"""
pupil_seg.py — dark-pupil segmentation for the AL_0048 eye camera (448x492).

The pupil is the dark, roughly-circular central blob; the iris is lighter; there
is one bright specular highlight inside/near the pupil and bright eyelid glints at
the rim. Strategy: adaptive dark threshold -> connected components -> pick the blob
that is central + large + round -> fill the specular hole -> area to equivalent
diameter. Robust to the fixed corner shadows and the lid glints.

seg_pupil(gray) -> (diameter_px, cx, cy, mask)  (nan diameter if no valid pupil)
"""
import numpy as np
from scipy import ndimage


def seg_pupil(gray, dark_pct=7, min_area=150, max_area=6000, prev=None):
    """The pupil is the darkest COMPACT central disc (far darker than the iris).
    Threshold only the darkest few percent, drop border-touching shadow blobs,
    then pick the roundest, most-central candidate."""
    g = gray.astype(np.float32)
    h, w = g.shape
    gs = ndimage.gaussian_filter(g, 1.5)
    thr = np.percentile(gs, dark_pct)
    dark = gs < thr
    # merge the specular highlight sitting inside the pupil, then clean speckle
    dark = ndimage.binary_closing(dark, iterations=3)
    dark = ndimage.binary_opening(dark, iterations=1)
    lbl, n = ndimage.label(dark)
    if n == 0:
        return np.nan, np.nan, np.nan, np.zeros_like(dark)
    cy0, cx0 = (prev[1], prev[0]) if prev is not None else (h / 2, w / 2)
    maxd = np.hypot(w, h) / 2
    best, best_score = None, -np.inf
    for i in range(1, n + 1):
        m = lbl == i
        area = int(m.sum())
        if area < min_area or area > max_area:
            continue
        ys, xs = np.nonzero(m)
        # reject blobs touching the frame border (corner fur shadows)
        if ys.min() == 0 or xs.min() == 0 or ys.max() == h - 1 or xs.max() == w - 1:
            continue
        cy, cx = ys.mean(), xs.mean()
        # circularity: area vs area of its equivalent-radius disc bounding box
        rad = np.sqrt(area / np.pi)
        bb = (np.ptp(ys) + 1) * (np.ptp(xs) + 1)
        circ = area / bb                       # ~pi/4 for a disc
        cen = 1.0 - np.hypot(cx - cx0, cy - cy0) / maxd
        score = circ * cen                     # round AND central
        if score > best_score:
            best_score, best = score, m
    if best is None:
        return np.nan, np.nan, np.nan, np.zeros_like(dark)
    filled = ndimage.binary_fill_holes(best)
    ys, xs = np.nonzero(filled)
    cy, cx = ys.mean(), xs.mean()
    area = filled.sum()
    diam = 2.0 * np.sqrt(area / np.pi)   # equivalent-circle diameter
    return diam, cx, cy, filled


if __name__ == "__main__":
    import imageio.v3 as iio
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import os

    scratch = os.environ.get("SCRATCH", ".")
    frames = ["eye_120.png", "eye_400.png", "eye_800.png"]
    fig, axes = plt.subplots(1, len(frames), figsize=(12, 4.6))
    prev = None
    for ax, fn in zip(axes, frames):
        img = iio.imread(os.path.join(scratch, fn))
        if img.ndim == 3:
            img = img[..., :3].mean(-1)
        diam, cx, cy, mask = seg_pupil(img, prev=prev)
        prev = (cx, cy) if np.isfinite(cx) else None
        ax.imshow(img, cmap="gray")
        if np.isfinite(diam):
            ax.contour(mask, levels=[0.5], colors="#ff2e6a", linewidths=1.5)
            ax.plot(cx, cy, "+", color="#38f", ms=10)
            ax.set_title(f"{fn}\nD={diam:.1f}px  c=({cx:.0f},{cy:.0f})", fontsize=9)
        else:
            ax.set_title(f"{fn}\nNO PUPIL", fontsize=9)
        ax.axis("off")
    fig.tight_layout()
    out = os.path.join(scratch, "pupil_seg_test.png")
    fig.savefig(out, dpi=110)
    print("wrote", out)
