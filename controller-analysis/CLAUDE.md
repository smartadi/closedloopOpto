# Controller Analysis — Research Context

## Goal
Characterise and compare closed-loop (CL, WC) vs open-loop (OL, NC) neural dynamics across all sessions using widefield imaging. Two complementary aims:

1. **PI controller performance**: Does closed-loop control reduce neural error (MSE) and variance relative to open-loop? Does CL decouple trial outcome from pre-stimulus brain state?
2. **Neural interactions / brain state**: Can motion, frequency-band power, and wide-brain activity explain trial-to-trial variability? Do these relationships differ between OL and CL?

The controller is a discrete-time PI that uses the kernel average of a cortical ROI as feedback, driving optogenetic input. This work directly supports the paper's Results section.

---

## Data
- **13 sessions total**: m1–m13
  - AL_0033: 8 sessions (m1–m8 approximately, Jan–Mar 2025)
  - AL_0039: 3 sessions (m9–m11 approximately, Apr 2025)
  - 2 additional sessions (m12–m13) — details in `plottingScript.m` session list
- Sampling: 35 Hz widefield, 2 kHz input (resampled to 35 Hz for TF fits)
- Reference: `d.ref = -5` (percent ΔF/F); default fallback if not in cache

---

## Primary Scripts

### `plottingScript.m` (root, ~100 KB, last modified 2026-05-15)
Cross-session analysis. Loads all sessions, computes per-trial error metrics, and generates all paper figures F–H plus motion, frequency, widebrain, and TF sections.

**Session loading pipeline:**
```
initialize_data → getpixel_dFoF → controllerData → cache to data/<session>.mat
```
Cache check: `isfield(tmp, 'd')` — if missing, reinitializes and re-saves.

**Key figures produced:**

| Figure | File | Content |
|--------|------|---------|
| F | `paper/all_variance_sessions.png` | Cross-session variance trace (OL red, CL green) |
| G | `paper/all_MSE_sessions.png` | Per-session violin (ksdensity) with mean marker |
| G2a | `paper/MSE_window_comparison.pdf` | Full window vs t=+1 to +3 s windowed MSE violin |
| G2b | `paper/MSE_vs_trial_number.pdf` | Windowed RMS MSE vs trial number per session |
| H | `paper/all_average_sessions.png` | Per-session faint traces + bold cross-session mean |
| Step | `paper/step_response.png` | Mean ± std shaded trace for sessions [4 9 11] |
| Spont | `paper/spont_variance.png` | Bootstrap variance convergence, batch 10–100 |
| Motion | `paper/motion_scatter_*.png`, `paper/motion_mse_combined.pdf` | Motion vs MSE scatter + combined |
| I | `paper/freq_heatmap_sessions.png` | Per-session OL\|CL spectral heatmap |
| J | `paper/freq_heatmap_combined.png` | All-session pooled MSE-sorted spectral heatmap |
| J2 | `paper/freq_heatmap_motionclean.png` | Same as J, motion-clean (|z-motion| ≤ 1.5) |
| K1/K2 | `paper/freq_heatmap_prestimvar.png`, `paper/prestimvar_mse.pdf` | Pre-stim variance sort (3 s window) |
| K1m/K2m | `paper/freq_heatmap_prestimvar_motclean.png`, `paper/prestimvar_mse_motclean.pdf` | K1/K2 motion-clean |
| K1w/K2w | `paper/freq_heatmap_pretrial_var.png`, `paper/pretrial_var_mse.pdf` | Pre+trial variance sort (6 s window) |
| WB | `paper/wb_prediction.pdf` | 4-panel: spont snippet / OL mean / CL mean / residual |
| OL TF | `paper/ol_tf_three_sessions.pdf` | OL step TF fit for sessions [4 9 11] |

