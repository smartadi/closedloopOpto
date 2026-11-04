"""build_panels.py -- the individual paper panels the SfN poster uses, cropped to their ink.

    python poster/sfn2026/build_panels.py

Writes poster/sfn2026/panels/<name>.pdf (git-ignored, vector). poster.tex prints all of them at one
\\includegraphics scale, so each file here is sized so its body text is 6 pt, the paper's panel size.
Re-run after a producer changes a panel in paper/figures_final/.

Sources: Figs 3-5 from panels/ (the one locked set); Figs 1-2 from jn/, whose panels were rebuilt for
the active draft (latency from the test recording, 2026-11-02; Fig 2 labels, 2026-11-03).
"""
import io
from pathlib import Path

import fitz
import numpy as np
from lxml import etree
from PIL import Image
from pptx import Presentation

HERE = Path(__file__).resolve().parent
FINAL = HERE.parents[1] / 'paper' / 'figures_final'
PAN, JN = FINAL / 'panels', FINAL / 'jn'
OUT = HERE / 'panels'
PAD = 1.0                       # pt of white kept around the ink

# name: (source, scale that brings its body text to 6 pt)
PANELS = {
    # 1 the loop
    'rig':        (PAN / 'figure1' / 'wfpath.pdf', 6 / 20.95),
    'frame':      (JN / 'fig1' / 'panel_b_frame.pdf', 6 / 7),
    'loop':       (JN / 'fig1' / 'panel_e_control_loop.svg', 6 / 7),
    # 2 linear on average, variable with state
    'imp_traces': (JN / 'fig2' / 'A.pdf', 1),
    'imp_dose':   (JN / 'fig2' / 'B.pdf', 1),
    'imp_fit':    (JN / 'fig2' / 'C.pdf', 1),
    'imp_r2':     (JN / 'fig2' / 'D.pdf', 1),
    'imp_state':  (JN / 'fig2' / 'G.pdf', 1),
    # 3 feedback works
    'cl_trial':   (PAN / 'figure3' / 'panel_A.pdf', 1),
    'cl_avg':     (PAN / 'figure3' / 'panel_B.pdf', 1),
    'cl_rmse':    (PAN / 'figure3' / 'MSE_ratio_by_window.pdf', 1),
    'cl_var':     (PAN / 'figure3' / 'variance_ratio_by_window.pdf', 1),
    # 4 moving target
    'sine_avg':   (PAN / 'figure5' / 'sine_5C_trialavg_AL_0048_2026-07-14_1.pdf', 1),
    'sine_lag':   (PAN / 'figure5' / 'sine_5H_phase_lag_AL_0048_2026-07-14_1.pdf', 1),
    'sine_rmse':  (PAN / 'figure5' / 'sine_5G_rmse_violin_AL_0048_2026-07-14_1.pdf', 1),
    'sine_var':   (PAN / 'figure5' / 'sine_5E_variance_AL_0048_2026-07-14_1.pdf', 1),
    # 5 brain state
    'st_trials':  (PAN / 'figure4' / 'f4_state_exemplars.pdf', 1),
    'st_unique':  (PAN / 'figure4' / 'f4_decomp_unique_sep.pdf', 1),
    'st_quart':   (PAN / 'figure4' / 'f4_row2_quartiles_nc.pdf', 1),   # OL slope / CL slope / CL/OL, as JN's Fig 4D
    # 6 disturbance
    'd_kernel':   (PAN / 'figure4' / 'f4_kernel_map.pdf', 1),
    'd_agl':      (PAN / 'figure4' / 'f4_agl.pdf', 1),
    'd_rr':       (PAN / 'figure4' / 'f4_cl_reject_RR.pdf', 1),
}
# Placed size of the SVG in JN's Figure 1 (fig1_nc_build.py), where its text is 7 pt.
SVG_MM = {'loop': (118, 62)}
MM = 72 / 25.4
TEMPLATE = HERE.parents[1] / 'paper-writing' / 'PosterTemplate.pptx'
ARIAL = 'C:/Windows/Fonts/arial.ttf'


