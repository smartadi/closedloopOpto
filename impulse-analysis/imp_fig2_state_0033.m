%% imp_fig2_state_0033.m -- state-dependence of the local residual, AL_0033 e1 ONLY.
%
% WHY ONE SESSION (user, 2026-08-12). Judged from the per-amp fit plots: AL_0033 2025-01-29 e1 is
% the only session whose prediction is valid enough to carry a residual claim. The other three are
% excluded for reasons already on the record:
%   AL_0041 e1  -- CATCH CONTROL FAILS: at lambda_R=0.3 the decomposition produces a residual dip of
%                  -0.076 dF/F with NO stim present, 11-22% of that session's real dips, same sign.
%   AL_0041 e2  -- rel-delta runs the WRONG WAY (rho=-0.03) and its amps are few and low-trial
%                  (n=19-26 at two of them).
%   AL_0048 e1  -- readout sits ~2.6 mm from the illuminated spot, so it measures a CONNECTED region,
%                  not illuminated tissue. The best-scaled contra spatial mean ALONE already accounts
%                  for ~100% of its dip at 0.40 and 1.60 V -> its "local residual" is close to empty.
% CONSEQUENCE, stated plainly: with n=1 there is no pooling, no Stouffer, and no replication. Every
% number below is a single-session result and must be reported as one. See RESEARCH 2026-08-11/12.
%
% WHAT IT RUNS
%   f2_state      LEVEL of the residual vs state   (partial Spearman, dev_pre controlled)
%   f2_state_var  VARIANCE of the residual vs state (across-trial spread by state bin, PRIMARY;
%                 within-trial roughness, secondary) -- both with the GLOBAL negative control
%
% SELECTION RULE. 'r2max' is forced: the regulariser is picked on held-out spontaneous R^2 alone, so
% the leak is MEASURED rather than targeted and the GLOBAL negative control is armed. Under
% 'frontier' the penalty enforces b'e ~ 0, which is the very thing that control tests -- a state
% result obtained there would be a property of the penalty. Set F2_SELECT_OVERRIDE to compare.
%
% RUN:  imp_fig2_state_0033
% --------------------------------------------------------------------------------------------------

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
end
addpath(genpath(fullfile(here,'..','utils')));

if ~exist('F2_SELECT_OVERRIDE','var') || isempty(F2_SELECT_OVERRIDE)
    F2_SELECT_OVERRIDE = 'r2max';
end
if ~exist('SV_NBIN','var') || isempty(SV_NBIN), SV_NBIN = 4; end
S0033_FIGDIR = fullfile(here,'figs','fig2_state_0033');
if ~exist(S0033_FIGDIR,'dir'), mkdir(S0033_FIGDIR); end

%% ---- sessions: load if absent, then pin to AL_0033 -----------------------------------------------
if ~exist('allExperiments','var') || isempty(allExperiments)
    fprintf('[S0033] allExperiments absent -> load_experiments (reads SVD from the server; slow)\n');
    load_experiments
end
iSel = find(arrayfun(@(A) strcmp(A.mn,'AL_0033'), allExperiments), 1);
assert(~isempty(iSel), 'AL_0033 not found in allExperiments.');

% Knobs are set EXPLICITLY, not left to imp_fig2's ~exist defaults, because a stale F2_* left in the
% workspace by an earlier run would otherwise change this analysis silently.
clear F2_SEL F2_SELECT F2_R2FLOOR F2_USE_AFFECT F2_DETECTOR F2_FDRQ F2_PLOT ...
      F2_BILATERAL F2_USE_MOTION F2_DV F2_NU F2_SVW F2_KMAX
F2_SEL        = iSel;
F2_SELECT     = F2_SELECT_OVERRIDE;
F2_BILATERAL  = false;          % AL_0048 excluded by the judgement above -- do not append it
F2_USE_MOTION = false;          % contra-only is the variant to quote for a motion state test
F2_DETECTOR   = 'tf';           % confirmed detector; 'null' finds 0 px here (RESEARCH 2026-08-11)
F2_USE_AFFECT = true;
F2_R2FLOOR    = 0.85;
F2_DV         = 'L1DEVz';
F2_PLOT       = false;          % the state figures are drawn explicitly below

fprintf('\n[S0033] session %d = %s %s e%d | select = %s\n', iSel, ...
        allExperiments(iSel).mn, allExperiments(iSel).td, allExperiments(iSel).en, F2_SELECT);

imp_fig2

assert(numel(F2)==1, '[S0033] expected exactly one session, got %d.', numel(F2));

%% ---- STATE: level, then variance ------------------------------------------------------------------
fprintf('\n================ LEVEL of the residual vs state ================\n');
S0033_LEVEL = f2_state(F2, struct('dv',F2_DV, 'plot',true, 'verbose',true));

fprintf('\n================ VARIANCE of the residual vs state ================\n');
S0033_VAR = f2_state_var(F2, struct('nbin',SV_NBIN, 'plot',true, 'verbose',true));

%% ---- export -------------------------------------------------------------------------------------
% Diagnostics, so PNG per the project export rule. Not paper panels.
if ~isempty(S0033_LEVEL.fig) && ishandle(S0033_LEVEL.fig)
    exportgraphics(S0033_LEVEL.fig, fullfile(S0033_FIGDIR,'state_level.png'), 'Resolution',300);
end
if ~isempty(S0033_VAR.fig) && ishandle(S0033_VAR.fig)
    exportgraphics(S0033_VAR.fig, fullfile(S0033_FIGDIR,'state_variance.png'), 'Resolution',300);
end
fprintf('\n[S0033] figures -> %s\n', S0033_FIGDIR);
fprintf('[S0033] structs: F2 (session), S0033_LEVEL, S0033_VAR.\n');
fprintf('[S0033] n = 1 session: no pooling, no replication. Report as a single-session result.\n');
