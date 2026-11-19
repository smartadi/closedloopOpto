"""JN Figure 4 panels C, D and E and the two Figure 4 supplementary figures, in the JN paper style
(paper/FIGURE_RULEBOOK.md: Arial; titles and axis labels 7 pt bold, ticks and annotations 6 pt,
panel letters 8 pt bold; axes 0.5 pt, means 1.0 pt, reference 0.75 pt, error bars 0.5 pt;
OL red, CL blue). Hub #92. Display only: every statistic is read from the stats_v2 outputs (run
run_all.py --corrected, f4d_windows.py, f4d_bands.py, sensitivity.py, sens_trials.py,
state_spectra_tests.py, state_spectra_cluster.py and error_bands.py first); the quartile tile means,
residual spectra and example trials are recomputed with the same rules as f4_row2_quartiles.m,
sensitivity.py and sens_trials.py.

Method approved by Aditya 2026-11-16: "approve" (the plotting rules posted in Hub control on
2026-11-14 and again on 2026-11-16). Equations and rules: brain_paper RESEARCH.md, L-2026-11-16-a.

Figure 4B  unique R^2 of initial deviation, motion and absolute 1-4 Hz, one model (f4_error_decomp.m
           'abs' mode, read from its .mat; approved by Aditya 2026-11-18, RESEARCH L-2026-11-18-a).
Figure 4C  quartile tiles for initial deviation, motion and absolute 1-4 Hz (session-level display of
           f4_row2_quartiles.m; stars from tests.csv).
Figure 4D  CL/OL residual power (sensitivity_curve.csv), as sensitivity_cert.panel.
Figure 4E  Q4/Q1 power by state, locked window, curves only. Back as 4E at Aditya's request
           2026-11-18 ("bring back q4/q1 it made sense", L-2026-11-18-d). The CL vs OL cluster test
           across frequency (state_spectra_clusters.csv; approved 2026-11-18, L-2026-11-18-b; no
           cluster significant) is printed, not drawn: bars dropped 2026-11-19 ("Drop the bars",
           L-2026-11-19-a).
Layout 2026-11-19 (L-2026-11-19-b, display only): JN rows are A+B, D+C+E, F+G+H, so D, C and E are
           4.5, 7.7 and 4.6 cm wide with one height and axes box (ROW2_*); B uses the A/C state names;
           E shows motion before absolute 1-4 Hz, as C; D names its curves on the plot.
Supp error bands  the 4C error split by frequency (< 1, 1-4, > 4 Hz), stacked per state quartile, OL and
                  CL (error_bands.py, approved 2026-11-18, L-2026-11-18-c; 4E for a while that day), with
                  the state over [-2,+3) s (f4S_error_bands) and laser off (f4S_error_bands_laseroff).
Supp states       A relative 1-4 Hz quartile tile, B state-window check, C band grid,
                  D Q4/Q1 spectra (laser off; relative power).
Supp sensitivity  A residual spectra, B 1 Hz bands with the pre-stimulus null, C band ratios per
                  session, D example trials, E variance budget and costs.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/fig4_paper_panels.py
OUT  paper/images/figure4/paper_py/*.pdf (vector) and *.png (review)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import matplotlib  # noqa: E402

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import matplotlib.ticker  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from matplotlib.lines import Line2D  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402

DATA = loader.ROOT / "data" / "stats_v2" / "corrected"
FIG = loader.ROOT / "paper" / "images" / "figure4" / "paper_py"
CM = 1 / 2.54
W_DOUBLE = 17.6

OL, CL = "#ff0000", "#0066d9"            # paperStyle.m col_ol [1 0 0], col_cl [0 0.40 0.85]
STATE_COL = {"init_dev": "#3366bf", "motion": "#bf661a", "rel_delta": "#598c4d", "abs_delta": "#8c4099"}
STATE_LAB = {"init_dev": "Initial deviation", "motion": "Motion", "rel_delta": "Rel 1–4 Hz",
             "abs_delta": "Abs 1–4 Hz"}
CURVE_KEY = {"motion": "motion", "abs_delta": "abs14", "rel_delta": "rel14"}
STATE_LAB_2 = {"init_dev": "Initial\ndeviation", "motion": "Motion", "abs_delta": "Abs\n1–4 Hz"}  # 4B, two lines
# Row 2 of the JN figure (D, C, E side by side, 2026-11-19): one figure height and one axes box for all
# three, so their axes and x labels line up when the panels are placed with their tops on one line.
ROW2_H, ROW2_Y, ROW2_AH = 4.45, 0.55, 3.2   # cm: figure height, axes top, axes height


def xlabel_cm(fig, x_cm, s):
    """The x label of a row-2 panel, at the same height in D, C and E."""
    W, H = fig.get_size_inches() / CM
    fig.text(x_cm / W, 1 - (ROW2_Y + ROW2_AH + 0.4) / H, s, ha="center", va="top", fontsize=7,
             fontweight="bold")
LOCKED, LASEROFF = "locked [-2,+3) s", "laser off [-5,0) s"
BANDS = {"0.5-1 Hz": (0.5, 1.0), "1-3 Hz": (1.0, 3.0), "3-6 Hz": (3.0, 6.0)}

# MATLAB f4_row2_quartiles.m quartile means, Q1..Q4 (RESEARCH L-2026-11-14-a), for the check in main()
MATLAB_Q = {"motion": ([0.16, 0.38, 0.39, 0.74], [-0.30, -0.42, -0.44, -0.50]),
            "abs_delta": ([0.11, 0.27, 0.59, 0.67], [-0.70, -0.65, -0.36, -0.05])}


def style():
    plt.rcParams.update({
        "font.family": "Arial", "font.size": 6, "font.weight": "normal",
        "axes.labelsize": 7, "axes.labelweight": "bold", "axes.titlesize": 7, "axes.titleweight": "bold",
        "axes.titlepad": 3, "axes.labelpad": 2,
        "xtick.labelsize": 6, "ytick.labelsize": 6, "legend.fontsize": 6, "legend.frameon": False,
        "axes.linewidth": 0.5, "xtick.major.width": 0.5, "ytick.major.width": 0.5,
        "xtick.minor.width": 0.4, "ytick.minor.width": 0.4,
        "xtick.major.size": 2, "ytick.major.size": 2, "xtick.minor.size": 1, "ytick.minor.size": 1,
        "xtick.major.pad": 1.5, "ytick.major.pad": 1.5,
        "xtick.direction": "out", "ytick.direction": "out",
        "axes.spines.top": False, "axes.spines.right": False, "lines.linewidth": 1.0,
        "lines.markersize": 2.5, "errorbar.capsize": 0, "pdf.fonttype": 42, "svg.fonttype": "none",
        "savefig.dpi": 300, "figure.facecolor": "white"})


def axes_cm(fig, x, y, w, h):
    """Axes at x, y (cm from the top-left corner of the figure), w x h cm."""
    W, H = fig.get_size_inches() / CM
    return fig.add_axes([x / W, 1 - (y + h) / H, w / W, h / H])


def letter(fig, x, y, s):
    W, H = fig.get_size_inches() / CM
    fig.text(x / W, 1 - y / H, s, fontsize=8, fontweight="bold", ha="left", va="top")


def stars(p):
    return "***" if p < 0.001 else "**" if p < 0.01 else "*" if p < 0.05 else "n.s."


def save(fig, name):
    FIG.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIG / f"{name}.pdf")
    fig.savefig(FIG / f"{name}.png", dpi=300)
    plt.close(fig)
    print(f"wrote {FIG / name}.pdf")


def log_freq_axis(a, lo=0.5, hi=8.0, ticks=(0.5, 1, 2, 4, 8)):
    a.set_xscale("log")
    a.set_xlim(lo, hi)
    a.set_xticks(ticks)
    a.set_xticklabels([f"{t:g}" for t in ticks])
    a.minorticks_off()


# ------------------------------------------------------------------------------ quartile tile
def quartile_means(tr, state):
    """Session-level quartile display of f4_row2_quartiles.m (RESEARCH L-2026-11-16-a): per session,
    z = (y - mean) / SD (ddof 1), y = trial RMSE to target over 1-3 s, over the session's OL and CL
    trials together; quartile edges = 25/50/75% quantiles of the session's combined state (MATLAB
    quantile = hazen); quartile of a trial = number of edges <= its state; OL and CL mean z per
    quartile; then mean and SEM across sessions. Sessions need >= 8 trials with a finite state in
    each condition."""
    rows = []
    for _, g in tr.groupby("session", sort=False):
        y = g["rmse_late"].to_numpy(float)
        zy = (y - np.nanmean(y)) / np.nanstd(y, ddof=1)
        x = g[state].to_numpy(float)
        ok = np.isfinite(x) & np.isfinite(zy)
        isol, iscl = (g["condition"] == "OL").to_numpy(), (g["condition"] == "CL").to_numpy()
        if (ok & isol).sum() < 8 or (ok & iscl).sum() < 8:
            continue
        e = np.quantile(x[ok], [0.25, 0.5, 0.75], method="hazen")
        q = np.searchsorted(e, x, side="right")
        rows.append([[np.nanmean(zy[ok & m & (q == b)]) for b in range(4)] for m in (isol, iscl)])
    A = np.array(rows)  # sessions x cond x quartile
    n = np.sum(np.isfinite(A), axis=0)
    return np.nanmean(A, axis=0), np.nanstd(A, axis=0, ddof=1) / np.sqrt(n), A.shape[0]


def quartile_tile(a, tr, tests, state, ylabel=True, legend=True):
    m, se, n = quartile_means(tr, state)
    xq = np.arange(1, 5)
    a.axhline(0, color="0.75", lw=0.75, zorder=0)
    for c, col, dx in ((0, OL, -0.04), (1, CL, 0.04)):
        a.errorbar(xq + dx, m[c], yerr=se[c], color=col, marker="o", ms=2.5, lw=1.0, elinewidth=0.5)
    a.set_xticks(xq)
    a.set_xticklabels([f"Q{i}" for i in xq])
    a.set_xlim(0.6, 4.4)
    a.set_title(STATE_LAB[state], color=STATE_COL[state])
    if ylabel:
        a.set_ylabel("RMSE to target (z)")
    t = tests[(tests["figure"] == "fig4d") & (tests["window_or_state"] == state)].set_index("quantity")
    lines = []
    for q, name in (("P", "OL slope"), ("R", "CL slope"), ("A", "CL/OL")):
        p, eff = t.loc[q, "p"], t.loc[q, "effect"]
        lines.append(f"{name} n.s." if p >= 0.05 else f"{name} {'↑' if eff > 0 else '↓'}{stars(p)}")
    a.text(0.97, 0.98, "\n".join(lines), transform=a.transAxes, ha="right", va="top", fontsize=6,
           linespacing=1.15)
    if legend:
        a.text(0.03, 0.98, "OL", color=OL, transform=a.transAxes, ha="left", va="top", fontweight="bold")
        a.text(0.03, 0.88, "CL", color=CL, transform=a.transAxes, ha="left", va="top", fontweight="bold")
    a.set_xlabel("State quartile")
    return m, n


# ------------------------------------------------------------------------------ Q4/Q1 spectra
def ratio_tile(a, curves, tests, window, key, title, tcol, ylabel=True, ylim=(0.2, 12), fmax=8.0, above=False,
               clusters=None):
    """above=True puts the band bars and stars above the axes (layout only), for tiles whose curves
    reach the top. clusters (state_spectra_clusters.csv rows): one black bar per CL vs OL cluster over
    its frequency range, with stars of its Holm p, in place of the band stars."""
    cv = curves[(curves["window"] == window) & (curves["state"] == key)]
    a.axhline(1, color="0.5", lw=0.75, ls="--", zorder=0)
    n = {}
    for cond, col in (("OL", OL), ("CL", CL)):
        d = cv[(cv["cond"] == cond) & (cv["freq"] >= 0.45) & (cv["freq"] <= fmax * 1.05)]
        a.fill_between(d["freq"], d["lo"], d["hi"], color=col, alpha=0.15, lw=0)
        a.plot(d["freq"], d["ratio"], color=col, lw=1.0)
        n[cond] = int(d["n_sessions"].iloc[0])
    a.set_yscale("log")
    a.set_ylim(*ylim)
    yt = [t for t in (0.25, 0.5, 1, 2, 4, 8) if ylim[0] <= t <= ylim[1]]
    a.set_yticks(yt)
    a.set_yticklabels([f"{t:g}" for t in yt])
    a.yaxis.set_minor_locator(matplotlib.ticker.NullLocator())
    log_freq_axis(a, 0.5, fmax, (0.5, 1, 2, 4, 8))
    a.set_title(title, color=tcol, pad=18 if above else plt.rcParams["axes.titlepad"])
    if ylabel:
        a.set_ylabel("Q4 / Q1 power")
    ybar, rows, va = ((1.03, (("OL", OL, 1.15), ("CL", CL, 1.04)), "bottom") if above
                      else (0.985, (("OL", OL, 0.955), ("CL", CL, 0.875)), "top"))
    t = tests[(tests["window"] == window) & (tests["state"] == key)] if tests is not None else None
    if t is not None and len(t):
        tr = a.get_xaxis_transform()
        for bname, (f0, f1) in BANDS.items():
            a.plot([f0 * 1.03, f1 / 1.03], [ybar, ybar], color="0.3", lw=0.5, transform=tr, clip_on=False)
            for cond, col, yy in rows:
                p = t[(t["band"] == bname) & (t["test"] == f"Q4/Q1 {cond}")]["p_holm"].iloc[0]
                a.text(np.sqrt(f0 * f1), yy, stars(p), color=col, transform=tr, ha="center", va=va,
                       fontsize=6)
    if clusters is not None:
        tr = a.get_xaxis_transform()
        c = clusters[(clusters["window"] == window) & (clusters["state"] == key) & (clusters["cluster"] > 0)]
        for _, r in c.iterrows():
            a.plot([r["f_lo"], r["f_hi"]], [ybar, ybar], color="k", lw=0.75, transform=tr, clip_on=False,
                   solid_capstyle="butt")
            a.text(np.sqrt(r["f_lo"] * r["f_hi"]), ybar + (0.03 if above else -0.03), stars(r["p_holm"]),
                   color="k", transform=tr, ha="center", va=va, fontsize=6)
    return n


# ------------------------------------------------------------------------------ main panels
def main_B():
    """Figure 4B: unique R^2 of initial deviation, motion and absolute 1-4 Hz in ONE per-session model
    (f4_error_decomp.m 'abs' mode: y = b0 + b1 z_init + b2 z_motion + b3 z_log10abs + e, y = the trial's
    RMSE to target over 0-1 s or 1-3 s, states z-scored within session; U_j = adjusted R^2 of the full
    model minus that of the model without j). Bar = mean over sessions, error bar = SEM (SD ddof 1 /
    sqrt n). Read from controller-analysis/data/f4_error_decomp.mat (DEC.abs, run 2026-11-14,
    L-2026-11-14-a); nothing is refit. Math approved by Aditya 2026-11-18: "approve" (Hub control,
    option 1: the init + motion + absolute model replaces the 'sep' bars once relative power left the
    main figure). Drawn as the SfN poster panel (poster/sfn2026/unique_panel.m): broken y axis,
    two-line names, at paper type sizes."""
    import scipy.io as sio
    dec = sio.loadmat(loader.ROOT / "controller-analysis" / "data" / "f4_error_decomp.mat",
                      squeeze_me=True, struct_as_record=False)["DEC"].abs
    assert [str(s) for s in dec.fac] == ["init-dev", "motion", "abs 1-4Hz"], dec.fac
    U = dec.Us[:, :, np.asarray(dec.okS, bool)]              # state x window x session
    n = U.shape[2]
    P = U.mean(axis=2)
    E = U.std(axis=2, ddof=1) / np.sqrt(n)
    assert np.allclose(P, dec.Up, atol=1e-12), "session mean differs from the saved DEC.abs.Up"
    fc = np.array([matplotlib.colors.to_rgb(STATE_COL[s]) for s in ("init_dev", "motion", "abs_delta")])
    light, dark = 1 - 0.55 * (1 - fc), 0.70 * fc             # 0-1 s light, 1-3 s dark (unique_panel.m)
    lo, hi = (-0.01, 0.2), (0.35, 0.5)
    top_lo = np.delete((P + E).ravel(), 0)                    # every bar but init-dev 0-1 s fits below
    assert top_lo.max() < lo[1] and hi[0] < P[0, 0] - E[0, 0] and P[0, 0] + E[0, 0] < hi[1], (P, E)

    # 5.0 x 4.4 cm. Widened to 6.6 x 4.0 and back the same day (Aditya 2026-11-19: "No do not widen").
    WB, HB = 5.0, 4.4
    fig = plt.figure(figsize=(WB * CM, HB * CM))
    x0, w = 1.05, WB - 1.25
    yt, ht, yl_, hl = 0.55, 0.6, 1.27, HB - 0.8 - 1.27        # upper / lower segment top and height, cm
    a2 = axes_cm(fig, x0, yt, w, ht)                          # upper segment
    a1 = axes_cm(fig, x0, yl_, w, hl)                         # lower segment
    xb = np.arange(1, 4)
    for a in (a1, a2):
        for k, (col, dx) in enumerate(((light, -0.2), (dark, 0.2))):
            a.bar(xb + dx, P[:, k], width=0.38, color=col, lw=0)
            a.errorbar(xb + dx, P[:, k], yerr=E[:, k], ls="none", color="0.25", elinewidth=0.5, capsize=1.5,
                       capthick=0.5)
        a.set_xlim(0.5, 3.5)
    a1.axhline(0, color="0.6", lw=0.5, zorder=0)
    a1.set_ylim(*lo)
    a1.set_yticks([0, 0.1, 0.2])
    a1.set_yticklabels(["0", "0.1", "0.2"])
    a1.set_xticks(xb)
    a1.set_xticklabels([STATE_LAB_2[k] for k in ("init_dev", "motion", "abs_delta")])
    for t, k in zip(a1.get_xticklabels(), ("init_dev", "motion", "abs_delta")):
        t.set_color(STATE_COL[k])                             # names and colours as 4A and 4C (2026-11-19)
    a2.set_ylim(*hi)
    a2.set_yticks([0.4])
    a2.set_yticklabels(["0.4"])
    a2.set_xticks([])
    a2.spines["bottom"].set_visible(False)
    for yb in (yl_, yt + ht):                                 # break marks on the y axis, cm from top
        fig.add_artist(Line2D([(x0 - 0.07) / WB, (x0 + 0.07) / WB],
                              [1 - (yb + 0.04) / HB, 1 - (yb - 0.04) / HB], color="k", lw=0.5))
    for k, (lab, g) in enumerate((("0–1 s", "0.72"), ("1–3 s", "0.35"))):
        a2.add_patch(plt.Rectangle((2.45, 0.465 - k * 0.05), 0.15, 0.03, color=g, lw=0, clip_on=False))
        a2.text(2.68, 0.48 - k * 0.05, lab, va="center", ha="left")
    fig.text((x0 + w / 2) / WB, 1 - 0.42 / HB, f"Unique R² ({n} sessions)", ha="center", va="bottom",
             fontsize=7, fontweight="bold")
    fig.text(0.2 / WB, 1 - (yt + (yl_ + hl - yt) / 2) / HB, "Unique R²", rotation=90, ha="center", va="center",
             fontsize=7, fontweight="bold")
    save(fig, "f4B_unique")
    for j, s in enumerate(("init-dev", "motion", "abs 1-4 Hz")):
        print(f"  B {s:10s} 0-1 s {P[j, 0]:.3f} [{E[j, 0]:.3f}]   1-3 s {P[j, 1]:.3f} [{E[j, 1]:.3f}]   ({n} sessions)")


def main_C(tr, tests):
    """Figure 4C: quartile tiles for initial deviation, motion and absolute 1-4 Hz, one y scale."""
    # 7.7 cm wide (was 11.2) so D, C and E fit one 17.6 cm JN row (2026-11-19, layout only)
    fig = plt.figure(figsize=(7.7 * CM, ROW2_H * CM))
    out, axs = {}, []
    x0, w, step = 1.05, 2.05, 2.25
    for j, st in enumerate(("init_dev", "motion", "abs_delta")):
        a = axes_cm(fig, x0 + j * step, ROW2_Y, w, ROW2_AH)
        out[st] = quartile_tile(a, tr, tests, st, ylabel=(j == 0), legend=(j == 0))
        a.set_xlabel("")
        axs.append(a)
    xlabel_cm(fig, x0 + (2 * step + w) / 2, "State quartile")
    lo = min(a.get_ylim()[0] for a in axs)
    hi = max(a.get_ylim()[1] for a in axs)
    for j, a in enumerate(axs):
        a.set_ylim(lo, hi + 0.25 * (hi - lo))  # room for the slope labels
        if j:
            a.set_yticklabels([])
    save(fig, "f4C_quartiles")
    return out


def main_D():
    from sensitivity_cert import THETA, stretches_on
    c = pd.read_csv(DATA / "sensitivity_curve.csv")
    f = c["f_hz"].to_numpy()
    # 4.5 cm wide (was 5.6) so D, C and E fit one 17.6 cm JN row (2026-11-19, layout only)
    fig = plt.figure(figsize=(4.5 * CM, ROW2_H * CM))
    a = axes_cm(fig, 1.05, ROW2_Y, 3.35, ROW2_AH)
    kp = (f >= 0.5) & (f <= 17.5)
    a.axhline(1, color="0.5", lw=0.75, ls="--", zorder=1)
    a.plot(f[kp], c["S_pre"][kp], color="0.6", lw=1.0, zorder=2, label="Before stimulus")
    a.fill_between(f[kp], c["S_full_lo"][kp], c["S_full_hi"][kp], color="0.8", lw=0, zorder=3)
    a.plot(f[kp], c["S_full"][kp], color="k", lw=1.0, zorder=4, label="During stimulus")
    lim = 1 / (2 * np.pi * THETA)
    a.axvline(lim, color="0.3", lw=0.75, ls=":", zorder=2)
    a.text(lim * 1.07, 0.24, f"Delay limit\n{lim:.1f} Hz", color="0.3", ha="left", va="center")
    tr = a.get_xaxis_transform()
    lo, hi = c["S_full_lo"].to_numpy(), c["S_full_hi"].to_numpy()
    below = [s for s in stretches_on(f, hi < 1) if s[1] > 0.5][0]
    above = stretches_on(f, lo > 1)[0]
    for (x0, x1), lab in (((max(below[0], 0.5), below[1]), "Reduced"), (above, "Amplified")):
        a.plot([x0, x1], [1.0, 1.0], color="k", lw=1.0, transform=tr, solid_capstyle="butt", clip_on=False)
        a.text(np.sqrt(x0 * x1), 1.03, lab, transform=tr, ha="center", va="bottom")
    a.set_yscale("log")
    a.set_ylim(0.15, 3.4)
    a.set_yticks([0.25, 0.5, 1, 2])
    a.set_yticklabels(["0.25", "0.5", "1", "2"])
    a.yaxis.set_minor_locator(matplotlib.ticker.NullLocator())
    log_freq_axis(a, 0.5, 17.5, (0.5, 1, 2, 4, 8, 16))
    xlabel_cm(fig, 1.05 + 3.35 / 2, "Frequency (Hz)")
    a.set_ylabel("CL / OL residual power")
    # curves named on the plot, not in a legend: a legend no longer fits left of the delay line at 4.5 cm
    a.text(0.52, 1.9, "Before stimulus", color="0.5", ha="left", va="bottom")
    a.text(0.52, 0.27, "During stimulus", color="k", ha="left", va="top")
    save(fig, "f4D_sensitivity")
    print(f"  delay limit {lim:.2f} Hz; reduced {below[0]:.2f}-{below[1]:.2f} Hz; amplified "
          f"{above[0]:.2f}-{above[1]:.2f} Hz")


def main_E(curves, clus):
    """Curves only: the cluster bars were dropped at Aditya's request 2026-11-19 ("Drop the bars",
    L-2026-11-19-a). The cluster test is still run and printed here for the record."""
    # 4.6 cm wide, motion before absolute 1-4 Hz as in 4C (2026-11-19, layout only)
    fig = plt.figure(figsize=(4.6 * CM, ROW2_H * CM))
    x0, w, step = 1.0, 1.6, 1.9
    a1 = axes_cm(fig, x0, ROW2_Y, w, ROW2_AH)
    a2 = axes_cm(fig, x0 + step, ROW2_Y, w, ROW2_AH)
    n1 = ratio_tile(a1, curves, None, LOCKED, "motion", STATE_LAB["motion"], STATE_COL["motion"])
    n2 = ratio_tile(a2, curves, None, LOCKED, "abs14", STATE_LAB["abs_delta"], STATE_COL["abs_delta"],
                    ylabel=False)
    for _, r in clus[(clus["window"] == LOCKED) & (clus["cluster"] > 0)].iterrows():
        print(f"  E (not drawn) {r['state']:6s} cluster {r['f_lo']:.2f}-{r['f_hi']:.2f} Hz {r['sign']} "
              f"CL/OL {r['cl_ol']:.2f} p {r['p']:.3f} Holm {r['p_holm']:.3f}")
    a2.set_yticklabels([])
    a1.set_xlabel("")
    a2.set_xlabel("")
    xlabel_cm(fig, x0 + (step + w) / 2, "Frequency (Hz)")
    a1.text(0.96, 0.97, "OL", color=OL, transform=a1.transAxes, fontweight="bold", ha="right", va="top")
    a1.text(0.96, 0.86, "CL", color=CL, transform=a1.transAxes, fontweight="bold", ha="right", va="top")
    save(fig, "f4E_state_spectra")
    print(f"  sessions: motion {n1}, abs {n2}")


BAND_COL = {"slow": "#d0d0d0", "1-4 Hz": "#8c8c8c", "fast": "#3a3a3a"}
BAND_LAB = {"slow": "< 1 Hz", "1-4 Hz": "1–4 Hz", "fast": "> 4 Hz"}


def supp_error_bands(qt, window=LOCKED, name="f4S_error_bands"):
    """Supplement (Figure 4E from L-2026-11-18-c until L-2026-11-18-d): the 4C error (MSE over 1-3 s,
    session mean = 1) split by Parseval into < 1 Hz, 1-4 Hz and > 4 Hz, stacked per state quartile; rows motion and absolute 1-4 Hz, columns OL and CL. Read
    from error_bands_quartiles.csv (stats_v2/error_bands.py). Approved by Aditya 2026-11-18:
    "Approve" (RESEARCH L-2026-11-18-c). No tests. window=LASEROFF sorts by the laser-off state."""
    fig = plt.figure(figsize=(6.0 * CM, 4.4 * CM))
    q = qt[qt["window"] == window]
    tot = q[q["band"] == "total"]["mean"].max()
    ymax = np.ceil(tot * 1.05 / 0.5) * 0.5
    xq = np.arange(1, 5)
    for i, st in enumerate(("motion", "abs_delta")):
        for j, (cond, ccol) in enumerate((("OL", OL), ("CL", CL))):
            a = axes_cm(fig, 1.15 + j * 2.45, 0.75 + i * 1.6, 2.2, 1.3)
            d = q[(q["state"] == st) & (q["cond"] == cond)]
            bottom = np.zeros(4)
            for b in BAND_COL:
                v = d[d["band"] == b].sort_values("quartile")["mean"].to_numpy()
                a.bar(xq, v, 0.7, bottom=bottom, color=BAND_COL[b], lw=0)
                bottom += v
            ns = int(d["n_sessions"].min())
            print(f"  S {window[:9]} {st:9s} {cond}: totals {np.round(bottom, 3)} ({ns} sessions)")
            a.set_xlim(0.4, 4.6)
            a.set_ylim(0, ymax)
            a.set_yticks(np.arange(0, ymax + 0.01, 0.5 if ymax <= 1.5 else 1.0))
            a.set_xticks(xq)
            a.set_xticklabels([f"Q{k}" for k in xq] if i == 1 else [])
            if j:
                a.set_yticklabels([])
            else:
                a.set_ylabel(STATE_LAB[st], color=STATE_COL[st])
            if i == 0:
                a.set_title(cond, color=ccol)
    fig.text(0.1 / 6.0, 1 - 2.2 / 4.4, "Error power (session mean = 1)", rotation=90, ha="left", va="center",
             fontsize=7, fontweight="bold")
    fig.text((1.15 + 2.325) / 6.0, 0.02, "State quartile", ha="center", va="bottom", fontsize=7,
             fontweight="bold")
    x = 1.15
    for b in BAND_COL:
        fig.patches.append(matplotlib.patches.Rectangle((x / 6.0, 1 - 0.32 / 4.4), 0.22 / 6.0, 0.18 / 4.4,
                                                        transform=fig.transFigure, color=BAND_COL[b], lw=0))
        fig.text((x + 0.3) / 6.0, 1 - 0.23 / 4.4, BAND_LAB[b], ha="left", va="center", fontsize=6)
        x += 1.5
    save(fig, name)


# ------------------------------------------------------------------------------ supp: states
def supp_states(tr, tests, curves, sst):
    fig = plt.figure(figsize=(W_DOUBLE * CM, 17.0 * CM))
    # A: relative 1-4 Hz quartile tile
    letter(fig, 0.0, 0.1, "A")
    aA = axes_cm(fig, 1.2, 0.75, 3.6, 4.2)
    mA, nA = quartile_tile(aA, tr, tests, "rel_delta")
    lo, hi = aA.get_ylim()
    aA.set_ylim(lo, hi + 0.25 * (hi - lo))  # room for the slope and OL/CL labels, as in main_C
    print(f"  A rel 1-4 Hz quartiles, {nA} sessions: OL {np.round(mA[0], 2)}, CL {np.round(mA[1], 2)}")

    # B: state windows
    letter(fig, 5.4, 0.1, "B")
    sw = pd.read_csv(DATA / "f4d_windows_slopes.csv")
    wins = [("peri", "[−2,+3) s, locked"), ("pre5", "[−5,0) s, laser off"), ("pre2", "[−2,0) s, laser off"),
            ("stim", "[0,+3) s, laser on")]
    states = ["rel_delta", "abs_delta", "motion"]
    cols = [("P", "OL slope\n(%ΔF/F per SD)"), ("R", "CL slope\n(%ΔF/F per SD)"), ("A", "CL/OL slope\n(% per SD)")]
    x0, wB = 9.0, 2.6
    for j, (q, ttl) in enumerate(cols):
        a = axes_cm(fig, x0 + j * (wB + 0.35), 0.95, wB, 4.0)
        ys, labs = [], []
        for i, st in enumerate(states):
            for k, (w, wl) in enumerate(wins):
                r = sw[(sw.state == st) & (sw.window == w) & (sw.q == q)].iloc[0]
                e, l, h = r["effect"], r["ci_lo"], r["ci_hi"]
                if q == "A":  # CL/OL slope as a percentage per SD: 100 (e^A - 1)
                    e, l, h = 100 * np.expm1(e), 100 * np.expm1(l), 100 * np.expm1(h)
                y = -(i * 5 + k)
                face = STATE_COL[st] if w == "peri" else "white"
                a.plot([l, h], [y, y], color=STATE_COL[st], lw=0.5)
                a.plot(e, y, "o", ms=2.5, mec=STATE_COL[st], mfc=face, mew=0.5)
                a.text(1.0, y, f"{r['p']:.2g}" if r["p"] >= 0.001 else f"{r['p']:.0e}".replace("e-0", "e-"),
                       transform=a.get_yaxis_transform(), ha="right", va="center", fontsize=6,
                       color=STATE_COL[st])
                ys.append(y)
                labs.append(wl)
        a.axvline(0, color="0.5", lw=0.75, ls="--", zorder=0)
        lo_, hi_ = a.get_xlim()
        a.set_xlim(lo_, hi_ + 0.55 * (hi_ - lo_))
        a.set_ylim(-14.6, 0.6)
        a.set_yticks(ys)
        a.set_yticklabels(labs if j == 0 else [])
        a.tick_params(axis="y", length=0)
        a.spines["left"].set_visible(False)
        a.set_title(ttl)
        if j == 0:
            for i, st in enumerate(states):
                a.text(-0.9, -(i * 5 + 1.5), STATE_LAB[st], color=STATE_COL[st], transform=a.get_yaxis_transform(),
                       rotation=90, ha="center", va="center", fontsize=7, fontweight="bold")
    fig.text((x0 + 3 * wB + 0.7) / W_DOUBLE, 1 - 5.7 / 17.0, "p, session t-test (uncorrected)", ha="right",
             fontsize=6, color="0.3")

    # C: band grid
    letter(fig, 0.0, 6.0, "C")
    fb = pd.read_csv(DATA / "f4d_bands.csv")
    fine = ["0.4-1", "1-2", "2-3", "3-4", "4-5", "5-6", "6-7", "7-8", "8-9", "9-10"]
    cen = np.array([np.sqrt(0.4 * 1)] + [k + 0.5 for k in range(1, 10)])
    wC, hC = 4.9, 2.2
    for i, kind in enumerate(("abs", "rel")):
        st = "abs_delta" if kind == "abs" else "rel_delta"
        for j, (q, ttl) in enumerate(cols):
            a = axes_cm(fig, 1.2 + j * (wC + 0.85), 7.0 + i * (hC + 0.45), wC, hC)
            a.axvspan(1, 4, color="0.92", lw=0, zorder=0)
            a.axhline(0, color="0.5", lw=0.75, ls="--", zorder=0)
            for w, mfc, ls, dx in (("peri", STATE_COL[st], "-", 0.97), ("pre5", "white", "--", 1.03)):
                d = fb[(fb.kind == kind) & (fb.window == w) & (fb.q == q)].set_index("band").loc[fine]
                e, l, h = d["effect"].to_numpy(), d["ci_lo"].to_numpy(), d["ci_hi"].to_numpy()
                if q == "A":
                    e, l, h = 100 * np.expm1(e), 100 * np.expm1(l), 100 * np.expm1(h)
                a.errorbar(cen * dx, e, yerr=[e - l, h - e], color=STATE_COL[st], ls=ls, lw=0.75, elinewidth=0.5,
                           marker="o", ms=2.5, mfc=mfc, mec=STATE_COL[st], mew=0.5)
            log_freq_axis(a, 0.5, 10.5, (0.5, 1, 2, 4, 8))
            if i == 0:
                a.set_title(ttl.replace("\n", " "))
                a.set_xticklabels([])
            else:
                a.set_xlabel("Band centre (Hz)")
            if j == 0:
                a.set_ylabel(STATE_LAB[st].replace("1–4 Hz", "power"), color=STATE_COL[st])
    hl = [Line2D([], [], color="0.3", marker="o", ms=2.5, lw=0.75, label="[−2,+3) s, locked"),
          Line2D([], [], color="0.3", marker="o", ms=2.5, mfc="white", ls="--", lw=0.75, label="[−5,0) s, laser off")]
    fig.legend(handles=hl, loc="upper right", bbox_to_anchor=(1 - 0.2 / W_DOUBLE, 1 - 6.05 / 17.0), ncol=2,
               handlelength=2.0, columnspacing=1.0)

    # D: Q4/Q1 spectra, laser off, and relative power
    letter(fig, 0.0, 12.65, "D")
    tiles = [(LASEROFF, "motion", "Motion, laser off", STATE_COL["motion"]),
             (LASEROFF, "abs14", "Abs 1–4 Hz, laser off", STATE_COL["abs_delta"]),
             (LOCKED, "rel14", "Rel 1–4 Hz, locked", STATE_COL["rel_delta"]),
             (LASEROFF, "rel14", "Rel 1–4 Hz, laser off", STATE_COL["rel_delta"])]
    for j, (w, key, ttl, tc) in enumerate(tiles):
        a = axes_cm(fig, 1.2 + j * 4.1, 13.3, 3.45, 2.8)
        ratio_tile(a, curves, sst if key != "rel14" else None, w, key, ttl, tc, ylabel=(j == 0), ylim=(0.2, 8))
        a.set_xlabel("Frequency (Hz)")
        if j:
            a.set_yticklabels([])
    save(fig, "f4S_states")


# ------------------------------------------------------------------------------ supp: sensitivity
def supp_sensitivity():
    from sens_trials import AMP, per_frame_cmd, session
    from sensitivity import FREQ, geo, resid_psd, trials
    oc = pd.read_csv(DATA.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}

    # residual spectra per session (as sensitivity.py), and a check against sensitivity_curve.csv
    logP = {"OL": [], "CL": []}
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, onset_frames=onsets.get(sid))
        for cname, code in (("OL", 0), ("CL", 1)):
            logP[cname].append(np.log(resid_psd(trials(s, "full", code))))
    curve = pd.read_csv(DATA / "sensitivity_curve.csv")
    for cname in ("OL", "CL"):
        g = np.exp(np.mean(logP[cname], axis=0))
        err = np.max(np.abs(g / curve[f"P_{cname}_full_geo"].to_numpy() - 1))
        assert err < 1e-9, f"residual spectrum {cname} differs from sensitivity_curve.csv by {err}"

    sess = pd.read_csv(DATA / "sens_trials_sessions.csv")
    order = sess.sort_values("ratio_means").reset_index(drop=True)
    sid = order.loc[len(order) // 2, "session"]
    q = session(sid, onsets)
    info = loader.load_session(sid, onset_frames=onsets.get(sid))

    H_SENS = 17.3
    fig = plt.figure(figsize=(W_DOUBLE * CM, H_SENS * CM))
    # A: residual spectra
    letter(fig, 0.0, 0.1, "A")
    a = axes_cm(fig, 1.4, 0.7, 4.25, 3.4)
    kp = (FREQ >= 0.33) & (FREQ <= 17.5)
    for cname, col, lab in (("OL", OL, "Open loop"), ("CL", CL, "Closed loop")):
        m, lo, hi = geo(np.array(logP[cname]))
        a.fill_between(FREQ[kp], lo[kp], hi[kp], color=col, alpha=0.18, lw=0)
        a.plot(FREQ[kp], m[kp], color=col, lw=1.0, label=lab)
    a.set_yscale("log")
    log_freq_axis(a, 0.33, 17.5, (0.5, 1, 2, 4, 8, 16))
    a.set_xlabel("Frequency (Hz)")
    # plain tick labels: 10^x exponents print at 4.2 pt, below the 5 pt minimum
    yt = [1e-3, 1e-2, 1e-1, 1, 10]
    a.set_yticks(yt)
    a.set_yticklabels([f"{v:g}" for v in yt])
    a.set_ylabel("Residual power\n((%ΔF/F)²/Hz)")  # Arial has no superscript minus for Hz⁻¹
    a.legend(loc="lower left", handlelength=1.0, borderaxespad=0.1)
    a.set_title("Residual, 0–3 s")

    # B: 1 Hz bands
    letter(fig, 6.4, 0.1, "B")
    b1 = pd.read_csv(DATA / "sensitivity_bands_1hz.csv")
    a = axes_cm(fig, 7.6, 0.7, 9.8, 3.4)
    a.axhline(1, color="0.5", lw=0.75, ls="--", zorder=0)
    # stars of the three windows stack above the band's highest CI, so they do not overlap (layout only)
    star_top, star_k, star_hi = b1.groupby("lo")["ci_hi"].max(), {}, 0.0
    for w, col, dx, lab in (("full", "k", -0.12, "0–3 s"), ("late", "0.45", 0.0, "1–3 s"),
                            ("pre", "0.7", 0.12, "Before stimulus")):
        d = b1[b1.window == w]
        x = (d["lo"] + d["hi"]).to_numpy() / 2 + dx
        e, l, h = d["ratio"].to_numpy(), d["ci_lo"].to_numpy(), d["ci_hi"].to_numpy()
        a.errorbar(x, e, yerr=[e - l, h - e], color=col, marker="o", ms=2.5, lw=0.75, elinewidth=0.5, label=lab,
                   mfc=col if w != "pre" else "white", mec=col, mew=0.5)
        for xx, b0, p in zip(x, d["lo"].to_numpy(), d["p_holm"].to_numpy()):
            if p < 0.05:
                k = star_k.get(b0, 0)
                ys = star_top[b0] * 1.03 * 1.13 ** k
                a.text(xx - dx, ys, stars(p), color=col, ha="center", va="bottom", fontsize=6)
                star_k[b0], star_hi = k + 1, max(star_hi, ys)
    a.set_yscale("log")
    a.set_ylim(top=max(a.get_ylim()[1], star_hi * 1.2))
    a.set_yticks([0.5, 1, 2])
    a.set_yticklabels(["0.5", "1", "2"])
    a.yaxis.set_minor_locator(matplotlib.ticker.NullLocator())
    a.set_xlim(1, 17.6)
    a.set_xticks(np.arange(2, 18, 2))
    a.set_xlabel("Band centre (Hz), 1 Hz bands")
    a.set_ylabel("CL / OL band power")
    a.legend(loc="upper right", ncol=3, handlelength=1.2, columnspacing=1.0, borderaxespad=0.1)
    a.set_title("Holm over 17 bands per window")

    # C: band ratios per session
    letter(fig, 0.0, 4.9, "C")
    bt = pd.read_csv(DATA / "sensitivity_bands.csv")
    a = axes_cm(fig, 1.25, 5.5, 5.6, 3.4)
    a.axhline(1, color="0.5", lw=0.75, ls="--", zorder=0)
    scols = [c for c in bt.columns if c.startswith("S_m")]
    bands = ["0-1", "1-2", "2-4", "4-10"]
    rng = np.random.default_rng(1)
    for i, bnd in enumerate(bands):
        for w, col, dx in (("full", "k", -0.25), ("late", "0.45", 0.0), ("pre", "0.7", 0.25)):
            r = bt[(bt.window == w) & (bt.band == bnd)].iloc[0]
            v = r[scols].to_numpy(float)
            a.plot(i + dx + rng.uniform(-0.06, 0.06, len(v)), v, "o", ms=1.5, color=col, alpha=0.6, mew=0)
            a.errorbar(i + dx, r["ratio"], yerr=[[r["ratio"] - r["ci_lo"]], [r["ci_hi"] - r["ratio"]]], color=col,
                       marker="o", ms=3, elinewidth=0.75, mfc=col if w != "pre" else "white", mec=col, mew=0.75)
    a.set_yscale("log")
    a.set_yticks([0.1, 0.3, 1, 3])
    a.set_yticklabels(["0.1", "0.3", "1", "3"])
    a.yaxis.set_minor_locator(matplotlib.ticker.NullLocator())
    a.set_xticks(range(4))
    a.set_xticklabels([f"{b} Hz" for b in bands])
    a.set_xlim(-0.5, 3.5)
    a.set_ylabel("CL / OL band power")
    a.set_title("Sessions (dots), mean ± 95% CI")

    # E: variance budget and costs
    letter(fig, 7.5, 4.9, "E")
    bud = pd.read_csv(DATA / "sens_trials_budget.csv")
    mb = bud.groupby("band", sort=False)[["OL", "CL"]].mean()
    a = axes_cm(fig, 8.7, 5.5, 2.3, 3.4)
    shades = {"0-1": "0.25", "1-3": "0.55", "3-6": "#e69f00", "6-17.5": "0.85"}
    for k, cname in enumerate(("OL", "CL")):
        base = 0
        for bnd, val in mb[cname].items():
            a.bar(k, val, bottom=base, color=shades.get(bnd, "0.8"), width=0.6, lw=0,
                  label=f"{bnd} Hz" if k == 0 else None)
            base += val
    a.set_xticks([0, 1])
    a.set_xticklabels(["OL", "CL"])
    for t, c in zip(a.get_xticklabels(), (OL, CL)):
        t.set_color(c)
    a.set_ylabel("Residual variance\n((%ΔF/F)²)")
    a.legend(loc="upper right", handlelength=0.8, borderaxespad=0.0, labelspacing=0.2, bbox_to_anchor=(1.08, 1.02))
    a.set_title("By band")
    rm = pd.read_csv(DATA / "sens_trials_rmse.csv")
    for k, (ttl, yo, yc, yl) in enumerate((("3–6 Hz", sess["rms_OL"], sess["rms_CL"], "3–6 Hz residual RMS (%ΔF/F)"),
                                          ("All frequencies", rm[rm.window == "0-3 s"]["rmse_OL"],
                                           rm[rm.window == "0-3 s"]["rmse_CL"], "Trial RMSE 0–3 s (%ΔF/F)"))):
        a = axes_cm(fig, 12.3 + k * 2.75, 5.5, 2.0, 3.4)
        for o, c in zip(yo, yc):
            a.plot([0, 1], [o, c], color="0.6", lw=0.4)
        a.plot([0, 1], [np.mean(yo), np.mean(yc)], color="k", lw=1.0, marker="o", ms=2.5)
        a.set_xticks([0, 1])
        a.set_xticklabels(["OL", "CL"])
        for t, c in zip(a.get_xticklabels(), (OL, CL)):
            t.set_color(c)
        a.set_xlim(-0.3, 1.3)
        a.set_ylim(bottom=0)
        a.set_ylabel(yl)
        a.set_title(ttl)

    # D: example trials of the median session; the 3-6 Hz part is sens_trials.py's display-only
    # band-pass (2nd-order Butterworth, forward and backward, at 35 Hz)
    letter(fig, 0.0, 9.8, "D")
    t = np.arange(q["OL"]["X"].shape[1]) / M.FS
    picks = [("OL", 50), ("CL", 50), ("OL", 90), ("CL", 90)]
    raw = np.concatenate([q[c]["X"].ravel() for c in ("OL", "CL")])
    ylr = (np.nanpercentile(raw, 0.5), np.nanpercentile(raw, 99.5))
    for j, (cname, pct) in enumerate(picks):
        d = q[cname]
        i = int(np.argsort(d["amp"])[int(round(pct / 100 * (d["n"] - 1)))])
        col = OL if cname == "OL" else CL
        x0 = 1.25 + j * 3.15
        a0 = axes_cm(fig, x0, 10.45, 2.65, 2.1)
        a0.plot(t, d["X"].mean(axis=0), color="0.6", lw=0.75)
        a0.plot(t, d["X"][i], color=col, lw=0.75)
        a0.axhline(info["ref"], color="0.3", ls="--", lw=0.75)
        a0.set_ylim(*ylr)
        a0.set_xticklabels([])
        a0.set_title(f"{cname}, {pct}th percentile", color=col)
        a1 = axes_cm(fig, x0, 12.8, 2.65, 1.6)
        a1.plot(t, d["B"][i], color=col, lw=0.75)
        a1.axhline(0, color="0.75", lw=0.5)
        a1.set_ylim(-3, 3)
        a1.set_xticklabels([])
        a2 = axes_cm(fig, x0, 14.65, 2.65, 1.6)
        u = per_frame_cmd(info, info["timeBlue"][d["on"][i]], len(t))
        a2.plot(t, u, color="k", lw=0.75)
        a2.set_ylim(0, 0.9)
        a2.set_xlabel("Time from onset (s)")
        if j == 0:
            a0.set_ylabel("ΔF/F (%)")
            a1.set_ylabel("3–6 Hz part\n(%ΔF/F)")
            a2.set_ylabel("Laser\ncommand (V)")
        else:
            for ax_ in (a0, a1, a2):
                ax_.set_yticklabels([])
    a = axes_cm(fig, 14.75, 10.45, 2.65, 2.1)
    for k, cname in enumerate(("OL", "CL")):
        v = q[cname]["amp"]
        a.plot(k + rng.uniform(-0.15, 0.15, len(v)), v, "o", ms=1.5, mew=0, alpha=0.6,
               color=OL if cname == "OL" else CL)
        a.plot([k - 0.25, k + 0.25], [np.median(v)] * 2, color="k", lw=1.0)
    a.set_yscale("log")
    a.set_yticks([0.1, 1])
    a.set_yticklabels(["0.1", "1"])  # plain labels: 10^x exponents print below 5 pt
    a.set_xticks([0, 1])
    a.set_xticklabels(["OL", "CL"])
    a.set_xlim(-0.5, 1.5)
    a.set_ylabel("Trial 3–6 Hz\npower ((%ΔF/F)²)")
    a.set_title("Trials, bar = median")
    r = sess[sess.session == sid].iloc[0]
    fig.text(14.75 / W_DOUBLE, 1 - 13.0 / H_SENS,
             f"{info['mouse']} session {sid}\n{int(r['nOL'])} OL, {int(r['nCL'])} CL trials\n"
             f"CL/OL 3–6 Hz power {r['ratio_means']:.2f}\n(median of {len(sess)} sessions)",
             fontsize=6, va="top", ha="left")
    save(fig, "f4S_sensitivity")
    print(f"  D example session {sid} ({info['mouse']}), CL/OL 3-6 Hz {r['ratio_means']:.2f}; AMP {AMP}")


def main():
    style()
    tr = pd.read_csv(DATA / "trials.csv")
    tests = pd.read_csv(DATA / "tests.csv")
    curves = pd.read_csv(DATA / "state_spectra_curves.csv")
    sst = pd.read_csv(DATA / "state_spectra_tests.csv")
    clus = pd.read_csv(DATA / "state_spectra_clusters.csv")
    qt = pd.read_csv(DATA / "error_bands_quartiles.csv")
    main_B()
    qc = main_C(tr, tests)
    main_D()
    main_E(curves, clus)
    supp_error_bands(qt)
    supp_error_bands(qt, LASEROFF, "f4S_error_bands_laseroff")
    supp_states(tr, tests, curves, sst)
    # check: the Python quartile means against the MATLAB f4_row2_quartiles.m run
    for st, (m, n) in qc.items():
        print(f"  check {st:9s} ({n} sessions): OL {np.round(m[0], 2)}, CL {np.round(m[1], 2)}")
        if st in MATLAB_Q:
            d = np.max(np.abs(np.round(m, 2) - np.array(MATLAB_Q[st])))
            print(f"    max |Python - MATLAB| = {d:.2f}")
    if "--no-sens" not in sys.argv:
        supp_sensitivity()


if __name__ == "__main__":
    main()
