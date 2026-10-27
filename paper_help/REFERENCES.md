# References used in the paper, and why

This guide was built on 2026-10-26 from `Closedloop_edit` `main` at cfc0de9 ("Updates from Overleaf"). It covers all **68 cited keys**, taken from the introduction, results, discussion, methods, supplementary, main and stat_tables files.

Each entry gives two things:
- **Shows:** what the paper itself shows.
- **We cite it for:** the claim it supports in our text, and where.

The **Check** column says how firmly "Shows" is verified:
- **A** — checked against the paper's abstract (Europe PMC, arXiv or Crossref) on 2026-10-21.
- **M** — listed in the verified literature map (`paper-writing/INTRO_LITREVIEW.md`, 2026-10-05).
- **T** — title or bib entry only. The summary comes from the title or general knowledge; read the paper before relying on details.

To rebuild the raw list of citing sentences, run `python paper_help/cite_contexts.py <Closedloop_edit path> <out.md>`. Its output for this version is the source of the "We cite it for" lines.

---

## 1. Brain state and response variability (motivation)

| Key | Check | Shows | We cite it for |
|---|---|---|---|
| Arieli1996 (Science) | M | Ongoing activity at stimulus time explains much of the large trial-to-trial variability of evoked cortical responses (cat visual cortex, voltage-sensitive dye) | Intro: responses depend on the current state. Disc: a fixed response riding on ongoing activity |
| Petersen2003 (PNAS) | M | In barrel cortex, sensory responses interact with the spontaneous depolarization present when the stimulus arrives | Intro: responses depend on state (sensory example) |
| Goris2014 (Nat Neurosci) | A | Much of sensory neurons' variability comes from slow, shared fluctuations in excitability (gain), not from noise within the neuron | Intro: responses depend on state |
| Mateo2011 (Curr Biol) | M | The cortex's response to optogenetic stimulation of excitatory neurons depends on brain state | Intro: responses depend on state (optogenetic example) |
| Massimini2005 (Science) | M | TMS-evoked cortical responses (effective connectivity) break down in sleep: perturbation responses depend on state | Intro: responses depend on state (magnetic example) |
| Niell2010 (Neuron) | M | Locomotion changes visual responses in mouse V1 | Intro: state follows movement and arousal. Disc: movement as a state variable |
| McGinley2015 (Neuron) | M | Arousal (pupil) sets membrane-potential state; low arousal brings slow fluctuations and variable responses | Intro: state follows arousal |
| McGinley2015waking (Neuron) | T | Perspective: fast changes in waking state (arousal, movement) shape neural and behavioral responses | Disc: movement and arousal as state; motion and slow power are anticorrelated |
| Vinck2015 (Neuron) | M | Arousal and locomotion contribute differently to cortical activity patterns and low-frequency power | Intro and Disc: state follows movement and arousal |
| musall2019single (Nat Neurosci) | M | Uninstructed movements dominate single-trial cortex-wide (wide-field) activity | Intro: state follows movement; mesoscale activity carries movement; models miss unobserved movements. Disc: same |
| stringer2019spontaneous (Science) | A | Spontaneous behaviors drive high-dimensional activity across the brain, and sensory input adds onto that ongoing signal | Intro: state follows movement; models miss these inputs. Disc: same |
| Salkoff2020 (Cereb Cortex) | M | Movement and task performance explain widespread wide-field cortical activity | Intro: state follows movement |
| Crochet2006 (Nat Neurosci) | M | Awake mouse barrel cortex shows slow, large membrane-potential fluctuations during quiet wakefulness, which whisking suppresses | Intro: slow synchronized rhythms in quiet wakefulness |
| Poulet2008 (Nature) | M | Internal brain state controls membrane-potential synchrony in barrel cortex of behaving mice | Intro: slow rhythms. Disc: synchrony as state |
| Reimer2014 (Neuron) | M | Pupil fluctuations track fast switching between synchronized and desynchronized cortical states in quiet wakefulness | Intro: slow rhythms in quiet wakefulness |
| Harris2011 (Nat Rev Neurosci) | M (review) | Review of cortical state (synchronized vs desynchronized) and attention | Disc: synchrony of ongoing activity as a state variable |
| harris2013topdown (Neuron) | T | Title: top-down control of cortical state. Author line not checked here | Disc: drive from other areas as an unobserved input |
| zagha2013motor (Neuron) | A | Motor cortex feedback changes network state in somatosensory cortex, through the direct corticocortical pathway | Intro and Disc: drive from other areas that a model of one region does not observe |
| Mohajerani2010 (J Neurosci) | M | Slow-wave activity is mirrored across the two hemispheres (bihemispheric voltage-sensitive dye, anesthetized and awake mice) | Intro: state is shared across hemispheres |
| Shimaoka2019 (eLife) | M | Bilateral ongoing activity shapes evoked responses in mouse cortex; the other hemisphere predicts trial-to-trial variability | Intro: shared across hemispheres. Disc: fixed response on ongoing activity; basis of the contralateral disturbance |
| Ye2026 (Science) | M | Rotating waves are coordinated brain-wide and topographically, including across hemispheres. Cite the Science 2026 version, not the 2023 bioRxiv | Intro: shared across hemispheres. Disc: contralaterally predicted disturbance |
| bryan2025temporal (J Neural Eng) | **T** | Title: temporal basis function models for closed-loop neural stimulation | Disc: "activity at stimulus onset shaped optogenetic responses in macaque sensorimotor cortex". **Not verified; check this claim against the paper** |

