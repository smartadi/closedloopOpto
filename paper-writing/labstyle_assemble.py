"""Assemble the JN figures with lab-style panels, in the current layouts, for a side-by-side comparison.

    python paper-writing/labstyle_assemble.py map      which panel is which in each layout (no writes but the map)
    python paper-writing/labstyle_assemble.py build    write current + lab PDFs and the comparison sheets

Added 2026-11-05 (Aditya: "remake all paper figures ... put them in a folder, I want to compare changes to the
current plotting setup"). The lab-style panels come from running the producers with the global PAPER_LABSTYLE on
(paper-writing/labstyle_remake.m), which writes them to paper/figures_labstyle/panels/<section>/ (and
jn/fig2/ for Figure 2) and never touches figures_final.

How a layout is converted. Illustrator opens each JN assembly (.ai, read only: the document is only ever
"saved as" a PDF in paper/figures_labstyle/, never saved over itself). Two kinds of panel are in there:
  * linked panels (PlacedItem): relinked to the lab-style file of the same name, top-left corner kept;
  * embedded panels (a group of vector art, most of Figs 3, 6, S2, S_varx, OLbest): identified by their text.
    Every word in the group is compared with the words of every final panel PDF (multiset Jaccard); the best
    match must score >= MIN_SCORE and beat the runner-up by MARGIN. The group's printed scale is its width
    over the current panel's width (checked against the height). The group is replaced by the lab panel at
    that scale, top-left corner kept, in the same stacking position.
Everything else (panel letters, schematics, hand-drawn keys, raster maps) stays exactly as it is. A panel
with no lab-style version (producer not rerun or failed) also stays, and is listed.
The "current" PDF is the same .ai saved as PDF with nothing changed, so the two differ only in the panels.

Outputs in paper/figures_labstyle/:  assembled/<name>_current.pdf, assembled/<name>_lab.pdf (+ .png),
compare/<name>_compare.png (current left, lab right), assembly_map.json, assembly_log.txt.
Hand edits made in Illustrator to an embedded panel are lost in the lab version (it is re-exported), and the
log says which groups were swapped, so check those panels for edits that matter.
"""
import json

import sys

from pathlib import Path

import fitz
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FINAL = ROOT / 'paper' / 'figures_final'
LAB = ROOT / 'paper' / 'figures_labstyle'
MM = 72 / 25.4
MIN_R, MARGIN = 0.60, 0.05          # appearance match: correlation of ink images, and lead over the runner-up

# JN include name -> assembly (relative to figures_final). Figure 1 and S_state_quartile are Python builds.
FIGS = [('Figure2', 'jn/Figure2.ai'), ('Figure3', 'jn/Figure3.ai'), ('Figure4', 'jn/Figure4.ai'),
        ('Figure5', 'jn/Figure5.ai'), ('Figure6', 'FigureMPC.ai'), ('S1', 'jn/S1.ai'), ('S2', 'S2.ai'),
        ('OLbest', 'OLbest.ai'), ('S3', 'jn/S3.ai'), ('S_varx', 'varx.ai')]

JS_DUMP = r"""
(function (src, curPdf) {
  var crop = app.preferences.PDFFileOptions.pDFCropToBox;
  app.preferences.PDFFileOptions.pDFCropToBox = PDFBoxType.PDFMEDIABOX;
  var doc = app.open(new File(src)), out = [], L, i, it;
  var o = new PDFSaveOptions();
  o.pDFPreset = '[Illustrator Default]'; o.preserveEditability = false; o.viewAfterSaving = false;
  doc.saveAs(new File(curPdf), o);                  // the layout as it is (the .ai itself is never saved)
  function texts(x) {
    var r = [], j;
    if (x.typename == 'TextFrame') r.push(x.contents.replace(/[\r\n\u0003]+/g, ' '));
    else if (x.typename == 'GroupItem') for (j = 0; j < x.pageItems.length; j++) r = r.concat(texts(x.pageItems[j]));
    return r;
  }
  for (L = 0; L < doc.layers.length; L++) {
    var lay = doc.layers[L];
    for (i = 0; i < lay.pageItems.length; i++) {
      it = lay.pageItems[i];
      var f = '';
      if (it.typename == 'PlacedItem') { try { f = it.file.fsName; } catch (e) { f = 'MISSING'; } }
      out.push([L, i, it.typename, it.geometricBounds.join(','), f, texts(it).join('\u0001')].join('\u0002'));
    }
  }
  var ab = doc.artboards[0].artboardRect.join(',');
  doc.close(SaveOptions.DONOTSAVECHANGES);
  app.preferences.PDFFileOptions.pDFCropToBox = crop;
  return ab + '\u0004' + out.join('\u0004');
})('%s', '%s');
"""

