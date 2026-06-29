% controller-tuning/load_grid.m
% Loader + per-trial cost for controller-gain GRID sweeps and AUTO-TUNING.
% SECONDARY analysis: how the closed-loop controller gains were tuned
% (not the paper's focus). See controller-tuning/CLAUDE.md.
%
% RUN ORDER:  run this FIRST (loads every session, caches a compact summary),
%             then run gain_grid.m and/or auto_tune.m which consume the
%             workspace structs G (grid) and A (auto-tune).
%
% DESIGN (2026-06-26): MOTION-FREE + CACHE-FIRST. We do NOT call initialize_data
% (it decodes the entire face.mp4 to compute unused motion energy -- minutes over
% the share). The per-session reader + cost loop live in ct_process_set.m so THIS
% file is a plain script (no local functions) and is re-parsed every run -- edits
% to the registry/knobs below always take effect without clear/rehash.
%
% Run from brain_paper/ root (or via run() from controller-tuning/).

clc; close all; clear;

if ~isfolder('controller-tuning') && isfolder(fullfile('..','controller-tuning'))
    cd('..');
end
addpath(genpath('utils'));
addpath('controller-tuning');                 % so ct_process_set.m is on the path

%% ---- Experiment registry -----------------------------------------------
% Fields per session:
%   mn,td,en  - identifiers (expPath)
%   ip        - 'root' | 'data'     : where input_params.csv / states.csv live
%   status    - 'ready' | 'hold'    : 'hold' = no onset source yet, skipped w/ note
%   note      - reason string (used when status='hold')
% The loader (ct_process_set.m) reads states.csv as y and AUTO-DETECTS the
% input_params layout by column count: 8-col -> onset@2/Kp@5/Ki@6/ref=-col7;
% 7-col -> no onset column (held). ref is taken from the data, not the registry.
mk = @(mn,td,en,ip,status,note) struct( ...
    'mn',mn,'td',td,'en',en,'ip',ip,'status',status,'note',note);

% --- GRID sessions (fixed (Kp,Ki) set, many trials each) ---
grid_sess(1) = mk('AL_0033','2025-01-10', 2,'data','ready','');                  % 8-col, data/ subdir
grid_sess(2) = mk('AL_0033','2025-03-03', 2,'root','ready','');                  % 8-col, prototype
grid_sess(3) = mk('AL_0033','2025-03-05', 1,'root','ready','');                  % 8-col, "with rewards"
grid_sess(4) = mk('AL_0034','2024-10-17',30,'data','ready','');                  % 7-col; Timeline onsets + auto-calibrated states lag (~71 frames)
grid_sess(5) = mk('AL_0034','2024-10-18', 1,'root','hold', ...
    '7-col; controlled signal (states.csv = ONLINE dF/F) not regulatable: no dip at any lag, no dose-response (Kp=0 dips same -2.9 as Kp=0.3). Laser pushed as hard as 10-17 (same pixel/kernel) but signal flat. Cause undetermined (biology vs online-dF/F targeting) -> needs getdfof recompute from raw (165GB .rar, not extracted). Unusable for cost surface regardless');
% NOTE: AL_0033 2025-03-17 moved to tune_sess below -- its (Kp,Ki) points are a
% scattered 2-cluster trajectory (continuous optimization), not a regular lattice.

% --- AUTO-TUNE sessions (gains adapt online; (Kp,Ki) form a trajectory) ---
tune_sess(1) = mk('AL_0034','2024-10-25', 1,'root','ready','');                  % 8-col, discrete zero-order
tune_sess(2) = mk('AL_0034','2024-10-25', 2,'root','ready','');                  % 8-col, discrete zero-order
tune_sess(3) = mk('AL_0033','2024-12-19', 1,'root','ready','');                  % 8-col, discrete zero-order
tune_sess(4) = mk('AL_0033','2025-03-17', 3,'root','ready','');                  % 8-col; continuous trajectory (reclassified from grid)

%% ---- knobs --------------------------------------------------------------
cfg.ONSET_OFF = 0;        % add to onset index if alignment is off (e.g. -horizon)
cfg.FS        = 35;       % states.csv sample rate (Hz) = imaging rate (105 samp = 3 s dur)
cfg.COST_WIN  = [0 3];    % seconds post-onset (controller-area MSE window)
cfg.PLOT_WIN  = [-0.5 3.5];% seconds, for stored per-node mean traces
cfg.IC_GATE   = 2;        % drop trials with |y at onset| > IC_GATE (bad baseline / glitch); Inf disables
cfg.YCLIP     = 80;       % |states| above this = logging glitch -> NaN'd before cost
% -- 7-col Timeline onset recovery (ct_timeline_onsets) --
cfg.FS_TL     = 2000;     % Timeline DAQ sample rate (Hz)
cfg.LASER_THR = 0.1;      % lightCommand laser-on threshold (V, abs); low so small regulated pulses count
cfg.TRIAL_GAP_S = 5;      % min ITI gap (s) to separate trials (merges intra-trial laser dropouts)
cfg.LAG_MAX   = 140;      % max states-vs-laser logging lag to auto-calibrate (frames)

%% ---- cache --------------------------------------------------------------
r_grid    = 0;            % 0 = recompute (use after editing this file); 1 = load summary cache
cacheFile = fullfile('data','grid_tuning_cache.mat');

if r_grid == 1 && isfile(cacheFile)
    load(cacheFile, 'G', 'A');
    fprintf('load_grid: loaded cache %s  (%d grid, %d auto-tune)\n', cacheFile, numel(G), numel(A));
else
    G = ct_process_set(grid_sess, cfg, 'GRID');
    A = ct_process_set(tune_sess, cfg, 'AUTOTUNE');
    if ~isfolder('data'); mkdir('data'); end
    save(cacheFile, 'G', 'A');
    fprintf('load_grid: saved cache %s\n', cacheFile);
end

fprintf('\nload_grid: ready. G = grid (%d), A = auto-tune (%d).\n', numel(G), numel(A));
fprintf('           -> gain_grid.m (cost surface), auto_tune.m (convergence).\n');
