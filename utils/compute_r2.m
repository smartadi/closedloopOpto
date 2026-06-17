function r2 = compute_r2(y, X, beta, pY, pX)
% One-shot R² of ARX model on a concatenated y/X pair.
    if isempty(y); r2 = NaN; return; end
    [Phi, yo] = buildLagMatrix(y, X, pY, pX);
    ss_res = sum((yo - Phi*beta).^2);
    ss_tot = sum((yo - mean(yo)).^2);
    if ss_tot < eps; r2 = NaN; return; end
    r2 = max(0, 1 - ss_res/ss_tot);
end
