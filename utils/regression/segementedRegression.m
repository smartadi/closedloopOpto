%% segmented_lagged_regression.m
% Data format:
%   y_mat    : L x S   (L = length per segment, S = #segments)
%   X_tensor : L x n x S   (n = # exogenous inputs) or [] if none
%
% Set pY=0 to exclude y-lags ("no y as input"). Uses MATLAB zscore.
 clc; close all;clear all;

%% --- USER DATA (REPLACE) ---
% Example placeholders (deterministic). Replace y_mat / X_tensor with your own.
L = 200; S = 6; t = (1:L)'; n = 3;
X_tensor = zeros(L, n, S);
for s = 1:S
    X_tensor(:,1,s) = 2.5 + 2.5*sin(2*pi*(t+(s-1)*5)/24); % 0..5-ish
    X_tensor(:,2,s) = linspace(0, 1e6, L)';               % 0..1e6 ramp
    X_tensor(:,3,s) = (-1).^(floor((t+(s-1)*20)/40));     % {-1,1} blocks
end
% True model (no y-lags)
pY = 0; pX = 2; maxLag = max(pY,pX);
b0 = 10;
y_mat = NaN(L,S);
for s = 1:S
    X1 = X_tensor(:,1,s); X2 = X_tensor(:,2,s); X3 = X_tensor(:,3,s);
    for tt = (maxLag+1):L
        y_mat(tt,s) = b0 ...
            + 0.7   * X1(tt-1) ...
            + 0.8e-6* X2(tt-2) ...
            - 0.6   * X3(tt-1);
    end
    y_mat(1:maxLag,s) = b0; % fill first maxLag (or leave NaN)
end

%% --- TRAIN/TEST SPLIT BY SEGMENTS ---
train_ratio_segments = 0.67;               % e.g., 2/3 of segments for train
Str = max(1, floor(train_ratio_segments * S));
trainSegs = 1:Str;                          % simple: first Str segments
testSegs  = (Str+1):S;

%% --- SCALE WITH MATLAB zscore (TRAIN SEGMENTS ONLY) ---
% Stack train segments vertically to compute per-column stats
y_tr_stack = y_mat(:, trainSegs); y_tr_stack = y_tr_stack(:);
[y_tr_z, muy, sdy] = zscore(y_tr_stack); sdy = max(sdy, eps);

if ~isempty(X_tensor)
    X_tr_stack = reshape(X_tensor(:, :, trainSegs), [], n);  % (L*Str) x n
    [X_tr_z_stack, muX, sdX] = zscore(X_tr_stack); sdX(sdX<eps) = 1;
    % Apply to all segments
    X_z = zeros(size(X_tensor));
    for s = 1:S
        Xz_s = reshape(X_tensor(:, :, s), [], n);
        Xz_s = (Xz_s - muX) ./ sdX;          % train stats applied
        X_z(:, :, s) = reshape(Xz_s, L, n);
    end
else
    X_z = [];
end
% Apply y scaling to all segments
y_z = (y_mat - muy) ./ sdy;

%% --- BUILD DESIGN MATRICES (NO LEAKAGE, WITHIN-SEGMENT LAGS) ---
[Phi_tr, y_tr_vec, maxLag, seg_tr, t_tr] = ...
    buildLagMatrix_segments(y_z(:, trainSegs), X_z(:, :, trainSegs), pY, pX);

[Phi_te, y_te_vec] = deal([]); seg_te=[]; t_te=[];
if ~isempty(testSegs)
    [Phi_te, y_te_vec, ~, seg_te, t_te] = ...
        buildLagMatrix_segments(y_z(:, testSegs), X_z(:, :, testSegs), pY, pX);
end

%% --- FIT & PREDICT IN SCALED SPACE ---
beta = Phi_tr \ y_tr_vec;
yhat_tr_scaled = Phi_tr * beta;
yhat_te_scaled = []; if ~isempty(Phi_te), yhat_te_scaled = Phi_te * beta; end

%% --- INVERT y SCALING TO ORIGINAL UNITS ---
yhat_tr = yhat_tr_scaled * sdy + muy;
yhat_te = yhat_te_scaled * sdy + muy;

%% --- RECONSTRUCT PREDICTIONS BACK TO SEGMENTS (L x S) ---
yhat_mat = NaN(L, S);
% Fill train segments
k = 0;
for sLocal = 1:numel(trainSegs)
    s = trainSegs(sLocal);
    for t = (maxLag+1):L
        k = k + 1;
        yhat_mat(t, s) = yhat_tr(k);
    end
end
% Fill test segments
k = 0;
for sLocal = 1:numel(testSegs)
    s = testSegs(sLocal);
    for t = (maxLag+1):L
        k = k + 1;
        yhat_mat(t, s) = yhat_te(k);
    end
end

%% --- METRICS (ORIGINAL UNITS) ---
rmse_train = sqrt(mean( (y_mat((maxLag+1):L, trainSegs) - yhat_mat((maxLag+1):L, trainSegs)).^2, 'all' ));
rmse_test  = NaN;
% After computing rmse_train and rmse_test (rmse_test may be NaN if no test segs)
if isnan(rmse_test)
    fprintf('maxLag=%d | RMSE train=%.6g | RMSE test=N/A (no test segments)\n', ...
        maxLag, rmse_train);
else
    fprintf('maxLag=%d | RMSE train=%.6g | RMSE test=%.6g\n', ...
        maxLag, rmse_train, rmse_test);
end


%% --- QUICK PLOTS (per-segment overlays) ---
figure('Name','Per-Segment Reconstruction','NumberTitle','off');
tiledlayout(S,1,'TileSpacing','compact','Padding','compact');
for s = 1:S
    nexttile;
    plot(1:L, y_mat(:,s), 'LineWidth', 1); hold on;
    plot(1:L, yhat_mat(:,s), 'LineWidth', 1);
    grid on; ylabel(sprintf('seg %d', s));
    if s==1, title('Actual vs Predicted (each segment)'); end
    if s==S, xlabel('t'); end
    xline(maxLag+0.5,':'); % indicate where predictions start
end
legend({'Actual','Predicted'},'Location','best');

%% ==================== HELPERS ====================
