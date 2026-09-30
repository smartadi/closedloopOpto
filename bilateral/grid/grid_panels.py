# -*- coding: utf-8 -*-
"""Per-panel export of the unified mouse-grid Aim 1 figure (grid_full_panel.py).

Same data, same selections, same colors as grid_full_panel.py -- but each panel is
saved as its own high-resolution, roughly-square standalone PNG with NO baked-in panel
letter and NO title, for LaTeX/grant assembly (the grant draws its own A-D letters).

Six PNGs into grid_png/:
  grid_p_brain.png  brain meanImage + numbered readout dots + injection rings (panel A)
  grid_p_self.png   exc+inh self-responses (H[ai,s,s]) + LTI fits, with data/LTI legend (B)
  grid_p_state.png  prediction error vs Q1..Q4 with bootstrap CI band (C)
  grid_p_near.png   near site->readout TFs, exc+inh (D-near); ylabel here only
  grid_p_mid.png    mid  site->readout TFs, exc+inh (D-mid)
  grid_p_far.png    far  site->readout TFs, exc+inh (D-far)   [near/mid/far share y-limits]

Run: .venv/Scripts/python.exe bilateral/grid/grid_panels.py
"""
import sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.interpolate
from pathlib import Path
import config, tf_fit
from analysis import site_px

BLUE, RED = "#3070b3", "#c02020"

# --------------------------------------------------------------------------
# Two size profiles. Default is unchanged. `--grant` exports at the EXACT
# printed width used by the R01 (frontmatter_updated.tex fig:grid, panels E-J:
# 0.31 x 0.5 x 0.62 x 7.5in = 51.9pt = 1.83cm), so the LaTeX scale factor is
# 1.0 and the font sizes below ARE the sizes on the page.
#
# Why this exists: the default 3.2in canvas shown in a 0.72in slot is a 0.23x
# reduction, which put 11/10/9pt type on the page at 2.5/2.3/2.0pt -- the
# unreadable-axis-labels complaint. Font size on the page is
#   source pt x (displayed width / natural width),
# so the only fix at fixed layout is to export at the printed size.
# Line widths and marker sizes are in points too, so they do NOT scale with
# the canvas and are respecified here rather than derived.
# --------------------------------------------------------------------------
GRANT = "--grant" in sys.argv

if GRANT:
    OUTDIR = Path(__file__).resolve().parent / "grid_png_grant"
    # Ticks at 6, not 8 (user 2026-09-30: "ticks are too big you can make them small").
    # Tick labels set the left/bottom margin, so shrinking them also gives the plot box
    # back area -- the labels are what had to read at 11 pt, not the numbers.
    LAB, TICK, LEG = 11, 6, 10        # bold; 14/10 was too big (user 2026-09-30)
    # 0.31 x 0.48 x 0.62 x 540 pt. The right block went 0.5 -> 0.48 in the draft
    # (2026-09-30), which narrowed the slot from 51.89 to 49.81 pt; exporting at the
    # old width left a 0.96x LaTeX rescale, i.e. 10.6 pt type instead of 11.
    W = 49.81 / 72.0                  # 1.757 cm, the printed width
    SZ_TRACE = (W, W * 3.0 / 3.2)     # keep the default aspect: the figure
    SZ_BRAIN = (W, W)                 # block height in the wrapfigure is fixed
    DPI = 1200                        # ~865 px at 1.83 cm: stays crisp zoomed in
    G = dict(lw_data=1.0, lw_fit=0.7, lw_ax=0.4, lw_link=0.5, ms=2.2,
             s_site=1.6, s_ro=17, s_ring=38, lw_ring=0.9, fs_num=5.0)
else:
    OUTDIR = Path(__file__).resolve().parent / "grid_png"
    # typography sized to read at ~1.4 in wide on the page
    LAB, TICK, LEG = 11, 10, 9
    # figure sizes (roughly square)
    SZ_TRACE = (3.2, 3.0)   # trace / state panels
    SZ_BRAIN = (3.0, 3.0)   # brain
    DPI = 500
    G = dict(lw_data=1.9, lw_fit=1.1, lw_ax=0.6, lw_link=1.0, ms=5.5,
             s_site=8, s_ro=82, s_ring=175, lw_ring=2.2, fs_num=7.5)

OUTDIR.mkdir(exist_ok=True)

