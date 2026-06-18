% widebrain_hemi_kernel.m  --  Contra-hemisphere spatial kernel for primary pixel
%
% Goal: find which contra pixels best predict the primary (ipsi) pixel.
% This is the spatial observability kernel — later connected to controller analysis.
%
% Pipeline:
%   1. Split brain at midline → contra hemisphere mask
%   2. Contra-specific SVD timecourses via U'U eigendecomposition (V_c)
%   3. Primary pixel timecourse from full SVD: y_prim = U_flat(prim,:) * V_wb
%   4. OLS on spontaneous pre-trial frames: beta_c = V_c_tr' \ y_prim_tr
%   5. Contra kernel map: k_contra = (U_c * W_c) * beta_c   [nPix_c × 1]
%   6. R² vs number of contra SVDs (rank curve, held-out test frames)
%   7. Scalar observability outputs: R2_spont, kernel_norm, kernel_peak
%
% Run from brain_paper/ root.
% Prereqs: load_sessions.m has been run (mouse, fields).
%          wb_roi_<session>.mat must exist (run widebrain_arx.m
%          pixel-selection cell).d

clc; close all;

PS = paperStyle();
setPaperDefaults();

if exist(fullfile('paper','images'),'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'),'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper';
    warning('widebrain_hemi_kernel: cannot locate paper/ -- run from brain_paper/ root.');
end
fig4_dir = fullfile(paper_root,'images','figure4');
mkdir(fig4_dir);

%% [HEMI-session] Load session + SVD
selField = 12;

wb_sel  = selField;
d_wb    = mouse.(fields{wb_sel}).d;
data_wb = mouse.(fields{wb_sel}).data;

if ~isfield(d_wb,'svd')
    fprintf('SVD missing -- reloading %s\n', fields{wb_sel});
    d_wb = initialize_data(mouse.(fields{wb_sel}).mn, mouse.(fields{wb_sel}).en, mouse.(fields{wb_sel}).td);
end
if ~isfield(d_wb,'svd')
    for k = 1:length(fields)
        if isfield(mouse.(fields{k}),'skip') && mouse.(fields{k}).skip; continue; end
        if isfield(mouse.(fields{k}).d,'svd')
            wb_sel  = k;
            d_wb    = mouse.(fields{k}).d;
            data_wb = mouse.(fields{k}).data;
            fprintf('Using session %s for hemi kernel.\n', fields{k});
            break;
        end
    end
end

U_wb    = d_wb.svd.U;      % [nY nX nSV]
V_wb    = d_wb.svd.V;      % [nSV nFrames]
mimg_wb = d_wb.svd.mimg;   % [nY nX]
[nY_wb, nX_wb] = size(mimg_wb);
nSV_wb  = size(U_wb,3);
nFrames = size(V_wb,2);

py_prim = double(d_wb.params.pixel(1));   % primary pixel row
px_prim = double(d_wb.params.pixel(2));   % primary pixel col

brain_mask = mimg_wb > prctile(mimg_wb(:),20);
U_flat     = reshape(U_wb, nY_wb*nX_wb, nSV_wb);   % [nPix × nSV]

%% [HEMI-roi] Contra mask from wb_roi; midline from saved roi file
roi_file = sprintf('wb_roi_%s.mat', fields{wb_sel});
if ~exist(roi_file,'file')
    error('ROI file %s not found. Run the pixel-selection cell in widebrain_arx.m first.', roi_file);
end

tmp    = load(roi_file);
ml     = tmp.midline;

if isfield(tmp,'valid_mask')
    valid_mask = tmp.valid_mask;
else
    [xg, yg] = meshgrid(1:nY_wb, 1:nX_wb);
    in_poly   = inpolygon(xg(:), yg(:), tmp.poly_row, tmp.poly_col);
    valid_mask = reshape(in_poly, nX_wb, nY_wb)' & brain_mask;
end

idx_c = find(valid_mask(:));   % contra pixel linear indices
U_c   = double(U_flat(idx_c, :));   % [nPix_c × nSV_wb]

fprintf('[HEMI-roi] Contra pixels: %d\n', numel(idx_c));

