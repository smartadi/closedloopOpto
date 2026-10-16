"""Validation landscape for the VARX with EQUAL cortex / laser history, L = Q (user 2026-10-16: 1 s for both).
Validation data only: fold-1 training rows, chronologically last 20 % (mpc_varx_embed protocol); iterated forecasts
of the controlled site at 86 and 200 ms. Rows use the largest Q so every setting is scored on the same frames.
Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_varx_lq_sweep.py
OUT     data/mpc_varx_lq_sweep_AL_0033_0226_e2.mat (supp VARX figure, panel E)
"""
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mpc_varx_embed as E  # noqa: E402

LQ_GRID, LAMS = [5, 10, 20, 35], [10, 100, 1000, 10000]
sess = "AL_0033_0226_e2"; DATA = E.DATA
A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
Wb = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)
valid = A["valid"].astype(bool); yr, ur, X = A["y"].astype(float), A["u"].astype(float), Wb["X"].astype(float)
Z = np.column_stack([yr / yr[valid].std(), X / X[valid].std(0)]); u = ur / ur[valid].std()
onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
pre, N = int(A["pre"]), int(A["N"]); T, nO = yr.size, onOL.size
fold = np.random.default_rng(7).permutation(np.arange(nO) % 5) + 1


def win(ons, lo, hi):
    m = np.zeros(T, bool)
    for o in ons:
        m[max(0, o + lo): min(T, o + hi + 1)] = True
    return m


spont = ~(win(onOL, -pre, N + E.POST) | win(onCL, -pre, N + E.POST))
te, tr = np.flatnonzero(fold == 1), np.flatnonzero(fold != 1)
ok = (spont | win(onOL[tr], -pre, N + E.POST)) & ~win(onOL[te], -pre - E.PAD, N + E.POST + E.HMAX) & valid
cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(E.PAD, T - E.HMAX - 1)
rows1 = t[(cs[t + max(LQ_GRID) + 2] - cs[t - E.PAD + 1]) == 0]
cut = rows1[int((1 - E.VAL_FRAC) * rows1.size)]; r_tr, r_va = rows1[rows1 < cut - E.HMAX], rows1[rows1 >= cut]
vo = r_va[::7]; vo = vo[vo + 8 < T]; yv = Z[vo[:, None] + np.arange(1, 8), 0]
R = []
for L in LQ_GRID:
    E.Q = L                                                   # embed's phi / iterate read E.Q
    G, B = E.fit(Z, u, r_tr, L, 0)
    for lam in LAMS:
        fc = E.iterate(Z, u, vo, E.solve(G, B, lam), L, 7)
        R.append([L, lam, E.r2(yv[:, 2], fc[:, 2]), E.r2(yv[:, 6], fc[:, 6])])
        print(f"L=Q={L} lambda={lam:g}: val R2 86 ms {R[-1][2]:.3f} | 200 ms {R[-1][3]:.3f}", flush=True)
savemat(DATA / f"mpc_varx_lq_sweep_{sess}.mat", {"R": np.array(R), "cols": np.array(["LQ", "lam", "r2_86", "r2_200"], dtype=object)})
