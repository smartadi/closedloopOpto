"""poster_ack.py -- an Acknowledgements section, and the RAIN Lab in the header (SfN poster v9, 2026-11-11).

    python poster/sfn2026/poster_ack.py <in.pptx> <out.pptx>

Aditya (2026-11-11): "add an acknowledgement section putting nsf(instead of up top) in there and thank TDPA for
conference funding support funding", "please thank lilly(i put thier logo in downloads)", "add rain lab logo
too i guess". Layout approved 2026-11-11 ("Approve"). Run after heading_fit.py, on the 54 x 36 in poster (he
kept 54 x 36: at 48 in the columns could not be balanced without dropping the panel type below the poster floor).
- Header: the NSF logo leaves the header for the new section. In its place goes the RAIN Lab's name as its
  website shows it (depts.washington.edu/uwrainlab has no graphic logo): "RAIN LAB" over "Robotics, Aerospace
  and / Information Networks", in the gold of the Steinmetz Lab logo (#E0C08C, its most common colour). It is
  text, a stand-in until a logo file turns up.
- Acknowledgements: a new section at the bottom of column 2, the one column with no body text, under a purple
  bar like the Introduction's and Conclusions'. The text is ACK. Beside it: the NSF logo and the Lilly logo
  (panels/lilly_logo.jpg, Aditya's file, cropped to the script). The funder's name is written as SfN writes
  it, "Eli Lilly and Company Foundation" (sfn.org news, 2025-11-14, on TPDA donors); TPDA = Trainee
  Professional Development Award.
- Room: K = (A - F - h_ack - 3 GAP) / P, with A the body height (BODY_TOP to BODY_BOT), F the bar rows of
  boxes 3-5 (kept at full size), h_ack the new section's height (bar, pad, then the taller of the measured
  text and the NSF logo) and P the height below the bars in boxes 3-5. Column 2's pictures, and the space
  between them, scale by K about the column's centre line; the four sections stack with gaps GAP. The script
  stops if K < 0.90 (panel ticks would fall below the poster's 17.8 pt floor).
"""
import copy
import os
import sys
import tempfile

import numpy as np
from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Emu, Inches, Pt

from poster_resize import fixed, measure, sections

HERE = os.path.dirname(os.path.abspath(__file__))
LILLY = os.path.join(HERE, 'panels', 'lilly_logo.jpg')
E = 914400
BODY_TOP, BODY_BOT = 4.82, 35.32  # in
GAP = 0.9                         # in, between sections in column 2 (columns 1 and 3 show 0.97-1.28 in)
INSET = 0.15                      # in, text and logos inside the column
PAD = 0.25                        # in, gold rule to content
NSF_H, LILLY_H = 1.25, 0.95       # in
GOLD, INK = 'E0C08C', '1E1E1E'
ACK = ['This work was supported by the U.S. National Science Foundation.',
       'Conference funding: SfN Trainee Professional Development Award, supported by the Eli Lilly and '
       'Company Foundation.']


def textbox(sl, name, x, y, w, paras):
    """paras: [(text, size_pt, bold, colour, line_pt, space_before_pt)]."""
    tb = sl.shapes.add_textbox(x, y, w, Inches(1))
    tb.name = name
    tf = tb.text_frame
    tf.word_wrap = True
    for m in ('margin_left', 'margin_right', 'margin_top', 'margin_bottom'):
        setattr(tf, m, 0)
    for i, (text, size, bold, colour, line, before) in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.line_spacing = Pt(line)
        p.space_before = Pt(before)
        r = p.add_run()
        r.text = text
        r.font.size, r.font.bold, r.font.name = Pt(size), bold, 'Arial'
        r.font.color.rgb = RGBColor.from_string(colour)
    return tb


def copy_shape(sl, sh, name):
    el = copy.deepcopy(sh._element)
    sl.shapes._spTree.append(el)
    new = sl.shapes[-1]
    new.name = name
    return new


