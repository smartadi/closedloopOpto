function [x_tr, scaler] = apply_and_fit(x_tr, pre_fun)
    fstr = func2str(pre_fun);

    % detect zscore only (anonymous or direct)
    if contains(fstr, 'zscore') && ~contains(fstr, 'log1p')
        mu = mean(x_tr,'omitnan');
        sd = std(x_tr,0,'omitnan'); sd = max(sd, eps);
        x_tr = (x_tr - mu) ./ sd;
        scaler.type='zscore'; scaler.mu=mu; scaler.sd=sd;
        return;
    end

    % detect log1p + zscore
    if contains(fstr, 'log1p') && contains(fstr, 'zscore')
        x_log = log1p(max(x_tr,0));
        mu = mean(x_log,'omitnan');
        sd = std(x_log,0,'omitnan'); sd = max(sd, eps);
        x_tr = (x_log - mu) ./ sd;
        scaler.type='log1p_z'; scaler.mu=mu; scaler.sd=sd;
        return;
    end

    % fallback: treat as plain zscore of the result of pre_fun(x)
    % (not invertible unless you add a custom branch)
    warning('Unknown transform; applying pre_fun then z-scoring (no exact inverse).');
    x_tmp = pre_fun(x_tr);
    mu = mean(x_tmp,'omitnan');
    sd = std(x_tmp,0,'omitnan'); sd = max(sd, eps);
    x_tr = (x_tmp - mu) ./ sd;
    scaler.type='z_of_custom'; scaler.mu=mu; scaler.sd=sd;
end