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

### 2026-10-27 — Producers re-run on the fixed caches with the session rule: what changed (working copies only)
**Changed/Found:** Headless MATLAB (`matlab -batch`, `PAPER_FINAL` off) ran `variance_mse`, `step_response`, `f4_row2_quartiles` and `ctrl_best_fixed_ol` on the onset-fixed caches. Before/after: `data/_pre_rerun_20261027/CHANGES.md` and `compare/compare_{fig3,fig4,bestfixed}.png` (old outputs backed up alongside, all local). `paper/figures_final` untouched (timestamps checked).
- **Fig 3:** ratios barely move (RMSE 0–3 s 0.767 → 0.768; variance 0.581 → 0.585; steady 0.683 → 0.679). Stars: 3H stays \*\*\* (t p = 5.8e-8, 15/15, 4/4 mice); 3I goes \*\* → \*\*\* (t p = 6.3e-6, 14/15). `all_average_sessions` and `all_variance_sessions` look cleaner: the onset step is sharper and the end-of-stim upturn is gone. 3I lost its 0.25 tick (cosmetic).
- **Fig 4D:** the mixed model on the fixed caches is almost the old one (e.g. abs-δ A p 0.0014 → 0.0021), so the onset fix is not what moves 4D. The session t-test does. Raw stars: initdev P \* → n.s. (p = 0.056); abs-δ P \*\*\* → \*\*; abs-δ A \*\* → n.s. (p = 0.094, +6.7 %/SD [−1.3, +15.4]); all the others keep their label. Holm (P+R 8, A 4): only motion A (−12.9 %/SD, p = 0.0023, Holm 0.0092, 11/11) and abs-δ R (p = 0.00071, Holm 0.0057, 15/15) survive. MATLAB `f4_row2_sess` equals the Python rebuild to 4 decimals on all 12 numbers (two independent pipelines). The Results motion slopes (+0.13 / −0.05, 11/11) are unchanged.
- **Best fixed:** ratios unchanged; m14 OL command 0.003 → 0.865 V (638 nm fix). With the t-test the steady-state CL/best is p = 0.00014; it was LMM p = 0.22 on 2.6 df. Spearman ρ 0.66 → 0.67 (p = 0.008).
- **Fig 4G: NOT re-run.** `imp_build_session` → `cp_loadUVt` needs the widefield SVDs on the lab data server (expPath: `Subjects/<mouse>/<date>/<exp>/blue/`), and today those folders are empty (AL_0033 2025-02-12, 2025-02-26) or missing (AL_0039 2025-04-20). Its old output is untouched. `f4_cl_reject_panel` now asserts the session test exists, so it cannot be re-drawn until `f4_cl_reject_lmm` runs where the SVDs are reachable.
**Why:** User asked to re-run the producers on the fixed caches and see what changed before re-exporting, with the session-level rule on Fig 4D.
**Next:** User approves the changes and picks raw vs Holm stars for 4D. Then: final re-export (`PAPER_FINAL` on), Fig 4G on a PC that can reach the SVDs (or find where they moved), and the manuscript/table updates (Methods stats, Results numbers, Tables 3–5, `paper_stats_table.m`).

### 2026-10-27 — BUG: AL_0048 dF/F written as a column by the onset fix; load_sessions broke
**Changed/Found:** `utils/ctrl_onset_fix.m`. The first version prepended the 11 lead frames with `[repmat(..., 11, 1); dFk(:)]`, which turned the m14 `data.dFk`/`data.F` from rows (how every cache stores them) into columns. `controllerData` handles either, so the trial matrices and the reconciliation (≤ 4.7e-7) were right. But `load_sessions.m:348` stacks `dFk(i-105:i+210)` with vertcat: on a column `pncDfk_l` became one long vector and `vr_ncDfk_l` a scalar, and the full load stopped with "Dimensions of arrays being concatenated are not consistent". Fix: a `padlead` helper keeps the orientation, plus a repair branch that turns an already-padded column back into a row (`info.reoriented`), so the next `load_sessions` re-saves m14. Values are unchanged.
**Why:** Found on the first headless re-run of the Fig 3/4 producers on the fixed caches.
**Next:** Confirm the re-run loads all 15 sessions. Python reads the caches with `ravel`, so its results are unaffected.

### 2026-10-27 — Session rule wired into the MATLAB producers (Fig 3, 4D, 4G, best fixed)
**Changed/Found:** New `utils/sess_test.m`, the MATLAB twin of `stats_v2/tests.py sess_test`: one-sample t (two-sided, df = n−1, t CI), exact Wilcoxon, k/n, leave-one-mouse-out worst p, per-mouse means. New `utils/holm_adjust.m`. New `utils/f4_row2_sess.m`: per-session P/R/A on the within-session z-scored state, same definitions as `stats_v2/run_all.py`.
- `utils/ratio_session_stats.m` adds `S.st = sess_test(...)` plus LOMO and mouse fields; the LMM fields stay as a reference.
- `variance_mse.m`: the 3H/3I title star is now the t-test on the 0–3 s log ratio (`R3.*.full.t_p`). It was the larger LMM p of 0–1 and 1–3 s.
- `f4_row2_quartiles.m`: the P/R/A stars now come from `f4_row2_sess` (`F4_STAR = 'raw'` default, `'holm'` option) and are saved to `data/f4_row2_sess.mat`. The LMM is still fitted, printed as `[LMM ref]` and saved to `f4_row2_lme.mat`.
- `f4_cl_reject_lmm.m`: adds the two-sided session t on per-session mean log RR (`ST`), and the same for all sessions without the offset gate (`STall`).
- `f4_cl_reject_panel.m`: the band and star come from `ST`.
- `ctrl_best_fixed_ol.m`: the console prints the t p and saves the Spearman (c*, CL/OL command) as `SP` for Table 4.
**Why:** User decisions 2026-10-27 (STATS_AUDIT §7): the session is the unit, the t-test on session values is the main test, Fig 4D is session-level, and Fig 4G is a two-sided session t. User: "what about state rebuild recommendations though? with session level on 4d".
**Next:** Run the producers headless (working copies only, `PAPER_FINAL` off), compare before vs after, and get approval before any final-panel export. If approved, update the manuscript (Methods stats, Results numbers, Tables 3–5) and `paper_stats_table.m`.

### 2026-10-27 — MATLAB pipeline: corrected onsets + AL_0048 fixes ported; caches rewritten and verified
**Changed/Found:** `utils/ctrl_laser_cmd.m` (new: the command channel that fired, by largest 99.9th percentile; AL_0048 → `inpVals638`). `utils/controllerData.m` builds `ncInp`/`wcInp` from it instead of `d.inpVals`. `utils/ctrl_onset_fix.m` (new, idempotent): sets `stimStarts`/`stimEnds` from `stats_v2/results/onsets_corrected.csv` (m1–m8; it errors if a cache no longer matches the table) and edge-pads m14 `dFk`/`F` by 11 frames. `controller-analysis/load_sessions.m` applies it on cache load (recompute + re-save if changed) and on rebuild from raw. `controller-analysis/ctrl_apply_onset_fix.m` (new, one-off) rewrote the caches through a headless `matlab -batch`, with originals in `data/_pre_onset_fix/` (9 files). Shifted onsets per session (m1 120, m2 200, m3 131, m4 141, m5 39, m6 18, m7 43, m8 39) match the table exactly. m14 dFk lead 11 and laser 638; m9–m13 and m15 untouched. Verification (`stats_v2/reconcile.py --corrected` → `stats_v2/results/corrected/RECONCILE.md`): per-trial full-window RMSE from the rewritten caches equals the Python corrected rebuild to ≤ 4.7e-7 in all 15 sessions, and the per-trial OL/CL command maxima match exactly (m14 OL now 0.865 V, was ≈ 0). Caches carry `d.onset_fix` plus a provenance stamp.
**Why:** User approved the corrected onsets (onset_check figures) and asked to port them and the AL_0048 fixes into the MATLAB figure pipeline, keeping t = 0 at the logged-onset convention.
**Next:** Re-run the figure producers on the fixed caches: Fig 3 (`variance_mse`, `step_response`), Fig 4D (`f4_row2_quartiles`), best fixed (`ctrl_best_fixed_ol`), and the Fig 4G chain (`ctrl_residual_build` → `f4_cl_reject_lmm`, built on old onsets). Check whether the AL_0048 sine sessions (bilateral loader) have the same 11-frame dFk offset. Gotcha: `addpath(genpath('utils'))` in batch mode puts a Rigbox test mock of `system` on the path (harmless "Mock called" warnings; the git stamp still recorded).

