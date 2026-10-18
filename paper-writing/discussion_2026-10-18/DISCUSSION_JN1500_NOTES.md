# Discussion, JNeurosci version: change log and items for the author (2026-10-18)

**File:** `discussion_jn1500.tex`, which replaces `discussion.tex`.
**Length:** 1,496 words including rendered citations (1,406 prose + 90 citation words), measured by `dwc.py`. JN cap: "Discussion (1,500 words maximum, including citations)" (official Information for Authors, pasted 2026-10-18).
**Build:** a scratch build (main.tex + this file + the Methods remark + new_refs.bib) compiles with no undefined references or citations, 41 pp. Nothing has been written into Closedloop_edit.

**Process:**
1. Two planners (a neuroscience-editor lens and an author-fidelity lens) wrote a plan, and the two plans were merged.
2. Three independent drafts were written: template-strict, author-voice and reviewer-proof.
3. Two judges scored them, and the best was synthesized from them.
4. Four checkers went over the result: facts against results.tex, every citation, causal language, and structure.
5. The text was revised and passed a final section-6 check (pass).
6. I then made the fixes listed below.

## Structure (rulebook section 1)
1. **Opening.** Cortical function first: linear on average, single trials ride on state-dependent ongoing activity. One number (15 sessions). Why it matters.
2. **C1 (main).** Linearity holds for the average, not single trials; the average is a sufficient plant. Includes your control argument in compressed form (monotone map, low-gain integral tracking, fixed-sign existence; formal detail in Remark 1) and state dependence as a property of the natural system.
3. **C2.** Feedback partly cancels activity predicted from the opposite hemisphere.
4. **C3.** Feedback separates variability into reachable and unreachable components (motion, 1–4 Hz, delay cap, reachability).
5. **C4.** Drive from the rest of cortex is observable but, at short leads, largely not forecastable. Includes the critique of other models, preview, and the MPC replay.
6. Limitations (one paragraph).
7. Implications.
8. Closing sentence.

## Change log (vs draft 2, ~3,100 words)
- **Headings and structure.** The six subsection headings were removed. The text was rebuilt as opening → four claim paragraphs → limitations → implications → closing.
- **Opening.** It now states cortical function, not method, with one headline number.
- **Control guarantee (theme 1).**
  - Shrunk to about four sentences: Logemann (with a "no single result covers our sampled PI loop" caveat) and Morari; the formal statement is left to the Remark.
  - Cut: Desoer–Lin, Desoer 1969, the Francis "need not know the equilibrium" sentence and the P-offset sentence.
  - The hand-tuned gains and empirical stability caveats moved to Limitations.
- **Modelling critique (theme 2).**
  - Moved into C4 and kept pointed: LFADS "over-approximates what is knowable in real time"; Lu 2025 and ZAPBench "neither models an actuator input".
  - Cut as coverage-style: CURBD, Vahidi, Yang 2018/2021, Galgali, rSLDS, Koopman, Chang, Steffen.
- **State dependence.** Kept as co-variation only. Added the paper's own evidence (the ratio vs stimulus-free activity barely changes, Fig S2) and a distinguishing test (per-quartile input–output models).
- **Contralateral (theme 3).**
  - The offset is attributed to feedforward calibration, and the integrator claim is limited "within its clamp".
  - The Li 2016 hedge stack was removed.
  - A distinguishing test was added (contralateral silencing).
- **Fig 4 (theme 4).**
  - P and R are named as slopes.
  - Attenuation and the initial-deviation result are cited to the table.
  - "Error that accompanied movement was rejected" replaces causal wording.
  - Alternatives are listed (saturation, the window spans stimulation, motion vs slow-power anticorrelation), with a test (CL/OL error spectrum, time at ceiling).
- **Delay derivation.** Kept, compressed, because Results L41 points to it.
- **Cut as unsupported.** Brammer (verified wrong as stated) and "7 of 13 sessions at the ceiling" (untraceable).
- **MPC (theme 5).**
  - One sentence (~40% and ~80% reductions; one session; "bound rather than measure").
  - Mayne for the constraint benefit.
  - Bolus 2021 is now the closest prior in vivo model-based work.
  - The Fig 6M phase-lag clause was cut for words.
- **Preview.** One sentence (*my fix after the workflow*): preview cancelled the phase lag feedback left (Fig 5H), so the Discussion mirrors the Abstract's feedback-vs-preview result.
- **Downstream use.** Moved to Implications as untested ("a prediction we did not test"). Hodgkin–Huxley, Wolff and Otchy were cut.
- **Limitations, now in one paragraph:**
  - uncorrected fluorescence;
  - spread to the readout;
  - sample sizes;
  - one site, awake head-fixed, inhibition only;
  - drift;
  - hand-tuned gains and empirical stability;
  - no sham, light-only, random-timing or P-only controls;
  - the integral role inferred, not isolated.
- **My fixes after the workflow:**
  - removed a dangling "the small gain" and moved the model-class caveat to the forecasting sentence;
  - fixed the Sanzeni sentence's logic ("although" → the ISN paradox concerns interneuron rates);
  - removed a "suggests … may" stack;
  - removed an unverified Valley clause ("cannot be split into neural and vascular parts");
  - fixed a missing space.

## Items needing your input
1. **Weighting vs the Abstract.** MPC (Fig 6) gets part of a paragraph in the Discussion but is absent from the Abstract, Significance Statement and Introduction. Preview now gets one sentence. Should the Abstract gain one MPC sentence?
2. **Controls statement.** The text says "There was no sham, opsin-free light-only, random-timing or proportional-only condition." Methods mentions none, but please confirm that none was ever run.
3. **"Seven of 13 sessions at the ceiling".** Cut as untraceable. Add a Methods line if you want it back.
4. **Delay derivation.** The 2.6–4 Hz cap is derived only in the Discussion, and Results L41 points there. Keep it here, or move it to Methods?
5. **Manuscript consistency.** Results L230 ("the integral term removes that offset") and Methods L901–902 ("empirical counterpart of the sensitivity function") are stronger than the Discussion. Align them?
6. **OUTLINE Q1.** Is the integral window M = 105 (3 s) also used for the 4 s sine trials? This bears on the Fig 5 offset.
7. **Bolus 2021 wording.** "adapted its estimator online to absorb model mismatch" (a parameter-adaptive Kalman filter). Confirm.
8. **Theme wording.**
   - "site-to-readout system" is used for your "input location to output location" system, and "nonlinear" is stated once, as a modelling stance.
   - Downstream effects appear only as a future use.
   - Confirm both.
9. **Referee risk not addressed (no key in the bibliography):** Churchland 2010 (stimulus onset quenches variability). Add it if you want C1 to pre-empt it.
10. **Structure option.** The C1 paragraph carries two sub-claims (the average suffices for control; state shows in responses). It could be split at no word cost.
11. **No [VERIFY] markers remain.** All 25 keys are in refs.bib or new_refs.bib, and each claim matches VERIFY_REPORT.txt.
