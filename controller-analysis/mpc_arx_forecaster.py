"""AR / ARX disturbance forecaster for the preview MPC, after Lu et al. 2025 (Ziyu).

Lu, Li, Ladd, Matveev, Deole, Shea-Brown, Kutz, Steinmetz (2025), "Benchmarking Probabilistic
Time Series Forecasting Models on Neural Activity", arXiv:2510.18037. Their "AR" (AR(valQL)) is the
StatsForecast AutoRegressive model: univariate, Gaussian likelihood, lag order increased from 1 until
the validation MWQL (mean weighted quantile loss, q = 0.1..0.9) fails to improve for 10 consecutive
orders, then refit on train + validation. This file reproduces that recipe in plain numpy (no
statsforecast install) and adds the variant the paper could not have: exogenous LASER-COMMAND lags (ARX),
because in our data the stimulation is known to the controller.

Signal: the continuous-session disturbance d = recorded online dF/F - plant(recorded laser command),
exported by ctrl_mpc_arx_export.m (~66 min, 138k frames at 35 Hz). Same definition ctrl_mpc_lqr replays.

Cross-validation: the 5 trial folds of ctrl_mpc_forecasters. For fold f, every test CL trial's window
(-1 s .. +3 s + horizon, padded by the max lag so no regressor touches it) is removed from training;
everything else in the session (ITIs, OL trials, other CL trials) is training data. Within the
training data the last 20 % (chronological) is the validation set for lag selection, as in the paper.

Forecasts: iterated, from every stim-window origin t = 1..N of each test trial, Hp = 35 leads. Future
laser command (unknown at the origin: it is what the MPC is about to choose) is HELD at its last value.
Output is the departure d_hat - Dmean, exactly the quantity ctrl_mpc_lqr previews (DEP).

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_forecaster.py [sess]
OUT     controller-analysis/data/ctrl_mpc_arx_out_<sess>.mat  (F.pyar, F.pyarx [N x Hp x nT], fold,
        orders, skill)  -> ctrl_mpc_lqr('frame','fig3','fcstFile','ctrl_mpc_arx_out_%s.mat','fcstModel','pyarx')
"""
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat, savemat
from scipy.stats import norm

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
QS = np.arange(0.1, 0.91, 0.1)
P_MAX, PATIENCE = 150, 10            # lag search cap (4.3 s) and the paper's 10-order patience
Q_GRID = [2, 5, 10, 20, 35]          # laser-command lags tried for the ARX variant
VAL_FRAC = 0.2
SEL_H = 7                            # leads scored for order selection (200 ms = the MPC preview; paper used 35)
SEL_METRIC = "mse"                   # 'mwql' = the paper's criterion. DEVIATION (2026-10-07): MWQL also
                                     # scores interval calibration, and on clean data it prefers a wide-band
                                     # AR(1) whose point forecast is worse (lead-1 RMSE 0.67 vs 0.55 at p=10).
                                     # The MPC consumes only the point forecast (certainty equivalence) -> MSE.
FULL_SCAN = True                    # scan all orders instead of the paper's patience stop (see select_and_fit)


# ---------------------------------------------------------------------------------------------
def lagmat(x, rows, L):
    """Columns x[s-1], ..., x[s-L] for each target row s."""
    return x[rows[:, None] - np.arange(1, L + 1)[None, :]]


def fit(d, u, rows, p, q, ridge=1e-6):
    """Least-squares (= conditional Gaussian ML) AR(p) + u-lags(q) + intercept on target rows."""
    X = [lagmat(d, rows, p)]
    if q:
        X.append(lagmat(u, rows, q))
    X.append(np.ones((rows.size, 1)))
    X = np.hstack(X)
    G = X.T @ X + ridge * np.eye(X.shape[1])
    w = np.linalg.solve(G, X.T @ d[rows])
    s2 = np.mean((d[rows] - X @ w) ** 2)
    return w[:p], w[p:p + q], w[-1], s2


def forecast(d, u, origins, a, b, c, H):
    """Iterated mean forecast of d[i+1..i+H] from origins i (last observed frame). u held at u[i]."""
    p, q = a.size, b.size
    hist = d[origins[:, None] - np.arange(p)[None, :]]            # d[i], d[i-1], ... (lag-1 first)
    uh = u[origins[:, None] - np.arange(q)[None, :]] if q else None
    out = np.empty((origins.size, H))
    for j in range(H):
        nxt = hist @ a + c + (uh @ b if q else 0.0)
        out[:, j] = nxt
        hist = np.column_stack([nxt, hist[:, :-1]])
        if q:
            uh = np.column_stack([uh[:, 0], uh[:, :-1]])         # future command = last known
    return out


