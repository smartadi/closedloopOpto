"""patch_online_v2.py -- second round of poster edits, applied to Aditya's hand-edited PowerPoint.

    python poster/sfn2026/patch_online_v2.py <edited.pptx> <out.pptx>

The file edited in PowerPoint online is the master, so this opens that file and changes only:
  - a new box 5 under the moving-target box: the site decouples from cortex (seedfc_panel.m);
  - old box 5 split in two: new box 6 (what explains the error) and box 7 (error across each state);
  - old box 6 renumbered 8; all column 3 text shortened in the style of Aditya's boxes 1-4.
Every other shape keeps its XML; main() asserts that. build_pptx.py is not used: it would overwrite the hand edits.
"""
import copy
import re
import sys
from pathlib import Path

import fitz
from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches

from build_panels import ink
from build_pptx import BODY, BULLET_IN, ITEM_GAP, PS, PX_ZOOM, text_h

HERE = Path(__file__).resolve().parent
PAN = HERE / 'panels'
PAD_BOTTOM = 0.2                # below the last bullet in a box
AFTER_PANEL = 0.19              # panels to bullets, as in the build
NB = ' '

# ---- the new words, in the style of boxes 1-4: what happened, no statistics (the panels carry the stars)
BOX5_HEAD = 'Feedback decouples the site from the rest of cortex'
BOX5 = ['Noise correlation with the site falls in closed loop only (12 sessions, 2 mice).']
BOX6_HEAD = f'State-dependent limits: initial deviation and 1–4{NB}Hz power explain{NB}part{NB}of{NB}the{NB}error'
BOX6 = ['Initial deviation explains much of the variation in transient error, almost none in the steady state.',
        f'Absolute 1–4{NB}Hz power explains a modest part, the most of any variable in the steady state.']
BOX7_HEAD = f'Feedback removes more error during movement, but{NB}error{NB}grows{NB}with{NB}1–4{NB}Hz{NB}power'
BOX7 = ['**Movement:** open-loop error rises and closed-loop error stays flat, so feedback removes a larger '
        'fraction of the error.',
        f'**Absolute 1–4{NB}Hz power:** closed-loop error rises by about as much as open-loop error.',
        'One explanation: opsin and indicator kinetics and loop delay limit the controllable frequencies.']
BOX8 = ['A linear model fit on laser-off frames predicts the site from the contralateral hemisphere.',
        'Closed loop rejects part of this disturbance: most of the constant offset, less of the fluctuations.']
ALT = 'Maps of coupling lost with the controlled site in 12 sessions, open and closed loop, and the per-session summary'


def inches(emu):
    return emu / 914400


def place(sh, x=None, y=None, w=None, h=None):
    if x is not None:
        sh.left = Inches(x)
    if y is not None:
        sh.top = Inches(y)
    if w is not None:
        sh.width = Inches(w)
    if h is not None:
        sh.height = Inches(h)


def set_one_line(sh, text):
    """Replace the text of a heading or a badge, keeping its first run's formatting."""
    p = sh._element.txBody.findall(qn('a:p'))[0]
    keep = p.find(qn('a:r'))
    for el in list(p):
        if el.tag in (qn('a:r'), qn('a:br'), qn('a:endParaRPr')) and el is not keep:
            p.remove(el)
    keep.find(qn('a:t')).text = text


def set_bullets(sh, items, first_ppr, next_ppr, rpr):
    body = sh._element.txBody
    for p in body.findall(qn('a:p')):
        body.remove(p)
    ns_a = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    for k, item in enumerate(items):
        p = body.makeelement(qn('a:p'), nsmap={'a': ns_a})
        p.append(copy.deepcopy(first_ppr if k == 0 else next_ppr))
        for i, chunk in enumerate(re.split(r'\*\*', item)):
            if not chunk:
                continue
            r = p.makeelement(qn('a:r'), {})
            rp = copy.deepcopy(rpr)
            rp.set('b', '1' if i % 2 else '0')
            r.append(rp)
            t = r.makeelement(qn('a:t'), {})
            t.text = chunk
            r.append(t)
            p.append(r)
        body.append(p)


def bullets_h(items, w):
    return text_h(items, BODY, w - BULLET_IN / 72, gap=ITEM_GAP)


