function [X_tr, X_te, scalers] = fit_transform_cols(X, idx_tr, pre_list)
% Fit per-column transforms on train, apply to train/test.
% pre_list: cell array of function handles describing the transform "type";
% this function *captures* the fitted params by re-estimating inside apply_*.
    [T,n] = size(X);
    X_tr = zeros(numel(idx_tr), n);
    X_te = zeros(T-numel(idx_tr), n);
    scalers = cell(1,n);
    % Split once
    Xtrain = X(idx_tr, :);
    mask = true(T,1); mask(idx_tr) = false;
    Xtest = X(mask,:);
    for j = 1:n
        % Fit: we only store means/std or anything needed to invert later
        [X_tr(:,j), scalers{j}] = apply_and_fit(Xtrain(:,j), pre_list{j});
        X_te(:,j)               = apply_with_scaler(Xtest(:,j),  scalers{j});
    end
end
