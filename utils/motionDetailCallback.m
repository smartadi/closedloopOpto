function motionDetailCallback(ax, mot_i, dev_i, imp_e, iAmp, t_win)
% Opens a 2-panel detail figure for the trial nearest to the clicked dot.
%
%   ax    — scatter axes (used to read CurrentPoint)
%   mot_i — motion energy per trial (n × 1), x-axis values
%   dev_i — Peak_imp_dev per trial (n × 1), y-axis values
%   imp_e — imp struct for this experiment (fields: dfImp, motTrace, uAmp)
%   iAmp  — amplitude index into imp_e
%   t_win — time vector matching dfImp columns (e.g. -3:1/35:3)

clickPt = ax.CurrentPoint;
xC = clickPt(1,1);
yC = clickPt(1,2);

% find nearest trial in normalised coordinates
xR = range(mot_i);  if xR == 0, xR = 1; end
yR = range(dev_i);  if yR == 0, yR = 1; end
d2 = ((mot_i - xC) / xR).^2 + ((dev_i - yC) / yR).^2;
[~, origIdx] = min(d2);

df_all  = imp_e.dfImp{iAmp};      % nTrials × nTime
mot_all = imp_e.motTrace{iAmp};   % nTrials × nTime
if origIdx > size(df_all, 1), return; end

df_trial  = df_all(origIdx, :);
df_mean   = mean(df_all,  1, 'omitnan');
df_sd     = std(df_all,   0, 1, 'omitnan');
mot_trial = mot_all(origIdx, :);
mot_mean  = mean(mot_all, 1, 'omitnan');

% highlight selected dot on the scatter
hold(ax, 'on');
plot(ax, mot_i(origIdx), dev_i(origIdx), 'o', ...
    'MarkerSize', 10, 'MarkerEdgeColor', [0.85 0.2 0.1], ...
    'MarkerFaceColor', 'none', 'LineWidth', 2, 'HandleVisibility', 'off');

fig = figure('Color','w', 'Position', [300 150 520 420]);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing','compact', 'Padding','compact');
title(tlo, sprintf('Amp = %.2f V  |  Trial %d  |  mot=%.2f  dev=%.3f', ...
    imp_e.uAmp{iAmp}, origIdx, mot_i(origIdx), dev_i(origIdx)), ...
    'FontWeight','bold', 'FontSize', 10);

% ── Row 1: dF/F trace ────────────────────────────────────────────────────────
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

% ── Row 2: motion trace ──────────────────────────────────────────────────────
ax2 = nexttile(tlo);  hold(ax2, 'on');
plot(ax2, t_win, mot_mean,  'Color', [0.6 0.6 0.6], 'LineWidth', 1.5, 'DisplayName', 'Mean');
plot(ax2, t_win, mot_trial, 'b-', 'LineWidth', 1.5, 'DisplayName', sprintf('Trial %d', origIdx));
xline(ax2, 0, '--k', 'Alpha', 0.35, 'HandleVisibility', 'off');
legend(ax2, 'Box', 'off', 'FontSize', 8, 'Location', 'best');
xlabel(ax2, 'Time (s)');
ylabel(ax2, 'Motion (z)');
set(ax2, 'Box', 'off', 'TickDir', 'out', 'FontSize', 9);
end
