"""tf_matrix.py — render the 52x52 site->site TF matrix (per amplitude) and the cross-amp
comparison for the 2026-07-10 two-power grid session.

Consumes grid_tf_fits_2amp.npz (tf_fit.fit_all_amps): for every stim site s and readout site
r we have a CV-selected low-order LTI transfer function, at each laser amplitude. Three figures:

  grid_tf_gain_matrix.png   signed peak-gain matrix per amp, sites ordered by hemisphere (Fig A)
  grid_tf_amp_compare.png   gain(amp1) vs gain(amp2) linearity + dominant-tau stability + R2 (Fig B)
  grid_tf_exemplars.png     a few strong pairs: empirical + fit overlaid at both amps (Fig C)

Fig B is the LTI check: if these are impulse responses of one linear network, the fitted poles
(time constants) should be amplitude-INVARIANT and the gain should scale with laser power.

Run (from bilateral/grid, after `python tf_fit.py 2amp`):
    ../../.venv/Scripts/python.exe tf_matrix.py
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

import tf_fit

OUT = Path(__file__).resolve().parent / "grid_png"


def _load():
    z = np.load(tf_fit.CACHE_TF2, allow_pickle=True)
    return {k: z[k] for k in z.files}


def _hemi_order(sites):
    """Site ordering by hemisphere then position: left (x<0, excitatory) first, ascending
    (x, y). Returns the permutation and the index where the right hemisphere starts."""
    order = np.lexsort((sites[:, 1], sites[:, 0]))
    split = int(np.searchsorted(sites[order, 0], 0.0))     # first x>=0 in the sorted order
    return order, split


def _dominant_tau(tau_vec, A_vec):
    """Time constant carrying the largest-magnitude residue (the pole that dominates the
    response shape). tau/A are aligned; NaN-padded to max order."""
    m = np.isfinite(tau_vec) & np.isfinite(A_vec)
    if not m.any():
        return np.nan
    tv, av = tau_vec[m], A_vec[m]
    return float(tv[np.argmax(np.abs(av))])


def gain_matrix(z, save="grid_tf_gain_matrix.png"):
    """Signed peak-gain matrix (rows = stim site, cols = readout site), one panel per amp."""
    sites, amps, gain, r2 = z["sites"], z["amps"], z["gain"], z["r2"]
    order, split = _hemi_order(sites)
    nA = len(amps)
    clim = np.nanpercentile(np.abs(gain), 98)

    fig, axes = plt.subplots(1, nA, figsize=(6.2 * nA, 5.6), constrained_layout=True)
    axes = np.atleast_1d(axes)
    for ai, ax in enumerate(axes):
        G = gain[ai][np.ix_(order, order)]
        im = ax.imshow(G, cmap="RdBu_r", vmin=-clim, vmax=clim, interpolation="nearest")
        for k in (split,):                                  # hemisphere separators
            ax.axhline(k - 0.5, c="k", lw=0.8); ax.axvline(k - 0.5, c="k", lw=0.8)
        ax.set_title(f"amp {amps[ai]:.1f}  (peak-gain, dF/F)\nmedian fit R2={np.nanmedian(r2[ai]):.2f}",
                     fontsize=10)
        ax.set_xlabel("readout site  (L | R)"); ax.set_ylabel("stim site  (L | R)")
        fig.colorbar(im, ax=ax, fraction=0.046, shrink=0.85, label="signed peak dF/F")
    fig.suptitle("Site->site TF peak-gain matrix — AL_0048 2026-07-10 grid "
                 "(left=excitatory, right=inhibitory)", fontsize=11)
    out = OUT / Path(save).name; OUT.mkdir(exist_ok=True)
    fig.savefig(out, dpi=150); plt.close(fig)
    print("wrote", out)
    return order, split


def amp_compare(z, cvr2_min=0.2, r2_strong=0.4, save="grid_tf_amp_compare.png"):
    """Cross-amp linearity + pole-stability + R2 distributions. Uses only pairs well fit at
    BOTH amps for the tau-stability panel; the linearity slope is reported both over ALL pairs
    (noise-attenuated) and over the well-fit subset (min in-sample R2 >= r2_strong), which is
    the honest scaling estimate — the sea of near-zero off-diagonal noise pairs otherwise pulls
    the through-origin slope toward zero (regression dilution)."""
    amps, gain, r2, cvr2, tau, A = z["amps"], z["gain"], z["r2"], z["cvr2"], z["tau"], z["A"]
    assert len(amps) == 2, "amp_compare expects exactly two amplitudes"
    a0, a1 = float(amps[0]), float(amps[1])
    g0, g1 = gain[0].ravel(), gain[1].ravel()
    finite = np.isfinite(g0) & np.isfinite(g1)

    # linearity: through-origin slope of gain(a1) on gain(a0)
    gg0, gg1 = g0[finite], g1[finite]
    slope = float(np.sum(gg0 * gg1) / np.sum(gg0 * gg0))          # all pairs (noise-attenuated)
    # HONEST scaling: the on-site (diagonal) focal responses, where signal >> measurement noise.
    # The all-pairs peak-gain regression is dominated by weak, sign-flipping off-diagonal pairs
    # (regression dilution), so it is reported only as a faint reference. Focal = physical dose.
    nS = tau.shape[1]
    di = np.arange(nS)
    dg0, dg1 = gain[0][di, di], gain[1][di, di]
    dwell = (r2[0][di, di] >= r2_strong) & (r2[1][di, di] >= r2_strong) \
        & np.isfinite(dg0) & np.isfinite(dg1)
    sg0, sg1 = dg0[dwell], dg1[dwell]
    slope_s = float(np.sum(sg0 * sg1) / np.sum(sg0 * sg0)) if dwell.sum() > 3 else np.nan
    r_lin_s = float(np.corrcoef(sg0, sg1)[0, 1]) if dwell.sum() > 3 else np.nan
    ratio_s = float(np.median(np.abs(sg1) / np.abs(sg0))) if dwell.sum() > 3 else np.nan

    # dominant tau per pair per amp, keep pairs well fit at both amps
    nS = tau.shape[1]
    td = np.full((2, nS * nS), np.nan)
    for ai in range(2):
        tt = tau[ai].reshape(nS * nS, -1); AA = A[ai].reshape(nS * nS, -1)
        td[ai] = [_dominant_tau(tt[k], AA[k]) for k in range(nS * nS)]
    well = (cvr2[0].ravel() >= cvr2_min) & (cvr2[1].ravel() >= cvr2_min) \
        & np.isfinite(td[0]) & np.isfinite(td[1])

    fig, ax = plt.subplots(1, 3, figsize=(15, 4.6), constrained_layout=True)

    # (1) gain linearity — all pairs faint, well-fit pairs highlighted
    lim = np.nanpercentile(np.abs(np.r_[gg0, gg1]), 99)
    ax[0].scatter(gg0, gg1, s=6, alpha=0.22, c="silver", edgecolors="none", label="all pairs")
    ax[0].scatter(sg0, sg1, s=30, alpha=0.85, c="crimson", edgecolors="k", linewidths=0.3,
                  label=f"on-site focal (R2>={r2_strong:g})")
    xs = np.array([-lim, lim])
    ax[0].plot(xs, slope_s * xs, "r-", lw=1.6, label=f"focal slope={slope_s:.2f}")
    ax[0].plot(xs, slope * xs, ":", c="grey", lw=1.0, label=f"all-pairs slope={slope:.2f} (diluted)")
    ax[0].plot(xs, (a1 / a0) * xs, "k--", lw=1.0, label=f"power ratio={a1/a0:.2f} (linear)")
    ax[0].axhline(0, c="grey", lw=0.4); ax[0].axvline(0, c="grey", lw=0.4)
    ax[0].set(xlim=(-lim, lim), ylim=(-lim, lim),
              xlabel=f"peak gain @ amp {a0:.1f}", ylabel=f"peak gain @ amp {a1:.1f}",
              title=f"gain linearity  (focal slope={slope_s:.2f}, r={r_lin_s:.2f}, n={dwell.sum()})")
    ax[0].legend(fontsize=7, loc="upper left")

    # (2) dominant-tau stability (LTI: on identity)
    if well.sum() > 3:
        t0, t1 = td[0][well] * 1e3, td[1][well] * 1e3
        tmax = np.nanpercentile(np.r_[t0, t1], 98)
        ax[1].scatter(t0, t1, s=10, alpha=0.5, c="darkorange", edgecolors="none")
        ax[1].plot([0, tmax], [0, tmax], "k--", lw=1.0, label="identity (LTI)")
        med_ratio = float(np.nanmedian(t1 / t0))
        ax[1].set(xlim=(0, tmax), ylim=(0, tmax),
                  xlabel=f"dominant tau (ms) @ amp {a0:.1f}",
                  ylabel=f"dominant tau (ms) @ amp {a1:.1f}",
                  title=f"pole stability  (median tau ratio={med_ratio:.2f}, n={well.sum()})")
        ax[1].legend(fontsize=8)
    else:
        ax[1].text(0.5, 0.5, f"too few well-fit pairs\n(CV-R2>={cvr2_min})", ha="center")

    # (3) fit-quality distributions
    for ai, c in zip(range(2), ("steelblue", "indianred")):
        vals = r2[ai].ravel(); vals = vals[np.isfinite(vals)]
        ax[2].hist(vals, bins=np.linspace(-0.2, 1, 40), alpha=0.55, color=c,
                   label=f"amp {float(amps[ai]):.1f}  (med {np.nanmedian(vals):.2f})")
    ax[2].set(xlabel="per-pair fit R2", ylabel="# pairs", title="fit quality by amp")
    ax[2].legend(fontsize=8)

    fig.suptitle("Site->site TF across laser power — LTI / linearity check "
                 "(2026-07-10 grid)", fontsize=11)
    out = OUT / Path(save).name; OUT.mkdir(exist_ok=True)
    fig.savefig(out, dpi=150); plt.close(fig)
    print("wrote", out)
    print(f"  gain linearity ALL pairs: slope={slope:.3f}, n={finite.sum()} (noise-attenuated, ignore)")
    print(f"  gain linearity ON-SITE FOCAL (R2>={r2_strong:g}): slope={slope_s:.3f}, r={r_lin_s:.3f}, "
          f"median ratio={ratio_s:.2f}, n={dwell.sum()} (linear would be {a1/a0:.2f})")
    if well.sum() > 3:
        print(f"  dominant-tau median ratio a{a1}/a{a0} = "
              f"{np.nanmedian(td[1][well] / td[0][well]):.3f} over {well.sum()} well-fit pairs")


def exemplars(z, save="grid_tf_exemplars.png"):
    """Overlay empirical H + LTI fit at both amps for a few strong, correctly-signed pairs:
    the strongest excitatory self-response, the strongest inhibitory self-response, and each
    one's strongest cross-readout pair."""
    sites, amps, H, yhat = z["sites"], z["amps"], z["H"], z["yhat"]
    window, gain = z["window"], z["gain"]
    nS = len(sites)
    lateral = np.abs(sites[:, 0]) >= 1.5
    gi = gain[-1]                                            # rank by the high-amp gain
    exc = np.where((sites[:, 0] < 0) & lateral)[0]
    inh = np.where((sites[:, 0] > 0) & lateral)[0]
    s_exc = exc[np.argmax([gi[i, i] for i in exc])]
    s_inh = inh[np.argmin([gi[i, i] for i in inh])]

    def strongest_cross(s):
        row = gi[s].copy(); row[s] = 0
        return int(np.argmax(np.abs(row)))

    cases = [(s_exc, s_exc, "excitatory self"), (s_exc, strongest_cross(s_exc), "excit -> strongest"),
             (s_inh, s_inh, "inhibitory self"), (s_inh, strongest_cross(s_inh), "inhib -> strongest")]

    fig, axes = plt.subplots(1, 4, figsize=(16, 3.8), constrained_layout=True)
    cols = ["#1f77b4", "#d62728"]
    for ax, (s, r, lab) in zip(axes, cases):
        for ai, c in zip(range(len(amps)), cols):
            ax.plot(window, H[ai, s, r], c=c, lw=1.3, alpha=0.9,
                    label=f"amp {float(amps[ai]):.1f} data")
            ax.plot(window, yhat[ai, s, r], c=c, lw=1.2, ls="--", alpha=0.9)
        ax.axhline(0, c="k", lw=0.4, ls=":"); ax.axvline(0, c="grey", lw=0.4)
        ax.set_xlim(-0.15, 0.6)
        ax.set_title(f"{lab}\nstim({sites[s,0]:+.1f},{sites[s,1]:+.0f}) -> "
                     f"({sites[r,0]:+.1f},{sites[r,1]:+.0f})", fontsize=9)
        ax.set_xlabel("t (s)")
        ax.legend(fontsize=7)
    axes[0].set_ylabel("dF/F")
    fig.suptitle("Site->site impulse responses + LTI fits (dashed) at both amps", fontsize=11)
    out = OUT / Path(save).name; OUT.mkdir(exist_ok=True)
    fig.savefig(out, dpi=150); plt.close(fig)
    print("wrote", out)


if __name__ == "__main__":
    z = _load()
    print(f"loaded 2-amp TF fits: amps={list(z['amps'])}, sites={len(z['sites'])}, "
          f"window {z['window'][0]:.2f}..{z['window'][-1]:.2f}s")
    gain_matrix(z)
    amp_compare(z)
    exemplars(z)
