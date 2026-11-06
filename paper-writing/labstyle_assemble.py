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
import shutil

import sys

from pathlib import Path

import fitz
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FINAL = ROOT / 'paper' / 'figures_final'
LAB = ROOT / 'paper' / 'figures_labstyle'
MM = 72 / 25.4
NL = '\n'
FIG_DRIFT, PANEL_DRIFT = 0.97, 0.95   # blurred-render correlation below which a paper copy is said to differ
MIN_R, MARGIN = 0.60, 0.05          # appearance match: correlation of ink images, and lead over the runner-up

# JN include name -> assembly (relative to figures_final). Figure 1 and S_state_quartile are Python builds.
FIGS = [('Figure2', 'jn/Figure2.ai'), ('Figure3', 'jn/Figure3.ai'), ('Figure4', 'jn/Figure4.ai'),
        ('Figure5', 'jn/Figure5.ai'), ('Figure6', 'FigureMPC.ai'), ('S1', 'jn/S1.ai'), ('S2', 'S2.ai'),
        ('OLbest', 'OLbest.ai'), ('S3', 'jn/S3.ai'), ('S_varx', 'varx.ai')]
# paper order (JN main.tex, supplementary.tex): the comparison sheets follow it
ORDER = ['Figure1', 'Figure2', 'Figure3', 'Figure4', 'Figure5', 'Figure6',
         'S1', 'S_state_quartile', 'S2', 'OLbest', 'S3', 'S_varx']

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


def assign(pending, used):
    """One-to-one assignment for groups whose best match did not lead by MARGIN (the S2 gain-grid nodes look
    alike): repeatedly take the highest-scoring (group, panel) pair whose group and panel are both still free.
    pending: {item index: [(r, path), ...]}; used: panels already taken in this figure. Returns {item: (r, path)}."""
    pairs = sorted(((r, i, p) for i, sc in pending.items() for r, p in sc if r >= MIN_R and p not in used),
                   key=lambda x: -x[0])
    got, taken = {}, set(used)
    for r, i, p in pairs:
        if i not in got and p not in taken:
            got[i] = (r, p)
            taken.add(p)
    return got


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
        items, ops, pending, used = [], [], {}, set()

        def accept(item, p1, r1, how):
            b = item['bounds']
            w, h = b[2] - b[0], b[1] - b[3]
            cw, chh = cands[p1]['size']
            sx, sy = w / cw, h / chh
            scale = sx if abs(sx - sy) / max(sx, sy) < 0.05 else 1.0
            item.update(best=str(p1), score=round(r1, 3), how=how, scale=round(scale, 4),
                        scale_xy=[round(sx, 4), round(sy, 4)])
            used.add(p1)
            twin = lab_twin(p1)
            item['lab'] = str(twin) if twin else None
            if twin:
                ops.append(dict(kind='swap', layer=item['layer'], idx=item['idx'], name=p1.name,
                                lab=twin.as_posix(), scale=scale))

        for r in rows:
            L, i, typ, bnds, f, _ = r.split('\u0002')
            b = [float(x) for x in bnds.split(',')]
            w, h = b[2] - b[0], b[1] - b[3]
            item = dict(layer=int(L), idx=int(i), type=typ, bounds=b)
            items.append(item)
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
                        accept(item, p1, r1, 'clear')
                    elif r1 >= MIN_R:
                        pending[len(items) - 1] = sc
        for j, (r1, p1) in assign(pending, used).items():
            accept(items[j], p1, r1, 'assigned')
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
                      f'{"  (assigned 1:1)" if it.get("how") == "assigned" else ""}'
                      f'{"" if not ok else ("  lab: yes" if it.get("lab") else "  lab: NO")}')
            elif it['type'] == 'GroupItem':
                bw, bh = (it['bounds'][2] - it['bounds'][0]) / 28.3465, (it['bounds'][1] - it['bounds'][3]) / 28.3465
                print(f'   group   (no candidate)  {bw:5.2f}x{bh:4.2f} cm')
    (LAB / 'assembly_map.json').write_text(json.dumps(out, indent=1), encoding='utf-8')
    return out


