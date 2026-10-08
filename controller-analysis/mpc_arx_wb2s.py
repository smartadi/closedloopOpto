"""Whole-brain direct ARX with a 2-s history on EVERY input (user 2026-10-07), two uses:

  ol  Held-out OL trial responses. Target = the online dF/F y. Inputs at origin t: y[t..t-69],
      laser u[t..t-69], all 100 brain spots X[t..t-69] (7000 cols), and the laser SCHEDULED for
      t+1..t+h (known in OL). One ridge regression per lead h = 1..141. 5 folds over the 92 OL trials,
      training = spont + training-fold OL (as mpc_arx_wholebrain).
  cl  Disturbance forecaster for the MPC replay. Target = d = y - plant(u) (what ctrl_mpc_lqr
      previews). Inputs d[t..t-69], u[t..t-69], X[t..t-69]; no future laser (in the replay the future
      command is the MPC's own decision). Leads 1..35. Folds = the 5 CL-trial folds of
      ctrl_mpc_forecasters (paired comparison); training = spont + all OL + training-fold CL, every
      test-CL window (-1 s .. +3 s + horizon, padded by the 2-s history) excluded. Also a ROI-only
      variant (d + u lags only) for a like-for-like check. Output in ctrl_mpc_lqr's format:
      F.<model>(t, j, k) = d_hat(origin t, lead j) - Dmean (departure, DEP).

Solving: 7141 features. The big block (everything except the scheduled laser) is Cholesky-factored once
per lambda; the scheduled-laser block (<= h columns, OL only) enters per lead by a Schur complement, so the
per-lead causal mask costs a 141x141 solve, not a 7141x7141 one. Lambda: one per fold, by validation R^2
(mean over leads 1,2,3,5,7) on the chronologically last 20 % of the training rows.

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_wb2s.py [ol|cl|both] [sess]
OUT     ol: data/mpc_arx_wb2s_ol_<sess>.mat, paper/images/mpc_arx/wb2s_ol_*.png
        cl: data/ctrl_mpc_wb2s_out_<sess>.mat (F.wb2s, F.roi2s, fold) -> ctrl_mpc_lqr fcstFile
"""
import sys
import time
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat
from scipy.linalg import cho_factor, cho_solve, solve_triangular

HERE = Path(__file__).resolve().parent
DATA, FIG = HERE / "data", HERE.parent / "paper" / "images" / "mpc_arx"
HIST = 70                                    # 2 s at 35 Hz, every input
POST, VAL_FRAC = 70, 0.2
LAMS = 10.0 ** np.arange(0, 5)
VAL_LEADS = np.array([1, 2, 3, 5, 7])


class Design:
    """[sig lags | u lags | spot lags | (scheduled u 1..nf) | 1]; 'b' = all but the scheduled-u block."""
    def __init__(self, sig, u, X, nf, use_spots=True, hs=HIST, hu=HIST, hx=HIST):
        self.s, self.u, self.X, self.nf, self.sp = sig, u, X, nf, use_spots
        self.hs, self.hu, self.hx = hs, hu, hx                 # history (frames) per input block
        self.nb = hs + hu + (X.shape[1] * hx if use_spots else 0) + 1
        self.F = self.nb + nf

    def __call__(self, t):
        cols = [self.s[t[:, None] - np.arange(self.hs)], self.u[t[:, None] - np.arange(self.hu)]]
        if self.sp:
            cols.append(self.X[t[:, None] - np.arange(self.hx)].reshape(t.size, -1))
        cols.append(np.ones((t.size, 1)))
        if self.nf:
            cols.append(self.u[t[:, None] + 1 + np.arange(self.nf)])
        return np.hstack(cols)


def gram(D, rows, Y, chunk=1500):
    G = np.zeros((D.F, D.F)); B = np.zeros((D.F, Y.shape[1]))
    for i in range(0, rows.size, chunk):
        A = D(rows[i:i + chunk]); G += A.T @ A; B += A.T @ Y[i:i + chunk]
    return G, B


