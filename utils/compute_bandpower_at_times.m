% File: compute_bandpower_at_times_numeric.m
function BandPower = compute_bandpower_at_times(X, time_vector, Fs, win_len_sec, tvec1, tvec2)
    % Inputs:
    %   X:            n x t matrix of time series (each row is a signal)
    %   time_vector:  1 x t vector of time values for each column in X
    %   Fs:           Sampling frequency
    %   win_len_sec:  Past window length in seconds
    %   tvec1, tvec2: Vectors of timestamps at which to compute band power
    %
    % Output:
    %   BandPower: struct with fields:
    %       BandPower_Vec1: n x length(tvec1) x 3
    %       BandPower_Vec2: n x length(tvec2) x 3

    [n, T] = size(X);
    all_tvecs = {tvec1, tvec2};
    field_names = {'BandPower_Vec1', 'BandPower_Vec2'};

    % Define frequency bands
    bands = [1 3; 3 6; 6 Fs/2];
    num_bands = size(bands, 1);

    for vi = 1:2  % Loop over both timestamp vectors
        tvec = all_tvecs{vi};
        num_points = length(tvec);
        result = NaN(n, num_points, num_bands);  % n x timestamps x bands

        for i = 1:n
            xi = X(i, :);
            for j = 1:num_points
                t_sec = tvec(j);
                [~, t_idx] = min(abs(time_vector - t_sec));
                win_len_samples = round(win_len_sec * Fs);
                start_idx = t_idx - win_len_samples + 1;

                if start_idx < 1 || t_idx > T
                    continue;
                end

                segment = xi(start_idx:t_idx);
                if length(segment) < 4
                    continue;
                end

                [Pxx, f] = pwelch(segment, [], [], [], Fs);

                for b = 1:num_bands
                    f_idx = f >= bands(b,1) & f < bands(b,2);
                    result(i, j, b) = sum(Pxx(f_idx));
                end
            end
        end

        BandPower.(field_names{vi}) = result;
    end
end
