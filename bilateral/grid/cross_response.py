"""cross_response.py — build & cache the stim x readout x time response tensor.

For every stim site s (input = laser at s) and readout ROI r (output = dF/F at r),
compute the trial-averaged dF/F response H[s, r, t]. Because the 25 ms pulse is shorter
than one 35 Hz frame, H[s, r, :] is the empirical IMPULSE RESPONSE from s -> r — the
spatiotemporal Green's function probed one input at a time.

This is the foundation for the TF fitting (tf_fit.py) and the network model. One SVD pass
builds the whole 52x52 tensor; it caches to data/grid_cross_response.npz so downstream
modelling iterates without re-reading the ~1.5 GB SVD over the network.

Run:
    .venv/Scripts/python.exe bilateral/grid/cross_response.py
"""
from pathlib import Path

import numpy as np

import config as cfg
import loader
import analysis
import calibration

CACHE = Path(__file__).resolve().parents[2] / "data" / "grid_cross_response.npz"


def build(amp_sel=cfg.AMP_SEL, win=None, cache=True):
    """Return (H, sites, window, label). H is (nStim, nReadout, nWin) trial-mean dF/F.
    `win` = (t0, t1) seconds rel. onset (default cfg.CROSS_WIN)."""
    U, mimg, V, svdT, ny, nx = loader.load_svd(cfg.EXPDIR, cfg.N_COMPS)
    gc = calibration.galvo_calib(cfg.SUBJECT, cfg.DATE, cfg.LASER, cfg.BLOCK_EXP,
                                 cfg.SERVER, CACHE.parent)
    onset_t, pos = loader.derive_onsets_positions(
        cfg.EXPDIR, cfg.LASER, cfg.LASER_THR, cfg.DEBOUNCE_S, cfg.FS_DAQ,
        gc["bregma_offset_x"], gc["bregma_offset_y"], gc["mm_per_v_x"], gc["mm_per_v_y"])
    onset_t, pos, sites, label = loader.select_power(
        onset_t, pos, amp_sel, cfg.SUBJECT, cfg.DATE, cfg.BLOCK_EXP, cfg.SERVER)
    t0, t1 = win if win is not None else cfg.CROSS_WIN
    window = np.arange(t0, t1, 1.0 / cfg.FS_WIN)
    base_ix = int(np.argmin(np.abs(window)))
    print(f"window {t0:+.2f}..{t1:+.2f}s @ {cfg.FS_WIN:.0f}Hz -> {len(window)} samples, base_ix={base_ix}")
    t2svd = analysis.make_t2svd(svdT, V)
    nS, nW = len(sites), len(window)

    # readout ROI spatial mask (SVD weights) + mean-image offset, one per site
    spat = np.zeros((nS, cfg.N_COMPS))
    mI = np.zeros(nS)
    for j, (mx, my) in enumerate(sites):
        cx, cy = analysis.site_px(mx, my, cfg.BREGMA_PX, cfg.PX_PER_MM_X, cfg.PX_PER_MM_Y)
        x0, x1 = int(np.clip(cx - cfg.ROI_RAD, 0, nx)), int(np.clip(cx + cfg.ROI_RAD, 0, nx))
        y0, y1 = int(np.clip(cy - cfg.ROI_RAD, 0, ny)), int(np.clip(cy + cfg.ROI_RAD, 0, ny))
        spat[j] = np.asarray(U[y0:y1, x0:x1, :cfg.N_COMPS]).mean((0, 1))
        mI[j] = mimg[y0:y1, x0:x1].mean()

    # for each stim site, interpolate its trials once, then project onto every readout ROI.
    # H = trial MEAN; Hstd = trial STD (for ±2 SD shading); Hsem = ±SEM.
    H = np.full((nS, nS, nW), np.nan)
    Hsem = np.full((nS, nS, nW), np.nan)
    Hstd = np.full((nS, nS, nW), np.nan)
    ntri = np.zeros(nS, int)
    for i, (mx, my) in enumerate(sites):
        these = onset_t[(pos[:, 0] == mx) & (pos[:, 1] == my)]
        ntri[i] = len(these)
        tr = t2svd(window[None, :] + these[:, None])          # (nTrials, nW, nSV)
        for j in range(nS):
            fluo = tr @ spat[j] + mI[j]                        # (nTrials, nW)
            base = np.nanmean(fluo[:, :base_ix])
            dff = (fluo - base) / base
            H[i, j] = np.nanmean(dff, 0)
            Hstd[i, j] = np.nanstd(dff, 0)
            Hsem[i, j] = Hstd[i, j] / np.sqrt(dff.shape[0])
        print(f"  stim {i+1:2d}/{nS}  site=({mx:+.1f},{my:+.0f})  n={ntri[i]} trials", end="\r")
    print()
    print(f"built H {H.shape}  ({label}; {ntri.min()}-{ntri.max()} trials/site; trial MEAN/STD/SEM)")

    # per-ROI full time-series (SVD-rate) so single trials for ANY (stim,readout) pair can
    # be reconstructed later with no network read (drives the trials viewer + avg check).
    roi_ts = (V @ spat.T) + mI[None, :]                       # (T, nS)

    if cache:
        CACHE.parent.mkdir(exist_ok=True)
        np.savez(CACHE, H=H, Hsem=Hsem, Hstd=Hstd, sites=sites, window=window, label=label,
                 base_ix=base_ix, ntri=ntri, fs_win=cfg.FS_WIN)
        print("cached ->", CACHE)
        np.savez(TRIALS_CACHE, roi_ts=roi_ts.astype(np.float32), svdT=svdT, onset_t=onset_t,
                 pos=pos, sites=sites, window=window, base_ix=base_ix)
        print(f"cached -> {TRIALS_CACHE}  (roi_ts {roi_ts.shape})")
    return H, sites, window, label


