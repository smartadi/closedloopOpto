"""impulse_core.py — load the AL_0048 impulse block, localize each spot, extract dF/F.

Reuses the grid module's raw-data primitives (onset derivation, galvo calibration, SVD
interpolation) and adds the impulse-specific steps: keep the impulse onset segment, assign
amplitude positionally from block 5's firing trials, find the data-derived focal pixel per
spot, and pull per-trial dF/F + the 0-200 ms energy.
"""
from pathlib import Path

import numpy as np
import scipy.io

import loader          # from bilateral/grid (on sys.path via impulse_config)
import calibration
import analysis


def load_session(cfg):
    """Return a dict with SVD handles, the impulse onsets, per-onset amplitude and side."""
    U, mimg, V, svdT, ny, nx = loader.load_svd(cfg.EXPDIR, cfg.N_COMPS)
    DATA = Path(__file__).resolve().parents[2] / "data"
    gc = calibration.galvo_calib(cfg.SUBJECT, cfg.DATE, cfg.LASER, cfg.CALIB_BLOCK,
                                 cfg.SERVER, DATA)
    onset_t, pos = loader.derive_onsets_positions(
        cfg.EXPDIR, cfg.LASER, cfg.LASER_THR, cfg.DEBOUNCE_S, cfg.FS_DAQ,
        gc["bregma_offset_x"], gc["bregma_offset_y"], gc["mm_per_v_x"], gc["mm_per_v_y"])
    print(f"{cfg.SUBJECT} {cfg.DATE}/{cfg.WF_EXP}: {len(onset_t)} detected {cfg.LASER} onsets")

    # keep the impulse region = everything BEFORE the >gap grid run (the final segment is the
    # grid). This region is block 5's firing onsets, possibly preceded by block-4 false-start
    # pulses; _assign_amp_from_block aligns block 5 from the tail and drops the leading extras.
    ot, pp, _ = loader.segment_onsets(onset_t, pos, cfg.SEGMENT_GAP_S, "first")
    ot, pp, amp, side = _assign_amp_from_block(ot, pp, cfg)
    return dict(U=U, mimg=mimg, V=V, svdT=svdT, ny=ny, nx=nx,
                onset_t=ot, pos=pp, amp=amp, side=side)


def _assign_amp_from_block(onset_t, pos, cfg):
    """Assign each impulse onset its amplitude by positional match to block 5's firing
    (amp>0) trials, validated by galvoX sign. Sham (amp 0) trials fire no laser so they are
    absent from the detected onsets and the firing subsequence maps 1:1, in order.

    Block 5 immediately precedes the grid, so its onsets are the LAST `nb` of the pre-grid
    region; any leading pulses (block-4 false start) are trimmed. Returns the trimmed
    (onset_t, pos, amp, side)."""
    blk = sorted((Path(cfg.SERVER) / cfg.SUBJECT / cfg.DATE / cfg.IMPULSE_BLOCK).glob("*_Block.mat"))
    b = scipy.io.loadmat(blk[0], squeeze_me=True, struct_as_record=False)["block"]
    ov = b.outputs.opto638Values
    bamp = np.array([float(s.amplitude) for s in ov])
    bx = np.array([float(s.galvoX) for s in ov])
    fire = bamp > 0
    famp, fbx = bamp[fire], bx[fire]
    nb = len(famp)
    n = len(onset_t)
    if n < nb:                              # block stopped/ran fewer firing trials than logged
        famp, fbx, nb = famp[:n], fbx[:n], n
    if n > nb:                              # trim leading false-start pulses (block 4)
        print(f"  dropping {n - nb} leading false-start onset(s) (block 4) before block "
              f"{cfg.IMPULSE_BLOCK}")
        onset_t, pos = onset_t[-nb:], pos[-nb:]
    sign_match = float((np.sign(pos[:, 0]) == np.sign(fbx)).mean())
    if sign_match < 0.999:
        raise ValueError(f"galvoX sign match only {sign_match:.3f} — positional alignment unsafe")
    print(f"  block {cfg.IMPULSE_BLOCK}: assigned amp to {nb} onsets (sign match {sign_match:.3f})")
    side = np.where(pos[:, 0] < 0, "left", "right")
    return onset_t, pos, famp, side


def _roi_spat(U, mimg, cx, cy, rad, n_comps):
    """SVD spatial mixing vector + mean fluorescence for a square ROI around (cx, cy)."""
    ny, nx = mimg.shape
    x0, x1 = int(np.clip(cx - rad, 0, nx)), int(np.clip(cx + rad, 0, nx))
    y0, y1 = int(np.clip(cy - rad, 0, ny)), int(np.clip(cy + rad, 0, ny))
    spat = np.asarray(U[y0:y1, x0:x1, :n_comps]).mean((0, 1))
    return spat, mimg[y0:y1, x0:x1].mean()


