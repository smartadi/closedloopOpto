function r2_arr = per_trial_r2(idx_list, spont_y, spont_X, beta, pY, pX)
% Per-trial R² for a list of pre-stim window indices.
    r2_arr = nan(numel(idx_list), 1);
    for kk = 1:numel(idx_list)
        j  = idx_list(kk);
        yj = spont_y{j};
        Xj = spont_X{j};
        if isempty(yj); continue; end
        [Phi_j, yo_j] = buildLagMatrix(yj, Xj, pY, pX);
        ss_res = sum((yo_j - Phi_j*beta).^2);
        ss_tot = sum((yo_j - mean(yo_j)).^2);
        if ss_tot > eps
            r2_arr(kk) = max(0, 1 - ss_res/ss_tot);
        end
    end
end
