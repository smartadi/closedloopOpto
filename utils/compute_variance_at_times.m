% File: compute_variance_at_times.m
function var_out = compute_variance_at_times(X, time_vector, Fs, win_len_sec, tvec)
    % Inputs:
    %   X:            n x t matrix (each row is a time series)
    %   time_vector:  1 x t vector of actual time values
    %   Fs:           Sampling frequency
    %   win_len_sec:  Past window duration in seconds
    %   tvec:         1 x k vector of time points to compute variance at
    %
    % Output:
    %   var_out:      n x k matrix of variance values at given time points

    [n, T] = size(X);
    k = length(tvec);
    var_out = NaN(n, k);

    for j = 1:k
        t_sec = tvec(j);
        past_t_sec = t_sec - win_len_sec;

        [~, end_idx] = min(abs(time_vector - t_sec));
        [~, start_idx] = min(abs(time_vector - past_t_sec));

        if start_idx < 1 || end_idx > T || start_idx >= end_idx
            continue;
        end

        for i = 1:n
            segment = X(i, start_idx:end_idx);
            if length(segment) < 2 
                continue;
            end
            var_out(i, j) = var(segment, 1);  % population variance
        end
    end
end
