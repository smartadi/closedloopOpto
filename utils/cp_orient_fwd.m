function [dr, dc] = cp_orient_fwd(T, r, c)
%CP_ORIENT_FWD  Native (row,col) -> display (row,col) under the session view T (see cp_orient).
%
% Plot with plot(dc, dr) -- display COLUMN is the x axis. Accepts arrays; shape is preserved, so a
% whole grid maps in one call. Exact inverse of cp_orient_inv.

if isempty(T), dr = r; dc = c; return; end
dr = r;  dc = c;
if T.tr, tmp = dr;  dr = dc;  dc = tmp; end     % transpose swaps the two indices
if T.fu, dr = T.Hd + 1 - dr; end
if T.fl, dc = T.Wd + 1 - dc; end
end
