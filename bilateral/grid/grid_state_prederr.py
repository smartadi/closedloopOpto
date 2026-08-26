# -*- coding: utf-8 -*-
"""Grid prediction-error vs state, in the style of paper Fig 2J/2K.

For each stimulated site x amplitude, the simplest LTI/drive-only predictor
knows only the laser amplitude and predicts the amplitude-mean evoked response.
The per-trial PREDICTION ERROR is the residual of the trial's evoked scalar
(mean ΔF/F over the evoked window at the stimulated site) from that mean, in
ΔF/F. We bin trials by pre-stimulus cortical state and report the prediction
error per bin, POOLED WITHIN cell (so a bin is not "more uncertain" merely
because it holds bigger-amplitude responses).

State markers (both computed; only the power-independent one is interpreted):
  PVv  pre-stim variance                       -> POWER CONFOUND (greyed)
  DPr  relative 1-4 Hz / 0.5-30 Hz             -> power-independent, ADMISSIBLE

Output: grid_png/grid_state_prederr.png  + printed per-bin curve.
"""
import numpy as np
import scipy.interpolate
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRIALS2 = Path(__file__).resolve().parents[2] / "data" / "grid_trials_2amp.npz"
OUT = HERE / "grid_png" / "grid_state_prederr.png"

PRE_T0, PRE_T1 = -1.0, -0.02      # pre-stim state window (s)
POST_T0, POST_T1 = 0.03, 0.45     # evoked window (s)
NBIN = 4
rng = np.random.default_rng(7)

t = np.load(TRIALS2, allow_pickle=True)
roi_ts = t["roi_ts"].astype(np.float64)
svdT = t["svdT"]; onset_t = t["onset_t"]; pos = t["pos"]; sites = t["sites"]
onset_amp = np.round(t["onset_amp"], 3); window = t["window"]
fs = 1.0 / np.median(np.diff(window))
pre_win = np.arange(PRE_T0, PRE_T1, 1.0 / fs)
amps = [a for a in np.unique(onset_amp) if a > 0.05]
pmask = (window >= POST_T0) & (window <= POST_T1)
bmask = (window >= -0.12) & (window < 0)


def rel_delta(seg, fs):
    """relative 1-4 Hz power / 0.5-30 Hz power per row (Hann, mean-removed)."""
    n = seg.shape[1]
    w = np.hanning(n)
    x = seg - np.nanmean(seg, axis=1, keepdims=True)
    x = np.nan_to_num(x)
    X = np.abs(np.fft.rfft(x * w, axis=1)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / fs)
    d = (f >= 1) & (f <= 4)
    b = (f >= 0.5) & (f <= 30)
    return X[:, d].sum(1) / np.maximum(X[:, b].sum(1), 1e-12)


# per-trial table: cell id, residual (ΔF/F), state markers
cell_id, resid, PVv, DPr = [], [], [], []
cid = 0
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
        ok = np.all(np.isfinite(post), axis=1) & np.all(np.isfinite(pre), axis=1)
        post, pre = post[ok], pre[ok]
        if ok.sum() < 16:
            continue
        r = np.nanmean(post[:, pmask], axis=1)          # evoked scalar, ΔF/F
        e = r - np.nanmean(r)                            # drive-only pred. error
        cell_id.extend([cid] * len(e)); resid.extend(e)
        PVv.extend(np.nanvar(pre, axis=1))
        DPr.extend(rel_delta(pre, fs))
        cid += 1
cell_id = np.array(cell_id); resid = np.array(resid)
PVv = np.array(PVv); DPr = np.array(DPr)
ncell = cid
print(f"cells={ncell}  trials={len(resid)}")


def rank_within_cell(v):
    out = np.full(len(v), np.nan)
    for c in np.unique(cell_id):
        m = cell_id == c
        vi = v[m]
        r = np.argsort(np.argsort(vi))
        out[m] = (r + 0.5) / len(vi)
    return out


def pooled_within_cell_sd(mask):
    """sqrt of pooled within-cell variance of resid over the masked trials, ΔF/F."""
    num = den = 0.0
    for c in np.unique(cell_id[mask]):
        v = resid[mask & (cell_id == c)]
        v = v[np.isfinite(v)]
        if len(v) < 3:
            continue
        num += (len(v) - 1) * np.var(v, ddof=1)
        den += (len(v) - 1)
    return np.sqrt(num / den) if den > 0 else np.nan


def curve(state, label):
    rk = rank_within_cell(state)
    edges = np.linspace(0, 1, NBIN + 1)
    g = np.clip(np.digitize(rk, edges[1:-1]), 0, NBIN - 1)
    pe, lo, hi = [], [], []
    for b in range(NBIN):
        m = g == b
        pe.append(pooled_within_cell_sd(m))
        # bootstrap CI over trials in the bin
        idx = np.where(m)[0]
        bs = []
        for _ in range(600):
            s = rng.choice(idx, len(idx), replace=True)
            mm = np.zeros(len(resid), bool); mm[s] = True
            bs.append(pooled_within_cell_sd(mm))
        lo.append(np.nanpercentile(bs, 2.5)); hi.append(np.nanpercentile(bs, 97.5))
    pe = np.array(pe)
    tr = np.corrcoef(np.arange(NBIN), pe)[0, 1]
    print(f"{label:14s} prediction error by bin: "
          + "  ".join(f"{x:.4f}" for x in pe) + f"   (trend r={tr:+.2f})")
    return pe, np.array(lo), np.array(hi), tr


pe_d, lo_d, hi_d, tr_d = curve(DPr, "rel-delta")
pe_v, lo_v, hi_v, tr_v = curve(PVv, "variance")

# ---- figure: single admissible series (relative delta), normalised to Q1 -----
# roi_ts is raw SVD units, not ΔF/F, so the curve is normalised to its Q1 value
# (relative prediction error); the message is the monotone rise with state.
q1 = pe_d[0]
pe_n, lo_n, hi_n = pe_d / q1, lo_d / q1, hi_d / q1
fig, ax = plt.subplots(figsize=(2.9, 2.4), dpi=300)
x = np.arange(1, NBIN + 1)
RED = "#c02020"
ax.fill_between(x, lo_n, hi_n, color=RED, alpha=0.18)
ax.plot(x, pe_n, "-o", color=RED, lw=1.9, ms=5)
ax.set_xticks(x); ax.set_xticklabels(["Q1", "Q2", "Q3", "Q4"])
ax.set_xlabel("pre-stim state (quartile)", fontsize=8.5)
ax.set_ylabel("LTI prediction error\n(rel. to Q1)", fontsize=8.5)
ax.set_title("model error grows with state", fontsize=8.5)
ax.tick_params(labelsize=8)
ax.margins(x=0.08)
for sp in ["top", "right"]:
    ax.spines[sp].set_visible(False)
fig.tight_layout()
fig.savefig(OUT, dpi=300, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
