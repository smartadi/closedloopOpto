function A = onset_provenance_audit(verbose)
%ONSET_PROVENANCE_AUDIT  Check every session's stimulus onsets against the laser.
%
% WHY (2026-10-01, user). Server-side metadata CSVs were written with a Timeline
% offset that changed between rig builds, so `input_params` column 2 does not
% mean the same thing in every session. utils/findStims.m carries THREE readings
% of that column and controller-analysis/load_sessions.m implements a fourth:
%
%   mode 0  ignore input_params; threshold-cross the analog light command
%   mode 1  col2 is relative to horizon start -> subtract params.horizon
%   mode 2  col2 is an absolute sample index  -> no subtraction
%   2026-07 build: col2 is the trial END      -> onset = timeBlue(col2) - dur
%
% initialize_data.m hardcodes mode 1 for EVERY session; load_sessions.m then
% overrides stimStarts for the new-build sessions. The hazard is that findStims
% reads `horizon` in a try/catch that silently defaults to 40*35 = 1400 samples,
% so a session missing params.horizon has every onset shifted by a constant 40 s
% with no error. load_sessions.m:186 records that this actually happened.
%
% A CONSTANT SHIFT IS INVISIBLE to any within-session consistency check: the
% trial-averaged inhibition would still look correctly aligned, because every
% trial moved together. The only way to catch it is an independent clock.
%
% THE INDEPENDENT CLOCK. d.inpVals/d.inpTime are the analog light command as
% recorded, not metadata. Threshold-crossing them reconstructs onsets from
% hardware. This function compares that against whatever onsets the session is
% actually using, and reports the difference in samples and seconds.
%
%   A = onset_provenance_audit;        % audit, print, save
%   A = onset_provenance_audit(false); % quiet
%
% Requires load_sessions to have run (mouse, fields in the base workspace).
% READ-ONLY: changes nothing, writes data/onset_provenance_audit.mat.
%
% A non-zero median offset is a BLOCKING defect -- it means the session's
% column-2 convention was misread and every window in it is shifted.

if nargin < 1 || isempty(verbose), verbose = true; end

mouse  = evalin('base', 'mouse');
fields = evalin('base', 'fields');
Fs     = 35;
nS     = numel(fields);

A = struct('session', {cell(nS,1)}, 'mouse', {cell(nS,1)});

if verbose
    fprintf('\n===== ONSET PROVENANCE AUDIT (metadata vs recorded laser) =====\n');
    fprintf('%-5s %-9s %-9s %7s %7s %9s %9s  %s\n', ...
        'id','mouse','build','n_meta','n_light','med_off_s','max_off_s','horizon');
end

for k = 1:nS
    M = mouse.(fields{k});
    d = M.d;
    A.session{k} = fields{k};
    A.mouse{k}   = d.mn;

    isNew = isfield(M,'newbuild') && M.newbuild;
    A.newbuild(k) = isNew;

    % --- horizon provenance: real field, or the silent 40 s fallback? --------
    if isfield(d,'params') && isfield(d.params,'horizon') && ~isempty(d.params.horizon)
        A.horizon(k) = double(d.params.horizon);  hsrc = sprintf('%g', A.horizon(k));
    else
        A.horizon(k) = 40*35;                     hsrc = 'FALLBACK 1400';
    end
    A.horizon_fallback(k) = ~(isfield(d,'params') && isfield(d.params,'horizon') ...
                              && ~isempty(d.params.horizon));

    % --- onsets actually in use ---------------------------------------------
    t_meta = d.stimStarts(:);
    A.n_meta(k) = numel(t_meta);

    % --- independent reconstruction from the recorded light command ---------
    t_light = [];
    if isfield(d,'inpVals') && isfield(d,'inpTime') && ~isempty(d.inpVals)
        v = d.inpVals(:); ti = d.inpTime(:);
        up = find(v(2:end) > 0.1 & v(1:end-1) <= 0.1) + 1;
        if ~isempty(up)
            tt = ti(up);
            tt = tt([true; diff(tt) > 2]);   % collapse within-train crossings
            t_light = tt(:);
        end
    end
    A.n_light(k) = numel(t_light);

    % --- match each metadata onset to its nearest light onset ---------------
    if isempty(t_light) || isempty(t_meta)
        A.med_off(k) = NaN; A.max_off(k) = NaN; A.med_off_samp(k) = NaN;
    else
        dd = nan(numel(t_meta),1);
        for j = 1:numel(t_meta)
            [mn_, ~] = min(abs(t_light - t_meta(j)));
            dd(j) = mn_;
        end
        % signed offset against the nearest light onset
        sg = nan(numel(t_meta),1);
        for j = 1:numel(t_meta)
            [~, ix] = min(abs(t_light - t_meta(j)));
            sg(j) = t_meta(j) - t_light(ix);
        end
        A.med_off(k)      = median(sg);
        A.max_off(k)      = max(abs(dd));
        A.med_off_samp(k) = A.med_off(k) * Fs;
    end

    if verbose
        bld = 'legacy'; if isNew, bld = '2026-07'; end
        fprintf('%-5s %-9s %-9s %7d %7d %9.4f %9.4f  %s\n', ...
            fields{k}, d.mn, bld, A.n_meta(k), A.n_light(k), ...
            A.med_off(k), A.max_off(k), hsrc);
    end
end

if verbose
    bad = find(abs(A.med_off) > 1/Fs);        % more than one frame off
    fprintf('\nsessions with |median offset| > 1 frame (28.6 ms): %d / %d\n', ...
            numel(bad), nS);
    if ~isempty(bad)
        for b = bad(:)'
            fprintf('  BLOCKING: %s (%s) median offset %.4f s = %.1f samples\n', ...
                A.session{b}, A.mouse{b}, A.med_off(b), A.med_off_samp(b));
        end
    end
    nf = sum(A.horizon_fallback);
    fprintf('sessions relying on the silent horizon fallback: %d / %d\n', nf, nS);
end

out = fullfile(fileparts(mfilename('fullpath')), '..', 'data', ...
               'onset_provenance_audit.mat');
save(out, 'A');
if verbose, fprintf('saved -> %s\n', out); end
end
