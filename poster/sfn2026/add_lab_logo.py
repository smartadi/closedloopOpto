"""add_lab_logo.py -- put the long gold Steinmetz Lab logo in the poster header, just left of the QR code.

    python poster/sfn2026/add_lab_logo.py <poster.pptx> <out.pptx> [height_in]

Source (read only): \\\\sahale.biostr.washington.edu\\data\\labLogo\\steinmetz-lab-logo-5-black-gold-horizontal-long.pdf
(Aditya, 2026-11-05: "the long gold logo ... next to the qr code"). That file draws the gold line art on a
black rectangle; the rectangle is dropped so the gold sits on the header purple, and nothing else is changed.
Rendered to a transparent PNG at 600 dpi at its placed size (panels/lab_logo.png, git-ignored).
Placed centred on the QR code's height, `GAP` in left of it. Re-runnable: replaces an existing 'lab logo'.
Every other shape keeps its XML; main() asserts that, and that the logo clears the header text.
"""
import copy
import sys
from pathlib import Path

import fitz
from lxml import etree
from pptx import Presentation
from pptx.util import Inches

SRC = r'\\sahale.biostr.washington.edu\data\labLogo\steinmetz-lab-logo-5-black-gold-horizontal-long.pdf'
PNG = Path(__file__).resolve().parent / 'panels' / 'lab_logo.png'
QR = 'Graphic 7'                 # Aditya's QR code, top right of the header
GAP = 0.35                       # in, logo to QR code
TEXT_RIGHT = 39.16               # in, right end of the title's first line (PowerPoint, 2026-11-05)
ALT = 'Steinmetz Lab, University of Washington'
BG = b'0 0 713.129 234.539 re f\n'


def render(h_in):
    d = fitz.open(SRC)
    p = d[0]
    x = p.get_contents()[0]
    s = d.xref_stream(x)
    assert s.count(BG) == 1, 'logo background not where expected'
    d.update_stream(x, s.replace(BG, b''))
    art = fitz.Rect()
    for g in p.get_drawings():
        art |= g['rect']
    art = (art + (-2, -2, 2, 2)) & p.rect
    zoom = h_in * 600 / art.height
    p.get_pixmap(matrix=fitz.Matrix(zoom, zoom), clip=art, alpha=True).save(str(PNG))
    return h_in * art.width / art.height


def main(src, out, h_in=1.7):
    h_in = float(h_in)
    prs = Presentation(src)
    sl = prs.slides[0]
    old = [sh for sh in sl.shapes if sh.name == 'lab logo']
    for sh in old:
        rid = sh._element.blip_rId
        sh._element.getparent().remove(sh._element)
        sl.part.drop_rel(rid)
    before = {sh.shape_id: copy.deepcopy(sh._element) for sh in sl.shapes}
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)
    S = {sh.name: sh for sh in sl.shapes}
    E = 914400
    qr, hd = S[QR], S['header']
    w_in = render(h_in)
    x = qr.left / E - GAP - w_in
    y = (qr.top + qr.height / 2) / E - h_in / 2
    assert x >= TEXT_RIGHT + 1.0, f'logo would crowd the title: starts at {x:.2f} in'
    assert hd.top / E <= y and y + h_in <= S['header gold rule'].top / E, 'logo leaves the header'
    pic = sl.shapes.add_picture(str(PNG), Inches(x), Inches(y), Inches(w_in), Inches(h_in))
    pic.name = 'lab logo'
    pic._element.nvPicPr.cNvPr.set('descr', ALT)
    print(f'lab logo: {w_in:.2f} x {h_in:.2f} in at x {x:.2f} y {y:.2f}; {x - TEXT_RIGHT:.2f} in clear of the title')
    now = {sh.shape_id: sh for sh in sl.shapes}
    for sid, el in before.items():
        assert c14n(now[sid]._element) == c14n(el), now[sid].name
    assert len(now) == len(before) + 1
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(*sys.argv[1:])
