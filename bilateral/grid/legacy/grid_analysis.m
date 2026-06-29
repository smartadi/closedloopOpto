%% grid_analysis.m  —  MATLAB port of scratch_grid/2025-10-29_AL41_grid.ipynb
% Galvo photostim SITE-GRID mapping (AL_0041): per-site dF/F timecourses laid out
% on an 8x8 grid, an exponential-rise tau fit per site, and a tau spatial map.
%
% Ports the notebook's ANALYSIS cells only; the exploration / "probe" cells are
% intentionally dropped:
%   - ipywidgets time-slider viewer (cell 6) + single-site probe (cells 4-5)
%   - rastermap import (unused)
%   - mp4 animation export (cells 8-9)
%   - widefield_deconv `deconvolve` (computed in the notebook but unused downstream)
%   - multi-session os.walk aggregation + .npy round-trip (cells 14-16) -> single session
%
% Reuses repo helpers: readUfromNPY / readVfromNPY / readNPY (utils/), paperFig/paperStyle,
% and getpixels_dFoF's "mean U over ROI, project onto V" idiom for dF/F.
% Run section-by-section in MATLAB. *** Set `bregma` from the Fig 0 sanity check first. ***

clear; clc;

%% ---- knobs -------------------------------------------------------------
mn = 'AL_0041'; td = '2026-02-17'; en = '1';
serverRoot = sprintf('\\\\sahale.biostr.washington.edu\\data\\Subjects\\%s\\%s\\%s', mn, td, en);
% If the share is mapped to a drive instead, e.g.:
%   serverRoot = sprintf('Z:\\Subjects\\%s\\%s\\%s', mn, td, en);

nSV     = 50;          % SVD components (notebook n_comps = 50)
expIdx  = 1;           % which expStartStop row is the grid block (notebook ess[0])
ampSel  = 4;           % laser power (mW) for timecourse + tau figs (notebook amp = 4)
roi_rad = 10;          % ROI half-width (px) around each stim site (notebook roi_around)

xscale  =  57.8;       % px per mm (notebook)
yscale  = -57.8;       % px per mm, y inverted for image coords
bregma  = [325 245];   % [x y] px  <-- *** SET PER SESSION *** (verify with Fig 0!)
% NB: the notebook recorded no bregma for 2026-02-17; [325 245] is just the last
%     value it used (2025-11-21). Nudge it until the Fig 0 markers sit on the stim
%     sites in the mean image.

% trial window (notebook: arange(0,1.5,1/70) - 12/35), seconds relative to onset
fs_win    = 70;                                            % within-window resample rate (Hz)
win_pre   = 12/35;                                         % baseline lead before onset (s)
win_dur   = 1.5;                                           % total window length (s)
window_wf = (0:ceil(win_dur*fs_win)-1)/fs_win - win_pre;   % 1 x nWin
base_ix   = find(window_wf < 0, 1, 'last');               % last pre-onset sample
tau_t0_ix = 32;                                            % first sample for exp-rise fit (notebook start_ix)

EXPORT  = true;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
outDir  = fullfile(thisDir, 'grid_png');
addpath(genpath(fullfile(thisDir, '..', 'utils')));
if EXPORT && ~exist(outDir,'dir'); mkdir(outDir); end

%% ---- load session ------------------------------------------------------
gx  = round(squeeze(readNPY(fullfile(serverRoot,'galvoXPositions_mm.npy')))*2)/2;
gy  = round(squeeze(readNPY(fullfile(serverRoot,'galvoYPositions_mm.npy')))*2)/2;
amp = round(squeeze(readNPY(fullfile(serverRoot,'laserPowers_mW.npy'))), 1);
onT = squeeze(readNPY(fullfile(serverRoot,'laserOnTimes.npy')));

