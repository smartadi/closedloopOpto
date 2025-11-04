function [Phi, y_out, maxLag] = buildLagMatrix(y, X, pY, pX)
% y: Tx1, X: Txd or []
% Returns:
%   Phi   : (T-maxLag) x (1 + pY + d*pX) design matrix (intercept in col 1)
%   y_out : (T-maxLag) x 1 aligned target
%   maxLag: max(pY,pX)

    if nargin < 2 || isempty(X), X = []; end
    if nargin < 3, pY = 0; end
    if nargin < 4, pX = 0; end

    T = size(y,1);
    d = size(X,2);
    maxLag = max(pY, pX);

    if maxLag == 0
        % Only intercept and contemporaneous X (if provided)
        Phi = ones(T,1);
        if ~isempty(X), Phi = [Phi X]; end
        y_out = y;
        return;
    end

    % Drop first maxLag to ensure all lags exist
    idx   = (maxLag+1):T;
    y_out = y(idx);

    % Intercept
    Phi = ones(numel(idx), 1);

    % AR lags of y: y_{t-1},...,y_{t-pY}
    for l = 1:pY
        Phi = [Phi  y(idx - l)];
    end

    % Lagged X terms: for each variable j, lags 1..pX
    if ~isempty(X) && pX > 0
        for j = 1:d
            for l = 1:pX
                Phi = [Phi  X(idx - l, j)];
            end
        end
    end
end