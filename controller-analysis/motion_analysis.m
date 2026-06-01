% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).

PS = paperStyle();
setPaperDefaults();

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
    'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName','OL');
errorbar(ax_ps, xb_ps + 0.1, wc_mean_ps, wc_sem_ps, 'o-', 'Color', colCL, ...
    'LineWidth', PS.lw_mean, 'MarkerSize', 3, 'CapSize', 3, 'DisplayName','CL');


xlim(ax_ps, [0.5, nBins_ps + 0.5]);
xticks(ax_ps, xb_ps);
xticklabels(ax_ps, {'Q1','Q2','Q3','Q4'});
lgd_ps = legend(ax_ps, 'Box','off', 'Location','northwest');
paperLegend(lgd_ps);
xlabel(ax_ps, '|{\DeltaF/F} at onset \minus ref| quartile', 'FontWeight', 'bold');
ylabel(ax_ps, 'Trial MSE (t = 0 to +3 s)', 'FontWeight', 'bold');
hold(ax_ps, 'off');

paperExport(fig_ps_mse, 'paper/images/figure4/prestim_dev_vs_mse.pdf');

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
        if isfield(mouse.(fields{k}), 'skip'),       continue; end
        if ~isfield(mouse.(fields{k}), 'data'),      continue; end
        if ~any(mouse.(fields{k}).data.ncmotion(:)), continue; end

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
    paperExport(figS, sprintf('paper/motion_scatter_%s.png', mode.label));

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
    paperExport(figQ, sprintf('paper/motion_quartile_%s.png', mode.label));

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
        lgd_qp = legend(ax_qp, 'Box','off', 'Location','northwest');
        paperLegend(lgd_qp);
        xlabel(ax_qp, 'Motion quartile (combined window)', 'FontWeight', 'bold');
        ylabel(ax_qp, 'MSE ||e|| (t = 0 to +3 s)', 'FontWeight', 'bold');
        paperExport(figQp, 'paper/images/figure4/motion_quartile_combined.pdf');
    end
end

%% Raw motion traces -- sessions with face video

sessColors = lines(nSess);

fig = figure('Color','w', 'Units','centimeters', 'Position',[0 0 35 6]);
hold on;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'd'),    continue; end
    if ~any(mouse.(fields{k}).d.motion(:)), continue; end

    t_k = mouse.(fields{k}).d.timeBlue;
    m_k = mouse.(fields{k}).d.motion;
    nPts = min(numel(t_k), numel(m_k));
    t_k  = t_k(1:nPts);
    m_k  = m_k(1:nPts);
    plot(t_k - t_k(1), m_k, 'Color', [sessColors(k,:) 0.7], 'LineWidth', 0.8, ...
        'DisplayName', sprintf('%s %s e%d', mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en));
end

legend('Box','off', 'Location','eastoutside', 'FontSize',6, 'Interpreter','none');
xlabel('Time (s)',           'FontWeight','bold');
ylabel('Motion (z-scored)',  'FontWeight','bold');
set(gca, 'Box','off', 'TickDir','out');
paperExport(fig, 'paper/motion_traces.png');

%% Combined motion vs MSE -- all sessions pooled (combined window)
iMode = motModes(1);   % 2 s pre + full trial

allNcMot = []; allNcMse = [];
allWcMot = []; allWcMse = [];

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),       continue; end
    if ~isfield(mouse.(fields{k}), 'data'),      continue; end
    if ~any(mouse.(fields{k}).data.ncmotion(:)), continue; end

    data_k    = mouse.(fields{k}).data;
    dur_k     = mouse.(fields{k}).d.params.dur;
    n_cols    = size(data_k.ncmotion, 2);
    onset_col = n_cols - 35 * dur_k;
    post_cols = dur_k * 35;
    win_start = max(1,      onset_col - round(iMode.pre_secs * 35));
    win_end   = min(n_cols, onset_col + post_cols);

    allNcMot = [allNcMot; mean(data_k.ncmotion(:, win_start:win_end), 2)];
    allNcMse = [allNcMse; data_k.er_ncDfk];
    allWcMot = [allWcMot; mean(data_k.wcmotion(:, win_start:win_end), 2)];
    allWcMse = [allWcMse; data_k.er_wcDfk];
