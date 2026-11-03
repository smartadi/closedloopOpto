"""Crop each JN Fig 2 panel PDF to its canvas (bottom-left corner of the export), then write a PNG preview.

MATLAB cannot be trusted to hold a small figure window on Windows, so fig2_jn_panels.m draws in a large
window with everything placed in cm from the bottom-left corner, and this keeps that corner.
Run: python -X utf8 -I impulse-analysis/fig2_jn_crop.py
"""
from pathlib import Path

import fitz

OUT = Path(__file__).resolve().parents[1] / 'paper' / 'figures_final' / 'jn' / 'fig2'
for n in 'ABCDEFG':
    pdf = OUT / f'{n}.pdf'
    w, h = (float(x) * 72 / 2.54 for x in (OUT / f'{n}.size').read_text().split())
    d = fitz.open(pdf)
    p = d[0]
    sizes = sorted({round(s['size'], 1) for b in p.get_text('dict')['blocks'] for ln in b.get('lines', []) for s in ln['spans']})
    print(n, 'type sizes', sizes)
    assert 4.1 <= min(sizes) and max(sizes) <= 7.01, f'{n}: type sizes {sizes}; re-run fig2_jn_panels'  # below 6 = superscripts only
    p.set_mediabox(fitz.Rect(0, 0, w, h))
    tmp = pdf.with_suffix('.tmp.pdf')
    d.save(tmp, garbage=3, deflate=True)
    d.close()
    tmp.replace(pdf)
    d = fitz.open(pdf)
    d[0].get_pixmap(matrix=fitz.Matrix(400 / 72, 400 / 72), alpha=False).save(OUT / f'{n}.png')
    print(n, round(d[0].rect.width / 72 * 2.54, 2), round(d[0].rect.height / 72 * 2.54, 2))
