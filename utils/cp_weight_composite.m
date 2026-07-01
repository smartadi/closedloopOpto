function rgb = cp_weight_composite(mimgT, kmT, cmap, clim_, alphaT)
%CP_WEIGHT_COMPOSITE  Flatten a gray-brain + weight overlay into ONE truecolor image.
%
%   rgb = CP_WEIGHT_COMPOSITE(mimgT, kmT, cmap, clim_, alphaT) blends a grayscale
%   brain background with a colour-mapped weight overlay into a single H x W x 3
%   RGB image, mirroring cp_kernel_explorer's local_composite. Use this instead of
%   two layered transparent axes (brain_overlay_fig): exportgraphics does not honour
%   AlphaData on a layered overlay, so the unmapped (NaN) region exports as a flat
%   colormap colour (the "ipsi half goes solid blue" bug). A single truecolor image
%   exports faithfully.
%
%   INPUTS (already in DISPLAY orientation -- e.g. transpose before calling)
%     mimgT   [H x W]   gray background (mean image)
%     kmT     [H x W]   weight map (NaN outside the mapped/contra region)
%     cmap    [N x 3]   colormap for the weights
%     clim_   [lo hi]   colour limits for kmT
%     alphaT  [H x W]   optional per-pixel opacity 0..1 (NaN -> 0). Default
%                       min(1, |kmT| / max(|clim_|)) -- magnitude-graded.
%
%   To keep a colorbar, set colormap(ax,cmap) + clim(ax,clim_) on the axes that
%   shows this image; the colorbar reads those even though the image is truecolor.

lo = prctile(mimgT(:), 1);  hi = prctile(mimgT(:), 99);
g  = min(1, max(0, (mimgT - lo) ./ (hi - lo + eps)));
rgb = repmat(g, [1 1 3]);

if nargin < 5 || isempty(alphaT)
    span   = max(abs(clim_));
    alphaT = min(1, abs(kmT) ./ max(span, eps));
end
valid = ~isnan(kmT) & ~isnan(alphaT);
a = alphaT;  a(~valid) = 0;

% map kmT -> colormap rows
N  = size(cmap, 1);
ci = round((kmT - clim_(1)) ./ (clim_(2) - clim_(1) + eps) * (N - 1)) + 1;
ci(~isfinite(ci)) = 1;
ci = min(N, max(1, ci));

C = zeros([size(kmT), 3]);
for ch = 1:3
    cc = cmap(:, ch);
    Cch = cc(ci);
    Cch(~valid) = 0;
    C(:, :, ch) = Cch;
end

A   = repmat(a, [1 1 3]);
rgb = rgb .* (1 - A) + C .* A;
end
