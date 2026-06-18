% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).

PS = paperStyle();
setPaperDefaults();

% Resolve paper/ root -- works whether run from brain_paper/ or controller-analysis/
if exist(fullfile('paper', 'images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..', 'paper', 'images'), 'dir')
    paper_root = fullfile('..', 'paper');
else
    paper_root = 'paper';
    warning('motion_analysis: cannot locate paper/ directory -- paths may be incorrect.');
end

%% Pre-stim state vs trial MSE -- OL/CL all sessions pooled
% Scientific question: does trial MSE scale with how far Î”F/F was from the
% reference at stim onset?  OL: no feedback â†’ expect positive slope.
% CL: feedback active â†’ slope should be attenuated or flat.
%
% X: |Î”F/F at stim onset âˆ’ ref|  (abs, %)     = abs(ncDfk(:, c0_g2) âˆ’ d.ref)
% Y: trial MSE (t = 0 to +3 s)                = er_ncDfk / er_wcDfk
% Requires G2 section to have run first (c0_g2 = 36 defined there).

allNcDev_ps = [];  allNcMse_ps = [];
allWcDev_ps = [];  allWcMse_ps = [];

for k = 1:length(fields)
    if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
    if ~isfield(mouse.(fields{k}), 'data');                           continue; end
    dk_ps  = mouse.(fields{k}).data;
    ref_ps = mouse.(fields{k}).d.ref;

    allNcDev_ps = [allNcDev_ps; abs(dk_ps.ncDfk(:, c0_g2) - ref_ps)];
    allNcMse_ps = [allNcMse_ps; dk_ps.er_ncDfk];
    allWcDev_ps = [allWcDev_ps; abs(dk_ps.wcDfk(:, c0_g2) - ref_ps)];
    allWcMse_ps = [allWcMse_ps; dk_ps.er_wcDfk];
end

% --- bin pooled trials into 4 quartiles of |deviation| (edges from OL+CL combined) ---
nBins_ps  = 4;
edges_ps  = quantile([allNcDev_ps; allWcDev_ps], linspace(0, 1, nBins_ps+1));

binIdx_nc_ps = discretize(allNcDev_ps, edges_ps);
binIdx_nc_ps(isnan(binIdx_nc_ps)) = nBins_ps;
binIdx_wc_ps = discretize(allWcDev_ps, edges_ps);
binIdx_wc_ps(isnan(binIdx_wc_ps)) = nBins_ps;

nc_bin_ps = cell(nBins_ps, 1);
wc_bin_ps = cell(nBins_ps, 1);
for b = 1:nBins_ps
    nc_bin_ps{b} = allNcMse_ps(binIdx_nc_ps == b);
    wc_bin_ps{b} = allWcMse_ps(binIdx_wc_ps == b);
end

nc_mean_ps = cellfun(@mean,                       nc_bin_ps);
nc_sem_ps  = cellfun(@(x) std(x)/sqrt(numel(x)), nc_bin_ps);
wc_mean_ps = cellfun(@mean,                       wc_bin_ps);
wc_sem_ps  = cellfun(@(x) std(x)/sqrt(numel(x)), wc_bin_ps);


% --- paper figure â†’ Figure 4 ---
fig_ps_mse = paperFig(6, 4);
ax_ps      = axes(fig_ps_mse, 'Units','normalized', 'Position',[0.18 0.22 0.76 0.60]);
hold(ax_ps, 'on');

xb_ps = 1:nBins_ps;
errorbar(ax_ps, xb_ps - 0.1, nc_mean_ps, nc_sem_ps, 'o-', 'Color', colOL, ...
    'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName','Open-Loop');
errorbar(ax_ps, xb_ps + 0.1, wc_mean_ps, wc_sem_ps, 'o-', 'Color', colCL, ...
    'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName','Closed-Loop');


xlim(ax_ps, [0.5, nBins_ps + 0.5]);
xticks(ax_ps, xb_ps);
xticklabels(ax_ps, {'Q1','Q2','Q3','Q4'});
lgd_ps = legend(ax_ps, 'Box','off', 'Location','northwest');
paperLegend(lgd_ps);
xlabel(ax_ps, '|\DeltaF/F_0 - r| at trial onset (quartile)', 'FontWeight', 'bold');
ylabel(ax_ps, 'Trial MSE (t = 0 to +3 s)', 'FontWeight', 'bold');
hold(ax_ps, 'off');

paperExport(fig_ps_mse, fullfile(paper_root, 'images', 'figure4', 'prestim_dev_vs_mse.pdf'));

%% Motion vs MSE -- three analysis modes
% onset_col is derived dynamically per session:
%   onset_col = size(ncmotion,2) - 35*dur
% This works regardless of which controllerData window is stored.
%
% Three modes (pre_secs=0 means start at onset, post_secs=0 means end at onset):
%   1. combined   -- 2s pre-trial + full trial
%   2. pre_trial  -- 3s before onset only
%   3. during     -- trial onset to trial end only

