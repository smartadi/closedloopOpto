function w = hannwin(N)
%HANNWIN  Symmetric Hann window - toolbox-free replacement for the Signal
%         Processing Toolbox window function of the same shape.
%
%   w = hannwin(N)   returns an N-by-1 symmetric Hann (raised-cosine) window,
%                    numerically identical to the toolbox symmetric window.
%
% WHY THIS EXISTS (2026-10-01). This machine's MATLAB licence does not cover the
% Signal Processing Toolbox: the toolbox is installed and license('test',...)
% returns 1, but license('checkout','Signal_Toolbox') returns 0 and the toolbox
% window function throws MathWorks Licensing Error 15. That blocked every
% spectral analysis in the paper. A Hann window is one line of arithmetic, so
% the dependency was removed rather than worked around. It also means a reader
% without the toolbox can reproduce the spectral results.
%
% THE CONVENTION MATTERS - READ BEFORE EDITING. The toolbox ships two similar
% windows and they are NOT interchangeable:
%
%   SYMMETRIC (the default, and what this file implements):
%       w(k) = 0.5*(1 - cos(2*pi*k/(N-1))),  k = 0..N-1,  endpoints exactly 0
%   PERIODIC (the 'periodic' option) divides by N instead of N-1, and the
%       legacy HANNING function uses an interior-points convention. Neither has
%       zero endpoints.
%
% Every call site in this repo used the plain, symmetric form, so that is what
% is reproduced here. Substituting a periodic window would shift every
% band-power number in the paper slightly and SILENTLY - nothing would error.
% If you change this function, re-run every spectral panel.
%
% VERIFIED (2026-10-01), all against the toolbox-free analytic identities, since
% the toolbox cannot be called on this machine to compare directly:
%   N = 8   matches the standard symmetric values
%           [0 0.1883 0.6113 0.9505 0.9505 0.6113 0.1883 0]   (max err 4.5e-05,
%           which is the rounding in those published 4-decimal values)
%   N = 70  sum(w)    = 34.5     = (N-1)/2     exactly
%           sum(w.^2) = 25.875   = 3*(N-1)/8   exactly
%   endpoints exactly 0; asymmetry 3.3e-16 (~1.5 eps, the same floating-point
%   dust the toolbox version carries from its own cosine evaluation).
%
% See also: utils/cl_reldelta.m, utils/imp_trial_states.m

if ~isscalar(N) || ~isfinite(N) || N < 0 || N ~= fix(N)
    error('hannwin:badN', 'N must be a non-negative integer scalar.');
end

if N == 0
    w = zeros(0, 1);
    return
elseif N == 1
    w = 1;                      % matches the toolbox value for a 1-point window
    return
end

k = (0:N-1).';
w = 0.5 * (1 - cos(2*pi*k / (N-1)));

% Kill the floating-point dust at the endpoints so the zeros are exact, as they
% are in the toolbox version (cos(2*pi) returns 1 to within eps, not exactly).
w(1)   = 0;
w(end) = 0;
end
