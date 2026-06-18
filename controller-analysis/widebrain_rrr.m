% widebrain_rrr.m  --  Spirals-style RRR widebrain prediction
% Companion to widebrain_arx.m: replaces the ARX pixel-grid predictor with a
% Reduced Rank Regression over brain-wide SVD components, then projects weights
% back to pixel space to produce a spatial kernel map (cf. spirals Fig 3h).
%
% Run from brain_paper/ root directory.
% Prereqs: load_sessions.m has been run (mouse, fields, tp, Mean_var_wc/nc, dur).
%          widebrain_arx.m ROI file (wb_roi_<session>.mat) should exist so the
%          interactive midline/polygon step can be skipped.
%
% Key outputs (parallel to widebrain_arx.m):
%   beta_rrr   [1 + nSV*pV x 1]  regression weights in SVD space
%   k_map      [nY x nX]          contra-hemisphere spatial kernel
%   pred_nc_r  [nNc x outlen]     RRR pink prediction, OL trials
%   pred_wc_r  [nWc x outlen]     RRR pink prediction, CL trials
%
% Three-layer model mirrors widebrain_arx.m:
%   Pink   = RRR spontaneous model applied to trial X
%   Orange = Pink + mean OL residual
%   Red    = Pink + per-trial TF laser response

PS  = paperStyle();
setPaperDefaults();

colOL    = PS.col_ol;
colCL    = PS.col_cl;

if exist(fullfile('paper','images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..','paper','images'), 'dir')
    paper_root = fullfile('..','paper');
else
    paper_root = 'paper';
    warning('widebrain_rrr: cannot locate paper/ directory -- run from brain_paper/ root.');
end
fig4_dir = fullfile(paper_root,'images','figure4');
mkdir(fig4_dir);
colPrd_r = [0.55 0.20 0.70];   % purple -- distinguishes RRR pink from ARX pink

%% Session + SVD
selField = 12;

wb_sel   = selField;
Fs_wb    = 35;
dur_wb   = 3;

d_wb     = mouse.(fields{wb_sel}).d;
data_wb  = mouse.(fields{wb_sel}).data;

if ~isfield(d_wb, 'svd')
    fprintf('SVD missing -- reloading %s\n', fields{wb_sel});
    d_wb = initialize_data(mouse.(fields{wb_sel}).mn, mouse.(fields{wb_sel}).en, mouse.(fields{wb_sel}).td);
end
if ~isfield(d_wb, 'svd')
    for k = 1:length(fields)
        if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
        if isfield(mouse.(fields{k}).d, 'svd')
            wb_sel  = k;
            d_wb    = mouse.(fields{k}).d;
            data_wb = mouse.(fields{k}).data;
            fprintf('Using session %s for widebrain RRR.\n', fields{k});
            break;
        end
    end
end

U_wb    = d_wb.svd.U;      % [nY nX nSV]
V_wb    = d_wb.svd.V;      % [nSV nFrames]
mimg_wb = d_wb.svd.mimg;   % [nY nX]
[nY_wb, nX_wb] = size(mimg_wb);
nSV_wb  = size(U_wb, 3);
nFrames = size(V_wb, 2);

py_prim = double(d_wb.params.pixel(1));
px_prim = double(d_wb.params.pixel(2));

horizon_wb = double(d_wb.params.horizon);
w_r        = horizon_wb - 1;
idx_r      = 1:nFrames;

brain_mask = mimg_wb > prctile(mimg_wb(:), 20);

% Reconstruct primary pixel dFk (rolling-baseline dF/F, same as widebrain_arx)
mI_prim   = mean(mimg_wb(py_prim-1:py_prim+1, px_prim-1:px_prim+1), 'all');
ikern_p   = U_wb(py_prim-1:py_prim+1, px_prim-1:px_prim+1, :);
ist_p     = reshape(mean(ikern_p, [1 2]), [1, nSV_wb]);
F_p       = ist_p * V_wb + mI_prim;
Fk_p      = [ones(1, w_r)*mI_prim, F_p];
cs_p      = [0, cumsum(Fk_p)];
Fm_p      = (cs_p(idx_r + w_r + 1) - cs_p(idx_r)) / (w_r + 1);
y_full    = ((F_p - Fm_p) ./ Fm_p * 100)';   % [nFrames x 1]

t_wb      = d_wb.timeBlue;
mot_wb    = d_wb.motion(:);
nF        = min(nFrames, numel(mot_wb));
y_full    = y_full(1:nF);

%% ROI: load from widebrain_arx output or redefine interactively
% Reuse the contra-hemisphere polygon already defined in widebrain_arx.m.
roi_file = sprintf('wb_roi_%s.mat', fields{wb_sel});

