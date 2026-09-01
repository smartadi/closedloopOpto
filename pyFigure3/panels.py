"""Figure 3 panels A-J (closed-loop vs open-loop cortical activity control).

Single-session panels (A-E) take one Session; cross-session panels (F-J) take a
list[Session]. Each function draws into a supplied matplotlib Axes so panels can
be exported individually (matching the MATLAB paper/images/figure3/*.pdf) or
composed into one montage (see figure3.make_figure3).

Math is ported verbatim from controller-analysis/{variance_mse,step_response}.m
and utils/analysisPlots_combined.m (see fig3_spec). RMSE is sample-normalised:
sqrt(mean((seg-ref)^2)).
"""
from __future__ import annotations

from typing import List

import numpy as np

from . import style
from .io import Session, time_axis_l, time_axis_wide, time_axis_input


def _kde_halfwidth(samples, npts=100):
    """KDE scaled to unit peak (like ksdensity + normalise to half-violin width)."""
    from scipy.stats import gaussian_kde

    samples = np.asarray(samples, dtype=float)
    samples = samples[np.isfinite(samples)]
    if samples.size < 2 or np.allclose(samples, samples[0]):
        y = np.array([samples.mean() if samples.size else 0.0])
        return np.array([style.VIOLIN_HALFWIDTH]), y
    kde = gaussian_kde(samples)
    ygrid = np.linspace(samples.min(), samples.max(), npts)
    f = kde(ygrid)
    f = f / f.max() * style.VIOLIN_HALFWIDTH
    return f, ygrid


def _half_violin(ax, x, samples, color, side, alpha):
    """Draw one half-violin at position x. side=-1 left (OL), +1 right (CL)."""
    f, y = _kde_halfwidth(samples)
    ax.fill_betweenx(y, x, x + side * f, color=color, alpha=alpha, edgecolor="none")
    ax.plot(x + side * 0.1, np.mean(samples), "*", color=color, ms=3, mew=0.5)


def _stim_patch(ax, dur, color=style.STIM_PATCH, alpha=0.5):
    yl = ax.get_ylim()
    ax.axvspan(0, dur, color=color, alpha=alpha, lw=0, zorder=-10)
    ax.set_ylim(yl)


def _stars(p):
    if p < 0.001:
        return "***"
    if p < 0.01:
        return "**"
    if p < 0.05:
        return "*"
    return ""


