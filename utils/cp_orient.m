function T = cp_orient(mimg, siteRow, siteCol, opts)
%CP_ORIENT  Resolve ONE display transform for a session, and cache it.
%
% THE PROBLEM THIS FIXES. The contra-prediction stack drew brains in two different frames: the ROI
% GUI hardcoded imagesc(mimg.') (transposed -- midline horizontal), while the Stage-1 validation
% map, the Stage-2 affected map and the detector GUI drew mimg natively. You therefore CLICKED in
% one frame and CHECKED in another, with nothing enforcing that they agree. Masks were still
% correct (they are stored native and indexed native), but a mis-oriented drawing surface makes a
% human draw a wrong outline, and that does propagate into every result.
%
% THE CONTRACT. Geometry is ALWAYS native (row,col) -- data is never rotated. One transform per
% session says how a native array is turned into pixels on screen, and every renderer and every
% click inverse goes through that same object:
%     cp_orient_img(T, A)        native image  -> display image
%     cp_orient_fwd(T, r, c)     native (r,c)  -> display (row,col)
%     cp_orient_inv(T, dr, dc)   display       -> native (r,c)
%
% HOW THE VIEW IS CHOSEN. Of the 8 dihedral views, the three degrees of freedom are settled
% separately, and two of them are settled by the data:
%   1. TRANSPOSE (is the midline vertical?) -- OBJECTIVE. For both the native and the transposed
%      image, scan candidate vertical axes and take the best mirror-symmetry correlation between
%      the two halves. The brain is bilaterally symmetric, so the frame in which a strong vertical
%      mirror axis exists is the frame in which the midline runs vertically. This is the same test
%      that settled the AL_0048 bregma question on 2026-08-02 (0.821 at the true midline vs 0.170
%      at the wrong one) -- a decisive margin, not a close call.
%   2. LEFT/RIGHT -- OBJECTIVE, by convention: flip so the hemisphere holding the recording site
%      (= ipsi, the prediction target) lands on the RIGHT of the display, matching the existing
%      "laser site (ipsi, right)" convention in the Stage-1 figure.
%   3. UP/DOWN (anterior up) -- NOT INFERABLE. Controller sessions carry no bregma registration
%      and mirror symmetry is blind to a vertical flip, so nothing in the image distinguishes
%      anterior from posterior. This one costs one keystroke, once per session, and is cached.
%      Anything else would be a guess dressed up as a measurement.
%
% Note the symmetry score CANNOT distinguish flips (a mirror axis survives both flips) -- it only
% separates transposed from not. That is exactly why steps 2 and 3 exist and are handled by rule
% and by eye rather than folded into one score.
%
% INPUTS
%   mimg              [nY x nX] mean image (native)
%   siteRow, siteCol  recording/laser site in NATIVE (row,col); used only for step 2
%   opts  .cache_file (path; loaded when present unless .redefine)  .redefine(false)
%         .confirm(false)  ask accept/flip/rotate/transpose at the console with a preview figure
%         .flip_ud(false)  initial guess for step 3      .verbose(true)
%
% OUTPUT T: .tr .fu .fl (apply in that order: transpose, then flipud, then fliplr)
%           .H .W (native dims) .Hd .Wd (display dims) .sym_native .sym_trans .mid_disp_col
%           .site_disp .created .confirmed

if nargin < 4 || isempty(opts), opts = struct(); end
def = struct('cache_file','', 'redefine',false, 'confirm',false, 'flip_ud',false, 'verbose',true);
fn = fieldnames(def);
for i = 1:numel(fn)
    if ~isfield(opts,fn{i}) || isempty(opts.(fn{i})), opts.(fn{i}) = def.(fn{i}); end
end
[H, W] = size(mimg);

% ---- cached? -------------------------------------------------------------------------------
if ~isempty(opts.cache_file) && exist(opts.cache_file,'file') && ~opts.redefine
    S = load(opts.cache_file,'T');
    if isfield(S,'T') && S.T.H == H && S.T.W == W
        T = S.T;
        if opts.verbose
            fprintf('[cp_orient] loaded view: %s  (sym native %.3f / transposed %.3f)\n', ...
                local_name(T), T.sym_native, T.sym_trans);
        end
        return
    end
    warning('[cp_orient] cached view has different frame dims -- re-resolving.');
end

% ---- step 1: transpose or not, by mirror symmetry --------------------------------------------
A = double(mimg);
[symN, midN] = local_sym(A);
[symT, midT] = local_sym(A.');
tr = symT > symN;
if opts.verbose
    fprintf(['[cp_orient] vertical mirror-symmetry: native %.3f (axis col %d) | transposed %.3f ' ...
             '(axis col %d)  -> midline is %s\n'], symN, midN, symT, midT, ...
            local_tern(tr,'VERTICAL in the TRANSPOSED view','VERTICAL in the NATIVE view'));
    if abs(symT - symN) < 0.05
        fprintf(2,['[cp_orient] ** the two scores are within 0.05 -- the symmetry test is NOT ' ...
                   'decisive here. Check the preview by eye. **\n']);
    end
end

T = struct('tr',tr, 'fu',logical(opts.flip_ud), 'fl',false, 'H',H, 'W',W, ...
           'sym_native',symN, 'sym_trans',symT, 'mid_disp_col',local_tern(tr,midT,midN), ...
           'created','', 'confirmed',false);
T = local_dims(T);

% ---- step 2: put the site's hemisphere on the RIGHT ------------------------------------------
[~, sc] = cp_orient_fwd(T, siteRow, siteCol);
T.fl = sc < T.mid_disp_col;                    % site left of the midline -> mirror horizontally
T = local_dims(T);
[sr2, sc2] = cp_orient_fwd(T, siteRow, siteCol);
T.site_disp = [sr2 sc2];

% ---- step 3: anterior up -- one keystroke, cached --------------------------------------------
if opts.confirm
    T = local_confirm(T, mimg, siteRow, siteCol);
end
T.created = char(datetime('now','Format','yyyy-MM-dd HH:mm'));

if ~isempty(opts.cache_file)
    save(opts.cache_file,'T');
    if opts.verbose, fprintf('[cp_orient] saved view %s -> %s\n', local_name(T), opts.cache_file); end
end
end

% =================================================================================================
function [best, bc] = local_sym(A)
% Best vertical mirror-symmetry correlation over candidate midline columns. Only the CENTRAL band
% is searched and each candidate is scored on the widest symmetric strip it admits, so an axis
% near the edge cannot win on a sliver of image.
[~, W] = size(A);
cols = max(2,round(0.30*W)) : min(W-1, round(0.70*W));
wmin = max(5, round(0.20*W));
best = -Inf;  bc = NaN;
for c0 = cols
    w = min(c0-1, W-c0);
    if w < wmin, continue; end
    L = A(:, c0-w:c0-1);
    R = fliplr(A(:, c0+1:c0+w));
    if std(L(:)) == 0 || std(R(:)) == 0, continue; end
    r = corr(L(:), R(:));
    if r > best, best = r;  bc = c0; end
end
if ~isfinite(best), best = -1; bc = round(W/2); end
end

function T = local_dims(T)
if T.tr, T.Hd = T.W;  T.Wd = T.H;  else, T.Hd = T.H;  T.Wd = T.W; end
end

function T = local_confirm(T, mimg, siteRow, siteCol)
% Preview the proposed view with the detected midline and the site, and let the user fix the one
% degree of freedom the data cannot settle (anterior up).
f = figure('Color','w','Name','cp_orient: confirm the view');
while true
    clf(f); ax = axes(f); %#ok<LAXES>
    D = cp_orient_img(T, mimg);
    imagesc(ax, D); colormap(ax, gray); axis(ax,'image','off'); hold(ax,'on');
    clim(ax, [prctile(D(:),1) max(prctile(D(:),99), prctile(D(:),1)+eps)]);
    xline(ax, T.mid_disp_col, 'c--', 'LineWidth',1.2);
    [sr, sc] = cp_orient_fwd(T, siteRow, siteCol);
    plot(ax, sc, sr, 'g+', 'MarkerSize',15, 'LineWidth',2.5);
    text(ax, 0.02, 0.97, 'is ANTERIOR up?', 'Units','normalized', 'Color','y', ...
        'FontWeight','bold', 'FontSize',11, 'VerticalAlignment','top');
    title(ax, sprintf('%s   (midline cyan, site green +)', local_name(T)), 'FontSize',10);
    drawnow;
    a = lower(strtrim(input('  view: [a]ccept / [f]lip vertical / [h]flip / [t]oggle transpose ? ','s')));
    if isempty(a), a = 'a'; end
    switch a(1)
        case 'a', T.confirmed = true; break
        case 'f', T.fu = ~T.fu;
        case 'h', T.fl = ~T.fl;
        case 't'
            T.tr = ~T.tr;  T = local_dims(T);
            [~, mid] = local_sym(cp_orient_img(struct('tr',T.tr,'fu',false,'fl',false, ...
                'H',T.H,'W',T.W,'Hd',T.Hd,'Wd',T.Wd), mimg));
            T.mid_disp_col = mid;
        otherwise, T.confirmed = true; break
    end
    T = local_dims(T);
end
if isgraphics(f), close(f); end
end

function s = local_name(T)
p = {}; if T.tr, p{end+1} = 'transpose'; end
if T.fu, p{end+1} = 'flipud'; end
if T.fl, p{end+1} = 'fliplr'; end
if isempty(p), s = 'native'; else, s = strjoin(p,'+'); end
end

function v = local_tern(c, a, b)
if c, v = a; else, v = b; end
end
