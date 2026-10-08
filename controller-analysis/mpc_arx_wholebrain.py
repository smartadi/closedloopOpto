"""Whole-brain ARX: forecast the controlled ROI from its own history + the stim + the time history of
N evenly spaced spots across the brain mask (file tags 100 and 200 by default; the 200 grid holds 199). Held-out OL trial test, same folds as
mpc_arx_ol_recon. Scored as R^2 (user 2026-10-07: "model performance ... should be r squared").

Why DIRECT (one ridge regression per lead) and not iterated: an iterated forecast would have to forecast
all 100 spots too (a 101-channel VAR). Direct multi-step regresses y[t+h] on everything known at the
origin t -- y lags, the brain spots' lags, past stim -- plus the stim SCHEDULED for t+1..t+h (known in OL),
so no spot ever has to be forecast. Both models below are direct, so the comparison isolates the brain.

  uni   y[t..t-69], u[t..t-34], u[t+1..t+h]                       (single ROI, as before)
  wb    uni + X_k[t..t-L+1] for the 100 spots (L = 10 frames = 286 ms)
Ridge (features scaled per block by their sd; intercept unpenalised), lambda per model by validation MSE
over leads 1..35 on the chronologically last 20 % of training rows (Lu et al. split), then refit on all.
CV: 5 folds over the 92 OL trials (same seed / folds as mpc_arx_ol_recon); each test trial's window
-1 s .. +5 s, padded by the max lag and horizon, never enters training. Training = spont + training OL.

Inputs: data/ctrl_mpc_arx_in_<sess>.mat (y, u, onsets), data/ctrl_mpc_wb_in_<sess>_n<N>.mat (X, spots)
Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_wholebrain.py [sess] [spot-file tags, e.g. 100,200]
OUT     data/mpc_arx_wholebrain_<sess>.mat, paper/images/mpc_arx/wb_*.png
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat

HERE = Path(__file__).resolve().parent
DATA, FIG = HERE / "data", HERE.parent / "paper" / "images" / "mpc_arx"
PY, QU, L_SP, HMAX = 70, 35, 10, 141            # y lags, past-u lags, spot lags, max lead (rel 0..140)
POST, VAL_FRAC = 70, 0.2
LAMS = 10.0 ** np.arange(-3, 6)                 # first run (warm-up contaminated) hit the 0.1 floor
LEADS = np.array([1, 2, 3, 5, 7, 10, 17, 35])


class Feats:
    """Builds the direct-forecast design for origins t (last observed frame)."""
    def __init__(self, y, u, X, use_wb, valid):
        # block scales from VALID frames only (y.std over the warm-up was 268 vs ~3 -> y lags were
        # effectively over-penalised in the first run)
        self.y, self.u = y / y[valid].std(), u / u[valid].std()
        self.X, self.wb = X / X[valid].std(0), use_wb
        self.nS = X.shape[1]
        # column blocks: [y lags | u past | u future 1..HMAX | spots (lag-major) | 1]
        self.n_base = PY + QU + HMAX
        self.F = self.n_base + (self.nS * L_SP if use_wb else 0) + 1
        self.maxlag = max(PY, QU, L_SP if use_wb else 0)

    def __call__(self, t):
        cols = [self.y[t[:, None] - np.arange(PY)], self.u[t[:, None] - np.arange(QU)],
                self.u[t[:, None] + 1 + np.arange(HMAX)]]
        if self.wb:
            cols.append(self.X[t[:, None] - np.arange(L_SP)].reshape(t.size, -1))
        cols.append(np.ones((t.size, 1)))
        return np.hstack(cols)

    def allowed(self, h):
        """Column mask for lead h: future stim only up to t+h."""
        m = np.ones(self.F, bool)
        m[PY + QU + h: PY + QU + HMAX] = False
        return m


def accumulate(fe, rows, Y, chunk=8000):
    G = np.zeros((fe.F, fe.F)); B = np.zeros((fe.F, Y.shape[1]))
    for i in range(0, rows.size, chunk):
        r = rows[i:i + chunk]
        A = fe(r)
        G += A.T @ A
        B += A.T @ Y[i:i + chunk]
    return G, B


def solve_all(fe, G, B, lam, leads):
    """Weights per lead (columns), respecting the per-lead causal stim mask."""
    W = np.zeros((fe.F, leads.size))
    pen = np.full(fe.F, lam); pen[-1] = 0.0
    for j, h in enumerate(leads):
        m = fe.allowed(h)
        W[m, j] = np.linalg.solve(G[np.ix_(m, m)] + np.diag(pen[m]), B[m, j])
    return W


def r2(y, yhat):
    """Coefficient of determination, pooled: 1 - SSE / SS around the targets' own mean."""
    return 1 - np.sum((y - yhat) ** 2) / np.sum((y - y.mean()) ** 2)


