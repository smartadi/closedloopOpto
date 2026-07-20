"""tf_sweep.py — hyperparameter + model-class sweep for the site->site TF fits.

WHY: median in-sample R2 sits ~0.29 (amp 2.0) after onset-zeroing. This sweeps the free
knobs to find a better configuration WITHOUT just buying R2 with complexity.

Selection criterion is HELD-OUT CV-R2 (fit on trial-half A, score on half B and vice versa),
NOT in-sample R2 — adding poles always raises in-sample R2, so optimizing it is how you
overfit. Both are reported so the gap (= overfit margin) is visible.

Axes swept:
  model      "real" = sum of decaying real exponentials (current production model)
             "osc"  = sum of DAMPED SINUSOIDS  B*exp(-t/sig)*sin(w*t + ph).
                      Strictly more general: w->0, ph->pi/2 recovers a real exponential.
                      Motivation: the real-pole model CANNOT oscillate, but the responses
                      visibly rebound/overshoot (cf. the 7-8 Hz graph-wave modes), so the
                      rebound is currently unmodellable -> a hard ceiling on R2.
  max_order  number of modes allowed (CV picks within 1..max_order, parsimony margin applied)
  delay_max  transport lag theta free in [0, delay_max] (0 = pinned, current production)
  tmax       fit window [0, tmax]
  onset_pre  width of the pre-onset window whose mean defines the zero initial condition

Run (from bilateral/grid):
    ../../.venv/Scripts/python.exe tf_sweep.py            # stage A then stage B
    ../../.venv/Scripts/python.exe tf_sweep.py --pairs 120
"""
import sys
import time

import numpy as np
import scipy.optimize

import cross_response
import tf_fit

CV_MARGIN = 0.03


# --------------------------------------------------------------------------- #
# model evaluation
def _eval(t, theta, P, n, model):
    """Impulse response of n modes. real: (A,tau) per mode. osc: (B,sig,om,ph) per mode."""
    out = np.zeros_like(t)
    m = t >= theta
    dt = t[m] - theta
    if model == "real":
        A, tau = P[:n], P[n:2 * n]
        out[m] = sum(a * np.exp(-dt / k) for a, k in zip(A, tau))
    else:
        B, sig, om, ph = P[:n], P[n:2 * n], P[2 * n:3 * n], P[3 * n:4 * n]
        out[m] = sum(b * np.exp(-dt / s) * np.sin(o * dt + p)
                     for b, s, o, p in zip(B, sig, om, ph))
    return out


def _seed_bounds(n, peak, model, delay_max):
    """Initial guess + bounds. Seeds put the response at ~0 at t=0 (onset-zeroed data)."""
    sign = np.sign(peak) or 1.0
    a = abs(peak) if abs(peak) > 0 else 1e-3
    taus = list(np.geomspace(0.05, 0.4, n))
    if model == "real":
        p0 = [sign * a] + [-sign * a * 0.5] * (n - 1) + taus
        lo = [-1.0] * n + [1e-3] * n
        hi = [1.0] * n + [3.0] * n
    else:
        # seed phases at 0 -> h(0)=0 exactly; frequencies spread over 2..10 Hz
        oms = list(2 * np.pi * np.geomspace(2.0, 10.0, n))
        p0 = [sign * a] * n + taus + oms + [0.0] * n
        lo = [-1.0] * n + [1e-3] * n + [0.0] * n + [-np.pi] * n
        hi = [1.0] * n + [3.0] * n + [2 * np.pi * 15.0] * n + [np.pi] * n
    if delay_max > 0:
        p0 = [0.0] + p0; lo = [0.0] + lo; hi = [delay_max] + hi
    return np.asarray(p0), (np.asarray(lo), np.asarray(hi))


def _fit(t, h, n, model, delay_max):
    """Least-squares fit of an n-mode model; returns (yhat, sse)."""
    peak = h[np.argmax(np.abs(h))]
    p0, bnds = _seed_bounds(n, peak, model, delay_max)

    def resid(p):
        th, P = (p[0], p[1:]) if delay_max > 0 else (0.0, p)
        return _eval(t, th, P, n, model) - h

    r = scipy.optimize.least_squares(resid, p0, bounds=bnds, max_nfev=4000)
    th, P = (r.x[0], r.x[1:]) if delay_max > 0 else (0.0, r.x)
    yhat = _eval(t, th, P, n, model)
    return yhat, float(np.sum((yhat - h) ** 2))