def solve_leads(D, G, B, lam, leads):
    """Ridge weights for every lead; lead h may use only the first h scheduled-u columns (Schur)."""
    nb, nf = D.nb, D.nf
    Gbb = G[:nb, :nb].copy(); Gbb[np.diag_indices(nb)] += lam; Gbb[nb - 1, nb - 1] -= lam  # intercept free
    c = cho_factor(Gbb, lower=True)
    Wb = np.zeros((D.F, leads.size))
    if nf == 0:
        Wb[:nb] = cho_solve(c, B[:nb])
        return Wb
    Lc = np.tril(c[0])
    Z = solve_triangular(Lc, G[:nb, nb:], lower=True)          # L^-1 Gbf
    Zb = solve_triangular(Lc, B[:nb], lower=True)              # L^-1 Bb (all leads)
    for j, h in enumerate(leads):
        h = min(h, nf); Zh = Z[:, :h]
        S = G[nb:nb + h, nb:nb + h] + lam * np.eye(h) - Zh.T @ Zh
        wf = np.linalg.solve(S, B[nb:nb + h, j] - Zh.T @ Zb[:, j])
        Wb[:nb, j] = solve_triangular(Lc.T, Zb[:, j] - Zh @ wf, lower=False)
        Wb[nb:nb + h, j] = wf
    return Wb


def r2(a, b):
    return 1 - np.sum((a - b) ** 2) / np.sum((a - a.mean()) ** 2)


def load(sess):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    W = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)
    return A, W


def fit_fold(D, target, rows, leads, tag):
    """Lambda by inner validation (last 20 % of rows), then refit on all rows. Returns weights (F x leads)."""
    cut = rows[int((1 - VAL_FRAC) * rows.size)]
    hmax = leads.max()
    r_tr, r_va = rows[rows < cut - hmax], rows[rows >= cut]
    t0 = time.time()
    G1, B1 = gram(D, r_tr, target[r_tr[:, None] + leads])
    G2, B2 = gram(D, r_va, target[r_va[:, None] + leads])
    vi = np.searchsorted(leads, VAL_LEADS)
    Av = D(r_va[::3]); Yv = target[r_va[::3][:, None] + leads[vi]]
    sc = []
    for lam in LAMS:
        Wl = solve_leads(D, G1, B1[:, vi], lam, leads[vi])
        sc.append(np.mean([r2(Yv[:, j], Av @ Wl[:, j]) for j in range(vi.size)]))
    lam = LAMS[int(np.argmax(sc))]
    W = solve_leads(D, G1 + G2, B1 + B2, lam, leads)
    print(f"[2S] {tag}: {rows.size} rows, {D.F} feats, lambda {lam:g} (val R2 {max(sc):.4f}), {time.time()-t0:.0f} s",
          flush=True)
    return W, lam


