# NUMBERS.md — canonical number registry for the manuscript

Single source of truth for every *n*, count, and headline statistic that appears in
`Closedloop_edit/{results,discussion,methods_rewrite}.tex`. Built 2026-10-01 during the
number-consolidation pass.

**Rule:** the manuscript quotes this file; this file quotes code or a verified run. If a
number is not here, it does not go in the paper.

**Status flags**
- ✅ **VERIFIED** — traced to code or an independent run; safe to quote.
- 🟨 **DERIVED** — follows from a verified number but has not itself been printed by a run.
- 🟥 **CONFLICT** — two sources disagree; must be resolved by a run before submission.
- ⬜ **NEEDS RUN** — nobody has computed it; a named script will produce it.
- 👤 **NEEDS ADITYA** — only the user has it (animal records, rig hardware).

---

## 1. Cohorts

### 1.1 Closed-loop cohort (Figure 3) — ✅ VERIFIED
Source: `controller-analysis/load_sessions.m` (m1–m15), the registry every script loads.

| id | mouse | date | exp | trials | motion trace |
|---|---|---|---|---|---|
| m1 | AL_0033 | 2025-01-20 | 3 | 120 | ✗ none |
| m2 | AL_0033 | 2025-02-12 | 2 | 200 | ✓ |
| m3 | AL_0033 | 2025-02-24 | 2 | 200 | ✗ none |
| m4 | AL_0033 | 2025-02-26 | 2 | 200 | ✓ |
| m5 | AL_0033 | 2025-03-04 | 1 | 60 | ✓ |
| m6 | AL_0033 | 2025-03-05 | 2 | 30 | ✓ |
| m7 | AL_0033 | 2025-03-20 | 4 | 100 | ✗ none |
| m8 | AL_0033 | 2025-04-15 | 2 | 60 | ✗ none |
| m9 | AL_0039 | 2025-04-20 | 1 | 100 | ✓ |
| m10 | AL_0039 | 2025-04-19 | 1 | 100 | ✓ |
| m11 | AL_0039 | 2025-04-30 | 3 | 100 | ✓ |
| m12 | AL_0033 | 2025-04-19 | 1 | 100 | ✓ |
| m13 | AL_0039 | 2025-04-20 | 2 | 100 | ✓ |
| m14 | AL_0048 | 2026-07-29 | 2 | 100 | ✓ |
| m15 | AL_0051 | 2026-07-29 | 2 | 100 | ✓ |

**Totals: 15 sessions / 4 mice.** AL_0033 = 9, AL_0039 = 4, AL_0048 = 1, AL_0051 = 1.
Trials/session: AL_0033 30–200, all others 100. Dates span 2025-01-20 → 2026-07-29.

- **Motion trace present in 11 of 15.** The 4 without are **m1, m3, m7, m8** (all AL_0033),
  motion identically zero — ✅ VERIFIED by independent `h5read` of all 15 caches
  (RESEARCH 2026-09-15). Trial counts (OL+CL) match declared totals in all 15; the
  OL/CL split varies per session (Bernoulli assignment), e.g. m5 36/24, m12 35/65, m6 14/16.
- AL_0050 was recorded the same day as m14/m15 and **excluded for poor stimulation** —
  👤 criterion still unstated in Methods.
- ⚠ The Methods cohort table matches this table for the closed-loop rows (counts, dates,
  trials/session all check out).

### 1.2 Impulse cohort (Figure 2) — ✅ VERIFIED
Source: `impulse-analysis/f2_slope_ci.m` run of 2026-08-30 (RESEARCH 2026-08-30).

| Fig 2A label | session | slope | R² | trials |
|---|---|---|---|---|
| Mouse 1a | AL_0041 e1 | −0.34 | 0.97 | 208 |
| Mouse 1b | AL_0041 e2 | −0.57 | 0.51 | 260 |
| Mouse 2 | AL_0033 2025-01-29 e1 | −0.59 | 0.92 | 748 |
| Mouse 3 | AL_0048 (right hemisphere) | −0.96 | 0.91 | 300 |

**Totals: 4 sessions / 3 mice**, Σ = 1516 trials. "Mouse 1a/1b are two sessions of one
animal" = AL_0041 e1/e2. Fig 2B shows **Mouse 1b**; Fig 2C shows **Mouse 2**.