# ===========================================================================
# Single-session panels A-E  (representative session)
# ===========================================================================
def panel_A(ax, sess: Session, trial_ol: int = 0, trial_cl: int = 0):
    """Single-trial OL/CL dF/F response + input signal below."""
    Tp = time_axis_wide()
    m = (Tp >= -3) & (Tp <= sess.dur + 3)
    if sess.n_ol:
        ax.plot(Tp[m], sess.pncDfk[trial_ol % sess.n_ol, m], color=style.COL_OL,
                lw=1.0, label="open-loop")
    if sess.n_cl:
        ax.plot(Tp[m], sess.pwcDfk[trial_cl % sess.n_cl, m], color=style.COL_CL,
                lw=1.0, label="closed-loop")
    Tin = time_axis_input()
    base = -9.0  # draw input traces near the bottom of the dF/F axis
    if sess.n_ol:
        ax.plot(Tin, base + sess.ncInp[trial_ol % sess.n_ol], color=style.COL_INP_OL,
                lw=style.LW_INP)
    ax.axhline(sess.ref, ls="--", color="k", lw=style.LW_REF)
    ax.set_xlim(-3, sess.dur + 3)
    ax.set_ylim(-10, 10)
    _stim_patch(ax, sess.dur)
    ax.set_xlabel("Time (s)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_ylabel(r"$\Delta F/F$ (%)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("A  single trial", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")
    ax.legend(frameon=False, fontsize=5)


def _trial_avg(ax, sess: Session, title, letter):
    Tp = time_axis_wide()
    for mat, col, lab in ((sess.pncDfk, style.COL_OL, "OL"), (sess.pwcDfk, style.COL_CL, "CL")):
        if mat is None or mat.shape[0] == 0:
            continue
        mu = mat.mean(0)
        sd = mat.std(0, ddof=1)
        ax.fill_between(Tp, mu - sd, mu + sd, color=col, alpha=style.FA, lw=0)
        ax.plot(Tp, mu, color=col, lw=style.LW_MEAN, label=lab)
    ax.axhline(sess.ref, ls="--", color="k", lw=style.LW_REF)
    ax.set_xlim(-3, sess.dur + 3)
    _stim_patch(ax, sess.dur)
    ax.set_xlabel("Time (s)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_ylabel(r"$\Delta F/F$ (%)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title(f"{letter}  {title}", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")
    ax.legend(frameon=False, fontsize=5)


def panel_B(ax, sess: Session):
    """Trial-averaged dF/F +/- std, OL vs CL."""
    _trial_avg(ax, sess, "trial-avg " + r"$\Delta F/F$", "B")


def panel_C(ax, sess: Session):
    """Trial-averaged optogenetic input +/- std (x3 display scale)."""
    Tin = time_axis_input()
    s = style.INPUT_DISPLAY_SCALE
    for mat, col, lab in ((sess.ncInp, style.COL_INP_OL, "OL input"),
                          (sess.wcInp, style.COL_INP_CL, "CL input")):
        if mat is None or mat.shape[0] == 0:
            continue
        mu = mat.mean(0) * s
        sd = mat.std(0, ddof=1) * s
        ax.fill_between(Tin, mu - sd, mu + sd, color=col, alpha=style.FA, lw=0)
        ax.plot(Tin, mu, color=col, lw=style.LW_MEAN, label=lab)
    ax.set_xlim(0, sess.dur)
    ax.set_xlabel("Time (s)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_ylabel("input (a.u. x3)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("C  trial-avg input", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")


def panel_D(ax, sess: Session):
    """Cross-trial variance of dF/F vs time, OL vs CL (representative session)."""
    Tp = time_axis_wide()
    ax.plot(Tp, sess.var_trace_wide(cl=False), color=style.COL_OL, lw=style.LW_MEAN, label="OL")
    ax.plot(Tp, sess.var_trace_wide(cl=True), color=style.COL_CL, lw=style.LW_MEAN, label="CL")
    ax.set_xlim(-3, sess.dur + 3)
    ax.set_ylim(-2, 12)
    _stim_patch(ax, sess.dur)
    ax.set_xlabel("Time (s)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_ylabel(r"variance (%$\Delta F/F$)$^2$", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("D  cross-trial variance", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")
    ax.legend(frameon=False, fontsize=5)


def panel_E(ax, sess: Session):
    """Per-trial RMSE half-violin (OL left, CL right), representative session."""
    _half_violin(ax, 1.0, sess.rmse_full(cl=False), style.COL_OL, side=-1, alpha=0.5)
    _half_violin(ax, 1.0, sess.rmse_full(cl=True), style.COL_CL, side=+1, alpha=0.5)
    ax.set_xlim(0.4, 1.6)
    ax.set_xticks([])
    ax.set_ylabel(r"Trial RMSE (%$\Delta F/F$)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("E  per-trial RMSE", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")


# ===========================================================================
# Cross-session panels F-J
# ===========================================================================
def _pool_var(sessions: List[Session]):
    """Session x 316 cross-trial variance matrices (OL, CL) on the tp axis."""
    Mnc = np.vstack([s.var_trace_l(cl=False) for s in sessions])
    Mwc = np.vstack([s.var_trace_l(cl=True) for s in sessions])
    return Mnc, Mwc


def panel_F(ax, sessions: List[Session]):
    """Cross-session average of cross-trial variance vs time, OL vs CL."""
    tp = time_axis_l()
    Mnc, Mwc = _pool_var(sessions)
    ax.plot(tp, Mnc.mean(0), color=style.COL_OL, lw=style.LW_MEAN, label="OL")
    ax.plot(tp, Mwc.mean(0), color=style.COL_CL, lw=style.LW_MEAN, label="CL")
    ax.axvline(0, lw=0.75, color="k")
    ax.axvline(style.DUR, lw=0.75, color="k")
    ax.set_xlim(-3, style.DUR + 3)
    ax.set_ylim(-2, 12)
    _stim_patch(ax, style.DUR)
    ax.set_xlabel("Time (s)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_ylabel(r"variance (%$\Delta F/F$)$^2$", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("F  avg session variance", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")
    ax.legend(frameon=False, fontsize=5)


def panel_G(ax, sessions: List[Session]):
    """Per-trial RMSE violins pooled across sessions (one pair per session)."""
    for k, s in enumerate(sessions, start=1):
        _half_violin(ax, float(k), s.rmse_full(cl=False), style.COL_OL, side=-1, alpha=0.5)
        _half_violin(ax, float(k), s.rmse_full(cl=True), style.COL_CL, side=+1, alpha=0.5)
    ax.set_xlim(0.5, len(sessions) + 0.5)
    ax.set_xlabel("Session", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_ylabel(r"Trial RMSE (%$\Delta F/F$)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("G  RMSE across sessions", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")


def panel_H(ax, sessions: List[Session]):
    """All-session mean tracking-error (RMSE) vs time within the [0,3] s window."""
    onset = style.PNCDFK_ONSET
    n = style.DUR * style.FS + 1                 # 106 samples, 0..3 s
    t_h = np.arange(0, n) / style.FS
    per_session = []
    for s in sessions:
        seg = s.pncDfk[:, onset:onset + n]       # OL error trace
        rms = np.sqrt(np.mean((seg - s.ref) ** 2, axis=0))
        per_session.append(rms)
        ax.plot(t_h, rms, color=style.COL_OL, lw=style.LW_TRIAL, alpha=style.FA)
    bold = np.vstack(per_session).mean(0)
    ax.plot(t_h, bold, color=style.COL_OL, lw=style.LW_MEAN, label="OL mean")
    # CL bold mean
    per_cl = []
    for s in sessions:
        seg = s.pwcDfk[:, onset:onset + n]
        per_cl.append(np.sqrt(np.mean((seg - s.ref) ** 2, axis=0)))
    ax.plot(t_h, np.vstack(per_cl).mean(0), color=style.COL_CL, lw=style.LW_MEAN, label="CL mean")
    ax.set_xlim(-0.5, style.DUR + 0.5)
    ax.set_xlabel("Time (s)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_ylabel(r"tracking RMSE (%$\Delta F/F$)", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("H  mean tracking error", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")
    ax.legend(frameon=False, fontsize=5)


def panel_I(ax, sessions: List[Session]):
    """OL/CL cross-trial variance ratio by window: pre / 0-1 s / 1-3 s / post."""
    tp = time_axis_l()
    Mnc, Mwc = _pool_var(sessions)
    idx = {
        "Pre":   (tp >= -3) & (tp < 0),
        "0-1 s": (tp >= 0) & (tp <= 1),
        "1-3 s": (tp > 1) & (tp <= style.DUR),
        "Post":  (tp > style.DUR) & (tp <= style.DUR + 3),
    }
    labels = list(idx)
    ncw = np.column_stack([Mnc[:, idx[w]].mean(1) for w in labels])   # sess x 4
    wcw = np.column_stack([Mwc[:, idx[w]].mean(1) for w in labels])
    ratio = ncw / wcw
    x = np.arange(1, 5)
    for r in ratio:
        ax.plot(x, r, "-o", color=style.COL_GRAY, ms=3, lw=0.6, mfc=style.COL_GRAY)
    ax.plot(x, ratio.mean(0), "k-o", lw=style.LW_MEAN, ms=5, mfc="k", label="Mean")
    ax.axhline(1, ls="--", color="k", lw=0.75)
    # signed-rank stars: OL vs CL variance per window
    from scipy.stats import wilcoxon

    yl = ax.get_ylim()
    ystar = yl[1] + 0.04 * (yl[1] - yl[0])
    for i, w in enumerate(labels, start=1):
        try:
            p = wilcoxon(ncw[:, i - 1], wcw[:, i - 1]).pvalue
        except ValueError:
            p = 1.0
        s = _stars(p)
        if s:
            ax.text(i, ystar, s, ha="center", va="bottom", fontsize=6, fontweight="bold")
    ax.set_ylim(yl[0], yl[1] + 0.15 * (yl[1] - yl[0]))
    ax.set_xlim(0.5, 4.5)
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_ylabel("OL/CL variance ratio", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("I  variance ratio by window", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")
    ax.legend(frameon=False, fontsize=5)


def panel_J(ax, sessions: List[Session]):
    """Disturbance rejection: OL/CL RMSE ratio, settling (0-1 s) vs steady (1-3 s)."""
    settling, steady = [], []
    for s in sessions:
        settling.append(np.mean(s.rmse_early(cl=False)) / np.mean(s.rmse_early(cl=True)))
        steady.append(np.mean(s.rmse_late(cl=False)) / np.mean(s.rmse_late(cl=True)))
    ratio = np.column_stack([settling, steady])
    x = np.arange(1, 3)
    for r in ratio:
        ax.plot(x, r, "-o", color=style.COL_GRAY, ms=3, lw=0.6, mfc=style.COL_GRAY)
    ax.plot(x, ratio.mean(0), "k-o", lw=style.LW_MEAN, ms=5, mfc="k", label="Mean")
    ax.axhline(1, ls="--", color="k", lw=0.75)
    ax.set_xlim(0.5, 2.5)
    ax.set_xticks(x)
    ax.set_xticklabels(["0-1 s\n(settling)", "1-3 s\n(steady)"])
    ax.set_ylabel("OL/CL RMSE ratio", fontsize=style.FS_LABEL, fontweight=style.FW)
    ax.set_title("J  disturbance rejection", fontsize=style.FS_LABEL, fontweight=style.FW, loc="left")
    ax.legend(frameon=False, fontsize=5)
