# Methods restructure plan: `methods_rewrite.tex`

Date: 2026-10-16. Target: `Closedloop_edit/methods_rewrite.tex` (1478 lines; live Methods, `\input` at `main.tex:100`).
This is a plan only. No `.tex` file was edited. All line numbers refer to the file as it stood on 2026-10-16
(git HEAD of Closedloop_edit at that time). Apply edits bottom-up so the line numbers stay valid.

Word counts come from a rough script: LaTeX comments dropped, `$...$` counted as one word, commands
stripped. Tables and the algorithm box are included in their block's count.

| | Words (rendered, approx.) |
|---|---|
| Methods now | **~10,550** (only 10 lines short of 1,480; ~190 lines are `%%` comments) |
| Results (for scale) | ~6,400 |
| Discussion | ~2,000 |
| Methods proposed (Section E) | **~6,100** (about 42% shorter) |

---

## 1. Current outline

Line ranges include the comment lines inside each block. "cmt" = `%` comment lines (render nothing).

| Lines | Lines n | cmt | Words | Block |
|---|---|---|---|---|
| 1–28 | 28 | 28 | 0 | File header comment (stale; see Section G) |
| 29–31 | 3 | 1 | 3 | `\section*{Materials and Methods}` |
| 32–137 | 106 | 41 | 455 | **Animals** (incl. Table `tab:cohort`, 102–129) |
| 138–162 | 25 | 2 | 224 | **Surgery and habituation** |
| 163–222 | 60 | 14 | 406 | **Wide-field calcium imaging** |
| 223–294 | 72 | 16 | 547 | **Optogenetic stimulation** (power conversion 260–285 = ~300 w) |
| 295–308 | 14 | 6 | 55 | **Behavioral monitoring** |
| 309–311 | 3 | 1 | 3 | **Real-time control system** |
| 312–336 | 25 | 1 | 216 | — Hardware and software |
| 337–370 | 34 | 5 | 235 | — Online signal processing (`eq:dff`) |
| 371–385 | 15 | 0 | 115 | — `\paragraph{Two ΔF/F normalizations}` |
| 386–410 | 25 | 8 | 137 | — Trial structure |
| 411–413 | 3 | 1 | 4 | **Plant model and controller** |
| 414–446 | 33 | 4 | 207 | — Nominal model (`eq:nl_state/out`, `eq:lti_*`) |
| 447–485 | 39 | 0 | 255 | — Trial-averaging assumption (`assm:trial_avg`) |
| 486–503 | 18 | 5 | 62 | — Tracking error (`eq:error`) |
| 504–550 | 47 | 11 | 241 | — Feedforward term (`sec:ff_gain`, `eq:ff`, `eq:kr`) |
| 551–634 | 84 | 8 | 537 | — Proportional–integral feedback (`eq:pi`, `eq:integral`, Table `tab:gains` 599–633) |
| 635–645 | 11 | 0 | 86 | — Closed-loop stability |
| 646–685 | 40 | 5 | 230 | — Sinusoidal reference and preview (`eq:sine_ref`, `eq:preview`) |
| 686–699 | 14 | 1 | 144 | — `\emph{Metrics.}` (sine) |
| 700–702 | 3 | 1 | 2 | **System characterization** |
| 703–724 | 22 | 3 | 164 | — Impulse-response protocol |
| 725–748 | 24 | 5 | 132 | — Evoked suppression (`sec:inhib_energy`) |
| 749–754 | 6 | 0 | 39 | — Sustained stimulation |
| 755–772 | 18 | 7 | 94 | — Spatial extent of suppression |
| 773–804 | 32 | 0 | 378 | — Transfer-function fitting (`sec:tf_fitting`; Mouse 3 workaround 789–803 = ~220 w) |
| 805–814 | 10 | 0 | 124 | — `\emph{Held-out validation}` |
| 815–821 | 7 | 0 | 65 | — `\emph{Cross-session model swap}` |
| 822–846 | 25 | 1 | 323 | — `\emph{Time constants}` + design-model note (841–844) |
| 847–850 | 4 | 1 | 2 | **Controller tuning** (`sec:gain_opt`) |
| 851–892 | 42 | 6 | 312 | — Tracking cost (`eq:trial_cost`) + three named windows |
| 893–904 | 12 | 0 | 103 | — Gain-grid sweep |
| 905–948 | 44 | 4 | 209 | — Online gain search + Algorithm `alg:zo` (925–946) |
| 949–1010 | 62 | 10 | 411 | **Session and trial selection** |
| 1011–1013 | 3 | 1 | 2 | **Offline analysis** |
| 1014–1028 | 15 | 2 | 80 | — Cross-session pooling |
| 1029–1041 | 13 | 0 | 65 | — Brain-state measures (`sec:disturbance`): intro + initial deviation |
| 1042–1048 | 7 | 0 | 73 | — `\emph{Motion energy}` |
| 1049–1059 | 11 | 0 | 108 | — `\emph{Relative 2–4 Hz power}` / absolute power |
| 1060–1074 | 15 | 0 | 177 | — `\emph{Windows.}` |
| 1075–1112 | 38 | 2 | 317 | — `\emph{Spectral estimation.}` (`eq:bandpow`) + "Two analyses" 1100–1111 |
| 1113–1154 | 42 | 2 | 403 | — State exemplars and error decomposition (`sec:f4_decomp`, `eq:uniqueR2`) |
| 1155–1201 | 47 | 0 | 457 | — Impulse-response variability and brain state (`sec:imp_state`, `eq:l2_error`) |
| 1202–1213 | 12 | 0 | 142 | — `\emph{Stimulus-free window.}` |
| 1214–1223 | 10 | 0 | 96 | — `\emph{Per-session view}` |
| 1224–1285 | 62 | 3 | 547 | — Contralateral prediction and disturbance decomposition (`sec:disturbance_decomp`, `eq:rr`) |
| 1286–1293 | 8 | 4 | 5 | **Experimental Design and Statistical Analysis** (`sec:stats`) |
| 1294–1334 | 41 | 2 | 406 | — `\emph{Design.}` + software/df/reporting paragraph |
| 1335–1404 | 70 | 0 | 805 | — `\emph{Mixed models.}` (line 1371 alone is ~230 w) |
| 1405–1420 | 16 | 0 | 125 | — `\emph{Multiple comparisons.}` |
| 1421–1428 | 8 | 0 | 57 | — `\emph{Non-parametric tests.}` |
| 1429–1433 | 5 | 0 | 35 | — `\emph{Regression.}` |
| 1434–1445 | 12 | 1 | 80 | — `\emph{Corroborating tests.}` |
| 1446–1457 | 12 | 3 | 50 | **Data and code availability** |
| 1458–1478 | 21 | 21 | 0 | Commented-out ARX subsection |

Where the bulk is: **Offline analysis (~2,470 w)**, **Plant model and controller (~1,760 w)**, **Statistics (~1,510 w)**,
**System characterization (~1,320 w)**, and the four hardware blocks Animals/Surgery/Imaging/Stimulation (~1,630 w),
most of which is the system already published in Matveev2024.

---

## 2. Section A: Replace with a citation to Matveev2024

Proposed opening sentence for a merged **"Animals, surgery and imaging system"** subsection:

> "Animals, surgical preparation, the wide-field microscope and the galvanometer-steered stimulation laser were as
> described by \citet{Matveev2024}; we summarize them here and give in full only what differs from, or is added to,
> that system."

