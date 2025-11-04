% File: compute_bandpower_for_matrix.m
function band_structs = compute_bandpower_for_matrix(X, Fs, win_len_sec)
    % X: n x t matrix (n time series, each length t)
    % Fs: sampling rate
    % win_len_sec: window length in seconds
    % Returns: struct array with fields band1, band2, band3

    [n, t] = size(X);
    band_structs = struct('band1', [], 'band2', [], 'band3', []);

    for i = 1:n
        xi = X(i, :);
        bp = compute_bandpower_past_window(xi, Fs, win_len_sec);

        band_structs(i).band1 = bp(:, 1);
        band_structs(i).band2 = bp(:, 2);
        band_structs(i).band3 = bp(:, 3);
    end
end
