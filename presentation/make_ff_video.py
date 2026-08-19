"""
make_ff_video.py — render the feedforward (sine-tracking) controller demo video.

AL_0048 dual-opsin, right (inhibitory) hemisphere. A fixed 1 Hz sine reference is
tracked under 4 controller modes (OL / OL+preview / CL / CL+preview). The video
streams every trial as a fast montage but DROPS TO REAL TIME on 3 auto-picked
representative trials (high-motion, sleepy, clean-tracking) to show how motion and
arousal affect tracking.

Left  : live rig — masked widefield ΔF/F movie, face + eye cameras, calibration.
Middle: ΔF/F feedback vs the moving sine reference, face-motion energy, pupil diameter.
Right : 4-mode trial-averaged tracking + per-mode MSE-over-time, accumulating.

Data: presentation/assets/demo_ff_<key>.npz  (build_ff_data.py)

Run:
  .venv/Scripts/python.exe presentation/make_ff_video.py --key 0721 --probe 0.5
  .venv/Scripts/python.exe presentation/make_ff_video.py --key 0721 --hd
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
# rendered media all lands in talk/ so the deck has one place to pull from
MEDIA = os.path.join(ROOT, "talk")
os.makedirs(MEDIA, exist_ok=True)

# ---- palette (light purple theme, matched to make_video.py) -----------------
BG = "#f0eaf8"; PANEL2 = "#f9f6fd"; EDGE = "#ccc3df"; GRID = "#e9e3f3"
TXT = "#1b2230"; MUTE = "#6b7688"
REFC = "#111417"; ZERO = "#b4bccb"; STIMF = "#f6c9d0"
ROIC = "#e11fbf"; GLOW = "#ff2e6a"; MOTC = "#c0392b"; PUPC = "#2c7fb8"
AMBER = "#d8880f"                                # laser command
RTC = "#d81b60"                                  # real-time accent colour

# ff_cond -> (label, colour); display order OL, OL+prev, CL, CL+prev.
# Palette matches the paper's Fig-5 sine scheme (sine_ff_plots_combined.m, 2026-07-23):
# OL=red, OL+prev=orange, CL=blue, CL+prev=green. Input command uses its mode's colour.
MODE_LABEL = {2: "OL", 1: "OL+prev", 3: "CL", 0: "CL+prev"}
MODE_COL = {2: "#ff0000", 1: "#ff8c40", 3: "#0066d9", 0: "#008000"}
MODE_SEQ = [2, 1, 3, 0]


def smooth(y, w=5):
    if w <= 1 or y is None:
        return y
    return np.convolve(y, np.ones(w) / w, mode="same")


def style_ax(ax):
    ax.set_facecolor(PANEL2)
    for s in ax.spines.values():
        s.set_color(EDGE); s.set_linewidth(0.8)
    ax.tick_params(colors=MUTE, labelsize=7, length=2)
    ax.grid(True, color=GRID, lw=0.6); ax.set_axisbelow(True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", default="0721")
    ap.add_argument("--hd", action="store_true")
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--probe", type=float, default=None,
                    help="render ONE frame at fraction [0..1] to a PNG and exit")
    args = ap.parse_args()

    from scipy import ndimage
    from matplotlib.colors import Normalize

    z = np.load(os.path.join(ASSETS, f"demo_ff_{args.key}.npz"), allow_pickle=True)
    D = {k: z[k] for k in z.files}
    Uf = D["U_ds"]; mimg = D["mimg"]; roi = D["roi"]
    Vwin = D["Vwin"]; dFoF = D["dFoF"]; REFW = D["REFW"]; MOT = D["MOT"]; PUP = D["PUP"]
    INP = D["INP"]
    ffc = D["ffc"].astype(int); MSE = D["MSE"]
    t = D["t_win"]; DUR = float(D["dur"]); FS = float(D["fs"]); PRE = int(D["n_pre"])
    NWIN = int(D["NWIN"]); n = int(D["n"]); K = int(D["K"]); Ntr = dFoF.shape[0]
    # Two views of the pixel trace:
    #  - dFoF     : RAW ΔF/F — used for the right-side analysis panels so the method,
    #               scale, and per-mode ranking match the paper (sine_ff_modes.m).
    #  - dFoF_bs  : baseline-subtracted (per-trial pre-onset) — used ONLY for the live
    #               single-trial feedback panel so an evoked response aligns with the
    #               sine reference on the fixed ±5 axis.
    dFoF_bs = dFoF - np.nanmean(dFoF[:, :PRE], axis=1, keepdims=True)
    SCH_T = D["SCHED_TRIAL"]; SCH_TAU = D["SCHED_TAU"]
    CAM_EYE = D["CAM_EYE"]; CAM_FACE = D["CAM_FACE"]
    rt_idx = D["rt_idx"]; rt_labels = D["rt_labels"].astype(str)
    rt_label = {int(j): lab for j, lab in zip(rt_idx, rt_labels)}
    mouse = str(D["mouse"]); date = str(D["date"])
    Uf = Uf.reshape(n * n, K) if Uf.ndim == 2 else Uf

    # ---- brain mask + baseline-subtracted dF/F activity (as in make_video) --
    mask_file = os.path.join(ASSETS, f"mask_ff_{args.key}.npy")
    if os.path.exists(mask_file):
        mask = np.load(mask_file).astype(bool)
        print(f"[mask] using hand-drawn {os.path.basename(mask_file)}")
    else:
        mask = mimg > np.percentile(mimg, 15)
        mask = ndimage.binary_fill_holes(mask)
        lbl, nlab = ndimage.label(mask)
        if nlab > 1:
            sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, nlab + 1))
            mask = lbl == (1 + int(np.argmax(sizes)))
        mask = ndimage.gaussian_filter(mask.astype(float), sigma=2.5) > 0.5
        mask = ndimage.binary_fill_holes(mask)
    mimg_safe = np.where(mimg > 1e-3, mimg, np.nan)
    soft = np.clip(ndimage.gaussian_filter(mask.astype(float), 3.0), 0.0, 1.0)

    Ufr = Uf.reshape(n, n, K)

    def activity(trial, tau):
        v0 = Vwin[trial][:, :PRE].mean(axis=1)
        act = (Ufr @ (Vwin[trial][:, tau] - v0)).reshape(n, n)
        return 100.0 * act / mimg_safe

    _s = np.concatenate([activity(tr, tau)[mask].ravel()
                         for tr in np.linspace(0, Ntr - 1, 6).astype(int)
                         for tau in (PRE + 8, PRE + 30, PRE + 70)])
    clim = float(np.nanpercentile(np.abs(_s), 97))
    dcmap = plt.get_cmap("RdBu_r"); dnorm = Normalize(-clim, clim)
    gnorm = Normalize(np.percentile(mimg[mask], 2), np.percentile(mimg[mask], 97))
    anat_rgba = plt.get_cmap("gray")(gnorm(mimg)); anat_rgba[..., 3] = soft

    def act_rgba(trial, tau):
        df = np.nan_to_num(activity(trial, tau), nan=0.0, posinf=0.0, neginf=0.0)
        rgba = dcmap(dnorm(df))
        rgba[..., 3] = np.clip(np.abs(df) / (0.72 * clim), 0.0, 1.0) * soft
        return rgba

    # per-trial last scheduled frame (for "trial complete" accumulation)
    last_frame = np.full(Ntr, -1)
    for fi, tj in enumerate(SCH_T):
        last_frame[tj] = fi

    # ---- figure / layout ----------------------------------------------------
    dpi = 120 if args.hd else 100
    fig = plt.figure(figsize=(16, 9), dpi=dpi)
    fig.patch.set_facecolor(BG)
    gs = fig.add_gridspec(nrows=100, ncols=100, left=0.03, right=0.975,
                          top=0.895, bottom=0.055, wspace=0, hspace=0)

    # left rig: brain + colorbar + two cameras + calibration
    axBrain = fig.add_subplot(gs[8:40, 0:20])
    axCB    = fig.add_subplot(gs[12:36, 20:21])
    axFace  = fig.add_subplot(gs[8:40, 25:37])
    axEye   = fig.add_subplot(gs[8:40, 38:50])
    # middle trace stack (banner band lives in rows 42-48, kept clear):
    # ΔF/F feedback · laser command input · motion+pupil (dual y-axis)
    axDF  = fig.add_subplot(gs[50:64, 0:50])
    axInp = fig.add_subplot(gs[68:80, 0:50])
    axAP  = fig.add_subplot(gs[84:100, 0:50])
    # right performance: big trial-average on top, MSE + variance side by side below
    axAvg = fig.add_subplot(gs[8:52, 57:100])
    axMSE = fig.add_subplot(gs[60:100, 57:77])
    axVar = fig.add_subplot(gs[60:100, 80:100])
    for ax in (axBrain, axDF, axInp, axAP, axAvg, axMSE, axVar):
        style_ax(ax)

    # ---- title bar ----
    fig.text(0.03, 0.945, "FEEDFORWARD OPTOGENETIC CONTROL", color=TXT,
             fontsize=20, fontweight="bold", va="center")
    from matplotlib.lines import Line2D
    fig.add_artist(Line2D([0.03, 0.975], [0.918, 0.918], color=EDGE, lw=1.0,
                          transform=fig.transFigure))

    # ---- brain movie ----
    axBrain.set_title("WIDEFIELD ΔF/F   ·   □ ROI", color=TXT, fontsize=8.5,
                      fontweight="bold", loc="left", pad=4)
    axBrain.set_facecolor(BG)
    axBrain.imshow(anat_rgba, interpolation="bilinear", zorder=0)
    axim = axBrain.imshow(act_rgba(int(SCH_T[0]), 0), interpolation="bilinear",
                          animated=True, zorder=1)
    axBrain.set_xticks([]); axBrain.set_yticks([]); axBrain.grid(False)
    for s in axBrain.spines.values():
        s.set_visible(False)
    from matplotlib.patches import Circle
    roi_glow = Circle((roi[0], roi[1]), 9, color=GLOW, alpha=0.0, zorder=5)
    axBrain.add_patch(roi_glow)
    axBrain.plot(roi[0], roi[1], "s", mec=ROIC, mfc="none", ms=13, mew=2.2, zorder=6)

    from matplotlib.cm import ScalarMappable
    cb = fig.colorbar(ScalarMappable(norm=dnorm, cmap=dcmap), cax=axCB, orientation="vertical")
    cb.set_label("ΔF/F (%)", color=MUTE, fontsize=7, labelpad=2)
    cb.set_ticks([-clim, 0, clim]); cb.ax.set_yticklabels([f"−{clim:.0f}", "0", f"+{clim:.0f}"])
    cb.ax.tick_params(colors=MUTE, labelsize=6, length=2)
    cb.outline.set_edgecolor(EDGE); cb.outline.set_linewidth(0.6)

    # ---- cameras ----
    for axc, title in ((axFace, "FACE"), (axEye, "EYE")):
        axc.set_title(title, color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
        axc.set_xticks([]); axc.set_yticks([]); axc.grid(False)
        for s in axc.spines.values():
            s.set_color(EDGE); s.set_linewidth(0.8)
    face_im = axFace.imshow(CAM_FACE[0], cmap="gray", vmin=0, vmax=255, animated=True, aspect="auto")
    eye_im = axEye.imshow(CAM_EYE[0], cmap="gray", vmin=0, vmax=255, animated=True, aspect="auto")

    banner = fig.text(0.03, 0.533, "", fontsize=12.5, fontweight="bold", va="center")
    banner_sub = fig.text(0.16, 0.533, "", fontsize=10.5, va="center", ha="left", color=MUTE)

    # ---- ΔF/F feedback vs moving sine reference ----
    axDF.set_title("PIXEL ΔF/F   —   feedback vs sine reference", color=TXT, fontsize=8.5,
                   fontweight="bold", loc="left", pad=4)
    axDF.set_xlim(t.min(), t.max())
    axDF.set_ylim(-5, 5)                                # fixed ±5 %ΔF/F
    axDF.set_ylabel("%ΔF/F", color=MUTE, fontsize=8)
    axDF.axvspan(0, DUR, color=STIMF, alpha=0.6, lw=0)
    axDF.axhline(0, color=ZERO, ls="--", lw=1.0)
    ref_line, = axDF.plot([], [], color=REFC, ls="--", lw=1.8, label="sine reference")
    df_line, = axDF.plot([], [], color=MODE_COL[0], lw=2.2, solid_capstyle="round", label="feedback")
    df_head, = axDF.plot([], [], "o", color=TXT, ms=4)
    axDF.legend(loc="lower right", fontsize=7.5, frameon=True, facecolor="#ffffff",
                edgecolor=EDGE, labelcolor=TXT, ncol=2)
    axDF.tick_params(labelbottom=False)

    # ---- laser command input (iputs) ----
    axInp.set_title("LASER COMMAND  —  inhibitory drive", color=TXT, fontsize=8,
                    fontweight="bold", loc="left", pad=3)
    axInp.set_xlim(t.min(), t.max())
    axInp.set_ylim(0, float(np.nanmax(INP)) * 1.05 + 1e-6)
    axInp.set_ylabel("a.u.", color=MUTE, fontsize=8)
    axInp.axvspan(0, DUR, color=STIMF, alpha=0.6, lw=0)
    inp_line, = axInp.plot([], [], color=AMBER, lw=1.8)
    inp_fill = [None]; axInp.tick_params(labelbottom=False)

    # ---- combined face-motion + pupil-diameter (dual y-axis) ----
    axAP.set_title("FACE MOTION  &  PUPIL DIAMETER", color=TXT, fontsize=8,
                   fontweight="bold", loc="left", pad=3)
    axAP.set_xlim(t.min(), t.max())
    axAP.set_ylim(float(np.nanmin(MOT)), float(np.nanmax(MOT)) * 1.05 + 1e-6)
    axAP.set_ylabel("motion (a.u.)", color=MOTC, fontsize=8)
    axAP.tick_params(axis="y", colors=MOTC)
    axAP.axvspan(0, DUR, color=STIMF, alpha=0.6, lw=0)
    axAP.set_xlabel("time (s)", color=MUTE, fontsize=8)
    mot_line, = axAP.plot([], [], color=MOTC, lw=1.6, label="motion")
    mot_fill = [None]
    axAP2 = axAP.twinx()
    axAP2.set_xlim(t.min(), t.max())
    axAP2.set_ylim(float(np.nanmin(PUP)) - 1, float(np.nanmax(PUP)) + 1)
    axAP2.set_ylabel("pupil (px)", color=PUPC, fontsize=8)
    axAP2.tick_params(axis="y", colors=PUPC, labelsize=7, length=2)
    axAP2.grid(False)
    for s in axAP2.spines.values():
        s.set_color(EDGE); s.set_linewidth(0.8)
    pup_line, = axAP2.plot([], [], color=PUPC, lw=1.8, label="pupil")
    axAP.legend([mot_line, pup_line], ["motion", "pupil"], loc="upper right", fontsize=7,
                frameon=True, facecolor="#ffffff", edgecolor=EDGE, labelcolor=TXT, ncol=2)

    # ---- right: 4-mode trial-averaged tracking (accumulating) ----
    axAvg.set_title("TRIAL-AVERAGED TRACKING  —  by controller mode", color=TXT,
                    fontsize=9, fontweight="bold", loc="left", pad=5)
    axAvg.set_xlim(t.min(), t.max())
    axAvg.set_ylim(float(np.nanpercentile(dFoF_bs, 1)) - 0.5, float(np.nanpercentile(dFoF_bs, 99)) + 0.5)
    axAvg.set_ylabel("%ΔF/F (baseline-sub.)", color=MUTE, fontsize=8.5)
    axAvg.axvspan(0, DUR, color=STIMF, alpha=0.45, lw=0)
    axAvg.axhline(0, color=ZERO, ls="--", lw=1.0)
    avg_ref, = axAvg.plot([], [], color=REFC, ls="--", lw=1.8, zorder=7, label="sine reference")
    mode_avg_line = {c: axAvg.plot([], [], color=MODE_COL[c], lw=2.8, zorder=6,
                                   label=MODE_LABEL[c])[0] for c in MODE_SEQ}
    axAvg.legend(loc="lower right", fontsize=8, frameon=True, facecolor="#ffffff",
                 edgecolor=EDGE, labelcolor=TXT, ncol=3)

    # ---- right-bottom-left: per-mode MSE over time (paper sine_ff_modes panel D) ----
    # mean over trials of the instantaneous squared error (RAW response vs ref);
    # ranks OL+prev WORST — trial-to-trial variability, not average tracking.
    axMSE.set_title("TRACKING ERROR  —  MSE by mode", color=TXT,
                    fontsize=8.5, fontweight="bold", loc="left", pad=4)
    axMSE.set_xlim(0, DUR)
    axMSE.set_ylabel("MSE  (%ΔF/F)²", color=MUTE, fontsize=8)
    axMSE.set_xlabel("time (s)", color=MUTE, fontsize=8)
    post = t >= 0
    stimw = (t >= 0) & (t <= DUR)

    def mode_pertrial_mse(sel):
        return np.nanmean((dFoF[sel] - REFW[sel]) ** 2, axis=0)   # trials axis

    mse_ymax = 1.15 * max(np.nanmax(mode_pertrial_mse(np.where(ffc == c)[0])[stimw])
                          for c in MODE_SEQ)
    axMSE.set_ylim(0, mse_ymax)
    mode_mse_line = {c: axMSE.plot([], [], color=MODE_COL[c], lw=2.2)[0] for c in MODE_SEQ}

    # ---- right-bottom-right: across-trial variance over time (paper panel B) ----
    # variance across RAW trials at each timepoint; ranks OL+prev highest, CL lowest.
    axVar.set_title("TRIAL-TO-TRIAL VARIANCE  —  by mode", color=TXT,
                    fontsize=8.5, fontweight="bold", loc="left", pad=4)
    axVar.set_xlim(t.min(), t.max())
    var_ymax = 1.15 * max(np.nanmax(np.nanvar(dFoF[ffc == c], axis=0)) for c in MODE_SEQ)
    axVar.set_ylim(0, var_ymax)
    axVar.set_ylabel("variance  (%ΔF/F)²", color=MUTE, fontsize=8)
    axVar.set_xlabel("time (s)", color=MUTE, fontsize=8)
    axVar.axvspan(0, DUR, color=STIMF, alpha=0.45, lw=0)
    mode_var_line = {c: axVar.plot([], [], color=MODE_COL[c], lw=2.2)[0] for c in MODE_SEQ}

    tpost = t[post]
    trial_lines = {}          # per-trial thin traces already drawn on axAvg

    # ---- session-progress bar (bottom): crawls slowly during real-time trials ----
    axProg = fig.add_axes([0.03, 0.022, 0.945, 0.008]); axProg.axis("off")
    axProg.set_xlim(0, 1); axProg.set_ylim(0, 1)
    axProg.add_patch(plt.Rectangle((0, 0), 1, 1, facecolor="#e2d9f2", edgecolor="none"))
    prog_fill = axProg.add_patch(plt.Rectangle((0, 0), 0, 1, facecolor="#7d5bd0", edgecolor="none"))

    def draw_frame(fnum):
        tj = int(SCH_T[fnum]); tau = int(SCH_TAU[fnum]); mode = int(ffc[tj])
        col = MODE_COL[mode]
        nrev = tau + 1; xs = t[:nrev]

        axim.set_data(act_rgba(tj, tau))
        on = 0 <= t[tau] <= DUR
        roi_glow.set_alpha(0.5 if on else 0.0)
        face_im.set_data(CAM_FACE[fnum]); eye_im.set_data(CAM_EYE[fnum])

        # feedback vs moving sine reference (baseline-subtracted, live evoked view)
        df_line.set_data(xs, dFoF_bs[tj][:nrev]); df_line.set_color(col)
        df_head.set_data([xs[-1]], [dFoF_bs[tj][tau]]); df_head.set_color(col)
        rr = REFW[tj][:nrev]
        ref_line.set_data(xs, rr)
        # laser command input (coloured by mode, matching the paper)
        uu = INP[tj][:nrev]; inp_line.set_data(xs, uu); inp_line.set_color(col)
        if inp_fill[0] is not None:
            inp_fill[0].remove()
        inp_fill[0] = axInp.fill_between(xs, 0, uu, color=col, alpha=0.18)
        # combined motion + pupil
        mm = MOT[tj][:nrev]; mot_line.set_data(xs, mm)
        if mot_fill[0] is not None:
            mot_fill[0].remove()
        mot_fill[0] = axAP.fill_between(xs, np.nanmin(MOT), mm, color=MOTC, alpha=0.13)
        pup_line.set_data(xs, PUP[tj][:nrev])

        banner.set_text(f"TRIAL {tj + 1:>3d} / {Ntr}"); banner.set_color(TXT)
        banner_sub.set_text(MODE_LABEL[mode]); banner_sub.set_color(col)
        prog_fill.set_width((fnum + 1) / total)
        prog_fill.set_color(RTC if tj in rt_label else "#7d5bd0")   # accent while real-time
        # accumulate completed trials into the right-side panels
        done = np.where(last_frame <= fnum)[0]
        # thin per-trial trace for each newly-completed trial (coloured by mode)
        for i in done:
            if i not in trial_lines:
                trial_lines[i], = axAvg.plot(t, smooth(dFoF_bs[i], 5),
                                             color=MODE_COL[int(ffc[i])], lw=0.3,
                                             alpha=0.05, zorder=2)
        avg_ref.set_data(t, np.nanmean(REFW[done], axis=0))
        for c in MODE_SEQ:
            dc = done[ffc[done] == c]
            cur = (c == mode)                          # is this the mode now playing?
            # dynamic highlight: the current mode is bold + opaque, others fade back
            mode_avg_line[c].set(linewidth=4.5 if cur else 2.0,
                                 alpha=1.0 if cur else 0.6, zorder=9 if cur else 6)
            if len(dc) >= 1:
                mode_avg_line[c].set_data(t, smooth(np.nanmean(dFoF_bs[dc], axis=0), 5))
            if len(dc) >= 4:                            # skip ultra-noisy few-trial estimates
                mode_mse_line[c].set_data(tpost, smooth(mode_pertrial_mse(dc)[post], 7))
                mode_var_line[c].set_data(t, smooth(np.nanvar(dFoF[dc], axis=0), 7))
                for ln in (mode_mse_line[c], mode_var_line[c]):
                    ln.set(linewidth=3.0 if cur else 1.5, alpha=1.0 if cur else 0.5)

    total = len(SCH_T)
    if args.probe is not None:
        fnum = int(np.clip(args.probe, 0.0, 1.0) * (total - 1))
        draw_frame(fnum)
        pout = os.path.join(ROOT, "presentation", f"_probe_ff_{args.key}.png")
        fig.savefig(pout, dpi=dpi, facecolor=BG)
        print(f"[probe] frame {fnum}/{total} (trial {int(SCH_T[fnum])+1}, "
              f"{'REAL-TIME '+rt_label.get(int(SCH_T[fnum]),'') if int(SCH_T[fnum]) in rt_label else 'fast'}) -> {pout}")
        return

    print(f"[render] {total} frames ({total/args.fps:.1f}s)  {'1080p' if args.hd else '900p'}")
    outname = os.path.join(MEDIA,
                           f"ff_demo_{args.key}{'_hd' if args.hd else ''}.mp4")
    writer = manim.FFMpegWriter(fps=args.fps, bitrate=7000,
                                metadata=dict(title="Feedforward controller demo"))
    with writer.saving(fig, outname, dpi=dpi):
        for fnum in range(total):
            draw_frame(fnum)
            writer.grab_frame(facecolor=BG)
            if fnum % 60 == 0:
                print(f"  frame {fnum}/{total}")
    print("wrote", outname, f"({os.path.getsize(outname)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