def fit_pair(t, h, hA, hB, model, max_order, delay_max, tmax):
    """Production-equivalent fit: CV picks the order (simplest within CV_MARGIN of best),
    then refit on the full mean. Returns (r2_insample, cv_r2, order)."""
    post = (t >= 0) & (t <= tmax)
    tp, hp, hAp, hBp = t[post], h[post], hA[post], hB[post]
    orders = tuple(range(1, max_order + 1))
    cv = []
    for n in orders:
        try:
            yA, _ = _fit(tp, hAp, n, model, delay_max)
            yB, _ = _fit(tp, hBp, n, model, delay_max)
            cv.append(0.5 * (tf_fit._r2(yA, hBp) + tf_fit._r2(yB, hAp)))
        except Exception:
            cv.append(-np.inf)
    cv = np.asarray(cv)
    if not np.any(np.isfinite(cv)):
        return np.nan, np.nan, orders[0]
    i = int(np.where(cv >= np.nanmax(cv) - CV_MARGIN)[0].min())
    n = orders[i]
    yhat, sse = _fit(tp, hp, n, model, delay_max)
    sst = np.sum((hp - hp.mean()) ** 2) + 1e-12
    return 1.0 - sse / sst, float(cv[i]), n


# --------------------------------------------------------------------------- #
def load_pairs(n_pairs):
    """Strongest-response (stim,readout) pairs + their split-half means. R2 is only
    meaningful where there IS a response; noise pairs would swamp the medians."""
    z = cross_response.load_cached()
    H, window = z["H"], z["window"]
    HA, HB, _ = tf_fit.split_half_means()
    nS = H.shape[0]
    post = window >= 0
    strength = np.abs(H[:, :, post]).max(2)
    flat = np.argsort(-strength.ravel())
    idx = [(int(k // nS), int(k % nS)) for k in flat[:n_pairs]]
    print(f"selected {len(idx)} strongest pairs "
          f"(|peak| {strength.ravel()[flat[n_pairs-1]]:.4f}..{strength.ravel()[flat[0]]:.4f} dF/F)")
    return window, H, HA, HB, idx


def run(window, H, HA, HB, idx, model, max_order, delay_max, tmax, onset_pre):
    r2s, cvs, ords = [], [], []
    old = tf_fit.ONSET_PRE_S
    tf_fit.ONSET_PRE_S = onset_pre
    for s, r in idx:
        h, off = tf_fit._zero_onset(window, H[s, r])
        hA, hB = HA[s, r] - off, HB[s, r] - off      # SAME offset -> consistent CV
        if not (np.all(np.isfinite(h)) and np.all(np.isfinite(hA)) and np.all(np.isfinite(hB))):
            continue
        try:
            a, c, n = fit_pair(window, h, hA, hB, model, max_order, delay_max, tmax)
        except Exception:
            continue
        r2s.append(a); cvs.append(c); ords.append(n)
    tf_fit.ONSET_PRE_S = old
    return (np.nanmedian(r2s), np.nanmedian(cvs), np.mean(ords), len(r2s))


def sweep(configs, window, H, HA, HB, idx, title):
    print(f"\n=== {title} ===")
    print(f"{'model':>6}{'ord':>5}{'delay':>7}{'tmax':>6}{'pre':>6}"
          f"{'medR2':>8}{'medCV':>8}{'<n>':>6}{'sec':>7}")
    rows = []
    for c in configs:
        t0 = time.time()
        r2, cv, mo, k = run(window, H, HA, HB, idx, **c)
        rows.append((c, r2, cv, mo))
        print(f"{c['model']:>6}{c['max_order']:>5}{c['delay_max']:>7.3f}{c['tmax']:>6.2f}"
              f"{c['onset_pre']:>6.2f}{r2:>8.3f}{cv:>8.3f}{mo:>6.2f}{time.time()-t0:>7.1f}")
    best = max(rows, key=lambda r: (r[2] if np.isfinite(r[2]) else -np.inf))
    print(f"-> best by CV-R2: {best[0]}  medR2={best[1]:.3f} medCV={best[2]:.3f}")
    return best


if __name__ == "__main__":
    n_pairs = 150
    if "--pairs" in sys.argv:
        n_pairs = int(sys.argv[sys.argv.index("--pairs") + 1])
    window, H, HA, HB, idx = load_pairs(n_pairs)

    base = dict(delay_max=0.0, tmax=tf_fit.FIT_TMAX, onset_pre=tf_fit.ONSET_PRE_S)
    stageA = [dict(model=m, max_order=o, **base)
              for m in ("real", "osc") for o in (2, 3, 4)]
    bA = sweep(stageA, window, H, HA, HB, idx, "STAGE A — model class x max order")

    m, o = bA[0]["model"], bA[0]["max_order"]
    stageB = [dict(model=m, max_order=o, delay_max=d, tmax=tm, onset_pre=pr)
              for d in (0.0, 0.03) for tm in (0.35, 0.6, 1.0) for pr in (0.05, 0.10)]
    sweep(stageB, window, H, HA, HB, idx, f"STAGE B — delay x tmax x onset_pre (model={m}, ord={o})")
