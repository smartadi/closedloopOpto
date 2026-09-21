"""make_state_control_v2.py -- self-explanatory state-dependence-of-control-error figure.

Reads state_control_v2.json (per-trial CL/OL trial RMSE + within-session state
quartile for two states) and renders quartile VIOLINS so the reader directly
sees (i) closed loop lowers error, (ii) the error trend with state, and
(iii) the spread widening with state (heteroscedasticity).
"""
import json, numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

S = r"C:\Users\aditya\AppData\Local\Temp\claude\C--Users-aditya-Documents-projects-brain-paper\69483c53-45a2-45f3-9e5d-0965ff7a6be0\scratchpad"
OUT = r"C:\Users\aditya\Documents\projects\draft\grant_2026_10_YazdanSteinmetz\figs2\ctrl_statedep.png"

with open(S + r"\state_control_v2.json") as f:
    D = json.load(f)

OL = "#e8000b"; CL = "#1f77b4"
plt.rcParams.update({"font.size": 12, "font.weight": "bold", "axes.linewidth": 1.2,
                     "axes.labelweight": "bold", "svg.fonttype": "none"})

panels = [("motion", "Movement quartile", "all trials", "falls at high movement"),
          ("prevar", "Pre-stimulus variance quartile", "motion-clean trials", "rises with variability")]

fig, axes = plt.subplots(1, 2, figsize=(9.2, 3.6))

def viol(ax, q, y, x0, color):
    q = np.asarray(q); y = np.asarray(y)
    data = [y[q == b] for b in (1, 2, 3, 4)]
    pos = np.arange(4) + x0
    vp = ax.violinplot(data, positions=pos, widths=0.36, showextrema=False)
    for body in vp["bodies"]:
        body.set_facecolor(color); body.set_edgecolor(color)
        body.set_alpha(0.32); body.set_linewidth(0.8)
    med = [np.median(d) for d in data]
    ax.plot(pos, med, "-", color=color, lw=2.0, marker="o", ms=5, mec="w", mew=0.8, zorder=5)
    return med

for ax, (key, xlab, sub, trend) in zip(axes, panels):
    d = D[key]
    viol(ax, d["q_ol"], d["y_ol"], -0.19, OL)
    viol(ax, d["q_cl"], d["y_cl"], +0.19, CL)
    ax.set_xticks(range(4)); ax.set_xticklabels(["Q1\n(low)", "Q2", "Q3", "Q4\n(high)"])
    ax.set_xlabel(xlab)
    ax.set_title(sub, fontsize=11, color="0.35")
    ax.spines[["top", "right"]].set_visible(False)
    ax.margins(x=0.06)
axes[0].set_ylabel("Trial RMSE (%$\\Delta F/F$)")

# shared y-limits for comparability
lo = min(a.get_ylim()[0] for a in axes); hi = max(a.get_ylim()[1] for a in axes)
for a in axes: a.set_ylim(lo, hi)

handles = [Patch(facecolor=OL, alpha=0.4, edgecolor=OL, label="Open-loop"),
           Patch(facecolor=CL, alpha=0.4, edgecolor=CL, label="Closed-loop")]
axes[1].legend(handles=handles, loc="upper left", frameon=False, fontsize=10)

fig.tight_layout()
fig.savefig(OUT, dpi=300, bbox_inches="tight")
print("wrote", OUT)
for key, *_ in panels:
    d = D[key]
    q = np.asarray(d["q_cl"]); y = np.asarray(d["y_cl"])
    med = [float(np.median(y[q == b])) for b in (1, 4)]
    sd = [float(np.std(y[q == b])) for b in (1, 4)]
    print(f"  {key} CL median Q1->Q4 {med[0]:.2f}->{med[1]:.2f} | SD Q1->Q4 {sd[0]:.2f}->{sd[1]:.2f}")
