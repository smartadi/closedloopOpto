"""fig1_nc_build.py -- Nature Comms Figure 1 from Anna's redrawn schematics (2026-10-29) + the final panels.

    python paper-writing/fig1_nc_build.py

Inputs (local, git-ignored):
  paper/from_anna_2026-10-29/files (1)/panel_{D_architecture,E_control_loop}.svg   (Anna's Claude chat)
  paper/figures_final/panels/figure1/{wfpath, schematic_optoephyswf (1),
                                       svd_frame_AL_0039_2025-04-19, latency_histogram}.pdf
Outputs (paper/figures_final/nc/fig1/):
  panel_b_frame.pdf                                     frame + readout/stimulation markers, legend, 1 mm bar
  panel_d_architecture.svg, panel_e_control_loop.svg   editable, for the Illustrator assembly
  Figure1_nc_draft.pdf / .png                           180 x 120 mm composition (preview of that assembly)

Layout (2026-10-29, Aditya): the mouse schematic (old b) is dropped, so the frame carries the marker
definitions it used to give. a optics, b frame, c latency, d pipeline, e control loop.

Fixes applied to Anna's SVGs (REVIEW_ANNA_2026-10-29.md, Figure 1):
  * E summing junction back to e = y - r (methods.tex eq:error; light only lowers activity). Her chat
    had flipped it to r - y.
  * All text 7 pt (labels and variables), 5.5 pt subscripts, 8 pt bold lowercase panel letters: the top
    of the Nature figure guide's 5-7 pt range, at Aditya's ask for larger text. Connectors 0.35 mm (1 pt).
  * D trigger trace drawn to scale: blue exposures every 28.6 ms (blue/violet alternate at 70 Hz),
    14 ms exposure, laser update 24 ms after exposure start (median; methods.tex L66, L101), 10 ms bar.
  * E widefield placeholder replaced by the real SVD frame (panel b source).
Panels a and c are placed so their text lands at 7 pt too; c's labels/ticks still need the F1.5 replot.
"""
import base64
import re
from pathlib import Path

import fitz
from lxml import etree

ROOT = Path(__file__).resolve().parents[1]
ANNA = ROOT / 'paper' / 'from_anna_2026-10-29' / 'files (1)'
PAN = ROOT / 'paper' / 'figures_final' / 'panels' / 'figure1'
OUT = ROOT / 'paper' / 'figures_final' / 'nc' / 'fig1'
SVG = '{http://www.w3.org/2000/svg}'
MM = 72 / 25.4

SIZES = {'font-size:2.29px': 'font-size:2.469px',    # labels 6.5 -> 7 pt
         'font-size:2.82px': 'font-size:2.469px',    # variables 8 -> 7 pt
         'font-size:3.53px': 'font-size:2.822px',    # panel letters 10 -> 8 pt
         'font-size:1.9176px': 'font-size:1.940px'}  # subscripts 5.4 -> 5.5 pt
LINE = 0.35                                          # connector width, mm (= 1 pt); Anna's was 0.25

# Panel b markers, in the 560 x 560 native frame (row, col). The frame and the stim-site map share
# that orientation (brain-mask correlation 0.74 as is, 0.04 transposed).
READOUT_RC = (320, 380)   # d.params.pixel = [380 320] (x, y): the rig's 10 x 10 px kernel (methods.tex L103)
LASER_RC = (291, 405)     # measured laser dip, controller-analysis/data/cp_stim_site_ctrl_AL_0039_0419_e1.mat
FIELD_MM = 560 * 0.0173   # 9.69 mm field (methods.tex L66)
BLUE, RED = (0.2, 0.6, 1.0), (0.89, 0.19, 0.17)


def restyle(root, letter):
    for st in root.iter(SVG + 'style'):
        for a, b in SIZES.items():
            st.text = st.text.replace(a, b)
        st.text = st.text.replace('stroke-width:0.25', f'stroke-width:{LINE}')
    for t in root.iter(SVG + 'text'):
        s = t.get('style')
        if s:
            for a, b in SIZES.items():
                s = s.replace(a, b)
            t.set('style', s)
        if t.get('class') == 'p':
            t.text = letter


