"""Tune the whole-brain direct ARX for the 86 ms (3-frame) forecast, and measure the forecast LAG.

Each plotted point of an h-step direct forecast is an independent prediction: at origin t the model sees
only recorded data up to t (+ the stim scheduled to t+h) and predicts y[t+h]; the next point re-reads the
data at t+1. Nothing is iterated or corrected. A forecast that is mostly persistence looks like the
recording shifted right by h; we quantify that as the lag maximising corr(yhat(t), y(t - lag)) on the
held-out OL trials (0 = on time, h = pure persistence).

Tuning (no test data): fold-1 training frames (same folds/exclusions as mpc_arx_wholebrain), the
chronologically last 20 % as validation; grid over y lags PY, spot lags LSP, past-stim lags QU, ridge
lambda; criterion = validation R2 at lead 3. Then the best and the default configs are scored on the full
5-fold held-out OL test (R2 + lag), leads 3 (86 ms) and 7 (200 ms).

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_wb_tune.py [sess] [spot-file tag]
OUT     data/mpc_arx_wb_tune_<sess>.mat, paper/images/mpc_arx/wb_tune_<sess>.png
"""
import itertools
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat

HERE = Path(__file__).resolve().parent
DATA, FIG = HERE / "data", HERE.parent / "paper" / "images" / "mpc_arx"
POST, VAL_FRAC, HPAD = 70, 0.2, 141
GRID_PY, GRID_LSP, GRID_QU = [3, 10, 35, 70], [1, 3, 5, 10, 20], [10, 35]
LAMS = 10.0 ** np.arange(-3, 4)
DEFAULT = dict(PY=70, LSP=10, QU=35)


def design(y, u, X, t, h, PY, LSP, QU):
    cols = [y[t[:, None] - np.arange(PY)], u[t[:, None] - np.arange(QU)], u[t[:, None] + 1 + np.arange(h)]]
    if LSP:
        cols.append(X[t[:, None] - np.arange(LSP)].reshape(t.size, -1))
    cols.append(np.ones((t.size, 1)))
    return np.hstack(cols)


def gram(y, u, X, rows, h, cfg, chunk=6000):
    G = B = None
    for i in range(0, rows.size, chunk):
        r = rows[i:i + chunk]
        A = design(y, u, X, r, h, **cfg)
        G = A.T @ A if G is None else G + A.T @ A
        B = A.T @ y[r + h] if B is None else B + A.T @ y[r + h]
    return G, B


def ridge(G, B, lam):
    pen = np.full(G.shape[0], lam); pen[-1] = 0
    return np.linalg.solve(G + np.diag(pen), B)


def r2(a, b):
    return 1 - np.sum((a - b) ** 2) / np.sum((a - a.mean()) ** 2)


def lag_of(F, Y, maxlag=8):
    """Lag (frames) maximising pooled corr(F[:, t], Y[:, t - lag]) over trials; F, Y aligned at target."""
    out = []
    for L in range(0, maxlag + 1):
        f, yy = F[:, L:], Y[:, :Y.shape[1] - L]
        out.append(np.corrcoef(f.ravel(), yy.ravel())[0, 1])
    return int(np.argmax(out)), np.array(out)


