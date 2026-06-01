% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).

PS = paperStyle();
setPaperDefaults();

%% Figures K1 & K2 -- Pre-stim dFk variance as trial sort key (all trials)
% K1: OL|CL spectral heatmap sorted by 3-s pre-onset dFk variance, MSE shown as side strip
% K2: pre-stim variance vs MSE scatter with regression slopes

preSamples_k = 3 * 35;   % 3 s pre-onset at 35 Hz

nc_all_k1 = []; wc_all_k1 = [];
nc_mse_k1 = []; wc_mse_k1 = [];
nc_var_k1 = []; wc_var_k1 = [];
freqCtrs_k1 = [];
use_abs_k1  = false;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;  wc_spec = data_k.wcFreqPow;
        use_abs_k1 = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec; wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k     = mouse.(fields{k}).d.params.dur;
    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nSamp_k  = min(preSamples_k, size(data_k.pncDfk_l, 2));
    var_nc_k = var(data_k.pncDfk_l(:, 1:nSamp_k), [], 2);
    var_wc_k = var(data_k.pwcDfk_l(:, 1:nSamp_k), [], 2);

    nNC = min([size(nc_mean_k,1), numel(var_nc_k), numel(data_k.er_ncDfk)]);
    nWC = min([size(wc_mean_k,1), numel(var_wc_k), numel(data_k.er_wcDfk)]);

    nc_all_k1 = [nc_all_k1; nc_mean_k(1:nNC, :)];
    wc_all_k1 = [wc_all_k1; wc_mean_k(1:nWC, :)];
    nc_mse_k1 = [nc_mse_k1; data_k.er_ncDfk(1:nNC)];
    wc_mse_k1 = [wc_mse_k1; data_k.er_wcDfk(1:nWC)];
    nc_var_k1 = [nc_var_k1; var_nc_k(1:nNC)];
    wc_var_k1 = [wc_var_k1; var_wc_k(1:nWC)];
    freqCtrs_k1 = data_k.freqBandCtrs;
end

