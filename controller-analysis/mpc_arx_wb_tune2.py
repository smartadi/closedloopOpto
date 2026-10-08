"""Second tuning pass for the whole-brain direct ARX, leads 1..5 frames (29-143 ms).

Beyond lag lengths (mpc_arx_wb_tune.py: flat), try the levers that change what the model can express:
  grp    separate ridge strength for the brain-spot block (multiplier on the own-history lambda)
  hp     spots high-passed causally (minus their trailing 2 s mean) -> drop slow drift
  pca    spots compressed to k PCs (fit on training rows), allowing longer spot history
  mot    face/body motion energy (d.motion) lags as an extra input
  stim   stim-on interaction: s_t * (y lags 0..9) and s_t * (spots lag 0), s_t = laser on -> different
         dynamics during stimulation (cheap state-dependence)
Search is coordinate-wise from the tuned base (PY35, spots raw L10, QU35); each variant gets its own
per-lead lambda. Criterion: validation R^2 averaged over leads 1..5, fold-1 TRAINING data only (last 20 %
chronological). The winning combination is then tested on the 5-fold held-out OL trials (R^2 + lag).

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_wb_tune2.py [sess] [spot tag]
OUT     data/mpc_arx_wb_tune2_<sess>.mat, paper/images/mpc_arx/wb_tune2_<sess>.png
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
POST, VAL_FRAC, HPAD, MAXLAG = 70, 0.2, 141, 70
HS = np.arange(1, 6)                                   # leads 1..5 frames
LAMS = 10.0 ** np.arange(-1, 5)
BASE = dict(PY=35, QU=35, LSP=10, spots="raw", k=0, mult=1.0, LM=0, stim=False)


def causal_hp(X, w=70):
    c = np.cumsum(np.vstack([np.zeros((1, X.shape[1])), X]), axis=0)
    i = np.arange(X.shape[0]); lo = np.maximum(0, i - w + 1)
    return X - (c[i + 1] - c[lo]) / (i + 1 - lo)[:, None]


class Design:
    def __init__(self, cfg, y, u, S, mot, s_on):
        self.c, self.y, self.u, self.S, self.m, self.s = cfg, y, u, S, mot, s_on
        nS = S.shape[1]
        self.blocks = [("y", cfg["PY"]), ("up", cfg["QU"]), ("uf", HS.max()), ("sp", nS * cfg["LSP"])]
        if cfg["LM"]:
            self.blocks.append(("mot", cfg["LM"]))
        if cfg["stim"]:
            self.blocks += [("sy", 10), ("ssp", nS)]
        self.blocks.append(("1", 1))
        self.F = sum(n for _, n in self.blocks)

    def __call__(self, t):
        c = self.c
        cols = [self.y[t[:, None] - np.arange(c["PY"])], self.u[t[:, None] - np.arange(c["QU"])],
                self.u[t[:, None] + 1 + np.arange(HS.max())],
                self.S[t[:, None] - np.arange(c["LSP"])].reshape(t.size, -1)]
        if c["LM"]:
            cols.append(self.m[t[:, None] - np.arange(c["LM"])])
        if c["stim"]:
            s = self.s[t][:, None]
            cols += [s * self.y[t[:, None] - np.arange(10)], s * self.S[t]]
        cols.append(np.ones((t.size, 1)))
        return np.hstack(cols)

    def pen(self, lam):
        p = []
        for name, n in self.blocks:
            v = 0.0 if name == "1" else lam * (self.c["mult"] if name in ("sp", "ssp") else 1.0)
            p.append(np.full(n, v))
        return np.concatenate(p)

    def mask(self, h):
        m = np.ones(self.F, bool); o = self.c["PY"] + self.c["QU"]
        m[o + h: o + HS.max()] = False                        # future stim only up to t+h
        return m


def fit_eval(D, y, r_tr, r_va, lam_grid):
    G = np.zeros((D.F, D.F)); B = np.zeros((D.F, HS.size))
    for i in range(0, r_tr.size, 6000):
        r = r_tr[i:i + 6000]; A = D(r); G += A.T @ A; B += A.T @ y[r[:, None] + HS]
    Av, Yv = D(r_va), y[r_va[:, None] + HS]
    best = []
    for j, h in enumerate(HS):
        m = D.mask(h); sc = []
        for lam in lam_grid:
            w = np.linalg.solve(G[np.ix_(m, m)] + np.diag(D.pen(lam)[m]), B[m, j])
            e = Yv[:, j] - Av[:, m] @ w
            sc.append((1 - np.sum(e ** 2) / np.sum((Yv[:, j] - Yv[:, j].mean()) ** 2), lam))
        best.append(max(sc))
    return np.array([b[0] for b in best]), np.array([b[1] for b in best]), G, B


def main(sess="AL_0033_0226_e2", tag="100"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    W = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n{tag}.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    yr, u, X, mot = A["y"].astype(float), A["u"].astype(float), W["X"].astype(float), A["motion"].astype(float)
    sy = yr[valid].std()
    y, u = yr / sy, u / u[valid].std()
    Xr = X / X[valid].std(0); Xhp = causal_hp(Xr); Xhp /= Xhp[valid].std(0)
    mot = (mot - mot[valid].mean()) / (mot[valid].std() + 1e-12)
    s_on = (A["u"] > 0.05 * A["u"].max()).astype(float)
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

    def rows_for(f):
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        ok = (spont | win(onOL[tr], -pre, N + POST)) & ~win(onOL[te], -pre - MAXLAG, N + POST + HPAD) & valid
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(MAXLAG, T - HPAD - 1)
        return t[(cs[t + HPAD + 1] - cs[t - MAXLAG + 1]) == 0], te

    def spots(cfg, rows):
        S = Xhp if cfg["spots"] == "hp" else Xr
        if cfg["k"]:
            Z = S[rows[::5]]; Z = Z - Z.mean(0)
            V = np.linalg.svd(Z, full_matrices=False)[2][:cfg["k"]].T
            P = S @ V; return P / P[valid].std(0)
        return S

    rows1, _ = rows_for(1)
    cut = rows1[int((1 - VAL_FRAC) * rows1.size)]
    r_tr, r_va = rows1[rows1 < cut - HPAD], rows1[rows1 >= cut][::2]

    def score(cfg):
        D = Design(cfg, y, u, spots(cfg, r_tr), mot, s_on)
        r2, lam, _, _ = fit_eval(D, y, r_tr, r_va, LAMS)
        return r2, lam

    log = []
    def run(name, cfg):
        r2, lam = score(cfg)
        log.append((name, dict(cfg), r2, lam))
        print(f"[TUNE2] {name:28s} val R2 @ {np.round(HS*1000/Fs).astype(int)} ms: {np.round(r2, 4)} "
              f"mean {r2.mean():.4f} | lambda {lam}", flush=True)
        return r2.mean()

    base = run("base (PY35 L10 Q35)", BASE)
    best_cfg, best = dict(BASE), base
    trials = [("grp mult %g" % m_, dict(mult=m_)) for m_ in (0.1, 0.3, 3, 10)]
    trials += [("spots high-passed", dict(spots="hp"))]
    trials += [("spots PCA k=%d L=%d" % (k, L), dict(k=k, LSP=L)) for k in (10, 20, 50) for L in (10, 20)]
    trials += [("motion LM=%d" % L, dict(LM=L)) for L in (5, 10)]
    trials += [("stim interaction", dict(stim=True))]
    gains = {}
    for name, ch in trials:
        cfg = dict(BASE); cfg.update(ch)
        gains[name] = (run(name, cfg) - base, ch)
    # combine every change that helped (best variant per lever), check the combination
    lever = lambda n: n.split()[0]
    pick = {}
    for n, (g, ch) in gains.items():
        if g > 1e-4 and (lever(n) not in pick or g > pick[lever(n)][0]):
            pick[lever(n)] = (g, ch)
    comb = dict(BASE)
    for g, ch in pick.values():
        comb.update(ch)
    if pick:
        cm = run("COMBINED " + "+".join(sorted(pick)), comb)
        if cm > best:
            best_cfg, best = comb, cm
    for n, (g, ch) in gains.items():
        if g + base > best:
            c2 = dict(BASE); c2.update(ch); best_cfg, best = c2, g + base
    print(f"[TUNE2] chosen config {best_cfg} | val mean R2 {best:.4f} (base {base:.4f})")

    # ---- held-out OL test: base vs chosen vs ROI-only, leads 1..5 --------------------------------
    roi = dict(BASE); roi["LSP"] = 0
    tests = {"ROI only": roi, "base whole-brain": BASE, "chosen": best_cfg}
    lamsel = {k: v[3] for k, v in [(l[0], l) for l in log]}
    res = {}
    for nm, cfg in tests.items():
        Fh = np.full((HS.size, nO, N), np.nan)
        for f in range(1, 6):
            rows, te = rows_for(f)
            D = Design(cfg, y, u, spots(cfg, rows), mot, s_on)
            cut_f = rows[int((1 - VAL_FRAC) * rows.size)]
            rt, rv = rows[rows < cut_f - HPAD], rows[rows >= cut_f][::2]
            _, lam, _, _ = fit_eval(D, y, rt, rv, LAMS)           # lambda per lead, inner validation
            G = np.zeros((D.F, D.F)); B = np.zeros((D.F, HS.size))
            for i in range(0, rows.size, 6000):
                r = rows[i:i + 6000]; Am = D(r); G += Am.T @ Am; B += Am.T @ y[r[:, None] + HS]
            for j, h in enumerate(HS):
                m = D.mask(h)
                w = np.linalg.solve(G[np.ix_(m, m)] + np.diag(D.pen(lam[j])[m]), B[m, j])
                for k in te:
                    Fh[j, k] = D(onOL[k] - 1 + np.arange(N))[:, m] @ w * sy
        out = []
        for j, h in enumerate(HS):
            Y = np.stack([yr[o - 1 + h + np.arange(N)] for o in onOL])
            r2 = 1 - np.sum((Y - Fh[j]) ** 2) / np.sum((Y - Y.mean()) ** 2)
            cc = [np.corrcoef(Fh[j][:, L:].ravel(), Y[:, :N - L].ravel())[0, 1] for L in range(9)]
            out.append((r2, int(np.argmax(cc))))
        res[nm] = out
        print(f"[TEST2] {nm:18s} R2 @ {np.round(HS*1000/Fs).astype(int)} ms: "
              f"{np.round([o[0] for o in out], 3)} | lag (frames) {[o[1] for o in out]}", flush=True)
    per = []
    for j, h in enumerate(HS):
        Y = np.stack([yr[o - 1 + h + np.arange(N)] for o in onOL]); P = np.stack([yr[o - 1 + np.arange(N)] for o in onOL])
        per.append(1 - np.sum((Y - P) ** 2) / np.sum((Y - Y.mean()) ** 2))
    print(f"[TEST2] persistence        R2: {np.round(per, 3)}")

    # ---- figure -----------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(1, 2, figsize=(14, 4.4), constrained_layout=True)
    a = ax[0]
    nm_ = [l[0] for l in log]; mv = np.array([l[2].mean() for l in log])
    a.barh(np.arange(len(nm_)), mv - base, color=["#2a9d8f" if v > base else "#d1495b" for v in mv])
    a.set_yticks(np.arange(len(nm_))); a.set_yticklabels(nm_, fontsize=7); a.invert_yaxis()
    a.axvline(0, color="k", lw=0.6); a.set_xlabel("Δ validation R² vs base (mean over 29-143 ms)")
    a.set_title(f"parameter levers (base mean val R² {base:.3f}; training data only)", fontsize=9)
    a = ax[1]; ms = HS * 1000 / Fs
    for (nm, out), c in zip(res.items(), ["#5b2c86", "#e07a5f", "#2a9d8f"]):
        a.plot(ms, [o[0] for o in out], "-o", ms=3, color=c, label=nm)
    a.plot(ms, per, ":", color="0.45", label="persistence")
    a.set_xlabel("forecast lead (ms)"); a.set_ylabel("held-out OL R²"); a.legend(fontsize=7, frameon=False)
    a.set_title("held-out OL test, leads 29-143 ms", fontsize=9)
    fig.savefig(FIG / f"wb_tune2_{sess}.png", dpi=200)
    savemat(DATA / f"mpc_arx_wb_tune2_{sess}.mat", {
        "names": np.array(nm_, dtype=object), "val_r2": np.array([l[2] for l in log]),
        "test": {k.replace(" ", "_"): np.array(v) for k, v in res.items()}, "persist": np.array(per),
        "lead_ms": ms, "chosen": str(best_cfg)})
    print(f"[TUNE2] -> {FIG / f'wb_tune2_{sess}.png'}")


if __name__ == "__main__":
    main(*sys.argv[1:])
