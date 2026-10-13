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

### 2026-10-12 — Manuscript: Fig 2C–F numbers + seeded-start Methods sentence (Closedloop_edit draft, uncommitted)
**Changed:** `scratchpad/apply_ms_1012e.py`:
- `results.tex`:
  - 2F caption triangles are now "(Mice 1a, 1b and 3)";
  - pooled CV 0.85 → 0.90;
  - swap cross 0.68 → 0.69;
  - rebound clause: "0.27 s in Mouse 2, beyond … in Mouse 1b, and no decay … in Mice 1a and 3".
- `discussion.tex` L9: 2-pole vs main is now "0.81 against 0.90", and the sentence is reworded. "Nearly as well" no longer holds; it now reads "kept more than one pole pair because a single damped oscillation predicted held-out trials less well … and because the extra poles separate …".
- `methods_rewrite.tex`, after the selection rule: the Mouse 3 seeded initialization (default start best R² 0.94; one data-built candidate per session; selected only in Mouse 3, 5p4z, R² 0.99; held-out and bootstrap refits started from it).
- The dip sentences (0.11 s in 3/4, median 0.113, 2.4–4.2 Hz) and the other session's model-order sentence are already correct.

**Why:** the seeded rerun (entry below).
**Next:**
- 2F caption censoring "43–73%" waits on `bootsplit_batch` (failed vs beyond).
- Adversarial check of the edits.
- Commit on draft (no push). Mouse 3 values stay provisional until the hemo recompute.

### 2026-10-12 — Fig 2C–F rerun with the seeded fit (Mouse 3 onset-referenced; May-2021 hemo still)
**Found:** the `matlab -batch` run of `scratchpad/tfseed_run.m` (`imp_tf_run` 55 min → `imp_tf_cv` 18 min → 2-pole CV 10 min, PAPER_FINAL on).
- **Fits:** Mice 1a, 1b and 2 are identical to the 10-11 new pass (3p1z0d / 4p3z0d / 4p3z0d, same τ and R²h). Mouse 3 selects the SEEDED 5p4z0d (R²h 0.994, AIC rule, no escalation). Its τ are 1768 s (offset mode), 0.500, 0.187, and a 0.1435 s dip pair at 3.25 Hz.
- **2F:** dip τ 0.1055 / 0.1117 / 0.1141 / 0.1435 → median 0.113 s, and three of four sessions at ≈0.11 s. Dip frequencies 2.43 / 4.12 / 4.19 / 3.25 Hz, so 2.4–4.2 Hz is unchanged.
  - Rebound: Mouse 2 0.268 s. Mice 1a, 1b and 3 are beyond the window (triangles); Mice 1a and 3 show no decay within it.
  - Bootstrap `tauBootReject` (includes failed refits): 41 / 73 / 3 / **100%**. Every Mouse 3 draw is rejected because its slowest mode is the offset pole. The failed vs beyond split is being replayed in `bootsplit_batch.m`.
- **2D CV:** 0.561 / 0.833 / 0.950 (identical to 10-11) / **0.957** [0.922, 0.975] for Mouse 3 (was 0.841 at 4p2z0d, 10% folds failed; now 0%). The pooled median goes **0.845 → 0.898**.
- **2E swap:** self 0.992, cross 0.691 (was 0.68).
- **2-pole CV:** Mouse 3 2p0z0d 0.871 (was 0.876); pooled 0.813 (was 0.809).
- **Exports:**
  - `tf_cv_2D_sidebar`, `tf_cv_single_AL_0033` and `tf_model_swap` were mirrored to figures_final.
  - **`tf_tau_forest.pdf` was NOT mirrored, because the file was locked (open in Illustrator).** Its `paper/images/figure2` copy is current. To re-mirror, close the file and run `imp_tf_figs` with PAPER_FINAL on.
- **Fixed:** the "only %d/%d bootstrap refits usable" fprintf had its arguments in the wrong order, which garbled the log. `T.tauBootFail` / `T.tauBootBeyond` are added so the 2F caption can report only the beyond-window share.

**Why:** the user chose the seeded fit (option B). These are the numbers with the onset-frame reference.
**Next:**
- Update the manuscript 2D–2F and Discussion numbers on draft.
- Re-mirror tau_forest.
- ⚠ Mouse 3's CV refits are warm-started from the full-data model (a basin-choice leak, like the order choice). Check it with per-fold seeds.
- All Mouse 3 numbers are provisional until its hemo correction is recomputed (TASKS 🔴).

### 2026-10-12 — Supp state rasters locked: pooled, all columns 0–0.5 s
**Changed:**
- `imp_state_raster_supp.m`:
  - the activity column is now 0–0.486 s, so all three columns share one span (it was −1 to +0.5 s);
  - removed the onset line;
  - the colorbar is a horizontal strip under the grid;
  - export goes through `paperExport(...,300)`, so the PAPER_FINAL mirror picks it up.
- `MANIFEST.txt [supplementary]` gains `supplementary/supp_state_raster.png`. `PAPER.md` gains the S-state rasters row.
- Exported `figures_final/panels/supplementary/supp_state_raster.png` (16.08 × 13.61 cm @300 dpi).

**Why:** User: "pooled, keep all column length same ie 0-500 ms activity".
**Next:** Write the caption plus a `supplementary.tex` float, and cite it from the 2G Results paragraph. Optionally make the colorbar strip thinner at assembly.

### 2026-10-12 — Supp: state-sorted trial rasters (3 states × activity / deviation / control)
**Changed:** New script `impulse-analysis/imp_state_raster_supp.m`. Rows = trials sorted by within-session state percentile, with quartile lines.
- Panel layout, one row per state (motion, rel δ, abs δ):
  - column 1 = onset-referenced activity, −1 to +0.49 s;
  - column 2 = deviation from the amplitude mean, 0–0.49 s;
  - column 3 = stim-free control deviation on the 18-sample window at −1.51 to −1.03 s.
- Every trial is divided by its session's response RMS L2. The control uses the same divisor, so magnitudes are directly comparable.
- Colours: purple–white–orange map, ±3 shared across panels.
- Knobs: `RS_SESS` ([] = pooled, 3 = Mouse 2), `RS_CLIM`, `RS_SMOOTH`.
- Rows are asserted against T.devRaw.
- Output: `paper/images/supplementary/supp_state_raster.png` and `supp_state_raster_s3.png` (300 dpi, heatmap rule). Not in MANIFEST.

