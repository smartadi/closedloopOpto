function [R, S] = cp_residual_core(allExperiments, selExp, opts)
% cp_residual_core — shared contra→ipsi RESIDUAL pipeline (state + dose-response).
%
% Fits the spontaneous contra→ipsi map (beta_cp) on pre-trial windows, optionally
% applies stim-bleed decontamination, and isolates the laser-driven residual
% response = actual_ipsi - contra_predicted_baseline. Computes per-trial residual
% energy + deviation-from-amp-average (dev_stim/dev_pre) and the state covariates
% (motion, pre-stim variance, 1-4 Hz delta) for the state-dependence test.
%
% INPUTS
%   allExperiments — struct array from load_experiments.m
%   selExp         — experiment index (default 3 = AL_0033 2025-01-29)
%   opts (struct, all optional):
%     .decontam   (true)  — stim-bleed decontamination. NOTE: cancels in the
%                           within-amp state metrics; only affects absolute magnitude.
%     .use_motion (true)  — append motion as a nuisance regressor to the contra map
%     .make_wide  (false) — build wide (-2..+2 s) per-trial traces for the inspector
%     .plot       (false) — draw the standard diagnostic figures + export PNGs
%
% OUTPUTS
%   R — data struct: res_imp/act_imp/prd_imp/prr_imp, t_imp, iDip, per-trial DVs
%       (resE/devS/devP) + covariates (mot/pv/dp/amp) + masks, beta_cp, R.Sin
%       (inspector payload when make_wide), metadata (mn/td/en/Fs/cv_mean).
%   S — state stats: r/p for dev_stim, dev_pre, partial(stim|pre), res_E per state.
%
% Prereqs: load_experiments.m has been run. Helpers resolved from utils/.
if nargin < 3 || isempty(opts), opts = struct(); end
def = struct('decontam',true,'use_motion',true,'make_wide',false,'plot',false, ...
             'predictor','hemi');   % 'hemi' = [CP-HEMI] field->kernel map (default); 'ols' = legacy beta_cp
ofn = fieldnames(def);
for ofk = 1:numel(ofn)
    if ~isfield(opts, ofn{ofk}), opts.(ofn{ofk}) = def.(ofn{ofk}); end
end
decontam       = opts.decontam;
use_motion     = opts.use_motion;
make_wide      = opts.make_wide;
make_inspector = make_wide;     % inspector traces built only when wide requested
do_plot        = opts.plot;
predictor      = opts.predictor;


% Resolve folders relative to THIS function's location (utils/). Guard against
% the editor-temp staging path (...\Temp\Editor_*) seen when a file is run with
% unsaved changes, so caches never land in tempdir.
core_path  = mfilename('fullpath');
if isempty(core_path) || startsWith(core_path, tempdir)
    w = which('cp_residual_core');
    if ~isempty(w) && ~startsWith(w, tempdir), core_path = w; end
end
utilsDir   = fileparts(core_path);
impulseDir = fullfile(utilsDir, '..', 'impulse-analysis');
paperRoot  = fullfile(utilsDir, '..', 'paper');
dataDir    = fullfile(impulseDir, 'data');
if ~exist(dataDir, 'dir'), mkdir(dataDir); end
addpath(utilsDir);
addpath(genpath(utilsDir));

PS = paperStyle();
setPaperDefaults();

paper_root = paperRoot;   % absolute path resolved from function location

%% Setup -- session and model parameters
if nargin < 2 || isempty(selExp), selExp = 3; end   % default 3 = AL_0033 2025-01-29
pY        = 0;      % AR self-lags on y (0 = pure contra prediction)
pX        = 0;      % predictor lags. 0 = instantaneous map y(t)=B*contra(t).
nSV_load  = 500;    % SVD components to load from disk
nSV_use   = 200;    % contra SVD components used as predictors (z-scored).
spont_pre = 6;      % pre-trial spontaneous training window (s)
dur_imp   = 3.0;    % trial window (s)
redefine_roi  = false; % set true to force re-draw brain outline + midline (cp_roi_masks)
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
% brain_mask_cp / contra / ipsi masks are built from the ROI by cp_roi_masks below.

d_tmp    = loadData(serverRoot, mn, td, en);
horizon  = double(d_tmp.params.horizon);
w_r      = horizon - 1;
idx_r_cp = 1:nFrames;
py_prim  = double(d_tmp.params.pixel(1));
px_prim  = double(d_tmp.params.pixel(2));
k_prim   = double(d_tmp.params.kernel);   % recording-kernel half-width (for HEMI predictor)
mot_full = d_tmp.motion.motion_1(1:2:end);
clear d_tmp

