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
- [x] 2026-07-16 — Methods states both RMSE windows (`methods_edit.tex` "Performance metric": full t=0→+3 s for per-trial/cross-session distributions; settled t=+1→+3 s only for disturbance rejection). Metric renamed MSE→RMSE same day.
- [ ] Run low-frequency spectral attribution (Fig 4 section): on motion-clean trials (z-motion ≤1.5), fraction of top-quartile high-error CL trials with elevated pre-stim 1–4 Hz absolute power (`ncFreqPow`/`wcFreqPow`); write results into Fig-4 `\todo`. Methods done (`methods.tex` sec:disturbance)
- [ ] Supplementary Fig S (`fig:lowfreq_examples`): AL to pick representative low-/high-error motion-clean CL trial spectra; placeholder in `methods.tex`

---

## 🟡 Next sprint

### Bilateral analysis — AL_0048 (new sub-area)
- [x] 2026-07-13 — **Dual-opsin impulse dose-response** (2026-07-10 block 5) analyzed via new Python sub-area `bilateral/impulse/` (reuses grid loader/calibration/SVD; run `bilateral/impulse/run_impulse.py`). Both opsins respond, opposite sign, dose-graded (excit peak +0.3→+2.1%; inhib dip ~−1.2% at high amp). See `bilateral/impulse/README.md` + RESEARCH 2026-07-13. Single session — needs replication + TF fit + sham-baseline recovery.
- [ ] Recover sham (amp 0) catch trials for the impulse dose-response via Block↔Timeline clock offset (no laser onset → not in detected onsets)
- [ ] TF-fit each side's AL_0048 impulse response (excit transient vs inhib dip time constants); compare to AL_0033/AL_0041 impulse TFs
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
- [x] 2026-07-13 — **Batch grid across ALL sessions × amps** (`bilateral/grid/run_grid_all.py`) → `grid_sessions/<date>/amp_<amp>/` + per-session `grid_sites.png` + cross-amp `amp_linearity.png`. Sessions/amps: 06-24 [0.5], 07-01 [0.25,0.5], 07-10 [1.0,2.0]. 07-10 clean dose-response (slope 1.39); 07-01 low-power SNR-limited (slope 0.19). RESEARCH 2026-07-13.
- [x] 2026-07-13 — Grid re-run on **2026-07-10 block 6** (WF=3): 5200 onsets, 52 sites, amps [1.0, 2.0] both fired (2600 each, 50/site). Added multi-block onset segmentation (`loader.segment_onsets` + config `ONSET_SEGMENT`) so the shared-Timeline impulse blocks are excluded. Registration + dual-opsin polarity clean. RESEARCH 2026-07-13.
- [x] 2026-06-25 — Python analysis runs end-to-end on 2026-06-24/2 (all notebook plots: sites/timecourses/τ/spatial/raster). Onsets+positions derived from raw Timeline + rig calibration; bregma dial-in confirmed; power split done (only 0.5 fired)
- [x] 2026-06-29 — Consolidated into `bilateral/grid/` and refactored the monolith into a clean Python module (`config`/`loader`/`analysis`/`plots`/`run_grid`); old script kept in `grid/legacy/`
- [~] 2026-07-13 — **Dynamical NETWORK model** on the 52-site tensor: `bilateral/grid/network_id.py`. Model ladder (all node-space graph-Laplacian + diagonal sign-free B except delay-DMD): **1st-order driven Laplacian** free −0.29 / self −1.04 — stable+interpretable, recovers opsin signs (77% hemisphere match), but monotone → structurally CANNOT rebound (proven); **2nd-order driven graph-wave** (`ẍ=−Lx−Γẋ+Bu`, k-NN local Laplacian, sim-error) free +0.28 / self +0.11 — oscillates (56 modes ~7–8 Hz), captures the rebound, sparse/stable/interpretable; **delay-DMD** free +0.64 — predictive ceiling, not a node Laplacian. Parsimony↔accuracy pair established. Figs: net_driven_laplacian.png, net_driven_wave.png. **Next:** choose paper framing (wave = mechanistic model + delay-DMD = ceiling) or push wave R² up (POD r / k-NN / per-node damping); validate multi-site superposition when data exists. RESEARCH 2026-07-13.
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

