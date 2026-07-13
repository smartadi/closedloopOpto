"""loader.py — read the raw AL_0048 grid session and derive stim onsets / positions.

This session has NO preprocessed laserOnTimes / galvoPositions, so onsets and galvo
positions are derived from the raw 2 kHz Timeline traces using the rig calibration.
These are the reusable primitives new grid analysis should build on.
"""
from pathlib import Path

import numpy as np


def load_svd(expdir, n_comps):
    """Load widefield SVD components for the session.

    Returns U (Y,X,2000) memmap, mimg (Y,X), V (T,n_comps), svdT (T,), ny, nx.
    U is left memory-mapped; callers materialize only the ROI / comps they need.
    """
    U = np.load(Path(expdir) / "blue/svdSpatialComponents.npy", mmap_mode="r")  # (Y,X,2000)
    mimg = np.asarray(np.load(Path(expdir) / "blue/meanImage.npy"))             # (560,560)
    V = np.asarray(np.load(Path(expdir) / "corr/svdTemporalComponents_corr.npy",
                           mmap_mode="r")[:, :n_comps])                          # (T,nSV)
    svdT = np.asarray(
        np.load(Path(expdir) / "corr/svdTemporalComponents_corr.timestamps.npy")).ravel()
    ny, nx = mimg.shape
    return U, mimg, V, svdT, ny, nx


def derive_onsets_positions(expdir, laser, laser_thr, debounce_s, fs_daq,
                            bregma_offset_x, bregma_offset_y, mm_per_v_x, mm_per_v_y):
    """Derive 638 nm stim onsets (s, same clock as SVD timestamps) and snapped galvo
    positions (mm-from-bregma) from the raw Timeline traces.

    Returns (onset_t, pos) where pos[:,0]=x on half-integers, pos[:,1]=y on integers.
    """
    expdir = Path(expdir)
    lc = np.asarray(np.load(expdir / f"lightCommand{laser}.raw.npy")).ravel()
    gx = np.asarray(np.load(expdir / "galvoX.raw.npy")).ravel()
    gy = np.asarray(np.load(expdir / "galvoY.raw.npy")).ravel()

    # rising edges of the light gate, debounced
    edges = np.where(np.diff((lc > laser_thr).astype(np.int8)) == 1)[0] + 1
    onset_ix = [edges[0]]
    for e in edges[1:]:
        if e - onset_ix[-1] > debounce_s * fs_daq:
            onset_ix.append(e)
    onset_ix = np.array(onset_ix)
    onset_t = onset_ix / fs_daq                  # Timeline seconds (same clock as svdT)

    # galvo volts during the 25 ms pulse -> mm -> snap to grid node
    vx = np.array([gx[i + 10:i + 40].mean() for i in onset_ix])
    vy = np.array([gy[i + 10:i + 40].mean() for i in onset_ix])
    mmx = (vx - bregma_offset_x) * mm_per_v_x
    mmy = (vy - bregma_offset_y) * mm_per_v_y
    pos = np.column_stack([np.round(mmx - 0.5) + 0.5,   # x on half-integers (-3.5..3.5)
                           np.round(mmy)])               # y on integers      (-4..3)
    return onset_t, pos


def segment_onsets(onset_t, pos, gap_s, which="last"):
    """Split a Timeline that contains several sequential stim blocks into contiguous
    segments separated by inter-block gaps, and return the requested one.

    When a single widefield/Timeline recording spans multiple Signals runs (e.g.
    AL_0048 2026-07-10 exp 3 holds the two impulse blocks then the grid block), the
    detected onsets form time-contiguous runs separated by minutes of setup. A gap
    larger than `gap_s` seconds marks a block boundary.

    which: 'last' (final segment), 'first', or an int segment index (0-based).
    Returns (onset_t_seg, pos_seg, seg_slice).
    """
    import numpy as _np
    bnd = _np.where(_np.diff(onset_t) > gap_s)[0]        # last idx of each segment but the last
    starts = _np.r_[0, bnd + 1]
    stops = _np.r_[bnd + 1, len(onset_t)]
    segs = list(zip(starts, stops))
    if which == "last":
        i = len(segs) - 1
    elif which == "first":
        i = 0
    else:
        i = int(which)
    s, e = segs[i]
    print(f"  segment_onsets: {len(segs)} segments {[int(b-a) for a, b in segs]}; "
          f"took '{which}' -> [{s}:{e}] = {e - s} onsets")
    return onset_t[s:e], pos[s:e], slice(s, e)


def block_power_per_onset(onset_t, snapped_pos, subject, date, block_exp, server):
    """Assign each Timeline onset its laser power by greedy in-order alignment to the
    session's Block.mat (the authoritative randomized trial log). The galvo position
    sequence is a fingerprint, so detected onsets (a subsequence of all trials) align
    unambiguously. Returns amp per onset (np.nan if no Block)."""
    import scipy.io
    blk = sorted((Path(server) / subject / date / block_exp).glob("*_Block.mat"))
    if not blk:
        print("  [power] no Block.mat in exp", block_exp, "-> power left pooled")
        return np.full(len(onset_t), np.nan)
    b = scipy.io.loadmat(blk[0], squeeze_me=True, struct_as_record=False)["block"]
    ov = b.outputs.opto638Values
    bamp = np.array([float(s.amplitude) for s in ov])
    bx = np.array([float(s.galvoX) for s in ov])
    by = np.array([float(s.galvoY) for s in ov])
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


def select_power(onset_t, pos, amp_sel, subject, date, block_exp, server):
    """Label each onset with its power via Block alignment, then keep only AMP_SEL
    (or pool all if amp_sel is None / no Block). Returns (onset_t, pos, sites, label)."""
    onset_amp = block_power_per_onset(onset_t, pos, subject, date, block_exp, server)
    if not np.isnan(onset_amp).all():
        lv, ct = np.unique(onset_amp[~np.isnan(onset_amp)], return_counts=True)
        print("  power breakdown of detected onsets:", dict(zip(np.round(lv, 2), ct)))
    if amp_sel is not None and not np.isnan(onset_amp).all():
        keep = onset_amp == amp_sel
        onset_t, pos = onset_t[keep], pos[keep]
        label = f"{amp_sel} power"
    else:
        label = "power pooled"
    sites = np.unique(pos, axis=0)
    return onset_t, pos, sites, label
