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
| 2A | Fig2 | paper/images/figure2/imp_single_AL_0033_2025-01-29_en1.pdf | — | vector | — | pending size |
| 2B | Fig2 | paper/images/figure2/imp_response.pdf | — | vector | — | pending size |
| 2C | Fig2 | paper/images/figure2/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf | 6 × 4 | vector | ±std | done |
| 2D | Fig2 | paper/images/figure2/step_response.pdf | — | image 300dpi | — | pending size |
| 2E | Fig2 | paper/images/figure2/onset_variance_slope.pdf | 6 × 4 | vector | ±SEM | OL variance trace + slope lines; gray traces, red stim lines |
| 2F | Fig2 | paper/images/figure2/imp_motion_devscatter_*.pdf | 6 × 4 | vector | — | Motion z-score vs \|Peak dev\| — single session (selExp_mot=3); binary No motion/Motion |
| 2F-pool | Fig2 | paper/images/figure2/imp_motion_devscatter_all_sessions.pdf | 6 × 4 | vector | — | Same scatter pooled across all sessions; r and p annotated |
| 3A | Fig3 | paper/images/figure3/panel_A.pdf | 8.9 × 4 | vector | — | utils/analysisPlots_combined.m — single trial OL\|CL |
| 3B | Fig3 | paper/images/figure3/panel_B.pdf | 8.9 × 4 | vector | ±std | utils/analysisPlots_combined.m — all trials + avg OL\|CL |
| 3C | Fig3 | paper/images/figure3/panel_C.pdf | 8.9 × 3 | vector | — | utils/analysisPlots_combined.m — avg inputs OL\|CL |
| 3D | Fig3 | paper/images/figure3/panel_D.pdf | 8.9 × 3.5 | vector | ±std | utils/analysisPlots_combined.m — variance over time |
| 3E | Fig3 | paper/images/figure3/panel_E.pdf | 8.9 × 3 | vector | — | utils/analysisPlots_combined.m — MSE half-violin |
| 3F | Fig3 | paper/images/figure3/all_variance_sessions.pdf | 3.5 × 3 | vector | — | done |
| 3G | Fig3 | paper/images/figure3/all_average_sessions.pdf | 3 × 4 | vector | ±SEM | done |
| 3H | Fig3 | paper/images/figure3/all_MSE_sessions.pdf | 9 × 4 | image 300dpi | — | done — mean dot too large |
| 3I | Fig3 | paper/images/figure3/ol_tf_trial_avg.pdf | 12 × 4 | vector | ±std | OL trial avg + TF pred, 3 sessions |
| 4 (system) | Fig4 | *(feedforward control system — illustrator)* | — | — | — | external |
| 4A | Fig4 | *(single trial OL/CL — sine wave)* | — | vector | — | pending |
| 4B | Fig4 | *(trial avg OL/CL — sine wave)* | — | vector | ±std | pending |
| 4C | Fig4 | *(trial avg input OL/CL — sine wave)* | — | vector | — | pending |
| 4D | Fig4 | *(variance across trials — sine wave)* | — | vector | — | pending |
| 4E | Fig4 | *(trial MSE dist — sine wave)* | — | vector | — | pending |

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

#### plottingScript.m

