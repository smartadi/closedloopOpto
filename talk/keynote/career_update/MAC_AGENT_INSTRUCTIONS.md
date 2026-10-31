# Keynote update — career conversation with Philip Sabes (2026-09-24)

**For the agent on the Mac.** Edit Aditya's existing Keynote deck. Do not rebuild it or restyle it.
The deck stays a `.key` file and remains his main way of presenting.

## Ground rules
1. **Work on a copy.** In Finder, duplicate `NeuroAI2026_Deole_updated.key` and name the copy
   `NeuroAI2026_Deole_career.key`. Edit only the copy.
2. **Keep his look.** For every new slide, **duplicate an existing slide of the same kind** (named below)
   and swap its title, text and pictures. Do not add new themes, colors, fonts or decorations.
3. **Find slides by title, not by number.** Slide numbers can differ from the order listed here.
4. Pictures are in `panels/` next to this file. They are 600-dpi PNGs, so resize them freely.
   When a picture replaces an old one, match the old one's position and size.
5. Put the talking points from each slide's **Notes** item below into Keynote's presenter notes.
6. Finish by exporting a PDF next to the deck (`NeuroAI2026_Deole_career.pdf`). Flip through it and
   check that no text overflows and no picture overlaps another.

## Current deck (titles, in presenting order)
Closed-loop control of Mesoscale Cortical activity (title) · Simultaneous Recording and Stimulation ·
Motivation · Variability: Uncertainty to a Control System · Input-Output Characterization ·
State Dependent Stim Response · System Design · Controller Design · Real-time Implementation ·
Performance (CL vs OL) · Performance (feedforward / preview) · Internal Brain Model ·
Closed-loop error decomposition · Three factors drive the closed-loop error ·
The loop cancels what it sees · Disturbance rejection: real but modest ·
Backup: mixed-effects statistics · Conclusion · Future directions ·
Model Predictive Control: clean results · MPC performance · Thank you

**Leave these slides unchanged:** Simultaneous Recording, Motivation, Variability,
State Dependent Stim Response (already updated), System Design, Controller Design, Real-time
Implementation, Performance (feedforward), Internal Brain Model, all the Figure-4 slides, and both MPC slides.

---

## Edit 1 — Title slide (text only)
- Keep the title. Replace the line with the author names with:
  - Line 1: `Aditya Deole`
  - Line 2: `Postdoctoral researcher · Steinmetz Lab & Yazdan Lab · University of Washington`
  - Line 3: `PhD, Aeronautics & Astronautics (control theory)`
- Keep "University of Washington". Replace "NeuroAI 2026" with
  `with Anna Li, Eric Shea-Brown, Mehran Mesbahi, Nick Steinmetz, Azadeh Yazdan`.
- **Notes:** "30-second pitch: I trained as a control engineer and now use that toolkit on the brain.
  In the Steinmetz lab I built a real-time closed-loop system that holds mouse cortical activity at a
  target, using widefield imaging plus optogenetics. In the Yazdan lab I build input-output models of how
  primate and rat cortex respond to stimulation, so stimulation can be designed rather than guessed."

## Edit 2 — "Input-Output Characterization" (swap in the final Figure 2 panels)
The current slide shows three older panels: an example trace, dose-response and a normalized fit.
- Replace the dose-response picture with `panels/F2A_dose_response.png`.
- Replace the right-hand fit picture with `panels/F2C_LTI_fit_heldout.png`.
- Keep the example stim-trace picture on the left.
- Add `panels/F2D_heldout_R2.png` and `panels/F2E_model_swap.png` as a second row, or to the right
  if there is room. If it gets crowded, drop the example trace.
- Change the subtitle text to:
  `Linear (LTI) models predict held-out stim responses (pooled R² = 0.86) and largely transfer across mice.`
- Delete the leftover small text boxes "n=50 trials per stim" and "Cross validated" if they no longer
  sit next to the right picture.
