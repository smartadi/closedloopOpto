function band_ratio = compute_bandpower_sliding(x, Fs, win_len_sec)
% Causal sliding band-power ratios. Returns NaN for samples where the full
% window is not yet available.
% Replaces a per-sample pwelch loop with a single batch FFT (M x W matrix).
%
% Outputs band_ratio: T x 3 matrix
%   col 1: [0–6 Hz] / total
%   col 2: [3–6 Hz] / total
%   col 3: [6–Nyquist] / total

    x   = x(:)';
    T   = numel(x);
    W   = round(win_len_sec * Fs);

    bands    = [0, 6; 3, 6; 6, Fs/2];
    num_bands = size(bands, 1);

    band_ratio = NaN(T, num_bands);

    t_valid = W:T;
    M = numel(t_valid);
    if M == 0 || W < 4; return; end

    % Build M x W window matrix via index striding (no loop)
    col_idx  = t_valid(:) - (W-1:-1:0);   % M x W indices into x
    win_mat  = x(col_idx);                 % M x W signal windows

    % Hann taper to reduce spectral leakage (row broadcast)
    win_mat = win_mat .* hann(W)';         % M x W

    % Single batch FFT across all M windows simultaneously
    nfft  = W;
    X     = fft(win_mat, nfft, 2);         % M x nfft

    % One-sided PSD (normalization cancels in the ratio, but keep it correct)
    nFreq = floor(nfft/2) + 1;
    Pxx   = abs(X(:, 1:nFreq)).^2;
    Pxx(:, 2:end-1) = 2 * Pxx(:, 2:end-1);  % fold negative frequencies

    % Frequency axis
    f = (0:nFreq-1) * (Fs / nfft);         % 1 x nFreq

    % Total power denominator (0 to Nyquist)
    total_power = sum(Pxx, 2);             % M x 1
    bad = total_power <= 0 | ~isfinite(total_power);

    % Band ratios — each band is a vectorised column sum
    for b = 1:num_bands
        f_idx = (f >= bands(b,1)) & (f < bands(b,2));
        ratio = sum(Pxx(:, f_idx), 2) ./ total_power;  % M x 1
        ratio(bad) = NaN;
        band_ratio(t_valid, b) = ratio;
    end
end
