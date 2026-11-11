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
    s = poster_grow(g, n);                                         % v7: placed s times larger, type scaled 1/s
    drawnow; cm = g.Position(3:4);
    sls_check(g, 'MinFontPt', 7 / s - 0.01, 'Ignore', {'spine', 'space'});
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
T.d_kernel = f(fullfile('figure4', 'f4_kernel_map.fig'), @fix_d_kernel_dots);
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
for t = findall(g, 'Type', 'text').'                                % 2026-11-11: "ΔF/F" poster-wide (the scale
    s = t.String;                                                   % bars said "dF/F", every other box "ΔF/F")
    if ischar(s) && contains(s, 'dF/F'), t.String = strrep(s, 'dF/F', [char(916) 'F/F']); end
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
% v6 (Aditya 2026-11-10, "Move them into panels"): box 3's bullets go, so the title carries their number, the
% 0-3 s geometric-mean ratio from paper_stats_table.m (3H_rmse_full / 3I_var_full) as a percentage drop.
S = readtable(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'paper-writing', 'STATS_TABLE.csv'), ...
    'TextType', 'string', 'Delimiter', ',');
t = a.Title.String; if iscell(t), t = strjoin(t, ' '); end
if contains(t, 'RMSE'), id = "3H_rmse_full"; w = 'RMSE'; else, id = "3I_var_full"; w = 'variance'; end
pct = round(100 * (1 - S.effect(S.id == id)));
assert(isscalar(pct) && contains(t, w), 'stats row or title word missing');
a.Title.String = strrep(t, w, sprintf('%s %d%%', w, pct));
fprintf('[poster_restyle] %s title: %s (%s, ratio %.4f)\n', w, a.Title.String, id, S.effect(S.id == id));
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
[gm, o] = sort(gm); lo = lo(o); hi = hi(o);
cm = [5.92 3.84] / 2.97 * 2.54;
g = figure('Visible', 'off', 'Units', 'centimeters', 'Position', [2 2 cm], 'Color', 'w');
% v5 (2026-11-10, approved): no session names (11 rotated names in ~2.5 cm could not be read), so the plot box
% gets d_agl's height, 2.17 cm, with its top 0.55 cm below the canvas top as d_agl's is; the title goes on
% one line from the canvas's left edge.
H_PLOT = 2.17; TOP = 0.55;
ax = axes(g, 'Units', 'centimeters', 'Position', [1.5 cm(2) - TOP - H_PLOT cm(1) - 1.62 H_PLOT]); hold(ax, 'on');
patch(ax, [0.3 nS+0.7 nS+0.7 0.3], [ciS(1) ciS(1) ciS(2) ciS(2)], [0.85 0.90 0.98], 'EdgeColor', 'none');
plot(ax, [0.3 nS+0.7], gmS * [1 1], '-', 'Color', PS.col_cl, 'LineWidth', 1.2);
plot(ax, [0.3 nS+0.7], [1 1], '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.75);
for i = 1:nS, plot(ax, [i i], [lo(i) hi(i)], '-', 'Color', [0.72 0.72 0.72], 'LineWidth', 0.6); end   % v6: thin grey (Aditya 2026-11-10)
scatter(ax, 1:nS, gm, 22, PS.col_cl, 'filled', 'MarkerEdgeColor', 'none');
set(ax, 'YScale', 'log', 'XTick', [], 'YTick', [0.25 0.5 1 2], 'YMinorTick', 'off', 'XLim', [0.3 nS+0.7], 'YLim', [0.22 2.9]);
jnAxes(ax);
xlabel(ax, sprintf('Session (%d, sorted by RR)', nS));
star = repmat('*', 1, (p < 0.05) + (p < 0.01) + (p < 0.001)); if isempty(star), star = 'n.s.'; end
text(ax, -1.4, H_PLOT + 0.12, sprintf('CL rejects disturbances %s', star), 'Units', 'centimeters', ...
    'FontSize', 8, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Clipping', 'off');
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
function fix_d_kernel_dots(g)
% Box 8, v11 (Aditya 2026-11-11): "bring back the original kernel map but make it more sparse"; of the options
% (top 10% / 25% of |weights|, small dots, a lasso refit) he picked "C: all, small dots": every one of the 408
% ridge weights is kept, only the dots shrink. Their diameter is 0.75 of the grid step, the rule box 5 uses, so
% each pixel reads as its own dot instead of the stripes touching dots made (v9; v10 had a diagram instead).
% Title (his pick): "Contra-to-ipsi prediction model" (the model predicts the ipsi site from the contra hemisphere).
fix_d_kernel(g);
a = findall(g, 'Type', 'axes'); a = a(1);
s = findall(a, 'Type', 'scatter'); assert(isscalar(s), 'expected one weight scatter');
u = a.Units; a.Units = 'points'; pos = a.Position; a.Units = u;
ppd = min(pos(3) / diff(a.XLim), pos(4) / diff(a.YLim));          % points per data unit ('axis image')
st = min(diff(unique(s.XData)));                                  % grid step, data units (13 px)
s.SizeData = (0.75 * st * ppd)^2;
fprintf('[poster_restyle] d_kernel: %d dots, step %.0f px = %.2f pt, dot %.2f pt across\n', numel(s.XData), st, st * ppd, 0.75 * st * ppd);
set(findall(g, 'Type', 'text'), 'FontWeight', 'normal');
% The title is wider than the map, so it is plain text on an overlay in cm (an axes title moved after placing
% it): from the panel's left edge, just above the brain (the image fills less than its axes: 'axis image').
% The colour bar is shortened from the top so its "+0.16" sits below the title.
a.Title.String = '';
g.Units = 'centimeters'; a.Units = 'centimeters'; p = a.Position; drawnow;
k = min(p(3) / diff(a.XLim), p(4) / diff(a.YLim)); top = p(2) + (p(4) + diff(a.YLim) * k) / 2;   % brain's top, cm
W = g.Position(3); H = g.Position(4);
ov = axes(g, 'Units', 'centimeters', 'Position', [0 0 W H], 'XLim', [0 W], 'YLim', [0 H], 'Visible', 'off');
t = text(ov, 0.10, top + 0.06, 'Contra-to-ipsi prediction model', 'FontSize', 8, 'FontWeight', 'normal', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
drawnow; e = t.Extent;                                             % [x y w h] in cm on the canvas
assert(e(2) + e(4) <= H + 0.01 && e(1) + e(3) <= W, 'title runs off the panel');
cb = findall(g, 'Type', 'colorbar'); cb.Units = 'centimeters';
lim = e(2) - 0.06 - 0.5 * 0.0353 * cb.FontSize;                    % half a tick label (pt -> cm) below the title
if cb.Position(2) + cb.Position(4) > lim, cb.Position(4) = lim - cb.Position(2); end
a.Position = p; drawnow;                                          % a manual colour bar lets the axes re-grow
assert(max(abs(a.Position - p)) < 1e-6 && cb.Position(1) >= p(1) + (p(3) + diff(a.XLim) * k) / 2, ...
    'the colour bar overlaps the map');
end

function fix_d_kernel(g)
% Box 8 map. The 408 weight dots tile the hemisphere, so they keep their paper size (larger ones smear
% into stripes). v6 (Aditya 2026-11-10, "Strip annotations"): the site is a black ring instead of a black
% disc with a black label box, and a one-line key under the map names it (the map
% fills its axes, so a label on it would cover weights or cortex). The dotted midline goes (the weights stop
% at the midline anyway).
for s = findall(g, 'Type', 'scatter').', s.SizeData = s.SizeData / 1.44; end
a = findall(g, 'Type', 'axes'); a = a(1);
delete(findall(a, 'Type', 'text', 'String', 'stimulation site'));
delete(findall(a, 'Type', 'line', 'LineStyle', ':'));
ln = findall(a, 'Type', 'line'); ln = ln(arrayfun(@(l) numel(l.XData) == 1, ln));
assert(~isempty(ln), 'no site marker found');
ms = ln(1).MarkerSize; x = ln(1).XData; y = ln(1).YData;
ring = @(xx, yy) plot(a, xx, yy, 'o', 'MarkerSize', ms, 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, 'Clipping', 'off');
delete(ln(1)); ring(x, y);
yk = a.YLim(2) + 0.075 * diff(a.YLim);                              % under the axes (image axes: y grows downward)
xk = a.XLim(1) + 0.30 * diff(a.XLim);
ring(xk, yk);
text(a, xk + 0.11 * diff(a.XLim), yk, 'stimulation site', 'FontSize', 7.5, 'Color', 'k', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Clipping', 'off');
end

function fix_d_agl(g)
% Box 8 trace. The legend sat on the traces: label each line directly instead, and lift R^2 off the axis.
% v6 (Aditya 2026-11-10, "Strip annotations"): no beige stimulation window, dashed zero line or dotted onset
% line; a red bar above the traces marks the laser (0-3 s); labels in regular weight; "Local" alone (the
% title already says Actual = Global + Local).
a = findall(g, 'Type', 'axes'); a = a(1);
delete(findall(g, 'Type', 'legend'));
pt = findall(a, 'Type', 'patch'); delete(pt(arrayfun(@(q) all(abs(q.FaceColor - [0.93 0.90 0.82]) < 0.03), pt)));
delete(findall(a, 'Type', 'constantline'));
delete(findall(a, 'Type', 'line', 'LineStyle', '--'));
ln = findall(a, 'Type', 'line'); ln = ln(arrayfun(@(l) numel(l.XData) > 50, ln));
col = arrayfun(@(l) {l.Color(1:3)}, ln); blk = cellfun(@(c) all(c < 0.2), col);
yb = ln(blk).YData; xb = ln(blk).XData; yend = mean(yb(xb > 2.3));
B = {'FontSize', 7.5, 'FontWeight', 'normal', 'HorizontalAlignment', 'right'};
text(a, 2.95, yend - 0.35, 'Actual', B{:}, 'Color', 'k', 'VerticalAlignment', 'top');
text(a, 2.95, 0.4, 'Global (contra pred.)', B{:}, 'Color', col{find(~blk, 1)}, 'VerticalAlignment', 'bottom');
tx = findall(a, 'Type', 'text');
loc = tx(arrayfun(@(t) startsWith(strjoin(cellstr(t.String), ''), 'Local'), tx)); set(loc, 'String', 'Local', 'FontWeight', 'normal');
r = tx(arrayfun(@(t) startsWith(strjoin(cellstr(t.String), ''), 'R^2'), tx)); r.Position(2) = -3.5;
yl = a.YLim; red = [0.85 0.12 0.10];
plot(a, [0 3], yl(2) - 0.12 * [1 1], '-', 'Color', red, 'LineWidth', 3);
text(a, -0.08, yl(2) - 0.12, 'laser', 'FontSize', 7.5, 'Color', red, 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'middle');
a.YLim = yl;
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
% 2026-11-11: the high init-dev example ran past the top of its tile and was cut off. The tiles share one y
% scale (one 5% bar for all four), so every tile gets the same higher top: the highest point in view + 2%.
yl = cell2mat(arrayfun(@(a) a.YLim, ax, 'UniformOutput', false));
assert(all(all(abs(yl - yl(1, :)) < 1e-9)), 'tiles do not share a y range');
tr = findall(ax, 'Type', 'line'); tr = tr(arrayfun(@(l) numel(l.XData) > 10, tr));
xv = ax(1).XLim;
hi = max(arrayfun(@(l) double(max([-Inf, l.YData(l.XData >= xv(1) & l.XData <= xv(2))])), tr));
if hi > yl(1, 2)
    set(ax, 'YLim', [yl(1, 1), hi + 0.02 * (hi - yl(1, 1))]);
    fprintf('[poster_restyle] st_trials: y top %.2f -> %.2f\n', yl(1, 2), ax(1).YLim(2));
end
for a = ax.'
    s = char(a.Title.String); a.Title.String = {'high', strtrim(erase(s, 'high'))};
    a.Title.String{2} = regexprep(a.Title.String{2}, '(\d)-(\d)', ['$1' char(8211) '$2']);   % 2026-11-11: en dash in ranges, as elsewhere
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
set(t5, 'String', ['5% ' char(916) 'F/F']);                       % 2026-11-11: the unit, as in the other boxes
set(t1, 'Position', [mean(h(1).XData), h(1).YData(1) - dy], 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
% motion tile: "z-motion" under its grey trace, not on it
a = ax(2); tz = findall(a, 'Type', 'text', 'String', 'z-motion');
gr = findall(a, 'Type', 'line'); gr = gr(arrayfun(@(l) numel(l.XData) > 10 && all(abs(l.Color(1:3) - 0.55) < 0.01), gr));
set(tz, 'Position', [tz.Position(1), min(gr(1).YData) - dy], 'VerticalAlignment', 'top');
end
