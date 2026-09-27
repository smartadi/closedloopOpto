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
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.interpolate
from pathlib import Path
import config, tf_fit
from analysis import site_px

OUTDIR = Path(__file__).resolve().parent / "grid_png"
OUTDIR.mkdir(exist_ok=True)
BLUE, RED = "#3070b3", "#c02020"

# typography sized to read at ~1.4 in wide on the page
LAB, TICK, LEG = 11, 10, 9

# figure sizes (roughly square)
SZ_TRACE = (3.2, 3.0)   # trace / state panels
SZ_BRAIN = (3.0, 3.0)   # brain
DPI = 500

# Fixed axes rectangle shared by all FIVE non-brain panels so they tile with
# identical geometry (same figsize + same margins + no bbox tight => identical
# pixel size AND identical plot-box position). L is sized to fit panel C's
# y-tick labels (0/0.5/1.0) + "prediction error" ylabel -- the widest left
# margin; the trace panels reserve the same L and leave it blank (or draw the
# short "dF/F %" ylabel, which fits inside it).
MARGIN = dict(left=0.20, right=0.965, top=0.955, bottom=0.175)

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


def _trace_axis(ax, ylab=None):
    """Common styling for the transfer-function trace panels; y-tick labels
    dropped (they don't add value -- sign and shape carry the message).
    No title, no panel letter."""
    ax.axhline(0, c="0.78", lw=0.6); ax.axvline(0, c="0.78", lw=0.6)
    ax.set_xlim(-0.1, 0.6); ax.set_xticks([0, 0.3, 0.6])
    ax.set_xlabel("t (s)", fontsize=LAB)
    ax.tick_params(labelsize=TICK, left=False, labelleft=False)
    _clean(ax)
    if ylab:
        ax.set_ylabel(ylab, fontsize=LAB)


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
axA.scatter(sx, sy, c="w", s=8, lw=0, alpha=0.55)
for s, col in [(s_exc, BLUE), (s_inh, RED)]:
    ix, iy = site_px(sites[s, 0], sites[s, 1], config.BREGMA_PX,
                     config.PX_PER_MM_X, config.PX_PER_MM_Y)
    for k, j in enumerate(_readouts(s), start=1):
        px, py = site_px(sites[j, 0], sites[j, 1], config.BREGMA_PX,
                         config.PX_PER_MM_X, config.PX_PER_MM_Y)
        axA.plot([ix, px], [iy, py], color=col, lw=1.0, alpha=0.5, zorder=2)
        axA.scatter(px, py, c=col, s=82, lw=0.7, edgecolors="w", zorder=3)
        axA.text(px, py, str(k), color="w", fontsize=7.5, fontweight="bold",
                 ha="center", va="center", zorder=4)
    axA.scatter(ix, iy, ec=col, fc="none", s=175, lw=2.2, zorder=3)
axA.set_xlim(60, 500); axA.set_ylim(500, 60)
pA = _save_tight(figA, "grid_p_brain.png")

# ========================= panel B: self-response ==========================
figB, axB = plt.subplots(figsize=SZ_TRACE, dpi=DPI)
for s, col in [(s_exc, BLUE), (s_inh, RED)]:
    axB.plot(tfwin, H[ai, s, s] * 100, color=col, lw=1.9)
    axB.plot(tfwin, yhat[ai, s, s] * 100, color=col, lw=1.1, ls="--")
_trace_axis(axB, ylab="$\\Delta$F/F %")
# compact data / LTI-fit legend lives on the self panel
axB.plot([], [], "k-", lw=1.7, label="data")
axB.plot([], [], "k--", lw=1.0, label="LTI fit")
axB.legend(fontsize=LEG, frameon=False, loc="upper right",
           handlelength=1.1, borderaxespad=0.15)
pB = _save_fixed(figB, "grid_p_self.png")

# ========================= panel C: prediction error vs state ==============
figC, axC = plt.subplots(figsize=SZ_TRACE, dpi=DPI)
xb = np.arange(1, NBIN + 1)
axC.fill_between(xb, pe_lo, pe_hi, color=RED, alpha=0.18)
axC.plot(xb, pe_n, "-o", color=RED, lw=2.1, ms=5.5)
axC.set_xticks(xb); axC.set_xticklabels(["Q1", "Q2", "Q3", "Q4"])
axC.set_xlabel("pre-stim state", fontsize=LAB)
axC.set_ylabel("prediction error", fontsize=LAB)
axC.margins(x=0.08); axC.tick_params(labelsize=TICK)
axC.set_yticks([0, 0.5, 1.0])
_clean(axC)
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
    ax.plot(tfwin, H[ai, s_exc, je] * 100, color=BLUE, lw=1.9)
    ax.plot(tfwin, yhat[ai, s_exc, je] * 100, color=BLUE, lw=1.1, ls="--")
    ax.plot(tfwin, H[ai, s_inh, ji] * 100, color=RED, lw=1.9)
    ax.plot(tfwin, yhat[ai, s_inh, ji] * 100, color=RED, lw=1.1, ls="--")
    _trace_axis(ax, ylab="$\\Delta$F/F %" if b == 0 else None)
    ax.set_ylim(ylim)
    pD[binname[b]] = _save_fixed(fig, binfile[binname[b]])

for nm, p in [("brain", pA), ("self", pB), ("state", pC),
              ("near", pD["near"]), ("mid", pD["mid"]), ("far", pD["far"])]:
    print("wrote", nm, "->", p)
print("D shared ylim:", ylim)
print("exc near/mid/far mm:", [round(float(d_exc[j]), 1) for j in exc_ro])
print("inh near/mid/far mm:", [round(float(d_inh[j]), 1) for j in inh_ro])
