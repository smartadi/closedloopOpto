# -*- coding: utf-8 -*-
"""Site->readout transfer-function heterogeneity for the grant.
Pick one strong excitatory injection site and one strong inhibitory injection
site; for each, show the empirical response (solid) + fitted LTI transfer
function (dashed) at SEVERAL readout locations (the injection's strongest
efferent targets), ordered by distance. Demonstrates that one injection defines
a whole spatial family H_ij(s) with heterogeneous, well-fit shapes.

Output: grid_png/grid_tf_multireadout.png
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator
import numpy as np
import tf_fit
from pathlib import Path

OUT = Path(__file__).resolve().parent / "grid_png" / "grid_tf_multireadout.png"
z = np.load(tf_fit.CACHE_TF2, allow_pickle=True)
sites, amps, H, yhat, gain = z["sites"], z["amps"], z["H"], z["yhat"], z["gain"]
window = z["window"]
ai = len(amps) - 1                    # strongest amplitude
gi = gain[ai]

lateral = np.abs(sites[:, 0]) >= 1.5
exc = np.where((sites[:, 0] < 0) & lateral)[0]
inh = np.where((sites[:, 0] > 0) & lateral)[0]
s_exc = exc[np.argmax([gi[i, i] for i in exc])]
s_inh = inh[np.argmin([gi[i, i] for i in inh])]

K = 4                                  # readouts per injection (self + 3 targets)
RESP_FRAC = 0.06                       # a readout counts as "responsive" if |gain| >= this * self-gain
DIST_Q = (0.35, 0.68, 1.0)             # near / mid / far distance percentiles among responsive sites


def readouts(inj):
    """self + 3 efferent readouts SPREAD ACROSS DISTANCE (near/mid/far), not just
    the 3 strongest (which cluster right next to the injection). Readouts are kept
    ipsilateral (same hemisphere as the injection) so the family is not contaminated
    by the opposite-opsin hemisphere."""
    d = np.linalg.norm(sites - sites[inj], axis=1)
    g = np.abs(gi[inj])
    cand = [j for j in range(len(sites))
            if j != inj and d[j] > 0.01 and g[j] >= RESP_FRAC * g[inj]
            and sites[j, 0] * sites[inj, 0] > 0]
    cand = sorted(cand, key=lambda j: d[j])
    if len(cand) >= K - 1:
        picks = sorted({cand[int(round(q * (len(cand) - 1)))] for q in DIST_Q},
                       key=lambda j: d[j])
        # if percentile collisions gave < K-1 unique, backfill with farthest unused
        for j in reversed(cand):
            if len(picks) >= K - 1:
                break
            if j not in picks:
                picks.append(j)
        picks = sorted(picks, key=lambda j: d[j])[:K - 1]
    else:
        picks = cand
    idx = sorted([inj] + picks, key=lambda j: d[j])
    return idx, d


# colour convention matched to the A/B panel: excitatory = blue, inhibitory = red
cases = [(s_exc, "excitatory injection", "#3070b3"),
         (s_inh, "inhibitory injection", "#c02020")]

fig, axes = plt.subplots(2, K, figsize=(2.25 * K, 4.8), dpi=600, sharex=True)
for r, (inj, lab, col) in enumerate(cases):
    ro, d = readouts(inj)
    for c, j in enumerate(ro):
        ax = axes[r, c]
        ax.plot(window, H[ai, inj, j], color=col, lw=1.5)
        ax.plot(window, yhat[ai, inj, j], color=col, lw=1.1, ls="--")
        ax.axhline(0, c="0.75", lw=0.5)
        ax.axvline(0, c="0.75", lw=0.5)
        ax.set_xlim(-0.1, 0.6)
        ax.set_xticks([0, 0.3, 0.6])
        dd = d[j]
        # readout number (self = column 0) matches the numbered dots in panel A
        ax.set_title("self" if dd < 0.01 else f"{c} · {dd:.1f} mm",
                     fontsize=9)
        ax.yaxis.set_major_locator(MaxNLocator(3))
        ax.tick_params(labelsize=8)
        for sp in ["top", "right"]:
            ax.spines[sp].set_visible(False)
    axes[r, 0].set_ylabel(f"{lab}\n$\\Delta$F/F", fontsize=9.5)
for c in range(K):
    axes[1, c].set_xlabel("t (s)", fontsize=9)
axes[0, K - 1].plot([], [], "k-", lw=1.5, label="data")
axes[0, K - 1].plot([], [], "k--", lw=1.1, label="LTI fit")
axes[0, K - 1].legend(fontsize=8, frameon=False, loc="upper right",
                      handlelength=1.2, borderaxespad=0.2)
fig.tight_layout()
fig.savefig(OUT, dpi=600, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
