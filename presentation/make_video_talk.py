"""
make_video_talk.py — PRESENTATION cut of the constant-reference controller demo.

An alternate to make_video.py (which is left untouched). Where that one is a
"live rig" dashboard, this one is a narrated argument built for a talk: it walks
the audience through the system, shows open loop failing, shows closed loop
working, and ends on the numbers.

Structure
  ACT 0  PREMISE   — what is being controlled, and how it is measured
  ACT 1  OPEN LOOP — fixed command, feedback arm visibly BROKEN; responses miss
  ACT 2  CLOSED LOOP — feedback arm live; controller corrects, responses converge
  ACT 3  VERDICT   — tracking error and trial-to-trial variability, with numbers

Explanatory devices
  - an animated CONTROL-LOOP SCHEMATIC (reference → Σ → PI → laser → cortex →
    ΔF/F → back), with a pulse travelling the loop; the feedback arm greys out
    and breaks under open loop. This is the main "what is happening" device.
  - a shaded TARGET BAND around the reference, so "on target" is legible without
    knowing what ΔF/F is; % time-in-band is reported.
  - timed CAPTIONS that narrate each beat, and act cards between sections.
  - one HERO TRIAL per condition played slowly and dissected, then the remaining
    trials as a fast montage.

Science + wording follow the manuscript (Closedloop_edit/results.tex): PI feedback
with feedforward compensation, reference tracking, and disturbance rejection
(trial-to-trial variance reduction that is specific to the stimulation window).
Colours follow the updated paper scheme: OL = red, CL = blue, input = gray.

Data: presentation/assets/demo_data_<key>.npz  (build_demo_data.py)

Run:
  .venv/Scripts/python.exe presentation/make_video_talk.py --session m13 --probe 0.5
  .venv/Scripts/python.exe presentation/make_video_talk.py --session m13 --hd
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

# ---- palette (light purple theme; condition colours per the paper) ----------
BG = "#f0eaf8"; PANEL2 = "#f9f6fd"; EDGE = "#ccc3df"; GRID = "#e9e3f3"
TXT = "#1b2230"; MUTE = "#6b7688"
OL_C = "#ff0000"          # open loop   (paper: red)
CL_C = "#0066d9"          # closed loop (paper: blue)
INP_C = "#8c8c8c"         # laser input (paper: gray, bold)
REFC = "#1b2230"          # reference line
BAND = "#bfe3c4"          # on-target band
STIMF = "#f6c9d0"         # stimulation window shading
ROIC = "#e11fbf"; GLOW = "#ff2e6a"
ACCENT = "#7d5bd0"        # narration / schematic accent
DEAD = "#c3c9d4"          # a broken / inactive loop arm

BANDW = 1.0               # target band half-width, %ΔF/F


def smooth(y, w=5):
    if w <= 1 or y is None:
        return y
    return np.convolve(y, np.ones(w) / w, mode="same")


def style_ax(ax):
    ax.set_facecolor(PANEL2)
    for s in ax.spines.values():
        s.set_color(EDGE); s.set_linewidth(0.8)
    ax.tick_params(colors=MUTE, labelsize=7.5, length=2)
    ax.grid(True, color=GRID, lw=0.6); ax.set_axisbelow(True)


# ============================ control-loop schematic =========================
class LoopDiagram:
    """Reference → Σ → PI → laser → cortex → ΔF/F → back to Σ.

    draw(closed, phase, active) — `closed` swaps the feedback arm between live
    and broken; `phase` in [0,1) moves the travelling pulse around the loop.
    """

    BOXES = {                       # name: (x0, x1, ycentre, label)
        "PI":     (0.255, 0.415, 0.63, "PI\ncontroller"),
        "LASER":  (0.470, 0.625, 0.63, "laser"),
        "CORTEX": (0.680, 0.880, 0.63, "cortex"),
    }
    SUM = (0.175, 0.63)             # summing junction centre
    BH = 0.20                       # box half-height
    FB_Y = 0.24                     # feedback arm height

    def __init__(self, ax):
        self.ax = ax
        ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
        ax.set_facecolor(PANEL2)
        ax.add_patch(plt.Rectangle((0, 0), 1, 1, transform=ax.transAxes,
                                   facecolor=PANEL2, edgecolor=EDGE, lw=0.8, zorder=0))
        ax.text(0.02, 0.95, "CONTROL LOOP", color=TXT, fontsize=8.5,
                fontweight="bold", va="top", ha="left")

        self.boxes, self.labels = {}, {}
        for name, (x0, x1, yc, lab) in self.BOXES.items():
            r = plt.Rectangle((x0, yc - self.BH), x1 - x0, 2 * self.BH,
                              facecolor="#ffffff", edgecolor=ACCENT, lw=1.4, zorder=3)
            ax.add_patch(r); self.boxes[name] = r
            self.labels[name] = ax.text((x0 + x1) / 2, yc, lab, ha="center", va="center",
                                        fontsize=7.6, color=TXT, fontweight="bold", zorder=4)
        # summing junction
        self.sum_c = plt.Circle(self.SUM, 0.052, facecolor="#ffffff",
                                edgecolor=ACCENT, lw=1.4, zorder=3)
        ax.add_patch(self.sum_c)
        ax.text(*self.SUM, "Σ", ha="center", va="center", fontsize=9,
                color=TXT, fontweight="bold", zorder=4)
        # reference input
        ax.text(0.015, 0.63, "ref\n−5%", ha="left", va="center", fontsize=7.4,
                color=REFC, fontweight="bold", zorder=4)
        self._arrow(0.098, 0.63, self.SUM[0] - 0.052, 0.63, REFC)

        # forward path arrows
        self._arrow(self.SUM[0] + 0.052, 0.63, 0.255, 0.63, ACCENT)
        self._arrow(0.415, 0.63, 0.470, 0.63, ACCENT)
        self._arrow(0.625, 0.63, 0.680, 0.63, ACCENT)

        # feedback arm (colour/​style toggled per condition)
        self.fb = []
        self.fb.append(ax.plot([0.78, 0.78], [0.43, self.FB_Y], color=ACCENT, lw=1.6, zorder=2)[0])
        self.fb.append(ax.plot([0.78, self.SUM[0]], [self.FB_Y, self.FB_Y], color=ACCENT, lw=1.6, zorder=2)[0])
        self.fb.append(ax.plot([self.SUM[0], self.SUM[0]], [self.FB_Y, 0.578], color=ACCENT, lw=1.6, zorder=2)[0])
        self.fb_lab = ax.text(0.50, self.FB_Y - 0.075, "measured ΔF/F  (35 Hz)", ha="center",
                              va="center", fontsize=7.0, color=ACCENT, zorder=4)
        # the break marker shown when the loop is open
        self.break_x = ax.text(0.50, self.FB_Y, "✕", ha="center", va="center",
                               fontsize=13, color=OL_C, fontweight="bold", zorder=6, visible=False)
        self.break_bg = plt.Rectangle((0.455, self.FB_Y - 0.055), 0.09, 0.11,
                                      facecolor=PANEL2, edgecolor="none", zorder=5, visible=False)
        ax.add_patch(self.break_bg)

        # travelling pulse
        self.pulse, = ax.plot([], [], "o", ms=7, color=CL_C, zorder=7)
        self.mode_tag = ax.text(0.98, 0.95, "", ha="right", va="top", fontsize=8.5,
                                fontweight="bold", zorder=6)

        # waypoints of the closed path (for the pulse)
        self.path = np.array([
            [self.SUM[0], 0.63], [0.255, 0.63], [0.415, 0.63], [0.470, 0.63],
            [0.625, 0.63], [0.680, 0.63], [0.78, 0.63], [0.78, self.FB_Y],
            [self.SUM[0], self.FB_Y], [self.SUM[0], 0.63],
        ])
        seg = np.linalg.norm(np.diff(self.path, axis=0), axis=1)
        self.cum = np.concatenate([[0], np.cumsum(seg)]); self.total = self.cum[-1]
        # forward-only path used when the loop is open (ref → Σ → PI → laser → cortex)
        self.fwd_end = 6

    def _arrow(self, x0, y0, x1, y1, col):
        self.ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                         arrowprops=dict(arrowstyle="-|>", color=col, lw=1.5,
                                         shrinkA=0, shrinkB=0), zorder=2)

    def _point_at(self, s):
        s = np.clip(s, 0, self.total)
        i = int(np.searchsorted(self.cum, s, side="right") - 1)
        i = min(max(i, 0), len(self.path) - 2)
        f = (s - self.cum[i]) / max(self.cum[i + 1] - self.cum[i], 1e-9)
        return self.path[i] + f * (self.path[i + 1] - self.path[i])

    def draw(self, closed, phase, active=True):
        col = CL_C if closed else OL_C
        for r in self.boxes.values():
            r.set_edgecolor(ACCENT if active else DEAD)
        self.sum_c.set_edgecolor(ACCENT if active else DEAD)
        # feedback arm
        for ln in self.fb:
            ln.set_color(ACCENT if closed else DEAD)
            ln.set_linestyle("-" if closed else (0, (3, 3)))
            ln.set_linewidth(1.6 if closed else 1.1)
        self.fb_lab.set_color(ACCENT if closed else DEAD)
        self.fb_lab.set_text("measured ΔF/F  (35 Hz)" if closed
                             else "no feedback — loop is open")
        self.break_x.set_visible(not closed); self.break_bg.set_visible(not closed)
        self.labels["PI"].set_text("PI\ncontroller" if closed else "fixed\ncommand")
        self.mode_tag.set_text("CLOSED LOOP" if closed else "OPEN LOOP")
        self.mode_tag.set_color(col)
        if not active:
            self.pulse.set_data([], []); return
        # pulse: full loop when closed, forward path only when open
        limit = self.total if closed else self.cum[self.fwd_end]
        p = self._point_at((phase % 1.0) * limit)
        self.pulse.set_data([p[0]], [p[1]]); self.pulse.set_color(col)


# ================================== main =====================================
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session", default="m13")
    ap.add_argument("--hd", action="store_true")
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--probe", type=float, default=None,
                    help="render ONE frame at fraction [0..1] to a PNG and exit")
    args = ap.parse_args()

    from scipy import ndimage
    from matplotlib.colors import Normalize

    z = np.load(os.path.join(ASSETS, f"demo_data_{args.session}.npz"), allow_pickle=True)
    D = {k: z[k] for k in z.files}
    Y, U = D["Y"], D["U"]
    LOOP = D["LOOP"].astype(str)
    VWIN = D["VWIN"]; Uf = D["U_ds"]; mimg = D["mimg"]; roi = D["roi"]
    t = D["t_win"]; REF = float(D["REF"]); DUR = float(D["DUR"]); PRE = int(D["PRE"])
    NWIN = Y.shape[1]; Ntr = Y.shape[0]; n = mimg.shape[0]
    mouse, date = str(D["mouse"]), str(D["date"])
    stim = (t >= 0) & (t <= DUR)

    # ---- headline statistics (computed here so captions can never drift) ----
    rmse = np.sqrt(np.mean((Y[:, stim] - REF) ** 2, axis=1))       # true RMSE, %ΔF/F
    ol_m, cl_m = LOOP == "OL", LOOP == "CL"
    RMSE_OL, RMSE_CL = rmse[ol_m].mean(), rmse[cl_m].mean()
    RMSE_DROP = 100 * (1 - RMSE_CL / RMSE_OL)
    var_ol = np.var(Y[ol_m][:, stim], axis=0).mean()
    var_cl = np.var(Y[cl_m][:, stim], axis=0).mean()
    VAR_DROP = 100 * (1 - var_cl / var_ol); VAR_RATIO = var_ol / var_cl
    inband = lambda M: 100 * np.mean(np.abs(Y[M][:, stim] - REF) <= BANDW)
    BAND_OL, BAND_CL = inband(ol_m), inband(cl_m)
    print(f"[{args.session}] RMSE OL {RMSE_OL:.2f} -> CL {RMSE_CL:.2f} ({RMSE_DROP:.0f}% lower) | "
          f"var {var_ol:.2f} -> {var_cl:.2f} ({VAR_DROP:.0f}% lower, {VAR_RATIO:.1f}x) | "
          f"in-band {BAND_OL:.0f}% -> {BAND_CL:.0f}%")

    # ---- brain mask + baseline-subtracted dF/F activity (as in make_video) ---
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
    soft = np.clip(ndimage.gaussian_filter(mask.astype(float), 3.0), 0.0, 1.0)

    def activity(trial, tau):
        v0 = VWIN[trial][:, :PRE].mean(axis=1)
        return 100.0 * (Uf @ (VWIN[trial][:, tau] - v0)).reshape(n, n) / mimg_safe

    _s = np.concatenate([activity(tr, tau)[mask].ravel()
                         for tr in np.linspace(0, Ntr - 1, 6).astype(int)
                         for tau in (PRE + 8, PRE + 30, PRE + 70)])
    clim = float(np.nanpercentile(np.abs(_s), 93))   # 93rd: more colour in the movie
    dcmap = plt.get_cmap("RdBu_r"); dnorm = Normalize(-clim, clim)
    gnorm = Normalize(np.percentile(mimg[mask], 2), np.percentile(mimg[mask], 97))
    anat_rgba = plt.get_cmap("gray")(gnorm(mimg)); anat_rgba[..., 3] = soft

    def act_rgba(trial, tau):
        df = np.nan_to_num(activity(trial, tau), nan=0.0, posinf=0.0, neginf=0.0)
        rgba = dcmap(dnorm(df))
        rgba[..., 3] = np.clip(np.abs(df) / (0.72 * clim), 0.0, 1.0) * soft
        return rgba

    # ---- frame schedule: intro | OL act | CL act | verdict ------------------
    INTRO, OUTRO, HERO, FAST = 108, 132, 60, 8
    ol_idx = [i for i in range(Ntr) if LOOP[i] == "OL"]
    cl_idx = [i for i in range(Ntr) if LOOP[i] == "CL"]
    # hero trials: the most typical OL trial, and a well-controlled CL trial
    hero_ol = int(ol_idx[np.argmin(np.abs(rmse[ol_idx] - np.median(rmse[ol_idx])))])
    hero_cl = int(cl_idx[np.argmin(rmse[cl_idx])])

    sched = []
    for k in range(INTRO):
        sched.append(dict(ph="intro", k=k))

    def add_act(name, hero, rest):
        for j, tau in enumerate(np.linspace(0, NWIN - 1, HERO).round().astype(int)):
            sched.append(dict(ph=name, tr=hero, tau=int(tau), hero=True, j=j, nj=HERO))
        for i in rest:
            for tau in np.linspace(0, NWIN - 1, FAST).round().astype(int):
                sched.append(dict(ph=name, tr=int(i), tau=int(tau), hero=False))

    add_act("ol", hero_ol, [i for i in ol_idx if i != hero_ol])
    add_act("cl", hero_cl, [i for i in cl_idx if i != hero_cl])
    for k in range(OUTRO):
        sched.append(dict(ph="outro", k=k))
    total = len(sched)
    act_start = {p: next(i for i, s in enumerate(sched) if s["ph"] == p)
                 for p in ("intro", "ol", "cl", "outro")}

    # ---- figure / layout ----------------------------------------------------
    dpi = 120 if args.hd else 100
    fig = plt.figure(figsize=(16, 9), dpi=dpi)
    fig.patch.set_facecolor(BG)
    gs = fig.add_gridspec(nrows=100, ncols=100, left=0.032, right=0.976,
                          top=0.885, bottom=0.115, wspace=0, hspace=0)

    axBrain = fig.add_subplot(gs[4:44, 0:19])
    axCB    = fig.add_subplot(gs[12:36, 19:20])
    axLoop  = fig.add_subplot(gs[6:42, 25:52])       # control-loop schematic
    axDF    = fig.add_subplot(gs[54:80, 0:52])       # ΔF/F vs target band
    axU     = fig.add_subplot(gs[86:100, 0:52])      # laser command
    axAvg   = fig.add_subplot(gs[4:50, 59:100])      # trial-averaged response
    axVar   = fig.add_subplot(gs[58:100, 59:100])    # across-trial variance
    for ax in (axBrain, axDF, axU, axAvg, axVar):
        style_ax(ax)

    # ---- title bar ----
    fig.text(0.032, 0.945, "CLOSED-LOOP CONTROL OF CORTICAL ACTIVITY", color=TXT,
             fontsize=20, fontweight="bold", va="center")
    act_label = fig.text(0.976, 0.945, "", color=MUTE, fontsize=11,
                         fontweight="bold", va="center", ha="right")
    from matplotlib.lines import Line2D
    fig.add_artist(Line2D([0.032, 0.976], [0.917, 0.917], color=EDGE, lw=1.0,
                          transform=fig.transFigure))

    # ---- narration bar (bottom) ----
    fig.add_artist(Line2D([0.032, 0.976], [0.083, 0.083], color=EDGE, lw=1.0,
                          transform=fig.transFigure))
    narr = fig.text(0.032, 0.046, "", color=TXT, fontsize=13.5, va="center", ha="left")
    narr_tag = fig.text(0.976, 0.046, f"{mouse} · {date}", color=MUTE, fontsize=9,
                        va="center", ha="right")

    # ---- brain ----
    axBrain.set_title("WIDEFIELD  ΔF/F      □ controlled ROI", color=TXT, fontsize=8.5,
                      fontweight="bold", loc="left", pad=4)
    axBrain.set_facecolor(BG)
    axBrain.imshow(anat_rgba, interpolation="bilinear", zorder=0)
    axim = axBrain.imshow(act_rgba(hero_ol, 0), interpolation="bilinear",
                          animated=True, zorder=1)
    axBrain.set_xticks([]); axBrain.set_yticks([]); axBrain.grid(False)
    for s in axBrain.spines.values():
        s.set_visible(False)
    from matplotlib.patches import Circle
    roi_glow = Circle((roi[0], roi[1]), 9, color=GLOW, alpha=0.0, zorder=5)
    axBrain.add_patch(roi_glow)
    axBrain.plot(roi[0], roi[1], "s", mec=ROIC, mfc="none", ms=13, mew=2.2, zorder=6)
    laser_pip = axBrain.text(0.5, 0.985, "", transform=axBrain.transAxes, ha="center",
                             va="top", fontsize=9, fontweight="bold", color=OL_C, zorder=8)

    from matplotlib.cm import ScalarMappable
    cb = fig.colorbar(ScalarMappable(norm=dnorm, cmap=dcmap), cax=axCB, orientation="vertical")
    cb.set_label("ΔF/F (%)", color=MUTE, fontsize=7, labelpad=2)
    cb.set_ticks([-clim, 0, clim]); cb.ax.set_yticklabels([f"−{clim:.0f}", "0", f"+{clim:.0f}"])
    cb.ax.tick_params(colors=MUTE, labelsize=6, length=2)
    cb.outline.set_edgecolor(EDGE); cb.outline.set_linewidth(0.6)

    loop = LoopDiagram(axLoop)

    # ---- ΔF/F with target band ----
    axDF.set_title("ACTIVITY IN THE CONTROLLED REGION", color=TXT, fontsize=9,
                   fontweight="bold", loc="left", pad=4)
    axDF.set_xlim(t.min(), t.max()); axDF.set_ylim(-11, 5)
    axDF.set_ylabel("%ΔF/F", color=MUTE, fontsize=8.5)
    axDF.axvspan(0, DUR, color=STIMF, alpha=0.55, lw=0)
    axDF.axhspan(REF - BANDW, REF + BANDW, color=BAND, alpha=0.75, lw=0, zorder=1)
    axDF.axhline(REF, color=REFC, ls="--", lw=1.6, zorder=2)
    axDF.axhline(0, color="#b4bccb", ls=":", lw=1.0)
    axDF.text(t.min() + 0.06, REF - BANDW - 0.3, "target band", color="#2f7d4f",
              fontsize=8, ha="left", va="top", fontweight="bold")
    df_line, = axDF.plot([], [], color=OL_C, lw=2.6, solid_capstyle="round")
    df_head, = axDF.plot([], [], "o", color=TXT, ms=5)
    axDF.tick_params(labelbottom=False)
    onoff = axDF.text(0.012, 0.06, "", transform=axDF.transAxes, fontsize=8.5,
                      fontweight="bold", color=MUTE, va="bottom")

    # ---- laser command ----
    axU.set_title("LASER COMMAND", color=TXT, fontsize=8.5, fontweight="bold",
                  loc="left", pad=3)
    axU.set_xlim(t.min(), t.max())
    axU.set_ylim(0, float(np.nanpercentile(U, 99.5)) * 1.15 + 1e-6)
    axU.set_ylabel("a.u.", color=MUTE, fontsize=8.5)
    axU.set_xlabel("time from stimulation onset (s)", color=MUTE, fontsize=8.5)
    axU.axvspan(0, DUR, color=STIMF, alpha=0.55, lw=0)
    u_line, = axU.plot([], [], color=INP_C, lw=2.2)
    u_fill = [None]

    # ---- trial-averaged response ----
    axAvg.set_title("", color=TXT, fontsize=9.5, fontweight="bold", loc="left", pad=5)
    axAvg.set_xlim(t.min(), t.max()); axAvg.set_ylim(-11, 5)
    axAvg.set_ylabel("%ΔF/F", color=MUTE, fontsize=8.5)
    axAvg.axvspan(0, DUR, color=STIMF, alpha=0.45, lw=0)
    axAvg.axhspan(REF - BANDW, REF + BANDW, color=BAND, alpha=0.7, lw=0, zorder=1)
    axAvg.axhline(REF, color=REFC, ls="--", lw=1.6, zorder=2)
    ol_mean, = axAvg.plot([], [], color=OL_C, lw=3.4, zorder=7, label="open loop")
    cl_mean, = axAvg.plot([], [], color=CL_C, lw=3.4, zorder=8, label="closed loop")
    avg_leg = axAvg.legend(loc="lower right", fontsize=9, frameon=True,
                           facecolor="#ffffff", edgecolor=EDGE, labelcolor=TXT)
    avg_leg.set_visible(False)

    # ---- across-trial variance ----
    axVar.set_title("", color=TXT, fontsize=9.5, fontweight="bold", loc="left", pad=5)
    axVar.set_xlim(t.min(), t.max())
    vmax = 1.2 * max(np.var(Y[ol_m], axis=0).max(), np.var(Y[cl_m], axis=0).max())
    axVar.set_ylim(0, vmax)
    axVar.set_xlabel("time from stimulation onset (s)", color=MUTE, fontsize=8.5)
    axVar.set_ylabel("variance across trials  (%ΔF/F)²", color=MUTE, fontsize=8.5)
    axVar.axvspan(0, DUR, color=STIMF, alpha=0.45, lw=0)
    ol_var, = axVar.plot([], [], color=OL_C, lw=3.0, zorder=7, label="open loop")
    cl_var, = axVar.plot([], [], color=CL_C, lw=3.0, zorder=8, label="closed loop")
    var_leg = axVar.legend(loc="upper right", fontsize=9, frameon=True,
                           facecolor="#ffffff", edgecolor=EDGE, labelcolor=TXT)
    var_leg.set_visible(False)

    # running evidence counter (appears once closed-loop trials accumulate)
    score = fig.text(0.976, 0.895, "", color=CL_C, fontsize=11, fontweight="bold",
                     va="top", ha="right")

    # ---- act card overlay ----
    card_bg = plt.Rectangle((0, 0), 1, 1, transform=fig.transFigure, facecolor=BG,
                            edgecolor="none", zorder=50, visible=False)
    fig.add_artist(card_bg)
    card_t = fig.text(0.5, 0.56, "", ha="center", va="center", fontsize=40,
                      fontweight="bold", color=TXT, zorder=51, visible=False)
    card_s = fig.text(0.5, 0.44, "", ha="center", va="center", fontsize=17,
                      color=MUTE, zorder=51, visible=False)

    def show_card(title, sub, alpha):
        card_bg.set_visible(True); card_bg.set_alpha(alpha)
        for a, txt in ((card_t, title), (card_s, sub)):
            a.set_visible(True); a.set_text(txt); a.set_alpha(alpha)

    def hide_card():
        card_bg.set_visible(False)
        card_t.set_visible(False); card_s.set_visible(False)

    trial_lines = []

    # ---- narration script ---------------------------------------------------
    INTRO_BEATS = [
        (0.00, "A single cortical region is our control target."),
        (0.28, "Wide-field calcium imaging reads out its activity as ΔF/F, 35 times a second."),
        (0.56, "A laser drives an inhibitory opsin nearby, pushing that activity down."),
        (0.80, f"The goal: hold the region at {REF:.0f}% ΔF/F — inside the green band."),
    ]
    OL_HERO_BEATS = [
        (0.00, "OPEN LOOP: the laser plays a fixed command, computed in advance."),
        (0.33, "Nothing is measured back — the loop is broken."),
        (0.62, "So spontaneous fluctuations go uncorrected, and the response misses the band."),
    ]
    CL_HERO_BEATS = [
        (0.00, "CLOSED LOOP: now the measured ΔF/F is fed back and compared to the target."),
        (0.33, "The PI controller turns that error into a correction, every single frame."),
        (0.62, "The command now changes shape trial by trial — that is feedback at work."),
    ]

    def beat(beats, frac):
        msg = beats[0][1]
        for f0, m in beats:
            if frac >= f0:
                msg = m
        return msg

    # ============================== per-frame ================================
    def draw_frame(fnum):
        s = sched[fnum]; ph = s["ph"]
        shown = [x for x in sched[:fnum + 1] if "tr" in x]
        seen = list(dict.fromkeys(x["tr"] for x in shown))

        # ---------- act cards ----------
        if ph == "intro" and s["k"] < 34:
            a = 1.0 if s["k"] < 22 else 1.0 - (s["k"] - 22) / 12
            show_card("Can we hold a brain region at a set-point?",
                      "closed-loop optogenetic control of cortical activity", a)
        elif ph in ("ol", "cl") and fnum - act_start[ph] < 26:
            k = fnum - act_start[ph]
            a = 1.0 if k < 15 else 1.0 - (k - 15) / 11
            if ph == "ol":
                show_card("OPEN LOOP", "a fixed light command — no feedback", a)
            else:
                show_card("CLOSED LOOP", "measure the error, correct it, every frame", a)
        elif ph == "outro":
            # fade the card in, hold, then fade it back OUT so the video ends on
            # the completed evidence rather than on a blank card
            k = s["k"]
            if k < 12:
                a = k / 12
            elif k < 58:
                a = 1.0
            elif k < 80:
                a = 1.0 - (k - 58) / 22
            else:
                a = 0.0
            if a > 0.02:
                show_card("Feedback controls cortical activity",
                          f"tracking error −{RMSE_DROP:.0f}%     ·     "
                          f"trial-to-trial variability −{VAR_DROP:.0f}%", a)
            else:
                hide_card()
        else:
            hide_card()

        # ---------- act label + narration ----------
        if ph == "intro":
            frac = s["k"] / max(INTRO - 1, 1)
            act_label.set_text("THE SETUP"); act_label.set_color(MUTE)
            narr.set_text(beat(INTRO_BEATS, frac)); narr.set_color(TXT)
            loop.draw(closed=True, phase=frac * 2.0, active=frac > 0.5)
            axim.set_data(act_rgba(hero_ol, int(frac * PRE)))
            laser_pip.set_text("")
            onoff.set_text("")
            return

        if ph == "outro":
            act_label.set_text("THE RESULT"); act_label.set_color(CL_C)
            narr.set_text(f"Closed loop held the target more accurately and far more "
                          f"repeatably — {VAR_RATIO:.1f}× less trial-to-trial variance.")
            narr.set_color(TXT)
            loop.draw(closed=True, phase=s["k"] / 22.0, active=True)
            score.set_text(f"tracking error −{RMSE_DROP:.0f}%   ·   "
                           f"variability −{VAR_DROP:.0f}%   "
                           f"({len(ol_idx)} OL / {len(cl_idx)} CL trials)")
            # draw the FINAL state explicitly, so the closing frames are complete
            # regardless of playback history (and so --probe is truthful here)
            for i in range(Ntr):
                if i not in trial_lines:
                    axAvg.plot(t, smooth(Y[i], 7), color=CL_C if LOOP[i] == "CL" else OL_C,
                               lw=0.6, alpha=0.16, zorder=3)
                    trial_lines.append(i)
            ol_mean.set_data(t, smooth(np.mean(Y[ol_m], 0), 7))
            cl_mean.set_data(t, smooth(np.mean(Y[cl_m], 0), 7))
            ol_var.set_data(t, smooth(np.var(Y[ol_m], axis=0), 7))
            cl_var.set_data(t, smooth(np.var(Y[cl_m], axis=0), 7))
            avg_leg.set_visible(True); var_leg.set_visible(True)
            axAvg.set_title("TRIAL AVERAGE  —  closed loop sits on target, "
                            "open loop falls short", color=TXT, fontsize=9.5,
                            fontweight="bold", loc="left", pad=5)
            axVar.set_title("TRIAL-TO-TRIAL VARIABILITY  —  feedback rejects the "
                            "disturbance", color=TXT, fontsize=9.5,
                            fontweight="bold", loc="left", pad=5)
            # hold the rig on the best closed-loop trial, mid-stimulation
            axim.set_data(act_rgba(hero_cl, PRE + int(1.2 * 35)))
            roi_glow.set_alpha(0.5); laser_pip.set_text("● LASER ON")
            laser_pip.set_color(CL_C); onoff.set_text("stimulation on")
            df_line.set_data(t, Y[hero_cl]); df_line.set_color(CL_C)
            df_head.set_data([t[-1]], [Y[hero_cl][-1]]); df_head.set_color(CL_C)
            if u_fill[0] is not None:
                u_fill[0].remove()
            u_line.set_data(t, U[hero_cl])
            u_fill[0] = axU.fill_between(t, 0, U[hero_cl], color=INP_C, alpha=0.22)
            return

        # ---------- trial playback ----------
        tr, tau = s["tr"], s["tau"]
        closed = LOOP[tr] == "CL"
        col = CL_C if closed else OL_C
        nrev = tau + 1; xs = t[:nrev]
        on = 0 <= t[tau] <= DUR

        act_label.set_text("CLOSED LOOP" if closed else "OPEN LOOP")
        act_label.set_color(col)

        axim.set_data(act_rgba(tr, tau))
        roi_glow.set_alpha(0.5 if on else 0.0)
        laser_pip.set_text("● LASER ON" if on else "")
        laser_pip.set_color(col)
        onoff.set_text("stimulation on" if on else "")

        loop.draw(closed=closed, phase=fnum / 9.0, active=on)

        # hero trials sweep in live; montage trials show the whole trial at once
        # (so the trace panel is never near-empty at a trial boundary)
        m = nrev if s.get("hero") else NWIN
        df_line.set_data(t[:m], Y[tr][:m]); df_line.set_color(col)
        df_head.set_data([t[m - 1]], [Y[tr][m - 1]]); df_head.set_color(col)
        uu = U[tr][:m]; xs = t[:m]; u_line.set_data(xs, uu)
        if u_fill[0] is not None:
            u_fill[0].remove()
        u_fill[0] = axU.fill_between(xs, 0, uu, color=INP_C, alpha=0.22)

        if s.get("hero"):
            frac = s["j"] / max(s["nj"] - 1, 1)
            narr.set_text(beat(OL_HERO_BEATS if not closed else CL_HERO_BEATS, frac))
            narr.set_color(TXT)
        else:
            k = len([x for x in shown if LOOP[x["tr"]] == ("CL" if closed else "OL")])
            ntot = len(cl_idx) if closed else len(ol_idx)
            if closed:
                narr.set_text("Every closed-loop trial is steered back toward the target "
                              "— the spread collapses.")
            else:
                narr.set_text("Trial after trial, the same fixed command lands in a "
                              "different place.")
            narr.set_color(MUTE)

        # ---------- accumulate right-hand panels ----------
        for i in seen[len(trial_lines):]:
            axAvg.plot(t, smooth(Y[i], 7), color=CL_C if LOOP[i] == "CL" else OL_C,
                       lw=0.6, alpha=0.16, zorder=3)
            trial_lines.append(i)
        so = [i for i in seen if LOOP[i] == "OL"]; sc = [i for i in seen if LOOP[i] == "CL"]
        if so:
            ol_mean.set_data(t, smooth(np.mean(Y[so], 0), 7))
        if sc:
            cl_mean.set_data(t, smooth(np.mean(Y[sc], 0), 7))
        if len(so) >= 2:
            ol_var.set_data(t, smooth(np.var(Y[so], axis=0), 7))
        if len(sc) >= 2:
            cl_var.set_data(t, smooth(np.var(Y[sc], axis=0), 7))
        avg_leg.set_visible(bool(sc)); var_leg.set_visible(len(sc) >= 2)

        if sc:
            axAvg.set_title("TRIAL AVERAGE  —  closed loop sits on target, "
                            "open loop falls short", color=TXT, fontsize=9.5,
                            fontweight="bold", loc="left", pad=5)
            axVar.set_title("TRIAL-TO-TRIAL VARIABILITY  —  feedback rejects the "
                            "disturbance", color=TXT, fontsize=9.5,
                            fontweight="bold", loc="left", pad=5)
        else:
            axAvg.set_title("TRIAL AVERAGE  —  where does the response actually land?",
                            color=TXT, fontsize=9.5, fontweight="bold", loc="left", pad=5)
            axVar.set_title("TRIAL-TO-TRIAL VARIABILITY  —  how repeatable is it?",
                            color=TXT, fontsize=9.5, fontweight="bold", loc="left", pad=5)

        # running evidence counter, once there is enough closed-loop data
        if len(sc) >= 4:
            r_ol = rmse[so].mean(); r_cl = rmse[sc].mean()
            v_o = np.var(Y[so][:, stim], axis=0).mean()
            v_c = np.var(Y[sc][:, stim], axis=0).mean()
            score.set_text(f"tracking error −{100*(1-r_cl/r_ol):.0f}%   ·   "
                           f"variability −{100*(1-v_c/v_o):.0f}%   (n={len(sc)} CL trials)")
        else:
            score.set_text("")

    # ================================ output =================================
    if args.probe is not None:
        fnum = int(np.clip(args.probe, 0.0, 1.0) * (total - 1))
        draw_frame(fnum)
        pout = os.path.join(ROOT, "presentation", f"_probe_talk_{args.session}.png")
        fig.savefig(pout, dpi=dpi, facecolor=BG)
        print(f"[probe] frame {fnum}/{total} phase={sched[fnum]['ph']} -> {pout}")
        return

    print(f"[render] {total} frames ({total/args.fps:.1f}s)  {'1080p' if args.hd else '900p'}")
    outname = os.path.join(ROOT, "presentation",
                           f"controller_talk_{args.session}{'_hd' if args.hd else ''}.mp4")
    writer = manim.FFMpegWriter(fps=args.fps, bitrate=7000,
                                metadata=dict(title="Closed-loop control — talk cut"))
    with writer.saving(fig, outname, dpi=dpi):
        for fnum in range(total):
            draw_frame(fnum)
            writer.grab_frame(facecolor=BG)
            if fnum % 60 == 0:
                print(f"  frame {fnum}/{total}")
    print("wrote", outname, f"({os.path.getsize(outname)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
