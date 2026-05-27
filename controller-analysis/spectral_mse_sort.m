% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).

%% Figures I & J -- Spectral heatmaps sorted by MSE (absolute power: S_bands)
% ncFreqPow/wcFreqPow store raw FFT^2 power (no band/total normalization).
% Old caches that only have ncFreqSpec (relative) are used as fallback.

% --- Pass 1: collect per-trial mean power for all sessions ---
nc_all     = [];  wc_all     = [];
nc_mse_all = [];  wc_mse_all = [];
freqCtrs   = [];

sess_nc    = cell(nSess, 1);
sess_wc    = cell(nSess, 1);
sess_valid = false(nSess, 1);
use_abs_power = false;   % set true once any session has ncFreqPow

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;

    % Prefer absolute power; fall back to relative if cache is old
    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;
        wc_spec = data_k.wcFreqPow;
        use_abs_power = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec;
        wc_spec = data_k.wcFreqSpec;
    else
        continue;
    end

    dur_k    = mouse.(fields{k}).d.params.dur;
    onsetBin = data_k.freqOnsetBin;
    winStart = onsetBin - 1;
    winEnd   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean = reshape(mean(nc_spec(:, winStart:winEnd, :), 2), size(nc_spec, 1), []);
    wc_mean = reshape(mean(wc_spec(:, winStart:winEnd, :), 2), size(wc_spec, 1), []);

    sess_nc{k}    = nc_mean;
    sess_wc{k}    = wc_mean;
    sess_valid(k) = true;
    freqCtrs      = data_k.freqBandCtrs;

    nc_all     = [nc_all;     nc_mean];
    wc_all     = [wc_all;     wc_mean];
    nc_mse_all = [nc_mse_all; data_k.er_ncDfk];
    wc_mse_all = [wc_mse_all; data_k.er_wcDfk];
end

if use_abs_power
    cbar_label = 'Power (\DeltaF/F)^2 Hz^{-1}';
else
    cbar_label = 'band/total power';
end

% Color limit: 98th percentile of pooled power (clips outliers)
clim_val = prctile([nc_all(:); wc_all(:)], 98);

% --- Figure I: per-session heatmaps, shared color scale, interactive ---
nSess_f  = 4;
nRows_f  = ceil(sum(sess_valid) / nSess_f);

lm       = 0.03;   rm      = 0.05;
tm       = 0.04;   bm      = 0.05;
sess_gap = 0.022;
pair_gap = 0.003;
row_gap  = 0.10;

pw = (1 - lm - rm - nSess_f*pair_gap - (nSess_f-1)*sess_gap) / (nSess_f*2);
ph = (1 - tm - bm - (nRows_f-1)*row_gap) / nRows_f;

fig_I = figure('Color','w', 'Units','centimeters', 'Position',[0 0 nSess_f*11.4 nRows_f*8.9]);

sessIdx = 0;
ax_last = [];

for k = 1:nSess
    if ~sess_valid(k); continue; end
    data_k = mouse.(fields{k}).data;

    nc_mean = sess_nc{k};
    wc_mean = sess_wc{k};

    [~, nc_ord] = sort(data_k.er_ncDfk, 'ascend');
    [~, wc_ord] = sort(data_k.er_wcDfk, 'ascend');

    sessIdx  = sessIdx + 1;
    row      = floor((sessIdx-1) / nSess_f);
    col_pair = mod(sessIdx-1,    nSess_f);

    x_ol = lm + col_pair * (2*pw + pair_gap + sess_gap);
    x_cl = x_ol + pw + pair_gap;
    y    = 1 - tm - (row+1)*ph - row*row_gap;

    sesslabel = sprintf('%s %s e%d', mouse.(fields{k}).mn, ...
        mouse.(fields{k}).td, mouse.(fields{k}).en);

    ud_base.d            = mouse.(fields{k}).d;
    ud_base.dFk          = data_k.dFk;
    ud_base.freqBandCtrs = freqCtrs;
    ud_base.freqOnsetBin = data_k.freqOnsetBin;

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec_k = data_k.ncFreqPow;
        wc_spec_k = data_k.wcFreqPow;
    else
        nc_spec_k = data_k.ncFreqSpec;
        wc_spec_k = data_k.wcFreqSpec;
    end

    ud_ol              = ud_base;
    ud_ol.sorted_order = nc_ord;
    ud_ol.trial_idx    = data_k.nc;
    ud_ol.freq_spec    = nc_spec_k;
    ud_ol.lbl          = 'OL';

    ud_cl              = ud_base;
    ud_cl.sorted_order = wc_ord;
    ud_cl.trial_idx    = data_k.wc;
    ud_cl.freq_spec    = wc_spec_k;
    ud_cl.lbl          = 'CL';

    ax_ol = axes(fig_I, 'Position', [x_ol, y, pw, ph]);
    im_ol = imagesc(ax_ol, freqCtrs, 1:size(nc_mean,1), nc_mean(nc_ord,:));
    colormap(ax_ol, 'hot'); clim(ax_ol, [0 clim_val]);
    title(ax_ol, [sesslabel '  OL'], 'FontSize', 6, 'FontWeight','bold', 'Interpreter','none');
    set(ax_ol, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6);
    im_ol.ButtonDownFcn = @(s,e) heatmapClickCallback(s, e, ud_ol);

    ax_cl = axes(fig_I, 'Position', [x_cl, y, pw, ph]);
    im_cl = imagesc(ax_cl, freqCtrs, 1:size(wc_mean,1), wc_mean(wc_ord,:));
    colormap(ax_cl, 'hot'); clim(ax_cl, [0 clim_val]);
    title(ax_cl, [sesslabel '  CL'], 'FontSize', 6, 'FontWeight','bold', 'Interpreter','none');
    set(ax_cl, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6, 'YTickLabel', {});
    im_cl.ButtonDownFcn = @(s,e) heatmapClickCallback(s, e, ud_cl);

    ax_last = ax_cl;
