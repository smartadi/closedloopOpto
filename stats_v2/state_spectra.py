"""Frequency composition of the Fig 4d states: readout spectra by state quartile (Aditya, 2026-11-10).

Look-at-the-data pass, no tests (Aditya's call). For each Fig 4d state, trials are split into
within-session quartiles (cut points on OL and CL trials pooled, as Fig 4d z-scores across both),
and the readout's 0-3 s spectrum is averaged per quartile, separately in OL and CL.

Choices Aditya made (2026-11-10):
  delta quartile window   both: laser-off [-5,0) s and the locked [-2,+3) s. The locked one is
                          circular for delta (the state is the readout's own 1-4 Hz power inside
                          the spectrum window); he decides which to keep after seeing both.
  spectrum window         0-3 s after onset (same as the sensitivity curve).
  signal                  both: residual (trial minus its condition's mean trace, x n/(n-1), as
                          sensitivity.py) and error from the reference (trial minus d.ref).
Defaults kept from sensitivity.py (stated to him, not objected to): motion state over the locked
[-2,+3) s window (face camera, not the readout), Hann periodogram NFFT 1024 at 35 Hz, a session's
quartile spectrum = mean of its trials' periodograms (>= 3 trials), group = geometric mean over
sessions. The shaded ranges are where the sensitivity curve's 95% CI excludes 1
(sensitivity_cert.py): feedback reduces power below 1.03 Hz and amplifies it at 2.77-6.63 Hz.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/state_spectra.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import matplotlib  # noqa: E402

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402
from sensitivity import F_PLOT, FREQ, periodograms  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2" / "corrected"
FIG = loader.ROOT / "paper" / "images" / "figure4" / "supp"
PERI, PRE5 = (-70, 104), (-175, -1)
SPEC = M.WINDOWS["full"]  # 0-3 s
CASES = [("Motion, [−2,+3) s", "motion", PERI),
         ("Absolute 1–4 Hz, laser-off [−5,0) s", "abs14", PRE5),
         ("Absolute 1–4 Hz, locked [−2,+3) s (circular)", "abs14", PERI),
         ("Relative 2–4 Hz, laser-off [−5,0) s", "rel24", PRE5),
         ("Relative 2–4 Hz, locked [−2,+3) s (circular)", "rel24", PERI)]
SIGNALS = {"resid": "Residual (trial − condition mean)", "err": "Error from reference (trial − ref)"}
QCOL = plt.cm.viridis(np.array([0.85, 0.6, 0.35, 0.05]))  # Q1 light -> Q4 dark
SENS_LO, SENS_HI = 1.03, (2.77, 6.63)


def state_value(s, st, o, rng):
    if st == "motion":
        seg = M.segment(s["motion"], o, rng)
        return float(np.mean(seg)) if np.all(np.isfinite(seg)) else np.nan
    seg = M.segment(s["dFk"], o, rng)
    if not np.all(np.isfinite(seg)):
        return np.nan
    if st == "rel24":
        return M.bandpower(seg, 2, 4) / M.bandpower(seg, 0.4, 10)
    return float(np.log10(M.bandpower(seg, 1, 4)))


def condition_spectra(s):
    """Per-trial periodograms over 0-3 s, per condition and signal."""
    out = {}
    for name, code in (("OL", 0), ("CL", 1)):
        idx = np.where(s["cond"] == code)[0]
        X = np.array([M.segment(s["dFk"], s["onset"][i], SPEC) for i in idx])
        ok = np.all(np.isfinite(X), axis=1)
        idx, X = idx[ok], X[ok]
        n = len(X)
        out[name] = {"idx": idx,
                     "resid": periodograms(X - X.mean(axis=0, keepdims=True)) * n / (n - 1),
                     "err": periodograms(X - s["ref"])}
    return out


def main():
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    sess = [loader.load_session(sid, onset_frames=onsets.get(sid)) for sid in loader.SESSION_IDS]
    spectra = [condition_spectra(s) for s in sess]

    # res[(case, signal, cond)] = sessions x 4 x freq ; counts[(case, cond)] = sessions x 4
    res, counts, nsess = {}, {}, {}
    for label, st, qrng in CASES:
        per = {(sg, c): [] for sg in SIGNALS for c in ("OL", "CL")}
        cnt = {c: [] for c in ("OL", "CL")}
        for s, sp in zip(sess, spectra):
            if st == "motion" and not s["has_motion"]:
                continue
            v = np.array([state_value(s, st, o, qrng) for o in s["onset"]])
            use = np.zeros(len(v), bool)
            for c in ("OL", "CL"):
                use[sp[c]["idx"]] = True
            use &= np.isfinite(v)
            edges = np.quantile(v[use], [0.25, 0.5, 0.75])
            for c in ("OL", "CL"):
                vi = v[sp[c]["idx"]]
                q = np.where(np.isfinite(vi), np.searchsorted(edges, vi, side="right"), -1)
                nq = [int(np.sum(q == k)) for k in range(4)]
                cnt[c].append(nq)
                for sg in SIGNALS:
                    Pj = sp[c][sg]
                    per[(sg, c)].append([Pj[q == k].mean(axis=0) if nq[k] >= 3
                                         else np.full(len(FREQ), np.nan) for k in range(4)])
        for key, val in per.items():
            res[(label, *key)] = np.array(val)
        for c in cnt:
            counts[(label, c)] = np.array(cnt[c])
        nsess[label] = len(cnt["OL"])

    # ---------------------------------------------------------------- tables
    rows = []
    for (label, sg, c), A in res.items():
        g = np.exp(np.nanmean(np.log(A), axis=0))  # 4 x freq
        for k in range(4):
            rows.append({"state": label, "signal": sg, "cond": c, "quartile": k + 1,
                         "n_sessions": int(np.sum(np.all(np.isfinite(A[:, k]), axis=1))),
                         **{f"{f:.3f}": p for f, p in zip(FREQ, g[k])}})
    pd.DataFrame(rows).to_csv(OUT / "state_spectra.csv", index=False)
    print("Trials per quartile, median over sessions [min-max] (Q1..Q4):")
    for label, _, _ in CASES:
        for c in ("OL", "CL"):
            n = counts[(label, c)]
            print(f"  {label:48s} {c}: " + "  ".join(
                f"{int(np.median(n[:, k]))} [{n[:, k].min()}-{n[:, k].max()}]" for k in range(4))
                  + f"   ({nsess[label]} sessions)")

    # ---------------------------------------------------------------- figures
    kp = (FREQ >= F_PLOT[0]) & (FREQ <= F_PLOT[1])
    f = FREQ[kp]
    for sg, sg_title in SIGNALS.items():
        fig, ax = plt.subplots(len(CASES), 2, figsize=(7.2, 2.15 * len(CASES)), sharex=True,
                               sharey=True, constrained_layout=True)
        for i, (label, st, _) in enumerate(CASES):
            for j, c in enumerate(("OL", "CL")):
                a = ax[i, j]
                A = res[(label, sg, c)]
                g = np.exp(np.nanmean(np.log(A), axis=0))
                a.axvspan(F_PLOT[0], SENS_LO, color="0.9", lw=0, zorder=0)
                a.axvspan(*SENS_HI, color="#fbe3cf", lw=0, zorder=0)
                for k in range(4):
                    a.plot(f, g[k, kp], color=QCOL[k], lw=1.2,
                           label=["Q1 (low)", "Q2", "Q3", "Q4 (high)"][k])
                a.set(xscale="log", yscale="log")
                a.set_title(f"{label}\n{c}, n = {nsess[label]} sessions", fontsize=7.5)
                a.tick_params(labelsize=7)
                if j == 0:
                    a.set_ylabel("Power ((%ΔF/F)² Hz⁻¹)", fontsize=7.5)
                if i == len(CASES) - 1:
                    a.set_xlabel("Frequency (Hz)", fontsize=7.5)
        ax[0, 0].legend(frameon=False, fontsize=6.5, loc="lower left")
        ax[0, 1].text(0.5, 0.97, "gray: feedback reduces (<1.03 Hz)\norange: feedback amplifies (2.77–6.63 Hz)",
                      transform=ax[0, 1].transAxes, ha="center", va="top", fontsize=6)
        for a in ax.ravel():
            a.set_xlim(*F_PLOT)
            a.set_xticks([0.5, 1, 2, 4, 8, 16])
            a.set_xticklabels(["0.5", "1", "2", "4", "8", "16"])
        fig.suptitle(f"Readout spectra 0–3 s by state quartile: {sg_title}; geometric mean over sessions",
                     fontsize=8.5)
        out = FIG / f"state_spectra_{sg}.png"
        fig.savefig(out, dpi=220, facecolor="white")
        plt.close(fig)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
