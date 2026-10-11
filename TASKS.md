# TASKS.md — Prioritized TODO

Single source of truth for open work. Updated after each session or meeting.
Findings that are done live in FINDINGS.md. Meeting context lives in MEETINGS.md.
Freeform thinking + diary lives in JOURNAL.md (Claude gleans tasks from it).

---

## ✅ Recently done (rolling — last ~10, oldest pruned to RESEARCH.md)

<!-- When a task is completed, move it here with a date before deleting. -->
- [x] 2026-10-10 — Fig 4D session-level points (+pooled/median fallbacks); OL offsets + 4G paired stats saved (`f4_rr_denominator_check`); Global-state circularity check done (does not fix it).
- [x] 2026-10-10 — **Overleaf edits merged; Fig 2F (dip/rebound), 2G (session-level) and Fig 3 captions applied**; captions realigned to new assemblies (2A<->B, 3H<->I swapped). RESEARCH 2026-10-10.
- [x] 2026-10-07 — **JNeurosci statistics pass done:** Methods subsection renamed + Design + multiple-comparison paragraphs; every Results claim is estimate + CI + t(df) + exact p + n, quoted from `paper-writing/STATS_TABLE.csv` (new `paper_stats_table.m`); 0 inexact p left.
- [x] 2026-10-07 — **Fig 4D multiple comparisons decided:** uncorrected, 8 tests stated, Bonferroni 0.0063 named; rel-delta softened (now p=0.050 after the df fix).
- [x] 2026-10-07 — **LMM df bug fixed** (`utils/lmm_cluster_df.m`); Fig 3, 4D, 4G, 2G re-run; `f4_cl_reject_lmm.m` post-mode-switch rerun done (AL_0051 now reaches, n=12).
- [x] 2026-10-05 — **MPC finished as a supplement:** forecast σ measured with our own CV forecasters (in place of Ziyu's model); MPC rebuilt on the 108 real single-trial disturbances (old tube-MPC was 17× under-scaled); 3-panel supp figure. Resolves `2026-09-11.3/.4` and the placement decision. See RESEARCH 2026-10-05.
- [x] 2026-10-02 — **Methods synced to the code behind every figure** (`methods_rewrite.tex`): state windows Fig 2 [−1,0) / Fig 4 [−2,+3) + continuous band power, Fig-4 exemplars + unique-R² decomposition, Fig-2G variability pipeline, Fig-2 TF/CV/swap/τ bootstrap (+ new Table tab:tf_fig2), preview controller + Fig-5 metrics, two ΔF/F normalizations, 40 s baseline. Fig-5 Results made descriptive (no tests). See RESEARCH 2026-10-02.
- [x] 2026-10-02 — Methods paragraph for the Fig-4 Row-2 session-aware LMM: covered by Statistics (cond × state model, predictability/controllability, hierarchical bootstrap) + "Brain-state measures" (motion = mean z over −2..+3 s).
- [x] 2026-08-12 — **Fig-4 beat 3+4 code built (all UNRUN, blocked on the Stage-2 rebuild).** (a) R² floor 0.85 now gates all three cross-session controller scripts identically (user decision); (b) `f4_reject_panels.m` = paper panels for cross-session disturbance rejection, read-only off the batch struct, ER as primary metric, with the T1 gain-vs-R² control as panel D; (c) `ctrl_optimal_xsess.m` + shared `utils/ctrl_opt_solve.m`/`ctrl_plant_markov.m` = the MPC beat across sessions, with the disturbance computed BOTH as the post-hoc residual and as the contra-predicted Global (the version a real controller could use). See RESEARCH 2026-08-12 ×3.
- [x] 2026-07-01 — Impulse residual: DV → **L1-dev primary** (template-gain secondary); retargeted to laser center [373,353] (A2); pre-onset-window (A4) + bleed-artifact controls pass; `[CP-KRECON]` sparse-kernel reconstruction added. Committed to `alpha` (101a9b9, 3ec2e0c). Retired `contra_residual.m`.

---

## 🔴 Blocking submission

### arXiv blockers (plan: `paper-writing/arxiv_jneurosci_plan_2026-10-10.md`; RESEARCH 2026-10-10)
- [ ] (user) Author/affiliation block (`main.tex` L71-78 renders "Department of ,") -- editing on Overleaf.
- [ ] (user) **Laser power setting on 2025-12-02 (AL_0041) and 2026-07-15 (AL_0048 impulse).** If 100%, Fig 2 mW values and the Mouse 1a/1b/3 per-mW slopes are ~5x off.
- [ ] (user, Illustrator) **Figure4.pdf panels C, D and G** -> re-place `f4_row2_quartiles.pdf` (4D now session points, 2026-10-10) and `figures_final/panels/figure4/f4_decomp_unique_sep.pdf` + `f4_cl_reject_RR.pdf` (text quotes 0.41/0.03, 0.15/0.19; panel shows 0.39/0.10).
- [ ] **Mislabeled power scale bars** -> fix code, re-export, re-place: 2A legend (`trace_overlay.m:53` uses /3; use plateau V x 1.8/4.9), 2B bar ('0.25 mW' spans 1 V = 0.37 mW, `dose_response.m:136,149`), 3A/3C '1 mW' bars are 0.15-0.24 mW (`analysisPlots_combined.m:72,81-82,97,200,208,216`), S-MPC '1 mW' on command volts (`ctrl_mpc_direct_panels.m:91,129`).
- [ ] **DECIDE 2-4 Hz framing (circularity; RESEARCH 2026-10-10 'Circularity').** Contra/Global state does NOT fix it (keeps the overlap, carries laser leak). Laser-off window [-2,0) on the readout: abs 1-4 Hz holds (OL/CL p 4e-7/5e-8), rel 2-4 Hz predicts OL and CL equally (att p=0.47) -> 'OL flat, CL rises' is in-stimulation only. Options: add laser-off rows to Table 1 + reword Abstract/Intro L46/Results L152/Discussion L18,L42 as concurrent effects; Methods 'sub-band least attenuated' justification.
- [ ] **DECIDE random state slope for Table 1** (1+cond+xw|sess): rel 2-4 reg 8.6e-4 -> 0.05, initdev reg 3.5e-5 -> 0.055, motion att 0.015 -> 0.0046, abs all still pass. `data/f4_circularity_checks.mat`.
- [ ] AL_0041 e2: raw trace has five levels (1.93 V split into 1.9/2.0 bins by 0.1 V rounding) -> rebin; affects Fig 2B points and Mouse 1b TF fit.
- [ ] Methods tuning: re-read end gains for AL_0034 10-25 e1 and AL_0033 12-19 from Kdata.npy and the iteration count; remove the `%% CHECK`.

### From the critical review (2026-10-10, RESEARCH 2026-10-10)
- [ ] **Fig 4G exclusion**: Methods now says the threshold was chosen after inspection (2026-10-10). Still to do: report the all-13-session result beside the gated one.
- [ ] **Fig 4G leak correction**: check per trial that subtracting the OL dip does not bias RR toward CL.
- [ ] **Cohort table**: add the AL_0048 impulse session and the sine sessions (units done 2026-10-10 except the laser-setting blocker above).
- [ ] **Overclaims**: "The linear relationship guarantees the stability of a linear feedback controller" (`results.tex` ~L69, user's wording — flagged, not changed); difference-in-significance arguments in 2G-vs-control and 4D motion.
- [ ] (user, Illustrator) Fig 2D right-axis label reads "he ld-out".
- [ ] **Fig 2G: test response vs stimulus-free control directly** (review 2026-10-10, item 5). Text says movement alters the evoked response itself because the response ratio (0.73, CI [0.62, 0.88]) is below the control ratio (0.80), but that difference was never tested and the CIs overlap. Need a test of response ratio vs control ratio (e.g. paired bootstrap of the ratio difference, or |z| ~ state × {response, control} + (1|session) interaction) in `impulse-analysis/imp_state_trialvar.m`. If n.s., soften `results.tex` to "consistent with" and drop "movement alters the evoked response itself".

### Manuscript text
- [ ] Methods FILLs added 2026-10-02: K_r/K_p/K_i per sine session (§Sinusoidal reference and preview); provenance of old `tab:tf_sessions` (CHECK — is it the controller-design fit?; the new 4-session table was dropped 2026-10-02); readout kernel size on rig.
- [ ] (LATER, user) **Re-place revised panels in Illustrator**: Fig 2 C/D/F/G (2026-10-10), Fig 3 all panels (2026-10-10), Fig 4 A/C/D/G, Fig 5G.
- [ ] Step-response paragraph (`results.tex` L59): rewritten + integral-term motivation present, but does NOT explicitly state the 3 s window is too short to observe steady state. Confirm whether that caveat is still wanted; add one sentence if so.
- [ ] **Confirm two Methods sentences** marked `%% CHECK` in `methods_rewrite.tex` (Experimental Design): no power analysis predetermined n; analyses not blinded.
- [ ] **DECIDE the status of relative 2-4 Hz power.** Fig 2G n.s. (p=0.068) and reverses sign on the Ye dataset, but in Fig 4D its REGULARIZABILITY effect is strong (CL error rises, p=8.6e-4, clears Bonferroni) - so it is a weak predictor of the impulse response but a clear limit on closed-loop regulation. Decide whether Fig 2's framing of it should change to match. Also decide whether to state in Methods that regularizability replaced the gap trend after the fact (RESEARCH 2026-10-07).
- [ ] **`ctrl_reject_trial_gallery.m`: fix or retire.** Its ER is not the paper's RR (0-3 s, no leak correction) and its header wrongly claims it comes from the headline function. Exploratory-only today, but it is a quotable wrong number. See RESEARCH 2026-10-09.
- [ ] Three remaining content `\todo` gaps in `results.tex`: §pre-stim brain state (L64–68), §low-freq spectral attribution (L112), §contra→ipsi prediction (L130) — see "Analysis still needed" below.
- [ ] Add Chrimson spatial-spread citation — `methods_edit.tex` L292 `\todo` (Nuo Li / Svoboda). NOT in refs.bib yet; needs exact paper from AL before adding a bib entry (do not fabricate).

### Supplement (MPC, Fig. S5 in paper since 2026-10-09)
- [ ] Optional robustness: repeat `ctrl_mpc_realtrial` on a second session (m9/m11, AL_0039) so the claim isn't n=1.
- [ ] Ziyu's model (`2026-09-11.4`), if it becomes available: score its error relative to AR (`ctrl_mpc_forecast_sigma`) and mark it on panel B's x-axis. No longer gating.
- [ ] Tell Nick (`2026-09-11.5`): MPC → supplementary. Real forecasters sit at PI parity; the headroom needs ~2× better forecasts plus online gain adaptation.

---

## 🟡 Next sprint

### New controller mice (AL_0048, AL_0051)
- [ ] **Run a dedicated controller-tuning experiment for BOTH AL_0048 and AL_0051** (user 2026-07-30). The 2026-07-29 sessions embed the Kp sweep in their early trials (locked-Kp OL/CL is only the LAST ~100), so a clean standalone gain-grid/auto-tune session per mouse is still needed (cf. `controller-tuning`). Feeds a proper per-mouse tuned gain + the cost-landscape methods figure.
- [~] Fold AL_0048 + AL_0051 (last-100 locked-Kp block) into the Fig 3 session-pooled figures + repeat the Fig 4 state-dependence analysis with them included (in progress 2026-07-30). See [[project_new_controller_mice]].

### Meeting-driven (Nick 2026-07-17 / 07-22 / 07-28; see MEETINGS.md)
- [ ] **Is the DR baseline offset state-dependent LASER GAIN, not controller work?** (`2026-07-28.2`) — Nick's central objection. Two tests: (a) correlate the **pre-stim baseline offset** of each trial in the DR scatter against **pre-stim delta power** and **motion**; (b) regress **stim-period residual amplitude ~ pre-stim delta × condition (OL/CL)** — a **significant interaction** means trial-by-trial actuator-gain variability explains the scatter, not controller failure. ⚠ This is the same identification problem already flagged for the Fig-4 Stage-5 `s_var→o_loc` pair — the interaction term is the fix that pair needs too.
- [ ] **Pool AL_0048 + AL_0050 + AL_0051 CL sessions into the state-dependence analysis** (`2026-07-28.3`) — Nick wants all three to firm up **p = 0.039**, which he treats as preliminary. ⚠ Two live caveats: the p-value also depends on the **unfinalized contra predictor mask** (`2026-07-06.3`), and **AL_0050 has weak expression** — run a quick impulse-response check on AL_0050 first (AI-flagged risk of diluting rather than strengthening the pooled result; note [[project_new_controller_mice]] already excluded AL_0050 for poor stim). Overlaps the in-progress AL_0048/AL_0051 Fig-3/Fig-4 fold-in below.
- [ ] **Check AL_0051 expression level** (`2026-07-28.5`; confirm with Anna if needed) → schedule grid characterization + CL session. Gates the item above.
- [ ] **Split the state-dependence figure by *source* of desynchronization** (AI-flagged): high running speed vs spontaneous low-delta, within the same panel. Aditya's own framing is that these are mechanistically distinct (motion = predictable state / unpredictable direction; synchronized = predictable direction / unpredictable laser gain) — splitting makes the "designer's dilemma" quantitative instead of qualitative.
- [ ] **OL-optimized reference line for disturbance rejection** (Nick, `2026-07-22.3/.4`): add a third trace = contra prediction + average laser effect ("orange + avg laser") to the trial-by-trial residual plots; per trial compute L2 of (actual − OL-optimized) over the stim window, contrast OL vs CL, and regress against pre-stim delta power + motion. This is the concrete disturbance-rejection metric — ties into the ⭐ PORT objective-2 ceiling below.
- [ ] **Bidirectional single-site candidates** (`2026-07-17.6`): from the 52-site grid maps, score each location by dot-product of inhib × excit ΔF/F response vectors (0–500 ms); rank to find sites drivable in both directions. Feeds the widefield opto paper's bidirectional-control extension.

### Impulse cohort (AL_0048 in Fig 2)
- [ ] **⚠ Carry the caveat**: AL_0048's inhibitory readout is ~2.6 mm from the illumination, so its impulse response is that of a CONNECTED region, not the illuminated tissue (unlike AL_0033/AL_0041). State this in Methods if the session backs a local-effect or actuator-TF claim.
- [ ] Check AL_0048 expression/histology for an anterior inhibitory-opsin offset; 2026-07-10 should show the same offset if that is the cause.
- [ ] Decide whether to copy the generated `face_proc.mat` next to the video on the lab share (write to shared storage — needs an explicit OK).

### Bilateral AL_0048 + site grid
- Open setup/analysis checklist (session registry, stim mode, polarity, OL/CL/sine runs, grid options) → `TASKS_archive_2026-10-10.md` §Bilateral and `bilateral/grid/README.md`.
- [ ] Recover sham (amp 0) catch trials for the impulse dose-response via Block↔Timeline clock offset (no laser onset → not in detected onsets)
- [ ] TF-fit each side's AL_0048 impulse response (excit transient vs inhib dip time constants); compare to AL_0033/AL_0041 impulse TFs

### Methods / figure hygiene
- [ ] confirm AL_0034 is introduced at first mention (13-session set names only AL_0033/AL_0039).
- [ ] Add `\label{sec:disturbance}` in `methods_edit.tex` (disturbance/motion methods) so the low-freq `\todo` ref resolves; optionally delete orphan `methods.tex`/`introduction_temp.tex`.
- [ ] **Periodic uptick artifact in the motion-energy trace (~every 60, possibly 70, frames)** — verify the exact period numerically on one session, then check whether it is present in ALL saved motion traces (it likely is, since motion is precomputed and cached). Design a filter (notch at the beat frequency, or median-of-neighbours replacement at the offending sample indices) and apply it at load time so every downstream user gets the clean trace. Not blocking: true motion has much larger amplitude, so current threshold-based results (motThresh = 1.5) stand. But motion is now the PRIMARY power-independent state covariate for the residual state-dependence claim, so the trace needs to be defensible before that result goes in the paper.
- [ ] Verify Fig 2C shading is ±1 SD — update caption if not
- [ ] **Colorblind-safe version of ALL figures** — add a colorblind palette/template to `utils/paperStyle.m` (Wong/Okabe-Ito 8-color or ColorBrewer), and re-export every panel through it; keep a switch so both the standard and colorblind versions can be produced.
- [ ] **Add units to every short-corner-axis figure** — `paperStyle` corner axes use `XLabel`/`YLabel` scale bars (e.g. '1 s','3%'); several panels don't set them yet. Audit all figures and add the missing unit labels.
- [ ] **DEFERRED (user: "keep for later") — Fig 3 OL/CL red→green → Wong colourblind pair.** `PS.col_ol=[1 0 0]` (red) / `PS.col_cl=[0 0.5 0]` (green) in `utils/paperStyle.m` is the paper's highest-impact CB liability (red-green encodes the primary OL vs CL contrast). Swap to Wong orange `#E69F00` [0.902 0.624 0] / blue `#0072B2` [0 0.447 0.698]; propagates to all Fig 3 panels + 2E. Re-export 3E/3G/3J/3H + step/H after.
- [ ] **BUG — `paper_root`/`paperRoot` export path is CWD-dependent → silent mislocation.** Resolver (`exist('paper/images')→'paper' else '../paper'`) writes to `projects\paper` (repo sibling) when a script runs from the repo ROOT while the workspace holds a stale `paper_root='..\paper'`. A stray `projects\paper\images\` has accumulated mislocated exports across sessions. Fix: anchor to the script's own dir via `fileparts(mfilename('fullpath'))` (robust to CWD + stale vars). Then decide whether to purge the stray mirror (holds other-session files — do not auto-delete). Found 2026-07-17.
- [ ] Add n and ± CI to all slope estimates in linearity paragraph — BLOCKED: needs fit CIs from the impulse dose-response fit (`dose_response.m`); n=3 already stated. Can't fabricate CIs — run the fit to emit slope ± CI, then add.

---

## 🟢 Deferred / waiting
- [ ] S4 single-trial RR figure (A-r vs D, `f4_supp_reject_trials.m`) TABLED 2026-10-10; float + 2 Discussion refs commented out. Revive only if reviewers ask for single trials.

- [ ] **Fig 2G stim-free control — rebuild on REAL catch trials, then revisit the overlay** (tabled by user 2026-10-03).
  Today's control is a within-trial pre-stimulus surrogate (`iSham`, −1.200 to −1.029 s), not an unstimulated
  trial. The 0 V events in `uAmp` are NOT usable as catch trials — they are gap-fill placeholders for events the
  detector missed (`load_experiments.m:153`), so their amplitude is unknown, not zero. Real catch trials have no
  laser onset and must be recovered from Block via the Block↔Timeline clock offset — same mechanism as the open
  bilateral item. Do this together with the `Lresp` 7-vs-8 length fix (`imp_state_trialvar.m:170`, see RESEARCH
  2026-10-03). Preview of both overlay framings already built: `impulse-analysis/_preview/stv_2g_ctrl_preview.m`
  (`PV_MODE` = 'shape' reproduces the caption's 0.80/1.00/2.25 exactly; 'magnitude' does not).

- [ ] **[TABLED 2026-08-12, user] Fig-5 spectral / tracking-fidelity panel.** Analysis is done and parked in `bilateral/sine_ff_error_decomp.m` (runs, reproduces the numbers, nothing registered). Three sections: error-power decomposition (offset / at-f0 / broadband, exact via Parseval), per-trial `|1−T|` at the drive frequency, and the trade-off plane. **If picked up: promote the trade-off plane** — it is the only version that supports "CL+preview is best" honestly (it dominates plain CL on both axes, 3/3 sessions), and 5H's 4.2 × 5.4 slot is free. Do **not** re-run the shape-similarity family: eight framings tested, all name OL+preview, for the structural reason that shape normalises out the offset term where CL+preview wins. RESEARCH 2026-08-12.
- [ ] **Controller analysis result caching** — avoid recomputing ARX fits, TF fits, and cross-session pooled arrays on every run. Proposed structure: `data/<session>wb_model.mat` (ARX `beta_m`, `pY/pX/grid_rows/grid_cols`, R²_train/test, TF fit object + time constants), `data/<session>wb_pred.mat` (pink/orange/red trial predictions + R²s + WB-5 MSEs), `cross_session_cache.mat` (motion quartile arrays, pre-stim dev/MSE, spectral aggregations, contributing sessions list). Each section checks whether cached params match current params before recomputing. See RESEARCH.md 2026-05-27 for full struct design.
- [ ] **[theory / discussion] Forecast test — local vs sub-cortical** (`2026-07-17.10` + AI flag): OL suppression shifts the fluctuation MEAN but not the VARIANCE. Fit AR/VAR on baseline widefield; at opto onset forecast from (a) raw suppressed level and (b) zero-mean-shifted level; whichever tracks the actual post-stim trace better reveals level-relative vs absolute dynamics. Discussion-section scope ONLY (keep from becoming a new experiment arc). Nick separately simulating inhibitory DC into Kurtow & Harris.
- [ ] **[future / not started] Sparse graph network model** — fit 1st- and 2nd-order site-to-site TFs across the 52-point grid → weighted adjacency matrix → impose sparsity (LASSO, or **DYNOTEARS**, Pamfil et al. 2020 UAI) → validate on held-out sites. Substantial overlap with the existing `bilateral/grid/network_id.py` driven-Laplacian / graph-wave ladder — start there rather than from scratch.
- [ ] **[deferred] getdfof recompute for AL_0034 10-18** — extract the raw widefield from the 165 GB `.rar`, recompute kernel-mean dF/F at pixel[390,390] via getdfof (independent of the online states.csv), re-test for a stim-locked dip / dose-response → settle biology-vs-online-pipeline. Only if 10-18 is specifically needed.
- [ ] Follow up with Zilu on ARIMA/forecasting models
- [ ] Prepare widefield dataset for Tim Kim latent-space model; arrange joint meeting

---

<!-- Pruned 2026-10-10: the full pre-prune list (NeuroAI talk, Fig-4 candidate audit, residual/contra/OLS workbenches, old analyses, done [x] items, cross-area diagram) is kept verbatim in TASKS_archive_2026-10-10.md. -->
