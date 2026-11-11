"""poster_box2_48.py -- the 48 x 36 in poster: box 2's panels larger, so column 1 has no empty band.

    python poster/sfn2026/poster_box2_48.py factors <in.pptx>         writes panels/poster/box2_48/grow.json
    (MATLAB: global POSTER_BOX2 POSTER_BOX2_48; POSTER_BOX2 = true; POSTER_BOX2_48 = true; fig2_jn_panels)
    python poster/sfn2026/poster_box2_48.py build <in.pptx> <out.pptx>
    python poster/sfn2026/poster_box2_48.py refine <out.pptx>          then MATLAB and build again

Aditya (2026-11-11): "fix the column 1 gap in the 48 version". At 48 in poster_resize.py shrinks every column
by 0.897; column 1 is mostly pictures, so its two gaps came out 1.71 in against 0.90 / 0.84 in in columns 2 / 3.
Box 1's diagram already spans the column, so box 2 grows (method approved by Aditya 2026-11-11: "approve"):
- Top row (A, B: average response, suppression vs laser power) x k_t about the column's centre line c, from
  box 2's rule r0 down:  k_t = (x_R - i - c) / (x_1 - c), with x_R the column's right edge, i box 1's inset
  and x_1 the row's right edge (the row reaches the column edges less the inset).
- C (linear model vs held-out trials) x s_f, centred, under the top row:
  s_f = 1 + [A - C - 2G - (h_t + d)(k_t - 1)] / h_f, with A the body height, C column 1's content height,
  G = GAP (poster_ack.py, column 2's gap), h_t the rule-to-row-bottom height, d the space between the rows
  and h_f C's height. Then the column's three sections stack with equal gaps (= G).
- Type held: fig2_jn_panels.m (POSTER_BOX2_48) prints A-C again on a page s times larger, which scales
  positions only: type, lines, markers (and ticks, held in MATLAB) keep their size. (Scaling the type by 1/s
  instead was tried first: MATLAB's print rounds font sizes to 0.5 pt, so C's 5/1.31 = 3.81 pt came out 3.5.)
  'factors' writes k_t and s_f for it; 'build' checks each print (same type sizes, page s times larger),
  then places it at the old picture's scale, so its plot geometry maps exactly as the old picture's, scaled
  by s about the column centre (A, B) or C's own centre. The 54 in prints (box2/) are untouched.
"""
import json
import statistics
import sys
from pathlib import Path

import fitz
from pptx import Presentation
from pptx.util import Emu

from build_pptx import PX_ZOOM
from poster_ack import GAP
from poster_resize import BODY_BOT, BODY_TOP, sections
from poster_swap_all import ink

E = 914400
HERE = Path(__file__).resolve().parent
OLD = HERE / 'panels' / 'poster' / 'box2'
NEW = HERE / 'panels' / 'poster' / 'box2_48'
PANELS = {'imp_traces': 'A', 'imp_dose': 'B', 'imp_fit': 'C'}
TOP = ('imp_traces', 'imp_dose')


def geometry(sl):
    by = {sh.name: sh for sh in sl.shapes}
    cols, secs = sections(sl)
    cL, cR = cols[0]
    cx = (cL + cR) / 2
    r0 = by['box 2 rule'].top + by['box 2 rule'].height
    row = [by['panel ' + n] for n in TOP]
    fit = by['panel imp_fit']
    row_bot = max(p.top + p.height for p in row)
    x1 = max(p.left + p.width for p in row)
    inset = by['panel system'].left - cL
    k_t = (cR - inset - cx) / (x1 - cx)
    c1 = [mem for c, _, mem in secs if c == 0]
    content = sum(max(s.top + s.height for s in m) - min(s.top for s in m) for m in c1)
    h_t, d, h_f = row_bot - r0, fit.top - row_bot, fit.height
    A = (BODY_BOT - BODY_TOP) * E
    s_f = 1 + (A - content - 2 * GAP * E - (h_t + d) * (k_t - 1)) / h_f
    return dict(by=by, c1=c1, cx=cx, r0=r0, row_bot=row_bot, d=d, k_t=k_t, s_f=s_f)


def factors(src):
    g = geometry(Presentation(src).slides[0])
    k = {PANELS[n]: round(g['k_t'], 4) for n in TOP}
    k['C'] = round(g['s_f'], 4)
    k['h_f0'] = g['by']['panel imp_fit'].height / E                # C's height before (in), for 'refine'
    NEW.mkdir(exist_ok=True)
    (NEW / 'grow.json').write_text(json.dumps(k))
    print(f'k_t = {g["k_t"]:.4f}, s_f = {g["s_f"]:.4f} -> {NEW / "grow.json"}')


