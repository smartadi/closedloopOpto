# Impulse Analysis — Research Context

## Goal
Characterise the cortical inhibitory response to brief optogenetic impulses across a range of stimulus amplitudes. Three questions:
1. How does inhibition depth scale with stimulus amplitude (dose–response)? Is the relationship approximately linear?
2. Is trial-to-trial variability in inhibition depth predicted by pre-stimulus neural state (motion, variance)?
3. Can the amplitude-normalised mean response be described by a low-order linear transfer function (system ID)?

This work is the empirical basis for the LTI assumption that justifies the PI controller design. If the impulse response is linear (peak scales with amplitude, waveform shape is invariant), then the step response and controller design follow from the same linear model.

---

## Primary Script
**`Impulse_mouseDataAnalysis_all.m`** (root, ~57 KB, last modified 2026-05-14)

Secondary / older version: `Impulse_mouseDataAnalysisV2.m` (root, ~12 KB) — superseded.

---

## Data
- 3 sessions: **AL_0041** (experiments 1 & 2, two dates), **AL_0033** (experiment 3, 2025-01-29)
- AL_0041 uses stim detection **mode 2** (`findStims(d, 2)`) — `input_params(:,2)` is absolute sample index
- AL_0033 uses stim detection mode 1 — relative index, `horizon` subtracted
- The gap-filling section stamps missing-stim events with amplitude 0; these are **excluded** from dose-response fits via `nzMask = xpos_raw > 0` (bug fixed 2026-05-14)

---

## Pipeline (per session)
1. Load widefield SVD data; z-score motion trace: `mv_z = zscore(d.motion.motion_1(1:2:end))`
2. Detect stim events via `findStims(d, mode)`; fill gaps; bin by amplitude → `uAmp` / `idxByAmp`
3. Extract pixel dF/F from SVD (`F/mI*100`)
4. Align ±3 s windows around each stim onset (baseline-subtracted at onset)
5. Compute `Peak_imp` per trial:
   - **Mode 3** (current default): mean dF/F over 0–200 ms post-onset — integrates total inhibition energy
   - Mode 2 (fallback): per-trial min within ±143 ms of trial-average trough
6. Compute `Peak_imp_dev = |Peak_imp − mean(Peak_imp)|` per amplitude group
7. Compute motion per trial: `sum(mv_z, stim ± 1 s)`
8. Session-level spectrogram: Hann 2 s window, 1 s hop, 20 bands 0–10 Hz, **absolute power** (ΔF/F² Hz⁻¹)

**Key knob:** `peak_mode` at top of analysis section (currently 3).

---

## Transfer Function Fitting
Uses MATLAB System Identification Toolbox (`tfest`).

**Method:**
- Amplitude-normalised mean response: `h_norm = mean(DF_imp(validAmp, iPost) ./ uA_s(validAmp), 1)`
- Fitted as response to unit impulse (`iddata` with `u = [0…0, 1, 0…0]`)
- Sweep: `np` = 1..3 poles, `nz` = 0..min(np−1, 2) zeros (strictly proper), `nd` = 0..5 samples of transport delay (~0–143 ms at 35 Hz)
- Model selection by **AIC**; best model used for per-amplitude R² via `sim()`
- Residual analysis: `resid(data_fit, best_sys)` checks autocorrelation and cross-correlation with input
- **LOAO cross-validation**: for each valid amplitude, refit on remaining amplitudes; predict held-out → R²_loao table

**Knobs at top of TF section:** `selExp`, `maxPoles`, `maxZeros`, `maxDelay`

**Currently runs on `selExp = 3`** (AL_0033, 2025-01-29).

---

## Spatial Spread Analysis (added 2026-05-14)
- `brainMask_e`: 10% of max mimg intensity threshold
- `UU_brain_e`: SVD spatial matrix restricted to brain pixels
- Per-amplitude response maps in SVD space (peak window 0–200 ms minus baseline −500–0 ms)
- Threshold at 2×SD of pooled baseline maps → area-above-threshold → effective radius = √(area/π)
- Pixel scale: **0.173 mm/px**
- Export: 2-panel PDF — inhibition contours on mean brain image + effective radius vs amplitude

