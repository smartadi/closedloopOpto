"""shared_amp_plots.py — visual summary of the shared-TF / amplitude-linearity investigation.

Consumes the per-amp independent fit (grid_tf_fits_2amp.npz) and the four shared-model variants:
  _raw   unweighted, gamma=1     _linw  weighted, gamma=1
  _shared weighted, gamma free   _gglob weighted, one GLOBAL gamma (fixed)

Produces grid_png/shared_amp_summary.png (6 panels) + a few example-pair fits.
Run:  ../../.venv/Scripts/python.exe shared_amp_plots.py
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.optimize

D = Path(__file__).resolve().parents[2] / "data"
OUT = Path(__file__).resolve().parent / "grid_png"


def load(name):
    z = np.load(D / name, allow_pickle=True)
    return {k: z[k] for k in z.files}


Z2 = load("grid_tf_fits_2amp.npz")
VAR = {}
for tag, fn in [("A raw (unwt, γ=1)", "grid_tf_fits_shared_raw.npz"),
                ("B wt, γ=1", "grid_tf_fits_shared_linw.npz"),
                ("C wt, γ free", "grid_tf_fits_shared.npz"),
                ("D wt, γ global", "grid_tf_fits_shared_gglob.npz")]:
    if (D / fn).exists():
        VAR[tag] = load(fn)

sites, window, amps = Z2["sites"], Z2["window"], Z2["amps"]
fit = (window >= 0) & (window <= 0.6)
cv = Z2["cvr2"]
good = (cv[0] > 0.2) & (cv[1] > 0.2)                 # well fit at BOTH amps
h1 = Z2["H"][0][good][:, fit]
h2 = Z2["H"][1][good][:, fit]
ratio = float(amps[1] / amps[0])

# --- model-free quantities ---
n1 = h1 / np.linalg.norm(h1, axis=1, keepdims=True)
n2 = h2 / np.linalg.norm(h2, axis=1, keepdims=True)
shape = np.sum(n1 * n2, 1)
k = np.sum(h1 * h2, 1) / np.sum(h1 * h1, 1)          # per-pair rescale magnitude (for panel F)

# TRUE ceiling for ANY "one shape + per-amp gain" model (the shared TF is a CONSTRAINED case:
# it further forces the shape to be a low-order LTI response and the gains to follow a^gamma).
# Best rank-1 fit of the stacked [h1; h2] via SVD; per-amp R2 vs each amp's own mean, averaged.
r2_ceiling = np.empty(h1.shape[0])
for i in range(h1.shape[0]):
    M = np.vstack([h1[i], h2[i]])                    # (2, T)
    U, S, Vt = np.linalg.svd(M, full_matrices=False)
    recon = np.outer(U[:, 0] * S[0], Vt[0])          # best one-shape + per-row gain
    r2a = [1 - np.sum((recon[a] - M[a]) ** 2) / (np.sum((M[a] - M[a].mean()) ** 2) + 1e-12)
           for a in (0, 1)]
    r2_ceiling[i] = np.mean(r2a)


def gobj(g):
    return float(np.sum((ratio ** g * h1 - h2) ** 2))


gs = np.linspace(0.05, 1.6, 120)
gcurve = [gobj(g) for g in gs]
G = float(scipy.optimize.minimize_scalar(gobj, bounds=(0.05, 2.0), method="bounded").x)
CEIL = float(np.median(r2_ceiling))

fig, ax = plt.subplots(2, 3, figsize=(16, 9), constrained_layout=True)

# (A) per-amp R2 across model variants + independent + ceiling
a = ax[0, 0]
labels, r1s, r2s = [], [], []
for tag, Z in VAR.items():
    m = Z["cvr2"] > 0
    labels.append(tag)
    r1s.append(np.nanmedian(Z["r2_amp"][0][m]))
    r2s.append(np.nanmedian(Z["r2_amp"][1][m]))
mi = Z2["cvr2"][0] > 0
labels += ["independent"]
r1s += [np.nanmedian(Z2["r2"][0][mi])]; r2s += [np.nanmedian(Z2["r2"][1][mi])]
x = np.arange(len(labels))
a.bar(x - 0.2, r1s, 0.38, label=f"amp {amps[0]:.1f}", color="#1f77b4")
a.bar(x + 0.2, r2s, 0.38, label=f"amp {amps[1]:.1f}", color="#d62728")
a.axhline(CEIL, c="green", ls="--", lw=1.4, label=f"rescale ceiling {CEIL:.2f}")
a.axhline(0, c="k", lw=0.6)
a.set_xticks(x); a.set_xticklabels(labels, rotation=25, ha="right", fontsize=8)
a.set(ylabel="median R² (CV-R²>0 pairs)", title="per-amp fit quality by model")
a.legend(fontsize=8)

# (B) waveform SHAPE cosine (why a ceiling exists at all)
a = ax[0, 1]
a.hist(shape, bins=25, color="slateblue")
a.axvline(np.median(shape), c="k", lw=1.5, label=f"median {np.median(shape):.3f}")
a.axvline(1.0, c="green", ls="--", lw=1.2, label="identical shape")
a.set(xlabel="amp1↔amp2 waveform cosine (scale removed)", ylabel="# pairs",
      title="response SHAPE changes with power\n(cosine<1 ⇒ no scaling model can be exact)")
a.legend(fontsize=8)

# (C) the achievable ceiling: best per-pair rescale R2
a = ax[0, 2]
a.hist(r2_ceiling, bins=25, range=(-0.5, 1), color="seagreen", alpha=0.8, label="best rescale (ceiling)")
if "C wt, γ free" in VAR:
    rc = np.nanmean(VAR["C wt, γ free"]["r2_amp"], 0)[good]
    a.hist(rc, bins=25, range=(-0.5, 1), color="indianred", alpha=0.6, label="shared γ-free (achieved)")
a.axvline(CEIL, c="green", lw=1.5)
a.set(xlabel="per-pair R² (mean over amps)", ylabel="# pairs",
      title=f"ceiling of ANY one-shape+gain model\nmedian rank-1 R²={CEIL:.2f}")
a.legend(fontsize=8)

# (D) global gamma estimation
a = ax[1, 0]
a.plot(gs, np.array(gcurve) / gcurve[np.argmin(gcurve)], c="navy", lw=1.8)
a.axvline(G, c="navy", ls="-", lw=1.2, label=f"global γ (SSE-opt) = {G:.3f}")
a.axvline(0.474, c="orange", ls="--", lw=1.2, label="per-pair γ median 0.47")
a.axvline(0.573, c="crimson", ls=":", lw=1.4, label="focal-ratio γ 0.57")
a.axvline(1.0, c="green", ls="--", lw=1.0, label="linear (γ=1)")
a.set(xlabel="γ (input nonlinearity exponent)", ylabel="relative SSE",
      title="one GLOBAL γ from waveform rescale\n(three estimates, all ≪ 1)")
a.legend(fontsize=8)

# (E) per-pair gamma unidentifiability
a = ax[1, 1]
if "C wt, γ free" in VAR:
    g = VAR["C wt, γ free"]["gamma"][VAR["C wt, γ free"]["cvr2"] > 0]
    g = g[np.isfinite(g)]
    a.hist(g, bins=30, color="darkorange")
    lo_r, hi_r = 100 * np.mean(g < 0.105), 100 * np.mean(g > 2.9)
    a.axvline(np.median(g), c="k", lw=1.5, label=f"median {np.median(g):.2f}")
    a.axvline(0.1, c="red", ls="--", lw=1.2, label=f"bounds railed: {lo_r:.0f}% lo + {hi_r:.0f}% hi")
    a.axvline(3.0, c="red", ls="--", lw=1.2)
    a.axvline(G, c="navy", ls="-", lw=1.2, label=f"global {G:.2f}")
    a.set(xlabel="per-pair fitted γ", ylabel="# pairs",
          title="per-pair γ is UNIDENTIFIED\n(rails at BOTH bounds ⇒ noise, not signal)")
    a.legend(fontsize=8)

# (F) k vs distance-from-stim (saturation not spatially uniform)
a = ax[1, 2]
si, ri = np.where(good.reshape(len(sites), len(sites)) if False else np.ones_like(cv[0], bool))
# recover (s,r) index of each good pair, in the same order as h1/h2/k
sr = np.array(np.where(good)).T
dist = np.hypot(sites[sr[:, 0], 0] - sites[sr[:, 1], 0], sites[sr[:, 0], 1] - sites[sr[:, 1], 1])
a.scatter(dist, k, s=14, alpha=0.5, c="teal")
a.axhline(ratio, c="r", ls="--", lw=1, label=f"linear (×{ratio:.0f})")
a.axhline(np.median(k), c="k", lw=1.2, label=f"median k={np.median(k):.2f}")
a.set(xlabel="stim→readout distance (mm)", ylabel="amp2/amp1 rescale k",
      title="saturation vs distance\n(on-site scales more than distal)")
a.legend(fontsize=8)

fig.suptitle("Shared-TF amplitude-linearity investigation — AL_0048 2026-07-10 grid "
             f"(n={good.sum()} pairs well fit at both amps)", fontsize=13)
OUT.mkdir(exist_ok=True)
fig.savefig(OUT / "shared_amp_summary.png", dpi=140)
plt.close(fig)
print("wrote", OUT / "shared_amp_summary.png")
print(f"global gamma={G:.3f}  ceiling R2={CEIL:.3f}  median shape cosine={np.median(shape):.3f}")


# --- example pairs: independent vs shared-global-gamma ---
def idx(mx, my):
    return int(np.argmin(np.hypot(sites[:, 0] - mx, sites[:, 1] - my)))


if "D wt, γ global" in VAR:
    ZG = VAR["D wt, γ global"]
    di = np.arange(len(sites))
    strong = np.argsort(-np.abs(Z2["gain"][1][di, di]) * (Z2["cvr2"][1][di, di] > 0.2))[:4]
    fig, ax = plt.subplots(1, 4, figsize=(17, 3.8), constrained_layout=True)
    cols = ["#1f77b4", "#d62728"]
    for a, s in zip(ax, strong):
        for ai, c in enumerate(cols):
            a.plot(window, Z2["H"][ai, s, s], c=c, lw=1.4, label=f"amp {amps[ai]:.1f} data")
            a.plot(window, ZG["yhat"][ai, s, s], c=c, lw=1.1, ls="--")
        a.axvline(0, c="grey", lw=0.5); a.axhline(0, c="k", lw=0.4, ls=":")
        a.set(xlim=(-0.2, 0.6), xlabel="t (s)",
              title=f"self ({sites[s,0]:+.1f},{sites[s,1]:+.0f})  R²={np.nanmean(ZG['r2_amp'][:,s,s]):.2f}")
        a.legend(fontsize=7)
    ax[0].set_ylabel("dF/F")
    fig.suptitle(f"Shared TF with ONE global γ={G:.3f} (dashed=fit): both amps from one waveform + "
                 "input nonlinearity", fontsize=12)
    fig.savefig(OUT / "shared_amp_examples.png", dpi=140)
    plt.close(fig)
    print("wrote", OUT / "shared_amp_examples.png")