def refine(built):
    """C's type is held, so its picture grows less than s_f (its text doesn't scale) and the gaps come out
    above G. Its height is linear in s: H(s) = H(1) + b (s - 1), b from this build. Solve for the s that adds
    the missing 2 (gap - G) to the column, write it to grow.json; then print C again and rebuild."""
    sl = Presentation(built).slides[0]
    k = json.loads((NEW / 'grow.json').read_text())
    cols, secs = sections(sl)
    c1 = [mem for c, _, mem in secs if c == 0]
    content = sum(max(s.top + s.height for s in m) - min(s.top for s in m) for m in c1) / E
    gap = ((BODY_BOT - BODY_TOP) - content) / 2
    H1 = {s.name: s for s in sl.shapes}['panel imp_fit'].height / E
    b = (H1 - k['h_f0']) / (k['C'] - 1)
    s2 = k['C'] + 2 * (gap - GAP) / b
    print(f'gaps {gap:.3f} in; C height {k["h_f0"]:.2f} -> {H1:.2f} in at s {k["C"]:.4f} ({b:.3f} in per unit s) '
          f'-> s {s2:.4f}')
    k['C'] = round(s2, 4)
    (NEW / 'grow.json').write_text(json.dumps(k))


def type_size(page):
    return statistics.median(sp['size'] for b in page.get_text('dict')['blocks'] for ln in b.get('lines', [])
                             for sp in ln['spans'] if sp['text'].strip())


def build(src, dst):
    prs = Presentation(src)
    sl = prs.slides[0]
    g = geometry(sl)
    grow = json.loads((NEW / 'grow.json').read_text())
    assert abs(grow['A'] - g['k_t']) < 1e-3 and abs(grow['h_f0'] - g['by']['panel imp_fit'].height / E) < 1e-3, \
        'grow.json is not from this input'
    by, cx, r0 = g['by'], g['cx'], g['r0']
    (NEW / 'png').mkdir(exist_ok=True)
    row_bot_new = r0 + (g['row_bot'] - r0) * g['k_t']
    for n, L in PANELS.items():
        k = grow[L]
        old, new = fitz.open(str(OLD / f'{L}.pdf'))[0], fitz.open(str(NEW / f'{L}.pdf'))[0]
        ratio = type_size(new) / type_size(old)
        assert abs(ratio - 1) < 1e-6, f'{L}: type x{ratio:.4f}, expected unchanged'
        page = new.rect.width / old.rect.width
        assert abs(page / k - 1) < 0.005, f'{L}: page x{page:.4f}, expected x{k}'
        ro, rn = ink(old), ink(new)
        pic = by['panel ' + n]
        assert not any((pic.crop_left, pic.crop_right, pic.crop_top, pic.crop_bottom)), f'{n} is cropped'
        sc = pic.width / ro.width                                  # EMU per PDF pt, as placed now; kept
        assert abs(pic.height / ro.height / sc - 1) < 0.005, f'{n}: picture is not the old ink box'
        # a point p of the old page sits at pic.left + (p.x - ro.x0) sc; on the new page it is at k p.x. Map it
        # to the old position scaled by k about the column centre (A, B; rows from the rule) or C's own centre.
        if n in TOP:
            left = cx + (pic.left - ro.x0 * sc - cx) * k + rn.x0 * sc
            top = r0 + (pic.top - ro.y0 * sc - r0) * k + rn.y0 * sc
        else:
            c_old = pic.left + pic.width / 2
            left = cx + (pic.left - ro.x0 * sc - c_old) * k + rn.x0 * sc
            top = row_bot_new + g['d'] * g['k_t'] - ro.y0 * sc * k + rn.y0 * sc
        q = fitz.open()
        p = q.new_page(width=rn.width, height=rn.height)
        p.show_pdf_page(p.rect, fitz.open(str(NEW / f'{L}.pdf')), 0, clip=rn)
        png = NEW / 'png' / f'{n}.png'
        p.get_pixmap(matrix=fitz.Matrix(PX_ZOOM, PX_ZOOM), alpha=False).save(str(png))
        new_pic = sl.shapes.add_picture(str(png), Emu(int(left)), Emu(int(top)),
                                        Emu(int(rn.width * sc)), Emu(int(rn.height * sc)))
        new_pic.name = pic.name
        descr = pic._element.nvPicPr.cNvPr.get('descr')
        if descr:
            new_pic._element.nvPicPr.cNvPr.set('descr', descr)
        pic._element.addprevious(new_pic._element)                 # same place in the drawing order
        pic._element.getparent().remove(pic._element)
        print(f'{n}: plot x{k:.3f}, page x{page:.4f}, type x{ratio:.3f}; {new_pic.width / E:.2f} x {new_pic.height / E:.2f} in '
              f'at x {new_pic.left / E:.2f} in')

    # column 1: its three sections with equal gaps (members re-read: the pictures are new objects)
    cols, secs = sections(sl)
    c1 = [mem for c, _, mem in secs if c == 0]
    ext = [(min(s.top for s in m), max(s.top + s.height for s in m)) for m in c1]
    gap = ((BODY_BOT - BODY_TOP) * E - sum(b - a for a, b in ext)) / (len(c1) - 1)
    y = BODY_TOP * E
    for m, (a, b) in zip(c1, ext):
        for s in m:
            s.top = Emu(int(y + s.top - a))
        y += (b - a) + gap
    print(f'column 1: gaps {gap / E:.2f} in (target {GAP:.2f}), ends {(y - gap) / E:.2f} in')
    prs.save(dst)
    print(dst)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    a = sys.argv[1:]
    {'factors': lambda: factors(a[1]), 'refine': lambda: refine(a[1]), 'build': lambda: build(a[1], a[2])}[a[0]]()
