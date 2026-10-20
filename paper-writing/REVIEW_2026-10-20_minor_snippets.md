# Minor review points: Overleaf snippets (2026-10-20)

Against Closedloop `main` 43fabaf. Each item gives the text to **find** on Overleaf and the text to
**replace** it with. Review IDs refer to `REVIEW_2026-10-20.md`.

---

## m1: truncated sentence closing the MPC section (results.tex)

**Find** (whole paragraph, after "...against $71^\circ$ under open loop (Figure~\ref{fig:mpc_direct}M)."):
```latex
This MPC demonstration shows that trial variability can be significantly reduced using predictive modeling. The improvement over open loop demonstrates the
```
**Replace with** (or delete it):
```latex
In both replays, predicting the disturbance lowered the error that feedback left, and in the sinusoidal replay also its trial-to-trial variability.
```
("Significantly" is dropped because no test was run.)

---

## m3: bandwidth limit (results.tex, Figure 1 paragraph)

**Find:**
```latex
This delay limits the bandwidth over which feedback can act (see Discussion).
```
**Replace with:**
```latex
This delay, together with the kinetics of the indicator and the opsin, limits the bandwidth over which feedback can act (see Discussion).
```

---

## m4: latency over a whole session (methods_rewrite.tex)

New analysis (`controller-analysis/ctrl_latency.m`, Mouse 4, 3539 closed-loop laser updates):
median 24.0 ms, 99th percentile 40.0 ms, maximum 43.5 ms, and 12.6% of updates arrived after the next
blue frame.

**Find:**
```latex
exposure to stimulation command, was measured over 200 loop cycles
(Fig.~\ref{fig:figure1}F).
```
**Replace with:**
```latex
exposure to stimulation command, was measured over 200 loop cycles
(Fig.~\ref{fig:figure1}F). Over a whole session (Mouse~4; 3539 closed-loop laser
updates, timed from the exposure start of the source frame to the laser edge
recorded on the Timeline), latency had a median of 24.0\,ms, a 99th percentile of
40.0\,ms and a maximum of 43.5\,ms, and 12.6\% of updates arrived after the next
blue frame.
```
❓ The script reports the channel that fired in this session as `lightCommand594`, but the
Methods say 638 nm. Probably just a channel name. Please confirm the wavelength for the 2026
sessions.

---

## m5: Fig 4C per-session trial counts (results.tex, Figure 4 caption)

New check: there are 16–108 closed-loop trials per session. Dropping the two sessions with fewer
than 30 (1f: 24, 1h: 16) moves no mean unique R² by more than 0.03. For example, absolute power at
steady state goes from 0.11 to 0.14 and initial deviation in the transient from 0.53 to 0.52.

**Find** (in the C: entry):
```latex
error bars, SEM ($n = 11$ sessions, 613 trials).
```
**Replace with:**
```latex
error bars, SEM ($n = 11$ sessions, 613 trials, 16--108 per session; without the two sessions with fewer than 30 trials, no mean changes by more than 0.03).
```

---

## m6: post-stimulation windows (results.tex Fig 3 caption + stat_tables.tex Table 4 caption)

Cause, from `variance_mse.m`: the stored trial segment ends 1 s after offset, so post-stimulation RMSE
can only use 1 s. Variance uses a separate 3 s buffer. The fix states the reason. (Making the two
windows equal would mean rerunning Table 4.)

**Find** (Fig 3, H entry; this also fixes the double period):
```latex
and post-stimulation (1\,s after offset). Gray lines,
```
```latex
($n = 15$ sessions, 4 mice; Materials and Methods)..\\
```
**Replace with:**
```latex
and post-stimulation (1\,s after offset, the end of the stored trial segment). Gray lines,
```
```latex
($n = 15$ sessions, 4 mice; Materials and Methods).\\
```

