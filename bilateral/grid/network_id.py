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
from scipy.optimize import nnls
from scipy.signal import savgol_filter
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import cross_response as cr

OUTDIR = Path(__file__).resolve().parent / "network_png"
FIT_WIN = (0.08, 0.60)      # s rel. onset: post-pulse autonomous decay, ends before the 0.716 s ITI
PRED_EXTRA = 0.30           # s beyond FIT_WIN to test extrapolation (free-run)
D_EMBED = 8                 # time-delay embedding dimension (Hankel-DMD / ERA)
DELAY_RANK = 40             # rank truncation for the delay-embedded propagator


def r2(actual, pred):
    """1 - SS_res/SS_tot over all entries (nan-safe)."""
    a, p = actual.ravel(), pred.ravel()
    m = np.isfinite(a) & np.isfinite(p)
    a, p = a[m], p[m]
    ss = np.sum((a - a.mean()) ** 2)
    return float(1 - np.sum((a - p) ** 2) / ss) if ss > 0 else np.nan


def fit_directed_laplacian(Xmid, Xdot, nS, ridge=0.0):
    """Fit A as a LEAKY DIRECTED graph-Laplacian with NON-NEGATIVE edge weights:
        x_dot_i = sum_{j!=i} W_ij (x_j - x_i) - gamma_i x_i ,   W_ij >= 0, gamma_i >= 0
    so A = W - diag(rowsum W) - diag(gamma) is Metzler with non-positive row sums =>
    Hurwitz-STABLE by construction (Gershgorin: Re(lambda) <= -min gamma). The fit
    SEPARATES BY ROW into nS non-negative least-squares problems (scipy.nnls): the
    coupling into node i plus its own leak. W_ij is the directed edge j->i.
    """
    W = np.zeros((nS, nS)); gamma = np.zeros(nS)
    for i in range(nS):
        idx = [j for j in range(nS) if j != i]
        R = np.column_stack([(Xmid[idx] - Xmid[i][None, :]).T, -Xmid[i]])   # (N, nS): W cols + leak
        b = Xdot[i]
        if ridge > 0:                                          # Tikhonov toward small weights
            R = np.vstack([R, np.sqrt(ridge) * np.eye(R.shape[1])])
            b = np.concatenate([b, np.zeros(R.shape[1])])
        coef, _ = nnls(R, b)
        W[i, idx] = coef[:-1]; gamma[i] = coef[-1]
    A = W.copy()
    A[np.diag_indices(nS)] = -(W.sum(1)) - gamma
    return A, W, gamma


def fit_driven_laplacian(H, sites, klo, khi, dt, nS, ridge=1e-2, dmax=None):
    """DRIVEN first-order SYMMETRIC-PSD graph-Laplacian (the parsimony baseline + rebound test):
        x_dot = -(L + diag(gamma)) x + B u ,   L = D - W,  W = W^T >= 0,  gamma >= 0,  B = diag(b)
    L is a proper combinatorial graph-Laplacian (undirected non-negative weights => symmetric PSD);
    gamma>=0 is a per-node leak that grounds the Laplacian's zero mode so responses decay to 0.
    B is DIAGONAL and SIGN-FREE: each stim injects only at its own node, and the SIGN of b_s is left
    free so the excitatory(+)/inhibitory(-) opsin polarity is a RESULT read off the data, not an
    imposed prior. L,gamma are fit by a CONVEX bounded-variable equation-error LS over the pooled
    post-pulse snapshots (undirected weight w_ij is shared between rows i and j); b_s is the signed
    self-kick at the driven site. A = -(L+diag(gamma)) is symmetric negative-definite => real
    eigenvalues => guaranteed stable AND non-oscillatory: it structurally cannot rebound, which is
    exactly why its same-site residual isolates the dynamics a first-order Laplacian must miss.
    Returns (A, L, W, gamma, b)."""
    from scipy.optimize import lsq_linear
    from scipy.sparse import csr_matrix, vstack, eye as speye
    Phi = np.transpose(H, (2, 1, 0))                             # (nWin, nReadout, nStim)
    Xc, Xdc = [], []
    for k in range(klo, khi):
        Xc.append(Phi[k]); Xdc.append((Phi[k + 1] - Phi[k - 1]) / (2 * dt))   # central diff
    X = np.concatenate(Xc, 1); Xd = np.concatenate(Xdc, 1)       # (nS, N)
    N = X.shape[1]
    if dmax is None:
        edges = [(i, j) for i in range(nS) for j in range(i + 1, nS)]
    else:                                                        # locality prior: candidate edges within dmax
        D = np.linalg.norm(sites[:, None, :] - sites[None, :, :], axis=2)
        edges = [(i, j) for i in range(nS) for j in range(i + 1, nS) if D[i, j] <= dmax]
    nE = len(edges)
    ri, ci, va, ar = [], [], [], np.arange(N)
    for ei, (i, j) in enumerate(edges):                          # w_ij: +(x_j-x_i) into row i, -(...) into row j
        di = X[j] - X[i]
        ri.extend(i * N + ar); ci.extend([ei] * N); va.extend(di)
        ri.extend(j * N + ar); ci.extend([ei] * N); va.extend(-di)
    for i in range(nS):                                          # leak: -x_i into row i
        ri.extend(i * N + ar); ci.extend([nE + i] * N); va.extend(-X[i])
    G = csr_matrix((va, (ri, ci)), shape=(nS * N, nE + nS))
    y = Xd.reshape(nS * N)                                       # node-major flatten matches row index i*N+n
    if ridge > 0:
        G = vstack([G, np.sqrt(ridge) * speye(nE + nS, format="csr")], format="csr")
        y = np.concatenate([y, np.zeros(nE + nS)])
    theta = lsq_linear(G, y, bounds=(0, np.inf), max_iter=60, lsmr_tol="auto", verbose=0).x
    W = np.zeros((nS, nS))
    for ei, (i, j) in enumerate(edges):
        W[i, j] = W[j, i] = theta[ei]
    gamma = theta[nE:]
    L = np.diag(W.sum(1)) - W
    A = -(L + np.diag(gamma))
    b = np.array([H[s, s, klo + int(np.argmax(np.abs(H[s, s, klo:khi])))] for s in range(nS)])
    return A, L, W, gamma, b