- 🟥 **The Methods cohort table is wrong here.** It credits impulse characterization to
  **AL_0041 only, 2 sessions**, and omits AL_0033 and AL_0048. Three of the six rows need
  their "Contributes to" column corrected, and AL_0048 contributes to **three** analyses
  (impulse Fig 2, closed loop Fig 3, sinusoid Fig 5) — currently shown as closed-loop only.
- 🟥 **Fig 2G states 1767 trials / 4 sessions** against Σ = 1516 here. Different pool (2G
  likely admits amplitude-0 trials or uses a different QC gate). ⬜ Resolve by printing the
  2G pool size from its generator.
- ⚠ Presentational note: Fig 2B's representative session (Mouse 1b) is the **weakest linear
  fit of the four** (R² = 0.51). Consider showing Mouse 2 (R² = 0.92) instead, or state why.

### 1.3 Sinusoid cohort (Figure 5) — ✅ VERIFIED (from the draft, consistent internally)
AL_0048, right hemisphere, inhibitory opsin, 1 Hz reference, 4 s window. Representative
session 200 sinusoidal trials, n = 51 / 46 / 46 / 57 for OL / OL+p / CL / CL+p.
Consistency across **3 sessions**; pooled OL n = 136, CL n = 100.
**1 mouse / 1 hemisphere / 1 drive frequency.**

---

## 2. Laser amplitude and calibration

### 2.1 Volt → milliwatt calibration — 🟥 CONFLICT (two factors live in the code)
- **Canonical: `vToMW = 1.8/4.9 = 0.3673` mW/V** ("0 V = 0 mW, 4.9 V = 1.8 mW"), used in
  `impulse-analysis/spatial_spread.m:24`, `impulse-analysis/prestim_variance.m:255,342`,
  `presentation/export_ampmaps.m:19`.
- **`impulse-analysis/imp_tf_cv.m` uses `/3` = 0.3333 mW/V instead** (RESEARCH 2026-09-24,
  "Units changed V → mW (`S1.amp.uA(a)/3`)").
- ⇒ **Fig 2C's amplitude labels are computed ~10 % low relative to Fig 2A/2B.** Fix
  `imp_tf_cv.m` to the canonical factor and re-export 2C, then re-check its legend values.

### 2.2 Amplitude sets differ per session — 🟥 CONFLICT with the Methods
| session | levels | range (mW) | range (command V) |
|---|---|---|---|
| AL_0033 2025-01-29 | **9** | 0.18 – 1.80 | 0.49 – 4.90 |
| AL_0041 e2 (Fig 2B) | **6** | 0.23 – 0.87 | 0.63 – 2.37 |
| set quoted in Methods | **5** | 0 – 0.99 | 0, 0.8, 1.6, 2.4, 2.7 |

The Methods presents **one session's** five-level set as if it were the protocol, in volts,
while the Results quote "0–1.8 mW" (the AL_0033 session) and Fig 2B quotes six levels.
All three are individually right; the Methods must say the set was **per session** and give
them in mW with the one calibration.

- ✅ All five levels of the Methods set **were delivered as commanded** — the 2.45 V
  microcontroller clamp does not apply, because the impulse rig is a separate earlier system
  and there is a downstream voltage amplifier (RESEARCH 2026-09-30).
- ⚠ The paper must say **once** which domain its volts live in: command volts at the
  microcontroller output, *before* the amplifier.
- 👤 Amplifier gain, so command volts can be stated as mW at the focal plane.

### 2.3 Evoked suppression window — 🟥 naming + arithmetic
Definition (`eq:inhib_energy`): mean ΔF/F over `W = {t_on … t_on+6}`, **7 samples at 35 Hz**.
- 7 samples spans **171 ms**, not the "200 ms" stated in the Methods and both Fig 2 places.
- The quantity is a **mean**, not an energy or an integral. Methods renamed it *evoked
  suppression*; **Results L62 and the Fig 2A caption still say "Total inhibition energy …
  integrated over 0–200 ms"** and must follow.

---

## 3. Figure 2 — LTI model

