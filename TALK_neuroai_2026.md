# NeuroAI in Seattle 2026 — 15 min talk plan

**Event:** 6th NeuroAI meeting, Allen Institute, Seattle — **20–21 Aug 2026**
**Theme:** *multi-area interactions*
**Organizers:** Adrienne Fairhall, Karel Svoboda, Ulises Pereira-Obilinovic, Amy Orsborn, Tim Kim
**Slot:** 15 min → budget **12 min talk + 3 min Q**
**Framing decided 2026-08-14 (user):** closed-loop control story, pivoting to multi-area in the last third.

---

## Governing rule

**No new analysis is run for this talk.** Six days is not enough to unblock the Stage-2
rebuild, and the server was down 2026-08-12. Everything on a slide is either an
already-exported panel or a schematic. Forward-looking work appears as *directions*,
with no numbers on the slide.

---

## Slide plan

### 1 — Opening: precise measurement + active control makes the control toolkit available (1:00)
> **Reframed 2026-08-14 (user):** *"the opening should not be about the problem but more
> that now that we have precise measurements and active control we can use brain states
> and feedback for better control — optimization, minimum-energy control, model-driven
> control."* The old deficiency-framing opener ("open loop is blind to state") is
> demoted to a single clause inside this slide. **Opportunity, not complaint.**

**The claim:** we can now measure mesoscale cortical population activity precisely and
continuously (widefield, cortex-wide, 35 Hz) *and* act on it continuously (spatially
targeted optogenetics) *and* identify the plant between them. That combination is the
**precondition for control theory proper** — and it has not been available at this scale
before.

**What it unlocks — name these explicitly, they are the talk's intellectual frame:**
- **Brain state as the feedback signal.** Ongoing activity stops being a nuisance
  variable to average away and becomes the thing you measure and act on. (This is where
  the old "open-loop is state-blind" point lives now — one clause, not a slide.)
- **Optimization.** Once there is a model and a cost, the command is *solved for*, not
  hand-tuned. You already have the cost surface to show this is real (T-A/T-B).
- **Minimum-energy control.** Given a model, drive the state along a desired path with
  the least input energy. **The scientific argument, not just the elegance:** minimum
  energy = **least-perturbative causal manipulation** — less light, less heating, less
  off-target drive. The right question is not "did the perturbation work" but *"what is
  the smallest push that produces the effect?"* That reframes optogenetics as a
  **designed** intervention.
- **Model-driven control.** The plant model is identified from data (slide 4), so the
  controller is designed rather than tuned — and, per slide 9, the model can be learned.

**The positioning line, and it is a strong one:**
> Network-control theory has been computing control energy and controllability on
> *structural connectomes* for a decade — almost entirely **without an actuator in the
> loop**. The theory has been waiting for a system where you can actually apply the
> input and measure what happened. That is what we built.

---

#### 🚀 Opening analogy — aerospace (user's own background: PhD, aero/astro + control)

**Use it. It is authentic to the speaker, it makes the control ideas legible to the
neuroscience half of the room, and the structural mapping is genuinely tight — not
decorative.**

**Recommended split: rocket in slide 1, aircraft in slide 9.** Two analogies, each doing
one job, neither overstaying. Do **not** thread either through every slide.

**Slide 1 — powered descent / rocket landing.** Maps onto the *actuation and
optimization* structure:

| Powered descent | This system |
|---|---|
| Thrust is **one-sided** — you can push, not pull; gravity does the rest | The laser **only inhibits**: `0 ≤ u ≤ u_max` |
| **Minimum-fuel** trajectory, not just "any landing" | **Minimum-energy** control = least-perturbative manipulation |
| Bounded, non-convex thrust constraint → solved as a **convex program** (the lossless-convexification / powered-descent guidance line, Açıkmeşe & Ploen) | One-sided actuation makes this a **constrained QP, not LQR** |
| Terminal constraint, hard deadline, delay in the loop | Trial window, ~14 ms loop delay, ~160 ms plant lag |

> The line to say: *"one-sided bounded actuation with a fuel cost — that is a solved
> problem in aerospace, and it is exactly the structure of a laser that can only
> inhibit."*

**Slide 9 — aircraft gust rejection.** Maps onto the *disturbance and forecasting*
structure: modern gust-load-alleviation uses **forward-looking sensing to measure the
gust field before it reaches the wing**, and feeds it forward. That is precisely
preview control (slide 6) generalized to a *predicted* disturbance — the MPC close,
in one image the room already understands.

