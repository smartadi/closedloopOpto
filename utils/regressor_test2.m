%% lagged_regression_with_matlab_zscore_deterministic.m
% Deterministic example (no randomness). Uses MATLAB zscore on TRAIN only.
clear; clc; close all;

%% --- DETERMINISTIC EXOGENOUS SERIES (n-D) ---
T = 720;                      % e.g., 30 days of hourly samples
t = (0:T-1)';                 % time index

% X1: bounded seasonality in [0,5]  (e.g., daily cycle with slight trend)
X1 = 2.5 + 2.5*sin(2*pi*t/24) + 0.002*(t/T);  % 0..5-ish

% X2: large linear ramp from 0 to ~1e6
X2 = linspace(0, 1e6, T)';                     % 0..1,000,000

% X3: square wave in [-1,1] with period 48 (2 cycles per day)
X3 = sign(sin(2*pi*t/48));
X = [X1, X2, X3];

%% --- TRUE DATA-GENERATING MODEL (no noise, no y-lags) ---
% y_t = b0 + 0.8*X1_{t-1} + 0.7e-6*X2_{t-2} - 0.5*X3_{t-1} + small deterministic season term
b0   = 10;
pX   = 2;             % we will include 2 lags for X in the regression
pY   = 0;             % no y as input
maxLag = max(pY, pX);

y = NaN(T,1);
% small deterministic season term at 12-hour harmonic
season = 0.4*sin(2*pi*t/12);
for tt = (maxLag+1):T
    y(tt) = b0 ...
          + 0.8  * X1(tt-1) ...
          + 0.7e-6 * X2(tt-2) ...
          - 0.5  * X3(tt-1) ...
          + season(tt);
end
% Fill first maxLag with the model's offset/season only (or leave as NaN if you prefer)
y(1:maxLag) = b0 + season(1:maxLag);

%% --- TRAIN/TEST SPLIT (chronological) ---
train_ratio = 0.7;
Ntr = floor(train_ratio*T);
idx_tr = 1:Ntr; idx_te = (Ntr+1):T;

X_tr = X(idx_tr,:);  X_te = X(idx_te,:);
y_tr = y(idx_tr);    y_te = y(idx_te);

%% --- SCALE WITH MATLAB zscore (TRAIN ONLY) ---
[X_tr_z, muX, sdX] = zscore(X_tr); sdX(sdX<eps)=1;     % columnwise
X_te_z = (X_te - muX) ./ sdX;

[y_tr_z, muy, sdy] = zscore(y_tr); sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

%% --- BUILD LAGGED DESIGN MATRICES (NO LEAKAGE) ---
[Phi_tr, y_tr_aligned] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

fprintf('maxLag = %d (pY=%d, pX=%d)\n', maxLag, pY, pX);

%% --- FIT (OLS) & PREDICT IN SCALED SPACE ---
beta         = Phi_tr \ y_tr_aligned;
yhat_tr_scal = Phi_tr * beta;
yhat_te_scal = Phi_te  * beta;

%% --- INVERT y SCALING TO ORIGINAL UNITS ---
yhat_tr = yhat_tr_scal * sdy + muy;
yhat_te = yhat_te_scal * sdy + muy;

% Align raw y for metrics/plots (drop first maxLag of each split)
y_tr_raw_aligned = y_tr((maxLag+1):end);
y_te_raw_aligned = y_te((maxLag+1):end);

rmse_tr = sqrt(mean((y_tr_raw_aligned - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw_aligned - yhat_te).^2));
fprintf('RMSE (orig units)  Train: %.6f | Test: %.6f\n', rmse_tr, rmse_te);

%% --- RECONSTRUCT ON ORIGINAL TIME AXIS ---
yhat_tr_full = NaN(Ntr,1);           yhat_tr_full((maxLag+1):end) = yhat_tr;
yhat_te_full = NaN(T-Ntr,1);         yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_tr_full; yhat_te_full];

%% --- PLOTS ---
figure('Name','Exogenous Series','NumberTitle','off');
subplot(3,1,1); plot(t, X1); grid on; ylabel('X1 (0..5)'); title('Deterministic Inputs');
subplot(3,1,2); plot(t, X2); grid on; ylabel('X2 (~0..1e6)');
subplot(3,1,3); plot(t, X3); grid on; ylabel('X3 (-1..1)'); xlabel('t');

figure('Name','Actual vs Predicted (Full Series)','NumberTitle','off');
plot(t, y, 'LineWidth', 1); hold on;
plot(t, yhat_all_full, 'LineWidth', 1);
grid on; xlabel('t'); ylabel('y');
title(sprintf('Actual vs Predicted | maxLag=%d', maxLag));
legend('Actual','Predicted','Location','best');

figure('Name','Test Segment Reconstruction','NumberTitle','off');
tt = (Ntr+1):T;
plot(tt, y(tt), 'LineWidth', 1); hold on;
plot(tt, yhat_te_full, 'LineWidth', 1);
grid on; xlabel('t'); ylabel('y');
title('Test Segment: Actual vs Predicted');
legend('Actual (test)','Predicted (test)','Location','best');

%% --- Inspect learned coefficients (optional, scaled space) ---
% Columns: [Intercept, X1_lag1, X1_lag2, X2_lag1, X2_lag2, X3_lag1, X3_lag2]
disp('Beta (scaled-space):'); disp(beta.');

%% --------- HELPER (original format) ----------
% function [Phi, y_out, maxLag] = buildLagMatrix(y, X, pY, pX)
%     if nargin < 2 || isempty(X), X = []; end
%     if nargin < 3, pY = 0; end
%     if nargin < 4, pX = 0; end
%     T = size(y,1); d = size(X,2);
%     maxLag = max(pY, pX);
%     if maxLag == 0
%         Phi = ones(T,1); if ~isempty(X), Phi=[Phi X]; end
%         y_out = y; return;
%     end
%     if T <= maxLag, error('Not enough samples: T=%d, maxLag=%d.', T, maxLag); end
%     idx = (maxLag+1):T; y_out = y(idx);
%     k = 1 + pY + d*pX; Phi = ones(numel(idx),k); col = 2;
%     % y-lags (none here since pY=0 by default)
%     for l=1:pY, Phi(:,col)=y(idx-l); col=col+1; end
%     % X-lags (by variable then lag)
%     if ~isempty(X) && pX>0
%         for j=1:d
%             for l=1:pX
%                 Phi(:,col) = X(idx-l, j);
%                 col = col + 1;
%             end
%         end
%     end
% end
