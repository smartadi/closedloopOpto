# Absolute vs relative δ power as state variables — literature check

**Date:** 2026-10-15 · **Scope:** literature only. No changes to manuscript, `Closedloop_edit/`, `refs.bib` or analysis code.
**Target text:** `results.tex` L80, the two δ sentences after Fig 2G. Fig 4 text L147–157 is read as context.
**Our setup, from `methods_edit.tex`:** GCaMP6s/8s (CaMKII), DLX2.0-Chrimson inhibition. Online imaging skips the violet frames, so the controller signal is **not hemodynamically corrected**. Signal is single-site kernel ΔF/F at 35 Hz.

Verification: three search agents checked every reference against PubMed/PMC, the journal page, or a DOI record. Five I re-checked myself: Allen 2017, Wright 2017, Salkoff 2020, Petersen 2003 and Bolus 2021. ⚠ marks a partly unverified item.

---

## Bottom line

1. **"Absolute power = disturbance amplitude" holds up.** There is direct precedent, including in mouse wide-field (Shimaoka 2019). Fig 2 also contains our own additivity check: the stimulus-free control. Present the framing as operational, not mechanistic.
2. **"Relative power = independent of overall power" does not hold up as written.** A band ratio cancels a pure gain change, such as expression level, illumination or multiplicative haemoglobin absorption. It does **not** cancel a change in spectral *shape*. Aperiodic (1/f) slope changes alone move band ratios (Donoghue, Dominguez & Voytek 2020, *eNeuro*). With slow indicators (6s/8s), 2–4 Hz is the attenuated tail of the spectrum, so rel-δ largely measures spectral slope. Change "independent of" to "normalised for", and report a control.
3. **"Relative δ matters in closed loop" is weaker than the sentence implies.** Our own Fig 4 text says the closed-loop rel-δ effect (p = 0.044) does not survive correction for 8 tests, "and we do not build on it". FINDINGS also records that the rel-δ predictability effect *flipped sign* on Zhiwen's independent data. The Results sentence should promise less.
4. **High motion → lower variability fits the arousal/desynchronization literature, with one caveat.** Movement-locked activity also *adds* variance (Musall 2019; Stringer 2019). Our own Fig 4 shows that second side: open-loop error *rose* with motion (+0.16 per SD). The two windows differ: Fig 2 uses −1 to 0 s, before stimulus; Fig 4 uses −2 to +3 s, which includes movement during stimulation. That difference explains both results and is worth one sentence.

---

## Q1. What do absolute and relative low-frequency power reflect?

**Low-frequency power indexes a synchronized, low-arousal state.**
- In awake mouse V1, 1–4 Hz LFP power falls with arousal: about 2.5-fold on air puff, and correlated with pupil at R = −0.93 during quiescence. It stays suppressed throughout locomotion and recovers over 40–50 s after locomotion stops [Vinck 2015]. ⚠ These numbers come from the bioRxiv full text; the journal abstract is verified.
- Pupil dilation marks desynchronized states, with larger responses and lower correlations. Constriction marks low-frequency oscillation [Reimer 2014]. ⚠ The exact band in Reimer was not verified.
- Quiet wakefulness shows slow, large, correlated Vm fluctuations. Whisking switches these to small, fast, decorrelated ones [Crochet & Petersen 2006; Poulet & Petersen 2008].
- At the lowest pupil-indexed arousal, Vm shows slow rhythmic (up/down-like) oscillations. The relationship to performance is an inverted U, not monotonic [McGinley, David & McCormick 2015].
- Reviews: synchronized and desynchronized states lie on a continuum defined by low-frequency power and correlations [Harris & Thiele 2011; McGinley et al. 2015 review].

**Wide-field GCaMP specifically:**
- Jacobs et al. 2020 (Harris/Carandini/Steinmetz) is our closest methodological precedent. They used pre-stimulus **3–6 Hz wide-field GCaMP power** as the synchrony index. They could not go lower because of indicator kinetics. Desynchronization was global. Population Fano factor rose with low-frequency power. Early evoked responses (100–300 ms) did **not** covary with it.
- Quiet-awake GCaMP6s shows a structured spontaneous mode at about 2.6 Hz in the 2–5 Hz band [Vanni et al. 2017]. That mode falls inside our band.
- Delta-band (0.4–4 Hz) GCaMP correlations are strongly state-dependent (wake / NREM / anaesthesia), while infraslow correlations change only modestly [Brier et al. 2019; Wright et al. 2017].
- The Ye et al. 2026 rotating waves were detected in 2–8 Hz wide-field signals, which also overlaps our band. ⚠ Their behavioural-state analysis is unread (science.org returned 403). Check it before citing for state.

