function sls_lab_render(src, rel, dpi, styles)
% SLS_LAB_RENDER  Render one saved panel (.fig) in our jn style and in the lab style, for the
% lab-vs-jn comparison in paper/figures_labstyle/ (2026-11-05). See SLS_LAB_EXPORT for the layout.
%
%   sls_lab_render(src, rel)                    both styles
%   sls_lab_render(src, rel, dpi, {'lab'})      one style
%
% src: the .fig; rel: the panel's path under paper/ with images/ or other/ first and the export
% extension last (e.g. images\figure3\panel_A.pdf). Each style opens its own copy of the .fig, so
% neither sees the other's changes. Writes only under paper/figures_labstyle/.
global PAPER_LABSTYLE_LOG                                           %#ok<GVMIS>
if nargin < 3 || isempty(dpi), dpi = 300; end
if nargin < 4 || isempty(styles), styles = {'jn', 'lab'}; end
root = fileparts(fileparts(mfilename('fullpath')));
lab  = fullfile(root, 'paper', 'figures_labstyle');
[~, base, ext] = fileparts(rel);
isVec = any(strcmpi(ext, {'.pdf', '.svg', '.eps'}));
sec = local_manifest_section([base ext]);
for s = 1:numel(styles)
    st = styles{s};
    try
        g = openfig(src, 'invisible');
        ln = findall(g, 'Type', 'line');                           % restore line transparency
        for k = 1:numel(ln)
            if isappdata(ln(k), 'sls_alpha'), ln(k).Color = [ln(k).Color(1:3) getappdata(ln(k), 'sls_alpha')]; end
        end
        if strcmp(st, 'jn')
            jnAxesAll(g);
            top = fullfile(lab, 'jnrerun');  R = [];
        else
            R = sls_style_fig(g);
            top = lab;
        end
        out = fullfile(top, rel);
        if ~exist(fileparts(out), 'dir'), mkdir(fileparts(out)); end
        local_export(g, out, isVec, dpi, [base ext]);
        if ~isempty(sec)
            pd = fullfile(top, 'panels', sec);
            if ~exist(pd, 'dir'), mkdir(pd); end
            copyfile(out, fullfile(pd, [base ext]));
            if isVec, copyfile(regexprep(out, '\.(pdf|svg|eps)$', '.png'), fullfile(pd, [base '.png'])); end
        end
        if strcmp(st, 'lab')
            tag = '';
            if ~isempty(sec), tag = sprintf('  -> panels/%s', sec); end
            fprintf('   [lab] %-60s ax %d, ends %d, ref %d, maps %d, legends %d, bars %d%s\n', rel, ...
                    R.axes, R.snapped, R.reflines, R.cmaps, R.legends, R.colorbars, tag);
            nlab = sls_report(g, out);
            if isempty(PAPER_LABSTYLE_LOG), PAPER_LABSTYLE_LOG = {}; end
            PAPER_LABSTYLE_LOG{end+1} = struct('file', out, 'sec', sec, 'name', [base ext], ...
                                               'restyle', R, 'lab_required', nlab);
        end
        close(g);
    catch ME
        warning('sls_lab_render:failed', '%s render failed for %s (%s)', st, rel, ME.message);
        if exist('g', 'var') && isvalid(g), close(g); end
    end
end
end

% -----------------------------------------------------------------------------------------
function local_export(fig, out, isVec, dpi, name)
if ~isVec
    exportgraphics(fig, out, 'Resolution', dpi, 'BackgroundColor', 'white');
    return
end
png = regexprep(out, '\.(pdf|svg|eps)$', '.png');
exportgraphics(fig, png, 'Resolution', 300, 'BackgroundColor', 'white');
% exportgraphics' vector writer sometimes squeezes a small panel (supp_tune_node_01 came out 1.16 x 1.16 cm
% instead of 2.5 x 1.1 on 2026-11-05; memory "MATLAB panel print"). The 300-dpi PNG of the same figure is the
% reference: a PDF much narrower or shorter than it is printed again after a re-layout.
info = imfinfo(png);  ref = [info.Width info.Height] / 300 * 2.54;
for attempt = 1:5
    exportgraphics(fig, out, 'ContentType', 'vector', 'BackgroundColor', 'white');
    [pw, ph] = pdf_page_cm(out);
    if isnan(pw) || all([pw ph] > 0.8 * ref), break; end
    fprintf('   [lab] %s: PDF %.2f x %.2f cm vs PNG %.2f x %.2f, printing again\n', name, pw, ph, ref);
    pu = fig.Units; fig.Units = 'centimeters'; fp = fig.Position;
    fig.Position = fp + [0 0 0 0.05]; drawnow; fig.Position = fp; drawnow; fig.Units = pu;
end
% paper_final_mirror's size guard, so both styles go through the export the paper uses: content that
% overhangs the canvas is pulled in by jn_fit_canvas, kept only if the page really shrinks
pu = fig.Units; fig.Units = 'centimeters'; cv = fig.Position(3:4); fig.Units = pu;
over = [pw - cv(1), ph - cv(2)];
if ~isnan(pw) && any(over > 0.15)
    try
        tmp = [tempname '.pdf'];
        jn_fit_canvas(fig);
        exportgraphics(fig, tmp, 'ContentType', 'vector', 'BackgroundColor', 'white');
        [pw2, ph2] = pdf_page_cm(tmp);
        if ~isnan(pw2) && max([pw2 - cv(1), ph2 - cv(2)]) < max(over) - 0.01 && all([pw2 ph2] > 0.8 * ref)
            copyfile(tmp, out);
            exportgraphics(fig, png, 'Resolution', 300, 'BackgroundColor', 'white');
        end
        if isfile(tmp), delete(tmp); end
    catch
    end
end
end

% -----------------------------------------------------------------------------------------
function sec = local_manifest_section(base)
% Same parse as paper_final_mirror: the [section] that lists this basename, or ''.
persistent MAP
if isempty(MAP)
    MAP  = containers.Map('KeyType', 'char', 'ValueType', 'char');
    root = fileparts(fileparts(mfilename('fullpath')));
    mf   = fullfile(root, 'paper', 'figures_final', 'MANIFEST.txt');
    if ~isfile(mf), sec = ''; return; end
    txt = strsplit(fileread(mf), newline);
    cur = '';
    for i = 1:numel(txt)
        ln = strtrim(txt{i});
        if isempty(ln) || startsWith(ln, '#'), continue; end
        if startsWith(ln, '[') && endsWith(ln, ']'), cur = ln(2:end-1); continue; end
        if isempty(cur), continue; end
        hh = strfind(ln, '#');
        if ~isempty(hh), ln = strtrim(ln(1:hh(1)-1)); end
        if isempty(ln), continue; end
        [~, nm, ex] = fileparts(ln);
        MAP([nm ex]) = cur;
    end
end
if isKey(MAP, base), sec = MAP(base); else, sec = ''; end
end
