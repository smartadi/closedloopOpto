#!/usr/bin/env python
"""run_excit_grid.py — EXPLORATORY excitatory-focused grid figures for AL_0048.

Reuses the existing grid pipeline (config/loader/analysis/calibration/plots) to run the
CLEAN 638 nm site-grid session (2026-07-10 exp 3 / block 6, amps 1.0 & 2.0) and writes
exploratory PNGs (300 dpi) into  bilateral/excit_plots/grid/  focused on the EXCITATORY
(left, galvo_x<0) hemisphere.

Outputs (bilateral/excit_plots/grid/):
  grid_sites.png                       registration overlay (amp-independent)
  amp_<a>/grid_{timecourses,tau,spatial,raster}.png   standard per-site figures per amp
  amp_linearity.png                    per-site dose-response amp1->amp2 (excit red / inhib blue)
  excit_focal_map.png                  signed focal dF/F over the 52 grid nodes (NEW panel)
  excit_left_timecourses.png           excitatory-left ROI dF/F traces (NEW panel)
  excit_left_raster.png                excitatory-left per-site trial x time raster (NEW panel)

Nothing here modifies the shared pipeline modules. Run from repo root:
    .venv/Scripts/python.exe bilateral/grid/run_excit_grid.py

Galvo side convention (verified): galvo_x_mm < 0 = LEFT = EXCITATORY; > 0 = RIGHT = INHIBITORY.
The orange 594 nm grid (2026-04-22/4) has NO widefield SVD on the share and cannot be run here.
"""
import types
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import config as base
import loader
import analysis
import calibration
import plots

DATA = Path(__file__).resolve().parents[2] / "data"
OUT = Path(__file__).resolve().parents[1] / "excit_plots" / "grid"

DATE, WF, BLOCK, SEG = "2026-07-10", "3", "6", "last"   # clean 638 dose-response session
MIN_ONSETS = 300


def make_cfg(outdir):
    c = types.SimpleNamespace(**{k: getattr(base, k) for k in dir(base) if k.isupper()})
    c.DATE = DATE
    c.OUTDIR = Path(outdir)
    return c


