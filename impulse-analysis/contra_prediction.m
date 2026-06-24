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
% mfilename('fullpath') is the abs path of THIS running script. Fall back to
% which()/pwd only if pasted into the command window.
cp_path    = mfilename('fullpath');
if isempty(cp_path), cp_path = which('contra_prediction'); end
if isempty(cp_path), cp_path = fullfile(pwd, 'contra_prediction.m'); end
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
brain_mask_cp  = mimg_cp > prctile(mimg_cp(:), 20);

d_tmp    = loadData(serverRoot, mn, td, en);
horizon  = double(d_tmp.params.horizon);
w_r      = horizon - 1;
idx_r_cp = 1:nFrames;
py_prim  = double(d_tmp.params.pixel(1));
px_prim  = double(d_tmp.params.pixel(2));
k_prim   = double(d_tmp.params.kernel);   % recording-kernel half-width (for [CP-HEMI])
mot_full = d_tmp.motion.motion_1(1:2:end);
clear d_tmp

%% Contra ROI definition
% Interactive on first run (or if redefine_roi=true); cached afterward.
% Only the midline and the contra polygon boundary are needed (no pixel grid).
roi_name = sprintf('cp_roi_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en);
roi_file = fullfile(dataDir, roi_name);
fprintf('[CP] ROI cache expected at: %s\n', roi_file);

% Migrate from any known legacy location into data/.
% Checked in priority order: impulseDir, pwd (catches root-level saves when
% mfilename resolved wrong), and parent of impulseDir.
if ~exist(roi_file, 'file')
    for rsd = {impulseDir, pwd, fileparts(impulseDir)}
        candidate = fullfile(rsd{1}, roi_name);
        if ~strcmp(candidate, roi_file) && exist(candidate, 'file')
            movefile(candidate, roi_file);
            fprintf('[CP] Migrated ROI cache: %s\n  -> %s\n', candidate, roi_file);
            break;
        end
    end
end

if redefine_roi && exist(roi_file,'file')
    delete(roi_file);
    fprintf('Deleted existing ROI: %s\n', roi_file);
end

if ~exist(roi_file,'file')
    fig_roi = figure('Color','k','Name','contra_prediction: define midline + contra ROI');
    imagesc(mimg_cp'); colormap(fig_roi, gray);
    clim([prctile(mimg_cp(:),1), prctile(mimg_cp(:),99)]);
    axis image off; hold on;

    title('STEP 1 -- Click 2 MIDLINE points, then Enter', ...
        'Color','w','FontSize',10,'FontWeight','bold');
    [xd1, yd1] = ginput(2);
    x_ml = yd1; y_ml = xd1;
    if abs(y_ml(2)-y_ml(1)) > abs(x_ml(2)-x_ml(1))
        ml_cp.a = (x_ml(2)-x_ml(1))/(y_ml(2)-y_ml(1));
        ml_cp.b = x_ml(1) - ml_cp.a*y_ml(1);
        ml_cp.type = 'x_of_y';
    else
        ml_cp.a = (y_ml(2)-y_ml(1))/(x_ml(2)-x_ml(1));
        ml_cp.b = y_ml(1) - ml_cp.a*x_ml(1);
        ml_cp.type = 'y_of_x';
    end
    ml_cp.img_size = [nY_cp, nX_cp];

    if strcmp(ml_cp.type,'x_of_y')
        t_ml = linspace(1,nY_cp,300);
        plot(t_ml, ml_cp.a*t_ml + ml_cp.b, 'w--','LineWidth',1.5);
    else
        t_ml = linspace(1,nX_cp,300);
        plot(ml_cp.a*t_ml + ml_cp.b, t_ml, 'w--','LineWidth',1.5);
    end

    title('STEP 2 -- Click CONTRALATERAL hemisphere boundary, then Enter', ...
        'Color','c','FontSize',10,'FontWeight','bold');
    [xd2, yd2] = ginput;
    xd2 = [xd2; xd2(1)]; yd2 = [yd2; yd2(1)];
    plot(xd2, yd2, 'c-','LineWidth',1.5);
    drawnow; pause(0.4);
    close(fig_roi);

    poly_col = yd2; poly_row = xd2;
    save(roi_file, 'ml_cp','poly_col','poly_row');
    fprintf('Saved ROI: [%s]\n', roi_file);
else
    tmp      = load(roi_file);
    ml_cp    = tmp.ml_cp;
    poly_col = tmp.poly_col;
    poly_row = tmp.poly_row;
    fprintf('Loaded ROI: [%s]\n', roi_file);
end

% Build contra mask from saved polygon
[xg_s, yg_s] = meshgrid(1:nY_cp, 1:nX_cp);
in_poly_s     = inpolygon(xg_s(:), yg_s(:), poly_row, poly_col);
valid_cp_svd  = reshape(in_poly_s, nX_cp, nY_cp)' & brain_mask_cp;

% -- Pixel map: show contra mask + primary pixel
fig_pmap = figure('Color','k','Name','contra_prediction: contra ROI');
fig_pmap.Units = 'centimeters'; fig_pmap.Position = [0 0 10 8];
ax_pm = axes(fig_pmap,'Position',[0 0 1 0.88]);
imagesc(ax_pm, mimg_cp'); colormap(ax_pm,gray);
clim(ax_pm, [prctile(mimg_cp(:),1), prctile(mimg_cp(:),99)]);
axis(ax_pm,'image','off'); hold(ax_pm,'on');

if strcmp(ml_cp.type,'x_of_y')
    t_ml2 = linspace(1,nY_cp,300);
    plot(ax_pm, t_ml2, ml_cp.a*t_ml2+ml_cp.b, 'w--','LineWidth',1.2);
else
    t_ml2 = linspace(1,nX_cp,300);
    plot(ax_pm, ml_cp.a*t_ml2+ml_cp.b, t_ml2, 'w--','LineWidth',1.2);
end
plot(ax_pm, poly_row, poly_col, 'c-','LineWidth',1.2);

% Overlay the contra mask as a semi-transparent fill
mask_overlay = double(valid_cp_svd);
mask_overlay(~valid_cp_svd) = NaN;
imagesc(ax_pm, mask_overlay', 'AlphaData', 0.25 * ~isnan(mask_overlay'));
colormap(ax_pm, gray);

scatter(ax_pm, py_prim, px_prim, 100, 's','filled', ...
    'MarkerFaceColor',[1 0.3 0.3],'MarkerEdgeColor','w','LineWidth',1.5);
legend(ax_pm, {'Midline','ROI outline','Primary pixel'}, ...
    'TextColor','w','Color','none','EdgeColor','none','FontSize',6,'FontWeight','bold', ...
    'Location','south','Orientation','horizontal');
hold(ax_pm,'off');

%% SVD extraction -- contra predictor signals (V_c_full)
% redoSVD on the full contra-hemisphere mask -> V_c_full (the [CP-HEMI] regressor
% modes) + U_svd_raw (contra spatial map, cached for the future bleed analysis).
% Cached in *_svdraw.mat; computed once.

path_cp      = fullfile(dataDir, sprintf('%scp%s%s%d.mat', mn, td(6:7), td(9:10), en));
path_svd_raw = strrep(path_cp, '.mat', '_svdraw.mat');

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
% PARITY CAVEATS (cannot fully match): no Allen-atlas sensory restriction (we use
% the hand-drawn hemisphere polygon + its complement); confirm AL_0033 SVD is
% hemodynamically corrected like his. Instantaneous (pX=0), matching our finding.
%
% Prereqs (run earlier sections first): U_cp, V_cp, V_c_full, valid_cp_svd,
% brain_mask_cp, y_full, Fs, all_starts_cp/pre_frames (from [CP-FIT]).

h_K        = 50;      % SVD modes per hemisphere (Zhiwen uses 50)
h_maxPix   = 2000;    % cap ipsi pixels (CPU memory); pooled R^2 is ~invariant to it
h_maxFrm   = 60000;   % cap total spontaneous frames used
h_trainFrac= 2/3;     % contiguous early-train / late-test split (~Zhiwen 40k/20k)
h_rankMark = 10;      % rank to highlight (Zhiwen reads ~0.99 here)
h_win_mode = 'interstim'; % spontaneous windowing: 'interstim' = full post-settle gap
                          % between stim starts (lever-1, long windows); 'prestim' = legacy
h_settle_s = 1.0;     % s dropped after each stim for the response to settle (interstim)

% --- ipsi (right) hemisphere mask = brain minus contra polygon ---
h_ipsi_mask = brain_mask_cp & ~valid_cp_svd;
h_idx_ipsi  = find(h_ipsi_mask(:));
if numel(h_idx_ipsi) > h_maxPix          % even stride downsample
    h_stride   = ceil(numel(h_idx_ipsi)/h_maxPix);
    h_idx_ipsi = h_idx_ipsi(1:h_stride:end);
end
fprintf('[CP-HEMI] ipsi mask: %d pixels (after cap %d)\n', numel(h_idx_ipsi), h_maxPix);

% --- ipsi SVD (redoSVD on ipsi pixels), cached like the contra side ---
h_path_ipsi = strrep(path_cp, '.mat', '_svdraw_ipsi.mat');
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

% --- figure: per-pixel R^2 map ---
h_r2img = nan(nY_cp*nX_cp, 1);
h_r2img(h_idx_ipsi) = h_perpix;
h_fig2 = figure('Color','w','Name','[CP-HEMI] per-pixel R^2');
h_fig2.Units='centimeters'; h_fig2.Position=[0 0 10 8];
imagesc(reshape(h_r2img, nY_cp, nX_cp)', 'AlphaData', ~isnan(reshape(h_r2img,nY_cp,nX_cp)'));
axis image off; colormap(parula); clim([0 1]);
cb = colorbar; ylabel(cb, sprintf('R^2 (rank %d)', h_rankMark), 'FontWeight','bold');
title(sprintf('[CP-HEMI] ipsi per-pixel R^2  (pooled=%.3f)', h_poolR2(h_rankMark)));
paperExport(h_fig2, fullfile(paper_root, 'cp_hemi_r2map.png'));
fprintf('[CP-HEMI] exported cp_hemi_rank.png + cp_hemi_r2map.png\n');