### 2026-10-27 — Onset check figures: corrections look right; CL rises unbiased against the OL estimate
**Changed/Found:** `stats_v2/plot_onsets.py` (new; matplotlib added to `stats_v2/requirements.txt`) → `data/stats_v2/onset_check_{1,2,3}.png` (local, git-ignored). Per session: 2 OL and 2 CL single trials (the largest correction or worst rise, plus a random one) and the OL average aligned on the new vs the old onset. In m1/m2 the old-onset average is about 4 frames late, while the corrected dip starts right after the laser rise. In m3–m8 the largest-shift trials show the response starting before the old onset. The corrected sessions m1–m8 are exactly the sessions whose command is a 35 Hz pulse train; m9–m15 use a step command. CL trials with a prompt rise: the residual vs the OL-derived estimate has a median of −0.17..+0.18 frames per session (IQR within ±0.5). m14 CL trial 89 shows the "error already below the reference" case: no command until frame 18. Minor: m14's OL average (dFk +11) drifts down about 1.5 % over the 8 frames before onset; probably noise (n = 45), worth a glance.
**Why:** User asked to confirm visually that trial onsets are correctly identified in every session.
**Next:** User confirms the onsets. Then decide the t = 0 convention and port the onsets to MATLAB.

### 2026-10-27 — Correction: the 1.88 / 2.86-frame onset offset is not loop latency
**Changed/Found:** `stats_v2/onsets.py` (docstring and ONSETS.md label only; the onsets are byte-identical). The previous entry called L the "onset→laser latency". It is the offset from the logged onset frame to the first laser command. Measured loop latency (exposure start → laser edge) is 24.0 ms median (methods.tex:101; RESEARCH 2026-10-20, m15). Subtracting it leaves 29.6 ms = 1.04 frames (old builds) and 57.5 ms = 2.02 frames (new builds): whole frames of trial bookkeeping. The first command is computed from onset frame + 1 (old) or + 2 (new). So t = 0 (the logged onset) sits about 1 frame (28.5 ms) earlier relative to the laser in the new builds than in the old.
**Why:** User: latency cannot be 2.86 frames. Correct; latency is about 0.84 frames.
**Next:** User decides whether t = 0 stays the logged onset frame (current) or becomes the laser onset in every session (shift 2 frames old / 3 frames new).

### 2026-10-27 — Rebuild with corrected onsets + m14 fix: Fig 3 unchanged; Fig 4D init-dev R drops below Holm
**Changed/Found:** `stats_v2/run_all.py --corrected` → `stats_v2/results/corrected/`. Fig 3 is unchanged in substance: full RMSE 0.768 [0.727, 0.811], p = 5.8e-8, 15/15, 4/4 mice (p = 0.011); full variance 0.585, p = 6.3e-6; pre RMSE 1.013 [0.997, 1.030]. Fig 4D (p, Holm): init-dev P 0.056, R 0.014 (Holm 0.071; was 0.0060 / 0.042 with the old onsets), A 0.91. Motion P 0.011, R 0.16, A 0.0023 (Holm 0.0092, 11/11, 4/4 mice). Rel δ P 0.98, R 0.035, A 0.029 (Holm 0.087). Abs δ P 0.0098, R 7.0e-4 (Holm 0.0057, 15/15), A 0.094 (Wilcoxon 0.035, 12/15). Survive Holm: motion A and abs-δ R only.
**Why:** User chose the laser-command rise (OL only) as the onset, with stimStarts corrected in the sessions that need it.
**Next:** Port the corrected onsets and the m14 fixes (dFk shift 11, 638 nm channel) into the MATLAB producers so the figures match; then redo the Fig 4D Results text and Table 4.

### 2026-10-27 — Corrected onsets: OL laser rise, carried to CL trials by time
**Changed/Found:** `stats_v2/onsets.py` (new), `loader.py` (`onset_frames` override), `run_all.py` (`--corrected`: corrected onsets + m14 dFk shift 11; outputs to `data/stats_v2/corrected/`). Nominal onset→laser latency L = 1.88 frames (old builds) and 2.86 (new), from the sessions whose OL offsets are stable. A session is corrected if any OL trial sits > 1.5 frames from L. That rule selects exactly m1–m8 (AL_0033, Jan–Apr 15 2025); m9–m15 are untouched. Shifts: m1 and m2 +3..+5 frames (median +4); m3–m8 median 0, range −7..+2. In CL trials whose own rise was detected, 89–100 % sit within 1 frame of the OL-derived estimate. No clock re-sync jumps between neighbouring OL trials. Per-trial table: `stats_v2/results/onsets_corrected.csv`.
**Why:** User: trust the command rise only in open loop (a CL command can start late when the error is ~0); stimStarts were right originally but code changes shifted them, so correct the sessions that need it.
**Next:** Same port to MATLAB as the entry above.

### 2026-10-27 — Fig 4D at session level: abs-δ attenuation no longer significant; init-dev R and motion A stronger
**Changed/Found:** `stats_v2/results/tests.csv` — per-session slopes, t-test across sessions (session-level p vs old mixed-model p). init-dev: P 0.060 (0.014), R **0.0060** (0.028), A 0.51 (0.89). Motion: P 0.011 (0.013), R 0.13 (0.27), A **0.0019**, 11/11 sessions (0.0048). Rel δ: P 0.95 (0.76), R 0.040 (0.044), A 0.039 (0.027). Abs δ: P 0.011 (6.6e-4), R **7.0e-4**, 15/15 (1.6e-4), A **0.082**, Wilcoxon 0.035, 12/15 (0.0014). Holm < 0.05: motion A 0.0077, abs-δ R 0.0056, init-dev R 0.042. Results.tex currently quotes abs-δ attenuation "+8 %/SD, p = 0.0014, survives correction"; at session level it is +7 %/SD, p = 0.082.
**Why:** User chose session-level tests for Fig 4D. The values are preliminary: they still use stimStarts onsets (see the onset entry) and the literal m14 alignment.
**Next:** Decide the onset marker; re-run; then rewrite the Fig 4D Results paragraph around the session-level numbers.

### 2026-10-27 — BUG: m14 (AL_0048) dFk is offset 11 frames from timeBlue
**Changed/Found:** `data/AL_0048ctrl07292.mat` — `data.dFk` has 54828 frames, `d.timeBlue` 54839. With the literal mapping dFk[i] ↔ timeBlue[i], the OL trial-average dFk starts falling 6 frames BEFORE the laser command rises (command at +2 frames, dFk dip from −6). In m13/m15 the dip starts 2 frames after the command. Shifting m14 by 11 frames gives a +3-frame lag, like every other session. The old pipeline uses the same literal mapping, so its m14 windows are about 0.31 s late. Effect on Fig 3 is small (full RMSE ratio 0.7675 → 0.7670); init-dev R Holm p moves 0.042 → 0.060.
**Why:** Found by the clean-room alignment check and confirmed independently from the trial averages.
**Next:** Fix m14's frame mapping at the source (SVD/dFk time base for the 2026-07 builds). Check whether the AL_0048 sine sessions (Fig 5/6 phase lags) have the same length mismatch; a 0.31 s offset is about 113° at 1 Hz.