**Table 4 caption (stat_tables.tex):** replace the whole `\caption{...}`. This supersedes the snippet
from my earlier message.
```latex
\caption{\textbf{Closed- versus open-loop tracking error and trial-to-trial variability} (Figure~\ref{fig:figure3}; 15 sessions, 4 mice, 1670 trials). Ratio, per-session ratio of the closed- to the open-loop value (mean per-trial RMSE, or across-trial variance averaged over the window), so that below one means closed loop was better; geometric mean across sessions with its $t$-based 95\% CI. $t$ (df) and $p$, mixed model $\log r \sim 1 + (1\mid\mathrm{mouse})$ with Satterthwaite degrees of freedom (Materials and Methods). Lower, $100\,(1-\mathrm{ratio})$. Below 1, sessions with ratio below one. Post-stimulation window, 1\,s (RMSE, the end of the stored trial segment) or 3\,s (variance) after offset.}
```

---

## m7: asymptotic theory vs a 3 s reset integrator (discussion.tex, limitations)

**Find:**
```latex
Gains were tuned empirically, and the low-gain guarantee assumes a fixed plant, so stability rests on the observation that no session showed sustained oscillation.
```
**Replace with:**
```latex
Gains were tuned empirically, and the low-gain guarantee is asymptotic and assumes a fixed plant, whereas our integrator ran over 3\,s trials and was reset between them, so the theory motivates the design and stability rests on the observation that no session showed sustained oscillation.
```

---

## m8: tested range and gain spread (results.tex, Figure 2 text)

**Find:**
```latex
This input--output relationship was approximately linear (slopes
```
**Replace with:**
```latex
Over the tested range (0.13--1.63\,mW), this input--output relationship was approximately linear, with a 3.5-fold spread in gain across sessions (slopes
```

---

## m8–m12 + agreed M7/M8 wording: Abstract (main.tex)

Replace the whole live Abstract body (the commented-out draft above it stays):

- m8: tested range
- m10: readout next to the stimulated site
- m11: inhibition only, reference below baseline
- m12: "in one mouse"
- M7: "within a session"
- M8: "simulated", and credit to a linear model rather than "forecasting"

```latex
Mesoscale brain dynamics have been linked to a wide range of perceptual, cognitive and motor functions. However, establishing causal links between mesoscale dynamics and behavior remains challenging, because it requires not only perturbing these dynamics but also precisely shaping them. Here we show that closed-loop optogenetic inhibition can steer cortical activity in real time toward a reference below baseline, using feedback from the ongoing activity it controls.
Over the tested powers, the trial-averaged response of a cortical readout next to the stimulated site is approximately linear and, within a session, time-invariant. On this basis, we design a linear feedback controller that tracks a reference.
It holds activity at the reference more accurately than open-loop stimulation in all 15 sessions from 4 mice and reduces trial-to-trial variability, consistent with disturbance rejection.
Controller performance depends on brain state: relative to open loop, it improves with movement and degrades with slow-wave-like delta-band (1--4\,Hz) activity.
Predicting the disturbance on each trial from the opposite hemisphere, we show that feedback partially rejects it.
In one mouse tracking a time-varying reference, preview cancels the phase lag of the cortical response, whereas feedback reduces error and variability.
Finally, in a simulated replay of recorded trials, a model-predictive controller using a linear model of cortex and the laser lowers the error left by feedback by about 40\%.
Together, these results show that approximately linear, time-invariant trial-averaged dynamics can be used to control regional cortical activity, and that the error left under control is informative about brain state.
```
The major points (M3 uncorrected ΔF/F, M6 mouse-level wording) may change it again. That will be the
one final pass after the majors.

## m9–m11: Significance Statement (main.tex)

```latex
We introduce a closed-loop control framework that steers cortical activity toward a reference. Using wide-field calcium imaging, we read out activity at one cortical site in real time and use it to set optogenetic inhibition delivered next to it, which can only lower that activity. Closed-loop stimulation tracks the reference more accurately than open-loop stimulation and reduces trial-to-trial variability across sessions and animals. The error that remains under feedback depends on cortical state around stimulation, and feedforward preview corrects the phase lag when tracking time-varying references. Finally, a linear model of the opposite hemisphere predicts much of the spontaneous activity in the controlled region (median held-out $R^2 = 0.76$), which lets us estimate the disturbance the controller rejects on each trial.
```

---

## m14: Fig 2B trial counts (results.tex, Figure 2 caption)

