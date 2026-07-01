function cp_kernel_explorer(matfile, start_sq)
%CP_KERNEL_EXPLORER  Click an ipsi pixel -> see its contra predictive-weight map.
%
%   cp_kernel_explorer(MATFILE, START_SQ) opens in the squared "energy" (w^2) view
%   when START_SQ is true (default false = signed weights). Toggle live with the
%   "squared" checkbox.
%
%   cp_kernel_explorer(MATFILE) opens an interactive figure from the compact rank-K
%   fit products dumped by contra_prediction's [CP-KERNEL] section
%   (cp_kernel_explorer_<sess>.mat in impulse-analysis/data). Click anywhere on the
%   ipsi mean image (left) and the contra predictive-weight map for that pixel's
%   recording footprint is back-projected through the (pixel-agnostic) contra->ipsi
%   field RRR fit and drawn on the right -- ONE matrix-vector product per click.
%
%   The whole tool keeps only the rank-K (=50) truncated products resident (~70 MB);
%   the raw SVD and the pixel x time movie are never loaded, so RAM stays flat no
%   matter how many times you click.
%
%   Controls: a RANK slider (rebuilds the transfer matrix on the fly) and a SQUARED
%   checkbox (sign-agnostic w^2 "energy" view). The green + marks the stored primary
%   pixel; the cyan o marks your last click.
%
%   Debugging the flip: click the stored primary -> focal homotopic hot-spot; click
%   its transpose (swap row/col) -> diffuse. Sweep around to watch the hot-spot track
%   homotopy and decide which orientation is the real recording site.
%
%   Display convention matches cp_roi_masks: imagesc(mimg.') so screen-x = pixel ROW,
%   screen-y = pixel COLUMN.

if nargin < 1 || isempty(matfile)
    error('cp_kernel_explorer: pass the cp_kernel_explorer_<sess>.mat from [CP-KERNEL].');
end
if ~exist(matfile, 'file')
    error('cp_kernel_explorer: file not found: %s', matfile);
end
if nargin < 2 || isempty(start_sq), start_sq = false; end
S = load(matfile);

st      = struct();
st.S    = S;
st.n    = double(min(S.nmap, S.K));
st.sq   = logical(start_sq);
st.T    = local_buildT(S, st.n);
st.xc   = S.px_prim;   % last click (screen coords: x=row, y=col)
st.yc   = S.py_prim;

f = figure('Name','CP kernel explorer','NumberTitle','off','Color','w', ...
           'Units','normalized','Position',[0.07 0.16 0.86 0.66]);
st.axL = axes('Parent',f,'Units','normalized','Position',[0.035 0.13 0.43 0.80]);
st.axR = axes('Parent',f,'Units','normalized','Position',[0.530 0.13 0.43 0.80]);

% left: ipsi mean image, transposed display (screen-x = row, screen-y = col)
imagesc(st.axL, S.mimg.');
colormap(st.axL, gray);  axis(st.axL,'image','off');  hold(st.axL,'on');
plot(st.axL, S.px_prim, S.py_prim, 'g+', 'MarkerSize',12, 'LineWidth',2);
st.clickMark = plot(st.axL, S.px_prim, S.py_prim, 'co', 'MarkerSize',10, 'LineWidth',1.5);
title(st.axL, 'click any pixel   (green + = stored primary)', 'FontWeight','bold','FontSize',9);

% right: RGB composite image (gray brain + red/blue weights), updated per click
st.imR = image(st.axR, zeros(S.nX, S.nY, 3));
axis(st.axR,'image','off');  hold(st.axR,'on');
st.rMark = plot(st.axR, S.px_prim, S.py_prim, 'g+', 'MarkerSize',12, 'LineWidth',2);
st.titR  = title(st.axR, '', 'FontWeight','bold','FontSize',9);

% controls: rank slider + squared toggle
st.lbl = uicontrol(f,'Style','text','Units','normalized','Position',[0.035 0.008 0.115 0.05], ...
        'String',sprintf('rank: %d / %d', st.n, S.K),'FontWeight','bold','BackgroundColor','w');
uicontrol(f,'Style','slider','Units','normalized','Position',[0.155 0.018 0.24 0.03], ...
        'Min',1,'Max',S.K,'Value',st.n, ...
        'SliderStep',[1/(S.K-1) max(1,round(S.K/10))/(S.K-1)], ...
        'Callback',@(src,~) local_onRank(f, src));
uicontrol(f,'Style','checkbox','Units','normalized','Position',[0.42 0.012 0.10 0.05], ...
        'String','squared','Value',double(st.sq),'BackgroundColor','w','FontWeight','bold', ...
        'Callback',@(src,~) local_onSq(f, src));

set(f, 'WindowButtonDownFcn', @(src,~) local_onClick(src));
guidata(f, st);

local_drawMap(f, S.px_prim, S.py_prim);   % initial draw at the stored primary pixel
end

% ----------------------------------------------------------------------------------
function T = local_buildT(S, n)
% T = U_svd_raw_K * diag(1./sd) * h_b(:,1:n) * M1(1:n,:)   [nContra x K]; pixw = T*meanU'
n = max(1, min(round(n), S.K));
W = (1 ./ S.sd_tr(:)) .* (S.h_b_K(:, 1:n) * S.M1(1:n, :));   % [K x K]
T = S.U_svd_raw_K * W;                                       % [nContra x K]
end

% ----------------------------------------------------------------------------------
function local_onClick(f)
st = guidata(f);
cp = get(st.axL, 'CurrentPoint');
xc = cp(1,1);  yc = cp(1,2);
xl = get(st.axL, 'XLim');  yl = get(st.axL, 'YLim');
if xc < xl(1) || xc > xl(2) || yc < yl(1) || yc > yl(2)
    return;   % click landed outside the left image (e.g. on a control)
end
local_drawMap(f, xc, yc);
end

% ----------------------------------------------------------------------------------
function local_onRank(f, src)
st = guidata(f);
st.n = max(1, min(st.S.K, round(get(src, 'Value'))));
st.T = local_buildT(st.S, st.n);
set(st.lbl, 'String', sprintf('rank: %d / %d', st.n, st.S.K));
guidata(f, st);
local_drawMap(f, st.xc, st.yc);
end

% ----------------------------------------------------------------------------------
function local_onSq(f, src)
st = guidata(f);
st.sq = logical(get(src, 'Value'));
guidata(f, st);
local_drawMap(f, st.xc, st.yc);
end

% ----------------------------------------------------------------------------------
function local_drawMap(f, xc, yc)
st = guidata(f);  S = st.S;
st.xc = xc;  st.yc = yc;                       % screen coords: x=row, y=col
row = min(max(round(xc),1), S.nY);
col = min(max(round(yc),1), S.nX);
kk  = S.k_prim;
rr  = (row-kk):(row+kk);  rr = rr(rr>=1 & rr<=S.nY);
cc  = (col-kk):(col+kk);  cc = cc(cc>=1 & cc<=S.nX);
[RR,CC] = ndgrid(rr, cc);
idxk = sub2ind([S.nY, S.nX], RR(:), CC(:));
idxk = intersect(idxk, S.full_idx);
set(st.clickMark, 'XData', row, 'YData', col);
set(st.rMark,     'XData', row, 'YData', col);
if isempty(idxk)
    set(st.imR, 'CData', local_composite(S.mimg.', nan(S.nX, S.nY), st.sq));
    set(st.titR, 'String', sprintf('pixel (r%d,c%d) is OUTSIDE the ipsi field', row, col));
    guidata(f, st);  return;
end
[~, sel] = ismember(idxk, S.full_idx);
meanU = mean(S.U_ipsi_raw_K(sel, :), 1);       % [1 x K]
pixw  = st.T * meanU.';                         % [nContra x 1]
km = nan(S.nY, S.nX);  km(S.idx_contra) = pixw;
set(st.imR, 'CData', local_composite(S.mimg.', km.', st.sq));
if st.sq
    set(st.titR, 'String', sprintf('contra ENERGY (w^2)  |  pixel (r%d,c%d)  |  rank %d', row, col, st.n));
else
    set(st.titR, 'String', sprintf('contra weights  |  pixel (r%d,c%d)  |  rank %d', row, col, st.n));
end
guidata(f, st);
end

% ----------------------------------------------------------------------------------
function rgb = local_composite(mimgT, kmT, sqmode)
% Blend a gray brain background (transposed frame) with a weight overlay.
lo = prctile(mimgT(:), 1);  hi = prctile(mimgT(:), 99);
g  = min(1, max(0, (mimgT - lo) ./ (hi - lo + eps)));
rgb = repmat(g, [1 1 3]);
v   = kmT;
valid = ~isnan(v);
if ~any(valid(:)); return; end
cr = ones(size(v));  cg = ones(size(v));  cb = ones(size(v));
if sqmode
    vv = max(v, 0);  vv(~valid) = 0;
    wl = prctile(v(valid), 99);  if ~isfinite(wl) || wl <= 0; wl = max(vv(:)); end
    if wl <= 0; wl = 1; end
    a = min(1, vv ./ wl);  a(~valid) = 0;
    cg = 1 - 0.9*a;  cb = 1 - 0.9*a;                    % white -> red
else
    wl = prctile(abs(v(valid)), 99);  if ~isfinite(wl) || wl <= 0; wl = 1; end
    a = min(1, abs(v) ./ wl);  a(~valid) = 0;
    pos = v > 0 & valid;  neg = v < 0 & valid;
    cg(pos) = 1 - a(pos);  cb(pos) = 1 - a(pos);        % white -> red
    cr(neg) = 1 - a(neg);  cg(neg) = 1 - a(neg);        % white -> blue
end
A = repmat(a, [1 1 3]);
C = cat(3, cr, cg, cb);
rgb = rgb .* (1 - A) + C .* A;
end
