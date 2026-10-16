# Decision pending: Fig 2 impulse TF window (0–0.5 s vs −0.5 to +1.0 s)

*Written 2026-10-15. Status: **OPEN**, waiting on Aditya. Nothing in Fig 2 has changed.*

## The question
Should the Fig 2 TF fits (2C/2D/2F, model swap, tau forest) move from the current
**0–0.5 s** window to **−0.5 to +1.0 s**, which includes real pre-onset data and the post-dip rebound?

## What the new fit does differently
| | Current (Fig 2) | Alternative |
|---|---|---|
| Fitted window | 0–0.5 s post-onset | −0.5 to +1.0 s |
| Pre-onset | synthetic zero lead-in | 17 real pre-onset samples |
| Trial reference | onset frame `dF(b)` | each trial's own −0.5..0 s mean |
| Order selection | AIC + R2h ≥ 0.98 escalation | BIC + stable poles + same escalation |
| Bootstrap | 300 draws, tau beyond 0.5 s discarded | 300 draws, tau beyond 1.03 s discarded |

**Why the pre-mean reference:** tfest assumes zero initial conditions. The onset-frame reference
turns one noisy frame into a constant offset (pre-window sits at −0.06 to +0.09 %/V). The pre-mean
reference makes the pre-onset segment zero-mean by construction.
**ITI check:** the nearest preceding stim of any kind (AL_0048's interleaved excitatory L-site
pulses included) is ≥ 2.5 s before onset in every session. So −0.5..0 s is ≥ 2 s after the previous
onset, past the rebound (gone by ~0.77 s). No contamination.

## Results, old → new
Sessions: M5a, M5b = AL_0041 e1/e2; M1 = AL_0033; M3 = AL_0048. "Dip" = fastest oscillatory
pole pair; "rebound" = slowest mode.

| | M5a | M5b | M1 | M3 |
|---|---|---|---|---|
| Order | 3p1z → 5p2z (escalated) | 4p3z → 4p2z | 4p3z → 4p3z | 5p4z → 4p3z |
| Dip τ, s [new 95% CI] | 0.106 → 0.073 [0.02–0.19] | 0.112 → 0.093 [0.01–0.13] | 0.114 → 0.095 [0.05–0.16] | 0.144 → 0.100 [0.01–0.22] |
| Rebound τ, s [new 95% CI] | ~10⁶ → 1.51 [0.18–0.99] | 0.97 → 0.68 [0.15–0.96] | 0.27 → 0.32 [0.17–0.82] | 1768 → 0.18 [0.15–0.97] |
| Bootstrap discard | 41% → 61% | 73% → 52% | 3% → 5% | 100% → 15% |
| Pooled R², new on 0–1 s / 0–0.5 s | 0.69 → 0.35 / 0.61 | 0.62 → 0.54 / 0.72 | 0.86 → 0.84 / 0.88 | 0.91 → 0.85 / 0.95 |
| R² over 0.25–1.0 s (rebound) | −0.52 → 0.87 | −2.12 → 0.97 | −2.55 → 0.84 | −0.04 → 0.94 |

- Old rebound R² = current models extrapolated past 0.5 s.
- Old discard rates are totals only: the old cache predates the beyond-window / failed split.
- Model swap (free gain): self R² 0.992 → 0.985; off-diagonal mean 0.691 → 0.704, median 0.724 → 0.761.

## For switching
- The rebound is captured in every session; the current models get it wrong past 0.5 s (negative R²).
- Predicted rebound peak matches measured: 0.10 vs 0.11, 0.30 vs 0.29, 0.23 vs 0.26, 0.54 vs 0.48 %/V.
- 3 of 4 sessions at 4 poles, all poles stable. The rejected 2026-10-03 0–1.0 s run sent every
  session to the 5-pole cap.
- Dip τ is tighter across sessions (0.073–0.100 s vs 0.106–0.144 s).
- M3's slowest pole is no longer a near-integrator (1768 s → 0.18 s); its bootstrap now has a CI.
- The pre-mean reference removes the need for the AL_0048 seeded-start workaround.

## Against switching / caveats
- **Rebound τ is still poorly identified:** its CI runs to the 1 s window edge in 3 of 4 sessions,
  so a tau forest would mostly show censored intervals.
- **M5a stays weak:** escalated to 5 poles, 61% bootstrap discard, pooled R² 0.35 on 0–1 s.
- **M5b:** 52% of draws have the slow pair beyond the window.
- **No cross-validation yet:** `imp_tf_cv` has no pre-onset-data path, so there is no held-out R²
  to set against Fig 2D's 0.86.
- Switching changes every Fig 2C–F number and the Methods text (window, reference, selection rule).

## If switching, still to do
1. Add a `preData_s` / `refMode` path to `imp_tf_cv` (+ `imp_tf_cv_session`) and rerun CV.
2. Decide what 2F shows for the rebound: drop it, show censored, or report dip only.
3. Point the producers at the new fits, rebuild panels with `PAPER_FINAL` on, update `MANIFEST.txt`.
4. Methods: window, pre-mean reference + why, ITI check, BIC + stability.
5. Update every Fig 2C–F number in Results and captions.

## Where things are
- Engine knobs: `utils/imp_tf_fit_session.m` (`preData_s`, `refMode`, `refPre_s`, `enforceStab`, `select='bic'`).
  Defaults reproduce the current Fig 2 fits exactly.
- Runner: `impulse-analysis/imp_tf_altwin.m` → `impulse-analysis/data/imp_tf_fits_win_m0p5_1p0.mat` (lab PC only, gitignored).
- Panels: `impulse-analysis/imp_tf_altwin_figs.m` → `paper/images/figure2/alt_window/`
  (`alt_fit_overlay.png`, `alt_tau_forest.png`, `alt_model_swap.png`).
- Log: RESEARCH.md, 2026-10-15 (three entries: engine knobs, config sweep, results).
- Fits take ~25 min per session (sweep + bootstrap). Run them as background `matlab -batch` jobs
  (`ALT_SESS=k`, then `ALT_MERGE=true`), not through the MATLAB MCP tool, which times out at 30 min.
