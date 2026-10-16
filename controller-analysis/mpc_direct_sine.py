"""Direct-prediction MPC replay on a SINE reference (Fig 6 I-L; user 2026-10-16). Sibling of mpc_direct.py (static
-5 reference, Fig 6 A-H): same VARX, same world, same MPC costs. The only change is the reference, which is now a
trajectory r(t), and the MPC cost uses its future r(t+1..t+Hp) -- the natural preview.

SESSION AL_0048 2026-07-14/1 (Fig 5's representative session), right hemisphere (inhibitory), 1 Hz sine 0..-4 %dF/F,
        4 s window, 4 interleaved modes OL / OL+p / CL / CL+p (rig PI Kp 0.08, Ki 0, preview 5 frames).
        Inputs from ctrl_mpc_sine_export.m (y = rig online dF/F states.csv on the frame clock, r = -reference_raw).
MODEL   VARX on z = [y, 100 brain spots], L = 10, Q = 35, ridge 100; 5-fold held-out controller models (folds
        interleaved over all 200 sine trials; a test fold's trial windows are cut out of training).
WORLD   VARX on all valid frames + each trial's recorded one-step innovations: under the recorded laser it reproduces
        every recorded trial exactly (asserted for all 200).
SIMULATED on EVERY sine trial (its innovations): MPC (fold model, rd = MPCD_RD) and the perfect-prediction MPC (world
        model + future innovations). Baselines = the recorded trials themselves: CL and CL+p (the MPC run on a CL
        trial is paired with that recorded CL trial). OL / OL+p are shown recorded only.
METRICS over the full stim window (onset .. onset + 4 s, 141 frames, Fig 5G): per-trial RMSE vs r; phase lag and gain
        of the trial average from a 1 Hz fundamental fit (Fig 5H: lag = wrapped phase(r) - phase(y), deg, >0 = y lags);
        across-trial variance per frame, averaged over the window. Simulation -> descriptive only.

Usage:  MPCD_RD=0.1 .venv\\Scripts\\python.exe controller-analysis\\mpc_direct_sine.py
OUT     data/mpc_direct_sine_<sess><MPCD_TAG>.mat, paper/images/mpc_arx/mpc_direct_sine_<sess><MPCD_TAG>.png
"""
import os
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_direct import VX, mpc_solve, CFG, HP, HIST, EXT, DATA, FIG  # noqa: E402
from mpc_pred200_sweep import Model, BASE  # noqa: E402

RD = float(os.environ.get("MPCD_RD", "0.1"))
ORD = float(os.environ.get("MPCD_ORD", str(RD)))
TAG = os.environ.get("MPCD_TAG", "")
NAMES = ["CL+p", "OL+p", "OL", "CL"]                # ff_cond 0 1 2 3


def fund(Fs, N, hz):
    t = np.arange(N) / Fs
    Xf = np.column_stack([np.ones(N), np.sin(2 * np.pi * hz * t), np.cos(2 * np.pi * hz * t)])
    def fit(y):
        b = np.linalg.lstsq(Xf, y, rcond=None)[0]
        return np.hypot(b[1], b[2]), np.arctan2(b[2], b[1])
    return fit


def lag_gain(fit, ym, rm):
    ay, py = fit(ym); ar, pr = fit(rm)
    return np.degrees((pr - py + np.pi) % (2 * np.pi) - np.pi), ay / ar