def inline_css(root):
    """Move the <style> rules onto each element as presentation attributes and drop <style>.
    MuPDF's SVG reader ignores <style>, and presentation attributes open the same everywhere."""
    rules = {}
    for st in list(root.iter(SVG + 'style')):
        for sel, body in re.findall(r'([^{}]+)\{([^}]*)\}', st.text):
            props = dict(kv.split(':', 1) for kv in body.split(';') if ':' in kv)
            for s in sel.split(','):
                rules.setdefault(s.strip(), {}).update({k.strip(): v.strip() for k, v in props.items()})
        st.getparent().remove(st)
    for e in root.iter():
        if not isinstance(e.tag, str):
            continue
        tag = e.tag.replace(SVG, '')
        props = dict(rules.get(tag, {}))
        for c in (e.get('class') or '').split():
            props.update(rules.get('.' + c, {}))
        if e.get('style'):
            props.update({k.strip(): v.strip() for k, v in
                          (kv.split(':', 1) for kv in e.get('style').split(';') if ':' in kv)})
            del e.attrib['style']
        for k, v in props.items():
            if k not in e.attrib:
                e.set(k, v)
    explicit_arrows(root)


def explicit_arrows(root, length=2.0, half=0.85, colour='#1d4f6b'):
    """Replace marker-end arrowheads with drawn triangles (tip on the line end, as refX=10 does).
    MuPDF drops SVG markers, and Illustrator imports them unreliably. The line stops inside the head
    so its 1 pt butt end does not poke past the tip; short last segments get a smaller head."""
    for e in list(root.iter(SVG + 'polyline')):
        if not (e.get('marker-end') or '').startswith('url('):
            continue
        xy = [tuple(map(float, p.split(','))) for p in e.get('points').split()]
        (x1, y1), (x2, y2) = xy[-2], xy[-1]
        L = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
        dx, dy = (x2 - x1) / L, (y2 - y1) / L
        k = min(1.0, 0.8 * L / length)
        length, half = length * k, half * k
        bx, by = x2 - length * dx, y2 - length * dy
        xy[-1] = (x2 - 0.6 * length * dx, y2 - 0.6 * length * dy)
        e.set('points', ' '.join(f'{x:.3f},{y:.3f}' for x, y in xy))
        d = f'M{x2:.3f},{y2:.3f} L{bx - half * dy:.3f},{by + half * dx:.3f} L{bx + half * dy:.3f},{by - half * dx:.3f} Z'
        e.addnext(etree.Element(SVG + 'path', {'d': d, 'fill': colour}))
        del e.attrib['marker-end']


def find_text(root, x, y, text):
    hits = [t for t in root.iter(SVG + 'text') if t.get('x') == x and t.get('y') == y and t.text == text]
    assert len(hits) == 1, f'expected one <text x={x} y={y}>{text}</text>, found {len(hits)}'
    return hits[0]


def el(parent, tag, text=None, **attrs):
    e = etree.SubElement(parent, SVG + tag, {k.replace('_', '-'): str(v) for k, v in attrs.items()})
    if text is not None:
        e.text = text
    return e


def fix_e(frame_png):
    tree = etree.parse(str(ANNA / 'panel_E_control_loop.svg'))
    root = tree.getroot()
    restyle(root, 'e')
    find_text(root, '24', '26.4', '+').text = '−'     # reference enters with minus
    find_text(root, '31.6', '33.4', '−').text = '+'   # measured output enters with plus
    for x, s in (('89.478', 'Input'), ('90.178', 'u')):  # at 7 pt "Input" ran into the feedforward "+"
        find_text(root, x, '26.4', s).set('y', '31.4')
    img = [i for i in root.iter(SVG + 'image') if i.get('id') == 'widefield_image_REPLACE']
    assert len(img) == 1
    img[0].set('id', 'widefield_image')
    img[0].set('href', 'data:image/png;base64,' + base64.b64encode(frame_png).decode())
    inline_css(root)
    return tree


