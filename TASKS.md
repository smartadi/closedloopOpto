# TASKS.md — Prioritized TODO

Single source of truth for open work. Updated after each session or meeting.
Findings that are done live in FINDINGS.md. Meeting context lives in MEETINGS.md.

---

## 🔴 Blocking submission

### Manuscript text
- [ ] Fix "stimulation onset did not affect variance" claim — rewrite using FINDINGS.md result (post-onset slope −0.57 ± 0.24) — `results_edit.tex` L50
- [ ] Soften linearity claim to "peak response scales approximately linearly" — `results_edit.tex` linearity paragraph
- [ ] Fix step-response tension: state window too short to observe steady state — `results_edit.tex` L49
- [ ] Fix variance-convergence paragraph: show batch mean stabilises, not just shrinking variance — `results_edit.tex` L52
- [ ] Fill in actual Kp and Ki gain values (currently [X] placeholders) — `results_edit.tex` L89
- [ ] Fix all broken cross-references `(Section )`, `(??)`, `Algorithm ??` throughout draft
- [ ] Fill in author names and affiliations — `main.tex` L63–67

### Analysis still needed for text
- [ ] Run TF fit across all 3 impulse sessions; compare poles/time constants between sessions — `Impulse_mouseDataAnalysis_all.m`
- [ ] Relax TF delay τ; report R² on held-out 20% test set (Nick, 2026-05-08)
- [ ] Verify widebrain ARX R²_spont > 0.3; interpret OL vs CL residuals — `plottingScript.m`
- [ ] Re-confirm trial MSE window t=+1→+3 s is used everywhere and stated in manuscript

---

## 🟡 Next sprint

### New analyses
- [ ] Implement three-layer contralateral prediction model (pink/orange/red) — see FINDINGS.md — `plottingScript.m`
- [ ] Implement Curto & Issa-style trial-sorting figure (synced vs desynced by pre-stim variance) — `plottingScript.m`
- [ ] Add pre-stim variance vs MSE finding to manuscript (results paragraph + K2 figure reference) — FINDINGS.md entry exists
- [ ] Add motion vs MSE (closed vs open loop, cross-session) panel to manuscript
- [ ] Add sine-wave (preview/feedforward) control results section + figure — `Analysis_variable.m`

### Figure fixes
- [ ] Make mean dot smaller in all-sessions MSE violin (panel 3H) — `plottingScript.m`
- [ ] Generate spatial spread supplementary panel (ΔF/F inhibition area vs laser power) — cite Nuoli/Svoboda
- [ ] Verify Fig 3H shows MSE (not MAE) — update caption accordingly
- [ ] Verify Fig 2C shading is ±1 SD — update caption if not

### Prose
- [ ] Convert passive voice to active throughout results ("We delivered…", "We quantified…")
- [ ] Standardise figure citation style to `Fig. 1A` (not `Figure 1(A)`) throughout
- [ ] Remove remaining equation references from Results prose
- [ ] Add n and ± CI to all slope estimates in linearity paragraph

---

## 🟢 Deferred / waiting

- [ ] Post-hoc optimal laser sequence (MPC motivation) — depends on three-layer model — see FINDINGS.md
- [ ] Add motion energy as co-predictor in contralateral prediction models
- [ ] Fraction of high-error CL trials attributable to 2–4 Hz fluctuations vs motion
- [ ] Latency staircase artefact: verify beat-frequency numerically (trial interval vs 1/35 s) before writing up
- [ ] Disturbance-rejection only comparison (last 2 s of trial, activity settled) — OL vs CL
- [ ] Freq analysis: use absolute power values in manuscript framing (not ratios/normalisation)
- [ ] Controller performance vs initial state at stim onset: per-trial MSE vs |ΔF/F at t=0| scatter
- [ ] Optional: insert fixed 2 ms pause in processing code to verify ~14 ms minimum latency shifts
- [ ] Follow up with Zilu on ARIMA/forecasting models
- [ ] Prepare widefield dataset for Tim Kim latent-space model; arrange joint meeting


---

## Cross-area diagram (static reference)

```
Impulse_mouseDataAnalysis_all.m
  → TF poles / time constants
     ↓ compare
plottingScript.m §OL step TF fit
  → same LTI model, step input
     ↓ both feed
Paper: linearity claim (Results §1)
  + controller performance (Results §2–3)
     ↓
Closedloop_edit/ → Overleaf → submission
```

Impulse TF time constants should match OL step TF time constants.
If they agree → validates LTI assumption across stimulus types.
