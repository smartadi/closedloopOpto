#!/usr/bin/env python
"""pixel_probe.py — read out the stim response at ANY pixel, not just the 52 grid nodes.

The stim site must stay on the grid (that is where the laser actually went), but the READOUT
is only an ROI choice, so it can be any pixel. This module turns a clicked pixel into the same
objects the site pipeline produces, so the pair inspector can treat it identically:

    pixel_series()   pixel ROI fluorescence over the whole session   (from the cached SVD)
    trial_response() per-amp single trials + trial mean, same baseline convention as
                     cross_response.build() (one scalar pre-onset baseline over all trials)
    fit_pixel()      per-amp TF fit with split-half CV order selection, on the fly
    snapshot()       full-frame dF/F image for a stim site (the SVD "pixel viewer" display)

Everything reads `svd_cache.load()` — no network. A fit here is over ~50 trials of a single
small ROI, so it is noisier than a site fit: gate on CV-R2 > 0 exactly as elsewhere.
"""
import numpy as np
import scipy.interpolate

import config as cfg
import svd_cache
import tf_fit


# --------------------------------------------------------------------------- #
def pixel_series(sv, cx, cy, rad=None):
    """Fluorescence time-series of the ROI centred on pixel (cx, cy).

    Returns (ts (T,), meta) where ts = V @ mean_ROI(U) + mean_ROI(meanImage) — the same
    construction cross_response.build() uses for the site ROIs, so the two are comparable.
    """
    rad = cfg.ROI_RAD if rad is None else rad
    U, V, mimg = sv["U"], sv["V"], sv["mimg"]
    ny, nx = mimg.shape
    x0, x1 = int(np.clip(cx - rad, 0, nx)), int(np.clip(cx + rad, 0, nx))
    y0, y1 = int(np.clip(cy - rad, 0, ny)), int(np.clip(cy + rad, 0, ny))
    if x1 <= x0 or y1 <= y0:
        raise ValueError(f"ROI at ({cx},{cy}) is outside the {nx}x{ny} image")
    spat = U[y0:y1, x0:x1, :].mean((0, 1)).astype(np.float64)
    mI = float(mimg[y0:y1, x0:x1].mean())
    ts = (V.astype(np.float64) @ spat) + mI
    return ts, dict(box=(x0, x1, y0, y1), mI=mI, rad=rad)


def onsets_for(tz, s_idx, amp):
    """Stim onsets (s) for grid site index `s_idx` at laser amplitude `amp`."""
    pos, sites = tz["pos"], tz["sites"]
    sel = ((pos[:, 0] == sites[s_idx, 0]) & (pos[:, 1] == sites[s_idx, 1])
           & (np.round(tz["onset_amp"], 3) == round(amp, 3)))
    return tz["onset_t"][sel]


def trial_fluo(tz, ts, svdT, s_idx, amp):
    """Raw per-trial ROI fluorescence (nTrials, nWin) — NOT yet dF/F."""
    window = tz["window"]
    these = onsets_for(tz, s_idx, amp)
    if these.size == 0:
        return np.zeros((0, len(window)))
    f = scipy.interpolate.interp1d(svdT, ts, bounds_error=False, fill_value=np.nan)
    return f(window[None, :] + these[:, None])


def _dff(fluo, base_ix):
    """One scalar pre-onset baseline over the trials given — the convention of
    cross_response.build() and tf_fit.split_half_means()."""
    base = np.nanmean(fluo[:, :base_ix])
    return (fluo - base) / base


def trial_response(tz, ts, svdT, s_idx, amp):
    """Single-trial dF/F (nTrials, nWin) + trial mean for stim site -> this pixel ROI."""
    window, base_ix = tz["window"], int(tz["base_ix"])
    fluo = trial_fluo(tz, ts, svdT, s_idx, amp)
    if fluo.size == 0:
        return fluo, np.full(len(window), np.nan)
    dff = _dff(fluo, base_ix)
    return dff, np.nanmean(dff, 0)


def split_half(fluo, base_ix):
    """Even/odd split-half mean dF/F — two INDEPENDENT estimates of the impulse response.

    Each half is baselined with its OWN pre-onset mean, exactly as tf_fit.split_half_means()
    does. Reusing the pooled baseline instead leaves a between-half offset in the halves and
    measurably depresses the CV-R2 (it made a CV-R2 0.92 site pair read 0.27), so the
    convention has to match the cached fits or pixel and site numbers are not comparable.
    """
    a = np.arange(fluo.shape[0]) % 2 == 0
    return tuple(np.nanmean(_dff(fluo[ix], base_ix), 0) for ix in (a, ~a))


def fit_pixel(window, fluo, base_ix):
    """TF fit for one pixel response, with split-half CV order selection.

    Mirrors tf_fit.fit_all_amps' per-pair path: onset-zero the full mean, subtract the SAME
    onset offset from both half-means, then CV-select the order. Returns (fit, h, dff).
    """
    dff = _dff(fluo, base_ix)
    h, off = tf_fit._zero_onset(window, np.nanmean(dff, 0))
    if fluo.shape[0] >= 4:
        hA, hB = split_half(fluo, base_ix)
        if np.all(np.isfinite(hA)) and np.all(np.isfinite(hB)):
            return tf_fit.fit_lti_cv(window, h, hA - off, hB - off), h, dff
    f = tf_fit.fit_lti(window, h)
    f["cvr2"] = np.nan
    return f, h, dff


def snapshot(sv, tz, s_idx, amp, base_win=None, stim_win=None):
    """Full-frame dF/F image evoked by stimulating site `s_idx` at `amp` — the SVD display.

    Mean over `stim_win` minus mean over `base_win` (both s rel. onset), reconstructed from
    the cached basis: image = U @ dV. Same construction as analysis.compute_spatial_snapshots.
    """
    base_win = cfg.BASE_WIN if base_win is None else base_win
    stim_win = cfg.STIM_WIN if stim_win is None else stim_win
    U, V, mimg, svdT = sv["U"], sv["V"], sv["mimg"], sv["svdT"]
    these = onsets_for(tz, s_idx, amp)
    if these.size == 0:
        return np.full(mimg.shape, np.nan)
    t2svd = scipy.interpolate.interp1d(svdT, V.astype(np.float64), axis=0,
                                       bounds_error=False, fill_value=np.nan)
    rb = np.arange(*base_win, 1 / cfg.FS_WIN)
    rs = np.arange(*stim_win, 1 / cfg.FS_WIN)
    base_v = np.nanmean(t2svd(these[:, None] + rb[None, :]), (0, 1))
    stim_v = np.nanmean(t2svd(these[:, None] + rs[None, :]), (0, 1))
    U = U.astype(np.float64)
    base_im = np.einsum("yxc,c->yx", U, base_v) + mimg
    stim_im = np.einsum("yxc,c->yx", U, stim_v) + mimg
    return (stim_im - base_im) / base_im


def px_to_mm(cx, cy):
    """Pixel -> mm-from-bregma, the inverse of analysis.site_px (for labelling a clicked ROI)."""
    return ((cx - cfg.BREGMA_PX[0]) / cfg.PX_PER_MM_X,
            (cy - cfg.BREGMA_PX[1]) / cfg.PX_PER_MM_Y)


def load(strict=True):
    """The cached SVD basis for the current config session."""
    return svd_cache.load(strict=strict)
