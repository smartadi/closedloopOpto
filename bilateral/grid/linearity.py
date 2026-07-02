"""linearity.py — does the grid perturbation response scale linearly with laser amplitude?

Loads the two-amp response tensor (cross_response.build_amps -> grid_cross_response_2amp.npz)
and, per (stim, readout) pair, tests the LTI/linearity signature: is the higher-amp response a
SCALAR MULTIPLE of the lower-amp one (same dynamics, only amplitude scaled)? If so the pair is
linear over this range; if the shape changes with drive it is nonlinear (saturating, etc.).

Per pair we report, over the post-onset window:
  k    = best least-squares scale  s.t.  H_high ≈ k · H_low   ( <H_hi,H_lo> / <H_lo,H_lo> )
  r2   = fraction of H_high variance explained by k · H_low   (1 = perfectly scaled)
  corr = waveform correlation of H_low vs H_high              (shape match, gain-independent)
  peak = peak |dF/F| at each amp                              (response strength / SNR gate)

Input is treated as two NOMINAL levels (0.25, 0.5 command), NOT calibrated mW (per user).
Run:  .venv/Scripts/python.exe bilateral/grid/linearity.py            (summary figure)
      .venv/Scripts/python.exe bilateral/grid/linearity.py pairs      (representative overlays)
"""
from pathlib import Path

import numpy as np

import cross_response as cr

OUT = Path(__file__).resolve().parent / "grid_png"
LIN_WIN = (0.0, 0.4)   # s post-onset — the clean early transient; beyond ~0.4 s the trial
                       # mean is neighbour-stim-contaminated (ITI ~0.71 s) and pure noise,
                       # which swamps the scaling/correlation test if included.


def _corr(A, B):
    """Waveform correlation along the last axis (NaN-safe)."""
    Am = A - np.nanmean(A, -1, keepdims=True)
    Bm = B - np.nanmean(B, -1, keepdims=True)
    num = np.nansum(Am * Bm, -1)
    den = np.sqrt(np.nansum(Am ** 2, -1) * np.nansum(Bm ** 2, -1))
    return num / np.where(den > 0, den, np.nan)


def metrics(z=None):
    """Compute per-pair scaling metrics from the 2amp cache. Returns dict of (nS,nS) arrays
    plus amps/sites/window. Assumes exactly 2 amps (low, high) sorted ascending."""
    z = z or cr.load_cached2()
    H, amps, window = z["H"], np.asarray(z["amps"], float), z["window"]
    order = np.argsort(amps)
    amps = amps[order]; H = H[order]
    post = (window >= LIN_WIN[0]) & (window <= LIN_WIN[1])
    lo, hi = H[0][:, :, post], H[1][:, :, post]                 # (nS,nS,nW in LIN_WIN)

    num = np.nansum(hi * lo, axis=2)
    den = np.nansum(lo * lo, axis=2)
    k = num / np.where(den > 0, den, np.nan)                    # best scale hi ≈ k·lo
    resid = hi - k[..., None] * lo
    sse = np.nansum(resid ** 2, axis=2)
    sstot = np.nansum((hi - np.nanmean(hi, axis=2, keepdims=True)) ** 2, axis=2)
    r2 = 1.0 - sse / np.where(sstot > 0, sstot, np.nan)
    return dict(k=k, r2=r2, corr=_corr(lo, hi),
                peak_lo=np.nanmax(np.abs(lo), axis=2),
                peak_hi=np.nanmax(np.abs(hi), axis=2),
                amps=amps, sites=z["sites"], window=window, H=H)


