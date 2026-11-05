"""box4_refresh.py -- box 4 (moving target) with three conditions: open loop, closed loop, CL + preview.

    python poster/sfn2026/box4_refresh.py <poster.pptx> <out.pptx>

Aditya, 2026-11-05: "lets just do open loop closed loop and cl + preview". Run sine_panels.m first: it prints the
four panels without OL + preview. This swaps each into its old spot (panel_swap.swap: same centre, never taller)
and rewrites the box's one bullet. Re-runnable. Every other shape keeps its XML; main() asserts that.
"""
import copy
import sys

from lxml import etree
from pptx import Presentation
from pptx.oxml.ns import qn

from panel_swap import PAN, swap
from patch_online_v2 import bullets_h, inches, set_bullets

BULLETS = ['1 Hz sine target: feedback lowers the error; preview removes the remaining lag.']
PANELS = [
    ('panel sine_avg', 'sine3_avg', 'Sine-target trial averages for open loop, closed loop, and closed loop with preview'),
    ('panel sine_lag', 'sine3_lag', 'Phase lag for open loop, closed loop, and closed loop with preview'),
    ('panel sine_rmse', 'sine3_rmse', 'Trial RMSE distributions for open loop, closed loop, and closed loop with preview'),
    ('panel sine_var', 'sine3_var', 'Variance across trials over time for open loop, closed loop, and closed loop with preview'),
]


def main(src, out):
    prs = Presentation(src)
    sl = prs.slides[0]
    before = {sh.shape_id: copy.deepcopy(sh._element) for sh in sl.shapes}
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)
    gone = [swap(sl, shape, PAN / f'{name}_raw.pdf', name, alt) for shape, name, alt in PANELS]

    b4 = next(sh for sh in sl.shapes if sh.name == 'box 4 bullets')
    f4 = next(sh for sh in sl.shapes if sh.name == 'box 4 frame')
    p0 = b4._element.txBody.findall(qn('a:p'))[0]
    ppr, rpr = p0.find(qn('a:pPr')), p0.find(qn('a:r')).find(qn('a:rPr'))
    set_bullets(b4, BULLETS, copy.deepcopy(ppr), copy.deepcopy(ppr), copy.deepcopy(rpr))
    b_h = bullets_h(BULLETS, inches(b4.width))
    one = bullets_h(['x'], inches(b4.width))                  # the box has room for one line, as Aditya left it
    assert b_h <= one + 0.01, f'box 4 bullet wraps: {b_h:.2f} in, one line is {one:.2f} in'
    print(f'box 4 bullet: one line ({b_h:.2f} in), box bottom {inches(f4.top + f4.height):.2f} in')

    now = {sh.shape_id: sh for sh in sl.shapes}
    assert len(now) == len(before) and not set(gone) & set(now)
    for sid, el in before.items():
        if sid not in gone and sid != b4.shape_id:
            assert c14n(now[sid]._element) == c14n(el), now[sid].name
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
