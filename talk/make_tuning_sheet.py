"""Side-by-side controller-tuning panels: every gain path beside its cost curve.

The published `autotune_convergence_*.pdf` stack the (Kp,Ki) path above the cost staircase,
which is the wrong pairing for a slide -- you want to read "where it went" and "what that
bought" left to right, at one glance. This splits each figure and re-lays it out, then
builds one overview sheet with both grids on top and both sessions' path|cost below.

Nothing is refitted; the source PDFs are the published ones in paper/images/tuning/.

Outputs (talk/):
  PANEL_tuning_<session>.png      path | cost, one session
  PANEL_tuning_grids.png          the two gain grids, side by side
  PANEL_tuning_overview.png       everything on one sheet
"""
import os
import subprocess

from PIL import Image, ImageChops, ImageDraw, ImageFont

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TUNE = os.path.join(ROOT, "paper", "images", "tuning")
DPI = 500
PAD = 60
BG = (255, 255, 255)

AUTO = [("AL0033_0317", "AL_0033  2025-03-17   cost 16.6 → 12.3",
         "autotune_convergence_AL_0033_0317.pdf"),
        ("AL0034_1025", "AL_0034  2024-10-25 e1   cost 11.9 → 4.6",
         "autotune_convergence_AL_0034_1025e1.pdf")]
GRIDS = [("AL_0033  2025-03-05   (primary)", "grid_cost_surface_AL_0033_0305.pdf"),
         ("AL_0034  2024-10-17   (dur = 4 s variant)", "grid_cost_surface_AL_0034_1017.pdf")]


def load(pdf, dpi=DPI):
    out = os.path.join(HERE, "img", "_sheet_tmp")
    subprocess.run(["pdftoppm", "-png", "-r", str(dpi), "-singlefile",
                    os.path.join(TUNE, pdf), out], check=True)
    im = Image.open(out + ".png").convert("RGB")
    bb = ImageChops.difference(im, Image.new("RGB", im.size, BG)).getbbox()
    if bb:
        im = im.crop(bb)
    os.remove(out + ".png")
    return im


def split_rows(im):
    """Cut the stacked figure at the widest blank band in its middle third.

    A fixed fraction leaves a sliver of the upper panel's axis on top of the lower one --
    visible as a stray glyph above the cost curve. Finding the actual gap is exact.
    """
    g = im.convert("L")
    px = g.load()
    step = max(1, im.width // 400)
    blank = [all(px[x, y] > 247 for x in range(0, im.width, step))
             for y in range(im.height)]
    lo, hi = int(im.height * 0.33), int(im.height * 0.72)
    best, run, start = (0, im.height // 2), 0, lo
    for y in range(lo, hi):
        if blank[y]:
            if run == 0:
                start = y
            run += 1
            if run > best[0]:
                best = (run, start + run // 2)
        else:
            run = 0
    cut = best[1]
    top, bot = im.crop((0, 0, im.width, cut)), im.crop((0, cut, im.width, im.height))
    return trim(top), trim(bot)


def trim(im):
    bb = ImageChops.difference(im, Image.new("RGB", im.size, BG)).getbbox()
    return im.crop(bb) if bb else im


def font(sz):
    for name in ("calibrib.ttf", "arialbd.ttf", "seguisb.ttf"):
        try:
            return ImageFont.truetype(name, sz)
        except OSError:
            continue
    return ImageFont.load_default()


def row(images, gap=PAD, title=None, title_h=90, labels=None, label_h=70):
    """Lay images left to right on a common baseline, scaled to a common height.

    `labels` captions each image underneath -- the source PDFs are inconsistent about
    carrying their own session title, so without this you cannot tell the two grids apart.
    """
    h = max(i.height for i in images)
    scaled = [i.resize((round(i.width * h / i.height), h), Image.LANCZOS) for i in images]
    w = sum(i.width for i in scaled) + gap * (len(scaled) - 1)
    top = title_h if title else 0
    bot = label_h if labels else 0
    sheet = Image.new("RGB", (w, h + top + bot), BG)
    d = ImageDraw.Draw(sheet)
    x = 0
    for k, i in enumerate(scaled):
        sheet.paste(i, (x, top))
        if labels:
            d.text((x + i.width // 2, h + top + 10), labels[k], fill=(90, 90, 90),
                   font=font(44), anchor="ma")
        x += i.width + gap
    if title:
        d.text((4, 14), title, fill=(17, 17, 17), font=font(52))
    return sheet


def stack(images, gap=PAD):
    w = max(i.width for i in images)
    scaled = [i.resize((w, round(i.height * w / i.width)), Image.LANCZOS) for i in images]
    h = sum(i.height for i in scaled) + gap * (len(scaled) - 1)
    sheet = Image.new("RGB", (w, h), BG)
    y = 0
    for i in scaled:
        sheet.paste(i, (0, y))
        y += i.height + gap
    return sheet


# ---- per-session path | cost ---------------------------------------------------------
per_session = []
for tag, label, pdf in AUTO:
    path, cost = split_rows(load(pdf))
    path.save(os.path.join(HERE, f"PANEL_gainpath_{tag}.png"), dpi=(DPI, DPI))
    cost.save(os.path.join(HERE, f"PANEL_costcurve_{tag}.png"), dpi=(DPI, DPI))
    sheet = row([path, cost], title=label,
                labels=["accepted (Kp, Ki) path", "cost per tune iteration"])
    sheet.save(os.path.join(HERE, f"PANEL_tuning_{tag}.png"), dpi=(DPI, DPI))
    per_session.append(sheet)
    print(f"PANEL_tuning_{tag}.png  {sheet.size}")

# ---- the two grids, side by side -----------------------------------------------------
grid_imgs = [load(pdf) for _, pdf in GRIDS]
grids = row(grid_imgs, title="Gain grids — exhaustive J(Kp, Ki) over a swept set of controllers",
            labels=[lbl for lbl, _ in GRIDS])
grids.save(os.path.join(HERE, "PANEL_tuning_grids.png"), dpi=(DPI, DPI))
print(f"PANEL_tuning_grids.png  {grids.size}")

# ---- one overview sheet --------------------------------------------------------------
over = stack([grids] + per_session, gap=PAD * 2)
if over.width > 5200:                       # keep it openable
    k = 5200 / over.width
    over = over.resize((5200, round(over.height * k)), Image.LANCZOS)
over.save(os.path.join(HERE, "PANEL_tuning_overview.png"), dpi=(DPI, DPI))
print(f"PANEL_tuning_overview.png  {over.size}")
