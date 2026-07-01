# TASKS.md — Prioritized TODO

Single source of truth for open work. Updated after each session or meeting.
Findings that are done live in FINDINGS.md. Meeting context lives in MEETINGS.md.
Freeform thinking + diary lives in JOURNAL.md (Claude gleans tasks from it).

---

## ✅ Recently done (rolling — last ~10, oldest pruned to RESEARCH.md)

<!-- When a task is completed, move it here with a date before deleting. -->
- [x] 2026-07-01 — Impulse residual: DV → **L1-dev primary** (template-gain secondary); retargeted to laser center [373,353] (A2); pre-onset-window (A4) + bleed-artifact controls pass; `[CP-KRECON]` sparse-kernel reconstruction added. Committed to `alpha` (101a9b9, 3ec2e0c). Retired `contra_residual.m`.
- [x] 2026-06-29 — Manuscript: variance-onset claim rewritten with −0.57 slope (`results.tex` L59)
- [x] 2026-06-29 — Manuscript: Kp/Ki/Kr placeholders filled (Kr=0.1, Kp=0.07, Ki=0.1; `results.tex` L96)
- [x] 2026-06-29 — Manuscript: variance-convergence paragraph now shows per-trial mean stationarity, not just shrinking variance (`results.tex` L61)
- [x] 2026-06-29 — Manuscript: linearity claim softened to "well approximated by a linear relationship" (`results.tex` L57)
- [x] 2026-06-29 — Manuscript: broken cross-refs `(??)`/`(Section )`/`Algorithm ??` all resolved (grep-clean)
- [x] 2026-06-15 — Set up JOURNAL.md diary layer + Recently-done section (project-management refactor)

---

## Impulse Prediction plan
- Use pre-trial contralateral widebrain activity to predict pre-trial(stim- 6sec to stim-(1frame)) ipsi lateral pixel(primary pixel kernel which we use for df/f). This is a one to one mapping where we are not forecasting but just using contra to predict ipsi
- Use this learning mapping we will predict the impulse response(stim-1sec to stim +2sec) of primary pixel. The impulse is applied near primary pixel so it does not affect the contra region. Now taking the contralateral activity we will get a baseline activity of ipsi during trial without impulse response added, so we will use the learned tf model to predict the impulse response by adding it to the prediction.
- Note that contra hemishpere may see effects of impulse as some impulse activity may bleed over, I want to figure out if this is happening and then come up with a plan to predict activity during stim as if stim was not actually there(from contra).

## 🔴 Blocking submission

### Manuscript text
> NOTE: primary results file is now `results.tex` (the old `results_edit.tex` name is retired). Most manuscript-text 🔴 items verified done 2026-06-29 → see ✅ Recently done.
- [ ] Step-response paragraph (`results.tex` L59): rewritten + integral-term motivation present, but does NOT explicitly state the 3 s window is too short to observe steady state. Confirm whether that caveat is still wanted; add one sentence if so.
- [ ] Fill in author names and affiliations — `main.tex` L62 (blocked on AL input)
- [ ] Three remaining content `\todo` gaps in `results.tex`: §pre-stim brain state (L64–68), §low-freq spectral attribution (L112), §contra→ipsi prediction (L130) — see "Analysis still needed" below.
- [ ] Add Chrimson spatial-spread citation — `methods_edit.tex` L292 `\todo` (Nuo Li / Svoboda). NOT in refs.bib yet; needs exact paper from AL before adding a bib entry (do not fabricate).

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
- [ ] Fill in session registry in `bilateral/load_bilateral.m` as experiments are collected
- [ ] Confirm `BREGMA_COL` (input_params column for galvo bregma X) and set in `load_bilateral.m`
- [ ] Decide stim detection mode (`STIM_MODE`: A / B / C) once first session is inspected
- [ ] Confirm reference polarity from first experiment; adjust `SIGN_L` / `SIGN_R` if needed
- [ ] Run `ol_characterization.m` on first impulse + step sessions → get OL time constants per side
- [ ] Run `cl_constant_ref.m` → baseline CL MSE per side
- [ ] Run `cl_tuning.m` → grid sweep + gradient descent for optimal Kp/Ki per side
- [ ] Run `cl_sinewave.m` → feedforward benefit quantification
- [ ] Run `compare_sides.m` → cross-side summary figure

