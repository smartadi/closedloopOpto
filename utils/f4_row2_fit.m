function [R, T] = f4_row2_fit(T)
% F4_ROW2_FIT  Canonical Fig-4 Row-2 session-aware LMM (single source).
% Shared by f4_row2_stats.m (forest, f4_2S_stats) and f4_row2_quartiles.m panels so the
% forest decoupling p and the panel star are IDENTICAL by construction.
%
%   [R, T] = f4_row2_fit(T)
%
% T is one state's pooled table from f4_row2_pool (vars y, cond{OL,CL}, x, sess, mouse).
% Adds xw = state centered WITHIN session then scaled by the pooled SD, and fits
%   y ~ cond*xw + (1+cond|sess) + (1|mouse)          (random OL/CL slope per session)
% falling back to (1|sess) + (1|mouse) if the random-slope model fails to converge.
% Returns R with:
%   gap/gapCI/gapP   cond_CL main effect  (OL-CL gap at mean state; <0 = CL lower RMSE)
%   slope/slopeCI/slopeP  xw main effect  (OL state slope, per SD = PREDICTABILITY term)
%   *T / *DF         t statistic and Satterthwaite df for gap, slope and dec
%   dec/decCI/decP   cond_CL:xw interaction (DECOUPLING; <0 = CL flattens state slope)
%   randslope        true if the random-slope model was used
%   lme              the fitted model object
% T is returned with the xw column added (used by the hierarchical bootstrap).
T.xw=zeros(height(T),1); us=unique(T.sess);
for i=1:numel(us), m=T.sess==us(i); T.xw(m)=T.x(m)-mean(T.x(m)); end
T.xw=T.xw/std(T.xw);
T.cond=reordercats(T.cond,{'OL','CL'});
% REML + Satterthwaite, matching utils/cl_olcl_lmm.m (2026-10-01). See there.
try   lme=fitlme(T,'y ~ cond*xw + (1+cond|sess) + (1|mouse)', 'FitMethod','REML'); rs=true;
catch, lme=fitlme(T,'y ~ cond*xw + (1|sess) + (1|mouse)',      'FitMethod','REML'); rs=false; end
[~,~,C]=fixedEffects(lme, 'DFMethod','Satterthwaite');  C=dataset2table_safe(C);
assert(~isempty(C) && ismember('Name', C.Properties.VariableNames), ...
    'f4_row2_fit:coefConv', 'Satterthwaite coefficient table did not convert.');
C=lmm_cluster_df(C, numel(unique(T.sess)));   % df <= nSess-1 (2026-10-07)
nmc=cellstr(string(C.Name)); gc=@(w) find(strcmp(nmc,w),1);
gi=gc('cond_CL'); si=gc('xw'); di=gc('cond_CL:xw');
% slopeP is taken from the SAME Satterthwaite table. Until 2026-10-07 the panel read the
% predictability p from lme.Coefficients, whose DF are the fitlme RESIDUAL default (~trial
% count), so predictability was tested against trials while controllability was tested
% against Satterthwaite df -- two different references inside one panel.
R=struct('gap',C.Estimate(gi),'gapCI',[C.LowerC(gi) C.UpperC(gi)],'gapP',C.pValueC(gi), ...
    'gapT',C.tStat(gi),'gapDF',C.DFc(gi), ...
    'slope',C.Estimate(si),'slopeCI',[C.LowerC(si) C.UpperC(si)],'slopeP',C.pValueC(si), ...
    'slopeT',C.tStat(si),'slopeDF',C.DFc(si), ...
    'dec',C.Estimate(di),'decCI',[C.LowerC(di) C.UpperC(di)],'decP',C.pValueC(di), ...
    'decT',C.tStat(di),'decDF',C.DFc(di), ...
    'sat',C(:,{'Name','DF','pValue'}), ...
    'randslope',rs,'lme',lme);
end
