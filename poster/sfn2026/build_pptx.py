"""build_pptx.py -- the SfN poster as a native PowerPoint file, to edit in PowerPoint for the web.

    python poster/sfn2026/build_panels.py     (first, if a panel changed)
    python poster/sfn2026/build_pptx.py

Same words and layout as poster.tex. PowerPoint's largest slide is 56 in, so the slide is 54 x 36 in: SfN's
template 3 size, and the same 3:2 shape as the 60 x 40 in PDF, so a print shop can scale it up unchanged.
All text, boxes and badges are native and editable, in Arial because PowerPoint online always has it, and every
shape is named for the Selection Pane. Panels are PNGs, 400 dpi even at 60 x 40 in, all at one print scale.

Text heights are measured with the Arial font files, and line spacing is exact, so boxes fit their text and
the leftover height in a column goes into the gaps between boxes, as \\vfill does in poster.tex.

Once the .pptx has been edited by hand it is the master: re-running this overwrites poster.pptx.
"""
import re
from pathlib import Path

import fitz
from lxml import etree
from PIL import Image, ImageFont
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, MSO_AUTO_SIZE, PP_ALIGN
from pptx.opc.constants import RELATIONSHIP_TYPE as RT
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt

HERE = Path(__file__).resolve().parent
PAN = HERE / 'panels'
PNG = PAN / 'png'
MOUSE = HERE.parents[1] / 'talk' / 'mousy.png'
OUTFILE = HERE / 'poster.pptx'

PURPLE, GOLD, SPIRIT = '4B2E83', 'B7A57A', 'FFC700'
INK, WHITE, RED = '1E1E1E', 'FFFFFF', 'C81E1E'

# ---- geometry, in inches on the 54 x 36 in slide (poster.tex x 0.9)
W, H = 54.0, 36.0
MARGIN = 0.675
HEAD_H = 3.87
COL_Y = MARGIN + HEAD_H + 0.27
COL_END = H - MARGIN
COL_W = [45.5 / 2.54 * 0.9, 45.5 / 2.54 * 0.9, 56 / 2.54 * 0.9]
COL_GAP = (W - 2 * MARGIN - sum(COL_W)) / 2
PS = 3.3 * 0.9                  # one print scale for every panel, as \PS in poster.tex
RULE = 3.6                      # pt, frame and rule
PAD = 0.2                       # inside a box, left and right
BADGE = 1.17
ROW_PAD = 0.14                  # above and below a row of panels
PX_ZOOM = 3.3 * 400 / 72        # 400 dpi if printed at 60 x 40 in

# ---- type: (size, exact line spacing), pt
BODY = (30.5, 37.5)           # same size as the PDF; no paragraph sits within 1.5% of an extra line
SMALL = (24, 29.5)
HEAD = (39, 46)
ITEM_GAP = 9                    # pt between bullets
BULLET_IN = 30.5                  # pt hanging indent

