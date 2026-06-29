# FINDINGS.md — Research Findings Bridge

One entry per completed or in-progress finding.
Format: Question → Analysis → Result → Paper claim → Figure → Status

Analysis sessions **append** here when a question is answered.
Paper-writing sessions **read** this file — no need to grep RESEARCH.md or sub-area CLAUDs.

---

## Finding: Cleaner grid sessions show an interior cost minimum at moderate PI gains
**Question:** Does sweeping a grid of fixed PI controllers (Kp,Ki) yield a cost surface J(Kp,Ki) with a clear minimum that justifies the gains used in the main CL analysis?
**Analysis:** `controller-tuning/load_grid.m` → `gain_grid.m`. Final GRID set = 4 sessions (03-17 reclassified to autotune — its points are a continuous trajectory, not a lattice; 10-18 held — signal not regulatable). y = `states.csv` (% ΔF/F @35 Hz; for the 7-col AL_0034 session onsets are Timeline-derived with an auto-calibrated states logging-lag), cost = ||y−ref||₂ over t=0–3 s post-onset, ref=−5, glitch-clipped, trials gated on |y(onset)|≤2.
**Result:** Across all 4, error is high at zero gain (no control), drops through a broad low-cost basin, and rises again at high gain (oscillation); the minimum sits at moderate gains:
  - AL_0033 2025-01-10 e2 (5 nodes, sparse): min **(0,0)** J=23.7 — degenerate (high-gain nodes oscillate so no-control "wins"); too sparse for a panel.
  - AL_0033 2025-03-03 e2 (13 nodes): min **corner (0.2,0.2)** J=17.4 — coarse high-gain sweep → optimum at boundary; fullest coverage.
  - AL_0033 2025-03-05 e1 (10 nodes): clean **interior** min **(0.05,0.1)** J=16.1; high-Kp nodes oscillate. **Cleanest.**
  - AL_0034 2024-10-17 e30 (17 nodes, **cross-mouse**): interior-ish min **(0.3,0.02)** J=24, broad low basin — replicates the basin structure in a 2nd mouse.
**Paper claim:** A grid of fixed PI controllers yields a cost surface with a broad low-cost basin and a minimum at moderate gains; too-high gains oscillate, too-low gains leave a steady offset; the basin replicates across mice. Primary panel: 03-05 (interior min); 03-03 for fuller coverage; 10-17 for cross-mouse.
**Figure:** `controller-tuning/paper/images/tuning/grid_cost_surfaces_4sessions.png` (2×2 headline) + per-session `gain_cost_surface_*.png` / `gain_node_traces_*.png`
**Status:** Analysis done (4 sessions, wrapping up). Open: pick primary panel + promote to PAPER.md/PDF; decide 10-17 cost window (dur=4).

## Finding: Online auto-tuning does not visibly converge to the grid optimum
**Question:** Does the zero-order/model-free auto-tuner drive (Kp,Ki) toward the grid cost-minimum region?
**Analysis:** `controller-tuning/auto_tune.m` on AL_0034 2024-10-25 e1 (136 trials, gains adapt online); per-trial cost = same ||y−ref||₂ metric as the grid.
**Result:** Running-best cost reaches 15.6 at trial 55 (gains Kp=0.042, Ki=0.137) — a **different region** than the grid corner-min (0.2, 0.2). Gains keep wandering over the whole session (exploration) and the per-trial cost cloud shows **no clear downward trend**; convergence toward the grid optimum is not evident in this session.
**Paper claim:** (tentative, needs replication) Online zero-order tuning explores the gain space; clean convergence to the grid optimum is not yet demonstrated.
**Figure:** `paper/images/tuning/autotune_convergence_AL_0034_1025e1.png`
**Status:** Analysis done (single session). Open: verify the running-best/cost metric; check A(2)=AL_0034 10-25 e2 and A(3)=AL_0033 12-19 for cleaner convergence. (AL_0034 *grid* not yet available — 7-col onset blocker.)

## Finding: Dual-opsin photostim grid shows opposite-polarity responses by hemisphere
**Question:** Does the AL_0048 638 nm photostim site-grid (`opto_brainGrid638`) evoke the expected dual-opsin response polarity — excitatory left vs inhibitory right?
**Analysis:** `scratch_grid/grid_analysis.py` (Python port) on AL_0048 2026-06-24/2. Per-site dF/F maps from 52 galvo positions × 50 reps (0.5 power), onsets/positions derived from raw Timeline + rig calibration. See `scratch_grid/README.md`.
**Result:** Left-hemisphere sites (galvo x<0, excitatory opsin) give focal POSITIVE/red dF/F; right-hemisphere sites (x>0, inhibitory opsin) give NEGATIVE/blue, each localized near the stim site. Polarity flips cleanly across the midline.
**Paper claim:** (not yet in manuscript) Bilateral dual-opsin photostimulation produces spatially focal, opposite-sign cortical responses consistent with excitatory (left) and inhibitory (right) opsin expression.
**Figure:** `scratch_grid/grid_png/grid_spatial.png` (exploratory PNG; not yet a paper panel)
**Status:** Analysis done; end-to-end pipeline validation. Not yet promoted to a paper figure.

