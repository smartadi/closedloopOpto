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
`contra_prediction.m` — SECTIONED MATLAB workbench (the residual/state sections were merged in
from the now-retired `contra_residual.m`, deleted 2026-07-01). Isolates the LOCAL stim effect =
actual ipsi dip − contra prediction (contra predicts the GLOBAL network activity flowing into the
ipsi kernel), then tests its brain-state dependence. Shared compute: `utils/cp_residual_core.m`. Run order:
1. `load_experiments.m` (builds `allExperiments`; reads SVD from server — slow).
2. `[CP-SETUP]` — builds `R`,`S` + the Actual/Global/Local decomposition. RUN FIRST.
   (`[CP-HEMI]`+`[CP-KERNEL]` must run first if you want `[CP-KRECON]`.)
3. then any section, in any order: `[CP-RESi]` (clickable per-trial inspector),
   `[CP-LOCAL]` (state×Actual/Global/Local overview), `[CP-MOTION]` (No-motion vs Motion),
   `[CP-MOTION-AMP]` (per-amplitude, fig-3 style, `amp_sig`='Actual'|'Global'|'Local'),
   `[CP-VAR]`, `[CP-DELTA]`, `[CP-BLEEDCTRL]` (bleed-artifact control), `[CP-KRECON]` (pixel-isolated reconstruction: predict from only the top-weight contra pixels; coupling is DISTRIBUTED not focal — `cp_pixel_recon.m`), `[CP-CLEAN]` (S12, marries KRECON×BLEED: predict from BLEED-FREE contra pixels — bleed & predictive maps DISJOINT ρ=−0.06, drop all bleed px → R² unchanged 0.865; `cp_clean_predict.m`), `[CP-CLEANRES]` (S13, deploy the bleed-free predictor on STIM trials: NON-STIM R² 0.865=0.865, peri-stim residual dip full −1.119 ≈ bleed-free −1.132 (both ~73% of −1.557 actual), per-amp gap ≤0.03 → local stim residual is NOT a bleed-absorption artifact; `cp_cleanres.m`), `[CP-STIMAFF]` (S14, "bleed-free" robustness: the [CP-BLEED] SLOPE test discards the amp-INVARIANT onset deflection — recovering it shows ~95% of contra co-suppresses (network coupling, not bleed); excluding the most onset-responsive px deepens the residual ONLY by degrading prediction — resDip-vs-R² curve coincides with RANDOM exclusion, so it's predictor-loss not bleed; amp-graded SLOPE is the correct bleed-specific test (bleed scales w/ power); `cp_stimaffect.m`), `[CP-PREDQ]` (S15, CLICKABLE: spontaneous contra→ipsi R² vs brain state — Motion ρ=−0.01 NULL (power-indep), Variance +0.79 / abs-δ +0.67 (power-CONFOUND), Relative-δ +0.29 (power-indep genuine) ⇒ predictability motion-invariant, higher in synced states; WHY the var/δ "local stim state-dep" was a signal-power confound; click a point → window actual/prediction/mean-corrected; `cp_spont_predq.m`).
- Helpers (utils/): `cp_agl.m`, `cp_cont_state.m`, `cp_motion_amp.m`, `cp_res_inspector.m`, `cp_bleed_control.m`, `cp_clean_predict.m`, `cp_cleanres.m`, `cp_stimaffect.m`, `cp_spont_predq.m`.
- **`ols_pixel_predictor.m`** — STANDALONE direct-pixel (no-lag) contra→ipsi OLS predictor (separate from the RRR pipeline). Sectioned; run after `load_experiments.m`. **REVERTED 2026-07-06 to the HEAD/2026-07-04 projection version** (§17 [AGL-STIMBLIND] PRIMARY: spont-trained OLS with the per-amp stim-dip coupling subspace projected out → Global carries ongoing state, residual/Local = full stim effect; §18 [BESTPRED] SECONDARY ceiling; §15 [SETTLETIME] `dip_win_s=0.300`; §16 [FARPIX]; §19 all-session headless; §20 SESSION-VIEWER). The 2026-07-06 per-amp-pixel-selection experiment was found WRONG and moved OUT of this canonical file.
  - **`ols_pixel_predictor_wip.m`** (untracked) — WIP repair copy where the stim-blind is being rebuilt FROM SCRATCH. **Diagnosis (2026-07-06):** per-amp "clean-pixel" selection does the OPPOSITE of the goal — network-correlated clean contra pixels still predict every detail of the ipsi dip, so Global absorbs the stim effect and the residual is near-empty. GOAL: find the contra pixel set / constraint whose prediction is BLIND to the stim so the residual captures ~100% of the ipsi stim effect (dropping directly-bled pixels by energy is insufficient — must remove the stim-PREDICTIVE direction). Also: FARPIX positive population is likely a non-effect; SETTLETIME should also capture the rebound (mostly gone by ~770 ms). Do stim-blind experiments in the WIP copy, not here.
  - Bleed is amplitude-dependent (absent ≤1.1 V, present ≥1.6 V — confirms Nick). See RESEARCH 2026-07-06 + 2026-07-03/04.
- **⚠ var/δ "local stim state-dependence" RETRACTED (2026-07-02): signal-power confound (`PreVar=var(y)`). Admissible states = motion (null) + relative-δ (+0.29). See [CP-PREDQ] + RESEARCH 2026-07-01/02.**
- **⚠⚠ relative-δ +0.29 does NOT replicate (2026-07-02): `cp_zhiwen_predq.m` on Ye/Zhiwen `AB_0004` gives relative-δ ρ=−0.25 (robust: −0.33 median, 99% of 150 sensory px NEGATIVE) — OPPOSITE sign. Variance/abs-δ confounds DO replicate (+0.74/+0.34). ⇒ the one "power-independent genuine" predictability-state effect is prep/task-specific, not a general law. Motion-null untested on his data (no motion trace). Don't rest a paper claim on relative-δ predictability. See RESEARCH 2026-07-02.**
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
