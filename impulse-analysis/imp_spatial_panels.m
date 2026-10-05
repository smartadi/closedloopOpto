% impulse-analysis/imp_spatial_panels.m
% ============================================================================
% PAPER PANELS -- spatial footprint of the optogenetic suppression.
%
% Supersedes the figure-drawing half of spatial_spread.m (which stays as the
% exploratory version). Two panels, both convention-compliant:
%
%   imp_spatial_maps.pdf    3x3 grid of per-amplitude mean response maps,
%                           brain-masked, blue-white-red diverging, cropped to
%                           the brain, shared colour axis, one scale bar.
%   imp_spatial_area.pdf    inhibition area vs amplitude, small.
%
% Conventions: paperFig sizing, 6 pt bold, paperExport (vector PDF), symmetric
% diverging colour axis so 0 = white, suppression = blue, facilitation = red.
%
% Pixel scale is 0.0173 mm/px (rig: 57.8 px/mm; Matveev et al. 2024 state
% 17.3 um/pixel). The 0.173 used before 2026-09-30 was a factor-of-ten error.
%
% Requires: load_experiments.m has been run (allExperiments in the workspace).
% ============================================================================

PX_MM   = 0.0173;          % mm per pixel
V_TO_MW = 1.8 / 4.9;       % command volts -> mW
SEL     = 3;               % AL_0033 2025-01-29 e1
ROI_HALF = 5;              % readout kernel half-width, px (rig ROI_HALF)

if ~exist('allExperiments', 'var')
    error('allExperiments not found -- run load_experiments.m first');
end
if ~exist('paperRoot', 'var') || isempty(paperRoot)
    paperRoot = fullfile(fileparts(which('load_experiments')), '..', 'paper');
end
outDir = fullfile(paperRoot, 'images', 'supplementary');
if ~exist(outDir, 'dir'); mkdir(outDir); end

ae    = allExperiments(SEL);
uA    = ae.uAmp(:);
imp   = ae.imp;
mimg  = ae.mimg;
bmask = ae.brainMask;
[nr, nc] = size(mimg);

validIdx = find(uA > 0);
nV       = numel(validIdx);

% ---- stack response maps into full frames (NaN outside the brain) ----------
maps = nan(nr, nc, nV);
for k = 1:nV
    f = nan(nr * nc, 1);
    f(bmask(:)) = imp.resp_map{validIdx(k)};
    maps(:, :, k) = reshape(f, nr, nc);
end

% ---- peak of the strongest amplitude --------------------------------------
[~, iStrong] = min(cellfun(@min, imp.resp_map(validIdx)));
strongMap    = maps(:, :, iStrong);
[pr, pc]     = find(strongMap == min(strongMap(:)), 1);

% ---- crop to the brain bounding box (this is the whitespace removal) -------
bm2  = reshape(bmask, nr, nc);
rows = find(any(bm2, 2));  cols = find(any(bm2, 1));
r0 = max(1, min(rows)); r1 = min(nr, max(rows));
c0 = max(1, min(cols)); c1 = min(nc, max(cols));
maps = maps(r0:r1, c0:c1, :);
prc  = pr - r0 + 1;  pcc = pc - c0 + 1;

% Display orientation: transpose so anterior is up and the hemispheres sit
% side by side, matching the orientation used in the previous version.
maps = permute(maps, [2 1 3]);
tmp  = prc;  prc = pcc;  pcc = tmp;

% ---- symmetric diverging colour axis, 0 = white ---------------------------
lim  = prctile(abs(maps(~isnan(maps))), 99.5);
clim = [-lim, lim];