### AL_0048 galvo photostim site-grid (`opto_brainGrid638`) — see `bilateral/grid/README.md`
- [x] 2026-06-25 — Python analysis runs end-to-end on 2026-06-24/2 (all notebook plots: sites/timecourses/τ/spatial/raster). Onsets+positions derived from raw Timeline + rig calibration; bregma dial-in confirmed; power split done (only 0.5 fired)
- [x] 2026-06-29 — Consolidated into `bilateral/grid/` and refactored the monolith into a clean Python module (`config`/`loader`/`analysis`/`plots`/`run_grid`); old script kept in `grid/legacy/`
- [ ] (optional) aggregate stim→response **causal/connectivity map** across the 52 sites (N×N or per-region readout) — beyond per-site `grid_spatial.png`; per-trial dF/F available via `analysis.compute_site_responses`
- [ ] 0.25-power map not recoverable here (laser sub-threshold) — if low-power data wanted, need a session where the 638 command clears the lasing threshold at 0.25; confirm with experimenter whether 0.25 was expected to fire
- [ ] (optional) parameterize loader for other `opto_brainGrid` sessions / the 594 line
- [ ] if promoted to a paper panel: move outputs out of `bilateral/grid/grid_png` and apply `paperFig`/`paperStyle`

### Controller tuning — gain grid + auto-tuning (new sub-area, secondary analysis)
Full state + data-layout findings → `controller-tuning/CLAUDE.md`. Data model RESOLVED 2026-06-27 (RESEARCH). **Wrapping up.**
- [x] 2026-06-27 — Rig data model resolved + `ct_load_session` rewired: y=`states.csv` (% ΔF/F @35 Hz, glitch-clipped); layout auto-detected by #cols (8-col onset@2/Kp@5/Ki@6/ref=−col7; 7-col Timeline onsets w/ auto-calibrated states lag).
- [x] 2026-06-28 — Final grid set = **4** (AL_0033 01-10/03-03/03-05 + AL_0034 10-17 cross-mouse); 03-17 → autotune (trajectory); 10-18 held (signal not regulatable). Headline panel `grid_cost_surfaces_4sessions.png`.
- [x] 2026-06-29 — **Methods written** (`methods_edit.tex` sec:gain_opt): grid + zeroth-order auto-tuning folded in; `fig:cost_landscape` now = real panels A(grid 03-05)/B(grid 10-17 cross-mouse)/C(autotune both mice); `eq:rms_cost` added; `alg:zo` corrected; panels copied to `Closedloop_edit/images/tuning/`. Cost window for 10-17 = **[0 4]** (decided).
- Tuning is **Methods-only** (AL 2026-06-29) — no Results writeup, no main figure number; lives as `fig:cost_landscape`. PAPER.md updated.
- [x] 2026-07-01 — Verified via local latexmk compile: all 3 `images/tuning/*.pdf` panels render, clean 29-page main.pdf. (Also fixed 2 surfaced blockers: `refs.bib` duplicate keys + `discussion.tex` `eq:controller`→`eq:pi`.)
- [ ] confirm AL_0034 is introduced at first mention (13-session set names only AL_0033/AL_0039).
- [ ] Add `\label{sec:disturbance}` in `methods_edit.tex` (disturbance/motion methods) so the low-freq `\todo` ref resolves; optionally delete orphan `methods.tex`/`introduction_temp.tex`.
- [ ] **[deferred] getdfof recompute for AL_0034 10-18** — extract the raw widefield from the 165 GB `.rar`, recompute kernel-mean dF/F at pixel[390,390] via getdfof (independent of the online states.csv), re-test for a stim-locked dip / dose-response → settle biology-vs-online-pipeline. Only if 10-18 is specifically needed.

