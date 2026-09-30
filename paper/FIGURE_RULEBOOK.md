# Figure Rule Book (Journal of Neuroscience conventions)

Grounded in JNeurosci "Information for Authors" + Nature Neuroscience formatting +
common figure-design practice. Use the `utils/jn*` MATLAB helpers to enforce it.

## 1. Figure widths (HARD limits — JNeurosci)
Figures must be submitted at final print size, at one of three column widths:

| Class      | Width   | Use for |
|------------|---------|---------|
| `single`   | 8.5 cm  | 1–2 small panels, a single plot |
| `onehalf`  | 11.6 cm | 3 panels in a row, medium figures |
| `double`   | 17.6 cm | full multi-panel figures (our Fig 3, Fig 4, Fig 5) |

- **Max height:** keep under ~22 cm (one page); shorter is better.
- Principle (JNeurosci): *"figures should be the smallest size that conveys the
  essential scientific information."* Do not exceed the width you need.

## 2. Panel size (the whitespace fix)
Do **not** hand-pick 6×4 cm per panel — that overflows a double column at 3/row.
Compute panel width from the grid so a row exactly fills its column class:

    panel_width = (figure_width − (ncols−1)·gap) / ncols     (gap = 0.5 cm)

| Row on `double` (17.6) | ncols | panel width |
|---|---|---|
| 2 across | 2 | 8.55 cm |
| 3 across | 3 | 5.53 cm |
| 4 across | 4 | 4.13 cm |
| 5 across | 5 | 3.30 cm |

- **Default data-panel:** ~4–5.5 cm wide.  **Default row height: 3.3 cm** (was 4.0).
- Time-series panels may be wider (lower ncols); square-ish for scatter/bars.
- A brain image or a "hero" panel can span 2 grid cells; keep others on the grid.

## 3. Fonts
- **Family:** Arial (sans-serif) everywhere. Convert to outlines on final EPS/PDF.
- **Sizes (final print, pt):** panel letter **8 bold**, axis label / title **7 bold**,
  tick labels **6 regular**, in-panel annotation / legend **6**. **Never below 5 pt.**
- **≤ 3 distinct font sizes per figure**; identical sizes across all figures.
- Panel letters (A, B, …) are added in **Illustrator**, not in MATLAB, so panels carry
  no letter margin.

## 4. Line weights (pt)
axes/box **0.5** · reference/grid **0.75** · mean/primary trace **1.0** (was 1.5) ·
model fit **1.0** · individual trials **0.4** · error bars **0.5**.
Keep these identical across every panel — mismatched weights are a common reviewer flag.

## 5. Whitespace / layout
- Tiled figures: `TileSpacing='compact'`, `Padding='tight'`.
- Single-axes figures: let the axes fill the canvas (thin margins), don't leave the
  default ~15% MATLAB border.
- Trim redundant titles/legends; one legend per row (leftmost panel).
- `TickDir='out'`, `Box='off'`, short ticks.

## 6. Export
- **Line art → vector PDF** (`exportgraphics(...,'ContentType','vector')`); never rasterize plots.
- Heatmaps/photos → 300 dpi (color/grayscale) PNG; bitmap line art → 1200 dpi.
- White background.
- **CROPPED, not exact-page.** `exportgraphics('vector')` crops the PDF page to the content
  bounding box, so no title/label/trace is ever clipped. We tried exact-page `print('-vector')`
  (page = `jnFig` canvas) but it *clips* content that overhangs the canvas (e.g. tiledlayout
  titles flush to the top edge — panel A). Control size via the `jnFig(w,h)` canvas + small
  fonts, never a fixed page that crops. **True import size = the cropped bbox** (measure from the
  PDF MediaBox; it is a few mm off the nominal canvas), and that is exactly what Illustrator
  places at 100% — quote *that*, not the nominal canvas.

## 6a. Figure size catalog (measured cropped import widths, cm)
Panels are placed at **100%** on a **17.6 cm** (double-column) artboard with **~0.25 cm** gaps;
each row stays inside 17.6 with ≥1 cm clearance. Sizes are the real PDF MediaBox.

| Fig | Panel | file (paper/figures_v2/…) | W × H (cm) |
|-----|-------|---------------------------|------------|
| 4 | A exemplars | figure4/f4_state_exemplars.pdf | 7.83 × 3.60 |
| 4 | B model eqn | figure4/f4_1B_equation.pdf | 3.14 × 1.87 |
| 4 | C unique R² | figure4/f4_decomp_unique_sep.pdf | 5.04 × 3.32 |
| 4 | D state×perf | figure4/f4_row2_quartiles.pdf | 16.58 × 3.39 |
| 4 | E kernel map | figure4/f4_kernel_map.pdf | 3.67 × 2.68 |
| 4 | F A=G+L | figure4/f4_agl.pdf | 4.80 × 3.35 |
| 4 | G rejection | figure4/f4_cl_reject_RR.pdf | 5.08 × 3.28 |
| 3 | A single trial | figure3/panel_A.pdf | 8.43 × 3.28 |
| 3 | B trials+avg | figure3/panel_B.pdf | 8.43 × 2.75 |
| 3 | C avg inputs | figure3/panel_C.pdf | 8.40 × 2.43 |
| 3 | D variance(t) | figure3/panel_D.pdf | 3.35 × 3.07 |
| 3 | E RMSE violin | figure3/panel_E.pdf | 3.35 × 2.29 |
| 3 | F xsess variance | figure3/all_variance_sessions.pdf | 3.21 × 3.10 |
| 3 | G xsess RMSE(t) | figure3/all_average_sessions.pdf | 2.96 × 3.10 |
| 3 | H variance ratio | figure3/variance_ratio_by_window.pdf | 4.20 × 3.17 |
| 3 | I RMSE ratio | figure3/MSE_ratio_by_window.pdf | 4.41 × 3.17 |

