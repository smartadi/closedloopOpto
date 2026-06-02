% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).

PS = paperStyle();
setPaperDefaults();

% Resolve paper/ root -- works whether run from brain_paper/ or controller-analysis/
if exist(fullfile('paper', 'images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..', 'paper', 'images'), 'dir')
    paper_root = fullfile('..', 'paper');
else
    paper_root = 'paper';
    warning('widebrain_arx: cannot locate paper/ directory -- paths may be incorrect.');
end

%% Widebrain -- pixel selection
% Define contralateral ROI grid. Re-run freely to adjust grid_rows/grid_cols.
% When happy with the pixel map, run the SVD extraction cell below.
% Residual (actual -' predicted) captures stimulus + controller effect.
close all;

selField = 12;

% -- Pixel selection parameters
wb_sel       = selField;  % session to analyse
Fs_wb        = 35;
dur_wb       = 3;         % trial duration (s)
k_pred       = 5;         % SVD kernel half-size for predictor pixels (1 -> 3x3, 2 -> 5x5, ...)
grid_rows    = 10;         % visual rows in contra ROI grid  (c direction)
grid_cols    = 10;         % visual cols in contra ROI grid  (r direction)
% nPred derived automatically: 1 contra-primary + grid nodes inside ROI
redefine_roi = true;      % set true to redo midline + ROI interactively

% -- Session + SVD
d_wb       = mouse.(fields{wb_sel}).d;
data_wb    = mouse.(fields{wb_sel}).data;

% SVD may be absent from old caches -- reload initialize_data if needed
if ~isfield(d_wb, 'svd')
    fprintf('SVD missing from cache for %s -- reloading...\n', fields{wb_sel});
    d_wb = initialize_data(mouse.(fields{wb_sel}).mn, mouse.(fields{wb_sel}).en, mouse.(fields{wb_sel}).td);
end

% If SVD still absent (files not on server for this session), scan loaded sessions
if ~isfield(d_wb, 'svd')
    fprintf('SVD unavailable for %s -- scanning other sessions...\n', fields{wb_sel});
    found = false;
    for k = 1:length(fields)
        if isfield(mouse.(fields{k}), 'skip') && mouse.(fields{k}).skip; continue; end
        if isfield(mouse.(fields{k}).d, 'svd')
            wb_sel  = k;
            d_wb    = mouse.(fields{k}).d;
            data_wb = mouse.(fields{k}).data;
            fprintf('Using session %s (%s %s e%d) for widebrain prediction.\n', ...
                fields{k}, mouse.(fields{k}).mn, mouse.(fields{k}).td, mouse.(fields{k}).en);
            found = true;
            break;
        end
    end
    if ~found
        error('No session with SVD data found. Re-run the loading block to populate d.svd.');
    end
end
% Session-specific ROI file -- persists across runs without re-selection
roi_file = sprintf('wb_roi_%s.mat', fields{wb_sel});

U_wb       = d_wb.svd.U;      % [nY nX nSV]
V_wb       = d_wb.svd.V;      % [nSV nFrames]
mimg_wb    = d_wb.svd.mimg;   % [nY nX]
[nY_wb, nX_wb] = size(mimg_wb);
nSV_wb     = size(U_wb, 3);
nFrames    = size(V_wb, 2);
horizon_wb = double(d_wb.params.horizon);
brain_mask = mimg_wb > prctile(mimg_wb(:), 20);
w_r        = horizon_wb - 1;
idx_r      = 1:nFrames;

% pixel stores [row, col]
py_prim = double(d_wb.params.pixel(1));   % row
px_prim = double(d_wb.params.pixel(2));   % col

% -- Combined interactive: midline + contralateral ROI
% One figure: click midline (2 pts, Enter) ->' polygon outline (n pts, Enter).
% Results saved to midline.mat + contra_pixels.mat.  Set redefine_roi=false to skip.
if redefine_roi && exist(roi_file, 'file')
    delete(roi_file);
    fprintf('Deleted existing ROI file: %s\n', roi_file);
end

if ~exist(roi_file, 'file')
    fig_roi = figure('Color','k', 'Name','Define midline + contralateral ROI');
    imagesc(mimg_wb'); colormap(fig_roi, gray);
    clim([prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
    axis image off; hold on;

    % -- Step 1: midline (exactly 2 clicks)
    title('STEP 1 -- Click 2 points along the MIDLINE, then press Enter', ...
        'Color','w', 'FontSize',10, 'FontWeight','bold');
    [xd1, yd1] = ginput(2);
    % transposed display: xd=original row, yd=original col -- swap to (col, row)
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
    % midline saved as part of roi_file at the end of this block (no separate midline.mat)

    % Overlay midline on same figure
    if strcmp(midline.type, 'x_of_y')
        t = linspace(1, nY_wb, 300);
        plot(t, midline.a*t + midline.b, 'w--', 'LineWidth', 1.5);
    else
        t = linspace(1, nX_wb, 300);
        plot(midline.a*t + midline.b, t, 'w--', 'LineWidth', 1.5);
    end
    fprintf('Midline saved (type=%s  a=%.4f  b=%.4f)\n', midline.type, midline.a, midline.b);

    % -- Step 2: polygon outline of contralateral hemisphere
    title('STEP 2 -- Click boundary of CONTRALATERAL hemisphere, press Enter to finish', ...
        'Color','c', 'FontSize',10, 'FontWeight','bold');
    [xd2, yd2] = ginput;   % unlimited clicks, Enter to finish
    % Close polygon for display and inpolygon
    xd2 = [xd2; xd2(1)];  yd2 = [yd2; yd2(1)];
    plot(xd2, yd2, 'c-', 'LineWidth', 1.5);
    drawnow; pause(0.4);
    close(fig_roi);

    % Convert polygon back to original (col, row) space
    poly_col = yd2;   % original cols
    poly_row = xd2;   % original rows

    % -- Build mask via inpolygon (no toolbox needed)
    % Grid in display space (transposed): xg = original rows, yg = original cols
    [xg, yg] = meshgrid(1:nY_wb, 1:nX_wb);
    in_poly   = inpolygon(xg(:), yg(:), xd2, yd2);
    in_poly   = reshape(in_poly, nX_wb, nY_wb)';   % back to [nY x nX] original space

    % Intersect with brain mask; enforce boundary margin
    valid_mask = in_poly & brain_mask;
    valid_mask(1:k_pred+1, :)   = false;
    valid_mask(end-k_pred:end,:) = false;
    valid_mask(:, 1:k_pred+1)   = false;
    valid_mask(:, end-k_pred:end)= false;

    [rows_v, cols_v] = find(valid_mask);
    if isempty(rows_v)
        error('No valid pixels found inside the drawn polygon. Try a larger region.');
    end

    % Compute contralateral primary pixel (reflection across midline)
    ml    = midline;
    denom = 1 + ml.a^2;
    if strcmp(ml.type, 'x_of_y')
        D    = px_prim - ml.a*py_prim - ml.b;
        px_c = round(px_prim - 2*D / denom);
        py_c = round(py_prim + 2*ml.a*D / denom);
    else
        D    = ml.a*px_prim - py_prim + ml.b;
        px_c = round(px_prim - 2*ml.a*D / denom);
        py_c = round(py_prim + 2*D / denom);
    end
    px_c = max(k_pred+1, min(nX_wb-k_pred, double(px_c)));
    py_c = max(k_pred+1, min(nY_wb-k_pred, double(py_c)));

    % Regular grid: grid_cols x grid_rows cell-centre nodes over the ROI bounding box.
    % Nodes whose rounded pixel coordinate falls OUTSIDE the eroded interior mask
    % are simply discarded -- no snapping.  nPred is set by how many survive.
    %
    % Display is transposed (imagesc(mimg')), so:
    %   visual rows = c direction (nX dim, cols of valid_mask) -> grid_rows controls c_lin
    %   visual cols = r direction (nY dim, rows of valid_mask) -> grid_cols controls r_lin
    r_min = min(rows_v); r_max = max(rows_v);
    c_min = min(cols_v); c_max = max(cols_v);

    % Cell-centre linspace (grid divided into equal cells, node at each centre)
    dr    = (r_max - r_min) / grid_cols;
    dc    = (c_max - c_min) / grid_rows;
    r_lin = linspace(r_min + dr/2, r_max - dr/2, grid_cols);
    c_lin = linspace(c_min + dc/2, c_max - dc/2, grid_rows);
    [cg, rg] = meshgrid(c_lin, r_lin);
    rg = round(rg(:));
    cg = round(cg(:));
    % Clamp to image bounds
    rg = max(1, min(nY_wb, rg));
    cg = max(1, min(nX_wb, cg));

    % Erode valid mask: a pixel is interior only if all neighbours within
    % margin_px are also valid (conv2, no toolbox required).
    margin_px = 4;
    kernel_e  = ones(2*margin_px+1);
    interior  = conv2(double(valid_mask), kernel_e, 'same') >= numel(kernel_e);
    if ~any(interior(:))
        warning('Interior mask empty after erosion -- falling back to full valid mask');
        interior = valid_mask;
    end

    % Keep only grid nodes that land on an interior pixel; drop the rest
    in_int = interior(sub2ind(size(interior), rg, cg));
    rg_k   = rg(in_int);
    cg_k   = cg(in_int);
    [~, ui]      = unique([rg_k, cg_k], 'rows', 'stable');
    snapped_rows = rg_k(ui);
    snapped_cols = cg_k(ui);

    pred_py = snapped_rows;
    pred_px = snapped_cols;

    % Mark the grid node nearest to the computed contra-primary reflection
    dists2     = (pred_py - py_c).^2 + (pred_px - px_c).^2;
    [~, contra_idx] = min(dists2);

    save(roi_file, 'midline', 'pred_px', 'pred_py', 'contra_idx', 'poly_col', 'poly_row', 'grid_rows', 'grid_cols');
    fprintf('Saved ROI: %d/%d grid nodes inside ROI (node %d is contra-primary)  [%s]\n', ...
        numel(snapped_rows), grid_rows*grid_cols, contra_idx, roi_file);
else
    tmp      = load(roi_file);
    midline  = tmp.midline;
    ml       = midline;
    pred_px    = tmp.pred_px;  pred_py  = tmp.pred_py;
    contra_idx = tmp.contra_idx;
    poly_col   = tmp.poly_col; poly_row = tmp.poly_row;
    fprintf('Loaded ROI from %s  (%d predictor pixels, contra node %d)\n', roi_file, length(pred_px), contra_idx);

    % Recompute contra-primary for display
    denom = 1 + ml.a^2;
    if strcmp(ml.type, 'x_of_y')
        D    = px_prim - ml.a*py_prim - ml.b;
        px_c = round(px_prim - 2*D / denom);
        py_c = round(py_prim + 2*ml.a*D / denom);
    else
        D    = ml.a*px_prim - py_prim + ml.b;
        px_c = round(px_prim - 2*ml.a*D / denom);
        py_c = round(py_prim + 2*D / denom);
    end
end
nPred = length(pred_px);
% fprintf('Primary (%d,%d) ->' contra (%d,%d)  |  %d predictor pixels\n', ...
%     py_prim, px_prim, py_c, px_c, nPred);

% -- Pixel map: verify selection on transposed brain image
fig_pmap = figure('Color','k', 'Name','Widebrain predictor pixels');
fig_pmap.Units = 'centimeters'; fig_pmap.Position = [0 0 10 8];
ax_pm = axes(fig_pmap, 'Position',[0 0 1 0.88]);
imagesc(ax_pm, mimg_wb');
colormap(ax_pm, gray);
clim(ax_pm, [prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
axis(ax_pm, 'image', 'off');
hold(ax_pm, 'on');

% Midline (transposed display: x=row, y=col)
if strcmp(ml.type, 'x_of_y')
    t = linspace(1, nY_wb, 300);
    plot(ax_pm, t, ml.a*t + ml.b, 'w--', 'LineWidth', 1.2);
else
    t = linspace(1, nX_wb, 300);
    plot(ax_pm, ml.a*t + ml.b, t, 'w--', 'LineWidth', 1.2);
end

% Polygon outline (poly_row/poly_col are in original space; display needs swap)
plot(ax_pm, poly_row, poly_col, 'c-', 'LineWidth', 1.2);

% Pixels (transposed display: scatter(row, col))
non_contra = true(nPred, 1); non_contra(contra_idx) = false;
scatter(ax_pm, pred_py(non_contra), pred_px(non_contra), 50, ...
    'o','filled','MarkerFaceColor',[0.2 0.6 1],'MarkerEdgeColor','w','LineWidth',0.5);
scatter(ax_pm, pred_py(contra_idx), pred_px(contra_idx), 100, ...
    's','filled','MarkerFaceColor',[0 0.9 1],  'MarkerEdgeColor','w','LineWidth',1.5);
scatter(ax_pm, py_prim, px_prim, 100, ...
    's','filled','MarkerFaceColor',[1 0.3 0.3],'MarkerEdgeColor','w','LineWidth',1.5);

legend(ax_pm, {'Midline','ROI outline','Grid pixels','Contra primary','Primary'}, ...
    'TextColor','w','Color','none','EdgeColor','none','FontSize',6,'FontWeight','bold', ...
    'Location','south','Orientation','horizontal');
hold(ax_pm, 'off');
fprintf('Pixel map ready. Adjust grid_rows/grid_cols or redefine_roi and re-run this cell as needed.\n');

%% Widebrain -- SVD extraction
% Run once after finalising the pixel selection above.
% Set recompute_svd=true to force recomputation (e.g. after changing the grid).
recompute_svd = false;

% -- Extract dFk via SVD projection (cached)
mn_wb   = mouse.(fields{wb_sel}).mn;
td_wb   = mouse.(fields{wb_sel}).td;
en_wb   = mouse.(fields{wb_sel}).en;
path_wb = fullfile('data', sprintf('%swb%s%s%d.mat', mn_wb, td_wb(6:7), td_wb(9:10), en_wb));

% y_full -- always from mouse struct (no cache needed; same signal as controller analysis)
y_full = data_wb.dFk(:);
if numel(y_full) ~= nFrames
    warning('[WB-SVD] data_wb.dFk length (%d) ~= nFrames (%d) -- truncating to shorter.', ...
        numel(y_full), nFrames);
    nFrames = min(numel(y_full), nFrames);
    y_full  = y_full(1:nFrames);
end

% X_full -- SVD predictor pixels (expensive; cached by k_pred + grid)
if exist(path_wb,'file') && ~recompute_svd
    tmp = load(path_wb);
    cache_ok = isfield(tmp,'k_pred')  && tmp.k_pred == k_pred && ...
               isfield(tmp,'pred_px') && isequal(tmp.pred_px(:), pred_px(:)) && ...
               isfield(tmp,'pred_py') && isequal(tmp.pred_py(:), pred_py(:));
    if cache_ok
        X_full = tmp.X_full;
        fprintf('Loaded predictor cache: %s  (k_pred=%d, nPred=%d)\n', path_wb, k_pred, nPred);
    else
        fprintf('Predictor cache stale (k_pred or grid changed) -- recomputing.\n');
        recompute_svd = true;
    end
end

if ~exist(path_wb,'file') || recompute_svd
    fprintf('Computing SVD predictor dFk (%d pixels, k_pred=%d) ...\n', nPred, k_pred);
    X_full = zeros(nFrames, nPred);
    for j = 1:nPred
        cx = pred_px(j); cy = pred_py(j);
        mI_j    = mean(mimg_wb(cy-k_pred:cy+k_pred, cx-k_pred:cx+k_pred), 'all');
        ikern_j = U_wb(cy-k_pred:cy+k_pred, cx-k_pred:cx+k_pred, :);
        ist_j   = reshape(mean(ikern_j, [1 2]), [1, nSV_wb]);
        F_j     = ist_j * V_wb + mI_j;
        Fk_j    = [ones(1,w_r)*mI_j, F_j];
        cs_j    = [0, cumsum(Fk_j)];
        Fm_j    = (cs_j(idx_r+w_r+1) - cs_j(idx_r)) / (w_r+1);
        X_full(:,j) = ((F_j - Fm_j) ./ Fm_j * 100)';
    end
    [~] = mkdir(fileparts(path_wb));
    save(path_wb, 'X_full', 'pred_px', 'pred_py', 'k_pred');
    fprintf('Saved predictor cache: %s  (k_pred=%d, nPred=%d)\n', path_wb, k_pred, nPred);
end

%% [WB-1a] Pink layer -- ARX fit + parameter tuning
% Adjust pX / spont_pre below, re-run this cell, inspect the held-out figure.
% Once R2_test > 0.3, run WB-1b to apply to trials.
% Prereqs: pixel-selection + SVD extraction cells above must have run.

% -- Learning parameters
pY        = 0;    % AR self-lags on y -- keep 0 (pure contralateral prediction)
pX        = 10;   % lags per predictor pixel (~286 ms at 35 Hz)
spont_pre = 6;    % pre-trial spontaneous window used for training (s)
mlag_wb   = max(pY, pX);

% ---- Build motion-augmented predictor matrix ----
mot_wb   = d_wb.motion(:);
nF       = min(size(X_full,1), numel(mot_wb));
X_full_m = [X_full(1:nF,:), mot_wb(1:nF)];
y_full_m  = y_full(1:nF);

t_wb_m       = d_wb.timeBlue;
pre_frames_m = spont_pre * Fs_wb;
all_tr_m     = [data_wb.nc(:); data_wb.wc(:)];
nAll_m       = length(all_tr_m);

% ---- Collect per-trial spontaneous windows individually (needed for split) ----
spont_y = cell(nAll_m, 1);
spont_X = cell(nAll_m, 1);
valid_m  = false(nAll_m, 1);
for j = 1:nAll_m
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(all_tr_m(j))));
    i0 = i_on - pre_frames_m;  i1 = i_on - 1;
    if i0 < 1 || i1 > nF; continue; end
    spont_y{j} = y_full_m(i0:i1);
    spont_X{j} = X_full_m(i0:i1,:);
    valid_m(j) = true;
end
valid_idx = find(valid_m);
nValid_m  = length(valid_idx);

% ---- 80 / 20 train / test split by trial index (deterministic) ----
nTrain_m  = round(0.8 * nValid_m);
train_idx = valid_idx(1 : nTrain_m);
test_idx  = valid_idx(nTrain_m+1 : end);

y_sp_train = cell2mat(spont_y(train_idx));
X_sp_train = cell2mat(spont_X(train_idx));

% ---- Fit ARX on training set ----
[Phi_train, y_tr] = buildLagMatrix(y_sp_train, X_sp_train, pY, pX);
beta_m  = Phi_train \ y_tr;
yh_tr   = Phi_train * beta_m;
R2_train = 1 - sum((y_tr - yh_tr).^2) / sum((y_tr - mean(y_tr)).^2);

% ---- Evaluate on held-out test set ----
y_sp_test = cell2mat(spont_y(test_idx));
X_sp_test = cell2mat(spont_X(test_idx));
[Phi_test, y_te] = buildLagMatrix(y_sp_test, X_sp_test, pY, pX);
yh_te    = Phi_test * beta_m;
R2_test  = 1 - sum((y_te - yh_te).^2) / sum((y_te - mean(y_te)).^2);

fprintf('[WB-1a] nPred=%d  pX=%d  |  R2_train=%.3f  R2_test=%.3f  (nTrain=%d  nTest=%d trials)\n', ...
    nPred, pX, R2_train, R2_test, nTrain_m, nValid_m-nTrain_m);
if R2_test <= 0
    error('[WB-1a] R2_test=%.3f <= 0 -- model generalises worse than mean. Check ROI / alignment.', R2_test);
elseif R2_test < 0.3
    warning('[WB-1a] R2_test=%.3f < 0.3 -- consider increasing nPred or pX.', R2_test);
end

% ---- Tuning figure: grid of held-out spontaneous windows ----
colPrd_m = [0.2 0.2 0.8];
N_show   = min(6, length(test_idx));
nCols_t  = 3;
nRows_t  = ceil(N_show / nCols_t);

fig_tune = figure('Color','w','Units','centimeters','Position',[0 0 18 nRows_t*4]);
for s = 1:N_show
    [Phi_s, y_s_w] = buildLagMatrix(spont_y{test_idx(s)}, spont_X{test_idx(s)}, pY, pX);
    yh_s = Phi_s * beta_m;
    R2_s = max(0, 1 - sum((y_s_w - yh_s).^2) / sum((y_s_w - mean(y_s_w)).^2));
    t_s  = (0:length(y_s_w)-1) / Fs_wb;

    ax_t = subplot(nRows_t, nCols_t, s);  hold(ax_t, 'on');
    plot(ax_t, t_s, y_s_w, 'k',           'LineWidth',0.8, 'DisplayName','Actual');
    plot(ax_t, t_s, yh_s,  'Color',colPrd_m, 'LineWidth',0.8, 'DisplayName','Predicted');
    hold(ax_t,'off');
    title(ax_t, sprintf('Test %d  R^2=%.2f', s, R2_s), 'FontSize',6,'FontWeight','bold');
    set(ax_t,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    if mod(s-1, nCols_t) == 0
        ylabel(ax_t,'dF/F (%)','FontSize',6,'FontWeight','bold');
    end
    if s > (nRows_t-1)*nCols_t
        xlabel(ax_t,'Time (s)','FontSize',6,'FontWeight','bold');
    end
end
sgtitle(sprintf('Spont prediction - nPred=%d  pX=%d  |  R2_{train}=%.2f  R2_{test}=%.2f', ...
    nPred, pX, R2_train, R2_test), 'FontSize',7,'FontWeight','bold');


%% [WB-1a-tune] pX order selection -- BIC sweep + 5-fold CV (training set only)
% Sweeps pX over a candidate range; selects order by BIC (no test data used).
% 5-fold CV on training trials provides a second, non-parametric estimate.
% Prereqs: WB-1a must have run (spont_y, spont_X, train_idx, pY, nPred, pX).
% After inspecting the plot: update pX in WB-1a and re-run WB-1a + WB-1a-tune.
% Test set is NOT touched here.

pX_cands = [2 4 6 8 10 12 15 20 25 30];
nPX_c    = numel(pX_cands);
aic_c    = nan(nPX_c, 1);
bic_c    = nan(nPX_c, 1);
cv5_c    = nan(nPX_c, 1);   % 5-fold CV R^2 on training trials

% ---- Concatenate all training-trial spontaneous windows ----
y_tr_all = cell2mat(spont_y(train_idx));
X_tr_all = cell2mat(spont_X(train_idx));

% ---- AIC / BIC on full training pool ----
for ip = 1:nPX_c
    [Phi_c, y_c] = buildLagMatrix(y_tr_all, X_tr_all, pY, pX_cands(ip));
    b_c   = Phi_c \ y_c;
    rss_c = sum((y_c - Phi_c*b_c).^2);
    n_c   = numel(y_c);
    k_c   = size(Phi_c, 2);          % pX*nPred + bias  (pY=0)
    aic_c(ip) = n_c * log(rss_c/n_c) + 2*k_c;
    bic_c(ip) = n_c * log(rss_c/n_c) + k_c * log(n_c);
end

% ---- 5-fold CV on training trials ----
kFold      = 5;
nTr_cv     = numel(train_idx);
fold_edges = round(linspace(0, nTr_cv, kFold+1));

for ip = 1:nPX_c
    r2_folds = nan(kFold, 1);
    for kk = 1:kFold
        val_local   = (fold_edges(kk)+1) : fold_edges(kk+1);
        train_local = setdiff(1:nTr_cv, val_local);
        if isempty(train_local) || isempty(val_local); continue; end

        [Phi_ktr, y_ktr] = buildLagMatrix( ...
            cell2mat(spont_y(train_idx(train_local))), ...
            cell2mat(spont_X(train_idx(train_local))), pY, pX_cands(ip));
        [Phi_kva, y_kva] = buildLagMatrix( ...
            cell2mat(spont_y(train_idx(val_local))), ...
            cell2mat(spont_X(train_idx(val_local))), pY, pX_cands(ip));

        b_k    = Phi_ktr \ y_ktr;
        ss_res = sum((y_kva - Phi_kva*b_k).^2);
        ss_tot = sum((y_kva - mean(y_kva)).^2);
        r2_folds(kk) = 1 - ss_res/ss_tot;
    end
    cv5_c(ip) = mean(r2_folds, 'omitnan');
end

% ---- Report recommendations ----
[~, iBIC] = min(bic_c);
[~, iCV]  = max(cv5_c);
pX_bic    = pX_cands(iBIC);
pX_cv5    = pX_cands(iCV);

fprintf('[WB-1a-tune] BIC-selected pX = %d  |  5-fold CV-selected pX = %d  |  current pX = %d\n', ...
    pX_bic, pX_cv5, pX);
if pX_bic ~= pX
    fprintf('             --> Update pX to %d in WB-1a and re-run.\n', pX_bic);
else
    fprintf('             --> Current pX matches BIC optimum -- no change needed.\n');
end

% ---- Figure: BIC curve (left) + CV R^2 curve (right) ----
fig_pxtune = figure('Color','w','Units','centimeters','Position',[2 2 12 5]);
lmT=0.11; rmT=0.04; bmT=0.20; tmT=0.10; gxT=0.10;
pwT = (1-lmT-rmT-gxT)/2;
phT = 1-bmT-tmT;

% Left: BIC - min(BIC)
ax_bic = axes(fig_pxtune,'Position',[lmT, bmT, pwT, phT]);
hold(ax_bic,'on');
plot(ax_bic, pX_cands, bic_c - min(bic_c), 'k-o', ...
    'LineWidth',1.2, 'MarkerSize',3, 'MarkerFaceColor','k');
xline(ax_bic, pX_bic, '--r', 'LineWidth',1.0, ...
    'Label',sprintf('BIC=%d',pX_bic), 'LabelHorizontalAlignment','right', ...
    'FontSize',5, 'FontWeight','bold');
if pX ~= pX_bic
    xline(ax_bic, pX, ':k', 'LineWidth',0.8, ...
        'Label',sprintf('cur=%d',pX), 'LabelHorizontalAlignment','left', ...
        'FontSize',5, 'FontWeight','bold');
end
hold(ax_bic,'off');
xlabel(ax_bic, 'pX (lags)', 'FontSize',6, 'FontWeight','bold');
ylabel(ax_bic, 'BIC \minus min(BIC)', 'FontSize',6, 'FontWeight','bold');
title(ax_bic, 'Training-set BIC', 'FontSize',6, 'FontWeight','bold');
set(ax_bic, 'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');

% Right: 5-fold CV R^2
ax_cv = axes(fig_pxtune,'Position',[lmT+pwT+gxT, bmT, pwT, phT]);
hold(ax_cv,'on');
plot(ax_cv, pX_cands, cv5_c, 'k-o', ...
    'LineWidth',1.2, 'MarkerSize',3, 'MarkerFaceColor','k');
xline(ax_cv, pX_cv5, '--', 'Color',[0.2 0.5 0.8], 'LineWidth',1.0, ...
    'Label',sprintf('CV=%d',pX_cv5), 'LabelHorizontalAlignment','right', ...
    'FontSize',5, 'FontWeight','bold');
if pX ~= pX_cv5
    xline(ax_cv, pX, ':k', 'LineWidth',0.8, ...
        'Label',sprintf('cur=%d',pX), 'LabelHorizontalAlignment','left', ...
        'FontSize',5, 'FontWeight','bold');
end
hold(ax_cv,'off');
xlabel(ax_cv, 'pX (lags)', 'FontSize',6, 'FontWeight','bold');
ylabel(ax_cv, '5-fold CV  R^2', 'FontSize',6, 'FontWeight','bold');
title(ax_cv, '5-fold CV (training trials)', 'FontSize',6, 'FontWeight','bold');
set(ax_cv, 'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');


%% [WB-1b] Pink layer -- apply to OL/CL trials, export figure
% Prereqs: WB-1a must have run (beta_m, X_full_m, y_full_m, t_wb_m, nF, colPrd_m).
% Run this only once parameters in WB-1a are satisfactory.

outlen_m  = dur_wb * Fs_wb;
t_trial_m = (0:outlen_m-1) / Fs_wb;
nNc_wb    = length(data_wb.nc);
nWc_wb    = length(data_wb.wc);

% Apply to OL trials
pred_nc_m   = nan(nNc_wb, outlen_m);
actual_nc_m = nan(nNc_wb, outlen_m);
for j = 1:nNc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.nc(j))));
    i0 = i_on - mlag_wb;  i1 = i_on + outlen_m - 1;
    if i0 < 1 || i1 > nF; continue; end
    [Phi_t, y_t]     = buildLagMatrix(y_full_m(i0:i1), X_full_m(i0:i1,:), pY, pX);
    pred_nc_m(j,:)   = Phi_t * beta_m;
    actual_nc_m(j,:) = y_t;
end

% Apply to CL trials
pred_wc_m   = nan(nWc_wb, outlen_m);
actual_wc_m = nan(nWc_wb, outlen_m);
for j = 1:nWc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.wc(j))));
    i0 = i_on - mlag_wb;  i1 = i_on + outlen_m - 1;
    if i0 < 1 || i1 > nF; continue; end
    [Phi_t, y_t]     = buildLagMatrix(y_full_m(i0:i1), X_full_m(i0:i1,:), pY, pX);
    pred_wc_m(j,:)   = Phi_t * beta_m;
    actual_wc_m(j,:) = y_t;
end

R2_nc_m = max(0, 1 - sum((actual_nc_m(:)-pred_nc_m(:)).^2,'omitnan') / ...
                      sum((actual_nc_m(:)-mean(actual_nc_m(:),'omitnan')).^2,'omitnan'));
R2_wc_m = max(0, 1 - sum((actual_wc_m(:)-pred_wc_m(:)).^2,'omitnan') / ...
                      sum((actual_wc_m(:)-mean(actual_wc_m(:),'omitnan')).^2,'omitnan'));
fprintf('[WB-1b]  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_m, R2_wc_m);

% 3-panel figure: OL actual vs pink | CL actual vs pink | residuals
fig_wb1 = paperFig(16, 5);
lm1=0.08; rm1=0.03; bm1=0.18; tm1=0.08; gx1=0.06;
pw1=(1-lm1-rm1-2*gx1)/3;  ph1=1-bm1-tm1;

ax1B = axes(fig_wb1,'Position',[lm1,             bm1, pw1, ph1]); hold(ax1B,'on');
plot(ax1B, t_trial_m, mean(actual_nc_m,1,'omitnan'), 'Color',colOL,    'LineWidth',1.5,'DisplayName','OL actual');
plot(ax1B, t_trial_m, mean(pred_nc_m,  1,'omitnan'), 'Color',colPrd_m, 'LineWidth',1,'LineStyle','--','DisplayName','Pink');
addStimPatch(ax1B, 0, dur_wb);  hold(ax1B,'off');
legend(ax1B,'Box','off','FontSize',6,'Location','best');
title(ax1B, sprintf('OL  R^2=%.2f',R2_nc_m),'FontSize',6,'FontWeight','bold');

ax1C = axes(fig_wb1,'Position',[lm1+pw1+gx1,    bm1, pw1, ph1]); hold(ax1C,'on');
plot(ax1C, t_trial_m, mean(actual_wc_m,1,'omitnan'), 'Color',colCL,    'LineWidth',1.5,'DisplayName','CL actual');
plot(ax1C, t_trial_m, mean(pred_wc_m,  1,'omitnan'), 'Color',colPrd_m, 'LineWidth',1,'LineStyle','--','DisplayName','Pink');
addStimPatch(ax1C, 0, dur_wb);  hold(ax1C,'off');
legend(ax1C,'Box','off','FontSize',6,'Location','best');
title(ax1C, sprintf('CL  R^2=%.2f',R2_wc_m),'FontSize',6,'FontWeight','bold');

ax1D = axes(fig_wb1,'Position',[lm1+2*(pw1+gx1), bm1, pw1, ph1]); hold(ax1D,'on');
plot(ax1D, t_trial_m, mean(actual_nc_m-pred_nc_m,1,'omitnan'), 'Color',colOL,'LineWidth',1.5,'DisplayName','OL residual');
plot(ax1D, t_trial_m, mean(actual_wc_m-pred_wc_m,1,'omitnan'), 'Color',colCL,'LineWidth',1.5,'DisplayName','CL residual');
yline(ax1D, 0,'k--','HandleVisibility','off');
addStimPatch(ax1D, 0, dur_wb);  hold(ax1D,'off');
legend(ax1D,'Box','off','FontSize',6,'Location','best');
title(ax1D,'Residual: actual - pink','FontSize',6,'FontWeight','bold');

for axi = [ax1B ax1C ax1D]
    set(axi,'FontSize',6,'FontWeight','bold','Box','off','TickDir','out');
    ylabel(axi,'dF/F (%)','FontSize',6,'FontWeight','bold');
    xlabel(axi,'Time (s)','FontSize',6,'FontWeight','bold');
end
paperExport(fig_wb1, fullfile(paper_root, 'images', 'figure4', 'wb_pink_4panel.pdf'));
fprintf('[WB-1b] Saved wb_pink_4panel.pdf\n');


%% [WB-1c] Decontaminated pink -- Option A: subtract mean OL primary response from predictors
% During OL/CL trials the contralateral pixels carry a laser-driven component
% (laser -> primary pixel -> bilateral propagation -> contra pixels -> ARX input).
%
% Option A (revised): subtract the mean OL PRIMARY pixel response (averaged across
% OL trials) from every contralateral predictor pixel's trial window.  The primary
% pixel's mean OL trace is the best single-channel proxy for the laser-propagated
% component, because the contamination reaches the contralateral hemisphere via
% the primary pixel.  Subtracting per-pixel contra means (previous version) removed
% spontaneous cross-hemisphere correlations and caused flat predictions.
%
% Prereqs: WB-1b must have run (actual_nc_m/actual_wc_m, X_full_m, y_full_m,
%          beta_m, t_wb_m, nF, mlag_wb, pY, pX, outlen_m, nNc_wb, nWc_wb).

% -- Mean OL primary pixel response: already in actual_nc_m from WB-1b
y_ol_mean_A = mean(actual_nc_m, 1, 'omitnan')';   % [outlen_m x 1]

% -- Re-predict OL trials: subtract y_ol_mean from all predictor pixels (not pre-history)
pred_nc_A = nan(nNc_wb, outlen_m);
for j = 1:nNc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.nc(j))));
    i0 = i_on - mlag_wb;  i1 = i_on + outlen_m - 1;
    if i0 < 1 || i1 > nF; continue; end
    Xw = X_full_m(i0:i1, :);
    Xw(mlag_wb+1:end, 1:nPred) = Xw(mlag_wb+1:end, 1:nPred) - y_ol_mean_A;
    [Phi_t, ~] = buildLagMatrix(y_full_m(i0:i1), Xw, pY, pX);
    pred_nc_A(j,:) = Phi_t * beta_m;