FONT = {
    '': ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 1000),
    'b': ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 1000),
    'i': ImageFont.truetype('C:/Windows/Fonts/ariali.ttf', 1000),
}
TOKEN = re.compile(r'\*\*(.+?)\*\*|_(.+?)_|\^(.+?)\^|\{\{(.+?)\}\}')
ALT = {
    'rig': 'Light path of the wide-field rig: LEDs, dichroics, laser and galvos, objective, camera',
    'frame': 'Mean wide-field frame with the output readout kernel, stimulation spot and 1 mm scale bar',
    'loop': 'Block diagram of the PI controller with feedforward gain, in closed loop with mouse cortex',
    'imp_traces': 'Trial-averaged responses to impulses at each laser power',
    'imp_dose': 'Evoked suppression against laser power, per session, with linear fits',
    'imp_fit': 'Held-out linear model fit to the impulse responses, Mouse 1b',
    'imp_r2': 'Held-out model R squared for each impulse session',
    'imp_state': 'Trial-to-trial variability by state quartile: motion, relative and absolute 2-4 Hz power',
    'cl_trial': 'Example open-loop and closed-loop trials against the target',
    'cl_avg': 'Trial-averaged open-loop and closed-loop responses',
    'cl_rmse': 'Closed-loop to open-loop RMSE ratio by window across sessions',
    'cl_var': 'Closed-loop to open-loop variance ratio by window across sessions',
    'sine_avg': 'Sine-target trial averages for open loop, open loop with preview, closed loop, closed loop with preview',
    'sine_lag': 'Phase lag for the four sine conditions',
    'sine_rmse': 'Trial RMSE distributions for the four sine conditions',
    'sine_var': 'Variance across trials over time for the four sine conditions',
    'st_trials': 'Example trials at high initial deviation, motion, relative 2-4 Hz and absolute 1-4 Hz power',
    'st_unique': 'Unique R squared of each state variable for 0-1 s and 1-3 s error',
    'st_quart': 'RMSE to target by state quartile for each state variable, open and closed loop',
    'd_kernel': 'Map of predictor kernel weights over the contralateral hemisphere, with the stimulation site',
    'd_agl': 'Example trial split into actual, global predicted from the contralateral side, and local',
    'd_rr': 'Disturbance rejection ratio by session',
}


def E(inches):
    return Emu(int(round(inches * 914400)))


def rgb(hex6):
    return RGBColor.from_string(hex6)


# ---- text: **bold**, _italic_, ^superscript^, {{red bold placeholder}}, ~ = no-break space
def runs(text):
    out, i = [], 0
    for m in TOKEN.finditer(text):
        if m.start() > i:
            out.append((text[i:m.start()], ''))
        b, it, sup, fill = m.groups()
        out.append((b, 'b') if b else (it, 'i') if it else (sup, '^') if sup else (fill, 'f'))
        i = m.end()
    if i < len(text):
        out.append((text[i:], ''))
    return [(t.replace('~', '\u00a0'), s) for t, s in out]


def width_in(fragment, style, size, bold):
    face = 'b' if bold or style in ('b', 'f') else 'i' if style == 'i' else ''
    scale = 2 / 3 if style == '^' else 1                # PowerPoint draws a superscript at about 2/3
    return FONT[face].getlength(fragment) / 1000 * size * scale / 72


def n_lines(text, size, width, bold=False):
    """Greedy wrap the way PowerPoint fills a line: it breaks after a space or a hyphen, and at a | here."""
    space = width_in(' ', '', size, bold)
    total = 0
    for seg in text.split('|'):
        chunks, word, after_space = [], 0.0, False
        for t, st in runs(seg):
            for piece in re.split(r'(?<= )|(?<=-)', t):
                word += width_in(piece.rstrip(' '), st, size, bold)
                if piece.endswith((' ', '-')):
                    chunks.append((word, after_space))
                    word, after_space = 0.0, piece.endswith(' ')
        chunks.append((word, after_space))
        lines, x = 1, 0.0
        for wd, sp in chunks:
            gap = space if sp and x else 0.0
            if x and x + gap + wd > width:
                lines, x = lines + 1, wd
            else:
                x += gap + wd
        total += lines
    return total


def text_h(paras, type_, width, gap=0, bold=False):
    size, line = type_
    return (sum(n_lines(p, size, width, bold) for p in paras) * line + gap * (len(paras) - 1)) / 72


# ---- shapes; every draw helper is a no-op when the slide is None, so one code path measures and draws
def rect(sl, x, y, w, h, fill=None, line=None, name=''):
    if sl is None:
        return None
    sh = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, E(x), E(y), E(w), E(h))
    sh._element.remove(sh._element.find(qn('p:style')))     # no theme shadow, outline or font colour
    if fill:
        sh.fill.solid()
        sh.fill.fore_color.rgb = rgb(fill)
    else:
        sh.fill.background()
    if line:
        sh.line.color.rgb = rgb(line)
        sh.line.width = Pt(RULE)
    else:
        sh.line.fill.background()
    sh.name = name
    return sh


