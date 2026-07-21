"""tf_fit.py — fit low-order LTI transfer functions to the s->r impulse responses.

Each H[s, r, :] (from cross_response.py) is the empirical impulse response from stim site
s to readout r. We fit a low-order LTI TF as a sum of DAMPED SINUSOID modes (MODEL="osc"):
    h(t) = sum_i A_i * exp(-(t-theta)/tau_i) * sin(om_i*(t-theta) + ph_i)   for t >= theta
Each mode is a complex-conjugate pole pair at -1/tau_i +- j*om_i. Setting om->0 recovers the
legacy pure-decay (real-pole) model, MODEL="real", which is retained for comparison.

Model class adopted 2026-07-20 from tf_sweep.py (150-pair sweep, matched tmax): real poles
CANNOT oscillate, but the responses rebound/overshoot, so the rebound was structurally
unmodellable and capped R2. Held-out CV-R2: real ord-3 0.232 -> osc ord-3 0.637.
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


ONSET_PRE_S = 0.10   # s — width of the immediate pre-onset window whose mean defines the
                     # "activity at stim onset". Subtracting it zeros the TF's initial condition
                     # (system at rest at onset), so the fit models the response, not a DC offset
                     # left over from baselining against the long 2 s pre-stim window.


def _zero_onset(t, h):
    """Return (h - onset_level, onset_level). onset_level = mean of h over [-ONSET_PRE_S, 0),
    so the shifted response is ZERO at stim onset — the correct zero initial condition for the
    sum-of-exponentials impulse-response fit. Falls back to the sample nearest t=0 if the
    pre-onset window is empty. NaN-safe."""
    pre = (t >= -ONSET_PRE_S) & (t < 0)
    off = np.nanmean(h[pre]) if np.any(pre) and np.any(np.isfinite(h[pre])) \
        else float(h[int(np.argmin(np.abs(t)))])
    return h - off, off


MODEL = "osc"        # "osc": each mode is a DAMPED SINUSOID B*exp(-t/sig)*sin(om*t+ph), i.e. a
                     # complex-conjugate pole pair. "real": legacy pure-decay modes (real poles).
                     # Adopted 2026-07-20 from the tf_sweep.py 150-pair sweep: at matched
                     # tmax=0.6 the osc family nearly TRIPLES held-out CV-R2 (real ord-3 0.232 ->
                     # osc ord-3 0.637). Reason is structural, not extra parameters: a sum of
                     # DECAYING real exponentials cannot oscillate, but the responses visibly
                     # rebound/overshoot (cf. the 7-8 Hz graph-wave modes), so the rebound was
                     # unmodellable -> a hard R2 ceiling. osc contains real as the om->0 limit.
OMEGA_MAX = 2 * np.pi * 15.0     # rad/s — cap mode frequency at 15 Hz (well above the ~7-8 Hz
                                 # network modes; the frame rate is 70 Hz -> Nyquist 35 Hz).


def _impulse(t, theta, A, tau, om=None, ph=None):
    """Impulse response as a sum of modes, zero before the delay theta.

    om/ph supplied -> damped sinusoids  sum_i A_i*exp(-(t-theta)/tau_i)*sin(om_i*(t-theta)+ph_i)
    om/ph None     -> legacy sum of pure decaying exponentials (real poles).
    """
    out = np.zeros_like(t)
    m = t >= theta
    dt = t[m] - theta
    if om is None:
        out[m] = sum(a * np.exp(-dt / tk) for a, tk in zip(A, tau))
    else:
        out[m] = sum(b * np.exp(-dt / s) * np.sin(o * dt + p)
                     for b, s, o, p in zip(A, tau, om, ph))
    return out


def _fit_order(t, h, n, peak):
    """Fit an n-mode model (no lag; theta pinned to 0); return (params, yhat, sse).
    Params per mode: real -> (A, tau); osc -> (A, tau, om, ph). Seeds put h(0)~0, matching the
    onset-zeroed data (phases seeded at 0 so sin(0)=0)."""
    sign = np.sign(peak) or 1.0
    a = abs(peak) if abs(peak) > 0 else 1e-3
    tau0 = list(np.geomspace(0.05, 0.4, n))
    if MODEL == "real":
        p0 = [sign * a] + [-sign * a * 0.5] * (n - 1) + tau0
        lo = [-1.0] * n + [1e-3] * n
        hi = [1.0] * n + [3.0] * n

        def resid(p):
            return _impulse(t, 0.0, p[:n], p[n:]) - h
    else:
        om0 = list(2 * np.pi * np.geomspace(2.0, 10.0, n))
        p0 = [sign * a] * n + tau0 + om0 + [0.0] * n
        lo = [-1.0] * n + [1e-3] * n + [0.0] * n + [-np.pi] * n
        hi = [1.0] * n + [3.0] * n + [OMEGA_MAX] * n + [np.pi] * n

        def resid(p):
            return _impulse(t, 0.0, p[:n], p[n:2 * n], p[2 * n:3 * n], p[3 * n:]) - h

    r = scipy.optimize.least_squares(resid, p0, bounds=(lo, hi), max_nfev=4000)
    if MODEL == "real":
        A, tau, om, ph = r.x[:n], r.x[n:], None, None
    else:
        A, tau, om, ph = r.x[:n], r.x[n:2 * n], r.x[2 * n:3 * n], r.x[3 * n:]
    yhat = _impulse(t, 0.0, A, tau, om, ph)
    return dict(theta=0.0, A=A, tau=tau, om=om, ph=ph), yhat, float(np.sum((yhat - h) ** 2))


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
        k = (4 if MODEL == "osc" else 2) * n     # params per mode; no lag term
        pen = k * np.log(n_obs) if criterion == "bic" else 2 * k
        ic = n_obs * np.log(sse / n_obs + 1e-30) + pen
        r2 = 1.0 - sse / ss_tot
        tv = np.asarray(params["tau"])
        ov = None if params["om"] is None else np.asarray(params["om"])
        cand = dict(order=n, ic=ic, r2=r2, sse=sse, theta=params["theta"],
                    tau=tv, A=np.asarray(params["A"]),
                    om=ov, ph=None if params["ph"] is None else np.asarray(params["ph"]),
                    poles=(-1.0 / tv) if ov is None else (-1.0 / tv + 1j * ov),
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


CV_MARGIN = 0.03   # min CV-R2 improvement to justify a higher order. A higher order is only
                   # accepted when it beats the simplest order-within-reach by more than this;
                   # otherwise the SIMPLEST order whose CV is within CV_MARGIN of the best wins.
                   # Prevents order inflation on marginal pairs where the extra pole only chases
                   # a noise-level sliver of held-out variance (parsimony / ~1-SE rule).


def fit_lti_cv(t, h, hA, hB, orders=ORDERS, margin=CV_MARGIN):
    """Select TF order by 2-fold split-half cross-validation, then refit on the full mean h.

    For each order: fit on half A, score R^2 on half B, and vice-versa; the CV score is the
    mean. Overfitting noise in one half does not predict the independent other half, so CV
    rejects orders that only fit noise. Among orders whose CV is within `margin` of the best,
    the SIMPLEST is chosen (parsimony: a higher order must EARN its complexity by > margin).
    Final params come from a refit on the full mean.
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
    if np.any(np.isfinite(cv)):
        within = np.where(cv >= np.nanmax(cv) - margin)[0]   # orders as good as best (± margin)
        i_best = int(within.min())                           # -> pick the SIMPLEST of them
        nbest, cv_best = orders[i_best], float(cv[i_best])   # report the CHOSEN order's CV
    else:
        nbest, cv_best = orders[0], np.nan
    params, yhat, sse = _fit_order(tp, hp, nbest, hp[np.argmax(np.abs(hp))])
    sst = np.sum((hp - hp.mean()) ** 2) + 1e-12
    tv = np.asarray(params["tau"])
    ov = None if params["om"] is None else np.asarray(params["om"])
    return dict(order=nbest, cvr2=cv_best,
                r2=1.0 - sse / sst, sse=sse, theta=0.0, tau=tv,
                A=np.asarray(params["A"]),
                om=ov, ph=None if params["ph"] is None else np.asarray(params["ph"]),
                poles=(-1.0 / tv) if ov is None else (-1.0 / tv + 1j * ov),
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
    tau = np.full((nS, nS, max(ORDERS)), np.nan)     # mode decay const (s), sorted ascending
    Amp = np.full((nS, nS, max(ORDERS)), np.nan)     # mode amplitudes, aligned to tau
    Om = np.full((nS, nS, max(ORDERS)), np.nan)      # mode frequencies (rad/s), aligned (osc)
    Ph = np.full((nS, nS, max(ORDERS)), np.nan)      # mode phases (rad), aligned (osc)
    Hs = np.array(H, float)                          # onset-zeroed copy (fit + store this)
    for s in range(nS):
        for r in range(nS):
            h, off = _zero_onset(window, H[s, r])    # zero the initial condition at onset
            Hs[s, r] = h
            if selection == "cv":
                f = fit_lti_cv(window, h, HA[s, r] - off, HB[s, r] - off, orders=orders)
                cvr2[s, r] = f["cvr2"]
            else:
                f = fit_lti(window, h, orders=orders, criterion=criterion)
            yhat[s, r] = _impulse(window, f["theta"], f["A"], f["tau"], f["om"], f["ph"])
            order[s, r] = f["order"]; r2[s, r] = f["r2"]; gain[s, r] = f["gain"]
            delay[s, r] = f["theta"]
            n = len(f["tau"]); o = np.argsort(f["tau"])
            tau[s, r, :n] = np.asarray(f["tau"])[o]
            Amp[s, r, :n] = np.asarray(f["A"])[o]
            if f["om"] is not None:
                Om[s, r, :n] = np.asarray(f["om"])[o]
                Ph[s, r, :n] = np.asarray(f["ph"])[o]
        print(f"  fit stim {s+1:2d}/{nS}  median R2(row)={np.nanmedian(r2[s]):.2f}", end="\r")
    print()
    print(f"fit all {nS}x{nS} ({selection}); order hist "
          f"{np.bincount(order.ravel(), minlength=6)[1:]}, median R2={np.nanmedian(r2):.2f}"
          + (f", median CV-R2={np.nanmedian(cvr2):.2f}" if selection == "cv" else ""))
    if cache:
        np.savez(CACHE_TF, H=Hs, Hsem=Hsem, Hstd=Hstd, yhat=yhat, sites=sites, window=window,
                 label=label, order=order, r2=r2, cvr2=cvr2, gain=gain, delay=delay, tau=tau,
                 A=Amp, om=Om, ph=Ph, model=MODEL)
        print("cached ->", CACHE_TF)
    return dict(H=Hs, Hsem=Hsem, Hstd=Hstd, yhat=yhat, sites=sites, window=window, order=order,
                r2=r2, cvr2=cvr2, gain=gain, delay=delay, tau=tau, A=Amp, om=Om, ph=Ph,
                model=MODEL, label=label)


# --------------------------------------------------------------------------- #
# TWO-AMPLITUDE variant: fit the 52x52 site->site TF matrix SEPARATELY for each laser
# amplitude of a multi-power session (2026-07-10 grid = [1.0, 2.0]). Same per-pair model
# and CV order selection as the single-amp path; adds an amp axis to every output so the
# fits are directly comparable (LTI check: poles amplitude-invariant, gain scales with power).
CACHE_TF2 = cross_response.CACHE.parent / "grid_tf_fits_2amp.npz"


def split_half_means_amp():
    """Even/odd-trial split-half means per amplitude from the 2-amp trials cache.

    Returns HA, HB (nA,nS,nS,nW) — two independent estimates of each pair's impulse response
    at each amp — plus amps and window. Onsets are filtered by Block-assigned power exactly as
    cross_response.extract_trials_amp, and the same per-half baseline convention as build_amps."""
    import scipy.interpolate
    zt = cross_response.load_trials2()
    roi_ts = zt["roi_ts"].astype(np.float64)
    svdT, onset_t, pos = zt["svdT"], zt["onset_t"], zt["pos"]
    onset_amp = np.round(zt["onset_amp"], 3)
    sites, window, base_ix = zt["sites"], zt["window"], int(zt["base_ix"])
    amps = [round(float(a), 3) for a in cross_response.load_cached2()["amps"]]
    nA, nS, nW = len(amps), len(sites), len(window)
    fr = [scipy.interpolate.interp1d(svdT, roi_ts[:, r], bounds_error=False, fill_value=np.nan)
          for r in range(nS)]
    HA = np.full((nA, nS, nS, nW), np.nan); HB = np.full((nA, nS, nS, nW), np.nan)
    for ai, amp in enumerate(amps):
        for s, (mx, my) in enumerate(sites):
            onsets = onset_t[(pos[:, 0] == mx) & (pos[:, 1] == my) & (onset_amp == amp)]
            a = np.arange(len(onsets)) % 2 == 0
            for r in range(nS):
                fluo = fr[r](window[None, :] + onsets[:, None])          # (nTrials,nW)
                for Hh, ix in ((HA, a), (HB, ~a)):
                    fh = fluo[ix]
                    if fh.shape[0] == 0:
                        continue
                    base = np.nanmean(fh[:, :base_ix])
                    Hh[ai, s, r] = np.nanmean((fh - base) / base, 0)
    return HA, HB, amps, window


def fit_all_amps(orders=ORDERS, selection="cv", cache=True):
    """Fit a TF to every (stim, readout) pair at EACH laser amplitude of the 2-amp session.

    Reads the 2-amp cross-response tensor (cross_response.load_cached2 -> H (nA,nS,nS,nW)) and,
    for CV order selection, the 2-amp split-half means. Caches per-amp H/yhat/order/r2/cvr2/
    gain/delay/tau/A (all with a leading amp axis) to grid_tf_fits_2amp.npz. Falls back to BIC
    if the 2-amp trials cache is missing."""
    z = cross_response.load_cached2()
    H, sites, window = z["H"], z["sites"], z["window"]        # H (nA,nS,nS,nW)
    amps = [round(float(a), 3) for a in z["amps"]]
    Hstd = z["Hstd"] if "Hstd" in z else np.zeros_like(H)
    nA, nS, nW = H.shape[0], len(sites), len(window)

    HA = HB = None
    if selection == "cv":
        try:
            HA, HB, amps_cv, _ = split_half_means_amp()
            assert amps_cv == amps, f"amp mismatch {amps_cv} vs {amps}"
        except Exception as e:
            print(f"  [cv] 2-amp trials cache unavailable ({e}); falling back to BIC")
            selection = "bic"

    yhat = np.zeros((nA, nS, nS, nW))
    order = np.zeros((nA, nS, nS), int)
    r2 = np.full((nA, nS, nS), np.nan)
    cvr2 = np.full((nA, nS, nS), np.nan)
    gain = np.zeros((nA, nS, nS))
    delay = np.zeros((nA, nS, nS))
    tau = np.full((nA, nS, nS, max(ORDERS)), np.nan)         # mode decay const (s), ascending
    Amp = np.full((nA, nS, nS, max(ORDERS)), np.nan)         # mode amplitudes, aligned to tau
    Om = np.full((nA, nS, nS, max(ORDERS)), np.nan)          # mode freqs (rad/s), aligned (osc)
    Ph = np.full((nA, nS, nS, max(ORDERS)), np.nan)          # mode phases (rad), aligned (osc)
    Hs = np.array(H, float)                                  # onset-zeroed copy (fit + store)
    for ai in range(nA):
        for s in range(nS):
            for r in range(nS):
                h = H[ai, s, r]
                if not np.all(np.isfinite(h)):               # site had no trials at this amp
                    continue
                h, off = _zero_onset(window, h)              # zero initial condition at onset
                Hs[ai, s, r] = h
                if selection == "cv" and np.all(np.isfinite(HA[ai, s, r])) \
                        and np.all(np.isfinite(HB[ai, s, r])):
                    f = fit_lti_cv(window, h, HA[ai, s, r] - off, HB[ai, s, r] - off, orders=orders)
                    cvr2[ai, s, r] = f["cvr2"]
                else:
                    f = fit_lti(window, h, orders=orders)
                yhat[ai, s, r] = _impulse(window, f["theta"], f["A"], f["tau"], f["om"], f["ph"])
                order[ai, s, r] = f["order"]; r2[ai, s, r] = f["r2"]
                gain[ai, s, r] = f["gain"]; delay[ai, s, r] = f["theta"]
                n = len(f["tau"]); o = np.argsort(f["tau"])
                tau[ai, s, r, :n] = np.asarray(f["tau"])[o]
                Amp[ai, s, r, :n] = np.asarray(f["A"])[o]
                if f["om"] is not None:
                    Om[ai, s, r, :n] = np.asarray(f["om"])[o]
                    Ph[ai, s, r, :n] = np.asarray(f["ph"])[o]
            print(f"  amp {amps[ai]}  stim {s+1:2d}/{nS}  median R2(row)={np.nanmedian(r2[ai, s]):.2f}",
                  end="\r")
        print()
        print(f"amp {amps[ai]}: order hist {np.bincount(order[ai].ravel(), minlength=6)[1:]}, "
              f"median R2={np.nanmedian(r2[ai]):.2f}"
              + (f", median CV-R2={np.nanmedian(cvr2[ai]):.2f}" if selection == "cv" else ""))
    if cache:
        np.savez(CACHE_TF2, H=Hs, Hstd=Hstd, yhat=yhat, sites=sites, window=window,
                 amps=np.array(amps, float), order=order, r2=r2, cvr2=cvr2, gain=gain,
                 delay=delay, tau=tau, A=Amp, om=Om, ph=Ph, model=MODEL)
        print("cached ->", CACHE_TF2)
    return dict(H=Hs, Hstd=Hstd, yhat=yhat, sites=sites, window=window, amps=amps, order=order,
                r2=r2, cvr2=cvr2, gain=gain, delay=delay, tau=tau, A=Amp, om=Om, ph=Ph,
                model=MODEL)


# --------------------------------------------------------------------------- #
# SHARED variant: ONE transfer function for ALL amplitudes, with the laser amplitude entering
# as the INPUT. The response to amplitude a is a*h(t) — there is deliberately NO free per-amp
# gain, because physically the bigger drive is what makes the response bigger, not a different
# system. This is the strict LTI statement (same dynamics AND same sensitivity).
#
# NOTE: this model FORCES a 2.0x ratio between amp 1.0 and 2.0, while the measured focal ratio
# is ~1.4-1.5x. The resulting systematic residual is therefore not a fit failure — it IS the
# quantity that measures saturation / departure from amplitude-linearity. Compare its per-amp
# R2 against the per-amp independent fits (fit_all_amps) to size that gap.
CACHE_TFS = cross_response.CACHE.parent / "grid_tf_fits_shared.npz"


GAMMA_BOUNDS = (0.1, 3.0)   # static input-nonlinearity exponent f(a)=(a/a_ref)^gamma.
                            # gamma=1 -> strictly linear in laser amplitude. The measured focal
                            # gain ratio is ~1.49 at doubled power -> gamma ~= 0.57 (saturating).


def _shared_weights(hs, amps, a_ref, weight):
    """Per-amplitude residual scale. The raw residual f(a)*b - h_a grows with a, so an
    UNWEIGHTED shared fit is dominated by the largest amplitude (SSE weight ~ (a2/a1)^2 = 4:1
    here) — the high-amp data sets h and the low amp is then scored on a curve it never
    influenced. Weighting equalises each amplitude's contribution.
      "none" — raw (legacy; high-amp dominated)
      "amp"  — divide by a/a_ref (known, parameter-free; responses scale ~linearly with a)
      "rms"  — divide by each amp's own response RMS (data-derived, fully size-equalising)
    """
    if weight == "amp":
        return np.asarray([a / a_ref for a in amps], float)
    if weight == "rms":
        return np.asarray([np.sqrt(np.nanmean(h ** 2)) + 1e-12 for h in hs], float)
    return np.ones(len(amps))


def _fit_order_shared(t, hs, amps, n, peak, fit_gamma=True, weight="amp", a_ref=None):
    """Fit ONE n-mode impulse response h(t) shared by every amplitude.

    Response to amplitude a is  f(a)*h(t)  with  f(a) = (a/a_ref)^gamma.  h is therefore the
    response AT the reference amplitude (a_ref = smallest amp), which removes the h<->f scale
    degeneracy. gamma=1 (fit_gamma=False) is the strict amplitude-linear model.
    Returns (params, base, yhat_per_amp, sse) — sse UNWEIGHTED so it stays comparable.
    """
    a_ref = float(np.min(amps)) if a_ref is None else float(a_ref)
    w = _shared_weights(hs, amps, a_ref, weight)
    sign = np.sign(peak) or 1.0
    a0 = abs(peak) if abs(peak) > 0 else 1e-3
    tau0 = list(np.geomspace(0.05, 0.4, n))
    if MODEL == "real":
        p0 = [sign * a0] + [-sign * a0 * 0.5] * (n - 1) + tau0
        lo = [-1.0] * n + [1e-3] * n
        hi = [1.0] * n + [3.0] * n
        nmode = 2 * n

        def base_of(p):
            return _impulse(t, 0.0, p[:n], p[n:2 * n])
    else:
        om0 = list(2 * np.pi * np.geomspace(2.0, 10.0, n))
        p0 = [sign * a0] * n + tau0 + om0 + [0.0] * n
        lo = [-1.0] * n + [1e-3] * n + [0.0] * n + [-np.pi] * n
        hi = [1.0] * n + [3.0] * n + [OMEGA_MAX] * n + [np.pi] * n
        nmode = 4 * n

        def base_of(p):
            return _impulse(t, 0.0, p[:n], p[n:2 * n], p[2 * n:3 * n], p[3 * n:4 * n])

    if fit_gamma:
        p0 = p0 + [1.0]; lo = lo + [GAMMA_BOUNDS[0]]; hi = hi + [GAMMA_BOUNDS[1]]

    def drive(p):
        g = p[nmode] if fit_gamma else 1.0
        return [(a / a_ref) ** g for a in amps]

    def resid(p):
        b = base_of(p)
        return np.concatenate([(d * b - h) / wi
                               for d, h, wi in zip(drive(p), hs, w)])

    r = scipy.optimize.least_squares(resid, p0, bounds=(lo, hi), max_nfev=6000)
    base = base_of(r.x)
    gamma = float(r.x[nmode]) if fit_gamma else 1.0
    if MODEL == "real":
        A, tau, om, ph = r.x[:n], r.x[n:2 * n], None, None
    else:
        A, tau, om, ph = r.x[:n], r.x[n:2 * n], r.x[2 * n:3 * n], r.x[3 * n:4 * n]
    yh = [(a / a_ref) ** gamma * base for a in amps]
    sse = float(sum(np.sum((y - h) ** 2) for y, h in zip(yh, hs)))
    return dict(theta=0.0, A=A, tau=tau, om=om, ph=ph, gamma=gamma), base, yh, sse


def fit_lti_cv_shared(t, hs, hAs, hBs, amps, orders=ORDERS, margin=CV_MARGIN,
                      fit_gamma=True, weight="amp"):
    """Split-half CV order selection for the shared model; CV pooled over amplitudes."""
    post = (t >= 0) & (t <= FIT_TMAX)
    tp = t[post]
    hsp = [h[post] for h in hs]
    hAp = [h[post] for h in hAs]
    hBp = [h[post] for h in hBs]
    ia = int(np.argmin(amps))                    # h is the response AT the reference amp
    pk = hsp[ia][np.argmax(np.abs(hsp[ia]))]
    kw = dict(fit_gamma=fit_gamma, weight=weight)

    cv = []
    for n in orders:
        try:
            _, _, yA, _ = _fit_order_shared(tp, hAp, amps, n, pk, **kw)
            _, _, yB, _ = _fit_order_shared(tp, hBp, amps, n, pk, **kw)
            cv.append(0.5 * (_r2(np.concatenate(yA), np.concatenate(hBp))
                             + _r2(np.concatenate(yB), np.concatenate(hAp))))
        except Exception:
            cv.append(-np.inf)
    cv = np.asarray(cv)
    if np.any(np.isfinite(cv)):
        i_best = int(np.where(cv >= np.nanmax(cv) - margin)[0].min())
        nbest, cv_best = orders[i_best], float(cv[i_best])
    else:
        nbest, cv_best = orders[0], np.nan

    params, base, yh, sse = _fit_order_shared(tp, hsp, amps, nbest, pk, **kw)
    r2a = [1.0 - np.sum((y - h) ** 2) / (np.sum((h - h.mean()) ** 2) + 1e-12)
           for y, h in zip(yh, hsp)]
    allh = np.concatenate(hsp)
    r2_pool = 1.0 - sse / (np.sum((allh - allh.mean()) ** 2) + 1e-12)
    return dict(order=nbest, cvr2=cv_best, r2=r2_pool, r2_amp=np.asarray(r2a), sse=sse,
                theta=0.0, tau=np.asarray(params["tau"]), A=np.asarray(params["A"]),
                om=None if params["om"] is None else np.asarray(params["om"]),
                ph=None if params["ph"] is None else np.asarray(params["ph"]),
                gamma=params["gamma"], base=base, yhat=yh, t=tp)


def fit_shared(orders=ORDERS, cache=True, fit_gamma=True, weight="amp", tag=None):
    """One TF per (stim, readout) pair, SHARED across amplitudes (amp = input scale)."""
    z = cross_response.load_cached2()
    H, sites, window = z["H"], z["sites"], z["window"]          # H (nA,nS,nS,nW)
    amps = [round(float(a), 3) for a in z["amps"]]
    Hstd = z["Hstd"] if "Hstd" in z else np.zeros_like(H)
    nA, nS, nW = H.shape[0], len(sites), len(window)
    HA, HB, amps_cv, _ = split_half_means_amp()
    assert amps_cv == amps, f"amp mismatch {amps_cv} vs {amps}"

    yhat = np.zeros((nA, nS, nS, nW))
    base = np.zeros((nS, nS, nW))                              # the shared h(t), per unit amp
    order = np.zeros((nS, nS), int)
    r2 = np.full((nS, nS), np.nan)                             # pooled over amps
    r2a = np.full((nA, nS, nS), np.nan)                        # per amp
    cvr2 = np.full((nS, nS), np.nan)
    gain = np.zeros((nA, nS, nS))
    tau = np.full((nS, nS, max(ORDERS)), np.nan)
    Amp = np.full((nS, nS, max(ORDERS)), np.nan)
    Om = np.full((nS, nS, max(ORDERS)), np.nan)
    Ph = np.full((nS, nS, max(ORDERS)), np.nan)
    Gam = np.full((nS, nS), np.nan)
    Hs = np.array(H, float)
    a_ref = float(np.min(amps))

    for s in range(nS):
        for r in range(nS):
            hs, hAs, hBs, ok = [], [], [], True
            for ai in range(nA):
                h = H[ai, s, r]
                if not np.all(np.isfinite(h)) or not np.all(np.isfinite(HA[ai, s, r])) \
                        or not np.all(np.isfinite(HB[ai, s, r])):
                    ok = False
                    break
                hz, off = _zero_onset(window, h)
                Hs[ai, s, r] = hz
                hs.append(hz); hAs.append(HA[ai, s, r] - off); hBs.append(HB[ai, s, r] - off)
            if not ok:
                continue
            f = fit_lti_cv_shared(window, hs, hAs, hBs, amps, orders=orders,
                                  fit_gamma=fit_gamma, weight=weight)
            bfull = _impulse(window, f["theta"], f["A"], f["tau"], f["om"], f["ph"])
            base[s, r] = bfull
            for ai in range(nA):
                yhat[ai, s, r] = (amps[ai] / a_ref) ** f["gamma"] * bfull
                gain[ai, s, r] = yhat[ai, s, r][np.argmax(np.abs(yhat[ai, s, r]))]
            order[s, r] = f["order"]; r2[s, r] = f["r2"]; cvr2[s, r] = f["cvr2"]
            r2a[:, s, r] = f["r2_amp"]; Gam[s, r] = f["gamma"]
            n = len(f["tau"]); o = np.argsort(f["tau"])
            tau[s, r, :n] = f["tau"][o]; Amp[s, r, :n] = f["A"][o]
            if f["om"] is not None:
                Om[s, r, :n] = f["om"][o]; Ph[s, r, :n] = f["ph"][o]
        print(f"  shared fit stim {s+1:2d}/{nS}  median pooled R2={np.nanmedian(r2[s]):.2f}",
              end="\r")
    print()
    gtxt = "gamma FREE" if fit_gamma else "gamma=1 (linear)"
    print(f"shared fit {nS}x{nS} ({MODEL}, {gtxt}, weight={weight}); order hist "
          f"{np.bincount(order.ravel(), minlength=6)[1:]}, median pooled R2={np.nanmedian(r2):.2f}, "
          f"median CV-R2={np.nanmedian(cvr2):.2f}")
    for ai in range(nA):
        print(f"  amp {amps[ai]}: median R2={np.nanmedian(r2a[ai]):.2f}")
    if fit_gamma:
        gg = Gam[cvr2 > 0]
        gg = gg[np.isfinite(gg)]
        if gg.size:
            print(f"  gamma (CV-R2>0 pairs, n={gg.size}): median={np.median(gg):.3f}  "
                  f"IQR=[{np.percentile(gg,25):.3f},{np.percentile(gg,75):.3f}]  "
                  f"(1.0 = amplitude-linear)")
    out = CACHE_TFS if tag is None else CACHE_TFS.with_name(f"grid_tf_fits_shared_{tag}.npz")
    if cache:
        np.savez(out, H=Hs, Hstd=Hstd, yhat=yhat, base=base, sites=sites, window=window,
                 amps=np.array(amps, float), order=order, r2=r2, r2_amp=r2a, cvr2=cvr2,
                 gain=gain, tau=tau, A=Amp, om=Om, ph=Ph, gamma=Gam, model=MODEL,
                 fit_gamma=fit_gamma, weight=weight, a_ref=a_ref)
        print("cached ->", out)
    return dict(H=Hs, yhat=yhat, base=base, sites=sites, window=window, amps=amps, order=order,
                r2=r2, r2_amp=r2a, cvr2=cvr2, gain=gain, tau=tau, A=Amp, om=Om, ph=Ph, gamma=Gam)


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
        h, _ = _zero_onset(window, H[s, r])          # zero initial condition at onset
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
    if "shared" in sys.argv:
        # Three variants isolate the two effects:
        #   linW  weighted, gamma=1  -> how much of the amp-1.0 failure was LS high-amp dominance
        #   (default) weighted, gamma free -> how much of the remainder is saturation
        if "linear" in sys.argv:
            fit_shared(fit_gamma=False, weight="amp", tag="linw")
        elif "raw" in sys.argv:
            fit_shared(fit_gamma=False, weight="none", tag="raw")
        else:
            fit_shared(fit_gamma=True, weight="amp")
    elif "2amp" in sys.argv:
        fit_all_amps()
    elif "all" in sys.argv:
        fit_all()
    else:
        prototype()
