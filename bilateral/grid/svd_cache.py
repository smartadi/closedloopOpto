#!/usr/bin/env python
"""svd_cache.py — cache the session's SVD basis locally so ANY pixel can be probed offline.

The grid pipeline's other caches are ROI-based: `cross_response.py` projects the SVD onto the
52 site ROIs and stores only those time-series. That fixes the readout to the 52 stim nodes.
To read out at an ARBITRARY pixel we need the spatial basis itself, so this module does one
network pass and stores:

    U     (ny, nx, N_COMPS)  float32   spatial components   ~63 MB at 560x560x50
    V     (T,  N_COMPS)      float32   temporal components  ~41 MB at T=203k
    svdT  (T,)               float64   frame times, SAME clock as the stim onsets
    mimg  (ny, nx)           float32   mean image

Any pixel's fluorescence is then  V @ U[y, x, :] + mimg[y, x]  with no further network reads.

The cache is STAMPED with subject/date/exp/n_comps and `load()` refuses a cache that does not
match the current `config.py` — the single-amp/2-amp cache mix-up of 2026-07-27 was exactly
this failure mode (a stale cache silently answering for a different session).

Build:  .venv/Scripts/python.exe bilateral/grid/svd_cache.py
        (a few minutes: U is stored (Y,X,2000) with the component axis last, so taking the
         first N_COMPS is a strided read over the whole file.)
"""
from pathlib import Path

import numpy as np

import config as cfg
import loader

DATA = Path(__file__).resolve().parents[2] / "data"


def cache_path(subject=None, date=None, n=None):
    subject = cfg.SUBJECT if subject is None else subject
    date = cfg.DATE if date is None else date
    n = cfg.N_COMPS if n is None else n
    return DATA / f"grid_svd_{subject}_{date}_n{n}.npz"


def build(cache=True):
    """One network pass -> local SVD basis for the session named in config.py."""
    U, mimg, V, svdT, ny, nx = loader.load_svd(cfg.EXPDIR, cfg.N_COMPS)
    print(f"materializing U[:, :, :{cfg.N_COMPS}] from {cfg.EXPDIR} ...")
    U50 = np.asarray(U[:, :, :cfg.N_COMPS], dtype=np.float32)
    V = np.asarray(V, dtype=np.float32)
    mimg = np.asarray(mimg, dtype=np.float32)
    out = dict(U=U50, V=V, svdT=np.asarray(svdT), mimg=mimg,
               subject=cfg.SUBJECT, date=cfg.DATE, wf_exp=str(cfg.WF_EXP),
               n_comps=cfg.N_COMPS)
    if cache:
        DATA.mkdir(exist_ok=True)
        p = cache_path()
        np.savez(p, **out)
        print(f"cached -> {p.name}  U{U50.shape} V{V.shape} "
              f"({p.stat().st_size / 1e6:.0f} MB)")
    return out


def load(strict=True):
    """Load the cache for the CURRENT config session. `strict` refuses a mismatched stamp."""
    p = cache_path()
    if not p.exists():
        raise FileNotFoundError(
            f"{p.name} missing — build it with:\n"
            f"  .venv/Scripts/python.exe bilateral/grid/svd_cache.py")
    z = np.load(p, allow_pickle=True)
    d = {k: z[k] for k in z.files}
    stamp = (str(d.get("subject")), str(d.get("date")), int(d.get("n_comps", -1)))
    want = (cfg.SUBJECT, cfg.DATE, cfg.N_COMPS)
    if stamp != want:
        msg = f"SVD cache is {stamp}, config wants {want}"
        if strict:
            raise ValueError(msg + " — rebuild with `python svd_cache.py`")
        print("[warn]", msg)
    return d


if __name__ == "__main__":
    build()
