%% run_fig4.m -- one-click launcher for the Figure-4 controller stream.
%
% Press Run. That is the whole interface. No analysis lives here: it runs, in order,
%   1. load_sessions          registry only (r_lean) -- each stage lazy-loads the session it needs
%   2. ctrl_residual_build    rebuild the Stage-2 stim-blind predictors (auto-K, unattended)
%   3. imp_reject_across_sessions   cross-session disturbance rejection
%   4. f4_reject_panels       Fig-4 rejection panels (demo + combined)
%   5. ctrl_optimal_xsess     cross-session MPC / best-possible-control comparison
%
% Sessions stay in the base workspace between runs, so a second run skips step 1. Steps 2-5
% each skip work they already have cached, so re-running after a crash resumes rather than
% restarting.
%
% WHY EVERY VARIABLE HERE IS NAMED RUN_*
%   Step 1 opens with `clearvars -except r_lean RUN_*`, and `run()` shares this workspace --
%   so anything this launcher sets under any other name is DESTROYED by step 1, and the failure
%   surfaces much later as "Unrecognized function or variable 'DO_REBUILD'". The RUN_ prefix is
%   the contract with load_sessions.m. If you add a knob here, prefix it.
%
% TIMING. Step 2 is the long one (~13 sessions, each 1-3.5 GB loaded and freed). Steps 3-5 are
% minutes. Step 4 alone is seconds -- it only reads a struct.
% -------------------------------------------------------------------------------------------------

%% ===================== CONFIG -- the only part you edit =====================
RUN_REBUILD = true;      % step 2. false once the Stage-2 caches are current (it is the slow one)
RUN_REJECT  = true;      % steps 3+4: rejection statistics and their panels
RUN_MPC     = true;      % step 5: the MPC comparison
RUN_FINAL   = false;     % false = PNG only (review) | true = also write the vector PDFs
RUN_FRESH   = false;     % true = rebuild the session registry even if it is already loaded
%% ============================================================================

clc;
RUN_HERE = fileparts(mfilename('fullpath'));
if isempty(RUN_HERE) || contains(RUN_HERE,tempdir,'IgnoreCase',true) || contains(RUN_HERE,'Editor_','IgnoreCase',true)
    RUN_HERE = 'C:\Users\aditya\Documents\projects\brain_paper\controller-analysis';  % section-run fallback
end
cd(RUN_HERE);  addpath(genpath(fullfile(RUN_HERE,'..','utils')));  addpath(RUN_HERE);

% Format flows to both panel scripts from one switch, so what you approve in PNG is what gets
% vectorised -- same figure code, only the extension list differs.
% (indexed rather than if/else: RUN_FINAL is a literal above, so the analyzer constant-folds
% an if/else and flags the untaken branch as dead code)
RUN_FMT_OPTS = {{'png'}, {'pdf','png'}};
RUN_FMT = RUN_FMT_OPTS{RUN_FINAL+1};

%% ---- 1. registry ---------------------------------------------------------------
% r_lean builds mouse/fields with NO d/data loaded: every stage below lazy-loads the one
% session it is working on and frees it again, so the 15-session load would only OOM.
if RUN_FRESH || ~exist('mouse','var') || ~exist('fields','var')
    fprintf('[RUN-FIG4] loading session registry...\n');
    r_lean = 1;   % read by load_sessions (registry-only mode)
    run(fullfile(RUN_HERE,'load_sessions.m'));
else
    fprintf('[RUN-FIG4] registry already loaded (%d sessions) -- set RUN_FRESH to force.\n', numel(fields));
end

%% ---- 2. rebuild the stim-blind predictors --------------------------------------
if RUN_REBUILD
    fprintf('\n[RUN-FIG4] === step 2/5: Stage-2 rebuild (the long one) ===\n');
    RB_REBUILD = true;  RB_CONFIRM = false;  %#ok<NASGU> read by ctrl_residual_build (auto-K default)
    run(fullfile(RUN_HERE,'ctrl_residual_build.m'));
    clear RB_REBUILD RB_CONFIRM
end

%% ---- 3+4. rejection statistics and panels --------------------------------------
if RUN_REJECT
    fprintf('\n[RUN-FIG4] === step 3/5: cross-session rejection ===\n');
    run(fullfile(RUN_HERE,'imp_reject_across_sessions.m'));
    fprintf('\n[RUN-FIG4] === step 4/5: rejection panels ===\n');
    F4_FMT = RUN_FMT;   % read by f4_reject_panels via its own override
    run(fullfile(RUN_HERE,'f4_reject_panels.m'));
end

%% ---- 5. MPC comparison ---------------------------------------------------------
if RUN_MPC
    fprintf('\n[RUN-FIG4] === step 5/5: cross-session MPC ===\n');
    OX_FMT = RUN_FMT;   % read by ctrl_optimal_xsess via its own override
    run(fullfile(RUN_HERE,'ctrl_optimal_xsess.m'));
end

fprintf('\n[RUN-FIG4] done. Panels -> %s\n', ...
    fullfile(fileparts(RUN_HERE),'paper','images','figure4'));
if ~RUN_FINAL
    fprintf('[RUN-FIG4] PNG only. Set RUN_FINAL = true and re-run once the layout is approved.\n');
end
