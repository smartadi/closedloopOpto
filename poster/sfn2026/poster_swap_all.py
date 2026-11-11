"""poster_swap_all.py -- put every poster-type panel (2026-11-10) into the poster, each in its own slot.

    python poster/sfn2026/poster_swap_all.py <poster.pptx> <out.pptx> [name ...]

Reads panels/poster/<name>_raw.pdf, written by poster_restyle.m (saved paper figures, restyled),
unique_panel.m (st_unique), sine_panels.m (sine_*) and seedfc_panel.m (copied there as seedfc_raw.pdf).
Each is cropped to its ink at the one print scale (PS) and replaces picture 'panel <name>', centred where the
old one was. A panel that comes out up to 4% larger than its slot is scaled down to fit (type stays >= 20 pt);
more than that is an error. Box 5's panel is taller on purpose: it fills its box under the rule.
Box 1 (v6, box1_diagram.py): the rig drawing, the loop diagram and the three crops of the widefield image
(image, key, scale bar) give way to one picture, 'panel system', the control diagram with the rig in it,
under the rule and centred across the box at PS (or up to 4% smaller to fit). The box's bullets move under it,
their markers 0.20 in inside the box as in the other boxes. (v5's box1_panels.py layout is in git, b7cf639.)
Plot tops line up within a row (ALIGN): each panel moves up or down so the top of its y axis is level with
its reference panel's. Horizontal positions don't change.
Every other shape keeps its XML; main() asserts that.
"""
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
# v6: box 8's kernel map gained a key under it, so it may be as tall as its row (d_agl's slot) and its title
# lines up with d_agl's (both panels start with their title, so the picture tops line up)
MAX_H = {'d_kernel': 3.90}
TOP_ALIGN = {'d_kernel': 'd_agl'}


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
        k = min(1, max(oh, MAX_H.get(name, 0)) / ph, (ow + 0.3) / pw)  # no taller than its slot, <= 0.3 in wider
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
    for name, ref in TOP_ALIGN.items():
        if name in placed and ref in placed:
            pic, fr, _ = placed[name]
            dy = (placed[ref][0].top - pic.top) / E
            pic.top = placed[ref][0].top
            assert fr.top <= pic.top and pic.top + pic.height <= fr.top + fr.height, f'{name} leaves {fr.name}'
            print(f'{name:10s} top level with {ref}: moved {dy:+.3f} in')


def box1(sl):
    """Box 1: one control diagram replaces the rig, the loop and the widefield image; returns (removed, moved, added)."""
    f1 = next(x for x in sl.shapes if x.name == 'box 1 frame')
    rule = next(x for x in sl.shapes if x.name == 'box 1 rule')
    bul = next(x for x in sl.shapes if x.name == 'box 1 bullets')
    old = [x for x in sl.shapes if x.name in ('panel rig', 'panel loop', 'panel frame')]
    assert len(old) == 5, [x.name for x in old]
    fx, fy, fw, fh = (v / E for v in (f1.left, f1.top, f1.width, f1.height))
    pw, ph, _ = render('system')
    k = min(1, (fw - 0.16) / pw)
    assert k >= SHRINK, f'system needs x{k:.3f}'
    pw, ph = pw * k, ph * k
    x, y = fx + (fw - pw) / 2, (rule.top + rule.height) / E + 0.09
    pic = sl.shapes.add_picture(str(OUT / 'png' / 'system.png'), Inches(x), Inches(y), Inches(pw), Inches(ph))
    pic.name = 'panel system'
    pic._element.nvPicPr.cNvPr.set('descr', 'Closed-loop control diagram with the widefield rig: the PI controller '
                                   'and feedforward drive a 638 nm laser, galvos steer it to the stimulation site '
                                   'on the widefield image of cortex, a camera with 470/405 nm LEDs reads the '
                                   'readout site, and dF/F is fed back.')
    old[0]._element.addprevious(pic._element)
    removed = set()
    for o in old:
        rid = o._element.blip_rId
        removed.add(o.shape_id)
        o._element.getparent().remove(o._element)
        if not any(q._element.tag.endswith('pic') and q._element.blip_rId == rid for q in sl.shapes
                   if q.shape_type == 13):
            sl.part.drop_rel(rid)
    bul.left, bul.top = Inches(fx + 0.20), Inches(y + ph + 0.12)
    assert (bul.top + bul.height) / E <= fy + fh, 'box 1 bullets leave the box'
    print(f'box 1: system {pw:.2f} x {ph:.2f} in (x{k:.3f}) at ({x:.2f}, {y:.2f}); bullets at {(bul.top / E):.2f}-'
          f'{(bul.top + bul.height) / E:.2f} in, box ends {fy + fh:.2f}')
    return removed, {bul.shape_id}, {pic.shape_id}


def main(src, out, names):
    prs = Presentation(src)
    sl = prs.slides[0]
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)
    before = {sh.shape_id: c14n(sh._element) for sh in sl.shapes}
    placed = {}
    gone = {swap(sl, n, placed) for n in names}
    align(placed)
    removed, moved, added = box1(sl)
    now = {sh.shape_id: sh for sh in sl.shapes}
    assert not (gone | removed) & set(now) and len(now) == len(before) - len(removed) + len(added)
    for sid, x in before.items():
        if sid not in gone | removed | moved:
            assert c14n(now[sid]._element) == x, now[sid].name
    prs.save(out)
    print(f'{out}: {len(now)} shapes, {len(gone)} panels swapped, {len(removed)} removed for 1 added, '
          f'{len(moved)} moved')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2], sys.argv[3:] or NAMES)
