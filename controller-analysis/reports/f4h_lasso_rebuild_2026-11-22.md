<!-- ai: drafted by Claude for Aditya, 2026-11-22; not reviewed -->
# Fig 4H with the lasso Global: rebuild and report (research-hub #100)

Brain Paper, branch `hub/100-sparse-kernel`, RESEARCH L-2026-11-22-a to -c. Descriptive only: no significance test was run, at Aditya's request.

## Summary

With the Actual paired to the imaging by time, the lasso Global reconstructs the controlled site in every session (R² on the spot before onset, closed loop: median 0.83, range 0.70 to 0.92 over the 11 sessions inside the Fig 4H offset gate). In those 11 sessions the closed-loop rejection ratio RR (1 to 3 s) has a median of 0.64 (range 0.43 to 1.08) and is below 1 in 10 of 11. The same ratio on open-loop trials, where no loop acts, has a median of 1.12 (range 0.87 to 1.62), and the closed-loop RR is below it in 11 of 11. The size of the predicted disturbance matches the site's own open-loop fluctuation (calibration slope β median 0.95, range 0.82 to 1.22).

## What was wrong

The controller scripts paired the Actual (`data.dFk`, one sample per blue frame) with the imaging (V, one column per frame) by index. Two things broke that pairing:

- AL_0048 (Mouse 3e): V starts 11 blue frames after the Actual (54,828 V frames, 54,839 blue frames). The readout pixel from V correlates with the Actual at r = 0.96 when shifted by 11 frames and at r = -0.36 unshifted. Every AL_0048 kernel, including the one behind the paper's Fig 4H, was fitted and scored with the Actual 0.31 s away from the cortex that predicts it.
- The server's corrected V was recomputed on 2026-10-11 and now drops the first blue frame. Since then any code that reads the corrected V of AL_0033 0212, 0224, 0226, 0304 or AL_0039 0419, 0420 paired the Actual one frame apart. In the #100 kernels that is the 4 AL_0033 sessions; AL_0039 0419 and 0420 use the uncorrected V there.

`impulse-analysis/load_experiments.m` already maps V columns to blue frames through V's timestamps (since 2026-10-11). The controller code did not.

## What changed

- New `utils/ctrl_pair_on_v.m`: V column k is paired with the blue frame whose exposure starts last at or before V's timestamp k, the same mapping as `load_experiments.m`. The Stage-1 spontaneous frames are moved to V columns the same way.
- `ctrl_sparse_kernel.m` (ridge and lasso fits) and `ctrl_sparse_kernel_cl.m` (trials, D, RR) use it. All 13 sessions were refitted and rescored; `f4_rr_diag.m` and `f4_reject_examples.m` were rerun.
- The 5 sessions without V timestamps (AL_0033 0305, 0320, 0415, 0419 and AL_0039 0430) keep the identity pairing, so their kernels still reproduce the cached ridge exactly. AL_0051's timestamps are violet times and also map to the identity.
- New `f4_lasso_report.m` draws the report figures and writes `data/f4_lasso_report.csv`.

Lasso results before and after the fix, where they changed:

| Session | Test R² | R² on the spot, CL | RR, CL |
|---|---|---|---|
| Mouse 3e (AL_0048_0729) | 0.305 to 0.876 | 0.271 to 0.886 | 2.55 to 0.64 |
| Mouse 1c (AL_0033_0212) | 0.777 to 0.897 | 0.792 to 0.912 | 1.77 to 1.53 |
| Mouse 1d (AL_0033_0224) | 0.856 to 0.912 | 0.865 to 0.918 | 0.61 to 0.56 |
| Mouse 1e (AL_0033_0226) | 0.725 to 0.788 | 0.823 to 0.901 | 0.73 to 0.66 |
| Mouse 1f (AL_0033_0304) | 0.709 to 0.771 | 0.758 to 0.813 | 0.70 to 0.57 |

AL_0039 0419 and 0420 did not change: their kernels use the uncorrected V (the existing list in `ctrl_ols_ol_stimblind.m`), which keeps the identity pairing.

## Results per session (lasso)

R² on the spot: 1 - Σ(A - G)² / Σ(A - mean A)² over -1 to 0 s, trials pooled. RR: per trial Σ(A - r)² / ΣD² over 1 to 3 s, session geometric mean. OL placebo: the same ratio on open-loop trials with the site's fluctuation around its mean laser response in place of A - r. β: slope of that open-loop fluctuation on D.