| # | Block | Lines | What it covers | Proposed replacement | Confidence |
|---|---|---|---|---|---|
| A1 | Animals, lines + virus | 39–50 | CaMKII-tTA × tetO-GCaMP crosses with Jackson stock numbers; DLX2.0-ChrimsonR-tdTomato in PHP.eB, Addgene #59171, retro-orbital P28–42; red-shift rationale | "We used CaMKII-tTA;tetO-GCaMP8s mice expressing ChrimsonR in forebrain inhibitory interneurons (retro-orbital PHP.eB AAV, DLX2.0 promoter) \citep{Matveev2024}, so that red light suppressed local excitatory activity." Drop the tetO-GCaMP6s line: the cohort table says every animal is GCaMP8s (comment 55–57). | High. Comment 51–54 says these lines and this construct come from Matveev2024, where AL_0033/0034 appear as Subjects 1 and 3. **Verify** that Matveev2024 gives the Jackson numbers, so they can be dropped. |
| A2 | Housing, handling, water restriction | 75–79 | Housing, light cycle, handling, ≥2 d head-fixation habituation, light water restriction, 10% sucrose at 2–5 s | Keep as is (~40 w); it already cites Matveev2024. Could become: "Housing, habituation and light water restriction followed \citet{Matveev2024}; during sessions mice received 10% sucrose at random 2–5 s intervals." | **Verify** that the random sucrose rewards are part of the Matveev2024 protocol. If they are, cut the sentence. |
| A3 | Surgery | 141–155 | Isoflurane, carprofen and lidocaine doses, VetBond, citric acid, Metabond, NOA81, 3D-printed chamber, titanium headpost, recovery | "Mice were implanted with a cleared-skull chamber and headpost under isoflurane anesthesia with carprofen analgesia, as described \citep{Matveev2024}, and recovered for at least one week before recording." (~35 w, down from ~190) | High: line 142 already says "following published procedures \citep{Matveev2024}". Keep anesthetic + analgesic + recovery in one sentence, since JNeurosci referees and IACUC-style checks look for them. |
| A4 | Recording setup | 157–160 | Head-fixed on a wheel, no task, light-blocking cone | "Mice were head-fixed on a wheel and performed no task \citep{Matveev2024}." Results:19 already says this. The cone could go. | Medium. **Verify** that the light-blocking cone is in Matveev2024. |
| A5 | Microscope optics | 166–173 | Triple-dichroic shared path, LEDs (Cairn OptoLED), 425/495/580 nm dichroics, 0.63× objective, 1× condenser | "We imaged through the single-photon mesoscope of \citet{Matveev2024}, which shares one light path between imaging and photostimulation." | High. Fig. 1A caption (results:29) already shows the path. |
| A6 | Camera and sampling | 175–181 | Basler acA2440-75m, 70 Hz, 3×3 binning to 560×560, pypylon, 9.7 mm field of view, 17.3 µm/pixel, blue/violet alternation, 1 ms sinusoidal LED ramps | Keep only: "Blue (470 nm) and violet (405 nm) illumination alternated frame by frame at 70 Hz, giving 35 Hz per channel, over a 9.7 × 9.7 mm field (17.3 µm per pixel)." Pixel size stays because the spatial-extent and kernel sizes depend on it. | Medium. **Verify against Matveev2024**: 3×3 binning to 560×560, the pypylon acquisition, and the 1 ms LED ramp. These may belong to this rig build rather than the published one. |
| A7 | Illumination safety | 193–195 | Same illumination as Matveev2024, no opsin activation, below photodamage | Keep one sentence, already cited. | High. |
| A8 | Offline preprocessing | 202–207 | Violet regression (hemodynamic correction), SVD with top 50 components, atlas registration, timestamp alignment | "Offline, we removed hemodynamic signals by regressing the violet- on the blue-channel signal, compressed the movies by SVD (50 components) and registered them to the atlas, all as in \citet{Matveev2024}." | Medium. **Verify** that Matveev2024 covers the registration method (FILL at 213) and keeps 50 components (comment 214–215 says it does: 98.2% of variance). |
| A9 | Laser and galvo optics | 226–233 | Omicron LuxX 638-200, 50 µm 0.22 NA fiber, Thorlabs GVS002 galvos, f = 100/300 mm scan and tube lenses | "Stimulation used the 638 nm galvanometer-steered laser of \citet{Matveev2024}, delivered through the imaging objective." **Keep** "AL_0051 was stimulated at 594 nm" (that is not part of the published rig; FILL at 234). | High for the 638 nm path. The 594 nm source is new and cannot be cited away. |
| A10 | Galvo calibration and coordinates | 236–240 | NI analog output, per-rig calibration files, bregma marked on the live image | "Targets were specified in mm relative to bregma \citep{Matveev2024}." | Medium. **Verify** that the calibration procedure is in Matveev2024. |
| A11 | Power-meter calibration | 247–249 | Thorlabs PM100D + S130C at the focal plane | "Laser power was calibrated at the focal plane as described \citep{Matveev2024}." | High (already cited). |
| A12 | Behavioral camera | 298–299 | FLIR Chameleon3, IR filter, 16 mm lens | "Face and forepaws were filmed with an infrared camera \citep{Matveev2024}." **Keep** the motion-energy definition (300–302): it is a locked analysis quantity. | Medium. **Verify** that Matveev2024 uses the same camera and that its motion-energy definition is the same (squared frame difference, z-scored within session). If it is identical, the definition can be cited too, keeping only "z-scored within session". |
| A13 | Galvo-sound delay control | 253–258 (comment only) | FILL: random 100–800 ms galvo-to-laser delay used in Matveev2024 | Nothing renders now. If the closed-loop sessions used it, one clause: "with the randomized galvo-to-laser delay of \citet{Matveev2024}". | Open (G4). |

**Must NOT be replaced by the citation.** These are new in this paper.

- The AL_0048 and AL_0051 actuation (84–87, 232–233). Per user 2026-10-13, never mention AL_0048's second opsin.
- The command path: serial link to the microcontroller, 0.01 V quantization, the 2.45 V ceiling, conversion of command to mW, peak-power convention, the ~1 mW power ceiling (260–285). Discussion:40 cites the ceiling.
- The 40 Hz sine-modulation sessions (287–290).
- The entire real-time control system (312–409). **Verify** that Matveev2024 does not already describe a real-time loop; I expect it does not.
- The blue-only online signal and corrected-offline-impulse split (198–201, 216–220). The Fig 2 vs Figs 3–5 signal choice is new.

Saving from Section A: about **1,630 → ~520 words**.

---

## 3. Section B: Cut implementation detail

Each row: line(s), a short quote of the current text, and the proposed wording. "Cut" means delete with no replacement.

### Hardware / real-time

