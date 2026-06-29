# Galvo photostim site-grid analysis — handoff (`bilateral/grid/`)

Self-contained record so a fresh session can carry this over with no prior context.
Last updated 2026-06-29 (consolidated into `bilateral/grid/` + refactored the monolith
into a clean Python module — see Module layout below).

## What this is
Python analysis (originally ported from the AL_0041 notebook
`legacy/2025-10-29_AL41_grid.ipynb`), adapted to run on **AL_0048 2026-06-24** in the repo
`.venv` instead of MATLAB. It maps the cortical dF/F response evoked by 638 nm optogenetic
stimulation at each of 52 galvo grid positions.

The experiment is `opto_brainGrid638` (Signals expDef): a 52-position brain grid,
`laserDur` = 25 ms, `laserAmp` = [0.25, 0.5], `numRepeats` = 50.

All notebook **analysis** cells are ported; all **probe/exploration** cells are dropped
(ipywidgets slider, single-site probe, `rastermap`, mp4 animation, the unused
`widefield_deconv.deconvolve`, and the multi-session `os.walk`/`.npy` round-trip).

## Module layout
New grid coding goes here (Python). The analysis is split into single-responsibility modules:
- `config.py`   — all session / calibration / window constants (edit this to change a session)
- `loader.py`   — read raw session, derive onsets + galvo positions, Block power alignment
- `analysis.py` — per-site dF/F extraction, rise-τ fit, spatial snapshots (pure compute)
- `plots.py`    — render the 5 figures
- `run_grid.py` — entry point wiring config → loader → analysis → plots
- `legacy/`     — pre-refactor monolith (`grid_analysis_monolith.py`), the MATLAB port
  (`grid_analysis.m`, for already-preprocessed sessions), and the source notebook. Frozen.

## How to run
```bash
.venv/Scripts/python.exe bilateral/grid/run_grid.py
```
- `.venv` (Python 3.14, at the repo root) already has the only deps needed: **numpy, scipy,
  matplotlib, colorcet** (also pinned in `requirements.txt`). Every other notebook import —
  `pytoolsAL`, `rastermap`, `ipywidgets`, `widefield_deconv` — is in the dropped layer.
- Reads data live from the sahale share (≈320 MB + a ~1.25 GB strided read of `U[:,:,:50]`
  for the spatial map). One run takes a couple of minutes over the network.
- Outputs → `bilateral/grid/grid_png/` (**gitignored** — regenerable).

