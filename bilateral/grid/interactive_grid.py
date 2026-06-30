#!/usr/bin/env python
"""interactive_grid.py — interactive perturbation-response explorer over the brain.

THREE linked windows, driven by clicks:
  • EFFERENT (primary brain map): click a node X -> every site shows H[X, ·], the
    trial-mean dF/F response to stimulating X (thick blue), ±2 SD band (faint),
    TF prediction (orange), model-order label, red stim line at t=0. The SAME click also
    refreshes the afferent map below. Poles/zeros printed to the console.
  • AFFERENT (2nd brain map): keyed off the same X -> column H[·, X]: each site Y shows
    X's trial-mean response WHEN Y was stimmed. X's own panel framed red. Click any node Y
    on THIS map ->
  • TRIALS (3rd window): a 10×5 grid of every individual trial for (stim Y -> readout X),
    each with the trial mean overlaid (same mean as the brain map) — the averaging check.
    The inspected Y is framed green on the afferent map.

Data: cached TF fits (`tf_fit.py all`) + brain image (`cross_response.py brain`) +
ROI time-series (`cross_response.py`, the trials cache). Single trials reconstruct with
no network read.

Run (interactive):   .venv/Scripts/python.exe bilateral/grid/interactive_grid.py
Run (static PNGs):    .venv/Scripts/python.exe bilateral/grid/interactive_grid.py save
Set display window:   ... interactive_grid.py --xlim -1 1
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

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cross_response as cr

DATA = Path(__file__).resolve().parents[2] / "data"
TF_CACHE = DATA / "grid_tf_fits.npz"
BRAIN_CACHE = DATA / "grid_brain.npz"
ST = [pe.withStroke(linewidth=2.0, foreground="black")]


def poles_zeros(tau, A):
    """Poles (-1/tau, real) and zeros (roots of the residue numerator) of the TF, in 1/s."""
    tau = tau[~np.isnan(tau)]; A = A[~np.isnan(A)]
    a = 1.0 / tau
    if len(a) <= 1:
        return -a, np.array([])
    nco = np.zeros(len(a))
    for i in range(len(a)):
        nco += A[i] * np.poly(-np.delete(a, i))
    return -a, np.roots(nco)


def corner_scale(ax, t0, ymax, dt=1.0):
    """L-shaped scale bar at the far lower-left of `ax`, drawn outside the panel."""
    x0, y0 = t0 - 0.08, -ymax * 1.10
    ax.plot([x0, x0], [y0, y0 + ymax], c="white", lw=1.8, path_effects=ST, clip_on=False)
    ax.plot([x0, x0 + dt], [y0, y0], c="white", lw=1.8, path_effects=ST, clip_on=False)
    ax.text(x0 + dt / 2, y0 - ymax * 0.34, f"{dt:g} s", ha="center", va="top",
            fontsize=7, fontweight="bold", color="white", path_effects=ST, clip_on=False)
    ax.text(x0 - dt * 0.22, y0 + ymax / 2, f"{ymax*100:.1f}%", ha="right", va="center",
            fontsize=7, fontweight="bold", color="white", rotation=90, path_effects=ST,
            clip_on=False)


def main():
    z = np.load(TF_CACHE, allow_pickle=True)
    H, yhat, sites, window = z["H"], z["yhat"], z["sites"], z["window"]
    Hstd = z["Hstd"] if "Hstd" in z.files else np.zeros_like(H)
    gain, order, tau, A = z["gain"], z["order"], z["tau"], z["A"]
    bz = np.load(BRAIN_CACHE, allow_pickle=True)
    mimg, px, sp, ny, nx = bz["mimg"], bz["px"], float(bz["sp"]), int(bz["ny"]), int(bz["nx"])
    tz = cr.load_trials()
    roi_ts = tz["roi_ts"].astype(np.float64)
    svdT, onset_t, pos, base_ix, twin = tz["svdT"], tz["onset_t"], tz["pos"], int(tz["base_ix"]), tz["window"]
    nS = len(sites)

    post = window >= 0
    YMAX = float(np.nanpercentile(np.abs(H[:, :, post]), 99.5)) or 0.01
    XLIM = None
    if "--xlim" in sys.argv:
        i = sys.argv.index("--xlim")
        XLIM = (max(float(sys.argv[i + 1]), float(window[0])),
                min(float(sys.argv[i + 2]), float(window[-1])))
    xlo = XLIM[0] if XLIM is not None else float(window[0])
    print(f"fixed y-scale ±{YMAX:.4f} dF/F; band = ±2 SD")

    w, h = (sp * 0.92) / nx, (sp * 0.92) / ny
    fxy = np.column_stack([px[:, 0] / nx, 1.0 - px[:, 1] / ny])
    bl = int(np.argmin(fxy[:, 0] + fxy[:, 1]))

    def coord(j):
        return f"({sites[j,0]:+.1f},{sites[j,1]:+.0f})"

    def build_brain():
        fig = plt.figure(figsize=(11, 11))
        bg = fig.add_axes([0, 0, 1, 1])
        bg.imshow(mimg, cmap="gray", extent=[0, nx, ny, 0], aspect="auto")
        bg.set_xlim(0, nx); bg.set_ylim(ny, 0); bg.axis("off")
        bg.scatter(px[:, 0], px[:, 1], s=14, c="red", edgecolors="white", linewidths=0.4, zorder=3)
        axd, axs = {}, {}
        for j in range(nS):
            ax = fig.add_axes([fxy[j, 0] - w / 2, fxy[j, 1] - h / 2, w, h])
            axd[j], axs[ax] = ax, j
        return dict(fig=fig, bg=bg, axd=axd, axs=axs, dot=None)

    def render(view, trace_fn, std_fn, pred_fn, order_fn, frames, ring, title):
        for j, ax in view["axd"].items():
            ax.clear(); ax.patch.set_alpha(0)
            ax.axhline(0, c="0.6", lw=0.4, ls=":", alpha=0.7, zorder=1)
            ax.axvline(0, c="red", lw=0.9, zorder=1)
            tr, sd = trace_fn(j), std_fn(j)
            ax.fill_between(window, tr - 2 * sd, tr + 2 * sd, color="deepskyblue", alpha=0.10, lw=0)
            ax.plot(window, tr, c="blue", lw=1.7)             # trial MEAN — prominent
            ax.plot(window, pred_fn(j), c="orange", lw=1.0, ls="--")
            ax.set_ylim(-YMAX, YMAX); ax.set_xticks([]); ax.set_yticks([])
            if XLIM is not None:
                ax.set_xlim(*XLIM)
            for spn in ax.spines.values():
                spn.set_visible(False)
            ax.text(0.04, 0.96, f"n{int(order_fn(j))}", transform=ax.transAxes, fontsize=6,
                    va="top", ha="left", color="white", path_effects=ST)
            if j in frames:
                for spn in ax.spines.values():
                    spn.set_visible(True); spn.set_color(frames[j]); spn.set_linewidth(2.2)
            if j == bl:
                corner_scale(ax, xlo, YMAX)
        if view["dot"] is not None:
            view["dot"].remove()
        view["dot"] = view["bg"].scatter([px[ring, 0]], [px[ring, 1]], s=130, facecolors="none",
                                         edgecolors="red", linewidths=2.0, zorder=4)
        t = view["fig"].suptitle(title, fontsize=11, color="white", y=0.995)
        t.set_path_effects(ST)
        view["fig"].canvas.draw_idle()

    def report(X):
        print(f"\n=== STIM {coord(X)} - fitted TF per readout (poles & zeros 1/s, by |gain|) ===")
        for r in np.argsort(-np.abs(gain[X])):
            p, zr = poles_zeros(tau[X, r], A[X, r])
            ps = ", ".join(f"{v:.1f}" for v in p)
            zs = ", ".join((f"{v.real:.1f}" if abs(v.imag) < 1e-6 else f"{v.real:.1f}{v.imag:+.1f}j")
                           for v in zr)
            print(f"  {coord(r)} n{int(order[X,r])} g{gain[X,r]:+.4f}  p[{ps}] z[{zs}]")

    eff = build_brain()
    views = {"aff": None, "trials": None}
    X0 = int(np.nanargmax(np.abs(gain[np.arange(nS), np.arange(nS)])))
    state = {"X": X0, "Y": None, "live": False, "on_sec": None}

    def draw_efferent(X):
        render(eff, lambda j: H[X, j], lambda j: Hstd[X, j], lambda j: yhat[X, j],
               lambda j: order[X, j], {X: "red"}, X,
               f"EFFERENT — stim {coord(X)} → response at every site   "
               f"blue=trial mean  band=±2SD  orange=TF")
        report(X)

    def draw_afferent(X, Ysel=None):
        if views["aff"] is None or not plt.fignum_exists(views["aff"]["fig"].number):
            views["aff"] = build_brain()
            if state.get("on_sec"):
                views["aff"]["fig"].canvas.mpl_connect("button_press_event", state["on_sec"])
            if state.get("live"):
                views["aff"]["fig"].show()
        frames = {X: "red"}
        if Ysel is not None:
            frames[Ysel] = "lime"
        render(views["aff"], lambda j: H[j, X], lambda j: Hstd[j, X], lambda j: yhat[j, X],
               lambda j: order[j, X], frames, X,
               f"AFFERENT — node {coord(X)}: each site = {coord(X)}'s response when THAT site "
               f"is stimmed   red={coord(X)}  green=trials shown   [click a node for its trials]")

    def show_trials(s, r):
        dff, m = cr.extract_trials(roi_ts, svdT, onset_t, pos, sites, twin, base_ix, s, r)
        n = dff.shape[0]
        yl = float(np.nanpercentile(np.abs(dff[:, post]), 99) * 1.15) or YMAX
        if views["trials"] is None or not plt.fignum_exists(views["trials"]["fig"].number):
            f, axx = plt.subplots(10, 5, figsize=(11, 13))
            views["trials"] = dict(fig=f, axes=axx.ravel())
            if state.get("live"):
                f.show()
        f, axx = views["trials"]["fig"], views["trials"]["axes"]
        for k, ax in enumerate(axx):
            ax.clear(); ax.set_xticks([]); ax.set_yticks([])
            if k < n:
                ax.axhline(0, c="0.7", lw=0.3, ls=":")
                ax.axvline(0, c="red", lw=0.6)
                ax.plot(twin, dff[k], c="dodgerblue", lw=0.6)
                ax.plot(twin, m, c="orange", lw=1.3)         # same mean as the brain map
                ax.set_ylim(-yl, yl)
                if XLIM is not None:
                    ax.set_xlim(*XLIM)
                ax.text(0.03, 0.97, f"{k+1}", transform=ax.transAxes, fontsize=5, va="top", c="0.4")
            else:
                ax.axis("off")
        f.suptitle(f"All {n} trials — stim {coord(s)} → readout {coord(r)}   "
                   f"blue = single trial   orange = trial mean (±{yl*100:.1f}% scale)", fontsize=11)
        f.tight_layout(rect=[0, 0, 1, 0.98])
        f.canvas.draw_idle()

    draw_efferent(X0)
    # default trials pair: the OTHER stim site whose response at X0 is strongest (afferent
    # col of X0, excluding X0 itself so the preview/default is a genuine cross pair)
    col = np.abs(H[:, X0, post]).max(1).copy(); col[X0] = -np.inf
    Y0 = int(np.argmax(col))
    state["Y"] = Y0

    if SAVE:
        draw_afferent(X0, Y0)
        show_trials(Y0, X0)
        outdir = Path(__file__).resolve().parent / "grid_png"; outdir.mkdir(exist_ok=True)
        eff["fig"].savefig(outdir / "view_efferent.png", dpi=130)
        views["aff"]["fig"].savefig(outdir / "view_afferent.png", dpi=130)
        views["trials"]["fig"].savefig(outdir / "view_trials.png", dpi=130)
        print("wrote view_efferent.png, view_afferent.png, view_trials.png")
        return

    # secondary (afferent) map: click a node Y on it -> trials of (stim Y -> readout X)
    def on_secondary(event):
        if views["aff"] is None or event.inaxes not in views["aff"]["axs"]:
            return
        state["Y"] = views["aff"]["axs"][event.inaxes]
        draw_afferent(state["X"], state["Y"])
        show_trials(state["Y"], state["X"])
    state["on_sec"] = on_secondary

    # primary (efferent) map: click a node X -> efferent H[X,:] AND afferent H[:,X] both update
    def on_primary(event):
        if event.inaxes not in eff["axs"]:
            return
        state["X"] = eff["axs"][event.inaxes]
        draw_efferent(state["X"])
        draw_afferent(state["X"], state["Y"])
        show_trials(state["Y"], state["X"])
    eff["fig"].canvas.mpl_connect("button_press_event", on_primary)

    draw_afferent(X0, Y0)          # creates the afferent window (+ connects on_secondary)
    show_trials(Y0, X0)
    state["live"] = True
    plt.show()


if __name__ == "__main__":
    main()
