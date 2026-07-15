# Paper TODO List

---

## NOTE
- large deviation in impulse prediction never have heavy motion energy / motion affected dynamics produce predictable impulse responses


## Scientific Claims to Fix (require analysis before editing)

These claims have identified problems and must be revisited before submission. Each has a `\todo{}` marker in `results_edit.tex` pointing to the issue.

- [ ] **Linearity claim too broad** (`results_edit.tex`, linearity paragraph): The paper tests linearity using peak ΔF/F vs amplitude only. Either (a) show that full trial-averaged waveforms superimpose after amplitude normalization, or (b) keep the "peak response scales approximately linearly" framing — but verify it is defensible as stated. Critical because the controller design assumes LTI dynamics.

- [ ] **Step-response internal tension** (`results_edit.tex` L49, `discussion.tex` L13): Text says "remained within a bounded set... consistent with marginally stable oscillatory dynamics" but the LTI claim implies convergence to steady state. Either state that the 3 s window is too short to observe steady state, or narrow the claim to what the step response actually shows (bounded, not converging).

- [ ] **Variance-convergence paragraph** (`results_edit.tex` L52): "Batch-mean variance decreasing with trial count" is a CLT consequence for *any* finite-variance process, including drifting ones. What you actually need to show is that the *batch mean itself* converges to a stable value across batch sizes. Verify whether Fig. S1 shows this; rephrase accordingly.

- [ ] **"Stimulation onset did not affect variance" claim** (`results_edit.tex` L50): **CLAIM IS WRONG — REVISE.** Variance slope analysis (n=13 OL sessions) shows pre-onset slope = −0.04 ± 0.14 (approx zero, high session variability) but post-onset slope = −0.57 ± 0.24 (ΔF/F)²/s — consistently negative. OL stimulation itself reduces variance during the stim window. Revised claim should be: *"Open-loop stimulation modestly reduced across-trial variance during stimulation (post-onset slope −0.57 ± 0.24 (ΔF/F)²/s, vs. near-zero pre-onset slope −0.04 ± 0.14, n = 13 sessions); closed-loop feedback produced a further and more consistent reduction."* This actually strengthens the paper — even OL reduces variance, CL does so more. Remove the `\todo{}` and rewrite L50 accordingly.

- [ ] **"Three independent sessions" for linearity** (`results_edit.tex` L36): n=3 is low given that Fig. 3 uses ~13 sessions. Either add remaining sessions or state the explicit selection criterion. Add n+CI on slope estimates.

---

## CL vs OL analysis
- [ ] add comparision purely focused on disturbance rejection, ie the last two seconds, so that activity settles for that refernce for both OL and CL.
- [ ] freq analysis we added was confusing Nick, and we shold rightfully use the absolute power values instead of using normalizations and ratios.
- [ ] **Controller performance vs initial state at stim onset**: add a section/plot showing trial MSE (OL and CL) as a function of |dF/F deviation from 0| at t=0 (stim onset). Per-trial scatter or binned mean +/- SEM, OL vs CL overlaid. Key question: does OL MSE increase with initial deviation (larger initial error → harder to correct passively) while CL MSE stays flat (feedback decouples initial state from outcome)? A flat CL slope vs steep OL slope is the mechanistic argument for why closed-loop control is valuable. Implement in `plottingScript.m` using `dk.ncDfk(:, c0_g2)` as the deviation measure per trial.



## Variable refernce plotting and literture
we have added a feedforward and a preview based controller to the experiment pipeline, we need to add the literature, results and discussions
- [ ] add plots for variable sine wave
- [ ] need to classify feedforward vs preview
- [ ] need to add coparision against naive CL.

## Manuscript corrections (Closedloop_edit)

### results_edit.tex
- [x] L16: Resolve `\aditya{}` comment about physiological delay — written out as proper sentence
- [x] L37: "This prompts to the fact" → "This suggests" — already fixed in file
- [x] L37: "a open loop" → "an open loop" — already fixed in file
- [x] L37: "supplimentary" → "supplementary" — already fixed in file
- [x] L37: Resolve `\aditya{add the figure as supplementary}` todo — already fixed in file
- [x] L54–55: Figure references `fig:figure1D` → `fig:figure2` — already fixed in file
- [x] L80–81: Figure 3 caption panel ordering — already correct in file
- [ ] L89: Fill in actual gain values for Kp and Ki (currently [X] placeholders) — defer, need data

