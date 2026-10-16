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

### 2026-10-16 — Manuscript: Fig 2G Results/caption/Methods made descriptive (Closedloop_edit draft)
**Changed/Found:** `results.tex` — 2G Results now report per-session patterns with no p-values: motion drop at Q4 (0.57–0.71, 4/4), abs δ rising in 4/4 (2.35, 1.70–2.71), rel δ no consistent pattern, and response/control Q4/Q1 0.98 / 0.95 / 0.87 (Fig S2B). Caption: the star/fraction sentence is replaced by "Descriptive panel; … supporting tests in Table". The hand-off to Fig 4 is reworded to "we test this directly in closed loop". `methods_rewrite.tex` — the inference paragraph is now "This analysis is descriptive … supporting test in Table"; the "Per-quartile tests" paragraph is rewritten as "Per-session view"; the stats-section sentence is reworded; the "attribute an effect only when it exceeds its control" rule is dropped. Also fixed a pre-existing broken `\ref` (a CR had replaced the "\r" of `\ref`, so it rendered as "Fig. ef{…}G") at the old line 1162. `supplementary.tex` — the Fig S2 caption describes the descriptive annotations. `paper_stats_table.m` — new rows `2G_*_stimctrl` (response/control Q4/Q1, geometric mean + range). `paper_stats_tex.m` — Table 4 caption marks the slope tests as supporting; the footnote gives response/control ratios plus the supporting top-vs-rest p. Build clean, no undefined refs.
**Why:** User: Fig 2 is groundwork, Fig 3 carries the paper's weight; keep the p-values only in the stats table "just in case".
**Next:** user re-assembles Fig 2 (2G) and Fig S2 in Illustrator; then review draft, ff main + push on their go.

### 2026-10-16 — Fig S2 panels re-exported with descriptive annotations
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — the panel notes no longer show "Q4/Q1–3 x, p=…" or "BF k/4". Columns A, B and D now show "Q4/Q1 GM (min–max)" via the new `local_rr`. The tests are still computed and written to `sq_stats.csv` for the stats table. Re-exported with PAPER_FINAL → 13 panels in `panels/supp_state_quartile/`. Found: response/control Q4/Q1 is motion 0.98 (0.93–1.06), rel δ 0.95 (0.90–1.02), abs δ 0.87 (0.66–0.99). The abs-δ value sits below 1 in all 4 sessions because Q1 response > control, so the response varies slightly LESS with abs δ than ongoing activity does. The Results now say this; it is consistent with a fixed stimulus effect diluting the state dependence.
**Why:** Same descriptive decision; S2 must match the main figure. Q4/Q1 replaces Q4 vs mean(Q1–3), so the paper uses a single ratio definition.
**Next:** user assembles S_state_quartile.pdf.

### 2026-10-16 — Fig 2G re-exported as a descriptive panel (no stars, no k/N)
**Changed/Found:** new `impulse-analysis/imp_state_var_combined.m` holds the Fig-2G combined-panel code (it used to be inline in `imp_state_trialvar_fig.m`, which now calls it). It reads `data/fig2g_state_stats.mat` when called with no arguments, so 2G rebuilds without a data reload. The star + "k/4" text is removed; the drawing is otherwise unchanged. Re-exported with PAPER_FINAL → `panels/figure2/imp_state_var_combined.pdf` (6.46 × 3.46 cm, same as before).
**Why:** User: Fig 2 is groundwork, so it is reported descriptively; Fig 3 carries the paper's claims. The per-session slope test stays only in stats Table 4, marked as supporting.
**Next:** user re-places 2G in Illustrator.

### 2026-10-16 — Legend still broken in the pull folder: fix had not been mirrored
**Changed/Found:** `paper/figures_final/panels/supp_state_quartile/` — the panels were locked into MANIFEST and mirrored at 11:17. The legend fix was re-exported at 11:21 with PAPER_FINAL off, so only `paper/images/supplementary/state_quartile/` got the fixed legend and the Illustrator pull folder kept the swatch-less copy. Re-ran `imp_state_quartile_supp.m` with `global PAPER_FINAL; PAPER_FINAL = true`. All 13 panels re-mirrored (11:25), and the pull-folder `sq_legend.pdf` was verified by rendering: 12 paths, all 7 colours.
**Why:** User verified in Illustrator (pull folder) that the legend was still text-only. My previous check had rendered the working copy, not the pull-folder copy.
**Next:** Once a panel is in MANIFEST, every re-export must run with PAPER_FINAL on, and the check must be made on the figures_final copy.

### 2026-10-16 — Supp state-quartile legend PDF lost its colour swatches
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — `sq_legend.pdf` held only text. legend() fed NaN placeholder lines on an invisible axes drops the swatches from exportgraphics' vector PDF (the PNG looked fine). Legend is now drawn as real line/marker/text objects on a cm-scaled axes with axis off. Also added a black "Mean (stim/control, variance)" item for the ratio and variance tiles. Verified by rendering the PDF (PyMuPDF): 12 vector paths in all 7 colours.
**Why:** User found the legend PDF had no colours in Illustrator.
**Next:** Avoid legend()+NaN+invisible-axes for any standalone legend panel exported as vector PDF; other supp legends may have the same bug (check supp_spatial_cbar-style standalone pieces if they use legend()).

### 2026-10-16 — Fig 2G: per-session quartile ratios replace the bootstrap CI; state-quartile supp figure enters the paper
**Changed/Found:** `paper-writing/paper_stats_table.m` — `2G_*_ratio` / `2G_*_ctrlratio` are now the geometric mean of per-session Q4/Q1 ratios (from `sdRawNs`/`sdPNs`, the drawn curves) with the min–max range; the hierarchical-bootstrap CI is dropped. New rows `2G_*_q4` and `2G_*_beyondctrl` read `sq_stats.csv` (imp_state_quartile_supp). Values: motion 0.58 (0.50–0.81), rel δ 1.03 (0.83–1.16), abs δ 2.35 (1.70–2.71); control 0.60 / 1.08 / 2.70; beyond control 0.92 / 0.95 / 0.95, p = 0.22 / 0.18 / 0.57. `paper_stats_tex.m` — Fig 2G table shows "Ratio (range)" for response and control, and the footnote carries the beyond-control test. Found: the old pooled-trial motion ratio (0.64) did not match the panel's equal-weight session mean (0.58); the δ ratios agreed (2.31 vs 2.35, 1.03 vs 1.03).
**Why:** User: with 4 sessions the CI does not make sense (35 distinct session draws, under-covers); report per-session spreads instead, and cite the existing supplementary state-quartile figure. That figure also tests response against control, so the Results line "we did not compare … statistically" is replaced with the test (weak evidence at n = 4, still worded as an interpretation).
**Next:** user assembles `S_state_quartile.pdf` in Illustrator from `panels/supp_state_quartile/` and uncomments the `\includegraphics`. Supplementary numbering shifted (old S2/S3 → S3/S4). The supp uses Q4 vs mean(Q1–3), while the main text uses Q4/Q1; the captions define both.

### 2026-10-16 — Manuscript: Fig 2G text blended with Figure S2 (Closedloop_edit draft)
**Changed/Found:** `Closedloop_edit/results.tex` — 2G caption points to Figure S2; Results quote the per-session ratios with ranges, add "motion is a step at Q4 (0.57–0.71, lowest in every session)", "abs δ rises quartile to quartile in all four sessions", and the response/control test. `methods_rewrite.tex` — bootstrap paragraph replaced by the per-session GM + range rationale; new "Per-quartile tests" paragraph; the stats-section bootstrap sentence was removed. `supplementary.tex` — new float `fig:state_quartile` (caption only, assembly pending). `stat_tables.tex` regenerated. latexmk builds clean, no undefined refs. Registry row added in PAPER.md; 13 panels added to MANIFEST `[supp_state_quartile]` and mirrored.
**Why:** Same decision as the entry above; the text has to match the new table and cite the supplementary figure.
**Next:** user reviews `git diff main..draft`, then ff main + push on their go.

### 2026-10-16 — Manuscript: Statistical tables section; numbers trimmed from Results (draft b2212d3, not pushed)
**Changed/Found:** `Closedloop_edit`: new `stat_tables.tex` (\input after Methods, booktabs added to main.tex) with Tables 3-7 (trial counts, Fig 2G, Fig 3 A/B, Fig 4D moved out of Methods with gap/gap-trend + motion slopes added, Fig 4G). Results/captions now keep effect + one p and cite the table. Fig 2B caption gives one trials-per-amplitude number per mouse (about 52/52/83/100). Discussion L18 gap-trend p list replaced by a table ref. Methods: \label{sec:stats}, a pointer sentence, and the Corroborating paragraph reduced to pointers. Builds clean (no undefined refs, no overfull boxes); the tables are flushed before the references with \clearpage. Synced first to the user's Overleaf commit ec17cda.
**Why:** User: move numbers out of the text into readable tables in a separate stats section ("clean and readable"), then "i pushed, sync and apply edits".
**Next:** user reviews the rendered tables (paper-writing/stat_tables_preview/), then push draft + ff main on their go.

### 2026-10-16 — paper_stats_tex.m + f2b_trial_counts.m: generated stats tables
**Changed/Found:** new `paper-writing/paper_stats_tex.m` writes `Closedloop_edit/stat_tables.tex` from STATS_TABLE.csv + `data/fig2b_trial_counts.csv`. The counts come from new `impulse-analysis/f2b_trial_counts.m` (needs load_experiments; 21 session x amplitude rows, 1516 trials). The only hand-entered numbers are the Fig 4D trial counts (1670/1190, documented in the code). Formatting: p to 2 significant figures with the trailing zero kept, sci notation below 0.001; log slopes converted to percent; the stored CL-OL gap is shown as OL-CL to match the Methods definition. AL_0048 amplitudes are command V like the others (load_bilateral_impulse reads Timeline volts), so mW = V/3 applies.
**Why:** No hand-typed statistics in the paper; one rerun updates every table.
**Next:** run order after any stats change: paper_stats_table -> paper_stats_tex -> latexmk.

### 2026-10-16 — Manuscript: Fig 3 rewritten to the CL/OL scheme + stats-audit fixes, pushed
**Changed/Found:** `Closedloop_edit` results.tex / methods_rewrite.tex / discussion.tex (draft 746f9b4, main fast-forwarded, both pushed). 3H/3I caption, Results and Methods now use CL/OL ratios, geometric mean [95% CI] and % lower, with the primary session-level LMM; the trial-level LMM and log-ratio Wilcoxon moved to the Corroborating paragraph. Fixed the three wrong p-values (pre 0.85 -> 0.84 LMM; post 0.76 -> 0.48; 0-1 s variance test now the ratio LMM). Full 0-3 s window: effect + 15/15 sessions only, no session-LMM p; the t-test and per-trial LMM p go in Corroborating, and Methods explains why. 4G Methods now leads with logRR~1+(1|sess). Deleted the "same direction in every mouse" promise and the "between-mouse variance negligible" claim. Loop delay: "at most 47 ms, about half that on average" (Results L40, Methods, Discussion; the FILL is removed); Discussion adds the average-latency bandwidth (~4 Hz, tau_eff ~37 ms). Discussion softened the relative 2-4 Hz argument (p=0.044 now "if the trend is real"). Builds clean.
**Why:** User: decisions 2-4 (soften the Discussion; 47 ms worst case and half on average; delete the sentence), then "make all other corrections then we push". On decision 1 the user pointed out that the single-session mice affect every test. The 0-3 s collapse is specific to REML putting nonzero variance on mouse there (it is ~0 in the sub-windows), so the full window is reported without a session-LMM p rather than switching tests.
**Next:** user to confirm the 0-3 s handling. Remaining unsourced numbers (2B slopes, leak %, Discussion MPC R2 0.42/0.10, "44-55%", "seven of 13") are still unchecked.

