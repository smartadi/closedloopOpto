#!/usr/bin/env python
"""network_id.py — fit a linear DYNAMICAL NETWORK model to the grid impulse-response tensor.

The grid experiment is a controlled MIMO impulse-response experiment: a known input (single-
frame photostim) is injected at each of 52 nodes and the full-field response is measured, so
the cached tensor H[s, r, t] (cross_response.py) IS the empirical impulse response (Green's
function) from input node s to readout node r — the Markov-parameter data that linear
system-ID consumes.

FEASIBILITY QUESTION: does a single linear network operator reproduce these impulse responses?
We fit the autonomous propagation on the post-pulse decay (t in FIT_WIN, after the input pulse
and before the ~0.716 s ITI contaminates the trial average) as x_dot = A x, i.e. each impulse
response is a trajectory of the SAME network, started from a different node.

Three fits, cheapest -> most structured (all numpy/scipy, no cvxpy):
  1. DMD  — unconstrained discrete propagator M (x_{k+1}=M x_k), the VAR/"GDAR" baseline.
  2. A_un — unconstrained continuous A = argmin ||X_dot - A X|| (directed network).
  3. A_sym— SYMMETRIC-constrained A (undirected, Laplacian-flavored): closed form via a
            Sylvester equation P A + A P = Q. First step toward a proper Laplacian model
            (next: add leak/zero-row-sum + off-diagonal sign + sparsity as a convex program).

Reports free-run (multi-step) prediction R^2, stability, mode timescales, and coupling-vs-
cortical-distance (locality => a Laplacian is well-motivated).

Run:  .venv/Scripts/python.exe bilateral/grid/network_id.py
Outputs -> bilateral/grid/network_png/ (gitignored PNGs).
"""
from pathlib import Path

import numpy as np
import scipy.linalg as sla
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import cross_response as cr

OUTDIR = Path(__file__).resolve().parent / "network_png"
FIT_WIN = (0.08, 0.60)      # s rel. onset: post-pulse autonomous decay, ends before the 0.716 s ITI
PRED_EXTRA = 0.30           # s beyond FIT_WIN to test extrapolation (free-run)


def r2(actual, pred):
    """1 - SS_res/SS_tot over all entries (nan-safe)."""
    a, p = actual.ravel(), pred.ravel()
    m = np.isfinite(a) & np.isfinite(p)
    a, p = a[m], p[m]
    ss = np.sum((a - a.mean()) ** 2)
    return float(1 - np.sum((a - p) ** 2) / ss) if ss > 0 else np.nan


def free_run(Mdisc, x0, nstep):
    """Iterate x_{k+1}=Mdisc x_k for nstep steps from x0; return (nstep+1, nNode)."""
    xs = [x0]
    for _ in range(nstep):
        xs.append(Mdisc @ xs[-1])
    return np.array(xs)