### discussion.tex
- [x] L3: Duplicate "to" in steady-state sentence — already fixed in file
- [x] L39: "differes" → "differs" — already fixed in file
- [x] L67: "the=is controller" → "this controller" — already fixed in file
- [x] L87: Incomplete sentence — completed: "...so that the predicted tracking error over a future horizon is minimized."

### main.tex
- [x] L85: Removed `\aditya{separately editing}`, uncommented `\input{introduction}`
- [ ] L63–67: Fill in real author names and department affiliations — waiting on user input

### methods_edit.tex
- [x] L110: `\ref{fig:2}C` label format — already fixed in file
- [x] L447: `\ref{fig:4}A` label format — already fixed in file

---

## Figure Registry

---

### Paper panels in use
Panels that appear in Figure1–4.pdf. **Primary uniformity table — update size/format here whenever a panel changes.**
Figure total width = 17 cm. Font = 6 pt bold. Line widths: 1.5 pt mean, 1.2 pt fit, 0.4 pt individual trials.

| Panel | Fig | Source PDF | Size (cm W×H) | Format | Shading | Status |
|-------|-----|-----------|--------------|--------|---------|--------|
| 1A | Fig1 | paper/images/wfpath.pdf | — | — | — | external image |
| 1B | Fig1 | paper/images/schematic_optoephyswf (1).pdf | — | — | — | external image |
| 1C | Fig1 | paper/images/figure1/svd_frame_AL_0039_2025-04-19.pdf | — | vector | — | pending size |
| 1D | Fig1 | *(interface diagram — illustrator)* | — | — | — | external |
| 1E | Fig1 | *(control system — illustrator)* | — | — | — | external |
| 1F | Fig1 | *(latency image)* | — | — | — | pending |
| 2A | Fig2 | paper/images/figure2/imp_single_AL_0033_2025-01-29_en1.pdf | 5 × 4 | vector | — | trace_overlay.m |
| 2B | Fig2 | paper/images/figure2/imp_response.pdf | 5 × 4 | vector | — | dose_response.m |
| 2C | Fig2 | paper/images/figure2/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf | 6 × 4 | vector | ±std | done |
| 2D | Fig2 | paper/images/figure2/step_response.pdf | 6 × 4 | image 300dpi | — | step_response.m |
| 2E | Fig2 | paper/images/figure2/onset_variance_slope.pdf | 6 × 4 | vector | ±SEM | OL variance trace + slope lines; gray traces, red stim lines |
| 2F (supp) | Supp | paper/images/supplementary/imp_motion_devscatter_*.png | 6 × 4 | PNG 300dpi | — | Single-session only (selExp_mot=3); supplementary, not paper panel |
| 2F | Fig2 | paper/images/figure2/imp_motion_devscatter_all_sessions.pdf | 4 × 4 | vector | — | motion z-score vs inhib dev, all sessions pooled; impulse-analysis/motion_analysis.m fig_mvp |
| 2G | Fig2 | paper/images/figure2/prevar_vs_dev_allamps_motexcl_AL_0033_2025-01-29_en1.pdf | 4 × 4 | vector | — | pre-stim var vs inhib dev per amplitude (motion excluded); impulse-analysis/prestim_variance.m fig_pvm |
| 2H | Fig2 | paper/images/figure2/prevar_heatmap_with_blockfit.pdf | 7 × 4 | vector | — | heatmap (freq×trial sorted by pre-stim var) + trial-rank scatter + delta-power scatter; impulse-analysis/prestim_variance.m fig_pvs |
| 3A | Fig3 | paper/images/figure3/panel_A.pdf | 8.9 × 4 | vector | — | utils/analysisPlots_combined.m — single trial OL\|CL |
| 3B | Fig3 | paper/images/figure3/panel_B.pdf | 8.9 × 4 | vector | ±std | utils/analysisPlots_combined.m — all trials + avg OL\|CL |
| 3C | Fig3 | paper/images/figure3/panel_C.pdf | 8.9 × 3 | vector | — | utils/analysisPlots_combined.m — avg inputs OL\|CL |
| 3D | Fig3 | paper/images/figure3/panel_D.pdf | 3 × 3.5 | vector | — | utils/analysisPlots_combined.m — variance over time (single panel) |
| 3E | Fig3 | paper/images/figure3/panel_E.pdf | 3 × 3 | vector | — | utils/analysisPlots_combined.m — MSE half-violin (single panel) |
| 3F | Fig3 | paper/images/figure3/all_variance_sessions.pdf | 3 × 3.5 | vector | ±SEM | variance_mse.m fig_F — cross-session variance trace |
| 3G | Fig3 | paper/images/figure3/all_average_sessions.pdf | 3 × 4 | vector | ±SEM | step_response.m fig_H — per-session faint + bold mean |
| 3H | Fig3 | paper/images/figure3/all_MSE_sessions.pdf | 7.8 × 4 | image 300dpi | — | variance_mse.m fig_G — cross-session MSE violin; mean dot too large (open task) |
| 3I | Fig3 | paper/images/figure3/variance_ratio_by_window.pdf | 5 × 4 | vector | — | variance_mse.m fig_Fr — OL/CL variance ratio: Pre/Stim/Post; Wilcoxon stars |
| 3J | Fig3 | paper/images/figure3/MSE_ratio_by_window.pdf | 5 × 4 | vector | — | variance_mse.m fig_G2r — OL/CL RMS MSE ratio: Pre/0–1s/1–3s/Post |
| 3K | Fig3 | paper/images/figure3/ol_tf_trial_avg.pdf | 12 × 4 | vector | ±std | tf_fit.m fig_tf_paper — OL trial avg + TF pred, 3 sessions |
| 4 (system) | Fig4 | *(feedforward control system — illustrator)* | — | — | — | external |
| 4A | Fig4 | paper/images/figure4/sine_4A_{OL,OL_prev,CL,CL_prev}_AL_0048_{2026-07-01_6,2026-07-14_1}.pdf | 4 × 4 | vector | — | sine_ff_paper_panels.m — per-mode all trials (grey) + mean (mode colour) + reference; 4 modes × 2 sessions = 8 files |
| 4B | Fig4 | paper/images/figure4/sine_4B_trialavg_AL_0048_*.pdf | 6 × 4 | vector | ±SEM | trial-avg of all 4 modes + reference, one file per session |
| 4C | Fig4 | paper/images/figure4/sine_4C_variance_AL_0048_*.pdf | 5 × 4 | vector | — | across-trial variance over time, 4 modes |
| 4D | Fig4 | paper/images/figure4/sine_4D_mse_violin_AL_0048_*.pdf | 5 × 4 | vector | — | trial MSE half-violins, 4 modes (+ Wilcoxon in console) |
| 4E | Fig4 | paper/images/figure4/sine_4E_mse_time_AL_0048_*.pdf | 5 × 4 | vector | ±SEM | MSE over time — **CL+prev is the only mode whose error falls within the trial (both sessions)** |
| 4F | Fig4 | paper/images/figure4/sine_4F_gain_phase_AL_0048_*.pdf | 5 × 4 | vector | — | 1 Hz gain (bars) + phase lag (squares) — preview's lag cancellation |
| T-A | Methods fig:cost_landscape | paper/images/tuning/grid_cost_surface_AL_0033_0305.pdf | 6 × 5 | vector | — | gain_grid.m — PI gain-grid cost surface J(Kp,Ki), AL_0033 03-05 (PRIMARY: clean interior min ~0.05,0.1) |
| T-B | Methods fig:cost_landscape | paper/images/tuning/grid_cost_surface_AL_0034_1017.pdf | 6 × 5 | vector | — | gain_grid.m — same, AL_0034 10-17 — **dur=4 VARIANT**: this session ran a 4 s stim (vs 3 s elsewhere) so J is scored over [0 4] s (parameter-dependence exhibit). CROSS-MOUSE replication of low-cost basin. min J=30.2 at (Kp=0.3,Ki=0.02). CAVEAT: dur & mouse covary (10-17 is the only dur=4 AND only AL_0034 grid) → variant exhibit, not a clean dur-controlled comparison |
| T-C | Methods fig:cost_landscape | paper/images/tuning/autotune_convergence_both.pdf | 12 × 8 | vector | — | AUTO-TUNE convergence, BOTH mice side-by-side (AL_0033 03-17 + AL_0034 10-25 e1); accepted Kdata/Kval — (Kp,Ki) path + cost staircase (16.6→12.3 / 11.9→4.6). Singles also exported: `autotune_convergence_AL_0033_0317.pdf`, `..._AL_0034_1025e1.pdf` |