**Absolute vs relative.** No mouse paper contrasts the two directly. The distinction rests on our own reasoning plus the spectral-parameterization literature.
- **Absolute** δ combines how rhythmic the signal is with how large its fluctuations are. Large shared slow events raise it.
- **Relative** δ removes a multiplicative offset but still tracks the aperiodic slope [Donoghue et al. 2020 *Nat Neurosci*; Donoghue, Dominguez & Voytek 2020 *eNeuro*]. Brain state is known to change that slope [Gao, Peterson & Voytek 2017].

## Q2. Are they reliable state markers in wide-field GCaMP?

**Hemodynamics.**
- Haemoglobin absorption distorts GCaMP *multiplicatively* [Ma et al. 2016 *Phil Trans B*; Valley et al. 2020]. Resting haemodynamics are a slow, low-pass copy of neural activity [Ma et al. 2016 *PNAS*]. Most of the artefact therefore lies below about 1 Hz: GCaMP–HbT coherence peaks at 0.21 Hz [Wright 2017].
- Two physiological sources remain in our band, and both survive correction at low amplitude [Wright 2017]:
  - mouse **respiration at about 3–5 Hz**, inside the 2–4 Hz numerator;
  - **heart rate at about 8–10 Hz**, inside the 0.4–10 Hz denominator.
- Ma 2016 recommends low-pass filtering at about 3–5 Hz to remove these.
- Our controller signal is uncorrected. A ratio cancels the multiplicative *gain* part of the artefact, but not added spectral peaks.

**GCaMP kinetics.**
- Single-AP half-decay is about 100 ms for GCaMP6f and about 500 ms for GCaMP6s [Chen et al. 2013]. ⚠ These values come from patent text that reproduces Chen's data; check against Chen Fig. 1 before quoting.
- Our own estimate, not from any paper: a first-order filter with these decay times has its corner well below 2 Hz. For 6s and 8s, 2–4 Hz therefore sits on the roll-off.
- Consequences:
  - 2–4 Hz power is real but attenuated, which is why Jacobs 2020 used 3–6 Hz.
  - Rel-δ = P(2–4)/P(0.4–10) is dominated by the 0.4–2 Hz part of the denominator. It largely measures the spectral slope.
  - Mixing 6s and 8s animals changes the filter between animals. Rel-δ then differs between animals for indicator reasons alone, so it must be z-scored within session. We already do this.

**Single site vs whole cortex.**
- Slow and δ-band wide-field activity is largely global and travelling:
  - hemisphere-wide motifs [Mohajerani 2013, VSD];
  - globally propagating waves [Matsui, Murakami & Ohki 2016];
  - during NREM/anaesthesia the slow oscillation lies in the first 3 PCs [Brier 2019];
  - desynchronization is global [Jacobs 2020].
- So a single site mostly indexes global state. That suits a state variable, but the 2–5 Hz mode does have spatial structure [Vanni 2017].
- I found **no published quantitative validation of wide-field GCaMP δ power against simultaneous LFP/EEG δ.** Wright 2017 shows only a qualitative 1.5 Hz match under anaesthesia.

**Short windows.**
- Resolution is about 1/T: 1 Hz for a 1 s window, 0.2 Hz for a 5 s window.
- At 1 s, the 2–4 Hz band covers 2–3 independent bins. A single-taper estimate then has a coefficient of variation near 1 [Thomson 1982; Prerau et al. 2017; Bokil et al. 2010 Chronux]. That calculation is standard theory, not a quote from these papers.
- Zero-padding (`f4_bandpow` 'continuous') interpolates the spectrum but adds no resolution.
- **Specific flag for Fig 2:** a 1 s window cannot resolve 0.4–1 Hz. In `imp_state_trialvar.m` `local_delta` (n = 35, Hann, mean removed, 1 Hz FFT grid), the denominator `f >= 0.4 & f <= 10` therefore picks up only the 1, 2, …, 10 Hz bins. The numerator is just the 2, 3 and 4 Hz bins. So in Fig 2 the "0.4–10 Hz" denominator is **effectively 1–10 Hz**, and Methods should say so. This is not a bug, but a reviewer who does the arithmetic will ask. Fig 4 uses a 5 s window with the continuous estimator and is fine.
- Multitaper estimation would reduce the variance. Our quartile binning partly absorbs the estimation noise anyway.

**The 1/f problem.** Band ratios conflate periodic and aperiodic activity. The θ/β ratio, for example, mostly tracks the aperiodic exponent [Donoghue, Dominguez & Voytek 2020 *eNeuro*]. Fixed bands mix centre frequency, power, bandwidth, offset and exponent [Donoghue et al. 2020 *Nat Neurosci*]. Broadband activity increases move the whole spectrum [Miller et al. 2009; He 2014]. I found **no paper that applies spectral parameterization (FOOOF/specparam) to wide-field GCaMP spectra.**

