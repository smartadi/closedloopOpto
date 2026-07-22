"""rank1_plots.py — summary of the adopted rank-1 (one free shape + per-amp gain) amplitude model.

Consumes grid_tf_fits_rank1.npz (tf_fit.fit_rank1). Produces grid_png/rank1_summary.png.
Run:  ../../.venv/Scripts/python.exe rank1_plots.py
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

D = Path(__file__).resolve().parents[2] / "data"
OUT = Path(__file__).resolve().parent / "grid_png"
Z = np.load(D / "grid_tf_fits_rank1.npz", allow_pickle=True)

sites, amps, window, tpost = Z["sites"], Z["amps"], Z["window"], Z["tpost"]
ratio, r2a, cvr2, gain = Z["ratio"], Z["r2_amp"], Z["cvr2"], Z["gain"]
shape, yhat, H = Z["shape"], Z["yhat"], Z["H"]
nS = len(sites)
good = cvr2 > 0
di = np.arange(nS)
x, y = sites[:, 0], sites[:, 1]

fig, ax = plt.subplots(2, 3, figsize=(16, 9), constrained_layout=True)

# (A) per-amp fit quality — the energy-dominance asymmetry
a = ax[0, 0]
r1 = r2a[0][good]; r2v = r2a[1][good]
a.hist(r1, bins=25, range=(-0.5, 1), alpha=0.6, color="#1f77b4", label=f"amp {amps[0]:.1f}  med {np.nanmedian(r1):.2f}")
a.hist(r2v, bins=25, range=(-0.5, 1), alpha=0.6, color="#d62728", label=f"amp {amps[1]:.1f}  med {np.nanmedian(r2v):.2f}")
a.set(xlabel="per-pair R²", ylabel="# pairs (CV-R²>0)",
      title="fit quality per amp\n(plain SVD shape is energy-dominated by high amp)")
a.legend(fontsize=8)

# (B) dose-response gain ratio distribution
a = ax[0, 1]
rr = ratio[good]; rr = rr[np.isfinite(rr) & (np.abs(rr) < 4)]
a.hist(rr, bins=30, color="seagreen")
a.axvline(np.median(rr), c="k", lw=1.5, label=f"median {np.median(rr):.2f}")
a.axvline(amps[1] / amps[0], c="r", ls="--", lw=1.5, label=f"linear {amps[1]/amps[0]:.1f}")
a.set(xlabel="per-pair gain ratio  g(amp2)/g(amp1)", ylabel="# pairs",
      title="dose-response, read off directly\n(no a^γ assumption)")
a.legend(fontsize=8)

# (C) dose-response ratio, on-site pairs, in brain coords (CV-gated)
a = ax[0, 2]
dg = (cvr2[di, di] > 0.2)
rr_on = np.where(dg, ratio[di, di], np.nan)
sc = a.scatter(x[dg], y[dg], c=np.clip(rr_on[dg], 0, 2.2), s=200, cmap="viridis",
               ec="k", lw=0.5, vmin=0.5, vmax=2.0)
a.scatter(x[~dg], y[~dg], facecolors="none", ec="0.7", s=120, lw=1.0)
a.axvline(0, c="0.6", lw=0.7, ls="--"); a.plot(0, 0, "+", c="lime", ms=9, mew=1.5)
a.set(aspect="equal", xlabel="ML (mm)", ylabel="AP (mm)",
      title="on-site dose-response ratio\n(hollow = CV≤0.2; excit L scales more)")
fig.colorbar(sc, ax=a, shrink=0.8, label="g(amp2)/g(amp1)")

# (D) the shared shapes of a few strong on-site pairs (unit-normalised)
a = ax[1, 0]
strong = np.argsort(-np.abs(gain[1][di, di]) * (cvr2[di, di] > 0.2))[:6]
for s in strong:
    w = shape[s, s]
    a.plot(tpost, w / np.max(np.abs(w)), lw=1.3, label=f"({sites[s,0]:+.1f},{sites[s,1]:+.0f})")
a.axhline(0, c="k", lw=0.4, ls=":"); a.axvline(0, c="grey", lw=0.5)
a.set(xlabel="t (s)", ylabel="normalised shape", title="the shared waveform w(t)\n(strong on-site pairs)")
a.legend(fontsize=7, ncol=2)

# (E,F) two example fits: data vs g_a * w(t)
for a, s in zip([ax[1, 1], ax[1, 2]], strong[:2]):
    for ai, c in enumerate(["#1f77b4", "#d62728"]):
        a.plot(window, H[ai, s, s], c=c, lw=1.4, label=f"amp {amps[ai]:.1f} data")
        a.plot(window, yhat[ai, s, s], c=c, lw=1.1, ls="--")
    a.axvline(0, c="grey", lw=0.5); a.axhline(0, c="k", lw=0.4, ls=":")
    a.set(xlim=(-0.2, 0.6), xlabel="t (s)", ylabel="dF/F",
          title=f"self ({sites[s,0]:+.1f},{sites[s,1]:+.0f})  ratio={ratio[s,s]:.2f}  "
                f"R²={np.nanmean(r2a[:,s,s]):.2f}")
    a.legend(fontsize=7)

fig.suptitle("Rank-1 amplitude model: one free shape w(t) + per-amp gain  (h_a = g_a·w)  "
             f"— {good.sum()} CV-R²>0 pairs", fontsize=13)
OUT.mkdir(exist_ok=True)
fig.savefig(OUT / "rank1_summary.png", dpi=140)
plt.close(fig)
print("wrote", OUT / "rank1_summary.png")
