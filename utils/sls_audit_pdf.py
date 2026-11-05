"""Lab-style (steinmetzlab-style) REQUIRED checks on finished figure PDFs.

The PDF is what lands in the journal, and MATLAB's exporters can rescale a small panel
(6 pt type has come out at 5.5 or 8.5 pt), so checking the live MATLAB figure is not
enough. This reads the PDF itself and reports, per page:

  font-size  live text below --min-pt (default 5, the JNeurosci rule-book floor), by each
             line's main size, as the lab's check_figure measures text objects. Super- and
             subscripts below it (MATLAB TeX draws them at 75%) are listed as notes.
  width      page wider than --max-width-cm (default 17.6, JNeurosci 2 columns)
  font       live text not in Arial/Helvetica (reported, preference)
  overlap    two text lines whose INK boxes overlap by more than 0.5 pt (exact positions
             from the PDF; ink box runs along the text from 0.05 size below the baseline
             to 0.72 size above it, rotated with the text)
  opacity    one path with a fill and a stroke of different opacity (Illustrator seam)
  units      a firing rate in Hz
  colormap   raster images or vector fills whose colours sit on jet, turbo, hsv or a
             linear-RGB blue-white-red ([t t 1; 1 1-t 1-t], our old f2 local_div)

Not checkable from a PDF: data past an axis end (use sls_check.m on the live figure),
scale bars, and anything about the science. Outlined text (no live fonts) is reported.

Usage (needs PyMuPDF; the system Python 3.14 has it):
  py -3.14 utils/sls_audit_pdf.py FIG.pdf [...] [--min-pt 5] [--png OUTDIR]
--png writes each page with the problems boxed in red, for a visual check.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import fitz
import numpy as np

CM = 72 / 2.54
ARIAL = ("arial", "helvetica")
RATE = re.compile(r"spike|firing|rate", re.I)
HZ = re.compile(r"\bHz\b")


# ---------------------------------------------------------------------------------------
def _bad_maps():
    """Colour curves of maps the lab rules out, built without matplotlib."""
    import colorsys
    t = np.linspace(0, 1, 256)[:, None]
    o = np.ones_like(t)
    x = t[:, 0]
    maps = {"linear-RGB blue-white-red": np.vstack([np.hstack([t, t, o]),
                                                    np.hstack([o, t[::-1], t[::-1]])])}
    maps["jet"] = np.clip(np.stack([1.5 - abs(4 * x - 3), 1.5 - abs(4 * x - 2),
                                    1.5 - abs(4 * x - 1)], 1), 0, 1)
    # Google's polynomial approximation of turbo (max error ~0.01)
    pr = [0.13572138, 4.61539260, -42.66032258, 132.13108234, -152.94239396, 59.28637943]
    pg = [0.09140261, 2.19418839, 4.84296658, -14.18503333, 4.27729857, 2.82956604]
    pb = [0.10667330, 12.64194608, -60.58204836, 110.36276771, -89.90310912, 27.34824973]
    poly = lambda p: sum(c * x ** k for k, c in enumerate(p))           # noqa: E731
    maps["turbo"] = np.clip(np.stack([poly(pr), poly(pg), poly(pb)], 1), 0, 1)
    maps["hsv"] = np.array([colorsys.hsv_to_rgb(h, 1, 1) for h in x])
    return maps


BAD_MAPS = _bad_maps()


def colormap_match(rgb, min_colors=24, tol=0.05, frac=0.8):
    """Name of a bad map that `rgb` (n x 3 in 0..1, unique colours) lies on, else ''.

    Only saturated colours count (greys and white sit on many maps), and the colours must
    span a real range of the map, so a single red line does not read as 'jet'. MATLAB's
    vector export re-encodes images as JPEG, which smears colours off the exact curve:
    tol/frac were set on a planted test (2026-11-05): jet 0.94 and linear-RGB blue-white-red
    0.97 of colours within 0.05, the lab diverging map at most 0.40.
    """
    rgb = np.unique(np.round(np.asarray(rgb, float), 3), axis=0)
    sat = rgb.max(1) - rgb.min(1)
    rgb = rgb[sat > 0.15]
    if len(rgb) < min_colors:
        return ""
    for name, cm in BAD_MAPS.items():
        d = np.sqrt(((rgb[:, None, :] - cm[None, :, :]) ** 2).sum(-1))
        near = d.min(1) < tol
        if near.mean() >= frac:
            idx = d.argmin(1)[near]
            if np.ptp(idx) > 80:          # spans > 30% of the map
                return name
    return ""


# ---------------------------------------------------------------------------------------
def text_lines(page):
    """One record per PDF text line: text, span sizes, fonts, ink quad, bounding box.

    The ink quad is oriented along the text: from the first span's baseline origin to the
    far edge of the last glyph, and from 0.05 size below the baseline to 0.72 size above
    it (cap height). Rotated labels (90 deg y labels, 45 deg tick labels) keep their true
    shape, so diagonal neighbours are not reported as overlapping.
    """
    out = []
    for b in page.get_text("rawdict")["blocks"]:
        for ln in b.get("lines", []):
            spans = [s for s in ln["spans"] if "".join(c["c"] for c in s["chars"]).strip()]
            if not spans:
                continue
            txt = "".join("".join(c["c"] for c in s["chars"]) for s in spans).strip()
            u = np.array(ln["dir"], float)
            u /= np.linalg.norm(u)
            n = np.array([u[1], -u[0]])                  # "up" in PDF (y-down) coordinates
            o = np.array(spans[0]["origin"], float)
            a_lo, a_hi = 0.0, 0.0
            sz = max(s["size"] for s in spans)
            for s in spans:
                x0, y0, x1, y1 = s["bbox"]
                for c in ((x0, y0), (x0, y1), (x1, y0), (x1, y1)):
                    a = float(np.dot(np.array(c) - o, u))
                    a_lo, a_hi = min(a_lo, a), max(a_hi, a)
            quad = np.array([o + u * a + n * h for a, h in
                             ((a_lo, -0.05 * sz), (a_hi, -0.05 * sz), (a_hi, 0.72 * sz), (a_lo, 0.72 * sz))])
            out.append(dict(text=txt, sizes=[s["size"] for s in spans],
                            fonts=sorted({s["font"] for s in spans}), quad=quad,
                            box=(*quad.min(0), *quad.max(0))))
    return out


def _quads_overlap(p, q, pad):
    """Separating-axis test for two convex quads; True if they overlap by more than pad."""
    for poly in (p, q):
        for k in range(4):
            e = poly[(k + 1) % 4] - poly[k]
            ax = np.array([-e[1], e[0]])
            nrm = np.linalg.norm(ax)
            if nrm == 0:
                continue
            ax /= nrm
            pp, qq = p @ ax, q @ ax
            if min(pp.max(), qq.max()) - max(pp.min(), qq.min()) <= pad:
                return False                              # separated (or touching < pad)
    return True


def overlaps(lines, pad=0.5):
    hits = []
    for i in range(len(lines)):
        for j in range(i + 1, len(lines)):
            a, b = lines[i]["box"], lines[j]["box"]
            if a[0] > b[2] or b[0] > a[2] or a[1] > b[3] or b[1] > a[3]:
                continue                                  # bounding boxes apart: cheap reject
            if not _quads_overlap(lines[i]["quad"], lines[j]["quad"], pad):
                continue
            if lines[i]["text"] == lines[j]["text"] and np.allclose(a, b, atol=0.5):
                continue                                  # stacked duplicate, invisible
            hits.append((i, j))
    return hits


def where(box, page):
    """Position as 'x, y cm from top-left' so a finding can be matched to a panel."""
    return f"({box[0] / CM:.1f}, {box[1] / CM:.1f}) cm"


def audit_page(page, min_pt, max_w_cm=None):
    R = []
    if max_w_cm and page.rect.width / CM > max_w_cm + 0.02:
        R.append(("req", "width", f"page is {page.rect.width / CM:.2f} cm wide; the journal "
                  f"maximum is {max_w_cm:g} cm (scaling it down shrinks every font)", None))
    lines = text_lines(page)
    if not lines:
        R.append(("info", "text", "no live text on this page (outlined, or image only)", None))
    small, script = {}, []
    for ln in lines:
        main = max(ln["sizes"])                           # the line's own type size
        if main < min_pt - 0.05:
            small.setdefault(round(main, 2), []).append(ln)
        elif min(ln["sizes"]) < min_pt - 0.05:
            script.append(ln)                             # only super/subscripts are small
        bad = [f for f in ln["fonts"] if not any(a in f.lower() for a in ARIAL)]
        if bad:
            R.append(("pref", "font", f"{ln['text'][:30]!r} in {', '.join(bad)}", ln["box"]))
        if HZ.search(ln["text"]) and RATE.search(ln["text"]):
            R.append(("req", "units", f"{ln['text'][:40]!r}: a firing rate is in spikes/s", ln["box"]))
    for sz, lns in sorted(small.items()):
        for ln in lns:
            R.append(("req", "font-size", f"{sz:g} pt < {min_pt:g}: {ln['text'][:30]!r}", ln["box"]))
    for ln in script:
        R.append(("note", "script-size", f"super/subscript at {min(ln['sizes']):g} pt in "
                  f"{max(ln['sizes']):g} pt text {ln['text'][:30]!r}", ln["box"]))
    for i, j in overlaps(lines):
        a, b = lines[i], lines[j]
        R.append(("req", "overlap", f"{a['text'][:24]!r} / {b['text'][:24]!r}",
                  tuple(np.r_[np.minimum(a['box'][:2], b['box'][:2]),
                              np.maximum(a['box'][2:], b['box'][2:])])))
    fills = []
    for d in page.get_drawings():
        if d.get("fill") is not None:
            fills.append(d["fill"])
        if d.get("type") == "fs":
            fo, so = d.get("fill_opacity"), d.get("stroke_opacity")
            if fo is not None and so is not None and fo > 0 and so > 0 and abs(fo - so) > 1e-3 \
                    and (d.get("width") or 0) > 0:
                R.append(("req", "opacity", f"fill {fo:.2g} vs stroke {so:.2g}", tuple(d["rect"])))
    if fills:
        nm = colormap_match(np.array(fills))
        if nm:
            R.append(("req", "colormap", f"vector fills follow {nm}", None))
    # Images from the page's display list: covers XObject AND inline images (MATLAB writes
    # imagesc content inline, which get_images() does not list).
    for blk in page.get_text("dict", flags=fitz.TEXT_PRESERVE_IMAGES)["blocks"]:
        if blk.get("type") != 1:
            continue
        try:
            pix = fitz.Pixmap(blk["image"])
            if pix.n - pix.alpha < 3:
                continue                                  # grey / mask: no hue map
            if pix.n - pix.alpha > 3:
                pix = fitz.Pixmap(fitz.csRGB, pix)
            a = np.frombuffer(pix.samples, np.uint8).reshape(pix.h, pix.w, pix.n)[..., :3]
            rgb = a.reshape(-1, 3)[:: max(1, (pix.h * pix.w) // 40000)] / 255.0
            nm = colormap_match(rgb)
            if nm:
                R.append(("req", "colormap", f"image ({pix.w}x{pix.h}) uses {nm}", tuple(blk["bbox"])))
        except Exception as e:                            # noqa: BLE001
            R.append(("info", "image", f"image at {where(blk['bbox'], page)} not read: {e}", None))
    return R, lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pdfs", nargs="+")
    ap.add_argument("--min-pt", type=float, default=5.0)
    ap.add_argument("--max-width-cm", type=float, default=17.6,
                    help="journal maximum page width (JNeurosci 2-column: 17.6 cm; 0 = off)")
    ap.add_argument("--png", default=None, help="write annotated page PNGs here")
    a = ap.parse_args(argv)
    try:
        sys.stdout.reconfigure(encoding="utf-8")         # minus signs, Greek in labels
    except Exception:                                     # noqa: BLE001
        pass
    total = 0
    for f in a.pdfs:
        doc = fitz.open(f)
        for pno, page in enumerate(doc):
            R, lines = audit_page(page, a.min_pt, a.max_width_cm)
            W, H = page.rect.width / CM, page.rect.height / CM
            nreq = sum(r[0] == "req" for r in R)
            total += nreq
            sizes = sorted({round(s, 1) for ln in lines for s in ln["sizes"]})
            print(f"\n== {Path(f).name} p{pno + 1}: {W:.2f} x {H:.2f} cm, {len(lines)} text lines, "
                  f"sizes {sizes[:8]}{'...' if len(sizes) > 8 else ''} pt; {nreq} required")
            for lvl, kind, msg, box in R:
                loc = f" at {where(box, page)}" if box is not None else ""
                print(f"  [{lvl}: {kind}] {msg}{loc}")
            if a.png:
                out = Path(a.png)
                out.mkdir(parents=True, exist_ok=True)
                for lvl, kind, msg, box in R:
                    if box is not None and lvl in ("req", "note"):
                        page.draw_rect(fitz.Rect(box), color=(1, 0, 0) if lvl == "req" else (1, 0.6, 0), width=0.6)
                page.get_pixmap(dpi=200).save(out / f"{Path(f).stem}_p{pno + 1}_audit.png")
    print(f"\n{total} required issue(s) in {len(a.pdfs)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
