"""Pipeline health check for a real controller cache (data/<session>.mat).

Walks the pipeline bottom-up and flags the mode-1 "sampling rate too high" bug:
whether dFk and timeBlue share an index space, the true blue rate, the input
rate, trial-window shapes, and onset alignment.

    .venv/bin/python -m pyFigure3.diagnose /mnt/sahale/.../AL_0048ctrl07292.mat
    .venv/bin/python -m pyFigure3.diagnose data/AL_0033ctrl04191.mat

Reads d.timeBlue / d.inpTime / d.stimStarts / data.dFk / data.ncDfk directly
from the HDF5 cache (only small vectors — never the SVD).
"""
from __future__ import annotations

import sys

import numpy as np

from . import style


def _read(h5obj, name):
    arr = np.array(h5obj[name])
    if arr.ndim == 2:
        arr = arr.T
    return np.asarray(arr).ravel() if arr.ndim <= 1 or 1 in arr.shape else arr


def _get(group, path):
    node = group
    for p in path.split("/"):
        if p not in node:
            return None
        node = node[p]
    return node


def diagnose(matpath: str):
    import h5py

    print(f"\n=== pipeline diagnosis: {matpath} ===\n")
    ok = True
    with h5py.File(matpath, "r") as f:
        d = f.get("d")
        data = f.get("data")
        if d is None or data is None:
            print("  ! cache missing top-level 'd' or 'data' group")
            return False

        # --- Stage 1: sampling rates from the timestamps themselves ----------
        tb = _get(d, "timeBlue")
        ti = _get(d, "inpTime")
        if tb is not None:
            tb = np.array(tb).ravel()
            fs_blue = 1.0 / np.median(np.diff(tb))
            print(f"[1] timeBlue: n={tb.size}, inferred rate = {fs_blue:6.2f} Hz "
                  f"(expect ~35)  {'OK' if abs(fs_blue-35) < 2 else '<-- OFF'}")
            if abs(fs_blue - 35) >= 2:
                ok = False
        if ti is not None:
            ti = np.array(ti).ravel()
            fs_in = 1.0 / np.median(np.diff(ti))
            print(f"    inpTime:  n={ti.size}, inferred rate = {fs_in:8.1f} Hz "
                  f"(expect ~2000) {'OK' if abs(fs_in-2000) < 100 else '<-- OFF'}")

        # --- Stage 2: dFk vs timeBlue index space (THE mode-1 bug) -----------
        dFk = _get(data, "dFk")
        if dFk is not None and tb is not None:
            dFk = np.array(dFk).ravel()
            ratio = dFk.size / tb.size
            verdict = "OK (same index space)" if abs(ratio - 1) < 0.02 else \
                      (f"<-- 2x TOO HIGH: dFk is at ~70 Hz, timeBlue at 35 Hz" if abs(ratio - 2) < 0.05
                       else f"<-- MISMATCH")
            print(f"[2] len(dFk)={dFk.size}  len(timeBlue)={tb.size}  "
                  f"ratio={ratio:.3f}  {verdict}")
            if abs(ratio - 1) >= 0.02:
                ok = False

        # --- Stage 3: trial-window shapes ------------------------------------
        ncDfk = _get(data, "ncDfk")
        if ncDfk is not None:
            m = np.array(ncDfk)
            if m.ndim == 2 and 1 not in m.shape:
                # h5py gives (time, trials); the port transposes to (trials, time)
                ncols = m.shape[0] if m.shape[0] in (176,) else m.shape[1]
                print(f"[3] ncDfk cols = {ncols}  (expect 176 = 35*(dur+2)+1)  "
                      f"{'OK' if ncols == 176 else '<-- OFF'}")
                if ncols != 176:
                    ok = False

        # --- Stage 4: onset alignment sanity ---------------------------------
        ss = _get(d, "stimStarts")
        if ss is not None and tb is not None and dFk is not None:
            ss = np.array(ss).ravel()
            j = ss.size // 2
            i = int(np.argmin(np.abs(tb - ss[j])))
            need = i + 35 * (int(round(1)) + 3)  # crude upper bound of a window end
            print(f"[4] sample onset idx for trial {j}: i={i}  "
                  f"(dFk has {dFk.size} samples; window fits: "
                  f"{'yes' if i - 350 >= 0 and i + 35*6 < dFk.size else 'NO <--'})")

    print(f"\n  VERDICT: {'pipeline looks consistent' if ok else 'PROBLEM DETECTED (see <-- flags)'}\n")
    return ok


def main():
    if len(sys.argv) < 2:
        print("usage: python -m pyFigure3.diagnose <cache.mat> [<cache2.mat> ...]")
        sys.exit(2)
    results = [diagnose(p) for p in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