| Var | Size (cm W×H) | Export path | Format | Active? | Notes |
|-----|--------------|-------------|--------|---------|-------|
| fig_F | 3.5 × 3 | paper/images/figure3/all_variance_sessions.pdf | vector | yes | Cross-session variance trace |
| fig_G | 9 × 4 | paper/images/figure3/all_MSE_sessions.pdf | image 300dpi | yes | Cross-session MSE violin |
| fig_G2a | 8 × 5 | paper/MSE_window_comparison.pdf | vector | **commented** | Trial-avg trace OL vs CL (replaced violins) |
| fig_G2b | nC×5 × nR×4 | paper/MSE_vs_trial_number.png | image 300dpi | yes | Windowed RMS MSE vs trial# |
| fig_H | 3 × 4 | paper/images/figure3/all_average_sessions.pdf | vector | yes | Per-session faint + bold mean |
| fig (step) | auto | paper/images/figure2/step_response.pdf | image 300dpi | yes | OL step response, sessions [4 9 11] |
| fig (spont) | 15 × 10 | paper/spont_variance.png | image 300dpi | yes | Bootstrap variance convergence |
| figC | auto | paper/motion_mse_combined.png | image 300dpi | yes | Motion vs MSE pooled scatter |
| fig_I | nSess×11.4 × nRows×8.9 | paper/freq_heatmap_sessions.png | image 300dpi | yes | Per-session spectral heatmap |
| fig_J | 25.4 × 15.2 | paper/freq_heatmap_combined.png | image 300dpi | yes | All-session pooled heatmap (MSE sort) |
| fig_J2 | 25.4 × 15.2 | paper/freq_heatmap_motionclean.png | image 300dpi | yes | J, motion-clean |
| fig_K1 | 25.4 × 15.2 | paper/freq_heatmap_prestimvar.png | image 300dpi | yes | Pre-stim var sort heatmap |
| fig_K2 | 6 × 4 | paper/prestimvar_mse.png | image 300dpi | yes | Pre-stim var vs MSE scatter |
| fig_K1m | 25.4 × 15.2 | paper/freq_heatmap_prestimvar_motclean.png | image 300dpi | yes | K1 motion-clean |
| fig_K2m | 6 × 4 | paper/prestimvar_mse_motclean.png | image 300dpi | yes | K2 motion-clean |
| fig_K1w | 25.4 × 15.2 | paper/freq_heatmap_pretrial_var.png | image 300dpi | yes | Pre+trial var sort heatmap |
| fig_K2w | 6 × 4 | paper/pretrial_var_mse.png | image 300dpi | yes | Pre+trial var vs MSE scatter |
| fig_wb | 12 × 8 | *(no export)* | — | no export | Widebrain ARX 4-panel |
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

#### Uniformity checklist
- [ ] Font: 6 pt bold throughout — audit `Impulse_mouseDataAnalysis_all.m` (currently uses 5–10 pt)
- [ ] Shading: ±std for single-session traces, ±SEM for cross-session means — audit `fig_H`, `fig_F`
- [ ] Line widths: mean=1.5, fit=1.2, individual trials=0.4, ref=1.0, input=0.75, zero=0.5
- [ ] Scalebars: `shortCornerAxes_plot` with LineWidth=1.5, LabelGap=0.05, FontSize=6, FontWeight='bold'
- [ ] Export: `exportgraphics(...,'ContentType','vector')` for all line-art; 300 dpi PNG for heatmaps
- [ ] fig_wb: needs exportgraphics added once ARX R²_spont > 0.3 confirmed

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


### Figure panels
Figures are created in illustrator by importing pdfs, panels exported as pdf. Each figure is 17cm wide, height depends on rows 

Figure1 System Architecture
---
Row 1
---  
- A microscope image (paper/images/wfpath.pdf)
- B mouse (paper/images/schematic_optoephyswf (1).pdf)
- C brain (paper/images/figure1/svd_frame_AL_0039_2025-04-19.pdf)
- D interface diagram
---
Row 2
---
- E control system 
- F Latency image


Figure 2 :: Input output charactereization
---
Row 1
--- 
- A single session stim responses (paper/images/figure2/imp_single_AL_0033_2025-01-29_en1.pdf)
- B multi session inhibition eenrgy (paper/images/figure2/imp_response.pdf)
- C Single Session TF fit (paper/images/figure2/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf)
---
Row 2
---
- D TF fit step response
- E Variance quantification (paper/images/figure2/onset_variance_slope.pdf)
- F Motion vs inhibition deviation (paper/images/figure2/imp_motion_devscatter_*.pdf)


Figure 3 :: analysis stationary reference
---
Column 1
--- 
- A single trial OL/CL (paper/images/figure3/panel_A.pdf)
- B Trial avg OL/CL (paper/images/figure3/panel_B.pdf)
- C Trial avg inp OL/CL (paper/images/figure3/panel_C.pdf)
---
Column 2
---
row 1
- D variance across trials (paper/images/figure3/panel_D.pdf)
- E Trial MSE distribution (paper/images/figure3/panel_E.pdf)
row 2
- F avg Variacne across all experiments (paper/images/figure3/all_variance_sessions.pdf)
- G avg Tracking error across all experiments (paper/images/figure3/all_average_sessions.pdf)
row 3
- H All sessions Trial error distributions, (need to make the size of the dots representing the mean smaller) (paper/images/figure3/all_MSE_sessions.pdf) 


Figure 4:: Sine wave Reference
Row 1
- Feedforward Control system
Row 2 (need pdf versions with appropriate sizes)
column 1
- A single trial OL/CL 
- B Trial avg OL/CL 
- C Trial avg inp OL/CL 
- D Variance Across trials, E Trail MSE Dist
column 2
- A single trial OL/CL 
- B Trial avg OL/CL 
- C Trial avg inp OL/CL
- D Variance Across trials, E Trail MSE Dist 
