function jnExport(fig, pdfpath, dpi)
% JNEXPORT  Save fig as a vector PDF (line art) + a 300-dpi PNG preview, white bg.
%   jnExport(fig, 'paper/figures_v2/figure4/panelG.pdf')
if nargin < 3 || isempty(dpi); dpi = 300; end
d = fileparts(pdfpath);
if ~isempty(d) && ~exist(d,'dir'); mkdir(d); end
% TIGHT-CROP vector (reverted 2026-09-29): page = content bbox, so nothing clips.
% Exact-page print() clips content overhanging the canvas; keep figures small via jnFig
% size + small fonts instead. True import size = cropped bbox (measure from the PDF).
prevUnits = fig.Units; fig.Units = 'centimeters'; sz = fig.Position(3:4); fig.Units = prevUnits;
exportgraphics(fig, pdfpath, 'ContentType','vector', 'BackgroundColor','white');
pngpath = regexprep(pdfpath, '\.pdf$', '.png');
exportgraphics(fig, pngpath, 'Resolution',dpi, 'BackgroundColor','white');
fprintf('[jnExport] %s  [canvas %.2f × %.2f cm; PDF cropped to content]\n', pdfpath, sz(1), sz(2));
end