def fill_frame(tf, paras, type_, color=INK, bold=False, align=PP_ALIGN.LEFT, gap=0, bullets=False, anchor=MSO_ANCHOR.TOP):
    size, line = type_
    tf.word_wrap = True
    tf.auto_size = MSO_AUTO_SIZE.NONE
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    for i, text in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.line_spacing = Pt(line)
        p.space_before = Pt(gap if i else 0)
        p.space_after = Pt(0)
        pPr = p._p.get_or_add_pPr()
        if bullets:
            pPr.set('marL', str(int(Pt(BULLET_IN))))
            pPr.set('indent', str(-int(Pt(BULLET_IN))))
            clr = etree.SubElement(pPr, qn('a:buClr'))
            etree.SubElement(clr, qn('a:srgbClr')).set('val', PURPLE)
            etree.SubElement(pPr, qn('a:buSzPct')).set('val', '75000')
            etree.SubElement(pPr, qn('a:buFont')).set('typeface', 'Arial')
            etree.SubElement(pPr, qn('a:buChar')).set('char', '\u25ba')
        else:
            etree.SubElement(pPr, qn('a:buNone'))
        for k, seg in enumerate(text.split('|')):
            if k:
                p.add_line_break()
            for t, st in runs(seg):
                r = p.add_run()
                r.text = t
                f = r.font
                f.name = 'Arial'
                f.size = Pt(size)
                f.bold = bold or st in ('b', 'f')
                f.italic = st == 'i'
                f.color.rgb = rgb(RED if st == 'f' else color)
                if st == '^':
                    r._r.get_or_add_rPr().set('baseline', '30000')


def text(sl, x, y, w, h, paras, type_, name='', **kw):
    if sl is None:
        return
    tb = sl.shapes.add_textbox(E(x), E(y), E(w), E(h))
    tb.name = name
    fill_frame(tb.text_frame, paras, type_, **kw)


def panel_size(name):
    r = fitz.open(str(PAN / f'{name}.pdf'))[0].rect
    return r.width / 72 * PS, r.height / 72 * PS


def panel(sl, name, x, y):
    if sl is None:
        return
    w, h = panel_size(name)
    pic = sl.shapes.add_picture(str(PNG / f'{name}.png'), E(x), E(y), E(w), E(h))
    pic.name = f'panel {name}'
    pic._element.nvPicPr.cNvPr.set('descr', ALT[name])


# ---- body pieces: each is f(sl, x, y, w) -> height, with x, w the inside of the box
def Row(*names):
    def f(sl, x, y, w):
        sizes = [panel_size(n) for n in names]
        tallest = max(h for _, h in sizes)
        spare = (w - sum(wd for wd, _ in sizes)) / (len(names) + 1)
        assert spare >= -1e-3, (names, spare)
        px = x + spare
        for n, (wd, h) in zip(names, sizes):
            panel(sl, n, px, y + ROW_PAD + tallest - h)      # bottoms line up, as baselines do in LaTeX
            px += wd + spare
        return tallest + 2 * ROW_PAD
    return f


def Bullets(*items, name='bullets'):
    def f(sl, x, y, w):
        h = text_h(items, BODY, w - BULLET_IN / 72, gap=ITEM_GAP)
        text(sl, x, y + 0.05, w, h, list(items), BODY, name=name, bullets=True, gap=ITEM_GAP)
        return h + 0.1
    return f


def PanelBeside(pname, *items, name='bullets'):
    def f(sl, x, y, w):
        pw, ph = panel_size(pname)
        tw = w - pw - 0.3
        th = text_h(items, BODY, tw - BULLET_IN / 72, gap=ITEM_GAP)
        panel(sl, pname, x, y + 0.13)
        text(sl, x + pw + 0.3, y + 0.13 + (ph - th) / 2, tw, th, list(items), BODY, name=name, bullets=True, gap=ITEM_GAP)
        return ph + 0.13
    return f