**Key knobs:**
- `custom_idx = [4 9 11]` — sessions for step response and OL TF fit (m4=AL_0033 2025-02-26, m9=AL_0039 2025-04-20, m11=AL_0039 2025-04-30)
- `ol_sess_idx = [4 9 11]` — same sessions for OL TF fit loop
- `motThresh = 1.5` — z-motion exclusion threshold for J2/K1m/K2m
- `selField = 10` — session for SVD frame export

### `Analysis_variable.m` (root, ~6.7 KB, last modified 2026-05-13)
Variable reference (feedforward / preview controller) single-session analysis.
- Bregma click now **cached**: saves to `paper/bregma_<mn>_<td>_en<N>.mat`; set `rerun_click = true` to force re-click
- Uses `findStims(d, 2)` (mode 2, absolute stim index) for AL_0041 sessions
- `sessTag = mn_td_enN` passed to `analysisPlots_var_paper` for per-session PDF names
- Plots exported to `paper/single_trial_var_<sessTag>.pdf`, `paper/trial_avg_var_<sessTag>.pdf`, etc.

### `Analysis_variable_split_double.m` (root, ~18 KB) — variable reference, split-double variant

### `Analysis_openloop_sinusoid.m` (root, ~19 KB) — open-loop sinusoidal input analysis

### `Grid_mouseDataAnalysis.m` (root, ~8.6 KB) — controller tuning grid analysis

### `primary_mouseDataAnalysis.m` (root, ~11 KB) — single-session closed-loop analysis

### `OL_opt_mouseDataAnalysis.m` (root, ~23 KB) — open-loop optimal controller analysis

### `latencyAnalysis.m` (root, ~7 KB) — characterises 14–50 ms latency; staircase pattern is beat-frequency artefact (trial interval vs 35 Hz frame clock)

### `define_midline.m` (root, ~2.3 KB) — interactive tool to define cortical midline; saves `midline.mat`

---

## Key Utilities (project-specific, in `utils/`)
Do not modify `utils/Pipelines`, `utils/widefield`, `utils/Rigbox`, `utils/npy-matlab` (external dependencies).

| File | Role |
|------|------|
| `utils/controllerData.m` | Loads/caches session data; computes `er_ncDfk`/`er_wcDfk` (MSE), `ncFreqSpec`/`wcFreqSpec` (relative), `ncFreqPow`/`wcFreqPow` (absolute ΔF/F² Hz⁻¹), `ncFreqBands`/`wcFreqBands`; stores `pncDfk_l`/`pwcDfk_l` (pre+trial buffered traces) |
| `utils/analysisPlots_combined.m` | Per-session combined figure (single trial, trial avg, variance, inputs); `d.ref` fallback = −5 |
| `utils/analysisPlots_var_paper.m` | Variable reference paper plots; adaptive ylims; per-session PDFs via `sessTag` |
| `utils/findStims.m` | Mode 1 (AL_0033/AL_0039): subtract horizon. Mode 2 (AL_0041): use absolute index directly |
| `utils/buildLagMatrix.m` | ARX lag matrix builder for widebrain prediction |
| `utils/varDetailCallback.m` | Interactive trial inspector for variance scatter (new 2026-05-13) |

---

## MSE Windowing Convention
- **Full window**: t = 0 to +3 s (all trial), stored as `er_ncDfk`/`er_wcDfk`
- **Nick's window** (2026-05-08): t = +1 s to +3 s — skips initial inhibitory transient, measures error once controller has had time to act. Stored as `er_ncDfk_w`/`er_wcDfk_w` in `mouse` struct after G2 section runs.

---

## Widebrain Prediction (ARX model)
**Goal:** Show contralateral brain activity predicts primary pixel; OL residual = opto effect alone; CL residual = opto + controller.

**Pipeline:**
1. Run `define_midline.m` → save `midline.mat`
2. Pixel selection: contralateral primary (midline reflection) + 9 pseudo-random grid pixels from contralateral polygon ROI (saved to `contra_pixels.mat`; set `redefine_roi=false` to skip on rerun)
3. Build lag matrix via `buildLagMatrix` (pY=5, pX=3)
4. Fit ARX on 6 s pre-trial spontaneous windows (all NC+WC trials pooled)
5. Apply to OL/CL trial windows; compute residual = actual − predicted
6. Target: R²_spont > 0.3; tune `contra_step`/`contra_R`/`pY`/`pX` if not met

