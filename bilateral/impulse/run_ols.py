#!/usr/bin/env python
"""run_ols.py — contra->ipsi stim-blind OLS decomposition on AL_0048 dual-opsin impulse.

Runs the ported impulse-analysis stim-blind predictor (impulse_ols) on both photostim sites of
the AL_0048 2026-07-10 impulse block: the LEFT/excitatory and RIGHT/inhibitory spots each get
their own contra (opposite-hemisphere) predictor, so the Local residual isolates the evoked
deflection per side — a within-animal opposite-sign control.

    .venv/Scripts/python.exe bilateral/impulse/run_ols.py

Outputs -> bilateral/impulse/ols_png/. See impulse/README.md for the handoff.
"""
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import impulse_config as cfg
import impulse_core as core
import impulse_ols as ols
import analysis   # from bilateral/grid
import loader     # from bilateral/grid

OUTDIR = Path(__file__).resolve().parent / "ols_png"
SIDE_TITLE = {"left": "left / excitatory", "right": "right / inhibitory"}
SIDE_SIGN = {"left": +1, "right": -1}

# The contra->ipsi OLS needs MANY MORE SVD components than the dose-response readout: with only
# ~50 comps the ~400-node contra grid spans the whole SVD temporal space and reconstructs any
# pixel EXACTLY (trivial R^2=1). 500 comps (matching the MATLAB nSV_load) makes the grid a proper
# subspace so the spontaneous fit is a genuine prediction (R^2 < 1). Focal localization still uses
# the 50-comp path; only the OLS engine reads this deeper V.
OLS_N_COMPS = 500


def main():
    OUTDIR.mkdir(exist_ok=True)
    S = core.load_session(cfg)
    U, mimg, svdT, V = S["U"], S["mimg"], S["svdT"], S["V"]
    onset_t, amp, side = S["onset_t"], S["amp"], S["side"]

    # native SVD frame rate — this port works on native frames (not the 70 Hz t2svd interp)
    ols._FS_REF = float(1.0 / np.median(np.diff(svdT)))
    ols.ROI_RAD_REF = cfg.ROI_RAD
    ols.PX_PER_MM_X_REF = cfg.PX_PER_MM_X
    print(f"  native SVD frame rate = {ols._FS_REF:.2f} Hz")

    t2svd = analysis.make_t2svd(svdT, V)
    print("  loading U[:, :, :%d] for focal localization ..." % cfg.N_COMPS)
    U50 = np.asarray(U[:, :, :cfg.N_COMPS])

    # reload the temporal SVD at full depth for the OLS (see OLS_N_COMPS note above)
    print(f"  reloading V[:, :{OLS_N_COMPS}] for the contra->ipsi OLS ...")
    _, _, S["V"], _, _, _ = loader.load_svd(cfg.EXPDIR, OLS_N_COMPS)

    ocfg = ols.OLSConfig()
    results = {}
    for sd, nominal in [("left", cfg.SITE_LEFT), ("right", cfg.SITE_RIGHT)]:
        sign = SIDE_SIGN[sd]
        sel = (side == sd) & (amp == cfg.FOCUS_AMP)
        px, py, _ = core.find_focal_pixel(U50, mimg, t2svd, onset_t[sel], nominal, sign, cfg)
        print(f"  {SIDE_TITLE[sd]}: focal pixel = ({px}, {py})")

        gr, gc = ols.build_contra_grid(mimg, cfg.BREGMA_PX, (px, py), ocfg)
        S["_grid"] = (gr, gc)
        S["_side_name"] = sd
        results[sd] = ols.stimblind_side(S, (px, py), sign, ocfg)

    print_dose(results)
    plot_decomposition(results, mimg)
    plot_dose(results)
    plot_weight_maps(results, mimg, cfg)
    print("\nwrote:", OUTDIR)


def _signed_peak(trace, cols, sign):
    """Signed peak of a trace within `cols` (max for excit sign +1, min for inhib -1)."""
    if trace is None:
        return np.nan
    return float(sign * np.nanmax(sign * np.asarray(trace)[cols]))


def peak_dose(R):
    """Signed-peak dose (Actual/Global/Local) per amp — the correct readout for the fast
    excitatory transient (the 0-300 ms MEAN cancels + spike against - undershoot)."""
    sign, cols = R["sign"], R["dip_cols"]
    return (np.array([_signed_peak(R["trA"][ai], cols, sign) for ai in range(len(R["amps"]))]),
            np.array([_signed_peak(R["trG"][ai], cols, sign) for ai in range(len(R["amps"]))]),
            np.array([_signed_peak(R["trL"][ai], cols, sign) for ai in range(len(R["amps"]))]))


def print_dose(results):
    print("\n  Actual / Global / Local  [signed PEAK in dip window | dip-window MEAN], %dF/F, + R^2:")
    for sd, R in results.items():
        pA, pG, pL = peak_dose(R)
        print(f"  {SIDE_TITLE[sd]}:  spont R2(full)={R['r2_ols']:.3f}  medLocal%={R['med_local_pct']:.0f}"
              f"  couple_win={R['couple_win_s']*1000:.0f}ms")
        for ai, a in enumerate(R["amps"]):
            print(f"    amp {a}:  peak A {pA[ai]:+.3f} G {pG[ai]:+.3f} L {pL[ai]:+.3f}  |  "
                  f"mean A {R['Actual'][ai]:+.3f} L {R['Local'][ai]:+.3f}  |  "
                  f"R2={R['r2_clean'][ai]:.3f} drop {R['n_drop'][ai]}/{R['n_g']} n={R['nT_amp'][ai]}")


