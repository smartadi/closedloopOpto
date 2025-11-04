% File: compute_past_variance.m
function var_signal = compute_past_variance(x, Fs, win_len_sec)
    T = length(x);
    win_len_samples = round(win_len_sec * Fs);
    var_signal = NaN(1, T);  % Preallocate

    for t = 1:T
        start_idx = t - win_len_samples + 1;
        if start_idx < 1
            continue;  % Not enough data
        end
        segment = x(start_idx:t);
        var_signal(t) = var(segment, 1);  % Normalize by N (not N-1)
    end
end
