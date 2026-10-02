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
%   slope            xw main effect        (OL state slope, per SD)
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
nmc=cellstr(string(C.Name)); gc=@(w) find(strcmp(nmc,w),1);
gi=gc('cond_CL'); si=gc('xw'); di=gc('cond_CL:xw');
R=struct('gap',C.Estimate(gi),'gapCI',[C.Lower(gi) C.Upper(gi)],'gapP',C.pValue(gi), ...
    'slope',C.Estimate(si), ...
    'dec',C.Estimate(di),'decCI',[C.Lower(di) C.Upper(di)],'decP',C.pValue(di), ...
    'randslope',rs,'lme',lme);
end
