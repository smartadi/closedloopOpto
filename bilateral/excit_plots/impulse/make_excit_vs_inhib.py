#!/usr/bin/env python
"""make_excit_vs_inhib.py — EXPLORATORY excitatory-vs-inhibitory impulse comparison (AL_0048).

Reuses the bilateral/impulse pipeline (impulse_core / impulse_config / grid loader+calib+SVD)
to load each dual-opsin impulse session ONCE and render 300-dpi PNG comparison panels into
this folder (bilateral/excit_plots/impulse/). NOT paper-styled, NOT PDF — exploratory only.

Dual opsin: LEFT hemisphere = EXCITATORY opsin (galvoX<0 -> focal +dF/F, fast transient +
post-offset rebound); RIGHT = INHIBITORY (galvoX>0 -> focal -dF/F, sustained dip).

Deliverables per session (prefixed <date>_):
  1. <date>_traces_excit_vs_inhib.png   per-amp trial-mean dF/F, both hemispheres
  2. <date>_dose_response_overlaid.png  peak + energy vs amp, BOTH hemispheres on the SAME axes
  3. <date>_sites.png / <date>_spatial.png   excit-left(+/red) vs inhib-right(-/blue) polarity

Run from the repo root:
    .venv/Scripts/python.exe bilateral/excit_plots/impulse/make_excit_vs_inhib.py
"""
import sys
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
IMPULSE_DIR = HERE.parent.parent / "impulse"       # bilateral/impulse
sys.path.insert(0, str(IMPULSE_DIR))

import impulse_config as cfg      # noqa: E402  (also puts bilateral/grid on sys.path)
import impulse_core as core       # noqa: E402
import analysis                   # noqa: E402  (bilateral/grid)

OUTDIR = HERE
DPI = 300
SESSIONS_TO_RUN = ["2026-07-10", "2026-07-15"]

EXC_COLOR = "tab:red"     # left / excitatory
INH_COLOR = "tab:blue"    # right / inhibitory
SIDE_TITLE = {"left": "LEFT / excitatory (+)", "right": "RIGHT / inhibitory (-)"}
SIDE_COLOR = {"left": EXC_COLOR, "right": INH_COLOR}

# post-transient rebound window for the excitatory undershoot (exploratory readout)
REBOUND_WIN = (0.15, 0.60)


def set_session(date):
    """Point impulse_config at `date` (re-derive the fields config computes at import)."""
    S = cfg.SESSIONS[date]
    cfg.SESSION = date
    cfg.DATE = date
    cfg.WF_EXP = S["WF_EXP"]
    cfg.IMPULSE_BLOCK = S["IMPULSE_BLOCK"]
    cfg.CALIB_BLOCK = S["CALIB_BLOCK"]
    cfg.EXPDIR = Path(cfg.SERVER) / cfg.SUBJECT / date / cfg.WF_EXP
    cfg.AMPS = S["AMPS"]
    cfg.FOCUS_AMP = S["FOCUS_AMP"]
    cfg.DOSE_AMPS = ([0.0] + list(cfg.AMPS)) if cfg.RECOVER_SHAM else list(cfg.AMPS)


def _amp_colors(amps):
    return plt.cm.viridis(np.linspace(0.15, 0.9, len(amps)))


def analyze(date):
    set_session(date)
    print(f"\n================ {cfg.SUBJECT} {date} (exp {cfg.WF_EXP}, block {cfg.IMPULSE_BLOCK}) ================")
    S = core.load_session(cfg)
    U, mimg, svdT, V = S["U"], S["mimg"], S["svdT"], S["V"]
    onset_t, amp, side = S["onset_t"], S["amp"], S["side"]

    for sd in ["left", "right"]:
        m = side == sd
        u, c = np.unique(amp[m], return_counts=True)
        print(f"  {sd:>5}: " + ", ".join(f"{a}:{n}" for a, n in zip(u, c)))

    t2svd = analysis.make_t2svd(svdT, V)
    window = np.arange(-cfg.WIN_PRE, cfg.WIN_POST, 1 / cfg.FS_WIN)
    base_ix = int(np.argmin(np.abs(window)))

    U50 = np.asarray(U[:, :, :cfg.N_COMPS])
    focal, traces, energy, peak = {}, {}, {}, {}
    for sd, nominal, sign in [("left", cfg.SITE_LEFT, +1), ("right", cfg.SITE_RIGHT, -1)]:
        sel = (side == sd) & (amp == cfg.FOCUS_AMP)
        px, py, dff_im = core.find_focal_pixel(U50, mimg, t2svd, onset_t[sel], nominal, sign, cfg)
        focal[sd] = (px, py, dff_im)
        these = onset_t[side == sd]
        amps_here = amp[side == sd]
        tr = core.site_traces(U, mimg, t2svd, (px, py), these, amps_here, window, base_ix, cfg)
        traces[sd] = tr
        energy[sd] = core.energy_per_trial(tr, window, cfg)
        peak[sd] = core.peak_of_mean_dose(tr, window, cfg, sign)
        print(f"  {sd} focal pixel = ({px}, {py})  [nominal galvo {nominal} mm]")

    return dict(date=date, mimg=mimg, focal=focal, window=window,
                traces=traces, energy=energy, peak=peak)