| Lines | Current (≤15 words) | Proposed |
|---|---|---|
| 177 | "acquired through the pypylon interface" | Cut. |
| 180–181 | "LED pulse onsets and offsets were ramped sinusoidally over 1 ms" | Cut, or cite (A6). |
| 186–191 | "The acquisition thread forwarded every second frame to the control process…" (6 lines) | "The controller received only the blue frames (35 Hz)." The reason is already given at 198–201; see C1. |
| 236–240 | "Galvo mirror voltages were driven from a National Instruments analog output…" | "Targets were set in mm relative to bregma." |
| 260–272 | "serial link to a microcontroller at 2 Mbaud … 8-bit index in hundredths of a volt" plus the modulation-ratio list (2.0 / 1.5 / 1.3) | "The controller computed its command in volts (so K_r and K_p are in V per %ΔF/F and K_i in V per %ΔF/F per s). Commands were quantized to 0.01 V and limited to 2.45 V; in the first two sessions the laser input itself saturated at the same level." Drop the per-period modulation ratios. They are bookkeeping behind the mW conversion, which is what a reader needs. |
| 273–285 | "For the impulse sessions and the 2025 closed-loop sessions we used a single ratio…" | "We converted the recorded laser modulation voltage to peak power at the focal plane using the calibration nearest each session (1 mW per 3 V for the 2025 and impulse sessions), and report all amplitudes in mW. The maximum deliverable power was about 1 mW in most 2025 sessions and 1.6 mW in the first two." Keep the ceiling sentence because Discussion:40 relies on it. Note the FILL at 280 (source of the 1 mW per 3 V convention) is unresolved. |
| 314–321 | "The real-time system was written in Python… pinned to one core… semaphore… ring buffer" | "The control loop ran in Python as a dedicated real-time process, woken by each frame, separate from display and disk writing." (~25 w, down from ~85) |
| 322–325 | "The rig logged the control-loop interval for every sample and wrote a per-session summary…" | "The loop interval was logged on every sample (nominal 28.57 ms)." |
| 326–330 | "End-to-end latency … measured over 200 consecutive loop cycles, was at most 47 ms…" | "End-to-end latency, from camera exposure to stimulation command, was measured over 200 loop cycles (Fig. 1F)." Keep the 47 ms only once: Results:40 and Discussion:42 already give it (C10). |
| 332–334 | "Every session also wrote the git commit, branch, and working-tree state…" | Move to Data and code availability; it is already said at 1453–1454, so cut here. |
| 352–355 | "re-extracted trace reproduced the logged online signal (r = 0.995 in a test session)…" | Keep, shortened: "Offline, we re-extracted this signal from the compressed movie; it matched the logged online signal (r = 0.995) and did not depend on region size (10–21 pixels)." |
| 367–369 | "The rig also provides a second-order Butterworth low-pass… off in every session" | "No filtering was applied to y_t." (A filter that was never used does not need describing.) |

### Controller

| Lines | Current | Proposed |
|---|---|---|
| 540–547 | "Some sessions instead took K_r from the rig's online calibration block, which runs 20 open-loop steps…" | "In some sessions, K_r came instead from a 20-step open-loop calibration at the start of the session. Because open- and closed-loop trials share K_r within a session, the comparison does not depend on which route produced it." (~45 w, down from ~95) |
| 569–586 | "the proportional and integral terms are clamped separately at p = q = 5 … the term clamps (p = q = 5) lie above u_max" | Give the clamps once ("p = q = 5 V, above u_max, so only the output saturation is active"). Cut the windup sentence at 583–584, which repeats 581–583. |
| 626 | "read from \texttt{input\_params} columns 4--6" | Cut (variable name). |
| 641–644 | "rather than certifying gain and phase margins on a nominal model…" | Keep only the first sentence and the reason, in one sentence (~45 w). |
| 676–683 | "Three sessions in one mouse (AL_0048, inhibitory side; 2026-07-01, experiment 6, A = 3; …)" | Move the session list (dates, experiment numbers, A) into the `tab:cohort` caption next to the other non-cohort sessions. Here say "Three sessions from one mouse contributed (Table cohort)". Drop "experiment 6" / "experiment 1" (rig bookkeeping). |
| 689–691 | "the phase of each is atan2(b2, b1) and the lag is their wrapped difference" | "…and the lag is the difference of the fitted phases." |

### System characterization

| Lines | Current | Proposed |
|---|---|---|
| 705–713 | "with the acquisition of the controller sessions (blue frames at 35 Hz)… Command voltages were converted…" | "Impulse experiments were run open loop with the same imaging. Each stimulus was a single ~1-frame pulse (23–28 ms), separated by randomized intervals (median 5.7–9.8 s)." The ΔF/F definition is already at 371–384 (C2) and the power conversion at 273–285. |
| 723 | "Every nonzero amplitude had at least 44 trials." | Keep here; cut the repeat at 1173–1174 (C8). |
| 737–744 | "W spans the eight samples from 0 to 200 ms after onset at 35 Hz, inclusive…" | Keep the equation. Prose: "W spans the eight samples from onset to 200 ms. Traces are referenced to the onset sample. We use the window mean because it is less sensitive to single-sample noise than the trough." Move the reporting convention (742–744: medians with percentiles, or mean ± SEM) to the captions, which already state it. |
| 749–753 | Sustained stimulation (whole subsection) | Cut as a subsection. Its content (cross-trial variance under a constant command) is the S1D evidence already stated at 482–484 (C17). |
| 763–764 | "converted to mm² at 0.0173 mm per pixel, on native-resolution 560 × 560 maps" | "Areas use the 17.3 µm pixel size." |
| 782–783 | "with \textsc{tfest} (MATLAB System Identification Toolbox)" | "We fitted continuous-time transfer functions by prediction-error minimization." |
| 789–803 | Mouse 3 initialization workaround (~220 w): "\textsc{tfest} did not reach a good fit from its default initialization…" | "In one session (Mouse 3), whose onset-referenced response stayed offset from zero, we added a candidate model initialized from a fit to the baseline-referenced response plus one pole near the origin. It was selected only there (five poles, four zeros, R² = 0.99). The near-origin pole contributes <0.2% of the response and is not interpreted. Held-out refits rebuilt this initialization from training trials only." (~70 w) |
| 822–832 | Time constants: mode-overlap examples (60–68% of trough, 6% sustained suppression, the 0.117/0.154 s alternatives) | "Each pole p gives τ = −1/Re(p). We report the fastest (dip) and slowest (rebound) modes. τ longer than the 0.5 s fit window is not resolved and is drawn at the window edge. The dip τ is sensitive to model order by up to ~0.04 s among near-equivalent fits." Drop the per-mouse percentages. They are results, not method. |
| 833–839 | Bootstrap identifiability (300 resamples, 39%/72%/100%/3%) | "In 300 bootstrap refits, the slowest τ exceeded the fit window in most refits of three of four sessions, so we show no intervals." The percentages could move to Results:82 if wanted. |
| 841–844 | "The controller was designed on an earlier two-pole transfer-function fit…" | Cut: 443–445 already says it (C16). |

### Tuning / selection

| Lines | Current | Proposed |
|---|---|---|
| 864–873 | "Ranking individual trials by RMSE is the same as ranking them by squared error…" | "Values carry the units of ΔF/F. We average per-trial RMSE over trials." Cut the functional-ordering argument. It answers a question no reader asks and has an open FILL (871–872). |
| 874–877 | "Ĵ(K) is a sample estimate of the expected cost … (see Discussion)" | Cut: Discussion:38 says this in full (C20). |
| 886–888 | "The 1 s boundary is a fixed convention rather than a fitted changepoint: it is roughly five times…" | Keep as one sentence: "The 1 s boundary is a fixed convention, about five times the ~200 ms impulse dip." |
| 907–916 vs 925–946 | Online-search prose and Algorithm `alg:zo` give the same parameters twice (C21) | Keep the prose (one paragraph). Drop the algorithm float, or move it to the Supplement. |
| 914–915 | "The cost was evaluated over the stimulation window less two samples." | Keep; it is why S2C is not comparable with S2A/D. Then cut the repeat in the S2 caption (supplementary:106–109) to "(online cost; Methods)". |
| 978–983 | "We gate on this share and not on the settled mean because AL_0051 settled only slightly…" | Cut to: "Any threshold between 20% and 37% selects the same eleven sessions." |
| 986–988 | "One session has no decomposed full-frame wide-field recording, and in the other the online readout…" | "(two sessions lacked a usable full-frame recording aligned to the control readout)". |
| 1004–1008 + 1305–1308 | Blinding and sample size, stated twice | Keep one copy in Statistics → Design (C15). |

