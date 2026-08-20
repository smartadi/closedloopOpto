"""make_motion_clip.py -- face/eye camera clips illustrating the arousal states used in the analysis.

The talk claims movement and arousal are brain states that change closed-loop performance, but
the audience has never seen what either actually is. This cuts the raw camera video at windows
the measures themselves flag, with the measure drawn underneath, so the state stops being an
abstraction. Every clip is written as BOTH mp4 and gif (gif for dropping straight into slides).

  motion_high        face camera, strongest SUSTAINED movement bout  (motThresh = 1.5 drawn)
  motion_quiet       face camera, matched still window
  pupil_lowarousal   eye camera, smallest sustained pupil + low motion
  pupil_arousal      eye camera, a dilation event -- the contrast that proves the trace is real

TWO SESSIONS, on purpose. Motion comes from AL_0048 2026-07-15 (the session whose motion trace
the impulse analysis actually uses). The pupil clips come from AL_0033 2025-03-04 exp 1, because
AL_0048's eye camera cannot be segmented: its whole eye interior is dark and the darkest-blob
rule locks onto the crescent shadow between the eyelid glint and the fur, returning a "pupil"
that swings 15 -> 72 px between neighbouring windows. AL_0033 m5's eye.mp4 tracks cleanly on
100% of frames (this is the session presentation/build_cam_movies.py already flags as having a
clear pupil). Do not move the pupil clips back to AL_0048 without re-checking the contact sheet.

⚠ NO SLEEP IN THIS SESSION. Swept at 1 Hz over all 89 min, the pupil is 14.7 px (1st pct) to
19.2 px (99th) with a 15.8 px median -- a constricted baseline the whole time, punctuated by
brief dilations that ride on movement bouts (corr(motion z, pupil d) = +0.23, n = 5341 s). There
is no sustained drowsy episode to cut. `pupil_lowarousal` is therefore the LOW end of a narrow
range, not a sleeping mouse, and is labelled that way on the frame. Do not re-label it "asleep".

Both face cameras here are 30 fps with one facemap motion sample per frame, so frame index ==
motion index. load_experiments does `motion_1(1:2:end)` for its own sessions because those rigs
run the face camera at 2x the blue-frame rate; that decimation is NOT applied here and must not
be -- it would desynchronise video from trace by 2x.

Usage:
  .venv/Scripts/python.exe talk/make_motion_clip.py                 # all four, mp4 + gif
  .venv/Scripts/python.exe talk/make_motion_clip.py --what pupil
  .venv/Scripts/python.exe talk/make_motion_clip.py --scan-only     # report picks, render nothing
"""
import argparse, os, subprocess, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy import ndimage
from PIL import Image
import imageio_ffmpeg
import imageio.v3 as iio

ROOT = r"C:\Users\aditya\Documents\projects\brain_paper"
sys.path.insert(0, os.path.join(ROOT, "presentation"))
from pupil_seg import seg_pupil            # noqa: E402  validated dark-pupil segmentation
from gif_utils import save_gif             # noqa: E402  single global palette (no frame jitter)

UNC   = chr(92) * 2 + "sahale.biostr.washington.edu" + chr(92) + "data" + chr(92) + "Subjects"
MOT_S = os.path.join(UNC, "AL_0048", "2026-07-15", "1")     # motion clips
PUP_S = os.path.join(UNC, "AL_0033", "2025-03-04", "1")     # pupil clips (see header)
MOT_TAG, PUP_TAG = "AL_0048  2026-07-15", "AL_0033  2025-03-04"

# AL_0048's facemap output was copied locally; m5's still lives on the server
MOT_PROC = os.path.join(ROOT, "impulse-analysis", "data", "face_proc.npy")
PUP_PROC = os.path.join(PUP_S, "face_proc.npy")
OUT      = os.path.join(ROOT, "talk")
CACHE    = os.path.join(OUT, "_cache")

FPS    = 30.0
MOTTHR = 1.5          # locked project-wide motion exclusion threshold (z)
EDGE   = 300.0        # ignore the first/last 5 min: mounting at the head, truncation at the tail

