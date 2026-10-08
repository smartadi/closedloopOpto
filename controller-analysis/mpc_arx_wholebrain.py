"""Whole-brain ARX: forecast the controlled ROI from its own history + the stim + the time history of
100 evenly spaced spots across the brain mask. Held-out OL trial test, same folds as mpc_arx_ol_recon.

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

Inputs: data/ctrl_mpc_arx_in_<sess>.mat (y, u, onsets), data/ctrl_mpc_wb_in_<sess>.mat (X, spots)
Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_wholebrain.py [sess]
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
    def __init__(self, y, u, X, use_wb):
        self.y, self.u, self.X, self.wb = y / y.std(), u / u.std(), X / X.std(0), use_wb
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


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    Wb = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}.mat", squeeze_me=True)
    y, u, X = A["y"].astype(float), A["u"].astype(float), Wb["X"].astype(float)
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = y.size, onOL.size
    leads = np.arange(1, HMAX + 1)
    valid = A["valid"].astype(bool)                                # rolling-baseline warm-up (40 s)
    r_sp = np.array([np.corrcoef(X[valid, k], y[valid])[0, 1] for k in range(X.shape[1])])
    print(f"[WB] {sess}: {X.shape[1]} spots | corr(spot, ROI) max {r_sp.max():.2f} median {np.median(r_sp):.2f}", flush=True)

    def win_mask(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m

    inOL, inCL = win_mask(onOL, -pre, N + POST), win_mask(onCL, -pre, N + POST)
    spont = ~(inOL | inCL)
    rng = np.random.default_rng(7)
    fold = rng.permutation(np.arange(nO) % 5) + 1                  # identical to mpc_arx_ol_recon

    FE = {"uni": Feats(y, u, X, False), "wb": Feats(y, u, X, True)}
    FC = {m: np.full((nO, N + 1, HMAX), np.nan) for m in FE}       # origins rel -1..N-1, leads 1..HMAX
    lam_sel, wmap = {m: [] for m in FE}, []
    for f in range(1, 6):
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        ok = (spont | win_mask(onOL[tr], -pre, N + POST)) & ~win_mask(onOL[te], -pre - PY, N + POST + HMAX) & valid
        bad = np.flatnonzero(~ok)
        for m, fe in FE.items():
            # origin t usable iff frames t-maxlag+1 .. t+HMAX are all usable
            cs = np.concatenate([[0], np.cumsum(~ok)])
            t_all = np.arange(fe.maxlag, T - HMAX - 1)
            good = (cs[t_all + HMAX + 1] - cs[t_all - fe.maxlag + 1]) == 0
            rows = t_all[good]
            cut = rows[int((1 - VAL_FRAC) * rows.size)]
            r_tr, r_va = rows[rows < cut - HMAX], rows[rows >= cut]
            Ytr = y[r_tr[:, None] + leads]; Yva = y[r_va[:, None] + leads]
            G1, B1 = accumulate(fe, r_tr, Ytr)
            va_s = r_va[::3]; Ava = fe(va_s); Yv = y[va_s[:, None] + leads[:35]]
            errs = []
            for lam in LAMS:
                Wl = solve_all(fe, G1, B1[:, :35], lam, leads[:35])
                errs.append(np.mean((Ava @ Wl - Yv) ** 2))
            lam = LAMS[int(np.argmin(errs))]
            G2, B2 = accumulate(fe, r_va, Yva)
            W = solve_all(fe, G1 + G2, B1 + B2, lam, leads)
            lam_sel[m].append(lam)
            print(f"[WB] fold {f} {m:3s} rows {rows.size} lambda {lam:g} val MSE(1-35) {min(errs):.3f}", flush=True)
            for k in te:
                FC[m][k] = fe(onOL[k] - 1 + np.arange(N + 1)) @ W   # origin rel -1 .. N-1
            if m == "wb":                                          # spot importance at 86 ms (lead 3)
                ws = W[fe.n_base:fe.n_base + fe.nS * L_SP, 2].reshape(L_SP, fe.nS)
                wmap.append(np.sqrt((ws ** 2).sum(0)))

    REC = np.stack([y[o:o + HMAX] for o in onOL]); PRE = np.stack([y[o - pre:o] for o in onOL])
    w03 = slice(0, N)
    free = {m: FC[m][:, 0, :] for m in FE}                         # from rel -1, leads 1..141 = rel 0..140
    rm = {m: np.sqrt(np.mean((free[m][:, w03] - REC[:, w03]) ** 2, 1)) for m in FE}
    r2 = {m: 1 - np.sum((free[m][:, w03].mean(0) - REC[:, w03].mean(0)) ** 2)
             / np.sum((REC[:, w03].mean(0) - REC[:, w03].mean(0).mean()) ** 2) for m in FE}
    kerr = {}
    for m in FE:
        e = []
        for L in LEADS:
            t0 = np.arange(N - L + 1)
            tgt = REC[:, t0 + L - 1]
            e.append(np.sqrt(np.mean((tgt - FC[m][:, t0, L - 1]) ** 2)))
        kerr[m] = np.array(e)
    kp = np.array([np.sqrt(np.mean((REC[:, np.arange(N - L + 1) + L - 1]
                    - np.stack([y[o + np.arange(N - L + 1) - 1] for o in onOL])) ** 2)) for L in LEADS])
    O = loadmat(DATA / f"mpc_arx_ol_recon_{sess}.mat", squeeze_me=True)
    k_it = O["kerr"]["ARX"].item() if hasattr(O["kerr"], "dtype") and O["kerr"].dtype.names else None
    lead_ms = LEADS * 1000 / Fs
    print(f"[WB] free-run 0-3 s median RMSE: uni {np.median(rm['uni']):.2f}, wb {np.median(rm['wb']):.2f} "
          f"| trial-avg R2 uni {r2['uni']:.3f} wb {r2['wb']:.3f}")
    print(f"[WB] k-step RMSE @ {np.round(lead_ms).astype(int)} ms")
    for m in FE:
        print(f"       {m:4s} {np.round(kerr[m], 2)}")
    if k_it is not None:
        print(f"       iterARX {np.round(k_it, 2)}")
    print(f"       persist {np.round(kp, 2)}")
    print(f"[WB] wb/uni RMSE ratio by lead: {np.round(kerr['wb'] / kerr['uni'], 3)}")

    # ---- figures ---------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    col = {"uni": "#5b2c86", "wb": "#d1495b", "it": "#2a9d8f", "p": "0.45"}
    fig, ax = plt.subplots(1, 3, figsize=(15, 4.2), constrained_layout=True)
    a = ax[0]
    a.imshow(Wb["mimg"], cmap="gray"); a.contour(Wb["mask"], [0.5], colors="w", linewidths=0.6)
    rc, wm = Wb["rc"], np.mean(wmap, 0)
    sc = a.scatter(rc[:, 1] - 1, rc[:, 0] - 1, c=wm, s=30, cmap="magma", edgecolors="w", linewidths=0.4)
    a.plot(Wb["site_rc"][1] - 1, Wb["site_rc"][0] - 1, "c+", ms=12, mew=2)
    a.set_title("100 spots: weight norm for the 86 ms forecast\n(+ = laser site)", fontsize=9); a.axis("off")
    plt.colorbar(sc, ax=a, fraction=0.04)
    a = ax[1]
    a.plot(lead_ms, kerr["uni"], "-o", color=col["uni"], ms=3, label="ROI only (direct)")
    a.plot(lead_ms, kerr["wb"], "-o", color=col["wb"], ms=3, label="ROI + 100 brain spots (direct)")
    if k_it is not None:
        a.plot(lead_ms, k_it, "--", color=col["it"], label="ROI only (iterated ARX, earlier)")
    a.plot(lead_ms, kp, ":", color=col["p"], label="persistence")
    a.axvline(57, color="0.7", lw=0.6, ls=":"); a.set_xscale("log")
    a.set_xlabel("forecast lead (ms)"); a.set_ylabel("RMSE (%dF/F)")
    a.set_title("held-out OL trials, k-step with known stim (origins 0-3 s)", fontsize=9); a.legend(fontsize=7, frameon=False)
    a = ax[2]
    tt, ts = np.arange(-pre, HMAX) / Fs, np.arange(HMAX) / Fs
    a.plot(tt, np.concatenate([PRE.mean(0), REC.mean(0)]), "k", lw=1.6, label="recorded")
    a.plot(ts, free["uni"].mean(0), color=col["uni"], label=f"ROI only (R² {r2['uni']:.2f})")
    a.plot(ts, free["wb"].mean(0), color=col["wb"], label=f"+ brain (R² {r2['wb']:.2f})")
    a.set_xlabel("time from onset (s)"); a.set_ylabel("dF/F (%)"); a.legend(fontsize=7, frameon=False)
    a.set_title("forecast from -1 frame, known stim: trial average", fontsize=9)
    fig.savefig(FIG / f"wb_arx_{sess}.png", dpi=200)

    ex = np.argsort(rm["wb"])[[nO // 4, nO // 2, 3 * nO // 4]]
    fig2, ax2 = plt.subplots(1, 3, figsize=(15, 3.6), constrained_layout=True)
    t86 = np.arange(N) / Fs + 2 / Fs                                # target time of the lead-3 forecast
    for i, k in enumerate(ex):
        a = ax2[i]
        a.plot(tt, np.concatenate([PRE[k], REC[k]]), "k", lw=1.1, label="recorded")
        a.plot(t86, FC["uni"][k, :N, 2], color=col["uni"], lw=1, label="86 ms ahead, ROI only")
        a.plot(t86, FC["wb"][k, :N, 2], color=col["wb"], lw=1, label="86 ms ahead, + brain")
        a.axvline(0, color="0.7", lw=0.6); a.axvline(3, color="0.7", lw=0.6)
        a.set_title(f"held-out OL trial {k + 1}", fontsize=9); a.set_xlabel("time from onset (s)")
        if i == 0:
            a.set_ylabel("dF/F (%)"); a.legend(fontsize=7, frameon=False)
    fig2.savefig(FIG / f"wb_arx_examples_{sess}.png", dpi=200)

    savemat(DATA / f"mpc_arx_wholebrain_{sess}.mat", {
        "kerr_uni": kerr["uni"], "kerr_wb": kerr["wb"], "kerr_persist": kp, "lead_ms": lead_ms,
        "rmse_free_uni": rm["uni"], "rmse_free_wb": rm["wb"], "r2_uni": r2["uni"], "r2_wb": r2["wb"],
        "lambda_uni": lam_sel["uni"], "lambda_wb": lam_sel["wb"], "spot_weight86": np.mean(wmap, 0),
        "r_spot_roi": r_sp, "fold": fold, "L_spot": L_SP}, do_compression=True)
    print(f"[WB] -> {FIG / f'wb_arx_{sess}.png'}")


if __name__ == "__main__":
    main(*sys.argv[1:])