### Offline analysis

| Lines | Current | Proposed |
|---|---|---|
| 1016–1019 | "we pooled per-trial RMSE, cross-trial variance time-courses, and power spectra" | Drop "and power spectra". It is stale: the Welch analysis was removed (comment 1026). |
| 1044–1047 | "That signal is already an energy (a squared frame difference…) We did not square the z-score…" | "(the mean, not the mean square, of the z-scored signal, so that still and active trials rank apart)". Locked choice, kept in one clause. |
| 1080–1081 | "N_FFT = max(8192, 2^⌈log2 8N⌉) points" | "zero-padded to at least 8192 points". |
| 1091–1098 | "Summing native periodogram bins instead would tie the band edges to the segment length…" | Keep one sentence (locked choice, and a referee will ask why): "Integrating between exact band edges makes the measure independent of segment length (Spearman ρ = 0.9999 across 174–176-sample windows), which summing native bins is not." |
| 1100–1104 | "First, we regressed per-trial RMSE on each state separately … compared slopes across sessions" | Replace with "State effects on RMSE were tested with the mixed model under Statistics." What remains of the per-session OLS motion slopes is the corroborating test (Table fig4_state_stats, bottom), which Statistics → Regression already describes. |
| 1132–1135 | "In-sample R² cannot fall when a factor is added… (0.01–0.03 under a within-session permutation…)" | "Adjusted R² removes the positive floor that in-sample R² differences have at these trial counts." |
| 1146–1153 | Exemplar selection detail | Keep the rule (one sentence). Cut "Traces are drawn from −2 to +3 s…", which the caption shows. |
| 1180–1190 | Long description of what the panel draws (pooling over session × amplitude cells, normalization) | Keep the statistic (top/bottom-quartile ratio, geometric mean over sessions with range). The plotted normalization belongs in the Fig 2G caption, which already says "normalized within each session and amplitude so that 1 marks a typical trial". |
| 1234–1245 | "eroded by 12 pixels … 28 penalties log-spaced from 10^-8 to 10 (relative to the mean diagonal…)" | "Predictors were ~500 pixels on a uniform lattice over the contralateral cortex, z-scored. The ridge penalty was chosen without stimulation trials: it was the smallest penalty at which the predictor's spurious deflection on 200 laser-free catch windows stopped falling (held-out R² peaks near zero penalty and cannot set it)." |

### Statistics

| Lines | Current | Proposed |
|---|---|---|
| 1290–1292 | `%% FILL: software and versions…` | Already answered at 1310. Delete the comment. |
| 1310–1312 | "MATLAB R2025b (25.2.0.3055257, Update 2) … Mixed models were fitted with \texttt{fitlme}" | "Analyses used MATLAB R2025b (Statistics and Machine Learning Toolbox). Mixed models were fitted by restricted maximum likelihood." Drop the build string and function name. JNeurosci asks for software and version, not the build. |
| 1313–1322 | Satterthwaite cap explained twice ("capped at the number of sessions minus one" at 1314–1315, then the full rationale at 1317–1322) | "Fixed effects were tested with Satterthwaite degrees of freedom, capped at n_sessions − 1 so that no test borrows trial-level df (the cap can only make a test more conservative)." Drop the REML-vs-ML justification 1315–1317, or keep it as a 10-word clause. |
| 1327–1330 | "Every number quoted is generated by a single script from the saved model fits…" | "Every test is listed in full in the Statistical tables." |
| 1347–1354 | Full-window df-collapse story | "For the full 0–3 s window the mouse variance was non-zero and the df collapsed toward the number of mice, so we base inference on the 0–1 and 1–3 s windows, which together span it." The stat_tables:108 footnote already carries the numbers (C14). |
| 1371 | ~230 words: random state slope, the 200-simulation false-positive rates, the −0.95 correlation, the fallback plan, "all twelve fits used the full structure" | "Each session had its own uncorrelated random state slope, so state effects are tested against between-session variation. Omitting it inflated the false-positive rate (0.12–0.65 vs 0.03–0.05 at α = 0.05 in simulations of our design)." Drop the fallback plan and the −0.95 correlation. |
| 1380–1386 | "We read regularizability from the closed-loop slope directly, rather than from the condition-by-state interaction…" | Cut to "The condition-by-state interaction (gap trend) is reported only in the Discussion." Discussion:18 already makes the argument (C12). |
| 1395–1400 | Mouse-nested RR model explanation | Keep the model in one sentence. Its df ≈ 1.2 caveat is in Results:226 and the table. |
| 1400–1403 | "The impulse-response state analysis (Fig 2G) is reported descriptively…" | Cut: 1192–1200 already says it (C18). |
| 1408–1415 | Fig 2G family in the multiple-comparison paragraph; "Absolute low-frequency power clears its threshold in every family…" | Remove the Fig 2G family (Fig 2G is descriptive now; its threshold stays in the Table stat_fig2g caption). Remove the results sentence (1412–1415): the table marks survivors. |
| 1429 | "Per-session slopes of RMSE on motion energy (below)" | "(below)" points to nothing. Change it to "(Table fig4_state_stats)". |
| 1434–1443 | Corroborating-tests paragraph | Replace with one sentence: "Each claim rests on one primary test; corroborating tests, listed in the Statistical tables, agreed with it." Each table caption already names its corroborating tests (C13). |

---

## 4. Section C: Redundancies

"Keep" = the copy to retain. The other copy is cut or reduced to a pointer.

