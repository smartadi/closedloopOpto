"""Cluster permutation test across frequency of the CL - OL difference in the high/low state spectra
(Fig 4E). Hub #92, 2026-11-18.

Math approved by Aditya 2026-11-18: "Approve" (Hub control method block "test both Fig 4E observations
with a cluster permutation test across frequency on the per-session CL-OL difference, in the locked
window, with a laser-off run as the check"; RESEARCH L-2026-11-18-b). Method after Maris and
Oostenveld 2007, J Neurosci Methods 164:177-190, doi 10.1016/j.jneumeth.2007.03.024 (cluster mass,
max statistic over the permutations).
A cluster's edges are not tested (Sassenhagen and Draschkow 2019, Psychophysiology 56(6),
doi 10.1111/psyp.13335).

For session s with both conditions, condition c (OL, CL), state k, frequency f in [0.5, 8] Hz:
    R_sc(f) = P_Q4(f) / P_Q1(f)      same P and quartiles as state_spectra_tests.py (quartile_spectra)
    d_s(f)  = ln R_s,CL(f) - ln R_s,OL(f)
    t(f)    = mean_s d_s(f) / (SD_s d_s(f) / sqrt(n))
    cluster = run of adjacent frequencies with |t(f)| > t_0.975,n-1 and the same sign; mass M = sum of t
    null    = every one of the 2^n patterns that flips the sign of whole d_s curves; for each, the
              largest |M| over its clusters (0 if none). Cluster p = fraction of patterns with largest
              |M| >= the cluster's |M| (the identity pattern included, so p >= 2 / 2^n).
    Holm    over the 2 states within a window: a state's p is its smallest cluster p (1 if no cluster);
            each cluster p is multiplied by its state's Holm factor (2 for the state with the smaller p,
            1 for the other, not below the first state's adjusted p).
    k/n     sessions whose mean d over the cluster has the cluster's sign (descriptive: the cluster was
            found in the same data).
Run on the locked [-2,+3) s state window (the figure) and on laser-off [-5,0) s (the check: there the
CL controller cannot change the state value that sorts the trials).

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/state_spectra_cluster.py
OUT  data/stats_v2/corrected/state_spectra_clusters.csv  (one row per cluster, or one row per state
                                                          and window with no cluster)
     data/stats_v2/corrected/state_spectra_cluster_t.csv (t(f) and CL/OL = exp(mean d) per frequency)
"""
import itertools
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy import stats  # noqa: E402

import loader  # noqa: E402
from sensitivity import FREQ  # noqa: E402
from state_spectra import OUT, condition_spectra  # noqa: E402
from state_spectra_tests import TESTED, WINDOWS, quartile_spectra  # noqa: E402

F_LO, F_HI = 0.5, 8.0
FSEL = (FREQ >= F_LO) & (FREQ <= F_HI)


def clusters(t, tcrit):
    """[(i0, i1, mass)] for runs of |t| > tcrit with one sign (i1 inclusive)."""
    out = []
    for sgn in (1, -1):
        above = np.concatenate([[False], sgn * t > tcrit, [False]])
        d = np.diff(above.astype(int))
        for i0, i1 in zip(np.where(d == 1)[0], np.where(d == -1)[0] - 1):
            out.append((int(i0), int(i1), float(t[i0:i1 + 1].sum())))
    return sorted(out, key=lambda c: c[0])


def t_curve(D):
    """One-sample t across rows of D (sessions x freq); nan where the SD is 0."""
    n = D.shape[0]
    m = D.mean(axis=0)
    sd = D.std(axis=0, ddof=1)
    with np.errstate(divide="ignore", invalid="ignore"):
        return m / (sd / np.sqrt(n))


def cluster_test(D):
    """Exact sign-flip cluster test. Returns (t, tcrit, [(i0, i1, mass, p)], null max |M|)."""
    n = D.shape[0]
    tcrit = float(stats.t.ppf(0.975, n - 1))
    t = t_curve(D)
    obs = clusters(t, tcrit)
    # t under each flip pattern from sums: flipping signs leaves sum(d^2) unchanged
    S = np.array(list(itertools.product((1.0, -1.0), repeat=n)))       # 2^n x n
    mean = S @ D / n
    ss = (D ** 2).sum(axis=0)
    with np.errstate(divide="ignore", invalid="ignore"):
        T = mean / np.sqrt((ss - n * mean ** 2) / (n - 1) / n)
    T = np.nan_to_num(T, nan=0.0)
    assert np.allclose(T[0], np.nan_to_num(t, nan=0.0))   # row 0 is the identity pattern
    null = np.array([max([abs(c[2]) for c in clusters(row, tcrit)], default=0.0) for row in T])
    # relative tolerance: the identity row repeats the observed mass up to rounding
    out = [(i0, i1, mass, float(np.mean(null >= abs(mass) * (1 - 1e-9)))) for i0, i1, mass in obs]
    return t, tcrit, out, null


