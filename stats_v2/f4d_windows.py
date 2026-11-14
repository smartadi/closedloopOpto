"""Is the Fig 4d band-power state confounded by the controller? (Aditya, 2026-11-02)

sensitivity.py shows the loop reshapes the readout's spectrum (<1 Hz x0.32, 3-6 Hz x1.4-1.8), and
the Fig 4d power states are measured on that readout over [-2,+3) s, which also shares samples
with the 1-3 s RMSE they are regressed against. This re-runs the Fig 4d slopes (same y, z-scoring
and session test as run_all.py) with the state measured in other windows:

    peri  [-2,+3) s   locked window: must reproduce tests.csv exactly
    pre5  [-5, 0) s   laser off, no sample overlap, SAME length as peri (same estimator noise)
    pre2  [-2, 0) s   laser off, no sample overlap, the pre-stim part of peri
    stim  [ 0,+3) s   controller on, overlaps the RMSE window

Three questions:
  A. Does the loop shift the state's distribution? (CL - OL per window; pre windows must be ~0)
  B. Do trials keep their identity across onset? (within-session r of pre5 state with stim state,
     OL vs CL.) In CL, how much of the locked peri state is pre-stim, how much is during stim?
  C. Do the Fig 4d slopes survive when the controller cannot have touched the state?

The caches already carry m14's 11-frame dFk padding (utils/ctrl_onset_fix.m), so no dfk_offset.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/f4d_windows.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import matplotlib  # noqa: E402

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy import stats  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402
from tests import sess_test  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2" / "corrected"
FIG = loader.ROOT / "paper" / "images" / "figure4" / "supp"
WINS = {"peri": (-70, 104), "pre5": (-175, -1), "pre2": (-70, -1), "stim": (0, 104)}
STATES = ["rel_delta", "abs_delta", "motion"]
LABEL = {"rel_delta": "Relative 1–4 Hz", "abs_delta": "Absolute 1–4 Hz", "motion": "Motion"}
WIN_COL = {"peri": "k", "pre5": "#2ca02c", "pre2": "#98df8a", "stim": "#6a3d9a"}
WIN_LAB = {"peri": "[−2,+3) locked", "pre5": "[−5,0) laser off", "pre2": "[−2,0) laser off",
           "stim": "[0,+3) controller on"}


def state_value(s, st, o, rng):
    if st == "motion":
        if not s["has_motion"]:
            return np.nan
        seg = M.segment(s["motion"], o, rng)
        return float(np.mean(seg)) if np.all(np.isfinite(seg)) else np.nan
    seg = M.segment(s["dFk"], o, rng)
    if not np.all(np.isfinite(seg)):
        return np.nan
    if st == "rel_delta":  # 1-4 Hz since 2026-11-13 (Aditya: "Yes keep this"), as metrics.py
        return M.bandpower(seg, 1, 4) / M.bandpower(seg, 0.4, 10)
    return float(np.log10(M.bandpower(seg, 1, 4)))


def fisher_mean(r):
    return float(np.tanh(np.nanmean(np.arctanh(r))))


def main():
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}

    slopes, shift, ident = [], [], []
    min_gap = {}
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, onset_frames=onsets.get(sid))
        on = s["onset"]
        min_gap[sid] = float(np.min(np.diff(np.sort(on))) / M.FS)
        y = np.array([M.rmse(M.segment(s["dFk"], o, M.WINDOWS["late"]), s["ref"]) for o in on])
        ol, cl = s["cond"] == 0, s["cond"] == 1
        vals = {st: {w: np.array([state_value(s, st, o, rng) for o in on]) for w, rng in WINS.items()}
                for st in STATES}
        for st in STATES:
            if st == "motion" and not s["has_motion"]:
                continue
            for w in WINS:
                x = vals[st][w]
                ok = np.isfinite(x) & np.isfinite(y)
                z = np.full(x.shape, np.nan)
                z[ok] = M.zscore(x[ok])
                o_, c_ = ol & ok, cl & ok
                bl_o = M.ols_slope(z[o_], np.log(y[o_]))
                bl_c = M.ols_slope(z[c_], np.log(y[c_]))
                slopes.append({"session": sid, "mouse": s["mouse"], "state": st, "window": w,
                               "P": M.ols_slope(z[o_], y[o_]), "R": M.ols_slope(z[c_], y[c_]),
                               "A": bl_c - bl_o})
                sd = np.nanstd(x[ok], ddof=1)
                shift.append({"session": sid, "mouse": s["mouse"], "state": st, "window": w,
                              "shift_sd": (np.nanmean(x[c_]) - np.nanmean(x[o_])) / sd})
            for cname, m in (("OL", ol), ("CL", cl)):
                a, b, c = vals[st]["pre5"][m], vals[st]["stim"][m], vals[st]["peri"][m]
                k = np.isfinite(a) & np.isfinite(b) & np.isfinite(c)
                ident.append({"session": sid, "mouse": s["mouse"], "state": st, "cond": cname,
                              "r_pre_stim": stats.spearmanr(a[k], b[k])[0],
                              "r_peri_pre2": stats.spearmanr(vals[st]["pre2"][m][k], c[k])[0],
                              "r_peri_stim": stats.spearmanr(b[k], c[k])[0]})
        print(f"{sid}: min onset gap {min_gap[sid]:.1f} s", flush=True)

    sl = pd.DataFrame(slopes)
    sh = pd.DataFrame(shift)
    idn = pd.DataFrame(ident)

    rows = []
    for (st, w), g in sl.groupby(["state", "window"], sort=False):
        for q in ("P", "R", "A"):
            t = sess_test(g[q].to_numpy(), g["mouse"].to_numpy())
            rows.append({"state": st, "window": w, "q": q, "effect": t["effect"], "ci_lo": t["ci_lo"],
                         "ci_hi": t["ci_hi"], "p": t["p"], "wilcoxon_p": t["wilcoxon_p"], "k": t["k"],
                         "n": t["n"], "mouse_k": t["mouse_k"], "lomo_worst_p": t["lomo_worst_p"]})
    res = pd.DataFrame(rows)
    res.to_csv(OUT / "f4d_windows_slopes.csv", index=False)

    # sanity: the locked window must reproduce the run_all.py --corrected numbers
    ref = pd.read_csv(OUT / "tests.csv")
    ref = ref[(ref["figure"] == "fig4d") & ref["quantity"].isin(["P", "R", "A"])]
    print("\nCheck against tests.csv (peri):")
    for st in STATES:
        for q in ("P", "R", "A"):
            mine = res[(res.state == st) & (res.window == "peri") & (res.q == q)].iloc[0]
            theirs = ref[(ref["window_or_state"] == st) & (ref["quantity"] == q)].iloc[0]
            print(f"  {st:10s} {q}: p here {mine['p']:.6g}  tests.csv {theirs['p']:.6g}")

    pd.set_option("display.width", 200)
    fmt = lambda v: f"{v:.4g}"  # noqa: E731
    print(f"\nShortest gap between onsets: {min(min_gap.values()):.1f} s (stim 3 s; pre5 needs > 8 s)")
    print("\nA. CL - OL state shift (within-session SDs):")
    rs = []
    for (st, w), g in sh.groupby(["state", "window"], sort=False):
        t = sess_test(g["shift_sd"].to_numpy(), g["mouse"].to_numpy())
        rs.append({"state": st, "window": w, "shift_sd": t["effect"], "ci_lo": t["ci_lo"],
                   "ci_hi": t["ci_hi"], "p": t["p"], "k": t["k"], "n": t["n"]})
    rs = pd.DataFrame(rs)
    rs.to_csv(OUT / "f4d_windows_shift.csv", index=False)
    print(rs.to_string(index=False, float_format=fmt))

    print("\nB. Trial identity (Fisher-mean Spearman r over sessions):")
    ri = []
    for st, g in idn.groupby("state", sort=False):
        o = g[g.cond == "OL"].set_index("session")
        c = g[g.cond == "CL"].set_index("session")
        dz = np.arctanh(c["r_pre_stim"]) - np.arctanh(o["r_pre_stim"])
        t = sess_test(dz.to_numpy(), c["mouse"].to_numpy())
        ri.append({"state": st,
                   "r_pre5_stim_OL": fisher_mean(o["r_pre_stim"]), "r_pre5_stim_CL": fisher_mean(c["r_pre_stim"]),
                   "CLvsOL_p": t["p"], "k": t["k"], "n": t["n"], "sign": t["sign"],
                   "r_peri_pre2_OL": fisher_mean(o["r_peri_pre2"]), "r_peri_pre2_CL": fisher_mean(c["r_peri_pre2"]),
                   "r_peri_stim_OL": fisher_mean(o["r_peri_stim"]), "r_peri_stim_CL": fisher_mean(c["r_peri_stim"])})
    ri = pd.DataFrame(ri)
    ri.to_csv(OUT / "f4d_windows_identity.csv", index=False)
    print(ri.to_string(index=False, float_format=fmt))

    print("\nC. Fig 4d slopes by state window (P = OL slope, R = CL slope, A = log CL/OL slope):")
    print(res.to_string(index=False, float_format=fmt))

    # ---------------------------------------------------------------- forest plot
    fig, ax = plt.subplots(3, 3, figsize=(12, 7.5), constrained_layout=True, sharey=True)
    for i, st in enumerate(STATES):
        for j, (q, ttl) in enumerate((("P", "OL slope (%ΔF/F per SD)"), ("R", "CL slope (%ΔF/F per SD)"),
                                      ("A", "log CL/OL slope (per SD)"))):
            a = ax[i, j]
            for y_, w in enumerate(WINS):
                r = res[(res.state == st) & (res.window == w) & (res.q == q)].iloc[0]
                a.errorbar(r["effect"], -y_, xerr=[[r["effect"] - r["ci_lo"]], [r["ci_hi"] - r["effect"]]],
                           fmt="o", color=WIN_COL[w], capsize=2, ms=5)
                a.text(1.0, -y_, f"p={r['p']:.2g}", transform=a.get_yaxis_transform(), ha="right",
                       va="bottom", fontsize=7, color=WIN_COL[w])
            a.axvline(0, color="0.3", ls="--", lw=1)
            a.set_yticks(-np.arange(len(WINS)))
            a.set_yticklabels([WIN_LAB[w] for w in WINS])
            a.set_ylim(-len(WINS) + 0.4, 0.6)
            if i == 0:
                a.set_title(ttl)
            if j == 0:
                a.set_ylabel(LABEL[st])
    out = FIG / "f4d_state_windows.png"
    fig.savefig(out, dpi=300)
    print(f"\nwrote {out}")


if __name__ == "__main__":
    main()
