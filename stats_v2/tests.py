"""The one session-level test used everywhere (SPEC.md section 5), plus Holm adjustment."""
import warnings

import numpy as np
from scipy import stats


def _t_p(x):
    x = np.asarray(x, float)
    if len(x) < 2 or np.std(x, ddof=1) == 0:
        return np.nan
    return float(stats.ttest_1samp(x, 0.0).pvalue)


def sess_test(values, mouse, log=False):
    """values: one number per session; mouse: the mouse of each session.

    log=True: test log(values) against 0 and report the geometric mean (ratios).
    Sign count and mouse-sign agreement are counted against the sign of the session mean
    (on the tested scale).
    """
    v = np.asarray(values, float)
    mouse = np.asarray(mouse)
    ok = np.isfinite(v) & ((v > 0) if log else True)
    x = np.log(v[ok]) if log else v[ok]
    m = mouse[ok]
    n = len(x)
    mean = float(np.mean(x))
    sd = float(np.std(x, ddof=1))
    se = sd / np.sqrt(n)
    df = n - 1
    tcrit = stats.t.ppf(0.975, df)
    lo, hi = mean - tcrit * se, mean + tcrit * se
    tstat = mean / se
    p = float(2 * stats.t.sf(abs(tstat), df))

    # exact Wilcoxon signed-rank (two-sided)
    n_zero = int(np.sum(x == 0))
    nz = np.abs(x[x != 0])
    n_tied = int(len(nz) - len(np.unique(nz)))
    with warnings.catch_warnings(record=True) as w:
        warnings.simplefilter("always")
        wres = stats.wilcoxon(x, method="exact", alternative="two-sided")
    wil_note = "; ".join(str(i.message) for i in w)

    sgn = np.sign(mean)
    k = int(np.sum(np.sign(x) == sgn))
    k_n = int(np.sum(x != 0))

    # leave-one-mouse-out
    lomo = {}
    for mo in np.unique(m):
        lomo[str(mo)] = _t_p(x[m != mo])
    finite = {k_: p_ for k_, p_ in lomo.items() if np.isfinite(p_)}
    worst_mouse = max(finite, key=finite.get) if finite else None
    lomo_worst = finite[worst_mouse] if finite else np.nan

    # mouse-averaged
    mice = np.unique(m)
    mm = np.array([np.mean(x[m == mo]) for mo in mice])
    mouse_k = int(np.sum(np.sign(mm) == sgn))

    back = np.exp if log else (lambda z: z)
    return {
        "n": n,
        "mean": mean,
        "effect": float(back(mean)),
        "ci_lo": float(back(lo)),
        "ci_hi": float(back(hi)),
        "t": float(tstat),
        "df": df,
        "p": p,
        "wilcoxon_p": float(wres.pvalue),
        "wilcoxon_note": wil_note,
        "n_zero": n_zero,
        "n_tied": n_tied,
        "k": k,
        "k_n": k_n,
        "sign": "neg" if sgn < 0 else "pos",
        "lomo_p": lomo,
        "lomo_worst_p": lomo_worst,
        "lomo_worst_mouse": worst_mouse,
        "mouse_means": {str(mo): float(back(v_)) for mo, v_ in zip(mice, mm)},
        "mouse_k": mouse_k,
        "mouse_n": len(mice),
        "mouse_p": _t_p(mm),
    }


def holm(pvals):
    """Holm step-down adjusted p-values (same order as input)."""
    p = np.asarray(pvals, float)
    m = len(p)
    order = np.argsort(p)
    adj = np.empty(m)
    running = 0.0
    for i, idx in enumerate(order):
        running = max(running, min(1.0, (m - i) * p[idx]))
        adj[idx] = running
    return adj
