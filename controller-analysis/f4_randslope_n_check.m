% controller-analysis/f4_randslope_n_check.m
% ============================================================================
% FIG 4 -- is the number of sessions enough for a random STATE slope?  [F4RSN]  (2026-10-11)
%
% Locked model:  y ~ cond*xw + (1+cond|sess) + (1|mouse)
% Random slope:  y ~ cond*xw + (1+cond+xw|sess) + (1|mouse)
% Uncorrelated:  y ~ cond*xw + (1+cond|sess) + (xw-1|sess) + (1|mouse)   (slope variance, no slope correlations)
% Question (user, 2026-10-11): "is n enough for figure 4 random slope?" (15 sessions, 11 for
% motion, 4 mice; Fig 2G has 4 sessions and the random-slope fit is degenerate there).
%   (1) VARIANCE  estimated session SD of the state slope vs the fixed slope, slope-correlation
%                 estimates (|r| ~ 1 = singular / not identified), REML LRT locked vs random slope.
%   (2) SIMULATION from the fitted models at the real design (same sessions, trials, states):
%                 NULL  = no fixed state effect, session slopes varying as estimated -> type-I
%                         error of the OL state slope under each model;
%                 ALT   = fitted random-slope model as truth -> power of each model.
%                 p from Satterthwaite with df capped at nSess-1 (as utils/f4_row2_fit).
% Knobs: RSN_NSIM (default 200), RSN_STATES (default all four). Results accumulate per state in
% data/f4_randslope_n_check.mat, so states can be run in separate calls.
% Needs: load_sessions.m (mouse/fields).
% ============================================================================
assert(exist('mouse','var') && exist('fields','var'), '[F4RSN] run load_sessions.m first.');
bpRoot = 'C:\Users\aditya\Documents\projects\brain_paper';
if ~exist('RSN_NSIM','var') || isempty(RSN_NSIM), RSN_NSIM = 200; end
if ~exist('RSN_STATES','var') || isempty(RSN_STATES), RSN_STATES = {'initdev','motion','delta','absdelta'}; end
[Pp,~] = f4_row2_pool(mouse, fields, 'mean', 'peri', false);
FL = 'y ~ cond*xw + (1+cond|sess) + (1|mouse)';
FR = 'y ~ cond*xw + (1+cond+xw|sess) + (1|mouse)';
FU = 'y ~ cond*xw + (1+cond|sess) + (xw-1|sess) + (1|mouse)';
F0 = 'y ~ cond + (1+cond+xw|sess) + (1|mouse)';          % null: no fixed state terms
fOut = fullfile(bpRoot,'data','f4_randslope_n_check.mat');
RSN = struct(); if exist(fOut,'file'), L0 = load(fOut); RSN = L0.RSN; end   % accumulate across runs
for i = 1:numel(RSN_STATES)
    st = RSN_STATES{i};
    rng(11 + i);
    T = Pp.(st); T = T(isfinite(T.x) & isfinite(T.y), :);
    T.xw = zeros(height(T),1); us = unique(T.sess);
    for s = 1:numel(us), m = T.sess==us(s); T.xw(m) = T.x(m) - mean(T.x(m)); end
    T.xw = T.xw / std(T.xw);  T.cond = reordercats(T.cond, {'OL','CL'});
    T.mouse = categorical(T.mouse); T.sess = categorical(T.sess);
    nS = numel(us);
    lL = fitlme(T, FL, 'FitMethod','REML');  lR = fitlme(T, FR, 'FitMethod','REML');
    lU = fitlme(T, FU, 'FitMethod','REML');
    % (1) variance components of the random-slope model
    [~, ~, cp] = covarianceParameters(lR);
    typ = cp{1}.Type; n1 = cp{1}.Name1; n2 = cp{1}.Name2; est = cp{1}.Estimate;
    slopeSD = est(strcmp(typ,'std') & strcmp(n1,'xw') & strcmp(n2,'xw'));
    corrs = est(strcmp(typ,'corr'));
    fx = fixedEffects(lR); bOL = fx(strcmp(lR.CoefficientNames,'xw'));
    C = compare(lL, lR);  pLRT = C.pValue(2);   % REML LRT, same fixed effects (conservative at the boundary)
    aic = [lL.ModelCriterion.AIC lR.ModelCriterion.AIC lU.ModelCriterion.AIC];
    fprintf('\n[F4RSN] %-8s nS=%2d nT=%4d | session SD of state slope %.3f vs fixed OL slope %+.3f (ratio %.2f) | slope corr %s | LRT p=%.3g | AIC locked %.1f, random %.1f, uncorr %.1f\n', ...
        st, nS, height(T), slopeSD, bOL, slopeSD/abs(bOL), mat2str(corrs',2), pLRT, aic);
    % (2) simulation
    l0 = fitlme(T, F0, 'FitMethod','REML');
    pN = nan(RSN_NSIM,3); pA = nan(RSN_NSIM,3);
    for r = 1:RSN_NSIM
        Ts = T; Ts.y = random(l0);
        pN(r,:) = [slope_p(Ts, FL, nS) slope_p(Ts, FR, nS) slope_p(Ts, FU, nS)];
        Ts.y = random(lR);
        pA(r,:) = [slope_p(Ts, FL, nS) slope_p(Ts, FR, nS) slope_p(Ts, FU, nS)];
    end
    t1 = mean(pN < 0.05, 1, 'omitnan');  pw = mean(pA < 0.05, 1, 'omitnan');
    fprintf('          %d sims | type-I @0.05: locked %.3f  random %.3f  uncorr %.3f | power @0.05: locked %.2f  random %.2f  uncorr %.2f | failed fits %d\n', ...
        RSN_NSIM, t1, pw, sum(isnan([pN(:); pA(:)])));
    RSN.(st) = struct('nS',nS,'nT',height(T),'slopeSD',slopeSD,'bOL',bOL,'corrs',corrs, ...
        'pLRT',pLRT,'aic',aic,'pNull',pN,'pAlt',pA,'typeI',t1,'power',pw, ...
        'models',{{FL,FR,FU}});
    save(fOut, 'RSN');
end
fprintf('[F4RSN] -> data/f4_randslope_n_check.mat\n');

function p = slope_p(T, f, nS)
% p of the OL state slope (xw, OL reference) with Satterthwaite df capped at nSess-1.
try
    l = fitlme(T, f, 'FitMethod','REML');
    [~,~,C] = fixedEffects(l, 'DFMethod','Satterthwaite'); C = lmm_cluster_df(dataset2table_safe(C), nS);
    p = C.pValueC(strcmp(cellstr(string(C.Name)), 'xw'));
catch
    p = NaN;
end
end