---

## Pre-Trial Variance Analysis (added 2026-05-13)
- Per-trial dF/F variance over 1 s pre-stimulus window (35 samples)
- Scatter: pre-trial variance vs |Peak_imp deviation| with Pearson r annotated
- Section 2: same plots after excluding top 25% trials by motion energy (75th-percentile threshold)
- Interactive: `varDetailCallback.m` (`utils/varDetailCallback.m`) — click a dot → 2-panel figure (dF/F trace + z-motion)

---

## Output Figures
| File | Content |
|------|---------|
| `paper/imp_single_<session>.pdf` | Mean traces per amplitude, session 3 |
| `paper/imp_response.pdf` | Mean ± SEM dose–response, linear fits, R² + slope annotated |
| `paper/imp_response_median.pdf` | Median ± 95th-percentile bounds dose–response |
| `paper/tf_data_vs_model_<mn>_<td>_en<N>.pdf` | Panel A: TF data vs model (3 representative amplitudes) |
| `paper/tf_loao_<mn>_<td>_en<N>.pdf` | Panel B: full-fit R² vs LOAO R² across amplitudes |
| `paper/imp_spatial_spread_<session>.pdf` | Contours + effective radius vs amplitude |

Figure standard: `paperFig(w, h)` helper, font 6 pt bold, `ItemTokenSize [6 6]`, `exportgraphics(..., 'ContentType','vector')`.

---

## Current Status
- [x] Dose–response figures (mean ± SEM and median ± 95th-percentile bounds)
- [x] R² and slope annotated on dose-response figures
- [x] 0-amp gap-fill events excluded from fits (bug fixed 2026-05-14)
- [x] Motion vs inhibition deviation scatter (interactive, per session)
- [x] Freq band power heatmap (absolute power, `hot` colormap, 98th-pctile clim)
- [x] TF fit working for session 3: `tfest` sweep, AIC selection, transport delay, per-amplitude R²
- [x] LOAO cross-validation working
- [x] Panel A and Panel B paper-quality figures
- [x] Spatial spread vs amplitude figure
- [x] varDetailCallback for interactive pre-trial variance scatter
- [ ] **Run TF fit across all 3 sessions; compare poles/zeros/gain between sessions**
- [ ] TF time constants: compare against OL step TF time constants (from `plottingScript.m %% OL step TF fit`)
- [ ] If LOAO gap at strong amplitudes is large → consider per-amplitude TF fits
- [ ] Confirm `stimStarts - 2` shift on Analysis_variable.m line 175 is still correct with mode 2

---

## Key Conventions
- Inhibition energy = integral of ΔF/F over 0–200 ms post-onset (Mode 3), not peak ΔF/F trough (Mode 2)
- Error bars: 95th-percentile bounds (2.5th–97.5th) on median plot, SEM on mean plot
- Power spectra: **absolute** (ΔF/F)² Hz⁻¹ — no normalization or z-scoring at any stage (decided 2026-05-11 with Nick)
- LOAO gap at strong amplitudes suggests amplitude-dependent dynamics — log if confirmed

---

## Open Questions
1. Do TF pole locations (time constants) agree across sessions? If yes, the LTI assumption holds for impulse data.
2. Do impulse TF time constants match the OL step TF time constants (`plottingScript.m`)? If yes, LTI holds across stimulus types.
3. Does pre-trial neural variance predict inhibition depth after motion exclusion? (r persisting in Section 2 would imply a brain-state effect separate from motion)
4. Does spatial spread grow linearly with amplitude, or does it saturate?

---

## Related Scripts / Utilities
- `utils/findStims.m` — stim detection (mode 1 for AL_0033/AL_0039; mode 2 for AL_0041)
- `utils/varDetailCallback.m` — interactive trial inspector for pre-trial variance scatter
- `paperFig.m` — figure size/format helper
- `../controller-analysis/` — OL step TF fit lives in `plottingScript.m`; compare time constants here
