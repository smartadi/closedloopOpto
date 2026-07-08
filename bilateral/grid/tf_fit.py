"""tf_fit.py — fit low-order LTI transfer functions to the s->r impulse responses.

Each H[s, r, :] (from cross_response.py) is the empirical impulse response from stim site
s to readout r. We fit a delayed all-pole TF, whose impulse response is a sum of
exponentials:  h(t) = sum_i A_i * exp(-(t-theta)/tau_i)  for t >= theta.
That is the impulse response of K * prod_i 1/(s + 1/tau_i) (poles at -1/tau_i; residue
pattern A_i absorbs the zeros). Real poles, opposite-sign residues give a rise-then-decay.
NOTE: the transport-delay (lag) term theta is currently DISABLED (pinned to 0) — scanning a
per-pair onset lag was absorbing real early dynamics, so fits now start at t=0.

Orders 1-3 are fit and AIC selects. This is the per-(s,r) building block; the prototype
runs it on a few representative pairs to validate the model class before scaling to 52x52.
"""
import numpy as np
import scipy.optimize

import cross_response

# NOTE: the transport-delay (lag) term theta is DISABLED for now. Scanning a per-pair onset
# lag was absorbing real early dynamics — the model stayed flat until theta then started, so
# the poles missed the fast rise. All fits now start at t=0 (theta fixed to 0).
DELAY_MAX = 0.0    # s — lag term disabled (theta pinned to 0)
ORDERS = (1, 2, 3)   # pole counts to try (CV selects among them). Capped at 3: a perturbation
                     # impulse response is a rise-then-decay (~2nd order). Orders 4-5 were being
                     # CV-selected only to approximate the rise with a sum of DECAYING exps — a
                     # model-class artifact (tightening the window made it worse, not better),
                     # not real dynamics. Low order also keeps poles/zeros interpretable.
FIT_TMAX = 0.6     # s — fit only t in [0, FIT_TMAX], which ends BEFORE the first neighbour
                   # stim (~0.71 s at ITI 0.71 s). The response transient completes by ~0.5 s;
                   # ending at 0.6 s keeps the fit clean of the reproducible neighbour bump —
                   # which CV alone can't reject (it is present in both trial-halves).


def _impulse(t, theta, A, tau):
    """Sum-of-exponentials impulse response, zero before the delay theta."""
    out = np.zeros_like(t)
    m = t >= theta
    dt = t[m] - theta
    out[m] = sum(a * np.exp(-dt / tk) for a, tk in zip(A, tau))
    return out


def _fit_order(t, h, n, peak):
    """Fit an n-pole sum-of-exponentials (no lag; theta pinned to 0); return (params,yhat,sse)."""
    sign = np.sign(peak) or 1.0
    A0 = [sign * abs(peak)] + [-sign * abs(peak) * 0.5] * (n - 1)   # rise/decay seed
    tau0 = list(np.geomspace(0.05, 0.4, n))
    p0 = A0 + tau0
    lo = [-1.0] * n + [1e-3] * n
    hi = [1.0] * n + [3.0] * n

    def resid(p):
        A, tau = p[:n], p[n:]
        return _impulse(t, 0.0, A, tau) - h

    r = scipy.optimize.least_squares(resid, p0, bounds=(lo, hi), max_nfev=4000)
    A, tau = r.x[:n], r.x[n:]
    yhat = _impulse(t, 0.0, A, tau)
    return dict(theta=0.0, A=A, tau=tau), yhat, float(np.sum((yhat - h) ** 2))