def fix_d():
    tree = etree.parse(str(ANNA / 'panel_D_architecture.svg'))
    root = tree.getroot()
    restyle(root, 'd')
    drop_lines = ('12.5,55 ', '23,52.2 ', '45.5,41.4 ', '23,56.6 ')
    for p in list(root.iter(SVG + 'polyline')):
        if p.get('points').startswith(drop_lines):
            root.remove(p)
    for t in list(root.iter(SVG + 'text')):
        if t.text in ('Exposure', 'trigger', 'Latency'):
            root.remove(t)
    # to scale: 0.7 mm per ms; blue exposure starts at x = 22 and 42 (28.6 ms apart), 14 ms long
    s, t0, period, expo, lat = 0.7, 22.0, 28.57, 14.0, 24.0
    e1, e2 = t0, t0 + period * s
    pts = [(12.5, 55), (e1, 55), (e1, 52.5), (e1 + expo * s, 52.5), (e1 + expo * s, 55),
           (e2, 55), (e2, 52.5), (e2 + expo * s, 52.5), (e2 + expo * s, 55), (56.7, 55)]
    el(root, 'polyline', points=' '.join(f'{x:.2f},{y}' for x, y in pts), **{'class': 'l'})
    for i, w in enumerate(('Blue', 'exposure', 'trigger')):
        el(root, 'text', w, x=0, y=50.9 + 2.9 * i, text_anchor='start')
    xl = t0 + lat * s                                        # laser update, 24 ms after exposure start
    el(root, 'polyline', points=f'{t0},52.2 {t0},40.5', **{'class': 'ar'})
    el(root, 'polyline', points=f'46.25,41.4 46.25,47.5 {xl:.2f},47.5 {xl:.2f},54.7', **{'class': 'ar'})
    el(root, 'text', 'Laser update', x=f'{xl + 0.8:.2f}', y=50.6, text_anchor='start')
    el(root, 'polyline', points=f'{t0},56.4 {t0},57.6 {xl:.2f},57.6 {xl:.2f},56.4', **{'class': 'l'})
    el(root, 'text', 'Latency, 24 ms median', x=f'{(t0 + xl) / 2:.2f}', y=60.6, text_anchor='middle')
    el(root, 'line', x1=46.7, y1=57.6, x2=46.7 + 10 * s, y2=57.6, stroke='#000', stroke_width=0.35)
    el(root, 'text', '10 ms', x=f'{46.7 + 5 * s:.2f}', y=60.6, text_anchor='middle')
    inline_css(root)
    return tree


def content_clip(page):
    bb = fitz.Rect()
    for d in page.get_drawings():
        bb |= d['rect']
    for b in page.get_text('dict')['blocks']:
        bb |= fitz.Rect(b['bbox'])
    for im in page.get_image_info():
        bb |= fitz.Rect(im['bbox'])
    return bb & page.rect


def place(page, src_pdf, x, y, w=None, h=None, clip=True, scale=None):
    """Fit into the box (x, y, w, h), or at a fixed scale with its top-left corner at (x, y). mm."""
    src = fitz.open(src_pdf) if isinstance(src_pdf, (str, Path)) else src_pdf
    c = content_clip(src[0]) if clip else src[0].rect
    if scale:
        w, h = c.width * scale / MM, c.height * scale / MM
    page.show_pdf_page(fitz.Rect(x * MM, y * MM, (x + w) * MM, (y + h) * MM), src, 0, clip=c)
    return w, h


def text(page, x, y, s, size=7, anchor='start'):
    if anchor == 'end':
        x -= fitz.get_text_length(s, 'helv', size) / MM
    page.insert_text(fitz.Point(x * MM, y * MM), s, fontname='helv', fontsize=size)