### 2026-10-27 — Onset marker: stimStarts is off from the actual laser onset in the old builds
**Changed/Found:** The laser command (2 kHz, same clock) rises after the stimStarts frame by: m1 4.7–6.7 frames (median 5.7, every trial); m2 5.5–6.9; m3–m8 a saw-tooth drift from −5 to +4 frames; m9–m13 about 1.9; m14/m15 about 2.9. In m1 the dFk dip aligned on the command rise starts within 1 frame; aligned on stimStarts it starts at +6/+7. So the command marks the true onset and stimStarts is about 0.16 s early in m1/m2 and jitters ±0.14 s in m3–m8. Old pipeline and rebuild share stimStarts, so this is not a discrepancy between them. Both conditions are affected alike per session; the transient window and initial deviation are affected most.
**Why:** Spec §6 onset sanity check (876/1670 trials outside ±2 frames), confirmed independently for m1 and m4.
**Next:** User decides the onset marker (command rise vs stimStarts). Then re-run Fig 3/4D as a sensitivity before choosing the primary.

### 2026-10-27 — Clean-room rebuild reproduces the old trial-level values exactly
**Changed/Found:** `stats_v2/` (loader/metrics/tests/run_all, built blind from SPEC.md; commit 09edd4a), `stats_v2/reconcile.py`, `stats_v2/results/`. Trial sets are identical in all 15 sessions (1670 trials). Per-trial full-window RMSE matches to ≤ 4.9e-7. Per-session Fig 3 ratios for pre/full/post match to ≤ 4e-7. Early/late differ by ≤ 0.007 (RMSE) and ≤ 0.028 (variance), because the old code puts the 1.000 s sample in "early" (tp ≤ 1, `variance_mse.m:76`) and the rebuild puts it in "late" — a convention, not a bug. Fig 3 session-level tests reproduce §6 of STATS_AUDIT (full RMSE p 9.2e-8, full variance 7.4e-6).
**Why:** Phase 4 reconciliation, tier by tier.
**Next:** none for Fig 3 arithmetic. The open items are upstream (onsets, m14 alignment).

### 2026-10-27 — Clean-room stats rebuild: spec v1 and Python environment
**Changed/Found:** `stats_v2/SPEC.md` (new) and `stats_v2/requirements.txt` (numpy 2.5.4, scipy 1.18.1, pandas 3.1.0, h5py 3.16.0, venv at `stats_v2/.venv`). Fig 3 and Fig 4D are rebuilt in Python from each cache's `d.*` and `data.dFk` only, read via h5py. All 15 caches are local and v7.3. Rules: active laser channel picked per session, validation block = last N trials, input_params row 3 = condition, session-level tests via one `tests.py`. Out of scope for v1: ΔF/F itself, Fig 4G, Fig 2G, best fixed input.
**Why:** User approved the clean-room rebuild with Python tests. An earlier attempt to run `load_sessions.m` through the MATLAB MCP hung for 30 min (MATLAB idle, no network I/O) and was aborted, so this path avoids MATLAB entirely.
**Next:** A blind builder agent implements the spec; then reconcile tier by tier against the old caches and STATS_TABLE.

### 2026-10-27 — BUG: AL_0048 (m14) laser command read from the idle 594 nm channel
**Changed/Found:** `utils/controllerData.m:119,146` builds `ncInp`/`wcInp` from `d.inpVals`, which for the 2026-07 builds equals `inpVals594`. In AL_0048 2026-07-29/2 the 594 channel is idle (max 0.016 V); stimulation went through `inpVals638` (max 4.18 V, on 19% of samples). So `ncInp`/`wcInp` for m14 are near zero (per-trial max median −0.01). AL_0051 (m15) used 594 and is correct (OL 1.30, CL 3.07). Affected for m14: `ctrl_best_fixed_ol.m` (uOL 0.003, cStar, best-fixed RMSE, uCLrel), the command-ratio Spearman (results.tex:147), and any pooled command panel. Not affected: Fig 3 RMSE/variance (from dFk and trial labels) and Fig 6 sine (`ctrl_mpc_sine_export.m:44` reads 638 explicitly).
**Why:** Pre-check before the clean-room rebuild: AL_0048's OL command read 0.003 against 0.33–2.49 in every other session.
**Next:** Clean-room picks the active laser channel per session from the raw command (spec rule). Then re-run `ctrl_best_fixed_ol.m` with m14 fixed and re-check the best-fixed rows and the Spearman.

### 2026-10-27 — Fig 4D goes session-level; motion gap increase holds in every random half of sessions
**Changed/Found:** `data/f4_motion_slopes.mat` — resampled the 11 per-session motion slopes. Gap change (OL − CL): 11/11 sessions, t p = 0.0014, exact sign-flip p = 0.0010, bootstrap 95% [+0.17, +0.40], same sign in 100% of random 5-session halves. OL slope: 10/11, p = 0.0073, 100% of halves. CL slope: 6/11, p = 0.46, only 74.5% of halves. Decision recorded in STATS_AUDIT §7.10: Fig 4D uses per-session slopes with a t-test across sessions.
**Why:** User framed the test as "does the claim hold if we pick random sessions?" and chose the session-level t-test. User also argued P, R and A per state are separate questions, so dividing by 12 makes no sense.
**Next:** User confirms per-question stars plus a Holm column in Table 4. The clean-room rebuild computes session-level P, R and A for all four states.

### 2026-10-27 — Fig 4D motion slopes at session level agree with the mixed model, slightly stronger
**Changed/Found:** `data/f4_motion_slopes.mat` (MOTSLOPE, 11 sessions, z units) — one-sample t across sessions: OL slope p = 0.0073 (Wilcoxon 0.0020; mixed model 0.013), CL slope p = 0.46 (mixed model 0.27), OL − CL p = 0.0014 (mixed-model gap trend 0.0051). Recorded as STATS_AUDIT §7.9.
**Why:** User asked whether Fig 4D can use session-level tests like Fig 3 instead of the trial-level mixed model.
**Next:** If approved, the clean-room rebuild computes per-session P, R and A for all 4 states. Holm across the 12 slopes stays.

### 2026-10-27 — Fig 4D corrected stars worked out: Holm keeps motion attenuation even across 12 tests
**Changed/Found:** `paper-writing/STATS_AUDIT.md` §7.4 — Holm-adjusted p from STATS_TABLE 4D rows. Stars disappear for initdev P/R, motion P, rel-δ R/A. Star levels drop for motion A (** → *) and abs-δ P/R (*** → **). Abs-δ A stays **. Bonferroni gives identical labels within the caption families. Pooled into one family of 12, Holm keeps the same four survivors (motion A 0.043), whereas Bonferroni would drop motion A (0.058).
**Why:** User asked for a detailed explanation of the Fig 4D star change. Raw-p stars contradict the Results text, which already says those slopes don't survive correction.
**Next:** User confirms Holm-adjusted stars; then `arrowstars` takes adjusted p, and the caption and Table 4 bold rule name Holm.

### 2026-10-27 — Decided not to flag in Methods when attenuation was added
**Changed/Found:** `paper-writing/STATS_AUDIT.md` §7.3 — the suggestion to say in Methods that attenuation was introduced on 2026-10-18 is struck. The other §7 revisions are accepted in principle; final approval is pending.
**Why:** User: attenuation is a real, distinct quantity, and predictability, regularizability and attenuation each show something different in the Fig 4D quartiles, so its timing doesn't need a mention.
**Next:** Confirm whether gap trend stays in Table 4 as "not interpreted"; then final approval of §7 and the clean-room spec.

### 2026-10-27 — Stats recommendations revised after a strict-reviewer pass
**Changed/Found:** `paper-writing/STATS_AUDIT.md` §7 — session unit kept (justified by within-session random interleaving, methods.tex:130/596) with the mouse level in the same sentence. 0–3 s becomes the primary window (was "drop its test"). Gap trend kept as the linear-scale check on attenuation (was "drop"), because attenuation was added 2026-10-18 after motion R was n.s. The 4G all-13 result goes in the text. Prep quality allowed only as a pre-specified OL- or actuator-based covariate, never as an exclusion.
**Why:** User asked to rethink each recommendation as a strict reviewer, and argued that a weak mouse reflects prep quality, not the controller.
**Next:** User decides on these revisions; then write the clean-room spec.

