% % File: compute_bandpower_sliding.m
% function band_power = compute_bandpower_sliding(x, Fs, win_len_sec, overlap_sec)
%     % Convert time to samples
%     win_len_samples = round(win_len_sec * Fs);
%     overlap_samples = round(overlap_sec * Fs);
%     hop_size = win_len_samples - overlap_samples;
% 
%     % Frequency bands in Hz
%     bands = [1 3; 3 6; 6 Fs/2];  % Fs/2 = Nyquist limit
% 
%     % Initialize output
%     num_windows = floor((length(x) - overlap_samples) / hop_size);
%     band_power = zeros(num_windows, size(bands, 1));
% 
%     % Loop over windows
%     for i = 1:num_windows
%         start_idx = (i - 1) * hop_size + 1;
%         end_idx = start_idx + win_len_samples - 1;
%         if end_idx > length(x)
%             break;
%         end
%         segment = x(start_idx:end_idx);
% 
%         % Welch PSD
%         [Pxx, f] = pwelch(segment, [], [], [], Fs);
% 
%         % Band power calculation
%         for b = 1:size(bands, 1)
%             f_idx = f >= bands(b, 1) & f < bands(b, 2);
%             band_power(i, b) = sum(Pxx(f_idx));
%         end
%     end
% end


% File: compute_bandpower_samplewise.m
% function band_power = compute_bandpower_sliding(x, Fs, win_len_sec)
%     T = length(x);
%     win_len_samples = round(win_len_sec * Fs);
%     half_win = floor(win_len_samples / 2);
% 
%     % Define frequency bands: 1–3, 3–6, 6–Nyquist
%     bands = [1 3; 3 6; 6 Fs/2];
%     num_bands = size(bands, 1);
% 
%     band_power = NaN(T, num_bands);  % Preallocate
% 
%     for t = 1:T
%         % Compute window bounds
%         start_idx = max(1, t - half_win);
%         end_idx = min(T, t + half_win);
% 
%         segment = x(start_idx:end_idx);
%         if length(segment) < 4  % Too short for PSD
%             continue;
%         end
% 
%         % Welch PSD
%         [Pxx, f] = pwelch(segment, [], [], [], Fs);
% 
%         % Compute power per band
%         for b = 1:num_bands
%             f_idx = f >= bands(b,1) & f < bands(b,2);
%             band_power(t, b) = sum(Pxx(f_idx));
%         end
%     end
% end


% File: compute_bandpower_past_window.m
function band_power = compute_bandpower_sliding(x, Fs, win_len_sec)
    T = length(x);
    win_len_samples = round(win_len_sec * Fs);

    % Define bands: 1–3, 3–6, 6–Nyquist
    bands = [1 3; 3 6; 6 Fs/2];
    num_bands = size(bands, 1);

    band_power = NaN(T, num_bands);  % Preallocate

    for t = 1:T
        start_idx = t - win_len_samples + 1;
        if start_idx < 1
            continue;  % Not enough past data
        end

        segment = x(start_idx:t);
        if length(segment) < 4  % Too short for PSD
            continue;
        end

        [Pxx, f] = pwelch(segment, [], [], [], Fs);

        for b = 1:num_bands
            f_idx = f >= bands(b,1) & f < bands(b,2);
            band_power(t, b) = sum(Pxx(f_idx));
        end
    end
end