#### ⚠ Reviewer-proofing the residual state claim (red-team 2026-07-01) — do BEFORE submission
> Anticipated referee objections to the Actual/Global/Local decomposition + state-dependence, ranked. Tier 1 = can sink it; Tier 2 = serious, answerable; Tier 3 = will be asked, cheap.
- [ ] **[T1] Hemodynamic confound** — single-wavelength widefield ΔF/F conflates neural + blood-volume/arousal signals; the dip, the 95% contra co-suppression, AND the variance/δ state effects could be partly hemodynamic (arousal is strongly vascular). State the correction used (dual-wavelength/isosbestic 405, or regression); if none, add a hemodynamic robustness control. **Biggest exposure.**
- [ ] **[T1] n=1** — headline is one session/one mouse; ρ=9e-9 is trial-level (pseudoreplication for an animal claim). Needs AL_0041 replication + animal-as-random-effect model. (Overlaps the PRIMARY item above.)
- [ ] **[T1] "Local is a modeling residual, not a mechanism"** — Local≡Actual−Global and |Local| scales with predictor capacity (CP-STIMAFF showed resDip↑ as R²↓). Show the +0.213 PreVar effect is STABLE across rank/K/#modes (not just its magnitude) → argues state-dependence is not a modeling artifact. **Tractable now.**
- [ ] **[T2] DV-selection / forking paths** — L1-dev promoted to primary AFTER template-gain collapsed at the retarget. Report BOTH DVs everywhere; frame the rim→center switch as principled (A2/A4) up front, not post-hoc.
- [x] **[T2] Variance/δ state-dep — ⚠ CONFIRMED = SIGNAL-POWER CONFOUND (2026-07-01, two tests)** — (i) stim vs no-stim: devL1(stim)≈devP(no-stim), excess≈0 → not stim-specific. (ii) direct non-stim confirmation (534 spontaneous windows): direction FLIPS by metric — relative predictability corr(actual,pred) vs PreVar=+0.77 (UP), absolute error mean|res|(=devL1) vs PreVar=+0.31 (UP). Root cause: PreVar=var(y)=signal's own power, entangled with every residual metric. The variance/δ "local state-dependence" is a magnitude confound in EITHER direction; the earlier reframe was WRONG in direction. Motion result stands (behavioral, power-independent). RESEARCH 2026-07-01.
  - [ ] **DROP** the variance/δ "local response is state-dependent" claim built on devL1/devP/devS (magnitude confound). Update FINDINGS.md headline + manuscript §pre-stim brain state.
  - [ ] **[required, not optional]** Re-do any predictability-vs-state test with a POWER-INDEPENDENT state: **pupil**, behavioral **motion**, or a **normalized spectral ratio** (relative δ = δ/total), NOT absolute PreVar/PreDelta.
  - [ ] (optional salvage) descriptive result on spontaneous data: inter-hemispheric R² is HIGHER in high-variance/synchronized states (+0.77) — only if the signal-power confound is explicitly flagged.
  - [ ] Productionize the stim-vs-no-stim + non-stim metric-flip tests as a `[CP-PREDQ]` control section (helper `cp_predq.m`).
- [ ] **[T2] Spont→stim generalization** — Global is trained on inter-stim windows, applied during stim; if coupling is non-stationary the error lands in Local. Show contra↔ipsi coupling is stable across the spont/stim boundary.
- [ ] **[T2] Motion-null may be underpowered** — motion effect is a THRESHOLD effect (fig 6) tested here with a linear partial (−0.046). Re-test motion per-component with the median-split/threshold framing before claiming "Local is motion-independent".
- [ ] **[T3] cheap defenses** — direct laser/optical artifact (amp-0 catch is clean; ideally no-opsin control); multiple-comparison correction (3 states×3 comps×2 DVs); hyperparameter stability (K=50/rank19/200 modes/pX=0); one-sentence mechanistic story for "higher pre-stim variance → less predictable local response".
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

