function st_quart_panel(out)
%ST_QUART_PANEL  SfN poster box 7: RMSE by state quartile (motion, absolute 1-4 Hz) + where in frequency each state adds power.
%   st_quart_panel               % writes poster/sfn2026/panels/poster/st_quart_raw.pdf
%   st_quart_panel(out)          % or to another path (e.g. a scratch preview)
% Box 7's story (Aditya, 2026-11-10): the quartile result first, then the spectra as one explanation.
%   Tiles   Fig 4D for motion and absolute 1-4 Hz only (box 7's heading; initial deviation is in box 6,
%           relative 2-4 Hz carries no claim). Values are read from the .fig labstyle_remake saved of the
%           NC panel f4_row2_quartiles_nc (session mean +- SEM of z-scored RMSE per quartile, and the slope
%           stars), so nothing is refit. Stars sit beside each plot, OL and CL in their line colours (= key).
%   Spectra Q4/Q1 power ratio of the 0-3 s residual, motion and 1-4 Hz, OL solid and CL dashed, geometric
%           mean over sessions with a session-bootstrap 95% band, no test. From
%           stats_v2/state_ratio_poster.py -> data/stats_v2/corrected/state_ratio_poster.csv. Both states on
%           the locked [-2,+3) s window, as the tiles (circular for 1-4 Hz; Aditya's choice). The bars mark
%           where the sensitivity curve's 95% CI excludes 1 (sensitivity_cert.py): feedback reduces power
%           below 1.03 Hz and amplifies it at 2.77-6.63 Hz.
% Type is the poster standard (poster_type.m): ticks 7 pt, labels and notes 7.5, titles 8 (about 21 / 22 /
% 24 pt on the poster at PS = 2.97), then the lab axes (poster_lab_axes.m, Aditya 2026-11-10). Canvas = the
% old panel's 16.51 x 3.30 cm, so it fits box 7's slot. Printed with print -vector on a fixed page, not
% exportgraphics, which rescales small panels. The paper panels are not touched.
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..', '..');
addpath(fullfile(root, 'utils')); addpath(here);
if nargin < 1 || isempty(out), out = fullfile(here, 'panels', 'poster', 'st_quart_raw.pdf'); end
src = fullfile(root, 'paper', 'figures_labstyle', 'src', 'images', 'figure4', 'f4_row2_quartiles_nc.fig');
spc = fullfile(root, 'data', 'stats_v2', 'corrected', 'state_ratio_poster.csv');
keep = {'Motion', 'Abs 1-4 Hz'};
show = {'Motion', 'Absolute 1–4 Hz'};
skey = {'motion', 'abs14'};

% ---- quartile values from the saved figure -------------------------------------------------------
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
    T(k).note = {pick('OL slope'), pick('CL slope'), pick('CL/OL')};
    T(k).tcol = a.Title.Color;
    T(k).ms = eb(1).MarkerSize;
    for c = {'OL', 'CL'}
        e = eb(isOL == strcmp(c{1}, 'OL'));
        T(k).([c{1} 'd']) = struct('x', e.XData, 'y', e.YData, 'lo', e.YNegativeDelta, 'hi', e.YPositiveDelta, ...
            'col', e.Color, 'mk', e.Marker, 'mfc', e.MarkerFaceColor);
    end
end
close(g0);
R = readtable(spc, 'TextType', 'string');

% ---- layout (cm) -----------------------------------------------------------------------------------
FT = 7; FA = 7.5; FL = 8;
Wp = 16.51; Hp = 3.62; fig = jnFig(Wp, Hp);                                % 3.62 cm inks to <= the 4.0 in slot
y0 = 0.85; h = 2.15; hs = 1.75; yT = 3.12;                                  % tile / spectral axes heights; title row
% the spectral panel is shorter: the feedback bars and their labels sit between its top and the title row
x0 = 1.2; w = 3.0; wn = 1.45; gapT = 0.2;                                   % tiles + their notes column
xs = x0 + 2 * (w + wn) + gapT + 1.3; ws = Wp - xs - 0.2;                    % spectral panel
ov = axes(fig, 'Units', 'centimeters', 'Position', [0 0 Wp Hp], 'XLim', [0 Wp], 'YLim', [0 Hp], ...
    'Visible', 'off', 'HitTest', 'off'); hold(ov, 'on');

% ---- quartile tiles --------------------------------------------------------------------------------
for k = 1:2
    xa = x0 + (k - 1) * (w + wn + gapT);
    a = axes(fig, 'Units', 'centimeters', 'Position', [xa y0 w h]); hold(a, 'on');
    yline(a, 0, '-', 'Color', [.7 .7 .7], 'LineWidth', 0.5);
    for c = {'OLd', 'CLd'}
        d = T(k).(c{1});
        errorbar(a, d.x, d.y, d.lo, d.hi, '-', 'Color', d.col, 'LineWidth', 1.0, 'CapSize', 0, ...
            'Marker', d.mk, 'MarkerFaceColor', d.mfc, 'MarkerEdgeColor', 'none', 'MarkerSize', T(k).ms * 1.2);
    end
    set(a, 'XLim', [0.5 4.5], 'XTick', 1:4, 'XTickLabel', {'Q1', 'Q2', 'Q3', 'Q4'}, 'YLim', [-1 1], ...
        'YTick', -1:0.5:1, 'FontSize', FT);
    if k > 1, a.YTickLabel = {}; end
    % titles on the overlay at one height: an axes title next to y tick labels gets lifted
    text(ov, xa, yT, show{k}, 'FontSize', FL, 'Color', T(k).tcol, 'VerticalAlignment', 'bottom');
    xlabel(a, 'state quartile', 'FontSize', FA);
    if k == 1, ylabel(a, 'RMSE to target (z)', 'FontSize', FA); end
    L = {['OL ' T(k).note{1}], ['CL ' T(k).note{2}], ['CL/OL ' T(k).note{3}]};
    C = {T(k).OLd.col, T(k).CLd.col, [0 0 0]};
    for j = 1:3
        text(ov, xa + w + 0.15, y0 + h - 0.05 - (j - 1) * 0.4, L{j}, 'Color', C{j}, 'FontSize', FA, ...
            'VerticalAlignment', 'top', 'Interpreter', 'none');
    end
end

% ---- spectral panel: Q4/Q1 power ratio -------------------------------------------------------------
a = axes(fig, 'Units', 'centimeters', 'Position', [xs y0 ws hs]); hold(a, 'on');
FX = [0.5 8]; YX = [0.18 12];                                               % bands span 0.20-10.4
yline(a, 1, '-', 'Color', [.7 .7 .7], 'LineWidth', 0.5);
for k = 1:2
    for c = ["OL", "CL"]
        r = R(R.state == skey{k} & R.cond == c & R.freq >= FX(1) & R.freq <= FX(2), :);
        fill(a, [r.freq; flipud(r.freq)], [r.lo; flipud(r.hi)], T(k).tcol, 'EdgeColor', 'none', ...
            'FaceAlpha', 0.18);
        ls = '-'; if c == "CL", ls = '--'; end
        plot(a, r.freq, r.ratio, 'Color', T(k).tcol, 'LineWidth', 1.0, 'LineStyle', ls);
    end
end
set(a, 'XScale', 'log', 'YScale', 'log', 'XLim', FX, 'YLim', YX, 'XTick', [0.5 1 2 4 8], ...
    'XTickLabel', {'0.5', '1', '2', '4', '8'}, 'YTick', [0.25 1 4], ...
    'YTickLabel', {'0.25', '1', '4'}, 'FontSize', FT, 'XMinorTick', 'off', 'YMinorTick', 'off');
xlabel(a, 'frequency (Hz)', 'FontSize', FA);
ylabel(a, 'Q4 / Q1 power', 'FontSize', FA);
text(ov, xs, yT, 'High vs low state', 'FontSize', FL, 'VerticalAlignment', 'bottom');
% feedback bars along the top (sensitivity_cert.py: CI excludes 1), drawn in cm so axis snapping can't move them
fx = @(f) xs + ws * log(f / FX(1)) / log(FX(2) / FX(1));
yb = y0 + hs + 0.09;
plot(ov, [fx(FX(1)) fx(1.03)], [yb yb], 'k', 'LineWidth', 2.5);
plot(ov, [fx(2.77) fx(6.63)], [yb yb], 'k', 'LineWidth', 2.5);
text(ov, fx(FX(1)), yb + 0.06, 'feedback reduces', 'FontSize', FT, 'VerticalAlignment', 'bottom');
text(ov, fx(6.63), yb + 0.06, 'amplifies', 'FontSize', FT, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
% key in the title row, right: line style = condition
kx = xs + ws - 1.75; ky = yT + 0.16;
plot(ov, kx + [0 0.35], [ky ky], 'k-', 'LineWidth', 1.0);
text(ov, kx + 0.42, ky, 'OL', 'FontSize', FT, 'VerticalAlignment', 'middle');
plot(ov, kx + 0.95 + [0 0.35], [ky ky], 'k--', 'LineWidth', 1.0);
text(ov, kx + 1.37, ky, 'CL', 'FontSize', FT, 'VerticalAlignment', 'middle');

uistack(ov, 'top');                                                         % else the plots' white hides it
drawnow;
poster_lab_axes(fig);
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
