function preview_png(fig, previewDir, name)
% PREVIEW_PNG  Optional 200-dpi PNG preview of a paper panel.
% No-op when previewDir is empty, so paper scripts can leave the call in place.
% The vector PDF from paperExport remains the deliverable — this is only for
% quick visual checks without opening the PDF.
%
% Usage:  preview_png(fig_A, PREVIEW_DIR, 'A');
if isempty(previewDir); return; end
if ~exist(previewDir, 'dir'); mkdir(previewDir); end
exportgraphics(fig, fullfile(previewDir, sprintf('prev_%s.png', name)), 'Resolution', 200);
end
