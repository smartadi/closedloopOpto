% controller-analysis -- extracted from plottingScript.m
% Run from brain_paper/ root directory.
% Requires: load_sessions.m has been run first (mouse, fields, tp, Mean_var_wc/nc, dur).


%% Widebrain -- pixel selection
% Define contralateral ROI grid. Re-run freely to adjust grid_rows/grid_cols.
% When happy with the pixel map, run the SVD extraction cell below.
% Residual (actual -' predicted) captures stimulus + controller effect.
close all;

selField = 12;

% -- Parameters
wb_sel      = selField;   % session to analyse (m10, AL_0039 2025-04-19)
pY          = 0;          % no AR self-lags -- prediction purely from contralateral pixels
pX          = 5;          % lags per contralateral predictor (~143 ms at 35 Hz)
Fs_wb       = 35;
dur_wb      = 3;          % trial duration (s)
spont_pre   = 6;          % spontaneous window before each trial (s)
k_wb         = 1;     % SVD kernel half-size (3x3 patch)
grid_rows    = 6;     % visual rows in contra ROI grid  (c direction in original image)
grid_cols    = 5;     % visual cols in contra ROI grid  (r direction in original image)
% nPred is derived automatically: 1 contra-primary + all grid nodes inside the ROI
redefine_roi = true; % set true to redo midline + ROI interactively for this session
mlag_wb      = max(pY, pX);

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
    valid_mask(1:k_wb+1, :)   = false;
    valid_mask(end-k_wb:end,:) = false;
    valid_mask(:, 1:k_wb+1)   = false;
    valid_mask(:, end-k_wb:end)= false;

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
    px_c = max(k_wb+1, min(nX_wb-k_wb, double(px_c)));
    py_c = max(k_wb+1, min(nY_wb-k_wb, double(py_c)));

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

if exist(path_wb,'file') && ~recompute_svd
    tmp    = load(path_wb);
    y_full = tmp.y_full;
    X_full = tmp.X_full;
    fprintf('Loaded dFk cache: %s\n', path_wb);
else
    fprintf('Computing SVD pixel dFk (%d pixels) ...\n', nPred+1);

    % Primary pixel
    mI_p    = mean(mimg_wb(py_prim-k_wb:py_prim+k_wb, px_prim-k_wb:px_prim+k_wb), 'all');
    ikern_p = U_wb(py_prim-k_wb:py_prim+k_wb, px_prim-k_wb:px_prim+k_wb, :);
    ist_p   = reshape(mean(ikern_p, [1 2]), [1, nSV_wb]);
    F_p     = ist_p * V_wb + mI_p;
    Fk_p    = [ones(1,w_r)*mI_p, F_p];
    cs_p    = [0, cumsum(Fk_p)];
    Fm_p    = (cs_p(idx_r+w_r+1) - cs_p(idx_r)) / (w_r+1);
    y_full  = ((F_p - Fm_p) ./ Fm_p * 100)';

    % Contralateral predictor pixels
    X_full = zeros(nFrames, nPred);
    for j = 1:nPred
        cx = pred_px(j); cy = pred_py(j);
        mI_j    = mean(mimg_wb(cy-k_wb:cy+k_wb, cx-k_wb:cx+k_wb), 'all');
        ikern_j = U_wb(cy-k_wb:cy+k_wb, cx-k_wb:cx+k_wb, :);
        ist_j   = reshape(mean(ikern_j, [1 2]), [1, nSV_wb]);
        F_j     = ist_j * V_wb + mI_j;
        Fk_j    = [ones(1,w_r)*mI_j, F_j];
        cs_j    = [0, cumsum(Fk_j)];
        Fm_j    = (cs_j(idx_r+w_r+1) - cs_j(idx_r)) / (w_r+1);
        X_full(:,j) = ((F_j - Fm_j) ./ Fm_j * 100)';
    end

    [~] = mkdir(fileparts(path_wb));   % create data/ if missing; silent no-op if it exists
    save(path_wb, 'y_full', 'X_full', 'pred_px', 'pred_py');
    fprintf('Saved dFk cache: %s\n', path_wb);
end

%% Widebrain prediction -- ARX regression
% Requires the pixel-selection cell above to have been run first.
% Fits contralateral-only ARX model on spontaneous data, applies to OL/CL trials.

% -- Spontaneous windows (6 s pre-trial, all trials pooled)
t_wb       = d_wb.timeBlue;
all_trials = [data_wb.nc(:); data_wb.wc(:)];
pre_frames = spont_pre * Fs_wb;

y_spont = []; X_spont = [];
for j = 1:length(all_trials)
    [~, i_on] = min(abs(t_wb - d_wb.stimStarts(all_trials(j))));
    i0 = i_on - pre_frames; i1 = i_on - 1;
    if i0 < 1; continue; end
    y_spont = [y_spont; y_full(i0:i1)];
    X_spont = [X_spont; X_full(i0:i1,:)];
end

% -- Fit ARX on spontaneous data
[Phi_s, y_s] = buildLagMatrix(y_spont, X_spont, pY, pX);
beta         = Phi_s \ y_s;
y_hat_s      = Phi_s * beta;
R2_spont     = 1 - sum((y_s - y_hat_s).^2) / sum((y_s - mean(y_s)).^2);
fprintf('ARX  R^2_spont=%.3f  (pY=%d  pX=%d  nPred=%d)\n', R2_spont, pY, pX, nPred);

% -- Apply model to OL trials
trial_frames = dur_wb * Fs_wb;   % 105 frames
outlen       = trial_frames;     % buildLagMatrix drops first mlag_wb; output = trial_frames

pred_nc   = nan(length(data_wb.nc), outlen);
actual_nc = nan(length(data_wb.nc), outlen);
for j = 1:length(data_wb.nc)
    [~, i_on] = min(abs(t_wb - d_wb.stimStarts(data_wb.nc(j))));
    i0 = i_on - mlag_wb; i1 = i_on + trial_frames - 1;
    if i0 < 1 || i1 > nFrames; continue; end
    [Phi_t, y_t]   = buildLagMatrix(y_full(i0:i1), X_full(i0:i1,:), pY, pX);
    pred_nc(j,:)   = Phi_t * beta;
    actual_nc(j,:) = y_t;
end

% -- Apply model to CL trials
pred_wc   = nan(length(data_wb.wc), outlen);
actual_wc = nan(length(data_wb.wc), outlen);
for j = 1:length(data_wb.wc)
    [~, i_on] = min(abs(t_wb - d_wb.stimStarts(data_wb.wc(j))));
    i0 = i_on - mlag_wb; i1 = i_on + trial_frames - 1;
    if i0 < 1 || i1 > nFrames; continue; end
    [Phi_t, y_t]   = buildLagMatrix(y_full(i0:i1), X_full(i0:i1,:), pY, pX);
    pred_wc(j,:)   = Phi_t * beta;
    actual_wc(j,:) = y_t;
end

R2_nc = 1 - sum((actual_nc(:)-pred_nc(:)).^2,'omitnan') / ...
             sum((actual_nc(:)-mean(actual_nc(:),'omitnan')).^2,'omitnan');
R2_wc = 1 - sum((actual_wc(:)-pred_wc(:)).^2,'omitnan') / ...
             sum((actual_wc(:)-mean(actual_wc(:),'omitnan')).^2,'omitnan');
fprintf('  R^2_OL=%.3f   R^2_CL=%.3f\n', R2_nc, R2_wc);

% -- Figure: 4-panel
t_trial = (0:outlen-1) / Fs_wb;
colOL   = [1 0 0];
colCL   = [0 0.5 0];
colPrd  = [0.2 0.2 0.8];

fig_wb = paperFig(12, 8);
lm_wb  = 0.10; rm_wb = 0.05; bm_wb = 0.12; tm_wb = 0.08;
gx     = 0.08; gy    = 0.15;
pw_wb  = (1 - lm_wb - rm_wb - gx) / 2;
ph_wb  = (1 - bm_wb - tm_wb - gy) / 2;

% Panel A -- Spontaneous: actual vs predicted (sample window)
ax_A = axes(fig_wb, 'Position', [lm_wb,           bm_wb+ph_wb+gy, pw_wb, ph_wb]);
n_show = min(3*Fs_wb, length(y_s));
t_show = (0:n_show-1) / Fs_wb;
hold(ax_A,'on');
plot(ax_A, t_show, y_s(1:n_show),     'Color',[0 0 0],  'LineWidth',1,   'DisplayName','Actual');
plot(ax_A, t_show, y_hat_s(1:n_show), 'Color', colPrd,  'LineWidth',1,   'DisplayName','Predicted');
hold(ax_A,'off');
legend(ax_A,'Box','off','FontSize',6,'Location','best');
title(ax_A, sprintf('Spontaneous  R^2=%.2f', R2_spont), 'FontSize',6,'FontWeight','bold');

% Panel B -- OL: mean actual vs mean predicted
ax_B = axes(fig_wb, 'Position', [lm_wb+pw_wb+gx,  bm_wb+ph_wb+gy, pw_wb, ph_wb]);
hold(ax_B,'on');
plot(ax_B, t_trial, mean(actual_nc,1,'omitnan'), 'Color',colOL,  'LineWidth',1.5, 'DisplayName','OL actual');
plot(ax_B, t_trial, mean(pred_nc,  1,'omitnan'), 'Color',colPrd, 'LineWidth',1,   'DisplayName','Predicted','LineStyle','--');
addStimPatch(ax_B, 0, dur_wb);
hold(ax_B,'off');
legend(ax_B,'Box','off','FontSize',6,'Location','best');
title(ax_B, sprintf('Open-Loop  R^2=%.2f', R2_nc), 'FontSize',6,'FontWeight','bold');

% Panel C -- CL: mean actual vs mean predicted
ax_C = axes(fig_wb, 'Position', [lm_wb,           bm_wb, pw_wb, ph_wb]);
hold(ax_C,'on');
plot(ax_C, t_trial, mean(actual_wc,1,'omitnan'), 'Color',colCL,  'LineWidth',1.5, 'DisplayName','CL actual');
plot(ax_C, t_trial, mean(pred_wc,  1,'omitnan'), 'Color',colPrd, 'LineWidth',1,   'DisplayName','Predicted','LineStyle','--');
addStimPatch(ax_C, 0, dur_wb);
hold(ax_C,'off');
legend(ax_C,'Box','off','FontSize',6,'Location','best');
title(ax_C, sprintf('Closed-Loop  R^2=%.2f', R2_wc), 'FontSize',6,'FontWeight','bold');

% Panel D -- Residual OL vs CL (actual -' predicted)
ax_D = axes(fig_wb, 'Position', [lm_wb+pw_wb+gx,  bm_wb, pw_wb, ph_wb]);
hold(ax_D,'on');
plot(ax_D, t_trial, mean(actual_nc-pred_nc,1,'omitnan'), 'Color',colOL, 'LineWidth',1.5, 'DisplayName','OL residual');
plot(ax_D, t_trial, mean(actual_wc-pred_wc,1,'omitnan'), 'Color',colCL, 'LineWidth',1.5, 'DisplayName','CL residual');
yline(ax_D, 0, 'k--', 'HandleVisibility','off');
addStimPatch(ax_D, 0, dur_wb);
hold(ax_D,'off');
legend(ax_D,'Box','off','FontSize',6,'Location','best');
title(ax_D, 'Residual: actual - predicted', 'FontSize',6,'FontWeight','bold');

for axi = [ax_A ax_B ax_C ax_D]
    set(axi, 'FontSize',6,'FontWeight','bold','Box','off','TickDir','out');
    ylabel(axi, 'dF/F (%)', 'FontSize',6,'FontWeight','bold');
    xlabel(axi, 'Time (s)', 'FontSize',6,'FontWeight','bold');
end





%% [WB-1a] Pink layer -- spontaneous fit + parameter tuning
% *** TUNING SECTION - adjust nPred / pX at the top of the widebrain block,
%     re-run this cell, inspect the held-out spont figure, repeat. ***
% Once R2_test is satisfactory (>0.3), run WB-1b to apply to trials.
%
% Prereqs: widebrain ROI + ARX sections above (d_wb, data_wb, y_full, X_full,
%          pY, pX, nPred, nFrames, mlag_wb, spont_pre, Fs_wb, dur_wb).

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
exportgraphics(fig_wb1,'paper/images/figure4/wb_pink_4panel.pdf','ContentType','vector');
fprintf('[WB-1b] Saved wb_pink_4panel.pdf\n');


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


%% [WB-3] Red layer -- per-trial TF response to actual laser input
% Fits 2p1z TF for wb_sel session on OL trial average, then runs each
% trial's actual laser input through that TF via lsim.

iOn_wb   = 36;            % c0_g2: onset column in ncDfk (= 1 s pre-onset at 35 Hz)
ncDfk_wb = data_wb.ncDfk;
ncInp_wb = data_wb.ncInp;
wcInp_wb = data_wb.wcInp;

bc_nc        = mean(ncDfk_wb(:, 1:iOn_wb-1), 2);
ncDfk_bc_wb  = ncDfk_wb - bc_nc;
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

colPink_wb   = [0.85 0.55 0.70];
colOrange_wb = [0.90 0.55 0.10];
colRed_wb    = [0.75 0.10 0.10];

PS_wb4  = paperStyle();
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
plot(ax4L,t_trial_m,mn_nc,                              'Color',colOL,       'LineWidth',PS_wb4.lw_mean,'DisplayName','OL actual');
plot(ax4L,t_trial_m,mean(pred_nc_m,     1,'omitnan'),   'Color',colPink_wb,   'LineWidth',PS_wb4.lw_fit, 'LineStyle','--','DisplayName','Pink');
plot(ax4L,t_trial_m,mean(pred_nc_orange,1,'omitnan'),   'Color',colOrange_wb, 'LineWidth',PS_wb4.lw_fit, 'LineStyle','--','DisplayName','Orange');
plot(ax4L,t_trial_m,mean(pred_nc_red,   1,'omitnan'),   'Color',colRed_wb,    'LineWidth',PS_wb4.lw_fit, 'LineStyle','--','DisplayName','Red');
addStimPatch(ax4L, 0, dur_wb);  hold(ax4L,'off');
lgd4L = legend(ax4L,'Box','off','Location','southwest','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
lgd4L.ItemTokenSize = [6 6];
title(ax4L,'Open-Loop','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
xlabel(ax4L,'Time (s)','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
ylabel(ax4L,'dF/F (%)','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
set(ax4L,'Box','off','TickDir','out','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);

% Right panel -- CL
ax4R = axes(fig_wb4,'Position',[lm4+pw4+gx4, bm4, pw4, ph4]);  hold(ax4R,'on');
mn_wc = mean(actual_wc_m,1,'omitnan');
se_wc = std(actual_wc_m,0,1,'omitnan') / sqrt(sum(~all(isnan(actual_wc_m),2)));
fill(ax4R,[t_trial_m,fliplr(t_trial_m)],[mn_wc+se_wc,fliplr(mn_wc-se_wc)], ...
    colCL,'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
plot(ax4R,t_trial_m,mn_wc,                            'Color',colCL,     'LineWidth',PS_wb4.lw_mean,'DisplayName','CL actual');
plot(ax4R,t_trial_m,mean(pred_wc_m,   1,'omitnan'),   'Color',colPink_wb,'LineWidth',PS_wb4.lw_fit, 'LineStyle','--','DisplayName','Pink');
plot(ax4R,t_trial_m,mean(pred_wc_red, 1,'omitnan'),   'Color',colRed_wb, 'LineWidth',PS_wb4.lw_fit, 'LineStyle','--','DisplayName','Red');
addStimPatch(ax4R, 0, dur_wb);  hold(ax4R,'off');
lgd4R = legend(ax4R,'Box','off','Location','southwest','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
lgd4R.ItemTokenSize = [6 6];
title(ax4R,'Closed-Loop','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
xlabel(ax4R,'Time (s)','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
ylabel(ax4R,'dF/F (%)','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);
set(ax4R,'Box','off','TickDir','out','FontSize',PS_wb4.fs,'FontWeight',PS_wb4.fw);

exportgraphics(fig_wb4,'paper/images/figure4/wb_three_layers.pdf','ContentType','vector');
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
PS_wb5  = paperStyle();
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