| # | Item | Location 1 | Location 2 (+) | Keep |
|---|---|---|---|---|
| C1 | Controller uses blue channel only; hemodynamic correction offline | methods:186–191 | methods:198–201; methods:216–220; discussion:44 | methods:216–220, merged with one clause from 198–201. Cut 186–191. Discussion:44 stays (it interprets). |
| C2 | Impulse ΔF/F = F / session-mean image | methods:378–381 (locked) | methods:709–712 | 378–381. At 709–712, point to it. |
| C3 | Onset-referenced trace | methods:739–740 | methods:1168–1169 | 739–740; 1168 says "(onset-referenced, as above)". |
| C4 | Transient / steady-state window definitions and the 1–3 s rationale | methods:879–891 | methods:968 ("settled means, 1–3 s"), 1119–1120, 1273–1275; results:137; fig4 caption results:162 | methods:879–891 is the single definition. Elsewhere in Methods use the names "transient" / "steady-state window" without re-deriving them. |
| C5 | RR definition and "referencing to own baseline keeps the setpoint offset out" | methods:1258–1277 | results:222 (near-verbatim second half); fig4 caption results:169; supplementary:148–158 (commented) | Methods. Shorten Results:222 to the formula plus "RR < 1 means rejection (Materials and Methods)". |
| C6 | "Decomposition is a construction; no claim from it" | methods:1253–1256 | results:220 | Results:220 (it is interpretation). Cut from Methods. |
| C7 | Leak magnitude 6–42%, median 23% | methods:1269–1270 | results:220 | Results (it is a result). Methods keeps only the correction procedure. |
| C8 | ≥44 trials per amplitude; 1516 trials | methods:723 | methods:1173–1174; stat_tables:12–47; fig2 caption | methods:723 plus Table stat_counts. Cut 1173–1174. |
| C9 | Standing-offset exclusion (2.2/1.4 %ΔF/F, 38%/59%, ≤17%, one-third threshold) | methods:963–983 | results:224 | Methods for the rule and threshold. Results keeps only "two sessions excluded for a standing offset (Materials and Methods)", or keep the numbers in Results and drop them from Methods. Do not keep both. |
| C10 | Loop latency ≤47 ms, ~half on average | methods:326–330 | results:40; fig1 caption results:34; discussion:42 | Methods for how it was measured; Results:40 for the number. Discussion:42 restates it to compute bandwidth, which is fine. Cut the number from Methods, or the "1.6 control intervals" clause. |
| C11 | State-window rationale (Fig 2 [−1,0) vs Fig 4 [−2,+3)) | methods:1060–1073 | results:88, 102, 179; supplementary:70–71 | Methods (locked). Results keep the short clauses they have. |
| C12 | Predictability / regularizability definitions, and why not the interaction | methods:1372–1386 | results:191–193; stat_tables:114; discussion:18 ("A widening gap can come from a rising open loop…") | Definitions in Methods (2 sentences). The why-not-interaction argument goes to Discussion:18 only. |
| C13 | Corroborating tests list | methods:1434–1443 | stat_tables captions 74, 114, 155; methods:1352–1356, 1421–1423 | stat_tables captions. Methods keeps one sentence. |
| C14 | Fig 3 full-window df collapse | methods:1347–1354 | stat_tables:108 footnote | Methods (shortened); the footnote keeps the numbers. |
| C15 | Blinding / sample size / interleaving set by software | methods:1004–1008 | methods:1294–1298, 1305–1308; trial structure 396–400 | Statistics → Design (one copy). Trial structure keeps the randomization *procedure* (p = 0.5 per trial). |
| C16 | Controller designed on an earlier two-pole fit | methods:443–445 | methods:841–844 | 443–445. |
| C17 | Variance under constant open-loop input (S1D) | methods:482–484 | methods:749–753 (Sustained stimulation); supplementary:54–59 | 482–484 in the assumption. Cut the Sustained stimulation subsection. |
| C18 | Fig 2G is descriptive, supporting tests only | methods:1192–1200 | methods:1400–1403, 1408–1412; stat_tables:55; fig2 caption results:63; supplementary:83 | methods:1192–1200, shortened. Cut 1400–1403 and the Fig 2G family in 1408–1412. |
| C19 | Fig 5 descriptive (n = 3) | methods:1330–1333 | results:256; fig5 caption results:246; discussion:26, 46 | Methods one sentence, plus the caption. Results:256 and Discussion:46 can each lose their restatement (author's call). |
| C20 | Ĵ(K) is a finite-sample estimate, inflated by non-stationarity | methods:874–877 | discussion:38 | Discussion. |
| C21 | Online gain search parameters | methods:907–916 (prose) | methods:925–946 (Algorithm `alg:zo`) | Prose. Drop the algorithm, or move it to the Supplement. |
| C22 | Online search cost window "less two samples", not comparable with grid | methods:914–915 | supplementary:106–109 | Methods. Caption: "online cost (Methods)". |
| C23 | Spatial-extent thresholds (50% of median within 0.2 mm; annulus 0.6–0.9 mm) | methods:757–762 | supplementary:37–42 (near-verbatim) | Methods. S1A caption: "suppressed area (threshold in Methods)". |
| C24 | Held-out validation splits (100 splits, both directions, stratified) | methods:805–813 | fig2 caption results:60; results:71 | Methods. The caption can drop "stratified by amplitude and scored in both directions". |
| C25 | τ beyond window drawn at edge | methods:830 | fig2 caption results:62; results:82 | Caption. Cut the Methods sentence. |
| C26 | Sine: four cycles in the window → exact Parseval split | methods:658–659, 693–697 | results:258; discussion:24 | Methods. Results:258 can say "(Materials and Methods)" instead of re-deriving it. |
| C27 | Preview lookahead 5 samples = 143 ms = 51.4° | methods:672–674 | results:232, 254; fig5 caption results:245; discussion:26 | Methods for the parameter; Results:254 for the measured match. The caption is fine. |
| C28 | Unique R² with separate models for the two power measures | methods:1136–1143 | results:184, 187; fig4 caption results:165; supplementary:126–133 | Methods. The S3 caption line 132–133 ("Fig 4C takes … from D and … from C") can stay, since it is the only place this mapping is spelled out. |
| C29 | Exemplar selection | methods:1145–1151 | supplementary:119–122; results:180 | Methods. |
| C30 | Contralateral co-activity framing sentence | methods:1227–1230 | results:218 (near-verbatim) | Results. Methods starts directly at "On spontaneous, no-laser frames…". |
| C31 | Predictor availability 13 of 15 | methods:984–988 | results:218, 224 | Methods (selection), shortened. |
| C32 | Interleaving means same brain-state distribution | methods:396–400 | methods:1018–1019, 1294–1298 | 396–400. |
| C33 | u_max = 2.45 V and first-two-sessions saturation | methods:264–268 | methods:570–571 | 264–268 (with the stimulation hardware); 570 gives only the symbol, "u_max = 2.45 V". |
| C34 | Power ceiling ~1 mW / 1.6 mW | methods:284–285 | discussion:40 | Both are fine (Discussion interprets). But Discussion points at `sec:pi_controller_design` for it; see Section D labels. |
| C35 | Uncorrected signal used for Fig 4 band power (hemodynamics caveat) | methods:216–220 | discussion:44 | Methods states the fact; Discussion keeps the caveat. Drop "(see Discussion)" duplication if trimmed. |
| C36 | MPC description | results:263–271 | fig:mpc_direct caption results:279–320; discussion:52 (repeats R² 0.42/0.10/0.02 and "bounds rather than measures") | Move the method into Methods (Section F). Results keeps the logic and numbers; the caption drops its method paragraph (316–320) to a pointer. Discussion:52 can lose the R² numbers. |
| C37 | Gains tuned per mouse and adjusted per session | results:126, 78 ("gains from earlier sessions served as a starting point") | methods:918–920 ("set by hand within the range the grid had explored") | Methods, but make it say what Results claims (G6). |
| C38 | Motion energy definition | methods:300–302 | methods:1042–1047; results:22 ("squared pixel change per unit time") | 300–302 for the signal; 1042 for the window statistic. Results:22 says "per unit time"; check it matches "between consecutive frames". |

---

## 5. Section D: Must keep

### Locked decisions (shorten wording if needed, never drop or change)

| Item | Where now | Note |
|---|---|---|
| Controller ΔF/F: trailing (F − F̄)/F̄, F̄ over 40.0 s = 1400 samples = controller horizon, same in all 15 sessions; loop could only use past samples | 339–351, `eq:dff`, 372–376 | Keep equation, window and reason. |
| Baseline frozen during the stimulated trial | 360–365 | Keep; it affects the meaning of the reference. Can shorten to two sentences. |
| Impulse ΔF/F: F / session-mean image × 100 over the kernel; offline and open loop, so no online constraint | 376–381 | Keep. The scale-invariance clause (381–384) can stay as one clause. |
| Fig 2 state window [−1, 0) s, 35 samples, strictly pre-stimulus | 1060–1065 | Keep. |
| Fig 4 state window [−2, +3) s, 175 samples, for motion, relative δ and absolute δ; initial deviation = \|y(t_on) − r\| | 1037–1040, 1065–1073 | Keep. Never "−1..+3" and never pre-only. |
| Fig 4 band power: continuous PSD (detrend, Hann, zero-pad, trapezoid between exact edges) | 1079–1098, `eq:bandpow` | Keep the equation plus one sentence of why. |
| Fig 2 band power: Hann periodogram, native 1 Hz bins, edges inclusive | 1075–1078 | Keep. |
| Band definitions: rel 2–4 / 0.4–10 Hz; abs 2–4 Hz (Fig 2) and log10 1–4 Hz (Fig 4) | 1049–1058 | Keep. |
| Motion statistic = mean of z-scored motion energy (not mean of z²) | 1042–1047 | Keep (one clause of why). |
| RMSE sample-normalised; mean of per-trial RMSE | 853–863, `eq:trial_cost` | Keep. |
| RMSE windows: 0–3 s trial RMSE; 1–3 s steady state for disturbance rejection and Fig 4 state; 0–1 s transient | 879–891 | Keep (single definition, C4). |
| Reference −5 %ΔF/F | 392–394; tab:gains caption | Keep once in Trial structure. |
| Motion exclusion: none (motion enters only as a state) | 960–962 | Keep. CLAUDE.md lists `motThresh = 1.5`, but the manuscript says no trial was excluded on motion. **Reconcile** (G9). |
| Evoked suppression = mean ΔF/F over 0–200 ms (8 samples incl. onset), onset-referenced | 728–740, `eq:inhib_energy` | Keep. |
| Session-level mixed models, REML, Satterthwaite df capped at sessions − 1; per-session log-ratio model for Fig 3 | 1313–1322, 1335–1346 | Keep (shortened). |
| Fig 2G descriptive; slope test supporting only | 1192–1200 | Keep. |
| Fig 5 descriptive (3 sessions) | 1330–1333 | Keep. |
| MPC = simulation, descriptive | new (Section F) | Add. |

### Needed for reproduction (keep in substance)

- Cohort table `tab:cohort` and its caption (session IDs for impulse, tuning and sine sessions).
- Gains table `tab:gains` (K_r, K_p, K_i, OL/CL counts). It could move to the Supplement (G7), but the label must survive because results:127 cites it.
- Readout: 10 × 10 pixel kernel (0.173 mm) adjacent to the stimulation target, somatosensory cortex. Also the FILL for coordinates (241–243).
- Trial structure: 3 s stimulation; ITI 15 s + up to 1 s jitter; per-trial p = 0.5 assignment; tuning phase precedes validation block; AL_0048/0051 used the last 100 trials.
- Tracking error sign convention, `eq:error` (with the CHECK comment resolved).
- Feedforward ū = K_r·|y_ref|, constant, independent of measurement (`eq:ff`). Without it "open loop" is undefined.
- K_r = U Y† (`eq:kr`; Discussion:16 cites it).
- PI law with output saturation [0, u_max], term clamps, finite 3 s (105-sample) boxcar integral reset each ITI (`eq:pi`, `eq:integral`).
- g = 0 / 1 switch defining open vs closed loop.
- Nominal model and Assumption 1 (`eq:nl_state`, `eq:nl_out`, `assm:trial_avg`; Discussion cites all three), and the n = 2 design model.
- Sine reference `eq:sine_ref`, preview `eq:preview` (in practice K_v = K_a = 0, K_pv = 1, d = 5), the four modes, and the sine metrics (RMSE, variance, phase from a 1 Hz fit, cross-correlation lag, Parseval split).
- Impulse protocol: pulse width, ITI, amplitude count, ≥44 trials per amplitude.
- TF fit: amplitude normalization with a² weights, 0.5 s window, order sweep (1–5 poles, 0–4 zeros, strictly proper, 0–3 sample delay), AIC with the R² < 0.98 parsimony rule, held-out split-half design (100 splits × 2), cross-session swap with a free gain, bootstrap identifiability (300).
- Spatial extent: threshold and annulus.
- Grid sweep: session, 10 gain pairs, 0–3 s scoring. Online search: start point, step sizes, 15 trials per candidate, anneal 0.8, 9 iterations, accept-if-better rule.
- All exclusion rules with counts (Session and trial selection).
- Unique-R² definition (`eq:uniqueR2`, adjusted), per-session OLS, separate models for the two power terms.
- Fig 4D quartile/z-score display construction (1104–1111).
- Impulse variability e_j (`eq:l2_error`), within-amplitude RMS scaling, quartile ratio + geometric mean, stimulus-free control window (−1.51 to −1.03 s) and why it does not overlap the state window.
- Contralateral predictor: ridge, lattice, time split 2/3 : 1/3, catch-window penalty rule, G/L split, leave-one-trial-out reconstruction check, RR definition (`eq:rr`), leak correction, steady-state window, offset/fluctuation split.
- Stats: every model formula (Fig 3 ratio model, per-trial corroborating model, state model with random state slope, log-RMSE attenuation model, RR session and mouse-nested models); one-sided tests and why; multiple-comparison family sizes and thresholds; signed-rank tests.
- Data and code availability.

### `\label` targets referenced from outside Methods (a cut must keep or redirect these)

| Label | Defined at | Cited from | Risk if cut |
|---|---|---|---|
| `eq:pi` | 566 | discussion:3, discussion:16 | Keep the equation. |
| `eq:kr` | 532 | discussion:16 | **At risk** if the K_r pseudoinverse equation is cut for brevity. Keep it. |
| `eq:nl_state`, `eq:nl_out` | 420–421 | discussion:7 | Keep the nominal-model equations. |
| `assm:trial_avg` | 453 | discussion:7, 16, 30, 38 (+59, commented) | Keep the assumption environment. |
| `sec:pi_controller_design` | 552 | discussion:40 (`\nameref`, for the laser **power ceiling**) | **At risk.** The ceiling is described in Optogenetic stimulation (284–285), not under this heading. If 260–285 is condensed, either put the ceiling sentence under PI feedback next to u_max, or add `\label{sec:stim}` to the stimulation subsection and repoint Discussion:40. |
| `sec:stats` | 1287 | stat_tables:7 (`\nameref`) | Keep the heading text and label. `stat_tables.tex` is generated (`paper_stats_tex.m`), so renaming the label means editing the generator. |
| `tab:gains` | 632 | results:127 | Keep (also if moved to the Supplement). |
| `tab:cohort` | 128 | results:169 (Fig 4 caption) | Keep. |
| Heading text "State exemplars and error decomposition" | 1113 | supplementary:122–123 (cited by name in `\emph{}`, not by label) | If the subsection is renamed or merged, update the S3 caption. |
| Textual "(Materials and Methods)" pointers | results:21, 22, 68, 70, 78, 81, 82, 88, 91, 102, 117, 126, 134, 179, 189, 220, 224, 226; supplementary:122; discussion:40 | — | Each pointer's target content must survive. Two currently point at content Methods does not clearly contain: results:78 ("gains from earlier sessions served as a starting point and needed minor adjustments") and results:126 ("For each mouse, we first tuned…"). See G6. results:226 ("too few for a mouse-level test") needs the mouse-nested model sentence to stay. |

**Internal-only labels** (referenced only inside Methods; safe if the referencing sentence moves with them):
`eq:dff` (372, 427), `eq:error` (556, 671), `eq:ff` (592, 670), `sec:gain_opt` (401), `sec:tf_fitting` (445), `sec:inhib_energy` (722),
`eq:inhib_energy` (1171), `eq:trial_cost` (867), `alg:zo` (909; dropping the algorithm means rewording 909), `sec:disturbance` (1178),
`eq:bandpow` (1096), `sec:imp_state` (1402; that sentence is cut in B, so the label becomes unused), `eq:l2_error` (1204), `sec:disturbance_decomp` (995).

**Unreferenced labels** (droppable): `sec:ff_gain`, `eq:lti_state`, `eq:lti_out`, `eq:trial_avg`, `eq:integral`, `sec:preview`, `eq:sine_ref`,
`eq:preview`, `sec:f4_decomp`, `eq:uniqueR2`, `eq:rr`.

**Already broken or stale:**
- discussion:54 cites `alg:zeroth_order`, which does not exist (the label is `alg:zo`), but the line is commented out. Harmless.
- The header comment at methods:18–21 claims results/discussion cite `fig:S1–S4`, `sec:disturbance`, `sec:disturbance_decomp`, `sec:gain_opt`, `sec:inhib_energy`, `sec:ff_gain`, `sec:tf_fitting`, `fig:spatial_maps`. None of these is cited outside Methods any more, and `fig:spatial_maps` / `fig:S*` no longer exist. Rewrite that comment.

**Count of broken-ref risks from this plan: 3 hard** (`eq:kr`, `sec:pi_controller_design` content, `sec:stats` heading) **+ 1 soft** (the S3 caption naming the subsection). The other 6 externally cited labels (`eq:pi`, `eq:nl_state`, `eq:nl_out`, `assm:trial_avg`, `tab:gains`, `tab:cohort`) are safe because the plan keeps their targets.

---

## 6. Section E: Proposed outline and targets

| # | Proposed subsection (heading) | Built from (current lines) | Now (w) | Target (w) |
|---|---|---|---|---|
| 1 | **Animals and preparation** (cite Matveev2024; AL_0048/0051 actuation; cohort table) | 32–162 | 679 | 300 (incl. ~120 w table) |
| 2 | **Imaging and optogenetic stimulation** (cite Matveev2024; 35 Hz per channel; blue-only online vs corrected offline; target adjacent to readout; command limits, mW conversion, power ceiling; 40 Hz sine sessions) — add `\label{sec:stim}` | 163–294 | 953 | 300 |
| 3 | **Behavioral monitoring** (motion energy definition) | 295–308 | 55 | 45 |
| 4 | **Real-time control** — loop and latency; online ΔF/F (`eq:dff`) + baseline freeze; two ΔF/F normalizations; trial structure | 309–410 | 706 | 430 |
| 5 | **Controller** — nominal model + Assumption 1 (S1C/D evidence); tracking error; feedforward (`eq:ff`, `eq:kr`, calibration routes); PI (`eq:pi`, `eq:integral`, gains table); stability; sinusoidal reference, preview and metrics | 411–699 | 1,762 | 1,150 |
| 6 | **Model-predictive control replay** (NEW, Section F) | — | 0 | 150 |
| 7 | **System characterization** — impulse protocol; evoked suppression; spatial extent; TF fitting (Mouse 3 compressed), held-out validation, model swap, time constants + bootstrap | 700–846 | 1,319 | 780 |
| 8 | **Controller tuning** — tracking cost and the three named windows; grid; online search (prose only) | 847–948 | 624 | 330 |
| 9 | **Session and trial selection** | 949–1010 | 411 | 220 |
| 10 | **Brain-state measures** — definitions, two windows, spectral estimation (`eq:bandpow`), Fig 4D quartile display | 1011–1112 | 820 | 520 |
| 11 | **Error decomposition and exemplars** (Fig 4A–C) | 1113–1154 | 403 | 250 |
| 12 | **Impulse-response variability and brain state** (Fig 2G; descriptive) | 1155–1223 | 695 | 420 |
| 13 | **Contralateral prediction and disturbance rejection** | 1224–1285 | 547 | 340 |
| 14 | **Experimental design and statistical analysis** — design; software + df policy; model formulas; multiple comparisons; non-parametric/one-sided; one corroboration sentence | 1286–1445 | 1,513 | 800 |
| 15 | **Data and code availability** (+ git revision sentence from 332–334) | 1446–1457 | 50 | 60 |
| | **Total** | | **~10,550** | **~6,100** |

Estimated reduction: **about 4,450 words (≈42%)**, with no loss of locked definitions. A further ~300 w is available
if the gains table and/or Algorithm box move to the Supplement, and ~150 w if the TF identifiability details move to
Results:82 or the S-figure caption.

Source-file hygiene, separate from rendered words: about 190 `%%` comment lines (FILL/CHECK notes, provenance) make the
file look ~13% longer than it renders. Resolve the FILLs, then move the provenance notes to `brain_paper/RESEARCH.md`
so the `.tex` stays readable. This does not change the rendered length.

---

## 7. Section F: Proposed MPC Methods paragraph (draft, ~145 words)

Place it as its own `\subsubsection*{Model-predictive control replay}` after "Sinusoidal reference and preview" (or at the
end of Offline analysis), with `\label{sec:mpc}` so that Results:263 and the Figure 6 caption can say
"(\nameref{sec:mpc})" in place of their method sentences.

> We simulated a model-predictive controller (MPC) on one closed-loop session (AL\_0033, 2025-02-26). Activity at the
> controlled site and at 100 sites across dorsal cortex, with the laser command as input, was modeled as a linear vector
> autoregressive process (VARX; ten lags, 286\,ms) fitted by ridge regression. At every frame the MPC chose the laser
> commands over a 1\,s horizon that minimized the squared deviation of the predicted controlled signal from the reference,
> plus a penalty ($\lambda = 0.1$) on command changes and a small penalty on departure from the steady-state command,
> within the range of commands the rig delivered. It applied the first command and planned again at the next frame. To
> replay a trial, we drove the VARX fitted to the whole session with that trial's recorded one-step residuals, which
> reproduces the recorded PI trial under the recorded laser. The MPC's own model was fitted with the trial's fold held
> out (five folds). RMSE was scored over 1--3\,s. All results are descriptive.

What it must contain, and what the caption currently supplies: session; model class, inputs, lags and fitting; horizon;
cost terms and λ; constraint; receding horizon; replay construction (why PI needs no model); cross-validation of the
MPC's model; scoring window; descriptive status. The prediction benchmark (AR order 35 chosen on validation data, naive
last value, 92 held-out open-loop trials, five folds) can stay in the Fig 6G caption, or be added as one more sentence.
Once this paragraph exists, the caption's closing method paragraph (results:316–320) can shrink to "(Materials and Methods)".

