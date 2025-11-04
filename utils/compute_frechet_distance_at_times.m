% File: compute_frechet_distance_at_times.m
function frechet_distances = compute_frechet_distance_at_times(X1, X2, time_vector, Fs, win_len_sec, tvec)
    % Inputs:
    %   X1, X2:        n x t matrices (each row is a time series)
    %   time_vector:   1 x t time values (not assumed to start at 0)
    %   Fs:            Sampling frequency
    %   win_len_sec:   Past window length in seconds
    %   tvec:          1 x k vector of time points (in seconds) to evaluate distances
    %
    % Output:
    %   frechet_distances: n x k matrix of Fréchet distances at specified times

    [n, T] = size(X1);
    assert(all(size(X1) == size(X2)), 'X1 and X2 must be the same size');

    k = length(tvec);
    frechet_distances = NaN(n, k);

    for j = 1:k
        t_sec = tvec(j);
        past_t_sec = t_sec - win_len_sec;

        % Find index closest to t_sec and past_t_sec
        [~, end_idx] = min(abs(time_vector - t_sec));
        [~, start_idx] = min(abs(time_vector - past_t_sec));

        if start_idx < 1 || end_idx > T || start_idx >= end_idx
            continue;
        end

        for i = 1:n
            seg1 = X1(i, start_idx:end_idx);
            seg2 = X2(i, start_idx:end_idx);

            if length(seg1) < 4
                continue;
            end

            frechet_distances(i, j) = discrete_frechet(seg1, seg2);
        end
    end
end

% Helper function: Discrete Fréchet Distance
% function dist = discrete_frechet(P, Q)
%     n = length(P);
%     m = length(Q);
%     ca = -ones(n, m);
% 
%     function d = c(i, j)
%         if ca(i,j) > -1
%             d = ca(i,j);
%         elseif i == 1 && j == 1
%             d = norm(P(1) - Q(1));
%         elseif i > 1 && j == 1
%             d = max(c(i-1,1), norm(P(i) - Q(1)));
%         elseif i == 1 && j > 1
%             d = max(c(1,j-1), norm(P(1) - Q(j)));
%         else
%             d = max(min([c(i-1,j), c(i-1,j-1), c(i,j-1)]), norm(P(i) - Q(j)));
%         end
%         ca(i,j) = d;
%     end
% 
%     dist = c(n, m);
% end
