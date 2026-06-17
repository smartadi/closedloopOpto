### 2026-06-10 — spectral_mse_sort.m: Figure J6 added (merged variance + delta vs MSE)
**Changed:** `controller-analysis/spectral_mse_sort.m` — Added Figure J6 as a single pooling loop combining analysis from prestim_variance.m (variance) and spectral_mse_sort.m (delta power). Per trial: variance = var(pncDfk_l, trial-2s to trial end, cols 36:210); delta = 1-4 Hz fractional power (ncFreqPow, full spectral window); MSE = er_ncDfk. Motion-clean (motThresh=1.5). Trials sorted by variance ascending. Layout: 14x8 cm, 3 cols x 2 rows. Col 1 = reference-subtracted dF/F heatmap; Col 2 = variance vs MSE scatter; Col 3 = delta vs MSE scatter. All three axes per row linked on Y (rank). Exports to paper/trial_state_mse.png.
**Why:** User wants a single figure testing the message "high trial variance → high MSE, same trials also show high delta power" — requires computing all three quantities on the same motion-clean trial pool.
**Next:** Run J6 section; compare OL vs CL r-values for both predictors; check if variance r > delta r (variance may be stronger predictor since it directly reflects the signal mismatch).

### 2026-06-09 — Pre-stim variance (not delta) is the per-session-robust controllability predictor; two independent state axes
**Changed/Found:** Re-tested state-dependence with the correct variable + rank correlation (per-session Spearman, controller data, loaded session). (1) **Pre-stim ΔF/F variance → trial MSE survives strongly per-session:** median Spearman r=+0.21 (OL) / +0.24 (CL), signrank p=0.0017 each, 12/13 sessions positive in BOTH loops; motion-clean r=+0.25/+0.13, p=0.027, 8/9 sessions. Linear slope was weak (relationship monotonic-nonlinear) — rank correlation captures it. (2) **Corrects old FINDINGS "CL decouples from pre-stim state":** CL is predicted by pre-stim variance just as much as OL (r 0.24 vs 0.21, paired signrank p=0.64) — uncontrollability PERSISTS under closed-loop (feedback can't reject intrinsic unpredictability). (3) **Motion ⊥ pre-stim variance** (per-session r(motion,prestim-var)=−0.009, p=0.82): two independent state axes, not one arousal axis. Synthesis: motion = rejectable exogenous disturbance (CL motion-invariant, OL degrades, interaction p=0.039); pre-stim variance = irreducible model-mismatch (both loops degrade). Maps cleanly onto internal model principle: you can't reject what you can't model.
**Why:** User clarified the real scientific narrative (predictability=controllability, grounded in impulse TF prediction error; motion→predictable-but-random; high pre-stim variance→unpredictable→uncontrollable, trend persists in controller data but weak under linear slopes). Pushed me to the correct variable (pre-stim variance) and method (rank corr).
**Next:** Impulse-side anchor not yet pulled (would need load_experiments.m + impulse-analysis/prestim_variance.m to quantify TF-prediction-error vs pre-stim variance / motion; FINDINGS r/p still placeholder XX). Abstract NOT yet edited — awaiting user choice between two-pillar framing now (controller numbers) vs loading impulse data first for the predictability anchor.

### 2026-06-09 — Per-session paired re-test: delta-power finding is a pseudoreplication artifact; motion story revised
**Changed/Found:** Re-ran state-dependence stats with session as the independent unit (paired `signrank`/per-session Spearman across n=9–13), replacing pooled-trial `ranksum`. (1) Variance −40.7% and MSE −19.3% **survive** (signrank p=0.0005, p=0.0002). (2) **Delta(1–4 Hz)→trial-MSE COLLAPSES per-session:** within-session Spearman median r=−0.14 (CL), signrank p=0.57; only 3/9 sessions r>0. The pooled r=+0.35 (p=1.6e-15) was Simpson's paradox — driven by a *between-session* link corr(session-mean delta, session-median MSE)=+0.76, p=0.018 (n=9; heavily weighted by m2). So delta is a session/state-level marker, NOT a per-trial predictor. (3) **Motion story revised:** per-session paired, CL beats OL at BOTH low (gap +4.1, p=0.008) and high motion (gap +7.0, p=0.004) — the pooled "indistinguishable at low motion (p=0.28)" was an artifact. What holds: OL degrades with movement (MSE 23.1→27.3) while CL is motion-invariant (19.7→19.6), so CL advantage is larger during movement (interaction signrank p=0.039). Mechanism = feedback rejects movement-induced disturbance.
**Why:** User asked to redo all abstract stats as proper per-session paired tests after a discussion of pseudoreplication; the pooled p-values treated 1470 trials as independent across only 13 sessions / 2 mice.
**Next:** Abstract NOT yet edited (user to decide). Options: drop delta claim, or demote to hedged between-session observation. Motion claim must be rewritten to the "motion-invariance/decoupling" framing. For journal: use mixed-effects (session random effect) throughout; treat delta as a between-session covariate only.

### 2026-06-09 — State-dependence of controller MSE quantified for SfN abstract (motion + delta)
**Changed/Found:** Ran two pooled analyses in live MATLAB (data from `load_sessions.m`). (1) Motion quartile → trial MSE (9 motion sessions, combined-window mean-sq z-motion): at high-motion Q4, CL MSE 20.3±0.5 vs OL 29.8±1.0 (CL −32%, gap +9.5, ranksum p<1e-4); at low-motion Q1, OL 33.5±1.8 vs CL 30.5±1.3 (gap +3.0, p=0.28 n.s.). CL advantage grows with arousal. (2) Motion-removed (|z|≤1.5) MSE median-split → pre-stim delta (1–4 Hz) power: CL high-error trials carry +24% delta power (0.040→0.049, ranksum p=2.7e-7; r=+0.35, p=1.6e-15); OL +12% (p=0.018; r=+0.155).
**Why:** User wanted hard numbers for the state-dependence section of the SfN abstract — specifically the motion-quartile (high motion → better CL) and motion-removed delta-power (high MSE → more slow-wave) results. Note: pooled *linear* motion→MSE correlation is weak/positive (OL r=+0.10); the quartile framing is the defensible one and is what was used.
**Next:** For journal version, compute these per-session (not just pooled) with mixed-effects to respect session nesting; add exact delta-band definition (centers 1–4 Hz, pre-stim bins 1–6, onsetBin=7) to Methods.

### 2026-06-06 — explore.m: comprehensive trial plot (both pixels × both stim sides × type × amp)
**Changed/Found:** `explore/explore.m` — replaced old per-side trial-plot loop with a comprehensive section; one figure per recording pixel, rows=stim condition (impulse/step × amp), cols=stim side (left/right), each panel overlays both pixels (solid=recording, dashed=other); auto-detects type codes when IMPULSE_CODE_P/STEP_CODE_P are NaN
**Why:** User requested a single organised view showing all experimental conditions together so both hemispheres' responses can be compared across stim type, amplitude, and stimulated side
**Next:** Set IMPULSE_CODE_P and STEP_CODE_P once codes are confirmed from the viewer section printout

### 2026-06-06 — bilateral-analysis/ restructured for mixed-stim sessions (trial_meta)
**Changed/Found:** `load_bilateral.m` — replaced per-session `exp_type` tag with per-trial `trial_meta` struct array; added `STIM_TYPE_COL`, `AMP_COL`, `STIM_TYPE_MAP` placeholders; all downstream scripts (`ol_characterization`, `cl_constant_ref`, `cl_tuning`, `cl_sinewave`) now filter trials via `trial_meta` mask instead of `sess.exp_type`
**Why:** Single session can contain impulse + step + mixed amplitudes on either side; session-level exp_type cannot represent this
**Next:** Fill `STIM_TYPE_COL`, `AMP_COL`, and `STIM_TYPE_MAP` codes once experiment repo is shared; verify `trial_meta` summary printout on first real session

### 2026-06-06 — bilateral-analysis/ sub-area scaffolded for AL_0048 dual-opsin mouse
**Changed/Found:** Created `bilateral-analysis/` with `CLAUDE.md`, `load_bilateral.m`, `ol_characterization.m`, `cl_constant_ref.m`, `cl_tuning.m`, `cl_sinewave.m`, `compare_sides.m`; updated root `CLAUDE.md` trigger table and locked-in decisions; added 9 tasks to TASKS.md
**Why:** AL_0048 has excitatory (left) and inhibitory (right) opsins requiring bilateral analysis with per-side reference polarity, variable galvo position identity from input_params, and new controller tuning (Kp/Ki grid + gradient descent) not present in existing sub-areas
**Next:** Fill `BREGMA_COL`, `STIM_MODE`, and first session entry in `load_bilateral.m` once first AL_0048 experiment is collected; confirm reference polarity sign

### 2026-06-04 — widebrain_hemi_kernel.m: align contra-SVD pipeline with spirals paper
**Changed:** `controller-analysis/widebrain_hemi_kernel.m` — Three changes: (1) replaced `eig(U_c'*U_c)` eigendecomp with `redoSVD` (batch-downsampled covariance SVD from Ye et al. 2023); (2) zscore regressors along time using train-set params applied to both train and test; (3) replaced spont-epoch frame loop with simple 80/20 frame-index cutoff on the full recording. Copied `utils/redoSVD.m` from spirals repo.
**Why:** Prior version deviated from the spirals methodology in SVD derivation and normalisation; aligning ensures the contra kernel is computed the same way as in the published pipeline.
**Next:** Run on selField=12 session; check R2_spont vs previous value; verify redoSVD completes without OOM.

### 2026-06-04 — spectral_mse_sort.m: drop J3/J3i; fix J5 scatter alignment
**Changed:** `controller-analysis/spectral_mse_sort.m` — (1) Deleted Figure J3 and J3 interactive entirely. Script now opens directly with J4. (2) Fixed J5 scatter: Y now uses `bYpos_nc5`/`bYpos_wc5` (rank-centre positions) so dots align with heatmap bins like J4 does. Custom Y-tick labels show actual block-mean variance at 5 evenly-spaced ticks. `linkaxes` updated: each heatmap–scatter pair linked on Y; cross-row scatter Y link removed.
**Why:** J3/J3i made redundant by J4+J5. J5 scatter dots were at variance-unit Y values (~1–50 ΔF/F²) while heatmap Y is rank (1–500+), causing complete misalignment.
**Next:** Run J4 and J5; confirm scatter dots sit at bin midpoints; check variance tick labels are readable.

### 2026-06-04 — spectral_mse_sort.m: new Figure J5 (variance-sorted dF/F heatmap)
**Changed:** `controller-analysis/spectral_mse_sort.m` — Added Figure J5 after J4. Same 2-col × 2-row layout (grayscale heatmap + scatter). Sort key: per-trial `var(ncDfk, 0, 2)` over full available window (1s pre + 3s trial, 140 frames). Scatter Y = block-mean trial variance ± SEM (not rank); X = block-mean MSE ± SEM. No fit line. `linkaxes`: time X linked across heatmaps; MSE X and variance Y linked across scatter rows. Exports to `paper/dff_var_sort.png`.
**Why:** User requested variance-sorted companion figure to J4 delta-sorted heatmap, with variance on Y-axis of scatter.
**Next:** Run J5 section; compare r-values OL vs CL; check if variance gradient is visible in heatmap.

### 2026-06-04 — spectral_mse_sort.m J4: sort key extended to full trial window
**Changed:** `controller-analysis/spectral_mse_sort.m` — Replaced `preWinF` (2 s pre-onset only, also had a stale `round(2*Fs_j4)` bug that accidentally clipped to `1:onsetBin-1`) with `sortWinF = max(1, onsetBin-2) : min(nBins, onsetBin+dur_k-1)`, covering trial−2 s through end of trial at ~1 Hz spectral bins. Renamed intermediate vars `nc_pre_s/wc_pre_s/nc_sort_norm` accordingly; pooled arrays (`nc_delta_pre_j4`) and sort call unchanged. Updated section header, fprintf, and sort comment.
**Why:** User requested full window (trial−2 s → end of trial) as sort key rather than pre-trial-only window.
**Next:** Run J4 section in MATLAB; verify heatmap gradient is stronger / weaker and OL vs CL r values.

### 2026-06-04 — tf_fit.m: Bode plot + phase-margin block added
**Changed:** `controller-analysis/tf_fit.m` — (1) Added `colOL = PS.col_ol; colCL = PS.col_cl;` after `paperStyle()` (pre-existing bug). (2) Stash each fitted TF as `tf_ol{si}` inside the loop. (3) Appended `%% Bode / phase-margin analysis` block: 500-point logspace freq grid 0.01–32 Hz, `bode()` on `tf(G)` (idtf→CT tf), `margin()` for Pm/Gm/crossover freqs, interpolated -90° crossing. Produces `fig_bode` with mag+phase panels, 3-session overlay, -90° dashed ref.
**Why:** User requested Bode plot and phase margin / -90° phase crossing frequency from the 2p1z OL TF fits.
**Next:** Phase never crosses -90° in the biological range (0–17.5 Hz Nyquist) — all sessions sit at +100° to +180° phase throughout. This is because the fitted TFs have a non-minimum-phase character (positive DC phase ~180°, driven by the inhibitory sign inversion). Discuss with Nick whether to negate the plant gain convention or interpret Pm differently.

### 2026-06-04 — spectral_mse_sort.m: new Figure J4 (raw dF/F delta-sorted)
**Changed:** `controller-analysis/spectral_mse_sort.m` — Added `%% Figure J4`. Sort key: per-trial pre-onset delta (1–4 Hz fractional power, 2 s pre-onset window). Col 1: raw dF/F heatmap (diverging blue-white-red, Y=rank, X=time, onset line). Col 2: MSE vs delta-rank block scatter (horizontal errorbars ±SEM, fit+r). Col 3: block-mean dF/F traces parula-coded by rank + onset + ref line + colourbar strip. linkaxes: heatmap+scatter share Y per row; heatmaps share X; scatter share X; traces share XY. Exports `dff_delta_sort.png`.
**Why:** User requested raw dF/F (not spectrum) as display, pre-trial delta as sort key (cleaner brain-state marker in CL where controller shapes pre-stim variance), and block-mean traces to show how response evolves with delta rank.
**Next:** Run J4; verify heatmap gradient visible; compare OL vs CL scatter r values.

### 2026-06-04 — spectral_mse_sort.m J4: 2-col layout, baseline-subtracted heatmap, no sig
**Changed:** `controller-analysis/spectral_mse_sort.m` — Removed Col 3 (block-mean traces + colourbar strip). Col 1 heatmap now plots `nc_dfk_bsl4` (per-trial pre-stim mean subtracted) so pre-stim centres at 0 and colour encodes post-onset deviation. clim recomputed on baseline-subtracted pool. Scatter r text has no significance stars. Layout 10×8 cm, hm_w4=0.48, sc_w4=0.32.
**Why:** User requested col 3 removed, reference zeroed before stim, significance not reported yet.
**Next:** Run J4; check heatmap shows clean onset response gradient vs rank.

### 2026-06-04 — Parsed June 3rd Nick meeting into MEETINGS.md
**Changed/Found:** `MEETINGS.md` — Added 2026-06-03 meeting entry and 8 new action items (2026-06-03.1–.8); updated open items header to as-of 2026-06-03
**Why:** New meeting covered laser-subtraction validation approach, delta-band fraction as sorting criterion, phase-margin instability frequency analysis, and joint amplitude+latency spatial spread characterization
**Next:** Prioritize 2026-06-03.1 (laser subtraction in `plottingScript.m`) and 2026-06-03.3 (instability frequency plot); update TASKS.md to reflect new 🔴/🟡 items from this meeting

### 2026-06-04 — contra_prediction.m: pre-trial CF + motion predictor
**Changed:** `impulse-analysis/contra_prediction.m` — (1) z-scored motion appended to predictor matrix as `X_cp_m = [X_cp, mot_z]`; (2) ARX trains on contra+motion; (3) `[CP-1]` rewritten to pre-trial counterfactual: model uses only `buf_pre = mlag+outlen` frames before onset — no laser-period data. Both actual and predicted baseline-corrected by `y_full(i_on)`.
**Why:** User wanted pure contra+motion prediction with zero laser input knowledge.
**Next:** Run and check R2_test; verify residual shape scales with amplitude.

### 2026-06-04 — New script: impulse-analysis/contra_prediction.m
**Changed/Found:** `impulse-analysis/contra_prediction.m` — new script; contralateral ARX model for impulse analysis (initial version with trial-window prediction).
**Why:** User requested contra-pixel predictive model for impulse experiments, analogous to widebrain_arx.m.

### 2026-06-04 — spectral_mse_sort.m J3: right column changed to delta vs MSE scatter
**Changed:** `controller-analysis/spectral_mse_sort.m` — Right column (delta panels) in both fig_J3 and fig_J3i: X = MSE (matches middle column), Y = delta (1–4 Hz) fractional power, vertical ±SEM errorbars. Correlation changed to `corr(bMSE, bDelta)`. Fit lines now span MSE range. linkaxes: mid col Y linked to heatmap (rank); all four scatter panels share X (MSE); right col OL/CL share Y (delta range).
**Why:** User requested right column mirror middle column — prediction error on X, band power on Y.
**Next:** Re-run J3; check delta vs MSE slope is steeper for OL than CL.

### 2026-06-04 — spectral_mse_sort.m: dropped Fig I/J/J2, kept J3 + interactive copy
**Changed:** `controller-analysis/spectral_mse_sort.m` — Removed Figures I (per-session), J (combined MSE-sort all), and J2 (combined MSE-sort motion-clean). Kept Figure J3 (variance-sorted heatmap + scatter panels). Added `%% Figure J3 — interactive` section: identical layout, `ButtonDownFcn` on both heatmap images calls local function `j3ClickCb` which prints rank / MSE / variance / delta to command window on click. Local function added at end of file.
**Why:** User confirmed Figs J and J2 are duplicates redundant with J3; Fig I's callback was broken (undefined `heatmapClickCallback`). Interactivity moved to J3 copy instead.
**Next:** Run both J3 sections; verify click prints to command window correctly.

### 2026-06-03 — spectral_mse_sort.m J3: Y-aligned scatter panels, 20-trial bins
**Changed:** `controller-analysis/spectral_mse_sort.m` — Scatter panels now use Y = trial rank (aligned with heatmap via `linkaxes(...,'y')`), X = MSE or delta with horizontal errorbars. `blockSize_j3` reduced 50→20 for more points. Four `linkaxes` calls: row-Y links each heatmap to its two scatter panels; column-X links OL/CL within MSE and delta columns. Stale `ax_ol_var`/`bVar_nc`/`xfv_nc` references removed from plotting code.
**Why:** User requested bins increase + scatter panels should align with heatmap Y axis so trial rank is a continuous shared axis across all three columns per row.
**Next:** Run J3 in MATLAB; verify trial count printout, heatmap gradient visible, r-values positive for OL MSE vs rank.

### 2026-06-03 — pixelviewer.m: trial-based SVD viewer for controller sessions
**Changed/Found:** `controller-analysis/pixelviewer.m` — wrote script to launch `pixelTuningCurveViewerSVD` from controller workspace; uses `d.svd.U/V`, `d.timeBlue`, and `d.stimStarts` indexed by `data.nc`/`data.wc`; two conditions: 'OL' and 'CL'; calcWin = [-1 4] s; selField selects session
**Why:** needed interactive pixel-level peri-event viewer to explore spatial structure of CL vs OL responses
**Next:** verify `d.svd` fields exist for target sessions (some older caches may lack them); check that stimStarts indexing with nc/wc matches timeBlue frame rate

<!-- New entries go here, most recent first. One ### block per change. -->

### 2026-06-02 — spectral_mse_sort.m J3: split OL/CL rows, normalize log power, motion-only sessions
**Changed/Found:** `controller-analysis/spectral_mse_sort.m` §J3 — (1) pooling loop already gates on `ncmotion` so only sessions with face video are included; added trial count printout; (2) per-trial normalization: `nc_norm = nc_spec ./ sum(nc_spec, 2)` before log10, heatmap now shows fractional spectral shape; delta scatter also uses fractional power; (3) figure split into 6 panels (3 cols × 2 rows): each row has its own heatmap + variance scatter + delta scatter coloured by condition; `linkaxes` syncs X within each scatter column.
**Why:** User requested separated OL/CL rows, normalized power for heatmap, and confirmed motion-only session filtering.
**Next:** Run J3; check console for trial counts; verify heatmap gradient cold→warm with variance sort; check r_var/r_dlt positive for OL.

### 2026-06-02 — Fix integer/double concat crash in initialize_data.m
**Changed/Found:** `utils/initialize_data.m` line 86 — `d.params.pixel` is an integer type; concatenating with double `px`/`py` arrays crashed with "Integers can only be combined with integers of the same class"
**Why:** MATLAB forbids mixed integer/double array concatenation; cast with `double()` fixes it
**Next:** verify all 13 sessions load cleanly after this fix

### 2026-06-02 — Add run_all.m pipeline runner for controller-analysis
**Changed/Found:** `controller-analysis/run_all.m` — new script that cds to brain_paper root, runs load_sessions.m then all six analysis scripts in dependency order
**Why:** needed a single entry-point to run the full pipeline without manually calling each script
**Next:** verify each script completes cleanly end-to-end when called via run()

### 2026-06-02 — spectral_mse_sort.m: Figure J3 redesigned — variance-sort + MSE scatter panels
**Changed/Found:** `controller-analysis/spectral_mse_sort.m` — full rewrite of J3: (1) new self-contained pooling loop collects dF/F variance over trial period (`var(ncDfk(:, c0:end), 0, 2)`), spectral power, and MSE with motion exclusion (|z|≤1.5, 2s-pre+trial window); (2) trials sorted by variance ascending; (3) log-power heatmap (OL top / CL bottom, 9×8 cm); (4) mid panel = block-mean variance vs MSE for OL+CL overlaid; (5) right panel = block-mean delta (1–4 Hz) power vs MSE for OL+CL overlaid; Pearson r + sig stars on each panel; exports `freq_heatmap_var_sort.png`.
**Why:** User restructured to use variance as sort key and MSE as the shared X axis across side panels, so OL/CL slopes can be compared directly. Previous design sorted by MSE and showed delta vs rank separately per condition.
**Next:** Run J3 (no J2 dependency now — self-contained loop); check r_var_nc and r_dlt_nc print positive for OL, and that CL slopes are shallower; upgrade to PDF + figure4 subfolder once verified.

### 2026-06-02 — spectral_mse_sort.m: new Figure J3 — heatmap + delta block curve
**Changed/Found:** `controller-analysis/spectral_mse_sort.m` — appended `%% Figure J3` section; reuses J2's motion-excluded pooled arrays (`nc_all_m`, `wc_all_m`, `nc_ord_m`, `wc_ord_m`); adds 50-trial block means of in-trial delta (1–4 Hz) power vs MSE rank; Pearson r + significance stars for OL and CL separately; 7×8 cm two-row figure (log heatmap + gold block curve per row); exports `freq_heatmap_blockfit.png`.
**Why:** Mirrors impulse-analysis `prestim_variance.m` §2G figure structure; tests whether high in-trial delta power predicts high MSE in OL (no feedback) but not CL (feedback attenuates coupling).
**Next:** Run J2 section first to populate arrays, then run J3; check that r_nc and r_wc print expected signs; upgrade to PDF and set paper/ subfolder once result is confirmed.

### 2026-06-02 — motion_analysis.m: drop redundant sections 3, 4, 5
**Changed/Found:** `controller-analysis/motion_analysis.m` — removed §3 (raw motion traces), §4 (pooled combined-window scatter), §5 (onset deviation vs windowed MSE scatter); ~175 lines deleted.
**Why:** §3 was diagnostic-only with no paper use; §4 was absorbed by §2's pooled quartile panel; §5 overlapped §1 (same scientific question, different display) and the windowed-MSE version was not designated as a paper panel.
**Next:** Confirm §2 pooled quartile panel (combined mode) is the sole motion-vs-MSE paper figure; consider whether §5's slope-annotation approach should be folded into §1 if Nick requests it.

### 2026-06-02 — Add has_motion flag to session pipeline; backfill old caches
**Changed/Found:** `utils/initialize_data.m`, `controller-analysis/load_sessions.m` — `initialize_data` now sets `d.has_motion = true/false` in both branches of the motion-file check (previously no-video sessions silently got `d.motion = zeros(...)` with no flag). `load_sessions` now backfills `has_motion` for old cached `.mat` files (inferred from `any(d.motion ~= 0)`) and propagates it to `mouse.(fields{k}).has_motion` for both the cache-hit and fresh-init paths.
**Why:** Sessions without face video were indistinguishable from sessions with video — motion was just zeroed out. Motion analyses were silently including those sessions with meaningless zero motion. The flag lets downstream scripts gate on `has_motion` cleanly.
**Next:** Update `cl_mse_factors.m` X2 pooling loop to check `mouse.(fields{k}).has_motion` instead of `~any(dk.wcmotion(:))`. Check `motion_analysis.m` for the same pattern.

### 2026-06-02 — Propagate has_motion flag to cl_mse_factors and motion_analysis
**Changed/Found:** `controller-analysis/cl_mse_factors.m`, `controller-analysis/motion_analysis.m` — replaced all `~any(...ncmotion(:))` guards with `~mouse.(fields{k}).has_motion`. In `cl_mse_factors`, also removed the now-redundant per-trial `mot_valid` zero-row mask (unnecessary once the flag guarantees valid video for the whole session).
**Why:** The old `any(ncmotion(:))` guard was fragile — a real session with very low but non-zero motion could differ from a zero-padded one by floating-point noise. The `has_motion` flag is set at source in `initialize_data` and is unambiguous.
**Next:** Run `load_sessions` + `cl_mse_factors` to confirm trial count changes as expected (should drop sessions without video).

### 2026-06-02 — cl_mse_factors: fix motion X2 to use motion energy (mean squared)
**Changed/Found:** `controller-analysis/cl_mse_factors.m` — X2 predictor changed from `mean(wcmotion, 2)` (raw mean of z-scored signal, which can cancel) to `mean(wcmotion.^2, 2)` (mean squared = motion energy). Also added named constant `c0_mot = 71` for the onset column in `wcmotion` (replaces implicit `onset_mot = n_mot - Fs_cl*dur_k`). Predictor label updated to 'Motion energy'.
**Why:** `d.motion` is a z-scored signal that goes negative; mean can cancel out genuine motion. Energy (sum of squares) is the correct summary. `c0_mot=71` is exact: `wcmotion = mv(i-70:i+35*dur)` so onset is at index 71.
**Next:** Re-run script and check whether R² for motion energy predictor changes substantially; verify VIF stays low.

### 2026-06-02 — motion_analysis.m: remove legend from motion-quartile paper figure
**Changed/Found:** `controller-analysis/motion_analysis.m` — removed `lgd_qp = legend(...)` and `paperLegend(lgd_qp)` from the motion-vs-MSE quartile paper figure (lines 225–226); OL/CL are colour-coded and the legend was redundant.
**Why:** User confirmed figure will carry no legend; tick labels and colour alone are sufficient for a 6×4 cm panel.
**Next:** Verify exported `motion_quartile_combined.pdf` looks clean without legend box.

### 2026-06-02 — widebrain_hemi_kernel.m: rewritten as OLS observability kernel (removed CCA)
**Changed/Found:** `controller-analysis/widebrain_hemi_kernel.m` — Stripped CCA and ipsi SVD entirely. New pipeline: contra SVD timecourses (V_c via M=U_c'U_c), primary pixel timecourse from full SVD (y_prim = U_flat(prim,:)*V_wb), OLS on spontaneous pre-trial frames (beta_c = V_c_tr \ y_prim_tr), kernel projected to pixel space (k_contra = U_c*W_c*beta_c). Scalar outputs: R2_spont, kernel_norm, kernel_peak — saved to data/hemi_obs_<session>.mat. Two figures: contra kernel map + R² vs rank curve. Script is now ~150 lines vs 380 lines previously.
**Why:** CCA finds coupled modes across all ipsi pixels simultaneously — overkill when the goal is the kernel for a single target pixel (the primary). OLS is the correct tool: it directly minimises prediction error for that pixel. CCA also caused OOM (materialised [nPix_i × nTrain]). The scalar R2_spont and kernel_norm are the observability index connecting to controller analysis.
**Next:** Run on session m12. R2_spont should be ~0.1–0.5 (meaningful contra prediction). Check kernel map for structured spatial pattern. Then connect R2_spont/kernel_norm to trial MSE across sessions.

### 2026-06-02 — New script: spiral_analysis.m — spiral detection + trial performance grading
**Changed/Found:** `controller-analysis/spiral_analysis.m` (new) — Calls `utils/detectSpirals.m` (which wraps spirals repo) per session, caches results to `data/*_spirals.mat`, then computes per-trial spiral density (spirals/s during trial window) and pre-trial density (pre-stim window). Six analysis panels: (1) pre-trial density vs MSE quartile bins OL/CL, (2) trial density vs MSE bins, (3) OL vs CL density bar/scatter per session, (4) peri-trial PETH ±SEM, (5) CW/CCW direction ratio OL vs CL, (6) MSE-sorted heatmap coloured by spiral density.
**Why:** User wants to grade trial MSE against spiral wave activity the same way motion_analysis.m grades against motion and deviation. Spirals are a candidate neural-state variable that could predict or be modulated by the closed-loop controller.
**Next:** Run detection on at least one session to verify detectSpirals returns non-empty table. Check whether pre-trial density (SPD-1) predicts MSE — if OL slope is significant and CL slope is flat, that is a strong result. Check SPD-3 PETH for suppression onset timing relative to stim.

### 2026-06-01 — New script: widebrain_rrr.m — spirals-style RRR widebrain prediction
**Changed/Found:** `controller-analysis/widebrain_rrr.m` (new) — Created companion to widebrain_arx.m that replaces the sparse ARX pixel-grid predictor with a Reduced Rank Regression over brain-wide SVD components. Key addition over ARX: projects regression weights back to pixel space to produce a spatial kernel map (cf. spirals paper Fig 3h). Includes the full three-layer model (pink/orange/red), BIC/CV order selection sweep over RRR rank, variance-explained-vs-rank figure, and MPC gap analysis. Contra-hemisphere basis computed via eigenvectors of M=Uc'Uc (no need to materialise full data matrix).
**Why:** User wants to apply the spirals-style interhemispheric RRR kernel analysis to the closed-loop opto paper. The spatial kernel shows which contra-hemisphere pixels drive the primary pixel — directly comparable to spirals Fig 3h and interpretable in terms of interhemispheric coupling structure under OL vs CL.
**Next:** Run RRR-1a and check R2_test vs ARX R2_test. Check RRR-varexp elbow for optimal nSV_rrr. Compare spatial kernel map to atlas regions. If R2_test is substantially higher than ARX, consider replacing widebrain_arx pink with RRR pink in paper figure.

### 2026-06-01 — Figure layout system: ASCII diagrams + fit-check utility in PAPER.md
**Changed/Found:** `PAPER.md`, `utils/checkLayout.m` (new) — Added ASCII layout diagrams for all four figures (showing panel positions, export W×H, generating script). Created `checkLayout(widths, heights, total, gap, label)` utility that replicates Illustrator's uniform-height scaling and reports slack/overflow. Added inline fit-check annotations to Fig 2 and Fig 3 rows. Found two issues: (1) Fig 2 row 2 overflows by 1.6 cm (three 6×4 panels = 18.6 cm in 17 cm figure); (2) Fig 3 H panel (8 cm wide) overflows right column (7.8 cm) by 0.2 cm. Also found row-height mismatches in Fig 3 rows 1 and 3.  Updated 2A, 2B, 2D panel registry sizes (all were "pending").
**Why:** No way to verify proposed panel sizes would fit without mental arithmetic. Needed a single place to see layout + sizes + whether each row fits, updated whenever panels change.
**Next:** (1) Resolve Fig 2 row 2 overflow — decide whether 2D/2E/2F get narrower (W→5.4) or row shrinks to 2 panels; (2) Fix Fig 3 H panel: resize to 7.8×4 in variance_mse.m; (3) Decide whether row-height mismatches in Fig 3 rows 1/3 are acceptable or need resolving.

### 2026-06-04 — prestim_variance.m: align spectrum window with variance window
**Changed:** `impulse-analysis/prestim_variance.m` — replaced `imp_pvh.freqSpec{iAmp}` (pre-stored ±1 s window centred on stim onset, computed in `load_experiments.m`) with per-trial FFT computed directly from `df_k(:, preIdx_var)` (the same −1..0 s pre-stim window used for variance). Uses 70-pt Hann-windowed FFT → Δf = 0.5 Hz, matching existing `freqBandCtrs` bins. Normalization: `|X_k|² × 2 / (fs × W_hann)` → (ΔF/F)² Hz⁻¹.
**Why:** The stored `freqSpec` was a ±1 s slice centred on stim onset — it included 1 s of post-stimulus inhibition response, contaminating the "pre-stimulus" spectral estimate. The heatmap and delta-band correlation should reflect brain state before the stimulus.
**Next:** Re-run `prestim_variance.m`; verify heatmap still shows expected low-freq structure sorted by variance; check delta band (1–4 Hz) correlation `r_dp` is stable or improves.

### 2026-06-01 — tf_fit.m Paper Fig A: patch ordering fix + R² tag format fix
**Changed:** `impulse-analysis/tf_fit.m` — (1) moved gray patch to after ylim is set from data (was before traces, causing ylim to expand to patch bounds); patch y-range now uses `[yl_A(1), yTop]` exactly; `uistack(hPatch,'bottom')` pushes it behind traces; (2) fixed R² text from invalid `R^2\!=\!%.2f` to plain `R^2=%.2f`.
**Why:** Patch added before traces forced MATLAB auto-ylim to expand to patch bounds, making traces tiny. `\!` is LaTeX negative-space — invalid in MATLAB TeX renderer, displayed as literal characters.
**Next:** Re-run `tf_fit.m` — verify ylim matches data range and R² tags are readable at right edge.

### 2026-06-01 — tf_fit.m Paper Fig A: gray patch + R² tags at trace ends
**Changed:** `impulse-analysis/tf_fit.m` — (1) added gray `[0.8 0.8 0.8]` `FaceAlpha 0.5` background patch covering `[-preWin_A, tFit_s]`, matching `trace_overlay.m`; (2) shortened legend labels to `'%.1f mW'` (removed R² from label); (3) added small (5 pt) color-matched `R²=X.XX` text tag at the right end of each TF fit trace (`tFit_s + 0.02 s`, `Clipping off`).
**Why:** LOAO panel is not a paper figure so R² must appear in Fig A. Long legend labels were overlapping traces on the 6×4 cm figure. Inline end-of-trace tags keep R² readable without crowding the interior.
**Next:** Re-run `tf_fit.m` — check that R² tags clear the right edge of the axes without colliding with the scalebar or each other (adjust `+0.02` offset if needed).

### 2026-05-31 — prestim_variance.m: added third panel ax_pvs_C (delta power vs prediction error)
**Changed:** `impulse-analysis/prestim_variance.m` — added `ax_pvs_C` plotting block: errorbar (both horizontal ±SEM and vertical ±SEM), gold linear fit line, significance stars from `[r_dp, p_dp]`, ylabel `\delta power`, xlabel matching ax_pvs_B. `linkaxes([ax_pvs_B, ax_pvs_C], 'x')` links X axes. Figure widened to 16 × 5 cm.
**Why:** User requested third panel showing delta band power vs prediction error using the same 50-trial batches as the middle panel, on a shared X axis. Brings back the delta-power relationship that was previously on the same panel before z-score confusion.
**Next:** Run `prestim_variance.m`, verify all three panels render and X axes are linked. Read r_dp/p_dp from fprintf output and transcribe to FINDINGS.md "Pre-stimulus 1–4 Hz power" entry (update batch size to 50 and add delta-power correlation values).

### 2026-05-31 — fig_pvs promoted to paper panel 2G with 5 paper-quality improvements
**Changed/Found:** `impulse-analysis/prestim_variance.m`, `PAPER.md` — (1) Switched from equal-width tiledlayout to manual `axes` Position layout: heatmap ~55% width, scatter ~32% width (unequal columns). (2) Right panel Y axis hidden (`YColor=none`) — shared dimension with left, no redundant label. (3) Scatter dots coloured by batch mean pre-stim variance using parula colormap (same cmap as heatmap — visual coherence). (4) r/p correlation stat moved from axes title to text annotation inside axes (top-left, 5pt bold). (5) n-trials note added inside heatmap panel (bottom-right, 5pt). `blockVar` computation added to block-data loop. `blockSize` set to 20. Panel registered as 2G in PAPER.md (12 × 5 cm, vector).
**Why:** Figure promoted to paper panel; needed all paper-quality details: unequal widths to emphasise scatter result, no redundant axes, stat annotation, motion-exclusion note.
**Next:** Run `prestim_variance.m`, verify figure renders, transcribe r/p into FINDINGS.md "Pre-stimulus 1–4 Hz power" entry and results_edit.tex.

### 2026-05-31 — Changed highlighted band from 2–4 Hz to 1–4 Hz; added finding to FINDINGS.md
**Changed/Found:** `impulse-analysis/prestim_variance.m`, `utils/heatmapRowCallback.m` — patch X coords changed from `[2 4 4 2]` to `[1 4 4 1]` in both interactive heatmap (`ax_pvhA`) and static paper figure (`ax_pvs_A`). In `heatmapRowCallback.m`: fill patch updated, `band24` renamed `band14`, threshold changed from `>= 2` to `>= 1`, title and info string updated to "1-4 Hz". Comment in `prestim_variance.m` updated. New finding entry added to `FINDINGS.md` with draft paper claim, figure path, and to-finalise note.
**Why:** 1 Hz included — slow fluctuations below 2 Hz likely contribute to brain-state variance. Band should capture full delta/theta range relevant to state prediction.
**Next:** Run `prestim_variance.m` to verify patch renders correctly and records r/p values in figure title; transcribe to FINDINGS.md claim and results_edit.tex.

### 2026-05-31 — prestim_variance.m: right panel of fig_pvs corrected to shared Y axis
**Changed/Found:** `impulse-analysis/prestim_variance.m` — Right panel (`ax_pvs_B`) of static paper figure `fig_pvs` now uses `blockYpos` (center trial index per 10-trial batch, e.g. 5.5, 15.5, …) on the Y axis and mean prediction error (`blockDev`) on X, with `YLim = [0.5, nT_pv+0.5]` and `YDir = normal` to match the left heatmap panel exactly. Linear fit (`polyfit`/`polyval`) plotted through block means. Y label reads "Trial rank (sorted by pre-stim variance)"; X label "Impulse prediction error (ΔF/F %)". Title shows r, p, n-blocks, block size.
**Why:** Previous version plotted block variance on Y axis, breaking the shared spatial correspondence with the heatmap. User requirement: right panel Y must represent the same trial rank dimension so the two panels can be read side-by-side.
**Next:** Run `prestim_variance.m` after `load_experiments.m` to verify the figure renders correctly (batch dots should span Y from ~5 to nT_pv−5, with linear fit showing positive slope if variance predicts error).

### 2026-05-31 — Centralised paper figure style system: 4 new wrappers + full script migration
**Changed/Found:** `utils/paperStyle.m`, `utils/setPaperDefaults.m` (new), `utils/paperAxes.m` (new), `utils/paperLegend.m` (new), `utils/paperExport.m` (new), `utils/analysisPlots_combined.m`, `controller-analysis/variance_mse.m`, `controller-analysis/step_response.m`, `controller-analysis/tf_fit.m`, `controller-analysis/spectral_mse_sort.m`, `controller-analysis/prestim_variance.m`, `controller-analysis/widebrain_arx.m`, `controller-analysis/motion_analysis.m`, `impulse-analysis/dose_response.m`, `impulse-analysis/tf_fit.m`, `impulse-analysis/motion_analysis.m`, `impulse-analysis/spatial_spread.m`, `impulse-analysis/prestim_variance.m` — Implemented centralised style: (1) Extended paperStyle.m with canonical colour palette (col_ol/cl/inp_ol/inp_cl/fit/zero), lgd_token=[6 6], ax_box/ax_tickdir. (2) setPaperDefaults() sets groot defaults for Font/Box/TickDir, eliminating per-axes property blocks. (3) paperAxes(ax,...) wraps cleanAxes+shortCornerAxes_plot with auto-injected style args. (4) paperLegend(lgd) sets Box/FontSize/FontWeight/ItemTokenSize. (5) paperExport(fig,path) routes by extension (.pdf/.svg→vector, .png/.jpg/.tif→300dpi). All 13 paper/exploratory scripts migrated: PS_X variable renamed to PS, setPaperDefaults() added, SCA+cleanAxes combos→paperAxes, legend formatting→paperLegend, exportgraphics→paperExport, canonical colours→PS.col_* (non-canonical local palettes preserved).
**Why:** Every script was repeating the same style boilerplate (FontSize/FontWeight/Box/TickDir on every axes, ItemTokenSize [6 6] on every legend, matching export format strings). A single change to the style (e.g. font size) required editing a dozen files. One rule file is now the single source of truth.
**Next:** (1) Run setPaperDefaults() + paperAxes in MATLAB to verify groot defaults are applied; (2) Re-run variance_mse.m §F, analysisPlots_combined.m panels A–E, dose_response.m 2B to confirm correct export format/font throughout; (3) Verify paper/images/supplementary/ exists before dose_response.m figM export.

### 2026-05-31 — Remaining figure uniformity fixes + path standardisation
**Changed/Found:** `impulse-analysis/dose_response.m`, `controller-analysis/prestim_variance.m`, `controller-analysis/spectral_mse_sort.m`, `controller-analysis/variance_mse.m` — Applied all remaining open items from audit. (1) dose_response.m: raw figure()→paperFig(5,4) for both main and figM; ax.FontSize 12→6 and ax_m.FontSize 7→6; both lgd ItemTokenSize [10 6]→[6 6], FontWeight added; shortCornerAxes_plot LineWidth 2→1.5 in both panels; all annotation text FontSize 5/7→PS_dr.fs=6; print()→exportgraphics(...,'ContentType','vector'); hard-coded '../paper/images/figure2/...' paths replaced with dynamic detection block (same pattern as tf_fit.m) in both the main export and supplementary export; mkdir('../..') guards removed. (2) prestim_variance.m: all 11 exportable figure() calls (K1, K1_1f, K1z, K1m, K1zm, K1w at 25.4×15.2; K2, K2m, K2w at 6×4; K2z, K2zm at 8×5) replaced with paperFig(); interactive K2i and K2iw left as-is. (3) spectral_mse_sort.m: fig_I(nSess_f×11.4, nRows_f×8.9), fig_J(25.4×15.2), fig_J2(25.4×15.2) all switched to paperFig(). (4) variance_mse.m: fig_G2a/G2b/G2v raw figure()→paperFig(); G2a mean LineWidth 2→1.5 for both OL and CL traces.
**Why:** Completing the uniformity audit. paperFig() ensures PaperSize and PaperPosition are set correctly for all exports, not just on-screen position. dose_response.m was the only impulse paper panel still using print() and hard-coded relative paths — critical to fix before submission re-run.
**Next:** Re-run dose_response.m from root to verify panel 2B exports cleanly. Verify paper/images/supplementary/ directory exists for figM.

### 2026-05-31 — Full figure/panel audit: script fixes + PAPER.md registry corrections
**Changed/Found:** `utils/analysisPlots_combined.m`, `controller-analysis/variance_mse.m`, `controller-analysis/step_response.m`, `controller-analysis/tf_fit.m`, `PAPER.md` — Systematic audit of all paper panel generation scripts vs PAPER.md registry. Fixes applied: (1) panel_A legend ItemTokenSize [16 4]→[6 6]; (2) variance_mse fig_F shortCornerAxes_plot added PS constants (LineWidth 2.5→1.5, LabelGap 0.04→0.05, FontSize+FontWeight propagated); (3) variance_mse fig_G2v legend ItemTokenSize [8 4]→[6 6]; (4) step_response.m step figure raw figure()→paperFig(6,4), shortCornerAxes LineWidth 2→PS.sca_lw=1.5, variance label FontSize 7→6, spont figure legend ItemTokenSize [14 6]→[6 6] with bold font; (5) tf_fit.m fig_tf_paper size 10→12 cm (matches PAPER.md 3K=12×4). PAPER.md: corrected panel sizes 3D(8.9×3.5→3×3.5), 3E(8.9×3→3×3), 3H(9×4→8×4), 3F(3.5×3→3×3.5); added panels 3I and 3J (variance ratio, MSE ratio); renumbered TF panel to 3K; added widebrain_arx.m and motion_analysis.m Fig4 panel registry; updated uniformity checklist.
**Why:** Panel sizes in PAPER.md were inconsistent with actual script output (D/E wrong by factor ~3×, G wrong by 1 cm). Style constants (LineWidth, LabelGap, ItemTokenSize) were hardcoded in several scripts rather than drawn from paperStyle(), creating drift risk. Panels 3I/3J and all Fig4 widebrain panels were absent from the registry.
**Next:** (1) Confirm step_response.m variance trace is using correct sessions (custom_idx=[4 9 11]); (2) Decide whether 3I/3J go into the paper or supplementary; (3) Fix K-figures and spectral figures to use paperFig() when they are finalised for paper; (4) Fix fig_G2a mean LineWidth 2→1.5 when that panel is activated.

### 2026-05-29 — prestim_variance.m: log color scale + 1/f-corrected K1 heatmap (controller)
**Changed/Found:** `controller-analysis/prestim_variance.m` — K1 figure (pre-stim variance sorted spectral heatmap): added `'ColorScale','log'` to both OL and CL imagesc axes; clim lower bound clamped to a positive minimum. Added new figure K1_1f: 1/f correction (divide each frequency band by its centre frequency before plotting), also on log scale, exported to `paper/freq_heatmap_prestimvar_1f.png`.
**Why:** Log scale reveals structure in low-power high-frequency bands hidden by the 1/f spectral tilt. 1/f version shows whether elevated low-frequency power is purely spectral-tilt or a true excess.
**Next:** Compare K1 vs K1_1f — if 1-2 Hz elevation persists after 1/f correction it is a genuine excess above the 1/f baseline. Show Nick both versions.

### 2026-05-29 — variance_mse.m: G2r expanded to 4 windows (pre / 0-1 s / 1-3 s / post)
**Changed/Found:** `controller-analysis/variance_mse.m` — Fig G2r (OL/CL MSE ratio): was 2 windows (0-1 s, 1-3 s); now expanded to 4 windows adding pre (-3 to 0 s from pncDfk_l) and post (beyond +3 s from ncDfk tail). Mean ratios: Pre=0.980, 0-1 s=1.184, 1-3 s=1.528, Post=0.995. Exported `paper/images/figure3/MSE_ratio_by_window.pdf`.
**Why:** User request to show the full temporal profile including pre and post windows, to demonstrate that OL/CL difference is stimulus-locked (not a baseline shift).
**Next:** Check whether post window has enough samples (only ~1 s in ncDfk, 35 cols); consider adding pncDfk post-stim window if longer post period is needed.

### 2026-05-29 — variance_mse.m: Fig Fr (3I) significance stars via Wilcoxon signed-rank
**Changed/Found:** `controller-analysis/variance_mse.m` — Fig Fr (OL/CL variance ratio by window): added `signrank` tests comparing per-session OL vs CL variance for each window (pre/stim/post). Results: p_pre=0.34 (ns), p_stim=0.0005 (***), p_post=0.64 (ns). Star annotation placed above each bar. Exported `paper/images/figure3/variance_ratio_by_window.pdf`.
**Why:** User request to annotate statistical significance on panel 3I to show that the OL>CL variance difference is specific to the stimulus window.
**Next:** Verify that Wilcoxon is appropriate here (paired, non-normal distributions likely) — confirmed appropriate. Stars convention: * p<0.05, ** p<0.01, *** p<0.001.

### 2026-05-29 — prestim_variance.m: grayscale amp colors + ylabel "impulse prediction error"
**Changed/Found:** `impulse-analysis/prestim_variance.m` — (1) `ampCmap_pam` changed from `cool(nV_pam)` to a grayscale ramp `linspace(0.85, 0.20, nV_pam)` replicated to Nx3, matching the Fig 2A amp-level grading. (2) ylabel changed from `'Mean |peak dev| +/- SEM (\DeltaF/F %)'` to `'impulse prediction error'`.
**Why:** Nick meeting 2026-05-29: unify color scheme across all Fig 2 panels; ylabel updated for clarity at journal style.
**Next:** Regenerate figure on server with allExperiments populated; check legend readability with dark-on-white grays.

### 2026-05-29 — motion_analysis.m: ylabel "impulse prediction error" + legend Box off
**Changed/Found:** `impulse-analysis/motion_analysis.m` — (1) ylabel for `fig_mv` (paper panel 2F, single session) changed from `'|Peak dev| (\DeltaF/F %)'` to `'impulse prediction error'`. (2) `'Box', 'off'` added to the `legend()` call for `lg_mv`.
**Why:** Nick meeting 2026-05-29: consistent ylabel wording across Fig 2 scatter panels; remove legend box border.
**Next:** Regenerate 2F on server; confirm legend box is gone and marker labels show correctly.

### 2026-05-29 — tf_fit.m: grayscale amp colors + "Session 1" title for Fig 2C
**Changed/Found:** `impulse-analysis/tf_fit.m` — (1) `cRep = parula(nRep + 2)` replaced with a grayscale ramp `linspace(0.85, 0.20, nRep)` (Nx3 RGB), matching Fig 2A amp-level color scheme. (2) `title(ax_A, 'Session 1', ...)` added in Session 1 blue `[0.2 0.4 0.8]` at FontSize 6 bold.
**Why:** Nick meeting 2026-05-29: unify all single-session panels under the same grayscale amp scheme; title identifies the session for the multi-session Fig 2B context.
**Next:** Regenerate Fig 2C on server; verify grayscale line legibility and title placement.

### 2026-05-29 — Meeting parsed: Nick/Aditya 2026-05-29
**Changed/Found:** `MEETINGS.md` — parsed May 29th meeting transcript. Added 7 new action items (2026-05-29.1–7); updated open items header; added new meeting entry and Spatial Spread section.
**Why:** Routine meeting parse. Key new directions: unify disturbance-figure color scheme; add significance stars to variance-ratio stem plot; log-scale power spectra color axis; SVD-based contralateral predictor; widefield GUI spatial-spread characterization; new mouse sine-wave session protocol.
**Next:** Prioritize 2026-05-29.1 (color scheme) and 2026-05-29.2 (significance stars) as they gate the disturbance figure completion. Check SVD cumulative-variance curve before committing to component count for contralateral model.

### 2026-05-28 — widebrain_arx WB-artifact: empirical laser artifact characterization
**Changed:** `controller-analysis/widebrain_arx.m` — added `%% [WB-artifact]` section. Stacks OL trial windows per contra predictor pixel and trial-averages to get the empirical laser artifact template. Computes `art_amp` (mean dF/F, baseline-corrected) and `art_snr` (artifact / pre-trial noise floor). Produces two figures: `wb_artifact_traces.png` (temporal profiles of all contra pixels + primary OL mean) and `wb_artifact_map.png` (brain maps of amplitude and SNR with dual-axes overlay).
**Why:** Prediction from contaminated or decontaminated contra signals is unreliable. OL trials provide a ground-truth measurement of what the laser does to each contra pixel — no model assumptions, no subtraction algebra. This characterization is the honest first step before deciding whether contra-based prediction is viable at all.
**Next:** Run WB-artifact; inspect art_snr map — if most contra pixels have SNR > 1, prediction from trial contra is dominated by laser propagation and contra-based ARX is invalid for trial windows. Use art_amp as the contamination budget to decide which pixels (if any) are usable.

### 2026-05-28 — widebrain_arx WB-1e: pre-trial counterfactual prediction
**Changed:** `controller-analysis/widebrain_arx.m` — added `%% [WB-1e]` section. For each OL/CL trial, builds the ARX lag matrix from the pre-trial contra window (`buf_pre = mlag_wb + outlen_m` frames, ending 1 frame before onset). All X lags are spontaneous → zero laser contamination by construction, no decontamination algebra needed. Predicts primary pixel activity as if no input was applied. Reports `R2_nc_pre`/`R2_wc_pre`, exports `wb_pretrial_cf.png` with actual vs pink vs pre-trial CF overlay.
**Why:** Trial-window contra signals (WB-1b) are contaminated by laser propagation. WB-1c/1d try to subtract contamination; WB-1e sidesteps it entirely by using only pre-onset data. R² gap between pink and CF shows how much the contamination inflates the pink prediction.
**Next:** Run WB-1e; compare R2_nc_pre vs R2_nc_m — if CF R² is lower, contra pixels during trials carry laser-driven signal that the ARX exploits. Check if CF prediction is closer to actual CL (controller holding primary near spontaneous level).

### 2026-05-28 — widebrain_arx WB-1d: dual-axes fix for alpha spatial map
**Changed:** `controller-analysis/widebrain_arx.m` — replaced single axes in the alpha map figure with two overlapping axes: `ax_bg` (gray colormap, brain image, clim at image percentiles) and `ax_sc` (transparent background, hot colormap, `clim` scaled to `[min(alpha_wb), max(alpha_wb)]`). Scatter dots were all black because MATLAB uses one colormap per axes and the single large image clim swamped the small alpha values.
**Why:** Per-pixel laser-coupling (alpha) values are ~O(0.01) while brain image pixel values are ~O(1000); with one axes the scatter dots all mapped to the bottom of the gray colormap → black. Dual-axes with independent clim/colormap is the standard MATLAB workaround.
**Next:** Run WB-1d end-to-end; verify alpha dots are visible with hot coloring and primary pixel cyan cross is overlaid correctly.

### 2026-05-28 — widebrain_arx: primary pixel uses data_wb.dFk; k_pred for predictor kernel
**Changed/Found:** `controller-analysis/widebrain_arx.m` — (1) Primary pixel y_full now taken directly from data_wb.dFk (same signal as controller analysis / getpixel_dFoF pipeline) instead of SVD reconstruction. (2) k_wb renamed to k_pred — applies only to predictor pixel SVD kernel (1→3×3, 2→5×5, etc.). (3) Cache validity now checks k_pred and pred_px/pred_py; cache save stores k_pred. Length mismatch between data_wb.dFk and nFrames triggers a warning and truncates to shorter.
**Why:** y_full should match the actual controller signal. Predictor pixels are new (not in session cache) so must still use SVD; k_pred lets the user control spatial smoothing on those pixels independently.
**Next:** Set recompute_svd=true to rebuild cache with new y_full source; run WB-1a to check R2_test.

### 2026-05-27 — dose_response.m: swap to IQR, fix non-ASCII, export to supplementary
**Changed/Found:** `impulse-analysis/dose_response.m` — plot 2 changed from 95th-percentile bounds to IQR (p25/p75); section header and fprintf updated; ylim set to auto on plot 2; export path changed to `paper/images/supplementary/imp_response_median_IQR.png`; all non-ASCII bytes removed (mojibake `a--` on section header was final remnant at byte 4172)
**Why:** Median +/- IQR is the more informative supplementary panel (shows trial distribution spread); 95th-pctile error bars were excessively wide; supplementary directory keeps it separate from paper panels
**Next:** Verify supplementary directory exists before running; confirm IQR plot renders correctly in MATLAB

### 2026-05-27 — annotation pass: \todo flags for all open issues, pushed to GitHub
**Changed/Found:** `Closedloop_edit/results_edit.tex`, `methods_edit.tex` — added \todo{} flags at every open issue location: wrong variance claim (FACTUALLY WRONG — post-onset slope data), 2-vs-3 mice inconsistency, Fig 2B caption terminology (Peak suppression → Inhibition energy), MSE window in Fig 3E caption (3 s → +1 to +3 s), step-response steady-state note, brain-states section placeholder with full content spec, variability section contradiction, latency 47 ms vs 80 ms inconsistency + 60-frame/1-s error + beat-frequency artifact, TF model-order inconsistency + held-out R², missing spatial spread supplementary panel, missing algorithm pseudocode block, MSE window verification and missing motion-vs-MSE panel. Pushed to GitHub (`ddbfce1`).
**Why:** User wants to address all open issues directly in Overleaf; \todo{} flags render as red [NOTE:] boxes in the compiled PDF at the exact problem location.
**Next:** Pull from GitHub into Overleaf. Work through red notes in priority order: (1) factually wrong variance claim → (2) mouse count → (3) MSE window + caption → (4) fill Kp/Ki → (5) run TF fit across all 3 sessions.

### 2026-05-27 — widebrain_arx WB-1c: spatial map of pixel traces on brain image
**Changed/Found:** `controller-analysis/widebrain_arx.m` — added new `%% [WB-1c]` cell between WB-2 and WB-3. Extracts trial-averaged traces for all predictor pixels (X_full columns) plus primary pixel (actual_nc_m/actual_wc_m), places each as a mini-axes at its spatial location on a faded brain image. OL left panel, CL right panel. Red border = primary pixel; cyan border = contra-primary. Shared y-limits across all pixels and conditions. Exports wb_spat_traces.png at 300 dpi.
**Why:** Evaluation figure to visually inspect which pixels respond and whether OL/CL differ spatially.
**Next:** Verify mini-axes positions look sensible; may need to tune mw_s/mh_s if pixels are densely packed or very sparse.

### 2026-05-27 — widebrain_arx WB-1b: add individual trial traces for evaluation
**Changed/Found:** `controller-analysis/widebrain_arx.m` — WB-1b figure now plots up to 10 individual trial traces (thin, 25% alpha) per condition (OL and CL) behind the mean line; trial count shown in panel title; export changed from PDF to PNG 300 dpi.
**Why:** User wanted to visually inspect trial-to-trial variability for evaluation; not a paper panel so PNG is correct.
**Next:** Verify alpha transparency renders correctly in MATLAB; check that 10 complete (non-NaN) trials exist in both nc and wc.

### 2026-05-27 — methods_edit.tex: add missing analysis sections
**Changed/Found:** `Closedloop_edit/methods_edit.tex` — added inhibition energy quantification (0–200 ms mean, eq:inhib_energy), transfer function fitting (tfest sweep 1–3 poles/0–2 zeros/0–5 delay, AIC, LOAO CV), MSE window note (+1 to +3 s post-onset), and new "Offline data analysis" subsection with: cross-session pooling (n=13 sessions), motion exclusion (motThresh=1.5), power spectral analysis (absolute (ΔF/F)²/Hz), pre-stimulus state analysis, widebrain ARX model (3 nested layers). Also fixed impulse response protocol text which wrongly said "mean peak suppression" instead of referencing inhibition energy.
**Why:** Impulse and controller analyses were not documented in Methods; the mean-peak wording contradicted the locked-in peak_mode=3 decision; MSE window and motion exclusion criteria were not stated anywhere in the manuscript.
**Next:** Verify that results_edit.tex refers to "inhibition energy" consistently (currently says "peak %ΔF/F suppression"); fill in Kp/Ki placeholders; resolve 2-vs-3 mice discrepancy between Fig 3 caption and Results text.

### 2026-05-27 — widebrain_arx: add [WB-1a-tune] pX order-selection section
**Changed/Found:** `controller-analysis/widebrain_arx.m` — inserted `%% [WB-1a-tune]` between WB-1a and WB-1b. Sweeps `pX_cands = [2 4 6 8 10 12 15 20 25 30]`; computes BIC and 5-fold CV R^2 on training trials only (test set untouched). Prints BIC-selected and CV-selected pX vs current; plots BIC-min(BIC) and CV R^2 curves with vertical markers.
**Why:** Avoid exhaustive test-set search (biases reported R2); BIC is the classical method for ARX order selection (no held-out data needed); 5-fold CV provides a non-parametric cross-check.
**Next:** Run WB-1a to build spont_y/spont_X/train_idx, then run WB-1a-tune to see BIC optimum; update pX in WB-1a if different, re-run both, then proceed to WB-1b.

### 2026-05-27 — widebrain_arx: WB-5 bar figure completed + file truncation repaired
**Changed/Found:** `controller-analysis/widebrain_arx.m` — file was truncated at `for g = 1:3` (same in HEAD); added bar/errorbar loop body, axis formatting, and PNG export for the OL/CL/Optimal grouped bar chart. Confirmed truncation pre-dated this session via `git show HEAD`. No local `buildLagMatrix` needed (utils/ version already on path). Two info-level style warnings (`try;` syntax) left as-is; not errors.
**Why:** WB-5 was the only incomplete section; script now runs end-to-end without syntax gaps.
**Next:** Set `redefine_roi = true`, run ROI section to generate `wb_roi_<session>.mat` with the new grid, then run WB-1a and verify R2_test > 0.3.

### 2026-05-27 — Split plottingScript.m and Impulse_mouseDataAnalysis_all.m into per-section files
**Changed/Found:** `controller-analysis/` and `impulse-analysis/` — created 7 + 8 split .m files extracted from the two root scripts; originals unchanged
**Why:** Scripts are 3557 and 1748 lines respectively; splitting into load_sessions/load_experiments loaders plus themed figure scripts allows targeted iteration without scrolling; files share the base workspace (no clear between them)
**Next:** Confirm each figure script runs correctly after its loader; update controller-analysis/CLAUDE.md primary-script reference once originals are retired

### 2026-05-27 — Decision: controller analysis result caching architecture (deferred task)
**Changed/Found:** `TASKS.md` — logged future caching work. Three new per-session files proposed: `wb_model.mat` (ARX beta + TF fit), `wb_pred.mat` (pink/orange/red predictions + R²s + WB-5 MSEs), `cross_session_cache.mat` (pooled motion/pre-stim/spectral arrays). Cache-invalidation pattern: compare stored params (pX, grid_rows, grid_cols) against current values before deciding whether to recompute.
**Why:** ARX lstsq, tfest, and cross-session aggregation are recomputed every run unnecessarily; user wants to avoid this without restructuring the analysis flow now.
**Next:** Implement when WB pipeline is stable and parameter tuning is done.

### 2026-05-27 — widebrain_arx: grid strategy → rows×cols parameters, drop outside-ROI nodes
**Changed/Found:** `controller-analysis/widebrain_arx.m` — replaced `nPred=20` fixed count with `grid_rows=6` / `grid_cols=5` design parameters. Grid generates `grid_cols × grid_rows` cell-centre nodes over the ROI bounding box; each is rounded to the nearest pixel and checked against the eroded interior mask via `interior(sub2ind(...))`. Nodes outside the mask are discarded — no dsearchn snapping. `nPred` is now derived as `length(pred_px)` after filtering. Legend updated to 'Grid pixels'. `roi_file` now also saves `grid_rows`/`grid_cols` for provenance.
**Why:** User wanted grid count to be determined by the ROI shape, not a preset target; outside-ROI nodes should vanish, not be forced inward.
**Next:** Set `redefine_roi=true`, run ROI definition section, check pixel map (expect up to 30 nodes, some dropped by ROI boundary), then set `redefine_roi=false` and run WB-1a.

### 2026-05-27 — plottingScript: WB grid fix — visual row/col confusion corrected + edge-pixel erosion
**Changed/Found:** `plottingScript.m` lines 2944-2984 — (1) Due to `imagesc(mimg_wb')` transposing display, visual rows correspond to original col (c) direction and visual cols to original row (r) direction. Previously `n_vis_rows` was incorrectly adding to the r direction (visual cols). Fixed: `n_vis_cols=ceil(sqrt(n_grid))` controls `r_lin`, `n_vis_rows=n_vis_cols+1` controls `c_lin`. (2) Pixels were snapping to polygon boundary. Fixed: erode `valid_mask` by `margin_px=4` via `conv2` (no toolbox), use eroded `interior` mask as candidate pool for `dsearchn`. (3) Pixel map legend updated from 'Random contra' → 'Grid pixels'.
**Why:** User pointed out an extra visual column was added instead of extra row; pixels landing on polygon edge.
**Next:** Run widebrain section with redefine_roi=true to regenerate wb_roi_<session>.mat with 5-col × 6-row grid (30 nodes → 19 unique interior pixels + 1 contra-primary = 20 total). Verify pixel map, then set redefine_roi=false and run WB-1a to check R2_test.

### 2026-05-27 — plottingScript: widebrain ROI — session-keyed save, pure grid sampling
**Changed/Found:** `plottingScript.m` — (1) `redefine_roi` default → false. (2) ROI now saved/loaded as single session-specific file `wb_roi_{fields{wb_sel}}.mat` (replaces generic midline.mat + contra_pixels.mat). (3) Removed random jitter from grid pixel sampling — grid is now purely deterministic (cell-centre nodes, snapped to nearest valid pixel via dsearchn). WB-1a/1b split also applied in same session.
**Why:** User wants deterministic pixel selection and persistent per-session ROI so re-running the section never triggers interactive picker.
**Next:** Set redefine_roi=true once to define the ROI for wb_sel=12, then set back to false permanently.

### 2026-05-27 — plottingScript: fresh WB-1 to WB-5 implementation appended (lines 3195–3498)
**Changed/Found:** `plottingScript.m` — Replaced plan-comment block with full runnable implementation of five widebrain sections: WB-1 (pink+motion ARX, 4-panel export to wb_pink_4panel.pdf), WB-2 (orange = pink + mean OL residual), WB-3 (red = pink + per-trial lsim TF response, fits best_wb via tfest on wb_sel OL average), WB-4 (two-panel overlay OL/CL vs pink/orange/red, wb_three_layers.pdf), WB-5 (Toeplitz optimal laser, gap ratio bar chart, wb_mpc_gap.pdf). All exports to paper/images/figure4/.
**Why:** User requested fresh implementation of the full three-layer contralateral prediction analysis.
**Next:** Run WB-1 first — check R2_spont, then R2_OL/R2_CL. If R2_spont < 0.3, increase nPred or check ROI. Run WB-3 and confirm R2_wc_red > R2_wc_pink (key validation). WB-5 gap ratio is the MPC motivation number.

### 2026-05-27 — plottingScript: widebrain three-layer plan appended (WB-1 through WB-5)
**Changed/Found:** `plottingScript.m` — Appended five commented skeleton sections after line 3192 covering the full widebrain prediction completion: WB-1 (pink layer + motion co-predictor + export), WB-2 (orange = pink + mean OL residual), WB-3 (red = pink + per-trial TF laser response), WB-4 (three-layer overlay paper figure), WB-5 (post-hoc optimal laser / MPC gap). Variable names match existing workspace. Key dependency noted: best_wb TF must be fit for wb_sel session separately from ol_sess_idx sessions.
**Why:** Nick decisions Apr-27 + May-11 call for three-layer contralateral model and MPC motivation; current code only has pink layer.
**Next:** Implement WB-1 first (set redefine_roi=false, add motion column, verify R2_spont > 0.3, add exportgraphics). Then WB-2 and WB-3 in order.

### 2026-05-26 — plottingScript: pre-stim dev vs MSE → quartile bins + ranksum, paper panel Figure 4
**Changed/Found:** `plottingScript.m` — Replaced linear-fit scatter in `%% Pre-stim state vs trial MSE` with quartile-binned mean ± SEM + Wilcoxon ranksum p-values (stars: */(**)/***/ns). Bin edges from pooled OL+CL |deviation|. paperFig(6,4), axes position [0.18 0.22 0.76 0.60] (headroom for stars). Exports vector PDF to `paper/images/figure4/prestim_dev_vs_mse.pdf`. Data pooling loop unchanged.
**Why:** Linear fit doesn't directly show OL vs CL distinction; quartile bins + ranksum makes the comparison explicit per deviation level.
**Next:** Run section; check p-values printed to console. If Q3/Q4 are significant and Q1 is not, that confirms deviation-dependent feedback benefit.

### 2026-05-26 — plottingScript: pre-stim ΔF/F deviation vs trial MSE scatter (all sessions pooled)
**Changed/Found:** `plottingScript.m` — Added new `%%` section immediately after line 992 (`%% Motion vs MSE`). Pools all sessions (skip-checked). X = signed ΔF/F at stim onset − d.ref (%), Y = er_ncDfk (norm, t=0→+3 s). OL (red) + CL (green) scatter, OLS regression lines with slope ± SE and r² annotations. paperFig(6,4) + paperStyle(). Exports to `paper/prestim_dev_vs_mse.png`. Distinct from existing `onset_dev` section (which uses absolute deviation and er_ncDfk_w t=+1→+3 s).
**Why:** User requested OL/CL comparison of ΔF/F deviation from ref at trial start vs trial MSE, all sessions pooled.
**Next:** Run section; check if OL slope is significantly steeper than CL slope (key claim). If result is clean, designate as paper panel for Figure 4.

### 2026-05-26 — plottingScript: motion quartile vs MSE paper panel for Figure 4
**Changed/Found:** `plottingScript.m` — Added paper-styled export inside the motion-vs-MSE loop for the `combined` mode (2 s pre + full trial). Creates a `paperFig(6,4)` with `paperStyle()` constants (6 pt bold, lw_mean=1.5, MarkerSize=3, ItemTokenSize [6 6]) and exports vector PDF to `paper/images/figure4/motion_quartile_combined.pdf`. MSE metric is `er_ncDfk` / `er_wcDfk` = norm(dFk − ref) over t = 0 to +3 s. PNG exploratory versions for all three modes are unchanged.
**Why:** User designated the combined-mode motion-quartile plot as Figure 4 paper panel.
**Next:** Verify exported PDF in Illustrator; check axis limits and tick labels look clean at 6 cm width.

### 2026-05-26 — Impulse: paper figure — pre-trial variance vs deviation, motion-excluded
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Added motion-excluded version of the paper figure. Same layout as all-trials version (mean |peak dev| +/- SEM per quintile, all amps overlaid) but top 25% motion trials removed per-session (threshold = 75th pctile of all motion values across amps). Deviation recomputed on kept trials. Exports to paper/images/figure2/prevar_vs_dev_allamps_motexcl_<session>.pdf.
**Why:** Shows that the variance-deviation relationship holds even after removing motion-contaminated trials, ruling out motion as a confound.
**Next:** Compare slopes/pattern to all-trials figure. If lines are steeper or cleaner, the relationship is not motion-driven.

### 2026-05-26 — Impulse: paper figure — pre-trial variance vs peak deviation all amps
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Added paper-ready section after line 1289 diagnostic block. One axis, all valid amplitudes overlaid as separate colour-coded errorbar lines (cool colormap). X = mean pre-trial variance per quintile bin, Y = mean |Peak dev| +/- SEM. Exports to paper/images/figure2/prevar_vs_dev_allamps_<session>.pdf (vector).
**Why:** Condenses the per-amplitude multi-subplot diagnostic into a single publishable panel showing the consistent variance-deviation relationship across all stimulus amplitudes.
**Next:** Run section after main loop. Check all amplitude lines show monotonic increase. If consistent, add to FINDINGS.md as supporting evidence.

### 2026-05-26 — Impulse: 3 non-normalised brain-state figures replace normalised ones
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Added allDev_p (absolute |Peak_imp - mean|, dF/F) to pooling loop. Replaced old normalised figures with: (1) spectral heatmap sorted by pre-trial variance + deviation side-strip colourbar; (2) scatter: pre-trial variance vs |deviation|; (3) scatter: 2-4 Hz power vs |deviation|. Exports: paper/prevar_sorted_heatmap_dev.png, paper/dev_scatter_prevar_freq24.png.
**Why:** All quantities now in physical dF/F units, not normalised. Cleaner for paper claim and cross-session comparison.
**Next:** Run brain-state section then new figure sections. Compare r(2-4Hz) vs r(broadband). If r(2-4Hz) is largest, add to FINDINGS.md.

### 2026-05-26 — Impulse: freq section restructured + 2 new brain-state figures
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — (1) Spatial spread analysis moved to its own %% section. (2) Superseded pre-trial variance standalone block (Section B) removed. (3) Brain-state section cleaned up, fbCtrs bug fixed (→ freqBandCtrs). (4) New fig: pre-trial variance sorted heatmap with freq bands + deviation side-strip → paper/prevar_sorted_heatmap_freq.png. (5) New fig: 2–4 Hz band power vs normalised prediction error, tertile-coloured → paper/freq24_vs_deviation.png.
**Why:** Show that high 2–4 Hz power at stim onset predicts worse impulse response prediction. Restructure separates spatial analysis from brain-state analysis.
**Next:** Run new figures in MATLAB. Check if 2–4 Hz r is larger than other bands. If yes, add to FINDINGS.md as supporting evidence for the 2–4 Hz claim.

### 2026-05-26 — plottingScript: onset-deviation scatter + variance slope line unification
**Changed/Found:** `plottingScript.m` — (1) Added fig_onset_dev: pooled per-trial |ΔF/F at onset| vs windowed MSE scatter, OL vs CL with regression lines; exported to paper/onset_dev_vs_mse.png. (2) Unified pre/post slope line dash pattern in onset_variance_slope figure (fig_ov).
**Why:** (1) Tests whether CL decouples initial brain state from trial outcome. (2) Visual consistency for paper panel 2E.
**Next:** Check if OL slope is significantly steeper than CL — if yes, add to FINDINGS.md and manuscript.

### 2026-05-26 — Project documentation restructure
**Changed/Found:** `CLAUDE.md`, `TASKS.md`, `RESEARCH.md`, `PAPER.md`, all sub-area `CLAUDE.md` files — full restructure of project coordination docs. Created `FINDINGS.md` as analysis→paper bridge. Rebuilt `TASKS.md` as prioritised TODO (🔴/🟡/🟢). Added area-detection rule and locked-in decisions to root `CLAUDE.md`. Slimmed sub-area CLAUDE.md files from 130–175 lines to ~35 lines each. Stripped stale task tracker from `RESEARCH.md` (kept change log). Removed pasted review text from `PAPER.md`.
**Why:** Eliminated TODO scatter across 4–5 files, reduced per-session token cost, established FINDINGS.md as the single handoff point between analysis and paper-writing sessions.
**Next:** At start of next session, verify area-detection works — say "controller area" and check Claude reads `controller-analysis/CLAUDE.md` without being told explicitly.

### 2026-05-26 — Pooled motion scatter: shuffle trial order + Session N labels
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — pooled `fig_mvp`: (1) `randperm` shuffle (`rng(0)`) applied to all pooled arrays before plotting so session 3 (largest) does not dominate by draw order. (2) Per-point colour passed as N×3 `cMat = expColors(allExp_s,:)` — two scatter calls (one per marker class) replace old per-session loop, avoiding the O(N) scatter call loop. (3) Legend session labels changed from `allExperiments(expIdx).mn` (mouse ID) to `sprintf('Session %d', expIdx)`.
**Why:** Third session had the most trials and was drawn last, visually burying sessions 1 and 2. Shuffle ensures all sessions are interleaved on the z-stack. Mouse IDs are not meaningful in the paper context.
**Next:** Run section 1038; confirm sessions are visually mixed; check legend shows Session 1/2/3 + o/^ entries.

### 2026-05-26 — Pooled motion scatter: session colour + marker shape for motion class
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — pooled `fig_mvp` rewritten. Adds `allExp_pool` to track session index per trial. Scatter loops over `expIdx × k` (session × motion class); colour = `expColors(expIdx,:)` (same as dose-response figures); marker = `o` for No motion, `^` for Motion. Legend shows one entry per session (circle, session colour) plus two shape entries (o/^ in grey). `binColors_m` no longer used in pooled figure.
**Why:** User wants session identity visible via colour (consistent with rest of script) and motion class via marker shape rather than colour.
**Next:** Run section 1038; check legend is not too crowded; verify markers are distinguishable at print size.

### 2026-05-26 — Added pooled-sessions motion scatter (paper panel 2F-pool)
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — added `fig_mvp` after single-session `fig_mv`. Loops over all `nExp` experiments and all amplitudes; pools `allAbsDev_pool` and `allMot_pool`. Binary No motion/Motion classification using same `motThr_hi` and `iMot_a` as single-session figure. Exports to `paper/images/figure2/imp_motion_devscatter_all_sessions.pdf` (6×4 cm vector). Registered in PAPER.md as panel 2F-pool.
**Why:** Single-session figure (selExp_mot=3) only uses one session; cross-session pooling gives more statistical power and generalisability for a paper panel.
**Next:** Run section 1038 to verify both figures export; compare r values between single-session and pooled.

### 2026-05-26 — Motion scatter figure promoted to paper panel 2F
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Figure 2 (motion z-score vs |Peak dev|) resized from `paperFig(6,6)` to `paperFig(6,4)` to match Figure 2 panel standard. Export added: `paper/images/figure2/imp_motion_devscatter_*.pdf` (vector). Registered as panel 2F in PAPER.md (Figure 2 Row 2) and in the Impulse figure reference table.
**Why:** User assigned this scatter as paper panel for Figure 2; 6×4 cm matches all other Figure 2 panels (2C, 2E).
**Next:** Run section 1038 in MATLAB to verify export lands in paper/images/figure2/.

### 2026-05-26 — Motion-sorted section simplified to 2 figures with binary classification
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — `%% Motion-sorted figures` (lines 1038–1241) rewritten. Removed residual heatmap and 3-class tertile logic. Now produces exactly 2 figures: (1) trial rank vs |Peak dev|, (2) mean motion z-score vs |Peak dev|. Both use binary classification — No motion (mot ≤ motThr_hi, blue) vs Motion (mot > motThr_hi, red) — driven by local `binColors_m`/`binLabels_m`. Fig 2 adds `xline(motThr_hi, 'k--')`. Legacy pool loop kept for downstream pre-variance sections.
**Why:** User wanted uniformity and simplicity: only 2 figures, only 2 categories, same colours. 3-class (Low/Mid/High) kept in section 945 per-amp scatter; section 1014 is the pooled session-level view where binary contrast is cleaner.
**Next:** Run parameter cell → main experiment loop → section 945 → section 1014. Verify figures export to paper/images/.

### 2026-05-26 — Motion normalised to mean z-score; fixed-threshold Low/Mid/High classification
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — (1) All motion energy computations changed from `sum(motTrace, 2)` → `mean(motTrace(:, iMot_a), 2)`. (2) Tertile classification in sections 945 and 1014 changed from rank-based equal-thirds (`quantile([1/3 2/3])`) to fixed SD thresholds: `motThr_lo = -0.5`, `motThr_hi = 0.5`. Classification: mot < −0.5 → Low, −0.5 ≤ mot ≤ 0.5 → Mid, mot > 0.5 → High. (3) Shared colour/label variables (`tertColors_mot`, `tLabels_m`) moved to parameter cell.
**Why:** `sum` scales with window length so changing `motWin_ana` distorts values. Mean z-score is window-length invariant and session-comparable since mv_z is already per-session z-scored. Equal-thirds classification made Low/High boundaries session-relative; fixed SD thresholds enable cross-session comparison.
**Next:** Verify that section 945 x-axis values fall roughly in ±2 range (typical z-score scale); confirm group sizes are unequal (actual distribution, not forced equal thirds).

### 2026-05-25 — Motion window made adjustable via motWin_ana parameter cell
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — new `%%` parameter cell added before line 945 with `motWin_ana = [-1.0, 0.5]`. Both analysis sections (945 and 1014) now compute motion on-the-fly via `sum(imp_e.motTrace{iAmp}(1:nUse, iMot_a), 2)` rather than reading `imp.mot`. `iMot_a` is the logical index into the ±3s `t_win_mot`/`t_full_mot` vector. Main loop reverted to ±35 samples (±1s) to keep pre-collected `imp.mot` wide. All xlabels use `sprintf('Motion (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2))`.
**Why:** User wants to explore different pre/post-stim windows without re-running the main data collection loop.
**Next:** Run parameter cell, then sections 945 and 1014; change motWin_ana to test e.g. [-1,0] pre-stim only.

### 2026-05-25 — Motion-sorted Fig 1: z-score → raw |deviation|; added Fig 4 scatter; fixed t_win_imp error
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — (1) `t_win_mot = t_win_imp` crashed (t_win_imp defined at line 1262, used at 952); fixed to `-tWin:1/35:tWin`. (2) Figure 1 changed from z-score scatter to raw `|Peak_imp − mean|` scatter; `allZdev_m`/`zdevSorted_m`/`sd_i` removed from data prep loop. (3) Added Figure 4: motion energy (X) vs `|Peak dev|` (Y) scatter with tertile colour — reuses `rA_m, pA_m` from Fig 1.
**Why:** User does not want z-score normalisation; wants raw deviation from expected inhibition energy. Separate scatter (Fig 4) makes the motion–deviation relationship directly visible with correct axes.
**Next:** Re-run main loop then motion sections 945 and 1014; verify 4 figures appear and Fig 4 r value matches Fig 1 title.

### 2026-05-24 — Motion window changed to −1 to +0.5 s
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — main experiment loop line ~294: `i1_mot` changed from `bAll + 35` (+1 s) to `bAll + 18` (+0.5 s, 18/35 = 0.514 s). Labels in `%% Motion vs Peak_imp deviation` (line 947, 996) and `%% Motion-sorted figures` (line 1023) updated. Also fixed `t_win_mot` from `-1:1/35:1` (71 pts) to `t_win_imp` (211 pts) to prevent size mismatch in `motionDetailCallback`.
**Why:** Pre-stimulus brain state is the relevant predictor; post-stimulus motion is a consequence of the optogenetic response, not a cause. Truncating at +0.5 s reduces contamination. Callback bug (71 vs 211 pts) would have crashed on first click.
**Next:** Re-run main experiment loop (sections 1–3) to recompute `imp.mot` with new window; then re-run motion sections 945 and 1014.

### 2026-05-24 — Motion-sorted section replaced with 3 clean figures
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — `%% Motion-sorted figures` section (lines 1043–1334 replaced). Removed 6 old exploratory figures (per-amp heatmap, tertile traces, pooled deviation scatter, norm heatmap, devscatter+regression, quartile traces). Added: (1) z-score scatter (response z-score vs trial rank, tertile colour), (2) static residual heatmap (df_trial − amp-mean, −2→+2 s, blue-white-red) + |Peak dev| side strip, (3) same heatmap clickable via `heatmapMotionCallback`. Legacy pool loop kept (allDF_n etc.) for compatibility. Fixed `iCrop_mot`→`iCrop_new` in pool loop.
**Why:** User wanted exactly 3 publication-quality figures from this section; old code was exploratory and had dead variable `iCrop_mot` after params block rewrite.
**Next:** Run section in MATLAB; verify Fig 1 scatter ±1 SD lines, Fig 2 inhibition dip visible near t=0, Fig 3 click opens detail popup.

### 2026-05-24 — Impulse_mouseDataAnalysis_all: uniform x/y limits on motion vs prediction error subplots
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — `%% Motion vs Peak_imp deviation` section (line ~945). Added pre-loop before `for iAmp` that pools all `mot` and `Peak_imp_dev` values across amplitudes per experiment, then computes shared `xLim_m` / `yLim_m` (5% padding). Applied with `xlim`/`ylim` inside each subplot after `set(ax,...)`.
**Why:** Each subplot auto-scaled independently, making cross-amplitude comparison misleading.
**Next:** Run section; verify all subplots share the same axes and that the y-axis starts at 0.

### 2026-05-24 — Reroute paper panel exports to paper/images/figureN/ subfolders
**Changed/Found:** `utils/analysisPlots_combined.m`, `plottingScript.m`, `Impulse_mouseDataAnalysis_all.m`, `PAPER.md` — All paper panel exportgraphics/print paths updated: panel_A–E → figure3/, all_variance/MSE/average_sessions → figure3/, ol_tf_trial_avg → figure3/, svd_frame → figure1/, step_response + imp_response + tf_data_vs_model + tf_loao → figure2/. imp_single already in figure2/. PAPER.md registry paths updated to match. Exploratory analysis figures (freq heatmaps, motion, spont) stay in paper/.
**Why:** Organise outputs to match the paper/images/figure1–4 folder structure for Illustrator assembly.
**Next:** Re-run affected script sections to populate the subfolders with fresh exports.

### 2026-05-24 — Paper style unification: paperStyle() helper + all scripts updated
**Changed/Found:** `utils/paperStyle.m` (new), `utils/analysisPlots_combined.m`, `Impulse_mouseDataAnalysis_all.m`, `plottingScript.m` — Created `paperStyle()` returning a struct of shared constants (lw_mean=1.5, lw_fit=1.2, lw_trial=0.4, lw_ref=1.0, lw_inp=0.75, lw_zero=0.5, fs=6, fw='bold', fa=0.2, sca_lw=1.5, sca_gap=0.05). Updated all three scripts: switched `figure()` → `paperFig()` in analysisPlots_combined, removed two `PW=8` overrides (fixed to 8.9), adopted PS constants in all `shortCornerAxes_plot` calls (LineWidth 2→1.5, added FontWeight='bold', LabelGap 0.04/0.05→PS.sca_gap=0.05, XLabel '1 sec'→'1 s'), fixed legend `ItemTokenSize [8 4]→[6 6]`, fixed variance trace LineWidth 1→PS.lw_mean in panel D, added `PS = paperStyle()` at paper panel entry points in all three scripts.
**Why:** Enforce uniform scalebar style, line widths, font, and figure-creation path across all paper-generating scripts.
**Next:** Re-run analysisPlots_combined (call from plottingScript or directly) to regenerate panel_A–E with corrected widths; verify shortCornerAxes_plot renders at 1.5 lw across all panels.

### 2026-05-21 — Manuscript prose fixes and scientific-claim TODOs
**Changed/Found:** `Closedloop_edit/results_edit.tex`, `discussion.tex`, `main.tex`, `brain_paper/PAPER.md` — (1) Converted passive-voice constructions to active throughout Results: "was well approximated" → "obeyed", "was designed" → "We designed", "was shifted" → "shifted", "were achieved with" → "required only". (2) Fixed spacing and grammar: missing spaces before `(Fig.~`, `regions activity` → `region's activity`. (3) Added `\todo{}` inline notes for: slope ± CI and n=3 justification (linearity para), MSE window update (t=+1 to +3 s), Kp/Ki values, variance-onset quantification, batch-mean vs. batch-variance convergence. (4) Added four placeholder subsections at end of Results for: Curto & Issa trial-sorting, disturbance attribution (spectral/motion), three-layer contralateral-prediction model, and feedforward/preview control. (5) Fixed discussion.tex opening passive ("was driven" → "we drove", removed redundant equation ref from first sentence). (6) Added `% TODO` comment at author affiliations in main.tex. (7) Added "Scientific Claims to Fix" section to PAPER.md.
**Why:** User requested prose fixes from Text & Prose list and placeholder sections for pending analyses; scientific claims documented as TODOs per analysis dependency.
**Next:** Extract Kp/Ki from .mat session data; compute slope ± CI for linearity figure; verify Fig. S1 shows batch-mean convergence (not just variance); resolve step-response LTI tension.

### 2026-05-21 — plottingScript: K1z & K2z — z-scored heatmap + quintile MSE bars
**Changed/Found:** `plottingScript.m` — New section inserted after K2 (before K2i). Reuses `nc_all_k1`/`wc_all_k1` already accumulated by K1/K2. (1) K1z: z-scores each frequency band across all pooled OL+CL trials (`mu_f_z`, `sig_f_z`); applies blue-white-red diverging colormap with symmetric `clim`; MSE strip uses `hot` colormap with shared `clim` across OL and CL. (2) K2z: bins pre-stim variance into 5 equal-count quintiles using pooled edges; grouped bar chart of mean MSE ± SEM for OL (red) and CL (green) per quintile. Both exports commented out (no export per user preference).
**Why:** Raw absolute power heatmap (K1) is dominated by low-frequency power magnitude; z-scoring removes the mean spectral shape and shows relative trial-to-trial deviations, making 2–4 Hz elevations visible. K2 scatter makes OL/CL overlap hard to judge; quintile bars show the gap clearly per brain-state tier and whether the controller's advantage grows with pre-stim variance.
**Next:** Run section; check whether K1z shows a visible 2–4 Hz band in high-variance trials for OL; check whether K2z bar gap widens from Q1 to Q5.

### 2026-05-21 — Poster: all 12 figures inserted; Row 2 regrouped by experiment type
**Changed/Found:** `make_poster.py` + `poster_template.pptx` — 4 PDFs converted to PNG via pdftoppm (220 DPI, saved as `*_poster-1.png` in `paper/`); all 12 figures inserted with `add_picture()` at exact placeholder coordinates. Row 2 regrouped: B1=Impulse brain state (motion tertiles | freq band), B2=Controller brain state (motion quartiles | freq heatmap), instead of previous (motion: impulse+ctrl | freq: impulse+ctrl). C1 schematic left as placeholder for manual insertion.
**Why:** User wants real figures in poster; Row 2 grouping by experiment type (impulse vs controller) makes direct comparison cleaner.
**Next:** Insert experimental schematic into C1. Confirm imp_freqband amp5 is the right representative for B1 right, or generate a combined pre-stim-power vs inhibition figure.

### 2026-05-21 — Poster template revised: 8-section focused layout
**Changed/Found:** `make_poster.py` + `poster_template.pptx` (regenerated) + `paper-writing/POSTER_LAYOUT.md` (new) — restructured from generic 4+3 column layout to content-driven layout: C1=Intro+System, C2=LTI Validation (dose-response + impulse TF left/right + step TF full-width strip), C3=Controller Performance (variance/MSE/avg side-by-side + sine-wave strip), B1=Motion Dependence (impulse tertiles + controller quartiles), B2=Frequency Dependence (impulse freqband + controller spectral heatmap), B3=Conclusions. Removed spatial spread. Layout spec written to `paper-writing/POSTER_LAYOUT.md`.
**Why:** User specified 8 content areas: impulse linearity, impulse TF, step TF, controller F/G/H, sine-wave avg, motion dependence of both, frequency dependence of both.
**Next:** (1) Answer two open questions in POSTER_LAYOUT.md — impulse freq combined figure? motion scatter vs quartile? (2) Replace figure placeholders with actual PDFs. (3) Draw experimental schematic. (4) Fill Kp/Ki values.

### 2026-05-21 — Created UW-branded poster template (48" × 36" landscape)
**Changed/Found:** `make_poster.py` (new) + `poster_template.pptx` (generated) — Python script using python-pptx generates a 48" × 36" landscape PowerPoint with UW purple (#4B2E83) / gold (#85754D) branding. Layout: purple title bar, 4-column main row (Intro | System Design | Impulse LTI Validation | Controller Performance), 3-column supplementary row (Spatial Spread | Brain State/Spectral | Conclusions), purple footer. All figure panels are labelled gray placeholders referencing actual `paper/` export filenames.
**Why:** Preparing conference poster from paper, controller-analysis, and impulse-analysis content.
**Next:** Replace figure placeholders with actual exported PDFs/PNGs; fill in Kp/Ki values, author affiliations, grant info; adjust font sizes after printing at full scale.

### 2026-05-21 — Impulse_mouseDataAnalysis_all: pre-trial variance vs prediction error, all trials pooled
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — new `%%` section. Session 3, all amps pooled (no motion exclusion), normalised deviation. Trials sorted by pre-trial variance ascending (Y), prediction error on X, scatter coloured by variance tertile (blue/purple/red). Loess smooth (15% span) overlaid as black line showing trend. r and p from `corr` in title. Exports `paper/imp_prevar_deviation_*.pdf` + `.png` 300 DPI.
**Why:** Simple companion to the motion-sorted figures. Shows whether pre-trial neural variance predicts prediction error even when high-motion trials are retained.
**Next:** Run; expect positive trend (high-variance trials at top → larger prediction error on right); compare r here vs r in motion-excluded panel (if r drops after exclusion, variance effect is partly a motion artefact).

### 2026-05-21 — Impulse_mouseDataAnalysis_all: poster figure — brain state predicts impulse predictability
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — new `%%` section inserted before spatial spread. Session 3, all amps pooled, top-25%-motion trials excluded globally. Three panels: (A) freq heatmap (hot colormap, trials sorted by norm |deviation|, quintile boundary lines); (B) mean power per freq band per prediction-error quintile (5 overlaid lines Q1–Q5 blue→red, SEM shaded); (C) pre-trial variance vs norm |deviation| scatter coloured by motion tertile (excluded = only bottom 75%), `fitlm` regression + 95% CI, r and p in title. Exports `paper/imp_brainstate_poster_*.pdf` + `.png` at 300 DPI.
**Why:** Poster needs a single figure showing that neural state — spectral composition and pre-trial variance — predicts inhibition predictability independently of motion confounds.
**Next:** Run section; check Panel B Q1 vs Q5 lines diverge (expect Q5/high-error trials to have lower delta/theta power); check Panel C r direction (expect positive: higher variance → higher prediction error).

### 2026-05-21 — Impulse_mouseDataAnalysis_all: added Figs 4–6 (normalised pooled) + PNG exports for all motion figures
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — extended pooled loop to also track `ampIdx_n` and `devNorm_n` (|deviation|/|mean|). Added: Fig 4 (Option A) — normalised heatmap with amp-group colour strip + |deviation| strip, tiledlayout 1×20; Fig 5 (Option B) — scatter of motion vs normalised deviation, per-amp colours, `fitlm` regression + 95% CI, r and p annotated; Fig 6 (Option C) — quartile (Q1–Q4) mean ± SEM normalised traces. All 6 figures now export both PDF (vector) and PNG (300 DPI). Outputs: `imp_motion_normheatmap_*`, `imp_motion_devscatter_*`, `imp_motion_quartiles_*`.
**Why:** Poster presentation requires high-res PNG alongside vector PDFs. The three pooled-normalised figures directly show the motion–response-regularity relationship across all amplitudes.
**Next:** Run section; check Fig 5 regression direction (expect negative slope — more motion → lower normalised deviation); check Fig 4 amp strip and deviation strip align with heatmap row ordering.

### 2026-05-17 — Impulse_mouseDataAnalysis_all: motion-sorted heatmap + absolute deviation + normalised tertile traces
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — three figures produced from one `%%` section. Figure 1: per-amp heatmap (raw dF/F, motion-sorted, shared CLim). Figure 2: per-amp absolute deviation scatter (`|Peak_imp − mean|` on X, same motion-sorted trial order on Y, coloured by tertile, r annotated). Figure 3: pooled amplitude-normalised tertile mean ± SEM traces (low/mid/high motion, blue/purple/red) — restores the trace overlay from the first version. Exports: `imp_motion_heatmap_*`, `imp_motion_deviation_*`, `imp_motion_traces_*`.
**Why:** Absolute deviation makes Figure 2 unambiguous (distance from mean, not direction). Tertile trace figure (Figure 3) provides the mean-response view that reviewers expect alongside the trial-sorted figures.
**Next:** Run section; check Figure 2 high-motion points (red, top rows) cluster near x=0; check Figure 3 high-motion SEM band is narrower than low-motion.

### 2026-05-18 — plottingScript: OL TF — add random CL trial panel; fix y₀ mismatch; fix repeated trial
**Changed/Found:** `plottingScript.m` (OL TF section) — (1) `tiledlayout` changed from 2→3 columns; skip block updated to 3 `nexttile` calls. (2) `rng('shuffle')` added once before the session loop so the random trial index changes every run. (3) y₀ anchor correction (`yp = yp + (y_actual(1) - yp(1))`) applied to OL mean, CL mean, and new single-trial predictions — shifts the prediction by a DC offset so the first sample matches the actual, making the dynamic tracking error visible from t=0. (4) New panel 3: random CL trial picked per session via `randi(nWc_ol)`; x0 from `findstates` on the pre-onset window; y₀ anchored; plots actual vs OL-TF pred with scaled input overlay.
**Why:** Without `rng('shuffle')`, MATLAB uses the default seed on each fresh run, giving the same trial index. y₀ mismatch occurs because `findstates` returns x0 at the start of the pre-onset window (t=−1 s), not at stim onset; the DC correction patches the offset so the visual comparison is valid.
**Next:** Check whether the dynamic tracking (post-anchor) is good or poor; poor tracking on CL trials with unusual inputs would confirm the LTI model can't capture controller-induced nonlinearities.

### 2026-05-18 — plottingScript: OL TF — replace 2-sample x0 with findstates on full pre-onset window
**Changed/Found:** `plottingScript.m` (OL TF section) — Replaced the 2-sample output-as-state approximation (`x0 = [y(-1); y(-2)]`) with `findstates(best_ol, iddata(y_pre, u_pre, Ts_ol))` for all four sim calls (OL mean, OL per-trial, CL mean, CL per-trial). Pre-onset input `u_pre = zeros(iOn_ol-1, 1)` (laser off before stim onset). `y_pre` is the full 35-sample (1 s) baseline-corrected pre-onset window per trial, or its mean for the average predictions.
**Why:** `findstates` uses all 35 pre-onset samples and is realization-independent — it finds the optimal x0 in the least-squares sense regardless of the internal canonical form MATLAB uses for the idtf. The 2-sample approximation was only valid if the model happened to be in observable canonical form.
**Next:** Run section; compare R² before and after — improvement in per-trial R² (especially for trials with large pre-stim fluctuations) confirms the initial-condition fix is working.

### 2026-05-17 — plottingScript: OL TF — fix initial condition using output-as-state assumption
**Changed/Found:** `plottingScript.m` (OL TF section, all four sim calls) — Replaced zero-prepend simulation with explicit x0 passed to `sim`. x0 = last 2 pre-onset samples of the baseline-corrected output for each trial (`ncDfk_bc(j, iOn_ol-2:iOn_ol-1)'`), or the mean across trials for the mean-response sim. `nPre_ol` is now only used for the fitting iddata warmup, not for simulation. Rationale: `sim` with zero initial conditions assumes the system state is zero at stim onset; baseline correction only removes DC, not the dynamic state (velocity in state-space terms). For a SISO 2p1z model in observable canonical form the state is approximated by the last 2 output samples.
**Why:** Zero-prepend sim always started from x(0)=0 regardless of pre-trial activity. For the mean response this nearly cancels, but for individual trials the pre-onset dynamics set a non-zero initial state that biases every prediction from sample 1. This systematically inflates trial-level R² error.
**Next:** Run section; check whether per-trial R² improves vs. before, especially for trials with large pre-stim fluctuations. If the observable canonical form assumption is too coarse, replace x0 with `findstates(best_ol, iddata(y_pre, u_pre, Ts_ol))`.

### 2026-05-17 — plottingScript: OL TF — fix to 2p1z, drop distribution panels, add interactive validation scatter
**Changed/Found:** `plottingScript.m` (lines ~2198–end) — Full rewrite of OL step TF section. (1) Fixed model order to 2p1z (removed AIC sweep, `res_ol` struct, `maxPoles/Zeros/Delay_ol` knobs). (2) Layout changed from 5-col to 2-col tiledlayout: OL traces+TF fit | CL mean vs OL-TF pred. AIC panel and the two trial-R² distribution panels (from previous session) removed. (3) After the session loop, builds a separate interactive figure: trial-level R² (X) vs trial MSE (Y), OL red / CL green, `ButtonDownFcn = scatterClickCallback` wired identically to K2i. UserData struct accumulates `field`, `stim_idx` (`data.nc(j)` / `data.wc(j)`), `lbl`, `mse` across all three sessions.
**Why:** Single fixed 2p1z is the agreed model; sweep was exploratory scaffolding. Distribution panels (jitter scatter) were non-interactive and redundant with console output. Interactive R²-vs-MSE scatter lets you click any outlier trial directly to inspect it with `plotSingleTrial`.
**Next:** Run section; check console for per-session 2p1z R² and tau; click low-R² CL trials to see if they correspond to high-MSE or atypical inputs.

### 2026-05-17 — plottingScript: OL TF validation — trial-level R² distributions replace anecdotal single-trial panels
**Changed/Found:** `plottingScript.m` (lines ~2300–2460) — Replaced panels 3 and 4 (random single OL/CL trial overlays) with quantified R² distributions. After fitting best_ol on OL mean: (1) loop over all OL trials, sim each with per-trial input, collect R2_ol_trials; (2) loop over all CL trials with same TF, collect R2_cl_trials. Panels 3/4 now show jittered scatter + median line + yline(0); title reports med/IQR. Two summary fprintf lines added (OL trial-level and CL trial-level med/IQR). Computation placed before panel drawing so values are available for both scatter and console.
**Why:** Single random-trial panels were anecdotal (non-reproducible, no summary statistic). Trial-level R² distributions show the TF generalises to unseen OL trials (within-condition) and to CL trials (cross-condition). No OL train/test split used — TF is fit on the mean (4 free params, no overfitting risk); CL is the principled held-out condition.
**Next:** Run section; check console for per-session med/IQR; if CL trial-level R² is close to OL trial-level R², LTI generalisation across conditions is confirmed.

### 2026-05-15 — Corrected Closedloop_edit path in CLAUDE.md files
**Changed/Found:** `paper-writing/CLAUDE.md`, root `CLAUDE.md`, memory `project_brain_paper.md` — Updated `Closedloop_edit/` path from (incorrectly assumed) `brain_paper/Closedloop_edit/` to the correct absolute path `C:\Users\aditya\Documents\projects\Closedloop_edit\`.
**Why:** User confirmed the manuscript folder is a sibling directory, not inside the repo.
**Next:** No action needed; path is now correct in all context files.

### 2026-05-15 — Created multi-agent research folder structure
**Changed/Found:** `impulse-analysis/CLAUDE.md`, `controller-analysis/CLAUDE.md`, `paper-writing/CLAUDE.md`, `CLAUDE.md` (root updated) — Created three subdirectories with detailed CLAUDE.md context files synthesized from RESEARCH.md, MEETINGS.md, PAPER.md, and existing CLAUDE.md. Root CLAUDE.md updated with three-area overview and relation diagram.
**Why:** User requested a structured multi-agent session setup so each research area has self-contained context for a Claude subagent starting cold.
**Next:** Verify folder structure with `ls`; open any of the three CLAUDE.md files at the start of a focused session to load area-specific context.

### 2026-05-15 — plottingScript: OL-TF driven by CL input — CL prediction panel
**Changed/Found:** `plottingScript.m` — Added centre panel to the OL step TF figure. After fitting `best_ol` on OL data, the same TF is simulated with the average CL input (`wcInp`); result compared against actual average CL response. Layout changed from 2→3 columns per session row: [OL traces+fit | CL actual vs OL-TF prediction | AIC]. Faint OL mean shown as reference in the CL panel. R²_CL printed to console. `paperFig` replaced with plain `figure`; export commented out.
**Why:** Tests whether the LTI model learned from OL data generalises to the CL condition. R²_CL ≈ R²_OL would validate the LTI assumption across conditions.
**Next:** Run section; compare R²_OL vs R²_CL per session; check whether prediction over- or undershoots the CL response (would indicate controller effect beyond what the input alone predicts).

### 2026-05-15 — plottingScript: OL step TF fit — looped over three sessions
**Changed/Found:** `plottingScript.m` — Replaced single-session OL TF fit with a loop over `ol_sess_idx = [4 9 11]`, matching `custom_idx` in the existing OL step response plot (m4=AL_0033 2025-02-26, m9=AL_0039 2025-04-20, m11=AL_0039 2025-04-30). Produces one 3-row × 2-col figure per-session (left: trial traces + mean ± SEM + TF prediction + scaled input; right: AIC bar). Exports `paper/ol_tf_three_sessions.pdf`. Session colors match the OL step response palette.
**Why:** User wanted TF fit applied to the same three sessions shown in the OL step response plot.
**Next:** Run section; check R² and tau printout per session; compare time constants to impulse TF.

### 2026-05-14 — plottingScript: OL step TF fit section
**Changed/Found:** `plottingScript.m` — Appended new section `%% OL step TF fit` at end of file. Uses `data.ncDfk` (35 Hz) and `data.ncInp` (2 kHz) from the selected OL session. Pipeline: resample input 2kHz→35Hz via `resample()`; subtract per-trial pre-onset baseline (t = −1 to 0 s); trial-average; prepend nPre zeros; build `iddata`; run same AIC-based `tfest` pole/zero/delay sweep as impulse section (1–3 poles). Outputs: 2-panel PDF (trial traces + mean ± SEM + TF fit + scaled input; AIC bar chart), Command Window pole→time-constant printout for comparison against impulse TF. Knob: `selSess_ol = 'm2'`.
**Why:** User requested TF fit to OL step data from closed-loop sessions, analogous to impulse TF. Input treated as arbitrary waveform (step or sine); toolbox handles both. Sinusoidal input caveat noted in comments.
**Next:** Run section; check R²; compare printed time constants to impulse TF poles. If poles agree, LTI assumption holds across stimulus types.

### 2026-05-14 — Impulse_mouseDataAnalysis_all: exclude 0-amp gap-fill events from dose-response plots
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Bug: the gap-filling section always stamps inserted missing-stim events with amplitude 0 (`allAmp = [ampDet; zeros(...)]`), so any experiment with gaps in its stim train gets a spurious 0-amp group in `uAmp_filled`. This flowed into `allVals`/`groupLabels` and was plotted at x=0 in both dose-response figures, distorting the linear fit. Fixed by adding `nzMask = xpos_raw > 0` filtering in both the mean±SEM and median±95th-pctile plot loops, after `accumarray` but before plotting and `polyfit`. Mirrors the existing `validAmp = uA_s > 0` guard in the TF fit section.
**Why:** Experiment 2 (AL_0041, en=2) has no real 0 mW condition; the 0-amp group it carried was entirely gap-filled artefacts, not laser trials.
**Next:** Re-run both dose-response sections; confirm experiment 2 no longer shows a data point at x=0 and that the linear fits look cleaner.

### 2026-05-14 — Impulse_mouseDataAnalysis_all: error bars IQR → 95th-percentile bounds
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — In the "Combined plot — median ± IQR" section, replaced `prctile(v,25)` / `prctile(v,75)` with `prctile(v,2.5)` / `prctile(v,97.5)`, renamed variables `q25`/`q75` to `p2_5`/`p97_5`, updated section header and fprintf label to "95th-pctile bounds". All three error-bar plot calls (vertical bar, lower cap, upper cap) updated. Output file unchanged (`paper/imp_response_median.pdf`).
**Why:** Nick's suggestion from 2026-05-08 meeting: IQR (25th–75th) is too narrow for this plot; 95th-percentile bounds (2.5th–97.5th) better reflect trial-to-trial spread and are more standard for reporting in the paper.
**Next:** Re-run the "Combined plot — median ± 95th-percentile bounds" section; check that error bars are visibly wider than before and still span a sensible range; export and update `Closedloop_edit/images/`.

### 2026-05-14 — Impulse_mouseDataAnalysis_all: spatial spread vs amplitude figure
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Added full spatial spread analysis pipeline. Inside the experiment loop: (1) compute `brainMask_e` (10% of max mimg intensity) and `UU_brain_e` (SVD spatial matrix restricted to brain pixels); (2) inside the amp loop, compute per-amplitude trial-averaged dF/F response maps in SVD space (peak window 0–200 ms minus baseline −500–0 ms), stored in `imp.resp_map` and `imp.base_map` as brain-pixel vectors. Added `brainMask`, `mimg`, `mI1` to `allExperiments`. New section at end: thresholds at 2×SD of pooled baseline maps, computes area-above-threshold and effective radius = sqrt(area/π); exports a 2-panel PDF: left = mean brain image + per-amplitude inhibition contours, right = spread radius (mm) vs amplitude (mW). Pixel scale: 0.173 mm/px.
**Why:** User requested spatial spread vs amplitude paper figure; plan agreed: area-above-threshold contour panel + effective radius summary panel.
**Next:** Run full script; check threshold value printed in contour panel title; verify contours are centred on stim site and grow with amplitude.

### 2026-05-13 — Impulse_mouseDataAnalysis_all: varDetailCallback + interactive motion-excluded scatter
**Changed/Found:** `utils/varDetailCallback.m` (new), `Impulse_mouseDataAnalysis_all.m` — Created `varDetailCallback` mirroring `motionDetailCallback`: click a dot in the motion-excluded pre-trial variance scatter → 2-panel figure showing dF/F trace (trial vs mean ± SD) and z-scored motion trace for that trial. Wired via `ButtonDownFcn` on the scatter handle; closure captures `preVar_clean`, `dev_clean`, `df_clean`, `mot_clean`, `t_win_imp`, `ampVal` per amplitude/experiment. Title updated with `[click]` hint.
**Why:** User requested interactive trial inspection matching the freq heatmap pattern, applied to the motion-excluded variance section.
**Next:** Run section; click a high-variance outlier dot and verify the correct trial trace opens.

### 2026-05-13 — Impulse_mouseDataAnalysis_all: pre-trial variance sort — fix subplot layout + switch bar to errorbar
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Fixed the subplot index formula in the "Pre-trial variance sort" section: old formula `nCols_v + iAmp` only worked when nAmp ≤ nCols_v (single row group); replaced with column/group calculation (`col_v`, `grp_v`, `sp_top`, `sp_bot`) that correctly pairs each amplitude's scatter and errorbar plot regardless of how many amplitudes wrap across rows. Also replaced the sorted `bar` in row 2 with an `errorbar` plot: trials are binned into 5 variance quintiles and mean ± SEM of |Peak_imp_dev| is shown per quintile.
**Why:** User reported bad subplot layout; the bar-of-individual-trials was also not informative at the quintile level. Errorbar by quintile is cleaner and more interpretable.
**Next:** Re-run section; verify row 1 (scatter) and row 2 (errorbar) are correctly paired per amplitude column.

### 2026-05-13 — Impulse_mouseDataAnalysis_all: pre-trial variance sort + motion-excluded sections
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — Appended two new sections after line 1151. Section 1: for each experiment/amplitude, computes per-trial dF/F variance over the 1 s pre-stimulus window (t ∈ [−1, 0) s, 35 samples), then plots a scatter of pre-trial variance vs |Peak_imp deviation from mean| (Pearson r annotated) and a bar of deviation values sorted by variance rank. Section 2: repeats the same plots after excluding the top 25% of trials by motion energy (imp.mot threshold = 75th percentile across all amplitudes per experiment), with n_kept/n_total shown in each subplot title.
**Why:** Test whether pre-stimulus neural state variance predicts trial-to-trial variability in inhibition peak, and whether that relationship persists after removing motion-contaminated trials.
**Next:** Run script; inspect whether r is consistently positive across amplitudes; compare Section 1 vs Section 2 r values to assess motion confound.

### 2026-05-13 — plottingScript: G2 — windowed MSE (t=+1 to +3 s) violin comparison + trial-number scatter
**Changed/Found:** `plottingScript.m` — Added self-contained `%% G2` section after Fig G. Computes RMS MSE from already-loaded `ncDfk`/`wcDfk` (cols 71:141 = t=+1 s to +3 s at 35 Hz, dur=3). G2a: side-by-side violin of full-window (t=0–3 s) vs new window (t=+1–3 s) per session; prints per-session OL/CL means and ratio table. G2b: per-session scatter of windowed RMS MSE vs trial number (red=OL, green=CL). Exports to `paper/MSE_window_comparison.pdf` and `paper/MSE_vs_trial_number.pdf`. Stores `er_ncDfk_w`/`er_wcDfk_w` into the `mouse` struct for downstream reuse.
**Why:** Nick requested (2026-05-08) that MSE be re-computed on t=+1 to +3 s to skip the initial inhibitory transient and measure error once the controller has had time to act. No util changes, no cache regeneration — slices existing stored trace windows.
**Next:** Run section; check violin shapes and printed ratio table; compare OL/CL separation between the two windows; inspect trial-number scatter for session-level drift or learning effects.

### 2026-05-13 — plottingScript: K1w/K2w/K2iw — pre+trial dFk variance sort (wider window)
**Changed/Found:** `plottingScript.m` — Added three figures after K2m using variance over the full pre+trial window (`pncDfk_l` cols 1:210 = 6 s at 35 Hz, vs 3 s pre-only in K1/K2). Single collection loop builds spectral, MSE, and interactive UserData in one pass. K1w is the heatmap with MSE strip; K2w is the static scatter; K2iw is the interactive version wired to `scatterClickCallback`.
**Why:** Pre+trial variance captures stimulus-evoked variability in addition to brain state, which may better predict MSE when the response itself is the dominant source of variation.
**Next:** Compare K2 vs K2w slopes; compare K1 vs K1w heatmap ordering to see whether pre-stim vs full-window variance rank trials differently.

### 2026-05-13 — plottingScript: K2i — interactive pooled pre-stim variance scatter
**Changed/Found:** `plottingScript.m` — Added `%% K2i` section between K2 and K1m. Re-runs the session loop to collect per-trial `UserData` (field, stim_idx, lbl, mse) alongside pre-stim variance and MSE. Creates a single pooled figure with OL (red) and CL (green) scatter objects, each with `ButtonDownFcn = @scatterClickCallback`. Clicking a point opens `plotSingleTrial` (dFk + motion + input).
**Why:** Mirrors the interactive motion scatter pattern so individual outlier trials (high pre-stim var, high or low MSE) can be inspected in context.
**Next:** Run section; click a high-var OL trial and a matched CL trial to compare traces.

### 2026-05-13 — plottingScript: Figures K1/K2/K1m/K2m — pre-stim dFk variance sort
**Changed/Found:** `plottingScript.m` — Added four figures before the Widebrain section. K1: spectral heatmap (OL|CL) with trials sorted by 3-s pre-onset dFk variance, MSE shown as a thin parula side-strip on each panel. K2: scatter of pre-stim variance vs MSE with OL/CL regression lines and annotated slopes. K1m and K2m repeat K1/K2 with motion exclusion (|z-motion| ≤ motThresh). Exports to `paper/freq_heatmap_prestimvar.png`, `paper/prestimvar_mse.pdf`, `paper/freq_heatmap_prestimvar_motclean.png`, `paper/prestimvar_mse_motclean.pdf`.
**Why:** Nick's suggestion — test whether pre-trial neural state variability predicts MSE outcome, and whether CL decouples that relationship relative to OL.
**Next:** Run all four sections; compare K2 OL vs CL slopes; compare K1 vs J trial ordering.

### 2026-05-13 — plottingScript: Figure J2 — motion-clean MSE-sorted spectral heatmap
**Changed/Found:** `plottingScript.m` after Fig J — New section pools all sessions with both motion and spectral data, excludes trials where |mean z-motion| > 1.5 (combined window: 2 s pre + full trial), then produces an MSE-sorted OL/CL heatmap identical in layout to Fig J. Prints per-condition exclusion counts. Exports to `paper/freq_heatmap_motionclean.png`.
**Why:** Isolate spectral MSE structure from motion confounds; check whether the frequency patterns seen in Fig J survive motion exclusion.
**Next:** Run section; check exclusion % is <20%; compare J vs J2 visually.

### 2026-05-13 — plottingScript: combined motion vs MSE scatter for all sessions
**Changed/Found:** `plottingScript.m` line 784 — Added new figure block that pools motion (z-scored, combined window: 2 s pre + full trial) and MSE (`er_ncDfk` / `er_wcDfk`) across all sessions. Plots OL (red) and CL (green) scatter with linear regression lines; exports to `paper/motion_mse_combined.pdf` (vector).
**Why:** Single-panel summary of motion–MSE relationship across all sessions, complementing the per-session subplots already present.
**Next:** Run section to verify pooling is correct and regression lines look sensible; check that sessions with no motion data are skipped cleanly.

### 2026-05-13 — Analysis_variable: cache bregma offset to skip image-click on re-runs
**Changed/Found:** `Analysis_variable.m` — Replaced the bare `openSVDImageClick` call with a save/load cache. On first run the result (`clickData`, `mmData`, `clickPixelCoords`, `bregmaOffset`) is saved to `paper/bregma_<mn>_<td>_en<N>.mat`. On subsequent runs the file is loaded directly and the image GUI is skipped. Set `rerun_click = true` to force re-clicking (e.g. when changing the ROI or bregma position).
**Why:** The image-click GUI was the main friction point for re-running the script on an already-processed session.
**Next:** Confirm the mat file is created after first run; test `rerun_click = true` overwrites correctly.

### 2026-05-13 — analysisPlots_var_paper: adaptive ylims for single-trial, trial-average, and variance plots
**Changed/Found:** `utils/analysisPlots_var_paper.m` — Removed all hardcoded `[-10 10]` and `[-2 12]` ylim calls. Single-trial ylim (`y_lim_trial`) is now computed from the union of both OL/CL dF/F traces, the reference, and the scaled input traces, with 15% padding. Trial-average axes (ax_C, ax_D) reuse `y_lim_trial` to keep the same scaling across figures. Variance axes derive `var_lim` from the actual `nc_var`/`wc_var` traces (15% padding, floor at 0).
**Why:** Hardcoded limits clipped or wasted space depending on the session; matching single-trial and trial-average ylims preserves visual comparability between the two figures.
**Next:** Verify traces fill the axes without clipping on a few sessions before finalising figures.

### 2026-05-13 — analysisPlots_var_paper: append session name to exported PDFs
**Changed/Found:** `utils/analysisPlots_var_paper.m` and `Analysis_variable.m` — Added `sessTag` parameter (`mn_td_enN` format) built in `Analysis_variable.m` and passed to the plot function. All 5 `exportgraphics` calls now use `['paper/<name>' sessTag '.pdf']` so each session saves distinct files (e.g. `single_trial_var_AL_0041_2026-04-13_en6.pdf`). Backward-compatible: calling without `sessTag` still saves to the original filename.
**Why:** Running multiple sessions overwrote the same PDFs in `paper/`; needed per-session files to keep all outputs.
**Next:** Verify PDFs appear with session suffix in `paper/` after next run.

### 2026-05-12 — plottingScript.m: pseudo-random grid+jitter+snap pixel sampling for contralateral ROI
**Changed/Found:** `plottingScript.m` — Replaced `randperm` pixel selection with pseudo-random placement: (1) `n_side × n_side` regular grid spanning ROI bounding box, (2) ±30% jitter in row/col, (3) `dsearchn` snap each jittered point to nearest valid mask pixel, (4) `unique(...,'rows','stable')` de-duplicate, (5) trim to `nPred-1`. Contra-primary still goes first. This spreads pixels evenly across the drawn ROI rather than clustering them by chance.
**Why:** Pure `randperm` tended to bunch pixels; evenly-spaced then jittered grid gives reproducible spatial coverage of the contralateral region for every ROI redraw.
**Next:** Set `redefine_roi=true`, rerun the pixel selection cell, verify pixel map shows evenly spread blue dots across the cyan polygon, then set `redefine_roi=false` and run the ARX regression cell.

### 2026-05-12 — plottingScript.m: replace grid pixels with interactive polygon ROI + random sampling
**Changed/Found:** `plottingScript.m` — Widebrain pixel selection rewritten. Fixed `d.params.pixel` coordinate order (pixel(1)=row, pixel(2)=col). Combined midline + ROI into one interactive figure: Step 1 = 2 midline clicks; Step 2 = polygon boundary around contralateral hemisphere. `inpolygon` mask (no toolbox); random sample `nPred-1=9` pixels from mask ∩ brain_mask. Contra-primary always first in `pred_px/pred_py`. Saves `midline.mat` + `contra_pixels.mat`; `redefine_roi=false` skips interaction on rerun. Pixel map shows outline, primary (red), contra-primary (cyan), random samples (blue).
**Why:** Grid approach gave badly placed pixels; interactive polygon lets user define exactly which contralateral region to sample.
**Next:** Run cell, draw midline + ROI, verify pixel map looks right, set `redefine_roi=false`, run regression cell.

### 2026-05-12 — Created MEETINGS.md: parsed all three meeting transcripts
**Changed/Found:** `MEETINGS.md` created — consolidated action items from all three Nick/Aditya meetings (2026-04-27, 2026-05-08, 2026-05-11). Includes open item tracker (by category), per-meeting summaries, and AI-analysis flags. Several items from Apr 27 marked complete per May 11 overview (laser trace rescale, subplot unification, captions, absolute power spectra, Anna mouse contact).
**Why:** No structured tracking of meeting action items existed; items were only in Obsidian transcript files. MEETINGS.md gives a single in-project view of what is open vs. done.
**Next:** After each new meeting, provide transcript path to Claude with "parse this meeting" to append a new entry and update the open items list.

### 2026-05-11 — Impulse_mouseDataAnalysis_all.m: rework Panel A (TF data vs model figure)
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` Panel A section — removed individual trial traces (gray), removed R² from legend labels, added 1s pre-stim baseline window (`preWin_A = 1.0`; display uses `iWin_A = find(t_full >= -preWin_A & t_full <= tFit_s)`). Amplitude selection changed from linspace-3 to exact smallest/middle/largest from `validAmp`. Stim onset now shown as thin red vertical line at t=0 instead of dot. Scale bar updated to 500 ms.
**Why:** User found raw trial traces cluttered and R² in legend redundant; pre-trial baseline context needed to show that the response starts from a flat baseline.
**Next:** Check that the red stim line at t=0 and the "Stim" text are visible and not obscured by the corner scale bar.

### 2026-05-11 — plottingScript.m: implement contralateral ARX widebrain prediction
**Changed/Found:** `plottingScript.m` — Added `%% Widebrain prediction — contralateral ARX model` section. Predictor pixels = contralateral primary pixel (reflected across midline from `midline.mat`, or image-centre fallback) + a grid of contralateral-hemisphere pixels (spacing 30px, radius 60px, brain-mask filtered). Pixel dFk extracted inline via SVD projection. ARX model (`buildLagMatrix`, pY=5, pX=3) fit on 6s pre-trial spontaneous windows pooled across all NC+WC trials. Model applied to OL and CL trial windows; residual (actual − predicted) isolates stimulus+controller deviation from spontaneous widebrain prediction. 4-panel figure: spontaneous snippet, OL mean trace, CL mean trace, residual comparison. Exported to `paper/wb_prediction.pdf`.
**Why:** RESEARCH.md goal: show contralateral widebrain activity predicts primary pixel; OL residual = opto effect alone; CL residual = opto + controller intervention.
**Next:** Run `define_midline.m` first to create `midline.mat` (currently falls back to image centre x). Then run cell and check R²_spont > 0.3, contralateral pixel count 5–20, and that OL vs CL residuals differ interpretably. Tune `contra_step`/`contra_R`/`pY`/`pX` as needed.

### 2026-05-11 — Impulse_mouseDataAnalysis_all.m: add paper-quality TF figures (Panel A & B)
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — added two new `%%` sections after the LOAO summary figure. Panel A (`tf_data_vs_model`): 2–3 representative amplitudes overlaid on one axes; individual trials (gray, 0.4 pt), session mean (parula color, 1.5 pt), TF model prediction (black dashed, 1.5 pt), stim onset marker, R² in legend labels. `paperFig(6,4)`, corner axes, vector export. Panel B (`tf_loao`): full-fit R² (filled blue circles) vs LOAO R² (open red squares) across amplitudes, x-axis in mW; `paperFig(4,4)`, adaptive scale bar, vector export. Both export to `paper/tf_data_vs_model_<mn>_<td>_en<N>.pdf` and `paper/tf_loao_<mn>_<td>_en<N>.pdf`.
**Why:** Manuscript needs a figure showing the TF can be learned. Panel A makes the LTI claim visual (same model shape × amplitude = data). Panel B provides falsifiable cross-validation evidence (LOAO R² close to full-fit R² → not overfit).
**Next:** Run the TF section for selExp=3 and check that (1) the stim marker position looks right, (2) the scale bar lengths (0.25 s / 1% dF/F and xLen_B / 0.5 R²) are sensible for the actual data range.

### 2026-05-11 — plottingScript.m + Impulse: remove all freq normalization/z-scoring from plots
**Changed/Found:** `plottingScript.m` — Figure K (per-band mean normalization) removed entirely; with absolute power in Figures I/J it was redundant. `Impulse_mouseDataAnalysis_all.m` — static and interactive freq heatmaps: removed `zscore()` call, replaced BWR colormap with `'hot'`, changed `clim([-2 2])` to `[0 clim_e]` where `clim_e` is the 98th percentile of all freq power for that experiment (computed once before the subplot loop, shared across amplitudes). Colorbar label updated to `'Power (ΔF/F)^2 Hz^{-1}'`.
**Why:** User confirmed all freq plots should show exact absolute power with no normalization or z-scoring at any stage.
**Next:** Re-run heatmaps; if low-freq power (delta) dominates and washes out higher bands visually, consider log-scaling the power before display (`log10(freq_i + eps)`).

### 2026-05-11 — Impulse_mouseDataAnalysis_all.m: switch freqSpec to absolute power
**Changed/Found:** `Impulse_mouseDataAnalysis_all.m` — per-trial freq slice now uses `S_bands` (raw squared FFT magnitude) instead of `S_norm` (band/total ratio). Comment on `S_norm` updated to "kept for reference, not used for freqSpec". Heatmap section comment updated to "absolute band power … z-scored across trials per band for display".
**Why:** Same motivation as the plottingScript.m change: Nick found band/total normalization confusing; absolute power is the correct quantity. The z-scoring already applied at display time is a separate, per-band normalization that is still appropriate.
**Next:** Re-run heatmap figures; verify z-score range is similar (if absolute power has a large dynamic range across sessions, consider log-scaling before z-scoring).

### 2026-05-11 — plottingScript.m step-response figure: standardised size and format
**Changed/Found:** `plottingScript.m` lines 392–395 — replaced ad-hoc `figure('Units','centimeters','Position',[0 0 15 10])` with the standard paper-figure setup (6 cm × 4 cm, explicit `PaperSize`/`PaperPosition`, matching `Impulse_mouseDataAnalysis_all.m`). Also fixed duplicate `legend()` call and changed `ItemTokenSize` from `[14 6]` to `[6 6]`.
**Why:** Figure size/paper properties must be set explicitly for `exportgraphics` to produce correctly sized vector PDFs. Font size 6 bold is the project standard.
**Next:** Verify exported `paper/step_response.pdf` is 6 × 4 cm. Use `paperFig(w,h)` for all new figures.

### 2026-05-11 — CLAUDE.md: add paper workflow section
**Changed/Found:** `CLAUDE.md` — added "Paper workflow" section documenting that the paper is edited on Overleaf, `Closedloop_edit/` holds the local snapshot, and the figure copy workflow (paper/ → Closedloop_edit/images/ → Overleaf).
**Why:** User asked to track the Overleaf + Closedloop_edit workflow in CLAUDE.md so future sessions have the context.
**Next:** Keep `Closedloop_edit/images/` in sync when new figures are exported.

### 2026-05-11 — analysisPlots_var_paper.m: reformat to match analysisPlots_combined style + add inputs panel
**Changed/Found:** `utils/analysisPlots_var_paper.m` — full rewrite to match `analysisPlots_combined.m` style: switched figure units to centimeters (PW=8 dual-panel, PW=3 single-panel); replaced `subplot` with explicit `axes(...,'Position',[...])` using shared `lm/rm/cg` layout; added `cleanAxes` and `addStimPatch` to all axes; fixed `shortCornerAxes_plot` LineWidth 5→2, LabelGap 0.04/0.05; fixed legend FontSize 12→6 and added `ItemTokenSize=[8 4]`; replaced PNG exports with vector PDF (`ContentType','vector'`); added new panel C (`paper/inputs_var.pdf`) showing mean±std input traces for OL and CL separately; used consistent `colOL/colCL/colInpOL/colInpCL` color scheme. Reference profile uses `(-5)*d.iputs(...)` (variable reference from last nc trial, matching `controllerData_var.m`).
**Why:** Style consistency with `analysisPlots_combined.m` for paper-quality export; inputs panel was missing and needed as a separate panel.
**Next:** Verify `d.iputs` field exists at runtime (it is computed in `controllerData_var.m`); check y-limits on inputs panel (auto-scaled) against actual signal range.

### 2026-05-11 — findStims.m / Analysis_variable.m: add mode 2 for newer stim detection
**Changed/Found:** `utils/findStims.m` — split the former `else` branch (mode 1) into two named modes: mode 1 (old, subtracts `horizon` from `input_params(:,2)`) and mode 2 (new, uses `input_params(:,2)` directly as absolute sample index, no horizon subtraction). `Analysis_variable.m` — added `d = findStims(d, 2)` immediately after `initialize_data` so AL_0041 sessions use the correct stim times.
**Why:** AL_0041 experiments store the stim onset as an absolute sample index in `input_params(:,2)`, whereas older sessions (AL_0033, AL_0039) store a relative index that requires subtracting `horizon`. `initialize_data` hardcodes mode 1 and is unchanged, so `plottingScript.m` is unaffected. The `d.stimStarts = d.stimStarts - 2` workaround on line 175 of `Analysis_variable.m` may now be incorrect — verify stim alignment on a sample trial before keeping or removing it.
**Next:** Check a sample trial in Analysis_variable.m to confirm `stimStarts` are correct with mode 2; decide whether to remove the `stimStarts - 2` shift on line 175.

### 2026-05-11 — controllerData.m: store absolute power alongside relative
**Changed/Found:** `utils/controllerData.m` — added `ncFreqPow`/`wcFreqPow` arrays (same shape as `ncFreqSpec`/`wcFreqSpec`) storing raw `S_bands` (squared FFT magnitude, units: (ΔF/F)² Hz⁻¹) for each trial window, without dividing by total power. Both fields now written to `data` and saved to cache.
**Why:** PAPER.md: Nick found the band/total normalization confusing; absolute power values are more interpretable and directly show spectral content differences between OL and CL.
**Next:** Set `r_ctrl = 0` and re-run the loading block to regenerate all caches with the new field; then rerun the heatmap figures to verify absolute power colormaps look sensible.

### 2026-05-11 — plottingScript.m: switch freq heatmaps (I/J/K) to absolute power
**Changed/Found:** `plottingScript.m` — Pass 1 loop and Figures I/J/K updated: prefer `ncFreqPow`/`wcFreqPow` (absolute) over `ncFreqSpec`/`wcFreqSpec` (relative); fallback to relative for old caches. Colorbar label changes from "band/total power" to "Power (ΔF/F)² Hz⁻¹" when absolute power is available. `ud_ol.freq_spec`/`ud_cl.freq_spec` in the interactive click callback also updated to use the correct field.
**Why:** Companion change to controllerData.m update — heatmap figures now reflect absolute power as requested.
**Next:** Verify colour scale is informative (98th-percentile clim should work; check if sessions with lower SNR wash out). Consider log-scaling if dynamic range is too large.

### 2026-05-11 — plottingScript.m: add SVD frame export after single-session plot
**Changed/Found:** `plottingScript.m` — after line 229 (`analysisPlots_combined` call), added a new section that builds `svdData` from `d.svd.{U,V,mimg}` for `selField=10` (AL_0039, 2025-04-19), calls `displayFrame` in SVD mode, then resizes `gcf` to 3 cm × 3 cm and exports via `exportgraphics` to `paper/svd_frame_<mn>_<td>.pdf` at 600 dpi (`ContentType','image'`).
**Why:** User requested a high-res 3×3 cm PDF brain frame for the selected session using the existing `displayFrame` function in SVD reconstruction mode.
**Next:** Verify the SVD files (svdSpatialComponents.npy etc.) are present for m10; confirm the exported PDF renders correctly at 3 cm size.

### 2026-05-08 — Impulse_mouseDataAnalysis_all.m: residual analysis + LOAO validation
**Changed:** `Impulse_mouseDataAnalysis_all.m` — (1) added `resid(data_fit, best_sys)` figure immediately after TF print to check autocorrelation of residuals and cross-correlation with input; (2) added LOAO section: for each valid amplitude, refit amplitude-weighted h_norm on remaining amplitudes using same best np/nz/nd, predict held-out amplitude, record R²_loao; prints full-fit vs LOAO R² table per amplitude; adds summary figure comparing R²_full vs R²_loao across amplitudes
**Why:** Validation step: resid detects missing model structure; LOAO tests whether poles generalize across amplitude levels (key assumption of the linear scaling model)
**Next:** Large R²_full − R²_loao gap at strong amplitudes → amplitude-dependent dynamics confirmed → consider per-amplitude TF fits

### 2026-05-08 — Impulse_mouseDataAnalysis_all.m: transport delay sweep added to TF fit
**Changed:** `Impulse_mouseDataAnalysis_all.m` — added `maxDelay` knob (default 5 samples, ~143 ms at 35 Hz); wrapped `np`/`nz` loops in outer `for nd = 0:maxDelay` loop; passes `'InputDelay', nd*Ts` to `tfest`; `res` struct gains `nd` field; printout header gains `nd` column; best-model summary prints delay in ms; figure title includes delay count
**Why:** Transport delay (axonal + synaptic) shifts the response onset and can substantially improve fit quality if unmodelled; AIC will select the right delay automatically
**Next:** Check if AIC consistently selects nd>0; if so, report best delay in ms as a physiological estimate

### 2026-05-08 — Impulse_mouseDataAnalysis_all.m: R² and slope on dose-response figures
**Changed:** `Impulse_mouseDataAnalysis_all.m` — in both mean±SEM and median±IQR dose-response loops, compute R² from `polyfit` residuals after each `polyfit` call; `fprintf` slope and R² to console; add `text(ax, ...)` annotation (normalized units, font size 5, matching session color) stacked vertically per session at top-left of each figure
**Why:** Task in RESEARCH.md current state: linear fits were already drawn but R² and slope were neither printed nor shown on the figure
**Next:** Verify text annotations are readable at the exported PDF size; consider moving annotations if they overlap the data

### 2026-05-08 — plottingScript.m + analysisPlots_combined.m: fully fix missing d.ref
**Changed:** `plottingScript.m` else-branch now sets `mouse.(fields{k}).d.ref = -5` before re-saving the cache; `utils/analysisPlots_combined.m` line 12 adds `if ~isfield(d,'ref'); d.ref = -5; end` as a last-resort default
**Why:** Guard in the cache-load path didn't help when the plotting cell was run in isolation on a stale workspace (ref never got set in memory); also the re-saved cache lacked ref so the next full run still hit the guard but didn't persist it
**Next:** Confirm `analysisPlots_combined` runs cleanly for all loaded sessions

### 2026-05-08 — plottingScript.m: fix "Unrecognized field name 'd'" on stale caches
**Changed:** `plottingScript.m` lines 91–95 — cache load block now checks `isfield(tmp, 'd')`; if missing, calls `initialize_data` and re-saves the cache with `d` included
**Why:** Old cache files for m2–m5, m9–m10, m13 were saved before `d` was added to the `save(pathCtrl, 'd', 'data')` call — they only contain `data`, so `tmp.d` threw "Unrecognized field name 'd'" and the catch block skipped those sessions
**Next:** Re-run the loading block to confirm all 13 sessions load; verify that the re-saved caches now include `d`

### 2026-05-08 — define_midline.m: interactive midline tool created
**Changed:** `define_midline.m` (new) — loads mean widefield image from AL_0033 2025-01-20 exp 3, displays it, lets user click 2 points along the cortical midline, fits a line, and saves parameters to `midline.mat`
**Why:** First step of contralateral-pixel prediction pipeline — need midline to mirror the primary ROI to the opposite hemisphere
**Next:** Use saved `midline.mat` to compute mirrored pixel coordinates; extract contralateral trace via SVD kernel projection

### 2026-05-08 — RESEARCH.md: Impulse script section rewritten
**Changed:** `RESEARCH.md` — rewrote `Impulse_mouseDataAnalysis_all.m` section to match actual script state: TF fitting is live (not commented out), freq analysis is implemented, pipeline notes corrected (peak_mode 3 default, ±1s motion window, output figures enumerated), open items updated
**Why:** Section was stale — marked TF and freq as not implemented when both are active
**Next:** Continue with TF fitting improvements (transport delay, LOAO, cross-session)

### 2026-05-08 — Logging system established
**Changed:** `CLAUDE.md` created, `RESEARCH.md` updated with Change Log section
**Why:** No changes from the 2026-05-07 session were recorded; adding mandatory logging rule so all future sessions are tracked
**Next:** Backfill yesterday's session if you remember what changed

### 2026-05-14 — Closedloop_edit manuscript corrections applied
**Changed:** `Closedloop_edit/results_edit.tex` — L16: removed `\aditya{}` wrapper, rewrote physiological delay as proper sentence with 80 ms end-to-end latency callout
**Why:** Blue comment placeholder was left from drafting; needed to be integrated as real text before final submission
**Next:** Fill in actual Kp/Ki gain values at L89 once extracted from .mat session data

### 2026-05-14 — discussion.tex incomplete sentence completed
**Changed:** `Closedloop_edit/discussion.tex` — L87: completed trailing sentence "...so that the predicted tracking error over a future horizon is minimized."
**Why:** Sentence ended mid-clause; manuscript was uncompilable/unreadable at that point
**Next:** Review Future Directions subsection for overall flow after completion

### 2026-05-14 — Caption enrichment: Fig. 1, 2, 3, S1
**Changed:** `Closedloop_edit/results_edit.tex` and `methods_edit.tex` — rewrote all four figure captions to Li/Lu journal standard: each panel now states what is shown, error bar type (±1 SD), n values (50 trials/amplitude for Fig. 2; 13 sessions/3 mice for Fig. 3), and stimulation window duration
**Why:** Reviewer noted captions were too thin — reader of Fig. 2B could not tell what points represent, what error bars show, or how many trials per amplitude
**Next:** Verify Fig. 2C shading is actually ±1 SD (not variance or SEM); verify Fig. 3H is mean absolute error (not MSE) — adjust caption wording if different

### 2026-05-14 — results_edit.tex: reviewer-driven prose improvements
**Changed:** `Closedloop_edit/results_edit.tex` — (1) removed vague filler opener from Experimental Setup subsection; (2) rewrote impulse-response paragraph to state peak-response claim precisely with explicit R² / slope units and removed equation cross-ref; (3) added open-loop qualifier to step-response variance sentence; (4) replaced math notation ($d_t$, $\rho_t$) in variability section with plain-English descriptions
**Why:** Claude online review (pasted in PAPER.md §Stuff from CLAUDE) identified passive voice, equation refs in Results, imprecise linearity claim scope, and missing open-loop qualifier as key issues
**Next:** Still open: (a) explicit n and ± CI on slope values in linearity paragraph; (b) caption enrichment (error bar type, n per amplitude); (c) caption figure-citation style audit (Fig. 1A vs Figure 1A)

### 2026-05-14 — main.tex: Introduction placeholder removed
**Changed:** `Closedloop_edit/main.tex` — L85: removed `\aditya{separately editing}` tag, uncommented `\input{introduction}` so introduction.tex is compiled into the document
**Why:** Introduction file exists and has content; placeholder was blocking it from rendering in the PDF
**Next:** Fill in real author names and department affiliations at L63–67

### 2026-05-21 -- K1z/K2z and OL TF sections: encoding fix
**Changed/Found:** `plottingScript.m` lines 1417-1522, 2305-2552 -- 54 lines had non-ASCII bytes. K1z/K2z section used UTF-8 curly quotes (U+2018/U+2019) throughout all string arguments and transpose operators; OL TF section had em dashes, superscript-2, multiplication sign, arrow, and plus-minus sign in string literals and comments.
**Why:** Edit tool writes UTF-8 but the .m file is Windows-1252 -- curly quotes broke all MATLAB string parsing in K1z/K2z. Fixed via Python byte-level replacement: curly quotes -> ASCII single quote; em dash -> '--'; superscript-2 -> '^2'; others to ASCII equivalents.
**Next:** Run K1z/K2z and OL TF sections in MATLAB to confirm no parse errors; verify R^2 renders correctly in figure legends.

### 2026-05-21 -- K1zm/K2zm: motion-clean z-scored heatmap and quintile bars
**Changed/Found:** `plottingScript.m` -- Added section K1zm & K2zm (after K2m, ~line 1732). K1zm: same blue-white-red diverging z-score heatmap as K1z but operating on motion-clean trials (nc_all_k1m / wc_all_k1m, |z-motion| <= motThresh). K2zm: same quintile bar chart but on motion-clean data. Section inserted via Python byte-level write to avoid CRLF/encoding issues.
**Why:** User requested motion-removed variant of the K1z/K2z section, to show whether the 2-4 Hz elevation in high-variance trials survives motion exclusion.
**Next:** Run K1zm/K2zm in MATLAB; compare K1z vs K1zm to assess how much of the 2-4 Hz pattern is motion-driven vs genuine neural signal.

### 2026-05-21 -- Onset variance test section added (OL only)
**Changed/Found:** `plottingScript.m` line 289 -- New section inserted between fig F and fig G. Computes per-session mean OL variance in t in [-1,0] s (var_pre) and t in [0,+3] s (var_post) from Mvarnc. Runs Wilcoxon signed-rank test and logs p-value + post/pre ratio. Two-panel figure: (A) per-session variance traces -1 to +3 s with cross-session mean +/- SEM and shaded comparison windows; (B) paired pre vs post scatter with grand mean +/- SEM, Wilcoxon p, and variance ratio annotated.
**Why:** Justifies results_edit.tex L50 claim "stimulation onset did not affect variance"; reviewer asked to quantify or remove. Fano factor unsuitable (mean ~ 0 at baseline); variance ratio + Wilcoxon directly answers the claim.
**Next:** Run section in MATLAB; if Wilcoxon p > 0.05 and ratio ~ 1.0, add the p-value and ratio to the results_edit.tex sentence at L50. If p < 0.05, the claim needs revision.

### 2026-05-21 -- Onset variance test revised: 4-window single panel
**Changed/Found:** `plottingScript.m` line 289 -- Replaced two-panel (pre vs post) version with single-panel 4-window version. Windows: pre [-1,0]s, stim [0,1]s, [1,2]s, [2,3]s. Per-session faint lines + grand mean +/- SEM. Wilcoxon signed-rank pre vs each of 3 stim windows, p-values annotated, Bonferroni threshold 0.05/3.
**Why:** User wanted the stim epoch broken into 1-second bins to show whether variance changes gradually or at onset.
**Next:** Run in MATLAB; if all 3 p-values > 0.017 (Bonferroni), the L50 claim holds. Report the three p-values in results_edit.tex.

### 2026-05-21 -- Onset variance test: replaced with slope-based analysis
**Changed/Found:** `plottingScript.m` line 289 -- Replaced window-mean Wilcoxon test with linear slope approach. For each session, fits polyfit(1) to the variance trace in pre [-3,0]s and post [0,+dur]s windows. Console prints per-session slope_pre, slope_post, delta per session plus cross-session mean +/- SEM. Figure shows variance trace (-3 to +dur s) with faint per-session lines, bold mean +/- SEM shading, and two dashed lines for the mean pre/post slope fits. Slope values annotated in legend and title.
**Why:** p-value on window means is weak evidence for a null claim with n=13. Slope near zero in both windows + small delta directly supports "small to insignificant change in variance at onset" as a quantitative claim.
**Next:** Run in MATLAB; if mean slopes are near zero (|slope| << 1 (dF/F)^2/s) and delta is small, write results_edit.tex L50 as: "The pre-stimulus variance slope was X +/- Y and the post-onset slope was X +/- Y (dF/F)^2/s (n=13 sessions), indicating a small and consistent change at stimulation onset."

### 2026-05-21 -- Variance slope result: OL stimulation reduces variance
**Changed/Found:** Slope analysis result (n=13 OL sessions): pre-onset mean slope = -0.04 +/- 0.14 (approx zero); post-onset mean slope = -0.57 +/- 0.24 (dF/F)^2/s (consistently negative). OL stimulation actively reduces across-trial variance during the stim window -- the original claim "onset did not affect variance" is incorrect.
**Why:** Data shows the step input drives trials toward a common response trajectory, reducing trial-to-trial spread. The important comparison remains OL vs CL (CL reduces variance further and more consistently).
**Next:** Revise results_edit.tex L50: remove todo, rewrite as "OL stimulation modestly reduced variance (post-onset slope -0.57 +/- 0.24), CL produced further reduction." Note in PAPER.md updated.

### 2026-05-21 -- G2a: replaced violin with trial-average trace figure
**Changed/Found:** `plottingScript.m` G2a block -- Replaced ksdensity violin plots with time-resolved trial-average traces (0 to +3 s). Per-session faint lines (OL red, CL green), cross-session mean +/- SEM shaded, reference at -5%, grey patch over [+1,+3]s MSE window, dotted vertical at t=+1s. MSE accumulation loop (er_ncDfk_w, er_wcDfk_w) preserved; console fprintf table preserved.
**Why:** Trial averages show the time-resolved controller behaviour directly; violin plots of per-trial RMS were redundant with figure G.
**Next:** Run G2 section; check that nc_tr_g2 / wc_tr_g2 have consistent column counts across sessions (all dur=3).

### 2026-05-21 -- controller-analysis/CLAUDE.md: added two analysis context TODOs
**Changed/Found:** `controller-analysis/CLAUDE.md` -- Added "Analysis Contexts Wanted" section before Open Analyses. Two contexts: (1) motion-clean trials (|z-motion| <= 1.5, extend K1m approach to all CL vs OL figures); (2) deviation-at-onset filtered trials (|dFk at t=0| ranked per session, test whether CL decouples initial state from trial outcome).
**Why:** User wants these as standing analysis contexts for all future CL vs OL comparisons, not one-off additions.
**Next:** Add per-figure TODO comments in plottingScript.m when revisiting G, G2, F sections.

### 2026-05-22 -- OL TF section: paper-level 1x3 trial-average + TF prediction figure
**Changed/Found:** `plottingScript.m` lines 2532, 2728-2772 -- Added paper-level figure `fig_tf_paper` (12 x 4 cm, 1 row x nSess_ol cols). Initialised before the OL TF loop (after rng('shuffle')). Each tile: stim window shaded grey (t=0 to +1 s), pre-onset mean +/- SEM from ncDfk_bc cols 1:35 (t=-1 to -1/35 s), post-onset mean +/- SEM from y_mean_ol/y_sem_ol (t=0 to +1 s), TF prediction yp_ol overlaid as k--. XLim [-1 1]. Insertion done via Python byte-level replacement (file is CRLF/Windows-1252). Export line commented out.
**Why:** User requested paper-level plot showing OL trial average + TF fit in -1 to +1 s window for 3 sessions as a 1-row panel.
**Next:** Run OL TF section in MATLAB to verify figure renders; uncomment exportgraphics when satisfied.

### 2026-06-10 -- trial_state_mse.m: fixed undefined nSess, verified end-to-end run
**Changed/Found:** `controller-analysis/trial_state_mse.m` line 19 -- Added `nSess = length(fields);` (was undefined; load_sessions.m never sets it, only `motion_analysis.m`/`variance_mse.m` derive it locally). Ran load_sessions.m + trial_state_mse.m: pools 465 OL / 501 CL motion-clean trials (|z-motion| <= 1.5), sorts by total variance (trial-2s to trial end, from pncDfk_l), produces 3-col x 2-row (OL/CL) figure -- dF/F deviation heatmap, block-mean variance vs MSE, block-mean 1-4 Hz delta power vs MSE. No export (no figures as paper per user instruction).
**Why:** This is the single merged script replacing the earlier prestim_variance.m / spectral_mse_sort.m pair (already deleted) per user's request to consolidate variance-sort + delta-power + MSE comparison into one script.
**Next:** Correlations: OL MSE~var r=0.653 p=0.0007, CL MSE~var r=0.771 p<0.0001, OL MSE~delta r=-0.062 p=0.78 (n.s.), CL MSE~delta r=0.509 p=0.0093. User to review figure and direct any layout/binning changes; no paper export until told.

### 2026-06-10 -- trial_state_mse.m: replaced timeseries heatmap with power spectrum, dropped redundant column
**Changed/Found:** `controller-analysis/trial_state_mse.m` -- Reworked figure from 3 cols x 2 rows to 2 cols x 2 rows. Col 1 was a dF/F-deviation timeseries heatmap (-1 to +3 s); replaced with a power spectrum heatmap (0-10 Hz, log10 absolute power, parula colormap, percentile-based clim) computed from ncFreqPow/wcFreqPow averaged over the same trial-2s-to-end window used for the variance sort, with white dashed lines marking the 1-4 Hz delta band. Removed pncDfk_l/ncDfk-based timeseries pooling entirely (no longer needed). Dropped the old Col 3 (delta-power vs MSE) since it plotted identical (x,y) points to Col 2 (variance vs MSE) and only differed in y-tick labels; the OL/CL MSE~delta correlations are still printed to console.
**Why:** User flagged that Col 2 and Col 3 were visually the same plot (same bMSE/bYpos data, different labels), and asked for the sorted-trial heatmap to show each trial's power spectrum instead of its dF/F timeseries.
**Next:** Colorbar label ("log10 power (DeltaF/F)^2 Hz^-1") slightly overlaps the heatmap's right edge -- tighten if it bothers the user. No export yet.

### 2026-06-10 -- trial_state_mse.m: f x power(f) weighting to flatten 1/f spectrum
**Changed/Found:** `controller-analysis/trial_state_mse.m` -- 0-1 Hz power was dominating the spectrum heatmap colour range, hiding structure in 1-10 Hz bands. Added `nc_specw_s = nc_spec_s .* freqCtrs` (and wc_ equivalent) -- multiplies each band's absolute power by its band-centre frequency (f x P(f)), a fixed deterministic per-band weight applied identically to OL/CL/all trials (not a trial-relative normalization). clim_spec, imagesc data, and colourbar label all updated to the weighted quantity (units (DeltaF/F)^2, log10 colour scale). 0-1 Hz band now saturates at the top of the colourbar; 1-10 Hz bands show clear trial-to-trial structure.
**Why:** User asked how to make non-0-1Hz effects visible without violating the locked "absolute power, no normalization" rule; f x P(f) is a standard fixed re-weighting (not data-driven normalization) so OL/CL and cross-trial comparisons remain valid.
**Next:** User to confirm this visualization is useful; consider also trying a log-frequency x-axis if 1-10 Hz still needs more spread. No export yet.

### 2026-06-10 -- trial_state_mse.m: log-frequency x-axis tried and reverted
**Changed/Found:** `controller-analysis/trial_state_mse.m` -- Briefly added a log-frequency x-axis (resampled bands onto a log10(Hz) grid via interp1) on top of the f x P(f) weighting. User clarified they meant the colour/intensity should be logged (already done via log10 colour scale), not the frequency axis -- reverted to linear 0-10 Hz x-axis with f x P(f) weighting + log10 colour (nc_specw_s/wc_specw_s, freqCtrs as XData).
**Why:** Misread "use log as well" as log-frequency axis; actual ask was about log power intensity, which the f x P(f) + log10 colour step already provides.
**Next:** User to confirm current version (linear freq axis, f x P(f), log10 colour) is the desired visualization. No export yet.

### 2026-06-10 -- trial_state_mse.m: removed f x P(f) weighting
**Changed/Found:** `controller-analysis/trial_state_mse.m` -- Removed the f x P(f) weighting added earlier; heatmap now shows plain absolute power (nc_spec_s/wc_spec_s) on log10 colour scale, linear 0-10 Hz x-axis, percentile-based clim. Colourbar label reverted to "log10 power (DeltaF/F)^2 Hz^-1".
**Why:** User asked to remove the f x P(f) weighting.
**Next:** User to confirm current version (absolute power, log10 colour) is the desired visualization. No export yet.

### 2026-06-10 -- trial_state_mse.m: restored f x P(f) weighting
**Changed/Found:** `controller-analysis/trial_state_mse.m` -- Re-added f x P(f) weighting (nc_specw_s/wc_specw_s = nc_spec_s/wc_spec_s .* freqCtrs), clim/colourbar/imagesc reverted to the weighted quantity. Current state: linear 0-10 Hz x-axis, f x P(f) weighting, log10 colour, percentile clim.
**Why:** User asked to go back to f x P(f) after discussing and declining the per-band z-score alternative (z-score would be a trial-population-relative normalization, conflicting with the locked "absolute power, no normalization" rule for OL vs CL comparisons; f x P(f) is a fixed deterministic re-weighting so it doesn't have that issue).
**Next:** This is the settled spectrum-heatmap visualization for now. No export yet.

### 2026-06-15 — contra_prediction: removed CP-1, unified decontam helper, brain_overlay_fig helper
**Changed/Found:** `impulse-analysis/contra_prediction.m` — (1) Deleted the entire `[CP-1]` section (pre-trial forward-extrapolation pipeline, ~106 lines): the approach (extrapolate from pre-stim history alone) is scientifically invalid — the concurrent contra prediction with stim-bleed negation (CP-IMP) is the correct pipeline and supersedes it. (2) Merged the duplicate decontamination logic: CP-IMP Pass 1 (nested loop building `art_imp`) and CP-4a (nested loop building `contra_sum4_amp`/`art_shape4_amp`) both computed per-amplitude mean onset-locked contra SVD deviation — replaced both with calls to a new `build_onset_artifact()` local function (pre_f, post_f arguments adapt to each caller's window). CP-IMP passes `(pre_imp, post_imp+1)` then masks with `neg_mask`; CP-4 passes `(nPad_a4, outlen)` then slices post-onset. The pooled `contra_sum4`/`contra_mean4` loop in CP-4a (used for `do_decontam4` threshold check and the artifact figure) is kept separate since it accumulates the raw signal, not deviation. (3) Extracted `brain_overlay_fig()` local function: the 15-line gray-background + transparent-overlay axes setup was copy-pasted between CP-3 and CP-RRR; both now call `[fig, ~, ax] = brain_overlay_fig(mimg_cp, 8, 6)`.
**Why:** User identified CP-1 as invalid (uses only pre-stim history to extrapolate, so the prediction includes no information about the actual trial dynamics and incorrectly attributes network state changes to the laser). CP-IMP (concurrent prediction with artifact removal) is the valid approach. Redundancy cleanup reduces maintenance surface and makes it easier to tune the decontam window in one place.
**Next:** Verify script runs cleanly in MATLAB from load_experiments.m → contra_prediction.m. CP-IMP and CP-4 decontam behaviour should be identical to before the refactor.

### 2026-06-10 -- trial_state_mse.m: added in-trial-only variance window alternative
**Changed/Found:** `controller-analysis/trial_state_mse.m` -- Added a `varWinMode` knob ('pre2trial' = trial-2s to end, the prior default; 'trial' = 0s to end, in-trial only). Controls both the `pncDfk_l`/`pwcDfk_l` variance window (`varWin_a`/`varWin_b`) and the matching spectral averaging window (`sortWinF`, via `specPreBins`). Heatmap titles now show `winLabel` dynamically. Ran with `varWinMode = 'trial'`: 465 OL / 501 CL trials pooled (motion-clean), OL MSE~var r=0.977 p<0.0001, CL MSE~var r=0.978 p<0.0001, OL MSE~delta r=0.954 p<0.0001, CL MSE~delta r=0.973 p<0.0001.
**Why:** User asked for an alternative where the variance-sort uses only the in-trial window (0 to +3s) instead of trial-2s-to-end, to compare against the original.
**Next:** Note the in-trial variance and MSE are both computed over ~t=0..+3s, so the much higher r-values (~0.97-0.98) vs the pre2trial mode (r~0.65-0.77) likely reflect window overlap rather than a stronger relationship -- flag this if either mode is used in the manuscript. `varWinMode` currently left set to 'trial'; switch back to 'pre2trial' to reproduce the original figure. No export yet.
