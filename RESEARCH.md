# Brain Paper — Research Coordination

## Project Context
Mouse widefield closed-loop PI controller vs open-loop analysis.  
Controller uses kernel average of a cortical region as output; PI controller drives input.  
Two mice: AL_0033 (8 sessions), AL_0039 (3 sessions), Jan–Apr 2025.

**Core question:** Does the closed-loop controller reduce neural variability and error compared to open-loop?

**Secondary questions:** Do closed-loop trials inform us about neural interactions through motion analysis, freq power markers and wide brain activity?

---

## plottingScript.m — Cross-session analysis

This script loads all sessions, computes per-trial error metrics, and generates paper figures F–H plus supplementary motion analysis.

### Data & Loading
- [x] Session list defined (m1–m13, two mice AL_0033 / AL_0039)
- [x] `initialize_data` + `getpixel_dFoF` + `controllerData` pipeline working
- [ ] Confirm all 13 sessions load without errors — check which sessions hit the `catch` block

### Figure F — Cross-session variance
- [x] Mean variance trace NC (open-loop, red) vs WC (closed-loop, green) across sessions
- [x] Export → `paper/all_variance_sessions.png`
- [ ] Verify y-axis range `[-2 12]` is appropriate for all sessions combined

### Figure G — Cross-session MSE violin
- [x] Per-session violin (ksdensity) with mean marker
- [x] Export → `paper/all_MSE_sessions.png`
- [ ] Check `er_ncDfk` / `er_wcDfk` field access — loop uses `.data.er_ncDfk` (no `_l` suffix); confirm this is populated by `controllerData`

### Figure H — All-session trial average (MSE over time)
- [x] Per-session faint traces + bold cross-session mean
- [x] Export → `paper/all_average_sessions.png`
- [ ] Time axis mismatch: `t1_h` has `dur+6` seconds of points but bold mean uses `t_h` (0 to dur only) — reconcile or confirm intentional

### Step response — selected sessions
- [x] Mean ± std shaded trace for `custom_idx = [4 9 11]`
- [x] Variance overlay + session mean line during trial
- [x] Export → `paper/step_response.png`
- [ ] Decide: hard-code `custom_idx` or make it a parameter at top of script

### Spontaneous variance vs batch size
- [x] Bootstrap variance convergence across batch sizes 10–100
- [x] Min-max normalized curves per session
- [x] Export → `paper/spont_variance.png`
- [ ] `custom_idx = randperm(13, 3)` is random each run — pin to fixed indices for reproducibility

### Motion vs MSE
- [x] Three analysis windows: combined (2s pre + trial), pre-trial (3s), during-trial
- [x] Per-session scatter with linear fit
- [x] Pooled quartile plot (Q1–Q4 motion bins)
- [x] Export → `paper/motion_scatter_*.png`, `paper/motion_quartile_*.png`
- [ ] Sessions without face video are silently skipped — add a summary print of which sessions have motion data

### Raw motion traces
- [x] All-session overlay
- [x] Export → `paper/motion_traces.png`

### Interactive motion scatter
- [x] Click-to-inspect per trial (calls `scatterClickCallback`)
- [ ] `scatterClickCallback` must be defined — confirm it exists in `utils/`


### Freq vs trial MSE analysis

**Goal:** How does spectral content during a trial relate to MSE? Compare OL vs CL.  
**Data already available:** `controllerData` stores `data.ncFreqSpec` / `data.wcFreqSpec` as `[nTrials × W_freq × 20]` — 20 bands from 0–10 Hz at 0.5 Hz resolution, already normalized as band/total power ratios. No extra computation needed.  
**Window:** 1s pre-onset to end of trial → bins `freqOnsetBin-1 : freqOnsetBin+dur-1` of the stored W_freq dimension (`freqOnsetBin = 7`).


**Remark:** I want to confirm that impulse dataset shows effect of freq band power on stim at the time of stim 

**Normalization:** relative power only (band/total) — no z-scoring. Color limits from 98th percentile of pooled data to clip outliers.

- [x] **Step 1 — Figure I: Per-session heatmap** — OL|CL side by side per session, shared color scale, interactive click → `paper/freq_heatmap_sessions.png`
- [x] **Step 2 — Figure J: Combined heatmap** — all sessions pooled, raw MSE sort → `paper/freq_heatmap_combined.png`
- [x] **Step 3 — Interactive Figure I** — click any row → `heatmapClickCallback.m` + `plotSingleTrial.m` (trace / motion / input / spectrogram)



---

## primary_mouseDataAnalysis.m — Single-session analysis
- [ ] *(Add tasks here)*

## Impulse_mouseDataAnalysis_all.m — Impulse experiments

### What this script does
Characterises the cortical inhibitory response to brief optogenetic impulses across a range of stimulus amplitudes, and asks whether trial-to-trial variability in that response is predicted by pre-stimulus motion state.

**Pipeline per session:**
1. Load widefield SVD data, z-score motion trace (`mv_z = zscore(d.motion.motion_1(1:2:end))`)
2. Detect stimulus events, fill gaps, bin by amplitude → `uAmp` / `idxByAmp`
3. Extract pixel dF/F from SVD (`F/mI*100`)
4. For each amplitude group, align ±3s windows around each stim onset (baseline-subtracted at onset)
5. Compute `Peak_imp` per trial — two switchable methods (`peak_mode`):
   - **Mode 2** (default): value at per-trial min within ±143 ms of trial-average trough — captures latency jitter
   - **Mode 3**: mean dF/F over 0–500 ms post-onset — integrates total inhibition energy
6. Compute `Peak_imp_dev = |Peak_imp − mean(Peak_imp)|` per amplitude group — trial-to-trial deviation
7. Compute motion per trial: `sum(mv_z, stim±2s)` — z-scored motion energy around stim

**Output figure:** scatter of motion energy vs inhibition deviation, all sessions × amps, colored by session → `paper/imp_motion_vs_deviation.png`

**Also in script (commented out):** parametric TF fitting (1- and 2-pole with dead time, AIC model selection, cross-amplitude LOAO validation)

### Current state
- [x] 3 sessions: AL_0041 (2×), AL_0033 (1×)
- [x] `peak_mode` switch at top of analysis section
- [x] Motion figure working and exported
- [ ] System ID section (TF fitting) commented out — needs validation before use
- [ ] Freq analysis not yet implemented — planned next
## Grid_mouseDataAnalysis.m — Controller tuning grid
- [ ] *(Add tasks here)*

## Analysis_variable_split_double.m — Variable reference
- [ ] *(Add tasks here)*

## Analysis_openloop_sinsusoid.m — Open-loop sinusoid
- [ ] *(Add tasks here)*

---

## Findings Log

| Date | Script | Finding |
|------|--------|---------|
| 2026-05-05 | plottingScript.m | Initial audit — 13 sessions across 2 mice, figures F/G/H + motion analysis implemented. Open items flagged above. |
| 2026-05-05 | Impulse_mouseDataAnalysis_all.m | Motion and freq band power loading refactored to match `controllerData.m`: `mv = d.motion.motion_1(1:2:end)`, session-level spectrogram (hann 2s, 1s hop, 20 bands), per-trial spectrogram slice replaces per-trial `pwelch`. Added motion vs inhibition scatter/quartile plots. |