def rebound_of_mean(tr, window):
    """Signed min (undershoot) of the trial-mean excit trace in REBOUND_WIN, per amp."""
    m = (window >= REBOUND_WIN[0]) & (window < REBOUND_WIN[1])
    out = {}
    for a, t in tr.items():
        out[a] = float(np.nanmin(np.nanmean(t["dff"][:, m], 0)))
    return out


def print_numbers(R):
    date = R["date"]
    print(f"\n  --- {date} excit-vs-inhib readout ---")
    reb = rebound_of_mean(R["traces"]["left"], R["window"])
    print("  amp | EXCIT peak(0-300ms) | EXCIT rebound-min(.15-.6s) | INHIB peak(dip) | INHIB energy(0-200ms med)")
    amps = sorted(set(R["peak"]["left"]) | set(R["peak"]["right"]))
    for a in amps:
        lp = R["peak"]["left"].get(a)
        rp = R["peak"]["right"].get(a)
        ren = R["energy"]["right"].get(a)
        lp_s = f"{lp[0]:+.4f}" if lp else "   -   "
        rb_s = f"{reb.get(a, np.nan):+.4f}" if a in reb else "   -   "
        rp_s = f"{rp[0]:+.4f}" if rp else "   -   "
        ren_s = f"{np.nanmedian(ren):+.4f}" if ren is not None else "   -   "
        print(f"  {a:>3} | {lp_s:>10}          | {rb_s:>10}                | {rp_s:>10}     | {ren_s:>10}")


# ------------------------------ plots ------------------------------
def plot_traces(R):
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4), sharex=True)
    for ax, sd in zip(axes, ["left", "right"]):
        tr = R["traces"][sd]
        amps = sorted(tr.keys())
        cols = _amp_colors(amps)
        for a, c in zip(amps, cols):
            m, sem = tr[a]["mean"], tr[a]["sem"]
            ax.plot(R["window"], m, color=c, lw=1.4, label=f"{a} (n={tr[a]['n']})")
            ax.fill_between(R["window"], m - sem, m + sem, color=c, alpha=0.18, lw=0)
        ax.axvline(0, color="k", lw=0.6, ls="--")
        ax.axhline(0, color="k", lw=0.4)
        ax.axvspan(*cfg.ENERGY_WIN, color="0.85", alpha=0.6, zorder=0)      # 0-200ms energy win
        if sd == "left":
            ax.axvspan(*REBOUND_WIN, color="tab:orange", alpha=0.10, zorder=0)  # rebound win
        ax.set_title(SIDE_TITLE[sd])
        ax.set_xlabel("time from impulse (s)")
        ax.set_ylabel("dF/F")
        ax.set_xlim(-0.3, 1.2)
        ax.legend(title="amp", fontsize=7, frameon=False, ncol=2)
    fig.suptitle(f"{cfg.SUBJECT} {R['date']} — impulse response by amplitude "
                 f"(excit transient+rebound vs inhib dip)")
    fig.tight_layout()
    _save(fig, f"{R['date']}_traces_excit_vs_inhib.png")


