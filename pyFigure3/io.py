"""Load a per-session controller cache (data/<session>.mat) into a Session.

The MATLAB pipeline saves each session as ``save(pathCtrl,'d','data','-v7.3')``,
i.e. an HDF5 file with top-level groups ``d`` and ``data`` (fig3_spec §1a).
We read ONLY the fields Figure 3 needs, so the multi-GB SVD held in ``d`` is
never materialised.

MATLAB v7.3 stores arrays column-major, so h5py sees every 2-D array with its
dimensions reversed; ``_read`` transposes back. A synthetic writer in synth.py
follows the same convention, so the loader is exercised end-to-end against a
file in the real on-disk format.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

import numpy as np

from . import style


# Fields pulled from the `data` struct. (trials x time) matrices + (trials,) vectors.
_DATA_MATRICES = ["ncDfk", "wcDfk", "pncDfk", "pwcDfk", "ncInp", "wcInp"]
_DATA_VECTORS = ["nc", "wc", "er_ncDfk", "er_wcDfk"]


@dataclass
class Session:
    """One controller session, holding only what Figure 3 consumes."""

    name: str = "session"
    ref: float = style.REF
    dur: float = style.DUR
    fs: int = style.FS

    ncDfk: np.ndarray = None   # (nNc, 176)  open-loop dF/F, onset col 35
    wcDfk: np.ndarray = None   # (nWc, 176)  closed-loop dF/F
    pncDfk: np.ndarray = None  # (nNc, 561)  wide window, onset col 350
    pwcDfk: np.ndarray = None  # (nWc, 561)
    ncInp: np.ndarray = None   # (nNc, 6001) OL input @2000 Hz, onset col 0
    wcInp: np.ndarray = None   # (nWc, 6001) CL input
    er_ncDfk: Optional[np.ndarray] = None  # (nNc,) full-window RMSE (recomputed if absent)
    er_wcDfk: Optional[np.ndarray] = None
    nc: Optional[np.ndarray] = None        # OL trial indices
    wc: Optional[np.ndarray] = None        # CL trial indices

    # ---- derived quantities (sample-normalised RMSE, cross-trial variance) ----
    def _rmse(self, mat: np.ndarray, c0: int, c1: int) -> np.ndarray:
        """sqrt(mean((seg-ref)^2)) over columns [c0:c1] — per-trial, sample-normalised."""
        seg = mat[:, c0:c1]
        return np.sqrt(np.mean((seg - self.ref) ** 2, axis=1))

    def rmse_full(self, cl: bool) -> np.ndarray:
        """[0,3] s per-trial RMSE (panels E, G). Uses cache er_* if present."""
        cached = self.er_wcDfk if cl else self.er_ncDfk
        if cached is not None:
            return np.asarray(cached).ravel()
        mat = self.wcDfk if cl else self.ncDfk
        return self._rmse(mat, style.NCDFK_ONSET, style.NCDFK_T3 + 1)

    def rmse_early(self, cl: bool) -> np.ndarray:
        """[0,1] s settling-window RMSE (panel J). cols 36:71 (1-based)."""
        mat = self.wcDfk if cl else self.ncDfk
        return self._rmse(mat, style.NCDFK_ONSET, style.NCDFK_T1 + 1)

    def rmse_late(self, cl: bool) -> np.ndarray:
        """[1,3] s steady-window RMSE (panel J). cols 71:141 (1-based)."""
        mat = self.wcDfk if cl else self.ncDfk
        return self._rmse(mat, style.NCDFK_T1, style.NCDFK_T3 + 1)

    def var_trace_l(self, cl: bool) -> np.ndarray:
        """Cross-trial variance on the 316-sample _l window (tp axis, panel F/I)."""
        pmat = self.pwcDfk if cl else self.pncDfk
        sub = pmat[:, style.PL_START:style.PL_STOP]
        return np.var(sub, axis=0, ddof=1)   # MATLAB var() normalises by N-1

    def var_trace_wide(self, cl: bool) -> np.ndarray:
        """Cross-trial variance on the full 561-sample window (panel D)."""
        pmat = self.pwcDfk if cl else self.pncDfk
        return np.var(pmat, axis=0, ddof=1)

    @property
    def n_ol(self) -> int:
        return 0 if self.ncDfk is None else self.ncDfk.shape[0]

    @property
    def n_cl(self) -> int:
        return 0 if self.wcDfk is None else self.wcDfk.shape[0]


def time_axis_l() -> np.ndarray:
    """tp = (-3*35 : 35*(dur+3))/35 -> -3..+6 s, 316 points, onset at index 105."""
    return np.arange(-style.DUR * style.FS, style.FS * (style.DUR + 3) + 1) / style.FS


def time_axis_wide() -> np.ndarray:
    """Tp for pncDfk = (-10*35 : 35*(dur+3))/35 -> -10..+6 s, 561 points."""
    return np.arange(-10 * style.FS, style.FS * (style.DUR + 3) + 1) / style.FS


def time_axis_input() -> np.ndarray:
    """Tin = (0 : dur*2000)/2000 -> 0..dur s, 6001 points."""
    return np.arange(0, style.DUR * style.FS_IN + 1) / style.FS_IN


# ---------------------------------------------------------------------------
# HDF5 (MATLAB v7.3) loader
# ---------------------------------------------------------------------------
def _read(h5obj, name):
    """Read one dataset, undoing MATLAB's column-major dim reversal."""
    dset = h5obj[name]
    arr = np.array(dset)
    if arr.ndim == 2:
        arr = arr.T
    return arr


