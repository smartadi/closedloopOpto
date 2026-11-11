"""box1_diagram.py -- box 1 as one control diagram with the rig in it (SfN poster v6, 2026-11-10).

    python poster/sfn2026/box1_diagram.py

Aditya (2026-11-10): the rig drawing, the loop diagram and the separate widefield image showed the brain twice;
he picked "One loop, rig inside": one bold-lined loop in which the controller drives the 638 nm laser, the
galvos steer it onto the stimulation site on the widefield image, the camera (470/405 nm LEDs) reads the
readout site, and dF/F goes back to the controller. Same blocks, signs and symbols as JN Fig 1E (error
e = y - r: '-' on the reference, '+' on the feedback, as the inhibitory opsin needs). The image, the readout
square and the stimulation dot are JN Fig 1B's (panels/frame.pdf), placed unchanged; the 1 mm bar is
measured from that figure's own bar. Units: 1 = 1 mm at panel size; text 7.5 pt, the poster's label size.
Writes panels/poster/system_raw.pdf (+ png preview in panels/poster/png/).
"""
import sys
from pathlib import Path

import fitz

from build_panels import ARIAL

HERE = Path(__file__).resolve().parent
OUT = HERE / 'panels' / 'poster'
FRAME = HERE / 'panels' / 'frame.pdf'
W, H = 137.5, 57
FS = 7.5 * 25.4 / 72                 # 7.5 pt in mm
SUB = 0.75 * FS
LINE, BOX = 0.7, 0.5                 # stroke widths (mm); JN Fig 1E used 0.35 and 0.25
C = '#1d4f6b'                        # JN Fig 1E's loop colour
RED, GREEN, BLUE, VIOLET = '#ff5a40', '#2fbf3a', '#3fa9f5', '#9b59d0'
SANS = "Arial, Helvetica, sans-serif"
SERIF = "'Times New Roman', Times, serif"
font = fitz.Font(fontfile=ARIAL)
els = []


def text(x, y, s, anchor='start', size=FS, fill='#000', italic=False, weight='normal'):
    fam = SERIF if italic else SANS
    sty = ' font-style="italic"' if italic else ''
    els.append(f'<text x="{x:.2f}" y="{y:.2f}" font-family="{fam}" font-size="{size:.3f}" fill="{fill}"'
               f' text-anchor="{anchor}" font-weight="{weight}"{sty}>{s}</text>')


def width(s, size=FS):
    return font.text_length(s, fontsize=size)


def label(x, y, word, sym, anchor='middle', sub=None):
    """'Word' in Arial then an italic symbol (with optional subscript), centred or anchored as a unit."""
    gap = 0.25 * FS
    total = width(word + ' ') + 0.55 * FS * len(sym) + (0.5 * SUB * len(sub) if sub else 0)
    x0 = {'start': x, 'middle': x - total / 2, 'end': x - total}[anchor]
    text(x0, y, word)
    xs = x0 + width(word) + gap
    text(xs, y, sym, italic=True)
    if sub:
        text(xs + 0.5 * FS, y + 0.3 * FS, sub, italic=True, size=SUB)


def line(*pts, color=C, w=LINE, arrow=True, opacity=1.0):
    p = ' '.join(f'{x:.2f},{y:.2f}' for x, y in pts)
    els.append(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linejoin="round"'
               f' stroke-opacity="{opacity}"/>')
    if arrow:
        (x1, y1), (x2, y2) = pts[-2], pts[-1]
        L = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
        ux, uy = (x2 - x1) / L, (y2 - y1) / L
        a, b = 2.6, 1.15                          # arrowhead length and half-width
        bx, by = x2 - a * ux, y2 - a * uy
        els.append(f'<path d="M{x2:.2f},{y2:.2f} L{bx - b * uy:.2f},{by + b * ux:.2f} L{bx + b * uy:.2f},{by - b * ux:.2f} Z"'
                   f' fill="{color}" fill-opacity="{opacity}"/>')


