# DECIDED: Fig 2 impulse TF window stays 0–0.5 s (alternative −0.5 to +1.0 s rejected)

*Written 2026-10-15. **Status: DECIDED 2026-10-15 (Aditya): keep the 0–0.5 s window, change nothing in Fig 2.** Deciding evidence: the open-loop step check below (the alternative fits predict 96–110 % relaxation of sustained suppression within 1 s; measured 7 %). Everything below is kept as the record.*

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

## Added 2026-10-15: how much does each mode matter? (`imp_tf_modes.m`)
Both fit sets, partial-fraction decomposed. Dip = fastest complex pair; offset = tau > 10 s (old M5a,
old M3), excluded; rebound = slowest remaining mode. Figures: `alt_window/modes_overlay.png`, `modes_step.png`.

| | M5a | M5b | M1 | M3 |
|---|---|---|---|---|
| Dip τ / freq, current → alt | 0.106 s 2.4 Hz → 0.073 s 1.8 Hz | 0.112 s 4.1 Hz → 0.093 s 2.1 Hz | 0.114 s 4.2 Hz → 0.095 s 3.8 Hz | 0.144 s 3.2 Hz → 0.100 s 3.5 Hz |
| Rebound τ [CI], alt | 1.51 [0.18–0.99] | 0.68 [0.15–0.96] | 0.32 [0.17–0.82] | 0.18 [0.15–0.97] |
| Modal energy dip/rebound, current → alt | 100/– → 76/20 | 11/89 → 65/35 | 26/74 → 9/25 | 7/33 → 33/67 |
| Cancellation index, current → alt | 1.0 → 2.1 | 1.0 → 1.0 | 1.7 → 8.9 | 7.1 → 2.4 |
| **Measured** energy in 0–0.25 s (of 0–1 s), pre-mean / onset ref | 80 / 72% | 65 / 39% | 76 / 67% | 88 / 79% |
| **Measured** rebound peak, % of dip trough, pre-mean / onset ref | 18 / 6% | 45 / 68% | 29 / 35% | 28 / 35% |
| **Data-predicted** step: relaxation by 1 s | 0% (still deepening) | 111% | 117% | 59% |
| Model step relaxation by 1 s, current / alt | 12 / 0% | 66 / 118% | 76 / 116% | 130 / 59% |
| Model 3 s step: relaxation / offset overshoot, alt | 23 / 23% | 93 / 94% | 132 / 132% | 58 / 58% |

**What it says:**
1. **Per-mode energy shares are not usable.** Modes cancel (DC shares up to ±1800%,
   cancellation index up to 8.9) and the split flips between fit sets (M1 dip 26% → 9%, M3 7% → 33%).
   For "dominated by the dip", use the model-free number: 65–88% (median 78%) of h(t) energy in the first 250 ms.
2. **The "slow drift removed by the integral term" claim is not what the impulse data predict.**
   The rebound is small in amplitude (18–45%) but long, so its area offsets most of the dip's area.
   Under LTI, a sustained input's suppression peaks at ~0.2 s and relaxes 59–117% within 1 s in
   3 of 4 sessions (M5a is the exception). That is fast relaxation, not gradual drift. The alt models
   reproduce this data-derived number; the current models do not.
3. **But the closed loop holds a sustained −5% for 3 s,** which needs non-zero plant DC gain. So the
   impulse data probably do not constrain sustained behaviour: the rebound may be an offset
   (post-inhibitory) effect rather than a linear mode, or the DC gain is simply not identifiable from
   a ≤1 s impulse window. **Check before writing the sentence:** compare open-loop sustained-stim trial
   averages (Fig 3 OL trials) with the impulse-model step prediction.
4. **Dip τ moves ~20% shorter with the longer window** (median 0.113 → 0.094 s), and the dip frequency
   drops in M5a/M5b (4.1 → 2.1 Hz). The old "2.4–4.2 Hz pair, τ ~0.11 s" partly absorbed the rebound.
   Consistent across sessions within each set, not invariant to the window.
5. **Rebound τ is still not identified** (CI upper ends at the 1 s window edge; 42/50% of draws
   beyond the window in M5a/M5b).

## Added 2026-10-15: open-loop sustained-stim check (`imp_tf_ol_stepcheck.m`) — the deciding test
Open-loop controller trials apply a near-constant 0.3–1.3 V laser command for 3 s with no feedback.
Figure: `paper/images/figure3/alt_step_check/ol_step_vs_impulse.png`. 15 sessions, 4 mice:

| | measured OL | impulse-model prediction (Mouse 1, 9 sessions) |
|---|---|---|
| Peak suppression time | median 1.20 s (0.57–2.80) | ~0.2 s |
| Relaxation by 1 s | median **7%** (2–22%) | **79–87%** current fits, **96–110%** alt fits |
| Relaxation by 3 s | median **21%** (5–37%; AL_0048 72%) | 76–79% current, 133–137% alt |
| Overshoot after laser offset | median **+27%** of peak (+7 to +90%) | +79–83% current, +135–141% alt |

**Verdict: the suppression is sustained, and the rebound is an offset (release) effect, not a linear mode.**
Both models get the first ~0.3 s of the step right (the dip), then predict the suppression collapsing;
the data hold it, with slow relaxation and a rebound only when the laser turns off. This matches the
closed loop holding −5% for 3 s. So the planned Results wording is right, but its support is the OL
step data, not the impulse LTI model (which predicts the opposite).

**Revised recommendation: keep 0–0.5 s.** The extra window's main gain was a rebound mode, and that mode
describes sustained input wrongly (the alt fits are actually the furthest from the data, 96–110% vs 7%).
The plant model should carry the dip dynamics, which both fits capture and which match the step onset;
describe the rebound empirically (impulse rebound 18–45% of the dip; OL offset overshoot median 27%).

**Suggested Results sentences:**
- "The response is dominated by the dip: 65–88% (median 78%) of the impulse response energy falls
  within 250 ms of onset, carried by a damped oscillatory mode with τ ≈ 0.11 s (median 0.113 s)."
  (Energy share measured on h(t) with the pre-onset reference; the onset-frame reference gives 39–79%.)
- "The post-inhibitory rebound was small (18–45% of the dip amplitude, median 29%) and did not act as a
  linear mode: under 3 s of open-loop stimulation the suppression was sustained, relaxing by a median of
  7% at 1 s and 21% at 3 s (15 sessions, 4 mice), with a rebound (median 27% of peak) only at laser
  offset. This slow relaxation acts as a gradual drift that the integral term can absorb."
  ("can absorb" rather than "removes": closed-loop drift compensation was not measured here.)

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
