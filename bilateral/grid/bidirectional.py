"""bidirectional.py — which grid sites can be driven in BOTH directions?

Identifies readout sites that are *adequately affected* both UP (excitatory) and DOWN
(inhibitory) by at least one of the 52 photostim sites — i.e. sites with genuine
bidirectional control authority, the point of the dual-opsin prep.

METHOD (deliberately independent of the TF fits — those are mid-revision, and a
site-selection claim should not inherit a model class that is still in flux):

  1. effect per (stim s -> readout r): per-trial dF/F, each trial baselined to its own
     immediate pre-onset mean (zero initial condition), then a FIXED-WINDOW mean over
     EFFECT_WIN (0-200 ms, the project's peak_mode=3 convention). Fixed window, NOT peak:
     an argmax over ~14 samples biases every effect away from zero.
  2. significance per pair: one-sample t-test of the per-trial effects against 0.
  3. BH-FDR across ALL nS*nS pairs BEFORE any max is taken. This is the crux — asking
     "is there ANY of 52 stim sites that drives r up?" is a selection over 52 noisy
     candidates and will manufacture winners from noise without correction.
  4. two criteria: FDR-significant AND |effect| >= MIN_EFFECT (statistically real AND
     practically useful — a 0.05% effect can be significant at n=50 and useless for control).
  5. site r is BIDIRECTIONAL if it has >=1 qualifying positive driver AND >=1 qualifying
     negative driver. Dynamic range = best_pos - best_neg = the control authority at r.

CAVEAT carried from the spatial maps: excitatory stim produces broad, near-cortex-wide
positive fields while inhibition is focal, so positive drivers will be plentiful and
negative drivers limiting. The broad positive field is also exactly where the
single-wavelength hemodynamic confound lives — treat "many + drivers" with more
suspicion than "few - drivers".

Run (from bilateral/grid):
    ../../.venv/Scripts/python.exe bidirectional.py
    ../../.venv/Scripts/python.exe bidirectional.py --min-effect 0.01 --q 0.01
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.interpolate
import scipy.stats

import cross_response

OUT = Path(__file__).resolve().parent / "grid_png"

EFFECT_WIN = (0.0, 0.20)   # s post-onset — project convention (mean dF/F, not peak)
ONSET_PRE = 0.10           # s — per-trial pre-onset baseline (zero initial condition)
FDR_Q = 0.05               # BH false-discovery rate across all pairs
MIN_EFFECT = 0.005         # |dF/F| floor for "adequately" affected (0.5%)


def bh_fdr(p, q):
    """Benjamini-Hochberg: boolean mask of significant p-values at FDR level q."""
    p = np.asarray(p, float)
    ok = np.isfinite(p)
    sig = np.zeros(p.shape, bool)
    pv = p[ok]
    if pv.size == 0:
        return sig
    order = np.argsort(pv)
    ranked = pv[order]
    below = ranked <= q * np.arange(1, pv.size + 1) / pv.size
    if not below.any():
        return sig
    kmax = int(np.max(np.where(below)[0]))
    keep = np.zeros(pv.size, bool)
    keep[order[:kmax + 1]] = True
    sig[ok] = keep            # boolean-mask assignment matches the p[ok] extraction order
    return sig


def pair_effects():
    """Per-pair trial-level effect: returns eff (nS,nS) mean dF/F over EFFECT_WIN,
    tstat, pval, and n trials. eff[s, r] = effect at readout r when stimming s."""
    zt = cross_response.load_trials()
    roi_ts = zt["roi_ts"].astype(np.float64)
    svdT, onset_t, pos = zt["svdT"], zt["onset_t"], zt["pos"]
    sites, window, base_ix = zt["sites"], zt["window"], int(zt["base_ix"])
    nS = len(sites)

    w_eff = (window >= EFFECT_WIN[0]) & (window <= EFFECT_WIN[1])
    w_pre = (window >= -ONSET_PRE) & (window < 0)
    print(f"effect window {EFFECT_WIN[0]:.2f}-{EFFECT_WIN[1]:.2f}s ({w_eff.sum()} samples), "
          f"onset baseline {ONSET_PRE:.2f}s ({w_pre.sum()} samples)")

    eff = np.full((nS, nS), np.nan)
    tst = np.full((nS, nS), np.nan)
    pv = np.full((nS, nS), np.nan)
    ntr = np.zeros((nS, nS), int)

    # one interpolator per readout; reuse across all stim sites
    for r in range(nS):
        f = scipy.interpolate.interp1d(svdT, roi_ts[:, r], bounds_error=False,
                                       fill_value=np.nan)
        for s, (mx, my) in enumerate(sites):
            onsets = onset_t[(pos[:, 0] == mx) & (pos[:, 1] == my)]
            if onsets.size < 3:
                continue
            fluo = f(window[None, :] + onsets[:, None])          # (nTrials, nW)
            base = np.nanmean(fluo[:, :base_ix])                 # same convention as build()
            if not np.isfinite(base) or base == 0:
                continue
            dff = (fluo - base) / base
            dff = dff - np.nanmean(dff[:, w_pre], 1, keepdims=True)   # per-trial onset zero
            e = np.nanmean(dff[:, w_eff], 1)                     # per-trial effect
            e = e[np.isfinite(e)]
            if e.size < 3:
                continue
            eff[s, r] = e.mean(); ntr[s, r] = e.size
            t, p = scipy.stats.ttest_1samp(e, 0.0)
            tst[s, r] = t; pv[s, r] = p
        print(f"  readout {r+1:2d}/{nS}", end="\r")
    print()
    return eff, tst, pv, ntr, sites


def classify(eff, pv, sites, q=FDR_Q, min_eff=MIN_EFFECT):
    """Per readout: best qualifying positive / negative driver; bidirectional flag."""
    sig = bh_fdr(pv, q)
    qual = sig & (np.abs(eff) >= min_eff) & np.isfinite(eff)
    nS = eff.shape[0]
    print(f"pairs: {np.isfinite(pv).sum()} tested, {sig.sum()} FDR-sig (q={q}), "
          f"{qual.sum()} also |eff|>={min_eff*100:.1f}%")

    best_pos = np.full(nS, np.nan); arg_pos = np.full(nS, -1, int)
    best_neg = np.full(nS, np.nan); arg_neg = np.full(nS, -1, int)
    for r in range(nS):
        col = eff[:, r]
        mp = qual[:, r] & (col > 0)
        mn = qual[:, r] & (col < 0)
        if mp.any():
            i = int(np.nanargmax(np.where(mp, col, -np.inf)))
            best_pos[r], arg_pos[r] = col[i], i
        if mn.any():
            i = int(np.nanargmin(np.where(mn, col, np.inf)))
            best_neg[r], arg_neg[r] = col[i], i
    bidir = np.isfinite(best_pos) & np.isfinite(best_neg)
    rng = np.where(bidir, best_pos - best_neg, np.nan)
    return dict(sig=sig, qual=qual, best_pos=best_pos, best_neg=best_neg,
                arg_pos=arg_pos, arg_neg=arg_neg, bidir=bidir, rng=rng)


def report(res, sites, eff):
    b, rng = res["bidir"], res["rng"]
    nS = len(sites)
    print(f"\nBIDIRECTIONAL readouts: {b.sum()}/{nS}")
    print(f"{'readout':>14}{'best+':>9}{'from':>12}{'best-':>9}{'from':>12}{'range':>9}")
    for r in np.argsort(-np.where(np.isfinite(rng), rng, -np.inf)):
        if not b[r]:
            continue
        ip, ineg = res["arg_pos"][r], res["arg_neg"][r]
        print(f"({sites[r,0]:+.1f},{sites[r,1]:+.0f})".rjust(14)
              + f"{res['best_pos'][r]*100:>8.2f}%"
              + f"({sites[ip,0]:+.1f},{sites[ip,1]:+.0f})".rjust(12)
              + f"{res['best_neg'][r]*100:>8.2f}%"
              + f"({sites[ineg,0]:+.1f},{sites[ineg,1]:+.0f})".rjust(12)
              + f"{rng[r]*100:>8.2f}%")
    only_p = np.isfinite(res["best_pos"]) & ~np.isfinite(res["best_neg"])
    only_n = ~np.isfinite(res["best_pos"]) & np.isfinite(res["best_neg"])
    print(f"\nup-only: {only_p.sum()}   down-only: {only_n.sum()}   "
          f"neither: {int((~b & ~only_p & ~only_n).sum())}")


def plot(res, sites, save="grid_bidirectional.png"):
    x, y = sites[:, 0], sites[:, 1]
    b, rng = res["bidir"], res["rng"]
    fig, ax = plt.subplots(1, 3, figsize=(15.5, 5), constrained_layout=True)

    # (1) who is bidirectional, sized/coloured by dynamic range
    sc = ax[0].scatter(x[b], y[b], c=rng[b] * 100, s=230, cmap="viridis",
                       ec="k", lw=0.6, zorder=3)
    ax[0].scatter(x[~b], y[~b], facecolors="none", ec="0.6", s=150, lw=1.0, zorder=2)
    cb = fig.colorbar(sc, ax=ax[0], shrink=0.8); cb.set_label("dynamic range (% dF/F)")
    ax[0].set_title(f"bidirectional sites: {b.sum()}/{len(sites)}\n(open = not bidirectional)",
                    fontsize=10)

    # (2) best positive driver strength
    p = res["best_pos"] * 100
    s2 = ax[1].scatter(x, y, c=np.where(np.isfinite(p), p, np.nan), s=200, cmap="Reds",
                       ec="k", lw=0.5, vmin=0)
    fig.colorbar(s2, ax=ax[1], shrink=0.8).set_label("best UP drive (% dF/F)")
    ax[1].set_title("best excitatory driver per site", fontsize=10)

    # (3) best negative driver strength
    n = res["best_neg"] * 100
    s3 = ax[2].scatter(x, y, c=np.where(np.isfinite(n), n, np.nan), s=200, cmap="Blues_r",
                       ec="k", lw=0.5, vmax=0)
    fig.colorbar(s3, ax=ax[2], shrink=0.8).set_label("best DOWN drive (% dF/F)")
    ax[2].set_title("best inhibitory driver per site", fontsize=10)

    for a in ax:
        a.axvline(0, c="0.6", lw=0.7, ls="--"); a.plot(0, 0, "+", c="lime", ms=9, mew=1.5)
        a.set_aspect("equal"); a.set_xlabel("ML from bregma (mm)")
    ax[0].set_ylabel("AP from bregma (mm)")
    fig.suptitle(f"Bidirectionally drivable grid sites — FDR q={FDR_Q}, "
                 f"|effect|>={MIN_EFFECT*100:.1f}% dF/F, window "
                 f"{EFFECT_WIN[0]*1000:.0f}-{EFFECT_WIN[1]*1000:.0f} ms", fontsize=12)
    OUT.mkdir(exist_ok=True)
    fig.savefig(OUT / Path(save).name, dpi=150); plt.close(fig)
    print("wrote", OUT / Path(save).name)


if __name__ == "__main__":
    if "--min-effect" in sys.argv:
        MIN_EFFECT = float(sys.argv[sys.argv.index("--min-effect") + 1])
    if "--q" in sys.argv:
        FDR_Q = float(sys.argv[sys.argv.index("--q") + 1])
    eff, tst, pv, ntr, sites = pair_effects()
    res = classify(eff, pv, sites, q=FDR_Q, min_eff=MIN_EFFECT)
    report(res, sites, eff)
    plot(res, sites)
    np.savez(cross_response.CACHE.parent / "grid_bidirectional.npz",
             eff=eff, tstat=tst, pval=pv, ntrials=ntr, sites=sites,
             bidir=res["bidir"], best_pos=res["best_pos"], best_neg=res["best_neg"],
             arg_pos=res["arg_pos"], arg_neg=res["arg_neg"], rng=res["rng"])
    print("cached -> grid_bidirectional.npz")