# =====================================================================================================
def run_ol(sess):
    A, Wf = load(sess)
    valid = A["valid"].astype(bool)
    yr, ur, X = A["y"].astype(float), A["u"].astype(float), Wf["X"].astype(float)
    sy = yr[valid].std(); y, u = yr / sy, ur / ur[valid].std(); Xs = X / X[valid].std(0)
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO, HMAX = y.size, onOL.size, 141
    leads = np.arange(1, HMAX + 1)
    rng = np.random.default_rng(7); fold = rng.permutation(np.arange(nO) % 5) + 1   # = mpc_arx_ol_recon

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    spont = ~(win(onOL, -pre, N + POST) | win(onCL, -pre, N + POST))
    FC = np.full((nO, N + 1, HMAX), np.nan); TM = np.full((nO, HMAX), np.nan)
    D = Design(y, u, Xs, HMAX)
    for f in range(1, 6):
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        TM[te] = np.mean([yr[o:o + HMAX] for o in onOL[tr]], axis=0)
        ok = (spont | win(onOL[tr], -pre, N + POST)) & ~win(onOL[te], -pre - HIST, N + POST + HMAX) & valid
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(HIST, T - HMAX - 1)
        rows = t[(cs[t + HMAX + 1] - cs[t - HIST + 1]) == 0]
        W, _ = fit_fold(D, y, rows, leads, f"OL fold {f}")
        for k in te:
            FC[k] = D(onOL[k] - 1 + np.arange(N + 1)) @ W * sy        # origins rel -1 .. N-1
    REC = np.stack([yr[o:o + HMAX] for o in onOL]); PRE = np.stack([yr[o - pre:o] for o in onOL])
    LEADS = np.array([1, 2, 3, 4, 5, 7, 10, 17, 35]); lead_ms = LEADS * 1000 / Fs
    k2 = np.array([r2(REC[:, np.arange(N - L + 1) + L - 1], FC[:, np.arange(N - L + 1), L - 1]) for L in LEADS])
    per = np.array([r2(REC[:, np.arange(N - L + 1) + L - 1], np.stack([yr[o + np.arange(N - L + 1) - 1] for o in onOL]))
                    for L in LEADS])
    free = FC[:, 0, :]; w03 = slice(0, N)
    fr1, fra = r2(REC[:, w03], free[:, w03]), r2(REC[:, w03].mean(0), free[:, w03].mean(0))
    P = loadmat(DATA / f"mpc_arx_wholebrain_{sess}.mat", squeeze_me=True)
    prev = {n: P["R2"][n].item() for n in P["R2"].dtype.names}
    plm = P["lead_ms"]
    print(f"[2S-OL] k-step R2 @ {np.round(lead_ms).astype(int)} ms: {np.round(k2, 3)}")
    print(f"[2S-OL] persistence                       {np.round(per, 3)}")
    print(f"[2S-OL] previous (spots 286 ms hist, 100) @ {np.round(plm).astype(int)}: {np.round(prev['wb_100_spots'], 3)}")
    print(f"[2S-OL] whole-trial forecast from -1 frame: single-trial R2 {fr1:.3f}, trial-avg R2 {fra:.3f}")

    FIG.mkdir(parents=True, exist_ok=True)
    tt, ts = np.arange(-pre, HMAX) / Fs, np.arange(HMAX) / Fs
    fig, ax = plt.subplots(1, 2, figsize=(13, 4.2), constrained_layout=True)
    a = ax[0]
    a.plot(lead_ms, k2, "-o", ms=3, color="#d1495b", label="2-s history, 100 spots")
    a.plot(plm, prev["wb_100_spots"], "-o", ms=3, color="#e9c46a", label="previous: spots 286 ms history")
    a.plot(plm, prev["ROI_only"], "-o", ms=3, color="#5b2c86", label="previous: ROI only")
    a.plot(lead_ms, per, ":", color="0.45", label="persistence")
    a.set_xscale("log"); a.set_xlabel("forecast lead (ms)"); a.set_ylabel("held-out OL R²")
    a.axvline(86, color="0.75", lw=0.6, ls=":"); a.legend(fontsize=7, frameon=False)
    a.set_title("k-step forecast, known stim, targets 0-3 s", fontsize=9)
    a = ax[1]
    a.plot(tt, np.concatenate([PRE.mean(0), REC.mean(0)]), "k", lw=1.6, label="recorded")
    a.plot(ts, free.mean(0), color="#d1495b", label=f"forecast from -1 frame (avg R² {fra:.2f}, single-trial {fr1:.2f})")
    a.plot(ts, TM.mean(0), "--", color="0.6", lw=1, label="training-fold OL average")
    a.set_xlabel("time from onset (s)"); a.set_ylabel("dF/F (%)"); a.legend(fontsize=7, frameon=False)
    a.set_title("trial average, held-out OL", fontsize=9)
    fig.savefig(FIG / f"wb2s_ol_{sess}.png", dpi=200)

    yy = REC[:, 2:N + 2]; f86 = FC[:, :N, 2]
    r2t = np.array([r2(yy[k], f86[k]) for k in range(nO)])
    ex = np.argsort(r2t)[np.round(np.linspace(0.1, 0.9, 6) * (nO - 1)).astype(int)]
    fig2, ax2 = plt.subplots(2, 3, figsize=(15, 6.4), constrained_layout=True, sharex=True)
    t86 = (np.arange(N) + 2) / Fs
    for i, k in enumerate(ex):
        a = ax2.flat[i]; a.axvspan(0, 3, color="0.93", zorder=0)
        a.plot(tt, np.concatenate([PRE[k], REC[k]]), "k", lw=1.2, label="recorded")
        a.plot(t86, f86[k], color="#d1495b", lw=1, label="86 ms ahead (2-s history, 100 spots)")
        a.plot(ts, free[k], color="#2a9d8f", lw=1, ls="--", label="whole-trial forecast from -1 frame")
        a.set_title(f"held-out OL trial {k + 1} (fold {fold[k]}) | R² 86 ms {r2t[k]:.2f}", fontsize=8.5)
        if i % 3 == 0: a.set_ylabel("dF/F (%)")
        if i >= 3: a.set_xlabel("time from onset (s)")
        if i == 0: a.legend(fontsize=7, frameon=False, loc="lower left")
    fig2.suptitle(f"held-out OL trials, 2-s history on every input (pooled R² at 86 ms {k2[2]:.2f})", fontsize=10)
    fig2.savefig(FIG / f"wb2s_ol_examples_{sess}.png", dpi=200)
    savemat(DATA / f"mpc_arx_wb2s_ol_{sess}.mat", {"R2": k2, "R2_persist": per, "lead_ms": lead_ms,
            "R2_free_single": fr1, "R2_free_avg": fra, "F86": f86, "fold": fold}, do_compression=True)