---

## 8. Section G: Open questions for the author

1. **What Matveev2024 actually covers.** I could not read the paper. Please confirm: Jackson stock numbers; the light-blocking cone; 3×3 binning to 560×560, pypylon and the 1 ms LED ramps; registration method and 50 SVD components; galvo calibration; FLIR camera and the motion-energy definition; sucrose-reward schedule. Whatever it does not cover stays in our Methods (short).
2. **Surgery detail level.** Does JNeurosci (or your IACUC wording) need anesthetic and analgesic doses stated in this paper, or is "isoflurane, carprofen, as in Matveev2024" enough? The plan keeps the agent names without the doses.
3. **Rig-build wording.** methods:1021–1024 says the 2026 sessions "used a different rig build". Comment 716 records "User: do not mention earlier/later system versions". These conflict. Keep the cross-build caveat, or rephrase it as "a different stimulation wavelength and calibration"?
4. **Galvo-sound delay** (FILL 253–258). Did the closed-loop sessions use Matveev's randomized 100–800 ms galvo-to-laser delay? A referee who knows the lab paper will look for it.
5. **The 4 s session.** FILL at 389 and the sentence at 891 refer to one session with a 4 s stimulus that is still unnamed. Name it or drop it.
6. **Gain-setting story.** Results:78 and :126 say gains were tuned per mouse and carried forward with small adjustments, citing Methods. Methods:918–920 says only "set by hand within the range the grid had explored". Which is right? Methods should state it once.
7. **Tables to the Supplement?** Moving `tab:gains` (and/or the Algorithm box) to the Supplement saves ~300 rendered words and a page float, at the cost of one more jump for the reader. Keep the label either way.
8. **Spectral detail for Fig 2.** Keep both estimators in Methods (Fig 2 native bins, Fig 4 continuous)? They are locked separately, so I have kept both.
9. **Motion threshold 1.5.** CLAUDE.md lists `motThresh = 1.5` as the motion-exclusion threshold, but Methods (960–962) says no trial was excluded on motion. If 1.5 is used anywhere in the paper analyses (e.g. a still/moving split), it needs a sentence; otherwise it is outdated and the CLAUDE.md line should be updated.
10. **MPC details missing from every current text.** How the 100 sites were chosen; the ridge penalty and how it was set; the weight of the steady-state-command penalty; the numeric command bounds (0–2.45 V?); whether the loop latency or command quantization was modeled; whether the session's interleaved K_p values (m4 interleaved three K_p values, Table gains) matter for the "PI baseline". These are needed for the Section F paragraph to be complete.
11. **The "Two analyses" paragraph (1100–1111).** Its first half (per-state slopes compared across sessions) is superseded by the mixed model. Do you still want the per-session OLS slope analysis for all four states, or only the motion slopes that appear in the table?
12. **Time-constant per-mouse numbers** (822–839). Move them to Results:81–82, or drop them? They are results, but Results currently cites Methods for them.
13. **Fig 3 note on m4.** The gains table says m4 interleaved three K_p values, and m4 is also the MPC session and the Fig 3 step-response session. Is a sentence needed anywhere about pooling over K_p within m4?
14. **Unresolved FILL/CHECK comments** affecting what remains: titers (60–62), IACUC number (63), AL_0051 construct (89–96), exposure and illumination power (182–184, 196), coordinates (241–243), session re-calibration (250–251), 1 mW per 3 V source (280), video frame rate / ROI / sync (303–306), repo URL (335), K_r route per session (548–549), clamp values (590), sine-session gains (684), RMSE-vs-RMS minimizer check (871–872), counts provenance (998–1001), blinding confirmation (1305–1306).

