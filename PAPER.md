# Paper TODO List

---

## NOTE
- large deviation in impulse prediction never have heavy motion energy / motion affected dynamics produce predictable impulse responses


## Scientific Claims to Fix (require analysis before editing)

> ⚠ **The live results file is `results.tex`** — the `results_edit.tex` name was retired. Line numbers below
> predate that rename and are indicative only; grep for the claim text, not the line.

These claims have identified problems and must be revisited before submission.

- [ ] **Linearity claim too broad** (`results.tex`, linearity paragraph): The paper tests linearity using peak ΔF/F vs amplitude only. Wording was softened to "well approximated by a linear relationship" (2026-06-29), but the *range* over which proportionality holds is still unstated. **Now answerable:** `imp_tf_xsess.m` computes `gRatio = gFree/uA`, flat under LTI and falling where the response compresses — the AL_0033 Local dip already turns over above 3.7 V (−1.68 → −1.51 → −1.35). Replace "approximately linear" with a stated amplitude bound once that runs.

- [ ] **Step-response internal tension** (`results.tex` step paragraph, `discussion.tex` L13): Text says "remained within a bounded set... consistent with marginally stable oscillatory dynamics" but the LTI claim implies convergence to steady state. Rewritten 2026-06-29 with the integral-term motivation, but it still does **not** explicitly state that the 3 s window is too short to observe steady state. Confirm whether that caveat is wanted; one sentence if so.

- [x] **Variance-convergence paragraph** — CLOSED 2026-06-29. Now shows per-trial mean stationarity, not just shrinking variance (`results.tex`).

- [x] **"Stimulation onset did not affect variance" claim** — CLOSED 2026-06-29. Rewritten with the measured slopes: post-onset −0.57 ± 0.24 (ΔF/F)²/s vs near-zero pre-onset −0.04 ± 0.14 (n = 13 OL sessions); CL reduces variance further and more consistently.

- [ ] **"Three independent sessions" for linearity** (`results.tex`): n=3 is low given that Fig. 3 now uses **15** sessions. n=3 is stated; the **slope ± CI is still missing** and is blocked on `dose_response.m` emitting fit CIs (do not fabricate). ⚠ The 3 impulse sessions come from **2 mice** (AL_0041 e1/e2 are the same animal) — say so.

---

## Manuscript corrections (Closedloop_edit)

> Closed items retired 2026-08-10 — the full list of what was fixed lives in RESEARCH.md / TASKS.md ✅.
> Only OPEN items remain below. **`results_edit.tex` is retired → `results.tex`.**

### results.tex
- [x] 2026-06-29 — All typo/ref/`\aditya{}` items closed; Kp/Ki/Kr placeholders filled (Kr = 0.1, Kp = 0.07, Ki = 0.1); broken cross-refs resolved grep-clean.
- [ ] Three content `\todo` gaps remain: §pre-stim brain state, §low-freq spectral attribution, §contra→ipsi prediction — all blocked on analysis, see TASKS 🔴.
- [ ] **Fig 3 preamble says "13 sessions across two mice"** — now **15 sessions across four mice** (AL_0048/AL_0051 added as m14/m15, 2026-07-30). Update wherever the cohort is stated.

### discussion.tex
- [x] 2026-06-29 — All typo/incomplete-sentence items closed.

### main.tex
- [x] 2026-06-29 — `\input{introduction}` uncommented.
- [ ] L62–67: Fill in real author names and department affiliations — **blocked on AL**.

### methods_edit.tex
- [x] 2026-06-29 — Label-format items closed; §gain_opt written with `fig:cost_landscape`.
- [ ] Add the **disturbance-rejection metric** paragraph — ⚠ **in energy-ratio units** `‖y_actual‖²/‖y_disturbance‖²` (1 = no work, <1 = controller gain), NOT ρ (Nick 2026-07-28). **ON AL APPROVAL.**
- [ ] Add `\label{sec:disturbance}` so the low-freq `\todo` ref resolves; delete orphan `methods.tex` / `introduction_temp.tex`.
- [ ] Add Chrimson spatial-spread citation (Nuo Li / Svoboda) — needs the exact paper from AL, not in `refs.bib`.
- [ ] State the **AL_0048 readout caveat** if that session backs any local-effect or actuator-TF claim: its inhibitory readout sits ~2.6 mm from the illumination, so its impulse response is that of a *connected* region, unlike AL_0033/AL_0041 where site and spot coincide.
- [ ] Confirm **AL_0034** is introduced at first mention (it appears only in the tuning methods figure; the session cohort names AL_0033/AL_0039/AL_0048/AL_0051).

---

## Figure Registry

---

### Paper story (figure-level) — updated 2026-07-29
- **Fig 1 — System architecture.** Widefield + opto interface, SVD readout, control-loop schematic.
- **Fig 2 — System properties.** Impulse response + step response with **their LTI (TF) fits**; state dependence on the **raw average trial**; state dependence of the **residual stim only activity**.
- **Fig 3 — Controller results.** Closed-loop vs open-loop (single-session example + cross-session summary).
- **Fig 4 — Controller state dependence.** Three blocks, in order: (1) **trial-average state dependence** — pre-stim state (contra-derived Global level) → true trial outcome, OL steep vs CL flat (`ctrl_state_dependence.m`); (2) **error-contribution model** — per-trial RMSE regressed on **initial deviation**, **motion**, **relative δ power** (`cl_mse_factors.m` / `cl_rmse_factor_windows.m`); (3) **residual-based state dependence** — disturbance rejection ρ = ‖A−ref‖/‖G‖ vs motion & δ quartiles (`internal_model_principle.m` `[IMP-STATE-QUARTILE]`).
- **Fig 5 — Feedforward / preview model.** Single-session results on **s3** (dark-screen session) + **combined stats across s1/s2/s3** (total RMSE, total variance, phase lag).

> Moves vs prior plan: the **step LTI fit** (`ol_tf_trial_avg.pdf`, was panel 3K) moves to **Fig 2** to sit with the impulse TF fit. **Fig 5** primary session flips **s2 → s3** (the 2026-07-21 "s2 primary" note predates s3) and adds the 3 across-session panels from `sine_ff_across_sessions.m`.

---

### Paper panels in use
Panels that appear in Figure1–5.pdf. **Primary uniformity table — update size/format here whenever a panel changes.**
Figure total width = 17 cm. Font = 6 pt bold. Line widths: 1.5 pt mean, 1.2 pt fit, 0.4 pt individual trials.