- **Notes:** "A: dose-response is linear in all 4 sessions (slopes −0.34 to −0.96; 4 sessions, 3 mice).
  C–D: LTI fits predict held-out trials, pooled R² 0.86. E: a model fit in one session mostly carries
  over to other mice."
- *Fallback:* if individual panels are awkward, put the whole `panels/F2_full_composite.png` on
  the slide instead.

## Edit 3 — "Performance" (the CL vs OL slide, NOT the feedforward one)
The current slide has a variance-ratio plot, a tracking-error trace plot and a session-variance trace.
- Replace the tracking-error ratio plot with `panels/F3I_rmse_ratio.png`.
- Replace the variance-ratio plot with `panels/F3H_variance_ratio.png`.
- Replace the tracking-error traces with `panels/F3G_tracking_error.png`.
- Change the text boxes to:
  - `Closed loop cuts tracking error ~1.5× and trial-to-trial variance ~1.9× (1–3 s, p < 0.001)`
  - `15 sessions · session-aware mixed-effects stats · not driven by any single mouse`
- **Notes:** "These are the mean open-loop/closed-loop ratios in the 1–3 s window. The stats use a mixed
  model with session nested in mouse, and the between-mouse effect is about zero."

## Edit 4 — NEW slide "Same toolkit in primate cortex" (Yazdan Lab)
- **Duplicate "Disturbance rejection: real but modest"** (title + one picture + caption).
  Place the copy **after "Backup: mixed-effects statistics"**, which puts it just before Conclusion.
- Title: `Same toolkit in primate cortex (Yazdan Lab)`
- Pictures: `panels/Y1_primate_waveforms.png` across the top at full width, and
  `panels/Y2_primate_accuracy.png` bottom-left at about half width.
- Caption / text box (bottom-right), three lines:
  - `One shared model predicts optogenetic responses across a 78-electrode ECoG array`
  - `Held-out r² 0.92 (vs 0.89 for 78 separate models), with ~100× fewer parameters`
  - `Found: cortex saturates under strong drive (1.3–1.8×), so a nonlinear front end is next`
- **Notes:** "Macaque M1/S1 ECoG, optogenetic pulse trains from 10 to 150 Hz. We score only the frequencies
  the stimulus actually drives, and anything that doesn't repeat across trials (60 Hz hum, drift) is
  dropped automatically. The shared model matches or beats per-electrode models, and it is much better at
  50 Hz (0.84 vs 0.67) and 100 Hz (0.96 vs 0.76). If asked: part of the 150 Hz result is caused by our
  own preprocessing filter."

## Edit 5 — NEW slide "Designing the controller before the experiment" (Yazdan Lab)
- Duplicate the slide from Edit 4 and place it right after it.
- Title: `Designing the controller before the experiment`
- Picture: `panels/Y3_closedloop_simulation.png` (large, left two-thirds).
- Text box (right):
  - `Simulator fitted to primate data → closed-loop control of beta power (in silico)`
  - `Tracking error: 22% open loop → 16% with PI feedback, even under a surprise 1.4× disturbance`
  - `Actuator limits built in: one-sided light, saturation, stability checked first`
  - `Rat µECoG: theta coherence as a real-time brain-state marker for closed-loop plasticity`
- **Notes:** "I design and stress-test controllers in a simulator fitted to real data before spending
  animal time. This is adaptive experiment design."

## Edit 6 — "Conclusion" (add one bullet)
Add a 4th bullet:
`The same measure → model → control pipeline transfers to primate and rat cortex (Yazdan Lab)`

## Edit 7 — "Future directions" (reword to lead toward therapy)
Replace the four bullets with:
- `State-aware stimulation: dosing that adapts to movement and slow brain rhythms`
- `Predict, then act: learned forecasters + MPC recover ~88% of the ideal benefit`
- `Shared models across sites and subjects for fast calibration`
- `Toward larger brains and new readouts (blood-flow / ultrasound) for clinical neuromodulation`
- **Notes:** "The last bullet is the natural hook for asking about his work (functional ultrasound plus
  neuromodulation) without pitching directly."

