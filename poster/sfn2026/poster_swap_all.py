"""poster_swap_all.py -- put every poster-type panel (2026-11-10) into the poster, each in its own slot.

    python poster/sfn2026/poster_swap_all.py <poster.pptx> <out.pptx> [name ...]

Reads panels/poster/<name>_raw.pdf, written by poster_restyle.m (saved paper figures, restyled),
unique_panel.m (st_unique), sine_panels.m (sine_*) and seedfc_panel.m (copied there as seedfc_raw.pdf).
Each is cropped to its ink at the one print scale (PS) and replaces picture 'panel <name>', centred where the
old one was. A panel that comes out up to 4% larger than its slot is scaled down to fit (type stays >= 20 pt);
more than that is an error. Box 5's panel is taller on purpose: it fills its box under the rule.
Box 1 (v5, box1_panels.py: labels x1.25): the rig drawing goes in at its true shape (v3 had it 10% too wide),
as tall as the old slot after the rig moved up 0.15 in; the loop diagram moves right to keep 0.3 in from it;
the widefield image and its two crops (key, scale bar) move down 0.12 in, each crop re-cut round the larger
key text so every marker stays where it was. The image no longer covers the rig's "sample" label.
Plot tops line up within a row (ALIGN): each panel moves up or down so the top of its y axis is level with
its reference panel's. Horizontal positions don't change.
Every other shape keeps its XML; main() asserts that.
"""
import copy
import sys
from pathlib import Path

import fitz
from lxml import etree
from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches

from build_panels import ink
from build_pptx import PS, PX_ZOOM

HERE = Path(__file__).resolve().parent
RAW, OUT = HERE / 'panels' / 'poster', HERE / 'panels' / 'poster'
E = 914400
NAMES = ['imp_traces', 'imp_dose', 'imp_fit', 'cl_trial', 'cl_avg', 'cl_rmse', 'cl_var', 'sine_avg', 'sine_lag',
         'sine_rmse', 'sine_var', 'seedfc', 'st_trials', 'st_unique', 'st_quart', 'd_kernel', 'd_agl', 'd_rr']
SHRINK = 0.96
# Box 2 is printed larger than PS (x1.398, nick_review.py), so its paper panels already read at 25 pt. For the
# lab axes (Aditya 2026-11-10) it takes JN Fig 2 A-C laid out by impulse-analysis/fig2_jn_panels.m with
# POSTER_BOX2 on (the paper layout, poster_lab_axes, B's mouse key off the data), at box 2's scale K2.
FIG2 = RAW / 'box2'
BOX2 = {'imp_traces': FIG2 / 'A.pdf', 'imp_dose': FIG2 / 'B.pdf', 'imp_fit': FIG2 / 'C.pdf'}
K2 = 1.398   # box 2's print scale relative to PS (nick_review.py): one scale for A-C, so their type matches
# panel -> the panel in its row whose plot top it lines up with (v5, approved by Aditya 2026-11-10: "approve")
ALIGN = {'d_rr': 'd_agl', 'sine_rmse': 'sine_lag', 'sine_var': 'sine_lag', 'imp_dose': 'imp_traces'}
OLD_FRAME = HERE / 'panels' / 'frame.pdf'   # the picture v3's three 'panel frame' crops cut from
GAP_RIG_LOOP = 0.3                          # in: keeps "dichroic" (rig) and "Reference r" (loop) apart


def axis_top(page, r):
    """Top of the plot below the ink top, in pt: the upper end of the left-most long vertical line inside the
    ink (the y axis; lab axes draw no box)."""
    best = None
    for dr in page.get_drawings():
        for it in dr['items']:
            if it[0] != 'l':
                continue
            a, b = it[1], it[2]
            top, bot = min(a.y, b.y), max(a.y, b.y)
            if abs(a.x - b.x) < 0.05 and bot - top > 0.25 * r.height and top > r.y0 + 0.5 and a.x > r.x0 + 1:
                if best is None or a.x < best[0] - 0.05:
                    best = (a.x, top)
                elif abs(a.x - best[0]) < 0.05:
                    best = (best[0], min(top, best[1]))
    return None if best is None else best[1] - r.y0


def render(name, crop_to_ink=True):
    """PNG of the panel cropped to its ink; returns its size at PS (in) and its plot top below the ink top (in)."""
    d = fitz.open(str(BOX2.get(name, RAW / f'{name}_raw.pdf')))
    r = ink(d[0]) if crop_to_ink else d[0].rect
    top = axis_top(d[0], r)
    n = fitz.open()
    q = n.new_page(width=r.width, height=r.height)
    q.show_pdf_page(q.rect, d, 0, clip=r)
    n.save(str(OUT / f'{name}.pdf'), garbage=3, deflate=True)
    (OUT / 'png').mkdir(exist_ok=True)
    n[0].get_pixmap(matrix=fitz.Matrix(PX_ZOOM, PX_ZOOM), alpha=False).save(str(OUT / 'png' / f'{name}.png'))
    return r.width / 72 * PS, r.height / 72 * PS, None if top is None else top / 72 * PS