| quantity | value | status |
|---|---|---|
| Pooled held-out R² (trial-cross-validated) | **0.857** amp-normalised (0.870 shape), median over 4 sessions × 200 splits | ✅ `imp_tf_cv.m` — manuscript's "0.86" ✓ |
| Per-session held-out R² | AL_0041 e1 **0.503** [0.045 0.760]; e2 **0.863**; AL_0033 **0.948**; AL_0048 **0.841** | ✅ same run |
| Fast time constant | ~0.14 s (0.14–0.15 s in 3 of 4 sessions) | ✅ draft; 🟥 see below |
| Slow time constant | ~0.2–0.3 s, more variable | ✅ draft |
| Settling time | "~200 ms" | 🟥 inconsistent with τ = 0.14 s (4τ ≈ 0.56 s). Define the criterion or drop the consistency claim |
| Plant order | **two real poles** | 🟥 Discussion calls it "lightly damped second-order, resonant near 2.2 Hz" and builds the ~2.6 Hz bandwidth argument on that resonance. Resolve against `tab:tf_sessions` |
| Cross-session model swap (2E) | diagonal high / off-diagonal lower | ⬜ **no numbers anywhere** — print diagonal vs off-diagonal medians |

### Fig 2G — state dependence (quartile ratios, top vs bottom)
| state | ratio | CI | p | sessions | control ratio |
|---|---|---|---|---|---|
| motion | 0.71 | [0.60, 0.84] | 1.5e-7 | 4/4 | 0.79 |
| relative 2–4 Hz | 1.10 | [0.94, 1.27] | 0.005 | **3/4** | 1.00 (ρ=+0.001, p=0.96) |
| absolute 2–4 Hz | 1.99 | [1.69, 2.37] | <1e-16 | 4/4 | 2.10 (ρ=+0.37) |

- 🟥 **Pool size 1767 trials** — see §1.2.
- 🟥 The dissenting rel-δ session is **AL_0048** (within-session ρ = **−0.062**, n = 300) vs
  +0.115 / +0.192 / +0.086 for the others; stratified ρ = +0.081. **Not named in the paper.**
- 🟥 rel-δ **reverses sign on the independent Ye/Zhiwen dataset** (ρ = −0.25; robust median
  −0.33, 99 % of 150 pixels negative) vs our +0.29 — FINDINGS §state-dependence. Unreported.
- ⚠ rel-δ also weakened ~6× under the pseudoreplication fix. Motion is 4/4 and robust; rel-δ
  is the load-bearing weak link and should be stated as weak-but-real near the noise floor.

---

## 4. Figure 3 — closed vs open loop

| quantity | value | status |
|---|---|---|
| Cohort | 15 sessions / 4 mice | ✅ §1.1 |
| Reference | −5 % ΔF/F, 3 s stimulation window | ✅ project default |
| Gains, AL_0033 2025-02-26 | Kr 0.1, Kp 0.07, Ki 0.1 | ✅ |
| LMM p, cross-trial variance | 2e-7 (0–1 s), 5.6e-14 (1–3 s); n.s. pre and post | ✅ draft caption |
| LMM p, tracking RMSE | 5.4e-9 (0–1 s), 2.5e-18 (1–3 s) | ✅ draft caption |
| 15-session variance slopes | pre −0.23 / during −0.53 / post +0.18 | ✅ `variance_mse.m` (RESEARCH 2026-09-08) |
| Batch-mean stationarity | **14 of 15** sessions do not drift; **AL_0051 (m15)** drifts (+1.63 SD, OLS & Spearman p<0.001), m14 borderline p=0.05 | ✅ `batch_mean_stationarity.m` — Methods' "14 of 15" ✓ |
| Motion exclusion threshold | z-motion > 1.5 | ✅ locked |

- 🟥 **Per-session gains for the other 12 sessions are missing** (`tab:gains` has 3 rows, 2 of
  them missing Kr and Ki). Each session logs Kref/Kp/Ki per trial in `input_params.csv`, so
  ⬜ this table is **generatable**, not a 👤 item. Do that rather than typing it.
- 🟥 **Fig 3 caption colour key contradicts itself**: panel A says closed-loop = green, panel B
  says blue. Locked scheme is **CL = blue**, OL = red, input = grey.

---

## 5. Figure 4 — ⚠ THE MAIN PROBLEM: "11 sessions" means three different things

The manuscript says "11 closed-loop sessions" as if one set. There are at least **three
distinct 11-session sets** in play, plus two distinct 13-session pools:

