# Meeting Log — Brain Paper (Nick/Aditya)

Transcripts: `C:\Users\aditya\OneDrive\Notes\Meetings\Adick meetings\`  
Add a new entry here after each meeting. Parse with: give Claude the transcript path and say "parse this meeting."

---

## Open Action Items — as of 2026-09-24

> Reconciled from the 2026-09-24 meeting's own new + carried-forward list (the authoritative current snapshot). Items marked DONE were closed by work logged after the meeting (see Research Hub worklog / RESEARCH.md); the rest are open. Older detailed breakdowns are preserved further down.
> ⚠ The 2026-09-24 summary carries `2026-09-23.x` items from a **2026-09-23 meeting that has no transcript in the vault** — listed here as carried; no separate entry exists.

### Grant (Azadeh collab) — NEW 2026-09-23 / 2026-09-24 *(deadline was ~Wed 2026-09-30 — now passed; verify which closed)*
- [~] `2026-09-24.1` Finish **Aims 2 and 3 text** (Aim 3 behavior section finalized with Nick 09-25) — *grant figures fixed for Nick's review 2026-09-30; confirm submitted*
- [ ] `2026-09-24.2` Check the 09-23 transcript to **confirm the final virus list** (expected 6: pan-Glut, pan-GABA, L2/3, L1, L3; VIP/SST dropped); update the Aim 1 table
- [~] `2026-09-24.3` Wait for **Felix's edits** before pushing more changes to the shared section
- [~] `2026-09-24.6` Edit aims text **directly, sentence-by-sentence** (AI only for targeted paragraph suggestions) — working rule
- [~] `2026-09-23.2` **Reframe aims around the virus-selection pipeline**: Aim 1 = I/O characterization gate, Aim 2 = GDAR modeling + basic control gate, Aim 3 = behavior + CL control in macaque
- [ ] `2026-09-23.3` **Redraw the two behavioral tasks** (mouse block-rule; macaque pointer/orientation) in a matching graphical format
- [~] `2026-09-23.4` Share updated specific aims with **Azadeh**; wait for her input before finalizing Aim 2/3
- [~] `2026-09-23.6` **Cut grant to ≤12 pages** (figure trimming reclaims ~2 pp) *(Command board still has "decide with PIs whether to cut to a hard 12 pp")*

### Manuscript / experiments — NEW 2026-09-23
- [ ] `2026-09-23.1` **Repeat the OL-optimized reference experiments with corrected laser parameters** (no artifact, sufficient power) to support the 0–1 energy-ratio disturbance-rejection analysis *(sharpens 2026-09-15.3)*
- [ ] `2026-09-23.7` **Meet Grace**; introduce her to the rig, start onboarding to 2–3 streams *(same as 2026-09-15.6)*
- [ ] `2026-08-10.4` Draft an experiment plan for **real-time slow-oscillation phase detection + sine feedforward cancellation** to push state toward desynchrony *(resurfaced in the 09-24 carry list)*
- [ ] `2026-06-29.5` **Repeat grid sessions** (same mouse/protocol) for excitatory + midline reliability; excitatory laser < 0.5 V *(resurfaced)*

### Nick's items — NEW 2026-09-23 / 09-24
- [ ] `2026-09-24.4` **Nick**: read Aim 1 + full draft; mark cuts and where the Vertex/spiral sentence goes
- [ ] `2026-09-24.5` **Nick**: add the **Vertex/spiral Science paper** bridge sentence between Aim 1 and Aim 2
- [ ] `2026-09-23.5` **Nick**: align with Azadeh on virus-handoff framing + Gantt chart
- [ ] `2026-09-23.8` **Nick**: clarify Grace's pay/admin; confirm she logs hours retroactively

---

## Open Action Items — 2026-09-15 snapshot (still carried unless noted)

> Reconciled from the 2026-09-15 meeting's own new + carried-forward list. Items marked DONE were closed by work logged after the meeting (see Research Hub worklog / RESEARCH.md); the rest are open. Older detailed breakdowns are preserved further down.

### Manuscript — critical path to bioRxiv (NEW 2026-09-15)
- [ ] `2026-09-15.1` **Run Ziyu's predictor model on the contra (CL) dataset** and add the resulting **σ operating point** to the MPC performance-vs-σ curve *(THE decision item — supersedes 2026-09-11.4; ARIMA + patch-LSTM σ from literature already placed on the curve)*
- [x] `2026-09-15.2` Finalize the statistical section; **session-level Wilcoxon Q1/Q4 tests done for all three claims** (initial-deviation, motion, rel-delta) and all three hold — **DONE**, bring the figures to next meeting for review
  - ⚠ *2026-10-02 re-run after the ΔF/F fix: the rel-δ (2–4 Hz) controllability claim weakened (Hub worklog 2026-10-02) — re-check before showing Nick*
- [ ] `2026-09-15.3` **Add the open-loop-optimized reference trace** to the disturbance-rejection analysis, and run **two additional control experiments** to support it *(merges 2026-07-22.3)*
- [ ] `2026-09-15.4` Chat with **Fabiola + Anna Lee** about additional excitatory-opsin mice (PHP-serotype retro-orbital or equiv); bring a concrete acquisition plan to next meeting
- [ ] `2026-09-15.5` Show Nick the **step-response traces** illustrating the inhibitory-rebound problem on the excitatory side
- [ ] `2026-09-15.6` Introduce **Grace** to the 2–3 experimental streams this week; help her pick one (likely impulse-response characterization)
- [ ] `2026-09-15.7` **Aditya + Grace**: reach out to Nick to schedule the first three-way meeting (~3-week cadence)
- [ ] `2026-09-15.8` Continue cutting the **manuscript/grant draft to 12 pages** (Azadeh's template + AI-assisted flow) — ongoing
- [ ] `2026-09-15.9` At the Thursday **Allen meeting**, push collaborators for SLDS/rSLDS/GDM code help; share data + code via Code Ocean
- [ ] `2026-09-15.10` **Hold on the motorized wheel** until Alice returns (~Sep 29) to redesign the fixtures

> **Settled at the 2026-09-15 meeting (was open in the Sept-11 snapshot):** the primary **disturbance-rejection metric is finalized as a 0–1 energy ratio**; the **residual-only (local) model moves to supplemental**; the **MPC clairvoyant baseline is redefined as average-OL + perfect control**. The Sept-11 items below are kept for their fuller notes.

### Manuscript — from the 2026-09-11 meeting
- [x] `2026-09-11.1` Replace pooled-trial Wilcoxon with a **session-level paired test** (one Q4−Q1 gap per session); report how many sessions individually show it — **DONE:** session-level + mixed-effects test now printed on the Fig-4 state panels and as a permanent stats panel (`f4_2S_stats`)
- [ ] `2026-09-11.2` **Fix legend labels** in the disturbance-rejection figure ("subdued response" → "response")
- [x] `2026-09-11.3` Resolve the **MPC calc discrepancy** (clairvoyant σ=0 ~38% ≈ σ=0.3 ~36% despite very different traces) — **DONE:** metric-window artifact; re-measured on the settled post-onset window, curve now sensible
- [ ] `2026-09-11.4` **Extract per-timestep prediction σ from Ziyu's model** on the closed-loop dataset; place it on the MPC performance-vs-σ curve to see whether real predictors are in the useful range *(the number that decides MPC main-text vs supplement — still the key open item)*
- [~] `2026-09-11.5` **Decide MPC main vs supplemental** (pending .4) — leaning **discussion-only, no figure** per 2026-09-21 worklog; confirm with Nick after the σ number

### GDM / model-comparison + experiment design (carried from 2026-09-10)
- [ ] `2026-09-10.1` Share the **52-point dual-opsin grid dataset** (with motion/pupil) with **Elu** via Code Ocean for GDM training
- [ ] `2026-09-10.2` Define the **GDM task spec**: motion energy + pupil as discrete (high/low) state labels; grid data as input-output pairs
- [ ] `2026-09-10.3` Design the **four-condition interleaved experiment** (OL; CL single controller; CL GDM-controller-1; CL GDM-controller-2) to pseudo-test state-dependent controller benefit
- [ ] `2026-09-10.4` Build a **model-comparison library**: fit SLDS (+ cousins) alongside GDM on the grid data; define tracking-error / variability-reduction metrics
- [x] `2026-09-10.5` Follow up with Nick to discuss manuscript + open items — **DONE (this is the 2026-09-11 meeting)**

### Manuscript / grant handoff (carried from 2026-08-24 / 08-10 / 08-05)
- [ ] `2026-08-24.1` / `2026-08-10.1` / `2026-08-05.5` **Finalize the manuscript draft** (unified dataset, three-figure structure) and send to Nick *(in progress — Fig 2/3 + text on Overleaf; Fig 4 held on local `draft` pending Row-3 headline)*
- [ ] `2026-08-24.2` Complete a **first draft of all three aims** and share with Nick, Felix, Sophia
- [ ] `2026-08-24.3` Coordinate a **group meeting with Felix + Sophia** to align on the grant story
- [ ] `2026-08-24.5` Write a **concrete experiment plan for Grace** (grid stim, step + impulse, two spots, motion/pupil)
- [ ] `2026-08-24.6` Request **Anna's multi-spot stim dataset**; study how dual-site 40 Hz alternating stim was programmed
- [ ] `2026-08-24.7` Test **fast-galvo two-spot within one widefield frame** (ramp noise + feasibility)
- [ ] `2026-08-24.8` Follow up with **Fabiola** on reciprocal collaboration (probe recordings during CL sessions)
- [ ] `2026-08-24.9` Follow up with **Fabiola** on injecting more excitatory-opsin mice
- [ ] `2026-08-24.10` Decide whether to **interview with Merge AI** (BCI co., contact Casper Kiorkowski; SF is the friction)
- [ ] `2026-08-10.6` Write the **Aim-2 contribution for Azadeh's grant** (with Felix)
- [ ] `2026-08-05.1` Look up the **exact virus for AL_0048** (AAV9-CamKII-ChrimsonR or equiv) from the injection sheet; confirm with Nick

### Dual-opsin / excitatory-side control (carried from 2026-08-10 / 08-05 / 07-22)
- [ ] `2026-08-10.2` Run **controllability analysis** on midline dual-opsin data (two-input LTI; check all output directions controllable → bidirectional shaping feasibility)
- [ ] `2026-08-10.3` Test **PI closed-loop with low targets on the excitatory side** (not yet attempted)
- [ ] `2026-08-05.2` Design an **excitatory-side input trajectory** that inverts the fitted TF to avoid the inhibitory-rebound regime; also test sine input on the excitatory side
- [ ] `2026-07-22.2` **Fit TFs (poles + zeros) to both hemispheres**; quantify difference in dominant time constants + oscillation frequency
- [ ] `2026-08-10.5` Run **heterogeneous-node graph-model** simulations on the grid data; generate reachability/spread plots *(now the `tpgdar` project)*

### State-dependence / residual framework (carried, several likely closed by Fig-4 finalization)
- [ ] `2026-07-06.2` Add **pre-stim-window residual control** (flat across delta/variance bins)
- [ ] `2026-07-06.3` **Finalize the contralateral predictor mask**, then rerun Q1–Q4 residual-deviation plots before claiming significance
- [ ] `2026-07-06.4` **Significance test on the slope** of residual deviation vs state variables, using the finalized mask
- [ ] `2026-07-22.3` Add the **OL-optimized reference trace** to residual plots; quantify baseline flatness + stim-period deviation
- [ ] `2026-07-22.4` **Quantify disturbance rejection per trial** vs pre-stim state (delta, motion) *(largely addressed by the Fig-4 rejection metric; confirm)*
- [ ] `2026-06-29.13` / `2026-07-02.5` Reconcile the impulse **state-dependence result + SFN p-value** with the corrected analysis before bioRxiv
- [ ] `2026-06-22.9` Re-run residual analysis with corrected predictor; clean + correctly-labeled trace/scatter plots
- [ ] `2026-07-17.10` Write the discussion-anchor question: **"Are mesoscale cortical dynamics locally generated or sub-cortically imposed?"**

### Ephys / spike-sorting (carried from 2026-07-22)
- [ ] `2026-07-22.5` **Validate the Python spike-sorting re-implementation** (~50 ms); then contact Streams to share
- [ ] `2026-07-22.6` Define the **target closed-loop ephys experiment** with Nick + lab (probe / opsin / manipulation)

### Treadmill / rig hardware (carried)
- [ ] `2026-07-28.6` **Purchase the motor**; in-situ noise test; foam housing / belt-drive if too loud
- [ ] `2026-07-17.3` **Place the passive running wheel** in the rig now; encoder later
- [ ] `2026-06-29.2` Add **rotary-encoder mount** to the wheel base; confirm Arduino wiring
- [ ] `2026-06-29.3` When **Alice returns (fall)**, supervise the motorized/clutch fixture redesign

### People / logistics / career (carried)
- [ ] `2026-08-10.9` Complete **Grace's onboarding** (she started Sep 1)
- [ ] `2026-08-05.6` Follow up with **Azadeh** to start the H1B process once the offer letter is confirmed
- [ ] `2026-07-17.5` Ask **Anna Lee** about the **CamKII-C1V1 mouse** availability for CL experiments

### Nick's items (not Aditya's)
- [ ] `2026-08-24.4` **Nick**: brief **Grace**; assign her grid-stim data collection (dual-spot, motion, pupil) + analysis
- [ ] `2026-08-05.3` **Nick**: talk to **Fabiola** about injecting more excitatory-opsin mice (L+R cohort)
- [ ] `2026-08-05.4` **Nick**: contact **Dr. Whitefield** re an off-the-shelf PHP-serotype virus for retro-orbital excitatory-opsin delivery
- [ ] `2026-08-05.7` **Nick**: finalize funding split with Eric; issue the one-year postdoc offer letter
- [ ] `2026-07-17.9` **Nick**: simulate an inhibitory DC input into the **Kurtow & Harris** model (does output variance survive?)

---

## Prior carry-forward (pre-2026-09-11)

> The detailed 2026-07-28-era breakdown, kept for the fuller notes on each item. Superseded by the reconciled snapshot above where they overlap.

### Disturbance-Rejection Metric & Multi-Mouse Sessions — NEW (2026-07-28, critical path)
- [ ] `2026-07-28.1` **Invert the disturbance-rejection metric to a plain energy ratio** — actual trial energy / disturbance energy, so **1 = no work done** and **< 1 = controller gain**; drop the minus-one offset (current ρ = 1 − ‖A−ref‖/‖G‖) *(2026-07-28)*
- [ ] `2026-07-28.2` **Test whether the pre-stim baseline offset in the DR scatter is state-dependent laser gain**, not controller work: correlate the offset with pre-stim delta power / motion; regress stim-period residual amplitude on pre-stim delta with an **OL×CL interaction term** (significant interaction ⇒ gain variability, not controller failure) *(2026-07-28)*
- [ ] `2026-07-28.3` **Run the CL PI-controller experiment on AL_0048, AL_0050 and AL_0051**; include all three in the state-dependence analysis to firm up the p = 0.039 result *(2026-07-28)*
- [ ] `2026-07-28.4` **Add the contralateral trace to the trial-by-trial residual plot** so "stays-around-zero" trials can be read against the contra prediction *(2026-07-28)*
- [ ] `2026-07-28.5` **Check AL_0051 expression level** (confirm with Anna if needed); schedule grid characterization + CL session *(2026-07-28)*

### State-Dependence / Residual Framework (critical path to bioRxiv)
- [ ] `2026-07-06.1` Produce **signed** (non-absolute-value) residual-deviation plots to test whether high/low laser response is directionally predictable *(2026-07-06)*
- [ ] `2026-07-06.2` Add **pre-stimulus-window residual as a control**: verify it is flat across delta-power / variance bins (rules out globally bad prediction as the confound) *(2026-07-06)*
- [ ] `2026-07-06.3` **Finalize the contralateral predictor mask** (currently a greedy worst-case-pixel, uniform-weight mask), then rerun quartile-binned (Q1–Q4) residual-deviation plots on the updated model before claiming significance *(2026-07-06)*
- [ ] `2026-07-06.4` Run **significance test on the slope** of residual deviation vs. state variables (delta power, pre-stim variance) using the finalized mask *(2026-07-06)*
- [ ] `2026-07-17.8` Finalize the **pre-stim prediction-error control figure** (color-coded scatter); verify high-prediction-error trials do NOT cluster at high residual deviations *(2026-07-17)*
- [ ] `2026-07-02.5` Reconcile the **SFN abstract p-value** claim on state-dependence with the corrected residual analysis *(2026-07-02)*
- [ ] `2026-06-29.9` Identify laser grid locations with **minimal contralateral spread**; restrict residual analysis to those locations to reduce bleed-through confound *(2026-06-29)*
- [ ] `2026-06-22.9` Re-run residual (local-only) analysis with the corrected predictor; produce clearly labeled trace + scatter plots; **fix mislabeled axes** (Y previously "motion") *(2026-06-22)*
- [ ] `2026-06-29.13` Reconcile the impulse state-dependence result in the paper draft; get the paper to a state matching the SFN abstract claims **before posting to bioRxiv** *(2026-06-29)*

### Sine-Wave / Preview Controller (manuscript)
- [ ] `2026-07-17.1` **Exclude drowsy/outlier trials and recompute per-condition MSE** for the four-mode sine-wave experiment (OL / OL+preview / CL / CL+preview) *(2026-07-17)*
- [ ] `2026-07-17.2` Repeat sine-wave tracking session(s) with a **water-restricted mouse** for cleaner behavioral state (plan for the water-restriction logistics) *(2026-07-17)*
- [ ] `2026-05-29.6` Sine-wave/feedforward sessions on new mouse: ≥4 s / ≥4-cycle stimuli, shorter ITIs; full-grid ping characterization before closed-loop *(2026-05-29)*

### Disturbance-Rejection / Closed-Loop Analyses (deferred until residual framework is locked)
- [ ] `2026-07-22.3` Add an **"open-loop-optimized" reference trace** (contra prediction + average laser effect) to the trial-by-trial residual plots; compute residual flatness in baseline + deviation during stim for OL vs CL *(2026-07-22)*
- [ ] `2026-07-22.4` **Quantify disturbance rejection per trial**: how much the CL (blue) residual deviates from the OL-optimized reference, related to pre-stim state (delta power, motion) *(2026-07-22)*
- [ ] `2026-06-03.1` For each CL trial, subtract modeled laser effect (TF fit) → inferred "no-laser" trace; compare variance distribution to actual no-laser trials (add shuffled-subtraction null) *(2026-06-03)*
- [ ] `2026-06-03.2` Re-do MSE-vs-delta-power plot: OL/CL binned by **pre-stimulus delta-band fraction**; match y-axes across panels *(2026-06-03)*
- [ ] `2026-06-03.3` Compute instability frequency from full latency distribution (worst-case ~47 ms); plot predicted control degradation vs. input frequency *(2026-06-03)*
- [ ] `2026-06-03.4` Replace variance-binned x-axis in state-dependence figure with delta-band power fraction as primary sorting criterion *(2026-06-03)*
- [ ] `2026-06-03.5` Produce heatmap of CL vs. OL trials, time on x-axis, trials sorted by delta-band fraction (Curto/Issa style) *(2026-06-03)*
- [ ] `2026-06-03.6` Spatial-spread 2D summary: response **amplitude and onset latency** as joint functions of distance from laser target *(2026-06-03)*
- [ ] Using the red model (if validated), compute post-hoc **optimal laser sequence** for representative trials; quantify gap vs. actual controller; frame as MPC motivation *(from 2026-05-11)*

### Dual-Opsin — Excitatory Hemisphere & Bidirectional Single-Site Control
- [x] `2026-07-22.1` **Check motion videos** from excitatory-side grid sessions — **DONE 2026-07-28: rebound is NOT motion artifact, it is a genuine neural response.** PD/2nd-order redesign is now unblocked *(2026-07-22 → closed 2026-07-28)*
- [ ] `2026-07-22.2` **Fit TFs (poles + zeros) to excitatory and inhibitory** hemisphere impulse responses; explicitly quantify the difference in dominant time constants + oscillation frequency *(2026-07-22)*
- [ ] `2026-07-17.7` Run **impulse-response characterization on the excitatory hemisphere** of the dual-opsin mouse; compare TF to inhibitory side *(2026-07-17)* — subsumed by `2026-07-22.2`
- [ ] `2026-07-17.5` Ask **Anna Lee** about availability of the **CamKII-C1V1 mouse** (different virus) for closed-loop experiments *(2026-07-17)*
- [ ] `2026-07-17.6` Identify cortical locations with **overlapping inhibitory + excitatory spatial footprints** from grid maps; attempt a bidirectional single-site control experiment *(2026-07-17)*
- [ ] `2026-06-29.5` Run additional grid sessions to assess reliability of excitatory and midline responses; use **lower excitatory laser power** (below 0.5 V) *(2026-06-29)*
- [ ] `2026-06-29.6` Plot grid data as **trials × time matrix** per location to diagnose whether low-response noise is outlier-trial driven; consider median over mean *(2026-06-29)*
- [ ] `2026-06-29.7` Build **inverse GUI view**: for a clicked widefield location, show the response trace for all 52 stim positions (find bidirectional-control candidates) *(2026-06-29)*
- [ ] `2026-06-29.8` Share additional grid sessions with **Dana** once collected *(2026-06-29)*
- [ ] `2026-06-22.7` Add the excitatory-opsin **spatial-localization result** (hemisphere-contained excitation) to the widefield opto paper *(2026-06-22)*

### Cortical Dynamics Theory (local vs. sub-cortical generation) — NEW, keep discussion-scope only
- [ ] `2026-07-17.10` Write down the framing anchor: **"Are mesoscale cortical dynamics locally generated or sub-cortically imposed?"** — key empirical constraint is OL suppression shifts the mean but NOT the variance of fluctuations *(2026-07-17)*
- [ ] **Forecast test (AI-flagged, existing data):** fit AR/VAR on baseline widefield; at opto onset forecast from raw (suppressed) level vs zero-mean-shifted level; better method reveals level-relative vs absolute dynamics *(2026-07-17)*

### Spike Sorting / Closed-Loop Ephys — NEW
- [ ] `2026-07-22.5` **Validate the Python spike-sorting re-implementation** (~50 ms latency); once validated, reach out to the original author (Streams) to share results *(2026-07-22)*
- [ ] `2026-07-22.6` Coordinate with Nick + lab to **define the target closed-loop ephys experiment**: probe type, opsin/mouse availability, manipulation modality *(2026-07-22)*
- [ ] `2026-07-28.7` **Decide the sorting approach for the target experiment**: Kilosort-based (~50 ms latency, high precision, needs 50 s blocks) vs simple threshold/template matching (sub-10 ms, lower precision) *(2026-07-28)*

### Treadmill / Rig Hardware — NEW
- [ ] `2026-07-28.6` **Purchase the identified motor** (approved); bench-test noise in situ; if too loud → foam housing and/or belt drive to offset the motor from the mouse; slow torque ramp-up *(2026-07-28)*
- [ ] **Noise pre-check (AI-flagged):** record a widefield session with the motor running at target speed but the wheel decoupled from the mouse; look for motor-frequency peaks in the ΔF/F power spectrum before investing in full sessions *(2026-07-28)*

### Grid Calibration / Rig Visualization — NEW
- [ ] `2026-07-22.7` Discuss with **Anna & Fabio** a software fix to **overlay grid points on the brain image** (Pylon frame) live during experiments, accounting for Bregma/Lambda calibration *(2026-07-22)*

### Motorized Treadmill / Passive Wheel
- [ ] `2026-07-17.3` **Place the passive running wheel** (no motor needed) in the imaging rig now to promote desynchronized trials; add rotary encoder when feasible *(2026-07-17)*
- [ ] `2026-07-06.6` / `2026-07-17.4` Post identified motor specs (model, torque, cost, controller) to the **treadmill Slack channel** for Nick/Matt/Alice *(2026-07-06 → 2026-07-17)*
- [ ] `2026-07-06.7` Check existing lab **power supplies** (variable-voltage adapters) for ≥3× peak-motor-current rating before buying a new one *(2026-07-06)*
- [ ] `2026-06-29.2` Add **rotary encoder mount** to the wheel base (reprint or clamp); confirm encoder wiring to Arduino *(2026-06-29)*
- [ ] `2026-06-29.3` When Alice returns (fall), supervise fixture redesign for motorized/clutch version *(2026-06-29)*

### People / Logistics
- [ ] `2026-06-29.11` Train **Alex** (rotation student) to run grid sessions; show full experimental workflow *(2026-06-29)*
- [ ] Run open-loop controller sessions and **save stimulus/response data** for the upcoming mouse(es) *(from 2026-05-08)*

### Nick's Items (not Aditya's)
- [ ] `2026-07-17.9` **Nick**: Simulate an **inhibitory DC input into the Kurtow & Harris model**; check whether output variance is preserved (tests whether that model class is consistent with the variance-flat observation) *(2026-07-17)*
- [ ] `2026-06-29.4` **Nick**: Confirm with Annie whether she wants to contribute to the treadmill hardware project *(2026-06-29)*
- [ ] `2026-06-29.12` **Nick**: Confirm protocol-amendment approval; notify Aditya when Alex can handle mice *(2026-06-29)*

### Presumed done (date passed — verify)
- [x] `2026-07-06.5` Present the SFN story at Data Club (scheduled 2026-07-07) with brief cortical-dynamics/control intro for new lab members *(2026-07-06; date has passed)*

---

## Meeting Entries

---

### 2026-09-24
**Source:** `C:\Users\aditya\OneDrive\Notes\Meetings\Adick meetings\2026-09-24_Aditya_Summary.md` *(also carries items from an untranscribed 2026-09-23 meeting)*

**Overview:** Grant-only sprint (Azadeh collaboration, deadline ~Wed 2026-09-30). Specific-aims text reviewed live: PI-vs-MPC "reactive" wording replaced with a **"feedback plus feedforward"** framing. **Vertex** (recent spiral-activity Science paper) to be cited at the Aim 1 → Aim 2 transition, before the GDAR/MPC block (Nick adds the sentence). Aim 1 virus list to be confirmed as **six** (VIP/SST dropped). AI-generated prose judged too formulaic → **edit directly, piece by piece**, no more full AI revision passes. Division of labor: Aditya writes Aims 2 + 3; Nick reads Aim 1 + full draft; Aim 3 behavior (macaque) finalized the next day. Wait for Felix's edits on the shared section. No manuscript decisions this meeting; the 09-23 carry list adds **repeat the OL-optimized reference experiments with a clean laser**.

**Key decisions:**
- Aims framed as a **virus-selection pipeline**: Aim 1 I/O characterization gate → Aim 2 GDAR modeling + basic control gate → Aim 3 behavior + CL control in macaque
- "Feedback plus feedforward" terminology for PI vs MPC
- VIP/SST dropped from the Aim 1 virus list
- Direct sentence-level editing over AI full-pass rewrites

**AI analysis flags (from transcript):**
- **Virus-list ambiguity (6 vs 8) on a hard deadline** — confirm from the 09-23 transcript before Nick's read-through
- **Deadline buffer thin** — Azadeh alignment still pending, Aim 3 behavior deferred a day

---

### 2026-09-15
**Source:** `C:\Users\aditya\OneDrive\Notes\Meetings\Adick meetings\Sept 15th.md`

**Overview:** Full action-item checklist review; most items in progress or carried forward. **Statistics closed out** — the session-level Wilcoxon tests (replacing the pooled-trial test Nick rejected on Sept 11) are now done for all three Q1/Q4 claims (initial disturbance, motion, relative delta) and **all three hold**. **MPC figure updated**: clairvoyant baseline redefined as **average open-loop + perfect control**; ARIMA and patch-LSTM σ values from the literature added to the performance-vs-σ curve; **Ziyu's model to be run on contra data next** (the remaining decision input). **Residual-only (local) model moved to supplemental**; the **primary disturbance-rejection metric is finalized as a 0–1 energy ratio.** Excitatory-opsin closed-loop still blocked by strong **inhibitory rebound on step inputs** → coordinate with Fabiola + Anna Lee for more excitatory-opsin mice. New rotation student **Grace** starts next week (Aditya introduces 2–3 streams, she picks one to own — likely impulse-response characterization; ~3-week three-way meetings).

**Key decisions:**
- **Statistics section is done** for the Q1/Q4 claims (session-level Wilcoxon, all three hold) — bring the figures to the next meeting
- **Disturbance-rejection metric finalized** as a **0–1 energy ratio**; residual-only (local) model → **supplemental**
- **MPC clairvoyant baseline** redefined as average-OL + perfect control; place literature σ (ARIMA, patch-LSTM) on the curve; **run Ziyu's model on the contra CL data** for the real operating point
- **Add an OL-optimized reference trace** to the disturbance-rejection analysis + two supporting control experiments
- Excitatory side: fit a 2nd-order (2-pole/1-zero) model, check for a right-half-plane (non-minimum-phase) zero to explain the step rebound; plan more excitatory-opsin mice with Fabiola/Anna Lee
- Hold the motorized wheel until Alice returns (~Sep 29)

**AI analysis flags (from transcript):**
- **Cross-check the ARIMA/patch-LSTM σ units** against the simulation — σ as std of prediction residuals in ΔF/F vs normalized units must match before the operating points are comparable
- **Grace onboarding vs manuscript push** is a real bandwidth risk — write her a one-page impulse-response grid protocol before day one so she starts with minimal supervision
- **Allen collaboration is a timeline dependency** — if Thursday's meeting doesn't unblock SLDS/GDM help, scope a self-sufficient `pylds` SLDS fit rather than wait

---

### 2026-09-11
**Source:** `C:\Users\aditya\OneDrive\Notes\Meetings\Adick meetings\Sept 11th.md`

**Overview:** Manuscript figure-structure walkthrough. Figs 1 and 3 unchanged; **Fig 2** now = LTI fits vs impulse responses across four mice (cross-session validation, model swapping, fast/slow mode variability); **Fig 4** = closed-loop performance + state-dependence. State-dependence uses an **error-decomposition model** (RMSE attributed to initial deviation, motion, relative/absolute delta power, unique R² per feature; absolute vs relative delta capture different trial types — short bursts vs sustained heavy delta). Nick's main statistics critique: the **Q1-vs-Q4 gap test is wrong** — pooling trials across sessions ignores session/mouse correlations; switch to a **session-level paired test** now and a **linear mixed-effects model** as the eventual primary statistic. Disturbance-rejection metric shown (subdued-energy / disturbance-energy per trial, global+stim-only predictor). **MPC** simulation (clairvoyant σ=0 vs PI vs tube-MPC σ=0.3) shown, but Nick flagged a **likely calc error** (σ=0 ~38% ≈ σ=0.3 ~36% despite very different traces) and questioned whether MPC earns a main-text spot vs supplemental. Path forward: extract per-step prediction σ from **Ziyu's model**, locate it on the MPC performance-vs-σ curve, and let that decide whether MPC is worth pursuing.

**Key decisions:**
- **Switch the Q1/Q4 gap statistic** from pooled-trial Wilcoxon to a **session-level paired test** (one gap per session), moving to a **linear mixed-effects model** (mouse + session random effects) as the correct long-run test
- **Resolve the MPC metric discrepancy** before the MPC panel can support any claim — most likely a normalization/window mismatch in the denominator
- **Compute σ from Ziyu's model on our CL data** and place it on the performance curve — this decides MPC main-text vs supplement
- **Fix the disturbance-rejection legend** ("subdued response" → "response")
- Fig-2/Fig-4 structure as above is the working layout for the draft

**AI analysis flags (from transcript):**
- MPC σ=0 vs σ=0.3 numbers cannot be nearly equal given the traces — check the metric denominator (disturbance energy vs reference-relative energy) and integration window; a perfect predictor on a linear plant should integrate to ~zero tracking error
- The MPC story is **evidence-free until the σ number lands** — if Ziyu's σ falls in the flat/high-σ regime, the MPC section *weakens* the paper; compute it before deciding inclusion
- **Session-count imbalance (6+5+2+2 across four mice)** persists even with session-level tests — the mixed-effects model with mouse as a random effect is the correct fix; prioritize it if the effect is marginal

---

### 2026-07-28
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\July 28th.md`