# Fixed axes rectangle shared by all FIVE non-brain panels so they tile with
# identical geometry (same figsize + same margins + no bbox tight => identical
# pixel size AND identical plot-box position). L is sized to fit panel C's
# y-tick labels (0/0.5/1.0) + "prediction error" ylabel -- the widest left
# margin; the trace panels reserve the same L and leave it blank (or draw the
# short "dF/F %" ylabel, which fits inside it).
if GRANT:
    # At 1.83 cm (51.9 x 48.6 pt) the margins must be budgeted in POINTS, not
    # guessed as fractions -- one line of 8pt text is 23% of the panel height.
    #   bottom = 6pt ticks + 2pt tick marks + 1pt pad + 8pt xlabel + 2pt = 19pt -> 0.39
    #   right  = the last xtick ("0.6") is centred on the right edge of the plot
    #            box and overhangs it by half its width, ~4.5pt -> 0.91
    #   left   = max(8pt ylabel + 1 + 2, 6pt ytick + 2 + 2) = 11pt -> 0.24
    # At 14pt the x-LABEL alone would be a third of the 48.6pt panel height, so
    # it is dropped and its unit folded into the last tick ("0.6 s"). What is
    # left is a big bold y-label and big bold ticks.
    # bottom 0.26 -> 0.30: 'Q1'/'Q4' on panel C rendered as 'O1'/'O4' because the Q's
    # DESCENDER fell past the canvas edge and was cut. Tick labels are measured from the
    # baseline, so a glyph with a descender needs more bottom margin than the digits do.
    MARGIN = dict(left=0.26, right=0.88, top=0.96, bottom=0.30)
    PAD = 1          # label padding (pt) -- the 4pt default is huge at this size
else:
    MARGIN = dict(left=0.20, right=0.965, top=0.955, bottom=0.175)
    PAD = 4

# ---- load ------------------------------------------------------------------
mimg = np.asarray(np.load(Path(config.EXPDIR) / "blue/meanImage.npy"))
z = np.load(tf_fit.CACHE_TF2, allow_pickle=True)
sites, amps, H, yhat, gain = z["sites"], z["amps"], z["H"], z["yhat"], z["gain"]
tfwin = z["window"]
lateral = np.abs(sites[:, 0]) >= 1.5
gi = gain[-1]
ai = len(amps) - 1
exc = np.where((sites[:, 0] < 0) & lateral)[0]
inh = np.where((sites[:, 0] > 0) & lateral)[0]
s_exc = exc[np.argmax([gi[i, i] for i in exc])]
s_inh = inh[np.argmin([gi[i, i] for i in inh])]

K = 4
RESP_FRAC = 0.06
DIST_Q = (0.35, 0.68, 1.0)
MIDLINE_MIN = 1.0  # exclude readouts hugging the midline (|x| < this, in mm)


def _readouts(s):
    """self + 3 efferents spread across distance (near/mid/far), ipsilateral,
    staying clear of the midline (so the exc picks don't land at x=-0.5)."""
    dsel = np.linalg.norm(sites - sites[s], axis=1)
    g = np.abs(gi[s])
    cand = [j for j in range(len(sites))
            if j != s and dsel[j] > 0.01 and g[j] >= RESP_FRAC * g[s]
            and sites[j, 0] * sites[s, 0] > 0
            and abs(sites[j, 0]) >= MIDLINE_MIN]
    cand = sorted(cand, key=lambda j: dsel[j])
    if len(cand) >= K - 1:
        picks = sorted({cand[int(round(q * (len(cand) - 1)))] for q in DIST_Q},
                       key=lambda j: dsel[j])
        for j in reversed(cand):
            if len(picks) >= K - 1:
                break
            if j not in picks:
                picks.append(j)
        picks = sorted(picks, key=lambda j: dsel[j])[:K - 1]
    else:
        picks = cand
    return sorted(picks, key=lambda j: dsel[j])


# ---- (C) prediction error vs pre-stim state --------------------------------
NBIN = 4
rng = np.random.default_rng(7)
t = np.load(Path(__file__).resolve().parents[2] / "data" / "grid_trials_2amp.npz",
            allow_pickle=True)
