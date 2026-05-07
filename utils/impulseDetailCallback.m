function impulseDetailCallback(ax, sOrd, imp_e, iAmp, t_win)
% Opens a 3-panel detail figure for the clicked trial row in the freq heatmap.
%
%   ax    — axes that was clicked (used to read CurrentPoint)
%   sOrd  — trial sort order (ascending Peak_imp_dev), length = nUse
%   imp_e — imp struct for this experiment (fields: dfImp, motTrace, freqSpec, uAmp)
%   iAmp  — amplitude index into imp_e
%   t_win — time vector matching df_imp columns (e.g. -3:1/35:3)

clickPt = ax.CurrentPoint;
yClick  = round(clickPt(1, 2));
nUse    = numel(sOrd);
yClick  = max(1, min(nUse, yClick));
origIdx = sOrd(yClick);

df_all   = imp_e.dfImp{iAmp};          % nTrials × nTime
mot_all  = imp_e.motTrace{iAmp};       % nTrials × nTime
freq_all = imp_e.freqSpec{iAmp};       % nTrials × nBands
fbCtrs   = (0:19)*0.5 + 0.25;

df_trial   = df_all(origIdx, :);
df_mean    = mean(df_all,   1, 'omitnan');
df_sd      = std(df_all,  0, 1, 'omitnan');
mot_trial  = mot_all(origIdx, :);
freq_trial = freq_all(origIdx, :);
freq_mean  = mean(freq_all, 1, 'omitnan');

fig = figure('Color','w', 'Position', [250 150 560 500]);
tlo = tiledlayout(fig, 3, 1, 'TileSpacing','compact', 'Padding','compact');
title(tlo, sprintf('Amp = %.2f V  |  Trial %d  (dev rank %d / %d)', ...
    imp_e.uAmp{iAmp}, origIdx, yClick, nUse), ...
    'FontWeight','bold', 'FontSize', 10);

% ── Row 1: dF/F trace ──────────────────────────────────────────────────────
ax1 = nexttile(tlo);  hold(ax1, 'on');
fill(ax1, [t_win, fliplr(t_win)], ...
    [df_mean + df_sd, fliplr(df_mean - df_sd)], ...
    [0.7 0.7 0.7], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
plot(ax1, t_win, df_mean,  'k-',  'LineWidth', 2,   'DisplayName', 'Mean ± SD');
plot(ax1, t_win, df_trial, 'r-',  'LineWidth', 1.5, 'DisplayName', sprintf('Trial %d', origIdx));
xline(ax1, 0, '--k', 'Alpha', 0.35, 'HandleVisibility', 'off');
legend(ax1, 'Box', 'off', 'FontSize', 8, 'Location', 'best');
ylabel(ax1, 'dF/F (%)');
set(ax1, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9);

% ── Row 2: motion trace ────────────────────────────────────────────────────
ax2 = nexttile(tlo);  hold(ax2, 'on');
mot_mean_tr = mean(mot_all, 1, 'omitnan');
plot(ax2, t_win, mot_mean_tr, 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5);
plot(ax2, t_win, mot_trial,   'b-',  'LineWidth', 1.5);
xline(ax2, 0, '--k', 'Alpha', 0.35);
ylabel(ax2, 'Motion (z)');
set(ax2, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9);

% ── Row 3: relative band power ────────────────────────────────────────────
ax3 = nexttile(tlo);  hold(ax3, 'on');
bar(ax3, fbCtrs, freq_trial, 'FaceColor', [0.8 0.3 0.1], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.7, 'DisplayName', 'This trial');
plot(ax3, fbCtrs, freq_mean, 'k-', 'LineWidth', 2, 'DisplayName', 'Amp mean');
legend(ax3, 'Box', 'off', 'FontSize', 8, 'Location', 'best');
xlabel(ax3, 'Frequency (Hz)');
ylabel(ax3, 'Rel. power');
set(ax3, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9, 'XLim', [0 10]);
xticks(ax3, 0:2:10);
end