**Overview:** Presented the updated **disturbance-rejection framework** — residual (local-only ipsi activity) isolates the laser effect, and a ratio metric quantifies how much energy the controller removes relative to the contra-predicted disturbance. Nick's main critique: **pre-stimulus baseline offsets in the DR scatter** suggest the metric may be partly capturing **trial-by-trial gain variability in the laser response** (state-dependent actuator scaling) rather than controller work. He also wants the metric **inverted to a plain energy ratio** (1 = no work, <1 = gain) instead of the current 1 − ‖·‖/‖·‖ form. Motion-video check came back: the **excitatory-hemisphere oscillatory rebound is NOT motion artifact** — it is a genuine neural response (closes `2026-07-22.1`, unblocks the PD/2nd-order redesign). Mouse inventory: **AL_0051 is the next CL candidate**; AL_0048 has one usable session (post-laser-calibration caveat) and **AL_0050 has weaker expression**; Nick wants all three in the pooled state-dependence analysis to firm up **p = 0.039**. Sparse **graph/network dynamics model** floated as a future analysis (site-to-site TFs across the grid → impose sparsity → dominant propagation paths); no results yet. **Motorized treadmill motor approved for purchase**; noise flagged as the risk (foam housing / belt drive / slow torque ramp).

**Key decisions:**
- **Invert the DR metric** to `‖y_actual‖² / ‖y_disturbance‖²` over the stim window; report median ± IQR separately for OL and CL, Wilcoxon signed-rank for paired sessions
- **Interrogate the baseline offset** before claiming controller gain — regress stim-period residual amplitude on pre-stim delta power with an **OL×CL interaction**; a significant interaction means state-dependent laser gain, not controller failure
- **Pool AL_0048 + AL_0050 + AL_0051 CL sessions** into the state-dependence analysis (p = 0.039 is preliminary until then)
- **Add the contra trace** to the trial-by-trial residual plot (third line alongside actual/residual)
- Excitatory rebound is **real neural dynamics** — motion-artifact hypothesis retired
- Buy the treadmill motor; **noise-test before rig install**

