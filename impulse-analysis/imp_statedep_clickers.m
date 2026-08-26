% imp_statedep_clickers.m — thin wrapper for the RUN_CLICKERS mode of ols_tf_pipeline.m.
% ------------------------------------------------------------------------------------------
% The clicker logic now lives INSIDE ols_tf_pipeline.m (the single script) under the
% RUN_CLICKERS block — search "CLICKERS: one clickable §17c state-vs-prediction scatter".
% This wrapper just clears any stale run-flags and drives it, so you can run it fresh.
%
% Produces one CLICKABLE §17c STATEDEP figure per session (Local-dip DV vs Motion / Pre-var /
% Pre-δ / Rel-δ). Click any scatter point -> that trial's actual / stim-blind prediction /
% residual / motion traces. All four stay interactive after the loop (callback data is
% self-contained in each figure's guidata).
%
% PREREQUISITE: allExperiments already in the base workspace (run load_experiments.m first).
% USAGE:  imp_statedep_clickers                         % all loaded sessions ([3 1 2 4])
%         CLICKER_SESS = [3 1]; imp_statedep_clickers   % a subset, in that order
% Equivalent to:  RUN_CLICKERS = true; ols_tf_pipeline
% ------------------------------------------------------------------------------------------

clear RUN_ALL RUN_ALLSESS RUN_MODE RUN_XSESS RUN_SESSION_VIEWER OLS_OVERRIDE CLK_ACTIVE
RUN_CLICKERS = true;
ols_tf_pipeline
