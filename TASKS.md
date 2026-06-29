# TASKS.md — Prioritized TODO

Single source of truth for open work. Updated after each session or meeting.
Findings that are done live in FINDINGS.md. Meeting context lives in MEETINGS.md.
Freeform thinking + diary lives in JOURNAL.md (Claude gleans tasks from it).

---

## ✅ Recently done (rolling — last ~10, oldest pruned to RESEARCH.md)

<!-- When a task is completed, move it here with a date before deleting. -->
- [x] 2026-06-15 — Set up JOURNAL.md diary layer + Recently-done section (project-management refactor)

---

## Impulse Prediction plan
- Use pre-trial contralateral widebrain activity to predict pre-trial(stim- 6sec to stim-(1frame)) ipsi lateral pixel(primary pixel kernel which we use for df/f). This is a one to one mapping where we are not forecasting but just using contra to predict ipsi
- Use this learning mapping we will predict the impulse response(stim-1sec to stim +2sec) of primary pixel. The impulse is applied near primary pixel so it does not affect the contra region. Now taking the contralateral activity we will get a baseline activity of ipsi during trial without impulse response added, so we will use the learned tf model to predict the impulse response by adding it to the prediction.
- Note that contra hemishpere may see effects of impulse as some impulse activity may bleed over, I want to figure out if this is happening and then come up with a plan to predict activity during stim as if stim was not actually there(from contra).

## 🔴 Blocking submission

### Manuscript text
- [ ] Fix "stimulation onset did not affect variance" claim — rewrite using FINDINGS.md result (post-onset slope −0.57 ± 0.24) — `results_edit.tex` L50
- [ ] Soften linearity claim to "peak response scales approximately linearly" — `results_edit.tex` linearity paragraph
- [ ] Fix step-response tension: state window too short to observe steady state — `results_edit.tex` L49
- [ ] Fix variance-convergence paragraph: show batch mean stabilises, not just shrinking variance — `results_edit.tex` L52
- [ ] Fill in actual Kp and Ki gain values (currently [X] placeholders) — `results_edit.tex` L89
- [ ] Fix all broken cross-references `(Section )`, `(??)`, `Algorithm ??` throughout draft
- [ ] Fill in author names and affiliations — `main.tex` L63–67

### Analysis still needed for text
- [ ] Run TF fit across all 3 impulse sessions; compare poles/time constants between sessions — `Impulse_mouseDataAnalysis_all.m`
- [ ] Relax TF delay τ; report R² on held-out 20% test set (Nick, 2026-05-08)
- [ ] Verify widebrain ARX R²_spont > 0.3; interpret OL vs CL residuals — `plottingScript.m`
- [ ] Confirm Methods states both MSE windows: general trial MSE = t=0→+3 s; disturbance-rejection panel = t=+1→+3 s
- [ ] Run low-frequency spectral attribution (Fig 4 section): on motion-clean trials (z-motion ≤1.5), fraction of top-quartile high-error CL trials with elevated pre-stim 1–4 Hz absolute power (`ncFreqPow`/`wcFreqPow`); write results into Fig-4 `\todo`. Methods done (`methods.tex` sec:disturbance)
- [ ] Supplementary Fig S (`fig:lowfreq_examples`): AL to pick representative low-/high-error motion-clean CL trial spectra; placeholder in `methods.tex`

---

## 🟡 Next sprint

### Bilateral analysis — AL_0048 (new sub-area)
- [ ] Fill in session registry in `bilateral-analysis/load_bilateral.m` as experiments are collected
- [ ] Confirm `BREGMA_COL` (input_params column for galvo bregma X) and set in `load_bilateral.m`
- [ ] Decide stim detection mode (`STIM_MODE`: A / B / C) once first session is inspected
- [ ] Confirm reference polarity from first experiment; adjust `SIGN_L` / `SIGN_R` if needed
- [ ] Run `ol_characterization.m` on first impulse + step sessions → get OL time constants per side
- [ ] Run `cl_constant_ref.m` → baseline CL MSE per side
- [ ] Run `cl_tuning.m` → grid sweep + gradient descent for optimal Kp/Ki per side
- [ ] Run `cl_sinewave.m` → feedforward benefit quantification
- [ ] Run `compare_sides.m` → cross-side summary figure

