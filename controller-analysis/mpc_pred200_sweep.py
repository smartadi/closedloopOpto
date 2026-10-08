"""Parameter sweep for the best 200 ms (7-frame) predictor of the controlled spot (user 2026-10-07).

Family: delay-embedded VARX (mpc_varx_embed.py) -- state z = [controlled spot, 100 brain spots] (or the spot
block compressed to k PCs), embedding of L frames, Q frames of laser, iterated with the known laser
schedule -- and, for comparison, a DIRECT ridge trained for lead 7 on the same embedding (+ the scheduled
laser up to t+7).
Selection: fold-1 TRAINING rows only (OL fold 1 held out entirely), validation = last 20 % chronological;
criterion = R^2 of y at 200 ms (lead 3 = 86 ms also reported). Coordinate-wise:
  stage 1  L x lambda
  stage 2  laser lags Q | stim-window weight | spot PCA k | causal 3-frame smoothing of the inputs
  stage 3  direct-for-lead-7 vs iterated
Test: the best configs + the current VARX (L10, lambda 100) on the 92 held-out OL trials (5 folds, same
folds/exclusions as before): R^2 at 86 / 200 ms and the forecast lag.

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_pred200_sweep.py [sess]
OUT     data/mpc_pred200_sweep_<sess>.mat, paper/images/mpc_arx/pred200_sweep_<sess>.png
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
POST, VAL_FRAC, HMAX, PAD, H7 = 70, 0.2, 141, 100, 7
BASE = dict(L=10, lam=100.0, Q=35, w=1, k=0, smooth=0, direct=False)


def r2(a, b):
    return 1 - np.sum((a - b) ** 2) / np.sum((a - a.mean()) ** 2)


class Model:
    """Delay-embedded VARX (iterated) or direct-for-lead-H7 ridge on [y | spots or spot PCs]."""
    def __init__(self, cfg, y, X, u, rows_pca):
        c = cfg; self.c = c
        S = X
        if c["k"]:
            Zs = X[rows_pca[::5]]; mu = Zs.mean(0)
            V = np.linalg.svd(Zs - mu, full_matrices=False)[2][:c["k"]].T
            S = (X - mu) @ V; S = S / S.std(0)
        Z = np.column_stack([y, S])
        if c["smooth"]:                                         # causal boxcar on the INPUT copy only
            k = c["smooth"]; cs = np.cumsum(np.vstack([np.zeros((1, Z.shape[1])), Z]), 0)
            Zi = Z.copy(); Zi[k - 1:] = (cs[k:] - cs[:-k]) / k
        else:
            Zi = Z
        self.Z, self.Zi, self.u, self.nC = Z, Zi, u, Z.shape[1]

    def phi(self, Zi, t, h_future):
        c = self.c
        cols = [Zi[t[:, None] - np.arange(c["L"])].reshape(t.size, -1),
                self.u[t[:, None] + h_future - np.arange(c["Q"])], np.ones((t.size, 1))]
        return np.hstack(cols)

    def fit(self, rows, stim_mask):
        c = self.c; hf = H7 if c["direct"] else 1
        F = self.nC * c["L"] + c["Q"] + 1
        G = np.zeros((F, F)); B = np.zeros((F, 1 if c["direct"] else self.nC))
        wts = np.where(stim_mask[rows], c["w"], 1.0)
        for i in range(0, rows.size, 3000):
            r = rows[i:i + 3000]; A = self.phi(self.Zi, r, hf); sw = wts[i:i + 3000][:, None]
            G += A.T @ (A * sw)
            tgt = self.Z[r + H7, :1] if c["direct"] else self.Z[r + 1]
            B += A.T @ (tgt * sw)
        p = np.full(F, c["lam"]); p[-1] = 0
        self.W = np.linalg.solve(G + np.diag(p), B)
        return self

    def predict(self, org, H):
        """Forecast y at leads 1..H (direct model: only lead H7 is defined -> NaN elsewhere)."""
        c = self.c
        if c["direct"]:
            out = np.full((org.size, H), np.nan)
            out[:, H7 - 1] = self.phi(self.Zi, org, H7) @ self.W[:, 0]
            return out
        hist = self.Zi[org[:, None] - np.arange(c["L"])]
        out = np.empty((org.size, H))
        for h in range(H):
            A = np.hstack([hist.reshape(org.size, -1), self.u[org[:, None] + h + 1 - np.arange(c["Q"])],
                           np.ones((org.size, 1))])
            nxt = A @ self.W
            out[:, h] = nxt[:, 0]
            hist = np.concatenate([nxt[:, None, :], hist[:, :-1, :]], axis=1)
        return out


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    Wb = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    yr, ur, X = A["y"].astype(float), A["u"].astype(float), Wb["X"].astype(float)
    sy = yr[valid].std(); y = yr / sy; u = ur / ur[valid].std(); Xs = X / X[valid].std(0)
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = yr.size, onOL.size
    rng = np.random.default_rng(7); fold = rng.permutation(np.arange(nO) % 5) + 1

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    spont = ~(win(onOL, -pre, N + POST) | win(onCL, -pre, N + POST))
    stim = win(onOL, 0, N) | win(onCL, 0, N)

    def rows_for(f):
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        ok = (spont | win(onOL[tr], -pre, N + POST)) & ~win(onOL[te], -pre - PAD, N + POST + HMAX) & valid
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(PAD, T - HMAX - 1)
        return t[(cs[t + 72] - cs[t - PAD + 1]) == 0], te

    rows1, _ = rows_for(1)
    cut = rows1[int((1 - VAL_FRAC) * rows1.size)]
    r_tr, r_va = rows1[rows1 < cut - HMAX], rows1[rows1 >= cut]
    vo = r_va[::5]; yv = y[vo[:, None] + np.arange(1, H7 + 1)]

    log = []
    def score(name, cfg):
        m = Model(cfg, y, Xs, u, r_tr).fit(r_tr, stim)
        fc = m.predict(vo, H7)
        s7 = r2(yv[:, H7 - 1], fc[:, H7 - 1]); s3 = np.nan if cfg["direct"] else r2(yv[:, 2], fc[:, 2])
        log.append((name, dict(cfg), s7, s3))
        print(f"[P200] {name:34s} val R2 200 ms {s7:.4f} | 86 ms {s3:.4f}", flush=True)
        return s7

    # ---- stage 1: embedding length x lambda -------------------------------------------------------
    best, bcfg = -np.inf, dict(BASE)
    for L in (3, 5, 10, 15, 20, 30):
        for lam in (1.0, 10.0, 100.0, 1e3, 1e4):
            cfg = dict(BASE, L=L, lam=lam); s = score(f"L={L} lambda={lam:g}", cfg)
            if s > best:
                best, bcfg = s, cfg
    print(f"[P200] stage 1 best: L={bcfg['L']} lambda={bcfg['lam']:g} -> {best:.4f}", flush=True)
    # ---- stage 2: one lever at a time from the stage-1 best ----------------------------------------
    s1 = dict(bcfg); gains = {}
    for name, ch in ([("Q=%d" % q, dict(Q=q)) for q in (10, 70)] +
                     [("stim weight x%d" % w, dict(w=w)) for w in (3, 10)] +
                     [("spot PCA k=%d" % k, dict(k=k)) for k in (10, 20, 40)] +
                     [("smooth inputs 3", dict(smooth=3))]):
        for lam in (s1["lam"] / 10, s1["lam"], s1["lam"] * 10):  # re-tune lambda per lever
            c = dict(s1, **ch, lam=lam); s = score(f"{name} lambda={lam:g}", c)
            if s > gains.get(name, (-np.inf,))[0]:
                gains[name] = (s, c)
    comb = dict(s1)
    for name, (s, c) in gains.items():
        if s > best + 1e-4:
            comb.update({kk: c[kk] for kk in ("Q", "w", "k", "smooth") if c[kk] != s1[kk]})
    if comb != s1:
        for lam in (s1["lam"] / 10, s1["lam"], s1["lam"] * 10):
            c = dict(comb, lam=lam); s = score(f"COMBINED lambda={lam:g}", c)
            if s > best:
                best, bcfg = s, c
    for name, (s, c) in gains.items():
        if s > best:
            best, bcfg = s, c
    print(f"[P200] stage 2 best: {bcfg} -> {best:.4f}", flush=True)
    # ---- stage 3: direct-for-lead-7 on the same embedding ------------------------------------------
    dbest, dcfg = -np.inf, None
    for lam in (10.0, 100.0, 1e3, 1e4):
        c = dict(bcfg, direct=True, lam=lam); s = score(f"DIRECT lead 7 lambda={lam:g}", c)
        if s > dbest:
            dbest, dcfg = s, c

    # ---- held-out OL test ---------------------------------------------------------------------------
    tests = {"current VARX (L10, lambda100)": dict(BASE), "tuned VARX (iterated)": bcfg, "tuned DIRECT (lead 7)": dcfg}
    res = {}
    for nm, cfg in tests.items():
        FC = np.full((nO, N, H7), np.nan)
        for f in range(1, 6):
            rows, te = rows_for(f)
            m = Model(cfg, y, Xs, u, rows).fit(rows, stim)
            for k in te:
                FC[k] = m.predict(onOL[k] - 1 + np.arange(N), H7) * sy   # origins rel -1..N-2
        out = {}
        for L in ((3, H7) if not cfg["direct"] else (H7,)):
            t0 = np.arange(N - L + 1)
            tg = np.stack([yr[o + t0 + L - 1] for o in onOL]); fc = FC[:, t0, L - 1]
            cc = [np.corrcoef(fc[:, s:].ravel(), tg[:, :tg.shape[1] - s].ravel())[0, 1] for s in range(12)]
            out[L] = (r2(tg, fc), int(np.argmax(cc)))
        res[nm] = out
        print(f"[P200-TEST] {nm:30s} " + " | ".join(f"{L*1000/Fs:.0f} ms R2 {v[0]:.3f} lag {v[1]}" for L, v in out.items()),
              flush=True)
    t0 = np.arange(N - H7 + 1)
    per = r2(np.stack([yr[o + t0 + H7 - 1] for o in onOL]), np.stack([yr[o + t0 - 1] for o in onOL]))
    print(f"[P200-TEST] persistence 200 ms R2 {per:.3f}")

    # ---- figure -------------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(1, 2, figsize=(14, 5), constrained_layout=True)
    a = ax[0]
    Ls = sorted({l[1]["L"] for l in log if not l[1]["direct"] and l[0].startswith("L=")})
    for lam, c in zip((1.0, 10.0, 100.0, 1e3, 1e4), plt.cm.viridis(np.linspace(0, 0.9, 5))):
        v = [next(l[2] for l in log if l[0] == f"L={L} lambda={lam:g}") for L in Ls]
        a.plot(np.array(Ls) * 1000 / Fs, v, "-o", ms=3, color=c, label=f"λ = {lam:g}")
    a.set_xlabel("embedding length (ms)"); a.set_ylabel("validation R² at 200 ms (training data)")
    a.set_title("stage 1: embedding length × ridge λ (VARX, iterated)", fontsize=9); a.legend(fontsize=7, frameon=False)
    a = ax[1]
    st2 = [(l[0], l[2]) for l in log if not l[0].startswith("L=")]
    a.barh(np.arange(len(st2)), [v - best for _, v in st2], color=["#2a9d8f" if v >= best - 1e-9 else "#adb5bd" for _, v in st2])
    a.set_yticks(np.arange(len(st2))); a.set_yticklabels([n for n, _ in st2], fontsize=6.5); a.invert_yaxis()
    a.axvline(0, color="k", lw=0.6); a.set_xlabel("validation R² at 200 ms minus the best")
    a.set_xlim(-0.05, 0.005)   # 'smooth inputs' diverges when iterated (train/iterate mismatch) -> off-scale
    txt = "\n".join(f"{nm}: " + ", ".join(f"{L*1000/Fs:.0f} ms R² {v[0]:.3f} (lag {v[1]*1000/Fs:.0f} ms)" for L, v in o.items())
                    for nm, o in res.items()) + f"\npersistence: 200 ms R² {per:.3f}"
    a.set_title("stage 2-3 levers  |  HELD-OUT OL TEST:\n" + txt, fontsize=7.5, loc="left")
    fig.savefig(FIG / f"pred200_sweep_{sess}.png", dpi=200)
    savemat(DATA / f"mpc_pred200_sweep_{sess}.mat", {
        "names": np.array([l[0] for l in log], dtype=object), "val_r2_200": np.array([l[2] for l in log]),
        "val_r2_86": np.array([l[3] for l in log]), "best": str(bcfg), "best_direct": str(dcfg),
        "test": {k.replace(" ", "_").replace("(", "").replace(")", "").replace(",", ""): np.array(list(v.values()))
                 for k, v in res.items()}, "persist200": per})


if __name__ == "__main__":
    main(*sys.argv[1:])