---

## Frequency Analysis Conventions
- **Absolute power only**: (ΔF/F)² Hz⁻¹ — no normalization, no z-scoring at the data level (decided 2026-05-11 with Nick). Field: `ncFreqPow`/`wcFreqPow`.
- Relative power (`ncFreqSpec`/`wcFreqSpec`) kept in cache for backward compatibility only.
- Display: colormap `parula` for heatmaps; `clim` set from 98th percentile of pooled data to clip outliers.
- Freq bins: 20 bands, 0–10 Hz, 0.5 Hz resolution. `freqOnsetBin = 7` marks stim onset.
- Sessions without face video are silently skipped in motion-exclusion sections.

---

## Current Status
- [x] All 13 sessions loading (cache fix for stale `d`-less files done 2026-05-08)
- [x] Figures F, G, H exported
- [x] Step response (sessions [4 9 11]) exported
- [x] Motion analysis (per-session + combined pooled scatter)
- [x] Freq heatmaps I, J, J2 (absolute power)
- [x] Pre-stim variance sort K1/K2/K1m/K2m/K1w/K2w/K2i/K2iw
- [x] G2 windowed MSE violin + trial-number scatter
- [x] Widebrain ARX prediction (contra pixels, midline.mat exists, contra_pixels.mat exists)
- [x] OL step TF fit loop over 3 sessions (`paper/ol_tf_three_sessions.pdf`)
- [ ] **Verify R²_spont > 0.3 for widebrain ARX; interpret OL vs CL residuals**
- [ ] Confirm `custom_idx = randperm(13, 3)` in spont variance pinned to fixed indices for reproducibility
- [ ] Compare K2 OL vs CL slopes — flat CL slope = controller decoupling pre-stim state from outcome
- [ ] Compare K1 vs J trial ordering — are MSE rank and pre-stim variance rank correlated?
- [ ] Add Curto & Issa-style trial-sorting figure (Nick, 2026-05-11): split synced vs. desynced by ~1 s pre-stim variance; sort by |ΔF/F| at t=0; display heatmaps

---

## Open Analyses from MEETINGS.md
- [ ] **Three-layer contralateral-prediction model** (Nick, 2026-05-11):
  - Pink: predict ipsilateral ROI from contralateral pixels in spontaneous data
  - Orange: + average OL impulse response on top
  - Red: + exact per-trial laser sequence via TF model → compare to CL traces
- [ ] **Post-hoc optimal laser sequence**: given the red model, compute MPC-optimal sequence; quantify gap vs actual controller; frame as MPC motivation
- [ ] Motion as co-predictor in pink/red models (2026-05-11)
- [ ] Fraction of high-error CL trials attributable to 2–4 Hz fluctuations vs motion (2026-05-08)
- [ ] Feedforward/preview (sine-wave) control results section + figure — deferred since 2026-04-27
- [ ] Follow up with Zilu on ARIMA/forecasting; with Tim Kim on latent-space model (2026-04-27)
- [ ] Latency staircase artefact: verify beat-frequency numerically (trial interval vs 1/35 s) before writing up

---

## Key Decisions Made
- MSE window for final paper: t = +1 s to +3 s (Nick, 2026-05-08)
- Power spectra: absolute (ΔF/F)² Hz⁻¹, no relative normalization (Nick, 2026-05-11)
- `d.ref = -5` as project-wide default reference level
- Figure standard: `paperFig(w, h)`, font 6 pt bold, `ItemTokenSize [6 6]`, `exportgraphics(..., 'ContentType','vector')`
- Inhibition energy = integral of ΔF/F over 0–200 ms (agreed 2026-05-08), not peak trough
