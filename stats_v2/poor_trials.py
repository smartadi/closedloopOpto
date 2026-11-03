"""What does a poor closed-loop trial say about the controller? (Aditya, 2026-11-03)

  1. How much of the trial-to-trial variation in steady-state CL RMSE the Fig 4C states explain together
     (adjusted R^2 within session; the unique values should sit close to Fig 4C).
  2. Is a poor trial a lasting state? Log RMSE against the next CL trial and the nearest OL trial, within session.
  3. Command extremes on the recorded CL trials: are the poor trials the ones near the session's lowest or
     highest command? Frame-averaged as in sens_trials.py, so a pulse train and a step read alike.
  4. MPC replay of Mouse 1e (m4, one session, descriptive simulation): do the trials PI handled worst gain most
     from a forecast or from perfect prediction, what limits them, and does the link with each state weaken?

Read-only on the session caches, trials.csv and the MPC file. Prints only.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/poor_trials.py
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy import stats  # noqa: E402
from scipy.io import loadmat  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2" / "corrected"
MPC = loader.ROOT / "controller-analysis" / "data" / "mpc_direct_AL_0033_0226_e2_lam01_noCL.mat"
LATE = M.WINDOWS["late"]
NEAR_LOW = 0.02  # within this fraction of the session's top frame-averaged command above its lowest
NEAR_TOP = 0.90  # at or above this fraction of the session's top frame-averaged command


def adj_r2(y, X):
    n, k = len(y), X.shape[1]
    X1 = np.column_stack([np.ones(n), X])
    b = np.linalg.lstsq(X1, y, rcond=None)[0]
    res = y - X1 @ b
    return 1 - (res @ res / (n - k - 1)) / (((y - y.mean()) ** 2).sum() / (n - 1))


def sem(v):
    return np.std(v, ddof=1) / math.sqrt(len(v))


def state_model(tr):
    print("1. CL RMSE on the states, within session (face-video sessions)")
    for w in ("rmse_early", "rmse_late"):
        for pw in ("abs_delta", "rel_delta"):
            tot, uni = [], []
            for _, g in tr[tr.condition == "CL"].groupby("session", sort=False):
                g = g.dropna(subset=[w, "init_dev", "motion", pw])
                if len(g) < 8:
                    continue
                y, X = g[w].to_numpy(), g[["init_dev", "motion", pw]].to_numpy()
                t = adj_r2(y, X)
                tot.append(t)
                uni.append([t - adj_r2(y, np.delete(X, i, axis=1)) for i in range(3)])
            u = np.mean(uni, axis=0)
            print(f"   {w} with {pw}: {len(tot)} sessions, total adj R2 {np.mean(tot):.3f} +- {sem(tot):.3f} "
                  f"(range {min(tot):.2f} to {max(tot):.2f}); unique init {u[0]:.3f}, motion {u[1]:.3f}, power {u[2]:.3f}")


def neighbours(tr):
    print("2. Is a poor trial a lasting state? Log late RMSE, within session")
    rng = np.random.default_rng(1)
    out = {"next CL": [], "nearest OL": []}
    null = {"next CL": [], "nearest OL": []}
    for _, g in tr.groupby("session", sort=False):
        g = g.sort_values("trial_index")
        c, o = g[g.condition == "CL"], g[g.condition == "OL"]
        cy, ct = np.log(c.rmse_late.to_numpy()), c.trial_index.to_numpy()
        oy, ot = np.log(o.rmse_late.to_numpy()), o.trial_index.to_numpy()
        near = oy[np.abs(ct[:, None] - ot[None, :]).argmin(axis=1)]
        out["next CL"].append(np.corrcoef(cy[:-1], cy[1:])[0, 1])
        out["nearest OL"].append(np.corrcoef(cy, near)[0, 1])
        sh = [rng.permutation(cy) for _ in range(500)]
        null["next CL"].append(np.mean([np.corrcoef(s[:-1], s[1:])[0, 1] for s in sh]))
        null["nearest OL"].append(np.mean([np.corrcoef(s, near)[0, 1] for s in sh]))
    for k, v in out.items():
        t = stats.ttest_1samp(v, 0.0)
        print(f"   {k}: mean r {np.mean(v):+.3f} (shuffled {np.mean(null[k]):+.3f}), positive in {sum(x > 0 for x in v)}/{len(v)}, "
              f"t = {t.statistic:.2f}, p = {t.pvalue:.3f}")
    rs = [np.corrcoef(g.max_cmd, g.rmse_late)[0, 1] for _, g in tr[tr.condition == "CL"].groupby("session", sort=False)]
    print(f"   peak command (0-3 s) vs late RMSE in CL: mean r {np.mean(rs):+.3f}, range {min(rs):+.2f} to {max(rs):+.2f}, "
          f"positive in {sum(x > 0 for x in rs)}/{len(rs)}")


def cmd_frames(s, t0, n):
    i = np.searchsorted(s["inpTime"], t0 + s["dt_frame"] * np.arange(n + 1))
    return np.array([s["cmd"][a:b].mean() if b > a else np.nan for a, b in zip(i[:-1], i[1:])])


def command_extremes(tr):
    print("3. Command extremes, recorded CL trials, frames 35-105")
    rows = []
    for sid in loader.SESSION_IDS:
        t = tr[tr.session == sid].sort_values("val_index")
        s = loader.load_session(sid, onset_frames=t.onset_frame.to_numpy() - 1)
        cl = np.flatnonzero(s["cond"] == 1)
        U = np.array([cmd_frames(s, s["timeBlue"][s["onset"][j]], LATE[1] + 1) for j in cl])[:, LATE[0]:]
        top, low = np.nanmax(U), np.nanmin(U)
        at = np.nanmean(U < low + NEAR_LOW * top, axis=1) + np.nanmean(U >= NEAR_TOP * top, axis=1)
        g = t.iloc[cl].copy()
        g["at_ext"] = at
        g["worst"] = g.rmse_late >= g.rmse_late.quantile(0.75)
        rows.append(g)
    a = pd.concat(rows)
    w, r = a[a.worst], a[~a.worst]
    print(f"   trials with a frame at an extreme: all {(a.at_ext > 0).mean():.2f} ({len(a)}), worst quartile {(w.at_ext > 0).mean():.2f} ({len(w)}), "
          f"rest {(r.at_ext > 0).mean():.2f} ({len(r)})")
    print(f"   share of frames at an extreme: worst quartile {w.at_ext.mean():.3f}, rest {r.at_ext.mean():.3f}")
    rs = [np.corrcoef(g.at_ext, g.rmse_late)[0, 1] for _, g in a.groupby("session", sort=False)]
    print(f"   r(share of frames at an extreme, late RMSE): mean {np.mean(rs):+.3f}, range {min(rs):+.2f} to {max(rs):+.2f}, positive in {sum(x > 0 for x in rs)}/{len(rs)}")
    tot0, tot1, uni0, uni1 = [], [], [], []
    for _, g in a.groupby("session", sort=False):
        g = g.dropna(subset=["init_dev", "motion", "abs_delta"])
        if len(g) < 8:
            continue
        y, S, E = g.rmse_late.to_numpy(), g[["init_dev", "motion", "abs_delta"]].to_numpy(), g[["at_ext"]].to_numpy()
        t0, t1 = adj_r2(y, S), adj_r2(y, np.column_stack([S, E]))
        tot0.append(t0)
        tot1.append(t1)
        uni0.append(t0 - adj_r2(y, S[:, :2]))
        uni1.append(t1 - adj_r2(y, np.column_stack([S[:, :2], E])))
    print(f"   {len(tot0)} face-video sessions: total adj R2 {np.mean(tot0):.3f} -> {np.mean(tot1):.3f} with the extremes added; "
          f"unique abs power {np.mean(uni0):.3f} -> {np.mean(uni1):.3f}")


def mpc_trials(tr):
    print("4. MPC replay, Mouse 1e (m4), steady-state window")
    d = loadmat(MPC, squeeze_me=True, struct_as_record=False)
    R, Y, U, ref = d["rmse"], d["Y"], d["U"], float(d["ref"])
    pi, mpc, per = R[:, 0], R[:, 1], R[:, 2]
    print(f"   medians PI {np.median(pi):.2f}, MPC {np.median(mpc):.2f}, perfect {np.median(per):.2f}")
    m4 = tr[(tr.session == "m4") & (tr.condition == "CL")].sort_values("val_index")
    print(f"   file PI vs trials.csv late RMSE: Spearman {stats.spearmanr(pi, m4.rmse_late).statistic:.3f}")
    print(f"   Spearman PI vs MPC {stats.spearmanr(pi, mpc).statistic:.2f}, PI vs perfect {stats.spearmanr(pi, per).statistic:.2f}")
    q = pi >= np.quantile(pi, 0.75)
    for lab, m in (("worst PI quartile", q), ("rest", ~q)):
        print(f"   {lab} (n = {m.sum()}): median PI {np.median(pi[m]):.2f}, MPC {np.median(mpc[m]):.2f}, perfect {np.median(per[m]):.2f}; "
              f"MPC/PI {np.median(mpc[m] / pi[m]):.2f}, perfect/PI {np.median(per[m] / pi[m]):.2f}")
    print(f"   of the worst PI quartile, still in the worst MPC quartile: {(q & (mpc >= np.quantile(mpc, 0.75))).sum() / q.sum():.2f} (chance 0.25)")
    for c, n in enumerate(("PI", "MPC", "perfect")):
        e, u = Y[35:105, :, c] - ref, U[35:105, :, c]
        top = np.nanmax(U[:, :, c])
        for lab, m in (("worst", q), ("rest", ~q)):
            ee, uu = e[:, m], u[:, m]
            tot = (ee ** 2).sum()
            hi = (ee[(uu >= 0.98 * top) & (ee > 0)] ** 2).sum() / tot
            lo = (ee[(uu <= 0.02 * top) & (ee < 0)] ** 2).sum() / tot
            print(f"   {n:7s} {lab:5s}: squared error above target at the top {hi:.2f}, below target with the laser off {lo:.2f}, total at a limit {hi + lo:.2f}")
    print("   Spearman of trial RMSE with each state (PI | MPC | perfect):")
    for st in ("abs_delta", "rel_delta", "motion", "init_dev"):
        x = m4[st].to_numpy()
        print(f"     {st:10s} {stats.spearmanr(x, pi).statistic:+.2f} | {stats.spearmanr(x, mpc).statistic:+.2f} | {stats.spearmanr(x, per).statistic:+.2f}")


def main():
    tr = pd.read_csv(OUT / "trials.csv")
    state_model(tr)
    neighbours(tr)
    command_extremes(tr)
    mpc_trials(tr)


if __name__ == "__main__":
    main()
