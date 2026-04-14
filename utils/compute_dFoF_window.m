function [dFoverF, Fmean, windowSamples] = compute_dFoF_window(F, tOrFs, windowSec)
% COMPUTE_DFOF_WINDOW Compute dF/F (%) for all traces using a window in seconds.
%   F must be [nTraces x nTime].
%   tOrFs can be either:
%     - time vector of length nTime, or
%     - scalar sampling frequency Fs (Hz).
%   windowSec is the mean window size in seconds.
%
%   Output:
%     dFoverF      [nTraces x nTime] dF/F in percent
%     Fmean        [nTraces x nTime] trailing-window mean baseline
%     windowSamples scalar window size in samples

if nargin < 3
    error('Usage: compute_dFoF_window(F, tOrFs, windowSec)');
end

if ndims(F) ~= 2
    error('F must be a 2D matrix [nTraces x nTime].');
end

if isempty(F)
    dFoverF = F;
    Fmean = F;
    windowSamples = 0;
    return;
end

if ~isscalar(windowSec) || windowSec <= 0
    error('windowSec must be a positive scalar in seconds.');
end

nTime = size(F, 2);

if isscalar(tOrFs)
    Fs = tOrFs;
    if Fs <= 0
        error('Sampling frequency Fs must be positive.');
    end
else
    t = tOrFs(:)';
    if numel(t) ~= nTime
        error('Time vector length must match size(F,2).');
    end
    dt = median(diff(t));
    if dt <= 0
        error('Time vector must be strictly increasing.');
    end
    Fs = 1 / dt;
end

windowSamples = max(1, round(windowSec * Fs));

% Trailing mean baseline (matches existing horizon-style logic)
Fmean = movmean(F, [windowSamples - 1, 0], 2);

smallMask = abs(Fmean) < eps;
if any(smallMask, 'all')
    Fmean(smallMask) = eps;
end

dFoverF = (F - Fmean) ./ Fmean * 100;
end