def plot_decomposition(results, mimg):
    """Per-amp Actual / stim-blind-pred (Global) / residual (Local) traces, one row per side."""
    n_a = max(len(R["amps"]) for R in results.values())
    fig, axes = plt.subplots(2, n_a, figsize=(2.4 * n_a, 5.2), sharex=True, squeeze=False)
    for si, (sd, R) in enumerate(results.items()):
        rel, fs, pre_n = R["rel"], R["fs"], R["pre_n"]
        tt = rel / fs
        dc = R["dip_cols"]
        for ai, a in enumerate(R["amps"]):
            ax = axes[si][ai]
            if R["trA"][ai] is None:
                ax.axis("off"); continue
            ax.axvspan(tt[dc[0]], tt[dc[-1]], color=(1, 0.9, 0.6), alpha=0.5, lw=0)
            ax.plot(tt, R["trA"][ai], "k-", lw=1.8, label="Actual")
            ax.plot(tt, R["trG"][ai], "-", color=(0.85, 0.2, 0.2), lw=1.4, label="Global (stim-blind pred)")
            ax.plot(tt, R["trL"][ai], "-", color=(0.15, 0.4, 0.85), lw=1.6, label="Local (residual)")
            ax.axhline(0, color="k", ls=":", lw=0.6); ax.axvline(0, color="k", ls=":", lw=0.6)
            ax.set_title(f"{a} V  (n={R['nT_amp'][ai]})", fontsize=9, fontweight="bold")
            ax.spines[["top", "right"]].set_visible(False)
            if ai == 0:
                ax.set_ylabel(f"{SIDE_TITLE[sd]}\nΔF/F (%)", fontsize=9, fontweight="bold")
            if si == 1:
                ax.set_xlabel("t re onset (s)", fontsize=8)
        for ai in range(len(R["amps"]), n_a):
            axes[si][ai].axis("off")
    axes[0][0].legend(fontsize=6, loc="best", frameon=False)
    fig.suptitle("Stim-blind contra→ipsi decomposition  (AL_0048 2026-07-10)",
                 fontsize=11, fontweight="bold")
    fig.tight_layout()
    fig.savefig(OUTDIR / "ols_decomposition.png", dpi=200)
    plt.close(fig)


def plot_dose(results):
    """Dose-response of Actual / Global / Local per side, using the signed PEAK (correct for the
    fast excitatory transient; robust for the inhibitory trough)."""
    fig, axes = plt.subplots(1, 2, figsize=(8, 3.4), squeeze=False)
    for si, (sd, R) in enumerate(results.items()):
        ax = axes[0][si]
        a = R["amps"]
        pA, pG, pL = peak_dose(R)
        ax.plot(a, pA, "k-o", lw=1.6, ms=4, label="Actual")
        ax.plot(a, pG, "-o", color=(0.85, 0.2, 0.2), lw=1.4, ms=4, label="Global (stim-blind)")
        ax.plot(a, pL, "-o", color=(0.15, 0.4, 0.85), lw=1.6, ms=4, label="Local (residual)")
        ax.axhline(0, color="k", ls=":", lw=0.6)
        ax.set_title(SIDE_TITLE[sd], fontsize=10, fontweight="bold")
        ax.set_xlabel("amplitude (V)", fontsize=9)
        ax.set_ylabel("signed peak ΔF/F (%)", fontsize=9)
        ax.spines[["top", "right"]].set_visible(False)
        if si == 0:
            ax.legend(fontsize=8, frameon=False)
    fig.suptitle("Local (residual) recovers the dose-graded stim effect; Global stays stim-blind",
                 fontsize=11, fontweight="bold")
    fig.tight_layout()
    fig.savefig(OUTDIR / "ols_dose_response.png", dpi=200)
    plt.close(fig)


def plot_weight_maps(results, mimg, cfg):
    """Brain + contra grid nodes colored by the stim-blind weight (strongest amp), site marked."""
    fig, axes = plt.subplots(1, 2, figsize=(9, 4.6), squeeze=False)
    g = (mimg - np.percentile(mimg, 1)) / (np.percentile(mimg, 99) - np.percentile(mimg, 1))
    g = np.clip(g, 0, 1)
    for si, (sd, R) in enumerate(results.items()):
        ax = axes[0][si]
        ax.imshow(g, cmap="gray", vmin=0, vmax=1)
        gr, gc = R["grid_rc"]
        b = R["b_clean"][-1]
        if b is None:
            b = next((x for x in reversed(R["b_clean"]) if x is not None), np.zeros(gr.size))
        vmax = np.percentile(np.abs(b), 98) or 1.0
        sc = ax.scatter(gc, gr, c=b, s=14, cmap="RdBu_r", vmin=-vmax, vmax=vmax,
                        edgecolors="k", linewidths=0.15)
        ax.plot(R["focal_px"][0], R["focal_px"][1], "g+", ms=14, mew=2)
        ax.plot(cfg.BREGMA_PX[0], cfg.BREGMA_PX[1], "cx", ms=8, mew=1.5)
        ax.set_title(f"{SIDE_TITLE[sd]}  (contra grid, n={gr.size})", fontsize=10, fontweight="bold")
        ax.axis("off")
        fig.colorbar(sc, ax=ax, fraction=0.046, pad=0.04, label="stim-blind weight")
    fig.suptitle("Contra predictor weights (stim-blind, strongest amp) + focal site (green)",
                 fontsize=11, fontweight="bold")
    fig.tight_layout()
    fig.savefig(OUTDIR / "ols_weight_maps.png", dpi=200)
    plt.close(fig)


if __name__ == "__main__":
    main()
