"""Assemble JN Figure 4 in the layout Aditya chose (2026-11-14), from the current panels.

    python -X utf8 -I paper-writing/fig4_jn_build.py [--out DIR]

Layout, 17.6 cm wide, letters as Aditya set them (row 1 reads A, B, D):
  row 1  A state exemplar trials  |  B unique R^2 (error decomposition)  |  D CL/OL residual power
  row 2  C state quartile tiles                                         |  E 4C error split by frequency
  row 3  F predictor kernel map   |  G A = G + L                         |  H rejection ratio
The error-model equation panel is gone, and relative 1-4 Hz power is in the supplement (f4S_states).

Panel A is the 2026-11-14 MATLAB exemplar row (f4_state_exemplars.m, corrected onsets, L-2026-11-14-a)
without its relative-power tile: tiles 1, 2 and 4 are copied as vector clips and tile 4 moves left by
one tile pitch. Display only; each tile's trial was picked on its own state, so no trial changes.
B, C, D, E come from stats_v2/fig4_paper_panels.py (L-2026-11-16-a; B, the init + motion + absolute
model, L-2026-11-18-a; E, the 4C error split into < 1, 1-4 and > 4 Hz, L-2026-11-18-c). F and H are the figures_final panels
used since 2026-11-04 (f4_kernel_map.m, f4_cl_reject_panel.m); G is the 2026-11-14 f4_contra_model.m run.

Panels are copied to paper/figures_final/jn/fig4/, placed (linked) in Illustrator with their tops on
the row line and equal gaps across each row, and saved as Figure4.ai / Figure4.pdf, with a 300 dpi
Figure4.png. Illustrator is driven through COM, as labstyle_assemble.py and fig4g_relink.py do.
"""
import argparse
import json
import shutil
from pathlib import Path

import fitz
import win32com.client as win

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / 'paper' / 'images' / 'figure4'
PAN = ROOT / 'paper' / 'figures_final' / 'panels' / 'figure4'
JN = ROOT / 'paper' / 'figures_final' / 'jn'
CM = 72 / 2.54
W, ROW_GAP = 17.6, 0.3

SRC = {
    'B': IMG / 'paper_py' / 'f4B_unique.pdf',
    'C': IMG / 'paper_py' / 'f4C_quartiles.pdf',
    'D': IMG / 'paper_py' / 'f4D_sensitivity.pdf',
    'E': IMG / 'paper_py' / 'f4E_error_bands.pdf',
    'F': PAN / 'f4_kernel_map.pdf',
    'G': IMG / 'f4_agl.pdf',
    'H': PAN / 'f4_cl_reject_RR.pdf',
}
ROWS = [['A', 'B', 'D'], ['C', 'E'], ['F', 'G', 'H']]
INSET = {'F': 0.4}          # F's title starts at its left edge, so the row starts right of the letter

# f4_state_exemplars.pdf: four 54.5 pt tiles on a 222 x 102 pt page; grey stimulus bands end at
# 56.0 / 110.5 / 165.0 / 219.5 pt and each next tile's '1 s' bar starts about 5 pt later.
A_SRC = IMG / 'f4_state_exemplars.pdf'
A_KEEP = (0.0, 111.0)        # tiles 1 and 2
A_TILE4 = (165.3, 222.0)     # tile 4, moved left by one pitch
A_PITCH = 54.5


def make_A(out):
    src = fitz.open(A_SRC)
    r = src[0].rect
    assert (round(r.width), round(r.height)) == (222, 102), f'unexpected exemplar page {r}'
    titles = [s['text'] for b in src[0].get_text('dict')['blocks'] for ln in b.get('lines', []) for s in ln['spans']
              if s['text'].startswith('high')]
    assert titles == ['high init-dev', 'high motion', 'high rel 1-4 Hz', 'high abs 1-4 Hz'], titles
    w = A_KEEP[1] + (A_TILE4[1] - A_TILE4[0])
    doc = fitz.open()
    pg = doc.new_page(width=w, height=r.height)
    pg.show_pdf_page(fitz.Rect(A_KEEP[0], 0, A_KEEP[1], r.height), src, 0, clip=fitz.Rect(A_KEEP[0], 0, A_KEEP[1], r.height))
    x0 = A_TILE4[0] - A_PITCH
    pg.show_pdf_page(fitz.Rect(x0, 0, x0 + A_TILE4[1] - A_TILE4[0], r.height), src, 0,
                     clip=fitz.Rect(A_TILE4[0], 0, A_TILE4[1], r.height))
    doc.save(out, garbage=3, deflate=True)
    kept = [s['text'] for b in fitz.open(out)[0].get_text('dict')['blocks'] for ln in b.get('lines', [])
            for s in ln['spans'] if s['text'].startswith('high')]
    assert kept == ['high init-dev', 'high motion', 'high abs 1-4 Hz'], kept


