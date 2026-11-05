function issues = sls_check(fig, varargin)
% SLS_CHECK  Mechanical checks on a finished MATLAB figure, in the Steinmetz Lab style.
% MATLAB port of steinmetzlab_style.check_figure (Anna's lab style repo; see SLS_ROOT).
% It checks mechanics only. Whether the figure supports its claim is not something code
% can decide.
%
%   sls_check(fig)                              % print the issues
%   issues = sls_check(fig, 'MinFontPt', 5)     % struct array: kind, level, where, message
%   sls_check(fig, 'Ignore', {'spine','ticks'}) % skip preference kinds
%
% Run it on the figure at its printed size, after all drawing and styling (after jnAxes /
% jnAxesAll), just before export.
%
% REQUIRED (accuracy and legibility; fix them, cannot be ignored):
%   font-size  text below MinFontPt (default 5 pt; set it from the journal)
%   overlap    two texts overlap (tick-label boxes are ESTIMATED; MATLAB exposes none)
%   opacity    translucent fill with an opaque edge: Illustrator shows a white seam
%   units      a firing rate in Hz (it is spikes/s)
%   colormap   colour-mapped data in a map that is not perceptually linear. MATLAB maps
%              have no names, so this one is MEASURED (CIELAB L*): flagged if lightness
%              rises and falls more than once (jet, hsv), if a diverging map's two ends
%              differ by > 12 L* (bwr-style linear-RGB ramps, turbo), or if lightness
%              strays > 30% from a straight line. Calibrated on matplotlib's maps to
%              reproduce the Python package's name list. Maps < 16 colours are skipped
%              (discrete category palettes).
%   overhang   data drawn past the end of a visible axis line (objects with Clipping off)
%   (clipped   not applicable in MATLAB: R2025b draws a marker whole whenever its centre
%              is inside the limits, under both ClippingStyles -- tested 2026-11-05 --
%              so an edge marker is never cut off as it is in matplotlib)
% PREFERENCES (lab defaults; fix, or ignore with a reason):
%   font-family  not Arial/Helvetica, or the LaTeX interpreter (Computer Modern)
%   spine        axis limits not on the first and last tick (MATLAB axis lines span the
%                limits, so the lab rule "spines end on ticks" means limits = end ticks)
%   ticks        more than MaxTickLabels labelled ticks (default 6)
%   space        empty margin > MaxMarginMM (3 mm), > MaxEmptyFrac (40%) of the canvas
%                outside every panel, or content past the canvas edge (a tight-cropped
%                export such as jnExport then comes out larger than the canvas)
% Not ported: panel-letter alignment (letters go on in Illustrator), colorbar gaps,
% highlight rings. Known limits: rotated tick labels (MATLAB rotates crowded ones) and
% legend/colorbar contents are not in the overlap check; equal-aspect axes (axis
% equal/image) are measured on their Position box, not the shrunken plot box; 3-D views
% skip the geometric checks.
%
% See also SLS_CMAP, SLS_ROOT, JNAXESALL, JNEXPORT.

if nargin < 1 || isempty(fig), fig = gcf; end
p = inputParser;
p.addParameter('MinFontPt', 5);
p.addParameter('MaxTickLabels', 6);
p.addParameter('MaxEmptyFrac', 0.4);
p.addParameter('MaxMarginMM', 3);
p.addParameter('Ignore', {});
p.addParameter('Quiet', false);
p.parse(varargin{:});
o = p.Results;
ign = cellstr(o.Ignore);
blocked = intersect(ign, req_kinds());
if ~isempty(blocked)
    error('sls_check:ignore', '%s are required checks and cannot be ignored.', strjoin(blocked, ', '));
end

drawnow;
G = geom(fig);
axs = findall(fig, 'Type', 'axes');
axs = axs(end:-1:1);                        % creation order, so "axes 1" is the first made
T = collect_texts(fig, axs, G);

issues = empty_issues();
issues = [issues, check_fonts(T, o.MinFontPt)];
issues = [issues, check_overlap(T)];
issues = [issues, check_opacity(fig)];
issues = [issues, check_units(T)];
issues = [issues, check_colormaps(fig, axs)];
issues = [issues, check_overhang(axs, G)];
issues = [issues, check_spines(axs)];
issues = [issues, check_ticks(axs, o.MaxTickLabels)];
issues = [issues, check_space(fig, axs, T, G, o.MaxMarginMM, o.MaxEmptyFrac)];
if ~isempty(issues)
    issues = issues(~ismember({issues.kind}, ign));
    [~, ord] = sort(~strcmp({issues.level}, 'required'));   % stable: required first
    issues = issues(ord);
end

if nargout == 0 || ~o.Quiet
    nreq = sum(strcmp({issues.level}, 'required'));
    fprintf('[sls_check] %d required, %d preference  (min font %g pt, canvas %.2f x %.2f cm)\n', ...
        nreq, numel(issues) - nreq, o.MinFontPt, G.W, G.H);
    for k = 1:numel(issues)
        fprintf('  [%s: %s] %s: %s\n', issues(k).level, issues(k).kind, issues(k).where, issues(k).message);
    end
end
if nargout == 0, clear issues; end
end

% =======================================================================================
function k = req_kinds()
k = {'font-size', 'overlap', 'opacity', 'units', 'colormap', 'clipped', 'overhang'};
end

function I = empty_issues()
I = struct('kind', {}, 'level', {}, 'where', {}, 'message', {});
end

function I = mk(kind, where, msg)
if ismember(kind, req_kinds()), lvl = 'required'; else, lvl = 'preference'; end
I = struct('kind', kind, 'level', lvl, 'where', where, 'message', msg);
end

function G = geom(fig)
u = fig.Units;
fig.Units = 'pixels';      px = fig.Position;
fig.Units = 'centimeters'; cm = fig.Position;
fig.Units = u;
G.pxPerCm = px(3) / cm(3);
G.W = cm(3); G.H = cm(4);
G.ptPerCm = 72 / 2.54;
end

function r = rect_cm(h, G)
% Position rectangle of an axes / legend / colorbar in figure cm, [x y w h].
r = getpixelposition(h, true) / G.pxPerCm;
end

function tf = is2d(ax)
[az, el] = view(ax);
tf = (abs(el - 90) < 1e-6) && (abs(mod(az, 90)) < 1e-6);
end

function tf = on(x)
tf = strcmp(x, 'on') || (islogical(x) && x) || (isa(x, 'matlab.lang.OnOffSwitchState') && x);
end

function s = flat_str(x)
if isstring(x), x = cellstr(x); end
if iscell(x)
    x = strjoin(cellfun(@flat_str, x(:)', 'UniformOutput', false), ' ');
elseif ischar(x) && size(x, 1) > 1
    x = strjoin(cellstr(x), ' ');
elseif isnumeric(x)
    x = num2str(x);
end
s = char(x);
end

function s = short(s, n)
s = regexprep(s, '\s+', ' ');
if numel(s) > n, s = [s(1:n-3) '...']; end
end

function pt = font_pt(h)
if isprop(h, 'FontUnits') && ~strcmp(h.FontUnits, 'points')
    u = h.FontUnits; h.FontUnits = 'points'; pt = h.FontSize; h.FontUnits = u;
else
    pt = h.FontSize;
end
end

function nm = axname(ax, axs)
k = find(axs == ax, 1);
hint = '';
cands = {ax.YLabel, ax.Title, ax.XLabel};
for c = 1:numel(cands)
    s = strtrim(flat_str(cands{c}.String));
    if ~isempty(s), hint = s; break; end
end
if isempty(hint), nm = sprintf('axes %d', k);
else, nm = sprintf('axes %d (%s)', k, short(hint, 24)); end
end

% ---------------------------------------------------------------------------------------
function T = collect_texts(fig, axs, G)
% Every drawn text: str, pt, font, interp, box (figure cm, [] if unknown), est (box is
% estimated), fontchk (run font checks on this item), where.
T = struct('str', {}, 'pt', {}, 'font', {}, 'interp', {}, 'box', {}, 'est', {}, ...
    'fontchk', {}, 'where', {});

% 1) text objects: annotations in axes, axis labels, titles, colorbar labels
tx = findall(fig, 'Type', 'text');
for i = 1:numel(tx)
    t = tx(i);
    s = flat_str(t.String);
    if ~on(t.Visible) || isempty(strtrim(s)), continue; end
    ax = ancestor(t, 'axes');
    if ~isempty(ax)
        if ~label_shown(t, ax), continue; end
    else
        host = t.Parent;
        if isprop(host, 'Visible') && ~on(host.Visible), continue; end
    end
    it = struct('str', s, 'pt', font_pt(t), 'font', t.FontName, 'interp', t.Interpreter, ...
        'box', [], 'est', false, 'fontchk', true, 'where', sprintf('''%s''', short(s, 30)));
    if ~isempty(ax) && is2d(ax)
        it.box = text_box_cm(t, ax, G);
    end
    T(end+1) = it; %#ok<AGROW>
end

% 2) tick labels: one font item per ruler, plus an estimated box per label
for a = 1:numel(axs)
    ax = axs(a);
    if ~on(ax.Visible), continue; end
    [rulers, sides] = ax_rulers(ax);
    tmp = gobjects(0);
    for r = 1:numel(rulers)
        ru = rulers(r);
        if ~on(ru.Visible), continue; end
        labs = cellstr(ru.TickLabels);
        if isempty(labs) || all(cellfun(@(c) isempty(strtrim(c)), labs)), continue; end
        nm = sprintf('%s tick labels of %s', sides{r}(1), axname(ax, axs));
        T(end+1) = struct('str', strjoin(labs(:)', ' '), 'pt', ruler_pt(ru, ax), ...
            'font', ru.FontName, 'interp', ru.TickLabelInterpreter, 'box', [], ...
            'est', false, 'fontchk', true, 'where', nm); %#ok<AGROW>
        if ~is2d(ax) || ~isnumeric(ru.TickValues), continue; end
        if isprop(ru, 'TickLabelRotation') && ru.TickLabelRotation ~= 0, continue; end
        if isempty(tmp)
            tmp = text(ax, 0, 0, '', 'Units', 'centimeters', 'Visible', 'off', ...
                'HandleVisibility', 'off');
        end
        set(tmp, 'FontName', ru.FontName, 'FontSize', ruler_pt(ru, ax), ...
            'FontWeight', ax.FontWeight, 'Interpreter', ru.TickLabelInterpreter);
        boxes = tick_boxes(ax, ru, sides{r}, labs, tmp, G);
        for b = 1:numel(boxes)
            T(end+1) = struct('str', boxes(b).str, 'pt', NaN, 'font', '', 'interp', '', ...
                'box', boxes(b).box, 'est', true, 'fontchk', false, ...
                'where', sprintf('%s tick label ''%s'' of %s', sides{r}(1), short(boxes(b).str, 12), ...
                axname(ax, axs))); %#ok<AGROW>
        end
    end
    if ~isempty(tmp), delete(tmp); end
end

% 3) legends, colorbars, annotation shapes: font + strings only (no box)
for lg = findall(fig, 'Type', 'legend')'
    if ~on(lg.Visible) || isempty(lg.String), continue; end
    T(end+1) = struct('str', flat_str(lg.String), 'pt', font_pt(lg), 'font', lg.FontName, ...
        'interp', lg.Interpreter, 'box', [], 'est', false, 'fontchk', true, ...
        'where', sprintf('legend ''%s''', short(flat_str(lg.String), 24))); %#ok<AGROW>
end
for cb = findall(fig, 'Type', 'colorbar')'
    if ~on(cb.Visible), continue; end
    T(end+1) = struct('str', flat_str(cb.TickLabels), 'pt', font_pt(cb), 'font', cb.FontName, ...
        'interp', cb.TickLabelInterpreter, 'box', [], 'est', false, 'fontchk', true, ...
        'where', 'colorbar tick labels'); %#ok<AGROW>
end
for an = [findall(fig, 'Type', 'textboxshape'); findall(fig, 'Type', 'textarrowshape')]'
    s = flat_str(an.String);
    if ~on(an.Visible) || isempty(strtrim(s)), continue; end
    T(end+1) = struct('str', s, 'pt', font_pt(an), 'font', an.FontName, 'interp', an.Interpreter, ...
        'box', [], 'est', false, 'fontchk', true, 'where', sprintf('annotation ''%s''', short(s, 24))); %#ok<AGROW>
end
end

function tf = label_shown(t, ax)
tf = true;
if t == ax.XLabel
    tf = on(ax.Visible) && on(ax.XAxis.Visible);
elseif t == ax.YLabel
    tf = on(ax.Visible) && any(arrayfun(@(r) on(r.Visible), ax.YAxis));
elseif t == ax.ZLabel
    tf = on(ax.Visible) && ~is2d(ax) && on(ax.ZAxis.Visible);
end
end

function box = text_box_cm(t, ax, G)
% Text extent in figure cm. Units are switched to cm and back (MATLAB does the data/
% normalized conversion, including log and reversed axes).
u = t.Units;
t.Units = 'centimeters'; e = t.Extent; t.Units = u;
r = rect_cm(ax, G);
box = [r(1) + e(1), r(2) + e(2), e(3), e(4)];
end

function [rulers, sides] = ax_rulers(ax)
rulers = ax.XAxis; sides = {['x-' char(ax.XAxisLocation)]};
ys = ax.YAxis;
if numel(ys) == 2
    rulers = [rulers; ys(1); ys(2)]; sides = [sides, {'y-left', 'y-right'}];
else
    rulers = [rulers; ys]; sides = [sides, {['y-' char(ax.YAxisLocation)]}];
end
end

function pt = ruler_pt(ru, ax)
if ~strcmp(ax.FontUnits, 'points')
    u = ax.FontUnits; ax.FontUnits = 'points'; pt = ru.FontSize; ax.FontUnits = u;
else
    pt = ru.FontSize;
end
end

function f = frac_on(ru, v)
lim = double(ru.Limits);
if strcmp(ru.Scale, 'log')
    f = (log10(v) - log10(lim(1))) / (log10(lim(2)) - log10(lim(1)));
else
    f = (v - lim(1)) / (lim(2) - lim(1));
end
if strcmp(ru.Direction, 'reverse'), f = 1 - f; end
end

function B = tick_boxes(ax, ru, side, labs, tmp, G)
% Estimated tick-label INK boxes. Calibrated 2026-11-05 on R2025b by rendering with and
% without tick labels at 600 dpi: the ink of x / y tick labels sits 3.1/2.1 pt (5 pt font),
% 5.2/4.3 pt (6 pt) and 5.5/4.3 pt (7 pt) beyond the outward tick marks; ink is ~0.6x the
% text Extent height and ~0.8 pt narrower than its width. The gaps used here (0.6x / 0.4x
% the font size) sit at or inside the measured ones, so the estimate errs toward missing a
% borderline overlap rather than inventing one.
B = struct('str', {}, 'box', {});
fs = tmp.FontSize;
gx = 0.6 * fs / G.ptPerCm;
gy = 0.4 * fs / G.ptPerCm;
r = rect_cm(ax, G);
vals = double(ru.TickValues);
lim = double(ru.Limits);
tol = 1e-9 * max(abs(diff(lim)), eps);
keep = vals >= min(lim) - tol & vals <= max(lim) + tol;
n = min(numel(vals), numel(labs));
L = ax.TickLength(1) * max(r(3), r(4));
switch ax.TickDir
    case 'out',  tickOut = L;
    case 'both', tickOut = L / 2;
    otherwise,   tickOut = 0;
end
for i = 1:n
    s = strtrim(labs{i});
    if ~keep(i) || isempty(s), continue; end
    tmp.String = labs{i};
    e = tmp.Extent; w = max(e(3) - 0.8 / G.ptPerCm, 0); h = 0.6 * e(4);
    f = frac_on(ru, vals(i));
    switch side
        case 'x-bottom', xc = r(1) + f * r(3); bx = [xc - w/2, r(2) - tickOut - gx - h, w, h];
        case 'x-top',    xc = r(1) + f * r(3); bx = [xc - w/2, r(2) + r(4) + tickOut + gx, w, h];
        case 'y-left',   yc = r(2) + f * r(4); bx = [r(1) - tickOut - gy - w, yc - h/2, w, h];
        case 'y-right',  yc = r(2) + f * r(4); bx = [r(1) + r(3) + tickOut + gy, yc - h/2, w, h];
        otherwise,       continue      % 'origin' axes: skip
    end
    B(end+1) = struct('str', s, 'box', bx); %#ok<AGROW>
end
end

% ---------------------------------------------------------------------------------------
function I = check_fonts(T, minPt)
I = empty_issues();
for k = 1:numel(T)
    if ~T(k).fontchk, continue; end
    if T(k).pt < minPt - 1e-6
        I(end+1) = mk('font-size', T(k).where, sprintf('%g pt is below the %g pt minimum', ...
            T(k).pt, minPt)); %#ok<AGROW>
    end
    if strcmpi(T(k).interp, 'latex')
        I(end+1) = mk('font-family', T(k).where, ...
            'LaTeX interpreter draws in Computer Modern, not Arial; use ''tex'''); %#ok<AGROW>
    elseif ~any(contains(lower(T(k).font), {'arial', 'helvetica', 'liberation sans'}))
        I(end+1) = mk('font-family', T(k).where, sprintf('drawn in %s, not Arial', T(k).font)); %#ok<AGROW>
    end
end
end

function I = check_overlap(T)
I = empty_issues();
idx = find(arrayfun(@(t) ~isempty(t.box), T));
for a = 1:numel(idx)
    for b = a + 1:numel(idx)
        A = T(idx(a)); B = T(idx(b));
        if A.est && B.est && strcmp(A.where, B.where), continue; end
        est = A.est || B.est;
        pad = (0.5 + 0.5 * est) / (72 / 2.54);           % 0.5 pt, 1 pt with an estimate
        if box_overlap(A.box, B.box, pad)
            msg = 'these labels overlap';
            if est, msg = [msg ' (tick-label position estimated)']; end %#ok<AGROW>
            I(end+1) = mk('overlap', sprintf('%s and %s', A.where, B.where), msg); %#ok<AGROW>
        end
    end
end
end

function tf = box_overlap(a, b, pad)
tf = a(1) < b(1) + b(3) - pad && b(1) < a(1) + a(3) - pad && ...
     a(2) < b(2) + b(4) - pad && b(2) < a(2) + a(4) - pad;
end

function I = check_units(T)
I = empty_issues();
for k = 1:numel(T)
    s = T(k).str;
    if T(k).est, continue; end                          % same strings as the ruler item
    if ~isempty(regexp(s, '\<Hz\>', 'once')) && ~isempty(regexpi(s, 'spike|firing|rate', 'once'))
        I(end+1) = mk('units', T(k).where, 'a firing rate is in spikes/s, not Hz'); %#ok<AGROW>
    end
end
end

% ---------------------------------------------------------------------------------------
function I = check_opacity(fig)
I = empty_issues();
objs = findall(fig, '-property', 'FaceAlpha');
for k = 1:numel(objs)
    h = objs(k);
    if ~on(h.Visible) || ~isprop(h, 'EdgeAlpha') || ~isprop(h, 'LineWidth'), continue; end
    fa = alpha_of(h.FaceAlpha, h.FaceColor);
    ea = alpha_of(h.EdgeAlpha, h.EdgeColor);
    if fa > 0 && ea > 0 && h.LineWidth > 0 && abs(fa - ea) > 1e-3
        I(end+1) = mk('opacity', h.Type, sprintf(['fill alpha %.2g differs from edge alpha %.2g; ' ...
            'Illustrator shows a white seam. Set ''EdgeColor'',''none'' (draw the edge as a ' ...
            'separate line), or use an opaque, pre-blended fill'], fa, ea)); %#ok<AGROW>
    end
end
for h = findall(fig, 'Type', 'scatter')'
    if ~on(h.Visible), continue; end
    fa = alpha_of(h.MarkerFaceAlpha, h.MarkerFaceColor);
    ea = alpha_of(h.MarkerEdgeAlpha, h.MarkerEdgeColor);
    if fa > 0 && ea > 0 && h.LineWidth > 0 && abs(fa - ea) > 1e-3
        I(end+1) = mk('opacity', 'scatter', sprintf(['marker fill alpha %.2g differs from edge ' ...
            'alpha %.2g; Illustrator shows a white seam'], fa, ea)); %#ok<AGROW>
    end
end
end

function a = alpha_of(alpha, col)
if (ischar(col) || isstring(col)) && strcmpi(col, 'none')
    a = 0;
elseif isnumeric(alpha)
    a = double(alpha);
else
    a = NaN;                                            % 'flat'/'interp': per-vertex, skip
end
end

% ---------------------------------------------------------------------------------------
function I = check_colormaps(fig, axs)
I = empty_issues();
for a = 1:numel(axs)
    ax = axs(a);
    if ~uses_cmap(ax), continue; end
    msg = cmap_problem(ax.Colormap);
    if ~isempty(msg)
        I(end+1) = mk('colormap', axname(ax, axs), msg); %#ok<AGROW>
    end
end
for hm = findall(fig, 'Type', 'heatmap')'
    msg = cmap_problem(hm.Colormap);
    if ~isempty(msg), I(end+1) = mk('colormap', 'heatmap', msg); end %#ok<AGROW>
end
end

function tf = uses_cmap(ax)
tf = false;
kids = findobj(ax, '-depth', 1);
for k = 2:numel(kids)                                    % kids(1) is ax
    h = kids(k);
    if ~on(h.Visible), continue; end
    switch h.Type
        case 'image'
            tf = size(h.CData, 3) == 1 && ~isempty(h.CData);
        case 'surface'
            tf = ~isempty(h.CData) && size(h.CData, 3) == 1 && ...
                (any(strcmp(h.FaceColor, {'flat', 'interp', 'texturemap'})) || ...
                 any(strcmp(h.EdgeColor, {'flat', 'interp'})));
        case 'patch'
            tf = any(strcmp(h.FaceColor, {'flat', 'interp'})) && ...
                ((~isempty(h.FaceVertexCData) && size(h.FaceVertexCData, 2) == 1) || ...
                 (~isempty(h.CData) && size(h.CData, 3) == 1));
        case 'scatter'
            tf = isnumeric(h.CData) && size(h.CData, 2) == 1 && numel(h.CData) > 1;
        case 'contour'
            tf = true;
    end
    if tf, return; end
end
end

function msg = cmap_problem(cm)
% Perceptual linearity from CIELAB lightness. Thresholds calibrated on matplotlib's
% maps (2026-11-05) to reproduce steinmetzlab_style's list of non-linear maps.
msg = '';
if size(cm, 1) < 16, return; end
L = lstar(cm);
[shape, segs] = lightness_shape(L);
if strcmp(shape, 'multi')
    msg = sprintf(['lightness rises and falls more than once (L* %.0f-%.0f), which draws edges ' ...
        'that are not in the data; use parula/viridis for sequential data or ' ...
        'sls_cmap(''diverging'') for diverging data'], min(L), max(L));
    return
end
dev = 0;
for s = 1:numel(segs)
    x = segs{s}; line = linspace(x(1), x(end), numel(x))';
    dev = max(dev, max(abs(x - line)) / max(abs(x(end) - x(1)), 1e-9));
end
if strcmp(shape, 'div') && abs(L(1) - L(end)) > 12
    msg = sprintf(['the two ends differ in lightness (L* %.0f vs %.0f), so equal deviations ' ...
        'from the centre look unequal (e.g. a linear-RGB blue-white-red); use ' ...
        'sls_cmap(''diverging'')'], L(1), L(end));
elseif dev > 0.30
    msg = sprintf(['lightness changes unevenly (up to %.0f%% off a straight line); use a ' ...
        'perceptually linear map'], 100 * dev);
end
end

function [shape, segs] = lightness_shape(L, tol)
if nargin < 2, tol = 1.0; end
L = L(:); n = numel(L);
if mono_ok(L, tol), shape = 'seq'; segs = {L}; return; end
[~, k] = max(abs(L - (L(1) + L(end)) / 2));
if k > 3 && k < n - 2 && mono_ok(L(1:k), tol) && mono_ok(L(k:end), tol)
    shape = 'div'; segs = {L(1:k), L(k:end)};
else
    shape = 'multi'; segs = {};
end
end

function tf = mono_ok(x, tol)
d = diff(x); s = sign(x(end) - x(1)); if s == 0, s = 1; end
tf = sum(max(-s * d, 0)) <= tol;
end

function L = lstar(rgb)
c = double(rgb(:, 1:3));
lo = c <= 0.04045;
c(lo) = c(lo) / 12.92; c(~lo) = ((c(~lo) + 0.055) / 1.055) .^ 2.4;
Y = c * [0.2126; 0.7152; 0.0722];
f = Y; big = Y > (6/29)^3;
f(big) = nthroot(Y(big), 3); f(~big) = Y(~big) / (3 * (6/29)^2) + 4/29;
L = 116 * f - 16;
end

% ---------------------------------------------------------------------------------------
function I = check_overhang(axs, G)
% Only objects with Clipping 'off' can draw past the limits in MATLAB.
I = empty_issues();
TOL_PT = 0.5;
for a = 1:numel(axs)
    ax = axs(a);
    if ~on(ax.Visible) || ~is2d(ax) || ~isnumeric(ax.XAxis.Limits), continue; end
    r = rect_cm(ax, G) * G.ptPerCm;
    xr = ax.XAxis; yr = ax.YAxis(1);
    xvis = on(xr.Visible); yvis = on(yr.Visible) && isnumeric(yr.Limits);
    worst = 0; n = 0;
    kids = findobj(ax, '-depth', 1);
    for k = 2:numel(kids)
        h = kids(k);
        if any(strcmp(h.Type, {'text', 'light', 'constantline'})) || ~isprop(h, 'Clipping'), continue; end
        if ~on(h.Visible) || on(h.Clipping), continue; end
        [X, Y] = drawn_xy(h);
        X = X(isfinite(X)); Y = Y(isfinite(Y));
        over = 0;
        if xvis && ~isempty(X)
            f = frac_on(xr, X); over = max([over, -min(f) * r(3), (max(f) - 1) * r(3)]);
        end
        if yvis && ~isempty(Y)
            f = frac_on(yr, Y); over = max([over, -min(f) * r(4), (max(f) - 1) * r(4)]);
        end
        if over > TOL_PT, n = n + 1; worst = max(worst, over); end
    end
    if n
        I(end+1) = mk('overhang', axname(ax, axs), sprintf(['%d element(s) with Clipping off extend ' ...
            'up to %.1f pt past the end of an axis line; extend the limits (and end ticks) to ' ...
            'cover the data, or keep bands and reference lines inside the axes'], n, worst)); %#ok<AGROW>
    end
end
end

function [X, Y] = drawn_xy(h)
X = []; Y = [];
switch h.Type
    case 'errorbar'
        X = double(h.XData(:)); Y = double(h.YData(:));
        if ~isempty(h.YNegativeDelta), Y = [Y; Y - double(h.YNegativeDelta(:))]; end
        if ~isempty(h.YPositiveDelta), Y = [Y; double(h.YData(:)) + double(h.YPositiveDelta(:))]; end
    case 'bar'
        X = double(h.XEndPoints(:)); Y = [double(h.YEndPoints(:)); h.BaseValue];
    case 'histogram'
        X = double(h.BinEdges(:)); Y = [0; double(h.Values(:))];
    otherwise
        if isprop(h, 'XData') && isnumeric(h.XData), X = double(h.XData(:)); end
        if isprop(h, 'YData') && isnumeric(h.YData), Y = double(h.YData(:)); end
end
end

% ---------------------------------------------------------------------------------------
function I = check_spines(axs)
I = empty_issues();
for a = 1:numel(axs)
    ax = axs(a);
    if ~on(ax.Visible) || ~is2d(ax) || ~isempty(findobj(ax, '-depth', 1, 'Type', 'image')), continue; end
    [rulers, sides] = ax_rulers(ax);
    for r = 1:numel(rulers)
        ru = rulers(r);
        if ~on(ru.Visible) || ~isnumeric(ru.TickValues), continue; end
        lim = double(ru.Limits);
        tol = 1e-6 * abs(diff(lim));
        t = sort(double(ru.TickValues));
        t = t(t >= lim(1) - tol & t <= lim(2) + tol);
        if numel(t) < 2, continue; end
        if abs(lim(1) - t(1)) > tol || abs(lim(2) - t(end)) > tol
            I(end+1) = mk('spine', sprintf('%s %s', axname(ax, axs), sides{r}), sprintf(['axis line ' ...
                'runs %g to %g but the ticks run %g to %g; set the limits to the end ticks'], ...
                lim(1), lim(2), t(1), t(end))); %#ok<AGROW>
        end
    end
end
end

function I = check_ticks(axs, maxLabels)
I = empty_issues();
for a = 1:numel(axs)
    ax = axs(a);
    if ~on(ax.Visible), continue; end
    [rulers, sides] = ax_rulers(ax);
    for r = 1:numel(rulers)
        ru = rulers(r);
        if ~on(ru.Visible) || ~isnumeric(ru.TickValues), continue; end
        lim = double(ru.Limits); v = double(ru.TickValues); labs = cellstr(ru.TickLabels);
        m = min(numel(v), numel(labs));
        nlab = sum(v(1:m) >= min(lim) & v(1:m) <= max(lim) & ~cellfun(@(c) isempty(strtrim(c)), labs(1:m))');
        if nlab > maxLabels
            I(end+1) = mk('ticks', sprintf('%s %s', axname(ax, axs), sides{r}), sprintf(['%d labelled ' ...
                'ticks; use fewer, or label only the ends when the divisions are obvious'], nlab)); %#ok<AGROW>
        end
    end
end
end

function I = check_space(fig, axs, T, G, maxMarginMM, maxEmpty)
I = empty_issues();
boxes = zeros(0, 4);
for a = 1:numel(axs)
    ax = axs(a);
    r = rect_cm(ax, G);
    ti = [0 0 0 0];
    try
        u = ax.Units; ax.Units = 'centimeters'; ti = ax.TightInset; ax.Units = u;
    catch
    end
    boxes(end+1, :) = [r(1) - ti(1), r(2) - ti(2), r(3) + ti(1) + ti(3), r(4) + ti(2) + ti(4)]; %#ok<AGROW>
end
for h = [findall(fig, 'Type', 'legend'); findall(fig, 'Type', 'colorbar')]'
    if on(h.Visible), boxes(end+1, :) = rect_cm(h, G); end %#ok<AGROW>
end
mask_boxes = boxes;
for k = 1:numel(T)
    if ~isempty(T(k).box), boxes(end+1, :) = T(k).box; end %#ok<AGROW>
end
if isempty(boxes), return; end
x0 = min(boxes(:, 1)); y0 = min(boxes(:, 2));
x1 = max(boxes(:, 1) + boxes(:, 3)); y1 = max(boxes(:, 2) + boxes(:, 4));
margins = struct('left', x0, 'right', G.W - x1, 'bottom', y0, 'top', G.H - y1);
for side = fieldnames(margins)'
    mm = 10 * margins.(side{1});
    if mm > maxMarginMM
        I(end+1) = mk('space', [side{1} ' margin'], sprintf(['%.1f mm empty; grow the panels or ' ...
            'shrink the figure'], mm)); %#ok<AGROW>
    elseif mm < -0.2
        I(end+1) = mk('space', [side{1} ' edge'], sprintf(['content runs %.1f mm past the canvas; ' ...
            'a tight-cropped export (jnExport) comes out larger than the canvas (jn_fit_canvas ' ...
            'fixes this)'], -mm)); %#ok<AGROW>
    end
end
n = 200; M = false(n);
for k = 1:size(mask_boxes, 1)
    b = mask_boxes(k, :);
    c0 = max(1, floor(b(1) / G.W * n) + 1); c1 = min(n, ceil((b(1) + b(3)) / G.W * n));
    r0 = max(1, floor(b(2) / G.H * n) + 1); r1 = min(n, ceil((b(2) + b(4)) / G.H * n));
    if c1 >= c0 && r1 >= r0, M(r0:r1, c0:c1) = true; end
end
empty = 1 - mean(M(:));
if empty > maxEmpty
    I(end+1) = mk('space', 'figure', sprintf(['%.0f%% of the canvas is outside every panel; look ' ...
        'for gaps the panels could grow into'], 100 * empty));
end
end
