function [dA,dG,dL, dA1,dG1,dL1, trA,trG,trL] = cp_agl(R)
% cp_agl — per-trial DV split into Actual / Global / Local components.
% For the contra_prediction residual pipeline (R = cp_residual_core output).
%
% PRIMARY DV = L1-dev: mean|r - mu| (robust trial-to-trial deviation from the
% amplitude-mean dip template = predictability). SECONDARY DV = template-gain:
% project each trial's dip onto the template (gain = <r,mu>/<mu,mu>; =1 for an
% average response, signed/directional = response SIZE). (Primacy swapped 2026-07-01:
% at the retargeted laser center L1-dev is the robust effect, gain collapses.)
% Normalized WITHIN amplitude: L1-dev as a RATIO to the amp-mean (positive; 1=average
% trial, <1=more predictable), template-gain as a z-score (signed/directional). For
% three signals, plus their pooled per-trial dip traces (aligned to R.mot order):
%   dA/dA1 , trA — actual ipsi dip        (= GLOBAL + LOCAL mixed)
%   dG/dG1 , trG — contra prediction      (GLOBAL incoming activity)
%   dL/dL1 , trL — residual = actual-contra (LOCAL stim effect)
% d*1 = L1-dev (PRIMARY);  d* = template-gain (SECONDARY).
iD = R.iDip;  nz = find(R.nzMask(:))';
zf = @(x)(x-mean(x,'omitnan'))/max(std(x,'omitnan'),eps);            % template-gain: z-within-amp (signed/directional)
rf = @(x) x ./ max(mean(x,'omitnan'),eps);                          % L1-dev: RATIO to amp-mean (positive; 1=avg, <1=more predictable)
dA=[]; dG=[]; dL=[]; dA1=[]; dG1=[]; dL1=[]; trA=[]; trG=[]; trL=[];
for ia = nz
    A = R.act_imp{ia};  P = R.prr_imp{ia};  L = R.res_imp{ia};
    [gA,l1A] = local_gain(A(:,iD));
    [gG,l1G] = local_gain(P(:,iD));
    [gL,l1L] = local_gain(L(:,iD));
    dA  = [dA;  zf(gA)];   dG  = [dG;  zf(gG)];   dL  = [dL;  zf(gL)];   %#ok<AGROW>
    dA1 = [dA1; rf(l1A)];  dG1 = [dG1; rf(l1G)];  dL1 = [dL1; rf(l1L)]; %#ok<AGROW> L1-dev = ratio to amp-mean
    trA = [trA; A];  trG = [trG; P];  trL = [trL; L];                   %#ok<AGROW>
end
end

% ------------------------------------------------------------------------------
function [g, l1] = local_gain(D)
% D [nT x nDip] dip traces. template mu = across-trial mean; g = projection gain,
% l1 = mean|dev|. nan-safe per trial.
mu  = mean(D, 1, 'omitnan');
den = max(sum(mu.^2, 'omitnan'), eps);
nT  = size(D, 1);  g = nan(nT,1);  l1 = nan(nT,1);
for j = 1:nT
    rj = D(j,:);  gd = isfinite(rj) & isfinite(mu);
    if ~any(gd), continue; end
    g(j)  = sum(rj(gd).*mu(gd)) / den;
    l1(j) = mean(abs(rj(gd) - mu(gd)), 'omitnan');
end
end
