function done = sls_lab_export(fig, path, dpi)
% SLS_LAB_EXPORT  Style-comparison run: instead of the normal export, render a panel in BOTH our jn
% style and the lab (steinmetzlab-style) style into paper/figures_labstyle/. No-op unless the global
% PAPER_LABSTYLE is true.
%
%   global PAPER_LABSTYLE; PAPER_LABSTYLE = true;   % then run any producer (paper-writing/labstyle_remake.m)
%
% Called first thing by jnExport and paperExport. When it returns true the exporter returns at once,
% so a comparison run writes nothing to paper/images/ and never reaches paper_final_mirror:
% figures_final/ cannot change. The producer's live figure is not touched either: it is saved as a
% .fig, and both styles are rendered from that file, so they start from the same drawing.
%   src/<path>.fig                          the figure as the producer drew it (line transparency kept
%                                           in appdata, since .fig files drop it)
%   jnrerun/images/<path>, jnrerun/panels/  our jn style (jnAxesAll), as paper_final_mirror would
%                                           write it today: the baseline for the comparison
%   images/<path>, panels/<section>/        the lab style (sls_style_fig)
% <path> is the path under paper/images (other/... for anything outside it); panels/ holds the
% MANIFEST-listed (final) panels. Both renders go through the same export: a re-print when the vector
% writer squeezes a small panel, and paper_final_mirror's oversize refit (jn_fit_canvas). The lab
% render is checked with sls_report (lab required rules). Failures are warnings, never errors.
% sls_lab_render redoes both renders from the .fig files (paper-writing/labstyle_reexport.m).
% Added 2026-11-05 to compare the lab style with ours (Aditya).
global PAPER_LABSTYLE                                               %#ok<GVMIS>
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
    [rd, base] = fileparts(rel);
    sd = fullfile(lab, 'src', rd);
    if ~exist(sd, 'dir'), mkdir(sd); end
    src = fullfile(sd, [base '.fig']);
    % line transparency (Color = [r g b a]) is not saved in a .fig: keep it in appdata. Edge (where
    % the alpha lives) is only built when the figure is drawn, so draw first: without this every
    % panel exported before its first drawnow lost its alpha (S1D, 2026-11-05)
    drawnow;
    ln = findall(fig, 'Type', 'line');
    for k = 1:numel(ln)
        try
            if strcmp(ln(k).Edge.ColorType, 'truecoloralpha')
                setappdata(ln(k), 'sls_alpha', double(ln(k).Edge.ColorData(4)) / 255);
            end
        catch
        end
    end
    savefig(fig, src);
    sls_lab_render(src, rel, dpi);
catch ME
    warning('sls_lab_export:failed', 'lab-style export failed for %s (%s)', char(path), ME.message);
end
end

% -----------------------------------------------------------------------------------------
function tf = local_isabs(p)
tf = numel(p) > 1 && (p(2) == ':' || startsWith(p, '\\') || startsWith(p, '/'));
end
