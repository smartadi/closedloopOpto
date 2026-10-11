"""Audit of the direct-prediction MPC result (user 2026-10-10: "seems too good to be true, can we review").

Checks, all on the recorded session (no simulation):
  T1 rig latency   which past y the rig's recorded command u(t+1) actually depends on. On CL trials regress
                   Delta u(t+1) on e(t-k) (k = 0..4); the rig's PI uses e at its own latency, so the lag with the
                   dominant coefficient is the information the rig had. The simulated MPC uses y(t) for u(t+1).
  T2 laser delay   when y first responds to the laser in index terms: OL trial-average y around onset vs the
                   recorded command; first frame where y departs from its pre-onset level.
  T3 learned G     the VARX's laser -> y impulse response at leads 1..5 (from mpc_direct.py's saved G).
Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_direct_audit.py [sess]
"""
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
REF = -5.0


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    y, u = A["y"].astype(float), A["u"].astype(float)
    onCL, onOL = A["onCL"].astype(int) - 1, A["onOL"].astype(int) - 1
    N, Fs = int(A["N"]), float(A["Fs"])

    # ---- T1: rig latency -------------------------------------------------------------------------
    e = y - REF
    rows = np.concatenate([o + np.arange(10, N - 1) for o in onCL])          # inside the CL window, past onset transient
    du = u[rows + 1] - u[rows]
    print("[AUDIT T1] corr( u(t+1)-u(t) , e(t-k) ) on CL trials:")
    for k in range(0, 6):
        print(f"           k={k}: r = {np.corrcoef(du, e[rows - k])[0, 1]:+.3f}")
    X = np.column_stack([e[rows - k] for k in range(6)] + [np.ones(rows.size)])
    b = np.linalg.lstsq(X, du, rcond=None)[0]
    print("[AUDIT T1] joint regression of Delta u(t+1) on e(t..t-5): " + " ".join(f"{v:+.3f}" for v in b[:6]))
    # level form: u(t+1) on e(t-k) (P term) -- report the best single lag by R^2
    for k in range(0, 6):
        Xk = np.column_stack([e[rows - k], np.ones(rows.size)]); r = u[rows + 1] - Xk @ np.linalg.lstsq(Xk, u[rows + 1], rcond=None)[0]
        print(f"           level u(t+1) ~ e(t-{k}): R^2 = {1 - r.var() / u[rows + 1].var():.3f}")

    # T1b: fit the rig's own PI law  u(t+1) = c + Kp e(t-d) + Ki' sum_{j<M} e(t-d-j)  for each lag d
    M = 105; cs = np.concatenate([[0.0], np.cumsum(e)])
    print("[AUDIT T1b] rig PI law fitted at lag d (u(t+1) from e up to t-d), CL rows, unsaturated only:")
    uns = rows[(u[rows + 1] > 0.02) & (u[rows + 1] < u[rows + 1].max() - 0.02)]
    for d in range(0, 5):
        t = uns - d; I = cs[t + 1] - cs[t + 1 - M]
        Xd = np.column_stack([e[t], I, np.ones(t.size)]); bd = np.linalg.lstsq(Xd, u[uns + 1], rcond=None)[0]
        r = u[uns + 1] - Xd @ bd
        print(f"           d={d}: R^2 = {1 - r.var() / u[uns + 1].var():.4f}  Kp {bd[0]:+.3f}  Ki' {bd[1]:+.4f}")

    # ---- T2: physical delay in index terms ----------------------------------------------------------
    pre = 10
    Y = np.stack([y[o - pre:o + 12] for o in onOL]); U = np.stack([u[o - pre:o + 12] for o in onOL])
    ym, um = Y.mean(0), U.mean(0); base = ym[:pre].mean(); sd = Y[:, :pre].std()
    print("[AUDIT T2] OL trial average around onset (index 0 = onset frame):")
    print("           k   :", " ".join(f"{k:6d}" for k in range(-3, 10)))
    print("           u   :", " ".join(f"{um[pre + k]:6.2f}" for k in range(-3, 10)))
    print("           y-b :", " ".join(f"{ym[pre + k] - base:6.2f}" for k in range(-3, 10)))
    k_u = int(np.argmax(um[pre:] > 0.5 * um[pre:].max()))
    k_y = int(np.argmax(ym[pre:] - base < -0.25 * abs((ym[pre:] - base).min())))
    print(f"           laser first >50% at k={k_u}; y first beyond 25% of its dip at k={k_y}  -> delay {k_y - k_u} frames")

    # ---- T3: learned laser response -----------------------------------------------------------------
    try:
        G = loadmat(DATA / f"mpc_direct_{sess}_lam01.mat", squeeze_me=True)["G"]
        g = G[:, 0]
        print("[AUDIT T3] VARX laser->y impulse response (y(t+j) per unit u(t+1)), j = 1..6: "
              + " ".join(f"{v:+.3f}" for v in g[:6]) + f" | DC {g.sum():+.2f}")
    except FileNotFoundError:
        print("[AUDIT T3] no mpc_direct_*_lam01.mat")


if __name__ == "__main__":
    main(*sys.argv[1:])
