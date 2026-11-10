function st_quart_panel(out)
%ST_QUART_PANEL  Poster copy of Fig 4D (RMSE by state quartile), motion and absolute 1-4 Hz only, for SfN box 7.
%   st_quart_panel               % writes poster/sfn2026/panels/poster/st_quart_raw.pdf
%   st_quart_panel(out)          % or to another path (e.g. a scratch preview)
%   Aditya 2026-11-10: box 7's heading names movement and 1-4 Hz power, so the panel shows only those two.
%   Initial deviation is already in box 6; relative 2-4 Hz carries no claim and its CL/OL effect does not
%   hold laser off (RESEARCH 2026-11-02, f4d_windows.py).
%   Values are read from the .fig labstyle_remake saved of the NC panel f4_row2_quartiles_nc (session mean
%   +- SEM per quartile, z-scored RMSE, and the slope stars), so nothing is refit. Same colours as the paper.
%   With two tiles there is room for the stars beside each plot instead of above it; OL and CL lines are
%   written in their line colours, so they double as the key.
%   Type is the poster standard (unique_panel.m, poster_type.m): ticks 7 pt, labels and notes 7.5, titles 8
%   (about 21 / 22 / 24 pt on the poster at PS = 2.97). Canvas = the old panel's, so it fits box 7's slot.
%   Printed with print -vector on a fixed page, not exportgraphics, which rescales small panels.
%   The paper panel (figures_final/panels/figure4/f4_row2_quartiles_nc.pdf) is not touched.
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..', '..');
addpath(fullfile(root, 'utils'));
if nargin < 1 || isempty(out), out = fullfile(here, 'panels', 'poster', 'st_quart_raw.pdf'); end
src = fullfile(root, 'paper', 'figures_labstyle', 'src', 'images', 'figure4', 'f4_row2_quartiles_nc.fig');
keep = {'Motion', 'Abs 1-4 Hz'};
show = {'Motion', 'Absolute 1–4 Hz'};

% ---- read the plotted values -------------------------------------------------------------------
g0 = openfig(src, 'invisible');
ax0 = findall(g0, 'Type', 'axes');
T = struct([]);
for k = 1:numel(keep)
    a = ax0(strcmp(arrayfun(@(x) char(string(x.Title.String)), ax0, 'UniformOutput', false), keep{k}));
    assert(isscalar(a), 'tile "%s" not found in %s', keep{k}, src);
    eb = findall(a, 'Type', 'errorbar');
    isOL = arrayfun(@(e) e.Color(1) > 0.9 && e.Color(3) < 0.1, eb);           % OL red [1 0 0], CL blue
    assert(nnz(isOL) == 1 && numel(eb) == 2, 'expected one OL and one CL errorbar in "%s"', keep{k});
    tx = findall(a, 'Type', 'text');
    s = arrayfun(@(t) char(strjoin(cellstr(t.String), '')), tx, 'UniformOutput', false);
    pick = @(p) strtrim(erase(s{startsWith(s, p)}, p));
    T(k).OL = eb(isOL); T(k).CL = eb(~isOL);
    T(k).note = {pick('OL slope'), pick('CL slope'), pick('CL/OL')};
    T(k).tcol = a.Title.Color;
    T(k).ms = eb(1).MarkerSize;
end
for k = 1:numel(keep)                                                       % copy the data out before closing
    for c = {'OL', 'CL'}
        e = T(k).(c{1});
        T(k).([c{1} 'd']) = struct('x', e.XData, 'y', e.YData, 'lo', e.YNegativeDelta, 'hi', e.YPositiveDelta, ...
            'col', e.Color, 'mk', e.Marker, 'mfc', e.MarkerFaceColor);
    end
end
close(g0);