%% [HEMI-SVD] Contra-specific SVD via redoSVD (batch covariance, spirals method)
% redoSVD reconstructs pixel traces for the contra subspace, downsamples by
% averaging nt0 adjacent frames, builds a covariance matrix, and SVDs it.
% This is the approach from Ye et al. 2023 (spirals_mirror pipeline).

nSV_r = min(50, nSV_wb);

fprintf('[HEMI-SVD] Running redoSVD on contra pixels...\n');
[U_c_new, V_c_full] = redoSVD(U_c, double(V_wb));   % U_c_new [nPix_c × nSVD], V_c_full [nSVD × nFrames]
V_c = double(V_c_full(1:nSV_r, :));                  % [nSV_r × nFrames]
U_c_new = double(U_c_new(:, 1:nSV_r));               % [nPix_c × nSV_r]

fprintf('[HEMI-SVD] Contra SVD done  (nSV_r=%d)\n', nSV_r);

%% [HEMI-prim] Target signal: dFk (spatial kernel average — the actual controller input)
% data_wb.dFk is the weighted spatial average over the primary ROI, already computed.
% This is what the controller regulates, so observability w.r.t. dFk is directly
% relevant to control performance.  py_prim/px_prim still used to mark the map.
y_prim = data_wb.dFk(:)';   % [1 × nFrames]

%% [HEMI-frames] Frame-index train/test split (spirals method)
% Treat the full continuous recording — no behavioural segmentation.
% First 80% of frames = train; remaining 20% = test.

nTrain   = round(0.8 * nFrames);
train_fr = 1:nTrain;
test_fr  = nTrain+1:nFrames;

fprintf('[HEMI-frames] Train: %d  Test: %d  (of %d total)\n', nTrain, numel(test_fr), nFrames);

%% [HEMI-OLS] OLS regression: contra SVDs → primary pixel
% Regressors are z-scored along time (spirals convention).
% Fit zscore params on train, apply same normalisation to test.

V_c_tr_raw = V_c(:, train_fr)';        % [nTrain × nSV_r]
mu_tr      = mean(V_c_tr_raw, 1);
sd_tr      = std(V_c_tr_raw, 0, 1) + eps;
V_c_tr     = (V_c_tr_raw - mu_tr) ./ sd_tr;   % zscore (train params)

y_tr = y_prim(train_fr)' - mean(y_prim(train_fr));   % [nTrain × 1]

beta_c = V_c_tr \ y_tr;             % [nSV_r × 1]

% Contra kernel projected back to pixel space
k_contra_pix = U_c_new * beta_c;    % [nPix_c × 1]

k_prim_flat = zeros(nY_wb*nX_wb, 1);
k_prim_flat(idx_c) = k_contra_pix;
k_prim_map   = reshape(k_prim_flat, nY_wb, nX_wb);
k_prim_map_c = k_prim_map; k_prim_map_c(~valid_mask) = nan;

%% [HEMI-obs] R2 on held-out test frames

V_c_te = (V_c(:, test_fr)' - mu_tr) ./ sd_tr;   % apply train zscore params
y_te   = y_prim(test_fr)' - mean(y_prim(test_fr));

y_pred   = V_c_te * beta_c;
ss_res   = sum((y_te - y_pred).^2);
ss_tot   = sum(y_te.^2);
R2_spont = 1 - ss_res / ss_tot;

fprintf('[HEMI-obs] R2_spont=%.3f\n', R2_spont);

%% [HEMI-rank] R² vs number of contra SVDs (rank curve)
% Re-fit OLS at each rank using the z-scored regressors.

explained_vs_rank = nan(nSV_r, 1);
for k = 1:nSV_r
    b_k    = V_c_tr(:,1:k) \ y_tr;
    pred_k = V_c_te(:,1:k) * b_k;
    explained_vs_rank(k) = 1 - sum((y_te - pred_k).^2) / ss_tot;
end

fprintf('[HEMI-rank] R2 at rank 1/5/10/%d: %.3f / %.3f / %.3f / %.3f\n', ...
    nSV_r, explained_vs_rank(1), explained_vs_rank(min(5,end)), ...
    explained_vs_rank(min(10,end)), explained_vs_rank(end));

%% [HEMI-save]
obs_out.R2_spont          = R2_spont;
obs_out.beta_c            = beta_c;
obs_out.k_prim_map        = k_prim_map;
obs_out.explained_vs_rank = explained_vs_rank;
obs_out.session           = fields{wb_sel};
save(fullfile('data', sprintf('hemi_obs_%s.mat', fields{wb_sel})), '-struct', 'obs_out');
fprintf('[HEMI-save] Saved hemi_obs_%s.mat\n', fields{wb_sel});

%% [HEMI-fig1] OLS contra kernel map
n_h2     = 64;
cmap_div = [linspace(0.2,1,n_h2)', linspace(0.2,1,n_h2)', ones(n_h2,1); ...
            ones(n_h2,1), linspace(1,0.2,n_h2)', linspace(1,0.2,n_h2)'];

mimg_rng = [prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)];
fig_k1   = paperFig(10, 8);
pos_k1   = [0.06 0.07 0.74 0.87];