What can be defended:
- "Relative power normalises for multiplicative differences in signal amplitude (expression, illumination, haemoglobin absorption) and is only partly correlated with total power."
- **Not** "independent of overall power".

## Q3. Is "absolute power = disturbance amplitude" fair?

**Yes, as an operational definition.**

*Additive precedent*
- Arieli et al. 1996: single cat V1 responses were predicted as a fixed evoked response linearly summed with the preceding ongoing activity.
- The same idea appears in human fMRI [Fox et al. 2006; Fox & Raichle 2007]. Becker et al. 2011 used ongoing *band power* to predict evoked variability, under linear superposition.
- In mouse wide-field (voltage and GCaMP), bilateral ongoing activity "interacted additively" with evoked responses and explained much of the trial-to-trial variance [Shimaoka et al. 2019]. This is the closest precedent.
- Synchronized states carry larger shared global fluctuations, which dominate variability [Schölvinck et al. 2015].

*Control-theory precedent*
- Bolus et al. 2021 model unmeasured, non-zero-mean disturbance plus process noise. They name changing brain state as a disturbance to reject.
- Bolus et al. 2018 and Newman et al. 2015 show PI feedback rejecting such disturbances and lowering trial-to-trial variability.

*Counter-evidence: non-additivity, strongest in synchronized states*
- Up-state or depolarized activity shrinks or reshapes responses [Petersen et al. 2003 PNAS; Sachdev, Ebner & Wilson 2004; Hasenstaub, Sachdev & McCormick 2007; Azouz & Gray 1999].
- It also changes spike gain multiplicatively [Haider et al. 2007].
- Optogenetically evoked PSPs depend on pre-stimulus Vm [Mateo et al. 2011].
- A "background + fixed response" model failed outright [Kisley & Gerstein 1999].
- Dynamics are nonlinear in synchronized states and only approximately linear in desynchronized ones [Curto et al. 2009]. This is exactly the high-δ regime.
- Stimulus onset quenches variability, which pure superposition forbids [Churchland et al. 2010]. Spontaneous and evoked activity interact negatively [He 2013].
- Shared variability has both additive and multiplicative parts [Lin et al. 2015; Goris et al. 2014; Arandia-Romero et al. 2016].

**Our own data already answers part of this.**
- The stimulus-free control tracks the evoked response's state dependence: quartile ratio 2.71 vs 2.31 for absolute δ.
- The ratio of within-session RMS errors is 0.92–1.06.
- That is exactly the additivity test the literature would ask for, and the text already labels it an interpretation.

A cheap strengthening, if wanted: show that the *mean* evoked dip is flat across absolute-δ quartiles while dispersion rises. Gain changes would scale the mean; additive disturbance would not.

## Q4. Face motion

- **It fits.** Whisking, facial motion and arousal desynchronize cortex and lower low-frequency power [Poulet & Petersen 2008; Crochet & Petersen 2006; Vinck 2015; Reimer 2014].
- Desynchronization raises response reliability and lowers shared variability. This holds both correlationally [Pachitariu et al. 2015; Schölvinck 2015] and causally, via basal-forebrain/cholinergic activation [Goard & Dan 2009; Pinto et al. 2013].
- **The caveat a reviewer will raise:** uninstructed movements produce large, brain-wide activity that is itself the dominant source of single-trial variability [Musall et al. 2019; Stringer et al. 2019; Salkoff et al. 2020].
- The way to reconcile the two is the window:
  - **Fig 2** measures motion only *before* the stimulus (−1 to 0 s), so it indexes the arousal state the impulse arrives in. Our lower variability matches desynchronization.
  - **Fig 4** measures motion from −2 to +3 s, which includes movement during stimulation. There, open-loop error *rose* with motion, matching Musall/Stringer: movement-locked activity is a disturbance. Closed loop rejected it.
  - The two are not in conflict. One sentence saying so pre-empts the objection.
- Further caveats:
  - Arousal effects are inverted-U [McGinley, David & McCormick 2015] and depend on area [Shimaoka, Harris & Carandini 2018]. In barrel cortex and area LM arousal only hyperpolarizes and damps phasic responses.
  - Jacobs 2020 found low-frequency-linked variability was "not information limiting". Frame the result as a correlate.

---

## Strongest reviewer objections and how the literature answers them

