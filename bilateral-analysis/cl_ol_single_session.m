% bilateral-analysis/cl_ol_single_session.m
% ------------------------------------------------------------------------
% STANDALONE single-session controller analysis (CL vs OL) for one AL_0048
% bilateral session. Self-contained: does NOT depend on load_bilateral.m or
% the multi-session sessions{} pipeline — run this file directly.
%
% It reproduces the classic single-session controller comparison
% (analysisPlots_combined: open-loop vs closed-loop) but generalised to the
% dual-opsin bilateral case: it loops over whichever hemispheres have a
% selected pixel and analyses each side independently with its own reference.
%
% Per side it produces:
%   Fig 1  all-trials + mean trace          (OL panel | CL panel)
%   Fig 2  variance across trials over time  (OL vs CL)
%   Fig 3  trial-MSE half-violin            (OL vs CL)
% plus a console summary of MSE (mean / median) and the OL/CL ratio.
%
% Run from the brain_paper/ root (or from bilateral-analysis/ — it will cd up).
% Requires server access for initialize_data (same as load_bilateral.m).
% ------------------------------------------------------------------------

%% ---- Workspace ---------------------------------------------------------
clc; close all; clear all;
if ~isfolder('bilateral-analysis') && isfolder(fullfile('..', 'bilateral-analysis'))
    cd('..');
end
addpath(genpath('utils'));

%% ---- Session knobs -----------------------------------------------------
MN  = 'AL_0048';
TD  = '2026-06-20';   % YYYY-MM-DD
EN  = 2;              % experiment number

dur    = 3;           % controller / MSE window (s): t = 0 to +dur post-onset
fs_img = 35;          % imaging frame rate (Hz)
r_load = 1;           % 1 = use assembled-session cache if present | 0 = recompute

%% ---- Reference levels (per side, signed) -------------------------------
% Left = excitatory opsin (ref > 0); Right = inhibitory opsin (ref < 0).
REF_L = +5;
REF_R = -5;

%% ---- OL / CL trial flag  (VERIFY against the diagnostic printout!) ------
% Classic controller sessions store the open/closed-loop flag in
% input_params column 3 (0 = open-loop, 1 = closed-loop). For AL_0048 the
% bilateral column map lists col 3 = trial_type and col 4 = hemisphere, so
% the flag column for a *controller* session may differ. This script prints
% the unique values of every input_params column on load — confirm which
% column is the 0/1 OL-CL flag and set OLCL_COL / OL_CODE / CL_CODE here.
OLCL_COL = 3;         % column holding the open/closed-loop flag
OL_CODE  = 0;         % value meaning open-loop
CL_CODE  = 1;         % value meaning closed-loop

%% ---- Hemisphere (side) trial filter ------------------------------------
% Bilateral sessions interleave left- and right-hemisphere stim trials. Each
% side's controller is analysed only on its own trials. Set USE_SIDE_FILTER
% = false to pool all trials against a single pixel (classic behaviour).
USE_SIDE_FILTER = true;
HEMI_COL        = 4;  % input_params column encoding hemisphere
SIGN_L          = +1; % hemi*SIGN_L > 0  -> left ; < 0 -> right (flip if inverted)

EXPORT_FIG = false;   % true -> PNGs to paper/images/bilateral/
% ------------------------------------------------------------------------


%% ===== Load / assemble session =========================================
cachePath = fullfile('data', sprintf('%s_clol_%s%s%d.mat', MN, TD(6:7), TD(9:10), EN));

if exist(cachePath, 'file') && r_load == 1
    S = load(cachePath);
    d     = S.d;
    sides = S.sides;
    fprintf('Loaded assembled-session cache: %s\n', cachePath);
