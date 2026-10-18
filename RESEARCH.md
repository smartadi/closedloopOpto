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

### 2026-10-18 — Introduction rewrite and JN compliance audit started, then paused at the user's request
**Changed/Found:** Two workflows were started and then stopped before producing output.
- The JN compliance audit (six auditors plus verifiers) was stopped because the user wants it after their own Discussion pass.
- The Introduction rewrite (brief: scratchpad `intro_brief.md`, 650 words including citations, set up Discussion claims C1–C4) was stopped when the user said "wait".
Both can resume from cache in this session.
**Why:** The user's priority is internal review and arXiv readiness: their Discussion pass first, then an Intro attempt, then reviewer passes, and JN formatting last.
**Next:** Resume the Intro rewrite on the user's go. Run the compliance audit after the user's Discussion pass.

### 2026-10-18 — Found: JN word caps confirmed; Introduction over its cap, Abstract lacks sex, figures pair red with green
**Changed/Found:** The official JN Information for Authors (pasted by the user) confirms these caps: Discussion 1,500 words including citations; Introduction 650 including citations; Abstract 250 including citations; Significance Statement 120.
- `introduction.tex` measures ~713 words with citations, over the cap.
- The Abstract is 222 words but does not state the sex of the subjects. JN requires it in the Abstract, though only at revision.
- The Significance Statement is 112 words.
- JN asks authors to convert red/green to magenta/green for colour-blind readers. The locked condition colours pair OL red with CL+p green.
**Why:** The user asked for the Discussion to meet the JN rules, which meant checking the current guidelines.
**Next:** Intro rewrite to ≤650 words (paused). Decide on the colour scheme and the sex statement when JN formatting starts.

### 2026-10-18 — JN Discussion at 1,496 words (incl. citations): `discussion_jn1500.tex`
**Changed/Found:** `paper-writing/discussion_2026-10-18/discussion_jn1500.tex` plus `DISCUSSION_JN1500_NOTES.md` (change log and 11 author items). It was rewritten to the user's rulebook by a workflow:
1. two planners and a merge;
2. three drafts;
3. two judges and a synthesis;
4. four checkers (facts, citations, causal language, structure);
5. a revision and a final section-6 check, which passed.

Structure: a cortical-function opening, then four claims (C1 linear-on-average and the control argument; C2 contralateral cancellation; C3 reachable vs unreachable variability; C4 observable but not forecastable, preview, MPC), then one limitations paragraph, implications and a closing sentence.

My post-workflow fixes:
- removed a dangling "small gain" referent;
- corrected the Sanzeni connective;
- removed a hedge stack;
- added a preview sentence to mirror the Abstract;
- removed an unverified Valley clause;
- fixed a missing space.

A scratch build compiles with no undefined references or citations (41 pp). Word count by scratchpad `dwc.py`: prose plus rendered author-year citations.
**Why:** The user's J Neurosci rulebook and the 1,500-word cap including citations. Draft 2 was ~3,100 words.
**Next:** The user's pass on the Discussion and the 11 author items in the NOTES file. Then write into Closedloop_edit (draft branch) with the Methods remark and new_refs.bib, and align Results L230 and Methods L901–902.

### 2026-10-18 — Discussion draft: ~2,900 words, not cut to the 2,500 target
**Changed/Found:** `paper-writing/discussion_2026-10-18/discussion_draft.tex`. After the verification fixes the draft came to 3,500 words, and it was trimmed to 2,895 (texcount). Dropped for length: Jazayeri & Afraz, Das & Fiete, Harris 1989, Garone 2017 (reference governors), the "jazayeri natural range" clause and the repeated Li 2019 rebound citation. An optional cut list of about 400 words is in OUTLINE.md.
**Why:** Cutting further would remove the caveats the verifiers required (theorem scope, "consistent with" for reachability, the crossover hedge) or remove the user's themes. Better to let the user choose the cuts.
**Next:** The user picks cuts from the OUTLINE.md list or accepts about 2,900 words.

### 2026-10-18 — Verifier found errors in the draft and two matching spots in the manuscript
**Changed/Found:** A second verification pass (facts, control theory, every citation; `paper-writing/discussion_2026-10-18/VERIFY_REPORT.txt`) found these problems.
- **Facts:**
  - The standing offset was described as cancelled contralateral drive; Results L230 attributes it to feedforward calibration.
  - Offset was called the largest error term in Fig 4; it is the largest only in Fig 5.
  - Attenuation was called the ratio of slopes; it is the slope of the CL/OL ratio against state.
  - Fig 2E was cited for between-session gain; the right panel is Fig 2B.
  - The text implied admissible gains were computed; Kp and Ki were hand-tuned.
- **Control theory:**
  - Morari's SISO condition is G(0) ≠ 0, with the sign fixing the controller's sign.
  - Brammer covers one-signed inputs only for plants with a real mode.
  - Desoer–Lin (PI, no saturation) was blended with Logemann–Curtain (I-only, linear plant, saturation and delay). No single theorem covers PI, saturation, delay and sampling.
  - The 2.6–4 Hz figure is a delay cap, not the crossover of the loop that ran; the plant lag of 60° at 1 Hz puts crossover lower.
  - Thm 4.1 gives e ∈ L² only; e(t) → 0 needs part (f).
  - The impulse fits do not fix the sign of G(0), because the slow mode is unresolved; the open-loop constant-command trials (Fig 3B) do.
- **In the manuscript:** Results L230 ("the integral term removes that offset") and Methods L901–902 ("empirical counterpart of the sensitivity function") carry the same overclaims.
- **Possible issue:** M = 105 samples (3 s), but sine trials last 4 s. If M was unchanged there, the boxcar is not an integrator in the last second.
- **Unsourced:** "7 of 13 sessions at the ceiling" comes only from the old Discussion.
**Why:** The user asked for a thorough, accurate Discussion and wants no wrong claims in the paper.
**Next:** The user decides on: matching fixes to Results L230 and Methods L901–902; a Methods line for the 7/13 ceiling count; the M value in the sine sessions.

### 2026-10-18 — Methods remark: low-gain integral tracking through a monotone actuator
**Changed/Found:** New `paper-writing/discussion_2026-10-18/methods_remark.tex` (Remark `rem:lowgain`, for methods_rewrite.tex after L323). Content:
- Logemann & Curtain 2000 Thm 4.1, with parts (a),(c),(d),(f) and Rem 4.2(b) named.
- φ absorbs ū, the ±q integral clamp, the [0, u_max] clipping and the command→drive map. e = y − y_ref (Eq. error).
- (iv) includes the clamp-limited range and any standing offset.
- Quantization is noted. Logemann 1999 gives the gain bound; Fliegner 2001 covers discrete time; Desoer & Lin is scoped.
- The follow-up paragraph says (ii) rests on Fig 3B, not the impulse fits, and lists four departures from the remark (P term, 3 s boxcar, 35 Hz, trial length).
- Scratch build: compiles, and the label resolves as Remark 1.
**Why:** The user chose "Discussion + Methods remark" so the stability argument is stated formally and with its limits.
**Next:** Insert into methods_rewrite.tex once the user approves the Discussion.

### 2026-10-18 — Discussion rewrite around the five themes, draft 2 (not yet in manuscript)
**Changed/Found:** `paper-writing/discussion_2026-10-18/` now holds:
- `discussion_draft.tex`, which replaces `discussion.tex`. Sections:
  1. monotone average → stabilizing design;
  2. linear on average / variable per trial, with the pointed critique of LFADS, CURBD, Lu 2025 and ZAPBench, and "observable but not forecastable" from contralateral R² 0.76 vs VARX 0.41/0.37;
  3. feedback partly cancels shared contralateral activity;
  4. reachability and predictability (the Fig 4D slopes in sensitivity-function terms; the delay cap vs actual crossover);
  5. prediction / MPC;
  6. Limitations.
- `OUTLINE.md`.
- `new_refs.bib`: 32 verified new keys.
- `VERIFY_REPORT.txt`.

New evidence used for the state theme: Results L97 shows that, relative to the stimulus-free window, response variability barely changes across quartiles (0.98/0.95/0.87). A scratch build (main.tex + draft + remark + bib) gives 0 undefined refs or citations, 43 pp.
**Why:** The user asked for the Discussion to be restructured around their five themes, with a thorough literature review ("we draft then write").
**Next:** User review. On approval: write into Closedloop_edit/discussion.tex, insert the remark, append to refs.bib, build, commit on draft, and push only on the user's go.

### 2026-10-16 — Reference audit: all 47 cited entries checked against Crossref/arXiv
**Changed/Found:** `Closedloop_edit/refs.bib` (main 907251a). Each cited entry was checked against Crossref (by DOI where present, by title otherwise) and arXiv: title, authors, journal, year, volume and pages. No wrong title or author list was found. Fixes:
- Gupta & Murphy: year 2025 → 2026 (version of record 2026-09-24, eLife 14) plus article RP105070.
- eLife/Science article numbers added: Shimaoka e43533, Siegle e03061, Zatka-Haas e63163, Ye eadx1369.
- Cell Press page suffixes: Allen 891–907.e6, Makino 880–890.e8.
- Åström & Hägglund title → "PID Controllers: Theory, Design, and Tuning", second edition.
- van Overschee title dashes → commas.
- Ritt & Ching "page" → "pages".
- Every Unicode en dash in a pages field → `--` (25 entries).

Verified but left as is: Nozari 2024 and Zaaimi 2023 (issue years; online 2023/2022); Bolus 2021 (journal version; the bioRxiv was 2020); Matveev 2024 (still a bioRxiv preprint per Crossref); Lu 2025 arXiv 2510.18037 (authors match); van Overschee 2012 Springer (a valid reprint of the 1996 Kluwer edition). Build: 39 pp, 0 bibtex warnings.
**Why:** User 2026-10-16: nothing in the references may be wrong (title, authors, journal, year).
**Next:** Recheck Matveev 2024 for a journal version before submission. Uncited entries in refs.bib were not audited.

### 2026-10-16 — Review fixes in the manuscript; Discussion reminder placed
**Changed/Found:** `Closedloop_edit` (main fb4e309):
- `results.tex`: L179 garbled sentence fixed; "independent of overall power" → "normalized for overall power"; Fig 2A caption 0.23–0.87 → 0.23–0.90 mW (matches the panel legend); 2G caption "open circles" → "open diamonds".
- `stat_tables.tex`: Table 2 caption drops "converted at 1 mW per 3 V".
- `methods_rewrite.tex`: the nominal-model paragraph now ends at "are the trial-averaged dynamics."
- `discussion.tex`: visible `\aditya{REMINDER ...}` after the old Fig 2G sentence.

Left as is (user): the [repository URL] placeholder, the mixed m-number / letter session naming, and the 40 Hz-sine sessions line.
**Why:** User's answers to the full-paper review, 2026-10-16. Do not raise the laser power-ceiling / V→mW arithmetic again (a level shifter; see memory).
**Next:** User rewrites the Discussion and deletes the reminder. The 2G panel title still says "State dependence of stimulation response" (Illustrator).

### 2026-10-16 — Fig 6H: AR dropped, site + laser added (same set as Fig S5E)
**Changed/Found:**
- **Panel.** `ctrl_mpc_direct_panels.m` panel B (paper 6H) now draws VARX / site + laser (black) / naive, all from `mpc_varx_supp_<sess>.mat`; the embed-file AR + persistence are gone. Re-exported with PAPER_FINAL → `panels/supp_mpc/mpcd_B_prediction.pdf`.
- **Draft text.**
  - Results: the VARX beats naive and "the same model given only the controlled site and the laser", plus a pointer to Fig S5.
  - Caption H: lists site + laser.
  - Discussion: R² 0.41 vs 0.37 (no cortex) vs 0.10 (naive). The Lu et al. citation is kept as context: univariate models cannot use the stimulation command.
- Clean build; draft committed.