def excit_focal_map(focal_by_amp, sites, cfg):
    """NEW panel: signed early-window focal dF/F at every grid node, one subplot per amp.
    Red = positive (excitatory-left expected), blue = negative (inhibitory-right expected).
    Marker size scales with |response|. A dashed midline marks the excit/inhib hemisphere
    split (mx=0)."""
    amps = sorted(focal_by_amp)
    fig, axes = plt.subplots(1, len(amps), figsize=(5.2 * len(amps), 5.0), squeeze=False)
    vmax = max(abs(v) for a in amps for v in focal_by_amp[a].values()) * 100
    for ax, a in zip(axes[0], amps):
        fb = focal_by_amp[a]
        xs = np.array([s[0] for s in sites]); ys = np.array([s[1] for s in sites])
        vals = np.array([fb[tuple(s)] for s in sites]) * 100
        sc = ax.scatter(xs, ys, c=vals, cmap="bwr", vmin=-vmax, vmax=vmax,
                        s=40 + 380 * np.abs(vals) / max(vmax, 1e-9), ec="k", lw=0.4)
        ax.axvline(0, ls="--", c="0.4", lw=0.8)
        ax.text(-1.9, 3.6, "EXCIT (left)", color="tab:red", fontsize=9, ha="center", weight="bold")
        ax.text(1.9, 3.6, "INHIB (right)", color="tab:blue", fontsize=9, ha="center", weight="bold")
        ax.set_aspect("equal"); ax.invert_yaxis()
        ax.set_xlabel("galvo x (mm from bregma)"); ax.set_ylabel("galvo y (mm)")
        ax.set_title(f"amp {a}")
    cb = fig.colorbar(sc, ax=list(axes[0]), shrink=0.7); cb.set_label("focal dF/F (%)")
    fig.suptitle(f"{base.SUBJECT} {DATE} - signed focal response per grid site "
                 f"({cfg.STIM_WIN[0]*1000:.0f}-{cfg.STIM_WIN[1]*1000:.0f} ms)")
    fig.savefig(OUT / "excit_focal_map.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print("  wrote excit_focal_map.png")


def excit_left_timecourses(window, resp_by_amp, cfg):
    """NEW panel: excitatory-LEFT (mx<0) ROI dF/F median +/- SEM, small-multiples by site,
    one column of amps overlaid per site."""
    amps = sorted(resp_by_amp)
    left_sites = sorted({s for a in amps for s in resp_by_amp[a]
                         if s[0] < 0}, key=lambda s: (s[1], s[0]))
    ncol = 7
    nrow = int(np.ceil(len(left_sites) / ncol))
    fig, axes = plt.subplots(nrow, ncol, figsize=(2.0 * ncol, 1.7 * nrow),
                             squeeze=False, sharex=True, sharey=True)
    colors = {amps[0]: "tab:orange", amps[-1]: "tab:red"}
    for k, s in enumerate(left_sites):
        ax = axes[k // ncol][k % ncol]
        for a in amps:
            if s not in resp_by_amp[a]:
                continue
            r = resp_by_amp[a][s]
            c = colors.get(a, "tab:red")
            ax.fill_between(window, r["median"] - r["sem"], r["median"] + r["sem"],
                            color=c, lw=0, alpha=0.2)
            ax.plot(window, r["median"], c=c, lw=0.9, label=f"amp {a}")
        ax.axhline(0, ls="--", c="k", lw=0.4); ax.axvspan(0, 0.025, color="r", alpha=0.3, lw=0)
        ax.set_ylim(-0.03, 0.05); ax.set_title(f"({s[0]:+.1f}, {s[1]:+.0f})", fontsize=8)
    for k in range(len(left_sites), nrow * ncol):
        axes[k // ncol][k % ncol].set_axis_off()
    axes[0][0].legend(fontsize=7, frameon=False, loc="upper right")
    fig.suptitle(f"{base.SUBJECT} {DATE} - excitatory (left) site dF/F (dodge=amp)")
    fig.supxlabel("time from stim (s)"); fig.supylabel("dF/F")
    fig.tight_layout()
    fig.savefig(OUT / "excit_left_timecourses.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote excit_left_timecourses.png ({len(left_sites)} left sites)")


def excit_left_raster(window, resp_by_amp, cfg):
    """NEW panel: excitatory-LEFT per-site trial x time raster at the highest amp."""
    a = sorted(resp_by_amp)[-1]
    left_sites = sorted({s for s in resp_by_amp[a] if s[0] < 0}, key=lambda s: (s[1], s[0]))
    ncol = 7
    nrow = int(np.ceil(len(left_sites) / ncol))
    fig, axes = plt.subplots(nrow, ncol, figsize=(2.0 * ncol, 1.7 * nrow), squeeze=False)
    im = None
    for k, s in enumerate(left_sites):
        ax = axes[k // ncol][k % ncol]
        dff = resp_by_amp[a][s]["dff"]
        im = ax.imshow(dff, cmap="bwr", clim=(-cfg.RASTER_CLIM, cfg.RASTER_CLIM),
                       aspect="auto", extent=[window[0], window[-1], 0, dff.shape[0]])
        ax.axvspan(0, 0.025, color="k", lw=0, alpha=0.25)
        ax.set_title(f"({s[0]:+.1f}, {s[1]:+.0f})", fontsize=8)
        ax.set_xticks([0, 1]); ax.set_yticks([])
    for k in range(len(left_sites), nrow * ncol):
        axes[k // ncol][k % ncol].set_axis_off()
    cb = fig.colorbar(im, ax=list(axes.ravel()), shrink=0.5,
                      ticks=[-cfg.RASTER_CLIM, cfg.RASTER_CLIM])
    cb.set_label("dF/F")
    cb.ax.set_yticklabels([f"{-cfg.RASTER_CLIM*100:.0f}%", f"{cfg.RASTER_CLIM*100:.0f}%"])
    fig.suptitle(f"{base.SUBJECT} {DATE} - excitatory (left) trial x time raster (amp {a})")
    fig.savefig(OUT / "excit_left_raster.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote excit_left_raster.png ({len(left_sites)} left sites, amp {a})")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    expdir = Path(base.SERVER) / base.SUBJECT / DATE / WF
    print(f"================ {base.SUBJECT} {DATE} (wf {WF} / block {BLOCK}) ================")

    U, mimg, V, svdT, ny, nx = loader.load_svd(expdir, base.N_COMPS)
    gc = calibration.galvo_calib(base.SUBJECT, DATE, base.LASER, BLOCK, base.SERVER, DATA)
    onset_t, pos = loader.derive_onsets_positions(
        expdir, base.LASER, base.LASER_THR, base.DEBOUNCE_S, base.FS_DAQ,
        gc["bregma_offset_x"], gc["bregma_offset_y"], gc["mm_per_v_x"], gc["mm_per_v_y"])
    print(f"  {len(onset_t)} detected {base.LASER} onsets")
    onset_t, pos, _ = loader.segment_onsets(onset_t, pos, base.SEGMENT_GAP_S, SEG)

    onset_amp = loader.block_power_per_onset(onset_t, pos, base.SUBJECT, DATE, BLOCK, base.SERVER)
    lv, ct = np.unique(onset_amp[~np.isnan(onset_amp)], return_counts=True)
    print("  power breakdown:", dict(zip(np.round(lv, 3), ct)))
    fired = [float(a) for a, n in zip(lv, ct) if n >= MIN_ONSETS]
    print("  characterizing amps:", fired)

    U50 = np.asarray(U[:, :, :base.N_COMPS])
    t2svd = analysis.make_t2svd(svdT, V)
    window, base_ix = analysis.trial_window(base.WIN_DUR, base.FS_WIN, base.WIN_PRE)
    early = (window >= base.STIM_WIN[0]) & (window < base.STIM_WIN[1])

    scfg = make_cfg(OUT)
    all_sites = np.unique(pos, axis=0)
    plots.plot_sites(mimg, all_sites, scfg, "all amps")

    focal_by_amp, resp_by_amp = {}, {}
    for amp in fired:
        keep = onset_amp == amp
        o, p = onset_t[keep], pos[keep]
        sites = np.unique(p, axis=0)
        label = f"{amp} power"
        acfg = make_cfg(OUT / f"amp_{amp}")
        acfg.OUTDIR.mkdir(parents=True, exist_ok=True)
        n_left = int((sites[:, 0] < 0).sum())
        print(f"  [amp {amp}] {len(o)} onsets, {len(sites)} sites ({n_left} left/excit), "
              f"{len(o)//max(len(sites),1)} trials/site")

        responses = analysis.compute_site_responses(
            U50, mimg, t2svd, sites, p, o, window, base_ix, acfg)
        plots.plot_timecourses(window, responses, sites, acfg, label)
        plots.plot_tau(responses, sites, acfg, label)
        snapshots = analysis.compute_spatial_snapshots(U50, mimg, t2svd, sites, p, o, acfg)
        plots.plot_spatial(snapshots, sites, acfg, label)
        plots.plot_raster(window, responses, sites, acfg, label)

        focal_by_amp[amp] = {tuple(s): float(responses[(s[0], s[1])]["median"][early].mean())
                             for s in sites}
        resp_by_amp[amp] = {tuple(s): responses[(s[0], s[1])] for s in sites}

    # ---- excitatory-focused NEW panels ----
    excit_focal_map(focal_by_amp, all_sites, scfg)
    excit_left_timecourses(window, resp_by_amp, scfg)
    excit_left_raster(window, resp_by_amp, scfg)

    # ---- dose-response (reuse the pipeline's amp_linearity, written to OUT) ----
    if len(fired) >= 2:
        from run_grid_all import plot_amp_linearity
        plot_amp_linearity(focal_by_amp, fired, scfg)

    # ---- concise excitatory-left findings to stdout ----
    print("\n================ EXCITATORY (left) FINDINGS ================")
    a_hi = fired[-1]
    fb = focal_by_amp[a_hi]
    left = sorted([(s, v) for s, v in fb.items() if s[0] < 0], key=lambda kv: -kv[1])
    print(f"  focal dF/F @ amp {a_hi}, excitatory-left sites (sorted, %):")
    for s, v in left:
        tag = "  <-- responsive" if v > 0.005 else ""
        print(f"    ({s[0]:+.1f}, {s[1]:+.0f})  {v*100:+.2f}%{tag}")
    if len(fired) >= 2:
        a_lo = fired[0]
        xs = np.array([focal_by_amp[a_lo][s] for s, _ in left]) * 100
        ys = np.array([focal_by_amp[a_hi][s] for s, _ in left]) * 100
        good = np.isfinite(xs) & np.isfinite(ys)
        if good.sum() >= 2:
            m, b = np.polyfit(xs[good], ys[good], 1)
            print(f"  excit-left dose-response slope amp{a_lo}->amp{a_hi}: {m:.2f}")
    print("wrote:", OUT)


if __name__ == "__main__":
    main()
