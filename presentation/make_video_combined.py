"""
make_video_combined.py — COMBINED talk cut: constant + moving reference.

An alternate to make_video.py (which is left untouched). Where that one is a
"live rig" dashboard, this one is a narrated argument built for a talk: it walks
the audience through the system, shows open loop failing, shows closed loop
working, and ends on the numbers.

Structure
  ACT 0  PREMISE   — what is being controlled, and how it is measured
  ACT 1  OPEN LOOP — fixed command, feedback arm visibly BROKEN; responses miss
  ACT 2  CLOSED LOOP — feedback arm live; controller corrects, responses converge
  ACT 3  MOVING TARGET — AL_0048 sine tracking. The reference is no longer a
                     constant: it moves. Only the two conditions that bracket
                     the result are shown — open loop, and closed loop with
                     feedforward preview — and the schematic grows a
                     feedforward branch feeding the reference straight to the
                     laser, alongside the feedback correction.
  ACT 4  VERDICT   — the whole dataset: per-session tracking error and the
                     window-specific variance ratio (Fig. 3G / 3I equivalents)

Explanatory devices
  - an animated CONTROL-LOOP SCHEMATIC (reference → Σ → PI → laser → cortex →
    ΔF/F → back), with a pulse travelling the loop; the feedback arm greys out
    and breaks under open loop. This is the main "what is happening" device.
  - a shaded TARGET BAND around the reference, so "on target" is legible without
    knowing what ΔF/F is; % time-in-band is reported.
  - timed CAPTIONS that narrate each beat, and act cards between sections.
  - THREE REAL-TIME TRIALS per condition (1x speed, spanning the session's RMSE
    distribution so they are representative, not cherry-picked), each narrated,
    interleaved with fast montage chunks of the remaining trials.
  - a closing CROSS-SESSION summary from all 13 sessions / 2 mice
    (presentation/assets/xsession_stats.mat, built by export_xsession_stats.m).

Science + wording follow the manuscript (Closedloop_edit/results.tex): PI feedback
with feedforward compensation, reference tracking, and disturbance rejection
(trial-to-trial variance reduction that is specific to the stimulation window).
Colours follow the updated paper scheme: OL = red, CL = blue, input = gray.

Both chapters share one figure and one panel geometry, so the cut reads as one
video rather than two stitched together. The camera / pupil / face-motion panels
of the standalone FF video are NOT carried over: they need a different layout,
and the subject here is the controller.

Data: presentation/assets/demo_data_<key>.npz   (build_demo_data.py)
      presentation/assets/demo_ff_<key>.npz     (build_ff_data.py)
      presentation/assets/xsession_stats.mat    (export_xsession_stats.m)

Run:
  .venv/Scripts/python.exe presentation/make_video_combined.py --probe 0.5
  .venv/Scripts/python.exe presentation/make_video_combined.py --hd
"""
import argparse
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.animation as manim
import matplotlib.ticker as mticker
import imageio_ffmpeg

_SUPS = str.maketrans("-0123456789", "⁻⁰¹²³⁴⁵⁶⁷⁸⁹")


def _sup(n):
    """render an integer exponent as Unicode superscript digits"""
    return str(int(n)).translate(_SUPS)

matplotlib.rcParams["animation.ffmpeg_path"] = imageio_ffmpeg.get_ffmpeg_exe()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")

# ---- palette --------------------------------------------------------------
# Condition colours are LOCKED to the paper (open loop red, closed loop blue)
# and are identical in every theme; only the deck around them changes. The
# "bone" deck is a warm neutral so the two saturated hues are the only strong
# colours on screen; "lavender" is the original purple deck.
THEMES = {
    "bone": dict(BG="#f5f2ec", PANEL2="#fffdf8", EDGE="#ddd6c8", GRID="#eae4d8",
                 TXT="#15191f", MUTE="#6f7581", HAIR="#e2dbcd", LINK="#bcb5a8",
                 STIMF="#f3d4cf", ACCENT="#a3672f", DEAD="#cac3b6"),
    "lavender": dict(BG="#f0eaf8", PANEL2="#f9f6fd", EDGE="#ccc3df", GRID="#e9e3f3",
                     TXT="#1b2230", MUTE="#6b7688", HAIR="#d9d1ea", LINK="#a8a0bd",
                     STIMF="#f6c9d0", ACCENT="#7d5bd0", DEAD="#c3c9d4"),
}
OL_C = "#ff0000"          # open loop   (paper: red)   -- locked
CL_C = "#0066d9"          # closed loop (paper: blue)  -- locked
INP_C = "#8c8c8c"         # laser input (paper: gray, bold)
BAND = "#bfe3c4"          # on-target band
FF_C = "#008000"          # feedforward / CL+preview (paper Fig-5 green) -- locked
ROIC = "#e11fbf"; GLOW = "#ff2e6a"


def apply_theme(name):
    """set the deck colours as module globals (called before the figure is built)"""
    globals().update(THEMES[name])
    globals()["REFC"] = THEMES[name]["TXT"]