**"…but with so much variability it's too hard" — the honest disanalogies. Name them;
they are the scientifically interesting part, and stating them is what stops this
reading as engineering-imperialism:**
1. **You don't get the plant for free.** A launch vehicle has mass properties and
   aerodynamics from first principles. Here there is **no first-principles model** — the
   plant must be *identified from data*, per animal, and re-checked for transfer. That's
   why slide 4 exists and why TF-D matters.
2. **The disturbance is the system.** Wind is exogenous to the aircraft. Here the
   "disturbance" is ongoing cortical activity — it is *the thing you're studying*, not
   a nuisance blowing in from outside. You are rejecting a signal you also want to
   measure. **This is the sentence that turns the analogy into the talk's thesis.**
3. **You don't know the reference.** A rocket's desired trajectory is specified by the
   mission. **What trajectory *should* neural activity follow?** That's an open
   scientific question, not a control one — and it's the best possible thing to leave
   the room chewing on.

**How we figure it out — and this is the honest answer to the user's question, because
it's just the standard control-engineering program applied to a plant nobody has
first-principles equations for:** identify the plant from data (slide 4) → close the
loop and measure how much variability feedback removes (slides 5–6) → characterize what
remains and where it comes from (slides 7–8) → model the disturbance and go
model-predictive (slide 9). **Say that as the roadmap on slide 1.** It gives the
audience the whole talk in one sentence, and it is exactly what an aerospace controls
person would do faced with an unknown plant.

⚠ **Dosage warning.** Half this room is neuroscientists. Use the analogy **once**,
crisply, then drop it — an extended aerospace metaphor reads as "biology is just an
engineering problem" and will cost you the room. The disanalogies above are the
insurance: they show you know where it breaks.
⚠ Spoken as an analogy, none of this needs a citation. If Açıkmeşe/lossless
convexification appears on a slide **as a reference**, verify it first — it is not in
`refs.bib`.

---

**Assets:** text + the loop cartoon. Consider one line of the state-space equations
`x⁺ = Ax + Bu`, `y = Cx` — this audience reads them instantly and it sets up slide 9.
**⚠ Citation gap:** the connectome-controllability literature (Gu et al. 2015,
*Controllability of structural brain networks*, Nat Commun, and the Pasqualetti/Bassett
line) is **NOT in `refs.bib`** — I checked. **Verify the exact reference before putting
it on a slide; do not cite from memory.**
**You have more support for this framing than the plan previously showed** — see
"Existing state-space / controllability work" below.

**Compressed to ONE clause inside slide 1** (was the whole opener): *"open-loop
delivers a fixed light pattern irrespective of ongoing state, so the same command lands
differently depending on when it arrives (Harris & Thiele 2011)"* — then immediately
turn it positive: **that state is measurable now, so it becomes the feedback signal
rather than the noise.** Source: `introduction.tex` ¶4. Do not dwell; the payoff
("perturbation becomes a controlled independent variable") lands on slide 2.

### 2 — What already exists, and the gap (1:15)
> **Added 2026-08-14 at the user's request** — the plan had no positioning against the
> field. This slide is what makes the contribution legible instead of implied.

**Acknowledge, specifically and generously — closed-loop optogenetics is not new:**
- **Newman et al. 2015** — the "optoclamp": a **PI controller** locking single-neuron
  firing rate to a target, in culture and anesthetized rat thalamus. *This is our
  direct methodological ancestor — name it as such.*
- **Bolus et al. 2018 / 2021** — model-based design, then **state-space LQR optimal
  feedback control** of single-neuron firing rate in awake head-fixed mice.
- **Kanta et al. 2019** — closed-loop control of amygdala gamma → causal link to memory
  consolidation. The exemplar of *why* you'd want the loop closed.
- **Nicholson 2018 / Zaaimi 2023** — closed-loop modulation of network oscillations,
  slices and NHP.
- **Clancy et al. 2014** — volitional modulation of optically recorded calcium via a
  neuroprosthetic interface.
- **Grosenick, Marshel & Deisseroth 2015** — the review that laid out the framework.

**The gap — two threads, and we sit at their intersection:**
- **Closed-loop optogenetics** works, but almost entirely at **single-neuron or LFP
  scale with electrophysiology as feedback**. Mesoscale population control with
  wide-field calcium as the readout is largely unexplored — and mesoscale is the scale
  at which distributed cortical computation actually happens.
- **Network-control theory** (controllability, control energy, minimum-energy input) has
  been developed on **structural connectomes with no actuator** — the inputs are
  hypothetical.

> One thread has the loop but not the scale; the other has the theory but not the
> actuator. **Simultaneous widefield + spatially targeted opto (Matveev et al. 2024)
> is what lets you have all three at once.**

