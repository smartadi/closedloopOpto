"""carry_edits.py -- carry Aditya's online edits from one poster version into the next (SfN 2026, v5).

    python poster/sfn2026/carry_edits.py <edited.pptx> <rebuilt.pptx> <new.pptx> <out.pptx>

<edited> is a version as it is in OneDrive, with his online edits. <rebuilt> is the same version built again
here from the same source (so it differs from <edited> only by his edits). <new> is the next version, built
from the same source. Every shape that is not a picture and whose XML differs between <edited> and <rebuilt>
is copied from <edited> into <new> in place of its namesake. Shapes are matched by name and order; the
script stops if <edited> and <rebuilt> don't hold the same shapes, or if an edited shape is gone from <new>
(the new version may add or drop other shapes, as v6 does). A carried shape that the new layout only
moved (same XML but its position) keeps his edit and moves by the same amount. Differences that are only PowerPoint housekeeping
(an empty end-of-paragraph run, lang/dirty attributes, relationship ids) don't count.
First use (2026-11-10): his v4 heading edits (boxes 1, 2, 4, 6, 7, 8) into v5.
"""
import copy
import re
import sys

from lxml import etree
from pptx import Presentation

PIC = '{http://schemas.openxmlformats.org/presentationml/2006/main}pic'
OFF = re.compile(r'<a:off [^>]*></a:off>')


def norm(el):
    x = etree.tostring(el, method='c14n', exclusive=True).decode()
    x = re.sub(r' r:(embed|link|id)="[^"]*"', '', x)
    x = re.sub(r' (lang|dirty)="[^"]*"', '', x)
    return re.sub(r'<a:endParaRPr[^>]*></a:endParaRPr>', '', x)


def keyed(sl):
    out, seen = {}, {}
    for sh in sl.shapes:
        i = seen[sh.name] = seen.get(sh.name, -1) + 1
        out[(sh.name, i)] = sh
    return out


def main(edited, rebuilt, new, out):
    pe, pr, pn = (Presentation(f) for f in (edited, rebuilt, new))
    e, r, n = (keyed(p.slides[0]) for p in (pe, pr, pn))
    assert list(e) == list(r), 'the edited poster and its rebuild hold different shapes'
    copied = []
    for k in e:
        if e[k]._element.tag == PIC or norm(e[k]._element) == norm(r[k]._element):
            continue
        assert k in n, f'{k[0]} was edited online but is gone from the new version'
        same = norm(r[k]._element) == norm(n[k]._element)
        moved = not same and OFF.sub('', norm(r[k]._element)) == OFF.sub('', norm(n[k]._element))
        assert same or moved, f'{k[0]} changed in the new version too'
        el = copy.deepcopy(e[k]._element)
        n[k]._element.addprevious(el)
        n[k]._element.getparent().remove(n[k]._element)
        if moved:            # the new layout only moved it: his edit, moved by the same amount
            sh = next(x for x in pn.slides[0].shapes if x._element is el)
            sh.left = e[k].left + n[k].left - r[k].left
            sh.top = e[k].top + n[k].top - r[k].top
        copied.append(k[0] + (' (moved with the layout)' if moved else ''))
    pn.save(out)
    print(f'{out}: carried {len(copied)} edited shapes: {", ".join(copied)}')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(*sys.argv[1:5])