## Finding: opto_brainGrid638 low power (0.25) did not lase
**Question:** The grid design specified two laser powers (`laserAmp` = [0.25, 0.5]); did both deliver stimulation in AL_0048 2026-06-24/2?
**Analysis:** `scratch_grid/grid_analysis.py` Block-aligned power labeling + direct probing of `lightCommand638`/`lightCommand594` at Block-predicted times.
**Result:** Of 2600 detected 638 pulses, 2541 are 0.5-power and only 59 are 0.25. At the predicted times, 0.25-power trials show NO 638 or 594 command pulse (median peak −0.01 V, 0% over threshold) while 0.5 fires (~1.38 V gate). The 0.25 level was sub-threshold and did not lase.
**Paper claim:** (data-quality note, not a manuscript claim) Only the high-power condition produced usable photostim this session.
**Figure:** none (diagnostic)
**Status:** Resolved. A 0.25-power response map is NOT recoverable from this session. CONFIRM with experimenter whether 0.25 was expected to fire (laser/AOM threshold).

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
**⚠ 2026-06-22 TENSION:** the contra-residual stream's reproduced fig 6 (peakdev, pooled n=1467) shows motion → *less* |Peak dev| (more predictable: median No-motion 1.23 vs Motion 0.59, ranksum p=9e-11) — the OPPOSITE sign to this entry's "motion → greater deviation." Reconcile before relying on panel 2F (likely a metric difference — peakdev here vs the `dev_metric='cperr'` default this entry may have used — or a sign/interpretation error). See the next finding.

---

## PARTIAL: Local photoinhibition response is state-robust to motion; state-dependence lives in GLOBAL activity
**Status:** Single session (AL_0033 2025-01-29, n=748); **replication on AL_0041 e1/e2 PENDING** (needs interactive ROI draw). Stream = `impulse-analysis/contra_residual.m` (sectioned workbench) + `utils/cp_residual_core.m`. Full chronological detail: RESEARCH.md 2026-06-17 → 2026-06-22.

**Question:** Is the trial-to-trial variability of the LOCAL photoinhibition response brain-state dependent? Motivated by (a) the controller result — CL motion trials have lower MSE / are more "steerable"; and (b) the "Motion predicts impulse response deviation" finding above (fig 6), which is on the RAW ipsi signal (global + local mixed).

**Approach:** Predict the ipsi primary-pixel from contralateral SVD activity (instantaneous map, no lags, held-out R²≈0.90). Contra captures the GLOBAL/network activity into the ipsi kernel; residual = actual − contra = the LOCAL stim effect (orthogonal to concurrent contra). Per trial, take `|dip − amplitude-mean|` (the fig-6 deviation; lower = more predictable) for **Actual** (=fig 6), **Global** (contra pred), **Local** (residual); test vs motion, pre-stim variance, pre-stim 1–4 Hz delta. Decisive test = `partial(dev_stim, state | dev_pre)` (controls baseline contra-prediction quality). DVs z-within-amplitude.

**Results (AL_0033):**
- **Motion→predictability is REAL but GLOBAL, not local.** Pooled actual: median |Peak dev| No-motion 1.23 vs Motion 0.59 (ranksum p=9e-11) — a THRESHOLD/tail effect (high-motion trials avoid the bad-prediction tail; continuous r weak because motion is zero-inflated, ~8% of trials). Splitting the deviation by contra: the effect sits entirely in the **Global** component; the **Local** residual is motion-**NULL** (partial ρ=+0.003 p=0.93; per-amplitude even inverts at high amp — the biggest 4.90 V local deviation is a high-motion trial).
- **Local effect retains WEAK genuine state-dependence:** pre-stim VARIANCE partial ρ=+0.085 (p=0.022, survives), DELTA ρ=+0.073 (p=0.051, borderline). Synchronized/high-variance → larger local deviation; low-variance/desynchronized → more reproducible.
- **Mechanism / controller bridge:** motion indexes a low-variance, desynchronized global state (motion↔variance ρ=−0.20). That regime makes GLOBAL activity more reproducible → actual response more predictable, and (in CL) the controller faces less disturbance → lower MSE. The LOCAL stim response is state-robust except for the weak variance modulation.

**Claim (provisional, pending AL_0041):** The local photoinhibition response is largely state-invariant; the apparent state/motion dependence is a property of the GLOBAL cortical state (readable from the contralateral hemisphere), not of the local stimulus response. Pre-stim variance weakly modulates local reproducibility. This supplies the open-loop mechanism for the controller's motion→lower-MSE result.

**Caveats:** Single session. Raw residual recovers only ~21% of the dip magnitude (contra absorbs ~79% as stim bleed) — a lower bound on the local effect; irrelevant to the within-amp STATE result (per-amp constant cancels) but matters for absolute magnitude (use `decontam=true` / `cp_doseresponse.m`). `dev_stim` is a mean-squared deviation; **L1 (total absolute deviation) is a cleaner proposed DV** (var partial 0.100 p=0.007, delta 0.085 p=0.023) — not yet adopted. Inhibition-energy window stays 0–200 ms (trough 114 ms; 200–300 ms is rebound).

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
