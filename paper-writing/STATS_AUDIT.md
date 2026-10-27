# Stats audit — 2026-10-26

Audit only: nothing in code, `STATS_TABLE.csv` or the manuscript was changed. Sources:
`paper-writing/STATS_TABLE.csv` (146 rows, built 2026-10-20), `Closedloop_edit/results.tex`,
`stat_tables.tex`, `methods.tex` (Closedloop 3f75ae2). Purpose: decide, claim by claim,
(1) does this claim need a test at all, and (2) is the test the right one. Consolidation comes next.

Verdict key: **OK** keep as is · **FIX** wrong or inconsistent, must change · **TRIM** redundant, drop or move to robustness · **DESC** should be descriptive (no p).

---

## 0. Headline problems (fix these first)

1. **Fig 3: the "primary" mixed model is unstable, and its p-values depend on a numerical edge case, not on the data.**
   `log r ~ 1 + (1|mouse)` with 4 mice (9 / 4 / 1 / 1 sessions). When REML puts the mouse variance at
   zero, Satterthwaite df = 14 and the model is identical to a one-sample t (p matches `_t` exactly).
   When the mouse variance comes out slightly above zero, df collapses to 0–2.7. Same data, same claim, different window:
   | row | sessions < 1 | LMM df → p | one-sample t (df 14) p | Wilcoxon p |
   |---|---|---|---|---|
   | RMSE 0–3 s | 15/15 | **1.0 → 0.089** | 9.2e-8 | 6.1e-5 |
   | variance 0–3 s | 14/15 | **0 → no test** | 7.4e-6 | 1.2e-4 |
   | CL/best-fixed 1–3 s | 13/15 | **2.6 → 0.22** | 2.4e-4 | — |
   | CL/best-fixed 0–3 s | 13/15 | **1.0 → 0.17** | 0.0010 | — |
   | variance 0–1 s | 14/15 | 6.0 → 0.0039 | 4.5e-4 | 8.5e-4 |
   The manuscript then works around it: the 0–3 s p is footnoted away, and results.tex:146 tells the
   reader the steady-state best-fixed result is p = 0.22 "because the model assigned variation to mice".
   With 2 of 4 mice contributing one session each, the mouse variance can't be estimated, so it is
   not a finding about mice. **FIX.** (A clean session-level test would make every one of these
   clearly significant, so this is the single biggest gain.)

