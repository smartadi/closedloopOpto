# Dual-opsin bilateral impulse dose-response — handoff (`bilateral/impulse/`)

Self-contained record so a fresh session can carry this over with no prior context.
Created 2026-07-13 for **AL_0048 2026-07-10**.

## What this is
The impulse-analysis logic (single-frame photostim dose-response, 0–200 ms energy, median ±
95th-pct / mean ± SEM) run as a **sub-area of the dual-opsin (bilateral) analysis** on the
two-spot bilateral impulse experiment (`opto_bilateralImpulse638`). It reuses the grid
module's raw-data primitives (`../grid/loader.py`, `calibration.py`, `analysis.py`) — same
onset-from-Timeline derivation, galvo volts→mm calibration, and SVD dF/F interpolation.

Dual opsin: **left hemisphere = EXCITATORY** (galvoX<0 → focal **positive** dF/F), **right =
INHIBITORY** (galvoX>0 → focal **negative** dF/F).

## Session & data layout (2026-07-10) — important: this session is RAW and MULTI-BLOCK
Server root: `//sahale.biostr.washington.edu/data/Subjects/AL_0048/2026-07-10/`
- **exp `3`** = the continuous widefield SVD + raw Timeline (`blue/`, `corr/`, galvo/lightCommand
  traces). Its Timeline spans the **whole ~97-min session** (11.63 M samples @ 2 kHz; corr V =
  203 356 frames), so its 638 onsets contain **all** stim blocks. `WF_EXP="3"`.
- **exp `4`** = 2-trial **false start** of the impulse protocol (ignore).
- **exp `5`** = the **impulse dose-response** (`IMPULSE_BLOCK="5"`): 643 trials, 6 amps
  `[0, 0.5, 1.0, 1.5, 2.0, 2.5]` (0 = sham, no laser), two mirrored spots galvoX = ±2.5 at
  galvoY = −3. Planned 1200 (100/amp), stopped ~half.
- **exp `6`** = the 52-site **grid** (`opto_brainGrid638`) — analyzed separately by `../grid/`.

Because one Timeline holds impulse (4,5) **then** grid (6) onsets separated by a **>90 s gap**,
`impulse_core.load_session` derives all 638 onsets, keeps the pre-grid segment
(`loader.segment_onsets`, gap 50 s), and **assigns amplitude positionally** from block 5's
firing (amp>0) trials: sham fires no laser so the 532 detected onsets map 1:1, in order, onto
block 5's 532 firing trials (validated: 100 % galvoX-sign match). A leading false-start pulse
(block 4) is trimmed from the tail-aligned set. **~50 reps per amp per side.**

## How to run
```bash
.venv/Scripts/python.exe bilateral/impulse/run_impulse.py
```
Outputs → `bilateral/impulse/impulse_png/` (gitignored — `*.png`). One run ≈ a minute over the
network (materializes `U[:,:,:50]` once for the focal localization).

## Pipeline (per side)
1. **Data-derived focal pixel** (`find_focal_pixel`): early stim-vs-baseline snapshot over the
   strongest-amp (`FOCUS_AMP=2.5`) trials; take the extreme **signed** dF/F within a
   `FOCUS_SEARCH_RAD=35` px box around the nominal galvo→pixel (max on excit side, min on
   inhib) — mirrors the impulse-area "data-derived stim site" rule, not the flip-prone
   nominal pixel. Left focal ≈ (164, 397); right ≈ (401, 389).
2. **Per-amp per-trial dF/F** at that focal ROI (`site_traces`), each trial baselined to its
   own pre-onset `[-0.5, 0]` s mean.
3. **Metrics:** 0–200 ms mean **energy** (project convention, `energy_per_trial`) and the
   signed **peak of the trial-mean trace** with bootstrap 95% CI (`peak_of_mean_dose`).