| # | Objection | Answer available? |
|---|---|---|
| 1 | "Relative δ is not independent of total power. Band ratios track the 1/f slope." | **No defence in the literature; concede and control.** Cite Donoghue 2020 *eNeuro*. Report ρ(rel-δ, log total power) directly. Show that the effect survives partialling out log total power, or that it holds on specparam-periodic 2–4 Hz power (5 s windows). |
| 2 | "Absolute δ and RMSE are circular: both are magnitudes of the same signal." Worse in Fig 4, where the δ window (−2 to +3 s) overlaps the RMSE window. | Partly answered. The disturbance framing makes the link *expected*, not artefactual [Arieli 1996; Shimaoka 2019; Bolus 2021]. But state outright that δ is measured partly during control, and point to Fig 2's pre-only window as the non-overlapping version. Your 2026-07-23 note to Nick already flagged this. |
| 3 | "Ongoing activity is not additive. Synchronized states change gain." | Partly answered. Precedent for additivity: Arieli, Shimaoka, Fox. Our stimulus-free control is our own evidence. Acknowledge Curto 2009 / Petersen 2003 / Lin 2015 and limit the claim to "consistent with additive". The text already does this. |
| 4 | "Uncorrected haemodynamics and respiration contaminate 2–4 Hz." | Mostly answered. Haemodynamics lie mainly below 1 Hz and act multiplicatively [Ma 2016; Wright 2017; Valley 2020]. Respiration at about 3–5 Hz is a real residual [Wright 2017]. Best control: repeat on sessions with offline blue/violet correction. The `paper/_hemo_compare/` folder suggests this is under way. |
| 5 | "GCaMP6s/8s cannot follow 2–4 Hz." | Answered. Jacobs 2020 and Vanni 2017 measure state in 2–6 Hz wide-field GCaMP. Attenuation is a gain, so it cancels within session. Mixing 6s and 8s animals is handled by within-session z-scoring. Say so. |
| 6 | "A 1 s window is too short." | Partly answered. Resolution 1 Hz, 2–3 bins in band. The 0.4 Hz denominator edge is unresolvable at 1 s. The Fig 2 code is effectively 1–10 Hz (1 Hz grid bins 1…10); state that in Methods. Fig 2 rel-δ was null anyway, so this costs nothing. |
| 7 | "Single site ≠ cortical state." | Answered. Low-frequency wide-field activity is largely global [Mohajerani 2013; Matsui 2016; Brier 2019; Jacobs 2020]. Optional check: correlate site δ with first-PC or whole-cortex δ. |
| 8 | "High motion → lower variability contradicts Musall/Stringer." | Answered by the window split above (Fig 2 pre-only vs Fig 4 peri-stimulus). |
| 9 | "Rel-δ matters in closed loop" | **Not supported by our own stats.** It does not survive correction (L155), and the predictability effect did not replicate (FINDINGS, Zhiwen). Don't promise it. |

---

## Proposed rewrite (results.tex L80; not applied)

> The two $\delta$ measures were correlated but not redundant (Spearman $\rho = 0.47$ over the impulse trials). Absolute power scales with the amplitude of ongoing slow fluctuations, which are larger in synchronized, low-arousal states~\citep{Vinck2015,Scholvinck2015,Jacobs2020}. Relative power divides out overall signal amplitude and so reflects how activity is distributed across frequencies, although, like any band ratio, it also follows changes in the broadband ($1/f$) slope~\citep{Donoghue2020eNeuro}. We carry both into the closed-loop analysis: absolute power as a measure of disturbance amplitude~\citep{Arieli1996,Shimaoka2019}, and relative power as a candidate measure of spectral state normalised for overall amplitude. There, absolute power is taken over 1--4\,Hz and both are measured from $-2$ to $+3$\,s around onset (Materials and Methods).

**Methods (Power spectral analysis), add:**
> Low-frequency wide-field power indexes cortical synchronization, which falls with arousal, whisking and locomotion~\citep{Crochet2006,Poulet2008,Vinck2015,Jacobs2020}. Relative power cancels multiplicative differences in signal amplitude, including indicator expression, illumination and haemoglobin absorption~\citep{Ma2016,Valley2020}, but not changes in spectral shape~\citep{Donoghue2020eNeuro}. We therefore z-scored both measures within session. This also removes differences in indicator kinetics between GCaMP6s and GCaMP8s animals~\citep{Chen2013}.

**Discussion (state paragraph), add:**
> Treating ongoing activity as a disturbance added to a fixed evoked response follows~\citet{Arieli1996} and~\citet{Shimaoka2019}, and matches how state-space neural controllers model unmeasured brain-state input~\citep{bolus2021state}. Ongoing activity can also change response gain, most clearly in synchronized states~\citep{Petersen2003,Curto2009,Lin2015}. Our stimulus-free control does not require strict additivity. It shows only that the disturbance, not the stimulus effect, carries the state dependence. Motion lowered impulse-response variability when measured before the stimulus, as expected if arousal desynchronizes cortex~\citep{Poulet2008,Vinck2015}, but raised open-loop error when it overlapped stimulation, consistent with movement-related cortical activity acting as an additional disturbance~\citep{musall2019single,Stringer2019}.

