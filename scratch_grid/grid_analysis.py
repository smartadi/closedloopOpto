#!/usr/bin/env python
"""grid_analysis.py - galvo photostim site-grid analysis (opto_brainGrid638), Python.

Cleaned port of scratch_grid/2025-10-29_AL41_grid.ipynb, adapted to AL_0048 2026-06-24/2.
That session's stim info is RAW Timeline (no preprocessed laserOnTimes / galvoPositions_mm),
so onsets + galvo positions are derived from the raw 2 kHz traces using the rig calibration
recorded in session 3's hardwareInfo.json + optoGalvoCalib/.

Dropped vs the notebook (all "probe"/exploration): ipywidgets time-slider, single-site probe,
rastermap, mp4 animation, the unused widefield_deconv.deconvolve, multi-session os.walk.

Deps (in repo .venv): numpy, scipy, matplotlib, colorcet.  Run:  .venv/Scripts/python.exe scratch_grid/grid_analysis.py
Outputs -> scratch_grid/grid_png/: grid_sites.png (Fig0 dial-in), grid_timecourses.png, grid_tau.png
"""
import numpy as np
import scipy.interpolate
import scipy.optimize
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

# ============================== CONFIG ==============================
SUBJECT = "AL_0048"; DATE = "2026-06-24"
WF_EXP  = "2"                 # session holding widefield SVD + raw Timeline traces
BLOCK_EXP = "3"              # paired Signals run: per-trial power/position/order (Block.mat)
SERVER  = r"\\sahale.biostr.washington.edu\data\Subjects"
EXPDIR  = Path(SERVER) / SUBJECT / DATE / WF_EXP

LASER      = "638"           # active laser line (lightCommand638; 594 was idle)
AMP_SEL    = 0.5            # laser power to analyze. NOTE: in this session only the 0.5
                            #   level produced a detectable 638 pulse; the 0.25 level did
                            #   not fire (sub-threshold), so 0.25 yields no trials here.
                            #   Set to None to pool whatever fired.
FS_DAQ     = 2000.0          # Timeline DAQ rate (Hz), from TimelineHW.json
N_COMPS    = 50              # SVD components used (notebook n_comps)
LASER_THR  = 0.3            # V threshold on lightCommand for onset detection
DEBOUNCE_S = 0.06            # min gap between accepted onsets (s)

# galvo volts -> mm-from-bregma  (hardwareInfo.daqController.galvoOpto)
MM_PER_V_X = 1.1111111111111112
MM_PER_V_Y = -1.075268817204301
BREGMA_OFFSET_X = 0.732639223045812
BREGMA_OFFSET_Y = 0.30088318722119456

# mm -> SVD-image pixel.  *** DIAL THESE IN WITH Fig 0 ***
#   bregma_coords.mat ([530, 217]) lives in the 512x640 calibration image, NOT this
#   560x560 SVD frame, so it can't be used directly. Adjust until the Fig 0 markers
#   sit on the stim sites in the mean image.
BREGMA_PX   = (280.0, 250.0) # (x, y) px in the 560x560 meanImage
PX_PER_MM_X =  57.8          # rig scale (from AL_0041 notebook; verify here)
PX_PER_MM_Y = -57.8          # y inverted for image coords
ROI_RAD     = 10             # ROI half-width (px) around each site (notebook roi_around)

# trial window (notebook: arange(0, 1.5, 1/70) - 12/35), seconds relative to onset
FS_WIN    = 70.0
WIN_PRE   = 12 / 35
WIN_DUR   = 1.5
TAU_T0_IX = 32               # first sample used for the exp-rise fit (notebook start_ix)

OUTDIR = Path(__file__).resolve().parent / "grid_png"
OUTDIR.mkdir(exist_ok=True)
# ===================================================================


