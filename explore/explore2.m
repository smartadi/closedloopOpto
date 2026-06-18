% explore/explore2.m
% Step-only experiment: 1 amp per hemisphere, 4 pixels per hemisphere (8 total).
% Run from brain_paper/ root directory.
close all; clear all; clc;

%% ---- Target session ----------------------------------------------------
mn = 'AL_0048';
td = '2026-06-07';
en = 1;           % <-- update for new experiment
% -------------------------------------------------------------------------

%% Setup
if ~isfolder('explore') && isfolder(fullfile('..', 'explore'))
    cd('..');
end
addpath(genpath('utils'));

serverRoot = expPath(mn, td, en);

%% Load raw session data
d = loadData(serverRoot, mn, td, en);
fprintf('Loaded: %s  %s  exp %d\n', mn, td, en);
fprintf('timeBlue: %.1f s at %.1f Hz | %d trials\n', ...
    d.timeBlue(end)-d.timeBlue(1), 1/mean(diff(d.timeBlue)), size(d.input_params,1));

%% Load SVD
svdDir = fullfile(serverRoot, 'blue');
uFile  = fullfile(svdDir, 'svdSpatialComponents.npy');
[uShape] = readNPYheader(uFile);
nSV = min(2000, uShape(3));
fprintf('SVD: loading %d components\n', nSV);
U    = readUfromNPY(uFile, nSV);
V    = readVfromNPY(fullfile(svdDir, 'svdTemporalComponents.npy'), nSV);
mimg = readNPY(fullfile(svdDir, 'meanImage.npy'));

%%
fig_mimg = figure('Name','Mean image','Units','centimeters','Position',[2 2 10 8]);
imagesc(mimg); axis image off; colormap gray; hold on;
bp = d.params.bregma;
plot(bp(1), bp(2), 'g+', 'MarkerSize',12, 'LineWidth',2);
text(bp(1)+5, bp(2), 'bregma', 'Color','g', 'FontSize',8);
title('Mean image'); colorbar;

%% ---- Bregma + pixel computation ----------------------------------------
r_pix     = 1;   % 0 = recompute | 1 = load cache
cachePath = fullfile('data', sprintf('%s_bil_pix_%s%s%d.mat', mn, td(6:7), td(9:10), en));
if ~exist('data','dir'); mkdir('data'); end

bregmaPix = d.params.bregma;
fprintf('Bregma from params: x=%d  y=%d\n', bregmaPix(1), bregmaPix(2));

if exist(cachePath,'file') && r_pix == 1
    C      = load(cachePath);
    pixels = C.pixels;
    fprintf('Loaded cache: %d galvo positions.\n', length(pixels));
else
    galvo_xy = d.input_params(:, [8 9]);
    [unique_mm, ~, ic] = unique(round(galvo_xy, 2), 'rows');
    try; k = double(d.params.kernel); catch; k = 10; end

    pixels = struct('mm',{}, 'pix',{}, 'side',{}, 'dFoF',{});
    for p = 1:size(unique_mm, 1)
        mm_xy   = unique_mm(p, :);
        pix     = convertXYmmToPixels(mm_xy, bregmaPix);
        gx_vals = galvo_xy(ic == p, 1);
        gx_mode = mode(sign(gx_vals));
        if gx_mode > 0; side = 'right'; elseif gx_mode < 0; side = 'left'; else; side = 'unknown'; end

        fprintf('  pos %d: mm=[%.2f %.2f]  pixel=[%d %d]  side=%s  (%d trials)\n', ...
            p, mm_xy, pix, side, sum(ic==p));

        rlo = max(1,pix(2)-k); rhi = min(size(mimg,1),pix(2)+k);
        clo = max(1,pix(1)-k); chi = min(size(mimg,2),pix(1)+k);
        w    = reshape(mean(U(rlo:rhi,clo:chi,:),[1 2]),[1 nSV]);
        dFoF = (w * V) / mean(mimg(rlo:rhi,clo:chi),'all') * 100;

        pixels(p).mm   = mm_xy;
        pixels(p).pix  = pix;
        pixels(p).side = side;
        pixels(p).dFoF = dFoF;
    end
    save(cachePath, 'bregmaPix', 'pixels', '-v7.3');
    fprintf('Saved: %s\n', cachePath);
