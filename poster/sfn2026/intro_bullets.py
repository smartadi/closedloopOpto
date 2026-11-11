"""intro_bullets.py -- the Introduction's bullets in the poster's bullet style (SfN poster v7, 2026-11-10).

    python poster/sfn2026/intro_bullets.py <in.pptx> <out.pptx>

Aditya (2026-11-10): "bullet styles are differnent in intro block and other make them same uw style". The
Introduction used black round bullets; every other box uses a purple (UW 4B2E83) triangle at 75% size with a
smaller hanging indent and a little space between paragraphs. This copies those bullet settings from
'box 1 bullets' (its first paragraph for the bullet, indent and line spacing; its second for the space before
a paragraph) onto each Introduction paragraph. The words, runs and sizes are untouched. The new space between
paragraphs makes the text taller, so the Introduction's frame and text box grow by that much (plus 0.10 in:
in v6 the last line already touched the frame). Run before poster_clean.py, which restacks column 1.
"""
import copy
import sys

from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Emu

BULLET = ('a:buClr', 'a:buSzPct', 'a:buFont', 'a:buChar')


def ppr(p):
    return p._p.get_or_add_pPr()


def main(src, out):
    prs = Presentation(src)
    sl = prs.slides[0]
    intro = next(sh for sh in sl.shapes if sh.name == 'introduction')
    ref = next(sh for sh in sl.shapes if sh.name == 'box 1 bullets').text_frame.paragraphs
    r0, r1 = ppr(ref[0]), ppr(ref[1])
    gap = r1.find(qn('a:spcBef'))
    added = 0
    for j, p in enumerate(intro.text_frame.paragraphs):
        pr = ppr(p)
        for k in ('marL', 'indent'):
            pr.set(k, r0.get(k))
        for tag in BULLET + ('a:spcBef',):
            for el in pr.findall(qn(tag)):
                pr.remove(el)
        new = [copy.deepcopy(r0.find(qn(t))) for t in BULLET]
        if j > 0 and gap is not None:
            added += int(gap.find(qn('a:spcPts')).get('val')) / 100 * 12700        # 1/100 pt -> EMU
            ln = pr.find(qn('a:lnSpc'))
            (ln.addnext if ln is not None else (lambda e: pr.insert(0, e)))(copy.deepcopy(gap))
        for el in new:
            pr.append(el)                      # bullet elements follow spacing in the schema order
    grow = Emu(int(added + 0.10 * 914400))
    frame = next(sh for sh in sl.shapes if sh.name == 'introduction frame')
    frame.height += grow
    intro.height += grow
    prs.save(out)
    print(f'{out}: {len(intro.text_frame.paragraphs)} Introduction paragraphs in the box bullet style; '
          f'frame and text {grow / 914400:.2f} in taller')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
