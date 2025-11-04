% File: frechet_distance_sliding.m
function dists = frechet_distance_sliding(x1, x2, Fs, win_len_sec)
    assert(length(x1) == length(x2), 'Signals must be same length');
    
    T = length(x1);
    win_len_samples = round(win_len_sec * Fs);
    dists = NaN(1, T);

    for t = 1:T
        start_idx = t - win_len_samples + 1;
        if start_idx < 1
            continue;
        end
        seg1 = x1(start_idx:t);
        seg2 = x2(start_idx:t);

        dists(t) = discrete_frechet(seg1, seg2);
    end
end
