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
%   ref       - commanded dF/F setpoint (negative = inhibit); cost is ||y-ref||
%   ip        - 'root' | 'data'     : where input_params.csv lives
%   gain      - 'ip' | 'kr'         : gains from input_params(:,5:6) or Kr.npy(:,1:2)
%   ysrc      - 'cache' | 'mean'    : output trace from data/<yfile> or mean_states.csv
%   yfile     - pixel-cache filename in data/ (only when ysrc='cache')
%   status    - 'ready' | 'hold'    : 'hold' = no usable source yet, skipped w/ message
mk = @(mn,td,en,ref,ip,gain,ysrc,yfile,status) struct( ...
    'mn',mn,'td',td,'en',en,'ref',ref,'ip',ip,'gain',gain, ...
    'ysrc',ysrc,'yfile',yfile,'status',status);

% --- GRID sessions (fixed (Kp,Ki) set, many trials each) ---
grid_sess(1) = mk('AL_0034','2024-10-17',30,-5,'data','ip','cache','pixel101730.mat','ready'); % imaging in data/ subdir
grid_sess(2) = mk('AL_0034','2024-10-18', 1,-5,'root','kr', 'mean','',              'ready'); % no input_amps; gains in Kr.npy; y=mean_states.csv
grid_sess(3) = mk('AL_0033','2025-01-10', 2,-5,'data','ip','cache','pixel01102.mat','ready'); % imaging in data/ subdir
grid_sess(4) = mk('AL_0033','2025-03-03', 2,-2,'root','ip','cache','pixel03032.mat','ready'); % prototype session
grid_sess(5) = mk('AL_0033','2025-03-05', 1,-2,'root','ip','cache','pixel03051.mat','ready'); % "with rewards"
grid_sess(6) = mk('AL_0033','2025-03-17', 3,-2,'root','ip','cache','pixel03173.mat','ready');

% --- AUTO-TUNE sessions (gains adapt online; (Kp,Ki) form a trajectory) ---
tune_sess(1) = mk('AL_0034','2024-10-25', 1,-2,'root','ip','cache','pixel10251.mat','ready'); % Kr.npy + mean_states also present
tune_sess(2) = mk('AL_0034','2024-10-25', 2,-2,'root','ip','none','',               'hold');  % no cache/mean_states/blue -> needs adapter
tune_sess(3) = mk('AL_0033','2024-12-19', 1,-2,'root','ip','cache','pixel12191.mat','ready');

%% ---- column map + knobs -------------------------------------------------
cfg.KP_COL    = 5;        % input_params proportional-gain column
cfg.KI_COL    = 6;        % input_params integral-gain column
cfg.ONSET_COL = 2;        % input_params onset sample index (into the dF/F frame series)
cfg.ONSET_OFF = 0;        % add to onset index if alignment is off (e.g. -horizon)
cfg.FS        = 35;       % dF/F frame rate (Hz); prototype uses 35
cfg.COST_WIN  = [0 3];    % seconds post-onset (controller-area MSE window)
cfg.PLOT_WIN  = [-0.5 3.5];% seconds, for stored per-node mean traces
cfg.IC_GATE   = 2;        % drop trials with |y at onset| > IC_GATE (bad baseline); Inf disables

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
