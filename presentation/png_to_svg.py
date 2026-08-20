"""
png_to_svg.py — trace a flat raster icon into a clean, background-free SVG.

Built for solid-colour artwork (logos, silhouette icons), not photographs: it
thresholds the image into ink / not-ink, walks the boundary at sub-pixel
precision, simplifies it, and emits smooth cubic Béziers.

Holes are handled by emitting every contour into ONE path with
`fill-rule="evenodd"`, so an enclosed region (a porthole, the middle of an
"O") knocks out instead of being filled over.

The background is simply never drawn — the SVG has no backing rect, so it is
transparent wherever the ink is not.

Run:
  .venv/Scripts/python.exe presentation/png_to_svg.py rocket.png
  .venv/Scripts/python.exe presentation/png_to_svg.py rocket.png --fill "#0066d9" --smooth 0
  .venv/Scripts/python.exe presentation/png_to_svg.py logo.png --ink light   # white art
"""
import argparse
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from PIL import Image


def rdp(pts, eps):
    """Ramer–Douglas–Peucker, iterative (long contours blow the recursion limit)"""
    n = len(pts)
    if n < 3:
        return pts
    keep = np.zeros(n, bool)
    keep[0] = keep[-1] = True
    stack = [(0, n - 1)]
    while stack:
        i0, i1 = stack.pop()
        if i1 <= i0 + 1:
            continue
        a, b = pts[i0], pts[i1]
        ab = b - a
        L = np.hypot(*ab)
        seg = pts[i0 + 1:i1]
        if L < 1e-12:
            d = np.hypot(*(seg - a).T)
        else:
            v = a - seg          # explicit 2-D cross: np.cross on 2-vectors
            d = np.abs(ab[0] * v[:, 1] - ab[1] * v[:, 0]) / L   # is deprecated
        j = int(np.argmax(d))
        if d[j] > eps:
            k = i0 + 1 + j
            keep[k] = True
            stack += [(i0, k), (k, i1)]
    return pts[keep]


def catmull_rom_bezier(p, tension=1.0):
    """closed Catmull–Rom through `p`, as SVG cubic segments"""
    n = len(p)
    d = [f"M {p[0][0]:.2f} {p[0][1]:.2f}"]
    for i in range(n):
        p0, p1, p2, p3 = p[(i - 1) % n], p[i], p[(i + 1) % n], p[(i + 2) % n]
        c1 = p1 + (p2 - p0) / 6.0 * tension
        c2 = p2 - (p3 - p1) / 6.0 * tension
        d.append(f"C {c1[0]:.2f} {c1[1]:.2f} {c2[0]:.2f} {c2[1]:.2f} "
                 f"{p2[0]:.2f} {p2[1]:.2f}")
    d.append("Z")
    return " ".join(d)


def polyline_path(p):
    d = [f"M {p[0][0]:.2f} {p[0][1]:.2f}"]
    d += [f"L {q[0]:.2f} {q[1]:.2f}" for q in p[1:]]
    d.append("Z")
    return " ".join(d)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--out", default=None)
    ap.add_argument("--ink", default="dark", choices=["dark", "light", "alpha"],
                    help="what counts as the artwork: dark pixels (default), "
                         "light pixels, or anything non-transparent")
    ap.add_argument("--threshold", type=float, default=0.5,
                    help="0..1 luminance cut between ink and background")
    ap.add_argument("--fill", default=None,
                    help="output colour; default = the artwork's own mean colour")
    ap.add_argument("--simplify", type=float, default=0.6,
                    help="RDP tolerance in source pixels; higher = fewer nodes")
    ap.add_argument("--smooth", type=float, default=1.0,
                    help="Catmull-Rom tension; 0 emits straight polygons")
    ap.add_argument("--min-area", type=float, default=12.0,
                    help="drop contours enclosing fewer than this many px^2 "
                         "(kills speckle and JPEG dirt)")
    ap.add_argument("--pad", type=float, default=2.0, help="viewBox padding, px")
    ap.add_argument("--size", type=float, default=None,
                    help="width/height attribute; default = the traced size")
    args = ap.parse_args()

    im = Image.open(args.image)
    rgba = np.asarray(im.convert("RGBA"), float) / 255.0
    rgb, alpha = rgba[..., :3], rgba[..., 3]
    # composite onto white first: a semi-transparent edge otherwise reads as
    # dark ink and the trace grows a halo
    lum = (rgb * [0.2126, 0.7152, 0.0722]).sum(-1) * alpha + (1 - alpha)

    if args.ink == "alpha":
        mask = alpha > 0.5
    elif args.ink == "dark":
        mask = lum < args.threshold
    else:
        mask = lum > args.threshold
    if not mask.any():
        raise SystemExit("nothing matched --ink/--threshold; try --ink light "
                         "or a different --threshold")

    default_fill = "#000000"
    sel = mask & (alpha > 0.5)
    if sel.any():
        default_fill = "#%02x%02x%02x" % tuple(
            int(round(255 * c)) for c in rgb[sel].mean(0))
    fill = args.fill or default_fill

    # sub-pixel boundary at the 0.5 iso-level of the binary mask
    fig = plt.figure()
    cs = plt.contour(mask.astype(float), levels=[0.5])
    segs = [np.asarray(s, float) for s in cs.allsegs[0]]
    plt.close(fig)

    paths, kept = [], 0
    for s in segs:
        if len(s) < 4:
            continue
        # shoelace area, as a size filter and to drop degenerate contours
        area = abs(np.dot(s[:, 0], np.roll(s[:, 1], -1))
                   - np.dot(s[:, 1], np.roll(s[:, 0], -1))) / 2.0
        if area < args.min_area:
            continue
        if np.allclose(s[0], s[-1]):
            s = s[:-1]
        p = rdp(s, args.simplify)
        if len(p) < 3:
            continue
        paths.append(catmull_rom_bezier(p, args.smooth) if args.smooth > 0
                     else polyline_path(p))
        kept += 1

    if not paths:
        raise SystemExit("no contours survived --min-area / --simplify")

    allpts = np.vstack([np.asarray(s) for s in segs if len(s) >= 4])
    x0, y0 = allpts.min(0) - args.pad
    x1, y1 = allpts.max(0) + args.pad
    w, h = x1 - x0, y1 - y0
    sw = args.size or w
    sh = sw * h / w

    d = " ".join(paths)
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{sw:.1f}" '
        f'height="{sh:.1f}" viewBox="{x0:.2f} {y0:.2f} {w:.2f} {h:.2f}">\n'
        f'  <path d="{d}" fill="{fill}" fill-rule="evenodd"/>\n'
        f'</svg>\n')

    out = args.out or os.path.splitext(args.image)[0] + ".svg"
    with open(out, "w", encoding="utf-8") as f:
        f.write(svg)
    nodes = sum(p.count("C") + p.count("L") for p in paths)
    print(f"wrote {out}  ({kept} contour(s), {nodes} nodes, fill {fill}, "
          f"viewBox {w:.0f}x{h:.0f}, {os.path.getsize(out)/1024:.1f} kB)")


if __name__ == "__main__":
    main()