### 2026-10-27 — Best-fixed outliers are calibration sessions, not weak preps; AL_0048 OL command reads 0.003
**Changed/Found:** `controller-analysis/data/ctrl_best_fixed_ol.mat` (table T) — Mouse 4 (AL_0051): CL/OL 1–3 s 0.72 (typical), best/OL 0.66, OL offset 2.03 → 0.38 %ΔF/F under the best fixed input, so CL/best = 1.10. Session 1k (AL_0033): same pattern (offset 2.25, CL/best 1.00). AL_0048 (Mouse 3e): uOL = median per-trial max of `ncInp` = 0.003, against 0.33–2.49 in the other 14 sessions; it is also the weakest CL/OL session (0.94).
**Why:** Checked whether the user's prep-quality explanation fits the session that breaks the best-fixed mouse-level result. It doesn't fit Mouse 4: its feedback benefit over OL is normal, and its OL was badly calibrated.
**Next:** Verify AL_0048's `ncInp` units, or whether OL barely stimulated, before any interpretation of that session; include it in the clean-room spec as an explicit check.

### 2026-10-27 — Session-level stats rule: Fig 3 robust to every mouse check; best-fixed 1–3 s is not
**Changed/Found:** `paper-writing/STATS_AUDIT.md` §6 — recomputed the Fig 3, best-fixed and Fig 4G tests from saved per-session values under the session rule (t on log ratio + Wilcoxon) with leave-one-mouse-out and mouse-averaged checks. Fig 3: every stimulation window passes all checks (LOMO worst p ≤ 0.014; 4/4 mice below 1). Fig 3I stars go ** → ***. Fig 4G: two-sided p = 2.6e-4, 3/3 mice < 1, still p = 0.021 with the 2 excluded sessions. Best fixed 1–3 s: session p = 2.4e-4 but dropping AL_0033 gives p = 0.053, and AL_0051's single session has ratio 1.10 (3/4 mice). Best fixed 0–1 s is weak (LOMO up to 0.16). Separately, the Fig 4D panel stars use uncorrected p, so five starred slopes are ones the text says don't survive Bonferroni.
**Why:** User asked how moving the unit from mouse to session changes results and figures before committing to the rule.
**Next:** User decides the best-fixed wording and whether Fig 4D stars use corrected p; then run the independent clean-room re-derivation (spec → fresh implementation → reconcile against STATS_TABLE).

