"""panel_swap.py -- replace one panel picture in the poster with a new MATLAB print, in the same spot.

    python poster/sfn2026/panel_swap.py <poster.pptx> <out.pptx> <shape name> <raw.pdf> <name> [alt text]

Crops <raw.pdf> to its ink, writes panels/<name>.pdf and panels/png/<name>.png at the poster's one print scale,
and puts the new picture where the old one was, centred on the old centre. Re-runnable. It refuses if the new
panel is taller than the old or leaves its box frame, and asserts every other shape keeps its XML.
First use, 2026-11-05: box 6's unique R^2 panel -> unique_panel.m (broken y-axis).
"""
import copy
import sys
from pathlib import Path

import fitz
from lxml import etree
from pptx import Presentation
from pptx.util import Inches

from build_panels import ink
from build_pptx import PS, PX_ZOOM

PAN = Path(__file__).resolve().parent / 'panels'


def render(raw, name):
    d = fitz.open(str(raw))
    r = ink(d[0])
    n = fitz.open()
    q = n.new_page(width=r.width, height=r.height)
    q.show_pdf_page(q.rect, d, 0, clip=r)
    n.save(str(PAN / f'{name}.pdf'), garbage=3, deflate=True)
    n[0].get_pixmap(matrix=fitz.Matrix(PX_ZOOM, PX_ZOOM), alpha=False).save(str(PAN / 'png' / f'{name}.png'))
    return r.width / 72 * PS, r.height / 72 * PS


def main(src, out, shape, raw, name, alt=None):
    prs = Presentation(src)
    sl = prs.slides[0]
    S = {sh.name: sh for sh in sl.shapes}
    before = {sh.shape_id: copy.deepcopy(sh._element) for sh in sl.shapes}
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)
    E = 914400
    old = S[shape]
    cx, cy = (old.left + old.width / 2) / E, (old.top + old.height / 2) / E
    frame = next(sh for n, sh in S.items() if n.endswith(' frame') and n.startswith('box ')
                 and sh.left <= old.left and sh.top <= old.top
                 and old.left + old.width <= sh.left + sh.width and old.top + old.height <= sh.top + sh.height)
    pw, ph = render(raw, name)
    x, y = cx - pw / 2, cy - ph / 2
    assert ph <= old.height / E + 0.01, f'new panel taller: {ph:.2f} vs {old.height / E:.2f} in'
    fx, fy, fw, fh = (v / E for v in (frame.left, frame.top, frame.width, frame.height))
    assert fx + 0.1 <= x and x + pw <= fx + fw - 0.1 and fy <= y and y + ph <= fy + fh, 'new panel leaves its box'

    pic = sl.shapes.add_picture(str(PAN / 'png' / f'{name}.png'), Inches(x), Inches(y), Inches(pw), Inches(ph))
    pic.name = shape
    pic._element.nvPicPr.cNvPr.set('descr', alt or old._element.nvPicPr.cNvPr.get('descr', ''))
    old._element.addprevious(pic._element)
    rid = old._element.blip_rId
    old._element.getparent().remove(old._element)
    sl.part.drop_rel(rid)
    print(f'{shape}: {old.width / E:.2f} x {old.height / E:.2f} -> {pw:.2f} x {ph:.2f} in, at x {x:.2f} y {y:.2f} '
          f'(in {frame.name})')

    now = {sh.shape_id: sh for sh in sl.shapes}
    assert old.shape_id not in now and len(now) == len(before)
    for sid, el in before.items():
        if sid != old.shape_id:
            assert c14n(now[sid]._element) == c14n(el), now[sid].name
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(*sys.argv[1:])
