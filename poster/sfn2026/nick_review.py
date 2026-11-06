"""nick_review.py -- Nick's poster review (2026-11-06) and Xander's box 2 cut.

    python poster/sfn2026/nick_review.py <poster.pptx> <out.pptx>

Runs on the poster as saved 2026-11-05 15:41 (box 4 with three conditions). Changes:
  authors        Nicholas A. Steinmetz (Nick, item 1).
  introduction   a motivation sentence first and a plainer bold line (Nick, items 2 and 3; Aditya picked
                 option A). Aditya's two sentences in between are unchanged.
  box 1 heading  Nick's wording, on two lines (item 4).
  box 2          the state panel and its bullet are gone (Xander; Aditya agreed 2026-11-06). The heading now
                 says only what the box shows. The three impulse panels sit in two rows, scaled to fill the
                 column, which also makes their type larger (item 5). The bullets sit beside the fit.
  column 1       re-stacked top to bottom with even gaps, ending where it ended before.
  boxes 3 and 4  bullets moved in from the frame edge, like boxes 5 to 8 (item 8).
Every other shape keeps its XML; main() asserts that.
"""
import copy
import sys

from lxml import etree
from pptx import Presentation
from pptx.oxml.ns import qn

from box5_refresh import set_two_lines
from build_pptx import BODY, text_h
from patch_online_v2 import bullets_h, inches, place

E = 914400
AUTHORS = ('Nick Steinmetz', 'Nicholas A. Steinmetz')
INTRO = ['Mesoscale cortical activity changes with arousal and movement, and these changes influence how animals '
         'perceive and act. Mesoscale cortical activity is typically perturbed open loop. Whether feedback can '
         'reliably regulate it, and what limits that control, remains largely untested.',
         'We used real-time imaging and optogenetics to hold activity at one cortical site at a target level, and '
         'asked when this works and when it does not.']
HEAD1 = ('Design of a real-time closed-loop system', 'with imaging and optogenetics')
HEAD2 = ('The average response to stimulation', 'is near-linear')
KEEP2 = ['Suppression scales with laser power.', 'Low-order linear model predicts stimulation response.']
GAP = 0.45            # intro frame to Results bar, box 1 to box 2
PAD_T, PAD_B = 0.17, 0.17   # intro text inside its frame, as before
RULE_AT = 1.41        # frame top to rule, two-line heading (boxes 3 to 8)
ROW_GAP = 0.3         # between the two rows of box 2
SIDE = 0.4            # fit panel to bullets
INNER = (0.88, 16.60)  # column 1 inner edges: frame 0.68..16.80, 0.2 pad


