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
nSV_use   = 200;    % contra SVD components used as predictors (z-scored).
                    % nSV sweep at pX=0: 100->0.918, 200->0.930, 500->0.938 but
                    % cond blows up (2.4e6) at 500 -> overfit. 200 = sweet spot.
spont_pre = 6;      % pre-trial spontaneous training window (s)
dur_imp   = 3.0;    % trial window (s)
redefine_roi = false; % set true to force re-draw midline + contra polygon

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

%% SVD extraction -- contra predictor signals (SVD-direct mode only)
% redoSVD on the full contra-hemisphere mask.
% Two-level cache:
%   *_svdraw.mat — full decomposition; computed once.
%   nSV_use      — slice index only; changing it does NOT rerun redoSVD.

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

nSV_actual = min(nSV_use, size(V_c_full, 1));
U_svd_cp   = U_svd_raw(:, 1:nSV_actual);   % [nPix_c × nSV_actual]
X_cp       = V_c_full(1:nSV_actual, :)';   % [nFrames × nSV_actual]
nPred_cp   = nSV_actual;
fprintf('SVD-direct: using %d/%d modes\n', nSV_actual, size(V_c_full,1));

%% Predictor matrix (contra SVD modes only)
% Each contra SVD mode is z-scored (unit variance) so high- and low-index modes
% are on equal footing — without this the Gram matrix is ill-conditioned
% (cond~1e8) because mode 1 variance >> mode N.
% NOTE: motion is deliberately NOT a predictor here. Including motion in the
% baseline regressed the motion-linked component out of cp_err, making the
% downstream motion-state split (CP-6b) partially circular. Dropping it lets
% motion be tested as an independent state variable. (2026-06-17)
nF_m   = min(nFrames, numel(mot_full));
X_cp_z = zscore(X_cp(1:nF_m,:));    % unit-variance per mode
X_cp_m = X_cp_z;                    % [nF_m × nPred_cp] — contra modes only
fprintf('Predictor matrix: %d contra SVD (z-scored) features (motion-free baseline)\n', ...
    size(X_cp_m,2));

%% [CP-FIT] Spontaneous contra→ipsi map fit
% Fits an instantaneous linear map (pX=0, pY=0) on pre-trial spontaneous
% windows.  Produces beta_cp used by all downstream sections.

imp_data   = allExperiments(selExp).imp;
uAmp_cp    = allExperiments(selExp).uAmp;
nzMask_cp  = uAmp_cp > 0;

all_starts_cp = [];
for ia = 1:numel(uAmp_cp)
    if ~nzMask_cp(ia); continue; end
    all_starts_cp = [all_starts_cp; imp_data.startTimes{ia}(:)];
end
all_starts_cp = sort(all_starts_cp);
nTrials_cp    = numel(all_starts_cp);

pre_frames = round(spont_pre * Fs);

spont_y_cp = cell(nTrials_cp, 1);
spont_X_cp = cell(nTrials_cp, 1);
valid_sp   = false(nTrials_cp, 1);
for j = 1:nTrials_cp
    [~, i_on] = min(abs(t_full - all_starts_cp(j)));
    i0 = i_on - pre_frames;  i1 = i_on - 1;
    if i0 < 1 || i1 > nF_m; continue; end
    spont_y_cp{j} = y_full(i0:i1);
    spont_X_cp{j} = X_cp_m(i0:i1,:);
    valid_sp(j)   = true;
end
valid_idx_cp = find(valid_sp);
nValid_cp    = numel(valid_idx_cp);

% 5-fold partition (fold_id used by [CP-RRR] rank sweep)
split_seed = 42;  kfold = 5;
rng(split_seed);
fold_id = mod(randperm(nValid_cp)-1, kfold) + 1;

% Fit on all valid windows; quick single-fold held-out R² for the record
tr_idx_q = valid_idx_cp(fold_id ~= 1);
te_idx_q = valid_idx_cp(fold_id == 1);
[Phi_q, y_q] = buildLagMatrix(cell2mat(spont_y_cp(tr_idx_q)), ...
                               cell2mat(spont_X_cp(tr_idx_q)), pY, pX);
beta_q  = Phi_q \ y_q;
cv_mean = compute_r2(cell2mat(spont_y_cp(te_idx_q)), ...
                     cell2mat(spont_X_cp(te_idx_q)), beta_q, pY, pX);

[Phi_all, y_all] = buildLagMatrix(cell2mat(spont_y_cp(valid_idx_cp)), ...
                                  cell2mat(spont_X_cp(valid_idx_cp)), pY, pX);
beta_cp = Phi_all \ y_all;
fprintf('[CP-FIT] %d windows  nSV=%d  held-out R²=%.3f\n', nValid_cp, nPred_cp, cv_mean);


%% [CP-2] SVD mode weights / kernels
% beta layout (pY=0): [intercept; (sv1..svN) blocks of pX lags each].
% pX=0 (instantaneous): one standardized weight per predictor -> stem plot.
% pX>0:                 per-mode lag kernels -> overlaid line plot.
beta_offset = 1 + pY;

if pX == 0
    % Single standardized weight per contra SVD mode
    mode_w      = beta_cp(beta_offset + (1:nPred_cp));   % [nPred_cp × 1]
    kern_energy = mode_w.^2;
    [~, top3]   = sort(kern_energy,'descend');
    fprintf('[CP-2] Instantaneous mode weights — top3 modes: [%d %.3f] [%d %.3f] [%d %.3f]\n', ...
        top3(1),mode_w(top3(1)), top3(2),mode_w(top3(2)), top3(3),mode_w(top3(3)));

    fig_kern = paperFig(8, 4);
    lmK=0.13; rmK=0.04; bmK=0.18; tmK=0.12;
    ax_kern = axes(fig_kern,'Position',[lmK,bmK,1-lmK-rmK,1-bmK-tmK]);
    stem(ax_kern, 1:nPred_cp, mode_w, 'filled', 'MarkerSize',3, ...
        'Color',[0.2 0.4 0.8],'LineWidth',0.6);
    yline(ax_kern, 0, 'k--','LineWidth',0.5);
    set(ax_kern,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax_kern,'Contra SVD mode','FontSize',6,'FontWeight','bold');
    ylabel(ax_kern,'Std. weight','FontSize',6,'FontWeight','bold');
    title(ax_kern, sprintf('Instantaneous contra map  nSV=%d', nPred_cp), ...
        'FontSize',6,'FontWeight','bold');
else
    t_kernel   = (1:pX) / Fs * 1000;
    kernels_cp = zeros(nPred_cp, pX);
    for j = 1:nPred_cp
        idx_b = beta_offset + (j-1)*pX + (1:pX);
        kernels_cp(j,:) = beta_cp(idx_b)';
    end
    kern_energy = sum(kernels_cp.^2, 2);
    [~, top3]   = sort(kern_energy,'descend');
    fprintf('[CP-2] SVD mode kernel energies — top3 modes: [%d %.3f] [%d %.3f] [%d %.3f]\n', ...
        top3(1),kern_energy(top3(1)), top3(2),kern_energy(top3(2)), top3(3),kern_energy(top3(3)));

    fig_kern = paperFig(8, 4);
    lmK=0.13; rmK=0.04; bmK=0.18; tmK=0.10;
    ax_kern = axes(fig_kern,'Position',[lmK,bmK,1-lmK-rmK,1-bmK-tmK]);
    hold(ax_kern,'on');
    cmap_k = parula(nPred_cp);
    for j = 1:nPred_cp
        lw = 0.4 + 1.1*(kern_energy(j)/max(kern_energy));
        plot(ax_kern, t_kernel, kernels_cp(j,:), 'Color', cmap_k(j,:), 'LineWidth', lw);
    end
    yline(ax_kern, 0, 'k--','LineWidth',0.5,'HandleVisibility','off');
    hold(ax_kern,'off');
    set(ax_kern,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax_kern,'Lag (ms)','FontSize',6,'FontWeight','bold');
    ylabel(ax_kern,'ARX kernel coefficient','FontSize',6,'FontWeight','bold');
    title(ax_kern, sprintf('SVD-mode kernels  pX=%d  nSV=%d', pX, nPred_cp), ...
        'FontSize',6,'FontWeight','bold');
    cb_k = colorbar(ax_kern); colormap(ax_kern, parula);
    clim(ax_kern,[1 nPred_cp]); cb_k.Label.String = 'SVD mode'; cb_k.FontSize = 5;
end
paperExport(fig_kern, fullfile(paper_root,'images','figure2','cp_svd_kernels.png'));
fprintf('[CP-2] Exported cp_svd_kernels.png\n');

% [CP-3] OLS kernel map removed — RRR kernel (below) is the retained version.