### ⭐ PORT the TF stim-blind contra→ipsi model into CONTROLLER trials (Actual/Global/Local under control) — NEW 2026-07-13
> **GOAL:** apply the stim-blind contra→ipsi predictor from `impulse-analysis/ols_tf_pipeline.m` during controller trials to
> predict the ipsi site FROM CONTRA ALONE = the counterfactual ipsi "as if no controller/laser input". Then per trial:
> **Global** = contra-prediction (ongoing network state), **Actual** = measured controlled ipsi, **Local = Actual − Global** =
> the controller's own contribution. Bridges the impulse Actual/Global/Local decomposition to the controller MSE /
> disturbance-rejection story. Groundwork: scaffold `controller-analysis/contra_prediction_controller.m`
> (`[CTRL-CP-SETUP/TRIAL/STATE]`) + `utils/cp_hemi_predictor.m`; and TASKS line "generalize contra→ipsi framework".
- [ ] **[BLOCKER — check FIRST] Full-frame widefield SVD availability** for the 13 controller sessions. The stim-blind predictor needs contra PIXELS (U/V or `redoSVD`), not just the ipsi-kernel `states.csv`. Confirm which controller sessions are `redoSVD`-able (the scaffold already uses `redoSVD` → at least some are). List usable sessions; if limited, port only to those.
- [ ] Cache `cp_stim_site_*` + `cp_roi2_*` (midline + contra mask) per usable controller session (draw ROI once) — same inputs the impulse pipeline expects.
- [ ] Build the STIM-AFFECTED contra map on the session's OPEN-LOOP step trials (fixed-amp laser ≈ impulse) with the ols_tf_pipeline detector (§10/§10T/§10T2) → unaffected contra pixel set. NOTE: CL laser is time-varying, so build the bleed map from OL fixed steps and assume the same pixels bleed (amplitude-scaled) in CL — flag this assumption.
- [ ] Train **Global** = contra→ipsi OLS on SPONTANEOUS (inter-trial, laser-off) frames using only unaffected pixels; per session.
- [ ] Implement `[CTRL-AGL]` in `contra_prediction_controller.m`: per trial (OL and CL) compute Actual, Global (counterfactual no-input ipsi), Local = Actual − Global. Baseline-align per trial (mean-center; carry the existing set-point fix — [CTRL-CP-TRIAL] [NEXT] item above).
- [ ] Analyses: (a) **CL vs OL Local** → controller authority beyond network state; (b) **Global's deviation from ref** = the disturbance the controller must reject → correlate with per-trial MSE; (c) does the controller shrink Local variance / does Global explain residual tracking error?
- [ ] Package the stim-blind predictor as ONE reusable function callable from BOTH impulse and controller (subsumes the line "Generalize the contra→ipsi setup into a reusable framework"). Candidate: promote the ols_tf_pipeline stim-blind core into `utils/`.
> Caveats: spont→control coupling stationarity (same reviewer concern as impulse); CL time-varying bleed; single-wavelength hemodynamic confound carries over.