| # | set | definition | n | mice | status |
|---|---|---|---|---|---|
| **S1** | contra-predictor reachable | of m1–m13, those with full-frame SVD + ROI **and** passing the Stage-2 frame-alignment guard. m1 has no full-frame SVD; **m13** (AL_0039 2025-04-20 e2) fails the guard (`dFk` 91800 vs SVD 91875 frames) | 11 = {m2…m12} | **2** (AL_0033, AL_0039) | ✅ RESEARCH 2026-08-?? ("11 is the complete reachable set, not an omission") |
| **S2** | motion-complete | sessions with a real motion trace | 11 = all but m1, m3, m7, m8 | 4 | ✅ §1.1 |
| **S3** | RR reachers | the 13-session RR pool minus the 2 that never reach setpoint (**AL_0033 2025-02-12**, **AL_0051**) | 11 | **3** | ✅ RESEARCH 2026-09-29 |

**S1 ≠ S2 ≠ S3.** S1 is two mice; S3 is three mice and includes AL_0048/AL_0051, which are
*not* in S1. So the Fig 4 caption's single "11 sessions" is at best ambiguous and at worst
wrong for two of the three panels it covers.

### 5.1 Panels B/C — error decomposition — ✅ VERIFIED
**397 closed-loop trials / 7 sessions.** Panel C title is literally `Unique R^2 (n=397, 7 sess)`.
Unique R², early (0–1 s) → settled (1–3 s):

| factor | early | settled |
|---|---|---|
| initial deviation | 0.29 | 0.004 |
| motion | <0.01 | <0.01 |
| relative 2–4 Hz | 0.10 | 0.12 |
| absolute 2–4 Hz | 0.23 | 0.35 |

✅ These match the manuscript exactly. All 7 motion sessions enter the per-session dots
(`minTr` lowered 25 → 12 so the 16-trial m6 is not silently dropped).

- 🟥 **Which 7?** Presumably S1 ∩ S2. But S1 ∩ S2 = {m2,m4,m5,m6,m9,m10,m11,m12} = **8**,
  not 7. ⬜ **One session is unaccounted for — print the session list from the generator.**
  This is the single most important open number in the paper.
- ⚠ The older `cl_rmse_factor_windows.m` / `f4_partB_panels.m` three-factor version reported
  **613 CL trials / 11 sessions** with different values (init-dev 0.381→0.029, rel 0.089→0.122).
  That version is **superseded** — do not quote 613/11 anywhere.

### 5.2 Panel D — state quartiles + session-aware LMM — 🟥 CONFLICT
Caption currently says: **11 sessions, 1240 trials; motion 7 sessions, 760 trials.**
The 2026-09-16 independent audit of the production `f4_row2_pool` + `f4_row2_fit` gave:

| factor | trials | sessions | mice |
|---|---|---|---|
| initial deviation | 1670 | **15** | 4 |
| motion | 1190 | **11** | 4 (= S2) |
| relative / absolute δ | 1670 | **15** | 4 |

The pool was evidently re-run after that audit (the motion interaction moved from
−0.202 / p=0.003 to −0.212 / p=0.0042, and the manuscript quotes p=0.004). ⬜ **Re-run
`f4_row2_pool` + `f4_row2_fit` and print per-factor n (trials / sessions / mice) and the
session list.** Until then the caption's 11/1240/7/760 is unverified.

🟨 **Likely but unconfirmed:** 760 = OL+CL trials in the motion sessions, 397 = CL-only in
the same sessions, 1240 = OL+CL across the 11. If so, 397 vs 760 is not an error — but the
paper must say which counts are CL-only and which are both conditions. Right now it doesn't.

LMM read-outs currently in the paper (all from `RMSE ~ cond*state + (1+cond|sess) + (1|mouse)`,
state centred/scaled within session):

| state | "predictability" (OL slope) | "controllability" (cond×state) |
|---|---|---|
| initial deviation | p = 4.5e-7 | p = 0.394 n.s. |
| motion | p = 9e-5 | p = 0.0042 |
| relative 2–4 Hz | p = 0.34 n.s. | p = 0.0182 |
| absolute 2–4 Hz | p = 3.5e-26 | p = 0.876 n.s. |

OL–CL gap at mean state: p ≤ 1.6e-11 for all four.

- 🟥 `methods_rewrite.tex:957` **misnames the model term**: it calls the *condition* main
  effect the predictability term. Predictability is the **open-loop slope on state**.
- ⚠ "predictability↓" is used in the text to mean "open-loop error rose", which is disturbance
  **magnitude**, not predictability.

