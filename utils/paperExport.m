function paperExport(fig, path)
% PAPEREXPORT  Smart figure export — infers format from file extension.
%   .pdf / .svg / .eps  →  exportgraphics ContentType='vector'
%   .png / .jpg / .tif  →  exportgraphics Resolution=300
%
% Usage:  paperExport(fig, fullfile(outDir, 'panel_A.pdf'));
%         paperExport(fig, fullfile(outDir, 'heatmap.png'));
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
fprintf('Exported: %s\n', path);
end
