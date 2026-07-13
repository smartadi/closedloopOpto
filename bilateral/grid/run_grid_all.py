#!/usr/bin/env python
"""run_grid_all.py — batch grid analysis across ALL AL_0048 grid sessions, per amplitude.

For every galvo photostim site-grid session we have, this runs the standard site-grid
characterization (`analysis` + `plots`) SEPARATELY FOR EACH FIRED LASER AMPLITUDE and writes
the figures into a per-session / per-amp subfolder tree:

    bilateral/grid/grid_sessions/<date>/grid_sites.png          (registration, amp-independent)
    bilateral/grid/grid_sessions/<date>/amp_linearity.png       (cross-amp, if >=2 amps)
    bilateral/grid/grid_sessions/<date>/amp_<amp>/grid_*.png     (the 5 standard figures)

Reuses the single-session module (config/loader/analysis/calibration/plots) unchanged; the
session/amp loop lives here so `run_grid.py` stays the one-session entry point.

Run from the repo root or this folder:
    .venv/Scripts/python.exe bilateral/grid/run_grid_all.py
Outputs (PNG) are gitignored/regenerable. See grid/README.md for the pipeline.
"""
import types
from pathlib import Path

import numpy as np

import config as base
import loader
import analysis
import calibration
import plots

DATA = Path(__file__).resolve().parents[2] / "data"
OUTROOT = Path(__file__).resolve().parent / "grid_sessions"
MIN_ONSETS = 300          # amps with fewer detected onsets are sub-threshold noise (e.g. the
                          # 2026-06-24 "0.25" = 59 spurious onsets that never lased) -> skipped

# --- grid session registry ------------------------------------------------------------------
# date, WF exp (widefield SVD + Timeline), Block exp (protocol log), onset segment.
# 'seg' = None for single-block Timelines; 'last' when the grid rides a multi-block Timeline
# (2026-07-10 exp 3 also holds the impulse blocks -> take the final onset segment).
# 'bregma' overrides the image-registration bregma pixel if a session needs it (None = base).
SESSIONS = [
    dict(date="2026-06-24", wf="2", block="3", seg=None,   bregma=None),
    dict(date="2026-07-01", wf="4", block="5", seg=None,   bregma=None),
    dict(date="2026-07-10", wf="3", block="6", seg="last", bregma=None),
]


def make_cfg(date, outdir, bregma=None):
    """Per-run config namespace: all session-independent constants from `config`, with DATE /
    OUTDIR (and optionally BREGMA_PX) overridden. analysis/plots read attributes off this."""
    c = types.SimpleNamespace(**{k: getattr(base, k) for k in dir(base) if k.isupper()})
    c.DATE = date
    c.OUTDIR = Path(outdir)
    if bregma is not None:
        c.BREGMA_PX = bregma
    return c