**Keys.** Already in `refs.bib`: Arieli1996, Shimaoka2019, Scholvinck2015, Vinck2015, Crochet2006, Poulet2008, Petersen2003, bolus2021state, musall2019single, Stringer2019, Harris2011, Reimer2014, McGinley2015 (= the David & McCormick Neuron 87:179 paper), Goris2014, Mateo2011, Salkoff2020, Ye2026, mohajerani2013spontaneous.
**New, proposed (not added):** Jacobs2020, Donoghue2020eNeuro, Donoghue2020, Ma2016, Valley2020, Chen2013, Curto2009, Lin2015. Optional: Wright2017, Vanni2017, Brier2019, Matsui2016, Fox2006, Becker2011, Haider2007, Kisley1999, Churchland2010, Goard2009, Pachitariu2015, Gao2017, Steinmetz2017, Thomson1982, Prerau2017.

---

## References

Verification uses ✓ for every item checked online. "abstract" means only the abstract or bibliographic record was seen. ⚠ means one detail is unverified, and the note says which.

**State, arousal, movement**
1. Vinck M, Batista-Brito R, Knoblich U, Cardin JA (2015). Arousal and locomotion make distinct contributions to cortical activity patterns and visual encoding. *Neuron* 86(3):740–754. doi:10.1016/j.neuron.2015.03.028 ✓ (numbers from bioRxiv full text)
2. Reimer J, Froudarakis E, Cadwell CR, Yatsenko D, Denfield GH, Tolias AS (2014). Pupil fluctuations track fast switching of cortical states during quiet wakefulness. *Neuron* 84(2):355–362. doi:10.1016/j.neuron.2014.09.033 ✓ abstract (⚠ exact band)
3. McGinley MJ, David SV, McCormick DA (2015). Cortical membrane potential signature of optimal states for sensory signal detection. *Neuron* 87(1):179–192. doi:10.1016/j.neuron.2015.05.038 ✓
4. McGinley MJ, Vinck M, Reimer J, Batista-Brito R, Zagha E, Cadwell CR, Tolias AS, Cardin JA, McCormick DA (2015). Waking state: rapid variations modulate neural and behavioral responses. *Neuron* 87(6):1143–1161. doi:10.1016/j.neuron.2015.09.012 ✓
5. Harris KD, Thiele A (2011). Cortical state and attention. *Nat Rev Neurosci* 12(9):509–523. doi:10.1038/nrn3084 ✓
6. Poulet JFA, Petersen CCH (2008). Internal brain state regulates membrane potential synchrony in barrel cortex of behaving mice. *Nature* 454:881–885. doi:10.1038/nature07150 ✓
7. Crochet S, Petersen CCH (2006). Correlating whisker behavior with membrane potential in barrel cortex of awake mice. *Nat Neurosci* 9(5):608–610. doi:10.1038/nn1690 ✓
8. Jacobs EAK, Steinmetz NA, Peters AJ, Carandini M, Harris KD (2020). Cortical state fluctuations during sensory decision making. *Curr Biol* 30(24):4944–4955.e7. doi:10.1016/j.cub.2020.09.067 ✓ full text
9. Schölvinck ML, Saleem AB, Benucci A, Harris KD, Carandini M (2015). Cortical state determines global variability and correlations in visual cortex. *J Neurosci* 35(1):170–178. doi:10.1523/JNEUROSCI.4994-13.2015 ✓
10. Pachitariu M, Lyamzin DR, Sahani M, Lesica NA (2015). State-dependent population coding in primary auditory cortex. *J Neurosci* 35(5):2058–2073. doi:10.1523/JNEUROSCI.3318-14.2015 ✓ abstract
11. Goard M, Dan Y (2009). Basal forebrain activation enhances cortical coding of natural scenes. *Nat Neurosci* 12:1444–1449. doi:10.1038/nn.2402 ✓
12. Pinto L, Goard MJ, Estandian D, Xu M, Kwan AC, Lee S-H, Harrison TC, Feng G, Dan Y (2013). Fast modulation of visual perception by basal forebrain cholinergic neurons. *Nat Neurosci* 16:1857–1863. doi:10.1038/nn.3552 ✓
13. Musall S, Kaufman MT, Juavinett AL, Gluf S, Churchland AK (2019). Single-trial neural dynamics are dominated by richly varied movements. *Nat Neurosci* 22(10):1677–1686. doi:10.1038/s41593-019-0502-4 ✓
14. Stringer C, Pachitariu M, Steinmetz N, Reddy CB, Carandini M, Harris KD (2019). Spontaneous behaviors drive multidimensional, brainwide activity. *Science* 364(6437):eaav7893. doi:10.1126/science.aav7893 ✓
15. Salkoff DB, Zagha E, McCarthy E, McCormick DA (2020). Movement and performance explain widespread cortical activity in a visual detection task. *Cereb Cortex* 30(1):421–437. doi:10.1093/cercor/bhz206 ✓
16. Shimaoka D, Harris KD, Carandini M (2018). Effects of arousal on mouse sensory cortex depend on modality. *Cell Rep* 22(12):3160–3167. doi:10.1016/j.celrep.2018.02.092 ✓
17. Niell CM, Stryker MP (2010). Modulation of visual responses by behavioral state in mouse visual cortex. *Neuron* 65(4):472–479. doi:10.1016/j.neuron.2010.01.033 ✓
18. Steinmetz NA, Zatka-Haas P, Carandini M, Harris KD (2019). Distributed coding of choice, action and engagement across the mouse brain. *Nature* 576:266–273. doi:10.1038/s41586-019-1787-x ✓
19. Ye Z, Ladd AE, MacKenzie N, Kolich L, Li AJ, Birman D, Bull MS, Daigle TL, Tasic B, Zeng H, Steinmetz NA (2026). Brain-wide topographic coordination of rotating waves. *Science* 392(6804):eadx1369. doi:10.1126/science.adx1369 ⚠ citation verified (already in refs.bib); full text unread, state content unverified

