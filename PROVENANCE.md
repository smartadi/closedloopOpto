# PROVENANCE.md — what the code computes vs. what the paper says it computes

One entry per **distinct quantity** the manuscript reports, not per panel. There are 54 panel
files in `paper/figures_final/MANIFEST.txt` but only ~16 distinct computations, reused across
panels.

## The rule this file was built under

**The code was read first and written down before the manuscript text for that quantity was
opened.** This is not a style preference. `NUMBERS.md` §2.3 audited text-against-text and
reached a conclusion that is backwards (it concluded the prose should say "171 ms not 200 ms";
the code genuinely ends at 200 ms — the *equation* is the defect). Reading the text first
anchors you into rubber-stamping it.

Manuscript: `C:\Users\aditya\Documents\projects\Closedloop_edit` (branch `draft`).
Code: this repo, branch `alpha`.

## Status flags (same set `NUMBERS.md` uses)

| flag | meaning |
|---|---|
| ✅ | matches — code and text describe the same operation |
| 🟥 | conflict — code and text disagree about what is computed |
| 🟨 | underspecified — text is not wrong, but does not pin the operation down, or the wording implies a different operation than the code performs |
| ⬜ | could not trace — with a statement of exactly what blocked it |

## Scope note

Verdicts are about **the operation**, not about numeric values. Nothing here was re-run; no
value in the manuscript was recomputed. Where a number could not be checked without running
MATLAB that is stated.

---

## Q1 — Evoked suppression ("inhibition energy")

**Code:** `impulse-analysis/load_experiments.m:342-346` (`peak_mode == 3`; `fs = 35` at
`load_experiments.m:229`)
**Computes:** `post_start = winSamp + 2` — the code's own comment calls this the "first sample
strictly after onset", so the onset sample is `winSamp+1`. Then
`win3 = post_start : winSamp + round(0.22*fs)`; `round(0.22*35) = round(7.7) = 8`. Window =
samples `winSamp+2 .. winSamp+8` = onset+1 .. onset+7 = **t = 28.6 ms to 200.0 ms, 7 samples,
onset sample EXCLUDED**. `p_imp = mean(df_imp(:, win3), 2)` — an **arithmetic mean** of 7
samples, units %ΔF/F, one value per trial. The branch comment reads "mean dF/F over 0–200 ms
post-onset. Integrates total inhibition energy" — the comment itself carries both the "0 ms"
and the "energy" errors.
**Paper says:** `methods_rewrite.tex` §Evoked suppression, `eq:inhib_energy`:
`W = {t_on, ..., t_on+6}` = 0 to 171.4 ms, 7 samples. Prose above it: "the mean ΔF/F over the
200 ms following stimulation onset" (correct). `results.tex:51` (Fig 2A caption) and
`results.tex:62`: "Total inhibition energy (suppression integrated over 0–200 ms)" and "mean
total inhibition energy per trial".
**Panels:** Fig 2A, 2B
**Verdict:** 🟥 The equation is off by one sample: both windows are 7 samples, but the code's
starts at onset+1 and ends at 200.0 ms while the equation's starts at onset and ends at
171.4 ms. Separately, `results.tex:51` and `:62` still use the retired name "inhibition energy"
and describe the quantity as *integrated*, when it is a mean — the Methods already renamed it
"evoked suppression" and flags this in a `%%` comment.
**Fix:** In `eq:inhib_energy`, set `W = {t_on+1, ..., t_on+7}` and keep "seven samples at
35 Hz" (the window is then 28.6–200 ms, matching the prose). In `results.tex:51` replace
"Total inhibition energy (suppression integrated over 0–200 ms)" with "Evoked suppression
(mean ΔF/F over 0–200 ms)"; same substitution at `results.tex:62`.
**Note:** `NUMBERS.md` §2.3 concluded the prose should say "171 ms not 200 ms". That is
backwards — the code does end at 200 ms.

---

## Q2 — Dose-response slope and R²

**Code:** `impulse-analysis/dose_response.m:60-94` (plotted fit) and
`impulse-analysis/f2_slope_ci.m:22-34` (the CI companion, whose header states it "Replicates
dose_response.m's fit EXACTLY")
**Computes:** per session, group the per-trial evoked suppression (`allVals`, = Q1's `p_imp`,
assembled at `load_experiments.m:378-385`) by amplitude label; take the **mean per amplitude**;
drop amplitude 0 via `nzMask = xpos_raw > 0` ("exclude 0-amp gap-fill markers (not real laser
trials)"). Then `p = polyfit(xpos, meanVals, 1)` — a straight line through **~4–6 per-amplitude
means**, not through trials. R² = `1 - SS_res/SS_tot` on those same ~4–6 points
(`dose_response.m:91-93`). x is in **Volts** — `xlabel('Amplitude(V)')` at
`dose_response.m:110`, printf format `'slope=%.4f dF%%/V'` at `:94`; no `laser_v2mw` call
anywhere in the script (the mW appears only as a scale-bar *label*, `dose_response.m:136,149`,
with the comment "XLength is in DATA units (V); the label is the mW equivalent"). The plotted
x is jittered by `(expIdx-2)*0.005` for visual offset; a constant x-shift moves the intercept
only, so the slope is unaffected. `f2_slope_ci.m` additionally reports a RAW-FIT (all
per-trial points, proper trial n) with a much tighter CI.
**Paper says:** `results.tex:42` "impulse inputs at discrete amplitudes spanning 0–1.8 mW";
`results.tex:62` "slopes −0.34, −0.57, −0.59, −0.96 and R² = 0.97, 0.51, 0.92, 0.91";
`results.tex:51` (Fig 2A caption) "Points, mean ± SEM across trials (~40–150 trials per
amplitude); lines, the fitted linear input–output relationship. … (slopes −0.34 to −0.96)".
**Panels:** Fig 2A
**Verdict:** 🟥 Unit mismatch: the amplitude axis the slopes were fitted on is **Volts**, while
the Results states the amplitude range in **mW**. A slope quoted bare next to a mW range reads
as %ΔF/F per mW; it is %ΔF/F per Volt. Additionally 🟨: the R² values are the goodness of fit
of a line through 4–6 **group means**, which is a very different (and much higher) number than
a trial-level R²; neither the Results sentence nor the caption says so, and no CI is given
although `f2_slope_ci.m` exists precisely to supply one.
**Fix:** Either convert the fit x-axis to mW with `laser_v2mw` and re-quote the slopes with
`%ΔF/F mW⁻¹`, or state the unit explicitly as `%ΔF/F V⁻¹` and drop/qualify the mW range.
Add to the caption: "lines, least-squares fit through the per-amplitude means (R² computed on
those means, n = 4–6 points per session)". Consider quoting the RAW-FIT slope ± 95% CI from
`f2_slope_ci.m` instead, which is the reviewer-facing number.

---

## Q3 — Transfer-function fit: order sweep and selection

