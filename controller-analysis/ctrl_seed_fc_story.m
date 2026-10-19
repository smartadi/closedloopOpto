function R = ctrl_seed_fc_story(sess, opt)
%CTRL_SEED_FC_STORY  Controls for the seed-FC decoupling result (hub #32), on ~60 cortical spots.
%   The CL drop in r(site, cortex) could be inflated or deflated by the laser itself: in CL the laser
%   differs trial to trial, so its drive is NOT removed by subtracting the trial mean. Three controls:
%   (1) LASER REMOVAL, non-circular. A laser -> V kernel (FIR, lags 0..Q-1, every SVD component) is fit on
%       OL trials only (laser independent of the brain there; onset + offset transients of the step pin
%       the kernel), then the predicted laser-driven part is subtracted from every window before r.
%       OL trials are removed with 5-fold cross-fitted kernels. Gain sweep g x kernel (actuator gain
%       varies ~40% trial to trial) and a SHUFFLE control (CL trials paired with another trial's laser).
%   (3) COHERENCE vs frequency, seed vs each spot, Hann-tapered 3 s windows (base [-3,0), stim [0,3)),
%       cross-spectra averaged over trials. Says WHICH timescales the controller decouples.
%   (4) GLOBAL-SIGNAL REGRESSION: the mask-mean signal is regressed out of every window (after evoked +
%       laser removal), so a drop is not just the brain-wide mode being cancelled.
%   r windows as in ctrl_seed_fc: base [-2,0) s vs stim [+1,+3) s, evoked (trial mean) removed.
%   Self-contained loader (raw session file + cached site/orient/ROI), so it runs on every session.
% IN   sess  e.g. 'AL_0033_0226_e2'
% OUT  data/ctrl_seed_fc_story_<sess>.mat
if nargin < 1 || isempty(sess), sess = 'AL_0033_0226_e2'; end
if nargin < 2, opt = struct(); end
df = struct('nSV', 200, 'nSpot', 60, 'base', [-2 0], 'stim', [1 3], 'cbase', [-3 0], 'cstim', [0 3], ...
            'Q', 35, 'lamK', 1, 'fitwin', [-1 4], 'gains', [0 0.6 0.8 1 1.2 1.4], 'excl_mm', 0.5, ...
            'nboot', 200, 'nshuf', 20, 'year', '');
fn = fieldnames(df); for i = 1:numel(fn), if ~isfield(opt, fn{i}), opt.(fn{i}) = df.(fn{i}); end, end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here, 'data'); addpath(genpath(fullfile(here, '..', 'utils')));

% ---- load ------------------------------------------------------------------------------------------
tk = regexp(sess, '(AL_\d+)_(\d\d)(\d\d)_e(\d+)', 'tokens', 'once');
yr = opt.year; if isempty(yr), yr = '2025'; if any(strcmp(tk{1}, {'AL_0048', 'AL_0051'})), yr = '2026'; end, end
Z = load(fullfile(here, '..', 'data', sprintf('%sctrl%s%s%s.mat', tk{1}, tk{2}, tk{3}, tk{4})), 'd', 'data');
dz = Z.d; Dz = Z.data; tb = dz.timeBlue(:); Fs = 35; T = numel(tb);
[uAmp, ~] = cp_laser_amplitude(dz.inpVals, dz.inpTime);
u = interp1(dz.inpTime, uAmp, tb, 'linear', 0); u(isnan(u)) = 0;
on = arrayfun(@(t) find(tb >= t, 1), dz.stimStarts(:));
onCL = on(Dz.wc(:)); onOL = on(Dz.nc(:));
valid = (1:T).' >= double(dz.params.horizon);
sr = expPath(tk{1}, sprintf('%s-%s-%s', yr, tk{2}, tk{3}), str2double(tk{4}));
[U, V, tsvd, mimg] = cp_loadUVt(sr, opt.nSV, tb);
hemo = exist(fullfile(sr, 'corr', 'svdTemporalComponents_corr.npy'), 'file') > 0;
[nY, nX, nS] = size(U); Uf = reshape(U, nY*nX, nS);
n = min(numel(tsvd), size(V, 2));
V = interp1(tsvd(1:n), double(V(:, 1:n)).', tb, 'linear', 'extrap').';
st = load(fullfile(dataDir, sprintf('cp_stim_site_ctrl_%s.mat', sess))); s = double(st.rowcol);
ocf = fullfile(dataDir, sprintf('cp_orient_ctrl_%s.mat', sess));
try
    T0 = cp_orient(mimg, s(1), s(2), struct('cache_file', ocf, 'redefine', false, 'confirm', false));
catch      % older caches (e.g. AL_0033 0224) lack the .sym_* fields cp_orient prints; T itself is valid
    T0 = load(ocf); T0 = T0.T;
end
Mk = cp_roi_masks(mimg, fullfile(dataDir, sprintf('cp_roi2_ctrl_%s.mat', sess)), s(1), s(2), ...
                  struct('redefine', false, 'thr_pctile', 20, 'plot', false, 'T', T0));
mask = imerode(logical(Mk.contra) | logical(Mk.ipsi), strel('disk', 3));
fprintf('[STORY] %s | %d SV (hemo-corr %d) | %d OL, %d CL trials\n', sess, nS, hemo, numel(onOL), numel(onCL));

% ---- seed, spots, global weights --------------------------------------------------------------------
h = 2; box = @(r, c) sub2ind([nY nX], reshape(repmat((max(1,r-h):min(nY,r+h)).', 1, 5), [], 1), ...
                                     reshape(repmat(max(1,c-h):min(nX,c+h), 5, 1), [], 1));
us = mean(Uf(box(s(1), s(2)), :), 1);
[rr, cc] = find(mask); best = inf;
for sp = 3:0.25:80
    [G1, G2] = ndgrid(round(min(rr):sp:max(rr)), round(min(cc):sp:max(cc)));
    in = mask(sub2ind(size(mask), G1(:), G2(:)));
    if abs(nnz(in) - opt.nSpot) < best, best = abs(nnz(in) - opt.nSpot); rc = [G1(in) G2(in)]; end
end
Us = cell2mat(arrayfun(@(i) mean(Uf(box(rc(i,1), rc(i,2)), :), 1), (1:size(rc,1)).', 'uni', 0));
ug = mean(Uf(mask(:), :), 1);
pxmm = 1000/17.3; dmm = hypot(rc(:,1) - s(1), rc(:,2) - s(2)) / pxmm; far = dmm > opt.excl_mm;

% ---- laser kernel from OL trials (cross-fitted for OL itself) ---------------------------------------
fw = round(opt.fitwin(1)*Fs):round(opt.fitwin(2)*Fs)-1;
okT = @(o, w) o + min(w) >= max(opt.Q, find(valid, 1)) & o + max(w) <= T;
onOL = onOL(okT(onOL, [fw round(opt.cbase(1)*Fs)])); onCL = onCL(okT(onCL, [fw round(opt.cbase(1)*Fs)]));
nO = numel(onOL); rng(3); fold = mod(randperm(nO), 5) + 1;
K_all = fitK(V, u, onOL, fw, opt); Kf = cell(5, 1);
for f = 1:5, Kf{f} = fitK(V, u, onOL(fold ~= f), fw, opt); end
R.K_site = us * K_all.B;                       % laser kernel at the site (1 x Q)
R.K_spots = Us * K_all.B;                      % nSpot x Q

% ---- windows -> per-trial V blocks (raw, laser-predicted) -------------------------------------------
W = struct('base', opt.base, 'stim', opt.stim, 'cbase', opt.cbase, 'cstim', opt.cstim);
cn = {'OL', 'CL'}; ons = {onOL, onCL}; [bl, al] = butter(4, 6 / (Fs/2));
for c = 1:2
    for w = fieldnames(W).'
        ix = ons{c} + (round(W.(w{1})(1)*Fs):round(W.(w{1})(2)*Fs)-1);   % nTr x nW
        Vr = blk(V, ix);                                                % nS x nW x nTr
        Lp = zeros(size(Vr));                                           % predicted laser-driven V
        for t = 1:size(ix, 1)
            Kt = K_all; if c == 1, Kt = Kf{fold(t)}; end
            % 6 Hz low-pass: the plant (tau ~190 ms) passes ~nothing faster, and the unfiltered FIR
            % prediction put kernel noise common to every spot -> spurious >8 Hz coherence (m4, 2026-10-19)
            Lp(:, :, t) = filtfilt(bl, al, (Kt.B * lagm(u, ix(t, :), opt.Q).').').';
        end
        D.(cn{c}).(w{1}) = struct('Vr', Vr, 'Lp', Lp, 'ix', ix);
    end
end

% ---- (1)+(4) r variants ------------------------------------------------------------------------------
var_names = {'raw', 'las', 'gsr', 'gsr_las'};
for c = 1:2
    for w = {'base', 'stim'}
        B = D.(cn{c}).(w{1});
        for v = var_names
            X = prep(B.Vr, B.Lp, v{1}, 1, ug);
            R.(cn{c}).(w{1}).(v{1}) = seedr(Us, us, X);
        end
        if strcmp(w{1}, 'stim')
            R.(cn{c}).gain_r = cell2mat(arrayfun(@(g) mfar(seedr(Us, us, prep(B.Vr, B.Lp, 'las', g, ug)), far), ...
                                                 opt.gains, 'uni', 0));
            if c == 2      % shuffle: each CL trial gets another trial's laser prediction
                sh = nan(opt.nshuf, 1);
                for k = 1:opt.nshuf
                    p = randperm(size(B.Lp, 3)); sh(k) = mfar(seedr(Us, us, prep(B.Vr, B.Lp(:, :, p), 'las', 1, ug)), far);
                end
                R.CL.shuf_r = sh;
            end
        end
        R.(cn{c}).(w{1}).sd_seed_raw = std(us * reshape(prep(B.Vr, B.Lp, 'raw', 1, ug), nS, []), 1);
        R.(cn{c}).(w{1}).sd_seed_las = std(us * reshape(prep(B.Vr, B.Lp, 'las', 1, ug), nS, []), 1);
    end
    % paired trial bootstrap of delta mean_far r (stim - base) per variant
    nT = size(D.(cn{c}).base.Vr, 3); bt = nan(opt.nboot, numel(var_names));
    for b = 1:opt.nboot
        k = randi(nT, nT, 1);
        for v = 1:numel(var_names)
            Bb = D.(cn{c}).base; Bs = D.(cn{c}).stim;
            bt(b, v) = mfar(seedr(Us, us, prep(Bs.Vr(:,:,k), Bs.Lp(:,:,k), var_names{v}, 1, ug)), far) ...
                     - mfar(seedr(Us, us, prep(Bb.Vr(:,:,k), Bb.Lp(:,:,k), var_names{v}, 1, ug)), far);
        end
    end
    for v = 1:numel(var_names)
        vn = var_names{v};
        R.(cn{c}).dr.(vn) = mean(R.(cn{c}).stim.(vn)(far)) - mean(R.(cn{c}).base.(vn)(far));
        R.(cn{c}).dci.(vn) = prctile(bt(:, v), [2.5 97.5]);
    end
    fprintf('[STORY] %s  dr  raw %+.3f [%+.3f %+.3f] | las %+.3f [%+.3f %+.3f] | gsr %+.3f | gsr+las %+.3f [%+.3f %+.3f]\n', cn{c}, ...
        R.(cn{c}).dr.raw, R.(cn{c}).dci.raw, R.(cn{c}).dr.las, R.(cn{c}).dci.las, R.(cn{c}).dr.gsr, ...
        R.(cn{c}).dr.gsr_las, R.(cn{c}).dci.gsr_las);
end
fprintf('[STORY] CL stim r vs gain %s: %s | shuffle mean %.3f (true g=1: %.3f)\n', mat2str(opt.gains), ...
    mat2str(R.CL.gain_r, 3), mean(R.CL.shuf_r), R.CL.gain_r(opt.gains == 1));

% ---- (3) coherence vs frequency ---------------------------------------------------------------------
nW = size(D.OL.cbase.Vr, 2); R.f = (1:floor(nW/2)) * Fs / nW; hw = hann(nW).';
for c = 1:2
    for w = {'cbase', 'cstim'}
        B = D.(cn{c}).(w{1});
        for v = {'raw', 'las', 'gsr_las'}
            X = reshape(prep(B.Vr, B.Lp, v{1}, 1, ug), nS, nW, []);
            [Coh, Sss] = cohspots(X, us, Us, hw, numel(R.f));
            R.(cn{c}).(w{1}).coh.(v{1}) = Coh;                 % nSpot x nf
            R.(cn{c}).(w{1}).Sss.(v{1}) = Sss;                 % seed power spectrum
        end
    end
end
R.sess = sess; R.opt = opt; R.hemo = hemo; R.rc = rc; R.site = s; R.mask = mask; R.mimg = mimg;
R.dmm = dmm; R.far = far; R.nTr = [numel(onOL) numel(onCL)];
save(fullfile(dataDir, sprintf('ctrl_seed_fc_story_%s.mat', sess)), '-struct', 'R', '-v7');
end

% =====================================================================================================
function K = fitK(V, u, ons, fw, opt)
% laser -> V FIR, per-trial baseline ([-1,0) s) subtracted, OLS-ish (small ridge)
pre = fw(fw < 0); Y = []; L = [];
for o = ons(:).'
    ix = o + fw; Y = [Y; (V(:, ix) - mean(V(:, o + pre), 2)).']; L = [L; lagm(u, ix, opt.Q) - mean(u(o + pre))]; %#ok<AGROW>
end
K.B = ((L.' * L + opt.lamK * eye(opt.Q)) \ (L.' * Y)).';      % nS x Q
end

function m = mfar(r, far)
m = mean(r(far));
end

function L = lagm(u, ix, Q)
ix = ix(:); L = zeros(numel(ix), Q);
for q = 0:Q-1, L(:, q+1) = u(max(1, ix - q)); end
end

function B = blk(V, ix)
B = reshape(V(:, reshape(ix.', 1, [])), size(V, 1), size(ix, 2), size(ix, 1));
end

function X = prep(Vr, Lp, how, g, ug)
% evoked removal (+ laser removal, + global-signal regression); returns nS x (nW*nTr)
if any(strcmp(how, {'las', 'gsr_las'})), Vr = Vr - g * Lp; end
Vr = Vr - mean(Vr, 3);
X = reshape(Vr, size(Vr, 1), []);
if startsWith(how, 'gsr')
    gs = ug * X; X = X - (X * gs.') / (gs * gs.') * gs;
end
end

function r = seedr(Us, us, X)
n = size(X, 2); sv = us * X;
r = (Us * (X * sv.') / n) ./ sqrt(sum((Us * ((X * X.') / n)) .* Us, 2) * var(sv, 1));
end

function [Coh, Sss] = cohspots(X, us, Us, hw, nf)
% X: nS x nW x nTr (evoked-removed). Welch over trials, Hann taper.
nTr = size(X, 3); nW = size(X, 2); nP = size(Us, 1);
Ssp = zeros(nP, nf); Spp = zeros(nP, nf); Sss = zeros(1, nf);
for t = 1:nTr
    xs = us * X(:, :, t); xp = Us * X(:, :, t);
    Fs_ = fft((xs - mean(xs)) .* hw, [], 2); Fp = fft((xp - mean(xp, 2)) .* hw, [], 2);
    Fs_ = Fs_(2:nf+1); Fp = Fp(:, 2:nf+1);
    Ssp = Ssp + Fp .* conj(Fs_); Spp = Spp + abs(Fp).^2; Sss = Sss + abs(Fs_).^2;
end
Coh = abs(Ssp).^2 ./ (Spp .* Sss); Sss = Sss / nTr / nW;
end
