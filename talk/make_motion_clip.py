"""make_motion_clip.py -- face-camera clips illustrating the motion state used in the analysis.

The talk claims "high motion" is a brain state that changes closed-loop performance, but the
audience has never seen what the motion regressor actually is. This cuts the face video at the
windows the regressor itself flags, with the trace drawn underneath and the locked exclusion
threshold (motThresh = 1.5, z-scored) marked -- so "high motion" stops being an abstraction.

Source: AL_0048 2026-07-15 exp 1. face.mp4 is 30 fps and facemap's motion[1] has exactly one
sample per frame, so frame index == motion index (no resampling). Note load_experiments does
`motion_1(1:2:end)` for its own sessions because those face cameras run at 2x the blue-frame
rate; that decimation is NOT applied here and must not be -- it would desynchronise video
from trace.

Usage:
  .venv/Scripts/python.exe talk/make_motion_clip.py            # high-motion + quiet clips
  .venv/Scripts/python.exe talk/make_motion_clip.py --t 961.8  # cut at an arbitrary time
"""
import argparse, os, subprocess
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter
import imageio_ffmpeg
import imageio.v3 as iio

# matplotlib shells out to a bare "ffmpeg" unless told otherwise, and there is none on PATH here
matplotlib.rcParams["animation.ffmpeg_path"] = imageio_ffmpeg.get_ffmpeg_exe()

ROOT   = r"C:\Users\aditya\Documents\projects\brain_paper"
SERVER = chr(92)*2 + "sahale.biostr.washington.edu"   # UNC prefix, built explicitly
VIDEO  = SERVER + r"\data\Subjects\AL_0048\2026-07-15\1\face.mp4"
PROC   = os.path.join(ROOT, "impulse-analysis", "data", "face_proc.npy")
OUT    = os.path.join(ROOT, "talk")
FPS    = 30.0
MOTTHR = 1.5          # locked project-wide motion exclusion threshold (z)

BG, TXT, MUTE = "#0b0d12", "#f2f4f8", "#9aa3b2"
HOT, COOL     = "#ff5a3c", "#4aa3ff"


def load_motion():
    o = np.load(PROC, allow_pickle=True).item()
    m = np.asarray(o["motion"][1], dtype=float)
    return (m - m.mean()) / m.std()


def grab(t0, dur):
    """Decode `dur` seconds starting at t0. -ss before -i seeks on keyframes fast; the
    re-encode to a temp file guarantees the first returned frame really is t0 (a raw
    keyframe seek can land up to a GOP early and silently shift the trace by ~1 s)."""
    ff  = imageio_ffmpeg.get_ffmpeg_exe()
    tmp = os.path.join(OUT, "_motion_seg.mp4")
    subprocess.run([ff, "-y", "-v", "error", "-ss", f"{t0:.3f}", "-i", VIDEO,
                    "-t", f"{dur:.3f}", "-an", "-c:v", "libx264", "-crf", "14",
                    "-pix_fmt", "yuv420p", tmp], check=True)
    frames = iio.imread(tmp, plugin="FFMPEG")
    os.remove(tmp)
    return frames


def render(t0, dur, z, tag, label):
    i0 = int(round(t0 * FPS))
    frames = grab(t0, dur)
    n = min(len(frames), z.size - i0)
    frames = frames[:n]
    zt = z[i0:i0 + n]
    t  = np.arange(n) / FPS

    fig = plt.figure(figsize=(7.2, 6.4), dpi=150, facecolor=BG)
    axv = fig.add_axes([0.06, 0.34, 0.88, 0.62]); axv.set_facecolor(BG); axv.axis("off")
    im  = axv.imshow(frames[0], cmap="gray", vmin=0, vmax=255)
    axt = fig.add_axes([0.11, 0.09, 0.83, 0.20]); axt.set_facecolor(BG)

    axt.axhline(MOTTHR, color=MUTE, lw=1.0, ls="--")
    axt.text(t[-1], MOTTHR, f"  motion threshold (z = {MOTTHR})", color=MUTE,
             fontsize=8, va="bottom", ha="right")
    axt.plot(t, zt, color=MUTE, lw=0.8, alpha=0.35)
    (ln,) = axt.plot([], [], color=HOT if label == "high" else COOL, lw=1.6)
    (pt,) = axt.plot([], [], "o", color=HOT if label == "high" else COOL, ms=4)
    axt.set_xlim(t[0], t[-1]); axt.set_ylim(min(-1.0, zt.min() - 0.5), max(2.5, zt.max() * 1.08))
    axt.set_xlabel("time (s)", color=MUTE, fontsize=9)
    axt.set_ylabel("face motion (z)", color=MUTE, fontsize=9)
    for s in ("top", "right"): axt.spines[s].set_visible(False)
    for s in ("bottom", "left"): axt.spines[s].set_color(MUTE)
    axt.tick_params(colors=MUTE, labelsize=8)

    ttl = fig.text(0.06, 0.975, "", color=TXT, fontsize=13, va="top", weight="bold")
    sub = fig.text(0.94, 0.975, "AL_0048  2026-07-15  face camera, 30 fps",
                   color=MUTE, fontsize=8, va="top", ha="right")
    badge = fig.text(0.90, 0.38, "", color=HOT, fontsize=12, weight="bold",
                     ha="right", va="bottom")

    out = os.path.join(OUT, f"motion_{label}_{tag}.mp4")
    w = FFMpegWriter(fps=FPS, codec="libx264", bitrate=-1,
                     extra_args=["-crf", "16", "-pix_fmt", "yuv420p"])
    ttl.set_text("HIGH MOTION" if label == "high" else "QUIET")
    with w.saving(fig, out, dpi=150):
        for k in range(n):
            im.set_data(frames[k])
            ln.set_data(t[:k + 1], zt[:k + 1])
            pt.set_data([t[k]], [zt[k]])
            badge.set_text("above threshold" if zt[k] > MOTTHR else "")
            w.grab_frame()
    plt.close(fig)
    print(f"  {out}   n={n} frames  mean z {zt.mean():+.2f}  peak {zt.max():+.2f}")
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--t", type=float, default=None, help="clip start (s) -- overrides the picks")
    ap.add_argument("--dur", type=float, default=6.0)
    a = ap.parse_args()
    z = load_motion()
    print(f"[motion] {z.size} samples ({z.size/FPS/60:.1f} min)")
    if a.t is not None:
        render(a.t, a.dur, z, f"t{a.t:.0f}", "high")
    else:
        # 1886.1 s: the strongest SUSTAINED bout (mean z +6.2 over 6 s), not a single spike,
        # and well clear of the first minutes where the mouse is being mounted.
        render(1886.1, a.dur, z, "t1886", "high")
        # a matched quiet window, so the contrast is on the same animal and camera
        render(9822.3, a.dur, z, "t9822", "quiet")