end

% Mark pixels on mean image
col_L = [0.18 0.45 0.80]; col_R = [0.85 0.20 0.20];
figure(fig_mimg);
for p = 1:length(pixels)
    px = pixels(p).pix;
    if strcmp(pixels(p).side,'left'); mc = col_L; mk = 'o';
    elseif strcmp(pixels(p).side,'right'); mc = col_R; mk = 's';
    else; mc = [1 1 0]; mk = 'x'; end
    plot(px(1), px(2), mk, 'Color', mc, 'MarkerSize',10, 'LineWidth',2);
    text(px(1)+5, px(2), sprintf('%s [%.1f,%.1f]', pixels(p).side, pixels(p).mm), ...
         'Color', mc, 'FontSize', 7);
end

%% Sanity plots — full dF/F traces
close all;
t      = d.timeBlue;
colors = {'b','r','g','m','c','b','r','g'};
figure('Name','dFoF per galvo position','Units','centimeters','Position',[2 2 18 4*length(pixels)]);
for p = 1:length(pixels)
    n = min(length(t), length(pixels(p).dFoF));
    subplot(length(pixels),1,p);
    plot(t(1:n), pixels(p).dFoF(1:n), colors{mod(p-1,8)+1}, 'LineWidth',0.8); hold on;
    plot(d.inpTime, d.inpVals,'k');
    ylabel('\DeltaF/F (%)');
    title(sprintf('%s | mm=[%.2f %.2f] | pixel=[%d %d]', pixels(p).side, pixels(p).mm, pixels(p).pix));
end
xlabel('Time (s)');

%% ---- Build sites lookup from unique galvo positions ---------------------

galvo_x   = d.input_params(:, 8);
galvo_y   = d.input_params(:, 9);
types_all = d.input_params(:, 3);
kk_all    = d.input_params(:, 2);

galvo_xy = [galvo_x galvo_y];
[unique_mm, ~, ic] = unique(round(galvo_xy, 2), 'rows');

sites = struct('mm',{},'side',{},'label',{},'trial_idx',{});
L_count = 0; R_count = 0;
for si = 1:size(unique_mm,1)
    gx = unique_mm(si,1);
    if gx < 0
        side = 'left';  L_count = L_count+1; num = L_count;
    elseif gx > 0
        side = 'right'; R_count = R_count+1; num = R_count;
    else
        side = 'unknown'; num = si;
    end
    sites(si).mm        = unique_mm(si,:);
    sites(si).side      = side;
    sites(si).label     = sprintf('%s%d [%.1f,%.1f]', upper(side(1)), num, unique_mm(si,:));
    sites(si).trial_idx = find(ic == si);
end
nSites = length(sites);
fprintf('\n[Sites] Found %d unique stim sites (%d L, %d R)\n', nSites, L_count, R_count);
for si = 1:nSites
    fprintf('  %s  n=%d trials\n', sites(si).label, length(sites(si).trial_idx));
end

%% ---- Trial plots: rows = recording pixels, cols = stim sites ------------
% ---- Parameters ---------------------------------------------------------
PRE_S       = 1.0;
POST_S      = 3.0;
SHOW_TRIALS = true;
% -------------------------------------------------------------------------

fs    = 1 / mean(diff(t));
n_pre = round(PRE_S  * fs);
n_post= round(POST_S * fs);
t_ax  = (-n_pre : n_post) / fs;

nPix  = length(pixels);
figure('Name','Trial plots — all pixels × all sites', ...
       'Units','centimeters','Position',[2 2 max(12, 5*nSites) max(8, 4*nPix)]);

