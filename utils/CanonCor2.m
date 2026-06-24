function [a, b, R2] = CanonCor2(Y, X)
% CanonCor2  Reduced-rank regression via canonical-correlation-style SVD.
%
% EXTERNAL DEPENDENCY — vendored verbatim (cell-array variant) from
%   Ye et al. 2023 spirals: spirals_mirror/utils/CanonCor2.m
%   (CanonCor2 from KDH; multi-instance cell version updated by NAS).
% Copied into this repo so contra_prediction.m [CP-HEMI] reproduces Zhiwen Ye's
% getReducedRankRegressionHEMI.m exactly. DO NOT edit the algorithm.
%
% Finds the linear combinations of X that predict the largest variance
% fractions of Y. Think of Y as dependent, X as independent.
%
% Y and X are cell arrays with the same number of cells; entry i of Y is
% [t_i, n_i], entry i of X is [t_i, p] (p shared across all instances).
% For a single instance pass {Ymat}, {Xmat}.
%
% R2(n) is the fraction of total variance of Y explained by the nth projection.
% The rank-n approximation is:   Y = X * b(:,1:n) * a(:,1:n)'
% (equivalently  Y(i,:)' = a(:,n) * b(:,n)' * X(i,:)' ).

% Make covariance matrices
nInst = numel(Y);
nX = size(X{1}, 2);
nY = sum(cellfun(@(x)size(x,2), Y));

% first covariance of X
allX = vertcat(X{:});
CXX = cov(allX);
eps = 1e-7;
CXX = CXX+eps*eye(nX); % prevents imaginary results in some cases

CXXMH = CXX ^ -0.5;

% now covariance of Y with X, assembled instance-by-instance
CYX = zeros(nY, nX);
varY = zeros(1,nY);
startInd = 1;

for q = 1:nInst
    % directly computes just the part we want (avoids forming CYY)
    thisY = Y{q};
    thisX = X{q};
    thisYmnSub = thisY - mean(thisY);
    thisXmnSub = thisX - mean(thisX);
    denom = size(thisX,1)-1;
    CYX(startInd:startInd+size(thisY,2)-1,:) = (thisYmnSub'*thisXmnSub)./denom;
    varY(startInd:startInd+size(thisY,2)-1) = var(thisY);

    startInd = startInd+size(thisY,2);
end

% matrix to do svd ...
M = CYX * CXXMH;

% do svd
[d, s, c] = svd(M, 0);

b = CXXMH * c;
a = d * s;

R2 = (diag(s).^2)/sum(varY);
end