# ---- boxes: each is f(sl, x, y, w) -> height
def ResultBox(n, title, *body):
    def f(sl, x, y, w):
        tw = w - BADGE - 0.25 - 0.1
        head = max(BADGE, text_h([title], HEAD, tw, bold=True) + 0.16)
        inner = y + head + 0.08
        hs = [b(None, x + PAD, 0, w - 2 * PAD) for b in body]
        total = head + 0.08 + sum(hs) + 0.13
        rect(sl, x, y, w, total, fill=WHITE, line=PURPLE, name=f'box {n} frame')
        if sl is not None:
            badge = rect(sl, x, y, BADGE, head, fill=PURPLE, name=f'box {n} number')
            fill_frame(badge.text_frame, [str(n)], (76, 76), color=WHITE, bold=True, align=PP_ALIGN.CENTER,
                       anchor=MSO_ANCHOR.MIDDLE)
        text(sl, x + BADGE + 0.25, y, tw, head, [title], HEAD, name=f'box {n} heading', bold=True, anchor=MSO_ANCHOR.MIDDLE)
        rect(sl, x, y + head - RULE / 144, w, RULE / 72, fill=PURPLE, name=f'box {n} rule')
        yy = inner
        for b, h in zip(body, hs):
            if sl is not None:
                b(sl, x + PAD, yy, w - 2 * PAD)
            yy += h
        return total
    return f


def TextBox(name, paras, type_=BODY, footer=None, bullets=False, gap=9):
    def f(sl, x, y, w):
        tw = w - 2 * 0.2
        indent = BULLET_IN / 72 if bullets else 0
        th = text_h(paras, type_, tw - indent, gap=gap)
        fh = text_h([footer], SMALL, tw) + 0.1 if footer else 0
        total = th + fh + 0.34
        rect(sl, x, y, w, total, fill=WHITE, line=PURPLE, name=f'{name} frame')
        text(sl, x + 0.2, y + 0.16, tw, th, paras, type_, name=name, gap=gap, bullets=bullets)
        if footer:
            text(sl, x + 0.2, y + 0.16 + th + 0.1, tw, fh - 0.1, [footer], SMALL, name='funding and contact',
                 align=PP_ALIGN.CENTER)
        return total
    return f


def SectionBar(title):
    def f(sl, x, y, w):
        ring = 0.14
        bar_h = 0.95
        rect(sl, x, y, w, bar_h + 2 * ring, line=PURPLE, name=f'{title} bar outline')
        if sl is not None:
            bar = rect(sl, x + ring, y + ring, w - 2 * ring, bar_h, fill=PURPLE, name=f'{title} bar')
            fill_frame(bar.text_frame, [title], (45, 50), color=WHITE, bold=True, align=PP_ALIGN.CENTER,
                       anchor=MSO_ANCHOR.MIDDLE)
        rect(sl, x + ring, y + ring + bar_h - 0.06, w - 2 * ring, 0.06, fill=GOLD, name=f'{title} bar gold rule')
        return bar_h + 2 * ring + 0.17
    return f


def stack(*parts):
    def f(sl, x, y, w):
        total = 0.0
        for p in parts:
            total += p(sl, x, y + total, w)
        return total
    return f


def column(sl, x, w, items):
    """Stack boxes; the leftover height goes evenly into the gaps."""
    hs = [f(None, x, 0, w) for f in items]
    free = (COL_END - COL_Y - sum(hs)) / (len(items) - 1)
    print(f'column at x={x:5.2f}: gaps {free:5.2f} in, boxes {[round(h, 2) for h in hs]}')
    assert free >= 0.2, 'column overflows the slide'
    y = COL_Y
    for f, h in zip(items, hs):
        f(sl, x, y, w)
        y += h + free


