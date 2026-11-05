function lims = sls_clim(data, center, varargin)
% SLS_CLIM  Colour limits symmetric about a reference value, for a diverging map.
% MATLAB port of steinmetzlab_style.diverging_limits.
%
%   lims = sls_clim(data)                       % [-m m], m = max |data|
%   lims = sls_clim(data, ref)                  % ref +/- max |data - ref|
%   lims = sls_clim(data, 0, 'Percentile', 99)  % clip the half-range to a percentile
%   lims = sls_clim(data, 0, 'Nice', true)      % round to 1 significant figure (31 -> 30)
%
% With 'Nice' (or 'Percentile' < 100) the limits may clip the data; then label the
% colorbar ends with '>=' and '<=' (e.g. '>=30', '<=-30').
%
% See also SLS_CMAP.

if nargin < 2 || isempty(center), center = 0; end
p = inputParser;
p.addParameter('Percentile', 100);
p.addParameter('Nice', false);
p.parse(varargin{:});

dev = abs(double(data(:)) - center);
dev = dev(isfinite(dev));
if isempty(dev)
    half = 1;
elseif p.Results.Percentile >= 100
    half = max(dev);
else
    half = prctile(dev, p.Results.Percentile);
end
if half == 0 || ~isfinite(half), half = 1; end
if p.Results.Nice
    k = floor(log10(half));
    x = half / 10^k;
    if abs(x - fix(x)) == 0.5, r = 2 * round(x / 2); else, r = round(x); end  % ties to even, as numpy
    half = r * 10^k;
end
lims = center + [-half half];
end
