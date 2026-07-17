"""
make_trial_clips.py — render one small, low-res clip PER TRIAL so a favourite can
be picked by eye. Each clip is the compact "live rig": the widefield brain movie,
face + pupil cameras, and that single trial's ΔF/F / laser-amplitude / tracking-
error / face-motion traces animating over the −1..+4 s window.

Output: presentation/clips/trial_<NN>_<CL|OL>.mp4   (one per trial)
Run:    .venv/Scripts/python.exe presentation/make_trial_clips.py
        .venv/Scripts/python.exe presentation/make_trial_clips.py --only CL
"""
import argparse
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.animation as manim
import imageio_ffmpeg

matplotlib.rcParams["animation.ffmpeg_path"] = imageio_ffmpeg.get_ffmpeg_exe()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")
CLIPS = os.path.join(ROOT, "presentation", "clips")

BG = "#ffffff"; PANEL2 = "#f5f7fb"; EDGE = "#c7d0df"; GRID = "#e7ecf4"
TXT = "#1b2230"; MUTE = "#6b7688"
REFC = "#2f6fe0"; AMBER = "#d8880f"; ERRC = "#158a55"
CL_C = "#1a9e5f"; OL_C = "#e0553b"; ZERO = "#b4bccb"
STIMF = "#f6c9d0"; ROIC = "#e11fbf"; GLOW = "#ff2e6a"; MOTC = "#7d5bd0"


def load(name):
    z = np.load(os.path.join(ASSETS, name), allow_pickle=True)
    return {k: z[k] for k in z.files}


def smooth(y, w=5):
    return np.convolve(y, np.ones(w) / w, mode="same") if w > 1 else y


