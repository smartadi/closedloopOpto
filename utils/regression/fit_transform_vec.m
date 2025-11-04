function [y_tr, y_te, scaler] = fit_transform_vec(y, idx_tr, pre_fun)
    ytrain = y(idx_tr);
    mask = true(numel(y),1); mask(idx_tr)=false; ytest = y(mask);
    [y_tr, scaler] = apply_and_fit(ytrain, pre_fun);
    y_te = apply_with_scaler(ytest, scaler);
end