def frame_of(sl, old):
    return next(sh for sh in sl.shapes if sh.name.startswith('box ') and sh.name.endswith(' frame')
                and sh.left <= old.left and sh.top <= old.top
                and old.left + old.width <= sh.left + sh.width and old.top + old.height <= sh.top + sh.height)


def swap(sl, name, placed):
    old = next(sh for sh in sl.shapes if sh.name == f'panel {name}')
    fr = frame_of(sl, old)
    fx, fy, fw, fh = (v / E for v in (fr.left, fr.top, fr.width, fr.height))
    ow, oh = old.width / E, old.height / E
    pw, ph, top = render(name)
    if name == 'seedfc':                       # fills box 5 under its rule, centred across the frame
        rule = next(sh for sh in sl.shapes if sh.name == 'box 5 rule')
        top, bot = (rule.top + rule.height) / E, fy + fh
        k = min(1, (bot - top - 0.2) / ph, (fw - 0.3) / pw)
        pw, ph = pw * k, ph * k
        x, y = fx + (fw - pw) / 2, top + (bot - top - ph) / 2
    elif name in BOX2:                         # box 2's own scale, same centre as the old panel
        k = K2
        pw, ph = pw * k, ph * k
        x, y = (old.left + old.width / 2) / E - pw / 2, (old.top + old.height / 2) / E - ph / 2
    else:
        k = min(1, oh / ph, (ow + 0.3) / pw)  # no taller than the old panel, at most 0.3 in wider
        assert k >= SHRINK, f'{name}: {pw:.2f} x {ph:.2f} in needs x{k:.3f} to fit {ow:.2f} x {oh:.2f}'
        pw, ph = pw * k, ph * k
        x, y = (old.left + old.width / 2) / E - pw / 2, (old.top + old.height / 2) / E - ph / 2
    assert fx + 0.08 <= x and x + pw <= fx + fw - 0.08 and fy <= y and y + ph <= fy + fh, f'{name} leaves {fr.name}'
    pic = sl.shapes.add_picture(str(OUT / 'png' / f'{name}.png'), Inches(x), Inches(y), Inches(pw), Inches(ph))
    pic.name = old.name
    pic._element.nvPicPr.cNvPr.set('descr', old._element.nvPicPr.cNvPr.get('descr', ''))
    old._element.addprevious(pic._element)
    rid = old._element.blip_rId
    old._element.getparent().remove(old._element)
    sl.part.drop_rel(rid)
    placed[name] = (pic, fr, None if top is None else y + top * k)
    print(f'{name:10s} {ow:5.2f} x {oh:4.2f} -> {pw:5.2f} x {ph:4.2f} in (x{k:.3f}) in {fr.name}')
    return old.shape_id


def align(placed):
    """Move each ALIGN panel up or down so its plot top is level with its reference panel's."""
    for name, ref in ALIGN.items():
        if name not in placed or ref not in placed:
            continue
        pic, fr, top = placed[name]
        dy = placed[ref][2] - top
        pic.top = Emu(pic.top + round(dy * E))
        assert fr.top <= pic.top and pic.top + pic.height <= fr.top + fr.height, f'{name} leaves {fr.name}'
        print(f'{name:10s} plot top level with {ref}: moved {dy:+.3f} in')


def set_image(sl, pic, png):
    """Point the picture at a new image; returns the old relationship id."""
    _, rid = sl.part.get_or_add_image_part(str(png))
    old = pic._element.blip_rId
    pic._element.blipFill.find(qn('a:blip')).set(qn('r:embed'), rid)
    return old


def key_lines(page):
    """Glyph box of each text line on the widefield-image key: Arial ascender 0.73 em, descender 0.21 em."""
    out = []
    for b in page.get_text('dict')['blocks']:
        for ln in b.get('lines', []):
            sp = ln['spans'][0]
            x, y = sp['origin']
            out.append((x, y - 0.73 * sp['size'], ln['bbox'][2], y + 0.21 * sp['size']))
    return sorted(out, key=lambda v: v[1])