end

% -- Re-predict CL trials: subtract same OL primary mean from contra predictors
pred_wc_A = nan(nWc_wb, outlen_m);
for j = 1:nWc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.wc(j))));
    i0 = i_on - mlag_wb;  i1 = i_on + outlen_m - 1;
    if i0 < 1 || i1 > nF; continue; end
    Xw = X_full_m(i0:i1, :);
    Xw(mlag_wb+1:end, 1:nPred) = Xw(mlag_wb+1:end, 1:nPred) - y_ol_mean_A;
    [Phi_t, ~] = buildLagMatrix(y_full_m(i0:i1), Xw, pY, pX);
    pred_wc_A(j,:) = Phi_t * beta_m;
end

R2_nc_A = max(0, 1 - sum((actual_nc_m(:)-pred_nc_A(:)).^2,'omitnan') / ...
                      sum((actual_nc_m(:)-mean(actual_nc_m(:),'omitnan')).^2,'omitnan'));
R2_wc_A = max(0, 1 - sum((actual_wc_m(:)-pred_wc_A(:)).^2,'omitnan') / ...
                      sum((actual_wc_m(:)-mean(actual_wc_m(:),'omitnan')).^2,'omitnan'));
fprintf('[WB-1c] Decontam A (mean sub):  R2_OL=%.3f  R2_CL=%.3f   (raw: %.3f  %.3f)\n', ...
    R2_nc_A, R2_wc_A, R2_nc_m, R2_wc_m);