% blue -> white -> red (project house diverging map)
n  = 256;
t  = linspace(0, 1, n/2)';
lo = [linspace(0.13,1,n/2)', linspace(0.25,1,n/2)', linspace(0.60,1,n/2)'];
hi = [ones(n/2,1), linspace(1,0.25,n/2)', linspace(1,0.17,n/2)'];
cmapBWR = [lo; hi];

% ============================== PANEL: MAPS =================================
nCols = 3;  nRows = ceil(nV / nCols);          % 9 amplitudes -> 3 x 3
figM = paperFig(8.5, 8.9);
tl   = tiledlayout(figM, nRows, nCols, 'TileSpacing','none', 'Padding','compact');

for k = 1:nV
    ax = nexttile(tl);
    img = maps(:, :, k);
    im = imagesc(ax, img, clim);
    im.AlphaData = ~isnan(img);                 % brain mask -> white outside
    colormap(ax, cmapBWR);
    axis(ax, 'image', 'off');
    hold(ax, 'on');

    % readout kernel (10 x 10 px) and stimulation peak
    rectangle(ax, 'Position', [pcc-ROI_HALF, prc-ROI_HALF, 2*ROI_HALF, 2*ROI_HALF], ...
        'EdgeColor', [0 0 0], 'LineWidth', 0.6);

    text(ax, 0.03, 0.97, sprintf('%.2f mW', uA(validIdx(k)) * V_TO_MW), ...
        'Units','normalized', 'VerticalAlignment','top', ...
        'FontSize', 6, 'FontWeight','bold');

    % scale bar on the first tile only: 1 mm
    if k == 1
        barPx = 1 / PX_MM;
        xl = xlim(ax); yl = ylim(ax);
        x0 = xl(1) + 0.06*diff(xl);  y0 = yl(2) - 0.08*diff(yl);
        plot(ax, [x0, x0+barPx], [y0, y0], 'k-', 'LineWidth', 1.2);
        text(ax, x0 + barPx/2, y0 - 0.045*diff(yl), '1 mm', ...
            'HorizontalAlignment','center', 'FontSize', 6, 'FontWeight','bold');
    end
    hold(ax, 'off');
end

cb = colorbar(nexttile(tl, nV));
cb.Layout.Tile    = 'east';
cb.Label.String   = '\DeltaF/F (%)';
cb.FontSize       = 6;
cb.Label.FontSize = 6;
cb.Label.FontWeight = 'bold';
set(cb, 'FontWeight', 'bold', 'Box', 'off', 'TickDirection', 'out');

paperExport(figM, fullfile(outDir, 'imp_spatial_maps.pdf'));

% ===================== PANELS: ONE MAP PER AMPLITUDE ========================
% Supplementary figures are assembled in Illustrator from individual panels, not
% stitched in LaTeX or montaged here (user, 2026-10-05). The montage above is kept
% as a working-dir contact sheet; THESE are the panels that get pulled.
%
% Two things change when a tiled montage becomes separate panels, and both are
% easy to get wrong:
%   1. THE COLOURBAR MUST BECOME ITS OWN PANEL. Above it is welded to the layout
%      (cb.Layout.Tile = 'east'), which has no meaning once the tiles are separate
%      files. It is exported standalone below so it can be placed once.
%   2. THE SCALE BAR SHOULD APPEAR ONCE. It is drawn only on panel 01, as in the
%      montage; if the assembly reorders the panels, move it in Illustrator rather
%      than re-exporting.
% The shared colour axis `clim` is reused unchanged, so the panels remain directly
% comparable to each other and to the contact sheet.
for k = 1:nV
    fK  = paperFig(2.6, 2.6);
    axK = axes(fK); %#ok<LAXES>
    img = maps(:, :, k);
    imK = imagesc(axK, img, clim);
    imK.AlphaData = ~isnan(img);
    colormap(axK, cmapBWR);
    axis(axK, 'image', 'off');
    hold(axK, 'on');
    rectangle(axK, 'Position', [pcc-ROI_HALF, prc-ROI_HALF, 2*ROI_HALF, 2*ROI_HALF], ...
        'EdgeColor', [0 0 0], 'LineWidth', 0.6);
    text(axK, 0.03, 0.97, sprintf('%.2f mW', uA(validIdx(k)) * V_TO_MW), ...
        'Units','normalized', 'VerticalAlignment','top', ...
        'FontSize', 6, 'FontWeight','bold');
    if k == 1
        barPx = 1 / PX_MM;
        xl = xlim(axK); yl = ylim(axK);
        x0 = xl(1) + 0.06*diff(xl);  y0 = yl(2) - 0.08*diff(yl);
        plot(axK, [x0, x0+barPx], [y0, y0], 'k-', 'LineWidth', 1.2);
        text(axK, x0 + barPx/2, y0 - 0.045*diff(yl), '1 mm', ...
            'HorizontalAlignment','center', 'FontSize', 6, 'FontWeight','bold');
    end
    hold(axK, 'off');
    paperExport(fK, fullfile(outDir, sprintf('supp_spatial_map_%02d.pdf', k)));
end

% Standalone colourbar, same clim as every map panel.
fCB  = paperFig(1.6, 2.6);
axCB = axes(fCB); %#ok<LAXES>
colormap(axCB, cmapBWR);
caxis(axCB, clim);
axis(axCB, 'off');
cbS = colorbar(axCB, 'Location', 'west');
% Force the bar to span the canvas. Left to itself it fills only the axes' own
% height and crops to ~1.8 cm against 2.12 cm map panels; the assembler would then
% have to scale it in Illustrator, which rescales the tick text and breaks the
% 6 pt rule. Exporting it at map height keeps every panel placeable at 100%.
cbS.Units    = 'normalized';
cbS.Position = [0.30 0.04 0.18 0.92];
cbS.Label.String     = '\DeltaF/F (%)';
cbS.FontSize         = 6;
cbS.Label.FontSize   = 6;
cbS.Label.FontWeight = 'bold';
set(cbS, 'FontWeight', 'bold', 'Box', 'off', 'TickDirection', 'out');
paperExport(fCB, fullfile(outDir, 'supp_spatial_cbar.pdf'));

fprintf('[SPATIAL] %d individual map panels + colourbar -> %s\n', nV, outDir);

% ============================== PANEL: AREA =================================
% Background offset per amplitude from an annulus 0.6-0.9 mm from the peak;
% threshold = 50% of the median response within 0.2 mm of the peak at the
% strongest amplitude. Radii in mm at the corrected 0.0173 mm/px scale.
[rr, cc] = ndgrid(1:size(maps,1), 1:size(maps,2));
dist = sqrt((rr - prc).^2 + (cc - pcc).^2) * PX_MM;
annulus = dist >= 0.6 & dist <= 0.9;
local   = dist <= 0.2;

sm   = maps(:, :, iStrong);
bgS  = mean(sm(annulus & ~isnan(sm)), 'omitnan');
thr  = 0.5 * median(sm(local & ~isnan(sm)) - bgS, 'omitnan');

area_mm2 = nan(nV, 1);
for k = 1:nV
    m  = maps(:, :, k);
    bg = mean(m(annulus & ~isnan(m)), 'omitnan');
    area_mm2(k) = sum((m(:) - bg) < thr & ~isnan(m(:))) * PX_MM^2;
end

figA = paperFig(4.2, 3.2);
axA  = axes(figA);
plot(axA, uA(validIdx) * V_TO_MW, area_mm2, 'o-', ...
    'Color', [0.15 0.35 0.8], 'MarkerFaceColor', [0.15 0.35 0.8], ...
    'MarkerSize', 3, 'LineWidth', 1.2);
xlabel(axA, 'Amplitude (mW)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(axA, 'Suppressed area (mm^2)', 'FontSize', 6, 'FontWeight', 'bold');
set(axA, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');
paperExport(figA, fullfile(outDir, 'imp_spatial_area.pdf'));

fprintf('\n[SPATIAL] threshold %.3f %%dF/F | clim +/- %.2f\n', thr, lim);
for k = 1:nV
    fprintf('  %.2f mW   area %.3f mm2\n', uA(validIdx(k)) * V_TO_MW, area_mm2(k));
end
fprintf('[SPATIAL] exported imp_spatial_maps.pdf + imp_spatial_area.pdf -> %s\n', outDir);
