"""drop_bullets.py -- take the bullet text out of boxes whose panels carry the message (SfN poster v6).

    python poster/sfn2026/drop_bullets.py <in.pptx> <out.pptx> [box number ...]     (default: 2 3 4)

Aditya (2026-11-10): the LTI, closed-loop performance and sine-wave boxes (2, 3, 4) don't need their text;
the facts only the bullets held moved into the panels (box 3's titles carry the 23% and 42%, box 4's legend
the 1 Hz). Run after poster_swap_all.py and before poster_clean.py, which restacks the columns from the frames.
For each box: 'box N bullets' goes and the frame ends PAD under the lowest panel. (v6 kept box 2's frame and
centred its lone LTI fit; since v7 poster_swap_all.py lays boxes 2-4 out in rows, so the frame only follows
the panels, and may get taller.) Every other shape keeps its XML.
"""
import sys

from pptx import Presentation
from pptx.util import Emu

E = 914400
PAD = 0.30                 # in under the lowest panel: box 2's margin in v3


def main(src, out, boxes):
    prs = Presentation(src)
    sl = prs.slides[0]
    for n in boxes:
        fr = next(x for x in sl.shapes if x.name == f'box {n} frame')
        bul = next(x for x in sl.shapes if x.name == f'box {n} bullets')
        rule = next(x for x in sl.shapes if x.name == f'box {n} rule')
        pics = [x for x in sl.shapes if x.name.startswith('panel ') and x.top >= rule.top
                and fr.left <= x.left + x.width / 2 <= fr.left + fr.width and x.top < fr.top + fr.height]
        bul._element.getparent().remove(bul._element)
        bottom = max(p.top + p.height for p in pics) + Emu(int(PAD * E))
        print(f'box {n}: bullets out, frame {fr.height / E:.2f} -> {(bottom - fr.top) / E:.2f} in '
              f'({", ".join(p.name for p in pics)})')
        fr.height = Emu(bottom - fr.top)
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2], [int(a) for a in sys.argv[3:]] or [2, 3, 4])
