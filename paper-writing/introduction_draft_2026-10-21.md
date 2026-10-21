# Introduction: full draft, 2026-10-21 (merged with `main`)

> **Installed 2026-10-21** as `Closedloop_edit/introduction.tex` (commit 3f75ae2, pushed to main). The installed text is the LaTeX block at the bottom. It differs from the numbered version by a tone pass against the Discussion: P1.5 "brain state"; P2.6 only state that adds to the response is a disturbance; P4.2 "anesthetized"; P5.5 "about as well as"; P5.6 hedged and cut to Logemann; P6.4 "on that basis, built ... tuned to the experiment"; P6.7 "four mice". Final length: 1229 words, 46 keys.

**This round:** I took what was good from the Introduction on `main` (commit 43fabaf) and merged it into the new draft. Text brought over from `main`, or newly written to carry it, is in **bold** in the numbered version.
- **Your point on monotonicity:** we see deeper suppression with more laser power, as Ambrosone 2025 does. So P6 line 5 now reports our result "as in open-loop silencing", and P5 line 4 says what is new: a linear, time-invariant description, and why monotonicity matters for a controller.
- **New paragraph:** there are now six paragraphs. P2 is new: main's argument for feedback over modelling the state.
- **Length:** word limit ignored, as asked. Word counts exclude citations: P1 138 · P2 167 · P3 175 · P4 183 · P5 234 · P6 334, which totals **1231** (main is 765). The JNeurosci limit I recall is 750, unverified, so this will need a trim later.
- **Citations:** 47 keys. 43 are from main and 4 are new; 3 of the new ones are not in `refs.bib` yet (BibTeX below).

---

## Text (sentences numbered for editing)

### P1: why set activity, and what open loop cannot do *(approved; state literature added from main)*

1. Establishing what a neural population contributes to behavior, or which pathways carry its influence, requires modulating its activity.
2. The efficacy of such a modulation depends on how precisely it can shape the activity.
3. Yet modulation, whether optical, electrical or magnetic, is often delivered open loop, with the input chosen in advance regardless of the activity it acts upon.
4. The response to any input depends on the circuit's current state, that is, its ongoing pattern of activity, as has been shown for sensory, optogenetic and magnetic stimulation `\citep{Arieli1996, Petersen2003,` **`Goris2014,`** `Mateo2011, Massimini2005}`.
5. **In awake mice, this state follows movement and arousal `\citep{Niell2010, McGinley2015, Vinck2015, musall2019single, stringer2019spontaneous, Salkoff2020}`, alternates with slow, synchronized rhythms during quiet wakefulness `\citep{Crochet2006, Poulet2008, Reimer2014}`, and is shared across the two hemispheres `\citep{Mohajerani2010, Shimaoka2019, Ye2026}`.**
6. The same input therefore creates variable responses from trial to trial.
7. Not only the known states but also inputs we cannot measure, including subcortical ones, drive the activity.

### P2: modelling the state versus feedback *(new; from main's paragraphs 3–4)*

1. **One way to handle this variability is to model it.**
2. **Switching linear dynamical systems treat the state as a parameter that changes the dynamics `\citep{linderman2017rslds}`, other models isolate the dynamics relevant to a behavior `\citep{sani2021modeling}`, and cortical state can be estimated in real time `\citep{weiss2024realtime}`.**
3. **Such models, however, do not observe the movements and the input from other areas that also drive a region `\citep{musall2019single, stringer2019spontaneous, zagha2013motor}`, and even the best current models forecast spontaneous wide-field activity informatively only about 1.5 s ahead `\citep{lu2025benchmarking}`.**
4. **A stimulus planned in advance would need a model that identifies and forecasts each trial's state precisely.**
5. Closed-loop control, which adjusts the input continuously from a real-time measurement of the activity it is meant to control, can in principle correct for such differences, provided the activity can be read out fast enough and the input acts on that same activity. *(your P1 line 6, moved here)*
6. **Because it acts on each trial's measured deviation, feedback needs no model of what caused that deviation: state-dependent variability becomes a disturbance to reject rather than a confound to average.**

### P3: the mesoscale, and why it suits a test of closed loop *(approved; line 5 split to take main's "open loop" sentence)*

