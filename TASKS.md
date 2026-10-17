# TASKS.md — Prioritized TODO

Single source of truth for open work. Updated after each session or meeting.
Findings that are done live in FINDINGS.md. Meeting context lives in MEETINGS.md.
Freeform thinking + diary lives in JOURNAL.md (Claude gleans tasks from it).

---

## ✅ Recently done (rolling — last ~10, oldest pruned to RESEARCH.md)

<!-- When a task is completed, move it here with a date before deleting. -->
- [x] 2026-10-16 — **MPC (Fig 6, static + sine I–M) and VARX (Fig S5) DONE and LOCKED** (user). L = Q = 35, ridge 100, controller model trained without CL data; panels in figures_final, Fig S5 + Methods pointer + numbers in Closedloop draft (9d57903). RESEARCH 2026-10-16; locked block in CLAUDE.md.
- [x] 2026-10-16 — **Fig 4 relative 2-4 Hz framed as in-stimulation** (Closedloop draft): Results L205 + Discussion L18/L42; no laser-off control added (user). Random-slope item was stale: adopted 2026-10-11, already in text. RESEARCH 2026-10-16.
- [x] 2026-10-16 — **Fig 2G Results reworded as co-variation** (Closedloop draft): responses and ongoing activity change together with state; no claim either way about the stimulus effect itself. Discussion L16 still says "rather than as a change in the response itself" (user is writing the Discussion). RESEARCH 2026-10-16.
- [x] 2026-10-16 — **Power scale bars: no change needed** — user checked the V→mW conversion by hand (2A/2B/3A/3C/S-MPC). RESEARCH 2026-10-16.
- [x] 2026-10-12 — **Fig 2C–F on the seeded Mouse 3 fit + leak-free CV, manuscript made consistent** (Closedloop draft 8db98b1, not pushed). Held-out 0.85 pooled. Mouse 3's slowest pole is vestigial (< 0.2%), dip 0.14 s; the dip τ is order-sensitive. RESEARCH 2026-10-12.
- [x] 2026-10-10 — **AL_0041 e2 rebinned + Fig 2 rerun** (gap-based levels in `detectStimEvents_idx`; Mouse 1b R² 0.51 -> 0.76) and manuscript numbers updated; Fig 2 laser values accepted as-is (user); 4G stays gated, the all-13-session result is not reported (user); 4D = session mean ± SEM (user).
- [x] 2026-10-10 — Fig 4D session-level points (+pooled/median fallbacks); OL offsets + 4G paired stats saved (`f4_rr_denominator_check`); Global-state circularity check done (does not fix it).
- [x] 2026-10-10 — **Overleaf edits merged; Fig 2F (dip/rebound), 2G (session-level) and Fig 3 captions applied**; captions realigned to new assemblies (2A<->B, 3H<->I swapped). RESEARCH 2026-10-10.
- [x] 2026-10-07 — **JNeurosci statistics pass done:** Methods subsection renamed + Design + multiple-comparison paragraphs; every Results claim is estimate + CI + t(df) + exact p + n, quoted from `paper-writing/STATS_TABLE.csv` (new `paper_stats_table.m`); 0 inexact p left.
- [x] 2026-10-07 — **Fig 4D multiple comparisons decided:** uncorrected, 8 tests stated, Bonferroni 0.0063 named; rel-delta softened (now p=0.050 after the df fix).

---

## 🔴 Blocking submission

