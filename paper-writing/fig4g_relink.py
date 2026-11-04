"""Swap the embedded Fig 4G in a draft's Figure4.ai for a link to the current panel.

    python paper-writing/fig4g_relink.py jn|nc [in_dir out_dir]

Fig 4G was embedded as vector art in both assemblies, so it kept the within-panel session letters
(Mouse3a, 1g, ...) after the panel moved to the paper-wide labels of utils/paper_session_label.m
(Mouse3e, 1l, ...). The new link takes the old group's place, with its axes on the same spot, under the same panel letter.
Run once on 2026-11-04; kept as the record and for the other PC. Originals: <draft>/_before_2026-11-04/.
"""
import sys
from pathlib import Path

import win32com.client as win

FINAL = Path(__file__).resolve().parents[1] / 'paper' / 'figures_final'
PANEL = FINAL / 'panels' / 'figure4' / 'f4_cl_reject_RR.pdf'
OLD_G = (334.83, -210.18, 479.33, -303.80)      # left, top, right, bottom of the embedded group, pt
SHIFT = (0.06, -0.66)                           # pt, puts the panel's axes where the old group's were (measured at 1200 dpi)

JS = r"""
(function (src, out, panel) {
  var crop = app.preferences.PDFFileOptions.pDFCropToBox;
  app.preferences.PDFFileOptions.pDFCropToBox = PDFBoxType.PDFMEDIABOX;
  var doc = app.open(new File(src)), L = doc.layers[0], old = [], i;
  for (i = 0; i < L.groupItems.length; i++) {
    var b = L.groupItems[i].geometricBounds;
    if (Math.abs(b[0] - %f) < .05 && Math.abs(b[1] - (%f)) < .05 && Math.abs(b[2] - %f) < .05 && Math.abs(b[3] - (%f)) < .05)
      old.push(L.groupItems[i]);
  }
  if (old.length != 1) { doc.close(SaveOptions.DONOTSAVECHANGES); throw new Error('found ' + old.length + ' G groups'); }
  var o = old[0].geometricBounds, p = L.placedItems.add();
  p.file = new File(panel);
  var g = p.geometricBounds;
  p.translate(o[0] - g[0] + %f, o[1] - g[1] + %f);
  p.move(old[0], ElementPlacement.PLACEBEFORE);
  old[0].remove();
  var a = new IllustratorSaveOptions(); a.pdfCompatible = true; a.embedLinkedFiles = false;
  doc.saveAs(new File(out + '/Figure4.ai'), a);
  var f = new PDFSaveOptions();
  f.pDFPreset = '[Illustrator Default]'; f.preserveEditability = true; f.viewAfterSaving = false;
  doc.saveAs(new File(out + '/Figure4.pdf'), f);
  var r = p.geometricBounds;
  doc.close(SaveOptions.DONOTSAVECHANGES);
  app.preferences.PDFFileOptions.pDFCropToBox = crop;
  return 'placed L' + r[0].toFixed(2) + ' T' + r[1].toFixed(2) + ' R' + r[2].toFixed(2) + ' B' + r[3].toFixed(2);
})('%s', '%s', '%s');
"""


def main(draft, src=None, out=None):
    src = Path(src) if src else FINAL / draft
    out = Path(out) if out else FINAL / draft
    out.mkdir(parents=True, exist_ok=True)
    app = win.Dispatch('Illustrator.Application')
    app.UserInteractionLevel = -1                # no dialogs
    js = JS % (*OLD_G, *SHIFT, (src / 'Figure4.ai').as_posix(), out.as_posix(), PANEL.as_posix())
    print(draft, app.DoJavaScript(js))


if __name__ == '__main__':
    main(*sys.argv[1:])