end

if ~isempty(ax_last)
    cb = colorbar(ax_last); cb.Label.String = cbar_label; cb.FontSize = 6;
end
exportgraphics(fig_I, 'paper/freq_heatmap_sessions.png', 'Resolution', 300);
fprintf('Figure I ready -- click any row to inspect that trial.\n');

% --- Figure J: combined heatmap (all sessions pooled, raw MSE sort) ---
[~, nc_ord_all] = sort(nc_mse_all, 'ascend');
[~, wc_ord_all] = sort(wc_mse_all, 'ascend');

lm_j = 0.08; rm_j = 0.12; bm_j = 0.10; tm_j = 0.06; mid_gap = 0.04;
pw_j = (1 - lm_j - rm_j - mid_gap) / 2;
ph_j = 1 - tm_j - bm_j;

fig_J = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

ax_ol = axes(fig_J, 'Position', [lm_j,              bm_j, pw_j, ph_j]);
imagesc(ax_ol, freqCtrs, 1:size(nc_all,1), nc_all(nc_ord_all,:));
colormap(ax_ol, 'hot'); clim(ax_ol, [0 clim_val]);
set(ax_ol, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6);
xlabel(ax_ol, 'Frequency (Hz)', 'FontWeight','bold');
ylabel(ax_ol, 'Trial (low \rightarrow high MSE)', 'FontWeight','bold');
title(ax_ol, 'Open-Loop', 'FontSize', 6, 'FontWeight','bold');

ax_cl = axes(fig_J, 'Position', [lm_j+pw_j+mid_gap, bm_j, pw_j, ph_j]);
imagesc(ax_cl, freqCtrs, 1:size(wc_all,1), wc_all(wc_ord_all,:));
colormap(ax_cl, 'hot'); clim(ax_cl, [0 clim_val]);
set(ax_cl, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 6, 'YTickLabel', {});
xlabel(ax_cl, 'Frequency (Hz)', 'FontWeight','bold');
title(ax_cl, 'Closed-Loop', 'FontSize', 6, 'FontWeight','bold');
cb = colorbar(ax_cl); cb.Label.String = cbar_label; cb.FontSize = 6;
exportgraphics(fig_J, 'paper/freq_heatmap_combined.png', 'Resolution', 300);

% Figure K removed -- band-normalised view is redundant when using absolute power (S_bands).

%% Figure J2 -- MSE-sorted spectral heatmap, motion-clean trials (|z-motion| <= 1.5)
motThresh  = 0.5;
iMode_j2   = motModes(1);   % 2 s pre + full trial

nc_all_m = []; wc_all_m = [];
nc_mse_m = []; wc_mse_m = [];
n_exc_nc = 0;  n_exc_wc = 0;
n_tot_nc = 0;  n_tot_wc = 0;
freqCtrs_m = [];
use_abs_m  = false;

