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
v7 (Aditya 2026-11-10: "lets move the camera below the brain image so that the camera line is not inclined"):
the camera sits under the image, its lens up, and the green readout beam runs straight down from the readout
square. Its signal goes left under the LEDs and up to the feedback row, so every wire is horizontal or vertical
and the space under the dF/F box stays free: poster_swap_all.py puts box 1's bullets there, beside the camera.
The 1 mm bar moves to the right of the image. system_raw.json gives that free corner (mm).
Then (Aditya 2026-11-10: "Move the exogenous inputs and parameters to the right, move the leds to the bottom
next to the camera or in the same block to keep widefield architerure true"): exogenous inputs and parameters
enter the cortex from the right; the LEDs sit beside the camera under the image, their 470/405 nm light going
up into the cortex along the camera's path. The image moves 6 mm left (IX 98 -> 92) to make room on the right.
Then (Aditya 2026-11-10: "the camera green with an arrow from brain towards camera, the leds blue and violet
from camera to brain arrow direction, but they dont all go to the primary spot they go from cmaera/led block to
the boundary of brain image showing that this is captureing entire brain"): the green, blue and violet beams run
between the image's lower edge and the camera/LED unit (now centred under the image), with arrowheads: green
down into the camera, blue and violet up into the cortex. The readout square and stimulation dot stay on the image.
"""
import json
import sys
from pathlib import Path

import fitz

from build_panels import ARIAL

HERE = Path(__file__).resolve().parent
OUT = HERE / 'panels' / 'poster'
FRAME = HERE / 'panels' / 'frame.pdf'
W, H = 137.5, 70.0                   # H: the LEDs' label + 1 mm (v7; was 57)
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


def beam(pts, color, w=1.3, arrow=False):
    """A light path; arrow=True ends it in an arrowhead of its own colour (the line stops at the head's base)."""
    if arrow:
        (x1, y1), (x2, y2) = pts[-2], pts[-1]
        L = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
        ux, uy = (x2 - x1) / L, (y2 - y1) / L
        a, b = 2.4, max(1.15, 1.1 * w)
        bx, by = x2 - a * ux, y2 - a * uy
        els.append(f'<path d="M{x2:.2f},{y2:.2f} L{bx - b * uy:.2f},{by + b * ux:.2f} L{bx + b * uy:.2f},{by - b * ux:.2f} Z"'
                   f' fill="{color}" fill-opacity="0.9"/>')
        pts = pts[:-1] + [(bx + 0.3 * ux, by + 0.3 * uy)]
    p = ' '.join(f'{x:.2f},{y:.2f}' for x, y in pts)
    cap = 'butt' if arrow else 'round'
    els.append(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linejoin="round"'
               f' stroke-linecap="{cap}" stroke-opacity="0.9"/>')


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
    elif nub == 'top':
        rect(x + w / 2 - 1.6, y - 1.6, 3.2, 1.6, fill='#1a1a1a', stroke='#1a1a1a', rx=0.3)


def build():
    im, dot, sq, bar_pt = image_geometry()
    S = 30.0                                       # image side (mm)
    k = S / im.width
    IX, IY = 92.0, 21.5
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
    xl = 87.0                                      # laser 3 mm left of v6 so the galvos clear it (image moved left)
    line((s2 + 3.0, yf), (xl, yf))
    label(84.0, yf + 6.0, 'Input', 'u')
    dark_block(xl, yf - 3.5, 19.0, 7.0, '638 nm laser', nub='right')
    assert dx - 2.2 > xl + 19.0 + 1.6 + 0.8, 'galvo mirror touches the laser'
    beam([(xl + 20.6, yf), (dx, yf), (dx, dy - 1.4)], RED)
    els.append(f'<line x1="{dx - 2.2:.2f}" y1="{yf - 2.2:.2f}" x2="{dx + 2.2:.2f}" y2="{yf + 2.2:.2f}" stroke="#111"'
               f' stroke-width="0.9" stroke-linecap="round"/>')
    text(dx + 3.0, yf - 0.8, 'galvos')

    # widefield image: placed in fitz below the drawing (see main); its scale bar (right of it, v7) and name
    bar = bar_pt * k
    xb, ybar = IX + S + 1.2, IY + S - 2.6
    els.append(f'<line x1="{xb:.2f}" y1="{ybar:.2f}" x2="{xb + bar:.2f}" y2="{ybar:.2f}"'
               f' stroke="#000" stroke-width="0.7"/>')
    text(xb, ybar + 1.15 * FS, '1 mm')
    text(IX + S + 1.2, IY + 3.0, 'mouse')
    text(IX + S + 1.2, IY + 3.0 + 1.15 * FS, 'cortex')

    # other inputs to the cortex, from the right; each name above its arrow, right-aligned at the edge
    for names, y in ((['Exogenous', 'inputs'], IY + 14.0), (['Parameters'], IY + 22.0)):
        line((W - 0.6, y), (IX + S + 0.4, y))
        for i, nm in enumerate(reversed(names)):
            text(W - 0.6, y - 1.2 - i * 1.15 * FS, nm, anchor='end')
        assert W - 0.6 - width(max(names, key=width)) > IX + S + 0.5, f'{names} reaches the image'

    # camera and LEDs as one unit centred under the image (widefield epi-illumination): the LEDs' blue and
    # violet light goes up to the image's edge, the green emission comes down from it into the camera. The
    # beams stop at the edge, not at the readout square: the camera images the whole cortex.
    cw, ch, lw, gap = 11.0, 7.0, 12.0, 0.6
    cx0, cy0 = IX + (S - cw - gap - lw) / 2, IY + S + 7.0
    dark_block(cx0, cy0, cw, ch, 'camera', nub='top')
    xc, edge = cx0 + cw / 2, IY + S
    beam([(xc, edge), (xc, cy0 - 1.6)], GREEN, arrow=True)
    lx0 = cx0 + cw + gap
    dark_block(lx0, cy0, lw, ch, 'LEDs')
    text(lx0 + lw / 2, cy0 + ch + 1.15 * FS, '470/405 nm', anchor='middle')
    for j, col in enumerate((BLUE, VIOLET)):
        xl = lx0 + lw / 2 - 1.3 + 2.6 * j
        beam([(xl, cy0), (xl, edge)], col, w=0.9, arrow=True)
    assert cy0 + ch + 1.15 * FS + 1.0 <= H, f'LED label ends at {cy0 + ch + 1.15 * FS:.1f} mm'

    # dF/F back to the controller: left from the camera, up at xv, along the feedback row
    xv = 88.0
    line((cx0, cy0 + ch / 2), (xv, cy0 + ch / 2), (xv, yb), (61.0, yb))
    rect(47.0, yb - 4.5, 14.0, 9.0)
    text(54.0, yb + 0.36 * FS, 'ΔF/F', anchor='middle')
    line((47.0, yb), (s1, yb), (s1, yf + 3.0))
    label(37.0, yb - 1.6, 'Output', 'y')
    free = {'left_bottom_mm': yb + 4.5, 'left_right_mm': xv - 1.5, 'W_mm': W, 'H_mm': H}
    return (IX, IY, S), im, free


def main():
    (IX, IY, S), im, free = build()
    (OUT / 'system_raw.json').write_text(json.dumps(free), encoding='utf-8')
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