%% Brain mask + contra/ipsi split (full-brain mask bisected by the midline)
% Single source of truth (utils/cp_roi_masks): draws the FULL-BRAIN outline + the
% midline on first run / redefine_roi, bisects the brain by the midline, and tags
% the side with the primary (recording) pixel as IPSI (target); other = CONTRA
% (predictor). Same helper + ROI cache (cp_roi2_*) as contra_prediction.m, so the
% benchmark and the residual share identical masks.
roi_name = sprintf('cp_roi2_%s_%s%s_e%d.mat', mn, td(6:7), td(9:10), en);
roi_file = fullfile(dataDir, roi_name);
fprintf('[CP] ROI cache expected at: %s\n', roi_file);

M_cp = cp_roi_masks(mimg_cp, roi_file, px_prim, py_prim, ...
                    struct('redefine', redefine_roi, 'thr_pctile', 20, 'plot', do_plot));
valid_cp_svd  = M_cp.contra;    % CONTRA = predictor hemisphere
ipsi_mask_cp  = M_cp.ipsi;      % IPSI   = target hemisphere (primary-pixel side)

%% SVD extraction -- contra predictor signals (SVD-direct mode only)
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

nSV_actual = min(nSV_use, size(V_c_full, 1));
U_svd_cp   = U_svd_raw(:, 1:nSV_actual);   % [nPix_c × nSV_actual]
X_cp       = V_c_full(1:nSV_actual, :)';   % [nFrames × nSV_actual]
nPred_cp   = nSV_actual;
fprintf('SVD-direct: using %d/%d modes\n', nSV_actual, size(V_c_full,1));

%% Predictor matrix (contra SVD modes + optional motion nuisance regressor)
% use_motion = true puts motion BACK as a baseline predictor (improves contra
% prediction; motion then treated as a NUISANCE, not a state variable to test —
% so no circularity for the variance/delta state analysis). (2026-06-19)
if ~exist('use_motion','var'), use_motion = true; end
nF_m   = min(nFrames, numel(mot_full));
X_cp_z = zscore(X_cp(1:nF_m,:));
if use_motion
    mot_z  = zscore(mot_full(1:nF_m)); mot_z = mot_z(:);
    X_cp_m = [X_cp_z, mot_z];       % motion = LAST column (decontam touches 1:nPred_cp only)
    fprintf('Predictor matrix: %d contra SVD + 1 motion = %d features\n', nPred_cp, size(X_cp_m,2));
else
    X_cp_m = X_cp_z;                % [nF_m × nPred_cp]
    fprintf('Predictor matrix: %d contra SVD (z-scored), motion-free\n', size(X_cp_m,2));
end

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

% ---- Predictor of record: HEMI field->kernel map (default) or legacy OLS beta_cp --
% predFun(g) returns the contra "Global" prediction of the primary pixel (%dF/F)
% for frame indices g, as a column vector. HEMI uses the [CP-HEMI] shared-latent
% field->kernel readout (cp_hemi_predictor); OLS uses the instantaneous beta_cp.
useHemi = strcmpi(predictor, 'hemi');
if useHemi
    Hp = cp_hemi_predictor(struct( ...
        'U_cp',U_cp,'V_cp',V_cp,'mimg_cp',mimg_cp,'nY_cp',nY_cp,'nX_cp',nX_cp, ...
        'nSV_cp',nSV_cp,'V_c_full',V_c_full,'ipsi_mask_cp',ipsi_mask_cp, ...
        'valid_cp_svd',valid_cp_svd,'py_prim',py_prim,'px_prim',px_prim, ...
        'k_prim',k_prim,'y_full',y_full,'t_full',t_full, ...
        'all_starts_cp',all_starts_cp,'nF_m',nF_m,'Fs',Fs,'path_cp',path_cp));
    Kh       = Hp.K;
    predFun  = @(g) V_c_full(1:Kh, g).' * Hp.bk + Hp.b0;   % [numel(g) x 1] %dF/F
    decontam = false;     % bleed deferred: HEMI shared latents carry no onset bleed
    cv_mean  = Hp.cv;     % held-out primary-pixel R^2 of the deployed map
    fprintf('[CP-RES] predictor = HEMI field->kernel (rank %d, held-out R^2=%.3f); decontam OFF\n', ...
        Hp.rankSel, Hp.cv);
