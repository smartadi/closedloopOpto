# NUMBERS.md — canonical number registry for the manuscript

Single source of truth for every *n*, count, and headline statistic that appears in
`Closedloop_edit/{results,discussion,methods_rewrite}.tex`. Built 2026-10-01 during the
number-consolidation pass.

**Rule:** the manuscript quotes this file; this file quotes code or a verified run. If a
number is not here, it does not go in the paper.

**2026-10-07: every STATISTICAL TEST now lives in `paper-writing/STATS_TABLE.csv`** (built by `paper-writing/paper_stats_table.m` from the saved producer outputs; df capped at nSessions-1). Where a p-value, CI or df below disagrees with that CSV, the CSV wins - the tables here predate the df fix (Fig 4D, Fig 4G and Fig 2G p-values all moved; Fig 4G pool is now 12 sessions / 640 trials / 4 mice).

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
| Mouse 1a | AL_0041 e1 | −0.30 | 0.97 | 208 |
| Mouse 1b | AL_0041 e2 | −0.50 | 0.51 | 260 |
| Mouse 2 | AL_0033 2025-01-29 e1 | −0.52 | 0.92 | 748 |
| Mouse 3 | AL_0048 (right hemisphere) | −0.81 | 0.92 | 300 |

⚠ **Slopes changed 2026-10-03** when the evoked-suppression window was corrected from
29–200 ms (7 samples, onset excluded) to a true **0–200 ms (8 samples, onset included)**,
on the user's instruction. Previous values were −0.34 / −0.57 / −0.59 / −0.96 with
R² 0.97 / 0.51 / 0.92 / 0.91. For AL_0041 and AL_0033 the change is an exact ×7/8 rescale
(the onset sample is identically zero there, so R² is unchanged); AL_0048 moved by ×0.846
and its R² by +0.006, because it comes through `load_bilateral_impulse.m` where the onset
sample is not identically zero.

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
| Cross-session model swap (2E) | **self R² = 0.991, cross-session 0.714** (drop 0.277) | ✅ resolved 2026-10-03 from `imp_tf_run`; now quoted in `results.tex` as 0.99 vs 0.71 |
| Tau forest (2F) — slow τ | **0.176 / 0.540 / 0.333 / 0.302 s**; mean 0.338, between-SD 0.151, within-SD 0.097, ratio 1.55 | ✅ measured 2026-10-03. 🟥 Results says "~0.2–0.3 s" — WRONG, range is 0.18–0.54 s. Tabled by user |
| Tau forest (2F) — fast τ | **0.148 / 0.093 / 0.150 / 0.143 s** | ✅ supports the "~0.14 s in three of four" claim |
| Tau forest (2F) — bootstrap discard | **42% / 50% / 2% / 50%** beyond the 0.51 s fit window | ✅ measured 2026-10-03; CIs are right-censored, not usable intervals |
| Model order across sessions | np = [3 4 4 4], modes [2 2 2 3] | ✅ NOT shared — do not write "the same model", write the range |

### Fig 2G — state dependence (quartile ratios, top vs bottom)
Re-verified 2026-10-03 live from `STV.R` after the evoked window became a true 0–200 ms
(`imp_state_trialvar.m` → `imp_state_trialvar_fig.m`). Values below are ✅ the generator's.

| state | ratio | CI95 | ρ (p) | LME p | sessions | control ratio (ρ, p) |
|---|---|---|---|---|---|---|
| motion | 0.729 | [0.618, 0.876] | −0.1228 (2.3e−7) | 7.31e−7 | 4/4 | 0.795 (ρ=−0.049, p=0.041) |
| relative 2–4 Hz | 1.022 | [0.878, 1.191] | +0.0933 (8.6e−5) | 0.00518 | **3/4** | 0.998 (ρ=+0.008, p=0.74) |
| absolute 2–4 Hz | 2.092 | [1.762, 2.572] | +0.4161 (<1e−16) | <1e−16 | 4/4 | 2.245 (ρ=+0.377) |

Paper (`results.tex`, updated to match 2026-10-03): 0.73 / 1.02 / 2.09, controls 0.80 / 1.00 / 2.25.
The window change moved only last digits — no claim, star or session count moves. The superseded
2026-09 table read 0.71 [0.60,0.84] / 1.10 [0.94,1.27] / 1.99 [1.69,2.37], controls 0.79 / 1.00 / 2.10;
that set predates both the pseudoreplication fix and the window fix — do not quote it.

- 🟥 **Pool size 1767 trials** — see §1.2.
- 🟥 The dissenting rel-δ session is **AL_0048** (within-session ρ = **−0.060**, n = 300) vs
  +0.116 / +0.195 / +0.110 for the others; stratified ρ = +0.0947. **Not named in the paper.**
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

