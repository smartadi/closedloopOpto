"""Is our 200 ms predictor worse than the Lu et al. (Ziyu) AR? Put both on the same metric (user 2026-10-07).

Lu et al. report MWQL RELATIVE TO NAIVE (last value), univariate REGION-AVERAGE dF/F, SPONTANEOUS data,
horizons 0.5-2 s (Fig 1c reads, kept in ctrl_tube_mpc.m: AR 0.83, PatchTST 0.80 x Naive at 1.0 s).
For a point forecast the weighted quantile loss is proportional to sum|e| / sum|y|, so the ratio to Naive
reduces to MAE / MAE_naive. We report that, MSE / MSE_naive, and R^2, for:
  models   Naive | AR (univariate, 20 lags, ridge, iterated, no laser) | VARX (100 spots + laser, L10, lambda100)
  targets  controlled spot (5x5 px, rig rolling-baseline dF/F)  |  "region" = mean of the 9 spots nearest the
           laser site (mean-image dF/F; ~an Allen-area-sized average)
  data     STIM: 92 held-out OL trials (5 folds, origins at every trial frame -- our MPC task)
           SPONT: chronological last 20 % of the session, spontaneous frames only (Lu-like task)
  leads    200 ms (7), 514 ms (18), 1.0 s (35)

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_pred_vs_lu.py [sess]
OUT     data/mpc_pred_vs_lu_<sess>.mat, paper/images/mpc_arx/pred_vs_lu_<sess>.png
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_pred200_sweep import Model, BASE, POST, HMAX, PAD  # noqa: E402

HERE = Path(__file__).resolve().parent
DATA, FIG = HERE / "data", HERE.parent / "paper" / "images" / "mpc_arx"
LEADS = (7, 18, 35)
LU = {"AR": 0.83, "PatchTST": 0.80}          # Lu et al. Fig 1c, 1.0 s MWQL / Naive (figure reads)


def metrics(tg, fc, nv):
    return dict(r2=1 - np.sum((tg - fc) ** 2) / np.sum((tg - tg.mean()) ** 2),
                mae=np.mean(np.abs(tg - fc)) / np.mean(np.abs(tg - nv)),
                mse=np.mean((tg - fc) ** 2) / np.mean((tg - nv) ** 2))


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    Wb = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    X = Wb["X"].astype(float); Xs = X / X[valid].std(0)
    ur = A["u"].astype(float); u = ur / ur[valid].std(); u0 = np.zeros_like(u)
    near = np.argsort(Wb["dist_px"])[:9]
    TARGETS = {"controlled spot": A["y"].astype(float), "region (9 spots at site)": X[:, near].mean(1)}
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = valid.size, onOL.size
    fold = np.random.default_rng(7).permutation(np.arange(nO) % 5) + 1
    H = max(LEADS)

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    spont = ~(win(onOL, -pre, N + POST) | win(onCL, -pre, N + POST))
    stim = win(onOL, 0, N) | win(onCL, 0, N)

    def clean_rows(ok):
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(PAD, T - HMAX - 1)
        return t[(cs[t + 72] - cs[t - PAD + 1]) == 0]

    def models(yr, rows):
        sy = yr[valid].std(); y = yr / sy
        ar = Model(dict(BASE, L=20, lam=1.0, Q=1), y, Xs[:, :0], u0, rows).fit(rows, stim)
        vx = Model(dict(BASE), y, Xs, u, rows).fit(rows, stim)
        return {"AR (univariate)": lambda o: ar.predict(o, H) * sy, "VARX (100 spots + laser)": lambda o: vx.predict(o, H) * sy}

    R = {}
    for tn, yr in TARGETS.items():
        # ---- STIM: held-out OL trials (our MPC task) --------------------------------------------------
        fcs, origins = {}, []
        for f in range(1, 6):
            te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
            rows = clean_rows((spont | win(onOL[tr], -pre, N + POST)) & ~win(onOL[te], -pre - PAD, N + POST + HMAX) & valid)
            M = models(yr, rows)
            o = np.concatenate([onOL[k] - 1 + np.arange(N) for k in te])
            origins.append(o)
            for mn, p in M.items():
                fcs.setdefault(mn, []).append(p(o))
        o = np.concatenate(origins)
        R[(tn, "stim")] = {mn: {L: metrics(yr[o + L], np.concatenate(v)[:, L - 1], yr[o]) for L in LEADS} for mn, v in fcs.items()}
        # ---- SPONT: chronological last 20 % (Lu-like task) ----------------------------------------------
        allrows = clean_rows((spont | win(onOL, -pre, N + POST)) & valid)
        cut = allrows[int(0.8 * allrows.size)]
        tr = allrows[allrows < cut - HMAX]
        te = allrows[(allrows >= cut) & spont[allrows] & np.array([spont[t:t + H + 1].all() for t in allrows])][::3]
        M = models(yr, tr)
        R[(tn, "spont")] = {mn: {L: metrics(yr[te + L], p(te)[:, L - 1], yr[te]) for L in LEADS} for mn, p in M.items()}
        for cond in ("stim", "spont"):
            for mn, d in R[(tn, cond)].items():
                print(f"[VSLU] {tn:26s} {cond:5s} {mn:26s} " + " | ".join(
                    f"{L*1000/Fs:4.0f} ms R2 {m['r2']:.3f} MAE/naive {m['mae']:.2f} MSE/naive {m['mse']:.2f}" for L, m in d.items()), flush=True)

    # ---- figure: MAE / Naive vs lead, Lu reference at 1 s ------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(1, 4, figsize=(16, 4.2), constrained_layout=True, sharey=True)
    for a, ((tn, cond), d) in zip(ax, R.items()):
        for mn, c in zip(d, ("#e76f51", "#264653")):
            a.plot([L * 1000 / Fs for L in LEADS], [d[mn][L]["mae"] for L in LEADS], "-o", color=c, label=mn)
            for L in LEADS:
                a.annotate(f"R² {d[mn][L]['r2']:.2f}", (L * 1000 / Fs, d[mn][L]["mae"]), fontsize=6.5,
                           textcoords="offset points", xytext=(3, -10 if c == "#264653" else 5), color=c)
        for nm, v in LU.items():
            a.plot(1000, v, "k*" if nm == "PatchTST" else "kD", ms=8 if nm == "PatchTST" else 5, label=f"Lu et al. {nm} (1 s, Fig 1c)")
        a.axhline(1, color="gray", lw=0.6, ls="--")
        a.set_title(f"{tn} | {'held-out OL stim trials' if cond == 'stim' else 'held-out spontaneous'}", fontsize=8.5)
        a.set_xlabel("forecast lead (ms)")
    ax[0].set_ylabel("MAE relative to Naive (≈ Lu et al. MWQL ratio)\n1 = no better than last value")
    ax[0].legend(fontsize=6.5, frameon=False, loc="lower right")
    fig.savefig(FIG / f"pred_vs_lu_{sess}.png", dpi=180)
    savemat(DATA / f"mpc_pred_vs_lu_{sess}.mat", {"leads_ms": np.array(LEADS) * 1000 / Fs,
        "table": np.array([[ti, ci, mi, L, m["r2"], m["mae"], m["mse"]]
                           for ti, tn in enumerate(TARGETS) for ci, cond in enumerate(("stim", "spont"))
                           for mi, (mn, d) in enumerate(R[(tn, cond)].items()) for L, m in d.items()]),
        "cols": "target cond model lead r2 mae_rel_naive mse_rel_naive"})


if __name__ == "__main__":
    main(*sys.argv[1:])