Fig-3 row layout that fits 17.6 (0.25 cm gaps): R1 = A+B = 17.11 · R2 = C+D+E = 15.60 ·
R3 = F+G+H+I = 15.53.

| 2 | dose-response | figure2/imp_response.pdf | 3.77 × 3.67 |
| 2 | single traces | figure2/imp_single_AL_0033_2025-01-29_en1.pdf | 3.49 × 3.10 |
| 2 | TF cv single (supp) | supplementary/tf_cv_single_AL_0033.pdf | 3.67 × 3.46 |
| 2 | held-out R² | figure2/tf_cv_heldout_r2.pdf | 3.74 × 3.42 |
| 2 | model swap | figure2/tf_model_swap.pdf | 3.81 × 2.68 |
| 2 | tau forest | figure2/tf_tau_forest.pdf | 3.70 × 3.39 |
| 2 | state combined | figure2/imp_state_var_combined.pdf | 8.08 × 3.25 |
| 5 | B single trial | figure5/sine_5B_single_trial_*.pdf | 12.14 × 3.00 |
| 5 | C trial avg | figure5/sine_5C_trialavg_*.pdf | 12.14 × 3.25 |
| 5 | D avg input | figure5/sine_5D_trialavg_input_*.pdf | 12.14 × 2.96 |
| 5 | E RMSE(t) | figure5/sine_5E_rmse_time_*.pdf | 4.83 × 2.86 |
| 5 | F variance | figure5/sine_5F_variance_*.pdf | 5.01 × 3.07 |
| 5 | G RMSE violin | figure5/sine_5G_rmse_violin_*.pdf | 3.74 × 3.03 |
| 5 | H phase lag | figure5/sine_5H_phase_lag_*.pdf | 3.67 × 3.21 |
| 5 | I xsess RMSE | figure5/sine_combined_rmse.pdf | 5.04 × 2.96 |
| 5 | J xsess variance | figure5/sine_combined_variance.pdf | 5.04 × 2.93 |
| 5 | K xsess phase | figure5/sine_combined_phase.pdf | 5.33 × 2.96 |

Fig-2 rows (0.25 gaps): R1 = imp_response + imp_single + tf_cv_single + tf_cv_heldout = 15.42 ·
R2 = tf_model_swap + tf_tau_forest + state_combined = 16.09. Both inside 17.6.

Fig-5 rows (0.25 gaps): B / C / D each 12.14 on their own row · I+J+K = 15.91. **E+F+G+H
4-across = 18.00 — OVER 17.6 by 0.40 cm**; split the row or trim E/F to fit.

> **`imp_response.pdf` crops TALLER than its canvas** (3.67 vs the 3.40 requested), i.e. its
> content overhangs the `paperFig` canvas. Same failure mode as Fig-4 panel A. Harmless for
> legibility (nothing is clipped, that is the point of cropped export) but it breaks row
> alignment — budget the measured 3.67, not 3.40.

> **Cropping defeats height unification.** All nine Fig-3 panels were drawn on a 3.4 cm
> canvas, but their cropped heights span 2.29–3.28 cm: `exportgraphics('vector')` crops to
> each panel's own content, so a panel with fewer tick/axis labels ends up shorter. Setting
> a common `jnFig` height does NOT give a common import height. If rows must align, either
> pad the short panels in Illustrator or equalise the drawn content (same tick/label
> furniture), and always quote the measured bbox — never the nominal canvas.

Row layout: R1 = A+B+C ≈ 16.5; R2 = D 16.58; R3 = E+F+G ≈ 14.0 (all + 0.25 gaps).

## 7. The MATLAB system (`utils/jn*`)
- `S = jnStyle()` — all constants above.
- `w = jnPanelWidth(class, ncols[, gap])` — grid panel width in cm.
- `fig = jnFig(w, h)` — a figure exactly w×h cm, Arial, white, print-sized.
- `[fig,tl] = jnTiled(class, nrows, ncols[, rowH])` — tiled figure at a column width.
- `jnAxes(ax)` — apply the axis/font/line style to one axes (call after drawing).
- `jnExport(fig, 'path/panel.pdf')` — vector PDF + 300-dpi PNG.

New panels built with this system go to a **separate finalized folder**
(`paper/figures_v2/`) — the existing `figures_final/` set is left untouched until the
new look is approved.
