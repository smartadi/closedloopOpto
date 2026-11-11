"""Exit 0 if a printed JN Fig 2 panel kept its plot box; called by fig2_jn_panels.m after each print.

MATLAB's print of an invisible 12 x 6 cm figure sometimes squeezes the page vertically by 9% (cause not
found; a pause before printing does not help, and which panel it hits changes from run to run). Numbers and
type are untouched, but the boxes no longer line up across a row, so the panel is printed again.
Usage: fig2_jn_boxcheck.py <panel.pdf> <letter> [scale]
scale (default 1): the page is scale times larger than 12 x 6 cm (the 48 x 36 in poster's box 2, 2026-11-11),
so positions are scale times larger and the expected values with them.
"""
import sys

import fitz

pdf, letter = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
page = fitz.open(pdf)[0]
if letter == 'A':
    # A has no axis lines: use the Laser label, which is placed in data units
    hits = [ln['bbox'] for b in page.get_text('dict')['blocks'] for ln in b.get('lines', [])
            if 'Laser' in ''.join(s['text'] for s in ln['spans'])]
    value = page.rect.height - (hits[0][1] + hits[0][3]) / 2
    ok = value > 67.5 * scale
    print(f'A Laser label {value:.1f} pt above the page bottom')
else:
    value = max(g['rect'].height for g in page.get_drawings() if g['rect'].width < 1.5) / 72 * 2.54
    ok = abs(value - 1.90 * scale) < 0.06 * scale
    print(f'{letter} plot box {value:.2f} cm')
sys.exit(0 if ok else 1)