1. Mesoscale activity is the combined activity of local neural populations across millimeters of cortex, between the scale of single neurons and that of the whole brain.
2. Its spontaneous spatial patterns follow the axonal projections between regions `\citep{mohajerani2013spontaneous}`, and it is closely tied to behavior, carrying task variables, learning-related change and movement `\citep{allen2017global, makino2017transformation, musall2019single}`.
3. We read it out as fluorescence across a field about 10 mm wide.
4. Wide-field imaging samples the field at 35 Hz, and the latency, the delay from a camera exposure to the light it triggers, has a median of 24 ms, about a fifth of the 0.11 s timescale on which light moves the activity.
5. Spatially targeted optogenetic stimulation has been combined with wide-field imaging to map and silence cortical areas `\citep{Lim2012, ZatkaHaas2021, Matveev2024, Ambrosone2025}`, **but open loop: the stimulus is fixed in advance, and the variability it meets is averaged away afterwards.**
6. In our setup, the light suppresses the cortex around the stimulated spot, including the region we read out.
7. Mesoscale activity is therefore a convenient scale at which to test closed-loop control, though not the only one.

### P4: what closed-loop control has achieved *(draft; three additions from main)*

1. Closed-loop stimulation has revealed what particular rhythms contribute to behavior: optogenetic stimulation triggered at chosen phases of hippocampal theta, or by bursts of amygdala gamma, showed their roles in encoding, retrieving and consolidating memories `\citep{Siegle2014, kanta2019closed}`.
2. **Closed-loop optogenetic feedback has also reshaped ongoing oscillations, in brain slices and in anaesthetized monkeys `\citep{nicholson2018analogue, Zaaimi2022}`.**
3. Continuous control, which adjusts the input at every update instead of delivering a preset one, has held neuronal firing at a chosen level in culture and in vivo `\citep{newman2015optogenetic}`.
4. Controllers designed from a model of the plant, the system the controller acts on, fitted to its responses to light, made thalamic firing track time-varying targets and reject unmeasured disturbances, and changed its trial-to-trial variability `\citep{bolus2018design, bolus2021state}`.
5. **For electrical stimulation, input–output models of multiregional responses have been built for model-based control `\citep{Yang2018, Yang2021}` and tested in closed loop in simulation `\citep{Yang2018}`.**
6. All-optical loops have tailored two-photon stimulation to activity imaged in real time `\citep{Zhang2018, Zhang2025}`.
7. Activity has also been fed back to animals as sound, **from cortical neurons `\citep{clancy2014volitional, Neely2018}` to mesoscale regions** `\citep{Gupta2026}`, but there the loop closes through the animal learning to change its activity for reward, not through a stimulus to the cortex.

### P5: the gap *(draft; why linear would be plausible and enough, from main)*

1. Closed-loop stimulation of mesoscale activity thus remains largely unexplored: to our knowledge, a framework for closed-loop all-optical control of cortex-wide activity has so far appeared only in a conference abstract `\citep{deAlteriis2026}`.
2. Three questions remain open.
3. First, is the response of a mesoscale signal to optogenetic input close enough to linear and time-invariant to design a controller from it?
4. Open-loop work shows that suppression of wide-field activity deepens with laser power `\citep{Ambrosone2025}`, but a controller also needs the time course of the response.
5. **A linear description is plausible, because linear models describe macroscale resting-state brain activity better than nonlinear ones `\citep{Nozari2024}`.**
6. **It would also be enough: integral action, an internal model of a constant signal `\citep{francis1976internal}`, removes a constant offset at low gain for a stable linear plant despite saturation and delay, given only the sign of the plant's steady-state gain `\citep{logemann2000absolute}`, which a monotonic response supplies.**
7. Second, does feedback make the signal less variable from trial to trial than open-loop input?
8. Third, how does the error that feedback leaves depend on the circuit's state, which makes open-loop responses vary?
9. **A controller designed on the average response is not designed for single-trial deviations, so relating the error it leaves to the measured state can show which fluctuations lie beyond its reach.**
10. The answers decide whether closed-loop control can set mesoscale activity precisely enough to test what it contributes to behavior, and whether a controller should take the state into account.

### P6: what we did and found *(draft; main's specifics, open-loop result, movement result, procedure and ending)*

