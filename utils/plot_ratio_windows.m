function plot_ratio_windows(ax, ST, xlab)
% PLOT_RATIO_WINDOWS  Fig 3H/3I layout: CL/OL ratio per window on a log y-axis (2026-10-15).
%   plot_ratio_windows(ax, ST, xlab)
% ST   : 1 x W struct array from utils/ratio_session_stats.m (one per window, plotted left->right)
% xlab : 1 x W cellstr of tick labels
% Sessions = grey traces across windows (same column per window, as the pre-2026-10-15 panels);
% black = geometric mean +/- 95% CI (t-based, session level); dashed line at 1. Below 1 = CL better.
nW = numel(ST);
R  = [ST.r];                                              % nSess x nW, same session order
G  = [ST.geo];  C = vertcat(ST.geoCI);                    % nW x 2
hold(ax, 'on');
yline(ax, 1, 'k--', 'LineWidth', 0.75, 'HandleVisibility', 'off');
for s = 1:size(R, 1)                                      % one grey trace per session
    plot(ax, 1:nW, R(s, :), '-o', 'Color', [0.6 0.6 0.6], 'MarkerSize', 2, ...
        'MarkerFaceColor', [0.6 0.6 0.6], 'LineWidth', 0.6, 'HandleVisibility', 'off');
end
for w = 1:nW                                              % 95% CI on the geometric mean
    plot(ax, [w w], C(w, :), 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
end
plot(ax, 1:nW, G, 'k-o', 'LineWidth', 1.5, 'MarkerSize', 3.5, 'MarkerFaceColor', 'k', ...
    'HandleVisibility', 'off');
hold(ax, 'off');
set(ax, 'YScale', 'log');
allr = vertcat(ST.r);  allc = vertcat(ST.geoCI);
lo = min([allr; allc(:)]);  hi = max([allr; allc(:)]);
ylim(ax, [lo/1.15, hi*1.35]);                             % headroom for the Stim label
cand = [0.125 0.25 0.5 1 2 4];
yt = cand(cand >= lo/1.15 & cand <= hi*1.35);
if ~ismember(1, yt), yt = sort([yt 1]); end
ax.YTick = yt;
ax.YTickLabel = arrayfun(@(v) strip(sprintf('%g', v)), yt, 'UniformOutput', false);
ax.YMinorTick = 'off';
xlim(ax, [0.5 nW+0.5]);
ax.XTick = 1:nW;  ax.XTickLabel = xlab;
xtickangle(ax, 0);
end
