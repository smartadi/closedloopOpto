function ctrl_mpc_sine_export(nSpot, nSV)
%CTRL_MPC_SINE_EXPORT  Inputs for the SINE-reference MPC replay (mpc_direct_sine.py): Fig 5's representative
%   session AL_0048 2026-07-14/1, right hemisphere (inhibitory), 1 Hz sine reference, 4 s window, 4 modes.
%   Same two files and fields as ctrl_mpc_arx_export + ctrl_mpc_wb_export (static, Fig 6 A-H), plus r(t).
%
%   y  = the rig's ONLINE dF/F, states.csv, i.e. literally the signal the PI fed back on. The rig logs row k with
%        frame k-1's value (states(k) = offline 40 s-rolling dF/F at the controlled pixel one frame earlier,
%        r = 0.988; mode-1 F/mI is r = 0.84), so on the frame clock y(k) = states(k+1).
%   r  = the TARGET trajectory, -reference_raw(k+1) (0 to -4 %dF/F, 1 Hz; same row->frame shift). NOT
%        reference.csv: error.csv = states + reference.csv exactly, but in the two PREVIEW modes reference.csv is
%        the lookahead copy, advanced by previewT_steps = 5 frames; reference_raw is the un-advanced target in
%        every mode (and is what Fig 5 scores against). The trial onset row o (sess.onset_idx) is frame o-1.
%   u  = Timeline lightCommand638 (cp_laser_amplitude: carrier check) sampled at timeBlue = the frame clock,
%        exactly as the static exporter does; Volts (the 638 V->mW calibration is session-dated, laser_v2mw).
%   X  = ~100 whole-brain spots (5x5 px), SVD (corr/ V when present) / mean image * 100, on timeBlue.
%        Mask = mean image > 0.65 x Otsu (Otsu alone keeps only the brighter hemisphere), largest component, holes
%        filled, eroded 6 px: this session has no cp_roi2 outline cache.
%   valid = after the rig's 1400-frame (40 s) rolling-baseline warm-up, finite, and inside the recording.
%   fold  = 5 folds interleaved over ALL sine trials in time order (the controller model of a trial never saw any
%        trial of its fold).
% OUT  data/ctrl_mpc_arx_in_AL_0048_0714_e1.mat, data/ctrl_mpc_wb_in_AL_0048_0714_e1_n<nSpot>.mat (v7)
if nargin < 1, nSpot = 100; end
if nargin < 2, nSV = 200; end
here = fileparts(mfilename('fullpath')); root = fullfile(here, '..'); dataDir = fullfile(here, 'data');
addpath(genpath(fullfile(root, 'utils')));
mn = 'AL_0048'; td = '2026-07-14'; en = 1; sess = 'AL_0048_0714_e1';
Fs = 35; pre = 35; Hp = 35; W_BASE = 1400;

tmp = load(fullfile(root, 'data', 'AL_0048_bil_07141.mat')); S = tmp.sess; clear tmp
d = S.d; tb = d.timeBlue(:); T = numel(tb); sr = expPath(mn, td, en);
rd = @(n) reshape(readmatrix(fullfile(sr, [n '.csv']), 'FileType', 'text', 'Delimiter', ' '), [], 1);
st = rd('states'); rf = rd('reference'); er = rd('error'); rraw = rd('reference_raw');
assert(numel(st) > T && max(abs(er(1:T) - st(1:T) - rf(1:T))) < 1e-9, 'error.csv ~= states + reference');
y = st(2:T+1); r = -rraw(2:T+1);
y(T) = NaN;                                           % row T+1 is past the last frame