**Found:** In the abs δ row, Q1 is pale in all three columns and Q4 is saturated in all three, so the control column tracks the deviation column visibly. Q4 also shows large pre-onset swings in the activity column. Motion is slightly paler in Q4; rel δ is flat.
**Why:** The user asked for sorted-trial rasters (9 panels) in place of the example-trial layouts A–C.
**Next:** User to choose pooled vs single-session and approve. Then make the colorbar compact, add the panel to MANIFEST [supplementary] and write a caption.

### 2026-10-12 — Decision: recompute Mouse 3's hemo correction locally (queued after the running TF rerun)
**Found (partial, read-only workflow wf_9882df74-940, `scratchpad/m3dip/`):** dip τ by V source, refit with the paper's options (seeded, no bootstrap):

| Session | Old corr | New corr / paper V | Raw blue (detrendAndFilt, timestamp-aligned) |
|---|---|---|---|
| M1a | 0.148 (2.89 Hz) | 0.1055 (2.43 Hz) | 0.119 (2.41 Hz) |
| M3 | — | 0.1435 (3.25 Hz; May-2021 corr) | pair 0.102, plus a real pole at 0.062 |

- Raw blue tracks the NEW correction in M1a, not the old one.
- M3's raw-blue dip pair matches the other mice. So the 0.14 s likely comes from its May-2021 correction (a one-way band-stop in the dip band).
- M1b and M2 calibration and the skeptic review are still running.

**Decision (user):**
- After the running tasks finish, recompute M3's hemo correction locally:
  - copy its widefield frames from the server (read-only);
  - run the SVD + hemo pipeline locally;
  - save the SVD/corr locally;
  - delete the frames;
  - then rerun M3's Fig 2 chain.
- Later, do the same for ALL sessions so every session is on one correction version.

**Why:** M3's slower dip is a correction artifact, not physiology. Leaving it would put a known artifact in 2F and the Discussion's conserved-dip claim.
**Next:** see TASKS 🔴. First find the lab's exact 2026-10-11 pipeline code and check disk space. Until the recompute, M3's numbers from today's TF rerun are provisional.

### 2026-10-12 — Dead end: launching a long MATLAB run from an MCP timer does not work; use `matlab -batch`
**Found:**
- A `timer` started from an MCP call (`evalin('base','run(tfseed_run.m)')`, StartDelay 2 s) reported TasksExecuted = 1 but never ran the script body. No variables, logs or error file appeared, and MATLAB sat idle for 85 min.
- The earlier probe only "worked" because it fired during a `pause(3)` inside the same call.

**Why:** the long TF rerun has to run without blocking the MCP session (1800 s idle timeout).
**Next:** long runs now go through a separate `matlab -batch` process (`scratchpad/tfseed_batch.m`):
- restore the MCP session's path;
- load the `allExperiments` saved from the session;
- run the job.

The TF rerun was relaunched that way at 18:25.

### 2026-10-12 — New supp producer: single-trial examples of the Fig 2G state effect (3 layouts)
**Changed/Found:** `impulse-analysis/imp_state_examples_supp.m` (new) — rebuilds per-trial traces in T's row order and asserts e and e_ctrl equal `T.devRaw`/`T.shmRaw` exactly (1516 trials, control -1.514..-1.029 s). Bins = Fig 2G's pooled equal-count quartiles of the within-session percentile. **Trial rule (deterministic):** "typical" trial = the one whose L2 error e is closest to its session x quartile cell's RMS e (ties -> lowest T row); spread overlay = trials at the 10/30/50/70/90th percentile ranks of e. Layouts (`SUPP_LAYOUT`): A = abs δ, 4 mice x Q1-Q4 typical trial (16.5 cm); B = 3 states x Q1/Q4, Mouse 2 (`SUPP_SESS=3`), 11.6 cm; C = residual x-μ_amp vs control c-μ_ctrl overlays, Q1 vs Q4, Mouse 2. Purple quartile ramp (not OL/CL colours), grey control, black dashed amplitude mean. PDFs -> `paper/images/supplementary/supp_state_examples_opt{A,B,C}.pdf`; 300-dpi workshop PNGs in the session scratchpad. Not added to MANIFEST; PAPER_FINAL untouched (it was already true in base, but the mirror is a no-op for unlisted names).
**Why:** Fig 2G's "fixed stimulus effect on state-dependent ongoing activity" reading needs a single-trial picture; the earlier random-pick scratch diagnostic was not reproducible.
**Next:** user picks a layout; then add it to PAPER.md + MANIFEST and caption it. Note single trials are dominated by ongoing activity (amp means ~1-3 % ΔF/F vs e ~2-6 %), and Mouse 2 motion runs Q1 > Q4 (cell RMS 3.65 vs 2.94).

### 2026-10-12 — Manuscript: Fig 2G text, caption, Methods switched to the L2 error
**Changed:** `Closedloop_edit/results.tex` and `methods_rewrite.tex` (uncommitted on `draft`; latexmk builds clean):
- **Results** state section, all from STATS_TABLE `2G_*`:
  - DV is now defined as the L2 error over 0–0.5 s;
  - control window is "equally long";
  - every response number is replaced: motion 0.64 [0.47, 0.82], t(3) = −7.33, p = 0.0052; rel δ 1.03 [0.85, 1.23], ρ +0.148, t(3) = 3.57, p = 0.038; abs δ 2.31 [1.85, 2.75], t(3) = 21.0, p = 2.4e-4;
  - control ratios 0.66 / 1.08 / 2.71, control ρ −0.23 / +0.127 / +0.57;
  - control/response RMS 0.92–1.06.
- **2G caption:** y definition, control window −1.51 to −1.03 s, a ** star level added (motion is now **).
- **Methods "Impulse-response variability":**
  - rewritten around the new Eq. `eq:l2_error` (18 samples, 0–0.49 s, onset-referenced, vs per-amplitude mean trace);
  - z = e / RMS_{s,a}(e) and RMS-based ratios;
  - control is the same equation over 18 samples ending at −1.03 s;
  - the Statistics paragraph's |dev| model is now z ~ state + (1|session).