## 2. Modelling the state and forecasting

| Key | Check | Shows | We cite it for |
|---|---|---|---|
| linderman2017rslds (AISTATS) | T (exists) | Recurrent switching linear dynamical systems: dynamics that switch between linear regimes, with switching driven by the state | Intro and Disc: models that treat state as a parameter of the dynamics |
| sani2021modeling (Nat Neurosci) | A | PSID: a linear state-space method that separates and prioritizes the behaviorally relevant neural dynamics | Intro and Disc: models isolating the dynamics relevant to a behavior |
| sani2024dissociative (Nat Neurosci) | T | DPAD: the same idea with recurrent neural networks (nonlinear) | Disc: linear models often predict about as well as nonlinear ones |
| weiss2024realtime (J Neural Eng) | A | Real-time estimation of discrete cortical state from LFP (GMM and hidden semi-Markov model), evaluated in emulation | Intro: state can be estimated in real time. Disc: a decoder that labels state without modelling the stimulus response; lags of 120–240 ms |
| lu2025benchmarking (arXiv 2510.18037) | A | Benchmark of forecasting models on spontaneous mouse wide-field activity; the best gives informative forecasts up to about 1.5 s | Intro and Disc: forecasts stay informative only about 1.5 s ahead |
| lueckmann2025zapbench (ICLR) | T | ZAPBench: a benchmark for predicting whole-brain zebrafish activity; even the best models leave a large error floor | Disc: even a perfect forecaster leaves some error |
| Nozari2024 (Nat Biomed Eng) | A | Linear autoregressive models describe macroscale resting-state brain dynamics (fMRI, iEEG) as well as or better than nonlinear ones | Intro and Disc: a linear description is plausible |
| Yang2021 (Nat Biomed Eng) | A | Dynamic input–output models predict multiregional macaque responses to electrical microstimulation | Intro: models built for model-based control. Disc: linear models predict stimulation responses; simulation-tested designs |
| lutkepohl2005new (Springer) | T (textbook) | Standard text on vector autoregressive (VAR/VARX) models | Results: the VARX used by the MPC |

## 3. Mesoscale activity and wide-field optogenetics

