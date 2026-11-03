// Assemble JN Figure 2 from the fixed-canvas panels: 17.6 cm wide, two 3.0 cm rows, 0.4 cm between rows.
(function () {
  app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS;
  var ROOT = '/c/Users/aditya/Documents/projects/brain_paper/paper/figures_final/jn/';
  var cm = 72 / 2.54, W = 17.6, RH = 3.0, GAP = 0.4, H = 2 * RH + GAP;
  var doc = app.documents.add(DocumentColorSpace.RGB, W * cm, H * cm);
  var ab = doc.artboards[0].artboardRect, L = doc.layers[0];
  var crop = app.preferences.PDFFileOptions.pDFCropToBox;
  app.preferences.PDFFileOptions.pDFCropToBox = PDFBoxType.PDFMEDIABOX;

  function place(n, xcm, ycm) {
    var f = new File(ROOT + 'fig2/' + n + '.pdf');
    if (!f.exists) throw new Error('missing ' + n);
    var p = L.placedItems.add();
    p.file = f;
    var b = p.geometricBounds;
    p.translate(ab[0] + xcm * cm - b[0], ab[1] - ycm * cm - b[1]);
    return p;
  }
  var arial = app.textFonts.getByName('Arial-BoldMT');
  function letter(s, xcm, ycm) {
    var t = L.textFrames.add();
    t.contents = s;
    t.textRange.characterAttributes.textFont = arial;
    t.textRange.characterAttributes.size = 10;
    t.textRange.characterAttributes.fillColor = (function () { var c = new RGBColor(); c.red = c.green = c.blue = 0; return c; })();
    t.left = ab[0] + xcm * cm;
    t.top = ab[1] - ycm * cm;
    return t;
  }

  var top = [['A', 4.1], ['B', 3.7], ['C', 4.9], ['D', 3.3]], bot = [['E', 4.7], ['F', 3.5], ['G', 8.4]];
  var out = [], rows = [[top, 0], [bot, RH + GAP]], r, i;
  for (r = 0; r < 2; r++) {
    var row = rows[r][0], y = rows[r][1], used = 0;
    for (i = 0; i < row.length; i++) used += row[i][1];
    var g = (W - used) / (row.length - 1), x = 0;
    for (i = 0; i < row.length; i++) {
      var p = place(row[i][0], x, y);
      var b = p.geometricBounds;
      out.push(row[i][0] + ' x ' + x.toFixed(2) + ' y ' + y.toFixed(2) + ' w ' + ((b[2] - b[0]) / cm).toFixed(2) + ' h ' + ((b[1] - b[3]) / cm).toFixed(2));
      // letter at the panel's top-left: inside the first panel of a row, in the gap for the others
      letter(row[i][0], i == 0 ? 0 : x - 0.31, y - 0.02);
      x += row[i][1] + g;
    }
  }
  app.preferences.PDFFileOptions.pDFCropToBox = crop;

  var s = new IllustratorSaveOptions(); s.pdfCompatible = true; s.embedLinkedFiles = false;
  doc.saveAs(new File(ROOT + 'Figure2.ai'), s);
  var o = new PDFSaveOptions(); o.pDFPreset = '[Illustrator Default]'; o.preserveEditability = true; o.viewAfterSaving = false;
  doc.saveAs(new File(ROOT + 'Figure2.pdf'), o);
  doc.close(SaveOptions.DONOTSAVECHANGES);
  return out.join('\n');
})();