JS_BUILD = r"""
(function (src, ops, curPdf, labPdf) {
  var crop = app.preferences.PDFFileOptions.pDFCropToBox;
  app.preferences.PDFFileOptions.pDFCropToBox = PDFBoxType.PDFMEDIABOX;
  var doc = app.open(new File(src)), log = [], k;
  function pdfOpts() {
    var o = new PDFSaveOptions();
    o.pDFPreset = '[Illustrator Default]'; o.preserveEditability = false; o.viewAfterSaving = false;
    return o;
  }
  doc.saveAs(new File(curPdf), pdfOpts());          // the layout as it is
  var items = [];
  for (k = 0; k < ops.length; k++) items.push(doc.layers[ops[k].layer].pageItems[ops[k].idx]);
  for (k = 0; k < ops.length; k++) {
    var op = ops[k], it = items[k], b0 = it.geometricBounds, p;
    if (op.kind == 'relink') {
      it.file = new File(op.lab);
      p = it;
    } else {
      p = it.layer.placedItems.add();
      p.file = new File(op.lab);
      if (Math.abs(op.scale - 1) > 1e-4) p.resize(op.scale * 100, op.scale * 100, true, true, true, true, op.scale * 100, Transformation.TOPLEFT);
      p.move(it, ElementPlacement.PLACEBEFORE);
      it.remove();
    }
    var b = p.geometricBounds;
    p.translate(b0[0] - b[0], b0[1] - b[1]);
    b = p.geometricBounds;
    log.push(op.name + ' ' + op.kind + ' size ' + ((b0[2] - b0[0]) / 28.3465).toFixed(2) + 'x' + ((b0[1] - b0[3]) / 28.3465).toFixed(2)
             + ' -> ' + ((b[2] - b[0]) / 28.3465).toFixed(2) + 'x' + ((b[1] - b[3]) / 28.3465).toFixed(2) + ' cm');
  }
  doc.saveAs(new File(labPdf), pdfOpts());
  doc.close(SaveOptions.DONOTSAVECHANGES);
  app.preferences.PDFFileOptions.pDFCropToBox = crop;
  return log.join('\n');
})('%s', %s, '%s', '%s');
"""


DPI, SIDE = 150, 96          # render resolution for matching; compared at SIDE px on the longer side


def gray(pix):
    a = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)[..., :3].mean(axis=2)
    return 255.0 - a                                         # ink, not paper


def small(img, w, h):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)
    return np.asarray(im, dtype=float)


def corr(a, b):
    a, b = a - a.mean(), b - b.mean()
    d = np.sqrt((a * a).sum() * (b * b).sum())
    return float((a * b).sum() / d) if d > 0 else 0.0


def candidates():
    """Every final panel PDF, rendered once (ink image) with its page size in pt."""
    c = {}
    for p in sorted((FINAL / 'panels').rglob('*.pdf')) + sorted((FINAL / 'jn' / 'fig2').glob('*.pdf')):
        try:
            page = fitz.open(p)[0]
        except Exception:
            continue
        c[p] = dict(img=gray(page.get_pixmap(dpi=DPI)), size=(page.rect.width, page.rect.height))
    return c


