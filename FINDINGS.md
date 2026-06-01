# FINDINGS.md — Research Findings Bridge

One entry per completed or in-progress finding.
Format: Question → Analysis → Result → Paper claim → Figure → Status

Analysis sessions **append** here when a question is answered.
Paper-writing sessions **read** this file — no need to grep RESEARCH.md or sub-area CLAUDs.

---

## Finding: OL stimulation reduces trial-to-trial variance
**Question:** Does stimulation onset affect trial-to-trial variance, and how does OL compare to CL?
**Analysis:** `controller-analysis/variance_mse.m` (§variance slope) — slope-based analysis, n=13 OL sessions
**Result:** Pre-onset slope = −0.04 ± 0.14 (≈ zero); post-onset slope = −0.57 ± 0.24 (ΔF/F)²/s — consistently negative. OL stimulation itself reduces variance during the stim window.
**Paper claim:** "Open-loop stimulation modestly reduced across-trial variance during stimulation (post-onset slope −0.57 ± 0.24 (ΔF/F)²/s, vs. near-zero pre-onset slope −0.04 ± 0.14, n=13 sessions); closed-loop feedback produced a further and more consistent reduction."
**Figure:** `paper/images/figure2/onset_variance_slope.pdf` (panel 2E)
**Status:** Analysis done. Manuscript claim in `results_edit.tex` needs rewrite — current text says "did not affect variance" which is WRONG.

---

## Finding: Impulse peak scales approximately linearly with amplitude
**Question:** Is the cortical inhibitory response to optogenetic impulses approximately linear?
**Analysis:** `impulse-analysis/dose_response.m` — peak ΔF/F (inhibition energy, 0–200 ms) vs amplitude, n=3 sessions
**Result:** Linear fit R² annotated per session. Peak scales approximately linearly. Full waveform superimposition not yet verified.
**Paper claim:** "Peak inhibition energy scales approximately linearly with stimulus amplitude" (softer than current text — do NOT claim full LTI waveform scaling without waveform superimposition test).
**Figure:** `paper/images/figure2/imp_response.pdf` (panel 2B)
**Status:** Analysis done. Claim needs softening in `results_edit.tex` linearity paragraph. n=3 is low — either add sessions or state selection criterion explicitly.

---

## Finding: Transfer function fit describes impulse response (session 3)
**Question:** Can the amplitude-normalised mean impulse response be described by a low-order LTI transfer function?
**Analysis:** `impulse-analysis/tf_fit.m` — `tfest` sweep (1–3 poles, 0–2 zeros, 0–5 sample delay), AIC selection, LOAO cross-validation. Currently run on selExp=3 (AL_0033, 2025-01-29) only.
**Result:** Best model selected by AIC. LOAO R² validates generalisation across amplitudes. Per-amplitude R² computed.
**Paper claim:** Low-order TF (n poles, n zeros, transport delay) fits amplitude-normalised response with R²=X on held-out 20%. Supports LTI assumption for controller design.
**Figure:** `paper/images/figure2/tf_data_vs_model_AL_0033_2025-01-29_en1.pdf` (panel 2C), `paper/images/figure2/tf_loao_*.pdf`
**Status:** Done for session 3 only. OPEN: run across all 3 sessions and compare poles/time constants. Also: relax delay τ, report R² on held-out 20% test set (Nick, 2026-05-08).

---

## Finding: CL reduces MSE and variance vs OL across sessions
**Question:** Does the PI closed-loop controller reduce neural error and variance relative to open-loop?
**Analysis:** `controller-analysis/variance_mse.m` — 13 sessions (AL_0033 + AL_0039), MSE window t=0 to +3 s
**Result:** CL MSE lower than OL across sessions. CL variance trace lower than OL. Per-session violins show consistent effect.
**Paper claim:** Closed-loop PI control reduces trial MSE and across-trial variance relative to open-loop stimulation, consistent across n=13 sessions in 2 mice.
**Figure:** `paper/images/figure3/` panels A–H
**Status:** Analysis done. Figures exported. Manuscript text in `results_edit.tex` — verify general MSE window t=0→+3 s is stated; disturbance-rejection panel uses t=+1→+3 s.

---

## Finding: Pre-stimulus variance predicts trial MSE (OL more than CL)
**Question:** Does pre-trial brain state (variance) predict controller performance? Does CL decouple this?
**Analysis:** `controller-analysis/prestim_variance.m` (§K2) — pre-stim var (3 s window) vs MSE scatter, OL/CL regression slopes, n=13 sessions
**Result:** OL slope positive (higher pre-stim variance → higher MSE). CL slope near-flat. Motion-clean version (K2m) shows same pattern.
**Paper claim:** Pre-stimulus neural variance predicts trial outcome in open-loop but not closed-loop, indicating that feedback control decouples initial brain state from performance.
**Figure:** `paper/prestimvar_mse.pdf` (panel K2), `paper/prestimvar_mse_motclean.pdf` (K2m)
**Status:** Analysis done. NOT yet in manuscript. Add as new paragraph in results — this is the mechanistic argument for CL value.

