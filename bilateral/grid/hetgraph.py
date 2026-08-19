"""Model H -- heterogeneous node LTI wrapped in a learned graph, on the AL_0048 grid.

Each node carries its own low-order LTI; a free directed graph closes the loop around them;
no topology is imposed anywhere.  Motivated by the dual-opsin geometry: expression is not
uniform across the two hemispheres and may overlap, so neither the injection field nor the
coupling should be told in advance where the midline is.

Model
-----
Node i owns a latent state x_i in R^P over a bank of FIXED first-order poles shared by all
nodes, and its own readout weights -- the only per-node dynamics parameter:

    x_i[t+1] = F x_i[t] + e v_i[t]         F = diag(a_1..a_P),  e = 1_P
    y_i[t]   = w_i' x_i[t]                 w_i in R^P
    v_i[t]   = sum_m B_im u_m[t] + sum_j W_ij y_j[t]

W_ii is FREE, and that is load-bearing rather than a detail.  Forbidding it (the obvious
reading of "the graph has no self-loops") forces every bit of a node's persistence to arrive
from other nodes, and on this data the lattice fits already showed the propagator is ~96%
diagonal -- so a self-loop-free version fits far worse than the VAR and comes out wildly
unstable (measured: test MSE 0.62 against the VAR's 0.15, rho 14).  W_ii is the node's own
feedback, i.e. its autonomous dynamics; the off-diagonal of W is the coupling, and only that
part is a claim about the network.

Equivalently y_i = h_i * v_i with h_i[s] = sum_r Omega_ir a_r^s, Omega = [w_1..w_N]'.  A
biphasic node is a positive weight on a fast pole plus a negative weight on a slow one.
Stacking x = [x_1;..;x_N] and writing R = blkdiag(w_1'..w_N') for the readout:

    x[t+1] = [ (I_N kron F) + (W kron e) R ] x[t] + (B kron e) u[t]
    y[t]   = R x[t]

which is the exact Kronecker form W kron (e w') when the nodes are homogeneous -- so
heterogeneity here IS "Kronecker with a node-indexed readout", not a different model class.

Why a fixed pole bank rather than free per-node poles: it keeps every estimation step a
linear solve.  The model is bilinear in (Omega, [W B]) -- fix either and the other is least
squares -- so it is fitted by alternating least squares.  Capping the slowest pole well
inside the 20 s detrend window also means the node dynamics structurally cannot chase
residual drift, which is where the rho > 1 of the VAR fits was traced to.

Everything runs off precomputed cross-Grams of the pole-filtered signals: after one pass to
build them, an ALS sweep touches no data.  See `build_grams`.

    .venv/Scripts/python.exe bilateral/grid/hetgraph.py
    .venv/Scripts/python.exe bilateral/grid/hetgraph.py --synthetic-only   # recovery test

Read `synthetic_check()` before interpreting any edge or any injection field: B and W trade
off (drive attributed to direct injection vs to propagation) and the only thing separating
them is timing.  The synthetic test measures how much of that separation this record's SNR
and length actually support.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from scipy.signal import lfilter

import gdar_x
import gdarx_grid

DATA = Path(__file__).resolve().parents[2] / "data"
PNG = Path(__file__).resolve().parent / "network_png"
RESULT = DATA / "grid_hetgraph.npz"
CACHE_SPLIT = DATA / "grid_gdarx_data_split.npz"

FS = gdarx_grid.FS
P_POLES = 5
TAU_LO, TAU_HI = 0.03, 2.0        # s; the slow end stays well inside the 20 s detrend
N_BLOCKS = 20
TEST_FRAC = 0.2


# --------------------------------------------------------------------------------------
# pole bank and filtered signals
# --------------------------------------------------------------------------------------

def pole_bank(P=P_POLES, tau_lo=TAU_LO, tau_hi=TAU_HI, fs=FS):
    """Discrete first-order poles a_r = exp(-1/(fs*tau_r)), tau log-spaced."""
    tau = np.geomspace(tau_lo, tau_hi, P)
    return np.exp(-1.0 / (fs * tau)), tau


def causal_filter(Z, a):
    """m[t] = sum_{s>=0} a^s z[t-1-s], i.e. m[t] = a*m[t-1] + z[t-1], strictly causal."""
    return lfilter([0.0, 1.0], [1.0, -float(a)], np.asarray(Z, float), axis=1)


def build_grams(X, U, poles, n_blocks=N_BLOCKS, verbose=True):
    """Per-block cross-Grams of the pole-filtered regressors.

    Stack S = [Y; U] (N+M channels) and filter it through each pole r to get S^(r).  Every
    quantity the ALS needs is a contraction of

        G[r][s] = S^(r) S^(s)'      (N+M, N+M)
        c[r]    = S^(r) Y'          (N+M, N)

    because equation i's regressor matrix is Z_i = sum_r Omega_ir S^(r) -- so its Gram is
    sum_{r,s} Omega_ir Omega_is G[r][s], with no further contact with the data.
    """
    N, T = X.shape
    M = U.shape[0]
    P = len(poles)
    S = np.vstack([X, U])
    Sf = [causal_filter(S, a) for a in poles]
    blk = (np.arange(T) * n_blocks) // T

    G = np.zeros((n_blocks, P, P, N + M, N + M))
    c = np.zeros((n_blocks, P, N + M, N))
    yy = np.zeros((n_blocks, N))
    ysum = np.zeros((n_blocks, N))
    nb = np.zeros(n_blocks, int)
    for b in range(n_blocks):
        m = blk == b
        Yb = X[:, m]
        nb[b] = int(m.sum())
        yy[b] = (Yb ** 2).sum(1)
        ysum[b] = Yb.sum(1)
        for r in range(P):
            Sr = Sf[r][:, m]
            c[b, r] = Sr @ Yb.T
            for s in range(r, P):
                g = Sr @ Sf[s][:, m].T
                G[b, r, s] = g
                if s != r:
                    G[b, s, r] = g.T
        if verbose:
            print(f"\r  block {b + 1}/{n_blocks}", end="", flush=True)
    if verbose:
        print()
    return dict(G=G, c=c, yy=yy, ysum=ysum, n=nb, N=N, M=M, P=P, blk=blk)


def combine(gb, which):
    """Sum block cross-Grams into one set."""
    w = list(which)
    return dict(G=gb["G"][w].sum(0), c=gb["c"][w].sum(0), yy=gb["yy"][w].sum(0),
                ysum=gb["ysum"][w].sum(0), n=int(gb["n"][w].sum()),
                N=gb["N"], M=gb["M"], P=gb["P"])


# --------------------------------------------------------------------------------------
# alternating least squares
# --------------------------------------------------------------------------------------

def _norm_sign(Om, poles):
    """Fix the (Omega, theta) scale/sign ambiguity: ||w_i|| = 1, dominant lobe positive.

    The model only identifies the product h_i * v_i, so w_i and row i of [W B] can trade a
    scalar.  Normalising the kernel is arbitrary; the SIGN convention is not -- anchoring on
    the dominant lobe of h_i makes the sign of B_im mean "site m drives node i up/down",
    which is the whole point of the injection map.
    """
    P = Om.shape[1]
    h = Om @ np.vstack([poles ** s for s in range(60)]).T      # (N, 60) kernel
    sgn = np.sign(h[np.arange(len(h)), np.abs(h).argmax(1)])
    sgn[sgn == 0] = 1.0
    nrm = np.linalg.norm(Om, axis=1, keepdims=True)
    nrm[nrm == 0] = 1.0
    return Om * (sgn[:, None] / nrm), (nrm.ravel() / sgn)


def fit_als(g, poles, n_iter=25, ridge=1e-6, ridge_om=1e-8, theta0=None, seed=0,
            verbose=False):
    """Alternate: theta = [W B] given Omega, then Omega given theta.

    Returns Omega (N, P), W (N, N), B (N, M) and the per-sweep training SSE.
    """
    N, M, P = g["N"], g["M"], g["P"]
    G, c, n = g["G"], g["c"], g["n"]
    D = N + M
    keep = [np.arange(D) for _ in range(N)]      # W_ii free -- see the module docstring

    rng = np.random.default_rng(seed)
    Om = (np.tile(np.linspace(1.0, -0.2, P), (N, 1))
          + (0.01 if seed == 0 else 0.5) * rng.standard_normal((N, P)))
    theta = np.zeros((N, D)) if theta0 is None else np.array(theta0, float)
    scale_g = np.trace(G[0, 0]) / D + 1e-12
    hist = []

    for it in range(n_iter):
        # --- theta | Omega -------------------------------------------------------------
        for i in range(N):
            k = keep[i]
            Gi = np.einsum("r,s,rsab->ab", Om[i], Om[i], G, optimize=True)[np.ix_(k, k)]
            bi = np.einsum("r,ra->a", Om[i], c[:, :, i])[k]
            theta[i] = 0.0
            theta[i, k] = np.linalg.solve(Gi + ridge * scale_g * np.eye(len(k)), bi)
        # --- Omega | theta -------------------------------------------------------------
        for i in range(N):
            t = theta[i]
            Ai = np.einsum("a,rsab,b->rs", t, G, t, optimize=True)
            bi = np.einsum("a,ra->r", t, c[:, :, i])
            Om[i] = np.linalg.solve(Ai + ridge_om * np.trace(Ai) / P * np.eye(P), bi)
        Om, sc = _norm_sign(Om, poles)
        theta *= sc[:, None]
        sse = _sse(Om, theta, g)
        hist.append(float(sse.sum()))
        if verbose:
            print(f"  ALS {it + 1:2d}  SSE {hist[-1]:.6g}")
        if it > 2 and abs(hist[-2] - hist[-1]) < 1e-10 * abs(hist[-1]):
            break

    W, B = theta[:, :N].copy(), theta[:, N:].copy()
    return dict(Omega=Om, W=W, B=B, theta=theta, sse=np.array(hist), poles=poles,
                self_loop=np.diag(W).copy())


def _sse(Om, theta, g):
    """Per-channel residual sum of squares from the cross-Grams (no data pass)."""
    G, c, yy = g["G"], g["c"], g["yy"]
    out = np.empty(g["N"])
    for i in range(g["N"]):
        t = theta[i]
        Gi = np.einsum("r,s,rsab->ab", Om[i], Om[i], G, optimize=True)
        ci = np.einsum("r,ra->a", Om[i], c[:, :, i])
        out[i] = yy[i] - 2 * (t @ ci) + t @ Gi @ t
    return out


def score(fit, g, sigma=None):
    """One-step held-out scores, comparable with `gdarx_grid` / `freegraph`."""
    N, n = g["N"], g["n"]
    sse = _sse(fit["Omega"], fit["theta"], g)
    var = np.maximum(sse / n, 1e-12) if sigma is None else sigma
    ell_mean = float(-0.5 * (np.sum(sse / n / var) + N * np.log(2 * np.pi)
                             + np.log(var).sum()))
    ss_tot = g["yy"] - g["ysum"] ** 2 / n
    return dict(mse=float(sse.sum() / n / N), ell_mean=ell_mean,
                vaf=float(np.nanmean(1 - sse / ss_tot)), var=var,
                rho=spectral_radius(fit))


def spectral_radius(fit):
    """rho of the closed loop (I kron F) + (W kron e) R, dimension N*P."""
    Om, W, poles = fit["Omega"], fit["W"], fit["poles"]
    N, P = Om.shape
    A = np.zeros((N * P, N * P))
    for i in range(N):
        A[i * P:(i + 1) * P, i * P:(i + 1) * P] = np.diag(poles)
    # e w_j' scaled by W_ij: block (i, j) gets ones(P,1) @ (W_ij * w_j')
    for i in range(N):
        for j in range(N):
            if W[i, j] != 0.0:
                A[i * P:(i + 1) * P, j * P:(j + 1) * P] += W[i, j] * np.outer(
                    np.ones(P), Om[j])
    return float(np.max(np.abs(np.linalg.eigvals(A))))


def _scale_to_rho(Om, W, poles, target=None, iters=40):
    """Shrink W by a scalar until the closed-loop spectral radius hits `target`.

    rho is monotone in the scalar but not analytic in it, so this is a bisection on
    alpha in (0, 1].  Used only to build a simulatable ground truth.

    The target must sit ABOVE max(poles): at alpha = 0 the loop is open and rho is already
    the slowest pole (0.986 for a 2 s pole at 35 Hz).  Asking for anything below that
    bisects alpha to zero and silently returns an edgeless truth -- which is exactly what
    a 0.95 target did on the first run, producing a "0 true edges" recovery test.
    """
    floor = float(np.max(np.abs(poles)))
    if target is None:
        target = floor + 0.3 * (1.0 - floor)
    target = max(target, floor + 1e-3)
    f = lambda a: spectral_radius(dict(Omega=Om, W=a * W, poles=poles))
    if f(1.0) <= target:
        return W
    lo, hi = 0.0, 1.0
    for _ in range(iters):
        mid = 0.5 * (lo + hi)
        if f(mid) > target:
            hi = mid
        else:
            lo = mid
    return lo * W


def kernels(fit, n_steps=60):
    """Per-node impulse kernels h_i[s] = sum_r Omega_ir a_r^s."""
    return fit["Omega"] @ np.vstack([fit["poles"] ** s for s in range(n_steps)]).T


# --------------------------------------------------------------------------------------
# the opsin question
# --------------------------------------------------------------------------------------

def model_impulse(fit, n_steps, chan):
    """Simulate the model's response (n_steps, N) to a unit impulse on input channel m."""
    Om, W, B, poles = fit["Omega"], fit["W"], fit["B"], fit["poles"]
    N, P = Om.shape
    x = np.zeros((N, P))
    y = np.zeros(N)
    out = np.zeros((n_steps, N))
    for t in range(n_steps):
        v = (B[:, chan] if t == 0 else 0.0) + W @ y
        x = x * poles[None, :] + v[:, None]
        y = np.einsum("ip,ip->i", Om, x)
        out[t] = y
    return out