### arXiv blockers (plan: `paper-writing/arxiv_jneurosci_plan_2026-10-10.md`; RESEARCH 2026-10-10)
- [ ] (user) Author block: syntax fixed 2026-10-16 (single UW affiliation, no indices, renders cleanly); add departments + confirm order with Nick before journal submission.
- [ ] (user decision) **Fig 2G trial set + AL_0048 reference** (RESEARCH 2026-10-12): drop the 251 amp-0 trials? re-reference AL_0048 to onset? The motion-vs-control conclusion flips with the reference. Then fix heading L71, intro L44, results L148, 2G panel title.
- [ ] **NEXT, after the 2026-10-12 TF rerun + M3 dip check finish (user 2026-10-12): recompute Mouse 3 (AL_0048 2026-07-15/1) hemo correction LOCALLY, then rerun its Fig 2 chain.** Why: so that all four sessions are on one pipeline version (the lab's fixed hemoCorrect). ⚠ Updated 2026-10-12 evening (RESEARCH "CORRECTION: Mouse 3's slow dip…"): M3's May-2021 corr has NO net filter delay on its own onset frames (+0.75 ms vs zero-phase raw blue). The recompute is therefore NOT expected to move its 0.14 s dip to ~0.11 s; the earlier raw-blue 0.102 s was an onset-frame artefact. The lab's code and record are at `\\sahale\data\Code\dataChangeLog\2026-10_hemoCorrect_recompute\` (EXPLAINER.md, hemo_corr_sessions.csv). How:
  - copy the raw widefield frames for that session from the server to local disk (the server is read-only: read and copy only);
  - run the lab's CURRENT (2026-10-11) SVD + hemo pipeline locally. First find the exact code version the lab used; the c0de607 `hemoCorrect.m` was unreadable on 10-11;
  - save U/V/corr + timestamps locally, then DELETE the local frames;
  - point `load_bilateral_impulse` at the local corr via a knob, not by hard-editing paths;
  - rerun 2B, TF (2C–2F, seeded), CV, 2-pole, 2G and STATS_TABLE, then update the manuscript numbers.
  - Check free disk space before copying.
- [ ] (later, user advises) **Run the hemo correction locally for ALL sessions for consistency**, with the same frames → local SVD + hemo → delete-frames procedure and one code version for every session. Then rerun every figure that reads corr/.
- [ ] (user, Illustrator) **Figure4.pdf panels C, D and G** -> re-place `f4_row2_quartiles.pdf` (4D now session points, 2026-10-10) and `figures_final/panels/figure4/f4_decomp_unique_sep.pdf` + `f4_cl_reject_RR.pdf` (text quotes 0.41/0.03, 0.15/0.19; panel shows 0.39/0.10).
- [ ] Methods tuning: re-read end gains for AL_0034 10-25 e1 and AL_0033 12-19 from Kdata.npy and the iteration count; remove the `%% CHECK`.

### From the critical review (2026-10-10, RESEARCH 2026-10-10)
- [ ] **Fig 4G leak correction**: check per trial that subtracting the OL dip does not bias RR toward CL.
- [ ] **Cohort table**: add the sine sessions (units done 2026-10-10; the impulse sessions incl. AL_0048 2026-07-15 were added to the caption 2026-10-12).
- [ ] **Overclaims**: "The linear relationship guarantees the stability of a linear feedback controller" (`results.tex` ~L69, user's wording — flagged, not changed); difference-in-significance arguments in 2G-vs-control and 4D motion.
- [ ] (user, Illustrator) Fig 2D right-axis label reads "he ld-out".
- [ ] **Fig 2G: test response vs stimulus-free control directly** (review 2026-10-10, item 5). Text says movement alters the evoked response itself because the response ratio (0.73, CI [0.62, 0.88]) is below the control ratio (0.80), but that difference was never tested and the CIs overlap. Need a test of response ratio vs control ratio (e.g. paired bootstrap of the ratio difference, or |z| ~ state × {response, control} + (1|session) interaction) in `impulse-analysis/imp_state_trialvar.m`. If n.s., soften `results.tex` to "consistent with" and drop "movement alters the evoked response itself".

### Manuscript text
- [ ] **Manuscript follow-ups (2026-10-15; 2G variability rename + Fig 2 caption fixes DONE in draft 68250de, not pushed):** (a) L84 rebound sentence vs OL step-check (rebound = offset effect) and L100 rel-δ "independent of overall power" vs lit review: user decides. (b) Push draft→main only on user's go. (c) **Fig 3 rewrite pending:** once the CL/OL log-ratio rerun (session-level, mouse-intercept LMM + t-test on 15 log ratios; 3H/3I replotted on log axis, E/G unchanged) lands and 3H/3I are re-placed in Illustrator, rewrite both Fig 3 Results subsections, the 3H/3I caption and the Methods stats paragraph from the new numbers.
- [ ] Methods FILLs added 2026-10-02: K_r/K_p/K_i per sine session (§Sinusoidal reference and preview); provenance of old `tab:tf_sessions` (CHECK — is it the controller-design fit?; the new 4-session table was dropped 2026-10-02); readout kernel size on rig.
- [ ] (LATER, user) **Re-place revised panels in Illustrator**: Fig 2 A/B/C/D/E/F/G (2026-10-10; A/B/D/E/F/G changed again by the AL_0041 rebin; B–F again 2026-10-12, Mouse 3 onset reference + seeded fit + leak-free CV — the assembled Figure2.pdf predates all of it), Fig 3 all panels (2026-10-10), Fig 4 A/C/D/G, Fig 5G.
- [ ] Step-response paragraph (`results.tex` L59): rewritten + integral-term motivation present, but does NOT explicitly state the 3 s window is too short to observe steady state. Confirm whether that caveat is still wanted; add one sentence if so.
- [ ] **Confirm two Methods sentences** marked `%% CHECK` in `methods_rewrite.tex` (Experimental Design): no power analysis predetermined n; analyses not blinded.
- [ ] **DECIDE the status of relative 2-4 Hz power.** Fig 2G n.s. (p=0.068) and reverses sign on the Ye dataset, but in Fig 4D its REGULARIZABILITY effect is strong (CL error rises, p=8.6e-4, clears Bonferroni) - so it is a weak predictor of the impulse response but a clear limit on closed-loop regulation. Decide whether Fig 2's framing of it should change to match. Also decide whether to state in Methods that regularizability replaced the gap trend after the fact (RESEARCH 2026-10-07).
- [ ] **`ctrl_reject_trial_gallery.m`: fix or retire.** Its ER is not the paper's RR (0-3 s, no leak correction) and its header wrongly claims it comes from the headline function. Exploratory-only today, but it is a quotable wrong number. See RESEARCH 2026-10-09.
- [ ] Three remaining content `\todo` gaps in `results.tex`: §pre-stim brain state (L64–68), §low-freq spectral attribution (L112), §contra→ipsi prediction (L130) — see "Analysis still needed" below.
- [ ] Add Chrimson spatial-spread citation — `methods_edit.tex` L292 `\todo` (Nuo Li / Svoboda). NOT in refs.bib yet; needs exact paper from AL before adding a bib entry (do not fabricate).

### MPC (Fig 6) + VARX (Fig S5) — LOCKED 2026-10-16; only optional / open items below
- [ ] Sine Results sentence "about two thirds of the squared error … rising half-cycles" does not reproduce (≈0.49 with a dR>0 split, laser off 83%): find the original definition or reword to "about half". RESEARCH 2026-10-16.
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
  trial. The 0 V events in `uAmp` are NOT usable as catch trials — they are SYNTHETIC times the gap-fill code
  inserts every 5 s into laser-off gaps > 7.5 s (`load_experiments.m:106-156`); the detector misses no pulses
  (corrected 2026-10-12: they are not missed stimulations). Real no-light trials: AL_0033 90 designed + 62
  commanded-but-unfired (input_params), AL_0041 e1 ~44, AL_0041 e2 none, AL_0048 100 R-site shams (Block). Real catch trials have no
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
