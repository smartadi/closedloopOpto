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

### 2026-10-31 — NC Nature-style pass (abstract, intro, Results, legends, Discussion)
**Changed/Found:** `Closedloop_nc` `main.tex`, `introduction.tex`, `results.tex`, `methods.tex`, `discussion.tex`. Abstract rebuilt as a Nature summary paragraph (197 words; Aditya's "Here we show" sentence kept verbatim; three title options in a comment, title unchanged). Intro: open questions as statements ("The first is whether…"), closed-loop literature before the mesoscale gap, tighter "Here we" paragraph. Results: two subheadings shortened, finding-first openers, power-measure rationale moved to the closed-loop state section, Fig 4c unique-R² values moved from the legend into the text, legend titles state findings, Fig 4 legend 434 → 342 words, leftover uppercase panel refs fixed (Fig 3 legend "a–d", "h"; Fig 5 "b"). Impulse-fit robustness details (model orders, two-pole check, mode overlap, order dependence of the dip τ, bootstrap fractions) moved to Methods, Transfer-function fitting; the "<30 trials" check moved from the Fig 4 legend to Methods. Discussion: light pass, claim order unchanged. Aditya's Overleaf heading edit ("The feedback tracking performance depends on brain state", pulled as 365b79f) kept verbatim. Main text 7,815 → 7,255 words; Methods 7,277 → 7,431. A script check found no number, citation or \ref lost (one new number: 0.04 s, the order dependence of the dip τ). Build clean, 44 pp. NC f0e01d7, 60cf0ee, 5a955c7, local, not pushed.
**Why:** Aditya, 2026-10-31: "we dont want to emulate Nick but we want to use it as advice and write in more of a nature paper"; he edits after this pass. New style guide `paper-writing/STYLE_NATURE.md`; `STYLE_NICK.md` is now marked as advice.
**Next:** Aditya's edit, then push to the NC Overleaf on his OK. Reaching ~5,000 words needs content cuts, not style: candidates are the time-constant paragraph and the best-fixed-input analysis (to Supplementary) and the Discussion's state-aware-control and forecasting paragraphs (to a sentence each). Methods (7.4k vs ~3k) needs a Supplementary Methods split.

### 2026-10-30 — NC Fig 5 rebuilt from the 10-28 panels; NC figures pushed
**Changed/Found:** `paper/figures_final/nc/Figure5.ai` — replaced the 9 embedded panels (b–f, h–k, still on the pre-10-28 signal) with links to the 10-28 files in `panels/figure5/` (rig's online ΔF/F), each at the old panel's top-left corner (e and f moved down 0.18 and 0.33 mm to stay on the artboard). Sizes changed by −0.35 to −0.18 mm, except f (+1.09 mm tall) and h (−1.06 mm wide). Moved letter e 2.6 mm left: the lowercase e sat on panel e's y-label (a close-up of all 68 letters found no other collision). Panel h now shows 71°/46° (OL/CL) and 16°/2° with preview, as `results.tex` says; the old embedded h showed about 60/37/5/−8°. NC f4c096e, build clean (44 pp); pushed 1721b39..f4c096e together with 42799f8.
**Why:** The text moved to the rig signal on 10-28 (98aebf1), but the assembly kept its embedded pre-10-28 panels; linked panels make the next rebuild reach the figure.
**Next:** Aditya pulls GitHub into the NC Overleaf. JN Fig 5 needs the same rebuild (TASKS); `nc/Figure5.ai` can be its template with uppercase letters.

### 2026-10-30 — Found: Fig 2, Fig 5, S1 and S3 in both drafts were exported before their locked panels; S1.ai is stale
**Changed/Found:** Opening the assemblies refreshes linked panels from disk (all links point to `figures_final/panels/`, all MANIFEST-listed except the superseded Fig 2a/2d files), so the NC re-export showed that both drafts carry old exports (the 10 old NC images were byte-identical to JN's). Fig 2: session labels Mouse 1/3 → 1b/3c (draft has the 10-16 export, `figures_final/Figure2.pdf` is 10-20). Fig 5g (rebuilt 10-28 with the rig-signal text, 98aebf1). S1 c–d (rebuilt 10-27; d's pre/post slopes −0.21/+0.21 → −0.10/+0.30, not quoted in the text). S3 b–d (rebuilt 10-11; caption quotes no numbers). Fig 5's other 9 panels were also rebuilt 10-28 but are embedded, so NC Fig 5 now has a new g next to old b–f, h–k. `figures_final/S1.ai` (saved 10-05 15:38) lacks panels c–d that its 16:21 PDF has; `nc/S1.ai` holds the full version. Fig 2a/2d still link the superseded `imp_single_AL_0041…` and `tf_cv_2D_sidebar`.
**Why:** The assemblies were exported before their panels were rebuilt and never re-exported; Illustrator updates links silently on open.
**Next:** NC: rebuild Fig 5 from the 10-28 panels; re-assemble Fig 2a/2d (D3). JN: re-export Fig 2, 5, S1, S3 (check the JN Overleaf copy first); save S1.ai from its PDF so c–d are not lost.

### 2026-10-30 — NC Fig 4d relinked to the OL slope / CL slope / CL/OL panel
**Changed/Found:** `paper/figures_final/nc/Figure4.ai` — panel d is a linked placed item; relinked from `panels/figure4/f4_row2_quartiles.pdf` to `f4_row2_quartiles_nc.pdf` (same 165.8 × 33.9 mm page, bounds unchanged to 0.000 mm). Render diff against the old Figure 4: only the panel-d label row and the panel letters changed.
**Why:** NC dropped predictability / regularizability / attenuation (2026-10-30), and its caption already describes the new labels.
**Next:** none.

### 2026-10-30 — NC figure assemblies with lowercase panel letters (Figs 2–6, S1–S3, OLbest, S_varx)
**Changed/Found:** new `paper/figures_final/nc/{Figure2..6,S1,S2,S3,OLbest,S_varx}.ai/.pdf`, made by scripted Illustrator (COM + ExtendScript) from the Illustrator data inside the PDFs the NC draft used; Fig 2 from the 10-20 export `figures_final/Figure2.pdf`, which has the 10-19 session labels. 68 panel letters (10 pt Arial Bold point text) set lowercase with Change Case; no other edits. Exported with `[Illustrator Default]` (no downsampling: the Fig 5a schematic is now 636 ppi, was 300). Copied into NC `images/` with `sync_figs.ps1 -Apply` (NC 42799f8, not pushed); build clean, 44 pp, main.pdf 16.2 → 13.0 MB. Widths stay 176 mm, inside NC's 180 mm column. JN `.ai` files untouched.
**Why:** Nature Comms labels panels with lowercase bold letters, and the NC text already cites "Fig. 2a".
**Next:** Push NC on Aditya's OK. Fig 1 and S_impulse_state were already NC builds.

### 2026-10-30 — NC: merged Overleaf's one edit (abstract sentence 3) into main
**Changed/Found:** `Closedloop_nc/main.tex` — Overleaf could not sync: the NC Overleaf project had never pulled from GitHub since the fork (98aebf1) and held one edit of its own, abstract sentence 3 ("in real time toward a target level, using feedback from the ongoing dynamics"), which the Nick-style abstract (660d8fd) had also rewritten. Overleaf pushed it to branch `overleaf-2026-10-31-0207` (262b9ce). Merged into main keeping Overleaf's sentence and the rest of the rewrite (NC 1721b39, pushed 99985e2..1721b39). Abstract now 200 words (limit 200); build clean, 44 pages.
**Why:** The Overleaf sentence is Aditya's own edit; a merge must never overwrite his text.
**Next:** Aditya pulls GitHub into the NC Overleaf; the pull brings all 17 NC commits since the 10-29 fork, not just today's. The `overleaf-2026-10-31-0207` branch on GitHub can be deleted.

### 2026-10-30 — NC: Fig 4d state result restated as OL slope, CL slope, CL/OL ratio and controllability
**Changed/Found:** NC `results.tex` (state section; Fig 4 caption d), `methods.tex` (State dependence; Multiple comparisons) and `stat_tables.tex` (Supplementary Table rows and caption, through new rule 6 in `paper-writing/nc_style.py`, so a regenerated table keeps the plain names). Predictability / regularizability / attenuation no longer appear anywhere in NC. Results now defines controllability from the combination: a positive OL slope = the state brings larger disturbances; a flat or negative CL slope = feedback corrected them (more controllable); the CL/OL ratio tests between the cases. Only movement met it (OL +0.24 %ΔF/F per SD, p = 0.011; CL −0.06, p = 0.16; ratio −13%/SD, p = 0.0023, Holm 0.009, 11/11); abs 1–4 Hz limited control (OL +0.28, CL +0.32 similar, ratio +7%/SD, p = 0.094). Rel 2–4 Hz now says its effects fail Holm (0.14, 0.087). Methods gives z, A = log-slope difference, 100(e^Ā − 1) with its CI (matches `utils/f4_row2_sess.m`), says "controllable" is empirical, not state-space controllability, and fixes the old claim that every slope is in %ΔF/F (the ratio is not). No numbers changed; NC builds, 44 pp (NC 99985e2, pushed with the rest of the rewrite).
**Why:** Aditya, 2026-10-30: use OL slope, CL slope and the OL/CL ratio instead of the three coined names, and make the controllability claim from their combination ("if OL slope increases we get more disturbances but CL stays flat or decreases we have higher degree of controllability"). Kept the ratio as CL/OL (the fraction of error left), so every number and sign stays as in STATS_TABLE.
**Next:** NC Figure 4 still shows P/R/A until panel d is relinked to `f4_row2_quartiles_nc.pdf` in an NC Illustrator assembly. JN keeps the old names until ported.

### 2026-10-30 — Fig 4d: NC panel variant with plain names (OL slope, CL slope, CL/OL)
**Changed/Found:** `controller-analysis/f4_row2_quartiles.m` — new stitched view `session_nc` → `f4_row2_quartiles_nc.pdf`: same session-level data and stars as `f4_row2_quartiles.pdf`, but every tile reads "OL slope / CL slope / CL/OL" instead of Predictability/Regularizability/Attenuation (P/R/A), and each arrow is the SIGN of its slope (up = increases with the state), not the old "direction of improvement" (P up iff OL slope < 0 etc.). `draw_panel` takes an optional `labs`; `PQ` stashes the slope signs (`olPos/clPos/ratioPos`). Added to `figures_final/MANIFEST.txt` [figure4]. The JN panel is unchanged.
**Why:** Aditya, 2026-10-30: drop the three coined names from the NC text and figures and state controllability from the combination of the OL slope, CL slope and CL/OL ratio. With plain names the old arrows would read backwards (motion's positive OL slope was drawn as a down arrow). NC and JN share the assembled Figure 4, so the change is a separate panel file rather than an edit of the shared one.
**Next:** In Illustrator, make an NC copy of `FIgure4.ai` (e.g. `figures_final/nc/fig4/`), relink panel d to `panels/figure4/f4_row2_quartiles_nc.pdf`, export, then `sync_figs.ps1 -Apply` in Closedloop_nc. When JN drops P/R/A too, retire the old panel and this view.

### 2026-10-30 — STYLE_NICK.md: measured style sheet from Nick's three papers
**Changed/Found:** new `paper-writing/STYLE_NICK.md` — rules (tense, literal verbs, cut decorative clauses, "target level", hedge interpretations, paragraph openers, state claims on the robust test) and structure of his abstracts, intros and discussions, from Steinmetz 2019 Nature, Zatka-Haas/Steinmetz 2021 eLife and Steinmetz 2021 Science (`nick papers/`, untracked). Measured per 1000 words, Nick vs NC before → after: motion verbs (grew/fell/stayed/leaves) 0.1 vs 5.9 → 1.6; increase/decrease/correlate 4.9 vs 1.5 → 6.7; metaphorical verbs 1.3 vs 5.7 → 1.4; hedges 3.2 vs 1.4 → 2.9; "we" + past verb 83% vs 59% → 69%. Sentence length was the same throughout (~28 words), so it was never the issue.
**Why:** Nick's N2 asked for a rewrite in the voice of his older papers; Aditya supplied the papers (2026-10-30).
**Next:** Apply to JN after Overleaf is synced to GitHub; Nick reviews diffs, not rewrites.

### 2026-10-30 — NC claim 2 restated on the Holm-robust tests (my rewrite had weakened it)
**Changed/Found:** NC `main.tex`, `introduction.tex`, `results.tex`, `discussion.tex` (NC 3da79c0). The rewrite had phrased the state result as "open-loop error increased with movement; under feedback it no longer did". From `STATS_TABLE.csv`: OL motion slope +0.24 [0.07, 0.41], p = 0.011, **Holm 0.069**; CL motion slope −0.06 [−0.14, 0.03], p = 0.16 (a null). The robust tests are motion attenuation −0.14 log ratio/SD [−0.21, −0.06], p = 0.0023, Holm 0.009, 11/11 sessions, 4/4 mice; and the CL slope on abs 1–4 Hz +0.32 [0.16, 0.48], p = 0.0007, Holm 0.0057, 15/15, 4/4. All four places now say: feedback removed a larger fraction of the error as movement increased, but closed-loop error increased with 1–4 Hz power. Results says "the closed-loop slope was not significant (p = 0.16)" instead of "did not". Abstract now 194 words.
**Why:** Aditya asked whether the stats reporting is good; the headline claim should rest on the tests that survive correction, as the pre-rewrite NC abstract did.
**Next:** Other stats suggestions are for Aditya to decide (CIs in text, Fig 4g mouse-level CI and 13-session sensitivity, relative-power effects that fail Holm, linearity slope CIs).

### 2026-10-30 — NC Methods pass: target level, past tense, plainer wording
**Changed/Found:** NC `methods.tex` (NC 87839cd), 96 lines reworded, no number or equation changed. "Target level" in prose; `y_ref` defined once as "the reference, in control terms" (L128); "constant offset" for "standing offset"; jargon replaced or glossed: "fed back on" → "used for feedback", "persistent excitation and subspace identification" → "the long, varied input sequences that standard system identification requires (…)", "zeroth-order search" → "random search that used only measured costs", "actuator" → "laser"/"command", "clamped" → "limited", "leak" glossed once. Clarified which VARX is which in the MPC replay (the MPC's own model fitted without closed-loop trials; the replay model fitted to the whole session). Methods text is 7,250 words (Nat Comms guide < 3,000).
**Why:** Aditya, 2026-10-30: "take a pass at methods too … less jargony and to the point".
**Next:** Cutting Methods toward 3,000 words means moving detail to the Supplement; Aditya to decide.

### 2026-10-30 — Bug: NC Discussion bandwidth used the old 47 ms loop latency
**Changed/Found:** NC `discussion.tex` (NC acbbc90) — the feedback-bandwidth sentence still said "loop delay at most 47 ms and about half that on average", giving an effective delay of 37–61 ms and a bandwidth of about 2.6–4 Hz. Fig 1c, Results and Methods L101 use the whole-session measurement (Mouse 4, n = 3539): median 24.0 ms, max 43.5 ms. Recomputed: effective delay = loop delay + 14 ms (half of one 28.6 ms frame) = 38–58 ms; crossover f ≤ 1/(2πτ) = 2.8–4.2 Hz. Now "about 2.8–4.2 Hz".
**Why:** The earlier fix to the same stale latency (Results L39, 2026-10-30) missed the Discussion.
**Next:** JN has the same sentence; port with D8.

### 2026-10-30 — NC Discussion reordered by claim and restyled
**Changed/Found:** NC `discussion.tex` (NC acbbc90) — new order: summary of the three claims → a model of the average response was enough (design, stationarity assumption, PI needs only the sign, earlier controllers) → the error left by feedback depends on state, consistent with the internal model principle (offset removed, fluctuations less; movement corrected, 1–4 Hz not; delay and saturation; what counts as state; which states suit a fixed linear controller; state-aware controllers) → part of the remaining error was predictable (MPC replay, forecast limits, ML forecasting models moved here from the cut intro paragraph) → limitations → procedure and use. All citations from the old intro and Discussion survive (checked by key). Plain wording: "plant" → "system being controlled", "clamp" dropped, "report the drive" → "reflect the input that the loop counteracts"; Aditya's garbled "extension to wide bran activity" sentence rewritten as "controlling activity over a wider area remains for future work". 1,775 → 1,927 words.
**Why:** Aditya approved "reorder by claims" (2026-10-30); Nick's style; less jargon.
**Next:** Main text is 7,799 words against Nat Comms ~5,000; reaching it needs material moved to Methods/Supplement (Aditya to decide).

### 2026-10-30 — NC Results restyled (Nick's style, target level, internal model principle)
**Changed/Found:** NC `results.tex` (NC 8249e7c) — dropped the 3-sentence overview before the first heading; past tense for what we did and saw; literal verbs (increased/decreased for grew/rose/fell; remained for stayed; "contained" for "carried"; "did not use the laser command" for "blind to the laser"); "target level" in all Results prose and Fig 1–6 captions (no "reference" left); "constant offset" for "standing offset"; "plant" removed. Headings: Fig 3 "tracks the target level more accurately than open-loop stimulation", Fig 4 "The error left by feedback depends on brain state", Fig 5 "Preview of a time-varying target level corrects the lag…", Fig 6 "In simulation, predicting the disturbance lowers the error left by feedback". The state section opens with the internal model principle and closes on why movement and 1–4 Hz power differ (hedged, pointing to the Discussion). The disturbance section adds "feedback removed most of the constant offset but a smaller part of the fluctuations" (offset share 35% → 7%, fluctuation energy 0.66 → 0.54). MPC: VARX R² at 200 ms stated (0.41 full, 0.37 site + laser, 0.10 naive, from Supp Fig varx e); the last sentence gives 40% (model) and about 80% (perfect prediction), from 1.46 → 0.88 → 0.27. Found: the old MPC summary said variance fell only in the sine replay, but the static replay reports −37%; now "both replays". No number changed.
**Why:** Aditya, 2026-10-30: NC in Nick's style around the bold points; less jargon, to the point.
**Next:** "Slow-moving" (bold point 3) is not supported: the naive forecast R² is only 0.10 at 200 ms, so the text says "predictable" instead. Fig 4d's P/R/A names (predictability, regularizability, attenuation) are still jargon; renaming needs the figure (F4.3).

### 2026-10-30 — SfN poster restyled to SfN template 3 + UW theme; state-dependence title
**Changed/Found:** `poster/sfn2026/poster.tex` (commit e3e8335) — layout now follows SfN example poster 3: header with two QR slots on the left and the poster number plus `talk/mousy.png` on the right; Introduction / Results / Conclusions section bars; result boxes with a square number badge. UW Husky Purple #4B2E83 and Husky Gold #B7A57A, Open Sans. Title is now "Brain state shapes how well feedback controls mesoscale cortical activity". Box 4 is retitled "Controller performance is brain-state dependent", with separate movement and slow-δ bullets. Methods moved into the Conclusions box. To fit the page, Fig 1 is drawn at 0.74 of the column width. mousy.png is 330 dpi, so its trim is in bp of an 180 bp image (the first trim was in px and blew up the header).
**Why:** User asked for template 3 with a UW theme and a title about the controller's state dependence.
**Next:** User picks a final title from the options. Fill the [FILL] items. A real poster number is shorter than the placeholder, which currently overlaps the top edge.

### 2026-10-30 — NC intro restructured: model survey cut (N1), internal model principle stated
**Changed/Found:** NC `introduction.tex` (NC ff2391e) — P2 (models of variability: switching LDS, LFADS, NDT, CEBRA, foundation models, POYO, POSSM, lu2025) cut; its point (feedback needs no model of what caused a deviation) closes P1. P1 reuses Nick's JN edits (mediate, input pattern chosen in advance, whisking/fidgeting, synchronized vs desynchronized). The third question now asks which fluctuations a linear controller leaves and whether they are predictable, stating the internal model principle (francis1976internal: PI contains a model of a constant, rejects offsets and slow drifts). The summary is split into setup and findings; findings in past tense, conclusions in present; the "procedure" sentences moved out (they stay in the Discussion). "Target level" replaces "reference".
**Why:** Aditya, 2026-10-30: rewrite NC in Nick's style around the three bold points; approved cutting the model survey (Nick's N1 on JN) and the five-paragraph outline.
**Next:** The ML forecasting citations (pandarinath, ye2021ndt, schneider2023cebra, wang2025foundation, azabou2023poyo, ryoo2025possm) now appear only if the Discussion's claim-3 block cites them; check after the Discussion rewrite.

### 2026-10-30 — NC abstract rewritten in Nick's style (claims 1–2 only, 199 words)
**Changed/Found:** NC `main.tex` abstract (NC 660d8fd) — 253 → 199 words (Nat Comms limit 200). Past tense for our results, "target level" for "reference", literal verbs ("increased" for "grows", "steered" for "holds"). Kept Nick's JN sentences (design: fluorescence in, laser out) where they fit. Added that single trials varied with state while the average was linear (claim 1's "despite"). State result stated as: open-loop error increased with movement and 1–4 Hz power; under feedback, no longer with movement but still with 1–4 Hz. Cut the disturbance, preview and MPC sentences.
**Why:** Aditya's bold points 1–2; MPC cut from the abstract "for now" (Aditya, 2026-10-30, after Nick's N6 on JN). Style from Nick's three papers (`nick papers/`): past tense for what we did, present for general conclusions, no metaphorical verbs.
**Next:** Revisit the MPC sentence if Aditya wants claim 3 back in the abstract.

### 2026-10-30 — Third bold point (MPC) added to PAPER.md
**Changed/Found:** `PAPER.md` "Bold points" — new third point, Aditya's words verbatim: much of the variability the linear feedback leaves behind is a predictable, slow-moving disturbance, as the MPC stimulation shows.
**Why:** Aditya asked for one more note, on MPC (Fig 6).
**Next:** Check that the Fig 6 Results text and the Discussion make this point in both drafts (JN and NC).

### 2026-10-30 — Aditya's "bold points" (headline claims) recorded in PAPER.md
**Changed/Found:** `PAPER.md` — new "Bold points" section at the top, Aditya's words verbatim: (1) despite variable brain states and non-linear dynamics, an LTI model plus a linear feedback controller tracks the target and cuts trial-to-trial variability; (2) via the internal model principle, tracking capacity reports brain state (motion, synchrony), which says which states suit precise control. `paper-writing/CLAUDE.md` start-of-session reading list now points to it.
**Why:** Aditya asked for a note of the paper's bold points; manuscript sessions should write toward them.
**Next:** The third sub-point under (2) is still blank for Aditya to fill. Check the abstract, significance and intro (JN and NC) state both points.

### 2026-10-30 — Nick's Overleaf review exported to a handoff file; reusable comment exporter added
**Changed/Found:** Added `paper-writing/overleaf_comments_export.js`, a console snippet that exports an Overleaf project's comment threads and tracked changes to Markdown, using the editor's own read-only endpoints (`/threads`, `/ranges`, doc download). Added `paper-writing/REVIEW_NICK_2026-10-30.md`. On JN Overleaf (Closedloop_edit), Nick left 10 comments (abstract, significance, intro L10) and 106 tracked changes (main.tex L91–109, intro L3–8). All are logged verbatim there, with diagnoses, 8 problems in the tracked edits (E1–E8) and draft abstract (249 words) and significance (116 words). Found: Overleaf is ahead of GitHub. `main.tex`, `introduction.tex` and `results.tex` differ: Nick's tracked changes, plus untracked edits (title, author line, `results.tex` L12–14 and L202 by Aditya at 18:21–18:27 UTC). In Nick's edits, "compensated for system delays" is wrong: 71° of lag at 1 Hz is about 200 ms, against 24 ms of loop latency. "State during the stimulation" contradicts the locked −2 to +3 s window. The older `Closedloop` project holds 49 earlier Nick threads (2025-11 to 2026-04), not exported.
**Why:** Aditya asked how to export Nick's comments and for help addressing them. Overleaf's GitHub sync carries no comments, so they had to come from the editor's endpoints.
**Next:** Aditya decides N1 (intro modelling paragraph: cut, or move to the Discussion), N2 (which of Nick's papers to use as the style model) and N3 ("target level" everywhere?). Then work the abstract and significance drafts one item at a time on Overleaf. Push Overleaf to GitHub before any local JN edit.

### 2026-10-30 — Bug: NC Results L39 still quoted the old 200-cycle latency ("at most 47 ms and about half that on average")
**Changed/Found:** Found during the G4 sweep. NC `results.tex` L39 is now two sentences: software computes the error and, from it, the stimulus on every frame; "The stimulus follows the camera exposure by a median of 24 ms and at most 43.5 ms (Fig. 1c,d)". It cited Fig 1c,e; e is the block diagram, so it now cites c,d.
**Why:** D8 replaced Fig 1c, its caption and Methods with the whole-session measurement (Mouse 4, n = 3539), but missed this Results sentence, so the text and figure disagreed.
**Next:** Grep JN for "47" when porting D8.

### 2026-10-30 — F2.7a: relative vs absolute 2–4 Hz power text applied to NC (Results, Fig 2g caption, Methods, 5 references)
**Changed/Found:** Applied `paper-writing/relative_vs_absolute_power.md` §6 to NC.
- **Results state paragraph:** one ~70-word sentence became five. Two refs say why low-frequency power indexes state (Crochet/Poulet/Vinck) and that wide-field imaging resolves it (Vanni 2017, Jacobs 2020). Absolute = band power, ρ = 0.97 with total power. Relative = share of 0.4–10 Hz, ρ = 0.24. It cites Supplementary Fig. 2a–c, so that supplement is now cited.
- **δ removed:** from Results L92–101 and caption g. Caption g's "state ." is fixed, and its dashed line is now "stimulus-free control" (was "no stimulus trials").
- **Methods L479–482:** replaced; it drops "the sub-band least attenuated by the controller", which is outcome-informed and wrong (review M19).
- **Methods:** new "Bands" paragraph.
- **refs.bib:** +Jacobs2020, Vanni2017, Donoghue2020eNeuro, Ma2016, Wright2017, copied from the checked list in the md §7.

**Why:** Anna F2.7 ("why del? … what is relative vs absolute supposed to be"), Aditya 2026-10-29 (be clear on the difference and cite why these bands), and the G4 sweep (Results L86 was one of the flagged paragraph-sentences).
**Next:** Fig 4 panels still say "abs δ" (F4.3). JN not ported. Results is +162 words.

### 2026-10-30 — G4: "slop" sweep of the NC Results through Fig 4 and captions
**Changed/Found:** NC `results.tex`, applying the tracker's cross-cutting list:
- **Definitions wedged in as asides, now their own sentences or reworded:**
  - initial deviation (L136);
  - best fixed input (L141, now three sentences);
  - attenuation (L201, now "We therefore also divided closed-loop by open-loop error, which gives the fraction of error left under feedback. The slope of this error ratio with the state measures attenuation");
  - Global/Local (L222);
  - RR (L227).
- **Dip/rebound paragraph (L79–82):** one claim per sentence. It explains poles in plain words ("Each fitted model describes the response as a sum of modes. Each mode decays with its own time constant, set by one of the model's poles"). This answers Anna's "what is a pole" without deciding D5.
- **Split "…, so …; …" chains:** L91, L94, L95, L98, L153, L154, L190, L202, L207, L208, L209, L212, and the Fig 4d caption.
- **Grammar:**
  - L151 "we observe the drop … holds showing its not a session specific effect";
  - L154 "and the controller treats them as disturbance".
- **"Significantly reduced" (L150)** became "fell much more": no test sits behind that single-session claim.
- **Small fixes:**
  - L77 reworded ("The dynamics were similar enough across sessions that the gains carried over…");
  - Fig 2f caption: "filled markers", not "solids";
  - Fig 3d caption: "Panels d and e".
- **"Plant":** now defined in its own sentence after L42 ("It acts on the cortical response to light, which control theory calls the plant.").

**Why:** Anna G4 / "you gotta fix the claude slop": the tracker's cross-cutting patterns 1–3 and 5. Numbers are unchanged; only sentence structure changed.
**Next:** Aditya reads the diff (NC local, unpushed). Still open: D5 (Fig 2e/f in place or supplement) and the JN port.

### 2026-10-30 — G4: "slop" sweep of the NC intro
**Changed/Found:** NC `introduction.tex`:
- **ML-limits sentence (L14)** is three sentences ("two limits. First, … Second, …").
- **Bolus:** the "plant" aside is gone ("fitted a model of how light drives thalamic firing and designed controllers from it"). L39 "stable linear plant" became "stable linear system", because plant is now defined in Results.
- **Rig sentence:** split in two.
- **Latency aside:** "The latency, the delay from a camera exposure to the light it triggers, has a median of 24 ms" became "The light follows each camera exposure by a median of 24 ms".
- **"…, and …, so …" chains split:** the opsin sentence, the characterize/built sentence, the linear-model sentence, and the 1–4 Hz/movement sentence (L53, flagged).

**Why:** Anna G4, patterns 1 and 3. The latency and rig sentences were Aditya-approved wording (2026-10-21) moved by D7; only their structure changed.
**Next:** Aditya to read it. JN not ported.

### 2026-10-30 — SfN 2026 poster draft (Figs 1–5) in LaTeX
**Changed/Found:** new `poster/sfn2026/poster.tex` — 60×40 in landscape, 3 columns, assembled vector Figs 1–5 with claim headlines and numbers from JN `results.tex`. Fig 1 is read from `Closedloop_nc/images/Figure1.pdf` by full path because `paper/figures_final/Figure1.pdf` is in fact a stale Fig-2 assembly (Mouse 1 / M1 labels, stars in G). Fig 2 is the 10-20 assembly, so it predates today's A = Mouse 1b / D = held-out-R² swap.
**Why:** SfN Neuroscience 2026 (DC, Nov 14–18); board is 6×4 ft, so 60×40 leaves a pin margin and prints on a 42 in roll. A virtual PDF is required, and it must name the funding sources. Fig 6 (MPC) is left out by request.
**Next:** fill the [FILL] items (title vs abstract title, departments, poster number, funding, QR, logo); re-run once Fig 2 is reassembled; consider 70×46 in if figure text (~14 pt) reads too small.

### 2026-10-30 — T8: NC Fig 2 section now says the impulses were open loop; caption a rewritten for Mouse 1b
**Changed/Found:** NC `results.tex`: heading "Under open-loop stimulation, trial-averaged cortical dynamics are well approximated by a linear system"; the first sentence says we "first stimulated open loop, without feedback", with amplitudes "fixed in advance". Fig 2a: "five of these amplitudes" (was three). Caption a: Mouse 1b (the session in c), five of ten amplitudes, 0–1.43 mW, and "Red trace, laser command, a single pulse at t = 0" in place of the red dot (F2.2).
**Why:** Anna T8/F2.1: the reader has just seen the closed-loop rig, so the impulse experiment must say it is open loop. Caption a follows D3 and the laser-row panel.
**Next:** Caption b still says "versus stimulation amplitude"; switch it to "laser power" when F2.3 is approved. JN not ported.

### 2026-10-30 — T7: opsin wording fixed in the NC intro and Results
**Changed/Found:** NC intro last paragraph: "The light excites inhibitory interneurons that express the opsin ChrimsonR, and these suppress the excitatory neurons whose activity we image, so the light can push the readout only below baseline" (was "excites inhibitory neurons that express an opsin, so it can only lower the activity"). Results L18: mice "expressed GCaMP8s in excitatory cortical neurons and the opsin ChrimsonR in inhibitory interneurons" (was "co-expressing GCaMP and an inhibitory opsin", which is wrong twice: ChrimsonR is excitatory, and the two are in different cells). Facts from Methods L21–23. NC has no significance statement, so the third place in the tracker does not apply.
**Why:** Anna T7: "this is not precisely true". The light raises interneuron activity; only the imaged excitatory signal goes down, and it rebounds after the dip.
**Next:** JN has the same errors in three places (intro, Results L18, significance); port.

### 2026-10-30 — T4: NC intro Bolus sentence split in two
**Changed/Found:** NC intro P4: "\citet{bolus2018design, bolus2021state} fitted a model of how light drives thalamic firing, the plant that a controller acts on, and designed controllers from it. These controllers made the firing track time-varying targets and reject unmeasured disturbances, and changed its trial-to-trial variability." The short "plant" definition stays because the intro (L39), Results and Discussion use the word later.
**Why:** Anna T4: "five clauses!!!".
**Next:** JN not ported.

### 2026-10-30 — T3/T5: NC intro P1 ends on one bridge to variability; P2 separates unobserved drivers from short forecasts
**Changed/Found:** NC intro P1 now ends: drivers include known states, unobserved states, unmeasured stimuli and input from other regions; "These drivers change from moment to moment, so the same stimulus meets a different circuit on each trial, and its response varies from trial to trial." P2 opens "One way to handle this variability is to model it, so that the factors that contribute to it can be identified. Several such approaches describe activity as a dynamical system." The old L12 is two sentences: these models do not observe movements and input from other areas; separately, "from its own past alone, spontaneous wide-field activity is forecast informatively for only about 1.5 s, even by the best current models" (lu2025benchmarking). Dropped "with considerable amount of uncertainty": the 1.5 s horizon already says that forecasts stop being informative.
**Why:** Anna T3 (abrupt jump from state to variability, then back to spontaneous states) and T5 (unmodelled inputs read as the cause of the 1.5 s limit; Ziyu's benchmark uses no inputs). Also fixes "In literature", "through a dynamical systems" and a double space.
**Next:** Aditya to read the new P1 ending; it replaces his Overleaf wording. JN not ported.

### 2026-10-30 — D3: Fig 2a and 2d locked in the final panel folder (MANIFEST)
**Changed/Found:** `paper/figures_final/MANIFEST.txt` [figure2]: A → `imp_single_AL_0033_2025-01-29_en1.pdf` (Mouse 1b), D → `tf_cv_heldout_r2.pdf`; comments fixed (the old 2A comment said "Mouse 1b" for the 5b file, X2.1). Ran `trace_overlay` and `imp_tf_cv` (`CV_REUSE`) with `PAPER_FINAL` on: panels/figure2 now has both new files (A 3.17 × 3.21 cm, D 3.56 × 3.28 cm) and a refreshed C. Did NOT run `collect_final_panels`, so the superseded `imp_single_AL_0041_2025-12-02_en2.pdf` and `tf_cv_2D_sidebar.pdf` stay on disk.
**Why:** Aditya chose Mouse 1b for both A and C, and decided D4 (D = held-out R² only). The JN assembly still links the old files, so pruning waits for the JN port.
**Next:** Re-assemble NC Figure 2 from panels/figure2 (A, D new). 2B and 2G still wait on approval before their `PAPER_FINAL` run. Prune with `collect_final_panels` once JN is ported.

### 2026-10-30 — D3: Fig 2a now draws Mouse 1b by default, legend in the bottom-right corner
**Changed/Found:** `impulse-analysis/trace_overlay.m`: `TO_EXP` default 2 → 3 (AL_0033 2025-01-29 e1, Mouse 1b, the session of Fig 2c). Mouse 1b draws five amplitudes (0, 0.37, 0.70, 1.07, 1.43 mW), and the five-row legend at the old bottom-left spot sat on the scale bars, so it now parks bottom-right, below the rebound, at `[1 - w - 0.01, 0.075]`. Re-rendered `paper/images/figure2/imp_single_AL_0033_2025-01-29_en1.pdf`.
**Why:** Aditya, D3: "Mouse 1b for both". 1b has ten graded amplitudes; 5b has two near-equal ones (0.87/0.90 mW) whose responses come out of order in c.
**Next:** none (locked in the next entry).

### 2026-10-30 — D6 (Fig 4e): kept the dense ridge map; the sparse "spot" version exists in ctrl_ols_spont.m
**Changed/Found:** Nothing changed. Aditya: Fig 4e answers a different question from the map Anna expected (one hotspot at the mirror spot), so it does not need to be sparse. The sparse version exists: `controller-analysis/ctrl_ols_spont.m` with `fit_mode = 'lasso'` (`l1_frac` 0.1, debiased) gave 51 of 427 active contra pixels, held-out R² 0.675 against 0.874 dense, and the top-10 weight centroid sat 12 px from the laser site's mirror across the midline (RESEARCH_archive_2026H2, 2026-07-19).
**Why:** Anna F4.2 ("are you sure about this? it looks bugged"). The dense weights cancel each other out (Haufe et al. 2014; RESEARCH 2026-10-29), but the panel is not meant as a hotspot map.
**Next:** If a referee asks Anna's question, show the lasso map (or a forward pattern). The caption should still not read the weights as "where the information is".

### 2026-10-30 — D8: NC Fig 1c is now the whole-session controller latency (Mouse 4, n = 3539, median 24 ms)
**Changed/Found:** `controller-analysis/ctrl_latency.m` gets a `[LAT-NC]` block that writes `paper/figures_final/nc/fig1/panel_c_latency.pdf` from the closed-loop updates of AL_0051 2026-07-29/2: n = 3539, median 24.0 ms, 99th percentile 40.0 ms, maximum 43.5 ms, 12.6 % after the next blue frame (28.5 ms, drawn as a dotted "Next frame" line). The panel is 5.4 × 4.4 cm, 7 pt, with 1 ms bins on a linear y-axis; `LAT_NC_YSCALE = 'log'` shows the tail better but reads worse. `latencyAnalysis.m`'s NC block (175-cycle test recording, median 29 ms) is removed, so it can no longer overwrite the panel; the JN print is unchanged. Rebuilt `fig1_nc_build.py` and copied the result to NC `images/Figure1.pdf`. NC caption c and Methods L100–101 now describe this one measurement (the "200 loop cycles" claim is gone).
**Why:** Aditya, D8: "controller latency". Fig 1c, the 24 ms bracket in d and Methods now quote the same session.
**Next:** JN still says 200 cycles; port when JN gets its Anna pass.

### 2026-10-30 — D7: NC intro P2 drops the rig specs; they move to the last intro paragraph
**Changed/Found:** NC `introduction.tex`. P2 lines "We read it out as fluorescence across a field about 10 mm wide" and the 35 Hz / 24 ms latency / 0.11 s sentence are replaced by one general sentence: wide-field calcium imaging records mesoscale activity across the dorsal cortex at once (Wekselblatt et al. 2016), and a controller can update its input on every frame. The last paragraph now says "a field about 10 mm wide, at 35 Hz", followed by the latency sentence in Aditya's approved wording.
**Why:** Anna T6: the specs are our system's, not properties of mesoscale imaging. Aditya: "do it".
**Next:** Check the new P2 sentence in Overleaf. JN unchanged.

### 2026-10-30 — D4: Fig 2d is the held-out R² panel alone; NC caption c/d say what each tests
**Changed/Found:** `impulse-analysis/imp_tf_cv.m`. Fig 2d goes back to the existing `tf_cv_heldout_r2.pdf` (per-session median and IQR of held-out R², pooled-median guide 0.85). The pooled-median label moved to the left end of its guide, because at the right end it sat on M3c's whisker. The panel now gets the `jnAxesAll` pass like the others. The sidebar (overlay + R² strip) stays a candidate only. New knobs: `CV_SINGLE_K` (pick panel C's session by index; the two AL_0041 sessions share a name) and `CV_REUSE` (keep a workspace `CV` instead of the 18 min refit). NC `results.tex`: caption c = "Model fit within one session (Mouse 1b), one pair of curves per amplitude…"; d = "Model fit in every session: held-out R² of each session's model…". The Results sentence citing the peak-normalized overlay ("Accordingly, the peak-normalized responses share the dip time course…", old L82) is removed; the time-constant numbers before it carry the same point. Re-run numbers unchanged: held-out R² 0.56 / 0.83 / 0.95 / 0.85 (M5a/M5b/M1b/M3c).
**Why:** Anna F2.5 ("what is D left supposed to provide beyond C except scaling?"). Aditya: c is per amplitude within one session; d needs only the held-out R².
**Next:** MANIFEST 2D → `tf_cv_heldout_r2.pdf` and the `PAPER_FINAL` run together with 2a/2b/2g. NC `Figure2.pdf` is still the old assembly and needs re-assembly.

### 2026-10-30 — D3 check: Fig 2a and 2c are different sessions; "Model fit window" label back at 6 pt
**Changed/Found:** Confirmed in code: 2a = `trace_overlay.m` hard-codes `allExperiments(2)` = AL_0041 2025-12-02 e2 (Mouse 5b); 2c = `imp_tf_cv.m` `CV_SINGLE_MN = 'AL_0033'` (Mouse 1b). `trace_overlay.m` gets a `TO_EXP` knob (default 2) and the "Model fit window" label again, at 6 pt (was 3.5 pt, then removed), centred above the plot box over the band. Rendered both candidates to scratch. Mouse 1b: ten amplitudes (0–1.63 mW, 81–196 trials each), graded responses, panel C held-out R² 0.56 / 0.91 / 0.98. Mouse 5b: five amplitudes, 0.87 and 0.90 mW nearly the same, so panel C shows 0.63 / 0.87 / 0.90 mW out of order (R² 0.55 / 0.94 / 0.79).
**Why:** Anna F2.4; Aditya: "make sure they are same session check in code then suggest, make sure the text model fit window is bigger".
**Next:** Aditya picks the session (suggested: Mouse 1b for both). If 1b, re-render 2a with `TO_EXP = 3` and move its legend clear of the scale bar.

### 2026-10-29 — NC: all Fig 2 supplementary material in one figure (relative/absolute power + state quartiles)
**Changed/Found:** New `paper-writing/supp_impulse_state_nc_build.py` (PyMuPDF; reuses the `fig1_nc_build.py` helpers). It builds `paper/figures_final/nc/supp_impulse_state/S_impulse_state_nc_draft.pdf` (180 × 128 mm) from the working panels in `paper/images/supplementary/`:
- a–c: relative/absolute power.
- d–f: quartile rows for motion, relative and absolute power.
- g–i: per-mouse raster strips.
- Then the session legend and the two colour bars.

One common scale per block (0.946 top, 0.938 state rows), so 6 pt panel text prints at 5.7 / 5.6 pt. Spatial spread (S1) stays a separate figure.

In Closedloop_nc:
- `supplementary.tex`: the figure keeps `\label{fig:state_quartile}` and now shows `images/supplementary/S_impulse_state.pdf`. Its caption merges the new a–c text with the old a–c → d–f and d–f → g–i text.
- `results.tex`: L92 "…}a)" → "…}d)" and L96 "a--c, second column" → "d--f, second column". The other citations (Results L102, Discussion L16, Methods L564, stat_tables L31) carry no letters.
- `git rm` of the old `S_state_quartile.pdf`.

Compiles clean: page 38, Supplementary Figure 2, no undefined references.
**Why:** Aditya: "we can put all figure 2 related supplementary material into one single figure"; asked whether to include the spatial-spread maps: "No, leave S1".
**Next:** panels a–c are not cited from the Results until the relative/absolute text (`relative_vs_absolute_power.md` §6) is approved. Once approved, run the relabs and quartile producers with `PAPER_FINAL` on and add a MANIFEST section. The JN draft still uses its own Illustrator assembly.

### 2026-10-29 — imp_state_quartile_supp.m: quartile axes by frequency ("Rel./Abs. 2–4 Hz quartile")
**Changed/Found:** `impulse-analysis/imp_state_quartile_supp.m`: `STATE_LAB` now reads "Absolute 2–4 Hz power" / "Relative 2–4 Hz power", so the axes read "Abs./Rel. 2–4 Hz quartile" instead of "Abs./Rel. δ quartile". Rebuilt from `data/fig2g_state_stats.mat` with `PAPER_FINAL` off; numbers unchanged (Q4/Q1 0.58 / 1.03 / 2.35). The raster strips (`imp_state_raster_peramp.m`) carry no δ label and already name sessions 5a/5b/1b/3c, so they were not re-run.
**Why:** Anna F2.7 (frequency, not Greek band names), so the panels match Fig 2g.
**Next:** run with `PAPER_FINAL` on once Aditya approves the F2.7 relabel.

### 2026-10-29 — imp_relabs_exemplars.m: panel a points in one neutral gray
**Changed/Found:** Panel a drew trials in the Fig 2 session blues, but the quartile rows in the same supplement use another session palette (M3c green), which clashed with the high-relative green. The values are z-scored within session, so session identity adds nothing; all points are now gray (0.70), with the three exemplar circles in colour.
**Why:** consistency once the panels were merged into one supplementary figure.
**Next:** none.

### 2026-10-29 — imp_relabs_exemplars.m: 2–4 Hz band-pass overlay removed from panel b
**Changed/Found:** `impulse-analysis/imp_relabs_exemplars.m` panel b now draws only the raw trial traces, plus the state-window shading and the laser row. The display-only 2–4 Hz Butterworth overlay added earlier today, and its `butter`/`filtfilt` code, are gone. Panels re-exported with `PAPER_FINAL` off; the caption draft in `relative_vs_absolute_power.md` no longer mentions light lines.
**Why:** Aditya: "what is the lights tone trace you added we dont need that".
**Next:** none.

### 2026-10-29 — imp_relabs_exemplars.m: high-relative exemplar re-picked to show 2–4 Hz bursts; 2–4 Hz component overlaid
**Changed/Found:** `impulse-analysis/imp_relabs_exemplars.m`.
- The high-relative rule is now the highest relative power among trials with z_abs ≥ 0. It was high relative and low absolute, mirroring `f4_delta_candidates.m`, but that picked trials too small for any rhythm to show (the dead end).
- A gallery of the top 6 per session under the new rule (scratchpad `relcand_gallery.png`) shows 2–4 Hz bursts in all four sessions.
- New Mouse 1b pick: amp 9, trial 54 (z_abs +1.1, z_rel +2.2, 95% of power in 2–4 Hz). Its absolute power is close to the high-absolute exemplar's (+0.9), so the two differ in spectral shape only.
- The panel c group is now z_rel > 1 and z_abs ≥ 0 (n = 104): 11% of power at 1 Hz, 81% in 2–4 Hz, median absolute 9.3 against 12.2 for the high-absolute group. Similar 2–4 Hz power; the high-absolute group has 10× more at 1 Hz.
- Panel b drops the amplitude-mean line and overlays each trial's 2–4 Hz component inside the window. This is a display-only 2nd-order Butterworth, zero phase, run on the whole trial and shifted to the trial's window mean.
**Why:** Aditya: "these high relatives ones dont have the short bursts i was hoping exist pick some other candidates".
**Next:** Aditya to approve; caption and table updated in `paper-writing/relative_vs_absolute_power.md`.

### 2026-10-29 — New imp_relabs_exemplars.m: relative vs absolute 2–4 Hz power on impulse trials; absolute ≈ total power (ρ = 0.97)
**Changed/Found:** New supplementary candidate `impulse-analysis/imp_relabs_exemplars.m`, the impulse counterpart of `controller-analysis/f4_delta_candidates.m`. It uses Fig 2g's trials (1516), window ([−1, 0) s, 35 samples) and estimator (mean removed, Hann, 1 Hz bins). Panels go to `paper/images/supplementary/relabs/` (not in MANIFEST):
- a: relative vs log-absolute power, z within session.
- b: three Mouse 1b trials picked by rule — typical, high absolute / low relative, and the reverse — on one y-axis over their amplitude means.
- c: group mean spectra, as a density and as a fraction of 0.4–10 Hz power.

Found:
- Spearman(abs, rel) = 0.47 pooled (0.41–0.50 per session), which reproduces the Results number.
- **Absolute 2–4 Hz power tracks total 0.4–10 Hz power at ρ = 0.97 (0.95–0.97 per session); relative power does not (ρ = 0.24, 0.13–0.29).**
- Mouse 1b groups:
  - high-absolute (n = 20): 53% of power at 1 Hz, 42% in 2–4 Hz, median total 28.3 (%ΔF/F)²;
  - high-relative (n = 29): 8% at 1 Hz, 80% in 2–4 Hz, median total 0.45;
  - typical (n = 72): 37% and 49%, median total 1.78.

So absolute 2–4 Hz power is effectively the size of the pre-stimulus fluctuations, mostly slow, while relative power is where in frequency they sit. Display spectra are scaled to a one-sided density ((%ΔF/F)² Hz⁻¹). That scale is one constant, so z-scores and the ratio are unchanged. Two layout dead ends: the z-value subtitles in b collided at 6 pt (moved to the caption), and a 6 pt legend covered the curves in either tile of c (dropped; the colours are b's titles).
**Why:** Aditya: "show example activity of both classes relative and absolute to show how they differ, put it in supplementary ... we already did this for controller trials".
**Next:** Aditya to approve the panels; then add a `[supp_relabs]` MANIFEST section and a supplementary caption (drafted in `paper-writing/relative_vs_absolute_power.md`). The ρ = 0.97 also fixes the honest reading of Fig 2g's absolute result: trials with larger pre-stimulus fluctuations deviate more. The stimulus-free control already shows that, so the text should say "amplitude", not "rhythm".

### 2026-10-29 — Fig 2b: real laser-power x-axis (mW) replaces the 0.25 mW scale bar; labels moved off the data
**Changed/Found:** `impulse-analysis/dose_response.m`, `DR_YAXIS` branch.
- `paperAxes` (which draws the corner scale bar) is replaced by `cleanAxes`, then both axes are drawn: x from 0 to 5.1 V (1.7 mW), ticks at 0, 0.5, 1 and 1.5 mW (placed at 3 V per mW), labelled "Laser power (mW)".
- Found: the old reason for having no x ticks ("per-session x offsets make tick values misleading") no longer holds. The dodge is 0.005 V per session, which is 0.002 mW.
- The session-label column moved from the top right, where it sat on the Mouse 1b/3c points, to start at 0.58 mW near the bottom. Hard left hit the steep Mouse 3c line, whose last point is at 0.54 mW; the new position was checked at 900 dpi.
- Fits unchanged (slopes −0.29 / −0.44 / −0.51 / −1.04 %/V). Exported with `PAPER_FINAL` off.
**Why:** Anna F2.3: "it's hard for me to interpret the laser power in B".
**Next:** caption b says "versus stimulation amplitude"; change it to "versus laser power" with the panel. Run with `PAPER_FINAL` on after Aditya approves.

### 2026-10-29 — Fig 2a: laser-command row with one pulse at t = 0 replaces the red "Stim" dot; 3.5 pt fit-window label removed
**Changed/Found:** `impulse-analysis/trace_overlay.m`.
- A red laser trace runs along the top of the panel (at 0.86 of the y-span), labelled "Laser". It has one 25 ms pulse at t = 0, one imaging frame long; Methods give 23–28 ms.
- The "Model Fit Window" label is removed. It was 3.5 pt, below Nature's 5 pt minimum, and at 6 pt it would be wider than the gray band. The caption names the band.
- Data were reloaded with `load_experiments` in a separate MATLAB batch (290 s, 4 sessions). Exported with `PAPER_FINAL` off.
**Why:** Anna F2.2: "why a dot for the laser".
**Next:** caption a "Red dot shows the stimulation impulse" → "Red trace, laser command (one 23–28 ms pulse at t = 0)". Run with `PAPER_FINAL` on after approval.

### 2026-10-29 — Fig 2g axis names by frequency: "2–4 Hz power (relative/absolute)", no δ
**Changed/Found:** `impulse-analysis/imp_state_var_combined.m` now labels the tiles from a tag → label map: "Motion", "2–4 Hz power (relative)" and "2–4 Hz power (absolute)". The cached `R.name` strings ("Rel \delta", "Abs \delta power") are no longer used for the panel. The first try, "Relative 2–4 Hz power" on one line, ran into the neighbouring tile at 6 pt, so the qualifier went on a second line. Rebuilt from `data/fig2g_state_stats.mat` with `PAPER_FINAL` off, so only `paper/images/figure2/` changed. Numbers unchanged (Q4/Q1 0.58 / 1.03 / 2.32).
**Why:** Anna F2.7: "just say 2-4hz power instead of del ... what is relative vs absolute supposed to be". Aditya wants the difference made clear and the band choice referenced; that text is drafted separately.
**Next:** once Aditya approves, run with `PAPER_FINAL` on to update `figures_final`; the Results/caption/Methods δ wording must change with it.

### 2026-10-29 — NC Fig 1e: gain triangles closed and enlarged so the K labels fit
**Changed/Found:** `paper-writing/fig1_nc_build.py` — new `gain_blocks()` in `fix_e`.
- Found: MuPDF stroked Anna's `<polygon>` gain blocks without their closing back edge, so K_r, K_p and K_i sat in open chevrons.
- Found: at 7 pt the K and its subscript spilled over the slanted edges. Anna sized the blocks (8–9 × 6–7 mm) for her smaller text.
- Changed: the triangles are now closed `<path … Z>` shapes, all 10 × 7 mm, with the K label in the tall back third.
- Changed: the six wires that meet the triangles move to the new edges.
**Why:** Aditya: "the triangular blocks dont have edges and the controller gains are overflowing" the blocks.
**Next:** none. Closedloop_nc 6ceced7 (local) carries it as `images/Figure1.pdf` and compiles clean.

### 2026-10-29 — NC Fig 1 re-packed: frame 46 → 34 mm with a key at its right, latency panel fills the row
**Changed/Found:** `paper-writing/fig1_nc_build.py`.
- `frame_panel` now draws a 34 mm frame with its key (output, stimulation, 1 mm bar) to the right, instead of a 46 mm frame with the key underneath.
- The top row's panels, a, b and c, are all at 1:1 text (7 pt). They are spaced with equal gaps across 180 mm and top-aligned under their letters.
- c is the new `panel_c_latency.pdf`, sized for its slot by `latencyAnalysis.m`.
- The page is now 180 × 115 mm (it was 120). Closedloop_nc e16b76a (local) carries it as `images/Figure1.pdf`.
- What white space remains is a ~14 mm band under b. b is shorter than a, which fixes the row height at 49 mm because its text is 7 pt.
**Why:** Aditya: "so much white space", "b is too big can be made small". Before this, the top row had ~70 mm of spare width once the schematic was gone.
**Next:** Aditya to review. Filling the band under b would need a taller b, which runs against the ask.

### 2026-10-29 — latencyAnalysis.m: NC Fig 1c export; the panel has n = 175 cycles and a 29 ms median, not 200 and 24
**Changed/Found:** `latencyAnalysis.m` gets a new NC block after the JN print. It writes the same data as a 5.4 × 4.4 cm panel, `paper/figures_final/nc/fig1/panel_c_latency.pdf`: 1 ms bins from 10 to 50 ms, ticks every 10 ms, axes "Loop latency (ms)" and "Loop cycles" (Anna F1.5). It also prints summary stats. The JN `paper/latency_histogram.pdf` is unchanged.
- I ran it on the server session test 2026-04-23/1 (photodiode pairs, light-gated). Result: **n = 175, median 29.0 ms, 99th percentile 44.4 ms, range 14.0–47.0 ms**.
- The range matches the old panel's end ticks, so it is the same data.
- The caption and methods L100 say "200 loop cycles", which is wrong for this panel.
- Fig 1d's bracket says "24 ms median" (methods L101: Mouse 4, exposure start to laser edge, 99th percentile 40 ms). So the figure now shows two different latency measurements side by side.
**Why:** Make c fill its slot and fix the axis labels Anna flagged.
**Next:** Aditya to decide which latency Fig 1 shows. Either c uses the Mouse 4 measurement that Methods quotes, or d's bracket and the text quote 29 ms from this test session. Then correct n in the caption and Methods (both drafts).

### 2026-10-29 — NC draft: Fig 1 caption and panel references follow the a–e layout
**Changed/Found:** Closedloop_nc 6a5502a (local, not pushed).
- `results.tex` caption: b is now the frame (Mouse 2a), with the kernel defined as 10 × 10 px (0.17 mm), "Markers are enlarged" and "Scale bar, 1 mm". The latency histogram is c. In d, the trigger trace is "drawn to scale" and the bracket marks the median latency.
- References re-lettered: results L21 b,c → b; results L39 e,f → c,e; methods L100 f → c; discussion L49 f → c.
- `images/Figure1.pdf` is now the `fig1_nc_build.py` composition, so the figure matches its caption. It compiles with no undefined references.
**Why:** The schematic was dropped and the panels were re-lettered (entry below).
**Next:** c's caption still says "camera trigger to laser-activation command", while Methods L100 says "camera exposure to stimulation command"; settle this with the F1.5 replot. Fig 1c is now first cited after 1d (results L39–40). The JN draft is unchanged.

### 2026-10-29 — NC Fig 1: mouse schematic dropped, frame carries its own markers; 7 pt text, 1 pt arrows
**Changed/Found:** `paper-writing/fig1_nc_build.py`. Panels re-lettered a optics, b frame, c latency, d pipeline, e control loop (page now 180 × 120 mm).
- New `panel_b_frame.pdf`: the frame plus a blue box (readout kernel) and a red dot (stimulation), a legend for both, and a 1 mm bar (field 560 px × 17.3 µm = 9.69 mm).
- Marker positions are real, in native (row, col): readout (320, 380) from `d.params.pixel = [380 320]` (x, y), and laser (291, 405) from the measured dip in `controller-analysis/data/cp_stim_site_ctrl_AL_0039_0419_e1.mat`. The rig's `params.laser = [410 300]` is within 10 px of the dip.
- Orientation checked: the frame and the stim-site brain mask correlate 0.74 as they are and 0.04 transposed. Readout and laser sit 38 px (0.66 mm) apart, both inside the inhibited zone.
- The markers are not to scale: the kernel is 10 px (0.17 mm) but is drawn as a 0.8 mm-wide square.
- d and e: all text is now 7 pt (labels were 6), subscripts 5.5 pt. Connectors went from 0.25 to 0.35 mm (1 pt). Arrowheads went from 1.6 to 2.0 mm, and each line now stops inside its head.
- Panels a and c are placed so their text also lands at 7 pt: a at 7/20.95 scale, c at 1:1.
- At 7 pt, e's "Input u" ran into the feedforward "+", so the label moved below the line.
**Why:** Aditya: drop b, but then the output and stimulation markers need defining on the frame; and "even larger fonts and bolder arrows on d, e". 7 pt is the top of the Nature figure guide's 5–7 pt range, so going larger would break it.
**Next:** NC caption and panel references follow the new letters (old b,c → b; old f → c). c still needs the F1.5 replot, which should also size it to fill its 60 mm slot. Then the Illustrator assembly from these panels.

### 2026-10-29 — NC Figure 1 draft built from Anna's SVGs: E signs restored, D timing to scale, one text size
**Changed/Found:** new `paper-writing/fig1_nc_build.py`. It reads Anna's files (`paper/from_anna_2026-10-29/`, from her Claude chat) and writes `paper/figures_final/nc/fig1/`: `panel_d_architecture.svg`, `panel_e_control_loop.svg` and the 180 × 112 mm composition `Figure1_nc_draft.pdf/.png`. Fixes:
- E: the summing junction is back to e = y − r (− on r, + on y; methods.tex eq:error).
- E: the widefield placeholder is replaced by the real SVD frame (600 dpi).
- One text size: 6 pt labels, 7 pt variables, 5 pt subscripts, 8 pt bold lowercase letters. Her chat used 6.5/8/5.4/10 pt; Nature allows 5–7 pt text.
- D: the trigger trace is to scale. Blue exposures come every 28.6 ms with 14 ms exposure (Methods L66: blue/violet alternate at 70 Hz), and the laser update is drawn 24 ms after exposure start (Methods L101). It has a latency bracket and a 10 ms bar. Her trace had ~15 pulses, and its "Latency" bracket spanned ~9 frame periods (≈260 ms).
- `<style>` CSS and SVG markers are inlined into attributes and drawn triangles, because MuPDF ignored both; this is also safer for Illustrator.
The composition places the real a (wfpath), b (mouse schematic) and c (SVD frame). F is placed at 6/7 scale so its 7 pt text lands at 6 pt. Measured placed text: a 6.1 pt, F 6.0 pt. `.gitignore` now excludes `paper/figures_final/nc/` and `paper/from_anna_*/` (local assets, like the other assemblies).
**Why:** Anna's F1.1, F1.3 and F1.4, plus the NC layout at the Nature double-column width. A rebuild is reproducible from the script, whereas hand edits in Illustrator are not.
**Next:**
- Aditya's calls: letter order (currently a b c f / d e), drop b (F1.2/D2), and whether E keeps the small widefield frame.
- F1.5: replot F at 38 × 43 mm with normal ticks and the Methods latency definition.
- A scale bar on c (needs the frame's field size).
- Final assembly in Illustrator from the two SVGs. Anna's originals exist only on this PC.

### 2026-10-29 — Anna's Fig 1 redraw read from her Claude share; its E sign flip contradicts Methods
**Changed/Found:** `paper-writing/REVIEW_ANNA_2026-10-29.md` (6b7a10b) — new subsection under Figure 1. It covers her chat "Scientific figure formatting" (shared to aditya.158@gmail.com, read through Claude in Chrome). The chat redrew Fig 1D and 1E as SVGs at print size and laid out the full figure at 180 × 112 mm, the NC double-column width. The share exposes the text but not the files ("This link doesn't give access to this file"), so Anna must send the 5 files. Her chat flipped the 1E summing junction to e = r − y, calling the original positive feedback. Our Methods define e_t = y_t − y_ref (`methods.tex` eq:error) because the light only lowers activity, so the original signs were correct.
**Why:** her redraw is the starting point for Fig 1 (F1.1–F1.4). The sign error would put a figure into the paper that contradicts its own Methods equation.
**Next:** get the SVG/PDF files from Anna. When placing E, restore "+" on y and "−" on r, and pick one text size for the figure (her 6.5 pt or the house 6 pt). Fig 1F's axis should state the latency definition used in Methods (exposure start to laser command).

### 2026-10-29 — Anna's review logged as a handoff file; opsin wording found wrong in Results
**Changed/Found:** `paper-writing/REVIEW_ANNA_2026-10-29.md` (new) lists every note in Anna's review (she read through Fig 4), quoted verbatim, each with its manuscript line or producer script, a diagnosis, a proposed fix and a status, plus the G1 abstract draft and 7 decisions waiting on Aditya. Found while mapping her notes: `results.tex` L18 says the mice co-express "GCaMP and an inhibitory opsin". ChrimsonR (DLX2.0, interneurons) is an excitatory opsin, and GCaMP8s is in excitatory neurons, so they are not in the same cells (item T7). Fig 2 panels label sessions "Mouse 1"/"M3" while the captions say 1b/3c (X2.1). She read JN 98aebf1, which is also the NC fork point, so text fixes need a draft named; panel fixes reach both.
**Why:** Aditya wants another agent able to work through the review one item at a time without this chat.
**Next:** work the items in the file's order; D1 (abstract order) is the first decision, and for each text fix ask which draft (JN, NC or both).

### 2026-10-29 — NC draft formatting pass (3 local commits, not pushed) + nc_style.py / nc_wordcount.py
**Changed/Found:** Closedloop_nc, committed locally only. (1) 34a7126 — natbib `numbers,sort&compress,square` + `unsrtnat`; three `\citealp` asides became `\citep`. (2) 47c9abf — removed the Significance Statement; Data availability and Code availability are now end-matter sections (moved out of Methods); added Acknowledgements, Author contributions and Competing interests placeholders; "Experimental Design and Statistical Analysis" became "Statistical analyses"; `stat_tables` moved into the SI. (3) ff6f08e — new `paper-writing/nc_style.py` (idempotent): 140 figure refs to "Fig.~\ref{}a", 92 caption panel letters to `\textbf{a},`, 26 table refs to "Supplementary Table", 4 equation refs, 32 "Materials and Methods" to "Methods". Plain-text panel letters were fixed by hand on 9 lines. The SI now numbers "Supplementary Figure/Table N", with `\theH*` so its hyperref anchors don't collide with the main-text ones. latexmk compiles: 42 pp, 0 undefined citations or refs, 0 duplicate anchors. New `paper-writing/nc_wordcount.py` measures the word budget.
**Why:** Nature Comms conventions (nature.com/ncomms/submit/article + how-to-submit, Nature figure guide, checked 2026-10-29). Doing the mechanical part by script keeps it repeatable: `paper_stats_tex` always writes JN style, so `nc_style.py` must re-run after every regeneration into NC.
**Next:** the budget. Main text is 7,535 words (intro 1,371, Results 4,389, Discussion 1,775) against ~5,000. The abstract is 253 words (≤200). Methods is 6,916 (typically <3,000; the rest goes to Supplementary Methods). The Fig 4 legend is 431 words (≤350). Title and abstract need Aditya's choices. The figure images still carry uppercase panel letters until the NC assemblies exist, and SI figure order should follow first citation. Push the NC repo only on Aditya's OK.

### 2026-10-29 — Seed FC supp panel relabelled with paper session labels (was internal m-numbers)
**Changed/Found:** `controller-analysis/ctrl_seed_fc_group.m` — column headers now come from `paper_session_label(..., 'short')` (M1c, M1d, M1e, M1f, M1h, M1j, M1k, M1l, M2a–M2d) and columns are sorted by that label, so mouse, then date. That swaps the old m9/m10 order: AL_0039 04-19 is now 2a. Removed the local `paper_m` m-number table. Re-exported from the per-session caches with `PAPER_FINAL` on; `figures_final/panels/supp_seedfc/seedfc_group.pdf` was rewritten. The numbers are unchanged: CL Δr −0.154 ± 0.027, 12/12, signrank p = 0.0005, 59/61 nodes FDR; OL +0.011 ± 0.010, p = 0.30, but **6/61 nodes pass FDR in OL**, which FINDINGS did not record. CL vs OL paired p = 0.0005.
**Why:** m-numbers are internal only (session-label rule 2026-10-19), and Aditya flagged that the "CL decouples the site from cortex" supp figure was never made. The panel existed (locked 10-20) but was in no manuscript.
**Next:** the supp figure still has to go into the drafts: caption, a Results sentence and a Methods paragraph, as snippets for Aditya. The panel covers 12 of the 15 sessions and 2 of the 4 mice (m1 has no site cache; AL_0048/AL_0051 were never run), so the caption needs a stated reason, or the analysis gets extended to Mice 3 and 4 if their full-frame SVDs exist.

### 2026-10-29 — Second manuscript draft for Nature Communications (Closedloop_nc), independent of the JNeurosci draft
**Changed/Found:** Created private GitHub repo `smartadi/Closedloop-NC` and local clone `projects/Closedloop_nc/`, cloned from Closedloop_edit main 98aebf1 (tag `fork-nc-2026-10-29`, pushed to the NC repo only). The NC clone has a fetch-only `jn` remote (push URL disabled, main only). `.git/info/exclude` was copied by hand because a clone does not carry it. A local `sync_figs.ps1` reads from `paper/figures_final/nc/` (new, empty). Updated `paper-writing/CLAUDE.md` (two-draft table, sharing rules, and removed the stale `draft`-branch protocol: only `main` since 10-27) and the root CLAUDE.md Manuscript bullet. The hub's `REPOS.md` lists `Closedloop_nc` as `auto`. The JN repo is untouched: 98aebf1 is still unpushed there, waiting on the Figure5.pdf reassembly.
**Why:** Aditya was advised to aim for Nature Communications. Overleaf's GitHub sync ties one project to one repo and syncs its default branch, so a branch in Closedloop could not be its own Overleaf project. Shared science (code, panels, STATS_TABLE.csv, FINDINGS) stays single-sourced here; prose, captions, assemblies, main.tex and refs.bib are per draft.
**Next:** Aditya imports Closedloop-NC into Overleaf and shares it with Nick, and clones it on the home PC. Then the NC first pass: numbered refs, title ≤15 words, abstract ≤200 words, no Significance Statement, main text toward ~5,000 words, lowercase panel letters. Shared-pipeline items (NC_STYLE.md, `paper_stats_tex` venue option, DRAFTS.md) are not built yet.

### 2026-10-29 — Fig 4E kernel map: not an indexing bug, but the ridge weights cannot be read as a map
**Changed/Found:** `controller-analysis/f4_kernel_map.m` (Anna's review: "looks bugged") — checked the plotted ridge file `ctrl_ols_ol_stimblind_ridge_AL_0033_0415_e2.mat`. The 408 weights match the 408 grid points (33×17 grid, step 13 px), so nothing is misplaced. The weights flip sign from pixel to pixel: sum(b) = 1.55 against sum(|b|) = 19.7, and the correlation between neighbouring weights is about zero (−0.08 horizontal, 0.13 vertical). Ridge spread the fit across strongly correlated neighbouring pixels. The prediction itself is fine (held-out R² 0.748 at λ* = 0.046). Held-out R² is flat across λ: 0.755 at λ → 0, 0.709 at λ = 1, 0.686 at λ = 10.
**Why:** a backward-model weight map shows how the model cancels shared signal, not where the information sits (Haufe et al. 2014), so the panel can't support the "the homolog carries the most weight" reading that Anna expects and the script header claims. The pixel time series aren't cached (the S1/S2 files hold no X or Gram), so a forward map needs the session's SVD to be reloaded.
**Next:** decide with Aditya: (1) replace 4E with a forward pattern (each contra pixel's covariance with the prediction) or a spontaneous-frame correlation map, or (2) drop 4E. Nothing changed yet.

### 2026-10-28 — Fig 5 panels re-exported and the manuscript's Fig 5 numbers updated (committed locally, NOT pushed)
**Changed/Found:** Headless `matlab -batch` ran `load_bilateral` → `sine_ff_plots_combined` (s2) → `sine_ff_across_sessions` with `PAPER_FINAL` on. All 10 `figures_final/panels/figure5/` panels were rewritten through the mirror. The old panels and working copies are backed up in `data/_pre_sine_rig_20261028/`. Trial counts are unchanged: s2 51/46/46/57; pooled 136/110/100/132.

Closedloop_edit `results.tex`, Fig 5 text and caption:

| Quantity | Old | New |
|---|---|---|
| Variance, OL → CL | 17.9 → 14.8 | 11.8 → 5.8 |
| Median RMSE (OL / OL+p / CL / CL+p) | 3.82 / 3.55 / 2.80 / 3.30 | 3.59 / 3.58 / 2.26 / 3.00 |
| Lag (OL / CL / OL+p / CL+p) | 60° / 36° / 5° / −9° | 71° / 46° / 16° / 2° |
| 5G SDs | 1.85 / 2.75 / 2.19 / 1.57 | 1.22 / 1.64 / 0.99 / 1.01 |
| Pooled RMSE (mean ± SD) | 4.58 ± 1.77 / 4.47 ± 2.22 / 3.83 ± 1.94 / 3.95 ± 1.58 | 4.08 ± 1.40 / 3.77 ± 1.38 / 3.00 ± 1.12 / 3.08 ± 1.11 |

Two claims changed:
- "the median per-trial shift was 5.0 samples" became "the OL shift (55°) was close to the five-sample lookahead (51°); the per-trial lag fell by 5.7 samples on average (6 in the median)".
- "CL+p had the narrowest spread of the four modes (SD 1.57 / 1.58)" was false on the new signal: CL is 0.99, CL+p 1.01. It became "as tightly spread as closed loop (1.01 vs 0.99; pooled 1.11 vs 1.12)".

Left alone:
- "preview canceled the lag" (Results J, abstract, Discussion). The per-session residuals are 4–16° (OL+p) and −12–15° (CL+p), the same size as the old −10° that was already called canceled.
- Methods L74/L119 already said Figs 3–5 use the signal the controller computed online, so the code now matches Methods and Methods needs no edit.

latexmk clean, 41 pp. Committed on Closedloop_edit main, not pushed: `images/Figure5.pdf` is still the old Illustrator assembly, so pushing now would put the new numbers next to the old panels on Overleaf. PAPER.md Fig 5 block and FINDINGS updated to the new numbers.
**Why:** User 2026-10-28: "reconcile the Fig 5 and Fig 6 sine numbers here now".
**Next:**
- User reassembles Figure5.pdf from the re-exported panels and copies it to `Closedloop_edit/images/`.
- Then push Closedloop_edit main.

### 2026-10-28 — 5B single-trial panels: y range now holds the example trials
**Changed/Found:** `bilateral/sine_ff_plots_combined.m` 5B y-limit was a fixed [−12 8]. On the rig signal the OL example trial (EX_TRIAL 6) runs above +8 after the stimulus and was clipped. It is now `[min(−12, floor(min)) max(8, ceil(max))]` over the four example traces, shared across the four mode axes. 5C keeps its fixed [−8 6]: the rolling signal's ±SD band is narrower and fits.
**Why:** Seen in the preview after the signal switch (entry below).
**Next:** none.

### 2026-10-28 — Found: the rig's logged signal comes from the stimulated right site in all three sine sessions; the low session-wide correlation is the rig's start-up transient
**Changed/Found:** Read-only (scratch `rig_pixel_map.m`, `rig_noise_check.m`, `rig_trace_plot.m`; server SVD + `states.csv` read only).
- Session-wide corr(states row k+1, offline 40 s trailing dF/F at `right.pixel`, frame k): s1 0.40, s2 0.99, s3 0.67.
- The cause is outside the trials:
  - the rig trace has a large start-up transient in its first ~1.5 min (s1 to > 40 %);
  - s3's excluded stationary block at the end (after ~64 min) diverges.
- On the scored sine-trial windows: r = 0.982 / 0.985 / 0.977 at lag 0, against 0.94–0.96 at ±1. Per-trial r is 0.99 and the OL trial averages agree (r ≥ 0.99, p2p 4.4 vs 4.5, 5.7 vs 5.8, 5.1 vs 4.5).
- The rig trace sits ~0.8–1.1 % below the offline one in every session, a baseline difference.
- s3's `d.params.pixel` = [153 367] (left hemisphere; the galvo sign-flip logged 2026-07-29). The correlation map (states vs every pixel, high-passed SVD) peaks in the RIGHT hemisphere near the stimulated site in s1 and s3, not at [153 367]. So the s3 controller fed back on the right site, and `params.pixel` is only mislabelled; no wrong-site control.
- Smoothing below 4 Hz does not raise the session-wide r, so this is not pixel noise.
**Why:** The first version of `sine_rig_dff`'s alignment check ran on the whole session and gave 0.40 / 0.67 for s1 / s3, which could have meant the rig controlled a different pixel.
**Next:** none. `sine_rig_dff.m` now runs its check on the trial windows and asserts r > 0.95.

### 2026-10-28 — Fig 5 now scores the rig's online dF/F on the rig's pairing; Fig 5 and Fig 6 now agree on Mouse 3b
**Changed/Found:**
- New `bilateral/sine_rig_dff.m` returns `states.csv` (the rig's online 40 s trailing dF/F at the controlled pixel) on the row clock of `onset_idx` / `ref_raw`:
  - row k = frame k−1, which is the rig's own pairing, as in `ctrl_mpc_sine_export`;
  - it reads the CSV from the server once and caches it in `data/sine_states_<mn>_<mmdd><en>.mat`;
  - it checks the alignment on the scored trial windows.
- `sine_ff_plots_combined.m` and `sine_ff_across_sessions.m` now score it:
  - against −`ref_raw`, the target the rig tracked (`error = states + reference`); the old `sine.ref0` offset (−0.032) was never part of it;
  - skipping trials that reach into the 1400-row warm-up (none do);
  - in 5B/5D the laser is read at `timeBlue(i0−1)`.
- Before, they scored `sess.right.dFoF`: `getpixel_dFoF` mode 1, F/meanImage, the impulse definition, against CLAUDE.md's rule that Figs 3–5 use the controller's trailing dF/F. Row kk was paired with frame kk.
- The plots script now prints the quoted numbers (median RMSE, SD, lag, window-mean variance).

Decomposition on s2, same trials and same 0–4 s window in both pipelines:

| | OL lag | CL lag | OL var | CL var | CL+p median RMSE |
|---|---|---|---|---|---|
| F/mI, kk (old Fig 5) | 60.5 | 36.2 | 17.93 | 14.76 | 3.300 |
| F/mI, o−1 | 70.2 | 45.9 | 17.97 | 14.79 | 3.265 |
| offline trailing, o−1 | 69.8 | 45.3 | 11.73 | 6.25 | 2.925 |
| rig states, o−1 (new Fig 5) | 70.7 | 46.1 | 11.82 | 5.81 | 2.985 (3.00 without ref0 = Fig 6's 2.995) |

So the pairing explains the ~10° lag gap, and the dF/F definition explains the RMSE and variance gaps. The new s2 output equals STATS_TABLE `6s_*` exactly: 3.59 / 3.58 / 2.26 / 3.00; 71 / 16 / 46 / 2°; variances 11.82 / 13.39 / 5.81 / 8.85.

Across sessions (5I–K), CL < OL still holds in every session:

| Session | RMSE (OL / OL+p / CL / CL+p) | Variance | Lag (°) |
|---|---|---|---|
| s1 | 5.18 / 4.31 / 3.99 / 3.46 | 24.6 / 19.3 / 13.4 / 11.4 | 66 / 9 / 55 / 15 |
| s2 | 3.84 / 3.69 / 2.61 / 2.98 | 11.8 / 13.4 / 5.8 / 8.9 | 71 / 16 / 46 / 2 |
| s3 | 3.88 / 3.63 / 2.93 / 3.05 | 12.7 / 11.9 / 7.6 / 9.8 | 70 / 4 / 49 / −12 |

**Why:** This was the Fig 5 vs Fig 6 mismatch found in today's consistency review. Fig 6 (MPC, locked) already scored the rig signal, so Fig 5 moves to it. This also brings Fig 5 in line with the locked ΔF/F rule and with what Methods already says.
**Next:**
- Re-export the panels and update the text (entry above).
- Not touched, all still on the old F/meanImage signal and none in the paper: `sine_ff_modes.m`, `sine_ff_error_decomp.m`, `sine_ff_paper_panels.m` (retired Fig-4 naming) and the presentation `export_ff_bundle.m`.

### 2026-10-28 — Manuscript pushed to Overleaf: rebuilt Figs 3/4/OLbest + stats-quoting consistency pass
**Changed/Found:** Closedloop_edit main d2eb61d (images/Figure3.pdf, Figure4.pdf, supplementary/OLbest.pdf copied from `paper/figures_final/`) and e7c4b0f (text), pushed together with 7e96deb..2fabeb6; origin/main = e7c4b0f. An independent read of every quoted statistic against STATS_TABLE.csv found, and I fixed:
- Abstract (main.tex) and Introduction still said 1–4 Hz power cost feedback ground *relative to open loop*. That is attenuation, now p = 0.094. Both now state the closed-loop slope (R, p = 7.1e-4, Holm 0.0057), as Results does.
- Abstract: MPC "about 40%" scoped to the constant-reference replay (the sine replay gave 11%).
- Discussion: "one session's trials" → "recorded trials" (two sessions were replayed); best fixed "29% too low" (old median 1.29) → "1.28 times".
- Methods:
  - Fig 4G carved out of "one number per session".
  - Mouse random effect: "did not base inference on".
  - The tables, not the text, carry CI + t(df).
  - V is given only for Fig 4G.
- Results:
  - Initial-deviation OL slope (p = 0.056) is no longer described as an effect.
  - Motion gap-trend clause removed (Methods says the gap trend is not interpreted).
  - Selective Holm caveat on rel δ removed (L204 already names the two Holm survivors).
  - Mouse counts added: 3H windows 4/4, best fixed 3/4, motion A 4/4, abs-δ R 4/4.
  - 3H star legend now says 0–3 s; 4G legend names its test; three typos.
- Numbers printed inside the figures match the tables:
  - OLbest: 0.92 [0.86, 0.99], 0.80 [0.73, 0.88], ρ 0.67, p 0.008.
  - Fig 4D: every star equals the raw p.
  - Fig 3H/I: the geometric means read off the axes are 0.85/0.68 and 0.66/0.54.
- latexmk clean, 41 pp, no overfull boxes.
**Why:** User 2026-10-28: "i updated all figures add to paper edit and push to main, do a review of stats quoting consistency in paper first then push to main".
**Next:**
- Overleaf pull.
- S1.pdf was not reassembled: `figures_final/S1.pdf` is still from 2026-10-05, and its OL-variance-evolution panel changed (not quoted anywhere).
- Fig 5/6 sine mismatch (entry below).
- Fig 4G re-run.

### 2026-10-28 — paper_stats_tex: Table 5 gets Wilcoxon / mice / LOMO columns; Bonferroni line removed
**Changed/Found:** `paper-writing/paper_stats_tex.m`:
- Fig 4D table re-laid out like the Fig 3 table. Each state is an italic block header with its sessions and trials. Columns: Quantity | Estimate [CI] | t | p | Holm p | Wilcoxon p | Sessions (mice) | LOMO p. The df go in the caption (14; 10 for motion).
- Fig 2G caption: "Bonferroni threshold for three states, p < 0.017" removed.
- Lead sentence: "Every statistic quoted in the Results" → "Every test quoted for Figs 2–4", with Figs 5 and 6 named as descriptive.
- `pctci` now always prints whole percent with no signed zero (initdev A was "−0.4 [−7, 7]").
- The table now shows:
  - abs-δ R LOMO worst p 0.065;
  - motion P LOMO 0.073;
  - abs-δ A Wilcoxon p 0.035 against t p 0.094.
**Why:** Methods promises the Wilcoxon and mouse checks for every session test, but Table 5 had only a sessions column. Bonferroni was retired on 2026-10-27.
**Next:** none.

### 2026-10-28 — Table S1 sensitivity without session 1e, re-run with the session t-test
**Changed/Found:** Took the per-session ratios in `data/fig3_ratio_stats.mat` (`R3.*.st.values`; row 4 = m4 = 1e, matched to `stats_v2/results/corrected/session_fig3.csv`), dropped 1e and ran `sess_test`. All six windows have 14 sessions and 4/4 mice:

| Ratio | 0–3 s | 0–1 s | 1–3 s |
|---|---|---|---|
| RMSE | 0.763 [0.72, 0.81], p 1.4e-7 | 0.850, p 2.0e-5 | 0.672, p 1.1e-6 |
| Variance | 0.573, p 9.0e-6 | 0.659, p 6.6e-4 | 0.526, p 1.9e-6 |

The supplementary caption had the old mixed-model values on the pre-fix caches (0.84/0.68 and 0.64/0.53, p ≤ 0.003) and left out the primary window. Caption updated.
**Why:** The consistency review found stale numbers from the retired test.
**Next:** none.

### 2026-10-28 — Found: Fig 5 and Fig 6 quote different numbers for the same Mouse 3b sine trials (NOT fixed)
**Changed/Found:** Both texts describe the same session and the same 0–4 s window, but quote different values:

| Quantity | Fig 5 text (`sine_ff_*`) | Fig 6 text/caption and STATS_TABLE `6s_*` (`ctrl_mpc_sine_export`) |
|---|---|---|
| OL lag | 60° | 71° |
| CL lag | 36° | 46° |
| OL+p lag | 5° | 16° |
| CL+p lag | −9° | 2° |
| OL median RMSE | 3.82 | 3.59 |
| OL+p median RMSE | 3.55 | 3.58 |
| CL median RMSE | 2.80 | 2.26 |
| CL+p median RMSE | 3.30 | 3.00 |
| OL variance | 17.9 | 11.8 |
| CL variance | 14.8 | 5.8 |

- The ~10° lag offset is the one-frame pairing difference logged 2026-10-27. `sine_ff_*` pairs row kk with frame kk; the MPC export uses the rig's o ↔ o−1 pairing.
- The RMSE and variance gaps are too large for one frame. Check the trial set, the window edges, the variance definition, and whether both really use the same session (Fig 6 caption: "the session of Fig. 5B–H").
**Why:** Found in the consistency review: a reader comparing Figs 5 and 6 sees two values for one quantity.
**Next:** Reconcile the two sine pipelines. The MPC side is locked, so Fig 5 adopts the rig pairing if that is the cause. Re-export the Fig 5 panels and text if Fig 5 moves.

### 2026-10-27 — Manuscript: Methods, Results and tables moved to the session rule (Closedloop_edit main, not pushed)
**Changed/Found:** Closedloop_edit commits 7e96deb (Tables 4–5 regenerated), deec011 (Methods), 2fabeb6 (Results + supplementary).
- Methods:
  - "Software and inference" now states the session t-test, the exact Wilcoxon, the mouse check (mice agreeing, leave-one-mouse-out) and why mouse is not a random effect, plus one sentence on the independent Python reproduction.
  - Fig 3: 0–3 s is primary; pre/post are reported as ratio + CI only.
  - Best fixed: Spearman sentence added; median 1.29 → 1.28.
  - Fig 4D: per-session OLS slopes replace the mixed-model block. The simulation false-positive sentence and the motion-Wilcoxon corroboration sentence are removed.
  - Multiple comparisons: raw p per question, with a Holm column as a check (Bonferroni thresholds removed).
  - The REML/Satterthwaite sentences moved into the Fig 4G paragraph, the only mixed model left.
  - New "Trial onsets" paragraph: Mouse 1 drift of up to 7 frames, corrected from the open-loop laser rise minus the 1.9-frame lag; Mouse 3e 11-frame realignment.
- Results:
  - Fig 3, variance and best-fixed numbers; the 2.6-df sentence is removed.
  - Fig 4D rewritten: abs-δ attenuation is no longer claimed (p = 0.094), and every starred slope is interpreted (initdev R, rel-δ R and A).
  - Fig 4D caption and Fig 3H star caption updated.
- Fig 4G text, caption and table are unchanged.
- latexmk is clean (41 pp, no overfull boxes); the 4D table needed tabcolsep 4 pt.
**Why:** User approved 2026-10-27: "Use raw per-question stars on Fig 4D with a Holm column in Table 4, re-export the final panels, and start the paper text and table changes."
**Next:** User reviews `git diff origin/main..main` in Closedloop_edit and says when to push. Fig 4G: re-run where the server SVDs are reachable, then update its Methods paragraph, Results L231, caption and Table 6.

### 2026-10-27 — paper_stats_table / paper_stats_tex rewired to the session rule
**Changed/Found:**
- `paper-writing/paper_stats_table.m`:
  - Six new columns (role, wilcoxon_p, sessions_agree, mice_agree, lomo_worst_p, holm_p) and an `addS` helper for `sess_test` rows.
  - Fig 3 rows come from `R3.*.st` (role main/secondary/control); Fig 4D rows come from `data/f4_row2_sess.mat`.
  - Retired (STATS_AUDIT §2–3 TRIM): the LMM, `_lmmfb` and `_w` rows; the trial-level CORROBORATING rows (`3_*_lmm` / `3_*_sr`); the Fig 4D LMM rows; the motion Wilcoxon rows.
  - New rows: `3H_best_cstar` (median + IQR) and `3H_best_cmd_rho` (Spearman).
  - STATS_TABLE.csv: 146 → 109 rows.
- `paper_stats_tex.m`:
  - New Fig 3 table: t, p, Wilcoxon, sessions (mice) below one, LOMO; pre/post without a test.
  - New Fig 4D table: Test, Holm p and Sessions columns; no bold.
  - The new text columns are read as strings; no signed zero.
- Before regenerating, I checked the old generator's output against Overleaf's `stat_tables.tex`: only the date line differed, so no hand edits were lost.
**Why:** The tables must match the approved test rule, and the audit's TRIM verdicts remove duplicate tests of one claim.
**Next:** Fig 4G rows once `f4_cl_reject_lmm` is re-run. The script already saves the session `ST` / `STall`.

### 2026-10-27 — FINAL export: Fig 3 ratio/cross-session panels, Fig 4D, best-fixed supp, S1 panels
**Changed/Found:** Headless `matlab -batch` run with `PAPER_FINAL = true` and `F4_STAR = 'raw'`. `PAPER_FINAL` was off during `load_sessions`, so panels A–E for m10 were not touched. 11 panels written to `paper/figures_final/panels/`:
- figure3: `MSE_ratio_by_window`, `variance_ratio_by_window`, `all_variance_sessions`, `all_average_sessions`;
- figure4: `f4_row2_quartiles`;
- supp_best_fixed: all 4 panels;
- supp_spatial: `supp_s1_batch_variance` (picture unchanged) and `supp_s1_ol_variance_evolution` (slopes now −0.10 / −0.52 / +0.30; not quoted anywhere).

The old final panels are backed up in `data/_pre_rerun_20261027/figures_final_panels/`, except `supp_s1_ol_variance_evolution`, which was not backed up; its old version survives inside `Closedloop_edit/images/supplementary/S1.pdf`. `collect_final_panels('dry')`: 132 present, 0 missing, 0 to prune. `f4_cl_reject_RR` was NOT re-exported (4G blocked).
**Why:** User approved the before/after comparison and asked for the final re-export.
**Next:** Re-link in Illustrator and rebuild Figure3.pdf / Figure4.pdf / OLbest.pdf / S1.pdf for the manuscript.

### 2026-10-27 — plot_ratio_windows: keep the tick just under the data
**Changed/Found:** `utils/plot_ratio_windows.m`. The y floor was min/1.15. After the onset fix, the lowest 0–1 s variance ratio (≈0.29) put the floor at 0.255, so the 0.25 tick disappeared from 3I. Now, if the nearest candidate tick below the data is within a factor of 1.3, the floor extends to just under it.
**Why:** Cosmetic regression seen in the before/after comparison.
**Next:** none.

### 2026-10-27 — Check: AL_0048 sine sessions (Figs 5/6) do NOT have the m14 dF/F offset or laser-channel bug
**Changed/Found:** Read-only check on the `load_bilateral.m` caches (`data/AL_0048_bil_07016 / 07141 / 07211.mat`, h5py; scratch scripts only, no code changed). Fig 5/6 score the OFFLINE pixel dF/F (`sess.right.dFoF`, from `getpixel_dFoF` on the SVD), not a logged dFk.

| session | n(timeBlue) | n(right.dFoF) | active laser (p99.9 V) | laser→dF/F lag, start / end-aligned | kk row ↔ frame (states vs offline dF/F; ref_raw vs laser, OL) | verdict |
|---|---|---|---|---|---|---|
| s1 2026-07-01/6 | 47244 | 47244 | 638 (3.94; 594 = 0.03) | +7 / +7 fr (r = −0.14) | states row = frame+1 (r 0.60); laser(f) ↔ ref row f−1 (r 0.995; ±11 fr r < 0) | OK |
| s2 2026-07-14/1 | 113302 | 113302 | 638 (3.30) | +6 / +6 fr (r = −0.14) | row = frame+1 (r 0.67); f−1 (r 0.995) | OK |
| s3 2026-07-21/1 | 150013 | 150013 | 638 (4.52) | +8 / +8 fr (r = −0.09) | row = frame+1 (r 0.68); f−1 (r 0.995) | OK |

Lengths match, so start- and end-aligned are the same; the laser→dF/F lag (+6..+8 fr ≈ 0.17–0.23 s ≈ 60–80° at 1 Hz, the expected OL phase lag) is causal, unlike m14's −6 fr lead. The kk clock (traj_on onsets, ref_raw, states) is within 1 frame of timeBlue in all three; an 11-frame shift is strongly anti-correlated. The 638 nm channel is the one that fired; the Fig 5 scripts never read a laser channel, and `ctrl_mpc_sine_export` already reads `inpVals638`.
Side note (not a bug of the m14 kind): `sine_ff_modes` / `sine_ff_across_sessions` / `sine_ff_plots_combined` index `dFoF(i0)` and `ref_raw(i0)` with the same kk row, while `ctrl_mpc_sine_export` uses row o ↔ frame o−1 (the rig's own pairing, `error = states + reference`). That is a 1-frame (~10° at 1 Hz) difference in absolute phase, the same in every mode, so mode differences and RMSE ordering are unaffected.
**Why:** Today's stats_v2 rebuild found m14 (AL_0048 2026-07-29/2) had dFk 11 frames short and end-aligned plus the laser read from the idle 594 nm channel (`ctrl_onset_fix.m`, `ctrl_laser_cmd.m`); 0.31 s would be ~113° at 1 Hz, so the sine sessions had to be ruled out.
**Next:** none for the fix (no `DFK_LEAD` entry needed; no Fig 5/6 number moves). Optional: decide whether Fig 5's absolute phase should adopt the o−1 pairing used by the MPC export (~10° shift, all modes).

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