def main(sess="AL_0048_0714_e1"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    yr, ur, rr = A["y"].astype(float), A["u"].astype(float), A["r"].astype(float)
    X = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)["X"].astype(float)
    Zr = np.column_stack([yr, X]); sz = Zr[valid].std(0); su = ur[valid].std()
    Z, u = np.nan_to_num(Zr / sz), ur / su
    on, cond, fold = A["on"].astype(int) - 1, A["cond"].astype(int), A["fold"].astype(int)
    pre, N, Fs, hz = int(A["pre"]), int(A["N"]), float(A["Fs"]), float(A["sine_hz"])
    T, nT, L, Q = Z.shape[0], on.size, CFG["L"], CFG["Q"]
    stim = np.zeros(T, bool)
    closed = np.isin(cond, [0, 3])
    umax = max(ur[o:o + N].max() for o in on[closed])
    uss = np.median(np.concatenate([ur[o:o + N] for o in on[closed]]))

    def rows_excl(test):
        ok = valid.copy()
        for o in on[test]:
            ok[max(0, o - pre - HIST): o + N + HP + HIST] = False
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(HIST, T - HP - 1)
        return t[(cs[t + HP + 1] - cs[t - HIST + 1]) == 0]

    def fit(rows):
        mdl = Model(dict(BASE, **CFG), Z[:, 0], Z[:, 1:], u, rows).fit(rows, stim)
        return VX(mdl.W, CFG["L"], CFG["Q"], sz, su)

    world = fit(rows_excl(np.array([], int)))
    ctrl = {f: fit(rows_excl(np.flatnonzero(fold == f))) for f in np.unique(fold)}
    print(f"[MPCS] {sess}: {nT} sine trials ({', '.join(f'{NAMES[c]} {np.sum(cond == c)}' for c in range(4))}) | "
          f"u_max {umax:.2f} | uss {uss:.2f} | world DC gain {world.G[:, 0].sum():.2f} %/unit", flush=True)

    E = np.zeros_like(Z)
    for o in on:
        for t in range(o - 2, o + N + max(HP, EXT) + 1):
            E[t + 1] = Z[t + 1] - world.step(Z[t - np.arange(world.L)], u[t + 1 - np.arange(world.Q)])

    def simulate(k, policy):
        o = on[k]; zs, us = Z.copy(), u.copy()
        for t in range(o - 1, o + N - 1 + EXT):
            us[t + 1] = policy(t, zs, us) / su if t + 1 < o + N else 0.0
            zs[t + 1] = world.step(zs[t - np.arange(world.L)], us[t + 1 - np.arange(world.Q)]) + E[t + 1]
        return (zs[o:o + N, 0] * sz[0], us[o:o + N] * su,
                zs[o - EXT:o + N + EXT, 0] * sz[0], us[o - EXT:o + N + EXT] * su)

    def mpc_policy(m, rd, oracle=False):
        def pol(t, zs, us):
            innov = E[t + 1:t + 1 + HP] if oracle else None
            f = m.free(zs[t - np.arange(m.L)], us[t - m.Q + 2:t + 1], innov)
            return float(mpc_solve(m, f, us[t] * su, uss, umax, rd, ref=rr[t + 1:t + 1 + HP])[0])
        return pol

    Rw = np.column_stack([rr[o:o + N] for o in on])                       # N x nT reference in each window
    rmse = lambda yy, k: np.sqrt(np.mean((yy - Rw[:, k]) ** 2))
    for k in range(nT):                                                    # world reproduces EVERY recorded trial
        y0 = simulate(k, lambda t, zs, us: u[t + 1] * su)[0]
        assert np.allclose(y0, yr[on[k]:on[k] + N], atol=1e-6), f"world replay does not reproduce trial {k + 1}"
    print(f"[MPCS] world reproduces all {nT} recorded trials (atol 1e-6)", flush=True)
    rRec = np.array([rmse(yr[o:o + N], k) for k, o in enumerate(on)])

    sims = {}
    for nm, mk in (("MPC", lambda k: mpc_policy(ctrl[fold[k]], RD)), ("perfect", lambda k: mpc_policy(world, ORD, oracle=True))):
        S = [simulate(k, mk(k)) for k in range(nT)]
        sims[nm] = (S, np.array([rmse(s[0], k) for k, s in enumerate(S)]))
        print(f"[MPCS] {nm} done", flush=True)

    # controller-model prediction quality on the sine windows (recorded future laser), all trials
    r2 = {}
    for Lh in (3, 7):
        tg, fc = [], []
        for k in range(nT):
            m = ctrl[fold[k]]; o = on[k]
            for t in range(o, o + N - Lh):
                fc.append(m._roll(m.W, Z[t - np.arange(L)], u[t - Q + 2:t + 1 + HP], Lh)[-1, 0] * sz[0]); tg.append(yr[t + Lh])
        tg, fc = np.array(tg), np.array(fc)
        r2[Lh] = 1 - np.sum((tg - fc) ** 2) / np.sum((tg - tg.mean()) ** 2)

    # ---- summaries: recorded modes, and MPC / perfect on the CL and CL+p trials -----------------------------------
    ff = fund(Fs, N, hz)
    Yrec = np.column_stack([yr[o:o + N] for o in on])
    Ysim = {nm: np.column_stack([s[0] for s in sims[nm][0]]) for nm in sims}
    rows, lab = [], []
    def summ(Y, rm, msk):
        lg, gn = lag_gain(ff, Y[:, msk].mean(1), Rw[:, msk].mean(1))
        return [np.median(rm[msk]), lg, gn, Y[:, msk].var(1, ddof=1).mean(), msk.sum()]
    for c in (2, 1, 3, 0):
        rows.append(summ(Yrec, rRec, cond == c)); lab.append(f"rec {NAMES[c]}")
    for nm in sims:
        for c in (3, 0):
            rows.append(summ(Ysim[nm], sims[nm][1], cond == c)); lab.append(f"{nm} on {NAMES[c]}")
        rows.append(summ(Ysim[nm], sims[nm][1], closed)); lab.append(f"{nm} on CL+CL+p")
    summary = np.array(rows)
    for l_, r_ in zip(lab, rows):
        print(f"[MPCS] {l_:22s} median RMSE {r_[0]:.3f} | lag {r_[1]:6.1f} deg | gain {r_[2]:.2f} | var {r_[3]:.2f} | n {int(r_[4])}")
    for c in (3, 0):
        m_ = cond == c
        for nm in sims:
            ra = sims[nm][1][m_] / rRec[m_]
            print(f"[MPCS] {nm}/rec {NAMES[c]}: median ratio {np.median(ra):.3f} | lower on {np.sum(ra < 1)}/{m_.sum()}")
    print(f"[MPCS] controller-model R^2 of y on sine windows (recorded laser): 86 ms {r2[3]:.3f} | 200 ms {r2[7]:.3f}", flush=True)

    # ---- quick-look figure --------------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    tt = np.arange(N) / Fs
    fig, ax = plt.subplots(1, 3, figsize=(15, 4), constrained_layout=True)
    cols = {2: "red", 1: "orange", 3: "#0066d9", 0: "green"}
    for c in (2, 1, 3, 0):
        ax[0].plot(tt, Yrec[:, cond == c].mean(1), color=cols[c], label=NAMES[c])
    ax[0].plot(tt, Ysim["MPC"][:, closed].mean(1), color="#733399", lw=2, label="MPC")
    ax[0].plot(tt, Ysim["perfect"][:, closed].mean(1), color="#c7a8e6", lw=2, label="perfect")
    ax[0].plot(tt, Rw.mean(1), "k--", lw=1, label="ref"); ax[0].legend(fontsize=7, frameon=False)
    for j, c in enumerate((3, 0)):
        m_ = cond == c
        ax[1].plot(np.full(m_.sum(), 2 * j), rRec[m_], "o", ms=3, color=cols[c], alpha=.5)
        ax[1].plot(np.full(m_.sum(), 2 * j + 1), sims["MPC"][1][m_], "o", ms=3, color="#733399", alpha=.5)
        for a_, b_ in zip(rRec[m_], sims["MPC"][1][m_]):
            ax[1].plot([2 * j, 2 * j + 1], [a_, b_], color="0.8", lw=.4, zorder=0)
    ax[1].set_xticks(range(4)); ax[1].set_xticklabels(["CL", "MPC", "CL+p", "MPC"]); ax[1].set_ylabel("RMSE (%)")
    for c in (2, 1, 3, 0):
        ax[2].plot(tt, Yrec[:, cond == c].var(1, ddof=1), color=cols[c])
    ax[2].plot(tt, Ysim["MPC"][:, closed].var(1, ddof=1), color="#733399", lw=2)
    ax[2].plot(tt, Ysim["perfect"][:, closed].var(1, ddof=1), color="#c7a8e6", lw=2); ax[2].set_ylabel("across-trial variance")
    fig.savefig(FIG / f"mpc_direct_sine_{sess}{TAG}.png", dpi=150)

    savemat(DATA / f"mpc_direct_sine_{sess}{TAG}.mat", {
        "sim_names": np.array(list(sims), dtype=object), "cond": cond, "cond_names": np.array(NAMES, dtype=object),
        "on": on + 1, "fold": fold, "rmse_rec": rRec, "rmse_sim": np.column_stack([sims[n][1] for n in sims]),
        "Yrec": Yrec, "Urec": np.column_stack([ur[o:o + N] for o in on]), "R": Rw,
        "Ysim": np.stack([Ysim[n] for n in sims], 2), "Usim": np.stack([np.column_stack([s[1] for s in sims[n][0]]) for n in sims], 2),
        "Yx": np.stack([np.column_stack([s[2] for s in sims[n][0]]) for n in sims], 2),
        "Ux": np.stack([np.column_stack([s[3] for s in sims[n][0]]) for n in sims], 2),
        "Yrecx": np.column_stack([yr[o - EXT:o + N + EXT] for o in on]), "Urecx": np.column_stack([ur[o - EXT:o + N + EXT] for o in on]),
        "Rx": np.column_stack([rr[o - EXT:o + N + EXT] for o in on]),
        "summary": summary, "summary_rows": np.array(lab, dtype=object),
        "summary_cols": np.array(["median_rmse", "lag_deg", "gain", "mean_var", "n"], dtype=object),
        "G": world.G, "r2_86": r2[3], "r2_200": r2[7], "rd": RD, "oracle_rd": ORD, "Fs": Fs, "pre": pre, "ext": EXT,
        "N": N, "hz": hz, "umax": umax, "uss": uss})


if __name__ == "__main__":
    main(*sys.argv[1:])