def render_seedfc():
    """Crop the MATLAB print to its ink and render it like every other panel. Returns its size on the poster."""
    d = fitz.open(str(PAN / 'seedfc_raw.pdf'))
    r = ink(d[0])
    n = fitz.open()
    q = n.new_page(width=r.width, height=r.height)
    q.show_pdf_page(q.rect, d, 0, clip=r)
    n.save(str(PAN / 'seedfc.pdf'), garbage=3, deflate=True)
    n[0].get_pixmap(matrix=fitz.Matrix(PX_ZOOM, PX_ZOOM), alpha=False).save(str(PAN / 'png' / 'seedfc.png'))
    return r.width / 72 * PS, r.height / 72 * PS


def main(src, out):
    prs = Presentation(src)
    sl = prs.slides[0]
    tree = sl.shapes._spTree
    S = {sh.name: sh for sh in sl.shapes}
    before = {sh.shape_id: copy.deepcopy(sh._element) for sh in sl.shapes}
    next_id = [max(before) + 1]

    def clone(sh, name, at):
        """Copy a shape under a new name and id, into the shape tree just before `at`."""
        el = copy.deepcopy(sh._element)
        cnv = el.xpath('.//p:cNvPr')[0]
        cnv.set('id', str(next_id[0]))
        cnv.set('name', name)
        next_id[0] += 1
        at._element.addprevious(el)
        return next(s for s in sl.shapes if s.shape_id == next_id[0] - 1)

    # paragraph and run formats, from the bullets as they stand in the edited file
    ps = S['box 5 bullets']._element.txBody.findall(qn('a:p'))
    first_ppr, next_ppr = ps[0].find(qn('a:pPr')), ps[1].find(qn('a:pPr'))
    rpr = ps[0].find(qn('a:r')).find(qn('a:rPr'))
    fmt = (copy.deepcopy(first_ppr), copy.deepcopy(next_ppr), copy.deepcopy(rpr))

    # ---- column 3
    X3, W3 = inches(S['box 5 frame'].left), inches(S['box 5 frame'].width)
    TX3, TW3 = inches(S['box 5 bullets'].left), inches(S['box 5 bullets'].width)
    top3 = inches(S['box 5 frame'].top)
    end3 = inches(S['Conclusions bar outline'].top)
    # (panels' bottom relative to the box top) + gap + bullets + pad
    q = S['panel st_quart']
    d = S['panel d_agl']
    rel_6 = inches(S['panel st_trials'].top + S['panel st_trials'].height) - top3
    rel_7 = inches(S['box 5 rule'].top) - top3 + 0.24 + inches(q.height)
    b8 = inches(S['box 6 frame'].top)
    rel_8 = inches(d.top + d.height) - b8
    h6 = rel_6 + AFTER_PANEL + bullets_h(BOX6, TW3) + PAD_BOTTOM
    h7 = rel_7 + AFTER_PANEL + bullets_h(BOX7, TW3) + PAD_BOTTOM
    h8 = rel_8 + AFTER_PANEL + bullets_h(BOX8, TW3) + PAD_BOTTOM
    gap = (end3 - top3 - h6 - h7 - h8) / 3
    assert gap >= 0.2, f'column 3 does not fit: gap {gap:.2f} in'
    y7, y8 = top3 + h6 + gap, top3 + h6 + gap + h7 + gap
    print(f'column 3: box heights {h6:.2f} {h7:.2f} {h8:.2f}, gap {gap:.2f} in')

    # old box 6 -> 8: same panels and heading, moved up or down as one
    dy = y8 - b8
    for n in ('frame', 'number', 'heading', 'rule', 'bullets'):
        sh = S[f'box 6 {n}']
        sh.top = Emu(sh.top + Inches(dy))
        sh.name = f'box 8 {n}'
    for n in ('panel d_kernel', 'panel d_agl', 'panel d_rr'):
        S[n].top = Emu(S[n].top + Inches(dy))
    place(S['box 6 frame'], h=h8)
    set_one_line(S['box 6 number'], '8')
    set_bullets(S['box 6 bullets'], BOX8, *fmt)
    place(S['box 6 bullets'], y=y8 + rel_8 + AFTER_PANEL, h=bullets_h(BOX8, TW3))

    # box 7: a copy of old box 5's frame, badge, heading, rule and bullets, around the quartile panel
    f7 = clone(S['box 5 frame'], 'box 7 frame', q)
    n7 = clone(S['box 5 number'], 'box 7 number', q)
    t7 = clone(S['box 5 heading'], 'box 7 heading', q)
    r7 = clone(S['box 5 rule'], 'box 7 rule', q)
    b7 = clone(S['box 5 bullets'], 'box 7 bullets', q)
    q._element.addnext(b7._element)
    f7._element.addprevious(S['box 5 bullets']._element)      # keeps the reading order box by box
    rule_rel = inches(S['box 5 rule'].top) - top3
    place(f7, y=y7, h=h7)
    place(n7, y=y7)
    place(t7, y=y7)
    place(r7, y=y7 + rule_rel)
    place(q, y=y7 + rule_rel + 0.24)
    set_one_line(n7, '7')
    set_one_line(t7, BOX7_HEAD)
    set_bullets(b7, BOX7, *fmt)
    place(b7, y=y7 + rel_7 + AFTER_PANEL, h=bullets_h(BOX7, TW3))

    # old box 5 -> 6: keeps the example trials and the unique R2 panel
    for n in ('frame', 'number', 'heading', 'rule', 'bullets'):
        S[f'box 5 {n}'].name = f'box 6 {n}'
    place(S['box 5 frame'], h=h6)
    set_one_line(S['box 5 number'], '6')
    set_one_line(S['box 5 heading'], BOX6_HEAD)
    set_bullets(S['box 5 bullets'], BOX6, *fmt)
    place(S['box 5 bullets'], y=top3 + rel_6 + AFTER_PANEL, h=bullets_h(BOX6, TW3))

    # ---- box 5, under the moving-target box, in the height down to the Methods box, same gap as column 2
    f4, m = S['box 4 frame'], S['methods frame']
    X2, W2 = inches(f4.left), inches(f4.width)
    col_gap = inches(f4.top) - inches(S['box 3 frame'].top + S['box 3 frame'].height)
    y5 = inches(f4.top + f4.height) + col_gap
    h5 = inches(m.top) - col_gap - y5
    pw, ph = render_seedfc()
    rule5 = inches(S['box 1 rule'].top) - inches(S['box 1 frame'].top)
    f5 = clone(S['box 4 frame'], 'box 5 frame', m)
    n5 = clone(S['box 1 number'], 'box 5 number', m)
    t5 = clone(S['box 1 heading'], 'box 5 heading', m)
    r5 = clone(S['box 1 rule'], 'box 5 rule', m)
    place(f5, y=y5, h=h5)
    place(n5, x=X2, y=y5)
    place(t5, x=inches(S['box 4 heading'].left), y=y5)
    place(r5, x=X2, y=y5 + rule5)
    set_one_line(n5, '5')
    set_one_line(t5, BOX5_HEAD)
    b_h = bullets_h(BOX5, inches(m.width) - 0.4)
    spare = h5 - rule5 - ph - b_h
    py = y5 + rule5 + spare * 0.3
    pic = sl.shapes.add_picture(str(PAN / 'png' / 'seedfc.png'), Inches(X2 + (W2 - pw) / 2), Inches(py), Inches(pw), Inches(ph))
    pic.name = 'panel seedfc'
    pic._element.nvPicPr.cNvPr.set('descr', ALT)
    m._element.addprevious(pic._element)
    next_id[0] = pic.shape_id + 1
    # the Methods box's text box is the padded width of this column; the copy keeps box 6's bullet format
    b5 = clone(S['box 5 bullets'], 'box 5 bullets', m)
    set_bullets(b5, BOX5, *fmt)
    place(b5, x=inches(S['methods'].left), y=py + ph + spare * 0.3, w=inches(S['methods'].width), h=b_h)
    print(f'box 5: y {y5:.2f} h {h5:.2f} in; panel {pw:.2f} x {ph:.2f} in; spare height {spare:.2f} in; bullet lines height {b_h:.2f} in')

    # ---- nothing else moved or changed
    from lxml import etree
    touched = {f'box {n} {p}' for n in (6, 8) for p in ('frame', 'number', 'heading', 'rule', 'bullets')} | {
        'panel d_kernel', 'panel d_agl', 'panel d_rr', 'panel st_quart'}
    for sh in sl.shapes:
        if sh.shape_id in before and sh.name not in touched:
            a = etree.tostring(sh._element, method='c14n', exclusive=True)
            assert a == etree.tostring(before[sh.shape_id], method='c14n', exclusive=True), sh.name
    ids = [sh.shape_id for sh in sl.shapes]
    assert len(ids) == len(set(ids))
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