- **Unchanged:** the Bonferroni statement (motion and abs pass 0.017, rel doesn't) and the δ-measure ρ = 0.47 (states only).

**Why:** User: "use L2, update the paper and the text across results and methods".
**Next:** None for 2G text. Fig 4 L151's cross-reference still reads correctly ("scatter around the mean response").

### 2026-10-12 — 2G DV switched to L2 time-course error (STV_DV='l2', default)
**Changed:**
- `impulse-analysis/imp_state_trialvar.m`:
  - new knobs `STV_DV` ('l2' default | 'mean') and `STV_L2_WIN` (0.5 s → 18 samples, 0–0.486 s);
  - per-trial e = RMS over t of (onset-referenced trace − per-amplitude mean trace);
  - control = same statistic over 18 stim-free samples (cols 53:70, −1.514 to −1.029 s, own-first-frame reference);
  - every spread summary goes through new helpers `local_spr`/`local_ss`/`local_dof`/`local_var`: SD/(n−1) pooling for 'mean', RMS/sum-of-squares for 'l2';
  - the bin test is Kruskal–Wallis under L2 (Brown–Forsythe under 'mean');
  - new R fields `ratioP`, `ctlRespSD`, `dvMode`, `l2Win`.
- `imp_state_hboot.m`: the bootstrap ratio is RMS under L2.
- `paper-writing/paper_stats_table.m`: 2G row labels follow the DV, and new rows `2G_*_ctrlratio` + `2G_ctl_resp_spread`.
- Re-ran: `data/fig2g_state_stats.mat` saved, `imp_state_var_combined.pdf` re-exported (PAPER_FINAL), STATS_TABLE.csv regenerated (only 2G rows changed, 58 rows).

**Found:** `STV_DV='mean'` reproduces the published numbers exactly (0.63 / 1.09 / 2.56, same CIs and t). L2 results are in the table below. All four sessions agree in every state. Control/response RMS per session is [0.92 0.94 1.06 1.06].

| State | Q4/Q1 [CI] | Control Q4/Q1 | LME | ρ (control ρ) |
|---|---|---|---|---|
| Motion | 0.64 [0.47, 0.82] | 0.66 | t(3) = −7.33, p = 0.0052 | −0.223 (−0.228) |
| Rel δ | 1.03 [0.85, 1.23] | 1.08 | t(3) = 3.57, p = 0.038 | +0.148 (+0.127) |
| Abs δ | 2.31 [1.85, 2.75] | 2.71 | t(3) = 21.0, p = 2.4e-4 | +0.551 (+0.573) |

**Why:** User chose L2 (0–0.5 s = the LTI fit window) after comparing candidates. It scores the response time course, not only its 0–200 ms mean.
**Next:** Supplementary example-trial figure in progress (background).

### 2026-10-12 — Fig 2G example trials per session × state quartile (diagnostic)
**Found:** I made scratch figures (`stv_example_trials.m`, session scratchpad): 2 random trials (rng 1) per session × quartile for motion / rel δ / abs δ, each trial's onset-referenced trace against the trial average at its own amplitude (−0.3 to 0.6 s, mW = V/3).
- **Abs δ:** Q1 trials hug their amplitude mean. Q4 trials carry large slow swings, ±5–15 % ΔF/F, that are already present BEFORE onset and continue through 0–0.5 s, which dwarfs the 1–5 % evoked dip. This is visual support for the "ongoing activity" reading.
- **Mice 1a/1b:** mean responses are only about 1–2 % ΔF/F, so single trials are dominated by ongoing activity even at low δ.
- **Control overlay (added on request):** each trial's own stim-free control (−1.543 to −1.029 s, own-first-frame reference) is drawn on the 0–0.5 s axis. High-δ control segments swing as much as the responses, and in Q4 control L2 is often ≥ response L2. The control's per-amplitude mean is not flat: it reaches up to 1.74 % ΔF/F of drift.
**Why:** The user asked to see what the 2G quartiles look like at the trial level.
**Next:** If the user wants it, convert this to a supplementary panel: fixed trial selection (e.g. median-L2 trial per quartile) and paper style.

### 2026-10-12 — S5B schematic shows the no-stimulation vs planned prediction; MPC prose checked against results
**Changed/Found:**
- `mpc_direct.py` now saves `snap_yfree`, the free response with the laser off from "now", next to `snap_yhat`, the prediction under the plan. Rerun gave identical numbers: MPC/PI 0.652 (108/108), perfect 0.224, medians 1.46 / 0.82 / 0.27.
- `ctrl_mpc_direct_panels.m` now draws both predictions on trial 79 at 2.0 s:
  - "no stim" (light purple, laser 0): the model predicts a rebound to above baseline within the 1 s;
  - "with plan" (purple): holds the signal at target.
  - Re-exported to figures_final.
- Timing kept at lag 0. The user decided the current timing is correct, which supersedes the 10-10 audit's suggestion to use lag 1.
- Manuscript `draft` (`Closedloop_edit`), MPC prose fixes:
  - Discussion: "ahead of the loop delay" became "over the next second". The variance reduction is now tied to the 1–3 s window. The upper bound now also says the laser acts identically in every brain state. The last sentence no longer claims a comparison with gain tuning that S5 does not show.
  - Caption A: the command bound is now "the range of commands the rig delivered" (u_max is the largest recorded command).
  - Caption B: rewritten for the two predictions.
  - Builds cleanly.
- NOT pushed. Local `draft` also carries `1f3ed30` (abstract) and uncommitted `results.tex` / `methods_rewrite.tex` edits that are not from this session.
**Why:** user: "keep current timing, check numbers and claims and write; show MPC prediction without stimulation then add stimulation".
**Next:**
- User re-places panel B in Illustrator (same size) and re-exports S5.
- Push main once the abstract commit and the uncommitted edits are cleared.

### 2026-10-12 — Fig 2G candidate: L2 (time-course RMS) error instead of SD of the 0–200 ms mean
**Found:** I wrote a scratch script (`stv_l2_panel.m`, session scratchpad, not in repo). It uses the same 1516 trials and state quartiles as `imp_state_trialvar`. The per-trial error is e = RMS over t of (trace − amp-mean trace), with the trace onset-referenced. The control uses an equally long stim-free window ending at −1.03 s, referenced to its own first frame. Per bin: sqrt(mean e²) ÷ session RMS.

| Window | State | Q4/Q1 resp | Q4/Q1 ctrl | LME t(3) | p | Agree |
|---|---|---|---|---|---|---|
| 0–200 ms | motion | 0.57 | 0.61 | −6.60 | 0.007 | 4/4 |
| 0–200 ms | rel δ | 1.12 | 1.09 | +3.81 | 0.032 | 4/4 |
| 0–200 ms | abs δ | 2.45 | 2.95 | +19.2 | 3.1e-4 | 4/4 |
| 0–500 ms | motion | 0.59 | 0.63 | −7.33 | 0.005 | 4/4 |
| 0–500 ms | rel δ | 1.04 | 1.07 | +3.70 | 0.034 | 4/4 |
| 0–500 ms | abs δ | 2.31 | 2.61 | +21.5 | 2.2e-4 | 4/4 |

Control/response session RMS ratio: 0.82–1.10 (200 ms window), 0.93–1.00 (500 ms window). Same conclusions as the current panel, slightly stronger tests; the control tracks the response even more tightly at 500 ms.
**Why:** The user asked for an L2-error version of 2G to judge as a replacement.
**Next:** If approved, port the computation into `imp_state_trialvar.m`/`_fig.m` behind a knob, add STATS_TABLE rows, and update the Results numbers + Methods definition. Until then the current panel stays.

### 2026-10-12 — Fig 2G y-label → "Trial-to-trial variability"; Fig 4 cross-reference updated
**Changed:**
- `imp_state_trialvar_fig.m`: the y-label changes from "Trial-to-trial spread" to "Trial-to-trial variability (× session typical)". Re-exported with PAPER_FINAL.
- `Closedloop_edit/results.tex` Fig 4 state paragraph: the sentence "The prediction error in Fig 2G asks how well the LTI model reproduces the response to the stimulus itself… better described by the impulse model" is rewritten. It now says 2G asks how far single impulse responses scatter around their per-amplitude mean.

**Why:** The user objected that "spread" is a new term needing explanation everywhere. "Trial-to-trial variability" is already the paper's term: the Fig 3 section title, Discussion L3 and the abstract use it. The old Fig 4 sentence was the only downstream use of "prediction error" for 2G, and it contradicted the reframe that state acts on ongoing activity rather than on the stimulus response.
**Next:** none.

### 2026-10-12 — Manuscript: Fig 2G reframed as "consistent with ongoing activity"
**Changed:** `Closedloop_edit/results.tex`, `methods_rewrite.tex` (uncommitted on `draft`; latexmk builds clean):
- **Section title** is kept: "Stimulation response is state dependent".
- **Results L74** now says the deviation is from the per-amplitude mean response, not the "model prediction".
- **Removed** the claim that motion "alters the evoked response itself".
- **New paragraph:** the control follows the response in every state (ratios and ρ per state), and the stim-free window's within-session SD is 0.80–1.10× the response's. It concludes the effect is "consistent with a fixed stimulus effect superimposed on state-dependent ongoing activity", not a demonstration, and links to Fig 4 (state as disturbance, feedback rejects it).
- **2G caption:**
  - y definition rewritten;
  - dotted line = 1 (typical trial);
  - dashed control described;
  - agreement fraction now uses the trial-weighted mean ρ (the old "pooled" was wrong).
- **Methods:** one sentence added on how the control curve is scaled.

**Why:** User: the response IS state dependent, but the likely source is the baseline (ongoing cortical activity), so not beating the control is expected, not a weakness.
**Next:** The 0.80–1.10 SD ratio is printed by `imp_state_trialvar` ("control/response session SD ratio") but is NOT in STATS_TABLE.csv; add it via paper_stats_table.m. No existing 2G number changed.

### 2026-10-12 — Fig 2G: stim-free control drawn; y-label clarified
**Changed:**
- `imp_state_trialvar.m` adds `R(k).sdPNs`: the sham deviation pooled within the same (session × amp) cells and bins as `sdRawNs`. It is normalized by the control's own session SD by default (`STV_CTRL_NORM='own'`; `'resp'` uses the response's SD).
- `imp_state_trialvar_fig.m` combined block:
  - dashed dark-grey open-circle control curve (equal-weight session mean);
  - legend "Stim / No stim" in the rel-δ tile;
  - session lines lightened to 0.78;
  - y-label changed from "Prediction error (session-normalized)" to "Trial-to-trial spread (× session typical)".
