#!/usr/bin/env python
"""interactive_grid.py — click a site to set it as the STIM; every site then shows its
response (trial-MEAN ±SEM + TF-predicted) to stimulation at the clicked site, laid out at
its TRUE cortical position over the mean brain image.

Loads the cached TF fits (`tf_fit.py all`) + the brain cache (`cross_response.py brain`).
Each site's mini-plot sits at its real pixel location on the 560x560 mean image, so the
panel is a spatial map: click any site -> it becomes the stim site -> every panel redraws
its trial mean (blue) ±SEM (band) + LTI/TF prediction (orange) for that stim. Each panel
is annotated with a decay TIME CONSTANT (1/e fall time of the prediction, ms). Shared
y-limits show amplitude falloff with distance. Stim panel = red frame. The bottom-left
panel carries a corner scale bar (time + dF/F); all other panels are frameless.

Run (interactive):   .venv/Scripts/python.exe bilateral/grid/interactive_grid.py
Run (static PNG):     .venv/Scripts/python.exe bilateral/grid/interactive_grid.py save
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


def tau_decay(t, y):
    """Model-free decay time constant: time from the response peak until |y| falls to
    peak/e. Returns (tau_seconds, censored_bool). censored = no 1/e fall within window."""
    post = t >= 0
    tp, yp = t[post], y[post]
    k = int(np.argmax(np.abs(yp)))
    peak = yp[k]
    if abs(peak) < 1e-9 or k >= len(tp) - 3:   # flat, or still rising at window end
        return np.nan, False
    below = np.where(np.abs(yp[k:]) <= abs(peak) / np.e)[0]
    if len(below) == 0:
        return tp[-1] - tp[k], True
    return tp[k + below[0]] - tp[k], False


def corner_scale(ax, t0, ymax, dt=0.5):
    """Draw an L-shaped scale bar in the lower-left of `ax`: horizontal = dt seconds,
    vertical = ymax dF/F. Labels in s and %."""
    x0 = t0 + 0.04
    y0 = -ymax * 0.92
    ax.plot([x0, x0], [y0, y0 + ymax], c="k", lw=1.1)          # amplitude
    ax.plot([x0, x0 + dt], [y0, y0], c="k", lw=1.1)            # time
    ax.text(x0 + dt / 2, y0 - ymax * 0.14, f"{dt:g} s", ha="center", va="top", fontsize=6)
    ax.text(x0 - dt * 0.10, y0 + ymax / 2, f"{ymax*100:.2f}%", ha="right", va="center",
            fontsize=6, rotation=90)


def main():
    if not TF_CACHE.exists():
        raise SystemExit(f"{TF_CACHE} missing — run: "
                         f".venv/Scripts/python.exe bilateral/grid/tf_fit.py all")
    if not BRAIN_CACHE.exists():
        raise SystemExit(f"{BRAIN_CACHE} missing — run: "
                         f".venv/Scripts/python.exe bilateral/grid/cross_response.py brain")
    z = np.load(TF_CACHE, allow_pickle=True)
    H, yhat, sites, window = z["H"], z["yhat"], z["sites"], z["window"]
    Hsem = z["Hsem"] if "Hsem" in z.files else np.zeros_like(H)
    gain = z["gain"]
    bz = np.load(BRAIN_CACHE, allow_pickle=True)
    mimg, px, sp, ny, nx = bz["mimg"], bz["px"], float(bz["sp"]), int(bz["ny"]), int(bz["nx"])
    nS = len(sites)

    fig = plt.figure(figsize=(11, 11))
    bg = fig.add_axes([0, 0, 1, 1])
    bg.imshow(mimg, cmap="gray", extent=[0, nx, ny, 0], aspect="auto")
    bg.set_xlim(0, nx); bg.set_ylim(ny, 0); bg.axis("off")

    w = (sp * 0.92) / nx
    h = (sp * 0.92) / ny
    fxy = np.column_stack([px[:, 0] / nx, 1.0 - px[:, 1] / ny])   # figure fractions
    axes, ax_site = {}, {}
    for j in range(nS):
        ax = fig.add_axes([fxy[j, 0] - w / 2, fxy[j, 1] - h / 2, w, h])
        axes[j] = ax; ax_site[ax] = j
    bl = int(np.argmin(fxy[:, 0] + fxy[:, 1]))                    # bottom-left panel

    state = {"stim": int(np.nanargmax(np.abs(gain[np.arange(nS), np.arange(nS)])))}

    def draw(stim):
        post = window >= 0
        ymax = np.nanpercentile(np.abs(H[stim][:, post]), 99) * 1.05
        ymax = ymax if ymax > 0 else 0.01
        for j, ax in axes.items():
            ax.clear()
            ax.patch.set_facecolor("white"); ax.patch.set_alpha(0.5)
            ax.axhline(0, c="0.4", lw=0.3); ax.axvline(0, c="0.4", lw=0.3)
            ax.fill_between(window, H[stim, j] - Hsem[stim, j], H[stim, j] + Hsem[stim, j],
                            color="dodgerblue", alpha=0.25, lw=0)
            ax.plot(window, H[stim, j], c="dodgerblue", lw=0.9)
            ax.plot(window, yhat[stim, j], c="orange", lw=1.0, ls="--")
            ax.set_ylim(-ymax, ymax); ax.set_xticks([]); ax.set_yticks([])
            for spn in ax.spines.values():
                spn.set_visible(False)

            # time constant (only where there is real signal)
            if np.nanmax(np.abs(H[stim, j][post])) > 0.12 * ymax:
                td, cens = tau_decay(window, yhat[stim, j])
                if np.isfinite(td):
                    ax.text(0.04, 0.96, f"{'>' if cens else ''}{td*1000:.0f} ms",
                            transform=ax.transAxes, fontsize=5.5, va="top", ha="left",
                            c="0.15")

            if j == stim:
                for spn in ax.spines.values():
                    spn.set_visible(True); spn.set_color("red"); spn.set_linewidth(2.2)
                ax.text(0.5, 0.5, "STIM", transform=ax.transAxes, fontsize=7,
                        color="red", ha="center", va="center", alpha=0.7, weight="bold")
            if j == bl:
                corner_scale(ax, window[0], ymax)

        fig.suptitle(f"STIM ({sites[stim, 0]:+.1f}, {sites[stim, 1]:+.0f})   "
                     f"blue = trial mean ±SEM   orange = TF prediction   "
                     f"label = decay τ (1/e)   [click a site to restim]",
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
