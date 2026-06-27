% impulse-analysis/contra_prediction.m
% Contralateral SVD ARX prediction of the impulse response.
%
% Fits ARX on spontaneous pre-trial windows (contra SVD components + z-scored
% motion).  Prediction uses ONLY pre-trial contra+motion history (no trial data,
% no laser input knowledge) — a counterfactual "what would primary do undisturbed?"
% Residual = actual - prediction isolates the laser-driven response.
%
% Training is performed ONLY on 6-second pre-stimulus data chunks.
% Trials are split chronologically into train / test / validate (60/20/20).
%
% Prereqs: load_experiments.m has been run (allExperiments in workspace).
% Run from brain_paper/ root directory or impulse-analysis/.
close all;
clc;


% Resolve the script's own folder robustly (independent of cwd / MATLAB path):
% mfilename('fullpath') is the abs path of THIS running script. BUT when the file
% is run from the editor with UNSAVED changes, MATLAB executes a staged copy under
% tempdir (...\Temp\Editor_*), so mfilename points there and every cache (ROI, SVD,
% ipsi SVD) would be written to temp. Reject any tempdir path and fall back to
% which()/pwd so the caches always land in impulse-analysis\data\.
cp_path = mfilename('fullpath');
if isempty(cp_path) || startsWith(cp_path, tempdir)
    cp_path = which('contra_prediction');
end
if isempty(cp_path) || startsWith(cp_path, tempdir)
    cands = {fullfile(pwd,'contra_prediction.m'), ...
             fullfile(pwd,'impulse-analysis','contra_prediction.m')};
    hit   = cands(cellfun(@(p) exist(p,'file')==2, cands));
    if ~isempty(hit), cp_path = hit{1}; else, cp_path = cands{1}; end
end
impulseDir = fileparts(cp_path);
paperRoot  = fullfile(impulseDir, '..', 'paper');
utilsDir   = fullfile(impulseDir, '..', 'utils');
% Absolute cache dir (ROI + SVD), anchored to the script -- NOT pwd -- so the
% midline/mask and SVD caches are found regardless of the working directory.
dataDir    = fullfile(impulseDir, 'data');
if ~exist(dataDir, 'dir'), mkdir(dataDir); end
addpath(utilsDir);
addpath(genpath(utilsDir));

PS = paperStyle();
setPaperDefaults();

if exist(fullfile('paper','images'),'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'),'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper';
    warning('contra_prediction: cannot locate paper/ -- paths may be wrong.');
end

%% Setup -- session and model parameters
selExp    = 3;      % experiment index (default 3 = AL_0033 2025-01-29)
pY        = 0;      % AR self-lags on y (0 = pure contra prediction)
pX        = 0;      % predictor lags. 0 = instantaneous map y(t)=B*contra(t).
                    % Interhemispheric coupling is near-instantaneous (callosal
                    % delay << one 28.6 ms frame) and the slow GCaMP signal makes
                    % lagged copies collinear -> rank-deficient with no gain.
                    % Lag sweep (AL_0033): pX=0 test R2=0.905 vs pX=10 R2=0.880.
nSV_load  = 500;    % SVD components to load from disk
spont_pre = 6;      % pre-trial spontaneous training window (s)
dur_imp   = 3.0;    % trial window (s)
redefine_roi  = false; % set true to force re-draw midline + contra polygon

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('contra_prediction: run load_experiments.m first.');
end

mn = allExperiments(selExp).mn;
td = allExperiments(selExp).td;
en = allExperiments(selExp).en;
fprintf('contra_prediction: %s  %s  en=%d\n', mn, td, en);

Fs      = 35;
mlag    = max(pY, pX);
outlen  = round(dur_imp * Fs);
t_trial = (0:outlen-1) / Fs;

y_full  = allExperiments(selExp).dF(:);
t_full  = allExperiments(selExp).timeBlue(:);
nFrames = numel(y_full);

%% Load SVD for this experiment
serverRoot    = expPath(mn, td, en);
[U_cp, V_cp, ~, mimg_cp] = loadUVt(serverRoot, nSV_load);
[nY_cp, nX_cp] = size(mimg_cp);
nSV_cp         = size(U_cp, 3);
% brain_mask_cp / contra / ipsi masks are built from the ROI by cp_roi_masks below.

d_tmp    = loadData(serverRoot, mn, td, en);
horizon  = double(d_tmp.params.horizon);
w_r      = horizon - 1;
idx_r_cp = 1:nFrames;
py_prim  = double(d_tmp.params.pixel(1));
px_prim  = double(d_tmp.params.pixel(2));
k_prim   = double(d_tmp.params.kernel);   % recording-kernel half-width (for [CP-HEMI])
mot_full = d_tmp.motion.motion_1(1:2:end);
clear d_tmp

