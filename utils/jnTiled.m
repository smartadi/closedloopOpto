function [fig, tl] = jnTiled(cls, nr, nc, rowH)
% JNTILED  Tiled figure at a JNeurosci column width with tight whitespace.
%   [fig,tl] = jnTiled('double', 1, 4)        % one row of 4 panels, 17.6 cm wide
%   [fig,tl] = jnTiled('double', 2, 3, 3.0)   % 2x3 grid, 3.0 cm per row
% Draw into nexttile(tl); call jnAxes(ax) on each; export with jnExport.
S = jnStyle(); if nargin < 4 || isempty(rowH); rowH = S.rowH; end
W = jnWidth(cls); H = min(nr*rowH, S.H_max);
fig = jnFig(W, H);
tl = tiledlayout(fig, nr, nc, 'TileSpacing','compact', 'Padding','tight');
end