def fit_lti(t, h, orders=ORDERS, criterion="bic"):
    """Fit orders 1..3 to a post-onset impulse response h(t); select by BIC (default) or AIC.

    BIC penalizes order more strongly (k*ln(n) vs 2k) — chosen because the smooth,
    autocorrelated dF/F residual makes naive AIC always grab the max order. Returns dict
    with order, poles (1/tau), tau, residues A, delay, gain, r2, ic, and the curve yhat.
    Robust to flat/weak pairs.
    """
    post = (t >= 0) & (t <= FIT_TMAX)        # fit only the clean early window
    tp, hp = t[post], h[post]
    n_obs = hp.size
    peak = hp[np.argmax(np.abs(hp))]
    ss_tot = np.sum((hp - hp.mean()) ** 2) + 1e-12

    best = None
    for n in orders:
        try:
            params, yhat, sse = _fit_order(tp, hp, n, peak)
        except Exception:
            continue
        k = 2 * n                                        # (A,tau) per pole; no lag term
        pen = k * np.log(n_obs) if criterion == "bic" else 2 * k
        ic = n_obs * np.log(sse / n_obs + 1e-30) + pen
        r2 = 1.0 - sse / ss_tot
        cand = dict(order=n, ic=ic, r2=r2, sse=sse, theta=params["theta"],
                    tau=np.asarray(params["tau"]), A=np.asarray(params["A"]),
                    poles=-1.0 / np.asarray(params["tau"]),
                    gain=yhat[np.argmax(np.abs(yhat))], yhat=yhat, t=tp)
        if best is None or ic < best["ic"]:
            best = cand
    return best


def _r2(yhat, target):
    ss = np.sum((yhat - target) ** 2)
    st = np.sum((target - target.mean()) ** 2) + 1e-12
    return 1.0 - ss / st


def split_half_means():
    """Even/odd-trial split-half mean responses HA, HB (nS,nS,nW) from the trials cache —
    two INDEPENDENT estimates of each pair's impulse response, for cross-validated order
    selection. Same per-half baseline convention as build()."""
    import scipy.interpolate
    zt = cross_response.load_trials()
    roi_ts = zt["roi_ts"].astype(np.float64)
    svdT, onset_t, pos = zt["svdT"], zt["onset_t"], zt["pos"]
    sites, window, base_ix = zt["sites"], zt["window"], int(zt["base_ix"])
    nS, nW = len(sites), len(window)
    fr = [scipy.interpolate.interp1d(svdT, roi_ts[:, r], bounds_error=False, fill_value=np.nan)
          for r in range(nS)]
    HA = np.full((nS, nS, nW), np.nan); HB = np.full((nS, nS, nW), np.nan)
    for s, (mx, my) in enumerate(sites):
        onsets = onset_t[(pos[:, 0] == mx) & (pos[:, 1] == my)]
        a = np.arange(len(onsets)) % 2 == 0
        for r in range(nS):
            fluo = fr[r](window[None, :] + onsets[:, None])          # (nTrials,nW)
            for Hh, ix in ((HA, a), (HB, ~a)):
                fh = fluo[ix]
                base = np.nanmean(fh[:, :base_ix])
                Hh[s, r] = np.nanmean((fh - base) / base, 0)
    return HA, HB, window


def fit_lti_cv(t, h, hA, hB, orders=ORDERS):
    """Select TF order by 2-fold split-half cross-validation, then refit on the full mean h.

    For each order: fit on half A, score R^2 on half B, and vice-versa; the CV score is the
    mean. Overfitting noise in one half does not predict the independent other half, so CV
    rejects orders that only fit noise. Final params come from a refit on the full mean.
    """
    post = (t >= 0) & (t <= FIT_TMAX)
    tp, hp, hAp, hBp = t[post], h[post], hA[post], hB[post]
    cv = []
    for n in orders:
        try:
            _, yA, _ = _fit_order(tp, hAp, n, hAp[np.argmax(np.abs(hAp))])
            _, yB, _ = _fit_order(tp, hBp, n, hBp[np.argmax(np.abs(hBp))])
            cv.append(0.5 * (_r2(yA, hBp) + _r2(yB, hAp)))
        except Exception:
            cv.append(-np.inf)
    cv = np.asarray(cv)
    nbest = orders[int(np.nanargmax(cv))] if np.any(np.isfinite(cv)) else orders[0]
    params, yhat, sse = _fit_order(tp, hp, nbest, hp[np.argmax(np.abs(hp))])
    sst = np.sum((hp - hp.mean()) ** 2) + 1e-12
    return dict(order=nbest, cvr2=float(np.nanmax(cv)) if np.any(np.isfinite(cv)) else np.nan,
                r2=1.0 - sse / sst, sse=sse, theta=0.0, tau=np.asarray(params["tau"]),
                A=np.asarray(params["A"]), poles=-1.0 / np.asarray(params["tau"]),
                gain=yhat[np.argmax(np.abs(yhat))], yhat=yhat, t=tp)


