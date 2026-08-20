"""Animate signal flow around the system-architecture block diagram -> a looping GIF.

The static diagram (paper/images/mouse_sys.pdf) already shows the loop; what it cannot
show is that the loop RUNS -- that error, command, brain response and readout are one
circulating signal at 35 Hz. A comet tracing the path says that in one glance.

Nothing is redrawn: the diagram is used as the backdrop and a glow is composited along a
hand-traced polyline, so the figure stays exactly the published one.

Output: talk/PANEL_system_architecture.gif
"""
import os
from PIL import Image, ImageDraw, ImageFilter

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "PANEL_system_architecture.png")
OUT = os.path.join(HERE, "PANEL_system_architecture.gif")

W_OUT = 1200                 # GIF width; the source is 4200 px and far too big to loop
N_FRAMES = 90
FRAME_MS = 45
TAIL = 20                    # comet length, in samples of the arc-length parameterisation
DOT_R = 9

# Path traced on the 2000-px-wide view of the figure. Scaled to the output width below.
REF_W = 2000.0
MAIN = [(190, 430), (345, 430), (740, 430), (1150, 430), (1300, 430), (1700, 430),
        (1985, 430), (1985, 880), (1430, 880), (1000, 880), (350, 880), (350, 470)]
# The feedforward Kr branch leaves the reference line and rejoins at the second summer.
FF = [(225, 430), (225, 128), (1295, 128), (1295, 425)]

GLOW = (255, 96, 32)         # warm orange reads on the diagram's teal without recolouring it


def resample(pts, n):
    """Uniform arc-length resampling, so the comet moves at constant speed through corners."""
    seg = [((pts[i + 1][0] - pts[i][0]) ** 2 + (pts[i + 1][1] - pts[i][1]) ** 2) ** 0.5
           for i in range(len(pts) - 1)]
    total = sum(seg)
    out, acc = [], 0.0
    for k in range(n):
        d = total * k / n
        acc, i = 0.0, 0
        while i < len(seg) and acc + seg[i] < d:
            acc += seg[i]
            i += 1
        if i >= len(seg):
            out.append(pts[-1])
            continue
        f = (d - acc) / seg[i] if seg[i] else 0.0
        out.append((pts[i][0] + f * (pts[i + 1][0] - pts[i][0]),
                    pts[i][1] + f * (pts[i + 1][1] - pts[i][1])))
    return out


base = Image.open(SRC).convert("RGB")
scale = W_OUT / base.width
base = base.resize((W_OUT, round(base.height * scale)), Image.LANCZOS)
k = W_OUT / REF_W

main = resample([(x * k, y * k) for x, y in MAIN], N_FRAMES)
ff = resample([(x * k, y * k) for x, y in FF], N_FRAMES)

frames = []
for f in range(N_FRAMES):
    glow = Image.new("L", base.size, 0)
    g = ImageDraw.Draw(glow)
    # Tail drawn as connected SEGMENTS, not a string of dots: at this path length the
    # per-frame step is ~20 px, so dots read as a dotted line rather than as motion.
    for j in range(TAIL, 0, -1):                # tail first, head last -> head stays brightest
        a = int(235 * (1 - j / TAIL) ** 1.7)
        r = DOT_R * (1 - 0.55 * j / TAIL)
        for path, off in ((main, f - j), (ff, f - j - N_FRAMES // 3)):
            p0 = path[off % N_FRAMES]
            p1 = path[(off + 1) % N_FRAMES]
            g.line([p0, p1], fill=a, width=max(2, int(2 * r)))
            g.ellipse([p1[0] - r, p1[1] - r, p1[0] + r, p1[1] + r], fill=a)
    glow = glow.filter(ImageFilter.GaussianBlur(3))
    frames.append(Image.composite(Image.new("RGB", base.size, GLOW), base, glow))

pal = frames[0].quantize(colors=127, method=Image.MEDIANCUT)
frames = [fr.quantize(palette=pal, dither=Image.NONE) for fr in frames]
frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=FRAME_MS,
               loop=0, optimize=True, disposal=2)
print(f"wrote {OUT}  {frames[0].size}  {N_FRAMES} frames  "
      f"{os.path.getsize(OUT) // 1024} KB")
