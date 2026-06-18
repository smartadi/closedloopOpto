% controller-analysis -- trial brain-state vs MSE
% Run from brain_paper/ root directory (or controller-analysis/).
% Requires: load_sessions.m has been run first (mouse, fields).
% Data needed per session: pncDfk_l/pwcDfk_l, ncFreqPow/wcFreqPow,
%                          ncmotion/wcmotion, er_ncDfk/er_wcDfk, freqBandCtrs.
%
% Produces one figure (no automatic export):
%   Col 1  -- power spectrum heatmap, trials sorted by total variance (window set by varWinMode)
%   Col 2  -- block-mean variance vs MSE
% Rows: OL (top) / CL (bottom).
% varWinMode: 'pre2trial' = trial-2s to end; 'trial' = 0s (in-trial only) to end.
clc;
close all;

PS = paperStyle();
setPaperDefaults();

nSess = length(fields);

Fs        = 35;
blockSize = 20;
motThresh = 1.5;
eps_v     = 1e-10;

% pncDfk_l layout: [3 s pre | 3 s trial | 3 s post] at 35 Hz
%   onset col = 3*35+1 = 106
pnc_c0  = 3 * Fs + 1;       % 106
pnc_dur = 3;                % trial duration in pncDfk_l (s)

% Variance/spectrum window:
%   'pre2trial' -- trial-2s to trial end (includes 2s pre-onset)
%   'trial'     -- 0s to trial end (in-trial only)
varWinMode = 'trial';

switch varWinMode
    case 'pre2trial'
        varWin_a    = pnc_c0 - round(2 * Fs);    % = 36
        specPreBins = 2;
        winLabel    = 'trial-2s to end';
    case 'trial'
        varWin_a    = pnc_c0;                    % = 106
        specPreBins = 0;
        winLabel    = '0s to end';
    otherwise
        error('trial_state_mse: unknown varWinMode "%s"', varWinMode);
end
varWin_b = pnc_c0 + pnc_dur * Fs - 1;        % = 210

