"""
make_video.py — render the real-time closed-loop controller demo video.

Left  : presentation replica of the live rig with TRUE movies —
        - widefield brain movie (reconstructed from the session SVD)
        - face / motion camera movie (raw behavior video, synced to each trial)
        plus a calibration readout, the scrolling ΔF/F feedback vs reference,
        laser command, tracking error, and face-motion (exclusion) trace.
Right : controller performance accumulating in parallel (trial-averaged CL-vs-OL
        with every individual trial shown, and per-trial error vs trial number).

Data: presentation/assets/demo_data.npz  (build_demo_data.py)
      presentation/assets/cam_movies.npz  (build_cam_movies.py — face movie)

Run:
  .venv/Scripts/python.exe presentation/make_video.py --mode short
  .venv/Scripts/python.exe presentation/make_video.py --mode full --hd
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

# ---- palette (light purple theme) -------------------------------------------
BG = "#f0eaf8"; PANEL2 = "#f9f6fd"; EDGE = "#ccc3df"; GRID = "#e9e3f3"
TXT = "#1b2230"; MUTE = "#6b7688"
REFC = "#2f6fe0"; AMBER = "#d8880f"; ERRC = "#158a55"
CL_C = "#1a9e5f"; OL_C = "#e0553b"; ZERO = "#b4bccb"
STIMF = "#f6c9d0"; ROIC = "#e11fbf"; GLOW = "#ff2e6a"; MOTC = "#7d5bd0"


def load(name):
    z = np.load(os.path.join(ASSETS, name), allow_pickle=True)
    return {k: z[k] for k in z.files}


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
    ap.add_argument("--mode", choices=["short", "full"], default="short")
    ap.add_argument("--hd", action="store_true")
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--session", default="m5", help="session key -> demo_data_<key>.npz")
    ap.add_argument("--data", default=None, help="override demo_data .npz name")
    ap.add_argument("--probe", type=float, default=None,
                    help="render ONE frame at this fraction [0..1] to a PNG and exit (fast preview)")
    args = ap.parse_args()

    from scipy import ndimage
    from matplotlib.colors import Normalize

    D = load(args.data or f"demo_data_{args.session}.npz")
    Y, U, ERR = D["Y"], D["U"], D["ERR"]
    LOOP, TRN = D["LOOP"].astype(str), D["TRN"]
    GAIN = D["GAIN"]; VWIN = D["VWIN"]; Uf = D["U_ds"]; mimg = D["mimg"]; roi = D["roi"]
    t = D["t_win"]; REF = float(D["REF"]); DUR = float(D["DUR"]); FS = float(D["FS"])
    PRE = int(D["PRE"])
    NWIN = Y.shape[1]; ntr_all = Y.shape[0]; n = mimg.shape[0]

    # ---- brain mask (cortical window) + baseline-subtracted dF/F activity ----
    # Hand-drawn mask wins if present (assets/mask_<session>.npy from draw_mask.py),
    # otherwise auto-detect and smooth the boundary.
    mask_file = os.path.join(ASSETS, f"mask_{str(D['session'])}.npy")
    if os.path.exists(mask_file):
        mask = np.load(mask_file).astype(bool)
        print(f"[mask] using hand-drawn {os.path.basename(mask_file)}")
    else:
        mask = mimg > np.percentile(mimg, 15)             # brain (incl. vessels) vs surround
        mask = ndimage.binary_fill_holes(mask)            # fill dark vessels inside the window
        lbl, nlab = ndimage.label(mask)                   # keep the largest blob
        if nlab > 1:
            sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, nlab + 1))
            mask = lbl == (1 + int(np.argmax(sizes)))
        # smooth the boundary: blur the binary mask and re-threshold (rounds jaggies)
        mask = ndimage.gaussian_filter(mask.astype(float), sigma=2.5) > 0.5
        mask = ndimage.binary_fill_holes(mask)
    mimg_safe = np.where(mimg > 1e-3, mimg, np.nan)
    # feathered (soft) edge: blur the binary mask so the brain fades smoothly into
    # the page rather than a hard cut-out
    soft = np.clip(ndimage.gaussian_filter(mask.astype(float), 3.0), 0.0, 1.0)

    def activity(trial, tau):
        v0 = VWIN[trial][:, :PRE].mean(axis=1)            # per-trial pre-stim baseline
        act = (Uf @ (VWIN[trial][:, tau] - v0)).reshape(n, n)
        return 100.0 * act / mimg_safe                    # dF/F (%), relative to baseline

    # symmetric colour scale from the dynamic range of stim-window activity
    _s = np.concatenate([activity(tr, tau)[mask].ravel()
                         for tr in np.linspace(0, ntr_all - 1, 6).astype(int)
                         for tau in (PRE + 8, PRE + 30, PRE + 70)])
    clim = float(np.nanpercentile(np.abs(_s), 97))
    dcmap = plt.get_cmap("RdBu_r")
    dnorm = Normalize(-clim, clim)

    # grayscale anatomy as RGBA with the feathered alpha
    gnorm = Normalize(np.percentile(mimg[mask], 2), np.percentile(mimg[mask], 97))
    anat_rgba = plt.get_cmap("gray")(gnorm(mimg))
    anat_rgba[..., 3] = soft

    def act_rgba(trial, tau):
        df = np.nan_to_num(activity(trial, tau), nan=0.0, posinf=0.0, neginf=0.0)
        rgba = dcmap(dnorm(df))
        rgba[..., 3] = np.clip(np.abs(df) / (0.72 * clim), 0.0, 1.0) * soft
        return rgba

    # both modes now play EVERY trial (so a favourite can be picked); short is a
    # quicker-paced review copy at lower resolution, full is the detailed 1080p cut.
    sel = np.arange(ntr_all)
    frames_per_trial = 16 if args.mode == "short" else 11
    play = list(sel)

    dpi = 120 if args.hd else 100
    fig = plt.figure(figsize=(16, 9), dpi=dpi)
    fig.patch.set_facecolor(BG)
    gs = fig.add_gridspec(nrows=100, ncols=100, left=0.035, right=0.975,
                          top=0.90, bottom=0.06, wspace=0, hspace=0)

    # imaging row: large masked brain movie | vertical dF/F colorbar | small calib card
    axBrain = fig.add_subplot(gs[8:47, 0:25])
    axCB    = fig.add_subplot(gs[14:41, 26:27])
    axHUD   = fig.add_subplot(gs[10:29, 31:47])
    # trace stack (feedback / laser amplitude / tracking error — no motion)
    axDF  = fig.add_subplot(gs[52:71, 0:47])
    axU   = fig.add_subplot(gs[75:87, 0:47])
    axErr = fig.add_subplot(gs[91:100, 0:47])
    # performance
    axAvg = fig.add_subplot(gs[8:52, 54:100])
    axVar = fig.add_subplot(gs[60:96, 54:100])
    for ax in (axBrain, axDF, axU, axErr, axAvg, axVar):
        style_ax(ax)

    # ---- title bar (title + quiet subtitle, left-aligned; no top-right chrome) ----
    fig.text(0.035, 0.952, "CLOSED-LOOP OPTOGENETIC CONTROL", color=TXT,
             fontsize=19, fontweight="bold", va="center")
    fig.text(0.035, 0.923, "real-time widefield feedback control",
             color=MUTE, fontsize=10.5, va="center")
    from matplotlib.lines import Line2D
    fig.add_artist(Line2D([0.035, 0.975], [0.905, 0.905], color=EDGE, lw=1.0,
                          transform=fig.transFigure))

    # ---- brain movie: grayscale anatomy underlay + dF/F activity overlay ----
    axBrain.set_title("WIDEFIELD  ΔF/F  ACTIVITY   ·   □ control ROI", color=TXT, fontsize=8.5,
                      fontweight="bold", loc="left", pad=4)
    axBrain.set_facecolor(BG)
    axBrain.imshow(anat_rgba, interpolation="bilinear", zorder=0)
    axim = axBrain.imshow(act_rgba(play[0], 0), interpolation="bilinear", animated=True, zorder=1)
    axBrain.set_xticks([]); axBrain.set_yticks([]); axBrain.grid(False)
    for s in axBrain.spines.values():
        s.set_visible(False)
    from matplotlib.patches import Circle
    roi_glow = Circle((roi[0], roi[1]), 9, color=GLOW, alpha=0.0, zorder=5)
    axBrain.add_patch(roi_glow)
    axBrain.plot(roi[0], roi[1], "s", mec=ROIC, mfc="none", ms=14, mew=2.4, zorder=6)

    # dF/F activity colorbar (vertical, beside the brain)
    from matplotlib.cm import ScalarMappable
    cb = fig.colorbar(ScalarMappable(norm=dnorm, cmap=dcmap), cax=axCB, orientation="vertical")
    cb.set_label("ΔF/F activity (%)", color=MUTE, fontsize=7.5, labelpad=3)
    cb.set_ticks([-clim, 0, clim]); cb.ax.set_yticklabels([f"−{clim:.0f}", "0", f"+{clim:.0f}"])
    cb.ax.tick_params(colors=MUTE, labelsize=6.5, length=2)
    cb.outline.set_edgecolor(EDGE); cb.outline.set_linewidth(0.6)

    # ---- calibration HUD (axes-based card) ----
    axHUD.axis("off")
    axHUD.set_facecolor("#f1ecfb")
    hud_bg = plt.Rectangle((0, 0), 1, 1, transform=axHUD.transAxes, facecolor="#f1ecfb",
                           edgecolor="#7d5bd0", lw=1.4, zorder=0)
    axHUD.add_patch(hud_bg)
    axHUD.text(0.5, 0.90, "CALIBRATION", color="#6a41c0", fontsize=8.5, fontweight="bold",
               transform=axHUD.transAxes, va="top", ha="center")
    axHUD.plot([0.1, 0.9], [0.80, 0.80], color="#c9b8ee", lw=0.9, transform=axHUD.transAxes)
    # Static, fixed to the closed-loop gains — the controller's locked settings.
    clG = GAIN[LOOP == "CL"]
    Kp0, Ki0, Kref0 = (np.nanmedian(clG, axis=0)[:3] if len(clG) else (0.1, 0.15, 0.15))
    hud_rows = [("Ref", f"{REF:.0f} %ΔF/F"), ("Kp", f"{Kp0:.2f}"),
                ("Ki", f"{Ki0:.2f}"), ("Kref", f"{Kref0:.2f}")]
    for i, (k, v) in enumerate(hud_rows):
        yy = 0.64 - i * 0.175
        axHUD.text(0.12, yy, k, color=MUTE, fontsize=8.5, transform=axHUD.transAxes, va="center")
        axHUD.text(0.88, yy, v, color=TXT, fontsize=9, fontweight="bold",
                   ha="right", transform=axHUD.transAxes, va="center", family="monospace")

    banner = fig.text(0.035, 0.492, "", fontsize=12.5, fontweight="bold", va="center")
    banner_sub = fig.text(0.20, 0.492, "", fontsize=10.5, va="center", ha="left", color=MUTE)

    # ---- ΔF/F ----
    axDF.set_title("PIXEL ΔF/F   —   feedback vs reference", color=TXT, fontsize=8.5,
                   fontweight="bold", loc="left", pad=4)
    axDF.set_xlim(t.min(), t.max()); axDF.set_ylim(-11, 4)
    axDF.set_ylabel("%ΔF/F", color=MUTE, fontsize=8)
    axDF.axvspan(0, DUR, color=STIMF, alpha=0.7, lw=0)
    axDF.axhline(REF, color=REFC, ls="--", lw=1.8)
    axDF.axhline(0, color=ZERO, ls="--", lw=1.0)
    axDF.text(t.min() + 0.06, REF + 0.4, "reference", color=REFC, fontsize=7.5, ha="left", va="bottom")
    df_line, = axDF.plot([], [], color=CL_C, lw=2.2, solid_capstyle="round")
    df_head, = axDF.plot([], [], "o", color=TXT, ms=4)
    axDF.tick_params(labelbottom=False)

    # ---- laser amplitude (command envelope) ----
    axU.set_title("LASER AMPLITUDE", color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
    axU.set_xlim(t.min(), t.max())
    umax = float(np.nanpercentile(U, 99.5)) or 1.0
    axU.set_ylim(0, umax * 1.15 + 1e-6)
    axU.set_ylabel("a.u.", color=MUTE, fontsize=8)
    axU.axvspan(0, DUR, color=STIMF, alpha=0.7, lw=0)
    u_line, = axU.plot([], [], color=AMBER, lw=1.8)
    u_fill = [None]; axU.tick_params(labelbottom=False)

    # ---- error ----
    axErr.set_title("TRACKING ERROR", color=TXT, fontsize=8, fontweight="bold", loc="left", pad=3)
    axErr.set_xlim(t.min(), t.max()); axErr.set_ylim(-7, 7)
    axErr.axvspan(0, DUR, color=STIMF, alpha=0.7, lw=0)
    axErr.axhline(0, color=ZERO, ls="--", lw=1.0)
    err_line, = axErr.plot([], [], color=ERRC, lw=1.6)
    axErr.set_xlabel("time (s)", color=MUTE, fontsize=8)

    # ---- trial-average (every trace) ----
    axAvg.set_title("TRIAL-AVERAGED RESPONSE  —  closed-loop vs open-loop", color=TXT,
                    fontsize=9, fontweight="bold", loc="left", pad=5)
    axAvg.set_xlim(t.min(), t.max()); axAvg.set_ylim(-11, 4)
    axAvg.set_ylabel("%ΔF/F", color=MUTE, fontsize=8.5)
    axAvg.axvspan(0, DUR, color=STIMF, alpha=0.5, lw=0)
    axAvg.axhline(REF, color=REFC, ls="--", lw=1.8)
    axAvg.axhline(0, color=ZERO, ls="--", lw=1.0)
    axAvg.text(t.min() + 0.06, REF + 0.4, "reference (−5%)", color=REFC, fontsize=8, ha="left", va="bottom")
    ol_mean_line, = axAvg.plot([], [], color=OL_C, lw=3.2, zorder=6, label="open-loop  (no control)")
    cl_mean_line, = axAvg.plot([], [], color=CL_C, lw=3.2, zorder=6, label="closed-loop (control)")
    axAvg.legend(loc="lower right", fontsize=8.5, frameon=True, facecolor="#ffffff",
                 edgecolor=EDGE, labelcolor=TXT)

    # ---- trial-to-trial variance OVER TIME (evolves as trials accumulate) ----
    axVar.set_title("TRIAL-TO-TRIAL VARIANCE  —  closed-loop vs open-loop", color=TXT,
                    fontsize=9, fontweight="bold", loc="left", pad=5)
    axVar.set_xlim(t.min(), t.max())
    ol_all = Y[LOOP == "OL"]; cl_all = Y[LOOP == "CL"]
    vmax_var = 1.18 * max(np.var(ol_all, axis=0).max(), np.var(cl_all, axis=0).max())
    axVar.set_ylim(0, vmax_var)
    axVar.set_xlabel("time (s)", color=MUTE, fontsize=8.5)
    axVar.set_ylabel("variance across trials  (%ΔF/F)²", color=MUTE, fontsize=8.5)
    axVar.axvspan(0, DUR, color=STIMF, alpha=0.5, lw=0)
    ol_var_line, = axVar.plot([], [], color=OL_C, lw=2.8, zorder=6, label="open-loop  (no control)")
    cl_var_line, = axVar.plot([], [], color=CL_C, lw=2.8, zorder=6, label="closed-loop (control)")
    axVar.legend(loc="upper right", fontsize=8.5, frameon=True, facecolor="#ffffff",
                 edgecolor=EDGE, labelcolor=TXT)

    shown_idx = []
    intro = 24; outro = 45
    total = intro + len(play) * frames_per_trial + outro
    cl_shown = [i for i in play if LOOP[i] == "CL"]
    outro_gi = cl_shown[-1] if cl_shown else play[-1]

    def running_mean_traces(idxs):
        ol = [Y[i] for i in idxs if LOOP[i] == "OL"]
        cl = [Y[i] for i in idxs if LOOP[i] == "CL"]
        return (smooth(np.mean(ol, 0)) if ol else None, smooth(np.mean(cl, 0)) if cl else None)

    def draw_frame(fnum):
        if fnum < intro:
            axim.set_data(act_rgba(play[0], 0))
            banner.set_text("SYSTEM ARMED"); banner.set_color(CL_C)
            banner_sub.set_text("calibration locked  ·  awaiting trials")
            return

        k = fnum - intro
        in_outro = k >= len(play) * frames_per_trial
        if in_outro:
            ti = len(play) - 1; prog = 1.0; gi = outro_gi
        else:
            ti = k // frames_per_trial
            prog = (k % frames_per_trial) / max(1, frames_per_trial - 1); gi = play[ti]
        loop = LOOP[gi]; col = CL_C if loop == "CL" else OL_C
        nrev = max(2, int(round(prog * NWIN))); tau = nrev - 1; xs = t[:nrev]

        axim.set_data(act_rgba(gi, tau))
        on = 0 <= t[tau] <= DUR
        roi_glow.set_alpha(0.5 if on else 0.0)

        df_line.set_data(xs, Y[gi][:nrev]); df_line.set_color(col)
        df_head.set_data([xs[-1]], [Y[gi][nrev - 1]])
        uu = U[gi][:nrev]; u_line.set_data(xs, uu)
        if u_fill[0] is not None:
            u_fill[0].remove()
        u_fill[0] = axU.fill_between(xs, 0, uu, color=AMBER, alpha=0.18)
        err_line.set_data(xs, ERR[gi][:nrev])

        if in_outro:
            banner.set_text(f"{len(play)} TRIALS COMPLETE"); banner.set_color(CL_C)
            banner_sub.set_text("closed-loop holds the set-point"); banner_sub.set_color(MUTE)
        else:
            banner.set_text(f"TRIAL {gi + 1:>3d} / {ntr_all}"); banner.set_color(TXT)
            banner_sub.set_text("CLOSED-LOOP" if loop == "CL" else "OPEN-LOOP"); banner_sub.set_color(col)

        done = play[:ti + (1 if prog > 0.985 else 0)]
        for i in done[len(shown_idx):]:
            c = CL_C if LOOP[i] == "CL" else OL_C
            axAvg.plot(t, smooth(Y[i], 7), color=c, lw=0.7, alpha=0.22, zorder=2)
            shown_idx.append(i)
        olm, clm = running_mean_traces(done)
        if olm is not None:
            ol_mean_line.set_data(t, olm)
        if clm is not None:
            cl_mean_line.set_data(t, clm)

        # variance across the trials seen so far, at each timepoint (evolves)
        ol_tr = [Y[i] for i in done if LOOP[i] == "OL"]
        cl_tr = [Y[i] for i in done if LOOP[i] == "CL"]
        if len(ol_tr) >= 2:
            ol_var_line.set_data(t, smooth(np.var(ol_tr, axis=0), 7))
        if len(cl_tr) >= 2:
            cl_var_line.set_data(t, smooth(np.var(cl_tr, axis=0), 7))

    sess = str(D["session"])
    if args.probe is not None:                            # single-frame preview, no video
        fnum = int(np.clip(args.probe, 0.0, 1.0) * (total - 1))
        draw_frame(fnum)
        pout = os.path.join(ROOT, "presentation", f"_probe_{sess}.png")
        fig.savefig(pout, dpi=dpi, facecolor=BG)
        print(f"[probe] frame {fnum}/{total} -> {pout}")
        return

    print(f"[render] mode={args.mode} trials={len(play)} frames={total} "
          f"({total/args.fps:.1f}s)  {'1080p' if args.hd else '900p'}")
    outname = os.path.join(MEDIA,
                           f"controller_demo_{sess}_{args.mode}{'_hd' if args.hd else ''}.mp4")
    writer = manim.FFMpegWriter(fps=args.fps, bitrate=7000, metadata=dict(title="Closed-loop controller demo"))
    with writer.saving(fig, outname, dpi=dpi):
        for fnum in range(total):
            draw_frame(fnum)
            writer.grab_frame(facecolor=BG)
            if fnum % 60 == 0:
                print(f"  frame {fnum}/{total}")
    print("wrote", outname, f"({os.path.getsize(outname)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
