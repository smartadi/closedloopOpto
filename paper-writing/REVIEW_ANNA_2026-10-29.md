# Anna's review, 2026-10-29 (read through Fig 4)

Source: Anna's notes, a 4-page PDF exported from Notion and sent to Aditya on 2026-10-29
(`C:\Users\aditya\.claude\uploads\e672ee85-ae07-4ce4-a739-d9ab3587f312\f19bce06-notes_on_closed_loop_paper.pdf`).
She read the compiled paper through Fig 4. Her summary to Aditya was "you gotta fix the claude slop".
Every note is listed below, with her words verbatim, where it lands, a diagnosis, a proposed fix and a status.

Status: `OPEN` (not started) · `DRAFT` (a draft was given in chat, waiting on Aditya) ·
`DECIDE` (needs Aditya's call before any work) · `DONE` (cite the commit).

---

## For the agent picking this up

- **Process (Aditya, 2026-10-29):** "lets go one by one at each point". Take ONE item at a time, show
  the proposal, wait for feedback, then move on. Update this file's status column as items close.
- **Which draft? Ask first.** Since 2026-10-29 there are two independent drafts (`paper-writing/CLAUDE.md`):
  - JN = `C:\Users\aditya\Documents\projects\Closedloop_edit\` (arXiv, then JNeurosci).
  - NC = `C:\Users\aditya\Documents\projects\Closedloop_nc\` (Nature Communications), forked from JN
    `main` 98aebf1, which is the text Anna read.

  Her **text** notes (G1, G2, G4, T3–T8, captions) apply to both drafts until NC is restructured, so
  ask Aditya which draft each fix goes into. **Panel** fixes (F1–F4 producers) are single-sourced in
  `brain_paper`, so they reach both drafts. Each draft has its own Illustrator assembly: JN from
  `paper/`, NC from `paper/figures_final/nc/`.
- **Manuscript files:** `main` only (no `draft` branch since 2026-10-27). The abstract and significance
  statement are in `main.tex`, plus `introduction.tex` and `results.tex`. Line numbers below are JN
  `main` 98aebf1 (2026-10-29). Re-grep before editing, especially in NC.
- **Edit rules** (memory `feedback_manuscript_overleaf_only`):
  - Aditya edits on Overleaf. Give LaTeX snippets in chat by default, and edit files only when he asks.
  - Never paste back text he cut.
  - Write one sentence per line. Files are CRLF.
  - Ask before pushing `main`.
  - Some flagged sentences are Aditya's own Overleaf wording (intro L7–10), so propose changes; don't impose them.
- **Figures:**
  - Producers write to `paper/images/<figN>/`.
  - Final panels go through `PAPER_FINAL` → `utils/paper_final_mirror.m` → `paper/figures_final/panels/`.
    Only panels listed in `paper/figures_final/MANIFEST.txt` are written.
  - Illustrator assembly of `FigureN.pdf` is Aditya's job.
  - House style is locked (root `CLAUDE.md`): 6 pt bold font, condition colours (OL red, CL blue),
    and state windows/estimators.
  - Do not change any analysis window to fix a label.
  - Anna reviewed `Closedloop_edit/images/FigureN.pdf`, and some of those predate re-exported panels
    (TASKS: "Re-place revised panels"). Check the current panel before fixing.
- **Logging:** one `RESEARCH.md` Change Log entry per change, then commit and push (`git sync`).

---

## Cross-cutting: what the "slop" is (sweep for it, not only at the sentences she quoted)

These habits recur through the intro, the Results up to Fig 4, and the captions. Fixing them is item G4.

1. **Definitions wedged into a sentence as asides:**
   - "the plant, the system the controller acts on," (intro L30);
   - "the latency, the delay from a camera exposure to the light it triggers," (intro L22);
   - "The initial deviation, the difference between output and reference at stimulation onset, settles…" (results L138);
   - "*attenuation*, the change with state in the error ratio, the fraction of open-loop error left under feedback;" (results L203, two nested);
   - "the best fixed input, the constant command that would have minimized…, computed on the same trials, which favors open loop" (results L143).

   Fix: define the term in its own short sentence, or drop the definition.
2. **One sentence carrying a paragraph.** Results L81–82 (dip/rebound) is about 90 words of clauses
   and numbers in brackets. Intro L14 and results L88 are similar. Fix: one claim per sentence, and move
   the numbers to the caption, a table or Methods.
3. **Clause chains joined by "and … , and … , so …"** (intro L30, L53; results L209). Fix: split them.
4. **System specs presented as general facts** (intro L21–22). See T6.
5. **Greek band names in figures** (δ) where the text uses frequencies. See F2.7 and F4.3.

---

## General notes

| ID | Anna (verbatim) | Where | Diagnosis / proposed fix | Status |
|---|---|---|---|---|
| G1 | "is this geared towards a neuroscience audience? and meant to be a non methods paper? if so the stuff like "the error left under control is informative about brain state" should really come before "we demonstrate a system for closed-loop..."." | Abstract, `main.tex` L89–99 | The state result is sentence 7 of 11. "informative about brain state" is the last sentence; the first half is the method. Lead with the question and the finding. This is the abstract only: the intro's control-first paragraph order (locked 2026-10-20) is untouched. Draft below. | DRAFT |
| G2 | "have to get ahead of "what is this for" - especially in significance statement" | Significance, `main.tex` L104–108 | It opens with "We introduce a closed-loop control framework…". Open instead with the problem it solves: testing what activity contributes needs it set precisely, and state makes open-loop responses vary. Then say what closed loop gives, then what the residual error reveals. Drop the R² = 0.76 detail. | OPEN (after G1), JN only: the NC draft has no Significance Statement (NC 47c9abf) |
| G3 | "figures could use some polish - many are hard to read" | Figs 1–4 | Per-panel items F1–F4 below. Also check that no panel was scaled below 6 pt at Illustrator assembly: she had to zoom to 300% for Fig 1E. | OPEN |
| G4 | "several sentences with many clauses that are hard to follow" | Intro and Results through Fig 4, plus captions | Sweep for the patterns above. Her two examples are T3 and T4. | OPEN |

### G1 draft abstract (given in chat 2026-10-29; Aditya has not answered yet)

1. Testing what cortical activity contributes to behavior requires setting it precisely, but the same stimulus evokes different responses from trial to trial, depending on the ongoing brain state.
2. Open-loop stimulation, fixed in advance, therefore sets activity only on average.
3. Closed-loop control adjusts the stimulus from a real-time readout, so it can correct each trial, and the error it leaves shows which fluctuations it cannot correct.
4. We closed the loop on mesoscale cortical activity in awake mice, reading out wide-field calcium activity next to a site of optogenetic inhibition.
5. Within a session, the trial-averaged response to light was approximately linear and time-invariant, so we could tune a linear controller from it.
6. Feedback held activity at a reference below baseline more accurately than open-loop stimulation in all 15 sessions from 4 mice, and reduced trial-to-trial variability.
7. The error left under feedback depended on brain state.
8. It grew with 1–4 Hz power, which marks large, slow fluctuations, by about as much as open-loop error did, whereas feedback removed a larger share of the error that accompanied movement.
9. A linear predictor from the opposite hemisphere estimated each trial's disturbance, and feedback partly rejected it.
10. In one mouse, preview cancelled the phase lag when tracking a time-varying reference, and in a simulated replay of recorded trials, a model-predictive controller lowered the error left by feedback by about 40%.
11. Closed-loop control thus sets mesoscale activity more precisely than open-loop stimulation, and the error it leaves marks the fluctuations a fixed linear controller cannot remove.

The draft is about 220 words. The JNeurosci limit of 250 is recalled, not verified. It folds Aditya's two opening
sentences into sentence 1 and replaces "slow-wave-like delta-band" with "1–4 Hz power".

---

## Text notes (intro and Results)

| ID | Anna (verbatim) | Where | Diagnosis / proposed fix | Status |
|---|---|---|---|---|
| T3 | (quotes intro L6–8) "also here the transition from brain state to trial-to-trial variability is abrupt. and after this it goes back into spontaneous states." | `introduction.tex` L7–8, then L10 | L7 stacks four causes into one clause. L8 jumps to "therefore … highly variable; especially…". L10 then returns to modelling states. Rewrite the P1 ending as one bridge (state varies → the same input meets a different circuit each trial → responses vary), then open P2 on modelling. L10 also has grammar errors ("In literature", "through a dynamical systems") and L7 has a double space. Parts are Aditya's Overleaf wording. | OPEN |
| T4 | "(another one - five clauses!!!)" (quotes intro L29–30) | `introduction.tex` L30 (Bolus) | Split it into two sentences and drop the "plant" aside. For example: "Bolus et al. fitted a model of how thalamic firing responds to light and designed controllers from it. These controllers made firing track time-varying targets, rejected unmeasured disturbances and changed its trial-to-trial variability." | OPEN |
| T5 | "here - i think modeling driving inputs well is conflated with forecasting. or do you mean that you use the input to determine what is upcoming? at least that is not what ziyu was doing in this paper" | `introduction.tex` L12 (`lu2025benchmarking` = Ziyu Lu's benchmark) | In the PDF, her note sits between the Bolus excerpt and the excerpt of L11–13. It refers to L12. The sentence joins two separate claims with ", and even", so it reads as if poor input modelling causes the 1.5 s limit, and Ziyu's benchmark uses no inputs. Split it: (1) these models do not observe the movements and inputs from other areas that drive a region; (2) separately, stimulus-blind forecasts of spontaneous wide-field activity stay informative for only about 1.5 s. Match the Discussion's correct wording (`discussion.tex` L29: "stimulus-blind, univariate forecasts … about 1.5 s"). Also fix "with considerable amount of uncertainty". | OPEN |
| T6 | "is this supposed to be a broad overview of mesoscale imaging? these specs are specific to our system and not necessarily properties of mesoscale imaging in general" (quotes intro L19–23) | `introduction.tex` L21–22 | 10 mm, 35 Hz, 24 ms and 0.11 s are our rig and our fit, not properties of mesoscale imaging. Keep P2 general: what mesoscale activity is, why it suits the test. Move the specs to the last intro paragraph (L47 already gives 35 Hz) or to Methods. Aditya approved this paragraph on 2026-10-21, including the latency clause, so this reopens his decision. | DECIDE |
| T7 | "also this is not precisely true:" (quotes intro L48 "The light excites inhibitory neurons that express an opsin, so it can only lower the activity.") | `introduction.tex` L48; also `results.tex` L18; significance `main.tex` L105 | Facts from `methods.tex` L21–22: GCaMP8s in excitatory neurons (CaMKII-tTA;tetO-GCaMP8s), and ChrimsonR (an excitatory opsin) under DLX2.0, so in inhibitory interneurons. The light raises interneuron activity and lowers the imaged excitatory activity, and the response rebounds after the dip (Fig 2). Proposed: "The light excites inhibitory interneurons that express the opsin ChrimsonR, which suppresses the excitatory neurons we image, so the input can push the readout only below baseline." Results L18, "co-expressing GCaMP and an inhibitory opsin", is wrong: ChrimsonR is not an inhibitory opsin, and the two are not in the same cells. Fix all three places together. | OPEN |
| T8 | "for the results, you should explicitly say 'open loop' 'closed loop' as you have spent a lot of intro time describing, it would be clearer here as you've just described the closed loop system but this is an open experiment" | `results.tex` L49 (start of the Fig 2 section) | Say that the impulse experiments were open loop (input fixed in advance, no feedback). Check the section heading too. | OPEN |

---

## Figure 1

### Anna's Fig 1 redraw (her Claude chat "Scientific figure formatting", read 2026-10-29)

Shared as https://claude.ai/share/530f9b84-ccfa-4a2e-9707-debbb3cb2178, now opened for aditya.158@gmail.com.
The chat text is readable, but **its files are not**: the share says "This link doesn't give access to
this file". Anna has to send the files herself: `Panel e control loop.svg`, `Panel d architecture.svg`,
and `Figure full 180mm` as .pdf, .svg and .png. Drop them in `brain_paper/paper/from_anna_2026-10-29/`.
What the chat produced:
- **Layout:** 180 × 112 mm in two rows. The top row (44 mm) is A 46 mm, then B, C and F at 38–42 mm.
  The bottom row is D (57 × 62 mm) and E (118 × 62 mm). A, B and F are placeholders; C is a low-res crop.
  180 mm is the Nature Comms double-column width, so this fits the NC assembly.
  She left open whether to reletter in reading order (A B C D / E F).
- **Style:** 6.5 pt Arial text, 8 pt italic serif for variables and gains, 10 pt bold panel letters,
  0.7 pt lines. Our house style is 6 pt bold (also inside Nature's 5–7 pt range). Pick one size for the
  whole figure, which is Anna's G3 complaint.
- **E changes:** "Open-loop gain" became "Feedforward gain" (correct: K_r is the feedforward term);
  "Controller" became "PI controller"; signals are labelled r, e, u, y; the stray output arrow and the
  mouse icon are gone ("System (mouse cortex)"); the widefield image is a placeholder
  (`widefield_image_REPLACE`, 14 × 14 mm).
- **⚠ E sign flip is WRONG for this paper.** Her chat changed the summing junction to e = r − y,
  calling the original positive feedback. Our Methods define **e_t = y_t − y_ref**
  (`methods.tex` eq. `eq:error`), because the light only lowers activity, so the command must rise when
  activity is above the reference. With a plant of negative gain, y − r and positive gains is negative
  feedback. When the SVG arrives, restore "+" on y and "−" on r, or show the plant sign explicitly.
  The original figure was right.
- **D changes:** labels are aligned; each arrow meets a rising edge of the trigger trace. The trace is
  schematic, not to scale. To make it to scale, use the blue-frame interval (35 Hz) and the
  24.0 ms median latency.
- **Her open question (latency definition):** Methods L100–101 time it from **exposure start** of the
  source frame to the laser command (24.0 ms median, Mouse 4 whole session). Fig 1F (200 loop cycles,
  14–47 ms) must say the same on its axis (F1.5). PAPER.md still flags 1F as having no generator in
  the repo; check `latencyAnalysis.m`.

Producers: A `wfpath.pdf`; B, D and E are Illustrator schematics (`schematic_optoephyswf (1).pdf`
in figures_final); C `controller-analysis/load_sessions.m` (`svd_frame_*`); F `latencyAnalysis.m`
(root; prints `paper/latency_histogram.pdf` with `print`, not `paperExport`).

| ID | Anna (verbatim) | Diagnosis / proposed fix | Status |
|---|---|---|---|
| F1.1 | "plz make text bigger i had to zoom in to 300% to read E" | E's block diagram is scaled far below 6 pt. Rebuild it at final size with 6 pt text. Easier once F1.4 strips E down. | DONE (NC): Anna's redraw at 118 x 62 mm, all text 7 pt (Nature's ceiling), 1 pt arrows, signs fixed; `paper-writing/fig1_nc_build.py` (brain_paper d910cf6, a4040d1). JN open |
| F1.2 | "i don't get the point of B, i think C does the job for that" | B (mouse cartoon with Output/Stim markers) repeats C (wide-field frame with the same markers). Drop B and update the caption letters and the Results refs (L21 cites Fig 1B,C). | DONE (NC 6a5502a): Aditya dropped B; the frame (now b) marks the readout kernel and the stim spot, and the figure is re-lettered a–e. JN open |
| F1.3 | "D is a nice idea, can be a lot bigger, show fewer exposure triggers, label the time between frames or just have some reference time labeled here" | Enlarge D. Show about 6 triggers instead of about 25, label the frame interval and the latency bracket (median 24 ms). Check the true exposure interval first: the LEDs alternate 470/405 nm, so blue exposures may be 1/35 s apart with violet ones in between. | DONE (NC): checked (Methods L66: 70 Hz alternating, 14 ms exposure, blue every 28.6 ms). D (now d) is 57 x 62 mm with 2 blue exposures to scale, laser update at 24 ms, latency bracket, 10 ms bar (`fig1_nc_build.py`). The 24 ms bracket waits on the latency decision under F1.5 |
| F1.4 | "conceptually D overlaps with E some, can you show just the controller parts or something? or at least make it clearer what i am supposed to be getting distinctly from E over D" | Both show widefield image → ΔF/F → controller → laser. Make D the data path and timing (hardware/software and trigger train) and E the control law only (reference, error, Kp, Ki∫, Kr feedforward, plant, output). Drop E's widefield image and mouse. | DRAFT (NC): Anna's redraw dropped the mouse and stray arrow; E keeps a small widefield frame (now the real SVD frame) on the feedback path. Whether to drop it too is open |
| F1.5 | "F unit labels can be clearer, latency of what and count of what" | x: "Loop latency, camera trigger to laser command (ms)", with more than the two end ticks (now only 14.0 and 47.0). y: "Loop cycles" (n = 200, from the caption). | DONE (NC, brain_paper a4040d1): replotted as c, "Loop latency (ms)" with ticks 10–50, "Loop cycles". ⚠ The data give n = 175, median 29 ms (test session 2026-04-23), not the 200 cycles and 24 ms median in the caption, d and Methods L100–101. Aditya picks one measurement (D8) |

## Figure 2

Producers: A `impulse-analysis/trace_overlay.m` (`imp_single_*`); B `impulse-analysis/dose_response.m`
(`imp_response.pdf`); C, D `impulse-analysis/imp_tf_cv.m`; E, F `impulse-analysis/imp_tf_run.m` →
`utils/imp_tf_robust_fig.m`; G `impulse-analysis/imp_state_var_combined.m`.

| ID | Anna (verbatim) | Diagnosis / proposed fix | Status |
|---|---|---|---|
| F2.1 | (T8, text) | See T8. | OPEN |
| F2.2 | "why a dot for the laser" | A marks the impulse with a red dot labelled "Stim". Replace it with a pulse mark at t = 0 (short bar or tick on a laser row) and keep the caption in sync ("Red dot shows the stimulation impulse"). | OPEN |
| F2.3 | "in B i feel like it makes more sense to have the yax be the scalebar rather than the x-axis? at least it's hard for me to interpret the laser power in B, i realize the numbers don't really matter" | B has a ticked y-axis but no x-axis, only a "0.25 mW" scale bar, so the laser powers can't be read. Give B a ticked x-axis, "Laser power (mW)". Check with Aditya whether he reads her note the same way. | OPEN |
| F2.4 | "is C a different subject than A? it's not critical i guess but why not just use the same example" | Yes: A = Mouse 5b (AL_0041), C = Mouse 1b (AL_0033, the best held-out R² of 0.95). Showing the best session in C also looks like a cherry-pick. Use one session for A and C. Which one is Aditya's call. | DECIDE |
| F2.5 | "what is D left supposed to provide beyond C except scaling?" | D-left (peak-normalized responses, all sessions) is meant to show that the dip shape is shared and only the rebound differs (results L83), but the panel doesn't say so. Either title it with that claim, or cut D-left and keep the R² summary (D-right). | DECIDE |
| F2.6 | "what is the purpose of E? i guess to me it just describes how well the opsin expresses across subjects? is there more? what is a pole supposed to be? did i miss this" | E (cross-session model swap) shows that dynamics are only partly shared, which is why the feedforward gain is rough and feedback corrects it (results L76–78). The panel doesn't say this. "Pole" comes from F ("time constants from the fitted poles"), and Results L80–82 use pole language with no plain explanation. Options: say the purpose in E's title and caption and rename F's measure in plain words ("time constants of the fitted model"), or move E and F to the supplement. | DECIDE |
| F2.7 | "in G i feel like just say 2-4hz power instead of del. also why del? isnt this supposed to be alpha? idk. what is relative vs absolute supposed to be" | Label by frequency and drop δ: "2–4 Hz power" and "2–4 Hz power (fraction of 0.4–10 Hz)". Fix the text to match (results L88, L94, L96–97, L102 use $\delta$; abstract "delta-band"). Define relative and absolute on the panel or in the caption. The naming background (why 2–4 Hz, why not alpha) is in `paper-writing/lit_delta_state_2026-10-15.md`. | OPEN |
| F2.7a | (Aditya, 2026-10-29) "we need to be clear on the differnece between relative and absolute powers for 2-4hz, and use refernece to show why we are using these specific bands" | NC `results.tex` L87, L93–97, L101–102, Fig 2g caption; `methods.tex` L479–482, L490 | Draft below. It removes "the sub-band least attenuated by the controller" (Methods L479), which is outcome-informed (review M19, 2026-10-03) and wrong: feedback raises 2–4 Hz power 1.44-fold during stimulation (RESEARCH 2026-10-11). Sources: `paper-writing/lit_delta_state_2026-10-15.md` (every reference checked). | DRAFT |
| X2.1 | (found while logging, not Anna's) | Panels B–F label sessions "Mouse 1", "Mouse 3", "M1", "M3", but the captions say 1b and 3c (session-label rule, `utils/paper_session_label.m`). The MANIFEST comment for 2A says "(Mouse 1b)", but the file is AL_0041 = Mouse 5b. | OPEN |

### F2.7a draft text (NC; given in chat 2026-10-29, not applied)

New bib keys, all checked in `lit_delta_state_2026-10-15.md`: Jacobs2020, Vanni2017, Donoghue2020eNeuro,
Ma2016 (Phil Trans B), Wright2017. Existing keys used: Crochet2006, Poulet2008, Vinck2015, Arieli1996, Shimaoka2019.
Reimer2014 is left out because its exact band was not verified.

- **Results L87** → (1) three measures, 1 s before onset: motion energy, and two measures of 2–4 Hz power in the readout.
  (2) Low-frequency power is high when cortex is synchronized and falls with movement and arousal
  [Crochet2006, Poulet2008, Vinck2015]; wide-field calcium imaging follows such rhythms up to a few hertz [Vanni2017, Jacobs2020].
  (3) Absolute = power in the band, so it grows with the amplitude of slow fluctuations.
  (4) Relative = that power divided by 0.4–10 Hz power, i.e. the share of activity in the band whatever its amplitude:
  doubling the signal quadruples absolute power and leaves relative power unchanged.
- **Results L93–97**: "absolute/relative $\delta$ power" → "absolute/relative 2–4 Hz power".
- **Results L101–102**: absolute = amplitude of ongoing activity that adds as a disturbance [Arieli1996, Shimaoka2019];
  relative = spectral state normalized for amplitude; the 5 s Fig 4 window resolves the full 1–4 Hz band, hence 1–4 Hz there.
- **Caption g**: "relative 2–4 Hz power (fraction of 0.4–10 Hz power) and absolute 2–4 Hz power"; drop "($\delta$)"; fix "state .".
- **Methods L479–482**: definitions; what each measures; absolute scales with expression/illumination/hemoglobin
  absorption, which act multiplicatively [Ma2016]; relative cancels that but follows the aperiodic slope [Donoghue2020eNeuro].
  Remove "the sub-band least attenuated by the controller".
- **Methods, new "Bands" paragraph**: low-frequency power indexes synchrony [Crochet2006, Poulet2008, Vinck2015];
  wide-field GCaMP synchrony was measured at 3–6 Hz [Jacobs2020]; quiet-wake wide-field mode near 2.6 Hz [Vanni2017];
  GCaMP–hemoglobin coherence peaks near 0.2 Hz [Wright2017]; 0.4–10 Hz spans the readout below its 17.5 Hz Nyquist;
  Fig 2g's 1 s window has 1 Hz resolution, so its denominator is in practice 1–10 Hz and its band starts at 2 Hz.

## Figure 3

| ID | Anna (verbatim) | Diagnosis / proposed fix | Status |
|---|---|---|---|
| F3.1 | "this one is pretty good. are the edge lines on the gray span necessary? it's hard to see the data behind it" | Black `xline(0)` and `xline(dur)` at stim onset and offset in `utils/analysisPlots_combined.m` (L77–78, 105–106, 154–155, 171–172, 205–206, 221–222, 246–247; panels A–D). Panels E and G have them too: grep `xline` in `variance_mse.m` and `step_response.m`. Remove them or make them faint; the gray band already marks the window. | OPEN |

## Figure 4

Producers: A `controller-analysis/f4_state_exemplars.m`; C `controller-analysis/f4_error_decomp.m`
(`f4_decomp_unique_sep`); D `controller-analysis/f4_row2_quartiles.m`; E `controller-analysis/f4_kernel_map.m`.

| ID | Anna (verbatim) | Diagnosis / proposed fix | Status |
|---|---|---|---|
| F4.1 | "A - would be nice to show the motion or relevant 2-4hz power timeseries above these" | Today only the motion exemplar carries a z-motion trace. Add above each exemplar the trace of the factor it is high in: z-motion, plus a sliding 1–4 Hz (or relative 2–4 Hz) power trace. The locked estimator (`utils/f4_bandpow.m` 'continuous' over [−2, +3) s) gives one number per trial, so a power time series needs a display-only sliding window. Choose the window, say so in the caption, and shade the [−2, +3) s state window. | OPEN |
| F4.2 | "E - are you sure about this? it looks bugged somehow. this is what i would expect" (her example image: a kernel map for an SSp pixel with one localized hotspot at the mirror spot in the other hemisphere, plus a group panel "Kernel maps (n = 15 mice)", regressor vs target hemisphere) | Checked 2026-10-29 (RESEARCH 2026-10-29). Not an indexing bug: 408 weights match 408 grid points. The ridge weights flip sign pixel to pixel (sum b = 1.55, sum abs b = 19.7, neighbour correlation about 0), so they show how the model cancels shared signal, not where the information sits (Haufe et al. 2014). Held-out R² is flat in λ (0.755 at λ → 0, 0.709 at λ = 1, 0.686 at λ = 10). Options: (1) plot a forward pattern (each contra pixel's covariance with the prediction) or a spontaneous-frame correlation map with the target, which should peak at the mirror spot. This needs session AL_0033 2025-04-15 e2's SVD reloaded, because no pixel series is cached. (2) Drop E (F already says G is contra-predicted). The script header's claim ("the contralateral HOMOLOG … should carry the strongest weight") is untested until (1) is done. | DECIDE |
| F4.3 | (from F2.7) | A, C and D use "abs δ", "rel 2-4 Hz" and "Abs δ". Switch to the text's labels: "1–4 Hz power" (Fig 4 absolute band is 1–4 Hz, locked) and "relative 2–4 Hz power". Fix in all three producers. | OPEN |

---

## Decisions waiting on Aditya

- **D1 (G1).** Abstract: lead with the finding, or keep the current order and fix only the wording? The draft is above.
- ~~**D2 (F1.2).** Drop Fig 1B?~~ Yes for NC (2026-10-29). JN still to decide.
- **D8 (F1.5).** Which latency does Fig 1 show: Mouse 4 (24 ms median, as Methods says) or the test session (29 ms, n = 175)? Either way, fix n in the caption and Methods in both drafts.
- **D3 (F2.4).** One session for Fig 2A and 2C. Which one?
- **D4 (F2.5).** Fig 2D-left: give it a claim title, or cut it?
- **D5 (F2.6).** Fig 2E/F: explain them in place, or move them to the supplement?
- **D6 (F4.2).** Fig 4E: forward or correlation map, or drop it?
- **D7 (T6).** Move the rig specs out of intro P2? This reopens the 2026-10-21 approval.
