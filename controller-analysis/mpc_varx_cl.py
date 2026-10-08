"""Delay-embedded VARX as the MPC disturbance forecaster on the CL trials (user 2026-10-08: "use our VARX in the MPC
and compare").

Target = the MPC's disturbance d = y - plant(u) (ctrl_mpc_arx_export.m), so the state is z = [d, brain inputs]:
  varx      d + 100 brain spots, L = 10, lambda = 100, Q = 35 laser lags (= the held-out-OL / Lu-protocol winner)
  varx_svd  d + 50 SVD temporal components, L = 5, lambda = 1e3 (the stim-trial-selected config)
Iterated 35 leads. The FUTURE laser command is the MPC's own decision, so inside each forecast it is HELD at its
last value (same convention as pyarx). Same 5 CL folds as ctrl_mpc_forecasters (paired); training = everything
valid except the test fold's CL-trial windows (spont + all OL + other CL), as mpc_arx_wb2s 'cl'.
Output = departure d_hat - Dmean, F.<model>(t, j, k), origin t = 1..N (last observed frame onCL + t - 1).

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_varx_cl.py [sess]
OUT     data/ctrl_mpc_varx_out_<sess>.mat  -> ctrl_mpc_lqr('fcstFile','ctrl_mpc_varx_out_%s.mat','fcstModel','varx')
"""
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_pred200_sweep import Model, BASE  # noqa: E402

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
HIST = 70


def predict_hold(m, org, H):
    """Model.predict, but laser samples after the origin are replaced by the laser at the origin."""
    c = m.c
    hist = m.Zi[org[:, None] - np.arange(c["L"])]
    out = np.empty((org.size, H))
    for h in range(H):
        idx = np.minimum(org[:, None] + h + 1 - np.arange(c["Q"]), org[:, None])
        A = np.hstack([hist.reshape(org.size, -1), m.u[idx], np.ones((org.size, 1))])
        nxt = A @ m.W
        out[:, h] = nxt[:, 0]
        hist = np.concatenate([nxt[:, None, :], hist[:, :-1, :]], axis=1)
    return out


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    dr, ur = A["d"].astype(float), A["u"].astype(float)
    sd = dr[valid].std(); d, u = dr / sd, ur / ur[valid].std()
    X = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)["X"].astype(float)
    V = loadmat(DATA / f"ctrl_mpc_svd_in_{sess}_k200.mat", squeeze_me=True)["V"].astype(float)[:, :50]
    INP = {"varx": (X / X[valid].std(0), dict(L=10, lam=100.0)), "varx_svd": (V / V[valid].std(0), dict(L=5, lam=1e3))}
    onCL = A["onCL"].astype(int) - 1
    fold = A["fold"].astype(int); Dmean = A["Dmean"].astype(float)
    pre, N, Hp = int(A["pre"]), int(A["N"]), int(A["Hp"])
    T, nT = d.size, onCL.size
    stim = np.zeros(T, bool)

    def win(ons, lo, hi):
        mk = np.zeros(T, bool)
        for o in ons:
            mk[max(0, o + lo): min(T, o + hi + 1)] = True
        return mk
    Fout = {k: np.full((N, Hp, nT), np.nan) for k in INP}
    rel_idx = pre + np.arange(1, N + 1)[:, None] + np.arange(Hp)[None, :]
    for f in np.unique(fold):
        te = np.flatnonzero(fold == f)
        ok = valid & ~win(onCL[te], -pre - HIST, N + Hp + HIST)
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(HIST, T - Hp - 1)
        rows = t[(cs[t + Hp + 1] - cs[t - HIST + 1]) == 0]
        for k, (Xi, cfg) in INP.items():
            m = Model(dict(BASE, **cfg), d, Xi, u, rows).fit(rows, stim)
            for j in te:
                fc = predict_hold(m, onCL[j] + np.arange(N), Hp) * sd
                Fout[k][:, :, j] = fc - Dmean[np.minimum(rel_idx, Dmean.size - 1)]
        print(f"[VARX-CL] fold {f}: {rows.size} training rows, {te.size} test CL trials", flush=True)
    savemat(DATA / f"ctrl_mpc_varx_out_{sess}.mat", {"F": Fout, "fold": fold.astype(float),
            "source": "mpc_varx_cl.py: delay-embedded VARX on [d, brain inputs], laser held after origin"},
            do_compression=True)
    print(f"[VARX-CL] -> {DATA / f'ctrl_mpc_varx_out_{sess}.mat'}")


if __name__ == "__main__":
    main(*sys.argv[1:])