def plot_dose_overlaid(R):
    """BOTH hemispheres on the SAME axes: peak (left panel) and 0-200 ms energy (right panel)."""
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.4))

    # peak of mean, both sides overlaid
    ax = axes[0]
    for sd in ["left", "right"]:
        pd = R["peak"][sd]
        al = sorted(pd.keys())
        a = np.array(al)
        pt = np.array([pd[x][0] for x in al])
        lo = np.array([pd[x][1] for x in al])
        hi = np.array([pd[x][2] for x in al])
        c = SIDE_COLOR[sd]
        ax.fill_between(a, lo, hi, color=c, alpha=0.15, lw=0)
        ax.plot(a, pt, "o-", color=c, lw=1.6, label=SIDE_TITLE[sd])
    ax.axhline(0, color="k", lw=0.5)
    ax.set_title("signed peak of trial-mean (0-300 ms)")
    ax.set_xlabel("laser amplitude (V command)")
    ax.set_ylabel("peak dF/F")
    ax.legend(fontsize=8, frameon=False)

    # 0-200 ms energy, both sides overlaid (median + 2.5-97.5 pct)
    ax = axes[1]
    for sd in ["left", "right"]:
        en = R["energy"][sd]
        al = sorted(en.keys())
        a = np.array(al)
        med = np.array([np.nanmedian(en[x]) for x in al])
        lo = np.array([np.nanpercentile(en[x], 2.5) for x in al])
        hi = np.array([np.nanpercentile(en[x], 97.5) for x in al])
        c = SIDE_COLOR[sd]
        ax.fill_between(a, lo, hi, color=c, alpha=0.12, lw=0)
        ax.plot(a, med, "o-", color=c, lw=1.6, label=SIDE_TITLE[sd])
    ax.axhline(0, color="k", lw=0.5)
    ax.set_title("0-200 ms mean dF/F (energy), median +/- 2.5-97.5 pct")
    ax.set_xlabel("laser amplitude (V command)")
    ax.set_ylabel("energy dF/F")
    ax.legend(fontsize=8, frameon=False)

    fig.suptitle(f"{cfg.SUBJECT} {R['date']} — dose-response, excitatory vs inhibitory (same axes)")
    fig.tight_layout()
    _save(fig, f"{R['date']}_dose_response_overlaid.png")


def plot_sites(R):
    fig, ax = plt.subplots(figsize=(6.2, 6.2))
    ax.imshow(R["mimg"], cmap="gray")
    ax.plot(*cfg.BREGMA_PX, "o", mfc="none", mec="magenta", ms=12, mew=2, label="bregma")
    for sd, (px, py, _) in R["focal"].items():
        ax.plot(px, py, "o", mfc="none", mec=SIDE_COLOR[sd], ms=13, mew=2.2)
        ax.text(px + 8, py, SIDE_TITLE[sd], color=SIDE_COLOR[sd], fontsize=9, va="center")
    ax.set_title(f"{cfg.SUBJECT} {R['date']} — data-derived focal impulse sites")
    ax.axis("off")
    fig.tight_layout()
    _save(fig, f"{R['date']}_sites.png")


def plot_spatial(R):
    fig, axes = plt.subplots(1, 2, figsize=(9.4, 4.8))
    for ax, sd in zip(axes, ["left", "right"]):
        px, py, dff = R["focal"][sd]
        im = ax.imshow(dff, cmap="bwr", vmin=-cfg.SPATIAL_CLIM, vmax=cfg.SPATIAL_CLIM)
        ax.plot(px, py, "kx", ms=11, mew=2)
        ax.set_title(f"{SIDE_TITLE[sd]}  (amp {cfg.FOCUS_AMP})")
        ax.axis("off")
        fig.colorbar(im, ax=ax, fraction=0.046, label="dF/F")
    fig.suptitle(f"{cfg.SUBJECT} {R['date']} — focal localization "
                 f"(excit +red / inhib -blue confirms polarity)")
    fig.tight_layout()
    _save(fig, f"{R['date']}_spatial.png")


def _save(fig, name):
    OUTDIR.mkdir(parents=True, exist_ok=True)
    p = OUTDIR / name
    fig.savefig(p, dpi=DPI, bbox_inches="tight")
    plt.close(fig)
    print("  wrote", p.name)


def main():
    for date in SESSIONS_TO_RUN:
        try:
            R = analyze(date)
        except Exception as e:
            print(f"  !! {date} FAILED to load/analyze: {type(e).__name__}: {e}")
            continue
        print_numbers(R)
        plot_traces(R)
        plot_dose_overlaid(R)
        plot_sites(R)
        plot_spatial(R)
    print("\nwrote ->", OUTDIR)


if __name__ == "__main__":
    main()
