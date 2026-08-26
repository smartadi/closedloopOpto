"""grid_stim_fields.py — parametric optogenetic "stimulation fields" for the AL_0048 grid.

Optogenetic analog of Barzon/De/Kiani microstimulation-control paper, Fig 5f: quantify how the
evoked response spreads with cortical distance from the stimulated site, and fit a parametric
spatial-field model per opsin class.

  * Excitatory (left hemisphere, x<0): stimulating a site drives a positive dF/F cluster that
    decays with distance -> fit an EXPONENTIAL decay, length constant lambda (mm).
  * Inhibitory (right hemisphere, x>0): stimulating a site suppresses local dF/F but can show a
    surrounding rebound -> fit a DIFFERENCE-OF-GAUSSIANS (center-surround), widths sigma_a<sigma_b.

Input: data/grid_tf_fits_2amp.npz (tf_fit.fit_all_amps) — the same fitted signed peak-gain matrix
`gain[amp, stim, readout]` that tf_matrix.py renders, plus `sites` (ML,AP mm) and `cvr2`.

Field construction (per stim site s):
  distance d_r = ||site_r - site_s||  (mm, cortical grid);
  response g_r = gain[s, r], normalized by |gain[s, s]| so every driver site's self-response is
  +-1 at d=0 and fields are pooled on a common scale (excitation -> +1, inhibition -> -1).
Only reliable DRIVER sites enter a pool: diagonal held-out CV-R2 >= CVR2_MIN and correctly-signed
self-response (excit self>0, inhib self<0). This mirrors the paper restricting to high-efficacy
electrodes; sites with no opsin drive would otherwise inject flat noise into the decay fit.

Run (from bilateral/grid):
    ../../.venv/Scripts/python.exe grid_stim_fields.py
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.optimize

import tf_fit

OUT = Path(__file__).resolve().parent / "grid_png"
CVR2_MIN = 0.2            # held-out CV-R2 gate for a site to count as a genuine driver
BIN_MM = 0.5             # distance bin width (mm) for the pooled field profile


# ----------------------------- field models -----------------------------
def _exp_decay(d, A, lam, c):
    """Excitatory field: A*exp(-d/lam) + c. lam = spatial length constant (mm)."""
    return A * np.exp(-d / lam) + c


def _dog(d, A, B, sa, dsb):
    """Inhibitory field as a difference-of-Gaussians (center suppression - surround rebound).
    Parametrized with sigma_b = sa + dsb (dsb>=0) to enforce surround wider than center."""
    sb = sa + dsb
    return -A * np.exp(-(d ** 2) / (2 * sa ** 2)) + B * np.exp(-(d ** 2) / (2 * sb ** 2))


# ----------------------------- field construction -----------------------------
def _load():
    z = np.load(tf_fit.CACHE_TF2, allow_pickle=True)
    return {k: z[k] for k in z.files}


def _dist_matrix(sites):
    """Euclidean cortical distance (mm) between every pair of grid sites."""
    d = sites[:, None, :] - sites[None, :, :]
    return np.sqrt((d ** 2).sum(-1))


def _driver_mask(gii, cv_ii, sign):
    """Reliable, correctly-signed driver sites for one hemisphere.
    gii/cv_ii are the diagonal self-gain and self CV-R2 vectors; sign = +1 excit, -1 inhib."""
    return np.isfinite(gii) & (cv_ii >= CVR2_MIN) & (np.sign(gii) == sign)


def _pool(gain_ai, cv_ai, D, hemi, sign):
    """Pool normalized (distance, response) points over all driver sites in a hemisphere.
    Returns dd (distances), gg (self-normalized responses), n_drivers used."""
    nS = gain_ai.shape[0]
    gii = np.array([gain_ai[i, i] for i in range(nS)])
    cvii = np.array([cv_ai[i, i] for i in range(nS)])
    drivers = np.where(hemi & _driver_mask(gii, cvii, sign))[0]
    dd, gg = [], []
    for s in drivers:
        self_g = abs(gain_ai[s, s])
        if self_g <= 0:
            continue
        row = gain_ai[s] / self_g            # +-1 at d=0
        ok = np.isfinite(row)
        dd.append(D[s][ok]); gg.append(row[ok])
    if not dd:
        return np.array([]), np.array([]), 0
    return np.concatenate(dd), np.concatenate(gg), len(drivers)


def _binned(dd, gg, bin_mm=BIN_MM, dmax=None):
    """Median +- SEM of gg in distance bins. Returns bin centers, median, sem, count."""
    if dmax is None:
        dmax = np.nanpercentile(dd, 99)
    edges = np.arange(0, dmax + bin_mm, bin_mm)
    ctr, med, sem, cnt = [], [], [], []
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (dd >= lo) & (dd < hi)
        if m.sum() == 0:
            continue
        v = gg[m]
        ctr.append((lo + hi) / 2); med.append(np.median(v))
        sem.append(v.std(ddof=1) / np.sqrt(m.sum()) if m.sum() > 1 else np.nan)
        cnt.append(m.sum())
    return (np.array(ctr), np.array(med), np.array(sem), np.array(cnt))


# ----------------------------- fits -----------------------------
def fit_excitatory(ctr, med):
    """Exponential-decay fit to the binned excitatory field. Returns params dict or None."""
    if len(ctr) < 4:
        return None
    p0 = [1.0, 1.0, 0.0]
    lo, hi = [0.0, 0.1, -0.5], [5.0, 12.0, 0.5]
    try:
        p, _ = scipy.optimize.curve_fit(_exp_decay, ctr, med, p0=p0, bounds=(lo, hi), maxfev=8000)
    except Exception as e:                                     # noqa: BLE001
        print("  excit exp fit failed:", e); return None
    yh = _exp_decay(ctr, *p)
    r2 = 1 - np.sum((med - yh) ** 2) / np.sum((med - med.mean()) ** 2)
    return dict(A=p[0], lam=p[1], c=p[2], r2=r2)


def _exp_suppress(d, A, lam, c):
    """Monotonic inhibitory field (no rebound): -A*exp(-d/lam) + c."""
    return -A * np.exp(-d / lam) + c


def fit_inhibitory(ctr, med):
    """Fit the inhibitory field with BOTH a difference-of-Gaussians (center-surround, allows a
    positive rebound via B) and a plain exponential suppression (monotonic, no rebound), and
    return whichever fits better plus a `rebound` flag. sigma_a bound widened so the fit is not
    rail-limited if the suppression is broad."""
    if len(ctr) < 5:
        return None
    out = {}
    # difference-of-Gaussians
    try:
        p, _ = scipy.optimize.curve_fit(_dog, ctr, med, p0=[1.2, 0.2, 0.4, 3.0],
                                        bounds=([0, 0, 0.1, 0.0], [5, 5, 8.0, 20.0]), maxfev=20000)
        yh = _dog(ctr, *p)
        out["dog"] = dict(A=p[0], B=p[1], sa=p[2], sb=p[2] + p[3],
                          r2=1 - np.sum((med - yh) ** 2) / np.sum((med - med.mean()) ** 2))
    except Exception as e:                                     # noqa: BLE001
        print("  inhib DoG fit failed:", e)
    # exponential suppression
    try:
        p, _ = scipy.optimize.curve_fit(_exp_suppress, ctr, med, p0=[1.0, 1.0, 0.0],
                                        bounds=([0, 0.1, -0.5], [5, 12, 0.5]), maxfev=8000)
        yh = _exp_suppress(ctr, *p)
        out["exp"] = dict(A=p[0], lam=p[1], c=p[2],
                          r2=1 - np.sum((med - yh) ** 2) / np.sum((med - med.mean()) ** 2))
    except Exception as e:                                     # noqa: BLE001
        print("  inhib exp fit failed:", e)
    if not out:
        return None
    dog, exp = out.get("dog"), out.get("exp")
    # "rebound present" = DoG has a meaningfully positive surround AND beats exp materially
    rebound = bool(dog and dog["B"] > 0.05 and (not exp or dog["r2"] > exp["r2"] + 0.02))
    best = dog if (rebound or not exp) else exp
    best = dict(best); best["model"] = "dog" if best is dog else "exp"
    best["rebound"] = rebound
    return best


# ----------------------------- figure -----------------------------
def _panel(ax, dd, gg, ctr, med, sem, fit, kind, amp):
    ax.axhline(0, c="0.6", lw=0.5, ls=":")
    ax.scatter(dd, gg, s=5, alpha=0.12, c="0.6", ec="none", zorder=1)
    ax.errorbar(ctr, med, yerr=sem, fmt="o", ms=4, c="k", lw=0.9, capsize=2, zorder=3,
                label="binned median +- SEM")
    xs = np.linspace(0, dd.max() if dd.size else 5, 200)
    if kind == "excit" and fit is not None:
        ax.plot(xs, _exp_decay(xs, fit["A"], fit["lam"], fit["c"]), "r-", lw=1.8, zorder=4,
                label=(f"exp decay\n$\\lambda$={fit['lam']:.2f} mm\n$R^2$={fit['r2']:.2f}"))
    elif kind == "inhib" and fit is not None:
        if fit["model"] == "dog":
            ax.plot(xs, _dog(xs, fit["A"], fit["B"], fit["sa"], fit["sb"] - fit["sa"]),
                    "b-", lw=1.8, zorder=4,
                    label=(f"diff-of-Gaussians\n$\\sigma_a$={fit['sa']:.2f} mm\n"
                           f"$\\sigma_b$={fit['sb']:.2f} mm\n$R^2$={fit['r2']:.2f}"))
        else:
            ax.plot(xs, _exp_suppress(xs, fit["A"], fit["lam"], fit["c"]),
                    "b-", lw=1.8, zorder=4,
                    label=(f"exp suppression\n(no rebound)\n$\\lambda$={fit['lam']:.2f} mm\n"
                           f"$R^2$={fit['r2']:.2f}"))
    title = "Excited (left / excitatory opsin)" if kind == "excit" else \
            "Inhibited (right / inhibitory opsin)"
    ax.set_title(f"{title}\namp {amp:.1f}", fontsize=10)
    ax.set_xlabel("distance from stim site (mm)")
    ax.set_ylabel("self-normalized peak dF/F")
    ax.legend(fontsize=7, loc="upper right" if kind == "excit" else "lower right")


def stim_fields(z, amp=None, save="grid_stim_fields.png"):
    """Fit + plot excitatory (exp) and inhibitory (DoG) fields at one amplitude."""
    sites, amps, gain, cvr2 = z["sites"], z["amps"], z["gain"], z["cvr2"]
    ai = len(amps) - 1 if amp is None else int(np.argmin(np.abs(amps - amp)))
    D = _dist_matrix(sites)
    left, right = sites[:, 0] < 0, sites[:, 0] > 0

    de, ge, ne = _pool(gain[ai], cvr2[ai], D, left, +1)
    di, gi, ni = _pool(gain[ai], cvr2[ai], D, right, -1)
    ce, me, se, _ = _binned(de, ge)
    ci, mi, si, _ = _binned(di, gi)
    fe, fi = fit_excitatory(ce, me), fit_inhibitory(ci, mi)

    fig, ax = plt.subplots(1, 2, figsize=(11, 4.6), constrained_layout=True)
    _panel(ax[0], de, ge, ce, me, se, fe, "excit", float(amps[ai]))
    _panel(ax[1], di, gi, ci, mi, si, fi, "inhib", float(amps[ai]))
    fig.suptitle(f"Optogenetic stimulation fields — AL_0048 2026-07-10 grid  "
                 f"(n_drivers: excit={ne}, inhib={ni})", fontsize=11)
    OUT.mkdir(exist_ok=True); out = OUT / Path(save).name
    fig.savefig(out, dpi=150); plt.close(fig)
    print("wrote", out)
    if fe:
        print(f"  EXCIT  lambda={fe['lam']:.3f} mm  (A={fe['A']:.2f}, c={fe['c']:+.3f}, "
              f"R2={fe['r2']:.2f}, n_drivers={ne})   [paper microstim: 0.71 mm]")
    if fi:
        if fi["model"] == "dog":
            print(f"  INHIB  DoG sigma_a={fi['sa']:.3f}  sigma_b={fi['sb']:.3f} mm  "
                  f"(A={fi['A']:.2f}, B={fi['B']:.2f}, rebound={fi['rebound']}, R2={fi['r2']:.2f}, "
                  f"n_drivers={ni})   [paper microstim: sa=0.16, sb=2.96, rebound=yes]")
        else:
            print(f"  INHIB  exp suppression lambda={fi['lam']:.3f} mm  NO surround rebound  "
                  f"(A={fi['A']:.2f}, R2={fi['r2']:.2f}, n_drivers={ni})   "
                  f"[paper microstim showed center-surround rebound]")
    print("  inhib binned profile (mm : median):",
          ", ".join(f"{c:.2f}:{m:+.2f}" for c, m in zip(ci, mi)))
    return dict(excit=fe, inhib=fi, n_excit=ne, n_inhib=ni)


def stim_fields_by_amp(z, save="grid_stim_fields_byamp.png"):
    """Same fields at every amplitude (rows) — a spatial LTI check: the length constant /
    center-surround widths should be roughly amplitude-invariant if the field just scales."""
    sites, amps, gain, cvr2 = z["sites"], z["amps"], z["gain"], z["cvr2"]
    D = _dist_matrix(sites)
    left, right = sites[:, 0] < 0, sites[:, 0] > 0
    nA = len(amps)
    fig, axes = plt.subplots(nA, 2, figsize=(11, 4.6 * nA), constrained_layout=True)
    axes = np.atleast_2d(axes)
    summ = []
    for ai in range(nA):
        de, ge, ne = _pool(gain[ai], cvr2[ai], D, left, +1)
        di, gi, ni = _pool(gain[ai], cvr2[ai], D, right, -1)
        ce, me, se, _ = _binned(de, ge); ci, mi, si, _ = _binned(di, gi)
        fe, fi = fit_excitatory(ce, me), fit_inhibitory(ci, mi)
        _panel(axes[ai, 0], de, ge, ce, me, se, fe, "excit", float(amps[ai]))
        _panel(axes[ai, 1], di, gi, ci, mi, si, fi, "inhib", float(amps[ai]))
        summ.append((float(amps[ai]), fe, fi))
    fig.suptitle("Stimulation fields vs laser power — spatial-shape amplitude invariance",
                 fontsize=11)
    OUT.mkdir(exist_ok=True); out = OUT / Path(save).name
    fig.savefig(out, dpi=150); plt.close(fig)
    print("wrote", out)
    for a, fe, fi in summ:
        le = f"{fe['lam']:.3f}" if fe else "n/a"
        if not fi:
            inh = "n/a"
        elif fi["model"] == "dog":
            inh = f"DoG sa/sb={fi['sa']:.2f}/{fi['sb']:.2f} (rebound={fi['rebound']})"
        else:
            inh = f"exp lambda={fi['lam']:.2f} (no rebound)"
        print(f"  amp {a:.1f}:  excit lambda={le} mm   inhib {inh}")


if __name__ == "__main__":
    z = _load()
    print(f"loaded 2-amp TF fits: amps={list(z['amps'])}, sites={len(z['sites'])}")
    stim_fields(z)                 # primary: high amp, excit exp | inhib DoG
    stim_fields_by_amp(z)          # amplitude-invariance check
