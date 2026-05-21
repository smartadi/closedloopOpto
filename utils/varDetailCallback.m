function varDetailCallback(ax, preVar, dev, df_clean, mot_clean, t_win, ampVal)
% Opens a 2-panel detail figure for the trial nearest to the clicked dot
% in the pre-trial variance scatter (motion-excluded section).
%
%   ax        — scatter axes (used to read CurrentPoint + highlight dot)
%   preVar    — pre-trial variance per kept trial (n × 1), x-axis values
%   dev       — |Peak_imp dev| per kept trial (n × 1), y-axis values
%   df_clean  — dF/F traces for kept trials (n × nTime)
%   mot_clean — z-scored motion traces for kept trials (n × nTime)
%   t_win     — time vector matching df_clean columns (e.g. -3:1/35:3)
%   ampVal    — stimulus amplitude value (scalar, for title)

clickPt = ax.CurrentPoint;
xC = clickPt(1,1);
yC = clickPt(1,2);

% nearest trial in normalised coordinates
xR = range(preVar);  if xR == 0, xR = 1; end
yR = range(dev);     if yR == 0, yR = 1; end
d2 = ((preVar - xC) / xR).^2 + ((dev - yC) / yR).^2;
[~, idx] = min(d2);

if idx > size(df_clean, 1), return; end

df_trial  = df_clean(idx, :);
df_mean   = mean(df_clean,  1, 'omitnan');
df_sd     = std(df_clean,   0, 1, 'omitnan');
mot_trial = mot_clean(idx, :);
mot_mean  = mean(mot_clean, 1, 'omitnan');

% highlight selected dot
hold(ax, 'on');
plot(ax, preVar(idx), dev(idx), 'o', ...
    'MarkerSize', 10, 'MarkerEdgeColor', [0.85 0.2 0.1], ...
    'MarkerFaceColor', 'none', 'LineWidth', 2, 'HandleVisibility', 'off');

fig = figure('Color','w', 'Position', [300 150 520 420]);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');
title(tlo, sprintf('Amp = %.2f V  |  Trial %d  |  preVar=%.4f  dev=%.3f', ...
    ampVal, idx, preVar(idx), dev(idx)), ...
    'FontWeight','bold', 'FontSize', 10);

% Row 1: dF/F trace
ax1 = nexttile(tlo);  hold(ax1, 'on');
fill(ax1, [t_win, fliplr(t_win)], ...
    [df_mean + df_sd, fliplr(df_mean - df_sd)], ...
    [0.7 0.7 0.7], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
plot(ax1, t_win, df_mean,  'k-',  'LineWidth', 2,   'DisplayName', 'Mean ± SD');
plot(ax1, t_win, df_trial, 'r-',  'LineWidth', 1.5, 'DisplayName', sprintf('Trial %d', idx));
xline(ax1, 0, '--k', 'Alpha', 0.35, 'HandleVisibility', 'off');
legend(ax1, 'Box', 'off', 'FontSize', 8, 'Location', 'best');
ylabel(ax1, 'dF/F (%)');
set(ax1, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9);

% Row 2: motion trace
ax2 = nexttile(tlo);  hold(ax2, 'on');
plot(ax2, t_win, mot_mean,  'Color', [0.6 0.6 0.6], 'LineWidth', 1.5, 'DisplayName', 'Mean');
plot(ax2, t_win, mot_trial, 'b-',   'LineWidth', 1.5, 'DisplayName', sprintf('Trial %d', idx));
xline(ax2, 0, '--k', 'Alpha', 0.35, 'HandleVisibility', 'off');
legend(ax2, 'Box', 'off', 'FontSize', 8, 'Location', 'best');
xlabel(ax2, 'Time (s)');
ylabel(ax2, 'Motion (z)');
set(ax2, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9);
end
