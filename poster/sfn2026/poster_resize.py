"""poster_resize.py -- the finished SfN poster at another width, same height (Aditya 2026-11-11: 48 x 36 in).

    python poster/sfn2026/poster_resize.py <poster.pptx> <out.pptx> <width_in> [g1 g2 g3]

Aditya: "make 48 by 36 versions. first check with sfn poster guidlines". SfN 2026 boards are 6 ft wide x 4 ft
high (sfn.org, Neuroscience 2026 > Poster Sessions), so 48 x 36 in landscape fits. Run on the finished poster
(after heading_fit.py). Words, type sizes and panels are the input's.
- Header: the purple band and its gold rule end at the new right margin. The lab logo and QR code move left
  with the right edge. Title, authors and affiliation are centred in the gap between the NSF logo and the
  lab logo (the slide centre would put the 23.75 in first title line against the lab logo).
- Body: each column narrows by its factor g (default: all three alike, so the columns, the gutters GUTTER
  and the margins fill the width). Inside a column every position and every picture scales by g about the
  column's top left, so panels keep their shape and their type shrinks by g. Text keeps its size: text boxes
  narrow by g and rewrap, heading bars keep their height, and the Introduction and Conclusions frames grow
  with their text. Text heights are measured in PowerPoint (TextRange.BoundHeight), not taken from the boxes.
- Each column's sections (Introduction; Results with box 1; box 2 / boxes 3-5 / boxes 6-8; Conclusions) are
  then stacked from BODY_TOP to BODY_BOT with equal gaps, as poster_clean.py does.
"""
import os
import sys
import tempfile

import win32com.client as w
from pptx import Presentation
from pptx.util import Emu, Inches

E = 914400
GUTTER = 1.2                      # in, between columns
BODY_TOP, BODY_BOT = 4.82, 35.32  # in
HEADS = ('Introduction bar', 'Results bar', 'Conclusions bar')
RIGHT = ('lab logo', 'Graphic 7')
TITLE = ('title', 'authors', 'affiliation')


def measure(path, names):
    """PowerPoint's own text heights (in) for the named shapes."""
    app = w.gencache.EnsureDispatch('PowerPoint.Application')
    pres = app.Presentations.Open(os.path.abspath(path), True, False, False)
    try:
        out = {}
        for sh in pres.Slides(1).Shapes:
            if sh.Name in names:
                tf = sh.TextFrame
                out[sh.Name] = (tf.TextRange.BoundHeight + tf.MarginTop + tf.MarginBottom) / 72
        return out
    finally:
        pres.Close()


def sections(sl):
    """[(column, [shapes])] top to bottom per column; a section starts at a heading bar."""
    by = {sh.name: sh for sh in sl.shapes}
    bars = [by[f'box {i} number'] for i in range(1, 9)]
    cols = sorted({(b.left, b.left + b.width) for b in bars})
    col = lambda sh: next(c for c, (a, b) in enumerate(cols) if a - E * 0.3 <= sh.left + sh.width / 2 <= b + E * 0.3)
    starts = [sh for sh in sl.shapes if sh.name in HEADS or (sh.name.endswith(' number') and sh.name != 'box 1 number')]
    out = []
    for c in range(3):
        st = sorted((s for s in starts if col(s) == c), key=lambda s: s.top)
        for i, s in enumerate(st):
            lo = s.top - E * 0.05
            hi = st[i + 1].top - E * 0.05 if i + 1 < len(st) else 10 ** 12
            mem = [sh for sh in sl.shapes if sh.top / E > 4.6 and col(sh) == c and lo <= sh.top < hi]
            out.append((c, s.name, mem))
    return cols, out


def fixed(sh):
    """Heading bars, heading text and gold rules: they keep their height."""
    return sh.name.endswith((' number', ' bar', ' heading', ' rule'))


def is_text(sh):
    return sh.has_text_frame and bool(sh.text_frame.text.strip()) and not fixed(sh)