else
    Hp      = [];
    predFun = @(g) [ones(numel(g),1), X_cp_m(g,:)] * beta_cp;   % legacy OLS map
    fprintf('[CP-RES] predictor = OLS beta_cp (%d modes); decontam=%d\n', nPred_cp, decontam);
end

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

if ~exist('decontam','var'), decontam = true; end   % presettable for comp on/off test
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
        yp_raw = predFun(g);
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
        if useHemi, yp_dec = yp_raw; else, yp_dec = [ones(nImp,1), Xw] * beta_cp; end
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
        ya = y_full(g); yp = predFun(g);
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

if do_plot
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
end   % do_plot (CP-IMP figure)

%% [CP-RES] Residual state-dependence: dev_stim vs state, controlling dev_pre
% Is the isolated stim response (residual) state-dependent BEYOND contra-prediction
% quality? Per trial:
%   res_E    = residual inhibition energy 0-200 ms (signed; stim-response size)
%   dev_stim = mean-sq deviation of residual from amp-avg residual, 0-200 ms
%              (= predictability of the stim response)
%   dev_pre  = same over the 0.2 s PRE-onset window (prediction quality, no stim)
%   covariates: motion, pre-stim variance, pre-stim 1-4 Hz delta power
% DECISIVE TEST: partialcorr(dev_stim, state | dev_pre). If state predicts dev_stim
% beyond dev_pre, the local stim response itself is state-dependent (not just a
% noisier baseline prediction). DVs z-scored WITHIN amplitude (removes amp as a
% confound); state covariates z-scored across the session (matches motThresh=1.5).

iPre_dev = find(t_imp >= -0.2 & t_imp < 0);        % matched pre-onset control window
win_r  = hann(numel(pre_bl)); W_r = sum(win_r.^2); % pre-stim spectral setup (1 s)
nfft_r = 2^nextpow2(numel(pre_bl));
fr     = (0:nfft_r-1)'/nfft_r * Fs; nB_r = floor(nfft_r/2)+1;
delta_r = fr(1:nB_r) >= 1 & fr(1:nB_r) <= 4;
zf = @(x) (x - mean(x,'omitnan')) ./ max(std(x,'omitnan'), eps);

if ~exist('make_inspector','var'), make_inspector = true; end   % clickable CP-RESi
pre_w  = 2*Fs; post_w = 2*Fs; t_w = (-pre_w:post_w)/Fs; Lw = numel(t_w);
iw_dip = find(t_w   >= 0 & t_w   <= taper_win(2));   % wide-window dip rows
it_dip = find(t_imp >= 0 & t_imp <= taper_win(2));   % matching CP-IMP artifact rows
ndip   = min(numel(iw_dip), numel(it_dip));
motz_full = (mot_full - mean(mot_full,'omitnan')) / max(std(mot_full,'omitnan'),eps);

