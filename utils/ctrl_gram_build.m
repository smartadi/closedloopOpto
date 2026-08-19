function F = ctrl_gram_build(Xg, frames, itr, ite, ytrace)
%CTRL_GRAM_BUILD  Precompute the subset-fit Gram for one session's contra grid.
%
%   Built ONCE per session; ctrl_fitsub.m then solves any pixel subset out of it in O(K^3)
%   instead of re-touching 60k frames. This is what makes the K sweep in ctrl_select_k.m and the
%   interactive sweep in ctrl_affected_gui.m affordable.
%
%   Reproduces ctrl_ols_ol_stimblind.m's fit EXACTLY: per-pixel z-score taken from the TRAIN
%   block only, target centred on the train mean, held-out R^2 measured against the test block's
%   own mean. (Lifted out of ctrl_affected_gui.m's [COMPUTE-GRAM] 2026-08-10 so Stage 2, the K
%   selector and the GUI share one definition.)
%
% INPUT
%   Xg      [nG x T]  contra grid timecourses over the WHOLE session (Uflat(gridIdx,:)*V)
%   frames  [1 x nF]  spontaneous (laser-off) frame indices, from Stage 1
%   itr/ite           train / test index sets INTO `frames` (temporal split, from Stage 1)
%   ytrace  [T x 1]   regression target -- the canonical data.dFk (the scale ref=-5 lives in)
%
% OUTPUT  F, the struct ctrl_fitsub expects, plus .mu/.sd/.muY so a caller can deploy the fitted
%         weights on any frames with the same normalisation.
%
%   NB sse0tr == sstr by construction (both centre on the train mean), but sse0te ~= sste: the
%   test residual is measured against muY (train), while the test total SS uses the test mean.
%   That is deliberate -- it is what makes R2te an honest held-out number rather than a refit.

Xs   = Xg(:, frames);
mu   = mean(Xs(:,itr), 2);
sd   = std(Xs(:,itr), 0, 2);  sd(sd==0) = 1;
Ztr  = ((Xs(:,itr) - mu)./sd).';
Zte  = ((Xs(:,ite) - mu)./sd).';

ys   = ytrace(frames);
ytr  = ys(itr);  yte = ys(ite);
muY  = mean(ytr);
etr  = ytr - muY;
ete  = yte - muY;

F = struct( ...
    'Gtr', Ztr.'*Ztr, 'ctr', Ztr.'*etr, 'sse0tr', etr.'*etr, ...
    'Gte', Zte.'*Zte, 'cte', Zte.'*ete, 'sse0te', ete.'*ete, ...
    'sstr', sum((ytr - mean(ytr)).^2), 'sste', sum((yte - mean(yte)).^2), ...
    'mu', mu, 'sd', sd, 'muY', muY, 'nTr', numel(itr), 'nTe', numel(ite));
end