def frame_panel(w=46):
    """Panel b: the frame with the readout kernel (blue box) and stimulation spot (red dot), their
    legend (the dropped mouse schematic used to define them) and a 1 mm bar. Markers not to scale:
    the kernel is 10 px = 0.17 mm, a 0.8 mm-wide square here."""
    src = fitz.open(PAN / 'svd_frame_AL_0039_2025-04-19.pdf')
    img = fitz.Rect(src[0].get_image_info()[0]['bbox'])
    hf = w * img.height / img.width
    doc = fitz.open()
    page = doc.new_page(width=w * MM, height=(hf + 8.4) * MM)
    page.show_pdf_page(fitz.Rect(0, 0, w * MM, hf * MM), src, 0, clip=img)

    def px(r, c):
        return fitz.Point((c - 0.5) / 560 * w * MM, (r - 0.5) / 560 * hf * MM)

    def square(p, s):
        page.draw_rect(fitz.Rect(p.x - s, p.y - s, p.x + s, p.y + s), color=BLUE, width=LINE * MM)

    def dot(p):
        page.draw_circle(p, 0.6 * MM, color=None, fill=RED)

    square(px(*READOUT_RC), 0.8 * MM)
    dot(px(*LASER_RC))
    y1, y2 = hf + 3.6, hf + 7.2                       # legend baselines; symbols centred on x-height
    square(fitz.Point(1.1 * MM, (y1 - 0.9) * MM), 0.8 * MM)
    text(page, 3.0, y1, 'Output (readout kernel)')
    dot(fitz.Point(1.1 * MM, (y2 - 0.9) * MM))
    text(page, 3.0, y2, 'Stimulation')
    bar = w / FIELD_MM                                # 1 mm of cortex
    page.draw_line(fitz.Point((w - 0.3 - bar) * MM, (y2 - 0.9) * MM), fitz.Point((w - 0.3) * MM, (y2 - 0.9) * MM),
                   color=(0, 0, 0), width=0.5 * MM)
    text(page, w - 1.3 - bar, y2, '1 mm', anchor='end')
    return doc


def svg_to_pdf(path):
    d = fitz.open(str(path))
    return fitz.open('pdf', d.convert_to_pdf())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frame = fitz.open(PAN / 'svd_frame_AL_0039_2025-04-19.pdf')
    frame_png = frame[0].get_pixmap(dpi=600).tobytes('png')
    fix_e(frame_png).write(str(OUT / 'panel_e_control_loop.svg'), xml_declaration=True, encoding='utf-8')
    fix_d().write(str(OUT / 'panel_d_architecture.svg'), xml_declaration=True, encoding='utf-8')

    fb = frame_panel()
    fb.save(str(OUT / 'panel_b_frame.pdf'))

    doc = fitz.open()
    page = doc.new_page(width=180 * MM, height=120 * MM)
    place(page, PAN / 'wfpath.pdf', 4, 1, scale=7 / 20.95)            # source text 20.95 pt -> 7 pt
    _, hb = place(page, fb, 64, 1, clip=False, scale=1)
    place(page, PAN / 'latency_histogram.pdf', 124, 1, clip=False, scale=1)   # source text 7 pt
    y2 = 1 + hb + 2
    place(page, svg_to_pdf(OUT / 'panel_d_architecture.svg'), 0, y2, 57, 62, clip=False)
    place(page, svg_to_pdf(OUT / 'panel_e_control_loop.svg'), 62, y2, 118, 62, clip=False)
    for letter, x in (('a', 0), ('b', 60), ('c', 120)):
        page.insert_text(fitz.Point(x * MM, 3.3 * MM), letter, fontname='hebo', fontsize=8)
    doc.save(str(OUT / 'Figure1_nc_draft.pdf'))
    page.get_pixmap(dpi=300).save(str(OUT / 'Figure1_nc_draft.png'))
    print('wrote', *sorted(p.name for p in OUT.iterdir()))


if __name__ == '__main__':
    main()
