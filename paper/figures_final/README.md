# figures_final — the locked paper panels (Illustrator pull-folder)

**This is the ONE folder. Pull every panel into Illustrator from `panels/<figure>/`.**
Not `paper/images/figureN/`, not `paper/figures_v2/` — those are working dirs full of
superseded and exploratory panels. `paper/figures_v3/` is **deleted**; it was a second
folder claiming to be "the final one", which is exactly the ambiguity this consolidation
(user, 2026-10-02) removes.

Everything in `panels/` is in **JNeurosci house style** (`../FIGURE_RULEBOOK.md`): Arial,
tick labels 6 pt regular, axis labels and titles 7 pt bold, ticks out, box off, 0.5 pt axis
line. Panel letters are added in Illustrator, not by the scripts.

## The two halves of the workflow

| | what it does |
|---|---|
| `utils/paper_final_mirror.m` | **WRITES** `panels/<section>/`. Called from both `paperExport.m` and `jnExport.m`, so a panel lands whichever exporter its producer uses. Applies the jn typography pass on the way out. Writes a panel **only if its basename is listed in `MANIFEST.txt`** — a producer exports many exploratory views and we do not want them here. |
| `collect_final_panels.m` | **CHECKS** `panels/`. Names anything the manifest lists but is missing, and deletes anything present but unlisted. `collect_final_panels('dry')` reports without deleting. It does **not** copy from `images`/`figures_v2` any more — doing so would overwrite the jn panels with their non-jn originals. |

### To rebuild panels

```matlab
global PAPER_FINAL; PAPER_FINAL = true;   % mirror ON
<run the producer script>                 % e.g. f4_row2_quartiles
collect_final_panels('dry')               % confirm the set is complete
```

Each mirrored file prints `[final+jn] panels\<section>\<name>.pdf`, and the session's
writes accumulate in the global `PAPER_FINAL_LOG`. If a panel is open in Illustrator or
Acrobat the write fails — the mirror **warns** (`paper_final_mirror:locked`) rather than
dying mid-figure, so close the file and re-run.

### To lock or retire a panel

- **Lock** → add its line under the right `[section]` in `MANIFEST.txt`, then re-run its
  producer with `PAPER_FINAL` on.
- **Retire** → delete its line, then run `collect_final_panels` to prune it.
- Keep `MANIFEST.txt` in sync with PAPER.md's "Paper panels in use" registry (same set).

`paper/` is gitignored, so the **tracked** record is `MANIFEST.txt` +
`collect_final_panels.m` + `utils/paper_final_mirror.m` + this README. The panel PDFs
themselves are local-only and are rebuilt from the producers.

## Current contents (verified 2026-10-02 — 38 present, 0 missing)

| section | panels | notes |
|---------|--------|-------|
| figure1 | 3 | hand-made / non-producer assets, copied in by hand — see `panels/figure1/README.txt`. `wfpath.pdf` is a full A4 page (21.01 × 29.70 cm) and needs cropping on import. |
| figure2 | 7 | A dose-response, B single session, C LTI fit, D timescales, E LTI validation, F model swap, G state-vs-prediction. Lettering locked 2026-09-30. |
| figure3 | 9 | |
| figure4 | 7 | A exemplars, B error-decomp model, C unique R², D state-quartile row (1×4 tiled), E contra→ipsi kernel, F A = G + L, G disturbance rejection. |
| figure5 | 10 | the assembled-figure letters do **not** match the filenames — read the path, not the letter. |
| supplementary | 2 | |

A 300-dpi PNG preview sits beside each PDF for quick eyeballing; `figure1/` has none
because those three are hand-made assets, not script output.

## Placement check (2026-10-02)

36 of 38 panels are drop-in replacements for what is already in the Illustrator files
(size change ≤ 0.11 cm). Two moved enough to need re-placing:
`all_variance_sessions` (+0.25 cm) and `f4_kernel_map` (+0.18 cm).

## Assembled figures

The top-level `FigureN.pdf` / `FigureN.ai` are the Illustrator output. Re-copy after
re-assembling. Fig 2G and Fig 4A/C/D changed content on 2026-10-02 (state-window and
motion-statistic corrections) and need re-placing before the next compile.

_Last refreshed: 2026-10-02 (single-folder consolidation; panels written by paper_final_mirror)._
