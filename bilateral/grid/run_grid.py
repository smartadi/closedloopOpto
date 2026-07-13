#!/usr/bin/env python
"""run_grid.py — entry point for the AL_0048 galvo photostim site-grid analysis.

Wires config -> loader -> analysis -> plots. Maps the cortical dF/F response evoked by
638 nm optogenetic stimulation at each of 52 galvo grid positions (dual-opsin: excitatory
left / inhibitory right). Reads the raw session live from the sahale share.

Run from the repo root (so the .venv is found) or from this folder:
    .venv/Scripts/python.exe bilateral/grid/run_grid.py
Outputs -> bilateral/grid/grid_png/. See grid/README.md for the full handoff.
"""
import config as cfg
import loader
import analysis
import calibration
import plots

from pathlib import Path
DATA = Path(__file__).resolve().parents[2] / "data"


def main():
    cfg.OUTDIR.mkdir(exist_ok=True)

    # ---- load + derive onsets/positions ----
    U, mimg, V, svdT, ny, nx = loader.load_svd(cfg.EXPDIR, cfg.N_COMPS)
    gc = calibration.galvo_calib(cfg.SUBJECT, cfg.DATE, cfg.LASER, cfg.BLOCK_EXP, cfg.SERVER, DATA)
    onset_t, pos = loader.derive_onsets_positions(
        cfg.EXPDIR, cfg.LASER, cfg.LASER_THR, cfg.DEBOUNCE_S, cfg.FS_DAQ,
        gc["bregma_offset_x"], gc["bregma_offset_y"], gc["mm_per_v_x"], gc["mm_per_v_y"])
    print(f"{cfg.SUBJECT} {cfg.DATE}/{cfg.WF_EXP}: {len(onset_t)} detected {cfg.LASER} onsets")

    # ---- multi-block Timeline: keep only this block's onset segment ----
    if getattr(cfg, "ONSET_SEGMENT", None) is not None:
        onset_t, pos, _ = loader.segment_onsets(onset_t, pos, cfg.SEGMENT_GAP_S, cfg.ONSET_SEGMENT)

    # ---- power select via Block alignment ----
    onset_t, pos, sites, label = loader.select_power(
        onset_t, pos, cfg.AMP_SEL, cfg.SUBJECT, cfg.DATE, cfg.BLOCK_EXP, cfg.SERVER)
    print(f"  -> {label}: {len(pos)} onsets, {len(sites)} sites, "
          f"{len(pos)//max(len(sites),1)} trials/site")

    # ---- compute ----
    window, base_ix = analysis.trial_window(cfg.WIN_DUR, cfg.FS_WIN, cfg.WIN_PRE)
    t2svd = analysis.make_t2svd(svdT, V)
    responses = analysis.compute_site_responses(
        U, mimg, t2svd, sites, pos, onset_t, window, base_ix, cfg)

    # ---- plot ----
    plots.plot_sites(mimg, sites, cfg, label)
    plots.plot_timecourses(window, responses, sites, cfg, label)
    plots.plot_tau(responses, sites, cfg, label)
    if cfg.SPATIAL_SNAPSHOT:
        snapshots = analysis.compute_spatial_snapshots(U, mimg, t2svd, sites, pos, onset_t, cfg)
        plots.plot_spatial(snapshots, sites, cfg, label)
    if cfg.RASTER:
        plots.plot_raster(window, responses, sites, cfg, label)

    print("wrote:", cfg.OUTDIR)


if __name__ == "__main__":
    main()
