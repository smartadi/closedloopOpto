# Sensitivity analysis: review plots (copied 2026-11-10)

Copies for review; the producers write the originals to `paper/images/figure4/supp/`.
All 15 sessions, 4 mice, corrected onsets, m14 alignment fixed. None is a locked paper panel.

| File | What it shows | Key numbers | Script |
|---|---|---|---|
| 01_sens_panel.png | Draft paper panel: CL/OL residual power vs frequency, 95% CI; bars where the CI excludes 1; delay limit 3.7 Hz | Reduced below 1.03 Hz; amplified 2.77–6.63 Hz, peak 1.95x at 4.2 Hz | `stats_v2/sensitivity_cert.py` |
| 02_sens_resid_sheet.png | Review sheet: absolute residual spectra (OL red, CL blue), the ratio with pre-stim null and 1–3 s window, band ratios, 1 Hz bands to 17.5 Hz | <1 Hz 0.32x; 1–3 Hz ~1; 3–6 Hz 1.37–1.80x (Holm); nothing above 7 Hz | `stats_v2/sensitivity.py` |
| 03_sens_trials_median.png | Trials picked by rule (50th/90th percentile of 3–6 Hz power) in the median session, m11 (Mouse 2) | Visible ~4 Hz oscillation in the 90th-percentile CL trial, laser command oscillating with it | `stats_v2/sens_trials.py` |
| 04_sens_trials_strongest.png | Same, strongest session by ratio, m15 (Mouse 4) | Ratio 2.65x but small in absolute terms (0.22 to 0.36 %dF/F) | `stats_v2/sens_trials.py` |
| 05_sens_trials_budget.png | Error budget: residual variance by band; 3–6 Hz RMS per session; RMSE per session | Feedback removes 3.13 (%dF/F)^2 below 1 Hz, adds 0.22 at 3–6 Hz; RMSE lower in 15/15 | `stats_v2/sens_trials.py` |
| 06_f4d_state_windows.png | Fig 4d slopes with each state measured locked, laser off ([−5,0), [−2,0)) and controller on | Absolute 1–4 Hz holds laser off; relative 2–4 Hz ratio effect does not | `stats_v2/f4d_windows.py` |
| 07_f4d_band_grid.png | Fig 4d slopes across 1 Hz bands, absolute and relative, locked and laser off | No band singles out absolute 1–4 Hz or relative 2–4 Hz | `stats_v2/f4d_bands.py` |
| 08_state_spectra_resid.png | Readout spectra 0–3 s by within-session state quartile (Q1 light, Q4 dark), OL and CL; motion, and absolute 1–4 Hz and relative 2–4 Hz in the laser-off and the locked (circular) window; residual signal | No tests (Aditya's call). By eye: motion's extra power is below 1 Hz and feedback removes it; absolute 1–4 Hz adds power at 0.6–6 Hz that survives feedback | `stats_v2/state_spectra.py` |
| 09_state_spectra_err.png | Same, error from the reference instead of the residual | Same shapes; extra offset power below 0.5 Hz | `stats_v2/state_spectra.py` |

Not shown as a plot: loop gain vs 3–6 Hz amplification across sessions (Spearman +0.70, within mouse +0.78;
table in `data/stats_v2/corrected/sens_trials_gain.csv`). Details for every number: RESEARCH.md, 2026-11-01 and 2026-11-02.
