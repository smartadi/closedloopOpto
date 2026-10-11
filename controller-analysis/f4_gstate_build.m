function R = f4_gstate_build(sessIdx, force)
% F4_GSTATE_BUILD  Per-trial stim-blind Global G (contra-predicted) on [-2,+3] s, for the
% Fig-4 band-power states computed on G instead of the controlled readout (2026-10-10).
%
% WHY: the Fig-4 relative/absolute delta states are measured on the controlled dF/F over
% [-2,+3) s, which shares 70 of its 175 samples with the [+1,+3] s error window, and the
% closed loop shapes that trace (|S| ~1.09 at 2-4 Hz). The state is then partly made by the
% controller (circularity; RESEARCH 2026-10-10). G is predicted from contralateral pixels by
% the locked ridge model (Stage 2, trained on spontaneous no-laser frames), so the controller
% does not drive it directly. Residual leak of the laser into G is checked in
% f4_gstate_checks.m (pre-only window, CL laser-command covariate).
%
%   R = f4_gstate_build(sessIdx)        % one session index into base-workspace `fields`
%   R = f4_gstate_build(sessIdx, true)  % rebuild even if the cache exists
%
% Writes controller-analysis/data/f4_gstate_<tag>.mat with
%   Gnc/Gwc  [nTrials x 176]  G at rel = -70:105 (onset column c0 = 71), rows in data.nc/data.wc order
%   Anc/Awc  same for the readout data.dFk (alignment check against pncDfk/pwcDfk)
%   lagNc/lagWc  per-trial frame offset of the SVD-timebase onset vs the controllerData onset
%   force_uncorr, R2_te, sess_tag, mn
% Requires load_sessions.m (mouse/fields in base) and the Stage-1/2 ridge caches + SVD.
if nargin < 2, force = false; end
mouse  = evalin('base','mouse');  fields = evalin('base','fields');
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
M = mouse.(fields{sessIdx});
tag = sprintf('%s_%s%s_e%d', M.mn, M.td(6:7), M.td(9:10), M.en);
fout = fullfile(dataDir, sprintf('f4_gstate_%s.mat', tag));
R = struct('k',sessIdx,'tag',tag,'ok',false,'msg','');
if exist(fout,'file') && ~force, R.ok=true; R.msg='cached'; return; end

CFG = struct('nSV_load',500,'Fs',35,'pre_s',2.0,'resp_s',3.0);
S = imp_build_session(mouse, fields, sessIdx, dataDir, CFG);
if ~S.ok, R.msg = S.msg; return; end
d = M.data;  nO = numel(d.nc);  nC = numel(d.wc);
% imp_build_session sorts onsets and drops edge trials; data.nc/wc come from find() (ascending)
% and the trial onsets are chronological, so the rows line up iff nothing was dropped.
assert(issorted(M.d.stimStarts(d.nc)) && issorted(M.d.stimStarts(d.wc)), '[GSB] onsets not chronological');
if S.nOL ~= nO || S.nCL ~= nC
    R.msg = sprintf('trial drop (OL %d/%d, CL %d/%d)', S.nOL, nO, S.nCL, nC); return;
end
rel = -S.pre:S.post;  assert(S.pre==70 && numel(rel)==176, '[GSB] unexpected window');
% alignment: pncDfk(:,351) is the controllerData onset frame; A uses the SVD timebase.
pcols = 351 + rel;
[lagNc, errNc] = bestlag(S.Aol, d.pncDfk, pcols);
[lagWc, errWc] = bestlag(S.Acl, d.pwcDfk, pcols);
Gnc = S.Gol; Gwc = S.Gcl; Anc = S.Aol; Awc = S.Acl;
% Re-express on the controllerData onset (the frame the readout states and the error use):
% relA = -70:104 (175 samples = the 'peri' state window), onset column c0 = 71. Lag -1 (SVD
% onset one frame earlier, seen on 0226 for every trial) maps to columns 2:176; NaN if a lag
% would need a sample outside the built window.
relA = -70:104;
GncA = realign(Gnc, lagNc, relA); GwcA = realign(Gwc, lagWc, relA);
AncA = realign(Anc, lagNc, relA); AwcA = realign(Awc, lagWc, relA);
force_uncorr = S.force_uncorr; R2_te = S.R2_te; mn = S.mn; c0 = 71; %#ok<NASGU>
save(fout, 'Gnc','Gwc','Anc','Awc','GncA','GwcA','AncA','AwcA','relA','lagNc','lagWc', ...
    'errNc','errWc','rel','c0','force_uncorr','R2_te','tag','mn');
R.ok = true;
R.msg = sprintf('OL %d CL %d | lag0 %d/%d %d/%d | max|dA| %.2g | uncorr %d | R2te %.2f', ...
    nO, nC, nnz(lagNc==0), nO, nnz(lagWc==0), nC, max([errNc; errWc]), force_uncorr, R2_te);
end

function Y = realign(X, lag, relA)
% X built on rel = -70:105 (col = rel+71) around the SVD onset; A(j,:) == P(j,351+rel+lag),
% so the controllerData onset sits at SVD rel = -lag. Return X on relA around that onset.
Y = nan(size(X,1), numel(relA));
for j = 1:size(X,1)
    cols = relA - lag(j) + 71;
    if all(cols>=1 & cols<=size(X,2)), Y(j,:) = X(j,cols); end
end
end

function [lag, err] = bestlag(A, P, pcols)
% per trial, the frame shift (-2..2) that best matches the SVD-timebase A to the cached buffer
lags = -2:2; n = size(A,1); lag = nan(n,1); err = nan(n,1);
for j = 1:n
    e = arrayfun(@(L) max(abs(A(j,:) - P(j, pcols+L))), lags);
    [err(j), i] = min(e); lag(j) = lags(i);
end
end
