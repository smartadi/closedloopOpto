"""poster_textcheck.py -- exit 1 if a printed panel spells any of the given strings with a gap in it.

    python poster/sfn2026/poster_textcheck.py <panel.pdf> <strings.txt>

MATLAB's print -vector sometimes places one glyph of a word too far right, so "power" prints as "pow er"
(seen in box 2's titles, 2026-11-10; which word, and whether at all, changes from print to print). The
strings file holds one expected text per line; each must appear as written in the PDF's text. The caller
prints again when this fails, as it does for the plot-box check.
"""
import sys

import fitz

pdf, lst = sys.argv[1], sys.argv[2]
want = [s for s in open(lst, encoding='utf-8').read().splitlines() if s.strip()]
page = fitz.open(pdf)[0]
lines = [''.join(c['c'] for s in ln['spans'] for c in s['chars'])
         for b in page.get_text('rawdict')['blocks'] for ln in b.get('lines', [])]
bad = [w for w in want if not any(w in ln for ln in lines)]
for w in bad:
    print(f'not found as written: {w!r}')
sys.exit(1 if bad else 0)
