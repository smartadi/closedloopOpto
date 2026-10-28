# stats_v2 — clean-room rebuild spec (v1, 2026-10-27)

Goal: recompute the paper's Fig 3 and Fig 4D statistics from the lowest locally available data tier,
with code written fresh in Python, so that no error from the existing MATLAB pipeline can carry over.
The result is compared with the published numbers only **after** the build is finished.

## 1. Independence rules (the builder must follow these)

1. **Do not read** any of: `paper-writing/STATS_TABLE.csv`, `paper-writing/STATS_AUDIT.md`, `RESEARCH*.md`,
   `FINDINGS.md`, `TASKS.md`, `MEETINGS.md`, `PAPER.md`, `../Closedloop_edit/*`, any `data/*.mat` other than the
   15 session caches below, any `controller-analysis/data/*`, and any existing `.m` analysis script.
   (This spec already contains every format fact you need.)
2. From each session cache, read **only** `d.*` and `data.dFk`. Do **not** read anything else under `data`
   (`er_*`, `vr_*`, `nc`, `wc`, `ncDfk`, `wcDfk`, `pncDfk`, `ncInp`, `wcInp`, `*motion`, `*Freq*`). Those are the
   old pipeline's derived outputs.
3. All code lives in `stats_v2/` (Python only). Use the venv at `stats_v2/.venv` (numpy, scipy, pandas, h5py).
   Run Python with `-I`. All outputs go to `data/stats_v2/` (git-ignored; create it).
4. Never write anywhere else. Never write to the lab servers. Do not run MATLAB.
5. Where this spec is ambiguous, choose, write the choice into `data/stats_v2/CHOICES.md`, and continue.

## 2. Inputs

Caches are MATLAB v7.3 (HDF5): open with `h5py`. Arrays come out transposed relative to MATLAB
(`input_params` is rows × trials in h5py). Char arrays are uint16 codes.

| id | mouse | date | exp | cache file (`data/`) | validation trials | build |
|---|---|---|---|---|---|---|
| m1 | AL_0033 | 2025-01-20 | 3 | AL_0033ctrl01203.mat | 120 | old |
| m2 | AL_0033 | 2025-02-12 | 2 | AL_0033ctrl02122.mat | 200 | old |
| m3 | AL_0033 | 2025-02-24 | 2 | AL_0033ctrl02242.mat | 200 | old |
| m4 | AL_0033 | 2025-02-26 | 2 | AL_0033ctrl02262.mat | 200 | old |
| m5 | AL_0033 | 2025-03-04 | 1 | AL_0033ctrl03041.mat | 60 | old |
| m6 | AL_0033 | 2025-03-05 | 2 | AL_0033ctrl03052.mat | 30 | old |
| m7 | AL_0033 | 2025-03-20 | 4 | AL_0033ctrl03204.mat | 100 | old |
| m8 | AL_0033 | 2025-04-15 | 2 | AL_0033ctrl04152.mat | 60 | old |
| m9 | AL_0039 | 2025-04-20 | 1 | AL_0039ctrl04201.mat | 100 | old |
| m10 | AL_0039 | 2025-04-19 | 1 | AL_0039ctrl04191.mat | 100 | old |
| m11 | AL_0039 | 2025-04-30 | 3 | AL_0039ctrl04303.mat | 100 | old |
| m12 | AL_0033 | 2025-04-19 | 1 | AL_0033ctrl04191.mat | 100 | old |
| m13 | AL_0039 | 2025-04-20 | 2 | AL_0039ctrl04202.mat | 100 | old |
| m14 | AL_0048 | 2026-07-29 | 2 | AL_0048ctrl07292.mat | 100 | new |
| m15 | AL_0051 | 2026-07-29 | 2 | AL_0051ctrl07292.mat | 100 | new |