### OLS pixel-predictor stim-blind decomposition (`impulse-analysis/ols_pixel_predictor_wip.m`) — NEW workbench, 2026-07-08
> Single-session (AL_0033 2025-01-29 e1) so far. Three stim-blind models: **GREEDY** (§17, sparse — LEFT AS-IS per AL), **NATIVE** (§17b, all-unaffected px + KKT dip+rebound blinding, `native_nblind` auto-tuned=2), and **NAIVE** (§17b2, FIXED 3.7 V pixel config reused across amps — **current best model**). State-dependence reframed as VARIABILITY (§17c2): Rel-δ held-out ρ=+0.113, perm p=0.025. RESEARCH 2026-07-07/08.
> **UPDATE 2026-07-13:** detection reworked to **TF-based** (§10T learns a canonical TF order from sampled pixels → §10T2 fits every pixel at that FIXED order → `affected_tf`; §10T3 = TF click-debug map). NATIVE stays primary stim-blind model; NAIVE retired. Clean linear rewrite lives in **`impulse-analysis/ols_tf_pipeline.m`** (setup→TF-detect→stim-blind→state-dep→batch; explorers in appendix; TF-map disk cache). WIP `ols_pixel_predictor_wip.m` kept as reference. UNVERIFIED — needs a clean run.
- [ ] **[PRIMARY-NEXT] TF affected-detection SENSITIVITY** (`ols_tf_pipeline.m` §10T/§10T2) — misses real affected pixels because the fixed-order TF is SLUGGISH vs the sharp real dip. Plan (P1+P3 first): **(P1)** fit + score VAF on the **DIP window** (onset→recovery ~0–350 ms / §15 landmark), not the full 0–1000 ms — the noisy rebound tail blunts the fit + depresses VAF; **(P3)** **OR-gate**: affected if the TF matches OR a sensitive dip-shape criterion fires (matched-filter cosine of the pixel dip vs reference dip > 0 V null) — rescues pixels the TF underfits; **(P2)** give bandwidth (allow a zero/underdamped pole, re-learn canonical order on the dip window, optionally per-pixel delay∈{0,1,2}); **(P4)** learn the reference from the STRONGEST amp (sharpest); **(P5)** noise-weighted VAF; then re-tune vafFloor+matchTol on the §10T3 debug set. Symptom seen on the affected plot: genuinely-responsive regions dropped.
- [ ] **[superseded] Keep iterating on STIMBLIND-NAIVE** — NAIVE retired 2026-07-13 (dominated by NATIVE+nblind=4; ref-amp sweep proved it). Kept for history; do not resume unless reopened.
- [ ] **Zhiwen-style weight plot on the FIRST (sparse OLS) model** — pick a few ipsi-side regions (laser-site pixel + 2–3 others) and render their most prominent CONTRA weights as a spatial map, à la Zhiwen Ye 2023; shows what contra structure predicts each ipsi region.
- [ ] **State the EXACT unaffected-pixel characterization** used by all stim-blind models — currently the §10 matched-filter AFFECT gate: per-amp, affected = (signed z > 2.0) AND (cosine-to-dip-template > 0.40) AND (evoked peak ≤ 700 ms); unaffected = complement. Write this precisely into Methods + the script header so the predictor set is reproducible/defensible.
- [ ] **Validate STATEDEP-VAR (Rel-δ variability, p=0.025) for the paper** — this IS the power-independent state result the reviewer-proofing block below asked for (drop abs-var/δ magnitude confound → use relative δ). Replicate across AL_0041 e1/e2 + other sessions, animal-as-random-effect, FDR across states×sessions, then write into results §"Pre-stimulus brain state shapes predictability" (results.tex L64–68, currently a `\todo` stub). Promote to FINDINGS.md once replicated.
- [ ] (session-left, 2026-07-08) All of the above is SINGLE-SESSION — run headless across allSelExp for cross-session. Greedy untouched by design. NATIVE M3 held-out rebound capture is weak (6–38%; dip generalizes far better) — flag in any rebound claim. `ols_pixel_predictor_wip.m` committed to `alpha` this session; not yet merged into the tracked `ols_pixel_predictor.m`.

### New analyses
- [ ] Implement three-layer contralateral prediction model (pink/orange/red) — see FINDINGS.md — `plottingScript.m`
- [ ] Implement Curto & Issa-style trial-sorting figure (synced vs desynced by pre-stim variance) — `plottingScript.m`
- [ ] Add pre-stim variance vs MSE finding to manuscript (results paragraph + K2 figure reference) — FINDINGS.md entry exists
- [ ] Add motion vs MSE (closed vs open loop, cross-session) panel to manuscript
- [ ] Add sine-wave (preview/feedforward) control results section + figure — `Analysis_variable.m`