**AI analysis flags (from transcript):**
- **p = 0.039 is not yet stable** — it rests on sessions predating the AL_0048 laser-calibration fix and on a contra predictor mask that is still unfinalized (`2026-07-06.3` open). Treat as preliminary; lock the mask *and* add the new sessions before quoting it
- **AL_0050's tenuous expression may dilute rather than strengthen** the pooled result — run a quick impulse-response check on AL_0050 before committing full CL sessions (⚠ consistent with the existing local note that AL_0050 was excluded for poor stim)
- **Split the state-dependence figure by *source* of desynchronization** (high running speed vs spontaneous low-delta) — Aditya framed these as mechanistically distinct (motion = predictable state, unpredictable direction; synchronized = predictable direction, unpredictable laser gain); splitting makes the "designer's dilemma" concrete rather than qualitative
- Network model pointers: `scipy.signal`/`control` for per-site-pair discrete TFs → cluster sites by dominant poles; **DYNOTEARS** (Pamfil et al. 2020, UAI) for the sparse directed graph fit with lagged dependencies

---

### 2026-07-22
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\Jul 22nd.md`

**Overview:** Sine-wave tracking on the dual-opsin mouse (inhibitory hemisphere, 3 sessions) — preview compensation improves phase alignment but not MSE meaningfully. The **excitatory hemisphere shows markedly different impulse dynamics** from the inhibitory side: faster decay + pronounced rebound oscillation → dominant second-order dynamics, implying a derivative (PD) term is needed in any controller for that side. Nick flagged the excitatory rebound may be **motion artifact** (mouse twitching to stim); Aditya has video but hasn't checked. Walked through the trial-by-trial residual framework (orange = contra prediction, black = actual, blue = residual); Nick proposed adding an **"open-loop-optimized" reference** (orange + average laser effect) as a third comparison line to rigorously isolate CL gain over OL. Aditya has a **Python spike-sorting re-implementation** (~50 ms latency, from a collaborator's C++ repo, re-written with Claude) — discussion of closed-loop ephys viability + which manipulation/mouse line. Grid calibration: wants a **live grid-point overlay** on the brain image to catch edge/midline placement; Nick suggested looping in Anna and Fabio.

**Key decisions:**
- Add the **OL-optimized reference** (contra prediction + average laser effect) to the residual plots; quantify CL disturbance rejection as deviation of the blue residual from that reference, related to pre-stim state (delta, motion)
- **Rule out motion artifact** for the excitatory rebound BEFORE any PD-controller redesign
- **Fit TFs (poles + zeros) to both hemispheres**; quantify difference in dominant time constants + oscillation frequency
- Spike-sorting: **validate first**, then contact the original author (Streams); define the target ephys experiment (probe / opsin / manipulation) with the lab

**AI analysis flags (from transcript):**
- Excitatory rebound is not necessarily network recurrence: **C1V1's slow off-kinetics (~100 ms)** can produce a post-excitation rebound via residual depolarization block — weigh alongside the motion-artifact check before redesigning the controller
- 50 ms spike-sorting latency is only ~2× widefield's ~28 ms/frame — confirm sorting latency (not the neural signal / population averaging) is the actual bottleneck before investing further in the ephys pipeline

---

### 2026-07-17
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\Jul 17th.md`

