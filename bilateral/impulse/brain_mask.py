"""brain_mask.py — hand-drawn brain outline + midline -> brain / contra / ipsi masks.

Python port of `utils/cp_roi_masks.m`, the project's SINGLE SOURCE OF TRUTH for the
contra-prediction ROI. You draw the FULL-BRAIN outline and 2 MIDLINE points ONCE per session on
the mean image; the geometry is cached to JSON and every later run just loads it.

    brain  = inside the drawn outline AND above an intensity floor (thr_pctile)
    ipsi   = the side of the drawn midline containing the photostim site (prediction TARGET)
    contra = the other side (the PREDICTOR)

Why hand-drawn: a bare intensity threshold is NOT a brain mask. `mimg > percentile(mimg, 20)`
keeps exactly 80% of the frame by construction, which on AL_0048 swept in the bright ventral /
skull band below cortex and the lateral edges — those pixels were being used as contra
predictors. In the MATLAB original `thr_pctile` is only a floor applied ON TOP of the outline;
the outline does the real work.

ORIENTATION: unlike the MATLAB (which works in a transposed display frame), everything here is
NATIVE (row, col) — `imshow(mimg)` puts col on x and row on y, so clicks come back as
(x=col, y=row), matching this module's `site_xy = (px_x, px_y)` convention. Masks are returned
as [nY x nX] boolean arrays that index `mimg`/`U` directly.

DRAW (once per session, needs a GUI window):
    .venv/Scripts/python.exe bilateral/impulse/brain_mask.py
Then re-run the analysis normally; it will pick up the cache.
"""
import json
from pathlib import Path

import numpy as np
from matplotlib.path import Path as MplPath

CACHE_DIR = Path(__file__).resolve().parent / "masks"


def cache_path(subject, date, wf_exp):
    """Canonical cache location for one session's drawn geometry."""
    return CACHE_DIR / f"roi_{subject}_{date.replace('-', '')}_e{wf_exp}.json"


# ---------------------------------------------------------------- interactive draw
def draw_masks(mimg, out_path, title_extra=""):
    """Interactive draw: brain outline (many points), then 2 midline points. Saves JSON.

    Left-click adds a point, right-click removes the last, middle-click / Enter finishes.
    """
    import matplotlib
    matplotlib.use("TkAgg", force=True)          # needs an interactive backend
    import matplotlib.pyplot as plt

    lo, hi = np.percentile(mimg, [1, 99])
    fig, ax = plt.subplots(figsize=(9, 9))
    ax.imshow(mimg, cmap="gray", vmin=lo, vmax=hi)
    ax.set_axis_off()
    ax.set_title("STEP 1 — click around the FULL-BRAIN outline\n"
                 "(many points; right-click undo; middle-click/Enter when done)" + title_extra,
                 fontsize=11, fontweight="bold")
    fig.canvas.draw()
    pts = fig.ginput(n=-1, timeout=0)
    if len(pts) < 3:
        plt.close(fig)
        raise ValueError("brain_mask: need >=3 outline points.")
    bx = [p[0] for p in pts] + [pts[0][0]]        # close the polygon
    by = [p[1] for p in pts] + [pts[0][1]]
    ax.plot(bx, by, "y-", lw=1.5)

    ax.set_title("STEP 2 — click 2 MIDLINE points (anterior + posterior), then Enter",
                 fontsize=11, fontweight="bold", color="c")
    fig.canvas.draw()
    mpts = fig.ginput(n=2, timeout=0)
    if len(mpts) < 2:
        plt.close(fig)
        raise ValueError("brain_mask: need 2 midline points.")
    mx = [p[0] for p in mpts]
    my = [p[1] for p in mpts]
    ax.plot(mx, my, "c--", lw=1.5)
    fig.canvas.draw()
    plt.pause(0.6)
    plt.close(fig)

    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    geom = dict(bx=list(map(float, bx)), by=list(map(float, by)),
                mx=list(map(float, mx)), my=list(map(float, my)),
                shape=[int(mimg.shape[0]), int(mimg.shape[1])])
    out_path.write_text(json.dumps(geom, indent=2))
    print(f"[brain_mask] saved ROI geometry: {out_path}")
    return geom


def load_geometry(path):
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(
            f"[brain_mask] missing ROI cache:\n  {path}\n"
            f"Draw it once with:  .venv/Scripts/python.exe bilateral/impulse/brain_mask.py")
    return json.loads(path.read_text())


