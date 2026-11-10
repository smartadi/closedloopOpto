function unique_panel()
%UNIQUE_PANEL  Poster copy of Fig 4C (unique R^2 by window) with a broken y-axis, for SfN poster box 6.
%   Aditya 2026-11-05: the initial-deviation bar (0-1 s, 0.53) takes up most of the panel, so the other
%   variables barely show. Lower segment 0-0.2 gets most of the height, a short upper segment 0.45-0.6 holds
%   the tall bar; the two segments have different scales, marked by break slashes on the y-axis.
%   Same numbers, colours and error bars as f4_error_decomp.m 'sep' mode (session mean +- SEM, 11 sessions):
%   read from controller-analysis/data/f4_error_decomp.mat (DEC.sep), nothing is refit.
%   The paper panel (figures_final/panels/figure4/f4_decomp_unique_sep.pdf) is not touched.
%   2026-11-10: poster type standard (as box 5 and poster_restyle.m): ticks 7 pt, labels 7.5, title 8
%   (about 21 / 22 / 24 pt on the poster, was 18 with a 13 pt superscript); variable names on two lines
%   instead of slanted.
% OUT  poster/sfn2026/panels/poster/st_unique_raw.pdf (git-ignored); panel_swap.py crops it to its ink.
%   Printed with print -vector on a fixed page, not exportgraphics, which rescales small panels.
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..', '..');
addpath(fullfile(root, 'utils'));
L = load(fullfile(root, 'controller-analysis', 'data', 'f4_error_decomp.mat'));
D = L.DEC.sep; U = D.Us(:, :, D.okS); nS = D.nSok;
P = mean(U, 3); E = std(U, 0, 3) / sqrt(nS);
FC = [0.20 0.40 0.75; 0.75 0.40 0.10; 0.35 0.55 0.30; 0.55 0.25 0.60];   % f4_error_decomp FCfac
lightC = 1 - 0.55 * (1 - FC); darkC = 0.70 * FC;                         % 0-1 s light, 1-3 s dark
lbl = {'init-dev', 'motion', 'rel 2–4 Hz', 'abs 1–4 Hz'};
S = jnStyle(); FT = 7; FA = 7.5; FL = 8;
lbl2 = {{'init-dev'}, {'motion'}, {'rel', '2–4 Hz'}, {'abs', '1–4 Hz'}};   % drawn as text: MATLAB staggers two-line tick labels

Wp = 7; Hp = 4.5; fig = jnFig(Wp, Hp);
x0 = 1.25; w = 4.1; y0 = 0.95; h1 = 1.45; gap = 0.12; h2 = 0.5;
lo = [-0.01 0.2]; hi = [0.45 0.65];   % 2026-11-10: init-dev 0.562 + SEM 0.050 reaches 0.61
ax1 = axes(fig, 'Units', 'centimeters', 'Position', [x0, y0, w, h1]);
ax2 = axes(fig, 'Units', 'centimeters', 'Position', [x0, y0 + h1 + gap, w, h2]);
for ax = [ax1 ax2]
    hold(ax, 'on');
    hb = bar(ax, P, 'grouped', 'EdgeColor', 'none', 'BarWidth', 0.8);
    hb(1).FaceColor = 'flat'; hb(1).CData = lightC;
    hb(2).FaceColor = 'flat'; hb(2).CData = darkC; set(hb, 'ShowBaseLine', 'off');
    for k = 1:2
        errorbar(ax, hb(k).XEndPoints, P(:, k).', E(:, k).', 'LineStyle', 'none', 'Color', [.25 .25 .25], ...
            'LineWidth', 0.6, 'CapSize', 2);
    end
    set(ax, 'XLim', [0.5 4.5], 'Box', 'off', 'TickDir', 'out', 'FontSize', FT, 'LineWidth', S.lw_axis, ...
        'TickLength', [0.02 0.02], 'Layer', 'top', 'TickLabelInterpreter', 'tex');
end
yline(ax1, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', 0.5);
set(ax1, 'YLim', lo, 'YTick', [0 0.1 0.2], 'XTick', 1:4, 'XTickLabel', {});
set(ax2, 'YLim', hi, 'YTick', [0.5 0.6], 'XTick', [], 'XColor', 'none'); ax2.XAxis.Visible = 'off';

% window key, as the paper panel: grey swatches, because colour already encodes the variable
ov = axes(fig, 'Units', 'centimeters', 'Position', [0 0 Wp Hp], 'XLim', [0 Wp], 'YLim', [0 Hp], 'Visible', 'off'); hold(ov, 'on');
kx = x0 + w - 1.05; ky = y0 + h1 + gap + h2 - 0.08;
wl = {'0-1 s', '1-3 s'}; gc = {[.72 .72 .72], [.35 .35 .35]};
for k = 1:2
    yk = ky - (k - 1) * 0.3;
    patch(ov, kx + [0 0.2 0.2 0], yk + [-0.08 -0.08 0.08 0.08], gc{k}, 'EdgeColor', 'none');
    text(ov, kx + 0.28, yk, wl{k}, 'VerticalAlignment', 'middle', 'FontSize', FT);
end
% break slashes on the y-axis, one at the top of the lower segment and one at the bottom of the upper
for yb = [y0 + h1, y0 + h1 + gap]
    plot(ov, x0 + [-0.07 0.07], yb + [-0.04 0.04], 'k', 'LineWidth', S.lw_axis);
end
for k = 1:4
    text(ov, x0 + (k - 0.5) / 4 * w, y0 - 0.1, lbl2{k}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'FontSize', FT);
end
text(ov, x0 - 0.78, y0 + (h1 + gap + h2) / 2, 'unique R^2', 'Rotation', 90, 'HorizontalAlignment', 'center', ...
    'FontSize', FA, 'FontWeight', 'bold');
text(ov, x0 + w / 2, y0 + h1 + gap + h2 + 0.1, sprintf('Unique R^2 (%d sessions)', nS), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', 'FontSize', FL, 'FontWeight', 'bold');

drawnow;
print(fig, fullfile(here, 'panels', 'poster', 'st_unique_raw.pdf'), '-dpdf', '-vector');
close(fig);
for j = 1:4
    fprintf('[UNIQUE] %-11s 0-1 s %.3f +- %.3f   1-3 s %.3f +- %.3f\n', lbl{j}, P(j,1), E(j,1), P(j,2), E(j,2));
end
end