| Key | Check | Shows | We cite it for |
|---|---|---|---|
| mohajerani2013spontaneous (Nat Neurosci) | M | Spontaneous cortical activity alternates between motifs set by regional axonal projections | Intro: mesoscale patterns follow axonal projections |
| allen2017global (Neuron) | M | Goal-directed behavior is represented globally across neocortex, in distinct cell types | Intro: mesoscale activity carries task variables |
| makino2017transformation (Neuron) | M | Cortex-wide activity properties change during motor learning | Intro: mesoscale activity carries learning-related change |
| Lim2012 (Front Neural Circuits) | M | Large-scale cortical mapping with ChR2 stimulation and imaging; asymmetric, reciprocal connections between areas (open loop) | Intro: opto combined with wide-field imaging to map areas |
| ZatkaHaas2021 (eLife) | M | Wide-field imaging and optogenetic inactivation give the causal impact of cortical areas on a visual decision (open loop) | Intro: wide-field plus silencing. Disc: testing a site's influence on behavior |
| Matveev2024 (bioRxiv) | M | Our platform: simultaneous mesoscopic imaging and optogenetic manipulation of mouse cortex (systemic AAV ChrimsonR in inhibitory neurons, galvo laser). It leaves closed loop as future work | Intro: wide-field plus opto. Results: chamber. Disc: the preparation reaches all dorsal cortex. **Methods: surgery, virus, mesoscope, illumination, hemodynamic correction, laser and calibration, video sync** |
| Ambrosone2025 (Brain Stimul) | A | Wide-field imaging with stGtACR2 silencing, open loop: suppression deepens with laser power and spreads across the hemisphere | Intro: wide-field silencing; suppression deepens with power; our monotonic result agrees with it |
| Peters2021 (Nature) | M | Striatal activity topographically reflects cortical (wide-field) activity | Disc: a tracked site's influence on striatum could be tested |
| li2019spatiotemporal (eLife) | T | Spatial and temporal limits of optogenetic inactivation in cortex: inhibition spreads beyond the light spot | Disc: inhibition spreads toward the adjacent readout |

## 4. Closed-loop neural control (prior work)

| Key | Check | Shows | We cite it for |
|---|---|---|---|
| Siegle2014 (eLife) | A | Closed-loop CA1 inhibition at chosen theta phases improves encoding or retrieval, depending on phase and task segment | Intro: closed loop revealed what rhythms contribute to behavior |
| kanta2019closed (Nat Commun) | A | Closed-loop detection and optogenetic boosting or suppression of amygdala gamma shows that gamma matters for memory consolidation | Intro: the same. Disc: light locked to oscillations |
| nicholson2018analogue (eLife) | A | Analogue closed-loop optogenetic feedback in hippocampal slices changes gamma frequency and amplitude separately | Intro: oscillations reshaped in slices. Disc: light locked to oscillations |
| Zaaimi2022 (Nat Biomed Eng, **2023**) | A | Continuous closed-loop optogenetic control of LFP dynamics in mouse slices and anesthetized macaques | Intro: oscillations reshaped in anesthetized monkeys. Disc: same. The key says 2022 but the year field is 2023 |
| newman2015optogenetic (eLife) | A | The "optoclamp": continuous bidirectional optical feedback holds firing at set levels for seconds to days, in culture and in vivo | Intro: firing held at a chosen level. Disc: earlier controllers; the optoclamp analogy (the command reports the opposed drive) |
| bolus2018design (J Neural Eng) | A | PI control of rat thalamic firing, designed from a model of the response to light fitted during the experiment. It tracked targets, rejected disturbances and changed trial-to-trial variability | Intro: model-based controllers of thalamic firing. Disc: details (poor model yet good control, lower Fano factor, one-sided limit) |
| bolus2021state (J Neural Eng) | A | LDS model plus LQR state feedback with an adaptive Kalman filter controls single-neuron firing in awake mouse thalamus | Intro: model-based control. Disc: state as a disturbance; adaptive estimator for mismatch |
| Zhang2018 (Nat Methods) | A | Closed-loop all-optical (two-photon) interrogation: stimulation tailored online to imaged activity in awake mice | Intro: all-optical loops. Disc: closest readout, holding single-neuron calcium near set levels (MAE about 5% ΔF/F; that number is from the full text) |
| Zhang2025 (Cell Rep Methods) | A | Real-time all-optical interface; threshold-triggered two-photon photostimulation during behavior | Intro: all-optical loops (recent) |
| clancy2014volitional (Nat Neurosci) | A | Mice learn to control an auditory cursor with two-photon calcium signals from L2/3 neurons | Intro: activity fed back as sound (cortical neurons) |
| Neely2018 (Neuron) | A | Rodents learn to produce arbitrary V1 activity patterns for an auditory cursor; learning needs the dorsomedial striatum | Intro: same |
| Gupta2026 (eLife) | A | CLoPy: real-time wide-field (mesoscale) neurofeedback with graded audio about 63 ms; mice learn to modulate cortical ROIs for reward | Intro: mesoscale loop closed through learning, not a stimulus |
| deAlteriis2026 (FENS 2026 poster) | **T** | Title only: a framework for closed-loop all-optical control of cortex-wide dynamics. A search summary describes wide-field imaging, patterned inhibition, a linear model, optimal control and preliminary single-area control | Intro: the only mesoscale closed-loop work we know of ("to our knowledge"). **Get the abstract text or drop it** |
| Yang2018 (J Neural Eng) | A | System identification for control plus a real-time closed-loop **simulation** testbed for electrical brain stimulation | Intro: models for model-based control, tested in closed loop in simulation. Disc: same caveat for our replay |
| little2013adaptive (Ann Neurol) | T | Adaptive DBS in Parkinson's disease: stimulation switches on when beta LFP crosses a threshold | Disc: threshold-triggered rather than continuous control |
| grosenick2015closed (Neuron) | T (review) | Review of closed-loop, activity-guided optogenetic control | Disc: state change as a change in the plant; gain scheduling with state |

