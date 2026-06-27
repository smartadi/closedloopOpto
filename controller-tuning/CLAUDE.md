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

## ⛔ CURRENT STATUS (2026-06-26) — READ FIRST (HANDOFF)
Scripts are written + `check_matlab_code`-clean, but the loader's **data-source and column
assumptions FAILED on the first real run**. Do **not** trust `G`/`A` output yet.

**Solved:** speed. The loader no longer calls `initialize_data`, so the `face.mp4` decode that
made it crawl is gone — sessions load in seconds.

**Broken / discovered on first run (AL_0033 vs AL_0034 differ — see RESEARCH 2026-06-26):**
1. **`input_params` column layout differs by mouse** (both space-delimited; `readmatrix` parses):
   AL_0033 = **8 cols** (onset@2, Kp@5, Ki@6 — prototype map is right *for AL_0033*);
   AL_0034 = **7 cols** (gains look like @2/@3, `col6`=0-based trial counter, `col4`=|ref|=5,
   **no onset-frame column**). The loader's fixed `KP_COL=5/KI_COL=6/ONSET_COL=2` produced
   garbage for AL_0034 (read the trial counter as "Ki 0–204", onset=0 → all trials skipped, J=NaN).
2. **Output units differ by source.** Bare `pixel*.mat` caches hold **raw F (~1300)**, NOT dF/F →
   `pick_trace` is unreliable. `mean_states.csv` ≈ 1.0 → **F/F₀ ratio**. The crash on session 2
   was empty `y` from a bad column pick on the single-row `mean_states.csv`.
3. **`states.csv` (1×300000) exists for EVERY session** (root, or `data/` for subdir sessions),
   starts at 0 → the **regulated dF/F signal**; `input_amps.csv` (1×300000) = control input.
   This is the clean **uniform** output source — no SVD, no video, no unreliable caches.

**PLAN (NOT yet implemented — do this next):** rewire `ct_load_session` to use **`states.csv`**
as `y` for all sessions; add a **per-mouse column map**; derive AL_0034 onsets (no onset col)
by detecting laser-on in `input_amps.csv`. Then re-test on AL_0033 first (cleanest).

**BLOCKING — ask the user before rewiring (see "Open rig questions" below).** Wrong guesses
on units/rate/onset-space cost a full run. The user paused here to checkpoint for a fresh session.

## Open rig questions — ASK THE USER FIRST (blocking)
1. **states.csv** = the controller's regulated output (kernel-mean dF/F)? Its **units** (% like
   `ref=−5`, or fraction) and **sample rate** (300000 samples = ? Hz; what session duration)?
2. **AL_0034 input_params (7-col)** — confirm gains = cols **2:3** (Kp,Ki), `col4`=|ref|, `col6`=trial
   counter, `col7`=type, `col1`=? ; and since there's **no onset column**, where do AL_0034 trial
   onsets come from — detect from `input_amps.csv` (laser-on), or a separate stims file?
3. **AL_0033 input_params (8-col)** — confirm `col2`=onset index, and whether it indexes the
   **states.csv sample space (300000)** or the imaging frames (~140975).
4. **AL_0034 10-25 e2** — no cache/`mean_states`/root `blue/`: any output source, or drop it?
5. (minor) exact zero-order update rule, for one Methods sentence (figures don't depend on it).

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

## Auto-tuning method (RESOLVED 2026-06-24)
- **Zero-order / model-free optimization** — no plant model; perturb gains, read back empirical cost.
- Evolving Kp/Ki stored in `input_params` per trial (column index per the per-mouse map above).
  Grid session = small set of fixed (Kp,Ki) each repeated; auto-tune = (Kp,Ki) trajectory over trials.
- Convergence figure = gain trajectory + cost-vs-iteration, described empirically.

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

## Export paths
`paper/images/tuning/` — panels TUNE-* (create on first export).
