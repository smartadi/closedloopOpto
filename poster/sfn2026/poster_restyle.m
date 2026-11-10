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
%   fix       a per-panel function for what a size change alone can't do (moved notes, tighter limits).
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
T.st_quart = f(fullfile('figure4', 'f4_row2_quartiles_nc.fig'), @fix_st_quart);
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
% so they shrink, the type doesn't). The panel title in B is an annotation, which restyle() misses.
% A: "1 mW" sat left of its bar, on the red trace; it moves right of the bar, above "OL Stim".
g.Position(3:4) = g.Position(3:4) * (0.975 - 0.02 * ~trial);
for t = findall(g, 'Type', 'textboxshape').', t.FontSize = 8; end
if trial                                                            % y units: %dF/F, limits -10..10
    set(findall(g, 'Type', 'text', 'String', '1 mW'), 'Position', [0.15 8.4 0], 'HorizontalAlignment', 'left');
    set(findall(g, 'Type', 'text', 'String', 'OL Stim'), 'Position', [2.25 6.0 0]);   % above the laser trace (~4.3)
    set(findall(g, 'Type', 'text', 'String', 'CL Stim'), 'Position', [2.25 7.8 0]);   % above the CL laser trace (5.5-7)
end
end

function fix_cl_ratio(g)
% Box 3 ratios. At poster size the window names touched and the variance title ran off the canvas:
% limits pulled in to the
% outer windows, axes run to the right edge; title 7.5 pt.
a = findall(g, 'Type', 'axes'); a = a(1); a.Units = 'centimeters';
p = a.Position; a.Position = [p(1) p(2) g.Position(3) - p(1) - 0.08 p(4)];
a.XLim = [0.6 4.4]; a.XTickLabel = strrep(a.XTickLabel, '-', char(8211));
a.Title.FontSize = 7.5;
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
ylabel(ax, {'rejection', 'ratio (RR)'}, 'FontWeight', 'bold');
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
B = {'FontSize', 7.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'right'};
text(a, 2.95, yend - 0.35, 'Actual', B{:}, 'Color', 'k', 'VerticalAlignment', 'top');
text(a, 2.95, 0.4, 'Global (contra pred.)', B{:}, 'Color', col{find(~blk, 1)}, 'VerticalAlignment', 'bottom');
tx = findall(a, 'Type', 'text'); r = tx(arrayfun(@(t) startsWith(strjoin(cellstr(t.String), ''), 'R^2'), tx)); r.Position(2) = -3.5;
end

function fix_st_trials(g)
% Box 6. "high abs 1-4 Hz" at poster size is wider than its tile: titles on two lines ("high" / the
% variable), axes shortened to make room. The four tiles share one time scale, so one "1 s" bar is
% kept (leftmost) and the other three go.
% Canvas = the poster slot at PS (7.83 x 3.55 cm), the tile layout inset so the scale bars, which hang
% outside the first tile, stay on the page.
cm = [9.16 4.15] / 2.97 * 2.54; g.Position(3:4) = cm;
tl = findall(g, 'Type', 'tiledlayout'); tl.Units = 'centimeters'; tl.OuterPosition = [0.45 0.42 cm(1) - 0.45 cm(2) - 0.42];
ax = findall(g, 'Type', 'axes'); [~, o] = sort(arrayfun(@(a) a.Layout.Tile, ax)); ax = ax(o);
assert(all(arrayfun(@(a) isequal(a.XLim, ax(1).XLim), ax)), 'tiles do not share a time axis');
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

function fix_st_quart(g)
% Box 7. The three stacked notes per tile (OL slope, CL slope, CL/OL) collide at poster size. Same
% notes on two lines at the top of each tile, OL and CL in their line colours, which also makes the
% separate OL/CL key redundant. The super-title repeats the box heading, so it goes.
OLc = [0.85 0.2 0.15]; CLc = [0.15 0.35 0.8];
for t = findall(g, 'Type', 'tiledlayout').', t.Title.String = ''; end
rgb = @(c) sprintf('\\color[rgb]{%.2f,%.2f,%.2f}', c);
ax = findall(g, 'Type', 'axes');
ymax = -inf;
for a = ax.'
    tx = findall(a, 'Type', 'text');
    s = arrayfun(@(t) char(strjoin(cellstr(t.String), '')), tx, 'UniformOutput', false);
    pick = @(p) strtrim(erase(s{startsWith(s, p)}, p));
    if ~any(startsWith(s, 'OL slope')), continue; end
    o = pick('OL slope'); c = pick('CL slope'); r = pick('CL/OL');
    key = ismember(s, {'OL', 'CL'});                               % the manual key in the first tile
    delete(tx(startsWith(s, {'OL slope', 'CL slope', 'CL/OL'}) | key));
    if any(key)
        ln = findall(a, 'Type', 'line'); delete(ln(arrayfun(@(l) numel(l.XData) == 1, ln)));
    end
    for l = findall(a, 'Type', 'line').', ymax = max(ymax, max(l.YData)); end
    for e = findall(a, 'Type', 'errorbar').', ymax = max(ymax, max(e.YData + e.YPositiveDelta)); end
    B = {'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 7.5, ...
        'FontWeight', 'bold', 'Interpreter', 'tex'};
    text(a, 0.5, 1.0, sprintf('slope: %sOL %s%s, %sCL %s', rgb(OLc), o, rgb([0 0 0]), rgb(CLc), c), B{:});
    text(a, 0.5, 0.80, sprintf('CL/OL %s', r), B{:});
end
yl = ax(1).YLim; yt = ax(1).YTick;                                  % shared limits; notes take the top 40%
for a = ax.', a.YLim = [yl(1), yl(1) + (ymax - yl(1)) / 0.6]; a.YTick = yt(yt <= ymax + 0.05); end
end
