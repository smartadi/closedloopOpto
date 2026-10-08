"""Replicate Lu et al. 2025 (arXiv:2510.18037, Ziyu; same lab, same rig) on our controller session (user 2026-10-07:
"use what they do"). Their recipe, from the paper's Sec. 3 + Appendix A.1-A.4:
  signal   region-averaged hemo-corrected SVD reconstruction at 35 Hz (CCF SS/MO/VIS/RSP). Ours: no CCF registration
           for controller sessions -> APPROXIMATE regions (ctrl_lu_regions_export.m), 4 on the stimulated hemisphere and
           the 4 mirror boxes on the contra hemisphere; plus the controlled 5x5 px spot (rig online dF/F).
  split    chronological 60 / 20 / 20 (train / val / test) of the valid frames.
  windows  val + test samples = sliding windows with NON-OVERLAPPING targets: sample k forecasts [s+kL, s+(k+1)L)
           from the history before it.
  AR       AR(valQL): univariate, Gaussian; lag order grown from 1 until validation MWQL fails to improve for 10
           consecutive orders; best order evaluated on test (no refit on val). DEVIATION: fitted by least squares
           (conditional Gaussian ML) instead of StatsForecast AutoRegressive -- statsforecast 2.1.1 on this Python
           (no numba) took >10 min per fit; for T ~ 80k frames the two estimates coincide.
  Naive    last value, sigma_h^2 = h sigma^2 (A.2.1).   Average  training mean.
  metrics  (A.3) MWQL = sum_i sum_t (1/Q) sum_q rho_q / sum |y| (q = .1..9, rho with the factor 2); MAE, MSE normalised by
           sum|y|, sum y^2; per-step MSE_t; median per-window Pearson r; all also as ratios to Naive (Fig 1c / Fig 2).
           Plus what WE use: per-step R^2 (mean-subtracted).
  horizons L = 18, 35 (paper) and 7 (our 200 ms MPC preview).
  data     A) all test windows (the session includes the stimulation -- AR is blind to it)
           B) only test windows whose history (p lags) and target contain no stimulation (closest to their spont data)
Also: our VARX (100 spots + laser, L10, lambda100) on the same windows (point forecast -> MAE/MSE/R^2 only).

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_lu_replicate.py [sess]
OUT     data/mpc_lu_replicate_<sess>.mat, paper/images/mpc_arx/lu_replicate_<sess>.png
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat
from scipy.stats import norm

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_pred200_sweep import Model, BASE, POST  # noqa: E402

HERE = Path(__file__).resolve().parent
DATA, FIG = HERE / "data", HERE.parent / "paper" / "images" / "mpc_arx"
QS = np.arange(0.1, 0.91, 0.1); ZQ = norm.ppf(QS)
PATIENCE, P_MAX, HORIZONS = 10, 200, (7, 18, 35)


def fit_ar(y, p):
    """OLS AR(p) with intercept on a contiguous series; returns (c, phi[p], sigma)."""
    Xl = np.column_stack([y[p - j - 1:len(y) - j - 1] for j in range(p)] + [np.ones(len(y) - p)])
    b, *_ = np.linalg.lstsq(Xl, y[p:], rcond=None)
    res = y[p:] - Xl @ b
    return b[-1], b[:-1], res.std()


def ar_forecast(y, org, c, phi, sig, L):
    """Iterated mean + Gaussian sd (psi weights) for leads 1..L from origins org (last observed index)."""
    p = phi.size
    hist = y[org[:, None] - np.arange(p)]                     # newest first
    out = np.empty((org.size, L))
    for h in range(L):
        nxt = c + hist @ phi
        out[:, h] = nxt
        hist = np.concatenate([nxt[:, None], hist[:, :-1]], 1)
    psi = np.zeros(L); psi[0] = 1.0
    for j in range(1, L):
        psi[j] = sum(phi[i] * psi[j - 1 - i] for i in range(min(p, j)))
    sd = sig * np.sqrt(np.cumsum(psi ** 2))
    return out, np.broadcast_to(sd, out.shape)


def mwql_terms(y, mu, sd):
    """Sum over quantiles (1/Q) of rho_q (paper's factor-2 quantile score), elementwise."""
    f = mu[..., None] + sd[..., None] * ZQ
    d = y[..., None] - f
    rho = np.where(d < 0, 2 * (1 - QS) * (-d), 2 * QS * d)
    return rho.mean(-1)


def scores(Y, mu, sd=None):
    out = dict(MAE=np.abs(Y - mu).sum() / np.abs(Y).sum(), MSE=((Y - mu) ** 2).sum() / (Y ** 2).sum(),
               MSE_t=((Y - mu) ** 2).sum(0) / (Y ** 2).sum(0),
               R2_t=1 - ((Y - mu) ** 2).sum(0) / ((Y - Y.mean(0)) ** 2).sum(0),
               r=np.nanmedian([np.corrcoef(a, b)[0, 1] if np.std(b) > 0 else np.nan for a, b in zip(Y, mu)]))
    if sd is not None:
        out["MWQL"] = mwql_terms(Y, mu, sd).sum() / np.abs(Y).sum()
    return out


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    Rg = loadmat(DATA / f"ctrl_lu_regions_{sess}.mat", squeeze_me=True)
    Wb = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)
    valid = A["valid"].astype(bool); v0 = int(np.flatnonzero(valid)[0])
    assert valid[v0:].all(), "valid frames are not one contiguous block"
    names = [str(n) for n in Rg["names"]] + ["controlled spot"]
    SER = np.column_stack([Rg["R"].astype(float), A["y"].astype(float)])[v0:]
    ur = A["u"].astype(float)[v0:]; Xs = Wb["X"].astype(float)[v0:]; Xs = Xs / Xs.std(0)
    onOL, onCL = A["onOL"].astype(int) - 1 - v0, A["onCL"].astype(int) - 1 - v0
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T = SER.shape[0]
    stim = np.zeros(T, bool)
    for o in np.concatenate([onOL, onCL]):
        if 0 <= o < T:
            stim[max(0, o): min(T, o + N + POST)] = True               # stim + 2 s post (laser off-transient)
    t_tr, t_va = int(0.6 * T), int(0.8 * T)
    print(f"[LU] {sess}: {T} valid frames ({T/Fs/60:.1f} min); train {t_tr} | val {t_va-t_tr} | test {T-t_va}; "
          f"stim-affected frames {stim.mean()*100:.0f} %", flush=True)

    def windows(s, e, L, pmin):
        org = np.arange(s - 1, e - L, L)                            # last observed index of each sample
        return org[org - pmin >= 0]

    res, orders = {}, {}
    for si, nm in enumerate(names):
        y = SER[:, si]
        for L in HORIZONS:
            # ---- AR(valQL) order selection on the validation windows ------------------------------------
            ov = windows(t_tr, t_va, L, P_MAX)
            Yv = y[ov[:, None] + np.arange(1, L + 1)]
            best, bp, bad, p, fits = np.inf, 1, 0, 0, {}
            while bad < PATIENCE and p < P_MAX:
                p += 1
                c, phi, sig = fit_ar(y[:t_tr], p)
                mu, sd = ar_forecast(y, ov, c, phi, sig, L)
                q = mwql_terms(Yv, mu, sd).sum() / np.abs(Yv).sum()
                fits[p] = (c, phi, sig)
                if q < best - 1e-12:
                    best, bp, bad = q, p, 0
                else:
                    bad += 1
            orders[(nm, L)] = bp
            c, phi, sig = fits[bp]
            # ---- test -------------------------------------------------------------------------------------
            ot = windows(t_va, T, L, P_MAX)
            spont_ok = np.array([not stim[o - max(bp, 70) + 1: o + L + 1].any() for o in ot])
            sig_n = np.std(np.diff(y[:t_tr]))
            for cond, sel in (("all", np.ones(ot.size, bool)), ("spont", spont_ok)):
                o = ot[sel]; Y = y[o[:, None] + np.arange(1, L + 1)]
                mu_ar, sd_ar = ar_forecast(y, o, c, phi, sig, L)
                mu_nv = np.repeat(y[o][:, None], L, 1); sd_nv = np.broadcast_to(sig_n * np.sqrt(np.arange(1, L + 1)), Y.shape)
                mu_av = np.full(Y.shape, y[:t_tr].mean())
                r = {"AR": scores(Y, mu_ar, sd_ar), "Naive": scores(Y, mu_nv, sd_nv), "Average": scores(Y, mu_av)}
                res[(nm, L, cond)] = (r, o.size)
            print(f"[LU] {nm:15s} L={L:2d} AR p={bp:3d} | " + " | ".join(
                f"{cond}: n={res[(nm, L, cond)][1]:4d} MWQL/Naive {res[(nm, L, cond)][0]['AR']['MWQL']/res[(nm, L, cond)][0]['Naive']['MWQL']:.3f} "
                f"MSE/Naive {res[(nm, L, cond)][0]['AR']['MSE']/res[(nm, L, cond)][0]['Naive']['MSE']:.3f} "
                f"R2@{L} {res[(nm, L, cond)][0]['AR']['R2_t'][-1]:.3f} (naive {res[(nm, L, cond)][0]['Naive']['R2_t'][-1]:.3f})"
                for cond in ("all", "spont")), flush=True)

    # ---- our VARX on the same test windows (controlled spot + ipsi SS), L = 35 -> every step ----------------
    vx = {}
    for nm in ("controlled spot", "SS"):
        si = names.index(nm); y = SER[:, si]; sy = y[:t_va].std(); L = 35
        rows = np.arange(100, t_va - L - 1)
        m = Model(dict(BASE), y / sy, Xs, ur / ur[:t_va].std(), rows).fit(rows, stim)
        ot = windows(t_va, T, L, P_MAX)
        for cond in ("all", "spont"):
            o = ot if cond == "all" else ot[[not stim[t - 69: t + L + 1].any() for t in ot]]
            Y = y[o[:, None] + np.arange(1, L + 1)]
            vx[(nm, cond)] = scores(Y, m.predict(o, L) * sy)
            print(f"[LU] VARX {nm:15s} {cond:5s} R2@7/18/35 " + " ".join(f"{vx[(nm, cond)]['R2_t'][h-1]:.3f}" for h in (7, 18, 35)), flush=True)

    # ---- figure: their Fig 3-style per-step MSE_t (normalised by sum y^2) + R^2 at our 200 ms ----------------
    FIG.mkdir(parents=True, exist_ok=True)
    fig, ax = plt.subplots(2, 3, figsize=(16, 8.5), constrained_layout=True)
    L = 35; tt = np.arange(1, L + 1) / Fs
    for j, cond in enumerate(("all", "spont")):
        a = ax[j, 0]
        for nm, c in zip(names, list(plt.cm.tab10(np.arange(8))) + ["k"]):
            r, n = res[(nm, L, cond)]
            a.plot(tt, r["AR"]["MSE_t"], "-", color=c, lw=1.6 if nm == "controlled spot" else 1, label=f"{nm} (n={n})")
            a.plot(tt, r["Naive"]["MSE_t"], ":", color=c, lw=0.8)
        a.axhline(1, color="g", lw=0.8); a.set_ylim(0, 1.6)
        a.axvspan(0.19, 0.21, color="r", alpha=0.15)
        a.set_title(f"AR(valQL) per-step MSE_t (Lu A.3; solid AR, dotted Naive) | {cond} test windows", fontsize=8.5)
        a.set_xlabel("time from forecast start (s)"); a.set_ylabel("MSE_t / sum y²  (Lu Fig A3 bottom)")
        if j == 0:
            a.legend(fontsize=6, frameon=False, ncol=2)
        a = ax[j, 1]
        xs = np.arange(len(names))
        for k, (Lh, c) in enumerate(zip(HORIZONS, ("#023047", "#219ebc", "#8ecae6"))):
            a.bar(xs + (k - 1) * 0.27, [res[(nm, Lh, cond)][0]["AR"]["MWQL"] / res[(nm, Lh, cond)][0]["Naive"]["MWQL"] for nm in names],
                  0.27, color=c, label=f"{Lh} steps ({Lh/Fs:.1f} s)")
        a.axhline(0.83, color="r", ls="--", lw=0.8, label="Lu AR, 1.0 s (Fig 1c read)")
        a.set_xticks(xs); a.set_xticklabels(names, rotation=45, ha="right", fontsize=7); a.set_ylim(0.4, 1.1)
        a.set_ylabel("MWQL relative to Naive (Lu Fig 1c)"); a.legend(fontsize=6.5, frameon=False)
        a.set_title(f"AR(valQL) MWQL / Naive, all steps aggregated | {cond}", fontsize=8.5)
        a = ax[j, 2]
        a.bar(xs - 0.2, [res[(nm, 35, cond)][0]["AR"]["R2_t"][6] for nm in names], 0.4, color="#e76f51", label="AR(valQL)")
        a.bar(xs + 0.2, [res[(nm, 35, cond)][0]["Naive"]["R2_t"][6] for nm in names], 0.4, color="#adb5bd", label="Naive")
        for nm in ("controlled spot", "SS"):
            a.plot(names.index(nm), vx[(nm, cond)]["R2_t"][6], "k*", ms=10, label="our VARX" if nm == "SS" else None)
        a.set_xticks(xs); a.set_xticklabels(names, rotation=45, ha="right", fontsize=7)
        a.set_ylabel("R² at 200 ms (step 7)"); a.legend(fontsize=7, frameon=False); a.set_ylim(0, 1)
        a.set_title(f"200 ms R² on the same windows | {cond}", fontsize=8.5)
    fig.suptitle(f"Lu et al. 2025 recipe on {sess} (approximate regions; no CCF)", fontsize=10)
    fig.savefig(FIG / f"lu_replicate_{sess}.png", dpi=170)
    rows = []
    for (nm, Lh, cond), (r, n) in res.items():
        for mdl in ("AR", "Naive", "Average"):
            s = r[mdl]
            rows.append([names.index(nm), Lh, cond == "spont", ("AR", "Naive", "Average").index(mdl), n, s.get("MWQL", np.nan),
                         s["MAE"], s["MSE"], s["r"], s["R2_t"][min(6, Lh - 1)], s["R2_t"][-1], orders[(nm, Lh)]])
    savemat(DATA / f"mpc_lu_replicate_{sess}.mat", {"names": np.array(names, dtype=object), "table": np.array(rows),
            "cols": "series L spont model n MWQL MAE MSE median_r R2_step7 R2_lastStep AR_order"})


if __name__ == "__main__":
    main(*sys.argv[1:])