def forecast_known_u(d, u, origins, a, b, c, H):
    """As forecast(), but with the TRUE future command (open loop: the stim is pre-scheduled)."""
    p, q = a.size, b.size
    hist = d[origins[:, None] - np.arange(p)[None, :]]
    out = np.empty((origins.size, H))
    for j in range(H):
        nxt = hist @ a + c
        if q:
            nxt = nxt + u[origins[:, None] + j - np.arange(q)[None, :]] @ b
        out[:, j] = nxt
        hist = np.column_stack([nxt, hist[:, :-1]])
    return out


def psi_sd(a, s2, H):
    """Forecast sd per lead from the AR part's MA(inf) weights (u treated as known)."""
    p = a.size
    psi = np.zeros(H)
    psi[0] = 1.0
    for j in range(1, H):
        psi[j] = sum(a[i] * psi[j - 1 - i] for i in range(min(p, j)))
    return np.sqrt(s2 * np.cumsum(psi ** 2))


def mwql(y, mu, sd):
    """Mean weighted quantile loss over q = 0.1..0.9 (Gaussian predictive), as in Lu et al."""
    den = np.sum(np.abs(y))
    tot = 0.0
    for qq in QS:
        yq = mu + norm.ppf(qq) * sd
        tot += 2 * np.sum(np.maximum(qq * (y - yq), (qq - 1) * (y - yq))) / den
    return tot / QS.size


def select_and_fit(d, u, ok, H, use_u, known_u=False):
    """AR(valQL) order selection on the chronologically last 20 % of the usable frames, then refit.
    known_u: validate with the true future command (OL reconstruction) instead of holding the last
    one, and search the AR order WITH the longest u-lag window in place (when the signal contains stim
    responses, an order searched without the input would be spent modelling them)."""
    fc_fn = forecast_known_u if known_u else forecast
    q_search = max(Q_GRID) if (use_u and known_u) else 0
    T = d.size
    idx = np.flatnonzero(ok)
    cut = idx[int((1 - VAL_FRAC) * idx.size)]
    # a target row s is usable if s and its full regressor window are usable (no excluded frame)
    bad = np.flatnonzero(~ok)
    nb = np.searchsorted(bad, np.arange(T))                       # first excluded frame >= s
    prev_bad = np.where(nb > 0, bad[np.maximum(nb - 1, 0)], -10**9)  # last excluded frame < s

    def rows_ok(lo, hi, L):
        s = np.arange(max(lo, L), hi)
        return s[(s - prev_bad[s] > L) & ok[s]]

    tr = rows_ok(0, cut, P_MAX + max(Q_GRID))
    # validation origins: every H frames (non-overlapping targets), history + targets all usable
    vo = np.arange(cut + P_MAX + max(Q_GRID), T - H, H)
    vo = vo[[(vo_i - prev_bad[vo_i] > P_MAX + max(Q_GRID)) and ok[vo_i:vo_i + H + 1].all() for vo_i in vo]]
    yv = d[vo[:, None] + np.arange(1, SEL_H + 1)[None, :]]

    def score(p, q):
        a, b, c, s2 = fit(d, u, tr, p, q)
        fc = fc_fn(d, u, vo, a, b, c, SEL_H)
        if SEL_METRIC == "mse":
            return np.mean((yv - fc) ** 2)
        return mwql(yv, fc, psi_sd(a, s2, SEL_H)[None, :])

    # The paper's rule stops after PATIENCE non-improving orders. On clean data (warm-up excluded,
    # 2026-10-07) validation MWQL does not fall over p = 2..11, so that rule stops at p = 1 -- an AR(1)
    # no better than persistence at short leads. DEVIATION: scan every order up to P_MAX on a coarse
    # grid and take the true minimum (FULL_SCAN). Set FULL_SCAN = False to reproduce the paper's rule.
    if FULL_SCAN:
        grid = sorted(set(list(range(1, 21)) + list(range(25, P_MAX + 1, 5))))
        sc = {p: score(p, q_search) for p in grid}
        best_p = min(sc, key=sc.get); best = sc[best_p]
    else:
        best_p, best, stall, p = 1, np.inf, 0, 1
        while p <= P_MAX and stall < PATIENCE:
            s = score(p, q_search)
            if s < best - 1e-9:
                best, best_p, stall = s, p, 0
            else:
                stall += 1
            p += 1
    best_q = 0
    if use_u:
        sq = {q: score(best_p, q) for q in Q_GRID}
        best_q = min(sq, key=sq.get)
        best = sq[best_q]
    full = rows_ok(0, T, P_MAX + max(Q_GRID))                     # refit on train + validation
    a, b, c, s2 = fit(d, u, full, best_p, best_q)
    return dict(a=a, b=b, c=c, s2=s2, p=best_p, q=best_q, val_mwql=best)


