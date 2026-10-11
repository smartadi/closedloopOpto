function [U, V, t, mimg] = loadUVt_hemo(expRoot, nSV)
% LOADUVT_HEMO  loadUVt with a switchable hemodynamic-correction folder.
%   [U, V, t, mimg] = loadUVt_hemo(expRoot, nSV)
%
% On 2026-10-11 the lab replaced <session>/corr/ on the server with a recomputed hemodynamic
% correction (fixed hemoCorrect.m, Pipelines c0de607) and kept the old one beside it in
% corr_hemoApr2021/ (or corr_hemoMay2021/, corr_hemoJan2021/, corr_hemoDec2020/). See
% \\sahale\data\Code\dataChangeLog\2026-10_hemoCorrect_recompute\EXPLAINER.md.
%
%   global HEMO_CORR
%     empty or 'corr'      -> exactly loadUVt (reads corr/, i.e. the NEW correction)
%     'corr_hemoApr2021'   -> U and mimg from loadUVt, V and t from that folder instead
%                             (the OLD correction; its timestamps are violet times, ~14 ms late)
%
% Exists so old-vs-new figures can be built from identical code and reverted if needed.
% Reads only; never writes to the server. loadUVt itself is vendored and stays untouched.
global HEMO_CORR
[U, V, t, mimg] = loadUVt(expRoot, nSV);
if isempty(HEMO_CORR) || strcmp(HEMO_CORR, 'corr')
    fprintf('[hemo] %s: corr/ (current server correction)\n', expRoot);
    return
end
d = fullfile(expRoot, HEMO_CORR);
vf = fullfile(d, 'svdTemporalComponents_corr.npy');
tf = fullfile(d, 'svdTemporalComponents_corr.timestamps.npy');
assert(exist(vf, 'file') == 2 && exist(tf, 'file') == 2, ...
    '[hemo] HEMO_CORR=''%s'' but %s has no corr V/timestamps.', HEMO_CORR, d);
V = readVfromNPY(vf, nSV);
t = readNPY(tf);
fprintf('[hemo] %s: V and t from %s/ (%d frames)\n', expRoot, HEMO_CORR, size(V, 2));
end
