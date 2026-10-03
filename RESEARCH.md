# Brain Paper — Research Coordination

## Project Context
Mouse widefield closed-loop PI controller vs open-loop analysis.
Controller uses kernel average of a cortical region as output; PI controller drives input.
Two mice: AL_0033 (9 sessions), AL_0039 (4 sessions) = 13 controller sessions, Jan–Apr 2025. (Verified 2026-06-16 from loaded cache m1–m13.)

**Core question:** Does the closed-loop controller reduce neural variability and error compared to open-loop?
**Secondary questions:** Do motion, frequency-band power, and wide-brain activity explain trial-to-trial variability? Do these differ between OL and CL?

**For tasks and priorities → `TASKS.md`**
**For completed findings and paper claims → `FINDINGS.md`**
**For meeting decisions → `MEETINGS.md`**

---

## Change Log

### 2026-10-03 - Evoked-suppression window changed to a TRUE 0-200 ms (8 samples) in both impulse loaders
**Changed/Found:** User asked that the code reflect 0-200 ms, not just the label. Traced the window and changed it in BOTH paths. `impulse-analysis/load_experiments.m` peak_mode==3: `win3` started at `post_start = winSamp+2` (= onset+1) and ran to `winSamp+round(0.22*fs)` (= onset+7), i.e. **29-200 ms over 7 samples**, while the panel, caption and Methods all said "0-200 ms". Now `win3 = (winSamp+1) : winSamp+1+round(0.2*fs)` = onset..onset+7, **8 samples, exactly 0.0-200.0 ms**. `post_start` is deliberately left alone so the peak_mode 1/2 trough search still excludes the onset sample, which is correct for a trough. **Second path found and fixed:** AL_0048 enters via `load_bilateral_impulse.m`, whose `dipC = winS + (round(dip_win(1)*Fs)+1 : round(dip_win(2)*Fs)) + 1` was ALSO onset+1..onset+7 despite `BLI.dip_win = [0 0.20]`; the stray `+1` on the lower edge is removed, so all four Fig-2A sessions now share one window. Had I only changed load_experiments, the cohort would have been split 3 sessions at 0-200 and 1 at 29-200. Also corrected a stale comment in `imp_state_trialvar.m:153` ("0-220 ms" -> "0-200 ms"); the 0.22 there was an offset from `winSamp`, not from onset. **New dose-response numbers (all four on 0-200 ms):** slopes **-0.3006 / -0.5010 / -0.5151 / -0.8095**, R2 **0.967 / 0.513 / 0.924 / 0.918** (were -0.3435/-0.5726/-0.5886/-0.9574 and 0.967/0.513/0.924/0.912). For the three load_experiments sessions the change is an EXACT x7/8 rescale (ratios 0.8751/0.8750/0.8751) because the onset sample is identically zero by construction there, so every R2 is unchanged and no inference moves - only the effect-size units. AL_0048 scaled by x0.846 with R2 +0.006, so its onset sample is NOT identically zero under the bilateral baselining. Manuscript updated on `draft`: body slopes/R2, the Fig 2A caption range (-0.30 to -0.81), the Methods equation `W = {t_on,...,t_on+7}` and the Methods prose ("the eight samples from 0 to 200 ms after onset, inclusive of the onset sample"). Panel re-exported to `panels/figure2/imp_response.pdf`. Build clean, 38 pp, 0 undefined. NUMBERS.md impulse table updated with the old values recorded alongside.
**Why:** User: "i want code to reflect 0-200ms as well". The label, caption and Methods prose had all claimed 0-200 ms for some time while the arithmetic delivered 29-200 ms, so the code was the thing out of step.
**Next:** **FLAG FOR THE USER - this overrode a documented rationale.** The Methods sentence I replaced read: "The onset sample itself is excluded because it straddles the trigger." If that is physically true, the onset sample is neither clean baseline nor clean response, and including it adds a half-stimulated sample to every trial mean - which is exactly why all three load_experiments slopes shrank by 1/8 without any gain in R2. Decide whether to keep 0-200 ms or revert to 29-200 ms; reverting is two one-line edits plus a re-run. Also still to re-run on the new window, since anything using Peak_imp under peak_mode=3 inherits it: the Fig 2G state-dependence panel (`imp_state_var_combined.pdf`, quartile ratios 0.73 / 1.03 / 2.10 and their controls), `imp_state_trialvar.m`, `lds_ipsi.m`, and `bilateral/ol_characterization.m`. The TF fits are NOT affected (they fit the trace, not the window mean).


### 2026-10-03 - Figure consistency fixes applied (caption/Methods edits + Fig 2A re-export)
**Changed/Found:** Worked the audit list the user triaged. **Manuscript (`draft` branch, Closedloop_edit):** (1) Fig 4C caption pool 7 sessions/397 trials -> **11 sessions/613 trials**, matching the panel title, the Results body and Methods S1088. (2) Fig 3A caption closed-loop **green -> blue**. (3) Fig 3A caption "Bottom traces show the ... input signals" -> "Grey traces **above** each response", which is where they actually sit. (4) Methods S1176 "ordinary least-squares predictor" -> **ridge-regularized**, plus a sentence that the penalty is chosen stim-blind from catch windows: `f4_kernel_map.m:21` asserts `strcmp(pmode,'ridge')`, so the CAPTION was right and the Methods was wrong. (5) Fig 4D caption now states the error is per-trial RMSE **z-scored within session** (Methods already said so). (6) Fig 5 caption regained the animal (**AL_0048, right hemisphere, inhibitory opsin**) and the grey/dashed trace key, both of which had been dropped in the 10-02 rewrite while the panels still showed them. (8) Methods latency sentence now carries **n = 200 consecutive loop cycles**, which the Fig 1F caption had been claiming unsupported. Build clean, 38 pp, 0 undefined refs. **Code + panels (brain_paper):** (7) `impulse-analysis/dose_response.m` ylabel **"Inhibition energy (0-200 ms)" -> "Evoked suppression (29-200 ms)"**; re-ran with `PAPER_FINAL` on and mirrored `panels/figure2/imp_response.pdf` (2.89 x 3.10 cm). The 29-200 ms figure is now right: Methods `eq:inhib_energy` was updated to **W = {t_on+1,...,t_on+7}**, so the caption's 29-200 ms is correct and the code's 0-200 ms was the outlier. The re-run also independently reproduced the locked dose-response numbers (slopes -0.3435/-0.5726/-0.5886/-0.9574, R2 0.967/0.513/0.924/0.912, "4 sessions from 3 mice"). (14) Copied `paper/latency_histogram.pdf` into `panels/figure1/` so Fig 1F can be pulled from the locked folder; its producer is `latencyAnalysis.m`. **THREE FINDINGS THAT CHANGE EARLIER CONCLUSIONS.** (a) **Fig 5G's significance brackets were already disabled in code on 2026-10-02** (`SINE_SHOW_STATS=false` in `bilateral/sine_ff_plots_combined.m`), and the LOCKED panel `panels/figure5/sine_5G_rmse_violin_*.pdf` is confirmed starless, while the WORKING copy in `paper/images/figure5/` (08-12) still has stars. The assembled `Figure5.pdf` therefore pulled panel G from `paper/images/` instead of the locked folder -- exactly what the CLAUDE.md rule forbids. No code work needed; the composite must be re-assembled from `figures_final/panels/`. (b) **Fig 4G is NOT a 10-session/2-mouse panel.** Text extraction of the locked `f4_cl_reject_RR.pdf` gives 11 tick labels across 3 mice (Mouse1a-1g, Mouse2a-2c, Mouse3a), matching the caption's n=11 and the 3-level mouse random effect. My earlier flag was a misread of the small rotated labels in the composite -- RETRACTED. (c) **Fig 2's panel letters are Illustrator text, confirmed**: every source panel in `panels/figure2/` contains zero letter glyphs, and `panels/figure1/README.txt` states outright that lettering is Illustrator's job. So the F/G/E scramble cannot be fixed from code. **Model-swap matrix numbers extracted for the user** (rows = model from, cols = applied to): M1a .97/.45/.71/.84 | M1b .09/1.00/.87/.78 | M2 .53/.88/1.00/.95 | M3 .69/.83/.97/1.00; diagonal mean 0.99, off-diagonal mean 0.716 / median 0.805 / range 0.09-0.97, with 6 of 12 off-diagonals >= 0.80.
**Why:** User moved into writing mode and triaged the panel audit into do-now items (1-8), a Fig 5G redraw (9), numbers-only reporting for the model swap (10), a check on Fig 4G (13), and staging Fig 1 sources for Illustrator (14). Item 11 (Fig 2G control panel) tabled by the user; item 12 (Fig 3G purple trace) withdrawn by the user -- there is no purple trace, my read of the render was wrong.
**Next:** Three items need Illustrator and cannot be done from code: **re-letter `FIgure2.ai` row 2 to E, F, G**; **re-assemble Figure 5 pulling panel G from `figures_final/panels/figure5/`** (the correct starless panel is already there); and **re-place Fig 2A** with the regenerated `imp_response.pdf`. Also: the user will fill `MANIFEST.txt [figure1]` now that `latency_histogram.pdf` is staged -- note `collect_final_panels.m` DELETES anything unlisted, so add the line before running the collector. Figure 1 D and E have no source files anywhere in the repo and appear to be native Illustrator artwork; nothing to stage for them. Secondary: `imp_response_median_IQR.pdf` (not a paper panel, not in the manifest) still carries the old "Inhibition Energy" label from a second label site in `dose_response.m`.


### 2026-10-03 — TF variants extended to a 3.0 s window (caps 2 and 5) + fit-overlay comparison
**Changed/Found:** Scratch script `tf_variants_3s.m` (imp_tf_run RUN_TFIT = 3.0, RUN_MAXPOLES = 2 / 5;
CV; panels; PAPER_FINAL off; 0.5 s cache restored). Fits `impulse-analysis/data/imp_tf_fits_tfit3p0_{2p,5p}_2026-10-03.mat`.
Overlays `scratchpad/tf_variants/tf_fit_compare_0-{3,1}s.png`: each model simulated over 0-3 s against
the measured amplitude-normalised response (R2 inside its window and over 0-3 s).
- 3.0 s / <=2p: R2h 0.16/0.47/0.59/0.66, pooled CV R2 0.009; Mouse 1a collapses to 1 pole; misses the dip.
- 3.0 s / <=5p: R2h 0.74/0.83/0.94/0.89 (best whole-trace description), but UNSTABLE slow pole in 3/4
  (near-integrator absorbing the late offset), 71-79 % bootstrap discards, pooled CV R2 0.065.
- R2 over 0-3 s: current 0.5 s fits -0.72/0.24/0.67/0.65 (excellent in window, extrapolate badly:
  dip below zero after 0.5 s where data stay positive); 1.0 s/<=4p 0.60/0.85/0.71 for 1b/2/3 (M1a unstable).
- Held-out CV collapses for every 3 s fit: the >1 s part of the trial average is dominated by
  ongoing activity that the two trial halves do not share, so it is not a reproducible stimulus response.
**Why:** User: "add comparison by increasing to 3 sec with 2p and 5p limits. this is exploratory, also plot the fits".
**Next:** USER DECISION. Nothing in the paper changed.

### 2026-10-03 - Panel-by-panel figure/caption/Results/Methods consistency audit (Figs 1-5)
**Changed/Found:** Audited every panel of all five figures against four sources: the assembled PDF itself (panel letters extracted by coordinate with PyMuPDF, content read visually), the caption, the Results body, and methods_rewrite.tex. **BIGGEST FIND - Figure 2's printed panel letters are scrambled.** Row 2 of Figure2.pdf prints F@x=2.5, G@x=163, E@x=308 (left-to-right F, G, E), while BOTH the caption and MANIFEST.txt say E=model swap, F=timescales, G=state. So every Results citation to 2E/2F/2G lands on the wrong panel: the swap matrix is printed F, timescales printed G, state printed E. Note the MANIFEST is already correct - the defect is in the Illustrator lettering ("Letters in Illustrator" per its own header), so editing MANIFEST.txt cannot fix it; FIgure2.ai must be re-lettered (or caption+manifest flipped, which leaves reading order F,G,E). Figures 1, 3, 4, 5 all letter correctly. **Figure 4C n resolved three-to-one:** the panel itself prints "Unique R2 (n=613, 11 sess)", Results says 11 sess/613 trials, Methods S1088 says "the 11 sessions with motion capture (613 trials)" - only the CAPTION still says 7 sessions/397 trials. Caption is stale; also its "at least 12 trials per state" describes minTr, which gates only the per-session dots, not the pool. **Figure 5 contradicts its own statistical fix:** panel G still displays *** and * significance brackets although the caption now says "no significance tests are reported for this figure" and Results says the same; the stars are also no longer defined anywhere. Figure 5 also LOST its animal identity - "AL_0048, right hemisphere (inhibitory opsin)" was removed from both caption and Results, so the single-mouse/single-hemisphere basis now appears nowhere in Results; and the caption no longer explains the grey (laser command) and dashed-black (reference) traces that B/C/D still show. **Figure 3:** caption A says closed-loop is green but the panel is blue, and says the input traces are at the bottom when they are at the top; caption E claims "points indicate individual trials" but the panel shows only half-violins with a central marker; panel G carries an unexplained purple trace/vertical line; F and G are not independent (G = all_average_sessions shares across-trial variance with F per the locked 2026-08-24 note) and neither caption says so. **Figure 2 content issues:** panel A's y-axis still reads "Inhibition energy (% dF/F, 0-200 ms)" - the rename to evoked suppression and the 29-200 ms window reached caption and Results but not the panel; the model-swap panel UNDERCUTS its claim (diagonal 0.97/1.00/1.00/1.00 but off-diagonals include 0.84/0.87/0.95/0.97, only the M1a-M1b pair is low at 0.09/0.45, so "per-session identification is required" is too strong); and the caption describes stimulus-free control ratios (0.80/1.00/2.25) that are not plotted anywhere. **Figure 4 others:** panel E caption says "ridge weights" while Methods S1175 says "ordinary least-squares predictor" (contradiction still live); panel D's y-axis is z-scored but the caption does not say so; panel G's x-labels read Mouse 1a-1g and 2a-2c, i.e. 2 mice and ~10 sessions, against a caption saying n=11 and a mouse random effect NUMBERS.md puts at 3 levels; and "Mouse 1/Mouse 2" denote DIFFERENT animals in Fig 2 (AL_0041/AL_0033) vs Fig 4, with no key. **Figure 1:** MANIFEST [figure1] lists only 3 source files, so panels D, E and F have no manifest entry - and F is a DATA panel (latency histogram) with no tracked producer; Methods gives the <=47 ms bound but not the n=200 cycles the caption claims; panel D's caption describes a signal flow while the panel is a two-layer block diagram with an undescribed blue-light trigger waveform. **Two clean results:** every caption panel letter in all five figures is cited at least once in the Results (no orphan panels), and no panel's method is described twice or inconsistently in Methods - each appears exactly once. The only Methods-vs-caption conflict is OLS vs ridge (Fig 4E). Discussion deliberately NOT audited (user is writing it).
**Why:** User moved into writing mode and asked for a panel-by-panel verification that each panel's content is consistently described by its caption, addressed in Results, and mentioned once in Methods. Checked against the rendered PDF rather than against the producer scripts, since the assembled figure is what a reader sees.
**Next:** Re-letter FIgure2.ai row 2 to E, F, G (the manifest and caption are already right, so nothing else changes). Fix Fig 4C's caption n to 11 sessions / 613 trials. Remove or re-enable the significance brackets in Fig 5G to match the no-tests decision, restore AL_0048/right-hemisphere to the Fig 5 caption or Results, and restore the grey/dashed trace key. Fix Fig 3A's colour (green->blue) and the top/bottom trace-position error, and confirm whether 3E plots individual trials. Re-export Fig 2A with the "Evoked suppression" axis label. Resolve ridge-vs-OLS for Fig 4E. Decide whether Fig 4G is 10 or 11 sessions and 2 or 3 mice. Add a mouse-label key, or renumber, so Fig 2 and Fig 4 do not reuse "Mouse 1/2" for different animals. Add Figure 1's D/E/F to the manifest and find or write a producer for the latency panel. Soften the model-swap claim to match its own numbers.


### 2026-10-03 — TF variants: 1.0 s window with pole cap 4 and cap 2 (neither beats the current 0.5 s fit)
**Changed/Found:** `imp_tf_run.m` with RUN_TFIT = 1.0 and RUN_MAXPOLES = 4 (maxZeros 3) and = 2
(maxZeros 1); 300-draw bootstrap; CV via `imp_tf_cv.m`; panels drawn with `imp_tf_figs.m`
(PAPER_FINAL off). Scratch: `scratchpad/tf_variants/` + comparison sheet
`fig2_tf_variants_comparison.png`. Fits: `impulse-analysis/data/imp_tf_fits_tfit1p0_{4p,2p}_2026-10-0{3}.mat`.
- 1.0 s / 4p: orders 4p2z1d, 4p3z, 4p3z, 4p3z. Fast tau 65/65/100/100 ms (current 148/93/150/142).
  AL_0041 e1 slow pole UNSTABLE (tau = 7.5e12 s), 76 % resamples discarded; others 24/4/21 %.
  Pooled CV R2 0.748 (current 0.86). Swap: M1a column/row fails (negative R2).
- 1.0 s / 2p: every session misses R2h 0.98 (0.13/0.86/0.79/0.93); AL_0041 e1 degenerates to 1 pole
  (R2h 0.127, held-out R2 < 0). One tau per session (complex pair): 720/384/243/147 ms; discard
  0 % in 3 of 4 (47 % e1). Pooled CV R2 0.627. Held-out fit misses the rebound and the onset.
- 0.5 s / 5p (current): pooled CV R2 0.86, swap diagonal 0.97-1.00, fast tau ~0.14 s in 3/4.
**Why:** User asked for 1.0 s with a 4-pole cap plus a 2-pole variant, figures reported.
**Next:** USER DECISION on Fig 2 fit settings; nothing in the paper changed (0.5 s cache restored,
finals untouched).

