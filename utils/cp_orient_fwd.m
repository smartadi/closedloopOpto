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
if isfield(T,'rot') && T.rot ~= 0               % optional fine rotation, matched to cp_orient_img's imrotate('crop')
    r0 = (T.Hd+1)/2; c0 = (T.Wd+1)/2; ph = T.rot*pi/180;
    x = dc - c0;  y = r0 - dr;                   % math coords (y up), rotate +rot CCW about centre
    xr = x*cos(ph) - y*sin(ph);  yr = x*sin(ph) + y*cos(ph);
    dc = c0 + xr;  dr = r0 - yr;
end
end