roi_ts = t["roi_ts"].astype(np.float64)
svdT = t["svdT"]; onset_t = t["onset_t"]; pos = t["pos"]; s2 = t["sites"]
onset_amp = np.round(t["onset_amp"], 3); window = t["window"]
fs = 1.0 / np.median(np.diff(window))
amps2 = [a for a in np.unique(onset_amp) if a > 0.05]
pmask = (window >= 0.03) & (window <= 0.45)
bmask = (window >= -0.12) & (window < 0)
pre_win = np.arange(-1.0, -0.02, 1.0 / fs)


def _rel_delta(seg):
    m = seg.shape[1]; w = np.hanning(m)
    xseg = np.nan_to_num(seg - np.nanmean(seg, axis=1, keepdims=True))
    X = np.abs(np.fft.rfft(xseg * w, axis=1)) ** 2
    f = np.fft.rfftfreq(m, 1.0 / fs)
    d = (f >= 1) & (f <= 4); b = (f >= 0.5) & (f <= 30)
    return X[:, d].sum(1) / np.maximum(X[:, b].sum(1), 1e-12)


cell_id, resid, DPr = [], [], []
cid = 0
for s_idx, (mx, my) in enumerate(s2):
    interp = scipy.interpolate.interp1d(svdT, roi_ts[:, s_idx],
                                        bounds_error=False, fill_value=np.nan)
    for amp in amps2:
        sel = (pos[:, 0] == mx) & (pos[:, 1] == my) & (onset_amp == amp)
        these = onset_t[sel]
        if len(these) < 16:
            continue
        pre = interp(pre_win[None, :] + these[:, None])
        post = interp(window[None, :] + these[:, None])
        post = post - np.nanmean(post[:, bmask], axis=1, keepdims=True)
        ok = np.all(np.isfinite(post), axis=1) & np.all(np.isfinite(pre), axis=1)
        post, pre = post[ok], pre[ok]
        if ok.sum() < 16:
            continue
        r = np.nanmean(post[:, pmask], axis=1)
        cell_id.extend([cid] * len(r)); resid.extend(r - np.nanmean(r))
        DPr.extend(_rel_delta(pre)); cid += 1
cell_id = np.array(cell_id); resid = np.array(resid); DPr = np.array(DPr)


def _rank_within_cell(v):
    out = np.full(len(v), np.nan)
    for c in np.unique(cell_id):
        m = cell_id == c
        out[m] = (np.argsort(np.argsort(v[m])) + 0.5) / m.sum()
    return out


def _pooled_sd(mask):
    num = den = 0.0
    for c in np.unique(cell_id[mask]):
        v = resid[mask & (cell_id == c)]; v = v[np.isfinite(v)]
        if len(v) < 3:
            continue
        num += (len(v) - 1) * np.var(v, ddof=1); den += (len(v) - 1)
    return np.sqrt(num / den) if den > 0 else np.nan


rk = _rank_within_cell(DPr)
gbin = np.clip(np.digitize(rk, np.linspace(0, 1, NBIN + 1)[1:-1]), 0, NBIN - 1)
pe = np.array([_pooled_sd(gbin == b) for b in range(NBIN)])
pe_lo, pe_hi = [], []
for b in range(NBIN):
    idx = np.where(gbin == b)[0]
    bs = []
    for _ in range(400):
        ss = rng.choice(idx, len(idx), replace=True)
        mm = np.zeros(len(resid), bool); mm[ss] = True
        bs.append(_pooled_sd(mm))
    pe_lo.append(np.nanpercentile(bs, 2.5)); pe_hi.append(np.nanpercentile(bs, 97.5))
# normalize so Q1 = 0 and Q4 = 1 (endpoints anchor the axis; ticks stay narrow)
lo0, span = pe[0], (pe[-1] - pe[0])
pe_n = (pe - lo0) / span
pe_lo = (np.array(pe_lo) - lo0) / span
pe_hi = (np.array(pe_hi) - lo0) / span


def _clean(ax):
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)


def _bold_ticks(ax):
    """Grant profile draws every tick label bold; tick_params has no weight arg."""
    if not GRANT:
        return
    for lb in list(ax.get_xticklabels()) + list(ax.get_yticklabels()):
        lb.set_fontweight("bold")