%% [CP-RRR] Reduced-rank (Ye et al. 2023) latent-component sweep
% Reproduces the "kernel prediction" of Ye et al. 2023 ("Brain-wide topographic
% coordination of traveling spiral waves", Methods "Linear regression within
% cortex"): predict one side from the other with reduced-rank regression, report
% cross-validated R^2 vs rank (their Fig 3C plateaus at ~16 latent components), and
% back-project the weights into pixel space as a kernel map (Fig 3D-G).
%
% NOTE on rank: the target here is a single pixel, so a true matrix-RRR collapses to
% rank-1 = OLS. The meaningful single-output analog is the regressor-side latent-
% component sweep: the contra predictors are ALREADY an SVD basis (V_c_full from
% redoSVD on the contra mask), so regressing the pixel on the top-r contra SVD
% components (= principal-component regression) and sweeping r reproduces Ye's
% variance-explained-vs-rank curve and plateau. The SAME k-fold CV folds as
% [CP-ARX] are reused, so the result is directly comparable to the fixed 200-mode
% OLS model (at r = nPred_cp the two models are identical -- a built-in check).
% A general rrr_fit() helper (true multi-output RRR) is provided at end of file for
% the future whole-hemisphere target.
if pX ~= 0 || pY ~= 0
    warning('[CP-RRR] assumes instantaneous model (pX=pY=0); current pX=%d pY=%d.', pX, pY);
end

rank_grid = unique(min([1 2 3 5 8 12 16 24 32 48 64 100 150 200], nPred_cp));
nRanks    = numel(rank_grid);             % motion-free baseline: predictors are contra modes only

rrr_R2_mean = nan(nRanks,1);
rrr_R2_sd   = nan(nRanks,1);

for ir = 1:nRanks
    r      = rank_grid(ir);
    cols_r = 1:r;                         % top-r contra SVD modes
    foldR2 = nan(kfold,1);
    for f = 1:kfold
        tr_idx = valid_idx_cp(fold_id ~= f);
        te_idx = valid_idx_cp(fold_id == f);

        y_tr = cell2mat(spont_y_cp(tr_idx));
        X_tr = cell2mat(spont_X_cp(tr_idx));
        [Phi_tr, yo_tr] = buildLagMatrix(y_tr, X_tr(:,cols_r), pY, pX);
        beta_r = Phi_tr \ yo_tr;

        y_te = cell2mat(spont_y_cp(te_idx));
        X_te = cell2mat(spont_X_cp(te_idx));
        foldR2(f) = compute_r2(y_te, X_te(:,cols_r), beta_r, pY, pX);
    end
    rrr_R2_mean(ir) = mean(foldR2, 'omitnan');
    rrr_R2_sd(ir)   = std(foldR2,  'omitnan');
end

% r*: smallest rank reaching >= 99% of the peak CV R^2 (knee of the plateau)
peakR2  = max(rrr_R2_mean);
ir_star = find(rrr_R2_mean >= 0.99*peakR2, 1, 'first');
r_star  = rank_grid(ir_star);
fprintf('[CP-RRR] rank sweep: peak CV R^2=%.3f | r*=%d (>=99%% of peak, R^2=%.3f)\n', ...
    peakR2, r_star, rrr_R2_mean(ir_star));
fprintf('[CP-RRR] CONTRAST: OLS-%d CV R^2=%.3f (cp-arx) vs RRR r*=%d CV R^2=%.3f | Ye plateau ~16 comps\n', ...
    nPred_cp, cv_mean, r_star, rrr_R2_mean(ir_star));

% Final RRR model: refit at r* on ALL valid windows (mirrors [CP-ARX] beta_cp refit)
y_all_v   = cell2mat(spont_y_cp(valid_idx_cp));
X_all_v   = cell2mat(spont_X_cp(valid_idx_cp));      % [N x nPred_cp]
cols_star = 1:r_star;
[Phi_star, yo_star] = buildLagMatrix(y_all_v, X_all_v(:,cols_star), pY, pX);
beta_rrr  = Phi_star \ yo_star;

% Conditioning: r* vs the full 200-mode model (the existing comment flags overfit/
% cond blow-up at high mode counts -- quantify it here).
cond_rrr     = cond(Phi_star' * Phi_star);
[Phi_full,~] = buildLagMatrix(y_all_v, X_all_v, pY, pX);
cond_full    = cond(Phi_full' * Phi_full);
fprintf('[CP-RRR] Gram cond: r*=%d -> %.2e   |   full %d-mode -> %.2e\n', ...
    r_star, cond_rrr, nPred_cp, cond_full);

% -- Rank-sweep figure (Ye Fig 3C analog) ------------------------------------------
fig_rs = paperFig(8, 5);
lmS=0.14; rmS=0.05; bmS=0.16; tmS=0.10;
ax_rs = axes(fig_rs,'Position',[lmS,bmS,1-lmS-rmS,1-bmS-tmS]); hold(ax_rs,'on');
patch(ax_rs, [rank_grid, fliplr(rank_grid)], ...
    [rrr_R2_mean'+rrr_R2_sd', fliplr(rrr_R2_mean'-rrr_R2_sd')], [0.2 0.4 0.8], ...
    'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
plot(ax_rs, rank_grid, rrr_R2_mean, '-o', 'Color',[0.2 0.4 0.8], ...
    'MarkerFaceColor',[0.2 0.4 0.8],'MarkerSize',3,'LineWidth',1.2, ...
    'DisplayName','RRR (PCR) CV R^2');
yline(ax_rs, cv_mean, '--', 'Color',[0.1 0.1 0.1],'LineWidth',1.0, ...
    'DisplayName',sprintf('OLS-%d CV R^2',nPred_cp));
xline(ax_rs, 16, ':', 'Color',[0.5 0.5 0.5],'LineWidth',0.8,'DisplayName','Ye r=16');
plot(ax_rs, r_star, rrr_R2_mean(ir_star), 'p', 'MarkerSize',9, ...
    'MarkerFaceColor',[0.85 0.3 0.1],'MarkerEdgeColor','k', ...
    'DisplayName',sprintf('r*=%d',r_star));
hold(ax_rs,'off');
set(ax_rs,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold','XScale','log');
xlim(ax_rs,[min(rank_grid)*0.8, max(rank_grid)*1.2]);
xlabel(ax_rs,'# contra latent components (rank r)','FontSize',6,'FontWeight','bold');
ylabel(ax_rs,'Cross-validated R^2','FontSize',6,'FontWeight','bold');
title(ax_rs, sprintf('%s %s e%d  |  RRR rank sweep', mn, td, en), ...
    'FontSize',6,'FontWeight','bold');
lg_rs = legend(ax_rs,'Location','southeast','FontSize',5,'Box','off');
try; lg_rs.ItemTokenSize=[8 8]; catch; end
paperExport(fig_rs, fullfile(paper_root,'images','figure2','cp_rrr_ranksweep.png'));
fprintf('[CP-RRR] Exported cp_rrr_ranksweep.png\n');

% -- Signed kernel map at r* (Ye Fig 3D analog) ------------------------------------
% Contrast with [CP-3], which squares to a positive "energy" map; here the weights
% are kept signed and pixel transparency is scaled by |weight| (as in Ye Fig 3D-G).
idx_contra_rrr = find(valid_cp_svd(:));
mode_w_rrr     = beta_rrr(1 + (1:r_star));            % contra weights (skip intercept)
pixel_w        = U_svd_cp(:,1:r_star) * mode_w_rrr;   % [nPix_contra x 1], signed
kmR            = nan(nY_cp, nX_cp);
kmR(idx_contra_rrr) = pixel_w;

[fig_kmR, ~, ax_sc] = brain_overlay_fig(mimg_cp, 8, 6);

wlim = prctile(abs(pixel_w), 99); if wlim < eps; wlim = 1; end
absK = abs(kmR'); alpha_w = min(1, absK ./ wlim); alpha_w(isnan(alpha_w)) = 0;
im_sc = imagesc(ax_sc, kmR');
set(im_sc, 'AlphaData', alpha_w);
% blue -> white -> red diverging colormap (no toolbox dependency)
nC = 256; nHalf = ceil(nC/2);
cmap_div = [ linspace(0.23,1,nHalf)', linspace(0.30,1,nHalf)', linspace(0.75,1,nHalf)'; ...
             linspace(1,0.80,nC-nHalf)', linspace(1,0.10,nC-nHalf)', linspace(1,0.10,nC-nHalf)' ];
colormap(ax_sc, cmap_div);
clim(ax_sc, [-wlim, wlim]);
plot(ax_sc, py_prim, px_prim, 'k+','MarkerSize',8,'LineWidth',1.5,'HandleVisibility','off');
title(ax_sc, sprintf('Contra RRR kernel map  (r*=%d)', r_star), ...
    'FontSize',6,'FontWeight','bold');
cb_kmR = colorbar(ax_sc,'Position',[0.78 0.12 0.05 0.72]);
ylabel(cb_kmR,'Kernel weight (a.u.)','FontSize',5,'FontWeight','bold');
hold(ax_sc,'off');
paperExport(fig_kmR, fullfile(paper_root,'images','figure2','cp_rrr_kernel_map.png'));
fprintf('[CP-RRR] Exported cp_rrr_kernel_map.png\n');

%% [CP-BLEED] Impulse-bleed spatial map on contra hemisphere
%
% WHAT THIS MEASURES
% For each contra SVD mode, compute the SIGNED mean change in that mode
% during the stim dip window (0–bleed_neg_win(2) s) relative to the
% pre-stim baseline, averaged across all trials and amplitudes.
% Project the resulting weight vector back to pixel space via U_svd_cp to
% get a spatial map of where on the contralateral hemisphere the stimulus
% drives correlated activity (positive = driven up, negative = driven down).
%
% ALGORITHM
%   1. Per trial: extract [−bleed_pre_s, +bleed_neg_win(2)] s window of
%      z-scored contra SVD modes (X_cp_m).
%   2. Subtract the per-trial pre-stim MEAN (t < 0) from each mode as
%      baseline correction.
%   3. Average the baseline-corrected traces across all trials of one
%      amplitude => trial-average onset-locked deviation [nWin × nPred_cp].
%   4. Take the TIME-MEAN over the dip window (t = 0..bleed_neg_win(2)) =>
%      one signed scalar per mode per amplitude.
%   5. Average those scalars across amplitudes => C_signed_z [nPred_cp × 1].
%   6. Convert C_signed_z from z-score units back to original SVD units
%      (multiply by per-mode std), then project: bleed_pixel_w = U * C.
%
% NOTE: Detection threshold is implicit (soft weighting by magnitude).
% The signed mean is NOT compared to baseline variance — a mode with a
% small but consistent dip gets a small weight, not a hard zero. To gate on
% SNR (require dip > k × baseline SD), compute baseline std and threshold
% C_signed_z accordingly before the pixel projection.

bleed_neg_win  = [0 0.30];         % dip window (s); must match [CP-IMP] neg_win
bleed_pre_s    = 6.0;              % pre-stim baseline window (s)
bleed_nPre     = round(bleed_pre_s * Fs);
bleed_nPost    = round(bleed_neg_win(2) * Fs);
bleed_nWin     = bleed_nPre + bleed_nPost + 1;
t_bleed        = (-bleed_nPre:bleed_nPost) / Fs;
bleed_pre_mask = t_bleed < 0;
bleed_dip_mask = t_bleed >= bleed_neg_win(1);

% Accumulate mean onset-locked contra deviation (z-scored SVD units) per amplitude
C_signed_z  = zeros(nPred_cp, 1);
n_bleed_amp = 0;
for ia_b = 1:numel(uAmp_cp)
    if ~nzMask_cp(ia_b); continue; end
    starts_b = imp_data.startTimes{ia_b}(:);
    devsum_b = zeros(bleed_nWin, nPred_cp);
    nval_b   = 0;
    for j_b = 1:numel(starts_b)
        [~, ion_b] = min(abs(t_full - starts_b(j_b)));
        i0_b = ion_b - bleed_nPre;
        i1_b = ion_b + bleed_nPost;
        if i0_b < 1 || i1_b > nF_m; continue; end
        Xc_b  = X_cp_m(i0_b:i1_b, 1:nPred_cp);       % z-scored SVD modes
        bl_b  = mean(Xc_b(bleed_pre_mask, :), 1, 'omitnan');
        devsum_b = devsum_b + (Xc_b - bl_b);
        nval_b = nval_b + 1;
    end
    if nval_b == 0; continue; end
    amp_mean_b  = devsum_b / nval_b;                  % [bleed_nWin × nPred_cp]
    C_signed_z  = C_signed_z + mean(amp_mean_b(bleed_dip_mask, :), 1)';
    n_bleed_amp = n_bleed_amp + 1;
end
C_signed_z = C_signed_z / max(n_bleed_amp, 1);        % [nPred_cp × 1] z-score units

% Convert from z-scored to original SVD temporal units, project to pixel space
std_X_b        = std(X_cp(1:nF_m, :), 0, 1)';        % [nPred_cp × 1]
C_signed_orig  = C_signed_z .* std_X_b;
bleed_pixel_w  = U_svd_cp * C_signed_orig;            % [nPix_contra × 1] signed

% Map to 2D grid
idx_contra_b   = find(valid_cp_svd(:));
km_bleed       = nan(nY_cp, nX_cp);
km_bleed(idx_contra_b) = bleed_pixel_w;

% Plot — diverging colormap, same style as RRR kernel map
nC_b = 256; nH_b = ceil(nC_b/2);
cmap_bleed = [ linspace(0.23,1,nH_b)', linspace(0.30,1,nH_b)', linspace(0.75,1,nH_b)'; ...
               linspace(1,0.80,nC_b-nH_b)', linspace(1,0.10,nC_b-nH_b)', linspace(1,0.10,nC_b-nH_b)' ];

[fig_bleed, ~, ax_bleed] = brain_overlay_fig(mimg_cp, 8, 6);
wlim_b = prctile(abs(bleed_pixel_w), 99); if wlim_b < eps; wlim_b = 1; end
alpha_b2 = min(1, abs(km_bleed') ./ wlim_b); alpha_b2(isnan(alpha_b2)) = 0;
im_bleed = imagesc(ax_bleed, km_bleed');
set(im_bleed, 'AlphaData', alpha_b2);
colormap(ax_bleed, cmap_bleed);
clim(ax_bleed, [-wlim_b, wlim_b]);
plot(ax_bleed, py_prim, px_prim, 'k+','MarkerSize',8,'LineWidth',1.5,'HandleVisibility','off');
title(ax_bleed, sprintf('Contra impulse bleed  (dip window 0–%.0f ms)', bleed_neg_win(2)*1000), ...
    'FontSize',6,'FontWeight','bold');
cb_bleed = colorbar(ax_bleed,'Position',[0.78 0.12 0.05 0.72]);
ylabel(cb_bleed,'Bleed weight (a.u.)','FontSize',5,'FontWeight','bold');
hold(ax_bleed,'off');
paperExport(fig_bleed, fullfile(paper_root,'images','figure2','cp_bleed_map.png'));
fprintf('[CP-BLEED] Exported cp_bleed_map.png\n');

%% [CP-IMP] Impulse-window contra prediction + stim-bleed negation (no TF)
% Apply the spontaneous instantaneous contra map (beta_cp) across [-1,+1] s using
% only concurrent contra+motion -- no stimulus info, no TF.
%
% Window length is fine: instantaneous model (pX=0) predicts pointwise, no history
% buffer needed (6 s training only set sample count for beta). (Requires pX=0.)
%
% STIM-BLEED NEGATION (decontam): the contra hemisphere is itself driven by the
% stimulus, so the raw prediction reproduces ~79% of the dip. We remove the
% per-amplitude ONSET-LOCKED contra deviation (the stim bleed) from the predictors
% -- but ONLY during the sharp stim-dip window (neg_win), NOT the whole second.
% Outside neg_win the prediction runs on actual contra and resumes tracking, so:
%   - dip window:  contra suppressed -> dip NOT predicted -> dip lands in residual
%   - after dip:   contra active     -> post-dip recovery IS predicted (coupled
%                  network activity) -> residual returns toward flat
% Spontaneous coupling is not onset-locked so it is preserved; only the stim-
% evoked transient is removed, and only where it dominates. Pre-stim untouched.
if pX ~= 0
    warning('[CP-IMP] assumes instantaneous model (pX=0); current pX=%d.', pX);
end

% DECONTAM: subtract the stim bleed from contra in neg_win so the residual =
% pure stim response. Two estimates available:
%   - decontam=false -> RESIDUAL (actual - raw_beta). Stable lower bound on the
%     stim effect (recovers ~21% of dip), monotonic, flat baseline. Caveat: it is
%     a LOWER BOUND (contra is itself stim-driven so raw_beta explains away the
%     shared dip portion). True impulse lies between residual and actual.
%   - decontam=true  -> project out the artifact subspace in neg_win (pca) or
%     subtract the per-amplitude onset mean (kernel). Recovers closer to the full
%     dip and stays smooth through the impulse (pca), at the cost of per-amplitude
%     stability. With pca_per_amp=true the PCA basis is built PER AMPLITUDE (each
%     amplitude's own dip-window epoch) -> per-amplitude correction, which fixes
%     the pooled-basis over-subtraction seen at mid amplitudes (e.g. 2.7V; see
%     paper/cp_val_peramp_pca_rescue.png). In-sample basis uses ALL trials of the
%     amplitude (not a held-out split) so it is far less noisy than the rescue test.
decontam = true;          % true -> decontaminated prediction
neg_win  = [0 0.30];      % window (s) where contra is suppressed = the stim dip.
                          % Outside this, contra predicts normally (post-dip
                          % recovery is explained, not isolated). Tune to the dip.
decontam_mode = 'scaledkernel';   % ADOPTED. Subtract kernel_alpha * (per-amplitude
                          % onset-mean artifact, tapered) from contra. beta*(full
                          % artifact)=the bleed, so scaling by alpha<1 can NEVER
                          % overshoot (convex) -> NO per-amplitude flips, and alpha<1
                          % leaves natural dynamics (no full switch-off). Stable +
                          % smooth + per-amplitude. Leaves ~ (1-alpha)*bleed residual.
                          %   'pca'    = artifact-subspace projection. REJECTED: PCA
                          %     orders modes by artifact variance not by beta-weight,
                          %     so low-rank recon mis-scales through beta and FLIPS
                          %     positive per-amplitude (2.1/3.2/4.3/4.9V), pooled or
                          %     per-amp, any rank. See paper/cp_decontam_pca_vs_kernel.
                          %   'kernel' = subtract full artifact (alpha=1, no taper):
                          %     exact zero bleed but switches contra off + boundary step.
                          %   false (decontam=false) = residual (actual-raw beta), the
                          %     stable LOWER BOUND alternative.
kernel_alpha = 0.85;       % scaledkernel: fraction of bleed to remove (0..1). 0.8 ->
                          % ~15% residual bleed at all amplitudes; 1.0 == kernel.
taper_win = [0.20 0.40];  % scaledkernel: cosine ramp 1->0 over this window past the
                          % dip, so subtraction fades out smoothly (kills boundary step).
pca_per_amp  = true;      % pca only: per-amplitude basis vs single pooled basis.
n_art_pca = 1;            % pca only: # PCA artifact components.

pre_imp  = Fs;                       % 1 s pre-onset
post_imp = Fs;                       % 1 s post-onset
nImp     = pre_imp + post_imp + 1;   % 71 frames
t_imp    = (-pre_imp:post_imp) / Fs; % [-1 ... +1] s
pre_bl   = 1:pre_imp;                % window indices used as baseline (pre-stim s)
iDip     = find(t_imp >= 0 & t_imp <= 0.2);        % inhibition dip (0-200 ms, peak_mode=3)
iPostDip = find(t_imp > neg_win(2) & t_imp <= 1);  % post-dip recovery window
neg_mask = (t_imp >= neg_win(1) & t_imp <= neg_win(2))';  % suppress contra here only

nAmp_imp = numel(uAmp_cp);
act_imp  = cell(nAmp_imp,1);   % actual (onset-baselined)
prd_imp  = cell(nAmp_imp,1);   % prediction AFTER decontam
prr_imp  = cell(nAmp_imp,1);   % prediction BEFORE decontam (raw, contaminated)
res_imp  = cell(nAmp_imp,1);   % residual = actual - (active) prediction
art_imp  = cell(nAmp_imp,1);   % per-amplitude onset-locked contra artifact (hard neg_win)
art_tap_imp = cell(nAmp_imp,1);% per-amplitude artifact, cosine-tapered (scaledkernel)

% ---- Pass 1: per-amplitude onset-locked contra artifact (the stim bleed) -----
art_raw_imp = build_onset_artifact(nAmp_imp, nzMask_cp, imp_data, t_full, X_cp_m, ...
    nPred_cp, pre_imp, post_imp + 1, nF_m);
% Taper weight: 1 from onset to taper_win(1), cosine ramp 1->0 over taper_win, 0
% after; 0 pre-onset. Smooth fade-out removes the hard-edge boundary step.
taper_w = ones(1, nImp);
tr = (t_imp >= taper_win(1) & t_imp <= taper_win(2));
taper_w(tr) = 0.5 * (1 + cos(pi * (t_imp(tr) - taper_win(1)) / (taper_win(2) - taper_win(1))));
taper_w(t_imp > taper_win(2)) = 0;
taper_w(t_imp < 0) = 0;
for ia = 1:nAmp_imp
    tmp = art_raw_imp{ia};
    tmp(~neg_mask, :) = 0;    % suppress contra in dip window only; else untouched
    art_imp{ia} = tmp;
    tt = art_raw_imp{ia};
    tt(t_imp < 0, :) = 0;     % keep onset-locked mean post-onset, then taper it
    art_tap_imp{ia} = tt .* taper_w(:);
end

% ---- PCA artifact basis (decontam_mode='pca'): dip-window epoch ---------------
% Build the mean stim artifact epoch over the dip window, then PCA over time ->
% orthonormal spatial (mode-space) artifact basis. Restricting the epoch to the
% dip makes the basis artifact-specific (not the recovery), so projecting it out
% costs no post-dip prediction. Two bases are built:
%   Ab_pca         -- pooled across all nonzero-amplitude trials (single basis)
%   Ab_pca_amp{ia} -- PER AMPLITUDE, from that amplitude's own dip epoch
% pca_per_amp selects which is used per trial in Pass 2. The per-amplitude basis
% uses ALL trials of the amplitude (in-sample), so it is well-conditioned here.
dip_rows = (t_imp >= neg_win(1) & t_imp <= neg_win(2));
A_epoch     = zeros(nImp, nPred_cp); ne_pca = 0;
A_epoch_amp = cell(nAmp_imp,1); ne_amp = zeros(nAmp_imp,1);
Ab_pca_amp  = cell(nAmp_imp,1); expl1_amp = nan(nAmp_imp,1);
for ia = 1:nAmp_imp
    if ~nzMask_cp(ia); continue; end
    Aa = zeros(nImp, nPred_cp);
    for s = imp_data.startTimes{ia}(:)'
        [~, ion] = min(abs(t_full - s)); g = ion-pre_imp : ion+post_imp;
        if g(1) < 1 || g(end) > min(nFrames, nF_m); continue; end
        seg = X_cp_m(g, 1:nPred_cp);
        dseg = seg - mean(seg(pre_bl,:), 1, 'omitnan');
        A_epoch = A_epoch + dseg;  ne_pca = ne_pca + 1;
        Aa      = Aa      + dseg;  ne_amp(ia) = ne_amp(ia) + 1;
    end
    A_epoch_amp{ia} = Aa / max(ne_amp(ia),1);
end
A_epoch = A_epoch / max(ne_pca, 1);
[coeff_pca, ~, ~, ~, expl_pca] = pca(A_epoch(dip_rows, :));
n_art_pca = max(1, min(n_art_pca, size(coeff_pca, 2)));
Ab_pca = coeff_pca(:, 1:n_art_pca)';            % [n_art × nPred] pooled basis
% Per-amplitude bases (fall back to pooled if an amplitude is too sparse).
for ia = 1:nAmp_imp
    if ~nzMask_cp(ia) || ne_amp(ia) < 3
        Ab_pca_amp{ia} = Ab_pca; continue;
    end
    [cfa, ~, ~, ~, eva] = pca(A_epoch_amp{ia}(dip_rows, :));
    na = max(1, min(n_art_pca, size(cfa,2)));
    Ab_pca_amp{ia} = cfa(:, 1:na)';
    expl1_amp(ia)  = eva(1)/sum(eva)*100;
end
fprintf('[CP-IMP] decontam_mode=%s per_amp=%d | pooled PC explained=[%s]%% | per-amp PC1=[%s]%%\n', ...
    decontam_mode, pca_per_amp, sprintf('%.0f ', expl_pca(1:min(4,numel(expl_pca)))), ...
    sprintf('%.0f ', expl1_amp(nzMask_cp)));

% ---- Pass 2: prediction (raw + decontam), actual, residual -------------------
for ia = 1:nAmp_imp
    if ~nzMask_cp(ia); continue; end
    starts = imp_data.startTimes{ia}(:);
    nT = numel(starts);
    A = nan(nT,nImp); P = nan(nT,nImp); Pr = nan(nT,nImp);
    art = art_imp{ia};
    for j = 1:nT
        [~, ion] = min(abs(t_full - starts(j)));
        g = ion-pre_imp : ion+post_imp;
        if g(1) < 1 || g(end) > min(nFrames, nF_m); continue; end
        Xw     = X_cp_m(g,:);                          % [nImp × nPred+1]
        yp_raw = [ones(nImp,1), Xw] * beta_cp;         % contaminated prediction
        if decontam && strcmpi(decontam_mode,'pca')
            % Per-trial: project the contra signal onto the artifact subspace
            % within neg_win and subtract. Removes only the rank-n_art_pca
            % artifact direction; neural subspace (natural dynamics) preserved.
            % pca_per_amp -> use this amplitude's own basis (per-amplitude corr).
            if pca_per_amp, Ab_use = Ab_pca_amp{ia}; else, Ab_use = Ab_pca; end
            seg   = X_cp_m(g, 1:nPred_cp);
            bc    = seg - mean(seg(pre_bl,:), 1, 'omitnan');
            recon = zeros(nImp, nPred_cp);
            recon(neg_mask,:) = (bc(neg_mask,:) * Ab_use') * Ab_use;
            Xw(:,1:nPred_cp) = seg - recon;
        elseif decontam && strcmpi(decontam_mode,'scaledkernel')
            % ADOPTED: subtract kernel_alpha * tapered per-amplitude artifact.
            % Convex scaling of the bleed -> cannot overshoot (no flip); taper
            % fades the subtraction out smoothly past the dip (no boundary step);
            % alpha<1 keeps natural dynamics (no switch-off).
            Xw(:,1:nPred_cp) = Xw(:,1:nPred_cp) - kernel_alpha * art_tap_imp{ia};
        elseif decontam
            % Kernel mode: subtract full per-amplitude onset-locked mean (in neg_win).
            Xw(:,1:nPred_cp) = Xw(:,1:nPred_cp) - art;
        end
        % decontam=false: Xw left raw, so yp_dec == yp_raw and the residual
        % res_imp = actual - raw_beta (ADOPTED impulse estimate).
        yp_dec = [ones(nImp,1), Xw] * beta_cp;         % decontaminated prediction
        % Baseline each trace by its OWN pre-stim mean: removes the model's DC
        % bias so the decontam prediction is flat at zero (no + or - drift) and
        % the residual = onset-baselined actual response. (raw/dec share pre-stim)
        ya   = y_full(g);
        bl_a = mean(ya(pre_bl),'omitnan');
        bl_p = mean(yp_raw(pre_bl),'omitnan');
        A(j,:)  = (ya - bl_a)';
        Pr(j,:) = (yp_raw - bl_p)';
        P(j,:)  = (yp_dec - bl_p)';
    end
    act_imp{ia} = A;
    prr_imp{ia} = Pr;
    prd_imp{ia} = P;
    if decontam, res_imp{ia} = A - P; else, res_imp{ia} = A - Pr; end
end

% ---- Amp-0 control: no-stim (gap-fill) trials, raw model, no decontam --------
% Validates the model is unbiased: on matched-timing no-stim trials both actual
% and prediction should be ~flat (no spurious drift) and unaffected by decontam.
A0 = []; P0 = [];
for ia = find(uAmp_cp(:)'==0)
    if isempty(imp_data.startTimes{ia}); continue; end
    starts = imp_data.startTimes{ia}(:);
    for j = 1:numel(starts)
        [~, ion] = min(abs(t_full - starts(j)));
        g = ion-pre_imp : ion+post_imp;
        if g(1) < 1 || g(end) > min(nFrames, nF_m); continue; end
        ya = y_full(g); yp = [ones(nImp,1), X_cp_m(g,:)]*beta_cp;
        A0 = [A0; (ya - mean(ya(pre_bl),'omitnan'))'];
        P0 = [P0; (yp - mean(yp(pre_bl),'omitnan'))'];
    end
end

% ---- Bleed quantification at the dip (0-200 ms): raw vs decontam --------------
ia_imp  = find(nzMask_cp);
A_pool  = cell2mat(act_imp(nzMask_cp));
Pr_pool = cell2mat(prr_imp(nzMask_cp));
Pd_pool = cell2mat(prd_imp(nzMask_cp));
dip = @(M) mean(mean(M(:,iDip),2,'omitnan'),'omitnan');
da_pool=dip(A_pool); dr_pool=dip(Pr_pool); dd_pool=dip(Pd_pool);

fprintf('[CP-IMP] Stim-bleed negation at dip (0-200 ms)  [decontam=%d]:\n', decontam);
for kk = 1:numel(ia_imp)
    ia = ia_imp(kk);
    da=dip(act_imp{ia}); dr=dip(prr_imp{ia}); dd=dip(prd_imp{ia});
    fprintf('  A=%.2f  actual=%+.3f | raw_pred=%+.3f (bleed %4.0f%%) -> decontam_pred=%+.3f (bleed %4.0f%%)\n', ...
        uAmp_cp(ia), da, dr, 100*dr/(da+eps), dd, 100*dd/(da+eps));
end
fprintf('  POOLED actual=%+.3f | raw bleed=%4.0f%% -> decontam bleed=%4.0f%%  (residual now recovers %.0f%% of dip)\n', ...
    da_pool, 100*dr_pool/(da_pool+eps), 100*dd_pool/(da_pool+eps), 100*(1-dd_pool/(da_pool+eps)));

% Post-dip tracking: after neg_win the contra prediction is active again, so it
% should EXPLAIN the recovery -> residual should be small vs actual there.
postdip = @(M) mean(abs(mean(M(:,iPostDip),1,'omitnan')));
ra_post = postdip(A_pool);                          % actual post-dip excursion
rr_post = postdip(cell2mat(res_imp(nzMask_cp)));    % residual post-dip excursion
fprintf('  POST-DIP (%.2f-1 s): |actual|=%.3f  |residual|=%.3f  -> contra explains %.0f%% of post-dip\n', ...
    neg_win(2), ra_post, rr_post, 100*(1-rr_post/(ra_post+eps)));
% Boundary smoothness at neg_win end: a large residual step there = hard switch-off
% artifact. PCA (subspace) gives a ~3x smaller step than kernel (full mean).
[~, ib_bnd] = min(abs(t_imp - neg_win(2)));
bump = mean(arrayfun(@(ia) abs(mean(res_imp{ia}(:,ib_bnd),'omitnan')), ia_imp));
fprintf('  BOUNDARY smoothness @%.2fs (mean |residual step|): %.3f  [smaller = smoother; kernel~0.6]\n', ...
    neg_win(2), bump);
if ~isempty(A0)
    fprintf('  AMP-0 control (no stim, n=%d): actual=%+.3f  pred=%+.3f  -> model unbiased (both ~0)\n', ...
        size(A0,1), dip(A0), dip(P0));
end

% -- Figure: actual + raw pred + decontam pred (top) + residual (bottom) -------
nPlotI = numel(ia_imp);
colA=[0.1 0.1 0.1]; colPr=[0.6 0.6 0.6]; colP=[0.2 0.4 0.85]; colR=[0.85 0.2 0.1];

fig_imp = paperFig(max(6, 5*nPlotI), 8);
lmI=0.07; rmI=0.02; bmI=0.12; tmI=0.10; gxI=0.03; gyI=0.07;
pwI = (1-lmI-rmI-(nPlotI-1)*gxI) / nPlotI;
phI = (1-bmI-tmI-gyI) / 2;

for kk = 1:nPlotI
    ia = ia_imp(kk);
    xL = lmI + (kk-1)*(pwI+gxI);

    nv    = sum(~all(isnan(act_imp{ia}),2));
    mu_a  = mean(act_imp{ia},1,'omitnan'); se_a = std(act_imp{ia},0,1,'omitnan')/sqrt(max(nv,1));
    mu_pr = mean(prr_imp{ia},1,'omitnan');
    mu_p  = mean(prd_imp{ia},1,'omitnan');
    mu_r  = mean(res_imp{ia},1,'omitnan'); se_r = std(res_imp{ia},0,1,'omitnan')/sqrt(max(nv,1));

    % Top: actual, raw (contaminated) pred, decontam (flat) pred
    axT = axes(fig_imp,'Position',[xL, bmI+phI+gyI, pwI, phI]); hold(axT,'on');
    patch(axT,[t_imp,fliplr(t_imp)],[mu_a+se_a,fliplr(mu_a-se_a)],colA, ...
        'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    plot(axT,t_imp,mu_a, 'Color',colA, 'LineWidth',1.5,'DisplayName','Actual');
    plot(axT,t_imp,mu_pr,'Color',colPr,'LineWidth',1.0,'LineStyle',':', 'DisplayName','Pred raw (bleed)');
    plot(axT,t_imp,mu_p, 'Color',colP, 'LineWidth',1.0,'LineStyle','--','DisplayName',sprintf('Pred decontam (%s)',decontam_mode));
    xline(axT,0,'k:','LineWidth',0.5,'HandleVisibility','off');
    yline(axT,0,'k--','LineWidth',0.4,'HandleVisibility','off');
    hold(axT,'off');
    set(axT,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold','XTickLabel',{});
    title(axT,sprintf('A=%.2f',uAmp_cp(ia)),'FontSize',6,'FontWeight','bold');
    if kk==1
        ylabel(axT,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
        lg=legend(axT,'Location','southwest','Box','off','FontSize',5);
        try; lg.ItemTokenSize=[8 6]; catch; end
    end

    % Bottom: residual = actual - decontam pred (= recovered stim response)
    axB = axes(fig_imp,'Position',[xL, bmI, pwI, phI]); hold(axB,'on');
    patch(axB,[t_imp,fliplr(t_imp)],[mu_r+se_r,fliplr(mu_r-se_r)],colR, ...
        'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
    plot(axB,t_imp,mu_r,'Color',colR,'LineWidth',1.5,'DisplayName','Residual');
    xline(axB,0,'k:','LineWidth',0.5,'HandleVisibility','off');
    yline(axB,0,'k--','LineWidth',0.4,'HandleVisibility','off');
    hold(axB,'off');
    set(axB,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(axB,'Time re onset (s)','FontSize',6,'FontWeight','bold');
    if kk==1, ylabel(axB,'Residual \DeltaF/F (%)','FontSize',6,'FontWeight','bold'); end
end
sgtitle(fig_imp, sprintf('%s %s e%d  |  Stim-bleed negation (%s): smooth pred through impulse -> residual = stim response', ...
    mn, td, en, decontam_mode), 'FontSize',6,'FontWeight','bold','Interpreter','none');
paperExport(fig_imp, fullfile(paper_root,'images','figure2','cp_impulse_pred_noTF.png'));
fprintf('[CP-IMP] Exported cp_impulse_pred_noTF.png\n');

%% [CP-4] Concurrent contra prediction + TF impulse layer
%
% Applies beta_cp to ACTUAL contra timeseries DURING the trial window.
% Adds the TF impulse response (best_sys from tf_fit.m) scaled by amplitude.
% PREREQ: Run tf_fit.m first (needs best_sys, uA_s in workspace).

if ~exist('best_sys','var') || ~exist('uA_s','var')
    error('[CP-4] Run tf_fit.m first (needs best_sys, uA_s in workspace).');
end
if ~exist('nBands','var') || ~exist('freqBandCtrs','var')
    nBands       = 20;
    freqBandCtrs = (0:nBands-1)*0.5 + 0.25;
end

eval_end_s  = 1.0;
eval_frames = round(eval_end_s * Fs);
iEval       = 1:eval_frames;           % 0-1 s window (R^2, trace display)
tEval       = (0:eval_frames-1) / Fs;
err_end_s   = 0.5;                      % prediction-error window = stim..stim+500 ms
iErr        = 1:(round(err_end_s*Fs)+1);% 0-500 ms (dip + early recovery)
nAmp_cp4    = numel(uAmp_cp);
cp4_alpha   = 0.9;                      % removes 90% of the per-amplitude bleed from
                                        % contra before beta_cp; ~10% residual mean artifact

% ── [CP-4a] Contra artifact check ─────────────────────────────────────────────
nPad_a4 = round(0.5 * Fs);
nWin_a4 = nPad_a4 + outlen;
t_art4  = ((-nPad_a4):(outlen-1))' / Fs;
% Pooled (all amplitudes) for threshold check and figure
% Also accumulate mode-averaged sum + sum-of-squares for per-trial SEM.
contra_sum4   = zeros(nWin_a4, nPred_cp);
mu_sum4       = zeros(nWin_a4, 1);   % sum of per-trial mode-averaged contra
mu_sq4        = zeros(nWin_a4, 1);   % sum of squared per-trial mode-averaged contra
n_art4        = 0;
for ia4 = 1:nAmp_cp4
    if ~nzMask_cp(ia4); continue; end
    for j4 = 1:numel(imp_data.startTimes{ia4})
        [~, ion4] = min(abs(t_full - imp_data.startTimes{ia4}(j4)));
        i0a4 = ion4 - nPad_a4; i1a4 = ion4 + outlen - 1;
        if i0a4 < 1 || i1a4 > nF_m; continue; end
        seg4         = X_cp_m(i0a4:i1a4, 1:nPred_cp);
        contra_sum4  = contra_sum4 + seg4;
        mu_seg4      = mean(seg4, 2);          % mode-averaged, 1 value per timepoint
        mu_sum4      = mu_sum4 + mu_seg4;
        mu_sq4       = mu_sq4  + mu_seg4.^2;
        n_art4       = n_art4 + 1;
    end
end
contra_mean4 = contra_sum4 / max(n_art4, 1);

% Mode-averaged mean and SEM across trials (for figure initial-condition display)
mu4_all  = mu_sum4 / max(n_art4, 1);
sem4_all = sqrt(max(mu_sq4/max(n_art4,1) - mu4_all.^2, 0)) / sqrt(max(n_art4,1));

% onset_idx4 = index of t=0; use stim-onset value as figure baseline (consistent
% with all other trace figures which are relative to stim time, not pre-stim mean)
onset_idx4  = nPad_a4 + 1;
bl4_fig     = mu4_all(onset_idx4);           % scalar: mode-averaged contra at t=0
mu4_bl      = mu4_all  - bl4_fig;            % onset-baselined mean
sem4_bl     = sem4_all;                      % SEM unchanged by baseline shift

pre_mask4  = t_art4 < 0;
stim_mask4 = t_art4 >= 0 & t_art4 <= 0.2;
% Keep pre-stim mean baseline for artifact ratio only (not for figure)
bl4_a      = mean(contra_mean4(pre_mask4, :), 1);
dev4_art   = contra_mean4(stim_mask4, :) - bl4_a;
max_art4   = max(abs(dev4_art(:)));
sd_pre4    = mean(std(contra_mean4(pre_mask4, :), 0, 1));
art_ratio4 = max_art4 / (sd_pre4 + eps);
do_decontam4 = art_ratio4 > 2.0;

fprintf('[CP-4a] Contra artifact: max_dev=%.4f  prestim_SD=%.4f  ratio=%.2f  decontam=%d\n', ...
    max_art4, sd_pre4, art_ratio4, double(do_decontam4));

% Per-amplitude artifact via shared helper; slice to post-onset window
art_raw_4      = build_onset_artifact(nAmp_cp4, nzMask_cp, imp_data, t_full, X_cp_m, ...
    nPred_cp, nPad_a4, outlen, nF_m);
art_shape4_amp = cellfun(@(a) a(nPad_a4+1:end, :), art_raw_4, 'UniformOutput', false);
% Cosine-taper the post-onset artifact (same scheme as CP-IMP scaledkernel) so the
% bleed is removed only in the dip + ramp and post-dip contra dynamics are kept.
t_post4 = (0:outlen-1) / Fs;
w4      = ones(1, outlen);
tr4     = (t_post4 >= taper_win(1) & t_post4 <= taper_win(2));
w4(tr4) = 0.5 * (1 + cos(pi * (t_post4(tr4) - taper_win(1)) / (taper_win(2) - taper_win(1))));
w4(t_post4 > taper_win(2)) = 0;
art_tap4_amp = cellfun(@(a) a .* w4(:), art_shape4_amp, 'UniformOutput', false);

% ── [CP-4b] TF impulse response per amplitude ─────────────────────────────────
try; nPre4 = numel(pole(best_sys)) + numel(zero(best_sys)) + 4; catch; nPre4 = 20; end
Ts4   = 1 / Fs;
h_TF4 = cell(nAmp_cp4, 1);
for ia4 = 1:nAmp_cp4
    if ~nzMask_cp(ia4); h_TF4{ia4} = zeros(outlen,1); continue; end
    u4 = [zeros(nPre4,1); 1; zeros(outlen-1,1)];
    try
        yp4  = sim(best_sys, iddata([], u4, Ts4));
        raw4 = yp4.OutputData(nPre4+1 : nPre4+outlen);
        n4   = min(numel(raw4), outlen);
        h4   = zeros(outlen,1);
        h4(1:n4) = raw4(1:n4);
        h_TF4{ia4} = uAmp_cp(ia4) * h4;
    catch ME4
        fprintf('[CP-4b] TF sim failed for amp %.3f: %s\n', uAmp_cp(ia4), ME4.message);
        h_TF4{ia4} = zeros(outlen,1);
    end
end

% ── [CP-4c] Per-trial concurrent prediction ───────────────────────────────────
actual4    = cell(nAmp_cp4, 1);
pink4      = cell(nAmp_cp4, 1);
red4       = cell(nAmp_cp4, 1);
err4       = cell(nAmp_cp4, 1);
mot4       = cell(nAmp_cp4, 1);
pvar4      = cell(nAmp_cp4, 1);
dpow_pre4  = cell(nAmp_cp4, 1);
dpow_stim4 = cell(nAmp_cp4, 1);
onset4     = cell(nAmp_cp4, 1);

delta4 = freqBandCtrs >= 1 & freqBandCtrs <= 4;
nfft4  = 2 * Fs;
W4     = sum(hann(Fs).^2);

% Per-trial motion statistics used to z-score per-trial motion values.
% imp_data.mot{ia} is a PER-TRIAL motion summary (already ~centered), NOT the
% continuous mot_full trace -- normalizing by mot_full's mean/std (~8000) made
% every trial z<0 and broke the high/low-motion split. Pool the per-trial values
% across amplitudes so the z-score is centered (mean 0) and the split is valid.
mot_pool4 = [];
for ia4p = 1:nAmp_cp4
    if ~nzMask_cp(ia4p); continue; end
    mot_pool4 = [mot_pool4; imp_data.mot{ia4p}(:)]; %#ok<AGROW>
end
mot_mean_sess4 = mean(mot_pool4, 'omitnan');
mot_std_sess4  = std(mot_pool4,  'omitnan');

for ia4 = 1:nAmp_cp4
    if ~nzMask_cp(ia4); continue; end
    starts4   = imp_data.startTimes{ia4}(:);
    nT4       = numel(starts4);
    mot_raw4  = imp_data.mot{ia4}(:);
    nMot4     = min(numel(mot_raw4), nT4);

    act_ia4   = nan(nT4, outlen);
    pink_ia4  = nan(nT4, outlen);
    red_ia4   = nan(nT4, outlen);
    err_ia4   = nan(nT4, 1);
    mot_ia4   = nan(nT4, 1);
    pv_ia4    = nan(nT4, 1);
    dpre_ia4  = nan(nT4, 1);
    dstim_ia4 = nan(nT4, 1);
    onset_ia4 = nan(nT4, 1);                  % onset frame (for CP-6i motion trace)
    mot_ia4(1:nMot4) = (mot_raw4(1:nMot4) - mot_mean_sess4) / max(mot_std_sess4, eps);
    h4 = h_TF4{ia4};

    for j4 = 1:nT4
        [~, ion4] = min(abs(t_full - starts4(j4)));
        i0w4 = ion4 - pX;
        i1w4 = ion4 + outlen - 1;
        if i0w4 < 1 || i1w4 > min(nFrames, nF_m); continue; end

        X_win4 = X_cp_m(i0w4:i1w4, :);

        if do_decontam4
            art_ia4 = cp4_alpha * art_tap4_amp{ia4};   % tapered, scaled by cp4_alpha
            n_sub4  = min(outlen, size(art_ia4, 1));
            X_win4(pX+1:pX+n_sub4, 1:nPred_cp) = ...
                X_win4(pX+1:pX+n_sub4, 1:nPred_cp) - art_ia4(1:n_sub4, :);
        end

        y_win4 = y_full(i0w4:i1w4);
        [Phi4, ~] = buildLagMatrix(y_win4, X_win4, pY, pX);
        if size(Phi4, 1) ~= outlen; continue; end

        bl_on4  = y_full(ion4);
        pink_j4 = Phi4 * beta_cp - bl_on4;
        pink_j4 = pink_j4 - pink_j4(1);   % clamp: express as change from t=0, same
        red_j4  = pink_j4 + h4;            % reference as act_j4 (both Δ from onset)
        act_j4  = y_full(ion4 : ion4+outlen-1) - bl_on4;

        act_ia4(j4,:)  = act_j4';
        pink_ia4(j4,:) = pink_j4';
        red_ia4(j4,:)  = red_j4';
        err_ia4(j4)    = mean((act_j4(iErr) - red_j4(iErr)).^2, 'omitnan');  % 0-500ms
        onset_ia4(j4) = ion4;

        i_pv0 = ion4 - Fs; i_pv1 = ion4 - 1;
        if i_pv0 >= 1
            pv_ia4(j4) = var(y_full(i_pv0:i_pv1), 'omitnan');
            Xfft4      = fft(y_full(i_pv0:i_pv1) .* hann(Fs), nfft4);
            pow4       = abs(Xfft4(1:nBands)).^2 * 2 / (Fs * W4);
            dpre_ia4(j4) = mean(pow4(delta4), 'omitnan');
        end

        i_st14 = ion4 + Fs - 1;
        if i_st14 <= nFrames
            sig_stim4  = y_full(ion4:i_st14) - bl_on4;
            Xfft4b     = fft(sig_stim4 .* hann(Fs), nfft4);
            pow4b      = abs(Xfft4b(1:nBands)).^2 * 2 / (Fs * W4);
            dstim_ia4(j4) = mean(pow4b(delta4), 'omitnan');
        end
    end

    actual4{ia4}    = act_ia4;
    pink4{ia4}      = pink_ia4;
    red4{ia4}       = red_ia4;
    err4{ia4}       = err_ia4;
    mot4{ia4}       = mot_ia4;
    pvar4{ia4}      = pv_ia4;
    dpow_pre4{ia4}  = dpre_ia4;
    dpow_stim4{ia4} = dstim_ia4;
    onset4{ia4}     = onset_ia4;
end

% Expose per-trial CP-4 outputs so motion_analysis / prestim_variance can use
% prediction error instead of raw Peak_imp_dev as the deviation signal.
allExperiments(selExp).imp.cp_err  = err4;
allExperiments(selExp).imp.cp_pvar = pvar4;

% ── [CP-4d] Stack + R² ────────────────────────────────────────────────────────
ia_list4  = find(nzMask_cp);
nAmps4    = numel(ia_list4);

act_all4   = cell2mat(actual4(nzMask_cp));
pink_all4  = cell2mat(pink4(nzMask_cp));
red_all4   = cell2mat(red4(nzMask_cp));
err_all4   = cell2mat(err4(nzMask_cp));
mot_all4   = cell2mat(mot4(nzMask_cp));
pv_all4    = cell2mat(pvar4(nzMask_cp));
dpre_all4  = cell2mat(dpow_pre4(nzMask_cp));
dstim_all4 = cell2mat(dpow_stim4(nzMask_cp));
onset_all4 = cell2mat(onset4(nzMask_cp));
amp_all4   = [];
for iaA = find(nzMask_cp(:))'
    amp_all4 = [amp_all4; repmat(uAmp_cp(iaA), size(actual4{iaA},1), 1)]; %#ok<AGROW>
end

tf_all4 = cell2mat(arrayfun(@(k) ...
    repmat(h_TF4{ia_list4(k)}', size(actual4{ia_list4(k)}, 1), 1), ...
    (1:nAmps4)', 'UniformOutput', false));

e_act4  = act_all4(:,  iEval);
e_pink4 = pink_all4(:, iEval);
e_red4  = red_all4(:,  iEval);
e_tf4   = tf_all4(:,   iEval);

ss4      = sum((e_act4(:) - mean(e_act4(:),'omitnan')).^2, 'omitnan');
R2_pink4 = max(0, 1 - sum((e_act4(:)-e_pink4(:)).^2,'omitnan') / ss4);
R2_tf4   = max(0, 1 - sum((e_act4(:)-e_tf4(:)).^2,  'omitnan') / ss4);
R2_red4  = max(0, 1 - sum((e_act4(:)-e_red4(:)).^2, 'omitnan') / ss4);
fprintf('[CP-4d] R² (0-1 s):  Contra ARX=%.3f  TF model=%.3f  ARX+TF=%.3f  dR²=%.3f\n', ...
    R2_pink4, R2_tf4, R2_red4, R2_red4 - R2_tf4);

% ── [CP-4f] Figures ───────────────────────────────────────────────────────────
colAct4  = [0.1 0.1 0.1];
colTF4   = [0.6 0.3 0.8];
colPink4 = [0.2 0.5 0.9];
colRed4  = [0.85 0.15 0.15];

% Fig 1: Artifact check — raw vs decontaminated pooled contra mean
% Pooled decontam mean: average the per-amplitude artifact-subtracted means
art_pool4 = zeros(outlen, nPred_cp);
n_art_pool4 = 0;
for ia4_v = 1:nAmp_cp4
    if ~nzMask_cp(ia4_v) || isempty(art_tap4_amp{ia4_v}); continue; end
    art_pool4 = art_pool4 + art_tap4_amp{ia4_v};
    n_art_pool4 = n_art_pool4 + 1;
end
art_pool4 = art_pool4 / max(n_art_pool4, 1);
contra_mean4_dec = contra_mean4;
n_sub_dec = min(outlen, size(art_pool4, 1));
contra_mean4_dec(nPad_a4+1 : nPad_a4+n_sub_dec, 1:nPred_cp) = ...
    contra_mean4_dec(nPad_a4+1 : nPad_a4+n_sub_dec, 1:nPred_cp) - cp4_alpha * art_pool4(1:n_sub_dec, :);
mean_dev4     = mean(contra_mean4     - bl4_a, 2);   % raw
mean_dev4_dec = mean(contra_mean4_dec - bl4_a, 2);   % after scaledkernel decontam

fig_art4 = paperFig(8, 4);
lmA4=0.12; rmA4=0.04; bmA4=0.18; tmA4=0.10;
ax_art4 = axes(fig_art4,'Position',[lmA4,bmA4,1-lmA4-rmA4,1-bmA4-tmA4]);
% Onset-baselined per-mode gray traces (consistent with stim-time reference)
bl4_onset = contra_mean4(onset_idx4, :);   % [1 × nPred_cp] onset value per mode
% Onset-baselined decontam mean (mode-averaged)
mu4_dec_all = mean(contra_mean4_dec, 2);
mu4_dec_bl  = mu4_dec_all - mu4_dec_all(onset_idx4);

hold(ax_art4,'on');
for kk4 = 1:nPred_cp
    plot(ax_art4, t_art4, contra_mean4(:,kk4) - bl4_onset(kk4), ...
        'Color',[0.85 0.85 0.85],'LineWidth',0.3,'HandleVisibility','off');
end
% SEM band shows actual spread of initial conditions across trials
fill(ax_art4, [t_art4; flipud(t_art4)], ...
    [mu4_bl + sem4_bl; flipud(mu4_bl - sem4_bl)], ...
    [0.5 0.5 0.5],'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
plot(ax_art4, t_art4, mu4_bl, 'k-','LineWidth',1.5, ...
    'DisplayName',sprintf('Raw mean ±SEM  (ratio=%.1f)', art_ratio4));
plot(ax_art4, t_art4, mu4_dec_bl, 'Color',colPink4,'LineWidth',1.2,'LineStyle','--', ...
    'DisplayName',sprintf('After decontam (\\alpha=%.1f)', cp4_alpha));
xline(ax_art4,0,'r--','LineWidth',0.8,'HandleVisibility','off');
hold(ax_art4,'off');
set(ax_art4,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(ax_art4,'Time re onset (s)','FontSize',6,'FontWeight','bold');
ylabel(ax_art4,'\DeltaF/F (%) contra dev','FontSize',6,'FontWeight','bold');
title(ax_art4,sprintf('Contra SVD artifact  decontam=%d  \\alpha=%.1f', ...
    double(do_decontam4), cp4_alpha),'FontSize',6,'FontWeight','bold');
lg_art4 = legend(ax_art4,'Location','best','Box','off','FontSize',5);
try; lg_art4.ItemTokenSize=[8 6]; catch; end
paperExport(fig_art4, fullfile(paper_root,'images','figure2','cp4_artifact_check.png'));

% Fig 2: Per-amplitude traces
fig_tr4 = paperFig(max(6, 5*nAmps4), 6);
lmT4=0.07; rmT4=0.02; bmT4=0.12; tmT4=0.10; gxT4=0.03;
pwT4 = (1-lmT4-rmT4-(nAmps4-1)*gxT4) / nAmps4;
phT4 = 1-bmT4-tmT4;

for kk4 = 1:nAmps4
    ia4 = ia_list4(kk4);
    xL4 = lmT4 + (kk4-1)*(pwT4+gxT4);
    ax_t4 = axes(fig_tr4,'Position',[xL4,bmT4,pwT4,phT4]);
    hold(ax_t4,'on');

    act_k4  = actual4{ia4}(:,iEval);
    pink_k4 = pink4{ia4}(:,iEval);
    red_k4  = red4{ia4}(:,iEval);
    tf_k4   = repmat(h_TF4{ia4}(iEval)', size(act_k4,1), 1);

    nv4k    = sum(~all(isnan(act_k4),2));
    mu_act4 = mean(act_k4, 1,'omitnan');
    mu_pink4= mean(pink_k4,1,'omitnan');
    mu_red4 = mean(red_k4, 1,'omitnan');
    mu_tf4  = mean(tf_k4,  1,'omitnan');
    se_act4 = std(act_k4,0,1,'omitnan') / sqrt(max(nv4k,1));

    fill(ax_t4,[tEval,fliplr(tEval)],[mu_act4+se_act4,fliplr(mu_act4-se_act4)], ...
        colAct4,'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
    plot(ax_t4,tEval,mu_act4, 'Color',colAct4, 'LineWidth',1.5,'DisplayName','Actual');
    plot(ax_t4,tEval,mu_tf4,  'Color',colTF4,  'LineWidth',1.0,'LineStyle','--','DisplayName','TF model');
    plot(ax_t4,tEval,mu_pink4,'Color',colPink4,'LineWidth',1.0,'LineStyle','--','DisplayName','Contra SVD ARX');
    plot(ax_t4,tEval,mu_red4, 'Color',colRed4, 'LineWidth',1.2,'LineStyle','--','DisplayName','ARX + TF');
    yline(ax_t4,0,'k:','LineWidth',0.4,'HandleVisibility','off');
    hold(ax_t4,'off');

    ek4  = act_k4(:); rk4 = red_k4(:);
    vk4  = isfinite(ek4) & isfinite(rk4);
    R2k4 = max(0, 1 - sum((ek4(vk4)-rk4(vk4)).^2) / ...
                       sum((ek4(vk4)-mean(ek4(vk4))).^2));

    set(ax_t4,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax_t4,'Time (s)','FontSize',6,'FontWeight','bold');
    if kk4==1, ylabel(ax_t4,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold'); end
    title(ax_t4,sprintf('%.2fV  R^2=%.2f',uAmp_cp(ia4),R2k4),'FontSize',6,'FontWeight','bold');
    if kk4==1
        lg_t4 = legend(ax_t4,'Location','southwest','Box','off','FontSize',5);
        try; lg_t4.ItemTokenSize=[12 6]; catch; end
    end
end
sgtitle(fig_tr4,sprintf('CP-4  %s %s e%d  |  Contra SVD ARX=%.2f  TF=%.2f  ARX+TF=%.2f', ...
    mn,td,en,R2_pink4,R2_tf4,R2_red4),'FontSize',6,'FontWeight','bold');
paperExport(fig_tr4, fullfile(paper_root,'images','figure2','cp4_traces.png'));

% Fig 3: R² bar chart
fig_r2_4 = paperFig(5, 4);
lmR4=0.16; rmR4=0.05; bmR4=0.20; tmR4=0.15;
ax_r2_4  = axes(fig_r2_4,'Position',[lmR4,bmR4,1-lmR4-rmR4,1-bmR4-tmR4]);
bh4 = bar(ax_r2_4, [R2_pink4, R2_tf4, R2_red4]*100, 0.6);
bh4.FaceColor = 'flat';
bh4.CData = [colPink4; colTF4; colRed4];
set(ax_r2_4,'XTick',1:3,'XTickLabel',{'Contra SVD','TF model','SVD + TF'}, ...
    'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
ylabel(ax_r2_4,'R^2 (%)','FontSize',6,'FontWeight','bold');
ylim(ax_r2_4,[0, max([R2_pink4,R2_tf4,R2_red4])*100*1.25 + 1]);
paperExport(fig_r2_4, fullfile(paper_root,'images','figure2','cp4_r2_bars.png'));

fprintf('[CP-4] Done. Exported: cp4_artifact_check.png  cp4_traces.png  cp4_r2_bars.png\n');

%% ── [CP-5] Individual trial on-stim trace inspection ─────────────────────────
% Grid layout: rows = amplitude levels, columns = individual trials.
% Trials within each row are sorted by ascending prediction error so the
% best- and worst-predicted trials are visible per amplitude.
%
% Adjustable parameters — edit these and re-run only this section:
nPerAmp5    = 5;      % columns: trials shown per amplitude
sort_by_err = true;   % true → ascending prediction error; false → trial order

nAmps5g = numel(ia_list4);
nCols5  = nPerAmp5;
nRows5  = nAmps5g;
fig_tr5 = figure('Color','w','Units','centimeters', ...
    'Position',[2 2 nCols5*5 nRows5*3.5]);
sgtitle(fig_tr5, sprintf('CP-5 trial grid  %s %s e%d  |  %d per amp  sorted\\_err=%d', ...
    mn, td, en, nPerAmp5, sort_by_err), ...
    'FontSize',6,'FontWeight','bold','Interpreter','tex');

spIdx5 = 0;
for aiG = 1:nAmps5g
    ia5      = ia_list4(aiG);
    act_tr5  = actual4{ia5}(:, iEval);
    pink_tr5 = pink4{ia5}(:, iEval);
    red_tr5  = red4{ia5}(:, iEval);
    err_tr5  = err4{ia5}(:);

    validRows5 = find(~all(isnan(act_tr5), 2) & isfinite(err_tr5));
    if sort_by_err && ~isempty(validRows5)
        [~, si5]   = sort(err_tr5(validRows5), 'ascend');
        validRows5 = validRows5(si5);
    end
    nUse5 = min(nPerAmp5, numel(validRows5));
    rows5 = validRows5(1:nUse5);

    for ki = 1:nPerAmp5
        spIdx5 = spIdx5 + 1;
        ax5 = subplot(nRows5, nCols5, spIdx5);
        if ki > nUse5
            axis(ax5, 'off'); continue
        end
        jj = rows5(ki);
        hold(ax5,'on');
        yl5 = [min([act_tr5(jj,:) pink_tr5(jj,:) red_tr5(jj,:)], [], 'omitnan'), ...
               max([act_tr5(jj,:) pink_tr5(jj,:) red_tr5(jj,:)], [], 'omitnan')];
        if ~any(isnan(yl5)) && diff(yl5) > 0
            patch(ax5, [0 err_end_s err_end_s 0], yl5([1 1 2 2]), ...
                [1 0.92 0.70],'FaceAlpha',0.30,'EdgeColor','none','HandleVisibility','off');
        end
        plot(ax5, tEval, pink_tr5(jj,:), 'Color',colPink4, 'LineWidth',0.7,'LineStyle','--');
        plot(ax5, tEval, red_tr5(jj,:),  'Color',colRed4,  'LineWidth',0.9,'LineStyle','--');
        plot(ax5, tEval, act_tr5(jj,:),  'Color',colAct4,  'LineWidth',1.0);
        yline(ax5, 0, 'k:', 'LineWidth',0.3,'HandleVisibility','off');
        hold(ax5,'off');
        title(ax5, sprintf('t%d  e=%.3f', jj, err_tr5(jj)), 'FontSize',5,'FontWeight','bold');
        set(ax5,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold');
        if ki == 1
            % amplitude label on y-axis of first column
            ylabel(ax5, sprintf('%.2fV\n\\DeltaF/F', uAmp_cp(ia5)), ...
                'FontSize',5,'FontWeight','bold');
        end
        if aiG == nAmps5g && ki == 1
            xlabel(ax5, 'Time (s)', 'FontSize',5,'FontWeight','bold');
        end
        if aiG == 1 && ki == 1
            legend(ax5, {'Contra SVD','ARX+TF','Actual'}, ...
                'FontSize',4,'Box','off','Location','southwest');
        end
    end
end
paperExport(fig_tr5, fullfile(paper_root,'images','figure2','cp5_trial_grid.png'));

% ── Fig B: spaghetti — all trials (faint) + mean (thick), one panel per amp ─
nAmps5   = numel(ia_list4);
fig_sp5  = paperFig(max(6, 5*nAmps5), 5);
lmSp=0.07; rmSp=0.02; bmSp=0.15; tmSp=0.12; gxSp=0.03;
pwSp = (1-lmSp-rmSp-(nAmps5-1)*gxSp) / max(nAmps5,1);
phSp = 1-bmSp-tmSp;

for kkS = 1:nAmps5
    iaS  = ia_list4(kkS);
    aS   = actual4{iaS}(:,iEval);
    pS   = pink4{iaS}(:,iEval);
    rS   = red4{iaS}(:,iEval);
    valS = find(~all(isnan(aS),2));

    muA = mean(aS(valS,:),1,'omitnan');
    muP = mean(pS(valS,:),1,'omitnan');
    muR = mean(rS(valS,:),1,'omitnan');

    xLS = lmSp + (kkS-1)*(pwSp+gxSp);
    axS = axes(fig_sp5,'Position',[xLS,bmSp,pwSp,phSp]);
    hold(axS,'on');
    for jr = valS'
        plot(axS,tEval,aS(jr,:),'Color',[colAct4  0.08],'LineWidth',0.3,'HandleVisibility','off');
        plot(axS,tEval,rS(jr,:),'Color',[colRed4  0.08],'LineWidth',0.3,'HandleVisibility','off');
        plot(axS,tEval,pS(jr,:),'Color',[colPink4 0.08],'LineWidth',0.3,'HandleVisibility','off');
    end
    plot(axS,tEval,muP,'Color',colPink4,'LineWidth',1.0,'LineStyle','--','DisplayName','Contra SVD');
    plot(axS,tEval,muR,'Color',colRed4, 'LineWidth',1.0,'LineStyle','--','DisplayName','ARX+TF');
    plot(axS,tEval,muA,'Color',colAct4, 'LineWidth',1.5,'DisplayName','Actual');
    xline(axS,err_end_s,'Color',[0.7 0.5 0],'LineStyle',':','LineWidth',0.8,'HandleVisibility','off');
    yline(axS,0,'k:','LineWidth',0.3,'HandleVisibility','off');
    hold(axS,'off');
    title(axS,sprintf('%.2fV  n=%d',uAmp_cp(iaS),numel(valS)),'FontSize',6,'FontWeight','bold');
    set(axS,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(axS,'Time (s)','FontSize',6,'FontWeight','bold');
    if kkS==1
        ylabel(axS,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold');
        lg_sp5 = legend(axS,'Location','southwest','Box','off','FontSize',5);
        try; lg_sp5.ItemTokenSize=[10 5]; catch; end
    end
end
sgtitle(fig_sp5,sprintf('CP-5 spaghetti  %s %s e%d  (each trial faint; mean thick)',mn,td,en), ...
    'FontSize',6,'FontWeight','bold');
paperExport(fig_sp5, fullfile(paper_root,'images','figure2','cp5_trial_spaghetti.png'));

fprintf('[CP-5] Done.  Exported: cp5_trial_grid.png  cp5_trial_spaghetti.png\n');

%% ── [CP-6] Prediction error correlations + scatter ───────────────────────────
% Motion/variance/delta analysis — runs after CP-5 so CP-4 prediction errors
% are fully populated before cross-correlating with behavioural predictors.

mot_thresh4 = prctile(mot_all4(isfinite(mot_all4)), 75);
motExcl4    = isfinite(mot_all4) & mot_all4 <= mot_thresh4;

vMot4  = isfinite(err_all4) & isfinite(mot_all4);
vPV4   = isfinite(err_all4) & isfinite(pv_all4)   & motExcl4;
vDpre4 = isfinite(err_all4) & isfinite(dpre_all4) & motExcl4;
vDstm4 = isfinite(err_all4) & isfinite(dstim_all4)& motExcl4;

[r4_mot,  p4_mot]  = corr(err_all4(vMot4),  mot_all4(vMot4),    'rows','complete');
[r4_pv,   p4_pv]   = corr(err_all4(vPV4),   pv_all4(vPV4),      'rows','complete');
[r4_dpre, p4_dpre] = corr(err_all4(vDpre4), dpre_all4(vDpre4),  'rows','complete');
[r4_dstm, p4_dstm] = corr(err_all4(vDstm4), dstim_all4(vDstm4), 'rows','complete');

fprintf('[CP-6] Prediction error (MSE 0-%dms) correlations:\n', round(err_end_s*1000));
fprintf('  vs Motion (all):              r=%+.3f  p=%.4f  n=%d\n',r4_mot, p4_mot, sum(vMot4));
fprintf('  vs Pre-stim var (motexcl):    r=%+.3f  p=%.4f  n=%d\n',r4_pv,  p4_pv,  sum(vPV4));
fprintf('  vs Pre-stim delta (motexcl):  r=%+.3f  p=%.4f  n=%d\n',r4_dpre,p4_dpre,sum(vDpre4));
fprintf('  vs Stim delta (motexcl):      r=%+.3f  p=%.4f  n=%d\n',r4_dstm,p4_dstm,sum(vDstm4));

% ── [CP-6w] Dip vs recovery dissociation ──────────────────────────────────────
% Recomputes per-trial MSE from the stacked traces (act_all4/red_all4) over
% DISJOINT windows — dip (0-200 ms) vs recovery (200-500 ms) — plus the full
% 0-500 ms (canonical cp_err) for reference, then re-runs the same state
% correlations (same masks as CP-6). Shows the state effect lives in the
% recovery, not the inhibition dip. Pearson + Spearman.
win_specs = { 'dip 0-200ms',       0.0, 0.2; ...
              'recovery 200-500ms', 0.2, 0.5; ...
              'full 0-500ms',       0.0, 0.5 };
fprintf('[CP-6w] State correlations — dip vs recovery dissociation:\n');
for iw = 1:size(win_specs,1)
    i_lo   = max(1, round(win_specs{iw,2}*Fs)+1);
    i_hi   = min(size(act_all4,2), round(win_specs{iw,3}*Fs)+1);
    iErr_w = i_lo:i_hi;
    err_w  = mean((act_all4(:,iErr_w) - red_all4(:,iErr_w)).^2, 2, 'omitnan');
    vMot_w   = isfinite(err_w) & isfinite(mot_all4);
    vPV_w    = isfinite(err_w) & isfinite(pv_all4)    & motExcl4;
    vDpre_w  = isfinite(err_w) & isfinite(dpre_all4)  & motExcl4;
    [rmP,pmP] = corr(err_w(vMot_w),  mot_all4(vMot_w));
    [rmS,pmS] = corr(err_w(vMot_w),  mot_all4(vMot_w),  'type','Spearman');
    [rvP,pvP] = corr(err_w(vPV_w),   pv_all4(vPV_w));
    [rvS,pvS] = corr(err_w(vPV_w),   pv_all4(vPV_w),    'type','Spearman');
    [rdP,pdP] = corr(err_w(vDpre_w), dpre_all4(vDpre_w));
    [rdS,pdS] = corr(err_w(vDpre_w), dpre_all4(vDpre_w),'type','Spearman');
    fprintf('  --- %s (n_mot=%d, n_motexcl=%d) ---\n', ...
        win_specs{iw,1}, sum(vMot_w), sum(vPV_w));
    fprintf('    Motion : Pearson r=%+.3f p=%.4f | Spearman rho=%+.3f p=%.4f\n', rmP,pmP,rmS,pmS);
    fprintf('    PreVar : Pearson r=%+.3f p=%.4f | Spearman rho=%+.3f p=%.4f\n', rvP,pvP,rvS,pvS);
    fprintf('    PreDlt : Pearson r=%+.3f p=%.4f | Spearman rho=%+.3f p=%.4f\n', rdP,pdP,rdS,pdS);
end

% Fig 13: Scatter plots (2x2) -- prediction error vs 4 predictors
fig_sc4 = paperFig(12, 10);
lmS4=0.11; rmS4=0.04; bmS4=0.12; tmS4=0.08; gxS4=0.08; gyS4=0.10;
pwS4 = (1-lmS4-rmS4-gxS4)/2;
phS4 = (1-bmS4-tmS4-gyS4)/2;

sdat4 = { ...
    err_all4(vMot4),  mot_all4(vMot4),    'Motion (a.u.)',                r4_mot, p4_mot;  ...
    err_all4(vPV4),   pv_all4(vPV4),      'Pre-stim var (\DeltaF/F)^2',  r4_pv,  p4_pv;   ...
    err_all4(vDpre4), dpre_all4(vDpre4),  'Pre-stim \delta power',        r4_dpre,p4_dpre; ...
    err_all4(vDstm4), dstim_all4(vDstm4), 'Stim-window \delta power',     r4_dstm,p4_dstm  ...
};
spos4 = {[lmS4, bmS4+phS4+gyS4, pwS4, phS4], [lmS4+pwS4+gxS4, bmS4+phS4+gyS4, pwS4, phS4], ...
         [lmS4, bmS4,            pwS4, phS4], [lmS4+pwS4+gxS4, bmS4,            pwS4, phS4]};

for sp4 = 1:4
    xd4 = sdat4{sp4,2}; yd4 = sdat4{sp4,1};
    xl4 = sdat4{sp4,3}; r4v = sdat4{sp4,4}; p4v = sdat4{sp4,5};

    ax_s4 = axes(fig_sc4,'Position',spos4{sp4});
    hold(ax_s4,'on');
    scatter(ax_s4,xd4,yd4,10,[0.5 0.5 0.5],'filled','MarkerFaceAlpha',0.4);
    if numel(xd4) > 2 && std(xd4) > eps
        xfit4 = linspace(min(xd4),max(xd4),100);
        yfit4 = polyval(polyfit(xd4,yd4,1),xfit4);
        plot(ax_s4,xfit4,yfit4,'r-','LineWidth',1.2);
    end
    hold(ax_s4,'off');

    if p4v<0.001, sig4='***'; elseif p4v<0.01, sig4='**';
    elseif p4v<0.05, sig4='*'; else, sig4='ns'; end
    text(ax_s4,0.97,0.97,sprintf('r=%+.2f %s',r4v,sig4), ...
        'Units','normalized','FontSize',5,'FontWeight','bold', ...
        'HorizontalAlignment','right','VerticalAlignment','top');
    text(ax_s4,0.97,0.84,sprintf('n=%d',numel(xd4)), ...
        'Units','normalized','FontSize',5,'Color',[0.5 0.5 0.5], ...
        'HorizontalAlignment','right','VerticalAlignment','top');
    set(ax_s4,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(ax_s4,xl4,'FontSize',6,'FontWeight','bold');
    ylabel(ax_s4,'Pred error (MSE)','FontSize',6,'FontWeight','bold');
end
sgtitle(fig_sc4,sprintf('CP-6 error correlations  %s %s e%d',mn,td,en), ...
    'FontSize',6,'FontWeight','bold');
paperExport(fig_sc4, fullfile(paper_root,'images','figure2','cp4_error_correlations.png'));

fprintf('[CP-6] Done. Exported: cp4_error_correlations.png\n');

%% ── [CP-6b] High vs low motion classification ────────────────────────────────
% Split trials by session-z-scored motion (threshold = 0 = session mean).
% mot_all4 is already in session-z-score units after the CP-4c change.

motH6 = mot_all4 > 0  & isfinite(mot_all4);
motL6 = mot_all4 <= 0 & isfinite(mot_all4);
fprintf('[CP-6b] High motion (z>0): %d trials  |  Low motion (z≤0): %d trials\n', ...
    sum(motH6), sum(motL6));

% Rows of act_all4 / pink_all4 / red_all4 align with mot_all4 / err_all4.
validRow6 = ~any(isnan(act_all4), 2);

muActH  = mean(act_all4(motH6 & validRow6, iEval), 1, 'omitnan');
muActL  = mean(act_all4(motL6 & validRow6, iEval), 1, 'omitnan');
semActH = std(act_all4(motH6 & validRow6, iEval), 0, 1, 'omitnan') / sqrt(max(sum(motH6 & validRow6),1));
semActL = std(act_all4(motL6 & validRow6, iEval), 0, 1, 'omitnan') / sqrt(max(sum(motL6 & validRow6),1));

muPinkH = mean(pink_all4(motH6 & validRow6, iEval), 1, 'omitnan');
muPinkL = mean(pink_all4(motL6 & validRow6, iEval), 1, 'omitnan');

vEH = motH6 & isfinite(err_all4);
vEL = motL6 & isfinite(err_all4);
errH_mu  = mean(err_all4(vEH), 'omitnan');
errH_sem = std( err_all4(vEH), 'omitnan') / sqrt(max(sum(vEH),1));
errL_mu  = mean(err_all4(vEL), 'omitnan');
errL_sem = std( err_all4(vEL), 'omitnan') / sqrt(max(sum(vEL),1));
fprintf('[CP-6b] Pred error  High=%.4f±%.4f  Low=%.4f±%.4f\n', ...
    errH_mu, errH_sem, errL_mu, errL_sem);

colH6 = [0.85 0.35 0.10];   % orange — high motion
colL6 = [0.15 0.45 0.80];   % blue   — low motion

fig_ms6 = paperFig(12, 8);
lm6=0.08; rm6=0.04; bm6=0.13; tm6=0.10; gx6=0.10;
pw6 = (1-lm6-rm6-gx6)/2;

% Left panel: mean actual ± SEM for high vs low motion
ax6L = axes(fig_ms6, 'Position', [lm6, bm6, pw6, 1-bm6-tm6]);
hold(ax6L, 'on');
fill(ax6L, [tEval, fliplr(tEval)], ...
    [muActH+semActH, fliplr(muActH-semActH)], colH6, ...
    'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
fill(ax6L, [tEval, fliplr(tEval)], ...
    [muActL+semActL, fliplr(muActL-semActL)], colL6, ...
    'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
plot(ax6L, tEval, muActH,  'Color',colH6, 'LineWidth',1.5, 'DisplayName',sprintf('High mot (n=%d)',sum(motH6)));
plot(ax6L, tEval, muActL,  'Color',colL6, 'LineWidth',1.5, 'DisplayName',sprintf('Low mot (n=%d)',sum(motL6)));
plot(ax6L, tEval, muPinkH, 'Color',colH6, 'LineWidth',0.8, 'LineStyle','--','HandleVisibility','off');
plot(ax6L, tEval, muPinkL, 'Color',colL6, 'LineWidth',0.8, 'LineStyle','--','HandleVisibility','off');
xline(ax6L, 0, 'k:', 'LineWidth',0.6,'HandleVisibility','off');
xline(ax6L, err_end_s, 'Color',[0.7 0.5 0],'LineStyle',':','LineWidth',0.8,'HandleVisibility','off');
yline(ax6L, 0, 'k:', 'LineWidth',0.3,'HandleVisibility','off');
hold(ax6L, 'off');
set(ax6L, 'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(ax6L, 'Time (s)',     'FontSize',6,'FontWeight','bold');
ylabel(ax6L, '\DeltaF/F',   'FontSize',6,'FontWeight','bold');
lh6 = legend(ax6L, 'Location', 'southwest');
set(lh6, 'FontSize', 5, 'Box', 'off');
try; set(lh6, 'ItemTokenSize', [6 6]); catch; end
title(ax6L, 'Mean actual ± SEM  (dashed = contra pred)', 'FontSize',6,'FontWeight','bold');

% Right panel: mean prediction error ± SEM bar chart
ax6R = axes(fig_ms6, 'Position', [lm6+pw6+gx6, bm6+0.15, pw6*0.5, 1-bm6-tm6-0.15]);
hold(ax6R, 'on');
bar(ax6R, 1, errH_mu, 0.5, 'FaceColor',colH6, 'EdgeColor','none');
bar(ax6R, 2, errL_mu, 0.5, 'FaceColor',colL6, 'EdgeColor','none');
errorbar(ax6R, [1 2], [errH_mu errL_mu], [errH_sem errL_sem], ...
    'k.', 'LineWidth',1.0, 'CapSize',4);
hold(ax6R, 'off');
set(ax6R, 'Box','off','TickDir','out','FontSize',6,'FontWeight','bold', ...
    'XTick',[1 2],'XTickLabel',{'High','Low'},'XLim',[0.3 2.7]);
ylabel(ax6R, 'Pred error (MSE 0-500ms)', 'FontSize',6,'FontWeight','bold');
title(ax6R, 'Error by motion group', 'FontSize',6,'FontWeight','bold');

sgtitle(fig_ms6, sprintf('CP-6b motion split  %s %s e%d',mn,td,en), ...
    'FontSize',6,'FontWeight','bold');
paperExport(fig_ms6, fullfile(paper_root,'images','figure2','cp6_motion_split.png'));
fprintf('[CP-6b] Done. Exported: cp6_motion_split.png\n');

%% ── [CP-6c/6d] Pre-stim variance & delta-power splits (mirror CP-6b) ──────────
% Median hi/lo split on motion-excluded trials (same cohort as the CP-6
% variance/delta correlations). Grouped comparison + trace means complement the
% CP-6 scatter. Error bars use err_all4 (canonical 0-500ms); the dip-vs-recovery
% dissociation (CP-6w) shows the effect concentrates in the 200-500ms recovery.
split_states = { ...
    'CP-6c', pv_all4,   'Pre-stim variance', 'cp6c_pvar_split.png'; ...
    'CP-6d', dpre_all4, 'Pre-stim \delta',   'cp6d_delta_split.png' };

for is = 1:size(split_states,1)
    stag = split_states{is,1};  sv = split_states{is,2};
    slbl = split_states{is,3};  sfile = split_states{is,4};

    base6 = motExcl4 & isfinite(sv) & validRow6;     % motion-excluded, valid traces
    medS  = median(sv(base6), 'omitnan');
    hiS   = base6 & sv >  medS;
    loS   = base6 & sv <= medS;
    fprintf('[%s] %s split (motexcl, median=%.3g): High=%d  Low=%d trials\n', ...
        stag, slbl, medS, sum(hiS), sum(loS));

    muActHi = mean(act_all4(hiS, iEval), 1, 'omitnan');
    muActLo = mean(act_all4(loS, iEval), 1, 'omitnan');
    semActHi= std(act_all4(hiS, iEval),0,1,'omitnan')/sqrt(max(sum(hiS),1));
    semActLo= std(act_all4(loS, iEval),0,1,'omitnan')/sqrt(max(sum(loS),1));
    muPinkHi= mean(pink_all4(hiS, iEval), 1, 'omitnan');
    muPinkLo= mean(pink_all4(loS, iEval), 1, 'omitnan');

    eHi_mu = mean(err_all4(hiS),'omitnan'); eHi_sem = std(err_all4(hiS),'omitnan')/sqrt(max(sum(hiS),1));
    eLo_mu = mean(err_all4(loS),'omitnan'); eLo_sem = std(err_all4(loS),'omitnan')/sqrt(max(sum(loS),1));
    [~, pErr] = ttest2(err_all4(hiS), err_all4(loS));
    fprintf('[%s] Pred error  High=%.4f±%.4f  Low=%.4f±%.4f  (t-test p=%.4f)\n', ...
        stag, eHi_mu, eHi_sem, eLo_mu, eLo_sem, pErr);

    colHi = [0.60 0.20 0.60];   % purple — high state
    colLo = [0.20 0.60 0.45];   % teal   — low state

    fig_sd = paperFig(12, 8);
    lmd=0.08; rmd=0.04; bmd=0.13; tmd=0.10; gxd=0.10;
    pwc = (1-lmd-rmd-gxd)/2;

    axL = axes(fig_sd, 'Position', [lmd, bmd, pwc, 1-bmd-tmd]);
    hold(axL,'on');
    fill(axL,[tEval,fliplr(tEval)],[muActHi+semActHi, fliplr(muActHi-semActHi)],colHi,'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    fill(axL,[tEval,fliplr(tEval)],[muActLo+semActLo, fliplr(muActLo-semActLo)],colLo,'FaceAlpha',0.2,'EdgeColor','none','HandleVisibility','off');
    plot(axL,tEval,muActHi,'Color',colHi,'LineWidth',1.5,'DisplayName',sprintf('High (n=%d)',sum(hiS)));
    plot(axL,tEval,muActLo,'Color',colLo,'LineWidth',1.5,'DisplayName',sprintf('Low (n=%d)',sum(loS)));
    plot(axL,tEval,muPinkHi,'Color',colHi,'LineWidth',0.8,'LineStyle','--','HandleVisibility','off');
    plot(axL,tEval,muPinkLo,'Color',colLo,'LineWidth',0.8,'LineStyle','--','HandleVisibility','off');
    xline(axL,0,'k:','LineWidth',0.6,'HandleVisibility','off');
    xline(axL,0.2,'Color',[0.5 0.5 0.5],'LineStyle',':','LineWidth',0.6,'HandleVisibility','off');
    xline(axL,err_end_s,'Color',[0.7 0.5 0],'LineStyle',':','LineWidth',0.8,'HandleVisibility','off');
    yline(axL,0,'k:','LineWidth',0.3,'HandleVisibility','off');
    hold(axL,'off');
    set(axL,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(axL,'Time (s)','FontSize',6,'FontWeight','bold');
    ylabel(axL,'\DeltaF/F','FontSize',6,'FontWeight','bold');
    lhd = legend(axL,'Location','southwest'); set(lhd,'FontSize',5,'Box','off');
    try; set(lhd,'ItemTokenSize',[6 6]); catch; end
    title(axL,'Mean actual ± SEM  (dashed = contra pred)','FontSize',6,'FontWeight','bold');

    axR = axes(fig_sd, 'Position',[lmd+pwc+gxd, bmd+0.15, pwc*0.5, 1-bmd-tmd-0.15]);
    hold(axR,'on');
    bar(axR,1,eHi_mu,0.5,'FaceColor',colHi,'EdgeColor','none');
    bar(axR,2,eLo_mu,0.5,'FaceColor',colLo,'EdgeColor','none');
    errorbar(axR,[1 2],[eHi_mu eLo_mu],[eHi_sem eLo_sem],'k.','LineWidth',1.0,'CapSize',4);
    hold(axR,'off');
    set(axR,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold','XTick',[1 2],'XTickLabel',{'High','Low'},'XLim',[0.3 2.7]);
    ylabel(axR,sprintf('Pred error (MSE 0-%dms)',round(err_end_s*1000)),'FontSize',6,'FontWeight','bold');
    title(axR,sprintf('Error by %s  (p=%.3f)',slbl,pErr),'FontSize',6,'FontWeight','bold');

    sgtitle(fig_sd, sprintf('%s %s split  %s %s e%d',stag,slbl,mn,td,en),'FontSize',6,'FontWeight','bold');
    paperExport(fig_sd, fullfile(paper_root,'images','figure2',sfile));
    fprintf('[%s] Done. Exported: %s\n', stag, sfile);
end

%% ── [CP-6i] Interactive trial inspector ──────────────────────────────────────
% Click any point on the motion-vs-error scatter to overlay that trial's
% actual trace, its amplitude-average, and the prediction, plus the
% motion-energy trace locked to that trial's onset.
mot_z_full = (mot_full(1:nF_m) - mot_mean_sess4) / max(mot_std_sess4, eps);

S_insp.mot_all4   = mot_all4;
S_insp.err_all4   = err_all4;
S_insp.amp_all4   = amp_all4;
S_insp.act_all4   = act_all4(:, iEval);
S_insp.red_all4   = red_all4(:, iEval);
S_insp.tEval      = tEval;
S_insp.onset_all4 = onset_all4;
S_insp.mot_z      = mot_z_full;
S_insp.Fs         = Fs;

cp_trial_inspector(S_insp);
fprintf('[CP-6i] Inspector launched — click a trial point to inspect.\n');

%% ── [CP-7] Per-session error-sorted heatmap (clickable) ──────────────────────
% One panel per amplitude. X = time (ms), Y = trial rank (ascending pred error).
% Click any row to pop a detail figure: actual + amp average + prediction.
S7.actual4    = actual4;
S7.pink4      = pink4;
S7.red4       = red4;
S7.err4       = err4;
S7.tEval      = tEval;
S7.uAmp_cp    = uAmp_cp;
S7.ia_list4   = ia_list4;
S7.iEval      = iEval;
S7.err_end_s  = err_end_s;
S7.mn         = mn;
S7.td         = td;
S7.en         = en;
S7.paper_root = paper_root;

cp_error_heatmap(S7);

% Helpers live in utils/ (on path via addpath at top):
%   compute_r2, per_trial_r2, plot_window, rrr_fit,
%   build_onset_artifact, brain_overlay_fig, cp_trial_inspector,
%   cp_error_heatmap
