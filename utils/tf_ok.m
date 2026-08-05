function ok = tf_ok(sys, Ts)
%TF_OK  TRUE iff a fitted continuous TF is SAFE to hand to sim()/compare().
%
% A pathological fit (which higher orders can produce) makes the controllib sssim MEX
% ACCESS-VIOLATE deep in BLAS -- a HARD crash that try/catch CANNOT trap, taking MATLAB with it.
% Screen it out FIRST using only algebraic pole extraction (roots of the denominator; no
% state-space simulation, so this check itself cannot crash).
%
% Rejects: unstable (any pole with real part > 0) and stiff/too-fast (|pole|*Ts past ~2x Nyquist,
% which the sampled data cannot represent and which explodes the solver step). Legitimate
% dip/rebound dynamics have |pole|*Ts = O(1) and Re(pole) < 0, so this only culls overfit junk.
%
% NOTE: impulse-analysis/tf_fit.m carries an identical LOCAL copy of this function (local
% functions in a script are not visible outside it). This file is the canonical version used by
% utils/imp_tf_fit_session.m; keep the two in step if the thresholds ever change.

ok = false;
if isempty(sys), return; end
try
    p = pole(sys);
catch
    return;
end
if isempty(p) || any(~isfinite(p)),   return; end
if max(real(p)) > 1e-6,               return; end   % unstable -> reject
if max(abs(p))*Ts > 2*pi,             return; end   % stiff / past ~2x Nyquist -> reject
ok = true;
end