### 5.3 Panel G — disturbance rejection ratio — ✅ VERIFIED
`RR = ‖A−r‖² / ‖D‖²`, settled 1–3 s, D leak-corrected and referenced to its own no-laser baseline.
`log RR ~ 1 + (1|mouse) + (1|mouse:session)`, one-sided on the intercept.

| quantity | value |
|---|---|
| geometric-mean RR | **0.58**, 95 % CI [0.48, 0.71] |
| intercept | −0.537 (SE 0.097, t(594) = −5.56) |
| one-sided p | **2.1e-8** |
| pool | **595 trials / 11 sessions / 3 mice** |
| session-median RR (the dots) | 0.72, 11/11 < 1, signrank p = 9.8e-4 |
| full pool before the reach gate | 13 sessions (11/13 < 1, p = 0.040) |
| excluded by the reach gate | AL_0033 2025-02-12 (settled mean A = −2.76), AL_0051 (−3.38) — gate = settled mean within 1.5 %ΔF/F of ref |

- 🟥 The manuscript quotes n = 11 sessions but **omits 595 trials and 3 mice**. With only 3
  mice the `(1|mouse)` term has three levels; say so.
- ⚠ Panel shows median 0.72 while the text leads with geomean 0.58. Both are correct; the
  caption should name which is which (decision on record: LMM geomean is the headline, session
  median is the dot summary).
- ⚠ **No open-loop comparator.** RR is CL-only. Computing RR on the OL trials of the same 11
  sessions is the obvious control and is nearly free — see the review's item D23.

### 5.4 Contra→ipsi predictor R² — 🟥 CONFLICT (three sets, two sharing a value)
| where | claim |
|---|---|
| Results L143 | held-out pre-stimulus windows, representative session: **0.85** OL / **0.89** CL |
| Results L151 | A = G + L reconstruction, cross-validated: **0.85** OL / **0.78** CL |
| Fig 4F caption | **R²_te = 0.75** |

⬜ Re-print all three from `ctrl_ols_xsess` / `f4_contra_model` output. The reuse of 0.85 in
two different roles, and 0.75 vs 0.78 for what looks like the same panel, both need resolving.
Methods also promises R² "against two nested nulls, Global alone and trial-average alone" —
⬜ those nulls are never reported.

- 🟥 **Estimator**: Methods says **ordinary least squares**; Fig 4E caption says **ridge weights**.
- ✅ Admission gate: sessions enter the decomposition only at predictor R² > 0.3 (⬜ count removed).

---

## 6. Figure 5 — sinusoidal tracking

| quantity | value | status |
|---|---|---|
| median per-trial RMSE, OL → CL | 3.82 → 2.80 % ΔF/F, rank-sum p = 7.7e-4 | ✅ draft |
| across-trial variance, OL → CL | 17.9 → 14.8 | ✅ draft; ⚠ **units missing** ((% ΔF/F)²) |
| pooled per-trial RMSE | OL 4.58 ± 1.77 (n=136), CL 3.83 ± 1.94 (n=100), rank-sum p = 1.5e-4; Kruskal–Wallis χ² = 19.6, p = 2.1e-4 | ✅ draft; 🟥 **pooled-trial tests = pseudoreplication** |
| session-level test | Friedman p = 0.060, n = 3 — underpowered, direction only | ✅ draft, honestly reported |
| phase lag | OL 60°, CL 36°, OL+p 5°, CL+p −9° | ✅ draft |
| preview lookahead | 5 samples at 35 Hz = 143 ms = **51.4°** at 1 Hz | ✅ draft |
| error partition, 3-session mean | at-frequency OL 3.14 → OL+p 0.89; CL 1.78 → CL+p 1.22. Broadband OL 10.55 → CL 6.62 (% ΔF/F)² | ✅ draft |
| constant-offset term | — | 🟥 **the Discussion claims it carries "the majority of total error power" but it is never reported.** Scratch probes put it at **40–65 %** of total error power (RESEARCH 2026-09-??) — report the number or drop the claim |

- 🟥 **Preview arithmetic doesn't close:** 60° → 5° is a 55° correction and 36° → −9° is 45°,
  against a 51.4° lookahead. Restate as measured-correction vs predicted, or recheck.
- 🟥 **Statistical standard is weaker than the rest of the paper.** Fit
  `RMSE ~ mode + (1|session)` and lead with that; keep Friedman as the n=3 caveat.

---

## 7. Rig and protocol constants