**Why:** the user confirmed AR is a univariate model of y alone with no input; on stimulated test trials it cannot see the laser, so it's an unfair baseline. VARX − site+laser isolates what the cortical sites add.
**Next:** the user swaps the new H panel into `FigureMPC.pdf`; then recopy it to `images/Figure6.pdf`, rebuild, and fast-forward + push main. DONE: the user swapped H (FigureMPC.pdf 19:33). It was copied to `images/Figure6.pdf`; clean build (39 pp, 0 errors, 0 undefined); main fast-forwarded and pushed (1a252bb..80cf840, incl. the text commit 23423b6). Overleaf pull is the last step.

### 2026-10-16 — Fig 6 re-copied from the user's repaired FigureMPC.pdf; caption/refs follow its lettering
**Changed/Found:**
- **Figure.** Closedloop_edit `images/Figure6.pdf` ← `paper/figures_final/FigureMPC.pdf` (the user's 19:19 text repair). The paper's previous copy dated from 14:37, so the main push at ef60279 carried an outdated Fig 6.
- **Assembly letters differ from the old caption:** G = smoothness λ, H = prediction R² (swapped), and the sine row is now I example, J per-trial RMSE, K RMSE over time, L variance, M phase lag.
- **Caption rewritten** for A–M.
- **Results references:** prediction G→H, smoothness H→G, sine RMSE I,L→I–K, lag K→M, variance J→L.
- **Discussion:** the reference G→H, and R² 0.42→0.41 (matches the Fig S5 / Fig 6H value 0.408).
- Clean build (39 pp); draft committed; main fast-forwarded and pushed (ef60279..1a252bb).

**Why:** the user repaired text issues in the assembled figure and asked to move it into the paper and push main.
**Next:** Overleaf pull. The Discussion's AR value (0.02 at 200 ms) was not re-checked against the current embed data.

### 2026-10-16 — Sine MPC Results: "two thirds" of the error in rising half-cycles → "about half"
**Changed/Found:** Closedloop_edit `results.tex` (sine MPC paragraph) — "Most of the remaining error (about two thirds of the squared error) fell in…" → "About half of the remaining squared error fell in…". Recomputed on the canonical `_noCL` data (CL+p trials, dR>0 split): MPC 0.49, perfect 0.49; the laser is off 83% of the rising half. Draft commit after a clean build.
**Why:** the user asked; the ⅔ figure did not reproduce under either the old or the new data.
**Next:** none. Update: on the user's go, Closedloop_edit main was fast-forwarded to draft and pushed (5546e7c..ef60279: no-CL MPC wording/numbers, Fig S5, Methods pointer, this sentence). Overleaf pull is the last step.

### 2026-10-16 — MPC (Fig 6) and VARX (Fig S5) declared DONE and LOCKED
**Changed/Found:** `CLAUDE.md` — new locked-decisions block "MPC (Fig 6) + VARX (Fig S5)":
- L = Q = 35, ridge 100;
- the controller model never sees CL data (`_noCL` files canonical);
- Hp 35, rd 0.1;
- MPC purple / VARX pink;
- Fig S5 lettering.

`TASKS.md` — added to Recently done (oldest item, 2026-10-07 LMM df fix, pruned to keep the cap at 10); the MPC section is retitled as locked, and the open "two thirds" sentence check is added there.
**Why:** the user said "MPC and varx is done and locked log it and commit".
**Next:** the only open MPC item is the "two thirds of the squared error" sentence in the sine Results (≈ half on recomputation). Push Closedloop draft → main only on the user's go.

### 2026-10-16 — VARX supp grid panel: y label "history L = Q (frames)" → "history (frames)"
**Changed/Found:** `ctrl_mpc_varx_supp_panels.m` — panel E (paper letter D) y label changed, so L/Q no longer reaches the reader. The PAPER_FINAL re-export did NOT reach the final folder: `panels/supp_varx/varx_E_sweep.pdf` (and C, D) are locked by Illustrator; only A updated. The working copy in `paper/images/supp_varx/` is updated.
**Why:** user request.
**Next:** once Illustrator is closed, re-run `global PAPER_FINAL; PAPER_FINAL = true; ctrl_mpc_varx_supp_panels`, then swap panel D in `varx.pdf` and recopy it to Closedloop_edit `images/supplementary/S_varx.pdf`.
**Update (same day):** the lock was Acrobat (it had `varx.pdf` open), not Illustrator. After the user quit it, the re-export wrote A, C, D and E to `panels/supp_varx/`, and the grid shows "history (frames)". `collect_final_panels` also removed the leftover F pdf; it had been locked during the earlier cleanup. Remaining: the user swaps D into `varx.pdf`, then recopy to `S_varx.pdf`. DONE: the user swapped D (`varx.pdf` 19:10). It was copied to Closedloop_edit `S_varx.pdf`; the build is clean (39 pp, 0 errors, 0 undefined); draft commit `9d57903`.

### 2026-10-16 — VARX supp in the paper as Fig. S5; laser-response panel F retired
**Changed/Found:**
- **Assembled figure in.** The user assembled `paper/figures_final/varx.pdf` (A construction, B weight map, C forecasts, D validation grid, E R² vs lead) and dropped panel F. Copied it to Closedloop_edit `images/supplementary/S_varx.pdf`. It renders as Fig. S5 (`fig:supp_varx`).
- **Caption.** States: training on spontaneous + OL only (no CL); 92 held-out OL trials over 5 folds; grid flat (all λ ≤ 10³ within 0.025 of best 0.634; used 0.626); R² at 200 ms 0.41 / 0.37 / 0.10 (VARX / site + laser / naive).
- **Methods pointer.** `methods_rewrite.tex` VARX paragraph now points to the figure; the validation range is corrected from "1–10⁴" to the swept grid, 10–10⁴ and 5–35 frames.
- **Manifest.** `varx_F_laser_response` removed; `collect_final_panels` pruned its pdf and png (127 present, 0 missing).
- Draft commit `2b828d1`; the PDF builds at 39 pp.

**Why:** the user said the laser-response panel isn't needed and asked to inset the figure with a caption and point to it from Methods.
**Next:** grid panel D still labels its y axis "history L = Q (frames)" — the only place L/Q reaches the reader; relabel to "history (frames)" if wanted. The producer still draws F (harmless; not in the manifest).

### 2026-10-16 — No-CL training made CANONICAL for every MPC panel, the stats table and the manuscript; ridge stays 100
**Changed/Found:**
- `ctrl_mpc_direct_panels.m` / `ctrl_mpc_sine_panels.m`: default `sfx = '_noCL'`, output back in `supp_mpc/`.
- `paper_stats_table.m`: reads `_lam01_noCL` / sine `_noCL`.
- `mpc_direct.py` / `mpc_direct_sine.py`: docstrings name the canonical run (`MPCD_NOCL=1`, tag `_noCL`). The env default is left at 0, so untagged files keep meaning with-CL. The old canonical files stay in place as the with-CL reference; an overwrite was blocked and isn't needed.
- Re-exported with PAPER_FINAL: all 8 data mpcd_* + 5 mpcs_* finals. Regenerated STATS_TABLE.csv: 6_ratio 0.682 (107/108), 6_var 0.630, sine MPC/CL+p 0.879 (56/57), varratio 0.707, perfect 0.767, lag −2.5°.
- `Closedloop_edit` draft:
  - `methods_rewrite.tex`: "the MPC's own model never saw closed-loop data … spontaneous and open-loop frames only" (static + sine). Also fixed the stale "ten lags, 286 ms" → "35 lags, 1 s, of every channel and of the laser command".
  - `results.tex`: 0.84 → 0.88 %ΔF/F, 39% → 37%, 2.61 → 2.67, MPC lag −1° → −2°, variance 0.67 → 0.71.
- Ridge: user settled it — keep 100.

**Found:** the results claim "about two thirds of the squared error in the half-cycles where the reference rose" does NOT reproduce with a dR>0 split: MPC 0.49, perfect 0.49, identical in old and new data, with the laser off 83% of the rising half. The earlier ⅔ / 79% must have used another definition.
**Why:** the user: "export all panels ill reassemble then add to methods that we used no CL trial training"; "dont change ridge keep as is".
**Next:** pin down the ⅔ claim (find the original definition, or rewrite it as ~half); push Closedloop_edit draft → main only on the user's go.

### 2026-10-16 — MPC: no-CL controller model made canonical (code defaults switched)
**Changed/Found:** `controller-analysis/ctrl_mpc_direct_panels.m`, `ctrl_mpc_sine_panels.m` — default `sfx` is now `'_noCL'` (was `''`), and panels write to `paper/images/supp_mpc/` whatever the suffix (was `supp_mpc<sfx>/`). `mpc_direct.py`, `mpc_direct_sine.py` — docstrings mark `MPCD_NOCL=1` (controller VARX trained on spontaneous + OL data only, never CL / CL+p) as CANONICAL, with `_noCL` output tags. `paper-writing/paper_stats_table.m` — Fig 6 rows now load `mpc_direct_AL_0033_0226_e2_lam01_noCL.mat`, and the sine rows load `mpc_direct_sine_AL_0048_0714_e1_noCL.mat`. These edits were made in another session; logged and committed here at the user's request.
**Why:** User decision 2026-10-16 to adopt the no-CL controller model, so the MPC replay can't have learned from the closed-loop trials it is compared against (preview: static MPC/CL 0.682 vs 0.662, sine 0.879 vs 0.887; see the "No-CL preview" entry).
**Next:** Not verified here: re-run `paper_stats_table` → `paper_stats_tex` so STATS_TABLE.csv / stat_tables.tex pick up the _noCL numbers; regenerate the Fig 6 panels with PAPER_FINAL on; update the manuscript MPC numbers to match.

### 2026-10-16 — Fig S2 re-assembled (A–C quartiles, D–F rasters); caption keyed to panels
**Changed/Found:** The user's new assembly `paper/figures_final/FIgure2_supp.pdf` is copied to `Closedloop_edit/images/supplementary/S_state_quartile.pdf`. Layout: rows A–C = motion / rel δ / abs δ quartile tiles; D–F = per-mouse raster strips (mW headers); legend on top, two colour keys at the bottom. `supplementary.tex` caption is rewritten around A–C and D–F (state rows A/D, B/E, C/F; |Dev.| as labelled in the figure). `results.tex`: "Figure S2, second column" → "S2A–C, second column". Build clean.
**Why:** User: "reexported with new captions so add them to caption".
**Next:** Closedloop draft pushed; ff main + push on the user's go.

### 2026-10-16 — Fig S2 caption rewritten; raster headers in mW
**Changed/Found:** `Closedloop_edit/supplementary.tex` — Fig S2 caption: column D (error variance) removed. It now describes the right-hand rasters: one amplitude per session by rule (second-highest: Mouse 5a 0.80 mW, 59 trials; 5b 0.87 mW, 50; Mouse 1 1.43 mW, 82; Mouse 3 0.33 mW, 100), trials sorted by state lowest at the bottom, quartile lines; Activity −0.2 to 0.49 s, blue–red ±5 %; |Deviation| from the amplitude mean, 0–0.49 s, white→black 0–5 %; raw ΔF/F. `methods_rewrite.tex` — the Fig S2 sentence no longer mentions variance/bootstrap and now mentions the per-session rasters. `impulse-analysis/imp_state_raster_peramp.m` — strip headers changed from V to mW (÷3, the Table 3 conversion) and re-exported. Build clean (0 undefined).
**Why:** User: "Rewrite the Fig S2 caption ... drop column D, describe the per-mouse rasters". mW keeps the figure consistent with Table 3 and the caption.
**Next:** Closedloop draft pushed; ff main + push on the user's go. User re-places the rmice strips (headers changed) when assembling.

### 2026-10-16 — No-CL preview: full Fig 6 MPC panel set rebuilt with a controller that never saw CL data
**Changed/Found:** ran `mpc_direct.py` (`_lam01_noCL`, `_lowrd_noCL`, `_noCL`, robust `_lam01_noCL`) and `mpc_direct_sine.py` (`_noCL`), all with `MPCD_NOCL=1`, then `ctrl_mpc_direct_panels(sess,'_noCL')` and `ctrl_mpc_sine_panels(sess,[],'_noCL')` → `paper/images/supp_mpc_noCL/` (PAPER_FINAL off; finals untouched). No-CL vs canonical:
- **Static:** MPC/CL 0.682 vs 0.662, 107/108; perfect/CL 0.223. Per-trial MPC RMSE correlates 0.999 with canonical; median per-trial ratio is 1.024 (2.4% worse).
- **Robust A/B/C/D:** 0.682 / 0.693 / 0.715 / 0.700 (canonical 0.662 / 0.680 / 0.684 / 0.693).
- **rd sweep:** 0 → 0.677, 0.01 → 0.675, 0.03 → 0.680, 0.1 → 0.682, 1 → 0.730.
- **Sine:** MPC/CL+p 0.879 (56/57) vs 0.887; perfect 0.767 (unchanged); MPC lag −2.5° (was −1.1°); MPC variance 6.26 vs CL+p 8.85.
- **Example trials:** the median example trial is now 86 (re-picked by median); the deviation example (79) and sine example (161) are unchanged.

**Why:** the user wants every panel in the no-CL version before deciding whether to swap, to rule out a reviewer's "trained on CL" objection.
**Next:** if the user swaps, make `MPCD_NOCL=1` the default, rerun the canonical tags, regenerate the panels with PAPER_FINAL on, and update the stats table and manuscript numbers (0.84 → ~0.68×-based ratios, etc.).

### 2026-10-16 — Fig S2: variance column dropped; per-mouse raster fits the right column
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — the error-variance column (D) is dropped (`SQ_VAR`, default false); the tile canvas is 2.4 × 2.3 cm (was 2.7 × 2.4); the legend item reads "Mean (ratio)". The exported tile is still 3.07 cm wide whatever SQ_W is, because the fixed-size 2-line note text sets the overhang. `impulse-analysis/imp_state_raster_peramp.m` — the S2 strip moves to the right column: 8.2 cm wide, the same height (SQ_H) and heatmap band (0.27H / 0.55H) as a tile so rows line up, about 0.86 cm per heatmap. Headers are positioned in cm ("Mouse 5a, 2.4 V" / Activity / |Dev.|), and the activity x-tick label shows only "0" because "0.4" collided with the |dev| "0" ("0.40"). State names come from the tiles. Second-highest amplitude per mouse. MANIFEST: sq_*_var removed and their files deleted from the pull folder. Mock assembly: 3 × 3.07 + 8.22 cm ≈ 17.4 cm plus gaps fits 17.6 cm. PAPER.md registry updated.
**Why:** User: "drop the error variance column from all states, then make the figures slightly smaller to have this raster fit on the right column, lets pick the second highest amp".
**Next:** User assembles Fig S2 in Illustrator (rows: tiles A–C + raster; legend and both colour keys at the bottom) and writes the caption. The supplementary.tex caption still describes a column D and no rasters.

### 2026-10-16 — Manuscript preprint layout; draft fast-forwarded to main and pushed
**Changed/Found:** `Closedloop_edit/main.tex`: margins 0.5 in → 1 in, `\doublespacing` → `\onehalfspacing`. Author block: removed the broken `\affil[12,3,4,5]{Department of , ...}`; now five unindexed authors and one affiliation, "University of Washington, Seattle, WA, USA". `stat_tables.tex` Table 3 (`tab:stat_fig3`): footnotesize + tabcolsep 4pt, because it overflowed by 47 pt at the new width. Build: 38 pp, 0 undefined, 0 overfull hbox. Merged the Overleaf commit dffcb0f (stat_tables, 1 line) into draft first, then fast-forwarded main to 5546e7c and pushed main and draft (user: "push to main").
Already resolved by earlier sessions, so no change: mouse IDs appear only in LaTeX comments; Results L18 says "adjacent" consistently; volts appear only in the Methods controller description, with the V→mW map stated once.
**Why:** User 2026-10-16: make the preprint-readiness edits and push to main.
**Next:** Overleaf pulls main. Still open before posting: re-place the Fig 2/4 panels in Illustrator, and add departments to the author block. Methods `%% CHECK` gains (Kdata.npy, lab PC) are invisible in the PDF and were skipped.

### 2026-10-16 — MPC panel producers take a variant suffix (for the no-CL preview set)
**Changed/Found:** `ctrl_mpc_direct_panels.m` (new arg `sfx`) and `ctrl_mpc_sine_panels.m` (new 3rd arg `sfx`) — they read `mpc_direct_<sess>_lam01<sfx>.mat` / `_lowrd<sfx>` / `<sfx>` and `mpc_direct_sine_<sess><sfx>.mat`, and write to `paper/images/supp_mpc<sfx>/`. The default `''` behaves exactly as before.
**Why:** the user wants every MPC panel rebuilt with the no-CL controller model (`MPCD_NOCL=1`) to compare before deciding whether to swap, without overwriting the canonical data or the final panels.
**Next:** run with sfx = '_noCL' (PAPER_FINAL off) once the `_noCL` replays finish.

### 2026-10-16 — Fig 4 relative 2–4 Hz effects framed as measured during stimulation
**Changed/Found:** `Closedloop_edit/results.tex` L205 (new sentence: the state window spans stimulation, so relative-power effects describe power during stimulation, which the loop shapes, not the starting state); `discussion.tex` L18 ("measured over a window that includes stimulation") and L42 ("during stimulation"). Abstract and Intro L46 already make no relative-2–4 Hz claim, so they are unchanged. Build clean, 40 pp. Draft commit, not pushed.
**Why:** User 2026-10-16. The laser-off check (RESEARCH 2026-10-10 'Circularity') showed the OL-flat / CL-rises split is specific to the in-stimulation window. The user chose to reword rather than add laser-off rows to Table 1.
**Next:** none for the text. TASKS "DECIDE random state slope" was stale: the uncorrelated random slope was adopted on 2026-10-11 and the manuscript already quotes it (rel 0.76 / 0.044 / 0.027). The laser-off numbers in the 10-10 entry are on the old locked model.

### 2026-10-16 — MPC test: controller VARX trained without ANY closed-loop data changes nothing material
**Changed/Found:** `mpc_direct.py`, `mpc_direct_sine.py` — new `MPCD_NOCL=1` flag. With it on, the controller model trains on spontaneous + OL data only; static excludes every CL trial, sine excludes every CL and CL+p trial and still holds out the test fold. The world model is unchanged (it must reproduce the recordings). Test runs (tag `_noCLtest`, λ = 100): static MPC/CL 0.682 (canonical 0.662), 107/108; sine MPC/CL+p 0.879 (canonical 0.887), 56/57; perfect unchanged (0.767). Controller R² on CL windows: 0.421 @ 86 ms (was 0.425).
**Why:** the user asked whether training on CL data lets a reviewer argue we are cheating. The canonical runs only hold out the test fold's CL trials; the other CL trials are in training.
**Next:** recommended making no-CL the canonical training (alongside the ridge decision), then rerunning static / robust / sine / Fig 6 panels / stats / manuscript numbers. Note the VARX supp panels already train on spont + training-fold OL only (`mpc_varx_supp.py`).

### 2026-10-16 — VARX supp schematic v2: no L/Q, stacked z/u vectors, h-step forecast, correct training text
**Changed/Found:** `varx_construction_diagram.tex` — braces now read "35 frames (1 s)" with no L/Q symbols; channel labels are "output site / cortical sites / laser command", with the stacked z_t = [y; x1..x100] and u_t further left; the equation is written with explicit lags (t−34, t−33); the iterate feedback loop is replaced by "h-step forecast ẑ_{t+1..t+h} (up to 1 s ahead)". The subtext now says "trained on spontaneous and open-loop data, tested on held-out trials (5-fold)". The old "every frame incl. closed-loop" text was WRONG for the supp panels, whose `mpc_varx_supp.py` excludes CL. Final panel B re-exported.
**Why:** user feedback — the reader never needs L/Q, and the loop was confusing.
**Next:** none.

### 2026-10-16 — Fig 2G Results: state co-variation, no claim about the stimulus effect
**Changed/Found:** `Closedloop_edit/results.tex` L98–99 (draft) — replaced "a fixed stimulus effect rides on ongoing activity ..., rather than that state changes how cortex responds" with: responses and ongoing activity change together with state (both less variable with movement, both more variable with absolute δ power); we do not separate a change in the stimulus effect from a change in ongoing activity. Next sentence now "This is consistent with brain state acting as a disturbance ...". Build clean, 40 pp, 0 undefined.
**Why:** User 2026-10-16: not claiming motion changes the stimulus response, nor that it doesn't — only that under motion the responses look different and so does the underlying activity.
**Next:** Discussion L16 carries the old claim ("rather than as a change in the response itself") — user is rewriting the Discussion. The response-vs-control ratio test (TASKS) is no longer needed for this wording.

### 2026-10-16 — Power scale bars: decided not to change
**Changed/Found:** none — the TASKS item "Mislabeled power scale bars" (2A, 2B, 3A/3C, S-MPC) is closed without code changes.
**Why:** User checked the V→mW conversion manually and it is correct; the 2026-10-10 review flag was wrong.
**Next:** none

### 2026-10-16 — Fig S2 strips: blue-white-red activity map; highest-amplitude comparison copy; finalized
**Changed/Found:** `impulse-analysis/imp_state_raster_peramp.m` — the activity map is now blue (negative/dip) – white – red (positive) (`local_bwr`, RdBu end points); |dev| stays white → black. Onset and quartile markers are now black so they don't read as data on the red/blue map; this also applies to the exploratory grid. New `RSA_S2_AMP` = 'second' (FINAL, mirrored) | 'top' (writes `sq_*_rmice_top.pdf` to images only, not in MANIFEST). Highest-amplitude copy: Mouse 5a 2.7 V (n = 56), Mouse 5b 2.7 V (n = 54), Mouse 1 4.9 V (n = 84), Mouse 3 1.6 V (n = 100). Its dip is deeper and the abs δ |dev| gradient is still visible (5a, 5b, 3). FINAL = second-highest, re-exported to figures_final with both keys.
**Why:** User: "non grayscale color bar for activity, like blue to red, also gimme the same for the highest amp per mouse then finalize". Caveat: red/blue are the locked OL/CL condition colours in Figs 3 and 5. Here they are a diverging scale in a supplementary figure, and the caption must say so.
**Next:** User assembles Fig S2 and writes the caption (rule, raw units, |dev|, colour scales). To use the highest amplitude instead, run with `RSA_S2_AMP='top'` and swap the MANIFEST names.

### 2026-10-16 — VARX supp locked for assembly: [supp_varx] added to MANIFEST, final PDFs exported
**Changed/Found:** `paper/figures_final/MANIFEST.txt` — new `[supp_varx]` section (varx_A–F). `ctrl_mpc_varx_supp_panels.m` — with PAPER_FINAL on it now copies the TikZ panel B straight into `panels/supp_varx/`, since B is not a MATLAB figure and so never passes through the mirror. Ran it with PAPER_FINAL on: all 6 PDFs are in `panels/supp_varx/`, and `collect_final_panels('dry')` reports 131 present, 0 missing, 0 to prune.
**Why:** the user approved the prototype ("looks good give me panels for assembly").
**Next:** the scale-bar labels in C/F crowd each other (fix in Illustrator); the panels use ridge 100 — if ridge switches to 10³ (still open), re-run with PAPER_FINAL on. Caption, Methods pointer and PAPER.md registry entry are still to do.

### 2026-10-16 — VARX supp: VARX recoloured pink, forecasts graded light → dark
**Changed/Found:** `ctrl_mpc_varx_supp_panels.m` — VARX colour `C.m` purple → `C.v` pink [0.85 0.20 0.55] in every panel (weight map, forecasts, R² curve, sweep colormap, laser-response fit). Panel C forecasts go from light to dark pink in time order. `varx_construction_diagram.tex` uses the same pink.
**Why:** the user wants purple reserved for the MPC, so the model and the controller are not confused across Fig 6 and the supp.
**Next:** Fig 6G (`ctrl_mpc_direct_panels.m` panel B) still draws the VARX R² curve in purple — recolour it to pink if the convention should hold in the main figure too.

### 2026-10-16 — VARX ridge test: grid-best λ = 10³ barely moves the MPC result
**Changed/Found:** `mpc_direct.py` / `mpc_direct_sine.py` run with `MPCD_LAM=1000` (tag `_lam1e3test`, canonical files untouched). Validation grid (`mpc_varx_lq_sweep`, R² at 200 ms): chosen L=Q=35, λ=10² = 0.626; best = 0.634, tied at L=Q=20 and L=Q=35 with λ=10³ (full range 0.588–0.634). At λ=10³: static MPC/CL 0.673 (was 0.662), 107/108; sine MPC/CL+p 0.897 (was 0.887), 56/57; perfect/CL+p 0.760 (was 0.767).
**Why:** the user pointed out that the supp sweep panel shows a best cell we didn't use.
**Next:** if λ=10³ is adopted, change the CFG default, rerun the canonical static (`_lam01`), robust, sine, varx_supp and Fig 6 panels, then update the stats table and the manuscript numbers.

### 2026-10-16 — VARX supp: tiled forecasts in panel C, AR removed from panel D
**Changed/Found:** `ctrl_mpc_varx_supp_panels.m` — C now plots every other origin (~0.97 s apart), so the 1 s forecasts tile instead of stacking, with two alternating purples. D drops the AR curve; it keeps VARX, site + laser and naive.
**Why:** the user said overlapping forecasts made the individual forecasts look bad, and AR is an unfair comparison because it never sees the stimulus.
**Next:** the scale-bar labels in C/F still crowd; build the panel-lettered layout once the ridge choice is settled.

### 2026-10-16 — Fig S2: per-mouse raster strips replace the pooled strip
**Changed/Found:** `impulse-analysis/imp_state_raster_peramp.m` (new `RSA_S2` block) — three full-width (17.6 cm) strips `sq_<mot|dpr|dpa>_rmice.pdf`, one per state. Each strip shows 4 mice × {Activity −0.2 to 0.49 s, signed ±5 % ΔF/F, onset marker; |Deviation from amplitude mean| 0–0.49 s, 0–5 % ΔF/F}, with 2 cm heatmaps, trials sorted by state, quartile lines, and native PNGs swapped in (lossless). There is one amplitude per mouse by rule (second-highest): Mouse 5a 2.4 V (n = 59), Mouse 5b 2.6 V (n = 50), Mouse 1 4.3 V (n = 82), Mouse 3 1.0 V (n = 100). Colour keys are `sq_rmice_cbar_act/dev`. MANIFEST: pooled strip entries (sq_*_raster, sq_raster_cbar, sq_pooled_header, sq_divider) replaced by the 5 new files; retired PDFs/PNGs deleted from the pull folder. `imp_state_raster_supp.m` now has `RS_ROWS` off by default. PAPER.md registry updated. By eye: abs δ Q4 rows are darker (larger |dev|) in Mice 5a, 5b and 3; motion Q1 rows are darker in Mice 5a and 3; rel δ is flat.
**Why:** User: "Put one amplitude per mouse into Fig S2, chosen by rule (each mouse's second-highest amplitude), as activity + |dev| strips". The pooled strip mixed amplitudes. Eight heatmaps per state can't fit the 4.6 cm right column, so this is a full-width section.
**Next:** The user re-assembles Fig S2 with the strips as a full-width section below the tiles. The tiles were shrunk from 3.6 × 2.8 to 2.7 × 2.4 cm only to make room for the old strip, so they could go back. The caption must describe the strips (rule, raw units, |dev|).

### 2026-10-16 — Per-amp rasters: top 3 amplitudes per mouse, |deviation| on a sequential scale
**Changed/Found:** `impulse-analysis/imp_state_raster_peramp.m` — now shows only each session's top 3 amplitudes (`RSA_NAMP`; Mouse 3 has only 3: 0.4 / 1.0 / 1.6 V). Deviation is |x − μ_amp| on a white (0) → black (5 % ΔF/F, `RSA_DLIM`) scale; activity stays signed ±5. There are two colour bars, under the first and last bottom tiles. With |dev| the abs δ effect is visible by eye: Q1 rows are light and Q4 rows dark in Mouse 5a at 2.4/2.7 V, Mouse 5b at 1.9/2.6 V, Mouse 1 at 3.7/4.3 V and Mouse 3 at 1.6 V. Motion Q4 rows are lighter in Mouse 1 at 3.7 V and Mouse 3 at 1.0 V. Rel δ shows no clear gradient, consistent with the pooled result.
**Why:** User: "three candidate amps for each mouse ... keep the dev as absolute dev ... it will make more sense for effect". Signed deviation cancels to grey; |dev| shows the spread.
**Next:** User picks the Fig S2 representative(s). The pooled Fig S2 strip still shows signed deviation, so switch it to |dev| if this view is adopted.

### 2026-10-16 — Per-amplitude state-sorted rasters (exploratory)
**Changed/Found:** new `impulse-analysis/imp_state_raster_peramp.m` — one PNG per session in `paper/images/supplementary/state_raster_peramp/`. Rows are the 3 states and columns are amplitudes; each cell is Activity (−0.2 to 0.49 s) next to deviation from that amplitude's mean, in raw % ΔF/F at ±5, trials sorted by state, quartile edges marked. Looked at Mouse 1, Mouse 3 and Mouse 5b (Mouse 5a was written but not viewed). Results: (1) the stimulus dip is a clean dark band at the session's top amplitudes (Mouse 1 ≥ 2.7 V, Mouse 3 1.0/1.6 V), invisible at the lowest. (2) Single-trial fluctuations of ±5 % swamp low amplitudes. (3) The state effect is visible by eye only in places: abs δ Q1 rows are calmer than Q4 in Mouse 5b at 2.6/2.7 V. Elsewhere it is not obvious, which fits a pooled effect that is small within any one session × amplitude (11–25 trials per quartile).
**Why:** User wanted per-amplitude rasters (no amplitude mixing) and a rule-chosen representative for Fig S2.
**Next:** User picks the representative (rule: highest amplitude of the largest session = Mouse 1 at 4.9 V; cleanest dip = Mouse 3 at 1.6 V) and decides whether the full set becomes its own supplementary figure.

### 2026-10-16 — Found: raster normalization downscales; single-trial noise ≫ mean dip
**Changed/Found:** `impulse-analysis/imp_state_raster_supp.m` (no code change) — the per-session divisor (response RMS L2 error) is 2.86 / 2.68 / 4.14 / 2.93 % ΔF/F (M5a / M5b / M1 / M3), so the rasters are shrunk 3–4×, not upscaled. In raw units the mean dip (0.06–0.17 s) is only −0.8 to −1.6 % ΔF/F, while single-trial |activity| and |deviation| reach 5.7 % at the 90th percentile and about 11 % at the 98th. That is why signed single-trial maps look grainy grey.
**Why:** User asked whether the raster normalization upscales. Normalization isn't needed for the rasters: sorting is by within-session percentile, so every quartile has the same session mix.
**Next:** Waiting on the user: proposed switching both raster columns to raw % ΔF/F at ±5 % (colour bar "−5 / +5 % ΔF/F").

### 2026-10-16 — Fig S2 rasters: two signed columns, activity from −0.2 s
**Changed/Found:** `impulse-analysis/imp_state_raster_supp.m` — the strip is now two columns: Activity and "Deviation from mean". Both are signed on one grey scale (±2 norm. ΔF/F, black = negative); columns are 1.97 cm wide. The no-stim control is dropped from the strip. The running-RMS display (entry below) is reverted and its key `sq_raster_cbar_rms` is removed from MANIFEST and deleted from disk. Activity now starts at −0.2 s (`RS_PRE`), with a white dashed onset marker, so the stim-evoked dip shows against pre-stim baseline. Deviation stays at 0–0.486 s. "Time (s)" appears once, centred under the bottom (abs δ) strip.
**Why:** User: "keep only two things, activity and deviation from av, not rms, we will figure out other route for effect prominence"; then "activity slightly prior to stim too to show effect of stim on activity". Col B (stim/control) already carries the control comparison.
**Next:** The state effect is still not visually prominent in signed maps; another route is TBD with the user. The caption must describe the two columns and the −0.2 s pre-stim.

### 2026-10-16 — Fig S2 rasters: running-RMS deviation so the state effect is visible
**Changed/Found:** `impulse-analysis/imp_state_raster_supp.m` — the Deviation and No-stim columns now show the running RMS over 51 state-sorted trials (`RS_RMSWIN`) on a white (0) → black (`RS_RMAX` = 1.6) grey scale. Titles: "Deviation RMS", "No-stim RMS". Activity stays signed grey, tightened ±3 → ±2 (`RS_ACLIM`). There are now two colour keys: `sq_raster_cbar.pdf` (activity ±2) and the new `sq_raster_cbar_rms.pdf` (0–1.6), which is added to MANIFEST. Quartile boundaries are drawn white on a black casing so they show on any grey.
Pooled deviation RMS by quartile (Q1→Q4): motion 1.05 / 1.09 / 1.09 / 0.63; rel δ 0.99 / 0.96 / 1.03 / 1.02; abs δ 0.57 / 0.80 / 1.17 / 1.35. Abs δ now shows a clear light→dark gradient up the trials and motion a light Q4; the no-stim RMS also rises with abs δ (as in col B, stim/control ≈ 1).
**Why:** User: "everything appears gray". A signed per-trial map can't show a change in spread, because neighbouring trials' ± deviations blend to mid-grey. Prototyped raw / running-mean / running-RMS on the loaded data; running RMS was the only one where the gradient reads.
**Next:** The Fig S2 caption must define running RMS (51 trials) and norm. ΔF/F. User re-places the strips and both keys.

### 2026-10-16 — State rasters: onsets aligned; the "no effect" look is the error-normalised colour scale
**Changed/Found:** Checked `impulse-analysis/imp_state_raster_supp.m` (Fig S2 pooled raster strips) after loading `load_experiments` and `imp_state_trialvar` (4 sessions, 1516 trials).
- **Alignment is correct.** In every session and amplitude the trial-average trough is at 86–114 ms with no pre-onset dip; `dfImp` is referenced to the onset frame (that column is exactly 0).
  - Minor bias: the onset frame already carries the start of the response. The mean of frames −3..−1 sits 0.1–0.4 %dF/F above it at strong amplitudes, so referencing to that frame trims a few tenths of a percent from the response.
- **Cause of the weak look.** The Activity column divides each trial by its session's typical L2 single-trial error, k = 2.82 / 2.68 / 4.19 / 2.93 %dF/F (AL_0041 e1, AL_0041 e2, AL_0033, AL_0048).
  - That error is as large as the evoked response: mean troughs are −0.5…−1.7 (AL_0041), −0.9…−4.2 (AL_0033) and −0.5…−2.7 (AL_0048).
  - So the normalised trough is −0.1…−1.0 on a ±3 colour scale, i.e. near mid-grey.
- **Contributing factors:**
  - Near-subthreshold amplitudes are pooled in (AL_0041 0.7: −0.13; AL_0033 0.5: −0.05; AL_0048 0.4: −0.54).
  - The dip is only ~150 ms wide, a 4–5-frame band at the left edge of the 0–0.49 s window.
- **Diagnostics** (gitignored): `paper/images/supplementary/_diag_raster_by_amp.png` (raw %, sorted by amplitude, per-amp means) and `_diag_raster_scaling.png` (current vs raw ±4 % vs trough-normalised).
  - Raw %dF/F at ±4 shows a clear 50–200 ms band in every motion quartile.
  - Normalising by each amplitude's mean trough blows up on the subthreshold amplitudes: rejected.
**Why:** User: the rasters barely show the stimulation effect that we know exists; asked to check onset alignment and amplitude normalisation.
**Next:** Proposed to the user, not yet applied: Activity column in raw %dF/F with its own scale (±4 %), window −0.2..0.5 s so the onset edge shows. Deviation and control columns keep the session-error units, since comparing them is their purpose. Optionally drop the subthreshold lowest amplitude from the display only.

### 2026-10-16 — Fig S2 rasters: grayscale, single time label, one-line 5 pt titles
**Changed/Found:** `impulse-analysis/imp_state_raster_supp.m` — the colour map is now `gray(256)`: black = negative, mid-grey = 0, white = positive (was purple-white-orange). This also covers the colour key. "Time (s)" now appears once, under the middle column of the abs-δ (bottom) strip. Column titles on the motion strip are one line at 5 pt bold ("Activity", "Deviation", "No-stim ctrl"). They are drawn with `text()` because jnAxes/jnAxesAll force `title()` back to 7 pt. Re-ran load_experiments → imp_state_trialvar (STV_PLOT off) → raster with PAPER_FINAL. All 6 raster-strip files were re-mirrored.
**Why:** User: "grayscale colorscheme"; time axis "only the one on abs delta at the bottom really needs it ... mentioned only once"; motion titles "too big ... one row".
**Next:** The strip PDFs are cropped to content, so their heights now differ (2.22 / 2.01 / 2.36 cm). Align them in Illustrator by the heatmaps, not the page edges. The effect is still faint at ±3; the |deviation| / tighter-range proposals are still open.

### 2026-10-16 — VARX relocked to 1 s history for cortex AND laser (L = Q = 35); Fig 6 A–M + supp regenerated
**Changed/Found:**
- **Code:** `mpc_direct.py` CFG default is L = Q = 35 (was L = 10, Q = 35), with env overrides `MPCD_L/Q/LAM`. Also changed: `mpc_direct_sine.py` (inherits CFG), `mpc_varx_supp.py` (defaults 35, `VARX_*` env), the Fig 6G panel (now reads the L = Q = 35 held-out R² from `mpc_varx_supp`; AR/naive from embed), and the supp diagram (equal 1 s windows).
- **Canonical .mat:** regenerated. The old L = 10 copies are kept as `*_L10bak.mat`; `_LQ10` / `_LQ35` comparison runs are also kept.
- **Comparison (static):**

  | | held-out R² 86 / 200 / 1000 ms | MPC/PI | perfect |
  |---|---|---|---|
  | L = 10, Q = 35 | 0.687 / 0.418 / 0.046 | 0.652 (108/108) | 0.224 |
  | L = Q = 10 | 0.686 / 0.415 / 0.050 | 0.642 (108/108) | 0.205 |
  | L = Q = 35 | 0.681 / 0.408 / 0.084 | 0.662 (107/108) | 0.223 |

- **Comparison (sine, MPC/CL+p):** 0.885 (L = Q = 10), 0.887 (L = Q = 35), both 56/57.
- **λ check:** validated on validation rows only for L = Q = 35. Flat: 86 ms 0.757 / 0.759 / 0.759 at λ = 100 / 300 / 1000, so λ = 100 is kept. New `mpc_varx_lq_sweep.py`: L = Q ∈ {5, 10, 20, 35} × λ. 200 ms R² ranges 0.588–0.634; 35/100 scores 0.626.
- **New canonical numbers:**
  - Static: PI 1.457, MPC 0.844 (0.662×, 107/108), perfect 0.270 (0.223×). Variance over 1–3 s: 4.29 / 2.63 / 1.47 (−39%).
  - λ sweep (MPC/PI): 0 0.649, 0.01 0.645, 0.03 0.650, 0.1 0.662, 1 0.711, 10 0.796.
  - Robustness: same world 0.662 (107), other world 0.680 (107), ±20% gain 0.684 (102), both 0.693 (102).
  - Sine: MPC 2.61 vs CL+p 3.00 (0.887×, 56/57), lag −1.1°, variance 0.67×, perfect 0.767×. The upper-half-cycle share of squared error is 0.63, and the laser is off 79% of that time.
- **Supp prototype:**
  - Panel F is now held out per fold (R² 0.974).
  - Panel H (residual ACF) is dropped. Residual lag-1 ACF is −0.054, kept for a Methods sentence.
  - Panel E is the L = Q grid.
- **Stats table** is regenerated, and the Closedloop draft (13494e9) carries the numbers plus "using the past second of every channel and of the laser".
**Why:** User: the 10-frame cortex / 1 s laser asymmetry has no principled basis; use 1 s for both. In the earlier sweep Q = 10 was as good as Q = 35, because the AR terms carry the laser response forward.
**Next:** The MPC laser command at rd = 0.1 is visibly more jagged with the bigger model (C1/C2 lower traces); raise it with the user. Then the reviewer analyses proposed to the user, still awaiting a go: error-growth test, nonlinear predictor, no re-planning, clipped LQR, nonlinear-world replay.

### 2026-10-16 — Fig S2 legend: one row at 7.5 cm, 5 pt
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — the two-row legend is reverted to one row on a 7.5 cm canvas. Text is 5 pt (was 6) and labels are shorter: M5a/M5b/M1/M3 (Fig 2 style), "Mean (RMS)", "Mean (ratio, var.)", "No-stim control". The producer prints the row width (7.47 cm). Final PDF: 7.58 × 0.28 cm.
**Why:** User: "legend is even worse now, i want it this width but ... smaller text to fit in one row". Shrinking the text alone would have needed about 3 pt, so I also shortened the labels.
**Next:** User re-places sq_legend in Illustrator. The dashed no-stim swatch still reads almost solid at 0.25 cm.

### 2026-10-16 — Fig S2 raster colour key: end values only, smaller
**Changed/Found:** `impulse-analysis/imp_state_raster_supp.m` — the colour key is now 1.4 cm wide (was 2.4) and 0.08 cm tall. Ticks are −3 / +3 only, at 5 pt. The label "ΔF/F (× session typical error)" became "norm. ΔF/F". Only the key was re-exported (block run on its own, no data reload). The figures_final copy was stale until `clear paper_final_mirror jnExport; rehash`.
**Why:** User: "not have long label jst put -3df/F to +3df/f also make it smaller". I kept "norm." because the values are ΔF/F divided by the session's typical error. A bare "3 ΔF/F" would read as 3 % ΔF/F, which is wrong.
**Next:** The caption must define "norm. ΔF/F". Ask the user how to make the raster effect stand out (proposals: |deviation| on a sequential map, a tighter colour range, a running-RMS margin).

### 2026-10-16 — Fig S2 legend wrapped to two rows (half length)
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — the legend now has two rows: Mouse 5a/5b/1/3 on top; session mean, stim/control mean and no-stim control below. Canvas height 0.5 → 0.8 cm. `sq_legend.pdf` is now 7.5 × 0.74 cm (it was 13.4 × 0.3). The first re-export silently used the cached old script; `clear` + `rehash` fixed it.
**Why:** User: "the legend is much too big, half its length". Shorter swatches alone only got it to 13.4 cm; the text sets the length.
**Next:** User re-places sq_legend in Illustrator.

### 2026-10-16 — Fig S2 (state quartiles) legend shortened
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — legend swatch 0.5 → 0.25 cm, swatch–text gap 0.10 → 0.07 cm, gap between items 0.35 → 0.25 cm. Re-exported with PAPER_FINAL, so `sq_legend.pdf` is now 13.4 × 0.3 cm (it was full-width). The stats table is unchanged.
**Why:** User: "make the legend length smaller and the color bar too". The state-quartile figure has no colorbar, so I read "color bar" as the coloured line swatches.
**Next:** User re-places sq_legend in Illustrator. At 0.25 cm the dashed no-stim control swatch shows only about one dash; lengthen that one item if it reads as solid.

### 2026-10-16 — Strip mouse IDs from cohort table and stats Table 3
**Changed/Found:** `Closedloop_edit/methods_rewrite.tex` — cohort table rows are now Mouse 1–5 (no AL IDs); caption drops the AL↔Mouse map and lists the extra sessions as "two sessions of Mouse 1" and so on. `paper-writing/paper_stats_tex.m` — Table 3's "Recording" column (AL ID + date) is now "Date"; stat_tables.tex regenerated. I checked the rendered Figs 1–6 and S1–S3 by eye: no AL IDs in the figures (Fig 2/4G already use Mouse labels; S3 uses S01–S11).
**Why:** User: mouse naming "plagues a lot of captions including supplementary figures"; the paper convention is Mouse N only.
**Next:** none. AL IDs remain only in TeX comments and in the dead methods_edit.tex.

### 2026-10-16 — Collector run live: 8 tabled S4 rejection-trial panels pruned
**Changed/Found:** `paper/figures_final/collect_final_panels.m` run live. It pruned the 8 `s4_reject_trials_*` .pdf/.png files ([supp_reject], tabled 2026-10-10). Follow-up dry run: 126 present, 0 missing, 0 to prune; the pull folder now matches MANIFEST exactly.
**Why:** User approved the prune after the dry run listed them.
**Next:** The panels can be regenerated with `controller-analysis/f4_supp_reject_trials.m` if S4 is un-tabled (un-comment the MANIFEST lines first).

### 2026-10-16 — Closedloop main c0386d6 pushed: Methods restructure + Figure 6 (I–L) + Overleaf merge
**Changed/Found:** Placed `figures_final/FigureMPC.pdf` (user's assembly) as `Closedloop_edit/images/Figure6.pdf`. The assembly has FOUR sine panels, I–L (I example, J variance across trials, K phase lag, L per-trial RMSE), not the five (I–M, with RMSE-over-time as J) that the sine session's caption and paragraph described. The caption and Results references were rewritten to match. "the best of the rig's sinusoidal modes" for CL+p became "the rig mode that combined both corrections", because Fig 5 has plain CL with the lower median RMSE. Verified the restructure (943347c): build clean, both ΔF/F definitions with the reason, state windows, continuous band power, motion-energy definition, 14 ms exposure, +2/−1 mm targets, 1 V integral clamp, blinding sentence all present; the per-mouse τ numbers now sit in the Results Fig 2F paragraph. origin/main carried one Overleaf edit (2f5a681, results.tex: an unfinished rewrite of the first sentence of "Controller performance is brain-state dependent"). It was merged into draft unchanged, then main was ff'd to c0386d6 and pushed (draft too).
**Why:** User: "do the full paper edit, updated methods and push to main".
**Next:** user finishes that Overleaf sentence (it currently reads "...but tracking performance / but how well it held activity..."). Remaining FILLs: IACUC, titers, illumination power, repository URL. The removal of AL_0051's opsin/594 nm (user) leaves the text implying ChrimsonR/638 nm for all mice.

### 2026-10-16 — Manuscript: Methods restructured (Closedloop_edit draft 943347c)
**Changed/Found:** `methods_rewrite.tex` rewritten to plan §E/§9: ~10,260→~6,590 rendered words (rough script; texcount 9,615→6,180). 15 subsections (Animals and preparation; Imaging and optogenetic stimulation; Behavioral monitoring; Real-time control; Controller; Model-predictive control replay [new, `sec:mpc`]; System characterization; Controller tuning; Session and trial selection; Brain-state measures; State exemplars and error decomposition; Impulse-response variability and brain state; Contralateral prediction and disturbance rejection; Experimental Design and Statistical Analysis; Data and code availability). Cited away to Matveev2024: mouse lines/Jackson numbers, surgery doses/materials, optics/camera/LED ramps, galvo calibration, power-meter procedure, SVD/registration, face-camera sync. Cut: Python/process/semaphore detail, unused Butterworth, MATLAB function names, Mouse-3 tfest workaround (→1 sentence), Sustained stimulation subsection, rig-build caveat, AL_0051 594 nm, 4 s session, K_r calibration-block route, per-session OLS slope analysis, duplicate blinding/df/corroboration text. Added author facts: 14 ms exposure, targets ≈(+2,−1) mm from bregma, monthly power calibration, integral clamp 1 V, jittered onsets, gain-setting story, MPC facts (Q10). Kept Algorithm box; `tab:gains` moved to `supplementary.tex` as Table S1 (label kept). All externally cited labels kept (eq:pi, eq:kr, eq:nl_*, assm:trial_avg, sec:pi_controller_design now also holds the ~1 mW power ceiling, sec:stats, tab:cohort); sine-session list moved into `tab:cohort` caption. Counts check vs STATS_TABLE.csv / fig2b_trial_counts.csv: 1516 trials, ≥44/amplitude, 3–9 amplitudes ≤1.63 mW, 1670 trials (=gains-table OL+CL), 1190 motion trials, 11/13/15 sessions, 595 RR trials all consistent; 613 CL motion trials matches NUMBERS.md; AL_0041 trials/session filled as 208–260. Per-mouse time-constant numbers moved to `results.tex` L80–82 (NOT committed: results.tex also carries the main session's MPC/Fig 6 hunks). Build clean (latexmk exit 0, no undefined refs). Remaining FILLs: IACUC number, viral titers, illumination power density, repository URL (visible `[repository URL]`).
**Why:** User: Methods too big; cite the mesoscale system paper (Matveev2024) and cut implementation detail; answers recorded in paper-writing/METHODS_RESTRUCTURE_PLAN.md §9.
**Next:** author reviews `git diff main..draft -- methods_rewrite.tex`; fill the remaining FILLs; then ff main + push on their go.

### 2026-10-16 — PROTOTYPE supp figure: how the VARX is built and how well it predicts
**Changed/Found:** new `controller-analysis/mpc_varx_supp.py` (compute), `ctrl_mpc_varx_supp_panels.m` (panels → `paper/images/supp_varx/varx_*.png`, draft layout `_draft_layout_supp_varx.png`) and `varx_construction_diagram.tex` (TikZ, panel B). Static session AL_0033 0226 e2. It is the same model as the MPC (L 10, Q 35, ridge 100) with the held-out OL protocol of `mpc_varx_embed`, and it reproduces Fig 6G's R² exactly (0.952 … 0.046).
- New ablation, site + laser only (no cortical spots): R² 0.639 vs 0.687 at 86 ms, 0.364 vs 0.418 at 200 ms, 0.135 vs 0.218 at 486 ms. The 100 spots carry real predictive skill.
- Learned laser response vs the measured OL trial average: R² 0.98 (peak −4.82 vs −4.89 %).
- One-step residuals are near white: ACF lag 1 −0.08 and lag 5 0.00, vs 0.95 / 0.65 for y. This supports the innovation replay used as the simulated cortex.
- L × λ validation landscape (from `mpc_pred200_sweep`): chosen (10, 100) 0.640, best 0.647, range 0.568–0.647, i.e. a broad plateau.
- In the one-step y equation the site's self-weight is 1.62 vs 0.16 for the strongest spot.
Not in MANIFEST, no PDFs: awaiting user approval.
**Why:** User: the VARX carries a lot of weight in Fig 6 and needs its own supplementary demo of construction and prediction. Prototype for approval.
**Next:** Remaining polish: E colorbar ticks clipped; the `t` label overlaps "286 ms)" in B; A's spot map shows the session's cached outline (both ROIs). On approval: add to MANIFEST, export PDFs, write the caption and a Methods pointer (not methods_rewrite.tex while the other session restructures it).

### 2026-10-16 — Fig 6L rescaled to the CL+p vs MPC differences
**Changed/Found:** `controller-analysis/ctrl_mpc_sine_panels.m`: L's y-axis is now [−2.5 3]° with ticks at −2/0/2. The OL bar (70.7°) is truncated with a white break mark, and the caption on Closedloop draft (results.tex) states it as 71°, truncated. Re-exported with PAPER_FINAL.
**Why:** User: emphasise the difference between CL+p (1.7°) and the MPCs (−0.6°, −1.6°), which was invisible on a 0–75° scale.
**Next:** none.

### 2026-10-16 — Fig 6 I–M resized to fit one row (17.6 cm)
**Changed/Found:**
- **Sizes:** in `controller-analysis/ctrl_mpc_sine_panels.m`, panel I is now 5.2×3.0 cm and J–M are 2.8×3.0 cm each (was 8.43 / 4.13 × 3.3). The row is 15.6 cm with 0.3 cm gaps (preview: `paper/images/supp_mpc/_row_preview_mpcs.png`).
- **Labels:** the condition names are now one row whose spacing is measured in cm from text extents. J and M carry them under their titles, and I's legend reads CL+p / MPC / perfect / target. K and L tick labels are rotated 45°.
- **Fixes:** I's dashed target is redrawn on top, because at this size the traces hid it. The K/L left margin went to 0.95 cm, because the L y-label was clipped.
- **Export:** re-exported with PAPER_FINAL.
**Why:** User: I–M must fit in one row.
**Next:** User assembles them in Illustrator.

### 2026-10-16 — Fig 6I example switched to CL+p trial 161 (large MPC gain)
**Changed/Found:** `controller-analysis/ctrl_mpc_sine_panels.m` has a new 2nd argument `kEx`, default 161; `[]` gives the median trial, which is 87. Candidates were the top 5 CL+p trials by RMSE drop: 104 (4.74→2.70), 141 (2.79→1.63), 184, 27 and 161 (1.58→0.83, perfect 0.53). I chose 161 by eye: MPC tracks the sine across the whole window while CL+p overshoots each rise. 104 and 141 gain mostly in the onset transient. Re-exported with PAPER_FINAL. The caption on Closedloop draft (b96f099) now says "a CL+p trial on which the MPC improved tracking markedly".
**Why:** User: show a trial where MPC does really well, instead of the median one.
**Next:** none.

### 2026-10-16 — Fig 6 I–M recut: CL+p vs the two MPCs only; J = RMSE over time
**Changed/Found:** `controller-analysis/ctrl_mpc_sine_panels.m`: CL is dropped everywhere. MPC and perfect now come from the 57 CL+p trials, paired with those recordings.
- I: CL+p trial 87 at the median of MPC − CL+p (RMSE 3.61 / 3.32 / 2.98).
- J: `mpcs_J_rmse_time` (Fig 5F definition: √ of the across-trial mean squared error ± SEM) for OL, CL+p, MPC and perfect. It replaces `mpcs_J_trial_average`; MANIFEST is updated and the old final panel deleted.
- K: CL+p / MPC / perfect only.
- L and M: OL, CL+p, MPC and perfect.

Numbers:
- Variance over 0–4 s: 11.8 / 8.85 / 6.01 / 5.05.
- RMSE-over-time window mean: 3.96 / 3.11 / 2.72 / 2.39.
- Lag: 70.7 / 1.7 / −0.6 / −1.6°.
- Upper-half-cycle share of squared error: CL+p 0.57, MPC 0.64, perfect 0.66. The laser is off 80% of the upper half-cycle under MPC.

Closedloop draft a72eed2 rewrites the sine paragraph and the I–M caption to match.
**Why:** User: compare CL+p against the two MPCs only, and replace the all-controller trial-average panel with a trial-averaged RMSE comparison of OL, CL+p and the MPCs.
**Next:** User assembles I–M in Illustrator. The stats table still carries the CL rows too (a superset; harmless).

### 2026-10-16 — Manuscript: Fig 6 sine paragraph + caption I–M (Closedloop draft 15df1e2)
**Changed/Found:** `Closedloop_edit/results.tex` (draft only, not pushed). One paragraph replaces the ROOM RESERVED comment, and the Fig 6 caption now says A–H = AL_0033 and I–M = AL_0048, with I–M described. Numbers are from STATS_TABLE `6s_*`. The paragraph states the one-sided-laser ceiling and the caveats (one session, same model class, state-independent laser), and says the values use the controller's own signal and timing, so they differ from Fig 5. methods_rewrite.tex was not touched. latexmk builds clean.
**Why:** User asked to fill the two reserved spots only.
**Next:** User reviews `git diff main..draft`, assembles Figure6.pdf with I–M, and gives the go to ff main + push.

### 2026-10-16 — Fig 6 sine block in paper_stats_table
**Changed/Found:** `paper-writing/paper_stats_table.m`: new "Figure 6 sine" block (ids `6s_*`) reading `mpc_direct_sine_AL_0048_0714_e1.mat`. For every summary row it adds median RMSE, lag and variance. For each baseline (CL, CL+p) it adds the MPC and perfect RMSE ratios, with the n-lower count in the claim, and the variance ratios. STATS_TABLE.csv now has 140 rows.
**Why:** Manuscript numbers must come from the saved .mat via the table, not be typed by hand.
**Next:** none.

### 2026-10-16 — Fig 6 I–M panels (sine MPC) locked into MANIFEST [supp_mpc]
**Changed/Found:** new `controller-analysis/ctrl_mpc_sine_panels.m` → `mpcs_I_example` (CL trial 113, the median of MPC−CL), `mpcs_J_trial_average` (OL / CL / CL+p / MPC / perfect ± SD), `mpcs_K_rmse_compare` (paired, two baselines), `mpcs_L_phase_lag`, `mpcs_M_variance`. Window −1..5 s. The laser is in mW via `laser_v2mw` (07-14 calibration; nonlinear, so no V/3 rule). M uses a 5-frame running mean for display only; its window means are unsmoothed. All five are added to MANIFEST [supp_mpc] and mirrored with PAPER_FINAL.
**Why:** User asked for the Fig 6 extension: trial average with OL / CL+p / MPC, phase lag and trial-by-trial variance, in Fig 6 style.
**Next:** User assembles them in Illustrator after H. The caption names them I–M (five panels, not four).

### 2026-10-16 — Sine MPC replay: MPC 0.84× CL RMSE (46/46), lag 46°→1°; one-sided laser limits even perfect MPC
**Changed/Found:** new `controller-analysis/mpc_direct_sine.py` (MPCD_RD=0.1). It simulates MPC and perfect MPC on all 200 sine trials; the world reproduces all 200 exactly. Baselines are the recorded trials; values are medians over the 4 s window.
- RMSE: CL 2.26 → MPC 1.93 (0.845×, lower 46/46) → perfect 1.67 (0.725×). CL+p 3.00 → MPC 2.70 (0.888×, 56/57) → perfect 2.33 (0.758×).
- Phase lag of the trial average: OL 70.7°, OL+p 15.8°, CL 46.1°, CL+p 1.7°, MPC 0.8°, perfect 0.2°.
- Gain: CL 0.70, MPC 0.62, perfect 0.59.
- Across-trial variance (0–4 s): OL 11.8, CL 5.8, CL+p 8.9, MPC (CL+CL+p) 5.2, perfect 4.5. MPC/CL 0.73 on the same trials; MPC/CL+p 0.68.
- Controller-model R² on the sine windows: 0.69 at 86 ms, 0.29 at 200 ms.
- KEY: the error left even with perfect prediction sits in the upper half-cycle (r > −2). There the target rises back to 0, the inhibitory laser is at 0 about 80% of the time, and y stays about 1.4–1.7 % below the target (perfect MSE upper 7.5 vs lower 3.4). The actuator can only suppress, so it cannot drive the upswing. That is why the gain is below 1 for every controller and why the sine gain is smaller than the static one (perfect 0.22× there).
**Why:** User request: extend the Fig 6 replay to a sinusoidal reference, with the natural preview from the future r.
**Next:** The manuscript paragraph must state the one-sided-actuator ceiling and the four caveats. Fig 5H lags differ by about 1 frame convention (see the exporter entry).

### 2026-10-16 — mpc_solve takes a reference trajectory; static Fig 6 numbers re-confirmed
**Changed/Found:** `controller-analysis/mpc_direct.py` — `mpc_solve(..., ref=REF)` now accepts a scalar or the future reference r(t+1..t+Hp). The default is the static −5, so no static call site changed. Re-ran the static case (`MPCD_RD=0.1 MPCD_ORD=0.1 MPCD_SNAP=79,76`, tag `_lam01_check`): PI 1.457, MPC 0.823 (0.652×, 108/108), perfect 0.224× PI. Identical to the canonical `_lam01`. That run then hit KeyError 'MPC rd=1' at the snapshot step, because the canonical invocation also sets `MPCD_REF="MPC rd=0.1"`. No files were written.
**Why:** The sine replay (Fig 6 I–M) needs a time-varying target with natural preview. Generalised behind a default argument so the static numbers cannot move.
**Next:** none (`_lam01` stays canonical).

### 2026-10-16 — Sine MPC exporter: AL_0048 07-14/1 y = rig states.csv; two clock/reference gotchas
**Changed/Found:** new `controller-analysis/ctrl_mpc_sine_export.m` → `data/ctrl_mpc_arx_in_AL_0048_0714_e1.mat` and `ctrl_mpc_wb_in_AL_0048_0714_e1_n100.mat`, with the same fields as the static exporters plus `r`, `on`, `cond`, `fold`. Found:
- (1) `states.csv` row k holds frame k−1. It matches the offline 40 s-rolling dF/F at pixel [410 346] with r = 0.988 at that shift (0.95 at ±1; mode-1 F/mI only 0.84). So y(k) = states(k+1), and the onset frame = onset row − 1.
- (2) In the two PREVIEW modes `reference.csv` is the lookahead copy, advanced by 5 frames (r starts at −0.75, not 0). `reference_raw.csv` is the un-advanced target in all modes. So r = −reference_raw(k+1). `error.csv` = states + reference exactly.
- (3) Otsu on the mean image kept only the brighter hemisphere. The mask is 0.65× Otsu, eroded 6 px (QC PNG `paper/images/mpc_arx/mpc_sine_spots_*.png`).
- s2 has no galvo sign flip: params.pixel [410 346] and galvo_x +2.128 are both right side.
- 200 sine trials: CL+p 57, OL+p 46, OL 51, CL 46.
**Why:** The MPC replay must use the signal and target the rig's PI actually used. The y and r definitions are the controller's own.
**Next:** Fig 5 pairs `dFoF(i0)` with `ref_raw(i0)`, i.e. row = frame. That is one frame (≈10° at 1 Hz) off the rig's own pairing, so Fig 6 sine lags are not numerically identical to Fig 5H. Flag this if the two are ever compared in prose.

### 2026-10-16 — Standalone state-raster PNG retired (S2 carries it)
**Changed/Found:** `paper/figures_final/MANIFEST.txt` — `supplementary/supp_state_raster.png` commented out as RETIRED. Deleted `panels/supplementary/supp_state_raster.png`. PAPER.md row marked retired, pointing to the S2 strips. `collect_final_panels('dry')` also listed 8 tabled `s4_reject_trials_*` files (commented out 2026-10-10) for pruning, so I did NOT run the live collector. Only the raster was deleted, by hand; the dry run now shows 121 present, 0 missing, 8 pending.
**Why:** User: S2 now carries the raster, so retire the standalone and prune it. The S4 prune was not requested.
**Next:** User to decide whether to prune the 8 tabled S4 files (the producer can regenerate them). `figures_final/S_state_raster.png` (root-level copy next to S1–S5) is untouched; the collector does not manage the root.

### 2026-10-16 — Methods restructure plan written (no .tex edited)
**Changed/Found:** new `paper-writing/METHODS_RESTRUCTURE_PLAN.md` (full read of `methods_rewrite.tex`). Methods is ~10,550 rendered words (1,478 lines, ~190 of them `%%` comments), about 1.6× Results. Proposed target ~6,100 words (−42%). It works by citing the system to Matveev2024 (~1,630 → ~520 w), cutting implementation detail (semaphore/ring buffer, tfest, Algorithm box, input_params), removing 38 redundancy pairs, and adding a new MPC Methods paragraph. Ref risks: `eq:kr` and `sec:pi_controller_design` (Discussion), `sec:stats` (stat_tables), and S3's plain-text section name. Also found: `paper-writing/CLAUDE.md` still names `methods_edit.tex` as live (it is `methods_rewrite.tex`).
**Why:** User: Methods too big; cite the mesoscale system paper and cut detail without losing meaning.
**Next:** user approves the plan and answers the open questions (what Matveev2024 covers, surgery doses, gain-setting story), then apply in Closedloop_edit on draft.

### 2026-10-16 — Manuscript: MPC promoted from supplement to Results (Figure 6), with a slot reserved for sine panels
**Changed/Found:** `Closedloop_edit/results.tex` — new last Results section "Model-predictive control rejects disturbances in a replay of recorded trials". It covers the motivation, the VARX model, the MPC, the replay construction (recorded residuals; PI baseline = recorded trial), the result (RMSE 1.46 → 0.82 on 108/108 trials, variance −39%, perfect prediction 0.27, holds across λ) and one caveat sentence ("bounds rather than measures"). `fig:mpc_direct` moved here from `supplementary.tex` and is retitled; `images/supplementary/S_mpc.pdf` was git-mv'd to `images/Figure6.pdf`. LaTeX comments reserve room for the sinusoidal MPC panels and paragraph. `discussion.tex` — the MPC paragraph no longer repeats the Results numbers; it keeps the R² comparison and the interpretation. Build clean; MPC = Figure 6. Supplementary numbering is unchanged (MPC was last).
**Why:** User: promote MPC to Results without overselling it. It must read as a study on recorded data, not a live run, while showing the improvement. Sine-wave MPC panels will come from another session.
**Next:** (1) Methods has no MPC subsection; add one in the Methods restructure. (2) The R² 0.42 / 0.10 / 0.02 (Discussion) is still not table-backed (STATS_AUDIT §D); the Results avoid quoting it. (3) Illustrator: the MPC assembly is `figures_final/S5.ai`; rename it to Figure 6 when the sine panels are added.

### 2026-10-16 — paper_stats_table.m: Figure 6 (MPC replay) rows
**Changed/Found:** New block reading `controller-analysis/data/mpc_direct_AL_0033_0226_e2_lam01.mat` (λ = 0.1, timing lag 0 per the user decision of 2026-10-12). It writes rows `6_rmse_{1,2,3}` (median RMSE 1–3 s: PI recorded 1.457, MPC 0.823, perfect-prediction 0.268), `6_ratio` (MPC/PI median 0.652, 108/108 lower) and `6_var` (across-trial variance 1–3 s, MPC/PI 0.609 → "39% lower"; this verifies the Discussion's former "about 40%"). Checked: the 10-09 file's PI median 1.12 is the dropped idealised re-tuned PI, not the rig; 1.46 is the recorded PI and is correct.
**Why:** The MPC numbers move into the Results, so they must be table-backed (NUMBERS rule).
**Next:** add the sine-wave MPC rows when that analysis lands.

### 2026-10-16 — Fig S2 gains the pooled-trial raster strip (right of the quartile tiles)
**Changed/Found:** `impulse-analysis/imp_state_raster_supp.m` — new `RS_ROWS` block (default on). Writes one vector strip per state, `sq_<mot|dpr|dpa>_raster.pdf` (activity | deviation | no-stim control, 1.25 cm columns, 4.6 cm strip). Uses the same axes band as the S2 tiles (bottom 0.27·H, height 0.55·H) so heatmaps line up row by row. Column titles appear on the top row only, x ticks are 0/0.4, and "No-stim control" is split over 2 lines. Also writes `sq_raster_cbar.pdf`, `sq_pooled_header.pdf` ("Pooled trials (n = 1516, all sessions)" with a bracket) and `sq_divider.pdf` (vertical separator). All are in MANIFEST [supp_state_quartile] and mirrored to figures_final.
**Why:** User: Fig S2 should also contain the state-sorted raster (supp_state_raster.png), as a PDF to the right with a "pooled trials" demarcation.
**Next:** User assembles in Illustrator. The standalone `supplementary/supp_state_raster.png` is still listed under MANIFEST [supplementary]; retire it if S2 now carries the raster.

### 2026-10-16 — exportgraphics vector PDF destroys heatmaps; fixed by swapping in native PNGs
**Changed/Found:** new `utils/pdf_swap_images.py` (PyMuPDF). exportgraphics(...,'vector') re-encoded the 1516 × 18 raster as a **125 × 106 JPEG** (`print -vector` gave 68 × 106). Most trials were averaged away and the colours were JPEG-smeared. The producer now also writes each heatmap as a native colour-mapped PNG (`_native/`, one pixel per trial × sample, flipud for YDir normal) and swaps it into the PDF's image XObject, in both the images copy and the figures_final copy. Verified: pull-folder PDFs hold 18 × 1516 Flate (lossless) images, 3 placed per strip, and the render shows the correct panel order (activity onset dip in col 1 only). Gotchas: Qt nests the images in Form XObjects (get_image_info xref = 0), so xrefs are taken in document order; incremental save is refused, so the script does a full rewrite plus os.replace. MATLAB `system` is shadowed by a Rigbox mock that warns but still calls the builtin.
**Why:** The user wanted a PDF version of the raster; a straight vector export would have shipped an unreadable heatmap.
**Next:** Reuse pdf_swap_images.py for any other heatmap panel that has to be a PDF (the supp_spatial maps went PNG for this same reason).

### 2026-10-16 — Fig S2 quartile tiles shrunk to 2.7 × 2.4 cm, 2-line notes
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — SQ_W/H 3.6×2.8 → 2.7×2.4 cm. Tile content is ~3.05 cm because the y-label overhangs the canvas; jnExport's tight crop keeps it, nothing clips. The descriptive note (local_rr) now takes 2 lines ("Q4/Q1 x" / "range a–b"). Full S2 row = 4 tiles + divider + raster strip ≈ 17.9 cm with loose preview gaps, so it fits 17.6 cm once tightened.
**Why:** User: make the existing panels smaller to make room for the raster strip.
**Next:** none

### 2026-10-16 — Closedloop main fast-forwarded to bece569 and pushed (Fig 2 descriptive + Fig S2)
**Changed/Found:** User re-exported `FIgure2_supp.pdf` with the corrected legend (Mouse 5a/5b/1/3, checked by rendering). Copied to `images/supplementary/S_state_quartile.pdf`; the build is clean. main ff'd from draft: b2212d3 (Statistical tables section), 7c31560, 7e54b60, 1320962, bece569. Pushed main + draft to GitHub smartadi/Closedloop.
**Why:** User: "update and push" after re-assembling Fig 2 and Fig S2.
**Next:** pull on Overleaf (GitHub sync). Supplementary numbering is now S1 spatial, S2 state quartiles, S3 tuning, S4 exemplars; check any talk/notes that cite the old numbers.

### 2026-10-16 — Fig 2 + Fig S2 assemblies placed; S2 mouse labels were wrong (fixed in producer)
**Changed/Found:** Copied `figures_final/Figure2.pdf` → `Closedloop_edit/images/Figure2.pdf` and `figures_final/FIgure2_supp.pdf` → `images/supplementary/S_state_quartile.pdf`. Uncommented the S2 `\includegraphics`. The user's assembly letters ROWS A–C (motion / rel δ / abs δ), so the S2 caption was rewritten by row, and the Results "Figure S2B" (stim/control) became "second column". FOUND: the S2 legend said Mouse 1a/1b/2/3, but the paper names these sessions Mouse 5a/5b/1/3 (stats Table 3, Fig 2B/D/E). Fixed `SESS_LAB` in `imp_state_quartile_supp.m` and re-exported (`sq_legend.pdf` now reads 5a/5b/1/3); the caption also said "Mouse 1a and 1b".
**Why:** User re-exported both figures and asked to update and push. The naming mismatch would show the same mice under two names in one paper.
**Next:** user swaps `sq_legend.pdf` into FIgure2_supp.ai and re-exports; then copy, rebuild, ff main, push.

### 2026-10-16 — Manuscript: Fig 2G Results/caption/Methods made descriptive (Closedloop_edit draft)
**Changed/Found:** `results.tex` — 2G Results now report per-session patterns with no p-values: motion drop at Q4 (0.57–0.71, 4/4), abs δ rising in 4/4 (2.35, 1.70–2.71), rel δ no consistent pattern, and response/control Q4/Q1 0.98 / 0.95 / 0.87 (Fig S2B). Caption: the star/fraction sentence is replaced by "Descriptive panel; … supporting tests in Table". The hand-off to Fig 4 is reworded to "we test this directly in closed loop". `methods_rewrite.tex` — the inference paragraph is now "This analysis is descriptive … supporting test in Table"; the "Per-quartile tests" paragraph is rewritten as "Per-session view"; the stats-section sentence is reworded; the "attribute an effect only when it exceeds its control" rule is dropped. Also fixed a pre-existing broken `\ref` (a CR had replaced the "\r" of `\ref`, so it rendered as "Fig. ef{…}G") at the old line 1162. `supplementary.tex` — the Fig S2 caption describes the descriptive annotations. `paper_stats_table.m` — new rows `2G_*_stimctrl` (response/control Q4/Q1, geometric mean + range). `paper_stats_tex.m` — Table 4 caption marks the slope tests as supporting; the footnote gives response/control ratios plus the supporting top-vs-rest p. Build clean, no undefined refs.
**Why:** User: Fig 2 is groundwork, Fig 3 carries the paper's weight; keep the p-values only in the stats table "just in case".
**Next:** user re-assembles Fig 2 (2G) and Fig S2 in Illustrator; then review draft, ff main + push on their go.

### 2026-10-16 — Fig S2 panels re-exported with descriptive annotations
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — the panel notes no longer show "Q4/Q1–3 x, p=…" or "BF k/4". Columns A, B and D now show "Q4/Q1 GM (min–max)" via the new `local_rr`. The tests are still computed and written to `sq_stats.csv` for the stats table. Re-exported with PAPER_FINAL → 13 panels in `panels/supp_state_quartile/`. Found: response/control Q4/Q1 is motion 0.98 (0.93–1.06), rel δ 0.95 (0.90–1.02), abs δ 0.87 (0.66–0.99). The abs-δ value sits below 1 in all 4 sessions because Q1 response > control, so the response varies slightly LESS with abs δ than ongoing activity does. The Results now say this; it is consistent with a fixed stimulus effect diluting the state dependence.
**Why:** Same descriptive decision; S2 must match the main figure. Q4/Q1 replaces Q4 vs mean(Q1–3), so the paper uses a single ratio definition.
**Next:** user assembles S_state_quartile.pdf.

### 2026-10-16 — Fig 2G re-exported as a descriptive panel (no stars, no k/N)
**Changed/Found:** new `impulse-analysis/imp_state_var_combined.m` holds the Fig-2G combined-panel code (it used to be inline in `imp_state_trialvar_fig.m`, which now calls it). It reads `data/fig2g_state_stats.mat` when called with no arguments, so 2G rebuilds without a data reload. The star + "k/4" text is removed; the drawing is otherwise unchanged. Re-exported with PAPER_FINAL → `panels/figure2/imp_state_var_combined.pdf` (6.46 × 3.46 cm, same as before).
**Why:** User: Fig 2 is groundwork, so it is reported descriptively; Fig 3 carries the paper's claims. The per-session slope test stays only in stats Table 4, marked as supporting.
**Next:** user re-places 2G in Illustrator.

### 2026-10-16 — Legend still broken in the pull folder: fix had not been mirrored
**Changed/Found:** `paper/figures_final/panels/supp_state_quartile/` — the panels were locked into MANIFEST and mirrored at 11:17. The legend fix was re-exported at 11:21 with PAPER_FINAL off, so only `paper/images/supplementary/state_quartile/` got the fixed legend and the Illustrator pull folder kept the swatch-less copy. Re-ran `imp_state_quartile_supp.m` with `global PAPER_FINAL; PAPER_FINAL = true`. All 13 panels re-mirrored (11:25), and the pull-folder `sq_legend.pdf` was verified by rendering: 12 paths, all 7 colours.
**Why:** User verified in Illustrator (pull folder) that the legend was still text-only. My previous check had rendered the working copy, not the pull-folder copy.
**Next:** Once a panel is in MANIFEST, every re-export must run with PAPER_FINAL on, and the check must be made on the figures_final copy.

### 2026-10-16 — Supp state-quartile legend PDF lost its colour swatches
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m` — `sq_legend.pdf` held only text. legend() fed NaN placeholder lines on an invisible axes drops the swatches from exportgraphics' vector PDF (the PNG looked fine). Legend is now drawn as real line/marker/text objects on a cm-scaled axes with axis off. Also added a black "Mean (stim/control, variance)" item for the ratio and variance tiles. Verified by rendering the PDF (PyMuPDF): 12 vector paths in all 7 colours.
**Why:** User found the legend PDF had no colours in Illustrator.
**Next:** Avoid legend()+NaN+invisible-axes for any standalone legend panel exported as vector PDF; other supp legends may have the same bug (check supp_spatial_cbar-style standalone pieces if they use legend()).

### 2026-10-16 — Fig 2G: per-session quartile ratios replace the bootstrap CI; state-quartile supp figure enters the paper
**Changed/Found:** `paper-writing/paper_stats_table.m` — `2G_*_ratio` / `2G_*_ctrlratio` are now the geometric mean of per-session Q4/Q1 ratios (from `sdRawNs`/`sdPNs`, the drawn curves) with the min–max range; the hierarchical-bootstrap CI is dropped. New rows `2G_*_q4` and `2G_*_beyondctrl` read `sq_stats.csv` (imp_state_quartile_supp). Values: motion 0.58 (0.50–0.81), rel δ 1.03 (0.83–1.16), abs δ 2.35 (1.70–2.71); control 0.60 / 1.08 / 2.70; beyond control 0.92 / 0.95 / 0.95, p = 0.22 / 0.18 / 0.57. `paper_stats_tex.m` — Fig 2G table shows "Ratio (range)" for response and control, and the footnote carries the beyond-control test. Found: the old pooled-trial motion ratio (0.64) did not match the panel's equal-weight session mean (0.58); the δ ratios agreed (2.31 vs 2.35, 1.03 vs 1.03).
**Why:** User: with 4 sessions the CI does not make sense (35 distinct session draws, under-covers); report per-session spreads instead, and cite the existing supplementary state-quartile figure. That figure also tests response against control, so the Results line "we did not compare … statistically" is replaced with the test (weak evidence at n = 4, still worded as an interpretation).
**Next:** user assembles `S_state_quartile.pdf` in Illustrator from `panels/supp_state_quartile/` and uncomments the `\includegraphics`. Supplementary numbering shifted (old S2/S3 → S3/S4). The supp uses Q4 vs mean(Q1–3), while the main text uses Q4/Q1; the captions define both.

### 2026-10-16 — Manuscript: Fig 2G text blended with Figure S2 (Closedloop_edit draft)
**Changed/Found:** `Closedloop_edit/results.tex` — 2G caption points to Figure S2; Results quote the per-session ratios with ranges, add "motion is a step at Q4 (0.57–0.71, lowest in every session)", "abs δ rises quartile to quartile in all four sessions", and the response/control test. `methods_rewrite.tex` — bootstrap paragraph replaced by the per-session GM + range rationale; new "Per-quartile tests" paragraph; the stats-section bootstrap sentence was removed. `supplementary.tex` — new float `fig:state_quartile` (caption only, assembly pending). `stat_tables.tex` regenerated. latexmk builds clean, no undefined refs. Registry row added in PAPER.md; 13 panels added to MANIFEST `[supp_state_quartile]` and mirrored.
**Why:** Same decision as the entry above; the text has to match the new table and cite the supplementary figure.
**Next:** user reviews `git diff main..draft`, then ff main + push on their go.

### 2026-10-16 — Manuscript: Statistical tables section; numbers trimmed from Results (draft b2212d3, not pushed)
**Changed/Found:** `Closedloop_edit`: new `stat_tables.tex` (\input after Methods, booktabs added to main.tex) with Tables 3-7 (trial counts, Fig 2G, Fig 3 A/B, Fig 4D moved out of Methods with gap/gap-trend + motion slopes added, Fig 4G). Results/captions now keep effect + one p and cite the table. Fig 2B caption gives one trials-per-amplitude number per mouse (about 52/52/83/100). Discussion L18 gap-trend p list replaced by a table ref. Methods: \label{sec:stats}, a pointer sentence, and the Corroborating paragraph reduced to pointers. Builds clean (no undefined refs, no overfull boxes); the tables are flushed before the references with \clearpage. Synced first to the user's Overleaf commit ec17cda.
**Why:** User: move numbers out of the text into readable tables in a separate stats section ("clean and readable"), then "i pushed, sync and apply edits".
**Next:** user reviews the rendered tables (paper-writing/stat_tables_preview/), then push draft + ff main on their go.

### 2026-10-16 — paper_stats_tex.m + f2b_trial_counts.m: generated stats tables
**Changed/Found:** new `paper-writing/paper_stats_tex.m` writes `Closedloop_edit/stat_tables.tex` from STATS_TABLE.csv + `data/fig2b_trial_counts.csv`. The counts come from new `impulse-analysis/f2b_trial_counts.m` (needs load_experiments; 21 session x amplitude rows, 1516 trials). The only hand-entered numbers are the Fig 4D trial counts (1670/1190, documented in the code). Formatting: p to 2 significant figures with the trailing zero kept, sci notation below 0.001; log slopes converted to percent; the stored CL-OL gap is shown as OL-CL to match the Methods definition. AL_0048 amplitudes are command V like the others (load_bilateral_impulse reads Timeline volts), so mW = V/3 applies.
**Why:** No hand-typed statistics in the paper; one rerun updates every table.
**Next:** run order after any stats change: paper_stats_table -> paper_stats_tex -> latexmk.

### 2026-10-16 — Manuscript: Fig 3 rewritten to the CL/OL scheme + stats-audit fixes, pushed
**Changed/Found:** `Closedloop_edit` results.tex / methods_rewrite.tex / discussion.tex (draft 746f9b4, main fast-forwarded, both pushed). 3H/3I caption, Results and Methods now use CL/OL ratios, geometric mean [95% CI] and % lower, with the primary session-level LMM; the trial-level LMM and log-ratio Wilcoxon moved to the Corroborating paragraph. Fixed the three wrong p-values (pre 0.85 -> 0.84 LMM; post 0.76 -> 0.48; 0-1 s variance test now the ratio LMM). Full 0-3 s window: effect + 15/15 sessions only, no session-LMM p; the t-test and per-trial LMM p go in Corroborating, and Methods explains why. 4G Methods now leads with logRR~1+(1|sess). Deleted the "same direction in every mouse" promise and the "between-mouse variance negligible" claim. Loop delay: "at most 47 ms, about half that on average" (Results L40, Methods, Discussion; the FILL is removed); Discussion adds the average-latency bandwidth (~4 Hz, tau_eff ~37 ms). Discussion softened the relative 2-4 Hz argument (p=0.044 now "if the trend is real"). Builds clean.
**Why:** User: decisions 2-4 (soften the Discussion; 47 ms worst case and half on average; delete the sentence), then "make all other corrections then we push". On decision 1 the user pointed out that the single-session mice affect every test. The 0-3 s collapse is specific to REML putting nonzero variance on mouse there (it is ~0 in the sub-windows), so the full window is reported without a session-LMM p rather than switching tests.
**Next:** user to confirm the 0-3 s handling. Remaining unsourced numbers (2B slopes, leak %, Discussion MPC R2 0.42/0.10, "44-55%", "seven of 13") are still unchecked.

### 2026-10-16 — Fig 2B caption: explicit trial counts per amplitude
**Changed/Found:** `Closedloop_edit/results.tex` Fig 2B caption — "19--84 trials per amplitude" replaced by the explicit counts, lowest to highest amplitude, from `load_experiments` (allExperiments.groupLabels, non-NaN, nonzero amps): Mouse 5a (AL_0041 e1) 44/49/59/56 = 208; Mouse 5b (AL_0041 e2) 53/58/45/50/54 = 260; Mouse 1 (AL_0033 0129) 84/84/82/85/81/84/82/82/84 = 748; Mouse 3 (AL_0048 0715 R) 100/100/100 = 300; total 1516. The old "19" came from RESEARCH L51's mW binning, which split the 45 trials into 26+19; the panel bins by command voltage. Builds clean; draft commit, not pushed.
**Why:** User: "on trial counts, dont use range, just explicitly state". The caption range contradicted the Methods' "at least 44".
**Next:** Methods L725/L1176 "at least 44" is now consistent and left as is. AL_0041 e1 0.53 mW has 49 usable trials (stim_vars lists 50; one is NaN).


<!-- older entries → RESEARCH_archive_2026H2.md (then RESEARCH_archive_2026H1.md) -->