**Wide-field GCaMP: signal, haemodynamics, kinetics**
20. Ma Y, Shaik MA, Kim SH, Kozberg MG, Thibodeaux DN, Zhao HT, Yu H, Hillman EMC (2016). Wide-field optical mapping of neural activity and brain haemodynamics: considerations and novel approaches. *Phil Trans R Soc B* 371(1705):20150360. doi:10.1098/rstb.2015.0360 ✓
21. Ma Y, Shaik MA, Kozberg MG, Kim SH, Portes JP, Timerman D, Hillman EMC (2016). Resting-state hemodynamics are spatiotemporally coupled to synchronized and symmetric neural activity in excitatory neurons. *PNAS* 113(52):E8463–E8471. doi:10.1073/pnas.1525369113 ✓
22. Wright PW, Brier LM, Bauer AQ, Baxter GA, Kraft AW, Reisman MD, Bice AR, Snyder AZ, Lee J-M, Culver JP (2017). Functional connectivity structure of cortical calcium dynamics in anesthetized and awake mice. *PLoS ONE* 12(10):e0185759. doi:10.1371/journal.pone.0185759 ✓
23. Valley MT, Moore MG, Zhuang J, Mesa N, Castelli D, Sullivan D, Reimers M, Waters J (2020). Separation of hemodynamic signals from GCaMP fluorescence measured with wide-field imaging. *J Neurophysiol* 123(1):356–366. doi:10.1152/jn.00304.2019 ✓ abstract (⚠ frequency-specific claims unread)
24. Allen WE, Kauvar IV, Chen MZ, Richman EB, Yang SJ, Chan K, Gradinaru V, Deverman BE, Luo L, Deisseroth K (2017). Global representations of goal-directed behavior in distinct cell types of mouse neocortex. *Neuron* 94(4):891–907.e6. doi:10.1016/j.neuron.2017.04.017 ✓ (already in refs.bib as allen2017global)
25. Couto J, Musall S, Sun XR, Khanal A, Gluf S, Saxena S, Kinsella I, Abe T, Cunningham JP, Paninski L, Churchland AK (2021). Chronic, cortex-wide imaging of specific cell populations during behavior. *Nat Protoc* 16(7):3241–3263. doi:10.1038/s41596-021-00527-z ✓
26. Chen T-W, Wardill TJ, Sun Y, Pulver SR, Renninger SL, Baohan A, Schreiter ER, Kerr RA, Orger MB, Jayaraman V, Looger LL, Svoboda K, Kim DS (2013). Ultrasensitive fluorescent proteins for imaging neuronal activity. *Nature* 499(7458):295–300. doi:10.1038/nature12354 ✓ (⚠ half-decay values via patent text; check Fig. 1)
27. Vanni MP, Chan AW, Balbi M, Silasi G, Murphy TH (2017). Mesoscale mapping of mouse cortex reveals frequency-dependent cycling between distinct macroscale functional modules. *J Neurosci* 37(31):7513–7533. doi:10.1523/JNEUROSCI.3560-16.2017 ✓
28. Brier LM, Landsness EC, Snyder AZ, Wright PW, Baxter GA, Bauer AQ, Lee J-M, Culver JP (2019). Separability of calcium slow waves and functional connectivity during wake, sleep, and anesthesia. *Neurophotonics* 6(3):035002. doi:10.1117/1.NPh.6.3.035002 ✓
29. Matsui T, Murakami T, Ohki K (2016). Transient neuronal coactivations embedded in globally propagating waves underlie resting-state functional connectivity. *PNAS* 113(23):6556–6561. doi:10.1073/pnas.1521299113 ✓
30. Mohajerani MH, Chan AW, Mohsenvand M, LeDue J, Liu R, McVea DA, Boyd JD, Wang YT, Reimers M, Murphy TH (2013). Spontaneous cortical activity alternates between motifs defined by regional axonal projections. *Nat Neurosci* 16(10):1426–1435. doi:10.1038/nn.3499 ✓
31. Steinmetz NA, Buetfering C, Lecoq J, Lee CR, Peters AJ, Jacobs EAK, Coen P, Ollerenshaw DR, Valley MT, de Vries SEJ, Garrett M, Zhuang J, Groblewski PA, Manavi S, Miles J, White C, Lee E, Griffin F, Larkin JD, Roll K, Cross S, Nguyen TV, Larsen R, Pendergraft J, Daigle T, Tasic B, Thompson CL, Waters J, Olsen S, Margolis DJ, Zeng H, Hausser M, Carandini M, Harris KD (2017). Aberrant cortical activity in multiple GCaMP6-expressing transgenic mouse lines. *eNeuro* 4(5):ENEURO.0207-17.2017. doi:10.1523/ENEURO.0207-17.2017 ✓

