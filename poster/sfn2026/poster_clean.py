"""poster_clean.py -- the frameless version of the SfN poster (Aditya 2026-11-10).

    python poster/sfn2026/poster_clean.py <poster.pptx> <out.pptx>

Takes a built poster (v3 after poster_swap_all.py) and removes the box outlines. Aditya's spec, after two
passes: "i like the headers as they were just the boxes removal is what is needed", then "give each header a
purple background remove numbers from them, give the intro a box".
- Box outlines go, except the Introduction's, which keeps its box. The outline round the Conclusions bar goes.
- Each box heading sits on a purple bar the width of its old box, white bold text, a gold rule under it: the
  same look as the Introduction / Results / Conclusions bars. The number squares go. Built from the heading's
  own shapes: the number square becomes the bar, the purple rule becomes the gold rule.
- The title band and the Introduction / Results / Conclusions bars stay as they were.
Without outlines the columns need real gutters, or neighbouring heading bars run together. So each column's
sections are scaled by S (type too, so lines break where they did) and stacked from BODY_TOP to BODY_BOT with
equal gaps; the outer margins line up with the title band and the gutters take what is left.
Every word and panel is the input's.
"""
import sys

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Emu, Inches

E = 914400
S = 0.95                          # section scale: makes room for the gutters
BODY_TOP, BODY_BOT = 4.82, 35.32  # in: where the boxes started and ended
INSET = 0.2                       # in: heading text inside its bar, as the bullets sit inside the old boxes
GOLD, WHITE = 'B7A57A', 'FFFFFF'
SECTION_FRAMES = {'introduction frame': 'intro', 'conclusions frame': 'concl'}
KEEP_OUTLINE = {'intro'}
OUTLINES = ('Conclusions bar outline',)


def section_of(sh, frames):
    cx, cy = sh.left + sh.width / 2, sh.top + sh.height / 2
    hits = [k for k, f in frames.items()
            if f.left - E * 0.05 <= cx <= f.left + f.width + E * 0.05
            and f.top - E * 0.25 <= cy <= f.top + f.height + E * 0.05]
    return hits[0] if len(hits) == 1 else None


def scale_text(el, s):
    """Scale every size-like attribute in a shape's text: run sizes, spacing in points, bullet sizes,
    indents and insets, so the text wraps where it did."""
    for node in el.iter():
        tag = node.tag.rsplit('}', 1)[-1]
        if tag in ('rPr', 'defRPr', 'endParaRPr') and node.get('sz'):
            node.set('sz', str(int(round(int(node.get('sz')) * s))))
        elif tag in ('spcPts', 'buSzPts') and node.get('val'):
            node.set('val', str(int(round(int(node.get('val')) * s))))
        elif tag == 'pPr':
            for k in ('marL', 'indent'):
                if node.get(k):
                    node.set(k, str(int(round(int(node.get(k)) * s))))
        elif tag == 'bodyPr':
            for k in ('lIns', 'tIns', 'rIns', 'bIns'):
                if node.get(k):
                    node.set(k, str(int(round(int(node.get(k)) * s))))


def heading_bar(mem, x0, x1):
    """Number square -> purple bar across the box, purple rule -> gold rule under it, heading text white."""
    num = next(sh for sh in mem if sh.name.endswith(' number'))
    head = next(sh for sh in mem if sh.name.endswith(' heading'))
    rule = next(sh for sh in mem if sh.name.endswith(' rule'))
    num.left, num.width, num.top, num.height = x0, x1 - x0, head.top, head.height
    num.text_frame.text = ''                                  # the number goes, the purple fill stays
    rule.left, rule.width, rule.top = x0, x1 - x0, head.top + head.height
    rule.height = Inches(0.06)
    rule.fill.solid()
    rule.fill.fore_color.rgb = RGBColor.from_string(GOLD)
    head.left = x0 + Inches(INSET)      # same width as before, so lines break where they did (wider split "1-4 Hz")
    for p in head.text_frame.paragraphs:
        for r in p.runs:
            r.font.color.rgb = RGBColor.from_string(WHITE)
    for br in head._element.iter('{http://schemas.openxmlformats.org/drawingml/2006/main}br'):
        for c in br.iter('{http://schemas.openxmlformats.org/drawingml/2006/main}srgbClr'):
            c.set('val', WHITE)


