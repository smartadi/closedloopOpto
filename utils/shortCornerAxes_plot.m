function ax = shortCornerAxes_plot(ax, varargin)
% SHORTCORNERAXES_PLOT  Neuroscience-style minimalist corner axes.
%
% Usage:
%   shortCornerAxes_plot(ax)
%   shortCornerAxes_plot(ax, 'Corner',    'bl')       % bl | tl | br | tr
%   shortCornerAxes_plot(ax, 'Frac',      0.15)       % fraction of axis range (fallback)
%   shortCornerAxes_plot(ax, 'XLength',   3)          % bar length in x data units (e.g. 3 s)
%   shortCornerAxes_plot(ax, 'YLength',   2)          % bar length in y data units (e.g. 2 % dF/F)
%   shortCornerAxes_plot(ax, 'LineWidth', 1.5)
%   shortCornerAxes_plot(ax, 'Color',     [0 0 0])
%   shortCornerAxes_plot(ax, 'XLabel',    'Time (s)')
%   shortCornerAxes_plot(ax, 'YLabel',    '\DeltaF/F')
%   shortCornerAxes_plot(ax, 'LabelGap',  0.08)       % fraction of range
%   shortCornerAxes_plot(ax, 'FontSize',  12)
%   shortCornerAxes_plot(ax, 'FontName',  'Arial')
%   shortCornerAxes_plot(ax, 'FontWeight','bold')

% --- handle ax argument ---
if nargin < 1 || isempty(ax)
    ax = gca;
elseif ~ishandle(ax) || ~strcmp(get(ax,'Type'),'axes')
    varargin = [{ax}, varargin];
    ax = gca;
end

% --- parse options ---
p = inputParser;
p.addParameter('Corner',     'bl',    @(s) ischar(s)||isstring(s));
p.addParameter('Frac',       0.15,    @(v) isnumeric(v)&&isscalar(v)&&v>0&&v<0.5);
p.addParameter('XLength',    [],      @(v) isempty(v)||(isnumeric(v)&&isscalar(v)&&v>0));
p.addParameter('YLength',    [],      @(v) isempty(v)||(isnumeric(v)&&isscalar(v)&&v>0));
p.addParameter('LineWidth',  1.5,     @(v) isnumeric(v)&&isscalar(v)&&v>0);
p.addParameter('Color',      [0 0 0], @(v) isnumeric(v)&&numel(v)==3);
p.addParameter('XLabel',     '',      @(s) ischar(s)||isstring(s));
p.addParameter('YLabel',     '',      @(s) ischar(s)||isstring(s));
p.addParameter('LabelGap',   0.08,    @(v) isnumeric(v)&&isscalar(v)&&v>=0);
p.addParameter('FontName',   'Arial', @(s) ischar(s)||isstring(s));
p.addParameter('FontSize',   7,      @(v) isnumeric(v)&&isscalar(v)&&v>0);
p.addParameter('FontWeight', 'bold',  @(s) ischar(s)||isstring(s));
p.parse(varargin{:});
S = p.Results;

corner = lower(string(S.Corner));
f  = S.Frac;
g  = S.LabelGap;

% --- hide default axes box and ticks ---
set(ax, 'Box','off', 'XColor','none', 'YColor','none', ...
        'XTick',[], 'YTick',[], 'Color','none');
try; ax.XLabel.Visible = 'off'; ax.YLabel.Visible = 'off'; catch; end

% --- preserve hold state ---
wasHeld = ishold(ax);
hold(ax, 'on');

% --- read limits then freeze to prevent auto-scaling shifting the corner ---
xl = ax.XLim;
yl = ax.YLim;
ax.XLimMode = 'manual';
ax.YLimMode = 'manual';

xr = diff(xl);
yr = diff(yl);

% --- resolve bar lengths: data-unit overrides Frac ---
xLen = f * xr;
yLen = f * yr;
if ~isempty(S.XLength), xLen = S.XLength; end
if ~isempty(S.YLength), yLen = S.YLength; end

% --- corner geometry in data coordinates ---
% Labels are anchored at the corner point (not centered on the bar).
switch corner
    case "bl"
        x0 = xl(1);  y0 = yl(1);
        xEnd = x0 + xLen;  yEnd = y0 + yLen;
        xLabXY = [x0,  y0 - g*yr];   xHAlign = 'left';
        yLabXY = [x0 - g*xr,  y0];   yHAlign = 'left';   % 'left' → after 90° rot, text goes upward from corner
    case "tl"
        x0 = xl(1);  y0 = yl(2);
        xEnd = x0 + xLen;  yEnd = y0 - yLen;
        xLabXY = [x0,  y0 + g*yr];   xHAlign = 'left';
        yLabXY = [x0 - g*xr,  y0];   yHAlign = 'right';  % 'right' → after 90° rot, text goes downward from corner
    case "br"
        x0 = xl(2);  y0 = yl(1);
        xEnd = x0 - xLen;  yEnd = y0 + yLen;
        xLabXY = [x0,  y0 - g*yr];   xHAlign = 'right';
        yLabXY = [x0 + g*xr,  y0];   yHAlign = 'left';   % 'left' → after 90° rot, text goes upward from corner
    case "tr"
        x0 = xl(2);  y0 = yl(2);
        xEnd = x0 - xLen;  yEnd = y0 - yLen;
        xLabXY = [x0,  y0 + g*yr];   xHAlign = 'right';
        yLabXY = [x0 + g*xr,  y0];   yHAlign = 'right';  % 'right' → after 90° rot, text goes downward from corner
    otherwise
        error('shortCornerAxes_plot: Corner must be bl, tl, br, or tr');
end

% --- draw both lines from the same corner point ---
lw = S.LineWidth;
c  = S.Color;
line(ax, [x0, xEnd], [y0, y0],   'Color',c, 'LineWidth',lw, 'Clipping','off', 'HandleVisibility','off');
line(ax, [x0, x0],   [y0, yEnd], 'Color',c, 'LineWidth',lw, 'Clipping','off', 'HandleVisibility','off');

% --- labels (only placed if non-empty) ---
% Labels start at the corner point: x label is left/right-aligned at the
% corner, y label is bottom/top-aligned at the corner (rotated 90 deg).
baseTxt = {'FontName',S.FontName, 'FontSize',S.FontSize, ...
           'FontWeight',S.FontWeight, 'Color',c, 'Clipping','off'};

if strlength(string(S.XLabel)) > 0
    text(ax, xLabXY(1), xLabXY(2), string(S.XLabel), baseTxt{:}, ...
        'HorizontalAlignment', xHAlign, 'VerticalAlignment', 'middle');
end
if strlength(string(S.YLabel)) > 0
    text(ax, yLabXY(1), yLabXY(2), string(S.YLabel), baseTxt{:}, ...
        'HorizontalAlignment', yHAlign, 'VerticalAlignment', 'middle', 'Rotation', 90);
end

% --- restore hold state ---
if ~wasHeld
    hold(ax, 'off');
end

end