for pi = 1:nPix
    if strcmp(pixels(pi).side,'left'); col = col_L; else; col = col_R; end
    dFoF = pixels(pi).dFoF;

    for si = 1:nSites
        sp_idx = (pi-1)*nSites + si;
        ax_sp = subplot(nPix, nSites, sp_idx); hold on; box off;

        trial_idx = sites(si).trial_idx;
        mat = [];
        for jj = 1:length(trial_idx)
            kk = round(kk_all(trial_idx(jj)));
            if kk - n_pre < 1 || kk + n_post > length(dFoF); continue; end
            mat(end+1,:) = dFoF(kk - n_pre : kk + n_post);
        end

        if isempty(mat)
            title(sprintf('%s\n(no data)', sites(si).label),'FontSize',5);
            xlim([t_ax(1) t_ax(end)]); continue;
        end

        if SHOW_TRIALS
            plot(t_ax, mat', 'Color', [col 0.15], 'LineWidth',0.4);
        end
        mn_tr = mean(mat,1); sd_tr = std(mat,0,1);
        patch([t_ax fliplr(t_ax)],[mn_tr+sd_tr fliplr(mn_tr-sd_tr)], ...
              col,'FaceAlpha',0.20,'EdgeColor','none');
        plot(t_ax, mn_tr, 'Color', col, 'LineWidth',1.5);
        xline(0,'k:','LineWidth',0.8);

        if pi == 1
            title(sites(si).label,'FontSize',5,'FontWeight','bold','Interpreter','none');
        end
        if si == 1
            ylabel(sprintf('pix %d\n[%.1f,%.1f]', pi, pixels(pi).mm), ...
                   'FontSize',5,'FontWeight','bold');
        end
        if pi == nPix; xlabel('Time (s)','FontSize',5); end
        xlim([t_ax(1) t_ax(end)]);
    end
end
sgtitle('Step trials — recording pixels × stim sites','FontSize',8);

%% ---- Pixel viewer -------------------------------------------------------
close all
% ---- Parameters ---------------------------------------------------------
CALC_WIN = [-1 4];
% -------------------------------------------------------------------------

kk_all_v    = d.input_params(:, 2);
galvo_x_v   = d.input_params(:, 8);
galvo_y_v   = d.input_params(:, 9);

valid = kk_all_v >= 1 & kk_all_v <= length(t);
galvo_xy_v = [galvo_x_v(valid) galvo_y_v(valid)];
kk_all_v   = kk_all_v(valid);

ev_times  = [];
ev_labels = {};

for ii = 1:length(kk_all_v)
    % Match to nearest site
    dists = sum((unique_mm - galvo_xy_v(ii,:)).^2, 2);
    [~, site_idx] = min(dists);
    ev_times(end+1)  = t(kk_all_v(ii));
    ev_labels{end+1} = sites(site_idx).label;
end

if isempty(ev_times)
    fprintf('No events found.\n');
else
    ulab = unique(ev_labels);
    fprintf('Launching viewer — %d events | %s\n', numel(ev_times), strjoin(ulab, ' | '));
    pixelTuningCurveViewerSVD(U, V, t(:)', ev_times, ev_labels, CALC_WIN);
end

%% ---- Brain map ----------------------------------------------------------
close all;
% ---- Parameters ---------------------------------------------------------
r_mask    = 1;
GRID_STEP = 40;
MINI_PRE  = 0.5;
MINI_POST = 2.0;
MINI_SCALE = 8;

% Colour map: left sites = blues, right sites = reds
cmap_L = [0.10 0.30 0.90; 0.10 0.60 1.00; 0.45 0.80 1.00; 0.70 0.90 1.00];
cmap_R = [0.90 0.10 0.10; 1.00 0.40 0.20; 1.00 0.65 0.35; 1.00 0.85 0.55];
L_idx = 0; R_idx = 0;
site_colors = zeros(nSites, 3);
for si = 1:nSites
    if strcmp(sites(si).side,'left')
        L_idx = L_idx + 1;
        site_colors(si,:) = cmap_L(min(L_idx,size(cmap_L,1)),:);
    else
        R_idx = R_idx + 1;
        site_colors(si,:) = cmap_R(min(R_idx,size(cmap_R,1)),:);
    end
end
% -------------------------------------------------------------------------

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

kk_m = d.input_params(:, 2);

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
fs_m = 1/mean(diff(t));
np_m = round(MINI_PRE*fs_m); npo_m = round(MINI_POST*fs_m);
nT   = np_m + npo_m + 1;
t_mini = (-np_m:npo_m)/fs_m;
t_span = MINI_PRE + MINI_POST;

% Pre-compute trial-average for ALL sites
mn_cond = nan(nSites, size(valid_pts,1), nT);
for si = 1:nSites
    kk_sel = round(kk_m(sites(si).trial_idx));
    fprintf('[Brain map] Site %s: %d trials\n', sites(si).label, length(kk_sel));
    for vi = 1:size(valid_pts,1)
        tr = [];
        for jj = 1:length(kk_sel)
            k0 = kk_sel(jj);
            if k0 - np_m < 1 || k0 + npo_m > size(dFoF_grid,2); continue; end
            tr(end+1,:) = dFoF_grid(vi, k0-np_m : k0+npo_m);
        end
        if isempty(tr); continue; end
        tr = tr - mean(tr(:, t_mini < 0), 2);
        mn_cond(si,vi,:) = mean(tr,1);
    end
end

% --- Site picker: click a stim location on the mean image -----------------
% Convert site mm positions to pixel coords for proximity test
site_pix = zeros(nSites, 2);
for si = 1:nSites
    site_pix(si,:) = convertXYmmToPixels(sites(si).mm, bregmaPix);
end

fig_pick = figure('Name','Click a stim site — press Enter to skip', ...
                  'Color','k','Units','normalized','Position',[0.05 0.3 0.35 0.6]);
imagesc(mimg); colormap(gca,gray); axis image off;
clim([prctile(mimg(:),2) prctile(mimg(:),98)]);
hold on;
plot(bregmaPix(1), bregmaPix(2), 'w+', 'MarkerSize',12, 'LineWidth',2);
for si = 1:nSites
    px = site_pix(si,:);
    col = site_colors(si,:);
    plot(px(1), px(2), 'o', 'Color',col, 'MarkerFaceColor',col, 'MarkerSize',10, 'LineWidth',1.5);
    text(px(1)+6, px(2), sites(si).label, 'Color',col, 'FontSize',7, ...
         'FontWeight','bold', 'Interpreter','none');
end
title('Click a stim site to view brain map  |  press Enter to show all', ...
      'Color','w','FontSize',9);

% Non-blocking: attach a WindowButtonDownFcn callback to the picker figure.
% Each click finds the nearest site and draws/replaces the brain map.
% The pixel viewer and all other figures remain fully interactive.

% Pack everything the callback needs into the figure's UserData
ud.site_pix    = site_pix;
ud.sites       = sites;
ud.site_colors = site_colors;
ud.mn_cond     = mn_cond;
ud.valid_pts   = valid_pts;
ud.t_mini      = t_mini;
ud.t_span      = t_span;
ud.MINI_SCALE  = MINI_SCALE;
ud.GRID_STEP   = GRID_STEP;
ud.MINI_PRE    = MINI_PRE;
ud.nRows       = nRows;
ud.nCols       = nCols;
ud.mimg        = mimg;
ud.bregmaPix   = bregmaPix;
ud.nSites      = nSites;
ud.fig_map     = [];   % will hold handle to current brain map figure
set(fig_pick, 'UserData', ud);

set(fig_pick, 'WindowButtonDownFcn', @(f,~) brainMapPickerCb(f));

fprintf('[Brain map] Picker ready — click a site dot to view its brain map.\n');

%% ========================================================================
%  Local functions (must be at end of script)
% =========================================================================

function brainMapPickerCb(fig_pick)
% Called on every click on the site-picker figure.
% Finds nearest site, redraws brain map, leaves all other figures alone.

ud = get(fig_pick, 'UserData');

% Get click position in axes coordinates
ax_pick = get(fig_pick, 'CurrentAxes');
if isempty(ax_pick); return; end
cp = get(ax_pick, 'CurrentPoint');
cx = cp(1,1); cy = cp(1,2);

% Find nearest site
dists = sum((ud.site_pix - [cx cy]).^2, 2);
[~, sel] = min(dists);
col = ud.site_colors(sel,:);
fprintf('[Brain map] Selected: %s\n', ud.sites(sel).label);

% Highlight selected site on picker (redraw markers only)
cla(ax_pick);
imagesc(ax_pick, ud.mimg); colormap(ax_pick, gray); axis(ax_pick,'image','off');
clim(ax_pick, [prctile(ud.mimg(:),2) prctile(ud.mimg(:),98)]);
hold(ax_pick,'on');
plot(ax_pick, ud.bregmaPix(1), ud.bregmaPix(2), 'w+', 'MarkerSize',12, 'LineWidth',2);
for si = 1:ud.nSites
    px = ud.site_pix(si,:); sc = ud.site_colors(si,:);
    if si == sel
        plot(ax_pick, px(1), px(2), 'o', 'Color','w', 'MarkerFaceColor',sc, 'MarkerSize',14, 'LineWidth',2.5);
    else
        plot(ax_pick, px(1), px(2), 'o', 'Color',sc, 'MarkerFaceColor',sc, 'MarkerSize',10, 'LineWidth',1.0);
    end
    text(ax_pick, px(1)+6, px(2), ud.sites(si).label, 'Color',sc, 'FontSize',7, ...
         'FontWeight','bold', 'Interpreter','none');
end
title(ax_pick, sprintf('Selected: %s  |  click another site', ud.sites(sel).label), ...
      'Color','w','FontSize',9);

% Close previous brain map and open new one
if isfield(ud,'fig_map') && ~isempty(ud.fig_map) && ishandle(ud.fig_map)
    close(ud.fig_map);
end

fig_map = figure('Name', sprintf('Brain map — %s', ud.sites(sel).label), ...
                 'Units','normalized','Position',[0.4 0 0.6 1]);
ax = axes(fig_map); hold(ax,'on');
imagesc(ax, flipud(ud.mimg)); colormap(ax, gray);
clim(ax, [prctile(ud.mimg(:),2) prctile(ud.mimg(:),98)]);
axis(ax,'image','off'); set(ax,'Color','k');

t_span      = ud.t_span;
half_w      = ud.GRID_STEP * 0.9 / 2;
x_onset_frac = ud.MINI_PRE / t_span;

for vi = 1:size(ud.valid_pts,1)
    row_g = ud.valid_pts(vi,1); col_g = ud.valid_pts(vi,2);
    y_ctr = ud.nRows + 1 - row_g;
    x_pl  = col_g - half_w + (ud.t_mini - ud.t_mini(1)) / t_span * half_w * 2;
    plot(ax, x_pl([1 end]), [y_ctr y_ctr], 'Color',[1 1 1 0.15], 'LineWidth',0.3);
    x_on = col_g - half_w + x_onset_frac * half_w * 2;
    plot(ax, [x_on x_on], [y_ctr-2 y_ctr+2], 'Color',[1 1 0 0.5], 'LineWidth',0.5);
    mn_vi = squeeze(ud.mn_cond(sel,vi,:))';
    if all(isnan(mn_vi)); continue; end
    plot(ax, x_pl, y_ctr + mn_vi * ud.MINI_SCALE, 'Color', col, 'LineWidth',0.8);
end

plot(ax, [ud.bregmaPix(1) ud.bregmaPix(1)], [1 ud.nRows], 'w--', 'LineWidth',1.0);

sb_col = ud.nCols - 4*ud.GRID_STEP; sb_row_d = 2*ud.GRID_STEP; sb_dff = 5;
plot(ax,[sb_col sb_col],[sb_row_d sb_row_d-sb_dff*ud.MINI_SCALE],'w-','LineWidth',1.5);
text(ax,sb_col+3,sb_row_d-sb_dff*ud.MINI_SCALE/2,sprintf('%g%% dF/F',sb_dff),...
     'Color','w','FontSize',7,'VerticalAlignment','middle');
sb_t = 1; x_sb = sb_col + round(1.5*ud.GRID_STEP);
plot(ax,[x_sb x_sb+(sb_t/t_span)*half_w*2],[sb_row_d sb_row_d],'w-','LineWidth',1.5);
text(ax,x_sb,sb_row_d+8,sprintf('%g s',sb_t),'Color','w','FontSize',7,'HorizontalAlignment','left');
title(ax, sprintf('Brain map  |  %s  |  scale: %g px/%%dF/F', ...
      ud.sites(sel).label, ud.MINI_SCALE), 'FontSize',8,'Color','w','Interpreter','none');

% Save new brain map handle back into picker UserData
ud.fig_map = fig_map;
set(fig_pick, 'UserData', ud);
end