- Re-exported `imp_state_var_combined.pdf` with PAPER_FINAL on (figures_final + images).

**Found:**
- The plotted equal-weight Q4/Q1 for response vs control is: motion 0.55 vs 0.58, rel δ 1.14 vs 1.07, abs δ 2.71 vs 3.04. The control tracks the response in all three states.
- The control/response session SD ratio is [1.1 0.95 0.8 0.91], so stim-free 200 ms windows vary about as much as the response.
- The stats are unchanged (n=1516; same ratios, t, p).

**Why:** User asked to draw the control so the "response ≈ control" comparison is visible. The old y-label didn't say it is a spread or what it is relative to.
**Next:** Nudge the legend in Illustrator if it touches the rel-δ session line at Q1.

### 2026-10-12 — Results: state the selected LTI model orders (Fig 2C–D)
**Changed:** `Closedloop_edit/results.tex` (after "fit LTI models…"): added the selected orders. Mouse 1a has 3 poles and 1 zero, Mice 1b and 2 have 4 and 3, Mouse 3 has 5 and 4, and none has a delay. Also added that the order is picked once on all trials and held fixed in CV. Not committed (results.tex already had uncommitted user edits on `draft`).
**Why:** User asked for it; Results only said "low-order". Mouse 3 uses the **seeded** pick (5p4z0d, fit-only check above). The other numbers in the paragraph (0.85, 0.99/0.68, τ) are still from the pre-fix 4p2z0d run, so the paragraph is mixed until the rerun.
**Next:** Full seeded rerun (`imp_tf_run`, `imp_tf_cv`, 2-pole CV), then confirm the orders and update the held-out R², swap and τ numbers.

### 2026-10-12 — MANIFEST + PAPER.md: Fig 2 A/B letters swapped to match the caption
**Changed:** `paper/figures_final/MANIFEST.txt` [figure2] comment block + line order, and `PAPER.md` registry rows 2A/2B. A is now `imp_single_AL_0041_2025-12-02_en2.pdf` (traces) and B is `imp_response.pdf` (dose-response).
**Why:** results.tex caption, Results text, producer comments (`trace_overlay.m` "2A", `dose_response.m` "2B") and the user's story all had A = traces; the manifest said the opposite while claiming to follow the caption.
**Next:** Check the Illustrator assembly uses this order. Basenames are unchanged, so no producer rerun is needed.