def main():
    OUTDIR.mkdir(exist_ok=True)
    z = cr.load_cached()
    H, sites, window = z["H"], z["sites"], z["window"]        # H (nStim,nReadout,nWin)
    fs = float(z["fs_win"]); dt = 1.0 / fs
    nS = len(sites)
    klo = int(np.argmin(np.abs(window - FIT_WIN[0])))
    khi = int(np.argmin(np.abs(window - FIT_WIN[1])))
    khi_pred = int(np.argmin(np.abs(window - (FIT_WIN[1] + PRED_EXTRA))))
    print(f"{nS} nodes | dt={dt*1e3:.1f} ms | fit t in [{window[klo]:.3f},{window[khi]:.3f}]s "
          f"({khi-klo} steps) | extrapolate to {window[khi_pred]:.3f}s")

    # trajectories: Phi_k[r,s] = H[s,r,k] = state of node r when node s was impulsed.
    # Each stim s is one trajectory of the shared network; stack snapshot pairs across all s,k.
    Phi = np.transpose(H, (2, 1, 0))                          # (nWin, nReadout, nStim)
    X0 = np.concatenate([Phi[k]       for k in range(klo, khi)], axis=1)   # state at k
    X1 = np.concatenate([Phi[k + 1]   for k in range(klo, khi)], axis=1)   # state at k+1
    Xmid = 0.5 * (X0 + X1)
    Xdot = (X1 - X0) / dt
    print(f"snapshot pairs: {X0.shape[1]}  (for a {nS}x{nS} operator)")

    # ---- 1. DMD: unconstrained discrete propagator (VAR/GDAR baseline) ----
    Mdmd = X1 @ np.linalg.pinv(X0)
    A_dmd = sla.logm(Mdmd).real / dt

    # ---- 2. unconstrained continuous A = argmin ||Xdot - A Xmid|| ----
    A_un = np.linalg.lstsq(Xmid.T, Xdot.T, rcond=None)[0].T

    # ---- 3. symmetric-constrained (Laplacian-flavored) A: P A + A P = Q ----
    P = Xmid @ Xmid.T
    Q = Xdot @ Xmid.T + Xmid @ Xdot.T
    A_sym = sla.solve_sylvester(P, P, Q)
    A_sym = 0.5 * (A_sym + A_sym.T)                           # enforce numerically

    models = {
        "DMD (discrete, unconstrained)": Mdmd,
        "A_un (continuous, directed)": sla.expm(A_un * dt),
        "A_sym (continuous, symmetric)": sla.expm(A_sym * dt),
    }

    # ---- evaluation: one-step + free-run (in-window) + extrapolation ----
    print("\n model                              1-step R2   free-run R2   extrapol R2   stable?")
    metrics = {}
    for name, Md in models.items():
        one = r2(X1, Md @ X0)
        fr, ex = [], []
        for s in range(nS):
            x0 = H[s, :, klo]
            traj = free_run(Md, x0, khi_pred - klo)           # (nstep+1, nNode)
            actual = H[s, :, klo:khi_pred + 1].T              # (nstep+1, nNode)
            fr.append(r2(actual[:khi - klo + 1], traj[:khi - klo + 1]))
            ex.append(r2(actual, traj))
        ev = np.linalg.eigvals(Md)
        stable = bool(np.max(np.abs(ev)) <= 1.0 + 1e-6)
        maxabs = float(np.max(np.abs(ev)))
        metrics[name] = dict(one=one, fr=np.nanmedian(fr), ex=np.nanmedian(ex),
                             stable=stable, maxabs=maxabs)
        flag = "yes" if stable else f"NO (max|l|={maxabs:.3f})"
        print(f" {name:34s}  {one:8.3f}   {np.nanmedian(fr):9.3f}   {np.nanmedian(ex):9.3f}   {flag}")

    # continuous poles / timescales from A_un and A_sym
    for nm, A in [("A_un", A_un), ("A_sym", A_sym)]:
        w = np.linalg.eigvals(A)
        tau = -1.0 / w.real
        tau = np.sort(tau[(w.real < 0) & (tau < 100)])[::-1]
        print(f" {nm}: {np.sum(w.real < 0)}/{nS} decaying modes; "
              f"slowest tau {tau[:4].round(3) if len(tau) else '[]'} s; "
              f"symmetry ||A-A^T||/||A|| = {np.linalg.norm(A-A.T)/np.linalg.norm(A):.2f}")

    _figures(H, sites, window, klo, khi, khi_pred, dt, A_un, A_sym, Mdmd, models, metrics)
    print("\nwrote:", OUTDIR)


