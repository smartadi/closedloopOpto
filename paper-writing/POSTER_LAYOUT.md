# Poster Layout — Brain Paper
*48" × 36" landscape · UW purple (#4B2E83) + gold (#85754D)*

---

## Story flow (left → right, top → bottom)

```
TITLE BAR (full width, purple)
────────────────────────────────────────────────────────────────────────
[Intro +  ] [  LTI Validation (18")                ] [Controller Perf (18.85")          ]
[System   ] [  Linear | Impulse TF | Step TF        ] [Var  | MSE  | Avg  || Sine wave   ]
[9.5"     ] [                                        ] [                                  ]  ← Row 1 (~19" tall)
────────────────────────────────────────────────────────────────────────
[Impulse Brain State (18")      ] [Controller Brain State (18")  ] [Conclusions (11")  ] ← Row 2 (~11" tall)
[Motion tertiles | Freq band    ] [Motion quartiles | Freq heatmap] [                  ]
────────────────────────────────────────────────────────────────────────
FOOTER BAR (purple)
```

---

## Panel-by-panel spec

### TITLE BAR
| Element | Content |
|---------|---------|
| Left placeholder | UW logo (replace manually) |
| Title | "Closed-Loop Widefield Control of Cortical Neural Activity via Optogenetics" |
| Authors | A. Dewan · N. Steinmetz · ¹Dept of Neuroscience, UW |
| Right placeholder | Dept/lab logo (replace manually) |
| Accent | Gold rule (0.18") below purple bar |

---

### ROW 1

#### C1 — Introduction + System (9.5" × 19")
| Sub-section | Content |
|-------------|---------|
| Motivation | 3 bullets: neural variability, brain state predicts response, OL can't compensate |
| Goal | 1 short paragraph: PI controller drives ΔF/F to −5%, reduces MSE, decouples brain state |
| Dataset | 2 mice · 11 sessions · AL_0033 (8) · AL_0039 (3) |
| Figure placeholder | Experimental schematic (widefield setup + laser) — **needs drawing** |

---

#### C2 — LTI Validation (18" × 19")
Divided into **left sub-column (8.5")** and **right sub-column (8.5")**, with a **full-width step TF strip at the bottom (~5.5")**.

| Sub-section | Width | Figure | File |
|-------------|-------|--------|------|
| Dose-Response Linearity (top-left) | 8.5" | Median ± 95th-pctile dose-response | `paper/imp_response_median.pdf` |
| Impulse TF — data vs model (top-right, left half) | 4.0" | TF fit for one session | `paper/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf` |
| Impulse TF — LOAO (top-right, right half) | 4.0" | R² full-fit vs LOAO across amps | `paper/tf_loao_AL_0033_2025-01-29_en1.pdf` |
| Step Response TF (bottom, full width) | 17.2" | OL step TF for 3 sessions | `paper/ol_tf_three_sessions.pdf` |

**Caption / logic to state:** Linearity (peak scales with amplitude) + TF dynamics (impulse) + same TF holds for step input → cortical response is LTI across stimulus types.

---

#### C3 — Controller Performance (18.85" × 19")
Upper 3/4 of panel: **3 side-by-side sub-figures** (each ~5.9" wide × ~11" tall).  
Lower 1/4: **Sine-wave tracking strip** (full panel width × ~5.5" tall).

| Sub-figure | Width | Figure | File |
|------------|-------|--------|------|
| Variance suppression (Fig F) | 5.9" | Cross-session variance trace OL vs CL | `paper/all_variance_sessions.png` |
| MSE reduction (Fig G) | 5.9" | Per-session violin t=+1→+3 s | `paper/all_MSE_sessions.png` |
| Trial-average convergence (Fig H) | 5.9" | Mean trial trace OL vs CL | `paper/all_average_sessions.png` |
| Sine-wave tracking (strip) | 17.6" | Trial-average ΔF/F for variable reference | `paper/trial_average_var.pdf` |

**Note on sine wave strip:** show only the trial average (not single trials, not variance). One representative session (AL_0041). Brief label: "Variable Reference Tracking". Caption: controller tracks sinusoidal reference with [X] ms latency.

---

### ROW 2

#### B1 — Impulse Brain State Dependence (18" × 11")
Split **left (8.5") = motion**, **right (8.5") = frequency**.

| Sub-section | Figure | File |
|-------------|--------|------|
| Motion: inhibition by tertile | Low/mid/high motion tertile mean ± SEM responses | `paper/imp_motion_traces.png` ✓ |
| Frequency: pre-stim spectral power | Representative mid-amplitude freq band | `paper/imp_freqband_AL_0033_2025-01-29_en1_amp5.png` ✓ |

**What to state:** High pre-stim motion and delta power both reduce impulse inhibition depth.

> **Open question:** the `imp_freqband_*` files are per-amplitude spectrograms. A combined figure showing pre-stim band power vs inhibition deviation would be a cleaner parallel to B2 right. Flag for future analysis in `Impulse_mouseDataAnalysis_all.m` if desired.

---

#### B2 — Controller Brain State Dependence (18" × 11")
Split **left (8.5") = motion**, **right (8.5") = frequency**.

| Sub-section | Figure | File |
|-------------|--------|------|
| Motion: MSE by quartile | OL vs CL MSE by motion quartile | `paper/motion_quartile_combined.png` ✓ |
| Frequency: spectral heatmap | MSE-sorted pooled spectral heatmap all sessions | `paper/freq_heatmap_combined.png` ✓ |

**What to state:** High-motion and high-delta-power trials have elevated MSE in OL. CL partially decouples MSE from both.

---

#### B3 — Conclusions (10.9" × 11")
| Sub-section | Content |
|-------------|---------|
| Key Findings (5 bullets) | LTI, MSE reduction, variance suppression, decoupling, spatial specificity |
| Future Directions (4 bullets) | Feedforward, three-layer model, MPC-optimal, Curto & Issa |
| Gold divider | Visual separator |
| Acknowledgments | Steinmetz lab, UW, [grant], IACUC |

---

## Open decisions before printing

1. **Impulse frequency panel**: Use existing `imp_freqband_*` per-amplitude spectrogram (mid amp), or generate a new combined figure showing pre-stim frequency band power vs inhibition deviation (better parallel to controller freq panel)?
2. **Controller motion figure**: `motion_quartile_combined.pdf` (traces) vs `motion_mse_combined.pdf` (scatter)?
3. **Sine wave session**: `trial_average_var.pdf` (generic) vs session-specific `trial_average_var_AL_0041_2026-04-13_en5.pdf`?
4. **Experimental schematic**: needs to be drawn and inserted into C1 placeholder.
5. **Kp/Ki values**: still needed for controller design bullet in C1.
6. **Author list + affiliations**: check with Nick before printing.

---

## Figure files referenced

| Poster panel | File |
|---|---|
| C2: Linearity | `paper/imp_response_median.pdf` |
| C2: Impulse TF data | `paper/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf` |
| C2: Impulse TF LOAO | `paper/tf_loao_AL_0033_2025-01-29_en1.pdf` |
| C2: Step TF | `paper/ol_tf_three_sessions.pdf` |
| C3: Variance | `paper/all_variance_sessions.png` |
| C3: MSE | `paper/all_MSE_sessions.png` |
| C3: Trial avg | `paper/all_average_sessions.png` |
| C3: Sine wave | `paper/trial_average_var.pdf` |
| B1 left: Impulse motion | `paper/imp_motion_traces.png` ✓ |
| B1 right: Impulse freq band | `paper/imp_freqband_AL_0033_2025-01-29_en1_amp5.png` ✓ |
| B2 left: Controller motion | `paper/motion_quartile_combined.png` ✓ |
| B2 right: Controller freq | `paper/freq_heatmap_combined.png` ✓ |

✓ = image currently in poster. PDFs were converted to PNG via pdftoppm at 220 DPI and saved as `*_poster-1.png` in `paper/`.