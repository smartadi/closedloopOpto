"""Fig 4C error split by frequency (the new Fig 4E). Hub #92, 2026-11-18.

Math approved by Aditya 2026-11-18: "Approve" (Hub control method block "replace 4E with the 4C error
power split into three frequency bands, stacked per quartile, for motion and absolute 1-4 Hz, OL and
CL"; RESEARCH L-2026-11-18-c). No tests.

For trial i of session s, over the 4C error window (1-3 s, frames 35-105, N = 71 samples at 35 Hz):
    e_i(t)  = x_i(t) - r                  x = dFk, r = the session's target (a constant)
    E_i(k)  = sum_t e_i(t) exp(-2 pi i k t / N),   f_k = 35 k / 71 Hz (|f| 0, 0.49, 0.99, ..., 17.25)
    MSE_i   = (1/N) sum_t e_i(t)^2 = (1/N^2) sum_k |E_i(k)|^2      (Parseval, no taper)
            = MSE_i,slow + MSE_i,1-4 + MSE_i,fast
              slow = bins 0 and 0.49 Hz (bin 0 is the trial's mean offset from target)
              1-4  = bins 0.99 to 3.94 Hz,   fast = bins 4.44 to 17.25 Hz
    part_i,b = MSE_i,b / (mean MSE over all the session's OL and CL trials)   (1 = session average)
Quartiles exactly as Fig 4C (fig4_paper_panels.quartile_means, f4_row2_quartiles.m): state over
[-2,+3) s from trials.csv, edges = 25/50/75% hazen quantiles of the session's OL and CL trials pooled,
sessions with >= 8 trials with a finite state in each condition. Bar = mean over sessions of the
session's quartile mean of part_i,b. The check sorts the same parts by the laser-off state ([-5,0) s,
state_spectra.state_value): for absolute 1-4 Hz the [-2,+3) s state contains the 1-3 s window.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/error_bands.py
OUT  data/stats_v2/corrected/error_bands_trials.csv     (one row per trial)
     data/stats_v2/corrected/error_bands_quartiles.csv  (window x state x cond x quartile x band)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402
from state_spectra import OUT, PRE5, state_value  # noqa: E402

N = M.WINDOWS["late"][1] - M.WINDOWS["late"][0] + 1
FABS = np.abs(np.fft.fftfreq(N, 1.0 / M.FS))
BANDS = {"slow": FABS < 0.75, "1-4 Hz": (FABS > 0.75) & (FABS < 4.2), "fast": FABS > 4.2}
STATES = {"motion": ("motion", "motion"), "abs_delta": ("abs_delta", "abs14")}  # trials.csv, state_value


def band_parts(e):
    """e: trials x N error samples -> (MSE, {band: MSE part}) by Parseval."""
    P = np.abs(np.fft.fft(e, axis=1)) ** 2 / N ** 2
    return np.mean(e ** 2, axis=1), {b: P[:, m].sum(axis=1) for b, m in BANDS.items()}


def checks():
    assert N == 71
    assert np.allclose(np.unique(FABS[BANDS["slow"]]), [0, 35 / 71])
    assert np.allclose(np.unique(FABS[BANDS["1-4 Hz"]]), 35 * np.arange(2, 9) / 71)
    assert np.allclose(np.unique(FABS[BANDS["fast"]]), 35 * np.arange(9, 36) / 71)
    t = np.arange(N) / M.FS
    rng = np.random.default_rng(0)
    e = np.vstack([np.full(N, 0.7), np.sin(2 * np.pi * (4 * 35 / 71) * t), rng.normal(0, 1, (5, N))])
    mse, parts = band_parts(e)
    tot = sum(parts.values())
    assert np.allclose(tot, mse, rtol=1e-9, atol=0)
    assert np.isclose(parts["slow"][0], 0.49) and parts["1-4 Hz"][0] < 1e-20 and parts["fast"][0] < 1e-20
    assert np.isclose(parts["1-4 Hz"][1], mse[1]) and parts["slow"][1] < 1e-20 and parts["fast"][1] < 1e-20
    _, p2 = band_parts(np.sin(2 * np.pi * 2.0 * t)[None, :])
    frac = p2["1-4 Hz"][0] / sum(v[0] for v in p2.values())
    print(f"checks passed: parts sum to MSE; a constant falls in slow only; a sine at the 1.97 Hz bin "
          f"falls in 1-4 Hz only; a 2.00 Hz sine puts {frac:.3f} of its power in 1-4 Hz")


def quartile_parts(tr, state_col):
    """{(cond, band): sessions x 4} of session quartile means of the normalised parts, as 4C
    (band "z": the 4C quantity itself, z-scored RMSE, for the check against quartile_means)."""
    out = {(c, b): [] for c in ("OL", "CL") for b in list(BANDS) + ["total", "z"]}
    for _, g in tr.groupby("session", sort=False):
        y = g["rmse_late"].to_numpy(float)
        zy = (y - np.nanmean(y)) / np.nanstd(y, ddof=1)
        x = g[state_col].to_numpy(float)
        ok = np.isfinite(x) & np.isfinite(zy)
        isol, iscl = (g["condition"] == "OL").to_numpy(), (g["condition"] == "CL").to_numpy()
        if (ok & isol).sum() < 8 or (ok & iscl).sum() < 8:
            continue
        e = np.quantile(x[ok], [0.25, 0.5, 0.75], method="hazen")
        q = np.searchsorted(e, x, side="right")
        norm = np.nanmean(g["mse"].to_numpy(float))
        for c, m in (("OL", isol), ("CL", iscl)):
            out[(c, "z")].append([np.nanmean(zy[ok & m & (q == k)]) for k in range(4)])
            for b in list(BANDS) + ["total"]:
                v = (g["mse"] if b == "total" else g[f"mse_{b}"]).to_numpy(float) / norm
                out[(c, b)].append([np.nanmean(v[ok & m & (q == k)]) for k in range(4)])
    return {k: np.array(v) for k, v in out.items()}


def main():
    checks()
    tr = pd.read_csv(OUT / "trials.csv")
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    rows = []
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, onset_frames=onsets.get(sid))
        X = np.array([M.segment(s["dFk"], o, M.WINDOWS["late"]) for o in s["onset"]])
        ok = np.all(np.isfinite(X), axis=1)
        mse = np.full(len(X), np.nan)
        parts = {b: np.full(len(X), np.nan) for b in BANDS}
        mse[ok], p = band_parts(X[ok] - s["ref"])
        for b in BANDS:
            parts[b][ok] = p[b]
        for j, o in enumerate(s["onset"]):
            r = {"session": s["id"], "onset_frame": int(o) + 1, "mse": mse[j]}
            r.update({f"mse_{b}": parts[b][j] for b in BANDS})
            for col, st in STATES.values():
                r[f"{col}_pre5"] = (state_value(s, st, o, PRE5) if (st != "motion" or s["has_motion"])
                                    else np.nan)
            rows.append(r)
    bt = pd.DataFrame(rows)
    tr = tr.merge(bt, on=["session", "onset_frame"], how="left", validate="one_to_one")
    assert tr["mse"].notna().sum() == tr["rmse_late"].notna().sum()
    d = np.nanmax(np.abs(tr["mse"] - tr["rmse_late"] ** 2) / tr["rmse_late"] ** 2)
    assert d < 1e-9, d
    s3 = tr[[f"mse_{b}" for b in BANDS]].sum(axis=1)
    assert np.nanmax(np.abs(s3 - tr["mse"]) / tr["mse"]) < 1e-9
    print(f"{len(tr)} trials; MSE = rmse_late^2 (max relative difference {d:.1e}); parts sum to MSE")
    tr.to_csv(OUT / "error_bands_trials.csv", index=False)

    # check: same session quartile rule as 4C (z means equal fig4_paper_panels.quartile_means)
    import fig4_paper_panels as FP
    qrows = []
    for wname, suffix in (("locked [-2,+3) s", ""), ("laser off [-5,0) s", "_pre5")):
        for col in STATES:
            Q = quartile_parts(tr, col + suffix)
            if not suffix:
                m4c, _, n4c = FP.quartile_means(tr, col)
                z = np.array([np.nanmean(Q[(c, "z")], axis=0) for c in ("OL", "CL")])
                assert Q[("OL", "total")].shape[0] == n4c and np.allclose(z, m4c), (z, m4c)
            for (c, b), A in Q.items():
                if b == "z":
                    continue
                for k in range(4):
                    qrows.append({"window": wname, "state": col, "cond": c, "quartile": k + 1, "band": b,
                                  "mean": float(np.nanmean(A[:, k])), "n_sessions": int(np.sum(np.isfinite(A[:, k])))})
            tot = Q[("OL", "total")].mean(axis=0)
            parts = sum(Q[("OL", b)] for b in BANDS).mean(axis=0)
            assert np.allclose(tot, parts)
            print(f"{wname:20s} {col:9s}: {Q[('OL', 'total')].shape[0]} sessions")
    qt = pd.DataFrame(qrows)
    qt.to_csv(OUT / "error_bands_quartiles.csv", index=False)
    show = qt[qt.band != "total"].pivot_table(index=["window", "state", "cond", "band"], columns="quartile",
                                              values="mean")
    with pd.option_context("display.width", 200, "display.max_rows", 100):
        print(show.round(3).to_string())
    print(f"wrote {OUT / 'error_bands_trials.csv'} and error_bands_quartiles.csv")


if __name__ == "__main__":
    main()