motModes(1).label     = 'combined';
motModes(1).pre_secs  = 2;
motModes(1).post_secs = -1;   % -1 = use dur (trial end) per session

motModes(2).label     = 'pre_trial_3s';
motModes(2).pre_secs  = 3;
motModes(2).post_secs = 0;

motModes(3).label     = 'during_trial';
motModes(3).pre_secs  = 0;
motModes(3).post_secs = -1;

colOL = PS.col_ol;
colCL = PS.col_cl;
nBins = 4;
nSess = length(fields);
nCols = 4;
nRows = ceil(nSess / nCols);

for m = 1:length(motModes)
    mode = motModes(m);

    allBin_nc_mse = cell(nBins, 1);
    allBin_wc_mse = cell(nBins, 1);
    for b = 1:nBins; allBin_nc_mse{b} = []; allBin_wc_mse{b} = []; end

    PW_fS = nCols*7.5; PH_fS = nRows*7.5;
    figS = figure('Color','w', 'Units','centimeters', 'Position',[0 0 PW_fS PH_fS]);

    spIdx = 0;
    for k = 1:nSess
        if isfield(mouse.(fields{k}), 'skip'),        continue; end
        if ~isfield(mouse.(fields{k}), 'data'),       continue; end
        if ~mouse.(fields{k}).has_motion,             continue; end

        data_k  = mouse.(fields{k}).data;
        dur_k   = mouse.(fields{k}).d.params.dur;
        n_cols  = size(data_k.ncmotion, 2);

        % derive onset column from stored window size -- works for any stored window
        onset_col = n_cols - 35 * dur_k;

        post_cols = dur_k * 35;
        if mode.post_secs ~= -1; post_cols = round(mode.post_secs * 35); end

        win_start = max(1,      onset_col - round(mode.pre_secs  * 35));
        win_end   = min(n_cols, onset_col + post_cols);

        % raw z-scored mean over selected window
        ncm = mean(data_k.ncmotion(:, win_start:win_end), 2);
        wcm = mean(data_k.wcmotion(:, win_start:win_end), 2);
        enc = data_k.er_ncDfk;
        ewc = data_k.er_wcDfk;

        allMot = [ncm; wcm];
        allMse = [enc; ewc];
        allLbl = [zeros(numel(ncm),1); ones(numel(wcm),1)];

        edges  = quantile(allMot, [0 0.25 0.5 0.75 1]);
        binIdx = discretize(allMot, edges);
        binIdx(isnan(binIdx)) = nBins;

        spIdx = spIdx + 1;
        ax = subplot(nRows, nCols, spIdx); hold on;

        scatter(ax, ncm, enc, 20, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.6, 'HandleVisibility','off');
        scatter(ax, wcm, ewc, 20, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.6, 'HandleVisibility','off');

        xAll = [ncm; wcm];
        xr   = linspace(min(xAll), max(xAll), 100);
        if numel(ncm) > 1
            plot(ax, xr, polyval(polyfit(ncm, enc, 1), xr), '-', 'Color', colOL, 'LineWidth', 1.5, 'HandleVisibility','off');
        end
        if numel(wcm) > 1
            plot(ax, xr, polyval(polyfit(wcm, ewc, 1), xr), '-', 'Color', colCL, 'LineWidth', 1.5, 'HandleVisibility','off');
        end

        title(ax, sprintf('%s %s e%d', mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en), ...
            'FontSize', 6, 'FontWeight','bold', 'Interpreter','none');
        set(ax, 'Box','off', 'TickDir','out', 'XTick',[], 'YTick',[]);

        for b = 1:nBins
            allBin_nc_mse{b} = [allBin_nc_mse{b}; allMse(binIdx == b & allLbl == 0)];
            allBin_wc_mse{b} = [allBin_wc_mse{b}; allMse(binIdx == b & allLbl == 1)];
        end
    end

    xlabel(ax, 'Motion (z-scored)', 'FontWeight','bold', 'FontSize', 6);
    ylabel(ax, 'MSE ||e||',         'FontWeight','bold', 'FontSize', 6);
    paperExport(figS, fullfile(paper_root, sprintf('motion_scatter_%s.png', mode.label)));

    % pooled quartile figure for this mode
    figQ = figure('Color','w', 'Units','centimeters', 'Position',[0 0 13 10]);
    hold on;

    nc_pool_mean = cellfun(@mean,                       allBin_nc_mse);
    nc_pool_sem  = cellfun(@(x) std(x)/sqrt(numel(x)), allBin_nc_mse);
    wc_pool_mean = cellfun(@mean,                       allBin_wc_mse);
    wc_pool_sem  = cellfun(@(x) std(x)/sqrt(numel(x)), allBin_wc_mse);

    xb = 1:nBins;
    errorbar(xb-0.1, nc_pool_mean, nc_pool_sem, 'o-', 'Color', colOL, ...
        'LineWidth', 2, 'MarkerSize', 6, 'CapSize', 4, 'DisplayName', 'Open-Loop');
    errorbar(xb+0.1, wc_pool_mean, wc_pool_sem, 'o-', 'Color', colCL, ...
        'LineWidth', 2, 'MarkerSize', 6, 'CapSize', 4, 'DisplayName', 'Closed-Loop');

    xlim([0.5 nBins+0.5]);
    xticks(xb);
    xticklabels({'Q1 (low)', 'Q2', 'Q3', 'Q4 (high)'});
    legend('Box','off', 'Location','northwest', 'FontSize', 6, 'FontWeight','bold');
    xlabel(sprintf('Motion quartile -- %s', strrep(mode.label,'_',' ')), 'FontWeight','bold');
    ylabel('MSE  ||e||', 'FontWeight','bold');
    set(gca, 'Box','off', 'TickDir','out');
    paperExport(figQ, fullfile(paper_root, sprintf('motion_quartile_%s.png', mode.label)));

    % ---- paper panel (combined mode only) â†’ Figure 4 ----
    if strcmp(mode.label, 'combined')
        figQp  = paperFig(6, 4);
        ax_qp  = axes(figQp); hold(ax_qp, 'on');

        errorbar(ax_qp, xb-0.1, nc_pool_mean, nc_pool_sem, 'o-', 'Color', colOL, ...
            'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName', 'Open-Loop');
        errorbar(ax_qp, xb+0.1, wc_pool_mean, wc_pool_sem, 'o-', 'Color', colCL, ...
            'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName', 'Closed-Loop');

        xlim(ax_qp, [0.5 nBins+0.5]);
        xticks(ax_qp, xb);
        xticklabels(ax_qp, {'Q1','Q2','Q3','Q4'});
        xlabel(ax_qp, 'Motion quartile (combined window)', 'FontWeight', 'bold');
        ylabel(ax_qp, 'MSE ||e|| (t = 0 to +3 s)', 'FontWeight', 'bold');
        paperExport(figQp, fullfile(paper_root, 'images', 'figure4', 'motion_quartile_combined.pdf'));
    end
