function seedfc_panel()
%SEEDFC_PANEL  Site-cortex coupling panel for the SfN poster, sized for the space under the moving-target box.
%   Same data and colour scale as controller-analysis/ctrl_seed_fc_group.m (figures_final/panels/supp_seedfc):
%   12 sessions, one row OL, one row CL, map of r_base - r_stim, plus the per-session OL vs CL summary.
%   That panel is 17.6 cm wide, too wide for this box at the poster's one print scale, so the maps here
%   are 0.845 cm instead of 1.12 cm. Text stays 6 pt. Panels stay raw (user 2026-10-19: no laser removal, no GSR).
% OUT  poster/sfn2026/panels/seedfc_raw.pdf (git-ignored); patch_online_v2.py crops it to its ink.
%   Printed with print -vector on a 14 x 6 cm page, not exportgraphics, which rescales small panels.
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..', '..');
addpath(fullfile(root, 'utils'));
G = load(fullfile(root, 'controller-analysis', 'data', 'ctrl_seed_fc_group.mat'));
S = jnStyle(); cmD = brbg(256); cl = [-0.3 0.3]; nS = numel(G.sessions);
lab = paper_session_label(G.sessions, 'short'); [lab, ord] = sort(lab);
mlN = (G.node(:,2) - 1)/50 - 1; apN = (G.node(:,1) - 1)/100;
xl = max(G.lat_px) / G.pxmm * [-1 1]; yl = [0 max(G.L_px) / G.pxmm];

