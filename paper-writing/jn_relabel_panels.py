"""Swap words in panel PDFs without touching anything else in them (labels only, so no number can move).

Run once on 2026-11-03 for the JN figures; the producers were changed to print the same words, so a later
re-run of a producer does not need this. Kept as the record of what was patched, and for the other PC.

Each edit names the spans to remove, the new text and how to anchor it on the old extent. Originals are
copied to scratch first. Re-runnable: a panel with none of its old spans left is reported and skipped.
"""
import math
import shutil
from pathlib import Path

import fitz

ROOT = Path(r'C:/Users/aditya/Documents/projects/brain_paper/paper/figures_final/panels')
BAK = ROOT.parent / 'jn' / '_before_2026-11-03' / 'panels_before'   # originals; the panels themselves are git-ignored
FONT = {'Arial-BoldMT': r'C:/Windows/Fonts/arialbd.ttf', 'ArialMT': r'C:/Windows/Fonts/arial.ttf'}

ABS_TICK = (['abs ', '/'], 'abs 1-4Hz', 'right')
EDITS = {
    'figure4/f4_state_exemplars.pdf': [(['high abs ', '/'], 'high abs 1-4 Hz', 'center')],
    'figure4/f4_decomp_unique_sep.pdf': [ABS_TICK],
    'figure4/f4_row2_quartiles_nc.pdf': [(['Abs ', '/'], 'Abs 1-4 Hz', 'center'), (['RMSE to ref (z)'], 'RMSE to target (z)', 'center')],
    'figure4/f4_row2_quartiles.pdf': [(['Abs ', '/'], 'Abs 1-4 Hz', 'center'), (['RMSE to ref (z)'], 'RMSE to target (z)', 'center')],
    'supp_f4/supp_f4_unique_both.pdf': [ABS_TICK],
    'supp_f4/supp_f4_unique_abs.pdf': [ABS_TICK],
    'figure3/panel_A.pdf': [(['Ref'], 'Target', 'left')],
    'figure5/sine_5C_trialavg_AL_0048_2026-07-14_1.pdf': [(['Ref'], 'Target', 'left')],
}


def spans(page):
    out = []
    for b in page.get_text('dict')['blocks']:
        for ln in b.get('lines', []):
            for s in ln['spans']:
                out.append((s, ln['dir']))
    return out


for rel, edits in EDITS.items():
    src = ROOT / rel
    if not src.exists():
        print('MISSING', rel)
        continue
    bak = BAK / rel
    if not bak.exists():
        bak.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, bak)
    d = fitz.open(src)
    p = d[0]
    assert p.rotation == 0
    todo = []
    for old, new, anchor in edits:
        have = spans(p)
        hit = []
        for want in old:
            m = [x for x in have if x[0]['text'] == want]
            hit.append(m)
        if not all(hit):
            print('  skip', rel, old, '(not found)')
            continue
        # the Arial word plus the math glyph right after it; tick panels hold exactly one such pair
        ss = [m[0] for m in hit]
        assert all(len(m) == 1 for m in hit) or old[-1] != '/', (rel, old, [len(m) for m in hit])
        first, dr = ss[0]
        x0 = min(s['bbox'][0] for s, _ in ss)
        x1 = max(s['bbox'][2] for s, _ in ss)
        y0 = min(s['bbox'][1] for s, _ in ss)
        y1 = max(s['bbox'][3] for s, _ in ss)
        for s, _ in ss:
            r = fitz.Rect(s['bbox'])
            p.add_redact_annot(r, fill=False, cross_out=False)
        todo.append((first, dr, new, anchor, (x0, y0, x1, y1), ss))
    if not todo:
        continue
    p.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE, graphics=fitz.PDF_REDACT_LINE_ART_NONE, text=fitz.PDF_REDACT_TEXT_REMOVE)
    for first, dr, new, anchor, box, ss in todo:
        ffile = FONT[first['font']]
        f = fitz.Font(fontfile=ffile)
        size = first['size']
        c = first['color']
        col = ((c >> 16 & 255) / 255, (c >> 8 & 255) / 255, (c & 255) / 255)
        new_w = f.text_length(new, fontsize=size)
        ox, oy = first['origin']
        ex, ey = dr  # unit vector along the baseline, in page coordinates (y down)
        # old advance along the baseline, from the first origin to the end of the last span
        last = ss[-1][0]
        lf = f.text_length(last['text'], fontsize=size) if last['font'] in FONT else (last['bbox'][2] - last['bbox'][0]) / max(abs(ex), 1e-6) * 0.0 + size * 0.5
        old_end = (last['origin'][0] - ox) * ex + (last['origin'][1] - oy) * ey + lf
        shift = {'left': 0.0, 'center': (old_end - new_w) / 2, 'right': old_end - new_w}[anchor]
        pt = fitz.Point(ox + ex * shift, oy + ey * shift)
        ang = math.degrees(math.atan2(-ey, ex))  # counter-clockwise on the page
        kw = {}
        if abs(ang) > 0.01:
            kw['morph'] = (pt, fitz.Matrix(ang))
        fname = 'ab' if first['font'] == 'Arial-BoldMT' else 'ar'
        p.insert_text(pt, new, fontname=fname, fontfile=ffile, fontsize=size, color=col, **kw)
        print(f"  {rel}: {[s['text'] for s, _ in ss]} -> {new!r} at ({pt.x:.1f},{pt.y:.1f}) angle {ang:.0f} width {new_w:.1f} page {p.rect.width:.0f}x{p.rect.height:.0f}")
    tmp = src.with_suffix('.tmp.pdf')
    d.save(tmp, garbage=3, deflate=True)
    d.close()
    tmp.replace(src)
print('done')