### 2026-10-12 — Fig 3 story/code consistency audit (read-only)
**Found:** Letters A–I ↔ files match the assembled Figure3.pdf; every number in Results l.105–116 matches STATS_TABLE; the LMM, windows and the 15 sessions / 4 mice all check out. Problems: (1) the assembled PDF still shows "1 mW" scale bars in A/C, while `analysisPlots_combined.m:84,211` now says 0.2 mW; (2) the representative session is ambiguous (code `selField=10` = AL_0039 0419; the README says AL_0033 0419; the gains in Results l.106 come from AL_0033 0226 per NUMBERS.md:181); (3) PAPER.md:95-99 and STATS_TABLE `3H_*` rows use the old letters (the variance ratio is now **I**); (4) Results claims no RMSE effect pre/post, but there is no pre/post RMSE test in STATS_TABLE; (5) "2.56 vs 2.04" medians and "between-mouse variance negligible" are not in STATS_TABLE; (6) Methods does not define log mean-squared-deviation variance metric; (7) Methods lists motion exclusion (30/1190) under "All exclusions", but Fig 3 applies none; (8) G is RMS across trials, and Results says the gap "persisted for the rest of the trial" though it only persists for the rest of the stim window; (9) stale p's in NUMBERS.md:182-183 and in `variance_mse.m:128,565` comments.
**Why:** Pre-submission story ↔ code check requested by the user.
**Next:** Re-export Fig 3 A/C and re-assemble; confirm the representative session and its gains; fix PAPER.md/STATS_TABLE letters; add the pre/post RMSE test or soften the claim; fix the Methods variance definition and motion-exclusion scope.

### 2026-10-12 — Fig 2 story/code consistency audit (read-only)
**Found:** (A/B) Onset referencing, the 0–200 ms 8-sample mean, SEM, slopes and R² all match. MANIFEST.txt:36-37 + PAPER.md:83-84 have **A/B swapped** relative to the caption (A = traces, B = dose). "0 to 1.6 mW" is wrong (amp-0 is synthetic and excluded; the lowest real level is ≈0.13 mW). The panel-A gray band spans [−0.2, 0.5] s, while the fit window is [0, 0.5] s. Methods does not say the dose fit is OLS on per-amp means with intercept. 2B slopes are not in STATS_TABLE. (C–F) The seeded-fit edits are uncommitted and no panel has been rerun since; the text numbers (0.85, 0.99/0.68, rebound 0.30 s Mouse 3, 43–73%) come from the pre-fix hemo_pass.log and match neither the current E/F (self 0.978/cross 0.687) nor the pending seeded run (Mouse 3 rebound → beyond the window). Results never states the selected model order (pre-fix: 3p1z / 4p3z / 4p3z / 4p2z, no delay). Results calls the dip a "damped 2.4–4.2 Hz oscillation", but code takes min τ regardless of oscillation. The model-swap diagonal is in-sample and is not labelled as such. (G) Numbers match STATS_TABLE (n=1516, which requires the uncommitted STV_SKIP_AMP0=true); the **stimulus-free control is not drawn** in the panel; caption "same sign as pooled" should say the trial-weighted mean within-session ρ; the "dotted line = session mean error" label is really the pooled within-cell SD; control ratios 0.69/1.19/2.74 and the δ ρ=0.47 are not in STATS_TABLE.
**Why:** Pre-submission story ↔ code check requested by the user.
**Next:** Commit the seeded TF + STV_SKIP_AMP0 + AL_0048 reref changes together; rerun imp_tf_run/imp_tf_cv; then update the Fig 2 text numbers, add the model order to Results, draw the control in 2G, and fix the manifest letters.

### 2026-10-12 — TF fit: one seeded candidate per session; warm-started refits when it wins (user chose option B)
**Changed:** `utils/imp_tf_fit_session.m`, `utils/imp_tf_cv_session.m`, `impulse-analysis/imp_tf_run.m`:
- New option `seedOffset` (default false; `imp_tf_run` sets it via `RUN_SEED`, default true). It adds one candidate to the sweep:
  - m = the amp²-weighted pre-onset mean of DF/uA over [−0.5, 0) s;
  - sweep h − m as usual;
  - add `m/(s+1e-3)` to that AIC winner;
  - refit the sum by `tfest` on h itself.
- Selection is unchanged (AIC, then the R²h < 0.98 rule). `T.seeded` records whether the seeded candidate won.
- When it wins, LOAO, per-amplitude, bootstrap and the CV half-split refits are warm-started from `T.sys`. The CV guard requires the order to match.
- Fit-only check (no bootstrap): Mice 1a, 1b and 2 are unchanged (same order, R²h, AIC; seeded = 0). Mouse 3 selects the seeded 5p4z0d at R²h 0.994 and AIC −6.06, versus the sweep pick 3p1z0d at R²h 0.938 and AIC −3.14.
- Mouse 3's τ: 1768 s (offset pole), 0.500, 0.187, and a dip pair of 0.1435 s.

**Why:** user decision (option B, "use the better fit"). The default `tfest` start cannot reach Mouse 3's best model after the onset-frame reference (entry below).
**Next:** the full `imp_tf_run` + `imp_tf_cv` + 2-pole CV rerun, then update the manuscript TF numbers and add a Methods sentence on the seeded start.

### 2026-10-12 — Found: after the onset-frame fix, the TF sweep misses Mouse 3's best model (optimizer, not data)
**Found:** `imp_tf_run` (300 boot, PAPER_FINAL on) left Mice 1a, 1b and 2 bit-identical (R²h 0.978 / 1.000 / 0.998, same τ). For Mouse 3:
- AIC picked 4p2z0d at R²h 0.924. The <0.98 rule re-picked 3p1z0d at R²h 0.938: τ 0.243 s (2.14 Hz pair) plus 0.017 s.
- The bootstrap censoring is 36%. Swap self/cross is 0.978 / 0.687.

Diagnosis:
- The new Mouse 3 h(t) is exactly the old h + 0.098 (SD 0). The shape is the same; there is a sustained +0.4 tail at 0.5 s.
- Every sweep fit tops out at R²h 0.94. `tfest` `InitializeMethod` 'all' on 5p4z0d also gives 0.94, and 40 random-init restarts give at best 0.13.
- Seeded from the pre-fix 4p2z0d model plus a slow pole, 5p4z0d reaches R²h 0.993 with AIC −5.55. That beats every sweep candidate (pick −3.14), so the published AIC rule would select it.
- Its poles: τ 2044 s (DC-like), 0.41 s, 0.20 s, and a dip pair of 0.144 s at 3.25 Hz (before the fix: 0.1425 s at 3.23 Hz).

The tf_tau_forest and tf_model_swap panels exported by this run use the poor 3p1z0d fit.

**Why:** the rerun after the Mouse 3 re-reference.
**Next:** the user decides:
- (A) keep the sweep result;
- (B) adopt the warm-start fit, with a Methods sentence and a warm-started bootstrap;
- (C) drop Mouse 3 from 2D–2F.