# ---------------------------------------------------------------- geometry -> masks
def masks_from_geometry(mimg, geom, site_xy, thr_pctile=20.0):
    """brain = inside outline AND above the intensity floor; bisected by the drawn midline.

    The side containing `site_xy` (x=col, y=row) is IPSI (target); the other is CONTRA
    (predictor). Split is orientation-robust (signed cross product), as in the MATLAB.
    """
    ny, nx = mimg.shape
    XX, YY = np.meshgrid(np.arange(nx), np.arange(ny))     # XX=col, YY=row, both (nY, nX)

    poly = MplPath(np.column_stack([geom["bx"], geom["by"]]))
    inside = poly.contains_points(np.column_stack([XX.ravel(), YY.ravel()])).reshape(ny, nx)
    brain = inside & (mimg > np.percentile(mimg, thr_pctile))

    mx, my = geom["mx"], geom["my"]
    dx, dy = mx[1] - mx[0], my[1] - my[0]                  # midline direction
    signed = dx * (YY - my[0]) - dy * (XX - mx[0])         # signed side of every pixel
    sgn_site = dx * (site_xy[1] - my[0]) - dy * (site_xy[0] - mx[0])
    sp = np.sign(sgn_site) or 1.0

    ipsi = brain & (np.sign(signed) == sp)
    contra = brain & (np.sign(signed) == -sp)
    return dict(brain=brain, contra=contra, ipsi=ipsi, geom=geom)


def get_masks(mimg, subject, date, wf_exp, site_xy, thr_pctile=20.0):
    """Load the cached drawn geometry for this session and build the masks."""
    return masks_from_geometry(mimg, load_geometry(cache_path(subject, date, wf_exp)),
                               site_xy, thr_pctile)


# ---------------------------------------------------------------- verification plot
def plot_masks(mimg, M, site_xy, out_png, label=""):
    """Verification overlay: contra (blue) / ipsi (red) tint + outline + midline + site."""
    import matplotlib.pyplot as plt
    lo, hi = np.percentile(mimg, [1, 99])
    g = np.clip((mimg - lo) / max(hi - lo, 1e-9), 0, 1)
    rgb = np.repeat(g[:, :, None], 3, axis=2)
    rgb[M["contra"]] = 0.65 * rgb[M["contra"]] + 0.35 * np.array([0.10, 0.45, 0.95])
    rgb[M["ipsi"]] = 0.65 * rgb[M["ipsi"]] + 0.35 * np.array([0.95, 0.30, 0.10])

    fig, ax = plt.subplots(figsize=(7, 7))
    ax.imshow(rgb)
    geom = M["geom"]
    ax.plot(geom["bx"], geom["by"], "k-", lw=1.0)
    mx, my = geom["mx"], geom["my"]
    dx, dy = mx[1] - mx[0], my[1] - my[0]
    t = np.linspace(-3, 3, 2)
    ax.plot(mx[0] + t * dx, my[0] + t * dy, "k--", lw=1.2)
    ax.plot(site_xy[0], site_xy[1], "g+", ms=15, mew=2.5)
    ax.set_xlim(0, mimg.shape[1]); ax.set_ylim(mimg.shape[0], 0)
    ax.set_axis_off()
    ax.set_title(f"{label}\ncontra=predictor (blue) | ipsi=site side (red) | site (green +)\n"
                 f"brain {M['brain'].sum()} px | contra {M['contra'].sum()} | ipsi {M['ipsi'].sum()}",
                 fontsize=9, fontweight="bold")
    fig.tight_layout()
    fig.savefig(out_png, dpi=170)
    plt.close(fig)


# ---------------------------------------------------------------- standalone draw
def main():
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import impulse_config as cfg
    import loader

    _, mimg, _, _, _, _ = loader.load_svd(cfg.EXPDIR, 8)
    out = cache_path(cfg.SUBJECT, cfg.DATE, cfg.WF_EXP)
    if out.exists():
        ans = input(f"[brain_mask] cache exists: {out}\n  redraw and overwrite? [y/N] ").strip().lower()
        if ans != "y":
            print("  keeping existing cache; nothing drawn.")
            return
    draw_masks(mimg, out, title_extra=f"\n{cfg.SUBJECT} {cfg.DATE} exp {cfg.WF_EXP}")

    # verification overlays for both photostim sites
    import matplotlib
    matplotlib.use("Agg", force=True)
    geom = load_geometry(out)
    outdir = Path(__file__).resolve().parent / "ols_png"
    outdir.mkdir(exist_ok=True)
    for sd, site in [("left", (164, 397)), ("right", (401, 389))]:
        M = masks_from_geometry(mimg, geom, site)
        plot_masks(mimg, M, site, outdir / f"brain_mask_{sd}.png",
                   label=f"{cfg.SUBJECT} {cfg.DATE} — {sd} site")
    print(f"[brain_mask] wrote verification overlays -> {outdir}")


if __name__ == "__main__":
    main()
