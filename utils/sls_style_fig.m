function R = sls_style_fig(fig, varargin)
% SLS_STYLE_FIG  Restyle a finished figure to the steinmetzlab-style paper defaults.
%
%   R = sls_style_fig(fig)
%   R = sls_style_fig(fig, 'SnapSpines',true, 'RefLines',true, 'Diverging',true, 'LegendPt',[])
%
% FOR COMPARISON ONLY (2026-11-05). This is the lab's paper.mplstyle and its helpers translated
% to MATLAB, so the paper's figures can be seen in the lab style next to our jn style. Our jn
% style stays the paper style until Aditya and Nick decide otherwise (CLAUDE.md, "Lab style
% repo": lab defaults that differ from ours are open decisions). paper_final_mirror calls this
% instead of jnAxesAll only when the global PAPER_LABSTYLE is true, and then writes to
% paper/figures_labstyle/, never to figures_final/.
%
% What changes, against jnAxes (paper.mplstyle values):
%   axis lines        1 pt                     (jn 0.5 pt)
%   ticks             in, 4 pt long            (jn out, 2% of the longer side)
%   axis labels/title 7 pt REGULAR             (jn 7 pt bold)
%   tick labels       6 pt regular             (same)
%   legends           regular, no box; size kept (paper.mplstyle says 7 pt: 'LegendPt',7 applies it.
%                     Off by default because our panels are laid out for 6 pt legends, and at 7 pt
%                     they ran off the canvas in Fig 2A/2C, 2026-11-05)
%   colour bars       no tick marks, no outline, 6 pt labels (axes.py colorbar)
%   axis ends         on the first and last tick (axes.py spines_to_ticks), see SnapSpines
%   reference lines   0.5 pt dashed 50% gray   (axes.py REFERENCE_STYLE), see RefLines
%   diverging maps    CET-D1A, white centre    (colors.py cmap_diverging), see Diverging
% Untouched: data line widths and colours (ours are locked), annotation text, panel sizes.
%
% SnapSpines. matplotlib can draw a spine shorter than the axis (set_bounds); MATLAB cannot,
% so the axis LIMITS move to the outer ticks instead, and only when nothing drawn in the axes
% (lines, markers, patches, bars, error bars, text inside the box) would fall outside them.
% Axes with images, surfaces, bars on x, or log/datetime/categorical rulers are left alone.
% RefLines. xline/yline in a gray colour, and two-point horizontal or vertical lines in a gray
% colour that are dashed or dotted. Solid two-point lines are left alone: they are often scale
% bars. MATLAB's '--' dash cannot be set to the lab's (4, 2) pattern.
% Diverging. A map with at least 16 colours whose lightness peaks in the middle third and whose
% two ends differ in hue by more than 90 degrees. CLim is not changed.
%
% R counts what was changed: axes, snapped (axis ends moved), reflines, cmaps, legends, colorbars.

p = inputParser;
addParameter(p, 'SnapSpines', true);
addParameter(p, 'RefLines', true);
addParameter(p, 'Diverging', true);
addParameter(p, 'LegendPt', []);
parse(p, varargin{:});
o = p.Results;
if nargin < 1 || isempty(fig); fig = gcf; end
R = struct('axes',0, 'snapped',0, 'reflines',0, 'cmaps',0, 'legends',0, 'colorbars',0);
ppi = get(groot, 'ScreenPixelsPerInch');
gray = [0.5 0.5 0.5];

ax = findobj(fig, 'Type', 'axes');
for k = 1:numel(ax)
    a = ax(k);
    set(a, 'FontName','Arial', 'FontSize',6, 'FontWeight','normal', ...
        'TickDir','in', 'Box','off', 'LineWidth',1);
    pos = getpixelposition(a, true) * 72 / ppi;                 % points
    L = 4 / max([pos(3:4) 1]);                                  % 4 pt as a fraction of the longer side
    a.TickLength = [L L];
    labs = [a.XLabel, a.Title];
    for y = 1:numel(a.YAxis), labs(end+1) = a.YAxis(y).Label; end %#ok<AGROW>
    set(labs, 'FontName','Arial', 'FontSize',7, 'FontWeight','normal');
    R.axes = R.axes + 1;

    if o.RefLines;   R.reflines = R.reflines + local_reflines(a, gray); end
    if o.SnapSpines; R.snapped  = R.snapped  + local_snap(a); end
    if o.Diverging && local_is_diverging(a.Colormap)
        a.Colormap = sls_cmap('diverging', size(a.Colormap, 1));
        R.cmaps = R.cmaps + 1;
    end
end

lg = findobj(fig, 'Type', 'legend');
for k = 1:numel(lg)
    set(lg(k), 'FontName','Arial', 'FontWeight','normal', 'Box','off');
    if ~isempty(o.LegendPt), lg(k).FontSize = o.LegendPt; end
    lg(k).Title.FontWeight = 'normal';
    R.legends = R.legends + 1;
end

cb = findobj(fig, 'Type', 'colorbar');
for k = 1:numel(cb)
    set(cb(k), 'FontName','Arial', 'FontSize',6, 'TickLength',0, 'Box','off');
    set(cb(k).Label, 'FontName','Arial', 'FontSize',7, 'FontWeight','normal');
    R.colorbars = R.colorbars + 1;
end
end

% -----------------------------------------------------------------------------------------
function n = local_reflines(a, gray)
n = 0;
isgray = @(c) isnumeric(c) && numel(c) == 3 && (max(c) - min(c)) < 0.05;
cl = findall(a, 'Type', 'constantline');
for k = 1:numel(cl)
    if isgray(cl(k).Color)
        set(cl(k), 'LineWidth',0.5, 'LineStyle','--', 'Color',gray);
        n = n + 1;
    end
end
ln = findall(a, 'Type', 'line');
for k = 1:numel(ln)
    h = ln(k);
    x = h.XData; y = h.YData;
    if numel(x) ~= 2 || numel(y) ~= 2 || any(~isfinite([x y])), continue; end
    if ~any(strcmp(h.LineStyle, {'--', ':', '-.'})) || ~isgray(h.Color), continue; end
    if x(1) == x(2) || y(1) == y(2)
        set(h, 'LineWidth',0.5, 'LineStyle','--', 'Color',gray);
        n = n + 1;
    end
end
end

% -----------------------------------------------------------------------------------------
function n = local_snap(a)
% Move each axis limit onto its outer tick when nothing drawn would fall outside. Returns the
% number of axes sides (x and y) moved.
n = 0;
kids = findall(a);
kids = kids(kids ~= a);
skip = [a.XLabel; a.Title; a.Subtitle; a.ZLabel];
for y = 1:numel(a.YAxis), skip(end+1) = a.YAxis(y).Label; end %#ok<AGROW>
kids = kids(~ismember(kids, skip));
types = get(kids, 'Type');
if ischar(types), types = {types}; end
ok = {'line','scatter','patch','area','bar','errorbar','histogram','stair','text', ...
      'constantline','hggroup','rectangle'};
if any(~ismember(types, ok)), return; end                     % images, surfaces, contours, ...
if numel(a.YAxis) > 1, return; end                             % yyaxis
for dim = 'XY'
    rul = a.([dim 'Axis']);
    if ~isa(rul, 'matlab.graphics.axis.decorator.NumericRuler'), continue; end
    if ~strcmp(a.([dim 'Scale']), 'linear'), continue; end
    if dim == 'X' && any(strcmp(types, 'bar')), continue; end
    lim = a.([dim 'Lim']);
    tol = 1e-9 * diff(lim);
    tv  = a.([dim 'Tick']);
    tv  = tv(tv >= lim(1) - tol & tv <= lim(2) + tol);
    if numel(tv) < 2, continue; end
    if abs(lim(1) - tv(1)) <= tol && abs(lim(2) - tv(end)) <= tol, continue; end
    [lo, hi] = local_range(kids, types, dim, lim);
    if isempty(lo) || lo < tv(1) - tol || hi > tv(end) + tol, continue; end
    a.([dim 'Tick']) = tv;                                     % freeze the ticks first
    a.([dim 'Lim'])  = [tv(1) tv(end)];
    n = n + 1;
end
end

% -----------------------------------------------------------------------------------------
function [lo, hi] = local_range(kids, types, dim, lim)
v = [];
for k = 1:numel(kids)
    h = kids(k);
    switch types{k}
        case {'line', 'scatter', 'stair'}
            v = [v; h.([dim 'Data'])(:)]; %#ok<AGROW>
        case 'patch'
            v = [v; h.([dim 'Data'])(:)]; %#ok<AGROW>
        case 'area'
            v = [v; h.([dim 'Data'])(:)]; %#ok<AGROW>
            if dim == 'Y', v = [v; h.BaseValue]; end %#ok<AGROW>
        case 'bar'
            v = [v; h.YEndPoints(:); h.BaseValue]; %#ok<AGROW>
        case 'errorbar'
            c = h.([dim 'Data'])(:);
            v = [v; c]; %#ok<AGROW>
            ng = h.([dim 'NegativeDelta'])(:); ps = h.([dim 'PositiveDelta'])(:);
            if numel(ng) == numel(c), v = [v; c - ng]; end %#ok<AGROW>
            if numel(ps) == numel(c), v = [v; c + ps]; end %#ok<AGROW>
        case 'histogram'
            if dim == 'X', v = [v; h.BinEdges(:)]; else, v = [v; 0; h.Values(:)]; end %#ok<AGROW>
        case 'rectangle'
            P = h.Position; i = 1 + (dim == 'Y');
            v = [v; P(i); P(i) + P(i + 2)]; %#ok<AGROW>
        case 'text'
            if ~strcmp(h.Units, 'data'), continue; end
            P = h.Position; c = P(1 + (dim == 'Y'));
            if c >= lim(1) && c <= lim(2), v = [v; c]; end %#ok<AGROW>   % only text now inside the box
    end
end
v = v(isfinite(v));
if isempty(v), lo = []; hi = []; return; end
lo = min(v); hi = max(v);
end

% -----------------------------------------------------------------------------------------
function tf = local_is_diverging(cm)
tf = false;
if isempty(cm) || size(cm, 1) < 16, return; end
lab = local_lab(cm);
n = size(cm, 1);
mid = round(n / 3):round(2 * n / 3);
Lmid = max(lab(mid, 1));
if Lmid < lab(1, 1) + 20 || Lmid < lab(end, 1) + 20, return; end
h1 = atan2d(lab(1, 3), lab(1, 2));
h2 = atan2d(lab(end, 3), lab(end, 2));
dh = abs(mod(h1 - h2 + 180, 360) - 180);
tf = dh > 90;
end

function lab = local_lab(rgb)
% sRGB (0-1) to CIELAB, D65.
c = rgb;
lin = c <= 0.04045;
c(lin) = c(lin) / 12.92;
c(~lin) = ((c(~lin) + 0.055) / 1.055) .^ 2.4;
M = [0.4124 0.3576 0.1805; 0.2126 0.7152 0.0722; 0.0193 0.1192 0.9505];
xyz = c * M';
xyz = xyz ./ [0.95047 1.0 1.08883];
f = @(t) (t > (6/29)^3) .* nthroot(t, 3) + (t <= (6/29)^3) .* (t / (3 * (6/29)^2) + 4/29);
F = f(xyz);
lab = [116 * F(:, 2) - 16, 500 * (F(:, 1) - F(:, 2)), 200 * (F(:, 2) - F(:, 3))];
end
