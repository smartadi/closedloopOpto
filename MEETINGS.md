# Meeting Log — Brain Paper (Nick/Aditya)

Transcripts: `C:\Users\aditya\OneDrive\Notes\Adick meetings\`  
Add a new entry here after each meeting. Parse with: give Claude the transcript path and say "parse this meeting."

---

## Open Action Items — as of 2026-05-11

### Manuscript — Text & Structure
- [ ] Finalize reorganized paragraph structure (punchline → explanation); move remaining content to Methods *(2026-05-08)*
- [ ] Fix broken cross-reference links throughout the draft *(2026-05-08)*
- [ ] Notify Nick when revised draft (text + figures) is ready for full review *(2026-05-08)*
- [x] Update remaining figure captions; incorporate Nick's Slack/cloud comments *(2026-04-27, done per 2026-05-11)*

### Manuscript — Figures (existing)
- [ ] Generate supplementary panel: spatial spread (ΔF/F inhibition area) vs. laser power; cite Nuoli/Svoboda *(2026-05-08)*
- [x] Update impulse-response figure: zoom in x-axis on panel A so power levels are distinguishable *(2026-05-08)*
- [x] Change error bars on impulse-response plots from IQR to 95th-percentile bounds *(2026-05-08, done 2026-05-14)*
- [ ] Refine transfer-function fit (3-pole model): relax delay parameter τ; report R² on held-out 20% test set *(2026-05-08)*
- [ ] Re-compute trial MSE using window **t = +1 s to +3 s** post-laser onset; compare to existing results *(2026-05-08)*
- [ ] Add motion vs. MSE (closed vs. open loop, cross-session) panel + good/bad trial spectral examples to manuscript *(2026-05-08)*
- [ ] Add sine-wave (preview/feedforward) control results section/figure *(2026-04-27, deferred again 2026-05-08)*
- [x] Rescale laser input trace on single-trial and average panels *(2026-04-27, done per 2026-05-11)*
- [x] Unify plot format across the four subpanels in the final figure *(2026-04-27, done per 2026-05-11)*
- [x] Replace relative (normalized) power spectra with absolute power (ΔF/F²/Hz) *(2026-05-08, done per 2026-05-11)*

### Manuscript — New Analyses (from 2026-05-11)
- [ ] Implement **Curto & Issa-style trial-sorting figure**: split trials into synchronized (high pre-stim variance) vs. desynchronized (low pre-stim variance) using ~1 s pre-stim window; sort within groups by absolute fluorescence at t = 0; display ΔF/F heatmaps *(2026-05-11)*
- [ ] Confirm absolute power spectral plots complete; finalize narrative framing (motion + frequency → trial outcome) and produce summary figure *(2026-05-11)*
- [ ] Generate **three-layer contralateral-prediction model** figure:
  - **Pink**: predict ipsilateral ROI from contralateral pixels in spontaneous (no-opto) data
  - **Orange**: add average open-loop impulse response on top of pink prediction
  - **Red**: add exact per-trial laser sequence (via transfer-function model) on top; check match to closed-loop traces *(2026-05-11)*
- [ ] Using the red model (if validated): compute post-hoc **optimal laser sequence** for representative trials; quantify gap vs. actual controller; frame as MPC motivation *(2026-05-11)*
- [ ] Add motion energy as co-predictor alongside contralateral pixels in pink/red models *(2026-05-11)*
- [ ] Determine what fraction of high-error closed-loop trials are attributable to 2–4 Hz spontaneous fluctuations vs. motion; prepare summary figure *(2026-05-08)*

### Latency Analysis
- [ ] Optional: insert fixed 2 ms pause in processing code to verify ~14 ms minimum latency shifts *(2026-04-27)*

### Mouse Logistics
- [x] Coordinate with Anna on timeline for retroorbital PHP.eB mouse; begin habituation; run first open-loop sessions with **data saving enabled** *(2026-05-11)*
- [x] Track habituation timeline for freshly injected mouse (~2 weeks from 2026-05-11) *(2026-05-11)*
- [x] Run open-loop controller sessions and **save the stimulus/response data** for new mouse(es) *(2026-05-08)*
- [x] Approach Fabiola with specific mice + virus info; coordinate surgery plan *(2026-04-27)*
- [x] Check status of existing GCaMP/PHP.eB mice needing head bar + window implants *(2026-04-27)*
- [x] Ask Anna to identify suitable GCaMP mice for new local viral injections *(2026-04-27, done — two mice now injected per 2026-05-11)*

### Collaboration
- [ ] Follow up with Zilu on ARIMA/forecasting models for multi-region widefield forecasting *(2026-04-27)*
- [ ] Prepare widefield dataset (impulse/step responses) for Tim Kim's latent-space forecasting model; arrange joint meeting *(2026-04-27)*
- [x] Send Nick screenshots: (a) bad/good-trial interactive spectral plots, (b) motion vs. MSE scatter — via Slack *(2026-05-08)*
- [x] Share CLAUDE.md and RESEARCH.md (or GitHub link) with Nick for departmental AI-tools presentation *(2026-05-08)*

### Nick's Items (not Aditya's)
- [ ] **Nick**: Create mouse catalog spreadsheet — proposed for lab meeting 2026-05-12 *(2026-04-27, recurring)*

---

## Meeting Entries

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
