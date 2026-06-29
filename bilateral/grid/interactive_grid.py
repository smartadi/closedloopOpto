#!/usr/bin/env python
"""interactive_grid.py — click a site to set it as the STIM; every site then shows its
response (trial-MEAN ±SEM + TF-predicted) to stimulation at the clicked site, laid out at
its TRUE cortical position over the mean brain image.

Loads the cached TF fits (`tf_fit.py all`) + the brain cache (`cross_response.py brain`).
Each site's mini-plot sits at its real pixel location on the 560x560 mean image, so the
panel is a spatial map: click any site -> it becomes the stim site -> every panel redraws
its trial mean (blue) ±SEM (band) + LTI/TF prediction (orange) for that stim. Each panel
is labelled with the fitted MODEL ORDER (n = number of poles); the full poles & zeros per
readout are printed to the console on each click. Shared y-limits show amplitude falloff
with distance. Stim panel = red frame. The bottom-left
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
import matplotlib.patheffects as pe

DATA = Path(__file__).resolve().parents[2] / "data"
TF_CACHE = DATA / "grid_tf_fits.npz"
BRAIN_CACHE = DATA / "grid_brain.npz"


def poles_zeros(tau, A):
    """Poles and zeros of the fitted TF for one (stim,readout) pair.

    The model is H(s) = sum_i A_i / (s + 1/tau_i) — an all-pole sum-of-exponentials with
    residues. Poles are real at s = -1/tau_i. Re-expressed as N(s)/D(s) with
    D(s)=prod_i(s+1/tau_i), the numerator N(s)=sum_i A_i*prod_{j!=i}(s+1/tau_j) has degree
    n-1, so there are up to n-1 zeros (roots of N), generally complex. Units: 1/s.
    """
    tau = tau[~np.isnan(tau)]
    A = A[~np.isnan(A)]
    a = 1.0 / tau                      # 1/tau_i
    poles = -a
    n = len(a)
    if n <= 1:
        return poles, np.array([])
    ncoef = np.zeros(n)               # numerator, degree n-1 -> n coeffs
    for i in range(n):
        ncoef += A[i] * np.poly(-np.delete(a, i))   # prod_{j!=i}(s + a_j)
    return poles, np.roots(ncoef)


def corner_scale(ax, t0, ymax, dt=0.5):
    """L-shaped scale bar at the far lower-left of `ax` (drawn outside the panel):
    horizontal = dt seconds, vertical = ymax dF/F. Bold white labels with a dark stroke."""
    st = [pe.withStroke(linewidth=2.0, foreground="black")]
    x0, y0 = t0 - 0.08, -ymax * 1.10            # pushed down-and-left, beyond the panel
    ax.plot([x0, x0], [y0, y0 + ymax], c="white", lw=1.8, path_effects=st, clip_on=False)
    ax.plot([x0, x0 + dt], [y0, y0], c="white", lw=1.8, path_effects=st, clip_on=False)
    ax.text(x0 + dt / 2, y0 - ymax * 0.34, f"{dt:g} s", ha="center", va="top",
            fontsize=8, fontweight="bold", color="white", path_effects=st, clip_on=False)
    ax.text(x0 - dt * 0.28, y0 + ymax / 2, f"{ymax*100:.1f}%", ha="right", va="center",
            fontsize=8, fontweight="bold", color="white", rotation=90,
            path_effects=st, clip_on=False)


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
    gain, order, tau, A = z["gain"], z["order"], z["tau"], z["A"]
    bz = np.load(BRAIN_CACHE, allow_pickle=True)
    mimg, px, sp, ny, nx = bz["mimg"], bz["px"], float(bz["sp"]), int(bz["ny"]), int(bz["nx"])
    nS = len(sites)

    fig = plt.figure(figsize=(11, 11))
    bg = fig.add_axes([0, 0, 1, 1])
    bg.imshow(mimg, cmap="gray", extent=[0, nx, ny, 0], aspect="auto")
    bg.set_xlim(0, nx); bg.set_ylim(ny, 0); bg.axis("off")
    # mark every photostim/readout site location on the cortex
    bg.scatter(px[:, 0], px[:, 1], s=14, c="red", edgecolors="white", linewidths=0.4, zorder=3)

    w = (sp * 0.92) / nx
    h = (sp * 0.92) / ny
    fxy = np.column_stack([px[:, 0] / nx, 1.0 - px[:, 1] / ny])   # figure fractions
    axes, ax_site = {}, {}
    for j in range(nS):
        ax = fig.add_axes([fxy[j, 0] - w / 2, fxy[j, 1] - h / 2, w, h])
        axes[j] = ax; ax_site[ax] = j
    bl = int(np.argmin(fxy[:, 0] + fxy[:, 1]))                    # bottom-left panel

    # FIXED y-scale across all stim conditions + all panels (not adaptive), so amplitudes
    # are directly comparable everywhere.
    post = window >= 0
    YMAX = float(np.nanpercentile(np.abs(H[:, :, post]), 99.5)) or 0.01
    print(f"fixed y-scale: ±{YMAX:.4f} dF/F (global 99.5th pct of |response|)")

    state = {"stim": int(np.nanargmax(np.abs(gain[np.arange(nS), np.arange(nS)]))), "dot": None}

    def report(stim):
        """Print the fitted TF (order, poles, zeros) for every readout of this stim."""
        print(f"\n=== STIM ({sites[stim,0]:+.1f},{sites[stim,1]:+.0f}) - fitted TF per readout"
              f"  (poles & zeros in 1/s, sorted by |gain|) ===")
        print(f"{'readout':>12} {'order':>5} {'gain':>9}   poles | zeros")
        for r in np.argsort(-np.abs(gain[stim])):
            p, zr = poles_zeros(tau[stim, r], A[stim, r])
            ps = ", ".join(f"{v:.1f}" for v in p)
            zs = ", ".join((f"{v.real:.1f}" if abs(v.imag) < 1e-6
                            else f"{v.real:.1f}{v.imag:+.1f}j") for v in zr)
            print(f"  ({sites[r,0]:+.1f},{sites[r,1]:+.0f}) {int(order[stim,r]):>5} "
                  f"{gain[stim,r]:>9.4f}   [{ps}] | [{zs}]")

    def draw(stim):
        for j, ax in axes.items():
            ax.clear()
            ax.patch.set_alpha(0)                              # transparent (brain shows through)
            ax.axhline(0, c="0.6", lw=0.4, ls=":", alpha=0.7, zorder=1)   # faint dF/F=0 baseline
            ax.axvline(0, c="red", lw=0.9, zorder=1)           # stim onset (red), replaces y-axis
            ax.fill_between(window, H[stim, j] - Hsem[stim, j], H[stim, j] + Hsem[stim, j],
                            color="dodgerblue", alpha=0.25, lw=0)
            ax.plot(window, H[stim, j], c="dodgerblue", lw=0.9)
            ax.plot(window, yhat[stim, j], c="orange", lw=1.0, ls="--")
            ax.set_ylim(-YMAX, YMAX); ax.set_xticks([]); ax.set_yticks([])
            for spn in ax.spines.values():
                spn.set_visible(False)

            # model order (number of poles); poles/zeros printed to console on click
            ax.text(0.04, 0.96, f"n{int(order[stim, j])}", transform=ax.transAxes,
                    fontsize=6, va="top", ha="left", color="white",
                    path_effects=[pe.withStroke(linewidth=1.4, foreground="black")])

            if j == stim:
                for spn in ax.spines.values():
                    spn.set_visible(True); spn.set_color("red"); spn.set_linewidth(2.2)
                ax.text(0.5, 0.5, "STIM", transform=ax.transAxes, fontsize=7,
                        color="red", ha="center", va="center", alpha=0.7, weight="bold")
            if j == bl:
                corner_scale(ax, window[0], YMAX)

        # ring the currently-selected stim spot on the cortex
        if state["dot"] is not None:
            state["dot"].remove()
        state["dot"] = bg.scatter([px[stim, 0]], [px[stim, 1]], s=130, facecolors="none",
                                  edgecolors="red", linewidths=2.0, zorder=4)

        fig.suptitle(f"STIM ({sites[stim, 0]:+.1f}, {sites[stim, 1]:+.0f})   "
                     f"blue = trial mean ±SEM   orange = TF prediction   "
                     f"n = model order (poles/zeros → console)   [click a site to restim]",
                     fontsize=11, y=0.995)
        report(stim)
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
