# figures_final — the locked paper panels (Illustrator pull-folder)

**Pull every panel into Illustrator from `panels/<figure>/` — never from
`paper/images/figureN/`** (those are working dirs full of superseded panels).

`panels/<figure>/` holds EXACTLY the locked set and nothing else. The list is
`MANIFEST.txt`; the sync is `collect_final_panels.m`:

- **Lock a panel** → add its source line under the right `[section]` of `MANIFEST.txt`,
  then run `collect_final_panels` (from MATLAB, in this folder).
- **Retire a panel** → delete its line, re-run. The collector copies listed sources in
  and **deletes any panel PDF not in the manifest**, so the folder never accumulates
  unused panels. `collect_final_panels('dry')` previews without changing anything.
- Keep `MANIFEST.txt` = PAPER.md's "Paper panels in use" registry.

`paper/` is gitignored, so the tracked record is **MANIFEST.txt + collect_final_panels.m +
this README**; the panel PDFs themselves are local-only.

The top-level `FigureN.pdf` below are the assembled figures (Illustrator output); refresh
by re-copying after re-assembling.

| File | Source | Source date | Status |
|------|--------|-------------|--------|
| Figure1.pdf | `paper/images/Figure1.pdf` | 2026-05-11 | stable (older; only copy) |
| Figure2.pdf | `paper/images/figure2/Figure2.pdf` | 2026-09-11 | current (residual row cut; 3 rows) |
| Figure3.pdf | `paper/images/Figure3.pdf` | 2026-09-08 | current |
| Figure4.pdf | `paper/images/figure4/Figure4.pdf` | 2026-09-11 | ⚠ IN PROGRESS — Row-2 session-level stats + SR rejection metric being finalized; re-assemble after Row-2/Row-3 panel updates |
| Figure5.pdf | `paper/images/figure5/Figure5.pdf` | 2026-08-12 | stable |

## panels/ — individual source panels per figure
`panels/figureN/` holds the individual panel PDFs that compose each assembled
figure, taken from PAPER.md's "Paper panels in use" registry (retired/superseded
panels excluded). Copy by PATH: for Fig 5 the assembled-figure letters do NOT
match the filenames (E=variance, F=RMSE, J=phase, K=variance) — read the path.

| Figure | panels copied | notes |
|--------|---------------|-------|
| figure1 | 3 | only the raster/vector panels; 1D/1E/1F are Illustrator-native (no PDF) |
| figure2 | 8 | A imp_response, B imp_single, C tf_cv_single (from supplementary/), **D tf_cv_heldout_r2** (2026-09-13: held-out R² per session + IQR, pooled median 0.86; the shape overlays tf_cv_shape_across / _2D_sidebar / _2D_endlabels moved to panels/supplementary/), E tf_model_swap, F tf_tau_forest, G imp_state_var_motion, H imp_state_var_reldelta |
| figure3 | 10 | verified against assembled Figure3.pdf (A–J). 3K (pooled_ol_cl_rmse_15sess) is NOT in this assembly — it's pending re-assembly per PAPER.md; the manuscript includes Figure3_extra.pdf, which may differ |
| figure4 | 7 | 2026-09-21 user spec: exemplars (f4_state_exemplars); error decomp init/motion/rel-2-4/abs-δ each δ own model (f4_decomp_unique_sep); quartile OL−CL gap vs pred error init/motion/rel-2-4/abs-δ w/ session-aware LMM star (f4_2A_initdev, f4_2B_motion, f4_2C_delta, f4_2D_absdelta); contra-model setup letter-free (f4_contra_model). Letters added in Illustrator. Old contra-level Panel A (ctrl_state_xsess) DROPPED |
| figure5 | 10 | verified against assembled Figure5.pdf (B–K; A is the Illustrator control diagram, no PDF). s2 primary session + 3 across-session combined panels |

## Caveats
- The manuscript (`../../Closedloop_edit/images/`) currently includes **stale**
  copies for Figs 2 & 3 (`Figure2_extra.pdf`, `Figure3_extra.pdf`, both June) —
  sync the files above into the manuscript's `images/` before the next compile.
- No `Figure4.pdf` is included in the manuscript yet (Fig 4 still being finalized).
- Fig 4 here is the pre-2026-09-12 assembly; it does NOT yet reflect the
  regenerated Row-2 panels (session-level star) or the SR rejection metric.

_Last refreshed: 2026-09-21 (manifest-driven via collect_final_panels.m)._