def open_pdf(path):
    if path.suffix != '.svg':
        return fitz.open(str(path))
    root = etree.parse(str(path)).getroot()          # the poster has no panel letters: drop JN's
    for t in list(root.iter('{http://www.w3.org/2000/svg}text')):
        if ''.join(t.itertext()).strip() in tuple('ABCDE'):
            t.getparent().remove(t)
    d = fitz.open(stream=etree.tostring(root), filetype='svg')
    return fitz.open('pdf', d.convert_to_pdf())


def ink(page):
    """Bounding box of everything drawn on the page, ignoring page-sized white backgrounds."""
    r = fitz.Rect()
    for kind, box in page.get_bboxlog():
        b = fitz.Rect(box)
        if kind.startswith('fill') and b.width >= page.rect.width * 0.98 and b.height >= page.rect.height * 0.98:
            continue
        r |= b
    return (r + (-PAD, -PAD, PAD, PAD)) & page.rect


def uw_logo():
    """The white W from the old poster template's logo, on transparent, so it sits on the header purple."""
    pic = next(sh for sh in Presentation(TEMPLATE).slides[0].shapes if sh.shape_type == 13 and sh.top < 914400)
    im = Image.open(io.BytesIO(pic.image.blob)).convert('L').crop((70, 128, 440, 384))
    im = im.resize((im.width * 4, im.height * 4), Image.LANCZOS)
    alpha = np.clip((np.asarray(im, float) - 40) / 215 * 255, 0, 255).astype(np.uint8)
    rgba = np.dstack([np.full_like(alpha, 255)] * 3 + [alpha])
    Image.fromarray(rgba, 'RGBA').save(OUT / 'uw_w.png')


def embed_font(page):
    """Reset base-14 Helvetica as embedded Arial (same metrics): a print shop needs every font embedded."""
    spans = [s for b in page.get_text('dict')['blocks'] for l in b.get('lines', []) for s in l['spans']
             if s['font'] == 'Helvetica']
    for s in spans:
        page.add_redact_annot(fitz.Rect(s['bbox']), fill=False, cross_out=False)
    page.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE, graphics=fitz.PDF_REDACT_LINE_ART_NONE,
                          text=fitz.PDF_REDACT_TEXT_REMOVE)
    for f in page.get_fonts(full=True):         # the redaction leaves its now unused resource behind
        if f[3] == 'Helvetica':
            page.parent.xref_set_key(page.xref, f'Resources/Font/{f[4]}', 'null')
    for s in spans:
        page.insert_text(s['origin'], s['text'], fontname='ar', fontfile=ARIAL, fontsize=s['size'], color=(0, 0, 0))


def smooth_rasters(doc, factor=6):
    """Resample embedded images smoothly so their pixels don't show at poster size. In memory only: adds no data."""
    for x in range(1, doc.xref_length()):
        if doc.xref_get_key(x, 'Subtype')[1] != '/Image':
            continue
        im = Image.open(io.BytesIO(doc.extract_image(x)['image'])).convert('RGB')
        im = im.resize((im.width * factor, im.height * factor), Image.BICUBIC)
        doc.update_stream(x, im.tobytes(), compress=True)
        doc.xref_set_key(x, 'Width', str(im.width))
        doc.xref_set_key(x, 'Height', str(im.height))


def main():
    OUT.mkdir(exist_ok=True)
    uw_logo()
    for name, (src, scale) in PANELS.items():
        s = open_pdf(src)
        if name == 'frame':
            embed_font(s[0])
        if name == 'd_kernel':      # 138 x 126 px in the panel, 44 dpi on the poster
            smooth_rasters(s)
        clip = ink(s[0])
        if name in SVG_MM:
            scale *= SVG_MM[name][0] * MM / s[0].rect.width
        d = fitz.open()
        p = d.new_page(width=clip.width * scale, height=clip.height * scale)
        p.show_pdf_page(p.rect, s, 0, clip=clip)
        d.save(str(OUT / f'{name}.pdf'), garbage=3, deflate=True)
        print(f'{name:11s} {p.rect.width / MM / 10:5.2f} x {p.rect.height / MM / 10:5.2f} cm')


if __name__ == '__main__':
    main()
