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
