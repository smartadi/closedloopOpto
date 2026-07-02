"""calibration.py — read per-session rig calibration from the server instead of hardcoding.

GALVO volts<->mm calibration (mmPerV_X/Y, bregmaOffset_X/Y) is written by Rigbox into each
acquisition's `*_hardwareInfo.json` under `signalsOutputs.opto<LASER>` (identical copy under
`signalsOutputs.galvoOpto`). We read it there and cache the four numbers to
`data/grid_calib_<subject>_<date>.json`, so the ~20 MB json is parsed only once per session.
These drive derive_onsets_positions (galvo voltage traces -> mm-from-bregma grid nodes).

IMAGE registration (bregma pixel + px/mm in the 560x560 SVD frame) is NOT in the widefield
session on the server: bregma is marked visually (Fig 0 dial-in) and px/mm is a widefield-
optics rig constant. `bregma_px_hint` offers a same-day `bregma.csv` pixel (e.g. from a paired
closed-loop run) as a starting estimate when one exists; the verified value stays in config.
"""
import json
from pathlib import Path

import numpy as np


def _hardwareinfo_path(subject, date, block_exp, server):
    d = Path(server) / subject / date / str(block_exp)
    hits = sorted(d.glob("*_hardwareInfo.json"))
    return hits[0] if hits else None


def galvo_calib(subject, date, laser, block_exp, server, cache_dir, refresh=False):
    """Return dict(mm_per_v_x, mm_per_v_y, bregma_offset_x, bregma_offset_y, source).

    Reads `signalsOutputs.opto<laser>` (falls back to `galvoOpto`) from the session's
    hardwareInfo.json and caches to data/grid_calib_<subject>_<date>.json. Pass refresh=True
    to re-read the server and overwrite the cache.
    """
    cache_dir = Path(cache_dir)
    cache = cache_dir / f"grid_calib_{subject}_{str(date).replace('/', '-')}.json"
    if cache.exists() and not refresh:
        return json.loads(cache.read_text())

    hw = _hardwareinfo_path(subject, date, block_exp, server)
    if hw is None:
        raise FileNotFoundError(
            f"no *_hardwareInfo.json under {subject}/{date}/{block_exp} — cannot read galvo calib")
    with open(hw) as f:
        H = json.load(f)
    so = H["signalsOutputs"]
    key = f"opto{laser}" if f"opto{laser}" in so else "galvoOpto"
    g = so[key]
    out = dict(mm_per_v_x=float(g["mmPerV_X"]), mm_per_v_y=float(g["mmPerV_Y"]),
               bregma_offset_x=float(g["bregmaOffset_X"]), bregma_offset_y=float(g["bregmaOffset_Y"]),
               source=f"{hw.name}:signalsOutputs.{key}")
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(out, indent=2))
    print(f"[calib] galvo volts->mm read from {out['source']} -> cached {cache.name}")
    return out


def bregma_px_hint(subject, date, server):
    """Return (x, y) bregma pixel from a same-day `bregma.csv` if any session has one, else
    None. This is only a starting estimate for BREGMA_PX (the marking frame may differ from
    the widefield SVD frame); always verify with Fig 0."""
    for csv in sorted((Path(server) / subject / date).glob("*/bregma.csv")):
        try:
            xy = np.loadtxt(csv, delimiter=",", skiprows=1)
            return (float(xy[0]), float(xy[1]), str(csv.parent.name))
        except Exception:
            continue
    return None