**Why it matters — the payoff line, land it explicitly:**
> Closing the loop turns the perturbation into a **controlled independent variable**.
> Instead of *"we delivered 2 mW to this region"* you can say *"we held this region at
> −5 % ΔF/F"* — and then ask what that does. That is a different class of causal
> experiment, and it is only available with feedback.

**And the bridge to the second half of the talk — same idea, stated from the other side:**
> Once you are actively rejecting a disturbance, **the disturbance is the rest of the
> brain**. Control performance becomes a *measurement* of ongoing multi-area dynamics.

**Assets:** text slide, ~6 citations. Consider one small figure: single-neuron/LFP scale
vs mesoscale, as a scale bar. **Do NOT frame open-loop as flawed** — it produced the
foundational results, and **Svoboda is in the room**. Frame it as: right tool, different
question.
**Source:** `Closedloop_edit/introduction.tex` ¶4–7; all citations already in `refs.bib`.

### 3 — The loop (0:45)
> Trimmed — slide 1 now carries the framing, so this is just the implementation.
**Claim:** A real-time PI controller closes the loop at 35 Hz: widefield SVD readout →
kernel-mean ΔF/F at a target pixel → PI → 638/594 nm laser.
**Assets:** `paper/images/wfpath.pdf`, `paper/images/schematic_optoephyswf (1).pdf`,
`paper/images/figure1/svd_frame_AL_0039_2025-04-19.pdf`, `paper/images/arch.pdf`
**Quote:** ~14 ms minimum loop latency; ref = −5 %ΔF/F.

### 4 — Plant identification + transfer (1:30)
> **Slides 3 and 4 of the old plan are now merged** — the positioning slide has to come
> from somewhere, and TF-A/TF-D are the cheapest minute in the talk to compress.
**Claim:** The cortical response to photoinhibition is approximately linear and is
captured by a low-order LTI transfer function.
**Assets:** `paper/images/figure2/imp_single_AL_0033_2025-01-29_en1.pdf` (2A),
`paper/images/figure2/imp_response.pdf` (2B),
`paper/images/figure2/tf_shape_across_sessions.pdf` (2C-i)
**Quote:** inhibition energy = mean ΔF/F over 0–200 ms; peak scales approximately
linearly with amplitude (n=3 sessions).
**Do NOT say:** "LTI" as a proven waveform-superposition claim — waveform
superimposition was never verified. Say *"approximately linear, well described by a
low-order model"*.

**Second half of the slide — the plant transfers:** time constants are consistent
across sessions, and a model fit on one session predicts another's measured response,
so a controller designed once transfers.
**Assets:** `paper/images/figure2/tf_tau_forest.pdf` (TF-A, 95% bootstrap CI),
`paper/images/figure2/tf_model_swap.pdf` (TF-D, diagonal ≈ off-diagonal)
**Note:** TF-D uses **free gain** — this is a claim about *dynamics*, not gain. Say so.
**If you overrun, TF-D is the first thing to drop** (keep TF-A; consistency of τ is the
load-bearing half).

### 5 — Closed loop holds the set-point — **VIDEO** (2:15)
**Claim:** Closed-loop control reduces tracking error relative to open-loop, and it
replicates across mice.
**Assets:** ▶ **`presentation/controller_demo_m13_full_hd.mp4`** (39 s, 1080p) —
real widefield ΔF/F movie replayed with the live-rig GUI: ROI goes blue under stim,
CL holds −5 % while OL overshoots, trial-average and across-trial variance
accumulating live. Then cut to **`paper/images/figure3/pooled_ol_cl_rmse_15sess.pdf`** (3K).
**The video REPLACES static panels 3A/3B/3C** — it shows all three at once, moving,
and it is the single most persuasive 40 s in the talk. Keep 3A–3C loaded as backup
in case AV fails.
**Quote:** **CL < OL in 14 of 15 sessions, signrank p = 1.2e-4.** Pooled OL 3.11 /
CL 2.44 %ΔF/F. RMSE window t = 0→+3 s. m13 = AL_0039 2025-04-20, ~30% CL-vs-OL gap.
**Say RMSE, never MSE** (project-wide rename 2026-07-16).
**Say aloud once:** *"this is a replay of real session data through a replica of the
live GUI, not a screen capture"* — the traces, gains and brain movie are all real, but
say it so nobody thinks you're claiming a raw capture.

