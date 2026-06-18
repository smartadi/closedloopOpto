 % explore/explore.m
% Load a session, pick bregma, compute and cache dF/F for each galvo position.
% Run from brain_paper/ root directory.
close all; clear all; clc;

%% ---- Target session ----------------------------------------------------
mn = 'AL_0048';
td = '2026-06-05';
en = 2;


% mn = 'AL_0048';
% td = '2026-06-07';
% en = 1;
% -------------------------------------------------------------------------

%% Setup
if ~isfolder('explore') && isfolder(fullfile('..', 'explore'))
    cd('..');
end
addpath(genpath('utils'));

serverRoot = expPath(mn, td, en);

%% Load raw session data (bypasses findStims / params.dur)
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
r_pix     = 1;   % 0 = recompute pixels | 1 = load cache
cachePath = fullfile('data', sprintf('%s_bil_pix_%s%s%d.mat', mn, td(6:7), td(9:10), en));
if ~exist('data','dir'); mkdir('data'); end

% Bregma from params (no click needed)
bregmaPix = d.params.bregma;   % [x y] in pixels
fprintf('Bregma from params: x=%d  y=%d\n', bregmaPix(1), bregmaPix(2));

if exist(cachePath,'file') && r_pix == 1
    C      = load(cachePath);
    pixels = C.pixels;
    fprintf('Loaded cache: %d galvo positions.\n', length(pixels));
else

    % Unique galvo positions from input_params
    galvo_xy = d.input_params(:, [8 9]);   % cols 8,9: galvo_x_mm, galvo_y_mm
    hemi_col = d.input_params(:, 4);       % col 4: hemisphere
    [unique_mm, ~, ic] = unique(round(galvo_xy, 2), 'rows');

    try; k = double(d.params.kernel); catch; k = 10; end

    pixels = struct('mm',{}, 'pix',{}, 'side',{}, 'dFoF',{});

    for p = 1:size(unique_mm, 1)
        mm_xy = unique_mm(p, :);
        pix   = convertXYmmToPixels(mm_xy, bregmaPix);

        gx_vals = galvo_xy(ic == p, 1);
        gx_mode = mode(sign(gx_vals));
        if gx_mode > 0; side = 'right'; elseif gx_mode < 0; side = 'left'; else; side = 'unknown'; end

        fprintf('  pos %d: mm=[%.2f %.2f]  pixel=[%d %d]  side=%s  (%d trials)\n', ...
            p, mm_xy, pix, side, sum(ic==p));

        rlo = max(1,pix(2)-k); rhi = min(size(mimg,1),pix(2)+k);
        clo = max(1,pix(1)-k); chi = min(size(mimg,2),pix(1)+k);
        weights      = reshape(mean(U(rlo:rhi,clo:chi,:),[1 2]), [1 nSV]);
        dFoF         = (weights * V) / mean(mimg(rlo:rhi,clo:chi),'all') * 100;

        pixels(p).mm   = mm_xy;
        pixels(p).pix  = pix;
        pixels(p).side = side;
        pixels(p).dFoF = dFoF;
    end

    save(cachePath, 'bregmaPix', 'pixels', '-v7.3');
    fprintf('Saved: %s\n', cachePath);
end

% Mark galvo pixels on mean image
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
colors = {'b','r','g','m','c'};
figure('Name','dFoF per galvo position','Units','centimeters','Position',[2 2 18 4*length(pixels)]);
for p = 1:length(pixels)
    n = min(length(t), length(pixels(p).dFoF));
    subplot(length(pixels),1,p);
    plot(t(1:n), pixels(p).dFoF(1:n), colors{mod(p-1,5)+1}, 'LineWidth',0.8); hold on;
    ylabel('\DeltaF/F (%)');
    plot(d.inpTime, d.inpVals,'k');
    title(sprintf('%s | mm=[%.2f %.2f] | pixel=[%d %d]', pixels(p).side, pixels(p).mm, pixels(p).pix));
end
xlabel('Time (s)');

%% ---- Comprehensive trial plots -----------------------------------------
% One figure per recording pixel (LEFT / RIGHT).
%   rows    = stim conditions: impulse amp1, impulse amp2, step amp1, step amp2
%   columns = which hemisphere was stimulated (left stim | right stim)
%   each panel overlays BOTH pixels: solid=recording pixel, dashed=other pixel

% ---- Parameters (set codes once you see them printed below) -------------
IMPULSE_CODE_P = NaN;   % e.g. 0   — trial_type code for impulse
STEP_CODE_P    = NaN;   % e.g. 1   — trial_type code for step