### AL_0048 galvo photostim site-grid (`opto_brainGrid638`) — see `scratch_grid/README.md`
- [x] 2026-06-25 — Python port `scratch_grid/grid_analysis.py` runs end-to-end on 2026-06-24/2 (all notebook analysis plots: sites/timecourses/τ/spatial/raster). Onsets+positions derived from raw Timeline + rig calibration; bregma dial-in confirmed; power split done (only 0.5 fired)
- [ ] (optional) aggregate stim→response **causal/connectivity map** across the 52 sites (N×N or per-region readout) — beyond per-site `grid_spatial.png`; per-trial dF/F already stashed in `dff_by_site`
- [ ] 0.25-power map not recoverable here (laser sub-threshold) — if low-power data wanted, need a session where the 638 command clears the lasing threshold at 0.25; confirm with experimenter whether 0.25 was expected to fire
- [ ] (optional) parameterize loader for other `opto_brainGrid` sessions / the 594 line
- [ ] if promoted to a paper panel: move outputs out of `scratch_grid/grid_png` and apply `paperFig`/`paperStyle`

### Controller tuning — gain grid + auto-tuning (new sub-area, secondary analysis)
Full state + data-layout findings → `controller-tuning/CLAUDE.md`. Data model RESOLVED 2026-06-27 (RESEARCH). **Wrapping up.**
- [x] 2026-06-27 — Rig data model resolved + `ct_load_session` rewired: y=`states.csv` (% ΔF/F @35 Hz, glitch-clipped); layout auto-detected by #cols (8-col onset@2/Kp@5/Ki@6/ref=−col7; 7-col Timeline onsets w/ auto-calibrated states lag).
- [x] 2026-06-28 — Final grid set = **4** (AL_0033 01-10/03-03/03-05 + AL_0034 10-17 cross-mouse); 03-17 → autotune (trajectory); 10-18 held (signal not regulatable). Headline panel `grid_cost_surfaces_4sessions.png`.
- [ ] **Pick the primary cost-surface paper panel** (recommend 03-05 interior min; 03-03 fuller coverage; 10-17 cross-mouse) → add to PAPER.md, export PDF, write Results/Methods sentences.
- [ ] **Decide cost window for 10-17** (dur=4 there) — keep [0 3] s for consistency, or [0 4].
- [ ] **[deferred] getdfof recompute for AL_0034 10-18** — extract the raw widefield from the 165 GB `.rar`, recompute kernel-mean dF/F at pixel[390,390] via getdfof (independent of the online states.csv), re-test for a stim-locked dip / dose-response → settle biology-vs-online-pipeline. Only if 10-18 is specifically needed.

