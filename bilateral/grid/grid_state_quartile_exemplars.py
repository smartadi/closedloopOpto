# -*- coding: utf-8 -*-
"""Actual response vs expected, split by pre-stimulus state quartile.
Justifies the grid prediction-error-vs-state result (Fig 8C): for each
pre-stimulus relative-delta quartile Q1..Q4, the ACTUAL evoked response
(quartile mean, +/-1 SD band across trials) is overlaid on the EXPECTED
(drive-only) prediction = the grand-mean normalized response. The spread of
actual trials around the expectation grows Q1->Q4 (annotated residual SD).

Output: grid_png/grid_state_quartile_exemplars.png
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.interpolate
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRIALS2 = Path(__file__).resolve().parents[2] / "data" / "grid_trials_2amp.npz"
OUT = HERE / "grid_png" / "grid_state_quartile_exemplars.png"
PRE_T0, PRE_T1 = -1.0, -0.02
POST_T0, POST_T1 = 0.03, 0.45
NBIN = 4

t = np.load(TRIALS2, allow_pickle=True)
roi_ts = t["roi_ts"].astype(float)
svdT = t["svdT"]; onset_t = t["onset_t"]
pos = t["pos"]; sites = t["sites"]
onset_amp = np.round(t["onset_amp"], 3); window = t["window"]
fs = 1.0 / np.median(np.diff(window))
pre_win = np.arange(PRE_T0, PRE_T1, 1.0 / fs)
amps = [a for a in np.unique(onset_amp) if a > 0.05]
pmask = (window >= POST_T0) & (window <= POST_T1)
bmask = (window >= -0.12) & (window < 0)


def rel_delta(seg, fs):
    n = seg.shape[1]; w = np.hanning(n)
    x = seg - np.nanmean(seg, 1, keepdims=True); x = np.nan_to_num(x)
    X = np.abs(np.fft.rfft(x * w, axis=1)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / fs)
    d = (f >= 1) & (f <= 4); b = (f >= 0.5) & (f <= 30)
    return X[:, d].sum(1) / np.maximum(X[:, b].sum(1), 1e-12)


Qtr = [[] for _ in range(NBIN)]
for s_idx, (mx, my) in enumerate(sites):
    interp = scipy.interpolate.interp1d(svdT, roi_ts[:, s_idx],
                                        bounds_error=False, fill_value=np.nan)
    for amp in amps:
        sel = (pos[:, 0] == mx) & (pos[:, 1] == my) & (onset_amp == amp)
        these = onset_t[sel]
        if len(these) < 16:
            continue
        pre = interp(pre_win[None, :] + these[:, None])
        post = interp(window[None, :] + these[:, None])
        post = post - np.nanmean(post[:, bmask], axis=1, keepdims=True)
        ok = np.all(np.isfinite(post), 1) & np.all(np.isfinite(pre), 1)
        post, pre = post[ok], pre[ok]
        if ok.sum() < 16:
            continue
        mean_resp = np.nanmean(post, 0)
        pk = mean_resp[pmask][np.nanargmax(np.abs(mean_resp[pmask]))]
        if abs(pk) < 1e-4:
            continue
        norm = post / pk                       # sign-align + peak-normalize (expected peak ~ +1)
        dpr = rel_delta(pre, fs)
        e = np.quantile(dpr, np.linspace(0, 1, NBIN + 1))
        q = np.clip(np.digitize(dpr, e[1:-1]), 0, NBIN - 1)
        for b in range(NBIN):
            if (q == b).any():
                Qtr[b].append(norm[q == b])

Qtr = [np.vstack(x) for x in Qtr]
expected = np.nanmean(np.vstack(Qtr), 0)       # grand-mean normalized = drive-only expectation

cols = ["#2c7fb8", "#41b6c4", "#fd8d3c", "#e31a1c"]
rng = np.random.default_rng(0)
NEX = 18                                        # individual example trials per quartile
fig, axes = plt.subplots(1, NBIN, figsize=(2.15 * NBIN, 2.5), dpi=300, sharey=True)
labels = ["Q1 (low)", "Q2", "Q3", "Q4 (high)"]
for b in range(NBIN):
    ax = axes[b]; T = Qtr[b]
    idx = rng.choice(len(T), size=min(NEX, len(T)), replace=False)
    for i in idx:
        ax.plot(window, T[i], color=cols[b], lw=0.6, alpha=0.4)   # individual actual trials
    ax.plot(window, expected, color="0.12", lw=1.8, ls="--")      # expected (drive-only)
    ax.axhline(0, c="0.8", lw=0.5); ax.axvline(0, c="0.8", lw=0.5)
    ax.set_xlim(-0.1, 0.5); ax.set_xticks([0, 0.2, 0.4]); ax.set_ylim(-4.5, 5.5)
    resid = np.nanstd(T[:, pmask] - expected[pmask], axis=1)
    ax.set_title(f"{labels[b]}   resid SD={np.nanmean(resid):.2f}", fontsize=8)
    ax.set_xlabel("t (s)", fontsize=8); ax.tick_params(labelsize=7)
    for sp in ["top", "right"]:
        ax.spines[sp].set_visible(False)
axes[0].set_ylabel("norm. response", fontsize=8.5)
axes[NBIN - 1].plot([], [], "0.12", ls="--", lw=1.8, label="expected (drive-only)")
axes[NBIN - 1].legend(fontsize=7, frameon=False, loc="upper right",
                      handlelength=1.2, borderaxespad=0.2)
fig.suptitle("Individual actual trials vs expected, by pre-stim state quartile", fontsize=9)
fig.tight_layout()
fig.savefig(OUT, dpi=300, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
for b in range(NBIN):
    r = np.nanstd(Qtr[b][:, pmask] - expected[pmask], axis=1)
    print(f"  Q{b+1}: n={len(Qtr[b])}  mean resid SD={np.nanmean(r):.3f}")