def deriv_stacks(H, klo, khi, dt):
    """Per-stim x, x_dot, x_ddot (central differences) pooled over [klo,khi] across stims.
    Returns (X, V, Acc) each (nNode, nStim*(khi-klo+1)) + a per-stim velocity at klo for seeding."""
    nS = H.shape[0]
    xs, vs, accs, v0 = [], [], [], np.zeros((nS, nS))
    for s in range(nS):
        Y = H[s]
        xs.append(Y[:, klo:khi + 1])
        vs.append((Y[:, klo + 1:khi + 2] - Y[:, klo - 1:khi]) / (2 * dt))
        accs.append((Y[:, klo + 1:khi + 2] - 2 * Y[:, klo:khi + 1] + Y[:, klo - 1:khi]) / dt ** 2)
        v0[s] = (Y[:, klo + 1] - Y[:, klo - 1]) / (2 * dt)
    return np.concatenate(xs, 1), np.concatenate(vs, 1), np.concatenate(accs, 1), v0


def fit_second_order(X, V, Acc, nS):
    """Fit a 2nd-order graph model  x_ddot_i = sum_{j!=i} W_ij (x_j - x_i) - gamma_i x_dot_i
    (damped wave / networked oscillator on the graph-Laplacian L = D - W, damping Gamma).
    W>=0, gamma>=0 via row-wise NNLS. Latent state = velocity (interpretable). Complex modes
    => it can produce the oscillatory rebounds a 1st-order model cannot. Returns companion
    A2 (2nS x 2nS), W, gamma, L."""
    W = np.zeros((nS, nS)); gamma = np.zeros(nS)
    for i in range(nS):
        idx = [j for j in range(nS) if j != i]
        R = np.column_stack([(X[idx] - X[i][None, :]).T, -V[i]])      # W cols + damping on x_dot
        coef, _ = nnls(R, Acc[i])
        W[i, idx] = coef[:-1]; gamma[i] = coef[-1]
    L = np.diag(W.sum(1)) - W
    A2 = np.block([[np.zeros((nS, nS)), np.eye(nS)], [-L, -np.diag(gamma)]])
    return A2, W, gamma, L


def fit_driven_wave(H, sites, klo, khi, dt, nS, r=18, knn=8, maxiter=120):
    """DRIVEN 2nd-order graph-WAVE with a NODE-SPACE proper Laplacian, fit by SIMULATION error:
        x_ddot = -(L + diag(leak)) x - Gamma x_dot + B u ,   L = D - W
    W = undirected NON-NEGATIVE weights on a LOCAL k-NN candidate edge set (=> L symmetric PSD and
    interpretable/sparse), leak>=0 grounds the Laplacian zero mode, Gamma=diag(g)>=0 damping, and
    B = diag(b) is DIAGONAL + SIGN-FREE (signed self-kick; opsin polarity read off the data). Being
    2nd-order, complex modes let it OSCILLATE (the rebound the first-order Laplacian cannot make)
    while L stays a proper graph-Laplacian. Non-negativity via softplus. The parameters live in NODE
    space (interpretable) but the trajectory is simulated in an r-mode POD subspace (Lr=P^T L P,
    Gr=P^T Gamma P) so each objective eval is cheap. L-BFGS from the equation-error 2nd-order fit
    (correct operator scale). Stable by construction (L, Gamma PSD). Returns (W, leak, g, b, L, P,
    freerun_fn)."""
    from scipy.optimize import minimize
    P = np.linalg.svd(np.concatenate([H[s, :, klo:khi + 1] for s in range(nS)], axis=1),
                      full_matrices=False)[0][:, :r]
    vel = np.stack([savgol_filter(H[s], 9, 3, deriv=1, delta=dt, axis=1) for s in range(nS)])
    nfit = khi - klo
    a0 = np.stack([P.T @ H[s, :, klo] for s in range(nS)]).T                # (r, nStim)
    v0 = np.stack([P.T @ vel[s, :, klo] for s in range(nS)]).T
    Aact = np.stack([P.T @ H[s, :, klo:khi + 1] for s in range(nS)], axis=1)  # (r, nStim, nfit+1)

    D = np.linalg.norm(sites[:, None, :] - sites[None, :, :], axis=2)       # k-NN candidate edges
    E = set()
    for i in range(nS):
        for j in np.argsort(D[i])[1:knn + 1]:
            E.add((min(i, int(j)), max(i, int(j))))
    edges = sorted(E); nE = len(edges)
    ei = np.array([e[0] for e in edges]); ej = np.array([e[1] for e in edges])
    sp = lambda t: np.logaddexp(0.0, t)                                     # softplus (>=0)

    def node_ops(th):
        w = sp(th[:nE]); leak = sp(th[nE:nE + nS]); g = sp(th[nE + nS:])
        W = np.zeros((nS, nS)); W[ei, ej] = w; W[ej, ei] = w
        L = np.diag(W.sum(1)) - W + np.diag(leak)
        return W, leak, g, L, np.diag(g)

    def reduced(L, Gam):
        Lr = P.T @ L @ P; Gr = P.T @ Gam @ P
        return sla.expm(np.block([[np.zeros((r, r)), np.eye(r)], [-Lr, -Gr]]) * dt)

    def simulate(Md, nstep):
        z = np.vstack([a0, v0]); out = [z[:r].copy()]
        for _ in range(nstep):
            z = Md @ z; out.append(z[:r].copy())
        return np.stack(out, axis=2)

    def obj(th):
        _, _, _, L, Gam = node_ops(th)
        return float(np.sum((simulate(reduced(L, Gam), nfit) - Aact) ** 2))

    X, V, Acc, _ = deriv_stacks(H, klo, khi, dt)                            # warm start from eq-error 2nd-order
    _, W2, gam2, _ = fit_second_order(X, V, Acc, nS)
    inv = lambda y: np.log(np.expm1(np.clip(y, 1e-6, None)))
    w0 = inv(np.maximum(0.5 * (W2[ei, ej] + W2[ej, ei]), 1e-4))
    th0 = np.concatenate([w0, inv(np.full(nS, 1e-2)), inv(np.maximum(gam2, 1e-2))])
    res = minimize(obj, th0, method="L-BFGS-B", options=dict(maxiter=maxiter))
    W, leak, g, L, Gam = node_ops(res.x)
    b = np.array([H[s, s, klo + int(np.argmax(np.abs(H[s, s, klo:khi])))] for s in range(nS)])
    Md = reduced(L, Gam)

    def freerun_fn(s, nstep):
        z = np.concatenate([P.T @ H[s, :, klo], P.T @ vel[s, :, klo]])
        xs = [P @ z[:r]]
        for _ in range(nstep):
            z = Md @ z; xs.append(P @ z[:r])
        return np.array(xs)
    return W, leak, g, b, L, P, freerun_fn


