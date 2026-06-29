#!/usr/bin/env python
"""interactive_grid.py — click a site to set it as the STIM; every site then shows its
response (trial-avg + TF-predicted) to stimulation at the clicked site, laid out at its
TRUE cortical position over the mean brain image.

Loads the cached TF fits (`tf_fit.py all`) + the brain cache (`cross_response.py brain`).
Each site's mini-plot is placed at its real pixel location on the 560x560 mean image, so
the panel is a spatial map: click any site -> it becomes the stim site -> every panel
redraws its trial-avg dF/F (blue) + LTI/TF prediction (orange) for that stim condition.
Shared y-limits show how response amplitude falls off with distance. Stim panel = red.

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

DATA = Path(__file__).resolve().parents[2] / "data"
TF_CACHE = DATA / "grid_tf_fits.npz"
BRAIN_CACHE = DATA / "grid_brain.npz"


def main():
    if not TF_CACHE.exists():
        raise SystemExit(f"{TF_CACHE} missing — run: "
                         f".venv/Scripts/python.exe bilateral/grid/tf_fit.py all")
    if not BRAIN_CACHE.exists():
        raise SystemExit(f"{BRAIN_CACHE} missing — run: "
                         f".venv/Scripts/python.exe bilateral/grid/cross_response.py brain")
    z = np.load(TF_CACHE, allow_pickle=True)
    H, yhat, sites, window = z["H"], z["yhat"], z["sites"], z["window"]
    r2, gain = z["r2"], z["gain"]
    bz = np.load(BRAIN_CACHE, allow_pickle=True)
    mimg, px, sp, ny, nx = bz["mimg"], bz["px"], float(bz["sp"]), int(bz["ny"]), int(bz["nx"])
    nS = len(sites)

    # square figure; background axes fills it with the mean image (correct size)
    fig = plt.figure(figsize=(11, 11))
    bg = fig.add_axes([0, 0, 1, 1])
    bg.imshow(mimg, cmap="gray", extent=[0, nx, ny, 0], aspect="auto")
    bg.set_xlim(0, nx); bg.set_ylim(ny, 0); bg.axis("off")

    # one mini-axes per site, placed at its true pixel location (figure fractions)
    w = (sp * 0.92) / nx
    h = (sp * 0.92) / ny
    axes, ax_site = {}, {}
    for j, (cx, cy) in enumerate(px):
        fx, fy = cx / nx, 1.0 - cy / ny           # image y is top-down -> flip for figure
        ax = fig.add_axes([fx - w / 2, fy - h / 2, w, h])
        ax.patch.set_facecolor("white"); ax.patch.set_alpha(0.55)
        axes[j] = ax; ax_site[ax] = j

    diag = gain[np.arange(nS), np.arange(nS)]
    state = {"stim": int(np.nanargmax(np.abs(diag)))}

    def draw(stim):
        post = window >= 0
        ymax = np.nanpercentile(np.abs(H[stim][:, post]), 99) * 1.05
        ymax = ymax if ymax > 0 else 0.01
        for j, ax in axes.items():
            ax.clear()
            ax.patch.set_facecolor("white"); ax.patch.set_alpha(0.55)
            ax.axhline(0, c="0.4", lw=0.3); ax.axvline(0, c="0.4", lw=0.3)
            ax.plot(window, H[stim, j], c="dodgerblue", lw=0.8)
            ax.plot(window, yhat[stim, j], c="orange", lw=1.0, ls="--")
            ax.set_ylim(-ymax, ymax); ax.set_xticks([]); ax.set_yticks([])
            ax.text(0.04, 0.96, f"{r2[stim, j]:.2f}", transform=ax.transAxes,
                    fontsize=5, va="top", ha="left", c="0.25")
            red = (j == stim)
            for sp_ in ax.spines.values():
                sp_.set_color("red" if red else "0.7")
                sp_.set_linewidth(2.2 if red else 0.5)
            if red:
                ax.text(0.5, 0.5, "STIM", transform=ax.transAxes, fontsize=7,
                        color="red", ha="center", va="center", alpha=0.7, weight="bold")
        fig.suptitle(f"STIM ({sites[stim, 0]:+.1f}, {sites[stim, 1]:+.0f})   "
                     f"blue = trial-avg dF/F   orange = TF prediction   "
                     f"y = ±{ymax:.3f}   (number = R²)   [click a site to restim]",
                     fontsize=11, y=0.995)
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