### Contra→ipsi prediction framework (impulse) — from JOURNAL 2026-06-16
> **STATE (2026-06-22):** the residual workbench `impulse-analysis/contra_residual.m` (sectioned: `[CP-SETUP]`→`[CP-RESi]`/`[CP-LOCAL]`/`[CP-MOTION]`/`[CP-MOTION-AMP]`/`[CP-VAR]`/`[CP-DELTA]`; core `utils/cp_residual_core.m`) is BUILT and is the active version. It supersedes the old CP-4 `err4` per-trial-error route. Findings + design in FINDINGS.md ("Local photoinhibition response is state-robust to motion") and `impulse-analysis/CLAUDE.md`.
- [ ] **[PRIMARY] Replicate the residual state-dependence on AL_0041 e1/e2** — run `load_experiments.m` then `contra_residual.m` sections with `selExp`=1 then 2 (draw midline+contra ROI on first run). Single-session (AL_0033) result needs replication before any claim. Cross-session driver: `cp_state_batch.m`.
- [ ] **Decide L1 vs dev_stim** as the deviation DV in `cp_residual_core.m` — L1 (total absolute deviation) tested cleaner (var partial 0.100 p=0.007, delta 0.085 p=0.023 vs dev_stim 0.085/0.073); if adopted, replace dev_stim/dev_pre with L1 forms (propagates to all sections). See RESEARCH 2026-06-20.
- [ ] **Reconcile fig-6 sign tension** — reproduced peakdev fig 6 shows motion→LESS deviation (more predictable), contradicting paper panel-2F finding "motion→greater deviation". Check cperr-vs-peakdev metric difference or sign error; fix the 2F claim. See FINDINGS.md ⚠ note.
- [ ] **Commit residual-workbench work to `alpha`**: `contra_residual.m` (restructure) + new `utils/cp_agl.m`, `cp_cont_state.m`, `cp_motion_amp.m` + RESEARCH.md entries + `paper/images/figure2/cp_*` figures.
- [ ] Solidify ONE prediction approach on non-stim data: benchmark current instantaneous OLS vs Zhiwen Ye 2023 method vs PCA-based; pick the winner on held-out spontaneous R² — `impulse-analysis/contra_prediction.m`
- [ ] Compare against Ye et al. 2023 instantaneous contra→ipsi code/method directly (`C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals\`) — confirm our pX=0 map matches their formulation
- [ ] Per-trial prediction error → brain-state mapping (JOURNAL 2026-06-16). Define prediction = contra_pred (pink) + TF impulse for that amplitude (red); error = deviation of actual trial from red over stim..stim+200ms (0-200ms dip window). Map error to motion AND motion-excluded pre-stim variance / delta power. NOTE: CP-4 in contra_prediction.m ALREADY computes red4=pink+TF, per-trial err4, and covariates (mot4, pvar4, dpow_pre4, dpow_stim4) — but err window is 0-1s (change to 0-200ms) and pink uses old full-kernel decontam (reconcile to α=1 baseline). This REPLACES the old per-trial error = deviation from trial-averaged-response-per-amp method.
- [ ] Generalize the contra→ipsi setup into a reusable framework callable from controller-level analysis (not just impulse)
- [ ] (decision pending) TF fit on the residual dip → add learned impulse response on top of the contra prediction at trial level

### New analyses
- [ ] Implement three-layer contralateral prediction model (pink/orange/red) — see FINDINGS.md — `plottingScript.m`
- [ ] Implement Curto & Issa-style trial-sorting figure (synced vs desynced by pre-stim variance) — `plottingScript.m`
- [ ] Add pre-stim variance vs MSE finding to manuscript (results paragraph + K2 figure reference) — FINDINGS.md entry exists
- [ ] Add motion vs MSE (closed vs open loop, cross-session) panel to manuscript
- [ ] Add sine-wave (preview/feedforward) control results section + figure — `Analysis_variable.m`

### Figure fixes
- [ ] Make mean dot smaller in all-sessions MSE violin (panel 3H) — `plottingScript.m`
- [ ] Generate spatial spread supplementary panel (ΔF/F inhibition area vs laser power) — cite Nuoli/Svoboda
- [ ] Verify Fig 3H shows MSE (not MAE) — update caption accordingly
- [ ] Verify Fig 2C shading is ±1 SD — update caption if not

### Prose
- [ ] Convert passive voice to active throughout results ("We delivered…", "We quantified…")
- [ ] Standardise figure citation style to `Fig. 1A` (not `Figure 1(A)`) throughout
- [ ] Remove remaining equation references from Results prose
- [ ] Add n and ± CI to all slope estimates in linearity paragraph

---

## 🟢 Deferred / waiting

- [ ] **Controller analysis result caching** — avoid recomputing ARX fits, TF fits, and cross-session pooled arrays on every run. Proposed structure: `data/<session>wb_model.mat` (ARX `beta_m`, `pY/pX/grid_rows/grid_cols`, R²_train/test, TF fit object + time constants), `data/<session>wb_pred.mat` (pink/orange/red trial predictions + R²s + WB-5 MSEs), `cross_session_cache.mat` (motion quartile arrays, pre-stim dev/MSE, spectral aggregations, contributing sessions list). Each section checks whether cached params match current params before recomputing. See RESEARCH.md 2026-05-27 for full struct design.
- [ ] Post-hoc optimal laser sequence (MPC motivation) — depends on three-layer model — see FINDINGS.md
- [ ] Add motion energy as co-predictor in contralateral prediction models
- [ ] Fraction of high-error CL trials attributable to 2–4 Hz fluctuations vs motion
- [ ] Latency staircase artefact: verify beat-frequency numerically (trial interval vs 1/35 s) before writing up
- [ ] Disturbance-rejection only comparison (last 2 s of trial, activity settled) — OL vs CL
- [ ] Freq analysis: use absolute power values in manuscript framing (not ratios/normalisation)
- [ ] Controller performance vs initial state at stim onset: per-trial MSE vs |ΔF/F at t=0| scatter
- [ ] Optional: insert fixed 2 ms pause in processing code to verify ~14 ms minimum latency shifts
- [ ] Follow up with Zilu on ARIMA/forecasting models
- [ ] Prepare widefield dataset for Tim Kim latent-space model; arrange joint meeting


---

## Cross-area diagram (static reference)

```
Impulse_mouseDataAnalysis_all.m
  → TF poles / time constants
     ↓ compare
plottingScript.m §OL step TF fit
  → same LTI model, step input
     ↓ both feed
Paper: linearity claim (Results §1)
  + controller performance (Results §2–3)
     ↓
Closedloop_edit/ → Overleaf → submission
```

Impulse TF time constants should match OL step TF time constants.
If they agree → validates LTI assumption across stimulus types.