Wp = 14; Hp = 6; fig = jnFig(Wp, Hp);
y0 = 1.5; x00 = 0.6; W = 0.845; dx = 0.855; Hh = W * diff(yl) / diff(xl);
yB = [y0 + 0.22 + Hh + 0.04, y0 + 0.22]; top = yB(1) + Hh;
cn = {'OL', 'CL'};
for c = 1:2
    for j = 1:nS
        i = ord(j);
        ax = axes(fig, 'Units', 'centimeters', 'Position', [x00 + (j - 1) * dx, yB(c), W, Hh]); hold(ax, 'on');
        X = G.ml * G.lat_px(i) / G.pxmm; Y = G.ap * G.L_px(i) / G.pxmm;
        contourf(ax, X, Y, double(G.Mn{i}), [0.5 0.5], 'FaceColor', [0.92 0.92 0.92], 'LineColor', [0.45 0.45 0.45], ...
            'LineWidth', 0.3);
        v = -G.(cn{c}).dr(i, :).'; ok = ~isnan(v);                 % baseline - stim
        ci = round(1 + (min(max(v(ok), cl(1)), cl(2)) - cl(1)) / diff(cl) * 255);
        scatter(ax, mlN(ok) * G.lat_px(i) / G.pxmm, apN(ok) * G.L_px(i) / G.pxmm, 2.2, cmD(ci, :), 'filled', 'MarkerEdgeColor', 'none');
        plot(ax, G.site_n(i,2) * G.lat_px(i) / G.pxmm, G.site_n(i,1) * G.L_px(i) / G.pxmm, 'p', 'MarkerSize', 3, ...
            'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
        set(ax, 'YDir', 'reverse'); axis(ax, 'equal', 'off'); xlim(ax, xl); ylim(ax, yl);
    end
end

% colour scale
xcb = x00 + nS * dx + 0.06;
ax = axes(fig, 'Units', 'centimeters', 'Position', [xcb, yB(2), 0.1, top - yB(2)]);
imagesc(ax, [0 1], cl, (1:256).'); colormap(ax, cmD);
set(ax, 'YDir', 'normal', 'XTick', [], 'YTick', [-0.3 0 0.3], 'YTickLabel', {'-0.3', '0', '0.3'}, 'YAxisLocation', 'right', ...
    'TickDir', 'out', 'TickLength', [0.03 0.03], 'FontSize', S.fs_tick, 'LineWidth', S.lw_axis, 'Box', 'on');

% per-session baseline - stim, OL vs CL (locked colours OL red, CL blue; marker = mouse)
xs = 12.42; ys = y0 + 0.33; hs = top + 0.05 - ys - 0.25;
ax = axes(fig, 'Units', 'centimeters', 'Position', [xs, ys, 1.2, hs]); hold(ax, 'on');
cO = [0.85 0.2 0.15]; cC = [0.15 0.35 0.8]; yo = -G.OL.sess_dr(:); yc = -G.CL.sess_dr(:);
plot(ax, [1 2], [yo yc].', '-', 'Color', [0.7 0.7 0.7], 'LineWidth', S.lw_ind);
mk = {'o', 's'}; ms = [33 39];
for m = 1:2
    i = G.mouse(:) == ms(m);
    scatter(ax, ones(nnz(i), 1), yo(i), 5, cO, mk{m}, 'filled');
    scatter(ax, 2 * ones(nnz(i), 1), yc(i), 5, cC, mk{m}, 'filled');
end
errorbar(ax, [0.6 2.4], [mean(yo) mean(yc)], [std(yo) std(yc)] / sqrt(nS), 'k_', 'LineWidth', S.lw_err, 'CapSize', 0);
yline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', S.lw_ref);
set(ax, 'XTick', [1 2], 'XTickLabel', {'OL', 'CL'}, 'XLim', [0.4 2.6], 'YLim', [-0.1 0.4], 'YTick', [0 0.2 0.4], ...
    'FontSize', S.fs_tick, 'TickLength', [0.03 0.03]);
p = signrank(yc, yo);

% text and scale bar on one overlay in cm
ov = axes(fig, 'Units', 'centimeters', 'Position', [0 0 Wp Hp], 'XLim', [0 Wp], 'YLim', [0 Hp], 'Visible', 'off'); hold(ov, 'on');
for j = 1:nS
    text(ov, x00 + (j - 1) * dx + W / 2, top + 0.02, lab{j}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', S.fs_annot, 'FontWeight', 'bold');
end
for c = 1:2
    text(ov, x00 - 0.14, yB(c) + Hh / 2, cn{c}, 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontSize', S.fs_label, 'FontWeight', 'bold');
end
bar_cm = 2 * W / diff(xl);
plot(ov, x00 + [0 bar_cm], (y0 + 0.11) * [1 1], 'k', 'LineWidth', 1);
text(ov, x00 + bar_cm + 0.06, y0 + 0.11, '2 mm', 'VerticalAlignment', 'middle', 'FontSize', S.fs_tick);
text(ov, xcb + 0.56, (yB(2) + top) / 2, 'coupling lost', 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontSize', S.fs_tick);
text(ov, xs - 0.6, ys + hs / 2, 'r_{base} - r_{stim}', 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontSize', S.fs_tick, 'FontWeight', 'bold');
text(ov, xs + 0.6, ys + hs + 0.04, 'CL vs OL ***', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontSize', S.fs_annot, 'FontWeight', 'bold');

drawnow;
print(fig, fullfile(here, 'panels', 'seedfc_raw.pdf'), '-dpdf', '-vector');
close(fig);
fprintf('[SEEDFC] Hh %.3f cm, canvas top %.3f cm above y0\n', Hh, top - y0);
fprintf('[SEEDFC] CL r %.3f -> %.3f, OL r %.3f -> %.3f\n', mean(G.CL.sess_base), mean(G.CL.sess_stim), mean(G.OL.sess_base), mean(G.OL.sess_stim));
fprintf('[SEEDFC] r_base - r_stim: CL %+.3f (%d/%d > 0, p = %.4f), OL %+.3f (p = %.3f); CL vs OL paired p = %.4f, n = %d, mice %s\n', ...
    mean(yc), nnz(yc > 0), nS, signrank(yc), mean(yo), signrank(yo), p, nS, mat2str(unique(G.mouse)));
end

function cm = brbg(n)
% brown - white - teal diverging (ColorBrewer BrBG endpoints), as ctrl_seed_fc_group.m
x = linspace(-1, 1, n).'; b = [0.55 0.32 0.04]; t = [0.00 0.40 0.37]; w = [1 1 1];
cm = (x < 0) .* (w + (-x) .* (b - w)) + (x >= 0) .* (w + x .* (t - w));
end
