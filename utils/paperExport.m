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
        exportgraphics(fig, path, 'ContentType', 'vector');
    case {'.png', '.jpg', '.tif', '.tiff'}
        exportgraphics(fig, path, 'Resolution', 300);
    otherwise
        warning('paperExport: unknown extension ''%s'' — defaulting to vector.', ext);
        exportgraphics(fig, path, 'ContentType', 'vector');
end
[~, fname, fext] = fileparts(path);
fprintf('Exported: %s%s  [%.2f × %.2f cm]\n', fname, fext, sz(1), sz(2));
end