# ---- poster content: words from poster.tex
DFF = '\u0394F/F'
MINUS = '\u2212'
COLUMNS = [
    [
        stack(SectionBar('Introduction'),
              TextBox('introduction',
                      ['Mesoscale cortical activity is typically perturbed open loop. Whether feedback can reliably '
                       'regulate it, and what limits that control, remains largely untested.',
                       '**We built a closed-loop optogenetic controller, then asked which brain states limit it.**'])),
        stack(SectionBar('Results'),
              ResultBox(1, 'We close the loop on cortex in real time',
                        Row('rig', 'loop'),
                        PanelBeside('frame',
                                    'Wide-field GCaMP8s imaging at 35~Hz',
                                    f'Output: {DFF} beside the stimulation spot',
                                    'Loop delay 29~ms mean (14\u201347~ms)', name='box 1 bullets'))),
        ResultBox(2, 'The average response is near-linear; single trials vary with brain state',
                  Row('imp_traces', 'imp_dose', 'imp_fit'),
                  Row('imp_r2', 'imp_state'),
                  Bullets('Suppression scales with laser power (_R_^2^~=~0.73\u20130.97), and a low-order linear model '
                          'predicts held-out trial averages (median _R_^2^~=~0.85; 4 sessions, 3 mice).',
                          'Single-trial variability falls at the highest motion (0.58\u00d7) and rises with absolute '
                          '2\u20134~Hz power (2.35\u00d7), with or without stimulation.', name='box 2 bullets')),
    ],
    [
        ResultBox(3, 'Feedback holds activity at the target and reduces|trial-to-trial variability',
                  Row('cl_trial', 'cl_rmse'),
                  Row('cl_avg', 'cl_var'),
                  Bullets(f'Target {MINUS}5%~{DFF} for 3~s, loops interleaved (15 sessions, 4 mice).',
                          f'RMSE 23% lower (ratio 0.77, _p_~=~5.8~\u00d7~10^{MINUS}8^), in all 15 sessions.',
                          f'Across-trial variance 42% lower (ratio 0.58, _p_~=~6.3~\u00d7~10^{MINUS}6^), in 14 of 15 sessions.',
                          f'Also beats the best fixed input (13%, _p_~=~6.5~\u00d7~10^{MINUS}4^): not only calibration.',
                          name='box 3 bullets')),
        ResultBox(4, 'Moving target: feedback reduces error,|preview corrects the lag',
                  Row('sine_avg'),
                  Row('sine_lag', 'sine_rmse', 'sine_var'),
                  Bullets('1~Hz target; preview gives the controller the target 143~ms ahead. Mouse 3b shown; '
                          'same direction in all 3 sessions (no tests).',
                          f'Feedback: variance 11.8~\u2192~5.8~(%~{DFF})^2^, median RMSE 3.59~\u2192~2.26.',
                          'Preview: lag 71\u00b0~\u2192~16\u00b0 in open loop, 46\u00b0~\u2192~2\u00b0 in closed loop; '
                          'it does not lower the error.', name='box 4 bullets')),
        TextBox('methods',
                ['**Methods.** CaMKII-tTA;tetO-GCaMP8s mice with AAV PHP.eB DLX2.0-ChrimsonR in inhibitory interneurons, '
                 'so 638~nm light suppresses local excitatory activity. Head-fixed, awake, no task (rig and preparation: '
                 f"Matveev et al., 2024). Closed-loop {DFF} uses the controller's own trailing 40~s mean; impulse {DFF} "
                 'divides by the session mean image. Statistics: per-session log CL/OL ratios, one-sample _t_-test across '
                 'sessions, checked per mouse; state slopes fitted within session and tested across sessions; rejection '
                 'ratio from a session-level mixed model.'], type_=SMALL),
    ],
    [
        ResultBox(5, 'State-dependent limits: feedback removes more error during movement, but error grows with 1\u20134~Hz power',
                  Row('st_trials', 'st_unique'),
                  Row('st_quart'),
                  Bullets('Initial deviation explains transient error (unique _R_^2^~=~0.53); absolute 1\u20134~Hz power '
                          'explains a modest part of steady-state error (0.11), more than any other state.',
                          '**Movement:** open-loop error rises (_p_~=~0.011), closed-loop error stays flat, so feedback '
                          f'removes a larger fraction of the error (CL/OL {MINUS}13% per SD, _p_~=~0.0023).',
                          f'**Absolute 1\u20134~Hz power:** closed-loop error rises (_p_~=~7.1~\u00d7~10^{MINUS}4^, all 15 sessions) '
                          'about as much as open-loop error; the fraction removed does not change significantly (_p_~=~0.094).',
                          'One explanation: opsin and indicator kinetics and loop delay limit the controllable frequencies.',
                          name='box 5 bullets')),
        ResultBox(6, 'Feedback partly rejects a disturbance predicted|from the other hemisphere',
                  Row('d_kernel', 'd_agl', 'd_rr'),
                  Bullets('A linear model fit on laser-off frames predicts the site from the contralateral hemisphere '
                          '(median held-out _R_^2^~=~0.76, 13 sessions).',
                          'Closed loop leaves less residual energy than the disturbance: rejection ratio 0.58 '
                          f'(_p_~=~1.3~\u00d7~10^{MINUS}4^; 11 sessions, 3 mice). It removes most of the constant offset and '
                          'less of the fluctuations.', name='box 6 bullets')),
        stack(SectionBar('Conclusions'),
              TextBox('conclusions',
                      ['A near-linear average response is enough to design a controller that **holds a cortical site at a '
                       'target level**, better than open loop in every session and mouse.',
                       '**Performance depends on brain state:** feedback removes more of the error during movement, while '
                       'error rises with absolute 1\u20134~Hz power.',
                       'Feedback rejects part of a disturbance predicted from the other hemisphere, and preview corrects '
                       'the lag when the target moves.'],
                      bullets=True,
                      footer='Supported by {{[FILL: grants: SfN requires a funding acknowledgement]}}~~~~Contact: adityad@uw.edu')),
    ],
]