CACHE_TF = cross_response.CACHE.parent / "grid_tf_fits.npz"


def fit_all(orders=ORDERS, selection="cv", criterion="bic", cache=True):
    """Fit a TF to every (stim, readout) pair; cache predictions + params for the viewer.

    selection="cv" (default): pick the order by split-half trial cross-validation — the
    overfitting-proof choice (falls back to BIC if the trials cache is missing). "bic" uses
    in-sample BIC. Caches H, yhat, and per-pair order/r2/cvr2/gain/tau to grid_tf_fits.npz.
    """
    z = cross_response.load_cached()
    H, sites, window = z["H"], z["sites"], z["window"]
    Hsem = z["Hsem"] if "Hsem" in z else np.zeros_like(H)
    Hstd = z["Hstd"] if "Hstd" in z else np.zeros_like(H)
    label = str(z["label"])
    nS, nW = len(sites), len(window)

    HA = HB = None
    if selection == "cv":
        try:
            HA, HB, _ = split_half_means()
        except Exception as e:
            print(f"  [cv] trials cache unavailable ({e}); falling back to BIC")
            selection = "bic"

    yhat = np.zeros((nS, nS, nW))
    order = np.zeros((nS, nS), int)
    r2 = np.full((nS, nS), np.nan)
    cvr2 = np.full((nS, nS), np.nan)
    gain = np.zeros((nS, nS))
    delay = np.zeros((nS, nS))
    tau = np.full((nS, nS, max(ORDERS)), np.nan)     # poles (s), sorted ascending
    Amp = np.full((nS, nS, max(ORDERS)), np.nan)     # residues, aligned to tau
    for s in range(nS):
        for r in range(nS):
            if selection == "cv":
                f = fit_lti_cv(window, H[s, r], HA[s, r], HB[s, r], orders=orders)
                cvr2[s, r] = f["cvr2"]
            else:
                f = fit_lti(window, H[s, r], orders=orders, criterion=criterion)
            yhat[s, r] = _impulse(window, f["theta"], f["A"], f["tau"])
            order[s, r] = f["order"]; r2[s, r] = f["r2"]; gain[s, r] = f["gain"]
            delay[s, r] = f["theta"]
            n = len(f["tau"]); o = np.argsort(f["tau"])
            tau[s, r, :n] = np.asarray(f["tau"])[o]
            Amp[s, r, :n] = np.asarray(f["A"])[o]
        print(f"  fit stim {s+1:2d}/{nS}  median R2(row)={np.nanmedian(r2[s]):.2f}", end="\r")
    print()
    print(f"fit all {nS}x{nS} ({selection}); order hist "
          f"{np.bincount(order.ravel(), minlength=6)[1:]}, median R2={np.nanmedian(r2):.2f}"
          + (f", median CV-R2={np.nanmedian(cvr2):.2f}" if selection == "cv" else ""))
    if cache:
        np.savez(CACHE_TF, H=H, Hsem=Hsem, Hstd=Hstd, yhat=yhat, sites=sites, window=window,
                 label=label, order=order, r2=r2, cvr2=cvr2, gain=gain, delay=delay, tau=tau, A=Amp)
        print("cached ->", CACHE_TF)
    return dict(H=H, Hsem=Hsem, Hstd=Hstd, yhat=yhat, sites=sites, window=window, order=order,
                r2=r2, cvr2=cvr2, gain=gain, delay=delay, tau=tau, A=Amp, label=label)