def main(src, dst):
    prs = Presentation(src)
    sl = prs.slides[0]
    shapes = list(sl.shapes)
    title_bg = next(sh for sh in shapes if sh.name == 'header')

    # ---- sections: each frame plus its bar / number / heading / rule and everything drawn inside it
    frames = {}
    for sh in shapes:
        if sh.name.startswith('box ') and sh.name.endswith(' frame'):
            frames[sh.name[:-6]] = sh
        elif sh.name in SECTION_FRAMES:
            frames[SECTION_FRAMES[sh.name]] = sh
    member = {k: [] for k in frames}
    for sh in shapes:
        if sh.name.startswith('Introduction bar'):
            member['intro'].append(sh)
        elif sh.name.startswith('Results bar'):          # the Results bar opens column 1's box run
            member['box 1'].append(sh)
        elif sh.name.startswith('Conclusions bar'):
            member['concl'].append(sh)
        else:
            k = section_of(sh, frames)
            if k is None and sh.top / E >= 4.7:
                raise SystemExit(f'unplaced shape: {sh.shape_id} {sh.name}')
            if k is not None:
                member[k].append(sh)

    # extents of each section as the reader saw it: frame plus its bars and heading row
    ext = {}
    for k, mem in member.items():
        box = [frames[k]] + [sh for sh in mem if sh.name.endswith((' number', ' heading')) or ' bar' in sh.name]
        ext[k] = (min(sh.left for sh in box), min(sh.top for sh in box),
                  max(sh.left + sh.width for sh in box), max(sh.top + sh.height for sh in box))

    # ---- headings and outlines
    for k, mem in member.items():
        if k.startswith('box '):
            heading_bar(mem, frames[k].left, frames[k].left + frames[k].width)
        for sh in list(mem):
            if (sh is frames[k] and k not in KEEP_OUTLINE) or sh.name in OUTLINES:
                sh._element.getparent().remove(sh._element)
                mem.remove(sh)

    # columns by position, sections top to bottom; margins line up with the title band
    cols = [[], [], []]
    for k, (x0, y0, x1, y1) in ext.items():
        cx = (x0 + x1) / 2 / E
        cols[0 if cx < 16.9 else 1 if cx < 33.3 else 2].append(k)
    for c in cols:
        c.sort(key=lambda k: ext[k][1])
    width = [max(ext[k][2] for k in c) - min(ext[k][0] for k in c) for c in cols]
    G = (title_bg.width - S * sum(width)) / 2
    assert G > 1.0 * E, f'gutter {G / E:.2f} in'
    left = [title_bg.left]
    for w in width[:2]:
        left.append(left[-1] + S * w + G)

    # ---- place: scale each section about its own top-left, stack down its column with equal gaps
    for c, ks in enumerate(cols):
        hs = [S * (ext[k][3] - ext[k][1]) for k in ks]
        gap = (Inches(BODY_BOT - BODY_TOP) - sum(hs)) / (len(ks) - 1)
        assert gap > 0.4 * E, f'column {c + 1}: gap {gap / E:.2f} in'
        y = Inches(BODY_TOP)
        for k, h in zip(ks, hs):
            x0, y0 = ext[k][0], ext[k][1]
            for sh in member[k]:
                sh.left = Emu(int(left[c] + (sh.left - x0) * S))
                sh.top = Emu(int(y + (sh.top - y0) * S))
                sh.width = Emu(int(sh.width * S))
                sh.height = Emu(int(sh.height * S))
                if sh.has_text_frame:
                    scale_text(sh._element, S)
            y += h + gap
        print(f'column {c + 1}: {", ".join(ks)}; gap {gap / E:.2f} in')
    print(f'scale {S}, margins = title band, gutters {G / E:.2f} in')
    prs.save(dst)
    print(f'{dst}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