def _figures(H, sites, window, klo, khi, khi_pred, dt, A_un, A_sym, Mdmd, models, metrics):
    nS = len(sites)
    order = np.lexsort((sites[:, 1], sites[:, 0]))            # by mx then my (hemisphere-grouped)

    # 1) eigen-spectrum (continuous poles, 1/s)
    fig, ax = plt.subplots(1, 2, figsize=(9, 4))
    for a, (nm, A) in zip(ax, [("A_un (directed)", A_un), ("A_sym (symmetric)", A_sym)]):
        w = np.linalg.eigvals(A)
        a.scatter(w.real, w.imag, s=18, c="tab:blue", alpha=0.7)
        a.axvline(0, color="r", lw=0.6, ls="--")
        a.set_xlabel("Re (1/s) — decay rate"); a.set_ylabel("Im (1/s) — osc")
        a.set_title(f"{nm}\n{np.sum(w.real<0)}/{nS} stable modes")
    fig.suptitle("Network eigen-spectrum (continuous poles)")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_eigenspectrum.png", dpi=150); plt.close(fig)

    # 2) A matrices (nodes hemisphere-ordered)
    fig, ax = plt.subplots(1, 2, figsize=(10, 4.6))
    for a, (nm, A) in zip(ax, [("A_un (directed)", A_un), ("A_sym (symmetric)", A_sym)]):
        Ao = A[np.ix_(order, order)]
        v = np.percentile(np.abs(Ao), 98)
        im = a.imshow(Ao, cmap="RdBu_r", vmin=-v, vmax=v)
        a.set_title(f"{nm}  (rows=to, cols=from)"); a.set_xlabel("from node"); a.set_ylabel("to node")
        fig.colorbar(im, ax=a, fraction=0.046, label="1/s")
    fig.suptitle("Identified network operator A (hemisphere-ordered nodes)")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_A_matrix.png", dpi=150); plt.close(fig)

    # 3) coupling vs cortical distance (off-diagonal |A_ij| vs |site_i - site_j| mm)
    D = np.linalg.norm(sites[:, None, :] - sites[None, :, :], axis=2)
    off = ~np.eye(nS, dtype=bool)
    fig, ax = plt.subplots(figsize=(5, 4))
    ax.scatter(D[off], np.abs(A_un[off]), s=6, alpha=0.25, c="tab:blue", label="|A_un|")
    # binned median
    bins = np.linspace(0, D[off].max(), 12)
    bc = 0.5 * (bins[:-1] + bins[1:])
    med = [np.median(np.abs(A_un[off])[(D[off] >= bins[i]) & (D[off] < bins[i + 1])])
           for i in range(len(bins) - 1)]
    ax.plot(bc, med, "k-o", lw=1.5, ms=4, label="binned median")
    ax.set_xlabel("inter-node cortical distance (mm)"); ax.set_ylabel("|A_ij| (1/s)")
    ax.set_title("Coupling vs distance (locality => Laplacian OK)"); ax.legend(fontsize=8, frameon=False)
    fig.tight_layout(); fig.savefig(OUTDIR / "net_coupling_distance.png", dpi=150); plt.close(fig)

    # 4) example free-run vs actual (3 stims, readout at stim-site + 2 strongest targets)
    Md = models["A_sym (continuous, symmetric)"]
    tt = window[klo:khi_pred + 1]
    ex_stims = [np.argmax([np.abs(H[s, s, klo:khi]).max() for s in range(nS)])]  # strongest self
    rng = np.linspace(0, nS - 1, 4).astype(int)[1:3]
    ex_stims += list(rng)
    fig, axs = plt.subplots(1, len(ex_stims), figsize=(4 * len(ex_stims), 3.4), sharex=True)
    for a, s in zip(np.atleast_1d(axs), ex_stims):
        traj = free_run(Md, H[s, :, klo], khi_pred - klo)
        tgt = [s] + list(np.argsort(-np.abs(H[s, :, khi]))[:2])
        for r in tgt:
            a.plot(tt, H[s, r, klo:khi_pred + 1] * 100, lw=1.6, label=f"node {r} actual")
            a.plot(tt, traj[:, r] * 100, "--", lw=1.2, color=a.lines[-1].get_color())
        a.axvline(window[khi], color="0.5", lw=0.6, ls=":")
        a.set_title(f"stim ({sites[s,0]:+.1f},{sites[s,1]:+.0f})"); a.set_xlabel("t (s)")
        a.set_ylabel("dF/F %"); a.legend(fontsize=6, frameon=False)
    fig.suptitle("Free-run (dashed) vs actual (solid); dotted = fit-window end")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_freerun_examples.png", dpi=150); plt.close(fig)

    # 5) top symmetric modes on the grid
    w, V = np.linalg.eigh(A_sym)                              # ascending (most negative first)
    slow = np.argsort(w)[::-1][:4]                            # slowest (least negative) modes
    fig, axs = plt.subplots(1, 4, figsize=(14, 3.6))
    for a, mi in zip(axs, slow):
        vec = V[:, mi].real
        sc = a.scatter(sites[:, 0], sites[:, 1], c=vec, cmap="RdBu_r", s=120,
                       vmin=-np.abs(vec).max(), vmax=np.abs(vec).max(), ec="k", lw=0.3)
        a.set_aspect("equal"); a.set_title(f"mode: tau={-1/w[mi]:.2f}s"); a.set_xticks([]); a.set_yticks([])
        fig.colorbar(sc, ax=a, fraction=0.046)
    fig.suptitle("Slowest symmetric network modes (spatial eigenvectors on the grid)")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_modes.png", dpi=150); plt.close(fig)


if __name__ == "__main__":
    main()