### 5.1 Panels B/C — error decomposition — 🟥 **CANNOT BE REGENERATED** (run 2026-10-01)

**The paper's numbers are 397 CL trials / 7 sessions** with unique R² (early → settled):
init-dev 0.29→0.004, motion <0.01, rel 2–4 Hz 0.10→0.12, abs δ 0.23→0.35.

**None of that reproduces, because the generator cannot run.** Verified by running the gate
logic over all 15 caches (`scratchpad/fig4_n_audit.m`):

- `controller-analysis/f4_error_decomp.m:55` indexes **`dk.pwcDfk_l`** with no fallback.
- **No cache has `pwcDfk_l`.** All 15 have `pwcDfk` instead.
- `utils/controllerData.m` **no longer produces the `_l` buffers at all** — it writes only
  `data.pncDfk` / `data.pwcDfk` (lines 161–162). So the field is not merely missing from
  caches; it cannot be rebuilt by the current pipeline.
- ⇒ **`f4_error_decomp.m` admits 0 of 15 sessions as it stands.**
- ⚠ `utils/cl_reldelta.m`'s docstring still says "`d.pwcDfk_l` … Both are present for all 15
  controller sessions". That is false and should be corrected.

**The fallback is exact.** From git history (`8673398:plottingScript.m:177`) the legacy buffer was
`dFk(i-35*3 : i+35*(dur+3))` — 105 pre-samples, onset at col 106; the current one is
`dFk(i-350 : i+35*(dur+3))` — 350 pre-samples, onset at col 351. **Same `dFk`, same onset
alignment, same rate**; only the pre-buffer length differs. Columns 36–211 of the legacy buffer
and 281–456 of the current one are therefore *the identical samples* of `dFk`
(−2 s → +3 s). `f4_row2_pool.m` and `f4_partB_panels.m` already use this fallback;
`f4_error_decomp.m` is the one that never got it.

**Reconstruction on the defined cohort** (`scratchpad/panelC_repro.m` — f4_error_decomp's math
and its verbatim `local_bandpow`, with the fallback applied), pool = **613 CL trials / 11 motion
sessions** {m2,m4,m5,m6,m9,m10,m11,m12,m13,m14,m15}:

| factor | early 0–1 s | settled 1–3 s | paper claims |
|---|---|---|---|
| initial deviation | **0.279** | **0.005** | 0.29 → 0.004 ✅ reproduces |
| motion | **0.000** | **0.000** | <0.01 ✅ reproduces |
| relative 2–4 Hz | **0.011** | **0.012** | 0.10 → 0.12 ❌ **~10× lower** |
| absolute δ | **0.142** | **0.219** | 0.23 → 0.35 ❌ lower |
| full model R² | 0.549 | 0.352 | 0.41 / 0.13 (older 613/11 run) ❌ |

Checked and excluded as causes: the bandpower implementation (swapping in the script's exact
`local_bandpow` moved rel from 0.010→0.011 — no effect) and the spectral window (shown
identical above).

🟥 **Leading hypothesis — needs the user's judgement.** With `has_motion` as the only
session gate, the script admits **11** sessions, not 7. The published "7 sessions" is most likely
**an artifact of which caches still carried `pwcDfk_l` at the time of that run**, not a defined
criterion — which would mean the Fig 4C pool was never a stated inclusion rule. The two factors
that reproduce (init-dev, motion) are the strong and the null one; the two that do not are the
two δ measures, consistent with dilution by the 4 extra sessions (m2, m13, and the two new-rig
mice m14/m15, which are on record as diluting the headline).

⚠ **If the reconstruction stands, the Fig 4 story changes.** The paper says "relative and
absolute 2–4 Hz power carry the settled window (0.10→0.12 and 0.23→0.35)". On the defined
11-session cohort, **absolute δ (0.219) outweighs relative δ (0.012) by ~18×** — and absolute
δ is the power-confounded measure the paper explicitly declines to interpret. The claim that the
irreducible settled error is carried by a *power-independent* state would not survive as written.

⚠ **Two different "motion" states inside one figure.** `f4_row2_pool.m` uses the **plain mean**
z-motion over −2→+3 s (user decision 2026-09-11, "NO rectification"); `f4_error_decomp.m` uses
the **mean of squared** motion over the same window. Panels C and D therefore regress on different
state variables under the same label. Pick one.

⚠ The older `cl_rmse_factor_windows.m` / `f4_partB_panels.m` three-factor run reported
613 CL trials / 11 sessions with init-dev 0.381→0.029, rel 0.089→0.122, full R² 0.407/0.132.
Same pool as my reconstruction, different values — so that path and `f4_error_decomp.m` do not
agree with each other either. Do not quote 613/11 numbers from it without re-deriving them.