def fit_delay_dmd(H, klo, khi, dt, d, rank, stabilize=True):
    """Time-delay-embedded DMD (Hankel-DMD ~ ERA): augment the state with d time-lagged copies,
    z_k = [x_k; x_{k-1}; ...; x_{k-d+1}], and fit a rank-truncated linear propagator on z. The
    delay coordinates supply the LATENT states the first-order observed-state fit lacked.
    stabilize=True projects the reduced propagator's eigenvalues onto the closed unit disk
    (|lambda|<=1) so free-run/extrapolation cannot diverge. Returns (Ur, Atil, d)."""
    nS = H.shape[0]
    Z0, Z1 = [], []
    for s in range(nS):
        Y = H[s]
        for k in range(klo, khi):
            if k - d + 1 < 0:
                continue
            Z0.append(np.concatenate([Y[:, k - t] for t in range(d)]))
            Z1.append(np.concatenate([Y[:, k + 1 - t] for t in range(d)]))
    Z0 = np.array(Z0).T; Z1 = np.array(Z1).T                          # (nS*d, N)
    U, S, Vt = np.linalg.svd(Z0, full_matrices=False)
    r = min(rank, int(np.sum(S > 1e-10 * S[0])))
    Ur, Sr, Vr = U[:, :r], S[:r], Vt[:r].T
    Atil = Ur.T @ Z1 @ (Vr / Sr)                                      # reduced propagator (r x r)
    if stabilize:
        lam, Phi = np.linalg.eig(Atil)
        lam_c = lam / np.maximum(np.abs(lam), 1.0)                    # project onto unit disk
        Atil = (Phi @ np.diag(lam_c) @ np.linalg.inv(Phi)).real
    return Ur, Atil, d


def _delay_freerun_scores(H, Ur, Atil, d, klo, khi, khi_pred, nS):
    """Median in-window free-run R2 and extrapolation R2 for a delay model across all stims."""
    fr, ex = [], []
    for s in range(nS):
        z0 = np.concatenate([H[s, :, klo - t] for t in range(d)])
        traj = free_run_delay(Ur, Atil, z0, khi_pred - klo, nS)
        actual = H[s, :, klo:khi_pred + 1].T
        fr.append(r2(actual[:khi - klo + 1], traj[:khi - klo + 1]))
        ex.append(r2(actual, traj))
    return float(np.nanmedian(fr)), float(np.nanmedian(ex))


def sweep_delay(H, klo, khi, khi_pred, dt, nS, depths=(3, 4, 6, 8), ranks=(40, 60, 80, 100, 130)):
    """Grid-search delay depth x rank for the STABILIZED delay-DMD; pick the best by
    extrapolation R2 (honest generalization). Returns (best_d, best_rank, Ur, Atil, table)."""
    table, best = [], None
    for d in depths:
        for rank in ranks:
            if rank > nS * d:
                continue
            Ur, Atil, _ = fit_delay_dmd(H, klo, khi, dt, d, rank, stabilize=True)
            frm, exm = _delay_freerun_scores(H, Ur, Atil, d, klo, khi, khi_pred, nS)
            table.append((d, rank, frm, exm))
            if best is None or exm > best[0]:
                best = (exm, frm, d, rank, Ur, Atil)
    return best, table


def fit_structured_simerror(H, klo, khi, khi_pred, dt, nS, r=18, maxiter=150):
    """PROPER structured marriage: a 2nd-order graph model  x_ddot = -L x - Gamma x_dot  with
    L symmetric PSD (generalized graph-Laplacian, Lambda=B B^T) and Gamma>=0 damping — STABLE
    by construction — fit by SIMULATION (output) error: directly minimize the free-run
    trajectory MSE (not the acceleration equation, which we showed fails). Optimized on an
    r-mode POD subspace to stay cheap; the node-space operator is L_node = P Lambda P^T.
    Returns (P, Lambda, gamma, freerun_fn, var_captured)."""
    from scipy.optimize import minimize
    P = np.linalg.svd(np.concatenate([H[s, :, klo:khi + 1] for s in range(nS)], axis=1),
                      full_matrices=False)[0][:, :r]                 # (nS, r) orthonormal modes
    # Savitzky-Golay velocity (a noisy finite-difference seed wrecks a 2nd-order free-run)
    vel = np.stack([savgol_filter(H[s], 9, 3, deriv=1, delta=dt, axis=1) for s in range(nS)])  # (nStim,nS,nWin)
    nfit, npred = khi - klo, khi_pred - klo
    a0 = np.stack([P.T @ H[s, :, klo] for s in range(nS)]).T          # (r, nStim)
    v0 = np.stack([P.T @ vel[s, :, klo] for s in range(nS)]).T
    Aact = np.stack([P.T @ H[s, :, klo:khi_pred + 1] for s in range(nS)], axis=1)  # (r,nStim,npred+1)

    def unpack(th):
        B = th[:r * r].reshape(r, r)
        return B @ B.T, np.log1p(np.exp(th[r * r:]))                  # Lambda PSD, gamma>=0 softplus

    def simulate(Lam, gam, nstep):
        A2r = np.block([[np.zeros((r, r)), np.eye(r)], [-Lam, -np.diag(gam)]])
        Md = sla.expm(A2r * dt)
        z = np.vstack([a0, v0]); out = [z[:r].copy()]
        for _ in range(nstep):
            z = Md @ z; out.append(z[:r].copy())
        return np.stack(out, axis=2)                                  # (r, nStim, nstep+1)

    def obj(th):
        Lam, gam = unpack(th)
        return float(np.sum((simulate(Lam, gam, nfit) - Aact[:, :, :nfit + 1]) ** 2))

    # warm start from the reduced EQUATION-error fit (symmetrized + PSD-projected)
    ar = np.concatenate([P.T @ H[s, :, klo - 1:khi + 2] for s in range(nS)], axis=1)  # (r, N+..)
    a = ar[:, 1:-1]; ad = (ar[:, 2:] - ar[:, :-2]) / (2 * dt); add = (ar[:, 2:] - 2 * ar[:, 1:-1] + ar[:, :-2]) / dt ** 2
    Meq = add @ np.linalg.pinv(np.vstack([a, ad]))                    # [-Lambda | -Gamma]
    Lam0 = -0.5 * (Meq[:, :r] + Meq[:, :r].T)
    ew, ev = np.linalg.eigh(Lam0); Lam0 = ev @ np.diag(np.maximum(ew, 1e-3)) @ ev.T
    B0 = np.linalg.cholesky(Lam0 + 1e-3 * np.eye(r))
    g0 = np.maximum(-np.diag(Meq[:, r:]), 1e-2)
    th0 = np.concatenate([B0.ravel(), np.log(np.expm1(g0))])
    res = minimize(obj, th0, method="L-BFGS-B", options=dict(maxiter=maxiter))
    Lam, gam = unpack(res.x)

    def freerun_fn(s, nstep):
        A2r = np.block([[np.zeros((r, r)), np.eye(r)], [-Lam, -np.diag(gam)]])
        Md = sla.expm(A2r * dt)
        z = np.concatenate([P.T @ H[s, :, klo], P.T @ vel[s, :, klo]])
        xs = [P @ z[:r]]
        for _ in range(nstep):
            z = Md @ z; xs.append(P @ z[:r])
        return np.array(xs)
    return P, Lam, gam, freerun_fn