### Figure fixes
- [ ] Make mean dot smaller in all-sessions MSE violin (panel 3H) — `plottingScript.m`
- [ ] Generate spatial spread supplementary panel (ΔF/F inhibition area vs laser power) — cite Nuoli/Svoboda
- [x] 2026-07-16 — Verify Fig 3H shows MSE (not MAE): it shows **MAE** — `step_response.m` computes `abs(mean error)` over time; caption "Mean absolute tracking error per unit time" is already CORRECT. No change.
- [ ] Verify Fig 2C shading is ±1 SD — update caption if not

### Paper figure consistency pass (whole-manuscript, 2026-07-08)
- [ ] **Colorblind-safe version of ALL figures** — add a colorblind palette/template to `utils/paperStyle.m` (Wong/Okabe-Ito 8-color or ColorBrewer), and re-export every panel through it; keep a switch so both the standard and colorblind versions can be produced.
- [x] 2026-07-16 — **Unify the error-metric label → RMSE everywhere** (user decision). Text: `methods_edit.tex` (metric definition now "RMSE = √(cost/N)", theory cost stays squared) + `results.tex` (captions 3E/3G/3J, motion caption, body) — grep-clean, zero bare MSE/RMS in live tex. Code labels: `variance_mse.m`, `analysisPlots_combined.m`, `motion_mse_significance.m`. Fig 3H = deliberate exception (genuinely MAE; axis fixed 'MSE dF/F'→'MAE dF/F'). **Bigger find:** `er_ncDfk` was `norm()` = un-normalised ‖e‖₂ (=RMSE·√N), not MSE *or* RMS → normalised in `controllerData.m`. No conclusion changes (constant rescale). RESEARCH 2026-07-16.
  - [x] 2026-07-16 — **Caches rebuilt + 3E/3G/3J re-exported** (MATLAB). Migrated all 13 caches in place from `data.dFk` (proven pure ×1/√106 rescale); re-ran `load_sessions.m`+`variance_mse.m`. Pooled OL 3.11 / CL 2.44 %ΔF/F. RESEARCH 2026-07-16. ⚠ manuscript composites (`Figure3_extra.pdf`) are Illustrator-assembled — still need AL to re-copy the new panels.
- [ ] **Add units to every short-corner-axis figure** — `paperStyle` corner axes use `XLabel`/`YLabel` scale bars (e.g. '1 s','3%'); several panels don't set them yet. Audit all figures and add the missing unit labels.
- [x] 2026-07-16 — **Fig 2A impulse-response variance shading added** — `trace_overlay.m` now draws a per-amplitude ±1 SD ribbon (`std(dfImp,0,1)`, `FaceAlpha = PS.fa`, two-pass so means sit on top), matching the caption L48 claim. PAPER.md 2A shading "—"→"±1 SD". Code-analyzer clean. **RE-EXPORTED 2026-07-16** (`load_experiments.m` → `trace_overlay.m`; dfImp 196×211 aligns t_win). Eyeball: 5 overlapping ±SD bands a bit busy at PS.fa=0.2 — drop alpha if muddy. RESEARCH 2026-07-16.

### Prose
- [x] 2026-07-16 — Convert passive voice to active throughout results (setup paragraph rewritten; OL-variance-slope sentence → "We quantified…"; rest of Results was already active). `results.tex`.
- [x] 2026-07-16 — Standardise figure citation style to `Fig. 1A` (fixed lone inline "Figure~\ref" on L41; all live-file refs now "Fig.~". Remaining "Figure~" are only in ORPHAN `methods.tex`, not `\input` by `main.tex`).
- [x] 2026-07-16 — Remove equation references from Results prose (grep-verified: none present — already clean).
- [ ] Add n and ± CI to all slope estimates in linearity paragraph — BLOCKED: needs fit CIs from the impulse dose-response fit (`dose_response.m`); n=3 already stated. Can't fabricate CIs — run the fit to emit slope ± CI, then add.

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
- [ ] **Make a video of the real-time controller setup** (Rainier rig) — a demo/supplementary clip showing the closed-loop controller running live. Likely easier to reconstruct on THIS PC from data we already have (replay the controller code against a recorded session) than to film the rig; check whether the online loop can be re-driven offline to render a real-time-looking animation.


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