def checks():
    rng = np.random.default_rng(0)
    # all-zero curves: no cluster
    t, _, cl, _ = cluster_test(np.zeros((11, 50)))
    assert cl == [], cl
    # planted effect in columns 20-29 of 11 sessions: one positive cluster there at the smallest p
    D = rng.normal(0, 0.05, (11, 50))
    D[:, 20:30] += 1.0
    _, _, cl, _ = cluster_test(D)
    big = max(cl, key=lambda c: abs(c[2]))
    assert (big[0], big[1]) == (20, 29) and big[2] > 0 and abs(big[3] - 2 / 2 ** 11) < 1e-12, cl
    # the fast t under flips equals scipy's t for one flip pattern
    s = rng.choice([-1.0, 1.0], 11)
    D = rng.normal(0.2, 1, (11, 30))
    S = np.array(list(itertools.product((1.0, -1.0), repeat=11)))
    row = int(np.where((S == s).all(axis=1))[0][0])
    mean = S[row] @ D / 11
    T = mean / np.sqrt(((D ** 2).sum(axis=0) - 11 * mean ** 2) / 10 / 11)
    assert np.allclose(T, stats.ttest_1samp(s[:, None] * D, 0).statistic)
    print("checks passed: zero curves give no cluster; planted 20-29 cluster found at p = 2/2^11; "
          "flip t matches scipy")


def main():
    checks()
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    sess = [loader.load_session(sid, onset_frames=onsets.get(sid)) for sid in loader.SESSION_IDS]
    spectra = [condition_spectra(s) for s in sess]
    curves = pd.read_csv(OUT / "state_spectra_curves.csv")
    f = FREQ[FSEL]

    rows, trows = [], []
    for wname, rng in WINDOWS.items():
        fam = {}
        for st in TESTED:
            lnR = {"OL": [], "CL": []}
            D = []
            for s, sp in zip(sess, spectra):
                if st == "motion" and not s["has_motion"]:
                    continue
                q = quartile_spectra(s, sp, st, rng)
                for c in ("OL", "CL"):
                    if q[c] is not None:
                        lnR[c].append(np.log(q[c][1]) - np.log(q[c][0]))
                if q["OL"] is not None and q["CL"] is not None:
                    D.append((np.log(q["CL"][1]) - np.log(q["CL"][0]) - np.log(q["OL"][1]) + np.log(q["OL"][0]))[FSEL])
            # check: per-condition session means reproduce the saved group curves
            for c in ("OL", "CL"):
                cv = curves[(curves.window == wname) & (curves.state == st) & (curves.cond == c)]
                assert np.allclose(cv.freq.to_numpy(), FREQ)
                err = np.max(np.abs(np.mean(lnR[c], axis=0) - np.log(cv.ratio.to_numpy())))
                assert err < 1e-9, (wname, st, c, err)
            D = np.array(D)
            t, tcrit, cl, null = cluster_test(D)
            fam[st] = (D, t, tcrit, cl)
            print(f"{wname:20s} {st:7s}: {D.shape[0]} paired sessions, {len(f)} frequencies, t crit {tcrit:.3f}, "
                  f"{2 ** D.shape[0]} patterns, curves reproduced")
            for fi, ti, di in zip(f, t, D.mean(axis=0)):
                trows.append({"window": wname, "state": st, "freq": fi, "t": ti, "cl_ol": np.exp(di),
                              "n": D.shape[0], "t_crit": tcrit})
        # Holm over the 2 states
        sp_ = {st: min([c[3] for c in v[3]], default=1.0) for st, v in fam.items()}
        order = sorted(sp_, key=sp_.get)
        mult = {order[0]: 2, order[1]: 1}
        floor = {order[0]: 0.0, order[1]: min(1.0, 2 * sp_[order[0]])}
        for st, (D, t, tcrit, cl) in fam.items():
            if not cl:
                rows.append({"window": wname, "state": st, "n": D.shape[0], "cluster": 0})
            for j, (i0, i1, mass, p) in enumerate(cl, 1):
                md = D[:, i0:i1 + 1].mean(axis=1)
                sgn = np.sign(mass)
                rows.append({"window": wname, "state": st, "n": D.shape[0], "cluster": j,
                             "f_lo": f[i0], "f_hi": f[i1], "n_freq": i1 - i0 + 1,
                             "sign": "CL>OL" if sgn > 0 else "CL<OL", "mass": mass,
                             "cl_ol": float(np.exp(D[:, i0:i1 + 1].mean())), "p": p,
                             "p_holm": min(1.0, max(mult[st] * p, floor[st])),
                             "k": int(np.sum(np.sign(md) == sgn))})
    tab = pd.DataFrame(rows)
    tab.to_csv(OUT / "state_spectra_clusters.csv", index=False)
    pd.DataFrame(trows).to_csv(OUT / "state_spectra_cluster_t.csv", index=False)
    with pd.option_context("display.width", 200, "display.max_rows", 100):
        print(tab.to_string(index=False, float_format=lambda x: f"{x:.3g}"))
    print(f"wrote {OUT / 'state_spectra_clusters.csv'} and state_spectra_cluster_t.csv")


if __name__ == "__main__":
    main()