def rect(x, y, w, h, fill='#fff', stroke=C, sw=BOX, rx=1.5):
    els.append(f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" rx="{rx}" fill="{fill}"'
               f' stroke="{stroke}" stroke-width="{sw}"/>')


def circle(x, y, r=3.0):
    els.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" stroke="{C}" stroke-width="{BOX}"/>')


def beam(pts, color, w=1.3):
    p = ' '.join(f'{x:.2f},{y:.2f}' for x, y in pts)
    els.append(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linejoin="round"'
               f' stroke-linecap="round" stroke-opacity="0.9"/>')


def image_geometry():
    """Image rect, stimulation dot centre and readout square centre (mm), and 1 mm in drawing units."""
    p = fitz.open(str(FRAME))[0]
    im = fitz.Rect(p.get_image_info()[0]['bbox'])
    dr = p.get_drawings()
    sq = next(d['rect'] for d in dr if d['type'] == 's' and d['rect'].x1 < im.x1)          # readout square
    dot = next(d['rect'] for d in dr if d['type'] == 'f' and d.get('fill') and d['fill'][0] > 0.8 and d['rect'].x1 < im.x1)
    bar = next(d['rect'] for d in dr if d['type'] == 's' and d['rect'].height < 0.01)       # 1 mm bar in the key
    return im, dot, sq, bar.width


def sym(x, y, base, sub):
    """Italic symbol with an italic subscript; returns the x where it ends."""
    text(x, y, base, italic=True)
    xs = x + 0.67 * FS
    text(xs, y + 0.3 * FS, sub, italic=True, size=SUB)
    return xs + 0.45 * SUB * len(sub)


def dark_block(x, y, w, h, word, nub=None):
    """Hardware: a dark block with its name in white; nub = 'right' adds a lens or aperture on that side."""
    rect(x, y, w, h, fill='#1a1a1a', stroke='#1a1a1a', rx=1.0)
    text(x + w / 2, y + h / 2 + 0.36 * FS, word, anchor='middle', fill='#fff')
    if nub == 'right':
        rect(x + w, y + h / 2 - 1.6, 1.6, 3.2, fill='#1a1a1a', stroke='#1a1a1a', rx=0.3)