def find_focal_pixel(U50, mimg, t2svd, these, nominal_mm, want_sign, cfg):
    """Data-derived focal pixel for a spot: the extreme signed dF/F (early stim vs baseline)
    within a search box around the nominal galvo->pixel location. want_sign +1 (excitatory,
    max positive) or -1 (inhibitory, min negative). Returns (px_x, px_y, dff_image)."""
    nx0, ny0 = analysis.site_px(nominal_mm[0], nominal_mm[1], cfg.BREGMA_PX,
                                cfg.PX_PER_MM_X, cfg.PX_PER_MM_Y)
    rb = np.arange(*cfg.SNAP_BASE_WIN, 1 / cfg.FS_WIN)
    rs = np.arange(*cfg.SNAP_STIM_WIN, 1 / cfg.FS_WIN)
    base_v = np.nanmean(t2svd(these[:, None] + rb[None, :]), (0, 1))
    stim_v = np.nanmean(t2svd(these[:, None] + rs[None, :]), (0, 1))
    base_im = np.einsum("yxc,c->yx", U50, base_v) + mimg
    stim_im = np.einsum("yxc,c->yx", U50, stim_v) + mimg
    dff = (stim_im - base_im) / base_im

    ny, nx = mimg.shape
    r = cfg.FOCUS_SEARCH_RAD
    x0, x1 = int(np.clip(nx0 - r, 0, nx)), int(np.clip(nx0 + r, 0, nx))
    y0, y1 = int(np.clip(ny0 - r, 0, ny)), int(np.clip(ny0 + r, 0, ny))
    box = dff[y0:y1, x0:x1] * want_sign
    j, i = np.unravel_index(np.nanargmax(box), box.shape)
    return x0 + i, y0 + j, dff


def site_traces(U, mimg, t2svd, focal_px, onset_t, amp, window, base_ix, cfg):
    """Per-amplitude per-trial dF/F traces at a focal ROI. Returns
    {amp: {dff (nTrials, nWin), mean, sem, median, lo, hi}} using each trial's own
    pre-onset baseline. lo/hi = 2.5th / 97.5th percentile bounds (impulse convention)."""
    spat, mI = _roi_spat(U, mimg, focal_px[0], focal_px[1], cfg.ROI_RAD, cfg.N_COMPS)
    out = {}
    for a in cfg.AMPS:
        these = onset_t[amp == a]
        tr = t2svd(window[None, :] + these[:, None])          # (nTrials, nWin, nSV)
        fluo = tr @ spat + mI
        base = np.nanmean(fluo[:, :base_ix], axis=1, keepdims=True)
        dff = (fluo - base) / base
        out[a] = dict(
            dff=dff,
            mean=np.nanmean(dff, 0), sem=np.nanstd(dff, 0) / np.sqrt(dff.shape[0]),
            median=np.nanmedian(dff, 0),
            lo=np.nanpercentile(dff, 2.5, 0), hi=np.nanpercentile(dff, 97.5, 0),
            n=dff.shape[0])
    return out


def energy_per_trial(traces, window, cfg):
    """Per-amp 0-200 ms mean-dF/F energy across trials. Returns
    {amp: energies (nTrials,)}."""
    m = (window >= cfg.ENERGY_WIN[0]) & (window < cfg.ENERGY_WIN[1])
    return {a: np.nanmean(tr["dff"][:, m], axis=1) for a, tr in traces.items()}


def peak_of_mean_dose(traces, window, cfg, sign, nboot=2000, seed=0):
    """Per-amp signed peak of the TRIAL-MEAN dF/F trace in PEAK_WIN, with a bootstrap 95% CI
    over trials. Unbiased point estimate (unlike median-of-per-trial-peaks, which rectifies
    noise): the peak is taken on the averaged trace, whose noise is ~sqrt(n) smaller.
    sign +1 -> max (excitatory), -1 -> min (inhibitory). Returns {amp: (point, lo, hi)}."""
    m = (window >= cfg.PEAK_WIN[0]) & (window < cfg.PEAK_WIN[1])
    rng = np.random.default_rng(seed)
    out = {}
    for a, tr in traces.items():
        seg = tr["dff"][:, m]
        nT = seg.shape[0]
        point = float(sign * np.nanmax(sign * np.nanmean(seg, 0)))
        boot = np.array([sign * np.nanmax(sign * np.nanmean(seg[rng.integers(0, nT, nT)], 0))
                         for _ in range(nboot)])
        out[a] = (point, float(np.nanpercentile(boot, 2.5)), float(np.nanpercentile(boot, 97.5)))
    return out