Then run `imp_tf_cv` and the 2-pole CV, and update the manuscript TF numbers. 2B, 2G and STATS_TABLE are already updated.

### 2026-10-12 — Fig 2G after the Mouse 3 fix and the amp-0 drop (n 1516)
**Found:** `imp_state_trialvar` (`STV_SKIP_AMP0` true, onset-referenced Mouse 3):

| State | Response ratio | LME t(3) | p | Agree | ρ | Control ratio | Control ρ |
|---|---|---|---|---|---|---|---|
| Motion | 0.634 [0.438, 0.857] | −5.54 | 0.0116 | 4/4 | −0.137 | 0.69 | −0.120 |
| Rel δ | 1.090 [0.880, 1.506] | 3.58 | 0.037 | 4/4 | +0.127 | 1.19 | +0.065 (p 0.011) |
| Abs δ | 2.562 [2.136, 3.089] | 16.8 | 4.6e-4 | — | +0.397 | 2.74 | +0.373 |

- ρ(DPa, DPr) = 0.471.
- Motion now beats its control on both the ratio and ρ, so the verdict is PASS.
- Panel stars are *, *, ***. The panel and STATS_TABLE were re-exported.
- Manuscript draft:
  - 2B Mouse 3 now −3.11 per mW, R² 0.88;
  - 2G paragraph, caption and Methods updated: motion again "fell more steeply than its control"; one onset reference for all sessions; "only nonzero amplitudes"; n 1516.

**Why:** the user's go on decisions 1 and 2.
**Next:** the TF decision above. Also recheck the heading, intro and L148; under the new result they are consistent again, because motion's effect exceeds its control.

### 2026-10-12 — Fig 2B rerun after the Mouse 3 fix: only Mouse 3 moves
**Found:** `f2_slope_ci` + `dose_response` (PAPER_FINAL on, new hemo correction for sessions 1–3).
- Mouse 3 slope: −1.035 %ΔF/F per V, CI [−5.85, 3.78] mean-fit, [−1.46, −0.61] raw-fit, R² 0.882. That is −3.11 per mW. It was −0.810 per V (−2.43 per mW), R² 0.92.
- Mice 1a, 1b and 2 are unchanged: −0.295 / −0.438 / −0.510 per V, R² 0.971 / 0.732 / 0.882.
- `panels/figure2/imp_response.pdf` was re-exported.

**Why:** the Mouse 3 onset-frame reference, per the user's go.
**Next:** TF fit / CV / 2G rerun, then the manuscript numbers.

### 2026-10-12 — Mouse 3 re-referenced to its onset frame; Fig 2G drops the synthetic amp-0 events by default
**Changed:**
- `impulse-analysis/load_bilateral_impulse.m`: `trM = trM - trM(:, relW == 0)` replaces the 18-frame pre-onset mean, with a comment giving the history. The header note says the quoted energies are historical. The onset-frame pick (L150) is left alone, per the investigation.
- `impulse-analysis/imp_state_trialvar.m`: `STV_SKIP_AMP0` now defaults to true. `STV_REREF_ONSET` is a no-op guard.

**Verified:** after `load_experiments`, `max|col106| = 0` in all four sessions.
**Why:** user, 2026-10-12: "mouse 3 refernce needs to be correct to match the onset frame only" and "dont use no light trials". Mouse 3's hemo correction is left as is; nothing about it goes in Methods yet (the user will decide).
**Next:** rerun the Fig 2 chain. The no-light catch-trial control (decision 3) is not built; 2G keeps the within-trial `self8` control.

### 2026-10-12 — Found: Mouse 3 (AL_0048) is on an older hemo correction, and its t = 0 frame is picked by a different rule
**Found:** from the read-only investigation workflow wf_ebe82208-64e (4 investigators, each with a skeptic).
- **Correction version:** AL_0048 2026-07-15/1 `corr/` was written 2026-07-15 and is not in the lab's recompute list. It is the May-2021 aligned version (d836449). That version resamples blue onto violet times and applies a one-direction band-stop, which delays 1–5 Hz by about 13–21 ms (per the lab notes, as quoted by the verifiers). Sessions 1–3 are on the 2026-10-11 recompute.
- **Onset-frame rule:**
  - `load_bilateral_impulse.m:150` takes the first corr sample stamped at or after the laser.
  - `load_experiments.m:311` takes the nearest blue exposure.
  - The investigators disagreed on whether to switch. The skeptic's lag regression shows the AL_0048 corr columns mix blue(k−1), blue(k) and blue(k+1) and are correctly stamped. Switching to the nearest-exposure rule would move the t = 0 sample later (median ~20 ms after the laser vs ~14 now, and ~7 in sessions 1–3).
  - My data check: the AL_0048 onset sample is dark under the current rule. Trial-averaged col 106 vs the 18-frame pre-mean is −0.36 ± 0.21, −0.08 ± 0.22 and −0.09 ± 0.30 at 0.4, 1.0 and 1.6 V, and the dip starts at col 107. The same holds in all four sessions.
- Possibly relevant: Mouse 3's slower dip τ (0.1425 s vs ~0.11 s) resembles the old-correction τs of sessions 1 and 3 (0.148, 0.150 s). Speculative.

**Why:** the user asked why onset differs for Mouse 3.
**Next:** keep L150. Ask the user whether to keep Mouse 3's correction and state it in Methods, or have it recomputed (lab or local; the server is read-only).

### 2026-10-12 — Found: the amplitude-0 "trials" in sessions 1 and 3 are synthetic gap-fill events; real no-light trials are not loaded
**Found:**
- `load_experiments.m:106-156` inserts events every 5 s into any laser-off gap longer than 7.5 s and labels them amp 0: 55 in AL_0041 e1 and 196 in AL_0033.
- The detector misses no pulses (AL_0033 748/748, AL_0041 209/209 and 260/260). So the 2026-10-03 entry and the TASKS note calling them "missed stimulations" were wrong; TASKS is corrected.
- Real no-light trials (from input_params and Block files, per the workflow):

| Session | Real no-light trials |
|---|---|
| AL_0033 | 90 designed zero (input_params col 9) + 62 commanded but never fired |
| AL_0041 e1 | ~44 trials with no pulse. The lit-trial laser delay varies 0.02–2 s, so the sham onset is not defined |
| AL_0041 e2 | none (261 rows, 260 fired, the last row unlit) |
| AL_0048 | 200 shams in the Block, 100 for the R site, recoverable by a Block↔Timeline clock fit (7 ms RMS) |

