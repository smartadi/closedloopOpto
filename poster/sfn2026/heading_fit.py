"""heading_fit.py -- box headings use the full width of their purple bars (SfN poster v8, 2026-11-11).

    python poster/sfn2026/heading_fit.py <in.pptx> <out.pptx>

Aditya (2026-11-11): "the panel titles are not filling up their space, the return appears midline in some of
them". Approved 2026-11-11 ("Approve"). Run after carry_edits.py, since his online heading edits come in
there. For each 'box N heading':
- One paragraph. Manual line breaks and extra paragraphs become spaces (box 3 broke after "reduces", box 7
  after "grows with"), non-breaking spaces become spaces (box 6's tied "4 Hz power explain part of the error."
  into one unit, so it broke after "1-"), runs of spaces collapse, and no space is left at either end.
- PowerPoint then wraps at the bar's right edge. Three ties keep a wrap from looking broken: the last two
  words are joined by a non-breaking space (no one-word last line, as box 4's "lag"); a numeric range such as
  "1-4 Hz" is held together (the en dash becomes a figure dash, U+2012, which Arial draws the same width and
  height and PowerPoint does not break after; it breaks after an en dash even with a word joiner U+2060 or a
  zero-width no-break space U+FEFF behind it, tested 2026-11-11; plus a non-breaking space before the unit);
  and hyphens inside a word become non-breaking hyphens (box 3 split "trial-to-trial").
- The text box spans its bar ('box N number') from INSET_L to INSET_R inside it, same top and height, text
  centred vertically. One size, SIZE, for every heading (they were 37.0 or 37.05 pt).
The bars, gold rules and the Introduction and Conclusions frames in each column take the left edge and width
of that column's box bars (box 7's bar sat 0.13 in left of boxes 6 and 8 and was 0.15 in wider; the
Introduction bar was 0.27 in narrower). The Results bar's gold rule, which lay hidden under box 1's rule,
goes back under the Results bar. Words are unchanged: the script stops if any word differs.
"""
import collections
import copy
import re
import sys

from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches

E = 914400
INSET_L, INSET_R = 0.15, 0.10     # in
SIZE = 3700                       # 37 pt
NBSP, FIG, NBH = '\u00a0', '\u2012', '\u2011'   # no-break space, figure dash, no-break hyphen


def plain(t):
    for c in ('\u2060', '\ufeff'):
        t = t.replace(c, '')
    return t.replace(NBSP, ' ').replace(FIG, '\u2013').replace(NBH, '-')


def fit_text(raw):
    t = re.sub(r'\s+', ' ', plain(raw)).strip()
    t = re.sub(r'(\d)\u2013(\d+) (?=\S)', lambda m: f'{m[1]}{FIG}{m[2]}{NBSP}', t)
    t = re.sub(r'(?<=\w)-(?=\w)', NBH, t)
    head, _, last = t.rpartition(' ')
    return f'{head}{NBSP}{last}' if head else t


def heading(sh):
    tb = sh._element.txBody
    ps = tb.findall(qn('a:p'))
    runs = [r for p in ps for r in p.findall(qn('a:r'))]
    look = {(r.rPr.get('b', '0'), r.rPr.get('i', '0'), ''.join(c.get('val', '') for c in r.rPr.iter(qn('a:srgbClr'))))
            for r in runs}
    assert len(look) == 1, f'{sh.name}: runs differ in style {look}'
    raw = ''
    for p in ps:
        for el in p:
            if el.tag == qn('a:r'):
                raw += el.find(qn('a:t')).text or ''
            elif el.tag == qn('a:br'):
                raw += ' '
        raw += ' '
    text = fit_text(raw)
    keep = ps[0]
    for p in ps[1:]:
        tb.remove(p)
    first = copy.deepcopy(runs[0])
    for el in list(keep):
        if el.tag != qn('a:pPr'):
            keep.remove(el)
    first.rPr.set('sz', str(SIZE))
    for a in ('lang', 'dirty'):
        first.rPr.attrib.pop(a, None)
    first.find(qn('a:t')).text = text
    keep.append(first)
    tb.find(qn('a:bodyPr')).set('anchor', 'ctr')
    return raw.strip(), text


def column(sh):
    c = (sh.left + sh.width / 2) / E
    return 0 if c < 17 else 1 if c < 34 else 2


def main(src, dst):
    prs = Presentation(src)
    sl = prs.slides[0]
    by = {sh.name: sh for sh in sl.shapes}

    bars = [sh for n, sh in by.items() if re.fullmatch(r'box \d number', n)]
    ref = {}
    for k in range(3):
        votes = collections.Counter((sh.left, sh.width) for sh in bars if column(sh) == k)
        ref[k] = votes.most_common(1)[0][0]
    rx = re.compile(r'box \d (number|rule)|(Introduction|Results|Conclusions) bar( gold rule)?'
                    r'|(introduction|conclusions) frame')
    for n, sh in by.items():
        if rx.fullmatch(n):
            l, w = ref[column(sh)]
            if (sh.left, sh.width) != (l, w):
                print(f'{n}: x {sh.left / E:.2f} w {sh.width / E:.2f} -> x {l / E:.2f} w {w / E:.2f} in')
                sh.left, sh.width = l, w
    rb, rr = by['Results bar'], by['Results bar gold rule']
    ib, ir = by['Introduction bar'], by['Introduction bar gold rule']
    top = rb.top + rb.height - (ib.top + ib.height - ir.top)
    if rr.top != top:
        print(f'Results bar gold rule: y {rr.top / E:.2f} -> {top / E:.2f} in (under the Results bar)')
        rr.top = Emu(top)

    for i in range(1, 9):
        sh, bar = by[f'box {i} heading'], by[f'box {i} number']
        old, new = heading(sh)
        sh.left = bar.left + Inches(INSET_L)
        sh.width = bar.width - Inches(INSET_L + INSET_R)
        sh.top, sh.height = bar.top, bar.height
        if plain(new) != re.sub(r'\s+', ' ', plain(old)):
            raise SystemExit(f'box {i}: words changed: {old!r} -> {new!r}')
        print(f'box {i}: {new!r}')
    prs.save(dst)
    print(dst)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