BG, TXT, MUTE = "#0b0d12", "#f2f4f8", "#9aa3b2"
HOT, COOL, PUPC = "#ff5a3c", "#4aa3ff", "#ffc857"
FF = imageio_ffmpeg.get_ffmpeg_exe()


# ----------------------------------------------------------------------------- io helpers
def load_motion(proc):
    o = np.load(proc, allow_pickle=True).item()
    m = np.asarray(o["motion"][1], dtype=float)
    return (m - m.mean()) / m.std()


def grab(video, t0, dur, gray=False, scale=None):
    """Decode `dur` seconds of `video` starting at t0.

    -ss before -i seeks on keyframes, which can land up to a GOP early and silently shift the
    video against the trace by ~1 s. Re-encoding the segment first guarantees frame 0 is t0.
    """
    tmp = os.path.join(OUT, "_seg_tmp.mp4")
    vf = []
    if scale: vf.append(f"scale={scale[0]}:{scale[1]}")
    if gray:  vf.append("format=gray")
    cmd = [FF, "-y", "-v", "error", "-ss", f"{t0:.3f}", "-i", video, "-t", f"{dur:.3f}", "-an"]
    if vf: cmd += ["-vf", ",".join(vf)]
    cmd += ["-c:v", "libx264", "-crf", "14", "-pix_fmt", "yuv420p", tmp]
    subprocess.run(cmd, check=True)
    frames = iio.imread(tmp, plugin="FFMPEG")
    os.remove(tmp)
    return frames


def as_gray(f):
    return f if f.ndim == 2 else f[..., :3].mean(-1)


# ----------------------------------------------------------------------------- window picking
def rolling(x, dur):
    """mean of x over each `dur`-second window (x sampled at FPS), plus the window start times."""
    W = max(1, int(dur * FPS))
    c = np.convolve(x, np.ones(W) / W, mode="valid")
    return c, np.arange(c.size) / FPS


def pick_motion(z, dur):
    """Strongest SUSTAINED bout, and a matched still window.

    Sustained, not peak: a single-frame spike is a twitch, and the clip is meant to show what a
    high-motion STATE looks like.
    """
    c, t = rolling(z, dur)
    ok = (t > EDGE) & (t < t[-1] - EDGE)
    hi = int(np.argmax(np.where(ok, c, -np.inf)))
    lo = int(np.argmin(np.where(ok, c, np.inf)))
    return (float(t[hi]), float(c[hi])), (float(t[lo]), float(c[lo]))


