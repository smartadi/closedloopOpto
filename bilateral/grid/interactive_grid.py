#!/usr/bin/env python
"""interactive_grid.py — interactive perturbation-response explorer over the brain.

TWO-CLICK FLOW — click 1 picks the STIM site, click 2 picks the READOUT:
  • SELECTOR (plain brain map): LEFT-click a node X -> X becomes the stim site.
    RIGHT-click ANYWHERE on this map -> readout at that PIXEL (not restricted to the 52
    nodes): the pair inspector opens in pixel mode, fitting that ROI on the fly from the
    cached SVD basis and showing the full-frame dF/F snapshot with the ROI marked.
  • EFFERENT (brain map of traces): every site shows H[X, ·], the trial-mean dF/F response
    to stimulating X (thick blue), ±2 SD band (faint), TF prediction (orange), model-order
    label, red stim line at t=0. Poles/zeros printed to the console. Then click any node Y:
      - plain click  -> PAIR INSPECTOR (`pair_inspector.py`): both amplitudes, independent
        + shared TF fits, s-plane poles/zeros, mode decomposition, single-trial raster and
        this pair's place in the population dose-response.
      - shift-click  -> TRIALS: 10×5 grid of every single trial for (X -> Y) at the display
        amplitude, trial mean overlaid — the averaging check.

  • FIELD MAPS (press `m`): for the current stim site, three brain maps side by side —
    signed matched-time dF/F, dominant time constant, and peak latency at every readout.
    Unreliable readouts (CV-R² ≤ 0) are drawn hollow.

Amplitude: the 2026-07-10 grid ran TWO laser powers [1.0, 2.0]. The brain maps draw ONE of
them (default the highest, `--amp 1.0` to switch, or press `a` to toggle live); the pair
inspector always shows both.

Data: cached 2-amp TF fits (`tf_fit.py 2amp`) + brain image (`cross_response.py brain`) +
per-amp ROI time-series (`cross_response.py 2amp`). Single trials reconstruct with no
network read.

Run (interactive):   .venv/Scripts/python.exe bilateral/grid/interactive_grid.py
Run (static PNGs):    .venv/Scripts/python.exe bilateral/grid/interactive_grid.py save
Set display window:   ... interactive_grid.py --xlim -1 1
Pick the amplitude:   ... interactive_grid.py --amp 1.0
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
import tf_fit
from pair_inspector import PairInspector, poles_zeros, dominant_tau   # TF algebra lives there

DATA = Path(__file__).resolve().parents[2] / "data"
TF_CACHE = DATA / "grid_tf_fits_2amp.npz"     # per-amp independent fits (tf_fit.py 2amp)
BRAIN_CACHE = DATA / "grid_brain.npz"
ST = [pe.withStroke(linewidth=2.0, foreground="black")]


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
    if not TF_CACHE.exists():
        raise FileNotFoundError(f"{TF_CACHE} missing — run `python tf_fit.py 2amp` first")
    z = np.load(TF_CACHE, allow_pickle=True)
    sites, window = z["sites"], z["window"]
    amps = [float(a) for a in z["amps"]]
    # every fitted array carries a leading amp axis; the brain maps draw ONE amp at a time.
    ALL = {k: z[k] for k in ("H", "yhat", "Hstd", "gain", "order", "tau", "A", "cvr2", "om", "ph")
           if k in z.files}
    if "--amp" in sys.argv:
        want = float(sys.argv[sys.argv.index("--amp") + 1])
        if not any(abs(want - a) < 1e-6 for a in amps):
            raise SystemExit(f"--amp {want} not in this session's amps {amps}")
        AI = int(np.argmin([abs(want - a) for a in amps]))
    else:
        AI = len(amps) - 1                                   # default: highest power
    bz = np.load(BRAIN_CACHE, allow_pickle=True)
    mimg, px, sp, ny, nx = bz["mimg"], bz["px"], float(bz["sp"]), int(bz["ny"]), int(bz["nx"])
    tz = cr.load_trials2()
    nS = len(sites)
    print(f"amps in session: {amps}; brain maps drawing amp {amps[AI]:.1f} "
          f"(--amp to change, or press 'a' to toggle)")

    # D = the currently displayed amplitude's slice of every fitted array. `set_amp` rebinds it
    # in place so the drawing closures below never need to know which amp is showing.
    D = {}

    def set_amp(ai):
        for k, v in ALL.items():
            D[k] = v[ai]
        D["ai"], D["amp"] = ai, amps[ai]
    set_amp(AI)

    post = window >= 0
    # fixed ±5% dF/F scale across ALL panels (comparable). The old per-sample 99.5th-pct
    # scale (~±1.9%) was dominated by near-zero samples and clipped 14% of pairs' peaks
    # (real responses reach 4-7%); ±5% clips only ~0.1%. Override with --ymax.
    YMAX = 0.05
    if "--ymax" in sys.argv:
        YMAX = float(sys.argv[sys.argv.index("--ymax") + 1])
    XLIM = (-0.5, 1.0)          # default trace window (s rel. onset); override with --xlim
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

    def render(view, trace_fn, std_fn, pred_fn, order_fn, frames, ring, title, rel_fn=None):
        for j, ax in view["axd"].items():
            ax.clear(); ax.patch.set_alpha(0)
            ax.axhline(0, c="0.6", lw=0.4, ls=":", alpha=0.7, zorder=1)
            ax.axvline(0, c="red", lw=0.9, zorder=1)
            tr, sd = trace_fn(j), std_fn(j)
            ax.fill_between(window, tr - 2 * sd, tr + 2 * sd, color="deepskyblue", alpha=0.10, lw=0)
            ax.plot(window, tr, c="blue", lw=1.7)             # trial MEAN — prominent
            # TF overlay: opacity encodes generalization (CV-R2). A fit that doesn't predict the
            # held-out trial half (low/negative CV-R2 = noise-fit) is drawn faint so it doesn't
            # read as a confident fit; a fit that generalizes is solid.
            a_tf = 1.0
            if rel_fn is not None:
                a_tf = float(np.clip(0.15 + 0.85 * (rel_fn(j) + 0.3) / 0.6, 0.15, 1.0))
            ax.plot(window, pred_fn(j), c="orange", lw=1.0, ls="--", alpha=a_tf)
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
        def _fmt(v):
            v = complex(v)
            return f"{v.real:.1f}" if abs(v.imag) < 1e-6 else f"{v.real:.1f}{v.imag:+.1f}j"

        for r in np.argsort(-np.abs(D["gain"][X])):
            p, zr = poles_zeros(D["tau"][X, r], D["A"][X, r],
                                D["om"][X, r] if "om" in D else None,
                                D["ph"][X, r] if "ph" in D else None)
            ps = ", ".join(_fmt(v) for v in p)
            zs = ", ".join(_fmt(v) for v in zr)
            print(f"  {coord(r)} n{int(D['order'][X,r])} g{D['gain'][X,r]:+.4f}  p[{ps}] z[{zs}]")

    def build_selector():
        """Map 1: a plain clickable brain (mean image + site dots). Click picks the stim site."""
        fig = plt.figure(figsize=(6.2, 6.2))
        ax = fig.add_axes([0, 0, 1, 1])
        ax.imshow(mimg, cmap="gray", extent=[0, nx, ny, 0], aspect="auto")
        ax.set_xlim(0, nx); ax.set_ylim(ny, 0); ax.axis("off")
        ax.scatter(px[:, 0], px[:, 1], s=70, c="red", edgecolors="white", linewidths=0.6, zorder=3)
        return dict(fig=fig, ax=ax, ring=None)

    def mark_selector(sel, X):
        if sel["ring"] is not None:
            sel["ring"].remove()
        sel["ring"] = sel["ax"].scatter([px[X, 0]], [px[X, 1]], s=240, facecolors="none",
                                        edgecolors="yellow", linewidths=2.6, zorder=4)
        t = sel["fig"].suptitle(f"STIM SITE {coord(X)} — left-click a node to change,  "
                                f"RIGHT-CLICK any pixel to read out there",
                                fontsize=12, color="white", y=0.99)
        t.set_path_effects(ST)
        sel["fig"].canvas.draw_idle()

    def nearest_site(event, ax):
        if event.inaxes is not ax or event.xdata is None:
            return None
        d = (px[:, 0] - event.xdata) ** 2 + (px[:, 1] - event.ydata) ** 2
        return int(np.argmin(d))

    effv = build_brain()
    sel = build_selector()
    views = {"trials": None, "pair": None, "fields": None}
    X0 = int(np.nanargmax(np.abs(D["gain"][np.arange(nS), np.arange(nS)])))
    state = {"X": X0, "Y": None, "live": False}

    def draw_efferent(X):
        render(effv, lambda j: D["H"][X, j], lambda j: D["Hstd"][X, j],
               lambda j: D["yhat"][X, j],
               lambda j: D["order"][X, j], {X: "red"}, X,
               f"EFFERENT @ amp {D['amp']:.1f} — stim {coord(X)} → response at every site   "
               f"blue=trial mean  band=±2SD  orange=TF (faint = low CV-R²)   "
               f"click=pair inspector, shift-click=single trials, 'a'=toggle amp",
               rel_fn=lambda j: D["cvr2"][X, j])
        report(X)

    def inspector():
        if views["pair"] is None:
            views["pair"] = PairInspector(xlim=XLIM, trials=tz, live=state.get("live", False))
        return views["pair"]

    def show_pair(s, r):
        """Open/refresh the full two-amplitude inspector for this (stim, readout) pair."""
        inspector().show(s, r, D["ai"])

    def show_pixel(s, cx, cy):
        """Same inspector, but the readout is an arbitrary PIXEL rather than a grid node."""
        try:
            inspector().show_pixel(s, cx, cy, D["ai"])
        except FileNotFoundError as e:
            print(f"[pixel mode unavailable] {e}")

    def field_maps(X):
        """Three brain maps for stim site X: matched-time gain, dominant tau, peak latency.

        Matched time = each readout's own |peak| time inside the fit window, so the gain map
        cannot mix the excitatory and suppression lobes (see pair_inspector.matched_time).
        """
        fit = (window >= 0) & (window <= tf_fit.FIT_TMAX)
        ixf = np.where(fit)[0]
        Hx = D["H"][X]                                        # (nS, nW)
        k = np.nanargmax(np.abs(np.nan_to_num(Hx[:, fit])), axis=1)
        ix = ixf[k]
        gm = Hx[np.arange(nS), ix]                            # signed dF/F at each peak
        lat = window[ix] * 1000.0                             # ms
        tau_d = np.array([dominant_tau(D["tau"][X, j], D["A"][X, j]) for j in range(nS)]) * 1000
        ok = D["cvr2"][X] > 0
        if views["fields"] is None or not plt.fignum_exists(views["fields"]["fig"].number):
            f, axx = plt.subplots(1, 3, figsize=(15.5, 5.6), constrained_layout=True)
            views["fields"] = dict(fig=f, axes=axx, cbars=[])
            if state.get("live"):
                f.show()
        f, axx = views["fields"]["fig"], views["fields"]["axes"]
        for cb in views["fields"]["cbars"]:
            try:
                cb.remove()
            except Exception:
                pass
        views["fields"]["cbars"] = []
        gl = float(np.nanpercentile(np.abs(gm[ok]), 98)) if ok.any() else 0.01
        # tau clim on the 10-90th percentile: a couple of readouts fit a slow mode LONGER than
        # the 600 ms fit window, and letting those set the scale flattens everything else.
        tlo, thi = (np.nanpercentile(tau_d[ok], [10, 90]) if ok.any() else (0, 300))
        specs = [(gm, "RdBu_r", (-gl, gl), "signed dF/F at each readout's peak"),
                 (tau_d, "viridis", (tlo, thi), f"dominant τ (ms)  [clipped {tlo:.0f}–{thi:.0f}]"),
                 (lat, "magma", (0, tf_fit.FIT_TMAX * 1000), "peak latency (ms)")]
        for ax, (v, cm, cl, ttl) in zip(axx, specs):
            ax.clear()
            ax.imshow(mimg, cmap="gray", extent=[0, nx, ny, 0], aspect="equal")
            ax.scatter(px[~ok, 0], px[~ok, 1], s=110, facecolors="none", edgecolors="0.6",
                       linewidths=1.0)
            sc = ax.scatter(px[ok, 0], px[ok, 1], c=v[ok], cmap=cm, vmin=cl[0], vmax=cl[1],
                            s=150, edgecolors="white", linewidths=0.6)
            ax.scatter([px[X, 0]], [px[X, 1]], s=320, facecolors="none", edgecolors="lime",
                       linewidths=2.4)
            ax.set_xlim(0, nx); ax.set_ylim(ny, 0); ax.axis("off")
            ax.set_title(ttl, fontsize=10)
            views["fields"]["cbars"].append(f.colorbar(sc, ax=ax, fraction=0.045, pad=0.02))
        f.suptitle(f"FIELDS @ amp {D['amp']:.1f} — stim {coord(X)} (lime)   "
                   f"hollow = CV-R²≤0 (fit does not generalize)", fontsize=12)
        f.canvas.draw_idle()

    def show_trials(s, r):
        dff, m = cr.extract_trials_amp(tz, s, r, D["amp"])
        twin = tz["window"]
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
        f.suptitle(f"All {n} trials @ amp {D['amp']:.1f} — stim {coord(s)} → readout {coord(r)}   "
                   f"blue = single trial   orange = trial mean (±{yl*100:.1f}% scale)", fontsize=11)
        f.tight_layout(rect=[0, 0, 1, 0.98])
        f.canvas.draw_idle()

    draw_efferent(X0)
    mark_selector(sel, X0)

    if SAVE:
        outdir = Path(__file__).resolve().parent / "grid_png"; outdir.mkdir(exist_ok=True)
        sel["fig"].savefig(outdir / "view_selector.png", dpi=130)
        effv["fig"].savefig(outdir / "view_efferent.png", dpi=130)
        # headless proof of the second click: the strongest OFF-SITE readout of the default
        # stim site (the self-pair is trivially strongest and would not demo a real pair)
        gsel = np.where(D["cvr2"][X0] > 0, np.abs(D["gain"][X0]), -np.inf)
        gsel[X0] = -np.inf
        Y0 = int(np.nanargmax(gsel))
        show_pair(X0, Y0)
        views["pair"].fig.savefig(outdir / "view_pair_inspector.png", dpi=130)
        show_trials(X0, Y0)                        # shift-click path, same pair
        views["trials"]["fig"].savefig(outdir / "view_trials.png", dpi=110)
        field_maps(X0)                             # 'm' path
        views["fields"]["fig"].savefig(outdir / "view_fields.png", dpi=130)
        made = ["view_selector.png", "view_efferent.png", "view_pair_inspector.png",
                "view_trials.png", "view_fields.png"]
        try:                                       # right-click path: readout at Y0's pixel
            show_pixel(X0, float(px[Y0, 0]), float(px[Y0, 1]))
            views["pair"].fig.savefig(outdir / "view_pixel_inspector.png", dpi=130)
            made.append("view_pixel_inspector.png")
        except Exception as e:
            print(f"[pixel render skipped] {type(e).__name__}: {e}")
        print(f"wrote {', '.join(made)}  ({coord(X0)} → {coord(Y0)}, amp {D['amp']:.1f})")
        return

    # Map 1 (selector): LEFT-click nearest site -> set stim X -> efferent map redraws.
    # RIGHT-click any pixel -> readout THERE (arbitrary ROI, fitted on the fly).
    def on_select(event):
        if event.inaxes is not sel["ax"] or event.xdata is None:
            return
        if event.button == 3:
            show_pixel(state["X"], float(event.xdata), float(event.ydata))
            return
        X = nearest_site(event, sel["ax"])
        if X is None:
            return
        state["X"] = X
        mark_selector(sel, X)
        draw_efferent(X)
        if views["fields"] is not None and plt.fignum_exists(views["fields"]["fig"].number):
            field_maps(X)
    sel["fig"].canvas.mpl_connect("button_press_event", on_select)

    # Map 2 (efferent): click a node = READOUT pick -> pair inspector (both amps).
    # shift-click keeps the old behaviour: the 10x5 single-trial grid at the display amp.
    def on_efferent(event):
        if event.inaxes not in effv["axs"]:
            return
        state["Y"] = effv["axs"][event.inaxes]
        if getattr(event, "key", None) == "shift":
            show_trials(state["X"], state["Y"])
        else:
            show_pair(state["X"], state["Y"])
    effv["fig"].canvas.mpl_connect("button_press_event", on_efferent)

    # 'a' toggles the displayed laser amplitude; 'm' opens/refreshes the field maps
    def on_key(event):
        if event.key == "m":
            field_maps(state["X"])
            return
        if event.key != "a" or len(amps) < 2:
            return
        set_amp((D["ai"] + 1) % len(amps))
        draw_efferent(state["X"])
        if state["Y"] is not None and views["pair"] is not None \
                and plt.fignum_exists(views["pair"].fig.number):
            show_pair(state["X"], state["Y"])
        if views["fields"] is not None and plt.fignum_exists(views["fields"]["fig"].number):
            field_maps(state["X"])
    for f_ in (sel["fig"], effv["fig"]):
        f_.canvas.mpl_connect("key_press_event", on_key)

    state["live"] = True
    plt.show()


if __name__ == "__main__":
    main()
