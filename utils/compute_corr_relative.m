function corr_coeffs = compute_corr_first_variable(time_series, time_vector, t_idx, W_seconds)
    % time_series: N x t matrix of time series data
    % time_vector: vector of time values corresponding to each column in time_series
    % t_idx: vector of actual time points for which correlation is computed
    % W_seconds: window length in seconds (how far back in time to consider)
    
    % Get the number of variables (N) and time points (t)
    [N, t] = size(time_series);
    
    % Initialize the output vector for correlation coefficients
    corr_coeffs = zeros(length(t_idx), N-1);
    
    % Loop over each time index in t_idx
    for i = 1:length(t_idx)
        % Get the current time index (from time_vector)
        current_time = t_idx(i);

        % Find the index in time_vector corresponding to the current time
        [~, current_idx] = min(abs(time_vector - current_time));
        
        % Calculate the corresponding window size in terms of indices
        % Find the indices where the time difference from current_time is <= W_seconds
        window_indices = find(time_vector <= current_time & time_vector >= current_time - W_seconds);
        
        % Check if the window is valid (we need at least W data points)
        if length(window_indices) >= 2
            % Extract the past window of data for all variables (rows) using window_indices
            past_data = time_series(:, window_indices);
            
            % Extract the first variable's time series over the window
            first_var = past_data(1, :);
            
            % Compute the correlation between the first variable and all other variables
            for j = 2:N  % Start from 2, because we want to exclude the first variable
                corr_coeffs(i, j-1) = corr(first_var', past_data(j, :)');
            end
        else
            warning(['Not enough data to compute correlation for time index ', num2str(current_time), ' with window size ', num2str(W_seconds), ' seconds.']);
        end
    end
end
