function plot_ratio_windows(ax, ST, xlab)
% PLOT_RATIO_WINDOWS  Fig 3H/3I layout: CL/OL ratio per window on a log y-axis (2026-10-15).
%   plot_ratio_windows(ax, ST, xlab)
% ST   : 1 x W struct array from utils/ratio_session_stats.m (one per window, plotted left->right)
% xlab : 1 x W cellstr of tick labels
% Sessions = grey points (deterministic jitter); black = geometric mean +/- 95% CI (t-based,
% session level); dashed line at 1 (no difference). Below 1 = closed loop better.
nW = numel(ST);
hold(ax, 'on');
yline(ax, 1, 'k--', 'LineWidth', 0.75, 'HandleVisibility', 'off');
for w = 1:nW
    r  = ST(w).r;  n = numel(r);
    jx = w - 0.22 + 0.12*((0:n-1)'/max(n-1,1) - 0.5);    % fixed spread, left of the mean
    [~, o] = sort(r);  jx(o) = jx;                        % spread ordered by value
    plot(ax, jx, r, 'o', 'MarkerSize', 2, 'Color', [0.6 0.6 0.6], ...
        'MarkerFaceColor', [0.6 0.6 0.6], 'LineStyle', 'none', 'HandleVisibility', 'off');
    plot(ax, [w w], ST(w).geoCI, 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot(ax, w, ST(w).geo, 'ko', 'MarkerSize', 3.5, 'MarkerFaceColor', 'k', ...
        'HandleVisibility', 'off');
end
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
