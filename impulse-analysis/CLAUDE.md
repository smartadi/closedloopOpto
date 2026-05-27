# Impulse Analysis — Session Context

## Primary script
`Impulse_mouseDataAnalysis_all.m` (root, ~1748 lines) — monolithic script, still in active use; run section-by-section in MATLAB.

## Split scripts (impulse-analysis/ — run after load_experiments.m)
- `load_experiments.m` — experiment array, full data loading loop, `allExperiments` struct
- `trace_overlay.m` — single-session dF/F trace overlay
- `dose_response.m` — combined dose-response across experiments
- `tf_fit.m` — transfer function fitting (tfest sweep), LOAO cross-validation
- `motion_analysis.m` — motion vs inhibition depth, motion-sorted figures
- `spectral_heatmap.m` — interactive frequency heatmap
- `prestim_variance.m` — pre-trial variance vs peak deviation, paper figure
- `spatial_spread.m` — spatial spread vs amplitude

## Data
- 3 sessions: AL_0041 (experiments 1 & 2), AL_0033 (experiment 3, 2025-01-29)
- AL_0041 → stim mode 2 (`input_params(:,2)` = absolute sample index)
- AL_0033 → stim mode 1 (relative index, subtract `horizon`)
- Gap-fill events stamped at amplitude 0 — excluded via `nzMask = xpos_raw > 0`

## Key knobs (top of script)
- `peak_mode` — currently **3** (inhibition energy, 0–200 ms mean)
- `selExp` — currently **3** (AL_0033, 2025-01-29) for TF fit
- `maxPoles`, `maxZeros`, `maxDelay` — TF sweep bounds

## Locked-in decisions (see root CLAUDE.md for full list)
- Inhibition energy = mean ΔF/F over 0–200 ms post-onset (NOT peak trough)
- Error bars: 95th-percentile bounds on median plot; SEM on mean plot
- Power spectra: absolute (ΔF/F)² Hz⁻¹, no normalization

## Open questions (see TASKS.md for priority)
1. Do TF poles/time constants agree across all 3 sessions?
2. Do impulse TF time constants match OL step TF constants from `plottingScript.m`?
3. Does LOAO gap at strong amplitudes → amplitude-dependent dynamics?
4. Does pre-trial variance predict inhibition depth after motion exclusion?

## Paper figures exported to
`paper/images/figure2/` — panels 2A, 2B, 2C, 2F (single session), 2F-pool