PRE_S       = 1.0;   % s before stim onset
POST_S      = 3.0;   % s after  stim onset
SHOW_TRIALS = true;  % overlay faint individual trials
COLOR_L     = [0.18 0.45 0.80];   % blue — left pixel
COLOR_R     = [0.85 0.20 0.20];   % red  — right pixel
% -------------------------------------------------------------------------
close all

fs    = 1 / mean(diff(t));
n_pre = round(PRE_S  * fs);
n_post= round(POST_S * fs);
t_ax  = (-n_pre : n_post) / fs;

galvo_x   = d.input_params(:, 8);   % >0=right stim, <0=left stim
types_all = d.input_params(:, 3);
amps_all  = d.input_params(:, 5);
kk_all    = d.input_params(:, 2);

% Print codes so user can fill IMPULSE_CODE_P / STEP_CODE_P
ucodes_p = unique(types_all);
fprintf('\n[Comprehensive plots] trial_type codes: %s\n', mat2str(ucodes_p'));

% Build type-name map
if ~isnan(IMPULSE_CODE_P) && ~isnan(STEP_CODE_P)
    type_map_p = containers.Map({IMPULSE_CODE_P, STEP_CODE_P}, {'impulse','step'});
else
    type_map_p = containers.Map(num2cell(ucodes_p), ...
        arrayfun(@(x) sprintf('type%g',x), ucodes_p, 'UniformOutput',false));
end

all_amps = sort(unique(amps_all))';

% Build ordered condition list (impulse first, step second; sorted amps within each)
pref_order = {'impulse','step'};
cond_type = {}; cond_code = []; cond_amp = [];
for oi = 1:length(pref_order)
    tn     = pref_order{oi};
    k_list = keys(type_map_p);
    for ki = 1:length(k_list)
        if strcmp(type_map_p(k_list{ki}), tn)
            for ai = 1:length(all_amps)
                cond_type{end+1} = tn;
                cond_code(end+1) = k_list{ki};
                cond_amp(end+1)  = all_amps(ai);
            end
        end
    end
end
% Fallback: auto-labelled types
if isempty(cond_type)
    for ki = 1:length(ucodes_p)
        tn = type_map_p(ucodes_p(ki));
        for ai = 1:length(all_amps)
            cond_type{end+1} = tn;
            cond_code(end+1) = ucodes_p(ki);
            cond_amp(end+1)  = all_amps(ai);
        end
    end
end

stim_sides = {'left','right'};
nCond      = length(cond_type);
nStimSides = 2;

% Grab left and right pixel dFoF once
left_idx  = find(strcmp({pixels.side},'left'),  1);
right_idx = find(strcmp({pixels.side},'right'), 1);
dFoF_L = []; dFoF_R = [];
if ~isempty(left_idx);  dFoF_L = pixels(left_idx).dFoF;  end
if ~isempty(right_idx); dFoF_R = pixels(right_idx).dFoF; end

if isempty(dFoF_L) && isempty(dFoF_R)
    fprintf('[Trial plots] No pixels found — skipping.\n');
else
    figure('Name','Comprehensive trial plots','Units','centimeters', ...
           'Position',[2 2 8*nStimSides 5*nCond]);

    for ci = 1:nCond
        type_name = cond_type{ci};
        type_code = cond_code(ci);
        amp_val   = cond_amp(ci);

        type_mask = (types_all == type_code);
        amp_mask  = abs(amps_all - amp_val) < 1e-6;

        for si = 1:nStimSides
            stim_side = stim_sides{si};
            if strcmp(stim_side,'left'); stim_mask = galvo_x < 0;
            else;                        stim_mask = galvo_x > 0;
            end
            trial_idx = find(stim_mask & type_mask & amp_mask);

            sp_idx = (ci-1)*nStimSides + si;
            subplot(nCond, nStimSides, sp_idx); hold on; box off;

            if isempty(trial_idx)
                title(sprintf('%s amp%g | stim %s\n(no trials)', ...
                    type_name, amp_val, stim_side), 'FontSize',6);
                xlim([t_ax(1) t_ax(end)]); continue;
            end

            % Plot each pixel
            pix_defs = {dFoF_L, COLOR_L, 'left'; dFoF_R, COLOR_R, 'right'};
            for px = 1:2
                dFoF_px  = pix_defs{px,1};
                col_px   = pix_defs{px,2};
                name_px  = pix_defs{px,3};
                if isempty(dFoF_px); continue; end

                mat = [];
                for jj = 1:length(trial_idx)
                    kk = round(kk_all(trial_idx(jj)));
                    if kk - n_pre < 1 || kk + n_post > length(dFoF_px); continue; end
                    mat(end+1,:) = dFoF_px(kk - n_pre : kk + n_post);
                end
                if isempty(mat); continue; end

                if SHOW_TRIALS
                    plot(t_ax, mat', 'Color', [col_px 0.12], 'LineWidth',0.4);
                end
                mn_p = mean(mat,1); sd_p = std(mat,0,1);
                patch([t_ax fliplr(t_ax)],[mn_p+sd_p fliplr(mn_p-sd_p)], ...
                      col_px,'FaceAlpha',0.20,'EdgeColor','none');
                plot(t_ax, mn_p, 'Color', col_px, 'LineWidth',1.5);
            end

            xline(0,'k:','LineWidth',0.8);
            % Capitalise type, spell out amplitude
            type_label = [upper(type_name(1)) type_name(2:end)];
            title(sprintf('%s  |  amp = %g  |  %s stim  (n=%d)', ...
                type_label, amp_val, stim_side, length(trial_idx)), ...
                'FontSize',6,'FontWeight','bold');
            if si == 1; ylabel('\DeltaF/F (%)','FontSize',6); end
            if ci == nCond; xlabel('Time (s)','FontSize',6); end
            xlim([t_ax(1) t_ax(end)]);
        end
    end

    sgtitle('Both pixels | rows: stim condition | cols: stim side', 'FontSize',8);
end

%% ---- Spatial brain map: trial-averaged dFoF overlaid on mimg -----------
% Full-screen figure. Background = mimg (gray). Overlay = mini peri-stim
% trial-average traces on a grid, masked to brain ROI. Midline drawn on top.
%
% Brain mask: drawn interactively with roipoly, cached to data/<mn>_brainmask.mat
% Midline:    loaded from midline.mat (run define_midline.m once to create)
close all;
% ---- Parameters ---------------------------------------------------------
r_mask    = 1;      % 0 = redraw mask | 1 = load cached mask
GRID_STEP = 40;     % pixels between grid centres
MINI_PRE  = 0.5;    % s before stim onset
MINI_POST = 2.0;    % s after  stim onset
MINI_SCALE = 8;     % image pixels per % dF/F (vertical scale)

% Conditions to overlay — one row per condition, each plotted in a different colour.
% Columns: { type_code,  stim_side ('left'|'right'),  [r g b],  label }
MAP_IMPULSE_CODE = 0;
MAP_STEP_CODE    = 1;
IC = MAP_IMPULSE_CODE; SC = MAP_STEP_CODE;  % shorthand

% Columns: { type_code, stim_side, amplitude (NaN=all), [r g b], label }
CONDITIONS = {
    % IC, 'left',  1,   [0.15 0.40 0.85], 'impulse left  amp1';
    % IC, 'left',  2,   [0.50 0.70 1.00], 'impulse left  amp2';
    % IC, 'right', 1,   [0.85 0.15 0.15], 'impulse right amp1';
    % IC, 'right', 2,   [1.00 0.55 0.55], 'impulse right amp2';
    % SC, 'left',  1,   [0.10 0.70 0.35], 'step left  amp1';
    % SC, 'left',  2,   [0.55 0.90 0.65], 'step left  amp2';
    % SC, 'right', 1,   [0.90 0.55 0.05], 'step right amp1';
    % SC, 'right', 2,   [1.00 0.80 0.40], 'step right amp2';
};
% To show fewer conditions, comment out unwanted rows above.
% -------------------------------------------------------------------------

[nRows, nCols] = size(mimg);
maskPath = fullfile('data', sprintf('%s_brainmask.mat', mn));

% --- Brain mask (roipoly, cached) ----------------------------------------
if exist(maskPath,'file') && r_mask == 1
    bm = load(maskPath); brain_mask = bm.brain_mask;
    fprintf('[Brain map] Loaded brain mask.\n');
else
    figure('Name','Draw brain mask — double-click to close polygon','Color','k');
    imagesc(mimg); colormap gray; axis image off;
    clim([prctile(mimg(:),2) prctile(mimg(:),98)]);
    title('Draw brain outline — double-click to close','Color','w','FontSize',10);
    brain_mask = roipoly();
    close;
    save(maskPath, 'brain_mask');
    fprintf('[Brain map] Brain mask saved.\n');
end

% --- Input params ----------------------------------------------------------
kk_m    = d.input_params(:, 2);
types_m = d.input_params(:, 3);
gx_m    = d.input_params(:, 8);
nConds  = size(CONDITIONS, 1);

% --- Build grid, skip non-brain points ------------------------------------
try; kk_kern = double(d.params.kernel); catch; kk_kern = 10; end

grid_rows = round(GRID_STEP/2) : GRID_STEP : nRows;
grid_cols = round(GRID_STEP/2) : GRID_STEP : nCols;

valid_pts = [];   % [row col]
W_all     = [];   % nValid × nSV weight matrix

for ri = 1:length(grid_rows)
    for ci_g = 1:length(grid_cols)
        row_g = grid_rows(ri);
        col_g = grid_cols(ci_g);
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

% --- Batch SVD dFoF + trial average via eventLockedAvgSVD ----------------
% Build a fake U_grid: one "pixel" per grid point (1×1×nSV)
% Instead, directly use W_all * V then call event locking manually — cleaner.
dFoF_grid = W_all * V;   % nValid × nTime

calc_win = [-MINI_PRE, MINI_POST];
% Use eventLockedAvgSVD with a synthetic 1-SV U to get trial averages per point
% — simpler: do it directly since we already have dFoF_grid
fs_m   = 1 / mean(diff(t));
np_m   = round(MINI_PRE  * fs_m);
npo_m  = round(MINI_POST * fs_m);
nT     = np_m + npo_m + 1;
t_mini = (-np_m:npo_m) / fs_m;
t_span = MINI_PRE + MINI_POST;

% --- Trial average per condition ------------------------------------------
% mn_cond: nConds × nValid × nT
mn_cond = nan(nConds, size(valid_pts,1), nT);
amps_m = d.input_params(:, 5);
for ci = 1:nConds
    type_code = CONDITIONS{ci,1};
    stim_side = CONDITIONS{ci,2};
    amp_val   = CONDITIONS{ci,3};
    if strcmp(stim_side,'left');  side_mask = gx_m < 0;
    else;                          side_mask = gx_m > 0;
    end
    amp_mask = true(size(kk_m));
    if ~isnan(amp_val); amp_mask = abs(amps_m - amp_val) < 1e-6; end
    sel    = (types_m == type_code) & side_mask & amp_mask;
    kk_sel = round(kk_m(sel));
    fprintf('[Brain map] Cond %d (%s): %d trials\n', ci, CONDITIONS{ci,5}, sum(sel));
    for vi = 1:size(valid_pts,1)
        tr = [];
        for jj = 1:length(kk_sel)
            k0 = kk_sel(jj);
            if k0 - np_m < 1 || k0 + npo_m > size(dFoF_grid,2); continue; end
            tr(end+1,:) = dFoF_grid(vi, k0-np_m : k0+npo_m);
        end
        if isempty(tr); continue; end
        bl = mean(tr(:, t_mini < 0), 2);
        tr = tr - bl;
        mn_cond(ci,vi,:) = mean(tr,1);
    end
end

% --- Draw -----------------------------------------------------------------
figure('Name','Brain map','Units','normalized','Position',[0 0 1 1]);
ax = axes; hold(ax,'on');
imagesc(ax, flipud(mimg));
colormap(ax, gray);
clim(ax, [prctile(mimg(:),2) prctile(mimg(:),98)]);
axis(ax,'image','off');
set(ax,'Color','k');

half_w = GRID_STEP * 0.9 / 2;
x_onset_frac = MINI_PRE / t_span;

for vi = 1:size(valid_pts,1)
    row_g = valid_pts(vi,1);
    col_g = valid_pts(vi,2);
    y_ctr = nRows + 1 - row_g;
    x_pl  = col_g - half_w + (t_mini - t_mini(1)) / t_span * half_w * 2;
    % shared baseline + onset markers (drawn once per grid point)
    plot(ax, x_pl([1 end]), [y_ctr y_ctr], 'Color',[1 1 1 0.15], 'LineWidth',0.3);
    x_on = col_g - half_w + x_onset_frac * half_w * 2;
    plot(ax, [x_on x_on], [y_ctr-2 y_ctr+2], 'Color',[1 1 0 0.5], 'LineWidth',0.5);
    % one trace per condition
    for ci = 1:nConds
        mn_vi = squeeze(mn_cond(ci, vi, :))';
        if all(isnan(mn_vi)); continue; end
        y_pl = y_ctr + mn_vi * MINI_SCALE;  % + because flipud flips biological y
        plot(ax, x_pl, y_pl, 'Color', CONDITIONS{ci,4}, 'LineWidth', 0.8);
    end
end



% --- Midline: vertical line at bregma x (bregmaPix(1) = midline by definition) ---
plot(ax, [bregmaPix(1) bregmaPix(1)], [1 nRows], 'w--', 'LineWidth', 1.0);

% --- Scale bars (top-right in flipped display = low row = high y_disp) ---
sb_col   = nCols - 4*GRID_STEP;
sb_row_d = 2*GRID_STEP;            % display y near top of image
sb_dff   = 5;
plot(ax,[sb_col sb_col],[sb_row_d sb_row_d-sb_dff*MINI_SCALE],'w-','LineWidth',1.5);
text(ax, sb_col+3, sb_row_d-sb_dff*MINI_SCALE/2, sprintf('%g%% dF/F',sb_dff), ...
     'Color','w','FontSize',7,'VerticalAlignment','middle');
sb_t = 1;
x_sb = sb_col + round(1.5*GRID_STEP);
plot(ax,[x_sb x_sb+(sb_t/t_span)*half_w*2],[sb_row_d sb_row_d],'w-','LineWidth',1.5);
text(ax, x_sb, sb_row_d+8, sprintf('%g s',sb_t), ...
     'Color','w','FontSize',7,'HorizontalAlignment','left');

title(ax, sprintf('Brain map  |  %d conditions  |  scale: %g px/%%dF/F', ...
    nConds, MINI_SCALE), 'FontSize',8,'Color','w');

%% Print line to paste into load_bilateral.m sessions_def
left_idx  = find(strcmp({pixels.side},'left'),  1);
right_idx = find(strcmp({pixels.side},'right'), 1);
pix_L = [NaN NaN]; pix_R = [NaN NaN];
if ~isempty(left_idx);  pix_L = pixels(left_idx).pix;  end
if ~isempty(right_idx); pix_R = pixels(right_idx).pix; end
fprintf('\n%% Paste into sessions_def:\n');
fprintf("  '%s', '%s',  %d,  NaN,  [%d %d],  [%d %d];\n", ...
    mn, td, en, pix_L(1), pix_L(2), pix_R(1), pix_R(2));


%% ---- Pixel viewer -------------------------------------------------------
close all
% ---- Selection parameters -----------------------------------------------
SHOW_IMPULSE  = false;             % include impulse trials
SHOW_STEP     = true;            % include step trials
STIM_SIDES    = { 'left'};         % stim hemisphere filter; e.g. {'left','right'} for both
CALC_WIN      = [-1 4];           % (s) peri-event window

% SET THESE — run once to see unique codes printed below, then fill in
IMPULSE_CODE  = 0;   % trial_type code for impulse
STEP_CODE     = 1;   % trial_type code for step
% -------------------------------------------------------------------------

kk_all    = d.input_params(:, 2);
types_all = d.input_params(:, 3);
amps_all  = d.input_params(:, 5);
galvo_x   = d.input_params(:, 8);

valid = kk_all >= 1 & kk_all <= length(t);
kk_all(~valid) = []; types_all(~valid) = []; amps_all(~valid) = []; galvo_x(~valid) = [];

% Print codes so user can fill in IMPULSE_CODE / STEP_CODE
ucodes = unique(types_all);
fprintf('\ntrial_type codes in data: %s\n', mat2str(ucodes'));
if isnan(IMPULSE_CODE) || isnan(STEP_CODE)
    fprintf('>>> Set IMPULSE_CODE and STEP_CODE above, then rerun this section.\n');
    return;
end

type_map = containers.Map({IMPULSE_CODE, STEP_CODE}, {'impulse','step'});

% Build event list
ev_times  = [];
ev_labels = {};

for ii = 1:length(kk_all)
    if galvo_x(ii) > 0; stim_side = 'right';
    elseif galvo_x(ii) < 0; stim_side = 'left';
    else; stim_side = 'unknown';
    end

    if ~ismember(stim_side, STIM_SIDES); continue; end

    code = types_all(ii);
    if ~isKey(type_map, code); continue; end
    type_name = type_map(code);

    if strcmp(type_name,'impulse') && ~SHOW_IMPULSE; continue; end
    if strcmp(type_name,'step')    && ~SHOW_STEP;    continue; end

    ev_times(end+1)  = t(kk_all(ii));
    ev_labels{end+1} = sprintf('%s %s amp%g', type_name, stim_side, amps_all(ii));
end

if isempty(ev_times)
    fprintf('No events matched selection.\n');
else
    fprintf('Launching viewer — %d events | %s\n', numel(ev_times), strjoin(unique(ev_labels),' | '));
    pixelTuningCurveViewerSVD(U, V, t(:)', ev_times, ev_labels, CALC_WIN);
end