def block_power_per_onset(onset_t, snapped_pos):
    """Assign each Timeline onset its laser power by greedy in-order alignment to
    session BLOCK_EXP's Block.mat (the authoritative randomized trial log). The galvo
    position sequence is a fingerprint, so the detected onsets (a subsequence of all
    trials) align to the Block unambiguously. Returns amp per onset (np.nan if no Block)."""
    import scipy.io
    blk = sorted((Path(SERVER) / SUBJECT / DATE / BLOCK_EXP).glob("*_Block.mat"))
    if not blk:
        print("  [power] no Block.mat in exp", BLOCK_EXP, "-> power left pooled")
        return np.full(len(onset_t), np.nan)
    b  = scipy.io.loadmat(blk[0], squeeze_me=True, struct_as_record=False)["block"]
    ov = b.outputs.opto638Values
    bamp = np.array([float(s.amplitude) for s in ov])
    bx   = np.array([float(s.galvoX) for s in ov])
    by   = np.array([float(s.galvoY) for s in ov])
    amp, bp = np.full(len(onset_t), np.nan), 0
    for k in range(len(onset_t)):
        adv = 0
        while bp < len(ov) and not (abs(bx[bp] - snapped_pos[k, 0]) < .01
                                    and abs(by[bp] - snapped_pos[k, 1]) < .01):
            bp += 1; adv += 1
            if adv > 300:
                break
        if bp < len(ov):
            amp[k] = bamp[bp]; bp += 1
    return amp


