function ctrl_lu_regions_export(sess, nSV)
%CTRL_LU_REGIONS_EXPORT  Region-average signals for a Lu et al. (2025, arXiv:2510.18037) replication.
%   They forecast pixel-averaged activity in 4 CCF regions (SS, MO, VIS, RSP) from the hemo-corrected
%   SVD reconstruction at 35 Hz. Controller sessions carry NO bregma/CCF registration (cp_orient), so
%   the regions here are ANATOMICAL APPROXIMATIONS on the brain mask of the stimulated (ipsi)
%   hemisphere, in the session's confirmed display orientation (anterior up, ipsi on the right):
%     MO  anterior 40 % of rows, medial half      SS  rows 20-65 %, lateral half
%     RSP posterior 45 % of rows, medial 30 %     VIS posterior 35 % of rows, lateral 70 %
%   Signal = mean over region pixels of (U*V) / mean(mimg over region) * 100 (mean-image dF/F),
%   interpolated onto the controller frame clock (timeBlue), same as ctrl_mpc_wb_export.
% OUT  data/ctrl_lu_regions_<sess>.mat (v7): R [T x 8] (4 ipsi + 4 mirrored contra), names, masks [nY x nX x 4]
if nargin < 1, sess = 'AL_0033_0226_e2'; end
if nargin < 2, nSV = 200; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
F3 = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)), 'P');
Z = load(fullfile(here,'..','data',F3.P.rawFile), 'd'); dz = Z.d;
tk = regexp(sess, '(AL_\d+)_(\d\d)(\d\d)_e(\d+)', 'tokens', 'once');
sr = expPath(tk{1}, sprintf('2025-%s-%s', tk{2}, tk{3}), str2double(tk{4}));
[U, V, tsvd, mimg] = cp_loadUVt(sr, nSV, dz.timeBlue);
V = double(V); [nY, nX, ~] = size(U);
st = load(fullfile(dataDir, sprintf('cp_stim_site_ctrl_%s.mat', sess))); site = double(st.rowcol);
T0 = cp_orient(mimg, site(1), site(2), struct('cache_file', fullfile(dataDir, sprintf('cp_orient_ctrl_%s.mat', sess)), ...
               'redefine', false, 'confirm', false));
Mk = cp_roi_masks(mimg, fullfile(dataDir, sprintf('cp_roi2_ctrl_%s.mat', sess)), site(1), site(2), ...
                  struct('redefine', false, 'thr_pctile', 20, 'plot', false, 'T', T0));
ipsiD = cp_orient_img(T0, logical(Mk.ipsi));                      % work in display frame (anterior up)
[rr, cc] = find(ipsiD);
r0 = min(rr); r1 = max(rr); fr = @(a, b) (1:size(ipsiD,1)).' >= r0 + a*(r1-r0) & (1:size(ipsiD,1)).' <= r0 + b*(r1-r0);
med = T0.mid_disp_col; lat = max(abs(cc - med)); dc = abs((1:size(ipsiD,2)) - med) / lat;   % 0 = midline, 1 = lateral edge
fc = @(a, b) dc >= a & dc <= b;
names = {'MO','SS','RSP','VIS','MO_c','SS_c','RSP_c','VIS_c'};   % _c = mirror box on the contra (unstimulated) hemisphere
boxes = {fr(0,0.40) & fc(0,0.5), fr(0.20,0.65) & fc(0.5,1), fr(0.55,1) & fc(0,0.3), fr(0.65,1) & fc(0.3,1)};
contraD = cp_orient_img(T0, logical(Mk.contra));
Uf = reshape(U, nY*nX, []); Xr = zeros(8, size(V,2)); masks = false(nY, nX, 8);
for i = 1:8
    if i <= 4, mD = ipsiD & boxes{i}; else, mD = contraD & boxes{i-4}; end   % dc is |distance from midline| -> mirror
    [dr, dcol] = find(mD); [nr, ncl] = cp_orient_inv(T0, dr, dcol);    % back to native indices
    m = false(nY, nX); m(sub2ind([nY nX], nr, ncl)) = true; masks(:,:,i) = m;
    ix = find(m);
    Xr(i,:) = (mean(Uf(ix,:),1) * V) / mean(mimg(ix)) * 100;
    fprintf('[LU-REG] %s: %d px\n', names{i}, numel(ix));
end
tb = dz.timeBlue(:); tsvd = tsvd(:); n = min(numel(tsvd), size(Xr,2));
R = interp1(tsvd(1:n), Xr(:,1:n).', tb, 'linear', 'extrap');
f = figure('Visible','off','Color','w'); imagesc(cp_orient_img(T0, mimg)); colormap gray; axis image off; hold on
cl = [lines(4); lines(4)];
for i = 1:8, contour(cp_orient_img(T0, double(masks(:,:,i))), [0.5 0.5], 'Color', cl(i,:), 'LineWidth', 1.5); end
sd = T0.site_disp; plot(sd(2), sd(1), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
title(sprintf('%s approximate regions (no CCF): %s', strrep(sess,'_',' '), strjoin(names, ' / ')));
exportgraphics(f, fullfile(here,'..','paper','images','mpc_arx', sprintf('lu_regions_%s.png', sess)), 'Resolution', 150); close(f);
S = struct('R', R, 'names', {names}, 'masks', masks, 'sess', sess);
save(fullfile(dataDir, sprintf('ctrl_lu_regions_%s.mat', sess)), '-struct', 'S', '-v7');
end