def compare_sheet(name, left, right, labels, out_png):
    """Two versions of a figure side by side on one page; saves a 200-dpi PNG and returns the page."""
    a, b = fitz.open(left), fitz.open(right)
    ra, rb = a[0].rect, b[0].rect
    gap, head = 24, 22
    doc = fitz.open()
    pg = doc.new_page(width=ra.width + rb.width + 3 * gap, height=max(ra.height, rb.height) + head + 2 * gap)
    pg.insert_text(fitz.Point(gap, gap + 8), f'{name}: {labels[0]}', fontname='hebo', fontsize=10)
    pg.insert_text(fitz.Point(2 * gap + ra.width, gap + 8), f'{name}: {labels[1]}', fontname='hebo', fontsize=10)
    r1 = fitz.Rect(gap, gap + head, gap + ra.width, gap + head + ra.height)
    r2 = fitz.Rect(2 * gap + ra.width, gap + head, 2 * gap + ra.width + rb.width, gap + head + rb.height)
    for r in (r1, r2):
        pg.draw_rect(r, color=(0.8, 0.8, 0.8), width=0.5)
    pg.show_pdf_page(r1, a, 0)
    pg.show_pdf_page(r2, b, 0)
    pg.get_pixmap(dpi=200).save(out_png)
    return doc