1. Here we close the loop on mesoscale activity in **awake, head-fixed** mice.
2. A camera images calcium-dependent fluorescence across the dorsal cortex at 35 Hz, and on every frame a controller compares the activity of a 0.17 mm patch of somatosensory cortex with a reference level below baseline and sets the power of a laser aimed next to the patch.
3. The light excites inhibitory neurons that express an opsin, so it can only lower the activity.
4. We first characterized how the activity responds to pulses of light of different amplitudes, then designed from it **a proportional–integral controller with feedforward compensation**, which we compared with open-loop stimulation within each session.
5. Trial-averaged suppression deepened with laser power, **as in open-loop silencing `\citep{Ambrosone2025}`**, and was approximately linear and time-invariant within a session, **so a low-order linear model predicted it**, in four sessions from three mice.
6. **Single responses, however, varied from trial to trial about as much as ongoing activity did without stimulation, and both changed together with the state.**
7. Closed loop held the activity at the reference more accurately than open loop in all 15 sessions from 4 mice, and reduced its trial-to-trial variability.
8. Power at 1–4 Hz, which marks large, slow fluctuations, raised the error of both by similar amounts, so the fraction of the error that feedback left grew with it, **whereas feedback removed more of the error that accompanied movement.**
9. **These results outline a procedure: characterize the input–output relationship, check that the average response is monotonic and approximately linear, and tune a proportional–integral controller to the experiment.**
10. It assumes only a readout that is fast relative to the response and an input whose effect is close to linear, so it is not tied to wide-field imaging or optogenetics, although we test it here with one readout and one input.
11. The error that such a controller leaves then carries information about the state: **it shows which components of ongoing variability lie beyond a fixed linear design, a starting point for** controllers that take the state into account.

---

## How the aim answers the gap

| P5 question | P6 answer | Source in the manuscript |
|---|---|---|
| 1. Linear and time-invariant enough to design a controller? | Line 5: deeper with power, approximately linear, time-invariant within a session, low-order model (4 sessions, 3 mice) | Results, Fig. 2 (slopes −0.88 to −3.11 %ΔF/F per mW, R² 0.73–0.97); abstract |
| 2. Less variable than open loop? | Line 6 sets it up: open-loop trials vary as much as ongoing activity (ratio 0.92–1.06). Line 7 answers: lower error in all 15 sessions, lower trial-to-trial variability | Results, Fig. 2G; Fig. 3 (RMSE −23%; steady-state variance −46%) |
| 3. How does the leftover error depend on state? | Line 8: 1–4 Hz power raises both errors alike, so the leftover fraction grows; feedback removes more of the movement-related error | Results, Fig. 4 (error ratio +8% per SD with 1–4 Hz power, p = 0.0014; −9% per SD with motion, p = 0.0048) |
| P5 line 10: should a controller use the state? | Lines 9–11: the procedure, and the leftover error as a guide to state-aware controllers | Abstract, last sentence |

**Still left out of P6, as agreed earlier:** preview, the MPC replay, and the contralateral-disturbance result with its 11-session number. Main had all three. Say if you want any of them back. The movement result in line 8 rests on the 11 sessions with face video, but the line gives no session count.

---

## What was ported from main, and how each claim was checked

| Claim (where) | Key | How it was checked (2026-10-21) |
|---|---|---|
| State follows movement and arousal (P1.5) | Niell2010, McGinley2015, Vinck2015, musall2019single, stringer2019spontaneous, Salkoff2020 | Verified literature map, section A; Stringer abstract (Europe PMC) |
| Slow, synchronized rhythms in quiet wakefulness (P1.5) | Crochet2006, Poulet2008, Reimer2014 | Literature map A (listed there for the 2–4 Hz claim) |
| Shared across hemispheres (P1.5) | Mohajerani2010, Shimaoka2019, Ye2026 | Literature map; the bib's Ye2026 is the Science 2026 version (eadx1369) |
| Excitability (gain) fluctuations shape responses (P1.4) | Goris2014 | Europe PMC abstract |
| Switching LDS (P2.2) | linderman2017rslds | Bib entry (Linderman, Johnson, Miller, Adams, Blei, Paninski, AISTATS 2017). Not in Crossref, as PMLR is not indexed; the paper is real |
| Behaviorally relevant dynamics (P2.2) | sani2021modeling | Europe PMC abstract (PSID) |
| Real-time cortical state estimation (P2.2) | weiss2024realtime | Europe PMC abstract. Its real-time system was evaluated "in emulation", hence "can be estimated" rather than "is decoded" |
| Motor cortex drives S1 state (P2.3) | zagha2013motor | Europe PMC abstract |
| Forecasts informative about 1.5 s ahead (P2.3) | lu2025benchmarking | arXiv 2510.18037 (Lu, …, Deole, …, Steinmetz): "the best model producing informative forecasts up to 1.5 seconds" |
| Oscillations reshaped by closed-loop opto (P4.2) | nicholson2018analogue, Zaaimi2022 | Europe PMC abstracts: hippocampal slices (gamma); slices plus anaesthetized macaques. The bib key says 2022 but the paper is **2023**; the year field is already 2023 |
| Input–output models for electrical stimulation (P4.5) | Yang2018, Yang2021 | Europe PMC abstracts. Yang2018 built a closed-loop **simulation** testbed; Yang2021 predicts responses only. I dropped main's "so far … only in simulation", which claims to cover everything published |
| Neurofeedback from cortical neurons (P4.7) | clancy2014volitional, Neely2018 | Europe PMC abstracts: two-photon L2/3 neurons; V1 activity in rats and mice. Both used an auditory cursor |
| Linear models fit macroscale activity best (P5.5) | Nozari2024 | Europe PMC abstract |
| Internal model principle; low-gain integral control (P5.6) | francis1976internal, logemann2000absolute | Crossref: Francis & Wonham, Automatica 12:457 (1976); Logemann & Curtain, ESAIM COCV 5:395 (2000). **Title-level only.** The exact conditions (saturation, delay, sign of the steady-state gain) come from main's wording; check them against the paper |

