function [dA,dG,dL,trA,trG,trL] = cp_agl(R)
% cp_agl — per-trial fig-6 deviation split into Actual / Global / Local.
% For the contra_residual residual pipeline (R = cp_residual_core output).
%
% Computes |dip - amplitude-mean| (the motion_analysis.m fig-6 deviation = single-
% trial distance from the trial-average response), z-scored WITHIN amplitude, for
% three signals, plus their pooled per-trial dip traces (aligned to R.mot order):
%   dA / trA — actual ipsi dip            (= fig 6, GLOBAL + LOCAL mixed)
%   dG / trG — contra prediction          (GLOBAL incoming activity)
%   dL / trL — residual = actual - contra (LOCAL stim effect)
% Actual = Global + Local exactly in signed space; |dev| is what we compare.
iD = R.iDip;  nz = find(R.nzMask(:))';
zf = @(x)(x-mean(x,'omitnan'))/max(std(x,'omitnan'),eps);
dA=[]; dG=[]; dL=[]; trA=[]; trG=[]; trL=[];
for ia = nz
    A = R.act_imp{ia};  P = R.prr_imp{ia};  L = R.res_imp{ia};
    dpA = mean(A(:,iD),2,'omitnan');  dpG = mean(P(:,iD),2,'omitnan');  dpL = mean(L(:,iD),2,'omitnan');
    dA = [dA; zf(abs(dpA - mean(dpA,'omitnan')))]; %#ok<AGROW>
    dG = [dG; zf(abs(dpG - mean(dpG,'omitnan')))]; %#ok<AGROW>
    dL = [dL; zf(abs(dpL - mean(dpL,'omitnan')))]; %#ok<AGROW>
    trA = [trA; A];  trG = [trG; P];  trL = [trL; L]; %#ok<AGROW>
end
end
