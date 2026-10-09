"""MPC that predicts the controlled signal DIRECTLY with the VARX -- no disturbance proxy (user 2026-10-09: "we never
wanted to use the d ... get away from disturbance, just directly predict and play MPC").

MODEL   delay-embedded VARX on z = [controlled spot y (rig online dF/F), 100 brain spots], L = 10 lags, Q = 35 laser
        lags, ridge lambda = 100 (mpc_pred200_sweep.Model). Trained on EVERY valid frame -- spontaneous stretches
        between trials, OL trials and CL trials -- except the test fold's CL-trial windows (5 CL folds, as before).
MPC     at frame t (y(t) observed) choose U = u(t+1..t+Hp). The VARX is affine in the future laser, so
        y_hat(t+1..t+Hp) = f(t) + G U  with f = free response (future laser 0) and G = the model's laser->y impulse
        response (time-invariant). Cost sum (y_hat - ref)^2 + r (U - uss)^2 + rd ||Delta U||^2, 0 <= U <= u_max
        (bounded least squares). Apply U(1), observe, repeat. Hp = 35 (1 s), r = 1e-3, rd in {0.1, 1, 10}.
WORLD   no separate plant model, so the stand-in for the brain is the VARX fitted on ALL valid data, driven by that
        trial's recorded one-step innovations e(t+1) = z(t+1) - VARX(z history, recorded laser): under the recorded
        laser it reproduces the recording exactly (asserted); under another laser the activity responds through the
        model's laser dynamics and the innovations (what nobody could predict) are replayed. The controller's own
        model is the fold model (never saw the test trial).
COMPARE PI in the same world (gains re-tuned there by grid, best median -> conservative for MPC); MPC; ORACLE MPC
        (world model + the future innovations known = perfect prediction ceiling); recorded rig CL (reference only).
        RMSE over 1-3 s (ctrl_mpc_lqr rmseWin), ref -5. Simulation -> descriptive only.

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_direct.py [sess]
OUT     data/mpc_direct_<sess>.mat, paper/images/mpc_arx/mpc_direct_<sess>.png, mpc_direct_examples_<sess>.png
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat
from scipy.optimize import lsq_linear

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_pred200_sweep import Model, BASE  # noqa: E402

HERE = Path(__file__).resolve().parent
DATA, FIG = HERE / "data", HERE.parent / "paper" / "images" / "mpc_arx"
CFG = dict(L=10, lam=100.0, Q=35)
HP, REF, R_U, HIST = 35, -5.0, 1e-3, 70
RD_GRID = (0.1, 1.0, 10.0)


class VX:
    """VARX weights + helpers in physical units for y (index 0) and u."""
    def __init__(self, W, L, Q, sz, su):
        self.W, self.L, self.Q, self.sz, self.su = W, L, Q, sz, su
        W0 = W.copy(); W0[-1] = 0
        self.G = np.zeros((HP, HP))                                  # y(t+j) per unit u(t+i), physical units
        for i in range(HP):
            uf = np.zeros(Q - 1 + HP); uf[Q - 1 + i] = 1.0
            self.G[:, i] = self._roll(W0, np.zeros((L, W.shape[1])), uf, HP)[:, 0] * sz[0] / su

    def _roll(self, W, zh, uf, H, innov=None):
        out = np.empty((H, W.shape[1])); zh = zh.copy()
        for h in range(H):
            nxt = np.concatenate([zh.ravel(), uf[h:h + self.Q][::-1], [1.0]]) @ W
            if innov is not None:
                nxt = nxt + innov[h]
            out[h] = nxt; zh = np.vstack([nxt[None], zh[:-1]])
        return out

    def step(self, zh, uh):
        """one-step prediction z(t+1) from zh (L x nC, newest first) and uh = [u(t+1), u(t), ...] (scaled)."""
        return np.concatenate([zh.ravel(), uh, [1.0]]) @ self.W

    def free(self, zh, u_past, innov=None):
        """y_hat(t+1..t+HP) with the future laser = 0; u_past = scaled u(t-Q+2..t) (Q-1 values)."""
        uf = np.concatenate([u_past, np.zeros(HP)])
        return self._roll(self.W, zh, uf, HP, innov)[:, 0] * self.sz[0]


def mpc_solve(m, f, u_prev, uss, umax, rd):
    D = np.eye(HP) - np.eye(HP, k=-1)
    Aq = np.vstack([m.G, np.sqrt(R_U) * np.eye(HP), np.sqrt(rd) * D])
    e0 = np.zeros(HP); e0[0] = u_prev
    bq = np.concatenate([REF - f, np.sqrt(R_U) * uss * np.ones(HP), np.sqrt(rd) * e0])
    return lsq_linear(Aq, bq, bounds=(0.0, umax), method="bvls").x


def main(sess="AL_0033_0226_e2", world_cfg=None, sig_g=0.0, tag=""):
    """world_cfg: VARX config of the WORLD (default = the controller's CFG); sig_g: per-trial lognormal laser-gain
    error of the world (robustness, 2026-10-09). tag != "" -> robustness run: no figures/files, returns the summary."""
    wcfg = dict(CFG, **(world_cfg or {}))
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    yr, ur = A["y"].astype(float), A["u"].astype(float)
    X = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)["X"].astype(float)
    Zr = np.column_stack([yr, X]); sz = Zr[valid].std(0); su = ur[valid].std()
    Z, u = Zr / sz, ur / su
    onCL, fold = A["onCL"].astype(int) - 1, A["fold"].astype(int)
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nT, L, Q = Z.shape[0], onCL.size, CFG["L"], CFG["Q"]
    win = np.arange(34, N)                                           # 1-3 s after onset (frames o+34..o+104)
    stim = np.zeros(T, bool)
    umax = max(ur[o:o + N].max() for o in onCL)
    uss = np.median(np.concatenate([ur[o + win] for o in onCL]))

    def rows_excl(test):
        ok = valid.copy()
        for o in onCL[test]:
            ok[max(0, o - pre - HIST): o + N + HP + HIST] = False
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(HIST, T - HP - 1)
        return t[(cs[t + HP + 1] - cs[t - HIST + 1]) == 0]

    def fit(rows, cfg=CFG):
        mdl = Model(dict(BASE, **cfg), Z[:, 0], Z[:, 1:], u, rows).fit(rows, stim)
        return VX(mdl.W, cfg["L"], cfg["Q"], sz, su)

    world = fit(rows_excl(np.array([], int)), wcfg)
    gk = np.exp(np.sqrt(np.log(1 + sig_g ** 2)) * np.random.default_rng(7).standard_normal(nT) - 0.5 * np.log(1 + sig_g ** 2))
    ctrl = {f: fit(rows_excl(np.flatnonzero(fold == f))) for f in np.unique(fold)}
    print(f"[MPCD] {nT} CL trials | u_max {umax:.2f} | uss {uss:.2f} | world laser->y DC gain {world.G[:, 0].sum():.2f} %/unit "
          f"(peak {world.G[:, 0].min():.2f} at lead {np.argmin(world.G[:, 0]) + 1})", flush=True)

    # innovations of the world model on the recorded data
    E = np.zeros_like(Z)
    for o in onCL:
        for t in range(o - 2, o + N + HP + 1):
            E[t + 1] = Z[t + 1] - world.step(Z[t - np.arange(world.L)], u[t + 1 - np.arange(world.Q)])

    def simulate(k, policy):
        """closed loop in the world model for CL trial k; policy(t, zs, us) -> physical u(t+1)."""
        o = onCL[k]; zs, us = Z.copy(), u.copy()               # copies (cheap enough per trial)
        zs_view = zs; lo, hi = o - 1, o + N - 1
        for t in range(lo, hi):
            us[t + 1] = policy(t, zs_view, us) / su
            zs_view[t + 1] = world.step(zs_view[t - np.arange(world.L)], gk[k] * us[t + 1 - np.arange(world.Q)]) + E[t + 1]
        return zs_view[o:o + N, 0] * sz[0], us[o:o + N] * su

    rmse = lambda yy: np.sqrt(np.mean((yy[win] - REF) ** 2))
    # sanity: recorded laser reproduces the recording
    y0, _ = simulate(0, lambda t, zs, us: u[t + 1] * su)
    if sig_g == 0:
        assert np.allclose(y0, yr[onCL[0]:onCL[0] + N], atol=1e-6), "world replay does not reproduce the recording"
    rec = np.array([rmse(yr[o:o + N]) for o in onCL])

    # PI: re-tuned in the world (grid, best median RMSE)
    def pi_policy(Kp, Ki):
        st = {"s": 0.0}
        def pol(t, zs, us):
            e = zs[t, 0] * sz[0] - REF; st["s"] += e
            return float(np.clip(uss + Kp * e + Ki / Fs * st["s"], 0, umax))
        return pol
    best = (np.inf, None)
    for Kp in (0.0, 0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0):      # widened 2026-10-09 (first grid's best sat on its edge)
        for Ki in (0.0, 0.25, 0.5, 1.0, 2.0, 4.0):
            r = np.median([rmse(simulate(k, pi_policy(Kp, Ki))[0]) for k in range(nT)])
            if r < best[0]:
                best = (r, (Kp, Ki))
    Kp, Ki = best[1]
    PI = [simulate(k, pi_policy(Kp, Ki)) for k in range(nT)]
    rPI = np.array([rmse(p[0]) for p in PI])
    print(f"[MPCD] PI re-tuned in the world: Kp {Kp} Ki {Ki} | median RMSE {np.median(rPI):.3f} (rig CL recorded {np.median(rec):.3f})", flush=True)

    def mpc_policy(m, rd, oracle=False):
        def pol(t, zs, us):
            innov = E[t + 1:t + 1 + HP] if oracle else None
            f = m.free(zs[t - np.arange(m.L)], us[t - m.Q + 2:t + 1], innov)
            return float(mpc_solve(m, f, us[t] * su, uss, umax, rd)[0])
        return pol
    res = {"PI": (PI, rPI)}
    for rd in RD_GRID:
        S = [simulate(k, mpc_policy(ctrl[fold[k]], rd)) for k in range(nT)]
        res[f"MPC rd={rd:g}"] = (S, np.array([rmse(s[0]) for s in S]))
        print(f"[MPCD] MPC (VARX direct, rd={rd:g}): median RMSE {np.median(res[f'MPC rd={rd:g}'][1]):.3f} | "
              f"MPC/PI {np.median(res[f'MPC rd={rd:g}'][1] / rPI):.3f} | beats PI {np.sum(res[f'MPC rd={rd:g}'][1] < rPI)}/{nT}", flush=True)
    if tag:
        out = {n: (np.median(res[n][1] / rPI), int(np.sum(res[n][1] < rPI))) for n in res if n != "PI"}
        print(f"[MPCD-{tag}] PI Kp {Kp} Ki {Ki} RMSE {np.median(rPI):.3f} | " + " | ".join(f"{n} {v[0]:.3f} ({v[1]}/{nT})" for n, v in out.items()), flush=True)
        return out
    S = [simulate(k, mpc_policy(world, 1.0, oracle=True)) for k in range(nT)]
    res["ORACLE MPC rd=1"] = (S, np.array([rmse(s[0]) for s in S]))
    print(f"[MPCD] ORACLE MPC (future innovations known): MPC/PI {np.median(res['ORACLE MPC rd=1'][1] / rPI):.3f}", flush=True)

    # prediction quality of the controller models on the CL trials, conditional on the recorded future laser
    r2 = {}
    for Lh in (3, 7):
        tg, fc = [], []
        for k in range(nT):
            m = ctrl[fold[k]]; o = onCL[k]
            for t in range(o, o + N - Lh):
                uf = u[t - Q + 2:t + 1 + HP]
                fc.append(m._roll(m.W, Z[t - np.arange(L)], uf, Lh)[-1, 0] * sz[0]); tg.append(yr[t + Lh])
        tg, fc = np.array(tg), np.array(fc)
        r2[Lh] = 1 - np.sum((tg - fc) ** 2) / np.sum((tg - tg.mean()) ** 2)
    print(f"[MPCD] controller-model R^2 of y on CL trials (recorded future laser): 86 ms {r2[3]:.3f} | 200 ms {r2[7]:.3f}", flush=True)

    # ---- figures ------------------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    names = list(res)
    fig, ax = plt.subplots(1, 2, figsize=(13, 4.5), constrained_layout=True)
    a = ax[0]
    a.plot(world.G[:, 0], "-o", ms=3, color="k"); a.axhline(0, color="0.7", lw=0.6)
    a.set_xlabel("frames after a unit laser step at lead 1 (≈ 29 ms each)"); a.set_ylabel("Δ y (%ΔF/F) per laser unit")
    a.set_title("laser → controlled spot impulse response learned by the VARX (world model)", fontsize=9)
    a = ax[1]
    rat = [np.median(res[n][1] / rPI) for n in names]; bt = [np.sum(res[n][1] < rPI) for n in names]
    cols = ["#1f77b4"] + ["#d62828"] * len(RD_GRID) + ["#c77dff"]
    a.barh(np.arange(len(names)), rat, color=cols); a.axvline(1, color="#1f77b4")
    for i, (v, b) in enumerate(zip(rat, bt)):
        a.text(v + 0.01, i, f"{v:.3f} ({b}/{nT})", va="center", fontsize=8)
    a.set_yticks(np.arange(len(names))); a.set_yticklabels(names); a.invert_yaxis(); a.set_xlim(0, 1.3)
    a.set_xlabel("median RMSE / PI RMSE (1-3 s), 108 CL trials")
    a.set_title(f"direct-prediction MPC in the VARX world | PI re-tuned (Kp {Kp}, Ki {Ki})\n"
                f"model R² of y on CL trials: 86 ms {r2[3]:.2f}, 200 ms {r2[7]:.2f}", fontsize=9)
    fig.savefig(FIG / f"mpc_direct_{sess}.png", dpi=170)

    gain = res["MPC rd=1"][1] - rPI; srt = np.argsort(gain); ex = srt[np.round(np.array([0.25, 0.5, 0.75]) * (nT - 1)).astype(int)]
    tt = np.arange(N) / Fs
    fig, ax = plt.subplots(2, 3, figsize=(16, 7), constrained_layout=True, sharex=True)
    for j, k in enumerate(ex):
        o = onCL[k]
        a = ax[0, j]
        a.plot(tt, yr[o:o + N], color="0.6", lw=1, label=f"recorded rig CL ({rec[k]:.2f})")
        a.plot(tt, PI[k][0], color="#1f77b4", lw=1.2, label=f"PI in world ({rPI[k]:.2f})")
        a.plot(tt, res["MPC rd=1"][0][k][0], color="#d62828", lw=1.4, label=f"MPC, VARX direct ({res['MPC rd=1'][1][k]:.2f})")
        a.plot(tt, res["ORACLE MPC rd=1"][0][k][0], color="#c77dff", lw=1, label=f"oracle MPC ({res['ORACLE MPC rd=1'][1][k]:.2f})")
        a.axhline(REF, color="k", ls="--", lw=0.8); a.axvspan(0, 1, color="0.92", zorder=0)
        a.set_title(f"CL trial {k + 1} (RMSE 1-3 s in legend)", fontsize=9); a.set_ylabel("ΔF/F (%)"); a.legend(fontsize=6.5, frameon=False)
        a = ax[1, j]
        a.plot(tt, ur[o:o + N], color="0.6", lw=1); a.plot(tt, PI[k][1], color="#1f77b4", lw=1.1)
        a.plot(tt, res["MPC rd=1"][0][k][1], color="#d62828", lw=1.3); a.plot(tt, res["ORACLE MPC rd=1"][0][k][1], color="#c77dff", lw=1)
        a.set_xlabel("time from onset (s)"); a.set_ylabel("laser command")
    fig.suptitle("direct-prediction MPC (no disturbance proxy): 25th / 50th / 75th pct trials of MPC − PI", fontsize=10)
    fig.savefig(FIG / f"mpc_direct_examples_{sess}.png", dpi=170)
    savemat(DATA / f"mpc_direct_{sess}.mat", {"names": np.array(names, dtype=object),
            "rmse": np.column_stack([res[n][1] for n in names]), "rec": rec, "Kp": Kp, "Ki": Ki,
            "G": world.G, "r2_86": r2[3], "r2_200": r2[7], "examples": ex + 1})


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "robust":
        sess = sys.argv[2] if len(sys.argv) > 2 else "AL_0033_0226_e2"
        alt = dict(L=20, lam=1e3, Q=70)
        for tg, wc, sg in (("A_same", None, 0.0), ("B_otherworld", alt, 0.0), ("C_gain20", None, 0.2), ("D_both", alt, 0.2)):
            main(sess, wc, sg, tg)
    else:
        main(*sys.argv[1:])
