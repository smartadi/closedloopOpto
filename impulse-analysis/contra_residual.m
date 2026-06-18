% impulse-analysis/contra_residual.m
% Simplified contra-residual pipeline — stops after [CP-IMP].
%
% Fits the spontaneous contra→ipsi map (beta_cp) on pre-trial windows, applies
% stim-bleed decontamination, and isolates the laser-driven residual response.
% All downstream concurrent-prediction / TF / error-correlation sections removed.
%
% Key outputs left in workspace:
%   res_imp{ia}  — per-amplitude residual traces [nTrials × nImp]  (stim response)
%   act_imp{ia}  — per-amplitude actual traces   [nTrials × nImp]
%   prd_imp{ia}  — per-amplitude decontam pred   [nTrials × nImp]
%   t_imp        — time axis (s), −1..+1 re onset
%   uAmp_cp, nzMask_cp, ia_imp  — amplitude metadata
%
% Prereqs: load_experiments.m has been run (allExperiments in workspace).
% Run from brain_paper/ root directory or impulse-analysis/.
close all;
clc;


% Resolve the script's own folder robustly (independent of cwd / MATLAB path):
cp_path    = mfilename('fullpath');
if isempty(cp_path), cp_path = which('contra_residual'); end
if isempty(cp_path), cp_path = fullfile(pwd, 'contra_residual.m'); end
impulseDir = fileparts(cp_path);
paperRoot  = fullfile(impulseDir, '..', 'paper');
utilsDir   = fullfile(impulseDir, '..', 'utils');
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
    warning('contra_residual: cannot locate paper/ -- paths may be wrong.');
end

%% Setup -- session and model parameters
selExp    = 3;      % experiment index (default 3 = AL_0033 2025-01-29)
pY        = 0;      % AR self-lags on y (0 = pure contra prediction)
pX        = 0;      % predictor lags. 0 = instantaneous map y(t)=B*contra(t).
nSV_load  = 500;    % SVD components to load from disk
nSV_use   = 200;    % contra SVD components used as predictors (z-scored).
spont_pre = 6;      % pre-trial spontaneous training window (s)
dur_imp   = 3.0;    % trial window (s)
redefine_roi  = false; % set true to force re-draw midline + contra polygon
% Artifact baseline mode for build_onset_artifact:
%   'none'           : subtract pre-stim mean only
%   'shifted_window' : subtract matched spontaneous window shifted ~20 s before onset (Option C)
%   'detrend'        : subtract per-trial linear trend extrapolated from pre-stim
bleed_spont_ref      = 'shifted_window';
bleed_spont_offset_s = 20;   % s to shift back for spontaneous reference window

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('contra_residual: run load_experiments.m first.');
end

