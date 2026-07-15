# Controller Analysis — Session Context

## ⭐ Incoming port (added 2026-07-13) — READ TASKS.md before starting
A **TF-based stim-blind contra→ipsi predictor** now exists in `impulse-analysis/ols_tf_pipeline.m`
(TF affected-detection → predict the ipsi site from contra pixels). **Plan: port it into controller trials**
to decompose the controlled ipsi into **Global** (contra-predicted = counterfactual "no controller input")
+ **Local** (the controller's own effect). See the **"⭐ PORT the TF stim-blind contra→ipsi model into
CONTROLLER trials"** block in `TASKS.md` for the full step list. Groundwork: scaffold
`controller-analysis/contra_prediction_controller.m` (`[CTRL-CP-SETUP/TRIAL/STATE]`).
**FIRST check (blocker):** full-frame widefield SVD availability for the 13 controller sessions
(the predictor needs contra PIXELS via `redoSVD`, not just the ipsi-kernel `states.csv`).

## Primary script
`plottingScript.m` (root, ~3557 lines) — monolithic script, still in active use; run section-by-section in MATLAB.

## Split scripts (controller-analysis/ — run after load_sessions.m)
- `load_sessions.m` — session struct, data loading loop, variance aggregation, `tp`/`Mean_var` setup
- `variance_mse.m` — OL/CL variance, MSE violin, windowed MSE (Figs F, G)
- `step_response.m` — trial-averaged dF/F, step response (Fig H)
- `motion_analysis.m` — pre-stim state vs MSE, motion vs MSE, onset deviation
- `spectral_mse_sort.m` — dF/F heatmaps sorted by delta power (J4) or variance (J5)
- `prestim_variance.m` — pre-stim dFk variance as trial sort key (K figures)
- `trial_state_mse.m` — merged figure J6: variance + delta power both vs MSE on same trial pool (from pncDfk_l + ncFreqPow); tests "high trial variance → high MSE, same trials show high delta"
- `widebrain_arx.m` — contralateral ARX model, OL TF fit, WB prediction layers

## Other scripts
- `Analysis_variable.m` — variable reference (feedforward/preview), single session
- `Analysis_variable_split_double.m` — split-double variant
- `Analysis_openloop_sinusoid.m` — OL sinusoidal input
- `primary_mouseDataAnalysis.m` — single-session CL analysis
- `OL_opt_mouseDataAnalysis.m` — OL optimal controller

## Session loading pipeline
`initialize_data → getpixel_dFoF → controllerData → cache to data/<session>.mat`
Cache check: `isfield(tmp, 'd')` — if missing, reinitialise and re-save.

## Key knobs (top of plottingScript.m or load_sessions.m)
- `custom_idx = [4 9 11]` — sessions for step response and OL TF fit
- `ol_sess_idx = [4 9 11]` — OL TF fit loop sessions
- `motThresh = 1.5` — z-motion exclusion threshold for motion-clean figures
- `selField = 10` — session for SVD frame export

## Key utilities
- `utils/controllerData.m` — loads/caches; stores `er_ncDfk_w`/`er_wcDfk_w` (windowed MSE), `ncFreqPow`/`wcFreqPow` (absolute power), `pncDfk_l`/`pwcDfk_l` (pre+trial buffered traces)
- `utils/analysisPlots_combined.m` — per-session combined figure (panels A–E)
- `utils/findStims.m` — mode 1 (AL_0033/AL_0039), mode 2 (AL_0041)

## Locked-in decisions (see root CLAUDE.md for full list)
- Error metric = **RMSE** (sample-normalised, %ΔF/F) — 2026-07-15, supersedes "MSE" naming. `er_ncDfk`/`er_wcDfk` = `norm(seg-ref)/sqrt(numel(seg))`; previously un-normalised `norm()` (=RMSE·√N), so **caches built before 2026-07-15 hold the OLD ‖e‖₂ values — rerun `load_sessions.m` with `r_ctrl = 0` once to rebuild**. Constant rescale ⇒ all ratios/z-scores/slopes/p-values unchanged; only axis scale + units.
- RMSE window: **t = 0 s to +3 s** default (`er_ncDfk` / `er_wcDfk`); **t = +1 s to +3 s** only for the disturbance-rejection panel (`er_ncDfk_w` / `er_wcDfk_w`)
- Power spectra: absolute (ΔF/F)² Hz⁻¹ only
- `d.ref = −5` as project-wide default reference level

## Open questions (see TASKS.md for priority)
1. Verify widebrain ARX R²_spont > 0.3; interpret OL vs CL residuals
2. Compare K2 OL vs CL slopes — flat CL slope = controller decoupling pre-stim state from outcome
3. Implement three-layer contralateral prediction model (pink/orange/red) — see FINDINGS.md
4. Implement Curto & Issa-style trial-sorting figure

## Paper figures exported to
`paper/images/figure3/` — panels 3A–3I; `paper/images/figure2/` — panels 2D, 2E
