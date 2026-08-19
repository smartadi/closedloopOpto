function M = cp_roi_masks(mimg, roi_file, prim_row, prim_col, opts)
% cp_roi_masks  Full-brain mask split into contra/ipsi by a hand-drawn midline.
%
% SINGLE SOURCE OF TRUTH for the contra-prediction ROI. On first run (or when
% opts.redefine is set) it draws the FULL-BRAIN outline + 2 MIDLINE points on the
% mean image and caches the geometry. The brain mask is the outline interior AND
% an intensity floor; it is then bisected by the midline. The side that contains
% the primary (recording) pixel is IPSI (the prediction TARGET); the other side is
% CONTRA (the PREDICTOR). No hand-drawn hemisphere polygon, no "everything-else"
% complement.
%
% ORIENTATION (reworked 2026-08-05): pass opts.T -- the session view resolved by
% cp_orient -- and the draw happens in THAT view, the same one every downstream
% figure renders and every click inverts through. Without opts.T the legacy
% hardcoded transpose (imagesc(mimg.')) is used, so existing callers are unchanged.
% Either way the stored geometry is NATIVE (row,col): this function's internal frame
% already had x = native row and y = native col, so (bx,by) meant native (row,col)
% before this change too -- only the picture being clicked on is different, and ROI
% files written either side of the change are interchangeable. Masks come back in
% mimg's native [nY x nX] so find(mask(:)) indexes U/V exactly (U flattened
% column-major over [nY, nX]). The hemisphere split is orientation-robust (signed
% cross product of the midline direction).
%
% INPUT
%   mimg      [nY x nX]  mean image
%   roi_file  char       cache path for the geometry (outline + midline points)
%   prim_row  scalar     primary pixel ROW    (= d.params.pixel(2) = px_prim)
%   prim_col  scalar     primary pixel COLUMN (= d.params.pixel(1) = py_prim)
%   opts (optional): .redefine(false) .thr_pctile(20) .plot(true)
%                    .T([]) session display view from cp_orient; [] = legacy transpose
%                    .draw_overlay([]) function handle @(ax) called on the DRAW axes before
%                        the first click. Use it to put the laser-effect map and the site
%                        markers under your cursor (cp_site_overlay) -- the midline decides
%                        which hemisphere is contra, so the spot must be visible while it is
%                        being clicked. Drawn once; it persists through both steps.
%                    .fig_pos([]) [x y w h] pixels for the draw window, so a caller can park
%                        it beside its own sanity figure.
%                    .name_extra('') appended to the draw window title bar (session tag)
%
% OUTPUT  M: .brain .contra .ipsi (logical [nY x nX]); .bx/.by (outline) and
%            .mx/.my (midline pts) in NATIVE (row,col); .prim_row .prim_col

if nargin < 5 || isempty(opts), opts = struct(); end
if ~isfield(opts,'redefine'),   opts.redefine   = false; end
if ~isfield(opts,'thr_pctile'), opts.thr_pctile = 20;    end
if ~isfield(opts,'plot'),       opts.plot       = true;  end
if ~isfield(opts,'T'),          opts.T          = [];    end   % session display view (cp_orient)
if ~isfield(opts,'draw_overlay'), opts.draw_overlay = []; end  % @(ax) sanity layer on the draw axes
if ~isfield(opts,'fig_pos'),    opts.fig_pos    = [];    end
if ~isfield(opts,'name_extra'), opts.name_extra = '';    end
[nY, nX] = size(mimg);
A = mimg.';                        % transposed display frame: size [nX x nY]
% Primary pixel in the transposed frame: x = column = prim_row, y = row = prim_col.
prim_xA = prim_row;
prim_yA = prim_col;

% opts.T = the session's resolved display view (cp_orient). When supplied, the DRAW happens in
% that view instead of the hardcoded transpose, and the clicks are converted back before storage.
%
% WHY THE STORAGE FORMAT DOES NOT CHANGE. This function's internal frame has x = native ROW and
% y = native COL, so (bx,by) is numerically already native (row,col) -- the "transposed frame" is
% only how those two numbers were being PLOTTED. Converting a click from any view straight to
% native therefore produces exactly the numbers the mask code below already expects, and ROI files
% written before and after this change mean the same thing. Only the picture the human clicked on
% is different. (The opts.plot verification overlay still renders in the legacy transposed frame;
% callers that pass a T draw their own oriented overlay and set plot=false.)

% --- draw or load the geometry (full-brain outline + 2 midline points) ------------
if opts.redefine && exist(roi_file,'file')
    delete(roi_file);
    fprintf('[cp_roi_masks] deleted existing ROI (redefine): %s\n', roi_file);
end
if ~exist(roi_file,'file')
    Dimg = cp_orient_img(opts.T, mimg);          % [] -> unchanged; legacy path draws A below
    if isempty(opts.T), Dimg = A; end
    figd = figure('Color','k','Name', ...
        strtrim(sprintf('cp_roi_masks: draw brain outline + midline  %s', opts.name_extra)));
    if ~isempty(opts.fig_pos), set(figd,'Position',opts.fig_pos); end
    imagesc(Dimg); colormap(figd, gray);
    clim([prctile(Dimg(:),1), prctile(Dimg(:),99)]);
    axis image off; hold on;
    % Sanity layer (laser-effect contours + site markers) goes on BEFORE the first click so the
    % outline and, critically, the midline are drawn with the laser spot in view.
    if ~isempty(opts.draw_overlay)
        try
            opts.draw_overlay(gca);
        catch ovME
            fprintf(2, '[cp_roi_masks] draw_overlay failed (%s) -- drawing without it.\n', ovME.message);
        end
    end
    title({'STEP 1 -- click around the FULL-BRAIN outline', '(many points, then Enter)'}, ...
        'Color','w','FontSize',11,'FontWeight','bold');
    try
        [bx, by] = ginput;                               % transposed-frame (x,y)
    catch ME
        if contains(ME.message,'deletion')
            error('cp_roi_masks: draw window closed before STEP 1 finished -- re-run to redraw.');
        else
            rethrow(ME);
        end
    end
    if numel(bx) < 3, close(figd); error('cp_roi_masks: need >=3 outline points.'); end
    bx = [bx; bx(1)];  by = [by; by(1)];
    plot(bx, by, 'y-', 'LineWidth', 1.5);
    dbx = bx;  dby = by;                          % keep the DISPLAY-frame copy for the overlay
    title('STEP 2 -- click 2 MIDLINE points, then Enter', ...
        'Color','c','FontSize',11,'FontWeight','bold');
    try
        [mx, my] = ginput(2);                            % transposed-frame (x,y)
    catch ME
        if contains(ME.message,'deletion')
            error('cp_roi_masks: draw window closed before STEP 2 finished -- re-run to redraw.');
        else
            rethrow(ME);
        end
    end
    if numel(mx) < 2, close(figd); error('cp_roi_masks: need 2 midline points.'); end
    plot(mx, my, 'c--', 'LineWidth', 1.5);  drawnow; pause(0.4);  close(figd);
    % Display frame -> native (row,col). A MATLAB ginput returns (x,y) = (display col, display
    % row), so the row argument comes second. With no T this is the identity the legacy code
    % already relied on (x = native row, y = native col).
    if ~isempty(opts.T)
        [bx, by] = cp_orient_inv(opts.T, dby, dbx);
        [mx, my] = cp_orient_inv(opts.T, my,  mx);
    end
    frame = 'native_rc';  view_used = opts.T;
    save(roi_file, 'bx','by','mx','my','frame','view_used');
    fprintf('[cp_roi_masks] saved ROI geometry (native row/col): %s\n', roi_file);
else
    t  = load(roi_file, 'bx','by','mx','my');
    bx = t.bx;  by = t.by;  mx = t.mx;  my = t.my;
    fprintf('[cp_roi_masks] loaded ROI geometry: %s\n', roi_file);
end

% --- full-brain mask = inside outline AND above intensity floor (transposed frame) -
[XX, YY] = meshgrid(1:nY, 1:nX);                         % XX=x(col-of-A), YY=y(row-of-A)  [nX x nY]
brainA = inpolygon(XX, YY, bx, by) & (A > prctile(A(:), opts.thr_pctile));

% --- bisect by the midline (orientation-robust signed cross product) --------------
dx = mx(2)-mx(1);  dy = my(2)-my(1);                     % midline direction in (x,y)
signed   = dx*(YY - my(1)) - dy*(XX - mx(1));            % [nX x nY] signed side
sgn_prim = dx*(prim_yA - my(1)) - dy*(prim_xA - mx(1));
sp = sign(sgn_prim);  if sp == 0, sp = 1; end
ipsiA   = brainA & (sign(signed) == sp);                % side with the primary pixel
contraA = brainA & (sign(signed) == -sp);               % the other side

% --- transpose masks back to mimg's native [nY x nX] so find(mask(:)) indexes U/V --
brain  = brainA.';  contra = contraA.';  ipsi = ipsiA.';
M = struct('brain',brain, 'contra',contra, 'ipsi',ipsi, ...
           'bx',bx, 'by',by, 'mx',mx, 'my',my, ...
           'prim_row',prim_row, 'prim_col',prim_col);
fprintf('[cp_roi_masks] brain %d px | contra(predictor) %d | ipsi(target,primary side) %d\n', ...
    nnz(brain), nnz(contra), nnz(ipsi));

% --- verification overlay (transposed frame, same as the draw) --------------------
if opts.plot
    figv = figure('Color','w','Name','cp_roi_masks: verification');
    figv.Units='centimeters'; figv.Position=[0 0 12 10];
    lab = nan(nX,nY);  lab(contraA) = 1;  lab(ipsiA) = 2;
    glo = prctile(A(:),1);  ghi = max(prctile(A(:),99), glo+eps);
    g   = min(max((A - glo)/(ghi - glo), 0), 1);           % transposed brain -> [0,1] grayscale
    image(repmat(g, 1, 1, 3));  axis image off;  hold on;  % brain image in the background
    him = imagesc(lab);  set(him, 'AlphaData', 0.35*double(~isnan(lab)));  % translucent hemisphere tint
    colormap(gca, [0.10 0.45 0.95; 0.95 0.30 0.10]);  clim([1 2]);
    plot(bx, by, 'k-', 'LineWidth', 0.8);
    tt = linspace(-3, 3, 2);
    plot(mx(1)+tt*dx, my(1)+tt*dy, 'k--', 'LineWidth', 1.2);
    % NB: marker only is drawn at the transposed screen position (x<->y) per user
    % display preference; the side test + masks above use (prim_xA,prim_yA) unchanged.
    plot(prim_yA, prim_xA, 'g+', 'MarkerSize', 14, 'LineWidth', 2.5);
    xlim([0.5 nY+0.5]); ylim([0.5 nX+0.5]);
    title('contra (blue) | ipsi = primary side (red) | primary (green +)', ...
        'FontSize', 9, 'FontWeight','bold');
    hold off;
end
end
