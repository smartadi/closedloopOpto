"""Export the deck to per-slide PNGs via PowerPoint COM (for visual QA)."""
import os
import sys
import glob
import win32com.client

HERE = os.path.dirname(os.path.abspath(__file__))
deck = os.path.join(HERE, "neuroai_seattle_2026.pptx")
outdir = os.path.join(HERE, "render")

for f in glob.glob(os.path.join(outdir, "*.png")):
    os.remove(f)
os.makedirs(outdir, exist_ok=True)

app = win32com.client.Dispatch("PowerPoint.Application")
pres = app.Presentations.Open(deck, WithWindow=False)
try:
    # 3 = ppSaveAsPNG-ish; use Export for controllable resolution
    pres.Export(outdir, "png", 1600, 900)
finally:
    pres.Close()
    app.Quit()

files = sorted(glob.glob(os.path.join(outdir, "*.PNG")) + glob.glob(os.path.join(outdir, "*.png")))
print(f"{len(files)} slides exported")
for f in files:
    print(f)
