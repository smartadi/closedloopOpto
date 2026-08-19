function [y, ok] = cp_svd_rolling_dfk(Uflat, V, mimg, prow, pcol, k, horizon, nY, nX)
%CP_SVD_ROLLING_DFK  SVD-reconstructed kernel fluorescence through getpixel_dFoF's mode-0 baseline.
%
%   The project's `data.dFk` is getpixel_dFoF **mode=0**: RAW binary frames put through a
%   `horizon`-sample ROLLING baseline -- NOT the SVD mean-image dF/F. Reconstructing the SVD kernel
%   against the mean image instead gives corr ~0.06 with data.dFk, because the baseline method
%   differs (RESEARCH 2026-07-18). This rebuilds raw fluorescence from the SVD and puts it through
%   the SAME rolling baseline, giving a trace that is both contra-predictable and tracks data.dFk.
%
%       F_raw(t) = mI + mean(U_box)*V(:,t)      (U*V is the zero-mean dF; mI = mean image = F0)
%       base(t)  = trailing mean of F_raw over the last (w+1) samples, w = horizon-1
%       dFk(t)   = (F_raw - base)/base * 100 ;  first w (warm-up) samples -> NaN
%
%   Box = row prow, col pcol in the getpixel convention (prow = pixel(2), pcol = pixel(1)).
%   ok = false if the box is out of frame or the mean image there is degenerate.
%
%   Verbatim the `local_svd_rolling_dfk` that ctrl_ols_spont.m / ctrl_ols_ol_stimblind.m /
%   ctrl_ols_cl_deploy.m / ctrl_affected_gui.m / ctrl_state_dependence.m / internal_model_principle.m
%   each carry a private copy of. Promoted 2026-08-10 so new callers cannot introduce a seventh
%   variant; the existing copies are byte-identical and are left alone deliberately, because
%   touching them would silently re-touch every cached number they produced.

y = nan(size(V,2),1);  ok = false;
if prow < 1 || prow > nY || pcol < 1 || pcol > nX; return; end
kr = max(1,prow-k):min(nY,prow+k);
kc = max(1,pcol-k):min(nX,pcol+k);
[KR,KC] = ndgrid(kr,kc);
kidx = sub2ind([nY,nX], KR(:), KC(:));
mI = mean(mimg(kr,kc),'all');
if ~isfinite(mI) || abs(mI) < eps; return; end
Fsvd = mean(double(Uflat(kidx,:)),1) * V;      % [1 x T] kernel dF reconstruction (zero-mean)
Fraw = mI + Fsvd(:);                            % [T x 1] raw fluorescence
w = max(1, round(horizon)-1);
T = numel(Fraw);  ii = (1:T).';
cs = [0; cumsum(Fraw)];  lo = max(ii-w, 1);
base = (cs(ii+1) - cs(lo)) ./ (ii - lo + 1);    % trailing causal mean over <= w+1 samples
y = (Fraw - base) ./ base * 100;
y(1:w) = NaN;                                   % warm-up baseline is garbage
ok = true;
end
