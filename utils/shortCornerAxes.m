function ax = shortCornerAxes(ax, varargin)
%SHORTCORNERAXES Draw minimalist "neuroscience-style" short corner axes.
%
% Usage:
%   shortCornerAxes();                          % applies to gca
%   shortCornerAxes(gca);                       % apply to specific axes
%   shortCornerAxes(gca,'Corner','bl');         % bottom-left (default)
%   shortCornerAxes(gca,'Corner','tl');         % top-left
%   shortCornerAxes(gca,'Corner','br');         % bottom-right
%   shortCornerAxes(gca,'Corner','tr');         % top-right
%   shortCornerAxes(gca,'Frac',0.10);           % axis length fraction
%   shortCornerAxes(gca,'LineWidth',1.2);       % corner line width
%   shortCornerAxes(gca,'Color',[0 0 0]);       % corner color
%   shortCornerAxes(gca,'XLabel','Time (s)','YLabel','\DeltaF/F'); % labels
%   shortCornerAxes(gca,'ShowLabels',false);    % default true if labels given
%
% Notes:
% - Hides built-in axes lines and ticks, then draws short L-shaped corner axes.
% - If you want labels, this function places them manually (since axes are hidden).
% - Call after setting xlim/ylim for best results.

% --------- handle inputs ----------
if nargin < 1 || isempty(ax)
    ax = gca;
elseif ~ishandle(ax) || ~strcmp(get(ax,'Type'),'axes')
    % If user passed something else as first arg, treat it as varargin
    varargin = [{ax} varargin];
    ax = gca;
end

p = inputParser;
p.addParameter('Corner','bl', @(s)ischar(s)||isstring(s));
p.addParameter('Frac',0.12, @(v)isnumeric(v)&&isscalar(v)&&v>0&&v<1);
p.addParameter('LineWidth',1.4, @(v)isnumeric(v)&&isscalar(v)&&v>0);
p.addParameter('Color',[0 0 0], @(v)isnumeric(v)&&numel(v)==3);
p.addParameter('XLabel','', @(s)ischar(s)||isstring(s));
p.addParameter('YLabel','', @(s)ischar(s)||isstring(s));
p.addParameter('ShowLabels',[], @(v)islogical(v)&&isscalar(v) || isempty(v));
p.addParameter('LabelOffset',0.08, @(v)isnumeric(v)&&isscalar(v)&&v>=0&&v<0.5);
p.addParameter('FontName','Arial', @(s)ischar(s)||isstring(s));
p.addParameter('FontSize',12, @(v)isnumeric(v)&&isscalar(v)&&v>0);
p.addParameter('FontWeight','bold', @(s)ischar(s)||isstring(s));
p.parse(varargin{:});
S = p.Results;

corner = lower(string(S.Corner));
frac   = S.Frac;

% If ShowLabels unspecified: show only if at least one label is provided
if isempty(S.ShowLabels)
    showLabels = ~(strlength(string(S.XLabel))==0 && strlength(string(S.YLabel))==0);
else
    showLabels = S.ShowLabels;
end

% --------- preserve hold state ----------
holdWasOn = ishold(ax);
hold(ax,'on');

% --------- hide built-in axes/ticks ----------
set(ax, ...
    'Box','off', ...
    'XColor','none', ...
    'YColor','none', ...
    'TickDir','out', ...
    'XTick',[], ...
    'YTick',[], ...
    'Color','none');

% Also hide default labels (we'll add manual ones if requested)
try
    ax.XLabel.Visible = 'off';
    ax.YLabel.Visible = 'off';
catch
    % Older versions may not expose Visible on labels in the same way; ignore
end

% --------- compute corner geometry in data units ----------
xl = xlim(ax);
yl = ylim(ax);
dx = frac * (xl(2)-xl(1));
dy = frac * (yl(2)-yl(1));

% Choose corner anchor and directions
switch corner
    case "bl" % bottom-left
        x0 = xl(1); y0 = yl(1);
        x1 = x0 + dx; y1 = y0;
        x2 = x0;      y2 = y0 + dy;
        xlabPos = [mean([x0 x1]), y0 - S.LabelOffset*(yl(2)-yl(1))];
        ylabPos = [x0 - S.LabelOffset*(xl(2)-xl(1)), mean([y0 y2])];
        yRot = 90;
    case "tl" % top-left
        x0 = xl(1); y0 = yl(2);
        x1 = x0 + dx; y1 = y0;
        x2 = x0;      y2 = y0 - dy;
        xlabPos = [mean([x0 x1]), y0 + S.LabelOffset*(yl(2)-yl(1))];
        ylabPos = [x0 - S.LabelOffset*(xl(2)-xl(1)), mean([y0 y2])];
        yRot = 90;
    case "br" % bottom-right
        x0 = xl(2); y0 = yl(1);
        x1 = x0 - dx; y1 = y0;
        x2 = x0;      y2 = y0 + dy;
        xlabPos = [mean([x0 x1]), y0 - S.LabelOffset*(yl(2)-yl(1))];
        ylabPos = [x0 + S.LabelOffset*(xl(2)-xl(1)), mean([y0 y2])];
        yRot = 90;
    case "tr" % top-right
        x0 = xl(2); y0 = yl(2);
        x1 = x0 - dx; y1 = y0;
        x2 = x0;      y2 = y0 - dy;
        xlabPos = [mean([x0 x1]), y0 + S.LabelOffset*(yl(2)-yl(1))];
        ylabPos = [x0 + S.LabelOffset*(xl(2)-xl(1)), mean([y0 y2])];
        yRot = 90;
    otherwise
        error('Corner must be one of: bl, tl, br, tr');
end
% --------- draw corner lines ----------
plot(ax, [x0 x1], [y0 y1], 'Color',S.Color, 'LineWidth',S.LineWidth, 'Clipping','off', 'HandleVisibility','off');
plot(ax, [x0 x2], [y0 y2], 'Color',S.Color, 'LineWidth',S.LineWidth, 'Clipping','off', 'HandleVisibility','off');

% --------- manual labels (optional) ----------
if showLabels
    if strlength(string(S.XLabel))>0
        text(ax, xlabPos(1), xlabPos(2), string(S.XLabel), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontName',S.FontName, ...
            'FontSize',S.FontSize, ...
            'FontWeight',S.FontWeight, ...
            'Color',S.Color, ...
            'Clipping','off');
    end
    if strlength(string(S.YLabel))>0
        text(ax, ylabPos(1), ylabPos(2), string(S.YLabel), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'Rotation',yRot, ...
            'FontName',S.FontName, ...
            'FontSize',S.FontSize, ...
            'FontWeight',S.FontWeight, ...
            'Color',S.Color, ...
            'Clipping','off');
    end
end

% --------- restore hold state ----------
if ~holdWasOn
    hold(ax,'off');
end
end