% restrict to the grid-experiment window (notebook ess[0])
ess = squeeze(readNPY(fullfile(serverRoot,'expStartStopTimes.npy')));
if size(ess,2) ~= 2, ess = reshape(ess, 2, []).'; end     % robust to flat [start stop] layout
gw  = ess(expIdx, :);
tr  = find(onT >= gw(1) & onT <= gw(2));
gx = gx(tr); gy = gy(tr); amp = amp(tr); onT = onT(tr);

% SVD: U from blue, V from corr (same source as package_grid_for_collab.m)
U    = readUfromNPY(fullfile(serverRoot,'blue','svdSpatialComponents.npy'), nSV);          % [Y X nSV]
V    = readVfromNPY(fullfile(serverRoot,'corr','svdTemporalComponents_corr.npy'), nSV);    % [nSV T]
mimg = readNPY(fullfile(serverRoot,'blue','meanImage.npy'));
svdT = double(readNPY(fullfile(serverRoot,'corr','svdTemporalComponents_corr.timestamps.npy'))); svdT = svdT(:);

nF   = min(numel(svdT), size(V,2));
svdT = svdT(1:nF);
Vt   = V(:, 1:nF).';          % [T x nSV]  == python svdTemp[:, :nSV]

% unique sites + grid<->mm<->pixel maps (notebook cell 3)
positions_all = [gx gy];
positions_mm  = unique(positions_all, 'rows');            % lexicographic, matches np.unique(axis=0)
nPos          = size(positions_mm, 1);
xy_pos_px     = [bregma(1) + positions_mm(:,1)*xscale, bregma(2) + positions_mm(:,2)*yscale];

% subplot row/col per site (notebook pos_ix), 0-based, clipped to the 8x8 grid
nrow = 8; ncol = 8;
pos_row = min(max(round(-positions_mm(:,2) + 3  ), 0), nrow-1);
pos_col = min(max(round( positions_mm(:,1) + 3.5), 0), ncol-1);

