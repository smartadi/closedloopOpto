% controller-tuning/load_grid.m
% Loader + per-trial cost for controller-gain GRID sweeps and AUTO-TUNING.
% SECONDARY analysis: how the closed-loop controller gains were tuned
% (not the paper's focus). See controller-tuning/CLAUDE.md.
%
% RUN ORDER:  run this FIRST (it loads every session and caches a compact
%             summary), then run gain_grid.m and/or auto_tune.m which consume
%             the workspace structs G (grid) and A (auto-tune).
%
% Prototype origin : Grid_mouseDataAnalysis.m (root) + scratch_grid/.
% Loading pipeline : initialize_data -> getpixel_dFoF (same as controller area).
% Run from brain_paper/ root (or via run() from controller-tuning/).

clc; close all; clear;

% If launched from controller-tuning/, step up to project root so data/+utils/ resolve.
if ~isfolder('controller-tuning') && isfolder(fullfile('..','controller-tuning'))
    cd('..');
end
addpath(genpath('utils'));

%% ---- Experiment registry (mn, td, en, ref) -----------------------------
% ref = commanded dF/F setpoint for that session's controller (negative = inhibit).
% d.ref is NOT auto-populated by initialize_data, so it is set explicitly here.
% Prototype used -2 for AL_0033 2025-03-03. CONFIRM/EDIT per session if different.
grid_sess(1) = struct('mn','AL_0034','td','2024-10-17','en',1,'ref',-2);
grid_sess(2) = struct('mn','AL_0034','td','2024-10-18','en',1,'ref',-2);
grid_sess(3) = struct('mn','AL_0033','td','2025-01-10','en',2,'ref',-2);
grid_sess(4) = struct('mn','AL_0033','td','2025-03-03','en',2,'ref',-2);   % prototype session
grid_sess(5) = struct('mn','AL_0033','td','2025-03-05','en',1,'ref',-2);   % "with rewards"
grid_sess(6) = struct('mn','AL_0033','td','2025-03-17','en',3,'ref',-2);

tune_sess(1) = struct('mn','AL_0034','td','2024-10-25','en',1,'ref',-2);
tune_sess(2) = struct('mn','AL_0034','td','2024-10-25','en',2,'ref',-2);
tune_sess(3) = struct('mn','AL_0033','td','2024-12-19','en',1,'ref',-2);

%% ---- input_params column map (from prototype; verify on first load) -----
KP_COL   = 5;     % proportional gain  (grid: fixed set; auto-tune: trajectory)
KI_COL   = 6;     % integral gain      (same columns for both experiment types)
% TYPE_COL = 3;   % trial type (==2 feedback in prototype) -- not filtered here

%% ---- Cost-function knobs (RESOLVED 2026-06-22) -------------------------
COST_WIN = [0 3];     % seconds post-onset (controller-area MSE window)
PLOT_WIN = [-0.5 3.5];% seconds, for stored per-node mean traces
IC_GATE  = 2;         % drop trials with |dF/F at onset| > IC_GATE (bad baseline); Inf disables
pixMode  = 1;         % getpixel_dFoF: 1 = SVD reconstruction
r_pix    = 1;         % getpixel_dFoF cache flag (1 = use data/<mn>pixel<MMDD><en>.mat)

%% ---- Cache --------------------------------------------------------------
r_grid    = 1;        % 1 = load summary cache if present; 0 = recompute from server
cacheFile = fullfile('data','grid_tuning_cache.mat');

if r_grid == 1 && isfile(cacheFile)
    load(cacheFile, 'G', 'A');
    fprintf('load_grid: loaded cache %s  (%d grid, %d auto-tune sessions)\n', ...
        cacheFile, numel(G), numel(A));
else
    G = process_set(grid_sess, KP_COL, KI_COL, COST_WIN, PLOT_WIN, IC_GATE, pixMode, r_pix, 'GRID');
    A = process_set(tune_sess, KP_COL, KI_COL, COST_WIN, PLOT_WIN, IC_GATE, pixMode, r_pix, 'AUTOTUNE');
    if ~isfolder('data'); mkdir('data'); end
    save(cacheFile, 'G', 'A');
    fprintf('load_grid: saved cache %s\n', cacheFile);
end

fprintf('load_grid: ready. G = grid struct (%d), A = auto-tune struct (%d).\n', numel(G), numel(A));
fprintf('           -> run gain_grid.m (cost surface) and auto_tune.m (convergence).\n');


%% ===================== local functions =================================
function S = process_set(sessList, KP_COL, KI_COL, COST_WIN, PLOT_WIN, IC_GATE, pixMode, r_pix, tag)
% Load each session, compute per-trial cost, group by unique (Kp,Ki).
S = struct([]);
for si = 1:numel(sessList)
    s = sessList(si);
    fprintf('\n[%s %d/%d] %s %s e%d (ref=%g) ...\n', tag, si, numel(sessList), s.mn, s.td, s.en, s.ref);
    try
        d = initialize_data(s.mn, s.en, s.td);
        [~, dFk] = getpixel_dFoF(d, pixMode, d.params.pixel, r_pix);
    catch ME
        warning('  skipped (%s): %s', s.mn, ME.message);
        continue;
    end
    dFk = double(dFk(:)).';
    t   = double(d.timeBlue(:)).';
    fs  = 1 / median(diff(t));
    ref = s.ref;

    IP    = d.input_params;
    nTr   = numel(d.stimStarts);
    nUse  = min(nTr, size(IP,1));
    gains = round(IP(1:nUse, [KP_COL KI_COL]), 6);   % round off float noise

    n3   = round(COST_WIN(2)*fs);
    nPre = round(-PLOT_WIN(1)*fs);
    nPost= round( PLOT_WIN(2)*fs);

    costTr = nan(nUse,1);  ic0 = nan(nUse,1);
    traces = nan(nUse, nPre+nPost+1);
    for j = 1:nUse
        [~, i0] = min(abs(t - d.stimStarts(j)));
        if i0+n3 > numel(dFk) || i0-nPre < 1 || i0+nPost > numel(dFk); continue; end
        seg        = dFk(i0 : i0+n3);
        costTr(j)  = norm(seg - ref);            % L2 deviation from setpoint over 0..3 s
        ic0(j)     = dFk(i0);
        traces(j,:)= dFk(i0-nPre : i0+nPost);
    end
    gate = abs(ic0) <= IC_GATE;                  % baseline-clean trials

    [C,~,ic] = unique(gains, 'rows');
    nNode = zeros(size(C,1),1); J = nan(size(C,1),1); Jsem = J;
    nodeMean = nan(size(C,1), size(traces,2)); nodeStd = nodeMean;
    for k = 1:size(C,1)
        sel = (ic==k) & gate & ~isnan(costTr);
        nNode(k)      = nnz(sel);
        J(k)          = mean(costTr(sel));
        Jsem(k)       = std(costTr(sel)) / sqrt(max(nNode(k),1));
        nodeMean(k,:) = mean(traces(sel,:), 1, 'omitnan');
        nodeStd(k,:)  = std(traces(sel,:), 0, 1, 'omitnan');
    end

    rec = struct();
    rec.mn=s.mn; rec.td=s.td; rec.en=s.en; rec.ref=ref; rec.fs=fs;
    rec.tt = (-nPre:nPost)/fs;                   % plot time vector (s)
    rec.C = C; rec.J = J; rec.Jsem = Jsem; rec.nNode = nNode;
    rec.nodeMean = nodeMean; rec.nodeStd = nodeStd;
    rec.trial = (1:nUse)'; rec.Kp = gains(:,1); rec.Ki = gains(:,2);
    rec.costTr = costTr; rec.gate = gate;
    if isempty(S); S = rec; else; S(end+1) = rec; end %#ok<AGROW>

    fprintf('  trials=%d (gated %d) | nodes=%d | Kp[%g %g] Ki[%g %g] | Jmin=%.3g\n', ...
        nUse, nnz(gate), size(C,1), min(C(:,1)), max(C(:,1)), min(C(:,2)), max(C(:,2)), min(J));
end
end