---

## 9. Author answers (2026-10-16) — these OVERRIDE the plan where they differ

- **Q1 Matveev2024 coverage:** ALL of these are covered and can be cited away: 3x3 binning/pypylon/LED ramps; atlas registration + 50 SVD components; galvo calibration; light-blocking cone; Jackson stock numbers; sucrose reward schedule; face camera. EXCEPTION: keep the motion-energy definition in our Methods exactly as we compute it (squared frame difference, z-scored within session, the statistic used).
- **Q2 Surgery:** drug names, no doses (isoflurane, carprofen; cleared-skull chamber + headpost as in Matveev2024; >=1 week recovery).
- **Q3 Rig build:** DROP the "different rig build and stimulation wavelength / absolute RMSE not comparable" caveat entirely (~methods 1021-1024). Never mention earlier/later system versions.
- **Q4 Galvo:** galvos do not move (fixed target), so no galvo-sound delay is needed. State instead that laser onset times were randomly jittered to avoid adaptation (keep/merge with the existing ITI jitter sentence). Remove the FILL at 252-258.
- **Q5 4 s session:** DROP the 4 s sentence (~891) and its FILL (~388-389). All reported sessions used 3 s trials.
- **Q6 Gains:** both true. Methods states once: initial gains for each mouse set by hand within the range the grid had explored, then carried to later sessions with small start-of-session adjustments. (Q14j adds: K_r from a least-squares fit to the impulse response, then manual per-session tuning.)
- **Q7 Floats:** KEEP the Algorithm box in Methods (overrides plan B "cut Algorithm box"; you may tighten the prose around it so it does not repeat the box). MOVE the PI gains table (`tab:gains`) to supplementary.tex (keep the label; Methods points to it).
- **Q8 Spectral:** keep both band-power estimators (Fig 2 native bins; Fig 4 continuous), one sentence each, keep why Fig 4 uses continuous.
- **Q9 Motion threshold 1.5:** not used in the paper. Methods keeps "no trial was excluded on motion"; no 1.5 anywhere.
- **Q10 MPC paragraph facts:** 100 sites = evenly spaced grid of 5x5-pixel boxes over the brain mask; ridge penalty 100 chosen on validation data from 1-10^4; small penalty pulling the command toward the median recorded closed-loop command; commands bounded between 0 and the largest command the rig delivered. Do NOT state timing/latency or quantization. Do NOT add a sentence about m4's interleaved K_p.
- **Q11 Fig 4 analyses:** DROP the per-session slope description ("First, we regressed per-trial RMSE on each state..."). Describe the Fig 4D mixed model properly as the test of predictability (OL slope) and regularizability (CL slope) for every state (and attenuation). The motion "OL slope > CL slope in 11/11 sessions" in Results is an observation; at most a clause in Methods for the per-session count.
- **Q12 Time constants:** Methods keeps only the method (tau definition, fit-window rule, bootstrap identifiability procedure). MOVE the per-mouse numbers (mode contributions 60-68%, Mouse 5a 6% sustained term, order-dependence 0.117 vs 0.106 s / 0.154 vs 0.114 s, bootstrap fractions 39%/72%/all/3%) into the Results timescale paragraph (results.tex ~80-82), concisely.
- **Q14 FILLs:**
  - a titers, b IACUC: keep FILL (author confirming with Anna).
  - c AL_0051 different opsin/construct and its 594 nm wavelength: REMOVE the mention entirely; not addressed in the paper.
  - d exposure/illumination power: cite Matveev2024; leave a FILL comment for exposure (author said "14 microseconds" -- to be confirmed, possibly ms) and power unknown. Do not print a value.
  - e target coordinates: keep as is / FILL.
  - f power calibration: once a month (state it, cite Matveev2024 for the procedure).
  - g 1 mW per 3 V source: do not mention the calibration file; cite Matveev2024.
  - h video frame rate/ROI/sync: syncing is in Matveev2024; cite it; drop the FILL.
  - i code URL: leave a visible placeholder.
  - j K_r route: least-squares fit to the impulse response, then manual per-session tuning.
  - k integral clamp: integral term clamped at 1 V on the microcontroller.
  - l sine-session gains: keep FILL.
  - m RMSE vs RMS minimizer: confirmed identical; remove the CHECK comment.
  - n counts provenance: regenerate/verify from saved outputs (paper-writing/STATS_TABLE.csv, data/fig2b_trial_counts.csv) and remove the FILL if consistent.
  - o blinding: "Analyses were not blinded to condition; all analyses were automated and applied identically to every condition."