% -- Figure: raw pink vs decontaminated A, OL (left) / CL (right)
colDecA  = [0.15 0.60 0.20];
fig_1c   = paperFig(12, 4);
lm1c=0.09; rm1c=0.04; bm1c=0.20; tm1c=0.08; gx1c=0.08;
pw1c = (1-lm1c-rm1c-gx1c)/2;  ph1c = 1-bm1c-tm1c;

ax1cL = axes(fig_1c,'Position',[lm1c,          bm1c, pw1c, ph1c]);  hold(ax1cL,'on');
plot(ax1cL, t_trial_m, mean(actual_nc_m,1,'omitnan'), 'Color',colOL,   'LineWidth',1.5,'DisplayName','OL actual');
plot(ax1cL, t_trial_m, mean(pred_nc_m,  1,'omitnan'), 'Color',colPrd_m,'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (raw)');
plot(ax1cL, t_trial_m, mean(pred_nc_A,  1,'omitnan'), 'Color',colDecA, 'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (decontam A)');
addStimPatch(ax1cL, 0, dur_wb);  hold(ax1cL,'off');
lgd1cL = legend(ax1cL,'Box','off','FontSize',5,'Location','best');  try; lgd1cL.ItemTokenSize=[6 6]; catch; end
title(ax1cL, sprintf('OL  raw=%.2f  decontam=%.2f',R2_nc_m,R2_nc_A), 'FontSize',6,'FontWeight','bold');

