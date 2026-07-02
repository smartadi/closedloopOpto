# FINDINGS.md — Research Findings Bridge

One entry per completed or in-progress finding.
Format: Question → Analysis → Result → Paper claim → Figure → Status

Analysis sessions **append** here when a question is answered.
Paper-writing sessions **read** this file — no need to grep RESEARCH.md or sub-area CLAUDs.

---

## Finding: Contra→ipsi predictor validated on Ye/Zhiwen data — our 0.925 ceiling is a DATA limit, not code/method
**Question:** Our CP-HEMI whole-hemisphere contra→ipsi pooled R² on AL_0033 plateaus at ~0.925 @rank10, ~0.065 below Ye et al. 2023's ~0.99. Is that gap in our CODE (ported primitives), our METHOD (whole-hemi split vs his Allen sensory-area restriction), or intrinsic to our DATA?
**Analysis:** `impulse-analysis/cp_zhiwen_validate.m` — positive control running OUR vendored `redoSVD`/`CanonCor2`/`sseExplainedCal` (K=50, train 1:40000/test 40001:60000, rank sweep, pooled `sseExplainedCal` over predicted-hemi pixels×test-time) on Zhiwen's own spontaneous session `AB_0004_20210330_1` (35.1 Hz, 82 min, hemo-corrected SVD, figshare). Two arms on the SAME data: **Arm A** = his exact atlas-registered sensory-area split (faithful port of `getReducedRankRegressionHEMI.m`, using his `tform`+Allen atlas); **Arm B** = whole-cortex hemisphere midline split (analogue of our AL_0033 CP-HEMI).
**Result:** Arm A (his sensory, his data) = **0.978@rank10, 0.989 peak** → reproduces his ~0.99. Arm B (whole-hemi, his data) = **0.971@rank10, 0.986 peak**. Our AL_0033 whole-hemi = **0.925@rank10** (reference). ⇒ (1) Arm A≈0.99 clears the CODE — our port is faithful. (2) Arm B≈Arm A (Δ≈0.007) clears the METHOD — whole-hemi split is not the cap; the sensory restriction buys almost nothing. (3) The identical whole-hemi pipeline reaches 0.971 on his prep but 0.925 on AL_0033 ⇒ the ~0.05–0.065 gap is DATA: lower bilateral coherence / SNR in the AL_0033 prep.
**Paper claim:** Reproducing Ye et al.'s hemisphere-to-hemisphere prediction (~0.99) with our own pipeline on their data confirms our contra→ipsi model is correctly specified; the lower ceiling on our prep reflects its intrinsic bilateral-coherence/SNR, not a modeling deficiency. (Referee answer to "why not 0.99".)
**Figure:** `impulse-analysis/data/cp_zhiwen_validate.png` (+ `cp_zhiwen_validate.mat`)
**Status:** OPEN — single Zhiwen session. Optionally replicate on a 2nd figshare session to bound variance.

