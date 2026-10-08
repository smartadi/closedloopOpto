"""Delay-embedded vector AR with laser input (VARX) predicting the controlled spot from 100 brain spots.

State z(t) = [y(t), x_1(t) .. x_100(t)]  (controlled ROI online dF/F + 100 evenly spaced brain spots).
One-step model, time-delay embedding of L frames for every channel and Q frames of laser command:
    z(t+1) = W' [ z(t), z(t-1), .., z(t-L+1),  u(t+1), u(t), .., u(t-Q+2),  1 ]
(u(t+1) is the command being applied over the next frame -- known in OL (scheduled), and the MPC's own
decision in closed loop). Fitted by ridge (all 101 outputs share one Gram matrix). Forecasts are ITERATED:
the model predicts every channel one frame ahead, feeds its own prediction back into the embedding, and
reads y off the predicted state -- so it is a single dynamical model of brain + laser, usable directly as
the MPC's prediction model (no separate plant / disturbance split).

Selection (no test data): L in {2,3,5,10}, lambda grid, by validation R^2 of y at lead 3 (86 ms), iterated,
on fold-1 training rows (chronologically last 20 %). Test: the 92 held-out OL trials, 5 folds, same folds
and exclusions as mpc_arx_ol_recon / mpc_arx_wholebrain; training = spont + training-fold OL.
Reported: k-step R^2 of y (origins 0-3 s), whole-trial forecast from -1 frame, forecast lag; compared
with the direct whole-brain ridge (mpc_arx_wb_tune2 base) and persistence.

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_varx_embed.py [sess]
OUT     data/mpc_varx_embed_<sess>.mat, paper/images/mpc_arx/varx_*.png
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
Q, POST, VAL_FRAC, HMAX, PAD = 35, 70, 0.2, 141, 70
L_GRID, LAMS = [2, 3, 5, 10], 10.0 ** np.arange(-1, 4)
LEADS = np.array([1, 2, 3, 4, 5, 7, 10, 17, 35])
DIRECT = {"lead_ms": [29, 57, 86, 114, 143], "R2": [0.952, 0.831, 0.689, 0.576, 0.512]}  # tune2 base, held-out OL


def phi(Z, u, t, L):
    """Embedding at origins t: [Z[t], .., Z[t-L+1] (lag-major), u[t+1], .., u[t-Q+2], 1]."""
    return np.hstack([Z[t[:, None] - np.arange(L)].reshape(t.size, -1),
                      u[t[:, None] + 1 - np.arange(Q)], np.ones((t.size, 1))])


def fit(Z, u, rows, L, lam, chunk=4000):
    F = Z.shape[1] * L + Q + 1
    G = np.zeros((F, F)); B = np.zeros((F, Z.shape[1]))
    for i in range(0, rows.size, chunk):
        r = rows[i:i + chunk]; A = phi(Z, u, r, L); G += A.T @ A; B += A.T @ Z[r + 1]
    return G, B


def solve(G, B, lam):
    p = np.full(G.shape[0], lam); p[-1] = 0
    return np.linalg.solve(G + np.diag(p), B)


def iterate(Z, u, org, W, L, H):
    """Iterated forecast of all channels from origins org (last observed frame); returns y forecasts."""
    nC = Z.shape[1]
    hist = Z[org[:, None] - np.arange(L)]                     # M x L x nC, lag 0 first
    out = np.empty((org.size, H))
    for h in range(H):
        A = np.hstack([hist.reshape(org.size, -1), u[org[:, None] + h + 1 - np.arange(Q)], np.ones((org.size, 1))])
        nxt = A @ W                                            # M x nC  = z(t+h+1)
        out[:, h] = nxt[:, 0]
        hist = np.concatenate([nxt[:, None, :], hist[:, :-1, :]], axis=1)
    return out


def r2(a, b):
    return 1 - np.sum((a - b) ** 2) / np.sum((a - a.mean()) ** 2)


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    Wb = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    yr, ur, X = A["y"].astype(float), A["u"].astype(float), Wb["X"].astype(float)
    sy = yr[valid].std()
    Z = np.column_stack([yr / sy, X / X[valid].std(0)]); u = ur / ur[valid].std()
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = yr.size, onOL.size
    rng = np.random.default_rng(7); fold = rng.permutation(np.arange(nO) % 5) + 1   # = earlier OL scripts

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    spont = ~(win(onOL, -pre, N + POST) | win(onCL, -pre, N + POST))

    def rows_for(f):
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        ok = (spont | win(onOL[tr], -pre, N + POST)) & ~win(onOL[te], -pre - PAD, N + POST + HMAX) & valid
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(PAD, T - HMAX - 1)
        return t[(cs[t + Q + 2] - cs[t - PAD + 1]) == 0], te       # history + next frame + u window usable

    # ---- selection on fold-1 training rows --------------------------------------------------------
    rows1, _ = rows_for(1)
    cut = rows1[int((1 - VAL_FRAC) * rows1.size)]
    r_tr, r_va = rows1[rows1 < cut - HMAX], rows1[rows1 >= cut]
    vo = r_va[::7]; vo = vo[vo + 8 < T]
    yv = Z[vo[:, None] + np.arange(1, 6), 0]
    best = (-np.inf,)
    for L in L_GRID:
        G, B = fit(Z, u, r_tr, L, 0)
        for lam in LAMS:
            Wl = solve(G, B, lam)
            fc = iterate(Z, u, vo, Wl, L, 5)
            s = r2(yv[:, 2], fc[:, 2])
            print(f"[VARX] L={L:2d} lambda={lam:g}: val R2(y) @ 29/57/86/114/143 ms "
                  f"{np.round([r2(yv[:, j], fc[:, j]) for j in range(5)], 3)}", flush=True)
            if s > best[0]:
                best = (s, L, lam)
    _, Lb, lamb = best
    print(f"[VARX] chosen L={Lb} ({Lb*1000/Fs:.0f} ms embedding), lambda={lamb:g}", flush=True)

    # ---- held-out OL test --------------------------------------------------------------------------
    FC = np.full((nO, N + 1, HMAX), np.nan); rho = []
    for f in range(1, 6):
        rows, te = rows_for(f)
        G, B = fit(Z, u, rows, Lb, lamb); Wf = solve(G, B, lamb)
        nC = Z.shape[1]                                          # stability of the AR part (companion)
        Ar = Wf[:nC * Lb].T                                       # nC x nC*L
        comp = np.zeros((nC * Lb, nC * Lb)); comp[:nC] = Ar; comp[nC:, :-nC] = np.eye(nC * (Lb - 1))
        rho.append(np.max(np.abs(np.linalg.eigvals(comp))))
        for k in te:
            FC[k] = iterate(Z, u, onOL[k] - 1 + np.arange(N + 1), Wf, Lb, HMAX) * sy
        print(f"[VARX] fold {f}: {rows.size} rows | spectral radius {rho[-1]:.4f}", flush=True)
    REC = np.stack([yr[o:o + HMAX] for o in onOL]); PRE = np.stack([yr[o - pre:o] for o in onOL])
    k2, per, lag = [], [], []
    for L in LEADS:
        t0 = np.arange(N - L + 1); tg = REC[:, t0 + L - 1]; fc = FC[:, t0, L - 1]
        k2.append(r2(tg, fc)); per.append(r2(tg, np.stack([yr[o + t0 - 1] for o in onOL])))
        cc = [np.corrcoef(fc[:, s:].ravel(), tg[:, :tg.shape[1] - s].ravel())[0, 1] for s in range(min(9, L + 4))]
        lag.append(int(np.argmax(cc)))
    k2, per = np.array(k2), np.array(per)
    free = FC[:, 0, :]; w03 = slice(0, N)
    fr1, fra = r2(REC[:, w03], free[:, w03]), r2(REC[:, w03].mean(0), free[:, w03].mean(0))
    lead_ms = LEADS * 1000 / Fs
    print(f"[VARX] held-out OL R2(y) @ {np.round(lead_ms).astype(int)} ms: {np.round(k2, 3)}")
    print(f"[VARX] lag (frames)                         {lag}")
    print(f"[VARX] direct whole-brain ridge             {DIRECT['R2']} (first five leads)")
    print(f"[VARX] persistence                          {np.round(per, 3)}")
    print(f"[VARX] whole-trial forecast from -1 frame: single-trial R2 {fr1:.3f}, trial-avg R2 {fra:.3f}")

    # ---- figures -----------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    tt, ts = np.arange(-pre, HMAX) / Fs, np.arange(HMAX) / Fs
    fig, ax = plt.subplots(1, 2, figsize=(13, 4.2), constrained_layout=True)
    a = ax[0]
    a.plot(lead_ms, k2, "-o", ms=3, color="#e76f51", label=f"VARX, delay embedding {Lb} frames (iterated)")
    a.plot(DIRECT["lead_ms"], DIRECT["R2"], "-o", ms=3, color="#2a9d8f", label="direct whole-brain ridge (per lead)")
    a.plot(lead_ms, per, ":", color="0.45", label="persistence")
    a.set_xscale("log"); a.axvline(86, color="0.75", lw=0.6, ls=":")
    a.set_xlabel("forecast lead (ms)"); a.set_ylabel("held-out OL R² (controlled spot)")
    a.legend(fontsize=7, frameon=False); a.set_title("k-step forecast, known laser schedule", fontsize=9)
    a = ax[1]
    a.plot(tt, np.concatenate([PRE.mean(0), REC.mean(0)]), "k", lw=1.6, label="recorded")
    a.plot(ts, free.mean(0), color="#e76f51", label=f"VARX from -1 frame (avg R² {fra:.2f}, single-trial {fr1:.2f})")
    a.set_xlabel("time from onset (s)"); a.set_ylabel("dF/F (%)"); a.legend(fontsize=7, frameon=False)
    a.set_title("held-out OL trial average", fontsize=9)
    fig.savefig(FIG / f"varx_{sess}.png", dpi=200)

    yy = REC[:, 2:N + 2]; f86 = FC[:, :N, 2]
    r2t = np.array([r2(yy[k], f86[k]) for k in range(nO)])
    ex = np.argsort(r2t)[np.round(np.linspace(0.1, 0.9, 6) * (nO - 1)).astype(int)]
    fig2, ax2 = plt.subplots(2, 3, figsize=(15, 6.4), constrained_layout=True, sharex=True)
    t86 = (np.arange(N) + 2) / Fs
    for i, k in enumerate(ex):
        a = ax2.flat[i]; a.axvspan(0, 3, color="0.93", zorder=0)
        a.plot(tt, np.concatenate([PRE[k], REC[k]]), "k", lw=1.2, label="recorded")
        a.plot(t86, f86[k], color="#e76f51", lw=1, label="86 ms ahead (VARX, iterated)")
        a.plot(ts, free[k], color="#264653", lw=1, ls="--", label="whole-trial forecast from -1 frame")
        a.set_title(f"held-out OL trial {k + 1} (fold {fold[k]}) | R² 86 ms {r2t[k]:.2f}", fontsize=8.5)
        if i % 3 == 0: a.set_ylabel("dF/F (%)")
        if i >= 3: a.set_xlabel("time from onset (s)")
        if i == 0: a.legend(fontsize=7, frameon=False, loc="lower left")
    fig2.suptitle(f"VARX with {Lb}-frame delay embedding of 100 spots + controlled spot + laser "
                  f"(pooled R² at 86 ms {k2[2]:.2f})", fontsize=10)
    fig2.savefig(FIG / f"varx_examples_{sess}.png", dpi=200)
    savemat(DATA / f"mpc_varx_embed_{sess}.mat", {"L": Lb, "lam": lamb, "R2": k2, "R2_persist": per, "lag": lag,
            "lead_ms": lead_ms, "R2_free_single": fr1, "R2_free_avg": fra, "spectral_radius": rho, "fold": fold},
            do_compression=True)


if __name__ == "__main__":
    main(*sys.argv[1:])
