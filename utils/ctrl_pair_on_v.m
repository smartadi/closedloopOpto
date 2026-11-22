function P = ctrl_pair_on_v(dfk, timeBlue, tV, nV, frames, itr, ite)
% CTRL_PAIR_ON_V  Pair the controller's Actual (data.dFk, one sample per BLUE frame) with the SVD
% (one column per V frame) by TIME, not by index (research-hub #100, RESEARCH L-2026-11-22-a, -b).
%
% V column k belongs to the blue frame whose exposure starts last at or before V's timestamp k
% (blue/ stamps sit ~7 ms after exposure onset, old-corr violet stamps ~21 ms, the d.timeBlue fallback
% of cp_loadUVt 0 ms). This is the mapping impulse-analysis/load_experiments.m has used since
% 2026-10-11; the controller code paired by index instead. The server corr recomputed on 2026-10-11
% drops the first blue frame, and AL_0048's V starts 11 blue frames late, so index pairing put the
% Actual 1 and 11 frames away from the cortex that predicts it.
%
%   dfk       data.dFk, one sample per blue frame        timeBlue  d.timeBlue (blue exposure onsets, s)
%   tV        V timestamps (3rd output of cp_loadUVt)     nV        number of V columns in use
%   frames, itr, ite (optional)  Stage-1 spontaneous frames and its train/test indices into frames.
%             Stage 1 built them assuming V column = blue frame, so they are read as BLUE-frame
%             indices (the times Stage 1 meant) and moved to V columns here.
% P.y         dFk at the blue frame of each V column, for the first P.nV columns (those with a dFk sample)
% P.blueOfCol blue frame of each V column; P.colOfBlue V column of each blue frame (NaN if none)
% P.offMs     V stamp minus the blue exposure onset, ms; P.frames, P.itr, P.ite in V columns
tb = double(timeBlue(:));  tV = double(tV(:));
assert(numel(tV) >= nV, 'ctrl_pair_on_v: %d V stamps for %d columns', numel(tV), nV);
tV = tV(1:nV);
b = discretize(tV + 1e-6, [tb; inf]);                            % last blue onset at or before each stamp
offMs = 1e3 * (tV - tb(min(max(b, 1), numel(tb))));
assert(all(isfinite(b)) && all(diff(b) > 0) && all(offMs > -0.5 & offMs < 25), ...
    'ctrl_pair_on_v: V stamps do not map one-to-one onto blue frames (offset %.1f..%.1f ms)', min(offMs), max(offMs));
nK = find(b <= numel(dfk), 1, 'last');
P = struct('y', double(dfk(b(1:nK))), 'nV', nK, 'blueOfCol', b, 'offMs', offMs, ...
    'colOfBlue', nan(numel(tb), 1), 'frames', [], 'itr', [], 'ite', []);
P.y = P.y(:);  P.colOfBlue(b) = 1:nV;
if nargin > 4
    fc = nan(size(frames));  in = frames >= 1 & frames <= numel(tb);
    fc(in) = P.colOfBlue(frames(in));
    keep = isfinite(fc) & fc <= nK;
    map = cumsum(keep);                                  % as the Stage-1 frame clamp in ctrl_ols_ol_stimblind.m
    P.itr = map(itr(keep(itr)));  P.ite = map(ite(keep(ite)));  P.frames = fc(keep);
end
end
