% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

%% Pre-trial variance sort â€” scatter (row 1) + errorbar by variance quintile (row 2)
%
% For each amplitude:
%   Row 1: scatter(pre-trial variance, |Peak_imp dev|) + Pearson r
%   Row 2: trials binned into 5 variance quintiles â†’ mean Â± SEM of |Peak_imp dev|
%
% Subplot index uses column/group calculation so the layout is correct
% when nAmp > 4 and amplitudes wrap across rows.

if ~exist('t_win_imp', 'var')
    t_win_imp = -3 : 1/35 : 3;
end

preIdx_var = t_win_imp >= -1 & t_win_imp < 0;   % 35 samples, -1 to 0 s
nVarBins   = 5;

for expIdx = 1:nExp

    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    nCols_v = min(nAmp_e, 4);
    nRows_v = ceil(nAmp_e / nCols_v);   % amplitude row-groups
    nGridR  = nRows_v * 2;              % total subplot rows (scatter + eb per group)

    fig_v = figure('Color','w');
    fig_v.Units    = 'centimeters';
    fig_v.Position = [2, 2, nCols_v*6, nRows_v*2*4];
    sgtitle(sprintf('%s  %s  e%d â€” pre-trial variance vs inhibition deviation', ...
        allExperiments(expIdx).mn, allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 8, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        df_i  = imp_e.dfImp{iAmp};
        if isfield(imp_e, 'cp_err') && ~isempty(imp_e.cp_err{iAmp})
            dev_i = imp_e.cp_err{iAmp}(:);
        else
            dev_i = imp_e.Peak_imp_dev{iAmp}(:);
        end
        n_i   = min(size(df_i,1), numel(dev_i));
        if n_i < 3, continue; end
        df_i  = df_i(1:n_i, :);
        dev_i = dev_i(1:n_i);

        preVar_i = var(df_i(:, preIdx_var), 0, 2);   % nTrials Ã— 1

        [r_v, p_v] = corr(preVar_i, dev_i, 'rows','complete');

        % Correct subplot indices: each amplitude occupies one column;
        % amplitudes wrap every nCols_v, each wrap uses 2 grid rows.
        col_v   = mod(iAmp-1, nCols_v) + 1;
        grp_v   = ceil(iAmp / nCols_v);
        sp_top  = (grp_v-1)*2*nCols_v + col_v;        % scatter row
        sp_bot  = (grp_v-1)*2*nCols_v + nCols_v + col_v;  % errorbar row

        % Row 1: scatter
        ax1 = subplot(nGridR, nCols_v, sp_top);
        scatter(ax1, preVar_i, dev_i, 12, 'filled', 'MarkerFaceAlpha', 0.5);
        xlabel(ax1, 'Pre-trial var (\DeltaF/F)^2', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax1, 'Prediction error', 'FontSize', 6, 'FontWeight','bold');
        title(ax1, sprintf('%.2f V  r=%.2f  p=%.3f', imp_e.uAmp{iAmp}, r_v, p_v), ...
            'FontSize', 6, 'FontWeight','bold');
        set(ax1, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');

        % Row 2: mean Â± SEM of |Peak dev| per variance quintile
        edges_v  = quantile(preVar_i, linspace(0, 1, nVarBins+1));
        edges_v(1) = edges_v(1) - eps;
        [~, ~, binID] = histcounts(preVar_i, edges_v);
        eb_mu  = zeros(nVarBins, 1);
        eb_sem = zeros(nVarBins, 1);
        for ib = 1:nVarBins
            vals = dev_i(binID == ib);
            eb_mu(ib)  = mean(vals, 'omitnan');
            eb_sem(ib) = std(vals, 'omitnan') / sqrt(max(sum(~isnan(vals)), 1));
        end

        ax2 = subplot(nGridR, nCols_v, sp_bot);
        errorbar(ax2, 1:nVarBins, eb_mu, eb_sem, 'o-', ...
            'Color',[0.2 0.4 0.8], 'MarkerFaceColor',[0.2 0.4 0.8], ...
            'MarkerSize', 4, 'LineWidth', 0.8, 'CapSize', 4);
        xticks(ax2, 1:nVarBins);
        xticklabels(ax2, {'Q1','Q2','Q3','Q4','Q5'});
        xlabel(ax2, 'Pre-trial var quintile', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax2, 'Mean prediction error ± SEM', 'FontSize', 6, 'FontWeight','bold');
        title(ax2, sprintf('n=%d', n_i), 'FontSize', 6, 'FontWeight','bold');
        set(ax2, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');
    end
end



%% Pre-trial variance vs deviation (per session, motion-excluded)
%
% Per-session, per-amplitude: scatter of pre-trial variance vs |Peak dev|,
% plus quintile errorbar.  Top 25% motion trials excluded.
% Diagnostic only â€” no export.

for expIdx = 1:nExp

    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    % Threshold across all amplitudes for this experiment
    mot_rows_e = cellfun(@(x) x(:)', imp_e.mot, 'UniformOutput', false);
    all_mot_e  = horzcat(mot_rows_e{:});
    mot_thresh = prctile(all_mot_e(:), 75);

    nCols_m = min(nAmp_e, 4);
    nRows_m = ceil(nAmp_e / nCols_m);
    nGridR_m = nRows_m * 2;

    fig_m = figure('Color','w');
    fig_m.Units    = 'centimeters';
    fig_m.Position = [2, 2, nCols_m*6, nRows_m*2*4];
    sgtitle(sprintf('%s  %s  e%d â€” pre-trial variance (motion-excluded, top 25%% removed)', ...
        allExperiments(expIdx).mn, allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 8, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        df_i    = imp_e.dfImp{iAmp};
        pk_i    = imp_e.Peak_imp{iAmp}(:);
        mot_i   = imp_e.mot{iAmp}(:);
        n_total = min([size(df_i,1), numel(pk_i), numel(mot_i)]);
        if isfield(imp_e, 'cp_err') && ~isempty(imp_e.cp_err{iAmp})
            n_total = min(n_total, numel(imp_e.cp_err{iAmp}));
        end
        if n_total < 3, continue; end

        df_i  = df_i(1:n_total, :);
        pk_i  = pk_i(1:n_total);
        mot_i = mot_i(1:n_total);

        keepIdx = mot_i <= mot_thresh;
        n_kept  = sum(keepIdx);
        if n_kept < 3, continue; end

        df_clean  = df_i(keepIdx, :);
        pk_clean  = pk_i(keepIdx);
        if isfield(imp_e, 'cp_err') && ~isempty(imp_e.cp_err{iAmp})
            cp_err_i  = imp_e.cp_err{iAmp}(1:n_total);
            dev_clean = cp_err_i(keepIdx);
        else
            dev_clean = abs(pk_clean - mean(pk_clean, 'omitnan'));
        end
        mot_clean = imp_e.motTrace{iAmp}(keepIdx, :);

        preVar_clean = var(df_clean(:, preIdx_var), 0, 2);
        [r_m, p_m]   = corr(preVar_clean, dev_clean, 'rows','complete');

        % Correct subplot indices
        col_m  = mod(iAmp-1, nCols_m) + 1;
        grp_m  = ceil(iAmp / nCols_m);
        sp_top = (grp_m-1)*2*nCols_m + col_m;
        sp_bot = (grp_m-1)*2*nCols_m + nCols_m + col_m;

        % Row 1: scatter (clickable)
        ax1 = subplot(nGridR_m, nCols_m, sp_top);
        hS = scatter(ax1, preVar_clean, dev_clean, 12, 'filled', 'MarkerFaceAlpha', 0.5);
        xlabel(ax1, 'Pre-trial var (\DeltaF/F)^2', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax1, 'Prediction error', 'FontSize', 6, 'FontWeight','bold');
        title(ax1, sprintf('%.2f V  r=%.2f  p=%.3f  (%d/%d)  [click]', ...
            imp_e.uAmp{iAmp}, r_m, p_m, n_kept, n_total), ...
            'FontSize', 6, 'FontWeight','bold');
        set(ax1, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');

        % Capture closure variables for callback
        c_ax1   = ax1;
        c_pvar  = preVar_clean;
        c_dev   = dev_clean;
        c_df    = df_clean;
        c_mot   = mot_clean;
        c_twin  = t_win_imp;
        c_amp   = imp_e.uAmp{iAmp};
        set(hS, 'ButtonDownFcn', ...
            @(~,~) varDetailCallback(c_ax1, c_pvar, c_dev, c_df, c_mot, c_twin, c_amp));

        % Row 2: mean Â± SEM of |Peak dev| per variance quintile
        edges_m = quantile(preVar_clean, linspace(0, 1, nVarBins+1));
        edges_m(1) = edges_m(1) - eps;
        [~, ~, binID_m] = histcounts(preVar_clean, edges_m);
        eb_mu_m  = zeros(nVarBins, 1);
        eb_sem_m = zeros(nVarBins, 1);
        for ib = 1:nVarBins
            vals = dev_clean(binID_m == ib);
            eb_mu_m(ib)  = mean(vals, 'omitnan');
            eb_sem_m(ib) = std(vals, 'omitnan') / sqrt(max(sum(~isnan(vals)), 1));
        end

        ax2 = subplot(nGridR_m, nCols_m, sp_bot);
        errorbar(ax2, 1:nVarBins, eb_mu_m, eb_sem_m, 'o-', ...
            'Color',[0.2 0.7 0.4], 'MarkerFaceColor',[0.2 0.7 0.4], ...
            'MarkerSize', 4, 'LineWidth', 0.8, 'CapSize', 4);
        xticks(ax2, 1:nVarBins);
        xticklabels(ax2, {'Q1','Q2','Q3','Q4','Q5'});
        xlabel(ax2, 'Pre-trial var quintile', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax2, 'Mean prediction error ± SEM', 'FontSize', 6, 'FontWeight','bold');
        title(ax2, sprintf('n=%d kept', n_kept), 'FontSize', 6, 'FontWeight','bold');
        set(ax2, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');
    end
end   % for expIdx - Section A

%% Pre-trial variance vs peak deviation â€” paper figure, motion-excluded (session selExp)
%
% Same as the all-trials paper figure above but top 25% motion trials removed.
% Motion threshold: 75th percentile of all motion values across all amps, session selExp.
% Deviation recomputed on kept trials only (mean shifts after removing noisy trials).

PS = paperStyle();
setPaperDefaults();

imp_pam   = allExperiments(selExp).imp;
nAmp_pam  = numel(imp_pam.uAmp);

% Motion threshold: 75th pctile across all amplitudes for this session
mot_rows_pam = cellfun(@(x) x(:)', imp_pam.mot, 'UniformOutput', false);
mot_thresh_pam = prctile(horzcat(mot_rows_pam{:}), 75);

vToMW_pam = 1.8 / 4.9;   % laser calibration: 0 V = 0 mW, 4.9 V = 1.8 mW

validAmps_pam = find(cellfun(@(x) x > 0, imp_pam.uAmp));
nV_pam        = numel(validAmps_pam);
% Grayscale color grading: lightest = weakest amp, darkest = strongest (matches Fig 2A scheme)
grayLevels_pam = linspace(0.85, 0.20, max(nV_pam, 1));
ampCmap_pam    = repmat(grayLevels_pam(:), 1, 3);   % nV_pam x 3 grayscale RGB

fig_pvm = paperFig(4, 4);
ax_pvm  = axes(fig_pvm);
hold(ax_pvm, 'on');

for ki = 1:nV_pam
    iAmp   = validAmps_pam(ki);
    df_i   = imp_pam.dfImp{iAmp};
    pk_i   = imp_pam.Peak_imp{iAmp}(:);
    mot_i  = imp_pam.mot{iAmp}(:);
    n_tot  = min([size(df_i,1), numel(pk_i), numel(mot_i)]);
    if n_tot < nVarBins + 1, continue; end

    df_i  = df_i(1:n_tot, :);
    pk_i  = pk_i(1:n_tot);
    mot_i = mot_i(1:n_tot);

    keepIdx = mot_i <= mot_thresh_pam;
    if sum(keepIdx) < nVarBins + 1, continue; end

    df_k   = df_i(keepIdx, :);
    pk_k   = pk_i(keepIdx);
    dev_k  = abs(pk_k - mean(pk_k, 'omitnan'));   % recomputed on kept trials

    preVar_k = var(df_k(:, preIdx_var), 0, 2);

    edges_pam    = quantile(preVar_k, linspace(0, 1, nVarBins + 1));
    edges_pam(1) = edges_pam(1) - eps;
    [~, ~, binID_pam] = histcounts(preVar_k, edges_pam);

    bin_mu_m  = zeros(nVarBins, 1);
    bin_sem_m = zeros(nVarBins, 1);
    bin_xmu_m = zeros(nVarBins, 1);
    for ib = 1:nVarBins
        mask_ib       = binID_pam == ib;
        vals_ib       = dev_k(mask_ib);
        bin_mu_m(ib)  = mean(vals_ib, 'omitnan');
        bin_sem_m(ib) = std(vals_ib, 'omitnan') / sqrt(max(sum(~isnan(vals_ib)), 1));
        bin_xmu_m(ib) = mean(preVar_k(mask_ib), 'omitnan');
    end

    col_pam = ampCmap_pam(ki, :);
    errorbar(ax_pvm, bin_xmu_m, bin_mu_m, bin_sem_m, 'o-', ...
        'Color', col_pam, 'MarkerFaceColor', col_pam, ...
        'MarkerSize', 3, 'LineWidth', PS.lw_mean, 'CapSize', 3, ...
        'DisplayName', sprintf('%.2f mW', imp_pam.uAmp{iAmp} * vToMW_pam));
end

hold(ax_pvm, 'off');
xlabel(ax_pvm, 'Pre-trial variance (\DeltaF/F)^2', 'FontWeight', 'bold');
ylabel(ax_pvm, 'Impulse Prediction Error', 'FontWeight', 'bold');
% title(ax_pvm, 'Pre-trial variance vs deviation (motion excluded)');
lg_pvm = legend(ax_pvm, 'Location', 'eastoutside');
paperLegend(lg_pvm);

mn_pam = allExperiments(selExp).mn;
td_pam = allExperiments(selExp).td;
en_pam = allExperiments(selExp).en;
paperExport(fig_pvm, ...
    fullfile(paperRoot, 'images', 'figure2', sprintf('prevar_vs_dev_allamps_motexcl_%s_%s_en%d.pdf', mn_pam, td_pam, en_pam)));

%% Freq heatmap sorted by pre-trial variance + deviation side strip (interactive)
%
% Trials sorted ascending by pre-trial variance (motion removed, session selExp).
% X axis: frequency bands (freqBandCtrs).
% Left panel: spectral power heatmap (parula). 1-4 Hz band highlighted.
% Right strip: absolute deviation |Peak_imp - mean| per trial (hot colormap).
%
% Click any row in either panel to open a 3-panel detail figure for that trial:
%   top   : dF/F trace (this trial, red) vs all kept-trial mean +/- SD (grey)
%   middle: frequency spectrum (this trial, red) vs mean spectrum (grey)
%   bottom: text summary (trial rank, pre-stim variance, deviation, amplitude)
%
% Static PNG is also exported.

% --- Pool data across amplitudes (motion excluded, same session and threshold) ---
imp_pvh        = allExperiments(selExp).imp;
nAmp_pvh       = numel(imp_pvh.uAmp);
mot_rows_pvh   = cellfun(@(x) x(:)', imp_pvh.mot, 'UniformOutput', false);
mot_thresh_pvh = prctile(horzcat(mot_rows_pvh{:}), 75);
vToMW_pvh      = 1.8 / 4.9;   % 0 V = 0 mW, 4.9 V = 1.8 mW

allPreVar_p   = [];
allFreq_p     = [];
allDev_p      = [];
allTrace_p    = [];
allAmpV_p     = [];   % amplitude in V per trial

% Spectral parameters for pre-stim window (same window as variance: -1..0 s)
% load_experiments uses ±1 s centred on onset — that includes post-stim activity.
% Here we recompute from the raw pre-stim trace so spectrum and variance are aligned.
nPre_smp = sum(preIdx_var);          % 35 samples = 1 s at fs=35 Hz
nfft_pv  = 2 * fs;                   % 70-pt FFT → Δf = 0.5 Hz, matches freqBandCtrs bins
W_hann   = sum(hann(nPre_smp).^2);  % Hann window normalisation factor

for iAmp_pvh = 1:nAmp_pvh
    df_i  = imp_pvh.dfImp{iAmp_pvh};
    pk_i  = imp_pvh.Peak_imp{iAmp_pvh}(:);
    mot_i = imp_pvh.mot{iAmp_pvh}(:);
    n_tot = min([size(df_i,1), numel(pk_i), numel(mot_i)]);
    if n_tot < 3, continue; end
    df_i  = df_i(1:n_tot, :);
    pk_i  = pk_i(1:n_tot);
    mot_i = mot_i(1:n_tot);

    keep = find(mot_i <= mot_thresh_pvh);
    if numel(keep) < 3, continue; end

    df_k   = df_i(keep, :);
    pk_k   = pk_i(keep);
    dev_k  = abs(pk_k - mean(pk_k, 'omitnan'));
    pvar_k = var(df_k(:, preIdx_var), 0, 2);

    % Recompute spectrum from the -1..0 s window of each kept trial
    freq_k = nan(numel(keep), nBands);
    for jj = 1:numel(keep)
        xj           = df_k(jj, preIdx_var)';
        Xj           = fft(xj .* hann(nPre_smp), nfft_pv);
        freq_k(jj,:) = abs(Xj(1:nBands)).^2 * 2 / (fs * W_hann);
    end

    allPreVar_p = [allPreVar_p; pvar_k];                                        %#ok<AGROW>
    allFreq_p   = [allFreq_p;   freq_k];                                        %#ok<AGROW>
    allDev_p    = [allDev_p;    dev_k];                                         %#ok<AGROW>
    allTrace_p  = [allTrace_p;  df_k];                                          %#ok<AGROW>
    allAmpV_p   = [allAmpV_p;   repmat(imp_pvh.uAmp{iAmp_pvh}, numel(keep), 1)]; %#ok<AGROW>
end

% --- Sort all pooled trials by pre-trial variance ---
[~, si_pv]       = sort(allPreVar_p, 'ascend');
freq_sorted_pv   = allFreq_p(si_pv, :);
dev_sorted_pv    = allDev_p(si_pv);
trace_sorted_pv  = allTrace_p(si_pv, :);
pvar_sorted_pv   = allPreVar_p(si_pv);
ampV_sorted_pv   = allAmpV_p(si_pv);
nT_pv            = numel(dev_sorted_pv);

% --- Build figure ---
fig_pvh = paperFig(10, 5);
tl_pvh  = tiledlayout(fig_pvh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel A: spectral heatmap (log10 power)
freq_log_pv = log10(max(freq_sorted_pv, 1e-6));
clim_log_pv = [prctile(freq_log_pv(:), 2), prctile(freq_log_pv(:), 98)];
ax_pvhA = nexttile(tl_pvh, 1);
hImg_A  = imagesc(ax_pvhA, freqBandCtrs, 1:nT_pv, freq_log_pv);
colormap(ax_pvhA, parula);
clim(ax_pvhA, clim_log_pv);
set(ax_pvhA, 'YDir', 'normal', 'Box', 'off', 'TickDir', 'out', ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_pvhA, 'Frequency (Hz)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pvhA, 'Trial (sorted by pre-stim variance, low->high)', ...
    'FontSize', 6, 'FontWeight', 'bold');
title(ax_pvhA, 'Spectral power log_{10}  [click row]', 'FontSize', 6, 'FontWeight', 'bold');
xticks(ax_pvhA, 0:2:10);
hold(ax_pvhA, 'on');
patch(ax_pvhA, [1 4 4 1], [0.5 0.5 nT_pv+0.5 nT_pv+0.5], ...
    [1 0.85 0.1], 'FaceAlpha', 0.13, 'EdgeColor', [0.85 0.6 0], ...
    'LineWidth', 0.8, 'HandleVisibility', 'off');
text(ax_pvhA, 2.5, 0, '\delta', ...
    'FontSize', 6, 'FontWeight', 'bold', 'Color', [0.75 0.45 0], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Clipping', 'off');
hold(ax_pvhA, 'off');
cb_pvhA = colorbar(ax_pvhA, 'Location', 'eastoutside');
cb_pvhA.Label.String   = 'log_{10} Power (\DeltaF/F)^2 Hz^{-1}';
cb_pvhA.Label.FontSize = 6;
cb_pvhA.FontSize       = 6;

% Panel B: deviation side strip
ax_pvhB = nexttile(tl_pvh, 2);
hImg_B  = imagesc(ax_pvhB, 1, 1:nT_pv, dev_sorted_pv);
colormap(ax_pvhB, hot);
clim(ax_pvhB, [0, prctile(dev_sorted_pv, 98)]);
set(ax_pvhB, 'YDir', 'normal', 'Box', 'off', 'TickDir', 'out', ...
    'XTick', [], 'FontSize', 6, 'FontWeight', 'bold', 'YTickLabel', {});
title(ax_pvhB, '|Dev| (dF/F)  [click]', 'FontSize', 6, 'FontWeight', 'bold');
cb_pvhB = colorbar(ax_pvhB, 'Location', 'eastoutside');
cb_pvhB.Label.String   = '|Peak dev| (\DeltaF/F %)';
cb_pvhB.Label.FontSize = 6;
cb_pvhB.FontSize       = 6;

% --- Attach click callbacks ---
% Capture all closure variables explicitly (avoids workspace-clear issues).
pvh_data.trace    = trace_sorted_pv;
pvh_data.dev      = dev_sorted_pv;
pvh_data.pvar     = pvar_sorted_pv;
pvh_data.ampV     = ampV_sorted_pv;
pvh_data.freq     = freq_sorted_pv;
pvh_data.fbCtrs   = freqBandCtrs;
pvh_data.twin     = t_win_imp;
pvh_data.nT       = nT_pv;
pvh_data.vToMW    = vToMW_pvh;
pvh_data.meanTr   = mean(trace_sorted_pv, 1, 'omitnan');
pvh_data.sdTr     = std(trace_sorted_pv, 0, 1);
pvh_data.meanFreq = mean(freq_sorted_pv, 1, 'omitnan');

set(hImg_A, 'ButtonDownFcn', @(~, ev) heatmapRowCallback(ev, ax_pvhA, pvh_data));
set(hImg_B, 'ButtonDownFcn', @(~, ev) heatmapRowCallback(ev, ax_pvhB, pvh_data));

%% Static paper figure 2G: log heatmap (left) + 50-trial block curve fit (right)
%
% Left panel : grayscale log10 heatmap, no Y ticks, horizontal colorbar above.
%              Delta band (1-4 Hz) highlighted. All trials are motion-excluded.
% Right panel: 50-trial batches, Y=trial rank (shared with left), X=z-score.
%              Two series on same X axis (z-scored for comparison):
%                gold  = batch mean delta power  (1-4 Hz)
%                red   = batch mean prediction error (|Peak dev|)
%              Each series has its own linear fit and r/p annotation.

% -- Block data: 50-trial batches --
blockSize         = 50;
nBlocks           = floor(nT_pv / blockSize);
blockDev          = zeros(nBlocks, 1);
blockDev_std      = zeros(nBlocks, 1);
blockYpos         = zeros(nBlocks, 1);
blockDeltaPow     = zeros(nBlocks, 1);
blockDeltaPow_std = zeros(nBlocks, 1);

% Delta band (1-4 Hz) mean power per trial (linear units)
deltaBands_pv = freqBandCtrs >= 1 & freqBandCtrs <= 4;
deltaPow_pv   = mean(freq_sorted_pv(:, deltaBands_pv), 2, 'omitnan');

for ib = 1:nBlocks
    idx                   = (ib-1)*blockSize + (1:blockSize);
    blockDev(ib)          = mean(dev_sorted_pv(idx), 'omitnan');
    blockDev_std(ib)      = std( dev_sorted_pv(idx), 'omitnan');
    blockYpos(ib)         = mean(idx);
    blockDeltaPow(ib)     = mean(deltaPow_pv(idx),   'omitnan');
    blockDeltaPow_std(ib) = std( deltaPow_pv(idx),   'omitnan');
end
blockDev_sem      = blockDev_std      / sqrt(blockSize);
blockDeltaPow_sem = blockDeltaPow_std / sqrt(blockSize);

% Fits and correlations
[r_blk, p_blk] = corr(blockDev, blockYpos,     'rows', 'complete');
[r_dp,  p_dp]  = corr(blockDev, blockDeltaPow, 'rows', 'complete');
xFit_blk = linspace(min(blockDev)*0.95, max(blockDev)*1.05, 200);
yFit_blk = polyval(polyfit(blockDev, blockYpos,     1), xFit_blk);
yFit_dp  = polyval(polyfit(blockDev, blockDeltaPow, 1), xFit_blk);

% NOTE FOR PAPER — transcribe to results_edit.tex and FINDINGS.md when final:
fprintf('[fig_pvs 2H] pred error vs trial rank:  r=%.3f  p=%.4f  (n=%d batches of %d)\n', r_blk, p_blk, nBlocks, blockSize);
fprintf('[fig_pvs 2H] delta power vs pred error: r=%.3f  p=%.4f\n', r_dp,  p_dp);

% -- Figure layout (3 panels + colorbar, 7 cm wide x 4 cm tall) --
% [left=0.06, w=0.33] heatmap | colorbar | [0.43, w=0.17] trial rank | [0.66, w=0.22] delta power
fig_pvs  = paperFig(7, 4);
ax_pvs_A = axes(fig_pvs, 'Position', [0.06 0.14 0.33 0.76]);
ax_pvs_B = axes(fig_pvs, 'Position', [0.43 0.14 0.17 0.76]);
ax_pvs_C = axes(fig_pvs, 'Position', [0.66 0.14 0.22 0.76]);

% --- Left: grayscale log heatmap (static, no click) ---
imagesc(ax_pvs_A, freqBandCtrs, 1:nT_pv, freq_log_pv);
colormap(ax_pvs_A, parula);
clim(ax_pvs_A, clim_log_pv);
set(ax_pvs_A, 'YDir', 'normal', 'Box', 'off', 'TickDir', 'out', ...
    'FontSize', 6, 'FontWeight', 'bold', 'YTick', []);
xlabel(ax_pvs_A, 'Frequency (Hz)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pvs_A, 'Trials sorted by pre-stim variance', 'FontSize', 6, 'FontWeight', 'bold');
xticks(ax_pvs_A, 0:2:10);
hold(ax_pvs_A, 'on');
patch(ax_pvs_A, [1 4 4 1], [0.5 0.5 nT_pv+0.5 nT_pv+0.5], ...
    [1 0.85 0.1], 'FaceAlpha', 0.13, 'EdgeColor', [0.85 0.6 0], ...
    'LineWidth', 0.8, 'HandleVisibility', 'off');
text(ax_pvs_A, 2.5, 0, '\delta', ...
    'FontSize', 6, 'FontWeight', 'bold', 'Color', [0.75 0.45 0], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Clipping', 'off');
text(ax_pvs_A, 0.98, 0.02, sprintf('n=%d trials', nT_pv), ...
    'Units', 'normalized', 'FontSize', 5, 'Color', [0.45 0.45 0.45], ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontWeight', 'bold');
hold(ax_pvs_A, 'off');

% --- Vertical short colorbar between panels ---
% Spans middle 45% of figure height, centred on the panel.
ax_cb = axes(fig_pvs, 'Position', [0.41 0.68 0.010 0.22]);  % between heatmap and middle panel, flush to top
imagesc(ax_cb, 1, [0 1], linspace(0,1,256)');   % column vector → vertical gradient
colormap(ax_cb, parula);
set(ax_cb, 'YDir', 'normal', 'XTick', [], ...
    'YTick', [0 1], 'YTickLabel', {'0','1'}, 'YAxisLocation', 'right', ...
    'FontSize', 5, 'FontWeight', 'bold', 'TickDir', 'out', 'Box', 'off');
text(ax_cb, 0.5, -0.10, {'normalized'; 'log power'}, 'Units', 'normalized', 'FontSize', 5, ...
    'FontWeight', 'bold', 'Color', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Clipping', 'off');

% --- Right: two z-scored series, shared Y=trial rank ---
col_err = [0.8 0.2 0.2];   % red — prediction error

hold(ax_pvs_B, 'on');
errorbar(ax_pvs_B, blockDev, blockYpos, ...
    zeros(nBlocks,1), zeros(nBlocks,1), ...  % no vertical bars
    blockDev_sem, blockDev_sem, ...          % horizontal ±SEM
    'o', 'Color', col_err, 'MarkerFaceColor', col_err, 'MarkerEdgeColor', 'none', ...
    'MarkerSize', 4, 'LineWidth', 0.8, 'CapSize', 3, 'HandleVisibility', 'off');
plot(ax_pvs_B, xFit_blk, yFit_blk, '-', 'Color', col_err, 'LineWidth', 1.5, ...
    'HandleVisibility', 'off');
hold(ax_pvs_B, 'off');

xlabel(ax_pvs_B, 'Impulse Prediction Error', 'FontSize', 6, 'FontWeight', 'bold');
set(ax_pvs_B, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, ...
    'YLim', [0.5, nT_pv+0.5], 'YDir', 'normal', 'YColor', 'none');

% Significance stars (p<0.05=*, p<0.01=**, p<0.001=***)
if     p_blk < 0.001,  sig_str = '***';
elseif p_blk < 0.01,   sig_str = '**';
elseif p_blk < 0.05,   sig_str = '*';
else,                  sig_str = 'ns';
end
text(ax_pvs_B, 0.05, 0.95, sig_str, ...
    'Units', 'normalized', 'FontSize', 8, 'FontWeight', 'bold', ...
    'Color', col_err, 'VerticalAlignment', 'top');

% --- Right: delta band power vs prediction error (same batches, same X axis) ---
col_dp = [0.75 0.45 0.0];   % gold — matches delta band highlight

hold(ax_pvs_C, 'on');
errorbar(ax_pvs_C, blockDev, blockDeltaPow, ...
    blockDeltaPow_sem, blockDeltaPow_sem, ...   % vertical ±SEM (delta power)
    blockDev_sem,      blockDev_sem, ...        % horizontal ±SEM (pred error)
    'o', 'Color', col_dp, 'MarkerFaceColor', col_dp, 'MarkerEdgeColor', 'none', ...
    'MarkerSize', 4, 'LineWidth', 0.8, 'CapSize', 3, 'HandleVisibility', 'off');
plot(ax_pvs_C, xFit_blk, yFit_dp, '-', 'Color', col_dp, 'LineWidth', 1.5, ...
    'HandleVisibility', 'off');
hold(ax_pvs_C, 'off');

xlabel(ax_pvs_C, 'Prediction error (\DeltaF/F %)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pvs_C, '\delta power  (\DeltaF/F)^2 Hz^{-1}', 'FontSize', 6, 'FontWeight', 'bold');
set(ax_pvs_C, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);

% Significance stars
if     p_dp < 0.001,  sig_dp = '***';
elseif p_dp < 0.01,   sig_dp = '**';
elseif p_dp < 0.05,   sig_dp = '*';
else,                 sig_dp = 'ns';
end
text(ax_pvs_C, 0.05, 0.95, sig_dp, ...
    'Units', 'normalized', 'FontSize', 8, 'FontWeight', 'bold', ...
    'Color', col_dp, 'VerticalAlignment', 'top');

% Link X axes of middle and right panels
linkaxes([ax_pvs_B, ax_pvs_C], 'x');

paperExport(fig_pvs, fullfile(paperRoot, 'images', 'figure2', 'prevar_heatmap_with_blockfit.pdf'));