# =====================================================================================================
def run_cl(sess):
    A, Wf = load(sess)
    valid = A["valid"].astype(bool)
    dr, ur, X = A["d"].astype(float), A["u"].astype(float), Wf["X"].astype(float)
    sd = dr[valid].std(); d, u = dr / sd, ur / ur[valid].std(); Xs = X / X[valid].std(0)
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    fold = A["fold"].astype(int); Dmean = A["Dmean"].astype(float)
    pre, N, Hp, Fs = int(A["pre"]), int(A["N"]), int(A["Hp"]), float(A["Fs"])
    T, nT = d.size, onCL.size
    leads = np.arange(1, Hp + 1)

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    # wbbest = the tuned config of mpc_arx_wb_tune (own/laser 35 frames, spots 10 frames = 286 ms)
    Ds = {"wb2s": Design(d, u, Xs, 0, True), "roi2s": Design(d, u, Xs, 0, False),
          "wbbest": Design(d, u, Xs, 0, True, hs=35, hu=35, hx=10)}
    Fout = {m: np.full((N, Hp, nT), np.nan) for m in Ds}
    rel_idx = pre + np.arange(1, N + 1)[:, None] + np.arange(Hp)[None, :]
    for f in np.unique(fold):
        te = np.flatnonzero(fold == f)
        ok = valid & ~win(onCL[te], -pre - HIST, N + Hp + HIST)
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(HIST, T - Hp - 1)
        rows = t[(cs[t + Hp + 1] - cs[t - HIST + 1]) == 0]
        for m, D in Ds.items():
            W, _ = fit_fold(D, d, rows, leads, f"CL fold {f} {m}")
            for k in te:
                fc = D(onCL[k] + np.arange(N)) @ W * sd              # origin t=1..N: last obs rel t-1 (frame on+t-1)
                Fout[m][:, :, k] = fc - Dmean[np.minimum(rel_idx, Dmean.size - 1)]
    savemat(DATA / f"ctrl_mpc_wb2s_out_{sess}.mat", {"F": Fout, "fold": fold.astype(float),
            "source": "mpc_arx_wb2s.py cl: direct ridge, 2-s history of d, laser, 100 brain spots"},
            do_compression=True)
    print(f"[2S-CL] -> {DATA / f'ctrl_mpc_wb2s_out_{sess}.mat'}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "both"
    sess = sys.argv[2] if len(sys.argv) > 2 else "AL_0033_0226_e2"
    if mode in ("ol", "both"):
        run_ol(sess)
    if mode in ("cl", "both"):
        run_cl(sess)