def main(src, out):
    prs = Presentation(src)
    sl = prs.slides[0]
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)
    before = {sh.shape_id: c14n(sh._element) for sh in sl.shapes}
    S = {}
    for sh in sl.shapes:
        S.setdefault(sh.name, []).append(sh)
    one = lambda n: S[n][0]
    box = lambda sh: tuple(round(inches(v), 2) for v in (sh.left, sh.top, sh.width, sh.height))
    touched = set()

    def tag(*shapes):
        touched.update(sh.shape_id for sh in shapes)

    # ---- authors
    r = one('authors')._element.txBody.find(qn('a:p')).find(qn('a:r')).find(qn('a:t'))
    assert AUTHORS[0] in r.text, r.text
    r.text = r.text.replace(*AUTHORS)
    tag(one('authors'))

    # ---- introduction text
    intro, ifr = one('introduction'), one('introduction frame')
    ps = intro._element.txBody.findall(qn('a:p'))
    assert len(ps) == 2 and all(len(p.findall(qn('a:r'))) == 1 for p in ps)
    for p, t in zip(ps, INTRO):
        p.find(qn('a:r')).find(qn('a:t')).text = t
    w = inches(intro.width)
    h_text = (text_h(INTRO[:1], BODY, w) + text_h(INTRO[1:], BODY, w, bold=True)) + 9 / 72
    tag(intro, ifr)

    # ---- old geometry
    f1, f2 = one('box 1 frame'), one('box 2 frame')
    y1_old, y1_end = inches(f1.top), inches(f1.top + f1.height)
    y2_old, y2_end = inches(f2.top), inches(f2.top + f2.height)
    col = lambda sh: inches(sh.left) < 16.8
    chrome = lambda sh, b: sh.name in (f'box {b} {p}' for p in ('frame', 'number', 'heading', 'rule'))
    in1 = [sh for sh in sl.shapes if col(sh) and y1_old <= inches(sh.top) < y1_end and not chrome(sh, 1)]
    in2 = [sh for sh in sl.shapes if col(sh) and y2_old <= inches(sh.top) < y2_end and not chrome(sh, 2)]
    assert sorted(sh.name for sh in in1) == ['box 1 bullets', 'panel frame', 'panel frame', 'panel frame',
                                            'panel loop', 'panel rig'], [sh.name for sh in in1]
    assert sorted(sh.name for sh in in2) == ['box 2 bullets', 'panel imp_dose', 'panel imp_fit', 'panel imp_state',
                                            'panel imp_traces'], [sh.name for sh in in2]

    # ---- column 1, top to bottom
    y = inches(ifr.top)
    place(intro, y=y + PAD_T, h=h_text + 0.05)
    place(ifr, h=h_text + PAD_T + PAD_B + 0.05)
    y = inches(ifr.top + ifr.height) + GAP
    rb, rg = one('Results bar'), one('Results bar gold rule')
    rg_off, f1_off = inches(rg.top - rb.top), y1_old - inches(rb.top)
    place(rb, y=y)
    place(rg, y=y + rg_off)
    tag(rb, rg)

    # box 1: two-line heading, everything below it moves down with the frame
    y1 = y + f1_off
    rule1_old = inches(one('box 1 rule').top) - y1_old
    dy = (y1 - y1_old) + (RULE_AT - rule1_old)
    set_two_lines(one('box 1 heading'), *HEAD1)
    place(f1, y=y1, h=inches(f1.height) + RULE_AT - rule1_old)
    for n in ('box 1 number', 'box 1 heading'):
        place(one(n), y=y1, h=1.44)
    place(one('box 1 rule'), y=y1 + RULE_AT)
    for sh in in1:
        place(sh, y=inches(sh.top) + dy)
    tag(f1, one('box 1 number'), one('box 1 heading'), one('box 1 rule'), *in1)

    # box 2: from GAP under box 1 to where column 1 ended before
    y2 = inches(f1.top + f1.height) + GAP
    place(f2, y=y2, h=y2_end - y2)
    set_two_lines(one('box 2 heading'), *HEAD2)
    rule2 = inches(one('box 2 rule').top) - y2_old
    for n in ('box 2 number', 'box 2 heading'):
        place(one(n), y=y2)
    place(one('box 2 rule'), y=y2 + rule2)
    tag(f2, one('box 2 number'), one('box 2 heading'), one('box 2 rule'))

    # state panel and its bullet out
    st = one('panel imp_state')
    rid = st._element.blip_rId
    st._element.getparent().remove(st._element)
    sl.part.drop_rel(rid)
    b2 = one('box 2 bullets')
    ps = b2._element.txBody.findall(qn('a:p'))
    assert 'Single-trial variability' in ''.join(t.text for t in ps[2].iter(qn('a:t')))
    b2._element.txBody.remove(ps[2])
    got = [''.join(t.text for t in p.iter(qn('a:t'))) for p in b2._element.txBody.findall(qn('a:p'))]
    assert got == KEEP2, got

    # two rows: traces | dose, then fit | bullets. One scale k for all three: the largest that fills the
    # height and still leaves the first bullet on one line. Left edges of traces and fit line up; dose
    # is centred over the bullets. Height left over is shared above, between and below the rows.
    tr, do, fi = one('panel imp_traces'), one('panel imp_dose'), one('panel imp_fit')
    top = y2 + rule2 + 0.05 + 0.23                       # rule to panels, as before
    bot = y2_end - 0.2
    (wt, ht), (wd, hd), (wf, hf) = [(inches(s.width), inches(s.height)) for s in (tr, do, fi)]
    h_row1 = max(ht, hd)
    bw_at = lambda k: INNER[1] - (INNER[0] + wf * k + SIDE)
    one_line = lambda w: bullets_h(KEEP2[:1], w - 0.25) <= bullets_h(['x'], w) + 0.01   # with room to spare
    k = (bot - top - ROW_GAP) / (h_row1 + hf)
    while not one_line(bw_at(k)):
        k -= 0.005
    spare = bot - top - ROW_GAP - k * (h_row1 + hf)
    top, row_gap = top + spare / 3, ROW_GAP + spare / 3
    assert INNER[1] - INNER[0] - k * (wt + wd) > 0.6
    for sh in (tr, do, fi):
        sh.width, sh.height = int(sh.width * k), int(sh.height * k)
    r1c = top + h_row1 * k / 2
    place(tr, x=INNER[0], y=r1c - ht * k / 2)
    place(do, x=(INNER[0] + wf * k + SIDE + INNER[1] - wd * k) / 2, y=r1c - hd * k / 2)   # centred over the bullets
    y_fit = top + h_row1 * k + row_gap
    place(fi, x=INNER[0], y=y_fit)
    bx, bw = INNER[0] + wf * k + SIDE, bw_at(k)
    bh = bullets_h(KEEP2, bw)
    place(b2, x=bx, w=bw, y=y_fit + hf * k / 2 - bh / 2, h=bh + 0.05)
    tag(tr, do, fi, b2)
    print(f'box 2: panels x{k:.3f} (type {6 * 2.97 * k:.1f} pt), spare {spare:.2f} in, bullets {bw:.2f} in wide, '
          f'{bh:.2f} in tall')

    # ---- boxes 3, 4: bullets in from the frame, as box 5
    b5 = one('box 5 bullets')
    for n in ('box 3 bullets', 'box 4 bullets'):
        place(one(n), x=inches(b5.left), w=inches(b5.width))
        tag(one(n))

    # ---- checks
    now = {sh.shape_id: sh for sh in sl.shapes}
    assert st.shape_id not in now and len(now) == len(before) - 1
    for sid, x in before.items():
        if sid in now and sid not in touched:
            assert c14n(now[sid]._element) == x, now[sid].name
    fr = [(n, one(f'{n} frame')) for n in ('introduction', 'box 1', 'box 2')]
    for n, f in fr:
        print(f'{n:13s} frame y {inches(f.top):6.2f} .. {inches(f.top + f.height):6.2f}')
    for sh in in1 + in2 + [b2]:
        if sh.shape_id not in now:
            continue
        f = f1 if sh in in1 else f2
        L, T, W, H = box(sh)
        assert inches(f.left) + 0.1 <= L and L + W <= inches(f.left + f.width) - 0.1, sh.name
        assert inches(f.top) + 1.4 <= T and T + H <= inches(f.top + f.height) + 0.001, (sh.name, T, T + H)
    assert abs(inches(f2.top + f2.height) - y2_end) < 0.005
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes, {len(touched)} touched')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
