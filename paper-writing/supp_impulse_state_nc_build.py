"""Nature Comms supplementary figure: pre-stimulus state in the impulse experiments (Fig 2 supplement).

One figure for all Fig 2 supplementary material (Aditya, 2026-10-29: "we can put all figure 2 related
supplementary material into one single figure"; S1 spatial spread stays separate: "No, leave S1").

  a-c  relative vs absolute 2-4 Hz power   impulse-analysis/imp_relabs_exemplars.m
  d-f  variability by state quartile        impulse-analysis/imp_state_quartile_supp.m (rows: motion,
                                            relative, absolute; columns: RMS, stim/control, trial error)
  g-i  per-mouse raster strips              impulse-analysis/imp_state_raster_peramp.m

Panels are read from the working copies in paper/images/supplementary/ (relabs and the relabelled
quartile panels are not in figures_final yet). Every panel goes in at one scale, chosen so the page is
180 mm wide; the scale is printed, and text stays at or above 5 pt (panels are 6 pt at 1:1).
Output: paper/figures_final/nc/supp_impulse_state/S_impulse_state_nc_draft.{pdf,png}.
Run: python -I paper-writing/supp_impulse_state_nc_build.py
"""
import sys
from pathlib import Path

import fitz

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fig1_nc_build import MM, content_clip, place   # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RA = ROOT / 'paper' / 'images' / 'supplementary' / 'relabs'
SQ = ROOT / 'paper' / 'images' / 'supplementary' / 'state_quartile'
OUT = ROOT / 'paper' / 'figures_final' / 'nc' / 'supp_impulse_state'
W, LET, GAP = 180, 3.5, 1.5


def size(p):
    c = content_clip(fitz.open(p)[0])
    return c.width / MM, c.height / MM


def letter(page, x, y, s):
    page.insert_text(fitz.Point(x * MM, (y + 2.3) * MM), s, fontname='hebo', fontsize=8)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    top = [RA / 'relabs_scatter.pdf', RA / 'relabs_traces_Mouse1b.pdf', RA / 'relabs_spectra_Mouse1b.pdf']
    rows = [[SQ / f'sq_{s}_{k}.pdf' for k in ('rms', 'ratio', 'dist')] for s in ('mot', 'dpr', 'dpa')]
    strips = [SQ / f'sq_{s}_rmice.pdf' for s in ('mot', 'dpr', 'dpa')]

    wt = [size(p) for p in top]
    s1 = min(1.0, (W - 3 * LET - 2 * 3) / sum(w for w, _ in wt))
    wq = [[size(p) for p in r] for r in rows]
    ws = [size(p) for p in strips]
    need = max(sum(w for w, _ in r) for r in wq) + max(w for w, _ in ws)
    s2 = min(1.0, (W - 2 * LET - 2 * GAP - 3) / need)
    print(f'scale: top row {s1:.3f}, state rows {s2:.3f} (6 pt -> {6 * s1:.1f} / {6 * s2:.1f} pt)')

    # page height: top row, legend, three state rows, colour bars
    h1 = max(h for _, h in wt) * s1
    hl = size(SQ / 'sq_legend.pdf')[1] * s2
    hr = [max(max(h for _, h in r), hs) * s2 for r, (_, hs) in zip(wq, ws)]
    hc = max(size(SQ / 'sq_rmice_cbar_act.pdf')[1], size(SQ / 'sq_rmice_cbar_dev.pdf')[1]) * s2
    H = 1 + h1 + 3 + hl + 1 + sum(hr) + 2 * len(hr) + hc + 1
    doc = fitz.open()
    page = doc.new_page(width=W * MM, height=H * MM)

    # a-c
    gap = (W - 3 * LET - sum(w for w, _ in wt) * s1) / 2
    x = 0
    for L, p, (w, _) in zip('abc', top, wt):
        letter(page, x, 1, L)
        place(page, p, x + LET, 1, scale=s1)
        x += LET + w * s1 + gap

    # legend, then d-f (quartile summaries) and g-i (raster strips)
    y = 1 + h1 + 3
    place(page, SQ / 'sq_legend.pdf', LET, y, scale=s2)
    y += hl + 1
    xs = W - max(w for w, _ in ws) * s2                       # strips right-aligned
    for i, (r, wr, st, h) in enumerate(zip(rows, wq, strips, hr)):
        letter(page, 0, y, 'def'[i])
        x = LET
        for p, (w, _) in zip(r, wr):
            place(page, p, x, y, scale=s2)
            x += w * s2 + GAP
        letter(page, xs - LET, y, 'ghi'[i])
        place(page, st, xs, y, scale=s2)
        y += h + 2
    place(page, SQ / 'sq_rmice_cbar_act.pdf', xs, y, scale=s2)
    wd = size(SQ / 'sq_rmice_cbar_dev.pdf')[0] * s2
    place(page, SQ / 'sq_rmice_cbar_dev.pdf', W - wd, y, scale=s2)

    out = OUT / 'S_impulse_state_nc_draft.pdf'
    doc.save(out)
    page.get_pixmap(dpi=300).save(OUT / 'S_impulse_state_nc_draft.png')
    print(f'wrote {out.name} ({W} x {H:.1f} mm)')


if __name__ == '__main__':
    main()