% Figure K1
if ~isempty(nc_all_k1) && ~isempty(freqCtrs_k1)
    [~, nc_ord_k1] = sort(nc_var_k1, 'ascend');
    [~, wc_ord_k1] = sort(wc_var_k1, 'ascend');

    clim_k1    = prctile([nc_all_k1(:); wc_all_k1(:)], 98);
    mse_lim_k1 = prctile([nc_mse_k1;   wc_mse_k1],    98);
    if use_abs_k1
        cbar_lbl_k1 = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_k1 = 'band/total power';
    end

    lm_k1=0.07; rm_k1=0.08; bm_k1=0.10; tm_k1=0.06;
    mse_w_k1=0.025; gap_k1=0.008; pair_gap_k1=0.05;
    pw_k1 = (1 - lm_k1 - rm_k1 - 2*mse_w_k1 - 2*gap_k1 - pair_gap_k1) / 2;
    ph_k1 = 1 - tm_k1 - bm_k1;

    x_ol_h = lm_k1;
    x_ol_s = x_ol_h + pw_k1 + gap_k1;
    x_cl_h = x_ol_s + mse_w_k1 + pair_gap_k1;
    x_cl_s = x_cl_h + pw_k1 + gap_k1;

    fig_K1 = paperFig(25.4, 15.2);

    % Version 1: log color scale
    ax_ol_k1 = axes(fig_K1, 'Position', [x_ol_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_ol_k1, freqCtrs_k1, 1:size(nc_all_k1,1), nc_all_k1(nc_ord_k1,:));
    colormap(ax_ol_k1, 'hot');
    % Log color scale: clamp lower bound to a small positive value
    clim_lo_k1 = max(clim_k1 * 1e-3, min(nc_all_k1(nc_all_k1 > 0)));
    clim(ax_ol_k1, [clim_lo_k1 clim_k1]);
    set(ax_ol_k1, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'ColorScale','log');
    xlabel(ax_ol_k1, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_k1, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_k1, 'Open-Loop', 'FontSize',6, 'FontWeight','bold');

    ax_ol_ms = axes(fig_K1, 'Position', [x_ol_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_ol_ms, 1, 1:numel(nc_mse_k1), nc_mse_k1(nc_ord_k1));
    colormap(ax_ol_ms, 'parula'); clim(ax_ol_ms, [0 mse_lim_k1]);
    set(ax_ol_ms, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_ms, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_k1 = axes(fig_K1, 'Position', [x_cl_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_cl_k1, freqCtrs_k1, 1:size(wc_all_k1,1), wc_all_k1(wc_ord_k1,:));
    colormap(ax_cl_k1, 'hot');
    clim_lo_k1_wc = max(clim_k1 * 1e-3, min(wc_all_k1(wc_all_k1 > 0)));
    clim(ax_cl_k1, [clim_lo_k1_wc clim_k1]);
    set(ax_cl_k1, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{},'ColorScale','log');
    xlabel(ax_cl_k1, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_k1, 'Closed-Loop', 'FontSize',6, 'FontWeight','bold');
    cb_k1 = colorbar(ax_cl_k1);
    cb_k1.Label.String = [cbar_lbl_k1, ' (log)']; cb_k1.FontSize = 6;

    ax_cl_ms = axes(fig_K1, 'Position', [x_cl_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_cl_ms, 1, 1:numel(wc_mse_k1), wc_mse_k1(wc_ord_k1));
    colormap(ax_cl_ms, 'parula'); clim(ax_cl_ms, [0 mse_lim_k1]);
    set(ax_cl_ms, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_ms, 'MSE', 'FontSize',6, 'FontWeight','bold');

    paperExport(fig_K1, 'paper/freq_heatmap_prestimvar.png');
    % fprintf('Figure K1 saved ->' paper/freq_heatmap_prestimvar.png\n');

    % Version 2: 1/f-corrected heatmap (multiply each freq band by 1/f)
    % Divide power at each frequency by f to remove 1/f spectral tilt.
    f_vec_k1 = freqCtrs_k1(:)';       % 1 x nBands, Hz
    f_vec_k1(f_vec_k1 == 0) = 1e-3;   % guard against 0 Hz
    nc_1f_k1 = nc_all_k1 ./ f_vec_k1; % broadcast: nTrials x nBands
    wc_1f_k1 = wc_all_k1 ./ f_vec_k1;

    clim_1f_k1 = prctile([nc_1f_k1(:); wc_1f_k1(:)], 98);
    clim_lo_1f_nc = max(clim_1f_k1 * 1e-3, min(nc_1f_k1(nc_1f_k1 > 0)));
    clim_lo_1f_wc = max(clim_1f_k1 * 1e-3, min(wc_1f_k1(wc_1f_k1 > 0)));

    fig_K1_1f = paperFig(25.4, 15.2);

    ax_ol_1f = axes(fig_K1_1f, 'Position', [x_ol_h, bm_k1, pw_k1, ph_k1]);
    imagesc(ax_ol_1f, freqCtrs_k1, 1:size(nc_1f_k1,1), nc_1f_k1(nc_ord_k1,:));
    colormap(ax_ol_1f, 'hot');
    clim(ax_ol_1f, [clim_lo_1f_nc clim_1f_k1]);
    set(ax_ol_1f, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'ColorScale','log');
    xlabel(ax_ol_1f, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_1f, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_1f, 'Open-Loop (1/f corrected)', 'FontSize',6, 'FontWeight','bold');

    ax_ol_ms_1f = axes(fig_K1_1f, 'Position', [x_ol_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_ol_ms_1f, 1, 1:numel(nc_mse_k1), nc_mse_k1(nc_ord_k1));
    colormap(ax_ol_ms_1f, 'parula'); clim(ax_ol_ms_1f, [0 mse_lim_k1]);
    set(ax_ol_ms_1f, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_ms_1f, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_1f = axes(fig_K1_1f, 'Position', [x_cl_h, bm_k1, pw_k1, ph_k1]);
    imagesc(ax_cl_1f, freqCtrs_k1, 1:size(wc_1f_k1,1), wc_1f_k1(wc_ord_k1,:));
    colormap(ax_cl_1f, 'hot');
    clim(ax_cl_1f, [clim_lo_1f_wc clim_1f_k1]);
    set(ax_cl_1f, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{},'ColorScale','log');
    xlabel(ax_cl_1f, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_1f, 'Closed-Loop (1/f corrected)', 'FontSize',6, 'FontWeight','bold');
    cb_1f = colorbar(ax_cl_1f);
    cb_1f.Label.String = 'Power/f (\DeltaF/F)^2 Hz^{-2} (log)'; cb_1f.FontSize = 6;

    ax_cl_ms_1f = axes(fig_K1_1f, 'Position', [x_cl_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_cl_ms_1f, 1, 1:numel(wc_mse_k1), wc_mse_k1(wc_ord_k1));
    colormap(ax_cl_ms_1f, 'parula'); clim(ax_cl_ms_1f, [0 mse_lim_k1]);
    set(ax_cl_ms_1f, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_ms_1f, 'MSE', 'FontSize',6, 'FontWeight','bold');

    paperExport(fig_K1_1f, 'paper/freq_heatmap_prestimvar_1f.png');
end

% Figure K2 -- pre-stim variance vs MSE scatter
if ~isempty(nc_var_k1)
    fig_K2 = paperFig(6, 4);
    hold on;

    scatter(nc_var_k1, nc_mse_k1, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');
    scatter(wc_var_k1, wc_mse_k1, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');

    xAll_k2 = [nc_var_k1; wc_var_k1];
    xr_k2   = linspace(min(xAll_k2), max(xAll_k2), 100);
    pNC_k2  = [0 0]; pWC_k2 = [0 0];
    if numel(nc_var_k1) > 1
        pNC_k2 = polyfit(nc_var_k1, nc_mse_k1, 1);
        plot(xr_k2, polyval(pNC_k2, xr_k2), '-', 'Color',colOL, 'LineWidth',1.5, 'DisplayName','Open-Loop');
    end
    if numel(wc_var_k1) > 1
        pWC_k2 = polyfit(wc_var_k1, wc_mse_k1, 1);
        plot(xr_k2, polyval(pWC_k2, xr_k2), '-', 'Color',colCL, 'LineWidth',1.5, 'DisplayName','Closed-Loop');
    end

    ax_k2 = gca; xl_k2 = xlim(ax_k2); yl_k2 = ylim(ax_k2);
    text(xl_k2(2), yl_k2(2) - 0.05*(yl_k2(2)-yl_k2(1)), sprintf('slope OL = %.3f', pNC_k2(1)), ...
        'Color',colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
    text(xl_k2(2), yl_k2(2) - 0.18*(yl_k2(2)-yl_k2(1)), sprintf('slope CL = %.3f', pWC_k2(1)), ...
        'Color',colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim dFk variance (3 s)', 'FontWeight','bold', 'FontSize',6);
    ylabel('MSE  ||e||',                   'FontWeight','bold', 'FontSize',6);
    set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
    paperExport(fig_K2, 'paper/prestimvar_mse.png');
    % fprintf('Figure K2 saved ->' paper/prestimvar_mse.pdf\n');
end

%% K1z & K2z -- Pre-stim variance sort: per-frequency z-scored spectrum + quintile MSE bars
% K1z: same trial sort as K1 (ascending pre-stim variance) but spectrum z-scored
%   per frequency band across all pooled OL+CL trials. Blue-white-red diverging
%   colormap reveals 2-4 Hz elevation relative to the cross-trial mean.
%   MSE strip uses 'hot' colormap for stronger contrast.
% K2z: pre-stim variance binned into quintiles; grouped OL vs CL bars of mean
%   MSE +/- SEM. Makes the OL-CL gap directly visible per brain-state tier.

if ~isempty(nc_all_k1) && ~isempty(freqCtrs_k1)

    % Per-frequency z-score: normalise each freq band across all pooled trials
    all_spec_z = [nc_all_k1; wc_all_k1];
    mu_f_z     = mean(all_spec_z, 1);
    sig_f_z    = std(all_spec_z, 0, 1) + eps;
    nc_z_k1    = (nc_all_k1 - mu_f_z) ./ sig_f_z;
    wc_z_k1    = (wc_all_k1 - mu_f_z) ./ sig_f_z;

    clim_z    = max(prctile(abs([nc_z_k1(:); wc_z_k1(:)]), 98), 0.1);
    mse_lim_z = prctile([nc_mse_k1; wc_mse_k1], 98);

    [~, nc_ord_z] = sort(nc_var_k1, 'ascend');
    [~, wc_ord_z] = sort(wc_var_k1, 'ascend');

    % Blue-white-red diverging colormap
    nC = 256;
    cmap_bwr = [linspace(0,1,nC/2)', linspace(0,1,nC/2)', ones(nC/2,1); ...
                ones(nC/2,1), linspace(1,0,nC/2)', linspace(1,0,nC/2)'];

    % Layout identical to K1
    lm_z=0.07; rm_z=0.08; bm_z=0.10; tm_z=0.06;
    mse_w_z=0.025; gap_z=0.008; pair_gap_z=0.05;
    pw_z = (1 - lm_z - rm_z - 2*mse_w_z - 2*gap_z - pair_gap_z) / 2;
    ph_z = 1 - tm_z - bm_z;
    x_ol_hz = lm_z;
    x_ol_sz = x_ol_hz + pw_z + gap_z;
    x_cl_hz = x_ol_sz + mse_w_z + pair_gap_z;
    x_cl_sz = x_cl_hz + pw_z + gap_z;

    fig_K1z = paperFig(25.4, 15.2);

    ax_ol_z = axes(fig_K1z, 'Position', [x_ol_hz, bm_z, pw_z, ph_z]);
    imagesc(ax_ol_z, freqCtrs_k1, 1:size(nc_z_k1,1), nc_z_k1(nc_ord_z,:));
    colormap(ax_ol_z, cmap_bwr);  clim(ax_ol_z, [-clim_z, clim_z]);
    set(ax_ol_z, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_z, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_z, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_z, 'Open-Loop  (z-score per freq)', 'FontSize',6, 'FontWeight','bold');

    ax_ol_msz = axes(fig_K1z, 'Position', [x_ol_sz, bm_z, mse_w_z, ph_z]);
    imagesc(ax_ol_msz, 1, 1:numel(nc_mse_k1), nc_mse_k1(nc_ord_z));
    colormap(ax_ol_msz, 'hot');  clim(ax_ol_msz, [0 mse_lim_z]);
    set(ax_ol_msz, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_msz, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_z = axes(fig_K1z, 'Position', [x_cl_hz, bm_z, pw_z, ph_z]);
    imagesc(ax_cl_z, freqCtrs_k1, 1:size(wc_z_k1,1), wc_z_k1(wc_ord_z,:));
    colormap(ax_cl_z, cmap_bwr);  clim(ax_cl_z, [-clim_z, clim_z]);
    set(ax_cl_z, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_z, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_z, 'Closed-Loop  (z-score per freq)', 'FontSize',6, 'FontWeight','bold');
    cb_z = colorbar(ax_cl_z);
    cb_z.Label.String = 'Power z-score';  cb_z.FontSize = 6;

    ax_cl_msz = axes(fig_K1z, 'Position', [x_cl_sz, bm_z, mse_w_z, ph_z]);
    imagesc(ax_cl_msz, 1, 1:numel(wc_mse_k1), wc_mse_k1(wc_ord_z));
    colormap(ax_cl_msz, 'hot');  clim(ax_cl_msz, [0 mse_lim_z]);
    set(ax_cl_msz, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_msz, 'MSE', 'FontSize',6, 'FontWeight','bold');

    % exportgraphics(fig_K1z, 'paper/freq_heatmap_prestimvar_zscore.png', 'Resolution',300);
    fprintf('Figure K1z ready\n');
end

% Figure K2z -- quintile bar chart
if ~isempty(nc_var_k1)
    nBins   = 5;
    edges_z = prctile([nc_var_k1; wc_var_k1], linspace(0, 100, nBins+1));
    edges_z(1) = -inf;  edges_z(end) = inf;

    nc_mse_bins = cell(nBins,1);  wc_mse_bins = cell(nBins,1);
    for b = 1:nBins
        nc_mse_bins{b} = nc_mse_k1(nc_var_k1 >= edges_z(b) & nc_var_k1 < edges_z(b+1));
        wc_mse_bins{b} = wc_mse_k1(wc_var_k1 >= edges_z(b) & wc_var_k1 < edges_z(b+1));
    end
    nc_mu_z  = cellfun(@mean, nc_mse_bins);
    wc_mu_z  = cellfun(@mean, wc_mse_bins);
    nc_sem_z = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), nc_mse_bins);
    wc_sem_z = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), wc_mse_bins);

    bw = 0.35;
    fig_K2z = paperFig(8, 5);
    hold on;
    bar((1:nBins) - bw/2, nc_mu_z, bw, 'FaceColor',colOL, 'EdgeColor','none', 'DisplayName','Open-Loop');
    bar((1:nBins) + bw/2, wc_mu_z, bw, 'FaceColor',colCL, 'EdgeColor','none', 'DisplayName','Closed-Loop');
    errorbar((1:nBins) - bw/2, nc_mu_z, nc_sem_z, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    errorbar((1:nBins) + bw/2, wc_mu_z, wc_sem_z, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    set(gca, 'XTick',1:nBins, ...
        'XTickLabel', arrayfun(@(b) sprintf('Q%d',b), 1:nBins, 'UniformOutput',false), ...
        'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim variance quintile  (Q1 = low)', 'FontWeight','bold', 'FontSize',6);
    ylabel('Mean MSE  ||e||',                        'FontWeight','bold', 'FontSize',6);
    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    title('MSE by pre-stim variance quintile', 'FontSize',6, 'FontWeight','bold');
    % exportgraphics(fig_K2z, 'paper/prestimvar_mse_binned.pdf', 'ContentType','vector');
    fprintf('Figure K2z ready\n');
end

%% K2i -- Interactive pooled pre-stim variance scatter
% Click any point to open plotSingleTrial (dFk trace + motion + input).
% Pools all sessions; OL red, CL green -- same layout as K2 but interactive.

ud_nc_i = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
ud_wc_i = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
nc_var_i = [];  nc_mse_i = [];
wc_var_i = [];  wc_mse_i = [];

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end

    nSamp_k  = min(preSamples_k, size(data_k.pncDfk_l, 2));
    var_nc_k = var(data_k.pncDfk_l(:, 1:nSamp_k), [], 2);
    var_wc_k = var(data_k.pwcDfk_l(:, 1:nSamp_k), [], 2);

    nNC = min([numel(var_nc_k), numel(data_k.er_ncDfk), numel(data_k.nc)]);
    nWC = min([numel(var_wc_k), numel(data_k.er_wcDfk), numel(data_k.wc)]);

    nc_var_i = [nc_var_i; var_nc_k(1:nNC)];
    nc_mse_i = [nc_mse_i; data_k.er_ncDfk(1:nNC)];
    wc_var_i = [wc_var_i; var_wc_k(1:nWC)];
    wc_mse_i = [wc_mse_i; data_k.er_wcDfk(1:nWC)];

    for j = 1:nNC
        ud_nc_i(end+1) = struct('field', fields{k}, 'stim_idx', data_k.nc(j), ...
            'lbl', 'OL', 'mse', data_k.er_ncDfk(j));
    end
    for j = 1:nWC
        ud_wc_i(end+1) = struct('field', fields{k}, 'stim_idx', data_k.wc(j), ...
            'lbl', 'CL', 'mse', data_k.er_wcDfk(j));
    end
end

fig_K2i = figure('Color','w', 'Name','Interactive Pre-Stim Var Scatter');
fig_K2i.Units    = 'inches';
fig_K2i.Position = [1, 1, 6, 5];
hold on;

sc_nc_i = scatter(nc_var_i, nc_mse_i, 20, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName','OL');
sc_nc_i.UserData      = ud_nc_i;
sc_nc_i.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

sc_wc_i = scatter(wc_var_i, wc_mse_i, 20, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.5, 'DisplayName','CL');
sc_wc_i.UserData      = ud_wc_i;
sc_wc_i.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

legend('Box','off', 'Location','northwest', 'FontSize',9, 'FontWeight','bold');
xlabel('Pre-stim dFk variance (3 s)', 'FontWeight','bold');
ylabel('MSE  ||e||',                   'FontWeight','bold');
title('Pre-stim variance vs MSE -- click to inspect trial', 'FontSize',9);
set(gca, 'Box','off', 'TickDir','out');
fprintf('K2i ready -- click any point to inspect that trial.\n');

%% Figures K1m & K2m -- Pre-stim variance sorted, motion-clean (|z-motion| <= motThresh)
nc_all_k1m = []; wc_all_k1m = [];
nc_mse_k1m = []; wc_mse_k1m = [];
nc_var_k1m = []; wc_var_k1m = [];
freqCtrs_k1m = [];
use_abs_k1m  = false;
n_exc_nc_k1m = 0; n_exc_wc_k1m = 0;
n_tot_nc_k1m = 0; n_tot_wc_k1m = 0;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end
    if ~isfield(data_k, 'ncmotion')  || ~any(data_k.ncmotion(:)),  continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;  wc_spec = data_k.wcFreqPow;
        use_abs_k1m = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec; wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k     = mouse.(fields{k}).d.params.dur;
    n_cols    = size(data_k.ncmotion, 2);
    onset_col = n_cols - 35 * dur_k;
    win_start = max(1,      onset_col - round(iMode_j2.pre_secs * 35));
    win_end   = min(n_cols, onset_col + dur_k * 35);

    ncm = mean(data_k.ncmotion(:, win_start:win_end), 2);
    wcm = mean(data_k.wcmotion(:, win_start:win_end), 2);

    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nSamp_k  = min(preSamples_k, size(data_k.pncDfk_l, 2));
    var_nc_k = var(data_k.pncDfk_l(:, 1:nSamp_k), [], 2);
    var_wc_k = var(data_k.pwcDfk_l(:, 1:nSamp_k), [], 2);

    nNC = min([size(nc_mean_k,1), numel(var_nc_k), numel(ncm), numel(data_k.er_ncDfk)]);
    nWC = min([size(wc_mean_k,1), numel(var_wc_k), numel(wcm), numel(data_k.er_wcDfk)]);

    nc_keep = abs(ncm(1:nNC)) <= motThresh;
    wc_keep = abs(wcm(1:nWC)) <= motThresh;

    n_tot_nc_k1m = n_tot_nc_k1m + nNC;
    n_tot_wc_k1m = n_tot_wc_k1m + nWC;
    n_exc_nc_k1m = n_exc_nc_k1m + sum(~nc_keep);
    n_exc_wc_k1m = n_exc_wc_k1m + sum(~wc_keep);

    nc_all_k1m = [nc_all_k1m; nc_mean_k(nc_keep, :)];
    wc_all_k1m = [wc_all_k1m; wc_mean_k(wc_keep, :)];
    nc_mse_k1m = [nc_mse_k1m; data_k.er_ncDfk(nc_keep)];
    wc_mse_k1m = [wc_mse_k1m; data_k.er_wcDfk(wc_keep)];
    nc_var_k1m = [nc_var_k1m; var_nc_k(nc_keep)];
    wc_var_k1m = [wc_var_k1m; var_wc_k(wc_keep)];
    freqCtrs_k1m = data_k.freqBandCtrs;
end

fprintf('K1m motion-clean: OL %d/%d kept (%.0f%% excl)  CL %d/%d kept (%.0f%% excl)\n', ...
    n_tot_nc_k1m - n_exc_nc_k1m, n_tot_nc_k1m, 100*n_exc_nc_k1m/max(n_tot_nc_k1m,1), ...
    n_tot_wc_k1m - n_exc_wc_k1m, n_tot_wc_k1m, 100*n_exc_wc_k1m/max(n_tot_wc_k1m,1));

% Figure K1m
if ~isempty(nc_all_k1m) && ~isempty(freqCtrs_k1m)
    [~, nc_ord_k1m] = sort(nc_var_k1m, 'ascend');
    [~, wc_ord_k1m] = sort(wc_var_k1m, 'ascend');

    clim_k1m    = prctile([nc_all_k1m(:); wc_all_k1m(:)], 98);
    mse_lim_k1m = prctile([nc_mse_k1m;   wc_mse_k1m],    98);
    if use_abs_k1m
        cbar_lbl_k1m = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_k1m = 'band/total power';
    end

    fig_K1m = paperFig(25.4, 15.2);

    ax_ol_k1m = axes(fig_K1m, 'Position', [x_ol_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_ol_k1m, freqCtrs_k1m, 1:size(nc_all_k1m,1), nc_all_k1m(nc_ord_k1m,:));
    colormap(ax_ol_k1m, 'hot'); clim(ax_ol_k1m, [0 clim_k1m]);
    set(ax_ol_k1m, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_k1m, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_k1m, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_k1m, sprintf('Open-Loop  (motion-clean, |z|\\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');

    ax_ol_msm = axes(fig_K1m, 'Position', [x_ol_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_ol_msm, 1, 1:numel(nc_mse_k1m), nc_mse_k1m(nc_ord_k1m));
    colormap(ax_ol_msm, 'parula'); clim(ax_ol_msm, [0 mse_lim_k1m]);
    set(ax_ol_msm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_msm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_k1m = axes(fig_K1m, 'Position', [x_cl_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_cl_k1m, freqCtrs_k1m, 1:size(wc_all_k1m,1), wc_all_k1m(wc_ord_k1m,:));
    colormap(ax_cl_k1m, 'hot'); clim(ax_cl_k1m, [0 clim_k1m]);
    set(ax_cl_k1m, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_k1m, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_k1m, sprintf('Closed-Loop  (motion-clean, |z|\\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    cb_k1m = colorbar(ax_cl_k1m); cb_k1m.Label.String = cbar_lbl_k1m; cb_k1m.FontSize = 6;

    ax_cl_msm = axes(fig_K1m, 'Position', [x_cl_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_cl_msm, 1, 1:numel(wc_mse_k1m), wc_mse_k1m(wc_ord_k1m));
    colormap(ax_cl_msm, 'parula'); clim(ax_cl_msm, [0 mse_lim_k1m]);
    set(ax_cl_msm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_msm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    paperExport(fig_K1m, 'paper/freq_heatmap_prestimvar_motclean.png');
    % fprintf('Figure K1m saved ->' paper/freq_heatmap_prestimvar_motclean.png\n');
end

% Figure K2m -- motion-clean pre-stim variance vs MSE scatter
if ~isempty(nc_var_k1m)
    fig_K2m = paperFig(6, 4);
    hold on;

    scatter(nc_var_k1m, nc_mse_k1m, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');
    scatter(wc_var_k1m, wc_mse_k1m, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');

    xAll_k2m = [nc_var_k1m; wc_var_k1m];
    xr_k2m   = linspace(min(xAll_k2m), max(xAll_k2m), 100);
    pNC_k2m  = [0 0]; pWC_k2m = [0 0];
    if numel(nc_var_k1m) > 1
        pNC_k2m = polyfit(nc_var_k1m, nc_mse_k1m, 1);
        plot(xr_k2m, polyval(pNC_k2m, xr_k2m), '-', 'Color',colOL, 'LineWidth',1.5, 'DisplayName','Open-Loop');
    end
    if numel(wc_var_k1m) > 1
        pWC_k2m = polyfit(wc_var_k1m, wc_mse_k1m, 1);
        plot(xr_k2m, polyval(pWC_k2m, xr_k2m), '-', 'Color',colCL, 'LineWidth',1.5, 'DisplayName','Closed-Loop');
    end

    ax_k2m = gca; xl_k2m = xlim(ax_k2m); yl_k2m = ylim(ax_k2m);
    text(xl_k2m(2), yl_k2m(2) - 0.05*(yl_k2m(2)-yl_k2m(1)), sprintf('slope OL = %.3f', pNC_k2m(1)), ...
        'Color',colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
    text(xl_k2m(2), yl_k2m(2) - 0.18*(yl_k2m(2)-yl_k2m(1)), sprintf('slope CL = %.3f', pWC_k2m(1)), ...
        'Color',colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim dFk variance (3 s)', 'FontWeight','bold', 'FontSize',6);
    ylabel('MSE  ||e||',                   'FontWeight','bold', 'FontSize',6);
    set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
    paperExport(fig_K2m, 'paper/prestimvar_mse_motclean.png');
    % fprintf('Figure K2m saved ->' paper/prestimvar_mse_motclean.pdf\n');
end
%% K1zm & K2zm -- Pre-stim variance sort: z-scored spectrum + quintile bars, motion-clean
% Same as K1z/K2z but operating on motion-excluded trials (|z-motion| <= motThresh).
% Uses nc_all_k1m / wc_all_k1m accumulated in the K1m section above.

if ~isempty(nc_all_k1m) && ~isempty(freqCtrs_k1m)

    % Per-frequency z-score across pooled motion-clean trials
    all_spec_zm = [nc_all_k1m; wc_all_k1m];
    mu_f_zm     = mean(all_spec_zm, 1);
    sig_f_zm    = std(all_spec_zm, 0, 1) + eps;
    nc_zm       = (nc_all_k1m - mu_f_zm) ./ sig_f_zm;
    wc_zm       = (wc_all_k1m - mu_f_zm) ./ sig_f_zm;

    clim_zm    = max(prctile(abs([nc_zm(:); wc_zm(:)]), 98), 0.1);
    mse_lim_zm = prctile([nc_mse_k1m; wc_mse_k1m], 98);

    [~, nc_ord_zm] = sort(nc_var_k1m, 'ascend');
    [~, wc_ord_zm] = sort(wc_var_k1m, 'ascend');

    % Blue-white-red diverging colormap (same as K1z)
    nC_zm = 256;
    cmap_bwr_m = [linspace(0,1,nC_zm/2)', linspace(0,1,nC_zm/2)', ones(nC_zm/2,1); ...
                  ones(nC_zm/2,1), linspace(1,0,nC_zm/2)', linspace(1,0,nC_zm/2)'];

    lm_zm=0.07; rm_zm=0.08; bm_zm=0.10; tm_zm=0.06;
    mse_w_zm=0.025; gap_zm=0.008; pair_gap_zm=0.05;
    pw_zm = (1 - lm_zm - rm_zm - 2*mse_w_zm - 2*gap_zm - pair_gap_zm) / 2;
    ph_zm = 1 - tm_zm - bm_zm;
    x_ol_hzm = lm_zm;
    x_ol_szm = x_ol_hzm + pw_zm + gap_zm;
    x_cl_hzm = x_ol_szm + mse_w_zm + pair_gap_zm;
    x_cl_szm = x_cl_hzm + pw_zm + gap_zm;

    fig_K1zm = paperFig(25.4, 15.2);

    ax_ol_zm = axes(fig_K1zm, 'Position', [x_ol_hzm, bm_zm, pw_zm, ph_zm]);
    imagesc(ax_ol_zm, freqCtrs_k1m, 1:size(nc_zm,1), nc_zm(nc_ord_zm,:));
    colormap(ax_ol_zm, cmap_bwr_m);  clim(ax_ol_zm, [-clim_zm, clim_zm]);
    set(ax_ol_zm, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_zm, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_zm, 'Trial (low \rightarrow high pre-stim var)', 'FontWeight','bold');
    title(ax_ol_zm, sprintf('Open-Loop  (z-score, motion-clean |z|\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');

    ax_ol_mszm = axes(fig_K1zm, 'Position', [x_ol_szm, bm_zm, mse_w_zm, ph_zm]);
    imagesc(ax_ol_mszm, 1, 1:numel(nc_mse_k1m), nc_mse_k1m(nc_ord_zm));
    colormap(ax_ol_mszm, 'hot');  clim(ax_ol_mszm, [0 mse_lim_zm]);
    set(ax_ol_mszm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_mszm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_zm = axes(fig_K1zm, 'Position', [x_cl_hzm, bm_zm, pw_zm, ph_zm]);
    imagesc(ax_cl_zm, freqCtrs_k1m, 1:size(wc_zm,1), wc_zm(wc_ord_zm,:));
    colormap(ax_cl_zm, cmap_bwr_m);  clim(ax_cl_zm, [-clim_zm, clim_zm]);
    set(ax_cl_zm, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_zm, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_zm, sprintf('Closed-Loop  (z-score, motion-clean |z|\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    cb_zm = colorbar(ax_cl_zm);
    cb_zm.Label.String = 'Power z-score';  cb_zm.FontSize = 6;

    ax_cl_mszm = axes(fig_K1zm, 'Position', [x_cl_szm, bm_zm, mse_w_zm, ph_zm]);
    imagesc(ax_cl_mszm, 1, 1:numel(wc_mse_k1m), wc_mse_k1m(wc_ord_zm));
    colormap(ax_cl_mszm, 'hot');  clim(ax_cl_mszm, [0 mse_lim_zm]);
    set(ax_cl_mszm, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_mszm, 'MSE', 'FontSize',6, 'FontWeight','bold');

    % exportgraphics(fig_K1zm, 'paper/freq_heatmap_prestimvar_zscore_motclean.png', 'Resolution',300);
    fprintf('Figure K1zm ready (motion-clean z-score heatmap)\n');
end

% Figure K2zm -- quintile bars, motion-clean
if ~isempty(nc_var_k1m)
    nBins_zm  = 5;
    edges_zm  = prctile([nc_var_k1m; wc_var_k1m], linspace(0, 100, nBins_zm+1));
    edges_zm(1) = -inf;  edges_zm(end) = inf;

    nc_mse_binsm = cell(nBins_zm,1);  wc_mse_binsm = cell(nBins_zm,1);
    for b = 1:nBins_zm
        nc_mse_binsm{b} = nc_mse_k1m(nc_var_k1m >= edges_zm(b) & nc_var_k1m < edges_zm(b+1));
        wc_mse_binsm{b} = wc_mse_k1m(wc_var_k1m >= edges_zm(b) & wc_var_k1m < edges_zm(b+1));
    end
    nc_mu_zm  = cellfun(@mean, nc_mse_binsm);
    wc_mu_zm  = cellfun(@mean, wc_mse_binsm);
    nc_sem_zm = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), nc_mse_binsm);
    wc_sem_zm = cellfun(@(x) std(x) / sqrt(max(numel(x),1)), wc_mse_binsm);

    bw_zm = 0.35;
    fig_K2zm = paperFig(8, 5);
    hold on;
    bar((1:nBins_zm) - bw_zm/2, nc_mu_zm, bw_zm, 'FaceColor',colOL, 'EdgeColor','none', 'DisplayName','Open-Loop');
    bar((1:nBins_zm) + bw_zm/2, wc_mu_zm, bw_zm, 'FaceColor',colCL, 'EdgeColor','none', 'DisplayName','Closed-Loop');
    errorbar((1:nBins_zm) - bw_zm/2, nc_mu_zm, nc_sem_zm, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    errorbar((1:nBins_zm) + bw_zm/2, wc_mu_zm, wc_sem_zm, 'k.', 'LineWidth',1, 'HandleVisibility','off');
    set(gca, 'XTick',1:nBins_zm, ...
        'XTickLabel', arrayfun(@(b) sprintf('Q%d',b), 1:nBins_zm, 'UniformOutput',false), ...
        'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');
    xlabel('Pre-stim variance quintile  (Q1 = low, motion-clean)', 'FontWeight','bold', 'FontSize',6);
    ylabel('Mean MSE  ||e||',                                       'FontWeight','bold', 'FontSize',6);
    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    title(sprintf('MSE by pre-stim variance quintile  (motion-clean |z|\leq%.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    % exportgraphics(fig_K2zm, 'paper/prestimvar_mse_binned_motclean.pdf', 'ContentType','vector');
    fprintf('Figure K2zm ready (motion-clean quintile bars)\n');
end


%% Figures K1w, K2w, K2iw -- same as K1/K2/K2i but variance over pre+trial window
% pncDfk_l layout: [3 s pre | dur s trial | 3 s post] at 35 Hz.
% Pre-only used cols 1:105. Here we extend to cols 1:(3+dur_loop)*35 to include the trial.
% This captures both resting state AND stimulus-evoked variability as the sort feature.

durLoop          = 3;           % hard-coded dur used when building pncDfk_l
preTrialSamples  = (3 + durLoop) * 35;   % = 210 samples

nc_all_kw = []; wc_all_kw = [];
nc_mse_kw = []; wc_mse_kw = [];
nc_var_kw = []; wc_var_kw = [];
ud_nc_kw  = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
ud_wc_kw  = struct('field',{}, 'stim_idx',{}, 'lbl',{}, 'mse',{});
freqCtrs_kw = [];
use_abs_kw  = false;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;
    if ~isfield(data_k, 'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;  wc_spec = data_k.wcFreqPow;
        use_abs_kw = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec; wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k     = mouse.(fields{k}).d.params.dur;
    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nSamp_kw  = min(preTrialSamples, size(data_k.pncDfk_l, 2));
    var_nc_k  = var(data_k.pncDfk_l(:, 1:nSamp_kw), [], 2);
    var_wc_k  = var(data_k.pwcDfk_l(:, 1:nSamp_kw), [], 2);

    nNC = min([size(nc_mean_k,1), numel(var_nc_k), numel(data_k.er_ncDfk), numel(data_k.nc)]);
    nWC = min([size(wc_mean_k,1), numel(var_wc_k), numel(data_k.er_wcDfk), numel(data_k.wc)]);

    nc_all_kw = [nc_all_kw; nc_mean_k(1:nNC, :)];
    wc_all_kw = [wc_all_kw; wc_mean_k(1:nWC, :)];
    nc_mse_kw = [nc_mse_kw; data_k.er_ncDfk(1:nNC)];
    wc_mse_kw = [wc_mse_kw; data_k.er_wcDfk(1:nWC)];
    nc_var_kw = [nc_var_kw; var_nc_k(1:nNC)];
    wc_var_kw = [wc_var_kw; var_wc_k(1:nWC)];
    freqCtrs_kw = data_k.freqBandCtrs;

    for j = 1:nNC
        ud_nc_kw(end+1) = struct('field', fields{k}, 'stim_idx', data_k.nc(j), ...
            'lbl', 'OL', 'mse', data_k.er_ncDfk(j));
    end
    for j = 1:nWC
        ud_wc_kw(end+1) = struct('field', fields{k}, 'stim_idx', data_k.wc(j), ...
            'lbl', 'CL', 'mse', data_k.er_wcDfk(j));
    end
end

% Figure K1w -- heatmap sorted by pre+trial variance
if ~isempty(nc_all_kw) && ~isempty(freqCtrs_kw)
    [~, nc_ord_kw] = sort(nc_var_kw, 'ascend');
    [~, wc_ord_kw] = sort(wc_var_kw, 'ascend');

    clim_kw    = prctile([nc_all_kw(:); wc_all_kw(:)], 98);
    mse_lim_kw = prctile([nc_mse_kw;   wc_mse_kw],    98);
    if use_abs_kw
        cbar_lbl_kw = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_kw = 'band/total power';
    end

    fig_K1w = paperFig(25.4, 15.2);

    ax_ol_kw = axes(fig_K1w, 'Position', [x_ol_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_ol_kw, freqCtrs_kw, 1:size(nc_all_kw,1), nc_all_kw(nc_ord_kw,:));
    colormap(ax_ol_kw, 'hot'); clim(ax_ol_kw, [0 clim_kw]);
    set(ax_ol_kw, 'YDir','normal','Box','off','TickDir','out','FontSize',6);
    xlabel(ax_ol_kw, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol_kw, 'Trial (low \rightarrow high pre+trial var)', 'FontWeight','bold');
    title(ax_ol_kw, 'Open-Loop  (pre+trial var)', 'FontSize',6, 'FontWeight','bold');

    ax_ol_msw = axes(fig_K1w, 'Position', [x_ol_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_ol_msw, 1, 1:numel(nc_mse_kw), nc_mse_kw(nc_ord_kw));
    colormap(ax_ol_msw, 'parula'); clim(ax_ol_msw, [0 mse_lim_kw]);
    set(ax_ol_msw, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_ol_msw, 'MSE', 'FontSize',6, 'FontWeight','bold');

    ax_cl_kw = axes(fig_K1w, 'Position', [x_cl_h, bm_k1, pw_k1,    ph_k1]);
    imagesc(ax_cl_kw, freqCtrs_kw, 1:size(wc_all_kw,1), wc_all_kw(wc_ord_kw,:));
    colormap(ax_cl_kw, 'hot'); clim(ax_cl_kw, [0 clim_kw]);
    set(ax_cl_kw, 'YDir','normal','Box','off','TickDir','out','FontSize',6,'YTickLabel',{});
    xlabel(ax_cl_kw, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl_kw, 'Closed-Loop  (pre+trial var)', 'FontSize',6, 'FontWeight','bold');
    cb_kw = colorbar(ax_cl_kw); cb_kw.Label.String = cbar_lbl_kw; cb_kw.FontSize = 6;

    ax_cl_msw = axes(fig_K1w, 'Position', [x_cl_s, bm_k1, mse_w_k1, ph_k1]);
    imagesc(ax_cl_msw, 1, 1:numel(wc_mse_kw), wc_mse_kw(wc_ord_kw));
    colormap(ax_cl_msw, 'parula'); clim(ax_cl_msw, [0 mse_lim_kw]);
    set(ax_cl_msw, 'YDir','normal','Box','off','XTick',[],'YTickLabel',{},'FontSize',6);
    title(ax_cl_msw, 'MSE', 'FontSize',6, 'FontWeight','bold');

    paperExport(fig_K1w, 'paper/freq_heatmap_pretrial_var.png');
    % fprintf('Figure K1w saved ->' paper/freq_heatmap_pretrial_var.png\n');
end

% Figure K2w -- pre+trial variance vs MSE scatter
if ~isempty(nc_var_kw)
    fig_K2w = paperFig(6, 4);
    hold on;

    scatter(nc_var_kw, nc_mse_kw, 8, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');
    scatter(wc_var_kw, wc_mse_kw, 8, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.3, 'HandleVisibility','off');

    xAll_kw = [nc_var_kw; wc_var_kw];
    xr_kw   = linspace(min(xAll_kw), max(xAll_kw), 100);
    pNC_kw  = [0 0]; pWC_kw = [0 0];
    if numel(nc_var_kw) > 1
        pNC_kw = polyfit(nc_var_kw, nc_mse_kw, 1);
        plot(xr_kw, polyval(pNC_kw, xr_kw), '-', 'Color',colOL, 'LineWidth',1.5, 'DisplayName','Open-Loop');
    end
    if numel(wc_var_kw) > 1
        pWC_kw = polyfit(wc_var_kw, wc_mse_kw, 1);
        plot(xr_kw, polyval(pWC_kw, xr_kw), '-', 'Color',colCL, 'LineWidth',1.5, 'DisplayName','Closed-Loop');
    end

    ax_kw = gca; xl_kw = xlim(ax_kw); yl_kw = ylim(ax_kw);
    text(xl_kw(2), yl_kw(2) - 0.05*(yl_kw(2)-yl_kw(1)), sprintf('slope OL = %.3f', pNC_kw(1)), ...
        'Color',colOL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');
    text(xl_kw(2), yl_kw(2) - 0.18*(yl_kw(2)-yl_kw(1)), sprintf('slope CL = %.3f', pWC_kw(1)), ...
        'Color',colCL, 'FontSize',6, 'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','top');

    legend('Box','off', 'Location','northwest', 'FontSize',6, 'FontWeight','bold');
    xlabel('dFk variance (pre+trial, 6 s)', 'FontWeight','bold', 'FontSize',6);
    ylabel('MSE  ||e||',                    'FontWeight','bold', 'FontSize',6);
    set(gca, 'Box','off', 'TickDir','out', 'FontSize',6);
    paperExport(fig_K2w, 'paper/pretrial_var_mse.png');
    % fprintf('Figure K2w saved ->' paper/pretrial_var_mse.pdf\n');
end

% Figure K2iw -- interactive pre+trial variance scatter
if ~isempty(nc_var_kw)
    fig_K2iw = figure('Color','w', 'Name','Interactive Pre+Trial Var Scatter');
    fig_K2iw.Units    = 'inches';
    fig_K2iw.Position = [1, 1, 6, 5];
    hold on;

    sc_nc_kw = scatter(nc_var_kw, nc_mse_kw, 20, colOL, 'o', 'filled', 'MarkerFaceAlpha',0.5, 'DisplayName','OL');
    sc_nc_kw.UserData      = ud_nc_kw;
    sc_nc_kw.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    sc_wc_kw = scatter(wc_var_kw, wc_mse_kw, 20, colCL, 'o', 'filled', 'MarkerFaceAlpha',0.5, 'DisplayName','CL');
    sc_wc_kw.UserData      = ud_wc_kw;
    sc_wc_kw.ButtonDownFcn = @(src,ev) scatterClickCallback(src, ev, mouse, fields);

    legend('Box','off', 'Location','northwest', 'FontSize',9, 'FontWeight','bold');
    xlabel('dFk variance (pre+trial, 6 s)', 'FontWeight','bold');
    ylabel('MSE  ||e||',                    'FontWeight','bold');
    title('Pre+trial variance vs MSE -- click to inspect trial', 'FontSize',9);
    set(gca, 'Box','off', 'TickDir','out');
    fprintf('K2iw ready -- click any point to inspect that trial.\n');
end
%% OL step TF fit -- fixed 2p1z, three sessions; separate interactive validation figure