**Code:** `impulse-analysis/imp_tf_run.m:157-171` (sweep bounds) and
`utils/imp_tf_fit_session.m:145-146, 371-395, 431-472` (selection)
**Computes:** `RUN_MAXPOLES = 5`, `opt.maxZeros = max(RUN_MAXPOLES-1, 1) = 4`,
`RUN_MAXDELAY = 3` samples (= 0–85.7 ms at 35 Hz), `tFit_s = 0.5` s fit window. The sweep is
constrained `nz < np` — "strictly proper -> h(0)=0, which onset-referencing depends on"
(`imp_tf_fit_session.m:431`). `tfest` is called with `EnforceStability = false`. AIC picks a
winner (`[~, iA] = min([res.AIC])`), but selection does **not stop there**: `local_select`
applies an escalation — if the AIC winner's `R2h` (fit to the measured h(t)) is below
`minR2h = 0.98`, the model is re-picked as the most parsimonious candidate within 0.002 R2h of
the best available, and `T.selRule` records which rule fired. The header is explicit: "'aic' is
the default and still picks by AIC -- but AIC here … So there is an ESCALATION".
`imp_tf_run.m:281-283` prints how many sessions were re-picked off AIC.
**Paper says:** `methods_rewrite.tex` §Transfer-function fitting: "We swept 1--3 poles, 0--2
zeros, and 0--5 samples of pure delay (0--143 ms at 35 Hz), took the best fit at each order,
and selected across orders by the Akaike Information Criterion."
**Panels:** Fig 2C, 2D, 2E, 2F (`tf_cv_single_AL_0033.pdf`, `tf_cv_2D_sidebar.pdf`,
`tf_tau_forest.pdf`, `tf_model_swap.pdf`); Table `tab:tf_sessions`
**Verdict:** 🟥 Four separate mismatches in one sentence. Poles: 1–5, not 1–3. Zeros: 0–4
(subject to `nz < np`), not 0–2. Delay: 0–3 samples (0–85.7 ms), not 0–5 samples (0–143 ms).
Selection: AIC **with an R2h escalation rule**, not AIC alone. `CLAUDE.md`'s "Locked-in
project decisions" carries the same stale bounds as the Methods — the code comment at
`imp_tf_run.m:55` records the change ("3 zeros / NO input delay; now 5 / 4 / 3 samples").
**Fix:** Rewrite as: "We swept 1–5 poles and 0–4 zeros subject to strict properness
(`nz < np`), with 0–3 samples of pure input delay (0–85.7 ms at 35 Hz), over a 0.5 s
post-onset fit window. Orders were selected by AIC; where the AIC-selected model reproduced
the measured impulse response with R² < 0.98, the order was re-selected as the most
parsimonious candidate within 0.002 R² of the best available, and we report which sessions
this affected." Also update `CLAUDE.md`'s locked-decision line.

---

## Q4 — Cross-validated R² of the LTI fit

