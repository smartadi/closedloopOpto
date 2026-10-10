# arXiv-first, JNeurosci-next: what to change (2026-10-10)

Language pass is on `Closedloop_edit` branch `draft` (commit e47efb2), not yet on `main`/Overleaf.
Word-level diff: `paper-writing/language_pass_2026-10-10_diff.html`.

## A. Must fix before arXiv (a day or less)

1. **Author block is broken in the PDF.** `main.tex` L71-78: `\affil[12,3,4,5]{Department of , University of Washington ...}`.
   Fill departments and fix the index list. Confirm author order with Nick.
2. **Fig 4G exclusion is post hoc but Methods calls exclusions pre-specified.** One sentence in Results
   ("we set this criterion after inspecting the data") plus the all-13-session RR next to the 11-session RR.
   Needs one number from `f4_cl_reject_lmm.m`.
3. **Fig 4 state measures come from the controlled signal, during stimulation (circularity).** If the
   stim-blind (contralateral) δ check cannot run before posting, add a limitation sentence in the
   Discussion that says it plainly. Referees will find this first.
4. **Stimulation units.** Impulses are 0-1.8 mW, saturation is "36 mW (5 V)", and Methods quotes command
   volts. Use one unit (mW at the brain surface) in the main text and give the V->mW map once in Methods.
5. **Results L18 contradiction.** The same paragraph says the spot is "adjacent to" the output kernel and
   "overlaps closely" with it. Pick one.
6. **Strip mouse IDs from the main text and captions** (results 2x `AL\_00xx`, supplementary 3x; Methods 41x).
   Use Mouse 1-4 as in Fig 2 (arXiv-optional, JNeurosci-required).
7. **Fig 2D "he ld-out" label** (Illustrator) and re-place the revised Fig 2/3 panels.
8. Methods has 30+ `%% FILL` comments. They are invisible in the PDF, so arXiv can go without them, but
   the visible ones that matter for reproducibility are: illumination power density, video frame rate +
   motion ROI, loop-interval p50/p99, code URL (L314), window/taper for the PSD (L993), software versions (L1225).

## B. Flow / major edits for JNeurosci (after arXiv)

1. **Section order.** JNeurosci puts Materials and Methods before Results. The Discussion currently leans on
   Methods objects (`Assumption`, `eq:pi`, `eq:kr`, `eq:nl_state`); fine once Methods comes first, but
   define the PI law in one sentence in Results so the Results read on their own.
2. **Discussion is ~2,600 words; the JNeurosci limit is 1,500.** Cuts that cost nothing:
   - "Future directions" says MPC three times (low-level-controller paragraph, the MPC simulation paragraph,
     and the data-driven-controller sentence). Keep the MPC simulation paragraph only.
   - Drop the translational paragraph (epilepsy, electrophysiology) or cut it to one sentence.
   - Fold "Relation to prior work" into two sentences in the opener; the Intro already covers it.
   - Shorten the "RMSE is a poor summary for moving references" paragraph to two sentences.
3. **Fig 4 Results are a wall of statistics.** Keep the story in the text (motion: disturbance grows but the
   loop holds it; 2-4 Hz: open loop unaffected but the loop loses the output) and move the eight slopes +
   four attenuation slopes to a table (Table 1 or Extended Data).
4. **Lead Fig 4G with the paired OL-vs-CL comparison** (RR 1.25 vs 0.72, 11/11). It is scale-free, so it does
   not depend on the leak correction or the disturbance scaling; the CL-only RR = 0.58 then becomes the
   magnitude estimate. Currently the order is reversed.
5. **Move Results L121 (validity of the trial-averaging assumption, sources of variability) to the
   Discussion limitations.** It interrupts the Fig 3 story.
6. **Fig 2G vs control.** The text now says the motion-vs-control difference was not tested directly. Either
   run the test (TASKS item) or keep the softened wording; do not restore "so movement alters the evoked response".
7. **Captions carry interpretation** (2G especially: "the motion effect exceeds its control ... therefore
   reflects ..."). JNeurosci captions should describe; move the reasoning to Results.
8. **Supplementary -> Extended Data** naming (Figure 4-1 etc.) for JNeurosci.
9. **Figure citation style.** Body text now says "Figure~\ref{...}" (your Overleaf choice) and the Discussion
   was switched to match. Captions still use the same. Keep one style.

## C. Claims I softened in the language pass (check you agree)

- Results: "The linear relationship guarantees the stability of a linear feedback controller" ->
  "An approximately linear plant also makes it straightforward to design a stable linear feedback
  controller around it." (Linearity alone does not guarantee closed-loop stability; gains and delay do.)
- Results 2G: "so movement alters the evoked response itself" -> "which suggests ...; we have not tested
  this difference directly."
- Results: "This indicates that the impulse response must be identified per session" kept, reworded.
- Discussion opener now summarises all results (state dependence, contralateral rejection, preview);
  before, it covered only tracking and variance.
- Discussion: "guaranteed by Trial-averaging Assumption" -> "under the trial-averaging Assumption".
- Discussion: `\citep{newman...}` / `\citep{bolus...}` at sentence start -> `\citet` (rendered as
  "(Newman et al.)" before, a typo).
