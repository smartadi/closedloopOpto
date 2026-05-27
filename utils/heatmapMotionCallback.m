function heatmapMotionCallback(ax, sortIdx, ampIdx_pool, trialIdx_pool, imp_e, t_win_full)
% Click handler for motion-sorted residual heatmap.
% Maps clicked Y row → original trial → opens 2-panel detail figure.
%
%   ax            — imagesc axes (CurrentPoint gives clicked coords)
%   sortIdx       — nT×1, maps rank (row index) → pooled trial index
%   ampIdx_pool   — nT×1, maps pooled index → amplitude group
%   trialIdx_pool — nT×1, maps pooled index → row in dfImp{iAmp}
%   imp_e         — imp struct (fields: dfImp, motTrace, uAmp)
%   t_win_full    — full time vector matching dfImp columns

clickPt = ax.CurrentPoint;
yC      = max(1, min(numel(sortIdx), round(clickPt(1, 2))));
pIdx    = sortIdx(yC);
iAmp    = ampIdx_pool(pIdx);
origIdx = trialIdx_pool(pIdx);

df_all  = imp_e.dfImp{iAmp};
mot_all = imp_e.motTrace{iAmp};
if origIdx > size(df_all, 1), return; end

df_trial  = df_all(origIdx, :);
df_mean   = mean(df_all,  1, 'omitnan');
df_sd     = std(df_all,   0, 1, 'omitnan');
mot_trial = mot_all(origIdx, :);
mot_mean  = mean(mot_all, 1, 'omitnan');

hold(ax, 'on');
yline(ax, yC, 'g-', 'LineWidth', 1.5, 'HandleVisibility', 'off');

fig = figure('Color', 'w', 'Position', [300 150 520 420]);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tlo, sprintf('Amp = %.2f V  |  Trial %d  |  rank = %d', ...
    imp_e.uAmp{iAmp}, origIdx, yC), 'FontWeight', 'bold', 'FontSize', 10);

ax1 = nexttile(tlo);  hold(ax1, 'on');
fill(ax1, [t_win_full, fliplr(t_win_full)], ...
    [df_mean + df_sd, fliplr(df_mean - df_sd)], ...
    [0.7 0.7 0.7], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
plot(ax1, t_win_full, df_mean,  'k-', 'LineWidth', 2,   'DisplayName', 'Mean \pm SD');
plot(ax1, t_win_full, df_trial, 'r-', 'LineWidth', 1.5, 'DisplayName', sprintf('Trial %d', origIdx));
xline(ax1, 0, '--k', 'Alpha', 0.35, 'HandleVisibility', 'off');
legend(ax1, 'Box', 'off', 'FontSize', 8, 'Location', 'best');
ylabel(ax1, 'dF/F (%)');
set(ax1, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9);

ax2 = nexttile(tlo);  hold(ax2, 'on');
plot(ax2, t_win_full, mot_mean,  'Color', [0.6 0.6 0.6], 'LineWidth', 1.5, 'DisplayName', 'Mean');
plot(ax2, t_win_full, mot_trial, 'b-', 'LineWidth', 1.5, 'DisplayName', sprintf('Trial %d', origIdx));
xline(ax2, 0, '--k', 'Alpha', 0.35, 'HandleVisibility', 'off');
legend(ax2, 'Box', 'off', 'FontSize', 8, 'Location', 'best');
xlabel(ax2, 'Time (s)');
ylabel(ax2, 'Motion (z)');
set(ax2, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9);
end
