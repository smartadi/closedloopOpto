"""poster_pdf.py -- the poster as a print-resolution PDF (SfN 2026).

    python poster/sfn2026/poster_pdf.py <poster.pptx> <out.pdf>

PowerPoint writes the PDF (text and shapes stay vector). Its export reduces every picture to 200 ppi, so each
panel picture ('panel ...') is then put back from the pptx at full resolution (the panel PNGs are 400 dpi at
print size), cropped as the slide crops it. Pictures are matched to the PDF's images by position (within
1 pt). Logos and the QR code keep PowerPoint's copy.
"""
import io
import os
import sys
import tempfile

import fitz
import win32com.client as w
from PIL import Image
from pptx import Presentation
from pptx.oxml.ns import qn

EMU_PT = 12700


def export(src, pdf):
    app = w.gencache.EnsureDispatch('PowerPoint.Application')
    pres = app.Presentations.Open(os.path.abspath(src), True, False, False)
    try:
        pres.SaveAs(os.path.abspath(pdf), 32)    # ppSaveAsPDF (ExportAsFixedFormat fails over COM, PrintRange)
    finally:
        pres.Close()


def panels(src):
    """(bbox in pt, PNG bytes cropped as on the slide) for every panel picture."""
    out = []
    for sh in Presentation(src).slides[0].shapes:
        if sh.shape_type != 13 or not sh.name.startswith('panel '):
            continue
        im = Image.open(io.BytesIO(sh.image.blob))
        x0, y0, x1, y1 = (v / EMU_PT for v in (sh.left, sh.top, sh.left + sh.width, sh.top + sh.height))
        sr = sh._element.blipFill.find(qn('a:srcRect'))
        if sr is not None:      # PowerPoint draws only the part of the crop that lies on the image
            l, t, r, b = (int(sr.get(a, 0)) / 1e5 for a in 'ltrb')
            W, H = im.size
            fx = lambda u: x0 + (u - l) / (1 - l - r) * (x1 - x0)
            fy = lambda v: y0 + (v - t) / (1 - t - b) * (y1 - y0)
            u0, v0, u1, v1 = max(l, 0), max(t, 0), min(1 - r, 1), min(1 - b, 1)
            im = im.crop((round(W * u0), round(H * v0), round(W * u1), round(H * v1)))
            x0, y0, x1, y1 = fx(u0), fy(v0), fx(u1), fy(v1)
        buf = io.BytesIO()
        im.convert('RGB').save(buf, 'PNG')
        bb = fitz.Rect(x0, y0, x1, y1)
        out.append((sh.name, bb, buf.getvalue(), im.size))
    return out


def main(src, out):
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, 'raw.pdf')
        export(src, raw)
        doc = fitz.open(raw)
        page = doc[0]
        infos = page.get_image_info(xrefs=True)
        used, n = set(), 0
        for name, bb, png, size in panels(src):
            hit = [i for i in infos if all(abs(a - b) < 1 for a, b in zip(i['bbox'], bb))]
            assert len(hit) == 1, f'{name}: {len(hit)} images at {bb}'
            x = hit[0]['xref']
            assert x not in used, f'{name}: image shared with another panel'
            used.add(x)
            page.replace_image(x, stream=png)
            n += 1
        doc.save(out, garbage=3, deflate=True)
        doc.close()
    print(f'{out}: {n} panels at full resolution, {os.path.getsize(out) / 1e6:.1f} MB')


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
