function paperExport(fig, path)
% PAPEREXPORT  Smart figure export — infers format from file extension.
%   .pdf / .svg / .eps  →  exportgraphics ContentType='vector'
%   .png / .jpg / .tif  →  exportgraphics Resolution=300
%
% Usage:  paperExport(fig, fullfile(outDir, 'panel_A.pdf'));
%         paperExport(fig, fullfile(outDir, 'heatmap.png'));
% Read figure size before export (Units may be anything — convert to cm)
prevUnits = fig.Units;
fig.Units = 'centimeters';
sz = fig.Position(3:4);   % [w h] in cm
fig.Units = prevUnits;

[~, ~, ext] = fileparts(path);
switch lower(ext)
    case {'.pdf', '.svg', '.eps'}
        % TIGHT-CROP vector (reverted 2026-09-29): exportgraphics crops the page to the
        % content bounding box, so NO label/title/trace is ever clipped. Exact-page print()
        % was tried (Option 2) but clips content that overhangs the canvas (e.g. tiledlayout
        % titles flush to the top edge on panel A). Keep figures small via jnFig() size +
        % small fonts, not by forcing a page that crops. The true import size is the cropped
        % bbox (may differ by a few mm from the nominal jnFig size); measure it from the PDF.
        exportgraphics(fig, path, 'ContentType', 'vector');
    case {'.png', '.jpg', '.tif', '.tiff'}
        exportgraphics(fig, path, 'Resolution', 300);
    otherwise
        warning('paperExport: unknown extension ''%s'' — defaulting to vector.', ext);
        exportgraphics(fig, path, 'ContentType', 'vector');
end
[~, fname, fext] = fileparts(path);
fprintf('Exported: %s%s  [canvas %.2f × %.2f cm; PDF cropped to content]\n', fname, fext, sz(1), sz(2));
end