if ~exist(roi_file, 'file')
    % --- interactive definition (same code as widebrain_arx.m) ---
    k_pred = 2;
    fig_roi = figure('Color','k','Name','Define midline + contra ROI for RRR');
    imagesc(mimg_wb'); colormap(fig_roi, gray);
    clim([prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
    axis image off; hold on;

    title('STEP 1 -- Click 2 MIDLINE points, Enter','Color','w','FontSize',9,'FontWeight','bold');
    [xd1, yd1] = ginput(2);
    x_ml = yd1; y_ml = xd1;
    if abs(y_ml(2)-y_ml(1)) > abs(x_ml(2)-x_ml(1))
        midline.a = (x_ml(2)-x_ml(1))/(y_ml(2)-y_ml(1));
        midline.b = x_ml(1) - midline.a*y_ml(1);
        midline.type = 'x_of_y';
    else
        midline.a = (y_ml(2)-y_ml(1))/(x_ml(2)-x_ml(1));
        midline.b = y_ml(1) - midline.a*x_ml(1);
        midline.type = 'y_of_x';
    end
    midline.img_size = [nY_wb, nX_wb];
    if strcmp(midline.type,'x_of_y')
        t_ml = linspace(1,nY_wb,300);
        plot(t_ml, midline.a*t_ml + midline.b,'w--','LineWidth',1.2);
    else
        t_ml = linspace(1,nX_wb,300);
        plot(midline.a*t_ml + midline.b, t_ml,'w--','LineWidth',1.2);
    end

    title('STEP 2 -- Click CONTRA hemisphere boundary, Enter','Color','c','FontSize',9,'FontWeight','bold');
    [xd2, yd2] = ginput;
    xd2 = [xd2; xd2(1)]; yd2 = [yd2; yd2(1)];
    plot(xd2, yd2,'c-','LineWidth',1.2); drawnow; pause(0.3); close(fig_roi);
    poly_col = yd2; poly_row = xd2;

    [xg, yg] = meshgrid(1:nY_wb, 1:nX_wb);
    in_poly   = inpolygon(xg(:), yg(:), xd2, yd2);
    in_poly   = reshape(in_poly, nX_wb, nY_wb)';
    valid_mask = in_poly & brain_mask;
    valid_mask(1:k_pred+1,:) = false; valid_mask(end-k_pred:end,:) = false;
    valid_mask(:,1:k_pred+1) = false; valid_mask(:,end-k_pred:end) = false;

    denom = 1 + midline.a^2;
    ml = midline;
    if strcmp(ml.type,'x_of_y')
        D = px_prim - ml.a*py_prim - ml.b;
        px_c = round(px_prim - 2*D/denom); py_c = round(py_prim + 2*ml.a*D/denom);
    else
        D = ml.a*px_prim - py_prim + ml.b;
        px_c = round(px_prim - 2*ml.a*D/denom); py_c = round(py_prim + 2*D/denom);
    end
    contra_idx = 1; pred_px = px_c; pred_py = py_c;  % placeholder
    save(roi_file,'midline','pred_px','pred_py','contra_idx','poly_col','poly_row','valid_mask');
    fprintf('Saved ROI: %s\n', roi_file);
else
    tmp        = load(roi_file);
    midline    = tmp.midline;
    poly_col   = tmp.poly_col; poly_row = tmp.poly_row;
    if isfield(tmp,'valid_mask')
        valid_mask = tmp.valid_mask;
    else
        % Reconstruct valid_mask from polygon stored in roi_file
        [xg, yg] = meshgrid(1:nY_wb, 1:nX_wb);
        in_poly  = inpolygon(xg(:), yg(:), tmp.poly_row, tmp.poly_col);
        valid_mask = reshape(in_poly, nX_wb, nY_wb)' & brain_mask;
    end
    fprintf('Loaded ROI from %s\n', roi_file);
end

%% [RRR-SVD] Contra-hemisphere basis in SVD space
% Build a contra-region weighting matrix M = U_c' * U_c  [nSV x nSV].
% Its eigenvectors are the directions in V_wb space that explain most
% variance within the contra hemisphere -- no need to materialise the
% full data matrix.  The resulting V_rrr are linear combinations of the
% original SVD timecourses, rotated to be contra-specific.

nSV_rrr = min(50, nSV_wb);   % RRR components to use

U_flat  = reshape(U_wb, nY_wb*nX_wb, nSV_wb);         % [nPix x nSV]
idx_c   = find(valid_mask(:));                          % linear indices of contra pixels
U_c     = U_flat(idx_c, :);                            % [nPix_c x nSV]

M_contra = double(U_c' * U_c);                         % [nSV x nSV]
[W_rrr, lam_rrr] = eig(M_contra);
[~, ord] = sort(diag(lam_rrr), 'descend');
W_rrr = W_rrr(:, ord(1:nSV_rrr));                     % [nSV x nSV_rrr]

V_rrr = W_rrr' * double(V_wb);                        % [nSV_rrr x nFrames] contra timecourses

% Spatial maps for kernel reconstruction: [nY x nX x nSV_rrr]
U_rrr_flat = U_flat * W_rrr;                           % [nPix x nSV_rrr]
U_rrr_vol  = reshape(U_rrr_flat, nY_wb, nX_wb, nSV_rrr);

fprintf('[RRR-SVD] Contra pixels: %d  |  RRR components: %d\n', numel(idx_c), nSV_rrr);

%% [RRR-1a] Pink layer -- RRR fit + parameter tuning
% Adjust pV / spont_pre below, re-run, inspect held-out R².
% Once R2_test > 0.3, run RRR-1b.
% Predictor: lagged V_rrr timecourses + motion.

pY        = 0;    % AR self-lags (keep 0: pure contralateral prediction)
pV        = 8;    % SVD-space lags (~229 ms at 35 Hz)
spont_pre = 6;    % pre-trial spontaneous window for training (s)
mlag_r    = max(pY, pV);

X_rrr_full = [V_rrr(:, 1:nF)', mot_wb(1:nF)];   % [nF x (nSV_rrr+1)]
y_full_r   = y_full(1:nF);

t_wb_r       = d_wb.timeBlue;
pre_frames_r = spont_pre * Fs_wb;
all_tr_r     = [data_wb.nc(:); data_wb.wc(:)];
nAll_r       = length(all_tr_r);

spont_y_r = cell(nAll_r, 1);
spont_X_r = cell(nAll_r, 1);
valid_r   = false(nAll_r, 1);
for j = 1:nAll_r
    [~, i_on] = min(abs(t_wb_r - d_wb.stimStarts(all_tr_r(j))));
    i0 = i_on - pre_frames_r; i1 = i_on - 1;
    if i0 < 1 || i1 > nF; continue; end
    spont_y_r{j} = y_full_r(i0:i1);
    spont_X_r{j} = X_rrr_full(i0:i1, :);
    valid_r(j)   = true;
end
valid_idx_r = find(valid_r);
nValid_r    = length(valid_idx_r);

nTrain_r  = round(0.8 * nValid_r);
train_idx_r = valid_idx_r(1:nTrain_r);
test_idx_r  = valid_idx_r(nTrain_r+1:end);

y_sp_train_r = cell2mat(spont_y_r(train_idx_r));
X_sp_train_r = cell2mat(spont_X_r(train_idx_r));

[Phi_tr_r, y_tr_r] = buildLagMatrix(y_sp_train_r, X_sp_train_r, pY, pV);
beta_rrr   = Phi_tr_r \ y_tr_r;
yh_tr_r    = Phi_tr_r * beta_rrr;
R2_train_r = 1 - sum((y_tr_r - yh_tr_r).^2) / sum((y_tr_r - mean(y_tr_r)).^2);

y_sp_test_r = cell2mat(spont_y_r(test_idx_r));
X_sp_test_r = cell2mat(spont_X_r(test_idx_r));
[Phi_te_r, y_te_r] = buildLagMatrix(y_sp_test_r, X_sp_test_r, pY, pV);
yh_te_r    = Phi_te_r * beta_rrr;
R2_test_r  = 1 - sum((y_te_r - yh_te_r).^2) / sum((y_te_r - mean(y_te_r)).^2);

fprintf('[RRR-1a] nSV=%d  pV=%d  |  R2_train=%.3f  R2_test=%.3f  (nTrain=%d  nTest=%d)\n', ...
    nSV_rrr, pV, R2_train_r, R2_test_r, nTrain_r, nValid_r - nTrain_r);
if R2_test_r <= 0
    error('[RRR-1a] R2_test=%.3f <= 0 -- check ROI / SVD alignment.', R2_test_r);
elseif R2_test_r < 0.3
    warning('[RRR-1a] R2_test=%.3f < 0.3 -- consider increasing nSV_rrr or pV.', R2_test_r);
end

% Held-out tuning figure
N_show_r = min(6, length(test_idx_r));
nCols_r  = 3; nRows_r = ceil(N_show_r / nCols_r);
fig_tune_r = figure('Color','w','Units','centimeters','Position',[0 0 18 nRows_r*4]);
for s = 1:N_show_r
    [Phi_s, y_s] = buildLagMatrix(spont_y_r{test_idx_r(s)}, spont_X_r{test_idx_r(s)}, pY, pV);
    yh_s = Phi_s * beta_rrr;
    R2_s = max(0, 1 - sum((y_s - yh_s).^2) / sum((y_s - mean(y_s)).^2));
    t_s  = (0:length(y_s)-1) / Fs_wb;
    ax_t = subplot(nRows_r, nCols_r, s); hold(ax_t,'on');
    plot(ax_t, t_s, y_s,  'k',         'LineWidth',0.8,'DisplayName','Actual');
    plot(ax_t, t_s, yh_s, 'Color',colPrd_r,'LineWidth',0.8,'DisplayName','RRR');
    hold(ax_t,'off');
    title(ax_t, sprintf('Test %d  R^2=%.2f', s, R2_s),'FontSize',6,'FontWeight','bold');
    set(ax_t,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    if mod(s-1,nCols_r)==0; ylabel(ax_t,'dF/F (%)','FontSize',6,'FontWeight','bold'); end
    if s > (nRows_r-1)*nCols_r; xlabel(ax_t,'Time (s)','FontSize',6,'FontWeight','bold'); end
end
sgtitle(sprintf('RRR spont -- nSV=%d  pV=%d  |  R2_{train}=%.2f  R2_{test}=%.2f', ...
    nSV_rrr, pV, R2_train_r, R2_test_r),'FontSize',7,'FontWeight','bold');

%% [RRR-1a-tune] Order selection -- BIC sweep + 5-fold CV (training set, SVD rank)
% Sweeps nSV over a candidate range to find how many contra SVD components are needed.
% pV is held at its current value.  Test set is NOT touched.

nSV_cands = [2 5 10 15 20 30 40 50];
nSV_cands = nSV_cands(nSV_cands <= nSV_rrr);
nC_sv     = numel(nSV_cands);
bic_sv    = nan(nC_sv, 1);
cv5_sv    = nan(nC_sv, 1);

y_tr_all_r = cell2mat(spont_y_r(train_idx_r));
X_tr_all_r = cell2mat(spont_X_r(train_idx_r));

for ip = 1:nC_sv
    nSV_ip = nSV_cands(ip);
    [Phi_c, y_c] = buildLagMatrix(y_tr_all_r, X_tr_all_r(:, 1:nSV_ip+1), pY, pV);
    b_c   = Phi_c \ y_c;
    rss_c = sum((y_c - Phi_c*b_c).^2);
    n_c   = numel(y_c); k_c = size(Phi_c, 2);
    bic_sv(ip) = n_c*log(rss_c/n_c) + k_c*log(n_c);
end

kFold_sv   = 5;
nTr_sv     = numel(train_idx_r);
fedg_sv    = round(linspace(0, nTr_sv, kFold_sv+1));
for ip = 1:nC_sv
    nSV_ip = nSV_cands(ip);
    r2f_sv = nan(kFold_sv, 1);
    for kk = 1:kFold_sv
        val_l   = (fedg_sv(kk)+1):fedg_sv(kk+1);
        tr_l    = setdiff(1:nTr_sv, val_l);
        if isempty(tr_l)||isempty(val_l); continue; end
        [Phi_ktr, y_ktr] = buildLagMatrix(cell2mat(spont_y_r(train_idx_r(tr_l))), ...
            cell2mat(spont_X_r(train_idx_r(tr_l))), pY, pV);
        [Phi_kva, y_kva] = buildLagMatrix(cell2mat(spont_y_r(train_idx_r(val_l))), ...
            cell2mat(spont_X_r(train_idx_r(val_l))), pY, pV);
        % restrict to nSV_ip components + motion
        cols_ip = [1, 2:pV*nSV_ip+1, size(Phi_ktr,2)];  % intercept + SVD lags + motion lags
        cols_ip = cols_ip(cols_ip <= size(Phi_ktr,2));
        b_k   = Phi_ktr(:,cols_ip) \ y_ktr;
        yhat_k = Phi_kva(:,cols_ip) * b_k;
        r2f_sv(kk) = 1 - sum((y_kva-yhat_k).^2)/sum((y_kva-mean(y_kva)).^2);
    end
    cv5_sv(ip) = mean(r2f_sv, 'omitnan');
end

[~, iBIC_sv] = min(bic_sv);  [~, iCV_sv] = max(cv5_sv);
fprintf('[RRR-1a-tune] BIC nSV=%d  |  CV nSV=%d  |  current nSV=%d\n', ...
    nSV_cands(iBIC_sv), nSV_cands(iCV_sv), nSV_rrr);

fig_tune_sv = figure('Color','w','Units','centimeters','Position',[2 2 12 5]);
lmT=0.11; rmT=0.04; bmT=0.20; tmT=0.10; gxT=0.10;
pwT=(1-lmT-rmT-gxT)/2; phT=1-bmT-tmT;

ax_bic_sv = axes(fig_tune_sv,'Position',[lmT, bmT, pwT, phT]);
plot(ax_bic_sv, nSV_cands, bic_sv-min(bic_sv),'k-o','LineWidth',1.2,'MarkerSize',3,'MarkerFaceColor','k');
xline(ax_bic_sv, nSV_cands(iBIC_sv),'--r','LineWidth',1.0,'Label',sprintf('BIC=%d',nSV_cands(iBIC_sv)),'LabelHorizontalAlignment','right','FontSize',5,'FontWeight','bold');
xlabel(ax_bic_sv,'nSV (rank)','FontSize',6,'FontWeight','bold');
ylabel(ax_bic_sv,'BIC \minus min(BIC)','FontSize',6,'FontWeight','bold');
title(ax_bic_sv,'Training BIC','FontSize',6,'FontWeight','bold');

ax_cv_sv = axes(fig_tune_sv,'Position',[lmT+pwT+gxT, bmT, pwT, phT]);
plot(ax_cv_sv, nSV_cands, cv5_sv,'k-o','LineWidth',1.2,'MarkerSize',3,'MarkerFaceColor','k');
xline(ax_cv_sv, nSV_cands(iCV_sv),'--','Color',[0.2 0.5 0.8],'LineWidth',1.0,'Label',sprintf('CV=%d',nSV_cands(iCV_sv)),'LabelHorizontalAlignment','right','FontSize',5,'FontWeight','bold');
xlabel(ax_cv_sv,'nSV (rank)','FontSize',6,'FontWeight','bold');
ylabel(ax_cv_sv,'5-fold CV  R^2','FontSize',6,'FontWeight','bold');
title(ax_cv_sv,'5-fold CV (train)','FontSize',6,'FontWeight','bold');

%% [RRR-kernel] Spatial kernel map
% Project RRR weights (lag-1 SVD coefficients) back through U_rrr to pixel space.
% beta layout: [intercept | nSV_rrr lags of V_rrr (lag1..lagpV) | pV motion lags]
% Lag-1 SVD weights occupy positions 2 : nSV_rrr+1 in beta_rrr.

beta_sv1 = beta_rrr(2 : nSV_rrr+1);           % lag-1 RRR weights [nSV_rrr x 1]
k_map_flat = U_rrr_flat * beta_sv1;            % [nPix_full x 1]
k_map      = reshape(k_map_flat, nY_wb, nX_wb);% [nY x nX]
k_map_c    = k_map; k_map_c(~valid_mask) = nan; % mask to contra region

fig_kern = figure('Color','w','Units','centimeters','Position',[2 2 10 8]);
pos_kn   = [0.07 0.08 0.72 0.84];

ax_kb = axes(fig_kern,'Position',pos_kn);
imagesc(ax_kb, mimg_wb');
colormap(ax_kb, gray);
clim(ax_kb, [prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
axis(ax_kb,'image','off');

ax_ko = axes(fig_kern,'Position',ax_kb.Position);
ax_ko.Color    = 'none';
ax_ko.XLim     = ax_kb.XLim; ax_ko.YLim = ax_kb.YLim;
ax_ko.YDir     = 'reverse';
ax_ko.XLimMode = 'manual'; ax_ko.YLimMode = 'manual';
set(ax_ko,'XTick',[],'YTick',[],'Box','off');
hold(ax_ko,'on');
imagesc(ax_ko, k_map_c', 'AlphaData', double(~isnan(k_map_c')));
n_half = 64;
cmap_rdbu = [linspace(0.647,1,n_half)', linspace(0,1,n_half)', linspace(0.149,1,n_half)'; ...
             linspace(1,0.196,n_half)', linspace(1,0.188,n_half)', linspace(1,0.380,n_half)'];
colormap(ax_ko, cmap_rdbu);
clim(ax_ko, [-1 1]*max(abs(beta_sv1.*std(V_rrr(1,:)))) * max(abs(U_rrr_flat(:))));
plot(ax_ko, py_prim, px_prim, 'k+','MarkerSize',8,'LineWidth',1.5);
cb_k = colorbar(ax_ko,'Position',[0.81 0.15 0.04 0.70]);
ylabel(cb_k,'RRR kernel weight','FontSize',5,'FontWeight','bold');
title(ax_ko,'Contra \rightarrow primary spatial kernel (lag 1)','FontSize',6,'FontWeight','bold');
paperExport(fig_kern,fullfile(fig4_dir,'rrr_kernel_map.png'));
fprintf('[RRR-kernel] Saved rrr_kernel_map.png\n');

%% [RRR-varexp] Variance explained vs RRR rank
% Fit using top-k contra SVD components and evaluate R² on held-out spont.
% Mirrors spirals Fig 3c (variance explained vs number of dimensions).

nSV_sweep  = 1:nSV_rrr;
R2_rank_tr = nan(nSV_rrr, 1);
R2_rank_te = nan(nSV_rrr, 1);

for nk = nSV_sweep
    X_k_tr = cell2mat(cellfun(@(x) x(:, 1:nk+1), spont_X_r(train_idx_r), 'UniformOutput', false));
    X_k_te = cell2mat(cellfun(@(x) x(:, 1:nk+1), spont_X_r(test_idx_r),  'UniformOutput', false));
    y_k_tr = cell2mat(spont_y_r(train_idx_r));
    y_k_te = cell2mat(spont_y_r(test_idx_r));
    [Phi_k_tr, yv_tr] = buildLagMatrix(y_k_tr, X_k_tr, pY, pV);
    [Phi_k_te, yv_te] = buildLagMatrix(y_k_te, X_k_te, pY, pV);
    b_k = Phi_k_tr \ yv_tr;
    R2_rank_tr(nk) = 1 - sum((yv_tr - Phi_k_tr*b_k).^2)/sum((yv_tr-mean(yv_tr)).^2);
    R2_rank_te(nk) = 1 - sum((yv_te - Phi_k_te*b_k).^2)/sum((yv_te-mean(yv_te)).^2);
end

fig_ve = paperFig(8, 5);
lmV=0.14; rmV=0.04; bmV=0.18; tmV=0.10;
ax_ve = axes(fig_ve,'Position',[lmV, bmV, 1-lmV-rmV, 1-bmV-tmV]);
hold(ax_ve,'on');
plot(ax_ve, nSV_sweep, R2_rank_tr,'Color',[0.7 0.7 0.7],'LineWidth',1.2,'DisplayName','Train');
plot(ax_ve, nSV_sweep, R2_rank_te,'Color',colPrd_r,      'LineWidth',1.5,'DisplayName','Test');
xline(ax_ve, nSV_rrr,'k:','LineWidth',0.8,'HandleVisibility','off');
hold(ax_ve,'off');
xlabel(ax_ve,'Number of SVD components','FontSize',6,'FontWeight','bold');
ylabel(ax_ve,'Variance explained (R^2)','FontSize',6,'FontWeight','bold');
title(ax_ve,'RRR rank -- spontaneous prediction','FontSize',6,'FontWeight','bold');
lg_ve = legend(ax_ve,'Location','southeast','Box','off','FontSize',5);
try; lg_ve.ItemTokenSize=[6 6]; catch; end
paperExport(fig_ve,fullfile(fig4_dir,'rrr_varexp_rank.png'));
fprintf('[RRR-varexp] Saved rrr_varexp_rank.png\n');

%% [RRR-1b] Apply to OL/CL trials
outlen_r   = dur_wb * Fs_wb;
t_trial_r  = (0:outlen_r-1) / Fs_wb;
nNc_r = length(data_wb.nc);
nWc_r = length(data_wb.wc);

pred_nc_r   = nan(nNc_r, outlen_r);
actual_nc_r = nan(nNc_r, outlen_r);
for j = 1:nNc_r
    [~, i_on] = min(abs(t_wb_r - d_wb.stimStarts(data_wb.nc(j))));
    i0 = i_on - mlag_r; i1 = i_on + outlen_r - 1;
    if i0 < 1 || i1 > nF; continue; end
    [Phi_t, y_t]      = buildLagMatrix(y_full_r(i0:i1), X_rrr_full(i0:i1,:), pY, pV);
    pred_nc_r(j,:)   = Phi_t * beta_rrr;
    actual_nc_r(j,:) = y_t;
end

pred_wc_r   = nan(nWc_r, outlen_r);
actual_wc_r = nan(nWc_r, outlen_r);
for j = 1:nWc_r
    [~, i_on] = min(abs(t_wb_r - d_wb.stimStarts(data_wb.wc(j))));
    i0 = i_on - mlag_r; i1 = i_on + outlen_r - 1;
    if i0 < 1 || i1 > nF; continue; end
    [Phi_t, y_t]      = buildLagMatrix(y_full_r(i0:i1), X_rrr_full(i0:i1,:), pY, pV);
    pred_wc_r(j,:)   = Phi_t * beta_rrr;
    actual_wc_r(j,:) = y_t;
end

R2_nc_r = max(0, 1-sum((actual_nc_r(:)-pred_nc_r(:)).^2,'omitnan') / ...
                    sum((actual_nc_r(:)-mean(actual_nc_r(:),'omitnan')).^2,'omitnan'));
R2_wc_r = max(0, 1-sum((actual_wc_r(:)-pred_wc_r(:)).^2,'omitnan') / ...
                    sum((actual_wc_r(:)-mean(actual_wc_r(:),'omitnan')).^2,'omitnan'));
fprintf('[RRR-1b]  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_r, R2_wc_r);

% 3-panel: OL actual vs RRR | CL actual vs RRR | residuals
fig_wb1_r = paperFig(16, 5);
lm1=0.08; rm1=0.03; bm1=0.18; tm1=0.08; gx1=0.06;
pw1=(1-lm1-rm1-2*gx1)/3; ph1=1-bm1-tm1;

ax1B_r = axes(fig_wb1_r,'Position',[lm1, bm1, pw1, ph1]); hold(ax1B_r,'on');
plot(ax1B_r, t_trial_r, mean(actual_nc_r,1,'omitnan'),'Color',colOL,   'LineWidth',PS.lw_mean,'DisplayName','OL actual');
plot(ax1B_r, t_trial_r, mean(pred_nc_r,  1,'omitnan'),'Color',colPrd_r,'LineWidth',PS.lw_fit, 'LineStyle','--','DisplayName','RRR pink');
addStimPatch(ax1B_r, 0, dur_wb); hold(ax1B_r,'off');
legend(ax1B_r,'Box','off','FontSize',6,'Location','best');
title(ax1B_r, sprintf('OL  R^2=%.2f', R2_nc_r),'FontSize',6,'FontWeight','bold');

ax1C_r = axes(fig_wb1_r,'Position',[lm1+pw1+gx1, bm1, pw1, ph1]); hold(ax1C_r,'on');
plot(ax1C_r, t_trial_r, mean(actual_wc_r,1,'omitnan'),'Color',colCL,   'LineWidth',PS.lw_mean,'DisplayName','CL actual');
plot(ax1C_r, t_trial_r, mean(pred_wc_r,  1,'omitnan'),'Color',colPrd_r,'LineWidth',PS.lw_fit, 'LineStyle','--','DisplayName','RRR pink');
addStimPatch(ax1C_r, 0, dur_wb); hold(ax1C_r,'off');
legend(ax1C_r,'Box','off','FontSize',6,'Location','best');
title(ax1C_r, sprintf('CL  R^2=%.2f', R2_wc_r),'FontSize',6,'FontWeight','bold');

ax1D_r = axes(fig_wb1_r,'Position',[lm1+2*(pw1+gx1), bm1, pw1, ph1]); hold(ax1D_r,'on');
plot(ax1D_r, t_trial_r, mean(actual_nc_r-pred_nc_r,1,'omitnan'),'Color',colOL,'LineWidth',PS.lw_mean,'DisplayName','OL residual');
plot(ax1D_r, t_trial_r, mean(actual_wc_r-pred_wc_r,1,'omitnan'),'Color',colCL,'LineWidth',PS.lw_mean,'DisplayName','CL residual');
yline(ax1D_r, 0,'k--','LineWidth',0.6,'HandleVisibility','off');
addStimPatch(ax1D_r, 0, dur_wb); hold(ax1D_r,'off');
legend(ax1D_r,'Box','off','FontSize',6,'Location','best');
title(ax1D_r,'Residual: actual \minus RRR pink','FontSize',6,'FontWeight','bold');

for axi_r = [ax1B_r ax1C_r ax1D_r]
    set(axi_r,'FontSize',6,'FontWeight','bold','Box','off','TickDir','out');
    ylabel(axi_r,'dF/F (%)','FontSize',6,'FontWeight','bold');
    xlabel(axi_r,'Time (s)','FontSize',6,'FontWeight','bold');
end
paperExport(fig_wb1_r,fullfile(fig4_dir,'rrr_pink_3panel.png'));
fprintf('[RRR-1b] Saved rrr_pink_3panel.png\n');

%% [RRR-2] Orange layer -- mean OL residual added to pink
ol_resid_mean_r = mean(actual_nc_r - pred_nc_r, 1, 'omitnan');
pred_nc_orange_r = pred_nc_r + ol_resid_mean_r;
pred_wc_orange_r = pred_wc_r + ol_resid_mean_r;

R2_nc_org_r = max(0, 1-sum((actual_nc_r(:)-pred_nc_orange_r(:)).^2,'omitnan') / ...
                        sum((actual_nc_r(:)-mean(actual_nc_r(:),'omitnan')).^2,'omitnan'));
R2_wc_org_r = max(0, 1-sum((actual_wc_r(:)-pred_wc_orange_r(:)).^2,'omitnan') / ...
                        sum((actual_wc_r(:)-mean(actual_wc_r(:),'omitnan')).^2,'omitnan'));
fprintf('[RRR-2] Orange:  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_org_r, R2_wc_org_r);

%% [RRR-3] Red layer -- per-trial TF laser response
iOn_r       = 36;
ncDfk_r     = data_wb.ncDfk;
ncInp_r     = data_wb.ncInp;
wcInp_r     = data_wb.wcInp;

bc_nc_r     = mean(ncDfk_r(:, 1:iOn_r-1), 2);
ncDfk_bc_r  = ncDfk_r - bc_nc_r;
y_mean_r    = mean(ncDfk_bc_r(:, iOn_r : iOn_r+outlen_r-1), 1)';

ds_r       = round(2000 / Fs_wb);
u_mean_r   = downsample(mean(ncInp_r, 1)', ds_r);
u_mean_r   = u_mean_r(1:outlen_r);

nPre_r     = 5;
Ts_r       = 1 / Fs_wb;
data_id_r  = iddata([zeros(nPre_r,1); y_mean_r], [zeros(nPre_r,1); u_mean_r], Ts_r);
tfOpt_r    = tfestOptions('EnforceStability',false,'Display','off');
best_r     = tfest(data_id_r, 2, 1, tfOpt_r);

p_r  = pole(best_r);
tau_r = sort(abs(1./real(p_r(real(p_r)<0))));
fprintf('[RRR-3] TF time constants:'); fprintf('  %.3f s', tau_r); fprintf('\n');

laser_nc_r = nan(nNc_r, outlen_r);
for j = 1:nNc_r
    u_j = downsample(ncInp_r(j,:)', ds_r); u_j = u_j(1:outlen_r);
    try; laser_nc_r(j,:) = lsim(best_r, u_j, t_trial_r)'; catch; end
end
laser_wc_r = nan(nWc_r, outlen_r);
for j = 1:nWc_r
    u_j = downsample(wcInp_r(j,:)', ds_r); u_j = u_j(1:outlen_r);
    try; laser_wc_r(j,:) = lsim(best_r, u_j, t_trial_r)'; catch; end
end

pred_nc_red_r = pred_nc_r + laser_nc_r;
pred_wc_red_r = pred_wc_r + laser_wc_r;

R2_nc_red_r = max(0, 1-sum((actual_nc_r(:)-pred_nc_red_r(:)).^2,'omitnan') / ...
                        sum((actual_nc_r(:)-mean(actual_nc_r(:),'omitnan')).^2,'omitnan'));
R2_wc_red_r = max(0, 1-sum((actual_wc_r(:)-pred_wc_red_r(:)).^2,'omitnan') / ...
                        sum((actual_wc_r(:)-mean(actual_wc_r(:),'omitnan')).^2,'omitnan'));
fprintf('[RRR-3] Red:  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_red_r, R2_wc_red_r);

%% [RRR-4] Three-layer overlay -- paper figure
colPink_r  = colPrd_r;
colOrange_r = [0.90 0.55 0.10];
colRed_r    = [0.75 0.10 0.10];

fig_wb4_r = paperFig(12, 4);
lm4=0.09; rm4=0.04; bm4=0.20; tm4=0.08; gx4=0.08;
pw4=(1-lm4-rm4-gx4)/2; ph4=1-bm4-tm4;

ax4L_r = axes(fig_wb4_r,'Position',[lm4, bm4, pw4, ph4]); hold(ax4L_r,'on');
mn_nc_r = mean(actual_nc_r,1,'omitnan');
se_nc_r = std(actual_nc_r,0,1,'omitnan') / sqrt(sum(~all(isnan(actual_nc_r),2)));
fill(ax4L_r,[t_trial_r,fliplr(t_trial_r)],[mn_nc_r+se_nc_r,fliplr(mn_nc_r-se_nc_r)], ...
    colOL,'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
plot(ax4L_r,t_trial_r,mn_nc_r,                                'Color',colOL,      'LineWidth',PS.lw_mean,'DisplayName','OL actual');
plot(ax4L_r,t_trial_r,mean(pred_nc_r,      1,'omitnan'),       'Color',colPink_r,  'LineWidth',PS.lw_fit,'LineStyle','--','DisplayName','Pink (RRR)');
plot(ax4L_r,t_trial_r,mean(pred_nc_orange_r,1,'omitnan'),      'Color',colOrange_r,'LineWidth',PS.lw_fit,'LineStyle','--','DisplayName','Orange');
plot(ax4L_r,t_trial_r,mean(pred_nc_red_r,  1,'omitnan'),       'Color',colRed_r,   'LineWidth',PS.lw_fit,'LineStyle','--','DisplayName','Red');
addStimPatch(ax4L_r, 0, dur_wb); hold(ax4L_r,'off');
lgd4L_r = legend(ax4L_r,'Location','southwest'); paperLegend(lgd4L_r);
title(ax4L_r,'Open-Loop','FontSize',6,'FontWeight','bold');
xlabel(ax4L_r,'Time (s)','FontWeight','bold'); ylabel(ax4L_r,'dF/F (%)','FontWeight','bold');

ax4R_r = axes(fig_wb4_r,'Position',[lm4+pw4+gx4, bm4, pw4, ph4]); hold(ax4R_r,'on');
mn_wc_r = mean(actual_wc_r,1,'omitnan');
se_wc_r = std(actual_wc_r,0,1,'omitnan') / sqrt(sum(~all(isnan(actual_wc_r),2)));
fill(ax4R_r,[t_trial_r,fliplr(t_trial_r)],[mn_wc_r+se_wc_r,fliplr(mn_wc_r-se_wc_r)], ...
    colCL,'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
plot(ax4R_r,t_trial_r,mn_wc_r,                                'Color',colCL,     'LineWidth',PS.lw_mean,'DisplayName','CL actual');
plot(ax4R_r,t_trial_r,mean(pred_wc_r,      1,'omitnan'),       'Color',colPink_r, 'LineWidth',PS.lw_fit,'LineStyle','--','DisplayName','Pink (RRR)');
plot(ax4R_r,t_trial_r,mean(pred_wc_red_r,  1,'omitnan'),       'Color',colRed_r,  'LineWidth',PS.lw_fit,'LineStyle','--','DisplayName','Red');
addStimPatch(ax4R_r, 0, dur_wb); hold(ax4R_r,'off');
lgd4R_r = legend(ax4R_r,'Location','southwest'); paperLegend(lgd4R_r);
title(ax4R_r,'Closed-Loop','FontSize',6,'FontWeight','bold');
xlabel(ax4R_r,'Time (s)','FontWeight','bold'); ylabel(ax4R_r,'dF/F (%)','FontWeight','bold');

paperExport(fig_wb4_r,fullfile(fig4_dir,'rrr_three_layers.pdf'));
fprintf('[RRR-4] Saved rrr_three_layers.pdf\n');

%% [RRR-5] Post-hoc optimal laser -- MPC motivation
ref_r    = d_wb.ref;
h_imp_r  = impulse(best_r, t_trial_r);
H_toep_r = toeplitz(h_imp_r, [h_imp_r(1); zeros(outlen_r-1,1)]) / Fs_wb;

mse_cl_act_r = nan(nWc_r,1); mse_cl_opt_r = nan(nWc_r,1);
for j = 1:nWc_r
    y_pk = pred_wc_r(j,:)'; y_ac = actual_wc_r(j,:)';
    if any(isnan(y_pk))||any(isnan(y_ac)); continue; end
    u_opt_r = H_toep_r \ (ref_r*ones(outlen_r,1) - y_pk);
    y_opt_r = y_pk + H_toep_r*u_opt_r;
    mse_cl_act_r(j) = mean((y_ac  - ref_r).^2);
    mse_cl_opt_r(j) = mean((y_opt_r - ref_r).^2);
end
mse_ol_act_r = nan(nNc_r,1);
for j = 1:nNc_r
    y_ac = actual_nc_r(j,:)'; if any(isnan(y_ac)); continue; end
    mse_ol_act_r(j) = mean((y_ac - ref_r).^2);
end

gap_r = median(mse_cl_act_r,'omitnan') / median(mse_cl_opt_r,'omitnan');
fprintf('[RRR-5] MSE -- OL: %.3f  CL: %.3f  Optimal: %.3f\n', ...
    median(mse_ol_act_r,'omitnan'), median(mse_cl_act_r,'omitnan'), median(mse_cl_opt_r,'omitnan'));
fprintf('[RRR-5] CL/Optimal gap: %.2fx\n', gap_r);

fig_wb5_r = paperFig(6,4);
ax_wb5_r  = axes(fig_wb5_r,'Units','normalized','Position',[0.20 0.18 0.74 0.72]);
hold(ax_wb5_r,'on');
grp_data_r = {mse_ol_act_r(~isnan(mse_ol_act_r)), ...
               mse_cl_act_r(~isnan(mse_cl_act_r)), ...
               mse_cl_opt_r(~isnan(mse_cl_opt_r))};
gm_r = cellfun(@mean, grp_data_r);
gs_r = cellfun(@(x) std(x)/sqrt(numel(x)), grp_data_r);
cb_r = [colOL; colCL; 0.5 0.5 0.5];
for g = 1:3
    bar(ax_wb5_r, g, gm_r(g), 0.6,'FaceColor',cb_r(g,:),'EdgeColor','none');
    errorbar(ax_wb5_r, g, gm_r(g), gs_r(g),'k','LineWidth',0.8,'CapSize',4,'LineStyle','none');
end
hold(ax_wb5_r,'off');
set(ax_wb5_r,'XTick',1:3,'XTickLabel',{'OL','CL','Optimal'}, ...
    'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(ax_wb5_r,'MSE (\DeltaF/F)^2','FontSize',PS.fs,'FontWeight',PS.fw);
title(ax_wb5_r, sprintf('CL/Optimal gap: %.2fx', gap_r),'FontSize',PS.fs,'FontWeight',PS.fw);
paperExport(fig_wb5_r,fullfile(fig4_dir,'rrr_mpc_gap.png'));
fprintf('[RRR-5] Saved rrr_mpc_gap.png\n');
