function jnExport(fig, pdfpath, dpi)
% JNEXPORT  Save fig as a vector PDF (line art) + a 300-dpi PNG preview, white bg.
%   jnExport(fig, 'paper/figures_v2/figure4/panelG.pdf')
if nargin < 3 || isempty(dpi); dpi = 300; end
d = fileparts(pdfpath);
if ~isempty(d) && ~exist(d,'dir'); mkdir(d); end
exportgraphics(fig, pdfpath, 'ContentType','vector', 'BackgroundColor','white');
pngpath = regexprep(pdfpath, '\.pdf$', '.png');
exportgraphics(fig, pngpath, 'Resolution',dpi, 'BackgroundColor','white');
fprintf('[jnExport] %s\n', pdfpath);
end