**Find:**
```latex
($n = 44$--$59$, $81$--$85$ and $100$ trials per amplitude for Mice 5a--5b, 1b and 3c;
```
**Replace with:**
```latex
($n = 44$--$59$, $45$--$58$, $81$--$85$ and $100$ trials per amplitude for Mice 5a, 5b, 1b and 3c;
```

---

## m15: two different "0.56" values (results.tex)

Fig 2C caption. **Find:**
```latex
at three amplitudes (Mouse 1b), with the held-out $R^2$ for each.\\
```
**Replace with:**
```latex
at three amplitudes (Mouse 1b), with the held-out $R^2$ of this split at each amplitude.\\
```
Text. **Find:**
```latex
per-session medians ranged from $0.56$ in Mouse 5a
```
**Replace with:**
```latex
the median over splits ranged by session from $0.56$ in Mouse 5a
```

---

## m17: mouse numbering (methods_rewrite.tex, Table 1 caption)

**Find:**
```latex
A session is named by its mouse number,
```
**Replace with:**
```latex
Mice 1--4, which contributed closed-loop sessions, are numbered in order of their first session, and Mouse 5 contributed only impulse sessions. A session is named by its mouse number,
```

---

## m18: motion result vs correction (results.tex, Fig 2G text)

Fig 2G is descriptive by your earlier decision, so this names the test without quoting p in the text.
**Find:**
```latex
so the pattern was a drop at the highest motion rather than a graded trend (top versus bottom quartile,
```
**Replace with:**
```latex
so the pattern was a drop at the highest motion rather than a graded trend, and its supporting test did not survive correction for the three states (Table~\ref{tab:stat_fig2g}; top versus bottom quartile,
```

---

## m19: sex (methods_rewrite.tex, Design)

**Find:**
```latex
mice (2 male, 2 female; 1670 trials) for Figs.~\ref{fig:figure3}
```
**Replace with:**
```latex
mice (2 male, 2 female, too few to test for sex differences; 1670 trials) for Figs.~\ref{fig:figure3}
```

---

## Added: Zhang et al. 2018 as the closest precedent (discussion.tex, comparison paragraph)

PMC6513754 is Zhang et al. 2018, *Nat Methods*, already cited as `Zhang2018` (Intro L34,
Discussion L41). This sentence uses its full text. In their "activity clamp", two-photon
stimulation fired whenever a neuron's GCaMP6s ΔF/F fell below a target (30, 50 or 80%). The
achieved level had a mean absolute error of 5.2 ± 4.7% ΔF/F (18 cells, 6 awake mice), and
the same approach reduced cell-to-cell and trial-to-trial variability of optogenetic responses
(their Supp. Fig. 3).

**Find:**
```latex
could not lower rates above target with an excitatory opsin~\citep{bolus2018design}, the mirror image of our one-sided limit.
```
**Replace with:**
```latex
could not lower rates above target with an excitatory opsin~\citep{bolus2018design}, the mirror image of our one-sided limit.
Closest to our readout, on/off two-photon feedback in awake mouse cortex held the calcium signal of single neurons near set levels, with a mean absolute error of about 5\%\,$\Delta F/F$, and made optogenetic responses more uniform across cells and trials~\citep{Zhang2018}, whereas our controller graded the light continuously and regulated a mesoscale signal.
```

---

## No snippet

| # | Status |
|---|---|
| m2 | Code URL placeholder. Needs a public repo or Zenodo DOI before arXiv (your call). |
| m13 | Figure legibility (Fig 1, Fig S4A). Your Illustrator work. The Fig 4G labels come with the regenerated panel. |
| m16 | Laser calibration. Skipped: you've already settled this. |
| m20 | Matveev 2024 is still a bioRxiv preprint (v1, no published version per the bioRxiv API). The reviewer wants the key preparation parameters here. ❓ Send me the 470/405 nm illumination intensity at the brain, and how Matveev et al. showed it does not activate ChrimsonR. I'll then draft the sentence. |
| m21 | No change needed. Crossref: Gupta & Murphy, eLife vol. 14, RP105070, version of record 2026-09-24. Ye 2026, Science 392:eadx1369. Both entries are correct. |
