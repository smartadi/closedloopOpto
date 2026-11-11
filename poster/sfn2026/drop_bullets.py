"""drop_bullets.py -- take the bullet text out of boxes whose panels carry the message (SfN poster v6).

    python poster/sfn2026/drop_bullets.py <in.pptx> <out.pptx> [box number ...]     (default: 2 3 4)

Aditya (2026-11-10): the LTI, closed-loop performance and sine-wave boxes (2, 3, 4) don't need their text;
the facts only the bullets held moved into the panels (box 3's titles carry the 23% and 42%, box 4's legend
the 1 Hz). Run after poster_swap_all.py and before poster_clean.py, which restacks the columns from the frames.
For each box: 'box N bullets' goes. If the bullets sat below every panel, the frame ends PAD under the lowest
panel. If they sat beside a panel (box 2), the frame keeps its size and a panel left alone in its row (box 2's
LTI fit) is centred across the box. Every other shape keeps its XML.
"""
import sys

from pptx import Presentation
from pptx.util import Emu

E = 914400
PAD = 0.30                 # in under the lowest panel: box 2's margin in v3


def inside(sh, fr):
    cx, cy = sh.left + sh.width / 2, sh.top + sh.height / 2
    return fr.left <= cx <= fr.left + fr.width and fr.top <= cy <= fr.top + fr.height


def main(src, out, boxes):
    prs = Presentation(src)
    sl = prs.slides[0]
    for n in boxes:
        fr = next(x for x in sl.shapes if x.name == f'box {n} frame')
        bul = next(x for x in sl.shapes if x.name == f'box {n} bullets')
        pics = [x for x in sl.shapes if x.name.startswith('panel ') and inside(x, fr)]
        below = bul.top >= max(p.top + p.height for p in pics) - Emu(int(0.05 * E))
        row = [p for p in pics if p.top < bul.top + bul.height and p.top + p.height > bul.top]
        bul._element.getparent().remove(bul._element)
        if below:
            bottom = max(p.top + p.height for p in pics) + Emu(int(PAD * E))
            assert bottom <= fr.top + fr.height
            print(f'box {n}: bullets out, frame {fr.height / E:.2f} -> {(bottom - fr.top) / E:.2f} in')
            fr.height = Emu(bottom - fr.top)
        else:
            assert len(row) == 1, [p.name for p in row]
            p = row[0]
            p.left = Emu(int(fr.left + (fr.width - p.width) / 2))
            print(f'box {n}: bullets out, {p.name} centred across the box')
    prs.save(out)
    print(f'{out}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2], [int(a) for a in sys.argv[3:]] or [2, 3, 4])