%% Pooling loop ---------------------------------------------------------------
nc_spec  = [];  wc_spec  = [];
nc_var   = [];  wc_var   = [];
nc_delta = [];  wc_delta = [];
nc_mse   = [];  wc_mse   = [];
freqCtrs = [];

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;

    if ~isfield(data_k,'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end
    if ~isfield(data_k,'ncmotion') || ~any(data_k.ncmotion(:)),  continue; end

    if isfield(data_k,'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec_k = data_k.ncFreqPow;   wc_spec_k = data_k.wcFreqPow;
    elseif isfield(data_k,'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec_k = data_k.ncFreqSpec;  wc_spec_k = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k    = mouse.(fields{k}).d.params.dur;
    freqCtrs = data_k.freqBandCtrs;

    % Motion mask (2 s pre + trial window in ncmotion)
    n_mot   = size(data_k.ncmotion, 2);
    ons_mot = n_mot - Fs * dur_k;
    ws_mot  = max(1, ons_mot - round(2 * Fs));
    we_mot  = min(n_mot, ons_mot + dur_k * Fs);
    ncm_k   = mean(data_k.ncmotion(:, ws_mot:we_mot), 2);
    wcm_k   = mean(data_k.wcmotion(:, ws_mot:we_mot), 2);

    n_nc = min([numel(data_k.er_ncDfk), size(data_k.pncDfk_l,1), ...
                size(nc_spec_k,1), numel(ncm_k)]);
    n_wc = min([numel(data_k.er_wcDfk), size(data_k.pwcDfk_l,1), ...
                size(wc_spec_k,1), numel(wcm_k)]);

    nc_keep = abs(ncm_k(1:n_nc)) <= motThresh;
    wc_keep = abs(wcm_k(1:n_wc)) <= motThresh;

    % Variance: trial-2s to trial end in pncDfk_l
    va = max(1,                         varWin_a);
    vb = min(size(data_k.pncDfk_l, 2), varWin_b);
    if va > vb, continue; end
    nc_var_k = var(data_k.pncDfk_l(1:n_nc, va:vb), 0, 2);
    wc_var_k = var(data_k.pwcDfk_l(1:n_wc, va:vb), 0, 2);

    % Power spectrum: same window as variance (in spectral bins)
    onsetBin = data_k.freqOnsetBin;
    sortWinF = max(1, onsetBin - specPreBins) : min(size(nc_spec_k, 2), onsetBin + dur_k - 1);
    if isempty(sortWinF), continue; end

    delta_msk = freqCtrs >= 1 & freqCtrs <= 4;
    if ~any(delta_msk), continue; end

    nc_spec_k_avg = reshape(mean(nc_spec_k(1:n_nc, sortWinF, :), 2), n_nc, []);
    wc_spec_k_avg = reshape(mean(wc_spec_k(1:n_wc, sortWinF, :), 2), n_wc, []);
    nc_norm_k = nc_spec_k_avg ./ (sum(nc_spec_k_avg, 2) + eps_v);
    wc_norm_k = wc_spec_k_avg ./ (sum(wc_spec_k_avg, 2) + eps_v);
    nc_delt_k = mean(nc_norm_k(:, delta_msk), 2, 'omitnan');
    wc_delt_k = mean(wc_norm_k(:, delta_msk), 2, 'omitnan');

    nc_spec  = [nc_spec;  nc_spec_k_avg(nc_keep, :)]; %#ok<AGROW>
    wc_spec  = [wc_spec;  wc_spec_k_avg(wc_keep, :)];
    nc_var   = [nc_var;   nc_var_k(nc_keep)];
    wc_var   = [wc_var;   wc_var_k(wc_keep)];
    nc_delta = [nc_delta; nc_delt_k(nc_keep)];
    wc_delta = [wc_delta; wc_delt_k(wc_keep)];
    nc_mse   = [nc_mse;   data_k.er_ncDfk(nc_keep)];
    wc_mse   = [wc_mse;   data_k.er_wcDfk(wc_keep)];
end

if isempty(nc_spec) || isempty(freqCtrs)
    warning('trial_state_mse: no valid sessions found.');
    return;
end

fprintf('[state_mse] %d OL  /  %d CL  trials pooled (motion-clean).\n', ...
    size(nc_spec,1), size(wc_spec,1));

%% Sort by variance (ascending) -----------------------------------------------
[nc_var_s, nc_ord] = sort(nc_var, 'ascend');
[wc_var_s, wc_ord] = sort(wc_var, 'ascend');

nc_spec_s   = nc_spec(nc_ord, :);   wc_spec_s   = wc_spec(wc_ord, :);
nc_delta_s  = nc_delta(nc_ord);     wc_delta_s  = wc_delta(wc_ord);
nc_mse_s    = nc_mse(nc_ord);       wc_mse_s    = wc_mse(wc_ord);
nT_nc       = size(nc_spec_s, 1);   nT_wc       = size(wc_spec_s, 1);

%% Block means ----------------------------------------------------------------
nBlk_nc  = floor(nT_nc / blockSize);
nBlk_wc  = floor(nT_wc / blockSize);
bYpos_nc = ((1:nBlk_nc)' - 0.5) * blockSize + 0.5;
bYpos_wc = ((1:nBlk_wc)' - 0.5) * blockSize + 0.5;

bMSE_nc  = zeros(nBlk_nc,1);  bMSE_sem_nc  = zeros(nBlk_nc,1);
bVar_nc  = zeros(nBlk_nc,1);
bDlt_nc  = zeros(nBlk_nc,1);
bMSE_wc  = zeros(nBlk_wc,1);  bMSE_sem_wc  = zeros(nBlk_wc,1);
bVar_wc  = zeros(nBlk_wc,1);
bDlt_wc  = zeros(nBlk_wc,1);

for ib = 1:nBlk_nc
    idx = (ib-1)*blockSize + (1:blockSize);
    bMSE_nc(ib)     = mean(nc_mse_s(idx),   'omitnan');
    bMSE_sem_nc(ib) = std( nc_mse_s(idx),   'omitnan') / sqrt(blockSize);
    bVar_nc(ib)     = mean(nc_var_s(idx),   'omitnan');
    bDlt_nc(ib)     = mean(nc_delta_s(idx), 'omitnan');
end
for ib = 1:nBlk_wc
    idx = (ib-1)*blockSize + (1:blockSize);
    bMSE_wc(ib)     = mean(wc_mse_s(idx),   'omitnan');
    bMSE_sem_wc(ib) = std( wc_mse_s(idx),   'omitnan') / sqrt(blockSize);
    bVar_wc(ib)     = mean(wc_var_s(idx),   'omitnan');
    bDlt_wc(ib)     = mean(wc_delta_s(idx), 'omitnan');
end

% Print correlations (not shown on figure)
[r_mv_nc, p_mv_nc] = corr(bMSE_nc, bVar_nc, 'rows','complete');
[r_mv_wc, p_mv_wc] = corr(bMSE_wc, bVar_wc, 'rows','complete');
[r_md_nc, p_md_nc] = corr(bMSE_nc, bDlt_nc, 'rows','complete');
[r_md_wc, p_md_wc] = corr(bMSE_wc, bDlt_wc, 'rows','complete');
fprintf('[state_mse] OL  MSE~var:   r=%.3f  p=%.4f\n', r_mv_nc, p_mv_nc);
fprintf('[state_mse] CL  MSE~var:   r=%.3f  p=%.4f\n', r_mv_wc, p_mv_wc);
fprintf('[state_mse] OL  MSE~delta: r=%.3f  p=%.4f\n', r_md_nc, p_md_nc);
fprintf('[state_mse] CL  MSE~delta: r=%.3f  p=%.4f\n', r_md_wc, p_md_wc);

%% Figure layout (12 x 8 cm, 2 cols x 2 rows) ---------------------------------
% Y-tick positions showing actual values (5 ticks per panel)
ntick_nc = min(5, nBlk_nc);
tidx_nc  = round(linspace(1, nBlk_nc, ntick_nc));
ntick_wc = min(5, nBlk_wc);
tidx_wc  = round(linspace(1, nBlk_wc, ntick_wc));

% f x power(f) -- flattens the 1/f spectrum so bands above 0-1 Hz are visible
% (deterministic per-band weight, same for OL/CL/all trials -- not a
% trial-relative normalization)
nc_specw_s = nc_spec_s .* freqCtrs;
wc_specw_s = wc_spec_s .* freqCtrs;

% Power spectrum heatmap colour limits (log10 of f x power, percentile-based)
spec_pool = log10([nc_specw_s(:); wc_specw_s(:)] + eps_v);
clim_spec = prctile(spec_pool, [2 98]);
cmap_spec = parula(256);

% Panel geometry (normalised units)
hm_x   = 0.09;   hm_w  = 0.40;
cb_x   = hm_x  + hm_w  + 0.012;  cb_w  = 0.015;
sc1_x  = cb_x  + cb_w  + 0.09;   sc_w  = 0.35;
row_h  = 0.40;   y_ol  = 0.55;    y_cl  = 0.11;

colOL = PS.col_ol;
colCL = PS.col_cl;

fig = paperFig(12, 8);
ax_ol_hm  = axes(fig, 'Position', [hm_x,  y_ol, hm_w, row_h]);
ax_cl_hm  = axes(fig, 'Position', [hm_x,  y_cl, hm_w, row_h]);
ax_ol_sc1 = axes(fig, 'Position', [sc1_x, y_ol, sc_w, row_h]);
ax_cl_sc1 = axes(fig, 'Position', [sc1_x, y_cl, sc_w, row_h]);

% Thin colourbar strip (shared visual label)
ax_cb = axes(fig, 'Position', [cb_x, y_ol + row_h*0.20, cb_w, row_h*0.60]);
imagesc(ax_cb, 1, [0 1], linspace(0,1,256)');
colormap(ax_cb, cmap_spec);
cb_ticks = [clim_spec(1), mean(clim_spec), clim_spec(2)];
set(ax_cb, 'YDir','normal','XTick',[],'YTick',[0 0.5 1], ...
    'YTickLabel', arrayfun(@(v) sprintf('%.1f',v), cb_ticks, 'UniformOutput',false), ...
    'YAxisLocation','right', ...
    'FontSize',5,'FontWeight','bold','TickDir','out','Box','off');
text(ax_cb, 0.5, -0.06, {'log_{10}(f \times power)';'(\DeltaF/F)^2'}, 'Units','normalized','FontSize',5, ...
    'FontWeight','bold','Color',[0.4 0.4 0.4], ...
    'HorizontalAlignment','center','VerticalAlignment','top','Clipping','off');

%% Col 1: power spectrum heatmaps, sorted by variance --------------------------
imagesc(ax_ol_hm, freqCtrs, 1:nT_nc, log10(nc_specw_s + eps_v));
colormap(ax_ol_hm, cmap_spec);  clim(ax_ol_hm, clim_spec);
hold(ax_ol_hm,'on');
plot(ax_ol_hm, [1 1], [0.5 nT_nc+0.5], 'w--', 'LineWidth',0.6);
plot(ax_ol_hm, [4 4], [0.5 nT_nc+0.5], 'w--', 'LineWidth',0.6);
hold(ax_ol_hm,'off');
set(ax_ol_hm, 'Box','off','TickDir','out','FontSize',6, ...
    'FontWeight','bold','XTickLabel',{},'YTick',[]);
ylabel(ax_ol_hm, 'OL', 'FontSize',6,'FontWeight','bold');
title(ax_ol_hm, sprintf('Power spectrum (%s)', winLabel), 'FontSize',6,'FontWeight','bold');

imagesc(ax_cl_hm, freqCtrs, 1:nT_wc, log10(wc_specw_s + eps_v));
colormap(ax_cl_hm, cmap_spec);  clim(ax_cl_hm, clim_spec);
hold(ax_cl_hm,'on');
plot(ax_cl_hm, [1 1], [0.5 nT_wc+0.5], 'w--', 'LineWidth',0.6);
plot(ax_cl_hm, [4 4], [0.5 nT_wc+0.5], 'w--', 'LineWidth',0.6);
hold(ax_cl_hm,'off');
set(ax_cl_hm, 'Box','off','TickDir','out','FontSize',6, ...
    'FontWeight','bold','YTick',[]);
ylabel(ax_cl_hm, 'CL', 'FontSize',6,'FontWeight','bold');
xlabel(ax_cl_hm, 'Frequency (Hz)', 'FontSize',6,'FontWeight','bold');
title(ax_cl_hm, sprintf('Power spectrum (%s)', winLabel), 'FontSize',6,'FontWeight','bold');

%% Col 2: variance vs MSE (Y = rank position, labels = variance values) -------
hold(ax_ol_sc1,'on');
errorbar(ax_ol_sc1, bMSE_nc, bYpos_nc, ...
    zeros(nBlk_nc,1), zeros(nBlk_nc,1), bMSE_sem_nc, bMSE_sem_nc, ...
    'o','Color',colOL,'MarkerFaceColor',colOL,'MarkerEdgeColor','none', ...
    'MarkerSize',3,'LineWidth',0.8,'CapSize',2,'HandleVisibility','off');
hold(ax_ol_sc1,'off');
set(ax_ol_sc1, 'Box','off','TickDir','out','FontSize',6,'FontWeight','bold', ...
    'XTickLabel',{}, 'YTick', bYpos_nc(tidx_nc), ...
    'YTickLabel', arrayfun(@(v) sprintf('%.1f',v), bVar_nc(tidx_nc), 'UniformOutput',false));
ylabel(ax_ol_sc1, 'Variance  (\DeltaF/F)^2', 'FontSize',6,'FontWeight','bold');

hold(ax_cl_sc1,'on');
errorbar(ax_cl_sc1, bMSE_wc, bYpos_wc, ...
    zeros(nBlk_wc,1), zeros(nBlk_wc,1), bMSE_sem_wc, bMSE_sem_wc, ...
    'o','Color',colCL,'MarkerFaceColor',colCL,'MarkerEdgeColor','none', ...
    'MarkerSize',3,'LineWidth',0.8,'CapSize',2,'HandleVisibility','off');
hold(ax_cl_sc1,'off');
set(ax_cl_sc1, 'Box','off','TickDir','out','FontSize',6,'FontWeight','bold', ...
    'YTick', bYpos_wc(tidx_wc), ...
    'YTickLabel', arrayfun(@(v) sprintf('%.1f',v), bVar_wc(tidx_wc), 'UniformOutput',false));
xlabel(ax_cl_sc1, 'Trial MSE', 'FontSize',6,'FontWeight','bold');
ylabel(ax_cl_sc1, 'Variance  (\DeltaF/F)^2', 'FontSize',6,'FontWeight','bold');

%% Link axes ------------------------------------------------------------------
% Each row: heatmap + scatter share rank Y
linkaxes([ax_ol_hm, ax_ol_sc1], 'y');
linkaxes([ax_cl_hm, ax_cl_sc1], 'y');
linkaxes([ax_ol_hm, ax_cl_hm], 'x');      % frequency X on heatmaps
linkaxes([ax_ol_sc1, ax_cl_sc1], 'x');    % MSE X