---

## Finding: Motion predicts impulse response deviation
**Question:** Is trial-to-trial variability in inhibition depth predicted by motion state at stimulus onset?
**Analysis:** `impulse-analysis/motion_analysis.m` — z-score motion vs |Peak_imp deviation|, per session + pooled
**Result:** Motion z-score correlates with |Peak deviation|. Pooled scatter with r and p annotated. Binary Low/High motion classification.
**Paper claim:** Trials with higher peri-stimulus motion show greater deviation from the mean impulse response, suggesting motion as a source of trial-to-trial variability.
**Figure:** `paper/images/figure2/imp_motion_devscatter_*.pdf` (panel 2F single), `paper/images/figure2/imp_motion_devscatter_all_sessions.pdf` (panel 2F-pool)
**Status:** Analysis done. Figures promoted to paper panel 2F. Manuscript integration pending.

---

## Finding: Pre-stimulus 1–4 Hz power predicts impulse prediction error
**Question:** Does the spectral content of pre-stimulus neural activity (specifically 1–4 Hz low-frequency power) predict how well the TF model captures the trial's impulse response?
**Analysis:** `impulse-analysis/prestim_variance.m` — all motion-excluded trials pooled across amplitudes and sessions, sorted ascending by pre-trial variance. Pre-stimulus frequency spectrum (1 s window before stim) computed per trial. Trials pooled into batches of 20, batch-mean TF prediction error (|Peak_imp deviation|) computed and plotted against batch center trial rank. Linear fit through batch means.
**Result:** Trials with higher pre-stimulus variance (dominated by 1–4 Hz power, highlighted in heatmap) tend to show larger prediction error. Correlation r and p read from figure title at runtime.
**Paper claim (draft):** Pre-stimulus low-frequency (1–4 Hz) power predicts trial-by-trial impulse response prediction error (r = XX, p = XX), indicating that slow fluctuations in brain state set the gain of the inhibitory response beyond what the linear TF model captures.
**Figure:** `paper/images/figure2/prevar_heatmap_with_blockfit.pdf` (7 × 4 cm; panel **2H**; left: log power heatmap sorted by pre-stim var; right: 20-trial batch curve fit, X = prediction error, Y = trial rank)
**Status:** Figure code complete. Needs one run to verify and record r/p values. Manuscript paragraph not yet written.
**To finalise:** Run `prestim_variance.m`, read r/p from right panel title, update claim above, add parenthetical to `results_edit.tex`.

---

## OPEN: Three-layer contralateral prediction model
**Question:** How much of the trial-by-trial neural response can be predicted from contralateral activity alone, and does adding the stimulus (via TF model) account for the remainder?
**Analysis:** `controller-analysis/widebrain_arx.m` — ARX on spontaneous data. THREE LAYERS:
- Pink: predict ipsilateral ROI from contralateral pixels (spontaneous data only)
- Orange: pink + average OL impulse response on top
- Red: orange + exact per-trial laser sequence via TF model → compare to CL traces
**Result:** PENDING
**Paper claim:** PENDING — expected to frame MPC motivation
**Figure:** PENDING
**Status:** ARX baseline exists (`paper/wb_prediction.pdf`). R²_spont needs verification (target > 0.3). Pink/orange/red layers not yet implemented. Nick proposed 2026-05-11.

---

## OPEN: Curto & Issa-style trial-sorting figure
**Question:** Do trials starting in synchronised (high pre-stim variance) vs desynchronised (low pre-stim variance) states show different response patterns?
**Analysis:** `controller-analysis/prestim_variance.m` — split trials by ~1 s pre-stim variance; sort within groups by |ΔF/F| at t=0; display ΔF/F heatmaps OL and CL
**Result:** PENDING
**Paper claim:** PENDING
**Figure:** PENDING
**Status:** Not yet implemented. Nick proposed 2026-05-11. Reference: Curto, Bhatt & Issa (verify authorship before citing).

---

## OPEN: Post-hoc optimal laser sequence (MPC motivation)
**Question:** How close is the PI controller to the theoretically optimal controller for a given trial?
**Analysis:** Using the red contralateral model (once validated): compute MPC-optimal laser sequence for representative trials; quantify gap vs actual PI controller
**Result:** PENDING
**Paper claim:** PENDING — frames MPC as next step, justifies current PI as practical baseline
**Figure:** PENDING
**Status:** Depends on three-layer model being validated first.
