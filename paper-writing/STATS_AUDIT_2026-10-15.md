# Stats-to-paper audit — 2026-10-15

Read-only check of `Closedloop_edit` (branch `draft`, built files: main.tex abstract, introduction,
results, discussion, methods_rewrite, supplementary) against `paper-writing/STATS_TABLE.csv`
(regenerated 2026-10-15) and saved producer outputs. No manuscript file was edited.

**Bottom line:** Figs 2 and 4 and the supplementary are clean (~65 table-backed numbers match).
Fig 3H/3I text and Methods are stale against the new CL/OL session-level scheme, and the
current text also has three wrong p-values. Four other real issues and several unsourced numbers.

---

## A. Fig 3 — stale against the new scheme (rewrite needed)

New scheme: ratio = CL/OL (<1 = CL better); effect = geometric mean [95% CI], % lower;
PRIMARY = LMM log(r) ~ 1 + (1|mouse), Satterthwaite; also one-sample t (df 14);
Wilcoxon on log r and the trial-level LMM are corroborating. Values: `STATS_TABLE.csv` rows 3H_*, 3I_*.

| Where | Now says | Should say |
|---|---|---|
| results.tex:116 (3H caption) | "Ratio of open-loop to closed-loop tracking RMSE"; "bold black line, mean"; stars from per-trial mixed model | CL/OL RMSE per session, log axis, <1 = CL better; black = geometric mean ± 95% CI; stars = session-level LMM on log ratios, larger p of the two stim windows (***) |
| results.tex:117 (3I caption) | stars from per-trial variance model | same session-level model; **3I shows \*\*** (p = 0.0039), caption must define ** |
| results.tex:133, 136 | CL−OL gaps 0.63 / 0.46 / 0.75 %ΔF/F, trial-level LMM | numbers correct but now corroborating. Primary: RMSE 15.2% lower 0–1 s (0.848 [0.802, 0.897]; t(14) = −6.29, p = 2.0×10⁻⁵), 31.7% lower 1–3 s (0.683 [0.618, 0.755]; t(14) = −8.14, p = 1.1×10⁻⁶) |
| results.tex:137–138 | "open-loop to closed-loop … above one"; "exceeded one in all 15"; medians 1.14 / 1.39 | "closed-loop to open-loop … below one"; "below one in all 15"; geometric means 0.848 / 0.683 |
| results.tex:147 | variance −24% / −41% (trial-level) | 34.8% lower 0–1 s (20.2–46.7%; 0.652 [0.533, 0.798]; t(6.0) = −4.55, p = 0.0039); 45.8% lower 1–3 s (35.8–54.2%; 0.542 [0.458, 0.642]; t(8.0) = −7.80, p = 5.4×10⁻⁵) |
| results.tex:148 | "open-loop/closed-loop … above one"; medians 1.60 / 1.87 | "closed-loop/open-loop … below one"; geometric means 0.652 / 0.542 |
| methods_rewrite.tex:1330–1342 | trial-level LMM is "every OL-vs-CL comparison" | add the primary session-level model; relabel trial-level as corroborating |
| methods_rewrite.tex:1426–1431 | ratios tested by Wilcoxon on log ratio; % reductions from per-trial log variance | primary LMM + one-sample t; Wilcoxon corroborating; % lower = 1 − geometric-mean ratio |
| methods_rewrite.tex:1450–1453 | OL/CL medians 1.14/1.39, 1.60/1.87; V = 120 / 116 | CL/OL medians 0.88/0.72, 0.62/0.54; V = 0, 0, 6, 0 (V = 116 and p = 4.3×10⁻⁴ are the trial-level signed-rank, mislabelled) |
| methods_rewrite.tex:1453–1455 | "between-mouse variance … negligible" | not true for every new ratio model (RMSE 0–3 s mouse SD 0.039 vs resid 0.098); qualify to the stim windows or drop |

## B. Wrong in the CURRENT text (independent of the scheme change)

