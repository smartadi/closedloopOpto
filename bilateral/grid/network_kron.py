"""network_kron.py — networked-LTI model of the 52-node photostim grid.

Each node i is its OWN high-order SISO LTI system (A_i, B_i, C_i) realised from that node's
self-response; the nodes are tied together by a sparse, distance-penalised graph Laplacian W:

    x_i[k+1] = A_i x_i[k] + B_i ( u_i[k] + sum_j W_ij (y_j[k] - y_i[k]) )
    y_i[k]   = C_i x_i[k]

This is the heterogeneous generalisation of the L(x)A Kronecker network: block-diagonal per-node
dynamics blkdiag(A_i) + diffusive Laplacian coupling. It subsumes the scalar graph-wave
(network_id.py) as the order-1/2 special case, and realises the measured 52x52 MIMO transfer
matrix H[s,r,t] as a STRUCTURED state-space (vs delay-DMD = the unstructured ceiling).

Why W is identifiable: with each A_i FIXED from the self-response, the coupling enters as an
extra input computable from the measured outputs, so fitting W is a LINEAR (equation-error)
problem — see fit_coupling() (added next). This file builds + validates the per-node realisation.

Data: grid_tf_fits.npz H (onset-zeroed, single amp = highest SNR). Run:
    ../../.venv/Scripts/python.exe network_kron.py
"""
from pathlib import Path

import numpy as np

import cross_response

DATA = cross_response.CACHE.parent
FIT_TMAX = 0.6          # s — realise each node over the clean early window (pre neighbour-stim)


def r2(actual, pred):
    a = np.asarray(actual).ravel(); p = np.asarray(pred).ravel()
    return 1.0 - np.sum((a - p) ** 2) / (np.sum((a - a.mean()) ** 2) + 1e-12)


# --------------------------------------------------------------------------- #
# per-node realisation: impulse response -> discrete state space (Ho-Kalman / ERA)
def era(markov, order):
    """Eigensystem Realisation Algorithm. `markov` = m[1], m[2], ... (SISO Markov params, with
    m[0]=D=0 assumed — the onset-zeroed response is 0 at k=0). Returns (A, B, C) of the requested
    order (a minimal discrete realisation whose impulse response matches `markov`)."""
    m = np.asarray(markov, float)                # m[0]=D(=0), m[1..] = C A^{k-1} B
    L = len(m)
    r = (L - 1) // 2
    # Hankel of the Markov params, EXCLUDING D: H0[i,j]=m[i+j+1], H1[i,j]=m[i+j+2]
    H0 = np.array([[m[i + j + 1] for j in range(r)] for i in range(r)])
    H1 = np.array([[m[i + j + 2] for j in range(r)] for i in range(r)])
    U, S, Vt = np.linalg.svd(H0)
    n = min(order, np.sum(S > 1e-9 * S[0]))
    n = max(int(n), 1)
    Un, Sn, Vn = U[:, :n], S[:n], Vt[:n].T
    S_half = np.diag(np.sqrt(Sn))
    S_ihalf = np.diag(1.0 / np.sqrt(Sn))
    A = S_ihalf @ Un.T @ H1 @ Vn @ S_ihalf
    B = (S_half @ Vn.T)[:, 0:1]
    C = (Un @ S_half)[0:1, :]
    return A, B, C


def impulse(A, B, C, nstep):
    """Discrete impulse response y[k]=C A^{k-1} B for k=1..nstep, with y[0]=0."""
    y = np.zeros(nstep)
    c = C.ravel()
    x = B[:, 0].copy()
    for k in range(1, nstep):
        y[k] = float(c @ x)
        x = A @ x
    return y


def realize_nodes(H, window, order=4, stabilize=True):
    """Realise every node's local LTI (A_i,B_i,C_i) from its SELF impulse response H[i,i,:] over
    [0,FIT_TMAX]. Returns dict of lists + the per-node self-reconstruction R2."""
    nS = H.shape[0]
    post = (window >= 0) & (window <= FIT_TMAX)
    kpost = np.where(post)[0]
    nodes = {"A": [], "B": [], "C": [], "n": [], "r2_self": []}
    for i in range(nS):
        h = H[i, i, kpost]                       # self impulse response, starts ~0
        m = h.copy()                             # Markov params m[k]=h[k], m[0]~0
        try:
            A, B, C = era(m, order)
            if stabilize:                        # clip unstable poles inside the unit circle
                ev, V = np.linalg.eig(A)
                if np.max(np.abs(ev)) > 1.0:
                    ev = ev / np.maximum(np.abs(ev), 1.0) * np.minimum(np.abs(ev), 0.999)
                    A = np.real(V @ np.diag(ev) @ np.linalg.inv(V))
            yhat = impulse(A, B, C, len(m))
            rr = r2(m, yhat)
        except Exception:
            A = np.zeros((1, 1)); B = np.zeros((1, 1)); C = np.zeros((1, 1)); yhat = m * 0; rr = np.nan
        nodes["A"].append(A); nodes["B"].append(B); nodes["C"].append(C)
        nodes["n"].append(A.shape[0]); nodes["r2_self"].append(rr)
    nodes["kpost"] = kpost
    return nodes


def lsim(A, B, C, u):
    """Discrete output of node LTI to input sequence u[k]: x[k+1]=Ax+Bu, y[k]=Cx (y[0]=0)."""
    y = np.zeros(len(u))
    c = C.ravel(); b = B[:, 0]
    x = np.zeros(A.shape[0])
    for k in range(len(u)):
        y[k] = float(c @ x)
        x = A @ x + b * u[k]
    return y