% ---- draw ---------------------------------------------------------------------------------------
S = jnStyle(); FT = 7; FA = 7.5; FL = 8;
Wp = 16.51; Hp = 3.30; fig = jnFig(Wp, Hp);                                  % the old panel's canvas
x0 = 1.35; w = 4.55; wn = 2.6; gapT = 0.75; y0 = 0.85; h = 1.85;               % axes, notes column, tile gap
yl = [-0.9 1.0]; yt = [-0.5 0 0.5 1];
ax = gobjects(1, 2);
for k = 1:2
    xa = x0 + (k - 1) * (w + wn + gapT);
    ax(k) = axes(fig, 'Units', 'centimeters', 'Position', [xa y0 w h]); hold(ax(k), 'on');
    yline(ax(k), 0, '-', 'Color', [.7 .7 .7], 'LineWidth', 0.5);
    for c = {'OLd', 'CLd'}
        d = T(k).(c{1});
        errorbar(ax(k), d.x, d.y, d.lo, d.hi, '-', 'Color', d.col, 'LineWidth', 1.0, 'CapSize', 0, ...
            'Marker', d.mk, 'MarkerFaceColor', d.mfc, 'MarkerEdgeColor', 'none', 'MarkerSize', T(k).ms * 1.2);
    end
    set(ax(k), 'XLim', [0.5 4.5], 'XTick', 1:4, 'XTickLabel', {'Q1', 'Q2', 'Q3', 'Q4'}, 'YLim', yl, ...
        'YTick', yt, 'Box', 'off', 'TickDir', 'out', 'FontSize', FT, 'LineWidth', S.lw_axis, ...
        'TickLength', [0.02 0.02], 'Layer', 'top');
    if k > 1, ax(k).YTickLabel = {}; end
    title(ax(k), show{k}, 'FontSize', FL, 'FontWeight', 'bold', 'Color', T(k).tcol);
    xlabel(ax(k), 'state quartile', 'FontSize', FA, 'FontWeight', 'bold');
    % stars beside the plot, OL and CL in their line colours (= the key)
    nx = xa + w + 0.25; ny = y0 + h - 0.15;
    L = {sprintf('OL slope %s', T(k).note{1}), sprintf('CL slope %s', T(k).note{2}), sprintf('CL/OL %s', T(k).note{3})};
    C = {T(k).OLd.col, T(k).CLd.col, [0 0 0]};
    for j = 1:3
        annotation_text(fig, nx, ny - (j - 1) * 0.42, L{j}, C{j}, FA);
    end
end
ylabel(ax(1), 'RMSE to target (z)', 'FontSize', FA, 'FontWeight', 'bold');

drawnow;
sls_check(fig, 'MinFontPt', 7, 'Ignore', {'spine', 'space'});
set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [Wp Hp], 'PaperPosition', [0 0 Wp Hp]);
print(fig, out, '-dpdf', '-vector');
[p, n] = fileparts(out); print(fig, fullfile(p, [n '.png']), '-dpng', '-r600');
close(fig);
for k = 1:2
    fprintf('[ST_QUART] %-16s OL %s  CL %s  | OL slope %s, CL slope %s, CL/OL %s\n', show{k}, ...
        mat2str(T(k).OLd.y, 3), mat2str(T(k).CLd.y, 3), T(k).note{:});
end
fprintf('[ST_QUART] -> %s\n', out);
end

function annotation_text(fig, x, y, str, col, fs)
% text in figure centimetres, through an invisible full-canvas axes (one per figure, reused)
ov = findobj(fig, 'Tag', 'st_quart_overlay');
if isempty(ov)
    ov = axes(fig, 'Units', 'centimeters', 'Position', [0 0 fig.Position(3:4)], 'XLim', [0 fig.Position(3)], ...
        'YLim', [0 fig.Position(4)], 'Visible', 'off', 'Tag', 'st_quart_overlay', 'HitTest', 'off');
    hold(ov, 'on');
end
text(ov, x, y, str, 'Color', col, 'FontSize', fs, 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
    'HorizontalAlignment', 'left', 'Interpreter', 'none');
end