### 6 — Time-varying reference: feedback vs preview — **VIDEO** (1:45)
**Claim:** Tracking a 1 Hz sine separates two things people usually conflate —
**the error win comes from feedback; the phase win comes from preview.**
**Assets:** ▶ **`presentation/ff_demo_0721_hd.mp4`** (63 s — **trim to ~30 s** or
talk over the first half), then `sine_combined_rmse.pdf` (5I) +
`sine_combined_phase.pdf` (5J). Static fallback:
`paper/images/figure5/sine_5C_trialavg_AL_0048_2026-07-14_1.pdf`.
**Quote:** CL < OL in all 3 sessions, pooled p = 1.5e-4. Preview: OL 60° → 5° lag;
preview lookahead 143 ms ≈ the measured ~160 ms plant lag.
**Do NOT say:** preview reduces error (OL vs OL+preview **n.s.**, p=0.49); or that
CL+preview beats CL (p=0.093 *in CL's favour*); or that Friedman is significant
(n=3, p=0.060, underpowered).
**Caveat aloud:** one mouse, one hemisphere, 3 sessions — call it preliminary.

### 7 — PIVOT: the disturbance is the rest of the brain (1:30)
> Callback: this is the bridge line you already planted on slide 2. Say it the same way
> twice — it's the spine of the talk.
**Claim:** What limits the controller is ongoing multi-area activity. Using the
contralateral hemisphere we can predict the target site *as if no laser were applied* —
giving **Global** (network-shared) vs **Local** (input-driven) per trial.
**Assets:** `impulse-analysis/data/cp_zhiwen_validate.png`,
`paper/images/Widebrain predictor pixels.png`, `paper/images/figure2/cp_kernel_map.png`
**Quote:** predictor validated against Ye et al. 2023 — **0.978 on their data**
(reproduces their ~0.99), **0.925 on ours** → the gap is data (bilateral coherence/SNR),
not method. On m4, the OL trial-average splits **~50% local / ~50% network-shared**.
**Do NOT show:** any pre-stim-variance or δ-power state-dependence result. Retracted
2026-07-01 as a signal-power confound, and relative-δ *flipped sign* on Ye's data.
That's the one slide that could get you correctly taken apart in this room.

### 8 — Disturbance rejection, and the internal model principle (1:30)
> **NEW 2026-08-18 (user):** *"promote more of the internal model principle and
> disturbance rejection story alongside showing that MPC can do even better."* This is
> now the empirical centre of the second half — and it is the **strongest cross-session
> result in the talk** (13/13 sessions).

**Measure the rejection.** With Global as the counterfactual disturbance, define the
**energy ratio** `ER = ‖A − ref‖² / ‖G − ref‖²`. Both terms share the reference, so
**ER = 1 means the controller did no work** and **ER < 1 is controller gain** — the
level is interpretable on its own, not only as an OL-vs-CL contrast. (This is Nick's
2026-07-28 metric; it is implemented and is PRIMARY. The legacy
`ρ = ‖A−ref‖/‖G‖` is retained for reproducibility — **never mix the two**, and every
number logged before 2026-08-10 is in ρ units.)

**The numbers — all run, all cross-session:**
- **ER median OL 0.291 → CL 0.203. CL better in 13 of 13 sessions, signrank p = 2.4×10⁻⁴.**
- Per-session rank-sum significant in **11/13**. The two that miss are exactly the two
  new mice with weak predictors (AL_0048 p=0.299 R²=0.441; AL_0051 p=0.755 R²=−2.058),
  so the result does **not** rest on them and their inclusion is *conservative*.
- Strongest: AL_0033_0304_e1 0.477→0.207 (p=1.6×10⁻⁷); AL_0039_0430_e3 0.311→0.182
  (p=6.1×10⁻⁸).
- Per-trial **transmission β** (slope of Actual on Global; 1 = passes straight through):
  m4 **OL 0.97 → CL 0.56**. Open-loop, the disturbance passes through essentially
  untouched; feedback nearly halves it.
- **Rejection is state-INVARIANT** — a roughly constant OL−CL offset across motion and
  δ quartiles. State-dependence returned null ([IMP-STATE-QUARTILE] m4: all four r_s
  null; [IMP-XSTATE] 7 sessions: no surviving slope, Friedman n.s.). **Say the
  invariance as the finding** — it is the honest read and it is a good result.

**Then the theory — this is the slide's real payload:**
> The **internal model principle** (Francis & Wonham): to reject a class of disturbances,
> the controller must *contain a model of that disturbance's dynamics*. A PI controller's
> integrator is an internal model of a **constant**. That is why it holds a set-point
> beautifully against DC drift — and why it bottoms out at ER ≈ 0.20 rather than 0
> against ongoing cortical activity, **which is not constant**.

> ⇒ The residual is not a tuning failure. It is a **missing model**. Give the controller
> the right internal model — a learned model of the network's dynamics — and the theory
> says you can do better. **MPC is not an add-on here; it is what IMP prescribes.**

**Setup slide before this one (deck slide 9)** uses `paper/kernelmap_paint.png` —
the Zhiwen-style coloured map: **six ipsi target sites and their colour-matched contra
kernels**, opacity ∝ |weight|, sparse grid winner-coloured by which ipsi target each
contra pixel best predicts. Generator `impulse-analysis/kernelmap_paint.m` (2026-07-10),
Okabe-Ito palette. **The point: the contra→ipsi mapping is TOPOGRAPHIC** — distinct ipsi
sites draw from distinct contra territory, so Global is structured, not one diffuse
signal. That is itself a multi-area-interaction result. Backup panels
`talk/img/kernel_filter.png` / `kernel_pattern.png` cover the filter-vs-pattern question
if asked (ρ = −0.02, 47 % sign flips; Haufe 2014).

**Assets:** `f4_reject_demo_ol.png` / `f4_reject_demo_cl.png` (Global-as-disturbance vs
Actual vs ref, shared y-limits — this *shows* rejection), `f4_reject_paired_er.png`
(the 13/13 paired plot).
⚠ These panels carry a burned-in **`UNGATED (no R² floor, n=13)`** annotation which
collides with their titles; the deck crops the top band, so **the ungated caveat must be
carried in the caption instead** — it is, do not drop it.

### 9 — Multi-area, directly (0:45)
> Frame the network model as **the forward model slide 9 needs**, not as a standalone
> result — that's what earns the close.
**Claim:** With a dual-opsin bilateral prep we drive 52 sites and identify the
site-to-site network — and the dynamics need 2nd order to reproduce what we see.
**Assets:** `bilateral/grid/grid_png/grid_spatial.png` (opposite-polarity hemispheres),
`bilateral/grid/network_png/net_driven_wave.png`
**Quote:** 1st-order driven Laplacian is stable and recovers opsin signs (77%
hemisphere match) but is monotone → *structurally cannot* produce the observed rebound.
The 2nd-order driven graph-wave model oscillates (~7–8 Hz modes) and captures it.
Delay-DMD is the predictive ceiling, not a mechanistic model.

### 10 — Close: from set-point regulation to **steering trajectories** with a learned forward model (1:15)
> **Expanded 2026-08-14 at the user's request** — the talk now ends on the NeuroAI
> thesis: *learned forecasting models can guide neural trajectories via MPC.* This is
> the slide the AI half of the room came for, so it gets real time, not 30 s.

**The argument — and every premise is something you already showed:**
1. **We have a plant model, and it transfers** (slide 4). MPC needs a forward model;
   we have one, and TF-D says it isn't session-specific.
2. **Lookahead already works on real data** (slide 6). Preview with a 143 ms horizon
   cancels the plant's phase lag. That is an *existence proof* that anticipation buys
   you something — on a **known** reference.
3. **The disturbance is *reconstructable* from the rest of cortex** (slide 7) —
   R² ≈ 0.93 from the opposite hemisphere. ⚠ **Say "reconstructable", not
   "predictable".** Stage 5a shows contra adds **no temporal information** beyond ipsi's
   own past (0.835 contra-informed vs 0.863 ipsi-only at the 86 ms loop-delay horizon).
   Contra gives you the disturbance's **spatial** structure, not its future.
4. **The forecasting has to come from the network dynamics** (slide 8) — the graph-wave
   model and delay-DMD roll site-to-site dynamics forward. **This is the premise that
   carries the forecast**, and it is the one still to be earned.

> ⇒ **Compose them:** forecast the disturbance, then solve for the command sequence that
> minimizes deviation from a desired *trajectory* over a receding horizon. The set-point
> becomes a path. That is MPC, and the forward model is exactly where learned /
> sequence-model methods enter.

**Why this is the interesting claim for this audience:** it inverts the usual NeuroAI
direction. Not *"can a network model predict neural data"* — but *"is a learned forward
model good enough to **steer** the system?"* Closed-loop control is the sharpest
available benchmark for a dynamics model, because a wrong model shows up immediately as
tracking error. **Prediction accuracy is a proxy; control performance is the test.**

---

#### ✅ MPC evidence EXISTS — corrected 2026-08-18. The old "no numbers" guard was wrong.

`ctrl_optimal_control.m` **has run on m4** and the result is on disk
(`paper/images/predictor_saga/ctrl_optimal_AL_0033_0226_e2.png`), three panels:

| | m4, trial-averaged, ref = −5, `u_max` = 2.06 |
|---|---|
| Steady RMSE (1–3 s) | **PI 1.202 → causal optimal 0.146** (−87.8 %), non-causal 0.000 |
| Full window (0–3 s) | PI 1.510 / causal 0.994 / non-causal 0.927 |
| Mean laser command | **PI 1.563 → optimal 1.300 — the optimal controller uses LESS light** |
| Measured disturbance | drifts **+1.82 %** over the trial (waning inhibition); both optima ramp `u` late to fight it |

**Two things here are worth more than the headline number:**
1. **Causal ≈ clairvoyant (0.146 vs 0.000).** Nearly all the achievable gain is
   reachable **causally** — the PI gap is *not* about needing to see the future. That
   pre-empts the obvious objection ("of course a non-causal optimum wins").
2. **Better tracking with LESS command.** This closes the loop on slide 1's
   minimum-energy framing: *least-perturbative* is not a trade against performance here,
   you get both. **Make this the punchline.**

**⚠ HONESTY — say these out loud, do not let them be inferred:**
- **This is ONE session and TRIAL-AVERAGED.** Not a cross-session claim.
- **The disturbance definition FLATTERS the optimizer.** `d = y_PI − H·u_PI` is a
  *post-hoc residual* measured from the PI trials, so it **absorbs plant mismatch** —
  part of the "optimal" advantage is the optimizer repairing the plant model, not doing
  better control. The project's own reading rule (2026-08-12): *a gap that survives
  under `'global'` is a control result; one that appears only under `'residual'` is the
  optimizer fixing the model.*
- **The version that would be a real control result is NOT done.**
  `ctrl_optimal_xsess.m` with `src='global'` — the contra-predicted disturbance, which
  is *available in real time* — has run on only **n = 2 sessions, p = 0.5**
  (`f4_mpc_rmse_global.png`), and its exemplar panel is **AL_0033_0212_e2, the session
  flagged for exclusion** (frame transposed at load, laser ~5× weak, spot straddling the
  midline). **Do not show the `f4_mpc_*_global` panels and do not quote n=2.**
- Say: *"on one session, with the disturbance measured post-hoc, the optimal controller
  more than halves the tracking error using less light — we are running the version that
  uses the real-time-available disturbance now."*
- **The contra→ipsi predictor is instantaneous** (pX = 0) — it reconstructs the target
  from *contemporaneous* cortex, it does **not** forecast. Turning it into a genuine
  forward model is the open problem, and it is the honest gap between slides 7 and 9.
  If you gloss this, someone in this room will find it in Q&A — better that you name it.
- **Actuation is one-sided** — the laser only inhibits. This is a constrained QP, not
  LQR, and whenever the disturbance already sits below reference **no command helps**
  and the error is irreducible. Quantifying that fraction is the first thing the ceiling
  analysis will produce.
- Loop delay ~14 ms; plant lag ~160 ms. Both bound the achievable horizon.

**Callback to the opening analogy (see slide 1):** gust-load alleviation on modern
aircraft uses **forward-looking sensing to measure the gust before it hits the wing**
and feeds it forward. That is preview control (slide 6) generalized to a *predicted*
disturbance — one image, and the room has the whole MPC idea. This is the analogy's
**second and last** appearance; don't reuse the rocket here.

**Assets:** schematic only — receding-horizon cartoon (predicted disturbance → optimized
command sequence → trajectory vs set-point). Reuse `bilateral/grid/network_png/net_driven_wave.png`
from slide 8 as the "forward model" box so the composition reads visually.
**Already on TASKS:** ⭐ PORT objective-2 (the ceiling) and objective-3 candidate (c) —
*"if Global is predictable ahead of time from contra, a preview controller should beat
the PI"* — this slide is that item, stated as a research direction.

**Then close on the slide-2 claim, now earned:** we can hold a cortical region at a
commanded activity level; what stops us holding it perfectly is the rest of the brain;
that residual is measurable — and if we can *forecast* it, we can steer through it.
Acknowledgments.

**Ask from the stage:** this is the natural moment to say you're looking for forward
models good enough to close the loop on — with **Tim Kim** (organizer, latent-space
widefield model, already on TASKS) and **Guillaume Bellec** in the room.

---

## Budget

**Assumes 12 min content + 3 min Q.** ⚠ **Confirm with the organizers** whether the
15 min is inclusive of questions — if it's 15 + Q, restore TF-D, run the 1:05 talk cut
of the m13 video instead of the 0:39, and give slides 2 and 7 another 30 s each.

| # | Slide | min |
|---|---|---|
| 1 | Opening: measurement + control ⇒ the control toolkit | 1:00 |
| 2 | What exists + the gap + why it matters | 1:00 |
| 3 | The loop | 0:45 |
| 4 | Plant ID + transfer (**TF-D → backup**) | 1:15 |
| 5 | CL holds set-point — **video** + 3K | 2:00 |
| 6 | Sine: feedback vs preview — **video** + 5I/5J | 1:30 |
| 7 | Pivot: the disturbance is the rest of the brain | 1:00 |
| 8 | **Disturbance rejection + internal model principle** | 1:30 |
| 9 | Multi-area grid + network model | 0:45 |
| 10 | **Close: MPC does better — and needs less light** | 1:15 |
| | **Total** | **12:00** |

**Cut order if the dry run overruns:** trim the ff video to 20 s (−0:10) → slide 8's
delay-DMD aside (−0:15) → slide 3 (−0:10). **Protect slides 2, 5 and 9** — the
positioning, the video, and the closing thesis are what the talk is actually for.

**Note the shape this now has:** slides 4, 6, 7 and 8 are each independently a paper
result *and* a premise in slide 9's argument. Signpost that as you go ("hold onto
this — we'll need it at the end"), so the close reads as assembly rather than a wish
list. TF-D moved to backup to buy slide 9 its time; τ-consistency (TF-A) is the
load-bearing half and stays.

---

## Video assets (all 1920×1080 H.264, drop straight into PowerPoint/Keynote)

Built by `presentation/` — a white-theme replica of the Rainier live GUI replaying
**real** closed-loop sessions, including the true widefield ΔF/F movie reconstructed
from the session SVD over a masked anatomy underlay.

| File | Length | Content | Use |
|---|---|---|---|
| `presentation/controller_demo_m13_full_hd.mp4` | 0:39 | m13 = AL_0039 2025-04-20, **step** stim, 100 trials, ~30% CL-vs-OL gap | **Slide 5 primary** |
| `presentation/controller_talk_m13_hd.mp4` | 1:05 | talk-cut of the same session | alternative if 39 s feels rushed — costs 26 s |
| `presentation/controller_demo_m5_full_hd.mp4` | 0:24 | m5 = AL_0033 2025-03-04, **pulse** stim, 60 trials, ~28% gap | shortest option / second mouse |
| `presentation/ff_demo_0721_hd.mp4` | 1:03 | feedforward + preview, session 0721 | **Slide 6**, trim to ~30 s |
| `presentation/session_previews/*.mp4` | ~short | 7 per-session performance previews | backup / Q&A |

**Honesty line to say once:** replay/reconstruction, not screen capture. Traces, gains,
RMSE and the widefield movie are real session data; the layout is restyled.

**Caveat for the m5/m13 laser panel:** it shows the command **amplitude envelope**
(sliding-window max), not the raw carrier — flat for OL, modulated for CL. If someone
asks why the OL command looks like a clean step, that's why.

**AV checklist:** confirm the Allen Institute podium accepts your laptop over HDMI and
that you present from **your own machine** — embedded 1080p H.264 in PowerPoint is where
conference AV most often fails. Have the .mp4 files loose on the desktop as a fallback,
and a static-panel version of slides 5–6 in the same deck.

---

## Existing state-space / controllability work — supports the slide-1 framing

Found 2026-08-14 while reframing the opener. The "optimization / minimum-energy /
model-driven control" theme is **not aspirational** — there is a real Stage-5 thread:

| Script | What it is | State |
|---|---|---|
| `controller-analysis/ctrl_subspace_id.m` | **Stage 5a** — subspace ID of a discrete innovations-form latent model, `x⁺=Ax+Bu+Ke`, `y=[8 contra POD channels; ipsi dFk]`, `u` = laser envelope. OL-only identification (CL held out — closed-loop ID is biased). m4: nx=11, delayest 2 samples | RUN on m4 |
| `controller-analysis/ctrl_spatial_modes.m` | **Stage 5b** — controllability/observability **Gramians**, PBH cosine, generalized eigenproblem `Wo_contra v = λ Wo_ipsi v`, modal maps. Design rule: *Gramians → scalars, eigenmodes → pictures* | RUN on m4, 11 s |
| `ctrl_gramians.m` (5b), `ctrl_mimo_control.m` (5c) | Named as NEXT in the 5a header | **do not exist yet** |

⚠ **`utils/ctrl_gram_build.m` is NOT a controllability Gramian** — it is a regression
Gram (`X'X`) for the subset-fit K sweep. Don't conflate them on a slide.

### ⚠ The Stage-5a result that constrains what slide 9 may claim
**Adding contra channels makes ipsi prediction slightly WORSE, not better.** m4, at the
loop-delay horizon (kPred=3 ≈ 86 ms): held-out OL R² **0.835 contra-informed vs 0.863
ipsi-only** (gain −0.028); on out-of-regime CL trials **0.670 vs 0.737**. Stage 5b's own
summary: contra carries **no temporal information beyond the ipsi readout's own past**
(gain ~ +0.009) — contra and ipsi are *two views of one shared latent state*, ipsi in
time, **contra in space**.

**Consequence, and it is the sharpest thing in this document:** "we can forecast the
disturbance from the other hemisphere" is **not supported by your own data**. Contra
buys you a *spatial* interpretation of the regulated state, not extra *temporal*
predictive power. So slide 9's forecasting premise must rest on **network dynamics**
(the graph-wave / delay-DMD models) — not on contra. This is the deeper version of the
"predictor is instantaneous (pX=0)" caveat and it is exactly what a control-literate
audience would corner you on. Fixed in slide 9's premise 3 below.

---

## Backup slides (prepare all three — this room will ask)

1. **"Is that controller work, or state-dependent actuator gain?"** — Nick's central
   objection (MEETINGS `2026-07-28.2`). A control-literate audience lands here fast.
   Honest answer: the identification test (residual ~ pre-stim δ × condition
   interaction) is designed and not yet run.
2. **Hemodynamics** — single-wavelength ΔF/F conflates neural and blood-volume signals.
   Have the number ready: **7 of 13** controller sessions have hemo-corrected `corr/`,
   5 fall back to uncorrected + `detrendAndFilt`.
3. **"Why PI and not MPC?"** — latency budget, and the fact that a plant model good
   enough for MPC is exactly what slide 8 is building.

Optional 4th: gain-grid cost surfaces `paper/images/tuning/grid_cost_surface_AL_0033_0305.pdf`
+ `autotune_convergence_both.pdf` if anyone asks how the gains were chosen.

---

## Explicitly OFF the slides

| Item | Why |
|---|---|
| Fig 4 state-dependence panel set | Audited 2026-07-21 — most panels UNUSABLE |
| Pre-stim variance / absolute δ effects | Retracted 2026-07-01, signal-power confound |
| Relative-δ predictability effect | Flipped sign on Ye `AB_0004` (−0.25 vs our +0.29) |
| 2G rebuild (`imp_state_reldelta_scatter.pdf`) | Not on disk — never ran |
| Global/Local **controller** port | Stage-2 rebuild blocked, all downstream UNRUN |
| Optimal-control ceiling numbers | `ctrl_optimal_xsess.m` built 2026-08-12, UNRUN |
| AL_0050 | Excluded, poor expression |

---

## Build tasks (when we move from plan → build)

1. **⚠ Biggest mechanical job: talk-scale panel re-export.** Every paper panel is
   **6 pt bold at 4–6 cm wide** — projected, that is unreadable from row 3. Needs a
   talk mode in `utils/paperStyle.m` (≈14–16 pt, thicker lines, ~20 cm width) and a
   re-export. Do not hand-scale the PDFs; the fonts won't reflow.
   **Scope shrank once the videos came in** — the panels that actually need re-export
   are: 2A, 2B, 2C-i (slide 3), **3K** (slide 5), **5I + 5J** (slide 6). Panels 3A/3B/3C
   are now video-replaced and only need re-export if you want the AV-failure fallback
   to look right — do them last.
2. Trim `ff_demo_0721_hd.mp4` to ~30 s (ffmpeg is available via the `imageio-ffmpeg`
   pip package in `.venv` — no system ffmpeg needed).
3. Check `paper/images/poster1–5.png` — an assembled poster already exists and may
   carry composed layouts worth reusing.
4. Speaker notes per slide with the exact numbers above.
5. Two timing runs; 12 min is tight for 10 slides **with 70 s of video in them**.

## Schedule (talk is Thu 20 / Fri 21)

| Day | Task |
|---|---|
| Fri 14 Aug | Plan locked (this file) |
| Sat 15–Sun 16 | `paperStyle` talk mode + re-export slides 3/5/6 panels; deck v1 |
| Mon 17 | Speaker notes + 3 backup slides; timing run 1 |
| Tue 18 | Dry run for Nick; revisions |
| Wed 19 | Final revisions; travel |
| Thu 20 / Fri 21 | Talk |

---

## People worth targeting in the room

- **Tim Kim** (organizer) — already on TASKS: *"Prepare widefield dataset for Tim Kim
  latent-space model; arrange joint meeting."* This talk is the natural opening; the
  Global/Local decomposition on slide 7 is exactly the interface.
- **Amy Orsborn** (organizer, UW) — BCI/co-adaptive control; slide 5 and the
  actuator-gain objection are her territory.
- **Guillaume Bellec** — network dynamics; slide 8's graph-wave vs delay-DMD trade-off.
- **Karel Svoboda** — the Chrimson spatial-spread citation is still an open `\todo` in
  `methods_edit.tex` L292 and was flagged as *Nuo Li / Svoboda*. Ask in person.