def match(crop, cands):
    """Best panel for an image crop of an embedded group: aspect within 8 %, then correlation at SIDE px."""
    h, w = crop.shape
    if w < 8 or h < 8 or crop.std() < 1:
        return []
    asp = w / h
    sw, sh = (SIDE, max(4, round(SIDE / asp))) if asp >= 1 else (max(4, round(SIDE * asp)), SIDE)
    a = small(crop, sw, sh)
    out = []
    for p, c in cands.items():
        cw, ch = c['size']
        if abs((cw / ch) / asp - 1) > 0.08:
            continue
        out.append((corr(a, small(c['img'], sw, sh)), p))
    return sorted(out, key=lambda x: -x[0])


def lab_twin(cur: Path):
    """The lab-style file for a current panel path, or None."""
    rel = cur.resolve().relative_to(FINAL.resolve())
    twin = LAB / rel
    return twin if twin.exists() else None


def illustrator():
    import win32com.client as win
    app = win.Dispatch('Illustrator.Application')
    app.UserInteractionLevel = -1                    # no dialogs
    return app


def make_map(app):
    cands = candidates()
    asm = LAB / 'assembled'
    asm.mkdir(parents=True, exist_ok=True)
    out = {}
    for name, ai in FIGS:
        cur = asm / f'{name}_current.pdf'
        raw = app.DoJavaScript(JS_DUMP % ((FINAL / ai).as_posix(), cur.as_posix()))
        ab, *rows = raw.split('\u0004')
        abL, abT = [float(x) for x in ab.split(',')][:2]
        page = gray(fitz.open(cur)[0].get_pixmap(dpi=DPI))
        k = DPI / 72
        items, ops = [], []
        for r in rows:
            L, i, typ, bnds, f, _ = r.split('\u0002')
            b = [float(x) for x in bnds.split(',')]
            w, h = b[2] - b[0], b[1] - b[3]
            item = dict(layer=int(L), idx=int(i), type=typ, bounds=b)
            if typ == 'PlacedItem':
                p = Path(f)
                item.update(file=str(p))
                twin = lab_twin(p) if f != 'MISSING' else None
                item['lab'] = str(twin) if twin else None
                if twin:
                    ops.append(dict(kind='relink', layer=int(L), idx=int(i), name=p.name, lab=twin.as_posix()))
            elif typ == 'GroupItem' and w > 20 and h > 10:
                x0, y0 = round((b[0] - abL) * k), round((abT - b[1]) * k)
                x1, y1 = round((b[2] - abL) * k), round((abT - b[3]) * k)
                sc = match(page[max(y0, 0):y1, max(x0, 0):x1], cands)
                if sc:
                    (r1, p1) = sc[0]
                    r2 = sc[1][0] if len(sc) > 1 else 0.0
                    item.update(best=str(p1), score=round(r1, 3), runner_up=round(r2, 3))
                    if r1 >= MIN_R and r1 - r2 >= MARGIN:
                        cw, chh = cands[p1]['size']
                        sx, sy = w / cw, h / chh
                        scale = sx if abs(sx - sy) / max(sx, sy) < 0.05 else 1.0
                        item.update(scale=round(scale, 4), scale_xy=[round(sx, 4), round(sy, 4)])
                        twin = lab_twin(p1)
                        item['lab'] = str(twin) if twin else None
                        if twin:
                            ops.append(dict(kind='swap', layer=int(L), idx=int(i), name=p1.name,
                                            lab=twin.as_posix(), scale=scale))
            items.append(item)
        out[name] = dict(ai=ai, artboard=ab, items=items, ops=ops)
        sw = sum(o['kind'] == 'swap' for o in ops)
        rl = sum(o['kind'] == 'relink' for o in ops)
        print(f'{name:8s} {ai:18s} items {len(items):3d}  relink {rl:2d}  swap {sw:2d}')
        for it in items:
            if it['type'] == 'PlacedItem':
                print(f'   linked  {Path(it["file"]).name:48s} lab: {"yes" if it.get("lab") else "NO"}')
            elif 'best' in it:
                ok = 'scale' in it
                bw, bh = (it['bounds'][2] - it['bounds'][0]) / 28.3465, (it['bounds'][1] - it['bounds'][3]) / 28.3465
                print(f'   group   {Path(it["best"]).parent.name + "/" + Path(it["best"]).name:58s} r {it["score"]:.2f} '
                      f'(next {it["runner_up"]:.2f}) {bw:5.2f}x{bh:4.2f} cm'
                      f'{"  UNMATCHED" if not ok else ("  x%.3f" % it["scale"])}'
                      f'{"" if not ok else ("  lab: yes" if it.get("lab") else "  lab: NO")}')
            elif it['type'] == 'GroupItem':
                bw, bh = (it['bounds'][2] - it['bounds'][0]) / 28.3465, (it['bounds'][1] - it['bounds'][3]) / 28.3465
                print(f'   group   (no candidate)  {bw:5.2f}x{bh:4.2f} cm')
    (LAB / 'assembly_map.json').write_text(json.dumps(out, indent=1), encoding='utf-8')
    return out


