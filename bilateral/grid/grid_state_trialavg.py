# -*- coding: utf-8 -*-
"""Grid state-dependence, trial-averaged comparison (matches the AL_0033
motion / pre-stim-variance style): split each site's focal-response trials by
pre-stimulus variance (low vs high, within-site median split), sign-align and
peak-normalize each site, then pool the trial-averaged response across sites.
Overlapping low/high traces => the local response is state-robust.

Output: grid_png/grid_state_trialavg.png
"""
import numpy as np
import scipy.interpolate
import scipy.signal
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRIALS2 = Path(__file__).resolve().parents[2] / "data" / "grid_trials_2amp.npz"
OUT = HERE / "grid_png" / "grid_state_trialavg.png"

PRE_T0, PRE_T1 = -1.0, -0.05
POST_T0, POST_T1 = 0.03, 0.45

t = np.load(TRIALS2, allow_pickle=True)
roi_ts = t["roi_ts"].astype(np.float64)
svdT = t["svdT"]; onset_t = t["onset_t"]
pos = t["pos"]; sites = t["sites"]
onset_amp = np.round(t["onset_amp"], 3)
window = t["window"]
fs = 1.0 / np.median(np.diff(window))
pre_win = np.arange(PRE_T0, PRE_T1, 1.0 / fs)
amps = [a for a in np.unique(onset_amp) if a > 0.05]
pmask = (window >= POST_T0) & (window <= POST_T1)

# high-pass the continuous per-site signal at 1 Hz to remove slow drift, so the
# pre-stim-variance split reflects fast cortical-state fluctuations and the
# evoked transient rather than non-stationary baseline ramps.
sos = scipy.signal.butter(2, 1.0, btype="high", fs=fs, output="sos")
roi_hp = scipy.signal.sosfiltfilt(sos, roi_ts, axis=0)

low_pool, high_pool = [], []
gain_lo, gain_hi = [], []
for s_idx, (mx, my) in enumerate(sites):
    interp = scipy.interpolate.interp1d(svdT, roi_hp[:, s_idx],
                                        bounds_error=False, fill_value=np.nan)
    for amp in amps:
        sel = (pos[:, 0] == mx) & (pos[:, 1] == my) & (onset_amp == amp)
        these = onset_t[sel]
        if len(these) < 16:
            continue
        pre = interp(pre_win[None, :] + these[:, None])
        post = interp(window[None, :] + these[:, None])
        # tight onset baseline on the drift-free (high-passed) signal
        bmask = (window >= -0.12) & (window < 0)
        base = np.nanmean(post[:, bmask], axis=1, keepdims=True)
        post = post - base
        ok = np.all(np.isfinite(post), axis=1) & np.all(np.isfinite(pre), axis=1)
        post, pre, these_ok = post[ok], pre[ok], these[ok]
        if ok.sum() < 16:
            continue
        pv = np.nanvar(pre, axis=1)
        mean_resp = np.nanmean(post, axis=0)
        pk = mean_resp[pmask][np.nanargmax(np.abs(mean_resp[pmask]))]
        if abs(pk) < 1e-4:
            continue
        norm = post / pk                        # sign-align + peak-normalize
        med = np.median(pv)
        lo = norm[pv <= med]; hi = norm[pv > med]
        if len(lo) >= 4 and len(hi) >= 4:
            low_pool.append(np.nanmean(lo, axis=0))
            high_pool.append(np.nanmean(hi, axis=0))
            # DIAGNOSTIC: per-trial shape-projection gain, same median split.
            seg = post[:, pmask]
            tmpl = np.nanmean(seg, axis=0)
            tt = float(tmpl @ tmpl)
            if tt > 0:
                g = (seg @ tmpl) / tt           # gain of each trial along shape
                gain_lo.append(np.nanmean(g[pv <= med]))
                gain_hi.append(np.nanmean(g[pv > med]))

low = np.array(low_pool); high = np.array(high_pool)
n = low.shape[0]
lo_m, lo_e = np.nanmean(low, 0), np.nanstd(low, 0) / np.sqrt(n)
hi_m, hi_e = np.nanmean(high, 0), np.nanstd(high, 0) / np.sqrt(n)
print(f"pooled site x amp cells: {n}")
gl, gh = np.array(gain_lo), np.array(gain_hi)
print(f"[DIAG] within-cell shape-projection gain  low={np.nanmean(gl):.3f}  "
      f"high={np.nanmean(gh):.3f}  high>low in {(gh>gl).mean()*100:.0f}% of cells")
print(f"[DIAG] peak-amplitude ratio high/low (pooled trace) = "
      f"{np.nanmax(np.nanmean(high,0))/np.nanmax(np.nanmean(low,0)):.2f}")

fig, ax = plt.subplots(figsize=(3.0, 2.4), dpi=300)
ax.axhline(0, color="0.75", lw=0.6)
ax.axvline(0, color="0.75", lw=0.6)
ax.fill_between(window, lo_m - lo_e, lo_m + lo_e, color="#3070b3", alpha=0.22)
ax.fill_between(window, hi_m - hi_e, hi_m + hi_e, color="#c02020", alpha=0.22)
ax.plot(window, lo_m, color="#3070b3", lw=1.8, label="low pre-stim activity")
ax.plot(window, hi_m, color="#c02020", lw=1.8, label="high pre-stim activity")
ax.set_xlim(-0.15, 0.5)
ax.set_xticks([0, 0.2, 0.4])
ax.set_xlabel("time from stim (s)", fontsize=8.5)
ax.set_ylabel("norm. response", fontsize=8.5)
ax.legend(fontsize=7.5, frameon=False, loc="upper right", handlelength=1.0,
          borderaxespad=0.2, handletextpad=0.5)
ax.tick_params(labelsize=8)
for sp in ["top", "right"]:
    ax.spines[sp].set_visible(False)
fig.tight_layout()
fig.savefig(OUT, dpi=300, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
