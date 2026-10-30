# Relative vs absolute low-frequency power: what they are, why these bands, how to write it

**Started:** 2026-10-29 (Aditya: "we need to be clear on the difference between relative and absolute
powers for 2-4hz, and use reference to show why we are using these specific bands"; then "put the
content about relative vs absolute and reference in a md file and lets start thinking about how to
tweak text to add them").
**Triggered by:** Anna F2.7 ("what is relative vs absolute supposed to be", "why del? isnt this supposed
to be alpha?"). Tracker: `REVIEW_ANNA_2026-10-29.md` F2.7 / F2.7a.
**Literature source:** `lit_delta_state_2026-10-15.md` checked every reference used here against
PubMed/PMC, the journal page or a DOI record. ⚠ marks a detail that was not verified.
**Draft:** these are proposals for the NC draft (`Closedloop_nc`); nothing here has been applied.

---

## 1. Definitions (as computed)

| | Fig 2g (impulse) | Fig 4 (controller) |
|---|---|---|
| Window | [−1, 0) s before onset, 35 samples | [−2, +3) s, 175 samples |
| Estimator | mean removed, Hann, FFT, native 1 Hz bins, edges inclusive (`imp_state_trialvar.m` `local_delta`) | detrended, Hann, zero-padded ≥ 8192, trapezoid between exact band edges (`utils/f4_bandpow.m` 'continuous') |
| **Absolute** | sum of the 2, 3, 4 Hz bins | log10 of 1–4 Hz power |
| **Relative** | (2–4 Hz) / (0.4–10 Hz); at 1 Hz resolution the denominator is in practice the 1…10 Hz bins | (2–4 Hz) / (0.4–10 Hz) |
| Scaling for analysis | quartiles within session | z-scored within session |

In one line: **absolute = how big the 2–4 Hz fluctuations are; relative = what share of 0.4–10 Hz activity lies in 2–4 Hz.**
Doubling the signal multiplies absolute power by four and leaves relative power unchanged.

## 2. What our own data say

Impulse trials (`impulse-analysis/imp_relabs_exemplars.m`, 2026-10-29; 1516 trials, 4 sessions):
- Spearman(absolute, relative) = **0.47** pooled (0.41–0.50 per session). This matches Results L101.
- Absolute 2–4 Hz power tracks **total 0.4–10 Hz power at ρ = 0.97** (0.95–0.97 per session).
  Relative power does not (**ρ = 0.24**, 0.13–0.29).
- Mouse 1b trial groups (shares of 0.4–10 Hz power):

  | Group | n | at 1 Hz | in 2–4 Hz | median total | median absolute 2–4 Hz |
  |---|---|---|---|---|---|
  | typical (\|z\| < 0.5 on both) | 72 | 37% | 49% | 1.78 | 0.85 |
  | high absolute, low relative (z_abs > 1, z_rel < 0) | 20 | 53% | 42% | 28.3 | 12.2 |
  | high relative, absolute ≥ mean (z_rel > 1, z_abs ≥ 0) | 104 | 11% | 81% | 10.0 | 9.3 |

  (power in (%ΔF/F)² Hz⁻¹ summed over bins.) The first version of the high-relative group required
  z_abs < 0: n = 29, 8% / 80%, median total 0.45. Those trials were too small for a rhythm to show
  (Aditya: "these high relatives ones dont have the short bursts i was hoping exist").
- **Reading.** The two non-typical groups carry similar 2–4 Hz power, but the high-absolute trials
  also carry ten times more power at 1 Hz. A trial is high in absolute 2–4 Hz power when all of its
  fluctuations are large, mostly slower than 2 Hz. A trial is high in relative power when its activity
  comes in short 2–4 Hz bursts (the exemplar has 95% of its 0.4–10 Hz power in 2–4 Hz).
- **Consequence for Fig 2g's absolute result** (variability ×2.35 from bottom to top quartile):
  trials with larger pre-stimulus fluctuations deviate more from the mean response. The
  stimulus-free control shows the same rise (×2.70), so this is the amplitude of ongoing activity,
  as the "disturbance amplitude" framing says. Do not describe it as a rhythm effect.

Controller trials (`controller-analysis/f4_delta_candidates.m`, 2026-09-15; 613 CL trials, Fig 4 window):
- corr(log absolute 1–4 Hz, relative 2–4 Hz) = 0.53 Pearson / 0.55 Spearman.
- The same two profiles appear: absolute picks large slow swings with spectra dominated below 2 Hz;
  relative picks smaller, flatter traces with power concentrated at 2–4 Hz.
- The supplement already shows per-session controller exemplars for each state
  (`f4_state_exemplars_supp.m`, Supplementary Fig. f4_exemplars a).

## 3. Why these bands (with references)

**Low frequencies index cortical state.**
- In awake mice, slow, large, correlated fluctuations mark quiet wakefulness. Whisking replaces them
  with small, fast, decorrelated ones [Crochet & Petersen 2006; Poulet & Petersen 2008].
- 1–4 Hz LFP power falls with arousal and locomotion [Vinck et al. 2015].
- Reviews put synchronized and desynchronized states on a continuum defined by low-frequency power
  [Harris & Thiele 2011; McGinley et al. 2015 review].
- ⚠ Reimer 2014 (pupil) fits, but its exact band was not verified; leave it out of band claims.

**Wide-field calcium imaging sees this range, but not much higher.**
- Pre-stimulus 3–6 Hz wide-field GCaMP power was used as the synchrony index in a closely related
  preparation [Jacobs et al. 2020, Harris/Carandini/Steinmetz]. Indicator kinetics stopped them going
  higher.
- Quiet-awake wide-field GCaMP6s shows a spontaneous mode near 2.6 Hz in the 2–5 Hz band [Vanni et al. 2017].
- Delta-band (0.4–4 Hz) wide-field GCaMP correlations change strongly with wake, sleep and anaesthesia
  [Brier et al. 2019; Wright et al. 2017] (optional citations).

**Hemodynamics are slower.**
- GCaMP–hemoglobin coherence in mice peaks near 0.2 Hz [Wright et al. 2017]. Resting hemodynamics are a
  slow, low-pass copy of neural activity [Ma et al. 2016 PNAS].
- Hemoglobin absorption distorts GCaMP fluorescence multiplicatively [Ma et al. 2016 Phil Trans B;
  Valley et al. 2020 ⚠ frequency claims unread].
- So 2–4 Hz sits above most of the hemodynamic signal, and a ratio cancels the multiplicative part.

**So, per band:**
- **2–4 Hz** (relative numerator; Fig 2 absolute): inside the slow range that indexes state, above most
  hemodynamic signal, within what the indicator follows. The same band in both figures, so Fig 2 and
  Fig 4 measure the same quantity (canonical since 2026-09-11; RESEARCH 2026-09-08).
- **0.4–10 Hz** (relative denominator): the range of the 35 Hz readout below its 17.5 Hz Nyquist
  frequency, without drifts slower than 0.4 Hz. This is a description, not a literature claim; no
  paper sets this edge.
- **1–4 Hz** (Fig 4 absolute): the conventional δ band [Vinck 2015 uses 1–4 Hz LFP]. Fig 4's 5 s window
  resolves it. Fig 2's 1 s window does not (1 Hz bins), which is why Fig 2's absolute measure starts at 2 Hz.

**Why both measures.**
- Absolute power grows with the amplitude of ongoing activity, which adds to the evoked response as a
  disturbance [Arieli et al. 1996; Shimaoka et al. 2019, mouse wide-field, "interacted additively"].
  It also grows with anything that scales the whole signal: expression, illumination, hemoglobin
  absorption [Ma 2016], and in Fig 4 the open- vs closed-loop magnitude difference.
- Relative power cancels those multiplicative factors and describes spectral shape. Like any band
  ratio, it also follows changes in the aperiodic (1/f) slope [Donoghue, Dominguez & Voytek 2020 eNeuro].
  Write "normalized for overall amplitude", never "independent of power".

## 4. Caveats to state or keep in mind

1. **Remove "the sub-band least attenuated by the controller"** (NC `methods.tex` L479). It reads as
   outcome-informed selection (review M19, 2026-10-03). It is also wrong: feedback raises 2–4 Hz power
   1.44-fold during stimulation (RESEARCH 2026-10-11, 13/15 sessions).
2. Fig 2's denominator is in practice 1–10 Hz (1 s window, 1 Hz bins). Say so in Methods.
3. Mouse respiration (~3–5 Hz) falls in the numerator and heart rate (~8–10 Hz) in the denominator.
   Both survive correction at low amplitude [Wright 2017]. The controller signal is not
   hemodynamically corrected; the impulse signal is.
4. Relative power did not replicate as a predictability marker on independent data (Zhiwen AB_0004,
   opposite sign; RESEARCH 2026-07-02). The paper already promises little for it; keep it that way.
5. Absolute power and RMSE are both magnitudes of the same signal, and in Fig 4 the windows overlap.
   Fig 2's strictly pre-stimulus window is the non-overlapping version.

## 5. Supplementary figure (candidate)

Script `impulse-analysis/imp_relabs_exemplars.m`, panels in `paper/images/supplementary/relabs/`
(`relabs_scatter.pdf`, `relabs_traces_Mouse1b.pdf`, `relabs_spectra_Mouse1b.pdf`). Not in MANIFEST yet.

Draft caption:
> **Relative and absolute 2–4 Hz power describe different features of pre-stimulus activity.**
> **a**, Relative versus absolute 2–4 Hz power over the 1 s before onset for all 1516 impulse trials
> (four sessions), each z-scored within session (absolute power on a log scale); colors, sessions.
> Circles mark the trials in **b**. Spearman ρ = 0.47.
> **b**, Three trials from Mouse 1b chosen by rule: typical (both near the session mean), high absolute
> and low relative power ($z_{abs} = +0.9$, $z_{rel} = −1.5$), and the highest relative power among
> trials with at least average absolute power ($z_{abs} = +1.1$, $z_{rel} = +2.2$). The two have similar
> absolute 2–4 Hz power. Light lines, each trial's 2–4 Hz component in the measurement window
> (zero-phase band-pass, for display). Gray shading, the window over which power was measured; red,
> laser command.
> **c**, Mean spectra over the same window for Mouse 1b trials that were typical ($|z| < 0.5$ on both;
> n = 72), high in absolute and below average in relative power ($z_{abs} > 1$, $z_{rel} < 0$; n = 20),
> or high in relative power with at least average absolute power ($z_{rel} > 1$, $z_{abs} \ge 0$;
> n = 104). Left, power spectral density; right, each frequency bin as a fraction of 0.4–10 Hz power.
> Gray band, 2–4 Hz. Over all trials, absolute 2–4 Hz power followed total 0.4–10 Hz power (Spearman
> ρ = 0.97), whereas relative power did not (ρ = 0.24).

Options still open:
- (i) Add a per-session version (rows = sessions), as the controller supplement does, to answer "is
  Mouse 1b cherry-picked?".
- (ii) Add the controller counterpart as a second row, built from `f4_delta_candidates.m` on the Fig 4
  window, so one supplementary figure explains both.
- (iii) Merge this into the existing Supplementary Fig. state_quartile as a new first row.

## 6. Text changes (NC line numbers as of 2026-10-29)

**Results L87** (state measures). Replace the one long sentence with:
> We characterized the state before each stimulus with three measures, all taken over the 1 s before
> onset (Methods): motion energy from face video, a measure of the animal's movement, and two measures
> of 2–4 Hz power in the readout.
> Low-frequency power is high when cortex is synchronized and falls with movement and
> arousal~\citep{Crochet2006,Poulet2008,Vinck2015}, and wide-field calcium imaging resolves such
> rhythms up to a few hertz~\citep{Vanni2017,Jacobs2020}.
> Absolute 2–4 Hz power is the power in that band, so it grows with the size of ongoing fluctuations;
> across trials it followed total 0.4–10 Hz power closely (Spearman ρ = 0.97).
> Relative 2–4 Hz power divides it by 0.4–10 Hz power, so it measures the share of activity in the
> band whatever its size (ρ = 0.24 with total power; Supplementary Fig.~\ref{fig:relabs}).

**Results L93, L95–97**: "absolute/relative $\delta$ power" → "absolute/relative 2–4 Hz power"
(L95 "motion, relative and absolute $\delta$ power" → "motion, relative and absolute power").

**Results L97** (optional, from §2): "with higher absolute 2–4 Hz power both were more variable" →
"when ongoing fluctuations were larger (higher absolute 2–4 Hz power), both were more variable".

**Results L101–102**:
> The two power measures were correlated but not redundant (Spearman ρ = 0.47 over the impulse trials).
> We therefore carry both into the closed-loop analysis: absolute power as a measure of the amplitude
> of ongoing activity, which adds to the response as a disturbance~\citep{Arieli1996,Shimaoka2019},
> and relative power as a measure of spectral state normalized for overall amplitude.
> There, the 5 s window resolves the full 1–4 Hz band, so absolute power is taken over 1–4 Hz, and all
> state measures are computed from −2 to +3 s around onset (Methods).

**Fig 2g caption**: "relative 2--4\,Hz ($\delta$) power and absolute 2--4\,Hz power" → "relative 2--4\,Hz
power (fraction of 0.4--10\,Hz power) and absolute 2--4\,Hz power"; also fix the stray space in "state .".

**Methods L479–482** (replace):
> \emph{Relative 2--4\,Hz power} is the ratio of band power in 2--4\,Hz to total power in 0.4--10\,Hz.
> \emph{Absolute low-frequency power} is band power without that normalization: 2--4\,Hz in
> Fig.~\ref{fig:figure2}g and $\log_{10}$ of 1--4\,Hz power in Fig.~\ref{fig:figure4}.
> The two measure different things.
> Absolute power grows with the amplitude of slow fluctuations, the part of ongoing activity that adds
> to an evoked response~\citep{Arieli1996,Shimaoka2019}.
> It also grows with anything that scales the whole signal, such as indicator expression, illumination
> or hemoglobin absorption, which act multiplicatively on wide-field fluorescence~\citep{Ma2016}, and in
> Fig.~\ref{fig:figure4} with the difference in signal magnitude between open and closed loop.
> Relative power cancels such multiplicative factors and describes how activity is distributed across
> frequencies, although, like any band ratio, it also follows changes in the aperiodic slope of the
> spectrum~\citep{Donoghue2020eNeuro}.

**Methods, new paragraph "Bands"** (after the definitions):
> \emph{Bands.} Power below about 4\,Hz indexes synchronized cortical states and falls with whisking,
> locomotion and arousal~\citep{Crochet2006,Poulet2008,Vinck2015}.
> In wide-field calcium imaging, the indicator's kinetics attenuate faster rhythms; earlier work
> measured cortical synchrony from wide-field GCaMP power at 3--6\,Hz~\citep{Jacobs2020}, and quiet
> wakefulness carries a spontaneous wide-field mode near 2.6\,Hz~\citep{Vanni2017}.
> Hemodynamic signals are slower: GCaMP--hemoglobin coherence peaks near 0.2\,Hz~\citep{Wright2017}.
> The 2--4\,Hz band therefore lies within the slow activity that indexes state, above most of the
> hemodynamic signal, and within what the indicator follows; we used it for relative power in both
> figures so that they measure the same quantity.
> The 0.4--10\,Hz denominator spans the 35\,Hz readout below its 17.5\,Hz Nyquist frequency, excluding
> drifts slower than 0.4\,Hz.
> In Fig.~\ref{fig:figure2}g the 1\,s window gives 1\,Hz resolution, so the denominator is in practice
> 1--10\,Hz and the absolute band starts at 2\,Hz; the 5\,s window of Fig.~\ref{fig:figure4} resolves
> the conventional 1--4\,Hz band, which its absolute measure uses.

**Fig 4 text** (L185, L193–194, L208–210, caption L169/L171): these already say "relative 2–4 Hz" and
"absolute 1–4 Hz" without δ. Optionally add one clause at L185: "absolute 1--4\,Hz power, which
measures the amplitude of slow fluctuations".

**Discussion L14** "which our slow-wave power measures track" → "which our 1--4\,Hz and relative
2--4\,Hz power measures track". L48 already says "slow, large-amplitude 1--4\,Hz fluctuations", which
matches §2.

## 7. Bibliography

New entries for NC `refs.bib` (all ✓ in the 2026-10-15 check):
```bibtex
@article{Jacobs2020, author={Jacobs, Elina A. K. and Steinmetz, Nicholas A. and Peters, Andrew J. and Carandini, Matteo and Harris, Kenneth D.}, title={Cortical state fluctuations during sensory decision making}, journal={Current Biology}, volume={30}, number={24}, pages={4944--4955.e7}, year={2020}, doi={10.1016/j.cub.2020.09.067}}
@article{Vanni2017, author={Vanni, Matthieu P. and Chan, Allen W. and Balbi, Matilde and Silasi, Gergely and Murphy, Timothy H.}, title={Mesoscale mapping of mouse cortex reveals frequency-dependent cycling between distinct macroscale functional modules}, journal={Journal of Neuroscience}, volume={37}, number={31}, pages={7513--7533}, year={2017}, doi={10.1523/JNEUROSCI.3560-16.2017}}
@article{Donoghue2020eNeuro, author={Donoghue, Thomas and Dominguez, Julio and Voytek, Bradley}, title={Electrophysiological frequency band ratio measures conflate periodic and aperiodic neural activity}, journal={eNeuro}, volume={7}, number={6}, pages={ENEURO.0192-20.2020}, year={2020}, doi={10.1523/ENEURO.0192-20.2020}}
@article{Ma2016, author={Ma, Ying and Shaik, Mohammed A. and Kim, Sharon H. and Kozberg, Mariel G. and Thibodeaux, David N. and Zhao, Hanzhi T. and Yu, Hang and Hillman, Elizabeth M. C.}, title={Wide-field optical mapping of neural activity and brain haemodynamics: considerations and novel approaches}, journal={Philosophical Transactions of the Royal Society B}, volume={371}, number={1705}, pages={20150360}, year={2016}, doi={10.1098/rstb.2015.0360}}
@article{Wright2017, author={Wright, Patrick W. and Brier, Lindsey M. and Bauer, Adam Q. and Baxter, Grant A. and Kraft, Andrew W. and Reisman, Matthew D. and Bice, Annie R. and Snyder, Abraham Z. and Lee, Jin-Moo and Culver, Joseph P.}, title={Functional connectivity structure of cortical calcium dynamics in anesthetized and awake mice}, journal={PLoS ONE}, volume={12}, number={10}, pages={e0185759}, year={2017}, doi={10.1371/journal.pone.0185759}}
```
Already in NC `refs.bib`: Crochet2006, Poulet2008, Vinck2015, Harris2011, McGinley2015waking (review),
Arieli1996, Shimaoka2019, Ye2026, musall2019single, stringer2019.