def build():
    im, dot, sq, bar_pt = image_geometry()
    S = 30.0                                       # image side (mm)
    k = S / im.width
    IX, IY = 98.0, 21.5
    to = lambda r: (IX + (r.x0 + r.x1) / 2 * k, IY + (r.y0 + r.y1) / 2 * k)
    (dx, dy), (sx, sy) = to(dot), to(sq)
    yt, yf, yb = 6.0, 17.0, 49.5                   # feedforward, forward and feedback rows
    s1, s2 = 27.0, 78.0                            # summing junctions

    # reference, error, controller, feedforward
    label(1.0, yf - 1.6, 'Reference', 'r', anchor='start')
    line((1.0, yf), (s1 - 3.0, yf))
    els.append(f'<circle cx="19" cy="{yf}" r="0.75" fill="{C}"/>')
    line((19, yf), (19, yt), (s2, yt), (s2, yf - 3.0))
    els.append(f'<path d="M43,{yt - 4.0} L43,{yt + 4.0} L55,{yt} Z" fill="#fff" stroke="{C}" stroke-width="{BOX}"'
               f' stroke-linejoin="round"/>')
    sym(45.0, yt + 1.0, 'K', 'r')
    text(57.0, yt - 1.4, 'Feedforward')
    circle(s1, yf)
    text(s1 - 4.2, yf - 1.6, '−', anchor='middle')
    text(s1 + 3.8, yf + 5.6, '+', anchor='middle')
    label(36.0, yf - 1.6, 'Error', 'e')
    line((s1 + 3.0, yf), (44.0, yf))
    rect(44.0, yf - 6.0, 24.0, 12.0)
    text(56.0, yf - 0.6, 'PI controller', anchor='middle')
    e = sym(51.6, yf + 3.9, 'K', 'p')
    text(e + 0.2, yf + 3.9, ',')
    sym(e + 1.6, yf + 3.9, 'K', 'i')
    line((68.0, yf), (s2 - 3.0, yf))
    circle(s2, yf)
    text(s2 - 4.2, yf - 1.6, '+', anchor='middle')
    text(s2 + 3.4, yf - 3.6, '+', anchor='middle')

    # input -> laser -> galvos -> stimulation site
    line((s2 + 3.0, yf), (90.0, yf))
    label(84.6, yf + 6.0, 'Input', 'u')
    dark_block(90.0, yf - 3.5, 19.0, 7.0, '638 nm laser', nub='right')
    beam([(110.6, yf), (dx, yf), (dx, dy - 1.4)], RED)
    els.append(f'<line x1="{dx - 2.2:.2f}" y1="{yf - 2.2:.2f}" x2="{dx + 2.2:.2f}" y2="{yf + 2.2:.2f}" stroke="#111"'
               f' stroke-width="0.9" stroke-linecap="round"/>')
    text(dx + 3.0, yf - 0.8, 'galvos')

    # widefield image: placed in fitz below the drawing (see main); its scale bar and name
    bar = bar_pt * k
    xb = IX + S - 7.5
    els.append(f'<line x1="{xb - bar:.2f}" y1="{IY + S + 2.4:.2f}" x2="{xb:.2f}" y2="{IY + S + 2.4:.2f}"'
               f' stroke="#000" stroke-width="0.7"/>')
    text(xb + 1.0, IY + S + 2.4 + 0.36 * FS, '1 mm')
    text(IX + S + 1.2, IY + 3.0, 'mouse')
    text(IX + S + 1.2, IY + 3.0 + 1.15 * FS, 'cortex')

    # other inputs to the cortex
    for j, s in enumerate(['Exogenous inputs', 'Parameters']):
        y = IY + 5.0 + j * 6.0
        line((IX - 9.0, y), (IX - 0.4, y))
        text(IX - 10.0, y + 0.36 * FS, s, anchor='end')

    # LEDs light the cortex; the camera reads the readout site
    lx, ly = 72.0, 38.0
    dark_block(lx, ly, 13.0, 5.5, 'LEDs')
    text(lx - 1.2, ly + 2.75 + 0.36 * FS, '470/405 nm', anchor='end')
    beam([(lx + 13.0, ly + 1.7), (IX - 0.6, ly + 1.7)], BLUE, w=0.9)
    beam([(lx + 13.0, ly + 3.8), (IX - 0.6, ly + 3.8)], VIOLET, w=0.9)
    dark_block(72.0, yb - 3.5, 13.0, 7.0, 'camera', nub='right')
    beam([(sx - 1.0, sy + 1.0), (86.6, yb)], GREEN)

    # dF/F back to the controller
    line((72.0, yb), (61.0, yb))
    rect(47.0, yb - 4.5, 14.0, 9.0)
    text(54.0, yb + 0.36 * FS, 'ΔF/F', anchor='middle')
    line((47.0, yb), (s1, yb), (s1, yf + 3.0))
    label(37.0, yb - 1.6, 'Output', 'y')
    return (IX, IY, S), im


def main():
    (IX, IY, S), im = build()
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}mm" height="{H}mm" viewBox="0 0 {W} {H}">'
           + ''.join(els) + '</svg>')
    (OUT / 'system.svg').write_text(svg, encoding='utf-8')
    d = fitz.open('pdf', fitz.open(stream=svg.encode(), filetype='svg').convert_to_pdf())
    mm = 72 / 25.4
    out = fitz.open()
    pg = out.new_page(width=W * mm, height=H * mm)
    pg.show_pdf_page(fitz.Rect(IX, IY, IX + S, IY + S) * mm, fitz.open(str(FRAME)), 0, clip=im)
    pg.show_pdf_page(pg.rect, d, 0)
    out.save(str(OUT / 'system_raw.pdf'), garbage=3, deflate=True)
    (OUT / 'png').mkdir(exist_ok=True)
    pg.get_pixmap(dpi=400, alpha=False).save(str(OUT / 'png' / 'system_preview.png'))
    print(f'system  {W / 10:.1f} x {H / 10:.1f} cm')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
