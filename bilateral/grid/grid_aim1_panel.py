# -*- coding: utf-8 -*-
"""Composite mouse-grid Aim 1 panel for the grant, three tiles, minimal text:
 (A) 52-site photostim grid on the cortical surface; the two exemplar readout
     points used for the LTI fits are ringed (blue = excitatory, red = inhibitory).
 (B) empirical site->self impulse responses (solid) + fitted low-order LTI
     transfer functions (dashed) at both laser amplitudes -> "we fit LTI systems".
 (C) state-dependence: identical stimulation, trials split by pre-stimulus
     cortical activity; higher pre-stim activity -> larger evoked gain.

Output: grid_png/grid_aim1_panel.png
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.interpolate, scipy.signal
from pathlib import Path
import config, tf_fit
from analysis import site_px

OUT = Path(__file__).resolve().parent / "grid_png" / "grid_aim1_panel.png"

# ---- (A) brain + sites ---------------------------------------------------
mimg = np.asarray(np.load(Path(config.EXPDIR) / "blue/meanImage.npy"))
z = np.load(tf_fit.CACHE_TF2, allow_pickle=True)
sites, amps, H, yhat, gain = z["sites"], z["amps"], z["H"], z["yhat"], z["gain"]
tfwin = z["window"]
lateral = np.abs(sites[:, 0]) >= 1.5
gi = gain[-1]
exc = np.where((sites[:, 0] < 0) & lateral)[0]
inh = np.where((sites[:, 0] > 0) & lateral)[0]
s_exc = exc[np.argmax([gi[i, i] for i in exc])]
s_inh = inh[np.argmin([gi[i, i] for i in inh])]

# ---- (C) prediction error vs pre-stim state (Fig-2J/2K style) -------------
# LTI/drive-only predictor -> per-trial residual (evoked scalar minus amp-mean);
# binned by pre-stim RELATIVE delta (power-independent, admissible marker),
# prediction error = pooled-within-cell SD of the residual per quartile.
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
        s = rng.choice(idx, len(idx), replace=True)
        mm = np.zeros(len(resid), bool); mm[s] = True
        bs.append(_pooled_sd(mm))
    pe_lo.append(np.nanpercentile(bs, 2.5)); pe_hi.append(np.nanpercentile(bs, 97.5))
q1 = pe[0]
pe_n = pe / q1; pe_lo = np.array(pe_lo) / q1; pe_hi = np.array(pe_hi) / q1

# ========================= figure ========================================
BLUE, RED = "#3070b3", "#c02020"
fig = plt.figure(figsize=(7.4, 2.4), dpi=300)
gs = fig.add_gridspec(1, 3, width_ratios=[1.05, 1.35, 1.0], wspace=0.46)

# (A) brain
axA = fig.add_subplot(gs[0, 0])
axA.imshow(mimg, cmap="gray"); axA.set_axis_off()
sx, sy = site_px(sites[:, 0], sites[:, 1], config.BREGMA_PX,
                 config.PX_PER_MM_X, config.PX_PER_MM_Y)
axA.scatter(sx, sy, c="w", s=9, lw=0, alpha=0.55)
for s, col in [(s_exc, BLUE), (s_inh, RED)]:
    px, py = site_px(sites[s, 0], sites[s, 1], config.BREGMA_PX,
                     config.PX_PER_MM_X, config.PX_PER_MM_Y)
    axA.scatter(px, py, ec=col, fc="none", s=120, lw=2.0)
axA.set_title("52-site photostim grid", fontsize=8.5, pad=3)
# tighten to the cortical window
axA.set_xlim(60, 500); axA.set_ylim(500, 60)

# (B) LTI fits, two exemplars stacked
gsB = gs[0, 1].subgridspec(1, 2, wspace=0.28)
for j, (s, col, lab) in enumerate([(s_exc, BLUE, "excitatory"),
                                   (s_inh, RED, "inhibitory")]):
    ax = fig.add_subplot(gsB[0, j])
    for ai, alpha in zip(range(len(amps)), [0.55, 1.0]):
        ax.plot(tfwin, H[ai, s, s], c=col, lw=1.5, alpha=alpha)
        ax.plot(tfwin, yhat[ai, s, s], c="k", lw=0.9, ls="--", alpha=alpha)
    ax.axhline(0, c="0.75", lw=0.5); ax.axvline(0, c="0.75", lw=0.5)
    ax.set_xlim(-0.1, 0.6); ax.set_xticks([0, 0.3, 0.6])
    ax.set_title(lab, fontsize=8)
    ax.set_xlabel("t (s)", fontsize=8); ax.tick_params(labelsize=7)
    for sp in ["top", "right"]:
        ax.spines[sp].set_visible(False)
    if j == 0:
        ax.set_ylabel("ΔF/F", fontsize=8.5)
    if j == 1:
        ax.plot([], [], "k-", lw=1.4, label="data")
        ax.plot([], [], "k--", lw=0.9, label="LTI fit")
        ax.legend(fontsize=6.8, frameon=False, loc="lower right",
                  handlelength=1.2, borderaxespad=0.1)

# (C) prediction error vs pre-stim state
axC = fig.add_subplot(gs[0, 2])
xb = np.arange(1, NBIN + 1)
axC.fill_between(xb, pe_lo, pe_hi, color=RED, alpha=0.18)
axC.plot(xb, pe_n, "-o", color=RED, lw=1.9, ms=5)
axC.set_xticks(xb); axC.set_xticklabels(["Q1", "Q2", "Q3", "Q4"])
axC.set_xlabel("pre-stim state (quartile)", fontsize=8)
axC.set_ylabel("LTI pred. error\n(rel. to Q1)", fontsize=8.5)
axC.set_title("model error grows with state", fontsize=8.5)
axC.margins(x=0.08)
axC.tick_params(labelsize=7.5)
for sp in ["top", "right"]:
    axC.spines[sp].set_visible(False)

# panel letters (figure coords so they clear the titles)
for x, L in [(0.055, "A"), (0.36, "B"), (0.70, "C")]:
    fig.text(x, 1.0, L, fontsize=11, fontweight="bold", va="top", ha="right")

fig.savefig(OUT, dpi=300, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
