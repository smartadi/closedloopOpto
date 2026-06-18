% explore/explore3.m
% Red-laser bilateral experiment: 2 recording pixels (L + R), stim on L or R.
% Separates trials by stim side. Brain map uses same site-picker as explore2.
% Run from brain_paper/ root directory.
close all; clear all; clc;

%% ---- Target session ----------------------------------------------------
mn = 'AL_0048';
td = '2026-06-11';   % <-- update
en = 1;              % <-- none
en = 2;              % <-- update
en = 3;              % <-- update
en = 4;              % <-- update
en = 5;              % <-- update
en = 5;              % <-- update



% -------------------------------------------------------------------------

%% Setup
if ~isfolder('explore') && isfolder(fullfile('..', 'explore'))
    cd('..');
end
addpath(genpath('utils'));

serverRoot = expPath(mn, td, en);

%% Load session
d = loadData(serverRoot, mn, td, en);
fprintf('Loaded: %s  %s  exp %d\n', mn, td, en);
fprintf('timeBlue: %.1f s at %.1f Hz | %d trials\n', ...
    d.timeBlue(end)-d.timeBlue(1), 1/mean(diff(d.timeBlue)), size(d.input_params,1));

t = d.timeBlue;

%% Load SVD
svdDir = fullfile(serverRoot, 'blue');
uFile  = fullfile(svdDir, 'svdSpatialComponents.npy');
vFile  = fullfile(svdDir, 'svdTemporalComponents.npy');

% Cap nSV to however many components are actually in the file
[uShape] = readNPYheader(uFile);
nSV = min(2000, uShape(3));
fprintf('SVD: loading %d components (file has %d)\n', nSV, uShape(3));

U    = readUfromNPY(uFile, nSV);
V    = readVfromNPY(vFile, nSV);
mimg = readNPY(fullfile(svdDir, 'meanImage.npy'));

%% ---- Laser input timeseries --------------------------------------------
kk_inp      = d.input_params(:, 2);
galvo_x_inp = d.input_params(:, 8);
n_L = sum(galvo_x_inp < 0); n_R = sum(galvo_x_inp > 0);
col_L_in = [0.18 0.45 0.80]; col_R_in = [0.85 0.20 0.20];

nPanels = 2 + (~isempty(d.inpTime594)) + (~isempty(d.inpTime638));
figure('Name','Laser input','Units','centimeters','Position',[2 2 28 5*nPanels]);
sp = 0;

% 594 nm trace
if ~isempty(d.inpTime594)
    sp = sp+1; subplot(nPanels,1,sp); hold on; box off;
    plot(d.inpTime594, d.inpVals594, 'Color',[0.85 0.55 0.05], 'LineWidth',0.6);
    ylabel('V'); title('594 nm (red laser)');
    xlim([d.inpTime594(1) d.inpTime594(end)]);
end

% 638 nm trace
if ~isempty(d.inpTime638)
    sp = sp+1; subplot(nPanels,1,sp); hold on; box off;
    plot(d.inpTime638, d.inpVals638, 'Color',[0.75 0.10 0.10], 'LineWidth',0.6);
    ylabel('V'); title('638 nm (orange laser)');
    xlim([d.inpTime638(1) d.inpTime638(end)]);
end

% Trial onset raster
sp = sp+1; subplot(nPanels,1,sp); hold on; box off;
yline(0,'Color',[0.75 0.75 0.75],'LineWidth',0.5);
for ii = 1:size(d.input_params,1)
    kk = round(kk_inp(ii));
    if isnan(kk) || kk < 1 || kk > length(t); continue; end
    if galvo_x_inp(ii) < 0; col_in = col_L_in; lbl = 'L';
    else;                    col_in = col_R_in; lbl = 'R';
    end
    xline(t(kk),'Color',col_in,'LineWidth',1.2,'Alpha',0.8);
    text(t(kk), 0.7+0.2*mod(ii,2), lbl,'Color',col_in,'FontSize',6,'HorizontalAlignment','center');
end
xlabel('Time (s)'); yticks([]); ylim([-0.1 1.1]);
title(sprintf('Trial onsets — LEFT stim n=%d (blue)  |  RIGHT stim n=%d (red)', n_L, n_R));
xlim([t(1) t(end)]);

