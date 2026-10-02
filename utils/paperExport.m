function paperExport(fig, path)
% PAPEREXPORT  Smart figure export — infers format from file extension.
%   .pdf / .svg / .eps  →  exportgraphics ContentType='vector'
%   .png / .jpg / .tif  →  exportgraphics Resolution=300
%
% Usage:  paperExport(fig, fullfile(outDir, 'panel_A.pdf'));
%         paperExport(fig, fullfile(outDir, 'heatmap.png'));
%
% ---- V3 / jn-STYLE MIRROR (user, 2026-10-02) ---------------------------------------------
% Set the global PAPER_V3 to true and every vector panel is ALSO written under
% paper/figures_v3/, after a jnAxesAll() rule-book pass (Arial, tick labels 6 pt regular,
% axis labels + title 7 pt bold, ticks out, box off, axis 0.5 pt — FIGURE_RULEBOOK §3/§4).
%   global PAPER_V3; PAPER_V3 = true;    % then run any producer script
% Done HERE rather than in each producer because all ~15 of them already funnel through
% this one function; jnAxesAll was written for exactly this ("rather than refactor every
% call site, this restyles the finished figure"). The v2/images original is still written
% unchanged, so v3 is purely additive and nothing that exists today is disturbed.
%
% Line weights are NOT touched: paperStyle's lw_* constants were already moved onto the
% rule-book values, so only typography differed between the two styles. Colours are
% identical in both (col_ol [1 0 0], col_cl [0 0.40 0.85]) — verified, not assumed.
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

paper_v3_mirror(fig, path);   % additive jn-style copy under figures_v3 (no-op unless PAPER_V3)
end
