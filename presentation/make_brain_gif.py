"""
make_brain_gif.py — clean, loopable widefield ΔF/F GIF for a slide schematic.

No axes, no titles, no colourbar: just the masked brain with the activity
overlay, so it can be dropped straight into a PowerPoint block diagram. The
anatomy is a soft-masked grayscale mean image; activity is baseline-subtracted
ΔF/F in RdBu_r, alpha-ramped by |ΔF/F| so quiet cortex stays anatomical.

By default it plays a full OPEN-LOOP trial across the whole stimulation window
and draws a laser spot on the controlled site whose brightness follows the
REAL command trace for that trial (`U`), so the "light on" graphic cannot
disagree with the data — when the command is zero the spot is off.

Frames come from the same SVD bundle the videos use, so the GIF is guaranteed
to match what the talk video shows.

Run:
  .venv/Scripts/python.exe presentation/make_brain_gif.py --session m13
  .venv/Scripts/python.exe presentation/make_brain_gif.py --session m13 --no-light
  .venv/Scripts/python.exe presentation/make_brain_gif.py --px 360 --step 3
"""
import argparse
import os
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gif_utils import save_gif, tsmooth

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")
# rendered media all lands in talk/ so the deck has one place to pull from
MEDIA = os.path.join(ROOT, "talk")
os.makedirs(MEDIA, exist_ok=True)

BG_HEX = {"white": "#ffffff", "bone": "#f5f2ec", "lavender": "#f0eaf8",
          "dark": "#15191f"}


