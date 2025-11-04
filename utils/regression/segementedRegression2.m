%% segmented_regression_6D_train_val_test.m
% n=6 exogenous dims; y depends ONLY on dim 4 (with lags).
% More segments + noise; train/val/test split by segments.
clear; clc; close all; rng(0);

%% ------------------ SETTINGS ------------------
L  = 240;      % length per segment
S  = 12;       % number of segments (more segments)
n  = 6;        % exogenous dimensions
pY = 0;        % no y-lags (no y as input)
pX = 2;        % use 2 lags of X
maxLag = max(pY, pX);

% Noise level (std dev) added to y
sigma_eps = 0.5;  % try 0.0 (noise-free), 0.5, 1.0, ...

% Segment split ratios (by segments)
rat_tr = 0.6;   % 60% train
rat_va = 0.2;   % 20% validation
rat_te = 0.2;   % 20% test

%% ------------------ BUILD DETERMINISTIC X (L x n x S) ------------------
t = (0:L-1)';
X_tensor = zeros(L, n, S);
for s = 1:S
    % X1: small sinusoid [0..5]
    X_tensor(:,1,s) = 2.5 + 2.5*sin(2*pi*(t + 3*(s-1))/24);

    % X2: large ramp 0..1e6
    X_tensor(:,2,s) = linspace(0, 1e6, L)';

    % X3: square wave {-1,1} with period ~48
    X_tensor(:,3,s) = sign(sin(2*pi*(t + 10*(s-1))/48));

    % X4: THE TRUE DRIVER (smooth curve) <-- y depends ONLY on this
    base = (t/L);
    X_tensor(:,4,s) = 50*(base.^2) + 20*sin(2*pi*(t+5*s)/60);  % ~[0..70]

    % X5: slow cosine [-1..1]
    X_tensor(:,5,s) = cos(2*pi*(t + 7*(s-1))/90);

    % X6: step pattern {-2,2}
    X_tensor(:,6,s) = 2*(2*(mod(floor(t/40) + s,2))-1);
end

%% ------------------ TRUE MODEL (y from X(:,4) lags) ------------------
b0 = 15;           % intercept
c1 = 0.9;          % coef for X4_{t-1}
c2 = -0.3;         % coef for X4_{t-2}

y_mat = NaN(L, S);
for s = 1:S
    X4 = X_tensor(:,4,s);
    for tt = (maxLag+1):L
        y_mat(tt,s) = b0 + c1*X4(tt-1) + c2*X4(tt-2);
    end
    y_mat(1:maxLag, s) = b0; % fill first maxLag
end

% Add noise
y_mat = y_mat + sigma_eps*randn(size(y_mat));

%% ------------------ SEGMENT SPLIT (by contiguous segments) ------------------
Str = max(1, floor(rat_tr*S));
Sva = max(1, floor(rat_va*S));
Ste = S - Str - Sva;
if Ste < 1, Ste = 1; Sva = max(1, S - Str - Ste); end

trainSegs = 1:Str;                  % e.g., 1..7 (if S=12)
valSegs   = (Str+1):(Str+Sva);      % next block
testSegs  = (Str+Sva+1):S;          % remaining

fprintf('Segments -> Train:%s  Val:%s  Test:%s\n', mat2str(trainSegs), mat2str(valSegs), mat2str(testSegs));

%% ------------------ TRAIN-ONLY ZSCORE ------------------
% Stack TRAIN segments to compute stats
y_tr_stack = y_mat(:, trainSegs); y_tr_stack = y_tr_stack(:);
[y_tr_z, muy, sdy] = zscore(y_tr_stack); sdy = max(sdy, eps);

X_tr_stack = reshape(X_tensor(:, :, trainSegs), [], n);  % (L*Str) x n
[X_tr_z_stack, muX, sdX] = zscore(X_tr_stack); sdX(sdX<eps)=1;

% Apply stats to ALL segments
y_z = (y_mat - muy) ./ sdy;
X_z = zeros(size(X_tensor));
for s = 1:S
    Xs = reshape(X_tensor(:, :, s), [], n);
    Xs = (Xs - muX) ./ sdX;
    X_z(:, :, s) = reshape(Xs, L, n);
end

%% ------------------ BUILD LAGGED MATRICES (within each segment) ------------------
[Phi_tr, y_tr_vec] = buildLagMatrix_segments(y_z(:, trainSegs), X_z(:, :, trainSegs), pY, pX);

Phi_va = []; y_va_vec = [];
if ~isempty(valSegs)
    [Phi_va, y_va_vec] = buildLagMatrix_segments(y_z(:, valSegs), X_z(:, :, valSegs), pY, pX);
end

Phi_te = []; y_te_vec = [];
if ~isempty(testSegs)
    [Phi_te, y_te_vec] = buildLagMatrix_segments(y_z(:, testSegs), X_z(:, :, testSegs), pY, pX);
end

%% ------------------ FIT ON TRAIN & EVALUATE ON VAL ------------------
beta_tr = Phi_tr \ y_tr_vec;