# ---------------------------------------------------------------------------------------------
def main(sess="AL_0033_0226_e2"):
    M = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    d, u = M["d"].astype(float), M["u"].astype(float)
    on = M["onCL"].astype(int) - 1                                 # MATLAB 1-based -> 0-based
    fold = M["fold"].astype(int)
    Dmean = M["Dmean"].astype(float)
    pre, N, H = int(M["pre"]), int(M["N"]), int(M["Hp"])
    nT, T = on.size, d.size
    pad = P_MAX + max(Q_GRID)

    F = {m: np.full((N, H, nT), np.nan) for m in ("pyar", "pyarx")}
    orders = {m: [] for m in F}
    valid = M["valid"].astype(bool)                                # rolling-baseline warm-up excluded
    for f in np.unique(fold):
        te = np.flatnonzero(fold == f)
        ok = valid.copy()
        for k in te:                                               # test windows (+ horizon + lags)
            ok[max(0, on[k] - pre): min(T, on[k] + N + H + pad + 1)] = False
        for m, use_u in (("pyar", False), ("pyarx", True)):
            R = select_and_fit(d, u, ok, H, use_u)
            orders[m].append((int(f), R["p"], R["q"], R["val_mwql"]))
            print(f"[PYAR] fold {f} {m:6s} p={R['p']:3d} q={R['q']:2d} val MWQL={R['val_mwql']:.4f}", flush=True)
            for k in te:
                org = on[k] + np.arange(N)                         # origin t=1..N: last obs rel t-1
                fc = forecast(d, u, org, R["a"], R["b"], R["c"], H)
                rel_idx = pre + np.arange(1, N + 1)[:, None] + np.arange(H)[None, :]   # target rel t+j-1
                F[m][:, :, k] = fc - Dmean[np.minimum(rel_idx, Dmean.size - 1)]

    # skill: RMSE / climatology at leads, targets inside the stim window (same as ctrl_mpc_forecasters)
    DEP = np.stack([d[o - pre:o + N + 1] for o in on]) - Dmean[None, :]
    leads = np.array([1, 2, 3, 5, 7, 10, 17, 35])
    skill = {}
    for m in F:
        sk = []
        for L in leads:
            t = np.arange(1, N - L + 1)
            tgt = DEP[:, pre + t + L - 1].T                        # rel t+L-1
            fc = F[m][t - 1, L - 1, :]
            sk.append(np.sqrt(np.mean((tgt - fc) ** 2)) / np.sqrt(np.mean(tgt ** 2)))
        skill[m] = np.array(sk)
        print(f"[PYAR] {m:6s} error/climatology @ {np.round(leads * 1000 / 35).astype(int)} ms: {np.round(skill[m], 3)}")

    savemat(DATA / f"ctrl_mpc_arx_out_{sess}.mat", {
        "F": F, "fold": fold.astype(float), "leads_ms": leads * 1000 / 35,
        "skill": np.vstack([skill["pyar"], skill["pyarx"]]), "names": np.array(["pyar", "pyarx"], dtype=object),
        "orders_pyar": np.array(orders["pyar"]), "orders_pyarx": np.array(orders["pyarx"]),
        "source": "mpc_arx_forecaster.py (Lu et al. 2025 AR(valQL) + laser-command lags)"}, do_compression=True)
    print(f"[PYAR] -> {DATA / f'ctrl_mpc_arx_out_{sess}.mat'}")


if __name__ == "__main__":
    main(*sys.argv[1:])