### 2026-10-16 — Fig 2B caption: explicit trial counts per amplitude
**Changed/Found:** `Closedloop_edit/results.tex` Fig 2B caption — "19--84 trials per amplitude" replaced by the explicit counts, lowest to highest amplitude, from `load_experiments` (allExperiments.groupLabels, non-NaN, nonzero amps): Mouse 5a (AL_0041 e1) 44/49/59/56 = 208; Mouse 5b (AL_0041 e2) 53/58/45/50/54 = 260; Mouse 1 (AL_0033 0129) 84/84/82/85/81/84/82/82/84 = 748; Mouse 3 (AL_0048 0715 R) 100/100/100 = 300; total 1516. The old "19" came from RESEARCH L51's mW binning, which split the 45 trials into 26+19; the panel bins by command voltage. Builds clean; draft commit, not pushed.
**Why:** User: "on trial counts, dont use range, just explicitly state". The caption range contradicted the Methods' "at least 44".
**Next:** Methods L725/L1176 "at least 44" is now consistent and left as is. AL_0041 e1 0.53 mW has 49 usable trials (stim_vars lists 50; one is NaN).

### 2026-10-15 — Stats-to-paper audit of the full manuscript (read-only)
**Changed/Found:** `paper-writing/STATS_AUDIT_2026-10-15.md` — checked every statistical number in the built manuscript files against STATS_TABLE.csv and saved outputs. Figs 2/4 and the supplementary are clean (~65 matches). Fig 3H/3I text and Methods are stale against the CL/OL scheme. Wrong in the current text: RMSE pre p 0.85 (should be 0.095), variance post p 0.76 (should be 0.64), variance 0-1 s p 4.3e-4 is the trial-level signed-rank. Also: Fig 2B trial counts (caption 19-84 vs Methods >=44), Discussion leans on the relative-delta p=0.044 that Results disclaims, 4G Methods leads with the nested model, the df-fallback is called conservative, and an unfulfilled "every mouse" promise. Unsourced numbers listed (47 ms loop delay, 2B slopes, leak %, Discussion MPC R2).
**Why:** User asked for a stats-to-paper consistency check including captions.
**Next:** main session rewrites Fig 3 Results/caption/Methods from section A and fixes B; user decides the full 0-3 s window test (section C).

### 2026-10-15 — Manuscript Figure 3 composite updated with the new 3H/3I
**Changed/Found:** `Closedloop_edit/images/Figure3.pdf` replaced by the user's Illustrator re-export (`paper/figures_final/Figure3.pdf`, 23:24) showing the CL/OL log-axis 3H/3I; latexmk builds clean (0 errors). Committed on draft (dbf92a9), not pushed.
**Why:** User asked to update the figure PDF in the paper.
**Next:** the Fig 3 caption/Results/Methods still describe OL/CL ratios with "above one" — they now contradict the figure until the text rewrite; push draft/main only on the user's go.

### 2026-10-15 — Fig 3H/3I final panels re-exported (trace layout)
**Changed/Found:** `controller-analysis/variance_mse.m` Fr + G2r re-run with PAPER_FINAL on, after the user closed the locked panels in Illustrator. figures_final/panels/figure3/MSE_ratio_by_window.pdf (3.56 x 2.65 cm) and variance_ratio_by_window.pdf (3.67 x 2.65 cm) now show the trace layout; stats unchanged.
**Why:** The previous export skipped both panels because the PDFs were locked.
**Next:** re-place 3H/3I in Illustrator; main session rewrites the Fig 3 Results/caption/Methods.

### 2026-10-15 — Fig 3H/3I restored to the old trace layout (user)
**Changed/Found:** `utils/plot_ratio_windows.m` — dropped the jittered point clouds; each session is again a grey trace across the 4 windows (markers aligned in columns), black = geometric-mean trace with 95% CI bars. Metrics unchanged (CL/OL, log y). Working copies in paper/images/figure3 re-exported; the figures_final panels were LOCKED (open in Illustrator) and NOT updated.
**Why:** User: the old layout was cleaner, and the traces show session continuity.
**Next:** close the two panels in Illustrator, re-run variance_mse.m Fr + G2r with PAPER_FINAL on, then re-place them.

### 2026-10-15 — Fig 3H/3I Satterthwaite df collapses for the full 0-3 s window (4 mice)
**Changed/Found:** `utils/ratio_session_stats.m` — the primary LMM log(r) ~ 1 + (1|mouse) is fine for the panel windows (RMSE 0-1/1-3 s df 14, p 2.0e-5 / 1.1e-6; variance df 6.0 / 8.0, p 0.0039 / 5.4e-5), but for the stats-only full 0-3 s window the mouse variance sits off zero and Satterthwaite df collapses: RMSE 0-3 s t=-7.48, df 0.97, p=0.089 (t-test p=9.2e-8, 15/15 sessions < 1); variance 0-3 s df 0 -> p NaN (project fallback df=n-1 gives p=1.3e-5). Pre RMSE df also 2.7.
**Why:** 4 mice, two of them single-session (AL_0048, AL_0051), so the mouse-variance estimate is at the boundary and Satterthwaite is unstable; it is not a data effect (early and late windows, which make up 0-3 s, are both highly significant).
**Next:** user decision before the Results rewrite — quote the full window via the t-test, or drop the mouse term / use an LRT when the mouse SD is ~0. Do not quote "LMM p=0.089" for 0-3 s without that context.

### 2026-10-15 — Fig 3H/3I on one session-level CL/OL ratio scheme, log-axis replot
**Changed/Found:** `controller-analysis/variance_mse.m` (sections Fr, G2r; header G3 load removed) — ratios flipped to CL/OL (< 1 = CL better), full 0-3 s window added (stats only), stats via new `utils/ratio_session_stats.m` (geo-mean [t 95% CI], % lower, PRIMARY LMM log(r)~1+(1|mouse) REML Satterthwaite, one-sample t on log r, Wilcoxon on log r, n<1), saved to `data/fig3_ratio_stats.mat` (R3.rmse/R3.var). Variance test was a paired signrank on RAW variances; now on log ratios as Methods say. Panels drawn by new `utils/plot_ratio_windows.m`: log y, sessions as grey points, black geo-mean ±95% CI, dashed 1; title stars from the session LMM (max p of the two stim windows). Re-exported with PAPER_FINAL (MANIFEST basenames MSE_ratio_by_window / variance_ratio_by_window). `paper-writing/paper_stats_table.m` now reads fig3_ratio_stats.mat (old fig3h_*signrank.mat no longer read); trial-level LMM + signrank rows relabelled CORROBORATING; STATS_TABLE.csv regenerated (88 rows).
Result: medians CL/OL RMSE 1.020/0.877/0.722/0.991, variance 1.014/0.625/0.536/0.996 (pre/0-1/1-3/post) — match the expected sanity values. Geo-mean RMSE 0.848 (15.2% lower) / 0.683 (31.7%); variance 0.652 (34.8%) / 0.542 (45.8%); pre/post n.s.
**Why:** user decision 2026-10-15: one consistent session-level scheme for every Fig 3 summary statistic.
**Next:** re-place 3H/3I in Illustrator; rewrite Fig 3 Results + caption + Methods (methods_rewrite.tex L1427-1451 still says OL/CL, Wilcoxon) in the main session; old-direction OL/CL ratios remain in fig3_olcl_stats medRatio, talk/redraw_fig3_colors.m, presentation/export_xsession_stats.m.

### 2026-10-15 — DECIDED: Fig 2 impulse TF window stays 0–0.5 s; −0.5..+1.0 s alternative not adopted
**Changed/Found:** No code, cache, panel or manuscript change. `impulse-analysis/ALT_WINDOW_DECISION.md` marked DECIDED. `data/imp_tf_fits.mat`, the Fig 2 C–F producers and finals stay as they are. The alternative cache (`data/imp_tf_fits_win_m0p5_1p0.mat`), the engine knobs and the exploratory scripts (`imp_tf_altwin*.m`, `imp_tf_modes.m`, `imp_tf_ol_stepcheck.m`) stay as the record.
**Why:** User: "keep the 0-0.5 s window dont change anything". The longer window's main gain is a rebound mode, and the open-loop 3 s step check showed that mode predicts sustained input wrongly (96–110 % relaxation by 1 s vs 7 % measured). The rebound is an offset effect, so it is described empirically, not as a plant mode.
**Next:** none for the window. The Results sentences drafted in the decision note (dip energy share; rebound as an offset effect with OL relaxation numbers) are optional text for the user.

### 2026-10-15 — Manuscript language/flow pass, Results Figs 1-4 (Closedloop_edit draft 68250de)
**Changed/Found:** `Closedloop_edit/results.tex`, `methods_rewrite.tex` after ff-pulling the user's Overleaf push (52e2591). Fig 2: section opener, split-half CV wording (fit and score on trial averages of random halves), caption C/D CV detail. Fig 2G Methods: "L2 error" -> "trial-to-trial variability", "stimulus-free control" -> "stimulus-free window". Fig 3: H/I sentences now state the ratio direction (OL/CL, >1 = CL better) and quote the during-stimulation medians (RMSE 1.14/1.39, variance 1.60/1.87) before pre/post; Methods sentence explains why model % (24/41%) differs from the window-variance ratio. Fig 4: section rewritten (state definitions merged, decomposition described per caption C — rel and abs power in separate models, abs 0.07 when both in; predictability/regularizability sign convention); `tab:fig4_state_stats` moved to Methods after "Multiple comparisons". Every Fig 3/Fig 4 number checked against STATS_TABLE and fig3h_*_signrank.mat — all match. Build clean, 41 pp. Committed on draft, not pushed.
**Why:** User-led language and flow review for concision, correct numbers and consistent single-session vs pooled panel references.
**Next:** Fig 3 text will be rewritten again after the CL/OL log-ratio rerun. The L84 rebound sentence conflicts with the OL step-check finding (rebound = offset effect); the L100 rel-δ sentence conflicts with the lit review (b). Both await the user's decision. Push only on the user's go.

