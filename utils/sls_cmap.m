function cm = sls_cmap(name, n)
% SLS_CMAP  The Steinmetz Lab diverging colormaps, read from the lab style repo.
%
%   cm = sls_cmap('diverging')        % blue-white-red, white centre (256 x 3)
%   cm = sls_cmap('diverging_dark')   % blue-black-red, dark centre, e.g. PC weights
%   cm = sls_cmap('diverging', 128)   % resampled to 128 colours
%
% Both maps change lightness evenly (CIELAB L*), so equal distances from the centre look
% equally strong. 'diverging' runs L* 20 -> 100 -> 20 (hues from Kovesi CET-D1A);
% 'diverging_dark' is Kovesi's CET diverging_bkr_55_10_c35, L* 55 -> 10 -> 55.
% Centre the map on the reference value with sls_clim:
%
%   colormap(ax, sls_cmap('diverging'));
%   clim(ax, sls_clim(data, 0, 'Nice', true));      % caxis(...) before R2022a
%
% For sequential data use a viridis-family map; MATLAB's parula and gray also pass
% sls_check. Never jet, turbo, hsv, or a linear-RGB blue-white-red ([s s 1; 1 s s]
% ramps), whose two halves differ in lightness.
%
% See also SLS_CLIM, SLS_CHECK, SLS_ROOT.

if nargin < 1 || isempty(name), name = 'diverging'; end
persistent cache
if isempty(cache), cache = struct(); end

key = lower(strrep(char(name), '-', '_'));
switch key
    case {'diverging', 'div', 'steinmetzlab_diverging'}
        key = 'diverging';
    case {'diverging_dark', 'div_dark', 'dark', 'steinmetzlab_diverging_dark'}
        key = 'diverging_dark';
    otherwise
        error('sls_cmap:name', 'Unknown map "%s"; use ''diverging'' or ''diverging_dark''.', name);
end

if ~isfield(cache, key)
    f = fullfile(sls_root(), 'src', 'steinmetzlab_style', 'styles', ['cmap_' key '.csv']);
    cache.(key) = readmatrix(f);
end
cm = cache.(key);

if nargin >= 2 && ~isempty(n) && n ~= size(cm, 1)
    cm = interp1(linspace(0, 1, size(cm, 1)), cm, linspace(0, 1, n));
end
end