## Finding: Predictability-vs-state — relative-δ effect does not replicate on Ye/Zhiwen data
**Question:** Our [CP-PREDQ] on AL_0033 found spontaneous contra→ipsi predictability (single-pixel local R²) rises with variance (+0.79) and abs δ-power (+0.67) — both retracted as signal-power CONFOUNDS (var is R²'s denominator) — leaving relative-δ (+0.29, δ/total, power-independent) as the one "genuine" state effect ("more predictable in synchronized states"). Does that relative-δ effect replicate on independent, cleaner, hemo-corrected data?
**Analysis:** `impulse-analysis/cp_zhiwen_predq.m` on Zhiwen `AB_0004_20210330_1` (spontaneous, 35 Hz, 82 min). Predictor = LEFT Allen-sensory redoSVD modes (K=50); target = representative RIGHT sensory pixel (median train-R², selected on train). 400 random 3-s windows from a held-out test block; per-window local R² vs {var, abs δ-power, relative δ}. Robustness across 150 sensory pixels. (Two artifacts fixed first: predicting the hemisphere MEAN → R²≈0.999 no range; K-modes→K-dim target near-degenerate → must predict FULL 200-dim signal from K=50 modes.)
**Result:** Variance +0.74 and abs-δ +0.34 CONFOUNDS replicate (expected). But **relative-δ FLIPS sign: −0.25** (robust: median −0.33, 99% of 150 pixels negative) vs our **+0.29**. So the sole power-independent predictability-state effect inverts on independent data ⇒ not a generalizable brain-state law; prep/task-specific (our task/stim widefield vs his passive spontaneous) or spurious. Motion (the cleanest AL_0033 claim = motion-null) is UNTESTED here — his data has no motion trace.
**Paper claim:** Do NOT claim a power-independent "predictability increases in synchronized (high relative-δ) states" relationship — it does not survive cross-dataset replication. Only the variance/power CONFOUND is reproducible, and it is an artifact of the R² metric, not a brain-state result.
**Figure:** `impulse-analysis/data/cp_zhiwen_predq.png` (+ `.mat`)
**Status:** OPEN — single Zhiwen session; recommend a 2nd session + partial-corr(relδ|var), and treat the AL_0033 relative-δ effect as unreplicated.

## Finding: Cleaner grid sessions show an interior cost minimum at moderate PI gains
**Question:** Does sweeping a grid of fixed PI controllers (Kp,Ki) yield a cost surface J(Kp,Ki) with a clear minimum that justifies the gains used in the main CL analysis?
**Analysis:** `controller-tuning/load_grid.m` → `gain_grid.m`. Final GRID set = 4 sessions (03-17 reclassified to autotune — its points are a continuous trajectory, not a lattice; 10-18 held — signal not regulatable). y = `states.csv` (% ΔF/F @35 Hz; for the 7-col AL_0034 session onsets are Timeline-derived with an auto-calibrated states logging-lag), cost = ||y−ref||₂ over a per-session window (`cwin`, default t=0–3 s; **AL_0034 10-17 uses [0 4] s** because it ran a 4 s stim — see dur=4 variant below), ref=−5, glitch-clipped, trials gated on |y(onset)|≤2.
**Result:** Across all 4, error is high at zero gain (no control), drops through a broad low-cost basin, and rises again at high gain (oscillation); the minimum sits at moderate gains:
  - AL_0033 2025-01-10 e2 (5 nodes, sparse): min **(0,0)** J=23.7 — degenerate (high-gain nodes oscillate so no-control "wins"); too sparse for a panel.
  - AL_0033 2025-03-03 e2 (13 nodes): min **corner (0.2,0.2)** J=17.4 — coarse high-gain sweep → optimum at boundary; fullest coverage.
  - AL_0033 2025-03-05 e1 (10 nodes): clean **interior** min **(0.05,0.1)** J=16.1; high-Kp nodes oscillate. **Cleanest.**
  - AL_0034 2024-10-17 e30 (17 nodes, **cross-mouse**, **dur=4 VARIANT**): this session ran a 4 s stim (vs 3 s elsewhere; confirmed 4.00 s on all 205 trials), so cost is scored over [0 4] s → min **(0.3,0.02)** J=30.2, broad low basin — replicates the basin structure in a 2nd mouse and shows the surface is robust to the cost-window/dur change. CAVEAT: dur & mouse covary (10-17 is the only dur=4 AND only AL_0034 grid), so this is a *variant exhibit of parameter dependence*, not a clean dur-controlled comparison.
**Paper claim:** A grid of fixed PI controllers yields a cost surface with a broad low-cost basin and a minimum at moderate gains; too-high gains oscillate, too-low gains leave a steady offset; the basin replicates across mice. Primary panel: 03-05 (interior min); 03-03 for fuller coverage; 10-17 for cross-mouse.
**Figure:** `controller-tuning/paper/images/tuning/grid_cost_surfaces_4sessions.png` (2×2 headline) + per-session `gain_cost_surface_*.png` / `gain_node_traces_*.png`
**Status:** Paper-ready. Panels promoted: T-A (03-05, primary interior min) + T-B (10-17, cross-mouse, dur=4 variant scored over [0 4] s). 10-17 cost-window question resolved: keep as a dur=4 parameter-dependence variant (per-session `cwin`).

## Finding: Online auto-tuning vs grid optimum — compared WITHIN MOUSE only
**Question:** Does the zero-order/model-free auto-tuner drive (Kp,Ki) toward the grid cost-minimum region — judged *same-mouse* (cross-mouse grid↔autotune comparisons are not meaningful; rule per AL 2026-06-29)?
**Analysis:** `controller-tuning/auto_tune.m`, per-trial cost = same ||y−ref||₂ metric as the grid. Pair each mouse's autotune sessions only against THAT mouse's grid.
**Result (same-mouse; "best controller" = lowest PER-CONTROLLER AVERAGE cost, not the optimistic single-trial running-best):**
  - **AL_0033** — grid basin (03-05 interior min ≈ (0.05,0.1), broad low-cost region): autotune best-avg **03-17 → (0.068,0.064) avgJ=15.1** lands squarely in that basin (clear running-best descent 17→11); **12-19 → (0.158,0.053) avgJ=23.7** higher-Kp/lower-Ki but in the broad low-cost region. → AL_0033 autotune settles in the AL_0033 grid's moderate-gain basin.
  - **AL_0034** — grid basin (10-17 min (0.3,0.02), broad/flat): autotune best-avg **10-25 e1 → (0.100,0.004) avgJ=23.2**, **e2 → (0.050,0.002) avgJ=20.3** — both low-Ki like the grid min but lower Kp; gains wander (e1), no tight convergence to (0.3,0.02). The flat basin makes a strong convergence claim unsupported here.
  - **Per-controller evaluation verified** (node-trace subplots, sorted by avg cost): in every session low-J controllers dip to −5 at t=0 and hold, the (0,0) no-control node is consistently worst (J≈21–37); caveats — n≈6–14 trials/controller (noisier than grid), and 03-17's (0.05,0.05) node has n=0 (all trials gated by |y(onset)|≤2).
  - ⚠ **CONVERGENCE VALIDITY (from the experiment's saved Kdata/Kval, 2026-06-29):** the accept-if-lowered search only genuinely converged where the ONLINE cost was live. **Valid: 03-17 (Kval 16.6→12.3, converged 0.068,0.064) and 10-25 e1 (Kval 11.9→4.6).** **Invalid: 12-19** — Kval≡0 (online `self.er` dead, AUDIT B2) → random walk; its landing is luck, NOT convergence. **10-25 e2** — stuck at (0,0) (nothing beat no-control). Show autotune trajectories from Kdata/Kval (accepted), NOT input_params (which logs every rejected probe). So the same-mouse convergence claim rests on **03-17 (AL_0033)** and **10-25 e1 (AL_0034)** only.
**Paper claim:** (tentative) Within mouse, model-free auto-tuning settles into the grid's low-cost basin (clearest in AL_0033 03-17); it explores rather than pinpoints when the basin is broad/flat (AL_0034). Do NOT compare an autotune session to a different mouse's grid.
**Figure:** PAPER PANEL T-C = `paper/images/tuning/autotune_convergence_both.pdf` — the two VALID sessions (AL_0033 03-17 + AL_0034 10-25 e1) side-by-side, each: accepted (Kp,Ki) path + Kval staircase (16.6→12.3 / 11.9→4.6). Singles: `autotune_convergence_AL_0033_0317.pdf`, `..._AL_0034_1025e1.pdf`. (Diagnostics for all 4 incl. invalid: `..._*.png`.)
**Status:** Paper-ready. T-C shows cross-mouse autotune convergence; same-mouse link to grid is AL_0033 (T-C left ↔ grid T-A).

## Finding: Dual-opsin photostim grid shows opposite-polarity responses by hemisphere
**Question:** Does the AL_0048 638 nm photostim site-grid (`opto_brainGrid638`) evoke the expected dual-opsin response polarity — excitatory left vs inhibitory right?
**Analysis:** `bilateral/grid/run_grid.py` (Python module) on AL_0048 2026-06-24/2. Per-site dF/F maps from 52 galvo positions × 50 reps (0.5 power), onsets/positions derived from raw Timeline + rig calibration. See `bilateral/grid/README.md`.
**Result:** Left-hemisphere sites (galvo x<0, excitatory opsin) give focal POSITIVE/red dF/F; right-hemisphere sites (x>0, inhibitory opsin) give NEGATIVE/blue, each localized near the stim site. Polarity flips cleanly across the midline.
**Paper claim:** (not yet in manuscript) Bilateral dual-opsin photostimulation produces spatially focal, opposite-sign cortical responses consistent with excitatory (left) and inhibitory (right) opsin expression.
**Figure:** `bilateral/grid/grid_png/grid_spatial.png` (exploratory PNG; not yet a paper panel)
**Status:** Analysis done; end-to-end pipeline validation. Not yet promoted to a paper figure.

## Finding: opto_brainGrid638 low power (0.25) did not lase
**Question:** The grid design specified two laser powers (`laserAmp` = [0.25, 0.5]); did both deliver stimulation in AL_0048 2026-06-24/2?
**Analysis:** `bilateral/grid/` Block-aligned power labeling (`loader.block_power_per_onset`) + direct probing of `lightCommand638`/`lightCommand594` at Block-predicted times.
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
**Status:** Single session (AL_0033 2025-01-29, n=748); **replication on AL_0041 e1/e2 PENDING** (needs interactive ROI draw). Stream = `impulse-analysis/contra_prediction.m` (sectioned workbench; `contra_residual.m` retired 2026-07-01) + `utils/cp_residual_core.m`. NB (2026-07-01): retargeted to the laser center [373,353] and DV switched to **L1-dev (predictability) primary** — the directional template-gain effect was a rim-pixel artifact; see RESEARCH.md 2026-07-01. Full chronological detail: RESEARCH.md 2026-06-17 → 2026-07-01.

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
