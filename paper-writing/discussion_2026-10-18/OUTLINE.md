# Discussion structure (draft 2, 2026-10-18, after verification)

About 2,900 words by texcount, against a ~2,500 target (optional cuts are listed at the bottom). It follows your five themes in your order. Limitations are folded into each theme, with one short closing paragraph.

Files in this folder:
- `discussion_draft.tex`: the prose. It replaces `discussion.tex` wholesale.
- `methods_remark.tex`: the formal remark. It goes after methods_rewrite.tex L323.
- `new_refs.bib`: 32 new entries, all verified. Append to refs.bib.
- `LIT_REVIEW.md`: every reference found in the first pass, with the checkers' verdicts.
- `VERIFY_REPORT.txt`: the second pass, with per-claim evidence and fixes for facts, control theory and every citation.

A scratch build has been run: main.tex plus this draft plus the remark plus the bib compiles with no undefined references or citations (43 pp). Nothing has been written into Closedloop_edit yet.

---

## 0. Opening (81 words)
Three results: tracking (Fig 3H,I), rejection (Fig 4G) and a state-dependent residual (Fig 4D). Then the tension the Discussion answers: the controller was set from a trial average that single trials depart from. The structure and K_r came from the average; Kp and Ki were tuned by hand.

## 1. A monotone trial-averaged response suffices to design a stabilizing controller (~410)
**Theme 1.**
- **P1, the guarantee.**
  - The impulse models are stable (slowest mode poorly constrained, Fig 2F) and the dose–response is monotone (Fig 2B).
  - Monotone means exactly one steady-state drive per feasible reference.
  - PI with matching sign and low gains tracks with no dynamic model (Desoer & Lin).
  - Integral control survives saturation and delay (Logemann & Curtain), though no single theorem covers PI, saturation, delay and sampling together (Remark).
  - The integrator finds the equilibrium input itself (Francis & Wonham).
  - P alone leaves part of any offset.