def style_ax(ax):
    ax.set_facecolor(PANEL2)
    for s in ax.spines.values():
        s.set_color(EDGE); s.set_linewidth(0.8)
    ax.tick_params(colors=MUTE, labelsize=7, length=2)
    ax.grid(True, color=GRID, lw=0.6); ax.set_axisbelow(True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["CL", "OL"], help="render only this loop type")
    ap.add_argument("--frames", type=int, default=40, help="animation frames per clip")
    ap.add_argument("--hold", type=int, default=8, help="held frames on the final image")
    ap.add_argument("--fps", type=int, default=25)
    ap.add_argument("--dpi", type=int, default=78)
    args = ap.parse_args()

    os.makedirs(CLIPS, exist_ok=True)
    D = load("demo_data.npz")
    Y, U, ERR, MOT = D["Y"], D["U"], D["ERR"], D["MOT"]
    LOOP, TRN = D["LOOP"].astype(str), D["TRN"]
    VWIN = D["VWIN"]; Uf = D["U_ds"]; mimg = D["mimg"]; roi = D["roi"]
    t = D["t_win"]; REF = float(D["REF"]); DUR = float(D["DUR"])
    NWIN = Y.shape[1]; ntr = Y.shape[0]; n = mimg.shape[0]

    try:
        cam = load("cam_movies.npz")
        FACE = cam["FACE"]; EYE = cam["EYE"] if "EYE" in cam else None
        NCAM = FACE.shape[1]
    except Exception:
        FACE = None; EYE = None; NCAM = 1
    eye_clim = (np.percentile(EYE, 18), np.percentile(EYE, 97)) if EYE is not None else (0, 255)
    vmin, vmax = np.percentile(mimg, 2), np.percentile(mimg, 99.6)

    def brain_frame(gi, tau):
        return mimg + (Uf @ VWIN[gi][:, tau]).reshape(n, n)

    # ---- build the figure ONCE, reuse across trials ----
    fig = plt.figure(figsize=(9, 8), dpi=args.dpi)
    fig.patch.set_facecolor(BG)
    gs = fig.add_gridspec(100, 100, left=0.075, right=0.965, top=0.90, bottom=0.065,
                          wspace=0, hspace=0)
    axBrain = fig.add_subplot(gs[3:41, 0:52])
    axFace = fig.add_subplot(gs[3:20, 60:100])
    axEye = fig.add_subplot(gs[24:41, 60:100])
    axDF = fig.add_subplot(gs[48:62, 0:100])
    axU = fig.add_subplot(gs[65:75, 0:100])
    axErr = fig.add_subplot(gs[78:87, 0:100])
    axMot = fig.add_subplot(gs[90:100, 0:100])
    for ax in (axBrain, axFace, axEye, axDF, axU, axErr, axMot):
        style_ax(ax)

    title = fig.text(0.075, 0.955, "", color=TXT, fontsize=15, fontweight="bold", va="center")
    title_sub = fig.text(0.965, 0.955, "", color=MUTE, fontsize=11, va="center", ha="right")

    axBrain.set_title("WIDEFIELD  ΔF/F   ·   □ control ROI", color=TXT, fontsize=8.5,
                      fontweight="bold", loc="left", pad=4)
    axim = axBrain.imshow(brain_frame(0, 0), cmap="viridis", vmin=vmin, vmax=vmax,
                          interpolation="bilinear", animated=True)
    axBrain.set_xticks([]); axBrain.set_yticks([]); axBrain.grid(False)
    from matplotlib.patches import Circle
    roi_glow = Circle((roi[0], roi[1]), 9, color=GLOW, alpha=0.0, zorder=5)
    axBrain.add_patch(roi_glow)
    axBrain.plot(roi[0], roi[1], "s", mec=ROIC, mfc="none", ms=12, mew=2.0, zorder=6)

    axFace.set_title("FACE CAM", color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
    axface_im = axFace.imshow(FACE[0][0] if FACE is not None else np.zeros((88, 76), np.uint8),
                              cmap="gray", vmin=0, vmax=255, interpolation="bilinear", animated=True)
    axFace.set_xticks([]); axFace.set_yticks([]); axFace.grid(False)

    axEye.set_title("PUPIL / EYE CAM", color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
    axeye_im = axEye.imshow(EYE[0][0] if EYE is not None else np.zeros((82, 96), np.uint8),
                            cmap="gray", vmin=eye_clim[0], vmax=eye_clim[1],
                            interpolation="bilinear", animated=True)
    axEye.set_xticks([]); axEye.set_yticks([]); axEye.grid(False)

    axDF.set_title("PIXEL ΔF/F   —   feedback vs reference", color=TXT, fontsize=8.5,
                   fontweight="bold", loc="left", pad=4)
    axDF.set_xlim(t.min(), t.max()); axDF.set_ylim(-11, 4)
    axDF.set_ylabel("%ΔF/F", color=MUTE, fontsize=8)
    axDF.axvspan(0, DUR, color=STIMF, alpha=0.7, lw=0)
    axDF.axhline(REF, color=REFC, ls="--", lw=1.8)
    axDF.axhline(0, color=ZERO, ls="--", lw=1.0)
    axDF.text(t.min() + 0.06, REF + 0.4, "reference", color=REFC, fontsize=7.5, ha="left", va="bottom")
    df_line, = axDF.plot([], [], lw=2.2, solid_capstyle="round")
    df_head, = axDF.plot([], [], "o", color=TXT, ms=4)
    axDF.tick_params(labelbottom=False)

    axU.set_title("LASER AMPLITUDE", color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
    axU.set_xlim(t.min(), t.max())
    umax = float(np.nanpercentile(U, 99.5)) or 1.0
    axU.set_ylim(0, umax * 1.15 + 1e-6)
    axU.set_ylabel("a.u.", color=MUTE, fontsize=8)
    axU.axvspan(0, DUR, color=STIMF, alpha=0.7, lw=0)
    u_line, = axU.plot([], [], color=AMBER, lw=1.8)
    u_fill = [None]; axU.tick_params(labelbottom=False)

    axErr.set_title("TRACKING ERROR", color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
    axErr.set_xlim(t.min(), t.max()); axErr.set_ylim(-7, 7)
    axErr.axvspan(0, DUR, color=STIMF, alpha=0.7, lw=0)
    axErr.axhline(0, color=ZERO, ls="--", lw=1.0)
    err_line, = axErr.plot([], [], color=ERRC, lw=1.6)
    axErr.tick_params(labelbottom=False)

    axMot.set_title("FACE MOTION (z)", color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
    axMot.set_xlim(t.min(), t.max())
    mmax = max(3.0, float(np.nanpercentile(MOT, 99)))
    axMot.set_ylim(-1, mmax)
    axMot.axvspan(0, DUR, color=STIMF, alpha=0.7, lw=0)
    axMot.axhline(1.5, color=OL_C, ls=":", lw=1.2)
    axMot.text(t.max() - 0.05, 1.5 + 0.15, "excl. thr", color=OL_C, fontsize=6.5, ha="right")
    mot_line, = axMot.plot([], [], color=MOTC, lw=1.5)
    axMot.set_xlabel("time (s)", color=MUTE, fontsize=8)

    def set_cams(gi, tau):
        cf = min(int(round(tau / (NWIN - 1) * (NCAM - 1))), NCAM - 1)
        if FACE is not None:
            axface_im.set_data(FACE[gi][cf])
        if EYE is not None:
            axeye_im.set_data(EYE[gi][cf])

    def render_trial(gi, writer):
        loop = LOOP[gi]; col = CL_C if loop == "CL" else OL_C
        title.set_text(f"TRIAL {gi + 1:>2d} / {ntr}")
        title_sub.set_text("CLOSED-LOOP" if loop == "CL" else "OPEN-LOOP")
        title_sub.set_color(col)
        df_line.set_color(col)
        nframes = args.frames
        for f in range(nframes + args.hold):
            prog = min(1.0, (f + 1) / nframes)
            nrev = max(2, int(round(prog * NWIN))); tau = nrev - 1; xs = t[:nrev]
            axim.set_data(brain_frame(gi, tau)); set_cams(gi, tau)
            roi_glow.set_alpha(0.5 if 0 <= t[tau] <= DUR else 0.0)
            df_line.set_data(xs, Y[gi][:nrev])
            df_head.set_data([xs[-1]], [Y[gi][nrev - 1]])
            uu = U[gi][:nrev]; u_line.set_data(xs, uu)
            if u_fill[0] is not None:
                u_fill[0].remove()
            u_fill[0] = axU.fill_between(xs, 0, uu, color=AMBER, alpha=0.18)
            err_line.set_data(xs, ERR[gi][:nrev])
            mot_line.set_data(xs, MOT[gi][:nrev])
            writer.grab_frame(facecolor=BG)

    sel = [i for i in range(ntr) if (args.only is None or LOOP[i] == args.only)]
    print(f"[clips] rendering {len(sel)} trials -> {CLIPS}  "
          f"({args.frames}+{args.hold} frames each, {args.dpi} dpi)")
    for k, gi in enumerate(sel):
        loop = LOOP[gi]
        out = os.path.join(CLIPS, f"trial_{gi + 1:02d}_{loop}.mp4")
        writer = manim.FFMpegWriter(fps=args.fps, bitrate=3500,
                                    metadata=dict(title=f"trial {gi + 1} {loop}"))
        with writer.saving(fig, out, dpi=args.dpi):
            render_trial(gi, writer)
        if k % 10 == 0 or k == len(sel) - 1:
            print(f"  {k + 1}/{len(sel)}  {os.path.basename(out)} "
                  f"({os.path.getsize(out) / 1e6:.2f} MB)")
    tot = sum(os.path.getsize(os.path.join(CLIPS, f)) for f in os.listdir(CLIPS)
              if f.endswith(".mp4")) / 1e6
    print(f"done — {len(sel)} clips, {tot:.1f} MB total in {CLIPS}")


if __name__ == "__main__":
    main()