### 2026-10-03 — Retired paper/figures_v2; producers now write working copies to paper/images
**Changed/Found:** Every producer that exported into `paper/figures_v2/<figN>/` now writes its
working copy to `paper/images/<figN>/`: sine_ff_across_sessions (outDir now from mfilename, was a
cwd-dependent exist() chain falling back to '.'), sine_ff_plots_combined, f4_1B_equation,
f4_cl_reject_panel, f4_contra_model, f4_error_decomp, f4_kernel_map, f4_row2_quartiles,
f4_state_exemplars, step_response, variance_mse (3 exports), dose_response, trace_overlay,
imp_state_trialvar_fig, imp_tf_run, imp_tf_cv (CV_PANELDIR = CV_OUTDIR), imp_tf_figs (removed the
copy-into-figures_v2 block; E/F reach figures_final via the mirror), analysisPlots_combined (5),
jnExport doc example, paper_final_mirror comment. Final panels are unaffected: the mirror takes the
destination from the MANIFEST section, never from the source path. Docs: CLAUDE.md, PAPER.md (33
registry paths -> paper/figures_final/panels/), FIGURE_RULEBOOK.md, figures_final README/MANIFEST/
collector comments. Folder MOVED (not deleted) to `paper/_retired/figures_v2_2026-10-03/` (gitignored).
PROVENANCE.md and the RESEARCH archives keep their historical figures_v2 mentions.
**Why:** User: "retire figures_v2 thats not where we are putting plots anymore".
**Next:** next PAPER_FINAL rebuild of any figure confirms the mirror still lands every panel.

### 2026-10-03 — REJECTED: 1.0 s TF fit window (tried to fix the censored Fig-2F tau CIs)
**Changed/Found:** Ran `impulse-analysis/imp_tf_run.m` with `RUN_TFIT = 1.0` (all else default:
5p/4z/3d sweep, AIC + R2h escalation, 300-draw bootstrap, 4 sessions). Result is WORSE on every axis:
every session hits the 5-pole cap (5p4z/5p4z/5p3z/5p4z, was 3p1z/4p3z/4p3z/4p2z); fast tau
collapses to 44/17/45/134 ms (was 148/93/150/142 — the "~0.14 s shared fast constant" claim would
die); slow tau 1829/427/441/379 ms; bootstrap discard (tau > 1.0 s) still 68/55/36/32 %; pooled R2
0.66/0.32/0.81/0.84 (was 0.74/0.52/0.87/0.94); sdBetween/sdWithin 0.707/0.222. Cause: 0.5-1.0 s
contains the post-dip REBOUND (mostly gone by ~770 ms), which a low-order decaying model cannot
represent, so AIC spends poles on it and the poles become non-identifiable.
RESTORED: 1.0 s fits kept as `data/imp_tf_fits_tfit1p0_2026-10-02.mat`; `data/imp_tf_fits.mat` is
the 0.5 s cache again (backup `imp_tf_fits_tfit0p5_2026-09-29.mat`); panels tf_model_swap +
tf_tau_forest (final), tf_shape_across_sessions + tf_pole_spectrum (working) redrawn from it via
`imp_tf_figs`. Panels 2C/2D and all manuscript text were never touched.
**Why:** User chose "lengthen the fit window to about 1.0 s" to make the slow tau identifiable.
**Next:** USER DECISION on 2F: (a) per-pole censoring + CI on fast tau only, slow tau as bare
point (recommended), or (b) bare points throughout (bareA). Window stays 0.5 s.

### 2026-10-02 — Supplementary S3/S4 panels synced to the manuscript
**Changed/Found:** Copied the four regenerated supplementary PDFs (f4_exemplars_sessions,
f4_decomp_unique_{both,rel,abs}; built 21:31 on the final window + continuous estimator) from
`paper/images/supplementary/` into `Closedloop_edit/images/supplementary/` (draft 30eb736).
**Why:** S3/S4 in the manuscript still showed the legacy-estimator panels.
**Next:** none.

### 2026-10-02 — DECISION locked in CLAUDE.md: state windows + band-power estimator
**Changed/Found:** `CLAUDE.md` Locked-in decisions gained "State windows + band-power estimator —
FINAL": Fig 2 = [−1, 0) s for motion / rel δ / abs δ (2–4 Hz, bin estimator); Fig 4 = [−2, +3) s
for all three (abs δ = log10 1–4 Hz), `f4_bandpow` 'continuous', motion = mean z. Never −1..+3 or
pre-only for Fig 4. FINDINGS.md updated the same session (new Fig-4 and Fig-5 findings; K2
pre-stim-variance finding marked SUPERSEDED; TF finding gained the window/pole exploration).
**Why:** User: "ok lets finalize -2 to +3 forever"; future sessions must not re-derive it.
**Next:** none.

### 2026-10-02 — Methods: dropped the per-session TF-fit table (tab:tf_fig2)
**Changed/Found:** `Closedloop_edit/methods_rewrite.tex` — removed Table tab:tf_fig2 (4-session
orders, tau, R2_h, bootstrap discard fraction) and its reference; text now just says the discarded
fraction is reported. Old tab:tf_sessions (cited by Discussion 2.2 Hz + Methods settling time) kept.
**Why:** User: "remove the tf fit table not needed".
**Next:** the discard fraction must then appear wherever 2F is described (caption) once the 2F
error-bar fix is chosen.

### 2026-10-02 — Fig-2 panel letters: MANIFEST now follows the caption
**Changed/Found:** `paper/figures_final/MANIFEST.txt` — lettering comment + line order changed to
D = tf_cv_2D_sidebar (validation), E = tf_model_swap, F = tf_tau_forest (was D = tau, E = CV,
F = swap). `impulse-analysis/imp_tf_figs.m` comments/printout: tau forest is panel F. PAPER.md
already matched the caption. Panel files unchanged.
**Why:** User: "fig 2 caption panel is correct change the manifest".
**Next:** re-place Fig 2 in Illustrator in caption order (user: later).

### 2026-10-02 — Sine s3 logged params come from the stationary block, not the sine block
**Changed/Found:** `sessions.s3.d.params` reads previewT_steps 0, traj_freq_hz 0, traj_amp 0,
dur 3 — the values of the merged stationary iteration (ff_cond −1), not the sine block (1 Hz,
A = 2, d = 5, dur 4, per the earlier per-block audit). s1/s2 params are the sine values.
Rig (`StLab_Rainier`): K_vel = K_acc = 0.0 in `Main_experiment.py` unchanged since 5bad11a
(2026-03-27), so all three sessions ran a pure 5-sample lookahead, r̃(k) = r(k+5).
**Why:** Methods now state d, K_preview, A per session; anyone reading s3 params directly would
get the wrong values.
**Next:** if s3 parameters are ever needed programmatically, read them from the sine block's
input_params, not `d.params`. Kp/Ki/Kr per sine session are not in params (Methods %% FILL).

### 2026-10-02 — TF bootstrap is heavily censored; Fig-2 lettering differs between MANIFEST and caption
**Changed/Found:** From `impulse-analysis/data/imp_tf_fits.mat` (saved 2026-09-29), the fraction of
τ bootstrap resamples discarded as non-identifiable (slow τ > 0.5 s window) is 42 % (AL_0041 e1),
50 % (AL_0041 e2), 2 % (AL_0033), 50 % (AL_0048). AL_0041 e2's slow-τ CI [155, 502] ms EXCLUDES its
point estimate 540 ms. Slow τ = 176/540/333/302 ms, so results.tex's "slower constant ~0.2–0.3 s"
does not cover 540. Fast τ 148/93/150/142 confirms "0.14–0.15 s in three of four" ✓.
Separately: MANIFEST locks D = tf_tau_forest, E = tf_cv_2D_sidebar, F = tf_model_swap, but the
results.tex caption describes D = validation, E = swap, F = timescales.
**Why:** Caption 2F promises "95 % bootstrap confidence intervals"; at 50 % censoring those are not
usable intervals (the bareA option in imp_tf_robust_fig.m exists for exactly this).
**Next:** USER DECISION: (a) show 2F as bare points + report discard fraction, or (b) keep CIs and
caveat; fix the "0.2–0.3 s" sentence; reconcile Fig-2 panel letters (MANIFEST vs caption).

### 2026-10-02 — Methods synced to the code behind every figure (methods_rewrite.tex)
**Changed/Found:** `Closedloop_edit/methods_rewrite.tex`: eq:dff baseline 20 s/700 → **40.0 s / 1400
samples** (CHECK reduced to kernel size); added "Two ΔF/F normalizations" paragraph; replaced
"Pre-stimulus state measures" with "Brain-state measures" (Fig-2 [−1,0) vs Fig-4 [−2,+3) windows
with rationale, mean-of-z motion, both spectral estimators with Eq. bandpow; deleted the false
"pre-stimulus-only window gave the same result" claim); NEW subsections "State exemplars and error
decomposition" (unique R², sep mode, ≥12 trials/session, exemplar margin rule), "Impulse-response
variability and brain state" (Fig 2G DV, percentile quartiles, SD ratio + 2000 bootstrap,
|z| ~ state + (1|session), stim-free control −1.20..−1.03 s), "Sinusoidal reference and preview"
(Eq. sine_ref/preview, four modes, sessions, Fig-5 metrics + Parseval decomposition); rewrote
TF fitting (amp²-weighted h(t), split-half CV, model swap with free gain, τ bootstrap with discard
rule) + new Table tab:tf_fig2; Statistics notes Fig 5 is descriptive; S3/S4 captions fixed
(S4 said "relative 1–4 Hz"). latexmk clean, no undefined refs. Script: scratchpad methods_edits.py.
**Why:** User: "change methods to follow what code actually does" + items 5–9 of the audit.
**Next:** FILLs left for user: Kr/Kp/Ki per sine session; old tab:tf_sessions provenance (CHECK);
kernel size on rig.

### 2026-10-02 — Fig-5 Results made descriptive (no significance tests)
**Changed/Found:** `results.tex`: removed caption-G star legend, the rank-sum p's (7.7e-4, 0.32,
0.093, 0.020), pooled rank-sum/Kruskal–Wallis/Friedman; replaced with medians and pooled mean ± SD.
OL+p 4.47 ± 2.22 (n = 110) and CL+p 3.95 ± 1.58 (n = 132) re-verified by running
`sine_ff_across_sessions.m` (EXPORT=false). Fixed "roughly threefold in every comparison" (actual
3.5× OL→OL+p, 1.5× CL→CL+p) and the "4\,s,." typo.
**Why:** User: "fig 5 n is too small for statistical tests we can report trends".
**Next:** none.

### 2026-10-02 — Fig-5G significance brackets switched off (SINE_SHOW_STATS knob)
**Changed/Found:** `bilateral/sine_ff_plots_combined.m`: new knob `SINE_SHOW_STATS` (default false);
when false no brackets/stars are drawn (p-values still printed to console). Fig 5 rebuilt; 5G is now
3.74 × 2.89 cm (MANIFEST updated).
**Why:** Fig 5 reports trends only (n = 3 sessions).
**Next:** user re-places 5G in Illustrator.

### 2026-10-02 — Fig-4 Results text updated to the final window + continuous estimator
**Changed/Found:** `results.tex` (9 edits, scratchpad f4_results_edits.py): caption A states the
[−2,+3) s window; 4C init 0.41→0.03, rel 2–4 Hz 0.15→0.19, abs 1–4 Hz 0.28→0.44; 4D rel
controllability↓ p = 0.032 (+0.12, CI [+0.01, +0.23]); gap bound p ≤ 3.7e-5; decomposition cohort
11 sessions / 613 CL trials (was a stale 7 / 397); motion slopes OL +0.13 p = 0.002, CL −0.05 p = 0.47,
11/11 sessions p = 0.001; body framing of the window per user rationale.
**Why:** Text quoted the legacy bins estimator and an old cohort.
**Next:** user re-places Fig 4 A/C/D in Illustrator; per-session rel-δ signrank is 0.083 (n.s.) —
the LMM is the reported test.

### 2026-10-02 — Grid-independent band power adopted for Fig 4 (f4_bandpow 'continuous')
**Changed/Found:** NEW `utils/f4_bandpow.m` ('continuous': detrend, Hann, NFFT = max(8192,
2^nextpow2(8N)), PSD = 2|X|²/(Fs·Σw²), trapezoid between exact band edges with interpolated
endpoints; 'bins' = legacy). `f4_state_window.m` carries `W.bandpow` ('peri' → continuous,
'legacy' → bins); `cl_reldelta.m` gained `opts.bandpow` (default 'bins', other callers unchanged);
f4_row2_pool / f4_row2_quartiles / f4_error_decomp / f4_state_exemplars(_supp) route through it.
Final Fig 4: 4C init .412/.026, motion .000/.000, rel .145/.189, abs .280/.437; 4D initdev pred
2.1e-10 / ctrl .74 / gap 1.4e-7; motion 7.3e-4 / .0015 / 3.7e-5; rel pred .34 / ctrl β +.119
[+.010, +.228] p = .032 / gap 8.0e-8; abs pred 3.8e-34 / ctrl .23 / gap 3.3e-8. Robust: ρ = 0.9999
across 174/175/176-sample windows, rel ctrl p .034/.032/.031 (bins gave .074 ↔ .009).
**Why:** User: "compute band power so the band edges don't depend on the number of samples, then
report whatever that gives."
**Next:** Fig 2 still uses the bin estimator — harmless there (35 samples, 1 Hz grid, bands land on
bins), but could be switched for uniformity if a reviewer asks.

### 2026-10-02 — Fig-4 window confirmed -2..+3 s (not -1..+3); rel-δ controllability is band-edge fragile
**Changed/Found:** User decision: Fig 2 states strictly pre-stimulus [-1,0) (already true — motion
`iMot` and spectral `iState=iPow` are the same 35 samples, `imp_state_trialvar.m:181-201`); Fig 4
all states over -2..+3 s, motion/rel/abs on the SAME window. User then asked whether Fig 4 is
actually -1..+3. Checked source, git history (`git log -G"'pre',\s*1"` empty) and the data: the
states read **-2.000..+3.000 s**. The only -1 s array is the trial trace `wcDfk` (-1..+4 s, onset
col 36), used for RMSE and initial deviation, not for states. `f4_state_window.m` redefined:
`'peri'` = ONE 175-sample window [-2,+3) for all three states; `'legacy'` = the old split
(spectral 176 / motion 175), verified bit-identical to the committed code. Also patched
`f4_state_exemplars_supp.m` (Fig S3) onto the shared window.
**Unifying moves rel-δ:** controllability p **0.0742 -> 0.00857** (pred 0.403 -> 0.418), abs-δ
pred 3e-33 -> 6e-35 / ctrl 0.15 -> 0.305; init-dev and motion unchanged (rho of state 1.000).
rho(rel-δ state, legacy vs unified) = 0.912. Cause is NOT the dropped +3.000 s sample (its step
is 1.0x a typical step, n=852): it is the FREQUENCY GRID. N=176 -> df 0.199 Hz, 2-4 Hz band =
2.19..3.98 Hz; N=175 -> df 0.200 Hz, band = 2.00..3.80 Hz. The band-edge bins swap, and on a
1/f spectrum the 2.0 Hz bin dominates.
**Why:** A published p-value that moves 9x under a one-sample change is not robust; it should
not be reported as either a firm effect or a firm null without saying so.
**Next:** USER DECISION before rebuilding Fig 4 on the unified window. Options: adopt unified
175 (rel-δ ctrl becomes p=0.0086), keep legacy, or make the band estimate grid-independent
(e.g. Welch / interpolated band edges) so the result stops depending on N.

