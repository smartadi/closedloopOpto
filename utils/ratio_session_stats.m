function S = ratio_session_stats(r, mouse)
% RATIO_SESSION_STATS  Session-level summary of a CL/OL ratio (Fig 3H/3I scheme, 2026-10-15).
%   S = ratio_session_stats(r, mouse)
% r     : per-session ratio CL/OL (n x 1), so < 1 = closed loop better.
% mouse : per-session mouse label (n x 1 cellstr).
% Unit = session. Everything is computed on log(r):
%   effect     geometric mean ratio exp(mean log r), t-based 95% CI, also as "% lower"
%   PRIMARY    LMM log(r) ~ 1 + (1|mouse), REML, Satterthwaite df (+ df capped at n-1,
%              utils/lmm_cluster_df.m convention); est/CI are exp()-transformed in S.lmm_ratio*
%   also       one-sample t-test on log r (df = n-1)
%   corrob.    Wilcoxon signed-rank on log r
%   counts     sessions with r < 1
r = r(:); mouse = mouse(:);
lr = log(r);  n = numel(lr);

S.n       = n;
S.nMouse  = numel(unique(mouse));
S.r       = r;
S.mouse   = mouse;
S.median  = median(r);
S.nBelow1 = sum(r < 1);

% ---- effect size: geometric mean, t-based 95% CI ----
m = mean(lr); se = std(lr)/sqrt(n); q = tinv(0.975, n-1);
S.geo      = exp(m);
S.geoCI    = exp(m + [-1 1]*q*se);
S.pctLower   = 100*(1 - S.geo);
S.pctLowerCI = 100*(1 - fliplr(S.geoCI));

% ---- one-sample t-test on log ratios ----
[~, p, ~, st] = ttest(lr);
S.t_t = st.tstat; S.t_df = st.df; S.t_p = p;

% ---- PRIMARY: LMM log(r) ~ 1 + (1|mouse), Satterthwaite ----
tb  = table(lr, categorical(mouse), 'VariableNames', {'y','mouse'});
lme = fitlme(tb, 'y ~ 1 + (1|mouse)', 'FitMethod', 'REML');
[~,~,C] = fixedEffects(lme, 'DFMethod', 'Satterthwaite');
C = lmm_cluster_df(dataset2table_safe(C), n);
S.lmm_est = C.Estimate(1);   S.lmm_se = C.SE(1);
S.lmm_t   = C.tStat(1);      S.lmm_df = C.DF(1);     S.lmm_p = C.pValue(1);
S.lmm_ci  = [C.Lower(1) C.Upper(1)];
% With 4 mice (two of them single-session) the mouse variance sits at/near the boundary and the
% Satterthwaite df is unstable: 14 when it is ~0, but it collapsed to 0.97 (RMSE 0-3 s) and 0
% (variance 0-3 s -> p NaN) on 2026-10-15. lmm_dfc/lmm_pc = project rule (lmm_cluster_df):
% cap at n-1, and fall back to n-1 when Satterthwaite returns 0/NaN. Report both.
S.lmm_dfc = C.DFc(1);        S.lmm_pc = C.pValueC(1);
S.lmm_ratioCIc = exp([C.LowerC(1) C.UpperC(1)]);
S.lmm_ratio   = exp(S.lmm_est);
S.lmm_ratioCI = exp(S.lmm_ci);
[psi, ~] = covarianceParameters(lme);
S.mouseSD = sqrt(psi{1}(1));
S.residSD = sqrt(lme.MSE);

% ---- corroborating: Wilcoxon signed-rank on log ratios ----
[pw, ~, sw] = signrank(lr);
S.w_p = pw;  S.w_V = sw.signedrank;

% ---- SESSION RULE (2026-10-27, STATS_AUDIT §7): the MAIN test is the one-sample t on log r
% (S.t_p above, = S.st.p), with the exact Wilcoxon as backup and the mouse checks next to it.
% The LMM fields above are kept as a reference only; they no longer drive any star.
S.st = sess_test(r, mouse, true);
S.lomo_worst_p = S.st.lomo_worst_p;  S.lomo_worst_mouse = S.st.lomo_worst_mouse;
S.mouse_k = S.st.mouse_k;  S.mouse_p = S.st.mouse_p;
end