def header(sl):
    x, y, w = MARGIN, MARGIN, W - 2 * MARGIN
    rect(sl, x, y, w, HEAD_H, fill=PURPLE, name='header')
    rect(sl, x, y + HEAD_H - 0.125, w, 0.125, fill=GOLD, name='header gold rule')
    logo_h = 2.61
    with Image.open(PAN / 'uw_w.png') as im:
        logo_w = logo_h * im.width / im.height
    pic = sl.shapes.add_picture(str(PAN / 'uw_w.png'), E(x + 3.75 - logo_w / 2), E(y + (HEAD_H - logo_h) / 2 - 0.05),
                                E(logo_w), E(logo_h))
    pic.name = 'UW logo'
    pic._element.nvPicPr.cNvPr.set('descr', 'University of Washington W logo')
    mid_x, mid_w = x + 8.0, w - 16.0
    text(sl, mid_x, y + 0.12, mid_w, 2.28, ['Controlling cortex in real time: state-dependent',
                                           'limits of closed-loop optogenetic regulation'],
         (76, 82), name='title', color=WHITE, bold=True, align=PP_ALIGN.CENTER)
    text(sl, mid_x, y + 2.43, mid_w, 0.64, ['Aditya Deole, Anna Li, Eric Shea-Brown, Mehran Mesbahi, Nick Steinmetz'],
         (41, 46), name='authors', color=WHITE, bold=True, align=PP_ALIGN.CENTER)
    text(sl, mid_x, y + 3.09, mid_w, 0.5, ['University of Washington, Seattle, WA'], (32, 36), name='affiliation',
         color=GOLD, align=PP_ALIGN.CENTER)
    right = x + w - 0.33
    text(sl, right - 7.0, y + 0.2, 7.0, 0.58, ['[FILL: PSTR###.##]'], (34, 40), name='poster number', color=SPIRIT,
         bold=True, align=PP_ALIGN.RIGHT)
    # the mouse in a white circle (same crop as poster.tex: trim 45 43 45 18 of a 180 bp image)
    with Image.open(MOUSE) as im:
        k = im.width / 180
        im.crop((int(45 * k), int(18 * k), int(im.width - 45 * k), int(im.height - 43 * k))).save(PNG / 'mouse.png')
    with Image.open(PNG / 'mouse.png') as im:
        mouse_h, mouse_w = 2.07, 2.07 * im.width / im.height
    dia = (mouse_w ** 2 + mouse_h ** 2) ** 0.5 + 0.1
    cx, cy = right - dia / 2, y + 0.78 + dia / 2
    disc = sl.shapes.add_shape(MSO_SHAPE.OVAL, E(cx - dia / 2), E(cy - dia / 2), E(dia), E(dia))
    disc._element.remove(disc._element.find(qn('p:style')))
    disc.fill.solid()
    disc.fill.fore_color.rgb = rgb(WHITE)
    disc.line.fill.background()
    disc.name = 'mouse circle'
    pic = sl.shapes.add_picture(str(PNG / 'mouse.png'), E(cx - mouse_w / 2), E(cy - mouse_h / 2), E(mouse_w), E(mouse_h))
    pic.name = 'mouse'
    pic._element.nvPicPr.cNvPr.set('descr', 'Cartoon of a mouse in a graduation cap with a head implant')


