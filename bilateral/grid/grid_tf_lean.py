# -*- coding: utf-8 -*-
"""Lean LTI-fit exemplars for the grant: strongest excitatory self-response and
strongest inhibitory self-response, empirical impulse response (solid) + fitted
low-order LTI transfer function (dashed), at both laser amplitudes. Minimal text.

Output: grid_png/grid_tf_lean.png
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import tf_fit
from pathlib import Path

OUT = Path(__file__).resolve().parent / "grid_png" / "grid_tf_lean.png"
z = np.load(tf_fit.CACHE_TF2, allow_pickle=True)
sites, amps, H, yhat, gain = z["sites"], z["amps"], z["H"], z["yhat"], z["gain"]
window = z["window"]

lateral = np.abs(sites[:, 0]) >= 1.5
gi = gain[-1]
exc = np.where((sites[:, 0] < 0) & lateral)[0]
inh = np.where((sites[:, 0] > 0) & lateral)[0]
s_exc = exc[np.argmax([gi[i, i] for i in exc])]
s_inh = inh[np.argmin([gi[i, i] for i in inh])]

cases = [(s_exc, "excitatory site"), (s_inh, "inhibitory site")]
cols = ["#3070b3", "#c02020"]

fig, axes = plt.subplots(1, 2, figsize=(4.6, 2.3), dpi=300)
for ax, (s, lab) in zip(axes, cases):
    for ai, c in zip(range(len(amps)), cols):
        ax.plot(window, H[ai, s, s], c=c, lw=1.6, alpha=0.95)
        ax.plot(window, yhat[ai, s, s], c=c, lw=1.2, ls="--", alpha=0.95)
    ax.axhline(0, c="0.7", lw=0.5)
    ax.axvline(0, c="0.7", lw=0.5)
    ax.set_xlim(-0.1, 0.6)
    ax.set_xticks([0, 0.3, 0.6])
    ax.set_title(lab, fontsize=8.5)
    ax.set_xlabel("t (s)", fontsize=8)
    ax.tick_params(labelsize=7.5)
    for sp in ["top", "right"]:
        ax.spines[sp].set_visible(False)
axes[0].set_ylabel("ΔF/F", fontsize=8.5)
# one-line legend proxy
axes[1].plot([], [], "k-", lw=1.6, label="data")
axes[1].plot([], [], "k--", lw=1.2, label="LTI fit")
axes[1].legend(fontsize=7.5, frameon=False, loc="lower right",
               handlelength=1.3, borderaxespad=0.2)
fig.tight_layout(w_pad=1.2)
fig.savefig(OUT, dpi=300, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
