function ctrl_mpc_wb_export(sess, nSpot, nSV)
%CTRL_MPC_WB_EXPORT  Whole-brain input for the ARX forecaster: ~100 evenly spaced spots on the brain
%   mask, their dF/F time series on the controller's frame clock (d.timeBlue = data.dFk frames).
%   SVD: cp_loadUVt (hemo-corrected corr/ V when present -- parity with the impulse + Stage-2 pipeline).
%   Mask: the session's cached brain outline (cp_roi2_ctrl_<tag>.mat via cp_roi_masks, contra | ipsi),
%   in the session's cached display orientation (cp_orient). Spots: square grid, spacing chosen so
%   ~nSpot grid nodes fall inside the mask; each spot = mean over a 5x5 px box. Signal per spot =
%   (U_box * V) / mimg_box * 100 (mean-image dF/F; SVD V is already mean-subtracted).
% OUT  data/ctrl_mpc_wb_in_<sess>_n<nSpot>.mat (v7): X [T x nSpot] on timeBlue, rc [nSpot x 2] (native row,col),
%      mask, mimg, site_rc (laser), dist_mm-free distance in px from the laser site.
if nargin < 1, sess = 'AL_0033_0226_e2'; end
if nargin < 2, nSpot = 100; end
if nargin < 3, nSV = 200; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
F3 = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)), 'P');
Z = load(fullfile(here,'..','data',F3.P.rawFile), 'd'); dz = Z.d;
tk = regexp(sess, '(AL_\d+)_(\d\d)(\d\d)_e(\d+)', 'tokens', 'once');
td = sprintf('2025-%s-%s', tk{2}, tk{3}); en = str2double(tk{4});
sr = expPath(tk{1}, td, en);
[U, V, tsvd, mimg] = cp_loadUVt(sr, nSV, dz.timeBlue);
V = double(V); [nY, nX, ~] = size(U);
fprintf('[WB-EXP] %s | SVD %dx%d x %d SV | %d frames | corr V: %d\n', sess, nY, nX, size(U,3), size(V,2), ...
    exist(fullfile(sr,'corr','svdTemporalComponents_corr.npy'),'file') > 0);

st = load(fullfile(dataDir, sprintf('cp_stim_site_ctrl_%s.mat', sess)));  site = double(st.rowcol);
T0 = cp_orient(mimg, site(1), site(2), struct('cache_file', fullfile(dataDir, sprintf('cp_orient_ctrl_%s.mat', sess)), ...
               'redefine', false, 'confirm', false));
Mk = cp_roi_masks(mimg, fullfile(dataDir, sprintf('cp_roi2_ctrl_%s.mat', sess)), site(1), site(2), ...
                  struct('redefine', false, 'thr_pctile', 20, 'plot', false, 'T', T0));
mask = logical(Mk.contra) | logical(Mk.ipsi);
mask = imerode(mask, strel('disk', 3));                          % keep spot boxes off the edge

% grid spacing -> ~nSpot nodes inside the mask
[rr, cc] = find(mask); best = inf;
for s = 3:0.25:60
    gr = min(rr):s:max(rr); gc = min(cc):s:max(cc);
    [G1, G2] = ndgrid(round(gr), round(gc)); in = mask(sub2ind(size(mask), G1(:), G2(:)));
    if abs(nnz(in) - nSpot) < best, best = abs(nnz(in) - nSpot); sp = s; rc = [G1(in) G2(in)]; end
end
fprintf('[WB-EXP] grid spacing %.2f px -> %d spots in mask\n', sp, size(rc,1));

Uf = reshape(U, nY*nX, []); h = 2; X = zeros(size(rc,1), size(V,2));
for i = 1:size(rc,1)
    [b1, b2] = ndgrid(max(1,rc(i,1)-h):min(nY,rc(i,1)+h), max(1,rc(i,2)-h):min(nX,rc(i,2)+h));
    ix = sub2ind([nY nX], b1(:), b2(:));
    X(i,:) = (mean(Uf(ix,:),1) * V) / mean(mimg(ix)) * 100;
end
tb = dz.timeBlue(:); tsvd = tsvd(:); n = min(numel(tsvd), size(X,2));
Xt = interp1(tsvd(1:n), X(:,1:n).', tb, 'linear', 'extrap');      % onto the dFk frame clock
dist_px = hypot(rc(:,1) - site(1), rc(:,2) - site(2));
fprintf('[WB-EXP] frame-clock offset: svd %d vs timeBlue %d frames; median |dt| %.2f ms\n', ...
    numel(tsvd), numel(tb), 1000*median(abs(diff(tsvd(1:min(end,1000))))));
S = struct('X', Xt, 'rc', rc, 'mask', mask, 'mimg', mimg, 'site_rc', site, 'dist_px', dist_px, ...
           'spacing_px', sp, 'nSV', size(U,3), 'sess', sess);
save(fullfile(dataDir, sprintf('ctrl_mpc_wb_in_%s_n%d.mat', sess, nSpot)), '-struct', 'S', '-v7');
end