def compare_sheet(name, cur, lab, outdir):
    a, b = fitz.open(cur), fitz.open(lab)
    ra, rb = a[0].rect, b[0].rect
    gap, head = 24, 22
    W = ra.width + rb.width + 3 * gap
    H = max(ra.height, rb.height) + head + 2 * gap
    doc = fitz.open()
    pg = doc.new_page(width=W, height=H)
    pg.insert_text(fitz.Point(gap, gap + 8), f'{name}: current (jn style)', fontname='hebo', fontsize=10)
    pg.insert_text(fitz.Point(2 * gap + ra.width, gap + 8), f'{name}: lab style (steinmetzlab-style)', fontname='hebo',
                   fontsize=10)
    r1 = fitz.Rect(gap, gap + head, gap + ra.width, gap + head + ra.height)
    r2 = fitz.Rect(2 * gap + ra.width, gap + head, 2 * gap + ra.width + rb.width, gap + head + rb.height)
    pg.draw_rect(r1, color=(0.8, 0.8, 0.8), width=0.5)
    pg.draw_rect(r2, color=(0.8, 0.8, 0.8), width=0.5)
    pg.show_pdf_page(r1, a, 0)
    pg.show_pdf_page(r2, b, 0)
    out = outdir / f'{name}_compare.png'
    pg.get_pixmap(dpi=200).save(out)
    return out


def build(app, M):
    asm, cmp_ = LAB / 'assembled', LAB / 'compare'
    asm.mkdir(parents=True, exist_ok=True)
    cmp_.mkdir(parents=True, exist_ok=True)
    log = []
    for name, ai in FIGS:
        m = M[name]
        cur, lab = asm / f'{name}_current.pdf', asm / f'{name}_lab.pdf'
        ops = [dict(kind=o['kind'], layer=o['layer'], idx=o['idx'], name=o['name'], lab=o['lab'],
                    scale=o.get('scale', 1.0)) for o in m['ops']]
        res = app.DoJavaScript(JS_BUILD % ((FINAL / ai).as_posix(), json.dumps(ops), cur.as_posix(), lab.as_posix()))
        kept = [it for it in m['items'] if it['type'] == 'PlacedItem' and not it.get('lab')]
        kept += [it for it in m['items'] if it['type'] == 'GroupItem' and 'scale' in it and not it.get('lab')]
        log.append(f'== {name} ({ai}): {len(ops)} panels swapped\n{res}')
        for it in kept:
            log.append(f'   KEPT (no lab version): {Path(it.get("file") or it.get("best")).name}')
        for p in (cur, lab):
            fitz.open(p)[0].get_pixmap(dpi=300).save(p.with_suffix('.png'))
        compare_sheet(name, cur, lab, cmp_)
        print(f'{name}: {len(ops)} swapped, {len(kept)} kept')
    (LAB / 'assembly_log.txt').write_text('\n'.join(log) + '\n', encoding='utf-8')


def main(cmd='map'):
    app = illustrator()
    if cmd == 'map':
        make_map(app)
    elif cmd == 'build':
        build(app, make_map(app))
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(*sys.argv[1:])