| quantity | value | status |
|---|---|---|
| Imaging rate | 35 Hz | ✅ |
| End-to-end loop latency | ≤ 47 ms (200 loop cycles) | ✅ Fig 1F |
| Effective delay with sample-and-hold | 47 + 14 = **61 ms** | ✅ Discussion |
| Implied bandwidth (ω_c τ ≲ 1 rad) | ~2.6 Hz | ✅ Discussion; ⚠ rests on the disputed resonance, §3 |
| Actuator saturation | 36 mW (5 V) | ✅ |
| Command clamp at microcontroller | 2.45 V, **with a downstream amplifier** — does not cap delivered power | ✅ RESEARCH 2026-09-30 |
| Reference level | −5 % ΔF/F | ✅ locked |
| Pixel scale | 0.0173 mm/px on native 560×560 maps | ✅ (the old 0.173 was a 10× bug, fixed 2026-09-30) |
| Gain / phase margin | — | ⬜ **NEEDS RUN** — discretize the fitted plant at 35 Hz, append the 47 ms dead time, close at `tab:gains`. The Methods already asserts the poles are inside the unit circle |
| MATLAB release + toolbox versions | — | 👤 / ⬜ trivial to print |
| Animal details: sex, indicator line, titre, age at first session, housing, light cycle | AL_0033 M / AL_0034 F, both GCaMP8s, 1.6e12 GC in 100 µL PBS | 👤 **for AL_0039, AL_0041, AL_0048, AL_0051.** Note Matveev et al. gives the titre as 1.6e13 in text and 1.6e12 in Table 1 — use the lab's own injection records |
| Second opsin in AL_0048 / AL_0051, and why 638 vs 594 nm | — | 👤 |
| Water restriction — did it apply to all four controller mice | — | 👤 (Matveev restricted 7 of 9, so not universal) |
| Data / code / processed-data URLs | — | 👤 |

---

## 8. Exclusion-rule counts (every `\textbf{n}` in `methods_rewrite.tex:802–816`)

| rule | count | status |
|---|---|---|
| Opsin expression — how confirmed, sessions removed | — | ⬜ / 👤 |
| Trial count ≥ 40 per condition after motion exclusion — sessions removed | — | ⬜ |
| Motion, z > 1.5 — trials removed of total | — | ⬜ |
| Tracking failure (RR only) — 2 sessions: AL_0033 2025-02-12, AL_0051 | **2** | ✅ §5.3 |
| Contralateral predictor R² > 0.3 — sessions removed | — | ⬜ (relates to S1, §5) |
| Behavioural video — sessions and trials used | 7 sessions / 397 CL trials *(as claimed)* | 🟥 see §5.1 — doesn't reconcile to 8 |
| Stimulation quality — AL_0050 | **1 animal** | ✅; 👤 criterion |

⚠ `methods_rewrite.tex` also claims "Results are reported **with and without** this exclusion"
for motion. **No without-exclusion version exists in the Results.** Either produce it or
delete the sentence.

---

## 9. Resolution queue

**⬜ Needs a run (all cheap, all on cached data):**
1. **Print the session list and per-factor n for every Fig 4 panel** — `f4_row2_pool` +
   `f4_row2_fit`, and the generator behind panel C. Resolves S1/S2/S3, the 7-vs-8 motion
   sessions, and 397 / 760 / 1240. *Highest value item in this file.*
2. Generate `tab:gains` for all 15 sessions from each session's `input_params.csv`.
3. Gain and phase margin from the fitted plant + 47 ms delay + the gains.
4. Re-print the three contra-predictor R² values and the two nested nulls.
5. Fig 2G pool size (1767 vs 1516).
6. Fig 2E diagonal vs off-diagonal R² medians.
7. All six exclusion counts in §8.
8. RR on open-loop trials (not a consolidation item — a new control, but same code path).

**🟥 Fix in code, then re-export:**
9. `imp_tf_cv.m` V→mW factor `/3` → `1.8/4.9`; re-export Fig 2C.

**👤 Only Aditya has these:** animal sex / indicator / titre / age / housing, the second
opsin and the 638-vs-594 nm reason, water-restriction coverage, the amplifier gain, the
"poor stimulation" criterion, and the three repository/DOI URLs.

---

*Change log for this file lives in `RESEARCH.md`. When a ⬜ or 🟥 is resolved, update the row
here first, then the manuscript.*