**Overview:** Sine-wave tracking with **four controller modes** (OL, OL+preview, CL, CL+preview) — preview-compensated versions give the best phase alignment (~5-frame / 51° lag correction) with reduced MSE, though drowsy-trial tail variability inflates variance. Nick suggested placing the **passive (no-motor) running wheel** in the rig immediately to promote desynchronized state (encoder later). Bidirectional single-site control via the dual-opsin mouse discussed (find sites with overlapping inhib + excit footprints). For the manuscript, Aditya showed a **color-coded scatter to rule out pre-stim prediction error** as a confound for the state-dependence result — Nick agreed it's needed. Extended theory discussion: OL suppression **shifts the mean of ongoing fluctuations but NOT their variance** → raises whether mesoscale dynamics are locally generated or sub-cortically imposed. Nick proposed simulating an inhibitory input into the **Kurtow & Harris** model to test whether it predicts variance preservation.

**Key decisions:**
- **Exclude drowsy/outlier trials and recompute per-condition MSE** for the four-mode experiment; repeat with a water-restricted mouse for cleaner state
- Finalize the **pre-stim prediction-error control figure** (verify high-prediction-error trials don't cluster at high residual deviations)
- Run impulse characterization on the **excitatory hemisphere**; compare TF to inhibitory side
- **Deploy the passive wheel now** (encoder attachment later)
- Nick to simulate inhibitory DC input into Kurtow & Harris; keep the **local-vs-subcortical question as a discussion-section anchor**, not a new experiment arc

**AI analysis flags (from transcript):**
- **Forecast test** as a direct empirical probe: fit AR/VAR on baseline widefield, at opto onset forecast from both the raw (suppressed) level and the zero-mean-shifted level; if the shifted forecast tracks the actual post-stim trace better, it supports "sub-cortical drive + additive laser effect" WITHOUT needing the Kurtow & Harris sim — doable on existing data
- **Single-subject sine-wave data** (one mouse) is insufficient for statistical claims; prioritize water restriction / C1V1 mouse before these appear in a figure
- **Scope-creep risk:** agree explicitly to keep the sub-cortical dynamics question as a discussion argument, not a new experiment set
- "Joanne's paper on cortical propagation" mentioned but not cited by name — retrieve + cite precisely (possibly Huo et al.)

---

### 2026-07-06
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\July 6th.md`

**Overview:** Aditya presented the **residual state-dependence framework**: per-trial residual deviation (|trial residual − trial-average residual|) plotted against pre-stimulus variance, delta power, and motion — **motion shows the clearest effect**. Predictor is now a pixel-based **greedy mask** (worst-case contralateral pixels, uniform weights); Aditya wants to lock the mask before running validation, and will switch scatter plots to quartile bins. Nick asked for a signed (non-abs) version to test directionality, and proposed that pre-stimulus residual should be flat across state bins as a key control (since the contralateral predictor should already capture delta). Motor identified for the treadmill (~10× prior torque, side-shaft, ~$20 + $10 controller); Nick computed ~29–60 RPM suffices at 30 cm/s. Data Club talk scheduled for the next day (SFN story + short intro for new members). Several older items confirmed done (cross-references, motion-energy predictor, motor spec/purchase).

**Key decisions:**
- Add **signed** residual-deviation plots + **pre-stim residual** flat-across-bins control before claiming significance
- Finalize the greedy contralateral mask first, then rerun **quartile-binned** residual plots and slope significance test
- Treadmill: post motor specs to Slack; confirm power-supply current headroom (≥3× peak) before purchase
- Downstream items (MSE-vs-delta plots, MPC/optimal-laser) stay deferred until residual framework is locked

**AI analysis flags (from transcript):**
- "Pre-stim residual should be flat" only holds if the predictor's fitting window captures the full delta cycle (~1–4 Hz); use ≥2 s baseline or it may covary with state and falsely mimic a laser effect
- Cleaner test: **difference-in-differences** — (high-power residual variance) − (matched low-power residual variance) within the same delta/motion bin — removes state-dependent baseline asymmetry; directly addresses the SFN p-value concern
- Mask finalization is a soft bottleneck gating significance tests, SFN reconciliation, and manuscript figures — set a concrete self-imposed deadline

---

### 2026-07-02
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\Jul 2nd.md`

**Overview:** Figures-only walkthrough of the state-dependence analysis; Nick again asked for a structured, slides-based validation of each step. Core narrative reaffirmed: OL linearity holds on average → build PI controller → use controller failure to reveal state-dependence. The **SFN abstract's state-dependence p-value** was flagged as conceptually unclear — apparent state-dependence in impulse responses may reflect baseline jitter rather than nonlinear dynamics. The **SVD-based contralateral predictor map showed anomalous non-blob structure**; Nick traced this to temporal components being scaled by singular values (S×V), so regression weights aren't comparable across components without re-normalizing. Agreed framing: fit predictor on spontaneous data; at low power (no local effect) residual ≈ 0 sets a noise floor; at higher powers, residual-variance increase correlated with motion/delta isolates local state-dependence.

**Key decisions:**
- Fix SVD component normalization (account for S×V scaling) before producing spatial kernel maps; verify corrected map shows a localized blob
- Residual framework: low-power trials as null (noise floor) → higher powers compute per-trial residual variance → correlate with motion, delta power, pre-stim variance
- No presenting without a proper slide deck next time
- Low-power (~0.5 V) contralateral spread is negligible → bleed-based prediction trick only fails at high powers, not a fundamental limit on the state-dependence claim

**AI analysis flags (from transcript):**
- **Squaring the regression weights** for visualization discards sign and distorts magnitudes — use signed `U*w` with a diverging colormap; likely a separate cause of the non-blob map from the S×V issue
- Confirm exactly which matrix is the regressor before concluding weights are miscalibrated: if regressing onto `S*V'`, OLS already accounts for scale — the error is in reconstructing the kernel (`U*w`, not `Σ Uᵢ²·wᵢ`)
- Low-power residual is not guaranteed zero-mean if there's state-dependent hemispheric asymmetry — split low-power residual by delta tercile; if already state-dependent, use difference-in-differences

---

### 2026-06-29
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\Jun 29th.md`

**Overview:** Treadmill wheel fits the rig — proceeding **free-spinning now, motorized/clutch deferred to Alice's return (fall)** under Aditya's supervision; Annie (undergrad) flagged as possible contributor. **Alex (rotation student)** to be trained to run grid sessions; protocol amendment submitted, approval expected next day. Reviewed interactive GUI of 52-spot grid impulse responses (0.5 V): inhibitory spots clean; **excitatory spots show strong oscillatory/higher-order dynamics with large rebounds**; spatial specificity varies widely. Nick identified a **bidirectional-control candidate** — a midline spot inhibited by some laser positions and excited (with rebound) by others. Predictor updated to Johansson's exact SVD method; residual-approach limits discussed (bleed may itself be state-dependent) → restrict to low-bleed locations. Career: Aditya aims to post bioRxiv as soon as defensible and apply to Starfish without waiting for publication.

**Key decisions:**
- Treadmill: free-spinning first, motorized later (Alice, fall); spec + purchase motor now (overkill torque OK)
- Restrict state-dependence residual analysis to laser locations with minimal contralateral spread (visually white on opposite hemisphere)
- Collect additional grid sessions (lower excitatory power, <0.5 V) to confirm midline bidirectional target reliability; use median over mean
- Train Alex to run grids to free Aditya's time
- Get paper to SFN-abstract-consistent state before bioRxiv

**AI analysis flags (from transcript):**
- "50 trials should be enough" — ambiguous grid responses may stem from non-zero-mean pre-stim baselines (insufficient ITI jitter) inflating the mean estimate's variance, not trial count
- Pre-stimulus SEM/SD bars should straddle zero by construction (baseline-normalized) — if not, check for baseline/pre-stim window overlap or an asymmetric plotting bug
- Consider **pupil diameter** as a trial-by-trial arousal covariate alongside delta power and motion; bridges to the "wake the mouse up" direction
- Bidirectional/sleep-induction idea: likely Adamantidis et al. (2007, Nature) or Fernandez et al. (2018, Nat Neurosci) — locate exact ref

---

### 2026-06-22
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\Jun 22nd.md`

**Overview:** Treadmill fitting logistics — re-test bare wheel on the axle for camera/LED clearance; a higher-torque motor is needed (estimate from ~1 ft jump of a 40 g mouse → axle torque → ≥2× stall torque). Aditya showed new-mouse impulse data at two sites (inhibitory + excitatory, 50 trials, 0.5 V, 1 s): inhibitory responses clean and consistent with prior mice; **excitatory responses show a large, spatially distinct post-offset rebound** of unclear mechanism. **Excitatory (orange laser) activation is hemisphere-localized with negligible contralateral spread** — a positive result for the widefield opto paper. No full grid run yet; Nick directed running the proper 52-spot grid first. Contralateral SVD-based residual analysis discussed but inconclusive — Nick flagged that state-dependent contralateral bleed could confound the residual, and asked Aditya to first hit Johansson-level R² (~0.95–0.99 at rank 10) before proceeding.

**Key decisions:**
- Motor spec: max mouse force → axle torque → ≥2× stall torque; Arduino-controllable; use existing axle rotary encoder for closed-loop speed control
- Run full 52-spot galvo grid (both lasers, multiple powers, **widely jittered ITI 3–9 s**, fully randomized) — no fixed/near-fixed ITI; verify saved timestamps that jitter actually executed
- Add hemisphere-contained excitation result to the widefield opto paper
- Reproduce Johansson contra→ipsi R² first; then re-run residual analysis with clean, correctly labeled plots

**AI analysis flags (from transcript):**
- Fixed-ITI claim ("5 ± 1 s") — ±1 s is too narrow; slow delta rebound from the previous excitatory trial may persist at onset; Nick's 3–9 s range is the fix; verify from timestamps
- "Closer to midline → smaller contralateral effect" contradicts Johansson (callosal midline areas show strongest contra correlation) — resolve as possible stimulus-location calibration error or bleed-map artifact before finalizing
- Excitatory rebound looks **non-minimum-phase** — fit a 2nd-order TF with a right-half-plane zero; NMP dynamics would fundamentally limit closed-loop bandwidth and must be noted
- Test whether contralateral bleed is state-dependent: bin by pre-stim delta power, check if contra amplitude covaries with ipsi amplitude; if so the residual method needs a correction factor

---

### 2026-06-03
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\June 6th.md`

**Overview:** Reviewed Curto/Issa-style trial-sorting figure (largely complete; delta-band power column still needs integration). Nick raised that MSE-vs-variance plots conflate brain-state variance with laser-induced variance — cleaner approach is to subtract TF-modeled laser effect from each CL trial to recover a "no-laser" counterfactual, then reanalyse state-dependence. Key unexpected finding: delta power predicts MSE more strongly in closed-loop than open-loop, possibly due to phase-margin degradation near the instability frequency (~5 Hz given ~47 ms latency); Nick suggested computing predicted control quality from the power spectrum and latency-dependent phase margin directly. Spatial-spread walkthrough with frame-by-frame GUI confirmed similar timing across locations; Anna's suggestion is to characterise spread by amplitude and onset latency jointly. New mouse still in habituation; sine-wave sessions not yet started.

**Key decisions:**
- Laser subtraction: subtract TF-predicted laser effect from CL trials; compare residual variance distribution to actual no-laser trials (add shuffled-subtraction as null)
- State-dependence sorting: switch from total pre-stim variance to **pre-stimulus delta-band fraction** as primary sorting criterion
- Phase-margin analysis: compute instability frequency from full open-loop TF (PI + plant + delay), not just pure-delay approximation; plot predicted control degradation vs. input frequency
- Spatial spread: characterise jointly by amplitude AND onset latency as functions of distance from target
- Delta-band sorting during trial: must use pre-stimulus window or contralateral hemisphere to avoid confound with laser suppression

**AI analysis flags (from transcript):**
- ~5 Hz instability is approximate (pure 47 ms delay gives −85° at 5 Hz); must include PI controller and plant phase before reporting in paper
- Linearity validation: add shuffled TF-subtraction as null control (matched vs. mismatched subtraction)
- Delta sorting during trial confounded by laser — resolve with pre-stim window, contralateral proxy, or laser-subtracted trace

---

### 2026-05-29
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\May 29th.md`

**Overview:** Reviewed progress on motion-based and pre-trial-variance trial-sorting figures (partially complete; need color scheme unification, statistics, log-scale power spectra). Validated use of total pre-stimulus variance as a synchrony measure (Kenneth Harris review cited). Contralateral-prediction (pink model) partially implemented: R² ~95% on test data predicting ipsilateral from contralateral pixels in spontaneous data. Nick recommended using SVD-based hemisphere representation and consulting Joanne's Spiral paper (Fig. 3) for spatially-localized predictor maps. Concern raised about spatial spread of optogenetic effect to contralateral hemisphere; Nick attributes this to neural propagation (withdrawal of excitation), not direct light spread. Sine-wave/feedforward results are inconclusive due to insufficient trials and low amplitude — new sessions should use longer stimuli and shorter ITIs.

**Key decisions:**
- Unify laser-power color scheme across disturbance figure panels (grayscale for laser; colored text for session labels)
- Variance-ratio stem plot to add significance stars and show pre/post structure matching trial-average figure
- SVD-based left-hemisphere representation preferred over fixed pixels for the contralateral-prediction model
- Spatial spread of opto effect attributed to neural propagation — characterize frame-by-frame with widefield GUI; discuss with Anna
- New mouse sine-wave sessions: ≥4 s / ≥4 cycle stimuli, shorter ITIs; full-grid ping characterization first
- Sine-wave results may need to be scoped out of primary manuscript if new sessions don't yield enough trials

**AI analysis flags (from transcript):**
- SVD component count claim ("need 2000 components") is unusual — verify cumulative variance explained vs. component count before finalizing contralateral-prediction model
- Contralateral signal temporal onset should be checked: simultaneous onset with ipsilateral dip would implicate optical artifact; a ≥1 frame (~30 ms) lag supports neural propagation
- Spatial predictor maps: ridge regression over all contralateral pixels → weight map identifies minimal predictor set relevant for real-time multi-input controller

---

### 2026-05-11
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\May 11th.md`

**Overview:** Status review of outstanding items (several figure items now done; two mice injected, one ready to start soon). Main discussion: (1) Curto & Issa (2009) framework for trial-sorting by pre-stimulus synchrony state; (2) detailed design of three-layer contralateral-prediction model (pink/orange/red) as the path to MPC justification. Nick proposed computing a post-hoc optimal laser sequence as a quantitative ceiling on controller performance.

**Key decisions:**
- Use ~1 s pre-stimulus variance as synchrony classifier (synced vs. desynced), following Curto & Issa style
- Contralateral-prediction model redesigned into three explicit layers (see Open Items above)
- Post-hoc optimal controller benchmark framed as MPC motivation within current paper (not just forward-looking)
- Nick to raise mouse catalog at lab meeting 2026-05-12

**AI analysis flags (from transcript):**
- Curto & Issa citation: verify exact authorship (Curto, Bhatt, Issa — check before manuscript)
- "60 frames = 1 s" inconsistency still unresolved (at 35 Hz, 60 frames ≈ 1.7 s — measure artifact period directly)
- State-space ≠ transfer function for MIMO; be precise if extending to multi-region model
- 1 s pre-stim window may conflate state transitions — consider 500 ms or sliding window

---

### 2026-05-08
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\May 8th.md`

**Overview:** Detailed figure review. New inhibition-energy metric (integrated response) replacing peak ΔF/F. Transfer-function (3-pole) linear-system validation supplementary figure proposed. Error bars changed IQR → 95th percentile. Absolute power spectra agreed (not relative). New MSE window: t = +1 s to +3 s. Motion vs. MSE scatter and interactive good/bad trial spectral inspection shown. Nick asked for CLAUDE.md + RESEARCH.md for departmental AI presentation.

**Key decisions:**
- Inhibition energy = integral of ΔF/F over response window (define exact bounds precisely in paper)
- MSE computed on t = +1 s to +3 s window going forward
- Power spectra: absolute units (ΔF/F²/Hz), not relative
- Transfer-function supplement: 3-pole model, relax delay τ, validate on held-out 20%

**AI analysis flags (from transcript):**
- "Baseline window" used ambiguously to mean response window — pin exact time bounds
- Transfer-function model order stated inconsistently ("1-0-2" vs. "3 poles 1 zero") — fix before reporting R²
- "60 Hz / 60 frames / 1 s" artifact inconsistency — measure period directly in raw data
- PI bandwidth claim from delay alone is qualitative only — verify from closed-loop Bode plot

---

### 2026-04-27
**Source:** `C:\Users\aditya\OneDrive\Notes\Adick meetings\Apr 27th.md`

**Overview:** Paper-draft review. Latency distribution (~14–50 ms, mean ~30 ms) analyzed: staircase pattern is beat-frequency artifact (trial interval vs. 35 Hz frame rate); ~14 ms minimum is true code execution time. Discussed adding feedforward/preview (sine-wave) control results to manuscript. New analysis direction: contralateral-prediction model to characterize local vs. global disturbances, as MPC groundwork. Collaboration with Tim Kim (Allen Institute) on latent-space forecasting model discussed. Mouse logistics for new local viral injections raised.

**Key decisions:**
- Staircase latency artifact = beat between trial interval and 35 Hz frame clock (verify numerically before paper)
- Contralateral-prediction analysis: fit on non-control data, apply to control, characterize residuals
- Feedforward/sine-wave control results to be added as new section/figure
- Seek collaboration with Zilu (ARIMA) and Tim Kim (latent-space model)

**AI analysis flags (from transcript):**
- Beat-frequency argument plausible but should be verified numerically (trial interval vs. 1/35 s)
- Uniform latency distribution assumes async trial onset — check empirically against histogram
- 100 Hz imaging latency reduction claim assumes constant code time (may not hold at higher throughput)
- Tim Kim model: "Gumbel distribution" — verify distributional assumption before writing up