## 5. Control theory and methods

| Key | Check | Shows | We cite it for |
|---|---|---|---|
| astrom1995pid (ISA) | T (textbook) | PID controllers: theory, design and tuning | Results: a linear feedforward controller calibrated from impulse-response data |
| astrom2008feedback (Princeton UP) | T (textbook) | Feedback Systems, an introductory control textbook | Disc: a low-order linear model makes stability, gain limits and bandwidth computable |
| gevers2005identification (Eur J Control) | T | Identification for control: a model for control needs to capture only the input–output behavior relevant to the loop | Disc: the design model need only capture how the laser moves the readout |
| conant1970every (Int J Syst Sci) | T | The good-regulator theorem: every good regulator of a system must be a model of that system | Disc: ours modelled only the average |
| francis1976internal (Automatica) | T (Crossref) | The internal model principle: to reject a signal class robustly, the controller must contain a model of it (an integrator for constants) | Disc: the integrator as an internal model of a constant offset |
| logemann2000absolute (ESAIM COCV) | T (Crossref) | Absolute-stability results giving low-gain integral control for stable linear (infinite-dimensional) plants with input nonlinearities; needs only the sign of the steady-state gain | Intro: integral control needs only the gain's sign, which monotonicity supplies. Disc: same, despite saturation and delay. **Confirm the exact conditions in the paper** |
| morari1985robust (IEEE TAC) | T | Robust stability with integral control (integral controllability) | Disc: variability limits the gains, not whether a correctly signed gain stabilizes the loop |
| skogestad2005multivariable (Wiley) | T (textbook) | Multivariable Feedback Control; delay limits bandwidth (ω_c·τ ≲ 1) | Disc: the delay caps the feedback bandwidth at about 2.6–4 Hz |
| rugh2000research (Automatica) | T | Survey of gain scheduling | Disc: a context-dependent controller that schedules its gains with state |
| rawlings2017model (Nob Hill) | T (textbook) | Model Predictive Control: Theory, Computation, and Design | Results: definition of MPC |
| mayne2000constrained (Automatica) | T | Stability and optimality of constrained MPC | Disc: MPC treats the one-sided laser as a constraint |
| pannocchia2003disturbance (AIChE J) | T | Disturbance models for offset-free MPC | Disc: a live MPC should keep integral action |

---

## Things to check

1. **deAlteriis2026:** title-level only. Get the abstract, or drop it from the Intro.
2. **bryan2025temporal:** the Disc claim that onset activity shaped optogenetic responses in macaque has never been checked against the paper.
3. **logemann2000absolute:** confirm the conditions (saturation, delay, sign of steady-state gain).
4. **harris2013topdown:** confirm the author list and that it supports "drive from other areas".
5. **Zaaimi2022:** the key name says 2022 but the paper is 2023. Cosmetic only; the year field is correct.
6. **Reviews and textbooks still cited** (Harris2011, McGinley2015waking, grosenick2015closed, plus five textbooks). This is fine for control-theory facts. The Intro uses none of them.
7. **Not checked by this scan:** uncited entries in `refs.bib` (they don't print).
