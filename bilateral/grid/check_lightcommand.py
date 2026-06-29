#!/usr/bin/env python
"""check_lightcommand.py — interactive, zoomable view of the raw laser-gate traces.

Opens a matplotlib WINDOW (with the pan/zoom toolbar) instead of saving a PNG, so you
can box-zoom into any 638 nm pulse and confirm which commanded trials actually fired.
Loads only the light-command + galvo + Block log (no SVD) -> ready in a few seconds.

Run from the repo root:
    .venv/Scripts/python.exe bilateral/grid/check_lightcommand.py

In the window:
    magnifier icon = box-zoom (drag a rectangle) | cross-arrows = pan
    house icon     = reset view                  | disk icon  = save current view as PNG
    (you can also right-drag with the zoom tool to zoom x/y independently)
"""
import sys
from pathlib import Path

import numpy as np
import scipy.io

import matplotlib
# Force an interactive backend (don't fall through to the non-GUI 'Agg').
for _bk in ("TkAgg", "QtAgg", "Qt5Agg"):
    try:
        matplotlib.use(_bk); break
    except Exception:
        continue
import matplotlib.pyplot as plt

sys.path.insert(0, str(Path(__file__).resolve().parent))
import config as cfg
import loader


def main():
    print("matplotlib backend:", matplotlib.get_backend())
    exp = cfg.EXPDIR
    lc = np.asarray(np.load(exp / f"lightCommand{cfg.LASER}.raw.npy")).ravel()
    lc594 = np.asarray(np.load(exp / "lightCommand594.raw.npy")).ravel()
    fs = cfg.FS_DAQ
    t = np.arange(lc.size) / fs

    # detected onsets (from the trace itself) + Block->Timeline offset
    onset_t, pos = loader.derive_onsets_positions(
        exp, cfg.LASER, cfg.LASER_THR, cfg.DEBOUNCE_S, fs,
        cfg.BREGMA_OFFSET_X, cfg.BREGMA_OFFSET_Y, cfg.MM_PER_V_X, cfg.MM_PER_V_Y)
    blk = sorted((Path(cfg.SERVER) / cfg.SUBJECT / cfg.DATE / cfg.BLOCK_EXP).glob("*_Block.mat"))[0]
    b = scipy.io.loadmat(blk, squeeze_me=True, struct_as_record=False)["block"]
    ov = b.outputs.opto638Values
    bamp = np.array([float(s.amplitude) for s in ov])
    bx = np.array([float(s.galvoX) for s in ov])
    by = np.array([float(s.galvoY) for s in ov])
    otimes = np.atleast_1d(b.outputs.opto638Times).astype(float)
    mi, bp = [], 0
    for k in range(len(onset_t)):
        adv = 0
        while bp < len(ov) and not (abs(bx[bp] - pos[k, 0]) < .01 and abs(by[bp] - pos[k, 1]) < .01):
            bp += 1; adv += 1
            if adv > 300:
                break
        if bp < len(ov):
            mi.append(bp); bp += 1
    offset = np.median(onset_t - otimes[np.array(mi)])
    planned = otimes + offset
    is05, is025 = bamp == 0.5, bamp == 0.25
    print(f"offset={offset:.2f}s  638 fired {len(onset_t)}/{len(otimes)} planned")

    fig, ax = plt.subplots(figsize=(13, 5))
    ax.plot(t, lc, lw=0.6, c="k", label="lightCommand638 (raw)")
    ax.plot(t, lc594, lw=0.6, c="purple", label="lightCommand594 (raw)")
    ax.vlines(planned[is05], -0.05, 1.5, color="g", lw=0.6, alpha=0.35)
    ax.vlines(planned[is025], -0.05, 1.5, color="r", lw=0.6, alpha=0.35)
    ax.plot(onset_t, np.full_like(onset_t, 1.45), "v", c="b", ms=4, label="detected pulse")
    ax.plot([], [], c="g", label="commanded 0.5")
    ax.plot([], [], c="r", label="commanded 0.25")
    ax.axhline(cfg.LASER_THR, ls="--", c="r", lw=0.8, label=f"{cfg.LASER_THR} V threshold")
    ax.set_xlabel("Timeline time (s)")
    ax.set_ylabel("V")
    ax.set_title(f"{cfg.SUBJECT} {cfg.DATE} — raw laser gates (zoom in to confirm). "
                 f"638 fired {len(onset_t)}/{len(otimes)}; green=0.5, red=0.25 commanded")
    ax.legend(loc="upper right", fontsize=8)
    fig.tight_layout()
    plt.show()   # blocks until you close the window


if __name__ == "__main__":
    main()
