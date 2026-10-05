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

% ---- CORTEX DISPLAY MASK (added 2026-10-05, user: "the brain images need a mask,
%      they are covering a lot of area outside the cortex") ------------------
% `ae.brainMask` is NOT a cortex outline. Measured on AL_0033 2025-01-29 it is TRUE
% over 75% of the frame (234414 / 313600 px, 70.2 mm^2): it includes the dark
% surround at the top corners AND it EXCLUDES a large block of posterior cortex.
% Plotting through it put diffuse signal well outside the brain and dropped real
% cortex, so every spatial map was misleading about where the effect reached.
%
% We cannot simply replace it: `imp.resp_map` is indexed BY `bmask`, so the unpack
% below must keep using it. Instead we derive a display mask from the mean image
% and NaN the maps outside it, leaving the indexing untouched.
%
% THE MASK IS DRAWN BY HAND, ONCE, AND CACHED (user, 2026-10-05). An automatic
% threshold was tried first and rejected: it split the hemispheres down the
% sagittal sinus (dark vessel -> below threshold) and trimmed the dim posterior
% taper, both of which are anatomical calls rather than intensity calls. Draw it
% once per session; every later run loads the cache.
%
% ORIENTATION TRAP. The maps are permuted to display orientation LATER (anterior
% up, hemispheres side by side). This mask is applied BEFORE that, so it must live
% in the raw (nr x nc) array frame. We therefore draw on the TRANSPOSED mean image
% -- the orientation you actually want to look at -- and transpose the result back
% before storing. Do not "simplify" this by dropping either transpose.
% `here` is not defined in this script; anchor the cache on load_experiments.m,
% the same way paperRoot above is anchored.
ctxDir   = fullfile(fileparts(which('load_experiments')), 'data');
ctxCache = fullfile(ctxDir, sprintf('cortex_mask_%s_%s_e%d.mat', ae.mn, ae.td, ae.en));
if ~exist('CTX_REDRAW','var') || isempty(CTX_REDRAW), CTX_REDRAW = false; end
if exist(ctxCache, 'file') && ~CTX_REDRAW
    S_ctx   = load(ctxCache, 'ctxMask');
    ctxMask = S_ctx.ctxMask;
    fprintf('[SPATIAL] cortex mask: CACHED (%s)\n', ctxCache);
else
    fh = figure('Color','w','Name','Draw the cortex mask','NumberTitle','off');
    imagesc(mimg'); axis image off; colormap(gray);
    title({'Draw the cortex outline (anterior up).', ...
           'Click to place vertices, double-click or close the shape to finish.'}, ...
          'FontWeight','bold');
    roi = drawpolygon('Color', [0.9 0.2 0.2], 'LineWidth', 1.2);
    wait(roi);
    maskDisp = createMask(roi);          % in DISPLAY (transposed) orientation
    ctxMask  = maskDisp';                % back to the raw (nr x nc) array frame
    close(fh);
    if ~exist(fileparts(ctxCache), 'dir'), mkdir(fileparts(ctxCache)); end
    save(ctxCache, 'ctxMask');
    fprintf('[SPATIAL] cortex mask: DRAWN and cached -> %s\n', ctxCache);
end
assert(isequal(size(ctxMask), [nr nc]), ...
       '[SPATIAL] cortex mask is %s, expected %s -- orientation bug', ...
       mat2str(size(ctxMask)), mat2str([nr nc]));
fprintf('[SPATIAL] cortex mask %d px (%.1f mm^2, %.0f%% of frame); ae.brainMask was %.0f%%\n', ...
        nnz(ctxMask), nnz(ctxMask)*PX_MM^2, 100*nnz(ctxMask)/(nr*nc), ...
        100*nnz(bmask)/(nr*nc));

% ---- stack response maps into full frames (NaN outside the cortex) --------
maps = nan(nr, nc, nV);
for k = 1:nV
    f = nan(nr * nc, 1);
    f(bmask(:)) = imp.resp_map{validIdx(k)};
    fm = reshape(f, nr, nc);
    fm(~ctxMask) = NaN;                 % display mask, applied after unpacking
    maps(:, :, k) = fm;
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
%   2. THE SCALE BAR SHOULD APPEAR ONCE. It is EMBEDDED on panel 01 (user,
%      2026-10-05: "i also want one of them to have the 1mm label embedded instead
%      of separate loading"), so there is no standalone scale-bar file to place.
%      If the assembly reorders the panels, move panel 01 rather than re-exporting.
% The shared colour axis `clim` is reused unchanged, so the panels remain directly
% comparable to each other and to the contact sheet.
% SIZE BUDGET, REPLANNED 2026-10-05 for a 3 x 3 arrangement (user: "i want all 9
% maps ill place it as 3 by 3"). All nine amplitudes are exported; the earlier
% 5-panel subset is retired.
%     maps      3 x 3 @ ~1.6 cm                    ~= 4.8 x 4.8 cm
%     colourbar beside them                        ~= 0.6 x 4.8 cm
%     right col area / spont var / stationarity    ~= 2.6 x 1.6 cm each, stacked
%                                            total ~= 8.0 x 4.8 cm   (budget 8 x 5)
%
% ---- THESE NINE PANELS ARE PNG, NOT PDF, AND THAT IS DELIBERATE ------------------
% The user reported the exported panels would not load properly. Inspecting the
% emitted files showed the real defect, and it is worse than a loading nuisance:
%
%   exportgraphics(fig, '*.pdf', 'ContentType','vector') re-encodes every embedded
%   raster as a JPEG RESAMPLED TO THE FIGURE'S ON-SCREEN PIXEL SIZE.
%
% A 1.6 cm canvas is ~60 screen px, so each brain map was landing in the PDF as a
% LOSSY 64 x 63 JPEG -- about 135 dpi, and below even the 103 x 121 native
% resolution of the cropped data. Passing 'Resolution' alongside 'ContentType',
% 'vector' is accepted and then silently ignored (verified: byte-identical output),
% so there is no way to fix this on the PDF path.
%
% A soft mask (/SMask) was the first suspect and it was WRONG: every MATLAB-exported
% panel in figures_final carries one, including all the ones that assemble fine.
% Noted here so it is not re-investigated.
%
% PNG at SP_MAP_DPI therefore gives a strictly better panel than PDF for this one
% panel class -- the full data, no JPEG, and crisp 6 pt type -- and it matches the
% project's own rule ("300 dpi PNG for heatmaps"), raised here because 300 dpi over
% 1.2 cm would be only 142 px. The colourbar and the area plot stay vector PDFs:
% they are line art, which is what the vector path is actually good at.
%
% Rendering stays NEAREST-NEIGHBOUR (no interpolation): these are real measurement
% pixels and smoothing them would invent spatial detail the widefield data does not
% have. The contact sheet above renders the same way, so the two agree.
%
% Labels are burned in (user: "all spatial map panels should have amps written on
% it"), and the 1 mm scale bar is embedded on the first panel rather than shipped as
% a separate file.
if ~exist('SP_MAP_DPI','var') || isempty(SP_MAP_DPI), SP_MAP_DPI = 1200; end
global PAPER_FINAL                                                   %#ok<GVMIS>
PAPER_FINAL_ON = ~isempty(PAPER_FINAL) && PAPER_FINAL;
for k = 1:nV
    fK  = paperFig(1.6, 1.6);
    axK = axes(fK); %#ok<LAXES>
    img = maps(:, :, k);
    imK = imagesc(axK, img, clim);
    imK.AlphaData = ~isnan(img);        % white outside the hand-drawn cortex mask
    colormap(axK, cmapBWR);
    axis(axK, 'image', 'off');
    hold(axK, 'on');

    rectangle(axK, 'Position', [pcc-ROI_HALF, prc-ROI_HALF, 2*ROI_HALF, 2*ROI_HALF], ...
        'EdgeColor', [0 0 0], 'LineWidth', 0.6);

    text(axK, 0.03, 0.97, sprintf('%.2f mW', uA(validIdx(k)) * V_TO_MW), ...
        'Units','normalized', 'VerticalAlignment','top', ...
        'HorizontalAlignment','left', 'FontSize', 6, 'FontWeight','bold');

    % 1 mm scale bar EMBEDDED on the first panel (user 2026-10-05: "i also want one
    % of them to have the 1mm label embedded instead of separate loading"). Bottom
    % left, so it cannot collide with the amplitude label in the top left.
    if k == 1
        barPx = 1 / PX_MM;
        xl = xlim(axK); yl = ylim(axK);
        x0 = xl(1) + 0.06*diff(xl);  y0 = yl(2) - 0.10*diff(yl);
        plot(axK, [x0, x0+barPx], [y0, y0], 'k-', 'LineWidth', 1.2);
        text(axK, x0 + barPx/2, y0 - 0.025*diff(yl), '1 mm', ...
            'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
            'FontSize', 6, 'FontWeight','bold');
    end
    hold(axK, 'off');
    paperExport(fK, fullfile(outDir, sprintf('supp_spatial_map_%02d.png', k)), SP_MAP_DPI);
    fprintf('    map_%02d  <-  %.2f mW\n', k, uA(validIdx(k)) * V_TO_MW);
end

% Standalone colourbar, same clim as every map panel.
fCB  = paperFig(1.0, 1.5);
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

% ---- PAD THE NINE MAPS TO A COMMON CANVAS ----------------------------------
% exportgraphics tight-crops to CONTENT, so panel 01 came out 1.22 x 0.95 cm while
% the rest were 1.07 x 0.97 -- its embedded scale bar and "1 mm" label push the
% bounding box out. Nine panels of eight different sizes cannot be dropped into a
% 3 x 3 grid without nudging each one by hand, and any nudge silently breaks the
% "place at 100%" rule the panels are sized for.
%
% So every map is padded with white to the largest box in the set, centred. Padding
% adds blank margin only -- no pixel of data is scaled, cropped or moved relative to
% any other -- so the nine stay directly comparable AND become a drop-in grid.
mapFiles = arrayfun(@(k) fullfile(outDir, sprintf('supp_spatial_map_%02d.png', k)), ...
                    1:nV, 'uni', 0);
if PAPER_FINAL_ON
    finDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                      'paper', 'figures_final', 'panels', 'supp_spatial');
    mapFiles = [mapFiles, arrayfun(@(k) fullfile(finDir, ...
        sprintf('supp_spatial_map_%02d.png', k)), 1:nV, 'uni', 0)];
end
pad_png_to_common_canvas(mapFiles);

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

% Narrowed 4.2 -> 2.8 cm (user size budget, 2026-10-05). The bottom row carries
% three panels -- area, spontaneous variance, stationarity -- inside an 8 cm width,
% so each gets ~2.6 cm after cropping. At 4.2 this one panel took half the row.
figA = paperFig(2.8, 3.2);
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


% =============================================================================
function pad_png_to_common_canvas(files)
% Pad each PNG with white until every file shares the largest canvas in the set,
% keeping the existing content centred. Missing or unreadable files are skipped
% rather than aborting -- a padding failure must never cost a producer its export.
files = files(cellfun(@(f) exist(f,'file') == 2, files));
if isempty(files), return; end
sz = nan(numel(files), 2);
for i = 1:numel(files)
    try
        info = imfinfo(files{i});
        sz(i,:) = [info(1).Height, info(1).Width];
    catch
    end
end
ok = all(~isnan(sz), 2);
if ~any(ok), return; end
tgt = max(sz(ok,:), [], 1);
nPad = 0;
for i = find(ok(:))'
    if isequal(sz(i,:), tgt), continue; end
    try
        [A, map, alpha] = imread(files{i});
        if ~isempty(map), A = ind2rgb(A, map); end
        if size(A,3) == 1, A = repmat(A, 1, 1, 3); end
        padT = floor((tgt(1) - sz(i,1)) / 2);  padB = tgt(1) - sz(i,1) - padT;
        padL = floor((tgt(2) - sz(i,2)) / 2);  padR = tgt(2) - sz(i,2) - padL;
        white = ones(1, 1, 'like', A);
        if isinteger(A), white = intmax(class(A)); end
        B = repmat(white, tgt(1), tgt(2), size(A,3));
        B(padT+1:padT+sz(i,1), padL+1:padL+sz(i,2), :) = A;
        if isempty(alpha)
            imwrite(B, files{i});
        else
            Aa = zeros(tgt, 'like', alpha);
            Aa(padT+1:padT+sz(i,1), padL+1:padL+sz(i,2)) = alpha;
            imwrite(B, files{i}, 'Alpha', Aa);
        end
        nPad = nPad + 1;
    catch
    end
end
fprintf('[SPATIAL] padded %d/%d map panels to a common %d x %d px canvas\n', ...
        nPad, numel(files), tgt(2), tgt(1));
end