ia_res = find(nzMask_cp(:))';
resE_all=[]; devS_all=[]; devP_all=[]; mot_all=[]; pv_all=[]; dp_all=[]; amp_all=[];
actW_all=[]; prdW_all=[]; resW_all=[]; motW_all=[];
for ia = ia_res
    R  = res_imp{ia};  nT = size(R,1);
    muD = mean(R(:,iDip),     1, 'omitnan');
    muP = mean(R(:,iPre_dev), 1, 'omitnan');
    resE = nan(nT,1); devS = nan(nT,1); devP = nan(nT,1);
    pv = nan(nT,1); dp = nan(nT,1); mt = nan(nT,1);
    actW = nan(nT,Lw); prdW = nan(nT,Lw); resW = nan(nT,Lw); motW = nan(nT,Lw);
    starts = imp_data.startTimes{ia}(:);  motA = imp_data.mot{ia}(:);
    for j = 1:nT
        if all(isnan(R(j,:))); continue; end
        resE(j) = mean(R(j,iDip), 'omitnan');
        devS(j) = mean((R(j,iDip)     - muD).^2, 'omitnan');
        devP(j) = mean((R(j,iPre_dev) - muP).^2, 'omitnan');
        if j <= numel(motA); mt(j) = motA(j); end
        [~, ion] = min(abs(t_full - starts(j)));
        gp = ion-numel(pre_bl) : ion-1;
        if gp(1) >= 1
            sp = y_full(gp);
            pv(j) = var(sp, 'omitnan');
            Xf = fft(sp(:).*win_r, nfft_r);
            pw = abs(Xf(1:nB_r)).^2 * 2/(Fs*W_r);
            dp(j) = mean(pw(delta_r), 'omitnan');
        end
        if make_inspector
            gW = ion-pre_w : ion+post_w;
            if gW(1) >= 1 && gW(end) <= min(nFrames, nF_m)
                ya   = y_full(gW);
                bl_a = mean(y_full(ion-Fs:ion-1),'omitnan');
                Xw   = X_cp_m(gW,:);
                yp_r = predFun(gW);
                bl_p = mean(yp_r(t_w>=-1 & t_w<0),'omitnan');
                Xdec = Xw;
                if decontam && strcmpi(decontam_mode,'scaledkernel')
                    artw = zeros(Lw, nPred_cp);
                    artw(iw_dip(1:ndip),:) = kernel_alpha * art_tap_imp{ia}(it_dip(1:ndip),:);
                    Xdec(:,1:nPred_cp) = Xw(:,1:nPred_cp) - artw;
                end
                if useHemi, yp_d = yp_r; else, yp_d = [ones(Lw,1), Xdec]*beta_cp; end
                actW(j,:) = (ya - bl_a)';
                prdW(j,:) = (yp_d - bl_p)';
                resW(j,:) = actW(j,:) - prdW(j,:);
                if gW(end) <= numel(motz_full); motW(j,:) = motz_full(gW)'; end
            end
        end
    end
    resE_all=[resE_all; zf(resE)]; devS_all=[devS_all; zf(devS)]; devP_all=[devP_all; zf(devP)];
    mot_all=[mot_all; mt]; pv_all=[pv_all; pv]; dp_all=[dp_all; dp];
    amp_all=[amp_all; repmat(uAmp_cp(ia), nT, 1)];   %#ok<AGROW>
    actW_all=[actW_all; actW]; prdW_all=[prdW_all; prdW];   %#ok<AGROW>
    resW_all=[resW_all; resW]; motW_all=[motW_all; motW];   %#ok<AGROW>
end
mot_all = zf(mot_all); pv_all = zf(pv_all); dp_all = zf(dp_all);   % session-z covariates

motThr = 1.5;
okM = isfinite(mot_all) & isfinite(devS_all) & isfinite(devP_all);
okV = okM & mot_all <= motThr & isfinite(pv_all);
okD = okM & mot_all <= motThr & isfinite(dp_all);

fprintf('[CP-RES] dev_stim & dev_pre vs state (Spearman; DV z-within-amp):\n');
states_rs = {'Motion', mot_all, okM; 'PreVar', pv_all, okV; 'PreDelta', dp_all, okD};
for q = 1:3
    nm = states_rs{q,1}; xs = states_rs{q,2}; m = states_rs{q,3};
    [rS,pS] = corr(devS_all(m), xs(m), 'type','Spearman', 'rows','complete');
    [rP,pP] = corr(devP_all(m), xs(m), 'type','Spearman', 'rows','complete');
    [rA,pA] = partialcorr(devS_all(m), xs(m), devP_all(m), 'type','Spearman', 'rows','complete');
    fprintf('  %-8s: dev_stim rho=%+.3f p=%.3g | dev_pre rho=%+.3f p=%.3g | PARTIAL(stim|pre) rho=%+.3f p=%.3g  n=%d\n', ...
        nm, rS, pS, rP, pP, rA, pA, sum(m));
end
[reM,~] = corr(resE_all(okM), mot_all(okM), 'type','Spearman', 'rows','complete');
[reV,~] = corr(resE_all(okV), pv_all(okV),  'type','Spearman', 'rows','complete');
[reD,~] = corr(resE_all(okD), dp_all(okD),  'type','Spearman', 'rows','complete');
fprintf('  res_E (magnitude) vs: motion rho=%+.3f | var rho=%+.3f | delta rho=%+.3f\n', reM, reV, reD);

