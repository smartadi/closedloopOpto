"""box5_refresh.py -- set box 5's heading, bullet and panel in the poster, in place of whatever box 5 holds now.

    python poster/sfn2026/box5_refresh.py <poster.pptx> <out.pptx>

Re-runnable on the current poster: it touches only box 5's number, heading, rule, panel and bullet, keeps the
frame where it is (column 2, from under box 4 to the column bottom since the Methods box went, 2026-11-05),
and asserts that every other shape keeps its XML. Run seedfc_panel.m first; this crops its print.
2026-11-05 (Aditya: "coupling lost" is unintuitive): heading and bullet now say what happens and why.
The wording keeps to "the site stops following cortex"; removing the laser's own signal restores the
correlation, so the inputs are not cut off and the text must not say so.
"""
import copy
import sys

from lxml import etree
from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Inches

from patch_online_v2 import PAN, bullets_h, inches, place, render_seedfc, set_bullets, set_one_line

HEAD = ('Feedback cancels shared fluctuations:', 'the site stops following the rest of cortex')
BULLETS = ['Open-loop stimulation is the same on every trial, so it can’t cancel them.']
ALT = ('Maps of the change in each cortical point’s correlation with the controlled site, during stimulation vs '
       'before, in each of 12 sessions and their mean, open and closed loop; correlation with the site before and '
       'during stimulation per session; and the per-session change, open vs closed loop')


def set_two_lines(sh, a, b):
    """Heading on two lines with a manual break, as Aditya's headings in boxes 3 and 8."""
    set_one_line(sh, a)
    p = sh._element.txBody.findall(qn('a:p'))[0]
    r1 = p.find(qn('a:r'))
    br = p.makeelement(qn('a:br'), {})
    rp = r1.find(qn('a:rPr'))
    if rp is not None:
        br.append(copy.deepcopy(rp))
    r2 = copy.deepcopy(r1)
    r2.find(qn('a:t')).text = b
    r1.addnext(br)
    br.addnext(r2)


def main(src, out):
    prs = Presentation(src)
    sl = prs.slides[0]
    S = {sh.name: sh for sh in sl.shapes}
    before = {sh.shape_id: copy.deepcopy(sh._element) for sh in sl.shapes}
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)

    f5, n5, t5, r5, old, b5 = (S[k] for k in ('box 5 frame', 'box 5 number', 'box 5 heading', 'box 5 rule',
                                              'panel seedfc', 'box 5 bullets'))
    f4, n4, t4, r4 = S['box 4 frame'], S['box 4 number'], S['box 4 heading'], S['box 4 rule']
    X2, W2, y5, h5 = inches(f5.left), inches(f5.width), inches(f5.top), inches(f5.height)

    # two-line heading: the badge, heading and rule take box 4's geometry, which has a two-line heading too
    set_two_lines(t5, *HEAD)
    place(n5, h=inches(n4.height))
    place(t5, h=inches(t4.height))
    rule5 = inches(r4.top) - inches(f4.top)
    place(r5, y=y5 + rule5)

    pw, ph = render_seedfc()
    ps = b5._element.txBody.findall(qn('a:p'))
    ppr, rpr = ps[0].find(qn('a:pPr')), ps[0].find(qn('a:r')).find(qn('a:rPr'))
    set_bullets(b5, BULLETS, copy.deepcopy(ppr), copy.deepcopy(ppr), copy.deepcopy(rpr))
    b_h = bullets_h(BULLETS, inches(b5.width))
    spare = h5 - rule5 - ph - b_h
    assert spare >= 0.4, f'box 5 does not fit: spare {spare:.2f} in'
    assert pw <= W2 - 0.3, f'panel too wide: {pw:.2f} in'
    py = y5 + rule5 + spare * 0.3

    pic = sl.shapes.add_picture(str(PAN / 'png' / 'seedfc.png'), Inches(X2 + (W2 - pw) / 2), Inches(py), Inches(pw), Inches(ph))
    pic.name = 'panel seedfc'
    pic._element.nvPicPr.cNvPr.set('descr', ALT)
    old._element.addprevious(pic._element)
    rid = old._element.blip_rId
    old._element.getparent().remove(old._element)
    sl.part.drop_rel(rid)
    place(b5, y=py + ph + spare * 0.3, h=b_h)
    print(f'box 5: y {y5:.2f} h {h5:.2f} in; panel {pw:.2f} x {ph:.2f} in; bullets {b_h:.2f} in; spare {spare:.2f} in')

    # nothing else moved or changed
    mine = {f5.shape_id, n5.shape_id, t5.shape_id, r5.shape_id, b5.shape_id}
    now = {sh.shape_id: sh for sh in sl.shapes}
    assert old.shape_id not in now and len(now) == len(before)
    assert c14n(now[f5.shape_id]._element) == c14n(before[f5.shape_id]), 'box 5 frame moved'
    for sid, el in before.items():
        if sid in mine or sid == old.shape_id:
            continue
        assert c14n(now[sid]._element) == c14n(el), now[sid].name
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