apply_theme("bone")

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
        # bottom-left: the top-left corner is needed by the feedforward block
        ax.text(0.02, 0.045, "CONTROL LOOP", color=TXT, fontsize=8.5,
                fontweight="bold", va="bottom", ha="left")

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
        self.ref_lab = ax.text(0.015, 0.63, "ref\n−5%", ha="left", va="center",
                               fontsize=7.4, color=REFC, fontweight="bold", zorder=4)
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

        # ---- feedforward branch (shown only in the moving-reference act) ----
        # the reference is fed straight to the laser in parallel with the
        # feedback correction, so the controller need not wait for an error
        FFY, INJ = 0.902, 0.4425
        self.ff_box = plt.Rectangle((0.255, FFY - 0.065), 0.160, 0.130,
                                    facecolor="#ffffff", edgecolor=FF_C, lw=1.4,
                                    zorder=3, visible=False)
        ax.add_patch(self.ff_box)
        self.ff_lab = ax.text(0.335, FFY, "feedforward" + chr(10) + "(preview)",
                              ha="center", va="center", fontsize=7.0, color=TXT,
                              fontweight="bold", zorder=4, visible=False)
        self.ff = [
            ax.plot([0.130, 0.130], [0.66, FFY], color=FF_C, lw=1.5, zorder=2,
                    visible=False)[0],
            ax.plot([0.130, 0.255], [FFY, FFY], color=FF_C, lw=1.5, zorder=2,
                    visible=False)[0],
            ax.plot([0.415, INJ], [FFY, FFY], color=FF_C, lw=1.5, zorder=2,
                    visible=False)[0],
            ax.plot([INJ, INJ], [FFY, 0.668], color=FF_C, lw=1.5, zorder=2,
                    visible=False)[0],
        ]
        self.ff_plus = ax.text(INJ, 0.645, "+", ha="center", va="bottom",
                               fontsize=11, color=FF_C, fontweight="bold",
                               zorder=6, visible=False)

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

    def draw(self, closed, phase, active=True, ff=False, tag=None, col=None,
             moving=None):
        col = col or (CL_C if closed else OL_C)
        for a in self.ff + [self.ff_box, self.ff_lab, self.ff_plus]:
            a.set_visible(ff)
        if moving is not None:
            self.ref_lab.set_text("ref\nsine" if moving else "ref\n−5%")
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
        self.mode_tag.set_text(tag or ("CLOSED LOOP" if closed else "OPEN LOOP"))
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
    ap.add_argument("--ffkey", default="0721", help="moving-reference bundle key")
    ap.add_argument("--hd", action="store_true")
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--probe", type=float, default=None,
                    help="render ONE frame at fraction [0..1] to a PNG and exit")
    ap.add_argument("--theme", default="bone", choices=sorted(THEMES),
                    help="deck palette; condition colours are locked either way")
    args = ap.parse_args()
    apply_theme(args.theme)

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

    # ---- cross-session summary (all 13 sessions) for the closing panels -----
    # from export_xsession_stats.m; the Figure-3 quantities, recomputed per session
    import scipy.io as sio
    X = sio.loadmat(os.path.join(ASSETS, "xsession_stats.mat"))
    xs = {k: X[k].ravel().astype(float) for k in
          ("rmse_ol", "rmse_cl", "var_ol", "var_cl",
           "var_ol_pre", "var_cl_pre", "var_ol_post", "var_cl_post",
           "rmse_ol_e", "rmse_cl_e", "rmse_ol_s", "rmse_cl_s", "nOL", "nCL")}
    xs_v = {"ol": X["vtr_ol"].astype(float), "cl": X["vtr_cl"].astype(float)}
    tx = X["t_axis"].ravel().astype(float)
    xmice = [str(m[0]) for m in X["mice"].ravel()]
    X_NTRIALS = int(np.nansum(X["nOL"].ravel()) + np.nansum(X["nCL"].ravel()))
    NSESS = len(xs["rmse_ol"]); NMICE = len(set(xmice))
    X_RMSE_DROP = 100 * np.median(1 - xs["rmse_cl"] / xs["rmse_ol"])
    X_NBETTER = int(np.sum(xs["rmse_cl"] < xs["rmse_ol"]))
    X_RATIO = {"pre": xs["var_ol_pre"] / xs["var_cl_pre"],
               "stim": xs["var_ol"] / xs["var_cl"],
               "post": xs["var_ol_post"] / xs["var_cl_post"]}
    X_PR = float(X["p_r"].ravel()[0]); X_PV = float(X["p_v"].ravel()[0])
    print(f"  cross-session: n={NSESS} sessions / {NMICE} mice | RMSE -{X_RMSE_DROP:.0f}% "
          f"({X_NBETTER}/{NSESS} improved, p={X_PR:.1e}) | variance ratio "
          f"pre {np.median(X_RATIO['pre']):.2f} / stim {np.median(X_RATIO['stim']):.2f} "
          f"/ post {np.nanmedian(X_RATIO['post']):.2f}")
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

    # ============ chapter 2 data: moving reference (AL_0048, 1 Hz sine) ======
    # Only two of the four sine conditions are carried into this cut: open loop
    # and closed loop + feedforward preview. They bracket the result, and two
    # traces stay legible on a projector where four do not.
    FF_SEQ = [2, 0]
    FF_COL = {2: OL_C, 0: FF_C}
    FF_NAME = {2: "open loop", 0: "closed loop + preview"}
    FF_TAG = {2: "OPEN LOOP  ·  moving target", 0: "CLOSED LOOP + PREVIEW"}

    zf = np.load(os.path.join(ASSETS, f"demo_ff_{args.ffkey}.npz"), allow_pickle=True)
    F = {k: zf[k] for k in zf.files}
    F_U, F_mimg, F_roi = F["U_ds"], F["mimg"], F["roi"]
    F_V, F_dF, F_REF, F_INP = F["Vwin"], F["dFoF"], F["REFW"], F["INP"]
    F_ffc = np.asarray(F["ffc"]).ravel()
    F_PRE, F_FS, F_DUR = int(F["n_pre"]), float(F["fs"]), float(F["dur"])
    F_t = np.asarray(F["t_win"], float)
    F_n, F_NWIN = F_mimg.shape[0], F_dF.shape[1]
    F_mouse, F_date = str(F["mouse"]), str(F["date"])
    F_bs = F_dF - np.nanmean(F_dF[:, :F_PRE], axis=1, keepdims=True)
    F_stim = (F_t >= 0) & (F_t <= F_DUR)
    ff_idx = {c: np.where(F_ffc == c)[0] for c in FF_SEQ}

    F_mask = ndimage.binary_fill_holes(F_mimg > np.percentile(F_mimg, 15))
    _lbl, _nl = ndimage.label(F_mask)
    if _nl > 1:
        _sz = ndimage.sum(np.ones_like(_lbl), _lbl, index=range(1, _nl + 1))
        F_mask = _lbl == (1 + int(np.argmax(_sz)))
    F_mask = ndimage.binary_fill_holes(
        ndimage.gaussian_filter(F_mask.astype(float), 2.5) > 0.5)
    F_msafe = np.where(F_mimg > 1e-3, F_mimg, np.nan)
    F_soft = np.clip(ndimage.gaussian_filter(F_mask.astype(float), 3.0), 0.0, 1.0)

    def F_activity(trial, tau):
        v0 = F_V[trial][:, :F_PRE].mean(axis=1)
        return 100.0 * (F_U @ (F_V[trial][:, tau] - v0)).reshape(F_n, F_n) / F_msafe

    _fs = np.concatenate([F_activity(tr, tau)[F_mask].ravel()
                          for tr in np.linspace(0, F_dF.shape[0] - 1, 8).astype(int)
                          for tau in range(F_PRE + 10, F_NWIN - 5, 25)])
    F_clim = float(np.nanpercentile(np.abs(_fs), 96))
    F_dnorm = Normalize(-F_clim, F_clim)
    F_gnorm = Normalize(np.percentile(F_mimg[F_mask], 2),
                        np.percentile(F_mimg[F_mask], 97))
    F_anat = plt.get_cmap("gray")(F_gnorm(F_mimg)); F_anat[..., 3] = F_soft

    def F_act_rgba(trial, tau):
        df = np.nan_to_num(F_activity(trial, tau), nan=0.0, posinf=0.0, neginf=0.0)
        rgba = dcmap(F_dnorm(df))
        rgba[..., 3] = np.clip(np.abs(df) / (0.72 * F_clim), 0.0, 1.0) * F_soft
        return rgba

    # per-trial squared tracking error against the moving reference (raw traces,
    # the paper's convention -- see RESEARCH.md 2026-07-24)
    def ff_mse(sel):
        return float(np.nanmean((F_dF[sel][:, F_stim] - F_REF[sel][:, F_stim]) ** 2))

    print(f"  moving reference: {F_mouse} {F_date} | "
          + " | ".join(f"{FF_NAME[c]} n={len(ff_idx[c])} mse={ff_mse(ff_idx[c]):.2f}"
                       for c in FF_SEQ))

    # ---- frame schedule: intro | OL act | CL act | moving target | verdict ---
    # HERO = true real time: one output frame per real frame of the window
    HERO = int(round(args.fps * (t.max() - t.min())))
    INTRO, OUTRO, FAST, NHERO = 108, 200, 8, 3
    ol_idx = [i for i in range(Ntr) if LOOP[i] == "OL"]
    cl_idx = [i for i in range(Ntr) if LOOP[i] == "CL"]

    def pick_heroes(idx, qs):
        """trials spanning the RMSE distribution — representative, not cherry-picked"""
        out = []
        for q in qs:
            target = np.quantile(rmse[idx], q)
            cand = [i for i in idx if i not in out]
            out.append(int(cand[int(np.argmin(np.abs(rmse[cand] - target)))]))
        return out

    heroes_ol = pick_heroes(ol_idx, [0.25, 0.50, 0.80])
    heroes_cl = pick_heroes(cl_idx, [0.20, 0.50, 0.75])
    hero_cl = heroes_cl[0]                      # best CL trial, used for the finale
    print(f"  real-time trials: OL {heroes_ol} | CL {heroes_cl}  ({HERO} frames each)")

    sched = []
    for k in range(INTRO):
        sched.append(dict(ph="intro", k=k))

    def add_act(name, heroes, rest):
        """hero (real time) → montage chunk → hero → chunk → hero → chunk"""
        chunks = np.array_split(np.array(rest), NHERO) if len(rest) else [np.array([])] * NHERO
        for hi, h in enumerate(heroes):
            for j, tau in enumerate(np.linspace(0, NWIN - 1, HERO).round().astype(int)):
                sched.append(dict(ph=name, tr=int(h), tau=int(tau), hero=True,
                                  hi=hi, j=j, nj=HERO))
            for i in chunks[hi]:
                for tau in np.linspace(0, NWIN - 1, FAST).round().astype(int):
                    sched.append(dict(ph=name, tr=int(i), tau=int(tau), hero=False))

    add_act("ol", heroes_ol, [i for i in ol_idx if i not in heroes_ol])
    add_act("cl", heroes_cl, [i for i in cl_idx if i not in heroes_cl])

    # chapter 2: one real-time trial per condition (the median-error one, so it
    # is representative), then a fast montage of that condition's other trials
    HERO_FF = int(round(args.fps * (F_t.max() - F_t.min())))
    FAST_FF, FF_MONT = 4, 22
    ff_hero = {}
    for c in FF_SEQ:
        idx = ff_idx[c]
        e = np.nanmean((F_dF[idx][:, F_stim] - F_REF[idx][:, F_stim]) ** 2, axis=1)
        ff_hero[c] = int(idx[int(np.argmin(np.abs(e - np.median(e))))])
        for j, tau in enumerate(np.linspace(0, F_NWIN - 1, HERO_FF).round().astype(int)):
            sched.append(dict(ph="ff", tr=ff_hero[c], tau=int(tau), hero=True,
                              mode=int(c), j=j, nj=HERO_FF))
        rest = [i for i in idx if i != ff_hero[c]]
        if rest:
            keep = np.unique(np.linspace(0, len(rest) - 1,
                                         min(len(rest), FF_MONT)).round().astype(int))
            for i in (rest[k] for k in keep):
                for tau in np.linspace(0, F_NWIN - 1, FAST_FF).round().astype(int):
                    sched.append(dict(ph="ff", tr=int(i), tau=int(tau), hero=False,
                                      mode=int(c)))

    for k in range(OUTRO):
        sched.append(dict(ph="outro", k=k))
    total = len(sched)
    act_start = {p: next(i for i, s in enumerate(sched) if s["ph"] == p)
                 for p in ("intro", "ol", "cl", "ff", "outro")}

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
    fig.text(0.032, 0.945, "TARGETED CLOSED-LOOP OPTOGENETIC CONTROL OF CORTICAL DYNAMICS",
             color=TXT, fontsize=16.5, fontweight="bold", va="center")
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
    anat_im = axBrain.imshow(anat_rgba, interpolation="bilinear", zorder=0)
    axim = axBrain.imshow(act_rgba(heroes_ol[0], 0), interpolation="bilinear",
                          animated=True, zorder=1)
    axBrain.set_xticks([]); axBrain.set_yticks([]); axBrain.grid(False)
    for s in axBrain.spines.values():
        s.set_visible(False)
    from matplotlib.patches import Circle
    roi_glow = Circle((roi[0], roi[1]), 9, color=GLOW, alpha=0.0, zorder=5)
    axBrain.add_patch(roi_glow)
    roi_sq, = axBrain.plot([roi[0]], [roi[1]], "s", mec=ROIC, mfc="none", ms=13,
                           mew=2.2, zorder=6)
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
    const_art = [
        axDF.axvspan(0, DUR, color=STIMF, alpha=0.55, lw=0),
        axDF.axhspan(REF - BANDW, REF + BANDW, color=BAND, alpha=0.75, lw=0, zorder=1),
        axDF.axhline(REF, color=REFC, ls="--", lw=1.6, zorder=2),
        axDF.axhline(0, color="#b4bccb", ls=":", lw=1.0),
        axDF.text(t.min() + 0.06, REF - BANDW - 0.3, "target band", color="#2f7d4f",
                  fontsize=8, ha="left", va="top", fontweight="bold"),
    ]
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
    const_art += [axU.axvspan(0, DUR, color=STIMF, alpha=0.55, lw=0)]
    u_line, = axU.plot([], [], color=INP_C, lw=2.2)
    u_fill = [None]

    # ---- trial-averaged response ----
    axAvg.set_title("", color=TXT, fontsize=9.5, fontweight="bold", loc="left", pad=5)
    axAvg.set_xlim(t.min(), t.max()); axAvg.set_ylim(-11, 5)
    axAvg.set_ylabel("%ΔF/F", color=MUTE, fontsize=8.5)
    const_art += [
        axAvg.axvspan(0, DUR, color=STIMF, alpha=0.45, lw=0),
        axAvg.axhspan(REF - BANDW, REF + BANDW, color=BAND, alpha=0.7, lw=0, zorder=1),
        axAvg.axhline(REF, color=REFC, ls="--", lw=1.6, zorder=2),
    ]
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
    const_art += [axVar.axvspan(0, DUR, color=STIMF, alpha=0.45, lw=0)]
    ol_var, = axVar.plot([], [], color=OL_C, lw=3.0, zorder=7, label="open loop")
    cl_var, = axVar.plot([], [], color=CL_C, lw=3.0, zorder=8, label="closed loop")
    var_leg = axVar.legend(loc="upper right", fontsize=9, frameon=True,
                           facecolor="#ffffff", edgecolor=EDGE, labelcolor=TXT)
    var_leg.set_visible(False)

    # running evidence counter (appears once closed-loop trials accumulate)
    score = fig.text(0.976, 0.895, "", color=CL_C, fontsize=11, fontweight="bold",
                     va="top", ha="right")

    # ---- chapter-2 artists: same panels, moving reference, two conditions ----
    ff_art = []
    ff_ref, = axDF.plot([], [], color=REFC, ls="--", lw=1.8, zorder=6, visible=False)
    ff_df, = axDF.plot([], [], color=OL_C, lw=2.6, solid_capstyle="round",
                       zorder=7, visible=False)
    ff_head, = axDF.plot([], [], "o", color=TXT, ms=5, visible=False)
    ff_art += [ff_ref, ff_df, ff_head]
    for _a in (axDF.axvspan(0, F_DUR, color=STIMF, alpha=0.55, lw=0),
               axDF.axhline(0, color="#b4bccb", ls=":", lw=1.0),
               axAvg.axvspan(0, F_DUR, color=STIMF, alpha=0.45, lw=0),
               axAvg.axhline(0, color="#b4bccb", ls=":", lw=1.0),
               axU.axvspan(0, F_DUR, color=STIMF, alpha=0.55, lw=0),
               axVar.axvspan(0, F_DUR, color=STIMF, alpha=0.45, lw=0)):
        _a.set_visible(False); ff_art.append(_a)
    ff_avg_ref, = axAvg.plot([], [], color=REFC, ls="--", lw=1.8, zorder=7,
                             label="sine reference", visible=False)
    ff_avg = {c: axAvg.plot([], [], color=FF_COL[c], lw=3.2, zorder=8,
                            label=FF_NAME[c], visible=False)[0] for c in FF_SEQ}
    ff_var = {c: axVar.plot([], [], color=FF_COL[c], lw=2.6, zorder=7,
                            label=FF_NAME[c], visible=False)[0] for c in FF_SEQ}
    ff_art += [ff_avg_ref] + list(ff_avg.values()) + list(ff_var.values())
    ff_seen_done = []
    ff_state = {"in": False}

    def enter_ff():
        """one-time switch of the shared panels from constant to moving reference"""
        if ff_state["in"]:
            return
        ff_state["in"] = True
        for a in const_art:
            a.set_visible(False)
        for a in (ol_mean, cl_mean, ol_var, cl_var):
            a.set_visible(False)
        avg_leg.set_visible(False); var_leg.set_visible(False)
        for a in ff_art:
            a.set_visible(True)
        for ax in (axDF, axU, axAvg, axVar):
            ax.set_xlim(F_t.min(), F_t.max())
        lo = float(np.nanpercentile(F_bs, 0.5)); hi = float(np.nanpercentile(F_bs, 99.5))
        pad = 0.18 * (hi - lo)
        axDF.set_ylim(lo - pad, hi + pad); axAvg.set_ylim(lo - pad, hi + pad)
        axU.set_ylim(0, float(np.nanpercentile(F_INP, 99.5)) * 1.15 + 1e-6)
        axVar.set_ylim(0, 1.15 * max(float(np.nanmax(np.nanvar(F_dF[ff_idx[c]], axis=0)))
                                     for c in FF_SEQ))
        anat_im.set_data(F_anat)
        axim.set_data(F_act_rgba(ff_hero[FF_SEQ[0]], 0))
        roi_sq.set_data([F_roi[0]], [F_roi[1]])
        roi_glow.center = (float(F_roi[0]), float(F_roi[1]))
        cb.update_normal(ScalarMappable(norm=F_dnorm, cmap=dcmap))
        cb.set_ticks([-F_clim, 0, F_clim])
        cb.ax.set_yticklabels([f"-{F_clim:.0f}", "0", f"+{F_clim:.0f}"])
        cb.ax.tick_params(colors=MUTE, labelsize=6, length=2)
        cb.set_label("ΔF/F (%)", color=MUTE, fontsize=7, labelpad=2)
        narr_tag.set_text(f"{F_mouse} · {F_date}")
        axDF.set_title("ACTIVITY IN THE CONTROLLED REGION  —  tracking a moving target",
                       color=TXT, fontsize=9, fontweight="bold", loc="left", pad=4)
        axAvg.legend(handles=[ff_avg_ref] + [ff_avg[c] for c in FF_SEQ],
                     loc="lower right", fontsize=8.5, frameon=True,
                     facecolor="#ffffff", edgecolor=EDGE, labelcolor=TXT)
        axVar.legend(handles=[ff_var[c] for c in FF_SEQ], loc="upper right",
                     fontsize=8.5, frameon=True, facecolor="#ffffff",
                     edgecolor=EDGE, labelcolor=TXT)

    # ======================= closing SLIDE: the paper figure ==================
    # The verdict is a standalone, paper-styled slide over the whole dataset —
    # the video does NOT return to the single-trial template. Panels mirror
    # Fig. 3: across-trial variance, OL-vs-CL tracking RMSE, and the RMSE ratio
    # split by regime within the trial (settling vs steady state, Fig. 3J).
    INK = TXT

    # per-artist base alpha, so a group can be faded in without losing the
    # translucency the fills were drawn with
    _a0 = {}

    def reg(arts):
        for a_ in arts:
            _a0.setdefault(a_, 1.0 if a_.get_alpha() is None else a_.get_alpha())
        return arts

    def ax_arts(ax):
        """every artist of an axes that participates in the reveal fade"""
        return reg(list(ax.lines) + list(ax.collections) + list(ax.texts)
                   + list(ax.patches) + list(ax.images) + list(ax.get_ygridlines())
                   + list(ax.get_xticklabels()) + list(ax.get_yticklabels()))

    def fade(arts, f):
        for a_ in arts:
            a_.set_alpha(_a0[a_] * f)
            a_.set_visible(f > 0.01)

    def dot_size(nn):
        """marker area ∝ trials contributed by that session"""
        nn = np.asarray(nn, float)
        return 22 + 110 * (nn - nn.min()) / max(float(np.ptp(nn)), 1e-9)

    def paper_ax(ax, ny=3):
        """deck aesthetic: no panel fill, no spines, one recessive horizontal grid"""
        ax.patch.set_alpha(0.0)
        for sp in ax.spines.values():
            sp.set_visible(False)
        ax.set_axisbelow(True)
        ax.xaxis.grid(False)
        ax.yaxis.grid(True, color=HAIR, lw=0.9, alpha=0.9, zorder=0)
        ax.yaxis.set_major_locator(mticker.MaxNLocator(ny))
        ax.tick_params(colors=MUTE, labelsize=9.5, length=0, pad=5)
        for lab in ax.get_xticklabels():
            lab.set_color(TXT); lab.set_fontsize(10.5)

    def strip(ax, cols, xs_, colors, med, xlabels, ratio=False):
        """paired per-session strip: links, dots sized by trial count, ink median"""
        sz = dot_size(xs["nOL"] + xs["nCL"])
        for k in range(NSESS):
            ax.plot(cols, [v[k] for v in xs_], color=LINK, lw=1.0, alpha=0.5, zorder=2)
        for i, (v, c) in enumerate(zip(xs_, colors)):
            ax.scatter(np.full(NSESS, cols[i]), v, s=sz, color=c, edgecolors=BG,
                       linewidths=1.4, zorder=3)
        ax.plot(cols, med, color=INK, lw=2.8, solid_capstyle="round", zorder=4)
        if ratio:
            ax.axhline(1.0, color=MUTE, ls=(0, (4, 3)), lw=1.1, zorder=1)
        ax.set_xlim(cols[0] - 0.55, cols[-1] + 0.55)
        ax.set_xticks(cols); ax.set_xticklabels(xlabels)

    # three columns: the wide time course, then the two control comparisons.
    # (The paired OL-vs-CL RMSE panel was cut — its number lives in the footer.)
    CX = (0.200, 0.545, 0.855)
    axQ1 = fig.add_axes([0.080, 0.150, 0.240, 0.435])
    axQ1b = fig.add_axes([0.470, 0.150, 0.150, 0.435])
    axQ3 = fig.add_axes([0.7875, 0.150, 0.135, 0.435])
    slide_axes = [axQ1, axQ1b, axQ3]

    # --- Q1: across-trial variance vs time (mean +/- SEM over sessions) ------
    vo_m = np.nanmean(xs_v["ol"], axis=0); vc_m = np.nanmean(xs_v["cl"], axis=0)
    vo_e = np.nanstd(xs_v["ol"], axis=0) / np.sqrt(NSESS)
    vc_e = np.nanstd(xs_v["cl"], axis=0) / np.sqrt(NSESS)
    axQ1.axvspan(0, DUR, color="#ffffff", alpha=0.55, lw=0, zorder=0)
    axQ1.fill_between(tx, vo_m - vo_e, vo_m + vo_e, color=OL_C, alpha=0.15, lw=0)
    axQ1.fill_between(tx, vc_m - vc_e, vc_m + vc_e, color=CL_C, alpha=0.15, lw=0)
    axQ1.plot(tx, vo_m, color=OL_C, lw=2.2, solid_capstyle="round")
    axQ1.plot(tx, vc_m, color=CL_C, lw=2.2, solid_capstyle="round")
    axQ1.set_xlim(tx.min(), tx.max()); axQ1.set_ylim(0, 10.6)
    axQ1.set_xticks([0, DUR]); axQ1.set_xticklabels(["0", f"{DUR:g} s"])
    # direct labels instead of a legend box (identity is never colour-alone)
    axQ1.text(1.5, 10.1, "laser on", ha="center", va="top", fontsize=9.5, color=MUTE)
    axQ1.text(1.5, np.interp(1.5, tx, vo_m + vo_e) + 0.35, "open loop", ha="center",
              va="bottom", fontsize=10.5, fontweight="bold", color=OL_C)
    axQ1.text(1.5, np.interp(1.5, tx, vc_m - vc_e) - 0.35, "closed loop", ha="center",
              va="top", fontsize=10.5, fontweight="bold", color=CL_C)

    # --- Q1b: variance ratio (OL/CL) by window -- the specificity control -----
    # Feedback should only suppress variability while the loop is closed: the
    # ratio must sit at 1 before and after stimulation, and rise only during.
    win_r = [X_RATIO["pre"], X_RATIO["stim"], X_RATIO["post"]]
    med_w = [float(np.nanmedian(w)) for w in win_r]
    strip(axQ1b, [0, 1, 2], win_r, (MUTE, CL_C, MUTE), med_w,
          ["before", "during", "after"], ratio=True)

    # --- Q3: RMSE ratio (OL/CL) by regime within the trial (Fig. 3J) ---------
    rat_e = xs["rmse_ol_e"] / xs["rmse_cl_e"]      # 0-1 s, settling
    rat_s = xs["rmse_ol_s"] / xs["rmse_cl_s"]      # 1-3 s, steady state
    strip(axQ3, [0, 1], [rat_e, rat_s], (MUTE, CL_C),
          [np.median(rat_e), np.median(rat_s)],
          ["0–1 s\nsettling", "1–3 s\nsteady"], ratio=True)

    for ax in slide_axes:
        paper_ax(ax); ax.set_visible(False)

    # ---- typographic header row: the number leads, the plot supports --------
    X_VAR_DROP = 100 * np.median(1 - xs["var_cl"] / xs["var_ol"])
    _pexp = int(np.floor(np.log10(X_PR)))
    P_STR = f"p = {X_PR / 10 ** _pexp:.1f}×10{_sup(_pexp)}"

    from matplotlib.colors import LinearSegmentedColormap
    OLCL = LinearSegmentedColormap.from_list("olcl", [OL_C, CL_C])
    _ramp = np.linspace(0, 1, 256)[None, :]

    def grad_rule(cx, y, w=0.062, h=0.0055):
        """hairline open-loop→closed-loop gradient, tying a number to its plot"""
        a = fig.add_axes([cx - w / 2, y, w, h]); a.set_axis_off()
        a.imshow(_ramp, aspect="auto", cmap=OLCL, interpolation="bilinear")
        return a

    slide_t = fig.text(0.5, 0.884, "Feedback controls cortical activity", ha="center",
                       va="center", fontsize=31, fontweight="bold", color=INK,
                       zorder=40, visible=False)
    ax_trule = grad_rule(0.5, 0.836, w=0.085, h=0.0065)
    slide_axes_extra = [ax_trule]
    slide_s = fig.text(0.5, 0.050, f"{NSESS} sessions   ·   {NMICE} mice   ·   "
                       f"{X_NTRIALS:,} trials   ·   tracking RMSE −{X_RMSE_DROP:.0f}% "
                       f"in {X_NBETTER}/{NSESS} sessions ({P_STR})   ·   "
                       f"dot size = trials per session",
                       ha="center", va="center", fontsize=10.5, color=MUTE,
                       zorder=40, visible=False)
    slide_head = reg([slide_t, slide_s]) + ax_arts(ax_trule)

    # (hero number, hero size, hero colour, two-line caption) per column
    COLS = [
        (f"−{X_VAR_DROP:.0f}%", 34, INK,
         "trial-to-trial variability\nwhile the loop is closed"),
        (f"{med_w[0]:.1f}× · {med_w[2]:.1f}×", 27, MUTE,
         "before and after —\nvariability unchanged"),
        (f"{np.median(rat_s):.1f}×", 34, INK,
         "error falls further once\nthe transient has settled"),
    ]
    slide_groups, slide_h = [], []
    for cx, (hero, hsz, hcol, cap), pax in zip(CX, COLS, slide_axes):
        th = fig.text(cx, 0.750, hero, ha="center", va="center", fontsize=hsz,
                      fontweight="bold", color=hcol, zorder=40, visible=False)
        tc = fig.text(cx, 0.648, cap, ha="center", va="center", fontsize=11,
                      color=MUTE, linespacing=1.55, zorder=40, visible=False)
        gax = grad_rule(cx, 0.706)
        slide_h += [th, tc]
        slide_axes_extra.append(gax)
        slide_groups.append(reg([th, tc]) + ax_arts(gax) + ax_arts(pax))

    slide_cap = fig.text(0.5, -1, "", visible=False)   # retired: numbers carry it
    slide_texts = [slide_t, slide_s] + slide_h
    slide_all_axes = slide_axes + slide_axes_extra
    for _a in slide_all_axes:
        _a.set_visible(False)
    for _g in [slide_head] + slide_groups:      # start fully faded out
        fade(_g, 0.0)

    # ---- act card overlay ----
    card_bg = plt.Rectangle((0, 0), 1, 1, transform=fig.transFigure, facecolor=BG,
                            edgecolor="none", zorder=50, visible=False)
    fig.add_artist(card_bg)
    card_t = fig.text(0.5, 0.55, "", ha="center", va="center", fontsize=38,
                      fontweight="bold", color=TXT, zorder=51, visible=False,
                      linespacing=1.35)
    card_s = fig.text(0.5, 0.38, "", ha="center", va="center", fontsize=17,
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
    # one narration set per real-time trial (played at true 1× speed)
    OL_HERO_BEATS = [
        [(0.00, "OPEN LOOP, in real time: the laser plays a fixed command, computed in advance."),
         (0.30, "Nothing is measured back — the loop is broken."),
         (0.58, "So spontaneous fluctuations go uncorrected, and the response drifts off target.")],
        [(0.00, "A second trial — the identical command is delivered again."),
         (0.35, "But the brain starts from a different state, so it lands somewhere else."),
         (0.65, "The system has no way to notice, and no way to correct.")],
        [(0.00, "A third trial. Same command, another outcome."),
         (0.35, "The error simply persists for the full three seconds."),
         (0.65, "This scatter across trials is what feedback should remove.")],
    ]
    CL_HERO_BEATS = [
        [(0.00, "CLOSED LOOP, in real time: the measured ΔF/F is fed back and compared to the target."),
         (0.30, "The PI controller turns that error into a correction — every single frame."),
         (0.58, "Watch the laser command: it is no longer flat. It is being computed live.")],
        [(0.00, "A second closed-loop trial, starting from a different brain state."),
         (0.35, "The controller pushes activity into the band and holds it there."),
         (0.65, "Proportional acts on the error now; integral removes any lasting offset.")],
        [(0.00, "A third trial — and it lands in the same place as the last two."),
         (0.35, "The command differs, because the disturbance differed."),
         (0.65, "Same outcome from different starting points: that is disturbance rejection.")],
    ]

    FF_BEATS = {
        2: [(0.00, "A harder problem: the target is no longer a constant — it moves."),
            (0.22, "OPEN LOOP first — a command computed in advance and played back blind."),
            (0.50, "It has roughly the right shape, but nothing corrects its phase or size."),
            (0.76, "So the response slides away from the reference and stays there.")],
        0: [(0.00, "CLOSED LOOP WITH PREVIEW: this reference is known ahead of time."),
            (0.22, "A feedforward branch sends it straight to the laser — the green path."),
            (0.50, "Feedback then cleans up whatever that feedforward command got wrong."),
            (0.76, "Acting before the error appears is what buys back the 47 ms lag.")],
    }
    FF_MONT_TXT = {
        2: "Every open-loop trial replays the same command — and tracks the sine differently.",
        0: "With preview and feedback together, the trials collapse onto the reference.",
    }

    def beat(beats, frac):
        msg = beats[0][1]
        for f0, m in beats:
            if frac >= f0:
                msg = m
        return msg

    # ============================== per-frame ================================
    def draw_frame(fnum):
        s = sched[fnum]; ph = s["ph"]
        shown = [x for x in sched[:fnum + 1]
                 if "tr" in x and (x["ph"] == "ff") == (ph == "ff")]
        seen = list(dict.fromkeys(x["tr"] for x in shown))

        # ---------- act cards ----------
        if ph == "intro" and s["k"] < 40:
            a = 1.0 if s["k"] < 28 else 1.0 - (s["k"] - 28) / 12
            show_card("Targeted closed-loop optogenetic\ncontrol of cortical dynamics", "", a)
        elif ph in ("ol", "cl") and fnum - act_start[ph] < 26:
            k = fnum - act_start[ph]
            a = 1.0 if k < 15 else 1.0 - (k - 15) / 11
            if ph == "ol":
                show_card("OPEN LOOP", "a fixed light command — no feedback", a)
            else:
                show_card("CLOSED LOOP", "measure the error, correct it, every frame", a)
        elif ph == "ff" and fnum - act_start["ff"] < 30:
            k = fnum - act_start["ff"]
            a = 1.0 if k < 18 else 1.0 - (k - 18) / 12
            show_card("A MOVING TARGET", "the reference is a 1 Hz sine — now the "
                      "controller must track, not just hold", a)
        elif ph == "outro":
            hide_card()          # the verdict IS the slide; no card over it
        else:
            hide_card()

        # ---------- act label + narration ----------
        if ph == "intro":
            frac = s["k"] / max(INTRO - 1, 1)
            act_label.set_text("THE SETUP"); act_label.set_color(MUTE)
            narr.set_text(beat(INTRO_BEATS, frac)); narr.set_color(TXT)
            loop.draw(closed=True, phase=frac * 2.0, active=frac > 0.5)
            axim.set_data(act_rgba(heroes_ol[0], int(frac * PRE)))
            laser_pip.set_text("")
            onoff.set_text("")
            return

        if ph == "outro":
            # hand over completely to the paper-style summary slide: every
            # single-trial element is hidden, nothing returns to the template
            for _ax in (axBrain, axCB, axLoop, axDF, axU, axAvg, axVar):
                _ax.set_visible(False)
            for _tx in (narr, narr_tag, score, act_label):
                _tx.set_visible(False)
            for _ax in slide_all_axes:
                _ax.set_visible(True)
            # build the slide column by column rather than dropping it whole:
            # title first, then each claim ~0.45 s apart, each over ~0.3 s
            k = s["k"]
            fade(slide_head, float(np.clip(k / 9.0, 0, 1)))
            for gi, grp in enumerate(slide_groups):
                fade(grp, float(np.clip((k - (14 + 13 * gi)) / 9.0, 0, 1)))
            return

        # ---------- chapter 2: moving reference ----------
        if ph == "ff":
            enter_ff()
            tr, tau, c = s["tr"], s["tau"], s["mode"]
            closed = c == 0
            col = FF_COL[c]
            on = 0 <= F_t[tau] <= F_DUR
            act_label.set_text(FF_TAG[c] + ("   ·   REAL TIME" if s.get("hero") else ""))
            act_label.set_color(col)
            axim.set_data(F_act_rgba(tr, tau))
            roi_glow.set_alpha(0.5 if on else 0.0)
            laser_pip.set_text("● LASER ON" if on else ""); laser_pip.set_color(col)
            onoff.set_text("stimulation on" if on else "")
            loop.draw(closed=closed, phase=fnum / 9.0, active=on, ff=closed,
                      tag=FF_TAG[c], col=col, moving=True)

            m = tau + 1 if s.get("hero") else F_NWIN
            ff_ref.set_data(F_t[:m], F_REF[tr][:m])
            ff_df.set_data(F_t[:m], F_bs[tr][:m]); ff_df.set_color(col)
            ff_head.set_data([F_t[m - 1]], [F_bs[tr][m - 1]]); ff_head.set_color(col)
            uu = F_INP[tr][:m]
            u_line.set_data(F_t[:m], uu)
            if u_fill[0] is not None:
                u_fill[0].remove()
            u_fill[0] = axU.fill_between(F_t[:m], 0, uu, color=INP_C, alpha=0.22)

            seenf = list(dict.fromkeys(x["tr"] for x in shown))
            for i in seenf[len(ff_seen_done):]:
                axAvg.plot(F_t, smooth(F_bs[i], 7), color=FF_COL[int(F_ffc[i])],
                           lw=0.5, alpha=0.13, zorder=3)
                ff_seen_done.append(i)
            ff_avg_ref.set_data(F_t, F_REF[tr])
            for cc in FF_SEQ:
                sel = [i for i in seenf if F_ffc[i] == cc]
                if sel:
                    ff_avg[cc].set_data(F_t, smooth(np.nanmean(F_bs[sel], 0), 7))
                if len(sel) >= 2:
                    ff_var[cc].set_data(F_t, smooth(np.nanvar(F_dF[sel], axis=0), 7))
            axAvg.set_title("TRACKING A MOVING TARGET  —  trial average by condition",
                            color=TXT, fontsize=9.5, fontweight="bold", loc="left", pad=5)
            axVar.set_title("TRIAL-TO-TRIAL VARIABILITY  —  by condition", color=TXT,
                            fontsize=9.5, fontweight="bold", loc="left", pad=5)

            if s.get("hero"):
                narr.set_text(beat(FF_BEATS[c], s["j"] / max(s["nj"] - 1, 1)))
                narr.set_color(TXT)
            else:
                narr.set_text(FF_MONT_TXT[c]); narr.set_color(MUTE)

            have = {cc: [i for i in seenf if F_ffc[i] == cc] for cc in FF_SEQ}
            if all(len(have[cc]) >= 3 for cc in FF_SEQ):
                e_ol, e_ff = ff_mse(have[2]), ff_mse(have[0])
                score.set_text(f"tracking MSE   open loop {e_ol:.1f}   ·   "
                               f"+preview {e_ff:.1f}   ({100 * (1 - e_ff / e_ol):.0f}% lower)")
                score.set_color(FF_C)
            else:
                score.set_text("")
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

        loop.draw(closed=closed, phase=fnum / 9.0, active=on, moving=False)

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
            sets = CL_HERO_BEATS if closed else OL_HERO_BEATS
            narr.set_text(beat(sets[min(s.get("hi", 0), len(sets) - 1)], frac))
            narr.set_color(TXT)
            act_label.set_text(("CLOSED LOOP" if closed else "OPEN LOOP") + "   ·   REAL TIME")
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
            _ln, = axAvg.plot(t, smooth(Y[i], 7),
                              color=CL_C if LOOP[i] == "CL" else OL_C,
                              lw=0.6, alpha=0.16, zorder=3)
            trial_lines.append(i); const_art.append(_ln)
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
        pout = os.path.join(ROOT, "presentation", f"_probe_combined_{args.session}.png")
        fig.savefig(pout, dpi=dpi, facecolor=BG)
        print(f"[probe] frame {fnum}/{total} phase={sched[fnum]['ph']} -> {pout}")
        return

    print(f"[render] {total} frames ({total/args.fps:.1f}s)  {'1080p' if args.hd else '900p'}")
    outname = os.path.join(ROOT, "presentation",
                           f"controller_combined_{args.session}"
                           f"{'_hd' if args.hd else ''}.mp4")
    writer = manim.FFMpegWriter(fps=args.fps, bitrate=7000,
                                metadata=dict(title="Closed-loop control — combined cut"))
    with writer.saving(fig, outname, dpi=dpi):
        for fnum in range(total):
            draw_frame(fnum)
            writer.grab_frame(facecolor=BG)
            if fnum % 60 == 0:
                print(f"  frame {fnum}/{total}")
    print("wrote", outname, f"({os.path.getsize(outname)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
