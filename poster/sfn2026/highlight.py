"""highlight.py -- set the Introduction and Conclusions apart from the result boxes (SfN poster v7, 2026-11-10).

    python poster/sfn2026/highlight.py <in.pptx> <out.pptx> <style>

Aditya (2026-11-10): "i want to highlight intro and conclusion compared to other block suggest styles". Run
after poster_clean.py (positions are final). The Introduction keeps its frame and the Conclusions get one just
under their gold rule (their text starts higher than the Introduction's); both are styled alike:
  tint     pale UW purple fill, thin purple outline
  gold     pale UW gold fill, thin purple outline
  outline  no fill, thick purple outline
  dark     UW purple fill, white text, gold bullets
The result boxes stay as they are (white, heading bar only). Words and sizes are untouched.
"""
import sys

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt

E = 914400
PURPLE, GOLD = '4B2E83', 'B7A57A'
STYLES = {'tint': ('EFEAF6', 1.5), 'gold': ('F5F0E3', 1.5), 'outline': (None, 4.0), 'dark': (PURPLE, 1.5)}


def style(sh, fill, width):
    if fill:
        sh.fill.solid()
        sh.fill.fore_color.rgb = RGBColor.from_string(fill)
    else:
        sh.fill.background()
    sh.line.color.rgb = RGBColor.from_string(PURPLE)
    sh.line.width = Pt(width)


def white_text(sh):
    for el in sh._element.iter(qn('a:srgbClr')):
        par = el.getparent().tag
        el.set('val', GOLD if par == qn('a:buClr') else 'FFFFFF')


def main(src, out, name):
    fill, width = STYLES[name]
    prs = Presentation(src)
    sl = prs.slides[0]
    by = {sh.name: sh for sh in sl.shapes}
    fi, ti = by['introduction frame'], by['introduction']
    bar, rule, tc = by['Conclusions bar'], by['Conclusions bar gold rule'], by['conclusions']
    top = rule.top + rule.height + Emu(int(0.06 * E))        # the text starts 0.25 in lower: room above line 1
    bottom = tc.top + tc.height                              # the text box ends at the body's bottom margin
    fc = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, bar.left, top, bar.width, bottom - top)
    fc.name = 'conclusions frame'
    fc.shadow.inherit = False
    tc._element.addprevious(fc._element)                     # behind the text
    for sh in (fi, fc):
        style(sh, fill, width)
    if name == 'dark':
        white_text(ti)
        white_text(tc)
    prs.save(out)
    print(f'{out}: {name}; conclusions frame {fc.left / E:.2f}, {fc.top / E:.2f}, {fc.width / E:.2f} x {fc.height / E:.2f} in')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(*sys.argv[1:4])
