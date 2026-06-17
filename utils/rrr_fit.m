function B_r = rrr_fit(X, Y, r)
% General reduced-rank regression (Ye et al. 2023).
% Maps X -> Y with a rank-r coefficient matrix.
%   X : [N x p] regressors
%   Y : [N x q] targets
%   r : target rank
% For q=1 collapses to OLS (rank-1 is full rank for a single output).
    B_ols = X \ Y;
    r     = min([r, size(B_ols,1), size(B_ols,2)]);
    Yhat  = X * B_ols;
    [~, ~, Vr] = svd(Yhat, 'econ');
    Pr    = Vr(:, 1:r) * Vr(:, 1:r)';
    B_r   = B_ols * Pr;
end