## Metric note (why two dose-response figures)
The locked "inhibition energy = mean 0–200 ms" (peak_mode=3) suits the **sustained inhibitory
trough** but *dilutes the fast excitatory transient* (a ~60 ms positive peak that partly
cancels its own decay within 200 ms). So the excitatory dose-response reads cleanly only on
the **peak** metric. Both are reported: `impulse_dose_response_peak.png` (headline) and
`impulse_dose_response_energy.png` (convention). Per-trial "max of a noisy trace" was rejected
— it rectifies noise and inflates low-amp points; the peak is taken on the **averaged** trace.

## Outputs (`impulse_png/`)
| File | content |
|---|---|
| `impulse_sites.png` | mean image + bregma + the two data-derived focal pixels |
| `impulse_spatial.png` | focal-localization dF/F map per side (amp 2.5, early stim vs base) |
| `impulse_traces.png` | per-amp trial-mean dF/F ± SEM at each focal site (energy window shaded) |
| `impulse_dose_response_peak.png` | signed peak-of-mean vs amp, bootstrap 95% CI (headline) |
| `impulse_dose_response_energy.png` | 0–200 ms energy vs amp, median ± 95th-pct + mean ± SEM |

## Findings (first pass, single session)
- **Both opsins respond, opposite sign, dose-graded.** Left/excitatory: fast positive
  transient scaling with amp (peak-of-mean +0.3 %→+2.1 % over amps 0.5→2.5). Right/inhibitory:
  0–200 ms negative dip, clean at amps 2.0–2.5 (peak ~−1.2 to −1.3 %) but weaker/noisier and
  non-monotonic at low amps.
- **Dual-opsin polarity confirmed** end-to-end (same as the grid): validates the raw →
  onset → position → calibration → SVD pipeline on the impulse block.

## Key knobs (`impulse_config.py`)
`SUBJECT/DATE/WF_EXP/IMPULSE_BLOCK/CALIB_BLOCK`, `AMPS`, `FOCUS_AMP`, `SITE_LEFT/RIGHT`,
`FOCUS_SEARCH_RAD`, `ROI_RAD`, window (`FS_WIN`, `WIN_PRE/POST`, `BASE_WIN`), `ENERGY_WIN`
(0–200 ms, locked), `PEAK_WIN` (0–300 ms), `SEGMENT_GAP_S`. Image registration
(`BREGMA_PX`, `PX_PER_MM_X/Y`) is imported from the grid config (Fig-0 verified this session).

## Contra→ipsi stim-blind OLS (`impulse_ols.py` + `run_ols.py`) — added 2026-07-16
Port of the impulse-analysis residual framework (`impulse-analysis/ols_tf_pipeline.m`:
`local_stimblind_session` + `select_wlasso`/`cd_lasso`) to this module. Isolates the LOCAL stim
effect at each site as the residual of a spontaneous-trained contra→ipsi predictor built to be
stim-blind:
```
Actual = ya            (measured peri-onset ipsi trace, focal pixel, %dF/F)
Global = b' · evZ      (sparse distal contra prediction — carries the honest LEAK)
Local  = ya − Global   (residual = the isolated local stim effect)
```
**Model = §17d [STIMBLIND-SELECT]** (sole model since NATIVE was retired upstream 2026-07-18):
keep the stim-UNAFFECTED contra px, then fit the spont OLS with an L1 penalty that GROWS toward
the ipsi site (`select_l1frac=0.15`, `select_pen_near=2.0`, `select_pen_far=0.2`), so surviving
predictors are FEW and FAR from the site. There is NO dip-blinding constraint, so Global measures
a real leak. ⚠ The retired NATIVE KKT model zeroed the predicted dip by construction — its ~100%
"capture" was guaranteed, not a finding. Do not reintroduce it.
Dual-opsin twist: each trial stims ONE hemisphere, so the OTHER is the unstimulated contra
predictor. Run per side → excit (left, +) & inhib (right, −) local effects in one session.

Run: `.venv/Scripts/python.exe bilateral/impulse/run_ols.py` → `bilateral/impulse/ols_png/`
(`ols_decomposition.png`, `ols_dose_response.png`, `ols_weight_maps.png`).