| Panel | Fig | Source PDF | Size (cm W×H) | Format | Shading | Status |
|-------|-----|-----------|--------------|--------|---------|--------|
| 1A | Fig1 | paper/images/wfpath.pdf | — | — | — | external image |
| 1B | Fig1 | paper/images/schematic_optoephyswf (1).pdf | — | — | — | external image |
| 1C | Fig1 | paper/images/figure1/svd_frame_AL_0039_2025-04-19.pdf | — | vector | — | pending size |
| 1D | Fig1 | *(interface diagram — illustrator)* | — | — | — | external |
| 1E | Fig1 | *(control system — illustrator)* | — | — | — | external |
| 1F | Fig1 | *(latency image)* | — | — | — | pending |
| 2A | Fig2 | paper/images/figure2/imp_single_AL_0033_2025-01-29_en1.pdf | 5 × 4 | vector | ±1 SD | trace_overlay.m — ±1 SD ribbon added 2026-07-16 (subset lowest+highest amp; faint fill α=0.08 + envelope outlines) |
| 2B | Fig2 | paper/images/figure2/imp_response.pdf | 5 × 4 | vector | — | dose_response.m |
| 2C | Fig2 | paper/images/figure2/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf | 6 × 4 | vector | ±std | done — **single session**; superseded by 2C-i/2C-ii below once those are cut |
| 2C-i | Fig2 | *(pending — `tfx_lti_across_sessions.png` exists, not yet a panel)* | 6 × 4 | vector | — | **PENDING.** Peak-normalised h(t), ALL sessions on the session gradient, measured solid / fit dashed (mirrors 2I). `imp_tf_xsess.m` (2026-08-05) |
| 2C-ii | Fig2 | *(pending)* | 4 × 4 | vector | 95% CI | **PENDING.** τ forest with bootstrap CIs — **matched amplitude range primary** (filled), full range open, cross-session mean ± SD band. Between/within SD ratio ≈1 ⇒ one shared time constant. ⚠ Caption must state the 3 sessions are **2 mice** (AL_0041 e1/e2 = same animal) |
| 2D | Fig2 | paper/images/figure2/step_response.pdf | 6 × 4 | image 300dpi | — | step_response.m |
| 2E | Fig2 | paper/images/figure2/onset_variance_slope.pdf | 6 × 4 | vector | ±SEM | OL variance trace + slope lines; gray traces, red stim lines |
| 2F (supp) | Supp | paper/images/supplementary/imp_motion_devscatter_*.png | 6 × 4 | PNG 300dpi | — | Single-session only (selExp_mot=3); supplementary, not paper panel |
| 2F | Fig2 | paper/images/figure2/imp_motion_devscatter_all_sessions.pdf | 4 × 4 | vector | — | motion z-score vs inhib dev, all sessions pooled; impulse-analysis/motion_analysis.m fig_mvp |
| 2G | Fig2 | paper/images/figure2/prevar_vs_dev_allamps_motexcl_AL_0033_2025-01-29_en1.pdf | 4 × 4 | vector | — | ⚠ **CONTESTED — do not assemble yet.** Built on **pre-stim variance**, retracted 2026-07-01 as a signal-power confound. impulse-analysis/prestim_variance.m fig_pvm. User is resolving the confound question separately (2026-08-05) |
| 2H | Fig2 | paper/images/figure2/prevar_heatmap_with_blockfit.pdf | 7 × 4 | vector | — | ⚠ **CONTESTED — same pre-stim-variance confound as 2G.** heatmap (freq×trial sorted by pre-stim var) + trial-rank + delta-power scatters; impulse-analysis/prestim_variance.m fig_pvs |
| 3A | Fig3 | paper/images/figure3/panel_A.pdf | 8.9 × 4 | vector | — | utils/analysisPlots_combined.m — single trial OL\|CL |
| 3B | Fig3 | paper/images/figure3/panel_B.pdf | 8.9 × 4 | vector | ±std | utils/analysisPlots_combined.m — all trials + avg OL\|CL |
| 3C | Fig3 | paper/images/figure3/panel_C.pdf | 8.9 × 3 | vector | — | utils/analysisPlots_combined.m — avg inputs OL\|CL |
| 3D | Fig3 | paper/images/figure3/panel_D.pdf | 3 × 3.5 | vector | — | utils/analysisPlots_combined.m — variance over time (single panel) |
| 3E | Fig3 | paper/images/figure3/panel_E.pdf | 3 × 3 | vector | — | utils/analysisPlots_combined.m — RMSE half-violin (single panel); relabelled + re-exported 2026-07-16 (cache rebuilt to RMSE) |
| 3F | Fig3 | paper/images/figure3/all_variance_sessions.pdf | 3 × 3.5 | vector | ±SEM | variance_mse.m fig_F — cross-session variance trace |
| 3G | Fig3 | paper/images/figure3/all_average_sessions.pdf | 3 × 4 | vector | ±SEM | step_response.m fig_H — per-session faint + bold mean |
| 3H | Fig3 | paper/images/figure3/all_MSE_sessions.pdf | 7.8 × 4 | image 300dpi | — | variance_mse.m fig_G — cross-session MSE violin; mean dot too large (open task) |
| 3I | Fig3 | paper/images/figure3/variance_ratio_by_window.pdf | 5 × 4 | vector | — | variance_mse.m fig_Fr — OL/CL variance ratio: Pre/Stim/Post; Wilcoxon stars |
| 3J | Fig3 | paper/images/figure3/MSE_ratio_by_window.pdf | 5 × 4 | vector | — | variance_mse.m fig_G2r — OL/CL RMS MSE ratio: Pre/0–1s/1–3s/Post. ⚠ filename still says "MSE"; metric is RMSE |
| 3K | Fig3 | paper/images/figure3/pooled_ol_cl_rmse_15sess.pdf | 5 × 4 | vector | — | **NEW 2026-07-30** — per-session median OL vs CL RMSE, **all 15 sessions**, m14/m15 outlined black. `controller-analysis/pooled_new_mice.m`. **CL < OL in 14/15, signrank p = 1.2e-4.** Lean load (`load(path,'data')`) — never holds `d`. This is the cross-session headline; placement in the Fig 3 layout still TBD |
| 2I (was 3K) | Fig2 | paper/images/figure2/ol_tf_trial_avg.pdf | 6 × 4 | vector | — | tf_fit.m fig_tf_paper — **MOVED to Fig 2 (2026-07-23)** as the step-response LTI fit, beside the impulse TF fit (2C). ONE axis, all 3 sessions on the session gradient, solid = OL trial mean, dashed = TF fit. Orders AIC-picked with np capped at 2 (R² 0.22/0.77/0.89). ✅ Export path moved to `figure2/` (verified 2026-08-10) |
| N1–N4 | Fig3 supp? | paper/images/newmice/{AL_0048,AL_0051}/ctrl_{trialavg,variance,rmse,input}.pdf | 6×4 / 5.5×4 / 4.2×5.4 / 6×4 | vector | ±std | **NEW 2026-07-30, placement UNDECIDED.** Paper-styled single-session panels for the two new mice (last-100 locked-Kp block). `new_mice_paper_panels.m`. Input panel is in **mW** (`laser_v2mw`); active laser differs by mouse (AL_0048 = 638 nm, AL_0051 = 594 nm). Per-session RMSE is **n.s.** (p=0.48/0.43) — the CL benefit is in the mean trace; significance comes from pooling (3K). No single-trial or avg-input equivalent of 3A/3C (this build has no valid `d.inpVals`) |
| 5A | Fig5 | *(feedforward control system — illustrator)* | 6 × 4 | — | — | external; physical row 1 |
| 5B | Fig5 | paper/images/figure5/sine_5B_single_trial_AL_0048_2026-07-21_1.pdf | 11.4 × 3.5 | vector | — | one representative trial, all 4 modes in one panel + reference; **no x-axis** (shares col1 time base) |
| 5C | Fig5 | paper/images/figure5/sine_5C_trialavg_AL_0048_2026-07-21_1.pdf | 11.4 × 3.5 | vector | ±SEM | trial average, all 4 modes + reference; **no x-axis** (shares col1 time base) |
| 5D | Fig5 | paper/images/figure5/sine_5D_trialavg_input_AL_0048_2026-07-21_1.pdf | 11.4 × 3.5 | vector | ±SEM | trial-average **input/command**, 4 modes — carries the col1 time axis + scalebar |
| 5E | Fig5 | paper/images/figure5/sine_5E_rmse_time_AL_0048_2026-07-21_1.pdf | 5.2 × 4 | vector | ±SEM | **RMSE** over time, 4 modes; physical row 1. (s3 early→late: OL −0.40, OL+p +0.09, CL +0.06, CL+p −0.02 — do NOT repeat the old "CL+prev only mode that falls" claim; it's false, OL falls most here) |
| 5F | Fig5 | paper/images/figure5/sine_5F_variance_AL_0048_2026-07-21_1.pdf | 5.2 × 4 | vector | — | across-trial variance over time, 4 modes; physical row 1 |
| ~~5G~~ | — | ~~sine_5G_rmse_violin~~ | — | — | — | **DROPPED 2026-07-29** — replaced by combined 5I (across-session RMSE). Still generated by the script; not a paper panel |
| ~~5H~~ | — | ~~sine_5H_phase_lag~~ | — | — | — | **DROPPED 2026-07-29** — replaced by combined 5K (across-session phase). Still generated by the script; not a paper panel |
| 5I | Fig5 | paper/images/figure5/sine_combined_rmse.pdf | 5.5 × 4.5 | vector | — | **across-session** total RMSE, 4 modes × 3 sessions (points aligned + mean bar); sine_ff_across_sessions.m. CL<OL in all 3 |
| 5J | Fig5 | paper/images/figure5/sine_combined_variance.pdf | 5.5 × 4.5 | vector | — | **across-session** total variance, 4 modes × 3 sessions; sine_ff_across_sessions.m. CL<OL in all 3 |
| 5K | Fig5 | paper/images/figure5/sine_combined_phase.pdf | 5.5 × 4.5 | vector | — | **across-session** 1 Hz phase lag, 4 modes × 3 sessions; sine_ff_across_sessions.m. Preview→~0° in all 3 |

> **Fig 5 session switch (2026-07-29): DONE.** Single-session panels regenerated on **s3 (`2026-07-21/1`, dark screen)** — `SESSION_TAG='s3'` is now the script default; suffix `AL_0048_2026-07-21_1`. Composition decided: **combined 5I/5J/5K REPLACE single-session 5G/5H** (dropped above). Fig 5 panel set = 5A (schematic) · 5B/5C/5D (s3 traces: single trial / trial-avg / input) · 5E/5F (s3 time-resolved RMSE + variance) · 5I/5J/5K (combined s1/s2/s3 RMSE / variance / phase). s3 feedback (OL-vs-CL) is n.s. within-session (p=0.36) — the quantitative feedback claim rides on combined 5I/5J (CL<OL in all 3 sessions); s3's single-session role is the illustrative example + preview lag cancellation (5C, phase in 5K).
| T-A | Methods fig:cost_landscape | paper/images/tuning/grid_cost_surface_AL_0033_0305.pdf | 6 × 5 | vector | — | gain_grid.m — PI gain-grid cost surface J(Kp,Ki), AL_0033 03-05 (PRIMARY: clean interior min ~0.05,0.1) |
| T-B | Methods fig:cost_landscape | paper/images/tuning/grid_cost_surface_AL_0034_1017.pdf | 6 × 5 | vector | — | gain_grid.m — same, AL_0034 10-17 — **dur=4 VARIANT**: this session ran a 4 s stim (vs 3 s elsewhere) so J is scored over [0 4] s (parameter-dependence exhibit). CROSS-MOUSE replication of low-cost basin. min J=30.2 at (Kp=0.3,Ki=0.02). CAVEAT: dur & mouse covary (10-17 is the only dur=4 AND only AL_0034 grid) → variant exhibit, not a clean dur-controlled comparison |
| T-C | Methods fig:cost_landscape | paper/images/tuning/autotune_convergence_both.pdf | 12 × 8 | vector | — | AUTO-TUNE convergence, BOTH mice side-by-side (AL_0033 03-17 + AL_0034 10-25 e1); accepted Kdata/Kval — (Kp,Ki) path + cost staircase (16.6→12.3 / 11.9→4.6). Singles also exported: `autotune_convergence_AL_0033_0317.pdf`, `..._AL_0034_1025e1.pdf` |

> **Fig 5 sine-wave (feedforward) section — AL_0048, right/inhibitory, 1 Hz sine, 4 s.** Source: `bilateral/sine_ff_paper_panels.m` (run after `bilateral/load_bilateral.m`). Design is **4-mode**, not OL-vs-CL binary: `ff_analysis_cond` 2=OL, 1=OL+preview, 3=CL, 0=CL+preview (rig "FF Analysis" button). Colour code (2026-07-23): **OL = red, OL+preview = orange, CL = blue, CL+preview = green**. Input command in each panel is **gray (solid, bold)** — context, not a compared quantity, so it never carries the mode colour (mode colour is reserved for the response).
> **Primary session = s3 `2026-07-21/1`** (dark screen), suffix `AL_0048_2026-07-21_1`, `SESSION_TAG='s3'` is the script default. n per mode [62 45 34 57]. Sessions s1 `2026-07-01/6` and s2 `2026-07-14/1` are **not shown as single-session panels** but ARE the other two points in the combined 5I/5J/5K.
>
> **Where each claim now lives — the split is deliberate:**
> - **(a) Feedback reduces tracking error → combined 5I/5J, NOT the single session.** s3's own OL-vs-CL is **n.s. (p=0.36)**; the claim rides on **CL < OL in all 3 sessions** for both RMSE and variance. Cross-session: OL vs CL **p=1.5e-4** (`sine_ff_across_sessions.m`, drowsy-excluded, 16/478 trials dropped at pre-stim var > median+2.5·SD). ⚠ **Friedman across sessions is n.s. (n=3, p=0.060) — underpowered; do not overstate.**
> - **(b) Preview cancels the plant's phase lag → 5C (illustration) + 5K (quantified).** Replicates cleanly on s3: OL 60°, OL+prev −9°, CL 37°, CL+prev −24°; preview lookahead = 62°. `previewT_steps=5` = **143 ms @35 Hz ≈ the measured ~160 ms lag** — the lookahead is matched to the delay by design.
> - **(c) Preview does NOT reduce tracking error.** OL vs OL+prev **n.s. (p=0.49** across sessions; p=0.32 on s2). Report preview as **lag cancellation, not error reduction**. The narrative is: **RMSE win = feedback; phase win = preview.**
>
> **⚠ Retired claims — do not resurrect (both were s2-only and are false or unsupported on s3):**
> - *"CL+preview is the only mode whose error falls within the trial"* — **FALSE on s3**, where OL falls most (early→late OL −0.40, OL+p +0.09, CL +0.06, CL+p −0.02). Removed 2026-07-29. The old s2 numbers (4.01→3.67) must not appear in the caption.
> - *Preview's sign on error* — flipped between mean-MSE and mean-RMSE on s2 (outlier-dominated). Superseded by the rank test in (c).
>
> **Caveats (read before writing):** (i) dF/F is **uncorrected blue SVD** (`corr/` holds only temporal comps; `getpixel_dFoF` falls back to blue). (ii) Onsets come from `traj_on` epochs, NOT `findStims` (whose `horizon` fallback puts them ~36 s early — RESEARCH 2026-07-15). (iii) **n = 3 sessions, one mouse (AL_0048), one hemisphere (right/inhibitory)** — Nick has asked for a water-restricted repeat before any stats claim. (iv) s3 pixel MUST be `pixel_R = [407 367]` (galvo sign-flip); see [[project_bilateral_sine_s3]]. Full detail: RESEARCH.md.

> Secondary-analysis "controller tuning" figure (gain grid + auto-tuning). **METHODS-ONLY** (AL 2026-06-29): lives as `fig:cost_landscape` in `methods_edit.tex` §gain_opt (A=grid 03-05, B=grid 10-17 cross-mouse, C=autotune both mice) — NO Results section / no main figure number.
> **Paper-ready panel set:** **Grid** — T-A cost surface AL_0033 03-05 + T-B AL_0034 10-17 (cross-mouse basin replication). **Auto-tune** — T-C convergence in BOTH mice side-by-side (cost descends monotonically → the model-free tuner works across mice). **Same-mouse link:** AL_0033 grid basin (T-A, ≈0.05,0.1) ≈ where AL_0033 autotune settles (T-C left, 0.068,0.064).
> **Methods/claims caveats (read before writing):** (a) cost = `mean(||y−ref||₂)` over t=0–3 s (per-session `cwin`; **T-B/10-17 uses [0 4] s** because it ran dur=4), y=`states.csv` (% ΔF/F, online kernel-mean), ref=−5; (b) autotune = greedy zero-order, accept-if-cost-lowered; show trajectories from accepted `Kdata`/`Kval`, NOT `input_params` (which logs rejected probes); (c) only 03-17 (+10-25 e1) are valid convergence demos — 12-19 had a dead online cost (random walk), 10-25 e2 stuck at (0,0); (d) grid↔autotune comparisons are SAME-MOUSE only; (e) the rig autotune cost/annealing was fixed 2026-06-29 (StLab_Rainier) for FUTURE runs — recorded sessions predate it. Full detail: FINDINGS.md + controller-tuning/CLAUDE.md.

---

### 🗂 Figure asset policy — **PDF means locked** (adopted 2026-08-10)

The one rule: **a `.pdf` under `paper/images/figureN/` is a panel that is locked in and linked by an
Illustrator file. Nothing else may be a PDF there.** Exploratory output, variants, sweeps, per-session
diagnostics and dead panels are PNG, and they live outside the figure folders. If you are unsure whether
a panel is locked, it is not — export PNG.

| Location | Contains | Format | Rule |
|---|---|---|---|
| `paper/images/figureN/` | **only** the panels listed in "Paper panels in use" | PDF (vector) or 300 dpi PNG for heatmaps | one file per panel, **no session suffix, no `_cb`/`_z`/metric variants, no duplicates** |
| `paper/images/*.ai` + assembled `FigureN.pdf` | Illustrator assemblies + their exports | — | assemblies live one level ABOVE the panel folders, never inside them |
| `paper/explore/<topic>/` | everything else — sweeps, diagnostics, rejected panels, per-session variants | **PNG only** | free-for-all; never linked by Illustrator |
| `paper/_archive/` | superseded assets, path-preserved | as-was | move here, never delete — an Illustrator relink can find them at the mirrored path |

**Why it matters right now:** `paper/` root holds **stale May copies** of `panel_A–E`, `step_response`,
`imp_response`, `ol_tf_trial_avg`, `all_MSE_sessions`, `tf_data_vs_model_*` and `svd_frame_*` whose live
versions in `images/figureN/` are from July/August. A relink or a manual grab from the root silently pulls
a three-month-old panel into the figure. This is the `paper_root` CWD-dependence bug (TASKS) made visible.

**Current violations (audit 2026-08-10, `paper/images/`):**

| Folder | PDFs | Verdict |
|---|---|---|
| `figure4/` | **54** | **Graveyard.** 30 are the *old Fig-5 sine panels* (`sine_4A–4F`, `sine_panel_A–F`, both retired sessions) superseded by `figure5/sine_5*`. 18 are the exploratory `factor_*`/`claim*` grid incl. `_z` variants. `wb_*` are unassigned. **Zero of the actual planned 4A–4E exist.** |
| `figure5/` | 19 | Holds **both** the retired 07-14 AND current 07-21 panels for 5B–5H, plus dropped 5G/5H, plus `Figure4.ai`/`Figure4.pdf`/`Figure5.pdf` assemblies sitting inside a panel folder |
| `figure2/` | 19 | 8 are in use; the rest are `_cb`, `_cperr`, `_peakdev` metric variants and `prevar_*` alternates |
| `figure3/` | 12 | Cleanest — 11 in use + one assembly (`Figure3_extra.pdf`) |
| `predictor_saga/` | 0 (51 PNG) | Correct format, wrong place — this is `explore/` material |
| `paper/` root | **61 PDF + 179 PNG** | Pre-reorg dumping ground + stale duplicates of live panels |

**Decluttering, in order of payoff:**
1. **Kill the root duplicates first** — highest risk, lowest effort. Nothing should export to `paper/` root.
2. **Fix the export-path bug at the source** so it cannot recur: anchor `paper_root` to
   `fileparts(mfilename('fullpath'))`, not to a CWD-dependent `exist()` probe (TASKS, found 2026-07-17).
3. **Empty `figure4/`** into `_archive/` — it is 100% dead or exploratory, and its name now collides with
   the state-dependence figure that will need the folder.
4. **One session per figure folder.** Drop the `_<mouse>_<date>_<exp>` suffix on locked panels; the session
   is recorded in this table and in the caption. Suffixes exist to let two sessions coexist — which is
   exactly the ambiguity that put the wrong session in the Fig 5 caption for three weeks.
5. **Variants (`_cb`, `_z`, `_cperr`, `_peakdev`) are PNG in `explore/`**, never PDF beside the panel.
   Exception: the colourblind set, once adopted, *replaces* the panel rather than sitting next to it.
6. **Make `paperExport` enforce it** — one helper that takes a panel ID, refuses to write a PDF for an ID
   not in the "Paper panels in use" table, and sends everything else to `explore/` as PNG. The registry
   then cannot drift from the folder, because the folder is generated from the registry.

---

### All generated figures (reference log)
All MATLAB-exported figures, including those not yet assigned to a paper panel. Add new figures here as they are created.

#### utils/analysisPlots_combined.m  (called from plottingScript.m, single session)

| Var | Size (cm W×H) | Export path | Format | Notes |
|-----|--------------|-------------|--------|-------|
| fig_A | 8.9 × 4 | paper/images/figure3/panel_A.pdf | vector | Single trial example OL\|CL |
| fig_B | 8.9 × 4 | paper/images/figure3/panel_B.pdf | vector | All trials + average OL\|CL; shading=±std |
| fig_C | 8.9 × 3 | paper/images/figure3/panel_C.pdf | vector | Average inputs OL\|CL |
| fig_D | 8.9 × 3.5 | paper/images/figure3/panel_D.pdf | vector | Variance over time; shading=±std |
| fig_E | 8.9 × 3 | paper/images/figure3/panel_E.pdf | vector | MSE half-violin |

#### variance_mse.m

| Var | Size (cm W×H) | Export path | Format | Active? | Notes |
|-----|--------------|-------------|--------|---------|-------|
| fig_Fr | 5 × 4 | paper/images/figure3/variance_ratio_by_window.pdf | vector | yes | OL/CL variance ratio by window (pre/stim/post); Wilcoxon stars *** on stim; **paper panel 3I** |
| fig_G2r | 5 × 4 | paper/images/figure3/MSE_ratio_by_window.pdf | vector | yes | OL/CL RMS MSE ratio — 4 windows: Pre / 0–1 s / 1–3 s / Post; **paper panel 3J** |

#### plottingScript.m

| Var | Size (cm W×H) | Export path | Format | Active? | Notes |
|-----|--------------|-------------|--------|---------|-------|
| fig_F | 3 × 3.5 | paper/images/figure3/all_variance_sessions.pdf | vector | yes | Cross-session variance trace (paper panel 3F) |
| fig_G | 8 × 4 | paper/images/figure3/all_MSE_sessions.pdf | image 300dpi | yes | Cross-session MSE violin (paper panel 3H) |
| fig_G2a | 8 × 5 | paper/MSE_window_comparison.pdf | vector | **commented** | Trial-avg trace OL vs CL (replaced violins) |
| fig_G2b | nC×5 × nR×4 | paper/MSE_vs_trial_number.png | image 300dpi | yes | Windowed RMS MSE vs trial# |
| fig_H | 3 × 4 | paper/images/figure3/all_average_sessions.pdf | vector | yes | Per-session faint + bold mean |
| fig (step) | auto | paper/images/figure2/step_response.pdf | image 300dpi | yes | OL step response, sessions [4 9 11] |
| fig (spont) | 15 × 10 | paper/spont_variance.png | image 300dpi | yes | Bootstrap variance convergence |
| figC | auto | paper/motion_mse_combined.png | image 300dpi | yes | Motion vs MSE pooled scatter |
| fig_I | nSess×11.4 × nRows×8.9 | paper/freq_heatmap_sessions.png | image 300dpi | yes | Per-session spectral heatmap |
| fig_J | 25.4 × 15.2 | paper/freq_heatmap_combined.png | image 300dpi | yes | All-session pooled heatmap (MSE sort) |
| fig_J2 | 25.4 × 15.2 | paper/freq_heatmap_motionclean.png | image 300dpi | yes | J, motion-clean |
| fig_K1 | 25.4 × 15.2 | paper/freq_heatmap_prestimvar.png | image 300dpi | yes | Pre-stim var sort heatmap — **log color scale** (updated 2026-05-29) |
| fig_K1_1f | 25.4 × 15.2 | paper/freq_heatmap_prestimvar_1f.png | image 300dpi | yes | K1 with 1/f correction (power ÷ f per band), log scale — companion to K1 |
| fig_K2 | 6 × 4 | paper/prestimvar_mse.png | image 300dpi | yes | Pre-stim var vs MSE scatter |
| fig_K1m | 25.4 × 15.2 | paper/freq_heatmap_prestimvar_motclean.png | image 300dpi | yes | K1 motion-clean |
| fig_K2m | 6 × 4 | paper/prestimvar_mse_motclean.png | image 300dpi | yes | K2 motion-clean |
| fig_K1w | 25.4 × 15.2 | paper/freq_heatmap_pretrial_var.png | image 300dpi | yes | Pre+trial var sort heatmap |
| fig_K2w | 6 × 4 | paper/pretrial_var_mse.png | image 300dpi | yes | Pre+trial var vs MSE scatter |
| fig_wb | 12 × 8 | *(no export)* | — | no export | Widebrain ARX 4-panel — pending R²_spont > 0.3 |
| fig_tf_paper | 12 × 4 | paper/images/figure3/ol_tf_trial_avg.pdf | vector | yes | OL trial avg + TF pred, -1 to stimend+1 s; shading=±std; scalebar on panel 1 only |
| fig_ov | 6 × 4 | paper/images/figure2/onset_variance_slope.pdf | vector | yes | OL variance trace + pre/post slope lines; gray, red stim xlines |
| fig_K1z/K2z | 25.4×15.2 / 8×5 | paper/freq_heatmap_prestimvar_zscore* | mixed | **commented** | Z-scored spectrum heatmap + quintile bars |
| fig_K1zm/K2zm | 25.4×15.2 / 8×5 | paper/..._motclean* | mixed | **commented** | K1z/K2z motion-clean |

#### Impulse_mouseDataAnalysis_all.m  (per-session, filename = `*_mn_td_enN.pdf`)

| Var | Size (cm W×H) | Export path pattern | Active? | Notes |
|-----|--------------|---------------------|---------|-------|
| fig_A | 6 × 4 | paper/images/figure2/tf_data_vs_model_*.pdf | yes | TF fit: data vs model |
| fig_B | 4 × 4 | paper/images/figure2/tf_loao_*.pdf | yes | LOAO cross-validation |
| fig_mh | nAmp×3 × 4 | paper/motion_heatmap_*.pdf | yes | Motion-sorted trial heatmap |
| fig_mt | 6 × 4 | paper/motion_trace_*.pdf | yes | Motion trace per amp |
| fig_md | 6 × 6 | paper/motion_dev_*.pdf | yes | Signed deviation vs motion |
| fig_mv | 6 × 4 | paper/images/figure2/imp_motion_devscatter_*.pdf | yes | Motion z-score vs \|Peak dev\| — paper panel 2F (single session) |
| fig_mvp | 6 × 4 | paper/images/figure2/imp_motion_devscatter_all_sessions.pdf | yes | Motion z-score vs \|Peak dev\| — all sessions pooled; paper panel 2F-pool |
| fig_na | 12 × 6 | paper/amplitude_all_*.pdf | yes | All-amp trial responses |
| fig_ns | 8 × 6 | paper/amplitude_sorted_*.pdf | yes | Amplitude-sorted heatmap |
| fig_nq | 6 × 4 | paper/amplitude_quartile_*.pdf | yes | Amplitude quartile summary |
| fig_pvp | 6 × 6 | paper/pretrial_var_pred_*.pdf | yes | Pre-trial variance vs prediction error |
| fig_poster | 18 × 6 | paper/poster_brainstate_*.pdf | yes | Brain-state poster panel |
| fig_sp | 12 × 4 | paper/spatial_spread_*.png | image 300dpi | yes | Spatial spread of response |

#### widebrain_arx.m  (widebrain / contralateral prediction — **figure assignment TBD**)
> Previously labelled "Fig 4". Fig 4 is now **state-dependence** (2026-07-17), so these panels
> need a home: fold into Fig 4, move to supplementary, or take their own number. Files still
> sit in `paper/images/figure4/`.

| Var | Size (cm W×H) | Export path | Format | Active? | Notes |
|-----|--------------|-------------|--------|---------|-------|
| fig_wb1 | 16 × 5 | paper/images/figure4/wb_pink_4panel.pdf | vector | yes | ARX pink prediction: 4 panels (OL/CL trace, residual, R²) |
| fig_wb4 | 12 × 4 | paper/images/figure4/wb_three_layers.pdf | vector | yes | Three-layer contralateral prediction (pink/orange/red) |
| fig_wb5 | 6 × 4 | paper/images/figure4/wb_mpc_gap.png | image 300dpi | yes | WB-5 MSE gap (CL vs OL residuals) |
| fig_spat | auto | paper/images/figure4/wb_spat_traces.png | image 300dpi | yes | Spatial spread of contralateral signal |

#### controller-analysis/motion_analysis.m  (candidate Fig 4 panels — state-dependence)

| Var | Size (cm W×H) | Export path | Format | Active? | Notes |
|-----|--------------|-------------|--------|---------|-------|
| fig_ps_mse | 6 × 4 | paper/images/figure4/prestim_dev_vs_mse.pdf | vector | ⚠ **no — circular** | x = \|dFk(t=0)−ref\| lies *inside* the y RMSE window (0–3 s); slope guaranteed by autocorrelation. Audited 2026-07-21. Do not promote to a panel. |
| figQp | 6 × 4 | paper/images/figure4/motion_quartile_combined.pdf | vector | yes | Motion quartile RMSE summary (pooled sessions). **Only power-independent state regressor in the old candidate set.** Window is −2→+3 s (not purely pre-stim). |

#### Uniformity checklist
- [ ] Font: 6 pt bold throughout — audit `impulse-analysis/tf_fit.m` and `impulse-analysis/dose_response.m`
- [x] Shading convention confirmed: ±std single-session (panels A–D, fig_tf_paper); ±SEM cross-session (fig_F, fig_H)
- [x] Line widths: enforced via `paperStyle()` in all paper panel scripts
- [x] Scalebars: `shortCornerAxes_plot` LineWidth=1.5, LabelGap=0.05, FontSize=6, FontWeight='bold' — fixed in fig_F (variance_mse.m) and step figure (step_response.m)
- [x] Legend `ItemTokenSize = [6 6]` — fixed in analysisPlots_combined panel A, variance_mse fig_G2v, step_response spont figure
- [ ] Export: `exportgraphics(...,'ContentType','vector')` for all line-art; 300 dpi PNG for heatmaps
- [ ] fig_wb: needs exportgraphics added once ARX R²_spont > 0.3 confirmed
- [x] K-figures (prestim_variance.m): all raw `figure()` → `paperFig()` (K1/K1_1f/K2: 25.4×15.2/6×4; K1z/K1m/K1zm/K1w: 25.4×15.2; K2z/K2zm: 8×5; K2m/K2w: 6×4; interactive K2i/K2iw left unchanged)
- [x] Spectral figures (spectral_mse_sort.m): fig_I/J/J2 raw `figure()` → `paperFig()`
- [x] fig_G2a/G2b/G2v (variance_mse.m): all raw `figure()` → `paperFig()`; G2a mean LineWidth 2→1.5
- [ ] dose_response.m: legend `FontWeight` added; `lgd_m.ItemTokenSize` fixed; text annotations FontSize 5/7→6; `shortCornerAxes_plot` LW fixed; `print()` replaced with `exportgraphics(...,'ContentType','vector')`; paths updated to dynamic detection matching tf_fit.m pattern — **re-run to regenerate panel 2B**

---

## Unification Plan

Two helpers, two responsibilities:

**`paperFig(w, h)`** — already exists. Creates figure with correct cm units, PaperSize, PaperPosition. Use everywhere a new paper figure is created. `analysisPlots_combined.m` currently uses raw `figure()` which loses PaperSize — switch it to `paperFig`.

**`paperStyle()`** — new. Returns a struct of style constants. Call at the top of any script or utility that draws paper axes. Orthogonal to figure creation so it works inside utility functions like `analysisPlots_combined.m` that receive axes rather than create figures.

```matlab
% paperStyle.m
function PS = paperStyle()
PS.lw_mean   = 1.5;   % mean trace
PS.lw_fit    = 1.2;   % TF fit / prediction
PS.lw_trial  = 0.4;   % individual trials
PS.lw_ref    = 1.0;   % dashed reference line
PS.lw_inp    = 0.75;  % input/laser trace
PS.lw_zero   = 0.5;   % zero baseline
PS.fs        = 6;     % font size (pt)
PS.fw        = 'bold';
PS.fa        = 0.2;   % FaceAlpha for ±std ribbon
PS.sca_lw    = 1.5;   % shortCornerAxes LineWidth
PS.sca_gap   = 0.05;  % shortCornerAxes LabelGap
end
```

### Implementation order

| Step | File | Change | Size |
|------|------|--------|------|
| 1 | `utils/paperStyle.m` | Create new helper | tiny |
| 2 | `utils/analysisPlots_combined.m` | Switch `figure()` → `paperFig`; fix `PW=8` → `PW=8.9`; adopt `PS` constants | small |
| 3 | `Impulse_mouseDataAnalysis_all.m` | Adopt `PS` constants; fix font sizes (5/7/8/9/10 → 6 bold) | medium |
| 4 | `plottingScript.m` | Adopt `PS` constants in paper panel sections; add `LabelGap` to `shortCornerAxes_plot` calls | small |

### Shading convention (decide before implementing)
- **Single-session traces** (panels A–D, fig_tf_paper): ±std — already correct
- **Cross-session means** (fig_F variance trace, fig_H avg trace): currently unknown — audit before touching


### Figure layouts
Sizes are **MATLAB export sizes** (W × H cm). Illustrator scales all panels in a row to a
uniform height, so widths scale proportionally. `[ext]` = Illustrator/external. `?` = not yet set.
To resize a panel: change the numbers. To move a panel: cut/paste the token to a different row.
Run `checkLayout(widths, heights, total, gap, label)` in MATLAB to verify any row fits.

**Notation:**  `Label(W×H)`  ·  space = side-by-side  ·  new line = new row  ·  `/` = stacked in same column

---

#### Fig 1  [total=17  gap=0.3]
```
row1:  1A(?×?)[ext]  1B(?×?)[ext]  1C(?×?)[ext]  1D(?×?)[ext]
row2:  1E(?×?)[ext]  1F(?×?)[ext]
```

---

#### Fig 2  [total=17  gap=0.3]
```
row1:  Text(1.2×4)  2A(5×4)   2B(5×4)   2C(6×4)
row2:  Text(1.2×4)  2D(6×4)   2E(6×4)
row3:              2F(4×4)   2G(4×4)   2H(7×4)
```
Fit checks (last computed, gap=0.3 cm):
- row1: text(1.2)+2A(5)+2B(5)+2C(6) + 3×0.3 = **18.1/17** ✗ (−1.1 overflow → shrink 2A/2B/2C: try 4.5×4 each → 1.2+4.5+4.5+6+0.9=17.1 ✓)
- row2: text(1.2)+2D(6)+2E(6) + 2×0.3 = **14.1/17** ✓ (+2.9)
- row3 @H=4: 2F(4)+2G(4)+2H(7) + 2×0.3 = **15.6/17** ✓ (+1.4)

---

#### Fig 3  [total=17  col-gap=0.3  inner-gap=0.3]
Two-column layout: col1 fixed at 8.9 cm, col2 = 17 − 8.9 − 0.3 = **7.8 cm**
```
section1:
  col1[8.9]:  3A(8.9×4)  /  3B(8.9×4)  /  3C(8.9×3)
  col2[7.8]:
    row1:  3D(3×3.5)  3E(3×3)
    row2:  3F(3×3.5)  3G(3×4)
    row3:  3H(7.8×4)

section2:
  row1:  3I(5×4)  3J(5×4)  3K(5×4)
```
> **3K = the new 15-session pooled RMSE panel** (`pooled_ol_cl_rmse_15sess.pdf`), NOT the old step-TF fit —
> that moved to Fig 2 as **2I** on 2026-07-23. Section 2 is now the three cross-session summary panels.
Fit checks (last computed, gap=0.3):
- col2 row1 @H=3.5: D(3→3.00) E(3→3.50) + 0.3 = **6.8/7.8** ✓ (+1.0)
- col2 row2 @H=4.0: F(3→3.43) G(3→3.00) + 0.3 = **6.7/7.8** ✓ (+1.1)
- col2 row3: H(7.8) = **7.8/7.8** ✓ (exact fit — updated from 8×4)
- col1 heights: 4+4+3 + 2×0.3 = **11.6 cm** total
- Row height match: row1 A=4 vs D/E=3.5 (⚠ 0.5 cm gap) · row2 B=4 vs F/G=4 ✓ · row3 C=3 vs H=4 (⚠ 1.0 cm gap)
- section2 row1: 5+5+5 + 2×0.3 = **15.6/17** ✓ (+1.4) — updated 2026-08-10 for 3K

---

#### Fig 4  [total=17  gap=0.3]
**Closed-loop feedback rejects a state-dependent disturbance carried by the contralateral hemisphere.**
Restructured 2026-07-29 into **three ordered blocks**, coarse → mechanistic:
> **Block 1 — trial-average state dependence** (`ctrl_state_dependence.m`, Stage 5): the pre-stim
> state (stim-blind contra-derived Global level `s_lvl`) predicts the *true* trial outcome (absolute
> Actual over 1→dur s, `o_act`). OL slope steep, CL slope flat → the controller decouples the outcome
> from ongoing brain state. This is the coarse, whole-trial version of the story.
> **Block 2 — error-contribution model** (`cl_mse_factors.m` / `cl_rmse_factor_windows.m`): per-trial
> RMSE regressed on **initial deviation + motion energy + relative δ power**; ΔR² waterfall /
> standardized coefficients show which state factors drive residual error.
> **Block 3 — residual state dependence** (`internal_model_principle.m`): the fine-grained mechanism —
> Actual = Global + Local decomposition, disturbance rejection ρ = ‖A−ref‖/‖G‖ over 1–3 s (0 = full
> rejection), and ρ classified by motion & δ quartiles (`[IMP-STATE-QUARTILE]`).

> **Panel plan.** Currently **single-session (m4 = AL_0033 2025-02-26)** + exploratory styling → these
> are *drafts*; production panels await the **Stage 1→2 cross-session sweep** (automated affected
> detector, C2) + `paperFig`/`paperStyle`.
>
> | Panel | Block | Content | Source |
> |---|---|---|---|
> | 4A | 1 | Trial-average state dependence: pre-stim Global level (state) → absolute Actual outcome; OL steep vs CL flat slope (bootstrap OL−CL slope diff) | `ctrl_state_dependence.m` (`s_lvl→o_act`) |
> | 4B | 2 | Error-contribution model: per-trial RMSE regressed on initial deviation + motion + relative δ; ΔR² / standardized coefficients | `cl_mse_factors.m` / `cl_rmse_factor_windows.m` |
> | 4C | 3 | Residual decomposition + rejection: Actual = Global (contra-predicted disturbance) + Local (controller effect); rejection ρ = ‖A−ref‖/‖G‖ (1–3 s), OL vs CL | `[IMP-PROOF-FIG]` / `[IMP-REJECT]` |
> | 4D | 3 | ρ vs motion-energy quartile (OL/CL) | `[IMP-STATE-QUARTILE]` |
> | 4E | 3 | ρ vs relative-δ (2–4 Hz) quartile (OL/CL) | `[IMP-STATE-QUARTILE]` |
> | (supp) | — | Predictor validity: contra→ipsi CV-R² (Global vs Global+Local) + pre-stim control; distributed contra co-suppression (proves Global = shared-network disturbance) | `[IMP-PROOF-FIG]` (a) · `stim_network_coupling.m` `[SNC]` |
>
> **State definitions are IDENTICAL across all three blocks** (they inherit `cl_rmse_factor_windows.m`):
> motion = mean z-motion² over −2 s→trial-end; δ = **relative** 2–4 Hz power (bandpow 2-4 / 0.4-10)
> over −2 s→stim-end. Block-3 outcome classified = **1–3 s rejection ρ only**. Cross-session inference
> (to build): per-session Spearman r_s(state, outcome), signrank across sessions, OL-vs-CL paired — via
> `imp_build_session` + `imp_reject_core` + `imp_state_across_sessions.m` (mirrors
> `imp_reject_across_sessions.m`); block-1 slopes via the `ctrl_state_dependence` bootstrap across sessions.

<details><summary>Prior state-dependence candidate audit (2026-07-21, superseded by the residual reframe)</summary>

> ⚠ **CANDIDATE LIST AUDITED 2026-07-21 — most of the original candidates are unusable.** The old
> list predates the 2026-07-01 signal-power retraction. Audit result (RESEARCH 2026-07-21):
>
> | Candidate | Status |
> |---|---|
> | `prestim_variance.m` K2 · `spectral_mse_sort.m` | **FILES DELETED** (commit `6080273`). "J4/J5" **never existed** in any commit — that description was fictional. |
> | `motion_analysis.m` `fig_ps_mse` (`prestim_dev_vs_mse.pdf`) | **CIRCULAR — do not use.** x = \|dFk(t=0)−ref\| is the *first sample inside* the y-window (RMSE of dFk over 0–3 s). Positive slope is guaranteed by autocorrelation alone. |
> | `trial_state_mse.m` (the "J6" fig) | **ALGEBRAICALLY CIRCULAR — do not use.** x = var(dFk, 0–3 s), y = RMSE(dFk, 0–3 s), *identical window*: RMSE² = var + (mean−ref)². Also no `paperExport` call. |
> | `motion_analysis.m` `figQp` (`motion_quartile_combined.pdf`) | ✅ **USABLE** — motion energy is the only power-independent regressor in the old set. Caveat: its window is −2→+3 s, so it is not purely *pre*-stim; the `pre_trial_3s` mode is the clean version. |
>
> **New primary source: `controller-analysis/ctrl_state_dependence.m` (Stage 5, 2026-07-21)** — state
> estimated as the stim-blind contra-derived Global, not as a magnitude of the ipsi signal. Its
> `s_lvl→o_act` pair is the one genuinely cross-signal, window-disjoint result and is the intended
> Fig 4 headline. Its `s_var→o_loc` and `s_dst→o_loc` pairs are same-signal and must NOT become
> panels as-is. Currently **single-session + exploratory styling** (no `paperFig`/`paperStyle`,
> exports to `paper/images/predictor_saga/`) — blocked on the Stage 1→2 cross-session sweep.
>
> Across the entire old candidate set, the OL-vs-CL slope comparison that motivates the figure was
> **never computed in code** — only two `polyfit` coefficients printed on the retired K2 axes for
> visual comparison. Stage 5 is the first script to actually test it (trial bootstrap, 5000).
</details>

```
row1 (block1→block2):  4A(state→outcome, OL vs CL)   4B(error-contribution model)
row2 (block3):          4C(decomp + reject ρ)  4D(ρ|motion)  4E(ρ|δ)
```
Fit checks: **pending** — sizes set once panels are re-exported at paperStyle from the cross-session sweep.

---

#### Fig 5  [total=17  gap=0.3]
Sine-wave (feedforward) section — panels exported individually, stitched in Illustrator.
**Primary session: s3 = `2026-07-21/1`** (dark screen; suffix `AL_0048_2026-07-21_1`).
Sessions s1 `2026-07-01/6` and s2 `2026-07-14/1` appear **only as points inside 5I/5J/5K**.
**All four modes live in ONE panel** per trace figure (not 4 separate per-mode panels) —
mode is encoded by colour, so 5B/5C/5D each carry all of OL / OL+prev / CL / CL+prev.
```
row1:  5A(6×4)[ext]   5E(5.2×4)   5F(5.2×4)

row2:  col1[11.4]:  5B(11.4×3.5) / 5C(11.4×3.5) / 5D(11.4×3.5)
       col2[5.3]:   5I(5.3×3.5) / 5J(5.3×3.5) / 5K(5.3×3.5)
```
Panel key: **5A** system diagram · **5B** single trial · **5C** trial average ·
**5D** trial-average input · **5E** RMSE over time · **5F** across-trial variance ·
**5I** across-session RMSE · **5J** across-session variance · **5K** across-session phase lag.
Physical top row is A, E, F. **5G/5H (single-session violin + phase) were DROPPED 2026-07-29** —
the combined panels replaced them; the script still emits them, they are not paper panels.

Fit checks (gap=0.3 cm) — **recomputed 2026-08-10 for the 5I/5J/5K column:**
- row1: 6 + 5.2 + 5.2 + 2×0.3 = **17.0/17** ✓ (exact)
- row2: col1(11.4) + col2(5.3) + 0.3 = **17.0/17** ✓ (exact) — col1 ≈ **2/3 of the measure**
- col1 inner height: 3×3.5 + 2×0.3 = **11.1 cm**
- col2 inner height: 3×3.5 + 2×0.3 = **11.1 cm** ✓ (columns flush by construction now —
  three panels each side, same height, so the old `2h+0.3 = 3×3.5+0.6` solve is obsolete)
- ⚠ **5I/5J/5K are currently exported at 5.5×4.5** — re-export at **5.3×3.5** to fit col2,
  or widen col2 to 5.5 (→ row2 = 11.4+5.5+0.3 = 17.2, 0.2 over; shrink col1 to 11.2).
- **Total height: 4 + 0.3 + 11.1 = 15.4 cm** ✓ (~7.6 cm spare on a 23 cm page)
- **Shared x-axis in col1:** 5B/5C/5D are the same 4 s time base stacked — only the bottom
  panel (5D, the input) should carry the time axis/scalebar; 5B/5C drop theirs. That is what
  buys the vertical room and makes the stack read as one object.

##### Fig 5 — draft manuscript caption
> ⚠ **Rewritten 2026-08-10 for the s3 + combined composition.** The previous caption was written
> for the retired s2 session (2026-07-14) and described the dropped panels G/H. Numbers below are
> s3 + `sine_ff_across_sessions.m`; anything quoted from s2 must be re-derived, not copied.

**Figure 5. Preview cancels the plant's phase lag while feedback reduces tracking error during 1 Hz sinusoidal reference tracking.**
Panels A–F: mouse AL_0048, right (inhibitory) hemisphere, 1 Hz sinusoidal reference, 4 s trials, one representative session (2026-07-21, dark screen; n = 62 / 45 / 34 / 57 trials per mode). Panels I–K pool three sessions from the same mouse and hemisphere. Four control modes appear throughout — open loop (OL), open loop with preview (OL+prev), closed loop (CL), and closed loop with preview (CL+prev): **OL = red, OL+preview = orange, CL = blue, CL+preview = green**. The laser command is gray. Preview advances the reference by 5 samples = 143 ms at 35 Hz, matched to the measured ~160 ms plant lag. Shading is ±SEM across trials unless noted.

**(A)** Control-system schematic. The preview path feeds the reference forward by 143 ms; the feedback path closes on the online kernel-mean ΔF/F.
**(B)** One representative trial per mode, with the sinusoidal reference overlaid (dashed). Time axis shared with C and D.
**(C)** Trial-averaged response per mode. Time axis shared with B and D. The preview modes are visibly in phase with the reference; the non-preview modes lag it.
**(D)** Trial-averaged laser command per mode, on its own scale. Carries the time axis for B–D.
**(E)** Tracking error (RMSE) against time within the trial; shading is ±SEM, transformed to RMSE units (and therefore asymmetric). Early→late change per mode: OL −0.40, OL+prev +0.09, CL +0.06, CL+prev −0.02.
**(F)** Across-trial variance of the response over time, per mode.
**(I)** Total per-trial RMSE per mode for each of the three sessions (points aligned, bar = mean). **Closed loop is below open loop in all three sessions** (OL vs CL, **p = 1.5 × 10⁻⁴**); preview has no significant effect on error (OL vs OL+prev, p = 0.49). Trials with pre-stimulus variance above median + 2.5 SD were excluded as drowsy (16/478).
**(J)** Total across-trial variance per mode per session; closed loop is below open loop in all three.
**(K)** Phase lag of the response relative to the 1 Hz reference, per mode per session. **Preview drives the lag to approximately zero in every session** (s3: OL 60°, OL+prev −9°, CL 37°, CL+prev −24°; preview lookahead = 62°).

ΔF/F is computed from an uncorrected blue SVD. Trial onsets are taken from `traj_on` epochs. Within the representative session alone the open- versus closed-loop difference does not reach significance (p = 0.36); the feedback claim rests on the three-session comparison in I and J. The Friedman test across sessions is not significant (n = 3, p = 0.060).

---

## Draft manuscript captions — Figs 1–4
Same house style as the Fig 5 caption above (results-first title sentence, shared preamble,
then per-panel text). **Statistics are deliberately left as `[n]` / `[p]` placeholders** where
I do not have a verified number on file — fill from the source script's console output rather
than from memory. Fig 5's caption lives with its layout above.

### Figure 1 — draft caption
**Figure 1. A closed-loop optogenetic system for controlling cortical population activity in real time.**
**(A)** Widefield imaging light path. **(B)** Combined optogenetic, electrophysiology and widefield preparation. **(C)** Example spatial SVD component of the widefield signal (AL_0039, 2025-04-19), showing the cortical parcellation from which the control readout is drawn. **(D)** Software interface linking image acquisition, online ΔF/F estimation and laser command. **(E)** Control-system block diagram: the measured kernel-mean ΔF/F is compared against the reference, and a PI controller sets the 638 nm laser command. **(F)** End-to-end loop latency from frame exposure to laser update.
> Panels A, B, D, E, F are schematics/external images; only C is script-generated. Sizes are still `?` in the layout block — set them before assembly.

### Figure 2 — draft caption
**Figure 2. Focal optogenetic inhibition produces a graded, low-order response whose magnitude depends on ongoing cortical state.**
All panels: mouse AL_0033 unless noted; inhibition energy is the mean ΔF/F over 0–200 ms after laser onset.
**(A)** Single-session ΔF/F responses to increasing laser amplitude (2025-01-29). Shading is ±1 SD across trials, shown for the lowest and highest amplitudes to bracket the spread. **(B)** Inhibition energy against laser amplitude for each session, with linear fits; error bars are ±SEM across trials. **(C)** Measured impulse response against the fitted transfer function (±std). **(D)** Step response of the same preparation. **(E)** Across-trial variance around laser onset, with fitted slopes (±SEM). **(F)** Per-trial prediction error against normalised motion (0–1, per session), pooled across sessions; circles = no motion, triangles = motion. **(G)** Pre-stimulus variance against inhibition depth, per amplitude, after motion exclusion. **(H)** Trials sorted by pre-stimulus variance: frequency×trial heatmap with the accompanying trial-rank and delta-power scatters.
> Panel F's x-axis is **per-session min-max normalised** motion (2026-07-21), not a z-score.
> ⚠ **The title sentence is contested.** "whose magnitude depends on ongoing cortical state" is contradicted
> by the 3-session state result (2026-08-03): **motion is null everywhere** (|pooled ρ| ≤ 0.04) and rel-δ →
> gain is +0.058 (Stouffer p = 0.053). The only surviving power-independent effect is rel-δ → *unpredictability*
> (L1DEV), ρ ≈ +0.06. Panels **2G/2H rest on the retracted pre-stim-variance confound** (2026-07-01).
> **Proposed reframe (NOT adopted — user is resolving separately):** the *actuator* is state-invariant and
> low-order, while the *surrounding network activity* is state-dependent — and that is precisely the
> disturbance Fig 4 shows the controller rejecting. Plant invariant + disturbance state-dependent +
> feedback rejects it makes Figs 2 and 4 the same argument at two levels.
> Also pending: **AL_0048 is now a 4th impulse session** (inhibitory only) and appears in no panel here.

### Figure 3 — draft caption
**Figure 3. Closed-loop feedback reduces both trial-to-trial variability and tracking error relative to open loop.**
Single-session panels (A–E): m4 (AL_0033, 2025-02-26). Cross-session panels (F–K): **15 sessions across four mice** (AL_0033, AL_0039, AL_0048, AL_0051); reference −5 % ΔF/F; error is RMSE over 0–3 s after laser onset unless noted. Open loop and closed loop are shown in **red and blue** throughout; the laser input command is gray (solid, bold).
**(A)** A single representative trial, open loop versus closed loop. **(B)** All trials with the trial average (±std). **(C)** Trial-averaged laser command. **(D)** Across-trial variance over time. **(E)** Per-trial RMSE distribution (half-violins). **(F)** Cross-session variance trace (±SEM). **(G)** Per-session trial averages, faint, with the cross-session mean in bold (±SEM). **(H)** Cross-session error distribution; this panel reports **MAE**, not RMSE. **(I)** Open/closed-loop variance ratio split by window (pre, stim, post); asterisks are Wilcoxon. **(J)** Open/closed-loop RMSE ratio split by window (pre, 0–1 s, 1–3 s, post). **(K)** Per-session median tracking error, open versus closed loop, for all 15 sessions (the two newly added mice outlined in black). **Closed loop is lower in 14 of 15 sessions (Wilcoxon signed-rank, p = 1.2 × 10⁻⁴).**
> ⚠ **Cohort mismatch to resolve before assembly:** F–J were computed on the original **13** sessions; only K includes m14/m15. Either regenerate F–J on the 15-session pool (lean path: `load(path,'data')`, see `pooled_new_mice.m`) or state the cohort per panel. Do not write "15 sessions" over panels that are still 13.
> Two more checks before submission: panel H is genuinely MAE and must stay labelled so (project decision 2026-07-16), and the 3H/3J *filenames* still say "MSE" although the metric is RMSE.
> Old panel **(K)** — the three-session step-response TF fit — is now **Fig 2 panel 2I**; do not describe it here.

### Figure 4 — draft caption *(three-block state-dependence reframe, 2026-07-29)*

> 🔴 **THIS CAPTION IS A PREDICTION THAT DID NOT HOLD — do not write from it. Annotated 2026-08-10.**
> The analyses it describes have since run and returned **null state slopes**. Four things changed:
>
> 1. **D/E are null, not graded.** `[IMP-STATE-QUARTILE]` on m4: **all four Spearman r_s null**
>    (motion OL −0.02 p=0.82 / CL −0.17 p=0.086; rel-δ OL +0.16 p=0.12 / CL −0.13 p=0.18).
>    `[IMP-XSTATE]` across 7 sessions: **no state slope survives** (motion OL +0.078 p=0.63 /
>    CL +0.086 p=0.88; rel-δ OL −0.028 p=0.94 / CL +0.118 p=0.30), Friedman over quartiles n.s.
>    (p=0.098 motion, p=0.69 δ). **What survives is the OFFSET:** OL−CL rejection gain is positive in
>    *every* quartile (+0.38/+0.37/+0.25/+0.62 motion; +0.51/+0.50/+0.46/+0.28 δ).
> 2. **The defensible claim is the opposite framing: rejection is state-INVARIANT.** A null with a
>    consistent OL−CL offset in every bin is a stronger control-theory statement than a slope
>    difference, and it is the opposite of the retracted var/δ "state-dependence" story.
>    ⇒ **The title sentence must be rewritten.** [user decision needed]
> 3. **The metric is retired.** Nick 2026-07-28 requires the **energy ratio**
>    `‖y_actual‖²/‖y_disturbance‖²` (1 = no work, <1 = controller gain), not ρ = ‖A−ref‖/‖G‖.
>    Every ρ number below is in old units and must be recomputed before it is quoted. [user decision needed]
> 4. **Good news not yet in the caption — C now replicates.** `[IMP-XSESS]`: median settled
>    ρ₁₋₃ **OL 1.306 ± 0.366 vs CL 0.879 ± 0.128**; per-session gain **+0.428, 95% CI [+0.228, +0.671],
>    signrank p = 0.0156, CL lower in 7/7 sessions.** Note CL sits **below 1** (net rejection) while OL
>    sits **above 1**. ⚠ Three gates before quoting: (a) **n = 7 sessions but n = 1 MOUSE** (all AL_0033) —
>    not an animal-level claim; (b) **6 of the 7 carry m4's seeded ROI** ([XROI] 2026-08-05) and need
>    re-running with per-session masks; (c) **predictor capacity spans 2→321 unaffected pixels**, and
>    Global is the *denominator* of ρ, so between-session comparisons are capacity-contaminated —
>    the new **R² ≥ 0.85 gate** (`utils/ctrl_r2_floor.m`) may disqualify some of them.
>
> Block 1 (panel A) is still **single-session with a bootstrap CI touching zero** ([−0.501, +0.001]);
> the cross-session sweep has not run. Panels A–E do not exist as PDFs — they are exploratory PNGs in
> `paper/images/predictor_saga/`.

**Figure 4. Closed-loop feedback decouples the controlled response from a state-dependent disturbance carried by the contralateral hemisphere.**
> Draft on the representative session (m4 = AL_0033, 2025-02-26); cross-session stats to fill from the sweep. Open loop red, closed loop blue. Rejection ρ over the 1–3 s steady-state window (0 = full rejection, 1 = disturbance passes).
>
> **(A)** Trial-average state dependence. The pre-stimulus brain state — quantified as the level of the stim-blind contralateral-derived prediction (Global) — predicts the true trial outcome (magnitude of the actual ipsilateral response over 1→3 s). Open loop shows a steep positive slope; closed loop is flat, showing that feedback decouples the outcome from ongoing state (bootstrap OL−CL slope difference, [Δslope], p = [p]). **(B)** Error-contribution model. Per-trial tracking error (RMSE) regressed on initial deviation, motion energy, and relative 2–4 Hz power; ΔR² for each factor over the base model. **(C)** Residual decomposition and rejection. The controlled ipsilateral response splits into a Global component (activity predicted from the contralateral hemisphere with no controller input — the disturbance) and a Local component (actual − Global, the controller effect); per-trial disturbance rejection ρ = ‖A−ref‖/‖G‖ over 1–3 s is lower in closed loop (median ρ [OL] vs [CL], rank-sum p = [p]). **(D)** ρ binned by pre-trial motion-energy quartile (low→high) and **(E)** by relative 2–4 Hz (delta) power quartile, open and closed loop; Spearman r_s per condition. State definitions are identical across all three blocks (motion −2 s→trial end; relative δ −2 s→stim end).
> Panel sources: A `ctrl_state_dependence.m` (`s_lvl→o_act`); B `cl_mse_factors.m` / `cl_rmse_factor_windows.m`; C `[IMP-PROOF-FIG]`/`[IMP-REJECT]`; D,E `[IMP-STATE-QUARTILE]` (`internal_model_principle.m`). Supplementary: contra→ipsi predictor CV-R² validity + distributed contralateral co-suppression (`stim_network_coupling.m`) supports treating Global as a shared-network disturbance.