✅ **RESOLVED 2026-10-02** (Python port, `bpy/analysis/f4_pool.py`; RESEARCH 2026-10-02). Two of
the three gaps were bookkeeping in the decomposition, not data:

1. **"Full model R²" is the REL model**, init-dev + motion + rel 2–4 Hz — not a four-predictor
   fit. On the 613/11 pool it is **0.414 / 0.141** against the paper's 0.407 / 0.132. The
   four-predictor fit (0.594 / 0.448) is identical to the *abs* model to three decimals: once
   absolute δ is in, rel adds nothing.
2. **init-dev was credited after rel.** Taking init's share from the rel model removes rel from
   init while still removing init from rel. Credited hierarchically (base pair against each
   other, then each δ over the base) it is **0.318 / 0.003** against the paper's 0.290 / 0.004.

That leaves **only absolute δ**, which reaches 0.240 / 0.383 (vs 0.230 / 0.350) on the **2–4 Hz**
band this file documents, while `f4_error_decomp.m` codes **1–4 Hz** — an open question for the
user, not a reproduction failure.

The **"397 CL trials / 7 sessions"** is **not** a subset of today's 613/11 pool: only two
7-session subsets sum to 397 and both require m14/m15, which did not exist when the panel was
made. It is an older pool, so the "7 sessions" was never an inclusion rule — the hypothesis
above stands.

When `f4_error_decomp.m` is re-run it needs both corrections (plus the line-55 fallback).

### 5.2 Panel D — state quartiles + session-aware LMM — ✅ **RESOLVED** (run 2026-10-01)

Ran the production `utils/f4_row2_pool.m` over all 15 caches (`scratchpad/fig4_n_audit.m`).
This **exactly reproduces the 2026-09-16 audit**, so these are the numbers:

| factor | all trials | CL trials | sessions | mice | session list |
|---|---|---|---|---|---|
| initial deviation | **1670** | 852 | **15** | 4 | m1–m15 |
| motion | **1190** | **613** | **11** | 4 | m2,m4,m5,m6,m9,m10,m11,m12,m13,m14,m15 |
| relative 2–4 Hz | **1670** | 852 | **15** | 4 | m1–m15 |
| absolute 2–4 Hz | **1670** | 852 | **15** | 4 | m1–m15 |

🟥 **The Fig 4 caption is wrong on all four of its numbers.** It says "11 sessions
(1240 trials; motion 7 sessions, 760 trials)". Correct: **15 sessions / 1670 trials** for
initial deviation, relative δ and absolute δ; **11 sessions / 1190 trials** for motion.
There is no 1240 and no 760 anywhere in the pool.

✅ Where "613" came from: it is the **CL-only** trial count of the 11 motion sessions.
✅ 1670 = every OL+CL trial across the 15 sessions — i.e. **this pool applies no trial-level
exclusion at all.** ⚠ That contradicts the Methods, which states trials with z-motion > 1.5
were excluded. Either the exclusion is not applied here, or the Methods overstates it.

✅ Per-session OL/CL splits (needed for the Methods, and not previously written down):
m1 56/64, m2 97/103, m3 101/99, m4 92/108, m5 36/24, m6 14/16, m7 46/54, m8 38/22,
m9 50/50, m10 48/52, m11 50/50, m12 35/65, m13 55/45, m14 45/55, m15 55/45.
Totals **758 OL / 852 CL = 1610**… plus the 60 trials of m1/m3/m7/m8 that carry no motion,
summing to the declared 1670. Every session's OL+CL equals its declared trial count.

✅ Motion trace confirmed present in **11 of 15**; absent (identically zero) in **m1, m3, m7, m8**,
all AL_0033 — independently reproducing the 2026-09-15 `h5read` audit.

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
6. ✅ DONE 2026-10-03 — Fig 2E self 0.991 vs cross 0.714.
7. All six exclusion counts in §8.
8. RR on open-loop trials (not a consolidation item — a new control, but same code path).

**🟥 Fix in code, then re-export:**
9. ✅ **FIXED 2026-10-03** — `imp_tf_cv.m:287` now uses `vToMW = 1.8/4.9` (was `/3`, labels ~9.4% low).
   ⚠ **Fig 2C NOT yet re-exported** — `imp_tf_cv.m` is a separate script and was not run; the locked
   panel still carries the old labels. Run with `PAPER_FINAL` on, then re-place 2C in Illustrator.
   No text change needed: nothing in Results or Methods quotes these mW values.

**👤 Only Aditya has these:** animal sex / indicator / titre / age / housing, the second
opsin and the 638-vs-594 nm reason, water-restriction coverage, the amplifier gain, the
"poor stimulation" criterion, and the three repository/DOI URLs.

---

*Change log for this file lives in `RESEARCH.md`. When a ⬜ or 🟥 is resolved, update the row
here first, then the manuscript.*
