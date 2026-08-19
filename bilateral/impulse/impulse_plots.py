"""impulse_plots.py — figures for the dual-opsin impulse dose-response.

Exploratory PNGs (regenerable, gitignored). If any is promoted to a paper panel, re-render
through utils/paperFig + paperStyle per the project figure standard.
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SIDE_TITLE = {"left": "LEFT / excitatory", "right": "RIGHT / inhibitory"}
SIDE_COLOR = {"left": "tab:red", "right": "tab:blue"}


def _amp_colors(amps):
    return plt.cm.viridis(np.linspace(0.15, 0.9, len(amps)))


def plot_sites(mimg, focal, cfg, label=""):
    """Mean image with bregma + the two data-derived focal pixels marked."""
    fig, ax = plt.subplots(figsize=(6, 6))
    ax.imshow(mimg, cmap="gray")
    ax.plot(*cfg.BREGMA_PX, "o", mfc="none", mec="magenta", ms=12, mew=2)
    for side, (px, py, _) in focal.items():
        ax.plot(px, py, "o", mfc="none", mec=SIDE_COLOR[side], ms=12, mew=2)
        ax.text(px + 8, py, SIDE_TITLE[side], color=SIDE_COLOR[side], fontsize=9, va="center")
    ax.set_title(f"{cfg.SUBJECT} {cfg.DATE} — focal impulse sites  {label}")
    ax.axis("off")
    fig.tight_layout(); _save(fig, cfg, "impulse_sites.png")


def plot_traces(window, traces_by_side, cfg, label=""):
    """Per-amp trial-averaged dF/F at each focal site (mean +/- SEM shading)."""
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2), sharex=True)
    for ax, side in zip(axes, ["left", "right"]):
        tr = traces_by_side[side]
        amps = sorted(tr.keys())               # includes recovered amp 0.0 (sham) if present
        cols = _amp_colors(amps)
        for a, c in zip(amps, cols):
            m, sem = tr[a]["mean"], tr[a]["sem"]
            ax.plot(window, m, color=c, lw=1.5, label=f"{a} ({tr[a]['n']})")
            ax.fill_between(window, m - sem, m + sem, color=c, alpha=0.2, lw=0)
        ax.axvline(0, color="k", lw=0.6, ls="--")
        ax.axhline(0, color="k", lw=0.4)
        ax.axvspan(*cfg.ENERGY_WIN, color="0.85", alpha=0.5, zorder=0)
        ax.set_title(SIDE_TITLE[side]); ax.set_xlabel("time from impulse (s)")
        ax.set_ylabel("dF/F"); ax.legend(title="amp (n)", fontsize=7, frameon=False)
    fig.suptitle(f"{cfg.SUBJECT} {cfg.DATE} — impulse response by amplitude  {label}")
    fig.tight_layout(); _save(fig, cfg, "impulse_traces.png")


def plot_dose_response(metric_by_side, cfg, ylabel, fname, label=""):
    """dF/F metric vs amplitude per side: median +/- 95th-pct bounds and mean +/- SEM.
    metric_by_side[side] = {amp: per-trial values}."""
    fig, axes = plt.subplots(1, 2, figsize=(9, 4), sharex=True)
    for ax, side in zip(axes, ["left", "right"]):
        en = metric_by_side[side]
        al = sorted(en.keys())                 # includes recovered amp 0.0 (sham) if present
        amps = np.array(al)
        med = np.array([np.nanmedian(en[a]) for a in al])
        lo = np.array([np.nanpercentile(en[a], 2.5) for a in al])
        hi = np.array([np.nanpercentile(en[a], 97.5) for a in al])
        mean = np.array([np.nanmean(en[a]) for a in al])
        sem = np.array([np.nanstd(en[a]) / np.sqrt(len(en[a])) for a in al])
        c = SIDE_COLOR[side]
        ax.fill_between(amps, lo, hi, color=c, alpha=0.15, lw=0, label="2.5-97.5 pct")
        ax.plot(amps, med, "o-", color=c, lw=1.5, label="median")
        ax.errorbar(amps, mean, yerr=sem, fmt="s--", color="k", ms=4, lw=1,
                    capsize=2, label="mean +/- SEM")
        ax.axhline(0, color="k", lw=0.4)
        ax.set_title(SIDE_TITLE[side]); ax.set_xlabel("laser amplitude (V command)")
        ax.set_ylabel(ylabel)
        ax.legend(fontsize=7, frameon=False)
    fig.suptitle(f"{cfg.SUBJECT} {cfg.DATE} — impulse dose-response  {label}")
    fig.tight_layout(); _save(fig, cfg, fname)


def plot_peak_dose(peak_dose_by_side, cfg, label=""):
    """Signed peak of the trial-mean trace vs amplitude, per side, with bootstrap 95% CI.
    peak_dose_by_side[side] = {amp: (point, lo, hi)}."""
    fig, axes = plt.subplots(1, 2, figsize=(9, 4), sharex=True)
    for ax, side in zip(axes, ["left", "right"]):
        pd = peak_dose_by_side[side]
        al = sorted(pd.keys())                 # includes recovered amp 0.0 (sham) if present
        amps = np.array(al)
        pt = np.array([pd[a][0] for a in al])
        lo = np.array([pd[a][1] for a in al])
        hi = np.array([pd[a][2] for a in al])
        c = SIDE_COLOR[side]
        ax.fill_between(amps, lo, hi, color=c, alpha=0.18, lw=0, label="bootstrap 95% CI")
        ax.plot(amps, pt, "o-", color=c, lw=1.5, label="peak of mean trace")
        ax.axhline(0, color="k", lw=0.4)
        ax.set_title(SIDE_TITLE[side]); ax.set_xlabel("laser amplitude (V command)")
        ax.set_ylabel("signed peak dF/F (0-300 ms)")
        ax.legend(fontsize=7, frameon=False)
    fig.suptitle(f"{cfg.SUBJECT} {cfg.DATE} — impulse dose-response (peak)  {label}")
    fig.tight_layout(); _save(fig, cfg, "impulse_dose_response_peak.png")


def plot_spatial(focal, cfg, label=""):
    """Focal-localization dF/F image per side (strongest amp, early stim vs baseline)."""
    fig, axes = plt.subplots(1, 2, figsize=(9, 4.6))
    for ax, side in zip(axes, ["left", "right"]):
        px, py, dff = focal[side]
        im = ax.imshow(dff, cmap="bwr", vmin=-cfg.SPATIAL_CLIM, vmax=cfg.SPATIAL_CLIM)
        ax.plot(px, py, "kx", ms=10, mew=2)
        ax.set_title(f"{SIDE_TITLE[side]}  (amp {cfg.FOCUS_AMP})"); ax.axis("off")
        fig.colorbar(im, ax=ax, fraction=0.046, label="dF/F")
    fig.suptitle(f"{cfg.SUBJECT} {cfg.DATE} — focal localization  {label}")
    fig.tight_layout(); _save(fig, cfg, "impulse_spatial.png")


def _save(fig, cfg, name):
    cfg.OUTDIR.mkdir(exist_ok=True)
    p = cfg.OUTDIR / name
    fig.savefig(p, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("  wrote", p.name)
