function p = f4_bandpow(seg, Fs, lo, hi, method)
%F4_BANDPOW  Band power of one trace segment, the ONE estimator for Fig-4 spectral states.
%
%   p = f4_bandpow(seg, Fs, lo, hi)                 % 'continuous' (default, paper)
%   p = f4_bandpow(seg, Fs, lo, hi, 'bins')         % legacy, pre-2026-10-02
%
% Both methods: linear detrend -> Hann taper -> one-sided periodogram.
%
% 'bins' (LEGACY). Sums |FFT|^2 over the native FFT bins with lo <= f < hi. The bin spacing is
%   Fs/N, so WHICH bins fall inside the band depends on the segment length N. Measured
%   2026-10-02: moving the Fig-4 window from 176 to 175 samples shifts the 2-4 Hz band from
%   2.19-3.98 Hz to 2.00-3.80 Hz; on a 1/f spectrum the 2.0 Hz bin dominates, and the
%   relative-2-4 Hz results moved accordingly (Fig-4D controllability p 0.074 -> 0.0086;
%   Fig-4C steady-state unique R^2 0.134 -> 0.232) from a ONE-SAMPLE change. A result that
%   depends on where a band edge lands on the FFT grid is not a property of the data.
%
% 'continuous' (PAPER). Power spectral density on a fixed fine grid (zero-padded FFT,
%   NFFT >= 8192, spacing <= 0.0043 Hz at 35 Hz), normalised by the window energy so it is a
%   true density in (dF/F)^2/Hz independent of N, then integrated (trapezoid) between the
%   EXACT band limits, with the PSD interpolated at lo and hi. The band integral is therefore
%   continuous in the band edges and in N: one extra sample changes it by one sample's worth
%   of data, not by a whole bin. Zero-padding adds no resolution -- it removes the grid
%   dependence, which is the point. Units: (dF/F)^2, i.e. absolute power in the band.
if nargin < 5 || isempty(method), method = 'continuous'; end
seg = detrend(double(seg(:)).', 'linear');
N   = numel(seg);
w   = hannwin(N).';
switch lower(method)
    case 'bins'
        P  = abs(fft(seg.*w)).^2;  P = P(1:floor(N/2)+1);
        fr = (0:floor(N/2))*Fs/N;
        p  = sum(P(fr>=lo & fr<hi));
    case 'continuous'
        nfft = max(8192, 2^nextpow2(8*N));
        X    = fft(seg.*w, nfft);
        psd  = abs(X(1:nfft/2+1)).^2 / (Fs * sum(w.^2));   % density, (dF/F)^2 / Hz
        psd(2:end-1) = 2*psd(2:end-1);                     % one-sided
        f    = (0:nfft/2) * Fs/nfft;
        inb  = f > lo & f < hi;
        fb   = [lo, f(inb), hi];
        pb   = [interp1(f, psd, lo), psd(inb), interp1(f, psd, hi)];
        p    = trapz(fb, pb);
    otherwise
        error('f4_bandpow:method', 'method must be ''continuous'' or ''bins''.');
end
end