## Session & data layout (important: this session is RAW)
Server root: `\\sahale.biostr.washington.edu\data\Subjects\AL_0048\2026-06-24\`
- **exp `2`** = widefield SVD + raw Timeline traces (the analysis reads this; `WF_EXP="2"`).
- **exp `3`** = paired Signals run: `*_Block.mat`, `*_expDef.m`, `*_parameters.json`,
  `*_hardwareInfo.json` (the protocol/calibration; `BLOCK_EXP="3"`).

Unlike the AL_0041 notebook, this session has **no preprocessed** `laserOnTimes.npy` /
`galvoXPositions_mm.npy` / `expStartStopTimes.npy`. Those are derived from raw here.

SVD (present, standard): `blue/svdSpatialComponents.npy` U `(560,560,2000)` float32;
`corr/svdTemporalComponents_corr.npy` V `(T=95248, 500)` float32 (already `[frames, comps]`);
`corr/svdTemporalComponents_corr.timestamps.npy`; `blue/meanImage.npy` `(560,560)`.

## How onsets & positions are derived (the crux)
- **Onsets**: threshold `lightCommand638.raw.npy` (a fixed ~1.38 V gate) at 0.3 V → rising
  edges, debounced > 60 ms. Time in seconds = `sampleIdx / 2000` (DAQ rate 2000 Hz, from
  `TimelineHW.json`). This is the **same clock** as the corr SVD timestamps, so no extra
  alignment is needed to extract dF/F.
- **Positions**: sample `galvoX.raw.npy` / `galvoY.raw.npy` during the pulse, convert
  volts→mm and snap to the grid nodes:
  ```
  mm_x = (V_x - bregmaOffset_X) * mmPerV_X     # snap to half-integers -3.5..3.5
  mm_y = (V_y - bregmaOffset_Y) * mmPerV_Y     # snap to integers      -4..3
  ```
- Yields exactly **2600 onsets = 52 sites × 50 reps** (one power level — see below).

### Calibration constants & provenance (from `hardwareInfo.json` → `daqController.galvoOpto`)
```
mmPerV_X        =  1.1111111111111112
mmPerV_Y        = -1.075268817204301      # Y inverted
bregmaOffset_X  =  0.732639223045812      # galvo volts at bregma (mm=0)
bregmaOffset_Y  =  0.30088318722119456
```
Also at `AL_0048/2026-06-24/optoGalvoCalib/` (`bregma_coords.mat`, `bregmaOffset_X/Y.mat`,
`bregma_image.mat`) — same offsets, plus `bregma_coords = [530.3, 216.7]` **in the 512×640
calibration image** (NOT the 560×560 SVD frame — see geometry note).

## Bregma / pixel geometry (dial-in, confirmed good)
The mm→pixel mapping for ROI placement uses top-of-script knobs, **not** the server
`bregma_coords` (that point is in the 512×640 calibration image; the SVD/meanImage is 560×560
and there's no stored registration between them). Current values, **confirmed visually correct
by the user via Fig 0** (`grid_sites.png`):
```
BREGMA_PX   = (280.0, 250.0)   # (x,y) px in the 560x560 meanImage
PX_PER_MM_X =  57.8            # rig scale carried from the AL_0041 notebook
PX_PER_MM_Y = -57.8            # y inverted
```
If a different session is used, re-verify these against Fig 0 before trusting downstream figs.

## Power: only the 0.5 level fired
Of the 2600 detected 638 pulses, **2541 are the 0.5-power condition and 59 the 0.25**
(assigned via Block alignment, below). Probing both light commands at Block-predicted times
shows **0.25-power trials produce no 638 (or 594) pulse at all** — they were sub-threshold and
did not lase. So `AMP_SEL = 0.5` (default) is the only usable power; a 0.25 map is NOT
recoverable from this session. (This is itself a data-quality finding — confirm with the
experimenter whether 0.25 was expected to fire.)

### Block→Timeline alignment (for per-onset power labeling)
`block_power_per_onset()` loads exp 3 `Block.mat` `outputs.opto638Values` (the randomized
per-trial amplitude/galvoX/galvoY log) and greedily aligns the detected onsets onto it by the
**galvo-position fingerprint** (100% match; the detected onsets are an in-order subsequence of
all 5200 planned trials). The Block↔Timeline clock offset is ≈ **98.9 s (std 0.2 s)** — note
the ±0.2 s jitter means Block times are NOT frame-accurate, so the hardware `lightCommand638`
edges remain the onsets used for dF/F.

## Outputs (`bilateral/grid/grid_png/`, gitignored)
| File | `plots.py` fn | Content |
|---|---|---|
| `grid_sites.png` | `plot_sites` | bregma/site overlay on the mean image (Fig 0 dial-in) |
| `grid_timecourses.png` | `plot_timecourses` | per-site ROI dF/F median±SEM + exp-rise τ fit, 8×8 |
| `grid_tau.png` | `plot_tau` | rise-τ spatial map (colorcet `cet_CET_L4`) |
| `grid_spatial.png` | `plot_spatial` | full-frame dF/F image per site, 40–120 ms post-stim |
| `grid_raster.png` | `plot_raster` | per-site trial×time dF/F raster (±8%) |

## Key knobs (all in `config.py`)
`SUBJECT/DATE/WF_EXP/BLOCK_EXP`, `LASER="638"`, `AMP_SEL=0.5` (None→pool),
`N_COMPS=50`, `LASER_THR=0.3`, `BREGMA_PX`, `PX_PER_MM_X/Y`, `ROI_RAD=10`,
window (`FS_WIN`, `WIN_PRE=12/35`, `WIN_DUR=1.5`, `TAU_T0_IX=32`),
`SPATIAL_SNAPSHOT`/`BASE_WIN`/`STIM_WIN`/`SPATIAL_CLIM`, `RASTER`/`RASTER_CLIM`.

## Findings (also in FINDINGS.md / RESEARCH.md)
- **Dual-opsin polarity confirmed**: left-hemisphere sites (galvo x<0, excitatory opsin) give
  focal POSITIVE/red dF/F; right-hemisphere sites (x>0, inhibitory opsin) give NEGATIVE/blue —
  clean end-to-end validation of the raw→onset→position→calibration→SVD pipeline.
- **0.25-power did not lase** (see above).

## Open items / next steps
- (optional) aggregate stim→response **causal/connectivity map** across the 52 sites (an N×N
  matrix or per-cortical-region readout), beyond the per-site spatial snapshot. Nothing like
  this exists yet; the per-trial dF/F is returned per site by `analysis.compute_site_responses`.
- 0.25-power map needs a session where the 638 command clears the lasing threshold at 0.25.
- (optional) parameterize loader for other `opto_brainGrid` sessions / the 594 line.
- If promoted to a paper panel: move outputs out of `bilateral/grid/grid_png` and apply
  `paperFig`/`paperStyle` (currently exploratory PNGs only).

## Files
- `config.py` / `loader.py` / `analysis.py` / `plots.py` / `run_grid.py` — the live module
  (see Module layout above). `run_grid.py` is the entry point.
- `legacy/grid_analysis_monolith.py` — the pre-refactor single-file version, kept as a
  behavioral reference to diff against (the module is a faithful split of it).
- `legacy/grid_analysis.m` — earlier MATLAB port; assumes a **preprocessed** session
  (`laserOnTimes.npy`, `galvoXPositions_mm.npy`, …). Keep for sessions that already have
  those derived files.
- `legacy/2025-10-29_AL41_grid.ipynb` — the source notebook (AL_0041).