sgtitle(sprintf('%s  %s  en=%d  |  %d trials  |  %.1f s  %.0f Hz', ...
    mn, td, en, size(d.input_params,1), t(end)-t(1), 1/mean(diff(t))), 'FontSize',9);

%% Mean image + bregma
fig_mimg = figure('Name','Mean image','Units','centimeters','Position',[2 2 10 8]);
imagesc(mimg); axis image off; colormap gray; hold on;
bregmaPix = d.params.bregma;
plot(bregmaPix(1), bregmaPix(2), 'g+', 'MarkerSize',12, 'LineWidth',2);
text(bregmaPix(1)+5, bregmaPix(2), 'bregma', 'Color','g', 'FontSize',8);
title('Mean image'); colorbar;
fprintf('Bregma: x=%d  y=%d\n', bregmaPix(1), bregmaPix(2));

%% ---- Pixel computation (2 pixels: L and R) -----------------------------
r_pix     = 1;
cachePath = fullfile('data', sprintf('%s_bil_pix_%s%s%d.mat', mn, td(6:7), td(9:10), en));
if ~exist('data','dir'); mkdir('data'); end

if exist(cachePath,'file') && r_pix == 1
    C      = load(cachePath);
    pixels = C.pixels;
    fprintf('Loaded cache: %d pixels.\n', length(pixels));
else
    galvo_xy = d.input_params(:, [8 9]);
    [unique_mm, ~, ic] = unique(round(galvo_xy, 2), 'rows');
    try; k = double(d.params.kernel); catch; k = 10; end

    pixels = struct('mm',{}, 'pix',{}, 'side',{}, 'dFoF',{});
    for p = 1:size(unique_mm, 1)
        mm_xy = unique_mm(p,:);
        pix   = convertXYmmToPixels(mm_xy, bregmaPix);
        gx_vals = galvo_xy(ic == p, 1);
        gx_mode = mode(sign(gx_vals));
        if gx_mode > 0; side = 'right'; elseif gx_mode < 0; side = 'left'; else; side = 'unknown'; end
        fprintf('  pos %d: mm=[%.2f %.2f]  pixel=[%d %d]  side=%s  (%d trials)\n', ...
            p, mm_xy, pix, side, sum(ic==p));
        rlo = max(1,pix(2)-k); rhi = min(size(mimg,1),pix(2)+k);
        clo = max(1,pix(1)-k); chi = min(size(mimg,2),pix(1)+k);
        w    = reshape(mean(U(rlo:rhi,clo:chi,:),[1 2]), [1 nSV]);
        dFoF = (w * V) / mean(mimg(rlo:rhi,clo:chi),'all') * 100;
        pixels(p).mm   = mm_xy;
        pixels(p).pix  = pix;
        pixels(p).side = side;
        pixels(p).dFoF = dFoF;
    end
    save(cachePath, 'bregmaPix', 'pixels', '-v7.3');
    fprintf('Saved: %s\n', cachePath);
end

col_L = [0.18 0.45 0.80];
col_R = [0.85 0.20 0.20];

figure(fig_mimg);
for p = 1:length(pixels)
    px = pixels(p).pix;
    if strcmp(pixels(p).side,'left'); mc = col_L; mk = 'o';
    elseif strcmp(pixels(p).side,'right'); mc = col_R; mk = 's';
    else; mc = [1 1 0]; mk = 'x'; end
    plot(px(1), px(2), mk, 'Color',mc, 'MarkerSize',10, 'LineWidth',2);
    text(px(1)+5, px(2), sprintf('%s [%.1f,%.1f]', pixels(p).side, pixels(p).mm), ...
         'Color',mc, 'FontSize',7);
end

%% Sanity — full dF/F traces
figure('Name','dFoF traces','Units','centimeters','Position',[2 2 18 4*length(pixels)]);
for p = 1:length(pixels)
    n = min(length(t), length(pixels(p).dFoF));
    subplot(length(pixels),1,p); hold on;
    plot(t(1:n), pixels(p).dFoF(1:n), 'LineWidth',0.8);
    plot(d.inpTime, d.inpVals, 'k');
    ylabel('\DeltaF/F (%)');
    title(sprintf('%s | mm=[%.2f %.2f]', pixels(p).side, pixels(p).mm));