1. **results.tex:138** — RMSE pre-stim "p = 0.85": that is the variance pre p. RMSE pre Wilcoxon p = 0.095 (LMM p = 0.84). Pre median is 1.02 CL/OL (0.98 OL/CL), not 0.99.
2. **results.tex:148** — variance post "p = 0.76": that is the RMSE post p. Variance post Wilcoxon p = 0.64 (LMM p = 0.48).
3. **results.tex:148 / methods:1451–1453** — variance 0–1 s "p = 4.3×10⁻⁴" is the trial-level signed-rank (3_var_early_sr), not the ratio test (Wilcoxon on log ratio p = 8.5×10⁻⁴).
4. **Trial counts, Fig 2B** — caption results.tex:58 "19–84 trials per amplitude" vs Methods methods_rewrite.tex:725/1176 "at least 44 trials". stim_vars gives 44–85 under the uAmp binning; RESEARCH L51 has 19/26 (mW binning). Pick one binning, fix both; AL_0048 counts unchecked (no stim_vars file).
5. **Discussion vs Results on relative 2–4 Hz** — discussion.tex:18 and :42 build the bandwidth/internal-model argument on relative-δ "degraded closed-loop regulation (p = 0.044)", but results.tex:202 says it does not survive correction and is not built on. Reconcile (absolute 1–4 Hz is the robust effect, but it also raised OL error, p = 6.6×10⁻⁴).
6. **methods_rewrite.tex:1366–1374 (Fig 4G)** — paragraph opens with the nested model `(1|mouse)+(1|mouse:session)` as the test; the primary (and what Results L226 says) is `logRR ~ 1 + (1|sess)`. Lead with the session model.
7. **methods_rewrite.tex:1310–1319** — "the cap can only make a test more conservative": the df = 0 → n−1 fallback (used for 3I variance 0–3 s) is *less* conservative. State the fallback separately.
8. **methods_rewrite.tex:1343–1344** — promises "the effect had the same direction in every mouse"; nothing in the paper reports it. Add or delete.

## C. Decision needed

- **Full 0–3 s window, primary LMM:** Satterthwaite df collapses (RMSE: t = −7.48, df 0.97, p = 0.089; variance: df 0 → fallback df 14, p = 1.3×10⁻⁵) because 2 of 4 mice have one session. The text at results.tex:133 and the abstract (main.tex:87 counts 15/15, 14/15) use the full window. Options: quote the one-sample t (RMSE t(14) = −10.0, p = 9.2×10⁻⁸; variance t(14) = −6.90, p = 7.4×10⁻⁶) with a Methods note, or drop the full window and lead with 0–1 / 1–3 s.
- **3I pre-stim:** LMM t = −0.03 while geometric mean is 1.038 (t-test +0.60) — mouse weighting flips the sign. n.s. either way; avoid quoting the LMM t next to a ratio > 1.

## D. Unsourced numbers (no table row or saved output found)

- Loop delay 47 ms and its derivatives (14 / 61 ms, ~4 / ~2.6 Hz, 200 loop cycles): results.tex:34, 40; discussion.tex:42. PAPER.md L81 flags a 47 vs 80 ms conflict; Methods L326 still has a FILL.
- Fig 2B slopes −0.88/−1.32/−1.53/−3.11 %ΔF/F per mW and R² 0.97/0.73/0.88/0.88 (results.tex:69): printed by f2_slope_ci.m, never saved.
- "0.23–0.87 mW" (results.tex:57): only RESEARCH L51.
- "1670 trials" (results.tex:166, 189; methods:1296): matches G3 n = 1670 but not in the table.
- Leak "6–42%, median 23%" (results.tex:220; methods:1268): only a script comment/print.
- discussion.tex:52 MPC R² 0.42 / 0.10 (saved outputs give 0.443 / 0.0199 at other horizons) and "about 40%" variance cut.
- discussion.tex:24 "44 to 55% of the total error power"; discussion.tex:40 "about 1 mW … seven of the 13 sessions"; discussion.tex:9 "≈0.11 s … three of four sessions" (RESEARCH L510 calls it less robust than it reads).

## E. Cosmetic

- methods:1445 Spearman ρ values mix 2 and 3 decimals.
- Fig 2G: first session has 209 nonzero-amplitude trials, 208 used; not stated.
- discussion.tex:18 gap trend +0.23 is OL−CL (table stores CL−OL, −0.23); consistent with the Methods definition, no change needed.

## F. Matches (no action)

Fig 2G (13), Fig 4D + state table (~40), Fig 4G (12), Fig 4C/S3 unique R², predictor R², RR exclusions,
MPC 1.46 → 0.82 / 108 trials, Fig 2 TF fit numbers, cohort counts (15 sessions / 4 mice / 9 from AL_0033),
abstract and introduction counts.