def _font(px):
    """a legible sans at GIF scale; PIL's built-in bitmap font is too small"""
    for name in ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            continue
    try:
        return ImageFont.load_default(size=px)
    except TypeError:
        return ImageFont.load_default()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session", default="m13")
    ap.add_argument("--cond", default="OL", choices=["OL", "CL"],
                    help="open- or closed-loop trial (default OL: a fixed "
                         "command held across the whole stimulation window)")
    ap.add_argument("--trial", type=int, default=None,
                    help="explicit trial index; overrides --cond")
    ap.add_argument("--px", type=int, default=460, help="output size in pixels")
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--step", type=int, default=1, help="use every Nth data frame; "
                         "1 = half real-time playback at 20 fps")
    ap.add_argument("--t0", type=float, default=-1.0, help="start time (s re onset)")
    ap.add_argument("--t1", type=float, default=4.0, help="end time (s re onset)")
    ap.add_argument("--bg", default="white", choices=sorted(BG_HEX) + ["transparent"])
    ap.add_argument("--loop", default="forward", choices=["forward", "pingpong"])
    ap.add_argument("--roi", action="store_true", help="draw the controlled-ROI ring")
    ap.add_argument("--no-light", dest="light", action="store_false",
                    help="omit the laser spot and the LASER ON badge")
    ap.add_argument("--no-badge", dest="badge", action="store_false",
                    help="keep the laser spot but drop the corner badge")
    ap.add_argument("--light-color", default="#39c6ff", help="laser spot hue")
    ap.add_argument("--tsmooth", type=int, default=3,
                    help="moving-average window over data frames; removes the "
                         "per-frame shot noise that reads as flicker (0/1 = off)")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    from scipy import ndimage

    z = np.load(os.path.join(ASSETS, f"demo_data_{args.session}.npz"),
                allow_pickle=True)
    D = {k: z[k] for k in z.files}
    Uf, mimg, roi = D["U_ds"], D["mimg"], D["roi"]
    VWIN, Y, LOOP, CMD = D["VWIN"], D["Y"], D["LOOP"], D["U"]
    PRE, FS, DUR = int(D["PRE"]), float(D["FS"]), float(D["DUR"])
    n = mimg.shape[0]
    nt = VWIN.shape[2]
    t = (np.arange(nt) - PRE) / FS

    # ---- mask: reuse the hand-drawn one when it exists (same as the videos) --
    mask_file = os.path.join(ASSETS, f"mask_{args.session}.npy")
    if os.path.exists(mask_file):
        mask = np.load(mask_file).astype(bool)
    else:
        mask = ndimage.binary_fill_holes(mimg > np.percentile(mimg, 15))
        lbl, nl = ndimage.label(mask)
        if nl > 1:
            sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, nl + 1))
            mask = lbl == (1 + int(np.argmax(sizes)))
        mask = ndimage.binary_fill_holes(
            ndimage.gaussian_filter(mask.astype(float), 2.5) > 0.5)
    mimg_safe = np.where(mimg > 1e-3, mimg, np.nan)
    # erode before feathering: the raw mask edge carries dust specks that read
    # as noise once the surround is transparent
    core = ndimage.binary_erosion(mask, iterations=2)
    soft = np.clip(ndimage.gaussian_filter(core.astype(float), 2.0), 0.0, 1.0)
    soft = np.clip((soft - 0.12) / 0.88, 0.0, 1.0)

    # smooth in SVD space: 200 components instead of 19 600 pixels, and the
    # projection is linear so it is identical to smoothing the frames
    VS = tsmooth(np.asarray(VWIN, float), args.tsmooth, axis=2)

    def activity(trial, tau):
        v0 = VS[trial][:, :PRE].mean(axis=1)
        return 100.0 * (Uf @ (VS[trial][:, tau] - v0)).reshape(n, n) / mimg_safe

    # ---- pick a trial: requested condition, strong drive, no motion blow-ups -
    stim = (t >= 0) & (t <= DUR)
    if args.trial is None:
        cand = [i for i in range(Y.shape[0]) if LOOP[i] == args.cond]
        score = [np.abs(np.nanmean(Y[i][stim])) / (1 + np.nanstd(np.diff(Y[i])))
                 for i in cand]
        trial = cand[int(np.argmax(score))]
    else:
        trial = args.trial

    clim = float(np.nanpercentile(
        np.abs(np.concatenate([activity(trial, k)[mask].ravel()
                               for k in range(PRE, nt, 6)])), 94))
    dcmap = plt.get_cmap("RdBu_r"); dnorm = Normalize(-clim, clim)
    # median-filter the anatomy layer only: the mean image is peppered with
    # dust/debris specks that look like noise at slide size (the ΔF/F
    # normalisation still uses the unfiltered mimg)
    mimg_disp = ndimage.gaussian_filter(ndimage.median_filter(mimg, 3), 0.6)
    gnorm = Normalize(np.percentile(mimg_disp[mask], 4),
                      np.percentile(mimg_disp[mask], 99))
    anat = plt.get_cmap("gray")(gnorm(mimg_disp))[..., :3]
    anat = 0.30 + 0.58 * anat

    # ---- laser spot: a radial glow at the target, driven by the real command -
    u = np.nan_to_num(np.asarray(CMD[trial], float), nan=0.0)
    u = np.clip(u / max(float(np.nanmax(u)), 1e-9), 0.0, 1.0)
    u = np.where(u > 0.03, 0.45 + 0.55 * u, 0.0)
    yy, xx = np.mgrid[0:n, 0:n]
    r2 = (xx - float(roi[0])) ** 2 + (yy - float(roi[1])) ** 2
    halo = np.exp(-r2 / (2 * (0.060 * n) ** 2)) * soft
    spot = np.exp(-r2 / (2 * (0.022 * n) ** 2)) * soft
    light_rgb = np.array(matplotlib.colors.to_rgb(args.light_color))
    core_rgb = 0.72 + 0.28 * light_rgb

    transparent = args.bg == "transparent"
    bg_rgb = np.array(matplotlib.colors.to_rgb(BG_HEX["white" if transparent
                                                      else args.bg]))

    taus = [k for k in range(nt) if args.t0 <= t[k] <= args.t1][::max(args.step, 1)]
    if args.loop == "pingpong":
        taus = taus + taus[-2:0:-1]

    frames, lit = [], []
    for tau in taus:
        df = np.nan_to_num(activity(trial, tau), nan=0.0, posinf=0.0, neginf=0.0)
        a_act = (np.clip(np.abs(df) / (0.45 * clim), 0, 1) * soft)[..., None]
        act = dcmap(dnorm(df))[..., :3]
        out = anat * soft[..., None] + bg_rgb * (1 - soft[..., None])
        out = act * a_act + out * (1 - a_act)
        uu = float(u[tau]) if args.light else 0.0
        if uu > 0.02:
            a_h = np.clip(0.80 * uu * halo, 0, 1)[..., None]
            out = out * (1 - a_h) + light_rgb * a_h
            a_c = np.clip(1.00 * uu * spot, 0, 1)[..., None]
            out = out * (1 - a_c) + core_rgb * a_c
        lit.append(uu)
        img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGB")
        img = img.resize((args.px, args.px), Image.LANCZOS)
        if transparent:                   # brain opaque, surround see-through
            al = Image.fromarray((soft * 255).astype(np.uint8), "L").resize(
                (args.px, args.px), Image.LANCZOS)
            img = img.convert("RGBA"); img.putalpha(al)
        frames.append(img)

    ring_c = (225, 31, 191)
    for im, uu in zip(frames, lit):
        d = ImageDraw.Draw(im)
        if args.roi:
            cx, cy = float(roi[0]) / n * args.px, float(roi[1]) / n * args.px
            r = 0.055 * args.px
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ring_c,
                      width=max(2, args.px // 200))
        if args.light and uu > 0.02:
            cx, cy = float(roi[0]) / n * args.px, float(roi[1]) / n * args.px
            rr = 0.075 * args.px
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                      outline=tuple(int(255 * v) for v in light_rgb),
                      width=max(2, args.px // 230))
        if args.light and args.badge and uu > 0.02:
            f = _font(max(11, args.px // 26))
            pad, dot = args.px * 0.045, args.px * 0.016
            col = tuple(int(255 * v) for v in light_rgb)
            d.ellipse([pad, pad, pad + 2 * dot, pad + 2 * dot], fill=col)
            d.text((pad + 2.9 * dot, pad + dot), "LASER ON", font=f, fill=col,
                   anchor="lm")

    out = args.out or os.path.join(MEDIA,
                                   f"brain_wf_{args.session}.gif")
    al = None
    if transparent:
        al = Image.fromarray((soft * 255).astype(np.uint8), "L").resize(
            (args.px, args.px), Image.LANCZOS)
    save_gif(frames, out, fps=args.fps, alpha=al)
    print(f"wrote {out}  ({len(frames)} frames, {args.px}px, "
          f"{os.path.getsize(out)/1e6:.1f} MB, trial {trial} {LOOP[trial]}, "
          f"{sum(1 for v in lit if v > 0.02)} lit frames)")


if __name__ == "__main__":
    main()