def run_session(sess):
    date, wf, block, seg = sess["date"], sess["wf"], sess["block"], sess["seg"]
    print(f"\n================ {base.SUBJECT} {date} (wf {wf} / block {block}) ================")
    expdir = Path(base.SERVER) / base.SUBJECT / date / wf
    sdir = OUTROOT / date
    sdir.mkdir(parents=True, exist_ok=True)

    # ---- load + derive onsets ----
    U, mimg, V, svdT, ny, nx = loader.load_svd(expdir, base.N_COMPS)
    gc = calibration.galvo_calib(base.SUBJECT, date, base.LASER, block, base.SERVER, DATA)
    onset_t, pos = loader.derive_onsets_positions(
        expdir, base.LASER, base.LASER_THR, base.DEBOUNCE_S, base.FS_DAQ,
        gc["bregma_offset_x"], gc["bregma_offset_y"], gc["mm_per_v_x"], gc["mm_per_v_y"])
    print(f"  {len(onset_t)} detected {base.LASER} onsets")
    if seg is not None:                                 # multi-block Timeline -> grid segment
        onset_t, pos, _ = loader.segment_onsets(onset_t, pos, base.SEGMENT_GAP_S, seg)

    # ---- power label per onset (once) ----
    onset_amp = loader.block_power_per_onset(onset_t, pos, base.SUBJECT, date, block, base.SERVER)
    lv, ct = np.unique(onset_amp[~np.isnan(onset_amp)], return_counts=True)
    print("  power breakdown:", dict(zip(np.round(lv, 3), ct)))
    fired = [float(a) for a, n in zip(lv, ct) if n >= MIN_ONSETS]
    skipped = [(float(a), int(n)) for a, n in zip(lv, ct) if n < MIN_ONSETS]
    if skipped:
        print(f"  skipping sub-threshold amps (< {MIN_ONSETS} onsets): {skipped}")
    print(f"  characterizing amps: {fired}")

    # ---- shared per-session compute state ----
    U50 = np.asarray(U[:, :, :base.N_COMPS])            # materialize once (reused every amp)
    t2svd = analysis.make_t2svd(svdT, V)
    window, base_ix = analysis.trial_window(base.WIN_DUR, base.FS_WIN, base.WIN_PRE)
    scfg = make_cfg(date, sdir, sess["bregma"])
    all_sites = np.unique(pos, axis=0)
    plots.plot_sites(mimg, all_sites, scfg, "all amps")     # registration (amp-independent)

    focal_by_amp = {}                                   # amp -> {site: early-window ROI dF/F}
    early = (window >= base.STIM_WIN[0]) & (window < base.STIM_WIN[1])
    for amp in fired:
        keep = onset_amp == amp
        o, p = onset_t[keep], pos[keep]
        sites = np.unique(p, axis=0)
        label = f"{amp} power"
        acfg = make_cfg(date, sdir / f"amp_{amp}", sess["bregma"])
        acfg.OUTDIR.mkdir(parents=True, exist_ok=True)
        print(f"  [amp {amp}] {len(o)} onsets, {len(sites)} sites, "
              f"{len(o)//max(len(sites),1)} trials/site -> {acfg.OUTDIR.relative_to(OUTROOT.parent)}")

        responses = analysis.compute_site_responses(
            U50, mimg, t2svd, sites, p, o, window, base_ix, acfg)
        plots.plot_timecourses(window, responses, sites, acfg, label)
        plots.plot_tau(responses, sites, acfg, label)
        snapshots = analysis.compute_spatial_snapshots(U50, mimg, t2svd, sites, p, o, acfg)
        plots.plot_spatial(snapshots, sites, acfg, label)
        plots.plot_raster(window, responses, sites, acfg, label)

        focal_by_amp[amp] = {tuple(s): float(responses[(s[0], s[1])]["median"][early].mean())
                             for s in sites}

    if len(fired) >= 2:
        plot_amp_linearity(focal_by_amp, fired, scfg)
    return dict(date=date, fired=fired, skipped=skipped, n_sites=len(all_sites))


def plot_amp_linearity(focal_by_amp, fired, cfg):
    """Cross-amp: each site's early-window focal dF/F at the two lowest/highest amps, colored
    by hemisphere (excitatory left / inhibitory right). A positive, sign-preserving trend =
    graded dose-response; the slope vs the identity line reads out amplitude scaling."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    a0, a1 = fired[0], fired[-1]
    sites = sorted(set(focal_by_amp[a0]) & set(focal_by_amp[a1]))
    x = np.array([focal_by_amp[a0][s] for s in sites]) * 100   # %
    y = np.array([focal_by_amp[a1][s] for s in sites]) * 100
    hemi = np.array([s[0] for s in sites])                     # mx: <0 left/excit, >0 right/inhib
    col = np.where(hemi < 0, "tab:red", "tab:blue")

    fig, ax = plt.subplots(figsize=(4.5, 4.5))
    lim = float(np.nanmax(np.abs(np.r_[x, y]))) * 1.1
    ax.plot([-lim, lim], [-lim, lim], "k--", lw=0.6, label="identity")
    ax.axhline(0, color="k", lw=0.3); ax.axvline(0, color="k", lw=0.3)
    ax.scatter(x[hemi < 0], y[hemi < 0], c="tab:red", s=18, label="left / excitatory")
    ax.scatter(x[hemi > 0], y[hemi > 0], c="tab:blue", s=18, label="right / inhibitory")
    good = np.isfinite(x) & np.isfinite(y)
    if good.sum() >= 2:
        m, b = np.polyfit(x[good], y[good], 1)
        xs = np.array([-lim, lim])
        ax.plot(xs, m * xs + b, color="0.4", lw=1.2, label=f"fit slope={m:.2f}")
    ax.set_xlim(-lim, lim); ax.set_ylim(-lim, lim); ax.set_aspect("equal")
    ax.set_xlabel(f"focal dF/F @ amp {a0} (%)"); ax.set_ylabel(f"focal dF/F @ amp {a1} (%)")
    ax.set_title(f"{cfg.SUBJECT} {cfg.DATE} - per-site amp scaling")
    ax.legend(fontsize=7, frameon=False)
    fig.tight_layout()
    fig.savefig(cfg.OUTDIR / "amp_linearity.png", dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote amp_linearity.png (slope {a0}->{a1})")


def main():
    OUTROOT.mkdir(exist_ok=True)
    summary = [run_session(s) for s in SESSIONS]
    print("\n================ SUMMARY ================")
    for s in summary:
        print(f"  {s['date']}: amps {s['fired']} ({s['n_sites']} sites)"
              + (f"  [skipped {s['skipped']}]" if s['skipped'] else ""))
    print("wrote:", OUTROOT)


if __name__ == "__main__":
    main()
