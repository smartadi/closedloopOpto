# Lab style vs our jn style: every JN paper figure, both ways (2026-11-05)

Aditya asked for all paper figures remade in the lab style (Anna's `steinmetzlab-style`),
assembled automatically and put in one folder, to compare with the current plotting setup.
Nothing here is a paper figure, and nothing here changes one. `paper/figures_final/`,
`paper/images/` and `data/` were checked against a snapshot after every run; anything a
producer wrote there was restored from the backup.

## Start here

| File | What it is |
|---|---|
| `compare/ALL_compare.pdf` | One page per figure: **our jn style (left)** and **lab style (right)**, drawn by today's code |
| `compare/<Figure>_compare.png` | The same, one PNG per figure |
| `drift/ALL_paper_vs_today.pdf` | Figures where the panel **in the paper** differs from what its producer draws **today**, in the jn style. This is about content, not style (see "Drift" below) |
| `audit/audit_{current,jnrerun,lab}.txt` | The lab's required checks (`utils/sls_audit_pdf.py`) on the assembled PDFs. `audit/*_lab_p1_audit.png` boxes the problems in red |

Both sides of a compare sheet come from the **same .fig** (saved before either style was
applied), so any difference between them is style alone. The left side is our jn style
re-run today, not the PDF in the paper. That rules out content changes made since the paper
copy was exported. The paper's own assembly is in `assembled/<Figure>_current.pdf`.

## Folders

| Folder | Contents |
|---|---|
| `assembled/` | `<Figure>_current.pdf` (paper copy), `_jnrerun.pdf` (jn style, today), `_lab.pdf` (lab style), plus PNGs |
| `src/` | Each panel's figure as its producer drew it (`.fig`), before any style pass |
| `jnrerun/images/`, `jnrerun/panels/` | Every panel in jn style (`jnAxesAll`), exported the way `paper_final_mirror` does |
| `images/`, `panels/` | Every panel in lab style (`sls_style_fig`); `panels/<section>/` holds the MANIFEST-listed ones |
| `jn/fig1/`, `jn/fig2/` | Lab-style panels for Figs 1 and 2, which have their own builders |
| `other/` | Panels exported outside `paper/images` |
| `assembly_map.json` | Which panel fills which slot in each Illustrator file (matched by appearance) |
| `assembly_log.txt`, `drift_panels.txt` | Build log; per-panel paper-vs-today scores |

## What the lab pass changes (`utils/sls_style_fig.m`)

The lab's `paper.mplstyle`, translated to MATLAB:

- **Axis labels and titles: 7 pt regular** (ours: 7 pt bold). This is the most visible change.
- **Axis lines 1 pt** (ours: 0.5 pt).
- **Ticks point in, 4 pt long** (ours: out, 2 % of the longer side).
- **Axis ends sit on the first and last tick** (`spines_to_ticks`), but only where no data
  falls outside them. MATLAB can't shorten a spine, so the axis limits move instead.
- **Reference lines: 0.5 pt dashed 50 % gray.** This covers gray horizontal `yline`s, and any
  gray `xline` or two-point line that is already dashed or dotted. Solid vertical lines (stimulus
  edges) and solid two-point lines (scale bars) are left alone.
- **Diverging maps → CET-D1A** (white centre), for example in Fig 4E and the raster strips.
  The colour limits are unchanged.
- **Legends:** regular weight, no box. **Colour bars:** no tick marks, no outline.

Unchanged: data colours and line widths (locked), annotation text, legend and colour-bar type
size, and the panel canvas sizes. Legends stay at their own size because 7 pt legends ran off the
canvas in Figs 2A and 2C.

## What to look at

- **Label weight and axis weight** carry most of the difference. The lab figures look lighter
  in the labels and heavier in the axes.
- **Ticks in, on heat maps** (Fig 2E): an inward tick runs into the map, and next to a positive
  tick label it reads like a minus sign ("0.12" looks like "−0.12").
- **Corners:** with the axis ends on the ticks, the first x and y tick labels can crowd each
  other (for example Q1 and 0.5 in Fig 2G).
- **Panels come out 0.1–0.2 cm smaller.** With ticks pointing in, the tick marks take up no
  space outside the axes.
- **Reference lines** are dashed and lighter. **Diverging maps** use the CET map in place of
  red-white-blue.

These are open choices for Aditya and Nick (CLAUDE.md, "Lab style repo"). None is applied to the paper.

## Audit (lab required rules, on the assembled PDFs)

- **Lab version:** passes every required check except one, which is already in the paper.
- **Already in the paper (all three versions):** "Target level" in the **Fig 5A schematic** is
  **2.9 pt**, under the 5 pt floor. It is outlined text in the Illustrator file, not a MATLAB panel.
- **jn re-run only:** two text overlaps, one in Fig 4 at (6.8, 9.7) cm and one in S_varx at
  (13.6, 0.2) cm. The paper copies don't have them, so they come from today's re-render and
  not from the jn style.

## Kept as in the paper (not re-rendered, identical on both sides)

- **Fig 4G** (`f4_cl_reject_RR`). `f4_cl_reject_panel` needs `f4_cl_reject_lmm` re-run first,
  and that needs the server SVD.
- **TikZ panels:** S_varx B (`varx_B_construction`) and Fig 6 / S_mpc `mpcd_0b_problem`.
- **Hand-made art:** the Fig 5A schematic and one S1 group (3.9 × 3.2 cm) that no MATLAB panel matches.
- **Figs 1 and 2:** the jn re-run is the paper copy, built from the same sources by their own builders.

## Drift: the paper's panels vs today's code (not a style issue)

Re-rendering everything turned up panels whose paper copy no longer matches what the producer
draws today. This is separate from the style question, but worth checking before submission:

**Fig 4A, 4C and 4F (`f4_agl`) are older than the corrected onsets.** Their last producer runs
were on 09-28 (`f4_state_exemplars`), 10-11 (`f4_error_decomp`) and 10-12 (`f4_contra_model`). The
corrected onsets were ported into the MATLAB pipeline on 10-27 (6f72136), and the session caches
were rewritten then. The 11-03 relabel changed words only and didn't re-run these producers. So:

- **Fig 4A** shows a **shorter pre-stimulus window** than today's producer draws. Its 09-28 export
  also predates the 10-02 lock of the [−2, +3) s state window.
- **Fig 4C** initial-deviation unique R² (0–1 s): **0.53 ± 0.05 in the paper** (`results.tex`
  line 198, FINDINGS) vs **0.562 ± 0.050 today**. The 11 sessions and the settings are the same,
  and a clean run (`load_sessions` then `f4_error_decomp` alone) gives 0.562 too. The other bars
  move as well: abs 1–4 Hz 0.099 / 0.129 and rel 2–4 Hz 0.050 / 0.033 (0–1 s / 1–3 s).
- **⚠ `controller-analysis/data/f4_error_decomp.mat` now holds the corrected-onset numbers.** The
  ctrl stage overwrote it (that folder was outside the snapshot). The old cache (0.529) is gone.
  The SfN poster's `poster/sfn2026/unique_panel.m` reads this file. The poster itself is unchanged,
  but re-running that script would now draw 0.562. The pre-fix session caches are in
  `data/_pre_onset_fix/` if the old numbers are ever needed.
- The Fig 4 row-2 LMM caches (`data/f4_row2_*.mat`) came out identical, so Fig 4D's statistics
  were already on the corrected onsets.

Other drift, cause not checked:

- **State-quartile supplement** (`sq_*_dist`, `_ratio`, `_rms`, impulse panels exported 10-29):
  visibly different distributions (scores 0.78–0.92). The controller onset fix doesn't apply to them.
- **S1A** (`imp_spatial_area`): different automatic ticks (x 0–2 vs 0–1.8, y step 0.5 vs 0.2).
- **OLbest** looks identical by eye. It scores 0.89 only because the panel sizes differ slightly.

The score is the correlation between blurred renders (about 1 mm blur): 1.00 means identical.
A size change alone lowers it, so treat anything above about 0.95 as noise.

## Rebuild

From the project root, in MATLAB, one stage at a time (each loader clears the workspace):

```matlab
RUN_LS_STAGE = 'ctrl'; run(fullfile(pwd,'paper-writing','labstyle_remake.m'))   % then 'mpc','tune','sine','imp','fig2'
RUN_LS_ONLY = {'load_sessions','variance_mse'};                                 % optional: a subset of a stage
labstyle_reexport('', {'lab'})        % re-render from src/*.fig after a change to sls_style_fig, no producers
```

Then, with Illustrator installed:

```
py -3 paper-writing/labstyle_assemble.py build     # assembled/, compare/, drift/
py -3 paper-writing/labstyle_assemble.py drift     # drift sheets only, no Illustrator
```

**Before a run:** snapshot `paper/figures_final`, `paper/images` and `data/`. **After it:**
restore from the snapshot. With `PAPER_FINAL` on, some producers still write outside this
folder:

- `ctrl_mpc_direct_panels` writes `mpcd_0b_problem`, and `ctrl_mpc_varx_supp_panels` writes
  `varx_B_construction` (TikZ copies). Both go into `figures_final/panels/` and `images/`.
- `ctrl_best_fixed_ol`, `sine_ff_across_sessions`, `f4_state_exemplars_supp` and
  `imp_state_quartile_supp` (`sq_stats.csv`) export straight to `images/`.
  `imp_state_raster_peramp` did too on 2026-11-05; it now writes to this folder in a lab run
  (not yet re-run).
- Data caches are rewritten by `f4_row2_quartiles`, `variance_mse` and `load_grid` (all in
  `data/`), and by `f4_error_decomp` and `ctrl_best_fixed_ol` (in `controller-analysis/data/`,
  outside the 2026-11-05 snapshot; see Drift). `load_experiments` rewrites
  `impulse-analysis/data/stim_vars_*.mat`. **Snapshot those two folders as well.**
- `latencyAnalysis` (Fig 1C, run by hand) writes `figures_final/jn/fig1/panel_c_latency.pdf`.

Code: `utils/sls_style_fig.m`, `utils/sls_lab_export.m` (hook in `jnExport`/`paperExport`,
active only when `global PAPER_LABSTYLE` is true), `utils/sls_lab_render.m`,
`paper-writing/labstyle_{remake.m,reexport.m,assemble.py}`. The log is in RESEARCH.md, 2026-11-05.
Only this README is tracked in git.