end

figC = figure('Color','w', 'Units','centimeters', 'Position',[0 0 6 4]);
hold on;

scatter(allNcMot, allNcMse, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');
scatter(allWcMot, allWcMse, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');

xAll = [allNcMot; allWcMot];
xr   = linspace(min(xAll), max(xAll), 100);
pNC = [0 0]; pWC = [0 0];
if numel(allNcMot) > 1
    pNC = polyfit(allNcMot, allNcMse, 1);
    plot(xr, polyval(pNC, xr), '-', 'Color', colOL, 'LineWidth', 1.5, 'DisplayName','Open-Loop');
end
if numel(allWcMot) > 1
    pWC = polyfit(allWcMot, allWcMse, 1);
    plot(xr, polyval(pWC, xr), '-', 'Color', colCL, 'LineWidth', 1.5, 'DisplayName','Closed-Loop');
end

ax = gca;
xl = xlim(ax); yl = ylim(ax);
text(xl(2), yl(2) - 0.05*(yl(2)-yl(1)), sprintf('slope OL = %.3f', pNC(1)), ...
    'Color', colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(xl(2), yl(2) - 0.18*(yl(2)-yl(1)), sprintf('slope CL = %.3f', pWC(1)), ...
    'Color', colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
xlabel('Motion (z-scored)', 'FontWeight','bold', 'FontSize',6);
ylabel('MSE  ||e||',        'FontWeight','bold', 'FontSize',6);
set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
paperExport(figC, 'paper/motion_mse_combined.png');

%% Onset deviation vs windowed MSE scatter (fig_onset_dev)
% Scientific question: does OL MSE increase steeply with initial deviation
% while CL MSE stays flat? A flat CL slope = feedback decouples initial
% brain state from outcome.
%
% X: |Î”F/F at t=0 (stim onset)| = abs(ncDfk(:, c0_g2)) / abs(wcDfk(:, c0_g2))
% Y: windowed MSE t=+1 to +3 s   = er_ncDfk_w / er_wcDfk_w (from G2 section)
% Requires G2 section to have run first (er_ncDfk_w stored in mouse.*.data).

% Pool across all sessions
allNcDev_od  = [];   allNcMse_od  = [];
allWcDev_od  = [];   allWcMse_od  = [];

for k = 1:length(fields)
    if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
    if ~isfield(mouse.(fields{k}), 'data');                           continue; end
    dk_od = mouse.(fields{k}).data;
    if ~isfield(dk_od, 'er_ncDfk_w') || ~isfield(dk_od, 'er_wcDfk_w'); continue; end

    % |Î”F/F at stim onset| -- c0_g2 = col 36 = t=0
    nc_dev_od = abs(dk_od.ncDfk(:, c0_g2));
    wc_dev_od = abs(dk_od.wcDfk(:, c0_g2));

    allNcDev_od = [allNcDev_od; nc_dev_od];
    allNcMse_od = [allNcMse_od; dk_od.er_ncDfk_w];
    allWcDev_od = [allWcDev_od; wc_dev_od];
    allWcMse_od = [allWcMse_od; dk_od.er_wcDfk_w];
end

fig_onset_dev = paperFig(6, 4);
ax_od = axes(fig_onset_dev, 'Units','normalized', 'Position',[0.18 0.18 0.78 0.74]);
hold(ax_od, 'on');

scatter(ax_od, allNcDev_od, allNcMse_od, 8, colOL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');
scatter(ax_od, allWcDev_od, allWcMse_od, 8, colCL, 'o', 'filled', ...
    'MarkerFaceAlpha', 0.3, 'HandleVisibility','off');

% Linear regression for OL
pNC_od = [0 0];  rSq_NC_od = 0;  slope_se_NC_od = 0;
if numel(allNcDev_od) > 2
    X_nc_od  = [ones(numel(allNcDev_od),1), allNcDev_od];
    b_nc_od  = X_nc_od \ allNcMse_od;
    yhat_nc  = X_nc_od * b_nc_od;
    ss_res   = sum((allNcMse_od - yhat_nc).^2);
    ss_tot   = sum((allNcMse_od - mean(allNcMse_od)).^2);
    rSq_NC_od = 1 - ss_res / ss_tot;
    % SE of slope via OLS formula
    sigma2_nc    = ss_res / (numel(allNcMse_od) - 2);
    slope_se_NC_od = sqrt(sigma2_nc / sum((allNcDev_od - mean(allNcDev_od)).^2));
    pNC_od = [b_nc_od(2), b_nc_od(1)];   % [slope, intercept]
    xr_nc  = linspace(min(allNcDev_od), max(allNcDev_od), 100);
    plot(ax_od, xr_nc, pNC_od(1)*xr_nc + pNC_od(2), '-', ...
        'Color', colOL, 'LineWidth', 1.2, 'DisplayName','OL fit');
end

% Linear regression for CL
pWC_od = [0 0];  rSq_WC_od = 0;  slope_se_WC_od = 0;
if numel(allWcDev_od) > 2
    X_wc_od  = [ones(numel(allWcDev_od),1), allWcDev_od];
    b_wc_od  = X_wc_od \ allWcMse_od;
    yhat_wc  = X_wc_od * b_wc_od;
    ss_res_w = sum((allWcMse_od - yhat_wc).^2);
    ss_tot_w = sum((allWcMse_od - mean(allWcMse_od)).^2);
    rSq_WC_od = 1 - ss_res_w / ss_tot_w;
    sigma2_wc    = ss_res_w / (numel(allWcMse_od) - 2);
    slope_se_WC_od = sqrt(sigma2_wc / sum((allWcDev_od - mean(allWcDev_od)).^2));
    pWC_od = [b_wc_od(2), b_wc_od(1)];
    xr_wc  = linspace(min(allWcDev_od), max(allWcDev_od), 100);
    plot(ax_od, xr_wc, pWC_od(1)*xr_wc + pWC_od(2), '-', ...
        'Color', colCL, 'LineWidth', 1.2, 'DisplayName','CL fit');
end

% Annotations: slope Â± SE and rÂ² for each condition
xl_od = xlim(ax_od);  yl_od = ylim(ax_od);
text(ax_od, xl_od(1), yl_od(2), ...
    sprintf('OL: slope=%.3f+/-%.3f, r^2=%.2f', pNC_od(1), slope_se_NC_od, rSq_NC_od), ...
    'Color', colOL, 'FontSize', 6, 'FontWeight','bold', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top');
text(ax_od, xl_od(1), yl_od(2) - 0.14*(yl_od(2)-yl_od(1)), ...
    sprintf('CL: slope=%.3f+/-%.3f, r^2=%.2f', pWC_od(1), slope_se_WC_od, rSq_WC_od), ...
    'Color', colCL, 'FontSize', 6, 'FontWeight','bold', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top');

lgd_od = legend(ax_od, 'Box','off', 'Location','southeast');
paperLegend(lgd_od);
xlabel(ax_od, '|{\DeltaF/F} at stim onset| (%)',  'FontWeight','bold');
ylabel(ax_od, 'Trial MSE (t=+1 to +3 s)',          'FontWeight','bold');
hold(ax_od, 'off');

paperExport(fig_onset_dev, 'paper/onset_dev_vs_mse.png');
fprintf('onset_dev_vs_mse: OL slope=%.4f+/-%.4f r2=%.3f  CL slope=%.4f+/-%.4f r2=%.3f\n', ...
    pNC_od(1), slope_se_NC_od, rSq_NC_od, pWC_od(1), slope_se_WC_od, rSq_WC_od);

%% Interactive motion scatter -- combined mode (click a point to inspect trial)
% Uses motModes(1) window. Click any point to open a dFk + input trace figure.
close all;
iMode       = motModes(1);

figI = figure('Color','w', 'Name','Interactive Motion Scatter');
figI.Units    = 'inches';
figI.Position = [1, 1, nCols*3, nRows*3];

spIdx = 0;
for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),       continue; end
    if ~isfield(mouse.(fields{k}), 'data'),      continue; end
    if ~any(mouse.(fields{k}).data.ncmotion(:)), continue; end

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