**Spectral methods and the aperiodic problem**
32. Donoghue T, Haller M, Peterson EJ, Varma P, Sebastian P, Gao R, Noto T, Lara AH, Wallis JD, Knight RT, Shestyuk A, Voytek B (2020). Parameterizing neural power spectra into periodic and aperiodic components. *Nat Neurosci* 23:1655–1665. doi:10.1038/s41593-020-00744-x ✓
33. Donoghue T, Dominguez J, Voytek B (2020). Electrophysiological frequency band ratio measures conflate periodic and aperiodic neural activity. *eNeuro* 7(6):ENEURO.0192-20.2020. doi:10.1523/ENEURO.0192-20.2020 ✓ (PMC7768281)
34. Donoghue T, Schaworonkow N, Voytek B (2022). Methodological considerations for studying neural oscillations. *Eur J Neurosci* 55(11–12):3502–3527. doi:10.1111/ejn.15361 ✓
35. Gao R, Peterson EJ, Voytek B (2017). Inferring synaptic excitation/inhibition balance from field potentials. *NeuroImage* 158:70–78. doi:10.1016/j.neuroimage.2017.06.078 ✓ (bibliographic record)
36. He BJ (2014). Scale-free brain activity: past, present, and future. *Trends Cogn Sci* 18(9):480–487. doi:10.1016/j.tics.2014.04.003 ✓
37. Miller KJ, Sorensen LB, Ojemann JG, den Nijs M (2009). Power-law scaling in the brain surface electric potential. *PLoS Comput Biol* 5(12):e1000609. doi:10.1371/journal.pcbi.1000609 ✓
38. Thomson DJ (1982). Spectrum estimation and harmonic analysis. *Proc IEEE* 70(9):1055–1096. doi:10.1109/PROC.1982.12433 ✓ vol/pages (⚠ DOI string not resolved)
39. Prerau MJ, Brown RE, Bianchi MT, Ellenbogen JM, Purdon PL (2017). Sleep neurophysiological dynamics through the lens of multitaper spectral analysis. *Physiology* 32(1):60–92. doi:10.1152/physiol.00062.2015 ✓
40. Bokil H, Andrews P, Kulkarni JE, Mehta S, Mitra PP (2010). Chronux: a platform for analyzing neural signals. *J Neurosci Methods* 192(1):146–151. doi:10.1016/j.jneumeth.2010.06.020 ✓

