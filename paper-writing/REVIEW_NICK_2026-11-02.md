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
| C13 | L20 | Harmonize Fig 1, redraw D and E | Port NC Fig 1 with uppercase letters, on Aditya's review, but with the latency panel from the test recording and panel D's bracket at 29 ms. Frame becomes B, latency C. Refs: 1B,C to 1B; 1F to 1C. Keep his citation in the panel A legend |
| C14 | L41 | Limit in Hz; is it 1/50 ms = 20 Hz? | No: 20 Hz is a full cycle of delay phase lag. Rule is crossover times delay below about 1 rad (Skogestad), so f is about 1/(2 pi tau): 3.2 Hz at 50 ms. Integrating-loop stability limit is 1/(4 tau): 5 Hz. With 43-61 ms: 2.6-3.7 Hz. JN Discussion L49 has this as 37-61 ms and 2.6-4 Hz, using "about half" of 47 ms for the average; the measured mean is 29 ms |

## His tracked edits to check

- **L20:** `(\citep{Matveev2024} ; Figure...)` prints double parentheses. Use `(\citealp{Matveev2024}; Figure...)`.
- **L21:** "quantified ... and take" mixes tenses; his C9 rule gives "took".
- **"Output" conflict:** abstract L93 (his edit) has fluorescence as the input and laser as the output, the controller's view. Results L21, L40 and the Fig 1E legend call fluorescence the output, the cortex's view. Raise with Nick.
- **L22:** "co-variate" to "covariate".
- **L40:** present tense against his C9; "reference" against his C3; XX.X and YY.Y-ZZ.Z placeholders.

## Figures are ahead of the text (JN 89b40a7, on Aditya's push 54fae66)

- **Fig 1:** panels are now A-E. References: results L21 `1B,C` to `1B`; L40, Discussion L49 and Methods L100 `1F` to `1C`. Caption: port NC's with uppercase letters, n = 175, keep Nick's citation in A.
- **Fig 2:** caption A, C, D, F, G and two text changes (five amplitudes; drop the peak-normalized sentence). Aditya has already typed edits in the section's opening lines, so re-cut it from the latest push.
- **Fig 4:** panel D says OL slope, CL slope, CL/OL; the caption and text still say predictability, regularizability, attenuation. Aditya's frequency decision applies here (relative 2-4 Hz carries no claim; RESEARCH 2026-11-02).
- **State supplement:** letters shift, A-F to D-I, with new A-C. Results L94, L98.
- **Fig 5, S1, S3:** captions already fit.
- **Frequency limit:** results L41-43 (Aditya, 54fae66) give about 1.5 Hz; Discussion L49 gives 37-61 ms and 2.6-4 Hz, which the test recording makes 43-61 ms and 2.6-3.7 Hz. Reconcile in the text pass.

## Latency numbers for L40

Use the latency test recording, not a whole session (Aditya, 2026-11-02): test 2026-04-23/1, n = 175, mean 29.03 ms,
median 29.00, SD 8.30, min 14.00, 99th percentile 44.37, max 47.00. JN's panel 1F already shows this recording, but its
caption and Methods L100 say 200 cycles. NC Fig 1c and its text use the whole session (D8) and are on hold with NC.

## Knock-on for later sections

- Correction: Overleaf already has 98aebf1's Fig 5 numbers (Aditya's push 54fae66 carries them). JN's `Figure5.pdf` went up in 89b40a7.
- From Fig 2 on, Results says "reference" 36 times and "target level" 0 times. Nick's C3 and his edits favour "target level".
- Evidence-based answer to C14, not run: closed- to open-loop error spectrum (Discussion L52 names it; RESEARCH archive 2026-10-06).