### Contra→ipsi prediction framework (impulse) — from JOURNAL 2026-06-16
> **STATE (2026-07-01):** the residual workbench lives in `impulse-analysis/contra_prediction.m` (sectioned: `[CP-SETUP]`→`[CP-RESi]`/`[CP-LOCAL]`/`[CP-MOTION]`/`[CP-MOTION-AMP]`/`[CP-VAR]`/`[CP-DELTA]`/`[CP-BLEEDCTRL]`/`[CP-KRECON]`; core `utils/cp_residual_core.m`). Retargeted to the laser center [373,353]; **DV = L1-dev (predictability) primary**, template-gain secondary. Findings + design in FINDINGS.md ("Local photoinhibition response is state-robust to motion") and `impulse-analysis/CLAUDE.md`. (The old `contra_residual.m` was retired/deleted 2026-07-01.)
- [ ] **[PRIMARY] Replicate the residual state-dependence on AL_0041 e1/e2** — first localize each site (`cp_find_stim_site`, cache `cp_stim_site_*`) so the retarget inherits, then run `load_experiments.m` + `contra_prediction.m` sections with `selExp`=1 then 2 (draw midline+contra ROI on first run). Single-session (AL_0033) result needs replication before any claim. Cross-session driver: `cp_state_batch.m`.
- [ ] **Reconcile fig-6 sign tension** — reproduced peakdev fig 6 shows motion→LESS deviation (more predictable), contradicting paper panel-2F finding "motion→greater deviation". Check cperr-vs-peakdev metric difference or sign error; fix the 2F claim. See FINDINGS.md ⚠ note.
- [ ] Re-cut the figure-2 state panels (`cp_var_residual`/`cp_delta_residual`/`cp_local_state`) at the retargeted site with the L1-dev DV for the manuscript.
- [ ] Solidify ONE prediction approach on non-stim data: benchmark current instantaneous OLS vs Zhiwen Ye 2023 method vs PCA-based; pick the winner on held-out spontaneous R² — `impulse-analysis/contra_prediction.m`
- [ ] Compare against Ye et al. 2023 instantaneous contra→ipsi code/method directly (`C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals\`) — confirm our pX=0 map matches their formulation
- [ ] Per-trial prediction error → brain-state mapping (JOURNAL 2026-06-16). Define prediction = contra_pred (pink) + TF impulse for that amplitude (red); error = deviation of actual trial from red over stim..stim+200ms (0-200ms dip window). Map error to motion AND motion-excluded pre-stim variance / delta power. NOTE: CP-4 in contra_prediction.m ALREADY computes red4=pink+TF, per-trial err4, and covariates (mot4, pvar4, dpow_pre4, dpow_stim4) — but err window is 0-1s (change to 0-200ms) and pink uses old full-kernel decontam (reconcile to α=1 baseline). This REPLACES the old per-trial error = deviation from trial-averaged-response-per-amp method.
- [ ] Generalize the contra→ipsi setup into a reusable framework callable from controller-level analysis (not just impulse)
- [ ] (decision pending) TF fit on the residual dip → add learned impulse response on top of the contra prediction at trial level

### Contra predictability of trials (controller) — NEW, scaffold ready
> Scaffold: `controller-analysis/contra_prediction_controller.m` (`[CTRL-CP-SETUP]`/`[CTRL-CP-TRIAL]`/`[CTRL-CP-STATE]`). Reuses the Zhiwen-faithful predictor (`utils/cp_hemi_predictor.m`) + `cp_roi_masks`/`redoSVD` UNCHANGED. Deferred until the impulse predictor is locked. RESEARCH 2026-06-29.
- [ ] **[NEXT] Baseline-align per trial in `[CTRL-CP-TRIAL]`** — subtract the pre-stim `iPre` mean from BOTH actual `ya` and predicted `yp` before `r2`/`resE`. The Zhiwen map is mean-centered (CanonCor2 centers Y/X, `aKern` has no intercept) → it predicts deviations, carries no DC; CL's controller-imposed set-point (`dFk`→ref=−5) would otherwise inflate `resE` / deflate `r2` and fake "CL less contra-predictable". `rho` is already offset-invariant. Mirror `cp_residual_core` baseline handling (`A=ya−bl_a`, `Pr=yp−bl_p`).
- [ ] Confirm DV + OL-vs-CL contrast with Nick before running (current scaffold: contra-predicted pre-stim state→MSE slope, OL vs CL = decoupling test for open Q2 / K2 slopes).
- [ ] On first run verify units: `cp_hemi_predictor` field→kernel reconstruction vs `data.dFk` (both %ΔF/F) → sane held-out R²; `d.params.kernel` present (fallback k_prim=2).

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