def main():
    # ---- SVD widefield ----
    U    = np.load(EXPDIR / "blue/svdSpatialComponents.npy", mmap_mode="r")     # (Y,X,2000)
    mimg = np.asarray(np.load(EXPDIR / "blue/meanImage.npy"))                   # (560,560)
    V    = np.asarray(np.load(EXPDIR / "corr/svdTemporalComponents_corr.npy",   # (T,nSV)
                              mmap_mode="r")[:, :N_COMPS])
    svdT = np.asarray(np.load(EXPDIR / "corr/svdTemporalComponents_corr.timestamps.npy")).ravel()
    ny, nx = mimg.shape

    # ---- onsets + galvo positions from raw Timeline (2 kHz) ----
    lc = np.asarray(np.load(EXPDIR / f"lightCommand{LASER}.raw.npy")).ravel()
    gx = np.asarray(np.load(EXPDIR / "galvoX.raw.npy")).ravel()
    gy = np.asarray(np.load(EXPDIR / "galvoY.raw.npy")).ravel()

    edges = np.where(np.diff((lc > LASER_THR).astype(np.int8)) == 1)[0] + 1
    onset_ix = [edges[0]]
    for e in edges[1:]:
        if e - onset_ix[-1] > DEBOUNCE_S * FS_DAQ:
            onset_ix.append(e)
    onset_ix = np.array(onset_ix)
    onset_t  = onset_ix / FS_DAQ                       # Timeline seconds (same clock as svdT)

    # galvo volts during the 25 ms pulse -> mm -> snap to grid node
    vx = np.array([gx[i + 10:i + 40].mean() for i in onset_ix])
    vy = np.array([gy[i + 10:i + 40].mean() for i in onset_ix])
    mmx = (vx - BREGMA_OFFSET_X) * MM_PER_V_X
    mmy = (vy - BREGMA_OFFSET_Y) * MM_PER_V_Y
    pos = np.column_stack([np.round(mmx - 0.5) + 0.5,  # x on half-integers (-3.5..3.5)
                           np.round(mmy)])              # y on integers (-4..3)
    print(f"{SUBJECT} {DATE}/{WF_EXP}: {len(onset_ix)} detected 638 onsets")

    # ---- assign laser power per onset via Block alignment, then select AMP_SEL ----
    onset_amp = block_power_per_onset(onset_t, pos)
    if not np.isnan(onset_amp).all():
        lv, ct = np.unique(onset_amp[~np.isnan(onset_amp)], return_counts=True)
        print("  power breakdown of detected onsets:", dict(zip(np.round(lv, 2), ct)))
    if AMP_SEL is not None and not np.isnan(onset_amp).all():
        keep = onset_amp == AMP_SEL
        onset_t, pos = onset_t[keep], pos[keep]
        power_lbl = f"{AMP_SEL} power"
    else:
        power_lbl = "power pooled"
    sites = np.unique(pos, axis=0)
    print(f"  -> {power_lbl}: {len(pos)} onsets, {len(sites)} sites, "
          f"{len(pos)//max(len(sites),1)} trials/site")

    def site_px(mx, my):
        return BREGMA_PX[0] + mx * PX_PER_MM_X, BREGMA_PX[1] + my * PX_PER_MM_Y

    # ---- Fig 0: site overlay (dial in BREGMA_PX / PX_PER_MM here) ----
    fig, ax = plt.subplots(figsize=(4, 4))
    ax.imshow(mimg, cmap="gray"); ax.set_axis_off()
    ax.scatter(*BREGMA_PX, ec="m", fc="none", s=70, lw=1.2)
    sx, sy = site_px(sites[:, 0], sites[:, 1])
    ax.scatter(sx, sy, c="r", s=14, lw=0, alpha=0.5)
    ax.set_title(f"{SUBJECT} {DATE} - verify bregma / sites")
    fig.savefig(OUTDIR / "grid_sites.png", dpi=300, bbox_inches="tight"); plt.close(fig)

    # ---- per-site dF/F timecourses (8x8 grid) ----
    window  = np.arange(0, WIN_DUR, 1 / FS_WIN) - WIN_PRE
    base_ix = int(np.argmin(np.abs(window)))
    t2svd   = scipy.interpolate.interp1d(svdT, V, axis=0, bounds_error=False, fill_value=np.nan)

    def exp_rise(t, a, tau, off):
        return a * (1 - np.exp(-t / tau)) + off

    taus = {}
    fig = plt.figure(figsize=(8, 8))
    gs  = fig.add_gridspec(8, 8, wspace=0.3, hspace=0.3)
    for mx, my in sites:
        sel   = (pos[:, 0] == mx) & (pos[:, 1] == my)
        these = onset_t[sel]
        cx, cy = site_px(mx, my)
        x0, x1 = int(np.clip(cx - ROI_RAD, 0, nx)), int(np.clip(cx + ROI_RAD, 0, nx))
        y0, y1 = int(np.clip(cy - ROI_RAD, 0, ny)), int(np.clip(cy + ROI_RAD, 0, ny))
        spat = np.asarray(U[y0:y1, x0:x1, :N_COMPS]).mean((0, 1))   # [nSV]
        mI   = mimg[y0:y1, x0:x1].mean()

        tr   = t2svd(window[None, :] + these[:, None])              # (nTrials,nWin,nSV)
        fluo = tr @ spat + mI
        base = np.nanmean(fluo[:, :base_ix])
        dff  = (fluo - base) / base
        m    = np.nanmedian(dff, 0)
        sem  = np.nanstd(dff, 0) / np.sqrt(dff.shape[0])

        r, c = int(round(3 - my)), int(round(mx + 3.5))            # 8x8 layout
        ax = fig.add_subplot(gs[r, c])
        ax.fill_between(window, m - sem, m + sem, color="dodgerblue", lw=0, alpha=0.3)
        ax.plot(window, m, c="dodgerblue", lw=0.5)
        ax.axhline(0, ls="--", c="k", lw=0.4)
        ax.set_ylim(-0.03, 0.03); ax.set_axis_off()

        try:
            p, _ = scipy.optimize.curve_fit(
                exp_rise, window[TAU_T0_IX:], m[TAU_T0_IX:], p0=[0.02, 0.1, 0],
                bounds=([0, 0, -np.inf], [0.1, 0.5, np.inf]))
            taus[(mx, my)] = p[1]
            ax.plot(window[TAU_T0_IX:], exp_rise(window[TAU_T0_IX:], *p),
                    c="orange", lw=0.7, ls="--")
        except Exception:
            taus[(mx, my)] = np.nan
    fig.suptitle(f"{SUBJECT} {DATE} - dF/F per site ({LASER} nm, {power_lbl})")
    fig.savefig(OUTDIR / "grid_timecourses.png", dpi=300, bbox_inches="tight"); plt.close(fig)

    # ---- tau spatial map ----
    try:
        import colorcet  # noqa: F401  (registers cet_* colormaps)
        cmap = "cet_CET_L4"
    except Exception:
        cmap = "viridis"
    tv = np.array([taus[(s[0], s[1])] for s in sites])
    fig, ax = plt.subplots(figsize=(4, 4)); ax.set_aspect("equal"); ax.set_axis_off()
    sc = ax.scatter(sites[:, 0], sites[:, 1], c=tv, s=120, ec="k", cmap=cmap, vmin=0, vmax=0.2)
    cb = fig.colorbar(sc, ax=ax, shrink=0.7); cb.set_label(r"$\tau$ (s)")
    ax.set_title(f"{SUBJECT} {DATE} - rise " + r"$\tau$" + f" ({power_lbl})")
    fig.savefig(OUTDIR / "grid_tau.png", dpi=300, bbox_inches="tight"); plt.close(fig)

    print("wrote:", OUTDIR)


if __name__ == "__main__":
    main()
