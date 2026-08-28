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

K = 5                                  # readouts per injection (self + 4 targets)


def readouts(inj):
    d = np.linalg.norm(sites - sites[inj], axis=1)
    others = [j for j in np.argsort(-np.abs(gi[inj])) if j != inj][:K - 1]
    idx = sorted([inj] + others, key=lambda j: d[j])
    return idx, d


cases = [(s_exc, "excitatory injection", "#c02020"),
         (s_inh, "inhibitory injection", "#3070b3")]

fig, axes = plt.subplots(2, K, figsize=(2.05 * K, 4.3), dpi=300, sharex=True)
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
        dx, dy = sites[j] - sites[inj]
        ax.set_title("self" if dd < 0.01 else f"{dd:.1f} mm  ({dx:+.0f},{dy:+.0f})",
                     fontsize=7.5)
        ax.tick_params(labelsize=7)
        for sp in ["top", "right"]:
            ax.spines[sp].set_visible(False)
    axes[r, 0].set_ylabel(f"{lab}\n$\\Delta$F/F", fontsize=8.5)
for c in range(K):
    axes[1, c].set_xlabel("t (s)", fontsize=8)
axes[0, K - 1].plot([], [], "k-", lw=1.5, label="data")
axes[0, K - 1].plot([], [], "k--", lw=1.1, label="LTI fit")
axes[0, K - 1].legend(fontsize=7, frameon=False, loc="upper right",
                      handlelength=1.2, borderaxespad=0.2)
fig.suptitle(f"Site$\\rightarrow$readout transfer functions at increasing distance "
             f"(amp {amps[ai]:.1f}; data solid, LTI fit dashed)", fontsize=9)
fig.tight_layout()
fig.savefig(OUT, dpi=300, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
