function C = lmm_cluster_df(C, nClus)
% LMM_CLUSTER_DF  Reference fixed-effect tests against the number of clusters.
%   C = lmm_cluster_df(C, nClus)
% C is a Satterthwaite coefficient table (fixedEffects(lme,'DFMethod','Satterthwaite'),
% converted with dataset2table_safe); nClus is the number of sessions.
% Adds DFc = min(DF, nClus-1) and the matching pValueC / LowerC / UpperC.
%
% Why (2026-10-07): the Methods state that a between-session contrast is referenced
% against the number of sessions, not the number of trials. Satterthwaite delivers that
% only when the random-slope variance is well away from zero. When it sits at the boundary
% (Fig-3 rmse_early, var_early: df 71 and 85 from 15 sessions), or when a within-session
% predictor carries no random slope (the Fig-4 state terms), the Satterthwaite df revert
% toward the trial count. Capping at nClus-1 enforces the stated rule; it can only make a
% test more conservative. The raw Satterthwaite DF/pValue columns are left untouched.
dfc = min(C.DF, nClus - 1);
% Satterthwaite returns 0 or NaN when the session variance is estimated at exactly zero
% (Fig-2G absolute delta, 2026-10-07). Fall back to the cluster count then, not to 0.
bad = ~(dfc > 0);  dfc(bad) = nClus - 1;
q   = tinv(0.975, dfc);
C.DFc     = dfc;
C.pValueC = 2 * tcdf(-abs(C.tStat), dfc);
C.LowerC  = C.Estimate - q .* C.SE;
C.UpperC  = C.Estimate + q .* C.SE;
end
