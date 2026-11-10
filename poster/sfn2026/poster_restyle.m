function poster_restyle(names)
%POSTER_RESTYLE  Poster-only copies of paper panels, restyled for reading at 1-2 m (SfN 2026, 2026-11-10).
%   poster_restyle                 % every panel in the table below
%   poster_restyle({'st_quart'})   % one or more by poster name
%
% Opens the .fig that labstyle_remake saved of each panel as its producer drew it
% (paper/figures_labstyle/src/images/..., all newer than the figures_final PDFs), so no analysis is rerun
% and no paper panel is touched. Canvas size is kept, so the panel still fits its poster slot at the one
% print scale (PS = 2.97). Then:
%   type      poster_type.m, the box-5 poster standard: ticks FT = 7 pt, labels and notes FA = 7.5 pt, titles FL = 8 pt
%             (about 21 / 22 / 24 pt on the poster; the paper's 5-6 pt printed at 15-18 pt).
%   lines     at least 0.6 pt, markers 20% larger.
%   axes      poster_lab_axes.m, the lab's axis style (Aditya 2026-11-10): 1 pt axes, ticks in, axis ends
%             on the end ticks, regular-weight text, titles left-aligned.
%   fix       a per-panel function for what a size change alone can't do: labels on the data instead of
%             legends, no dark lines at laser on/off (the grey band marks it), ratio panels shaded below 1.
% Box 7 (st_quart) is built by st_quart_panel.m since 2026-11-10 (Motion and Abs 1-4 Hz only, Aditya).
% OUT  poster/sfn2026/panels/poster/<name>_raw.pdf (git-ignored), printed with print -vector on the
%      figure's own page (exportgraphics rescales small panels). panel_swap.py crops and places it.
root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
addpath(genpath(fullfile(root, 'utils')));
src = fullfile(root, 'paper', 'figures_labstyle', 'src', 'images');
out = fullfile(fileparts(mfilename('fullpath')), 'panels', 'poster');
if ~isfolder(out), mkdir(out); end
T = table_of_panels();
if nargin < 1 || isempty(names), names = fieldnames(T).'; end
for k = 1:numel(names)
    n = names{k}; e = T.(n);
    if isa(e.fig, 'function_handle')
        g = e.fig(root);                                            % no saved .fig: poster-only builder
    else
        g = openfig(fullfile(src, e.fig), 'invisible');
        restore_alpha(g);
    end
    g.Units = 'centimeters';
    poster_type(g);
    poster_lab_axes(g);                                            % before the fix: snapping ignores notes in normalised units
    if ~isempty(e.fix), e.fix(g); end
    drawnow; cm = g.Position(3:4);
    sls_check(g, 'MinFontPt', 7, 'Ignore', {'spine', 'space'});
    set(g, 'PaperUnits', 'centimeters', 'PaperSize', cm, 'PaperPosition', [0 0 cm]);
    print(g, fullfile(out, [n '_raw.pdf']), '-dpdf', '-vector');
    close(g);
    fprintf('[poster_restyle] %s: %.2f x %.2f cm -> panels/poster/%s_raw.pdf\n', n, cm, n);
end
end

% ------------------------------------------------------------------------------------------------
function T = table_of_panels()
f = @(fig, fix) struct('fig', fig, 'fix', fix);
T.st_trials = f(fullfile('figure4', 'f4_state_exemplars.fig'), @fix_st_trials);
T.d_kernel = f(fullfile('figure4', 'f4_kernel_map.fig'), @fix_d_kernel);
T.d_agl = f(fullfile('figure4', 'f4_agl.fig'), @fix_d_agl);
T.d_rr = f(@build_d_rr, []);
T.cl_trial = f(fullfile('figure3', 'panel_A.fig'), @(g) fix_cl_ab(g, true));
T.cl_avg = f(fullfile('figure3', 'panel_B.fig'), @(g) fix_cl_ab(g, false));
T.cl_rmse = f(fullfile('figure3', 'MSE_ratio_by_window.fig'), @fix_cl_ratio);
T.cl_var = f(fullfile('figure3', 'variance_ratio_by_window.fig'), @fix_cl_ratio);
end

function fix_cl_ab(g, trial)
% Box 3 traces. Canvas 2.5% smaller so the larger type still fits the slot (axes are in normalised units,
% so they shrink, the type doesn't). The panel title in B is an annotation, which poster_type misses.
% Layout ideas (Aditya 2026-11-10, from a lab-style Fig 3): no dark lines at laser on/off, the grey band
% marks it; column titles "Open loop" / "Closed loop" left-aligned in the condition colours; A's legend
% goes and "Target" sits on its dashed line; "OL Stim" becomes "laser" on the grey command trace, "CL Stim"
% goes (one label is enough). "1 mW" moves right of its bar, off the red trace.
% Not done: a separate laser strip with an mW axis. The producer (analysisPlots_combined.m) draws the
% command as 5*v in OL and 4*v in CL under one "1 mW" bar, so the two can't share an mW axis as drawn.
g.Position(3:4) = g.Position(3:4) * (0.975 - 0.02 * ~trial);
ax = findall(g, 'Type', 'axes'); [~, o] = sort(arrayfun(@(a) a.Position(1), ax)); ax = ax(o);   % OL left, CL right
delete(findall(g, 'Type', 'constantline'));
for t = findall(g, 'Type', 'textboxshape').'                       % B's "Trial-averaged response"
    t.FontSize = 8; t.HorizontalAlignment = 'left'; t.Position(1) = ax(1).Position(1) - 0.01;
end
names = {'Open-Loop', 'Open loop'; 'Closed-Loop', 'Closed loop'};
for k = 1:2
    tx = findall(ax(k), 'Type', 'text');
    s = arrayfun(@(t) strjoin(cellstr(t.String), ''), tx, 'UniformOutput', false);
    r = tx(startsWith(s, 'RMSE')); col = r(1).Color;                % the condition colour
    h = tx(strcmp(s, names{k, 1}));
    if ~isempty(h), set(h, 'String', names{k, 2}, 'Color', col, 'Position', [0 1.06 0], 'HorizontalAlignment', 'left'); end
end
if trial                                                            % y units: %dF/F, limits -10..10
    delete(findall(g, 'Type', 'legend'));
    set(findall(g, 'Type', 'text', 'String', '1 mW'), 'Position', [0.15 8.4 0], 'HorizontalAlignment', 'left');
    set(findall(g, 'Type', 'text', 'String', 'OL Stim'), 'String', 'laser', 'Position', [2.25 6.0 0]);
    delete(findall(g, 'Type', 'text', 'String', 'CL Stim'));
    ln = findall(ax(1), 'Type', 'line', 'LineStyle', '--');
    yr = ln(1).YData(1);
    text(ax(1), -0.15, yr, 'Target', 'Color', [0.45 0.45 0.45], 'FontSize', 7.5, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle');
end
end

function fix_cl_ratio(g)
% Box 3 ratios. Axes run to the right edge, less the half of "Post" that hangs past the axis end, which
% now ends on the Pre and Post ticks (lab axes). Shaded below 1, where closed loop is better. The title
% names the measure ("CL lowers RMSE"), so the y label only says which way the ratio runs: "RMSE ratio
% (closed/open)" was longer than the axis and was cut off at the panel's left edge. Title 7.5 pt.
a = findall(g, 'Type', 'axes'); a = a(1); a.Units = 'centimeters';
p = a.Position; a.Position = [p(1) p(2) g.Position(3) - p(1) - 0.32 p(4)];
a.XTickLabel = strrep(a.XTickLabel, '-', char(8211));
a.Title.FontSize = 7.5;
yl = a.YLim; xl = a.XLim;
a.YLabel.String = 'Closed / open';
drawnow; ti = a.TightInset(1) + 0.05;                    % the variance panel's "0.25" pushes its label off the page
if ti > a.Position(1), a.Position([1 3]) = [ti a.Position(3) - (ti - a.Position(1))]; end
a.Title.Units = 'centimeters';                            % title from the panel's left edge, not the axis: the
a.Title.Position(1) = 0.15 - a.Position(1);               % moved axis pushed the stars past the right edge
pt = patch(a, xl([1 2 2 1]), [yl(1) yl(1) 1 1], [0.90 0.94 0.98], 'EdgeColor', 'none');
uistack(pt, 'bottom'); a.Layer = 'top'; a.YLim = yl; a.XLim = xl;
end

function g = build_d_rr(root)
% Box 8 rejection ratio. No .fig was saved, so this redraws f4_cl_reject_panel.m's panel from its .mat
% (same numbers: per-session geometric mean RR +- 1 SD of log RR, session t-test band and star) on the
% poster slot (5.92 x 3.84 in at PS). Session names in the poster's short form (M1c, as box 5), the title
% and y label on two lines so they fit at poster size. Nothing is written to paper/.
L = load(fullfile(root, 'controller-analysis', 'data', 'f4_cl_reject_lmm.mat'));
PS = paperStyle(); T = L.T;
if isfield(L, 'ST')                                                % session t-test (producer since 2026-10-27)
    gmS = L.ST.effect; ciS = L.ST.ci; p = L.ST.p; src = 'session t-test';
else                                                               % this PC's .mat predates it: session LMM, as the 10-20 panel
    gmS = exp(L.sessM.est); ciS = exp(L.sessM.ci); p = L.sessM.p1; src = 'session LMM (no ST in this .mat)';
end
u = unique(cellstr(T.sess), 'stable'); nS = numel(u);
gm = nan(nS, 1); lo = gm; hi = gm;
for i = 1:nS
    lr = T.logRR(T.sess == u{i}); m = mean(lr); s = std(lr);
    gm(i) = exp(m); lo(i) = exp(m - s); hi(i) = exp(m + s);
end
lab = string(paper_session_label(u, 'short'));
[gm, o] = sort(gm); lo = lo(o); hi = hi(o); lab = lab(o);
cm = [5.92 3.84] / 2.97 * 2.54;
g = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 cm], 'Color', 'w');
ax = axes(g, 'Units', 'centimeters', 'Position', [1.5 0.95 cm(1) - 1.62 cm(2) - 1.7]); hold(ax, 'on');
patch(ax, [0.3 nS+0.7 nS+0.7 0.3], [ciS(1) ciS(1) ciS(2) ciS(2)], [0.85 0.90 0.98], 'EdgeColor', 'none');
plot(ax, [0.3 nS+0.7], gmS * [1 1], '-', 'Color', PS.col_cl, 'LineWidth', 1.2);
plot(ax, [0.3 nS+0.7], [1 1], '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.75);
for i = 1:nS, plot(ax, [i i], [lo(i) hi(i)], '-', 'Color', PS.col_cl, 'LineWidth', 1.0); end
scatter(ax, 1:nS, gm, 22, PS.col_cl, 'filled', 'MarkerEdgeColor', 'none');
set(ax, 'YScale', 'log', 'XTick', 1:nS, 'XTickLabel', cellstr(lab), 'XTickLabelRotation', 45, 'TickLabelInterpreter', 'none', ...
    'YTick', [0.25 0.5 1 2], 'XLim', [0.3 nS+0.7], 'YLim', [0.22 2.9]);
jnAxes(ax);
star = repmat('*', 1, (p < 0.05) + (p < 0.01) + (p < 0.001)); if isempty(star), star = 'n.s.'; end
title(ax, {'CL rejects', sprintf('disturbances %s', star)});
ylabel(ax, {'Rejection', 'ratio (RR)'});
fprintf('[poster_restyle] d_rr: %d sessions, geomean RR %.2f [%.2f, %.2f], p = %.2g, from %s\n', nS, gmS, ciS, p, src);
end

function restore_alpha(g)
% sls_lab_export stores line transparency in appdata (a .fig drops the 4th colour element)
ln = findall(g, 'Type', 'line');
for k = 1:numel(ln)
    if isappdata(ln(k), 'sls_alpha'), ln(k).Color = [ln(k).Color(1:3) getappdata(ln(k), 'sls_alpha')]; end
end
end

% ------------------------------------------------------------------------------------------------
function fix_d_kernel(g)
% Box 8 map. The 408 weight dots tile the hemisphere, so they keep their paper size (larger ones smear
% into stripes). "stimulation site" on two lines, white on a small black label under the site marker, so it
% reads over the weights, the grey image and the white background alike.
for s = findall(g, 'Type', 'scatter').', s.SizeData = s.SizeData / 1.44; end
a = findall(g, 'Type', 'axes'); a = a(1);
t = findall(a, 'Type', 'text', 'String', 'stimulation site');
ln = findall(a, 'Type', 'line'); ln = ln(arrayfun(@(l) numel(l.XData) == 1, ln));
assert(~isempty(ln), 'no site marker found');
dn = 1 - 2 * strcmp(a.YDir, 'reverse');                             % +1 if y grows upward
set(t, 'String', {'stimulation', 'site'}, 'Color', 'w', 'BackgroundColor', 'k', 'Margin', 0.5, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
    'Position', [ln(1).XData, ln(1).YData - dn * 0.07 * diff(a.YLim)]);
end

function fix_d_agl(g)
% Box 8 trace. The legend sat on the traces: label each line directly instead, and lift R^2 off the axis.
a = findall(g, 'Type', 'axes'); a = a(1);
delete(findall(g, 'Type', 'legend'));
ln = findall(a, 'Type', 'line'); ln = ln(arrayfun(@(l) numel(l.XData) > 50, ln));
col = arrayfun(@(l) {l.Color(1:3)}, ln); blk = cellfun(@(c) all(c < 0.2), col);
yb = ln(blk).YData; xb = ln(blk).XData; yend = mean(yb(xb > 2.3));
B = {'FontSize', 7.5, 'HorizontalAlignment', 'right'};
text(a, 2.95, yend - 0.35, 'Actual', B{:}, 'Color', 'k', 'VerticalAlignment', 'top');
text(a, 2.95, 0.4, 'Global (contra pred.)', B{:}, 'Color', col{find(~blk, 1)}, 'VerticalAlignment', 'bottom');
tx = findall(a, 'Type', 'text'); r = tx(arrayfun(@(t) startsWith(strjoin(cellstr(t.String), ''), 'R^2'), tx)); r.Position(2) = -3.5;
end

function fix_st_trials(g)
% Box 6. "high abs 1-4 Hz" at poster size is wider than its tile: titles on two lines ("high" / the
% variable), axes shortened to make room. The four tiles share one time scale, so one "1 s" bar is
% kept (leftmost) and the other three go. The dotted line at laser onset goes: the grey band marks it.
% Canvas = the poster slot at PS (7.83 x 3.55 cm), the tile layout inset so the scale bars, which hang
% outside the first tile, stay on the page.
cm = [9.16 4.15] / 2.97 * 2.54; g.Position(3:4) = cm;
tl = findall(g, 'Type', 'tiledlayout'); tl.Units = 'centimeters'; tl.OuterPosition = [0.45 0.42 cm(1) - 0.45 cm(2) - 0.42];
ax = findall(g, 'Type', 'axes'); [~, o] = sort(arrayfun(@(a) a.Layout.Tile, ax)); ax = ax(o);
assert(all(arrayfun(@(a) isequal(a.XLim, ax(1).XLim), ax)), 'tiles do not share a time axis');
delete(findall(g, 'Type', 'constantline'));
for a = ax.'
    s = char(a.Title.String); a.Title.String = {'high', strtrim(erase(s, 'high'))};
    a.Title.FontSize = 7.5;
end
for a = ax(2:end).'
    tx = findall(a, 'Type', 'text', 'String', '1 s'); p = tx.Position; delete(tx);
    ln = findall(a, 'Type', 'line');
    bar = arrayfun(@(l) numel(l.XData) == 2 && abs(diff(l.XData) - 1) < 1e-6 && abs(diff(l.YData)) < 1e-6 && ...
        abs(l.YData(1) - p(2)) < 3, ln);
    delete(ln(bar));
end
% first tile: "5%" beside the middle of the vertical bar, "1 s" under the horizontal one
a = ax(1); ln = findall(a, 'Type', 'line');
v = ln(arrayfun(@(l) numel(l.XData) == 2 && abs(diff(l.XData)) < 1e-9 && abs(diff(l.YData)) > 0, ln));
h = ln(arrayfun(@(l) numel(l.XData) == 2 && abs(diff(l.YData)) < 1e-9 && abs(diff(l.XData) - 1) < 1e-6, ln));
t5 = findall(a, 'Type', 'text', 'String', '5%'); t1 = findall(a, 'Type', 'text', 'String', '1 s');
dx = diff(a.XLim) * 0.04; dy = diff(a.YLim) * 0.03;
set(t5, 'Position', [v(1).XData(1) - dx, mean(v(1).YData)], 'Rotation', 90, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
set(t1, 'Position', [mean(h(1).XData), h(1).YData(1) - dy], 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
% motion tile: "z-motion" under its grey trace, not on it
a = ax(2); tz = findall(a, 'Type', 'text', 'String', 'z-motion');
gr = findall(a, 'Type', 'line'); gr = gr(arrayfun(@(l) numel(l.XData) > 10 && all(abs(l.Color(1:3) - 0.55) < 0.01), gr));
set(tz, 'Position', [tz.Position(1), min(gr(1).YData) - dy], 'VerticalAlignment', 'top');
end