def main(src, dst):
    prs = Presentation(src)
    sl = prs.slides[0]
    by = {sh.name: sh for sh in sl.shapes}
    cols, secs = sections(sl)
    cL, cR = cols[1]
    cW = cR - cL

    # ---- header: RAIN Lab where the NSF logo was
    band, uw, nsf = by['header'], by['UW logo'], by['NSF logo']
    rain = textbox(sl, 'RAIN lab', uw.left + uw.width + Inches(0.45), band.top, Inches(4.8),
                   [('RAIN LAB', 66, True, GOLD, 72, 0),
                    ('Robotics, Aerospace and', 24, False, GOLD, 28, 4),
                    ('Information Networks', 24, False, GOLD, 28, 0)])

    # ---- Acknowledgements: bar and gold rule copied from the Conclusions bar
    cb, cr = by['Conclusions bar'], by['Conclusions bar gold rule']
    off = cr.top - cb.top
    bar = copy_shape(sl, cb, 'Acknowledgements bar')
    rule = copy_shape(sl, cr, 'Acknowledgements bar gold rule')
    bar.text_frame.paragraphs[0].runs[0].text = 'Acknowledgements'
    for sh in (bar, rule):
        sh.left, sh.width = cL, cW

    lilly = sl.shapes.add_picture(LILLY, 0, 0)
    lilly.name = 'Lilly logo'
    lilly._element.nvPicPr.cNvPr.set('descr', 'Eli Lilly and Company Foundation')
    a = np.asarray(Image.open(LILLY).convert('RGB')).astype(int)
    ys, xs = np.nonzero((765 - a.sum(2)) > 60)           # the red script on white
    H, W = a.shape[:2]
    m = 8                                                 # px of white kept round the script
    lilly.crop_left, lilly.crop_right = (xs.min() - m) / W, 1 - (xs.max() + 1 + m) / W
    lilly.crop_top, lilly.crop_bottom = (ys.min() - m) / H, 1 - (ys.max() + 1 + m) / H
    asp = (xs.max() + 1 - xs.min() + 2 * m) / (ys.max() + 1 - ys.min() + 2 * m)
    lilly.height = Inches(LILLY_H)
    lilly.width = int(Inches(LILLY_H) * asp)
    nsf.height = nsf.width = Inches(NSF_H)
    lilly.left = cR - Inches(INSET) - lilly.width
    nsf.left = lilly.left - Inches(0.45) - nsf.width
    tx = cL + Inches(INSET)
    text = textbox(sl, 'acknowledgements', tx, 0, nsf.left - Inches(0.4) - tx,
                   [(t, 26, False, INK, 32, 6 if i else 0) for i, t in enumerate(ACK)])

    with tempfile.TemporaryDirectory() as tmp:
        t = os.path.join(tmp, 'a.pptx')
        prs.save(t)
        hgt = measure(t, {'acknowledgements', 'RAIN lab'})
    text.height, rain.height = Inches(hgt['acknowledgements']), Inches(hgt['RAIN lab'])
    rain.top = int(band.top + (band.height - rain.height) / 2)
    body = max(text.height, nsf.height)
    h_ack = bar.height + Inches(PAD) + body

    # ---- column 2: pictures shrink by K, bars keep their size, four sections with equal gaps
    info = []
    for c, head, mem in secs:
        if c != 1:
            continue
        top = min(sh.top for sh in mem)
        bot = max(sh.top + sh.height for sh in mem)
        rows = []
        for a0, b0 in sorted((sh.top - top, sh.top + sh.height - top) for sh in mem if fixed(sh)):
            if rows and a0 <= rows[-1][1]:
                rows[-1][1] = max(rows[-1][1], b0)
            else:
                rows.append([a0, b0])
        keep = sum(b0 - a0 for a0, b0 in rows)
        info.append((mem, top, bot - top, rows, keep))
    A = Inches(BODY_BOT - BODY_TOP)
    F = sum(i[4] for i in info)
    P = sum(i[2] - i[4] for i in info)
    K = (A - F - h_ack - 3 * Inches(GAP)) / P
    assert 0.9 <= K <= 1.0, f'column 2 would shrink to {K:.3f}'
    cx = cL + cW / 2
    y = Inches(BODY_TOP)
    for mem, top, h, rows, keep in info:
        def ymap(dy, rows=rows):
            k = sum(max(0, min(b0, dy) - a0) for a0, b0 in rows)
            return k + (dy - k) * K
        for sh in mem:
            sh.top = Emu(int(y + ymap(sh.top - top)))
            if not fixed(sh):
                sh.left = Emu(int(cx + (sh.left - cx) * K))
                sh.width, sh.height = Emu(int(sh.width * K)), Emu(int(sh.height * K))
        y += int(keep + (h - keep) * K) + Inches(GAP)
    bar.top = Emu(int(y))
    rule.top = Emu(int(y + off))
    c0 = y + bar.height + Inches(PAD)
    for sh in (text, nsf, lilly):
        sh.top = Emu(int(c0 + (body - sh.height) / 2))
    print(f'column 2: pictures x{K:.3f}, gaps {GAP} in, Acknowledgements {h_ack / E:.2f} in high, '
          f'ends {(y + h_ack) / E:.2f} in')
    print(f'RAIN lab {rain.height / E:.2f} in high at x {rain.left / E:.2f} in; '
          f'Lilly logo {lilly.width / E:.2f} x {lilly.height / E:.2f} in')
    prs.save(dst)
    print(dst)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