end

%% Interactive motion scatter -- combined mode (click a point to inspect trial)
% Uses motModes(1) window. Click any point to open a dFk + input trace figure.
close all;
iMode       = motModes(1);

figI = figure('Color','w', 'Name','Interactive Motion Scatter');
figI.Units    = 'inches';
figI.Position = [1, 1, nCols*3, nRows*3];

spIdx = 0;
for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),        continue; end
    if ~isfield(mouse.(fields{k}), 'data'),       continue; end
    if ~mouse.(fields{k}).has_motion,             continue; end

    data_k  = mouse.(fields{k}).data;
    dur_k   = mouse.(fields{k}).d.params.dur;
    n_cols  = size(data_k.ncmotion, 2);
    onset_col = n_cols - 35 * dur_k;

    post_cols = dur_k * 35;
    win_start = max(1,      onset_col - round(iMode.pre_secs * 35));
    win_end   = min(n_cols, onset_col + post_cols);

    ncm = mean(data_k.ncmotion(:, win_start:win_end), 2);
    wcm = mean(data_k.wcmotion(:, win_start:win_end), 2);
    enc = data_k.er_ncDfk;
    ewc = data_k.er_wcDfk;

    spIdx = spIdx + 1;
    ax = subplot(nRows, nCols, spIdx); hold on;

    % OL scatter -- store per-point metadata in UserData
    ud_nc = struct( ...
        'field',    repmat(fields(k), numel(data_k.nc), 1), ...
        'stim_idx', num2cell(data_k.nc(:)), ...
        'lbl',      repmat({'OL'}, numel(data_k.nc), 1), ...
        'mse',      num2cell(enc(:)));
    sc_nc = scatter(ax, ncm, enc, 25, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.6);
    sc_nc.UserData    = ud_nc;
    sc_nc.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    % CL scatter
    ud_wc = struct( ...
        'field',    repmat(fields(k), numel(data_k.wc), 1), ...
        'stim_idx', num2cell(data_k.wc(:)), ...
        'lbl',      repmat({'CL'}, numel(data_k.wc), 1), ...
        'mse',      num2cell(ewc(:)));
    sc_wc = scatter(ax, wcm, ewc, 25, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.6);
    sc_wc.UserData    = ud_wc;
    sc_wc.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    title(ax, sprintf('%s %s e%d', mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en), ...
        'FontSize', 7, 'FontWeight','bold', 'Interpreter','none');
    set(ax, 'Box','off', 'TickDir','out', 'XTick',[], 'YTick',[]);
end

xlabel(ax, 'Motion (z-scored)', 'FontWeight','bold', 'FontSize', 9);
ylabel(ax, 'MSE ||e||',         'FontWeight','bold', 'FontSize', 9);

fprintf('Interactive scatter ready -- click any point to inspect that trial.\n');