### 2026-10-15 — Fig 2 caption numbers were wrong (found in chat review)
**Changed/Found:** Fig 2A caption said 0.23–0.90 mW, but `trace_overlay.m` draws odd amplitude indices of AL_0041 e2 = 0.23/0.63/0.87 mW. Fig 2B said "100 trials per amplitude", but `stim_vars_*.mat` gives 19–84 (5b: 53/58/26/19/50/54). The user applied both fixes on Overleaf. Verified in the same pass: 2G n = 1516 (208/260/748/300), stars (motion p 0.030, rel 0.17, abs 7.4e-4), sign fractions 4/4, 3/4, 4/4; the 2D CV is a stratified split-half with 100 splits in both directions.
**Why:** Pre-submission number audit requested by the user.
**Next:** Confirm 0.87 against the rendered 2A legend. Mouse 3 rebound text vs caption is reconciled ("at the edge of the 0.5 s window").

### 2026-10-15 — Lit review of absolute vs relative δ as state variables; Fig 2 rel-δ denominator is effectively 1–10 Hz
**Changed/Found:** NEW `paper-writing/lit_delta_state_2026-10-15.md`, a literature report with 61 verified references. Framing verdicts:
- (a) "absolute δ = disturbance amplitude" is defensible as an operational, additive framing. Precedent: Arieli 1996; Shimaoka 2019 (mouse wide-field, "interacted additively"); Bolus 2021 (brain state as unmeasured disturbance). Our stimulus-free control is our own evidence for it.
- (b) "relative δ is independent of overall power" is NOT defensible. Band ratios cancel a pure gain but track the 1/f slope (Donoghue, Dominguez & Voytek 2020 eNeuro). With GCaMP6s/8s, 2–4 Hz is on the indicator roll-off.
- (c) Fig 2 "motion → lower variability" fits arousal/desynchronization (Vinck 2015; Poulet & Petersen 2008; Jacobs 2020). The Fig 4 open-loop rise with motion fits movement-as-disturbance (Musall/Stringer 2019). The window difference (pre-only vs −2..+3 s) reconciles the two.

Code-level find in `imp_state_trialvar.m` `local_delta`: a 1 s window (n = 35, 1 Hz grid) means `f >= 0.4` selects only bins 1…10 Hz. The Fig 2 rel-δ denominator is therefore effectively 1–10 Hz, not 0.4–10 Hz.
**Why:** The Results L80 sentence on the two δ measures is the one reviewers and Nick will push on. The relative-δ closed-loop effect (p = 0.044) already fails correction (L155) and did not replicate on Zhiwen's data (FINDINGS), so the text should not promise it.
**Next:** Decide whether to adopt the rewrite in the report (results L80 + Methods + Discussion; new bib keys Jacobs2020, Donoghue2020eNeuro, Ma2016, Valley2020, Chen2013, Curto2009, Lin2015). Optional controls: partial out log total power from rel-δ; repeat on a hemo-corrected subset; state the effective 1–10 Hz Fig 2 denominator in Methods.

