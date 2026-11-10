"""poster_clean.py -- the clean, frameless version of the SfN poster (Aditya 2026-11-10).

    python poster/sfn2026/poster_clean.py <poster.pptx> <out.pptx>

Takes a built poster (v3 after poster_swap_all.py) and lays it out again on the model of Fabiola Duarte's
SfN 2026 poster, which Aditya found "much cleaner": nothing draws a container. No header band, coloured bars,
box frames, number squares or rules; white ground; titles and headings in Arial regular, near-black; wide
gutters; the figures carry each section. Measured on her PDF: title 83 pt, headings 47-52 pt, body 29 pt, all
regular, all #231F20, no frames.

What changes, all from the input file, so it reruns on whatever v3 holds (his online edits included):
- header: band and gold rule removed; UW W and lab logo recoloured UW purple; title, authors, affiliation
  regular weight in ink.
- sections (Introduction, boxes 1-8, Conclusions): frames, rules, bars and the Results bar removed; box
  numbers become large purple numerals beside the heading; headings regular, ink, HEAD pt; bullets become
  plain dots; body text in ink (other text colours kept).
- layout: each column's sections are scaled by S (type too, so lines break where they did) and stacked
  from BODY_TOP to BODY_BOT with equal gaps; margins M and gutters G come from S.
Every word and every panel is the input's; nothing is reworded.
"""
import copy
import io
import sys
from pathlib import Path

from lxml import etree
from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Emu, Inches, Pt

E = 914400
A = '{http://schemas.openxmlformats.org/drawingml/2006/main}'
INK, PURPLE, MUTED = '231F20', '4B2E83', '5A5A5A'
S = 0.94                         # section scale: makes room for the gutters
M = 1.0                          # outer margin (in)
BODY_TOP, BODY_BOT = 5.35, 35.1  # in
HEAD, NUM = 42, 88               # heading and numeral size (pt), after scaling
SECTION_FRAMES = {'introduction frame': 'intro', 'conclusions frame': 'concl'}
DROP_ALWAYS = {'header', 'header gold rule', 'Results bar', 'Results bar gold rule'}


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
        tag = etree.QName(node).localname
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


def set_runs(sh, color=None, bold=None, size=None, only_plain=False):
    """Restyle every run (and the paragraph end marks). only_plain: recolour only black, purple, ink or
    theme-coloured runs; deliberate colours stay."""
    for p in sh.text_frame.paragraphs:
        for r in list(p.runs):
            f = r.font
            if color is not None:
                plain = True
                if only_plain and f.color and f.color.type is not None:
                    try:
                        plain = str(f.color.rgb).upper() in ('000000', '4B2E83', '231F20', 'FFFFFF', '262626', '404040')
                    except AttributeError:
                        plain = True          # theme colour: text colour of the template
                if plain:
                    f.color.rgb = RGBColor.from_string(color)
            if bold is not None:
                f.bold = bold
            if size is not None:
                f.size = Pt(size)


def plain_bullets(sh):
    for node in sh._element.iter(A + 'buChar'):
        node.set('char', '•')
    for node in list(sh._element.iter(A + 'buClr')):
        for c in list(node):
            node.remove(c)
        etree.SubElement(node, A + 'srgbClr', val=INK)


def unfill(sh):
    sh.fill.background()
    sh.line.fill.background()


def recolour(pic, rgb):
    """A one-colour logo on transparency (UW W white, lab logo gold) in another colour, alpha kept."""
    part = pic.part.related_part(pic._element.blipFill.blip.rEmbed)
    im = Image.open(io.BytesIO(part.blob)).convert('RGBA')
    r, g, b = (int(rgb[i:i + 2], 16) for i in (0, 2, 4))
    a = im.getchannel('A')
    out = Image.new('RGBA', im.size, (r, g, b, 255))
    out.putalpha(a)
    buf = io.BytesIO()
    out.save(buf, 'PNG')
    part._blob = buf.getvalue()


