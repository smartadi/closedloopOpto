"""VARX forecaster variants for tuning the MPC on CL trials (user 2026-10-08/09: "tune varx for best performance,
maybe we need input smoothing to not react against fast twitches").

Written to data/ctrl_mpc_varx_tune_<sess>.mat as F.<variant> (departure d_hat - Dmean, [N x Hp x nT], same CL folds),
scored by ctrl_mpc_varx_tune.m (MPC/PI, selection on odd CL trials, report on even + all).
  model variants (d + 100 spots + laser; future laser held at its origin value, as mpc_varx_cl.py):
      L in {5, 10, 20} x lambda in {100, 1e3};  Q in {10, 70} at L10/lambda100
  forecast-smoothing variants on the base VARX (L10, lambda100) -- what the MPC actually reacts to:
      leadMA3 / leadMA5  moving average ACROSS LEADS within each forecast (uses only that forecast)
      combA5 / combA3    combine successive forecasts of the SAME target frame (causal):
                         G[t, j] = a F[t, j] + (1-a) G[t-1, j+1]  (a = 0.5 / 0.3), lead Hp falls back to F
  (Smoothing the VARX *inputs* is a no-op for a linear model whose embedding already spans the smoothing window,
  so input smoothing is tested where it can matter: on the preview and via the MPC's Delta-u penalty rd.)

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_varx_tune.py [sess]
"""
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_pred200_sweep import Model, BASE  # noqa: E402
from mpc_varx_cl import predict_hold, HIST  # noqa: E402

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"


def lead_ma(F, w):
    k = np.ones(w) / w; out = np.empty_like(F)
    for t in range(F.shape[0]):
        for j in range(F.shape[2]):
            x = np.pad(F[t, :, j], (w // 2, w // 2), mode="edge")
            out[t, :, j] = np.convolve(x, k, "valid")
    return out


def combine(F, a):
    G = F.copy()
    for t in range(1, F.shape[0]):
        G[t, :-1] = a * F[t, :-1] + (1 - a) * G[t - 1, 1:]
    return G


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    dr, ur = A["d"].astype(float), A["u"].astype(float)
    sd = dr[valid].std(); d, u = dr / sd, ur / ur[valid].std()
    X = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)["X"].astype(float)
    Xs = X / X[valid].std(0)
    onCL = A["onCL"].astype(int) - 1
    fold = A["fold"].astype(int); Dmean = A["Dmean"].astype(float)
    pre, N, Hp = int(A["pre"]), int(A["N"]), int(A["Hp"])
    T, nT = d.size, onCL.size
    stim = np.zeros(T, bool)
    CFG = {f"L{L}_lam{lam:g}": dict(L=L, lam=lam) for L in (5, 10, 20) for lam in (100.0, 1e3)}
    CFG.update({"L10_lam100_Q10": dict(L=10, lam=100.0, Q=10), "L10_lam100_Q70": dict(L=10, lam=100.0, Q=70)})

    def win(ons, lo, hi):
        mk = np.zeros(T, bool)
        for o in ons:
            mk[max(0, o + lo): min(T, o + hi + 1)] = True
        return mk
    F = {k: np.full((N, Hp, nT), np.nan) for k in CFG}
    rel_idx = pre + np.arange(1, N + 1)[:, None] + np.arange(Hp)[None, :]
    for f in np.unique(fold):
        te = np.flatnonzero(fold == f)
        ok = valid & ~win(onCL[te], -pre - HIST, N + Hp + HIST)
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(HIST, T - Hp - 1)
        rows = t[(cs[t + Hp + 1] - cs[t - HIST + 1]) == 0]
        for k, cfg in CFG.items():
            m = Model(dict(BASE, **cfg), d, Xs, u, rows).fit(rows, stim)
            for j in te:
                F[k][:, :, j] = predict_hold(m, onCL[j] + np.arange(N), Hp) * sd - Dmean[np.minimum(rel_idx, Dmean.size - 1)]
        print(f"[VARX-TUNE] fold {f} done", flush=True)
    base = F["L10_lam100"]
    F.update({"leadMA3": lead_ma(base, 3), "leadMA5": lead_ma(base, 5), "combA5": combine(base, 0.5), "combA3": combine(base, 0.3)})
    savemat(DATA / f"ctrl_mpc_varx_tune_{sess}.mat", {"F": F, "fold": fold.astype(float), "names": np.array(list(F), dtype=object)},
            do_compression=True)
    print(f"[VARX-TUNE] {len(F)} variants -> ctrl_mpc_varx_tune_{sess}.mat", flush=True)


if __name__ == "__main__":
    main(*sys.argv[1:])