mn = allExperiments(selExp).mn;
td = allExperiments(selExp).td;
en = allExperiments(selExp).en;
fprintf('contra_residual: %s  %s  en=%d\n', mn, td, en);

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
roi_name = sprintf('cp_roi_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en);
roi_file = fullfile(dataDir, roi_name);
fprintf('[CP] ROI cache expected at: %s\n', roi_file);

% Migrate from any known legacy location into data/.
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
    fig_roi = figure('Color','k','Name','contra_residual: define midline + contra ROI');
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
fig_pmap = figure('Color','k','Name','contra_residual: contra ROI');
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
% Motion deliberately excluded — keeps it as independent state variable for
% downstream analysis. (2026-06-17)
nF_m   = min(nFrames, numel(mot_full));
X_cp_z = zscore(X_cp(1:nF_m,:));
X_cp_m = X_cp_z;                    % [nF_m × nPred_cp]
fprintf('Predictor matrix: %d contra SVD (z-scored) features (motion-free baseline)\n', ...
    size(X_cp_m,2));

%% [CP-FIT] Spontaneous contra→ipsi map fit
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

% 5-fold partition
split_seed = 42;  kfold = 5;
rng(split_seed);
fold_id = mod(randperm(nValid_cp)-1, kfold) + 1;

% Quick single-fold held-out R²
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

%% [CP-IMP] Impulse-window contra prediction + stim-bleed negation (no TF)
% Apply the spontaneous instantaneous contra map (beta_cp) across [-1,+1] s using
% only concurrent contra -- no stimulus info, no TF.
%
% STIM-BLEED NEGATION (decontam): the contra hemisphere is itself driven by the
% stimulus, so the raw prediction reproduces ~79% of the dip. We remove the
% per-amplitude ONSET-LOCKED contra deviation (the stim bleed) from the predictors
% -- but ONLY during the sharp stim-dip window (neg_win), NOT the whole second.
% Outside neg_win the prediction runs on actual contra and resumes tracking, so:
%   - dip window:  contra suppressed -> dip NOT predicted -> dip lands in residual
%   - after dip:   contra active     -> post-dip recovery IS predicted (coupled
%                  network activity) -> residual returns toward flat
if pX ~= 0
    warning('[CP-IMP] assumes instantaneous model (pX=0); current pX=%d.', pX);
end

decontam = true;
neg_win  = [0 0.30];
decontam_mode = 'scaledkernel';
kernel_alpha = 0.85;
taper_win = [0.20 0.40];
pca_per_amp  = true;
n_art_pca = 1;

pre_imp  = Fs;
post_imp = Fs;
nImp     = pre_imp + post_imp + 1;
t_imp    = (-pre_imp:post_imp) / Fs;
pre_bl   = 1:pre_imp;
iDip     = find(t_imp >= 0 & t_imp <= 0.2);
iPostDip = find(t_imp > neg_win(2) & t_imp <= 1);
neg_mask = (t_imp >= neg_win(1) & t_imp <= neg_win(2))';

nAmp_imp = numel(uAmp_cp);
act_imp  = cell(nAmp_imp,1);
prd_imp  = cell(nAmp_imp,1);
prr_imp  = cell(nAmp_imp,1);
res_imp  = cell(nAmp_imp,1);
art_imp  = cell(nAmp_imp,1);
art_tap_imp = cell(nAmp_imp,1);

% ---- Pass 1: per-amplitude onset-locked contra artifact ----------------------
if ~exist('bleed_spont_ref',     'var'); bleed_spont_ref      = 'shifted_window'; end
if ~exist('bleed_spont_offset_s','var'); bleed_spont_offset_s = 20; end
art_raw_imp = build_onset_artifact(nAmp_imp, nzMask_cp, imp_data, t_full, X_cp_m, ...
    nPred_cp, pre_imp, post_imp + 1, nF_m, bleed_spont_ref, round(bleed_spont_offset_s * Fs));
taper_w = ones(1, nImp);
tr = (t_imp >= taper_win(1) & t_imp <= taper_win(2));
taper_w(tr) = 0.5 * (1 + cos(pi * (t_imp(tr) - taper_win(1)) / (taper_win(2) - taper_win(1))));
taper_w(t_imp > taper_win(2)) = 0;
taper_w(t_imp < 0) = 0;
for ia = 1:nAmp_imp
    tmp = art_raw_imp{ia};
    tmp(~neg_mask, :) = 0;
    art_imp{ia} = tmp;
    tt = art_raw_imp{ia};
    tt(t_imp < 0, :) = 0;
    art_tap_imp{ia} = tt .* taper_w(:);
end

% ---- PCA artifact basis (for decontam_mode='pca') ----------------------------
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
Ab_pca = coeff_pca(:, 1:n_art_pca)';
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
        Xw     = X_cp_m(g,:);
        yp_raw = [ones(nImp,1), Xw] * beta_cp;
        if decontam && strcmpi(decontam_mode,'pca')
            if pca_per_amp, Ab_use = Ab_pca_amp{ia}; else, Ab_use = Ab_pca; end
            seg   = X_cp_m(g, 1:nPred_cp);
            bc    = seg - mean(seg(pre_bl,:), 1, 'omitnan');
            recon = zeros(nImp, nPred_cp);
            recon(neg_mask,:) = (bc(neg_mask,:) * Ab_use') * Ab_use;
            Xw(:,1:nPred_cp) = seg - recon;
        elseif decontam && strcmpi(decontam_mode,'scaledkernel')
            Xw(:,1:nPred_cp) = Xw(:,1:nPred_cp) - kernel_alpha * art_tap_imp{ia};
        elseif decontam
            Xw(:,1:nPred_cp) = Xw(:,1:nPred_cp) - art;
        end
        yp_dec = [ones(nImp,1), Xw] * beta_cp;
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

% ---- Amp-0 control -----------------------------------------------------------
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

% ---- Bleed quantification at the dip (0-200 ms) -----------------------------
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
fprintf('  POOLED actual=%+.3f | raw bleed=%4.0f%% -> decontam bleed=%4.0f%%  (residual recovers %.0f%% of dip)\n', ...
    da_pool, 100*dr_pool/(da_pool+eps), 100*dd_pool/(da_pool+eps), 100*(1-dd_pool/(da_pool+eps)));

postdip = @(M) mean(abs(mean(M(:,iPostDip),1,'omitnan')));
ra_post = postdip(A_pool);
rr_post = postdip(cell2mat(res_imp(nzMask_cp)));
fprintf('  POST-DIP (%.2f-1 s): |actual|=%.3f  |residual|=%.3f  -> contra explains %.0f%% of post-dip\n', ...
    neg_win(2), ra_post, rr_post, 100*(1-rr_post/(ra_post+eps)));
[~, ib_bnd] = min(abs(t_imp - neg_win(2)));
bump = mean(arrayfun(@(ia) abs(mean(res_imp{ia}(:,ib_bnd),'omitnan')), ia_imp));
fprintf('  BOUNDARY smoothness @%.2fs (mean |residual step|): %.3f\n', neg_win(2), bump);
if ~isempty(A0)
    fprintf('  AMP-0 control (no stim, n=%d): actual=%+.3f  pred=%+.3f\n', ...
        size(A0,1), dip(A0), dip(P0));
end

% ---- Figure: actual + raw pred + decontam pred (top) + residual (bottom) ----
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

    % Top: actual, raw (contaminated) pred, decontam pred
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

    % Bottom: residual = actual - decontam pred
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

% ---- Script ends here. Workspace contains: ----------------------------------
%   res_imp, act_imp, prd_imp, prr_imp  — per-amplitude trial matrices [nT x nImp]
%   t_imp                               — time axis (s)
%   ia_imp, uAmp_cp, nzMask_cp          — amplitude metadata
%   beta_cp                             — spontaneous contra map coefficients
%   X_cp_m, U_svd_cp                    — contra SVD signals and spatial modes
% Add residual-analysis sections below as needed.