def green_check(fit, site_of_input, amp_of_input, sites, fs=FS, verbose=True):
    """Compare the model's Green's function against the measured one.

    This is the metric Model H exists for.  One-step likelihood is not a model-selection
    criterion on this data (see `freegraph.py`: it is monotone in edge count and runs to the
    complete graph), and it rewards a flexible per-lag AR term rather than a network.  The
    impulse response is multi-step, it is what the photostimulation experiment actually
    measures, and it is only defined for a model that can be simulated at all.

    `H` in grid_cross_response_2amp.npz is FRACTIONAL dF/F while the state here is percent,
    so the comparison is on correlation, not on absolute scale.
    """
    f = DATA / "grid_cross_response_2amp.npz"
    if not f.exists():
        return None
    z = np.load(f, allow_pickle=True)
    H, amps, win = z["H"], z["amps"], z["window"]
    base = int(z["base_ix"])
    # H is interpolated onto a FS_WIN window (70 Hz), NOT the 35 Hz imaging clock the model
    # runs on, so it must be decimated by `step` before any sample-by-sample comparison.
    # Comparing index-for-index silently pits 28.6 ms model frames against 14.3 ms data
    # samples -- the model then looks like it is running at half speed rather than being
    # wrong, and every correlation below is depressed for a reason that is not the model.
    step = int(round(float(z["fs_win"]) / fs))
    if step < 1:
        raise ValueError(f"H sampled at {float(z['fs_win'])} Hz, below the model's {fs} Hz")
    n_post = min(int(round(0.7 * fs)), (H.shape[-1] - base) // step)
    # H is always the full 52-site tensor; the model may be fitted on a node subset, so map
    # model index -> H index by site coordinate rather than assuming they line up.
    key = {(round(x, 3), round(y, 3)): i for i, (x, y) in enumerate(z["sites"])}
    orig = np.array([key[(round(x, 3), round(y, 3))] for x, y in np.asarray(sites)])
    N = len(orig)

    on_m, on_e, peak_m, peak_e = [], [], np.zeros((N, N)), np.zeros((N, N))
    for ai, amp in enumerate(amps):
        sel = np.nonzero((np.asarray(site_of_input) >= 0)
                         & np.isclose(np.asarray(amp_of_input, float), amp))[0]
        if not len(sel):
            continue
        for ch in sel:
            s = int(site_of_input[ch])
            sim = model_impulse(fit, n_post, ch)                      # (n_post, N)
            emp = H[ai][np.ix_(orig, [orig[s]])][:, 0,
                                                 base:base + step * n_post:step].T
            on_m.append(sim[:, s]); on_e.append(emp[:, s])
            k = np.abs(sim).argmax(0)
            peak_m[:, s] = sim[k, np.arange(N)]
            k = np.abs(emp).argmax(0)
            peak_e[:, s] = emp[k, np.arange(N)]
        break                                                        # one amplitude is enough
    on_m, on_e = np.array(on_m), np.array(on_e)
    r_on = float(np.corrcoef(on_m.ravel(), on_e.ravel())[0, 1])
    r_pk = float(np.corrcoef(peak_m.ravel(), peak_e.ravel())[0, 1])
    r_off = float(np.corrcoef(peak_m[~np.eye(N, dtype=bool)],
                              peak_e[~np.eye(N, dtype=bool)])[0, 1])
    if verbose:
        print(f"\nGreen's function vs measured H ({n_post} frames = "
              f"{n_post / fs * 1e3:.0f} ms):")
        print(f"  corr on-site time course   {r_on:+.3f}")
        print(f"  corr {N}x{N} peak map        {r_pk:+.3f}")
        print(f"  corr OFF-DIAGONAL peaks    {r_off:+.3f}   <- the propagation claim")
    return dict(r_onsite=r_on, r_peak=r_pk, r_peak_off=r_off,
                sim_on=on_m, emp_on=on_e, peak_m=peak_m, peak_e=peak_e, n_post=n_post)


def mixing_index(B, site_of_input=None):
    """Signed balance of each stim site's injection field, in [-1, +1].

    +1: site m drives every node in the positive direction (pure excitatory-like drive).
    -1: pure suppression.  Near 0: the site injects both signs -- which is what overlapping
    opsin expression at one galvo position would look like.  The sign is meaningful only
    because `_norm_sign` anchors each node's kernel on its dominant lobe.
    """
    B = np.asarray(B, float)
    pos = np.clip(B, 0, None).sum(0)
    neg = np.clip(-B, 0, None).sum(0)
    tot = pos + neg
    idx = np.where(tot > 0, (pos - neg) / np.where(tot > 0, tot, 1.0), np.nan)
    return idx, tot


def synthetic_check(g_shape, poles, X, U, fit, blocks, n_rep=1, seed=0, verbose=True):
    """Simulate from a known (Omega, W, B), refit, and measure what is recoverable.

    The point is not to validate the code (that is `gdar_x._selftest`) but to measure the
    B-vs-W confound: drive that reaches a node directly and drive that arrives through the
    graph differ only in timing, and this says how much of that difference survives at this
    record's SNR and length.
    """
    rng = np.random.default_rng(seed)
    N, M = fit["W"].shape[0], fit["B"].shape[1]
    P = len(poles)
    Om_t, W_t, B_t = fit["Omega"], fit["W"], fit["B"]
    # Sparsify the truth (off-diagonal only -- the self-loops are the node dynamics and
    # must survive) so that edge recovery is a meaningful question, then rescale the
    # coupling until the closed loop is stable: a truth with rho > 1 simulates to inf and
    # the recovery test measures nothing.
    off = ~np.eye(N, dtype=bool)
    thr = np.percentile(np.abs(W_t[off]), 90)
    W_t = np.where(off & (np.abs(W_t) < thr), 0.0, W_t)
    W_t = _scale_to_rho(Om_t, W_t, poles)

    T = U.shape[1]
    noise_sd = np.sqrt(np.maximum(_sse(fit["Omega"], fit["theta"], g_shape)
                                  / g_shape["n"], 1e-12))
    Y = np.zeros((N, T))
    x = np.zeros((N, P))
    for t in range(1, T):
        v = B_t @ U[:, t - 1] + W_t @ Y[:, t - 1]
        x = x * poles[None, :] + v[:, None]
        Y[:, t] = np.einsum("ip,ip->i", Om_t, x) + noise_sd * rng.standard_normal(N)

    gb = build_grams(Y, U, poles, verbose=False)
    g_tr = combine(gb, blocks)
    f2 = fit_als(g_tr, poles, n_iter=25)

    true_edge = W_t != 0
    np.fill_diagonal(true_edge, False)
    sc = np.abs(f2["W"])
    np.fill_diagonal(sc, 0.0)
    auc = _auc(sc[~np.eye(N, dtype=bool)], true_edge[~np.eye(N, dtype=bool)])
    rB = float(np.corrcoef(B_t.ravel(), f2["B"].ravel())[0, 1])
    rW = float(np.corrcoef(W_t.ravel(), f2["W"].ravel())[0, 1])
    rH = float(np.corrcoef(kernels(fit).ravel(), kernels(f2).ravel())[0, 1])
    if verbose:
        print(f"\nsynthetic recovery ({int(true_edge.sum())} true edges):")
        print(f"  edge detection AUC        {auc:.3f}")
        print(f"  corr(W_true, W_hat)       {rW:+.3f}")
        print(f"  corr(B_true, B_hat)       {rB:+.3f}   <- the B/W confound lives here")
        print(f"  corr(h_true, h_hat)       {rH:+.3f}")
    return dict(auc=auc, corr_W=rW, corr_B=rB, corr_h=rH,
                n_true=int(true_edge.sum()), W_true=W_t, W_hat=f2["W"],
                B_true=B_t, B_hat=f2["B"])


def _auc(score, label):
    """Rank-based AUC (Mann-Whitney), no sklearn dependency."""
    score, label = np.asarray(score, float).ravel(), np.asarray(label, bool).ravel()
    order = np.argsort(score)
    ranks = np.empty(len(score))
    ranks[order] = np.arange(1, len(score) + 1)
    n1, n0 = int(label.sum()), int((~label).sum())
    if n1 == 0 or n0 == 0:
        return np.nan
    return float((ranks[label].sum() - n1 * (n1 + 1) / 2) / (n1 * n0))


# --------------------------------------------------------------------------------------
# driver
# --------------------------------------------------------------------------------------

def load_split(rebuild=False, verbose=True):
    """X/U with one input channel per (site, amplitude) -- no dose linearity assumed."""
    if CACHE_SPLIT.exists() and not rebuild:
        z = np.load(CACHE_SPLIT, allow_pickle=True)
        d = {k: z[k] for k in z.files}
        if verbose:
            print(f"loaded {CACHE_SPLIT.name}: X {d['X'].shape}, U {d['U'].shape}")
        return d
    d = gdarx_grid.build(amp_mode="split", cache=False, verbose=verbose)
    np.savez_compressed(CACHE_SPLIT, **{k: np.asarray(v) for k, v in d.items()})
    print(f"cached -> {CACHE_SPLIT.name}")
    return d


def run(d=None, P=P_POLES, n_iter=25, n_restart=3, save=True, verbose=True,
        synthetic=True, interior=False, roi=False, tag=""):
    d = load_split(verbose=verbose) if d is None else d
    if roi or interior:
        import freegraph
        if roi:
            import roi_nodes
            keep = roi_nodes.load_mask(d["sites"], verbose=verbose)
        else:
            keep = gdar_x.interior_nodes(d["sites"], verbose=verbose)
        d = freegraph.subset_nodes(d, keep, verbose=verbose)
    X, U, sites = d["X"], d["U"], d["sites"]
    soi = np.asarray(d["site_of_input"], int)
    N, M = X.shape[0], U.shape[0]
    poles, tau = pole_bank(P)
    if verbose:
        print(f"N={N} nodes, M={M} input channels, P={P} poles "
              f"(tau {tau[0] * 1e3:.0f} ms - {tau[-1]:.1f} s)")
        print(f"parameters: Omega {N * P} + W {N * (N - 1)} + B {N * M} = "
              f"{N * P + N * (N - 1) + N * M}")
        print("building pole-filtered cross-Grams (one pass) ...")

    gb = build_grams(X, U, poles, verbose=verbose)
    stride = max(int(round(1.0 / TEST_FRAC)), 2)
    te = [b for b in range(N_BLOCKS) if b % stride == stride - 1]
    tr = [b for b in range(N_BLOCKS) if b not in te]
    g_tr, g_te = combine(gb, tr), combine(gb, te)
    if verbose:
        print(f"train {g_tr['n']} frames / test {g_te['n']}")

    # ALS is a local method; restart it and keep the best training SSE.
    best = None
    for r in range(n_restart):
        f = fit_als(g_tr, poles, n_iter=n_iter, seed=r, verbose=verbose and r == 0)
        if best is None or f["sse"][-1] < best["sse"][-1]:
            best = f
        if verbose:
            print(f"  restart {r}: SSE {f['sse'][-1]:.6g}"
                  + ("  <- best" if best is f else ""))
    fit = best
    s_tr = score(fit, g_tr)
    s_te = score(fit, g_te, sigma=s_tr["var"])
    if verbose:
        off = ~np.eye(N, dtype=bool)
        selfl = np.abs(np.diag(fit["W"])).mean()
        coup = float(np.sqrt((fit["W"][off] ** 2).mean()))
        print(f"\ntrain  MSE {s_tr['mse']:.5f}  VAF {s_tr['vaf']:.4f}")
        print(f"test   MSE {s_te['mse']:.5f}  VAF {s_te['vaf']:.4f}  "
              f"ell {s_te['ell_mean']:.3f}  rho {s_te['rho']:.4f}")
        print(f"self-loop |W_ii| {selfl:.4f}  vs off-diagonal coupling rms {coup:.4f} "
              f"({coup / max(selfl, 1e-12):.1%} of the self term)")
        idx, tot = mixing_index(fit["B"])
        lm = np.average(idx[~np.isnan(idx)], weights=tot[~np.isnan(idx)])
        print(f"injection balance: mean {lm:+.3f}, "
              f"{np.mean(np.abs(idx[~np.isnan(idx)]) < 0.5):.0%} of sites are mixed-sign "
              f"(|balance| < 0.5)")

    amp_of_input = np.asarray(d["amp_of_input"], float)
    grn = green_check(fit, soi, amp_of_input, sites, verbose=verbose)
    syn = synthetic_check(g_tr, poles, X, U, fit, tr, verbose=verbose) if synthetic else None

    out = dict(fit=fit, s_tr=s_tr, s_te=s_te, sites=sites, poles=poles, tau=tau,
               site_of_input=soi, amp_of_input=amp_of_input, green=grn,
               syn=syn, g_tr=g_tr, g_te=g_te)
    if save:
        np.savez_compressed(
            RESULT.with_name(RESULT.stem + tag + RESULT.suffix),
            Omega=fit["Omega"], W=fit["W"], B=fit["B"], poles=poles, tau=tau,
            sites=sites, site_of_input=soi, amp_of_input=out["amp_of_input"],
            sse=fit["sse"], mse_test=s_te["mse"], vaf_test=s_te["vaf"],
            ell_test=s_te["ell_mean"], rho=s_te["rho"],
            **({} if grn is None else {f"green_{k}": np.asarray(v)
                                       for k, v in grn.items() if np.ndim(v) <= 2}),
            **({} if syn is None else {f"syn_{k}": v for k, v in syn.items()
                                       if np.ndim(v) <= 2}))
        print(f"saved -> {RESULT.stem + tag + RESULT.suffix}")
    return out


def figure(res, out=None):
    fit, sites = res["fit"], res["sites"]
    W, B, Om = fit["W"], fit["B"], fit["Omega"]
    N = len(sites)
    soi, amp = res["site_of_input"], res["amp_of_input"]
    h = kernels(fit)
    tsec = np.arange(h.shape[1]) / FS
    left = sites[:, 0] < 0

    fig, ax = plt.subplots(2, 4, figsize=(19.5, 9.2))
    fig.suptitle("Model H — heterogeneous node LTI + learned graph (no topology imposed)",
                 fontsize=12)

    # A: the per-node kernels -- the heterogeneity the model buys
    a = ax[0, 0]
    for i in range(N):
        a.plot(tsec, h[i], lw=0.7, color=("tab:green" if left[i] else "tab:purple"),
               alpha=0.65)
    a.axhline(0, color="0.6", lw=0.7)
    a.set_xlabel("s after drive", fontsize=8); a.set_ylabel("h_i(t)", fontsize=8)
    a.set_title(f"A. per-node kernels (P={len(res['poles'])} shared poles,\n"
                f"tau {res['tau'][0] * 1e3:.0f} ms – {res['tau'][-1]:.1f} s; "
                f"green = left/excitatory, purple = right/inhibitory)", fontsize=9)

    # B: kernel peak time and sign, mapped
    a = ax[0, 1]
    pk = tsec[np.abs(h).argmax(1)]
    sc = a.scatter(sites[:, 0], sites[:, 1], c=pk * 1e3, cmap="viridis", s=90, ec="k",
                   lw=0.3)
    a.axvline(0, color="0.55", ls="--", lw=0.8)
    fig.colorbar(sc, ax=a, fraction=0.045).set_label("kernel peak (ms)", fontsize=7)
    a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
    a.set_title("B. node dynamics are heterogeneous in space", fontsize=9)

    # C: the learned coupling, strongest edges
    a = ax[0, 2]
    mag = np.abs(W)
    thr = np.percentile(mag[mag > 0], 98) if (mag > 0).any() else 0
    ii, jj = np.nonzero(mag >= thr)
    seg = np.stack([sites[jj], sites[ii]], 1)
    w = W[ii, jj]
    vm = np.abs(w).max() if len(w) else 1.0
    lc = LineCollection(seg, array=w, cmap="RdBu_r", norm=plt.Normalize(-vm, vm),
                        linewidths=0.4 + 2.2 * np.abs(w) / max(vm, 1e-12), zorder=2)
    a.add_collection(lc)
    a.scatter(sites[:, 0], sites[:, 1], c="0.75", s=55, ec="k", lw=0.3, zorder=3)
    a.axvline(0, color="0.55", ls="--", lw=0.8)
    fig.colorbar(lc, ax=a, fraction=0.045).set_label("W[i,j]", fontsize=7)
    a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
    offd = ~np.eye(N, dtype=bool)
    a.set_title(f"C. learned coupling, top 2% of |W| ({len(ii)} edges)\n"
                f"self-loop |W_ii| {np.abs(np.diag(W)).mean():.2f} vs coupling rms "
                f"{np.sqrt((W[offd] ** 2).mean()):.2f}", fontsize=9)
    a.autoscale_view()

    # D: THE opsin panel -- injection balance per stim site
    a = ax[0, 3]
    idx, tot = mixing_index(B)
    per_site = np.full(N, np.nan)
    for s in range(N):
        m = soi == s
        if m.any():
            per_site[s] = np.average(idx[m], weights=np.maximum(tot[m], 1e-12))
    sc = a.scatter(sites[:, 0], sites[:, 1], c=per_site, cmap="coolwarm", vmin=-1, vmax=1,
                   s=110, ec="k", lw=0.4)
    a.axvline(0, color="0.4", ls="--", lw=1.0)
    fig.colorbar(sc, ax=a, fraction=0.045).set_label("injection balance", fontsize=7)
    a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
    nL = np.nanmean(per_site[left]); nR = np.nanmean(per_site[~left])
    a.set_title(f"D. injection balance per stim site (+1 all-positive drive)\n"
                f"left mean {nL:+.2f}, right mean {nR:+.2f} — "
                f"nothing here assumed a midline", fontsize=9)

    # E: dose response, straight off the split input channels
    a = ax[1, 0]
    amps = np.unique(amp[~np.isnan(amp)])
    if len(amps) == 2:
        g0 = np.linalg.norm(B[:, amp == amps[0]], axis=0)
        g1 = np.linalg.norm(B[:, amp == amps[1]], axis=0)
        a.scatter(g0, g1, s=26, c=np.where(left, "tab:green", "tab:purple"))
        lim = max(g0.max(), g1.max()) * 1.05
        a.plot([0, lim], [0, lim], "--", color="0.6", lw=0.9, label="1:1")
        r = amps[1] / amps[0]
        a.plot([0, lim], [0, lim * r], ":", color="k", lw=0.9, label=f"{r:.0f}:1 (linear)")
        ok = g0 > 0
        a.set_title(f"E. dose response per site, no linearity assumed\n"
                    f"median gain ratio {np.median(g1[ok] / g0[ok]):.2f} "
                    f"(linear would be {r:.1f})", fontsize=9)
        a.set_xlabel(f"||B|| at {amps[0]:.2g} mW", fontsize=8)
        a.set_ylabel(f"||B|| at {amps[1]:.2g} mW", fontsize=8)
        a.legend(fontsize=7, frameon=False)

    # F/G: the model's Green's function against the measured one -- the metric that matters
    grn = res.get("green")
    a = ax[1, 1]
    if grn:
        ts = np.arange(grn["n_post"]) / FS
        for k in range(min(12, len(grn["sim_on"]))):
            a.plot(ts, grn["emp_on"][k] * 100, color="0.6", lw=0.8)
            a.plot(ts, grn["sim_on"][k], color="tab:red", lw=0.8, alpha=0.8)
        a.axhline(0, color="0.7", lw=0.6)
        a.set_xlabel("s after pulse", fontsize=8)
        a.set_ylabel("dF/F %", fontsize=8)
        a.set_title(f"F. on-site impulse response: measured (grey)\n"
                    f"vs model (red), corr {grn['r_onsite']:+.2f}", fontsize=9)

    a = ax[1, 2]
    if grn:
        od = ~np.eye(N, dtype=bool)
        a.scatter(grn["peak_e"][od] * 100, grn["peak_m"][od], s=6, c="0.5", alpha=0.5,
                  label="off-diagonal")
        a.scatter(np.diag(grn["peak_e"]) * 100, np.diag(grn["peak_m"]), s=18,
                  c="tab:red", label="stimulated site")
        a.axhline(0, color="0.8", lw=0.6); a.axvline(0, color="0.8", lw=0.6)
        a.set_xlabel("measured peak (dF/F %)", fontsize=8)
        a.set_ylabel("model peak", fontsize=8)
        a.legend(fontsize=7, frameon=False)
        a.set_title(f"G. {N}x{N} peak map: r={grn['r_peak']:+.2f} overall,\n"
                    f"{grn['r_peak_off']:+.2f} off-diagonal (the propagation claim)",
                    fontsize=9)

    # H: what the synthetic test says is recoverable
    a = ax[1, 3]
    syn = res.get("syn")
    if syn:
        names = ["edge AUC", "corr(W)", "corr(B)", "corr(h)"]
        vals = [syn["auc"], syn["corr_W"], syn["corr_B"], syn["corr_h"]]
        a.bar(range(4), vals, color=["tab:blue", "tab:orange", "tab:red", "tab:green"])
        a.axhline(0.5, color="0.5", ls="--", lw=0.8)
        a.set_ylim(0, 1.05); a.set_xticks(range(4)); a.set_xticklabels(names, fontsize=7)
        for i, v in enumerate(vals):
            a.text(i, v + 0.02, f"{v:.2f}", ha="center", fontsize=7)
        a.set_title(f"H. synthetic recovery at this SNR and record length\n"
                    f"({syn['n_true']} true edges; dashed = chance for AUC)", fontsize=9)

    fig.tight_layout(rect=(0, 0, 1, 0.96))
    PNG.mkdir(exist_ok=True)
    out = (PNG / "hetgraph.png") if out is None else Path(out)
    fig.savefig(out, dpi=150)
    print(f"wrote {out}")
    return fig


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--poles", type=int, default=P_POLES)
    ap.add_argument("--n-iter", type=int, default=25)
    ap.add_argument("--n-restart", type=int, default=3)
    ap.add_argument("--interior", action="store_true",
                    help="drop perimeter grid sites (see gdar_x.interior_nodes)")
    ap.add_argument("--roi", action="store_true",
                    help="use the hand-drawn ROI mask (bilateral/grid/roi_nodes.py)")
    ap.add_argument("--no-synthetic", action="store_true")
    ap.add_argument("--no-save", action="store_true")
    a = ap.parse_args()
    tag = "_roi" if a.roi else "_int" if a.interior else ""
    res = run(P=a.poles, n_iter=a.n_iter, n_restart=a.n_restart, save=not a.no_save,
              synthetic=not a.no_synthetic, interior=a.interior, roi=a.roi, tag=tag)
    figure(res, out=PNG / f"hetgraph{tag}.png")


if __name__ == "__main__":
    main()