Format facts (from the rig's file format):
- `d.timeBlue`: imaging frame times, s (~35.09 Hz, dt ≈ 0.0285 s). `data.dFk`: the controlled site's ΔF/F in
  **% ΔF/F**, one value per frame, same length as `timeBlue`. **Accept `dFk` as given** (the ΔF/F definition is
  locked; it cannot be recomputed here because raw frames are not local for the old builds).
- `d.inpTime`, `d.inpVals*`: laser command, V, 2000 Hz. Old builds have `inpVals`. New builds have `inpVals`,
  `inpVals594`, `inpVals638`.
- **Active laser channel rule:** per session, the active command channel is the `inpVals*` field with the
  largest 99.9th percentile. Record it. (Known: in m14 the active channel is `inpVals638`, not `inpVals`.)
- `d.input_params`: one column per trial (in h5py, rows = fields). Row 3 (index 2) = condition: **0 = open loop
  (OL), 1 = closed loop (CL)**. The **validation block = the last N trials** (N from the table). Only validation
  trials enter any analysis.
- Onsets: `d.stimStarts` (s, `timeBlue` clock), one per trial. **Onset frame = the frame whose `timeBlue` is
  nearest to `stimStarts`.** For new builds, also check that `stimStarts ≈ timeBlue[kk] − dur`, with
  `kk = input_params row 2` read as a 1-based frame index (the trial-END frame); report the disagreement.
- `d.params.dur` = 3 (s) in all sessions. `d.ref` = −5 (% ΔF/F), the reference.
- `d.motion`: per-frame motion energy, already z-scored over the session (mean 0, SD ≈ 1), on the `timeBlue`
  clock. A session **has motion** if `d.motion` is not constant. Expected: 11 of 15 sessions.

## 3. Definitions

Fs = 35 frames/s. Let `o` be the onset frame. Sample offsets are relative to `o`.

**Windows** (inclusive sample ranges):

| name | samples | seconds |
|---|---|---|
| pre | o−105 … o−1 | −3 to 0 |
| early (transient) | o … o+34 | 0 to 1 |
| late (steady state) | o+35 … o+105 | 1 to 3 |
| full (main) | o … o+105 | 0 to 3 (106 samples) |
| post_rmse | o+106 … o+140 | 3 to 4 |
| post_var | o+106 … o+210 | 3 to 6 |

**Per-trial RMSE** in window W: `sqrt(mean((dFk[W] − ref)^2))`, in % ΔF/F.

**Across-trial variance** in window W, per session and condition: at each sample offset, the variance across
that condition's trials (ddof = 1). Average over the window's samples.

**Per-session ratios**:
- RMSE ratio = mean CL per-trial RMSE / mean OL per-trial RMSE.
- Variance ratio = CL window variance / OL window variance.
- Below 1 means closed loop is better.

**Fig 4D states** (per trial). Use one peri-stimulus window for all states: **[−2, +3) s = o−70 … o+104,
175 samples.**
- *initial deviation* = |dFk[o] − ref|.
- *motion* = mean of `d.motion` over the window (motion sessions only).
- *relative δ* = P(2–4 Hz) / P(0.4–10 Hz), from `dFk` over the window.
- *absolute δ* = log10 P(1–4 Hz), from `dFk` over the window.

**Band power estimator P(lo, hi)** (the locked 'continuous' estimator):
1. Linear detrend the segment, then apply a symmetric Hann taper of length N.
2. FFT with nfft = max(8192, next power of 2 ≥ 8N).
3. One-sided PSD = |X|² / (Fs · Σw²), with interior bins doubled.
4. Integrate by trapezoid between the exact edges lo and hi, interpolating the PSD linearly at lo and hi.

**Fig 4D outcome** = per-trial steady-state RMSE (late window).

**Fig 4D state scaling.** Within each session, standardise each state across that session's validation trials
(both conditions pooled): z = (x − mean) / SD. Slopes are therefore "per within-session SD".

## 4. Analyses

### Fig 3 (15 sessions)
For each session and each window (pre, early, late, full, post): compute the RMSE ratio (post uses post_rmse)
and the variance ratio (post uses post_var).

### Fig 4D (15 sessions; motion: motion sessions only)
For each state and session:
- **P** = OLS slope of steady-state RMSE on z-state, OL trials.
- **R** = OLS slope, CL trials.
- **A** = (OLS slope of log RMSE on z-state, CL) − (same, OL). Report it also as 100·(e^A − 1) % per SD.
- **gap** = mean OL steady-state RMSE − mean CL steady-state RMSE.
- **gap_change** = P − R.

### Prep covariate (pre-specified before any look at its relation to the benefit)
Per session, the fraction of CL command samples over 0–3 s (active channel) at a bound:
- lower bound: |u| < 0.01 V;
- upper bound: u ≥ 0.99 × the session's maximum CL command.

Report the lower, upper and total fractions. Relate each to the full-window RMSE ratio across sessions with
Spearman ρ (two-sided). This is **supplementary**.

## 5. Tests (`stats_v2/tests.py`, one function used everywhere)

`sess_test(values, mouse, log)`: values = one number per session (log-transform first when `log=True`, for
ratios). Returns:
- n, mean, and the effect (geometric mean when `log`);
- 95% CI (t-based, df = n−1);
- one-sample t (two-sided): t, df, p;
- **exact** Wilcoxon signed-rank p (two-sided);
- sign count k/n;
- leave-one-mouse-out: the t-test p after dropping each mouse in turn, and the worst one;
- mouse-averaged: one mean per mouse, how many share the overall sign, and the t-test p across mice.

Apply it to:
- every Fig 3 ratio (log). The **main** test is full RMSE and full variance; the rest are secondary. For pre
  and post, report the effect and CI (the p is still computed, but flagged `null_window`);
- every Fig 4D P, R and A (not logged), 12 in total. Also report the Holm-adjusted p across the 12
  (the P and R slopes as one family of 8, A as one family of 4), as a separate column; do not drop the raw p;
- gap and gap_change: effect and CI.

## 6. Checks to report (`data/stats_v2/CHECKS.md`)
- Per session: trials in input_params; validation N; OL/CL counts; active channel; has_motion.
- Onset sanity: the laser command (active channel) should rise within ±2 frames of each onset. Report the
  median and maximum offset per session, and every trial outside ±2 frames.
- New builds: the stimStarts vs `timeBlue[kk] − dur` disagreement.
- Any NaN or out-of-range window, and what was done about it.
- Whether trial conditions look randomly interleaved: the number of runs vs a runs test, per session.

## 7. Outputs (`data/stats_v2/`)
- `trials.csv`: one row per validation trial. Columns: session id, mouse, trial index, condition,
  onset_s, onset_frame, RMSE per window, the 4 states, max command (active channel).
- `session_fig3.csv`: per-session ratios.
- `session_fig4d.csv`: per-session P, R, A, gap, gap_change per state.
- `prep.csv`: per-session bound fractions.
- `tests.csv`: one row per test. Columns: figure, quantity, window or state, role
  (main / secondary / null_window / supplementary), n, effect, ci_lo, ci_hi, t, df, p, wilcoxon_p, k, n,
  lomo_worst_p, mouse_k, mouse_n, mouse_p, holm_p.
- `manifest.json`: git commit hash, UTC time, Python and package versions, SHA-256 of every input cache,
  and the list of fields read.
- `CHOICES.md`, `CHECKS.md`.

## 8. Out of scope for v1 (stated so nobody assumes otherwise)
- **ΔF/F itself** (accepted from `data.dFk`; raw frames are not local for the old builds).
- **Fig 4G** (needs contralateral pixels and a predictor, which are not in the caches). After the build, its
  statistics are re-tested from the saved per-trial RR with the same `tests.py`.
- **Fig 2G** (impulse sessions, another loader). Re-tested from the saved per-session values.
- **Best fixed input** (needs the model-based counterfactual). Re-run with the old producer once the m14
  laser-channel bug is fixed.
- **Fig 6 / sine** (descriptive; unchanged).
