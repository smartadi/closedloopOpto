"""Reconcile the clean-room rebuild (data/stats_v2) against the old MATLAB pipeline's cached outputs.

Run after run_all.py. This script is NOT blind: it reads the old derived fields (data.nc/wc, data.er_*)
and the old per-session ratios, and writes data/stats_v2/RECONCILE.md.
"""
import os
import h5py
import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "stats_v2")
CACHES = {
    "m1": "AL_0033ctrl01203.mat", "m2": "AL_0033ctrl02122.mat", "m3": "AL_0033ctrl02242.mat",
    "m4": "AL_0033ctrl02262.mat", "m5": "AL_0033ctrl03041.mat", "m6": "AL_0033ctrl03052.mat",
    "m7": "AL_0033ctrl03204.mat", "m8": "AL_0033ctrl04152.mat", "m9": "AL_0039ctrl04201.mat",
    "m10": "AL_0039ctrl04191.mat", "m11": "AL_0039ctrl04303.mat", "m12": "AL_0033ctrl04191.mat",
    "m13": "AL_0039ctrl04202.mat", "m14": "AL_0048ctrl07292.mat", "m15": "AL_0051ctrl07292.mat",
}


def old_trials(sess):
    """Old pipeline's trial labels and full-window RMSE, from the cache's derived fields."""
    with h5py.File(os.path.join(ROOT, "data", CACHES[sess]), "r") as h:
        g = h["data"]
        rows = []
        for cond, idx, er in (("OL", "nc", "er_ncDfk"), ("CL", "wc", "er_wcDfk")):
            ii = np.asarray(g[idx]).ravel().astype(int)
            ee = np.asarray(g[er]).ravel()
            rows += [{"session": sess, "trial_index": i, "condition": cond, "old_rmse_full": e}
                     for i, e in zip(ii, ee)]
    return pd.DataFrame(rows)


def main():
    new = pd.read_csv(os.path.join(OUT, "trials.csv"))
    old = pd.concat([old_trials(s) for s in CACHES], ignore_index=True)
    m = new.merge(old, on=["session", "trial_index", "condition"], how="outer", indicator=True)
    lines = ["# Reconciliation: clean-room rebuild vs old pipeline caches", ""]

    lines += ["## Tier 1: trial sets and per-trial full-window RMSE", "",
              "| session | trials new | trials old | only new | only old | max abs RMSE diff | trials diff > 1e-6 |",
              "|---|---|---|---|---|---|---|"]
    for s in CACHES:
        ms = m[m.session == s]
        both = ms[ms._merge == "both"]
        d = (both.rmse_full - both.old_rmse_full).abs()
        lines.append(f"| {s} | {int((ms._merge != 'right_only').sum())} | {int((ms._merge != 'left_only').sum())} | "
                     f"{int((ms._merge == 'left_only').sum())} | {int((ms._merge == 'right_only').sum())} | "
                     f"{d.max():.2e} | {int((d > 1e-6).sum())} |")

    # Tier 2: per-session Fig 3 ratios vs the old ratio file (MATLAB v5 .mat, read via scipy).
    from scipy.io import loadmat
    R3 = loadmat(os.path.join(ROOT, "data", "fig3_ratio_stats.mat"), squeeze_me=True,
                 struct_as_record=False)["R3"]
    sf = pd.read_csv(os.path.join(OUT, "session_fig3.csv"))
    order = list(CACHES)  # the old file stores sessions in m1..m15 order
    lines += ["", "## Tier 2: per-session Fig 3 ratios (new / old)", "",
              "| metric | window | max abs diff | worst session | new | old |", "|---|---|---|---|---|---|"]
    for met, col in (("rmse", "rmse_ratio"), ("var", "var_ratio")):
        for w in ("pre", "early", "late", "full", "post"):
            o = np.asarray(getattr(getattr(R3, met), w).r, float).ravel()
            n = sf.set_index("session").loc[order, f"{col}_{w}"].to_numpy(float)
            k = int(np.nanargmax(np.abs(n - o)))
            lines.append(f"| {met} | {w} | {np.nanmax(np.abs(n - o)):.2e} | {order[k]} | {n[k]:.4f} | {o[k]:.4f} |")

    with open(os.path.join(OUT, "RECONCILE.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
