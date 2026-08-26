# -*- coding: utf-8 -*-
"""Grid state-dependence: does pre-stimulus cortical state predict the evoked
FOCAL photostim response on the AL_0048 52-site grid?

Uses the single-trial cache data/grid_trials_2amp.npz (continuous per-site ROI
time-series). For each onset of each stimulated site, computes a pre-stimulus
state regressor (pre-stim variance and pre-stim 1-4 Hz power over a 1 s window
ending at onset) and the evoked focal response (signed peak-|.| of the baselined
post-onset trace at the STIMULATED site). Regressors and responses are z-scored
WITHIN site x amplitude (removes site/opsin/dose differences), then pooled.

Outputs: grid_png/grid_state_dependence.png  + printed r / p.
"""
import numpy as np
import scipy.interpolate
import scipy.stats
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRIALS2 = Path(__file__).resolve().parents[2] / "data" / "grid_trials_2amp.npz"
OUT = HERE / "grid_png" / "grid_state_dependence.png"

PRE_T0, PRE_T1 = -1.0, -0.05      # pre-stim state window (s, ends before onset)
POST_T0, POST_T1 = 0.03, 0.45     # evoked window (s) — skip the on-artifact
LOWF = (1.0, 4.0)                  # low-frequency band (Hz)

t = np.load(TRIALS2, allow_pickle=True)
roi_ts = t["roi_ts"].astype(np.float64)     # (T, nS)
svdT = t["svdT"]; onset_t = t["onset_t"]
pos = t["pos"]; sites = t["sites"]
onset_amp = np.round(t["onset_amp"], 3)
window = t["window"]
fs = 1.0 / np.median(np.diff(window))
pre_win = np.arange(PRE_T0, PRE_T1, 1.0 / fs)
amps = [a for a in np.unique(onset_amp) if a > 0.05]
print(f"fs={fs:.1f}Hz  nSites={len(sites)}  amps={amps}  nOnsets={len(onset_t)}")

def bandpower(x, fs, lo, hi):
    x = x - np.nanmean(x)
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / fs)
    P = np.abs(np.fft.rfft(x)) ** 2
    m = (f >= lo) & (f <= hi)
    return np.nansum(P[m])

rows = []   # (site, amp, prestim_var, prestim_lowf, evoked_signedpeak)
for s_idx, (mx, my) in enumerate(sites):
    interp = scipy.interpolate.interp1d(svdT, roi_ts[:, s_idx],
                                        bounds_error=False, fill_value=np.nan)
    for amp in amps:
        sel = (pos[:, 0] == mx) & (pos[:, 1] == my) & (onset_amp == amp)
        these = onset_t[sel]
        if len(these) < 8:
            continue
        pre = interp(pre_win[None, :] + these[:, None])     # (nTr, nPre)
        post = interp(window[None, :] + these[:, None])     # (nTr, nWin)
        base = np.nanmean(post[:, window < 0], axis=1, keepdims=True)
        post = post - base
        pmask = (window >= POST_T0) & (window <= POST_T1)
        seg = post[:, pmask]                                 # (nTr, nPost)
        # Template-projection gain: amplitude of each trial ALONG the site's
        # mean evoked shape (robust to broadband noise, unlike |peak|). The
        # template is leave-one-out to avoid a trivial self-projection bias.
        good_tr = np.all(np.isfinite(seg), axis=1)
        tmpl_all = np.nanmean(seg[good_tr], axis=0)
        tt = float(tmpl_all @ tmpl_all)
        n_ok = good_tr.sum()
        evoked = np.full(seg.shape[0], np.nan)
        for i in range(seg.shape[0]):
            if not good_tr[i] or tt <= 0:
                continue
            # leave-one-out template
            tl = (tmpl_all * n_ok - seg[i]) / (n_ok - 1)
            evoked[i] = (seg[i] @ tl) / (tl @ tl)
        pv = np.nanvar(pre, axis=1)
        lf = np.array([bandpower(pre[i], fs, *LOWF) for i in range(pre.shape[0])])
        for i in range(len(these)):
            if np.isfinite(pv[i]) and np.isfinite(evoked[i]) and np.isfinite(lf[i]):
                rows.append((s_idx, amp, pv[i], lf[i], evoked[i]))