def pupil_sweep(force=False):
    """Pupil diameter at 1 Hz across the whole pupil session, cached.

    Segmenting 89 min frame-by-frame is unnecessary to CHOOSE a window; 1 Hz resolves the states
    and the chosen window is then segmented at full rate for the render.
    """
    os.makedirs(CACHE, exist_ok=True)
    f = os.path.join(CACHE, "pupil_sweep_AL_0033_2025-03-04_1.npz")
    if os.path.exists(f) and not force:
        d = np.load(f)
        return d["diam"], d["motz"]

    W, H = 160, 242
    print("[pupil] decoding the eye video at 1 Hz (once, then cached) ...")
    cmd = [FF, "-nostdin", "-loglevel", "error", "-i", os.path.join(PUP_S, "eye.mp4"),
           "-vf", f"fps=1,scale={W}:{H},format=gray", "-f", "rawvideo", "-pix_fmt", "gray",
           "pipe:1"]
    a = np.frombuffer(subprocess.run(cmd, capture_output=True).stdout, np.uint8)
    n = a.size // (W * H)
    fr = a[: n * W * H].reshape(n, H, W)

    diam, prev = np.full(n, np.nan), None
    for i in range(n):
        d, cx, cy, _ = seg_pupil(fr[i], prev=prev)
        prev = (cx, cy) if np.isfinite(cx) else None
        diam[i] = d

    z = load_motion(PUP_PROC)
    nb = min(n, z.size // int(FPS))
    motz = np.full(n, np.nan)
    motz[:nb] = z[: nb * int(FPS)].reshape(nb, int(FPS)).mean(1)

    np.savez(f, diam=diam, motz=motz)
    g = np.isfinite(diam[:nb]) & np.isfinite(motz[:nb])
    print(f"[pupil] {n} s swept | trackable {np.isfinite(diam).mean():.3f} | "
          f"d {np.nanpercentile(diam,1):.1f}-{np.nanpercentile(diam,99):.1f} px "
          f"(median {np.nanmedian(diam):.1f}) | corr(motion, pupil) "
          f"{np.corrcoef(motz[:nb][g], diam[:nb][g])[0,1]:+.3f}")
    return diam, motz


def window_diam(t0, dur, scale=(160, 242)):
    """Full-rate pupil trace for one window (the 1 Hz sweep aliases blinks away)."""
    fr = grab(os.path.join(PUP_S, "eye.mp4"), t0, dur, gray=True, scale=scale)
    d, prev = np.full(len(fr), np.nan), None
    for i in range(len(fr)):
        v, cx, cy, _ = seg_pupil(as_gray(fr[i]), prev=prev)
        prev = (cx, cy) if np.isfinite(cx) else None
        d[i] = v
    return d


def stability(d):
    """(fraction of frames within 25% of the window median, min/median ratio).

    A BLINK makes seg_pupil return a small bogus blob -- the lid occludes the pupil, so the
    darkest compact thing left is a sliver -- which shows up as a brief COLLAPSE to about a
    third of the running value. That is an eyelid artefact and must not be shown as a dilation.

    Two numbers, because the fraction alone is not enough: a 1.5 s blink in a 10 s window is
    only 15% of frames, so a "92% stable" window can still open on a closed eye (it did, at
    t = 4786 s -- 15.9 px against a 44.1 px median). The min/median ratio catches the collapse
    however brief it is.
    """
    m = np.nanmedian(d)
    if not np.isfinite(m) or m <= 0:
        return 0.0, 0.0
    frac = float(np.nanmean(np.abs(d - m) < 0.25 * m))
    return frac, float(np.nanmin(d) / m)


def pick_arousal(diam, dur, ntry=8, min_stab=0.97, min_ratio=0.60, verbose=True):
    """Most dilated BLINK-FREE window: rank on diameter, then slide to dodge the blink.

    Two failure modes had to be handled in turn.

    (1) Rank on diameter alone and the winner is the eye REOPENING after a blink: the first
        attempt picked t = 4786 s, where the trace ran 15.9 -> 45 px in 1.5 s. That is an
        eyelid, not a pupil.

    (2) Reject any window containing a blink and the real dilation goes with it. t = 4786 s
        has a genuinely dilated pupil (21.4 px median against this session's 15.8 px baseline)
        AND a blink in its first 1.5 s -- discarding it dropped the search to t = 3829 s, whose
        pupil is 15.3 px, i.e. no dilation at all. A clip labelled "arousal" showing a baseline
        pupil is worse than no clip.

    So: keep the high-diameter candidates, and slide the window start in 1 s steps across the
    dilation until the segmented trace is blink-free. The dilation is many seconds long; the
    blink is not.
    """
    W = max(1, int(dur))
    ds = np.convolve(np.nan_to_num(diam, nan=np.nanmedian(diam)), np.ones(W) / W, mode="valid")
    t  = np.arange(ds.size, dtype=float)
    ok = (t > EDGE) & (t < t[-1] - EDGE)
    order = [int(i) for i in np.argsort(np.where(ok, ds, -np.inf))[::-1]]

    seen, best = [], None
    for i in order:
        if any(abs(i - j) < dur * 2 for j in seen):
            continue
        seen.append(i)
        for off in range(-int(dur), int(dur) + 1):
            t0 = float(t[i]) + off
            if t0 < EDGE or t0 + dur > t[-1] - EDGE:
                continue
            d = window_diam(t0, dur)
            frac, ratio = stability(d)
            med = float(np.nanmedian(d))
            if frac >= min_stab and ratio >= min_ratio:
                if verbose:
                    print(f"   arousal t={t0:6.0f}s (cand {t[i]:.0f}{off:+d})  d {med:5.1f} px  "
                          f"stable {frac:.2f}  min/med {ratio:.2f}  <- blink-free")
                if best is None or med > best[1]:
                    best = (t0, med, frac)
                break
            if verbose and off == 0:
                print(f"   arousal cand t={t[i]:6.0f}s  d {med:5.1f} px  stable {frac:.2f}  "
                      f"min/med {ratio:.2f}   <- blink, sliding")
        if len(seen) >= ntry:
            break
    if best is None:
        raise RuntimeError("no blink-free arousal window found -- raise ntry or relax min_ratio")
    return best


def pick_pupil(diam, motz, dur):
    """Low-arousal window (smallest sustained pupil AND low motion) and a dilation event.

    Scored on a `dur`-second mean so a single mis-segmented second cannot win. The arousal pick
    maximises the pupil instead -- it exists to show the trace MOVES, which is the only evidence
    on offer that the small baseline is a real constricted pupil and not a segmentation floor.
    """
    W = max(1, int(dur))
    k = np.ones(W) / W
    ds = np.convolve(np.nan_to_num(diam, nan=np.nanmedian(diam)), k, mode="valid")
    ms = np.convolve(np.nan_to_num(motz, nan=0.0), k, mode="valid")
    t  = np.arange(ds.size, dtype=float)
    ok = (t > EDGE) & (t < t[-1] - EDGE)

    dz = (ds - np.median(ds)) / (np.std(ds) + 1e-9)
    mz = (ms - np.median(ms)) / (np.std(ms) + 1e-9)
    lo = int(np.argmin(np.where(ok, dz + mz, np.inf)))      # same score as build_ff_data.py
    return float(t[lo]), float(ds[lo]), float(ms[lo])


# ----------------------------------------------------------------------------- rendering
def _write(frames, stem, gif_fps, gif_width):
    """One frame list -> mp4 (full rate) + gif (subsampled, downscaled, one shared palette)."""
    h, w = frames[0].shape[:2]
    w2, h2 = w - w % 2, h - h % 2
    mp4 = os.path.join(OUT, stem + ".mp4")
    wr = imageio_ffmpeg.write_frames(mp4, (w2, h2), fps=FPS, quality=8, macro_block_size=1)
    wr.send(None)
    for f in frames:
        wr.send(np.ascontiguousarray(f[:h2, :w2, :3]))
    wr.close()

    step = max(1, int(round(FPS / gif_fps)))
    gh   = int(round(h * gif_width / w))
    pil  = [Image.fromarray(f[..., :3]).resize((gif_width, gh), Image.LANCZOS)
            for f in frames[::step]]
    gif  = os.path.join(OUT, stem + ".gif")
    save_gif(pil, gif, fps=FPS / step, n_pal_samples=24)
    print(f"  {mp4}  ({os.path.getsize(mp4)/1e6:.1f} MB)")
    print(f"  {gif}  ({os.path.getsize(gif)/1e6:.1f} MB, {len(pil)} frames @ {FPS/step:.0f} fps)")
    return mp4, gif


def _fig(dpi, figsize=(7.2, 6.2), vbox=(0.06, 0.34, 0.88, 0.58), tbox=(0.14, 0.10, 0.80, 0.20)):
    """`vbox`/`tbox` are the video and trace axes. The eye frame is portrait (320x484), so a
    landscape figure letterboxes it into a thumbnail -- pupil clips pass a taller figure."""
    fig = plt.figure(figsize=figsize, dpi=dpi, facecolor=BG)
    axv = fig.add_axes(list(vbox)); axv.set_facecolor(BG); axv.axis("off")
    axt = fig.add_axes(list(tbox)); axt.set_facecolor(BG)
    for s in ("top", "right"): axt.spines[s].set_visible(False)
    for s in ("bottom", "left"): axt.spines[s].set_color(MUTE)
    axt.tick_params(colors=MUTE, labelsize=8)
    return fig, axv, axt


def _rgb(fig):
    fig.canvas.draw()
    return np.asarray(fig.canvas.buffer_rgba())[..., :3].copy()


def render_motion(t0, dur, z, label, args):
    i0 = int(round(t0 * FPS))
    frames = grab(os.path.join(MOT_S, "face.mp4"), t0, dur)
    n  = min(len(frames), z.size - i0)
    zt = z[i0:i0 + n]
    t  = np.arange(n) / FPS
    col = HOT if label == "high" else COOL

    fig, axv, axt = _fig(args.dpi)
    im = axv.imshow(frames[0], cmap="gray", vmin=0, vmax=255)
    axt.axhline(MOTTHR, color=MUTE, lw=1.0, ls="--")
    axt.text(t[-1], MOTTHR, f"  motion threshold (z = {MOTTHR})", color=MUTE,
             fontsize=8, va="bottom", ha="right")
    axt.plot(t, zt, color=MUTE, lw=0.8, alpha=0.35)
    (ln,) = axt.plot([], [], color=col, lw=1.6)
    (pt,) = axt.plot([], [], "o", color=col, ms=4)
    axt.set_xlim(t[0], t[-1]); axt.set_ylim(min(-1.0, zt.min() - 0.5), max(2.5, zt.max() * 1.08))
    axt.set_xlabel("time (s)", color=MUTE, fontsize=9)
    axt.set_ylabel("face motion (z)", color=MUTE, fontsize=9)
    fig.text(0.06, 0.975, "HIGH MOTION" if label == "high" else "QUIET",
             color=TXT, fontsize=13, va="top", weight="bold")
    fig.text(0.94, 0.975, f"{MOT_TAG}  face camera, 30 fps",
             color=MUTE, fontsize=8, va="top", ha="right")
    badge = fig.text(0.90, 0.355, "", color=HOT, fontsize=11, weight="bold",
                     ha="right", va="bottom")

    out = []
    for k in range(n):
        im.set_data(frames[k])
        ln.set_data(t[:k + 1], zt[:k + 1])
        pt.set_data([t[k]], [zt[k]])
        badge.set_text("above threshold" if zt[k] > MOTTHR else "")
        out.append(_rgb(fig))
    plt.close(fig)
    print(f"[motion-{label}] t={t0:.1f}s  mean z {zt.mean():+.2f}  peak {zt.max():+.2f}")
    return _write(out, f"motion_{label}_t{t0:.0f}", args.gif_fps, args.gif_width)


def render_pupil(t0, dur, label, pct, args):
    frames = grab(os.path.join(PUP_S, "eye.mp4"), t0, dur, gray=True)
    n = len(frames)
    t = np.arange(n) / FPS

    diam, masks, prev = np.full(n, np.nan), [], None
    for k in range(n):
        d, cx, cy, m = seg_pupil(as_gray(frames[k]), prev=prev)
        prev = (cx, cy) if np.isfinite(cx) else None
        diam[k] = d
        masks.append(m)
    good = np.isfinite(diam)
    # short dropouts are segmentation misses, not real pupil changes -- bridge, then smooth
    if good.sum() >= 2:
        diam = np.interp(np.arange(n), np.flatnonzero(good), diam[good])
    diam = ndimage.median_filter(diam, size=5)

    hot = label == "arousal"
    fig, axv, axt = _fig(args.dpi, figsize=(4.6, 7.0),
                         vbox=(0.02, 0.30, 0.96, 0.62), tbox=(0.19, 0.085, 0.76, 0.17))
    im = axv.imshow(as_gray(frames[0]), cmap="gray", vmin=0, vmax=255)
    ctr = axv.contour(masks[0].astype(float), levels=[0.5], colors=[PUPC], linewidths=1.5)
    axt.plot(t, diam, color=MUTE, lw=0.8, alpha=0.35)
    (ln,) = axt.plot([], [], color=PUPC, lw=1.6)
    (pt,) = axt.plot([], [], "o", color=PUPC, ms=4)
    axt.set_xlim(t[0], t[-1])
    pad = max(0.8, 0.18 * np.ptp(diam))
    axt.set_ylim(diam.min() - pad, diam.max() + pad)
    axt.set_xlabel("time (s)", color=MUTE, fontsize=9)
    axt.set_ylabel("pupil diameter (px)", color=MUTE, fontsize=9)
    fig.text(0.04, 0.982, "AROUSAL — pupil dilates" if hot else "LOW AROUSAL — constricted pupil",
             color=TXT, fontsize=12, va="top", weight="bold")
    # state the session-wide percentile on the frame: without it a small pupil is just a small
    # pupil, and this session's whole range is narrow (see the module header)
    fig.text(0.04, 0.951, f"{pct:.0f}th percentile of this session's pupil range",
             color=MUTE, fontsize=8.5, va="top")
    fig.text(0.04, 0.928, f"{PUP_TAG}  eye camera, 30 fps",
             color=MUTE, fontsize=8, va="top")

    out = []
    for k in range(n):
        im.set_data(as_gray(frames[k]))
        for c in (ctr.collections if hasattr(ctr, "collections") else [ctr]):
            c.remove()
        ctr = axv.contour(masks[k].astype(float), levels=[0.5], colors=[PUPC], linewidths=1.5)
        ln.set_data(t[:k + 1], diam[:k + 1])
        pt.set_data([t[k]], [diam[k]])
        out.append(_rgb(fig))
    plt.close(fig)
    print(f"[pupil-{label}] t={t0:.1f}s  d {np.median(diam):.1f} px "
          f"({diam.min():.1f}-{diam.max():.1f})  tracked {good.mean():.2f}")
    return _write(out, f"pupil_{label}_t{t0:.0f}", args.gif_fps, args.gif_width)


# ----------------------------------------------------------------------------- main
if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--what", choices=["motion", "pupil", "both"], default="both")
    ap.add_argument("--dur", type=float, default=6.0, help="motion clip length (s)")
    ap.add_argument("--pupil-dur", type=float, default=10.0)
    ap.add_argument("--gif-fps", type=float, default=15.0)
    ap.add_argument("--gif-width", type=int, default=620)
    ap.add_argument("--pupil-gif-width", type=int, default=460,
                    help="pupil frames are portrait, so the same width costs far more bytes")
    ap.add_argument("--dpi", type=int, default=110)
    ap.add_argument("--refresh-sweep", action="store_true")
    ap.add_argument("--scan-only", action="store_true")
    a = ap.parse_args()

    if a.what in ("motion", "both"):
        z = load_motion(MOT_PROC)
        print(f"[motion] {z.size} samples ({z.size / FPS / 60:.1f} min)")
        (thi, zhi), (tlo, zlo) = pick_motion(z, a.dur)
        print(f"[pick] high t={thi:.1f}s (z {zhi:+.2f}) | quiet t={tlo:.1f}s (z {zlo:+.2f})")
        if not a.scan_only:
            render_motion(thi, a.dur, z, "high", a)
            render_motion(tlo, a.dur, z, "quiet", a)

    if a.what in ("pupil", "both"):
        diam, motz = pupil_sweep(force=a.refresh_sweep)
        tlo, dlo, mlo = pick_pupil(diam, motz, a.pupil_dur)
        plo = 100.0 * float(np.nanmean(diam < dlo))
        print(f"[pick] low-arousal t={tlo:.0f}s  d {dlo:.1f} px ({plo:.0f}th pct)  "
              f"motion z {mlo:+.2f}")
        thi, dhi, sthi = pick_arousal(diam, a.pupil_dur)
        phi = 100.0 * float(np.nanmean(diam < dhi))
        print(f"[pick] arousal     t={thi:.0f}s  d {dhi:.1f} px ({phi:.0f}th pct)  "
              f"stable {sthi:.2f}")
        if not a.scan_only:
            a.gif_width = a.pupil_gif_width
            render_pupil(tlo, a.pupil_dur, "lowarousal", plo, a)
            render_pupil(thi, a.pupil_dur, "arousal", phi, a)