### 2026-10-27 — Intro: ML dynamics models + two limits for control (Closedloop 9354e56)
**Changed/Found:** `introduction.tex`, `refs.bib`: two sentences added after the lu2025 forecasting sentence, covering LFADS, NDT, CEBRA, the Wang 2025 foundation model, POYO and POSSM. Their limits are framed as real-time impracticality and no forecasting of the response to stimulation. Five bib entries were added. The reference check (Crossref/arXiv) changed the claims. NDT's abstract claims 3.9 ms real-time inference, so NDT is NOT cited for real-time impracticality. Wang 2025 *does* predict responses to (visual) stimuli, so it is excepted from the "no forecasting" claim. "In the manner of language models" was dropped because no source says it.
**Why:** The user asked for state-of-the-art ML models (including Lajoie's group) with their limits, and for the references to be checked before installing.
**Next:** "LFADS infers from whole trials" is from model knowledge; the Crossref record has no abstract. The NDT citation is arXiv-only. The Intro is still about 1,300 words against the ~750 limit.

### 2026-10-26 — Results MPC wording fixes (Closedloop e1b13e4, pushed)
**Changed/Found:** `Closedloop_edit/results.tex`, MPC subsection. Changes:
- The Overleaf opening (lines 282–283) was rewritten. The cost now matches Methods: tracking error plus a penalty on command changes. It had said "conserving energy", and that the model predicts "from current activity"; neither was accurate.
- Fixed "horizon( Figure".
- The constraint sentence is now in controls language: input constraints, prediction error from plant–model mismatch and unforecastable disturbance.
- Aditya's own Methods perfect-prediction line was kept as he wrote it.

Built clean.
**Why:** Aditya asked for my earlier MPC corrections to replace his Overleaf push (b091bca), and for main to be pushed.
**Next:** Aditya pulls into Overleaf. The new Intro first line and the P1.5 cortex/mesoscale line are still to be pasted by him.

### 2026-10-26 — Stats audit: Fig 3 mouse-LMM df collapse, CI/p mismatch, ~35 redundant rows
**Changed/Found:** `paper-writing/STATS_AUDIT.md` (new) — claim-by-claim audit of all 146 STATS_TABLE rows against results.tex / stat_tables.tex / methods.tex. Found: (1) Fig 3 primary `log r~1+(1|mouse)` Satterthwaite df flips between 14 and 0–2.7 with 4 mice (9/4/1/1 sessions), giving p=0.089 for 0–3 s RMSE (15/15 sessions <1; t-test p=9.2e-8) and p=0.22 for CL/best-fixed 1–3 s (t p=2.4e-4); (2) Fig 3 table CIs are df-14 intervals beside df-1/2.6 p-values; (3) Fig 3 uses mouse-LMM as primary but Fig 4G uses session-only LMM, so the rule flips between figures; (4) results.tex:147 Spearman rho=0.66 p=0.009 (ctrl_best_fixed_ol.m) has no STATS_TABLE row; (5) ~35 redundant/orphan rows (3_* corroborating, 0–3 s tests, gap ×4, gap trend vs attenuation, 4_motslope_* Wilcoxon vs 4D LMM slopes, 2G_*_q4).
**Why:** User asked for an audit before reconsolidating tests: which claims need a test, and is each test the right one (hub #62).
**Next:** User decides the paper-wide rule (recommended: session-level one-sample t on log ratios + Wilcoxon robustness + mouse sensitivity check), one-sided vs two-sided 4G, CI-only for pre/post null windows; then rewire producers + paper_stats_table/tex.

### 2026-10-25 — Replay plays the CL average one sample (28.6 ms) late (AL_0048 2026-10-23/1)
**Changed/Found:** `controller-analysis/ol_opt_replay_controlapp.m`: the replay trials' command is exactly `custom_mw_trial_avg` (max diff 1.8e-14 mW), but delayed by 1 sample relative to the CL custom trials it was averaged from. `avg_mw(1)` is the `kk_onset` sample, when the light is still off: custom trials are recorded from `u_log[inp]`, one sample before light (DATA_FILES gotcha 9). Replay plays that 0 as its first on-sample. CL light starts at `kk_onset+1`, replay light at `kk_onset+2`.
**Why:** The overlay of replay on its CL source looked shifted. A lag scan (−2…+3 samples) gives zero error only at +1.
**Next:** This is a rig-side bug (controlApp, Main custom recording), not an analysis issue. At 28.6 ms it is small next to a 3 s step, so the result stands. Fix in the rig repo: drop the first recorded sample or start replay at index 1. Mention it in Methods if replay goes in the paper.

### 2026-10-25 — OL-best replay analysis for control-app session AL_0048 2026-10-23/1
**Changed/Found:** New `controller-analysis/ol_opt_replay_controlapp.m`, the control-app counterpart of `ol_opt_replay_batch.m` + `ol_opt_replay_avginput.m`. Those scripts, and the AL_0041 results and figures, are untouched. It writes `paper/images/ol_opt_replay/AL_0048_2026-10-23_1_{tracking,avginput}.png`.
- **Format:** recorded by `Main_experiment.py --mode closed_loop --demo`, controlApp @ 959995b (`git_dirty: yes`). `--demo` is on by default and only adds read-only presentation panels to the live figure (`demo_panels.py` reads `statedf` / `refr` / `last_logged_k`), so the data are unaffected. `input_params_header.csv` has one name per line; columns are read by name.
- **Onset = `kk_onset`**, not `kk`. With `kk_onset`, pre-onset ΔF/F is ~0 and the command 0 mW. With `kk` (the AL_0041 rule) the "pre" window is inside the stimulus: ΔF/F −1.7 to −3.2 %, command 5–18 mW. `kk − kk_onset` = 103–105 samples, because `kk` is logged at trial end. Timeline check: all 164 trials match a `lightCommand638` rising edge, 19.7 ms (median, p95 50 ms) after the blue frame at `kk_onset`, with epoch duration 2.997 s and Timeline V within 4% of `laser_out.laser_v`. The 34 extra Timeline epochs all fall inside CL trials, where the command touched 0 mW.
- **trial_type decoding** (`Main_experiment.py` `TRIAL_TYPES` and `control()`): 0 = Exp Start, trials 1–15. These are gain/Kref tuning, logged as mode 1 even though trials 1–6 have Kp = Ki = 0, and are excluded. 4 = custom, trials 16–65: 50 CL trials at Kp 5 / Ki 0.75 / Kref 1, whose command mean is `custom_mw_trial_avg`, identical to 1e-14 mW. 1 = Analyze, trials 66–164: mode drawn at random from {0, 0.5, 1}, giving OL 30 / CL 36 / replay 33 at the same gains. The comparison uses the Analyze block only.
- **Units:** mW; OL = Kref·R = 5 mW, i.e. 0.30 old uval at 16.81 mW/uval; CL mean 17.6 mW, replay 18.0 mW. The red calibration failed QC.
- **Result** (states.csv, RMSE over 0–3 s to ref −5 %):
  - **RMSE:** OL 3.68 ± 1.14, CL 2.77 ± 0.88, replay 2.78 ± 0.72. Ranksum: CL vs replay p = 0.85, OL vs CL p = 8e-4, OL vs replay p = 9e-4.
  - **Across-trial variance, 0–3 s:** OL 4.42, CL 3.79, replay 2.90 (%ΔF/F)².
  - **Steady state:** neither CL nor replay reaches the ref; both plateau near −3.3 %.
**Why:** The user asked for the AL_0048 OL-best replay session to be added as a new session for the supplement. The new rig format breaks the AL_0041 conventions (`loadData` parsing, `kk` meaning, uval), so it needs its own loader.
**Next:** The user decides how it enters the supplement (OLbest figure). Note that OL here is Kref·R = 5 mW, an under-dosed fixed input rather than the best fixed input. Check whether the PI integrator saturates or resets, given the plateau at −3.3 % instead of −5 %. No pixel maps were made (SVD has no `corr` folder).

### 2026-10-21 — Introduction rewritten and installed (Closedloop 3f75ae2, pushed)
**Changed/Found:** `Closedloop_edit/introduction.tex` was replaced with the rewrite, which is 1229 words excluding citations and cites 46 keys.
- **Structure:** six paragraphs:
  - why modulate, and the limits of open loop;
  - modelling the state versus feedback;
  - the mesoscale (10 mm field, 35 Hz, 24 ms latency);
  - what closed loop has achieved;
  - the gap as three questions (linearity, variability, state);
  - what we did.
- **`refs.bib`:** added Ambrosone2025, Zhang2025 and deAlteriis2026. The build was clean: 41 pp, no undefined citations.
- **Working copy and notes:** `paper-writing/introduction_draft_2026-10-21.md`.
- **Novelty re-run found two things:**
  - Ambrosone 2025 (Brain Stimul) already shows wide-field suppression deepening with laser power. The old intro's "monotonic … has not been tested" was therefore dropped; our result is now reported "as in open-loop silencing".
  - A KCL FENS 2026 abstract (de Alteriis … Khan) reports preliminary closed-loop wide-field control. The intro therefore makes no "first" claim; its single "to our knowledge" points to that abstract.
- **Tone pass against the Discussion:**
  - "designed from it" became "on that basis built … tuned to the experiment", because the gains were empirical (Discussion L9, L72).
  - Nozari's "better than nonlinear" became "about as well as".
  - The integral-action sentence was hedged and cut to Logemann only.
  - Only offset-like state is called a disturbance, as in Discussion L17.
  - "anesthetized"; "four mice"; "brain state".

**Why:** Aditya asked for the rewrite (funnel structure, discovery lead, originals only), then "takes whats good from main and add to this intro", then "main this the intro in main repo and push", after a tone check against the Discussion.

**Next:**
- Aditya pulls into Overleaf.
- Get the KCL abstract text, or drop deAlteriis2026.
- Confirm the Logemann & Curtain conditions in the paper.
- Trim toward the ~750-word limit.
- Two Discussion issues, left unedited:
  - L70 has a typo ("wide bran activity") and a run-on sentence;
  - it never cites Gupta2026, Ambrosone2025 or the KCL abstract, although the intro now does.

### 2026-10-20 — Discussion: clearer ZAPBench error-floor sentence (Closedloop 2faf7f7, pushed)
**Changed/Found:** `discussion.tex` line 30. "Authors of a zebrafish whole-brain benchmark expect an irreducible error floor" now says what the floor is and why: activity has random sources and depends on unobserved processes such as neuromodulation, so even a perfect forecasting model leaves some error. Checked against Lueckmann et al. 2025 (ZAPBench, ICLR, pp. 9–10), which says the floor's size is unknown. The new sentence makes no claim about its size. Builds with 0 undefined references. The earlier 5 commits (d911ce8..75bbd67) are also pushed.
**Why:** the user found the old line unclear and approved the rewrite ("do it push to main").
**Next:** user pulls into Overleaf.

### 2026-10-20 — Manuscript: Table 4 best-fixed rows, OLbest supp figure, one Methods file + pass
**Changed/Found:** Closedloop_edit `main` was fast-forwarded to the user's Overleaf push 40a9323. Five local commits followed, NOT pushed (waiting on the user):
- d911ce8: `stat_tables.tex` regenerated. The diff against the Overleaf version was only the 3 best-fixed rows and footnote b.
- 4acfe97: `fig:best_fixed` (`images/supplementary/OLbest.pdf`) added after Table S1. The text already cited it in 5 places.
- 4b26815: `methods_rewrite.tex` renamed to `methods.tex`; the dead `methods.tex` and `methods_edit.tex` deleted.
- 7367d15: Methods reflowed to one sentence per line. Script-verified as whitespace-only (949 → 652 lines).
- 75bbd67: Methods pass. 25 semicolon-joined clauses split into sentences, the dangling "(see Discussion)" dropped (the user deleted the Discussion's hemodynamics sentence), "it asserts" → "it assumes" (M7 stance), "Figure~" → "Fig.~", Table 1 caption reflowed.

`latexmk` gives 40 pages and 0 undefined references. Snippet check: all major snippets are in. Not pasted, on purpose: m8 (tested range / 3.5-fold spread), m19 (sex), "Over the tested powers" in the Abstract. The user rewrote m18 their own way.
**Why:** the user asked for the table update, the figure, one Methods file and a pass, with returns only at sentence ends. They also said: "dont add edits without asking i deleted some sentences" (saved to memory).
**Next:** user approves the push of `main`. Report the "wide bran activity" typo in their Discussion limitation sentence and ask before fixing. `paper-writing/CLAUDE.md` file map updated.

### 2026-10-20 — Best-fixed-input supp figure assembled (OLbest.pdf) and checked
**Changed/Found:** the user assembled `paper/figures_final/OLbest.pdf` (+ `.ai`) from the four `supp_best_fixed` panels. It is 17.6 × 3.83 cm, vector only (0 embedded images), with fonts embedded. Panel letters are 10 pt, like Figure2/S3/S5, and the text is 6–7 pt. B and C share a y-range, and the content matches the SF-1 caption. The PAPER.md registry row now points at it.
**Why:** check before the figure goes into the manuscript.
**Next:** after the user pushes their Overleaf edits, add the figure to Closedloop_edit `supplementary.tex`. Copy it as `images/supplementary/OLbest.pdf`, use label `fig:best_fixed`, and add the references from the M1-3 / M2 snippets.

### 2026-10-20 — Review M2/M11: rough K_r is off by about 30%, and sessions are roughly consistent within a mouse
**Changed/Found:** scratch check, no script changed. It uses c* from `ctrl_best_fixed_ol.mat` and K_r from Table S1. c* has median 1.29 (IQR 1.06–1.40, range 0.78–1.67); 9/15 sessions are within a factor of 4/3. The gain that would have been best, K_r* = K_r·c*, is 0.077–0.105 in Mouse 2 (CV 0.14, 4 sessions over 11 days) and 0.10–0.28 in Mouse 1 (CV 0.29, 9 sessions over 3 months). K_r and c* are not correlated (Spearman −0.28, p = 0.31).
**Why:** M2 says K_r was fit on another signal; M11 says it was retuned every session. The user's stance is that a rough gain from earlier sessions is enough because feedback compensates.
**Next:** user must say how K_r was set for Mice 2 and 4 and for 1a (before impulse 1b). The Methods/Discussion snippets are given in chat.

### 2026-10-20 — Review M11: dropping session 1e (three Kp values) leaves Fig 3H/3I unchanged
**Changed/Found:** scratch rerun of `ratio_session_stats` on `data/fig3_ratio_stats.mat` R3 without m4 (1e), n = 14. RMSE CL/OL: 0–1 s 0.84 [0.79, 0.89], 1–3 s 0.68 [0.61, 0.75], 14/14 below one. Variance: 0.64 [0.52, 0.79] (13/14) and 0.53 [0.45, 0.63] (14/14). All stimulation-window LMM p ≤ 0.003. CL/best fixed input without 1e: 0.91 (p = 0.029) and 0.80 (p = 0.21).
**Why:** 1e interleaved three Kp values, so the reviewer asks whether it drives the pooled result.
**Next:** one sentence in the Table S1 caption (snippet in chat).

### 2026-10-20 — Supplementary figure: closed loop vs best fixed input (review M1)
**Changed/Found:** `controller-analysis/ctrl_best_fixed_ol.m` gains a `[BFO-SUPP]` section with four 4.0 × 3.4 cm paper panels (`paper/images/supplementary/supp_bfo_*.pdf`):
- A: laser command in the median-c* session (1d): OL as run 1.69 V, best fixed 2.18 V, CL mean ± SD (2.06 V over 1–3 s). The command amplitude is a 40 ms moving peak, because the early sessions are 40 Hz-modulated.
- B, C: per-session RMSE at 0–1 s and 1–3 s.
- D: CL/OL command vs c*, with ρ = 0.66.

The trial averages are now saved as `TR`. The panels are registered in `MANIFEST.txt` [supp_best_fixed] and the PAPER.md registry, then mirrored with PAPER_FINAL. Two run-time fixes: labels carry a "Mouse " prefix, and `T.capped` is double, so it is indexed via `logical`. A '\rho' inside sprintf was read as a carriage return, so the title is now concatenated.
**Why:** the user asked for the M1 review figure as a supplementary figure. A first showed trial-averaged ΔF/F, and the user rejected it ("dont show trial averaged but input trace plots it just confuses the reader"). The Fig 3 example (2a) is not used because its OL was already near the reference (c* = 1.05).
**Next:** assemble the four panels in Illustrator as `images/supplementary/S_best_fixed.pdf`, then paste the figure environment on Overleaf.

### 2026-10-20 — Stats tables: M1 best-fixed-input rows added to STATS_TABLE + Table 4
**Changed/Found:** `paper-writing/paper_stats_table.m` now reads `controller-analysis/data/ctrl_best_fixed_ol.mat` and adds 6 rows (`3H_best_{early,late,full}_{lmm,t}`). A diff of STATS_TABLE.csv confirms all 140 earlier rows are unchanged. `paper-writing/paper_stats_tex.m` adds a "Tracking RMSE, closed loop / best fixed input" block to Table 4, with footnote b (definition; df fall to 2.6 and 1.0). It compiles cleanly in a scratch copy of 43fabaf (no overfull boxes or undefined references).
**Why:** the stats-table section promises every statistic quoted in Results, and the M1 text will quote these ratios.
**Next:** user pastes the regenerated Table 4 on Overleaf (Overleaf-only, so `stat_tables.tex` is not regenerated in Closedloop_edit).

### 2026-10-20 — Review M1: closed loop vs the best fixed open-loop input
**Changed/Found:** `controller-analysis/ctrl_best_fixed_ol.m` (new). Under the paper's linear model with an additive trial-to-trial disturbance, an OL trial is b + h(t) + n_i(t), and a rescaled fixed command gives b + c·h + n_i. c* minimises the 0–3 s squared error to −5% on the same OL trials (an in-sample oracle, which favours OL) and is capped at the 2.45 V limit (binding in 1a and 1c). All 15 sessions; stats via `utils/ratio_session_stats`, the Fig 3H scheme.
- The CL/OL check reproduces Table 4 exactly (0.85, 0.68, 0.77).
- c* median 1.29 (0.78–1.67). The median stim-window offset falls from 1.47 (OL as run) to 0.29 %ΔF/F.
- Best/OL: 0.92 [0.88, 0.97] for 0–1 s, 0.85 [0.76, 0.94] for 1–3 s, 0.89 [0.83, 0.95] for 0–3 s.
- **CL/best: 0.92 [0.85, 0.99] for 0–1 s, 0.80 [0.73, 0.89] for 1–3 s, 0.87 [0.80, 0.93] for 0–3 s, 13/15 sessions below 1 in each window.** LMM p = 0.036 (t(14) = −2.33), 0.22 (t(2.6) = −1.62; the mouse variance is non-zero, so df collapses) and 0.17 (df 1). One-sample t p = 0.036, 2.4e-4 and 0.001.
- About half the CL advantage over OL as run is calibration, half is feedback beyond the best fixed input.
- The mean CL command (1–3 s) relative to the OL command has median 1.16 (0.75–1.90), against c* median 1.29. Spearman ρ = 0.66, p = 0.0086; median |log(uCL/c*)| = 0.08. So feedback moved the average command toward the best fixed input in each session (1f: OL overshot, CL 0.75 vs c* 0.78).
- Under this model across-trial variance is independent of c, so the Fig 3I reduction (35–46%) is not a calibration effect (M10 tests the level-dependence caveat separately).
**Why:** blind review M1. The OL arm is a deliberately rough calibration (user), and the reviewer asked how much of the CL advantage survives against the best constant input.
**Next:** draft the M1 text (Methods K_r sentence, new Methods paragraph, Results, Discussion). Caveats: linear scaling to c* up to 1.67× is extrapolated beyond the power that ran, and the in-sample c* favours OL. 3e's `ncInp` is in different units (uOL 0.003), but its cap is not binding. The user plans real best-fixed-input experiments before submission.

### 2026-10-20 — Minor review points: Overleaf snippet set drafted
**Changed/Found:** `paper-writing/REVIEW_2026-10-20_minor_snippets.md` (new) has find/replace LaTeX for m1, m3–m8, m14, m15, m17–m19, plus a new Abstract and Significance Statement. Those two also carry the agreed M7 ("within a session") and M8 ("simulated", credit to the linear model) wording and come to 249/250 and 119/120 words. It adds one Discussion sentence on Zhang2018, which the user flagged (PMC6513754 = Zhang et al. 2018 Nat Methods, already cited): their on/off "activity clamp" held single-cell GCaMP6s ΔF/F at 30/50/80% with |error| 5.2 ± 4.7% (18 cells, 6 awake mice). No snippet for m2, m13, m16 (skipped by user decision), m20 or m21.
**Why:** user: "lets do minor ones first"; snippet mode (Overleaf-only since 2026-10-20).
**Next:** user pastes the snippets on Overleaf. m20 needs the 470/405 nm illumination intensity and Matveev's no-activation evidence from the user. Then the major points, one at a time.

### 2026-10-20 — Review m4: whole-session loop latency (Mouse 4)
**Changed/Found:** `controller-analysis/ctrl_latency.m` (unchanged; run on AL_0051 2026-07-29/2). Measured from the exposure start of the source blue frame to the laser edge on the Timeline. CL: n = 3539 updates, median 24.0 ms, IQR 24.0–24.5, 99th percentile 40.0, max 43.5 ms; 12.6% arrived after the next blue frame (>28.5 ms). OL: n = 103, max 41.0 ms. Command→frame mapping ρ = 0.9996. Consistent with the paper's "at most 47 ms" (Fig 1F, 200 cycles). The channel that fired is `lightCommand594`, while Methods say 638 nm; asked the user, likely a channel name.
**Why:** reviewer m4: 200 cycles (~6 s) is too few to bound worst-case latency.
**Next:** only one 2026-build session can be measured this way; the 2025 sessions use an older log format. Confirm the laser wavelength with the user.

### 2026-10-20 — Review m5: Fig 4C robust to the two small sessions
**Changed/Found:** `controller-analysis/data/f4_error_decomp.mat` (read only; scratch script). There are 11 sessions, 613 CL trials, 16–108 per session (1h = 16, 1f = 24). Dropping 1f and 1h moves every mean adjusted unique R² by ≤ 0.03. Transient: init-dev 0.53 → 0.52, abs δ 0.11 → 0.13. Steady state: abs δ 0.11 → 0.14, rel δ 0.03 → 0.04, init-dev 0.03 → 0.05. Motion stays ≈ 0. The factor ordering is unchanged.
**Why:** reviewer m5: adjusted R² at n = 16 with 3 predictors is noisy.
**Next:** none beyond the Fig 4C caption snippet.

### 2026-10-20 — Review m6: post-stimulation window asymmetry explained; Table 4 caption
**Changed/Found:** `controller-analysis/variance_mse.m` (read): post-stim RMSE uses 3–4 s because the stored trial segment `ncDfk` ends 1 s after offset (L450–453, L482–486), while variance uses a separate 3 s buffer. `paper-writing/paper_stats_tex.m`: the Table 4 caption now gives that reason ("RMSE, the end of the stored trial segment").
**Why:** reviewer m6 asked to justify or harmonize; justifying needs no rerun.
**Next:** if the user wants the windows equal, compute the variance post window over 3–4 s and rerun Table 4.

### 2026-10-20 — Review m20/m21: reference status checked
**Changed/Found:** Crossref: Gupta2026 = eLife vol. 14 RP105070, VOR 2026-09-24 (the entry is correct; the reviewer's concern is unfounded). Ye2026 = Science 392:eadx1369, 2026-06-18 (correct). bioRxiv API: Matveev2024 (10.1101/2024.11.01.621418) is still v1 only, with no published version.
**Why:** reviewer m20/m21.
**Next:** m20 needs the key illumination parameters from the user.

### 2026-10-20 — Blind review round (PDF only): major revision; Table 4 CI/test mismatch confirmed
**Changed/Found:** `paper-writing/REVIEW_2026-10-20.md` (new). A fresh reviewer agent got only the compiled PDF of Closedloop 43fabaf, with no CLAUDE.md, project context or earlier reviews. It returned 12 major and 21 minor points and a major-revision recommendation. Spot-checked against source:
- **M12 is real.** Table 4's "Ratio [95% CI]" is the raw geometric mean with a one-sample-t CI (`paper_stats_table.m` L111 stores `r.geo`/`r.geoCI` in the `_lmm` row). Only t, df and p are from the mixed model. The pre-stimulation rows therefore disagree: variance ratio 1.04 with LMM t = −0.03; RMSE CI [1.00, 1.03] with LMM p = 0.84, against t-test p = 0.07. The LMM's own ratio is in `r.lmm_ratio`.
- **m1 is real.** `results.tex` L296 ends mid-sentence ("The improvement over open loop demonstrates the").
- **The M1 sentence is as quoted.** Methods L543–544 says "share the same K_r, so the comparison … does not depend on its value". The reviewer's point holds: OL error depends on K_r calibration, CL corrects it.
- **M2 and M11 follow from the Eq. 9 text.** It says K_r was estimated "from the impulse-response experiments", but Mice 2 and 4 had none.
**Why:** user asked for a new review round with no context given to the reviewer.
**Next:** user decides which points to act on. Analysis asks: best-fixed-input OL baseline (M1), pre-stim state window (M4, conflicts with the locked [−2, +3) s window; pre-only was tested and killed motion), saturation audit (M5), hemo-corrected rerun (M2/M3), out-of-class MPC plant (M8), all-13-session RR (M9), mean-matched variance (M10), drop-1e check (M11), and which ratio/CI Table 4 reports (M12).

### 2026-10-20 — paper_stats_tex: correct Table 4 caption (CI is t-based, not mixed-model)
**Changed/Found:** `paper-writing/paper_stats_tex.m` — Table 4 caption now says the ratio is the geometric mean with its t-based 95% CI, and that t (df) and p come from the mixed model. Earlier today I had rewritten it as "95% CI from the mixed model", which is false (see the review entry above). That wrong caption is on Closedloop `main` 43fabaf.
**Why:** caption error I introduced in the Table 4 one-test edit, caught while checking the blind review's M12.
**Next:** user pastes the corrected caption on Overleaf (they now edit only there). The Ratio/CI vs LMM-test mismatch itself (M12) still needs a decision.

### 2026-10-20 — Fig 2 / Fig S2-quartile / Fig 4G panels rebuilt with global session labels
**Changed/Found:** Ran with `PAPER_FINAL = true` (serial MCP calls, cold `load_experiments` → 4 sessions): `dose_response` → `figure2/imp_response.pdf` (2.89 × 3.10 cm, direct labels Mouse 5a/5b/1b/3c); `imp_tf_cv` → `tf_cv_2D_sidebar.pdf` + `tf_cv_single_AL_0033.pdf` (CV numbers unchanged: pooled held-out R² 0.846); `imp_tf_figs` (FIG_PANELS swap+tau, cached fits) → `tf_model_swap.pdf`, `tf_tau_forest.pdf` (ticks M5a/M5b/M1b/M3c); `imp_state_trialvar` + `imp_state_var_combined(STV.R)` → `imp_state_var_combined.pdf` (no session labels; Q4/Q1 0.58/1.03/2.32 as before); `imp_state_raster_peramp` → `sq_{mot,dpr,dpa}_rmice.pdf` + cbars; `imp_state_quartile_supp` → all `sq_*` + `sq_legend.pdf`; `f4_cl_reject_panel` → `figure4/f4_cl_reject_RR.pdf` (11 sessions, ticks 2a 1h 1f 2d 1d 2b 1e 1j 1l 3e 1k; LMM RR 0.58 [0.46,0.72] p=1.3e-4 unchanged). Labels verified by pdftotext on the final PDFs + MATLAB renders for rotated ticks. `paper_stats_tex` re-run to scratch: byte-identical (bar line endings) to `Closedloop_edit/stat_tables.tex`, which already carries Mouse 1b/3c (Closedloop_edit 43fabaf) → not overwritten. ⚠ `tf_cv_2D_sidebar.pdf` now exports 4.76 × 3.39 cm vs the 3.99 × 3.35 MANIFEST note.
**Why:** the 2026-10-19 global session-label rule (`utils/paper_session_label.m`, 8956579) changed printed labels; code was switched but the locked panels still carried per-panel labels.
**Next:** Illustrator: update links in `FIgure2.ai` (7 linked panels) and `FIgure2_supp.ai` (16 links; it still links the retired `sq_divider.pdf`); `FIgure4.ai` links only `f4_row2_quartiles.pdf`, so 4G is EMBEDDED and must be re-placed from `panels/figure4/f4_cl_reject_RR.pdf`. Check 2D sidebar width in the layout. No hand-typed session labels found in the .ai files (only panel letters are native text).

### 2026-10-20 — imp_state_quartile_supp.m: legend labels from the registry (was hard-coded M1/M3)
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — `legLab = {'M5a','M5b','M1','M3'}` and the unused `SESS_LAB` were hard-coded with the pre-2026-10-19 names, so `sq_legend.pdf` (Fig S2 state-quartile) still printed M1/M3. Both now come from `imp_mouse_label(SESS_ID)` over the four impulse sessions → M5a M5b M1b M3c. The 10-19 switch missed it because it never called the label helper. Repo sweep for other hard-coded `'Mouse N'`/`'MN'` literals in analysis code: none left.
**Why:** one label registry project-wide (user 2026-10-19).
**Next:** none

### 2026-10-20 — Seed FC panel locked as a supp panel (figure TBD)
**Changed/Found:** `paper/figures_final/MANIFEST.txt`: new `[supp_seedfc]` section listing `supp_seedfc/seedfc_group.pdf`. `PAPER.md`: added a row to "Supplementary figures in use" (figure TBD). Rebuilt with `PAPER_FINAL = true`: `paper/figures_final/panels/supp_seedfc/seedfc_group.pdf` (jn-style, 17.11 × 4.73 cm cropped). `collect_final_panels('dry')`: 128 present, 0 missing, 0 to prune.
**Why:** user: "this is a legitimate supplementary panel… put it in paper figures, I'll decide which figure it goes into; give me a paper-style PDF".
**Next:** user to assign it to a supp figure / LaTeX label and cite it from the variance paragraph. The m2 midline check is still open.

### 2026-10-20 — Seed FC supp panel: one row OL / one row CL, paper m-numbering, r_base − r_stim
**Changed/Found:** `controller-analysis/ctrl_seed_fc_group.m` `panel()`: 17.6 × 5.0 cm. Row 1 = OL, row 2 = CL, 12 sessions per row in paper order m2…m13 (`paper_m()` table copied from `load_sessions.m`; m1 = AL_0033 01-20 has no stim-site cache, so it's absent). The plotted quantity is now **r_base − r_stim** (positive = coupling to the site lost), in the maps and the side scatter. Colormap switched to brown–white–teal (BrBG) because red/blue are the locked OL/CL condition colours. The scatter title carries n and the paired p. Numbers unchanged: CL r_base − r_stim +0.154 (12/12 > 0), OL −0.011, CL vs OL p = 0.0005.
**Why:** user: use the paper's session numbering, put all sessions in one row per condition, and plot baseline − stim instead of baseline and stim separately.
**Next:** decide lock (MANIFEST.txt + PAPER.md); m2 (AL_0033 0212) still shows its site near the midline, so check its midline.

### 2026-10-20 — Manuscript: new Discussion + Intro, Remark 1 removed, global session labels, Table 1
**Changed/Found:** `Closedloop_edit` 43fabaf (on `main`, pushed). `discussion.tex` / `introduction.tex` replaced by the 2026-10-19 restructure (~1860 / ~770 words; over the 1500 cap by user choice for arXiv), with 10 new refs in `refs.bib`. `main.tex`: `\captionsetup{font=small}`. `methods_rewrite.tex`: Remark 1 (`rem:lowgain`) and the paragraph checking its conditions (i)–(iv) removed (its last point kept: bounded command + stable plant → oscillation is the only visible instability). Table 1 (`tab:cohort`) lost Trials/session and Contributes-to; the session-to-analysis mapping moved into the caption. Fig 3 Methods text for the per-trial corroborating model and the Wilcoxon check was removed. Session labels from `session_labels_snippets_2026-10-19.md` applied to Results, Methods and Supplementary (Table S1 now keyed by label). Fig 2B caption counts corrected from Overleaf's "N= 50 80 and 100" to 44–59 / 81–85 / 100. Build: 39 pp, no undefined refs or cites.
**Why:** user batch request 2026-10-20 ("put these restructured discussion and intro as the main", small captions, drop Table 1's last two columns, align to the global labels, remove Remark 1).
**Next:** figures not regenerated yet (Fig 2 and Fig 4G labels; the user will update them). Abstract still says performance "improves with movement", which does not match the Discussion's "movement none". Untracked `paper-writing/{discussion_restructure,introduction_draft}_2026-10-19.tex` are now superseded.

### 2026-10-20 — paper_stats_tex: Table 2 one row per session, Table 4 one test only
**Changed/Found:** `paper-writing/paper_stats_tex.m` — Table 2 (`tab:stat_counts`) now has one row per session (amplitude list, trials per amplitude as a range, total), down from one row per amplitude. Table 4 (`tab:stat_fig3`) keeps only the session-level mixed model ($t$, df, $p$); the one-sample $t$-test and Wilcoxon columns and panel B (per-trial mixed model) were dropped. They are still in STATS_TABLE.csv. All numbers are unchanged. Found: three Overleaf hand-edits to `stat_tables.tex` that the generator would have reverted. "1 mW per 3 V" had been removed from the Table 2 caption, the Gap trend gloss read "(not interpreted; Materials and Methods)", and Table 4 had `\footnotesize\setlength{\tabcolsep}{4pt}`. The first two are ported; the third is no longer needed at 6 columns.
**Why:** user: "compress table 2"; "table 4 refers to 3 different tests why, lets only talk about one relevant one". Results text quotes only the mixed-model $p$ values, and Methods names the mixed model as primary.
**Next:** none. Hand-edits to `stat_tables.tex` on Overleaf get lost on regeneration, so port them to the generator.

### 2026-10-20 — Seed FC supp panel: per-session Δr maps replace the pooled map
**Changed/Found:** `controller-analysis/ctrl_seed_fc_group.m` `panel()` rewritten. The panel is now 17.6 × 9.8 cm (double column): 12 per-session Δr maps for OL (rows 1–2) and 12 for CL (rows 3–4). Each map shows its own brain outline, the common nodes inside its own mask, and its own site (star), labelled `ALxx MM-DD eN  ±Δr`. One Δr colorbar; the per-session OL-vs-CL scatter is kept on the right. Stats unchanged (CL Δr −0.154, 12/12, p = 0.0005; OL +0.011, p = 0.30). The pooled-map columns and the overlay of all 12 sites are removed.
**Why:** user: drawing all sessions' stim sites on one shared brain looked wrong; show per-session maps instead and keep the side scatter.
**Next:** AL_0033 0212 (transposed view) has its site at ML +0.11, near the midline. Check whether that's real or a midline estimate issue. Then the user decides whether to lock the panel.

### 2026-10-19 — Paper-wide session labels: one registry, global date-order letters
**Changed/Found:** `utils/paper_session_label.m` (new) — single registry of every session in the paper → "Mouse <n><letter>", letters in date/exp order over ALL of a mouse's sessions (m1..m15 → 1a,1c,1d,1e,1f,1h,1j,1k,2b,2a,2d,1l,2c,3e,4; impulse AL_0033 = 1b, AL_0048 = 3c; grid 1g, auto-tune 1i; sine 3a/3b/3d). `utils/imp_mouse_label.m` now wraps it (errors if a bare mouse name repeats). Callers switched to pass session structs: `dose_response.m`, `f2b_trial_counts.m`, `f2_slope_ci.m`, `imp_state_examples_supp.m`, `imp_state_raster_peramp.m`, `imp_state_raster_supp.m`, `imp_tf_cv.m`. `f4_cl_reject_panel.m` Fig 4G ticks use the registry. `data/fig2b_trial_counts.csv` relabelled (1→1b, 3→3c). Verified in MATLAB: all 15 m-indices, the impulse set and tag formats map correctly.
**Why:** user rule 2026-10-19. Old code lettered within each panel, so Fig 2 printed "Mouse 1" for one of Mouse 1's 12 sessions and Fig 4G relettered Mouse 1 after dropping m2 (and gave single-session Mouse 3 a spurious "3a").
**Next:** regenerate Fig 2 panels (run_fig2, PAPER_FINAL) and Fig 4G, relink in Illustrator, re-run paper_stats_tex; paste `paper-writing/session_labels_snippets_2026-10-19.md` on Overleaf.

<!-- older entries → RESEARCH_archive_2026H2.md (then RESEARCH_archive_2026H1.md) -->