end
xlabel('Time (s)');

%% ---- Trial plots: rows = stim side, cols = recording pixel -------------
% ---- Parameters ---------------------------------------------------------
PRE_S       = 1.0;
POST_S      = 3.0;
SHOW_TRIALS = true;
% Print trial_type codes to console — inspect before setting TRIAL_CODE
% -------------------------------------------------------------------------

fs    = 1 / mean(diff(t));
n_pre = round(PRE_S  * fs);
n_post= round(POST_S * fs);
t_ax  = (-n_pre : n_post) / fs;

galvo_x   = d.input_params(:, 8);
types_all = d.input_params(:, 3);
kk_all    = d.input_params(:, 2);

ucodes = unique(types_all);
fprintf('\n[Trial plots] trial_type codes in data: %s\n', mat2str(ucodes'));

left_idx  = find(strcmp({pixels.side},'left'),  1);
right_idx = find(strcmp({pixels.side},'right'), 1);
if isempty(left_idx) || isempty(right_idx)
    fprintf('[Trial plots] Need one left and one right pixel — skipping.\n');
else
    dFoF_L = pixels(left_idx).dFoF;
    dFoF_R = pixels(right_idx).dFoF;

    stim_sides = {'left','right'};
    pix_list   = {left_idx, right_idx};
    pix_cols   = {col_L, col_R};
    pix_labels = {'LEFT pixel','RIGHT pixel'};

    figure('Name','Trial plots — stim side × recording pixel', ...
           'Units','centimeters','Position',[2 2 16 14]);

    for si = 1:2   % rows: stim side
        if strcmp(stim_sides{si},'left'); stim_mask = galvo_x < 0;
        else;                             stim_mask = galvo_x > 0;
        end
        trial_idx = find(stim_mask);

        for pi = 1:2   % cols: recording pixel
            p    = pix_list{pi};
            col  = pix_cols{pi};
            dFoF = pixels(p).dFoF;

            sp_idx = (si-1)*2 + pi;
            subplot(2, 2, sp_idx); hold on; box off;

            if isempty(trial_idx)
                title(sprintf('stim %s | %s\n(no trials)', stim_sides{si}, pix_labels{pi}),'FontSize',6);
                xlim([t_ax(1) t_ax(end)]); continue;
            end

            mat = [];
            for jj = 1:length(trial_idx)
                kk = round(kk_all(trial_idx(jj)));
                if isnan(kk) || kk - n_pre < 1 || kk + n_post > length(dFoF); continue; end
                mat(end+1,:) = dFoF(kk - n_pre : kk + n_post);
            end
            if isempty(mat)
                title(sprintf('stim %s | %s\n(no data)', stim_sides{si}, pix_labels{pi}),'FontSize',6);
                xlim([t_ax(1) t_ax(end)]); continue;
            end

            if SHOW_TRIALS
                plot(t_ax, mat', 'Color',[col 0.15], 'LineWidth',0.4);
            end
            mn_tr = mean(mat,1); sd_tr = std(mat,0,1);
            patch([t_ax fliplr(t_ax)],[mn_tr+sd_tr fliplr(mn_tr-sd_tr)], ...
                  col,'FaceAlpha',0.20,'EdgeColor','none');
            plot(t_ax, mn_tr, 'Color',col, 'LineWidth',1.5);
            xline(0,'k:','LineWidth',0.8);

            title(sprintf('stim %s | %s  (n=%d)', stim_sides{si}, pix_labels{pi}, size(mat,1)), ...
                  'FontSize',6,'FontWeight','bold');
            if pi == 1; ylabel('\DeltaF/F (%)','FontSize',6); end
            if si == 2; xlabel('Time (s)','FontSize',6); end
            xlim([t_ax(1) t_ax(end)]);
        end
    end
    sgtitle('Red laser — stim side × recording pixel','FontSize',8);
end

%% ---- Pixel viewer -------------------------------------------------------
close all
% ---- Parameters ---------------------------------------------------------
CALC_WIN = [-1 4];
% -------------------------------------------------------------------------

kk_all_v  = d.input_params(:, 2);
galvo_x_v = d.input_params(:, 8);

valid      = kk_all_v >= 1 & kk_all_v <= length(t);
kk_all_v   = kk_all_v(valid);
galvo_x_v  = galvo_x_v(valid);

ev_times  = [];
ev_labels = {};
for ii = 1:length(kk_all_v)
    if galvo_x_v(ii) < 0;      lbl = 'stim LEFT';
    elseif galvo_x_v(ii) > 0;  lbl = 'stim RIGHT';
    else;                       lbl = 'stim UNKNOWN';
    end
    ev_times(end+1)  = t(kk_all_v(ii));
    ev_labels{end+1} = lbl;
end

if isempty(ev_times)
    fprintf('No events found.\n');
else
    ulab = unique(ev_labels);
    fprintf('Launching viewer — %d events | %s\n', numel(ev_times), strjoin(ulab,' | '));
    pixelTuningCurveViewerSVD(U, V, t(:)', ev_times, ev_labels, CALC_WIN);
end

%% ---- Brain map (site picker) -------------------------------------------
close all
% ---- Parameters ---------------------------------------------------------
r_mask    = 1;
GRID_STEP = 40;
MINI_PRE  = 0.5;
MINI_POST = 2.0;
MINI_SCALE = 8;
% -------------------------------------------------------------------------

% Two "sites": left stim and right stim
kk_m    = d.input_params(:, 2);
galvo_x_m = d.input_params(:, 8);

sites_bm(1).label     = 'stim LEFT';
sites_bm(1).side      = 'left';
sites_bm(1).trial_idx = find(galvo_x_m < 0);
sites_bm(1).color     = col_L;

sites_bm(2).label     = 'stim RIGHT';
sites_bm(2).side      = 'right';
sites_bm(2).trial_idx = find(galvo_x_m > 0);
sites_bm(2).color     = col_R;

nSites_bm = 2;
for si = 1:nSites_bm
    fprintf('[Brain map] %s: %d trials\n', sites_bm(si).label, length(sites_bm(si).trial_idx));
end

[nRows, nCols] = size(mimg);
maskPath = fullfile('data', sprintf('%s_brainmask.mat', mn));

if exist(maskPath,'file') && r_mask == 1
    bm = load(maskPath); brain_mask = bm.brain_mask;
    fprintf('[Brain map] Loaded brain mask.\n');
else
    figure('Name','Draw brain mask','Color','k');
    imagesc(mimg); colormap gray; axis image off;
    clim([prctile(mimg(:),2) prctile(mimg(:),98)]);
    title('Draw brain outline — double-click to close','Color','w','FontSize',10);
    brain_mask = roipoly(); close;
    save(maskPath, 'brain_mask');
    fprintf('[Brain map] Brain mask saved.\n');
end

try; kk_kern = double(d.params.kernel); catch; kk_kern = 10; end

grid_rows = round(GRID_STEP/2) : GRID_STEP : nRows;
grid_cols = round(GRID_STEP/2) : GRID_STEP : nCols;

valid_pts = []; W_all = [];
for ri = 1:length(grid_rows)
    for ci_g = 1:length(grid_cols)
        row_g = grid_rows(ri); col_g = grid_cols(ci_g);
        if ~brain_mask(row_g, col_g); continue; end
        rlo = max(1,row_g-kk_kern); rhi = min(nRows,row_g+kk_kern);
        clo = max(1,col_g-kk_kern); chi = min(nCols,col_g+kk_kern);
        w  = reshape(mean(U(rlo:rhi,clo:chi,:),[1 2]),[1 nSV]);
        mI = mean(mimg(rlo:rhi,clo:chi),'all');
        valid_pts(end+1,:) = [row_g col_g];
        W_all(end+1,:)     = w / mI * 100;
    end
end
fprintf('[Brain map] %d grid points inside mask.\n', size(valid_pts,1));

dFoF_grid = W_all * V;
fs_m  = 1/mean(diff(t));
np_m  = round(MINI_PRE*fs_m);  npo_m = round(MINI_POST*fs_m);
nT    = np_m + npo_m + 1;
t_mini = (-np_m:npo_m)/fs_m;
t_span = MINI_PRE + MINI_POST;

% Pre-compute trial averages for both stim sides
mn_cond_bm = nan(nSites_bm, size(valid_pts,1), nT);
for si = 1:nSites_bm
    kk_sel = round(kk_m(sites_bm(si).trial_idx));
    for vi = 1:size(valid_pts,1)
        tr = [];
        for jj = 1:length(kk_sel)
            k0 = kk_sel(jj);
            if k0 - np_m < 1 || k0 + npo_m > size(dFoF_grid,2); continue; end
            tr(end+1,:) = dFoF_grid(vi, k0-np_m : k0+npo_m);
        end
        if isempty(tr); continue; end
        tr = tr - mean(tr(:, t_mini < 0), 2);
        mn_cond_bm(si,vi,:) = mean(tr,1);
    end
end

% Site picker — two buttons: click LEFT half of image = left stim, RIGHT half = right stim
% Use pixel positions of recording pixels as click targets
fig_pick = figure('Name','Click: LEFT pixel = left stim map | RIGHT pixel = right stim map', ...
                  'Color','k','Units','normalized','Position',[0.05 0.3 0.35 0.6]);
imagesc(mimg); colormap(gca,gray); axis image off;
clim([prctile(mimg(:),2) prctile(mimg(:),98)]);
hold on;
plot(bregmaPix(1), bregmaPix(2), 'w+', 'MarkerSize',12, 'LineWidth',2);
% Mark recording pixels as targets
for p = 1:length(pixels)
    px = pixels(p).pix;
    if strcmp(pixels(p).side,'left'); mc = col_L; else; mc = col_R; end
    plot(px(1), px(2), 'o', 'Color',mc, 'MarkerFaceColor',mc, 'MarkerSize',14, 'LineWidth',2);
    text(px(1)+6, px(2), sprintf('%s stim', pixels(p).side), 'Color',mc, 'FontSize',8, 'FontWeight','bold');
end
title('Click a pixel marker to view its brain map','Color','w','FontSize',9);

% Pack UserData for callback
ud3.pixels      = pixels;
ud3.col_L       = col_L;
ud3.col_R       = col_R;
ud3.sites_bm    = sites_bm;
ud3.nSites_bm   = nSites_bm;
ud3.mn_cond_bm  = mn_cond_bm;
ud3.valid_pts   = valid_pts;
ud3.t_mini      = t_mini;
ud3.t_span      = t_span;
ud3.MINI_SCALE  = MINI_SCALE;
ud3.GRID_STEP   = GRID_STEP;
ud3.MINI_PRE    = MINI_PRE;
ud3.nRows       = nRows;
ud3.nCols       = nCols;
ud3.mimg        = mimg;
ud3.bregmaPix   = bregmaPix;
ud3.fig_map     = [];
set(fig_pick, 'UserData', ud3);
set(fig_pick, 'WindowButtonDownFcn', @(f,~) brainMapPickerCb3(f));

fprintf('[Brain map] Picker ready — click a pixel marker.\n');

%% ========================================================================
%  Local functions
% =========================================================================

function brainMapPickerCb3(fig_pick)
ud = get(fig_pick, 'UserData');
ax_pick = get(fig_pick, 'CurrentAxes');
if isempty(ax_pick); return; end
cp = get(ax_pick, 'CurrentPoint');
cx = cp(1,1); cy = cp(1,2);

% Find nearest recording pixel in image space (picker uses normal mimg coords)
pix_coords = reshape([ud.pixels.pix], 2, [])';   % nPix x 2: [x y]
dists = sum((pix_coords - [cx cy]).^2, 2);
[~, nearest_pix] = min(dists);
pix_side = ud.pixels(nearest_pix).side;

% Map recording pixel side → stim site index (ipsi/contra both shown for that side)
% Convention: clicking left pixel → show "stim LEFT" map; clicking right → "stim RIGHT"
if strcmp(pix_side,'left');  sel = 1; col = ud.col_L;
else;                        sel = 2; col = ud.col_R;
end
fprintf('[Brain map] Selected: %s\n', ud.sites_bm(sel).label);

% Redraw picker with highlight
cla(ax_pick);
imagesc(ax_pick, ud.mimg); colormap(ax_pick,gray); axis(ax_pick,'image','off');
clim(ax_pick,[prctile(ud.mimg(:),2) prctile(ud.mimg(:),98)]);
hold(ax_pick,'on');
plot(ax_pick, ud.bregmaPix(1), ud.bregmaPix(2), 'w+', 'MarkerSize',12, 'LineWidth',2);
for p = 1:length(ud.pixels)
    px = ud.pixels(p).pix;
    if strcmp(ud.pixels(p).side,'left'); mc = ud.col_L; else; mc = ud.col_R; end
    sz = 14; lw = 2;
    if p == nearest_pix; sz = 18; lw = 3; end
    plot(ax_pick, px(1), px(2), 'o', 'Color','w', 'MarkerFaceColor',mc, 'MarkerSize',sz, 'LineWidth',lw);
    text(ax_pick, px(1)+6, px(2), sprintf('%s stim', ud.pixels(p).side), ...
         'Color',mc, 'FontSize',8, 'FontWeight','bold');
end
title(ax_pick, sprintf('Showing: %s  |  click to switch', ud.sites_bm(sel).label), ...
      'Color','w','FontSize',9);

% Close previous brain map
if isfield(ud,'fig_map') && ~isempty(ud.fig_map) && ishandle(ud.fig_map)
    close(ud.fig_map);
end

fig_map = figure('Name', sprintf('Brain map — %s', ud.sites_bm(sel).label), ...
                 'Units','normalized','Position',[0.4 0 0.6 1]);
ax = axes(fig_map); hold(ax,'on');
imagesc(ax, flipud(ud.mimg)); colormap(ax,gray);
clim(ax,[prctile(ud.mimg(:),2) prctile(ud.mimg(:),98)]);
axis(ax,'image','off'); set(ax,'Color','k');

t_span       = ud.t_span;
half_w       = ud.GRID_STEP * 0.9 / 2;
x_onset_frac = ud.MINI_PRE / t_span;

for vi = 1:size(ud.valid_pts,1)
    row_g = ud.valid_pts(vi,1); col_g = ud.valid_pts(vi,2);
    y_ctr = ud.nRows + 1 - row_g;
    x_pl  = col_g - half_w + (ud.t_mini - ud.t_mini(1)) / t_span * half_w * 2;
    plot(ax, x_pl([1 end]), [y_ctr y_ctr], 'Color',[1 1 1 0.15], 'LineWidth',0.3);
    x_on = col_g - half_w + x_onset_frac * half_w * 2;
    plot(ax, [x_on x_on], [y_ctr-2 y_ctr+2], 'Color',[1 1 0 0.5], 'LineWidth',0.5);
    mn_vi = squeeze(ud.mn_cond_bm(sel,vi,:))';
    if all(isnan(mn_vi)); continue; end
    plot(ax, x_pl, y_ctr + mn_vi * ud.MINI_SCALE, 'Color',col, 'LineWidth',0.8);
end

plot(ax, [ud.bregmaPix(1) ud.bregmaPix(1)], [1 ud.nRows], 'w--', 'LineWidth',1.0);

sb_col = ud.nCols - 4*ud.GRID_STEP; sb_row_d = 2*ud.GRID_STEP; sb_dff = 5;
plot(ax,[sb_col sb_col],[sb_row_d sb_row_d-sb_dff*ud.MINI_SCALE],'w-','LineWidth',1.5);
text(ax,sb_col+3,sb_row_d-sb_dff*ud.MINI_SCALE/2,sprintf('%g%% dF/F',sb_dff), ...
     'Color','w','FontSize',7,'VerticalAlignment','middle');
sb_t = 1; x_sb = sb_col + round(1.5*ud.GRID_STEP);
plot(ax,[x_sb x_sb+(sb_t/t_span)*half_w*2],[sb_row_d sb_row_d],'w-','LineWidth',1.5);
text(ax,x_sb,sb_row_d+8,sprintf('%g s',sb_t),'Color','w','FontSize',7,'HorizontalAlignment','left');
title(ax, sprintf('Brain map  |  %s  |  scale: %g px/%%dF/F', ...
      ud.sites_bm(sel).label, ud.MINI_SCALE), 'FontSize',8,'Color','w','Interpreter','none');

ud.fig_map = fig_map;
set(fig_pick, 'UserData', ud);
end