def main(src, dst, width, g=None):
    prs = Presentation(src)
    sl = prs.slides[0]
    by = {sh.name: sh for sh in sl.shapes}
    dW = Inches(width) - prs.slide_width
    cols, secs = sections(sl)
    wid = [b - a for a, b in cols]
    m = by['header'].left
    room = Inches(width) - 2 * m - 2 * Inches(GUTTER)
    g = g or [room / sum(wid)] * 3
    assert abs(sum(gc * wc for gc, wc in zip(g, wid)) - room) < E * 0.02, 'column factors do not fill the width'
    left = [m]
    for gc, wc in zip(g[:2], wid[:2]):
        left.append(left[-1] + int(gc * wc) + Inches(GUTTER))

    # ---- header
    prs.slide_width = Inches(width)
    for n in ('header', 'header gold rule'):
        by[n].width = by[n].width + dW
    for n in RIGHT:
        by[n].left = by[n].left + dW
    x0 = by['NSF logo'].left + by['NSF logo'].width + Inches(0.3)
    x1 = by['lab logo'].left - Inches(0.3)
    for n in TITLE:
        by[n].left, by[n].width = x0, x1 - x0

    # ---- body: narrow each section about its column's top left. Bar rows (heading bars, their gold rules)
    # keep their height; the vertical space between them scales by g like the pictures.
    texts = [sh.name for c, head, mem in secs for sh in mem if is_text(sh)]
    frames = (('introduction frame', 'introduction'), ('conclusions frame', 'conclusions'))
    old = measure(src, set(texts))
    pad = {f: by[f].top + by[f].height - by[tx].top - Inches(old[tx]) for f, tx in frames}
    for c, head, mem in secs:
        gc, ox, oy = g[c], cols[c][0], min(sh.top for sh in mem)
        rows = []
        for a, b in sorted((sh.top - oy, sh.top + sh.height - oy) for sh in mem if fixed(sh)):
            if rows and a <= rows[-1][1]:
                rows[-1][1] = max(rows[-1][1], b)            # bar, heading and rule overlap: one row
            else:
                rows.append([a, b])

        def ymap(dy):
            keep = sum(max(0, min(b, dy) - a) for a, b in rows)
            return keep + (dy - keep) * gc

        for sh in mem:
            sh.left = Emu(int(left[c] + (sh.left - ox) * gc))
            sh.top = Emu(int(oy + ymap(sh.top - oy)))
            sh.width = Emu(int(sh.width * gc))
            if not fixed(sh):
                sh.height = Emu(int(sh.height * gc))

    # ---- text heights from PowerPoint, then frames round their text with their old bottom padding
    with tempfile.TemporaryDirectory() as tmp:
        t = os.path.join(tmp, 'a.pptx')
        prs.save(t)
        hgt = measure(t, set(texts))
    for n in texts:
        by[n].height = Inches(hgt[n])
        print(f'{n}: text {old[n]:.2f} -> {hgt[n]:.2f} in high')
    for f, tx in frames:
        by[f].height = Emu(int(by[tx].top + by[tx].height + pad[f] - by[f].top))

    # ---- stack each column's sections with equal gaps
    for c in range(3):
        cs = [(head, mem) for cc, head, mem in secs if cc == c]
        ext = [(min(sh.top for sh in mem), max(sh.top + sh.height for sh in mem)) for _, mem in cs]
        gap = (Inches(BODY_BOT - BODY_TOP) - sum(b - a for a, b in ext)) / (len(cs) - 1)
        y = Inches(BODY_TOP)
        for (head, mem), (a, b) in zip(cs, ext):
            for sh in mem:
                sh.top = Emu(int(y + sh.top - a))
            y += (b - a) + gap
        print(f'column {c + 1}: x {left[c] / E:.2f}-{(left[c] + g[c] * wid[c]) / E:.2f} in (x{g[c]:.3f}); '
              f'{", ".join(h for h, _ in cs)}; gap {gap / E:.2f} in')
    prs.save(dst)
    print(f'{dst}: {width} x {prs.slide_height / E:.0f} in')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    a = sys.argv[1:]
    main(a[0], a[1], float(a[2]), [float(v) for v in a[3:6]] if len(a) >= 6 else None)
