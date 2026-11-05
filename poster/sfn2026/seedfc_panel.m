function seedfc_panel()
%SEEDFC_PANEL  Site-cortex coupling panel for SfN poster box 5, which fills column 2 below the moving-target box.
%   Same data and colour scale as controller-analysis/ctrl_seed_fc_group.m (figures_final/panels/supp_seedfc):
%   12 sessions from 2 mice, raw coupling (user 2026-10-19: no laser removal, no GSR), value = r_base - r_stim
%   with base [-2,0) s and stim [+1,+3) s.
%   Top: every session's map, OL row and CL row, ordered by paper label.
%   Bottom: the mean of the 12 maps on the common node grid (session-mean brain size, consensus outline, every
%   session's site as a dot), r with the site at base and during stimulation per session, and the per-session
%   r_base - r_stim, OL vs CL.
%   2026-11-05: was one 13.4 x 2.07 cm strip; the Methods box was removed, so the box is 3 in taller and the
%   panel is width-limited, so the extra height goes to the bottom row. Text stays 6 pt.
% OUT  poster/sfn2026/panels/seedfc_raw.pdf (git-ignored); patch_v2_box5.py crops it to its ink.
%   Printed with print -vector on a fixed page, not exportgraphics, which rescales small panels.
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..', '..');
addpath(fullfile(root, 'utils'));
G = load(fullfile(root, 'controller-analysis', 'data', 'ctrl_seed_fc_group.mat'));
S = jnStyle(); cmD = brbg(256); cl = [-0.3 0.3]; nS = numel(G.sessions); cn = {'OL', 'CL'};
cc = {[0.85 0.2 0.15], [0.15 0.35 0.8]};                        % locked OL red, CL blue
lab = paper_session_label(G.sessions, 'short'); [lab, ord] = sort(lab);
mlN = (G.node(:,2) - 1)/50 - 1; apN = (G.node(:,1) - 1)/100;
xl = max(G.lat_px) / G.pxmm * [-1 1]; yl = [0 max(G.L_px) / G.pxmm];
dot = @(cm_per_mm) (0.75 * G.spacing_mm * cm_per_mm * 72 / 2.54)^2;   % marker area: dot = 3/4 of node spacing
col = @(v) cmD(round(1 + (min(max(v, cl(1)), cl(2)) - cl(1)) / diff(cl) * 255), :);
star = @(p) char(repmat('*', 1, (p < 0.05) + (p < 0.01) + (p < 0.001)));

Wp = 14; Hp = 7; fig = jnFig(Wp, Hp);
x00 = 0.55; W = 1.05; dx = 1.06; Hh = W * diff(yl) / diff(xl); R = x00 + (nS - 1) * dx + W;
yM = 0.8; Hm = 1.6;                                              % bottom row
yT = yM + Hm + 0.45; yB = [yT + 0.22 + Hh + 0.04, yT + 0.22]; top = yB(1) + Hh;   % top strip

% ---- top: every session
for c = 1:2
    for j = 1:nS
        i = ord(j);
        ax = axes(fig, 'Units', 'centimeters', 'Position', [x00 + (j - 1) * dx, yB(c), W, Hh]); hold(ax, 'on');
        contourf(ax, G.ml * G.lat_px(i) / G.pxmm, G.ap * G.L_px(i) / G.pxmm, double(G.Mn{i}), [0.5 0.5], ...
            'FaceColor', [0.92 0.92 0.92], 'LineColor', [0.45 0.45 0.45], 'LineWidth', 0.3);
        v = -G.(cn{c}).dr(i, :).'; ok = ~isnan(v);                 % baseline - stim
        scatter(ax, mlN(ok) * G.lat_px(i) / G.pxmm, apN(ok) * G.L_px(i) / G.pxmm, dot(W / diff(xl)), col(v(ok)), ...
            'filled', 'MarkerEdgeColor', 'none');
        plot(ax, G.site_n(i,2) * G.lat_px(i) / G.pxmm, G.site_n(i,1) * G.L_px(i) / G.pxmm, 'p', 'MarkerSize', 3.5, ...
            'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
        set(ax, 'YDir', 'reverse'); axis(ax, 'equal', 'off'); xlim(ax, xl); ylim(ax, yl);
    end
end

% ---- bottom left: mean of the 12 maps, common node grid
Lx = G.Lml / G.pxmm; Ly = G.Lap / G.pxmm; Wm = Hm * 2 * Lx / Ly; xm = [x00, x00 + Wm + 0.15];
for c = 1:2
    ax = axes(fig, 'Units', 'centimeters', 'Position', [xm(c), yM, Wm, Hm]); hold(ax, 'on');
    contourf(ax, G.ml * Lx, G.ap * Ly, double(G.cons), [0.5 0.5], 'FaceColor', [0.92 0.92 0.92], ...
        'LineColor', [0.45 0.45 0.45], 'LineWidth', 0.4);
    v = -mean(G.(cn{c}).dr, 1, 'omitnan').';
    scatter(ax, mlN * Lx, apN * Ly, dot(Wm / (2 * Lx)), col(v), 'filled', 'MarkerEdgeColor', 'none');
    plot(ax, G.site_n(:,2) * Lx, G.site_n(:,1) * Ly, 'o', 'MarkerSize', 1.6, 'MarkerFaceColor', 'k', ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.25);
    set(ax, 'YDir', 'reverse'); axis(ax, 'equal', 'off'); xlim(ax, Lx * [-1 1]); ylim(ax, [0 Ly]);
    fprintf('[SEEDFC] %s mean map: %.3f..%.3f\n', cn{c}, min(v), max(v));
end
xcb = xm(2) + Wm + 0.12;
ax = axes(fig, 'Units', 'centimeters', 'Position', [xcb, yM + 0.1, 0.1, Hm - 0.2]);
imagesc(ax, [0 1], cl, (1:256).'); colormap(ax, cmD);
set(ax, 'YDir', 'normal', 'XTick', [], 'YTick', [-0.3 0 0.3], 'YTickLabel', {'-0.3', '0', '0.3'}, 'YAxisLocation', 'right', ...
    'TickDir', 'out', 'TickLength', [0.03 0.03], 'FontSize', S.fs_tick, 'LineWidth', S.lw_axis, 'Box', 'on');

% ---- bottom right: two per-session summaries, spread over the rest of the row
lab_w = 0.8; wa = 3.1; ws = 1.9;                                 % y-label room, axes widths
x_free = R - (xcb + 0.9) - (lab_w + wa) - (lab_w + ws);
xa = xcb + 0.9 + x_free / 2 + lab_w; xs = xa + wa + x_free / 2 + lab_w;
ya = yM + 0.3; ha = Hm - 0.3;
ax = axes(fig, 'Units', 'centimeters', 'Position', [xa, ya, wa, ha]); hold(ax, 'on');
pc = zeros(1, 2);
for c = 1:2
    b = G.(cn{c}).sess_base(:); s = G.(cn{c}).sess_stim(:); pc(c) = signrank(b, s);
    plot(ax, [1 2], [b s].', '-', 'Color', cc{c} + (1 - cc{c}) * 0.6, 'LineWidth', S.lw_ind);
end
for c = 1:2
    b = G.(cn{c}).sess_base(:); s = G.(cn{c}).sess_stim(:);
    errorbar(ax, [1 2], [mean(b) mean(s)], [std(b) std(s)] / sqrt(nS), '-', 'Color', cc{c}, 'LineWidth', 1.2, 'CapSize', 0);
end
set(ax, 'XTick', [1 2], 'XTickLabel', {'base', 'stim'}, 'XLim', [0.8 2.75], 'YLim', [0.25 0.9], 'YTick', [0.3 0.6 0.9], ...
    'FontSize', S.fs_tick, 'TickLength', [0.03 0.03]);

ax = axes(fig, 'Units', 'centimeters', 'Position', [xs, ya, ws, ha]); hold(ax, 'on');
yo = -G.OL.sess_dr(:); yc = -G.CL.sess_dr(:);
plot(ax, [1 2], [yo yc].', '-', 'Color', [0.7 0.7 0.7], 'LineWidth', S.lw_ind);
mk = {'o', 's'}; ms = [33 39];
for m = 1:2
    i = G.mouse(:) == ms(m);
    scatter(ax, ones(nnz(i), 1), yo(i), 6, cc{1}, mk{m}, 'filled');
    scatter(ax, 2 * ones(nnz(i), 1), yc(i), 6, cc{2}, mk{m}, 'filled');
end
errorbar(ax, [0.6 2.4], [mean(yo) mean(yc)], [std(yo) std(yc)] / sqrt(nS), 'k_', 'LineWidth', S.lw_err, 'CapSize', 0);
yline(ax, 0, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', S.lw_ref);
set(ax, 'XTick', [1 2], 'XTickLabel', {'OL', 'CL'}, 'XLim', [0.4 2.6], 'YLim', [-0.1 0.4], 'YTick', [0 0.2 0.4], ...
    'FontSize', S.fs_tick, 'TickLength', [0.03 0.03]);
p = signrank(yc, yo);

% ---- text and scale bars on one overlay in cm
ov = axes(fig, 'Units', 'centimeters', 'Position', [0 0 Wp Hp], 'XLim', [0 Wp], 'YLim', [0 Hp], 'Visible', 'off'); hold(ov, 'on');
B = {'FontSize', S.fs_annot, 'FontWeight', 'bold'};
for j = 1:nS
    text(ov, x00 + (j - 1) * dx + W / 2, top + 0.02, lab{j}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', B{:});
end
for c = 1:2
    text(ov, x00 - 0.14, yB(c) + Hh / 2, cn{c}, 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontSize', S.fs_label, 'FontWeight', 'bold');
    text(ov, xm(c) + Wm / 2, yM + Hm + 0.03, sprintf('%s, mean of %d', cn{c}, nS), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', B{:});
end
bar1 = 2 * W / diff(xl); bar2 = 2 * Wm / (2 * Lx);
plot(ov, x00 + [0 bar1], (yT + 0.11) * [1 1], 'k', 'LineWidth', 1);
text(ov, x00 + bar1 + 0.06, yT + 0.11, '2 mm', 'VerticalAlignment', 'middle', 'FontSize', S.fs_tick);
plot(ov, x00 + [0 bar2], (yM - 0.14) * [1 1], 'k', 'LineWidth', 1);
text(ov, x00 + bar2 + 0.06, yM - 0.14, '2 mm', 'VerticalAlignment', 'middle', 'FontSize', S.fs_tick);
text(ov, xcb + 0.74, yM + Hm / 2, 'coupling lost', 'Rotation', 90, 'HorizontalAlignment', 'center', 'FontSize', S.fs_tick);
text(ov, xa - 0.62, ya + ha / 2, 'r with site', 'Rotation', 90, 'HorizontalAlignment', 'center', B{:});
text(ov, xs - 0.62, ya + ha / 2, 'r_{base} - r_{stim}', 'Rotation', 90, 'HorizontalAlignment', 'center', B{:});
text(ov, xs + ws / 2, ya + ha + 0.04, ['CL vs OL ' star(p)], 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', B{:});
ux = @(x) xa + (x - 0.8) / (2.75 - 0.8) * wa; uy = @(y) ya + (y - 0.25) / (0.9 - 0.25) * ha;
for c = 1:2
    s = mean(G.(cn{c}).sess_stim); t = star(pc(c)); if isempty(t), t = 'n.s.'; end
    text(ov, ux(2.1), uy(s), sprintf('%s %s', cn{c}, t), 'Color', cc{c}, 'VerticalAlignment', 'middle', B{:});
end

drawnow;
print(fig, fullfile(here, 'panels', 'seedfc_raw.pdf'), '-dpdf', '-vector');
close(fig);
fprintf('[SEEDFC] maps %.3f x %.3f cm, mean maps %.3f x %.3f cm, plots at x %.2f and %.2f, right edge %.2f cm\n', W, Hh, Wm, Hm, xa, xs, R);
fprintf('[SEEDFC] CL r %.3f -> %.3f (p = %.4f), OL r %.3f -> %.3f (p = %.4f)\n', mean(G.CL.sess_base), mean(G.CL.sess_stim), pc(2), ...
    mean(G.OL.sess_base), mean(G.OL.sess_stim), pc(1));
fprintf('[SEEDFC] r_base - r_stim: CL %+.3f (%d/%d > 0), OL %+.3f; CL vs OL paired p = %.4f, n = %d, mice %s\n', ...
    mean(yc), nnz(yc > 0), nS, mean(yo), p, nS, mat2str(unique(G.mouse)));
end

function cm = brbg(n)
% brown - white - teal diverging (ColorBrewer BrBG endpoints), as ctrl_seed_fc_group.m
x = linspace(-1, 1, n).'; b = [0.55 0.32 0.04]; t = [0.00 0.40 0.37]; w = [1 1 1];
cm = (x < 0) .* (w + (-x) .* (b - w)) + (x >= 0) .* (w + x .* (t - w));
end