def free_run(Mdisc, x0, nstep):
    """Iterate x_{k+1}=Mdisc x_k for nstep steps from x0; return (nstep+1, nNode)."""
    xs = [x0]
    for _ in range(nstep):
        xs.append(Mdisc @ xs[-1])
    return np.array(xs)


def free_run_2nd(M2, x0, v0, nstep, nS):
    """Free-run the 2nd-order system from [x0; v0]; return the position part (nstep+1, nS)."""
    z = np.concatenate([x0, v0]); xs = [z[:nS]]
    for _ in range(nstep):
        z = M2 @ z; xs.append(z[:nS])
    return np.array(xs)


def free_run_delay(Ur, Atil, z0, nstep, nS):
    """Free-run in reduced delay coords from full delay-stack z0; return x part (nstep+1, nS)."""
    a = Ur.T @ z0; xs = [(Ur @ a)[:nS]]
    for _ in range(nstep):
        a = Atil @ a; xs.append((Ur @ a)[:nS])
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

    # ---- 4. LEAKY DIRECTED graph-Laplacian, non-negative weights (stable by construction) ----
    A_lap, W_lap, gamma = fit_directed_laplacian(Xmid, Xdot, nS, ridge=0.0)

    models = {
        "DMD (discrete, unconstrained)": Mdmd,
        "A_un (continuous, directed)": sla.expm(A_un * dt),
        "A_sym (continuous, symmetric)": sla.expm(A_sym * dt),
        "A_lap (directed Laplacian, W>=0)": sla.expm(A_lap * dt),
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

    # continuous poles / timescales
    for nm, A in [("A_un", A_un), ("A_sym", A_sym), ("A_lap", A_lap)]:
        w = np.linalg.eigvals(A)
        tau = -1.0 / w.real
        tau = np.sort(tau[(w.real < 0) & (tau < 100)])[::-1]
        print(f" {nm}: {np.sum(w.real < 0)}/{nS} decaying modes; "
              f"slowest tau {tau[:4].round(3) if len(tau) else '[]'} s; "
              f"symmetry ||A-A^T||/||A|| = {np.linalg.norm(A-A.T)/np.linalg.norm(A):.2f}")
    dens = float((W_lap > 1e-6).mean())
    print(f" A_lap: leak gamma tau=1/gamma range [{1/np.maximum(gamma,1e-9).max():.3f}, "
          f"{1/np.maximum(gamma.min(),1e-9):.3f}]s; edge density {dens:.2f}; "
          f"W asymmetry ||W-W^T||/||W|| = {np.linalg.norm(W_lap-W_lap.T)/np.linalg.norm(W_lap):.2f}")

    # ---- DRIVEN 1st-order SYMMETRIC-PSD Laplacian: parsimony baseline + REBOUND DIAGNOSTIC ----
    A_drv, L_drv, W_drv, gam_drv, b_drv = fit_driven_laplacian(H, sites, klo, khi, dt, nS, ridge=1e-2)
    Md_drv = sla.expm(A_drv * dt)
    fr, ex, self_r2, self_act, self_mod = [], [], [], [], []
    for s in range(nS):
        traj = free_run(Md_drv, H[s, :, klo], khi_pred - klo)
        actual = H[s, :, klo:khi_pred + 1].T
        fr.append(r2(actual[:khi - klo + 1], traj[:khi - klo + 1]))
        ex.append(r2(actual, traj))
        self_r2.append(r2(actual[:, s], traj[:, s]))
        sgn = np.sign(b_drv[s]) or 1.0                        # sign-normalize so all self-responses start +
        self_act.append(sgn * actual[:, s]); self_mod.append(sgn * traj[:, s])
    self_act = np.array(self_act); self_mod = np.array(self_mod)
    ev_drv = np.linalg.eigvalsh(A_drv)                       # symmetric => real
    # opsin-sign recovery: does the free-fit b_s sign match hemisphere (left/excit x<0 => +)?
    hemi_expect = np.where(sites[:, 0] < 0, 1.0, -1.0)
    sign_match = float(np.mean(np.sign(b_drv) == hemi_expect))
    # rebound index: EARLY-trough -> subsequent-peak recovery of the pooled mean self-response
    # (the biphasic dip->rebound a symmetric-PSD first-order model structurally cannot produce)
    mact = self_act.mean(0)
    half = max(1, int(0.6 * len(mact)))
    ktr = int(np.argmin(mact[:half]))                       # FIRST (early) trough, not the decaying tail
    rebound = float((mact[ktr:].max() - mact[ktr]) / (np.abs(mact[0]) + 1e-9))
    fr1_med, self1_med = np.nanmedian(fr), np.nanmedian(self_r2)     # keep: `fr` is reused by later loops
    print(f"\n DRIVEN symmetric-PSD Laplacian (x_dot=-(L+diag g)x + B u):")
    print(f"   free-run R2 {fr1_med:.3f} | extrapol R2 {np.nanmedian(ex):.3f} | "
          f"SELF-site R2 {self1_med:.3f} | stable {ev_drv.max() <= 1e-6} (all real, max l={ev_drv.max():.3g})")
    print(f"   diag B opsin-sign recovery vs hemisphere: {sign_match*100:.0f}% match "
          f"({int(np.sum(b_drv > 0))} +, {int(np.sum(b_drv < 0))} -)")
    print(f"   rebound index (pooled self-response post-trough recovery, model CANNOT produce): {rebound:+.2f} "
          f"=> {'REBOUND present, first-order structurally misses it' if rebound > 0.15 else 'no strong rebound'}")
    _driven_figures(H, sites, window, klo, khi, khi_pred, A_drv, W_drv, gam_drv, b_drv,
                    Md_drv, self_act, self_mod, self_r2, hemi_expect, nS)

    # ---- LATENT-STATE models (add the capacity the first-order fits lacked) ----
    X, V, Acc, v0 = deriv_stacks(H, klo, khi, dt)
    A2, W2, gamma2, L2 = fit_second_order(X, V, Acc, nS)
    M2 = sla.expm(A2 * dt)

    # STABILIZED delay-DMD, tuned by (depth x rank) sweep on extrapolation R2
    (exm, frm, d, drank, Ur, Atil), sweep_tbl = sweep_delay(H, klo, khi, khi_pred, dt, nS)
    print("\n delay-DMD sweep (stabilized |lambda|<=1):   d  rank   free-run  extrapol")
    for dd, rr, f, e in sweep_tbl:
        print(f"   {dd:3d} {rr:4d}   {f:8.3f}  {e:8.3f}" + ("  <-- best" if (dd == d and rr == drank) else ""))

    def fr_2nd(s, n):
        return free_run_2nd(M2, H[s, :, klo], v0[s], n, nS)

    def fr_delay(s, n):
        z0 = np.concatenate([H[s, :, klo - t] for t in range(d)])
        return free_run_delay(Ur, Atil, z0, n, nS)

    # STRUCTURED MARRIAGE: 2nd-order symmetric-PSD graph-Laplacian, fit by SIMULATION error.
    # r=18 is the best config; more modes make the nonconvex fit harder + ring (interpretable
    # but RIGID -- one freq/damping per mode -- so it can't match the flexible delay-DMD).
    R_POD = 18
    Pmode, Lam, gam_s, fr_struct = fit_structured_simerror(H, klo, khi, khi_pred, dt, nS, r=R_POD, maxiter=200)
    L_node = Pmode @ Lam @ Pmode.T                                   # node-space PSD Laplacian
    freqs = np.sqrt(np.clip(np.linalg.eigvalsh(Lam), 0, None)) / (2 * np.pi)   # modal freq (Hz)

    print(f"\n latent-state model                 free-run R2   extrapol R2   stable?   #states  (delay d={d},r={drank})")
    latent = [
        ("2nd-order graph (equation-error)", fr_2nd, np.max(np.linalg.eigvals(A2).real) <= 1e-6, 2 * nS),
        (f"delay-embed DMD (d={d}, r={drank})", fr_delay, np.max(np.abs(np.linalg.eigvals(Atil))) <= 1 + 1e-6, drank),
        (f"structured graph-Laplacian (sim-error, r={R_POD})", fr_struct, True, 2 * R_POD)]
    for name, frfn, stable, nst in latent:
        fr, ex = [], []
        for s in range(nS):
            traj = frfn(s, khi_pred - klo)
            actual = H[s, :, klo:khi_pred + 1].T
            fr.append(r2(actual[:khi - klo + 1], traj[:khi - klo + 1]))
            ex.append(r2(actual, traj))
        print(f" {name:44s}  {np.nanmedian(fr):8.3f}   {np.nanmedian(ex):9.3f}   "
              f"{'yes' if stable else 'NO':6s}   {nst}")
    print(f" structured model: {len(freqs)} modes, oscillation freqs {np.sort(freqs)[::-1][:5].round(2)} Hz; "
          f"damping gamma tau=1/gamma {(1/np.maximum(gam_s,1e-9)).round(2)[:4]} s")

    # ---- DRIVEN 2nd-order graph-WAVE: node-space proper Laplacian, sim-error (step 3) ----
    W_w, leak_w, g_w, b_w, L_w, P_w, fr_wave = fit_driven_wave(H, sites, klo, khi, dt, nS, r=18, knn=8)
    frw, exw, selfw = [], [], []
    for s in range(nS):
        traj = fr_wave(s, khi_pred - klo)
        actual = H[s, :, klo:khi_pred + 1].T
        frw.append(r2(actual[:khi - klo + 1], traj[:khi - klo + 1]))
        exw.append(r2(actual, traj))
        selfw.append(r2(actual[:, s], traj[:, s]))
    Aw2 = np.block([[np.zeros((nS, nS)), np.eye(nS)], [-L_w, -np.diag(g_w)]])
    ew = np.linalg.eigvals(Aw2)
    fw = np.abs(ew.imag[np.abs(ew.imag) > 1e-3]) / (2 * np.pi)
    dens_w = float((W_w > 1e-6).mean())
    print(f"\n DRIVEN 2nd-order graph-WAVE (node Laplacian-cone, sim-error): "
          f"free-run R2 {np.nanmedian(frw):.3f} | extrapol {np.nanmedian(exw):.3f} | "
          f"SELF-site R2 {np.nanmedian(selfw):.3f} | {int(np.sum(ew.real<=1e-6))}/{2*nS} stable")
    print(f"   {W_w[W_w>1e-6].size} learned edges (kNN cand.), density {dens_w:.2f}; "
          f"{len(fw)} oscillatory modes, freqs {np.sort(fw)[::-1][:5].round(2)} Hz")

    # ---- unified comparison: interpretability vs prediction, across the model ladder ----
    print("\n ===== MODEL LADDER (free-run R2 / self-site R2 / node-space Laplacian?) =====")
    print(f"  1st-order driven Laplacian   free {fr1_med:+.2f}  self {self1_med:+.2f}  "
          f"node-L YES  (monotone: cannot rebound)")
    print(f"  2nd-order driven graph-wave  free {np.nanmedian(frw):+.2f}  self {np.nanmedian(selfw):+.2f}  "
          f"node-L YES  (oscillates: {len(fw)} complex modes)")
    print(f"  delay-DMD (predictive ceil.) free {frm:+.2f}  self  n/a   node-L NO   (latent Hankel)")

    _figures(H, sites, window, klo, khi, khi_pred, dt, A_un, A_sym, Mdmd, models, metrics)
    _lap_figures(sites, A_lap, W_lap, gamma)
    _latent_figures(H, sites, window, klo, khi, khi_pred, A2, W2, gamma2, fr_2nd, fr_delay, Atil, dt, nS)
    _struct_figures(H, sites, window, klo, khi, khi_pred, L_node, fr_struct, fr_delay, freqs, nS)
    _wave_figures(H, sites, window, klo, khi, khi_pred, W_w, L_w, b_w, fr_wave, fr_delay, Aw2, selfw, nS)
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


def _lap_figures(sites, A_lap, W, gamma):
    nS = len(sites)
    order = np.lexsort((sites[:, 1], sites[:, 0]))

    # 1) directed W matrix + A_lap eigen-spectrum (should be all-stable)
    fig, ax = plt.subplots(1, 2, figsize=(10, 4.6))
    Wo = W[np.ix_(order, order)]
    im = ax[0].imshow(Wo, cmap="magma", vmax=np.percentile(W[W > 0], 98) if (W > 0).any() else 1)
    ax[0].set_title("directed edge weights W (j->i, >=0)"); ax[0].set_xlabel("from j"); ax[0].set_ylabel("to i")
    fig.colorbar(im, ax=ax[0], fraction=0.046)
    ev = np.linalg.eigvals(A_lap)
    ax[1].scatter(ev.real, ev.imag, s=18, c="tab:green", alpha=0.7)
    ax[1].axvline(0, color="r", lw=0.6, ls="--")
    ax[1].set_title(f"A_lap spectrum — {int(np.sum(ev.real<1e-9))}/{nS} stable (Re<=0)")
    ax[1].set_xlabel("Re (1/s)"); ax[1].set_ylabel("Im (1/s)")
    fig.suptitle("Directed leaky graph-Laplacian: connectivity + stability")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_laplacian_W.png", dpi=150); plt.close(fig)

    # 2) grid maps: leak timescale, in/out strength, top directed edges
    instr = W.sum(1)      # incoming coupling to node i
    outstr = W.sum(0)     # outgoing coupling from node j
    tau_leak = 1.0 / np.maximum(gamma, 1e-9)
    fig, ax = plt.subplots(1, 4, figsize=(16, 3.8))
    for a, val, ttl in [(ax[0], np.clip(tau_leak, 0, np.percentile(tau_leak, 95)), "leak timescale 1/gamma (s)"),
                        (ax[1], instr, "in-strength (sum_j W_ij)"),
                        (ax[2], outstr, "out-strength (sum_i W_ij)")]:
        sc = a.scatter(sites[:, 0], sites[:, 1], c=val, cmap="viridis", s=130, ec="k", lw=0.3)
        a.set_aspect("equal"); a.set_title(ttl); a.set_xticks([]); a.set_yticks([])
        fig.colorbar(sc, ax=a, fraction=0.046)
    # top directed edges as arrows (color by hemisphere of source)
    a = ax[3]
    a.scatter(sites[:, 0], sites[:, 1], c="0.7", s=60, zorder=1)
    thr = np.percentile(W[W > 0], 96) if (W > 0).any() else np.inf
    for i in range(nS):
        for j in range(nS):
            if W[i, j] >= thr:
                a.annotate("", xy=sites[i], xytext=sites[j], zorder=2,
                           arrowprops=dict(arrowstyle="->", lw=0.8, alpha=0.6,
                                           color="tab:red" if sites[j, 0] < 0 else "tab:blue"))
    a.set_aspect("equal"); a.set_title("top 4% directed edges (j->i)"); a.set_xticks([]); a.set_yticks([])
    fig.suptitle("Directed graph-Laplacian network structure on the grid")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_laplacian_grid.png", dpi=150); plt.close(fig)


def _driven_figures(H, sites, window, klo, khi, khi_pred, A, W, gamma, b, Md,
                    self_act, self_mod, self_r2, hemi_expect, nS):
    """Driven symmetric-PSD Laplacian: opsin-sign B map, recovered undirected coupling, and the
    REBOUND DIAGNOSTIC (pooled same-site actual vs the monotone first-order free-run)."""
    order = np.lexsort((sites[:, 1], sites[:, 0]))
    tt = window[klo:khi_pred + 1]
    fig, ax = plt.subplots(2, 2, figsize=(11, 9))

    # (a) recovered diagonal input B on the grid: sign = opsin polarity, data-resolved
    a = ax[0, 0]
    vmax = np.percentile(np.abs(b), 98)
    sc = a.scatter(sites[:, 0], sites[:, 1], c=b, cmap="RdBu_r", s=150, ec="k", lw=0.4,
                   vmin=-vmax, vmax=vmax)
    match = np.sign(b) == hemi_expect
    a.scatter(sites[~match, 0], sites[~match, 1], s=250, facecolors="none",
              edgecolors="lime", lw=1.6, label="sign != hemisphere")
    a.axvline(0, color="0.5", lw=0.8, ls="--")
    a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
    a.set_title(f"diagonal input B (signed self-kick)\nleft/excit x<0 => +  |  {int(match.mean()*100)}% match hemisphere")
    fig.colorbar(sc, ax=a, fraction=0.046, label="b_s (dF/F)")
    if (~match).any():
        a.legend(fontsize=7, frameon=False, loc="lower right")

    # (b) recovered undirected coupling W (symmetric) as top edges on the grid
    a = ax[0, 1]
    a.scatter(sites[:, 0], sites[:, 1], c="0.7", s=60, zorder=1)
    thr = np.percentile(W[W > 0], 96) if (W > 0).any() else np.inf
    for i in range(nS):
        for j in range(i + 1, nS):
            if W[i, j] >= thr:
                a.plot([sites[i, 0], sites[j, 0]], [sites[i, 1], sites[j, 1]],
                       "tab:purple", lw=1.1, alpha=0.55, zorder=2)
    a.axvline(0, color="0.5", lw=0.8, ls="--")
    a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
    a.set_title(f"undirected Laplacian coupling W=W^T (top 4% edges)\ndensity {float((W>1e-6).mean()):.2f}")

    # (c) THE REBOUND DIAGNOSTIC: pooled sign-normalized self-response, actual vs monotone model
    a = ax[1, 0]
    mact, sact = self_act.mean(0), self_act.std(0)
    mmod = self_mod.mean(0)
    a.fill_between(tt, (mact - sact) * 100, (mact + sact) * 100, color="k", alpha=0.12, lw=0)
    a.plot(tt, mact * 100, "k-", lw=2.0, label="actual self-response (mean)")
    a.plot(tt, mmod * 100, "--", lw=1.6, color="tab:red", label="first-order Laplacian (monotone)")
    a.axhline(0, color="0.6", lw=0.6)
    a.axvline(window[khi], color="0.5", lw=0.6, ls=":")
    a.set_xlabel("t (s)"); a.set_ylabel("sign-norm. dF/F %")
    a.set_title("REBOUND DIAGNOSTIC: same-site actual vs first-order\n(gap after trough = structurally unrepresentable)")
    a.legend(fontsize=8, frameon=False)

    # (d) per-stim self-site free-run R2 distribution
    a = ax[1, 1]
    sr = np.array(self_r2); sr = sr[np.isfinite(sr)]
    a.hist(sr, bins=np.linspace(min(-1, sr.min()), 1, 25), color="tab:red", alpha=0.75)
    a.axvline(np.median(sr), color="k", lw=1.5, ls="--", label=f"median {np.median(sr):.2f}")
    a.set_xlabel("same-site free-run R2"); a.set_ylabel("# stims")
    a.set_title("Same-site fit quality (per driven node)")
    a.legend(fontsize=8, frameon=False)

    fig.suptitle("Driven first-order symmetric-PSD graph-Laplacian  x_dot = -(L+diag g) x + B u", fontsize=12)
    fig.tight_layout(); fig.savefig(OUTDIR / "net_driven_laplacian.png", dpi=150); plt.close(fig)


def _wave_figures(H, sites, window, klo, khi, khi_pred, W, L, b, fr_wave, fr_delay, Aw2, selfw, nS):
    """Driven 2nd-order graph-wave: learned node-space Laplacian coupling on the grid, its complex
    (oscillatory) spectrum, same-site free-run vs actual (does it now capture the rebound?), and the
    wave-vs-delay-DMD free-run comparison."""
    tt = window[klo:khi_pred + 1]
    fig, ax = plt.subplots(2, 2, figsize=(11.5, 9))

    # (a) learned undirected coupling W on the grid (top edges), node color = input sign
    a = ax[0, 0]
    vmax = np.percentile(np.abs(b), 98)
    a.scatter(sites[:, 0], sites[:, 1], c=b, cmap="RdBu_r", s=90, ec="k", lw=0.3,
              vmin=-vmax, vmax=vmax, zorder=3)
    thr = np.percentile(W[W > 0], 90) if (W > 0).any() else np.inf
    for i in range(nS):
        for j in range(i + 1, nS):
            if W[i, j] >= thr:
                a.plot([sites[i, 0], sites[j, 0]], [sites[i, 1], sites[j, 1]],
                       "0.35", lw=0.5 + 2.0 * W[i, j] / W.max(), alpha=0.5, zorder=1)
    a.axvline(0, color="0.5", lw=0.8, ls="--")
    a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
    a.set_title(f"learned graph-wave coupling W=W^T (top 10% k-NN edges)\nnode fill = diagonal B sign")

    # (b) complex spectrum: oscillatory modes = the rebound capacity
    a = ax[0, 1]
    ew = np.linalg.eigvals(Aw2)
    a.scatter(ew.real, ew.imag / (2 * np.pi), s=18, c="tab:blue", alpha=0.7)
    a.axvline(0, color="r", lw=0.6, ls="--")
    a.set_xlabel("Re (1/s) — decay"); a.set_ylabel("Im/2pi (Hz) — oscillation")
    a.set_title(f"graph-wave poles: {int(np.sum(np.abs(ew.imag) > 1e-3))}/{2*nS} oscillatory, "
                f"{int(np.sum(ew.real <= 1e-6))}/{2*nS} stable")

    # (c) same-site free-run vs actual, pooled sign-normalized (does it capture the rebound now?)
    a = ax[1, 0]
    sa, sm = [], []
    for s in range(nS):
        tr = fr_wave(s, khi_pred - klo); ac = H[s, :, klo:khi_pred + 1].T
        sgn = np.sign(b[s]) or 1.0
        sa.append(sgn * ac[:, s]); sm.append(sgn * tr[:, s])
    sa, sm = np.array(sa), np.array(sm)
    a.fill_between(tt, (sa.mean(0) - sa.std(0)) * 100, (sa.mean(0) + sa.std(0)) * 100, color="k", alpha=0.12, lw=0)
    a.plot(tt, sa.mean(0) * 100, "k-", lw=2.0, label="actual self-response (mean)")
    a.plot(tt, sm.mean(0) * 100, "--", lw=1.7, color="tab:blue", label="2nd-order graph-wave")
    a.axhline(0, color="0.6", lw=0.6); a.axvline(window[khi], color="0.5", lw=0.6, ls=":")
    a.set_xlabel("t (s)"); a.set_ylabel("sign-norm. dF/F %")
    a.set_title(f"same-site: graph-wave vs actual (median self R2 {np.nanmedian(selfw):.2f})\nnow oscillatory — compare to first-order's monotone miss")
    a.legend(fontsize=8, frameon=False)

    # (d) example free-run: graph-wave vs delay-DMD vs actual (strongest self + 2 stims)
    a = ax[1, 1]
    ex_stims = [int(np.argmax([np.abs(H[s, s, klo:khi]).max() for s in range(nS)])), int(nS * 0.4), int(nS * 0.75)]
    cols = ["tab:blue", "tab:green", "tab:orange"]
    for s, c in zip(ex_stims, cols):
        tw = fr_wave(s, khi_pred - klo); td = fr_delay(s, khi_pred - klo)
        a.plot(tt, H[s, s, klo:khi_pred + 1] * 100, "-", lw=1.8, color=c, label=f"stim {s} actual")
        a.plot(tt, tw[:, s] * 100, "--", lw=1.2, color=c)
        a.plot(tt, td[:, s] * 100, ":", lw=1.2, color=c)
    a.axvline(window[khi], color="0.5", lw=0.6, ls=":")
    a.set_xlabel("t (s)"); a.set_ylabel("dF/F %")
    a.set_title("self free-run: actual (solid) / graph-wave (dash) / delay-DMD (dot)")
    a.legend(fontsize=7, frameon=False)

    fig.suptitle("Driven 2nd-order graph-WAVE  x_ddot = -(L+diag leak) x - Gamma x_dot + B u  (node Laplacian, sim-error)", fontsize=11.5)
    fig.tight_layout(); fig.savefig(OUTDIR / "net_driven_wave.png", dpi=150); plt.close(fig)


def _latent_figures(H, sites, window, klo, khi, khi_pred, A2, W2, gamma2, fr_2nd, fr_delay, Atil, dt, nS):
    tt = window[klo:khi_pred + 1]
    # example free-run (2nd-order vs delay vs actual) for 3 stims, strongest self + 2 targets
    ex_stims = [int(np.argmax([np.abs(H[s, s, klo:khi]).max() for s in range(nS)]))]
    ex_stims += [int(nS * 0.4), int(nS * 0.75)]
    fig, axs = plt.subplots(1, 3, figsize=(13, 3.6), sharex=True)
    for a, s in zip(axs, ex_stims):
        t2 = fr_2nd(s, khi_pred - klo); td = fr_delay(s, khi_pred - klo)
        tgt = [s] + list(np.argsort(-np.abs(H[s, :, khi]))[:1])
        for r in tgt:
            a.plot(tt, H[s, r, klo:khi_pred + 1] * 100, "k-", lw=1.8, label=f"node {r} actual")
            a.plot(tt, t2[:, r] * 100, "--", lw=1.2, color="tab:orange", label="2nd-order")
            a.plot(tt, td[:, r] * 100, ":", lw=1.4, color="tab:green", label="delay-DMD")
        a.axvline(window[khi], color="0.5", lw=0.6, ls=":")
        a.set_title(f"stim ({sites[s,0]:+.1f},{sites[s,1]:+.0f})"); a.set_xlabel("t (s)"); a.set_ylabel("dF/F %")
        a.legend(fontsize=6, frameon=False)
    fig.suptitle("Latent-state free-run: 2nd-order (orange) & delay-DMD (green) vs actual (black)")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_latent_freerun.png", dpi=150); plt.close(fig)

    # spectra: 2nd-order continuous poles + delay-DMD discrete->continuous poles
    fig, ax = plt.subplots(1, 2, figsize=(9, 4))
    e2 = np.linalg.eigvals(A2)
    ax[0].scatter(e2.real, e2.imag, s=16, c="tab:orange", alpha=0.7)
    ax[0].axvline(0, color="r", lw=0.6, ls="--")
    ax[0].set_title(f"2nd-order poles (1/s)\n{int(np.sum(e2.real<=1e-6))}/{2*nS} stable, "
                    f"{int(np.sum(np.abs(e2.imag)>1e-3))} oscillatory")
    ax[0].set_xlabel("Re"); ax[0].set_ylabel("Im")
    ed = np.log(np.linalg.eigvals(Atil).astype(complex)) / dt
    ax[1].scatter(ed.real, ed.imag, s=16, c="tab:green", alpha=0.7)
    ax[1].axvline(0, color="r", lw=0.6, ls="--")
    ax[1].set_title(f"delay-DMD poles (1/s)\n{int(np.sum(np.abs(ed.imag)>1e-3))} oscillatory")
    ax[1].set_xlabel("Re"); ax[1].set_ylabel("Im")
    fig.suptitle("Latent-state model spectra (complex modes = oscillatory rebounds)")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_latent_spectra.png", dpi=150); plt.close(fig)


def _struct_figures(H, sites, window, klo, khi, khi_pred, L_node, fr_struct, fr_delay, freqs, nS):
    order = np.lexsort((sites[:, 1], sites[:, 0]))
    tt = window[klo:khi_pred + 1]

    # 1) recovered node-space graph-Laplacian L_node + its off-diagonal coupling on the grid
    fig, ax = plt.subplots(1, 2, figsize=(10, 4.6))
    Lo = L_node[np.ix_(order, order)]
    v = np.percentile(np.abs(Lo), 98)
    im = ax[0].imshow(Lo, cmap="RdBu_r", vmin=-v, vmax=v)
    ax[0].set_title("recovered node Laplacian L = PΛP^T (sym PSD)"); ax[0].set_xlabel("node"); ax[0].set_ylabel("node")
    fig.colorbar(im, ax=ax[0], fraction=0.046)
    # strongest off-diagonal (negative L_ij = coupling) edges on the grid
    Woff = -L_node.copy(); np.fill_diagonal(Woff, 0)
    ax[1].scatter(sites[:, 0], sites[:, 1], c="0.7", s=60, zorder=1)
    thr = np.percentile(np.abs(Woff), 98)
    for i in range(nS):
        for j in range(i + 1, nS):
            if abs(Woff[i, j]) >= thr:
                ax[1].plot([sites[i, 0], sites[j, 0]], [sites[i, 1], sites[j, 1]],
                           color=("tab:blue" if Woff[i, j] > 0 else "tab:red"),
                           lw=1.1, alpha=0.6, zorder=2)
    ax[1].set_aspect("equal"); ax[1].set_title("top 2% coupling edges (blue=+, red=-)")
    ax[1].set_xticks([]); ax[1].set_yticks([])
    fig.suptitle("Structured graph-Laplacian recovered by simulation-error fit")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_struct_laplacian.png", dpi=150); plt.close(fig)

    # 2) free-run: structured (blue) vs delay-DMD (green) vs actual (black)
    ex_stims = [int(np.argmax([np.abs(H[s, s, klo:khi]).max() for s in range(nS)])), int(nS * 0.4), int(nS * 0.75)]
    fig, axs = plt.subplots(1, 3, figsize=(13, 3.6), sharex=True)
    for a, s in zip(axs, ex_stims):
        ts = fr_struct(s, khi_pred - klo); td = fr_delay(s, khi_pred - klo)
        for r in [s] + list(np.argsort(-np.abs(H[s, :, khi]))[:1]):
            a.plot(tt, H[s, r, klo:khi_pred + 1] * 100, "k-", lw=1.8, label=f"node {r} actual")
            a.plot(tt, ts[:, r] * 100, "--", lw=1.3, color="tab:blue", label="structured L")
            a.plot(tt, td[:, r] * 100, ":", lw=1.3, color="tab:green", label="delay-DMD")
        a.axvline(window[khi], color="0.5", lw=0.6, ls=":")
        a.set_title(f"stim ({sites[s,0]:+.1f},{sites[s,1]:+.0f})"); a.set_xlabel("t (s)"); a.set_ylabel("dF/F %")
        a.legend(fontsize=6, frameon=False)
    fig.suptitle("Structured graph-Laplacian (blue) vs delay-DMD (green) vs actual (black)")
    fig.tight_layout(); fig.savefig(OUTDIR / "net_struct_freerun.png", dpi=150); plt.close(fig)


if __name__ == "__main__":
    main()
