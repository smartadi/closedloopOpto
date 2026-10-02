function T = dataset2table_safe(D)
%DATASET2TABLE_SAFE  Convert a titled-dataset to a table, tolerating releases.
%
% covarianceParameters and fixedEffects return titled-datasets (not tables) in
% some MATLAB releases and plain tables in others. This normalises both.
%
% Promoted from a local subfunction of utils/cl_olcl_lmm.m on 2026-10-01 so that
% utils/f4_row2_fit.m can use it too, when both helpers moved to
% fixedEffects(...,'DFMethod','Satterthwaite').
%
% NOTE ON THE EMPTY FALLBACK. On failure this returns an EMPTY table, because
% its original caller (the covariance-parameter loop) treats a missing Group
% column as "skip this component". That is safe there and UNSAFE for a
% fixed-effects coefficients table, where an empty result would silently become
% a missing coefficient rather than an error. Callers converting coefficients
% must check the result is non-empty and contains the coefficient they expect --
% cl_olcl_lmm.m and f4_row2_fit.m both do.

try
    if istable(D), T = D; else, T = dataset2table(D); end
catch
    T = table();   % Group column absent -> caller skips
end
end