def page_similarity(p1, p2, dpi=72, blur_mm=1.0):
    """Correlation of two single-page PDFs rendered at the same size (1.0 = identical ink). Both are blurred by
    about 1 mm first: two renders of the same line art sit a pixel or two apart, which alone sends the raw
    correlation of thin lines to 0.3-0.5 (seen 2026-11-05 on panels that are identical by eye)."""
    from PIL import ImageFilter
    a, b = fitz.open(p1)[0], fitz.open(p2)[0]
    ia, ib = gray(a.get_pixmap(dpi=dpi)), gray(b.get_pixmap(dpi=dpi))
    h, w = ia.shape
    rad = blur_mm / 25.4 * dpi
    f = lambda x: np.asarray(Image.fromarray(np.clip(x, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(rad)), float)
    return corr(f(ia), f(small(ib, w, h)))


def drift_report():
    """Every final panel against today's jn re-render of it: where the paper's panel no longer matches what
    its producer draws now (data, code or wording changed since the panel was locked), the style comparison
    is not like for like for that panel, so it is listed."""
    rows = []
    for jn in sorted((LAB / 'jnrerun' / 'panels').rglob('*.pdf')):
        fin = FINAL / 'panels' / jn.parent.name / jn.name
        if not fin.exists():
            continue
        fa, fb = fitz.open(fin)[0].rect, fitz.open(jn)[0].rect
        rows.append((page_similarity(fin, jn), f'{jn.parent.name}/{jn.name}', fa.width / MM / 10, fa.height / MM / 10,
                     fb.width / MM / 10, fb.height / MM / 10))
    rows.sort()
    lines = ['Final panels vs the same panel re-rendered today in jn style (correlation of the rendered pages; '
             "1.00 = identical). Below PANEL_DRIFT the paper's panel differs from what its producer draws now.", '']
    lines += [f'{r:5.3f}  {n:62s} paper {aw:5.2f} x {ah:5.2f} cm   today {bw:5.2f} x {bh:5.2f} cm'
              for r, n, aw, ah, bw, bh in rows]
    (LAB / 'drift_panels.txt').write_text(NL.join(lines) + NL, encoding='utf-8')
    return [(r, n) for r, n, *_ in rows if r < PANEL_DRIFT]


def figure_drift():
    """Paper copy vs jn re-render, per figure: a side-by-side sheet in drift/ for each figure below FIG_DRIFT."""
    asm, dft = LAB / 'assembled', LAB / 'drift'
    shutil.rmtree(dft, ignore_errors=True)
    dft.mkdir(parents=True, exist_ok=True)
    drift, changed = fitz.open(), []
    for name in ORDER:
        cur, jn = asm / f'{name}_current.pdf', asm / f'{name}_jnrerun.pdf'
        if not (cur.exists() and jn.exists()):
            continue
        r = page_similarity(cur, jn)
        print(f'   drift {name:18s} {r:.3f}')
        if r < FIG_DRIFT:
            changed.append(f'{name} {r:.3f}')
            drift.insert_pdf(compare_sheet(name, cur, jn, ('in the paper now', 'jn style, re-rendered today'),
                                           dft / f'{name}_paper_vs_today.png'))
    if len(drift):
        drift.save(dft / 'ALL_paper_vs_today.pdf')
    return changed, drift_report()


def build(app, M):
    asm, cmp_, dft = LAB / 'assembled', LAB / 'compare', LAB / 'drift'
    for d in (asm, cmp_, dft):
        d.mkdir(parents=True, exist_ok=True)
    log = []
    for name, ai in FIGS:
        m = M[name]
        cur = asm / f'{name}_current.pdf'
        for tag, top in (('jnrerun', LAB / 'jnrerun'), ('lab', LAB)):
            ops = []
            for o in m['ops']:
                twin = top / Path(o['lab']).relative_to(LAB)
                if twin.exists():
                    ops.append(dict(kind=o['kind'], layer=o['layer'], idx=o['idx'], name=o['name'],
                                    lab=twin.as_posix(), scale=o.get('scale', 1.0)))
            out = asm / f'{name}_{tag}.pdf'
            res = app.DoJavaScript(JS_BUILD % ((FINAL / ai).as_posix(), json.dumps(ops), cur.as_posix(), out.as_posix()))
            log.append(f'== {name} ({ai}) {tag}: {len(ops)} panels swapped{NL}{res}')
            print(f'{name} {tag}: {len(ops)} swapped')
        kept = [it for it in m['items'] if it['type'] == 'PlacedItem' and not it.get('lab')]
        kept += [it for it in m['items'] if it['type'] == 'GroupItem' and 'scale' in it and not it.get('lab')]
        for it in kept:
            log.append(f'   KEPT as in the paper (no re-render): {Path(it.get("file") or it.get("best")).name}')
    # Python-built figures (fig1_nc_build.py / supp_impulse_state_nc_build.py with jnlab / jnrerun)
    shutil.copyfile(FINAL / 'jn' / 'Figure1.pdf', asm / 'Figure1_current.pdf')
    shutil.copyfile(FINAL / 'jn' / 'Figure1.pdf', asm / 'Figure1_jnrerun.pdf')   # its one plot: same code + data
    shutil.copyfile(FINAL / 'jn' / 'S_state_quartile.pdf', asm / 'S_state_quartile_current.pdf')
    log.append('== Figure1, S_state_quartile: Python builds (jnlab / jnrerun drafts); Figure 1 jn = the paper copy')
    sheets = fitz.open()
    for name in ORDER:
        cur, jn, lab = (asm / f'{name}_{t}.pdf' for t in ('current', 'jnrerun', 'lab'))
        if not (lab.exists() and jn.exists()):
            log.append(f'== {name}: missing a version')
            continue
        for p in (cur, jn, lab):
            fitz.open(p)[0].get_pixmap(dpi=300).save(p.with_suffix('.png'))
        sheets.insert_pdf(compare_sheet(name, jn, lab, ("our jn style (today's code)", 'lab style (steinmetzlab-style)'),
                                        cmp_ / f'{name}_compare.png'))
    sheets.save(cmp_ / 'ALL_compare.pdf')
    changed, low = figure_drift()
    log.append('== figures whose jn re-render differs from the paper copy: ' + ', '.join(changed))
    log.append(f'== panels below {PANEL_DRIFT} (see drift_panels.txt): ' + ', '.join(f'{n} {r:.2f}' for r, n in low))
    (LAB / 'assembly_log.txt').write_text(NL.join(log) + NL, encoding='utf-8')
    print(NL.join(log[-2:]))


def main(cmd='map'):
    app = illustrator() if cmd != 'drift' else None
    if cmd == 'map':
        make_map(app)
    elif cmd == 'build':
        build(app, make_map(app))
    elif cmd == 'drift':
        changed, low = figure_drift()
        print('figures:', ', '.join(changed))
        print('panels:', ', '.join(f'{n} {r:.2f}' for r, n in low))
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(*sys.argv[1:])