ax1cR = axes(fig_1c,'Position',[lm1c+pw1c+gx1c, bm1c, pw1c, ph1c]);  hold(ax1cR,'on');
plot(ax1cR, t_trial_m, mean(actual_wc_m,1,'omitnan'), 'Color',colCL,   'LineWidth',1.5,'DisplayName','CL actual');
plot(ax1cR, t_trial_m, mean(pred_wc_m,  1,'omitnan'), 'Color',colPrd_m,'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (raw)');
plot(ax1cR, t_trial_m, mean(pred_wc_A,  1,'omitnan'), 'Color',colDecA, 'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (decontam A)');
addStimPatch(ax1cR, 0, dur_wb);  hold(ax1cR,'off');
lgd1cR = legend(ax1cR,'Box','off','FontSize',5,'Location','best');  try; lgd1cR.ItemTokenSize=[6 6]; catch; end
title(ax1cR, sprintf('CL  raw=%.2f  decontam=%.2f',R2_wc_m,R2_wc_A), 'FontSize',6,'FontWeight','bold');

for axi = [ax1cL ax1cR]
    set(axi,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(axi,'Time (s)','FontSize',6,'FontWeight','bold');
    ylabel(axi,'dF/F (%)','FontSize',6,'FontWeight','bold');
end


%% [WB-1d] Decontaminated pink -- Option B: per-pixel laser coupling regression
% For each predictor pixel j, fit a scalar coupling gain alpha_j:
%   X_contra_j(t) ~ alpha_j * u(t)     (using stacked OL trial windows)
% Then subtract alpha_j * u_trial from pixel j before ARX evaluation.
% Handles per-trial laser variation (different powers / pulse shapes).
% Also produces a spatial alpha map showing which contra pixels couple to the laser.
%
% Prereqs: WB-1b must have run.  data_wb.ncInp / wcInp must be present.

ds_1d = round(2000 / Fs_wb);   % laser recorded at 2000 Hz, imaging at Fs_wb

% -- Stack OL trial windows to fit alpha: u [N x 1], X_pixels [N x nPred]
u_stk  = nan(nNc_wb * outlen_m, 1);
X_stk  = nan(nNc_wb * outlen_m, nPred);
stk_n  = 0;
for j = 1:nNc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.nc(j))));
    i0 = i_on;  i1 = i_on + outlen_m - 1;
    if i0 < 1 || i1 > nF; continue; end
    u_j = downsample(data_wb.ncInp(j,:)', ds_1d);
    u_j = u_j(1:outlen_m);
    rows = stk_n + (1:outlen_m);
    u_stk(rows)   = u_j;
    X_stk(rows,:) = X_full_m(i0:i1, 1:nPred);
    stk_n = stk_n + outlen_m;
end
u_stk = u_stk(1:stk_n);
X_stk = X_stk(1:stk_n, :);

% OLS per pixel (no intercept -- signals are mean-removed via rolling baseline)
% alpha = (u'u)^{-1} u'X  ->  [1 x nPred]
alpha_wb = ((u_stk' * u_stk) \ (u_stk' * X_stk))';   % [nPred x 1]
fprintf('[WB-1d] alpha range: [%.4f, %.4f]  mean=%.4f\n', min(alpha_wb), max(alpha_wb), mean(alpha_wb));

% -- Re-predict OL trials with per-pixel cleaned X
pred_nc_B = nan(nNc_wb, outlen_m);
for j = 1:nNc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.nc(j))));
    i0 = i_on - mlag_wb;  i1 = i_on + outlen_m - 1;
    if i0 < 1 || i1 > nF; continue; end
    u_j = downsample(data_wb.ncInp(j,:)', ds_1d);
    u_j = u_j(1:outlen_m);
    Xw = X_full_m(i0:i1, :);
    Xw(mlag_wb+1:end, 1:nPred) = Xw(mlag_wb+1:end, 1:nPred) - u_j * alpha_wb';
    [Phi_t, ~] = buildLagMatrix(y_full_m(i0:i1), Xw, pY, pX);
    pred_nc_B(j,:) = Phi_t * beta_m;
end

% -- Re-predict CL trials (subtract OL-fitted alpha * CL laser)
pred_wc_B = nan(nWc_wb, outlen_m);
for j = 1:nWc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.wc(j))));
    i0 = i_on - mlag_wb;  i1 = i_on + outlen_m - 1;
    if i0 < 1 || i1 > nF; continue; end
    u_j = downsample(data_wb.wcInp(j,:)', ds_1d);
    u_j = u_j(1:outlen_m);
    Xw = X_full_m(i0:i1, :);
    Xw(mlag_wb+1:end, 1:nPred) = Xw(mlag_wb+1:end, 1:nPred) - u_j * alpha_wb';
    [Phi_t, ~] = buildLagMatrix(y_full_m(i0:i1), Xw, pY, pX);
    pred_wc_B(j,:) = Phi_t * beta_m;
end

R2_nc_B = max(0, 1 - sum((actual_nc_m(:)-pred_nc_B(:)).^2,'omitnan') / ...
                      sum((actual_nc_m(:)-mean(actual_nc_m(:),'omitnan')).^2,'omitnan'));
R2_wc_B = max(0, 1 - sum((actual_wc_m(:)-pred_wc_B(:)).^2,'omitnan') / ...
                      sum((actual_wc_m(:)-mean(actual_wc_m(:),'omitnan')).^2,'omitnan'));
fprintf('[WB-1d] Decontam B (alpha reg): R2_OL=%.3f  R2_CL=%.3f   (raw: %.3f  %.3f)\n', ...
    R2_nc_B, R2_wc_B, R2_nc_m, R2_wc_m);

% -- Alpha spatial map: which contra pixels couple most to the laser?
% Two overlapping axes: gray brain image (ax_bg) + hot scatter (ax_sc),
% each with its own colormap and clim.
fig_alpha = figure('Color','w','Units','centimeters','Position',[2 2 8 6]);
pos_al = [0.08 0.10 0.72 0.82];

ax_bg = axes(fig_alpha, 'Position', pos_al);
imagesc(ax_bg, mimg_wb');
colormap(ax_bg, gray);
clim(ax_bg, [prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
axis(ax_bg, 'image', 'off');

% Use ax_bg.Position (settled after axis image) for the overlay.
% Do NOT copy DataAspectRatio -- MATLAB re-solves the layout and shifts the axes.
% Do NOT call axis(image) on ax_sc -- it resets limits on an empty axes.
ax_sc = axes(fig_alpha, 'Position', ax_bg.Position);
ax_sc.Color    = 'none';       % transparent -- brain image shows through
ax_sc.XLim     = ax_bg.XLim;
ax_sc.YLim     = ax_bg.YLim;
ax_sc.YDir     = 'reverse';    % match imagesc convention (row 1 at top)
ax_sc.XLimMode = 'manual';     % prevent autoscaling when scatter is added
ax_sc.YLimMode = 'manual';
set(ax_sc, 'XTick', [], 'YTick', [], 'Box', 'off');
hold(ax_sc, 'on');
scatter(ax_sc, pred_py, pred_px, 40, alpha_wb, 'filled', 'MarkerEdgeColor','none');
plot(ax_sc, py_prim, px_prim, 'c+', 'MarkerSize',8, 'LineWidth',1.5);
colormap(ax_sc, 'hot');
clim(ax_sc, [min(alpha_wb), max(alpha_wb)]);   % scale to actual alpha range
cb_al = colorbar(ax_sc, 'Position', [0.82 0.15 0.04 0.70]);
ylabel(cb_al, '\alpha  (laser-contra coupling)', 'FontSize',5, 'FontWeight','bold');
title(ax_sc, 'Laser-to-contra coupling (\alpha per pixel)', 'FontSize',6, 'FontWeight','bold');

% -- Figure: raw pink vs decontaminated B, OL (left) / CL (right)
colDecB  = [0.60 0.15 0.75];
fig_1d   = paperFig(12, 4);
lm1d=0.09; rm1d=0.04; bm1d=0.20; tm1d=0.08; gx1d=0.08;
pw1d = (1-lm1d-rm1d-gx1d)/2;  ph1d = 1-bm1d-tm1d;

ax1dL = axes(fig_1d,'Position',[lm1d,          bm1d, pw1d, ph1d]);  hold(ax1dL,'on');
plot(ax1dL, t_trial_m, mean(actual_nc_m,1,'omitnan'), 'Color',colOL,   'LineWidth',1.5,'DisplayName','OL actual');
plot(ax1dL, t_trial_m, mean(pred_nc_m,  1,'omitnan'), 'Color',colPrd_m,'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (raw)');
plot(ax1dL, t_trial_m, mean(pred_nc_B,  1,'omitnan'), 'Color',colDecB, 'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (decontam B)');
addStimPatch(ax1dL, 0, dur_wb);  hold(ax1dL,'off');
lgd1dL = legend(ax1dL,'Box','off','FontSize',5,'Location','best');  try; lgd1dL.ItemTokenSize=[6 6]; catch; end
title(ax1dL, sprintf('OL  raw=%.2f  decontam=%.2f',R2_nc_m,R2_nc_B), 'FontSize',6,'FontWeight','bold');

ax1dR = axes(fig_1d,'Position',[lm1d+pw1d+gx1d, bm1d, pw1d, ph1d]);  hold(ax1dR,'on');
plot(ax1dR, t_trial_m, mean(actual_wc_m,1,'omitnan'), 'Color',colCL,   'LineWidth',1.5,'DisplayName','CL actual');
plot(ax1dR, t_trial_m, mean(pred_wc_m,  1,'omitnan'), 'Color',colPrd_m,'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (raw)');
plot(ax1dR, t_trial_m, mean(pred_wc_B,  1,'omitnan'), 'Color',colDecB, 'LineWidth',1.0,'LineStyle','--','DisplayName','Pink (decontam B)');
addStimPatch(ax1dR, 0, dur_wb);  hold(ax1dR,'off');
lgd1dR = legend(ax1dR,'Box','off','FontSize',5,'Location','best');  try; lgd1dR.ItemTokenSize=[6 6]; catch; end
title(ax1dR, sprintf('CL  raw=%.2f  decontam=%.2f',R2_wc_m,R2_wc_B), 'FontSize',6,'FontWeight','bold');

for axi = [ax1dL ax1dR]
    set(axi,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(axi,'Time (s)','FontSize',6,'FontWeight','bold');
    ylabel(axi,'dF/F (%)','FontSize',6,'FontWeight','bold');
end


%% [WB-1e] Pre-trial counterfactual prediction -- clean X, no laser contamination
% For each trial, build the ARX lag matrix from the pre-trial contra window
% (same duration+buffer as the trial window, ending 1 frame before onset).
% All X lags are spontaneous → zero laser contamination by construction.
%
% Prediction = "what would the primary pixel do if the pre-trial contra
% state continued uninterrupted?"  No decontamination algebra required.
%
% Prereqs: WB-1a (beta_m), WB-1b (actual_nc_m / actual_wc_m, nNc_wb, nWc_wb).

colCF = [0.05 0.55 0.35];   % dark teal -- distinguishable from pink/orange/red

buf_pre = mlag_wb + outlen_m;   % frames needed before onset: pX lags + full trial

pred_nc_pre = nan(nNc_wb, outlen_m);
pred_wc_pre = nan(nWc_wb, outlen_m);

for j = 1:nNc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.nc(j))));
    i0_pre = i_on - buf_pre;
    i1_pre = i_on - 1;             % ends 1 frame before onset
    if i0_pre < 1 || i1_pre > nF; continue; end
    [Phi_pre, ~] = buildLagMatrix(y_full_m(i0_pre:i1_pre), X_full_m(i0_pre:i1_pre,:), pY, pX);
    if size(Phi_pre,1) ~= outlen_m; continue; end
    pred_nc_pre(j,:) = Phi_pre * beta_m;
end

for j = 1:nWc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.wc(j))));
    i0_pre = i_on - buf_pre;
    i1_pre = i_on - 1;
    if i0_pre < 1 || i1_pre > nF; continue; end
    [Phi_pre, ~] = buildLagMatrix(y_full_m(i0_pre:i1_pre), X_full_m(i0_pre:i1_pre,:), pY, pX);
    if size(Phi_pre,1) ~= outlen_m; continue; end
    pred_wc_pre(j,:) = Phi_pre * beta_m;
