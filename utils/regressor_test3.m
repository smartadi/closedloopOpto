%% plot_original_reconstruction_test_and_X.m
clear; clc; close all;

%% --- Deterministic exogenous (n-D) ---
T = 960;  t = (0:T-1)';  n = 5;
X1 = 2.5 + 2.5*sin(2*pi*t/24);            % [0..5] seasonality
X2 = linspace(0, 1e6, T)';                % 0..1e6 ramp
X3 = cos(2*pi*t/60);                      % [-1..1]
X4 = 100*(t/T).^2;                        % ~[0..100] smooth growth
X5 = 2*(mod(floor(t/50),2)==0)-1;         % {-1,1} step every 50
X  = [X1 X2 X3 X4 X5];

%% --- True model (no noise, no y-lags) ---
b0 = 12; pX = 2; pY = 0; maxLag = max(pY,pX);
season = 0.5*sin(2*pi*t/12+pi/3);
y = NaN(T,1);
for tt = (maxLag+1):T
    y(tt) = b0 ...
        + 0.6    * X1(tt-1) ...
        + 0.9e-6 * X2(tt-2) ...
        - 0.4    * X3(tt-1) ...
        + 0.2    * X4(tt-2) ...
        - 0.7    * X5(tt-1) ...
        + season(tt);
end
y(1:maxLag) = b0 + season(1:maxLag);

%% --- Split ---
train_ratio = 0.7;
Ntr = floor(train_ratio*T);
idx_tr = 1:Ntr; idx_te = (Ntr+1):T;
X_tr = X(idx_tr,:);  X_te = X(idx_te,:);
y_tr = y(idx_tr);    y_te = y(idx_te);

%% --- Train-only zscore ---
[X_tr_z, muX, sdX] = zscore(X_tr); sdX(sdX<eps)=1;
X_te_z = (X_te - muX) ./ sdX;
[y_tr_z, muy, sdy] = zscore(y_tr); sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

%% --- Build lagged design (no leakage) ---
[Phi_tr, y_tr_aligned] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

%% --- Fit & predict (scaled space) ---
beta         = Phi_tr \ y_tr_aligned;
yhat_tr_scal = Phi_tr * beta;
yhat_te_scal = Phi_te  * beta;

%% --- Invert y scaling & align ---
yhat_tr = yhat_tr_scal * sdy + muy;
yhat_te = yhat_te_scal * sdy + muy;
y_tr_raw_aligned = y_tr((maxLag+1):end);
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_tr_full = NaN(Ntr,1);           yhat_tr_full((maxLag+1):end) = yhat_tr;
yhat_te_full = NaN(T-Ntr,1);         yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_tr_full; yhat_te_full];

%% --- Metrics ---
rmse_tr = sqrt(mean((y_tr_raw_aligned - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw_aligned - yhat_te).^2));
fprintf('maxLag=%d | RMSE Train=%.6f  Test=%.6f\n', maxLag, rmse_tr, rmse_te);

%% --- PLOTS: X (original scale), Original y, Reconstruction, Test-only ---
% A) Plot X (original scale), one subplot per column, with train/test split line
figure('Name','Exogenous X (original scale)','NumberTitle','off');
tiledlayout(n,1,'TileSpacing','compact','Padding','compact');
for j = 1:n
    nexttile;
    plot(t, X(:,j), 'LineWidth', 1); grid on;
    xline(Ntr, '--');  % train/test split
    ylabel(sprintf('X_%d', j));
    if j==1, title('Exogenous series X (original scale)'); end
    if j==n, xlabel('t'); end
end

% B) Original y
figure('Name','Original y','NumberTitle','off');
plot(t, y, 'LineWidth', 1); grid on; xlabel('t'); ylabel('y'); title('Original y'); xline(Ntr,'--');

% C) Reconstruction (full)
figure('Name','Reconstruction (Full Series)','NumberTitle','off');
plot(t, y, 'LineWidth', 1); hold on;
plot(t, yhat_all_full, 'LineWidth', 1);
grid on; xlabel('t'); ylabel('y');
title(sprintf('Reconstruction (Full) | maxLag=%d', maxLag));
legend('Original','Predicted','Location','best');
xline(Ntr,'--');

% D) Test segment only
figure('Name','Test Segment: Original vs Predicted','NumberTitle','off');
tt = (Ntr+1):T;
plot(tt, y(tt), 'LineWidth', 1); hold on;
plot(tt, yhat_te_full, 'LineWidth', 1);
grid on; xlabel('t'); ylabel('y');
title('Test Segment: Original vs Predicted');
legend('Original (test)','Predicted (test)','Location','best');

% %% --- Helper (original format) ---
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
%     k = 1 + pY + d*pX; Phi = ones(numel(idx), k); col = 2;
%     for l=1:pY, Phi(:,col)=y(idx-l); col=col+1; end
%     if ~isempty(X) && pX>0
%         for j=1:d, for l=1:pX, Phi(:,col)=X(idx-l,j); col=col+1; end, end
%     end
% end
