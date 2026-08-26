"""State-dependence of closed-loop control -- grant figure (matches draft matplotlib style).

Two panels, pooled within-session quartiles over the mouse controller sessions:
  A  Motion quartile (all trials)          -- CL error FALLS at high movement (Q4)
  B  Pre-stimulus variance quartile        -- error RISES with ongoing variability, both loops
Numbers dumped headless from the MATLAB controller caches by talk/dump_state_control.m.
Red = open-loop, blue = closed-loop (project-locked control colors).
"""
import json, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SCRATCH = (r"C:\Users\aditya\AppData\Local\Temp\claude"
           r"\C--Users-aditya-Documents-projects-brain-paper"
           r"\69483c53-45a2-45f3-9e5d-0965ff7a6be0\scratchpad\state_control.json")
with open(SCRATCH) as f:
    D = json.load(f)

OL = "#e8000b"   # open-loop red
CL = "#1f77b4"   # closed-loop blue
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 11,
                     "axes.linewidth": 1.0, "svg.fonttype": "none"})

x = [1, 2, 3, 4]
xt = ["Q1\n(low)", "Q2", "Q3", "Q4\n(high)"]
panels = [("motion", "Movement quartile", "A", "all trials"),
          ("prevar", "Pre-stimulus variance quartile", "B", "motion-clean trials")]

fig, axes = plt.subplots(1, 2, figsize=(7.2, 3.1))
for ax, (key, xlab, tag, subset) in zip(axes, panels):
    d = D[key]
    ax.errorbar([xi - 0.06 for xi in x], d["mO"], d["sO"], fmt="o-", color=OL,
                lw=1.8, ms=5.5, capsize=3, mfc=OL, mec=OL, label="Open-loop")
    ax.errorbar([xi + 0.06 for xi in x], d["mC"], d["sC"], fmt="o-", color=CL,
                lw=1.8, ms=5.5, capsize=3, mfc="white", mec=CL, label="Closed-loop")
    ax.set_xticks(x); ax.set_xticklabels(xt)
    ax.set_xlim(0.5, 4.5)
    ax.set_xlabel(xlab)
    ax.spines[["top", "right"]].set_visible(False)
    ax.tick_params(direction="out", length=3)
    ax.set_title(f"{tag}", loc="left", fontweight="bold", fontsize=13)
    ax.text(0.5, 1.02, subset, transform=ax.transAxes, ha="center",
            va="bottom", fontsize=8.5, color="0.4")

axes[0].set_ylabel("Trial RMSE (%\u0394F/F)")
axes[0].legend(frameon=False, fontsize=9, loc="lower left",
               handlelength=1.4, borderaxespad=0.2)

fig.tight_layout(w_pad=2.0)
out = (r"C:\Users\aditya\Documents\projects\draft"
       r"\grant_2026_10_YazdanSteinmetz\figs2\ctrl_statedep.png")
fig.savefig(out, dpi=300, bbox_inches="tight")
print("wrote", out)
