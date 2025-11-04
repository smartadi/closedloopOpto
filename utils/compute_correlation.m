function R = compute_correlation(X, t, t0, window_size)
% corrAtTime computes correlation matrix between N signals over a time window.
%
% Inputs:
%   X           - N x T matrix, N signals (rows), T time steps (columns)
%   t           - 1 x T or T x 1 time vector
%   t0          - scalar, current time (end of window)
%   window_size - scalar, duration of time window
%
% Output:
%   R           - N x N correlation matrix (NaN if not enough points)

    % Ensure proper dimensions
    [N, T] = size(X);
    t = t(:);  % ensure column vector
    if length(t) ~= T
        error('Time vector length must match number of columns in X.');
    end

    % Find indices in the window [t0 - window_size, t0]
    idx = find(t >= (t0 - window_size) & t <= t0);

    if numel(idx) < 2
        warning('Not enough points in the window to compute correlation.');
        R = NaN(N, N);
        return;
    end

    % Extract windowed data: N x length(idx)
    X_window = X(:, idx);

    % Compute correlation across rows → transpose to: observations x variables
    R = corrcoef(X_window.');
end
