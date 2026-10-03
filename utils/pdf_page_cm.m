function [w, h] = pdf_page_cm(pdfpath)
%PDF_PAGE_CM  Page size of a PDF in centimetres — i.e. the size it imports into Illustrator.
%
%   [w,h] = pdf_page_cm('panel.pdf')
%
% Why this exists: exportgraphics(...,'ContentType','vector') TIGHT-CROPS the page to the
% content bounding box, so the figure's canvas size (fig.Position(3:4)) is NOT the size the
% panel lands at. Anything overhanging the canvas — a long tick label, a legend pushed
% outside the axes, an annotation — enlarges the page. That is how a panel ends up oversized
% in Illustrator while looking correct in MATLAB.
%
% Reads the /MediaBox from the PDF, in points (1 pt = 1/72 in = 2.54/72 cm). Takes the FIRST
% MediaBox in the file (these are single-page panel exports). Returns NaN on anything it
% cannot parse rather than guessing — a wrong size silently recorded is worse than no size.
w = NaN; h = NaN;
if ~isfile(pdfpath), return; end

fid = fopen(pdfpath, 'r');
if fid < 0, return; end
cleanupObj = onCleanup(@() fclose(fid));                                    %#ok<NASGU>
raw = fread(fid, inf, '*char')';

tok = regexp(raw, '/MediaBox\s*\[\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\]', ...
             'tokens', 'once');
if isempty(tok), return; end

v = str2double(tok);
if any(isnan(v)), return; end

w = abs(v(3) - v(1)) * 2.54 / 72;
h = abs(v(4) - v(2)) * 2.54 / 72;
end
