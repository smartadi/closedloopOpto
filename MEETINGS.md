# Meeting Log — Brain Paper (Nick/Aditya)

Transcripts: `C:\Users\aditya\OneDrive\Notes\Adick meetings\`  
Add a new entry here after each meeting. Parse with: give Claude the transcript path and say "parse this meeting."

---

## Open Action Items — as of 2026-07-06

> Reconciled from the 2026-07-06 meeting's own carry-forward list (the authoritative current snapshot). Older figure/analysis items now folded into the residual-framework pivot or confirmed done are recorded in the meeting entries below, not repeated here.

### State-Dependence / Residual Framework (critical path to bioRxiv)
- [ ] `2026-07-06.1` Produce **signed** (non-absolute-value) residual-deviation plots to test whether high/low laser response is directionally predictable *(2026-07-06)*
- [ ] `2026-07-06.2` Add **pre-stimulus-window residual as a control**: verify it is flat across delta-power / variance bins (rules out globally bad prediction as the confound) *(2026-07-06)*
- [ ] `2026-07-06.3` **Finalize the contralateral predictor mask** (currently a greedy worst-case-pixel, uniform-weight mask), then rerun quartile-binned (Q1–Q4) residual-deviation plots on the updated model before claiming significance *(2026-07-06)*
- [ ] `2026-07-06.4` Run **significance test on the slope** of residual deviation vs. state variables (delta power, pre-stim variance) using the finalized mask *(2026-07-06)*
- [ ] `2026-07-02.5` Reconcile the **SFN abstract p-value** claim on state-dependence with the corrected residual analysis *(2026-07-02)*
- [ ] `2026-06-29.9` Identify laser grid locations with **minimal contralateral spread**; restrict residual analysis to those locations to reduce bleed-through confound *(2026-06-29)*
- [ ] `2026-06-22.9` Re-run residual (local-only) analysis with the corrected predictor; produce clearly labeled trace + scatter plots; **fix mislabeled axes** (Y previously "motion") *(2026-06-22)*
- [ ] `2026-06-29.13` Reconcile the impulse state-dependence result in the paper draft; get the paper to a state matching the SFN abstract claims **before posting to bioRxiv** *(2026-06-29)*

### Closed-Loop Analyses (deferred until residual framework is locked)
- [ ] `2026-06-03.1` For each CL trial, subtract modeled laser effect (TF fit) → inferred "no-laser" trace; compare variance distribution to actual no-laser trials (add shuffled-subtraction null) *(2026-06-03)*
- [ ] `2026-06-03.2` Re-do MSE-vs-delta-power plot: OL/CL binned by **pre-stimulus delta-band fraction**; match y-axes across panels *(2026-06-03)*
- [ ] `2026-06-03.3` Compute instability frequency from full latency distribution (worst-case ~47 ms); plot predicted control degradation vs. input frequency *(2026-06-03)*
- [ ] `2026-06-03.4` Replace variance-binned x-axis in state-dependence figure with delta-band power fraction as primary sorting criterion *(2026-06-03)*
- [ ] `2026-06-03.5` Produce heatmap of CL vs. OL trials, time on x-axis, trials sorted by delta-band fraction (Curto/Issa style) *(2026-06-03)*
- [ ] `2026-06-03.6` Spatial-spread 2D summary: response **amplitude and onset latency** as joint functions of distance from laser target *(2026-06-03)*
- [ ] Using the red model (if validated), compute post-hoc **optimal laser sequence** for representative trials; quantify gap vs. actual controller; frame as MPC motivation *(from 2026-05-11)*
- [ ] `2026-05-29.6` Sine-wave/feedforward sessions on new mouse: ≥4 s / ≥4-cycle stimuli, shorter ITIs; full-grid ping characterization before closed-loop *(2026-05-29)*

### New Mouse — Grid Characterization (excitatory + inhibitory opsin)
- [ ] `2026-06-29.5` Run additional grid sessions (same mouse, same protocol) to assess reliability of excitatory and midline responses; use **lower excitatory laser power** (below 0.5 V) *(2026-06-29)*
- [ ] `2026-06-29.6` Plot grid data as **trials × time matrix** per location to diagnose whether low-response noise is outlier-trial driven; consider median over mean *(2026-06-29)*
- [ ] `2026-06-29.7` Build **inverse GUI view**: for a clicked widefield location, show the response trace for all 52 stim positions (find bidirectional-control candidates) *(2026-06-29)*
- [ ] `2026-06-29.8` Share additional grid sessions with **Dana** once collected *(2026-06-29)*
- [ ] `2026-06-22.7` Add the excitatory-opsin **spatial-localization result** (hemisphere-contained excitation) to the widefield opto paper *(2026-06-22)*

### Motorized Treadmill
- [ ] `2026-07-06.6` Post identified motor specs (model, torque, cost, controller) to the **treadmill Slack channel** for Nick/Matt/Alice *(2026-07-06)*
- [ ] `2026-07-06.7` Check existing lab **power supplies** (variable-voltage adapters) for ≥3× peak-motor-current rating before buying a new one *(2026-07-06)*
- [ ] `2026-06-29.2` Add **rotary encoder mount** to the wheel base (reprint or clamp); confirm encoder wiring to Arduino *(2026-06-29)*
- [ ] `2026-06-29.3` When Alice returns (fall), supervise fixture redesign for motorized/clutch version *(2026-06-29)*

### People / Logistics
- [ ] `2026-06-29.11` Train **Alex** (rotation student) to run grid sessions; show full experimental workflow *(2026-06-29)*
- [ ] Run open-loop controller sessions and **save stimulus/response data** for the upcoming mouse(es) *(from 2026-05-08)*

### Nick's Items (not Aditya's)
- [ ] `2026-06-29.4` **Nick**: Confirm with Annie whether she wants to contribute to the treadmill hardware project *(2026-06-29)*
- [ ] `2026-06-29.12` **Nick**: Confirm protocol-amendment approval; notify Aditya when Alex can handle mice *(2026-06-29)*

### Presumed done (date passed — verify)
- [x] `2026-07-06.5` Present the SFN story at Data Club (scheduled 2026-07-07) with brief cortical-dynamics/control intro for new lab members *(2026-07-06; date has passed)*

---

## Meeting Entries

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
