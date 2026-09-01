"""Synthetic session fixtures for testing the port without real 40 GB caches.

Two uses:
  * make_synthetic_session(...)   -> an in-memory Session (fast panel tests)
  * write_synthetic_cache(path,s) -> an HDF5 file mimicking MATLAB's -v7.3
                                     layout (arrays stored transposed, structs
                                     as groups), so io.load_session is exercised
                                     against a file in the real on-disk format.

Signals are shaped so open-loop tracks the -5% reference worse (positive bias,
higher cross-trial variance) than closed-loop — matching the paper's claim — so
the panels render something meaningful.
"""
from __future__ import annotations

import numpy as np

from . import style
from .io import Session


def _mean_traj(t, steady):
    """Smooth response: 0 pre-stim, exp approach to `steady` during [0,dur], decay after."""
    y = np.zeros_like(t)
    stim = (t >= 0) & (t <= style.DUR)
    y[stim] = steady * (1 - np.exp(-t[stim] / 0.4))
    post = t > style.DUR
    y_end = steady * (1 - np.exp(-style.DUR / 0.4))
    y[post] = y_end * np.exp(-(t[post] - style.DUR) / 0.5)
    return y


def make_synthetic_session(name="synth", seed=0, n_ol=50, n_cl=50) -> Session:
    rng = np.random.default_rng(seed)
    t = (np.arange(561) - style.PNCDFK_ONSET) / style.FS   # -10..+6 s
    stim = (t >= 0) & (t <= style.DUR)

    # Open-loop: undershoots the -5 target (~-3.2 steady) with large trial spread.
    ol_mean = _mean_traj(t, steady=-3.2)
    # Closed-loop: reaches the -5 target with smaller spread.
    cl_mean = _mean_traj(t, steady=-5.0)

    def build(mean, n, offset_sd, noise_sd):
        # per-trial constant brain-state offset (bigger for OL) + timepoint noise,
        # both amplified during the stim window.
        offs = rng.normal(0, offset_sd, size=(n, 1))
        noise = rng.normal(0, noise_sd, size=(n, 561))
        amp = np.where(stim, 1.0, 0.35)             # quieter outside stim
        return mean[None, :] + offs * amp[None, :] + noise * amp[None, :]

    pncDfk = build(ol_mean, n_ol, offset_sd=2.4, noise_sd=1.3)
    pwcDfk = build(cl_mean, n_cl, offset_sd=1.0, noise_sd=0.7)

    # ncDfk/wcDfk = 176-sample sub-window of the wide window (onset col 35).
    lo = style.PNCDFK_ONSET - 35
    hi = style.PNCDFK_ONSET + 141
    ncDfk = pncDfk[:, lo:hi].copy()
    wcDfk = pwcDfk[:, lo:hi].copy()

    # Input traces @2000 Hz, 0..dur s. CL applies a larger corrective drive.
    tin = np.arange(0, style.DUR * style.FS_IN + 1) / style.FS_IN
    base = 0.8 * (1 - np.exp(-tin / 0.3))
    ncInp = base[None, :] + rng.normal(0, 0.05, size=(n_ol, tin.size))
    wcInp = 1.4 * base[None, :] + rng.normal(0, 0.12, size=(n_cl, tin.size))

    sess = Session(name=name, ref=style.REF, dur=style.DUR,
                   ncDfk=ncDfk, wcDfk=wcDfk, pncDfk=pncDfk, pwcDfk=pwcDfk,
                   ncInp=ncInp, wcInp=wcInp,
                   nc=np.arange(n_ol), wc=np.arange(n_cl))
    # cache the full-window RMSE like controllerData.m does
    sess.er_ncDfk = sess.rmse_full(cl=False)
    sess.er_wcDfk = sess.rmse_full(cl=True)
    return sess


def make_session_set(n=6, base_seed=100):
    """A set of sessions with mild per-session variation (for cross-session panels)."""
    return [make_synthetic_session(name=f"S{k+1}", seed=base_seed + k,
                                   n_ol=40 + 3 * k, n_cl=40 + 2 * k) for k in range(n)]


# ---------------------------------------------------------------------------
# Write an HDF5 file that mimics MATLAB -v7.3 (column-major -> reversed dims).
# ---------------------------------------------------------------------------
def write_synthetic_cache(path: str, sess: Session):
    """Write a Session to an HDF5 file in MATLAB v7.3 layout.

    Matrices are stored transposed and vectors as (1,n), exactly the dimension
    order h5py sees for a real MATLAB save; io._read transposes them back.
    """
    import h5py

    with h5py.File(path, "w") as f:
        g = f.create_group("data")
        for key in ["ncDfk", "wcDfk", "pncDfk", "pwcDfk", "ncInp", "wcInp"]:
            arr = getattr(sess, key)
            g.create_dataset(key, data=np.asarray(arr, dtype=np.float64).T)  # transposed
        for key in ["nc", "wc", "er_ncDfk", "er_wcDfk"]:
            arr = getattr(sess, key)
            if arr is not None:
                g.create_dataset(key, data=np.asarray(arr, dtype=np.float64).reshape(1, -1))
        d = f.create_group("d")
        d.create_dataset("ref", data=np.array([[sess.ref]], dtype=np.float64))
        p = d.create_group("params")
        p.create_dataset("dur", data=np.array([[sess.dur]], dtype=np.float64))
    return path
