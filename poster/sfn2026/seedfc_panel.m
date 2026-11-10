function seedfc_panel()
%SEEDFC_PANEL  Site-cortex correlation panel for SfN poster box 5, which fills column 2 below the moving-target box.
%   Same data as controller-analysis/ctrl_seed_fc_group.m (figures_final/panels/supp_seedfc): 12 sessions from
%   2 mice, raw correlation (user 2026-10-19: no laser removal, no GSR), before = [-2,0) s, during = [+1,+3) s.
%   Shown value = r_during - r_before (G.dr), so a drop is negative; the colour map is the supp panel's BrBG
%   flipped, so a drop is still teal. (The supp panel plots r_base - r_stim, "coupling lost".)
%   Top: every session's map, OL row and CL row, ordered by paper label, with a one-line key.
%   Bottom: the mean of the 12 maps on the common node grid (session-mean brain size, consensus outline; no site
%   markers, Aditya 2026-11-05: 12 stars there were confusing), r with the site before and during stimulation
%   per session, and the per-session change, OL vs CL.
%   2026-11-05: taller layout after the Methods box was removed; then relabelled for poster viewers (Aditya:
%   "coupling lost" is unintuitive): sign flipped, colour bar ends in words, key line, before/during.
%   2026-11-06 (Nick: some text in panel 5 is a bit small): poster type sizes FT/FA/FL, larger than the
%   paper's 6 pt, so ticks print at about 21 pt and labels at about 22 pt on the poster.
%   2026-11-10 (Aditya: make it look gorgeous; critique in RESEARCH): same data, panels and layout, restyled.
%   Cortex white with each node a hairline grey ring, so no change reads as an empty circle; session
%   outlines are their own masks with holes filled and lightly smoothed; site star black with a white edge;
%   session names regular grey, OL / CL names in the condition colours; mean maps larger, filling the box;
%   change panel: coloured mean +- SEM beside the dots (were black crosses) and a bracket with the stars.
%   The colour map is unchanged: the BrBG ramp passes sls_check (L* 38 / 100 / 41, even steps).
% OUT  poster/sfn2026/panels/seedfc_raw.pdf (git-ignored); panel_swap.py crops it to its ink.
%   Printed with print -vector on a fixed page, not exportgraphics, which rescales small panels.
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..', '..');
addpath(fullfile(root, 'utils'));
G = load(fullfile(root, 'controller-analysis', 'data', 'ctrl_seed_fc_group.mat'));
S = jnStyle(); FT = 7; FA = 7.5; FL = 8;
cmD = flipud(brbg(256)); cl = [-0.3 0.3]; nS = numel(G.sessions); cn = {'OL', 'CL'};
cc = {[0.85 0.2 0.15], [0.15 0.35 0.8]};
gry = [0.3 0.3 0.3]; ring = [0.84 0.84 0.84]; edgeC = [0.55 0.55 0.55];
lab = paper_session_label(G.sessions, 'short'); [lab, ord] = sort(lab);
mlN = (G.node(:,2) - 1)/50 - 1; apN = (G.node(:,1) - 1)/100;
xl = max(G.lat_px) / G.pxmm * [-1 1]; yl = [0 max(G.L_px) / G.pxmm];
dot = @(cm_per_mm) (0.75 * G.spacing_mm * cm_per_mm * 72 / 2.54)^2;
col = @(v) cmD(round(1 + (min(max(v, cl(1)), cl(2)) - cl(1)) / diff(cl) * 255), :);
star = @(p) char(repmat('*', 1, (p < 0.05) + (p < 0.01) + (p < 0.001)));
site = {'p', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w', 'LineWidth', 0.4};
clean = @(m) edge0(imgaussfilt(double(imfill(m, 'holes')), 1.5));   % smoothed, closed at the grid edge

Wp = 14; Hp = 7.5; fig = jnFig(Wp, Hp);
x00 = 0.6; W = 1.05; dx = 1.06; Hh = W * diff(yl) / diff(xl); R = x00 + (nS - 1) * dx + W;
yM = 0.75; Hm = 1.8;                                              % bottom row, taller
yT = yM + Hm + 0.4; yB = [yT + 0.22 + Hh + 0.05, yT + 0.22]; top = yB(1) + Hh;

% ---- top: every session
for c = 1:2
    for j = 1:nS
        i = ord(j);
        ax = axes(fig, 'Units', 'centimeters', 'Position', [x00 + (j - 1) * dx, yB(c), W, Hh]); hold(ax, 'on');
        contourf(ax, G.ml * G.lat_px(i) / G.pxmm, G.ap * G.L_px(i) / G.pxmm, clean(G.Mn{i}), [0.5 0.5], ...
            'FaceColor', 'w', 'LineColor', edgeC, 'LineWidth', 0.35);
        v = G.(cn{c}).dr(i, :).'; ok = ~isnan(v);
        scatter(ax, mlN(ok) * G.lat_px(i) / G.pxmm, apN(ok) * G.L_px(i) / G.pxmm, dot(W / diff(xl)), col(v(ok)), ...
            'filled', 'MarkerEdgeColor', ring, 'LineWidth', 0.2);
        plot(ax, G.site_n(i,2) * G.lat_px(i) / G.pxmm, G.site_n(i,1) * G.L_px(i) / G.pxmm, site{:}, 'MarkerSize', 4.5);
        set(ax, 'YDir', 'reverse'); axis(ax, 'equal', 'off'); xlim(ax, xl); ylim(ax, yl);
    end
end

% ---- bottom left: mean maps
Lx = G.Lml / G.pxmm; Ly = G.Lap / G.pxmm; Wm = Hm * 2 * Lx / Ly; xm = [x00, x00 + Wm + 0.22];
for c = 1:2
    ax = axes(fig, 'Units', 'centimeters', 'Position', [xm(c), yM, Wm, Hm]); hold(ax, 'on');
    contourf(ax, G.ml * Lx, G.ap * Ly, clean(G.cons), [0.5 0.5], 'FaceColor', 'w', 'LineColor', edgeC, 'LineWidth', 0.45);
    v = mean(G.(cn{c}).dr, 1, 'omitnan').';
    scatter(ax, mlN * Lx, apN * Ly, dot(Wm / (2 * Lx)), col(v), 'filled', 'MarkerEdgeColor', ring, 'LineWidth', 0.25);
    set(ax, 'YDir', 'reverse'); axis(ax, 'equal', 'off'); xlim(ax, Lx * [-1 1]); ylim(ax, [0 Ly]);
end
xcb = xm(2) + Wm + 0.15; hcb = Hm - 0.7; ycb = yM + (Hm - hcb) / 2;
ax = axes(fig, 'Units', 'centimeters', 'Position', [xcb, ycb, 0.12, hcb]);
imagesc(ax, [0 1], cl, (1:256).'); colormap(ax, cmD);
set(ax, 'YDir', 'normal', 'XTick', [], 'YTick', [-0.3 0 0.3], 'YTickLabel', {'-0.3', '0', '+0.3'}, 'YAxisLocation', 'right', ...
    'TickDir', 'out', 'TickLength', [0.03 0.03], 'FontSize', FT, 'LineWidth', S.lw_axis, 'Box', 'on');

% ---- bottom right: per-session summaries
lab_w = 1.3; wa = 2.0; ws = 1.5;
xa = xcb + 1.83 + lab_w; xs = xa + 3.85; x_free = R + 0.2 - (xs + ws);   % right plot may run 2 mm past the grid
ya = yM + 0.35; ha = Hm - 0.35;
ax = axes(fig, 'Units', 'centimeters', 'Position', [xa, ya, wa, ha]); hold(ax, 'on');
pc = zeros(1, 2);
for c = 1:2
    b = G.(cn{c}).sess_base(:); s = G.(cn{c}).sess_stim(:); pc(c) = signrank(b, s);
    plot(ax, [1 2], [b s].', '-', 'Color', cc{c} + (1 - cc{c}) * 0.6, 'LineWidth', S.lw_ind);
end
for c = 1:2
    b = G.(cn{c}).sess_base(:); s = G.(cn{c}).sess_stim(:);
    errorbar(ax, [1 2], [mean(b) mean(s)], [std(b) std(s)] / sqrt(nS), '-o', 'Color', cc{c}, 'LineWidth', 1.4, ...
        'CapSize', 0, 'MarkerSize', 3, 'MarkerFaceColor', cc{c});
end
set(ax, 'XTick', [1 2], 'XTickLabel', {'before', 'during'}, 'XLim', [0.8 2.6], 'YLim', [0.25 0.9], 'YTick', [0.3 0.6 0.9], ...
    'FontSize', FT, 'TickLength', [0.03 0.03], 'TickDir', 'out', 'Box', 'off', 'LineWidth', S.lw_axis);

ax2 = axes(fig, 'Units', 'centimeters', 'Position', [xs, ya, ws, ha]); hold(ax2, 'on');
yo = G.OL.sess_dr(:); yc = G.CL.sess_dr(:);
yline(ax2, 0, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', S.lw_ref);
plot(ax2, [1 2], [yo yc].', '-', 'Color', [0.75 0.75 0.75], 'LineWidth', S.lw_ind);
mk = {'o', 's'}; ms = [33 39];
for m = 1:2
    i = G.mouse(:) == ms(m);
    scatter(ax2, ones(nnz(i), 1), yo(i), 7, cc{1}, mk{m}, 'filled');
    scatter(ax2, 2 * ones(nnz(i), 1), yc(i), 7, cc{2}, mk{m}, 'filled');
end
xo = [0.62 2.38]; mu = [mean(yo) mean(yc)]; se = [std(yo) std(yc)] / sqrt(nS);
for c = 1:2
    plot(ax2, xo(c) * [1 1], mu(c) + se(c) * [-1 1], '-', 'Color', cc{c}, 'LineWidth', 1.0);
    plot(ax2, xo(c), mu(c), 'o', 'MarkerSize', 4, 'MarkerFaceColor', cc{c}, 'MarkerEdgeColor', 'w', 'LineWidth', 0.4);
end
p = signrank(yc, yo);
yb = 0.13; plot(ax2, [1 1 2 2], yb + [-0.025 0 0 -0.025], 'k-', 'LineWidth', 0.5);
text(ax2, 1.5, yb + 0.005, star(p), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', FA, 'FontWeight', 'bold');
set(ax2, 'XTick', [1 2], 'XTickLabel', {'OL', 'CL'}, 'XLim', [0.45 2.55], 'YLim', [-0.4 0.2], 'YTick', [-0.4 -0.2 0], ...
    'FontSize', FT, 'TickLength', [0.03 0.03], 'TickDir', 'out', 'Box', 'off', 'LineWidth', S.lw_axis);
ax2.XAxis.TickLabelColor = 'k';

% ---- text and scale bars
ov = axes(fig, 'Units', 'centimeters', 'Position', [0 0 Wp Hp], 'XLim', [0 Wp], 'YLim', [0 Hp], 'Visible', 'off'); hold(ov, 'on');
B = {'FontSize', FA, 'FontWeight', 'bold'};
for j = 1:nS
    text(ov, x00 + (j - 1) * dx + W / 2, top + 0.03, lab{j}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', FA, 'Color', gry);
end
for c = 1:2
    text(ov, x00 - 0.06, yB(c) + Hh / 2, cn{c}, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'FontSize', FL + 0.5, 'FontWeight', 'bold', 'Color', cc{c});
    text(ov, xm(c) + Wm / 2, yM + Hm + 0.05, sprintf('%s, mean', cn{c}), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', B{:}, 'Color', cc{c});
end
text(ov, (x00 + R) / 2, yT + 0.1, 'Each dot: change in its correlation with the site (star), during stimulation vs before', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', FA, 'Color', gry);
bar1 = 2 * W / diff(xl); bar2 = 2 * Wm / (2 * Lx);
plot(ov, x00 + [0 bar1], (yT + 0.1) * [1 1], 'k', 'LineWidth', 1);
text(ov, x00 + bar1 + 0.06, yT + 0.1, '2 mm', 'VerticalAlignment', 'middle', 'FontSize', FT);
plot(ov, x00 + [0 bar2], (yM - 0.16) * [1 1], 'k', 'LineWidth', 1);
text(ov, x00 + bar2 + 0.06, yM - 0.16, '2 mm', 'VerticalAlignment', 'middle', 'FontSize', FT);
text(ov, xcb - 0.22, ycb + hcb + 0.06, 'more correlated', 'VerticalAlignment', 'bottom', 'FontSize', FA);
text(ov, xcb - 0.22, ycb - 0.06, 'less correlated', 'VerticalAlignment', 'top', 'FontSize', FA);
text(ov, xa - 0.98, ya + ha / 2, {'correlation', 'with site'}, 'Rotation', 90, 'HorizontalAlignment', 'center', B{:});
text(ov, xs - 0.98, ya + ha / 2, {'change in', 'correlation'}, 'Rotation', 90, 'HorizontalAlignment', 'center', B{:});
ux = @(x) xa + (x - 0.8) / (2.6 - 0.8) * wa; uy = @(y) ya + (y - 0.25) / (0.9 - 0.25) * ha;
for c = 1:2
    s = mean(G.(cn{c}).sess_stim); t = star(pc(c)); if isempty(t), t = 'n.s.'; end
    text(ov, ux(2.05), uy(s), sprintf('%s %s', cn{c}, t), 'Color', cc{c}, 'VerticalAlignment', 'middle', B{:});
end

drawnow;
sls_check(fig, 'MinFontPt', 7, 'Ignore', {'spine', 'space'});
print(fig, fullfile(here, 'panels', 'seedfc_raw.pdf'), '-dpdf', '-vector');
close(fig);
fprintf('[SEEDFC] CL r %.3f -> %.3f (p = %.4f), OL r %.3f -> %.3f (p = %.4f)\n', mean(G.CL.sess_base), mean(G.CL.sess_stim), pc(2), ...
    mean(G.OL.sess_base), mean(G.OL.sess_stim), pc(1));
fprintf('[SEEDFC] r_during - r_before: CL %+.3f (%d/%d < 0), OL %+.3f; CL vs OL paired p = %.4f, n = %d, mice %s\n', ...
    mean(yc), nnz(yc < 0), nS, mean(yo), p, nS, mat2str(unique(G.mouse)));
end

function cm = brbg(n)
% brown - white - teal diverging (ColorBrewer BrBG endpoints), as ctrl_seed_fc_group.m
x = linspace(-1, 1, n).'; b = [0.55 0.32 0.04]; t = [0.00 0.40 0.37]; w = [1 1 1];
cm = (x < 0) .* (w + (-x) .* (b - w)) + (x >= 0) .* (w + x .* (t - w));
end

function s = edge0(s)
s([1 end], :) = 0; s(:, [1 end]) = 0;
end