R = np.array(rows, float)
print(f"pooled trials: {len(R)}")

# z-score within site x amp
def zwithin(col_val, keycols):
    out = np.full(len(col_val), np.nan)
    keys = R[:, keycols]
    uk = np.unique(keys, axis=0)
    for k in uk:
        m = np.all(keys == k, axis=1)
        v = col_val[m]
        if np.nanstd(v) > 0 and m.sum() >= 8:
            out[m] = (v - np.nanmean(v)) / np.nanstd(v)
    return out

z_var = zwithin(R[:, 2], [0, 1])
z_lowf = zwithin(R[:, 3], [0, 1])
z_absevk = zwithin(R[:, 4], [0, 1])   # evoked GAIN along the mean response shape
# reproducibility: |trial - within-cell mean| already captured by z of |evoked|
good = np.isfinite(z_var) & np.isfinite(z_absevk) & np.isfinite(z_lowf)
zv, zl, za = z_var[good], z_lowf[good], z_absevk[good]
print(f"z-scored trials: {good.sum()}")

r_var, p_var = scipy.stats.spearmanr(zv, za)
r_lf, p_lf = scipy.stats.spearmanr(zl, za)
print(f"pre-stim VARIANCE vs |evoked focal|:  Spearman r={r_var:+.3f}  p={p_var:.2e}")
print(f"pre-stim 1-4Hz POWER vs |evoked focal|: Spearman r={r_lf:+.3f}  p={p_lf:.2e}")

# ---- figure: quartile bars (variance) + scatter -------------------------
fig, ax = plt.subplots(1, 2, figsize=(7.2, 3.0), dpi=300)

# (A) quartile bars: |evoked| by pre-stim variance quartile
q = np.quantile(zv, [0, .25, .5, .75, 1.0])
labels = ["Q1\n(low var)", "Q2", "Q3", "Q4\n(high var)"]
means, sems = [], []
for i in range(4):
    m = (zv >= q[i]) & (zv <= q[i + 1]) if i == 3 else (zv >= q[i]) & (zv < q[i + 1])
    means.append(np.mean(za[m])); sems.append(np.std(za[m]) / np.sqrt(m.sum()))
ax[0].bar(range(4), means, yerr=sems, color="#3070b3", alpha=0.85, capsize=3)
ax[0].set_xticks(range(4)); ax[0].set_xticklabels(labels, fontsize=7.5)
ax[0].set_ylabel("evoked gain  (z)", fontsize=8.5)
ax[0].set_title("Pre-stim variance → response magnitude", fontsize=9, fontweight="bold")
ax[0].tick_params(labelsize=8)
for sp in ["top", "right"]:
    ax[0].spines[sp].set_visible(False)

# (B) scatter with binned trend
ax[1].plot(zv, za, "o", ms=1.2, color="0.6", alpha=0.35, mew=0)
nb = 12
bins = np.quantile(zv, np.linspace(0, 1, nb + 1))
bc = 0.5 * (bins[:-1] + bins[1:]); bm = []
for i in range(nb):
    m = (zv >= bins[i]) & (zv <= bins[i + 1]) if i == nb - 1 else (zv >= bins[i]) & (zv < bins[i + 1])
    bm.append(np.mean(za[m]))
ax[1].plot(bc, bm, "-o", color="#c02020", ms=3, lw=1.4)
sl, ic = np.polyfit(zv, za, 1)
xs = np.array([zv.min(), zv.max()])
ax[1].plot(xs, sl * xs + ic, "k--", lw=1.0)
ax[1].set_xlabel("pre-stim variance  (z)", fontsize=8.5)
ax[1].set_ylabel("evoked gain  (z)", fontsize=8.5)
ax[1].set_title(f"Spearman r = {r_var:+.2f}", fontsize=9, fontweight="bold")
ax[1].set_ylim(np.quantile(za, 0.005), np.quantile(za, 0.995))
ax[1].tick_params(labelsize=8)
for sp in ["top", "right"]:
    ax[1].spines[sp].set_visible(False)

fig.tight_layout()
fig.savefig(OUT, dpi=300, facecolor="white", bbox_inches="tight")
print("wrote", OUT)
