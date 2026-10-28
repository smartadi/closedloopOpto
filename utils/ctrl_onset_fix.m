function [d, data, info] = ctrl_onset_fix(d, data, sid)
% CTRL_ONSET_FIX  Corrected trial onsets + AL_0048 dF/F alignment for one controller session.
%
%   [d, data, info] = ctrl_onset_fix(d, data, 'm4')
%
% Idempotent: a session that is already fixed comes back unchanged (info.changed = false).
% When info.changed is true the caller must re-run controllerData(data, d, trials).
%
% 1) ONSETS (user 2026-10-27). In m1-m8 (AL_0033, the 35 Hz pulse-train builds) stimStarts
%    drifted from the laser onset: m1/m2 about 4 frames early, m3-m8 drift of -7..+2 frames.
%    Corrected onset = open-loop laser-command rise minus the offset of the sessions that never
%    drifted (1.88 frames: one frame of trial bookkeeping + the 24 ms loop latency), so t = 0
%    keeps the logged-onset convention. CL trials take the offset from the OL trials around them
%    in time (a CL command can start late when the error is ~0). Built by stats_v2/onsets.py and
%    checked by eye for every session (data/stats_v2/onset_check_*.png).
%    Table: stats_v2/results/onsets_corrected.csv. m9-m15 are unchanged.
% 2) dF/F ALIGNMENT. AL_0048 2026-07-29/2 (m14): data.dFk is 11 frames shorter than timeBlue and
%    belongs to its END. Read start-aligned, the response led the laser by 6 frames. Prepend 11
%    copies of the first sample so dFk(i) <-> timeBlue(i). Edge-padded rather than NaN, so
%    whole-session filters stay finite; no trial window reaches these frames.
% The laser-channel fix for the same session lives in controllerData (ctrl_laser_cmd).
DFK_LEAD = struct('key', {'AL_0048_2026-07-29_2'}, 'lead', {11});

info = struct('changed', false, 'n_shifted', 0, 'dfk_lead', 0);
root = fileparts(fileparts(mfilename('fullpath')));
T = readtable(fullfile(root, 'stats_v2', 'results', 'onsets_corrected.csv'), 'TextType', 'string');
T = T(T.session == string(sid) & T.shift ~= 0, :);
tb = d.timeBlue(:);
nDur = round(double(d.params.dur) * 35);
for i = 1:height(T)
    j = T.trial_index(i);
    want = tb(T.onset_frame(i));
    if abs(d.stimStarts(j) - want) < 1e-9, continue; end      % already fixed
    [~, now_f] = min(abs(tb - d.stimStarts(j)));
    assert(now_f == T.onset_frame_stim(i), 'ctrl_onset_fix:mismatch', ...
        '%s trial %d: cache onset frame %d, table expects %d -- cache changed since the table was built.', ...
        sid, j, now_f, T.onset_frame_stim(i));
    d.stimStarts(j) = want;
    if isfield(d, 'stimEnds') && numel(d.stimEnds) >= j
        d.stimEnds(j) = tb(min(numel(tb), T.onset_frame(i) + nDur));
    end
    info.n_shifted = info.n_shifted + 1;
end

key = sprintf('%s_%s_%d', strtrim(char(d.mn(:)')), strtrim(char(d.td(:)')), round(d.en));
m = strcmp({DFK_LEAD.key}, key);
if any(m)
    lead = DFK_LEAD(m).lead;
    if numel(data.dFk) == numel(tb) - lead
        data.dFk = [repmat(data.dFk(1), lead, 1); data.dFk(:)];
        if isfield(data, 'F') && numel(data.F) == numel(tb) - lead
            data.F = [repmat(data.F(1), lead, 1); data.F(:)];
        end
        info.dfk_lead = lead;
    end
end

info.changed = info.n_shifted > 0 || info.dfk_lead > 0;
if info.changed
    d.onset_fix = struct('table', 'stats_v2/results/onsets_corrected.csv', ...
        'n_shifted', info.n_shifted, 'dfk_lead', info.dfk_lead, ...
        'when', char(datetime('now', 'Format', 'yyyy-MM-dd')));
end
end
