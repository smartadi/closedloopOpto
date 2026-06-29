# Controller Tuning — Session Context

## Purpose / framing
**Secondary analysis: *how the closed-loop controller gains were chosen.*** Not the focus
of the paper — the focus stays CL-vs-OL variability/error (controller-analysis). This area
shows the *tuning methodology* behind the gains used elsewhere:
- **Gain grid** — a session runs several fixed PI controllers (Kp, Ki pairs); trials are
  grouped by controller and a cost `J(Kp,Ki)` is computed per node → cost surface + minimum.
- **Auto-tuning** — the controller adapts its gains online; the gain trajectory + cost are
  read back to show convergence (ideally toward the grid minimum).

This is a *unilateral* analysis on the main controller mice. Do **not** confuse with:
- the **AL_0046 photostim spatial grid** (galvo X/Y site mapping → `package_grid_for_collab.m`)
- the **AL_0048 bilateral** Kp/Ki sweep + gradient descent (`bilateral-analysis/cl_tuning.m`)

---

## ✅ CURRENT STATUS (2026-06-27) — DATA MODEL RESOLVED, loader rewired
The 2026-06-26 first-run failures are fixed. `ct_load_session` was rewired and verified against
the share; `G`/`A` output is now trustworthy. **7 of 9 sessions run** (4 grid + 3 autotune);
`gain_grid.m` + `auto_tune.m` export figures to `paper/images/tuning/`.

**Resolved data model (verified from files, see RESEARCH 2026-06-27 + FINDINGS):**
- **y = `states.csv`** — regulated kernel-mean signal in **% ΔF/F**, logged at **35 Hz**
  (laser-on run = 105 samples = `dur`=3 s; `params.mat` has `dur/horizon/kernel`), 300000-sample
  buffer, median ≈0. A few hundred logging-glitch samples (|y| up to 1e5) are NaN'd via
  `cfg.YCLIP=80`. Read with a robust `textscan` row reader (`readmatrix` → 1×1 NaN on these
  single-row sci-notation files). `mean_states.csv` = F/F₀ ratio (≈1) — NOT used. Bare `pixel*.mat`
  caches = raw F — NOT used.