def main(sess="AL_0033_0226_e2", tag="100"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    W = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n{tag}.mat", squeeze_me=True)
    y, u, X = A["y"].astype(float), A["u"].astype(float), W["X"].astype(float)
    valid = A["valid"].astype(bool)
    # scale blocks on valid frames (as mpc_arx_wholebrain); keep y's scale to report in %dF/F
    sy = y[valid].std(); ys, us, Xs = y / sy, u / u[valid].std(), X / X[valid].std(0)
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = y.size, onOL.size
    rng = np.random.default_rng(7); fold = rng.permutation(np.arange(nO) % 5) + 1

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    spont = ~(win(onOL, -pre, N + POST) | win(onCL, -pre, N + POST))

    def usable_rows(ok, maxlag):
        cs = np.concatenate([[0], np.cumsum(~ok)])
        t = np.arange(maxlag, T - HPAD - 1)
        return t[(cs[t + HPAD + 1] - cs[t - maxlag + 1]) == 0]

    # ---- 1. tune on fold-1 training data only (validation = last 20 % of its rows) ----------------
    te1, tr1 = np.flatnonzero(fold == 1), np.flatnonzero(fold != 1)
    ok1 = (spont | win(onOL[tr1], -pre, N + POST)) & ~win(onOL[te1], -pre - 70, N + POST + HPAD) & valid
    rows = usable_rows(ok1, 70)
    cut = rows[int((1 - VAL_FRAC) * rows.size)]
    r_tr, r_va = rows[rows < cut - HPAD], rows[rows >= cut][::2]
    h = 3
    res = []
    for PY, LSP, QU in itertools.product(GRID_PY, GRID_LSP + [0], GRID_QU):
        cfg = dict(PY=PY, LSP=LSP, QU=QU)
        G, B = gram(ys, us, Xs, r_tr, h, cfg)
        Av = design(ys, us, Xs, r_va, h, **cfg); yv = ys[r_va + h]
        sc = [(r2(yv, Av @ ridge(G, B, lam)), lam) for lam in LAMS]
        best = max(sc)
        res.append((best[0], PY, LSP, QU, best[1]))
        print(f"[TUNE] PY={PY:2d} LSP={LSP:2d} QU={QU:2d} -> val R2(86 ms) {best[0]:.4f} (lambda {best[1]:g})", flush=True)
    res.sort(reverse=True)
    bR, bPY, bLSP, bQU, bLam = res[0]
    print(f"[TUNE] BEST PY={bPY} LSP={bLSP} QU={bQU} lambda={bLam:g} val R2 {bR:.4f}")
    dflt = [r for r in res if (r[1], r[2], r[3]) == (DEFAULT["PY"], DEFAULT["LSP"], DEFAULT["QU"])][0]
    print(f"[TUNE] default PY=70 LSP=10 QU=35 val R2 {dflt[0]:.4f}")

    # ---- 2. 5-fold held-out OL test for best vs default vs ROI-only(best PY) + lag ---------------
    cfgs = {"default (PY70,L10)": (dict(PY=70, LSP=10, QU=35), dflt[4]),
            f"tuned (PY{bPY},L{bLSP},Q{bQU})": (dict(PY=bPY, LSP=bLSP, QU=bQU), bLam)}
    roi = max([r for r in res if r[2] == 0])
    cfgs[f"ROI only (PY{roi[1]},Q{roi[3]})"] = (dict(PY=roi[1], LSP=0, QU=roi[3]), roi[4])
    out = {}
    for hh in (3, 7):
        for name, (cfg, lam) in cfgs.items():
            Fh = np.full((nO, N), np.nan)
            for f in range(1, 6):
                te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
                ok = (spont | win(onOL[tr], -pre, N + POST)) & ~win(onOL[te], -pre - 70, N + POST + HPAD) & valid
                G, B = gram(ys, us, Xs, usable_rows(ok, 70), hh, cfg)
                w = ridge(G, B, lam)
                for k in te:                                       # origins rel -1..N-2 -> targets rel hh-1..
                    Fh[k] = design(ys, us, Xs, onOL[k] - 1 + np.arange(N), hh, **cfg) @ w * sy
            Y = np.stack([y[o - 1 + hh + np.arange(N)] for o in onOL])  # targets, rel hh-1 .. N+hh-2
            Fp = np.stack([y[o - 1 + np.arange(N)] for o in onOL])      # persistence
            lg, cc = lag_of(Fh, Y)
            out[(hh, name)] = dict(R2=r2(Y, Fh), lag=lg, cc=cc, F=Fh, Y=Y)
            out[(hh, "persistence")] = dict(R2=r2(Y, Fp), lag=lag_of(Fp, Y)[0], cc=lag_of(Fp, Y)[1], F=Fp, Y=Y)
            print(f"[TEST] lead {hh} ({hh*1000/Fs:.0f} ms) {name:24s} R2 {out[(hh, name)]['R2']:.3f} | lag {lg} frames "
                  f"({lg*1000/Fs:.0f} ms)", flush=True)
        p = out[(hh, "persistence")]
        print(f"[TEST] lead {hh} persistence              R2 {p['R2']:.3f} | lag {p['lag']} frames")

    # ---- figure: lag profile + example trial ------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(1, 3, figsize=(16, 4), constrained_layout=True)
    names = list(cfgs) + ["persistence"]
    cols = ["#d1495b", "#2a9d8f", "#5b2c86", "0.5"]
    for j, hh in enumerate((3, 7)):
        a = ax[j]
        for c, nm in zip(cols, names):
            o = out[(hh, nm)]
            a.plot(np.arange(o["cc"].size) * 1000 / Fs, o["cc"], "-o", ms=3, color=c,
                   label=f"{nm}: R² {o['R2']:.3f}, lag {o['lag']*1000/Fs:.0f} ms")
        a.axvline(hh * 1000 / Fs, color="0.7", ls=":", lw=0.8)
        a.set_xlabel("shift of the recording (ms)"); a.set_ylabel("corr(forecast, recording shifted)")
        a.set_title(f"{hh*1000/Fs:.0f} ms-ahead forecast: where does it line up? (dotted = pure persistence)", fontsize=9)
        a.legend(fontsize=7, frameon=False)
    a = ax[2]
    nm_t = f"tuned (PY{bPY},L{bLSP},Q{bQU})"
    o = out[(3, nm_t)]; k = int(np.argsort([r2(o["Y"][i], o["F"][i]) for i in range(nO)])[nO // 2])
    tt = (np.arange(N) + 2) / Fs
    a.plot(tt, o["Y"][k], "k", lw=1.2, label="recorded")
    a.plot(tt, o["F"][k], color=cols[1], lw=1, label=f"86 ms ahead, {nm_t}")
    a.plot(tt, out[(3, "persistence")]["F"][k], color="0.6", lw=0.8, ls="--", label="persistence (recording shifted 86 ms)")
    a.set_xlabel("time from onset (s)"); a.set_ylabel("dF/F (%)"); a.legend(fontsize=7, frameon=False)
    a.set_title(f"median held-out OL trial ({k + 1})", fontsize=9)
    fig.savefig(FIG / f"wb_tune_{sess}.png", dpi=200)
    savemat(DATA / f"mpc_arx_wb_tune_{sess}.mat", {
        "grid": np.array([r[:4] + (r[4],) for r in res]), "best": [bPY, bLSP, bQU, bLam],
        "test": {f"L{hh}_{i}": np.array([out[(hh, nm)]["R2"], out[(hh, nm)]["lag"]])
                 for hh in (3, 7) for i, nm in enumerate(names)}, "names": np.array(names, dtype=object)})
    print(f"[TUNE] -> {FIG / f'wb_tune_{sess}.png'}")


if __name__ == "__main__":
    main(*sys.argv[1:])
