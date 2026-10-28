"""Session loader for the stats_v2 clean-room rebuild (SPEC.md section 2).

Reads ONLY `d.*` fields and `data.dFk` from the MATLAB v7.3 session caches. Every field
that is read goes through `_read`, which records it in FIELDS_READ for the manifest.
"""
from pathlib import Path

import h5py
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

# id, mouse, date, exp, cache file, validation N, build  (SPEC.md section 2 table)
SESSIONS = [
    ("m1", "AL_0033", "2025-01-20", 3, "AL_0033ctrl01203.mat", 120, "old"),
    ("m2", "AL_0033", "2025-02-12", 2, "AL_0033ctrl02122.mat", 200, "old"),
    ("m3", "AL_0033", "2025-02-24", 2, "AL_0033ctrl02242.mat", 200, "old"),
    ("m4", "AL_0033", "2025-02-26", 2, "AL_0033ctrl02262.mat", 200, "old"),
    ("m5", "AL_0033", "2025-03-04", 1, "AL_0033ctrl03041.mat", 60, "old"),
    ("m6", "AL_0033", "2025-03-05", 2, "AL_0033ctrl03052.mat", 30, "old"),
    ("m7", "AL_0033", "2025-03-20", 4, "AL_0033ctrl03204.mat", 100, "old"),
    ("m8", "AL_0033", "2025-04-15", 2, "AL_0033ctrl04152.mat", 60, "old"),
    ("m9", "AL_0039", "2025-04-20", 1, "AL_0039ctrl04201.mat", 100, "old"),
    ("m10", "AL_0039", "2025-04-19", 1, "AL_0039ctrl04191.mat", 100, "old"),
    ("m11", "AL_0039", "2025-04-30", 3, "AL_0039ctrl04303.mat", 100, "old"),
    ("m12", "AL_0033", "2025-04-19", 1, "AL_0033ctrl04191.mat", 100, "old"),
    ("m13", "AL_0039", "2025-04-20", 2, "AL_0039ctrl04202.mat", 100, "old"),
    ("m14", "AL_0048", "2026-07-29", 2, "AL_0048ctrl07292.mat", 100, "new"),
    ("m15", "AL_0051", "2026-07-29", 2, "AL_0051ctrl07292.mat", 100, "new"),
]
SESSION_IDS = [s[0] for s in SESSIONS]

FIELDS_READ = set()

# Preference order used only to break an exact tie in the 99.9th-percentile rule.
CHANNEL_ORDER = ["inpVals", "inpVals594", "inpVals638"]


def _read(f, path):
    """Read one dataset (only d.* or data.dFk allowed) and record it."""
    if not (path.startswith("d/") or path == "data/dFk"):
        raise PermissionError(f"stats_v2 must not read {path}")
    FIELDS_READ.add(path.replace("/", "."))
    return f[path][()]


def _vec(f, path):
    return np.asarray(_read(f, path), dtype=float).ravel()


def _chars(f, path):
    return "".join(chr(c) for c in np.asarray(_read(f, path)).ravel())


def session_info(sid):
    row = SESSIONS[SESSION_IDS.index(sid)]
    keys = ("id", "mouse", "date", "exp", "file", "n_val", "build")
    return dict(zip(keys, row))


def load_session(sid, dfk_offset=0):
    """Load one session.

    dfk_offset: frame shift used to place data.dFk on the timeBlue grid.
      0  -> dFk[i] belongs to timeBlue[i] (the spec's reading; default).
      k  -> dFk[i] belongs to timeBlue[i + k] (only used for the m14 sensitivity check).
    Frames of the timeBlue grid without a dFk value are NaN.
    """
    info = session_info(sid)
    path = DATA / info["file"]
    with h5py.File(path, "r") as f:
        dkeys = list(f["d"].keys())
        s = dict(info)
        s["path"] = str(path)
        s["mn"] = _chars(f, "d/mn")
        s["td"] = _chars(f, "d/td")
        s["en"] = float(_vec(f, "d/en")[0])
        s["timeBlue"] = _vec(f, "d/timeBlue")
        dfk_raw = _vec(f, "data/dFk")
        s["motion_raw"] = _vec(f, "d/motion")
        s["input_params"] = np.asarray(_read(f, "d/input_params"), dtype=float)  # rows = fields
        s["stimStarts"] = _vec(f, "d/stimStarts")
        s["dur"] = float(_vec(f, "d/params/dur")[0])
        s["ref"] = float(_vec(f, "d/ref")[0])
        s["inpTime"] = _vec(f, "d/inpTime")

        # Active laser channel: the inpVals* field with the largest 99.9th percentile.
        chans = [k for k in CHANNEL_ORDER if k in dkeys]
        vals = {k: _vec(f, f"d/{k}") for k in chans}
        p999 = {k: float(np.percentile(v, 99.9)) for k, v in vals.items()}
        best = max(p999.values())
        tied = [k for k in chans if p999[k] == best]
        active = tied[0]
        s["chan_p999"] = p999
        s["chan_tied"] = tied
        s["chan_identical"] = (
            all(np.array_equal(vals[tied[0]], vals[k]) for k in tied[1:]) if len(tied) > 1 else None
        )
        s["active_channel"] = active
        s["cmd"] = vals[active]

        # New builds carry per-channel time vectors; check they equal d.inpTime.
        s["chan_time_equal"] = {}
        for k in ("inpTime594", "inpTime638"):
            if k in dkeys:
                s["chan_time_equal"][k] = bool(np.array_equal(_vec(f, f"d/{k}"), s["inpTime"]))

    tb = s["timeBlue"]
    s["len_timeBlue"] = len(tb)
    s["len_dFk"] = len(dfk_raw)
    s["len_motion"] = len(s["motion_raw"])
    s["dfk_offset"] = dfk_offset

    dfk = np.full(len(tb), np.nan)
    lo = max(0, dfk_offset)
    hi = min(len(tb), dfk_offset + len(dfk_raw))
    dfk[lo:hi] = dfk_raw[lo - dfk_offset: hi - dfk_offset]
    s["dFk"] = dfk
    s["dFk_raw"] = dfk_raw

    mot = np.full(len(tb), np.nan)
    m = min(len(tb), len(s["motion_raw"]))
    mot[:m] = s["motion_raw"][:m]
    s["motion"] = mot
    s["has_motion"] = bool(np.nanmax(s["motion_raw"]) > np.nanmin(s["motion_raw"]))

    ip = s["input_params"]
    n_all = ip.shape[1]
    n_val = info["n_val"]
    s["n_trials_all"] = n_all
    s["n_stimStarts"] = len(s["stimStarts"])
    val = np.arange(n_all - n_val, n_all)  # validation block = last N trials (0-based columns)
    s["val_cols"] = val
    s["cond"] = ip[2, val].astype(int)  # 0 = OL, 1 = CL
    s["kk"] = ip[1, val]  # new builds: trial-END frame, 1-based
    s["stim"] = s["stimStarts"][val]
    s["dt_frame"] = float(np.median(np.diff(tb)))
    # Onset frame = frame whose timeBlue is nearest to stimStarts (0-based index).
    s["onset"] = np.array([int(np.argmin(np.abs(tb - t))) for t in s["stim"]])
    return s