| Session | In 4H gate | OL / CL trials | Test R² | R² spot OL | R² spot CL | RR CL | RR OL placebo | β |
|---|---|---|---|---|---|---|---|---|
| Mouse 1c (AL_0033_0212) | no | 97 / 103 | 0.90 | 0.90 | 0.91 | 1.53 | 1.11 | 1.01 |
| Mouse 1d (AL_0033_0224) | yes | 101 / 99 | 0.91 | 0.91 | 0.92 | 0.56 | 0.95 | 0.89 |
| Mouse 1e (AL_0033_0226) | yes | 92 / 108 | 0.79 | 0.88 | 0.90 | 0.66 | 1.00 | 0.90 |
| Mouse 1f (AL_0033_0304) | yes | 36 / 24 | 0.77 | 0.77 | 0.81 | 0.57 | 1.02 | 0.82 |
| Mouse 1h (AL_0033_0305) | yes | 14 / 16 | 0.61 | 0.70 | 0.70 | 0.43 | 1.15 | 0.91 |
| Mouse 1j (AL_0033_0320) | yes | 46 / 54 | 0.80 | 0.79 | 0.86 | 0.67 | 1.12 | 0.97 |
| Mouse 1k (AL_0033_0415) | yes | 38 / 22 | 0.74 | 0.74 | 0.77 | 1.08 | 1.17 | 0.96 |
| Mouse 1l (AL_0033_0419) | yes | 35 / 65 | 0.80 | 0.79 | 0.74 | 0.69 | 1.01 | 0.95 |
| Mouse 2a (AL_0039_0419) | yes | 48 / 52 | 0.84 | 0.84 | 0.83 | 0.46 | 1.62 | 1.22 |
| Mouse 2b (AL_0039_0420) | yes | 50 / 50 | 0.86 | 0.85 | 0.80 | 0.73 | 1.35 | 1.09 |
| Mouse 2d (AL_0039_0430) | yes | 50 / 50 | 0.89 | 0.90 | 0.88 | 0.56 | 1.12 | 0.98 |
| Mouse 3e (AL_0048_0729) | yes | 45 / 55 | 0.88 | 0.89 | 0.89 | 0.64 | 0.87 | 0.93 |
| Mouse 4 (AL_0051_0729) | no | 55 / 45 | 0.71 | 0.72 | 0.70 | 1.41 | 1.22 | 0.84 |

Over the 11 gated sessions the geometric mean of the session RR is 0.62 on closed-loop trials and 1.11 for the open-loop placebo.

## Open points

1. **One-frame offsets that the timestamps do not explain.** After the fix, the readout-pixel check (readout pixel from the V each kernel uses against the Actual, peak of the cross-correlation in each tenth of the session) finds the two aligned in 6 sessions: AL_0033 0224, 0226, 0304, AL_0039_0419, AL_0048 and AL_0051. AL_0033_0212 is off by one frame in every tenth. AL_0039_0430 and AL_0033_0419 are off by one frame in the other direction in every tenth, and AL_0033 0305, 0320, 0415 and AL_0039_0420 sit between 0 and 1 frame. All but 0212 use a V without timestamps. One frame is 29 ms. Correcting these from the check itself would be a new alignment step and needs Aditya's approval.
2. **The paper's trial builder still pairs by index.** `imp_build_session.m` is unchanged. Every Fig 4 number it feeds (the 4H panel, the state analyses that use the Global) carries the 11-frame error in AL_0048 and the one-frame error in the 6 corrected-V sessions. Fixing it changes paper numbers, so it is left for Aditya.
3. **Mouse 2a.** The lasso keeps 9 pixels and its β is 1.22, so its D is smaller than the site's open-loop fluctuation and its RR (0.46) is higher than it would be with a D of the right size. Ridge in the same session has β 0.98 and RR 0.29.
4. **Mouse 1k** is the one gated session with closed-loop RR above 1 (1.08); its open-loop placebo is 1.17.

## Figures

- `controller-analysis/_preview/f4_lasso_report_summary.png`: per session, R² (A), CL RR and OL placebo RR (B), β (C).
- `controller-analysis/_preview/f4_lasso_report_trials.png`: one OL and one CL trial per session, Actual and lasso Global.
- `controller-analysis/_preview/f4_reject_examples.png`: one CL trial per gated session, the CL error A - r and D.
