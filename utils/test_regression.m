%% lagged_lr_with_plots.m
% y_t = b0 + sum_j sum_l b(j,l)*X_{t-l,j} + sum_l a(l)*y_{t-l} + e_t
% Option 1 only: backslash OLS. Includes reconstruction plots.

clear; clc; close all;

%% --- USER INPUTS ---
% Replace with your own data (same length T)
% T = 500;
% y = filter(1,[1 -0.6 0.2], randn(T,1));   % AR(2)-like target
% X = [randn(T,1), randn(T,1)];             % two exogenous series (optional; [] if none)
% 
% pY = 2;            % # lags of y (AR terms)
% pX = 3;            % # lags of X
% train_ratio = 0.7; % chronological split


T = 400;
rng(0);

% n-dimensional X (here n = 3)
n = 3;
X = randn(T, n);

% Make y depend on X lags and y lags
true_a  = [0.5, -0.2];                   % y lags: a1,a2
true_B  = [ 0.8, -0.4;                   % for X(:,1): lags 1..pX
           -0.3,  0.6;                   % for X(:,2)
            0.5,  0.0];                  % for X(:,3)
pY = numel(true_a);
pX = size(true_B,2);

y = zeros(T,1);
for t = 1+max(pY,pX):T
    y(t) = ...
        1.0 ...                                            % intercept b0
      + true_a(1)*y(t-1) + true_a(2)*y(t-2) ...            % AR terms
      + sum(true_B(1,:).* [X(t-1,1), X(t-2,1)]) ...
      + sum(true_B(2,:).* [X(t-1,2), X(t-2,2)]) ...
      + sum(true_B(3,:).* [X(t-1,3), X(t-2,3)]) ...
      + 0.3*randn();                                       % noise
end

train_ratio = 0.7;

%% --- BUILD LAGGED DESIGN MATRIX ---
[Phi, y_aligned, maxLag] = buildLagMatrix(y, X, pY, pX);

% Split train/test
N   = size(Phi,1);
Ntr = floor(train_ratio * N);
Phi_tr = Phi(1:Ntr, :);         y_tr = y_aligned(1:Ntr);
Phi_te = Phi(Ntr+1:end, :);     y_te = y_aligned(Ntr+1:end);

%% --- FIT (Option 1: OLS with backslash) ---
beta    = Phi_tr \ y_tr;            % coefficients incl. intercept
yhat_tr = Phi_tr * beta;
yhat_te = Phi_te * beta;

% Reconstruct predictions aligned to original time base (NaN for first maxLag)
t_idx = (maxLag+1):T;               % indices where predictions exist
yhat_all_aligned = Phi * beta;      % all aligned preds (train+test)
yhat_full = NaN(T,1);
yhat_full(t_idx) = yhat_all_aligned;

%% --- METRICS ---
rmse_tr = sqrt(mean((y_tr - yhat_tr).^2));
rmse_te = sqrt(mean((y_te - yhat_te).^2));
fprintf('Train RMSE: %.4f | Test RMSE: %.4f\n', rmse_tr, rmse_te);

%% --- PLOTS: RECONSTRUCTION ---
% 1) Full-series reconstruction (with NaNs up front)
figure('Name','Full Reconstruction','NumberTitle','off');
plot(1:T, y, 'LineWidth', 1); hold on;
plot(1:T, yhat_full, 'LineWidth', 1);
xlabel('t'); ylabel('y');
title('Actual vs Predicted (Full Series)');
legend('Actual y','Predicted \hat{y}','Location','best'); grid on;

% 2) Test-slice reconstruction only
figure('Name','Test Reconstruction','NumberTitle','off');
t_test = t_idx(Ntr+1:end);  % original-time indices for test region
plot(t_test, y(t_test), 'LineWidth', 1); hold on;
plot(t_test, yhat_te, 'LineWidth', 1);
xlabel('t'); ylabel('y');
title('Actual vs Predicted (Test Segment)');
legend('Actual y (test)','Predicted \hat{y} (test)','Location','best'); grid on;

% 3) Test residuals
figure('Name','Test Residuals','NumberTitle','off');
plot(t_test, y(t_test) - yhat_te, 'LineWidth', 1);
xlabel('t'); ylabel('Residual'); grid on;
title('Residuals on Test Segment');


