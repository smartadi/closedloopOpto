"""
make_ampmap_gif.py — animate the laser dose / spatial-spread supplementary panel.

ONE image at a time, cross-dissolving into the next as the laser amplitude
climbs, so the inhibition is seen to deepen and spread in place rather than as
a wall of thumbnails. The only text on screen is the amplitude. The last map
dissolves back into the first, so the loop has no seam.

The dissolve blends the DATA (a weighted mean of the two maps), not two
alpha-stacked images — alpha stacking double-darkens through the crossover and
looks muddy.

Maps come straight from `presentation/assets/ampmaps_*.mat`
(export_ampmaps.m -> the same `imp.resp_map` that impulse-analysis/
spatial_spread.m plots), so the animation cannot drift from the paper.

Run:
  .venv/Scripts/python.exe presentation/make_ampmap_gif.py
  .venv/Scripts/python.exe presentation/make_ampmap_gif.py --cmap magma --mark
"""
import argparse
import glob
import os
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gif_utils import save_gif

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")
# rendered media all lands in talk/ so the deck has one place to pull from
MEDIA = os.path.join(ROOT, "talk")
os.makedirs(MEDIA, exist_ok=True)

BG_HEX = {"white": "#ffffff", "bone": "#f5f2ec", "dark": "#15191f"}
INK = {"white": "#15191f", "bone": "#15191f", "dark": "#f2efe9"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mat", default=None, help="ampmaps_*.mat (default: newest)")
    # Blue->red, symmetric about zero, is now the DECK-WIDE map (user, 2026-08-19: "unify
    # the colormap across the gifs ... make them all blue to red"). It matches
    # make_brain_gif.py's RdBu_r/+-clim and talk/make_site_map.m, so a colour means the same
    # thing in every animation. It also fixes a readability inversion in the old default:
    # under `jet` with Normalize(min, 0) the NO-EFFECT background was dark red and the
    # deepest inhibition was green -- i.e. the loudest colour marked where nothing happened.
    # With RdBu_r about zero, white = no effect and deep blue = strong inhibition.
    ap.add_argument("--cmap", default="RdBu_r",
                    help="deck default RdBu_r (blue=inhibition, white=0); "
                         "'jet' reproduces the old supplementary figure")
    ap.add_argument("--sym", dest="sym", action="store_true", default=True,
                    help="scale the colour axis symmetrically about 0 (default)")
    ap.add_argument("--no-sym", dest="sym", action="store_false",
                    help="scale from the data minimum to 0, as the old jet version did")
    ap.add_argument("--px", type=int, default=620, help="output width in pixels")
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--hold", type=int, default=11, help="frames held on each map")
    ap.add_argument("--fade", type=int, default=15, help="frames of cross-dissolve")
    ap.add_argument("--ds", type=int, default=2, help="spatial downsample factor")
    ap.add_argument("--bg", default="white", choices=sorted(BG_HEX))
    ap.add_argument("--label-size", type=float, default=30.0)
    ap.add_argument("--label-color", default=None,
                    help="default: the deck ink colour")
    ap.add_argument("--mark", action="store_true", help="mark the peak pixel")
    ap.add_argument("--mask-open", type=int, default=3,
                    help="opening radius (px) before picking the brain blob")
    ap.add_argument("--mask-erode", type=int, default=2,
                    help="erode the cleaned mask, to pull off the ragged rim")
    ap.add_argument("--keep-blobs", action="store_true",
                    help="skip the cleanup and use load_experiments' raw "
                         "intensity mask as-is")
    ap.add_argument("--no-loop-back", dest="loop_back", action="store_false",
                    help="stop on the strongest amplitude instead of dissolving "
                         "back to the weakest")
    ap.add_argument("--mp4", action="store_true", help="also write an mp4")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    import scipy.io as sio

    path = args.mat
    if path is None:
        hits = sorted(glob.glob(os.path.join(ASSETS, "ampmaps_*.mat")))
        if not hits:
            raise SystemExit("no ampmaps_*.mat in assets — run "
                             "presentation/export_ampmaps.m in MATLAB first")
        path = hits[-1]
    M = sio.loadmat(path)
    maps = M["maps"].astype(float)                 # nr x nc x nAmp
    amps = M["amps_mW"].ravel().astype(float)
    bmask = M["brainMask"].astype(bool)
    mouse, date = str(M["mouse"][0]), str(M["date_str"][0])
    pr, pc = int(M["pr_pk"].ravel()[0]) - 1, int(M["pc_pk"].ravel()[0]) - 1  # MATLAB 1-based

    # `brainMask` from load_experiments.m is a bare intensity cut
    # (mimg > 0.1*max) and picks up bright non-brain junk outside the window:
    # 31 connected components here, of which the brain is 98.7% of the pixels.
    # Cleanup is SUBTRACTIVE only -- resp_map is defined solely on the original
    # mask, so a hole cannot be filled in without inventing data.
    if not args.keep_blobs:
        from scipy import ndimage
        raw = bmask.sum()
        m = bmask
        if args.mask_open > 0:
            k = args.mask_open
            m = ndimage.binary_opening(m, np.ones((k, k)))
        lbl, nl = ndimage.label(m)
        if nl > 1:
            sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, nl + 1))
            m = lbl == (1 + int(np.argmax(sizes)))
        if args.mask_erode > 0:
            m = ndimage.binary_erosion(m, iterations=args.mask_erode)
        print(f"  mask: {nl} component(s) -> brain only, "
              f"{raw} -> {m.sum()} px ({100*(1-m.sum()/raw):.1f}% removed)")
        bmask = m

    # crop to the brain, then downsample: the maps are 560^2 and most of that
    # is background the panel never shows
    rows, cols = np.where(bmask)
    r0, r1 = rows.min(), rows.max() + 1
    c0, c1 = cols.min(), cols.max() + 1
    d = max(args.ds, 1)
    maps = maps[r0:r1, c0:c1][::d, ::d]
    bm = bmask[r0:r1, c0:c1][::d, ::d]
    pr_c, pc_c = (pr - r0) / d, (pc - c0) / d
    maps[~bm] = np.nan
    nA = maps.shape[2]

    # display orientation is TRANSPOSED (brain vertical) and the peak marker
    # swaps coordinates with it — see impulse-analysis/CLAUDE.md
    disp = [maps[:, :, k].T for k in range(nA)]
    if args.sym:
        # symmetric about zero so the map's white point IS zero. With Normalize(min, 0) a
        # diverging colormap gets its blue half stretched over the whole range and its
        # midpoint lands on half-maximum inhibition, which reads as "no effect" in the
        # wrong place.
        c = float(np.nanmax(np.abs(maps)))
        norm = Normalize(-c, c)
    else:
        norm = Normalize(float(np.nanmin(maps)), 0.0)
    cmap = plt.get_cmap(args.cmap).copy()
    cmap.set_bad(alpha=0.0)

    bg = BG_HEX[args.bg]
    ink = args.label_color or INK[args.bg]
    ph, pw = disp[0].shape
    fig_w = args.px / 100.0
    fig_h = fig_w * (ph / pw) + 0.62               # room for the amplitude label
    fig = plt.figure(figsize=(fig_w, fig_h), dpi=100)
    fig.patch.set_facecolor(bg)

    ax = fig.add_axes([0.01, 0.62 / fig_h, 0.98, 1 - 0.70 / fig_h])
    ax.set_xticks([]); ax.set_yticks([]); ax.set_facecolor(bg)
    for s in ax.spines.values():
        s.set_visible(False)
    im = ax.imshow(disp[0], cmap=cmap, norm=norm, interpolation="bilinear")
    ax.set_aspect("equal")
    if args.mark:
        ax.plot(pr_c, pc_c, "+", color="#ffffff", ms=11, mew=2.0)

    lab = fig.text(0.5, 0.30 / fig_h, f"{amps[0]:.2f} mW", ha="center",
                   va="center", fontsize=args.label_size, fontweight="bold",
                   color=ink)

    # ---- schedule: hold on map k, then dissolve k -> k+1 --------------------
    steps = []                                    # (map_a, map_b, blend, label)
    order = list(range(nA)) + ([0] if args.loop_back else [])
    for j in range(len(order)):
        k = order[j]
        steps += [(k, k, 0.0, k)] * args.hold
        if j + 1 < len(order):
            nxt = order[j + 1]
            for f in range(args.fade):
                a = (f + 1) / (args.fade + 1)
                steps.append((k, nxt, a, k if a < 0.5 else nxt))

    frames = []
    for (ka, kb, a, klab) in steps:
        im.set_data(disp[ka] if a == 0.0 else (1 - a) * disp[ka] + a * disp[kb])
        # the label fades out and back in through the crossover rather than
        # two labels overlapping
        lab.set_alpha(1.0 if a == 0.0 else abs(2 * a - 1) ** 0.7)
        lab.set_text(f"{amps[klab]:.2f} mW")
        fig.canvas.draw()
        frames.append(Image.frombytes(
            "RGBA", fig.canvas.get_width_height(),
            bytes(fig.canvas.buffer_rgba())).convert("RGB"))

    stem = f"ampmaps_{mouse}_{date}"
    out = args.out or os.path.join(MEDIA, f"{stem}.gif")
    save_gif(frames, out, fps=args.fps, n_pal_samples=nA * 2)
    print(f"wrote {out}  ({len(frames)} frames, {frames[0].size[0]}x"
          f"{frames[0].size[1]}, {os.path.getsize(out)/1e6:.1f} MB, "
          f"{nA} amplitudes {amps[0]:.2f}–{amps[-1]:.2f} mW, "
          f"{len(frames)/args.fps:.1f} s)")

    if args.mp4:
        import imageio_ffmpeg
        mp4 = out.replace(".gif", ".mp4")
        w, h = frames[0].size
        w -= w % 2; h -= h % 2
        wr = imageio_ffmpeg.write_frames(mp4, (w, h), fps=args.fps, quality=8)
        wr.send(None)
        for fr in frames:
            wr.send(np.asarray(fr)[:h, :w].tobytes())
        wr.close()
        print(f"wrote {mp4} ({os.path.getsize(mp4)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
