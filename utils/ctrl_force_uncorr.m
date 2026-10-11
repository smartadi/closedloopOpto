function tf = ctrl_force_uncorr(S2)
% CTRL_FORCE_UNCORR  Which V a Stage-2 cache's ridge weights (b, mu, sd) were trained on.
%
%   tf = ctrl_force_uncorr(S2)   S2 = loaded ctrl_ols_ol_stimblind<sfx>_<tag>.mat
%
% Every consumer that applies the Stage-2 weights to a freshly loaded V must load the SAME V,
% i.e. pass tf as cp_loadUVt's 4th argument. Read from the cache, never from a session list:
% the uncorrected-V list in ctrl_ols_ol_stimblind.m (2026-09-05) only governs NEW fits, and the
% current ridge caches (2026-08-12) predate it. Caches without the field were trained on the
% default V (corrected where a corr/ folder exists).
%
% 2026-10-10: a list-keyed version of this check briefly made imp_build_session load the
% uncorrected V for AL_0039 0419/0420 against corrected-trained weights; reverted the same day
% after the corrected V was shown to predict the readout better (pre-stim R^2 0.85/0.81 vs
% 0.74/0.75). RESEARCH 2026-10-10.
tf = isstruct(S2) && isfield(S2,'force_uncorr') && logical(S2.force_uncorr);
end
