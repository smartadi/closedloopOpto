function var_signal = compute_past_variance(x, Fs, win_len_sec)
% Causal sliding variance over a past window of win_len_sec seconds.
% Returns NaN for samples where the full window is not yet available.
    win = round(win_len_sec * Fs);
    T   = numel(x);

    % O(T) via cumulative sums: var = E[X²] - (E[X])²
    cs1 = [0, cumsum(x(:)')];
    cs2 = [0, cumsum(x(:)'.^2)];

    t_valid  = win:T;
    sum_x    = cs1(t_valid + 1) - cs1(t_valid - win + 1);
    sum_x2   = cs2(t_valid + 1) - cs2(t_valid - win + 1);
    var_signal = [NaN(1, win-1), (sum_x2 - sum_x.^2 / win) / win];
end