yhat_tr_scaled = Phi_tr * beta_tr;
yhat_va_scaled = []; if ~isempty(Phi_va), yhat_va_scaled = Phi_va * beta_tr; end
yhat_te_scaled = []; if ~isempty(Phi_te), yhat_te_scaled = Phi_te * beta_tr; end

% Invert scaling back to original y units
yhat_tr = yhat_tr_scaled * sdy + muy;
yhat_va = yhat_va_scaled * sdy + muy;
yhat_te = yhat_te_scaled * sdy + muy;

% Reconstruct aligned matrices Yhat (L x S)
yhat_mat = NaN(L, S);
% Fill train segments
k = 0;
for sL = 1:numel(trainSegs)
    s = trainSegs(sL);
    for tt = (maxLag+1):L
        k = k + 1;
        yhat_mat(tt, s) = yhat_tr(k);
    end
end
% Fill validation segments
k = 0;
for sL = 1:numel(valSegs)
    s = valSegs(sL);
    for tt = (maxLag+1):L
        k = k + 1;
        yhat_mat(tt, s) = yhat_va(k);
    end
end
% Fill test segments
k = 0;
for sL = 1:numel(testSegs)
    s = testSegs(sL);
    for tt = (maxLag+1):L
        k = k + 1;
        yhat_mat(tt, s) = yhat_te(k);
    end
end

%% ------------------ METRICS (original units) ------------------
rmse_train = sqrt(mean((y_mat((maxLag+1):L, trainSegs) - yhat_mat((maxLag+1):L, trainSegs)).^2, 'all'));
rmse_val   = NaN; if ~isempty(valSegs)
    rmse_val = sqrt(mean((y_mat((maxLag+1):L, valSegs) - yhat_mat((maxLag+1):L, valSegs)).^2, 'all'));
end
rmse_test  = NaN; if ~isempty(testSegs)
    rmse_test = sqrt(mean((y_mat((maxLag+1):L, testSegs) - yhat_mat((maxLag+1):L, testSegs)).^2, 'all'));
end

% Safe prints
fprintf('maxLag=%d  |  RMSE Train=%.6g', maxLag, rmse_train);
if ~isnan(rmse_val), fprintf('  |  Val=%.6g', rmse_val); else, fprintf('  |  Val=N/A'); end
if ~isnan(rmse_test), fprintf('  |  Test=%.6g\n', rmse_test); else, fprintf('  |  Test=N/A\n'); end

%% ------------------ (OPTIONAL) REFIT ON TRAIN+VAL, EVAL TEST ------------------
% If you want the final model trained on more data before testing:
if ~isempty(valSegs)
    [Phi_trva, y_trva_vec] = buildLagMatrix_segments(y_z(:, [trainSegs, valSegs]), X_z(:, :, [trainSegs, valSegs]), pY, pX);
    beta_trva = Phi_trva \ y_trva_vec;
    if ~isempty(Phi_te)
        yhat_te_scaled2 = Phi_te * beta_trva;
        yhat_te2 = yhat_te_scaled2 * sdy + muy;
        % compute RMSE on test with refit (optional)
        y_true_te = y_mat((maxLag+1):L, testSegs);
        y_pred_te = reshape(yhat_te2, L - maxLag, []);  % columns = #testSegs
        rmse_test_refit = sqrt(mean((y_true_te - y_pred_te).^2, 'all'));
        fprintf('REFIT on Train+Val -> Test RMSE: %.6g\n', rmse_test_refit);
    end
end

%% ------------------ PLOTS: Validation & Test Reconstructions ------------------
% Per-segment overlays for VALIDATION
if ~isempty(valSegs)
    figure('Name','Validation Segments: Actual vs Predicted','NumberTitle','off');
    tiledlayout(numel(valSegs),1,'TileSpacing','compact','Padding','compact');
    for idx = 1:numel(valSegs)
        s = valSegs(idx);
        nexttile;
        plot(1:L, y_mat(:,s), 'LineWidth', 1); hold on;
        plot(1:L, yhat_mat(:,s), 'LineWidth', 1);
        grid on; ylabel(sprintf('seg %d', s));
        if idx==1, title('Validation: Actual vs Predicted'); end
        if idx==numel(valSegs), xlabel('t'); end
        xline(maxLag+0.5, ':'); % prediction starts
        legend({'Actual','Predicted'},'Location','best'); legend boxoff;
    end
end

% Per-segment overlays for TEST
if ~isempty(testSegs)
    figure('Name','Test Segments: Actual vs Predicted','NumberTitle','off');
    tiledlayout(numel(testSegs),1,'TileSpacing','compact','Padding','compact');
    for idx = 1:numel(testSegs)
        s = testSegs(idx);
        nexttile;
        plot(1:L, y_mat(:,s), 'LineWidth', 1); hold on;
        plot(1:L, yhat_mat(:,s), 'LineWidth', 1);
        grid on; ylabel(sprintf('seg %d', s));
        if idx==1, title('Test: Actual vs Predicted'); end
        if idx==numel(testSegs), xlabel('t'); end
        xline(maxLag+0.5, ':'); % prediction starts
        legend({'Actual','Predicted'},'Location','best'); legend boxoff;
    end
end