**Two non-obvious knobs (see RESEARCH 2026-07-16):**
- **500 SVD comps** (`OLS_N_COMPS` in `run_ols.py`), NOT the 50 the dose-response uses. With 50,
  the ~400-node contra grid spans the whole SVD space → any pixel reconstructs exactly → spont
  R²=1.0 (trivial). 500 comps make the grid a proper subspace → genuine R² 0.95/0.99.
- **Dose readout = signed PEAK**, not the 0–300 ms mean: the fast excitatory transient cancels
  against its undershoot in the mean (peak_mode=3 dilutes it), exactly as for the dose-response.
- Contra grid = **bregma-midline hemisphere split** (`build_contra_grid`), no hand-drawn ROI.

**Brain mask (REQUIRED first step).** The contra grid is built from the hand-drawn ROI —
see `brain_mask.py` and draw it once per session before running:
```bash
.venv/Scripts/python.exe bilateral/impulse/brain_mask.py    # outline + 2 midline pts -> masks/*.json
```
⚠ Do NOT fall back to a bare intensity threshold: `mimg > percentile(mimg, 20)` keeps 80 % of the
frame BY CONSTRUCTION and sweeps the ventral/skull band in as contra predictors (RESEARCH
2026-07-21). `thr_pctile` is only a floor applied INSIDE the drawn outline.

**Result (single session, SELECT, peak-based capture/leak — the valid readout).**
Mask QC: brain 192 537 px (61 % of frame), contra/ipsi 95 521/97 016 (balanced 48/52 % →
midline well placed). Spont contra→ipsi R² = **0.986** (excit) / **0.993** (inhib) on the full
grid (455/471 nodes); the sparse SELECT fit keeps only **2–8 predictors** (predR² 0.66–0.74).

| side | capture | leak | reading |
|---|---|---|---|
| left / excitatory | **90 %** | 10 % | local effect is spatially CONFINED — distal px are ~stim-blind |
| right / inhibitory | **61 %** | 39 % | dip PROPAGATES — ~40 % is predictable from far contra px |

The inhibitory leak is **dose-graded** (Global peak −0.49 → −0.84 across amps), so it is genuine
stim propagation, not predictor noise. This excit-confined vs inhib-broad asymmetry is the
headline dual-opsin claim, and it lines up with AL_0033 `[CP-STIMAFF]` ("~95% of contra
co-suppresses = network coupling"). **Not yet replicated** (n=1 session).

⚠ Open caveats (in priority order):
1. **Extreme sparsity** — nActive 2–8. Inhib 2.5 V selects just **2** predictors yet leaks 71 %;
   either genuine broad propagation or the bled detector failing to exclude stim-affected px.
2. **L1 shrinkage** — `select_wlasso` does not debias, so Global is shrunk → capture is an
   UPPER bound (same bias upstream in MATLAB §17d).
3. **Bled-detector instability** — per-amp drop counts non-monotonic (excit 247/87/57/31/222).
4. Exclude **inhib 1.5 V** and **excit 0.5 V** (near-threshold, Actual≈0 → ratios blow up);
   both flagged `!` in the runner output.

## Open items / next steps
- **Recover the sham (amp 0) catch condition** — it fires no laser so it is absent from the
  detected onsets; recover its trial times via the Block↔Timeline clock offset to get a true
  no-stim baseline for the dose-response origin.
- **Stage 3 — residual state-dependence** (per-trial residual vs brain state). BLOCKED: no
  AL_0048 face-motion trace exists yet (only `compute_face_motion_AL0046.m`); pre-stim
  variance/δ is a KNOWN signal-power confound (retracted 2026-07-02). Get the face-motion trace
  first — motion is the clean, power-independent state variable.
- **TF fit** of the impulse response per side (excitatory transient vs inhibitory dip time
  constants); compare to AL_0033/AL_0041 impulse TFs.
- If any panel is promoted to the paper: re-render through `utils/paperFig`/`paperStyle`.
