"""Certify the Results claim on the loop's frequency limit with the empirical sensitivity curve.

Claim (JN Results, Aditya 2026-11-02): a 29 ms loop delay alone permits feedback up to about 4 Hz;
with ~100 ms kinetics the effective limit for disturbance rejection is about 1.5 Hz; slower
perturbations are counteracted, faster ones pass largely uncorrected.

  1. Where the limit is: crossing of CL/OL = 1 under estimator variants (window, taper, detrend),
     per mouse, leaving each mouse out.
  2. Where the curve clearly leaves 1: per-frequency 95% t CI over sessions; 0.5 Hz bands.
  3. Not circular: leave-one-session-out. Crossing from the other sessions, then the held-out
     session's power ratio below and above it.
  4. Can 3 s trials locate a crossing? Ground truth: noise with the measured OL spectrum through a
     known loop L = K exp(-theta s)/s, same trial counts and estimator, known crossing.
  5. The arithmetic behind the delay and kinetics numbers.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/sensitivity_cert.py
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
from sensitivity import FREQ, NFFT, band, crossings, geo, periodograms, resid_psd, trials  # noqa: E402
from tests import holm, sess_test  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2" / "corrected"
FIG = loader.ROOT / "paper" / "images" / "figure4" / "supp"
RNG = np.random.default_rng(20261102)
N_BOOT = 5000
N_SIM = 300
HOLD = 0.014  # s, holding each command for one frame
LAT_MEAN, LAT_MIN, LAT_MAX = 0.029, 0.014, 0.047  # s, JN latency test recording
TAU_DIP = 0.113  # s, median dip time constant
FINE = [(0.5, 1.0), (1.0, 1.5), (1.5, 2.0), (2.0, 2.5), (2.5, 3.0), (3.0, 3.5), (3.5, 4.0), (4.0, 5.0)]
THETA = LAT_MEAN + HOLD
TRUE_C = [1.0, 1.5, 2.0, 3.0]


def psd_detrended(mat):
    n = mat.shape[0]
    r = signal.detrend(mat - mat.mean(axis=0, keepdims=True), axis=1, type="linear")
    return periodograms(r).mean(axis=0) * n / (n - 1)


def psd_multitaper(mat, nw=2.0, k=3):
    n, L = mat.shape
    r = mat - mat.mean(axis=0, keepdims=True)
    tap = signal.windows.dpss(L, nw, Kmax=k)  # unit energy
    out = 0.0
    for w in tap:
        X = np.fft.rfft(r * w, NFFT, axis=1)
        P = np.abs(X) ** 2 / (M.FS * np.sum(w ** 2))
        P[:, 1:-1] *= 2.0
        out = out + P.mean(axis=0)
    return out / k * n / (n - 1)


def cross_only(S):
    return crossings(S)[0]


def half_power(S, lo=0.33, hi=3.0):
    """First rise of CL/OL through 0.5. Only meaningful if it lies above the window's resolution."""
    k = np.where((FREQ >= lo) & (FREQ <= hi))[0]
    for a, b in zip(k[:-1], k[1:]):
        if S[a] < 0.5 <= S[b]:
            return FREQ[a] + (0.5 - S[a]) * (FREQ[b] - FREQ[a]) / (S[b] - S[a])
    return np.nan


def boot_cross(logS):
    n = logS.shape[0]
    c = np.array([cross_only(np.exp(logS[RNG.integers(0, n, n)].mean(axis=0))) for _ in range(N_BOOT)])
    return np.nanpercentile(c, [2.5, 97.5]), float(np.mean(np.isnan(c)))


def stretches(mask):
    """[(lo Hz, hi Hz)] of contiguous True runs on the FREQ grid."""
    out, i = [], 0
    idx = np.where(mask)[0]
    if len(idx) == 0:
        return out
    start = prev = idx[0]
    for j in idx[1:]:
        if j != prev + 1:
            out.append((float(FREQ[start]), float(FREQ[prev])))
            start = j
        prev = j
    out.append((float(FREQ[start]), float(FREQ[prev])))
    return out


# ---------------------------------------------------------------------- ground truth
def s_true(f, K, theta=THETA):
    w = 2 * np.pi * f
    w[0] = 1e-9
    L = K * np.exp(-1j * w * theta) / (1j * w)
    return 1.0 / (1.0 + L)