def load_cached():
    """Load the cached tensor as a dict; raises if not built yet."""
    if not CACHE.exists():
        raise FileNotFoundError(f"{CACHE} missing — run cross_response.py first")
    z = np.load(CACHE, allow_pickle=True)
    return {k: z[k] for k in z.files}


BRAIN_CACHE = CACHE.parent / "grid_brain.npz"
TRIALS_CACHE = CACHE.parent / "grid_trials.npz"


def extract_trials(roi_ts, svdT, onset_t, pos, sites, window, base_ix, s_idx, r_idx):
    """Reconstruct the individual single-trial dF/F for stim site s_idx, readout r_idx.
    Returns (dff, mean) where dff is (nTrials, nWin). Mean reproduces the cached H[s,r]
    exactly (same scalar baseline convention), which is the averaging sanity check."""
    import scipy.interpolate
    these = onset_t[(pos[:, 0] == sites[s_idx, 0]) & (pos[:, 1] == sites[s_idx, 1])]
    f = scipy.interpolate.interp1d(svdT, roi_ts[:, r_idx], bounds_error=False, fill_value=np.nan)
    fluo = f(window[None, :] + these[:, None])                # (nTrials, nWin)
    base = np.nanmean(fluo[:, :base_ix])
    dff = (fluo - base) / base
    return dff, np.nanmean(dff, 0)


def load_trials():
    if not TRIALS_CACHE.exists():
        raise FileNotFoundError(f"{TRIALS_CACHE} missing — run cross_response.py first")
    z = np.load(TRIALS_CACHE, allow_pickle=True)
    return {k: z[k] for k in z.files}


def cache_brain():
    """Fetch the mean image (small — not the SVD) + each site's true pixel coords and
    inter-site pixel spacing, cache to data/grid_brain.npz for the spatial viewer."""
    z = load_cached()
    sites = z["sites"]
    mimg = np.asarray(np.load(cfg.EXPDIR / "blue/meanImage.npy"))   # (ny, nx), ~1 MB
    ny, nx = mimg.shape
    px = np.array([analysis.site_px(mx, my, cfg.BREGMA_PX, cfg.PX_PER_MM_X, cfg.PX_PER_MM_Y)
                   for mx, my in sites])                            # (nS, 2) = (cx, cy)
    sp = float(abs(cfg.PX_PER_MM_X))                                # px per 1 mm grid step
    np.savez(BRAIN_CACHE, mimg=mimg, px=px, sp=sp, ny=ny, nx=nx, sites=sites)
    print(f"cached brain image {mimg.shape} + {len(px)} site coords -> {BRAIN_CACHE}")


if __name__ == "__main__":
    import sys
    argv = sys.argv
    if "brain" in argv:
        cache_brain()
    else:
        win = None
        if "--win" in argv:
            i = argv.index("--win"); win = (float(argv[i + 1]), float(argv[i + 2]))
        build(win=win)
