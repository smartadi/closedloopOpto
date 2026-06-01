% impulse-analysis -- extracted from Impulse_mouseDataAnalysis_all.m
% Run from impulse-analysis/ directory.
% Requires: load_experiments.m has been run first (allExperiments, selExp, t_win).

PS = paperStyle();
setPaperDefaults();

%% Spatial spread vs amplitude

pxMM      = 0.173;    % mm per pixel
selExp_sp = 3;        % session to analyse (change here; does not require selExp in workspace)

uA_sp       = allExperiments(selExp_sp).uAmp(:);
imp_s       = allExperiments(selExp_sp).imp;
mimg_s      = allExperiments(selExp_sp).mimg;
brainMask   = allExperiments(selExp_sp).brainMask;
mI1_s       = allExperiments(selExp_sp).mI1;
nAmp_sp     = numel(uA_sp);
validAmp_sp = uA_sp > 0;
validIdx_sp = find(validAmp_sp);
nV_sp       = numel(validIdx_sp);

nr_s = size(mimg_s, 1);   nc_s = size(mimg_s, 2);

% Stack resp and baseline maps across valid amplitudes
resp_maps = zeros(sum(brainMask), nV_sp);
base_maps = zeros(sum(brainMask), nV_sp);
for k = 1:nV_sp
    iA = validIdx_sp(k);
    resp_maps(:, k) = imp_s.resp_map{iA};
    base_maps(:, k) = imp_s.base_map{iA};
end

% Global threshold: 50% of the strongest inhibition across ALL amplitudes.
% Using per-amplitude FWHM inverts the ordering (small amps get a very
% permissive threshold, counting noise as spread -> spuriously large area).
% A single shared threshold fixes this: small amps that never reach it
% give near-zero area, and area grows monotonically with amplitude.
global_thr_sp = 0.5 * min(resp_maps(:));   % most negative dF/F across all amps, halved
fprintf('Global threshold: %.4f dF/F%%  (50%% of strongest peak)\n', global_thr_sp);

spread_area = nan(nAmp_sp, 1);
for k = 1:nV_sp
    iA = validIdx_sp(k);
    map_k = resp_maps(:, k);
    n_px = sum(map_k < global_thr_sp);
    spread_area(iA) = n_px * pxMM^2;
    fprintf('  amp=%.2f mW  peak=%.3f%%dF/F  area=%.2f mm2\n', ...
        uA_sp(iA) * (1.8/4.9), min(map_k), spread_area(iA));
end

% â”€â”€ Figure: amplitude vs inhibition area â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
vToMW_sp  = 1.8 / 4.9;   % calibration: 0 V = 0 mW, 4.9 V = 1.8 mW
xAmp_sp   = uA_sp(validAmp_sp) * vToMW_sp;
yArea_sp  = spread_area(validAmp_sp);

fig_sp = paperFig(6, 4);
ax_sp  = axes(fig_sp);
plot(ax_sp, xAmp_sp, yArea_sp, 'o-', ...
    'Color', [0.15 0.35 0.8], 'MarkerFaceColor', [0.15 0.35 0.8], ...
    'MarkerSize', 4, 'LineWidth', 1.5);
xlabel(ax_sp, 'Amplitude (mW)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_sp, 'Inhibition area (mm^2)', 'FontSize', 6, 'FontWeight', 'bold');
set(ax_sp, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

mn_sp = allExperiments(selExp_sp).mn;
td_sp = allExperiments(selExp_sp).td;
en_sp = allExperiments(selExp_sp).en;
paperExport(fig_sp, ...
    fullfile(paperRoot, 'images', 'figure2', sprintf('spatial_spread_%s_%s_en%d.png', mn_sp, td_sp, en_sp)));