def simulate(sd_fn, nTr, K, n_long=2 ** 17):
    """Sessions of independent OL and CL trials; returns the estimated geometric-mean CL/OL."""
    f = np.fft.rfftfreq(n_long, 1.0 / M.FS)
    amp = np.sqrt(sd_fn(f) * n_long * M.FS / 4.0)
    logS = []
    win = M.WINDOWS["full"]
    L = win[1] - win[0] + 1
    H = s_true(f.copy(), K)
    for nO, nC in nTr:
        Pd = []
        for gain, nt in ((None, nO), (H, nC)):
            spec = amp * (RNG.normal(size=len(f)) + 1j * RNG.normal(size=len(f)))
            if gain is not None:
                spec = spec * gain
            x = np.fft.irfft(spec, n_long)
            st = RNG.integers(0, n_long - L, nt)
            Pd.append(resid_psd(np.stack([x[a:a + L] for a in st])))
        logS.append(np.log(Pd[1] / Pd[0]))
    return np.exp(np.mean(logS, axis=0))


def panel(freq, g, lo, hi, gp):
    """Sensitivity panel in house style (PNG until locked). Bars mark where the 95% CI excludes 1."""
    plt.rcParams.update({"font.family": "Arial", "font.size": 6, "font.weight": "bold",
                         "axes.labelweight": "bold", "axes.linewidth": 0.5, "xtick.major.width": 0.5,
                         "ytick.major.width": 0.5, "xtick.major.size": 2, "ytick.major.size": 2,
                         "axes.spines.top": False, "axes.spines.right": False, "pdf.fonttype": 42})
    fig, a = plt.subplots(figsize=(6.5 / 2.54, 4.4 / 2.54), constrained_layout=True)
    kp = (freq >= 0.5) & (freq <= 17.5)
    f = freq[kp]
    a.axhline(1, color="0.35", lw=0.6, ls="--", zorder=1)
    a.plot(f, gp[kp], color="0.6", lw=1.0, zorder=2, label="Before stimulus")
    a.fill_between(f, lo[kp], hi[kp], color="0.78", lw=0, zorder=3)
    a.plot(f, g[kp], color="k", lw=1.5, zorder=4, label="During stimulus")
    lim = 1 / (2 * np.pi * THETA)
    a.axvline(lim, color="0.3", lw=0.6, ls=":", zorder=2)
    a.text(lim * 1.06, 0.47, f"Delay limit {lim:.1f} Hz", color="0.3", ha="left", va="center")
    tr = a.get_xaxis_transform()
    below = [s for s in stretches_on(freq, hi < 1) if s[1] > 0.5][0]
    above = stretches_on(freq, lo > 1)[0]
    for (x0, x1), lab in (((max(below[0], 0.5), below[1]), "Reduced"), (above, "Amplified")):
        a.plot([x0, x1], [0.97, 0.97], color="k", lw=1.5, transform=tr, solid_capstyle="butt", clip_on=False)
        a.text(np.sqrt(x0 * x1), 0.995, lab, transform=tr, ha="center", va="bottom", color="k")
    a.set(xscale="log", yscale="log", xlim=(0.5, 17.5), ylim=(0.2, 3.4),
          xlabel="Frequency (Hz)", ylabel="CL / OL residual power")
    a.set_xticks([0.5, 1, 2, 4, 8, 16])
    a.set_xticklabels(["0.5", "1", "2", "4", "8", "16"])
    a.set_yticks([0.25, 0.5, 1, 2])
    a.set_yticklabels(["0.25", "0.5", "1", "2"])
    a.minorticks_off()
    a.legend(frameon=False, loc="lower right", handlelength=0.9, handletextpad=0.4, borderaxespad=0.1,
             labelspacing=0.2)
    out = FIG / "sens_panel.png"
    fig.savefig(out, dpi=300)
    print(f"wrote {out}")


def stretches_on(freq, mask):
    idx = np.where(mask)[0]
    runs = np.split(idx, np.where(np.diff(idx) != 1)[0] + 1)
    return [(float(freq[r[0]]), float(freq[r[-1]])) for r in runs if len(r)]