end

R2_nc_pre = max(0, 1 - sum((actual_nc_m(:)-pred_nc_pre(:)).^2,'omitnan') / ...
                        sum((actual_nc_m(:)-mean(actual_nc_m(:),'omitnan')).^2,'omitnan'));
R2_wc_pre = max(0, 1 - sum((actual_wc_m(:)-pred_wc_pre(:)).^2,'omitnan') / ...
                        sum((actual_wc_m(:)-mean(actual_wc_m(:),'omitnan')).^2,'omitnan'));
fprintf('[WB-1e] Pre-trial CF:  R2_OL=%.3f   R2_CL=%.3f   (pink: %.3f  %.3f)\n', ...
    R2_nc_pre, R2_wc_pre, R2_nc_m, R2_wc_m);

% -- Figure: OL left / CL right; actual, pink, pre-trial CF
fig_1e = paperFig(12, 4);
lm1e = 0.10; rm1e = 0.04; bm1e = 0.22; tm1e = 0.14; gx1e = 0.10;
pw1e = (1-lm1e-rm1e-gx1e)/2;
ph1e = 1-bm1e-tm1e;

ax1eL = axes(fig_1e,'Position',[lm1e,          bm1e, pw1e, ph1e]); hold(ax1eL,'on');
patch(ax1eL, [t_trial_m, fliplr(t_trial_m)], ...
    [mean(actual_nc_m,1,'omitnan') + std(actual_nc_m,0,1,'omitnan'), ...
     fliplr(mean(actual_nc_m,1,'omitnan') - std(actual_nc_m,0,1,'omitnan'))], ...
    colOL, 'FaceAlpha',0.15, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax1eL, t_trial_m, mean(actual_nc_m,  1,'omitnan'), 'Color',colOL,    'LineWidth',1.5, 'DisplayName','OL actual');
