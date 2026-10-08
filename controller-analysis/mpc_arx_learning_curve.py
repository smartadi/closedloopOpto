"""Is the whole-brain disturbance forecaster data-limited? Learning curve on the CL-trial test folds.

Model: the 'wbbest' direct ridge of mpc_arx_wb2s.py (target d = y - plant(u); d + laser 35-frame history,
100 brain spots 10-frame history), same 5 CL folds and exclusions. For each fraction of the training data
(random 60-s blocks, so the subsample keeps temporal structure; 3 draws), refit (lambda by inner validation)
and score held-out CL-trial R^2 of the disturbance at 29/57/86/143 ms, plus the in-sample training R^2.
Reading: test R^2 still rising at 100 % -> more data (other sessions/mice) should help; flat -> it will not,
and a different model class (nonlinear / state-dependent) is the lever. Train >> test -> variance-limited.

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_learning_curve.py [sess]
OUT     data/mpc_arx_learning_curve_<sess>.mat, paper/images/mpc_arx/learning_curve_<sess>.png
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mpc_arx_wb2s as W  # noqa: E402

FRACS = [0.05, 0.1, 0.25, 0.5, 0.75, 1.0]
LEADS = np.array([1, 2, 3, 5])
BLOCK = 35 * 60


def main(sess="AL_0033_0226_e2"):
    A, Wf = W.load(sess)
    valid = A["valid"].astype(bool)
    dr, ur, X = A["d"].astype(float), A["u"].astype(float), Wf["X"].astype(float)
    sd = dr[valid].std(); d, u = dr / sd, ur / ur[valid].std(); Xs = X / X[valid].std(0)
    onCL = A["onCL"].astype(int) - 1; fold = A["fold"].astype(int); Dmean = A["Dmean"].astype(float)
    pre, N, Hp, Fs = int(A["pre"]), int(A["N"]), int(A["Hp"]), float(A["Fs"])
    T = d.size; leads = np.arange(1, Hp + 1)
    D = W.Design(d, u, Xs, 0, True, hs=35, hu=35, hx=10)
    rng = np.random.default_rng(11)

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m

    DEP = np.stack([dr[o - pre:o + N + 1] for o in onCL]) - Dmean[None, :]
    test_r2 = np.full((len(FRACS), 3, LEADS.size), np.nan); train_r2 = test_r2.copy(); nrows = np.zeros(len(FRACS))
    for fi, fr in enumerate(FRACS):
        for rep in range(3 if fr < 1 else 1):
            tg, fc, trs = {L: [] for L in LEADS}, {L: [] for L in LEADS}, []
            for f in np.unique(fold):
                te = np.flatnonzero(fold == f)
                ok = valid & ~win(onCL[te], -pre - W.HIST, N + Hp + W.HIST)
                cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(W.HIST, T - Hp - 1)
                rows = t[(cs[t + Hp + 1] - cs[t - W.HIST + 1]) == 0]
                if fr < 1:
                    blk = rows // BLOCK; ub = np.unique(blk)
                    keep = rng.choice(ub, max(2, int(round(fr * ub.size))), replace=False)
                    rows = rows[np.isin(blk, keep)]
                Wt, _ = W.fit_fold(D, d, rows, leads, f"frac {fr:.2f} rep {rep} fold {f}")
                A_tr = D(rows[::5]);
                for j, L in enumerate(LEADS):
                    yt = d[rows[::5] + L]; trs.append((j, 1 - np.sum((yt - A_tr @ Wt[:, L - 1]) ** 2) / np.sum((yt - yt.mean()) ** 2)))
                for k in te:
                    fk = D(onCL[k] + np.arange(N)) @ Wt * sd - Dmean[np.minimum(pre + np.arange(1, N + 1)[:, None] + np.arange(Hp), Dmean.size - 1)]
                    for L in LEADS:
                        tt = np.arange(1, N - L + 1)
                        tg[L].append(DEP[k, pre + tt + L - 1 + 1 - 1]); fc[L].append(fk[tt - 1, L - 1])
            for j, L in enumerate(LEADS):
                a, b = np.concatenate(tg[L]), np.concatenate(fc[L])
                test_r2[fi, rep, j] = 1 - np.sum((a - b) ** 2) / np.sum((a - a.mean()) ** 2)
                train_r2[fi, rep, j] = np.mean([v for jj, v in trs if jj == j])
            nrows[fi] = rows.size
        print(f"[LC] frac {fr:.2f} (~{nrows[fi]/Fs/60:.0f} min/fold) test R2 @ {np.round(LEADS*1000/Fs).astype(int)} ms: "
              f"{np.round(np.nanmean(test_r2[fi], 0), 3)} | train {np.round(np.nanmean(train_r2[fi], 0), 3)}", flush=True)

    mins = nrows / Fs / 60
    fig, ax = plt.subplots(1, 1, figsize=(6.5, 4.2), constrained_layout=True)
    cols = ["#264653", "#2a9d8f", "#e76f51", "#8d5524"]
    for j, L in enumerate(LEADS):
        m = np.nanmean(test_r2[:, :, j], 1); s = np.nanstd(test_r2[:, :, j], 1)
        ax.errorbar(mins, m, s, fmt="-o", ms=4, color=cols[j], label=f"held-out CL, {L*1000/Fs:.0f} ms")
        ax.plot(mins, np.nanmean(train_r2[:, :, j], 1), ":", color=cols[j], lw=1)
    ax.set_xscale("log"); ax.set_xlabel("training data (minutes, per fold)"); ax.set_ylabel("R² of disturbance forecast")
    ax.set_title("whole-brain forecaster learning curve (dotted = training R²)", fontsize=9)
    ax.legend(fontsize=7, frameon=False)
    fig.savefig(W.FIG / f"learning_curve_{sess}.png", dpi=200)
    savemat(W.DATA / f"mpc_arx_learning_curve_{sess}.mat", {"fracs": FRACS, "minutes": mins, "test_r2": test_r2,
            "train_r2": train_r2, "lead_ms": LEADS * 1000 / Fs})


if __name__ == "__main__":
    main(*sys.argv[1:])
