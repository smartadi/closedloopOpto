"""
gif_utils.py — shared GIF writer for the slide graphics.

The one thing that matters here: **a single global palette**. PIL's default is
to quantise every frame independently, so each frame lands on a slightly
different set of 256 colours and a smooth widefield gradient shimmers from
frame to frame — that is the "jitter", and it is a palette artefact, not the
data. Dithering makes it worse (the dither pattern is re-randomised per frame),
so it is off.
"""
import numpy as np
from PIL import Image

TRANSP_IDX = 255      # palette slot reserved for the transparent colour


def save_gif(frames, path, fps=20, loop=0, alpha=None, n_pal_samples=16):
    """Write `frames` (list of RGB/RGBA PIL images) with one shared palette.

    alpha : optional single-channel PIL image (same size) — pixels below 128
            become fully transparent. GIF alpha is 1-bit, so a feathered edge
            will show some stair-stepping.
    """
    rgb = [f.convert("RGB") for f in frames]
    n = len(rgb)

    # build the palette from a strip of evenly spaced frames, so colours that
    # only appear late in the movie still get slots
    idx = np.unique(np.linspace(0, n - 1, min(n, n_pal_samples)).round().astype(int))
    w, h = rgb[0].size
    strip = Image.new("RGB", (w * len(idx), h))
    for j, i in enumerate(idx):
        strip.paste(rgb[i], (j * w, 0))
    ncol = TRANSP_IDX if alpha is not None else 256
    pal = strip.quantize(colors=ncol, method=Image.MEDIANCUT)

    out = [f.quantize(palette=pal, dither=Image.NONE) for f in rgb]

    kw = {}
    if alpha is not None:
        m = np.array(alpha.convert("L")) < 128
        for im in out:
            a = np.array(im)
            a[m] = TRANSP_IDX
            im.putdata(a.ravel().tolist())
        kw = dict(transparency=TRANSP_IDX, disposal=2)
    else:
        kw = dict(disposal=1)          # leave the previous frame in place

    out[0].save(path, save_all=True, append_images=out[1:], loop=loop,
                duration=int(round(1000 / fps)), optimize=False, **kw)
    return path


def tsmooth(x, w, axis=-1):
    """centred moving average along `axis`; w<=1 is a no-op.

    Widefield frames carry per-frame shot noise that reads as flicker once the
    movie is slowed down. Averaging a few frames is the standard display fix.
    """
    if w is None or w <= 1:
        return x
    k = np.ones(int(w)) / float(int(w))
    return np.apply_along_axis(lambda v: np.convolve(v, k, mode="same"), axis, x)
