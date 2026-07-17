"""
make_session_previews.py — one short preview clip PER SESSION (experiment) so a
session can be chosen for the full brain-movie video + PPT. Each clip shows the
controller-performance story that differentiates sessions: the trial-averaged
closed-loop vs open-loop response and the per-trial error, accumulating as trials
arrive, plus a rolling example trial (ΔF/F + laser amplitude).

Reads the lightweight per-session bundles in assets/preview/<key>_perf.mat
(exported from the controller caches in MATLAB — traces only, no SVD movie).

Output: presentation/session_previews/<key>_<mouse>_preview.mp4
Run:    .venv/Scripts/python.exe presentation/make_session_previews.py
        .venv/Scripts/python.exe presentation/make_session_previews.py --keys m5 m13
"""
import argparse
import os
import numpy as np
import scipy.io as sio
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.animation as manim
import imageio_ffmpeg
from numpy.lib.stride_tricks import sliding_window_view as swv

matplotlib.rcParams["animation.ffmpeg_path"] = imageio_ffmpeg.get_ffmpeg_exe()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREV = os.path.join(ROOT, "presentation", "assets", "preview")
OUT = os.path.join(ROOT, "presentation", "session_previews")

BG = "#ffffff"; PANEL2 = "#f5f7fb"; EDGE = "#c7d0df"; GRID = "#e7ecf4"
TXT = "#1b2230"; MUTE = "#6b7688"
REFC = "#2f6fe0"; AMBER = "#d8880f"; ERRC = "#158a55"
CL_C = "#1a9e5f"; OL_C = "#e0553b"; ZERO = "#b4bccb"; STIMF = "#f6c9d0"

FS = 35.0; NWIN = 176; PRE = 35; REF = -5.0; DUR = 3.0
t = (np.arange(NWIN) - PRE) / FS
KEYS_ALL = ["m13", "m5", "m10", "m3", "m9", "m4", "m2"]   # movie sessions, best gap first


def smooth(y, w=7):
    return np.convolve(y, np.ones(w) / w, mode="same") if w > 1 else y


