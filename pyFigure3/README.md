# pyFigure3 — Python port of Figure 3 (closed-loop vs open-loop)

Python reimplementation of the MATLAB Figure 3 panel pipeline, so the figure can
be regenerated **without MATLAB** (e.g. from the home PC) directly from the same
`data/<session>.mat` controller caches.

Ported from:
- `controller-analysis/variance_mse.m` — panels F, G, I
- `controller-analysis/step_response.m` — panel H
- `utils/analysisPlots_combined.m` — panels A–E
- `utils/controllerData.m` / `controller-analysis/load_sessions.m` — cache schema & aggregation

## Panels

| Panel | Content | Scope |
|---|---|---|
| A | single-trial OL/CL ΔF/F + input | representative session |
| B | trial-averaged ΔF/F ± std | representative session |
| C | trial-averaged optogenetic input (×3 display) | representative session |
| D | cross-trial variance vs time | representative session |
| E | per-trial RMSE half-violin | representative session |
| F | cross-session average variance vs time | all sessions |
| G | per-trial RMSE violins, one pair per session | all sessions |
| H | all-session mean tracking-error RMSE vs time | all sessions |
| I | OL/CL variance ratio by window (pre / 0–1 s / 1–3 s / post) | all sessions |
| J | OL/CL RMSE ratio, settling (0–1 s) vs steady (1–3 s) | all sessions |

## Setup

```bash
python3 -m venv .venv           # from brain_paper/ root
.venv/bin/pip install -r pyFigure3/requirements.txt
```

## Run on real data (lab PC — where `data/` caches live)

```python
from pyFigure3 import figure3
figure3.make_figure3(
    cache_paths=[
        "data/AL_0033ctrl01203.mat",
        "data/AL_0033ctrl02122.mat",
        # ... the 13 controller sessions ...
    ],
    rep_path="data/AL_0033ctrl04191.mat",   # representative session for A–E (selField=10)
    outdir="paper/images/figure3",
)
```

Writes `panel_A.png … panel_J.png` + `figure3_montage.png` to `outdir`.
The loader reads only the Figure-3 fields from each cache, so the multi-GB SVD in
`d` is never loaded into memory.

## Test without data

```bash
.venv/bin/python -m pyFigure3.test_figure3     # synthetic fixtures + demo figures
```

This builds synthetic sessions, round-trips them through the MATLAB-v7.3-style
HDF5 loader, renders every panel, and asserts the paper's core claims (CL RMSE <
OL RMSE; stim-window variance ratio > 1).

## Notes on fidelity

- **RMSE is sample-normalised**: `sqrt(mean((seg − ref)²))`, `ref = −5`
  (matches `er_ncDfk = norm(seg−ref)/sqrt(numel)` after the 2026-07-16 RMSE
  convention change).
- **Column layout** (35 Hz): in the 176-sample `ncDfk` window, onset = col 36,
  +1 s = col 71, +3 s = col 141 (1-based MATLAB; 0-based in `style.py`).
- **Panel I uses four windows** (pre / 0–1 s / 1–3 s / post), following the
  current `variance_mse.m` (`Fr` cell), which splits the stim window into early
  and late — newer than the manuscript caption's three-window description.
- **Input color**: the current MATLAB code draws both OL and CL inputs in gray
  (`[0.55 0.55 0.55]`); the caption's pink/blue predates that revision. This port
  matches the code.
- **Cache format assumption**: the loader expects the `-v7.3`/HDF5 layout with
  top-level groups `data` and `d`, numeric fields stored as datasets. If a real
  cache differs (e.g. a struct field stored via object references), adjust
  `io._read` — this is the most likely thing to need a tweak on first real-data run.
