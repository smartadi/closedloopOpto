"""Session-level tests of the high/low state spectra (Fig 4E), plus the per-frequency curves for the
paper panels (Fig 4E, supplementary state figure). Hub #92, 2026-11-13.

Math approved by Aditya 2026-11-13 ("Do state spectra tests", after the method block posted in chat
that evening). For session s, condition c (OL, CL), state k and band b:

    P_Q(f)   mean periodogram of the 0-3 s residual (trial minus condition mean, x n/(n-1)) over the
             trials of state quartile Q (cut points on OL+CL pooled; >= 3 trials per quartile, else
             the session drops out of that cell). Same spectra and quartiles as state_spectra.py.
    y_scb  = ln( mean_{f in b} P_Q4(f) / mean_{f in b} P_Q1(f) ),  b in {0.5-1, 1-3, 3-6 Hz}
    test 1   mean_s y_scb = 0, one-sample t across sessions (tests.sess_test, log scale), per c.
    test 2   d_sb = y_sCLb - y_sOLb, mean_s d_sb = 0, paired across sessions.
    family   2 states (motion, absolute 1-4 Hz) x 3 bands x 3 tests = 18, Holm within each state
             window; run with the state over the locked [-2,+3) s window and over [-5,0) s laser off.
             For absolute 1-4 Hz power the locked window is circular (the state and the 0-3 s spectrum
             share 1-4 Hz power); the laser-off result is the check.
Relative 1-4 Hz power (1-4 Hz / 0.4-10 Hz, approved 2026-11-13 "Yes keep this") gets curves only,
for the supplement; it is not in the test family.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/state_spectra_tests.py
OUT  data/stats_v2/corrected/state_spectra_tests.csv   (one row per state x window x band x test)
     data/stats_v2/corrected/state_spectra_curves.csv  (per-frequency group ratio and 95% band)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402
import tests as T  # noqa: E402
from sensitivity import FREQ  # noqa: E402
from state_spectra import OUT, PERI, PRE5, condition_spectra, state_value  # noqa: E402

BANDS = {"0.5-1 Hz": (0.5, 1.0), "1-3 Hz": (1.0, 3.0), "3-6 Hz": (3.0, 6.0)}
WINDOWS = {"locked [-2,+3) s": PERI, "laser off [-5,0) s": PRE5}
TESTED = ("motion", "abs14")
CURVES = ("motion", "abs14", "rel14")
N_BOOT = 5000
RNG = np.random.default_rng(20261110)


def state_val(s, st, o, rng):
    if st == "rel14":
        seg = M.segment(s["dFk"], o, rng)
        if not np.all(np.isfinite(seg)):
            return np.nan
        return M.bandpower(seg, 1, 4) / M.bandpower(seg, 0.4, 10)
    return state_value(s, st, o, rng)


def quartile_spectra(s, sp, st, rng):
    """{c: (P_Q1(f), P_Q4(f), n_Q1, n_Q4)} for one session, or None for a cell with < 3 trials."""
    v = np.array([state_val(s, st, o, rng) for o in s["onset"]])
    use = np.zeros(len(v), bool)
    for c in ("OL", "CL"):
        use[sp[c]["idx"]] = True
    use &= np.isfinite(v)
    edges = np.quantile(v[use], [0.25, 0.5, 0.75])
    out = {}
    for c in ("OL", "CL"):
        vi = v[sp[c]["idx"]]
        q = np.where(np.isfinite(vi), np.searchsorted(edges, vi, side="right"), -1)
        n1, n4 = int(np.sum(q == 0)), int(np.sum(q == 3))
        P = sp[c]["resid"]
        out[c] = None if min(n1, n4) < 3 else (P[q == 0].mean(axis=0), P[q == 3].mean(axis=0), n1, n4)
    return out


def band_log_ratio(P1, P4, f0, f1):
    k = (FREQ >= f0) & (FREQ < f1)
    return float(np.log(P4[k].mean() / P1[k].mean()))


def main():
    # check: identical quartile spectra give y = 0
    P = np.linspace(1, 2, len(FREQ))
    assert abs(band_log_ratio(P, P, 0.5, 1.0)) < 1e-12

    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    sess = [loader.load_session(sid, onset_frames=onsets.get(sid)) for sid in loader.SESSION_IDS]
    spectra = [condition_spectra(s) for s in sess]

    test_rows, curve_rows = [], []
    for wname, rng in WINDOWS.items():
        fam = []
        for st in CURVES:
            per = []   # (mouse, {c: quartile spectra or None})
            for s, sp in zip(sess, spectra):
                if st == "motion" and not s["has_motion"]:
                    continue
                per.append((s["mouse"], quartile_spectra(s, sp, st, rng)))
            # per-frequency curves (group = geometric mean over sessions, session bootstrap band)
            for c in ("OL", "CL"):
                A = np.array([np.log(q[c][1]) - np.log(q[c][0]) for _, q in per if q[c] is not None])
                n = len(A)
                boot = np.array([A[RNG.integers(0, n, n)].mean(axis=0) for _ in range(N_BOOT)])
                lo, hi = np.percentile(boot, [2.5, 97.5], axis=0)
                m = A.mean(axis=0)
                for f, a, b, d in zip(FREQ, m, lo, hi):
                    curve_rows.append({"window": wname, "state": st, "cond": c, "freq": f,
                                       "ratio": np.exp(a), "lo": np.exp(b), "hi": np.exp(d), "n_sessions": n})
                nmin = min(min(q[c][2], q[c][3]) for _, q in per if q[c] is not None)
                print(f"{wname:20s} {st:7s} {c}: {n} sessions, fewest trials in Q1 or Q4 = {nmin}")
            if st not in TESTED:
                continue
            for bname, (f0, f1) in BANDS.items():
                y = {c: np.array([band_log_ratio(q[c][0], q[c][1], f0, f1) if q[c] is not None else np.nan
                                  for _, q in per]) for c in ("OL", "CL")}
                mice = np.array([mo for mo, _ in per])
                for test, vals in (("Q4/Q1 OL", y["OL"]), ("Q4/Q1 CL", y["CL"]),
                                   ("CL vs OL", y["CL"] - y["OL"])):
                    r = T.sess_test(np.exp(vals), mice, log=True)
                    fam.append({"window": wname, "state": st, "band": bname, "test": test,
                                "ratio": r["effect"], "ci_lo": r["ci_lo"], "ci_hi": r["ci_hi"],
                                "p": r["p"], "k": r["k"], "n": r["n"], "mouse_k": r.get("mouse_k"),
                                "lomo_worst_p": r.get("lomo_worst_p")})
        ph = T.holm([row["p"] for row in fam])
        for row, h in zip(fam, ph):
            row["p_holm"] = float(h)
        test_rows += fam

    tdf = pd.DataFrame(test_rows)
    tdf.to_csv(OUT / "state_spectra_tests.csv", index=False)
    pd.DataFrame(curve_rows).to_csv(OUT / "state_spectra_curves.csv", index=False)
    with pd.option_context("display.width", 200, "display.max_rows", 100):
        show = tdf[["window", "state", "band", "test", "ratio", "ci_lo", "ci_hi", "p", "p_holm", "k", "n"]]
        print(show.to_string(index=False, float_format=lambda x: f"{x:.3g}"))
    print(f"wrote {OUT / 'state_spectra_tests.csv'} and state_spectra_curves.csv")


if __name__ == "__main__":
    main()
