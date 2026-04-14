% File: compute_bandpower_past_window_ratio.m
function band_ratio = compute_bandpower_sliding(x, Fs, win_len_sec)
    T = length(x);
    win_len_samples = round(win_len_sec * Fs);

    % Define bands: 1–3, 3–6, 6–Nyquist
    bands = [0 6; 3 6; 6 Fs/2];
    num_bands = size(bands, 1);

    band_ratio = NaN(T, num_bands);  % Preallocate

    for t = 1:T
        start_idx = t - win_len_samples + 1;
        if start_idx < 1
            continue;  % Not enough past data
        end

        segment = x(start_idx:t);
        if numel(segment) < 4
            continue;
        end

        % Welch PSD
        [Pxx, f] = pwelch(segment, [], [], [], Fs);

        % ---- Total power over the "entire band" ----
        % Use 1 Hz to Nyquist to match your band definitions
        f_total_idx = (f >= 0) & (f <= Fs/2);
        total_power = sum(Pxx(f_total_idx));

        if total_power <= 0 || ~isfinite(total_power)
            continue; % avoid divide-by-zero / weird PSD edge cases
        end

        % ---- Band ratios ----
        for b = 1:num_bands
            f_idx = (f >= bands(b,1)) & (f < bands(b,2));
            band_ratio(t, b) = sum(Pxx(f_idx)) / total_power;
        end
    end
end