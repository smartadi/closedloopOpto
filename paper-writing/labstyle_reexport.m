function labstyle_reexport(pattern, styles)
% LABSTYLE_REEXPORT  Redo the jn and lab renders of the style comparison from the .fig files a
% labstyle_remake run saved, without rerunning any producer (2026-11-05).
%
%   labstyle_reexport                    % every vector panel, both styles
%   labstyle_reexport('tune')            % only paths containing 'tune'
%   labstyle_reexport('', {'lab'})       % lab render only (e.g. after a change to sls_style_fig)
%
% sls_lab_export saves each figure as the producer drew it to paper/figures_labstyle/src/<path>.fig;
% this sends each one through sls_lab_render again. Skipped: the sq_*_rmice strips (their heat maps
% are swapped for lossless PNGs by imp_state_raster_peramp after export, so rerun that script) and
% raster-only panels. Writes only under paper/figures_labstyle/.
if nargin < 1, pattern = ''; end
if nargin < 2, styles = {'jn', 'lab'}; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'utils')));
lab = fullfile(root, 'paper', 'figures_labstyle');
F = dir(fullfile(lab, 'src', '**', '*.fig'));
n = 0;
for k = 1:numel(F)
    src = fullfile(F(k).folder, F(k).name);
    rel = [src(numel(fullfile(lab, 'src')) + 2:end-4) '.pdf'];          % e.g. images\figure3\panel_A.pdf
    if ~isempty(pattern) && ~contains(rel, pattern), continue; end
    if contains(rel, '_rmice') || ~isfile(fullfile(lab, rel)), continue; end
    sls_lab_render(src, rel, 300, styles);
    n = n + 1;
end
fprintf('[labstyle_reexport] %d panels re-rendered (%s)\n', n, strjoin(styles, ', '));
end