**Still left out from main, and why:**
- Harris2011, Wolff2018, grosenick2015closed, RittChing2015, vyas2020computation and astrom1995pid: reviews or a textbook. We agreed on originals only.
- Churchland2012: its abstract does not state the linear-dynamics claim main used it for.
- Peters2021: a methods pipeline.
- bryan2025temporal: never verified. It is still cited in the Discussion, so it needs checking there anyway.

---

## Novelty search, re-run 2026-10-21 (unchanged)

- **No published paper continuously controls a mesoscale signal with optogenetics.** Gupta & Murphy 2026 closes the loop through reward (P4.7).
- **The KCL FENS 2026 abstract** (de Alteriis … Sadeh & Khan) is cited in P5.1 by title only. Its page is offline; details from a search summary describe wide-field imaging plus patterned inhibition, a linear model, optimal control and "preliminary" single-area control. **Get the abstract text or drop the citation.**
- **Ambrosone 2025** (open loop, suppression deepens with power) is used in P3.5, P5.4 and P6.5. Our result agrees with it.
- **Zhang 2025** (two-photon, threshold-triggered) is used in P4.6. The Yoshida/Ikegaya FENS poster is not used.

Sources: [FENS 2026, de Alteriis et al.](https://world-wide.org/fens-26/framework-closed-loop-all-optical-control-2980e290) · [FENS 2026, Yoshida et al.](https://world-wide.org/fens-26/closed-loop-optogenetic-control-cortical-2e89b59e) · [Ambrosone et al. (bioRxiv)](https://www.biorxiv.org/content/10.1101/2024.12.12.628207v1) · [Gupta & Murphy 2026](https://elifesciences.org/articles/105070) · [Zhang et al. 2025](https://pmc.ncbi.nlm.nih.gov/articles/PMC12570328/) · [Lu et al. 2025 (arXiv)](http://arxiv.org/abs/2510.18037v2)

---

## BibTeX to add to `refs.bib`

```bibtex
@article{Ambrosone2025,
  title={All-optical mapping reveals distributed suppression of cortical sensory responses after optogenetic silencing},
  author={Ambrosone, Manuel and Montagni, Elena and Resta, Francesco and Ulivi, Tommaso and Curti, Lorenzo and Polverini, Federica and Mazzamuto, Giacomo and Mannaioni, Guido and Masi, Alessio and Pavone, Francesco Saverio and Allegra Mascaro, Anna Letizia},
  journal={Brain Stimulation},
  volume={18},
  number={5},
  pages={1514--1522},
  year={2025},
  doi={10.1016/j.brs.2025.07.003}
}

@article{Zhang2025,
  title={A real-time all-optical interface for dynamic perturbation of neural activity during behavior},
  author={Zhang, Zihui and Dzialecka, Patrycja and Russell, Lloyd E. and Ratto, Riccardo and Buetfering, Christina and Gauld, Oliver M. and Selviah, David R. and H{\"a}usser, Michael},
  journal={Cell Reports Methods},
  volume={5},
  number={10},
  pages={101180},
  year={2025},
  doi={10.1016/j.crmeth.2025.101180}
}

@misc{deAlteriis2026,
  title={A framework for closed-loop all-optical control of cortex-wide neural dynamics},
  author={de Alteriis, Giuseppe and Harvey, Matthew and Davey, Martha and Machado Ferreira, Filipe and Expert, Paul and Turkheimer, Federico and Sadeh, Sadra and Khan, Adil},
  howpublished={Poster, FENS Forum 2026},
  year={2026},
  url={https://world-wide.org/fens-26/framework-closed-loop-all-optical-control-2980e290}
}
```

---

## Open items

1. **refs.bib:** add the three entries above. Nothing in `Closedloop_edit` has been edited.
2. **KCL abstract:** get its text, or drop P5.1's citation.
3. **Logemann claim (P5.6):** confirm its exact conditions in the paper.
4. **Length:** 1231 words. Trim later. The biggest candidates:
   - P2.2–P2.4 (the modelling survey);
   - P4.2, P4.5 and P4.6;
   - P5.5–P5.6;
   - P6.9–P6.10, which overlap.
5. **Two possible overlaps:**
   - P1.7 ("inputs we cannot measure") and P2.3 ("input from other areas") make a similar point. P2.3 is the more specific of the two.
   - P6.4 and P6.9 both describe the two-step procedure.

---

## Paste-ready LaTeX (one sentence per line)

```latex
Establishing what a neural population contributes to behavior, or which pathways carry its influence, requires modulating its activity.
The efficacy of such a modulation depends on how precisely it can shape the activity.
Yet modulation, whether optical, electrical or magnetic, is often delivered open loop, with the input chosen in advance regardless of the activity it acts upon.
The response to any input depends on the circuit's current state, that is, its ongoing pattern of activity, as has been shown for sensory, optogenetic and magnetic stimulation~\citep{Arieli1996, Petersen2003, Goris2014, Mateo2011, Massimini2005}.
In awake mice, brain state follows movement and arousal~\citep{Niell2010, McGinley2015, Vinck2015, musall2019single, stringer2019spontaneous, Salkoff2020}, alternates with slow, synchronized rhythms during quiet wakefulness~\citep{Crochet2006, Poulet2008, Reimer2014}, and is shared across the two hemispheres~\citep{Mohajerani2010, Shimaoka2019, Ye2026}.
The same input therefore creates variable responses from trial to trial.
Not only the known states but also inputs we cannot measure, including subcortical ones, drive the activity.

One way to handle this variability is to model it.
Switching linear dynamical systems treat the state as a parameter that changes the dynamics~\citep{linderman2017rslds}, other models isolate the dynamics relevant to a behavior~\citep{sani2021modeling}, and cortical state can be estimated in real time~\citep{weiss2024realtime}.
Such models, however, do not observe the movements and the input from other areas that also drive a region~\citep{musall2019single, stringer2019spontaneous, zagha2013motor}, and even the best current models forecast spontaneous wide-field activity informatively only about 1.5\,s ahead~\citep{lu2025benchmarking}.
A stimulus planned in advance would need a model that identifies and forecasts each trial's state precisely.
Closed-loop control, which adjusts the input continuously from a real-time measurement of the activity it is meant to control, can in principle correct for such differences, provided the activity can be read out fast enough and the input acts on that same activity.
Because it acts on each trial's measured deviation, feedback needs no model of what caused that deviation, so state-dependent activity that adds to the response becomes a disturbance to reject rather than a confound to average.

Mesoscale activity is the combined activity of local neural populations across millimeters of cortex, between the scale of single neurons and that of the whole brain.
Its spontaneous spatial patterns follow the axonal projections between regions~\citep{mohajerani2013spontaneous}, and it is closely tied to behavior, carrying task variables, learning-related change and movement~\citep{allen2017global, makino2017transformation, musall2019single}.
We read it out as fluorescence across a field about 10\,mm wide.
Wide-field imaging samples the field at 35\,Hz, and the latency, the delay from a camera exposure to the light it triggers, has a median of 24\,ms, about a fifth of the 0.11\,s timescale on which light moves the activity.
Spatially targeted optogenetic stimulation has been combined with wide-field imaging to map and silence cortical areas~\citep{Lim2012, ZatkaHaas2021, Matveev2024, Ambrosone2025}, but open loop: the stimulus is fixed in advance, and the variability it meets is averaged away afterwards.
In our setup, the light suppresses the cortex around the stimulated spot, including the region we read out.
Mesoscale activity is therefore a convenient scale at which to test closed-loop control, though not the only one.

Closed-loop stimulation has revealed what particular rhythms contribute to behavior: optogenetic stimulation triggered at chosen phases of hippocampal theta, or by bursts of amygdala gamma, showed their roles in encoding, retrieving and consolidating memories~\citep{Siegle2014, kanta2019closed}.
Closed-loop optogenetic feedback has also reshaped ongoing oscillations, in brain slices and in anesthetized monkeys~\citep{nicholson2018analogue, Zaaimi2022}.
Continuous control, which adjusts the input at every update instead of delivering a preset one, has held neuronal firing at a chosen level in culture and in vivo~\citep{newman2015optogenetic}.
Controllers designed from a model of the plant, the system the controller acts on, fitted to its responses to light, made thalamic firing track time-varying targets and reject unmeasured disturbances, and changed its trial-to-trial variability~\citep{bolus2018design, bolus2021state}.
For electrical stimulation, input--output models of multiregional responses have been built for model-based control~\citep{Yang2018, Yang2021} and tested in closed loop in simulation~\citep{Yang2018}.
All-optical loops have tailored two-photon stimulation to activity imaged in real time~\citep{Zhang2018, Zhang2025}.
Activity has also been fed back to animals as sound, from cortical neurons~\citep{clancy2014volitional, Neely2018} to mesoscale regions~\citep{Gupta2026}, but there the loop closes through the animal learning to change its activity for reward, not through a stimulus to the cortex.

Closed-loop stimulation of mesoscale activity thus remains largely unexplored: to our knowledge, a framework for closed-loop all-optical control of cortex-wide activity has so far appeared only in a conference abstract~\citep{deAlteriis2026}.
Three questions remain open.
First, is the response of a mesoscale signal to optogenetic input close enough to linear and time-invariant to design a controller from it?
Open-loop work shows that suppression of wide-field activity deepens with laser power~\citep{Ambrosone2025}, but a controller also needs the time course of the response.
A linear description is plausible, because linear models often predict brain activity about as well as nonlinear ones~\citep{Nozari2024}.
Control theory suggests it would also be enough, because low-gain integral control of a stable linear plant needs only the sign of its steady-state gain~\citep{logemann2000absolute}, which a monotonic response supplies.
Second, does feedback make the signal less variable from trial to trial than open-loop input?
Third, how does the error that feedback leaves depend on the circuit's state, which makes open-loop responses vary?
A controller designed on the average response is not designed for single-trial deviations, so relating the error it leaves to the measured state can show which fluctuations lie beyond its reach.
The answers decide whether closed-loop control can set mesoscale activity precisely enough to test what it contributes to behavior, and whether a controller should take the state into account.

Here we close the loop on mesoscale activity in awake, head-fixed mice.
A camera images calcium-dependent fluorescence across the dorsal cortex at 35\,Hz, and on every frame a controller compares the activity of a 0.17\,mm patch of somatosensory cortex with a reference level below baseline and sets the power of a laser aimed next to the patch.
The light excites inhibitory neurons that express an opsin, so it can only lower the activity.
We first characterized how the activity responds to pulses of light of different amplitudes and, on that basis, built a proportional--integral controller with feedforward compensation, tuned to the experiment, which we compared with open-loop stimulation within each session.
Trial-averaged suppression deepened with laser power, as in open-loop silencing~\citep{Ambrosone2025}, and was approximately linear and time-invariant within a session, so a low-order linear model predicted it, in four sessions from three mice.
Single responses, however, varied from trial to trial about as much as ongoing activity did without stimulation, and both changed together with the state.
Closed loop held the activity at the reference more accurately than open loop in all 15 sessions from four mice, and reduced its trial-to-trial variability.
Power at 1--4\,Hz, which marks large, slow fluctuations, raised the error of both by similar amounts, so the fraction of the error that feedback left grew with it, whereas feedback removed more of the error that accompanied movement.
These results outline a procedure: characterize the input--output relationship, check that the average response is monotonic and approximately linear, and tune a proportional--integral controller to the experiment.
It assumes only a readout that is fast relative to the response and an input whose effect is close to linear, so it is not tied to wide-field imaging or optogenetics, although we test it here with one readout and one input.
The error that such a controller leaves then carries information about the state: it shows which components of ongoing variability lie beyond a fixed linear design, a starting point for controllers that take the state into account.
```
