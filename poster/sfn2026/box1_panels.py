"""box1_panels.py -- box 1's drawings with poster-size labels (SfN poster v5, 2026-11-10).

    python poster/sfn2026/box1_panels.py

Approved by Aditya 2026-11-10 ("approve"): box 1's labels go from 6 pt to 7.5 pt at panel size (x1.25), the
size of the poster's axis labels (poster_type.m), ~21 pt printed instead of ~17 pt. Same sources and the same
scale as build_panels.py; only the text changes.
- loop: JN Fig 1E's SVG. Every font-size attribute x1.25 (x1.1 inside the system box); each label keeps
  its text-anchor point (start / middle / end), so it grows away from the line it labels; four small nudges
  keep the larger words off their neighbours (see loop()). Panel letter dropped.
- rig: the light-path drawing (wfpath.pdf). Each label is set again at x1.25; it keeps the edge that faces
  the part it names (RIG_ANCHOR) and its vertical centre, and its lines spread with it.
- frame: the widefield image and its key (JN Fig 1B). Key text x1.25 from its left edge (the symbols sit to
  its left); the page widens on the right to hold it. poster_swap_all.py re-maps the three crops of this
  picture in the poster onto the new image.
Writes panels/poster/{loop,rig,frame}_raw.pdf.
"""
import sys
from pathlib import Path

import fitz
from lxml import etree

from build_panels import ARIAL, MM, PANELS, SVG_MM, embed_font, ink

HERE = Path(__file__).resolve().parent
OUT = HERE / 'panels' / 'poster'
K = 1.25
SVG = '{http://www.w3.org/2000/svg}'
# rig labels: the edge each keeps (the side facing the part it names)
RIG_ANCHOR = {'638 nm': 'right', 'galvos': 'left', '550 nm': 'left', '490 nm': 'left', 'camera': 'centre',
              'alternating LEDs': 'right', '0.63x': 'right', 'sample': 'centre'}


def loop():
    """Labels x1.25 except the two inside the 20 mm system box (x1.1: "(mouse cortex)" would be 21.6 mm);
    "Exogenous inputs" 1 mm left and "Parameters" 1.5 mm right so the larger words clear each other; "Error e"
    1 mm up and "Input u" 1.2 mm down so they clear the summing junctions; the view widened 4.5 mm left
    ("Reference r" ends at x = 12) and 3.5 mm right, still 1 unit = 1 mm."""
    src, scale = PANELS['loop']
    root = etree.parse(str(src)).getroot()
    k_text = {'System': 1.1, '(mouse cortex)': 1.1}
    dx = {'Exogenous': -1.0, 'inputs': -1.0, 'Parameters': 1.5}
    dy = {'Error': -1.0, 'e': -1.0, 'Input': 1.2, 'u': 1.2}             # clear the two summing junctions
    for t in list(root.iter(SVG + 'text')):
        s = ''.join(t.itertext()).strip()
        if s in tuple('ABCDE'):                                          # panel letter
            t.getparent().remove(t)
            continue
        fs = t.get('font-size')
        if fs:
            t.set('font-size', f'{float(fs.replace("px", "")) * k_text.get(s, K):.3f}px')
        if s in dx:
            t.set('x', f'{float(t.get("x")) + dx[s]:.3f}')
        if s in dy and t.get('text-anchor'):                             # skip the K_r subscript 'r' etc.
            t.set('y', f'{float(t.get("y")) + dy[s]:.3f}')
    x0, y0, w, h = (float(v) for v in root.get('viewBox').split())
    root.set('viewBox', f'{x0 - 4.5} {y0} {w + 8} {h}')
    root.set('width', f'{w + 8}mm')
    d = fitz.open(stream=etree.tostring(root), filetype='svg')
    return fitz.open('pdf', d.convert_to_pdf()), scale                  # 1 unit = 1 mm = JN's placed size


