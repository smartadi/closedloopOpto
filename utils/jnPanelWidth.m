function pw = jnPanelWidth(cls, ncols, gap)
% JNPANELWIDTH  Panel width (cm) so ncols panels + gaps exactly fill a column class.
%   pw = jnPanelWidth('double', 4)      -> 4.13 cm  (4 across a 2-column figure)
%   pw = jnPanelWidth('double', 3, 0.4) -> custom gap
S = jnStyle(); if nargin < 3 || isempty(gap); gap = S.gap; end
W = jnWidth(cls);
pw = (W - (ncols-1)*gap) / ncols;
end
