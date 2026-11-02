# Nick's JN review, export of 2026-11-02

Source: `nick papers/Closedloop_edit_review_2026-11-02.md` (lab PC only, untracked): 14 threads, 132 tracked changes.
Every tracked line matches JN push 5afa294. New since the 10-30 export (`REVIEW_NICK_2026-10-30.md`): C11-C14 and
26 tracked items, all in `results.tex` L12-41. He has read up to L41. Nothing from Fig 2 onward has an anchor yet.

Workflow (Aditya, 2026-11-02): Aditya pastes and edits on Overleaf section by section; no JN pushes from here. Labels
stay as traced (no threshold tuning). NC figures and captions go into JN only after Aditya reviews each one. Inside
L12-41 edit in place with tracking on; do not paste over his tracked edits or comment anchors.

## Comments

| # | Line | Ask | Status |
|---|---|---|---|
| C11 | L12-14 | Delete the opening sentences; the intro's last paragraph sets the stage | Agree: that paragraph covers all three |
| C12 | L19 | Cite two papers at "spontaneous activity" | Avitan & Stringer 2022 Neuron (10.1016/j.neuron.2022.06.019); Dimakou et al. 2025 Neuron (10.1016/j.neuron.2025.02.009). Neither is in `refs.bib` |
| C13 | L20 | Harmonize Fig 1, redraw D and E | Port NC Fig 1 with uppercase letters, on Aditya's review. Frame becomes B, latency C. Refs: 1B,C to 1B; 1F to 1C. Keep his citation in the panel A legend |
| C14 | L41 | Limit in Hz; is it 1/50 ms = 20 Hz? | No: 20 Hz is a full cycle of delay phase lag. Rule is crossover times delay below about 1 rad (Skogestad), so f is about 1/(2 pi tau): 3.2 Hz at 50 ms. Integrating-loop stability limit is 1/(4 tau): 5 Hz. With 38-58 ms: 2.8-4.2 Hz. JN Discussion L49 has this with the old 47 ms numbers (37-61 ms, 2.6-4 Hz) |

## His tracked edits to check

- **L20:** `(\citep{Matveev2024} ; Figure...)` prints double parentheses. Use `(\citealp{Matveev2024}; Figure...)`.
- **L21:** "quantified ... and take" mixes tenses; his C9 rule gives "took".
- **"Output" conflict:** abstract L93 (his edit) has fluorescence as the input and laser as the output, the controller's view. Results L21, L40 and the Fig 1E legend call fluorescence the output, the cortex's view. Raise with Nick.
- **L22:** "co-variate" to "covariate".
- **L40:** present tense against his C9; "reference" against his C3; XX.X and YY.Y-ZZ.Z placeholders.

## Latency numbers for L40

Whole closed-loop session, AL_0051 2026-07-29/2, same measurement as NC Fig 1c: n = 3539 laser updates, mean 25.46 ms,
median 24.00, SD 3.82, min 19.50, 99th percentile 40.00, max 43.50, 12.6% after the next blue frame.
JN's current panel 1F is the older test recording (n = 175, median 29 ms, 14-47 ms), and its caption says 200 cycles.

## Knock-on for later sections

- Pasting the Fig 5 section from 5afa294 brings 98aebf1's corrected numbers; JN's `Figure5.pdf` must be reassembled with it.
- From Fig 2 on, Results says "reference" 36 times and "target level" 0 times. Nick's C3 and his edits favour "target level".
- Evidence-based answer to C14, not run: closed- to open-loop error spectrum (Discussion L52 names it; RESEARCH archive 2026-10-06).