def _trace_axis(ax, ylab=None):
    """Common styling for the transfer-function trace panels; y-tick labels
    dropped (they don't add value -- sign and shape carry the message).
    No title, no panel letter."""
    ax.axhline(0, c="0.78", lw=G["lw_ax"]); ax.axvline(0, c="0.78", lw=G["lw_ax"])
    ax.set_xlim(-0.1, 0.6)
    if GRANT:
        # No x-label: the unit rides on the last tick instead, which buys back a
        # third of the panel height for bigger type.
        # Unit rides on the last tick instead of an x-label. Anchoring the end
        # labels inward (ha left/right) stops them overhanging the panel, which
        # is what forced the unit off in the first place.
        # Only the END tick is labelled. At 10pt bold, "0" and "0.6 s" collide in
        # a ~26pt plot box (they came out as "006 s"); t=0 is already marked by
        # the grey vertical line, so the zero label carries nothing.
        ax.set_xticks([0, 0.6]); ax.set_xticklabels(["", "0.6 s"])
        ax.get_xticklabels()[-1].set_horizontalalignment("right")
    else:
        ax.set_xticks([0, 0.3, 0.6])
        ax.set_xlabel("t (s)", fontsize=LAB, labelpad=PAD)
    ax.tick_params(labelsize=TICK, left=False, labelleft=False)
    _clean(ax)
    if ylab:
        ax.set_ylabel(ylab, fontsize=LAB, labelpad=PAD,
                      fontweight="bold" if GRANT else "normal")
    _bold_ticks(ax)


def _save_tight(fig, name):
    """Brain panel: its own square, cropped to content."""
    p = OUTDIR / name
    fig.savefig(p, dpi=DPI, facecolor="white", bbox_inches="tight")
    plt.close(fig)
    return p


def _save_fixed(fig, name):
    """The five tiling panels: fixed axes rectangle, NO bbox tight, so the saved
    canvas equals figsize exactly and every panel comes out pixel-identical with
    its plot box in the same position."""
    fig.subplots_adjust(**MARGIN)
    p = OUTDIR / name
    fig.savefig(p, dpi=DPI, facecolor="white")  # no bbox_inches="tight"
    plt.close(fig)
    return p


# ========================= panel A: brain ==================================
figA, axA = plt.subplots(figsize=SZ_BRAIN, dpi=DPI)
axA.imshow(mimg, cmap="gray"); axA.set_axis_off()
sx, sy = site_px(sites[:, 0], sites[:, 1], config.BREGMA_PX,
                 config.PX_PER_MM_X, config.PX_PER_MM_Y)
axA.scatter(sx, sy, c="w", s=G["s_site"], lw=0, alpha=0.55)
for s, col in [(s_exc, BLUE), (s_inh, RED)]:
    ix, iy = site_px(sites[s, 0], sites[s, 1], config.BREGMA_PX,
                     config.PX_PER_MM_X, config.PX_PER_MM_Y)
    for k, j in enumerate(_readouts(s), start=1):
        px, py = site_px(sites[j, 0], sites[j, 1], config.BREGMA_PX,
                         config.PX_PER_MM_X, config.PX_PER_MM_Y)
        axA.plot([ix, px], [iy, py], color=col, lw=G["lw_link"], alpha=0.5, zorder=2)
        axA.scatter(px, py, c=col, s=G["s_ro"], lw=0.4, edgecolors="w", zorder=3)
        axA.text(px, py, str(k), color="w", fontsize=G["fs_num"], fontweight="bold",
                 ha="center", va="center", zorder=4)
    axA.scatter(ix, iy, ec=col, fc="none", s=G["s_ring"], lw=G["lw_ring"], zorder=3)
axA.set_xlim(60, 500); axA.set_ylim(500, 60)
pA = _save_tight(figA, "grid_p_brain.png")

# ========================= panel B: self-response ==========================
figB, axB = plt.subplots(figsize=SZ_TRACE, dpi=DPI)
for s, col in [(s_exc, BLUE), (s_inh, RED)]:
    axB.plot(tfwin, H[ai, s, s] * 100, color=col, lw=G["lw_data"])
    axB.plot(tfwin, yhat[ai, s, s] * 100, color=col, lw=G["lw_fit"], ls="--")
_trace_axis(axB, ylab="%" if GRANT else "$\\Delta$F/F %")
# compact data / LTI-fit legend lives on the self panel. Dropped at grant size:
# 1.83 cm has no room for it, and the fig:grid caption already states
# "solid, data; dashed, fitted LTI model".
if not GRANT:
    axB.plot([], [], "k-", lw=1.7, label="data")
    axB.plot([], [], "k--", lw=1.0, label="LTI fit")
    axB.legend(fontsize=LEG, frameon=False, loc="upper right",
               handlelength=1.1, borderaxespad=0.15)