def main(sess="AL_0033_0226_e2", spots="100,200"):     # file tags = requested counts (200 -> 199 on the grid)
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    y, u = A["y"].astype(float), A["u"].astype(float)
    valid = A["valid"].astype(bool)                                # rolling-baseline warm-up (40 s)
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = y.size, onOL.size
    leads = np.arange(1, HMAX + 1)
    WB = {int(n): loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n{n}.mat", squeeze_me=True) for n in spots.split(",")}

    def win_mask(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m

    inOL, inCL = win_mask(onOL, -pre, N + POST), win_mask(onCL, -pre, N + POST)
    spont = ~(inOL | inCL)
    rng = np.random.default_rng(7)
    fold = rng.permutation(np.arange(nO) % 5) + 1                  # identical to mpc_arx_ol_recon

    FE = {"ROI only": Feats(y, u, WB[min(WB)]["X"].astype(float), False, valid)}
    for n, W_ in WB.items():
        X = W_["X"].astype(float)
        r_sp = np.array([np.corrcoef(X[valid, k], y[valid])[0, 1] for k in range(X.shape[1])])
        print(f"[WB] {n} spots | corr(spot, ROI) max {r_sp.max():.2f} median {np.median(r_sp):.2f}", flush=True)
        FE[f"+ {X.shape[1]} spots"] = Feats(y, u, X, True, valid)
    FC = {m: np.full((nO, N + 1, HMAX), np.nan) for m in FE}       # origins rel -1..N-1, leads 1..HMAX
    TMPL = np.full((nO, HMAX), np.nan)                             # training-fold OL average, rel 0..140
    lam_sel, wmap = {m: [] for m in FE}, {m: [] for m in FE}
    for f in range(1, 6):
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        TMPL[te] = np.mean([y[o:o + HMAX] for o in onOL[tr]], axis=0)
        ok = (spont | win_mask(onOL[tr], -pre, N + POST)) & ~win_mask(onOL[te], -pre - PY, N + POST + HMAX) & valid
        cs = np.concatenate([[0], np.cumsum(~ok)])
        for m, fe in FE.items():
            t_all = np.arange(fe.maxlag, T - HMAX - 1)               # origin usable iff t-maxlag+1..t+HMAX usable
            rows = t_all[(cs[t_all + HMAX + 1] - cs[t_all - fe.maxlag + 1]) == 0]
            cut = rows[int((1 - VAL_FRAC) * rows.size)]
            r_tr, r_va = rows[rows < cut - HMAX], rows[rows >= cut]
            G1, B1 = accumulate(fe, r_tr, y[r_tr[:, None] + leads])
            va_s = r_va[::3]; Ava = fe(va_s); Yv = y[va_s[:, None] + leads[:35]]
            errs = [np.mean((Ava @ solve_all(fe, G1, B1[:, :35], lam, leads[:35]) - Yv) ** 2) for lam in LAMS]
            lam = LAMS[int(np.argmin(errs))]
            G2, B2 = accumulate(fe, r_va, y[r_va[:, None] + leads])
            W = solve_all(fe, G1 + G2, B1 + B2, lam, leads)
            lam_sel[m].append(lam)
            print(f"[WB] fold {f} {m:12s} train rows {r_tr.size + r_va.size} lambda {lam:g}", flush=True)
            for k in te:
                FC[m][k] = fe(onOL[k] - 1 + np.arange(N + 1)) @ W   # origin rel -1 .. N-1
            if fe.wb:                                              # spot importance at 86 ms (lead 3)
                ws = W[fe.n_base:fe.n_base + fe.nS * L_SP, 2].reshape(L_SP, fe.nS)
                wmap[m].append(np.sqrt((ws ** 2).sum(0)))

    REC = np.stack([y[o:o + HMAX] for o in onOL]); PRE = np.stack([y[o - pre:o] for o in onOL])
    w03 = slice(0, N)
    # ---- R^2 on held-out OL trials --------------------------------------------------------------
    # k-step: targets rel t0+L-1 for origins rel t0-1, t0 = 0..N-L (all inside 0..3 s), pooled over trials
    def kstep(get):
        out = []
        for L in LEADS:
            t0 = np.arange(N - L + 1)
            out.append((REC[:, t0 + L - 1], get(L, t0)))
        return out
    pairs = {m: kstep(lambda L, t0, m=m: FC[m][:, t0, L - 1]) for m in FE}
    pairs["persistence"] = kstep(lambda L, t0: np.stack([y[o + t0 - 1] for o in onOL]))
    pairs["stim-locked mean"] = kstep(lambda L, t0: TMPL[:, t0 + L - 1])
    R2 = {m: np.array([r2(a, b) for a, b in v]) for m, v in pairs.items()}
    # beyond the stim-locked mean: how much of the trial-to-trial deviation is predicted
    R2dev = {m: np.array([1 - np.sum((a - b) ** 2) / np.sum((a - c) ** 2)
                          for (a, b), (_, c) in zip(v, pairs["stim-locked mean"])]) for m, v in pairs.items()}
    free = {m: FC[m][:, 0, :] for m in FE}                         # from rel -1: leads 1..141 = rel 0..140
    free["stim-locked mean"] = TMPL
    fr_single = {m: r2(REC[:, w03], v[:, w03]) for m, v in free.items()}
    fr_avg = {m: r2(REC[:, w03].mean(0), v[:, w03].mean(0)) for m, v in free.items()}
    lead_ms = LEADS * 1000 / Fs
    print(f"[WB] k-step R2 (held-out OL, targets 0-3 s) @ {np.round(lead_ms).astype(int)} ms")
    for m in R2:
        print(f"       {m:17s} {np.round(R2[m], 3)}")
    print(f"[WB] k-step R2 of the deviation from the stim-locked mean")
    for m in R2dev:
        if m != "stim-locked mean":
            print(f"       {m:17s} {np.round(R2dev[m], 3)}")
    print("[WB] forecast from -1 frame (whole trial): single-trial R2 " +
          ", ".join(f"{m} {v:.3f}" for m, v in fr_single.items()))
    print("[WB]                                        trial-avg R2    " +
          ", ".join(f"{m} {v:.3f}" for m, v in fr_avg.items()))

    # ---- figures ---------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    pal = {"ROI only": "#5b2c86", "persistence": "0.45", "stim-locked mean": "0.65"}
    reds = ["#e07a5f", "#b5179e", "#d1495b"]
    for i, m in enumerate([m for m in FE if m != "ROI only"]):
        pal[m] = reds[i % 3]
    nBig = max(WB); mBig = f"+ {WB[nBig]['X'].shape[1]} spots"
    fig, ax = plt.subplots(1, 4, figsize=(19, 4.3), constrained_layout=True)
    a = ax[0]; W_ = WB[nBig]
    a.imshow(W_["mimg"], cmap="gray"); a.contour(W_["mask"], [0.5], colors="w", linewidths=0.6)
    sc = a.scatter(W_["rc"][:, 1] - 1, W_["rc"][:, 0] - 1, c=np.mean(wmap[mBig], 0), s=16, cmap="magma",
                   edgecolors="w", linewidths=0.3)
    a.plot(W_["site_rc"][1] - 1, W_["site_rc"][0] - 1, "c+", ms=12, mew=2)
    a.set_title(f"{WB[nBig]['X'].shape[1]} spots: weight norm, 86 ms forecast (+ laser)", fontsize=9); a.axis("off")
    plt.colorbar(sc, ax=a, fraction=0.04)
    for a, D, ttl in ((ax[1], R2, "R² of the forecast (held-out OL, targets 0-3 s)"),
                      (ax[2], R2dev, "R² of the deviation from the stim-locked mean")):
        for m, v in D.items():
            if D is R2dev and m == "stim-locked mean":
                continue
            ls = ":" if m in ("persistence", "stim-locked mean") else "-"
            a.plot(lead_ms, v, ls, marker="o" if ls == "-" else None, ms=3, color=pal[m], label=m)
        a.axvline(57, color="0.7", lw=0.6, ls=":"); a.axhline(0, color="0.8", lw=0.6)
        a.set_xscale("log"); a.set_xlabel("forecast lead (ms)"); a.set_ylabel("R²")
        a.set_title(ttl, fontsize=9); a.legend(fontsize=7, frameon=False)
    a = ax[3]
    tt, ts = np.arange(-pre, HMAX) / Fs, np.arange(HMAX) / Fs
    a.plot(tt, np.concatenate([PRE.mean(0), REC.mean(0)]), "k", lw=1.6, label="recorded")
    for m in FE:
        a.plot(ts, free[m].mean(0), color=pal[m], lw=1.1,
               label=f"{m} (avg R² {fr_avg[m]:.2f}, single-trial {fr_single[m]:.2f})")
    a.set_xlabel("time from onset (s)"); a.set_ylabel("dF/F (%)"); a.legend(fontsize=6.5, frameon=False)
    a.set_title("forecast from -1 frame with the known stim: trial average", fontsize=9)
    fig.savefig(FIG / f"wb_arx_{sess}.png", dpi=200)

    rmse_b = np.sqrt(np.mean((free[mBig][:, w03] - REC[:, w03]) ** 2, 1))
    ex = np.argsort(rmse_b)[[nO // 4, nO // 2, 3 * nO // 4]]
    fig2, ax2 = plt.subplots(1, 3, figsize=(15, 3.6), constrained_layout=True)
    t86 = np.arange(N) / Fs + 2 / Fs                                # target time of the lead-3 forecast
    for i, k in enumerate(ex):
        a = ax2[i]
        a.plot(tt, np.concatenate([PRE[k], REC[k]]), "k", lw=1.1, label="recorded")
        for m in ("ROI only", mBig):
            a.plot(t86, FC[m][k, :N, 2], color=pal[m], lw=1, label=f"86 ms ahead, {m}")
        a.axvline(0, color="0.7", lw=0.6); a.axvline(3, color="0.7", lw=0.6)
        a.set_title(f"held-out OL trial {k + 1} (fold {fold[k]})", fontsize=9); a.set_xlabel("time from onset (s)")
        if i == 0:
            a.set_ylabel("dF/F (%)"); a.legend(fontsize=7, frameon=False)
    fig2.savefig(FIG / f"wb_arx_examples_{sess}.png", dpi=200)

    key = lambda m: m.replace(" ", "_").replace("+", "wb").replace("-", "_")
    savemat(DATA / f"mpc_arx_wholebrain_{sess}.mat", {
        "R2": {key(m): v for m, v in R2.items()}, "R2dev": {key(m): v for m, v in R2dev.items()},
        "R2_free_single": {key(m): v for m, v in fr_single.items()},
        "R2_free_avg": {key(m): v for m, v in fr_avg.items()}, "lead_ms": lead_ms,
        "lambda": {key(m): np.array(v) for m, v in lam_sel.items()},
        "spot_weight86": {key(m): np.mean(v, 0) for m, v in wmap.items() if v}, "fold": fold, "L_spot": L_SP},
        do_compression=True)
    print(f"[WB] -> {FIG / f'wb_arx_{sess}.png'}")


if __name__ == "__main__":
    main(*sys.argv[1:])