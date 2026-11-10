"""poster_swap_all.py -- put every poster-type panel (2026-11-10) into the poster, each in its own slot.

    python poster/sfn2026/poster_swap_all.py <poster.pptx> <out.pptx> [name ...]

Reads panels/poster/<name>_raw.pdf, written by poster_restyle.m (saved paper figures, restyled),
unique_panel.m (st_unique), sine_panels.m (sine_*) and seedfc_panel.m (copied there as seedfc_raw.pdf).
Each is cropped to its ink at the one print scale (PS) and replaces picture 'panel <name>', centred where the
old one was. A panel that comes out up to 4% larger than its slot is scaled down to fit (type stays >= 20 pt);
more than that is an error. Box 5's panel is taller on purpose: it fills its box under the rule.
Box 1: the rig moves up 0.15 in and the widefield image (with its key and scale bar, crops of the same
picture, so the bar keeps its scale) down 0.12 in, so the image no longer covers the rig's "sample" label.
Every other shape keeps its XML; main() asserts that.
"""
import copy
import sys
from pathlib import Path

import fitz
from lxml import etree
from pptx import Presentation
from pptx.util import Inches

from build_panels import ink
from build_pptx import PS, PX_ZOOM

HERE = Path(__file__).resolve().parent
RAW, OUT = HERE / 'panels' / 'poster', HERE / 'panels' / 'poster'
E = 914400
NAMES = ['cl_trial', 'cl_avg', 'cl_rmse', 'cl_var', 'sine_avg', 'sine_lag', 'sine_rmse', 'sine_var', 'seedfc',
         'st_trials', 'st_unique', 'st_quart', 'd_kernel', 'd_agl', 'd_rr']
SHRINK = 0.96


def render(name):
    d = fitz.open(str(RAW / f'{name}_raw.pdf'))
    r = ink(d[0])
    n = fitz.open()
    q = n.new_page(width=r.width, height=r.height)
    q.show_pdf_page(q.rect, d, 0, clip=r)
    n.save(str(OUT / f'{name}.pdf'), garbage=3, deflate=True)
    (OUT / 'png').mkdir(exist_ok=True)
    n[0].get_pixmap(matrix=fitz.Matrix(PX_ZOOM, PX_ZOOM), alpha=False).save(str(OUT / 'png' / f'{name}.png'))
    return r.width / 72 * PS, r.height / 72 * PS


def frame_of(sl, old):
    return next(sh for sh in sl.shapes if sh.name.startswith('box ') and sh.name.endswith(' frame')
                and sh.left <= old.left and sh.top <= old.top
                and old.left + old.width <= sh.left + sh.width and old.top + old.height <= sh.top + sh.height)


def swap(sl, name):
    old = next(sh for sh in sl.shapes if sh.name == f'panel {name}')
    fr = frame_of(sl, old)
    fx, fy, fw, fh = (v / E for v in (fr.left, fr.top, fr.width, fr.height))
    ow, oh = old.width / E, old.height / E
    pw, ph = render(name)
    if name == 'seedfc':                       # fills box 5 under its rule, centred across the frame
        rule = next(sh for sh in sl.shapes if sh.name == 'box 5 rule')
        top, bot = (rule.top + rule.height) / E, fy + fh
        k = min(1, (bot - top - 0.2) / ph, (fw - 0.3) / pw)
        pw, ph = pw * k, ph * k
        x, y = fx + (fw - pw) / 2, top + (bot - top - ph) / 2
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
    print(f'{name:10s} {ow:5.2f} x {oh:4.2f} -> {pw:5.2f} x {ph:4.2f} in (x{k:.3f}) in {fr.name}')
    return old.shape_id


def box1_nudge(sl):
    """Rig up 0.15 in, the widefield image and its two crops down 0.12 in; returns the ids moved."""
    pics = [sh for sh in sl.shapes if sh.name in ('panel rig', 'panel frame')]
    rig = next(sh for sh in pics if sh.name == 'panel rig')
    frames = [sh for sh in pics if sh.name == 'panel frame']
    assert len(frames) == 3
    f1 = next(sh for sh in sl.shapes if sh.name == 'box 1 frame')
    rule = next(sh for sh in sl.shapes if sh.name == 'box 1 rule')
    rig.top -= Inches(0.15)
    for sh in frames:
        sh.top += Inches(0.12)
    assert rig.top >= rule.top + rule.height, 'rig over the rule'
    assert max(sh.top + sh.height for sh in frames) <= f1.top + f1.height, 'image leaves box 1'
    img = max(frames, key=lambda sh: sh.height)
    print(f'box 1: rig bottom {(rig.top + rig.height) / E:.2f}, image top {img.top / E:.2f} in')
    return {rig.shape_id, *(sh.shape_id for sh in frames)}


def main(src, out, names):
    prs = Presentation(src)
    sl = prs.slides[0]
    c14n = lambda el: etree.tostring(el, method='c14n', exclusive=True)
    before = {sh.shape_id: c14n(sh._element) for sh in sl.shapes}
    gone = {swap(sl, n) for n in names}
    moved = box1_nudge(sl)
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