> **Fig 4 sine-wave (feedforward) section — AL_0048, right/inhibitory, 1 Hz sine, 4 s.** Source: `bilateral/sine_ff_paper_panels.m` (run after `bilateral/load_bilateral.m`). Design is **4-mode**, not OL-vs-CL binary: `ff_analysis_cond` 2=OL, 1=OL+preview, 3=CL, 0=CL+preview (rig "FF Analysis" button). Colour code: **red family = open loop, green family = closed loop; lighter = +preview**.
> **Two sessions exported side-by-side** (Illustrator: one column each) — s1 `2026-07-01/6` (87 trials; Kp .08, **Ki .01**, Kref .075, amp 3) and s2 `2026-07-14/1` (200 trials; Kp .08, **Ki 0**, Kref .05, amp 2).
> **Paper-ready claims (what replicates):** (a) **Feedback reduces tracking error** — OL vs CL Wilcoxon **p=0.0046 (s1, n=43)** and **p=0.00077 (s2, n=97)**; the robust result, significant across both parameter settings. (b) **Preview cancels the plant's phase lag** — 156→−5 ms (s1) and 168→15 ms (s2) for OL, 125→13 / 101→−26 ms for CL; `previewT_steps=5` = **143 ms @35 Hz ≈ the measured ~160 ms lag**, i.e. the lookahead is matched to the delay. (c) **CL+preview is the only mode whose error falls within the trial** in BOTH sessions (14.41→11.88 and 16.07→13.45 for 0–1 s vs 1–4 s) — panel 4E.
> **Claims caveats (read before writing):** (i) **Preview's MSE benefit does NOT replicate** — it helped in s1 (OL 28.2→20.6) but not s2 (20.2→23.7, p=0.32), because preview raised OL variance (17.9→23.2); report preview as lag-cancellation + settling, **not** as an MSE reduction. (ii) The two sessions differ in Ki/Kref/amp → **absolute MSE is not comparable across sessions**; only within-session mode contrasts are. Ki=0 in s2 is the prime suspect for the preview difference — a matched-parameter rerun is the clean test. (iii) dF/F is **uncorrected blue SVD** (`corr/` holds only temporal comps; `getpixel_dFoF` falls back to blue). (iv) s2's MSE distribution has heavy outliers (trials to ~250–300) — motion exclusion (`motThresh=1.5`) not yet applied; Wilcoxon is rank-based so p-values hold, but means are skewed. (v) Onsets come from `traj_on` epochs, NOT `findStims` (whose `horizon` fallback puts them ~36 s early — see RESEARCH.md 2026-07-15). Full detail: RESEARCH.md.