- **P2, what variability costs.**
  - Session variation changes gain limits and speed, not whether a fixed-sign controller exists (Morari: G(0) ≠ 0, sign fixes the controller's sign). Variation sources: gain 2B, shape 2E, rebound 2F.
  - Caveats, one sentence each:
    1. Asymptotic and nominal.
    2. Stability is empirical: no sustained oscillation, the only instability a bounded loop can show.
    3. Frozen-plant assumption (Desoer 1969), with brain state not much slower than the loop.
    4. The sign is measured, not guaranteed (Li 2019; Sanzeni 2020).

## 2. Linear on average, variable on every trial (~720)
**Theme 2.**
- **P1, why the average is linear.**
  - R² 0.85, yet single trials scatter and models transfer poorly (2C–E).
  - Averaging gives linearity (Nozari).
  - Your stance: the system is nonlinear, driven by unobserved inputs, and state dependent, hence parameter dependent and non-stationary. Average = plant; departures = disturbance.
  - Galgali 2023.
- **P2, the pointed critique.**
  - New topic sentence: models either fit single trials with inputs inferred after the fact (LFADS, CURBD) or forecast for barely a second (Lu 2025, ZAPBench). Both fail for the same reason: inputs are unknown when the controller must act.
  - "Their fit over-approximates what is knowable in real time" is kept as sentence 2.
  - Vahidi 2024.
  - **Own data link themes 2 and 3:**
    - Contralateral R² 0.76 means the drive is observable as it arrives.
    - VARX 0.41 vs 0.37 at 200 ms means it is not forecastable (cortical sites add more at longer leads).
    - "Observable but not forecastable, which is the situation feedback is built for."
- **P3, why LTI for control** (your "favorable to define LTI / interpretable dynamics so we can do system analysis").
  - Åström & Murray; Skogestad.
  - Honest that only K_r was computed and Kp, Ki were hand-tuned.
  - Yang 2018 (control design), Yang 2021 (prediction).
- **P4, state belongs to the natural system.**
  - Fig 2G: response variability and stimulus-free activity move together.
  - **New:** relative to the stimulus-free window, response variability barely changes across quartiles (Fig S state_quartile), so the state effect rides on ongoing activity. This is your point, now with the paper's own evidence.
  - Arieli; Shimaoka. Mateo as the "not excluded" caveat.
  - Additive (offset that feedback subtracts) vs gain (model error, Goris). rSLDS as the future model class.

## 3. Feedback partly cancels activity shared with the opposite hemisphere (~450)
**Theme 3.** Cancellation is kept, scoped to what was measured.
- **P1, cancellation.**
  - Opening line: "The controller cancels part of the input the controlled site receives from the rest of cortex, as far as the opposite hemisphere reveals it, and holds the site near the target."
  - OL 1.25 vs CL 0.72 (paired medians, Table stat_fig4g).
  - Most of the difference is the standing offset (from calibration, not contralateral drive): 35% → 7%. Fluctuation only 0.66 → 0.54.
  - Why: the PI internal model of constants; loop gain glossed.
  - Interhemispheric restoration (Li 2016).
  - Caveat: linear projection, not causal (Bauer 2018).
- **P2, downstream.**
  - The loop constrains the per-trial perturbation (variance −46%, 3I).
  - Open-loop problems: Wolff, Fig 2G, Otchy.
  - Voltage clamp → optoclamp.
  - **Promoted:** the laser command should track the opposed drive (untested); if it does, the command is a readout of the cancelled input.
  - Downstream targets: dorsal cortex, striatum (Peters 2021), behaviour (Zatka-Haas 2021).
  - No space clamp.

## 4. Reachability and predictability bound what feedback can do (~590)
**Theme 4.**
- **P1, reachability.**
  - One-sided actuator: the Remark's feasibility condition. Brammer is scoped correctly: one-signed input with a real mode.
  - Evidence, hedged as "consistent with":
    - ceiling hit in 7/13 sessions (needs a Methods line, see Q2);
    - 2 offset-excluded sessions;
    - half of the MPC sine-replay error in rising half-cycles.
  - Rival causes named: integral clamp, slow integration.
- **P2, Fig 4D slopes in control terms.**
  - P = predictability, R = regularizability.
  - **Fixed:** CL/OL error ratio = broadband analogue of the sensitivity function; attenuation = its slope against state (table only).
  - Motion: rejected (−9%/SD).
  - 1–4 Hz: reduced but not held (+8%/SD).
  - Initial deviation: linear behaviour.
- **P3, why slow power escapes.**
  - 37–61 ms effective delay → a 2.6–4 Hz cap for *any* controller (derivation restored).
  - Bode integral, stated correctly.
  - **Fixed:** the plant's own lag (60° at 1 Hz) puts the actual crossover lower, probably 1–2 Hz (not measured).
  - Saturation and self-shaping stay open. Motion and slow power are anticorrelated (McGinley 2015).

## 5. Prediction removes error that feedback leaves (~510)
**Theme 5.** Retitled with a finding.
- **P1, bridge (moved from §4).**
  - Minimum-variance bound (Åström 1970), stated as a floor for linear plants with dead time.
  - State dependence makes it a benchmark.
  - Removing the predictable part needs a disturbance model.
- **P2, preview.**
  - Lag cancelled but RMSE barely moved because offset dominates; report error components separately.
  - A fixed shift is not optimal preview (Tomizuka).
- **P3, MPC replay.**
  - 1.46 → 0.88 over 1–3 s (107/108), variance −37%, oracle 0.27.
  - Three additions: Mayne (constraints), Rawlings (reference in cost).
  - Sine: 3.00 → 2.67 over 4 s; perfect prediction gives 0.77.
  - Replay bounds, not measures.
- **P4, live MPC keeps integral action.**
  - Pannocchia & Rawlings (integrating disturbance plus feasibility).
  - Offset is large in both figures.
  - Positioning: Chang 2020 and Steffen 2024 (simulation), Bolus 2021 (live, single neuron).
  - Ends on the payoff: use brain state via lifted linear predictors (Korda & Mezić).

## 6. Limitations (~190)
- Hemodynamics: Valley 2020; the impulse analysis is corrected.
- Spread: Fig S spatial_spread A,B; Li 2019.
- Sample list now includes the 15-session / 4-mouse comparison.
- Drift. Scope.

---

## Methods remark
Logemann & Curtain 2000, Thm 4.1, with the parts named: (a),(c),(d),(f) and Rem 4.2(b).
- **φ** absorbs ū, the ±q integral clamp, the [0, u_max] clipping and the command→drive map. u is the integrator state (Kp = 0, u = Ki ē).
- **(i)–(iv):**
  - quantization is ignored explicitly;
  - (iv) includes the clamp-limited command range and any standing offset y₀;
  - e = y − y_ref, matching Eq. error.
- Gain bound from step or frequency data (Logemann 1999); discrete time (Fliegner 2001).
- Desoer & Lin (PI) needs an increasing bijection with slope bounded away from zero, which saturation violates.
- **Follow-up paragraph:**
  - (i) from the stable fits (impulse mice ≠ controller sessions).
  - (ii) from the open-loop constant-command trials (Fig 3B), not from the fits, since the slow mode is unresolved.
  - Transient dose–response → monotone steady-state map via the Hammerstein structure.
  - Four departures: P term, 3 s boxcar, 35 Hz discrete time, 3/4 s trials.
  - Stability = no sustained oscillation.

## What the verification changed (summary)
- **Facts:**
  - The standing offset is from calibration, not contralateral drive.
  - Offset is the largest term only in Fig 5.
  - Attenuation definition.
  - Fig 2B (not 2E) for gain.
  - Hand-tuned gains acknowledged.
  - Mixed statistics separated.
  - "Reduced but not held" and "as much as", matching Results.
  - Motion = top quartile only.
- **Control theory:**
  - Morari condition (G(0) ≠ 0).
  - Brammer scoped.
  - Theorems not blended.
  - Delay cap ≠ crossover of the loop that ran.
  - Bode wording.
  - Minimum-variance bound is a floor, not just a benchmark.
  - Desoer 1969 is stability only.
- **Citations:**
  - Sanzeni: absent, not weak, PV-only.
  - Galgali: "can", not "only".
  - ZAPBench: expected floor, not reached.
  - Vahidi: "can".
  - Wolff: re-scoped to unusual states.
  - Hodgkin: current, not conductance.
  - Jazayeri, Das & Fiete, Harris 1989 and Garone dropped for length.
  - Li 2019 cited twice, not three times.

## Open questions for you
1. **Sine trials and the integral window.** The integral window is M = 105 samples (3 s), but sine trials last 4 s. If M stayed at 105, the boxcar stops acting as an integrator in the last second, which could leave part of the Fig 5 offset. Was M changed for the sine sessions?
2. **"Seven of 13 sessions at the ceiling".** Its only source is the old Discussion, which this replaces. Add a Methods line after L316, or drop the number?
3. **Matching fixes elsewhere.** Methods L901–902 ("the empirical counterpart of the sensitivity function") and Results L230 ("while the integral term removes that offset") need the same corrections as the Discussion. Should I apply them too?
4. **refs.bib DOIs.** newman2015optogenetic and bolus2021state lack DOI fields. Should I add them?

## Optional cuts to reach ~2,500 (~400 words)
- §1 P2: the Desoer 1969 frozen-plant sentence (~35). The "asymptotic" caveat already covers the nominal point.
- §2 P1: the Galgali sentence (~15).
- §2 P2: the Vahidi sentence (~20).
- §3 P2: the "Open-loop manipulations…" sentence (~25).
- §4 P1: the Brammer sentence (~30).
- §4 P3: the McGinley sentence (~20) and the Bode sentence (~35).
- §5 P2: the whole preview paragraph down to one sentence (~50).
- §5 P4: the positioning sentence (~40).
- Limitations: the sample list → "small samples (Materials and Methods)" (~45).
