% controller-tuning/load_grid.m
% Session registry for controller-gain GRID sweeps + AUTO-TUNING experiments.
% SECONDARY analysis: how the closed-loop controller gains were tuned
% (not the paper's focus). See controller-tuning/CLAUDE.md.
%
% Prototype origin : Grid_mouseDataAnalysis.m (root) + scratch_grid/.
% Loading pipeline : reuse controller area -> initialize_data -> getpixel_dFoF.
% Run from brain_paper/ root (or via run() from controller-tuning/).

clc; close all; clear;

% If launched from controller-tuning/, step up to project root so data/ + utils/ resolve.
if ~isfolder('controller-tuning') && isfolder(fullfile('..','controller-tuning'))
    cd('..');
end
addpath(genpath('utils'));

%% ---- Experiment registry (mn, td, en) ----------------------------------
% GRID: each session runs several fixed PI controllers (Kp,Ki pairs); trials are
% grouped by controller -> cost J(Kp,Ki) per node.
grid_sess(1) = struct('mn','AL_0034','td','2024-10-17','en',1);
grid_sess(2) = struct('mn','AL_0034','td','2024-10-18','en',1);
grid_sess(3) = struct('mn','AL_0033','td','2025-01-10','en',2);
grid_sess(4) = struct('mn','AL_0033','td','2025-03-03','en',2);   % active session in prototype
grid_sess(5) = struct('mn','AL_0033','td','2025-03-05','en',1);   % "with rewards" in prototype
grid_sess(6) = struct('mn','AL_0033','td','2025-03-17','en',3);

% AUTO-TUNE: controller adapts its gains online; read back gain trajectory + cost.
tune_sess(1) = struct('mn','AL_0034','td','2024-10-25','en',1);
tune_sess(2) = struct('mn','AL_0034','td','2024-10-25','en',2);
tune_sess(3) = struct('mn','AL_0033','td','2024-12-19','en',1);

%% ---- input_params column map -------------------------------------------
% From Grid_mouseDataAnalysis.m. UNVERIFIED per-session -- confirm on first load.
ONSET_COL = 2;   % stim/trial onset sample index
TYPE_COL  = 3;   % trial type (==2 => feedback/CL in prototype)
KP_COL    = 5;   % proportional gain  (grid: fixed set; auto-tune: trajectory over trials)
KI_COL    = 6;   % integral gain      (same columns for both experiment types)

%% ---- Cost-function knobs (RESOLVED 2026-06-22) -------------------------
COST_WIN     = [0 3];   % seconds post-onset (matches controller-area MSE window)
% Cost reference = per-session d.ref (read on load; do NOT hard-code). The two
% constants below are only fallbacks if a session is missing d.ref.
REF_FALLBACK = -2;      % prototype target
REF_PROJECT  = -5;      % project-wide default

%% ---- Cache ------------------------------------------------------------
r_grid = 1;   % 1 = load from cache if available; 0 = recompute and overwrite
grid_key = @(s) sprintf('%s_grid_%s%d.mat', s.mn, s.td(6:7), s.en);   % e.g. AL_0033_grid_03032.mat

fprintf('load_grid: %d grid sessions, %d auto-tune sessions registered.\n', ...
    numel(grid_sess), numel(tune_sess));

% NOTE: loading loop + cost computation intentionally deferred until the open
% questions in controller-tuning/CLAUDE.md are resolved (cost reference, autotune
% columns, paper scope). Do not build gain_grid.m / auto_tune.m before then.