plot(ax1eL, t_trial_m, mean(pred_nc_m,    1,'omitnan'), 'Color',colPrd_m, 'LineWidth',1.0, 'LineStyle','--', 'DisplayName','Pink (trial X)');
plot(ax1eL, t_trial_m, mean(pred_nc_pre,  1,'omitnan'), 'Color',colCF,    'LineWidth',1.0, 'LineStyle','-',  'DisplayName','Pre-trial CF');
addStimPatch(ax1eL, 0, dur_wb); hold(ax1eL,'off');
title(ax1eL, sprintf('OL  R^2 pink=%.2f  CF=%.2f', R2_nc_m, R2_nc_pre), 'FontSize',6,'FontWeight','bold');

ax1eR = axes(fig_1e,'Position',[lm1e+pw1e+gx1e, bm1e, pw1e, ph1e]); hold(ax1eR,'on');
patch(ax1eR, [t_trial_m, fliplr(t_trial_m)], ...
    [mean(actual_wc_m,1,'omitnan') + std(actual_wc_m,0,1,'omitnan'), ...
     fliplr(mean(actual_wc_m,1,'omitnan') - std(actual_wc_m,0,1,'omitnan'))], ...
    colCL, 'FaceAlpha',0.15, 'EdgeColor','none', 'HandleVisibility','off');
plot(ax1eR, t_trial_m, mean(actual_wc_m,  1,'omitnan'), 'Color',colCL,    'LineWidth',1.5, 'DisplayName','CL actual');
plot(ax1eR, t_trial_m, mean(pred_wc_m,    1,'omitnan'), 'Color',colPrd_m, 'LineWidth',1.0, 'LineStyle','--', 'DisplayName','Pink (trial X)');
plot(ax1eR, t_trial_m, mean(pred_wc_pre,  1,'omitnan'), 'Color',colCF,    'LineWidth',1.0, 'LineStyle','-',  'DisplayName','Pre-trial CF');
addStimPatch(ax1eR, 0, dur_wb); hold(ax1eR,'off');
title(ax1eR, sprintf('CL  R^2 pink=%.2f  CF=%.2f', R2_wc_m, R2_wc_pre), 'FontSize',6,'FontWeight','bold');

for axi = [ax1eL ax1eR]
    set(axi,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    xlabel(axi,'Time (s)','FontSize',6,'FontWeight','bold');
    ylabel(axi,'dF/F (%)','FontSize',6,'FontWeight','bold');
    lg_1e = legend(axi,'Location','best','FontSize',5,'Box','off');
    try; lg_1e.ItemTokenSize = [6 6]; catch; end
end
paperExport(fig_1e, 'wb_pretrial_cf.png');
fprintf('[WB-1e] Exported wb_pretrial_cf.png\n');

%% [WB-artifact] Laser artifact characterization -- OL contra pixel responses
% For each contra predictor pixel j, stack the OL trial windows and average.
% The mean is the deterministic laser artifact (propagated to contra).
% The pre-trial window provides the spontaneous baseline for the same trials.
%
% Outputs:
%   art_amp [nPred]  -- mean artifact amplitude (dF/F, trial-averaged, baseline-corrected)
%   art_snr [nPred]  -- artifact / pre-trial std  (how many sigmas above noise)
%   mu_art  [outlen_m x nPred]  -- full temporal artifact profile per pixel
%
% Prereqs: WB-1b must have run (nNc_wb, outlen_m, t_trial_m, X_full_m, t_wb_m).

art_stk = nan(nNc_wb, outlen_m, nPred);   % trial x time x pixel
pre_stk = nan(nNc_wb, outlen_m, nPred);   % pre-trial baseline (same duration)

for j_art = 1:nNc_wb
    [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.nc(j_art))));
    i0_t = i_on;             i1_t = i_on + outlen_m - 1;   % trial window
    i0_p = i_on - outlen_m; i1_p = i_on - 1;               % pre-trial window
    if i0_t < 1 || i1_t > nF || i0_p < 1; continue; end
    art_stk(j_art,:,:) = X_full_m(i0_t:i1_t, 1:nPred);
    pre_stk(j_art,:,:) = X_full_m(i0_p:i1_p, 1:nPred);
end

mu_art   = squeeze(mean(art_stk, 1, 'omitnan'));   % [outlen_m x nPred]
mu_pre   = squeeze(mean(pre_stk, 1, 'omitnan'));   % [outlen_m x nPred]
std_pre  = squeeze(std( pre_stk, 0, 1, 'omitnan'));% [outlen_m x nPred] -- per-frame std

% Scalar per pixel: mean artifact over full trial window, baseline-corrected
art_amp = mean(mu_art, 1, 'omitnan') - mean(mu_pre, 1, 'omitnan');   % [1 x nPred]
art_snr = art_amp ./ (mean(std_pre, 1, 'omitnan') + eps);            % artifact / noise floor

fprintf('[WB-artifact] Artifact amp: min=%.3f  max=%.3f  mean=%.3f (dF/F%%)\n', ...
    min(art_amp), max(art_amp), mean(art_amp,'omitnan'));
fprintf('[WB-artifact] Artifact SNR: min=%.2f  max=%.2f  mean=%.2f (sigma)\n', ...
    min(art_snr), max(art_snr), mean(art_snr,'omitnan'));

% -- Figure 1: Temporal artifact profile (all pixels, mean ± std across trials)
fig_art1 = paperFig(10, 5);
lmA=0.11; rmA=0.04; bmA=0.18; tmA=0.12;
ax_art1 = axes(fig_art1,'Position',[lmA, bmA, 1-lmA-rmA, 1-bmA-tmA]);
hold(ax_art1,'on');
for jp = 1:nPred
    if jp == contra_idx
        plot(ax_art1, t_trial_m, mu_art(:,jp), 'Color',[0 0.8 0.8], 'LineWidth',1.2, ...
            'DisplayName','Contra-primary');
    else
        plot(ax_art1, t_trial_m, mu_art(:,jp), 'Color',[0.6 0.6 0.6], 'LineWidth',0.4, ...
            'HandleVisibility','off');
    end
end
% Primary pixel OL mean for reference
plot(ax_art1, t_trial_m, mean(actual_nc_m,1,'omitnan'), 'Color',colOL, 'LineWidth',1.5, ...
    'DisplayName','Primary (OL actual)');