### 2026-10-15 — OL sustained stim vs impulse-model step prediction: suppression is SUSTAINED; rebound is an offset effect, not a linear mode
**Changed/Found:** NEW `impulse-analysis/imp_tf_ol_stepcheck.m` (reads `data` only from the 15 controller caches, never `d`; both impulse TF caches) → `paper/images/figure3/alt_step_check/ol_step_vs_impulse.png`. OL trials apply a near-constant 0.3–1.3 V command for 3 s (trial-to-trial SD 0.004–0.01 V in 2025-04+ and 2026 sessions; 0.4–0.8 V in the older AL_0033 sessions, harmless for a mean prediction by linearity). Measured trial-averaged OL dF/F (baseline −1..0 s), 15 sessions / 4 mice: peak suppression at median 1.20 s (0.57–2.80); relaxation by 1 s median 7 % (2–22 %); by 3 s median 21 % (5–37 %, AL_0048 72 %); overshoot after offset median +27 % of peak (+7 to +90 %). Impulse-model prediction for Mouse 1 (AL_0033, 9 sessions, driven by each session's mean OL command): relaxation by 1 s 79–87 % (current fits) / 96–110 % (alt fits), vs measured 2–22 %. Both models do reproduce the initial ~0.3 s dip of the step. Mouse 3 (AL_0048, unit step because its OL command is not in the cache): current fit predicts 121 % / alt 58 % by 1 s, measured 7 %. Models also under-predict the size of the step response (Mouse 1 model peak −1.6 to −3.8 vs measured −3.3 to −8.1 %dF/F; different day/pixel/dF-F definition, not pursued).
Side observations, not chased: AL_0048 ctrl cache records the OL command as −0.02 V (newbuild input channel); `AL_0033ctrl04191` and `AL_0039ctrl04191` have identical OL command statistics to 3 decimals (possible cache duplication).
**Why:** The modal analysis showed LTI impulse models predict fast relaxation under sustained input, contradicting the planned "slow drift" sentence and the closed loop's ability to hold −5 %. OL steps are the direct test. Result: the rebound seen after a brief pulse is a release (offset) effect, not a linear mode that acts during sustained input, so neither fit set's slow mode describes sustained behaviour. Caveat: the controller dF/F uses a 40 s trailing mean, which can inflate 3 s relaxation by at most a few % of peak.
**Next:** Revises the window recommendation in `ALT_WINDOW_DECISION.md`: keep 0–0.5 s for the plant (dip dynamics), describe the rebound empirically. Optional: check AL_0048's OL command channel and the 04-19 cache duplication.

### 2026-10-15 — Modal decomposition of both impulse TF fit sets: per-mode shares are fragile; LTI predicts fast relaxation, not slow drift
**Changed/Found:** NEW `impulse-analysis/imp_tf_modes.m` (read-only on both caches) → `paper/images/figure2/alt_window/modes_overlay.png`, `modes_step.png`. Partial fractions per selected TF; dip = fastest complex pair, offset = tau > 10 s (old M5a 1.7e6 s, old M3 1768 s; excluded from shares and steps), rebound = slowest remaining mode. Sessions M5a/M5b/M1/M3, current → alt:
- **Per-mode shares are not robust.** Window energy share dip/rebound: 100/– → 76/20 | 11/89 → 65/35 | 26/74 → 9/25 (a 0.118 s real "other" mode takes 66 %) | 7/33 → 33/67. DC-gain shares reach +1814 / −1714 % (alt M5b) and +1086 % (alt M1). Cancellation index (summed modal energy / model energy) up to 8.9 (alt M1) and 7.1 (old M3): large modes cancel, so "X % of energy in the dip" depends on how the fit places its poles, not on the response.
- **Model-free replacement:** share of measured h(t) energy in 0–0.25 s of 0–1 s = 80 / 65 / 76 / 88 % on the pre-mean reference (72 / 39 / 67 / 79 % on the onset reference); alt models reproduce it (81 / 66 / 79 / 89 %).
- **Rebound / dip amplitude (measured):** 18 / 45 / 29 / 28 % pre-mean ref; 6 / 68 / 35 / 35 % onset ref (the reference matters for M5a/M5b).
- **Sustained input under LTI:** the step response predicted straight from the data (running sum of h, to 1 s) peaks at 0.17–0.20 s and relaxes 111 / 117 / 59 % by 1 s in M5b / M1 / M3 (crosses zero in two). M5a does not relax (still deepening at 1 s). Alt models agree (118 / 116 / 59 %); old models do not (66 / 76 / 130 %). 3 s model steps (offset removed): relaxation 12 / 115 / 78 / 186 % (old), 23 / 93 / 132 / 58 % (alt). The rebound is small in amplitude but long, so its AREA offsets most of the dip's: LTI predicts the suppression largely gone within ~1 s, NOT a gradual drift.
- **Dip tau:** 0.106 / 0.112 / 0.114 / 0.144 → 0.073 / 0.093 / 0.095 / 0.100 s (median 0.113 → 0.094); frequency 2.4 / 4.1 / 4.2 / 3.2 → 1.8 / 2.1 / 3.8 / 3.5 Hz. Consistently ~20 % shorter with the longer window; old pair partly absorbed the rebound.
- **Rebound tau CI:** alt [0.18 0.99] / [0.15 0.96] / [0.17 0.82] / [0.15 0.97] s, upper ends near tauMax 1.03 s; beyond-window discard 42 / 50 / 5 / 14 %. Better than old (censored at 0.5 s; M3 no CI) but still not identified in M5a/M5b.
**Why:** User asked for numbers behind two planned Results claims (dip dominates; rebound is small slow drift removed by the integral term), for both fit sets. The second claim conflicts with the LTI prediction from the impulse data. The controller holds a sustained −5 % level in closed loop, which needs non-zero plant DC gain, so the impulse-derived DC gain is probably wrong for sustained input (rebound likely an offset/nonlinear effect, or DC not constrained by a ≤1 s impulse window).
**Next:** Before writing the drift sentence: compare open-loop sustained-stim trial averages (Fig 3 OL trials) with the impulse-model step prediction. Use the model-free energy split, not modal shares, in Results. Fixed during the run: legend names, CI row lookup (dip last / rebound first, as in imp_tf_altwin_figs), model split NaN.

### 2026-10-15 — Alt-window (−0.5..+1.0 s) impulse TF fits + candidate panels: rebound captured, dip tighter, rebound tau still loose
**Changed/Found:** NEW `impulse-analysis/imp_tf_altwin.m` (runner: preData_s 0.5, tFit_s 1.0, refMode 'premean', BIC + EnforceStability + R2h≥0.98 escalation, 300-draw bootstrap; per-session part files + merge) → `data/imp_tf_fits_win_m0p5_1p0.mat`. NEW `impulse-analysis/imp_tf_altwin_figs.m` → PNG only in `paper/images/figure2/alt_window/`: `alt_fit_overlay.png`, `alt_tau_forest.png`, `alt_model_swap.png`. Fig-2 cache, finals, MANIFEST and manuscript untouched. Old → new (labels M5a/M5b/M1/M3 = AL_0041 e1/e2, AL_0033, AL_0048):
- order 3p1z(esc) → 5p2z(esc) | 4p3z → 4p2z | 4p3z → 4p3z | 5p4z → 4p3z.
- dip tau (fastest oscillatory pair) 0.106 → 0.073 [0.021 0.186] | 0.112 → 0.093 [0.010 0.129] | 0.114 → 0.095 [0.053 0.164] | 0.144 (no CI) → 0.100 [0.012 0.219] s.
- rebound tau (slowest mode) 1.7e6 → 1.507 [0.183 0.994] | 0.973 → 0.678 [0.147 0.964] | 0.268 → 0.324 [0.170 0.820] | 1768 (no CI) → 0.180 [0.146 0.965] s.
- bootstrap discard 41 → 61 % | 73 → 52 % | 3 → 5 % | 100 → 15 % (new tauMax = 1.03 s).
- pooled LTI R² 0.686 → 0.347 (0–1 s) / 0.609 (0–0.5 s) | 0.622 → 0.539 / 0.719 | 0.862 → 0.840 / 0.883 | 0.913 → 0.845 / 0.946.
- R² 0.25–1.0 s (rebound): old models extrapolated −0.52 / −2.12 / −2.55 / −0.04; new 0.87 / 0.97 / 0.84 / 0.94. Rebound peak measured vs new model 0.10 vs 0.11, 0.30 vs 0.29, 0.23 vs 0.26, 0.54 vs 0.48 %/V.
- model swap (free gain): self 0.992 → 0.985; off-diagonal mean 0.691 → 0.704, median 0.724 → 0.761. M5a is still the outlier.
Fix during the run: the figs script first took dip = fastest pole of any kind, which picked a 15 ms real pole in new M5a; changed to the fastest COMPLEX pair (the Fig-2F text's definition). The old cache lacks tauBootBeyond/Fail (predates 10-12), so old discard rates are totals only. The "pre-window R²" printed by the script is 0 by construction (model is 0, data zero-mean) and carries no information.
**Why:** User asked for an exploratory refit on a window with real pre-onset data that deals with the rebound rather than repeating the rejected 10-03 run. Pre-mean referencing plus fitting the real pre-onset samples keeps 3 of 4 sessions below the pole cap with stable poles and an identifiable dip, which the 10-03 run could not do. The rebound mode is still weakly identified: its CI runs to the 1 s window edge in 3 of 4 sessions.
**Next:** USER DECISION: switch Fig 2 TF to this window or keep 0–0.5 s. If switching: decide whether the forest shows the rebound tau at all (CIs touch the window edge), rerun CV (`imp_tf_cv` has no preData path yet) and write Methods text on the pre-mean reference.

### 2026-10-15 — Alt-window (−0.5..+1.0 s) config sweep: pre-mean ref + real pre data captures the rebound below the pole cap
**Changed/Found:** Scratch `explore_cfg.m` (no bootstrap; `imp_tf_fit_session` with preData_s 0.5, tFit_s 1.0, refMode 'premean'). Orders / R2h / R² over 0.25–1.0 s (rebound) for M1a, M1b, M2, M3:
- B (AIC, R2h ≥ 0.98 escalation): 5p2z (escalated) / 4p3z / 4p3z / 5p4z; R2h 0.964/0.987/0.992/0.996; rebound R² 0.87/0.97/0.84/0.96.
- D (BIC + EnforceStability + escalation): 5p2z (escalated) / 4p2z / 4p3z / 4p3z; R2h 0.964/0.987/0.992/0.996; rebound R² 0.87/0.97/0.84/0.94. Rebound peak measured vs model: 0.10 vs 0.11, 0.30 vs 0.29, 0.23 vs 0.26, 0.54 vs 0.48 %/V. Every model stable.
- F (BIC + stability, NO escalation): M1a drops to 4p2z but R2h 0.75 / rebound R² 0.52 (underfit); others same as D.
- Configs A (onset ref = the rejected run), C and E never started (MATLAB license queue) and were killed. E would select the same as D: M1a stays under 0.95 at every order below the cap.
Contrast with the rejected 2026-10-03 run (onset ref, synthetic lead-in, 0–1.0 s): every session hit the 5-pole cap there; here 3 of 4 sit at 4 poles. The one escalated session, M1a, is the one with almost no rebound.
**Why:** Choose selection settings before the expensive bootstrap. The escalation rule, not AIC vs BIC, is what pushes M1a to the cap; dropping it underfits, so it stays.
**Next:** Full fit with config D + 300-draw bootstrap → `data/imp_tf_fits_win_m0p5_1p0.mat`; panels via `imp_tf_altwin_figs.m`.

### 2026-10-15 — imp_tf_fit_session: alternative-window knobs (real pre-onset data, pre-mean reference)
**Changed/Found:** `utils/imp_tf_fit_session.m` — new opts, all defaulting to the current behaviour: `preData_s` (fit real pre-onset samples [-preData_s, 0) instead of the synthetic zero lead-in; threaded through the main sweep, LOAO, per-amp and bootstrap refits via a new `local_iddata`), `refMode` `'onset'|'premean'` (re-reference amp-averages and per-trial `dfImp` to the mean over [-refPre_s, 0)), `enforceStab` (tfest EnforceStability), and `select='bic'`. `seedOffset` is switched off when `preData_s > 0`. Regression: with the cached `sweepOpt` the engine reproduces all 4 cached models exactly (3p1z0d / 4p3z0d / 4p3z0d / 5p4z0d, identical tau and R2h). ITI check for the pre-onset window: the nearest preceding stim of ANY kind (AL_0048's interleaved L-site excitatory stims included) is ≥ 2.5 s before onset in every session (medians 5.7 / 6.1 / 5.7 / 9.5 s), so −0.5..0 s is ≥ 2 s after the previous onset, past the rebound (gone by ~0.77 s). Trials were onset-frame referenced, so the trial-average pre-window sits at −0.06 / +0.09 / +0.03 / +0.09 %/V (one frame's noise as a constant offset).
**Why:** User asked for an exploratory −0.5..+1.0 s refit with real pre-onset data. Zero initial conditions are only honest if the pre-onset segment is at baseline. Pre-mean referencing makes it zero-mean by construction, and the ITI check shows nothing from the previous trial is left to remove. Knobs rather than a fork, so the Fig 2 path is untouched.
**Next:** Run the config sweep (onset/premean × AIC/BIC × stability) on the new window, then the full 300-draw bootstrap into `data/imp_tf_fits_win_m0p5_1p0.mat`.

### 2026-10-15 — Supp state-quartile panels v2: smaller tiles for row whitespace
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — tiles 4.0×3.3 → 3.6×2.8 cm. Axes Position fixed to [0.22 0.27 0.74 0.55] so labels and the 2-line note fit the canvas. At the smaller size these clipped: y-labels ("RMS error (× typical)", "Variance of trial error"), right-hand notes and the "Absolute δ power quartile" x-label. Shortened to "Norm. RMS error", "Stim / control RMS", "Trial error", "Error variance", "Rel./Abs. δ quartile". The variance note is now 2 lines (BF n/4 sessions; Q4/Q1–3 ratio, p). p shown with 2 significant figures. Unicode δ with Interpreter none (tex bold had spread the words apart).
**Why:** User wants smaller panels to add whitespace between rows in Illustrator.
**Next:** User assembles in Illustrator. Register in MANIFEST.txt/PAPER.md when locked.

### 2026-10-15 — Supp prototype v1: state-quartile prediction-error panels (JN style)
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` (new producer) → `paper/images/supplementary/state_quartile/sq_<mot|dpr|dpa>_<rms|ratio|dist|var>.pdf` + `sq_legend.pdf` + `sq_stats.csv`. JN style (jnFig/jnAxes/jnExport), 4.0 × 3.3 cm tiles, one row per Fig-2G state (motion, rel δ, abs δ; pre-var left out as the power confound). Each tile carries its test as a one-line annotation. Sessions are named S1–4 = Mouse 1a/1b (AL_0041 e1/e2), Mouse 2 (AL_0033), Mouse 3 (AL_0048), from the load_experiments order. Numbers match imp_state_quartile_profile.m.
**Why:** User wants the per-quartile/per-session variance view as a supplementary figure, assembled in Illustrator, with stats per row.
**Next:** Iterate on layout with the user. Not yet in MANIFEST.txt/PAPER.md: register it once the user locks it. The variance column still has no stim-free control (needs per-trial yp saved by imp_state_trialvar.m).

### 2026-10-15 — Fig 2G quartile profile: per-session VARIANCE of trial error added
**Changed/Found:** `impulse-analysis/imp_state_quartile_profile.m` — new 4th column: var(per-trial error y) in each quartile × session, 95% trial-bootstrap CI, within-session Brown–Forsythe (Stouffer), session t on log(var Q4/Q1–3); table → `paper/images/figure2/imp_state_quartile_var.csv`. Motion: var flat ~0.35–0.45 in Q1–3, falls to 0.09–0.22 in Q4 in 4/4 sessions (BF p ≤ 0.005 each, Stouffer 2e-11; Q4/Q1–3 = 0.40, p = 0.018). Pre-var: rises 0.05–0.15 → 0.41–0.62 (4/4, p = 0.023). Abs δ: rises in 3/4 sessions (S4 BF p = 0.13; session p = 0.11). Rel δ: no effect (BF Stouffer p = 0.32; only S4 p = 0.045).
**Why:** User: the plot lacked the variance of the trial prediction error per quartile × state × session, wanted for a possible supplementary figure.
**Next:** No per-trial control error in the saved stats, so this column is stim-only. Add the per-trial control vector (yp) to STV_R in `imp_state_trialvar.m` if the supplement needs a variance-vs-control comparison. Session labels are S1–S4 by index; map them to mouse/date before any supplement.

### 2026-10-15 — Fig 2G full per-quartile profile of prediction-error spread
**Changed/Found:** `impulse-analysis/imp_state_quartile_profile.m` (new; reads `data/fig2g_state_stats.mat`, no reload) → `paper/images/figure2/imp_state_quartile_profile.png`. Per-session RMS error Q1..Q4 (mean of 4 sessions). Motion: 1.12/1.04/1.10/**0.65**, a step at Q4 only, not a trend. Q4/mean(Q1–3) = 0.60 (4/4 sessions, t p=0.002), Friedman p=0.038. But the control steps the same way (0.69 at Q4); beyond control 0.92, p=0.22. Pre-var and abs δ: monotone 0.54→1.43 and 0.58→1.35, matched by the control (beyond control ≈0.95, p≈0.57; power confound as before). Rel δ: flat, 0.96/1.00/1.02/0.99, Friedman p=0.61, Q4 contrast p=0.91. Within-session Kruskal–Wallis is significant for every state (Stouffer), but session-level tests are not for rel δ.
**Why:** User asked whether the spread changes quartile-to-quartile in a way the Q4/Q1 + linear-slope summary misses.
**Next:** Decide whether the motion "Q4 step" shape goes into the 2G text. It does not beat the stim-free control, so it supports "state shapes ongoing activity", not "state shapes the evoked response".

### 2026-10-13 — Manuscript: captions de-numbered, Results to one primary test per claim
**Changed/Found:** `Closedloop_edit/results.tex`, `methods_rewrite.tex` (draft 37280b9). Captions for Figs 2/3/4 now carry only what is drawn, n and star definitions (words 494→371, 393→323, 505→354; Fig 2 numbers 53→38, Fig 4 52→36). The τ bootstrap fractions (39/72/3/100%) went into Methods (time constants). Results now gives each claim one primary test. 2G: per-session slope t-tests. Fig 3: the mixed model for the full, transient and steady-state windows, plus Wilcoxon for pre/post. The redundant "We tested every OL vs CL…" paragraph is deleted. Fig 4D now leads with two messages, motion rejected and abs δ not held; rel δ gets one sentence saying it does not survive correction. The 4G mouse-level 1.2-df model moved to Methods. A new Methods paragraph, "Corroborating tests", holds the Wilcoxon, Spearman and per-session-OLS checks. The multiple-comparison paragraph now states once which effects clear Bonferroni (abs power in every family, motion only for attenuation). Results p-values went 37→25 and Results words 4562→4007. No number changed.
**Why:** User critique: captions read as results, and the Results looked statistically forced, with repeated Bonferroni/uncorrected hedging and redundant corroborating tests.
**Next:** User reads it on Overleaf after the ff push to main. The captions are still ~320–370 words for the 7-panel figures; further trimming would mean dropping drawn-content description.

### 2026-10-13 — Manuscript pushed to Overleaf with re-exported Figures 2–4
**Changed/Found:**
- Copied the user's re-exported `figures_final/Figure{2,3,4}.pdf` to `Closedloop_edit/images`. Figure 2 has the global mouse labels and the new 2G stars; Figure 3 has the 3F bar; Figure 4 has the session-level 4C and the 4F title.
- `images/Figure1.pdf` was deliberately NOT updated: the user's `figures_final/Figure1.pdf` was accidentally overwritten with Figure 2 content, so main's copy is kept.
- Build: 42 pp, clean.
- Commit abb3119 on draft, then fast-forwarded `main` and pushed (6e0ddf2..abb3119). The first push hung up; the retry with `http.version=HTTP/1.1` and a larger postBuffer succeeded.

**Why:** the user asked to update the figures, commit everything and push the paper to main.
**Next:** the user re-exports Figure 1 from Illustrator so `figures_final/Figure1.pdf` is correct again. The manuscript's copy is fine.

### 2026-10-13 — User confirmations: AL_0051 stays; Matveev 2024 supports the crosstalk citation
**Changed/Found:** The user confirmed that AL_0051 stays in the 15-session cohort; "drop al_0051" meant AL_0050, as implemented. The user also confirmed that Matveev et al. 2024 shows the imaging light does not activate the opsin, so the Methods citation stands as written.
**Why:** these closed two open items from the 2026-10-12/13 reviewer pass.
**Next:** the user re-places Fig 2 B–G, Fig 3 A–F and Fig 4 C/F in Illustrator; IACUC number; push draft → main.

### 2026-10-13 — STATS_TABLE: Fig 4G open- vs closed-loop rejection rows added
**Changed/Found:** `paper_stats_table.m` adds `4G_olcl_RR` / `_offshare` / `_RRfluct` from `f4_rr_denominator_check.mat` (kept sessions, one-sided signed-rank OL > CL). STATS_TABLE now has 65 rows. All three reproduce Results L193 exactly:
- RR 1.25 vs 0.72, V = 66, p = 4.9e-4, 11/11 sessions;
- offset share 35% vs 7%, V = 65, p = 9.8e-4, 10/11;
- fluctuation 0.66 vs 0.54, V = 63, p = 0.0024, 10/11.

**Why:** reviewer m18. L193 numbers had no table row.
**Next:** L63 dose slopes/R² still have no row (no saved output from `f2_slope_ci`). Fig 5 is descriptive by design, so it has no rows.

### 2026-10-13 — Two-pole model comparison moved from Discussion to Results
**Changed/Found:** the "two-pole held-out R² 0.81 vs 0.85 (Mouse 3 0.87 vs 0.85)" numbers now sit in `results.tex` after the model-order sentence. `discussion.tex` L9 refers back to Results.
**Why:** reviewer m14. New results should not first appear in the Discussion.
**Next:** none.

### 2026-10-13 — Fig 3F gets a y scale bar; Fig 3 panels A–E regenerated (1 mW bars now on disk)
**Changed/Found:** `utils/analysisPlots_combined.m` panel E (paper 3F, trial-RMSE half-violins) had no y scale at all. It now has a y-only "1% dF/F" bar (XLength 0), and the "Trial RMSE" label is raised to 0.74 so it clears the bar label. All five panels were regenerated with PAPER_FINAL from the m10 cache (`data/AL_0039ctrl04191.mat`) via `matlab -batch`. This also writes the restored "1 mW" bars on panels A/C to `figures_final`, closing the "panels still carry 0.2 mW" item.
**Why:** reviewer m19. The user chose a scale bar.
**Next:** re-place Fig 3 panels in Illustrator.

### 2026-10-13 — Fig 2C/2D CV panels re-rendered with global mouse labels (background batch)
**Changed/Found:** `matlab -batch` ran `load_experiments` and then `imp_tf_cv` with PAPER_FINAL, writing `tf_cv_2D_sidebar` and `tf_cv_single_AL_0033` at 02:54. The seeded results reproduced exactly: held-out R² 0.561 / 0.833 / 0.950 / 0.845, pooled 0.846 (shape 0.864).
**Why:** global numbering (see the entry below).
**Next:** 2B (`dose_response`) is re-rendering in a second batch.

### 2026-10-13 — Minor manuscript fixes: Fig 5 attribution softened; Gupta & Murphy year
**Changed/Found:**
- `results.tex` L221: "therefore attributable to feedback…" (n = 3) → "pattern is consistent with…".
- `refs.bib` Gupta2026: year 2026 → 2025 (eLife 14:RP105070, checked online). The key name is kept.

**Why:** reviewer m21/m23.
**Next:** none.

### 2026-10-13 — Methods: disturbance-predictor details and Fig 3 variance metric written from code
**Changed/Found:** `methods_rewrite.tex`:
- **Predictor:** the undefined "grid / catch windows / target-independent split" text was replaced with values from `ctrl_ols_spont.m` / `ctrl_ridge_path.m`:
  - a lattice of ~500 contralateral pixels, mask eroded 12 px;
  - a temporal 2/3 : 1/3 train/test split;
  - λ from logspace(−8, 1, 28) × mean diag(Gram), chosen by the catch-floor rule on 200 laser-off catch windows.
- **Variance metric:** "per-trial windowed variance" is now defined as the log mean squared deviation from the condition's trial average (matching the 3I caption), with inference over sessions and the same direction in every mouse.
- `results.tex` L108: "every session and in all four mice".

**Why:** reviewer m10/m11.
**Next:** none.

### 2026-10-13 — Global mouse numbering across the paper (user decision)
**Changed/Found:**
- `utils/imp_mouse_label.m` now uses fixed IDs: 1 = AL_0033, 2 = AL_0039, 3 = AL_0048, 4 = AL_0051, 5 = AL_0041, with a/b per session. It used to number by order of appearance, which made Fig 2 Mouse 1 = AL_0041 but Fig 4G Mouse 1 = AL_0033.
- Text: the Fig 2 labels were remapped (1a/1b → 5a/5b, 2 → 1, 3 unchanged) in results L51–70, methods L122–123/788–831 and discussion L9.
- The Fig 4G caption warning is replaced by "numbered as in Table cohort", and the cohort caption defines the numbering.
- Regenerated with PAPER_FINAL: `tf_tau_forest`, `tf_model_swap`.
- `tf_cv_*` (2C/2D) are re-rendering in a background `matlab -batch` job, because the CV refit takes over 30 min. `imp_response` (2B) is still to rerun.

**Why:** reviewer m17. The user chose one global numbering.
**Next:** confirm the background job wrote `tf_cv_*`; rerun `dose_response` with PAPER_FINAL; reassemble Fig 2 in Illustrator.

### 2026-10-13 — Methods: AL_0050 and the unspecified opsin-expression exclusion removed from the paper
**Changed/Found:** `methods_rewrite.tex` "Session and trial selection": the "Opsin expression" bullet (no method, no count) and the "Stimulation quality" (AL_0050) bullet are deleted. No other mention of AL_0050 is left in the body.
**Why:** reviewer m13. The user said not to mention AL_0050 in the paper. "drop al_0051" was read as a typo for AL_0050, and AL_0051 stays in the cohort; this was flagged to the user.
**Next:** the user confirms that AL_0051 stays.

### 2026-10-13 — Methods: stimulus waveform corrected to a 40 Hz sine (not 50 Hz) in early sessions
**Changed/Found:**
- The waveform sentence printed with an undefined actuator. It now says the controller writes one command per 28.6 ms sample, which sets the laser power for that sample.
- A few early sessions used a 40 Hz sine whose peak the controller set each sample. The old text said "AL_0033 … 50 Hz".
- The peak-power sentence was updated to match.

**Why:** reviewer m16; the facts are from the user.
**Next:** none.

### 2026-10-13 — Methods: imaging-light crosstalk claim cited to Matveev 2024
**Changed/Found:** "kept below levels that cause … direct opsin activation" (no evidence) → "same illumination as Matveev et al. 2024, used with the same opsin without detectable activation".
**Why:** reviewer m15; the user chose the citation.
**Next:** confirm that Matveev 2024 actually reports no blue-light activation of ChrimsonR.

### 2026-10-13 — Methods: husbandry cited to Matveev 2024; availability = deposit on acceptance
**Changed/Found:**
- Housing, light cycle, handling and water restriction are now cited to Matveev 2024. The IACUC number stays a FILL comment.
- The data/code availability statement no longer prints "URL" placeholders. It now says the material will be deposited in a public repository on acceptance.

**Why:** reviewer M1 and m4 (user choices).
**Next:** IACUC protocol number before submission.

### 2026-10-13 — Impulse protocol written from the session data
**Changed/Found:** `methods_rewrite.tex` "Impulse-response protocol": the "earlier version of the control system" paragraph and its FILL were replaced with measured values. These are:
- Pulse width from the Timeline light command (2 kHz): 28.5, 28.5, 23.0 and 27.5 ms.
- ITI medians from `imp.startTimes`: 5.77, 6.11, 5.74 and 9.80 s.
- Blue frame rate: 35.0–35.1 Hz.
- Logged `params.kernel` = 10.
- The readout uses the hemodynamically corrected movie, with the mean-image ΔF/F.

The text gives these as a single shared protocol with across-session ranges. "Amplitudes from 0 to 1.6 mW" became "nonzero amplitudes up to 1.6 mW", since amplitude 0 is synthetic.
**Why:** reviewer M11. The user said all impulse experiments had the same conditions and the text should not mention earlier or later versions.
**Next:** none.

### 2026-10-13 — Methods: second-opsin and feedback-sign language removed (user decision)
**Changed/Found:** `methods_rewrite.tex`:
- "AL_0048/AL_0051 additionally expressed a second, spectrally distinct opsin" is replaced with a neutral sentence: stimulated at 638/594 nm through an interneuron-expressed opsin, giving suppression as in the other mice.
- The σ feedback sign is removed: Eq. error is now e_t = y_t + R = y_t − y_ref, the preview error is e_k = y_k + r̃_k, and the subsection is renamed "Tracking error".
- "different opsins" → "stimulation wavelength".
- "Titers … in Table" → "Per-animal details" (the table has no titer column).

Alyx gives AL_0051's construct as "PHP S5E2 C1V1" (interneuron-driven). It is unconfirmed, so it is left as a FILL comment and not named in the body.
**Why:** reviewer M13. The user said not to mention AL_0048's excitatory second opsin anywhere.
**Next:** if wanted, name the AL_0048/AL_0051 inhibitory constructs once confirmed from injection records.

### 2026-10-13 — Methods tuning section limited to the S2 grid + auto-tune run; facts corrected from rig logs
**Changed/Found:** `methods_rewrite.tex` "Gain-grid sweep" and "Online gain search" now describe only:
- grid AL_0033 2025-03-05 (10 nodes, min (0.05, 0.10), Ĵ = 16.1);
- auto-tune AL_0033 2025-03-17 (136 trials, 9 iterations × 15 trials per candidate, online cost 16.6→15.1→12.3, end (0.068, 0.064)). These come from `input_params` run lengths and `Kdata`/`Kval`.

Other changes in the same file:
- Algorithm block: N = 15, I = 9 (was the code default 5/5).
- The contradictory "required Ĵ(K) ≤ Ĵ(0)" sentence is dropped.
- The AL_0034 row is removed from `tab:cohort`; the caption names the S2 sessions.
- "Lists every animal and session" is scoped down.

The old text had wrong end gains for AL_0034 e1: logged (0.10, 0.22), written as (0.20, 0.20). The AL_0033 12-19 run had a dead online cost (Kval ≡ 0), so it was a random walk, not a search.
**Why:** reviewer m2/m3. The user said Methods should describe only the grid search and auto-tuning presented in S2.
**Next:** none.

### 2026-10-13 — Readout box size does not affect the offline signal (checked against rig states.csv)
**Changed/Found:**
- **The question:** rig code (`rainier/StLab_Rainier/backup/Main_PID_serial.py`, `img[p-s:p+s]` with s = 5, logged as `kernel = 2*s = 10`; `experiment_core/base_controller.py` ROI_HALF = 5) suggests a 10×10 online box. The user says the csv kernel is a half-width. Offline, `getpixel_dFoF` uses ±kernel (21×21).
- **The test:** on AL_0039 2025-04-19, the box mean was rebuilt from the blue SVD (500 comps). ΔF/F used a trailing 1400-sample mean. The result was compared to `d.states`, whose nonzero span equals the V length exactly.
- **The result:** 10×10, 11×11 and 21×21 give r = 0.995 (lag 0), high-pass r = 0.876, and SD 3.00–3.02 vs the rig's 3.04. The boxes are indistinguishable.
- **Text:** `methods_rewrite.tex` keeps 10×10 and adds one sentence that the offline re-extraction reproduces the online signal (r = 0.995) independent of box size. The CHECK comment was replaced.

**Why:** reviewer m6 raised the kernel size. The user asked for the states.csv comparison and had previously found that the box doesn't change the data; this test confirms it.
**Next:** none. Not changing `getpixel_dFoF`.

### 2026-10-13 — Methods claims checked against code; six corrected (Closedloop_edit draft)
**Changed/Found:** in `methods_rewrite.tex`:
- **Motion exclusion:** removed "30 of 1190 excluded". `motThresh` is used only in `trial_state_mse.m` / `f4_lowfreq_examples.m`, neither of which is a manifest panel, and Fig 4D uses all 1190 trials. Methods now says no trial is excluded on motion.
- **Predictor bullet:** added the 15→13 predictor-availability bullet.
- **2G trial counts:** the "<8 trials" rule never fires; the minimum is 44 per session × amplitude, counted from STV.T.
- **Bootstrap:** the mouse→session→trial claim was replaced with the actual session→trial bootstrap (`imp_state_hboot`), with the caveat of 35 distinct draws.
- **Anti-windup:** windup is bounded by the 3 s reset window; the 5 V term clamps sit above u_max.
- **Welch:** the "Power spectra" subsection was removed. No figure shows a Welch spectrum, and every band power comes from the Hann periodogram.

In code, the stale offset-share comment in `f4_cl_reject_lmm.m:16` (47/73%) was corrected to the data values (38/59%), which match Methods.
**Why:** reviewer M9, m1, m7, m8, m9 and M14 items. Each was resolved from the code or data, not by judgement.
**Next:** kernel size. Logged `d.params.kernel = 10`; offline extraction uses ±10 (21×21). The rig's own interpretation still needs confirming.

### 2026-10-12 — Fig 4F retitled "Actual = Global + Local"
**Changed/Found:** `f4_contra_model.m`: the panel title changed from "Global predicts the counterfactual". Re-exported with PAPER_FINAL to `figures_final/panels/figure4/f4_agl.pdf` (R²_te = 0.75 unchanged).
**Why:** reviewer M7. A no-controller trial is never observed, so the old title overclaimed (user's choice).
**Next:** re-place 4F in the Illustrator Figure 4, together with 4C.

### 2026-10-12 — Manuscript framing: intro, abstract, 2G in Discussion, scope limitation (user-approved drafts)
**Changed/Found:**
- `introduction.tex` L44: single trials "scattered around [the model] by an amount that varied with … state, as ongoing activity did".
- `discussion.tex`:
  - 2G sentence added to "Disturbance rejection…";
  - a "Fifth" scope limitation added: n = 4 impulse sessions / 3 mice, inhibition only, one area, Local as a residual, Fig 5 n = 3.
- `main.tex` abstract: "inhibitory … 15 sessions from 4 mice"; "stationary" → "approximately linear, time-invariant".
- `results.tex` L13 "stationary" → "within each session … time-invariant".
- The L109 gains non-sequitur is replaced by a pointer to Table gains.

The PDF is now 42 pp, clean.
**Why:** reviewer M12 and the L109 nit. The new 2G framing had made the intro and the "stationary" wording contradict Results (cross-session R² 0.69 shows the dynamics are session-specific).
**Next:** none.

### 2026-10-12 — Manuscript: per-figure signal stated; hemodynamic limitation added (user decision)
**Changed/Found:** The code shows two different signals:
- Fig 2 uses hemodynamic-corrected SVDs (`loadUVt_hemo`).
- Figs 3–5 use the uncorrected blue channel: `getpixel_dFoF`'s SVD branch always loads blue-only V (the "corrected file not found" print is unconditional), and `load_bilateral` routes through it.

Text changes:
- `methods_rewrite.tex` FILL at line 208 is replaced by that statement.
- `discussion.tex` gets a "Fourth" limitation: the controller and closed-loop analyses use the uncorrected signal, so 2–4 Hz state power may be partly vascular. The corrected impulse 2G still shows abs δ in 4/4 sessions.
- "Three factors" becomes "Four".

**Why:** reviewer M10. This is the most likely referee question on the 2–4 Hz result. The user chose "state it + limitation", with no new control analysis.
**Next:** none, unless a referee asks for the corrected-signal Fig 4 control.

### 2026-10-12 — Fig 2G inference switched to per-session slopes (user decision)
**Changed/Found:**
- New `utils/stv_sess_slopes.m`: within-session OLS slope of |z| on state (z-scored per session), then a one-sample t-test across sessions with df = 3.
- `imp_state_trialvar.m` stores the result as `R(k).SL`. The intercept-only LME is kept for reference only.
- `imp_state_trialvar_fig.m`: stars and fractions now come from SL, via the local `stvf_infer`.
- `paper_stats_table.m`: the `2G_*_lmm` rows are replaced by `2G_*_slope`. The pooled-trial Spearman rows are kept as effect sizes with no p.
- The panel was rebuilt with PAPER_FINAL, and `data/fig2g_state_stats.mat` was re-saved.

Results by state:

| State | Old LME t(3) | Old p | Per-session t(3) | New p | Sessions agreeing |
|---|---|---|---|---|---|
| Motion | −7.33 | 0.0052 | −3.90 | 0.030 | 4/4 |
| Abs δ | 21.0 | 2.4e-4 | 14.3 | 7.4e-4 | 4/4 |
| Rel δ | 3.57 | 0.038 | 1.81 | 0.17 (n.s.) | 3/4 |

Only abs δ clears the 3-test Bonferroni threshold. Ratios and CIs are unchanged. As a check, a full random-slope LME gives p = 0.16, 0.038 and 0.28. In `results.tex`, the L76 paragraph and the 2G caption stars were rewritten. In `methods_rewrite.tex`, both 2G inference passages were rewritten.
**Why:** the user thought the test was already per-session, but the code used `(1|sess)` with a trial-based SE. The Methods simulation shows that is anti-conservative (FPR 0.115–0.645), and the reviewer flagged it as M3.
**Next:** Illustrator re-place of 2G in Figure 2. The rel δ "candidate power-independent state" framing at L78 still stands, but rel δ no longer shows an impulse effect.

### 2026-10-12 — Fig 4 contra→ipsi R² in text updated to the ridge test value (0.75)
**Changed/Found:** `results.tex` L183. Changed "R² = 0.85 OL / 0.89 CL" to "R² = 0.75 representative session (Fig 4F), median 0.76, range 0.44–0.98 over 13 sessions", read from the `R2_te` field of `controller-analysis/data/ctrl_ols_ol_stimblind_ridge_*.mat`.
**Why:** NUMBERS.md §5.4 had flagged a three-way R² conflict. The panel's 0.75 is the current ridge predictor; 0.85/0.89 were stale.
**Next:** NUMBERS.md §5.4 L151 "0.85 OL / 0.78 CL" reconstruction R² and the nested nulls are still unverified.

### 2026-10-12 — Fig 4C bar/text mismatch traced to stale Illustrator assembly
**Changed/Found:** the locked panel `figures_final/panels/figure4/f4_decomp_unique_sep.pdf` (session-level, 2026-10-11) matches the text (0.53→0.03, 0.05→0.03, 0.11/0.11). The assembled `Figure4.pdf` still holds the old pooled 4C ("n=613").
**Why:** reviewer M2 flagged the mismatch between the text and the bars.
**Next:** the user re-places 4C (and checks the 4D stars) in Illustrator, then copies Figure4.pdf to `Closedloop_edit/images`.

### 2026-10-12 — Fig 3H pre/post RMSE ratio now tested; 3H/3I labels fixed
**Changed/Found:**
- `variance_mse.m` (G2r block): adds a signed-rank test on the log OL/CL RMSE ratio per window and saves `data/fig3h_rmse_ratio_signrank.mat`. Values were computed from the 15 caches with identical windows:
  - pre: 0.99, V = 56, p = 0.85
  - 0–1 s: 1.14, V = 120, p = 6.1e-5
  - 1–3 s: 1.39, V = 120, p = 6.1e-5
  - post: 1.01, V = 66, p = 0.76
- `paper_stats_table.m`: adds rows `3H_*` (RMSE ratio). The variance-ratio rows are relabelled `3I_*`, confirmed against the assembled Figure3.pdf. STATS_TABLE now has 62 rows.
- PAPER.md registry: 3H/3I rows swapped.
- `results.tex` L108: now quotes these numbers.

**Why:** reviewer M5. The "above one during stimulation but not before or after" claim had no test, and STATS_TABLE called the variance-ratio rows 3H.
**Next:** none.

### 2026-10-12 — Mechanical manuscript fixes from the reviewer pass (Closedloop_edit draft)
**Changed/Found:**
- `methods_rewrite.tex`:
  - removed the 15 printing `[RIG]` tags;
  - "Validation blocks were 100 trials" → "30–200 (Table gains)";
  - steady-state window stated for all Fig 4 state analyses (D, G, table), matching `f4_row2_pool.m:12`; the lead-in is now described as 3 s;
  - the 1 s boundary is justified against the dip and rebound τ;
  - 2G window is "18 samples, 0–0.49 s";
  - unused pooled rank-sum replaced with a note that the RR tests are one-sided.
- `discussion.tex`:
  - K_p e_t sign;
  - the identification sentence no longer contradicts the LTI fits.
- `results.tex`:
  - 2G caption no longer defines the L2 error circularly;
  - dip-τ sentence names its mice;
  - abs δ 1–4 vs 2–4 Hz note added.

The PDF builds (41 pp, no undefined refs).
**Why:** these were the reviewer items needing no judgement call. Discussion "13 sessions in 2025" was checked and is correct (15 = 13 + 2 from 2026), and the Fig 4G "all eleven medians < 1" claim is confirmed (0.34–0.93).
**Next:** the items needing user input are taken one by one.

### 2026-10-12 — Final reviewer pass: 14 MAJOR / 23 MINOR issues found (no edits yet)
**Changed/Found:** `paper-writing/REVIEW_2026-10-12.md`. Three read-only reviewers were merged into one list. Key findings:
- 15 `[RIG]` tags and "URL" placeholders print in the Methods PDF.
- The Fig 4C text numbers don't match the bars, and 4C has no STATS_TABLE rows.
- The Fig 2G LMM has no random state slope, which is anti-conservative per the paper's own simulation (FPR 0.115–0.645).
- Methods states a 0–3 s window, but `f4_row2_pool.m:12` scores Fig 4D on [+1, +3] s.
- The STATS_TABLE `3H_pre/post` rows are actually Fig 3I.
- Methods says validation blocks were "100 trials"; `tab:gains` gives 30–200.

**Why:** the user asked for a final reviewer pass before finishing the paper. Items that conflict with locked decisions were excluded: the 2G heading, Fig 3 "1 mW", naming the representative session, and S5.
**Next:** the user picks which fixes to apply. M3 (2G inference) weakens the p-values and needs the user's sign-off.

### 2026-10-12 — S5B: prediction phase drawn solid magenta instead of dashed purple
**Changed/Found:** `controller-analysis/ctrl_mpc_direct_panels.m` — the predicted signal, the planned laser, the first-move dot and the "predict" / "plan" / "apply 1st" labels now use C.p = [0.85 0.25 0.55], solid instead of dashed.
- Light purple stays reserved for perfect MPC (panels C–F).
- The jagged look was mostly dash gaps on a step plot; the plan itself is smooth.
- The past applied laser is genuinely jagged: with λ = 0.1 the controller re-plans every frame and applies only the first move.
- Re-exported to figures_final.
- Manuscript caption B now says "magenta" (`draft`, not pushed).
**Why:** user: "why does the planned input look jagged; make it a different colour for the predict phase instead of dashed".
**Next:** user re-places panel B and re-exports S5.

### 2026-10-12 — Fig 3 laser scale bar back to "1 mW" (revert of the 10-11 V/3 relabel for Fig 3)
**Changed:** `utils/analysisPlots_combined.m`: reverse-applied the Fig 3 hunks of 160e8d8. Panel A is back to OL laser gain 5, a [6 8] bar and the "1 mW" label; panel C (`ax_E`) is back to YLength 2 and "1 mW". A comment now explains why.
**Why:** User: on the closed-loop controller trials the rig modifies the stim voltage, so "1 mW" is correct for Fig 3. The mW = V/3 correction holds only for the impulse experiments (dose_response, imp_tf_cv, imp_spatial_panels), which have no such modification. The assembled Figure3.pdf already shows 1 mW and is correct. My earlier audit flag ("stale 1 mW") was wrong.
**Next:** The panel files in `figures_final/panels/figure3/` still carry the 0.2 mW labels from 10-11 and need a regen with PAPER_FINAL on when the controller data is loaded. Assembly is unaffected. Ask the user whether `controller-analysis/ctrl_mpc_direct_panels.m` (S5, controller-session voltages), which got the same V/3 relabel on 10-11 ("0.5 mW = 1.5 V"), should also be reverted.

### 2026-10-12 — S5B schematic: "now" moved to 2.17 s (mid-excursion), no-stim prediction removed, window label "predict"
**Changed/Found:**
- `mpc_direct.py`: new `MPCD_SNAP_ALT` option saves the MPC prediction and plan at several candidate frames on the snapshot trial (`data/mpc_direct_snapalt_<sess>.mat`). Frames 70–78 on trial 79 were compared:
  - frame 76 (2.17 s) sits mid-rise of the 2.1–2.25 s excursion, and the prediction shows the MPC bringing it back to target;
  - frame 77 (2.20 s) is at the peak, the alternative.
  - Reran with `MPCD_SNAP=79,76`; the numbers are unchanged (0.652, 108/108).
- `ctrl_mpc_direct_panels.m`:
  - removed the laser-off "no stim" prediction and its laser line;
  - window label "predict 1 s" → "predict";
  - removed the line label;
  - the x-range now extends to the horizon end (3.17 s), so the full window shows past the stim window.
  - Re-exported to figures_final.
- Manuscript `draft` caption B is updated to match (committed; not pushed).
**Why:** user: "remove the no stim; move the now window slightly forward to capture a particular feature; on predict window don't say 1 s".
**Next:** user re-places panel B in Illustrator and re-exports S5. Push main once draft is ready.

### 2026-10-12 — Fig 3 audit items 1–2: stale scale bars and the representative session
**Found:**
- **(1)** The panel files already say "0.2 mW": `figures_final/panels/figure3/panel_A.png` and `panel_C.png` were exported 10-11 11:52. The "1 mW" survives only in the Illustrator assembly: `Figure3.ai` was saved 10-10 and `Figure3.pdf` exported 10-11 17:57 (byte-identical to `Closedloop_edit/images/Figure3.pdf`). Nothing needs regenerating; panels A and C must be re-placed in Illustrator and Figure3.pdf re-exported.
- **(2)** The representative session is m10 = AL_0039 2025-04-19 e1 (`load_sessions.m` `selField = 10`), and its gains are Kr 0.1, Kp 0.07, Ki 0.1. The Results sentence (L109) is correct, as an archived entry already established.

**Changed:** Corrected three stale labels:
- `NUMBERS.md:181` row read "AL_0033 2025-02-26";
- `pyFigure3/README.md:45` example read AL_0033ctrl04191;
- `pyFigure3/figure3.py:8` docstring example read AL_0033ctrl02242.

All three now point to AL_0039ctrl04191.
**Why:** Fig 3 audit item 2. Three sources disagreed on which session Fig 3A–D/F shows.
**Next:** User: re-place panel_A/panel_C in Figure3.ai and re-export. Optional: name the session in the Fig 3 caption ("Mouse 2" in the Fig 4G numbering).

### 2026-10-12 — Manuscript Fig 2B–F: Results/Methods/Discussion made consistent (Closedloop_edit 8db98b1, draft, not pushed)
**Changed:** `results.tex`, `methods_rewrite.tex`, `discussion.tex` via `apply_ms_1012g.py` (14 edits). The three-lens verify (wf_42b24b7c-583) found the problems. Every number was re-checked in MATLAB against `imp_tf_fits.mat` (exact modal decomposition, residual < 2e-15) and the logs (cvfree, cv2p_new, bootsplit).
- Mouse 3's slowest pole (τ = 1768 s) contributes **+0.003 against a trough of −1.777 (< 0.2%)**. Dropping it changes R² only from 0.9936 to 0.9932.
  - It does NOT carry the offset; my earlier draft said it did.
  - The seeded fit's gain comes from the starting point. Methods now says this and does not treat that pole as a timescale.
  - Results and caption F name Mouse 3's slowest substantive mode: 0.50 s, at the window edge, so its 0.5 s triangle sits in the same place.
- Dip: "tightly reproducible" became "similar in three of four sessions". Values: 0.106–0.114 s (two of them from Mouse 1), 0.14 s in Mouse 3, median 0.113 s.
  - It is order-sensitive: the only other model within 0.005 R² gives 0.117 s instead of 0.106 s (Mouse 1a) and 0.154 s instead of 0.114 s (Mouse 2). Mice 1b and 3 have no such model.
- The modes overlap. In Mice 1b and 2 the slow mode supplies 60–68% of the trough. In Mouse 1a the slowest pole is a near-integrator giving 6% sustained suppression. Methods now says this.
  - The 2D claim "share the dip, diverge in the rebound" holds in the data: across-session SD of the peak-normalized responses is 0.066 up to the trough and 0.226 after it. Only the causal "Accordingly" was dropped.
- Held-out CV:
  - "held within each session" became per-session medians, 0.56 (Mouse 1a, IQR 0.09–0.79) to 0.95.
  - Methods now states that failed folds are excluded (10% in Mouse 3, ≤ 2% elsewhere) and how the pooled value is formed.
- Swap (recomputed, matches): the diagonal is labelled in-sample (0.99); cross-session mean 0.69, range 0.12–0.97.
- Bootstrap: the beyond-window share is now given per session (39 / 72 / 3 / 100%), with tauMax = 18 samples = 0.51 s and failed refits counted as not beyond. The unrun "matched-range refit" sentence was deleted.
- Discussion: "more than one pole pair" was false for Mice 1a and 3, so it now reads "more than two poles". It also says the 2-pole model did slightly better in Mouse 3 (0.87 vs 0.85). "Conserved dip / rebound" became "shared fast dip / slower modes that differ".
- Smaller fixes:
  - The Methods nominal model is now "an earlier two-pole fit" (it was the Fig-2 fits, which have 3–5 poles), and Methods adds that the per-session fits were not used for the design.
  - The 2A gray band is −0.2 to 0.5 s (trace_overlay.m L21), not the fit window.
  - The cohort caption now lists the impulse sessions, including AL_0048 2026-07-15.
- Staging: the parallel session's uncommitted 2G rewrite sits in the same files. I staged HEAD plus my passes 1012d–g, replayed into the index with `git update-index`. Their edits stay unstaged.
- Compiles clean; the one overfull box is pre-existing.

**Why:** The user asked to "apply the edits on manuscript. make things consistent across results and methods" after the seeded M3 fit and the leak-free CV.
**Next:**
- The assembled `images/Figure2.pdf` (14:43) predates the seeded refit, the leak-free CV and the 2F re-mirror. The user must re-assemble 2B–2F from figures_final in Illustrator.
- Optional: change the 2F rule to drop negligible-amplitude modes (< 1% of the response) before ranking. Mouse 3 would then plot as a 0.50 s circle; this needs a bootstrap rerun for the Mouse 3 share.
- Claim softenings ("similar", "shared") need the user's review.

### 2026-10-12 — 2F tau forest re-mirrored to figures_final (file was locked earlier)
**Changed:** `imp_tf_figs` (FIG_PANELS {'tau'}, FIG_SRC = patched `imp_tf_fits.mat`, PAPER_FINAL on) → `figures_final/panels/figure2/tf_tau_forest.pdf/.png` at 3.21 × 3.28 cm.
- M3 dip 0.1435 s; median line 0.113 s.
- Triangles at 0.5 s for M1a, M1b and M3; M2 rebound 0.268 s.

**Why:** the user closed the PDF in Illustrator.
**Next:** the user re-places 2B, 2C, 2D, 2E, 2F and 2G in Illustrator.

### 2026-10-12 — Supp state rasters parked as a candidate beside S1–S5
**Changed:** I copied `panels/supplementary/supp_state_raster.png` to `paper/figures_final/S_state_raster.png`, next to the assembled S1–S5. `PAPER.md` marks the row CANDIDATE. It is not added to `supplementary.tex` or to `Closedloop_edit/images`. The MANIFEST line is kept, so the producer keeps refreshing the panel copy.
**Why:** User: "put it in supplementary figures folder, I'll decide if we put it in later".
**Next:** If it is approved, add a supplementary.tex float and caption and cite it from the 2G Results paragraph. If it is rejected, delete the MANIFEST line and run collect_final_panels.

### 2026-10-12 — CORRECTION: Mouse 3's slow dip is NOT a hemo filter-delay artefact; a recompute is unlikely to move it to ~0.11 s
**Found:**
- Read-only workflow wf_9882df74-940: 1 builder plus 3 skeptics (code-fidelity: refutes, inference: inconclusive, numbers: supports). Files in `scratchpad/m3dip/`.
- Plus a decisive follow-up, `m3dip_build_pf.m`.

1. **Sessions 1–3, old → new dip shift** (0.148 → 0.106 and 0.150 → 0.114 s):
   - This is the old correction's one-pass 9–14 Hz heartbeat band-stop, which delays 1–5 Hz by 13–21 ms (group delay 13.0 / 13.8 / 15.2 / 17.6 / 21.4 ms).
   - The lab's fixed hemoCorrect (server `Code/dataChangeLog/2026-10_hemoCorrect_recompute/EXPLAINER.md`) runs that band-stop forwards and backwards.
   - Old corr plus one backward pass lines up with new to ±0.25 ms, and gives dip τ 0.116 / 0.115 s in M1a / M2. M1b is ambiguous.
   - So the shift is not the hemodynamic over-subtraction.
2. **One-pass raw blue (loadUVt's `detrendAndFilt`) is NOT a calibrated proxy.** It lags new by 13.5–15 ms. My partial note above ("raw blue tracks NEW in M1a; M3 raw-blue pair 0.102 s") was WRONG, for two reasons:
   - M1a at a fixed order gives 0.150, which matches OLD;
   - the M3 raw-blue variants were built about 1 frame off the paper's onset frames (blue stamps are 21.2 ms earlier than the corr stamps the L152 rule uses).
3. **Decisive check on the paper's OWN onset frames** (L152 rule on the corr stamps, applied to blue V):
   - M3's May-2021 corr vs zero-phase raw blue: lag **+0.75 ms**, R² 0.997, trough on the same frame (114 ms);
   - one-pass raw blue: +14 ms.
   - So **M3's corr carries no net delay.** The 0.14 s dip is not the artefact that slowed M1a and M2.
4. **M3's dip τ is fit-fragile:**
   - every unseeded candidate on its corr is at R²h ≤ 0.938;
   - zero-phase raw blue on the paper frames gives 6p5z0d with a 0.177 s pair (before the cap below);
   - delay-removed variants reach R²h ≤ 0.957.
5. **The TF dip τ moves 0.025–0.04 s within a session** with model order or small non-timing shape changes (M1a raw blue 0.119 vs 0.150; M1b 0.080 vs 0.107). The "conserved dip, 0.11 s in 3 of 4" claim is therefore less robust than it reads.
6. **Implication:** anything still on an Apr/May-2021 corr carries that 13–21 ms delay at 1–5 Hz. That includes Fig 4E–G and the MPC supplement, which were kept on the OLD correction this morning.

**Why:** the user asked whether the Mouse 3 fit should repair the dip toward 0.1 s.
**Next:**
- The TASKS item for the local M3 hemo recompute stays (the user's decision). Its stated reason is now consistency (one pipeline version for all sessions), with no expectation that M3's dip moves.
- Tell the user about point 6 for Fig 4E–G and MPC, and about point 5 for the Discussion's "conserved dip".

### 2026-10-12 — Fig 2D CV rerun leak-free: Mouse 3 0.845, pooled 0.846 → manuscript back to 0.85; seeded class capped
**Found:** `scratchpad/cvfree_batch.m` reran `imp_tf_cv` (PAPER_FINAL on) with the leak-free engine, with Mouse 3 `seedAlt` [4 2 0].
- Mouse 3: **0.845** [0.675, 0.925], 10% folds failed. My check script gave 0.868 / 7%; the engine also screens the alt fit with `tf_ok`.
- Mice 1a, 1b and 2 are unchanged: 0.561 / 0.833 / 0.950.
- **Pooled 0.846** (shape 0.864). So the 0.898 was entirely the warm-start leak.
- `tf_cv_2D_sidebar` and `tf_cv_single_AL_0033` were re-mirrored to figures_final.

**Changed:**
- `results.tex` pooled CV 0.90 → **0.85**.
- `discussion.tex` L9 restored to the committed sentence (0.81 against 0.85, "nearly as well"); the file is unchanged vs HEAD.
- `methods_rewrite.tex`: held-out refits rebuild the seed from the training trials; bootstrap refits start from the selected model.
- `utils/imp_tf_fit_session.m`:
  - the alt sweep is capped at maxPoles−1, so a seeded candidate can never exceed the stated 1–5 poles / 0–4 zeros (the zero-phase test above produced 6p5z);
  - Mouse 3 is unchanged (5p4z0d, R²h 0.9936, AIC −6.058, same τ, seedAlt [4 2 0]);
  - the log message is updated.
- `impulse-analysis/data/imp_tf_fits.mat` is patched with `seedAlt` / `seedPre_s` so a CV-only run from file works. M3 [4 2 0] is what the engine now computes; the others are [].

**Why:** a held-out score must not use the held-out data. The seed must stay in the swept model class.
**Next:** `tf_tau_forest.pdf` in figures_final is still LOCKED (open in Illustrator). Close it, then run `imp_tf_figs` with PAPER_FINAL on.

### 2026-10-12 — Supp state rasters: 8 cm wide, short centred colour key
**Changed:** `imp_state_raster_supp.m`:
- `paperFig(8, 14)` (was 11 cm wide);
- all x-labels are "Time (s)" and the title is shortened ("Trials sorted by pre-stimulus state (n = 1516)"), because they collided at 8 cm;
- the colour key is no longer a tile-spanning bar. It is a short (34 % width), hairline-thin key hung off a hidden helper axes below the grid, with ticks −3 / 0 / +3, no box, and the label underneath;
- `tl.OuterPosition` leaves a strip for it.
- Re-exported to `figures_final` at 7.41 × 13.84 cm.

**Why:** The user asked to squish x further, then for a shorter, more stylish colour bar.
**Next:** Caption and supplementary.tex float; the caption must say the right column's time axis is time within the −1.51 to −1.03 s control window.

### 2026-10-12 — 2F bootstrap: failed vs beyond-window split; caption "43–73%" → "39–100%"
**Found:** `scratchpad/bootsplit_batch.m` replays the paper fits: rng(3), same opts, same session order. All four sessions are identical to the 19:20 run (τ, tauBootReject).

| Session | Beyond window | Failed |
|---|---|---|
| M1a | 38.7% | 2.3% |
| M1b | 72.3% | 0.3% |
| M2 | 2.7% | 0% |
| M3 | 100% | 0% |

The old `tauBootReject` (41 / 73 / 3 / 100%) counted failed refits as "beyond". M3 is 100% because its slowest mode is the offset pole by construction.
**Changed:**
- `Closedloop_edit/results.tex` 2F caption: "In three of four sessions, 39--100\%".
- `utils/imp_tf_fit_session.m`: the bootstrap log lines now print the beyond-window and failed shares separately (the old message called the combined share "tau > window").

**Why:** the caption reports the beyond-window share only.
**Next:** none for 2F. The Methods sentence ("fraction whose slowest τ exceeded the 0.5 s fit window") is now accurate.

### 2026-10-12 — Supp state rasters: x squished instead (11 × 14 cm); y squish reverted
**Changed:** `imp_state_raster_supp.m`:
- `paperFig(11, 14)`: width 17 → 11 cm; the height is back to 14 cm, which reverts the previous entry's 10 cm.
- The two-line y-labels are restored.
- Column titles are shortened to "Activity / Deviation / No-stim control" and the control x-label to "Time in window (s)", because the long titles collided at 11 cm.
- Re-exported to `figures_final` at 10.30 × 13.61 cm.

**Why:** The user clarified that they meant squishing the x axis, not the y axis.
**Next:** The caption must define "Deviation" (from the amplitude mean) and the control window (−1.51 to −1.03 s).

### 2026-10-12 — Supp state rasters: figure squished to 10 cm tall, single-line y labels
**Changed:** `imp_state_raster_supp.m`:
- the figure is now `paperFig(17, 10)` (was 14 cm tall);
- the y-labels are just the state name: "trials sorted by state" overlapped between rows at the new height, and the caption will say it instead.
- Re-exported to `figures_final` at 15.89 × 9.62 cm.

**Why:** The user asked to squish the y axis so the rasters look less blocky.
**Next:** The caption must say the rows are trials sorted by state.

### 2026-10-12 — Supp state rasters: Q4 on top, Q1 at the bottom
**Changed:** `imp_state_raster_supp.m` now sets the axes to `'YDir','normal'`. Same sort, so row 1 (the lowest state) is drawn at the bottom. Re-exported `figures_final/panels/supplementary/supp_state_raster.png` (PAPER_FINAL).
**Why:** The user asked for the order reversed: Q1 below, Q4 on top.
**Next:** none.

### 2026-10-12 — Found + fixed: warm-starting Mouse 3's CV refits from the full-data model inflated its held-out R²
**Found:** `scratchpad/m3cv_leakfree.m` uses the same 100 splits × 2 as the paper CV (rng 7).
- Warm start from the full-data seeded model, as in the 19:39 paper CV: median **0.953** [0.918, 0.973], 0% folds failed. It reproduces the paper's 0.957 to within 0.004.
- Seed rebuilt from each training half alone: the alt fit of (h − m) at the full-data alt order 4p2z0d, plus that half's own offset pole, refit. Median **0.868** [0.717, 0.942], 7% folds failed.
- So the warm start let the held-out half choose the basin, which inflated Mouse 3 by ~0.09 and the pooled median from ~0.87 to 0.898.

**Changed:**
- `utils/imp_tf_fit_session.m`:
  - stores `T.seedAlt` [np nz nd] and `T.seedPre_s`;
  - LOAO rebuilds the seed from the training amplitudes (new `local_fit_seeded`);
  - bootstrap and per-amp refits keep the warm start, since they estimate uncertainty, not prediction.
- `utils/imp_tf_cv_session.m`:
  - the warm start from T.sys is removed;
  - seeded fits rebuild the seed per training half (`local_build_h` now also returns that half's pre-onset mean);
  - a seeded T without `seedAlt` skips CV loudly, so it never leaks silently.

**Why:** a held-out score must not depend on the held-out data. The order is still chosen once on all trials, which Methods already says.
**Next:**
- `scratchpad/cvfree_batch.m` reruns `imp_tf_cv` with Mouse 3's `seedAlt` patched to [4 2 0] (same sweep, same data).
- Update the 2D panel, the pooled median (0.90 → new), the Discussion 2-pole comparison, and the Methods sentence ("held-out refits rebuilt the seed from the training half").


<!-- older entries → RESEARCH_archive_2026H2.md (then RESEARCH_archive_2026H1.md) -->
