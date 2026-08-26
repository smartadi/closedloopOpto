function h = starOffset(ax, x, y, PS, varargin)
%STAROFFSET  Mark a point with a star placed BESIDE it, not on top of it.
%
%   starOffset(ax, x, y, PS) draws a white star offset from (x,y) by a fixed fraction
%   of the axis span, joined to the point by a hairline leader.
%
%   Why not just plot the star at the point: on a cost surface or a cost-coloured
%   trajectory, the marked point IS the result -- and an opaque marker on top of it
%   hides the very colour the panel exists to report (user, 2026-08-19). Offsetting
%   keeps the annotation and the datum both readable.
%
%   OPTIONS (name/value)
%     'dir'   [dx dy] offset direction, in axis-span fractions   default [0.075 0.075]
%     'size'  star MarkerSize                                     default 9
%
%   The offset is computed from the CURRENT axis limits, so call this after the data
%   are plotted. Limits are then frozen, otherwise the star can push them and move
%   itself on the next draw.

p = inputParser;
p.addParameter('dir',  [0.075 0.075]);
p.addParameter('size', 9);
p.parse(varargin{:});
o = p.Results;

xl = xlim(ax);  yl = ylim(ax);
dx = o.dir(1) * diff(xl);
dy = o.dir(2) * diff(yl);

% Flip the offset toward whichever side has room, so the star never lands outside.
if x + dx > xl(2) - 0.02*diff(xl), dx = -dx; end
if y + dy > yl(2) - 0.02*diff(yl), dy = -dy; end

sx = x + dx;  sy = y + dy;
plot(ax, [x sx], [y sy], '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.5, ...
     'HandleVisibility','off');
h = plot(ax, sx, sy, 'p', 'MarkerSize', o.size, ...
         'MarkerFaceColor','w', 'MarkerEdgeColor','k', 'LineWidth', 0.6, ...
         'HandleVisibility','off');
xlim(ax, xl);  ylim(ax, yl);
if nargin < 4 || isempty(PS), return, end     % PS unused for now; kept for style parity
end