else
    d = initialize_data(MN, EN, TD);
    if ~isfield(d, 'ref'); d.ref = -5; end

    % --- Per-side pixel dF/F -------------------------------------------------
    % Prefer the bilateral pixel cache (stores per-side dFoF directly); fall
    % back to getpixel_dFoF on the stored pixel coordinates.
    pixCache = fullfile('data', sprintf('%s_bil_pix_%s%s%d.mat', MN, TD(6:7), TD(9:10), EN));
    sides = struct('name', {}, 'ref', {}, 'pix', {}, 'dFoF', {});

    if exist(pixCache, 'file')
        P = load(pixCache);
        for i = 1:numel(P.pixels)
            px = P.pixels(i);
            if ~ismember(px.side, {'left', 'right'}); continue; end
            sides(end+1) = struct('name', px.side, ...
                'ref', refForSide(px.side, REF_L, REF_R), ...
                'pix', px.pix, 'dFoF', double(px.dFoF(:)')); %#ok<SAGROW>
        end
        fprintf('Loaded per-side dF/F from pixel cache: %s (%d sides)\n', ...
            pixCache, numel(sides));
    else
        error(['No pixel cache %s found. Run the bilateral pixel-selection ' ...
               'step first, or point this script at the correct pixel cache.'], pixCache);
    end

    if ~exist('data', 'dir'); mkdir('data'); end
    save(cachePath, 'd', 'sides', '-v7.3');
    fprintf('Saved assembled-session cache: %s\n', cachePath);
end

%% ===== input_params diagnostic =========================================
ip = d.input_params;
fprintf('\ninput_params: %d trials x %d cols. Unique values per column:\n', ...
    size(ip,1), size(ip,2));
for c = 1:size(ip,2)
    u = unique(ip(:,c));
    if numel(u) <= 8
        fprintf('  col %d: %s\n', c, mat2str(u(:)'));
    else
        fprintf('  col %d: %d unique (min %.3g, max %.3g)\n', c, numel(u), min(u), max(u));
    end
end
fprintf('Using OL/CL flag = col %d (OL=%g, CL=%g); side filter = col %d (%s)\n\n', ...
    OLCL_COL, OL_CODE, CL_CODE, HEMI_COL, mat2str(USE_SIDE_FILTER));


%% ===== Per-side controller analysis ====================================
PS = paperStyle();
t      = d.timeBlue(:)';
n_pre  = round(3 * fs_img);          % 3 s pre-onset
n_win  = round((dur + 3) * fs_img);  % onset .. dur+3 s
n_err  = round(dur * fs_img);        % MSE window (0 .. dur)
T      = (-n_pre : n_win) / fs_img;  % trace time axis
Tref   = (0 : n_err) / fs_img;

results = struct();

for si = 1:numel(sides)
    sd   = sides(si);
    dFoF = sd.dFoF;
    ref  = sd.ref;
    if numel(dFoF) ~= numel(t)
        warning('[%s] dFoF length (%d) ~= timeBlue length (%d) — using min overlap.', ...
            sd.name, numel(dFoF), numel(t));
    end

    % --- trial selection: hemisphere then OL/CL ---------------------------
    nTr = size(ip, 1);
    if USE_SIDE_FILTER && size(ip,2) >= HEMI_COL
        hemi = ip(:, HEMI_COL);
        if strcmp(sd.name, 'left')
            sideMask = hemi * SIGN_L > 0;
        else
            sideMask = hemi * SIGN_L < 0;
        end
    else
        sideMask = true(nTr, 1);
    end

    olMask = sideMask & ip(:, OLCL_COL) == OL_CODE;
    clMask = sideMask & ip(:, OLCL_COL) == CL_CODE;
    nc = find(olMask);   % open-loop trial indices
    wc = find(clMask);   % closed-loop trial indices

    if isempty(nc) && isempty(wc)
        fprintf('[%s] no OL/CL trials after filtering — skipping.\n', sd.name);
        continue;
    end

    % --- window each trial: pre .. dur+3 s; MSE over 0 .. dur -------------
    [ncTr, er_nc] = sliceTrials(dFoF, t, d.stimStarts, nc, n_pre, n_win, n_err, ref);
    [wcTr, er_wc] = sliceTrials(dFoF, t, d.stimStarts, wc, n_pre, n_win, n_err, ref);

    results.(sd.name).nc     = nc;     results.(sd.name).wc     = wc;
    results.(sd.name).ncTr   = ncTr;   results.(sd.name).wcTr   = wcTr;
    results.(sd.name).er_nc  = er_nc;  results.(sd.name).er_wc  = er_wc;
    results.(sd.name).ref    = ref;

    fprintf('[%s] OL: %d trials, MSE mean=%.3f median=%.3f | CL: %d trials, MSE mean=%.3f median=%.3f | OL/CL=%.2f\n', ...
        sd.name, numel(nc), mean(er_nc,'omitnan'), median(er_nc,'omitnan'), ...
        numel(wc), mean(er_wc,'omitnan'), median(er_wc,'omitnan'), ...
        mean(er_nc,'omitnan')/mean(er_wc,'omitnan'));

    %% ---- Fig 1: all trials + mean (OL | CL) ----------------------------
    f1 = paperFig(9, 4);
    set(f1, 'Name', sprintf('CLvsOL traces | %s | %s', sd.name, MN));
    axOL = axes(f1, 'Position', [0.08 0.14 0.42 0.74]);
    axCL = axes(f1, 'Position', [0.55 0.14 0.42 0.74]);
    drawTracePanel(axOL, T, ncTr, ref, dur, PS.col_ol, PS, ...
        sprintf('Open-Loop (%s)', sd.name));
    drawTracePanel(axCL, T, wcTr, ref, dur, PS.col_cl, PS, ...
        sprintf('Closed-Loop (%s)', sd.name));
    linkaxes([axOL axCL], 'xy');

    %% ---- Fig 2: variance over time (OL vs CL) --------------------------
    f2 = paperFig(6, 4);
    set(f2, 'Name', sprintf('CLvsOL variance | %s | %s', sd.name, MN));
    ax2 = axes(f2, 'Position', [0.15 0.14 0.80 0.78]);
    hold(ax2, 'on');
    if ~isempty(ncTr)
        plot(ax2, T, var(ncTr, 0, 1), 'Color', PS.col_ol, 'LineWidth', PS.lw_mean, 'DisplayName','OL');
    end
    if ~isempty(wcTr)
        plot(ax2, T, var(wcTr, 0, 1), 'Color', PS.col_cl, 'LineWidth', PS.lw_mean, 'DisplayName','CL');
    end
    xline(ax2, 0, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    xline(ax2, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    addStimPatch(ax2, 0, dur);
    uistack(findobj(ax2,'Type','line'), 'top');
    hold(ax2, 'off');
    xlim(ax2, [-3 dur+3]);
    xlabel(ax2, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax2, 'Variance across trials', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax2, sprintf('%s | %s', sd.name, MN), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    lgd2 = legend(ax2, 'Location', 'best'); paperLegend(lgd2);

    %% ---- Fig 3: trial-MSE half-violin (OL vs CL) -----------------------
    f3 = paperFig(3, 4);
    set(f3, 'Name', sprintf('CLvsOL MSE | %s | %s', sd.name, MN));
    ax3 = axes(f3, 'Position', [0.18 0.15 0.77 0.75]);
    hold(ax3, 'on');
    hw = 0.3;
    if numel(er_nc) > 1
        [fA, yA] = ksdensity(er_nc); fA = fA / max(fA) * hw;
        fill(ax3, [1 - fA, ones(1,numel(fA))], [yA, fliplr(yA)], PS.col_ol, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax3, 1 - 0.1, mean(er_nc,'omitnan'), '*', 'Color', PS.col_ol, ...
            'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');
    end
    if numel(er_wc) > 1
        [fB, yB] = ksdensity(er_wc); fB = fB / max(fB) * hw;
        fill(ax3, [1 + fB, ones(1,numel(fB))], [yB, fliplr(yB)], PS.col_cl, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax3, 1 + 0.1, mean(er_wc,'omitnan'), '*', 'Color', PS.col_cl, ...
            'MarkerSize', 5, 'LineWidth', 1, 'HandleVisibility','off');
    end
    hold(ax3, 'off');
    xlim(ax3, [0.5 1.5]); ax3.XTick = [];
    ylabel(ax3, 'Trial MSE  (||\DeltaF/F - ref||)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax3, sprintf('%s', sd.name), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    set(ax3, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);

    %% ---- Optional export -----------------------------------------------
    if EXPORT_FIG
        outDir = fullfile('paper', 'images', 'bilateral');
        if ~exist(outDir, 'dir'); mkdir(outDir); end
        exportgraphics(f1, fullfile(outDir, sprintf('clol_traces_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        exportgraphics(f2, fullfile(outDir, sprintf('clol_variance_%s_%s.png', MN, sd.name)), 'Resolution', 300);
        exportgraphics(f3, fullfile(outDir, sprintf('clol_mse_%s_%s.png', MN, sd.name)), 'Resolution', 300);
    end
end

fprintf('\ncl_ol_single_session.m complete for %s %s exp %d.\n', MN, TD, EN);


%% ===== Local helpers ===================================================
function r = refForSide(side, refL, refR)
    if strcmp(side, 'left'); r = refL; else; r = refR; end
end

function [traces, err] = sliceTrials(dFoF, t, stimStarts, idx, n_pre, n_win, n_err, ref)
% Window each trial around stim onset and compute per-trial MSE (norm to ref
% over the 0..dur window). Skips trials whose window runs off either edge.
    traces = [];
    err    = NaN(numel(idx), 1);
    for j = 1:numel(idx)
        [~, i0] = min(abs(t - stimStarts(idx(j))));
        if i0 - n_pre < 1 || i0 + n_win > numel(dFoF); continue; end
        traces      = [traces; dFoF(i0 - n_pre : i0 + n_win)]; %#ok<AGROW>
        seg         = dFoF(i0 : i0 + n_err);
        err(j)      = norm(seg - ref);
    end
end

function drawTracePanel(ax, T, traces, ref, dur, col, PS, ttl)
% All-trials (faint) + mean (+/- std ribbon) + reference, with stim patch.
    hold(ax, 'on');
    if ~isempty(traces)
        mu = mean(traces, 1);
        sd = std(traces, 0, 1);
        fill(ax, [T fliplr(T)], [mu+sd fliplr(mu-sd)], col, ...
            'FaceAlpha', PS.fa, 'EdgeColor','none', 'HandleVisibility','off');
        plot(ax, T, traces', 'Color', [0.7 0.7 0.7], 'LineWidth', PS.lw_trial, 'HandleVisibility','off');
        plot(ax, T, mu, 'Color', col, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
    end
    plot(ax, [0 dur], [ref ref], '--k', 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
    xline(ax, 0, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    xline(ax, dur, 'LineWidth', PS.lw_zero, 'HandleVisibility','off');
    addStimPatch(ax, 0, dur);
    uistack(findobj(ax,'Type','line'), 'top');
    hold(ax, 'off');
    xlim(ax, [-3 dur+3]);
    xlabel(ax, 'Time (s)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    ylabel(ax, '\DeltaF/F (%)', 'FontSize', PS.fs, 'FontWeight', PS.fw);
    title(ax, ttl, 'FontSize', PS.fs, 'FontWeight', PS.fw);
    set(ax, 'Box','off', 'TickDir','out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
end
