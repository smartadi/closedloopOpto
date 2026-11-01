"""Empirical sensitivity: closed- vs open-loop residual power as a function of frequency.

Reviewer request (2026-11-01): plot CL/OL residual power against frequency, to test the
Discussion's account (slow fluctuations are rejected; 1-4 Hz sits near the 2.8-4.2 Hz loop
bandwidth) and whether feedback ADDS 1-4 Hz power. Model-free: no contra prediction, so all
15 sessions enter (ctrl_sensitivity_freq.m needs the Global and covered 13).

Estimator, per session and condition:
  residual   = trial trace minus the condition's trial-mean trace. This removes the
               deterministic stim-locked response. In OL the command is fixed, so the residual
               is the disturbance itself; in CL it is the disturbance after feedback.
  P(f)       = Hann-tapered periodogram of each residual, averaged over trials, x n/(n-1) for
               the removed mean. Absolute (%dF/F)^2/Hz, no normalisation.
  S(f)       = P_CL(f) / P_OL(f).  < 1 feedback suppresses, > 1 feedback amplifies.
Across sessions: mean of log S with a t CI (= geometric mean), as tests.sess_test does.
Null: the same estimator on the pre-stim window (laser off in both conditions) must sit at 1.
Check: the same ratio on the error about the reference (x - ref, mean NOT removed), which also
carries the deterministic transient and offset.

Windows (M.WINDOWS): 'full' 0-3 s (RMSE window), 'late' 1-3 s (disturbance-rejection window,
skips the onset transient), 'pre' -3-0 s. A 3 s Hann window resolves about 0.67 Hz (2 s: 1 Hz),
so the lowest band is reported as "slow", DC included, not resolved within.

Onsets and the m14 mapping are the corrected ones (run_all.py --corrected).

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/sensitivity.py
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import matplotlib  # noqa: E402

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy import signal, stats  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402
from tests import holm, sess_test  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2" / "corrected"
FIG = loader.ROOT / "paper" / "images" / "figure4" / "supp"
M14_SHIFT = 11
NFFT = 1024
BANDS = [(0.0, 1.0), (1.0, 2.0), (2.0, 4.0), (4.0, 10.0)]
# 1 Hz bands up to Nyquist (17.5 Hz); Holm-adjusted within each window. Neighbouring bands are
# not independent: the 3 s Hann window smears about 0.67 Hz.
BANDS_1HZ = [(float(lo), min(lo + 1.0, M.FS / 2)) for lo in range(1, 18)]
BW_PRED = (2.8, 4.2)  # Discussion's delay-limited bandwidth (discussion.tex:30)
WINS = ["full", "late", "pre"]
F_PLOT = (0.33, M.FS / 2)
N_BOOT = 5000
RNG = np.random.default_rng(20261101)
COL_OL, COL_CL = "#d62728", "#1f77b4"  # locked condition colours: OL red, CL blue

FREQ = np.fft.rfftfreq(NFFT, 1.0 / M.FS)


def periodograms(mat):
    """mat: trials x samples (already centred). One-sided Hann periodogram per trial."""
    w = signal.windows.hann(mat.shape[1], sym=True)
    X = np.fft.rfft(mat * w, NFFT, axis=1)
    P = np.abs(X) ** 2 / (M.FS * np.sum(w ** 2))
    P[:, 1:-1] *= 2.0
    return P


def resid_psd(mat):
    n = mat.shape[0]
    return periodograms(mat - mat.mean(axis=0, keepdims=True)).mean(axis=0) * n / (n - 1)


def err_psd(mat, ref):
    return periodograms(mat - ref).mean(axis=0)


def band(P, lo, hi):
    k = (FREQ >= lo) & (FREQ <= hi)
    return float(np.trapezoid(P[k], FREQ[k]))


def trials(s, win, cond):
    segs = [M.segment(s["dFk"], o, M.WINDOWS[win]) for o, c in zip(s["onset"], s["cond"]) if c == cond]
    segs = np.array([x for x in segs if np.all(np.isfinite(x))])
    return segs


def geo(logS):
    """logS: sessions x freq. Geometric mean and 95% t CI per frequency."""
    n = logS.shape[0]
    m = logS.mean(axis=0)
    se = logS.std(axis=0, ddof=1) / np.sqrt(n)
    t = stats.t.ppf(0.975, n - 1)
    return np.exp(m), np.exp(m - t * se), np.exp(m + t * se)


def crossings(S, lo=0.67, hi=10.0):
    """First upward crossing of 1 above lo, and the peak of S in [1, hi] Hz."""
    k = np.where((FREQ >= lo) & (FREQ <= hi))[0]
    up = np.nan
    for a, b in zip(k[:-1], k[1:]):
        if S[a] < 1 <= S[b]:
            up = FREQ[a] + (1 - S[a]) * (FREQ[b] - FREQ[a]) / (S[b] - S[a])
            break
    kp = np.where((FREQ >= 1.0) & (FREQ <= hi))[0]
    ip = kp[np.argmax(S[kp])]
    return up, FREQ[ip], S[ip]


def band_table(bands, P, E, sess, mice):
    """One session test per (window, band) on log(CL/OL band power); Holm within each window."""
    rows = []
    for w in WINS + ["full_err"]:
        src = E["full"] if w == "full_err" else P[w]
        for lo, hi in bands:
            r_s = np.array([band(src["CL"][i], lo, hi) / band(src["OL"][i], lo, hi)
                            for i in range(len(sess))])
            t = sess_test(r_s, mice, log=True)
            rows.append({"window": w, "band": f"{lo:g}-{hi:g}", "lo": lo, "hi": hi,
                         "ratio": t["effect"], "ci_lo": t["ci_lo"], "ci_hi": t["ci_hi"],
                         "p": t["p"], "wilcoxon_p": t["wilcoxon_p"], "k": t["k"], "n": t["n"],
                         "dir": "CL<OL" if t["sign"] == "neg" else "CL>OL",
                         "mouse_k": t["mouse_k"], "mouse_n": t["mouse_n"],
                         "lomo_worst_p": t["lomo_worst_p"],
                         **{f"S_{x}": v for x, v in zip(sess, r_s)}})
    bt = pd.DataFrame(rows)
    bt["p_holm"] = np.nan
    for w, g in bt.groupby("window"):
        bt.loc[g.index, "p_holm"] = holm(g["p"].to_numpy())
    return bt


def main():
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    OUT.mkdir(parents=True, exist_ok=True)
    FIG.mkdir(parents=True, exist_ok=True)

    sess, mice = [], []
    P = {w: {"OL": [], "CL": []} for w in WINS}
    E = {w: {"OL": [], "CL": []} for w in WINS}
    nTr = []
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, dfk_offset=M14_SHIFT if sid == "m14" else 0,
                                onset_frames=onsets.get(sid))
        n = {}
        for w in WINS:
            for cname, c in (("OL", 0), ("CL", 1)):
                X = trials(s, w, c)
                n[(w, cname)] = len(X)
                P[w][cname].append(resid_psd(X))
                E[w][cname].append(err_psd(X, s["ref"]))
        sess.append(sid)
        mice.append(s["mouse"])
        nTr.append((n[("full", "OL")], n[("full", "CL")]))
        print(f"{sid}: {s['mn']} {s['td']}  OL {n[('full','OL')]}  CL {n[('full','CL')]}")
    mice = np.array(mice)
    for w in WINS:
        for c in ("OL", "CL"):
            P[w][c] = np.array(P[w][c])
            E[w][c] = np.array(E[w][c])

    # ---------------------------------------------------------------- per-frequency curves
    curves = {}
    for w in WINS:
        logS = np.log(P[w]["CL"] / P[w]["OL"])
        curves[w] = geo(logS) + (logS,)
    logE = np.log(E["full"]["CL"] / E["full"]["OL"])
    curves["full_err"] = geo(logE) + (logE,)

    # bootstrap over sessions: crossover and peak of the geometric-mean S (full window)
    boot = []
    logS = curves["full"][3]
    for _ in range(N_BOOT):
        idx = RNG.integers(0, len(sess), len(sess))
        boot.append(crossings(np.exp(logS[idx].mean(axis=0))))
    boot = np.array(boot, float)
    xo, fpk, spk = crossings(curves["full"][0])

    # ---------------------------------------------------------------- band tests
    bt = band_table(BANDS, P, E, sess, mice)
    bt.to_csv(OUT / "sensitivity_bands.csv", index=False)
    b1 = band_table(BANDS_1HZ, P, E, sess, mice)
    b1.to_csv(OUT / "sensitivity_bands_1hz.csv", index=False)
    pd.DataFrame({"f_hz": FREQ,
                  **{f"S_{w}": curves[w][0] for w in curves},
                  **{f"S_{w}_lo": curves[w][1] for w in curves},
                  **{f"S_{w}_hi": curves[w][2] for w in curves},
                  "P_OL_full_geo": np.exp(np.log(P["full"]["OL"]).mean(0)),
                  "P_CL_full_geo": np.exp(np.log(P["full"]["CL"]).mean(0))}
                 ).to_csv(OUT / "sensitivity_curve.csv", index=False)

    summ = {"sessions": sess, "n_trials_OL_CL": nTr,
            "crossover_hz": xo, "crossover_boot_ci": np.nanpercentile(boot[:, 0], [2.5, 97.5]).tolist(),
            "crossover_boot_nan_frac": float(np.mean(np.isnan(boot[:, 0]))),
            "peak_hz": fpk, "peak_S": spk,
            "peak_boot_ci_hz": np.percentile(boot[:, 1], [2.5, 97.5]).tolist(),
            "peak_boot_ci_S": np.percentile(boot[:, 2], [2.5, 97.5]).tolist()}
    (OUT / "sensitivity_summary.json").write_text(json.dumps(summ, indent=2))

    pd.set_option("display.width", 200)
    print("\nBand ratios CL/OL (geometric mean over sessions, 95% t CI):")
    print(bt[["window", "band", "ratio", "ci_lo", "ci_hi", "p", "wilcoxon_p", "k", "n", "dir",
              "mouse_k", "lomo_worst_p"]].to_string(index=False, float_format=lambda v: f"{v:.4g}"))
    cols = ["band", "ratio", "ci_lo", "ci_hi", "p", "p_holm", "k", "n", "dir", "mouse_k"]
    for w in ("full", "late", "pre"):
        print(f"\n1 Hz bands, window '{w}' (Holm over {len(BANDS_1HZ)} bands):")
        print(b1[b1["window"] == w][cols].to_string(index=False, float_format=lambda v: f"{v:.4g}"))
    print(f"\nfull 0-3 s: upward crossing of S=1 at {xo:.2f} Hz "
          f"(boot 95% {summ['crossover_boot_ci'][0]:.2f}-{summ['crossover_boot_ci'][1]:.2f}); "
          f"peak S {spk:.3f} at {fpk:.2f} Hz (boot {summ['peak_boot_ci_hz'][0]:.2f}-"
          f"{summ['peak_boot_ci_hz'][1]:.2f} Hz)")

    # ---------------------------------------------------------------- figure (review sheet)
    kp = (FREQ >= F_PLOT[0]) & (FREQ <= F_PLOT[1])
    f = FREQ[kp]
    fig = plt.figure(figsize=(15, 9), constrained_layout=True)
    gs = fig.add_gridspec(2, 3)
    ax = [fig.add_subplot(gs[0, j]) for j in range(3)] + [fig.add_subplot(gs[1, :])]

    a = ax[0]
    for c, col, lab in (("OL", COL_OL, "open loop"), ("CL", COL_CL, "closed loop")):
        lg = np.log(P["full"][c][:, kp])
        g, lo, hi = geo(lg)
        a.fill_between(f, lo, hi, color=col, alpha=0.2, lw=0)
        a.plot(f, g, color=col, lw=1.8, label=lab)
    a.set(xscale="log", yscale="log", xlabel="Frequency (Hz)",
          ylabel="Residual power ((%ΔF/F)² Hz⁻¹)", title="a  Residual power, 0–3 s")
    a.axvspan(*BW_PRED, color="0.85", zorder=0, label="predicted bandwidth")
    a.legend(frameon=False)

    a = ax[1]
    for w, col, lab, lw in (("pre", "0.55", "pre-stim −3–0 s (null)", 1.2),
                            ("late", "#6a3d9a", "stim 1–3 s", 1.2),
                            ("full", "k", "stim 0–3 s", 2.0)):
        g, lo, hi, lS = curves[w]
        if w == "full":
            a.plot(f, np.exp(lS[:, kp]).T, color="0.8", lw=0.4, zorder=1)
        a.fill_between(f, lo[kp], hi[kp], color=col, alpha=0.18, lw=0, zorder=2)
        a.plot(f, g[kp], color=col, lw=lw, label=lab, zorder=3)
    a.axhline(1, color="0.3", ls="--", lw=1)
    a.axvspan(*BW_PRED, color="0.85", zorder=0)
    a.axvline(0.67, color="0.6", ls=":", lw=1)
    a.set(xscale="log", yscale="log", xlabel="Frequency (Hz)", ylabel="CL / OL residual power",
          title="b  Empirical sensitivity |S(f)|²", ylim=(0.05, 4))
    a.legend(frameon=False, loc="lower right")

    a = ax[2]
    xb = np.arange(len(BANDS))
    for j, (w, col, dx) in enumerate((("full", "k", -0.2), ("late", "#6a3d9a", 0.0), ("pre", "0.55", 0.2))):
        sub = bt[bt["window"] == w]
        for i, (_, r) in enumerate(sub.iterrows()):
            v = np.array([r[f"S_{x}"] for x in sess])
            a.scatter(np.full(len(v), i + dx) + RNG.uniform(-0.04, 0.04, len(v)), v, s=8,
                      color=col, alpha=0.5, lw=0)
            a.errorbar(i + dx, r["ratio"], yerr=[[r["ratio"] - r["ci_lo"]], [r["ci_hi"] - r["ratio"]]],
                       fmt="o", color=col, ms=5, capsize=2, label={"full": "0–3 s", "late": "1–3 s",
                                                                    "pre": "pre (null)"}[w] if i == 0 else None)
    a.axhline(1, color="0.3", ls="--", lw=1)
    a.set(yscale="log", xticks=xb, xticklabels=[f"{lo:g}–{hi:g} Hz" for lo, hi in BANDS],
          ylabel="CL / OL band power", title="c  Band power ratio (session dots, GM ± 95% CI)")
    a.legend(frameon=False)

    a = ax[3]
    for w, col, dx, lab in (("full", "k", -0.2, "stim 0–3 s"), ("late", "#6a3d9a", 0.0, "stim 1–3 s"),
                            ("pre", "0.55", 0.2, "pre-stim (null)")):
        sub = b1[b1["window"] == w]
        xc = (sub["lo"].to_numpy() + sub["hi"].to_numpy()) / 2 + dx * 0.5
        yr = sub["ratio"].to_numpy()
        a.errorbar(xc, yr, yerr=[yr - sub["ci_lo"].to_numpy(), sub["ci_hi"].to_numpy() - yr],
                   fmt="o-", color=col, ms=4, lw=1, capsize=2, label=lab)
        if w != "pre":
            sig = sub["p_holm"].to_numpy() < 0.05
            a.scatter(xc[sig], sub["ci_hi"].to_numpy()[sig] * 1.08, marker="*", s=30, color=col, lw=0)
    a.axhline(1, color="0.3", ls="--", lw=1)
    a.axvspan(*BW_PRED, color="0.85", zorder=0)
    a.set(yscale="log", xlim=(0.8, 17.7), xticks=np.arange(1, 18),
          xlabel="Frequency (Hz), 1 Hz bands (last 17–17.5 Hz)", ylabel="CL / OL band power",
          title="d  1 Hz bands up to Nyquist (GM ± 95% CI; ★ Holm p < 0.05 over 17 bands)")
    a.legend(frameon=False, ncol=3, loc="upper right")
    out = FIG / "sens_resid_sheet.png"
    fig.savefig(out, dpi=300)
    print(f"\nwrote {out}")


if __name__ == "__main__":
    main()
