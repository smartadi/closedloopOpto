# figures_final — the locked paper panels (Illustrator pull-folder)

**This is the ONE folder. Pull every panel into Illustrator from `panels/<figure>/`.**
Not `paper/images/figureN/` — that is the producers' working dir, full of
superseded and exploratory panels. `paper/figures_v2/` is **retired** (2026-10-03, archived
to `paper/_retired/`; nothing writes there) and `paper/figures_v3/` is **deleted**; it was a second
folder claiming to be "the final one", which is exactly the ambiguity this consolidation
(user, 2026-10-02) removes.

Everything in `panels/` is in **JNeurosci house style** (`../FIGURE_RULEBOOK.md`): Arial,
tick labels 6 pt regular, axis labels and titles 7 pt bold, ticks out, box off, 0.5 pt axis
line. Panel letters are added in Illustrator, not by the scripts.

## The two halves of the workflow

| | what it does |
|---|---|
| `utils/paper_final_mirror.m` | **WRITES** `panels/<section>/`. Called from both `paperExport.m` and `jnExport.m`, so a panel lands whichever exporter its producer uses. Applies the jn typography pass on the way out. Writes a panel **only if its basename is listed in `MANIFEST.txt`** — a producer exports many exploratory views and we do not want them here. |
| `collect_final_panels.m` | **CHECKS** `panels/`. Names anything the manifest lists but is missing, and deletes anything present but unlisted. `collect_final_panels('dry')` reports without deleting. It does **not** copy from `images` any more — doing so would overwrite the jn panels with their non-jn originals. |

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

## Size contract (2026-10-02)

**Every panel line in `MANIFEST.txt` carries its measured import size** (`# W x H cm`), read
from the exported PDF's MediaBox. That is the size the panel lands at in Illustrator — it is
**not** the MATLAB canvas size, because `exportgraphics(...,'ContentType','vector')`
tight-crops the page to the content. Place at 100%; never scale a panel on the page, because
scaling silently breaks the rule-book type sizes.

The mirror enforces this: it measures each panel against its canvas and, if the content
overhangs, retries with the content pulled inside — keeping the retry **only if it actually
reduces the overflow**, so the fixer can never make a panel worse. Re-run the audit after
re-exporting anything, so the recorded sizes stay true.

Known exception: **`f4_state_exemplars.pdf` is 7.83 × 3.56 cm against a 7.50 × 3.30 canvas**
(+0.33/+0.26). The automatic fit cannot improve it; it needs a hand layout change in
`f4_state_exemplars.m`.

## Rebuild provenance

All 35 producer-made panels were regenerated from a cleared MATLAB state on 2026-10-02 and
**every one changed hash**, so anything dated before that rebuild is superseded.
`svd_frame_AL_0039_2025-04-19.pdf` is the one exception — it could not be rebuilt because
m10's cache is slim (no `d.svd`); force a server reload for that session to regenerate it.

## Assembled figures

The top-level `FigureN.pdf` / `FigureN.ai` are the Illustrator output. Re-copy after
re-assembling. Fig 2G and Fig 4A/C/D changed content on 2026-10-02 (state-window and
motion-statistic corrections) and need re-placing before the next compile.

_Last refreshed: 2026-10-02 (single-folder consolidation; panels written by paper_final_mirror)._