**Ongoing activity and evoked variability**
41. Arieli A, Sterkin A, Grinvald A, Aertsen A (1996). Dynamics of ongoing activity: explanation of the large variability in evoked cortical responses. *Science* 273(5283):1868–1871. doi:10.1126/science.273.5283.1868 ✓
42. Azouz R, Gray CM (1999). Cellular mechanisms contributing to response variability of cortical neurons in vivo. *J Neurosci* 19(6):2209–2223. doi:10.1523/JNEUROSCI.19-06-02209.1999 ✓
43. Fox MD, Snyder AZ, Zacks JM, Raichle ME (2006). Coherent spontaneous activity accounts for trial-to-trial variability in human evoked brain responses. *Nat Neurosci* 9(1):23–25. doi:10.1038/nn1616 ✓
44. Fox MD, Raichle ME (2007). Spontaneous fluctuations in brain activity observed with functional magnetic resonance imaging. *Nat Rev Neurosci* 8(9):700–711. doi:10.1038/nrn2201 ✓
45. Becker R, Reinacher M, Freyer F, Villringer A, Ritter P (2011). How ongoing neuronal oscillations account for evoked fMRI variability. *J Neurosci* 31(30):11016–11027. doi:10.1523/JNEUROSCI.0210-11.2011 ✓
46. He BJ (2013). Spontaneous and task-evoked brain activity negatively interact. *J Neurosci* 33(11):4672–4682. doi:10.1523/JNEUROSCI.2922-12.2013 ✓
47. Shimaoka D, Steinmetz NA, Harris KD, Carandini M (2019). The impact of bilateral ongoing activity on evoked responses in mouse cortex. *eLife* 8:e43533. doi:10.7554/eLife.43533 ✓
48. Haider B, Duque A, Hasenstaub AR, Yu Y, McCormick DA (2007). Enhancement of visual responsiveness by spontaneous local network activity in vivo. *J Neurophysiol* 97(6):4186–4202. doi:10.1152/jn.01114.2006 ✓
49. Petersen CCH, Hahn TTG, Mehta M, Grinvald A, Sakmann B (2003). Interaction of sensory responses with spontaneous depolarization in layer 2/3 barrel cortex. *PNAS* 100(23):13638–13643. doi:10.1073/pnas.2235811100 ✓ (refs.bib `Petersen2003` is this paper)
50. Sachdev RNS, Ebner FF, Wilson CJ (2004). Effect of subthreshold up and down states on the whisker-evoked response in somatosensory cortex. *J Neurophysiol* 92(6):3511–3521. doi:10.1152/jn.00347.2004 ✓
51. Hasenstaub A, Sachdev RNS, McCormick DA (2007). State changes rapidly modulate cortical neuronal responsiveness. *J Neurosci* 27(36):9607–9622. doi:10.1523/JNEUROSCI.2184-07.2007 ✓
52. Kisley MA, Gerstein GL (1999). Trial-to-trial variability and state-dependent modulation of auditory-evoked responses in cortex. *J Neurosci* 19(23):10451–10460. doi:10.1523/JNEUROSCI.19-23-10451.1999 ✓
53. Curto C, Sakata S, Marguet S, Itskov V, Harris KD (2009). A simple model of cortical dynamics explains variability and state dependence of sensory responses in urethane-anesthetized auditory cortex. *J Neurosci* 29(34):10600–10612. doi:10.1523/JNEUROSCI.2053-09.2009 ✓
54. Goris RLT, Movshon JA, Simoncelli EP (2014). Partitioning neuronal variability. *Nat Neurosci* 17(6):858–865. doi:10.1038/nn.3711 ✓
55. Lin I-C, Okun M, Carandini M, Harris KD (2015). The nature of shared cortical variability. *Neuron* 87(3):644–656. doi:10.1016/j.neuron.2015.06.035 ✓
56. Arandia-Romero I, Tanabe S, Drugowitsch J, Kohn A, Moreno-Bote R (2016). Multiplicative and additive modulation of neuronal tuning with population activity affects encoded information. *Neuron* 89(6):1305–1316. doi:10.1016/j.neuron.2016.01.044 ✓
57. Churchland MM, Yu BM, Cunningham JP, Sugrue LP, Cohen MR, Corrado GS, Newsome WT, Clark AM, Hosseini P, Scott BB, Bradley DC, Smith MA, Kohn A, Movshon JA, Armstrong KM, Moore T, Chang SW, Snyder LH, Lisberger SG, Priebe NJ, Finn IM, Ferster D, Ryu SI, Santhanam G, Sahani M, Shenoy KV (2010). Stimulus onset quenches neural variability: a widespread cortical phenomenon. *Nat Neurosci* 13(3):369–378. doi:10.1038/nn.2501 ✓
58. Mateo C, Avermann M, Gentet LJ, Zhang F, Deisseroth K, Petersen CCH (2011). In vivo optogenetic stimulation of neocortical excitatory neurons drives brain-state-dependent inhibition. *Curr Biol* 21(19):1593–1602. doi:10.1016/j.cub.2011.08.028 ✓

**Closed-loop control and disturbance**
59. Newman JP, Fong M, Millard DC, Whitmire CJ, Stanley GB, Potter SM (2015). Optogenetic feedback control of neural activity. *eLife* 4:e07192. doi:10.7554/eLife.07192 ✓
60. Bolus MF, Willats AA, Whitmire CJ, Rozell CJ, Stanley GB (2018). Design strategies for dynamic closed-loop optogenetic neurocontrol in vivo. *J Neural Eng* 15(2):026011. doi:10.1088/1741-2552/aaa506 ✓ full text
61. Bolus MF, Willats AA, Rozell CJ, Stanley GB (2021). State-space optimal feedback control of optogenetically driven neural activity. *J Neural Eng* 18(3):036006. doi:10.1088/1741-2552/abb89c ✓ full text (⚠ article no. 036006 not seen on a page; DOI and vol/issue verified)

**Not verified or not found:** a 2022 "West et al." wide-field arousal paper (not found); any quantitative wide-field-GCaMP vs LFP/EEG δ-power validation (none found); any specparam/FOOOF analysis of wide-field calcium spectra (none found); a Sanchez-Vives/Reig optogenetic Up/Down paper (not confirmed). Treat the last three as gaps rather than citations.
