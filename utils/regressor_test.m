%% Linear regression with time lags (one-step-ahead)
% Inputs:
%   y        : T x 1 target series
%   X        : T x p exogenous series (optional; [] if none)
%   yLags    : vector of positive ints, e.g., 1:3  (lags of y)
%   xLags    : cell of length p; xLags{j} lists lags to use for X(:,j)
%              e.g., {1:2, [1 3], 2}  (or [] to use same lags for all via xLagsAll)
%   xLagsAll : vector used if xLags is empty, e.g., 1:2
%   useIntercept : true/false
%   standardize  : true/false (z-score features)
%   ridgeLambda  : 0 for OLS; >0 for ridge

clear; clc

%% --- USER SETTINGS ---
% Example data (replace with your own):
T = 1000;
y = sin((1:T)'/15) + 0.3*randn(T,1);
X = [cos((1:T)'/11), randn(T,1)];  % two exogenous predictors

yLags       = 1:3;                % AR(3)
xLags       = {};                 % leave empty to use xLagsAll for all X columns
xLagsAll    = 1:2;                % apply to all X columns if xLags is {}
useIntercept = true;
standardize  = true;              % standardize regressors only
ridgeLambda  = 0;                 % 0 => OLS; e.g., 1.0 for ridge

% Train/validation split (chronological)
trainFrac = 0.8;

%% --- BUILD LAGGED DESIGN MATRIX ---
[Phi, yAligned, varNames] = designMatrixWithLags(y, X, yLags, xLags, xLagsAll, useIntercept);

% Split
N = size(Phi,1);
Ntr = floor(trainFrac*N);
Phi_tr = Phi(1:Ntr,:);   y_tr = yAligned(1:Ntr);
Phi_te = Phi(Ntr+1:end,:); y_te = yAligned(Ntr+1:end);

% Standardize regressors (fit params on train, apply to test)
mu = zeros(1,size(Phi,2));  sig = ones(1,size(Phi,2));
if standardize
    mu = mean(Phi_tr,1); sig = std(Phi_tr,[],1);
    sig(sig==0) = 1;
    Phi_tr = (Phi_tr - mu) ./ sig;
    Phi_te = (Phi_te - mu) ./ sig;
end

%% --- FIT LINEAR MODEL (OLS or Ridge) ---
if ridgeLambda > 0
    % Ridge: add sqrt(lambda) * I rows (except optional intercept)
    I = eye(size(Phi_tr,2));
    if useIntercept
        I(1,1) = 0; % don't penalize intercept
    end
    Phi_aug = [Phi_tr; sqrt(ridgeLambda)*I];
    y_aug   = [y_tr; zeros(size(Phi_tr,2),1)];
    w = Phi_aug \ y_aug;
else
    % OLS
    w = Phi_tr \ y_tr;  % equivalent to regress/fitlm for full-rank Phi_tr
end

%% --- EVALUATE ---
yhat_tr = Phi_tr*w;
yhat_te = Phi_te*w;

rmse = @(a,b) sqrt(mean((a-b).^2));
fprintf('Train RMSE: %.4f\n', rmse(y_tr, yhat_tr));
fprintf('Test  RMSE: %.4f\n', rmse(y_te, yhat_te));

%% --- PREDICT NEXT STEP (rolling) ---
% Given the latest observed y and X rows, build one-row Phi and compute yhat.
% Example using the final rows from the original y, X:
Phi_next = lastRowDesign(y, X, yLags, xLags, xLagsAll, useIntercept);
if standardize
    Phi_next = (Phi_next - mu) ./ sig;
end
yhat_next = Phi_next * w;
fprintf('Next-step forecast: %.4f\n', yhat_next);

%% --- OPTIONAL: Inspect coefficients ---
tbl = table(varNames(:), w, 'VariableNames', {'Regressor','Weight'});
disp(tbl);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helper: build lagged design matrix
function [Phi, yAligned, varNames] = designMatrixWithLags(y, X, yLags, xLags, xLagsAll, useIntercept)
    if nargin < 6, useIntercept = true; end
    if isempty(yLags), yLags = []; end
    T = size(y,1);
    p = size(X,2);
    if isempty(X), p = 0; end

    % Normalize xLags input
    if p>0
        if isempty(xLags)
            xLags = repmat({xLagsAll}, 1, p);
        else
            assert(numel(xLags)==p, 'xLags must be a cell of length size(X,2).');
        end
    end

    maxLag = 0;
    if ~isempty(yLags), maxLag = max(maxLag, max(yLags)); end
    for j=1:p
        if ~isempty(xLags{j}), maxLag = max(maxLag, max(xLags{j})); end
    end
    idx = (maxLag+1):T;                 % rows that have all lags available

    PhiParts = {};
    names = {};

    if useIntercept
        PhiParts{end+1} = ones(numel(idx),1);
        names{end+1} = 'Intercept';
    end

    % y-lags (autoregressive terms)
    for k = yLags
        col = y(idx - k);
        PhiParts{end+1} = col;
        names{end+1} = sprintf('y(t-%d)', k);
    end

    % X-lags
    if p>0
        for j = 1:p
            for k = xLags{j}
                col = X(idx - k, j);
                PhiParts{end+1} = col;
                names{end+1} = sprintf('x%d(t-%d)', j, k);
            end
        end
    end

    Phi = cat(2, PhiParts{:});
    yAligned = y(idx);                  % predict y(t) from past lags
    varNames = names;
end

% Helper: build a single-row Phi for the "next-step" forecast
function Phi_row = lastRowDesign(y, X, yLags, xLags, xLagsAll, useIntercept)
    if nargin < 6, useIntercept = true; end
    T = size(y,1);
    p = size(X,2);
    if isempty(X), p = 0; end
    if p>0 && isempty(xLags)
        xLags = repmat({xLagsAll}, 1, p);
    end

    parts = [];
    if useIntercept
        parts = [parts, 1];
    end
    % y-lags
    for k = yLags
        parts = [parts, y(T - k + 1)];
    end   
    % X-lags
    for j = 1:p
        for k = xLags{j}
            parts = [parts, X(T - k + 1, j)];
        end
    end
    Phi_row = parts;
end
