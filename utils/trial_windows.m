function W = trial_windows(dur, Fs)
%TRIAL_WINDOWS  Single source of truth for per-trial array geometry.
%
%   W = trial_windows(dur)        % Fs defaults to 35
%   W = trial_windows(dur, Fs)
%
% WHY THIS EXISTS (2026-10-01). The four per-trial arrays in a controller
% session are sliced around the same onset index but with DIFFERENT lead-ins,
% so they have different onset columns:
%
%   array     built in                    slice            onset col   span
%   dfk       controllerData.m:110        i-35  : i+35*(dur+1)   36     -1 .. dur+1
%   pdfk      controllerData.m:111        i-350 : i+35*(dur+3)  351    -10 .. dur+3
%   pdfk_l    load_sessions.m:259         dFk(i-105 : i+35*(dur+3)) 106   -3 .. dur+3
%   motion    controllerData.m:114        i-70  : i+35*dur       71     -2 .. dur
%
% THE TRAP THIS CLOSES: dfk and motion are BOTH 176 columns when dur = 3, but
% their onsets are 35 samples apart. Equal lengths defeat the obvious sanity
% check, so applying dfk's onset to the motion array is wrong by exactly one
% second and nothing errors. Before this function those four numbers lived as
% bare literals on utils/f4_row2_pool.m:22.
%
% Onsets are COMMAND-locked, not laser-locked (user, 2026-10-01). The recorded
% light command arrives after the controller issues it, so realigning to the
% laser would fold the recording latency into t = 0 and destroy the loop
% latency the transfer-function fit is meant to measure. The measured
% metadata-to-laser offset per session is provenance, recorded by
% controller-analysis/onset_provenance_audit.m, and is deliberately NOT applied.
%
% See also: trialwin (resolves a time span to column indices).

if nargin < 2 || isempty(Fs), Fs = 35; end
assert(isscalar(dur) && isfinite(dur) && dur > 0, 'trial_windows:dur', ...
       'dur must be a positive scalar.');

W = struct('fs', Fs, 'dur', dur, 'onset_locked_to', 'controller command');

W.dfk    = mk(35,  35*(dur+1), Fs);
W.pdfk   = mk(350, 35*(dur+3), Fs);
W.motion = mk(70,  35*dur,     Fs);

% pdfk_l has TWO producers, which is why it is listed separately:
%   - load_sessions.m:259 re-slices dFk directly at i-105, with its own
%     min(abs(t - stimStarts)) index lookup -- it is NOT cropped from pdfk;
%   - analysisPlots_paper.m:199-200 and analysisPlots_var.m:177-178 instead
%     take pdfk(:, 246:end), which lands on the same 316 columns (351-245=106).
% Verified 2026-10-01 on all 15 sessions: the two paths agree to EXACTLY 0,
% so the duplication is currently harmless. It is still duplication, and the
% restructure removes it by making pdfk_l a view rather than a stored array.
W.pdfk_l = mk(350 - 245, 35*(dur+3), Fs);

% every analysis array, so callers can iterate
W.names = {'dfk','pdfk','pdfk_l','motion'};
end

% -----------------------------------------------------------------------------
function w = mk(nPre, nPost, Fs)
% nPre samples before onset, nPost after, onset itself included.
w = struct( ...
    'onset_col', nPre + 1, ...
    'n',         nPre + 1 + nPost, ...
    't_first',  -nPre / Fs, ...
    't_last',    nPost / Fs);
end