> Secondary-analysis "controller tuning" figure (gain grid + auto-tuning). **METHODS-ONLY** (AL 2026-06-29): lives as `fig:cost_landscape` in `methods_edit.tex` §gain_opt (A=grid 03-05, B=grid 10-17 cross-mouse, C=autotune both mice) — NO Results section / no main figure number.
> **Paper-ready panel set:** **Grid** — T-A cost surface AL_0033 03-05 + T-B AL_0034 10-17 (cross-mouse basin replication). **Auto-tune** — T-C convergence in BOTH mice side-by-side (cost descends monotonically → the model-free tuner works across mice). **Same-mouse link:** AL_0033 grid basin (T-A, ≈0.05,0.1) ≈ where AL_0033 autotune settles (T-C left, 0.068,0.064).
> **Methods/claims caveats (read before writing):** (a) cost = `mean(||y−ref||₂)` over t=0–3 s (per-session `cwin`; **T-B/10-17 uses [0 4] s** because it ran dur=4), y=`states.csv` (% ΔF/F, online kernel-mean), ref=−5; (b) autotune = greedy zero-order, accept-if-cost-lowered; show trajectories from accepted `Kdata`/`Kval`, NOT `input_params` (which logs rejected probes); (c) only 03-17 (+10-25 e1) are valid convergence demos — 12-19 had a dead online cost (random walk), 10-25 e2 stuck at (0,0); (d) grid↔autotune comparisons are SAME-MOUSE only; (e) the rig autotune cost/annealing was fixed 2026-06-29 (StLab_Rainier) for FUTURE runs — recorded sessions predate it. Full detail: FINDINGS.md + controller-tuning/CLAUDE.md.

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