ax_bg1 = axes(fig_k1, 'Position', pos_k1);
imagesc(ax_bg1, mimg_wb'); colormap(ax_bg1, gray);
clim(ax_bg1, mimg_rng); axis(ax_bg1, 'image', 'off');

ax_ov1 = axes(fig_k1, 'Position', ax_bg1.Position);
ax_ov1.Color = 'none';
ax_ov1.XLim = ax_bg1.XLim; ax_ov1.YLim = ax_bg1.YLim;
ax_ov1.YDir = 'reverse';
ax_ov1.XLimMode = 'manual'; ax_ov1.YLimMode = 'manual';
set(ax_ov1, 'XTick',[], 'YTick',[], 'Box','off');
hold(ax_ov1, 'on');

imagesc(ax_ov1, k_prim_map_c', 'AlphaData', double(~isnan(k_prim_map_c')));
colormap(ax_ov1, cmap_div);
klim = max(abs(k_prim_map_c(:)), [], 'omitnan') + eps;
clim(ax_ov1, [-klim klim]);

plot(ax_ov1, py_prim, px_prim, 'k+', 'MarkerSize',10, 'LineWidth',1.5);

cb_k1 = colorbar(ax_ov1, 'Position', [0.82 0.15 0.04 0.70]);
ylabel(cb_k1, 'OLS weight', 'FontSize',PS.fs, 'FontWeight',PS.fw);
title(ax_ov1, sprintf('Contra kernel  R^2=%.2f', R2_spont), ...
    'FontSize',PS.fs, 'FontWeight',PS.fw);

paperExport(fig_k1, fullfile(fig4_dir,'hemi_kernel_primary.png'));
fprintf('[HEMI-fig1] Saved hemi_kernel_primary.png\n');

%% [HEMI-fig2] R² vs contra SVD rank
fig_ve = paperFig(8, 5);
lmV = 0.15; rmV = 0.05; bmV = 0.18; tmV = 0.12;
ax_ve = axes(fig_ve, 'Position', [lmV, bmV, 1-lmV-rmV, 1-bmV-tmV]);
hold(ax_ve, 'on');
plot(ax_ve, 1:nSV_r, explained_vs_rank*100, 'k-o', ...
    'LineWidth',PS.lw_mean, 'MarkerSize',3, 'MarkerFaceColor','k');
yline(ax_ve, R2_spont*100, '--', 'Color',[0.6 0.6 0.6], 'LineWidth',0.8, ...
    'Label',sprintf('full model R^2=%.2f', R2_spont), ...
    'LabelHorizontalAlignment','left', 'FontSize',PS.fs);
yline(ax_ve, 0, 'k:', 'LineWidth',0.5, 'HandleVisibility','off');
hold(ax_ve, 'off');
xlabel(ax_ve, 'Contra SVD rank', 'FontSize',PS.fs, 'FontWeight',PS.fw);
ylabel(ax_ve, 'R^2 test (%)',    'FontSize',PS.fs, 'FontWeight',PS.fw);
title(ax_ve,  'Contra \rightarrow dFk: rank curve', 'FontSize',PS.fs, 'FontWeight',PS.fw);
xlim(ax_ve, [1 nSV_r]);

paperExport(fig_ve, fullfile(fig4_dir,'hemi_rank_curve.png'));
fprintf('[HEMI-fig2] Saved hemi_rank_curve.png\n');