JS = r"""
(function (root, ops, W, H) {
  app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS;
  var cm = 72 / 2.54;
  var doc = app.documents.add(DocumentColorSpace.RGB, W * cm, H * cm);
  var ab = doc.artboards[0].artboardRect, L = doc.layers[0];
  var crop = app.preferences.PDFFileOptions.pDFCropToBox;
  app.preferences.PDFFileOptions.pDFCropToBox = PDFBoxType.PDFMEDIABOX;
  var arial = app.textFonts.getByName('Arial-BoldMT'), out = [], i;
  var black = new RGBColor(); black.red = black.green = black.blue = 0;
  for (i = 0; i < ops.length; i++) {
    var o = ops[i], f = new File(root + 'fig4/' + o.n + '.pdf');
    if (!f.exists) throw new Error('missing ' + o.n);
    var p = L.placedItems.add();
    p.file = f;
    var b = p.geometricBounds;
    p.translate(ab[0] + o.x * cm - b[0], ab[1] - o.y * cm - b[1]);
    b = p.geometricBounds;
    out.push(o.n + ' x ' + o.x.toFixed(2) + ' y ' + o.y.toFixed(2) + ' w ' + ((b[2] - b[0]) / cm).toFixed(2) + ' h ' + ((b[1] - b[3]) / cm).toFixed(2));
    var t = L.textFrames.add();
    t.contents = o.n;
    t.textRange.characterAttributes.textFont = arial;
    t.textRange.characterAttributes.size = 10;
    t.textRange.characterAttributes.fillColor = black;
    t.left = ab[0] + o.lx * cm;
    t.top = ab[1] - (o.y - 0.02) * cm;
  }
  app.preferences.PDFFileOptions.pDFCropToBox = crop;
  var s = new IllustratorSaveOptions(); s.pdfCompatible = true; s.embedLinkedFiles = false;
  doc.saveAs(new File(root + 'Figure4.ai'), s);
  var pdf = new PDFSaveOptions(); pdf.pDFPreset = '[Illustrator Default]'; pdf.preserveEditability = true; pdf.viewAfterSaving = false;
  doc.saveAs(new File(root + 'Figure4.pdf'), pdf);
  doc.close(SaveOptions.DONOTSAVECHANGES);
  return out.join('\n');
})(%s, %s, %s, %s);
"""


def layout(sizes):
    """Equal gaps across each row, tops on the row line; letter in the gap left of each panel
    (inside the first panel of a row), as fig2_jn_build.jsx."""
    ops, y = [], 0.0
    for row in ROWS:
        x0 = INSET.get(row[0], 0.0)
        used = sum(sizes[n][0] for n in row)
        g = (W - x0 - used) / (len(row) - 1)
        assert g >= 0.35, f'row {row}: {used:.2f} cm of panels leaves {g:.2f} cm gaps'
        x = x0
        for i, n in enumerate(row):
            ops.append({'n': n, 'x': round(x, 3), 'y': round(y, 3), 'lx': round(0.0 if i == 0 else x - 0.31, 3)})
            x += sizes[n][0] + g
        y += max(sizes[n][1] for n in row) + ROW_GAP
    return ops, y - ROW_GAP


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=str(JN), help='folder for fig4/ and Figure4.*')
    a = ap.parse_args()
    out = Path(a.out).resolve()
    (out / 'fig4').mkdir(parents=True, exist_ok=True)
    make_A(out / 'fig4' / 'A.pdf')
    for n, s in SRC.items():
        shutil.copy2(s, out / 'fig4' / f'{n}.pdf')
    sizes = {}
    for n in 'ABCDEFGH':
        r = fitz.open(out / 'fig4' / f'{n}.pdf')[0].rect
        sizes[n] = (r.width / CM, r.height / CM)
        print(f'{n} {sizes[n][0]:.2f} x {sizes[n][1]:.2f} cm')
    ops, H = layout(sizes)
    app = win.Dispatch('Illustrator.Application')
    app.UserInteractionLevel = -1
    print(app.DoJavaScript(JS % (json.dumps(out.as_posix() + '/'), json.dumps(ops), W, round(H, 3))))
    d = fitz.open(out / 'Figure4.pdf')
    print(f'Figure4.pdf {d[0].rect.width / CM:.2f} x {d[0].rect.height / CM:.2f} cm')
    d[0].get_pixmap(dpi=300, alpha=False).save(out / 'Figure4.png')


if __name__ == '__main__':
    main()