### 2026-10-02 — Fig-4 "pre-stimulus" states are measured over -2..+3 s; two claims depend on post-onset data
**Changed/Found:** User asked to confirm Fig 4 uses the correct window for rel 2-4 Hz and abs δ.
Every Fig-4 consumer measures motion, relative 2-4 Hz and absolute 1-4 Hz power over **-2 s to
+3 s** — but `results.tex:136-139` calls them "four pre-stimulus quantities ... read from the
trial itself before the laser turns on", and three of those five seconds are inside the 0-3 s
error window they are used to explain. (The [-1,0) move earlier today was Fig 2 only; this
session's Hub entry saying Fig 4 moved too was wrong.) Added `utils/f4_state_window.m` — ONE
window definition (`'peri'` published | `'pre2'` -2 s..onset | `'pre1'` -1 s..onset; pre windows
end on the last sample BEFORE onset) — threaded through `f4_row2_pool` (4th arg),
`f4_row2_quartiles` (pool AND its inline block), `f4_error_decomp`, `f4_state_exemplars` via
knob `F4_STATE_WIN`; `cl_reldelta` gained an optional `opts.rel_idx`. **Default `'peri'` verified
bit-identical** to the committed code (all four pooled tables `isequal`, 1670/1190 trials) and
reproduces published 4C exactly. Results:
- **4D motion:** pred p 7.3e-4 / ctrl **p 0.0015** (peri) -> 0.75 / **0.27** (pre2) -> 0.70 / **0.40** (pre1). The published motion claim rests ENTIRELY on movement during the trial.
- **4D rel 2-4 Hz:** pred 0.40 / ctrl 0.074 (peri) -> **pred 2.1e-4** / ctrl 0.75 (pre2) -> pred 0.0098 / ctrl 0.42 (pre1). The story inverts: pre-stimulus rel power predicts OL error and does not modulate controllability.
- **4D abs 1-4 Hz:** predictability robust (3e-33 -> 2.5e-18 -> 6.7e-15), ctrl n.s. in all.
- **4D init-dev:** identical in all three (measured at onset) — confirms the knob touches only what it should.
- **4C** unique R² steady-state: rel 0.134 -> 0.089 / 0.072, abs 0.441 -> 0.276 / 0.261; transient init-dev 0.387 -> 0.317 / 0.325; motion ~0 throughout. Shape survives, spectral magnitudes drop ~35-45%.
**Why:** The Methods claims "a pre-stimulus-only window, -2 s to onset, gave the same result and
serves as a circularity control". Tested, it does NOT for 4D. The circularity is real for the
spectral pair: they are computed from the very readout whose RMSE they predict. Motion is
different in kind — it comes from an independent sensor (camera), so concurrent motion is an
exogenous disturbance, not circular — but it is then a during-trial disturbance, not a
pre-stimulus state, and must be named as such.
**Next:** USER DECISION on the window (and the motion framing). Published default left unchanged
until then; no panel or manuscript number has been altered. Also fix `results.tex:138`
"absolute 2--4 Hz" -> 1--4 Hz (code and caption are 1-4 Hz).

### 2026-10-02 — Figures 2–5 re-assembled and synced into the manuscript
**Changed/Found:** User re-assembled Figs 2–5 in Illustrator (20:34–20:45) from the rebuilt
`figures_final/panels/` set; copied the four `FigureN.pdf` into `Closedloop_edit/images/` and
recompiled. `Figure1.pdf` was NOT copied — the local assembly is byte-identical to the
manuscript's copy (md5 75ba35c5, 205015 B), so there was nothing to sync. Compile: latexmk
exit 0, **0 errors, 0 undefined references, 0 missing figure files, 35 pages**. Pushed to
`draft` as 13a3df7.
**Why:** The manuscript still carried the 2026-09-30 assemblies, built from panels that the
clean rebuild has since shown to differ from current code output.
**Next:** Supplementary figures are the next target — the manuscript's supplementary includes
live in `methods_edit.tex` and point at `images/supplementary/`, which is NOT covered by
MANIFEST.txt beyond two tf_cv panels. Audit that set the same way.

### 2026-10-02 — Full clean rebuild of all 38 final panels; every single one changed
**Changed/Found:** Regenerated the whole manifest set from a cleared MATLAB state
(`clear all; clear functions; rehash`, data reloaded from the verified cache) with
`PAPER_FINAL=true`. Audited by md5 against a pre-rebuild baseline: **35/35 producer panels
REBUILT — not one hash matched.** So the panels sitting in `panels/` before today's rebuild
were NOT what the current reviewed code produces; they were mirrored across a 14:12–14:45
window, several of them before the last round of fixes landed. Verified on the way through
that the clean run reproduces the corrected numbers: Fig-2 motion 0.73 [0.62–0.87] p=2.43e-07
4/4 on the [-1.00,-0.03] s window with 3 bins in 2–4 Hz; Fig-4 rel-δ controllability p=0.0742,
motion p=0.00147; RR=0.58 [0.48,0.71] p=2.1e-08. All paper-config knobs (`STV_MOT_STAT='mean'`,
`STV_MOT_WIN='paper'`, `STV_PWR_WIN='paper'`) are the script defaults and no caller passes
`'sq'`, so a clean workspace cannot silently select a secondary config.
**Why:** User did not trust that the panels in the folder came from the reviewed code rather
than a pre-fix run — "i am not sure if you made the new figures in the first place". Inspection
cannot answer that; only a rebuild from a cleared state can, and the all-changed hash audit
shows the doubt was justified.
**Next:** `svd_frame_AL_0039_2025-04-19.pdf` (Fig 1) could NOT be rebuilt — m10's cache is slim
(no `d.svd`), so `load_sessions` skips that panel. It is the one stale producer-made panel in
the folder; force a server reload for m10 to regenerate it.

### 2026-10-02 — Size guard: panels were importing into Illustrator larger than their canvas
**Changed/Found:** New `utils/pdf_page_cm.m` (reads /MediaBox → cm) and `utils/jn_fit_canvas.m`;
`paper_final_mirror.m` now measures every exported panel against its figure canvas and, if it
overflows, retries with the content pulled inside — **keeping the refit only if it actually
reduces the overflow**. Root cause: `exportgraphics(...,'ContentType','vector')` crops to the
CONTENT box, not the canvas, so anything overhanging enlarges the page. 5 of 35 panels were
oversized; 4 are now fixed (`imp_response` 3.85→2.89, `tf_cv_2D_endlabels` 4.48→3.25,
`tf_cv_single_AL_0033` 5.93→5.36, `tf_cv_2D_sidebar` 4.73×3.77→3.99×3.35).
**Why:** User: "the figures that land in the folder must not be oversized". An oversized panel
forces a manual scale in Illustrator, which silently breaks the rule-book type sizes.
**Next:** `f4_state_exemplars.pdf` is STILL oversized (7.83 × 3.56 vs 7.50 × 3.30 canvas,
+0.33/+0.26) — the automatic fit cannot improve it and was correctly rejected rather than
allowed to make it worse. It needs a hand layout change in `f4_state_exemplars.m`; that is a
visual decision on a paper panel, so ask before changing it.

### 2026-10-02 — MATLAB's PositionConstraint does NOT fix export overflow (rejected approach)
**Changed/Found:** First version of `jn_fit_canvas` set `PositionConstraint='outerposition'`
on every axes, the documented way to make decorations fit. It moved `imp_response` by exactly
0.00 cm. Reason: that constraint only accounts for decorations MATLAB owns (ticks, xlabel,
ylabel, title) — it ignores free-standing `text()` objects, and our panels draw the y label as
a manual rotated text at axes-normalized x ≈ −0.32, which lands ~0.7 cm outside a 3.4 cm
canvas. Replaced with an explicit measure-and-inset loop over text extents, `TightInset`
(tick labels are ruler-drawn, not text objects — missing this hid 0.47 cm of vertical
overflow on `tf_cv_2D_sidebar`) and legend/colorbar positions.
**Why:** Worth recording so the obvious one-line "fix" is not tried again.
**Next:** none.

### 2026-10-02 — dose_response drew a stray 'dF/F %' label outside the panel
**Changed/Found:** `impulse-analysis/dose_response.m` — line 111 sets `ylabel('dF/F %')`, but
line ~192 draws the REAL y label as a manual rotated text. Both were being rendered: MATLAB
pushes the built-in label further out to clear the manual one, so a stray `dF/F %` sat ~0.75 cm
to the LEFT of the real label. Invisible at screen size, present in the vector export, and —
being the leftmost object — it set the crop. Added `ylabel(ax,'')` before the manual text.
**Why:** Found by the new size guard, not by eye. It is a visible defect on a paper panel, not
just a sizing nuisance.
**Next:** Other panels use the same manual-rotated-label idiom; grep for `Rotation',90` if
another panel shows an unexplained left overhang.

### 2026-10-02 — load_bilateral's `clear all` silently disarms the panel mirror
**Changed/Found:** `bilateral/load_bilateral.m:15` runs `clc; close all; clear all;`. `clear all`
clears GLOBALS, so `PAPER_FINAL` went false mid-rebuild and the entire Figure-5 block exported
to `figures_v2` while mirroring **nothing** — with no error and no warning. Caught only because
`PAPER_FINAL_LOG` read 0 after the run. Re-armed and re-ran; all 10 Fig-5 panels then mirrored.
Did NOT edit `load_bilateral` (its `clear all` is deliberate — it rebuilds the session structs
from scratch); the rebuild driver re-arms after it instead.
**Why:** This is the exact failure mode that makes a folder look rebuilt when it is not, so it
belongs in the log rather than in a fix that hides it.
**Next:** Any future batch that runs `load_bilateral` partway through must re-arm `PAPER_FINAL`
afterwards. Consider having the mirror warn once per session if it is called with the global
unset while a MANIFEST panel is being written.

### 2026-10-02 — MANIFEST now records each panel's true import size
**Changed/Found:** Every panel line in `paper/figures_final/MANIFEST.txt` now carries a
`# W x H cm` note measured from the exported PDF's MediaBox — the size the panel actually
lands at in Illustrator, which is NOT the MATLAB canvas size because the vector export
tight-crops. Both parsers (`paper_final_mirror.m`, `collect_final_panels.m`) strip a trailing
`#` note before taking the basename, splitting on `#` only so paths with spaces
(`schematic_optoephyswf (1).pdf`) still resolve. Verified: 38 present, 0 missing, 0 pruned.
**Why:** User: "figures imported into illustrator should be same size used in manifest".
Recording the measured size makes placement deterministic and makes future size drift show up
in a diff instead of being discovered on the page.
**Next:** Re-run the audit after any panel is re-exported, so the recorded sizes stay true.

### 2026-10-02 — Consolidate to ONE final-panel folder: paper/figures_final
**Changed/Found:** Deleted `utils/paper_v3_mirror.m` and the whole `paper/figures_v3/` tree;
added `utils/paper_final_mirror.m`, which writes the jn-style copy straight into
`paper/figures_final/panels/<section>/` (global renamed `PAPER_V3` → `PAPER_FINAL`,
`PAPER_V3_LOG` → `PAPER_FINAL_LOG`, plus a locked-file warning branch for panels open in
Illustrator). Repointed `utils/paperExport.m` and `utils/jnExport.m` at it. Moved the 71 jn
files (38 PDFs + PNGs) from figures_v3 into `panels/`. **Rewrote
`paper/figures_final/collect_final_panels.m`:** it used to `copyfile` each manifest source
out of `figures_v2`/`images` into `panels/`, which would have overwritten every jn panel with
its pre-restyle original — its job is now verify + prune only. Updated `MANIFEST.txt`'s header,
`figures_final/README.md` (it still described an 8-panel Fig 2 and the retired f4_2A..f4_2D
set) and the CLAUDE.md "Finalized-panels rule". `collect_final_panels('dry')` → **38 present,
0 missing, 0 to prune.**
**Why:** User: "only maintain one single folder for jn style final paper panels ill go there
and pull them into illustrator". Two folders both claiming to hold the final set is how a
superseded panel reaches Illustrator; and the collector's copy step was a live last-writer-wins
trap pointing at the non-jn sources.
**Next:** Re-place the 4 changed panels (Fig 2G, Fig 4A/C/D) in Illustrator — only
`all_variance_sessions` (+0.25 cm) and `f4_kernel_map` (+0.18 cm) need resizing; the other 36
are drop-in. `wfpath.pdf` is still a full A4 page and needs cropping.

### 2026-10-02 — Delete stale commented-out prose from results.tex
**Changed/Found:** Removed 28 lines from `Closedloop_edit/results.tex` (290 → 262): line 67, a
commented duplicate of the Fig-2 state-dependence paragraph carrying the superseded 0.71/1.10/1.99
ratios, and lines 191–214, commented draft prose plus per-panel stat notes with the now-wrong
`motion p=0.014423`, `rel p=0.01412`, `n=11 (motion 7)`. Deliberately KEPT the `% ---` rules at
218/220/258/260 (they bracket live `\subsection*` headers) and the figure-provenance notes at
111–117/129–134 that record which MANIFEST entry each `\includegraphics` comes from. Recompiled:
`latexmk` exit 0, 0 undefined references, PDF byte-identical at 5,980,646 bytes.
**Why:** User: "delete the stale commented block". Dead comments holding pre-correction numbers
are the most likely way a wrong value gets resurrected into the live text months later.
**Next:** none — the live text already carries the corrected values.

### 2026-10-02 - Hardening pass: four failure modes that did not look like failures
**Changed/Found:** Fixed the four things that cost time today, each of which let a script succeed while doing the wrong thing. All verified by test, not by inspection.
**1. `imp_state_trialvar_fig.m` - a manifest panel behind TWO opt-in flags.** `imp_state_var_combined.pdf` (Fig 2G) required `STVF_PAPER=true` AND `STVF_UNITS='norm'`, defaulting `false` and `'sd'`. An ordinary run skipped it in silence, which is why 2G sat at its 2026-09-30 build through a full day of Fig-2 work and surfaced only in a coverage audit. Now `STVF_PAPER=true` is SUFFICIENT (implies `'norm'` unless units were set explicitly), and with paper mode off it warns **by panel name**. Tested both: auto-switch fires and builds 2G; the off path raises `STVF:noPaperPanel`.
**2. `f4_row2_quartiles.m:142` - relative output path.** `outview=fullfile('_preview')` resolved against the cwd, so running from the project root created a SECOND preview dir at `brain_paper/_preview/` while everyone reads `controller-analysis/_preview/`. That is why the stitched panel's PNG read hours stale while its PDF was current. Now derived from the script's own location via `which()`. Stray dir deleted (5 files).
**3. `utils/assert_pooled.m` (NEW) - a pooling loop that collects nothing now ERRORS.** Twice today a script ran to completion and exported a panel built from zero sessions (`cl_factor_decomp_panel`, `trial_state_mse`), both from a field-presence test used as a data-availability test. Guards added to `f4_error_decomp` (trials + sessions), `cl_factor_decomp_panel` (both pools), `cl_rmse_factor_windows`, `f4_state_exemplars_supp`, and `trial_state_mse` - where a `warning(...); return;` was ALSO a clean exit and is now an error. Verified: all five still run on real data, and a deliberately emptied pool raises "POOLED NOTHING: f4_error_decomp CL trials collected 0".
**4. `utils/ctrl_cache_stamp.m` (NEW) - caches now record how they were built.** Both save sites in `load_sessions.m` stamp `d.provenance` with `dff_mode`, `dff_w`, `slim`, the short git commit and a UTC timestamp. **This is the direct lesson of the Fig-4C diagnosis**, which needed a five-way elimination ending in "run the pre-finalization script" only because no cache records its own state. Absent values are recorded as NaN rather than guessed, so an old cache stays visibly unknown instead of acquiring a plausible lie - self-test on `AL_0033ctrl02122` returned `dff_mode NaN` (honestly unknown), `dff_w 1400` (recovered from `params.horizon`), `slim 1`, `git 6f11ddc`.
**Why:** User asked for the remaining coding work and approved this pass. Every item here is "a failure that reports success", which is the class of bug that actually cost hours today.
**Next:** (a) The guards cover the FINAL-panel producers; `f4_lowfreq_examples.m:28` still has a bare `continue` on a missing field but produces no manifest panel. (b) Existing caches stay unstamped until rebuilt - the stamp only applies going forward, by design. (c) Still open and untouched: the `trialwin`/`tq` migration across ~10 files with hardcoded `c0_mot=71`/`c0_l=106`/`c0_p=351` literals, the duplicated pooling block in `f4_row2_quartiles.m:80-95` (now harmless, both sides call `f4_motion_stat`), and the 13 older caches lacking spectral arrays.


### 2026-10-02 - DECISION (user): the two dF/F definitions stay separate and get reported
**Changed/Found:** I raised the Fig-2 vs Fig-3/4 dF/F difference as a consistency problem. **It is not one - the user states both choices are purposeful**, and the reasoning is right:
- **Impulse is not in feedback**, so there is no need to estimate the mean online and no causal constraint on the denominator. The constant mean-image divisor (`load_experiments.m:221`, `dF = F/mI(1)*100`) is simply the most stable choice available to an offline analysis.
- **The controller needs an online mean estimate**, because the loop can only use past samples. Hence the trailing baseline.
**Verified the controller side is even tighter than "a 40 s window":** `utils/getpixel_dFoF.m:120` takes `w = d.params.horizon`, and that is **1400 samples = exactly 40.0 s at 35 Hz, identical across all 15 sessions** (checked every cache). So the analysis baseline is **the controller's own horizon parameter** - not an analysis choice at all, but the window the hardware actually used.
**This reframes the whole thing as a STRENGTH.** The controller's dF/F *is* the signal the loop fed back on. Re-deriving Figs 3-5 with a retrospective whole-session mean would characterise a signal the controller never saw, so matching the impulse definition would make the controller analysis LESS correct, not more. The apparent inconsistency is the two analyses each using the definition their causal structure permits.
**It also explains cleanly why only Fig 4C moved** (see the two preceding entries): Fig-2's statistics are provably invariant to a constant rescale (rank quartile binning + z-scored DV, measured 0.00e+00 under x1.7), so the impulse choice cannot leak into its numbers. Fig 4C regresses raw amplitudes, so it tracks whatever dF/F is in force.
**Logged as a LOCKED project decision in `CLAUDE.md`** under a new "ΔF/F — TWO definitions, deliberately" block, with an explicit "do not reconcile them" so a future session does not try to unify them as drift.
**Why:** User decision, with the mechanism verified rather than taken on trust.
**Next:** Methods needs a short paragraph stating both definitions and the causal reason for the difference - drafted and handed to the user as a chat snippet (the manuscript lives on Overleaf; the local `Closedloop_edit` repo is not touched). No code change follows from this: both pipelines already do the right thing.


### 2026-10-02 - Fig 2 is PROVABLY immune to the Fig-4C dF/F fingerprint; check withdrawn
**Changed/Found:** I proposed checking whether the Fig-4C amplitude fingerprint also touches Fig-2's abs-delta (2.10) and pre-var (3.13), since those are amplitude-sensitive in the same way. **Tested it instead of assuming, and the answer is no - withdraw the check.** Scaling every trial's dF/F by 1.7 (exactly what a change in `mI(1)` does at `load_experiments.m:221`, `dF = F/mI(1)*100`) moves all four Fig-2 ratios by **0.00e+00**:
| marker | x1 | x1.7 | diff |
|---|---|---|---|
| Motion | 0.7266 | 0.7266 | 0.00e+00 |
| Pre-trial variance | 3.1305 | 3.1305 | 0.00e+00 |
| Abs delta power | 2.0987 | 2.0987 | 0.00e+00 |
| Rel delta | 1.0279 | 1.0279 | 0.00e+00 |
**Two independent structural reasons, which is why it is exact and not approximate:** (1) trials are binned into **quartiles by RANK** of the marker, and a positive constant scale is monotone, so quartile membership cannot change; (2) the DV is **z-scored within amplitude**, so an SD ratio is scale-free. Fig 4C has neither protection - it regresses raw `|dFk(onset)-ref|` and raw `log10` power on raw RMSE, so absolute scale enters the fit directly. That is the real reason the two figures respond differently, not anything about the markers themselves.
**The protection is specific to a CONSTANT rescale and would NOT survive a time-varying baseline.** A rolling-baseline dF/F is a per-timepoint, non-monotone transform; it reorders trials, so rank binning stops protecting. The impulse path has not changed - `load_experiments.m:221` is still the constant-divisor form and was untouched today.
**The genuine issue this surfaces is a consistency one, not a numbers one:** Fig 2 (impulse) uses `dF = F/mI(1)*100`, a constant mean-image divisor, while Fig 3/4 (controller) now use the rolling 40 s trailing baseline `(F - Fkmean)/Fkmean*100` after today's unification. **Two figures in one paper define dF/F two different ways**, and Methods currently describes one.
**Why:** The user asked what the proposed check meant; checking it was cheaper than explaining why it might matter, and it turned a speculation into a closed question.
**Next:** (a) **Methods must state both dF/F definitions and why they differ**, or the impulse path moves onto the rolling baseline too - the latter is a real re-analysis (it would reorder impulse trials and is NOT protected by the rank/z-score argument above), so it is a decision, not a cleanup. (b) Do NOT spend time re-checking Fig-2 numbers against the Fig-4C cause; it is closed. (c) Fig-4C caption renumbering still stands.


### 2026-10-02 - Fig-4C diagnosed: the CODE is exonerated, the CACHES changed, and the fingerprint says dF/F
**Changed/Found:** Chased the Fig-4C discrepancy (published `0.29/0.10/0.23` vs fresh `0.387/0.095/0.276`) to a conclusion by elimination. Four candidates are now EXCLUDED BY MEASUREMENT, not by argument:
| candidate | test | result |
|---|---|---|
| motion statistic | mean(z) vs mean(z^2) | moves unique R^2 by <= 0.003 |
| pre-buffer switch | `_l` (onset 106) vs long (onset 351) | byte-identical -2.000..3.000 s slice |
| the two new sessions | drop m14 AL_0048 + m15 AL_0051 (613 -> 513 trials) | **WORSE**: dev 0.097 -> 0.112 |
| today's dF/F recompute of m14/m15 | same test (they are the only recomputed ones) | excluded with the above |
| **the code itself** | **ran `git show 91ad3dd:f4_error_decomp.m`, the pre-finalization version, on today's data** | **0.388/0.096/0.275 vs current 0.387/0.095/0.276 - IDENTICAL** |
**So the published panel was computed on a CACHE STATE THAT NO LONGER EXISTS.** Same script, same trials (613 / 11 motion sessions both ways), different inputs.
**The fingerprint points at dF/F, and it is specific.** Of the three factors, the two that moved are exactly the AMPLITUDE-SENSITIVE ones - init-dev `|dFk(onset) - ref|` (0.29 -> 0.387) and abs-delta `log10` absolute power (0.23 -> 0.276, 0.35 -> 0.441). The one that did NOT move is rel-delta (0.10 -> 0.095), which is a RATIO of band powers and therefore invariant to any rescaling of dF/F. A change in the dF/F definition is the one hypothesis that predicts that split; a change in trial selection, windows or bands would not spare the ratio.
**Why this is not alarming for the science:** no claim in `results.tex` is reversed. The ordering is unchanged - init-dev owns the transient, abs-delta dominates the steady state, rel-delta is intermediate, motion is ~0 - and motion's "<0.01" is reproduced exactly. Only the three magnitudes quoted in the caption and at `:153-156` are low, all in the same direction (the current, unified dF/F yields LARGER unique R^2 for the amplitude-sensitive factors).
**Why:** User asked for the next step; this was the top open correctness item, and leaving an unexplained gap on a main-text panel was not acceptable before assembly.
**Next:** (a) **Renumber the caption from the current panel** rather than hunting the old cache - the present pipeline is the audited one (rolling 40 s baseline, verified to reproduce cached F to 0.000e+00) and the old cache state is not recoverable or defensible. New values: init-dev **0.39 -> 0.02**, rel **0.10 -> 0.13**, abs **0.28 -> 0.44**, motion `<0.01` unchanged. (b) Confirm the same amplitude fingerprint does not touch any OTHER published number built on absolute dF/F magnitude - Fig-2's abs-delta and pre-var are the obvious ones to check. (c) `slim_ctrl_cache.m` / any future cache rebuild should stamp a provenance field (dff_mode + date) into `d`, so "which cache state produced this panel" is answerable instead of inferred - none of the 15 caches currently carries `d.dff_mode`.


### 2026-10-02 - Fig 2G / Fig 4D state-quartile panels: pooled display vs session-level stats
**Changed/Found:** `controller-analysis/f4_row2_quartiles.m` — the drawn quartile bars pool all trials (quartile edges from the pooled z-state, L147) with **trial-SEM** error bars (L151-152), but the panel star comes from the session-aware LMM and the session signed-rank, which use **per-session** quartile edges (L119). PAPER.md (2026-08-13 entry) says the bars carry SEM *across sessions*; the current code does not. `impulse-analysis/imp_state_trialvar_fig.m` (2G) does the same thing: a pooled curve with a trial-bootstrap CI next to an LMM (1|session) star and a "k/N sess" count. No code changed.
**Why:** User flagged the mismatch between the pooled plots and the session-specific significance tests in Figs 2 and 4.
**Next:** DECIDED (user, same day): keep the pooled trial-level display and its trial-level error bars as they are. Add a caption sentence to Figs 2G and 4 (quartile row) saying the display is pooled over trials and the inference is session-level (mixed model + per-session agreement). Per-session-line redraw NOT done. Correct the stale PAPER.md 2026-08-13 claim ("SEM across sessions").

### 2026-10-02 - figures_v3: all 38 FINAL panels rebuilt in jn (rule-book) style
**Changed/Found:** User asked for every finalized paper panel regenerated in jn style into a separate v3 folder. Built `paper/figures_v3/` = **35 of 38 panels regenerated + 3 Figure-1 panels copied**, with **zero non-final files**.
**Mechanism - one hook, no 15-script refactor.** New `utils/paper_v3_mirror.m`, called from BOTH `paperExport` and `jnExport` (every producer funnels through one of them). With `global PAPER_V3 = true` it runs `jnAxesAll` (Arial, ticks 6 pt regular, axis labels + titles 7 pt bold, ticks out, box off, axis 0.5 pt - FIGURE_RULEBOOK §3) and writes an additive PDF+PNG under `figures_v3/`. `jnAxesAll` was written for exactly this: "rather than refactor every call site, this restyles the finished figure".
**Only typography changes, and that was verified rather than assumed:** `paperStyle`'s `lw_*` were already on the rule-book values (`lw_mean` 1.0, `lw_ref` 0.75, `lw_fit` 1.0, `lw_ind` 0.4) and the two styles' condition colours are IDENTICAL (`col_ol` [1 0 0], `col_cl` [0 0.40 0.85]). The real divergence was `paperStyle`'s single 6 pt bold for ticks AND labels vs the rule book's 7 bold / 6 regular split.
**GATED ON THE MANIFEST (user, mid-task: "you are exporting too many figures, i only asked for finalized paper figures").** First pass mirrored every vector export and produced ~30 unwanted files - producers emit exploratory views, per-mode variants and supplements alongside the keepers. The mirror now keys on `paper/figures_final/MANIFEST.txt`, the project's existing definition of final, and files each panel under the manifest's own `[section]` rather than its source path - which also puts `tf_cv_2D_endlabels` / `tf_cv_shape_across_sessions` in `supplementary/` where the manifest wants them, not `figure2/`. 23 already-written non-final PDFs were purged.
**Producers run:** `analysisPlots_combined` (Fig-3 A-E, exemplar session m10 per `load_sessions.m:333`), `variance_mse` (3), `step_response` (1), `imp_state_trialvar(_fig)` (2G), `imp_tf_cv` (1 + 2 supp), `imp_tf_figs` (2), `dose_response` (1), `trace_overlay` (1), six Fig-4 scripts (7), `sine_ff_plots_combined` (7), `sine_ff_across_sessions` (3).
**The 3 Figure-1 panels are COPIED, not regenerated, and a README in the folder says so.** `wfpath.pdf` and `schematic_optoephyswf (1).pdf` have no producer in the repo (hand-made drawings); `svd_frame_AL_0039_2025-04-19.pdf` needs the `d.svd` the slimming removed. Nothing is lost: `jnAxesAll` only retypesets axis labels/ticks/titles and none of the three has MATLAB axes.
**Two gotchas worth remembering:** (1) `global` values do NOT reliably reach a producer run through a nested `evalin('base','evalc(...)')` - Figure 5 reported 0 panels until it was called directly, with MATLAB warning "local variables may have been changed to match the globals". (2) `imp_tf_cv` auto-invokes `load_experiments` when its inputs are missing; a failed invocation left `allExperiments` at **numel 1** instead of 4, silently shrinking the impulse dataset. Restored from the scratchpad snapshot and re-run. Any impulse result computed while that was true would have been wrong - today's Fig-2 numbers were not, they printed n=1767 / 4 sessions.
**Why:** User instruction. v3 is additive, so the locked v2/figures_final set is untouched and this cannot damage the current assembly.
**Next:** (a) Spot-check a v3 panel against its v2 twin for label-size overflow - 6 -> 7 pt on axis labels grows the cropped bbox slightly, which can change the Illustrator placement width. (b) Decide whether `figures_v3` or `figures_final/panels` becomes the pull-folder; keeping both invites exactly the drift `MANIFEST.txt` exists to prevent. (c) `f4_decomp_unique_sep.pdf` in v3 still carries the unexplained Fig-4C magnitude discrepancy - the jn pass does not touch it.

### 2026-10-02 - CORRECTION: the Row-1 scripts were never "dead"; the `_l` buffers are built at LOAD time
**Changed/Found:** `load_sessions.m:309,316` **creates** `mouse.(f).data.pwcDfk_l` / `vr_wcDfk_l` in memory during the load loop. They are simply never SAVED into the `.mat` cache. Confirmed by running the real entry point: after `load_sessions`, `isfield(mouse.m1.data,'pncDfk_l')` is **1**.
**So this morning's entry "Fig-4 Row-1 scripts were ALL DEAD on the current caches" is WRONG as written, and I am correcting it rather than leaving it to mislead.** Those scripts fail only in the **cache-only path** - building `mouse` by `load(...,'data')` straight from `data/*ctrl*.mat`, which is what MY drivers did all session. Run the way the project actually runs them (`load_sessions` first), they work, and `cl_factor_decomp_panel`/`trial_state_mse` were not silently skipping in normal use either.
**What survives from that entry, and still matters:**
- `utils/pre_spec_buffer.m` is still the right fix and still an improvement: it makes those five scripts work from caches alone, and the window it resolves is byte-identical (-2.000..3.000 s either buffer). It also replaces the `isfield(...,'pwcDfk_l')`-as-presence-test idiom, which genuinely does convert a schema change into silent empty output - that hazard is real whether or not it had bitten yet.
- `step_response.m` and `variance_mse.m` are NOT broken: they need `tp`/`Mean_var_*`/`dur`, which `load_sessions` computes at its lines ~361-363. Both run fine once it has.
**THE REAL BUG was a different one, and it was mine from earlier today.** `load_sessions.m:338` did `svdData.U = d_sel.svd.U` unguarded, and `utils/slim_ctrl_cache.m` removed `d.svd` this morning (28.3 GB -> 0.69 GB). So `load_sessions` **aborted at the Figure-1 SVD frame**, 25 lines before it computes `Mean_var_wc/nc` and `tp`. Everything downstream of that point silently never ran - which is exactly why `variance_mse` reported `Unrecognized function or variable 'tp'` and why I mis-read it as a bug in `variance_mse`. Now guarded: skip the one Fig-1 panel with a named warning, let the Fig-3 aggregates run.
**Why:** The slimming was mine; so was the misdiagnosis. A changelog that blames the wrong file is worse than silence.
**Next:** (a) The `d.svd` removal breaks exactly one panel, `svd_frame_AL_0039_2025-04-19.pdf` - either force a server reload of m10 to rebuild it or accept the existing PDF as final. (b) Re-check the OTHER five `_l` scripts under the `load_sessions` path before calling any of them broken. (c) `slim_ctrl_cache.m` should warn which downstream producers lose capability, since `d.svd` is not inert.


### 2026-10-02 - Regenerated the 4 final panels today's changes touched; collector confirms only 4
**Changed/Found:** Rebuilt every panel in `paper/figures_final/MANIFEST.txt` affected by today's window/statistic changes, all under PRIMARY settings, then ran `collect_final_panels`. It reported **4 copied, 34 up-to-date, 0 deleted** - an independent confirmation that exactly four final panels moved and nothing else did.
| panel | source | was | now |
|---|---|---|---|
| 2G state vs prediction | `figure2/imp_state_var_combined.pdf` | 09-30 12:31 | **10-02 12:41** |
| 4A state exemplars | `figure4/f4_state_exemplars.pdf` | 10-02 12:00 | rebuilt on `mean` |
| 4C unique R^2 | `figure4/f4_decomp_unique_sep.pdf` | 10-02 11:58 | rebuilt on `mean` |
| 4D state quartiles | `figure4/f4_row2_quartiles.pdf` | 10-02 09:44 | **10-02 12:40** |
**Two traps found while doing it, both of which would have shipped the WRONG panel:**
1. **`f4_decomp_unique_sep.pdf` on disk was written by the `sq` comparison run**, not the primary - my `f4_row1_reconcile` driver ran `mean` first and `sq` second, so the last writer won. A timestamp check alone would have called it current. **Any script that sweeps a knob must re-run the primary LAST, or export to per-config filenames.**
2. **2G was never being rebuilt at all.** `imp_state_var_combined.pdf` is gated behind `STVF_PAPER && strcmpi(STVF_UNITS,'norm')`, and both default to the non-paper values (`false`, `'sd'`). Every ordinary run of `imp_state_trialvar_fig` silently skips the one Fig-2 panel that is in the manifest, so it sat at 09-30 through all of today's Fig-2 work.
**Also noted (minor, not fixed):** `f4_row2_quartiles.m:142` sets `outview = fullfile('_preview')`, a RELATIVE path, so run from the project root it writes `brain_paper/_preview/` instead of `controller-analysis/_preview/`. There are now two `_preview` dirs with different-vintage PNGs of the same panel - which is how the PNG looked stale while the PDF was current.
**Why:** User asked for the updated final panels to review.
**Next:** (a) Give `imp_state_trialvar_fig` a paper-panel default, or a loud warning when it skips the manifest panel - a figure the manifest depends on must not be behind two opt-in flags. (b) Make `outview` absolute off the project root in `f4_row2_quartiles.m` and delete the stray `_preview/`. (c) Export a PNG beside the combined 2G PDF; it is currently the only final panel with no raster preview, which is why it had to be rasterized by hand to be reviewed.


### 2026-10-02 - AUDIT: the `_l` buffer rot reaches FIGURE 3, and a SECOND script runs on zero sessions
**Changed/Found:** Ran all five remaining `_l`-dependent scripts against the current caches instead of reasoning about them. Result, measured:
| script | status | note |
|---|---|---|
| **`step_response.m`** | **FAILS, line 42, `pncDfk_l`** | ⚠ **FIGURE 3 PAPER PANEL** |
| **`trial_state_mse.m`** | **"RAN OK" on ZERO sessions** | silent-skip, see below |
| `cl_mse_exemplars.m` | FAILS, `pwcDfk_l` | |
| `f4_delta_candidates.m` | FAILS, `pwcDfk_l` | |
| `variance_mse.m` | FAILS, `Unrecognized variable 'tp'` | a DIFFERENT bug; `_l` reads at :431-432 not even reached yet |
**`trial_state_mse.m:61` carries the exact idiom that made `cl_factor_decomp_panel.m` draw an empty panel:** `if ~isfield(data_k,'pncDfk_l') || isempty(data_k.pncDfk_l), continue; end`. Instrumented the gate directly: **0 of 15 sessions pass, so the loop body executes 0 times** and the script still exits clean. That is now **two** scripts found today that report success while processing nothing, from the same one-line pattern. The pattern is the bug, not the individual files - using a field's presence as a data-availability test converts a schema change into silent empty output.
**`step_response.m` is the serious one:** it builds a Figure-3 panel and it cannot run at all. Its slicing is also NOT the simple onset-relative form the other scripts use - `pncDfk_l(:,1:35*3)`, `(:,35*6+1:end)` - so `pre_spec_buffer` cannot be dropped in mechanically; the column scheme has to be re-derived for a 561-column, onset-351 buffer. Do NOT patch it by search-and-replace.
**Why:** The user asked what needs addressing. "Five more files have the same dependency" was a grep result, not a finding; running them turned it into one, and moved Figure 3 into scope.
**Next, in this order:** (1) **`step_response.m`** - re-derive its column scheme for the long buffer, then confirm the Fig-3 panel it exports matches the published one. (2) `grep -rn "isfield(.*Dfk_l" ` and kill the presence-test idiom everywhere; prefer `pre_spec_buffer`, which errors. (3) `variance_mse.m`'s `tp` error first, since its `_l` reads are unreachable until that is fixed. (4) `cl_mse_exemplars.m`, `f4_delta_candidates.m`. (5) Re-check whether any OTHER figure script exits clean on zero sessions - a count assertion (`assert(nPass>0)`) in each pooling loop would have caught both of today's cases.


### 2026-10-02 - Fig-4 Row 1 motion reconciled to mean(z); numerically harmless, but Fig-4C does NOT reproduce
**Changed/Found:** User: "reconcile the figure 4 row 1 error decomposition stuff on motion to take mean(z) and same window as figure 4 row 2 state dependent analysis". Both halves checked before changing anything:
- **The WINDOW already matched.** Row 1 computes `we` from each session's `params.dur`; Row 2 hardcodes `dur=3`. Verified session by session: **all 15 are dur=3 with 176 motion columns**, so both resolve to cols 1:175 = **-2.000 .. +2.971 s**. Nothing to change, and now recorded rather than assumed. (The stray `-1` that makes it +2.971 instead of +3.000 is a SEPARATE pending item, untouched here.)
- **The STATISTIC differed** and is now unified. `utils/f4_motion_stat.m` takes one or two segments, so all five Row-1 sites (`f4_error_decomp.m`, `cl_rmse_factor_windows.m`, `cl_factor_decomp_panel.m`, `f4_state_exemplars.m`, `_supp.m`) and both Row-2 sites now read the same function and the same `F4_MOT_STAT` knob. Fig 4 no longer defines motion two ways.
**The statistic change is numerically harmless to Row 1** (mode 'sep' unique R^2, 613 CL trials / 11 motion sessions, identical n both ways):
| factor | mean(z) 0-1s / 1-3s | mean(z^2) 0-1s / 1-3s |
|---|---|---|
| init-dev | 0.387 / 0.020 | 0.388 / 0.020 |
| **motion** | **0.000 / 0.000** | **0.001 / 0.000** |
| rel 2-4 Hz | 0.095 / 0.134 | 0.096 / 0.137 |
| abs delta | 0.276 / 0.441 | 0.275 / 0.444 |
Motion's unique R^2 is ~0 under either statistic, so the published "motion contributed negligibly (unique $R^2 < 0.01$)" is unaffected - if anything cleaner. The other factors move by <= 0.003 only because motion is a co-regressor.
**⚠ BUT the published Fig-4C numbers do NOT reproduce**, and this is unrelated to today's change:
| factor | `results.tex:122/153-156` | fresh run |
|---|---|---|
| init-dev | 0.29 -> 0.004 | **0.387 -> 0.020** |
| rel 2-4 Hz | 0.10 -> 0.12 | **0.095 -> 0.134** |
| abs delta | 0.23 -> 0.35 | **0.276 -> 0.441** |
| motion | < 0.01 | 0.000 (reproduced) |
**Two candidate causes are already EXCLUDED by measurement:** the motion statistic (table above, <= 0.003) and the pre-buffer switch (both buffers give byte-identical -2.000..3.000 s slices of the same `dFk`). Remaining candidates, untested: the dF/F unification applied earlier today, and whether the published panel predates the AL_0048/AL_0051 sessions. **I am not attributing it without a test.** The QUALITATIVE claim is intact and unchanged in direction - init-dev owns the transient, abs and rel delta carry the steady state, motion neither - but the three magnitudes quoted in the caption and at `:153-156` are all low.
**Why:** User instruction; the reconciliation itself, plus honest reporting of what running the scripts revealed.
**Next:** (a) Diagnose Fig-4C by checking out the panel's last-generated state and bisecting against the dF/F change - do NOT edit the caption until the cause is known, since the right fix may be regeneration rather than renumbering. (b) `f4_error_decomp.m`'s header line F2 was corrected from "mean z-motion^2" to mean z. (c) The stray `-1` in the motion window end is still open.

### 2026-10-02 - Fig-4 Row-1 scripts were ALL DEAD on the current caches; one failed SILENTLY
**Changed/Found:** Reconciling Row-1 motion required running those scripts, and none of them could. Every Fig-4 Row-1 script hardcoded `pwcDfk_l` (onset col 106), and **no cache in `data/` still carries a `_l` buffer** - checked all 15, every one has `pwcDfk`/`pncDfk` at 561 columns, onset col 351.
| script | behaviour before this fix |
|---|---|
| `f4_error_decomp.m` | error: Unrecognized field name "pwcDfk_l" |
| `cl_rmse_factor_windows.m` | error, same |
| `f4_state_exemplars.m` / `_supp.m` | error, same |
| **`cl_factor_decomp_panel.m`** | **NO error - line 69 `continue`d past every session and drew an EMPTY panel** |
The silent one is the dangerous one: `if ~isfield(dk,'wcDfk') || ~isfield(dk,'pwcDfk_l'); continue; end` turns a missing buffer into "this session has no data", so the script exits 0 and exports a figure. After the fix it pools **852 trials / 15 sessions** (613/11 for the motion model). It had been reporting nothing at all.
**Fix:** new **`utils/pre_spec_buffer.m`** resolves the buffer and returns its ONSET COLUMN, so each caller keeps its own `c0 - round(pre*Fs) : c0 + round(post*Fs)` arithmetic and the window in SECONDS is identical whichever buffer exists. **Verified identical, not assumed:** long buffer slice 281:456 = -2.000..3.000 s; a `_l` buffer would slice 36:211 = -2.000..3.000 s. It **errors** when neither buffer is present rather than skipping or clamping, so this failure mode cannot recur quietly. All five scripts now run.
**⚠ FIVE MORE SCRIPTS HAVE THE SAME DEAD DEPENDENCY and are NOT fixed here** (out of scope, needs its own pass, and two of them feed Figure 3): `step_response.m` (Fig-3 panel; slices `pncDfk_l(:,1:35*3)` etc., a different column scheme that needs care), `variance_mse.m:431-432`, `trial_state_mse.m:95-96,110-111`, `cl_mse_exemplars.m:149,164`, `f4_delta_candidates.m:24,84,89`.
**Why:** The user asked to reconcile Row-1 motion with Row 2; that cannot be verified without running the scripts, and running them exposed this.
**Next:** (a) Audit those five remaining files the same way - **check `step_response.m` first, it is a Fig-3 paper panel**. (b) Grep the repo for any other `isfield(...,'p*Dfk_l')` used as a data-presence test; that idiom converts a schema change into silent empty output. (c) Consider making `pre_spec_buffer` the only way any script reaches these buffers.


### 2026-10-02 - LEDGER AUDIT: two "published" numbers I was carrying are NOT in the manuscript
**Changed/Found:** User asked whether confirmed values are being logged correctly. Checked every number this session claims to move against the live `Closedloop_edit/results.tex` rather than against my own notes, and found **two errors in my ledger, both in the same direction - I had been treating freshly COMPUTED values as if they were PUBLISHED ones:**
1. **Fig-4 motion.** I recorded the published values as predictability `1.1e-5` and controllability `0.0098`. The manuscript says neither. `results.tex:123` and `:213` both say **predictability p = 5.1e-5, controllability p = 0.0144**. `1.1e-5`/`0.0098` were values *I computed this morning* under `mean(z^2)` after the dF/F fix - never in the paper. So "revert to mean(z) moves the published 1.1e-5" was wrong twice over: wrong baseline, and the real baseline predates both of today's changes.
2. **Fig-4 motion session count.** The stale commented block at `results.tex:212` records `n=11 (motion 7)`, i.e. the published motion result rests on **7 sessions**; the live text at `:213` says **11**. Today's run uses 11. So the published 5.1e-5/0.0144 and anything computed now are not the same analysis, and no clean old-vs-new comparison of those two p-values exists.
**What this does NOT change:** no live manuscript statement is falsified. The two bound-style claims this session touched are CONSERVATIVE and still true - `:105` "all $p < 5\times10^{-4}$" against a measured worst of 2.02e-6, and `:171` "gap at mean state $p \le 1.7\times10^{-4}$" against a measured worst of 3.73e-05. Both can be tightened; neither is incorrect. The distinction matters: a loose-but-true bound is not an erratum.
**Also measured, to finish the Fig-2G caption properly.** The caption quotes stim ratio AND matched-sham ratio for each marker, so updating only the stim side would half-break its argument. Legacy config reproduces **all six published caption numbers exactly** (0.71/0.79, 1.10/1.00, 1.99/2.10):
| marker | legacy stim / sham (published) | new [-1,0) stim / sham |
|---|---|---|
| Motion | 0.71 / 0.79 | **0.73 / 0.80** |
| Pre-var | 3.21 / 4.06 | **3.13 / 4.08** |
| Abs delta | 1.99 / 2.10 | **2.10 / 2.25** |
| Rel delta | 1.10 / 1.00 | **1.03 / 1.00** |
**The caption's three-way dissociation survives for two of three legs.** Motion still falls below its control (0.73 vs 0.80) and abs-delta's control still rises at least as steeply (2.25 vs 2.10), so "abs-delta is ongoing-amplitude, not stimulus response" holds. But **rel-delta's margin over its control collapses from 1.10-vs-1.00 to 1.03-vs-1.00** - 0.03 on a ratio whose own CI is [0.89, 1.20]. The sentence at `:70` ("Elevated relative 2--4 Hz power raised prediction error modestly ... independent of signal power") can no longer lean on the ratio; only the continuous rho/LME form (rho +0.092, p = 1.0e-04, LME 0.0045, 3/4) supports it.
**Why:** Logging integrity. A change log whose baselines are wrong is worse than none, because it manufactures confident deltas against values that were never published.
**Next:** (a) Treat `results.tex` as the ONLY source for "what the paper currently says" - never a prior session's notes. (b) Rebuild the manuscript-delta table against the .tex before any text edit. (c) Decide whether Fig-4 motion is reported on 7 or 11 sessions, and state it; the published 5.1e-5/0.0144 cannot be compared to today's numbers until that is settled. (d) Rel-delta: drop the ratio framing in both the caption and `:70`.


### 2026-10-02 - Fig-4 motion reverted to mean(z); STRENGTHENS the claim the figure is about
**Changed/Found:** Applied the user's "keep mean z for both" to Figure 4, completing the retraction of the 2026-10-01 `mean(z^2)` switch. New shared helper **`utils/f4_motion_stat.m`** is now the ONE definition; `utils/f4_row2_pool.m` takes a third arg `motstat` ('mean' default | 'sq') and `controller-analysis/f4_row2_quartiles.m` + `f4_row2_stats.m` both read one knob `F4_MOT_STAT` and pass it through. **This is the structural fix for yesterday's bug:** the panel file carries a DUPLICATED pooling block, the pool was switched to the mean square and that copy was not, so the bars binned one ordering of trials while the star above them tested another (59.2 % of trials changed quartile). The two blocks can no longer disagree about the statistic, because there is only one function.
**Control: `initdev`, `delta` and `absdelta` are BIT-IDENTICAL between the two runs** (same gap, same CI, same p to all printed digits), proving only motion moved.
**Fig-4 Row-2 motion, 1190 trials, 11 sessions:**
| quantity | mean(z^2) (yesterday's) | **mean(z) (NEW PRIMARY)** | |
|---|---|---|---|
| state slope xw = PREDICTABILITY | b=+0.159 p=**1.05e-05** | b=+0.140 p=**7.33e-04** | weaker, still clear |
| cond_CL:xw = CONTROLLABILITY | b=-0.177 p=**0.00977** | b=-0.197 p=**0.00146** | **6.7x STRONGER** |
| OL-CL gap | -0.703 p=3.74e-05 | -0.705 p=3.73e-05 | unchanged |
| per-session agreement | 10/11 | **11/11** | perfect |
**It is a genuine trade-off, and it falls on the right side.** mean(z) costs ~70x on the predictability main effect (1.1e-05 -> 7.3e-04, still p < 0.001) and buys 6.7x on the **cond x state interaction - which IS the Row-2 claim** ("the closed-loop rejection benefit is state-dependent"). It also takes per-session agreement to 11/11. Same direction as Fig 2, where mean(z^2) was the one that dropped to 3/4 sessions. So the monotone statistic is better on the claim being made, in both figures, and nothing is lost that was significant before.
**Why:** User decision 2026-10-02, "lets keep mean z for both but also run z^2 as secondary to see how things change", after I retracted the mean-square rationale as elementary-wrong (averaging an already-rectified energy's z-score is exactly monotone in trial energy; mean(z^2) is a second moment minimised AT the session mean).
**Next:** Manuscript - Fig-4 motion **predictability 1.1e-5 -> 7.3e-4** and **controllability 0.0098 -> 0.0015**, in `results.tex:173-175` and the matching caption at `:123`. ⚠ **The remaining five Fig-4 ROW-1 sites still square** (`f4_error_decomp.m:51`, `cl_rmse_factor_windows.m:77`, `cl_factor_decomp_panel.m:77`, `f4_state_exemplars.m:31`, `_supp.m:28`). Those predate 2026-10-01 - squaring is their ORIGINAL definition, not something introduced yesterday - so flipping them would move published Row-1 variance-decomposition and exemplar numbers. NOT changed; needs an explicit decision, and until it is made Fig 4 Row 1 and Row 2 define motion differently.

### 2026-10-02 - Fig-2 rel/abs delta + pre-var moved to [-1,0) too; sham moved EARLIER, not the window later
**Changed/Found:** User: "rel delta and abs delta should also use the -1 to 0 window". `imp_state_trialvar.m` gains `STV_PWR_WIN` (`'paper'` default / `'legacy'`). Every Fig-2 state marker is now measured on one window, cols 71:105 = -1.000 to -0.029 s, 35 samples.
**The sham constraint was dissolved, not overridden.** The power window could not previously reach -1.0 s because the matched sham was PINNED at -1.0 s and the state window was then pushed to start after it (2026-08-12), costing 7 of 34 samples. That dependency is now INVERTED: the state window is fixed at [-1,0) and the sham is placed to end one sample BEFORE it, at cols 64:70 = **-1.200 to -1.029 s**. The sham's actual requirement was only to sit outside the removed -0.5..0 s baseline (a sham inside it is constrained toward zero: var 8.0 inside vs 17.3 outside); it was never required to be at exactly -1.0 s. Both asserts - state/sham disjointness, and sham outside the baseline - are kept and both pass. **No samples are spent to buy the disjointness any more.**
**Second, independent reason this was the right call - SPECTRAL RESOLUTION.** `local_delta` takes a bare FFT, so df = fs/n:
| window | n | df | bins inside 2-4 Hz |
|---|---|---|---|
| legacy -0.8..-0.03 s | 26 | 1.346 Hz | **1**, at 2.69 Hz |
| new -1.00..-0.03 s | 35 | **1.000 Hz** | **3**, at exactly 2, 3, 4 Hz |
The published "2-4 Hz absolute power" was therefore **a single off-centre FFT bin** that represented neither 2 nor 4 Hz. At 35 samples the band is three bins on the integers. This is a correctness fix, not a preference.
**Results - config A (legacy/legacy/mean) again reproduces the published numbers EXACTLY**, so every difference is attributable to the windows:
| marker | legacy (published) | all [-1,0) (NEW) | direction |
|---|---|---|---|
| Motion | 0.71 [0.60-0.84] p=1.48e-07 4/4 | **0.73 [0.62-0.87] p=7.34e-07 4/4** | ~unchanged |
| Pre-var | 3.21 [2.89-3.63] p=0 4/4 | **3.13 [2.79-3.64] p=0 4/4** | ~unchanged |
| Abs delta | 1.99 [1.69-2.37] p=0 4/4, rho=+0.389 | **2.10 [1.77-2.57] p=0 4/4, rho=+0.414** | STRONGER |
| Rel delta | 1.10 [0.94-1.27] p=0.00503 3/4, rho=+0.080 | **1.03 [0.89-1.20] p=0.00451 3/4, rho=+0.092** | SPLIT - see below |
**Rel-delta splits and the manuscript must not paper over it.** Its continuous form gets STRONGER (rho +0.080 -> +0.092, p 7.8e-04 -> 1.0e-04; LME 0.00503 -> 0.00451) while its **SD RATIO collapses to 1.03 [0.89, 1.20]** - the point estimate is now essentially 1 and the CI straddles it. The CI already included 1 at 1.10, so the ratio was never a supportable claim; at 1.03 it is plainly null. **Rel-delta should be reported as a continuous/LME effect only, never as a Q4/Q1 variance ratio.**
**A pre-existing weakness this surfaced, worth logging on its own:** the MOTION sham control is nominally significant and ALWAYS WAS - rho=-0.059 **p=0.0129 in the published config**. Moving the sham off -1.0 s improves it only to p=0.0407. So a stim-free window also shows a weak motion-variance relation, i.e. part of the motion effect is not stimulus-specific. (Pre-var and abs-delta shams are overwhelming, rho=+0.52/+0.38 p=0 - that is the already-retracted power confound. Rel-delta's sham is clean, p=0.74, which is exactly why rel-delta is the admissible marker.)
**Why:** User instruction, plus the single-FFT-bin discovery above.
**Next:** (a) Manuscript: abs-delta 1.99 [1.69, 2.37] -> **2.10 [1.77, 2.57]**; rel-delta ratio claim must be dropped or restated as continuous. (b) **Report the motion sham p=0.04 honestly or drop the motion-specificity claim** - a reviewer who asks for the control will find it. (c) Methods can now state one window, [-1, 0) s, for all four markers and a sham at -1.2..-1.03 s.


### 2026-10-02 - Fig-2 motion moved to the stated [-1, 0) s window; result is robust
**Changed/Found:** Per the user, Figure 2's pre-stim motion window is now the `[-1, 0)` s the manuscript states. `impulse-analysis/imp_state_trialvar.m` gains a **decoupled motion window** `iMot = (iOn - round(1.0*fs)) : (iOn - 1)` = cols 71:105, 35 samples, plus two switches: `STV_MOT_WIN` (`'paper'` default / `'legacy'`) and `STV_MOT_STAT` (`'mean'` default / `'sq'`).
**Why motion had to be decoupled rather than sharing `iState`:** the matched sham control occupies -1.000 to -0.829 s - the first fifth of `[-1, 0)` - and `iState` was deliberately pushed to start at -0.8 s so the POWER markers (PVv/DPa/DPr) are not built from the same samples as the control they are tested against. Both of those come from `df`. Motion comes from `imp.motTrace` (FaceMap), an independent channel, so an overlap with a df-derived sham carries no circularity. A single shared window would force either motion to lose the stated `[-1,0)` or the power markers to regain the circularity the 2026-08-12 fix removed.
Also used **integer column arithmetic** rather than `tAxis >= a & tAxis <= b`, which is what silently costs `iState` 2 of its intended 28 samples.
**THE CONTROL REPRODUCES THE PAPER EXACTLY.** Running `STV_MOT_WIN='legacy'` gives ratio **0.71, CI [0.60-0.84], LME p = 1.48e-07, 4/4** against the published 0.71, [0.60, 0.84], 1.5e-7, 4/4. So the implementation is sound and every difference below is attributable to the window/statistic, not to the rerun.
| config | rho | SDratio [CI95] | LME p | sessions |
|---|---|---|---|---|
| legacy / mean (= published) | -0.122 | 0.71 [0.60-0.84] | 1.48e-07 | 4/4 |
| **paper / mean (NEW PRIMARY)** | **-0.122** | **0.73 [0.62-0.87]** | **7.34e-07** | **4/4** |
| paper / sq (secondary) | -0.129 | 0.78 [0.68-0.91] | 2.83e-07 | **3/4** |
**Conclusion: the effect is robust to the window.** Widening from 26 samples at -0.77 s to 35 samples at -1.00 s leaves rho identical (-0.122), moves the ratio 0.71 -> 0.73 and the LME p 1.5e-7 -> 7.3e-7, and keeps 4/4 sessions. The `mean(z^2)` secondary is slightly WORSE on the measure that matters for replication: it reports a weaker effect (ratio 0.78) and **drops to 3/4 sessions agreeing**, consistent with it being non-monotone in trial motion.
**Unchanged, as expected:** Rel delta 1.10 [0.94-1.27] p = 0.00503 3/4, Abs delta 1.99 [1.69-2.37], Pre-var 3.21 - only motion's window was touched.
**Why:** User instruction, after confirming that both motion sources are already rectified energies.
**Next:** Manuscript - `results.tex:70` currently reads "ratio $0.71$, 95\% CI $[0.60, 0.84]$; session-aware mixed model $p = 1.5\times10^{-7}$, 4/4 sessions"; it becomes **0.73, [0.62, 0.87], p = 7.3e-7, 4/4**. The stale commented duplicate at `:67` carries the same numbers and should be deleted rather than updated. The Methods can now honestly say motion is measured over [-1, 0) s, which it could not before. Figure 4's motion statistic still needs reverting from `mean(z^2)` to `mean(z)` under the same decision - not yet done.


### 2026-10-02 - Motion-statistic retraction CONFIRMED independently, and switching costs Fig 4 nothing
**Changed/Found:** Re-checked this morning's `mean(z^2)` retraction from the Python port, on the full 1190-trial Fig-4 motion pool rather than one session - and it holds, more clearly than the single-session version did. By decile of `mean(z)`, `mean(z^2)` is **U-shaped, not monotone**:

| decile of mean(z) | 1 (quietest) | 2 | 4 | 6 (min) | 8 | 10 (busiest) |
|---|---|---|---|---|---|---|
| mean(z) | -0.386 | -0.265 | -0.175 | -0.143 | -0.035 | +1.119 |
| mean(z^2) | **0.222** | 0.104 | 0.051 | **0.037** | 0.189 | 7.717 |

The quietest decile scores **six times** the sixth decile under `mean(z^2)`, so the statistic reads "unusually still" and "unusually active" as the same thing. Pooled Spearman rho between the two statistics is **0.219** (the m2-only estimate was 0.303). 81.2 % of z samples sit below zero, as expected for a heavy-tailed rectified energy that has been z-scored.

**And the decision turns out to be cheap.** Fig-4's Row-2 model (`y ~ cond*xw + (1+cond|sess) + (1|mouse)`, REML + Satterthwaite) under both statistics, same 1190 trials / 11 sessions / 4 mice:

| | `mean(z^2)` (published) | `mean(z)` |
|---|---|---|
| predictability (xw slope) | p 1.05e-05, beta +0.159 | p 7.3e-04, beta +0.140 |
| controllability (cond:xw) | p 0.00978, beta -0.177 | **p 0.00147**, beta -0.197 |
| OL-CL gap | p 3.75e-05 | p 3.73e-05 |
| panel-C motion unique R^2 | 0.0012 / 0.0012 | 0.0010 / 0.0042 |

**Both effects survive either way.** Predictability weakens by about an order of magnitude; controllability *strengthens* by 6.6x; the OL-CL gap does not move at all; motion stays the null factor in panel C. So no Fig-4 claim depends on the choice, and the principled statistic can be adopted without re-arguing any result.

Incidentally this **validates the port**: `mean(z^2)` reproduces `NUMBERS.md`'s published 1.1e-5 and 0.0098 as 1.05e-5 and 0.00978, to three digits, through an independent implementation of the pool and the LMM.

**Code:** the Python port now has one switch, `bpy.analysis.f4_pool.MOTION_STAT` (`"sq"` or `"mean"`), used by both `row2_pool` and `decomp_pool`, so the two can never drift apart again - which is exactly the failure mode that produced this morning's quartile-vs-star bug. Default left at `"sq"` deliberately: it matches the published MATLAB and I am not moving a published number without the user's say. `row2_fit` now also returns `slopeP`, the predictability p, which was being quoted in `NUMBERS.md` without the code reporting it.
**Why:** The retraction correctly said "user decision", but a decision with no numbers attached stalls. The useful contribution was to measure what the switch actually costs - and it costs nothing - so the choice can be made on principle instead of on fear of moving a p-value.
**Next:** Aditya's call: set `MOTION_STAT = "mean"` and change `utils/f4_row2_pool.m` + `utils/f4_error_decomp.m` to match (one line each), or keep the square and state in Methods that motion is a second moment about the session mean. My recommendation is `"mean"`. Whichever is chosen, `f4_row2_quartiles.m:85` and the pool must use the SAME one - the inline duplicate at line 85 is still a separate code path and is the standing hazard. Figure 2 (`imp_state_trialvar.m`) already uses `mean(z)` and would then need no change. Tools: `tools/motion_stat_check.py`, `tools/motion_both.py` (brain_paper_py).

### 2026-10-02 - First paper panels built end-to-end from raw camera frames, with no MATLAB cache in the chain
**Changed/Found:** Fig-3 panels A-E now export from the server's raw data alone. The representative session is m10 (AL_0039 2025-04-19 e1), whose per-pixel trace was streamed out of `widefield.wfz` and verified to 1.3e-12 relative against MATLAB's `dFk` earlier today. **Proof that nothing MATLAB-side is involved:** re-ran with `BRAIN_PAPER_ROOT` pointed at a directory that does not exist (`__no_matlab_repo__`) and all five panels still exported. Everything the panels need - Timeline, `params`, `input_params.csv`, laser channel, `timeBlue`, motion, and the frames themselves - comes off the server; the only local artifact is the ~1 MB pixel trace.

Raw-frame rebuild status at this point: **6 verified** (m3 65.3 min, m4 51.6, m5 25.4, m6, m10 25.8, m13 31.9; all 1e-12 relative or better), **1 failed** (m2, logged above), 4 streaming, 2 queued.
**Why:** This is the claim the whole port rests on - that the figures are recomputed from primary data rather than re-plotted from caches - and until now it was an architectural intention rather than a demonstrated fact. Pointing the MATLAB root at a nonexistent path is the only test that actually proves it, because a silent cache fallback looks identical to success otherwise.
**Next:** The cross-session panels (F-I) and the LMM still need all 13 mode-0 sessions, so they stay on `--source matlab` until the rebuild finishes. Figure 1's SVD frame also uses m10 but reads the 2.8 GB `U` - run it after the workers drain so it is not competing for server bandwidth.

### 2026-10-02 - RETRACTION: mean(z^2) is the WRONG motion statistic; z is already an energy
**Changed/Found:** The user asked me to confirm, before applying `mean(z^2)` to Figure 2, that `z` is a z-score and not already a squared motion energy. It is already an energy, in BOTH analyses, verified against the raw files:
- **Impulse (Fig 2):** `load_experiments.m:87` takes FaceMap's `motion_1` from `face_proc.mat`. Measured on AL_0041 2025-11-05/3: **min = 0, max = 107982, mean/median = 1.64, exactly 0.00 % of samples negative.** It is rectified. (The same file's `motSVD_1(:,1)` IS signed - min -152.7, 87 % negative - so FaceMap provides both and the code took the energy.)
- **Controller (Fig 4):** `initialize_data.m` builds `motEng(q) = sum(sum((thisFrame - lastFrame).^2))` - literally a sum of squares. Measured on AL_0033 2025-02-12/2 `motEngF.npy`: **min = 237,345, 0.00 % negative.**
**So my 2026-10-01 justification for switching to the mean square was wrong, and the error is elementary.** I argued that "a plain mean is a SIGNED deviation ... quiet trials go negative and partly cancel the bouts". There is no cancellation: averaging z over a within-trial window gives
`mean_window(z) = (mean_window(E) - mu_session) / sigma_session`
which is **exactly monotone** in that trial's mean energy. Negative values simply mean "below session average", which is the correct and desired encoding.
`mean(z^2)`, by contrast, is a second moment: it is **minimised when the trial sits AT the session mean** and therefore rises for unusually STILL trials as well as unusually active ones. Measured on m2's real trials, by decile of `mean(z)`: decile 1 (quietest, mean z = -0.211) has `mean(z^2)` = **0.045**, HIGHER than deciles 4-6 (0.023, 0.022, **0.021**). **Rank correlation between the two statistics is only 0.303** - they order trials very differently, which is also why 59.2 % of trials changed quartile when the Fig-4 panel was brought into line with the pool earlier today.
**Why this matters beyond the statistic:** the Fig-4 motion result currently published (predictability p = 1.1e-5, controllability p = 0.0098) was computed on `mean(z^2)`. If `mean(z)` is adopted, Fig 4's motion numbers must be regenerated too - this is not confined to Figure 2.
**Next:** User decision. Recommendation is `mean(z)` on the z-scored energy for both figures: monotone, standardised across sessions, and directly interpretable as "how much movement relative to this session's average". If the aim is specifically to emphasise large bouts over sustained low-level movement, the principled alternative is the mean of the RAW energy (`mean(E)`, then standardise once across trials), NOT the mean square of an already-standardised energy. Do not re-run Figure 2 until this is settled, since the choice determines the analysis.


### 2026-10-02 - Fig-2 published state window is 26 samples, not the 35 its header documents
**Changed/Found:** User asked what window the Figure-2 motion-vs-prediction LMM actually used. Traced it to `impulse-analysis/imp_state_trialvar.m:182`, `mot = mean(imp.motTrace{a}(1:n, iState), 2, 'omitnan')`, with `STV_STATE_WIN` defaulting to `'pre'` (line 60), and resolved `iState` numerically.
**The answer: columns 79:104 = -0.771 to -0.057 s, 26 samples, plain `mean(z)`.** Three discrepancies sit behind that number:
1. **The header overstates the window.** Line 43 documents "strictly PRE-ONSET [-1, 0) s for every state marker", which would be cols 71:105 = 35 samples. The delivered window is 26 samples, **74 % of what is documented**. The 2026-08-12 sham-disjointness fix shortened it - its own inline comment at line 126 says "Costs 7 of 34 state samples" - but the top-of-file WINDOWS block was never updated to match. Anything quoting the Methods from that header is quoting a window the code does not use.
2. **Two more samples are lost to floating point, not to design.** After the sham fix the intended window is cols 78:105 (28 samples, -0.800 to -0.0286 s). But `st1 = -0.80000000000000016` while `tAxis(78) = -0.80000000000000027`, and `st2 = -0.028571428571428571` while `tAxis(105) = -0.02857142857142847`; both boundary samples fail `tAxis >= stWin(1) & tAxis <= stWin(2)` by ~1e-16. So `iState` silently becomes 79:104. **2 of 28 samples, 7 % of the window, dropped by rounding.**
3. **It is `mean(z)`, not `mean(z^2)`.** The 2026-10-01 instruction was one motion-energy definition across Fig 2/3/4 using the mean square; only Fig 4 was changed, so Fig 2 still uses the signed plain mean.
**Why:** The user is planning to move Fig 2's motion window to [-2, 0]. That change is materially larger than "[-1,0) -> [-2,0]" suggests, because the starting point is 26 samples at -0.77..-0.06 s, not 35 samples at -1..0 s.
**Next:** No code changed - this is a measurement, and the window decision is the user's. When a window IS set: (a) use a tolerance or integer column arithmetic rather than bare `>=`/`<=` on a floating-point time axis, which is what `utils/trialwin` already does via `round(tspan*Fs)`; (b) update the line-43 header in the same edit; (c) decide separately whether Fig 2 adopts `mean(z^2)`. Note for whoever edits it: a [-2, 0] window would swallow all 7 sham samples (cols 71:77) and trip the line-131 assert, so motion's window has to be decoupled from the power markers' `iState`.


### 2026-10-02 - m2 (AL_0033 2025-02-12) raw frames FAIL verification, and the first failure destroyed its own evidence
**Changed/Found:** The 13-session raw-frame rebuild is running; three sessions verified to ~1e-12 relative (m4 51.6 min, m6, m13 31.9 min) and **m2 = AL_0033_0212_e2 MISMATCHED**: 53.8 min, 149458 samples (the same length as MATLAB's `dFk`, so the sample count and the `timeBlue` every-other-edge phase are right), but `max|diff| = 12.3 %dF/F`, relative 0.72 against a signal whose peak is ~17. It is the largest archive in the set (75.2 GB, 298915 stored frames). ~~and the only one with an odd frame count~~ - **that was wrong**: m10 (AL_0039_0419_e1) has 160915 frames, also odd, and VERIFIED to 1.3e-12 twenty minutes later. So an odd-length archive is handled correctly and parity is not the cause.

**I cannot yet say whether the trace is wrong or only bruised**, because the comparison reported a single max-abs number and then `build_frames.py` **deleted the cache entry** - throwing away the 1 MB trace that cost 54 minutes of server streaming. A max-abs of 12.3 is equally consistent with "wrong channel / wrong frame mapping throughout" and with "three corrupted frames in 149458", and those have completely different implications.

**Fixed the driver** (`build_frames.py`, now tracked - it was gitignored as if it were a scratch script, which it is not: it is the port's primary data path): a rejected trace is **set aside** as `<name>__rejected.pkl` instead of deleted, and the mismatch is profiled before anything is moved - count and percentage of samples beyond tolerance, RMS difference, Pearson correlation, the runs of consecutive bad samples, the worst sample's two values, and max|diff| under +-1 and +-2 sample shifts to rule out a phase error cheaply.
**Why:** Delete-on-failure is the wrong default when the artifact is expensive to regenerate and the failure is the thing you need to study. The cost asymmetry is 1 MB of disk against an hour of server reads. This also keeps the server untouched either way - nothing is written there and no archive is ever copied locally, so the only local artifact is the ~1 MB trace.
**Next:** Re-run `python build_frames.py m2` once the four workers drain (it will contend for server bandwidth otherwise) and read the profile. The two hypotheses to separate: (a) a frame-index mapping problem in this archive - `WfzReader.frame(i)` vs `frame_by_storage_index(i)` - which the shift rows will show (ruled out as a generic odd-length bug by m10); (b) a handful of individually bad frames, which the run-length row will show. Note m2 is also one of the two sessions NUMBERS.md records as never reaching setpoint, so if it stays unverifiable the cost is low - but it must be stated, not quietly dropped.

### 2026-10-02 - Fig-3 LMM: two of the four p-values come from a BOUNDARY fit; their Satterthwaite df is not identified
**Changed/Found:** Yesterday's port entry compared the Python/R fit against the **draft caption** (5.4e-9 / 2.5e-18), but `fig3_olcl_stats.m` had already been re-run on 2026-10-01 and no longer produces those numbers. Against the **current MATLAB fit** - identical data, identical formula `y ~ cond + (1+cond|sess) + (1|mouse)`, both REML + Satterthwaite - the two implementations still disagree, and by very different amounts:

| metric | port (R lme4/lmerTest) | Satterthwaite df | MATLAB `fitlme` | ratio |
|---|---|---|---|---|
| rmse_early | 1.5e-08 | **71.0** | 1.8e-07 | 12x |
| rmse_late | 1.3e-07 | 13.8 | 1.0e-06 | 8x |
| var_early | 9.7e-07 | **84.6** | 4.7e-04 | **483x** |
| var_late | 1.7e-06 | 14.0 | 4.1e-06 | 2.4x |

**The df column explains the whole pattern.** The design is the same for all four metrics - 15 sessions, 4 mice, ~1660 trials - so the session-slope df should be ~14 every time, and it is for `rmse_late` and `var_late`, the two that agree with MATLAB to within 8x. For `rmse_early` and `var_early` lmerTest instead reports **71 and 85** df, and those are exactly the two with the largest MATLAB disagreement. Refitting them with an **uncorrelated** slope (`(1|sess) + (0+cond|sess)`) returns **sessSD = 0.0000** while p is unchanged to three digits - the intercept variance has collapsed into the slope. That is a **boundary fit**: the random-slope covariance is at the edge of the parameter space, the effective df is not identified, and p becomes an artifact of which optimiser stopped where. The correlation parameter itself is irrelevant (correlated and uncorrelated forms give the same p to 3 digits); only intercept-only-vs-slope matters, and that moves p by 1e5 to 1e29.

**What is robust:** the effect size. Across all three random structures the CL-OL gap moves only in the third digit (rmse_early -0.464 to -0.491, var_late -0.485 to -0.524). Every structure and both implementations give p <= 5e-4 for all four metrics, so **no claim in Fig 3 changes** - but nothing finer than "p < 1e-4" is defensible for `rmse_early` and `var_early`.
**Why:** A 483x implementation gap on a published p-value is the kind of thing a referee reproduces and asks about, and "both are REML + Satterthwaite" is not an answer. The df diagnostic turns it from an unexplained discrepancy into a known, statable property of the model: with 15 sessions a random OL->CL slope is weakly identified for the early-window metrics.
**Next:** Decide with Aditya how the caption should read. My recommendation: quote **one significant figure** and the conservative (df ~= 14) scale for the two boundary metrics, i.e. all four as `p < 1e-4` with the gap and CI carrying the quantitative claim - the CIs are stable and are the better statistic here. If the random slope is kept, `utils/cl_olcl_lmm.m` should **report the Satterthwaite df alongside p** so a boundary fit is visible instead of silent; its `try/catch` only catches hard errors, so a boundary fit never triggers the intercept-only fallback. Probe: `scratchpad/fig3_lmm_probe.py` (brain_paper_py).

### 2026-10-02 - Fig-4C RESOLVED (2 of 3 gaps): the paper's "full model R^2" is the REL model, and init-dev was credited after rel
**Changed/Found:** Two of the three remaining panel-C discrepancies were my own reporting definitions, not data problems. Both found in the Python port (`bpy/analysis/f4_pool.py`) and both apply to the MATLAB script's intent as well.

**(1) Full-model R^2 - 0.594/0.448 vs the paper's 0.407/0.132.** The paper's number is the **three-factor REL model** (init-dev + motion + rel 2-4 Hz), not a four-predictor fit. Measured on the declared 613-CL-trial / 11-session pool:

| model | 0-1 s | 1-3 s |
|---|---|---|
| init+motion+rel (**the paper's**) | **0.414** | **0.141** |
| init+motion+abs | 0.594 | 0.448 |
| init+motion+rel+abs | 0.594 | 0.448 |
| paper-era three-factor run | 0.407 | 0.132 |

0.414/0.141 vs 0.407/0.132 - a match to <0.01. The four-predictor fit is identical to the abs model to three decimals, i.e. **once absolute delta is in, rel adds nothing**; quoting 0.594/0.448 as "the full model" silently swapped in the abs model. Added `sep_full_r2()` returning both model R^2 and made `decomp_sep` report them.

**(2) init-dev 0.388 vs the paper's 0.290.** `sep_unique` took init's and motion's share from the **rel 3-factor model** (`R2(init,mot,rel) - R2(mot,rel)`) while crediting rel and abs as increments over init+motion. That removes rel from init *and* init from rel - not a decomposition, and asymmetric. Credited hierarchically instead (base pair against each other, then each delta over the base):

| factor | before | after | paper |
|---|---|---|---|
| init-dev | 0.388 / 0.020 | **0.318 / 0.003** | 0.290 / 0.004 |
| motion | 0.001 / 0.000 | 0.001 / 0.001 | <0.01 |
| rel 2-4 Hz | 0.096 / 0.137 | 0.096 / 0.137 (unchanged) | 0.100 / 0.120 |
| abs delta | 0.275 / 0.444 | 0.275 / 0.444 (unchanged) | 0.230 / 0.350 |

The settled window now matches exactly (0.003 vs 0.004) and early is within 0.028. The old behaviour is kept behind `sep_unique(..., legacy_base=True)` and pinned by a test, so the drift cannot return unnoticed.

**Where that leaves panel C:** every manuscript number now reproduces within rounding **except absolute delta**, which lands on 0.240/0.383 (vs 0.230/0.350) only on the 2-4 Hz band `NUMBERS.md` documents - the open band question logged earlier today. Also checked and rejected: the published "397 CL trials / 7 sessions" is **not** a subset of today's 613/11 pool - only two 7-session subsets sum to 397 and both require m14/m15, which did not exist when the panel was made. It is an older pool, not an inclusion rule.
**Why:** The full-model R^2 was 46%/240% above the paper and init-dev 34% above, which looked like a data or pool problem for two weeks. It was arithmetic bookkeeping in the decomposition - exactly the class of bug that survives review because every individual number is plausible.
**Next:** Settle the abs-delta band (1-4 vs 2-4 Hz) with Aditya, then `f4_error_decomp.m` needs the same two corrections before it is re-run: report the rel-model R^2 as the full model, and credit init/motion over the base pair rather than over the rel model. Its line 55 (`dk.pwcDfk_l`, no fallback) still blocks execution. New tests: `tests/test_fig4_pool.py::test_decomp_matches_manuscript_panel_c` and `::test_sep_decomposition_credits_the_base_pair_before_the_deltas`.

### 2026-10-02 - Fig-4C abs-delta band: code uses 1-4 Hz, NUMBERS.md documents 2-4 Hz, and 2-4 Hz is closer to the paper
**Changed/Found:** Chasing the residual Fig-4C gap (unique R^2 for abs-delta came out 0.275 / 0.444 against the paper's 0.230 / 0.350), I found the absolute-power band is **not** the band the manuscript documents. `f4_error_decomp.m` builds `absdelta` as `log10(bandpow(1,4))`, while `NUMBERS.md` describes the marker as "absolute 2-4 Hz". Re-running the decomposition with the documented band, everything else held fixed:

| marker | code band (1-4 Hz) | documented band (2-4 Hz) | paper |
|---|---|---|---|
| init dev | 0.388 / 0.020 | 0.388 / 0.020 | 0.290 / 0.004 |
| rel delta | 0.096 / 0.137 | 0.096 / 0.137 | 0.100 / 0.120 |
| **abs delta** | **0.275 / 0.444** | **0.240 / 0.383** | **0.230 / 0.350** |
| full-model R^2 | 0.594 / 0.448 | 0.565 / 0.406 | 0.407 / 0.132 |

(each cell = 0-1 s window / 1-3 s window.)

The documented band moves abs-delta from +0.045/+0.094 off the paper to +0.010/+0.033 - i.e. inside the rounding the paper reports. So the likely history is that the panel was generated on 2-4 Hz, the label in NUMBERS.md is right, and the lower edge in the script drifted to 1 Hz afterwards. The rel-delta marker already uses 2-4 Hz (`rel_delta` numerator), so 2-4 Hz is also the self-consistent choice within the figure.
**Why:** This is the only one of the three markers whose band disagrees between code and documentation, and it is also the marker with the largest paper-vs-port gap - the two facts are almost certainly the same fact. Worth settling before the panel is re-exported, because the number is quoted in the Results text.
**Next:** Do **not** silently change `f4_error_decomp.m` - ask Aditya which band the panel should ship with (1-4 Hz as coded, or 2-4 Hz as documented). Note that even on 2-4 Hz the **init-dev** marker (0.388 vs 0.290) and the **full-model R^2** (0.565/0.406 vs 0.407/0.132) remain off, so the band is not the whole story; those two are still open and are tracked separately. Also fix `f4_error_decomp.m:55` before any MATLAB re-run (it currently cannot execute).

### 2026-10-02 - BUG I INTRODUCED: Fig-4 motion panel binned on plain mean while its star tested the mean square
**Changed/Found:** `controller-analysis/f4_row2_quartiles.m` has **two** pooling paths. Line 62 calls the shared `f4_row2_pool` + `f4_row2_fit`, which produce the **star** printed on the panel. Line 85 is a **duplicated inline copy** of the same pooling block that builds `S.motion`, consumed at line 100 to compute the **quartile bins and the bars**.
On 2026-10-01 I switched motion to `mean(z^2)` per the user's instruction - **but only in `f4_row2_pool.m`**. The inline copy at line 85 kept `mean(z)` under a comment reading "PLAIN mean (unified w/ f4_row2_pool)", which the edit silently made false. From that point the motion panel **binned trials by plain-mean motion while the star above it came from squared motion**.
**This was not cosmetic.** Measured over the 1190 motion trials: **59.2 % of trials fall in a different quartile** under the two definitions, and the per-session correlation between them is median 0.889 but as low as **0.465**. Bars and p-value were describing materially different orderings of the same trials.
**Fixed** line 85 to `mean(...^2,2)` and corrected the header line that documented the state as a plain mean. Regenerated all four Row-2 panels.
**Effect of the fix:** the **star is unchanged** (p = 0.00978) because it never came from the broken path. The **bars changed** - the OL-CL gap across quartiles now reads ~0.62 / 0.38 / 0.78 / 0.98 instead of ~0.70 / 0.37 / 0.63 / 1.04 - and the panel's own companion tests moved with it: per-session signed-rank **0.000977 -> 0.042**, pooled **0.000217 -> 0.00219**. Both remain significant and the conclusion is unchanged; the panel now shows what its star tested.
**Why:** Found while answering the user's question about what time window motion uses. The lesson is the duplication, not the typo: `f4_row2_pool.m` and `f4_row2_quartiles.m` carry near-identical pooling blocks, and both headers claim they are unified, so an edit to one is invisible in the other.
**Next:** Delete the inline block at `f4_row2_quartiles.m:80-95` entirely and have it bin from the `POOLs` struct it already loads at line 62, so the duplication cannot recur. That is a behaviour-preserving refactor now that the two definitions agree - do it as its own verified step.

### 2026-10-02 - Catalogue: motion is windowed FOUR different ways across controller analysis
**Changed/Found:** Swept every site that windows `ncmotion`/`wcmotion`. The array itself is fixed: `controllerData.m:120` slices `mv(i-70 : i+35*dur)`, giving 176 columns at dur = 3 with **onset at column 71**, spanning **-2.000 to +3.000 s**. What the consumers take from it is not fixed:
| window | seconds | cols | used by |
|---|---|---|---|
| **A (Fig-4 primary)** | **-2.000 to +2.971** (175 smp) | 1:175 | `f4_row2_pool`, `f4_row2_quartiles`, `f4_error_decomp`, `cl_rmse_factor_windows`, `f4_partB_panels`, `f4_devmodel_supp`, `f4_state_exemplars`(+`_supp`), `cl_mse_exemplars`, `cl_mse_factors`, `cl_factor_decomp_panel`, `_preview/panelC_repro` |
| B | -2.000 to +3.000 (176 smp) | 1:176 | `trial_state_mse` |
| C | -2.000 to **0.000** (pre-onset only) | 1:71 | `ctrl_distrej_quartiles`, `ctrl_distrej_statedep` |
| D | **0.000** to +3.000 (during only) | 71:176 | `motion_mse_significance` |
| E | configurable | 3 modes | `motion_analysis` (`pre_secs` = 2, 3, 0) |
Group A is one sample short of the trial end because of the `-1` in `we = min(end, c0_mot + round(dur*Fs) - 1)`; group B omits that `-1`. So the two "same" -2 s to trial-end windows differ by 28.6 ms, mirroring the one-sample Fig-3/Fig-4 disagreement logged earlier today.
**Three aggregations are layered on top of these four windows:** `mean(z^2)` (energy - Fig-4 primary), `mean(max(z,0))` (rectified - `f4_partB_panels:94`, `f4_devmodel_supp:45`), and plain `mean(z)` (`trial_state_mse`, `ctrl_distrej_*`, `motion_mse_significance`, `motion_analysis`).
**A latent silent-clamp:** `motion_analysis.m` mode 2 requests `pre_secs = 3`, but the array only holds 2 s of lead-in, so `max(1, onset_col - 105)` quietly returns a 2 s baseline and reports it as 3 s. Nothing errors. This is exactly the idiom `utils/trialwin` refuses.
**Good news on onsets:** `trial_state_mse`, `motion_mse_significance` and `ctrl_distrej_*` all derive the onset as `size(ncmotion,2) - 35*dur` rather than hardcoding 71 - self-describing and correct for any `dur`. The Fig-4 group uses the literal `c0_mot = 71`.
**Why:** User asked what the motion time window is in controller analysis. There is no single answer, which is itself the finding.
**Next:** Decide ONE canonical definition for the paper's motion state (recommend group A's window and `mean(z^2)`, since that is what Fig 4 publishes) and state it in the Methods; migrate the Fig-4 group onto `trialwin('motion', [-2 3], dur)` so the onset stops being a literal. Groups C and D are legitimately different measurements (pre-stimulus vs during-stimulus) and should be NAMED differently rather than unified.


### 2026-10-02 - Fig-4C RESOLVED: panel runs again, and the paper's rel-2-4 Hz unique R2 is CORRECT
**Changed/Found:** `f4_error_decomp.m` has been unrunnable since `controllerData.m` stopped writing the `_l` buffers (it indexes `dk.pwcDfk_l` at line 55, admits 0 of 15 sessions - RESEARCH 2026-09-21). The Python port builds `p*Dfk_l` for every session in `ControllerSession._finish`, so panel C runs: 613 CL trials / 11 motion sessions (the declared pool), unique R2 (0-1 s / 1-3 s) init-dev **0.388/0.020**, motion **0.001/0.000**, rel 2-4 Hz **0.096/0.137**, abs delta **0.275/0.444**. Two sub-results. (1) Computing the state from `pwcDfk_l` at onset col 106 and from `pwcDfk` at onset col 351 gives **bit-identical** unique R2 - the documented window equivalence (legacy cols 36-211 == current 281-456) is confirmed, so the fallback is exact and the `_l` buffers never needed to be rebuilt. (2) The 2026-09-21 reconstruction's alarming "rel 2-4 Hz ~10x lower than the paper" (0.011/0.012 vs 0.10/0.12) does NOT reproduce: the correct computation gives 0.096/0.137, i.e. **the paper's 0.10/0.12 is right**. Indexing `pwcDfk` with the OLD onset column (106 instead of 351) - a window ~9 s before onset - moves the numbers toward that reconstruction (init 0.300/0.001, rel 0.045/0.075, abs 0.120/0.271), so the shortfall was most likely a windowing error in the reconstruction, not a problem with the figure.
**Why:** This closes the biggest open Fig-4 worry. The rel-delta unique R2 was the one number RESEARCH flagged as a ~10x discrepancy against the manuscript, and it is the manuscript that is correct. Residual gaps remain on init-dev (0.388 vs 0.290) and abs delta (0.275/0.444 vs 0.230/0.350), both HIGHER here, so the paper is conservative on those.
**Next:** Fix `f4_error_decomp.m:55` to prefer `pwcDfk_l` and fall back to `pwcDfk` at col 351 (the equivalence is now verified both ways), then re-run it in MATLAB and reconcile the residual init-dev / abs-delta gap. Remove the "rel 2-4 Hz is 10x off" item from the Fig-4 worry list.

### 2026-10-02 - Fig-4D shows one motion definition and stars another
**Changed/Found:** `f4_row2_quartiles.m:88` builds its DISPLAYED motion state as `mean(d.ncmotion(:,ws:we),2)` - a plain mean - with the comment "PLAIN mean (unified w/ f4_row2_pool)". But `utils/f4_row2_pool.m:44`, which supplies the panel's significance star via `f4_row2_fit`, uses `mean(...^2,2)` - the mean SQUARE (changed 2026-10-01). So the bars/quartile bins a reader sees and the p-value printed above them come from two different state definitions, and the "unified" comment is false. Ported faithfully in `brain_paper_py/bpy/figures/fig4.py` (display = plain mean, star = pool) so the panel reproduces, with the divergence documented in the code.
**Why:** The panel's claim is about how the OL-CL gap changes across the state axis. If the axis is built one way and tested another, the quartile bin edges do not correspond to the tested predictor - trials can sit in a different quartile under the two definitions. Low risk for the reported direction (both are monotone in movement) but it is not defensible as written.
**Next:** Pick ONE definition (mean square is the 2026-10-01 decision and matches `f4_error_decomp.m`) and use it in both places; delete the stale comment; re-export 4D.

### 2026-10-02 - Migration 1/8: fig3_olcl_stats off hardcoded columns, bit-identical
**Changed/Found:** First call-site migration of the restructure. `controller-analysis/fig3_olcl_stats.m` carried `c0 = 36; c1 = 71; c2 = 141` at line 28 and passed raw `(a,b)` bounds into its `re`/`vc`/`putvar` helpers. It now derives `dur` from the array width (`dfk` is `35*(dur+2)+1` columns, so this doubles as an assertion that the cache has the shape `trialwin` assumes) and resolves all three windows through `utils/trialwin`.
**Verified bit-identical:** re-ran against the values computed immediately before the edit - worst |dp| = **0.000e+00**, worst |dgap| = **0.000e+00**, worst |d signrank| = **0.000e+00** across all six metrics. `trialwin` returns exactly the old literals: full 36:141, early 36:71, late 72:141.
**The one subtlety that made this worth doing carefully:** `rmse_late` used `c1+1`, i.e. column 72, deliberately excluding the +1 s sample so that the early and late windows do not share it. A naive `trialwin('dfk',[1 3],dur)` returns 71:141 and would have silently shifted the window by one sample. The migration keeps the exclusion explicit (`iLate(1) = []`) with a comment saying why, rather than letting the next reader "simplify" it back.
**Why:** User chose one-file-at-a-time with verification at each step. This is the pattern for the remaining seven.
**Next:** `f4_row2_pool.m:22` is next and is the most delicate, because it is the file that holds `c0_mot = 71` - the motion onset - alongside `c0 = 36`, the two that are one second apart on arrays of identical width.

### 2026-10-02 - Fig-3 and Fig-4 disagree by one sample about the "settled [+1,+3] s" window
**Changed/Found:** Found while preparing migration 2. Both figures describe their steady-state outcome as the 1-3 s window, but they do not use the same columns:
- `fig3_olcl_stats` `rmse_late` = columns **72:141** = 70 samples = 1.0286 to 3.0000 s (it excludes the +1 s sample so early and late do not overlap).
- `f4_row2_pool` `yOL`/`yCL` = columns **71:141** = 71 samples = 1.0000 to 3.0000 s (it includes it).
A 28.6 ms / 1.4 % difference in window length between two figures' "same" measurement. Numerically trivial - it will not move any conclusion - but it is a genuine one-quantity-two-definitions case, and the Methods describes a single 1-3 s settled window for both.
**Why:** Exactly the class of defect the one-file-at-a-time migration is meant to surface: the literals hid it, because 71 and 72 look equally arbitrary until the windows are expressed in seconds.
**Next:** Decide which is canonical and make both use it. Preference is the EXCLUSIVE form (72:141) wherever early and late windows are both reported from the same trace, since overlapping windows share variance; but Fig 4 reports only the settled window, so the inclusive form is defensible there. Either way, state ONE convention in the Methods. Do not change Fig-4's window silently - it would move the published Fig-4 numbers that were only just regenerated.


### 2026-10-02 - Measured where cache space actually goes: it is NOT the duplicated trial arrays
**Changed/Found:** Before restructuring anything for "space", measured a controller cache properly. The duplication everyone (including me) assumed was the problem is **0.004 %** of the file:
| component | size | share |
|---|---|---|
| `d.svd` | 2950 MB | **92 %** |
| rest of `d` (ten 25 MB laser/time vectors) | 251 MB | 7.8 % |
| `data` -- **every** per-trial array | 6.6 MB | 0.2 % |
| the duplicated dFk views (`ncDfk`,`wcDfk`) | 0.14 MB | **0.004 %** |
`d.svd.U` alone is 560x560x2000 single = 2.5 GB. **So collapsing the trial arrays is worth doing for CORRECTNESS, not for space** - and widening motion onto the shared -10..+6 grid actually makes it slightly bigger (176 -> 561 columns, +0.19 MB/session).
Also corrected an earlier assumption of mine: **`pncDfk_l` is not stored in the cache at all.** `load_sessions.m:305` constructs it at load time, so there are three persisted views of dFk, not four.
**Why:** The user asked whether the restructure was deduplicating arrays to save space. It would not have; claiming otherwise would have been a wrong justification for the right change.
**Next:** Keep the trial-struct migration on its real footing (one onset, one grid, queryable in seconds). Space is a separate job, below.

### 2026-10-02 - Slimmed the controller caches: 28.3 GB -> 0.69 GB, Fig-3 bit-identical
**Changed/Found:** Added `utils/slim_ctrl_cache.m` and ran it over all fifteen controller caches. It drops `d.svd` (re-readable from the server in ~20 s/session) and `d.lightRaw594`/`d.lightRaw638` (**verified zero consumers** outside `loadData.m`). **Result: 28.3 GB -> 0.69 GB, 27.6 GB reclaimed**, per-session 3540 -> 82 MB, 2979 -> 41 MB, 2809 -> 50 MB and so on.
**Deliberately KEPT** `d.inpVals` / `d.inpTime` / `d.lightRaw` even though each is a literal copy of a per-wavelength array, because they carry 61 / 59 / 4 call sites between them; 75 MB/session is not worth that blast radius next to the 2950 MB above.
**Safety argument, which was checked rather than assumed:** six of the fifteen caches **never had an SVD** (12-46 MB on disk) and both Fig-3 and Fig-4 already ran across all fifteen, so the no-SVD path was the norm for 40 % of sessions. The one consumer, `controller-analysis/contra_prediction_controller.m:74`, already detects the absence and reloads via `initialize_data`.
**The write is write-verify-then-rename:** each cache is rewritten to a temp, the temp is RELOADED and compared field-by-field against the in-memory `data` and every retained field of `d`, and only then does the original get replaced. **Proof it was lossless: re-running `fig3_olcl_stats` against the slimmed caches reproduced the pre-slim values to EXACTLY 0.000e+00 on all six metrics' p-values and gaps.**
**Dead end worth recording:** the first attempt named the temp `<file>.mat.slim.tmp` and `load` refused it - `save` writes MAT format regardless of extension, but `load` guesses the format FROM the extension. The failure was harmless precisely because of the ordering (the original is untouched until verification passes); the temp is now `<file>.slim.mat`.
**Why:** User approved "slim all 9, write-verify-replace" once shown that the SVD, not the trial arrays, is 92 % of the cache.
**Next:** `contra_prediction_controller` will now re-download the SVD on first use for the nine slimmed sessions (~20 s each, one time per run). If that becomes annoying, the fix is a sidecar `data/<session>_svd.mat` rather than putting it back in the controller cache.


### 2026-10-02 - Fig-4 Row-2 pool reproduces EXACTLY, but the rel-delta decoupling p crosses 0.05
**Changed/Found:** Ported `utils/f4_row2_pool.m` + `utils/cl_reldelta.m` + `utils/f4_row2_fit.m` (`brain_paper_py/bpy/analysis/f4_pool.py`) and ran them on the same MATLAB caches. The POOL is an exact reproduction: initdev/delta/absdelta 1670 trials (852 CL) / 15 sessions / 4 mice, motion 1190 (613 CL) / 11 sessions - identical to the 2026-09-16 and 2026-10-01 audits. The MODEL (`y ~ cond*xw + (1+cond|sess) + (1|mouse)`, REML + Satterthwaite via lme4/lmerTest, random slope converged for all four) gives cond x state decoupling p: initdev 0.743 (paper 0.394), motion 0.0098 (paper 0.0042), **rel 2-4 Hz 0.074 (paper 0.0182)**, absdelta 0.15 (paper 0.876). OL-CL gap p 1.4e-07 / 3.7e-05 / 8.7e-08 / 2.8e-08 (paper claims <= 1.6e-11 for all four).
**Why:** Three of the four decoupling terms keep their conclusion (two n.s., motion significant). **Relative 2-4 Hz does not**: 0.0182 is a significant decoupling claim, 0.074 is not. The paper's rel-delta numbers may predate the 2026-09-11 canonical band change (2-4 / 0.4-10 Hz) or the 2026-10-01 switch of the motion state to mean-square, both of which post-date the recorded run. Also: NUMBERS.md's table calls the fourth state "absolute 2-4 Hz" but `f4_row2_pool.m` builds it from `comp.delta` = **1-4 Hz** absolute power.
**Next:** Re-run `f4_row2_stats.m` in MATLAB on the current code and re-record all eight p-values in NUMBERS.md; until then do not quote the rel-delta decoupling as significant. Fix the "absolute 2-4 Hz" label to 1-4 Hz.

### 2026-10-02 - Fig-3 LMM: the draft caption's p-values match NEITHER random structure
**Changed/Found:** Installed R 4.6.1 + lme4 2.0.6 + lmerTest 3.2.1 and ran the Fig-3 stats through real REML + Satterthwaite (`brain_paper_py`, port of `controller-analysis/fig3_olcl_stats.m`, same MATLAB caches, same metrics). On the stated model `y ~ cond + (1+cond|sess) + (1|mouse)` the random slope DOES fit (not singular, df 14-85), and the p-values are: rmse_early 1.5e-08, rmse_late 1.3e-07, var_early 9.7e-07, var_late 1.7e-06. The draft caption (NUMBERS.md 3.x) says 5.4e-9 / 2.5e-18 (RMSE 0-1 s / 1-3 s) and 2e-7 / 5.6e-14 (variance). Refitting intercept-only (`+ (1|sess) + (1|mouse)`, the `catch` branch of `utils/cl_olcl_lmm.m`) gives 9.2e-13 / 3.0e-36 / 6.8e-09 / 9.1e-26 - so the caption sits BETWEEN the two models and is reproduced by neither. The early-window numbers are within ~3x of the random-slope fit; the late-window ones are off by 1e11.
**Why:** 2.5e-18 on 15 sessions / 4 mice is the signature of trials treated as independent - the exact pseudoreplication objection Nick raised for Fig 4. If the honest number is ~1e-7 the claim is unchanged (still highly significant) but the caption is overstated by eleven orders of magnitude, and a referee who refits will see it.
**Next:** Run `fig3_olcl_stats.m` once in MATLAB and record what its `fitlme` actually returns for the four windows (whether the random slope converged, and the DFMethod). Then correct NUMBERS.md 3.x and the caption from that run. Do NOT quote the Python numbers in the paper until MATLAB's own output is on record.

### 2026-10-02 - Mode-0 raw camera frames are rebuildable again: widefield.wfz streams from the server
**Changed/Found:** The 13 original controller sessions' dF/F needs raw frames, which no longer exist as frame files anywhere - only as each experiment's lossless `widefield.wfz` (JPEG-LS, 11.6-75.6 GB per session, 568 GB total). Readable with the lab's own `wfcompress` (SteinmetzLab/widefieldCompress @ f73774a), now installed in `brain_paper_py/.venv`. Frames are streamed and CRC-verified in place; the archive is never copied locally and nothing is extracted. m6 (AL_0033 2025-03-05 e2) rebuilt end to end and its dF/F matches the MATLAB `AL_0033pixel03052.mat` cache to **max|diff| 5.9e-12 (rel 5e-13)**, which validates the frame decode, the row/col orientation, the pixel, the kernel and the rolling baseline in one check. Measured throughput 70 frame-reads/s, and it is SERVER-BOUND: four parallel workers give the same 68 reads/s total as one, so the full 13-session rebuild is ~5 h however it is split.
**Why:** Without this the port could only verify the steps downstream of dF/F for 13 of 15 sessions, and the mode-0 definition could never be re-derived from the data on any machine.
**Next:** Build the remaining 12 (running) and confirm all 13 verify against their pixel caches; then run Fig 3 fully from raw. Note `AL_0033pixel*.mat` caches store `dFk` only (no `F`), so the raw trace itself has no MATLAB oracle - the dF/F comparison is the check.

### 2026-10-02 - Server access is now enforced read-only in code, not by convention
**Changed/Found:** `brain_paper_py/bpy/core/paths.py` gained `writable(path)`, which raises `ServerIsReadOnly` for any path inside the lab server tree (and its parent share, so a stray `..` cannot escape). Every write in the package routes through it: the local pixel/session caches, figure export (`paper_export`), and the Fig-3 stats JSON. Verified it blocks the Subjects root, a subject folder and the parent `\data` share.
**Why:** The port now reads 568 GB of primary data off the server; a single mistaken write (an extracted frame folder, a cache file, a repacked archive) would land in someone else's raw-data tree. Convention is not enough when the write sites are this spread out.
**Next:** none.

### 2026-10-02 - Fig-4 panels regenerated; the delta "trend" is non-monotonic in BOTH versions
**Changed/Found:** Re-ran `f4_row2_quartiles` on the corrected data (panels f4_2A/2B/2C/2D + the stitched `f4_row2_quartiles`, to `paper/images/figure4` and `_preview`). The Rel 2-4 Hz panel now prints "P n.s. / C n.s."; Motion keeps its ** star. Built a decision figure, `paper/images/figure4/delta_controllability_old_vs_new.png`, putting the old and corrected quartile curves side by side with all 15 per-session gap traces.
**The important observation is not the p-value, it is the shape.** The OL-CL gap across Rel 2-4 Hz quartiles is:
- OLD dF/F: 0.886, 0.658, 0.823, 0.600
- CORRECTED: 0.877, 0.694, 0.910, 0.682
**Both are non-monotonic** - Q2 dips, Q3 rises back above Q1-level, Q4 falls. There is no clean decline in either version; the model was fitting a linear interaction through a bumpy pattern, and the per-session traces span roughly -0.5 to +1.8 at every quartile. Net Q1->Q4 change is only -0.29 (old) and -0.20 (corrected). So the claim was **marginal and fragile before the correction**, not a solid effect that the correction destroyed: p = 0.0141 was already a weak linear fit over a non-monotonic pattern with large between-session spread, and a two-session change was enough to move it to 0.074.
All three tests now agree it is not significant: LMM p = 0.0742, per-session signed-rank p = 0.107, pooled p = 0.0732.
**Why:** The user declined to re-word the manuscript without seeing the figure and the trend first, which was the right call - the shape is more informative than the p-value and changes how the claim should be framed.
**Next:** User decision on wording, deferred to them. Note for whatever they choose: Fig-4B/C unique-variance is independent evidence for the same conclusion (relative power carries the steady-state window, unique R^2 0.10 -> 0.12, where initial deviation collapses 0.29 -> 0.004), and does not depend on this interaction at all.

### 2026-10-02 - Stale header in f4_row2_quartiles describes a model it does not use
**Changed/Found:** `controller-analysis/f4_row2_quartiles.m` documents its panel star as coming from `zrmse ~ cond*state + (1|mouse) + (1|sess)` - z-scored outcome, random INTERCEPTS only. `f4_row2_stats.m` documents the opposite, that the star comes from the shared `f4_row2_fit` (`y ~ cond*xw + (1+cond|sess) + (1|mouse)`, raw outcome, random SLOPES). Running it settles it: the printed stars are 0.743 / 0.00978 / 0.0742 / 0.15, identical to `f4_row2_fit`, and the script's own footer prints "ROW 2 LME (session-aware, SHARED with f4_2S_stats)". **So the shared model is what runs and the quartiles header is stale documentation**, describing a superseded test.
**Why:** Checked deliberately, because two headers describing different models for the same star is exactly the "one quantity, two paths" risk the code review is meant to catch. It turned out to be a documentation defect rather than a numerical one.
**Next:** Delete the stale model description from the `f4_row2_quartiles.m` header (lines ~22-27) so it does not mislead the next reader into believing the panel star and the forest come from different models. No behaviour change.


### 2026-10-02 - Fig-3 re-run on corrected dF/F: every p-value STRONGER, nothing reversed
**Changed/Found:** MATLAB was restarted overnight (clearing the workspace) and the licence is healthy again, so the blocked statistics could finally be regenerated. Re-ran `controller-analysis/fig3_olcl_stats` over all 15 controller caches (it globs `data/*ctrl*.mat`, so it picked up the rebuilt m14/m15 automatically; confirmed exactly 15 files, the two new ones dated 2026-10-01).
| metric | p OLD | p NEW | gap OLD -> NEW |
|---|---|---|---|
| rmse_full | 5.79e-07 | **3.97e-08** | -0.612 -> -0.633 |
| rmse_early | 1.80e-07 | **1.51e-08** | -0.442 -> -0.464 |
| rmse_late | 1.03e-06 | **1.25e-07** | -0.722 -> -0.746 |
| var_stim | 4.44e-06 | **2.02e-06** | -0.426 -> -0.435 |
| var_early | 4.67e-04 | **9.74e-07** | -0.268 -> -0.275 |
| var_late | 4.06e-06 | **1.71e-06** | -0.511 -> -0.524 |
**Every p-value fell and every gap widened in magnitude. No sign flips, no significance changes.** `var_early` improved ~480x. n = 1670 trials / 15 sessions / 4 mice unchanged, random slope converged for all six metrics as before. Signed-rank companions also held or improved (worst 4.3e-4).
**Manuscript consequence:** the largest Fig-3 p is now **2.02e-6**, so `results.tex:105` "all $p < 5\times10^{-4}$" is true but now very loose - it can be tightened to "all $p < 3\times10^{-6}$".
**Why:** The m14/m15 dF/F correction changed two of fifteen sessions, so every pooled statistic had to be regenerated before the numbers could be quoted.
**Next:** `data/fig3_olcl_lmm.mat` is rewritten, so `variance_mse.m` stars and `pooled_new_mice.m` titles will annotate from the new values automatically on next run. Panels still need regenerating.

### 2026-10-02 - Fig-4 re-run: three of four claims strengthen, but the relative-2-4-Hz controllability claim LOSES significance
**Changed/Found:** Re-ran the Fig-4 Row-2 LMMs (`f4_row2_pool` + `f4_row2_fit`, `y ~ cond*xw + (1+cond|sess) + (1|mouse)`) on the corrected data. Mapping to the manuscript's vocabulary: `cond_CL` = OL-CL gap at mean state, `xw` = *predictability*, `cond_CL:xw` = *controllability*.
| state | gap p OLD -> NEW | predictability p OLD -> NEW | controllability p OLD -> NEW |
|---|---|---|---|
| initdev | 1.03e-06 -> **1.44e-07** | 8.87e-14 -> **2.07e-10** | 0.558 -> 0.743 (n.s. both) |
| motion | 1.65e-04 -> **3.74e-05** | 5.12e-05 -> **1.05e-05** | 0.0144 -> **0.0098** |
| delta (rel 2-4 Hz) | 7.61e-07 -> **8.69e-08** | 0.946 -> 0.403 (n.s. both) | **0.0141 -> 0.0742** |
| absdelta | 2.26e-07 -> **2.82e-08** | 1.87e-27 -> **3.09e-33** | 0.387 -> 0.150 (n.s. both) |
**The one regression: relative 2-4 Hz controllability, beta +0.1446 CI [+0.029,+0.260] p=0.0141 -> beta +0.0994 CI [-0.0097,+0.2085] p=0.0742.** The CI now includes zero. Direction is unchanged (positive interaction = the OL-CL gap narrows as relative delta rises = controllability falls), but it is a trend, not a significant effect.
**THE CAUSE IS PROVEN, not assumed.** Ran a control that rebuilt m14/m15's trial arrays from the OLD mode-1 dF/F in the backed-up pixel caches and re-fitted: it reproduced the archived values to 3-4 significant figures (gap 1.026e-6 / 1.645e-4 / 7.605e-7 / 2.263e-7 vs archived 1.03e-6 / 1.65e-4 / 7.61e-7 / 2.26e-7; controllability 0.5582 / 0.01439 / 0.01407 / 0.3869 vs 0.558 / 0.0144 / 0.0141 / 0.387; and the paper's quoted motion predictability 5.1e-5 exactly). It also reproduced the old per-session RMSE for both sessions. So the shift is attributable **solely to the dF/F correction**, not to the lean `mouse` reconstruction used for the re-run.
**Manuscript consequence - this one needs a decision, not just a number swap.** `results.tex:183` and the duplicate at `:213` assert "controllability fell ($p = 0.0141$), identifying the ongoing low-frequency fluctuation as **the one disturbance feedback cannot fully cancel**", and the Fig-4 caption at `:123` carries "Relative 2--4\,Hz: predictability unchanged, controllability$\downarrow$ ($p=0.0141$)". At p = 0.074 that sentence can no longer stand as written. The closing internal-model sentence ("steerable for the unanticipated motor disturbance but limited for the ongoing low-frequency brain state") leans on it too. Note the *motion* controllability claim - the positive half of the internal-model argument - **strengthened** to p = 0.0098, so the narrative survives on motion; it is the "delta is the uncancellable disturbance" half that becomes a trend.
Also: the stale LaTeX comment at `results.tex:212` records an even older run (init 0.394, abs 0.876) that matches neither the archived .mat nor the new fit; it should be deleted rather than updated.
**Why:** Completing the dF/F correction honestly means reporting the sub-claim it weakens, not only the five it strengthens.
**Next:** User decision on wording - soften to an explicit trend with the CI, or drop the claim and rest the low-frequency argument on Fig-4B/C unique-variance instead. Either way the three numbers at `:123`, `:183`, `:213` must change, plus the Fig-3 bound at `:105`. **Do not quote 0.0141 anywhere again.**


### 2026-10-02 - TF order selection depends on the optimiser: a stronger search picks 5p3z for AL_0033, not 4p3z
**Changed/Found:** Python port (`brain_paper_py/bpy/analysis/tf.py`) of `utils/imp_tf_fit_session.m`. At MATLAB's selected order the port lands on the SAME time constants (AL_0033 4p3z0d tau 0.3331/0.1499, e2 4p3z0d 0.5398/0.0930), so the fitter is right. But a multi-start search finds 5-pole optima that `tfest`'s single local search never reaches, with lower AIC (AL_0033 5p3z0d nAIC -8.26 vs 4p3z0d -8.08; taus 0.106/0.096 instead of 0.333/0.150). With a tfest-like single start + local refine the port matches MATLAB on e1 (3p1z0d) and e2 (4p3z0d) but still prefers 5p3z on AL_0033 and 4p3z (tau 0.201/0.115) over 4p2z on AL_0048.
**Why:** The selected order - and therefore the Fig 2D tau forest - is partly a property of which local optimum tfest happens to find, not only of the data. A referee re-fitting with another toolbox could get different taus.
**Next:** Decide how the paper states model order: (a) keep MATLAB's tfest result and say so in Methods, (b) switch to BIC / a parsimony rule that is robust to the optimiser, or (c) report taus at a fixed order. Re-check 2D after the decision.

### 2026-10-02 - Fig 2G per-quartile numbers in NUMBERS.md not reproduced exactly by the Python port
**Changed/Found:** Port of `impulse-analysis/imp_state_trialvar.m` (`brain_paper_py/bpy/analysis/statevar.py`) reproduces the pool (1767 trials / 4 sessions), every direction and the session-agreement counts (motion 4/4, rel-delta 3/4 with AL_0048 the dissenter, abs-delta 4/4), but the SD ratios top/bottom quartile are 0.72 / 1.12 / 2.20 vs NUMBERS.md 0.71 / 1.10 / 1.99, and per-session rel-delta rho 0.167/0.150/0.095/-0.069 vs 0.115/0.192/0.086/-0.062. Ruled out: the timeBlue edge definition (both definitions give the same numbers to 2 d.p.).
**Why:** The largest gap is on the delta-band markers, consistent with the NUMBERS.md 2G row coming from a run before the 2026-09-11 canonical band change (2-4 / 0.4-10 Hz), but that is not proven.
**Next:** Re-run `imp_state_trialvar.m` once in MATLAB and update NUMBERS.md 2G from that run (it is the canonical registry).

### 2026-10-02 - m14/m15 controller caches hold the flat 594 nm laser trace (stale vs the 2026-10-01 loadData fix)
**Changed/Found:** `data/AL_0048ctrl07292.mat`, `data/AL_0051ctrl07292.mat` - `data.ncInp`/`wcInp` are the 594 nm channel (|v| < 0.05 V), while current `utils/loadData.m` selects 638 nm (the channel that fired). Found by the Python raw rebuild, which matches these caches on every other field (dFk rel 8e-7, onsets exact).
**Why:** The caches were built before the signal-based laser selection; any panel that plots the laser command for m14/m15 would show a flat input.
**Next:** Rebuild m14/m15 with `r_ctrl = 0` before plotting their laser input; no RMSE/variance number is affected (they do not use ncInp).

### 2026-10-02 - Python port now builds Figs 2, 3, 5 from raw server data (class-based); parity vs MATLAB caches
**Changed/Found:** `brain_paper_py` restructured into io / data / analysis / figures layers (`ServerExperiment`, `ControllerSession`, `SineSession`, `ImpulseSession`, `PaperFigure`), CLI `python -m bpy make fig5`. Parity: all 15 controller sessions match their caches downstream of dF/F (287 checks; RMSE/variance/spectra to 1e-5), all 3 bilateral sessions match (18 checks), Fig 5 reproduces every PAPER.md number from raw. `loadData` timeBlue confirmed as `tt(mask)` = the Timeline sample BEFORE each exposure edge.
**Why:** User asked for a port that computes from raw data, with MATLAB caches only as test oracles.
**Next:** The 13 mode-0 controller sessions need raw camera frames; on the server they exist only as `widefield.wfz`, readable with the lab's `wfcompress` package (not yet installed). Fig 4 and the R LMM backend still to do.

<!-- older entries → RESEARCH_archive_2026H2.md (then RESEARCH_archive_2026H1.md) -->