def envelope(x, w=250):
    pad = np.pad(np.asarray(x, float), (w // 2, w // 2), mode="edge")
    return swv(pad, w).max(-1)[:len(x)]


def resamp_env(row):
    e = envelope(row)
    u = np.interp(t, np.linspace(0, DUR, e.size), e, left=0.0, right=e[-1])
    u[(t < 0) | (t > DUR)] = 0.0
    return u


def style_ax(ax):
    ax.set_facecolor(PANEL2)
    for s in ax.spines.values():
        s.set_color(EDGE); s.set_linewidth(0.8)
    ax.tick_params(colors=MUTE, labelsize=7, length=2)
    ax.grid(True, color=GRID, lw=0.6); ax.set_axisbelow(True)


def load_session(key):
    m = sio.loadmat(os.path.join(PREV, f"{key}_perf.mat"), squeeze_me=True)
    ncD = np.atleast_2d(m["ncDfk"].astype(float)); wcD = np.atleast_2d(m["wcDfk"].astype(float))
    ncI = np.atleast_2d(m["ncInp"].astype(float)); wcI = np.atleast_2d(m["wcInp"].astype(float))
    er_nc = np.atleast_1d(m["er_ncDfk"].astype(float).ravel())
    er_wc = np.atleast_1d(m["er_wcDfk"].astype(float).ravel())
    nc = np.atleast_1d(m["nc"].astype(int).ravel()); wc = np.atleast_1d(m["wc"].astype(int).ravel())
    trials = []
    for i in range(ncD.shape[0]):
        trials.append(dict(idx=int(nc[i]), loop="OL", y=ncD[i],
                           u=resamp_env(ncI[i]) if i < ncI.shape[0] else np.zeros(NWIN),
                           mse=float(er_nc[i]) if i < er_nc.size else np.nan))
    for i in range(wcD.shape[0]):
        trials.append(dict(idx=int(wc[i]), loop="CL", y=wcD[i],
                           u=resamp_env(wcI[i]) if i < wcI.shape[0] else np.zeros(NWIN),
                           mse=float(er_wc[i]) if i < er_wc.size else np.nan))
    trials.sort(key=lambda tr: tr["idx"])
    meta = dict(mouse=str(m["mouse"]), date=str(m["date"]),
                inp=("step" if str(m["mouse"]) == "AL_0039" else "pulse / sine"))
    return trials, meta


def build_fig(dpi):
    fig = plt.figure(figsize=(12, 6.75), dpi=dpi)
    fig.patch.set_facecolor(BG)
    gs = fig.add_gridspec(100, 100, left=0.055, right=0.975, top=0.85, bottom=0.10,
                          wspace=0, hspace=0)
    axAvg = fig.add_subplot(gs[2:58, 0:55])
    axMSE = fig.add_subplot(gs[70:100, 0:55])
    axTr = fig.add_subplot(gs[2:42, 63:100])
    axU = fig.add_subplot(gs[52:82, 63:100])
    for ax in (axAvg, axMSE, axTr, axU):
        style_ax(ax)
    return fig, axAvg, axMSE, axTr, axU


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keys", nargs="*", default=KEYS_ALL)
    ap.add_argument("--fps", type=int, default=25)
    ap.add_argument("--dpi", type=int, default=82)
    ap.add_argument("--max-steps", type=int, default=48, help="max trials animated")
    ap.add_argument("--fpt", type=int, default=6, help="frames per trial step")
    args = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)

    fig, axAvg, axMSE, axTr, axU = build_fig(args.dpi)

    title = fig.text(0.055, 0.955, "", color=TXT, fontsize=17, fontweight="bold", va="center")
    subttl = fig.text(0.055, 0.905, "", color=MUTE, fontsize=11, va="center")
    stat = fig.text(0.975, 0.955, "", color=CL_C, fontsize=17, fontweight="bold",
                    va="center", ha="right")
    stat_sub = fig.text(0.975, 0.905, "", color=MUTE, fontsize=10, va="center", ha="right")

    # static decorations
    for ax, ttl in ((axAvg, "TRIAL-AVERAGED RESPONSE   —   closed-loop vs open-loop"),
                    (axMSE, "PER-TRIAL ERROR   —   accumulating as trials arrive"),
                    (axTr, "EXAMPLE TRIAL   ΔF/F"), (axU, "LASER AMPLITUDE")):
        ax.set_title(ttl, color=TXT, fontsize=8.5, fontweight="bold", loc="left", pad=4)
    for ax in (axAvg, axTr):
        ax.set_xlim(t.min(), t.max()); ax.set_ylim(-11, 4)
        ax.axvspan(0, DUR, color=STIMF, alpha=0.55, lw=0)
        ax.axhline(REF, color=REFC, ls="--", lw=1.6)
        ax.axhline(0, color=ZERO, ls="--", lw=1.0)
    axAvg.set_ylabel("%ΔF/F", color=MUTE, fontsize=8)
    axAvg.text(t.min() + 0.06, REF + 0.4, "reference (−5%)", color=REFC, fontsize=8, ha="left", va="bottom")
    axTr.set_ylabel("%ΔF/F", color=MUTE, fontsize=8); axTr.tick_params(labelbottom=False)
    axU.set_xlim(t.min(), t.max()); axU.axvspan(0, DUR, color=STIMF, alpha=0.55, lw=0)
    axU.set_ylabel("a.u.", color=MUTE, fontsize=8); axU.set_xlabel("time (s)", color=MUTE, fontsize=8)
    axMSE.set_xlabel("trial number", color=MUTE, fontsize=8); axMSE.set_ylabel("mean tracking error", color=MUTE, fontsize=8)

    ol_mean_line, = axAvg.plot([], [], color=OL_C, lw=3.0, zorder=6, label="open-loop  (no control)")
    cl_mean_line, = axAvg.plot([], [], color=CL_C, lw=3.0, zorder=6, label="closed-loop (control)")
    axAvg.legend(loc="lower right", fontsize=8.5, frameon=True, facecolor="#ffffff",
                 edgecolor=EDGE, labelcolor=TXT)
    tr_line, = axTr.plot([], [], lw=2.2, solid_capstyle="round")
    u_line, = axU.plot([], [], color=AMBER, lw=1.8)
    ol_run, = axMSE.plot([], [], color=OL_C, lw=2.4, zorder=5)
    cl_run, = axMSE.plot([], [], color=CL_C, lw=2.4, zorder=5)
    ol_sc = axMSE.scatter([], [], s=20, color=OL_C, alpha=0.4, zorder=3, edgecolors="none")
    cl_sc = axMSE.scatter([], [], s=20, color=CL_C, alpha=0.4, zorder=3, edgecolors="none")

    def render_session(key):
        trials, meta = load_session(key)
        ntot = len(trials)
        # subsample the animated trials but always keep the full set in the finale
        if ntot > args.max_steps:
            sel = sorted(set(np.linspace(0, ntot - 1, args.max_steps).round().astype(int)))
        else:
            sel = list(range(ntot))
        idxs = np.array([tr["idx"] for tr in trials])
        axMSE.set_xlim(0, idxs.max() + 1)
        umax = max(1e-3, max(float(tr["u"].max()) for tr in trials))
        axU.set_ylim(0, umax * 1.15)
        mse_all = np.array([tr["mse"] for tr in trials], float)
        axMSE.set_ylim(0, np.nanpercentile(mse_all, 98) * 1.12)
        redu = 100 * (1 - np.nanmedian([tr["mse"] for tr in trials if tr["loop"] == "CL"]) /
                      np.nanmedian([tr["mse"] for tr in trials if tr["loop"] == "OL"]))
        title.set_text(f"EXPERIMENT  {key.upper()}   —   {meta['mouse']} · {meta['date']}")
        subttl.set_text(f"{ntot} trials  ·  {meta['inp']} input  ·  brain movie available")
        stat.set_text(f"error  ↓ {redu:0.0f}%")

        # clear per-session dynamic artists (thin traces)
        for ln in list(axAvg.lines):
            if ln not in (ol_mean_line, cl_mean_line):
                ln.remove()
        shown = []            # trials added to the average so far
        ol_pts, cl_pts = [], []
        nsteps = len(sel)
        intro, outro = 12, 20
        total = intro + nsteps * args.fpt + outro

        out = os.path.join(OUT, f"{key}_{meta['mouse']}_preview.mp4")
        writer = manim.FFMpegWriter(fps=args.fps, bitrate=4200,
                                    metadata=dict(title=f"{key} preview"))
        with writer.saving(fig, out, dpi=args.dpi):
            for fnum in range(total):
                if fnum < intro:
                    writer.grab_frame(facecolor=BG); continue
                k = fnum - intro
                in_outro = k >= nsteps * args.fpt
                si = nsteps - 1 if in_outro else k // args.fpt
                prog = 1.0 if in_outro else (k % args.fpt) / max(1, args.fpt - 1)
                gi = sel[si]; tr = trials[gi]; col = CL_C if tr["loop"] == "CL" else OL_C
                nrev = max(2, int(round(prog * NWIN))); xs = t[:nrev]
                tr_line.set_data(xs, tr["y"][:nrev]); tr_line.set_color(col)
                u_line.set_data(xs, tr["u"][:nrev])
                # accumulate this trial once, near end of its step
                if (prog > 0.9 or in_outro) and gi not in shown:
                    axAvg.plot(t, smooth(tr["y"]), color=col, lw=0.7, alpha=0.20, zorder=2)
                    shown.append(gi)
                    (cl_pts if tr["loop"] == "CL" else ol_pts).append((tr["idx"], tr["mse"]))
                    ol = [trials[j]["y"] for j in shown if trials[j]["loop"] == "OL"]
                    cl = [trials[j]["y"] for j in shown if trials[j]["loop"] == "CL"]
                    if ol:
                        ol_mean_line.set_data(t, smooth(np.mean(ol, 0)))
                    if cl:
                        cl_mean_line.set_data(t, smooth(np.mean(cl, 0)))
                    if ol_pts:
                        op = np.array(ol_pts); o = np.argsort(op[:, 0]); ol_sc.set_offsets(op)
                        ol_run.set_data(op[o, 0], np.cumsum(op[o, 1]) / np.arange(1, len(o) + 1))
                    if cl_pts:
                        cp = np.array(cl_pts); o = np.argsort(cp[:, 0]); cl_sc.set_offsets(cp)
                        cl_run.set_data(cp[o, 0], np.cumsum(cp[o, 1]) / np.arange(1, len(o) + 1))
                    stat_sub.set_text(f"closed-loop vs open-loop   (n = {len(shown)} trials)")
                writer.grab_frame(facecolor=BG)
        print(f"  {key}: {os.path.basename(out)}  ({os.path.getsize(out)/1e6:.2f} MB, "
              f"{ntot} trials, -{redu:.0f}%)")

    print(f"[previews] {len(args.keys)} sessions -> {OUT}")
    for key in args.keys:
        if not os.path.exists(os.path.join(PREV, f"{key}_perf.mat")):
            print(f"  [skip] {key}: no bundle"); continue
        render_session(key)
    tot = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(".mp4")) / 1e6
    print(f"done — {tot:.1f} MB total in {OUT}")


if __name__ == "__main__":
    main()