# --------------------------------------------------------------------------- #
def _nearest(sites, ref, exclude=()):
    """Index of the site closest to coordinate `ref`, excluding given indices."""
    d = np.hypot(sites[:, 0] - ref[0], sites[:, 1] - ref[1])
    for e in exclude:
        d[e] = np.inf
    return int(np.argmin(d))


def prototype(save="grid_png/tf_prototype.png"):
    """Fit + plot a few representative (stim,readout) pairs to validate the model class."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from pathlib import Path

    z = cross_response.load_cached()
    H, sites, window = z["H"], z["sites"], z["window"]
    label = str(z["label"])

    # signed diagonal peak; pick the strongest CORRECTLY-SIGNED, clearly-LATERAL exemplar
    # in each hemisphere (near-midline sites are dominated by the opposite field).
    post = window >= 0
    dp = np.array([H[i, i][post][np.argmax(np.abs(H[i, i][post]))] for i in range(len(sites))])
    lateral = np.abs(sites[:, 0]) >= 1.5
    exc = np.where((sites[:, 0] < 0) & (dp > 0) & lateral)[0]
    inh = np.where((sites[:, 0] > 0) & (dp < 0) & lateral)[0]
    s_exc = exc[np.argmax(dp[exc])]
    s_inh = inh[np.argmin(dp[inh])]

    # build representative pairs: own / near / far-ipsi / contralateral-mirror (all distinct)
    def pairs_for(s):
        coord = sites[s]
        near = _nearest(sites, coord, exclude=(s,))
        far_ipsi = _nearest(sites, (np.sign(coord[0]) * 3.5, -coord[1]), exclude=(s, near))
        contra = _nearest(sites, (-coord[0], coord[1]), exclude=(s, near, far_ipsi))
        labels = ["own (direct)", "near", "far ipsi", "contralateral"]
        return list(zip([s, s, s, s], [s, near, far_ipsi, contra], labels))

    cases = pairs_for(s_exc) + pairs_for(s_inh)

    fig, axes = plt.subplots(2, 4, figsize=(15, 7))
    print(f"\nLTI fits ({label}); stim_exc=({sites[s_exc,0]:+.1f},{sites[s_exc,1]:+.0f}) "
          f"stim_inh=({sites[s_inh,0]:+.1f},{sites[s_inh,1]:+.0f})")
    print(f"{'pair':<16}{'order':>6}{'R2':>8}{'delay_ms':>10}{'tau_ms (poles)':>22}{'gain':>10}")
    for ax, (s, r, lab) in zip(axes.ravel(), cases):
        h = H[s, r]
        fit = fit_lti(window, h, orders=ORDERS)
        ax.axhline(0, c="k", lw=0.4, ls="--")
        ax.axvline(0, c="grey", lw=0.4)
        ax.plot(window, h, c="dodgerblue", lw=1.2, label="empirical")
        ax.plot(fit["t"], fit["yhat"], c="orange", lw=1.4, ls="--", label="LTI fit")
        ax.set_title(f"stim({sites[s,0]:+.1f},{sites[s,1]:+.0f}) -> {lab}\n"
                     f"order {fit['order']}, R2={fit['r2']:.2f}", fontsize=9)
        ax.set_xlabel("t (s)"); ax.legend(fontsize=7)
        taus = ", ".join(f"{tk*1000:.0f}" for tk in np.sort(fit["tau"]))
        print(f"{lab:<16}{fit['order']:>6}{fit['r2']:>8.2f}{fit['theta']*1000:>10.0f}"
              f"{taus:>22}{fit['gain']:>10.4f}")
    fig.suptitle(f"LTI prototype — {label} (top: excitatory stim, bottom: inhibitory stim)")
    fig.tight_layout()
    out = Path(__file__).resolve().parent / "grid_png" / Path(save).name
    out.parent.mkdir(exist_ok=True)
    fig.savefig(out, dpi=140)
    print("wrote", out)


if __name__ == "__main__":
    import sys
    if "all" in sys.argv:
        fit_all()
    else:
        prototype()