def box1(sl):
    """Box 1 at poster type: rig, loop and the widefield image with its key; returns the ids changed."""
    sh = {n: [x for x in sl.shapes if x.name == n] for n in ('panel rig', 'panel loop', 'panel frame')}
    rig, loop, frames = sh['panel rig'][0], sh['panel loop'][0], sh['panel frame']
    assert len(frames) == 3
    f1 = next(x for x in sl.shapes if x.name == 'box 1 frame')
    rule = next(x for x in sl.shapes if x.name == 'box 1 rule')
    fx, fw = f1.left / E, f1.width / E
    old_rel = set()

    # widefield image, key and scale bar: three crops of one picture, now the page of frame_raw.pdf
    po, pn = fitz.open(str(OLD_FRAME))[0], fitz.open(str(RAW / 'frame_raw.pdf'))[0]
    lo, ln_ = key_lines(po), key_lines(pn)
    assert len(lo) == len(ln_) == 3 and all(abs(a[0] - b[0]) < 0.01 for a, b in zip(lo, ln_)), 'key lines moved'
    cut = (ln_[1][3] + ln_[2][1]) / 2                     # between "Stimulation" and "1 mm"
    W0, H0, W1, H1 = po.rect.width, po.rect.height, pn.rect.width, pn.rect.height
    render('frame', crop_to_ink=False)
    for f in frames:
        sr = f._element.blipFill.find(qn('a:srcRect'))
        l, t, r, b = (int(sr.get(a, 0)) / 1e5 for a in 'ltrb')
        x0, y0, x1, y1 = W0 * l, H0 * t, W0 * (1 - r), H0 * (1 - b)   # the crop in pt
        s = f.width / E / (x1 - x0)                                    # in per pt, kept
        if x1 < lo[0][0]:                                              # the image: same crop
            n0, m0, n1, m1 = x0, y0, x1, y1
        elif y0 < lo[0][1]:                                            # key: output and stimulation lines
            n0, m0, n1, m1 = x0, min(y0, ln_[0][1] - 1), max(x1, ln_[0][2] + 2), cut
        else:                                                          # scale bar and "1 mm"
            n0, m0, n1, m1 = x0, cut, max(x1, ln_[2][2] + 2), max(y1, ln_[2][3] + 1)
        old_rel.add(set_image(sl, f, OUT / 'png' / 'frame.png'))
        for a, v in zip('ltrb', (n0 / W1, m0 / H1, 1 - n1 / W1, 1 - m1 / H1)):
            sr.set(a, str(round(v * 1e5)))
        f.left = Emu(f.left + round((n0 - x0) * s * E))
        f.top = Emu(f.top + round(((m0 - y0) * s + 0.12) * E))
        f.width, f.height = Emu(round((n1 - n0) * s * E)), Emu(round((m1 - m0) * s * E))
    img = next(f for f in frames if f.height == max(g.height for g in frames))

    # rig: true shape, from just under the rule to just above the image
    pw, ph, _ = render('rig')
    top = (rule.top + rule.height) / E + 0.09
    h = img.top / E - 0.05 - top
    k_rig = h / ph
    old_rel.add(set_image(sl, rig, OUT / 'png' / 'rig.png'))
    rig.top, rig.height, rig.width = Emu(round(top * E)), Emu(round(h * E)), Emu(round(pw * k_rig * E))

    # loop: GAP_RIG_LOOP right of the rig, as wide as the frame allows (at most PS)
    pw, ph, _ = render('loop')
    x = max(loop.left / E, (rig.left + rig.width) / E + GAP_RIG_LOOP)
    k_loop = min(1, (fx + fw - 0.08 - x) / pw)
    assert k_loop >= SHRINK, f'loop needs x{k_loop:.3f}'
    old_rel.add(set_image(sl, loop, OUT / 'png' / 'loop.png'))
    loop.left, loop.width, loop.height = Emu(round(x * E)), Emu(round(pw * k_loop * E)), Emu(round(ph * k_loop * E))

    for rid in old_rel:
        sl.part.drop_rel(rid)
    assert max(f.top + f.height for f in frames) <= f1.top + f1.height, 'image leaves box 1'
    for f in (rig, loop, *frames):
        assert f1.left <= f.left and f.left + f.width <= f1.left + f1.width, f'{f.name} leaves box 1'
    print(f'box 1: rig x{k_rig:.3f} ({rig.width / E:.2f} x {h:.2f} in), loop x{k_loop:.3f} at x = {x:.2f} in, '
          f'rig bottom {(rig.top + rig.height) / E:.2f}, image top {img.top / E:.2f} in')
    return {rig.shape_id, loop.shape_id, *(f.shape_id for f in frames)}


def main(src, out, names):
    prs = Presentation(src)
    sl = prs.slides[0]
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)
    before = {sh.shape_id: c14n(sh._element) for sh in sl.shapes}
    placed = {}
    gone = {swap(sl, n, placed) for n in names}
    align(placed)
    moved = box1(sl)
    now = {sh.shape_id: sh for sh in sl.shapes}
    assert not gone & set(now) and len(now) == len(before)
    for sid, x in before.items():
        if sid not in gone and sid not in moved:
            assert c14n(now[sid]._element) == x, now[sid].name
    prs.save(out)
    print(f'{out}: {len(now)} shapes, {len(gone)} panels swapped, {len(moved)} moved')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2], sys.argv[3:] or NAMES)