def main():
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    EST = {"Hann 0-3 s": ("full", resid_psd), "Hann 1-3 s": ("late", resid_psd),
           "Hann + detrend 0-3 s": ("full", psd_detrended), "Multitaper 0-3 s": ("full", psd_multitaper)}
    logS = {k: [] for k in EST}
    logPre, Pol, sess, mice, nTr, pre_ol = [], [], [], [], [], []
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, onset_frames=onsets.get(sid))
        for k, (w, fn) in EST.items():
            logS[k].append(np.log(fn(trials(s, w, 1)) / fn(trials(s, w, 0))))
        logPre.append(np.log(resid_psd(trials(s, "pre", 1)) / resid_psd(trials(s, "pre", 0))))
        Xo = trials(s, "full", 0)
        Pol.append(resid_psd(Xo))
        nTr.append((len(Xo), len(trials(s, "full", 1))))
        sess.append(sid)
        mice.append(s["mouse"])
    mice = np.array(mice)
    logS = {k: np.array(v) for k, v in logS.items()}
    logPre = np.array(logPre)
    base = logS["Hann 0-3 s"]
    g, lo, hi = geo(base)
    gp, lop, hip = geo(logPre)

    # 5 --------------------------------------------------------------- arithmetic
    print("5. Arithmetic")
    for name, th in (("29 ms alone", LAT_MEAN), ("29 + 14 ms hold", LAT_MEAN + HOLD),
                     ("47 + 14 ms (max)", LAT_MAX + HOLD), ("14 + 14 ms (min)", LAT_MIN + HOLD)):
        print(f"   delay {name:18s}: 1/(2 pi theta) = {1 / (2 * np.pi * th):.2f} Hz")
    for tau in (0.100, TAU_DIP):
        print(f"   lag {tau * 1e3:.0f} ms alone: corner {1 / (2 * np.pi * tau):.2f} Hz; "
              f"delay + lag summed ({(THETA + tau) * 1e3:.0f} ms): {1 / (2 * np.pi * (THETA + tau)):.2f} Hz")

    # 1 --------------------------------------------------------------- crossing
    print("\n1. Crossing of CL/OL = 1, by estimator (session bootstrap 95%)")
    rows = []
    for k, ls in logS.items():
        S = np.exp(ls.mean(axis=0))
        c, fp, sp = crossings(S)
        ci, nanf = boot_cross(ls)
        rows.append({"estimator": k, "cross_hz": c, "ci_lo": ci[0], "ci_hi": ci[1], "nan_frac": nanf,
                     "peak_hz": fp, "peak_S": sp, "half_power_hz": half_power(S)})
    est = pd.DataFrame(rows)
    est.to_csv(OUT / "sens_cert_estimators.csv", index=False)
    print(est.to_string(index=False, float_format=lambda v: f"{v:.2f}"))

    print("\n   By mouse (geometric mean of that mouse's sessions, Hann 0-3 s)")
    for mo in pd.unique(mice):
        m = mice == mo
        c, fp, sp = crossings(np.exp(base[m].mean(axis=0)))
        c2 = crossings(np.exp(base[~m].mean(axis=0)))[0]
        print(f"   {mo}: {m.sum()} sessions, crossing {c:.2f} Hz, peak {sp:.2f} at {fp:.2f} Hz; "
              f"leave this mouse out: crossing {c2:.2f} Hz")
    mm = np.array([base[mice == mo].mean(axis=0) for mo in pd.unique(mice)])
    print(f"   mean of the 4 mouse means: crossing {crossings(np.exp(mm.mean(axis=0)))[0]:.2f} Hz")

    # 2 --------------------------------------------------------------- where it leaves 1
    print("\n2. Per-frequency 95% CI excludes 1 (Hann 0-3 s, sessions)")
    print("   below 1:", [(round(a, 2), round(b, 2)) for a, b in stretches(hi < 1)])
    print("   above 1:", [(round(a, 2), round(b, 2)) for a, b in stretches(lo > 1)])
    print("   pre-stim below 1:", [(round(a, 2), round(b, 2)) for a, b in stretches(hip < 1)],
          " above 1:", [(round(a, 2), round(b, 2)) for a, b in stretches(lop > 1)])
    for fq in (0.67, 1.0, 1.25, 1.5, 2.0, 3.0, 4.2, 6.0, 8.0, 12.0):
        i = np.argmin(np.abs(FREQ - fq))
        print(f"   {FREQ[i]:5.2f} Hz: CL/OL {g[i]:.2f} [{lo[i]:.2f}, {hi[i]:.2f}]  |S| {np.sqrt(g[i]):.2f}")

    print("\n   0.5 Hz bands, CL/OL band power (Holm over these bands)")
    fine = []
    # band power needs the two spectra, so rebuild them for the primary estimator
    Pc, Po = [], []
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, onset_frames=onsets.get(sid))
        Pc.append(resid_psd(trials(s, "full", 1)))
        Po.append(resid_psd(trials(s, "full", 0)))
    Pc, Po = np.array(Pc), np.array(Po)
    for a, b in FINE:
        r = np.array([band(Pc[i], a, b) / band(Po[i], a, b) for i in range(len(sess))])
        t = sess_test(r, mice, log=True)
        fine.append({"band": f"{a:g}-{b:g}", "ratio": t["effect"], "ci_lo": t["ci_lo"], "ci_hi": t["ci_hi"],
                     "p": t["p"], "k": t["k"], "sign": t["sign"], "mouse_k": t["mouse_k"]})
    fine = pd.DataFrame(fine)
    fine["p_holm"] = holm(fine["p"].to_numpy())
    fine.to_csv(OUT / "sens_cert_fine.csv", index=False)
    print(fine.to_string(index=False, float_format=lambda v: f"{v:.3g}"))

    # 3 --------------------------------------------------------------- leave one session out
    below, above, cs = [], [], []
    for i in range(len(sess)):
        c = crossings(np.exp(np.delete(base, i, axis=0).mean(axis=0)))[0]
        cs.append(c)
        below.append(band(Pc[i], 0.67, c) / band(Po[i], 0.67, c))
        above.append(band(Pc[i], c, 3.0) / band(Po[i], c, 3.0))
    tb, ta = sess_test(np.array(below), mice, log=True), sess_test(np.array(above), mice, log=True)
    print(f"\n3. Leave one session out: crossing {min(cs):.2f}-{max(cs):.2f} Hz across folds")
    print(f"   held-out power 0.67 Hz to crossing: {tb['effect']:.2f} [{tb['ci_lo']:.2f}, {tb['ci_hi']:.2f}], "
          f"p = {tb['p']:.2g}, {tb['k']}/{tb['n']}, {tb['mouse_k']}/{tb['mouse_n']} mice")
    print(f"   held-out power crossing to 3 Hz:    {ta['effect']:.2f} [{ta['ci_lo']:.2f}, {ta['ci_hi']:.2f}], "
          f"p = {ta['p']:.2g}, {ta['k']}/{ta['n']} ({ta['sign']}), {ta['mouse_k']}/{ta['mouse_n']} mice")

    # 4 --------------------------------------------------------------- ground truth
    print(f"\n4. Ground truth, {N_SIM} simulated 15-session data sets, measured OL spectrum, theta {THETA * 1e3:.0f} ms")
    geoOL = np.exp(np.log(Po).mean(axis=0))
    ok = FREQ >= 0.5
    # below the resolved range, continue the measured spectrum as 1/f down to a floor at 0.02 Hz
    f0 = FREQ[ok][0]
    p0 = geoOL[ok][0]

    def sd_fn(f):
        out = np.interp(f, FREQ[ok], geoOL[ok])
        low = f < f0
        out[low] = p0 * (f0 / np.maximum(f[low], 0.02))
        return out

    grid = np.linspace(0.05, 17.5, 20000)
    sim_rows = []
    for ct in TRUE_C:
        w = 2 * np.pi * ct
        K = 2 * w * np.sin(w * THETA)  # closed form for |1 + L| = 1
        S2 = np.abs(s_true(grid.copy(), K)) ** 2
        ip = np.argmax(S2)
        est_c, est_p = [], []
        for _ in range(N_SIM):
            S = simulate(sd_fn, nTr, K)
            c, fp, _sp = crossings(S)
            est_c.append(c)
            est_p.append(fp)
        est_c = np.array(est_c)
        sim_rows.append({"true_cross": ct, "K": K, "true_peak_hz": grid[ip], "true_peak_S": S2[ip],
                         "est_cross_median": np.nanmedian(est_c),
                         "est_cross_lo": np.nanpercentile(est_c, 2.5), "est_cross_hi": np.nanpercentile(est_c, 97.5),
                         "bias": np.nanmedian(est_c) - ct, "nan_frac": float(np.mean(np.isnan(est_c))),
                         "est_peak_median": np.median(est_p)})
    sim = pd.DataFrame(sim_rows)
    sim.to_csv(OUT / "sens_cert_groundtruth.csv", index=False)
    print(sim.to_string(index=False, float_format=lambda v: f"{v:.2f}"))

    c0, fp0, sp0 = crossings(g)
    ci0, _ = boot_cross(base)
    (OUT / "sens_cert_summary.json").write_text(json.dumps(
        {"crossing_hz": c0, "crossing_ci": list(ci0), "peak_hz": fp0, "peak_ratio": sp0,
         "delay_limit_hz": 1 / (2 * np.pi * THETA)}, indent=2))

    panel(FREQ, g, lo, hi, gp)


if __name__ == "__main__":
    if "--panel" in sys.argv:  # redraw from sensitivity.py's saved curve, skipping the simulations
        c = pd.read_csv(OUT / "sensitivity_curve.csv")
        panel(c["f_hz"].to_numpy(), c["S_full"].to_numpy(), c["S_full_lo"].to_numpy(),
              c["S_full_hi"].to_numpy(), c["S_pre"].to_numpy())
    else:
        main()