2. **Fig 3 CIs don't match the p-values.** Methods:607 says CIs are t-based on the same df as the test.
   The table CIs are clearly df-14 intervals (0–3 s RMSE `[0.73, 0.81]`; with df = 1 the interval would
   cover 1). So rows show a CI that excludes 1 next to p = 0.089 / 0.22 / 0.17. This is the same class of
   mismatch the blind review flagged for Table 4 on 2026-10-20. **FIX** (goes away once #1 is fixed).

3. **Mouse is handled in opposite ways in Fig 3 and Fig 4G.** Fig 3 makes the mouse model primary;
   Fig 4G makes the session-only model primary (`logRR ~ 1 + (1|sess)`, df 9.3) and lists the mouse-nested
   model (df 1.2, p = 0.049) as secondary. A reviewer will ask why the rule flips. **FIX**: one rule for the
   whole paper.

4. **A p-value in the text that isn't in the table.** results.tex:147, "Spearman ρ = 0.66, p = 0.009"
   (closed-loop command vs best fixed input, Fig S-best_fixed D) is computed in
   `controller-analysis/ctrl_best_fixed_ol.m` but has no `STATS_TABLE` row. That breaks the NUMBERS.md rule
   (the paper quotes the table). **FIX**: add the row.

---

## 1. Figure 2G — impulse variability vs pre-stimulus state (4 sessions, 3 mice)

| claim | current test | needs a test? | verdict |
|---|---|---|---|
| Q4/Q1 variability ratio per state (`2G_*_ratio`) | geometric mean + per-session range | No: the panel and text are explicitly descriptive | **OK / DESC** |
| Per-session slope of variability on state (`2G_*_slope`) | one-sample t on 4 slopes, df 3 | Caption says "supporting, not used for inference" | **OK**, but see note a |
| Pooled Spearman ρ (`2G_*_rho`, `_ctrl`) | none (pseudo-replication noted) | No | **OK / DESC** |
| Response vs stimulus-free ratio (`_stimctrl`, `_ctrlratio`, `_ctl_resp_spread`) | descriptive | No | **OK** |
| Response/control, Q4 vs mean Q1–3 (`_beyondctrl`) | one-sample t, df 3 | Supporting only (table footnote) | **OK**, note a |
| Q4 vs mean Q1–3, response alone (`2G_*_q4`) | one-sample t, df 3 | Not quoted anywhere (no tex table, no text) | **TRIM** (orphan row) |

Notes
- a. With n = 4 a Wilcoxon can't do better than p = 0.125 (two-sided), so a t-test is the only option that
  can reach significance. That's fine as long as it stays "supporting". But AL_0041 contributes 2 of the 4
  sessions, so df 3 slightly overstates independence. Say so once in Methods, or average AL_0041's two sessions
  as a sensitivity check. Two supporting tests (slope and q4) for one descriptive claim is one too many; keep the slope.
- 3 states × 2 supporting tests, no correction. Acceptable because nothing is inferred from them; keep the caption
  wording that says so.

## 2. Figure 3 — CL vs OL tracking RMSE and across-trial variance (15 sessions, 4 mice)

| claim | current primary | needs a test? | verdict |
|---|---|---|---|
| CL/OL RMSE ratio, 0–1 s and 1–3 s | LMM `log r ~ 1+(1|mouse)` (happens to have df 14, so = t-test) | **Yes**, a core claim | **FIX** test choice (headline #1); the numbers stand |
| CL/OL RMSE ratio, 0–3 s | same LMM, df 1, p = 0.089 | Overlaps 0–1 + 1–3 | **TRIM**: report the ratio descriptively (text already does), drop its test |
| CL/OL variance ratio, 0–1 s / 1–3 s | same LMM, df 6 / 8 | **Yes**, a core claim | **FIX** test choice |
| CL/OL variance ratio, 0–3 s | df 0, no test | Overlaps | **TRIM** as above (also drop the `_lmmfb` fallback row) |
| Pre / post windows "stayed at one" | same LMM, p = 0.84 / 1.0 / 0.98 / 0.48 | These are **null controls**: a large p does not show "no change" | **DESC**: report the ratio with its 95% CI (CI shows the change is small, e.g. RMSE post [0.97, 1.03]); no p needed |
| CL/best-fixed RMSE, 0–1 s, 1–3 s, 0–3 s | same LMM, df 14 / 2.6 / 1.0 | 0–1 and 1–3 yes (answers reviewer M1); 0–3 overlaps | **FIX** 0–1/1–3; **TRIM** 0–3 |
| Command ratio vs best fixed, Spearman ρ | not in table | Yes, quoted in text | **FIX**: add the row (headline #4) |
| `3_*_lmm` trial-level LMM `y ~ cond + (1+cond|sess) + (1|mouse)`, `3_*_sr` per-session Wilcoxon (12 rows, "CORROBORATING") | not quoted anywhere | Same claims as 3H/3I in different units | **TRIM**: keep at most one as the robustness column |

Recommended direction for the consolidation step (to decide together, not done):
the unit is the session; primary = one-sample t on per-session log ratios (df 14) with the
exact Wilcoxon signed-rank as the robustness column; mouse handled by a stated sensitivity check
(e.g. mouse-averaged ratios, or leave-one-mouse-out), not by a random effect it can't estimate. That
keeps every number the text quotes for 0–1 s and 1–3 s RMSE (already df 14) and makes the
variance and best-fixed rows consistent with them.

## 3. Figure 4D — state dependence of OL/CL steady-state RMSE

Model: trial-level LMM `y ~ cond*state + (1+cond|sess) + (state-1|sess) + (1|mouse)`, df capped at
sessions−1. That is a sound design for "does the slope differ from 0 / between conditions": slopes vary by
session and inference is at the session level. **OK** in principle.

| quantity | needs a test? | verdict |
|---|---|---|
| Gap at mean state (×4 states) | Restates the Fig 3 claim four times | **TRIM**: report the estimate and CI; one p (or none, pointing to Fig 3) |
| Predictability (OL slope), Regularizability (CL slope) | Yes | **OK**: Bonferroni over 8 is stated, and the text only interprets the bold ones |
| Attenuation (slope of log CL/OL) | Yes, this is the interpreted interaction | **OK**: Bonferroni over 4 |
| Gap trend (cond × state, linear) | Same interaction as attenuation on a different scale; caption says "not interpreted" | **TRIM**: two tests of one effect invite cherry-picking (rel δ: att p = 0.027 vs trend p = 0.081). Drop it, or move it to the supplement as the linear-scale check |
| Motion: Wilcoxon on within-session OL, CL, OL−CL slopes (`4_motslope_*`) | Same three quantities as motion predictability / regularizability / gap trend, different test (OL p 0.0020 vs 0.013) | **TRIM** to one row: keep only the "11/11 sessions OL slope > CL slope" count, which the text quotes, as a sign-count statement. Two tests of the same slope with different p-values is the inconsistency a reviewer looks for |

Notes
- Motion has n = 11 sessions vs 15 for the others; the table already says so. OK.
- The paper's correction scheme is Bonferroni within quantity family. State that the family is
  "per quantity across the 4 states" in Methods (the caption has it; check Methods says the same).

## 4. Figure 4G — disturbance rejection (11 sessions, 3 mice)

| claim | current | needs a test? | verdict |
|---|---|---|---|
| RR < 1 in CL | session LMM (primary), mouse-nested LMM, Wilcoxon on session medians, all one-sided | Yes | **FIX** to the paper-wide rule (headline #3). Three tests of one claim → one primary + one robustness |
| OL vs CL: RR, offset share, fluctuation energy | Wilcoxon, one-sided OL > CL | Yes, but one-sided needs a stated a-priori reason | **OK** if Methods gives the reason (feedback can only be argued to lower residual). Otherwise go two-sided: p doubles (4.9e-4 → 9.8e-4 etc.), and nothing changes in substance |
| 2 sessions excluded (offset > 1/3) | rule stated | — | **OK**, but report RR with all 13 included as a sensitivity line (reviewer bait otherwise) |

## 5. Figure 6 / sine — MPC and preview (simulation + single session)

All rows are medians, ratios and trial counts ("MPC lower on 107/108 trials"), with no p-values.
**OK / DESC.** These are model counterfactuals on the same trials (the trials aren't independent
samples of an effect), and the sine data come from one mouse, so a p-value would mean little. Keep
descriptive; the "k/N trials lower" counts are the right summary.

---

## Summary counts

| verdict | rows (approx.) |
|---|---|
| OK / DESC as is | ~85 (all Fig 6, most of 2G, 4D slopes and attenuation) |
| FIX (test choice / mismatch / missing row) | ~20 (3H/3I primary, CIs, 4G primary, Spearman row) |
| TRIM (redundant or orphan) | ~35 (`3_*` corroborating, 0–3 s tests, gap ×4, gap trend, `4_motslope_*`, `2G_*_q4`, `_lmmfb`) |
| Change to descriptive | 8 (Fig 3 pre/post p-values → CI) |

## Decisions needed before consolidation
1. Paper-wide unit-of-inference rule: session-level t + Wilcoxon robustness + mouse sensitivity (recommended),
   or keep a mouse random effect everywhere (then Fig 4G must switch and Fig 3 keeps its collapsing df).
2. One-sided tests in Fig 4G: keep with a stated reason, or go two-sided.
3. Pre/post null windows: CI only (recommended) or keep the p-values.
4. Gap trend and the motion Wilcoxon rows: drop, or move to the supplement.