def reset_text(page, k, anchors=None):
    """Remove every text span and set it again at k x its size; fonts become embedded Arial (same metrics).
    anchors None: each line keeps its left edge and its own vertical centre (key text beside its symbol).
    anchors dict: blocks that touch vertically and overlap horizontally form one label; each label grows about
    its vertical centre and the edge named by anchors[first words] ('left', 'right' or 'centre'), so it grows
    away from the part it names. Returns the right-most x the new text reaches."""
    font = fitz.Font(fontfile=ARIAL)
    blocks = [b for b in page.get_text('dict')['blocks'] if b.get('lines')]
    groups = []
    for b in sorted(blocks, key=lambda b: b['bbox'][1]):
        x0, y0, x1, y1 = b['bbox']
        g = next((g for g in groups if abs(y0 - g['bbox'][3]) < 3 and x0 < g['bbox'][2] and x1 > g['bbox'][0]), None)
        if g is None:
            groups.append({'bbox': list(b['bbox']), 'blocks': [b]})
        else:
            g['blocks'].append(b)
            g['bbox'] = [min(g['bbox'][0], x0), min(g['bbox'][1], y0), max(g['bbox'][2], x1), max(g['bbox'][3], y1)]
    spans, right = [], page.rect.x0
    for g in groups:
        gx0, gy0, gx1, gy1 = g['bbox']
        lines = [ln for b in g['blocks'] for ln in b['lines']]
        if anchors is not None:
            key = ' '.join(sp['text'] for sp in lines[0]['spans']).strip()
            ax = {'left': gx0, 'right': gx1, 'centre': (gx0 + gx1) / 2}[anchors[key]]
            ay = (gy0 + gy1) / 2
        for ln in lines:
            lx0, ly0, lx1, ly1 = ln['bbox']
            for sp in ln['spans']:
                if not sp['text'].strip():
                    continue
                ox, oy = sp['origin']
                if anchors is None:
                    x, y = lx0 + (ox - lx0) * k, (ly0 + ly1) / 2 + (oy - (ly0 + ly1) / 2) * k
                else:
                    x, y = ax + (ox - ax) * k, ay + (oy - ay) * k
                size = sp['size'] * k
                right = max(right, x + font.text_length(sp['text'], fontsize=size))
                spans.append((fitz.Point(x, y), sp['text'], size, sp['color'], sp['bbox']))
    for *_, bb in spans:
        page.add_redact_annot(fitz.Rect(bb), fill=False, cross_out=False)
    page.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE, graphics=fitz.PDF_REDACT_LINE_ART_NONE,
                          text=fitz.PDF_REDACT_TEXT_REMOVE)
    for pt, text, size, color, _ in spans:
        rgb = tuple(((color >> sh) & 255) / 255 for sh in (16, 8, 0))
        page.insert_text(pt, text, fontname='ar', fontfile=ARIAL, fontsize=size, color=rgb)
    return right


def grow(page, margin):
    """More room round the page (text can then grow past the old edges and still be drawn)."""
    r = page.rect
    page.set_mediabox(fitz.Rect(r.x0 - margin, r.y0 - margin, r.x1 + margin, r.y1 + margin))


def rig():
    src, scale = PANELS['rig']
    s = fitz.open(str(src))
    reset_text(s[0], K, RIG_ANCHOR)
    grow(s[0], 40)                                # source text is ~21 pt here; ink() crops it back
    return s, scale


def frame():
    src, scale = PANELS['frame']
    s = fitz.open(str(src))
    embed_font(s[0])
    p = s[0]
    right = reset_text(p, K)
    if right + 2 > p.rect.x1:                     # widen the page on the right only, so the crops still map
        p.set_mediabox(fitz.Rect(p.rect.x0, p.rect.y0, right + 2, p.rect.y1))
    return s, scale


def save(name, s, scale, crop_to_ink=True):
    clip = ink(s[0]) if crop_to_ink else s[0].rect
    d = fitz.open()
    pg = d.new_page(width=clip.width * scale, height=clip.height * scale)
    pg.show_pdf_page(pg.rect, s, 0, clip=clip)
    d.save(str(OUT / f'{name}_raw.pdf'), garbage=3, deflate=True)
    print(f'{name:6s} {pg.rect.width / MM / 10:5.2f} x {pg.rect.height / MM / 10:5.2f} cm')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    save('loop', *loop())
    save('rig', *rig())
    save('frame', *frame(), crop_to_ink=False)    # the poster crops this picture three ways: keep the page
