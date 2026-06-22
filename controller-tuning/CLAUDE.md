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

## Sub-area trigger words
controller grid, gain grid, gain sweep, Kp Ki sweep, cost surface, J(Kp,Ki),
auto-tune, auto-tuning, tuning methodology, tuning convergence
(AL_0034 / AL_0033 grid+autotune → here; AL_0048 → bilateral)

## Mice & sessions (registry: `load_grid.m`)
**AL_0034** is a controller mouse not in the root locked-in list — registered here for tuning only.

Grid (mn, td, en):
- AL_0034 2024-10-17 1 · AL_0034 2024-10-18 1
- AL_0033 2025-01-10 2 · AL_0033 2025-03-03 2 · AL_0033 2025-03-05 1 · AL_0033 2025-03-17 3

Auto-tuning (mn, td, en):
- AL_0034 2024-10-25 1 · AL_0034 2024-10-25 2 · AL_0033 2024-12-19 1

## Prototype origin
- `Grid_mouseDataAnalysis.m` (root) — working exploratory script: groups trials by
  `unique(d.input_params(:,5:6),'rows')`, computes per-node cost, plots per-controller
  traces / variance / FFT, fits a `J(Kp,Ki)` surface (`linearinterp`) + 3D/contour view.
- `scratch_grid/` — saved outputs (`grid_maps.mat`, overview/montage PNGs) from earlier runs.

## Planned scripts (controller-tuning/ — run from brain_paper/ root)
- `load_grid.m`      — session registry + column map + cost knobs (DONE, stub)
- `gain_grid.m`      — per-node cost `J(Kp,Ki)`, cost surface, marked minimum (paper panel)
- `auto_tune.m`      — gain trajectory + cost-vs-iteration convergence
- `compare_tuning.m` — grid-optimal vs auto-tuned vs hand-picked gains (if in scope)

## Loading pipeline
Reuse controller area: `initialize_data → getpixel_dFoF`; cache to `data/<key>.mat`.
Proposed cache key: `sprintf('%s_grid_%s%d.mat', mn, td(6:7), en)` (mirrors `_bil`).

## input_params column map (from prototype — UNVERIFIED per-session, confirm on first load)
| col | meaning | source |
|---|---|---|
| 2 | onset sample index | `d.input_params(j,2)` |
| 3 | trial type (`==2` → feedback/CL in prototype) | `find(...==2)` |
| 5 | Kp (proportional gain) | `unique(...,5:6)` |
| 6 | Ki (integral gain) | `unique(...,5:6)` |
Auto-tune online-update columns: **TBD** (how the rig logs the adapting gains).

## Cost function (RESOLVED 2026-06-22)
- Window: `t = 0 s … +3 s` post-onset (matches controller-area default MSE window).
- Metric: `mean_trials( ‖dF/F − ref‖₂ over window )` per (Kp,Ki) node.
- **Reference: read per-session `d.ref`** — do NOT hard-code. Print/assert `d.ref` on load.
  (Prototype's −2 and the project −5 are both just fallbacks; the session value wins.)

## Auto-tuning method (RESOLVED 2026-06-22)
- **Zero-order / model-free optimization** — no plant model is identified; the optimizer
  perturbs gains and reads back the empirical cost.
- The evolving **Kp/Ki are stored in `input_params` cols 5:6 per trial** (same columns as
  the grid). So: grid session = small set of fixed (Kp,Ki) values, each repeated over many
  trials; auto-tune session = (Kp,Ki) forms a *trajectory* over trials. Distinguish by the
  registry split in `load_grid.m`, cross-checked by unique-gain count per session.
- Convergence figure = gain trajectory (Kp,Ki vs trial/iteration) + cost-vs-iteration,
  described empirically (don't assert a specific update rule unless confirmed).

## Paper scope (RESOLVED 2026-06-22) — two proper paper figures
1. **Grid cost-function surface** — `J(Kp,Ki)` surface/contour with the minimum marked.
2. **Auto-tuning convergence** — gains + cost converging (ideally toward the grid minimum).
Both are real paper panels (paperFig/paperStyle, 6 pt bold, vector export).

## Locked-in decisions (provisional until data confirms)
- PI only (Kp, Ki); no Kd.
- Offline, no live interface.
- Cache flag: `r_grid = 1` load / `r_grid = 0` recompute.
- Export PNG by default; promote to PDF only when a panel is listed in PAPER.md.

## Open questions (remaining)
1. Exact zero-order update rule (simplex / coordinate descent / SPSA / pattern search)?
   — only needed for a precise Methods sentence; figures don't depend on it.
2. Are these sessions cached in `data/` or pulled fresh from the sahale share? (check on load)
3. Confirm input_params cols 2/3/5/6 hold on the actual sessions (verify on first load).

## Export paths
`paper/images/tuning/` — panels TUNE-* (create on first export).
