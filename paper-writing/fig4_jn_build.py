"""Assemble JN Figure 4 from the current panels, one story per row (Aditya 2026-11-19: "A,B must tell
same story, DCE is same story and FGH is same story").

    python -X utf8 -I paper-writing/fig4_jn_build.py [--out DIR]

Layout, 17.6 cm wide, letters as Aditya set them (row 2 reads D, C, E):
  row 1  A state exemplar trials (0-1 s and 1-3 s shaded)  |  B unique R^2 in those two windows
  row 2  D CL/OL residual power  |  C state quartile tiles  |  E Q4/Q1 state spectra
  row 3  F predictor kernel map  |  G A = G + L  |  H rejection ratio

A is f4_state_exemplars.m (JN version, 3 tiles, same picks as 2026-11-14, L-2026-11-19-b; 0 and target
lines and 8.4 x 3.2 cm, L-2026-11-19-e). B, C, D, E
come from stats_v2/fig4_paper_panels.py (L-2026-11-16-a; B L-2026-11-18-a; E L-2026-11-18-b/-d and
L-2026-11-19-a; row-2 sizes L-2026-11-19-b). F and G are f4_kernel_map.m and f4_contra_model.m re-run
2026-11-19 at the row-3 sizes (F drawn as squares, L-2026-11-19-e); H is the figures_final panel used since 2026-11-04 (f4_cl_reject_panel.m
needs a fresh f4_cl_reject_lmm.m run, not done).

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
    'A': IMG / 'f4A_exemplars_jn.pdf',
    'B': IMG / 'paper_py' / 'f4B_unique.pdf',
    'C': IMG / 'paper_py' / 'f4C_quartiles.pdf',
    'D': IMG / 'paper_py' / 'f4D_sensitivity.pdf',
    'E': IMG / 'paper_py' / 'f4E_state_spectra.pdf',
    'F': IMG / 'f4_kernel_map.pdf',
    'G': IMG / 'f4_agl.pdf',
    'H': PAN / 'f4_cl_reject_RR.pdf',
}
ROWS = [['A', 'B'], ['D', 'C', 'E'], ['F', 'G', 'H']]
INSET = {'F': 0.4}          # F's title starts at its left edge, so the row starts right of the letter


def check_A(path):
    """The JN 4A has the three state tiles of 4B, in 4B's order and names."""
    want = ['Initial deviation', 'Motion', 'Abs 1–4 Hz']
    titles = [s['text'] for b in fitz.open(path)[0].get_text('dict')['blocks'] for ln in b.get('lines', [])
              for s in ln['spans'] if s['text'] in want]
    assert titles == want, titles


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
    check_A(SRC['A'])
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
