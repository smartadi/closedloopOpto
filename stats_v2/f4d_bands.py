"""Do the data single out relative 2-4 Hz and absolute 1-4 Hz? (Aditya, 2026-11-02)

Re-runs the Fig 4d slopes (same y, z-scoring and session test as run_all.py) with the band varied,
for absolute (log10 band power) and relative (band / 0.4-10 Hz) power, in the locked [-2,+3) s
window and the laser-off [-5,0) s window (same 175-sample length, see f4d_windows.py).

Also reports how the measures relate within a session: Spearman r with total 0.4-10 Hz power, and
each sub-band's share of the 1-4 Hz power.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/f4d_bands.py
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
from tests import holm, sess_test  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2" / "corrected"
FIG = loader.ROOT / "paper" / "images" / "figure4" / "supp"
WINS = {"peri": (-70, 104), "pre5": (-175, -1)}
WIN_COL = {"peri": "k", "pre5": "#2ca02c"}
WIN_LAB = {"peri": "[−2,+3) s locked", "pre5": "[−5,0) s laser off"}
FINE = [(0.4, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 10)]
WIDE = [(1, 4), (2, 4), (3, 6), (4, 10), (0.4, 10)]
ALL = FINE + WIDE
TOTAL = (0.4, 10)
REL_SKIP = {TOTAL}  # band / itself = 1


def name(b):
    return f"{b[0]:g}-{b[1]:g}"


def main():
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}

    rows, rel_rows, share_rows = [], [], []
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, onset_frames=onsets.get(sid))
        on = s["onset"]
        y = np.array([M.rmse(M.segment(s["dFk"], o, M.WINDOWS["late"]), s["ref"]) for o in on])
        ol, cl = s["cond"] == 0, s["cond"] == 1
        for w, rng in WINS.items():
            segs = [M.segment(s["dFk"], o, rng) for o in on]
            bp = {b: np.array([M.bandpower(x, *b) if np.all(np.isfinite(x)) else np.nan for x in segs])
                  for b in ALL}
            for kind in ("abs", "rel"):
                for b in ALL:
                    if kind == "rel" and b in REL_SKIP:
                        continue
                    x = np.log10(bp[b]) if kind == "abs" else bp[b] / bp[TOTAL]
                    ok = np.isfinite(x) & np.isfinite(y)
                    z = np.full(x.shape, np.nan)
                    z[ok] = M.zscore(x[ok])
                    o_, c_ = ol & ok, cl & ok
                    rows.append({"session": sid, "mouse": s["mouse"], "kind": kind, "band": name(b),
                                 "window": w, "P": M.ols_slope(z[o_], y[o_]), "R": M.ols_slope(z[c_], y[c_]),
                                 "A": M.ols_slope(z[c_], np.log(y[c_])) - M.ols_slope(z[o_], np.log(y[o_]))})
            lt = np.log10(bp[TOTAL])
            for cname, m in (("OL", ol), ("CL", cl)):
                k = m & np.isfinite(lt)
                rel_rows.append({
                    "session": sid, "window": w, "cond": cname,
                    "abs14_total": stats.spearmanr(np.log10(bp[(1, 4)])[k], lt[k])[0],
                    "abs24_total": stats.spearmanr(np.log10(bp[(2, 4)])[k], lt[k])[0],
                    "abs14_abs24": stats.spearmanr(np.log10(bp[(1, 4)])[k], np.log10(bp[(2, 4)])[k])[0],
                    "rel24_total": stats.spearmanr((bp[(2, 4)] / bp[TOTAL])[k], lt[k])[0],
                    "rel24_abs14": stats.spearmanr((bp[(2, 4)] / bp[TOTAL])[k], np.log10(bp[(1, 4)])[k])[0],
                    "rel24_abs24": stats.spearmanr((bp[(2, 4)] / bp[TOTAL])[k], np.log10(bp[(2, 4)])[k])[0],
                })
                t14 = np.nanmean(bp[(1, 4)][k])
                share_rows.append({"session": sid, "window": w, "cond": cname,
                                   "s12": np.nanmean(bp[(1, 2)][k]) / t14,
                                   "s23": np.nanmean(bp[(2, 3)][k]) / t14,
                                   "s34": np.nanmean(bp[(3, 4)][k]) / t14,
                                   "s14_of_total": t14 / np.nanmean(bp[TOTAL][k])})
        print(sid, flush=True)

    sl = pd.DataFrame(rows)
    res = []
    for (kind, band, w), g in sl.groupby(["kind", "band", "window"], sort=False):
        for q in ("P", "R", "A"):
            t = sess_test(g[q].to_numpy(), g["mouse"].to_numpy())
            res.append({"kind": kind, "band": band, "window": w, "q": q, "effect": t["effect"],
                        "ci_lo": t["ci_lo"], "ci_hi": t["ci_hi"], "p": t["p"], "k": t["k"], "n": t["n"],
                        "mouse_k": t["mouse_k"], "lomo_worst_p": t["lomo_worst_p"]})
    res = pd.DataFrame(res)
    res["p_holm_fine"] = np.nan
    fine = [name(b) for b in FINE]
    for (kind, w, q), g in res[res.band.isin(fine)].groupby(["kind", "window", "q"]):
        res.loc[g.index, "p_holm_fine"] = holm(g["p"].to_numpy())
    res.to_csv(OUT / "f4d_bands.csv", index=False)

    pd.set_option("display.width", 200)
    for kind in ("abs", "rel"):
        for w in WINS:
            sub = res[(res.kind == kind) & (res.window == w)]
            piv = []
            for b in [name(x) for x in ALL]:
                g = sub[sub.band == b]
                if g.empty:
                    continue
                r = {q: g[g.q == q].iloc[0] for q in ("P", "R", "A")}
                piv.append({"band": b,
                            "OL": f"{r['P'].effect:+.2f}", "p_OL": f"{r['P'].p:.3g}",
                            "CL": f"{r['R'].effect:+.2f}", "p_CL": f"{r['R'].p:.3g}", "k_CL": r['R'].k,
                            "CL/OL%": f"{100 * (np.exp(r['A'].effect) - 1):+.1f}", "p_A": f"{r['A'].p:.3g}",
                            "k_A": r['A'].k})
            print(f"\n{kind} power, window {w}: slopes per SD (fine bands first, then composites)")
            print(pd.DataFrame(piv).to_string(index=False))

    rl = pd.DataFrame(rel_rows)
    cols = ["abs14_total", "abs24_total", "abs14_abs24", "rel24_total", "rel24_abs14", "rel24_abs24"]
    print("\nFisher-mean within-session Spearman r:")
    print(rl.groupby(["window", "cond"])[cols].agg(lambda v: np.tanh(np.nanmean(np.arctanh(v))))
          .round(2).to_string())
    print("\nShare of 1-4 Hz power by sub-band, and 1-4 Hz share of 0.4-10 Hz (session means):")
    print(pd.DataFrame(share_rows).groupby(["window", "cond"])[["s12", "s23", "s34", "s14_of_total"]]
          .mean().round(2).to_string())

    # ---------------------------------------------------------------- figure
    fc = [(b[0] + b[1]) / 2 for b in FINE]
    fig, ax = plt.subplots(2, 3, figsize=(13, 6.2), constrained_layout=True, sharex=True)
    lab = {"P": "OL slope (%ΔF/F per SD)", "R": "CL slope (%ΔF/F per SD)", "A": "CL/OL slope (log, per SD)"}
    for i, (kind, ttl) in enumerate((("abs", "Absolute power"), ("rel", "Relative power"))):
        for j, q in enumerate(("P", "R", "A")):
            a = ax[i, j]
            for w in WINS:
                g = res[(res.kind == kind) & (res.window == w) & (res.q == q)].set_index("band").reindex(fine)
                e = g["effect"].to_numpy()
                a.errorbar(fc, e, yerr=[e - g["ci_lo"].to_numpy(), g["ci_hi"].to_numpy() - e], fmt="o-",
                           color=WIN_COL[w], ms=4, lw=1, capsize=2, label=WIN_LAB[w])
            a.axhline(0, color="0.3", ls="--", lw=1)
            a.axvspan(1, 4, color="0.92", zorder=0)
            a.set_xscale("log")
            a.set_xticks([0.5, 1, 2, 4, 8])
            a.set_xticklabels(["0.5", "1", "2", "4", "8"])
            if i == 0:
                a.set_title(lab[q])
            if j == 0:
                a.set_ylabel(ttl)
            if i == 1:
                a.set_xlabel("Band centre (Hz)")
    ax[0, 0].legend(frameon=False, fontsize=8)
    out = FIG / "f4d_band_grid.png"
    fig.savefig(out, dpi=300)
    print(f"\nwrote {out}")


if __name__ == "__main__":
    main()