- **input_params layout is per RIG-VERSION (detect by #columns), not per mouse:**
  - **8-col** (7 of 9 sessions, incl. BOTH AL_0034 10-25 autotune): onset=**col2** (index into the
    SAME 35 Hz states axis — matches `input_amps.csv` rising edge off-by-1), Kp=**col5**, Ki=**col6**,
    |ref|=**col7** (=5). `col1`=trial counter, `col3`=type, `col4`=step amp, `col8`=dur(3).
  - **7-col** (only AL_0034 2024-10-17 e30, 2024-10-18 e1): gains=**col2:3**, |ref|=col4, `col6`=trial
    counter — **NO onset column** and **no input_amps.csv** → onsets unavailable → `status='hold'`.
- **ref = −|col7| = −5** for all 8-col sessions (settled t=2–3 s median −4.3…−5.2). Overrides the
  stale registry `ref=−2`; ref is now derived from the data in the loader.

**Open follow-ups (not blocking):**
1. **7-col AL_0034 onset adapter** — derive onsets from Timeline (`lightCommand`/`galvo` @2 kHz,
   `daqSampleRate=2000`) mapped to the 35 Hz states axis, to unblock the 2 held grid sessions.
2. Grid-min sits at the swept **boundary** (Kp=Ki=0.2); autotune does **not** visibly converge to it
   — decide framing / check the other sessions (FINDINGS.md).
3. (minor) exact zero-order update rule, for one Methods sentence (figures don't depend on it).

---

## Sub-area trigger words
controller grid, gain grid, gain sweep, Kp Ki sweep, cost surface, J(Kp,Ki),
auto-tune, auto-tuning, tuning methodology, tuning convergence
(AL_0034 / AL_0033 grid+autotune → here; AL_0048 → bilateral)

## Per-session data layout (server scan 2026-06-26) — registry in `load_grid.m`
**AL_0034** is a controller mouse not in the root locked-in list — registered here for tuning only.
Each registry row carries source tags: `ip` (root|`data/`), `gain` (ip|kr), `ysrc`, `status`.
**`gains` column + `output y` here reflect the CURRENT (partly wrong) loader — see status block.**

| session | input_params loc | gains (loader) | output (loader) | states.csv | status |
|---|---|---|---|---|---|
| AL_0034 2024-10-17 e30 | `data/` subdir | ip 2:3 (7-col) | raw-F cache ✗ | `data/states.csv` | needs rewire |
| AL_0034 2024-10-18 e1  | root (no amps) | **Kr.npy** | `mean_states.csv` (ratio) | `states.csv` | needs rewire |
| AL_0033 2025-01-10 e2  | `data/` subdir | ip 5:6 (8-col) | bare cache | `data/states.csv` | needs rewire |
| AL_0033 2025-03-03 e2  | root | ip 5:6 | bare cache (raw F) | `states.csv` | needs rewire (prototype) |
| AL_0033 2025-03-05 e1  | root | ip 5:6 | `AL_0033pixel03051.mat` (has dFk) | `states.csv` | closest to working |
| AL_0033 2025-03-17 e3  | root | ip 5:6 | bare cache | `states.csv` | needs rewire |
| AL_0034 2024-10-25 e1  | root | ip 2:3 | cache/`mean_states` | `states.csv` | needs rewire (auto-tune) |
| AL_0034 2024-10-25 e2  | root | ip 2:3 | none found | ? (check) | **hold** |
| AL_0033 2024-12-19 e1  | root | ip 5:6 | bare cache | `states.csv` | needs rewire (auto-tune) |

Resolved facts: `mean_states.csv` = kernel-mean (F/F₀ ratio, ≈1); `Kr.npy` = per-trial (Kp,Ki) schedule;
`blue/` SVD exists at root ONLY for the three 2025-03 sessions; `states.csv` + `input_amps.csv`
(both 1×300000) present for ALL sessions → the intended uniform source.

## input_params column maps (INFERRED from data — confirm with user, Q2/Q3)
**AL_0033 (8 cols):** `1`=trial idx · `2`=onset index · `3`=type · `4`=step amp(varies) ·
`5`=**Kp** · `6`=**Ki** · `7`=|ref|(=5) · `8`=? (=3)
**AL_0034 (7 cols):** `1`=?(0.125) · `2`=**Kp?** · `3`=**Ki?** · `4`=|ref|(=5) · `5`=?(4/3) ·
`6`=trial counter(0-based) · `7`=type · (no onset-frame column)

## Cost function (RESOLVED 2026-06-24)
- Window: `t = 0 s … +3 s` post-onset (matches controller-area MSE window).
- Metric: `mean_trials( ‖y − ref‖₂ over window )` per (Kp,Ki) node; `y` = regulated dF/F.
- Reference per-session (registry `ref`); units must match `y` (resolve via Q1).

## Auto-tuning method (RESOLVED 2026-06-29) — METHODS-READY
- **Zero-order / model-free, greedy accept-if-lowered.** No plant model. Each iteration: apply a
  candidate (Kp,Ki) for `N_tune` reps, average its cost; **if cost ≥ best-so-far, REVERT** to the
  previous gains; else accept. Next candidate = accepted point + a random step (unit direction ×
  [STEP_KP, STEP_KI], step annealed geometrically). Source: `rainier/StLab_Rainier/Main_experiment.py`
  (+ `experiment_core/base_controller.py`).
- **Trajectory data:** the per-trial `input_params` logs EVERY applied candidate incl. rejected probes —
  for analysis/figures use the saved **accepted** gains `Kdata.npy` + costs `Kval.npy`, NOT input_params.
- **Recorded-session validity (verified from Kval):** only sessions with a LIVE online cost converge —
  **AL_0033 03-17 (Kval 16.6→12.3 → 0.068,0.064)** and **AL_0034 10-25 e1 (11.9→4.57)**. AL_0033 12-19
  had Kval≡0 (dead online error → random walk); AL_0034 10-25 e2 stuck at (0,0). See FINDINGS.md.
- **Rig fixes (2026-06-29, StLab_Rainier — affect FUTURE runs only):** (1) cost now from synced
  `statedf` not the dead `self.er`; (2) cost = full deviation trace → `mean(‖y−ref‖₂)` (RMS, penalises
  oscillation) not `|mean err|`; (3) step-size annealing added. `N_tune` small = testing.
- **Same-mouse rule:** compare autotune ↔ grid only within a mouse (AL_0033 03-17 ↔ grid 03-05).
- Convergence figure = accepted (Kp,Ki) path + Kval-vs-iteration (paper panel **T-C**).

## Paper scope (RESOLVED 2026-06-24) — two proper paper figures
1. **Grid cost-function surface** — `J(Kp,Ki)` surface/contour with the minimum marked.
2. **Auto-tuning convergence** — gains + cost converging (ideally toward the grid minimum).
PaperFig/paperStyle, 6 pt bold; PNG until a panel is promoted in PAPER.md.

## Scripts (run from brain_paper/ root)
1. `load_grid.m`  — RUN FIRST. Plain script (no local funcs → no stale-cache trap): registry +
   knobs (`cfg`), calls `ct_process_set`, caches `G`/`A` to `data/grid_tuning_cache.mat`. `r_grid=0`
   recompute / `1` load. **Prints a per-session `align-check` line — use it to verify onset units.**
2. `ct_process_set.m` — `ct_process_set` (load loop + cost + grouping) + `ct_load_session`
   (per-session reader: `input_params` root/`data`, gains ip/Kr, output cache/mean) + `pick_trace`.
   **This is where the states.csv rewire + per-mouse column map go.** Edit it → `clear all; rehash`.
3. `gain_grid.m`  — consumes G. Fig1 = cost surface (1D fallback if one gain fixed); Fig2 = per-node
   mean±std traces. Knob `SEL`. (Unaffected by the rewire — same G schema.)
4. `auto_tune.m`  — consumes A. Kp/Ki trajectory + cost + running-best vs iteration. Knob `SEL`.
- `compare_tuning.m` — (future) grid-optimal vs auto-tuned vs hand-picked gains.
Outputs → `paper/images/tuning/`.

## Locked-in decisions
- PI only (Kp, Ki); no Kd. Offline; **motion never loaded** (no `initialize_data`).
- Export PNG by default; PDF only when a panel is listed in PAPER.md.
- **Compare grid ↔ autotune WITHIN THE SAME MOUSE only** (AL 2026-06-29). Valid pairs:
  AL_0033 grid {01-10,03-03,03-05} ↔ AL_0033 autotune {12-19,03-17};
  AL_0034 grid {10-17} ↔ AL_0034 autotune {10-25 e1/e2}. Never cross mice.
  Implication for the paper: the strong same-mouse story is **AL_0033 grid 03-05 + autotune 03-17**.

## Export paths
`paper/images/tuning/` — panels TUNE-* (create on first export).
