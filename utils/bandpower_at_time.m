% File: bandpower_at_time.m
function bp = bandpower_at_time(x, Fs, win_len_sec, t)
    % Inputs:
    %   x: signal (1D vector)
    %   Fs: sampling frequency
    %   win_len_sec: window length in seconds
    %   t: time index in samples (integer)
    % Output:
    %   bp: 1x3 vector of band powers [1–3Hz, 3–6Hz, 6Hz+]

    win_len_samples = round(win_len_sec * Fs);
    start_idx = t - win_len_samples + 1;

    if start_idx < 1 || t > length(x)
        bp = [NaN NaN NaN];
        return;
    end

    segment = x(start_idx:t);
    if length(segment) < 4
        bp = [NaN NaN NaN];
        return;
    end

    % Frequency bands
    bands = [1 3; 3 6; 6 Fs/2];

    [Pxx, f] = pwelch(segment, [], [], [], Fs);

    bp = zeros(1, size(bands,1));
    for b = 1:size(bands,1)
        idx = f >= bands(b,1) & f < bands(b,2);
        bp(b) = sum(Pxx(idx));
    end
end
