function T = build_trials(d, data, span, Fs)
%BUILD_TRIALS  One per-trial time series per condition, on ONE common grid.
%
%   T = build_trials(d, data)                % default span [-10 6] s
%   T = build_trials(d, data, [-10 6], 35)
%
% WHY THIS EXISTS (2026-10-01). The cached struct stores the SAME underlying
% signal four times, sliced four ways around the same onset index:
%
%   ncDfk     dFk(i-35  : i+35*(dur+1))   onset col  36   -1 .. dur+1
%   pncDfk    dFk(i-350 : i+35*(dur+3))   onset col 351  -10 .. dur+3
%   pncDfk_l  dFk(i-105 : i+35*(dur+3))   onset col 106   -3 .. dur+3
%   ncmotion  mv (i-70  : i+35*dur)       onset col  71   -2 .. dur
%
% Audited 2026-10-01 across all 15 sessions: ncDfk is pncDfk(:,316:491) to
% EXACTLY zero, and pncDfk_l is pncDfk(:,246:end) to EXACTLY zero even though
% load_sessions.m:259 builds it by an independent re-slice. So three of the
% four are redundant -- but because each carries a DIFFERENT onset column,
% every downstream analysis had to remember which array it was holding. That
% is the bug surface: dfk and motion are both 176 columns at dur = 3 while
% their onsets differ by 35 samples, so using the wrong one is wrong by
% exactly one second and nothing errors.
%
% This function collapses them to one array per condition, with motion placed
% on the SAME grid as dFk (re-sliced from d.motion at the same onset index,
% not resampled -- they already share the d.timeBlue clock). After this you
% never pick an array or an onset column; you ask TQ for a time span:
%
%   y = tq(T, 'cl', 'dfk',    [-1 4]);   % CL dF/F, -1 to +4 s
%   m = tq(T, 'ol', 'motion', [-2 0]);   % OL motion baseline
%
% ONSETS ARE COMMAND-LOCKED, not laser-locked (user, 2026-10-01): the recorded
% light command lags the controller's command by acquisition latency, so
% laser-locking would fold the recording path into t = 0 and destroy the loop
% latency the transfer-function fit exists to measure. Measured per-session
% metadata-to-laser offsets are provenance only -- see onset_provenance_audit.
%
% Trials that cannot supply the full span are NaN-padded, never clamped, and
% counted in T.n_padded. A short window then shows up as NaN rather than as a
% plausible average over the wrong interval.
%
% See also: tq, trial_windows, controllerData.

if nargin < 3 || isempty(span), span = [-10 6]; end
if nargin < 4 || isempty(Fs),   Fs   = 35;      end

assert(numel(span) == 2 && span(2) > span(1), 'build_trials:span', ...
       'span must be [t0 t1] seconds with t1 > t0.');

nPre  = round(-span(1) * Fs);
nPost = round( span(2) * Fs);
assert(nPre >= 0, 'build_trials:span', 'span(1) must be <= 0 (onset is t = 0).');

dFk = data.dFk(:)';
mv  = d.motion(:)';
t   = d.timeBlue(:)';

T = struct();
T.fs        = Fs;
T.onset_col = nPre + 1;
T.n         = nPre + 1 + nPost;
T.t         = (-nPre:nPost) / Fs;          % seconds, 0 at the command
T.span      = span;
T.lock      = 'controller command';
T.dur       = d.params.dur;
T.ref       = d.ref;
T.mn        = d.mn;  T.td = d.td;  T.en = d.en;
T.signals   = {'dfk','motion'};
T.n_padded  = 0;

for c = {'ol','cl'}
    cond = c{1};
    switch cond
        case 'ol', sel = data.nc(:);
        case 'cl', sel = data.wc(:);
    end
    nTr = numel(sel);

    X = nan(nTr, T.n);
    M = nan(nTr, T.n);
    i0 = zeros(nTr, 1);

    for j = 1:nTr
        % Same nearest-sample lookup controllerData.m and load_sessions.m use,
        % so the unified arrays reproduce the originals exactly.
        [~, i] = min(abs(t - d.stimStarts(sel(j))));
        i0(j)  = i;

        [X(j,:), padX] = grab(dFk, i, nPre, nPost, T.n);
        [M(j,:), padM] = grab(mv,  i, nPre, nPost, T.n);
        T.n_padded = T.n_padded + double(padX || padM);
    end

    T.(cond).dfk      = X;
    T.(cond).motion   = M;
    T.(cond).trial    = sel;   % row index into d.input_params
    T.(cond).onset_ix = i0;    % sample index into d.timeBlue / data.dFk
    T.(cond).n        = nTr;
end
end

% -----------------------------------------------------------------------------
function [row, padded] = grab(v, i, nPre, nPost, n)
% Slice v around i, NaN-padding rather than clamping when the session ends.
a = i - nPre;  b = i + nPost;
padded = a < 1 || b > numel(v);
if ~padded
    row = v(a:b);
    return
end
row = nan(1, n);
src = max(1, a) : min(numel(v), b);
row((src(1) - a + 1) : (src(end) - a + 1)) = v(src);
end
