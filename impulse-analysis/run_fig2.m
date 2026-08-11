%% run_fig2.m -- one-click launcher for the Figure-2 residual stream (imp_fig2.m).
%
% Press Run. That is the whole interface. Everything below the CONFIG block is path setup,
% guard rails and reporting -- no analysis lives here, it all lives in imp_fig2 and the f2_* helpers.
%
% TIMING.  cold (sessions not yet loaded)  ~5.5 min SVD load + ~2 min analysis
%          warm (allExperiments in memory) ~2 min for all 4 sessions, both motion variants
%                                          ~33 s for one session, figures off, no variant
%
% Sessions stay in the base workspace between runs, so only the FIRST run of a MATLAB session
% pays the load. Set FRESH_LOAD = true to force a reload.
% -------------------------------------------------------------------------------------------------

%% ===================== CONFIG -- the only part you edit =====================
SESSIONS    = [];        % [] = all four | 3 = AL_0033 (primary) | 1,2 = AL_0041 e1,e2 | 4 = AL_0048
FIGURES     = true;      % affected-layout figure per session + the state figure
MOTION_VAR  = true;      % also run the contra+motion predictor variant (robustness); doubles runtime
DV          = 'L1DEVz';  % state DV: 'L1DEVz' (primary, unpredictability) | 'DVz' (signed dip) | 'GAINz'
FRESH_LOAD  = false;     % true = clear allExperiments and re-read the SVD from the server
%% ============================================================================

clc;
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here, tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';   % section-run fallback
end
cd(here);  addpath(genpath(fullfile(here,'..','utils')));  addpath(here);

% Emptied rather than `clear`ed: `clear` inside a script blinds MATLAB's static analyser to
% everything after it. imp_fig2 tests isempty(), so [] triggers the reload just as clear would.
% UNRCH: the analyser constant-folds the FRESH_LOAD default and calls this dead. It is a config
% flag -- flipping it in the CONFIG block above is the entire point.
if FRESH_LOAD, allExperiments = []; end   %#ok<UNRCH>
F2 = [];  F2_STATE = [];  F2_STATE_MOT = [];        % never let a previous run's results survive

% GUARD: load_experiments now appends AL_0048 itself. Calling load_bilateral_impulse on top of it
% registers the session TWICE, and a duplicate would silently be pooled as a 5th replicate. Cheap to
% detect, so detect it rather than trusting nobody ever does it.
if exist('allExperiments','var') && ~isempty(allExperiments)
    tags = arrayfun(@(A) sprintf('%s_%s_e%d', A.mn, A.td, A.en), allExperiments, 'uni',0);
    [u, ia] = unique(tags, 'stable');
    if numel(u) < numel(tags)
        fprintf(2,'[RUN] allExperiments has %d DUPLICATE entr(y/ies) -> dropping them.\n', numel(tags)-numel(u));
        allExperiments = allExperiments(sort(ia));
    end
end

F2_SEL = SESSIONS;  F2_PLOT = FIGURES;  F2_USE_MOTION = MOTION_VAR;  F2_DV = DV;  F2_BILATERAL = true;

fprintf('[RUN] Figure-2 residual stream | sessions %s | figures %d | motion variant %d | DV %s\n', ...
        local_selstr(SESSIONS), FIGURES, MOTION_VAR, DV);
t0 = tic;
imp_fig2
fprintf('\n[RUN] finished in %.0f s.\n', toc(t0));

%% ---- what to look at, so the summary is not just a wall of numbers -------------------------------
fprintf(['\n[RUN] WHERE TO LOOK\n' ...
         '  1. PREDICTOR / DECOMPOSITION SUMMARY -- shiftR2 must be ~0 or negative (else the R^2 is\n' ...
         '     inflated by drift), and catch%% must be near 0 (else the residual is manufactured).\n' ...
         '  2. CATCH VERDICT just below it -- any session listed there has VOID capture/leak numbers.\n' ...
         '  3. The per-session "ridge sweep" tables -- R^2 and leak fall together, which is exactly why\n' ...
         '     the old leak-minimising pick was circular. This stream picks on R^2.\n' ...
         '  4. F2-STATE -- Motion should read NULL; the GLOBAL control column says whether an effect\n' ...
         '     is local or just leaking through the predictor.\n' ...
         '\n[RUN] WORKSPACE\n' ...
         '  F2(k)         .A affected | .M model | .D decomposition | .Mmot/.Dmot motion variant\n' ...
         '  F2_STATE      per-session + pooled state result\n' ...
         '  allExperiments  stays loaded -- re-running is fast unless you set FRESH_LOAD\n']);

function s = local_selstr(v)
if isempty(v), s = 'all'; else, s = mat2str(v); end
end
