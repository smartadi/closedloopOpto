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

### Contra→ipsi prediction framework (impulse) — from JOURNAL 2026-06-16
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
