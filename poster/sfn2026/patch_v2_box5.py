"""patch_v2_box5.py -- remove the Methods box and let box 5 (site decouples from cortex) fill column 2.

    python poster/sfn2026/patch_v2_box5.py <poster.pptx> <out.pptx>

Aditya, 2026-11-05: "i dont think we need the methods block just expand number 5".
Run seedfc_panel.m first: it prints the taller panel (per-session strip on top; mean maps and the two
per-session summaries below) to panels/seedfc_raw.pdf. This script deletes the Methods frame and text, stretches
box 5's frame to the bottom of the column, swaps in the new panel and moves the bullet under it.
Every other shape keeps its XML; main() asserts that.
"""
import copy
import sys
from pathlib import Path

from lxml import etree
from pptx import Presentation
from pptx.util import Inches

from patch_online_v2 import BOX5, PAN, bullets_h, inches, place, render_seedfc

ALT = ('Maps of coupling lost with the controlled site in each of 12 sessions and their mean, open and closed loop, '
       'with r with the site at baseline and during stimulation, and the per-session change, open vs closed loop')


def main(src, out):
    prs = Presentation(src)
    sl = prs.slides[0]
    S = {sh.name: sh for sh in sl.shapes}
    before = {sh.shape_id: copy.deepcopy(sh._element) for sh in sl.shapes}
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)

    f5, m, mt, old, b5 = S['box 5 frame'], S['methods frame'], S['methods'], S['panel seedfc'], S['box 5 bullets']
    X2, W2 = inches(f5.left), inches(f5.width)
    y5 = inches(f5.top)
    bottom = inches(m.top + m.height)                       # the column's bottom edge, level with box 2
    h5 = bottom - y5
    rule5 = inches(S['box 5 rule'].top) - y5
    pw, ph = render_seedfc()
    b_h = bullets_h(BOX5, inches(b5.width))
    spare = h5 - rule5 - ph - b_h
    assert spare >= 0.4, f'box 5 does not fit: spare {spare:.2f} in'
    assert pw <= W2 - 0.3, f'panel too wide: {pw:.2f} in'
    py = y5 + rule5 + spare * 0.3

    # Methods out
    for sh in (m, mt):
        sh._element.getparent().remove(sh._element)

    # new panel in the old one's place in the shape tree; the old picture's image goes with it
    pic = sl.shapes.add_picture(str(PAN / 'png' / 'seedfc.png'), Inches(X2 + (W2 - pw) / 2), Inches(py), Inches(pw), Inches(ph))
    pic.name = 'panel seedfc'
    pic._element.nvPicPr.cNvPr.set('descr', ALT)
    old._element.addprevious(pic._element)
    rid = old._element.blip_rId
    old._element.getparent().remove(old._element)
    sl.part.drop_rel(rid)

    old_h = inches(f5.height)
    place(f5, h=h5)
    place(b5, y=py + ph + spare * 0.3)
    print(f'box 5: y {y5:.2f} h {h5:.2f} in (was {old_h:.2f}); panel {pw:.2f} x {ph:.2f} in; spare {spare:.2f} in')

    # nothing else moved or changed
    gone = {m.shape_id, mt.shape_id, old.shape_id}
    now = {sh.shape_id: sh for sh in sl.shapes}
    assert not gone & set(now), 'a removed shape is still on the slide'
    for sid, el in before.items():
        if sid in gone or sid in (f5.shape_id, b5.shape_id):
            continue
        assert c14n(now[sid]._element) == c14n(el), now[sid].name
    assert len(now) == len(before) - 2
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
