function [r, c] = cp_orient_inv(T, dr, dc)
%CP_ORIENT_INV  Display (row,col) -> native (row,col) under the session view T (see cp_orient).
%
% For clicks: a MATLAB CurrentPoint gives (x,y) = (display column, display row), so call
% cp_orient_inv(T, y, x). Undoes cp_orient_fwd's operations in reverse order.

if isempty(T), r = dr; c = dc; return; end
r = dr;  c = dc;
if T.fl, c = T.Wd + 1 - c; end
if T.fu, r = T.Hd + 1 - r; end
if T.tr, tmp = r;  r = c;  c = tmp; end
end