yline(ax_art1, 0, 'k--', 'LineWidth',0.6, 'HandleVisibility','off');
addStimPatch(ax_art1, 0, dur_wb);
hold(ax_art1,'off');
set(ax_art1,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
xlabel(ax_art1,'Time (s)','FontSize',6,'FontWeight','bold');
ylabel(ax_art1,'dF/F (%)','FontSize',6,'FontWeight','bold');
title(ax_art1,'OL contra pixel responses (trial-averaged artifact)','FontSize',6,'FontWeight','bold');
lg_art1 = legend(ax_art1,'Location','best','FontSize',5,'Box','off');
try; lg_art1.ItemTokenSize = [6 6]; catch; end
paperExport(fig_art1,'wb_artifact_traces.png');

% -- Figure 2: Spatial maps of artifact amplitude and SNR (dual-axes brain overlay)
fig_art2 = figure('Color','w','Units','centimeters','Position',[2 2 16 6]);

for sp_i = 1:2
    val_sp  = [art_amp(:); art_snr(:)];
    data_sp = {art_amp, art_snr};
    lbl_sp2 = {'Artifact amp (dF/F%)', 'Artifact SNR (\sigma)'};
    pax_sp  = [0.04, 0.56];

    dv = data_sp{sp_i};
    ax_bg2 = axes(fig_art2,'Position',[pax_sp(sp_i), 0.10, 0.42, 0.82]);
    imagesc(ax_bg2, mimg_wb');
    colormap(ax_bg2, gray);
    clim(ax_bg2, [prctile(mimg_wb(:),1), prctile(mimg_wb(:),99)]);
    axis(ax_bg2,'image','off');

    ax_sc2 = axes(fig_art2,'Position', ax_bg2.Position);
    ax_sc2.Color    = 'none';
    ax_sc2.XLim     = ax_bg2.XLim;
    ax_sc2.YLim     = ax_bg2.YLim;
    ax_sc2.YDir     = 'reverse';
    ax_sc2.XLimMode = 'manual';
    ax_sc2.YLimMode = 'manual';
    set(ax_sc2,'XTick',[],'YTick',[],'Box','off');
    hold(ax_sc2,'on');
    scatter(ax_sc2, pred_py, pred_px, 50, dv(:)', 'filled','MarkerEdgeColor','none');
    plot(ax_sc2, py_prim, px_prim, 'c+','MarkerSize',8,'LineWidth',1.5,'HandleVisibility','off');
    colormap(ax_sc2, 'hot');
    dv_lim = [min(dv(:)), max(dv(:))];
    if diff(dv_lim) < eps; dv_lim = dv_lim + [-1 1]*0.01; end
    clim(ax_sc2, dv_lim);
    cb2 = colorbar(ax_sc2,'Location','eastoutside');
    ylabel(cb2, lbl_sp2{sp_i},'FontSize',5,'FontWeight','bold');
    title(ax_sc2, lbl_sp2{sp_i},'FontSize',6,'FontWeight','bold');
end
paperExport(fig_art2,'wb_artifact_map.png');
fprintf('[WB-artifact] Exported wb_artifact_traces.png + wb_artifact_map.png\n');

%% [WB-2] Orange layer -- mean OL residual on top of pink
% Orange = pink + average open-loop stimulus response.
% When applied to CL trials, orange overshoots because feedback suppresses
% the mean impulse -- the undershoot gap reveals controller action.

ol_resid_mean = mean(actual_nc_m - pred_nc_m, 1, 'omitnan');   % [1 x outlen_m]

pred_nc_orange = pred_nc_m + ol_resid_mean;
pred_wc_orange = pred_wc_m + ol_resid_mean;

R2_nc_org = max(0, 1 - sum((actual_nc_m(:)-pred_nc_orange(:)).^2,'omitnan') / ...
                        sum((actual_nc_m(:)-mean(actual_nc_m(:),'omitnan')).^2,'omitnan'));
R2_wc_org = max(0, 1 - sum((actual_wc_m(:)-pred_wc_orange(:)).^2,'omitnan') / ...
                        sum((actual_wc_m(:)-mean(actual_wc_m(:),'omitnan')).^2,'omitnan'));
fprintf('[WB-2] Orange:  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_org, R2_wc_org);


%% [WB-1c] Spatial map -- trial-averaged pixel traces at grid locations
% Each predictor pixel (plus primary) shown as a mini-trace at its spatial
% position on the brain image. OL left, CL right. Prereqs: WB-1b must have run.

% --- Per-pixel trial-averaged traces ---
nPix_sp   = nPred + 1;
pix_py_sp = [pred_py(:); py_prim];   % image row coords -> display x
pix_px_sp = [pred_px(:); px_prim];   % image col coords -> display y

trMean_nc = nan(nPix_sp, outlen_m);
trMean_wc = nan(nPix_sp, outlen_m);

for p_sp = 1:nPred
    buf_nc_sp = nan(nNc_wb, outlen_m);
    buf_wc_sp = nan(nWc_wb, outlen_m);
    for j = 1:nNc_wb
        [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.nc(j))));
        i1 = i_on + outlen_m - 1;
        if i_on < 1 || i1 > nF; continue; end
        buf_nc_sp(j,:) = X_full(i_on:i1, p_sp);
    end
    for j = 1:nWc_wb
        [~, i_on] = min(abs(t_wb_m - d_wb.stimStarts(data_wb.wc(j))));
        i1 = i_on + outlen_m - 1;
        if i_on < 1 || i1 > nF; continue; end
        buf_wc_sp(j,:) = X_full(i_on:i1, p_sp);
    end
    trMean_nc(p_sp,:) = mean(buf_nc_sp, 1, 'omitnan');
    trMean_wc(p_sp,:) = mean(buf_wc_sp, 1, 'omitnan');
end
trMean_nc(nPix_sp,:) = mean(actual_nc_m, 1, 'omitnan');
trMean_wc(nPix_sp,:) = mean(actual_wc_m, 1, 'omitnan');

% Shared y-limits across all pixels and conditions
allTr_sp = [trMean_nc; trMean_wc];
yl_lo_sp = min(allTr_sp(:), [], 'omitnan');
yl_hi_sp = max(allTr_sp(:), [], 'omitnan');
yrng_sp  = max(yl_hi_sp - yl_lo_sp, 1);
yl_sp    = [yl_lo_sp - 0.08*yrng_sp, yl_hi_sp + 0.08*yrng_sp];

% --- Figure: two side-by-side panels ---
fig_spat = figure('Color','w','Units','centimeters','Position',[2 2 24 11]);
lm_s=0.03; rm_s=0.02; bm_s=0.06; tm_s=0.07; gap_s=0.04;
pw_s = (1 - lm_s - rm_s - gap_s) / 2;
ph_s = 1 - bm_s - tm_s;
mw_s = pw_s * 0.14;    % mini-axes width  (~1 grid cell)
mh_s = ph_s * 0.17;    % mini-axes height

colPrim_sp = [1  0.25 0.25];   % red border  = primary pixel
colCont_sp = [0  0.85 0.85];   % cyan border = contra-primary pixel

for iP_sp = 1:2
    pan_x0 = lm_s + (iP_sp-1)*(pw_s + gap_s);
    if iP_sp == 1
        trMat_sp = trMean_nc;  colLine_sp = colOL;  lbl_sp = 'OL (no-controller)';
    else
        trMat_sp = trMean_wc;  colLine_sp = colCL;  lbl_sp = 'CL (with-controller)';
    end

    % Brain image background (faded)
    ax_bg_sp = axes(fig_spat,'Position',[pan_x0, bm_s, pw_s, ph_s]);
    h_im_sp  = imagesc(ax_bg_sp, mimg_wb');
    colormap(ax_bg_sp, gray);
    clim(ax_bg_sp, [prctile(mimg_wb(:),2), prctile(mimg_wb(:),98)]);
    axis(ax_bg_sp,'image','off');
    h_im_sp.AlphaData = 0.45;
    title(ax_bg_sp, lbl_sp, 'FontSize',7,'FontWeight','bold','Color','k');

    % Mini-axes at each pixel's spatial location
    for p_sp = 1:nPix_sp
        % Map display coords to normalized figure position
        % imagesc(mimg_wb'): x-axis = image rows (pred_py), y-axis = image cols (pred_px), y down
        fx_sp = pan_x0 + pw_s * (pix_py_sp(p_sp) - 0.5) / nY_wb;
        fy_sp = bm_s   + ph_s * (1 - (pix_px_sp(p_sp) - 0.5) / nX_wb);
        ap = [fx_sp - mw_s/2, fy_sp - mh_s/2, mw_s, mh_s];
        ap(1) = max(pan_x0,        min(pan_x0 + pw_s - mw_s, ap(1)));
        ap(2) = max(bm_s,          min(bm_s   + ph_s - mh_s, ap(2)));

        ax_m_sp = axes(fig_spat,'Position',ap);
        ax_m_sp.Color = 'none';
        plot(ax_m_sp, t_trial_m, trMat_sp(p_sp,:), 'Color',colLine_sp,'LineWidth',0.9);
        xline(ax_m_sp, 0,'Color',[0.5 0.5 0.5],'LineWidth',0.4,'HandleVisibility','off');
        ylim(ax_m_sp, yl_sp);
        xlim(ax_m_sp, [t_trial_m(1), t_trial_m(end)]);

        if p_sp == nPix_sp           % primary pixel -- red border
            set(ax_m_sp,'Box','on','XTick',[],'YTick',[], ...
                'XColor',colPrim_sp,'YColor',colPrim_sp,'LineWidth',1.5);
        elseif p_sp == contra_idx    % contra-primary -- cyan border
            set(ax_m_sp,'Box','on','XTick',[],'YTick',[], ...
                'XColor',colCont_sp,'YColor',colCont_sp,'LineWidth',1.5);
        else
            set(ax_m_sp,'Box','off','XTick',[],'YTick',[], ...
                'XColor','none','YColor','none');
        end
    end
end

paperExport(fig_spat, fullfile(paper_root, 'images', 'figure4', 'wb_spat_traces.png'));
fprintf('[WB-1c] Saved wb_spat_traces.png\n');


%% [WB-3] Red layer -- per-trial TF response to actual laser input
% Fits 2p1z TF for wb_sel session on OL trial average, then runs each
% trial's actual laser input through that TF via lsim.

iOn_wb   = 36;            % c0_g2: onset column in ncDfk (= 1 s pre-onset at 35 Hz)
ncDfk_pred = data_wb.ncDfk;
ncInp_wb = data_wb.ncInp;
wcInp_wb = data_wb.wcInp;

bc_nc        = mean(ncDfk_pred(:, 1:iOn_wb-1), 2);
ncDfk_bc_wb  = ncDfk_pred - bc_nc;
y_mean_wb    = mean(ncDfk_bc_wb(:, iOn_wb : iOn_wb+outlen_m-1), 1)';

ds_wb      = round(2000 / Fs_wb);
u_mean_wb  = downsample(mean(ncInp_wb,1)', ds_wb);
u_mean_wb  = u_mean_wb(1:outlen_m);

nPre_wb    = 5;
Ts_wb_tf   = 1 / Fs_wb;
data_id_wb = iddata([zeros(nPre_wb,1); y_mean_wb], ...
                    [zeros(nPre_wb,1); u_mean_wb], Ts_wb_tf);
tfOpt_wb   = tfestOptions('EnforceStability',false,'Display','off');
best_wb    = tfest(data_id_wb, 2, 1, tfOpt_wb);

p_wb  = pole(best_wb);
tau_wb = sort(abs(1 ./ real(p_wb(real(p_wb) < 0))));
fprintf('[WB-3] wb TF time constants:');  fprintf('  %.3f s', tau_wb);  fprintf('\n');

% Per-trial OL laser response
laser_resp_nc = nan(nNc_wb, outlen_m);
for j = 1:nNc_wb
    u_j = downsample(ncInp_wb(j,:)', ds_wb);
    u_j = u_j(1:outlen_m);
    try; laser_resp_nc(j,:) = lsim(best_wb, u_j, t_trial_m)'; catch; end
end

% Per-trial CL laser response
laser_resp_wc = nan(nWc_wb, outlen_m);
for j = 1:nWc_wb
    u_j = downsample(wcInp_wb(j,:)', ds_wb);
    u_j = u_j(1:outlen_m);
    try; laser_resp_wc(j,:) = lsim(best_wb, u_j, t_trial_m)'; catch; end
end

pred_nc_red = pred_nc_m + laser_resp_nc;
pred_wc_red = pred_wc_m + laser_resp_wc;

R2_nc_red = max(0, 1 - sum((actual_nc_m(:)-pred_nc_red(:)).^2,'omitnan') / ...
                        sum((actual_nc_m(:)-mean(actual_nc_m(:),'omitnan')).^2,'omitnan'));
R2_wc_red = max(0, 1 - sum((actual_wc_m(:)-pred_wc_red(:)).^2,'omitnan') / ...
                        sum((actual_wc_m(:)-mean(actual_wc_m(:),'omitnan')).^2,'omitnan'));
fprintf('[WB-3] Red:  R2_OL=%.3f   R2_CL=%.3f\n', R2_nc_red, R2_wc_red);
fprintf('  Check: R2_wc_red (%.3f) > R2_wc_pink (%.3f)? %s\n', ...
    R2_wc_red, R2_wc_m, mat2str(R2_wc_red > R2_wc_m));


%% [WB-4] Three-layer overlay -- paper figure (Figure 4)
% Left: OL actual vs pink / orange / red
% Right: CL actual vs pink / red  (orange omitted -- built from OL residual)

colPink_pred   = [0.85 0.55 0.70];
colOrange_wb = [0.90 0.55 0.10];
colRed_wb    = [0.75 0.10 0.10];

fig_wb4 = paperFig(12, 4);
lm4=0.09; rm4=0.04; bm4=0.20; tm4=0.08; gx4=0.08;
pw4 = (1-lm4-rm4-gx4)/2;
ph4 = 1-bm4-tm4;

% Left panel -- OL
ax4L = axes(fig_wb4,'Position',[lm4, bm4, pw4, ph4]);  hold(ax4L,'on');
mn_nc = mean(actual_nc_m,1,'omitnan');
se_nc = std(actual_nc_m,0,1,'omitnan') / sqrt(sum(~all(isnan(actual_nc_m),2)));
fill(ax4L,[t_trial_m,fliplr(t_trial_m)],[mn_nc+se_nc,fliplr(mn_nc-se_nc)], ...
    colOL,'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
plot(ax4L,t_trial_m,mn_nc,                              'Color',colOL,       'LineWidth',PS.lw_mean,'DisplayName','OL actual');
plot(ax4L,t_trial_m,mean(pred_nc_m,     1,'omitnan'),   'Color',colPink_pred,   'LineWidth',PS.lw_fit, 'LineStyle','--','DisplayName','Pink');
plot(ax4L,t_trial_m,mean(pred_nc_orange,1,'omitnan'),   'Color',colOrange_wb, 'LineWidth',PS.lw_fit, 'LineStyle','--','DisplayName','Orange');
plot(ax4L,t_trial_m,mean(pred_nc_red,   1,'omitnan'),   'Color',colRed_wb,    'LineWidth',PS.lw_fit, 'LineStyle','--','DisplayName','Red');
addStimPatch(ax4L, 0, dur_wb);  hold(ax4L,'off');
lgd4L = legend(ax4L,'Location','southwest'); paperLegend(lgd4L);
title(ax4L,'Open-Loop');
xlabel(ax4L,'Time (s)','FontWeight','bold');
ylabel(ax4L,'dF/F (%)','FontWeight','bold');

% Right panel -- CL
ax4R = axes(fig_wb4,'Position',[lm4+pw4+gx4, bm4, pw4, ph4]);  hold(ax4R,'on');
mn_wc = mean(actual_wc_m,1,'omitnan');
se_wc = std(actual_wc_m,0,1,'omitnan') / sqrt(sum(~all(isnan(actual_wc_m),2)));
fill(ax4R,[t_trial_m,fliplr(t_trial_m)],[mn_wc+se_wc,fliplr(mn_wc-se_wc)], ...
    colCL,'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
plot(ax4R,t_trial_m,mn_wc,                            'Color',colCL,     'LineWidth',PS.lw_mean,'DisplayName','CL actual');
plot(ax4R,t_trial_m,mean(pred_wc_m,   1,'omitnan'),   'Color',colPink_pred,'LineWidth',PS.lw_fit, 'LineStyle','--','DisplayName','Pink');
plot(ax4R,t_trial_m,mean(pred_wc_red, 1,'omitnan'),   'Color',colRed_wb, 'LineWidth',PS.lw_fit, 'LineStyle','--','DisplayName','Red');
addStimPatch(ax4R, 0, dur_wb);  hold(ax4R,'off');
lgd4R = legend(ax4R,'Location','southwest'); paperLegend(lgd4R);
title(ax4R,'Closed-Loop');
xlabel(ax4R,'Time (s)','FontWeight','bold');
ylabel(ax4R,'dF/F (%)','FontWeight','bold');

paperExport(fig_wb4, fullfile(paper_root, 'images', 'figure4', 'wb_three_layers.pdf'));
fprintf('[WB-4] Saved wb_three_layers.pdf\n');


%% [WB-5] Post-hoc optimal laser -- MPC motivation
% Per CL trial: given the pink prediction of that trial's initial brain state,
% find the laser sequence u* minimising ||y_pink + H*u - ref||^2.
% Gap = median(MSE_CL_actual) / median(MSE_optimal) -- how suboptimal is the controller?

ref_wb = d_wb.ref;

% Toeplitz convolution matrix from TF impulse response (discrete scaling: divide by Fs)
h_imp_wb = impulse(best_wb, t_trial_m);
H_toep   = toeplitz(h_imp_wb, [h_imp_wb(1); zeros(outlen_m-1,1)]) / Fs_wb;

mse_cl_act = nan(nWc_wb,1);
mse_cl_opt = nan(nWc_wb,1);
for j = 1:nWc_wb
    y_pk = pred_wc_m(j,:)';
    y_ac = actual_wc_m(j,:)';
    if any(isnan(y_pk)) || any(isnan(y_ac)); continue; end
    u_opt = H_toep \ (ref_wb*ones(outlen_m,1) - y_pk);
    y_opt = y_pk + H_toep*u_opt;
    mse_cl_act(j) = mean((y_ac  - ref_wb).^2);
    mse_cl_opt(j) = mean((y_opt - ref_wb).^2);
end

mse_ol_act = nan(nNc_wb,1);
for j = 1:nNc_wb
    y_ac = actual_nc_m(j,:)';
    if any(isnan(y_ac)); continue; end
    mse_ol_act(j) = mean((y_ac - ref_wb).^2);
end

gap_ratio = median(mse_cl_act,'omitnan') / median(mse_cl_opt,'omitnan');
fprintf('[WB-5] MSE -- OL: %.3f  CL: %.3f  Optimal: %.3f\n', ...
    median(mse_ol_act,'omitnan'), median(mse_cl_act,'omitnan'), median(mse_cl_opt,'omitnan'));
fprintf('[WB-5] CL/Optimal gap: %.2fx\n', gap_ratio);

% Grouped bar: OL / CL / Optimal (mean +/- SEM)
fig_wb5 = paperFig(6, 4);
ax_wb5  = axes(fig_wb5,'Units','normalized','Position',[0.20 0.18 0.74 0.72]);
hold(ax_wb5,'on');

grp_labels = {'OL','CL','Optimal'};
grp_data   = {mse_ol_act(~isnan(mse_ol_act)), ...
              mse_cl_act(~isnan(mse_cl_act)), ...
              mse_cl_opt(~isnan(mse_cl_opt))};
gm5  = cellfun(@mean,                       grp_data);
gs5  = cellfun(@(x) std(x)/sqrt(numel(x)), grp_data);
cb5  = [colOL; colCL; 0.5 0.5 0.5];

for g = 1:3
    bar(ax_wb5, g, gm5(g), 0.6, 'FaceColor', cb5(g,:), 'EdgeColor', 'none');
    errorbar(ax_wb5, g, gm5(g), gs5(g), 'k', 'LineWidth', 0.8, 'CapSize', 4, 'LineStyle', 'none');
end
hold(ax_wb5, 'off');
set(ax_wb5, 'XTick', 1:3, 'XTickLabel', grp_labels, ...
    'Box', 'off', 'TickDir', 'out', 'FontSize', PS.fs, 'FontWeight', PS.fw);
ylabel(ax_wb5, 'MSE (\DeltaF/F)^2', 'FontSize', PS.fs, 'FontWeight', PS.fw);
title(ax_wb5, sprintf('CL/Optimal gap: %.2fx', gap_ratio), ...
    'FontSize', PS.fs, 'FontWeight', PS.fw);

paperExport(fig_wb5, fullfile(paper_root, 'images', 'figure4', 'wb_mpc_gap.png'));
fprintf('[WB-5] Saved wb_mpc_gap.png\n');

