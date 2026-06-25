% explore/explore5.m
% Red-laser bilateral experiment: 2 recording pixels (L + R), stim on L or R,
% 1 s step at 2 amplitude levels (col 5). Separates trials by stim side AND
% amplitude. Brain-map picker: click a side marker + a clickable amp button.
% Run from brain_paper/ root directory.
close all; clear all; clc;

%% ---- Target session ----------------------------------------------------
mn = 'AL_0048';
td = '2026-06-20';   % <-- update

en = 1;              % <-- update




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
amp_inp     = d.input_params(:, 5);          % col 5 = amplitude
n_L = sum(galvo_x_inp < 0); n_R = sum(galvo_x_inp > 0);
col_L_in = [0.18 0.45 0.80]; col_R_in = [0.85 0.20 0.20];

% --- Condition breakdown: stim side x amplitude (confirm data was read OK) -
uamps = sort(unique(amp_inp(~isnan(amp_inp))))';
fprintf('Amplitudes present (col 5): %s  (%d levels)\n', mat2str(uamps), numel(uamps));
for a = uamps
    nLa = sum(galvo_x_inp < 0 & abs(amp_inp - a) < 1e-6);
    nRa = sum(galvo_x_inp > 0 & abs(amp_inp - a) < 1e-6);
    fprintf('  amp %g:  LEFT n=%d  |  RIGHT n=%d\n', a, nLa, nRa);
end

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

%% ---- Trial plots: rows = stim side × amplitude, cols = recording pixel --
% ---- Parameters ---------------------------------------------------------
PRE_S       = 1.0;
POST_S      = 3.0;
SHOW_TRIALS = true;
% -------------------------------------------------------------------------

fs    = 1 / mean(diff(t));
n_pre = round(PRE_S  * fs);
n_post= round(POST_S * fs);
t_ax  = (-n_pre : n_post) / fs;

galvo_x   = d.input_params(:, 8);
types_all = d.input_params(:, 3);
amps_all  = d.input_params(:, 5);
kk_all    = d.input_params(:, 2);