**Code:** `utils/imp_tf_cv_session.m:53, 100-127, 183-271`, driven by
`impulse-analysis/imp_tf_cv.m`
**Computes:** defaults `nSplit = 100, seed = 7, minTrials = 6, nPre = 11, perAmp = true`. Per
split: trials are permuted **within each amplitude** and halved (stratified split); each half is
collapsed to an amplitude-normalised, amp²-weighted mean impulse response
(`local_build_h`, weights `w = uA.^2 / sum(uA.^2)` — "as the fit uses"); the **order is held
fixed** at the full-data `np/nz/nd` and only the coefficients are refitted per fold (header: "Re-
selecting order per fold would fold model-selection instability into the CV"). Both directions
are scored, so 100 splits give **200 folds**. Three scores per fold: `R2_out` (held-out,
amplitude-normalised, **no free scale** — "the prediction carries the model's gain, so a gain
error is a miss"), `R2_shape` (each trace peak-normalised first, gain removed), `R2_in`
(in-sample control on the training half). R² itself is `1 - SSE/SST` over samples finite in
both. Amplitudes with fewer than `2*minTrials = 12` trials are dropped from CV; sessions with
fewer than 2 usable amplitudes are skipped. Reported as **median across the 200 folds with
IQR**.
**Paper says:** `methods_rewrite.tex` §Transfer-function fitting: "We validated by
**leave-one-amplitude-out cross-validation**, fitting to all amplitudes but one and evaluating
the **normalized root-mean-square prediction error** at the held-out amplitude, and report
cross-validated R²." `results.tex:54` (Fig 2D caption): "per-session trial-cross-validated
held-out R² (median and interquartile range); pooled median across the four sessions,
R² = 0.86". `results.tex:64`: "The trial-cross-validated held-out R² had a pooled median of
0.86".
**Panels:** Fig 2C, 2D; supplementary `tf_cv_2D_endlabels.pdf`,
`tf_cv_shape_across_sessions.pdf`
**Verdict:** 🟥 The Methods describes a completely different validation from the one the
panels show. The panels are a **stratified random half-split over trials** (200 folds, order
fixed, R² = 1 − SSE/SST). Leave-one-amplitude-out does exist in the codebase
(`R2_loao`, reported in `imp_tf_run.m:277`) but it is a *different* diagnostic and is not what
Fig 2C/2D plot. "Normalized root-mean-square prediction error" is also not what is computed —
`local_r2` is a plain R², deliberately with no free gain. The caption and Results sentence
("trial-cross-validated", "median and interquartile range") are **correct** and match the code;
it is the Methods that is wrong.
**Fix:** Replace the Methods sentence with: "We validated by repeated stratified
cross-validation over trials: trials were split in half within each amplitude, the fit's
selected order was refitted on one half and scored on the amplitude-normalised mean response
of the other (both directions, 100 splits, 200 folds), with no free gain. We report the median
held-out R² with its interquartile range. Leave-one-amplitude-out fits are reported separately."

---

## Q5 — Power spectra

**Code:** `utils/controllerData.m:22-34`
**Computes:** one **session-level** spectrogram, not a per-trial estimate:
`spectrogram(dFk, hann(70), 35, 70, 35)` — 2 s Hann window, 1 s hop (50% overlap), 70-point
FFT, Fs = 35 Hz, so Δf = 0.5 Hz exactly. Then `S_bands = abs(S_spec(1:20,:)).^2` — the
**squared magnitude of the STFT**, with no `1/(Fs·Σw²)` scaling and no one-sided doubling, so
the units are (%ΔF/F)² in arbitrary STFT-squared units, **not** (%ΔF/F)²·Hz⁻¹.
`S_norm = S_bands ./ sum(S_bands,1)` gives within-trial power ratios over 0–10 Hz. Per trial the
spectrogram is *sliced*, not recomputed: columns `sc-6 : sc+dur+3` around the onset bin.
Band centres are `0.25, 0.75, … 9.75` Hz. Stored as `ncFreqPow`/`wcFreqPow` (absolute) and
`ncFreqSpec`/`wcFreqSpec` (ratio).
**Paper says:** `methods_rewrite.tex` §Power spectra: "We estimated power spectral density per
trial by Welch's method `%% FILL: window length, overlap, and taper.` and report absolute units
of (ΔF/F)² Hz⁻¹. No z-scoring or relative normalization was applied at any stage … Spectra were
averaged within session and then across sessions." Also listed in §Cross-session pooling as one
of the three pooled quantities.
**Panels:** **none.** No spectrum panel appears in `MANIFEST.txt`, and no sentence in
`results.tex` or any figure caption cites this subsection.
**Verdict:** 🟥 Three problems. (1) Units: the code never divides by `Fs·Σw²` and never doubles
the one-sided bins, so the stored quantity is a squared STFT magnitude, not a power spectral
density in (ΔF/F)²·Hz⁻¹. (2) "Per trial by Welch's method" misdescribes a single session-level
STFT that is then sliced per trial — morally Welch-like (2 s Hann, 50% overlap) but not a
per-trial periodogram average. (3) The subsection is **orphaned**: nothing in the manuscript
cites it and no panel shows a spectrum, yet §Cross-session pooling claims spectra were pooled
across the 15 sessions. The `%% FILL` for window/overlap/taper is still open.
**Fix:** Either delete the §Power spectra subsection and the "and power spectra" clause in
§Cross-session pooling (nothing depends on them), or — if a spectrum panel is to be added —
fill the FILL with "2 s Hann window, 50% overlap, Δf = 0.5 Hz" and change the unit claim to
"squared STFT magnitude, (ΔF/F)², in arbitrary units" unless the code is changed to normalise
by `Fs · Σw²`.

---

## Q6 — Pre-stimulus state factor 1: initial deviation

**Code:** `utils/f4_row2_pool.m:34`, `controller-analysis/f4_row2_quartiles.m:79`,
`controller-analysis/f4_error_decomp.m:48`, `controller-analysis/cl_rmse_factor_windows.m:72`
— all four agree.
**Computes:** `initdev = abs(dFk(:, c0) - ref)` with `c0 = 36` and `ref = -5`. `c0` is the
onset column of the `ncDfk`/`wcDfk` buffer (`controllerData.m:113` builds it as
`dFk(i-35 : i+35*(dur+1))`, so column 36 is exactly t = 0). This is the **absolute distance of
a single sample, the onset sample, from the reference**, per trial, in %ΔF/F.
`cl_rmse_factor_windows.m:11` documents it as "|dF/F(onset) - ref| [IDENTICAL to
cl_mse_factors]".
**Paper says:** `methods_rewrite.tex` §Pre-stimulus state measures: "The *initial deviation* is
the **cross-trial variance of ΔF/F over the 3 s preceding laser onset**."
**Panels:** Fig 4A, 4C, 4D (first tile); supplementary S3, S4
**Verdict:** 🟥 **Major.** The Methods describes a different quantity in every respect: a
variance where the code takes an absolute value; a cross-trial statistic where the code is
per-trial; a 3 s pre-onset window where the code uses the single onset sample; units
(%ΔF/F)² where the code is %ΔF/F. No code path anywhere in the repo computes the quantity the
Methods describes. This is the first-listed state factor and it owns the transient-window
claim (unique R² 0.29 → 0.004), so the definition is load-bearing.
**Fix:** Replace with: "The *initial deviation* is the absolute distance of ΔF/F from the
reference at the stimulation onset sample, |y(t_on) − r|, computed per trial."

---

## Q7 — Pre-stimulus state factor 2: motion energy

**Code:** two different definitions in two Figure-4 panels.
- `utils/f4_row2_pool.m:40-41` and `controller-analysis/f4_row2_quartiles.m:85-86`:
  `motion = mean(ncmotion(:, ws:we), 2)` — **plain mean, explicitly not rectified**
  ("PLAIN mean, no rectify" / "[user 2026-09-11]").
- `controller-analysis/f4_error_decomp.m:50`: `x2 = mean(wcmotion(:, ws:we).^2, 2)` —
  **mean of the squared** z-motion (its own header: "F2 motion = mean z-motion^2").
**Computes:** window in both cases is `ws = c0_mot - round(2*Fs) = 1` to
`we = c0_mot + round(dur*Fs) - 1 = 175`, with `c0_mot = 71` the onset column of the motion
buffer (`controllerData.m:114` builds `mv(i-70 : i+35*dur)`). That is **t = −2.000 s to
+2.971 s**, 175 samples — one sample short of the "+3 s / stim end" the comments claim. Input
is the z-scored motion trace, so the plain mean can be negative; the squared version cannot.
**Paper says:** `methods_rewrite.tex` §Pre-stimulus state measures: "*Motion energy* is the
mean z-scored motion signal over the trial, defined under Behavioral monitoring above."
**Panels:** Fig 4A, 4C (squared version), 4D second tile (plain-mean version); supplementary
S3, S4
**Verdict:** 🟥 The same named factor is computed two different ways in two panels of the same
figure: Fig 4C uses the mean **square**, Fig 4D uses the plain mean. The Methods definition
matches only 4D. Separately, the name "motion energy" describes the squared version but is
applied to both, and a plain mean of a z-scored signal is a signed quantity, not an energy.
The window is "−2 s to stim end" in the comments but ends at +2.971 s in the arithmetic, and
the Methods says "over the trial", which pins neither bound.
**Fix:** Decide one definition and use it in both panels. Then state it precisely: either
"mean squared z-scored motion over −2 s to stimulation end" (and keep the name "motion
energy"), or "mean z-scored motion over −2 s to stimulation end" (and rename it "motion
level"). Whichever is chosen, replace "over the trial" with the explicit window.

---

## Q8 — Pre-stimulus state factor 3: relative 2–4 Hz power

**Code:** `utils/cl_reldelta.m:46-77` (the canonical definition; "user decision 2026-09-08"),
called from `f4_row2_pool.m:45-47` and `f4_row2_quartiles.m:88-90` with
`opts = struct('pre',2,'post',3)`; the identical local copy is
`f4_error_decomp.m:203-207` (`local_bandpow`).
**Computes:** `rel = bandpow(seg, 2, 4) / max(bandpow(seg, 0.4, 10), eps)`, where `seg` runs
from `onsetCol - round(2*Fs)` to `onsetCol + round(3*Fs)` — **t = −2.000 s to +3.000 s, 176
samples**. `bandpow` is: linear detrend → Hann taper → `abs(fft(seg.*w)).^2` → keep the
one-sided half → sum bins with `lo <= f < hi`. The FFT is **not** normalised by `Fs·Σw²`, but
since the quantity is a ratio the normalisation cancels. Dimensionless, bounded in [0,1].
**Paper says:** `methods_rewrite.tex` §Pre-stimulus state measures: "*Relative 2–4 Hz power* is
the ratio of band power in 2–4 Hz … to total power in 0.4–10 Hz. Both were taken from a
one-sided periodogram of the readout after linear detrending and Hann tapering, over the
window from −2 s to trial end. A pre-stimulus-only window, −2 s to onset, gave the same result
and serves as a circularity control."
**Panels:** Fig 4A, 4C, 4D third tile; supplementary S3, S4
**Verdict:** ✅ Matches. Bands, detrend, taper, one-sided periodogram and window all agree, and
`cl_reldelta`'s `opts.post = 0` switch exists exactly for the stated circularity control
(documented in the function header).
**Fix:** none.

---

## Q9 — Pre-stimulus state factor 4: absolute low-frequency power

**Code:** `utils/cl_reldelta.m:50, 69, 76` (`delta_bnd = [1 4]`, returned as `comp.delta`),
consumed by `utils/f4_row2_pool.m:50` and `controller-analysis/f4_row2_quartiles.m:94` as
`adlog(cO.delta)` with `adlog = @(v) log10(max(v, eps))`; independently in
`controller-analysis/f4_error_decomp.m:35, 57` as `delta_bnd = [1 4]` then
`log10(Xdel)`.
**Computes:** `log10` of the **absolute 1–4 Hz** band power over the same −2 s to +3 s window,
same detrend/Hann/one-sided-periodogram construction as Q8. Unnormalised FFT power, so the
pre-log units are arbitrary ((%ΔF/F)² × window/taper factors); the log makes the scale
irrelevant to the z-scored regressions but not to any absolute statement.
**Paper says:** The Methods **does not define this factor at all** — §Pre-stimulus state
measures opens "We characterized cortical state before each trial in **three** ways." It is
nonetheless reported by name in `results.tex:122` (Fig 4C caption: "relative and absolute
2--4 Hz power carry the steady-state window ($0.10\rightarrow0.12$ and
$0.23\rightarrow0.35$)"), `results.tex:154`, `results.tex:123` (Fig 4D caption: "Initial
deviation and absolute power"), and in the supplementary captions S3
(`methods_rewrite.tex:1146`, "high absolute 2--4 Hz power") and S4
(`methods_rewrite.tex:1161`, "relative and absolute 2--4 Hz power entered together").
**Panels:** Fig 4A, 4C (fourth bar), 4D fourth tile; supplementary S3, S4
**Verdict:** 🟥 Two conflicts. (1) **Band:** the code integrates **1–4 Hz**, while every place
the manuscript names it says **2–4 Hz**. The relative factor really is 2–4 Hz (Q8); the
absolute one is not, and that is deliberate in the code (`delta_bnd` and `hi_bnd` are separate
constants in both `cl_reldelta.m` and `f4_error_decomp.m`). (2) **Omission:** the Methods
defines three state measures and the figures use four; the fourth carries the largest
steady-state unique R² in the paper (0.35), so it is the most load-bearing of the four.
**Fix:** Change "in three ways" to "in four ways" and add a paragraph: "*Absolute
low-frequency power* is the log₁₀ of absolute band power in 1–4 Hz over the same window and
from the same periodogram, entered as a magnitude-sensitive counterpart to the ratio."
Then change "absolute 2--4 Hz power" to "absolute 1--4 Hz power" at `results.tex:122`,
`results.tex:154`, `results.tex:196`, and in the S3 and S4 captions
(`methods_rewrite.tex:1146, 1161`).

---

## Q10 — Per-trial tracking RMSE

**Code:** `utils/controllerData.m:120` (OL) and `:144` (CL); window constants and
recomputations at `controller-analysis/fig3_olcl_stats.m:27-29`,
`controller-analysis/variance_mse.m:321-330, 431-452`, `utils/f4_row2_pool.m:31-32`
**Computes:** `seg = dFk(i : i+35*dur)` with `i` the onset sample and `dur = 3`, so **106
samples, t = 0 to +3.000 s inclusive**; `er_ncDfk(j) = norm(seg - d.ref) / sqrt(numel(seg))`
with `d.ref = -5`. Units %ΔF/F. The sample normalisation is the 2026-07-16 change and the
code carries the note in place: "Was norm() = ||e||_2 (un-normalised, = RMSE*sqrt(N))".
Windowed variants recompute directly as `sqrt(mean((M(:,a:b)-ref).^2, 2))`:
full `c0:c2 = 36:141` (0 to +3.000 s, 106 samples), transient `c0:c1 = 36:71` (0 to +1.000 s,
36 samples), steady-state `c1+1:c2 = 72:141` (+1.029 to +3.000 s, 70 samples).
**Paper says:** `methods_rewrite.tex` §Tracking cost, `eq:trial_cost`:
`RMSE_i = (1/√T)·||e_i||₂`, "so that reported values carry the units of ΔF/F". Windows named
in the same subsection: full 0 to +3 s, transient 0 to +1 s, steady-state +1 to +3 s.
`results.tex:81` (Fig 3E caption): "per-trial tracking RMSE (root-mean-squared error over the
3 s stimulation window, in %ΔF/F)".
**Panels:** Fig 3E, 3G, 3I; Fig 4C, 4D, 4G inputs; Fig 5G, 5I
**Verdict:** ✅ `eq:trial_cost` matches the code exactly, including the `1/√T`. The
`Ĵ(K) = (1/N)Σ RMSE_i` form matches the gain-grid usage and the Methods correctly flags (in a
`%%` comment) that a mean of norms is not the root of a mean of squares.
🟨 on one detail: "steady-state window, t = +1 to +3 s" is rendered three different ways in the
code — `72:141` (+1.029 to +3.000 s) in `fig3_olcl_stats.m` and `f4_error_decomp.m`,
`71:141` (+1.000 to +3.000 s) in `f4_row2_pool.m` and `f4_row2_quartiles.m`, and
`pre+36 : pre+105` (+1.000 to +2.971 s) in `f4_cl_reject_lmm.m`. None is wrong; they differ by
one sample at each end and are not interchangeable to three significant figures.
**Fix:** None required for the equation. Optionally unify the three steady-state window
definitions in code so the panels are exactly comparable, and state the sample count in the
Methods ("+1 to +3 s, 70 samples at 35 Hz").

### RMSE regeneration check (the 2026-07 sample-normalisation trap)

Every panel that reports RMSE was **regenerated after** the 2026-07-16 change, not relabelled:

| artefact | date | post-2026-07-16 |
|---|---|---|
| all 15 `data/*ctrl*.mat` caches (source of `er_ncDfk`/`er_wcDfk`) | 2026-07-16 15:25–15:40, two on 2026-07-30 | ✅ |
| `figures_v2/figure3/*.pdf` | 2026-09-30 / 2026-10-01 | ✅ |
| `figures_v2/figure4/*.pdf` | 2026-09-29 / 2026-09-30 | ✅ |
| `figures_v2/figure5/*.pdf` | 2026-09-29 | ✅ |
| `figures_v2/figure2/*.pdf` | 2026-09-30 | ✅ |

Two caveats found while checking:

- 🟥 **Stale loaders.** `controller-analysis/load_sessions.m:257` and `:283` still compute
  `er_ncDfk = norm(dFk(i:i+35*(dur))+5)` — **un-normalised, and with `+5` hard-coded instead of
  `d.ref`**. The same is true of `utils/controllerData_nomotion.m:99,110` and
  `utils/controllerData_pix.m:96,107`. These values are *not* stored back into
  `mouse.<f>.data` (no `data.er_ncDfk =` assignment exists in `load_sessions.m`), so no
  manifest panel currently consumes them — but they are a live trap for the next analysis that
  reaches for `er_ncDfk` from that loader.
- 🟨 **Pull-folder is one build stale.** `paper/figures_v2/figure3/panel_A–E.pdf` were
  regenerated 2026-10-01; the copies in `paper/figures_final/panels/figure3/` are dated
  2026-09-30 and `panel_B.pdf` differs in size (29971 vs 29970 bytes). Re-run
  `paper/figures_final/collect_final_panels.m`.

---

## Q11 — Across-trial variance

**Code:** single session `utils/analysisPlots_combined.m:224-225` (`var(pncDfk)`,
`var(pwcDfk)`); cross-session `controller-analysis/load_sessions.m:303-304, 315-316, 351-352`
then `controller-analysis/variance_mse.m:38-39`; ratio panel `variance_mse.m:72-89`;
LMM response `controller-analysis/fig3_olcl_stats.m:29, 97-104`
**Computes:**
- *Single session (3D):* `var(pncDfk)` — MATLAB column-wise variance over **trials**, N−1
  normalisation, on `controllerData.m`'s buffer `dFk(i-350 : i+35*(dur+3))`, so
  **t = −10 to +6 s**. Units (%ΔF/F)².
- *Cross-session (3F):* per session `var(pncDfk)` on `load_sessions.m`'s buffer
  `dFk(i-105 : i+35*(dur+3))`, **t = −3 to +6 s**, then an **unweighted arithmetic mean across
  sessions** (`mean(Mvarnc)`), sessions not weighted by trial count.
- *Ratio panel (3H):* windows `pre = [-3, 0)`, `early = [0, 1]`, `late = (1, 3]`,
  `post = (3, 6]`. Per session, `mean(var_OL over window) / mean(var_CL over window)`, then
  the panel's bold line is the **arithmetic mean of those per-session ratios**.
- *The p-value on the panel:* **not** the signed-rank. `variance_mse.m:122` overrides the
  signed-rank fallback with `G3.var_early.lmm_p` / `G3.var_late.lmm_p`. In
  `fig3_olcl_stats.m:97-100` the LMM response is
  `log(mean((M(:,a:b) - mean(M(:,a:b),1)).^2, 2) + eps)` — the **log of the per-trial mean
  squared deviation from the across-trial mean trace**, a dispersion proxy, not a variance.
  The signed-rank companion does use the classic per-session across-trial variance.
**Paper says:** `results.tex:80` (Fig 3D caption) "Cross-trial variance of ΔF/F as a function
of time … in a representative session"; `:82` (3F) "averaged across all 15 sessions";
`:84` (3H) "Ratio of across-trial variance (open-loop / closed-loop) for each session, in four
windows … bold line, across-session mean … a session-aware linear mixed model on the
**per-trial windowed variance** (∼cond + (1+cond|session) + (1|mouse)) gives p = 2×10⁻⁷ and
5.6×10⁻¹⁴". `methods_rewrite.tex` §Statistics: "The same model was applied to per-trial
windowed variance."
**Panels:** Fig 3D, 3F, 3H; Fig 5E (sine, `var(traces,0,1)` at
`bilateral/sine_ff_plots_combined.m:267`)
**Verdict:** 🟨 The LMM response is not "per-trial windowed variance" — a single trial has no
variance. It is the **log** of each trial's mean squared deviation from the across-trial mean
trace, which the code's own header calls "a mixed dispersion test". The caption and the
Methods both omit the log transform and the fact that this is a dispersion proxy rather than a
variance, which matters because the reported coefficient is then a log-ratio, not a difference
of variances. Also 🟨: the panel's bold line is an **arithmetic mean of per-session ratios**,
a biased estimator of a ratio — the caption says "across-session mean" without saying mean of
what, and the cross-session variance trace (3F) is an unweighted session mean, so a 16-trial
session counts as much as a 150-trial one.
**Fix:** In the Fig 3H caption and §Statistics, replace "per-trial windowed variance" with
"the log of each trial's mean squared deviation from the condition's across-trial mean trace
(a mixed dispersion test), with the per-session across-trial variance tested by Wilcoxon
signed-rank as a companion". In the 3F and 3H captions add "unweighted mean across sessions".

---

## Q12 — Unique-R² error decomposition

**Code:** `controller-analysis/f4_error_decomp.m:126-152` (the `'sep'` mode, which is the
main-text panel), helper `fitR2` at `:37-38`, bar/error-bar drawing at `:158-196`
**Computes:** pooled over CL trials from every motion-capable session (`minTr = 12` per session
for the per-session dots), predictors z-scored, OLS. The four bars are **not** drop-one terms
from a single four-factor model. Columns are `1 = init, 2 = motion, 3 = rel 2–4, 4 = abs δ`
and `sepU` is:

```
init   = R²{init,motion,rel} − R²{motion,rel}
motion = R²{init,motion,rel} − R²{init,rel}
rel    = R²{init,motion,rel} − R²{init,motion}
abs    = R²{init,motion,abs} − R²{init,motion}
```

So `init` and `motion` are unique **within the relative-δ model only** (abs δ never enters
their model), and the two δ terms each get their unique R² over the *same* init+motion base but
in separate three-factor models. The reason is in the code: "rel-2-4 and abs-delta are
collinear, so a single 4-factor model makes them cannibalise each other (abs wins, rel -> 0)"
(`f4_error_decomp.m:127-128`). Windows: early `eE = c0 : c0+35` = 0 to +1.000 s (36 samples),
late `lL = c0+36 : c0+105` = +1.029 to +3.000 s (70 samples). Outcome
`y = sqrt(mean((wcDfk(:,win) - ref).^2, 2))`. The error bars on the bars are **±1 SD across
sessions** (`f4_error_decomp.m:180-186`, "replaces scatter (user 2026-09-29)"), not SEM and not
a CI. The conventional four-factor drop-one decomposition is also computed, under
`mode = 'both'`, and exported to supplementary.
**Paper says:** `results.tex:122` (Fig 4C caption): "Unique R² of each factor for the
closed-loop error, resolved by window (transient 0–1 s, light; steady-state 1–3 s, dark)" —
with no statement of the model structure and no statement of what the error bars are.
`methods_rewrite.tex` does not describe the decomposition anywhere. The `'sep'` scheme *is*
described, correctly, but only in the supplementary S4 caption
(`methods_rewrite.tex:1163-1166`: "The main text (Fig. 4C) enters each low-frequency term in
its own initial-deviation-plus-motion base").
**Panels:** Fig 4C; supplementary S4
**Verdict:** 🟨 The caption's bare "Unique R² of each factor" invites the reader to assume one
model with four drop-one terms — which is precisely the model the code rejects, and which gives
a different answer (rel → ~0). The only place the real scheme is stated is a supplementary
caption, which the main-text caption does not point to. Error bars are undefined in the
caption. The Methods has no §Error decomposition at all.
**Fix:** Add to the Fig 4C caption: "Each low-frequency term's unique R² is taken over the same
initial-deviation-plus-motion base in its own three-factor model, because the two are
collinear (Fig. S4); initial deviation and motion are unique within the relative-power model.
Bars, pooled estimate; error bars, ±1 SD across sessions." Add a short §Error decomposition to
the Methods carrying the same four expressions and the window definitions.

---

## Q13 — Session-aware linear mixed model (state dependence)

**Code:** `utils/f4_row2_fit.m:21-30` (single source, shared by `f4_row2_stats.m` and
`f4_row2_quartiles.m`); pooled table built by `utils/f4_row2_pool.m`
**Computes:** `T.xw` = the state **centred within session**, then divided by
`std(T.xw)` — the **pooled SD of all centred values**, one global scale, not a per-session SD.
`T.cond` reordered to `{OL, CL}` so `cond_CL` is the contrast. Model:
`fitlme(T, 'y ~ cond*xw + (1+cond|sess) + (1|mouse)')`, falling back to
`(1|sess) + (1|mouse)` if the random-slope model fails to converge (recorded in
`R.randslope`). The random slope is on **condition**, not on the state. The response `y` is
the **raw** rejection RMSE in %ΔF/F over the settled window (`f4_row2_pool.m:31-32`), *not*
z-scored. Three coefficients are read out: `gap` = `cond_CL` (OL−CL gap at mean state),
`slope` = `xw` (the OL state slope), `dec` = `cond_CL:xw` (the decoupling interaction).
Sessions enter a state only with ≥8 finite trials in **each** condition
(`f4_row2_pool.m:57`).
**Paper says:** `methods_rewrite.tex` §Statistics: "`RMSE ∼ condition × state + (1 + condition
| session) + (1 | mouse)`, with the state centered and scaled within session. From that model
we read two quantities: **the condition main effect on the open-loop level**, which we report
as the effect of state on *predictability* of the disturbance, and the condition-by-state
interaction, which we report as its effect on *controllability*."
`results.tex:123` (Fig 4D caption) and `results.tex:213` carry the same two-property reading.
**Panels:** Fig 4D (star), Fig 4 forest (`f4_row2_stats.m`)
**Verdict:** 🟥 The Methods maps *predictability* onto "the condition main effect", but the
condition main effect (`cond_CL`) is the OL−CL **gap at mean state** — it has no state in it
and cannot carry a claim about how state affects predictability. The quantity the Results
actually reports as predictability ("the trend of the uncontrolled error", `results.tex:213`)
is the **state main effect** (`xw`, the code's `R.slope`). The caption gets it right; the
Methods sentence names the wrong coefficient.
🟨 on two further details: "scaled within session" is not what the code does — it centres
within session and then applies a single **pooled** SD, so the coefficient is "per pooled SD",
not "per within-session SD"; and the panel plots **within-session z-scored** RMSE
(`f4_row2_quartiles.m:95-96`) while the star comes from a model fitted on **raw** RMSE, so the
plotted effect size and the tested effect size are on different scales.
**Fix:** In §Statistics change "the condition main effect on the open-loop level" to "the state
main effect, which gives the open-loop slope", and change "centered and scaled within session"
to "centered within session and scaled by the pooled standard deviation". Add to the Fig 4D
caption: "Panel y-axis, RMSE z-scored within session across the pooled open- and closed-loop
trials; the mixed model is fitted to raw RMSE."

---

## Q14 — Contralateral → ipsilateral predictor R²

**Code:** `controller-analysis/ctrl_ols_ol_stimblind.m:30-85` (configuration),
`:273-290` (predictor mode), `:330-343` (ridge path), `:453-459` (reported R²),
`:465-477` (quality gate); gate constant `utils/ctrl_r2_floor.m:20`
**Computes:** `ctrl_pred_tag()` returns `'ridge'` and `f4_contra_model.m:23` **asserts** it
(`assert(strcmp(pmode,'ridge'),'need ridge predictor')`). The ridge path keeps the **whole
contralateral grid** — "predictor mode = RIDGE: whole grid kept, lambda chosen from catch
windows" (`:290`) — with λ selected from **laser-off catch windows** by
`ctrl_ridge_path`. `R2_te = RPATH.R2te_star` is the **held-out R² on spontaneous frames**
from a temporal train/test split (`:453-454`: "held-out spont R^2"), with the target detrended
when the train/test target means drift (`:233`). The affected-pixel rule is
`det_method = 'least_affected'` (PRIMARY since 2026-08-10), which keeps the **K least-affected**
pixels with K chosen per session by `ctrl_select_k`; the old absolute "exclude pixels near the
stimulation site" cut (`'dip'`, threshold 1.33) was **retired** because "the cut deleted 70–99%
of the grid … and only 1 of 13 sessions cleared `ctrl_r2_floor()`" (`:44-51`). The quality gate
is `R2_te >= ctrl_r2_floor()`, and `ctrl_r2_floor.m` returns **0.85** ("SINGLE SOURCE OF TRUTH
for the quality gate (user, 2026-08-05) … History: 0.90 requested, then set to 0.85").
**Paper says:** `methods_rewrite.tex` §Contralateral prediction: "we fitted an **ordinary least
squares** predictor from a grid of contralateral pixels … **Pixels near the homotopic
stimulation site were excluded**, because direct optical cross-talk contaminates their apparent
coupling. The predictor was fitted on a target-independent train-test split of spontaneous
frames, and we confirmed that it generalized to held-out pre-stimulus windows."
§Session and trial selection: "Sessions entered the decomposition only if the spontaneous-data
predictor reached **R² > 0.3**." `results.tex:225`: "contralateral→ipsilateral R² = 0.85 open
loop and 0.89 closed loop; representative session". `results.tex:125` (Fig 4F caption):
"trial average for a representative session (R²_te = 0.75)".
**Panels:** Fig 4E (`f4_kernel_map.pdf`), Fig 4F (`f4_agl.pdf`)
**Verdict:** 🟥 Three conflicts. (1) **Estimator:** the deployed predictor is **ridge** with λ
chosen from laser-off catch windows, not OLS; `f4_contra_model.m` refuses to run on anything
else. (2) **Pixel selection:** the Methods describes the retired absolute exclusion rule; the
code keeps the K least-affected pixels (and in ridge mode keeps the whole grid, reporting the
residual bleed rather than assuming it away). (3) **Gate:** the Methods says R² > 0.3; the
code's single source of truth is **0.85**, and the difference is not cosmetic — the 0.85 gate
is what stops a weak Global from manufacturing a large Local.
🟨 additionally: `results.tex:125` annotates the panel with `R²_te = 0.75` while
`results.tex:225` quotes 0.85 / 0.89 for the same predictor's generalisation. `R2_te` in the
code is the **held-out spontaneous** R², so whatever the 0.85/0.89 pair is, it is a different
number from the one printed on the panel. (`NUMBERS.md` §5.4 flags the same cluster.)
**Fix:** Rewrite §Contralateral prediction: "we fitted a ridge-regularised linear predictor
from the contralateral pixel grid to the ipsilateral readout on spontaneous, laser-off frames,
with the ridge penalty chosen from laser-off catch windows and each pixel z-scored on the
training partition. Rather than excluding pixels near the homotopic site by an absolute
criterion, we retained the K least stimulus-affected pixels per session, K being the smallest
count that still cleared the predictor-quality gate, and report the residual bleed." Change
"R² > 0.3" to "R² ≥ 0.85 on held-out spontaneous frames". Reconcile 0.75 / 0.85 / 0.89 and say
for each whether it is held-out spontaneous R² or something else.

---

## Q15 — The A = G + L decomposition

**Code:** `controller-analysis/ctrl_ols_ol_stimblind.m:500-508` (deploy);
`controller-analysis/f4_contra_model.m:23-26, 42-46` (panel)
**Computes:** per trial, `A_tr(j,:) = ytrace(onF(j)+rel)` and
`G_tr(j,:) = Gall(onF(j)+rel)` over `rel = -round(pre_s*Fs) : post` with `pre_s = 1.0` s; both
are **baseline-subtracted per trial** over `bwin` (`bl = @(M) M - mean(M(:,bwin),2)`), then
`L_tr = A_tr - G_tr` by definition, and the panel plots the trial averages
`Aa, Gg, Lo`. Target is `data.dFk` (`target_mode = 'canonical'`, chosen because the legacy
`y_full` reconstruction is "~1.5x its amplitude, so ||A-ref|| in y_full units is invalid"),
so A and G share the ref frame. Exemplar session is pinned: `tag = 'AL_0033_0415_e2'`. The
`R²_te = %.2f` printed on the panel is `O.R2_te` loaded straight from the stimblind cache —
i.e. the held-out **spontaneous** R² of Q14, annotated next to a stimulation-trial prediction.
**Paper says:** `methods_rewrite.tex` §Contralateral prediction: "This gives the *Global*
component G(t) … and by subtraction the *Local* component L(t) = A(t) − G(t) … We tested the
decomposition by reconstructing A as G plus the **leave-one-trial-out average local response**,
and report **cross-validated R² over the 0–3 s window** against two nested nulls, Global alone
and trial-average alone." `results.tex:235`: "the actual response was well reconstructed as the
Global disturbance plus the average local response (cross-validated R² = 0.85 open loop, 0.78
closed loop)". `results.tex:125` (Fig 4F caption): "(R²_te = 0.75)".
**Panels:** Fig 4F
**Verdict:** 🟥 The decomposition itself (`L = A − G`, baseline-subtracted per trial) matches
and is exact by construction. But the R² the panel carries is **not** the R² the Methods
describes: `R2_te` is the held-out spontaneous-frame R² of the ridge predictor, while the
Methods describes a leave-one-trial-out reconstruction of A over the 0–3 s window against two
nested nulls. The panel annotation and the Methods sentence are about different computations,
and a reader will read the 0.75 on the panel as the reconstruction R².
⬜ **Could not trace:** the leave-one-trial-out reconstruction R² against "two nested nulls,
Global alone and trial-average alone", and the values 0.85 / 0.78 at `results.tex:235`. No
script in `controller-analysis/` or `utils/` was found that computes a LOTO reconstruction of
A with nested-null comparison; the grep over the repo for the stimblind cache
(`ctrl_ols_ol_stimblind`) returns 33 consumers and none of them implements it. It may live in
an uncommitted script, in a cached `.mat` only, or the sentence may describe an analysis that
was planned and not run. **This needs the user to point at the generator before the sentence
can stand.**
**Fix:** Either locate and cite the LOTO script and label the panel with *that* R², or change
the Fig 4F annotation and its caption to say explicitly "R² of the contralateral predictor on
held-out spontaneous frames", and either substantiate or delete the nested-null sentence at
`results.tex:235`.

---

## Q16 — Rejection ratio RR

**Code:** `controller-analysis/f4_cl_reject_lmm.m:13, 26-37, 49-52` (the number);
`controller-analysis/f4_cl_reject_panel.m:14-23, 52-53` (the panel)
**Computes:** window `wr = pre + round(1*Fs) + 1 : pre + round(3*Fs)`, i.e. with the onset at
index `pre+1`, **t = +1.000 s to +2.971 s, 70 samples**. Numerator
`sum((Acl(:,wr) - ref).^2, 2)` with `ref = -5`; denominator `sum(D(:,wr).^2, 2)` where
`D = (Gcl − per-trial baseline) − gdipOL` and
`gdipOL = mean(mean(Gr_ol(:,wr), 2))` is a **single scalar**, the grand mean over OL trials and
over the settled window of the baseline-subtracted OL Global. That scalar subtraction is what
"leak-corrected" means. Reach gate: `abs(mean(mean(Acl(:,wr),2)) - (-5)) <= 1.5`; sessions
failing it are reported but excluded. Only `isfinite(rr) & rr > 0` trials enter. Test:
`fitlme(T, 'logRR ~ 1 + (1|mouse) + (1|mouse:sess)')`, one-sided on the intercept; the panel's
blue band is `exp(est) ± 1.96·se` back-transformed; per-session markers are geometric mean
`exp(mean(log RR))` with `exp(mean ± 1 SD)` whiskers on a log y-axis.
**Paper says:** `methods_rewrite.tex` `eq:rr`: `RR = ||A − r||²/||D||²`, "Both were evaluated
over the steady-state window, 1–3 s"; "the denominator the energy of the disturbance, taken as
the contralaterally predicted excursion referenced to its own no-laser baseline and
leak-corrected". §Statistics: "`log RR ∼ 1 + (1|mouse) + (1|mouse:session)`, one-sided on the
intercept, and report the geometric mean of RR with its 95% confidence interval".
§Session and trial selection: "two sessions whose settled mean never came within 1.5 %ΔF/F of
the reference were excluded … AL_0033 2025-02-12 and AL_0051 2026-07-29". `results.tex:207`:
"RR = 0.58 (95% CI [0.48, 0.71]) … one-sided p = 2.1×10⁻⁸, n = 11 sessions".
**Panels:** Fig 4G
**Verdict:** ✅ on the formula, the model, the one-sided test, the geometric-mean reporting and
the reach gate — including the two named excluded sessions, which match the code comment
exactly.
🟨 on two points: "leak-corrected" is never defined, and what the code does is subtract one
scalar, the grand-mean settled level of the open-loop Global — a reader cannot reconstruct that
from the word alone. And the window is +1.000 to +2.971 s, not +1 to +3 s (see Q10's
three-renderings note); the per-session whiskers are ±1 SD in log space, which the caption does
not state.
**Fix:** In §Contralateral prediction add: "Leak correction subtracts from the closed-loop
Global trace a single scalar, the grand mean of the baseline-referenced open-loop Global over
the same settled window, so that the residual stimulus-locked component common to both
conditions is not counted as disturbance." Add "points, per-session geometric mean; whiskers,
±1 SD in log space; band, mixed-model geometric mean with 95% CI" to the Fig 4G caption.

---

## Q17 — 1 Hz phase lag

**Code:** `bilateral/sine_ff_plots_combined.m:396-407` (single session, Fig 5H);
`bilateral/sine_ff_across_sessions.m:106` (across sessions, Fig 5J);
per-trial cross-correlation companion at `sine_ff_across_sessions.m:95-99`
**Computes:** a three-column design `Xf = [1, sin(2π·f₀·t), cos(2π·f₀·t)]` with `f₀ = sn.hz`
(1 Hz), solved by `Xf\y` (OLS), giving `fPh(y) = atan2(cos-coef, sin-coef)`. Applied to the
**trial-averaged** response `mu = mean(traces{m}(:, iRef), 1)` and the **trial-averaged**
reference `mr = mean(refs{m}, 1)` over `iRef = nPre+1 : nPre+1+round(dur*fs)`, i.e. t = 0 to
`dur`. Lag = `mod(fPh(mr) - fPh(mu) + π, 2π) - π`, converted to degrees — so positive means
the response lags the reference. Because the fit is on the trial average there is exactly
**one number per mode per session and no uncertainty estimate**. Gain
`fAmp(mu)/fAmp(mr)` is computed alongside but not plotted. The dashed lookahead marker is
`prevLook = 360 * sn.hz * input_params(:,8) / fs` — 5 samples at 35 Hz = 51.4°. The separate
per-trial estimate (`poolLAGf`) is a constrained normalised cross-correlation,
`xcorr(T-mean(T), R-mean(R), ±round(fs/hz/2), 'normalized')`, argmax in **samples**.
**Paper says:** `results.tex:271` (Fig 5H caption): "Phase lag relative to the reference from a
1 Hz fundamental fit to the trial average; dashed line marks the preview lookahead (51° at
1 Hz)". `results.tex:280`: "lagged the reference by 60° under open loop and by 36° under closed
loop; adding preview moved both to approximately zero (5° and −9°) … a five-sample preview at
35 Hz corresponds to 143 ms, or 51° at the 1 Hz drive frequency, and the measured open-loop
correction across all pooled trials was 5.0 samples (51.4°, median)."
`results.tex:272` (Fig 5I–K caption): "at n = 3 sessions no session-level significance test is
possible".
**Verdict:** ✅ The caption pins the operation exactly ("1 Hz fundamental fit to the trial
average"), the 51° lookahead arithmetic is reproduced by the code, and the "5.0 samples
(51.4°, median)" sentence correctly attributes the pooled per-trial number to the
cross-correlation estimator rather than the fundamental fit. The n = 3 caveat is stated.
**Fix:** none.

---

## Q18 — Sine error spectral partition (constant / drive-frequency / broadband)

**Code:** `bilateral/sine_ff_error_decomp.m:48-80`
**Computes:** `N = round(dur*fs)` samples from onset — exactly `dur` seconds, so with a 1 Hz
drive over 4 s the drive lands on FFT bin `k0 = round(hz*N/fs) + 1` and Parseval is exact. Per
trial: `Pe = pw(fft(y - r)/N)` with
`pw = @(X) [abs(X(1))^2, 2*abs(X(2:nH-1)).^2, abs(X(nH))^2]` — a correctly doubled one-sided
power whose sum equals `mean(e²)` exactly. The three terms are `Pe(1)` (the **squared mean
error**, i.e. the constant offset), `Pe(k0)` (the drive bin), and
`sum(Pe) - Pe(1) - Pe(k0)` (everything else). Accumulated per mode and divided by the trial
count, then **averaged over the three sessions** (`mean(DC(:,m))` etc.). Units (%ΔF/F)².
**Paper says:** `results.tex:284`: "Because the stimulation window contains exactly four cycles
of the drive, per-trial squared error partitions without loss into a constant-offset term, a
term at the drive frequency, and the remaining broadband term. Averaged over the three
sessions, preview reduced the error at the drive frequency roughly threefold in every
comparison (OL 3.14 → OL+p 0.89; CL 1.78 → CL+p 1.22 (%ΔF/F)²), while feedback reduced the
broadband term (10.55 → 6.62 from OL to CL)."
**Panels:** **none.** `sine_ff_error_decomp.m` is not referenced in `MANIFEST.txt` and its own
header line 3 reads: "**PARKED 2026-08-12** (user: 'table this for now'). **Nothing here is a
registered paper panel.**"
**Verdict:** 🟨 The operation matches the text precisely — the partition is exact, the
"four cycles" justification is the code's own, and "averaged over the three sessions" is what
the code does. Two things are not clean. (1) **Provenance:** a paragraph of the Results rests
entirely on a script the repo marks as parked and unregistered, with no figure. Nothing
guarantees the quoted values were produced by the committed version. (2) **Selective
reporting:** the partition has three terms and the Results reports two. The code header states
that the **offset term is the largest** ("40–65% of total error power sits there") and that
CL+preview has the lowest DC error in 3/3 sessions — a result that supports the paragraph's
own conclusion and is omitted. The sentence "Closed-loop control with preview was the only mode
to engage both" is also weaker than the code header's recorded finding ("CL+preview dominates
plain CL on BOTH axes … only OL+p and CL+p are non-dominated -- in all 3 sessions").
🟨 also: the decomposition window is `i0 : i0+N-1` (N samples) while panel 5G's per-trial RMSE
uses `i0 : i0+round(dur*fs)` (N+1 samples), so the code's claim that the bar total equals
"the same quantity as panel 5G" is true only up to one sample.
**Fix:** Either promote this to a registered panel (the header nominates `[TRADE]` at
5.4 × 5.0 cm) and add it to `MANIFEST.txt` and `PAPER.md`, or add a Methods paragraph defining
the partition so the Results values are reconstructable without a figure. Report the offset
term's values alongside the other two. Align the two windows to N or N+1 samples.

---

## Cross-cutting findings (not tied to one quantity)

- 🟥 **Motion exclusion is described but not applied.** `methods_rewrite.tex` §Session and
  trial selection: "Trials whose peak motion energy exceeded 1.5 standard deviations above the
  session mean were excluded, removing **n** of **n** trials. Results are reported with and
  without this exclusion." No motion exclusion exists in `utils/controllerData.m`,
  `controller-analysis/load_sessions.m`, `utils/f4_row2_pool.m`,
  `controller-analysis/f4_error_decomp.m` or `controller-analysis/fig3_olcl_stats.m` — grep for
  `motThresh` across `utils/` and `controller-analysis/` returns only
  `f4_lowfreq_examples.m:21` and `trial_state_mse.m:22`, neither of which generates a manifest
  panel, and `trial_state_mse.m:88` applies `abs(mean z-motion) <= 1.5`, which is not "peak
  motion exceeding 1.5 SD above the session mean". So no Figure 3, 4 or 5 panel has motion
  exclusion applied, and the "with and without" comparison the Methods promises is not
  computed for them.
  **Fix:** delete the rule, or apply it and fill the counts.
- 🟥 **Figure 5 E/F are swapped between the caption and the panel files.** `MANIFEST.txt`
  lists `sine_5E_rmse_time_*.pdf` and `sine_5F_variance_*.pdf`; `results.tex:270` reads
  "**E:** Across-trial variance over time. **F:** RMSE over time", and the body text at
  `results.tex:278` follows the caption's convention. Known (RESEARCH.md 2026-09-30 logs the
  fact-check) but still unresolved in the `.tex`.
- 🟨 **Figure 3A caption colour.** `results.tex:77` says "closed-loop (**green**)"; the locked
  project scheme (and panel B's own caption at `:78`) is CL = blue, green = CL+preview.
- 🟨 **`MANIFEST.txt` does not cover the supplementary figures the manuscript includes.**
  `methods_rewrite.tex` S1–S4 pull `spont_variance.pdf`, `batch_mean_stationarity.pdf`,
  `f4_exemplars_sessions.pdf`, `f4_decomp_unique_both/rel/abs.pdf`, none of which is listed in
  the `[supplementary]` section (which holds only `tf_cv_2D_endlabels.pdf` and
  `tf_cv_shape_across_sessions.pdf`, both flagged in the manifest as having no `figures_v2`
  export). The "a panel is final iff it is listed here" rule is therefore not holding for the
  supplement.
- 🟨 **`CLAUDE.md`'s locked TF sweep is stale** — "sweep 1–3 poles, 0–2 zeros, 0–5 sample delay;
  AIC selection" matches the Methods, and both are superseded by the code (Q3).

---

## Resolution queue

Most load-bearing claim first.

| # | flag | quantity | one-line |
|---|---|---|---|
| 1 | 🟥 | Q6 initial deviation | Methods defines it as cross-trial variance over 3 s pre-onset; code is `\|y(t_on) − r\|`, a per-trial single-sample absolute deviation. Nothing in the repo computes the Methods version. Owns the transient-window claim. |
| 2 | 🟥 | Q14 contra→ipsi predictor | Methods says OLS with stimulation-site pixels excluded and an R² > 0.3 gate; code is ridge on the retained K least-affected pixels with the gate at **0.85**. |
| 3 | 🟥 | Q9 absolute low-frequency power | Code integrates **1–4 Hz**; manuscript says 2–4 Hz in five places. The factor is also missing from the Methods, which defines only three states while the figures use four. |
| 4 | 🟥 | Q4 cross-validated R² | Methods says leave-one-amplitude-out with NRMSE; panels are a 200-fold stratified trial half-split scored by plain R². Caption and Results are right; Methods is wrong. |
| 5 | 🟥 | Q3 TF order sweep | Poles 1–5 not 1–3, zeros 0–4 not 0–2, delay 0–3 samples not 0–5, and selection is AIC **plus an R2h escalation rule**. |
| 6 | 🟥 | Q7 motion energy | Computed two different ways within Figure 4 (mean square in 4C, plain mean in 4D); Methods matches only 4D; window ends at +2.971 s, not "over the trial". |
| 7 | 🟥 | Q15 A = G + L reconstruction R² | Panel annotates the held-out **spontaneous** predictor R²; Methods and `results.tex:235` describe a leave-one-trial-out reconstruction over 0–3 s against two nested nulls — **generator not found (⬜)**. |
| 8 | 🟥 | Q13 LMM coefficient mapping | §Statistics attributes *predictability* to the condition main effect; it is the state main effect. |
| 9 | 🟥 | Q1 evoked suppression | `eq:inhib_energy` window is one sample early (0–171 ms vs the code's 28.6–200 ms); `results.tex:51,62` still say "inhibition energy … integrated". |
| 10 | 🟥 | Q2 dose-response | Slopes are fitted and quoted in %ΔF/F per **Volt**; the Results states the amplitude range in mW. |
| 11 | 🟥 | Q5 power spectra | Squared STFT magnitude presented as a Welch PSD in (ΔF/F)² Hz⁻¹; subsection is orphaned (no panel, no citation) and its FILL is open. |
| 12 | 🟥 | cross-cutting | Motion exclusion rule stated in §Session and trial selection is not applied in any manifest panel's pipeline. |
| 13 | 🟥 | cross-cutting | Figure 5 E/F swapped between caption/body text and panel filenames. |
| 14 | 🟥 | Q10 (loaders) | `load_sessions.m:257,283` (and `controllerData_nomotion/_pix`) still compute un-normalised `norm(... + 5)`; unused by current panels but a live trap. |
| 15 | 🟨 | Q12 unique R² | The main-text bars come from the `'sep'` scheme, not a single four-factor drop-one model; stated only in the S4 caption. Error bars (±1 SD across sessions) undefined. |
| 16 | 🟨 | Q11 variance LMM | "Per-trial windowed variance" is actually the **log** of each trial's mean squared deviation from the across-trial mean trace. |
| 17 | 🟨 | Q18 spectral partition | Sourced from a script the repo marks PARKED and unregistered; the largest of the three terms (offset) is not reported. |
| 18 | 🟨 | Q13 (scaling) | "Scaled within session" is really centred within session then divided by one pooled SD; panel plots z-scored RMSE while the model is fitted to raw RMSE. |
| 19 | 🟨 | Q16 RR | "Leak-corrected" never defined (it is subtraction of one scalar, the grand-mean settled OL Global); window is +1.000 to +2.971 s. |
| 20 | 🟨 | Q2 (R²) | Dose-response R² is computed on 4–6 per-amplitude means, not trials; no CI quoted although `f2_slope_ci.m` produces one. |
| 21 | 🟨 | Q10 (windows) | "Steady-state 1–3 s" is rendered three incompatible ways across panels (72:141, 71:141, pre+36:pre+105). |
| 22 | 🟨 | Q11 (ratios) | Fig 3F/3H bold lines are unweighted arithmetic means across sessions (of variances and of per-session ratios respectively); captions say only "across-session mean". |
| 23 | 🟨 | cross-cutting | `MANIFEST.txt` `[supplementary]` does not list the four supplementary figures the manuscript actually includes. |
| 24 | 🟨 | cross-cutting | `paper/figures_final/panels/figure3/` is one build behind `figures_v2` (panel_B.pdf differs); re-run `collect_final_panels.m`. |
| 25 | 🟨 | cross-cutting | `results.tex:77` calls closed-loop green; the locked scheme is CL = blue. |
| 26 | ⬜ | Q15 | LOTO reconstruction R² (0.85 OL / 0.78 CL) against Global-alone and trial-average-alone nulls: no generating script found in `controller-analysis/` or `utils/`. Needs the user to name the script, or the sentence goes. |

<!-- Audited 2026-10-01. Code read before text, per the rule at the top. No value was recomputed; verdicts concern operations, not numbers. -->