- All other Fig 2/S1 producers already exclude amp 0. Only 2G included the synthetic events (251 of 1767).

**Why:** the user said "dont use no light trials … there should be some in all sessions". The second part does not hold for Mouse 1b.
**Next:** the user decides the 2G control: keep the within-trial `self8` (available in all 4 sessions) and/or add a real catch-trial control (3 of 4 sessions; needs new loader code).

### 2026-10-12 — Found: Mouse 3's pre-onset-mean reference is an undocumented port artifact, not a choice
**Found:**
- `load_bilateral_impulse.m:227` (`trM - mean(trM(:, relW<0 & relW>=-round(0.5*Fs_b)),2)`) was written once, in a91c076 (2026-08-02), when AL_0048 was ported from the Python bilateral sub-area. That sub-area's `impulse_config.py` sets `BASE_WIN = (-0.5, 0.0)`. The port never changed this line, although its comment says "matching the load_experiments contract".
- `load_experiments` has referenced every trial to the onset frame since the April monolith (8827995). The 2026-07-16 entry required an onset-frame reference so the TF fit has r(1) = 0.
- Data:
  - per-trial Mouse 3 Peak under the two references correlates only r = 0.36–0.55;
  - the onset reference lowers the within-amp SD (2.39→2.02, 2.27→1.56, 3.09→1.88);
  - the 2B slope of the amp means goes from −0.810 to −1.035 per V, i.e. −2.43 → −3.11 per mW.

**Why:** the user asked why Mouse 3's onset differs. It is truly wrong by the project's own convention.
**Next:** with the user's go, change L227 to the onset frame and rerun the Mouse 3 Fig 2 chain: 2B, TF (2C–2F), CV (2D), the 2-pole CV, 2G (with amp 0 dropped), STATS_TABLE, and the manuscript numbers.

### 2026-10-12 — Manuscript second pass after an adversarial check of today's edits (Closedloop_edit draft)
**Changed:** Applied only the fixes that don't depend on the decision below.
- `results.tex`:
  - Rel δ sentence: the control has a weaker ρ but a quartile ratio no closer to one (1.11), so it does not separate response from ongoing activity.
  - Abs δ now reads "as steeply or more".
  - Motion: referent fixed.
  - Added the 2G Bonferroni line (0.05/3 = 0.017; motion and abs clear it).
  - 4C last sentence made descriptive ("absolute power was the largest unique term"), with no "therefore … tied to".
- `methods_rewrite.tex`:
  - y_{j,t} reference now defined at Eq. inhib_energy (onset sample; AL_0048 18-sample pre-mean).
  - The control paragraph now says the ratio and ρ are repeated (not "every test"; the code runs no LME or agreement on the control).
  - Discloses that AL_0048's response reference falls inside the state window.
  - Names the exceed-rule as "both quartile ratio and correlation".
  - Added a 2G threshold to the multiple-comparisons sentence.
  - Regression paragraph rewritten to what is reported: per-session motion slopes plus Wilcoxon; 4C descriptive.
- `discussion.tex`: OL motion slope given p = 0.013 (not below corrected; within-session p = 0.0020), matching the treatment of rel-δ p = 0.044.

**Why:** the verify workflow (wf_9bc099bc-510, 4 checkers) found the following:
- the rel/abs wording contradicted one of the two numbers given;
- the Methods overstated what is repeated on the control;
- the trace reference was undefined;
- the Regression paragraph attached Bonferroni tests to 4C;
- p-qualifiers in the Discussion were uneven.

**Next:** held for the user's amp-0 / AL_0048-reference decision, because the motion conclusion flips with it:
- section heading "Stimulation response is state dependent" (L71);
- intro L44 "single-trial responses depended on … state";
- results L148 "movement trials are better described by the impulse model";
- 2G panel title "State dependence of stimulation response" (`imp_state_trialvar_fig.m` L430).

The compiled `images/Figure4.pdf` still has the old 4C (n=613) and stale 4D stars; the user is reassembling it.

### 2026-10-12 — Found: Fig 2G includes 251 zero-amplitude trials, and AL_0048's response reference sits inside the state window
**Found:** `imp_state_trialvar.m` loops over every amplitude.
- 251 of the 1767 trials are amp 0, with no light in the "response" window: AL_0041 e1 has 55 and AL_0033 has 196.
- AL_0048's `dfImp` is referenced to the mean of the 18 pre-onset frames (cols 88:105), which lie inside the [−1, 0) state window. The other three sessions are referenced to the onset frame.

Added off-by-default knobs `STV_SKIP_AMP0` and `STV_REREF_ONSET`; the default reproduces the paper exactly. Sensitivity (response vs control):

| Variant | n | Motion ratio | Motion ρ | Rel δ LME | Abs δ ratio |
|---|---|---|---|---|---|
| Paper | 1767 | 0.72 vs 0.68 | −0.116 vs −0.149 | p 0.057, 3/4 | 2.19 vs 2.88 |
| Skip amp 0 | 1516 | 0.73 vs 0.65 | — | p 0.055 | 2.27 vs 2.74 |
| Re-reference AL_0048 | 1767 | 0.64 vs 0.72 | −0.133 vs −0.126 | p 0.039, 4/4 | 2.41 vs 2.87 |
| Both | 1516 | 0.63 vs 0.69 | −0.136 vs −0.120 | p 0.037, 4/4 | 2.56 vs 2.74 |

Results are in `scratchpad/fig2g_sensitivity.mat`.

**Why:** the reviewer flagged the no-light trials as contradicting "response vs matched quantity with no stimulus". Whether motion beats its control depends on AL_0048's reference.
**Next:** the user decides. Recommended: drop amp 0 and use one reference definition for all sessions (onset frame). If adopted in the loader rather than only in 2G, the Mouse 3 Fig 2 numbers (2B slope, TF, CV) need a rerun.

### 2026-10-12 — Manuscript: p-values added where the text says "not significant" (Closedloop_edit draft, not pushed)
**Changed:** Several files.
- `results.tex`:
  - 2G caption now reads "n.s., not significant, p = 0.057 for relative power";
  - Fig 3 variance-ratio windows: before V = 56, p = 0.85; after V = 54, p = 0.76.
- `discussion.tex` L18:
  - CL motion p = 0.27;
  - rel δ OL p = 0.76; CL p = 0.044 ("not below the corrected threshold");
  - gap trends rel p = 0.081, abs p = 0.31, init p = 0.69.