ucodes = unique(types_all);
fprintf('\n[Trial plots] trial_type codes in data: %s\n', mat2str(ucodes'));
amp_levels = sort(unique(amps_all(~isnan(amps_all))))';
nAmp       = max(1, numel(amp_levels));
fprintf('[Trial plots] amplitude levels: %s\n', mat2str(amp_levels));

left_idx  = find(strcmp({pixels.side},'left'),  1);
right_idx = find(strcmp({pixels.side},'right'), 1);
if isempty(left_idx) || isempty(right_idx)
    fprintf('[Trial plots] Need one left and one right pixel — skipping.\n');
else
    stim_sides = {'left','right'};
    pix_list   = {left_idx, right_idx};
    pix_cols   = {col_L, col_R};
    pix_labels = {'LEFT pixel','RIGHT pixel'};

    % Rows = stim side × amplitude (low→high within each side); cols = pixel
    nRowsTP = 2 * nAmp;
    figure('Name','Trial plots — (stim side × amp) × recording pixel', ...
           'Units','centimeters','Position',[2 2 16 3.5*nRowsTP]);

    for si = 1:2                       % stim side
        if strcmp(stim_sides{si},'left'); side_mask = galvo_x < 0;
        else;                             side_mask = galvo_x > 0;
        end
        for ai = 1:nAmp                % amplitude level
            amp_val  = amp_levels(ai);
            amp_mask = abs(amps_all - amp_val) < 1e-6;
            trial_idx = find(side_mask & amp_mask);
            row_idx   = (si-1)*nAmp + ai;

            for pi = 1:2               % recording pixel
                p    = pix_list{pi};
                base = pix_cols{pi};
                % shade by amplitude: low amp = lighter, high amp = full colour
                shade = 0.35 + 0.65*(ai-1)/max(1,nAmp-1);
                col   = 1 - shade*(1 - base);
                dFoF  = pixels(p).dFoF;

                sp_idx = (row_idx-1)*2 + pi;
                subplot(nRowsTP, 2, sp_idx); hold on; box off;

                if isempty(trial_idx)
                    title(sprintf('stim %s amp%g | %s (no trials)', ...
                          stim_sides{si}, amp_val, pix_labels{pi}),'FontSize',6);
                    xlim([t_ax(1) t_ax(end)]); continue;
                end

                mat = [];
                for jj = 1:length(trial_idx)
                    kk = round(kk_all(trial_idx(jj)));
                    if isnan(kk) || kk - n_pre < 1 || kk + n_post > length(dFoF); continue; end
                    mat(end+1,:) = dFoF(kk - n_pre : kk + n_post);
                end
                if isempty(mat)
                    title(sprintf('stim %s amp%g | %s (no data)', ...
                          stim_sides{si}, amp_val, pix_labels{pi}),'FontSize',6);
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

                title(sprintf('stim %s | amp %g | %s (n=%d)', ...
                      stim_sides{si}, amp_val, pix_labels{pi}, size(mat,1)), ...
                      'FontSize',6,'FontWeight','bold');
                if pi == 1; ylabel('\DeltaF/F (%)','FontSize',6); end
                if row_idx == nRowsTP; xlabel('Time (s)','FontSize',6); end
                xlim([t_ax(1) t_ax(end)]);
            end
        end
    end
    sgtitle('Red laser — (stim side × amplitude) × recording pixel','FontSize',8);
end

%% ---- Pixel viewer -------------------------------------------------------
close all
% ---- Selection parameters -----------------------------------------------
SEL_SIDES = {'left','right'};   % stim side(s): {'left'} | {'right'} | {'left','right'}
SEL_AMPS  = 'all';              % amplitude(s): 'all' | numeric vector, e.g. [1] or [1 2]
CALC_WIN  = [-10 10];             % (s) peri-event window
% -------------------------------------------------------------------------

kk_all_v  = d.input_params(:, 2);
galvo_x_v = d.input_params(:, 8);
amp_v     = d.input_params(:, 5);

valid      = kk_all_v >= 1 & kk_all_v <= length(t);
kk_all_v   = kk_all_v(valid);
galvo_x_v  = galvo_x_v(valid);
amp_v      = amp_v(valid);

amps_present = sort(unique(amp_v(~isnan(amp_v))))';
fprintf('[Pixel viewer] amplitudes present: %s\n', mat2str(amps_present));
amp_is_all = ischar(SEL_AMPS) || isstring(SEL_AMPS);   % 'all' -> keep every amp

ev_times  = [];
ev_labels = {};
for ii = 1:length(kk_all_v)
    if galvo_x_v(ii) < 0;      side = 'left';
    elseif galvo_x_v(ii) > 0;  side = 'right';
    else;                       side = 'unknown';
    end
    if ~ismember(side, SEL_SIDES); continue; end
    if ~amp_is_all && ~any(abs(amp_v(ii) - SEL_AMPS) < 1e-6); continue; end  %#ok<UNRCH>  (reachable when SEL_AMPS is numeric)
    ev_times(end+1)  = t(kk_all_v(ii));
    ev_labels{end+1} = sprintf('stim %s a%g', upper(side), amp_v(ii));  % side × amp condition
end

if isempty(ev_times)
    fprintf('[Pixel viewer] No events matched selection (sides=%s, amps=%s).\n', ...
            strjoin(SEL_SIDES,'+'), mat2str(SEL_AMPS));
else
    ulab = unique(ev_labels);
    fprintf('[Pixel viewer] %d events | %s\n', numel(ev_times), strjoin(ulab,' | '));
    pixelTuningCurveViewerSVD(U, V, t(:)', ev_times, ev_labels, CALC_WIN);
end

%% ---- Brain map (condition picker) ---------------------------------------
close all
% ---- Selection parameters -----------------------------------------------
r_mask     = 1;
GRID_STEP  = 40;
MINI_PRE   = 2;
MINI_POST  = 5;
MINI_SCALE = 8;
SEL_SIDES  = {'left','right'};   % sides to build: {'left'} | {'right'} | {'left','right'}
% Amplitude is chosen on the brain-map GUI: every level present gets a button,
% so you can flip between the two amps interactively (no parameter needed).
% -------------------------------------------------------------------------

kk_m      = d.input_params(:, 2);
galvo_x_m = d.input_params(:, 8);
amp_m     = d.input_params(:, 5);

% Every amplitude level present becomes an amp-picker button on the GUI
amp_lvls_m = sort(unique(amp_m(~isnan(amp_m))))';
sel_amps   = amp_lvls_m;
fprintf('[Brain map] amplitude levels (picker buttons): %s\n', mat2str(amp_lvls_m));

% Build condition list = (selected sides) x (selected amps); one site per condition
conds = struct('side',{},'amp',{},'label',{},'color',{},'trial_idx',{});
for s = 1:numel(SEL_SIDES)
    side = SEL_SIDES{s};
    if strcmp(side,'left'); side_mask = galvo_x_m < 0; ccol = col_L;
    else;                   side_mask = galvo_x_m > 0; ccol = col_R;
    end
    for a = sel_amps
        amp_mask = abs(amp_m - a) < 1e-6;
        conds(end+1) = struct( ...
            'side', side, 'amp', a, ...
            'label', sprintf('stim %s | amp %g', upper(side), a), ...
            'color', ccol, ...
            'trial_idx', find(side_mask & amp_mask));   %#ok<SAGROW>
    end
end
nConds = numel(conds);
if nConds == 0
    error('[Brain map] No conditions selected — check SEL_SIDES / SEL_AMPS.');
end
for ci = 1:nConds
    fprintf('[Brain map] cond %d — %s: %d trials\n', ci, conds(ci).label, numel(conds(ci).trial_idx));
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

% Pre-compute trial averages for each selected condition
mn_cond_bm = nan(nConds, size(valid_pts,1), nT);
for ci = 1:nConds
    kk_sel = round(kk_m(conds(ci).trial_idx));
    for vi = 1:size(valid_pts,1)
        tr = [];
        for jj = 1:length(kk_sel)
            k0 = kk_sel(jj);
            if k0 - np_m < 1 || k0 + npo_m > size(dFoF_grid,2); continue; end
            tr(end+1,:) = dFoF_grid(vi, k0-np_m : k0+npo_m);   %#ok<SAGROW>
        end
        if isempty(tr); continue; end
        tr = tr - mean(tr(:, t_mini < 0), 2);
        mn_cond_bm(ci,vi,:) = mean(tr,1);
    end
end

% --- Side picker: small mean-image window; click a recording-pixel marker to
%     choose the stim SIDE.
fig_pick = figure('Name','Side picker — click LEFT or RIGHT stim marker', ...
                  'Color','k','Units','normalized','Position',[0.02 0.30 0.30 0.55]);
ax_pick = axes('Parent',fig_pick,'Units','normalized','Position',[0.05 0.04 0.90 0.88]);
imagesc(ax_pick, mimg); colormap(ax_pick,gray); axis(ax_pick,'image','off');
clim(ax_pick,[prctile(mimg(:),2) prctile(mimg(:),98)]);
hold(ax_pick,'on');
plot(ax_pick, bregmaPix(1), bregmaPix(2), 'w+', 'MarkerSize',12, 'LineWidth',2);
for p = 1:length(pixels)
    px = pixels(p).pix;
    if strcmp(pixels(p).side,'left'); mc = col_L; else; mc = col_R; end
    plot(ax_pick, px(1), px(2), 'o', 'Color',mc, 'MarkerFaceColor',mc, 'MarkerSize',14, 'LineWidth',2);
    text(ax_pick, px(1)+6, px(2), sprintf('%s stim', pixels(p).side), 'Color',mc, 'FontSize',8, 'FontWeight','bold');
end

% --- Brain-map figure carrying the AMP PICKER (one button per amp level) --
fig_map = figure('Name','Brain map','Color','k','Units','normalized','Position',[0.34 0 0.64 1]);
ax_map  = axes('Parent',fig_map,'Units','normalized','Position',[0.02 0.02 0.96 0.90]);
uicontrol(fig_map,'Style','text','Units','normalized','Position',[0.02 0.945 0.07 0.035], ...
          'String','Amp:','BackgroundColor','k','ForegroundColor','w', ...
          'FontWeight','bold','HorizontalAlignment','left','FontSize',10);
amp_btns = gobjects(1, numel(amp_lvls_m));
for ai = 1:numel(amp_lvls_m)
    av = amp_lvls_m(ai);
    amp_btns(ai) = uicontrol(fig_map,'Style','pushbutton','Units','normalized', ...
        'Position',[0.09 + (ai-1)*0.11, 0.945, 0.10, 0.04], ...
        'String',sprintf('amp %g', av), 'FontWeight','bold','FontSize',10, ...
        'Callback', @(src,~) bmAmpCb(fig_pick, av));
end

% Pack shared state on fig_pick (both windows' callbacks read/write it)
ud3.pixels      = pixels;
ud3.col_L       = col_L;
ud3.col_R       = col_R;
ud3.conds       = conds;
ud3.sel_amps    = amp_lvls_m;
ud3.amp_btns    = amp_btns;
ud3.ax_pick     = ax_pick;
ud3.ax_map      = ax_map;
ud3.fig_map     = fig_map;
ud3.cur_side    = conds(1).side;   % default selection
ud3.cur_amp     = amp_lvls_m(1);
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
set(fig_pick, 'UserData', ud3);
set(fig_pick, 'WindowButtonDownFcn', @(f,~) bmSideCb(f));

% Draw the default condition immediately
renderBrainMap(fig_pick);

fprintf('[Brain map] Ready — click a side marker (side picker); click amp buttons (brain map).\n');

%% ========================================================================
%  Local functions
% =========================================================================

function bmSideCb(fig_pick)
% Marker-click callback: pick the stim SIDE from the nearest recording pixel.
ud = get(fig_pick, 'UserData');
ax_pick = ud.ax_pick;
if isempty(ax_pick) || ~ishandle(ax_pick); return; end
cp = get(ax_pick, 'CurrentPoint');
cx = cp(1,1); cy = cp(1,2);
pix_coords = reshape([ud.pixels.pix], 2, [])';   % nPix x 2: [x y]
dists = sum((pix_coords - [cx cy]).^2, 2);
[~, nearest_pix] = min(dists);
ud.cur_side = ud.pixels(nearest_pix).side;
set(fig_pick, 'UserData', ud);
renderBrainMap(fig_pick);
end

function bmAmpCb(fig_pick, ampVal)
% Amplitude-button callback: pick the amplitude LEVEL.
ud = get(fig_pick, 'UserData');
ud.cur_amp = ampVal;
set(fig_pick, 'UserData', ud);
renderBrainMap(fig_pick);
end

function renderBrainMap(fig_pick)
% Render the trial-averaged brain map for the current (side, amp) selection.
ud = get(fig_pick, 'UserData');
ax_pick = ud.ax_pick;

% Resolve the condition index for the current side + amp
sel = find(strcmp({ud.conds.side}, ud.cur_side) & ...
           abs([ud.conds.amp] - ud.cur_amp) < 1e-6, 1);
if isempty(sel)
    fprintf('[Brain map] No condition for side=%s amp=%g.\n', ud.cur_side, ud.cur_amp);
    return;
end
col = ud.conds(sel).color;
fprintf('[Brain map] Showing: %s\n', ud.conds(sel).label);

% Highlight the active amplitude button
for bi = 1:numel(ud.amp_btns)
    if abs(ud.sel_amps(bi) - ud.cur_amp) < 1e-6
        set(ud.amp_btns(bi), 'BackgroundColor',[1.0 0.85 0.20], 'ForegroundColor','k');
    else
        set(ud.amp_btns(bi), 'BackgroundColor',[0.90 0.90 0.90], 'ForegroundColor','k');
    end
end

% Redraw picker with side highlight
cla(ax_pick);
imagesc(ax_pick, ud.mimg); colormap(ax_pick,gray); axis(ax_pick,'image','off');
clim(ax_pick,[prctile(ud.mimg(:),2) prctile(ud.mimg(:),98)]);
hold(ax_pick,'on');
plot(ax_pick, ud.bregmaPix(1), ud.bregmaPix(2), 'w+', 'MarkerSize',12, 'LineWidth',2);
for p = 1:length(ud.pixels)
    px = ud.pixels(p).pix;
    if strcmp(ud.pixels(p).side,'left'); mc = ud.col_L; else; mc = ud.col_R; end
    sz = 14; lw = 2;
    if strcmp(ud.pixels(p).side, ud.cur_side); sz = 18; lw = 3; end
    plot(ax_pick, px(1), px(2), 'o', 'Color','w', 'MarkerFaceColor',mc, 'MarkerSize',sz, 'LineWidth',lw);
    text(ax_pick, px(1)+6, px(2), sprintf('%s stim', ud.pixels(p).side), ...
         'Color',mc, 'FontSize',8, 'FontWeight','bold');
end
title(ax_pick, sprintf('Side: %s  |  click a marker to switch side', ud.cur_side), ...
      'Color','w','FontSize',9);

% Redraw the brain-map axes in place (figure + amp buttons persist)
ax = ud.ax_map;
cla(ax); hold(ax,'on');
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
      ud.conds(sel).label, ud.MINI_SCALE), 'FontSize',8,'Color','w','Interpreter','none');

set(fig_pick, 'UserData', ud);
end
