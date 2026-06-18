% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments).
%
% Shows raw mean response maps (peak - baseline dF/F%) per amplitude.
% Quantitative area is not computed: mean resp_maps contain a large global
% hemodynamic component that cannot be separated from local inhibition via
% thresholding. The maps are exported as a qualitative illustration.
close all;
pxMM      = 0.173;    % mm per pixel
selExp_sp = 3;

uA_sp       = allExperiments(selExp_sp).uAmp(:);
imp_s       = allExperiments(selExp_sp).imp;
mimg_s      = allExperiments(selExp_sp).mimg;
brainMask   = allExperiments(selExp_sp).brainMask;
validAmp_sp = uA_sp > 0;
validIdx_sp = find(validAmp_sp);
nV_sp       = numel(validIdx_sp);
vToMW_sp    = 1.8 / 4.9;

nr_s = size(mimg_s, 1);   nc_s = size(mimg_s, 2);

% Stack resp maps
resp_maps = zeros(sum(brainMask), nV_sp);
for k = 1:nV_sp
    resp_maps(:, k) = imp_s.resp_map{validIdx_sp(k)};
end

% Peak pixel from strongest amplitude
[~, iStrongest] = min(cellfun(@min, imp_s.resp_map(validIdx_sp)));
iA_strong = validIdx_sp(iStrongest);
resp_strong_full = nan(nr_s * nc_s, 1);
resp_strong_full(brainMask(:)) = imp_s.resp_map{iA_strong};
resp_strong_full = reshape(resp_strong_full, nr_s, nc_s);
[pr_pk, pc_pk] = find(resp_strong_full == min(resp_strong_full(:)), 1);

% ── Amplitude vs inhibition area ─────────────────────────────────────────
% Background subtraction: per-amplitude mean of an annulus (6–9 mm from peak)
% removes the global hemodynamic offset. Fixed threshold = 5th percentile of
% the background-subtracted strongest-amplitude map, applied to all amplitudes.
[all_rows_sp, all_cols_sp] = ind2sub([nr_s nc_s], find(brainMask(:)));
dist_sp  = sqrt((all_rows_sp - pr_pk).^2 + (all_cols_sp - pc_pk).^2) * pxMM;
ann_mask = dist_sp >= 6 & dist_sp <= 9;

% Calibrate threshold from the strongest amplitude's local zone (within 2 mm).
% Using the whole-brain percentile fails because the background annulus is
% itself inhibited, making most bg-subtracted pixels positive.
map_str    = resp_maps(:, iStrongest);
bg_str     = mean(map_str(ann_mask));
local_mask = dist_sp <= 2;   % pixels within 2 mm of peak
fixed_thr  = 0.5 * median(map_str(local_mask) - bg_str);   % 50% of local median
fprintf('Fixed threshold (50%% of local median, strongest amp): %.4f%%\n', fixed_thr);

spread_area = nan(numel(uA_sp), 1);
for k = 1:nV_sp
    iA   = validIdx_sp(k);
    mk   = resp_maps(:, k);
    bg   = mean(mk(ann_mask));
    npx  = sum(mk - bg < fixed_thr);
    spread_area(iA) = npx * pxMM^2;
    fprintf('  %.2f mW  bg=%.3f  n_px=%d  area=%.2f mm2\n', ...
        uA_sp(iA)*(1.8/4.9), bg, npx, spread_area(iA));
end

PS = paperStyle();
setPaperDefaults();
fig_sp = paperFig(6, 4);
ax_sp  = axes(fig_sp);
plot(ax_sp, uA_sp(validAmp_sp)*(1.8/4.9), spread_area(validAmp_sp), 'o-', ...
    'Color',[0.15 0.35 0.8], 'MarkerFaceColor',[0.15 0.35 0.8], ...
    'MarkerSize',4, 'LineWidth',1.5);
xlabel(ax_sp, 'Amplitude (mW)', 'FontSize',6, 'FontWeight','bold');
ylabel(ax_sp, 'Inhibition area (mm^2)', 'FontSize',6, 'FontWeight','bold');
set(ax_sp, 'Box','off', 'TickDir','out', 'FontSize',6, 'FontWeight','bold');

% Shared colour axis across all amplitudes
clim_val = [min(resp_maps(:)), 0];

mn_sp = allExperiments(selExp_sp).mn;
td_sp = allExperiments(selExp_sp).td;
en_sp = allExperiments(selExp_sp).en;

nCols_map = min(nV_sp, 4);
nRows_map = ceil(nV_sp / nCols_map);
fig_map = figure('Color','w','Name','Spatial inhibition maps', ...
    'Position',[50 50 300*nCols_map 280*nRows_map]);
tlo_map = tiledlayout(fig_map, nRows_map, nCols_map, ...
    'TileSpacing','compact','Padding','compact');
title(tlo_map, sprintf('%s %s en%d — mean response map (dF/F%%)', mn_sp, td_sp, en_sp), ...
    'FontWeight','bold','FontSize',9,'Interpreter','none');

for k = 1:nV_sp
    iA   = validIdx_sp(k);
    full = nan(nr_s * nc_s, 1);
    full(brainMask(:)) = resp_maps(:, k);
    full = reshape(full, nr_s, nc_s);

    ax_m = nexttile(tlo_map);
    imagesc(ax_m, full.', clim_val);   % transposed brain orientation
    colormap(ax_m, 'jet');
    hold(ax_m, 'on');
    plot(ax_m, pr_pk, pc_pk, 'w+', 'MarkerSize', 8, 'LineWidth', 2);   % swap coords for transpose
    axis(ax_m, 'image', 'off');
    title(ax_m, sprintf('%.2f mW', uA_sp(iA) * vToMW_sp), 'FontSize', 8, 'FontWeight', 'bold');
end

% Shared colorbar on last tile
cb = colorbar(nexttile(tlo_map, nV_sp));
cb.Label.String = 'dF/F (%)';
cb.FontSize = 7;

if ~exist(fullfile(paperRoot, 'images', 'supplementary'), 'dir')
    mkdir(fullfile(paperRoot, 'images', 'supplementary'));
end
paperExport(fig_map, ...
    fullfile(paperRoot, 'images', 'supplementary', sprintf('spatial_maps_%s_%s_en%d.pdf', mn_sp, td_sp, en_sp)));
paperExport(fig_sp, ...
    fullfile(paperRoot, 'images', 'supplementary', sprintf('spatial_spread_%s_%s_en%d.pdf', mn_sp, td_sp, en_sp)));
