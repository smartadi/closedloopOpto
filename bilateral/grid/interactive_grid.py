#!/usr/bin/env python
"""interactive_grid.py — click a site to set it as the STIM; every site then shows its
response (trial-avg + TF-predicted) to stimulation at the clicked site.

Loads the cached TF fits (run `tf_fit.py all` first). Opens an interactive window laid
out in the 8x8 brain grid: each cell is one readout site. Click any cell -> that site
becomes the stimulation site -> all 52 cells redraw to show H[stim, r] (blue, trial-avg
dF/F) and the LTI/TF prediction (orange) for that stim condition. The stim cell is
outlined in red; shared y-limits show how the response amplitude falls off with distance.

Run (interactive):
    .venv/Scripts/python.exe bilateral/grid/interactive_grid.py
Run (dump a static preview PNG for the default stim site, no window):
    .venv/Scripts/python.exe bilateral/grid/interactive_grid.py save
"""
import sys
from pathlib import Path

import numpy as np

SAVE = "save" in sys.argv
import matplotlib
if SAVE:
    matplotlib.use("Agg")
else:
    for _bk in ("TkAgg", "QtAgg", "Qt5Agg"):
        try:
            matplotlib.use(_bk); break
        except Exception:
            continue
import matplotlib.pyplot as plt

CACHE = Path(__file__).resolve().parents[2] / "data" / "grid_tf_fits.npz"


def _rc(mx, my):
    """8x8 subplot (row, col) for a grid site — same layout as the other grid figures."""
    return int(round(3 - my)), int(round(mx + 3.5))


def main():
    if not CACHE.exists():
        raise SystemExit(f"{CACHE} missing — run: "
                         f".venv/Scripts/python.exe bilateral/grid/tf_fit.py all")
    z = np.load(CACHE, allow_pickle=True)
    H, yhat, sites, window = z["H"], z["yhat"], z["sites"], z["window"]
    r2, gain = z["r2"], z["gain"]
    nS = len(sites)

    fig = plt.figure(figsize=(12, 10))
    gs = fig.add_gridspec(8, 8, wspace=0.15, hspace=0.30)
    axes, ax_site = {}, {}
    for j, (mx, my) in enumerate(sites):
        ax = fig.add_subplot(gs[_rc(mx, my)])
        axes[j] = ax
        ax_site[ax] = j

    diag = gain[np.arange(nS), np.arange(nS)]
    state = {"stim": int(np.nanargmax(np.abs(diag)))}

    def draw(stim):
        post = window >= 0
        ymax = np.nanpercentile(np.abs(H[stim][:, post]), 99) * 1.05
        ymax = ymax if ymax > 0 else 0.01
        for j, (mx, my) in enumerate(sites):
            ax = axes[j]; ax.clear()
            ax.axhline(0, c="k", lw=0.3, ls="--"); ax.axvline(0, c="grey", lw=0.3)
            ax.plot(window, H[stim, j], c="dodgerblue", lw=0.8)
            ax.plot(window, yhat[stim, j], c="orange", lw=1.0, ls="--")
            ax.set_ylim(-ymax, ymax); ax.set_xticks([]); ax.set_yticks([])
            for sp in ax.spines.values():
                sp.set_color("0.8"); sp.set_linewidth(0.5)
            if j == stim:
                for sp in ax.spines.values():
                    sp.set_color("red"); sp.set_linewidth(2.0)
                ax.set_title("STIM", color="red", fontsize=7, pad=1)
            else:
                ax.set_title(f"R²={r2[stim, j]:.2f}", fontsize=6, pad=1)
        fig.suptitle(f"STIM site ({sites[stim, 0]:+.1f}, {sites[stim, 1]:+.0f})   "
                     f"blue = trial-avg dF/F   orange = TF prediction   "
                     f"y = ±{ymax:.3f}    [click any cell to restim]", fontsize=12)
        fig.canvas.draw_idle()

    draw(state["stim"])

    if SAVE:
        out = Path(__file__).resolve().parent / "grid_png" / "interactive_preview.png"
        out.parent.mkdir(exist_ok=True)
        fig.savefig(out, dpi=130)
        print("wrote", out)
        return

    def onclick(event):
        if event.inaxes in ax_site:
            state["stim"] = ax_site[event.inaxes]
            draw(state["stim"])

    fig.canvas.mpl_connect("button_press_event", onclick)
    plt.show()


if __name__ == "__main__":
    main()
