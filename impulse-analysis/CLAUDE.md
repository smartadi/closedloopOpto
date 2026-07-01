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

## Stim site & display orientation — CANONICAL, do not re-flip (2026-06-29)
- **`params.pixel` is flip-prone** (load/save schemes swap x/y). DO NOT trust it for the site.
- **Laser/recording site = data-derived**, deepest focal inhibition in the trial-avg peri-stim
  map (`utils/cp_find_stim_site.m`; baseline −500→0 ms vs peak 0→200 ms, strongest amp).
  AL_0033 0129 e1 → **array [row 373, col 353]**; cached `data/cp_stim_site_AL_0033_0129_e1.mat`.
- **Correct view is TRANSPOSED** (brain vertical, `imagesc(mimg')`). The site is an ARRAY
  `(row,col)` (display-invariant). On a transposed axis, mark it `plot(row,col)` = `plot(px_prim,py_prim)`
  where **`px_prim`=row, `py_prim`=col**. (getpixel_dFoF's `mimg(pixel(2),pixel(1))` read put the
  pixel on the inhibition RIM = the old bug.)
- `contra_prediction.m` `[CP-SITE]` (knob `USE_DATA_SITE`) sets px/py_prim from the cache and
  re-extracts `y_full` at the site; footprint = `mimg(px_prim±k, py_prim±k)`. Markers in
  `[CP-KERNEL]`/`[CP-BLEED]` + explorers all use the `plot(px_prim,py_prim)` rule.
- TODO: replicate `cp_find_stim_site` on AL_0041 e1/e2; re-cache the explorer dumps (old A pixel).

## Residual / state-dependence workbench — PRIMARY ACTIVE STREAM (2026-06)
`contra_residual.m` — SECTIONED MATLAB workbench. Isolates the LOCAL stim effect = actual ipsi dip
− contra prediction (contra predicts the GLOBAL network activity flowing into the ipsi kernel), then
tests its brain-state dependence. Shared compute: `utils/cp_residual_core.m`. Run order:
1. `load_experiments.m` (builds `allExperiments`; reads SVD from server — slow).
2. `[CP-SETUP]` — builds `R`,`S` + the Actual/Global/Local decomposition. RUN FIRST.
3. then any section, in any order: `[CP-RESi]` (clickable per-trial inspector),
   `[CP-LOCAL]` (state×Actual/Global/Local overview), `[CP-MOTION]` (No-motion vs Motion),
   `[CP-MOTION-AMP]` (per-amplitude, fig-3 style, `amp_sig`='Actual'|'Global'|'Local'),
   `[CP-VAR]`, `[CP-DELTA]`, `[CP-BLEEDCTRL]` (bleed-artifact control on the state result).
- Helpers (utils/): `cp_agl.m`, `cp_cont_state.m`, `cp_motion_amp.m`, `cp_res_inspector.m`, `cp_bleed_control.m`.
- DV = **template-gain** `<r,μ>/<μ,μ>` (signed/directional; `R.gain`) + **L1-dev** (unsigned deviation; `R.devL1`),
  z-within-amp (2026-07-01, superseded `dev_stim`). Per-trial `R.bleed` (ipsi→contra leakage) + `R.catch`
  (amp-0 null) for `[CP-BLEEDCTRL]`.
- **A2 (2026-07-01): cp_residual_core now RETARGETS to the data-derived laser center** [row 373 col 353]
  (`opts.use_data_site=true`, default) — reverses the old "do not retarget". This MATERIALLY shifted the
  headline: at the true focus the signed template-gain effect collapses (PreVar −0.215→−0.080, PreDelta
  −0.217→−0.115) but **L1-dev is robust** (PreVar +0.213 p=9e-9, PreDelta +0.166 p=8e-6). ⇒ defensible
  finding is the PREDICTABILITY (L1-dev) effect, not directional size. **DV-primacy: revisit (L1 primary?).**
- **A4:** `opts.state_win='pre'` (strictly pre-onset [−1,0]s) reproduces 'peri' → no onset-span circularity.
- Bleed control at center: PreDelta confound rejected; PreVar bleed mildly state-dep (A1 +0.104) but gain
  survives control; catch null clean. cp_bleed_control still built on `R.gain` — re-run on L1 if DV swaps.
- Cross-session batch: `cp_state_batch.m`. Absolute dose-response (bleed comp ON): `cp_doseresponse.m`.
- selExp=3 (AL_0033) ROI cached in `impulse-analysis/data/`; AL_0041 e1/e2 need interactive ROI draw on first run.

### Residual-stream design decisions (do not silently change)
- `decontam=false` for STATE — stim-bleed comp subtracts a per-amplitude CONSTANT that CANCELS in
  within-amp deviations → state results identical with/without it. decontam=true ONLY for absolute
  magnitude (`cp_doseresponse.m`). Raw residual recovers ~21% of the dip (contra absorbs ~79% as bleed).
- `use_motion=false` — keep motion OUT of the contra map so it can be tested as a state.
- Inhibition-energy / dip window = **0–200 ms** (trough at 114 ms; 200–300 ms is post-dip REBOUND, not inhibition).
- DV = per-trial deviation from amp-mean (`dev_stim`). L1 (total abs deviation) is a cleaner PROPOSED
  replacement (var partial 0.100 p=0.007, delta 0.085 p=0.023) — NOT yet adopted; see RESEARCH 2026-06-20.

### Headline finding (AL_0033 single session — REPLICATION ON AL_0041 PENDING)
The LOCAL stim effect is state-ROBUST to motion. The "motion→more predictable" effect (motion_analysis
fig 6: median |Peak dev| No-mot 1.23 vs Mot 0.59, p=9e-11, a THRESHOLD effect) is GLOBAL — splitting via
contra puts it all in the Global component; the LOCAL residual is motion-NULL (partial ρ=+0.003 p=0.93,
inverts at high amp). Local effect's only retained state-dependence: weak pre-stim VARIANCE (partial
ρ=0.085 p=0.022) + borderline DELTA (0.073 p=0.051). Bridges the controller (CL motion→lower MSE) via the
low-variance desynchronized global state (motion↔variance ρ=−0.20). Full record: FINDINGS.md + RESEARCH.md 2026-06-19/20/22.

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
