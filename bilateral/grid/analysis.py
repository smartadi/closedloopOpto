"""analysis.py — per-site dF/F extraction, rise-tau fit, spatial snapshots.

Pure computation: takes loaded data + config, returns structured results that the
plotting module renders. No file I/O, no figures here.
"""
import numpy as np
import scipy.interpolate
import scipy.optimize


def make_t2svd(svdT, V):
    """Interpolator mapping query times -> SVD temporal components (NaN outside range)."""
    return scipy.interpolate.interp1d(svdT, V, axis=0, bounds_error=False,
                                      fill_value=np.nan)


def site_px(mx, my, bregma_px, px_per_mm_x, px_per_mm_y):
    """mm-from-bregma -> pixel (x, y) in the meanImage. Scalar or array."""
    return bregma_px[0] + mx * px_per_mm_x, bregma_px[1] + my * px_per_mm_y


def trial_window(win_dur, fs_win, win_pre):
    """Per-trial time axis (s rel. onset) and the baseline-sample index."""
    window = np.arange(0, win_dur, 1 / fs_win) - win_pre
    base_ix = int(np.argmin(np.abs(window)))
    return window, base_ix


def _exp_rise(t, a, tau, off):
    return a * (1 - np.exp(-t / tau)) + off


def compute_site_responses(U, mimg, t2svd, sites, pos, onset_t, window, base_ix, cfg):
    """Per-site ROI dF/F time courses + exponential rise-tau fits.

    Returns dict {(mx, my): {dff, median, sem, tau, fit_t, fit_y}} where dff is
    (nTrials, nWin). Faithful to the monolith's timecourse loop.
    """
    ny, nx = mimg.shape
    out = {}
    for mx, my in sites:
        sel = (pos[:, 0] == mx) & (pos[:, 1] == my)
        these = onset_t[sel]
        cx, cy = site_px(mx, my, cfg.BREGMA_PX, cfg.PX_PER_MM_X, cfg.PX_PER_MM_Y)
        x0, x1 = int(np.clip(cx - cfg.ROI_RAD, 0, nx)), int(np.clip(cx + cfg.ROI_RAD, 0, nx))
        y0, y1 = int(np.clip(cy - cfg.ROI_RAD, 0, ny)), int(np.clip(cy + cfg.ROI_RAD, 0, ny))
        spat = np.asarray(U[y0:y1, x0:x1, :cfg.N_COMPS]).mean((0, 1))   # [nSV]
        mI = mimg[y0:y1, x0:x1].mean()

        tr = t2svd(window[None, :] + these[:, None])                   # (nTrials,nWin,nSV)
        fluo = tr @ spat + mI
        base = np.nanmean(fluo[:, :base_ix])
        dff = (fluo - base) / base
        m = np.nanmedian(dff, 0)
        sem = np.nanstd(dff, 0) / np.sqrt(dff.shape[0])

        tau, fit_t, fit_y = np.nan, None, None
        try:
            p, _ = scipy.optimize.curve_fit(
                _exp_rise, window[cfg.TAU_T0_IX:], m[cfg.TAU_T0_IX:], p0=[0.02, 0.1, 0],
                bounds=([0, 0, -np.inf], [0.1, 0.5, np.inf]))
            tau = p[1]
            fit_t = window[cfg.TAU_T0_IX:]
            fit_y = _exp_rise(fit_t, *p)
        except Exception:
            pass

        out[(mx, my)] = dict(dff=dff, median=m, sem=sem, tau=tau, fit_t=fit_t, fit_y=fit_y)
    return out


def compute_spatial_snapshots(U, mimg, t2svd, sites, pos, onset_t, cfg):
    """Full-frame dF/F image per site (early response vs baseline window).

    Returns dict {(mx, my): dff_im (Y,X)}. Materializes U[:, :, :N_COMPS] once.
    """
    print("  loading U[:, :, :%d] for spatial maps ..." % cfg.N_COMPS)
    U50 = np.asarray(U[:, :, :cfg.N_COMPS])                            # (Y,X,nSV)
    rb = np.arange(*cfg.BASE_WIN, 1 / cfg.FS_WIN)
    rs = np.arange(*cfg.STIM_WIN, 1 / cfg.FS_WIN)
    out = {}
    for mx, my in sites:
        these = onset_t[(pos[:, 0] == mx) & (pos[:, 1] == my)]
        base_v = np.nanmean(t2svd(these[:, None] + rb[None, :]), (0, 1))   # [nSV]
        stim_v = np.nanmean(t2svd(these[:, None] + rs[None, :]), (0, 1))
        base_im = np.einsum("yxc,c->yx", U50, base_v) + mimg
        stim_im = np.einsum("yxc,c->yx", U50, stim_v) + mimg
        out[(mx, my)] = (stim_im - base_im) / base_im
    return out