All of these values come from the sweep workflow (wf_nsp.json) and match Results L150/L152 and STATS_TABLE.

**Skipped:**
- results L110 (a duplicate of the L112 test);
- the Methods L1180 insertion (results belong in Results).

**Why:** user, 2026-10-12: "mention the p value if we dont have significance".
**Next:** these claims still have no computed test anywhere:
- 3H pre/post RMSE ratio;
- mouse-variance LRT;
- S1 plateau, S1C, S1D;
- Fig 5G/H/I preview claims (these conflict with the Fig 5 "no significance tests" caption policy);
- the Discussion's preview "no detectable change" and the feedback × preview interaction.

Ask the user which ones to compute.

### 2026-10-12 — Manuscript: Fig 4C is construction only, no tests (Closedloop_edit draft, not pushed)
**Changed:**
- `results.tex` 4C paragraph: removed every V, p and the signed-rank and Bonferroni sentence, keeping mean ± SEM. "Kept the same share in both windows" now reads "took a similar share (0.11 ± 0.05 and 0.11 ± 0.06)".
- `methods_rewrite.tex`:
  - dropped "test ... with a one-sided Wilcoxon signed-rank test";
  - removed 4C from the multiple-comparisons families and from the 0.0063 threshold sentence.

**Why:** user, 2026-10-12: "4C dont state p values or significance we are just going to explain the construction here".
**Next:** `f4_error_decomp.m` still computes `DEC.sep.p` / `V` for the record. The panel has no stars, so it needs no change.

### 2026-10-12 — Manuscript: Fig 2G stimulus-free control numbers and Methods for the matched (Option B) control (Closedloop_edit draft)
**Changed:**
- `results.tex` L73/L75:
  - control described as "the same quantity over an eight-sample window just before the state window";
  - motion now reads "control fell at least as steeply (0.68 vs 0.72; ρ −0.15 vs −0.12), so quieter ongoing activity during movement can account for it; it does not show movement alters the evoked response";
  - rel δ control ratio 1.11, ρ +0.046, p = 0.053 ("about half as large, not significant"), replacing "flat, 0.98, p 0.94";
  - abs δ control 2.88 vs 2.19, ρ +0.39 vs +0.40;
  - closing line now covers both motion and abs power.
- `methods_rewrite.tex`: control paragraph rewritten:
  - Eq. inhib_energy over −1.23 to −1.03 s;
  - referenced like the response (onset frame; Mouse 3: preceding 0.5 s mean);
  - the "−0.5 to 0 s baseline" clause removed, because it was wrong for 3 of 4 sessions, whose traces are onset-frame referenced.

**Why:** rerun below; the old text's "motion falls more steeply than control → movement alters the evoked response" no longer holds.
**Next:** the user must agree the 2G narrative change before the push.

### 2026-10-12 — Decision: keep the OLD hemo correction for Fig 4E–G and the MPC supplement; hold the Methods hemo sentence
**Found/decided:** in answer to the correction explainer, the user said "hold off keep using old correction". Fig 4E–G and the MPC supplement stay on the corr_hemoApr2021-era caches. Fig 2/S1 stay on the new correction (the user's 2026-10-11 instruction). The Methods hemo-version sentence is not added.
**Why:** a user decision. A rebuild would also have to handle the AL_0033 2025-04-15 dropped/doubled-frame flag.
**Next:** revisit if the user reopens it. Until then the Methods hemo description stays generic.

### 2026-10-12 — Found: MATLAB ran a stale `imp_state_trialvar` after an edit
**Found:** the second edit (the AL_0048 reference branch) was not picked up. The run reproduced the previous numbers exactly and the new `fprintf` never printed. `clear imp_state_trialvar; rehash` fixed it.
**Why:** this is the known function-cache issue (memory `reference_matlab_function_cache`). It also hits scripts run through the MCP right after an Edit.
**Next:** after editing a script, always `clear <name>; rehash` before rerunning it via MCP. Check that a new print line appears.

### 2026-10-12 — `imp_state_trialvar.m`: Fig 2G sham = Option B (8 samples, self-referenced, matches the response statistic)
**Changed:** new knob `STV_SHAM`.
- `'self8'` (default):
  - `Lresp = numel(iOn:iOn+round(0.2*fs))` = 8, giving `iSham` cols 63:70 (−1.229 to −1.029 s);
  - the sham is referenced to its own first frame, as `Peak_imp` (`load_experiments` win3) is referenced to the onset frame;
  - for AL_0048, whose `load_bilateral_impulse` references `dfImp` to the mean of the 18 pre-onset frames (cols 88:105), the sham is referenced to cols 45:62;
  - the reference is detected from the data per amplitude, with an assert.
- `'onset7'` restores the old 7-sample, onset-referenced sham.

**Found:** the response is unchanged. The control changed:

| State | Q4/Q1 ratio, new (old) | ρ, new (old) |
|---|---|---|
| Motion | 0.68 (0.80) | −0.149 (−0.076) |
| Rel δ | 1.11 (0.98) | +0.046, p 0.053 (+0.002, p 0.94) |
| Abs δ | 2.88 (2.35) | +0.390 (+0.385) |

- Motion threshold split: control 0.51 vs response 0.40.
- The variance-decomposition regression of obs on sham now gives b = −0.081. The code comment records r = +0.39 for the old sham. The old sham shared the response's onset reference frame, which is the likely source of that correlation.
- The verdict for motion is now "NOT above stim-free control".
- The 2G paper panel is unchanged, because paper mode (`STVF_UNITS='norm'`) does not draw the control. It was re-exported anyway.
- `STATS_TABLE.csv` was regenerated.

**Why:** user, 2026-10-12: "rerun 2G with correct control, 8 samples … go option B". The old sham was one sample short since the 2026-10-03 response-window change, and it shared the onset frame with the response.
**Next:** manuscript updated (entry above). `imp_state_trial_examples.m` still uses the legacy 7-sample geometry; it is not a paper panel.

### 2026-10-12 — Fig 4C abs δ, transient vs steady state: paired test computed, not reported
**Found:** adjusted unique R² in the separate-model abs δ term, 0–1 s vs 1–3 s: 0.106 vs 0.114, a difference of 0.007. Paired signed-rank V = 31, p = 0.898, n = 11.
**Why:** this was computed to back "kept the same share in both windows". The user then decided 4C states no tests, so the text now gives the two values only.
**Next:** none.

<!-- older entries → RESEARCH_archive_2026H2.md (then RESEARCH_archive_2026H1.md) -->
