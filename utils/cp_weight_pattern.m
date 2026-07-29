function [a, info] = cp_weight_pattern(X, b, mu, sd, y0, yhat_ext)
%CP_WEIGHT_PATTERN  Forward PATTERN from backward-model weights (Haufe et al. 2014).
%
%   a = CP_WEIGHT_PATTERN(X, b) converts the weights `b` of a backward (decoding)
%   model  yhat = b' * z  into the forward ACTIVATION PATTERN that may legitimately be
%   plotted as a spatial map.
%
%   WHY THIS EXISTS
%     A backward-model weight vector is a FILTER, not a map. Fit on correlated
%     regressors (e.g. neighbouring cortical pixels) it is optimised to CANCEL shared
%     noise, so it can be large on a pixel that carries no signal at all (a suppressor
%     variable) and near-zero on a pixel whose signal a neighbour already supplies.
%     Sign flips relative to the true pattern are the ordinary failure mode, not an
%     exotic one. Reading `b` as "how much this region contributes" is therefore wrong,
%     and it is a standard referee objection in the neuroimaging literature.
%
%     The interpretable object is the forward pattern
%           a = Sigma_x * b / var(yhat)      equivalently      a_j = cov(x_j, yhat)
%     i.e. how strongly each regressor CO-VARIES with the part of the target the model
%     actually explains. Unlike `b`, this is what you can paint on a brain.
%
%   INPUTS
%     X   [p x T]  regressor traces in the SAME units the weights were fit on (raw,
%                  pre-z-scoring). Pass the z-scoring used at fit time via mu/sd.
%     b   [p x 1]  backward weights, as fit (i.e. applied to the z-scored regressors).
%     mu  [p x 1]  (optional) per-regressor mean used to z-score at fit time. Default 0.
%     sd  [p x 1]  (optional) per-regressor sd used to z-score at fit time.   Default 1.
%     y0  [1 x 1]  (optional) prediction intercept. Only shifts yhat; does not affect a.
%     yhat_ext [T x 1] (optional) use THIS prediction instead of computing one from b.
%                  Pass b = [] with it. This is the form to use when you want the pattern
%                  over a LARGER pixel set than the predictor was fit on: the pattern is
%                  just cov(x_j, yhat), which is defined for every pixel, whereas the
%                  filter exists only for the regressors actually in the model.
%
%   OUTPUTS
%     a    [p x 1]  forward pattern, in units of  cov(X_j, yhat)  -- plot THIS.
%     info .yhat    [T x 1] model prediction
%          .var_yhat, .rho_ab (corr between filter and pattern -- the diagnostic:
%          values well below 1 mean the filter was NOT safe to plot), .p, .T
%
%   NOTE ON SCALE  `a` is a covariance, so its absolute units are rarely meaningful;
%   spatial STRUCTURE and SIGN are. Normalise (e.g. by max(abs(a))) for display.
%
%   See also CP_WEIGHT_COMPOSITE.

narginchk(2, 6);
[p, T] = size(X);
b = b(:);
if nargin < 3 || isempty(mu), mu = zeros(p,1); end
if nargin < 4 || isempty(sd), sd = ones(p,1);  end
if nargin < 5 || isempty(y0), y0 = 0;          end
if nargin < 6, yhat_ext = []; end
mu = mu(:); sd = sd(:); sd(sd == 0) = 1;

if ~isempty(yhat_ext)
    yhat = yhat_ext(:);
    assert(numel(yhat) == T, ...
        'cp_weight_pattern: yhat_ext has %d samples but X has %d columns.', numel(yhat), T);
else
    assert(numel(b) == p, ...
        'cp_weight_pattern: b has %d entries but X has %d rows (pass yhat_ext to use a larger pixel set).', ...
        numel(b), p);
    Z    = (X - mu) ./ sd;             % z-scored exactly as at fit time
    yhat = (Z.' * b) + y0;             % [T x 1]
end
yc = yhat - mean(yhat);

% a_j = cov(x_j, yhat).  Computed on the RAW regressors so the pattern lives in the
% data's own units and stays interpretable per pixel.
Xc = X - mean(X, 2);
a  = (Xc * yc) / max(T - 1, 1);

info = struct();
info.yhat     = yhat;
info.var_yhat = var(yhat);
info.p        = p;
info.T        = T;
% Diagnostic: how far apart are the filter and the pattern? corr ~1 means the filter
% happened to be safe to plot; anything lower means it was not.
if numel(b) == p && std(b) > 0 && std(a) > 0
    info.rho_ab = corr(b, a);
else
    info.rho_ab = NaN;                 % not comparable (external yhat / larger pixel set)
end
end
