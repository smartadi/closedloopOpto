# stats_v2 CHOICES

Decisions taken where SPEC.md was silent or ambiguous (one line each).

1. **Active channel tie**: If two inpVals* channels share the largest 99.9th percentile, take the first of inpVals, inpVals594, inpVals638. Only m15 ties (inpVals and inpVals594 are identical arrays), so the choice has no effect.
2. **Command time base**: All channels use d.inpTime (spec). In the new builds d.inpTime594 and d.inpTime638 were read only to confirm they are identical to d.inpTime (they are).
3. **dFk / timeBlue length mismatch**: Spec says equal lengths; m8 (−1), m13 (−75) and m14 (−11 frames) are shorter. Primary analysis maps dFk[i] to timeBlue[i] (start-aligned, the literal reading); frames without dFk are NaN (none fall in a window). Because the m14 alignment check contradicts this, a sensitivity run with m14 end-aligned (shift 11) is reported in CHECKS §8 and sensitivity_m14_align.csv; it does not replace the primary numbers.
4. **motion length mismatch**: m10 and m11 d.motion is 1 frame short; start-aligned to timeBlue (no window reaches the missing frame).
5. **has_motion**: A session has motion iff max(d.motion) > min(d.motion) over the whole session.
6. **Onset frame indexing**: Internally 0-based. trials.csv reports onset_frame 1-based (MATLAB convention, comparable with kk); trial_index is the 1-based input_params column; val_index is 0-based within the validation block.
7. **Validation block**: Exactly the last N input_params columns (and the matching stimStarts entries) per the table, even where controller parameters vary inside it (m4).
8. **Fs for spectra**: Fs = 35 Hz (spec) for the PSD frequency axis and normalisation, although the measured frame rate is 35.088 Hz. Windows are defined in samples, so only the spectral band edges are affected (by 0.25 %).
9. **Hann taper**: scipy.signal.windows.hann(N, sym=True): symmetric, zero at both ends (same as MATLAB hann(N)).
10. **Detrend**: scipy.signal.detrend(type='linear'): least-squares straight-line removal over the 175-sample segment.
11. **nfft**: max(8192, next power of 2 ≥ 8N); for N = 175 this is 8192.
12. **One-sided PSD**: rfft bins 0..nfft/2; |X|²/(Fs·Σw²); bins 1..nfft/2−1 doubled (DC and Nyquist not doubled).
13. **Band integration**: Trapezoid over [lo, bins strictly inside (lo, hi), hi], with the PSD at lo and hi linearly interpolated between neighbouring bins.
14. **Initial deviation**: |dFk[o] − ref| using the onset-frame sample only.
15. **State z-score**: z = (x − mean)/SD with SD ddof = 1, over all validation trials of the session (OL+CL pooled). Motion only in motion sessions.
16. **OLS slope**: Ordinary least squares with intercept, slope = Σ(z−z̄)(y−ȳ)/Σ(z−z̄)², fitted within the condition's trials (z is not re-standardised within condition).
17. **Logs**: Natural log for A (log RMSE) and for the ratio tests; A_pct = 100·(e^A − 1). For the A test row, effect_pct / ci_*_pct apply the same transform to the mean and CI of A.
18. **Variance**: Across-trial variance uses numpy var(ddof=1) per sample offset, then the mean over the window samples; the post variance window is post_var (3–6 s) and post RMSE uses post_rmse (3–4 s), as specified.
19. **Prep window**: Command samples with timeBlue[o] ≤ t < timeBlue[o]+3 s on d.inpTime, pooled over all CL validation trials; 'session maximum CL command' = the maximum of these pooled samples; total = lower + upper (disjoint). Raw command samples, no offset correction (pre-specified definition kept; validity caveat in CHECKS §7).
20. **max_cmd**: Per trial, the maximum active-channel sample over the same 0–3 s interval, OL and CL.
21. **Onset sanity**: Rise = first sample in [t0−0.5, t0+1.0) s exceeding (median over [t0−1.5, t0−0.5) s) + 0.05 V; offset = (t_rise − t0)/median frame interval; 'within ±2 frames' = |offset| ≤ 2.
22. **Alignment check**: Added check (not in spec): lag of the most negative correlation between frame-to-frame changes of dFk and of the frame-binned command, lags −20..+20, excluding |dFk| ≥ 50 (start-up transient).
23. **Runs test**: Wald–Wolfowitz runs test on the validation-block condition sequence, normal approximation, two-sided.
24. **sess_test sign count**: k = number of sessions whose value (on the tested scale, i.e. log ratio for ratios) has the same sign as the session mean; k_n = number of non-zero values. tests.csv names the sign-count denominator k_n because the spec lists 'n' twice. The 'sign' column says which sign was counted.
25. **sess_test CI**: t-based 95 % CI on the tested scale (df = n−1); for log=True the mean and CI are exponentiated (geometric mean and its CI).
26. **Wilcoxon**: scipy.stats.wilcoxon(x, method='exact', alternative='two-sided') on the tested-scale values (log ratios vs 0, i.e. ratio vs 1); zero_method default 'wilcox'. Zeros/ties are counted in tests.csv (n_zero, n_tied); none occurred.
27. **Leave-one-mouse-out**: One-sample t-test p after removing all sessions of one mouse, for each mouse; lomo_worst_p = the largest of these; a mouse whose removal leaves < 2 sessions would be skipped (never happens here).
28. **Mouse-averaged**: Per-mouse mean on the tested scale (log for ratios); mouse_k = mice whose mean has the same sign as the session mean; mouse_p = one-sample t-test across the mouse means (n = 4 mice, df = 3).
29. **Holm**: Own implementation (tests.holm): step-down, adjusted p_(i) = max over j ≤ i of min(1, (m−j+1)·p_(j)). Families: P and R over the 4 states (m = 8); A over the 4 states (m = 4). Raw p kept.
30. **Roles**: Fig 3: full = main; early, late = secondary; pre, post = null_window. Fig 4D P, R, A = main (spec gives no role). Fig 4D gap and gap_change = secondary (spec asks for effect and CI; the other columns are filled anyway). Prep Spearman = supplementary.
31. **gap per state**: gap does not depend on the state; it is repeated per state so that the motion row uses the 11 motion sessions and the others use all 15.
32. **Spearman**: scipy.stats.spearmanr (average ranks for ties, two-sided p from its t approximation), n = 15 sessions, against the full-window RMSE ratio.