def report(save="linearity_summary.png"):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    m = metrics()
    k, r2, corr = m["k"], m["r2"], m["corr"]
    plo, phi = m["peak_lo"], m["peak_hi"]
    amps = m["amps"]; nS = len(m["sites"])
    diag = np.eye(nS, dtype=bool)
    # SNR gate: only judge pairs where BOTH amps give a response clearly above the noise floor
    thr = np.nanpercentile(phi, 60)
    strong = (phi > thr) & (plo > np.nanpercentile(plo, 60))
    ks, cs, rs = k[strong], corr[strong], r2[strong]

    print(f"amps {[float(a) for a in amps]}  window {LIN_WIN}s ; {strong.sum()} strong pairs judged")
    print(f"  self-stim: peak {np.nanmedian(plo[diag])*100:.2f}% ({amps[0]}) vs "
          f"{np.nanmedian(phi[diag])*100:.2f}% ({amps[1]}); shape corr {np.nanmedian(corr[diag]):.2f}; "
          f"gain k(hi/lo) {np.nanmedian(k[diag]):.2f}")
    print(f"  strong pairs: gain k median {np.nanmedian(ks):.2f} IQR "
          f"[{np.nanpercentile(ks,25):.2f},{np.nanpercentile(ks,75):.2f}]; "
          f"shape corr median {np.nanmedian(cs):.2f} (>0.7 in {100*np.nanmean(cs>0.7):.0f}%); "
          f"scaling r2 median {np.nanmedian(rs):.2f}")
    verdict = ("LINEAR: high ~ k*low, same shape" if np.nanmedian(cs) > 0.7 and np.nanmedian(ks) > 1.3
               else "NO CLEAN SCALING: high amp is not a consistent scale of low amp "
                    "(weak/low-SNR responses; 0.5 not clearly > 0.25)")
    print("  VERDICT:", verdict)

    fig, ax = plt.subplots(1, 3, figsize=(14, 4.2))
    ax[0].scatter(plo[strong] * 100, phi[strong] * 100, s=10, alpha=0.6, c="k")
    kk = np.nanmedian(ks)
    xl = np.array([0, np.nanmax(plo[strong]) * 100])
    ax[0].plot(xl, kk * xl, "r--", lw=1.2, label=f"slope=median k={kk:.1f}")
    ax[0].set_xlabel(f"peak |dF/F| @ {amps[0]} (%)"); ax[0].set_ylabel(f"peak |dF/F| @ {amps[1]} (%)")
    ax[0].set_title("response strength: high vs low amp"); ax[0].legend(fontsize=8)

    ax[1].hist(cs[~np.isnan(cs)], bins=np.linspace(-1, 1, 41), color="steelblue")
    ax[1].axvline(np.nanmedian(cs), c="r", ls="--", lw=1)
    ax[1].set_xlabel("waveform corr(low, high)"); ax[1].set_ylabel("# strong pairs")
    ax[1].set_title("shape match across amps\n(1 = linear: same dynamics)")

    ax[2].hist(ks[np.isfinite(ks)], bins=30, color="darkorange")
    ax[2].axvline(np.nanmedian(ks), c="r", ls="--", lw=1)
    ax[2].set_xlabel("gain ratio k = high/low"); ax[2].set_ylabel("# strong pairs")
    ax[2].set_title(f"amplitude gain\n(command ratio {amps[1]/amps[0]:.0f}×; not mW)")
    fig.suptitle(f"Grid linearity — {m['sites'].shape[0]} sites, amps "
                 f"{[float(a) for a in amps]} (nominal command levels)")
    fig.tight_layout()
    OUT.mkdir(exist_ok=True)
    out = OUT / save
    fig.savefig(out, dpi=140)
    print("wrote", out)


def prototype(save="linearity_pairs.png"):
    """Overlay low-amp, high-amp, and k·low for representative pairs to eyeball scaling."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    m = metrics()
    H, amps, window, sites = m["H"], m["amps"], m["window"], m["sites"]
    k, phi = m["k"], m["peak_hi"]
    nS = len(sites)

    # pick strong, well-defined pairs: a few diagonals + a few strong off-diagonals
    diag = [(i, i) for i in np.argsort(-np.diag(phi))[:3]]
    off = phi.copy(); off[np.eye(nS, dtype=bool)] = -1
    ij = [np.unravel_index(a, off.shape) for a in np.argsort(-off, axis=None)[:3]]
    pairs = diag + [tuple(map(int, p)) for p in ij]

    fig, axes = plt.subplots(2, 3, figsize=(14, 7))
    for ax, (s, r) in zip(axes.ravel(), pairs):
        ax.axhline(0, c="0.7", lw=.4, ls=":"); ax.axvline(0, c="red", lw=.7)
        ax.plot(window, H[0, s, r], c="dodgerblue", lw=1.3, label=f"low ({amps[0]})")
        ax.plot(window, H[1, s, r], c="crimson", lw=1.3, label=f"high ({amps[1]})")
        ax.plot(window, k[s, r] * H[0, s, r], c="k", lw=1.0, ls="--",
                label=f"k·low (k={k[s,r]:.1f})")
        ax.set_title(f"stim {tuple(sites[s])} -> read {tuple(sites[r])}\n"
                     f"corr={m['corr'][s,r]:.2f}  r2={m['r2'][s,r]:.2f}", fontsize=9)
        ax.set_xlim(-0.4, 0.8); ax.legend(fontsize=7); ax.set_xlabel("t (s)")
    fig.suptitle("Linearity check — if the black dashed (scaled low) matches red (high), the "
                 "pair is linear over this range")
    fig.tight_layout()
    OUT.mkdir(exist_ok=True)
    out = OUT / save
    fig.savefig(out, dpi=140)
    print("wrote", out)


if __name__ == "__main__":
    import sys
    if "pairs" in sys.argv:
        prototype()
    else:
        report()