%% Brain mask + contra/ipsi split (full-brain mask bisected by the midline)
% Single source of truth: utils/cp_roi_masks draws the FULL-BRAIN outline + the
% midline (first run / redefine_roi), bisects the brain by the midline, and tags
% the side containing the primary (recording) pixel as IPSI (target); the other is
% CONTRA (predictor). No hand-drawn hemisphere polygon, no "everything-else"
% complement. cp_roi_masks also draws a verification overlay (contra=blue,
% ipsi=red, primary=green +) so the split can be confirmed before trusting any R^2.
roi_name = sprintf('cp_roi2_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en);
roi_file = fullfile(dataDir, roi_name);
fprintf('[CP] ROI cache expected at: %s\n', roi_file);

M_cp = cp_roi_masks(mimg_cp, roi_file, px_prim, py_prim, ...
                    struct('redefine', redefine_roi, 'thr_pctile', 20, 'plot', true));
brain_mask_cp = M_cp.brain;     % full-brain mask (outline AND intensity floor)
valid_cp_svd  = M_cp.contra;    % CONTRA = predictor hemisphere (name kept for downstream)
ipsi_mask_cp  = M_cp.ipsi;      % IPSI   = target hemisphere (primary-pixel side)

%% SVD extraction -- contra predictor signals (V_c_full)
% redoSVD on the full contra-hemisphere mask -> V_c_full (the [CP-HEMI] regressor
% modes) + U_svd_raw (contra spatial map, cached for the future bleed analysis).
% Cached in *_svdraw.mat; computed once.

path_cp      = fullfile(dataDir, sprintf('%scp%s%s%d.mat', mn, td(6:7), td(9:10), en));
path_svd_raw = strrep(path_cp, '.mat', '_svdraw_ml.mat');   % _ml = midline-split masks

if exist(path_svd_raw, 'file')
    tmp       = load(path_svd_raw, 'U_svd_raw', 'V_c_full');
    U_svd_raw = tmp.U_svd_raw;
    V_c_full  = tmp.V_c_full;
    fprintf('Loaded contra SVD raw cache: %s\n', path_svd_raw);
else
    idx_contra = find(valid_cp_svd(:));
    U_flat_cp  = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
    U_contra   = double(U_flat_cp(idx_contra, :));
    fprintf('Running redoSVD on contra mask (%d px, nSV_cp=%d)...\n', numel(idx_contra), nSV_cp);
    [U_svd_raw, V_c_full] = redoSVD(U_contra, double(V_cp));
    U_svd_raw = double(U_svd_raw);
    V_c_full  = double(V_c_full);
    [~] = mkdir(fileparts(path_svd_raw));
    save(path_svd_raw, 'U_svd_raw', 'V_c_full', '-v7.3');
    fprintf('Saved contra SVD raw cache: %s  (%d modes)\n', path_svd_raw, size(V_c_full,1));
end

%% Frame count for the spontaneous windows
% [CP-HEMI] is the predictor and z-scores the contra modes (V_c_full) itself, so
% the old OLS predictor matrix is gone; only the usable frame count remains.
nF_m = min(nFrames, numel(mot_full));

%% [CP-STIM] Stim-onset list for the spontaneous windows
% Builds the sorted nonzero-amplitude stim onsets + pre_frames -- the only former
% [CP-FIT] outputs still used: [CP-HEMI] carves its spontaneous windows from them
% (inter-stim gaps or pre-stim). The instantaneous OLS map beta_cp and all its
% downstream sections were removed 2026-06-24; [CP-HEMI] is the predictor.

imp_data   = allExperiments(selExp).imp;
uAmp_cp    = allExperiments(selExp).uAmp;
nzMask_cp  = uAmp_cp > 0;

all_starts_cp = [];
for ia = 1:numel(uAmp_cp)
    if ~nzMask_cp(ia); continue; end
    all_starts_cp = [all_starts_cp; imp_data.startTimes{ia}(:)];  %#ok<AGROW>
end
all_starts_cp = sort(all_starts_cp);

pre_frames = round(spont_pre * Fs);

%% [CP-HEMI] Whole-hemisphere reduced-rank prediction (Ye/Zhiwen replication)
%
% FAITHFUL PORT of Ye et al. 2023 spirals
%   spirals_mirror/preprocessing/getReducedRankRegressionHEMI.m
% to make OUR contra->ipsi prediction directly comparable to Zhiwen's ~0.99.
%
% KEY DIFFERENCE from [CP-FIT]/[CP-RRR]: the target is the WHOLE ipsi-hemisphere
% PIXEL FIELD (not the single primary pixel). Zhiwen's 0.99-at-low-rank is a
% variance-WEIGHTED pooled R^2 over all ipsi pixels x time, dominated by the few
% bilaterally-mirrored modes. Reproduced here via reduced-rank regression
% (utils/CanonCor2.m) scored with utils/sseExplainedCal.m, exactly as he does.
%
% We report THREE numbers from one fit:
%   (1) pooled whole-ipsi-hemisphere R^2 vs rank   -> the Zhiwen-comparable curve
%   (2) per-pixel R^2 map at a chosen rank         -> where prediction is good
%   (3) PRIMARY-pixel R^2 vs rank = the predicted ipsi FIELD spatially AVERAGED
%       over the recording-kernel footprint (getpixel_dFoF square, half-width
%       d.params.kernel), scored against y_full (the real recorded trace). The
%       kernel mean is reconstructed full-resolution from the ipsi SVD and read
%       out through the SAME canonical latents as the field (no free OLS to
%       y_full, and the pooled fit (1)/(2) is untouched -- see below). NB: because
%       the readout and the kernel-average are both linear, this lands near the
%       single-pixel ceiling (~0.85), well below the variance-weighted pooled
%       number (1) -- by design, not a bug.
%
% PARITY CAVEATS (cannot fully match): no Allen-atlas sensory restriction -- contra
% (predictor) and ipsi (target) are the two clean halves of the full-brain mask
% bisected by the midline (cp_roi_masks), the side with the primary pixel = ipsi.
% Confirm AL_0033 SVD is hemodynamically corrected like his. Instantaneous (pX=0).
%
% Prereqs (run earlier sections first): U_cp, V_cp, V_c_full, valid_cp_svd (contra),
% ipsi_mask_cp, y_full, Fs, all_starts_cp/pre_frames.

h_K        = 50;      % SVD modes per hemisphere (Zhiwen uses 50)
h_maxPix   = 2000;    % cap ipsi pixels (CPU memory); pooled R^2 is ~invariant to it
h_maxFrm   = 60000;   % cap total spontaneous frames used
h_trainFrac= 2/3;     % contiguous early-train / late-test split (~Zhiwen 40k/20k)
h_rankMark = 10;      % rank to highlight (Zhiwen reads ~0.99 here)
h_win_mode = 'interstim'; % spontaneous windowing: 'interstim' = full post-settle gap
                          % between stim starts (lever-1, long windows); 'prestim' = legacy
h_settle_s = 1.0;     % s dropped after each stim for the response to settle (interstim)

% --- ipsi (target) hemisphere mask (midline-split, from cp_roi_masks) ---
h_ipsi_mask = ipsi_mask_cp;
h_idx_ipsi  = find(h_ipsi_mask(:));
if numel(h_idx_ipsi) > h_maxPix          % even stride downsample
    h_stride   = ceil(numel(h_idx_ipsi)/h_maxPix);
    h_idx_ipsi = h_idx_ipsi(1:h_stride:end);
end
fprintf('[CP-HEMI] ipsi mask: %d pixels (after cap %d)\n', numel(h_idx_ipsi), h_maxPix);

% --- ipsi SVD (redoSVD on ipsi pixels), cached like the contra side ---
h_path_ipsi = strrep(path_cp, '.mat', '_svdraw_ml_ipsi.mat');   % _ml = midline-split
if exist(h_path_ipsi, 'file')
    h_tmp        = load(h_path_ipsi, 'U_ipsi_raw', 'V_ipsi_full');
    U_ipsi_raw   = h_tmp.U_ipsi_raw;
    V_ipsi_full  = h_tmp.V_ipsi_full;
    fprintf('[CP-HEMI] loaded ipsi SVD cache: %s\n', h_path_ipsi);
else
    h_Uflat   = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
    h_Uipsi   = double(h_Uflat(find(h_ipsi_mask(:)), :)); %#ok<FNDSB> full mask for SVD
    fprintf('[CP-HEMI] running redoSVD on ipsi mask (%d px)...\n', size(h_Uipsi,1));
    [U_ipsi_raw, V_ipsi_full] = redoSVD(h_Uipsi, double(V_cp));
    U_ipsi_raw  = double(U_ipsi_raw);
    V_ipsi_full = double(V_ipsi_full);
    save(h_path_ipsi, 'U_ipsi_raw', 'V_ipsi_full', '-v7.3');
    fprintf('[CP-HEMI] saved ipsi SVD cache: %s\n', h_path_ipsi);
end
% --- recording-kernel footprint around the primary pixel -------------------------
% Mirror getpixel_dFoF / load_experiments EXACTLY: the recorded primary trace is
% the mean over the square  mimg(pixel(2)-k:pixel(2)+k, pixel(1)-k:pixel(1)+k)
% i.e. rows = px_prim+/-k, cols = py_prim+/-k, then F / mean(mimg_kernel) * 100.
% The predicted primary pixel is therefore the predicted FIELD averaged over the
% SAME footprint, /mean(mimg_kernel)*100, compared to y_full.
if exist('k_prim','var') && ~isempty(k_prim)
    h_kk = double(k_prim);
else                                    % standalone-section fallback (setup not re-run)
    try
        h_dk = loadData(serverRoot, mn, td, en);  h_kk = double(h_dk.params.kernel);  clear h_dk
    catch;  h_kk = 10;  end
end
h_kr = (px_prim - h_kk):(px_prim + h_kk);   h_kr = h_kr(h_kr>=1 & h_kr<=nY_cp);  % rows
h_kc = (py_prim - h_kk):(py_prim + h_kk);   h_kc = h_kc(h_kc>=1 & h_kc<=nX_cp);  % cols
[h_KR, h_KC]  = ndgrid(h_kr, h_kc);
h_idx_kern_sq = sub2ind([nY_cp, nX_cp], h_KR(:), h_KC(:));   % full square footprint
h_full_idx    = find(h_ipsi_mask(:));
h_idx_kern    = intersect(h_idx_kern_sq, h_full_idx);        % footprint inside ipsi field
h_mI_kern     = mean(mimg_cp(h_kr, h_kc), 'all');            % == y_full's mI(1) normalizer
if isempty(h_idx_kern)
    error('[CP-HEMI] primary-pixel kernel footprint falls outside the ipsi field mask.');
elseif numel(h_idx_kern) < numel(h_idx_kern_sq)
    fprintf(['[CP-HEMI] WARNING: %d/%d kernel pixels outside ipsi mask ' ...
             '(brain edge/midline) -- averaging the in-field subset.\n'], ...
             numel(h_idx_kern_sq)-numel(h_idx_kern), numel(h_idx_kern_sq));
end

% --- ipsi-SVD loading for the full-resolution kernel footprint (matches y_full) ---
% The primary pixel already lives inside the ipsi field, so its kernel mean is
% reconstructed straight from the ipsi SVD (full footprint, no downsampling) and
% read out through the SAME canonical latents below. The whole-field RRR fit and
% the pooled/map scoring are therefore left byte-identical to Zhiwen's pipeline.
[~, h_sel_kern] = ismember(h_idx_kern, h_full_idx);   % rows of U_ipsi_raw for the kernel
h_meanU = mean(U_ipsi_raw(h_sel_kern, 1:h_K), 1);     % [1 x K] mean ipsi-SVD loading over kernel
fprintf('[CP-HEMI] kernel k=%d: %d footprint px in ipsi field\n', h_kk, numel(h_idx_kern));

% --- U for the (downsampled) scoring pixel set (Zhiwen: all selected-area pixels) ---
[~, h_sel] = ismember(h_idx_ipsi, h_full_idx);        % rows of U_ipsi_raw to keep
h_Uips     = U_ipsi_raw(h_sel, 1:h_K);                % [P x K]

% --- spontaneous frame set: post-settling inter-stim intervals (lever-1) ----------
% No contiguous spontaneous recording exists, so to capture the slow global
% fluctuations that carry bilateral coherence we use the FULL gap between
% consecutive stim starts, dropping h_settle_s after each stim for the response to
% settle, then using the rest. (Legacy short pre-stim windows: h_win_mode='prestim'.)
% Any amplitude-0 gap-fill events that fall inside a gap are no-laser, so they stay
% as spontaneous frames.
h_onsets = zeros(numel(all_starts_cp),1);
for j = 1:numel(all_starts_cp)
    [~, h_onsets(j)] = min(abs(t_full - all_starts_cp(j)));
end
h_frames = [];
switch h_win_mode
    case 'interstim'
        h_settle = round(h_settle_s * Fs);
        for j = 1:numel(h_onsets)
            i0 = h_onsets(j) + h_settle;                      % drop settling after this stim
            if j < numel(h_onsets);  i1 = h_onsets(j+1) - 1;  % up to just before the next stim
            else;                    i1 = nF_m;  end          % last stim -> tail to end
            i0 = max(i0,1);  i1 = min(i1, nF_m);
            if i1 >= i0;  h_frames = [h_frames, i0:i1];  end  %#ok<AGROW>
        end
    case 'prestim'
        for j = 1:numel(h_onsets)
            i0 = h_onsets(j) - pre_frames;  i1 = h_onsets(j) - 1;
            if i0 >= 1 && i1 <= nF_m;  h_frames = [h_frames, i0:i1];  end %#ok<AGROW>
        end
    otherwise
        error('[CP-HEMI] unknown h_win_mode: %s', h_win_mode);
end
h_frames = unique(h_frames);
if numel(h_frames) > h_maxFrm
    h_frames = h_frames(round(linspace(1, numel(h_frames), h_maxFrm)));
end
h_nF   = numel(h_frames);
h_nTr  = floor(h_trainFrac * h_nF);
h_tr   = h_frames(1:h_nTr);            % contiguous early frames -> train
h_te   = h_frames(h_nTr+1:end);        % late frames -> test (state generalization)
fprintf('[CP-HEMI] %s windows: %d gaps -> %d spont frames (%.1f s; %d train / %d test)\n', ...
        h_win_mode, numel(all_starts_cp), h_nF, h_nF/Fs, numel(h_tr), numel(h_te));

% --- regressors (contra modes, z-scored over time per mode; train/test indep) ---
h_Xtr = zscore(V_c_full(1:h_K, h_tr), [], 2)';   % [nTr x K]
h_Xte = zscore(V_c_full(1:h_K, h_te), [], 2)';   % [nTe x K]

% --- target: ipsi-hemisphere pixel field (h_K-mode reconstruction) ---
h_Ytr = (h_Uips * V_ipsi_full(1:h_K, h_tr))';    % [nTr x P]
h_Yte = (h_Uips * V_ipsi_full(1:h_K, h_te))';    % [nTe x P]

% --- reduced-rank regression (Zhiwen: CanonCor2(signal', regressor')) ---
[h_a, h_b, ~] = CanonCor2({h_Ytr}, {h_Xtr});     % h_a:[P x K]  h_b:[K x K]

% --- (1) pooled whole-hemisphere R^2 vs rank (= Zhiwen explained_var5) ---
h_poolR2 = nan(h_K,1);
for n = 1:h_K
    h_Yhat = h_Xte * h_b(:,1:n) * h_a(:,1:n)';    % [nTe x P]
    h_poolR2(n) = sseExplainedCal(h_Yte(:)', h_Yhat(:)');
end

% --- (3) PRIMARY-pixel R^2 vs rank = predicted ipsi FIELD averaged over the
%     recording-kernel footprint, scored against y_full (the real trace).
%   The kernel-mean ipsi signal is reconstructed full-resolution from the ipsi SVD
%   (h_meanU * V_ipsi). Its field readout through the canonical latents IS the
%   kernel-average of the per-pixel loadings: a_kern = scores \ kernel-mean.
%   CanonCor2's canonical scores are orthonormal on the train set, so the rank-n
%   truncation a_kern(1:n) matches the field's a(:,1:n) exactly -- i.e. this is
%   "predict the field, then average the kernel pixels", not a free OLS to y_full.
%   It does NOT enter the RRR fit, so (1)/(2) stay byte-identical.
h_scoresTr = h_Xtr * h_b;                            % [nTr x K] canonical latents (orthonormal/train)
h_scoresTe = h_Xte * h_b;                            % [nTe x K]
h_sKernTr  = (h_meanU * V_ipsi_full(1:h_K, h_tr))';  % [nTr x 1] kernel-mean ipsi dF (train)
h_aKern    = h_scoresTr \ h_sKernTr;                 % [K x 1] field loading for the kernel mean
h_yte      = y_full(h_te);
h_kernR2   = nan(h_K,1);
for n = 1:h_K
    h_yhatF     = h_scoresTe(:,1:n) * h_aKern(1:n);  % predicted kernel-mean raw dF [nTe x 1]
    h_yhatdF    = h_yhatF / h_mI_kern * 100;         % -> %dF/F (getpixel_dFoF norm; cancels in R^2)
    h_kernR2(n) = sseExplainedCal(h_yte(:)', h_yhatdF(:)');
end

% --- (2) per-pixel R^2 map at h_rankMark ---
h_YhatM  = h_Xte * h_b(:,1:h_rankMark) * h_a(:,1:h_rankMark)';
h_perpix = sseExplainedCal(h_Yte', h_YhatM');     % [P x 1]

[h_poolPk, h_ipk] = max(h_poolR2);
[h_kernPk, h_kpk] = max(h_kernR2);
fprintf(['[CP-HEMI] POOLED ipsi-hemi R^2: rank%d=%.3f | peak=%.3f@rank%d  ' ...
         '(Zhiwen ~0.99)\n'], h_rankMark, h_poolR2(h_rankMark), h_poolPk, h_ipk);
fprintf(['[CP-HEMI] PRIMARY pixel (field->kernel-avg vs y_full) R^2: ' ...
         'rank%d=%.3f | peak=%.3f@rank%d\n'], ...
         h_rankMark, h_kernR2(h_rankMark), h_kernPk, h_kpk);

% --- figure: R^2 vs rank (pooled hemi vs raw pixel) ---
h_fig = paperFig(8, 6);
h_ax  = axes(h_fig, 'Position', [0.14 0.16 0.82 0.78]); hold(h_ax,'on');
plot(h_ax, 1:h_K, h_poolR2, '-o', 'Color',[0.1 0.5 0.8], 'MarkerSize',3, ...
     'LineWidth',1.5, 'DisplayName','pooled ipsi-hemi');
plot(h_ax, 1:h_K, h_kernR2,  '-s', 'Color',[0.85 0.3 0.1], 'MarkerSize',3, ...
     'LineWidth',1.5, 'DisplayName','primary pixel (field\rightarrowkernel avg)');
yline(h_ax, 0.99, 'k--', 'LineWidth',1.0, 'HandleVisibility','off');
xline(h_ax, h_rankMark, ':', 'Color',[0.4 0.4 0.4], 'HandleVisibility','off');
xlabel(h_ax, 'rank (# components)', 'FontWeight','bold','FontSize',6);
ylabel(h_ax, 'held-out R^2', 'FontWeight','bold','FontSize',6);
ylim(h_ax,[0 1]); xlim(h_ax,[1 h_K]);
h_lg = legend(h_ax, 'Location','southeast', 'FontSize',5);
h_lg.ItemTokenSize = [6 6];
title(h_ax, 'Contra\rightarrowipsi prediction vs rank', 'FontSize',6,'FontWeight','bold');
hold(h_ax,'off');
paperExport(h_fig, fullfile(paper_root, 'cp_hemi_rank.png'));

% --- figure: per-pixel R^2 map (nearest-fill the sparse scored pixels) ------------
% h_perpix is scored on the DOWNSAMPLED ipsi set (~h_maxPix px); painting only
% those sparse pixels left the map ~blank (each was 1/N of the image). Nearest-
% neighbour fill to the full ipsi mask so the hemisphere renders as a dense map.
h_full_ipsi      = find(h_ipsi_mask(:));
[h_iy_s, h_ix_s] = ind2sub([nY_cp,nX_cp], h_idx_ipsi(:));
[h_iy_a, h_ix_a] = ind2sub([nY_cp,nX_cp], h_full_ipsi);
h_gd  = isfinite(h_perpix(:));
h_Fnn = scatteredInterpolant(double(h_ix_s(h_gd)), double(h_iy_s(h_gd)), ...
                             h_perpix(h_gd), 'nearest', 'nearest');
h_r2img = nan(nY_cp*nX_cp, 1);
h_r2img(h_full_ipsi) = h_Fnn(double(h_ix_a), double(h_iy_a));
h_r2map = reshape(h_r2img, nY_cp, nX_cp)';
h_fig2  = figure('Color','w','Name','[CP-HEMI] per-pixel R^2');
h_fig2.Units='centimeters'; h_fig2.Position=[0 0 10 8];
h_im = imagesc(h_r2map); set(h_im, 'AlphaData', ~isnan(h_r2map));
axis image off; colormap(parula); clim([0 1]);
cb = colorbar; ylabel(cb, sprintf('R^2 (rank %d)', h_rankMark), 'FontWeight','bold');
title(sprintf('[CP-HEMI] ipsi per-pixel R^2  (pooled=%.3f)', h_poolR2(h_rankMark)));
paperExport(h_fig2, fullfile(paper_root, 'cp_hemi_r2map.png'));

% --- predicted vs actual PRIMARY-PIXEL trace over the held-out test block ----------
% Predict the recording pixel (field->kernel readout) at the best held-out rank,
% split the test block into fixed-length segments ("trials"), score each.
h_kbest   = h_kpk;                                          % rank with best held-out R^2
h_yhat_te = (h_scoresTe(:,1:h_kbest) * h_aKern(1:h_kbest)) / h_mI_kern * 100;  % [nTe x 1] %dF/F
h_yact_te = y_full(h_te);                                   % actual primary pixel %dF/F
h_segL   = round(3*Fs);
h_nSeg   = floor(numel(h_te) / max(h_segL,1));
h_segR2  = nan(max(h_nSeg,0),1);   % raw (offset penalised, matches h_kernR2)
h_segR2b = nan(max(h_nSeg,0),1);   % per-segment baseline-removed ("shape", offset-invariant)
h_numB = 0;  h_denB = 0;
for s = 1:h_nSeg
    idx = (s-1)*h_segL + (1:h_segL);
    ya  = h_yact_te(idx);  yh = h_yhat_te(idx);
    yac = ya - mean(ya,'omitnan');  yhc = yh - mean(yh,'omitnan');
    h_segR2(s)  = 1 - sum((ya-yh).^2,'omitnan')   / max(sum(yac.^2,'omitnan'), eps);
    h_segR2b(s) = 1 - sum((yac-yhc).^2,'omitnan') / max(sum(yac.^2,'omitnan'), eps);
    h_numB = h_numB + sum((yac-yhc).^2,'omitnan');  h_denB = h_denB + sum(yac.^2,'omitnan');
end
h_poolB = 1 - h_numB / max(h_denB, eps);          % pooled baseline-removed primary-pixel R^2
h_tseg  = (0:h_segL-1)/Fs;
fprintf(['[CP-HEMI] PRIMARY pixel R^2: raw=%.3f | per-segment baseline-removed=%.3f\n' ...
         '          (the gap is slow per-segment drift -> a level shift the residual\n' ...
         '           pipeline removes per-trial, so the science is unaffected)\n'], ...
         h_kernPk, h_poolB);

if h_nSeg >= 2
    % --- figure: prediction on example held-out segments --------------------------
    h_pick = unique(round(linspace(1, h_nSeg, min(6,h_nSeg))));
    h_fig3 = paperFig(20, 10);  h_nP = numel(h_pick);  h_nc = ceil(h_nP/2);
    for kk = 1:h_nP
        ax = subplot(2, h_nc, kk); hold(ax,'on');
        s = h_pick(kk); idx = (s-1)*h_segL + (1:h_segL);
        ya = h_yact_te(idx);  yh = h_yhat_te(idx);   % each centred on its OWN mean -> shape
        plot(ax, h_tseg, ya-mean(ya,'omitnan'), 'Color',[0.1 0.1 0.1], 'LineWidth',1.2, 'DisplayName','actual');
        plot(ax, h_tseg, yh-mean(yh,'omitnan'), 'Color',[0.85 0.3 0.1], 'LineWidth',1.2, 'DisplayName','contra pred');
        title(ax, sprintf('seg %d   R^2=%.2f (shape %.2f)', s, h_segR2(s), h_segR2b(s)), 'FontSize',6,'FontWeight','bold');
        set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
        if mod(kk-1,h_nc)==0, ylabel(ax,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold'); end
        if kk > h_nP-h_nc, xlabel(ax,'time (s)','FontSize',6,'FontWeight','bold'); end
        if kk==1, lg=legend(ax,'Location','best','FontSize',5); lg.ItemTokenSize=[6 6]; end
    end
    sgtitle(h_fig3, sprintf('[CP-HEMI] contra->primary-pixel prediction, example held-out segments (rank %d)', h_kbest), ...
        'FontSize',7,'FontWeight','bold','Interpreter','none');
    paperExport(h_fig3, fullfile(paper_root, 'cp_hemi_examples.png'));

    % --- figure: best vs worst held-out segments ---------------------------------
    h_fin = find(isfinite(h_segR2));
    [~, h_si] = sort(h_segR2(h_fin), 'descend');
    h_ord = h_fin(h_si);
    h_nbw = min(3, floor(numel(h_ord)/2));
    h_bw  = [h_ord(1:h_nbw); h_ord(end-h_nbw+1:end)];
    h_lbl = [repmat({'BEST'},h_nbw,1); repmat({'WORST'},h_nbw,1)];
    h_fig4 = paperFig(20, 9);
    for kk = 1:numel(h_bw)
        ax = subplot(2, h_nbw, kk); hold(ax,'on');
        s = h_bw(kk); idx = (s-1)*h_segL + (1:h_segL);
        ya = h_yact_te(idx);  yh = h_yhat_te(idx);   % each centred on its OWN mean -> shape
        plot(ax, h_tseg, ya-mean(ya,'omitnan'), 'Color',[0.1 0.1 0.1], 'LineWidth',1.2);
        plot(ax, h_tseg, yh-mean(yh,'omitnan'), 'Color',[0.85 0.3 0.1], 'LineWidth',1.2);
        title(ax, sprintf('%s seg %d   R^2=%.2f (shape %.2f)', h_lbl{kk}, s, h_segR2(s), h_segR2b(s)), 'FontSize',6,'FontWeight','bold');
        set(ax,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
        if mod(kk-1,h_nbw)==0, ylabel(ax,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold'); end
        if kk > h_nbw, xlabel(ax,'time (s)','FontSize',6,'FontWeight','bold'); end
    end
    sgtitle(h_fig4, sprintf('[CP-HEMI] best vs worst segments (rank %d) -- traces on own mean; R^2 raw, shape=offset-removed', h_kbest), ...
        'FontSize',7,'FontWeight','bold','Interpreter','none');
    paperExport(h_fig4, fullfile(paper_root, 'cp_hemi_bestworst.png'));
end

fprintf('[CP-HEMI] exported cp_hemi_rank/r2map/examples/bestworst .png\n');


%% [CP-KERNEL] Contra weight map: pixels most predictive of the ipsi primary pixel
% Back-project the deployed HEMI readout's contra-mode weights into pixel space
% (Ye et al. 2023 Fig 3D-G analog). The readout at rank n is
%   yhat = (X_zscored * h_b(:,1:n)) * h_aKern(1:n),
% so the weight on the z-scored contra modes is h_b(:,1:n)*h_aKern(1:n); dividing by
% the train per-mode std expresses it on the RAW V_c_full modes -> the same basis as
% the cached contra spatial loadings U_svd_raw, giving a signed per-pixel weight map.
h_nmap  = h_kbest;                                         % deployed rank (best held-out R^2)
h_sdtr  = std(V_c_full(1:h_K, h_tr), [], 2);  h_sdtr(h_sdtr==0) = 1;
h_wz    = h_b(:, 1:h_nmap) * h_aKern(1:h_nmap);           % weight on z-scored modes  [K x 1]
h_wraw  = h_wz ./ h_sdtr;                                 % weight on RAW contra modes [K x 1]
h_idx_c = find(valid_cp_svd(:));                          % contra pixels (== U_svd_raw rows)
h_pixw  = U_svd_raw(:, 1:h_K) * h_wraw;                   % [nPix_contra x 1] signed
h_km    = nan(nY_cp, nX_cp);  h_km(h_idx_c) = h_pixw;

[h_figK, ~, h_axK] = brain_overlay_fig(mimg_cp, 8, 6);
h_wlim   = prctile(abs(h_pixw), 99);  if h_wlim < eps; h_wlim = 1; end
h_kmT    = h_km';                                         % transposed display (matches brain bg)
h_alphaK = min(1, abs(h_kmT)./h_wlim);  h_alphaK(isnan(h_alphaK)) = 0;
h_imK = imagesc(h_axK, h_kmT);  set(h_imK, 'AlphaData', h_alphaK);
nC = 256; nHalf = ceil(nC/2);                            % blue->white->red diverging (no toolbox)
h_cmapK = [ linspace(0.23,1,nHalf)', linspace(0.30,1,nHalf)', linspace(0.75,1,nHalf)'; ...
            linspace(1,0.80,nC-nHalf)', linspace(1,0.10,nC-nHalf)', linspace(1,0.10,nC-nHalf)' ];
colormap(h_axK, h_cmapK);  clim(h_axK, [-h_wlim, h_wlim]);
plot(h_axK, py_prim, px_prim, 'k+', 'MarkerSize',8, 'LineWidth',1.5, 'HandleVisibility','off');
title(h_axK, sprintf('Contra weights predictive of ipsi primary pixel (rank %d)', h_nmap), ...
    'FontSize',6,'FontWeight','bold');
h_cbK = colorbar(h_axK, 'Position',[0.80 0.12 0.05 0.72]);
ylabel(h_cbK, 'predictive weight (a.u.)', 'FontSize',5,'FontWeight','bold');
hold(h_axK,'off');
paperExport(h_figK, fullfile(paper_root, 'cp_hemi_kernel_map.png'));
fprintf('[CP-KERNEL] exported cp_hemi_kernel_map.png (rank %d, |w| 99pct=%.3g)\n', h_nmap, h_wlim);

% --- secondary: squared "energy" map (sign-agnostic localization; sharpens focal vs diffuse) ---
h_pixw2 = h_pixw.^2;
h_km2   = nan(nY_cp, nX_cp);  h_km2(h_idx_c) = h_pixw2;
[h_figK2, ~, h_axK2] = brain_overlay_fig(mimg_cp, 8, 6);
h_wlim2  = prctile(h_pixw2, 99);  if h_wlim2 < eps; h_wlim2 = 1; end
h_km2T   = h_km2';
h_alpha2 = min(1, h_km2T ./ h_wlim2);  h_alpha2(isnan(h_alpha2)) = 0;
h_imK2 = imagesc(h_axK2, h_km2T);  set(h_imK2, 'AlphaData', h_alpha2);
h_cmap2 = [linspace(1,0.85,256)', linspace(1,0.10,256)', linspace(1,0.10,256)'];   % white -> red
colormap(h_axK2, h_cmap2);  clim(h_axK2, [0, h_wlim2]);
plot(h_axK2, py_prim, px_prim, 'k+', 'MarkerSize',8, 'LineWidth',1.5, 'HandleVisibility','off');
title(h_axK2, sprintf('Contra predictive ENERGY (w^2, rank %d)', h_nmap), 'FontSize',6,'FontWeight','bold');
h_cbK2 = colorbar(h_axK2, 'Position',[0.80 0.12 0.05 0.72]);
ylabel(h_cbK2, 'weight^2 (a.u.)', 'FontSize',5,'FontWeight','bold');
hold(h_axK2,'off');
paperExport(h_figK2, fullfile(paper_root, 'cp_hemi_kernel_map_sq.png'));
fprintf('[CP-KERNEL] exported cp_hemi_kernel_map_sq.png (secondary energy view)\n');

% --- dump compact rank-K fit products for the interactive kernel explorer ----------
% cp_kernel_explorer(matfile) back-projects ANY clicked ipsi pixel's contra weight
% map through these (pixel-agnostic) products -- one matvec per click, ~70 MB, no raw
% SVD. Chain: aKern = M1*meanU';  w = (h_b(:,1:n)*aKern(1:n))./sd;  pixw = U_svd_raw*w.
h_M1 = h_scoresTr \ (V_ipsi_full(1:h_K, h_tr)).';          % [K x K]  (aKern = M1*meanU')
expl = struct( ...
    'U_svd_raw_K',  U_svd_raw(:, 1:h_K), ...               % [nContra x K] contra spatial loadings
    'U_ipsi_raw_K', U_ipsi_raw(:, 1:h_K), ...              % [nIpsi   x K] ipsi  spatial loadings
    'M1',           h_M1, ...                              % [K x K]
    'h_b_K',        h_b(:, 1:h_K), ...                     % [K x K] CanonCor2 b
    'sd_tr',        h_sdtr(:), ...                         % [K x 1] train per-mode std
    'idx_contra',   h_idx_c, ...                           % contra linear idx (U_svd_raw rows)
    'full_idx',     h_full_idx, ...                        % ipsi  linear idx (U_ipsi_raw rows)
    'mimg',         mimg_cp, 'nY', nY_cp, 'nX', nX_cp, ...
    'k_prim',       k_prim, 'px_prim', px_prim, 'py_prim', py_prim, ...
    'nmap',         h_nmap, 'K', h_K);
h_expl_file = fullfile(dataDir, sprintf('cp_kernel_explorer_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
save(h_expl_file, '-struct', 'expl', '-v7.3');
fprintf('[CP-KERNEL] explorer products -> %s\n', h_expl_file);
fprintf('           launch:  cp_kernel_explorer(''%s'')\n', h_expl_file);


%% [CP-BLEED] Impulse-bleed map: which contra pixels are input-affected, and how far
% For every contra pixel, test whether its trial-averaged peri-stim response is
% amplitude-graded -- the dose-response slope beta over amps 0..5 is the input-effect
% strength. Significance from an amplitude-LABEL permutation null (shuffles the amp
% tag across trials, breaking the amp<->response link while keeping each trial's
% response + its slow-signal autocorrelation intact), then Benjamini-Hochberg FDR
% across pixels. Response = mean dF/F over [0,200] ms post-onset minus a [-500,0] ms
% pre-onset baseline (same 0-200 ms window as the inhibition energy). Expectation:
% |beta| decays with distance from the primary pixel.

b_post_s = 0.200;     % post-onset response window (s) -- inhibition-energy window
b_pre_s  = 0.500;     % pre-onset baseline window (s)
b_nPerm  = 1000;      % amplitude-label permutations for the null
b_q      = 0.05;      % BH-FDR level
rng(7);               % reproducible permutations

% --- per-amp stim onsets INCLUDING amp 0 (catch); times -> frame indices ----------
b_onset_t = [];  b_amp = [];
for ia = 1:numel(uAmp_cp)
    bs = imp_data.startTimes{ia}(:);
    b_onset_t = [b_onset_t; bs];                                          %#ok<AGROW>
    b_amp     = [b_amp; repmat(double(uAmp_cp(ia)), numel(bs), 1)];       %#ok<AGROW>
end
b_onf = zeros(numel(b_onset_t), 1);
for j = 1:numel(b_onset_t)
    [~, b_onf(j)] = min(abs(t_full - b_onset_t(j)));
end
b_post = round(b_post_s * Fs);
b_pre  = round(b_pre_s  * Fs);
b_Tend = min(nF_m, size(V_cp, 2));
b_keep = (b_onf - b_pre >= 1) & (b_onf + b_post <= b_Tend);
b_onf  = b_onf(b_keep);  b_amp = b_amp(b_keep);
nTrial = numel(b_onf);

% --- per-trial response in contra-mode space: dv = mean(V_post) - mean(V_pre) ------
% r(pixel,trial) = (U_contra * dv) ./ mimg_contra * 100   (getpixel_dFoF mode-1 dF/F)
b_idx_c = find(valid_cp_svd(:));
Uflat   = reshape(U_cp, nY_cp*nX_cp, nSV_cp);
b_Uc    = double(Uflat(b_idx_c, :));                 % [nContra x nSV]
b_mI    = mimg_cp(b_idx_c);  b_mI(b_mI == 0) = eps;  % [nContra x 1]
b_dv = zeros(nSV_cp, nTrial);
for j = 1:nTrial
    o = b_onf(j);
    b_dv(:,j) = mean(double(V_cp(:, o:o+b_post)), 2) - mean(double(V_cp(:, o-b_pre:o-1)), 2);
end
b_R  = (b_Uc * b_dv) ./ b_mI * 100;                  % [nContra x nTrial] dF/F response
b_Rc = b_R - mean(b_R, 2);                           % center over trials
clear b_R

% --- dose-response slope beta per contra pixel ------------------------------------
b_ac    = b_amp - mean(b_amp);                       % [nTrial x 1]
b_den   = b_ac.' * b_ac;
b_beta  = (b_Rc * b_ac) / b_den;                     % [nContra x 1]
b_abeta = abs(b_beta);

% --- amplitude-label permutation null -> two-tailed p -----------------------------
b_cnt = zeros(size(b_beta));
for s = 1:b_nPerm
    ac    = b_amp(randperm(nTrial)) - mean(b_amp);
    bs    = (b_Rc * ac) / (ac.' * ac);
    b_cnt = b_cnt + (abs(bs) >= b_abeta);
end
b_p = (b_cnt + 1) / (b_nPerm + 1);

% --- sanity: primary pixel (ipsi) should be strongly amp-graded (positive control) -
b_kr = (px_prim-k_prim):(px_prim+k_prim);  b_kr = b_kr(b_kr>=1 & b_kr<=nY_cp);
b_kc = (py_prim-k_prim):(py_prim+k_prim);  b_kc = b_kc(b_kc>=1 & b_kc<=nX_cp);
[BKR,BKC] = ndgrid(b_kr, b_kc);
b_pidx = sub2ind([nY_cp,nX_cp], BKR(:), BKC(:));
b_mIp  = mean(mimg_cp(b_kr,b_kc), 'all');
b_rp   = (mean(double(Uflat(b_pidx,:)),1) * b_dv) / b_mIp * 100;   % [1 x nTrial]
b_rpc  = b_rp - mean(b_rp);
b_bp   = (b_rpc * b_ac) / b_den;
b_cps  = 0;
for s = 1:b_nPerm
    ac = b_amp(randperm(nTrial)) - mean(b_amp);
    b_cps = b_cps + (abs((b_rpc*ac)/(ac.'*ac)) >= abs(b_bp));
end
clear b_Uc b_dv

% --- Benjamini-Hochberg FDR across contra pixels ----------------------------------
[b_ps, b_oi] = sort(b_p);
b_m   = numel(b_p);
b_thr = (1:b_m).' / b_m * b_q;
b_cut = find(b_ps <= b_thr, 1, 'last');
b_sig = false(b_m, 1);
if ~isempty(b_cut);  b_sig(b_oi(1:b_cut)) = true;  end
fprintf('[CP-BLEED] %d trials (amps %s) | %d/%d contra px input-affected (FDR q<%.2f)\n', ...
        nTrial, num2str(unique(b_amp).'), nnz(b_sig), b_m, b_q);
fprintf('[CP-BLEED] sanity: primary-pixel beta=%.3g (p=%.4f) -- positive control\n', ...
        b_bp, (b_cps+1)/(b_nPerm+1));

% --- map: signed dose-response slope; FDR-significant pixels opaque ----------------
b_km  = nan(nY_cp, nX_cp);  b_km(b_idx_c) = b_beta;
[b_fig1, ~, b_ax1] = brain_overlay_fig(mimg_cp, 8, 6);
b_lim = prctile(abs(b_beta), 99);  if b_lim < eps; b_lim = 1; end
b_kmT = b_km';
b_al  = zeros(nY_cp, nX_cp);  b_al(b_idx_c) = 0.30;  b_al(b_idx_c(b_sig)) = 1.0;
b_alT = b_al';  b_alT(isnan(b_kmT)) = 0;
b_im1 = imagesc(b_ax1, b_kmT);  set(b_im1, 'AlphaData', b_alT);
nCb = 256; nHb = ceil(nCb/2);                        % blue->white->red diverging
b_cmap = [ linspace(0.23,1,nHb)', linspace(0.30,1,nHb)', linspace(0.75,1,nHb)'; ...
           linspace(1,0.80,nCb-nHb)', linspace(1,0.10,nCb-nHb)', linspace(1,0.10,nCb-nHb)' ];
colormap(b_ax1, b_cmap);  clim(b_ax1, [-b_lim, b_lim]);
plot(b_ax1, py_prim, px_prim, 'g+', 'MarkerSize',8, 'LineWidth',1.5, 'HandleVisibility','off');
title(b_ax1, 'Impulse-bleed: dose-response slope \beta (opaque = FDR sig.)', ...
      'FontSize',6, 'FontWeight','bold');
b_cb = colorbar(b_ax1, 'Position',[0.80 0.12 0.05 0.72]);
ylabel(b_cb, '\beta (dF/F per amp)', 'FontSize',5, 'FontWeight','bold');
hold(b_ax1, 'off');
paperExport(b_fig1, fullfile(paper_root, 'cp_bleed_slope_map.png'));

% --- decay: |beta| and % FDR-significant vs distance from the primary pixel --------
[b_rr, b_cc] = ind2sub([nY_cp, nX_cp], b_idx_c);
b_dist  = hypot(b_rr - px_prim, b_cc - py_prim);     % px from primary pixel
b_edges = linspace(0, max(b_dist), 16);
b_ctr   = 0.5*(b_edges(1:end-1) + b_edges(2:end));
b_mB = nan(numel(b_ctr),1);  b_sB = nan(numel(b_ctr),1);  b_fS = nan(numel(b_ctr),1);
for k = 1:numel(b_ctr)
    mm = b_dist >= b_edges(k) & b_dist < b_edges(k+1);
    if any(mm)
        b_mB(k) = mean(b_abeta(mm));
        b_sB(k) = std(b_abeta(mm)) / sqrt(nnz(mm));
        b_fS(k) = 100 * mean(b_sig(mm));
    end
end
b_fig2 = paperFig(8, 6);  b_ax2 = axes('Parent', b_fig2);
yyaxis(b_ax2, 'left');
errorbar(b_ax2, b_ctr, b_mB, b_sB, 'o-', 'LineWidth',1.2, 'MarkerSize',3);
ylabel(b_ax2, 'mean |\beta|  (dF/F per amp)', 'FontSize',6, 'FontWeight','bold');
yyaxis(b_ax2, 'right');
plot(b_ax2, b_ctr, b_fS, 's--', 'LineWidth',1.0, 'MarkerSize',3);
ylabel(b_ax2, '% pixels FDR-significant', 'FontSize',6, 'FontWeight','bold');
xlabel(b_ax2, 'distance from primary pixel (px)', 'FontSize',6, 'FontWeight','bold');
title(b_ax2, 'Impulse-bleed decay vs distance', 'FontSize',6, 'FontWeight','bold');
set(b_ax2, 'FontSize',6, 'FontWeight','bold');
paperExport(b_fig2, fullfile(paper_root, 'cp_bleed_decay.png'));
fprintf('[CP-BLEED] exported cp_bleed_slope_map.png + cp_bleed_decay.png\n');

% --- params for the interactive WHOLE-BRAIN bleed explorer (uses the FLIPPED primary) ---
% cp_bleed_explorer reloads the SVD and recomputes beta per pixel for any time window
% live (cumsum-of-V window means -> one matvec/update); permutation+FDR on a button.
% The flipped primary (row<->col swap) is the marker + distance reference, per the
% user's decision to treat the transposed pixel as the recording site.
bx = struct('mn',mn, 'td',td, 'en',en, 'nSV_load',nSV_load, ...
            'onf',b_onf, 'amp',b_amp, 'brain_idx',find(brain_mask_cp(:)), ...
            'prim_row',py_prim, 'prim_col',px_prim, ...   % FLIPPED: row=py_prim, col=px_prim
            'k_prim',k_prim, 'Fs',Fs, 'nY',nY_cp, 'nX',nX_cp, 'dur_imp',dur_imp);
bx_file = fullfile(dataDir, sprintf('cp_bleed_explorer_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en));
save(bx_file, '-struct', 'bx');
fprintf('[CP-BLEED] explorer params -> %s\n', bx_file);
fprintf('           launch:  cp_bleed_explorer(''%s'')\n', bx_file);


%%

% kernel explorer (self-contained ~70 MB .mat, opens instantly)
cp_kernel_explorer('C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis\data\cp_kernel_explorer_AL_0033_0129_e1.mat')
%%
% bleed explorer (reloads the SVD via loadUVt -> ~30 s to open)
cp_bleed_explorer('C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis\data\cp_bleed_explorer_AL_0033_0129_e1.mat')


% =====================================================================================
% RESIDUAL + STATE-DEPENDENCE WORKBENCH  (merged from contra_residual.m, 2026-06-26)
% =====================================================================================
% Sectioned residual-analysis workbench for the contra->ipsi LOCAL stim effect.
% Run [CP-SETUP] first (builds R, S, and the Actual/Global/Local decomposition),
% then run any section below on its own (Ctrl+Enter), in any order:
%   [CP-RESi]   clickable per-trial inspector (actual / contra-pred / residual / motion)
%   [CP-LOCAL]  overview: where each state's effect lives (GLOBAL=contra vs LOCAL=residual)
%   [CP-MOTION] motion-only effect (No-motion vs Motion: predictability + mean dip)
%   [CP-MOTION-AMP] per-amplitude motion vs |dip dev| (fig-3 style, large fonts; amp_sig switch)
%   [CP-VAR]    pre-stim variance-only effect (scatter + dose-response + partial)
%   [CP-DELTA]  pre-stim 1-4 Hz delta-only effect
%
% Shared pipeline: utils/cp_residual_core.m (the SAME cp_hemi_predictor field->kernel
% map used by [CP-HEMI] above — no separate prediction). Helpers: utils/cp_agl.m
% (decomposition), utils/cp_cont_state.m (continuous-state figure), utils/cp_res_inspector.m.
% Cross-session batch: cp_state_batch.m.
% Concept: the trial-average ipsi dip ~ a low-dim LTI/SISO impulse response; contra
% predicts the GLOBAL activity flowing into the ipsi kernel; residual = LOCAL stim
% effect; the question is whether that local effect is brain-state dependent.
%
% Metric (ported from motion_analysis.m fig 6): |dip - amplitude-mean| = single-trial
% deviation from the trial-average (lower = more predictable). Split per trial into
%   dA = actual (= fig 6, global+local) | dG = contra pred (GLOBAL) | dL = residual (LOCAL).
%
% Presettable before [CP-SETUP]:
%   selExp     (3)     — experiment index
%   decontam   (false) — bleed comp OFF (cancels in within-amp state metrics)
%   use_motion (false) — keep motion OUT of the contra map so it can be tested as a
%                        state in [CP-MOTION]; variance/delta unaffected (R² 0.899 vs 0.900)

%% [CP-SETUP] Build residual + Actual/Global/Local decomposition — RUN THIS FIRST
close all;
wrap_path = mfilename('fullpath');
if isempty(wrap_path), wrap_path = fullfile(pwd, 'contra_prediction.m'); end
addpath(genpath(fullfile(fileparts(wrap_path), '..', 'utils')));

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('contra_prediction [CP-SETUP]: run load_experiments.m first.');
end
if ~exist('selExp','var')     || isempty(selExp),     selExp     = 3;     end
if ~exist('decontam','var')   || isempty(decontam),   decontam   = false; end
if ~exist('use_motion','var') || isempty(use_motion), use_motion = false; end
if ~exist('predictor','var')  || isempty(predictor),  predictor  = 'hemi'; end  % 'hemi' | 'ols'

opts  = struct('decontam', decontam, 'use_motion', use_motion, ...
               'make_wide', true, 'plot', false, 'predictor', predictor);
[R, S] = cp_residual_core(allExperiments, selExp, opts);

% Per-trial fig-6 deviation (z-within-amp) for Actual/Global/Local + pooled dip traces.
[dA, dG, dL, trA, trG, trL] = cp_agl(R);
AGL = {'Actual (fig6)', dA; 'Global (contra)', dG; 'Local (residual)', dL};

if R.use_motion
    warning(['[CP-SETUP] use_motion=true regresses motion out of the residual; the ' ...
             '[CP-MOTION] test will be biased. Set use_motion=false and re-run.']);
end
fprintf('\n[CP-SETUP] %s %s e%d | decontam=%d motion=%d | held-out R²=%.3f\n', ...
    R.mn, R.td, R.en, R.decontam, R.use_motion, R.cv_mean);
fprintf('  partial(dev_stim, state | dev_pre):  Motion %+.3f (p=%.3g) | PreVar %+.3f (p=%.3g) | PreDelta %+.3f (p=%.3g)\n', ...
    S.r_partial(1), S.p_partial(1), S.r_partial(2), S.p_partial(2), S.r_partial(3), S.p_partial(3));
fprintf('  -> now run any of: [CP-RESi] [CP-LOCAL] [CP-MOTION] [CP-VAR] [CP-DELTA]\n');

%% [CP-RESi] Clickable inspector — click a trial: actual / contra-pred / residual / motion
if ~exist('R','var'), error('Run [CP-SETUP] first.'); end
if isempty(R.Sin)
    warning('[CP-RESi] no inspector payload (make_wide was off). Re-run [CP-SETUP].');
else
    cp_res_inspector(R.Sin);
    fprintf('[CP-RESi] Inspector open — click a scatter point (snaps to nearest trial).\n');
end

%% [CP-LOCAL] Overview: where each state effect lives (GLOBAL contra vs LOCAL residual)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
states = {'Motion',  'Motion (z)',         R.mot, R.okM; ...
          'PreVar',  'Pre-stim var (z)',   R.pv,  R.okV; ...
          'PreDelta','Pre-stim \delta (z)',R.dp,  R.okD};
fprintf('\n[CP-LOCAL] Spearman rho of |dip dev| with each state (z-within-amp):\n');
fprintf('  %-9s  Actual   Global   Local\n', 'state');
for s = 1:3
    rr = nan(1,3);
    for c = 1:3
        m = states{s,4} & isfinite(AGL{c,2});
        rr(c) = corr(AGL{c,2}(m), states{s,3}(m), 'type','Spearman','rows','complete');
    end
    fprintf('  %-9s  %+.3f   %+.3f   %+.3f\n', states{s,1}, rr(1), rr(2), rr(3));
end
figL = paperFig(18, 14);
for s = 1:3
    for c = 1:3
        axL = subplot(3,3,(s-1)*3+c); hold(axL,'on');
        m = states{s,4} & isfinite(AGL{c,2}); xv = states{s,3}(m); yv = AGL{c,2}(m);
        scatter(axL, xv, yv, 6, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha',0.3);
        if numel(xv) > 2
            pc = polyfit(xv,yv,1); xl = [min(xv) max(xv)];
            plot(axL, xl, polyval(pc,xl), 'r-', 'LineWidth',1.0);
            [rv,pp] = corr(xv,yv,'type','Spearman');
            title(axL, sprintf('%s  \\rho=%+.2f p=%.2g', AGL{c,1}, rv, pp), 'FontSize',5,'FontWeight','bold');
        end
        set(axL,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold');
        if s==3, xlabel(axL, states{s,2}, 'FontSize',5,'FontWeight','bold'); end
        if c==1, ylabel(axL, sprintf('%s\n|dip dev| (z)', states{s,2}), 'FontSize',5,'FontWeight','bold'); end
    end
end
sgtitle(figL, sprintf('CP-LOCAL overview  %s %s e%d  (rows=state, cols=Actual/Global/Local)', ...
    R.mn, R.td, R.en), 'FontSize',6,'FontWeight','bold','Interpreter','tex');
paperExport(figL, fullfile(R.paper_root,'images','figure2','cp_local_state.png'));
fprintf('[CP-LOCAL] Exported cp_local_state.png\n');

%% [CP-MOTION] Motion-only: predictability (No-motion vs Motion) + mean dip trace
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
mot = R.mot;  noM = mot <= 0.5;  yesM = mot > 0.5;   % binary split (motion z is zero-inflated; lab motThr_hi=0.5)
[rp,pp_] = partialcorr(R.devS(R.okM), mot(R.okM), R.devP(R.okM), 'type','Spearman','rows','complete');
fprintf('\n[CP-MOTION] partial(dev_stim, motion | dev_pre) rho=%+.3f p=%.3g | n(No/Mot)=%d/%d\n', ...
    rp, pp_, sum(noM), sum(yesM));
clsCol = [0.3 0.55 0.85; 0.85 0.2 0.2];  clsLab = {'No motion','Motion'};  TR = {trA, trG, trL};
figM = paperFig(18, 11);
for c = 1:3
    d = AGL{c,2};  T = TR{c};
    axt = subplot(2,3,c); hold(axt,'on');               % top: |dip dev| No-motion vs Motion
    grp = {d(noM & isfinite(d)), d(yesM & isfinite(d))};
    for q = 1:2
        v = grp{q};  mu = mean(v);  se = std(v)/sqrt(max(numel(v),1));
        bar(axt, q, mu, 0.6, 'FaceColor',clsCol(q,:), 'FaceAlpha',0.55, 'EdgeColor','none');
        errorbar(axt, q, mu, se, 'k', 'LineWidth',1, 'CapSize',5);
    end
    pr = ranksum(grp{1}, grp{2});
    set(axt,'XTick',1:2,'XTickLabel',clsLab,'XLim',[0.4 2.6],'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    title(axt, sprintf('%s  ranksum p=%.2g', AGL{c,1}, pr), 'FontSize',6,'FontWeight','bold');
    if c==1, ylabel(axt, '|dip dev| (z) [lower=predictable]','FontSize',6,'FontWeight','bold'); end
    axb = subplot(2,3,3+c); hold(axb,'on');             % bottom: mean dip trace by motion class
    cls = {noM, yesM};
    for q = 1:2
        idx = cls{q} & any(isfinite(T),2);
        m  = mean(T(idx,:),1,'omitnan');  se = std(T(idx,:),0,1,'omitnan')/sqrt(max(sum(idx),1));
        patch(axb,[R.t_imp,fliplr(R.t_imp)],[m+se,fliplr(m-se)],clsCol(q,:),'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
        plot(axb, R.t_imp, m, 'Color',clsCol(q,:), 'LineWidth',1.2, 'DisplayName',sprintf('%s (n=%d)',clsLab{q},sum(idx)));
    end
    xline(axb,0,'k:','LineWidth',0.5,'HandleVisibility','off'); yline(axb,0,'k--','LineWidth',0.4,'HandleVisibility','off');
    set(axb,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold'); xlabel(axb,'Time re onset (s)','FontSize',6,'FontWeight','bold');
    if c==1, ylabel(axb,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold'); lg=legend(axb,'Location','south','Box','off','FontSize',5); lg.ItemTokenSize=[6 6]; end
end
sgtitle(figM, sprintf('CP-MOTION  %s %s e%d  (top: predictability | bottom: mean dip)  by motion class', ...
    R.mn, R.td, R.en), 'FontSize',6,'FontWeight','bold','Interpreter','tex');
paperExport(figM, fullfile(R.paper_root,'images','figure2','cp_motion_residual.png'));
fprintf('[CP-MOTION] Exported cp_motion_residual.png\n');

%% [CP-MOTION-AMP] Per-amplitude motion vs |dip dev| (figure-3 style, large fonts)
% One subplot per amplitude (within-amp r controls for amplitude). Pick the signal:
%   amp_sig = 'Actual' (= motion_analysis fig 3) | 'Global' (contra) | 'Local' (residual)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
if ~exist('amp_sig','var') || isempty(amp_sig), amp_sig = 'Actual'; end
imp_amp = allExperiments(R.selExp).imp;
switch lower(amp_sig)
    case 'global', SIGc = R.prr_imp;  sName = 'Global (contra)';
    case 'local',  SIGc = R.res_imp;  sName = 'Local (residual)';
    otherwise,     SIGc = R.act_imp;  sName = 'Actual (fig3)';  amp_sig = 'Actual';
end
cp_motion_amp(R, imp_amp, SIGc, sName, sprintf('cp_motion_amp_%s.png', lower(amp_sig)));

%% [CP-VAR] Pre-stim variance-only effect (A/G/L scatter + Local dose-response + partial)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
cp_cont_state('PreVar', 'Pre-stim var (z)', R.pv, AGL, R.devS, R.devP, R.okV, R, 'cp_var_residual.png');

%% [CP-DELTA] Pre-stim 1-4 Hz delta-only effect (A/G/L scatter + Local dose-response + partial)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
cp_cont_state('PreDelta', 'Pre-stim \delta (z)', R.dp, AGL, R.devS, R.devP, R.okD, R, 'cp_delta_residual.png');