def main(src, dst):
    prs = Presentation(src)
    sl = prs.slides[0]
    shapes = list(sl.shapes)
    named = lambda n: [sh for sh in shapes if sh.name == n]

    # ---- sections: each frame plus its bar / number / heading / rule and everything drawn inside it
    frames = {}
    for sh in shapes:
        if sh.name.startswith('box ') and sh.name.endswith(' frame'):
            frames[sh.name[:-6]] = sh
        elif sh.name in SECTION_FRAMES:
            frames[SECTION_FRAMES[sh.name]] = sh
    member = {k: [] for k in frames}
    header, drop = [], []
    for sh in shapes:
        if sh.name in DROP_ALWAYS:
            drop.append(sh)
            continue
        if sh.name.startswith('Introduction bar'):
            member['intro'].append(sh)
            continue
        if sh.name.startswith('Conclusions bar'):
            member['concl'].append(sh)
            continue
        k = section_of(sh, frames)
        if k is None and sh.top / E < 4.7:
            header.append(sh)
        elif k is None:
            raise SystemExit(f'unplaced shape: {sh.shape_id} {sh.name}')
        else:
            member[k].append(sh)

    # extents of each section as the reader saw it: frame plus its heading row
    ext = {}
    for k, mem in member.items():
        box = [frames[k]] + [sh for sh in mem if sh.name.endswith((' number', ' heading')) or ' bar' in sh.name]
        x0 = min(sh.left for sh in box); y0 = min(sh.top for sh in box)
        x1 = max(sh.left + sh.width for sh in box); y1 = max(sh.top + sh.height for sh in box)
        ext[k] = (x0, y0, x1, y1)

    # columns by position, sections top to bottom
    cols = [[], [], []]
    for k, (x0, y0, x1, y1) in ext.items():
        cx = (x0 + x1) / 2 / E
        cols[0 if cx < 16.9 else 1 if cx < 33.3 else 2].append(k)
    for c in cols:
        c.sort(key=lambda k: ext[k][1])
    width = [max(ext[k][2] for k in c) - min(ext[k][0] for k in c) for c in cols]
    G = (prs.slide_width - 2 * M * E - S * sum(width)) / 2      # gutter
    assert G > 0.8 * E, f'gutter {G / E:.2f} in'
    left = [M * E]
    for w in width[:2]:
        left.append(left[-1] + S * w + G)

    # ---- restyle before scaling (sizes set here are pre-scale, so divide by S)
    for sh in drop:
        sh._element.getparent().remove(sh._element)
    for k, mem in member.items():
        for sh in list(mem):
            n = sh.name
            if sh is frames[k] or (n.startswith(('box ', 'Introduction bar ', 'Conclusions bar '))
                                   and n.endswith((' rule', 'outline'))):     # not 'panel frame' (box 1 image)
                sh._element.getparent().remove(sh._element)
                mem.remove(sh)
            elif n.endswith(' number'):
                unfill(sh)
                set_runs(sh, color=PURPLE, bold=False, size=NUM / S)
            elif n.endswith(' heading'):
                set_runs(sh, color=INK, bold=False, size=HEAD / S)
                for node in sh._element.iter(A + 'lnSpc'):            # fixed 1.03x leading: open to 1.12x
                    for sp in node.iter(A + 'spcPts'):
                        sp.set('val', str(int(HEAD * 1.12 / S * 100)))
            elif n in ('Introduction bar', 'Conclusions bar'):
                unfill(sh)
                set_runs(sh, color=INK, bold=False, size=HEAD / S)
                for p in sh.text_frame.paragraphs:
                    p.alignment = 1                                   # left
                sh.text_frame.margin_left = 0
            elif sh.has_text_frame:
                set_runs(sh, color=INK, only_plain=True)
                plain_bullets(sh)

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
    print(f'scale {S}, margins {M} in, gutters {G / E:.2f} in')

    # ---- header on white
    for sh in header:
        if sh.name in ('UW logo', 'lab logo'):
            recolour(sh, PURPLE)
        elif sh.name == 'title':
            set_runs(sh, color=INK, bold=False)
        elif sh.name == 'authors':
            set_runs(sh, color=INK, bold=False)
        elif sh.name == 'affiliation':
            set_runs(sh, color=MUTED, bold=False)
    prs.save(dst)
    print(f'{dst}: {len(sl.shapes)} shapes')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