#### widebrain_arx.m  (Fig 4 — widebrain / contralateral prediction)

| Var | Size (cm W×H) | Export path | Format | Active? | Notes |
|-----|--------------|-------------|--------|---------|-------|
| fig_wb1 | 16 × 5 | paper/images/figure4/wb_pink_4panel.pdf | vector | yes | ARX pink prediction: 4 panels (OL/CL trace, residual, R²) |
| fig_wb4 | 12 × 4 | paper/images/figure4/wb_three_layers.pdf | vector | yes | Three-layer contralateral prediction (pink/orange/red) |
| fig_wb5 | 6 × 4 | paper/images/figure4/wb_mpc_gap.png | image 300dpi | yes | WB-5 MSE gap (CL vs OL residuals) |
| fig_spat | auto | paper/images/figure4/wb_spat_traces.png | image 300dpi | yes | Spatial spread of contralateral signal |

#### controller-analysis/motion_analysis.m  (candidate Fig 4 panels)

| Var | Size (cm W×H) | Export path | Format | Active? | Notes |
|-----|--------------|-------------|--------|---------|-------|
| fig_ps_mse | 6 × 4 | paper/images/figure4/prestim_dev_vs_mse.pdf | vector | yes | Pre-stim state deviation vs MSE (OL+CL) |
| figQp | 6 × 4 | paper/images/figure4/motion_quartile_combined.pdf | vector | yes | Motion quartile MSE summary (pooled sessions) |

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
  row1:  3I(5×4)  3J(5×4)

supp:  3K(12×4)
```
Fit checks (last computed, gap=0.3):
- col2 row1 @H=3.5: D(3→3.00) E(3→3.50) + 0.3 = **6.8/7.8** ✓ (+1.0)
- col2 row2 @H=4.0: F(3→3.43) G(3→3.00) + 0.3 = **6.7/7.8** ✓ (+1.1)
- col2 row3: H(7.8) = **7.8/7.8** ✓ (exact fit — updated from 8×4)
- col1 heights: 4+4+3 + 2×0.3 = **11.6 cm** total
- Row height match: row1 A=4 vs D/E=3.5 (⚠ 0.5 cm gap) · row2 B=4 vs F/G=4 ✓ · row3 C=3 vs H=4 (⚠ 1.0 cm gap)
- section2 row1: 5+5 + 0.3 = **10.3/17** ✓ (+6.7 — can widen panels)

---

#### Fig 4  [total=17  gap=0.3]
Sine-wave (feedforward) section — panels exported individually, stitched in Illustrator.
Two session columns: **s1 = 2026-07-01/6 (87 tr, Ki .01)**, **s2 = 2026-07-14/1 (200 tr, Ki 0)**.
`_s1` / `_s2` = the two per-session files of the same panel.
```
row0:  4(system)(?×?)[ext]

row1:  4A_OL(4×4)  4A_OLprev(4×4)  4A_CL(4×4)  4A_CLprev(4×4)      <- one session per row
row2:  4A'_OL(4×4) 4A'_OLprev(4×4) 4A'_CL(4×4) 4A'_CLprev(4×4)     <- other session

row3:  4B_s1(6×4)   4B_s2(6×4)
row4:  4C_s1(5×4)   4D_s1(5×4)   4E_s1(5×4)
row5:  4C_s2(5×4)   4D_s2(5×4)   4E_s2(5×4)
row6:  4F_s1(5×4)   4F_s2(5×4)
```
Fit checks (gap=0.3 cm):
- row1/row2: 4×4.0 + 3×0.3 = **16.9/17** ✓ (+0.1)
- row3: 6+6 + 0.3 = **12.3/17** ✓ (+4.7 — room for the system diagram alongside)
- row4/row5: 5+5+5 + 2×0.3 = **15.6/17** ✓ (+1.4)
- row6: 5+5 + 0.3 = **10.3/17** ✓ (+6.7)


#### Fig 5