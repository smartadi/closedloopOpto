"""High/low state quartile power ratio of the readout, per frequency, for SfN poster box 7 (2026-11-10).

For motion and absolute 1-4 Hz power: each session's Q4/Q1 ratio of the 0-3 s residual spectrum,
in OL and CL, then the group ratio = geometric mean over sessions, with a 95% band from resampling
sessions (percentile bootstrap, 5000 draws). No test (Aditya's call). Ratio 1 = the state adds no
power at that frequency.

Choices Aditya made (2026-11-10, box 7):
  states        motion and absolute 1-4 Hz only (box 7's heading).
  state window  both on the locked Fig 4 window [-2,+3) s, so the spectra match the quartile tiles.
                For 1-4 Hz power this is circular (the state is the readout's own 1-4 Hz power,
                partly inside the 0-3 s spectrum); the laser-off [-5,0) s version is in
                state_spectra.py's sheets (08-09) for comparison.
  signal        residual (trial minus its condition's mean, x n/(n-1)), as the sensitivity curve.
  statistic     Q4/Q1 power ratio; OL and CL separately.
  uncertainty   session bootstrap band, no test.
Quartiles, spectra and state values come from state_spectra.py (cut points on OL+CL pooled, a
session's quartile spectrum = mean of its trials' periodograms, >= 3 trials per quartile).

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/state_ratio_poster.py
OUT  data/stats_v2/corrected/state_ratio_poster.csv  (read by poster/sfn2026/st_quart_panel.m)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

import loader  # noqa: E402
from sensitivity import FREQ  # noqa: E402
from state_spectra import OUT, PERI, condition_spectra, state_value  # noqa: E402

CASES = [("motion", "Motion", PERI), ("abs14", "Absolute 1–4 Hz", PERI)]
N_BOOT = 5000
RNG = np.random.default_rng(20261110)
BANDS = {"reduces <1.03 Hz": (0.0, 1.03), "1.03-2.77 Hz": (1.03, 2.77), "amplifies 2.77-6.63 Hz": (2.77, 6.63)}


def session_log_ratio(s, sp, st, qrng):
    """log(P_Q4 / P_Q1) per frequency for OL and CL in one session (NaN if a quartile has < 3 trials)."""
    v = np.array([state_value(s, st, o, qrng) for o in s["onset"]])
    use = np.zeros(len(v), bool)
    for c in ("OL", "CL"):
        use[sp[c]["idx"]] = True
    use &= np.isfinite(v)
    edges = np.quantile(v[use], [0.25, 0.5, 0.75])
    out = {}
    for c in ("OL", "CL"):
        vi = v[sp[c]["idx"]]
        q = np.where(np.isfinite(vi), np.searchsorted(edges, vi, side="right"), -1)
        P = sp[c]["resid"]
        if np.sum(q == 0) < 3 or np.sum(q == 3) < 3:
            out[c] = np.full(len(FREQ), np.nan)
        else:
            out[c] = np.log(P[q == 3].mean(axis=0)) - np.log(P[q == 0].mean(axis=0))
    return out


def main():
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    sess = [loader.load_session(sid, onset_frames=onsets.get(sid)) for sid in loader.SESSION_IDS]
    spectra = [condition_spectra(s) for s in sess]

    rows = []
    for st, name, qrng in CASES:
        L = {"OL": [], "CL": []}
        for s, sp in zip(sess, spectra):
            if st == "motion" and not s["has_motion"]:
                continue
            r = session_log_ratio(s, sp, st, qrng)
            for c in L:
                L[c].append(r[c])
        for c, A in L.items():
            A = np.array(A)
            A = A[np.all(np.isfinite(A), axis=1)]
            n = len(A)
            boot = np.array([A[RNG.integers(0, n, n)].mean(axis=0) for _ in range(N_BOOT)])
            lo, hi = np.percentile(boot, [2.5, 97.5], axis=0)
            m = A.mean(axis=0)
            for f, a, b, d in zip(FREQ, m, lo, hi):
                rows.append({"state": st, "cond": c, "freq": f, "ratio": np.exp(a), "lo": np.exp(b),
                             "hi": np.exp(d), "n_sessions": n})
            msg = []
            for bn, (f0, f1) in BANDS.items():
                k = (FREQ > max(f0, 0.3)) & (FREQ <= f1)
                bb = np.exp(boot[:, k].mean(axis=1))
                msg.append(f"{bn}: {np.exp(m[k].mean()):.2f} [{np.percentile(bb, 2.5):.2f}, "
                           f"{np.percentile(bb, 97.5):.2f}]")
            print(f"{name:16s} {c} (n={n}): " + " | ".join(msg))
    df = pd.DataFrame(rows)
    df.to_csv(OUT / "state_ratio_poster.csv", index=False)
    print(f"wrote {OUT / 'state_ratio_poster.csv'}  ({len(df)} rows)")


if __name__ == "__main__":
    main()