pB = _save_fixed(figB, "grid_p_self.png")

# ========================= panel C: prediction error vs state ==============
figC, axC = plt.subplots(figsize=SZ_TRACE, dpi=DPI)
xb = np.arange(1, NBIN + 1)
axC.fill_between(xb, pe_lo, pe_hi, color=RED, alpha=0.18)
axC.plot(xb, pe_n, "-o", color=RED, lw=G["lw_data"] * 1.1, ms=G["ms"])
axC.set_xticks(xb)
# Four 6pt "Qn" labels need ~36pt; the grant plot box is ~35pt wide, so they
# would touch. Keep all four tick MARKS (the four bins still read) but label
# only the endpoints.
axC.set_xticklabels(["Q1", "", "", "Q4"] if GRANT else ["Q1", "Q2", "Q3", "Q4"])
# At grant size the x-label is shortened and the y-label dropped: an 8pt
# "prediction error" would need a 17pt left margin out of 52pt, and the axes
# rectangle is SHARED with the trace panels (MARGIN below) so that cost lands on
# all five. The quantity is named by the LaTeX panel title and the caption.
if GRANT:
    # 'Err.' is the y-label here (big and bold); the x is named by its Q1/Q4
    # ticks, so the x-label goes, exactly as on the trace panels.
    pass   # no y-label: 0/1 ticks carry it, and "Err." would clip at 14pt
else:
    axC.set_xlabel("pre-stim state", fontsize=LAB, labelpad=PAD)
    axC.set_ylabel("prediction error", fontsize=LAB, labelpad=PAD)
axC.margins(x=0.08); axC.tick_params(labelsize=TICK)
axC.set_yticks([0, 1.0] if GRANT else [0, 0.5, 1.0])
_clean(axC)
_bold_ticks(axC)
pC = _save_fixed(figC, "grid_p_state.png")

# ========================= panel D: near / mid / far =======================
exc_ro, inh_ro = _readouts(s_exc), _readouts(s_inh)
d_exc = np.linalg.norm(sites - sites[s_exc], axis=1)
d_inh = np.linalg.norm(sites - sites[s_inh], axis=1)
binname = ["near", "mid", "far"]
binfile = {"near": "grid_p_near.png", "mid": "grid_p_mid.png", "far": "grid_p_far.png"}

# shared y-limits across all three D panels: compute common min/max first
ymin, ymax = np.inf, -np.inf
for b in range(3):
    je, ji = exc_ro[b], inh_ro[b]
    for arr in (H[ai, s_exc, je], yhat[ai, s_exc, je],
                H[ai, s_inh, ji], yhat[ai, s_inh, ji]):
        v = arr * 100
        ymin = min(ymin, float(np.nanmin(v)))
        ymax = max(ymax, float(np.nanmax(v)))
pad = 0.05 * (ymax - ymin)
ylim = (ymin - pad, ymax + pad)

pD = {}
for b in range(3):
    fig, ax = plt.subplots(figsize=SZ_TRACE, dpi=DPI)
    je, ji = exc_ro[b], inh_ro[b]
    ax.plot(tfwin, H[ai, s_exc, je] * 100, color=BLUE, lw=G["lw_data"])
    ax.plot(tfwin, yhat[ai, s_exc, je] * 100, color=BLUE, lw=G["lw_fit"], ls="--")
    ax.plot(tfwin, H[ai, s_inh, ji] * 100, color=RED, lw=G["lw_data"])
    ax.plot(tfwin, yhat[ai, s_inh, ji] * 100, color=RED, lw=G["lw_fit"], ls="--")
    _trace_axis(ax, ylab=("%" if GRANT else "$\\Delta$F/F %") if b == 0 else None)
    ax.set_ylim(ylim)
    pD[binname[b]] = _save_fixed(fig, binfile[binname[b]])

for nm, p in [("brain", pA), ("self", pB), ("state", pC),
              ("near", pD["near"]), ("mid", pD["mid"]), ("far", pD["far"])]:
    print("wrote", nm, "->", p)
print("D shared ylim:", ylim)
print("exc near/mid/far mm:", [round(float(d_exc[j]), 1) for j in exc_ro])
print("inh near/mid/far mm:", [round(float(d_inh[j]), 1) for j in inh_ro])
