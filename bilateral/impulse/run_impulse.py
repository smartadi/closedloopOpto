#!/usr/bin/env python
"""run_impulse.py — dual-opsin bilateral impulse dose-response (AL_0048; session via registry).

Session is chosen in impulse_config.SESSION (registry: 2026-07-10, 2026-07-15). The amp-0
(sham) catch condition is recovered from the Block<->Timeline clock map (impulse_config.
RECOVER_SHAM) and reported as the per-side dose-response origin.

Sub-area of the dual-opsin (bilateral) analysis: runs the impulse-analysis logic (0-200 ms
energy, dose-response, median +/- 95th-pct bounds) on the two-spot single-frame impulse
experiment. Reuses the grid module's raw onset/calibration/SVD primitives.

Run from the repo root or this folder:
    .venv/Scripts/python.exe bilateral/impulse/run_impulse.py
Outputs -> bilateral/impulse/impulse_png/. See impulse/README.md for the handoff.
"""
import numpy as np

import impulse_config as cfg
import impulse_core as core
import impulse_plots as plots
import analysis        # from bilateral/grid (on sys.path via impulse_config)


def main():
    cfg.OUTDIR.mkdir(exist_ok=True)
    S = core.load_session(cfg)
    U, mimg, svdT, V = S["U"], S["mimg"], S["svdT"], S["V"]
    onset_t, amp, side = S["onset_t"], S["amp"], S["side"]

    # counts per amp x side
    for sd in ["left", "right"]:
        m = side == sd
        u, c = np.unique(amp[m], return_counts=True)
        print(f"  {sd}: " + ", ".join(f"{a}:{n}" for a, n in zip(u, c)))

    t2svd = analysis.make_t2svd(svdT, V)
    window = np.arange(-cfg.WIN_PRE, cfg.WIN_POST, 1 / cfg.FS_WIN)
    base_ix = int(np.argmin(np.abs(window)))

    print("  loading U[:, :, :%d] for focal localization ..." % cfg.N_COMPS)
    U50 = np.asarray(U[:, :, :cfg.N_COMPS])

    focal, traces_by_side, energy_by_side, peak_by_side = {}, {}, {}, {}
    for sd, nominal, sign in [("left", cfg.SITE_LEFT, +1), ("right", cfg.SITE_RIGHT, -1)]:
        sel = (side == sd) & (amp == cfg.FOCUS_AMP)
        px, py, dff_im = core.find_focal_pixel(U50, mimg, t2svd, onset_t[sel], nominal, sign, cfg)
        focal[sd] = (px, py, dff_im)
        print(f"  {sd} focal pixel = ({px}, {py})  [nominal galvo {nominal} mm]")

        these = onset_t[side == sd]
        amps_here = amp[side == sd]
        tr = core.site_traces(U, mimg, t2svd, (px, py), these, amps_here, window, base_ix, cfg)
        traces_by_side[sd] = tr
        energy_by_side[sd] = core.energy_per_trial(tr, window, cfg)
        peak_by_side[sd] = core.peak_of_mean_dose(tr, window, cfg, sign)

    # print the dose-response table (both metrics); amp 0.0 = recovered sham catch condition
    print("\n  dose-response  [peak of mean trace (95% CI) | 0-200 ms energy median [pct]]:")
    for sd in ["left", "right"]:
        print(f"  {plots.SIDE_TITLE[sd]}:")
        for a in sorted(peak_by_side[sd].keys()):
            pt, lo, hi = peak_by_side[sd][a]
            en = energy_by_side[sd][a]
            print(f"    amp {a}: peak {pt:+.4f} [{lo:+.4f}, {hi:+.4f}]  |  "
                  f"energy {np.nanmedian(en):+.4f} "
                  f"[{np.nanpercentile(en,2.5):+.4f}, {np.nanpercentile(en,97.5):+.4f}]  n={len(en)}")

    plots.plot_sites(mimg, focal, cfg)
    plots.plot_spatial(focal, cfg)
    plots.plot_traces(window, traces_by_side, cfg)
    plots.plot_peak_dose(peak_by_side, cfg)
    plots.plot_dose_response(energy_by_side, cfg, "0-200 ms mean dF/F (energy)",
                             "impulse_dose_response_energy.png")
    print("\nwrote:", cfg.OUTDIR)


if __name__ == "__main__":
    main()