def render_panels():
    PNG.mkdir(exist_ok=True)
    for name in ALT:
        doc = fitz.open(str(PAN / f'{name}.pdf'))
        doc[0].get_pixmap(matrix=fitz.Matrix(PX_ZOOM, PX_ZOOM), alpha=False).save(str(PNG / f'{name}.png'))


def set_theme(prs):
    """UW colours and Arial in the theme, so anything added by hand in PowerPoint matches."""
    part = prs.slide_master.part.part_related_by(RT.THEME)
    x = part.blob.decode('utf8')
    x = re.sub(r'(<a:latin typeface=")[^"]*(")', r'\1Arial\2', x)
    for slot, value in (('dk2', PURPLE), ('accent1', PURPLE), ('accent2', GOLD), ('accent3', SPIRIT),
                        ('accent4', RED), ('accent5', '325FC8'), ('accent6', '1E1E1E')):
        x = re.sub(rf'(<a:{slot}>\s*<a:srgbClr val=")[0-9A-Fa-f]{{6}}(")', rf'\g<1>{value}\2', x)
    part._blob = x.encode('utf8')


def main():
    render_panels()
    prs = Presentation()
    prs.slide_width, prs.slide_height = E(W), E(H)
    blank = next(l for l in prs.slide_layouts if l.name == 'Blank')
    for l in list(prs.slide_layouts):
        if l is not blank:
            prs.slide_layouts.remove(l)
    set_theme(prs)
    cp = prs.core_properties
    cp.title = 'Controlling cortex in real time: state-dependent limits of closed-loop optogenetic regulation'
    cp.subject = 'SfN Neuroscience 2026 poster'
    cp.author = cp.last_modified_by = 'Aditya Deole'
    cp.keywords = cp.comments = ''

    sl = prs.slides.add_slide(blank)
    header(sl)
    x = MARGIN
    for w, items in zip(COL_W, COLUMNS):
        column(sl, x, w, items)
        x += w + COL_GAP
    prs.save(str(OUTFILE))
    print(f'{OUTFILE.name}: {OUTFILE.stat().st_size / 1e6:.1f} MB, {len(sl.shapes)} shapes')


if __name__ == '__main__':
    main()
