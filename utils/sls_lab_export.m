function done = sls_lab_export(fig, path, dpi)
% SLS_LAB_EXPORT  Lab-style comparison run: write a steinmetzlab-style copy of a panel into
% paper/figures_labstyle/ INSTEAD OF the normal export. No-op unless the global PAPER_LABSTYLE
% is true.
%
%   global PAPER_LABSTYLE; PAPER_LABSTYLE = true;   % then run any producer
%
% Called first thing by jnExport and paperExport. When it returns true the exporter returns at
% once, so a comparison run writes nothing to paper/images/ and never reaches
% paper_final_mirror, so figures_final/ cannot change. Everything lands under
% paper/figures_labstyle/ (git-ignored, like all of paper/):
%   images/<path under paper/images>   every panel the exporters write, lab-styled (other/ for
%                                      paths outside paper/images)
%   panels/<section>/<name>            the MANIFEST-listed (final) panels, as in figures_final
%   src/<same path>.fig                the figure as the producer drew it, before the lab pass,
%                                      so the lab pass can be redone without rerunning producers
% The lab pass is sls_style_fig (paper.mplstyle in MATLAB). Each panel is then checked with
% sls_report (lab required rules). Failures are warnings, never errors: a comparison run must
% not abort a producer. Added 2026-11-05 to compare the lab style with ours (Aditya).
global PAPER_LABSTYLE PAPER_LABSTYLE_LOG                           %#ok<GVMIS>
done = false;
if isempty(PAPER_LABSTYLE) || ~PAPER_LABSTYLE, return; end
done = true;
if nargin < 3 || isempty(dpi), dpi = 300; end
try
    root = fileparts(fileparts(mfilename('fullpath')));             % utils/.. = project root
    lab  = fullfile(root, 'paper', 'figures_labstyle');
    p    = strrep(char(path), '/', filesep);
    if ~local_isabs(p), p = fullfile(pwd, p); end
    p    = char(java.io.File(p).getCanonicalPath());
    pimg = [fullfile(root, 'paper', 'images') filesep];
    proot = [fullfile(root, 'paper') filesep];
    if strncmpi(p, pimg, numel(pimg))
        rel = fullfile('images', p(numel(pimg)+1:end));
    elseif strncmpi(p, proot, numel(proot))
        rel = fullfile('other', p(numel(proot)+1:end));
    else
        [~, b, e] = fileparts(p); rel = fullfile('other', [b e]);
    end
    [rd, base, ext] = fileparts(rel);
    out = fullfile(lab, rel);
    if ~exist(fileparts(out), 'dir'), mkdir(fileparts(out)); end

    % the producer's own figure, once per figure, before any restyle
    if ~isappdata(fig, 'sls_lab_src')
        sd = fullfile(lab, 'src', rd);
        if ~exist(sd, 'dir'), mkdir(sd); end
        setappdata(fig, 'sls_lab_src', true);
        try
            savefig(fig, fullfile(sd, [base '.fig']));
        catch
        end
    end

    R = sls_style_fig(fig);
    isVec = any(strcmpi(ext, {'.pdf', '.svg', '.eps'}));
    if isVec
        exportgraphics(fig, out, 'ContentType', 'vector', 'BackgroundColor', 'white');
        exportgraphics(fig, regexprep(out, '\.(pdf|svg|eps)$', '.png'), 'Resolution', 300, ...
                       'BackgroundColor', 'white');
    else
        exportgraphics(fig, out, 'Resolution', dpi, 'BackgroundColor', 'white');
    end

    sec = local_manifest_section([base ext]);
    if ~isempty(sec)
        pd = fullfile(lab, 'panels', sec);
        if ~exist(pd, 'dir'), mkdir(pd); end
        copyfile(out, fullfile(pd, [base ext]));
        if isVec
            copyfile(regexprep(out, '\.(pdf|svg|eps)$', '.png'), fullfile(pd, [base '.png']));
        end
    end
    tag = '';
    if ~isempty(sec), tag = sprintf('  -> panels/%s', sec); end
    fprintf('   [lab] %-60s ax %d, ends %d, ref %d, maps %d, legends %d, bars %d%s\n', rel, ...
            R.axes, R.snapped, R.reflines, R.cmaps, R.legends, R.colorbars, tag);
    nlab = sls_report(fig, out);
    if isempty(PAPER_LABSTYLE_LOG), PAPER_LABSTYLE_LOG = {}; end
    PAPER_LABSTYLE_LOG{end+1} = struct('file', out, 'sec', sec, 'name', [base ext], ...
                                       'restyle', R, 'lab_required', nlab);
catch ME
    warning('sls_lab_export:failed', 'lab-style export failed for %s (%s)', char(path), ME.message);
end
end

% -----------------------------------------------------------------------------------------
function tf = local_isabs(p)
tf = numel(p) > 1 && (p(2) == ':' || startsWith(p, '\\') || startsWith(p, '/'));
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