fprintf('%s %s/%s : %d trials in grid window, %d unique sites, powers = %s mW\n', ...
    mn, td, en, numel(onT), nPos, num2str(unique(amp).'));

%% ---- Fig 0: bregma / site sanity check (notebook cell 7) ---------------
f0 = figure('Color','w','Name','site overlay');
imagesc(mimg); colormap(gca,'gray'); axis image off; hold on;
scatter(bregma(1), bregma(2), 40, 'm', 'LineWidth', 1);
scatter(xy_pos_px(:,1), xy_pos_px(:,2), 18, 'r', 'filled', 'MarkerFaceAlpha', 0.4);
title(sprintf('%s %s - verify bregma / sites', mn, td), 'Interpreter','none');
if EXPORT, exportgraphics(f0, fullfile(outDir, sprintf('grid_sites_%s_%s.png', mn, td)), 'Resolution',300); end

%% ---- per-site dF/F timecourses @ ampSel (notebook cell 14) -------------
nWin        = numel(window_wf);
dff_by_pos  = cell(nPos,1);          % each: [nTrials x nWin]
mean_by_pos = nan(nPos, nWin);

f1 = figure('Color','w','Name','site timecourses');
tl = tiledlayout(nrow, ncol, 'TileSpacing','compact', 'Padding','compact');
for iP = 1:nPos
    sel   = positions_all(:,1)==positions_mm(iP,1) & ...
            positions_all(:,2)==positions_mm(iP,2) & amp==ampSel;
    these = onT(sel);

    ax = nexttile(tl, pos_row(iP)*ncol + pos_col(iP) + 1);
    if isempty(these); axis(ax,'off'); continue; end

    % ROI spatial weights = mean of U over the site ROI (getpixels_dFoF idiom)
    cx = xy_pos_px(iP,1); cy = xy_pos_px(iP,2);
    xr = min(max(round([cx-roi_rad, cx+roi_rad]), 1), size(U,2));
    yr = min(max(round([cy-roi_rad, cy+roi_rad]), 1), size(U,1));
    thisSpat = squeeze(mean(U(yr(1):yr(2), xr(1):xr(2), :), [1 2]));   % [nSV x 1]
    mI       = mean(mimg(yr(1):yr(2), xr(1):xr(2)), 'all');            % absolute-F offset

    % per-trial fluorescence: interpolate V onto each trial window, project onto ROI
    fluo = nan(numel(these), nWin);
    for k = 1:numel(these)
        Vq        = interp1(svdT, Vt, window_wf + these(k));           % [nWin x nSV]
        fluo(k,:) = Vq * thisSpat + mI;
    end
    base = mean(fluo(:, 1:base_ix), 'all');                           % pre-stim baseline (scalar)
    dff  = (fluo - base) / base;                                      % fractional dF/F
    dff_by_pos{iP}    = dff;
    trMean            = median(dff, 1, 'omitnan');
    trSem             = std(dff, 0, 1, 'omitnan') ./ sqrt(size(dff,1));
    mean_by_pos(iP,:) = trMean;

    fill(ax, [window_wf fliplr(window_wf)], [trMean-trSem fliplr(trMean+trSem)], ...
        [0.12 0.56 1], 'EdgeColor','none', 'FaceAlpha',0.3); hold(ax,'on');
    plot(ax, window_wf, trMean, 'Color',[0.12 0.56 1], 'LineWidth',0.5);
    yline(ax, 0, '--k', 'LineWidth',0.5);
    xlim(ax, [window_wf(1) window_wf(end)]); ylim(ax, [-0.03 0.03]);
    axis(ax,'off');
end
title(tl, sprintf('%s %s - dF/F per site @ %g mW', mn, td, ampSel), 'Interpreter','none');
if EXPORT, exportgraphics(f1, fullfile(outDir, sprintf('grid_timecourses_%s_%s.png', mn, td)), 'Resolution',300); end

%% ---- exponential-rise tau fit per site (notebook cell 17) --------------
exp_rise = @(p,t) p(1)*(1 - exp(-t/p(2))) + p(3);   % p = [A tau offset]
tf   = window_wf(tau_t0_ix:end);
p0   = [0.02 0.1 0];  lb = [0 0 -Inf];  ub = [0.1 0.5 Inf];
opts = optimoptions('lsqcurvefit','Display','off');

taus = nan(nPos,1);
for iP = 1:nPos
    if all(isnan(mean_by_pos(iP,:))); continue; end
    y = mean_by_pos(iP, tau_t0_ix:end);
    try
        p = lsqcurvefit(exp_rise, p0, tf, y, lb, ub, opts);
        taus(iP) = p(2);
    catch
        taus(iP) = NaN;
    end
end

%% ---- tau spatial map (notebook cell 18) -------------------------------
f2 = figure('Color','w','Name','tau map'); ax = axes(f2); hold(ax,'on'); axis(ax,'equal');
ctxFile = fullfile(thisDir,'..','data','ctxOutlines.mat');   % optional cortical outline
if exist(ctxFile,'file')
    S = load(ctxFile); coords = S.coords;
    for j = 1:numel(coords)
        plot(ax, double(coords(j).x)/100 - 5.7, double(coords(j).y)/-100 + 5.2, ...
            'Color',[0.8 0.8 0.8], 'LineWidth',0.5);
    end
end
scatter(ax, positions_mm(:,1), positions_mm(:,2), 60, taus, 'filled', 'MarkerEdgeColor','k');
colormap(ax, parula); set(ax,'CLim',[0 0.1]); axis(ax,'off');
cb = colorbar(ax); cb.Label.String = '\tau (s)';
title(ax, sprintf('%s %s - rise \\tau @ %g mW', mn, td, ampSel), 'Interpreter','none');
if EXPORT, exportgraphics(f2, fullfile(outDir, sprintf('grid_tau_%s_%s.png', mn, td)), 'Resolution',300); end
