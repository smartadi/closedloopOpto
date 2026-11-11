"""poster_logos.py -- header logos for the SfN poster (Aditya 2026-11-10).

    python poster/sfn2026/poster_logos.py <poster.pptx> <out.pptx>

Aditya: "add the W logo with university of washington written instead of just the W. also add a NSF logo".
Approved 2026-11-10 ("approve"), with the image steps below.
- UW: the lone white W ('UW logo') becomes the full stacked UW signature (W over "UNIVERSITY of WASHINGTON")
  in white, left edge where the W was, centred on the title band. Source: panels/uw_signature_purple.png,
  the 746 x 367 two-colour image of the signature in Fabiola Duarte's SfN 2026 poster PDF (the only copy on
  this PC). Opacity a = (255 - g) / (255 - g_purple) from the grey level g (g_purple = darkest 1%),
  upsampled x4 (Lanczos), then a' = clip(3 (a - 0.5) + 0.5, 0, 1) so the edges stay sharp at ~5.6 in wide.
- NSF: panels/NSF_Official_logo_Med_Res_600ppi.png, NSF's official logo from its media hub
  (mediahub.nsf.gov/c/wc3fwkos, 5100 px original, stored at 1600 px), full colour as NSF's brand policy asks
  of award recipients, right of the UW signature. Skipped with a note if the file isn't there.
- QR code ('Graphic 7', Aditya's, 2026-11-11: "make sure the qr code is high res in the 54" by 36" format"):
  it is his vector SVG (OneDrive Talks/SfN2026/QR_adityadeole.svg, 29 modules + 4-module margin), so it
  prints sharp at any size, but it sat stretched to 3.25 x 2.99 in. It becomes square (side = its height,
  same centre), and gets his matching 2220 px black-and-white PNG (panels/QR_adityadeole.png, 60 px per
  module, ~740 ppi here; checked module by module against the SVG, 0 of 1369 differ) as the fallback picture
  that PowerPoint normally stores beside an SVG, for any program that can't draw SVG.
Other shapes are untouched.
"""
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Inches

HERE = Path(__file__).resolve().parent
UW_SRC = HERE / 'panels' / 'uw_signature_purple.png'
NSF_SRC = HERE / 'panels' / 'NSF_Official_logo_Med_Res_600ppi.png'
QR_PNG = HERE / 'panels' / 'QR_adityadeole.png'
QR = 'Graphic 7'
E = 914400
UW_H = 2.75     # in: signature height on the 3.87 in band
NSF_H = 2.6     # in
GAP = 0.45      # in: between the signature and the NSF logo


def white_signature(src, up=4):
    """Purple-on-white -> white on transparent (see the module docstring for the two steps)."""
    g = np.asarray(Image.open(src).convert('L'), dtype=float)
    a = np.clip((255 - g) / (255 - np.percentile(g, 1)), 0, 1)
    big = Image.fromarray((a * 255).astype(np.uint8)).resize((g.shape[1] * up, g.shape[0] * up), Image.LANCZOS)
    a = np.asarray(big, dtype=float) / 255
    a = np.clip((a - 0.5) * 3 + 0.5, 0, 1)
    out = np.zeros(a.shape + (4,), dtype=np.uint8)
    out[..., :3] = 255
    out[..., 3] = (a * 255).astype(np.uint8)
    buf = io.BytesIO()
    Image.fromarray(out, 'RGBA').save(buf, 'PNG')
    buf.seek(0)
    return buf, a.shape[1] / a.shape[0]


def square_qr(sl):
    """The QR code square about its centre, with the PNG fallback (module docstring)."""
    qr = next(sh for sh in sl.shapes if sh.name == QR)
    cx, cy = qr.left + qr.width / 2, qr.top + qr.height / 2
    s = qr.height
    print(f'QR code {qr.width / E:.2f} x {qr.height / E:.2f} in -> {s / E:.2f} x {s / E:.2f} in')
    qr.left, qr.top, qr.width, qr.height = int(cx - s / 2), int(cy - s / 2), s, s
    blip = qr._element.blipFill.find(qn('a:blip'))
    if QR_PNG.exists() and blip.get(qn('r:embed')) is None:
        _, rid = sl.part.get_or_add_image_part(str(QR_PNG))
        blip.set(qn('r:embed'), rid)
        print(f'QR code: PNG fallback {QR_PNG.name}')


def main(src, dst):
    prs = Presentation(src)
    sl = prs.slides[0]
    band = next(sh for sh in sl.shapes if sh.name == 'header')
    old = next(sh for sh in sl.shapes if sh.name == 'UW logo')
    mid = band.top + band.height / 2

    img, aspect = white_signature(UW_SRC)
    h = Inches(UW_H)
    w = int(h * aspect)
    pic = sl.shapes.add_picture(img, old.left, int(mid - h / 2), w, h)
    pic.name = 'UW logo'
    pic._element.nvPicPr.cNvPr.set('descr', 'University of Washington')
    old._element.addprevious(pic._element)
    old._element.getparent().remove(old._element)
    right = pic.left + pic.width
    print(f'UW signature {w / E:.2f} x {UW_H:.2f} in at x {pic.left / E:.2f}-{right / E:.2f} in')

    if NSF_SRC.exists():
        im = Image.open(NSF_SRC)
        nh = Inches(NSF_H)
        nw = int(nh * im.width / im.height)
        nsf = sl.shapes.add_picture(str(NSF_SRC), right + Inches(GAP), int(mid - nh / 2), nw, nh)
        nsf.name = 'NSF logo'
        nsf._element.nvPicPr.cNvPr.set('descr', 'U.S. National Science Foundation')
        print(f'NSF logo {nw / E:.2f} x {NSF_H:.2f} in at x {nsf.left / E:.2f}-{(nsf.left + nw) / E:.2f} in')
    else:
        print(f'NSF logo skipped: {NSF_SRC.name} not in panels/')
    square_qr(sl)
    prs.save(dst)
    print(dst)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main(sys.argv[1], sys.argv[2])
