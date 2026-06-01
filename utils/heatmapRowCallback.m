function heatmapRowCallback(~, ax, d)
% heatmapRowCallback  Click callback for the pre-trial variance heatmap.
%
% Called when user clicks a row in either panel of the
% "Freq heatmap sorted by pre-trial variance" section of
% Impulse_mouseDataAnalysis_all.m.
%
% Usage (wired in main script):
%   set(hImg, 'ButtonDownFcn', @(~, ev) heatmapRowCallback(ev, ax, d));
%
% Inputs:
%   ~    - event data (unused; click coords read from ax.CurrentPoint)
%   ax   - axes that received the click
%   d    - struct with pooled sorted data (built in main script):
%            .trace    nT x nTime  dF/F traces (sorted by pre-stim var)
%            .dev      nT x 1      absolute peak deviation
%            .pvar     nT x 1      pre-trial variance
%            .ampV     nT x 1      amplitude in Volts
%            .freq     nT x nBands frequency spectrum
%            .fbCtrs   1 x nBands  band centre frequencies (Hz)
%            .twin     1 x nTime   time vector (s)
%            .nT       scalar      total trials
%            .vToMW    scalar      V -> mW conversion factor
%            .meanTr   1 x nTime   mean trace across all kept trials
%            .sdTr     1 x nTime   SD of traces
%            .meanFreq 1 x nBands  mean frequency spectrum

% Identify clicked row from axes current point (Y = trial rank, 1-based)
pt      = ax.CurrentPoint;
row_raw = pt(1, 2);
row_idx = max(1, min(d.nT, round(row_raw)));

% Highlight clicked row with a white horizontal line in the source axes
delete(findobj(ax, 'Tag', 'pvh_highlight'));
xl = xlim(ax);
hold(ax, 'on');
plot(ax, xl, [row_idx row_idx], 'w-', 'LineWidth', 1.5, 'Tag', 'pvh_highlight');
hold(ax, 'off');

% Open detail figure
amp_mw = d.ampV(row_idx) * d.vToMW;
fig_d  = figure('Name', sprintf('Trial rank %d / %d  |  %.3f mW', ...
                row_idx, d.nT, amp_mw), ...
                'Color', 'w', 'NumberTitle', 'off');
fig_d.Units    = 'centimeters';
fig_d.Position = [5 5 14 10];

tl_d = tiledlayout(fig_d, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% --- Panel 1: dF/F trace ---
ax1   = nexttile(tl_d);
t_ax  = d.twin;
upper = d.meanTr + d.sdTr;
lower = d.meanTr - d.sdTr;
fill(ax1, [t_ax, fliplr(t_ax)], [upper, fliplr(lower)], ...
    [0.75 0.75 0.75], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
hold(ax1, 'on');
plot(ax1, t_ax, d.meanTr, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
plot(ax1, t_ax, d.trace(row_idx, :), 'r-', 'LineWidth', 1.4);
xline(ax1, 0, 'k--', 'LineWidth', 0.6);
hold(ax1, 'off');
set(ax1, 'Box', 'off', 'TickDir', 'out', 'FontSize', 7);
xlabel(ax1, 'Time re stim onset (s)', 'FontSize', 7);
ylabel(ax1, '\DeltaF/F (%)', 'FontSize', 7);
title(ax1, sprintf('Rank %d/%d  amp=%.3f mW  (red) vs mean+/-SD (grey)', ...
    row_idx, d.nT, amp_mw), 'FontSize', 7);

% --- Panel 2: pre-stim frequency spectrum ---
ax2    = nexttile(tl_d);
ymin_f = max(min([d.freq(row_idx,:), d.meanFreq]) * 0.5, 1e-6);
ymax_f = max([d.freq(row_idx,:), d.meanFreq]) * 2.0;
if ymax_f <= ymin_f, ymax_f = ymin_f * 10; end
fill(ax2, [1 4 4 1], [ymin_f ymin_f ymax_f ymax_f], ...
    [1 0.85 0.1], 'FaceAlpha', 0.15, 'EdgeColor', 'none');
hold(ax2, 'on');
plot(ax2, d.fbCtrs, d.meanFreq, '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.0);
plot(ax2, d.fbCtrs, d.freq(row_idx, :), 'r-', 'LineWidth', 1.4);
hold(ax2, 'off');
set(ax2, 'YScale', 'log', 'YLim', [ymin_f, ymax_f]);
set(ax2, 'Box', 'off', 'TickDir', 'out', 'FontSize', 7);
xticks(ax2, 0:2:10);
xlabel(ax2, 'Frequency (Hz)', 'FontSize', 7);
ylabel(ax2, 'Power (\DeltaF/F)^2 Hz^{-1}  (log)', 'FontSize', 7);
title(ax2, 'Pre-stim spectrum: this trial (red) vs mean (grey). \delta band (1-4 Hz) shaded.', 'FontSize', 7);

% --- Panel 3: metadata text ---
ax3 = nexttile(tl_d);
axis(ax3, 'off');
dev_rank = sum(d.dev <= d.dev(row_idx));
band14   = d.fbCtrs >= 1 & d.fbCtrs <= 4;
pwr14    = mean(d.freq(row_idx, band14), 'omitnan');
pwr14_mn = mean(d.meanFreq(band14), 'omitnan');
info_str = sprintf([ ...
    'Trial rank (sorted by pre-stim var) : %d / %d\n' ...
    'Pre-stim variance                   : %.5f (dF/F)^2\n' ...
    'Amplitude                           : %.4f V = %.3f mW\n' ...
    'Abs peak deviation                  : %.4f dF/F%%\n' ...
    'Deviation rank (low=1)              : %d / %d\n' ...
    '1-4 Hz power this trial             : %.5f   (mean: %.5f)'], ...
    row_idx, d.nT, ...
    d.pvar(row_idx), ...
    d.ampV(row_idx), amp_mw, ...
    d.dev(row_idx), ...
    dev_rank, d.nT, ...
    pwr14, pwr14_mn);
text(ax3, 0.03, 0.85, info_str, 'Units', 'normalized', ...
    'FontSize', 8, 'VerticalAlignment', 'top', ...
    'FontName', 'Courier New', 'Interpreter', 'none');

end
