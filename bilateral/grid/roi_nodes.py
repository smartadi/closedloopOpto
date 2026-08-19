"""Draw an ROI on the mean image and keep only the grid sites well inside it.

Replaces the purely geometric `gdar_x.interior_nodes` perimeter rule with a hand-drawn
region: the lattice-degree rule assumes the usable cortex is the middle of the grid, which
is only true if the grid happens to be centred on it.  Drawing the region says where the
cortex actually is.

    .venv/Scripts/python.exe bilateral/grid/roi_nodes.py                 # draw it
    .venv/Scripts/python.exe bilateral/grid/roi_nodes.py --margin 0.8    # redraw, wider margin
    .venv/Scripts/python.exe bilateral/grid/roi_nodes.py --reuse --margin 0.3   # keep the
        polygon, just recompute the mask at a different margin -- no redrawing

How to draw: LEFT click adds a vertex, RIGHT click removes the last one, MIDDLE click (or
Enter) finishes.  The polygon closes itself; you do not need to click the first point again.

A site is kept only if it is inside the polygon AND at least `margin` mm from its boundary
-- "too close to the edge" and "outside" are the same failure (the illuminated spot has a
finite radius, so a site near the boundary is partly stimulating tissue you have excluded).
The margin is in mm and converted with the cached px/mm, so it is comparable to the 1 mm
grid spacing rather than being an arbitrary pixel count.

Writes `data/grid_roi_nodes.npz` (polygon + keep mask + margin).  Both fitting drivers take
`--roi` to use it:

    .venv/Scripts/python.exe bilateral/grid/freegraph.py --roi
    .venv/Scripts/python.exe bilateral/grid/hetgraph.py  --roi
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

DATA = Path(__file__).resolve().parents[2] / "data"
PNG = Path(__file__).resolve().parent / "network_png"
BRAIN = DATA / "grid_brain.npz"
ROI = DATA / "grid_roi_nodes.npz"


def load_brain():
    if not BRAIN.exists():
        raise FileNotFoundError(
            f"{BRAIN.name} missing -- build it with:\n"
            f"  .venv/Scripts/python.exe bilateral/grid/cross_response.py brain")
    z = np.load(BRAIN, allow_pickle=True)
    return dict(mimg=z["mimg"], px=z["px"], sp=float(z["sp"]), sites=z["sites"])


# --------------------------------------------------------------------------------------
# geometry
# --------------------------------------------------------------------------------------

def _dist_to_polygon(pts, poly):
    """Minimum Euclidean distance from each point to the polygon BOUNDARY (not its inside)."""
    pts = np.asarray(pts, float)
    poly = np.asarray(poly, float)
    a = poly
    b = np.roll(poly, -1, axis=0)
    ab = b - a                                            # (V, 2) edge vectors
    ap = pts[:, None, :] - a[None, :, :]                  # (N, V, 2)
    den = (ab ** 2).sum(1)
    den[den == 0] = 1.0
    t = np.clip((ap * ab[None]).sum(-1) / den[None], 0.0, 1.0)
    proj = a[None] + t[..., None] * ab[None]
    return np.linalg.norm(pts[:, None, :] - proj, axis=-1).min(1)


def polygon_mask(px, poly, margin_px):
    """keep = inside(polygon) AND distance-to-boundary >= margin_px."""
    from matplotlib.path import Path as MplPath
    inside = MplPath(np.asarray(poly, float)).contains_points(np.asarray(px, float))
    dist = _dist_to_polygon(px, poly)
    return inside & (dist >= margin_px), inside, dist


def report(keep, inside, dist, sites, sp, margin_mm):
    N = len(keep)
    out = ~inside
    edge = inside & ~keep
    print(f"\nROI: {int(keep.sum())}/{N} sites kept "
          f"({int(out.sum())} outside, {int(edge.sum())} inside but within "
          f"{margin_mm:g} mm of the boundary)")
    L = sites[:, 0] < 0
    print(f"  kept: {int((keep & L).sum())} left / {int((keep & ~L).sum())} right")
    if edge.any():
        print("  dropped for margin: " + ", ".join(
            f"#{i}({sites[i, 0]:+.1f},{sites[i, 1]:+.0f})@{dist[i] / sp:.2f}mm"
            for i in np.nonzero(edge)[0]))
    if out.any():
        print("  dropped as outside: " + ", ".join(
            f"#{i}({sites[i, 0]:+.1f},{sites[i, 1]:+.0f})" for i in np.nonzero(out)[0]))
    return dict(n_keep=int(keep.sum()), n_out=int(out.sum()), n_edge=int(edge.sum()))


# --------------------------------------------------------------------------------------
# drawing
# --------------------------------------------------------------------------------------

def draw(b, margin_mm=0.5, cmap="gray"):
    """Interactive polygon draw over the mean image.  Returns the vertex array (V, 2)."""
    import matplotlib
    try:
        matplotlib.use("TkAgg", force=True)
    except Exception as exc:                                  # noqa: BLE001
        raise RuntimeError(
            "no interactive matplotlib backend available -- install tk, or pass an "
            "explicit --polygon") from exc
    import matplotlib.pyplot as plt

    mimg, px, sites = b["mimg"], b["px"], b["sites"]
    fig, ax = plt.subplots(figsize=(9, 9))
    ax.imshow(mimg, cmap=cmap)
    left = sites[:, 0] < 0
    ax.scatter(px[left, 0], px[left, 1], s=48, c="tab:green", ec="k", lw=0.4, zorder=3)
    ax.scatter(px[~left, 0], px[~left, 1], s=48, c="tab:purple", ec="k", lw=0.4, zorder=3)
    for i, (x, y) in enumerate(px):
        ax.annotate(str(i), (x, y), fontsize=6, color="w", ha="center", va="center",
                    zorder=4)
    ax.set_title("LEFT click = vertex,  RIGHT click = undo,  MIDDLE click / Enter = done\n"
                 f"(green = left/excitatory, purple = right/inhibitory; "
                 f"margin {margin_mm:g} mm = {margin_mm * b['sp']:.0f} px)", fontsize=10)
    ax.set_axis_off()
    fig.tight_layout()
    print("\ndraw the usable region -- left click vertices, middle click (or Enter) "
          "when done ...")
    pts = plt.ginput(n=-1, timeout=0, show_clicks=True)
    plt.close(fig)
    if len(pts) < 3:
        raise SystemExit("need at least 3 vertices -- nothing saved")
    return np.asarray(pts, float)


def preview(b, poly, keep, inside, dist, margin_mm, out=None):
    import matplotlib
    matplotlib.use("Agg", force=True)
    import matplotlib.pyplot as plt

    mimg, px, sites, sp = b["mimg"], b["px"], b["sites"], b["sp"]
    fig, ax = plt.subplots(1, 2, figsize=(13, 6.6))

    a = ax[0]
    a.imshow(mimg, cmap="gray")
    a.plot(*np.vstack([poly, poly[:1]]).T, "-", color="tab:orange", lw=1.6)
    a.scatter(px[keep, 0], px[keep, 1], s=55, c="tab:green", ec="k", lw=0.4, label="kept")
    a.scatter(px[inside & ~keep, 0], px[inside & ~keep, 1], s=55, c="tab:orange", ec="k",
              lw=0.4, label=f"too close (<{margin_mm:g} mm)")
    a.scatter(px[~inside, 0], px[~inside, 1], s=55, c="tab:red", ec="k", lw=0.4,
              marker="x", label="outside")
    a.legend(fontsize=8, loc="lower right")
    a.set_axis_off()
    a.set_title(f"{int(keep.sum())}/{len(keep)} sites kept", fontsize=10)

    a = ax[1]
    order = np.argsort(dist / sp)
    col = np.where(~inside[order], "tab:red",
                   np.where(keep[order], "tab:green", "tab:orange"))
    a.barh(np.arange(len(order)), np.where(inside[order], 1, -1) * dist[order] / sp,
           color=col)
    a.axvline(margin_mm, color="k", ls="--", lw=1.0)
    a.axvline(0, color="0.5", lw=0.8)
    a.set_yticks(np.arange(len(order)))
    a.set_yticklabels([f"{i} ({sites[i, 0]:+.1f},{sites[i, 1]:+.0f})" for i in order],
                      fontsize=5.5)
    a.set_xlabel("signed distance to ROI boundary (mm); negative = outside", fontsize=8)
    a.set_title(f"margin = {margin_mm:g} mm (dashed)", fontsize=10)

    fig.tight_layout()
    PNG.mkdir(exist_ok=True)
    out = (PNG / "roi_nodes.png") if out is None else Path(out)
    fig.savefig(out, dpi=150)
    print(f"wrote {out}")


# --------------------------------------------------------------------------------------
# persistence
# --------------------------------------------------------------------------------------

def save(poly, keep, inside, dist, margin_mm, sites):
    np.savez(ROI, polygon=poly, keep=keep, inside=inside, dist_px=dist,
             margin_mm=float(margin_mm), sites=sites)
    print(f"saved -> {ROI.name}")


def load_mask(sites=None, verbose=True):
    """Keep mask saved by this tool, checked against the caller's site list."""
    if not ROI.exists():
        raise FileNotFoundError(
            f"{ROI.name} missing -- draw one first:\n"
            f"  .venv/Scripts/python.exe bilateral/grid/roi_nodes.py")
    z = np.load(ROI, allow_pickle=True)
    keep = z["keep"].astype(bool)
    if sites is not None:
        s = np.asarray(sites, float)
        if s.shape != z["sites"].shape or not np.allclose(s, z["sites"]):
            raise ValueError("the saved ROI was drawn for a different site list -- "
                             "redraw it, or drop --roi")
    if verbose:
        L = z["sites"][:, 0] < 0
        print(f"ROI mask: {int(keep.sum())}/{len(keep)} sites "
              f"({int((keep & L).sum())} left / {int((keep & ~L).sum())} right), "
              f"margin {float(z['margin_mm']):g} mm")
    return keep


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--margin", type=float, default=0.5,
                    help="mm from the ROI boundary a site must clear (default 0.5)")
    ap.add_argument("--reuse", action="store_true",
                    help="keep the saved polygon, only recompute the mask at --margin")
    ap.add_argument("--cmap", default="gray")
    a = ap.parse_args()

    b = load_brain()
    if a.reuse:
        if not ROI.exists():
            raise SystemExit(f"--reuse needs an existing {ROI.name}")
        poly = np.load(ROI, allow_pickle=True)["polygon"]
        print(f"reusing the saved {len(poly)}-vertex polygon at margin {a.margin:g} mm")
    else:
        poly = draw(b, margin_mm=a.margin, cmap=a.cmap)

    keep, inside, dist = polygon_mask(b["px"], poly, a.margin * b["sp"])
    report(keep, inside, dist, b["sites"], b["sp"], a.margin)
    if keep.sum() < 4:
        print("\n[warn] fewer than 4 sites kept -- nothing downstream will be meaningful")
    save(poly, keep, inside, dist, a.margin, b["sites"])
    preview(b, poly, keep, inside, dist, a.margin)


if __name__ == "__main__":
    main()
