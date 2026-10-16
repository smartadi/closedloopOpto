"""pdf_swap_images.py -- replace the raster images inside a MATLAB-exported PDF with native PNGs.

WHY: exportgraphics(...,'ContentType','vector') re-encodes every embedded image (imagesc heatmaps)
as a JPEG resampled to the figure's ON-SCREEN pixel size. A 1516-trial raster drawn 2.4 cm tall
came out as a 125 x 106 JPEG: most trials were averaged away and the colours were JPEG-smeared.
This keeps MATLAB's vector axes/text/lines and the image's exact placement, and swaps each image
stream for the native-resolution, lossless PNG (one pixel per trial x time sample).

Images are matched LEFT -> RIGHT by their placed bbox (x0), so pass the PNGs in panel order.

usage:  python -I pdf_swap_images.py <pdf> <png1> [<png2> ...]    (edits the PDF in place)
"""
import sys
import fitz  # PyMuPDF

pdf, pngs = sys.argv[1], sys.argv[2:]
doc = fitz.open(pdf)
page = doc[0]
# MATLAB/Qt nests the images inside Form XObjects, so get_image_info reports xref 0. Take the
# /Image xrefs from the document instead; Qt writes them in drawing order (= panel order).
# Callers must verify the order once by rendering (the producer draws panels left -> right).
xrefs = [x for x in range(1, doc.xref_length()) if doc.xref_get_key(x, "Subtype")[1] == "/Image"
         and doc.xref_get_key(x, "SMask")[0] == "null" and doc.xref_get_key(x, "ImageMask")[1] != "true"]
if len(xrefs) != len(pngs):
    sys.exit(f"[swap] {pdf}: {len(xrefs)} images in PDF but {len(pngs)} PNGs given")
for x, png in zip(xrefs, pngs):
    page.replace_image(x, filename=png)
tmp = pdf + ".swap.tmp"
doc.save(tmp, garbage=3, deflate=True)   # full rewrite: Qt PDFs refuse incremental saves
doc.close()
import os
os.replace(tmp, pdf)
print(f"[swap] {pdf}: replaced {len(pngs)} image(s) with native PNGs")
