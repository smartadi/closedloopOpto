function [S, t, fctr] = stft_bands(x, w, noverlap, nfft, Fs, nBands)
%STFT_BANDS  Base-MATLAB replacement for the spectrogram call in controllerData.
%
%   [S, t, fctr] = stft_bands(x, w, noverlap, nfft, Fs, nBands)
%
%   S    : nBands x nSeg  ABSOLUTE power, |STFT|^2  (same as abs(S_spec(1:nBands,:)).^2)
%   t    : 1 x nSeg       segment-centre times in seconds
%   fctr : 1 x nBands     band centre frequencies in Hz
%
% Matches MATLAB's  spectrogram(x, w, noverlap, nfft, Fs)  for real x: each
% segment is multiplied by the window and FFT'd with NO normalisation, and the
% one-sided spectrum is the first nfft/2+1 bins. Only the first nBands bins are
% returned, which is all controllerData uses.
%
% WHY THIS EXISTS (2026-10-01). Signal Processing Toolbox is installed and
% entitled (`license('test','Signal_Toolbox')` = 1) but cannot be checked out:
% every call dies with MathWorks Licensing Error 15 / Feature: MATLAB, and a
% FRESH MATLAB process cannot start at all (error 5201). So the toolbox is
% unavailable for reasons that have nothing to do with this project, and a
% cache rebuild -- which needs `spectrogram` -- was blocked outright. Removing
% the dependency also means a reviewer without the toolbox can reproduce the
% spectral panels, same motivation as hann -> hannwin.
%
% VALIDATED by reproducing the CACHED ncFreqPow/ncFreqSpec of the thirteen
% existing controller sessions, which were produced by the real `spectrogram`.
%
% See also: hannwin, controllerData.

x = double(x(:))';
w = double(w(:));
nwin = numel(w);

if nargin < 4 || isempty(nfft),   nfft   = nwin; end
if nargin < 5 || isempty(Fs),     Fs     = 35;   end
if nargin < 6 || isempty(nBands), nBands = floor(nfft/2) + 1; end

assert(noverlap < nwin, 'stft_bands:overlap', 'noverlap must be < window length.');
hop  = nwin - noverlap;
nSeg = floor((numel(x) - noverlap) / hop);
assert(nSeg >= 1, 'stft_bands:short', 'Signal is shorter than one window.');
assert(nBands <= floor(nfft/2) + 1, 'stft_bands:nBands', ...
       'nBands (%d) exceeds the one-sided bin count (%d).', nBands, floor(nfft/2)+1);

S = zeros(nBands, nSeg);
for i = 1:nSeg
    a   = (i-1)*hop + 1;
    seg = x(a : a + nwin - 1)' .* w;
    X   = fft(seg, nfft);
    S(:, i) = abs(X(1:nBands)).^2;
end

% Segment-centre times, matching spectrogram's convention.
t    = ((0:nSeg-1)*hop + nwin/2) / Fs;
fctr = (0:nBands-1) * (Fs/nfft);
end
