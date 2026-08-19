"""
make_ampmap_gif.py — animate the laser dose / spatial-spread supplementary panel.

One response map per laser amplitude (trial-averaged ΔF/F, baseline −500→0 ms
vs peak 0→+200 ms), revealed one at a time in ascending power, so the audience
watches the inhibition deepen and spread. The final frame is the supplementary
figure itself.

Maps come straight from `presentation/assets/ampmaps_*.mat`
(export_ampmaps.m -> the same `imp.resp_map` that impulse-analysis/
spatial_spread.m plots), so the animation cannot drift from the paper.

Run:
  .venv/Scripts/python.exe presentation/make_ampmap_gif.py
  .venv/Scripts/python.exe presentation/make_ampmap_gif.py --cmap magma_r --cols 3
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
    ap.add_argument("--cmap", default="jet",
                    help="'jet' matches the supplementary figure; 'magma_r' or "
                         "'viridis_r' read better on a projector")
    ap.add_argument("--cols", type=int, default=3)
    ap.add_argument("--px", type=int, default=980, help="output width in pixels")
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--fade", type=int, default=9, help="frames per panel fade-in")
    ap.add_argument("--hold", type=int, default=7, help="frames between panels")
    ap.add_argument("--end-hold", type=int, default=55,
                    help="frames on the completed figure before looping")
    ap.add_argument("--ds", type=int, default=2, help="spatial downsample factor")
    ap.add_argument("--bg", default="white", choices=sorted(BG_HEX))
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
    clim = (float(np.nanmin(maps)), 0.0)
    norm = Normalize(*clim)
    cmap = plt.get_cmap(args.cmap).copy()
    cmap.set_bad(alpha=0.0)

    bg, ink = BG_HEX[args.bg], INK[args.bg]
    ncol = max(args.cols, 1)
    nrow = int(np.ceil(nA / ncol))
    ph, pw = disp[0].shape
    aspect = ph / pw
    fig_w = args.px / 100.0
    fig_h = fig_w * (nrow * aspect / ncol) * 1.10 + 1.35
    fig = plt.figure(figsize=(fig_w, fig_h), dpi=100)
    fig.patch.set_facecolor(bg)

    top, bot = 0.885, 0.105
    gap = 0.012
    cw = (0.96 - (ncol - 1) * gap) / ncol
    ch = (top - bot - (nrow - 1) * gap) / nrow
    ims, labs = [], []
    for k in range(nA):
        r, c = divmod(k, ncol)
        ax = fig.add_axes([0.02 + c * (cw + gap),
                           top - ch - r * (ch + gap), cw, ch])
        ax.set_xticks([]); ax.set_yticks([]); ax.set_facecolor(bg)
        for s in ax.spines.values():
            s.set_visible(False)
        im = ax.imshow(disp[k], cmap=cmap, norm=norm, interpolation="bilinear",
                       alpha=0.0)
        ax.plot(pr_c, pc_c, "+", color="#ffffff", ms=9, mew=1.8, alpha=0.0)
        ax.set_aspect("equal")
        labs.append(ax.text(0.5, 1.012, f"{amps[k]:.2f} mW", transform=ax.transAxes,
                            ha="center", va="bottom", fontsize=12,
                            fontweight="bold", color=ink, alpha=0.0))
        ims.append((im, ax.lines[0]))

    fig.text(0.5, 0.955, "Inhibition deepens and spreads with laser power",
             ha="center", va="center", fontsize=17, fontweight="bold", color=ink)
    sub = fig.text(0.5, 0.915, f"{mouse} · {date} · mean ΔF/F, 0–200 ms after onset",
                   ha="center", va="center", fontsize=11, color=ink, alpha=0.65)

    cax = fig.add_axes([0.34, 0.048, 0.32, 0.021])
    cb = fig.colorbar(plt.cm.ScalarMappable(norm=norm, cmap=cmap), cax=cax,
                      orientation="horizontal")
    cb.set_label("ΔF/F (%)", fontsize=11, color=ink, labelpad=2)
    cb.ax.tick_params(colors=ink, labelsize=10, length=3)
    cb.outline.set_visible(False)

    # ---- frame schedule: each panel fades in, then the figure holds ---------
    frames = []
    per = args.fade + args.hold
    total = nA * per + args.end_hold
    for f in range(total):
        for k in range(nA):
            a = float(np.clip((f - k * per) / max(args.fade, 1), 0.0, 1.0))
            ims[k][0].set_alpha(a)
            ims[k][1].set_alpha(a)
            labs[k].set_alpha(a)
        fig.canvas.draw()
        frames.append(Image.frombytes(
            "RGBA", fig.canvas.get_width_height(),
            bytes(fig.canvas.buffer_rgba())).convert("RGB"))

    stem = f"ampmaps_{mouse}_{date}"
    out = args.out or os.path.join(MEDIA, f"{stem}.gif")
    save_gif(frames, out, fps=args.fps)
    print(f"wrote {out}  ({len(frames)} frames, {frames[0].size[0]}x"
          f"{frames[0].size[1]}, {os.path.getsize(out)/1e6:.1f} MB, "
          f"{nA} amplitudes {amps[0]:.2f}–{amps[-1]:.2f} mW)")

    if args.mp4:
        import imageio_ffmpeg
        mp4 = out.replace(".gif", ".mp4")
        w, h = frames[0].size
        wr = imageio_ffmpeg.write_frames(mp4, (w - w % 2, h - h % 2),
                                         fps=args.fps, quality=8)
        wr.send(None)
        for fr in frames:
            wr.send(np.asarray(fr)[:h - h % 2, :w - w % 2].tobytes())
        wr.close()
        print(f"wrote {mp4} ({os.path.getsize(mp4)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