% the shift: y(k) must sit on the offline frame clock (rolling dF/F at the controlled pixel)
yr = dff_rolling(100 + double(S.right.dFoF(:)).', W_BASE); yr = yr(:);
ii = (W_BASE + 1000):(T - 10);
c0 = corr(y(ii), yr(ii)); cm = corr(y(ii), yr(ii - 1)); cp = corr(y(ii), yr(ii + 1));
fprintf('[SINE-EXP] corr(y, offline rolling dF/F) lag -1 %.3f | 0 %.3f | +1 %.3f\n', cm, c0, cp);
assert(c0 > max(cm, cp) && c0 > 0.97, 'frame-clock alignment of states.csv failed');

[uAmp, li] = cp_laser_amplitude(d.inpVals638, d.inpTime638);
u = interp1(d.inpTime638, uAmp, tb, 'linear', 0); u(isnan(u)) = 0;
fprintf('[SINE-EXP] laser 638: %s | max u %.2f V\n', li.mode, max(u));

tm = S.trial_meta; cond = [tm.ff_cond].'; side = {tm.side}.';
N = round(S.sine.dur * Fs) + 1;                       % Fig 5 window: onset .. onset + dur*Fs (141 samples)
on = S.onset_idx(:) - 1;                              % onset row -> frame
keep = cond >= 0 & strcmp(side, 'right') & isfinite(on);
keep = keep & on - pre - 140 > W_BASE & on + N + 140 < T;
on = on(keep); cond = cond(keep); tix = find(keep);
[on, so] = sort(on); cond = cond(so); tix = tix(so);
fold = mod((0:numel(on)-1).', 5) + 1;

valid = (1:T).' > W_BASE + 1 & isfinite(y) & isfinite(u);
fprintf('[SINE-EXP] %d frames | valid %d | max|y| on valid %.1f\n', T, nnz(valid), max(abs(y(valid))));
% the reference the rig tracked, inside each window: must be the 1 Hz, 0..-4 sine
R = cell2mat(arrayfun(@(o) r(o + (0:N-1)).', on, 'uni', 0));
fprintf('[SINE-EXP] ref in window: min %.2f max %.2f | trial-to-trial max sd %.3g\n', min(R(:)), max(R(:)), max(std(R, 0, 1)));
names = {'CL+p', 'OL+p', 'OL', 'CL'};                % ff_cond 0 1 2 3
for c = 0:3, fprintf('[SINE-EXP] %-5s %3d trials\n', names{c+1}, nnz(cond == c)); end
mot = zeros(T, 1); if isfield(d, 'motion') && numel(d.motion) == T, mot = double(d.motion(:)); end
A = struct('y', y, 'u', u, 'r', r, 'valid', double(valid), 'on', on + 0, 'cond', cond, 'trial_idx', tix, ...
           'fold', fold, 'pre', pre, 'N', N, 'Hp', Hp, 'Fs', Fs, 'sess', sess, 'motion', mot, ...
           'cond_names', {names}, 'pixel', S.right.pixel, 'sine_amp', S.sine.amp, 'sine_hz', S.sine.hz, ...
           'Kp', d.input_params(tix(1), 5), 'Ki', d.input_params(tix(1), 6), 'Kref', d.input_params(tix(1), 4), ...
           'previewT_steps', d.input_params(tix(1), 8));
save(fullfile(dataDir, sprintf('ctrl_mpc_arx_in_%s.mat', sess)), '-struct', 'A', '-v7');

% ---- whole-brain spots --------------------------------------------------------------------------------------
[U, V, tsvd, mimg] = cp_loadUVt(sr, nSV, tb);
V = double(V); [nY, nX, ~] = size(U);
fprintf('[SINE-EXP] SVD %dx%d x %d SV | %d frames | corr V: %d\n', nY, nX, size(U, 3), size(V, 2), ...
    exist(fullfile(sr, 'corr', 'svdTemporalComponents_corr.npy'), 'file') > 0);
mi = double(mimg); mi = mi / max(mi(:));
mask = mi > 0.65 * graythresh(mi);
cc = bwconncomp(mask); [~, ib] = max(cellfun(@numel, cc.PixelIdxList));
mask = false(size(mask)); mask(cc.PixelIdxList{ib}) = true;
mask = imerode(imfill(mask, 'holes'), strel('disk', 6));
site = double(S.right.pixel([2 1]));                  % [row col] (pixel is [x y] = [col row])

[rr, cc2] = find(mask); best = inf;
for s = 3:0.25:60
    gr = min(rr):s:max(rr); gc = min(cc2):s:max(cc2);
    [G1, G2] = ndgrid(round(gr), round(gc)); in = mask(sub2ind(size(mask), G1(:), G2(:)));
    if abs(nnz(in) - nSpot) < best, best = abs(nnz(in) - nSpot); sp = s; rc = [G1(in) G2(in)]; end
end
fprintf('[SINE-EXP] grid spacing %.2f px -> %d spots in mask\n', sp, size(rc, 1));
Uf = reshape(U, nY*nX, []); h = 2; X = zeros(size(rc, 1), size(V, 2));
for i = 1:size(rc, 1)
    [b1, b2] = ndgrid(max(1, rc(i,1)-h):min(nY, rc(i,1)+h), max(1, rc(i,2)-h):min(nX, rc(i,2)+h));
    ix = sub2ind([nY nX], b1(:), b2(:));
    X(i, :) = (mean(Uf(ix, :), 1) * V) / mean(mimg(ix)) * 100;
end
tsvd = tsvd(:); n = min(numel(tsvd), size(X, 2));
Xt = interp1(tsvd(1:n), X(:, 1:n).', tb, 'linear', 'extrap');
dist_px = hypot(rc(:,1) - site(1), rc(:,2) - site(2));
f = figure('Visible', 'off'); imagesc(mi); axis image; colormap gray; hold on
contour(mask, [0.5 0.5], 'y'); plot(rc(:,2), rc(:,1), 'c.'); plot(site(2), site(1), 'r+', 'MarkerSize', 12);
title(sprintf('%s: %d spots, laser site red', sess, size(rc, 1)), 'Interpreter', 'none');
exportgraphics(f, fullfile(root, 'paper', 'images', 'mpc_arx', sprintf('mpc_sine_spots_%s.png', sess)), 'Resolution', 150); close(f)
W = struct('X', Xt, 'rc', rc, 'mask', mask, 'mimg', mimg, 'site_rc', site, 'dist_px', dist_px, ...
           'spacing_px', sp, 'nSV', size(U, 3), 'sess', sess);
save(fullfile(dataDir, sprintf('ctrl_mpc_wb_in_%s_n%d.mat', sess, nSpot)), '-struct', 'W', '-v7');
end