def load_session(matpath: str, name: Optional[str] = None) -> Session:
    """Load a controller cache .mat (v7.3/HDF5) into a Session.

    Reads only the Figure-3 fields from the ``data`` group and ``d.ref`` /
    ``d.params.dur`` from the ``d`` group. Falls back to scipy.io.loadmat for
    pre-v7.3 files.
    """
    import os

    if name is None:
        name = os.path.splitext(os.path.basename(matpath))[0]

    try:
        import h5py
    except ImportError as exc:  # pragma: no cover
        raise ImportError("h5py is required to read -v7.3 caches: pip install h5py") from exc

    try:
        f = h5py.File(matpath, "r")
    except OSError:
        return _load_session_legacy(matpath, name)

    with f:
        data = f["data"]
        kw = {}
        for key in _DATA_MATRICES:
            if key in data:
                kw[key] = _read(data, key).astype(np.float64)
        for key in _DATA_VECTORS:
            if key in data:
                kw[key] = np.asarray(_read(data, key)).ravel()

        ref, dur = style.REF, style.DUR
        if "d" in f:
            d = f["d"]
            if "ref" in d:
                ref = float(np.array(d["ref"]).ravel()[0])
            if "params" in d and "dur" in d["params"]:
                dur = float(np.array(d["params"]["dur"]).ravel()[0])

    return Session(name=name, ref=ref, dur=dur, **kw)


def _load_session_legacy(matpath: str, name: str) -> Session:
    """Fallback for MATLAB < v7.3 files (scipy.io.loadmat)."""
    from scipy.io import loadmat

    m = loadmat(matpath, squeeze_me=True, struct_as_record=False)
    data = m["data"]
    kw = {}
    for key in _DATA_MATRICES + _DATA_VECTORS:
        if hasattr(data, key):
            kw[key] = np.atleast_1d(np.asarray(getattr(data, key), dtype=np.float64))
    ref, dur = style.REF, style.DUR
    if "d" in m:
        d = m["d"]
        ref = float(getattr(d, "ref", style.REF))
        if hasattr(d, "params") and hasattr(d.params, "dur"):
            dur = float(d.params.dur)
    return Session(name=name, ref=ref, dur=dur, **kw)


def load_many(paths, names=None):
    """Load several caches -> list[Session]."""
    if names is None:
        names = [None] * len(paths)
    return [load_session(p, n) for p, n in zip(paths, names)]