for k = 1:nSess
    if isfield(mouse.(fields{k}), 'skip'),  continue; end
    if ~isfield(mouse.(fields{k}), 'data'), continue; end
    data_k = mouse.(fields{k}).data;

    if ~isfield(data_k, 'ncmotion') || ~any(data_k.ncmotion(:)), continue; end

    if isfield(data_k, 'ncFreqPow') && any(data_k.ncFreqPow(:))
        nc_spec = data_k.ncFreqPow;
        wc_spec = data_k.wcFreqPow;
        use_abs_m = true;
    elseif isfield(data_k, 'ncFreqSpec') && any(data_k.ncFreqSpec(:))
        nc_spec = data_k.ncFreqSpec;
        wc_spec = data_k.wcFreqSpec;
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

    nc_keep = abs(ncm) <= motThresh;
    wc_keep = abs(wcm) <= motThresh;

    n_tot_nc = n_tot_nc + numel(ncm);
    n_tot_wc = n_tot_wc + numel(wcm);
    n_exc_nc = n_exc_nc + sum(~nc_keep);
    n_exc_wc = n_exc_wc + sum(~wc_keep);

    onsetBin  = data_k.freqOnsetBin;
    winStartF = onsetBin - 1;
    winEndF   = min(onsetBin + dur_k - 1, size(nc_spec, 2));

    nc_mean_k = reshape(mean(nc_spec(:, winStartF:winEndF, :), 2), size(nc_spec,1), []);
    wc_mean_k = reshape(mean(wc_spec(:, winStartF:winEndF, :), 2), size(wc_spec,1), []);

    nc_all_m = [nc_all_m; nc_mean_k(nc_keep, :)];
    wc_all_m = [wc_all_m; wc_mean_k(wc_keep, :)];
    nc_mse_m = [nc_mse_m; data_k.er_ncDfk(nc_keep)];
    wc_mse_m = [wc_mse_m; data_k.er_wcDfk(wc_keep)];

    freqCtrs_m = data_k.freqBandCtrs;
end

fprintf('Motion-clean: OL %d/%d kept (%.0f%% excluded)  CL %d/%d kept (%.0f%% excluded)\n', ...
    n_tot_nc - n_exc_nc, n_tot_nc, 100*n_exc_nc/max(n_tot_nc,1), ...
    n_tot_wc - n_exc_wc, n_tot_wc, 100*n_exc_wc/max(n_tot_wc,1));

if ~isempty(nc_all_m) && ~isempty(freqCtrs_m)
    [~, nc_ord_m] = sort(nc_mse_m, 'ascend');
    [~, wc_ord_m] = sort(wc_mse_m, 'ascend');

    clim_m = prctile([nc_all_m(:); wc_all_m(:)], 98);
    if use_abs_m
        cbar_lbl_m = 'Power (\DeltaF/F)^2 Hz^{-1}';
    else
        cbar_lbl_m = 'band/total power';
    end

    lm_j2 = 0.08; rm_j2 = 0.12; bm_j2 = 0.10; tm_j2 = 0.06; mid_gap2 = 0.04;
    pw_j2 = (1 - lm_j2 - rm_j2 - mid_gap2) / 2;
    ph_j2 = 1 - tm_j2 - bm_j2;

    fig_J2 = figure('Color','w', 'Units','centimeters', 'Position',[0 0 25.4 15.2]);

    ax_ol2 = axes(fig_J2, 'Position', [lm_j2,                bm_j2, pw_j2, ph_j2]);
    imagesc(ax_ol2, freqCtrs_m, 1:size(nc_all_m,1), nc_all_m(nc_ord_m,:));
    colormap(ax_ol2, 'hot'); clim(ax_ol2, [0 clim_m]);
    set(ax_ol2, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize',6);
    xlabel(ax_ol2, 'Frequency (Hz)', 'FontWeight','bold');
    ylabel(ax_ol2, 'Trial (low \rightarrow high MSE)', 'FontWeight','bold');
    title(ax_ol2, sprintf('Open-Loop  (motion-clean, |z| \\leq %.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');

    ax_cl2 = axes(fig_J2, 'Position', [lm_j2+pw_j2+mid_gap2, bm_j2, pw_j2, ph_j2]);
    imagesc(ax_cl2, freqCtrs_m, 1:size(wc_all_m,1), wc_all_m(wc_ord_m,:));
    colormap(ax_cl2, 'hot'); clim(ax_cl2, [0 clim_m]);
    set(ax_cl2, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize',6, 'YTickLabel',{});
    xlabel(ax_cl2, 'Frequency (Hz)', 'FontWeight','bold');
    title(ax_cl2, sprintf('Closed-Loop  (motion-clean, |z| \\leq %.1f)', motThresh), ...
        'FontSize',6, 'FontWeight','bold');
    cb2 = colorbar(ax_cl2); cb2.Label.String = cbar_lbl_m; cb2.FontSize = 6;

    exportgraphics(fig_J2, 'paper/freq_heatmap_motionclean.png', 'Resolution',300);
    % fprintf('Figure J2 saved ->' paper/freq_heatmap_motionclean.png\n');
end