if do_plot
% figure: top row dev_stim vs state, bottom row dev_pre vs state (control)
fig_rs = paperFig(20, 12);
sdc = {mot_all,'Motion (z)',okM; pv_all,'Pre-stim var (z)',okV; dp_all,'Pre-stim \delta (z)',okD};
dvc = {devS_all,'dev_{stim} (z)'; devP_all,'dev_{pre} (z)'};
for rr = 1:2
    for cc = 1:3
        axr = subplot(2,3,(rr-1)*3+cc); hold(axr,'on');
        mm = sdc{cc,3}; xv = sdc{cc,1}(mm); yv = dvc{rr,1}(mm);
        gd = isfinite(xv) & isfinite(yv); xv = xv(gd); yv = yv(gd);
        scatter(axr, xv, yv, 8, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha',0.3);
        if numel(xv) > 2
            pc = polyfit(xv, yv, 1); xl = [min(xv) max(xv)];
            plot(axr, xl, polyval(pc,xl), 'r-', 'LineWidth',1.2);
            [rv,pvl] = corr(xv, yv, 'type','Spearman');
            title(axr, sprintf('\\rho=%+.2f p=%.2g', rv, pvl), 'FontSize',6,'FontWeight','bold');
        end
        set(axr,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
        if rr==2, xlabel(axr, sdc{cc,2}, 'FontSize',6,'FontWeight','bold'); end
        if cc==1, ylabel(axr, dvc{rr,2}, 'FontSize',6,'FontWeight','bold'); end
    end
end
sgtitle(fig_rs, sprintf('CP-RES residual state-dep  %s %s e%d  (top=stim resp, bottom=pre-stim control)', ...
    mn, td, en), 'FontSize',6,'FontWeight','bold');
paperExport(fig_rs, fullfile(paper_root,'images','figure2','cp_res_state.png'));
fprintf('[CP-RES] Exported cp_res_state.png\n');
end   % do_plot (CP-RES figure)

% ---- Build inspector payload (returned in R.Sin; caller opens the figure) ----
Sin = [];
if make_inspector
    Sin = struct();
    Sin.stateX = {mot_all, pv_all, dp_all};
    Sin.stateL = {'Motion (z)', 'Pre-stim var (z)', 'Pre-stim \delta (z)'};
    Sin.devS = devS_all;  Sin.amp = amp_all;  Sin.tW = t_w;
    Sin.actW = actW_all;  Sin.prdW = prdW_all;  Sin.resW = resW_all;  Sin.motW = motW_all;
end

% ---- Package data outputs (R) -----------------------------------------------
R = struct();
R.mn = mn; R.td = td; R.en = en; R.selExp = selExp; R.Fs = Fs;
R.paper_root = paper_root; R.cv_mean = cv_mean; R.nValid = nValid_cp; R.nPred = nPred_cp;
R.t_imp = t_imp; R.iDip = iDip; R.ia_imp = ia_imp;
R.uAmp = uAmp_cp; R.nzMask = nzMask_cp;
R.act_imp = act_imp; R.prd_imp = prd_imp; R.prr_imp = prr_imp; R.res_imp = res_imp;
R.beta_cp = beta_cp;
R.predictor = predictor; R.Hp = Hp;   % 'hemi' (R.Hp = field->kernel map) or 'ols'
R.resE = resE_all; R.devS = devS_all; R.devP = devP_all;
R.mot = mot_all; R.pv = pv_all; R.dp = dp_all; R.amp = amp_all;
R.okM = okM; R.okV = okV; R.okD = okD; R.motThr = motThr;
R.decontam = decontam; R.use_motion = use_motion;
R.Sin = Sin;

% ---- Package state stats (S) ------------------------------------------------
S = struct();
S.label = {'Motion','PreVar','PreDelta'};
sttS = {mot_all, okM; pv_all, okV; dp_all, okD};
S.r_stim=nan(1,3); S.p_stim=nan(1,3); S.r_pre=nan(1,3); S.p_pre=nan(1,3);
S.r_partial=nan(1,3); S.p_partial=nan(1,3); S.r_resE=nan(1,3); S.n=nan(1,3);
for qq = 1:3
    xs = sttS{qq,1}; mm = sttS{qq,2};
    [S.r_stim(qq),    S.p_stim(qq)]    = corr(devS_all(mm), xs(mm), 'type','Spearman','rows','complete');
    [S.r_pre(qq),     S.p_pre(qq)]     = corr(devP_all(mm), xs(mm), 'type','Spearman','rows','complete');
    [S.r_partial(qq), S.p_partial(qq)] = partialcorr(devS_all(mm), xs(mm), devP_all(mm), 'type','Spearman','rows','complete');
    S.r_resE(qq) = corr(resE_all(mm), xs(mm), 'type','Spearman','rows','complete');
    S.n(qq) = sum(mm);
end
S.mn = mn; S.td = td; S.en = en; S.selExp = selExp; S.cv_mean = cv_mean;
end