def lasso_cd(X, y, alpha, pen=None, iters=500, tol=1e-8):
    """Signed weighted Lasso by coordinate descent (columns assumed unit-L2 -> col2=1).
    Minimises 1/(2n)||y-Xb||^2 + alpha * sum_j pen_j |b_j|. pen=None -> uniform."""
    n, p = X.shape
    pen = np.ones(p) if pen is None else np.asarray(pen, float)
    b = np.zeros(p)
    r = y - X @ b
    an = alpha * n
    for _ in range(iters):
        dmax = 0.0
        for j in range(p):
            bj = b[j]
            rho = X[:, j] @ r + bj                          # col2_j = 1
            g = an * pen[j]
            nb = np.sign(rho) * max(abs(rho) - g, 0.0)
            if nb != bj:
                r += X[:, j] * (bj - nb)
                b[j] = nb
                dmax = max(dmax, abs(nb - bj))
        if dmax < tol:
            break
    return b


def fit_coupling(H, sites, window, nodes, alpha=0.08, dist_pow=1.0):
    """Fit the coupling W by EQUATION error (linear, given fixed per-node A_i).

    Each node i's measured output must equal its LTI response to  u_i + sum_j W_ij (y_j - y_i).
    LTI_i*u_i is the direct term (=self-impulse only when i is the stimmed node), so
      target  t_i^s = y_i^s - LTI_i*u_i^s
      feature phi_ij^s = LTI_i * (y_j^s - y_i^s)          (diffusive difference, node-i-filtered)
      t_i = sum_j W_ij phi_ij     -> Lasso per node i (signed W; excit AND inhib coupling).
    Distance-scaled L1 (feature / d_ij^dist_pow) makes long edges cost more but ALLOWED if strong.
    """
    nS = len(sites)
    kpost = nodes["kpost"]
    T = len(kpost)
    D = np.hypot(sites[:, 0][:, None] - sites[:, 0][None, :],
                 sites[:, 1][:, None] - sites[:, 1][None, :])
    Y = H[:, :, kpost]                                       # Y[s,r,k]
    imp = [impulse(nodes["A"][i], nodes["B"][i], nodes["C"][i], T) for i in range(nS)]

    W = np.zeros((nS, nS))
    tf_r2 = np.full(nS, np.nan)
    for i in range(nS):
        Ai, Bi, Ci = nodes["A"][i], nodes["B"][i], nodes["C"][i]
        feats, targ = [], []
        for s in range(nS):
            yi = Y[s, i]
            direct = imp[i] if s == i else np.zeros(T)
            targ.append(yi - direct)
            row = [lsim(Ai, Bi, Ci, Y[s, j] - yi) if j != i else np.zeros(T) for j in range(nS)]
            feats.append(np.array(row).T)                    # (T, nS)
        X = np.vstack(feats)                                 # (nS*T, nS)
        t = np.concatenate(targ)
        cn = np.linalg.norm(X, axis=0) + 1e-12               # unit-normalise columns for CD
        Xn = X / cn
        pen = D[i] ** dist_pow                               # distance-weighted L1 penalty
        pen[i] = 1e9                                         # forbid self-loop
        amax = np.max(np.abs(Xn.T @ t) / (len(t) * pen))     # alpha at which all coefs are 0
        beta = lasso_cd(Xn, t, alpha * amax, pen=pen)
        W[i] = beta / cn                                     # de-normalise back to W
        W[i, i] = 0.0
        tf_r2[i] = r2(t, Xn @ beta)
    return W, tf_r2, D


if __name__ == "__main__":
    z = np.load(DATA / "grid_tf_fits.npz", allow_pickle=True)
    H, sites, window = z["H"], z["sites"], z["window"]
    cvr2 = z["cvr2"]
    nS = len(sites)
    dt = float(window[1] - window[0])
    print(f"{nS} nodes | dt={dt*1e3:.1f} ms | realising each node's self-TF over [0,{FIT_TMAX}]s")

    nodes = realize_nodes(H, window, order=4)
    rr = np.array(nodes["r2_self"])
    strong = np.diag(cvr2) > 0.2
    print(f"per-node realisation (order 4): median self-recon R2 = {np.nanmedian(rr):.3f} "
          f"(reliable {np.nanmedian(rr[strong]):.3f})")

    print("fitting coupling W (equation-error Lasso, distance-scaled) ...")
    W, tf_r2, Dist = fit_coupling(H, sites, window, nodes)
    nz = np.abs(W) > 1e-9
    print(f"  teacher-forced R2: median {np.nanmedian(tf_r2):.3f} (reliable {np.nanmedian(tf_r2[strong]):.3f})")
    print(f"  edges: {nz.sum()} / {nS*(nS-1)} ({100*nz.sum()/(nS*(nS-1)):.1f}%), "
          f"median in-degree {np.median(nz.sum(1)):.0f}")
    ed = Dist[nz]
    if ed.size:
        print(f"  edge distance (mm): median {np.median(ed):.2f}, 90th pct {np.percentile(ed,90):.2f}, "
              f"max {ed.max():.2f}  ({100*np.mean(ed>3):.0f}% long-range >3mm)")
    np.savez(DATA / "grid_network_kron.npz", W=W, tf_r2=tf_r2, sites=sites, dist=Dist,
             node_n=nodes["n"], r2_self=nodes["r2_self"])
    print("cached -> grid_network_kron.npz")