## Edit 8 — "Thank you" (acknowledgements)
Under Co-PIs, add the line `Azadeh Yazdan (Yazdan Lab)`.

## Edit 8b — Conversation cheat-sheet in the "Thank you" presenter notes
Paste this block verbatim into the **presenter notes** of the "Thank you" slide. Only Aditya sees it,
in presenter view. If the slide already has notes, add this at the end.
```
CONVERSATION CHEAT-SHEET: Philip Sabes

WHO: CEO of Arbor Neuroscience (formerly Forest Neurotech), a Focused Research Organization within
Convergent Research. Wearable functional ultrasound + neuromodulation, aimed at depression and chronic
pain ("change brain circuits by design"). UCSF Professor Emeritus; MIT PhD (motor control + ML); did
brain-machine interface work at UCSF; also co-founder of Integral Neurotechnologies.

OPENING: Research Scientist, Data Analysis (SF, on site). The posting asks for control theory,
real-time closed-loop analysis, intervention optimization, adaptive experiment design, and imaging
analysis tools. Overlap: my widefield signal is blood-flow-like and mesoscale, much like fUS.

QUESTIONS
1. How did you decide when to move from academia to building a company?
2. For someone from controls / system ID, what separates people who do well in neurotech R&D
   from those who don't?
3. Postdoc to industry: better as a scientist role, or should I build software / engineering
   credentials first?
4. What's the hardest open problem in making stimulation predictable at Arbor: the modeling,
   brain state, or the hardware?
5. (Close) If a role like your data-analysis scientist opening fits, who should I talk to?
```

## Edit 9 — Order (optional)
Move "Backup: mixed-effects statistics" so it comes **after "Thank you"**, making it a true backup slide.

---

## Optional: automate with AppleScript (`osascript`)
Keynote has an AppleScript interface. These commands are useful, but check the result visually after each step:
```applescript
tell application "Keynote"
  set d to front document
  -- find a slide by its title
  repeat with i from 1 to count of slides of d
    try
      if object text of default title item of slide i of d contains "Disturbance rejection" then set src to i
    end try
  end repeat
  duplicate slide src of d to after slide src of d          -- new slide inherits the look
  set s to slide (src + 1) of d
  set object text of default title item of s to "Same toolkit in primate cortex (Yazdan Lab)"
  set presenter notes of s to "…"
  delete every image of s                                    -- then add new ones:
  make new image at end of images of s with properties {file:(POSIX file "/path/to/panels/Y1_primate_waveforms.png"), position:{60, 110}, width:880}
end tell
```
If AppleScript can't reach an element (for example free text boxes), edit it in the Keynote UI instead.

## Panel list
| File | Source | Used in |
|---|---|---|
| F2A_dose_response.png | paper Fig 2A | Edit 2 |
| F2C_LTI_fit_heldout.png | paper Fig 2C | Edit 2 |
| F2D_heldout_R2.png | paper Fig 2D | Edit 2 |
| F2E_model_swap.png | paper Fig 2E | Edit 2 |
| F2_full_composite.png | paper Fig 2 (all) | Edit 2 fallback |
| F3G_tracking_error.png | paper Fig 3G | Edit 3 |
| F3H_variance_ratio.png | paper Fig 3H | Edit 3 |
| F3I_rmse_ratio.png | paper Fig 3I | Edit 3 |
| F3_full_composite.png | paper Fig 3 (all) | spare |
| Y1_primate_waveforms.png | Yazdan sysID P1 (top row) | Edit 4 |
| Y2_primate_accuracy.png | Yazdan sysID P2a | Edit 4 |
| Y3_closedloop_simulation.png | Yazdan NETSIM PI control | Edit 5 |
