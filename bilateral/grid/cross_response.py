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

CACHE = Path(__file__).resolve().parents[2] / "data" / "grid_cross_response.npz"


def build(amp_sel=cfg.AMP_SEL, cache=True):
    """Return (H, sites, window, label). H is (nStim, nReadout, nWin) dF/F medians."""
    U, mimg, V, svdT, ny, nx = loader.load_svd(cfg.EXPDIR, cfg.N_COMPS)
    onset_t, pos = loader.derive_onsets_positions(
        cfg.EXPDIR, cfg.LASER, cfg.LASER_THR, cfg.DEBOUNCE_S, cfg.FS_DAQ,
        cfg.BREGMA_OFFSET_X, cfg.BREGMA_OFFSET_Y, cfg.MM_PER_V_X, cfg.MM_PER_V_Y)
    onset_t, pos, sites, label = loader.select_power(
        onset_t, pos, amp_sel, cfg.SUBJECT, cfg.DATE, cfg.BLOCK_EXP, cfg.SERVER)
    window, base_ix = analysis.trial_window(cfg.WIN_DUR, cfg.FS_WIN, cfg.WIN_PRE)
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

    # for each stim site, interpolate its trials once, then project onto every readout ROI
    H = np.full((nS, nS, nW), np.nan)
    ntri = np.zeros(nS, int)
    for i, (mx, my) in enumerate(sites):
        these = onset_t[(pos[:, 0] == mx) & (pos[:, 1] == my)]
        ntri[i] = len(these)
        tr = t2svd(window[None, :] + these[:, None])          # (nTrials, nW, nSV)
        for j in range(nS):
            fluo = tr @ spat[j] + mI[j]                        # (nTrials, nW)
            base = np.nanmean(fluo[:, :base_ix])
            dff = (fluo - base) / base
            H[i, j] = np.nanmedian(dff, 0)
        print(f"  stim {i+1:2d}/{nS}  site=({mx:+.1f},{my:+.0f})  n={ntri[i]} trials", end="\r")
    print()
    print(f"built H {H.shape}  ({label}; {ntri.min()}-{ntri.max()} trials/site)")

    if cache:
        CACHE.parent.mkdir(exist_ok=True)
        np.savez(CACHE, H=H, sites=sites, window=window, label=label,
                 base_ix=base_ix, ntri=ntri, fs_win=cfg.FS_WIN)
        print("cached ->", CACHE)
    return H, sites, window, label


def load_cached():
    """Load the cached tensor as a dict; raises if not built yet."""
    if not CACHE.exists():
        raise FileNotFoundError(f"{CACHE} missing — run cross_response.py first")
    z = np.load(CACHE, allow_pickle=True)
    return {k: z[k] for k in z.files}


BRAIN_CACHE = CACHE.parent / "grid_brain.npz"


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
    if "brain" in sys.argv:
        cache_brain()
    else:
        build()
