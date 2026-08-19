"""GDAR-with-input — graph-constrained vector autoregression with an exogenous stimulus term.

Fits

    x_t = sum_{k in a_lags} A_k x_{t-k}  +  sum_{r in u_lags} B_r u_{t-r}  +  e_t,
    e_t ~ N(0, Sigma)

where `x_t` is the N-channel state (one ROI per photostim site) and `u_t` is the
M-channel input (one channel per stim site, an impulse train scaled by laser amplitude).

The A_k carry a *graph* sparsity pattern, supp(A_k) subset of adj | I, and optionally the
GDAR symmetry constraint A_k = A_k^T (Schwock et al.).  Dropping symmetry gives GVAR;
dropping the graph too gives plain VAR/VARX.  The B_r can be free, diagonal
(input enters only at its own node -- all spatial spread is then carried by the network
(I - sum A_k)^-1), or restricted to a neighbourhood mask.

Design notes
------------
*Self-contained*: pure numpy + scipy.sparse.  No cvxpy, no cross-repo import.  The
constrained-GLS algebra is a re-derivation of `gdar.gdar_model.CVARModel.fit_restricted`
(yazdanlab/repos/network_analysis_software) and the held-out-likelihood scorer follows
yazdanlab/sysID/gdar_with_input.py; see yazdanlab/sysID/GDAR_INPUT_MODEL.md for the
derivation and the E0/E1/E2 estimator taxonomy.

*Gram-based*: the design matrix Z (D x n_fit) is never materialised.  Everything the
estimators and scorers need factors through the second-moment matrices

    Z2 = Z Z^T (D,D),   ZY = Z Y^T (D,N),   YY = Y Y^T (N,N),   n

accumulated in one chunked pass.  With N = M = 52 and K = 5 that is D = 520, so fitting
and scoring cost O(D^2) memory regardless of record length (203k frames here).

*Constraint algebra*: a constrained fit is parameterised by theta = sum_i gamma_i M_i where
each basis matrix M_i is a handful of unit entries of the (N, D) coefficient block --
one entry for a free coefficient, two for a symmetry-tied pair.  Writing the GLS objective
tr[(Y - theta Z)^T C (Y - theta Z)] in terms of gamma gives normal equations G gamma = h with

    G[i,i'] = sum_{t in i} sum_{s in i'} v_t v_s Z2[q_t, q_s] C[p_t, p_s]
    h[i]    = sum_{t in i} v_t (C Y Z^T)[p_t, q_t]

where (p_t, q_t, v_t) enumerates the nonzeros of the basis matrices.  Because each basis
matrix has at most 2 nonzeros this is assembled by a scatter of a dense nnz x nnz block --
no per-parameter loop over D x D products.

Estimators
----------
E0  `model='ols'`                     unconstrained A, joint least squares.
E1  `method='alt'`   (default)        block-coordinate: constrained A-step on Y - B Zu,
                                      then B-step on the AR residual.  Cheap for a free B
                                      (13520 params here) because the B-step is row-separable.
E2  `method='joint'`                  one constrained-GLS solve over [A, B] together.
                                      Exact, but needs a *restricted* B (n_free must stay
                                      in the low thousands) -- use with b_mask='diag'/'local'.

Both fit Sigma by the two-stage GLS of `fit_gdar`: fit with C = I, form the residual
covariance, refit with C = Sigma^-1.

Run `python gdar_x.py` for a synthetic self-test.
"""

from __future__ import annotations

import numpy as np
from scipy import sparse

__all__ = [
    "lattice_graph", "build_input", "make_spec",
    "grams", "block_split",
    "fit_gdarx",
    "resid_moment", "noise_cov", "condition_report",
    "vaf_from_grams", "loglik_from_grams", "delta_loglik",
    "predict", "input_gain", "dc_gain", "impulse_response", "spectral_radius",
]


# --------------------------------------------------------------------------------------
# graph
# --------------------------------------------------------------------------------------

def lattice_graph(sites, connectivity=8, spacing=1.0, bridge_midline=True, tol=1e-6):
    """Adjacency over stim sites laid out on a regular mm lattice.

    sites : (N, 2) array of (x_mm, y_mm).  For the AL_0048 grid, x is on half-integers
            -3.5..3.5 and y on integers -4..3, so `spacing` is 1.0 mm.
    connectivity : 4 (von Neumann) or 8 (Moore, includes diagonals).
    bridge_midline : if False, drop edges joining x<0 to x>0.  The two hemispheres carry
            *different opsins* (left excitatory, right inhibitory), so a symmetric A_k
            across the midline is a strong assumption -- this switch lets you test it.

    Returns a boolean (N, N) adjacency with a zero diagonal.
    """
    P = np.asarray(sites, float)
    if P.ndim != 2 or P.shape[1] != 2:
        raise ValueError(f"sites must be (N,2), got {P.shape}")
    d = np.linalg.norm(P[:, None, :] - P[None, :, :], axis=-1)
    if connectivity == 4:
        adj = np.abs(d - spacing) < tol
    elif connectivity == 8:
        adj = (d < spacing * np.sqrt(2.0) + tol) & (d > tol)
    else:
        raise ValueError("connectivity must be 4 or 8")
    if not bridge_midline:
        side = np.sign(P[:, 0])
        adj = adj & (side[:, None] == side[None, :])
    adj = adj & adj.T
    np.fill_diagonal(adj, False)
    return adj


def interior_nodes(sites, connectivity=8, spacing=1.0, min_degree=None, verbose=False):
    """Mask of grid sites that are NOT on the perimeter.

    Perimeter sites sit at the edge of the galvo grid, where the illuminated spot can fall
    outside the imaged cortical region -- their ROI is then reading something other than the
    response to a well-placed stimulus, and as a readout they are the least trustworthy
    channels in the set.  A perimeter node is defined purely geometrically, as one missing
    any of its lattice neighbours; no data is consulted, so the mask cannot be tuned to a
    result.

    On the AL_0048 52-site grid this keeps the 24 sites with all 8 neighbours present,
    balanced 12 left / 12 right, which also leaves the channel set full rank (24 ROIs read
    out of a 50-component SVD basis, against 52 before).
    """
    adj = lattice_graph(sites, connectivity=connectivity, spacing=spacing,
                        bridge_midline=True)
    deg = adj.sum(1)
    if min_degree is None:
        min_degree = int(connectivity)
    keep = deg >= min_degree
    if verbose:
        P = np.asarray(sites, float)
        print(f"interior nodes: {keep.sum()}/{len(keep)} kept (lattice degree >= "
              f"{min_degree}); {int((keep & (P[:, 0] < 0)).sum())} left, "
              f"{int((keep & (P[:, 0] > 0)).sum())} right")
    return keep


# --------------------------------------------------------------------------------------
# input construction
# --------------------------------------------------------------------------------------

def build_input(frame_t, onset_t, onset_site, n_sites, weight=None, fractional=True):
    """One-hot impulse train U (n_sites, T) on the imaging frame clock.

    frame_t     : (T,) frame timestamps (s).
    onset_t     : (n_onset,) stimulus times (s).
    onset_site  : (n_onset,) integer site index in [0, n_sites).
    weight      : (n_onset,) per-onset amplitude, default 1.0.  Pass the laser amplitude
                  to make B a per-mW gain; pass 1.0 to fold amplitude into B.
    fractional  : split each impulse linearly between the two bracketing frames.  The
                  25 ms pulse is shorter than the 28.6 ms frame, so sub-frame onset
                  timing is real jitter, not noise -- linear splitting preserves both the
                  total delivered "mass" and its first moment.  With fractional=False the
                  impulse lands entirely on the nearest frame.

    Onsets outside the frame-clock span are dropped (reported in the returned count).
    """
    frame_t = np.asarray(frame_t, float)
    onset_t = np.asarray(onset_t, float)
    onset_site = np.asarray(onset_site, int)
    T = len(frame_t)
    w = np.ones(len(onset_t)) if weight is None else np.asarray(weight, float)

    ok = (onset_t >= frame_t[0]) & (onset_t <= frame_t[-1])
    ot, os_, w = onset_t[ok], onset_site[ok], w[ok]

    U = np.zeros((n_sites, T))
    if fractional:
        j = np.clip(np.searchsorted(frame_t, ot) - 1, 0, T - 2)
        span = frame_t[j + 1] - frame_t[j]
        frac = np.clip((ot - frame_t[j]) / np.where(span > 0, span, 1.0), 0.0, 1.0)
        np.add.at(U, (os_, j), w * (1.0 - frac))
        np.add.at(U, (os_, j + 1), w * frac)
    else:
        j = np.clip(np.searchsorted(frame_t, ot), 0, T - 1)
        j = np.where((j > 0) & (np.abs(frame_t[np.maximum(j - 1, 0)] - ot)
                                < np.abs(frame_t[j] - ot)), j - 1, j)
        np.add.at(U, (os_, j), w)
    return U, int(ok.sum())


# --------------------------------------------------------------------------------------
# constraint specification
# --------------------------------------------------------------------------------------

class Spec:
    """Sparse basis for a constrained coefficient block theta (N, D).

    theta = sum_i gamma_i M_i, and (p, q, v, col) lists the nonzeros of every M_i:
    entry `t` contributes value v[t] at theta[p[t], q[t]] and belongs to free parameter
    col[t].  A free coefficient owns one entry; a symmetry-tied off-diagonal pair owns two.
    """

    __slots__ = ("p", "q", "v", "col", "n_free", "N", "D", "shape_a", "shape_b", "Da")

    def __init__(self, p, q, v, col, n_free, N, D, shape_a, shape_b, Da):
        self.p = np.asarray(p, np.intp)
        self.q = np.asarray(q, np.intp)
        self.v = np.asarray(v, float)
        self.col = np.asarray(col, np.intp)
        self.n_free, self.N, self.D = int(n_free), int(N), int(D)
        self.shape_a, self.shape_b, self.Da = shape_a, shape_b, int(Da)

    @property
    def nnz(self):
        return len(self.p)

    def to_theta(self, gamma):
        """Expand free parameters to the dense (N, D) coefficient block."""
        theta = np.zeros((self.N, self.D))
        np.add.at(theta, (self.p, self.q), self.v * np.asarray(gamma, float)[self.col])
        return theta

    def split(self, theta):
        """theta (N, D) -> A (N, N, K_a), B (N, M, K_u).  Either may be None."""
        A = B = None
        if self.shape_a is not None:
            N, _, K_a = self.shape_a
            A = np.stack([theta[:, k * N:(k + 1) * N] for k in range(K_a)], axis=-1)
        if self.shape_b is not None:
            _, M, K_u = self.shape_b
            off = self.Da
            B = np.stack([theta[:, off + r * M:off + (r + 1) * M] for r in range(K_u)], axis=-1)
        return A, B


def _mask_pairs(mask, sym):
    """(i, j) index arrays for the free entries of a single N x N lag matrix."""
    mask = np.asarray(mask, bool)
    return np.nonzero(np.triu(mask) if sym else mask)


def make_spec(N, M, K_a, K_u, a_mask, b_mask, sym):
    """Build the constraint basis for [A_1..A_Ka, B_1..B_Ku] laid out as theta (N, D).

    a_mask : (N, N) boolean support for every A_k (the diagonal is forced on).
    b_mask : (N, M) boolean support for every B_r, or None for no input block.
    sym    : tie A_k[i,j] to A_k[j,i] (GDAR); False gives GVAR/VAR.
    """
    Da = N * K_a
    Du = 0 if b_mask is None else M * K_u
    D = Da + Du
    p, q, v, col = [], [], [], []
    c = 0

    if K_a > 0:
        am = np.asarray(a_mask, bool).copy()
        np.fill_diagonal(am, True)
        ii, jj = _mask_pairs(am, sym)
        for k in range(K_a):
            off = k * N
            for i, j in zip(ii, jj):
                p.append(i); q.append(off + j); v.append(1.0); col.append(c)
                if sym and i != j:
                    p.append(j); q.append(off + i); v.append(1.0); col.append(c)
                c += 1

    if b_mask is not None:
        bi, bm = np.nonzero(np.asarray(b_mask, bool))
        for r in range(K_u):
            off = Da + r * M
            for i, m in zip(bi, bm):
                p.append(i); q.append(off + m); v.append(1.0); col.append(c)
                c += 1

    shape_a = (N, N, K_a) if K_a > 0 else None
    shape_b = (N, M, K_u) if b_mask is not None else None
    return Spec(p, q, v, col, c, N, D, shape_a, shape_b, Da)


def resolve_b_mask(b_mask, N, M, adj=None):
    """'free' | 'diag' | 'local' | 'zero' | None | explicit (N, M) boolean -> mask or None.

    `None` means "no input block at all" (theta is A-only, D = N K_a), whereas 'zero' means
    "an input block that is constrained to zero".  The distinction matters: a 'zero' fit
    keeps the full-width theta, so it can be scored against exactly the same Gram as the
    models it is the null for.
    """
    if b_mask is None:
        return None
    if isinstance(b_mask, str) and b_mask == "zero":
        return np.zeros((N, M), bool)
    if isinstance(b_mask, str):
        if b_mask == "free":
            return np.ones((N, M), bool)
        if b_mask in ("diag", "local"):
            if M != N:
                raise ValueError(f"b_mask='{b_mask}' needs M == N (got M={M}, N={N})")
            out = np.eye(N, dtype=bool)
            if b_mask == "local":
                if adj is None:
                    raise ValueError("b_mask='local' needs `adj`")
                out = out | np.asarray(adj, bool)
            return out
        raise ValueError(f"unknown b_mask {b_mask!r}")
    out = np.asarray(b_mask, bool)
    if out.shape != (N, M):
        raise ValueError(f"b_mask must be (N,M)=({N},{M}), got {out.shape}")
    return out


# --------------------------------------------------------------------------------------
# second moments
# --------------------------------------------------------------------------------------

def grams(X, U, a_lags, u_lags, keep=None, chunk=20000):
    """Accumulate Z2 = Z Z^T, ZY = Z Y^T, YY = Y Y^T over the usable time columns.

    X : (N, T) state.  U : (M, T) input, or None.
    a_lags / u_lags : positive lag lists for A and B.  u_lags may include 0 to allow a
        contemporaneous input term (GDAR_INPUT_MODEL.md sec. 7 open question); the default
        callers use strictly causal lags.
    keep : optional boolean mask over the n_fit = T - lag_max usable columns, for
        train/test splits.

    Returns a dict carrying the moments plus the layout metadata the fitters need.
    """
    X = np.asarray(X, float)
    N, T = X.shape
    a_lags = list(a_lags)
    u_lags = [] if U is None else list(u_lags)
    if U is None:
        M = 0
    else:
        U = np.asarray(U, float)
        M = U.shape[0]
        if U.shape[1] != T:
            raise ValueError(f"U has {U.shape[1]} samples, X has {T}")
    K_a, K_u = len(a_lags), len(u_lags)
    lag_max = max([0] + a_lags + u_lags)
    if lag_max >= T:
        raise ValueError("record shorter than the maximum lag")

    idx = np.arange(lag_max, T)
    n_fit = len(idx)
    if keep is not None:
        keep = np.asarray(keep, bool)
        if len(keep) != n_fit:
            raise ValueError(f"keep must have length n_fit={n_fit}, got {len(keep)}")
        idx = idx[keep]
    if len(idx) == 0:
        raise ValueError("no columns selected")

    Da, D = N * K_a, N * K_a + M * K_u
    Z2 = np.zeros((D, D))
    ZY = np.zeros((D, N))
    YY = np.zeros((N, N))
    Ysum = np.zeros(N)

    for s in range(0, len(idx), chunk):
        ti = idx[s:s + chunk]
        Zc = np.empty((D, len(ti)))
        for k, L in enumerate(a_lags):
            Zc[k * N:(k + 1) * N] = X[:, ti - L]
        for r, L in enumerate(u_lags):
            Zc[Da + r * M:Da + (r + 1) * M] = U[:, ti - L]
        Yc = X[:, ti]
        Z2 += Zc @ Zc.T
        ZY += Zc @ Yc.T
        YY += Yc @ Yc.T
        Ysum += Yc.sum(1)

    return dict(Z2=Z2, ZY=ZY, YY=YY, Ysum=Ysum, n=int(len(idx)), n_fit=int(n_fit),
                N=N, M=M, K_a=K_a, K_u=K_u, D=D, Da=Da,
                a_lags=a_lags, u_lags=u_lags, lag_max=int(lag_max))


def block_split(n_fit, test_frac=0.2, n_blocks=20):
    """Contiguous-block train/test masks over the fit columns.

    Splitting into a modest number of long contiguous blocks (rather than interleaving
    single frames) keeps train/test leakage to the block boundaries: a test column's lag
    regressors come from the same block except within `lag_max` of an edge.
    """
    if not 0 < test_frac < 1:
        raise ValueError("test_frac must be in (0,1)")
    blk = (np.arange(n_fit) * n_blocks) // n_fit
    stride = max(int(round(1.0 / test_frac)), 2)
    test = (blk % stride) == (stride - 1)
    if not test.any() or test.all():           # degenerate n_blocks/test_frac combination
        test = np.zeros(n_fit, bool)
        test[int(n_fit * (1 - test_frac)):] = True
    return ~test, test


# --------------------------------------------------------------------------------------
# constrained GLS solve
# --------------------------------------------------------------------------------------

def _unstructured_cols(spec):
    """Columns of theta that are fully free and untied, or None if the spec is structured.

    True for the unconstrained VAR/VARX blocks (model='ols', b_mask='free'), where the
    constrained machinery below would burn an O(n_free^2) matrix to reproduce a plain
    least-squares solve.
    """
    if spec.nnz != spec.n_free:          # symmetry ties present
        return None
    cols = np.unique(spec.q)
    if spec.n_free != spec.N * cols.size or not np.all(spec.v == 1.0):
        return None
    return cols


def _solve_gls(spec, Z2, RHS, C, ridge=0.0, chunk=2048, max_free=12000):
    """Solve the constrained normal equations for gamma, return theta (N, D).

    Z2  : (D, D) regressor second moment.
    RHS : (N, D) equal to Y Z^T (the *unweighted* cross moment).
    C   : (N, N) precision Sigma^-1 (or I).
    """
    cols = _unstructured_cols(spec)
    if cols is not None:
        # Every row of theta is free over the same columns and nothing is tied, so the rows
        # separate and the GLS weight C drops out entirely (identical regressors across
        # equations -- the SUR/OLS equivalence).  One D_c x D_c solve instead of n_free^2.
        Zc = Z2[np.ix_(cols, cols)]
        if ridge:
            Zc = Zc + ridge * np.eye(len(cols))
        theta = np.zeros((spec.N, spec.D))
        theta[:, cols] = np.linalg.solve(Zc.T, np.asarray(RHS, float)[:, cols].T).T
        return theta

    if spec.n_free > max_free:
        raise MemoryError(
            f"{spec.n_free} free parameters exceeds max_free={max_free}; the joint solve "
            f"needs an O(n_free^2) matrix. Use method='alt' for a free B, or restrict "
            f"b_mask to 'diag'/'local'.")
    p, q, v, col, nf = spec.p, spec.q, spec.v, spec.col, spec.n_free
    nnz = spec.nnz
    S = sparse.csr_matrix((np.ones(nnz), (np.arange(nnz), col)), shape=(nnz, nf))

    G = np.zeros((nf, nf))
    for s in range(0, nnz, chunk):
        sl = slice(s, min(s + chunk, nnz))
        Mblk = (v[sl, None] * v[None, :]) * Z2[np.ix_(q[sl], q)] * C[np.ix_(p[sl], p)]
        W = (S.T @ Mblk.T)                       # (nf, chunk) == (Mblk @ S).T
        G += S[sl].T @ W.T

    Bmat = C @ np.asarray(RHS, float)            # (N, D) = C Y Z^T
    h = S.T @ (v * Bmat[p, q])

    if ridge:
        G = G + float(ridge) * np.eye(nf)
    try:
        gamma = np.linalg.solve(G, h)
    except np.linalg.LinAlgError:
        gamma = np.linalg.lstsq(G, h, rcond=None)[0]
    if not np.all(np.isfinite(gamma)):
        gamma = np.linalg.lstsq(G, h, rcond=None)[0]
    return spec.to_theta(gamma)


# --------------------------------------------------------------------------------------
# moments -> diagnostics
# --------------------------------------------------------------------------------------

def resid_moment(theta, g):
    """Sum-of-outer-products of the one-step residuals, from Grams: sum_t r_t r_t^T."""
    theta = np.asarray(theta, float)
    cross = theta @ g["ZY"]                       # (N, N)
    return g["YY"] - cross - cross.T + theta @ g["Z2"] @ theta.T


def noise_cov(theta, g, diagonal=False, shrinkage=1e-6):
    """Residual covariance estimate, optionally diagonalised and ridge-stabilised.

    `shrinkage` pulls Sigma toward (tr Sigma / N) I.  The default is a numerical guard,
    but it is a real modelling knob whenever the channels are a low-rank image of some
    smaller basis -- widefield ROIs read out of a rank-50 SVD, for instance, give a
    52 x 52 Sigma with exactly-zero eigenvalues.  Sigma^-1 then blows up directions that
    carry no signal, and a GLS fit optimises almost entirely inside them.  See
    `condition_report`.
    """
    Sigma = resid_moment(theta, g) / g["n"]
    Sigma = 0.5 * (Sigma + Sigma.T)
    if diagonal:
        Sigma = np.diag(np.diag(Sigma))
    if shrinkage:
        Sigma = Sigma + shrinkage * np.trace(Sigma) / Sigma.shape[0] * np.eye(Sigma.shape[0])
    return Sigma


def condition_report(X, tol=None):
    """Effective rank of the channel set, and what it means for a GLS fit.

    A VAR over N channels silently assumes the N channels are N independent signals.
    Widefield ROIs are not: `roi_ts = V @ spat.T + mI` reconstructs every ROI from the
    same rank-`N_COMPS` SVD basis, so with 52 ROIs off 50 components the channel
    covariance has *exactly* two zero eigenvalues, and many more that are zero for
    practical purposes.  Two consequences, both of which bite silently:

      - the regression design Z is rank-deficient, so an unconstrained VARX solution is
        not unique (the constrained fits are fine -- the constraints break the degeneracy);
      - Sigma inherits the deficiency, so Sigma^-1 up-weights directions containing no
        signal by many orders of magnitude, and a GLS objective ends up almost entirely
        about them.  `logdet Sigma` -- and therefore any likelihood -- is dominated by
        the same directions, which makes cross-model likelihood differences untrustworthy.

    `tol` is a *relative* eigenvalue floor, w[0] * 1e-8 by default, deliberately far above
    machine epsilon: a direction carrying 1e-8 of the leading variance is noise whether or
    not it is numerically distinguishable from zero, and it is exactly such a direction
    that a GLS weight would blow up.  A machine-eps tolerance would call this data full
    rank (its smallest eigenvalue is ~1e-12 against a leading ~1e2) and say nothing useful.

    Returns a dict.  `shrink_hint` is the sigma_shrink that would cap the condition number
    of this spectrum at `cond_target`: noise_cov adds lam * (tr/N) * I, so the eigenvalues
    become w_i + lam*m and cond -> (w_max + lam*m) / (w_min + lam*m); solving that at
    w_min = 0 gives lam = w_max / (m * (kappa - 1)).  It is computed from cov(X) rather
    than from Sigma, so treat it as an order of magnitude, not a calibrated value.  Note
    that shrinkage only ever caps the damage -- on this data it never recovers the fit a
    diagonal Sigma gives, so prefer `sigma_diagonal=True` when the report says deficient.
    """
    X = np.asarray(X, float)
    N = X.shape[0]
    w = np.linalg.eigvalsh(np.cov(X))[::-1]
    tol = (w[0] * 1e-8) if tol is None else tol
    rank = int((w > tol).sum())
    frac = np.cumsum(w) / w.sum()
    m = w.mean()
    return dict(N=N, rank=rank, deficient=rank < N, tol=float(tol),
                eig=w, cond=float(w[0] / max(w[-1], np.finfo(float).tiny)),
                n_99=int(np.searchsorted(frac, 0.99) + 1),
                n_999=int(np.searchsorted(frac, 0.999) + 1),
                participation_ratio=float(w.sum() ** 2 / (w ** 2).sum()),
                cond_target=1e3,
                shrink_hint=float(w[0] / (m * (1e3 - 1))) if rank < N else 1e-6)


def vaf_from_grams(theta, g, centered=True):
    """Per-channel one-step variance accounted for, 1 - SS_res / SS_tot."""
    ss_res = np.diag(resid_moment(theta, g))
    ss_tot = np.diag(g["YY"]).copy()
    if centered:
        ss_tot = ss_tot - g["Ysum"] ** 2 / g["n"]
    return 1.0 - ss_res / np.where(ss_tot > 0, ss_tot, np.nan)


def loglik_from_grams(theta, g, Sigma):
    """Gaussian one-step predictive log-likelihood on the columns summarised by `g`.

    Teacher-forced (one-step), not free-run: near the unit root a free-run VAF diverges
    while this stays finite, which is why it is the headline metric in GDAR_INPUT_MODEL.md.
    Sigma must come from the *training* fit for a held-out score to be honest.
    """
    N, n = g["N"], g["n"]
    Sigma = np.asarray(Sigma, float)
    Sigma_inv = np.linalg.pinv(Sigma)
    sign, logdet = np.linalg.slogdet(Sigma)
    if sign <= 0:
        logdet = np.log(np.clip(np.linalg.eigvalsh(Sigma), 1e-12, None)).sum()
    quad = float(np.sum(Sigma_inv * resid_moment(theta, g)))   # tr(Sigma^-1 R)
    ell = -0.5 * (quad + n * (N * np.log(2 * np.pi) + logdet))
    return float(ell), float(ell / n)


def _zero_input(theta, g):
    """Copy of theta with the B block set to zero (the no-input null model)."""
    out = np.array(theta, float, copy=True)
    out[:, g["Da"]:] = 0.0
    return out


def delta_loglik(theta, g, Sigma):
    """Held-out evidence for the input term: ell(with u) - ell(B == 0), same Sigma.

    Positive delta means the stimulus channel earns its parameters on data the model did
    not see.  Reported as a total and per-sample.
    """
    ell_u, mean_u = loglik_from_grams(theta, g, Sigma)
    ell_0, mean_0 = loglik_from_grams(_zero_input(theta, g), g, Sigma)
    return dict(ell_withU=ell_u, ell_noU=ell_0,
                delta_total=ell_u - ell_0, delta_mean=mean_u - mean_0,
                n=g["n"])


# --------------------------------------------------------------------------------------
# fitting
# --------------------------------------------------------------------------------------

def fit_gdarx(X, U=None, adj=None, K_a=5, K_u=5, model="gdar", b_mask="free",
              method="alt", n_iter=3, gls=True, ridge_a=0.0, ridge_u=1e-6,
              a_lags=None, u_lags=None, keep=None, sigma_diagonal=False,
              sigma_shrink=1e-6, tol=1e-6, g=None, verbose=False):
    """Fit x_t = sum A_k x_{t-k} + sum B_r u_{t-r} + e_t under graph/symmetry constraints.

    model  : 'gdar' (graph sparsity + symmetric A), 'gvar' (graph sparsity only),
             'ols'  (unconstrained A -- estimator E0).
    b_mask : 'free' | 'diag' | 'local' | 'zero' | explicit (N, M) boolean.  'zero' fits
             the autonomous model, i.e. the null the held-out delta is measured against.
    method : 'alt'   -- E1 block coordinate descent (A-step, then B-step), n_iter passes.
             'joint' -- E2 single constrained GLS over [A, B]; needs a restricted b_mask.
    gls    : re-weight by Sigma^-1 after the first pass (the two-stage GLS of `fit_gdar`).
    sigma_shrink : shrink Sigma toward (tr Sigma / N) I before inverting it.  Leave at the
             numerical default only when the channels are full rank.  If they are not --
             `condition_report` will say so -- the GLS weight is dominated by directions
             with no signal in them and the fit is driven by numerical noise; something
             like 0.05 restores a sane objective.  Also applies to the returned Sigma, so
             the same weighting is used when scoring.
    keep   : boolean mask over fit columns (train subset); ignored if `g` is supplied.
    g      : precomputed `grams(...)` dict, to avoid re-scanning the record.

    Returns a dict with A (N,N,K_a), B (N,M,K_u) or None, theta, Sigma, spec, grams,
    plus the fit settings.
    """
    X = np.asarray(X, float)
    N = X.shape[0]
    M = 0 if U is None else np.asarray(U).shape[0]

    if model not in ("gdar", "gvar", "ols"):
        raise ValueError("model must be 'gdar', 'gvar' or 'ols'")
    sym = (model == "gdar")
    if model == "ols":
        a_mask = np.ones((N, N), bool)
    else:
        if adj is None:
            raise ValueError(f"model='{model}' needs an adjacency")
        a_mask = np.asarray(adj, bool) | np.eye(N, dtype=bool)

    bm = None if U is None else resolve_b_mask(b_mask, N, M, adj)
    if bm is None:
        U, K_u = None, 0

    a_lags = list(range(1, K_a + 1)) if a_lags is None else list(a_lags)
    u_lags = ([] if bm is None else
              (list(range(1, K_u + 1)) if u_lags is None else list(u_lags)))
    K_a, K_u = len(a_lags), len(u_lags)

    if g is None:
        g = grams(X, U, a_lags, u_lags, keep=keep)
    Da, D = g["Da"], g["D"]
    Z2, ZY = g["Z2"], g["ZY"]
    YZ = ZY.T                                      # (N, D) = Y Z^T

    spec = make_spec(N, M, K_a, K_u, a_mask, bm, sym)
    spec_a = make_spec(N, M, K_a, 0, a_mask, None, sym)
    C = np.eye(N)
    Sigma = np.eye(N)

    joint = bm is None or method == "joint" or not bm.any()
    if joint:
        # ---- E0 / E2: one constrained solve over everything, iteratively reweighted.
        # The reweighting is iterated rather than done once because the GLS fixed point
        # (Sigma = residual covariance of the fit that Sigma^-1 weighted) is what makes
        # log-likelihoods comparable across models -- a single pass leaves each model at a
        # different distance from its own optimum, and the logdet term then reflects that
        # gap instead of model quality.
        theta = _solve_gls(spec, Z2, YZ, C, ridge=ridge_a)
        n_done = 1
        if gls:
            for it in range(max(int(n_iter), 1)):
                Sigma = noise_cov(theta, g, diagonal=sigma_diagonal, shrinkage=sigma_shrink)
                C = np.linalg.pinv(Sigma)
                new = _solve_gls(spec, Z2, YZ, C, ridge=ridge_a)
                delta = np.linalg.norm(new - theta) / max(np.linalg.norm(new), 1e-12)
                theta, n_done = new, it + 2
                if verbose:
                    print(f"  iter {it + 1}: rel dTheta = {delta:.3e}")
                if delta < tol:
                    break
        Sigma = noise_cov(theta, g, diagonal=sigma_diagonal, shrinkage=sigma_shrink)

    else:
        # ---- E1: alternate the constrained A-step with the (row-separable) B-step.
        Aa = Z2[:Da, :Da]                          # Za Za^T
        Au = Z2[:Da, Da:]                          # Za Zu^T
        Uu = Z2[Da:, Da:]                          # Zu Zu^T
        YZa = YZ[:, :Da]                           # Y Za^T
        YZu = YZ[:, Da:]                           # Y Zu^T

        b_free = bool(bm.all())
        spec_b = None if b_free else make_spec(N, M, 0, K_u, a_mask, bm, sym)
        Uu_reg = Uu + ridge_u * np.eye(Uu.shape[0])
        Bf = np.zeros((N, Uu.shape[0]))
        theta_a = np.zeros((N, Da))
        n_done = 0

        for it in range(max(int(n_iter), 1)):
            theta_a = _solve_gls(spec_a, Aa, YZa - Bf @ Au.T, C, ridge=ridge_a)
            rhs_b = YZu - theta_a @ Au              # (N, Du) = (Y - A Za) Zu^T
            if b_free:
                B_new = np.linalg.solve(Uu_reg.T, rhs_b.T).T
            else:
                B_new = _solve_gls(spec_b, Uu, rhs_b, C, ridge=ridge_u)
            delta = np.linalg.norm(B_new - Bf) / max(np.linalg.norm(B_new), 1e-12)
            Bf = B_new
            n_done = it + 1
            theta = np.concatenate([theta_a, Bf], axis=1)
            if gls:
                Sigma = noise_cov(theta, g, diagonal=sigma_diagonal, shrinkage=sigma_shrink)
                C = np.linalg.pinv(Sigma)
            if verbose:
                print(f"  iter {it + 1}: rel dB = {delta:.3e}")
            if it > 0 and delta < tol:
                break

        theta = np.concatenate([theta_a, Bf], axis=1)
        Sigma = noise_cov(theta, g, diagonal=sigma_diagonal, shrinkage=sigma_shrink)

    A, B = spec.split(theta)
    return dict(A=A, B=B, theta=theta, Sigma=Sigma, spec=spec, grams=g,
                model=model, method=("joint" if joint else "alt"),
                b_mask=bm, a_lags=a_lags, u_lags=u_lags, n_iter=n_done,
                n_free=spec.n_free, N=N, M=M, K_a=K_a, K_u=K_u)


# --------------------------------------------------------------------------------------
# prediction and model summaries
# --------------------------------------------------------------------------------------

def predict(X, U, A, B, a_lags, u_lags):
    """One-step (teacher-forced) prediction.  Returns (Yhat (N, n_fit), t_index)."""
    X = np.asarray(X, float)
    N, T = X.shape
    a_lags, u_lags = list(a_lags), list(u_lags or [])
    lag_max = max([0] + a_lags + u_lags)
    ti = np.arange(lag_max, T)
    Yhat = np.zeros((N, len(ti)))
    for k, L in enumerate(a_lags):
        Yhat += A[:, :, k] @ X[:, ti - L]
    if B is not None and U is not None:
        U = np.asarray(U, float)
        for r, L in enumerate(u_lags):
            Yhat += B[:, :, r] @ U[:, ti - L]
    return Yhat, ti


def input_gain(B):
    """(N, M) direct input gain ||B[i, m, :]||_2 -- how strongly site m drives node i
    *before* any network propagation."""
    return np.linalg.norm(np.asarray(B, float), axis=-1)


def dc_gain(A, B):
    """Steady-state map (I - sum_k A_k)^-1 sum_r B_r, (N, M).

    This is the network-mediated gain: the total displacement of node i per unit sustained
    drive at site m.  Comparing it against `input_gain(B)` separates direct injection from
    propagation -- the whole point of the B-diagonal test.
    """
    A = np.asarray(A, float)
    N = A.shape[0]
    Asum = A.sum(-1)
    Bsum = np.asarray(B, float).sum(-1)
    return np.linalg.solve(np.eye(N) - Asum, Bsum)


def impulse_response(A, B, n_steps, u_lags=None, a_lags=None):
    """Model Green's function: response (n_steps, N, M) to a unit impulse at t = 0.

    Directly comparable to the empirical stim->response tensor H from cross_response.py
    (up to the dF/F scaling and the imaging frame rate).
    """
    A = np.asarray(A, float)
    B = np.asarray(B, float)
    N, _, K_a = A.shape
    M, K_u = B.shape[1], B.shape[2]
    a_lags = list(range(1, K_a + 1)) if a_lags is None else list(a_lags)
    u_lags = list(range(1, K_u + 1)) if u_lags is None else list(u_lags)

    h = np.zeros((n_steps, N, M))
    for t in range(n_steps):
        acc = np.zeros((N, M))
        for k, L in enumerate(a_lags):
            if t - L >= 0:
                acc += A[:, :, k] @ h[t - L]
        for r, L in enumerate(u_lags):
            if t - L == 0:                          # unit impulse at t = 0
                acc += B[:, :, r]
        h[t] = acc
    return h


def spectral_radius(A):
    """Spectral radius of the companion matrix -- < 1 means the fitted AR part is stable."""
    A = np.asarray(A, float)
    N, _, K = A.shape
    comp = np.zeros((N * K, N * K))
    comp[:N] = A.reshape(N, N * K, order="F")
    if K > 1:
        comp[N:, :-N] = np.eye(N * (K - 1))
    return float(np.max(np.abs(np.linalg.eigvals(comp))))


# --------------------------------------------------------------------------------------
# self-test
# --------------------------------------------------------------------------------------

def _ring_adj(N):
    adj = np.zeros((N, N), bool)
    for i in range(N):
        adj[i, (i + 1) % N] = adj[(i + 1) % N, i] = True
    return adj


def _make_truth(N, K_a, adj, rho=0.85, seed=0):
    rng = np.random.default_rng(seed)
    A = np.zeros((N, N, K_a))
    mask = adj | np.eye(N, dtype=bool)
    for k in range(K_a):
        W = rng.normal(0, 1, (N, N)) * mask
        W = 0.5 * (W + W.T) / (k + 1) ** 2
        A[:, :, k] = W
    # Scaling every A_k by c does not scale the companion eigenvalues by c when K_a > 1,
    # so hit the target radius by fixed-point iteration rather than a single division.
    for _ in range(50):
        r = spectral_radius(A)
        if abs(r - rho) < 1e-9:
            break
        A *= rho / r
    return A


def _simulate(A, B, U, noise, seed=0):
    rng = np.random.default_rng(seed)
    N, _, K_a = A.shape
    K_u = 0 if B is None else B.shape[2]
    T = U.shape[1]
    X = np.zeros((N, T))
    L = np.linalg.cholesky(noise) if noise.ndim == 2 else None
    for t in range(max(K_a, K_u), T):
        x = L @ rng.normal(size=N)
        for k in range(K_a):
            x += A[:, :, k] @ X[:, t - k - 1]
        for r in range(K_u):
            x += B[:, :, r] @ U[:, t - r - 1]
        X[:, t] = x
    return X


def _selftest():
    rng = np.random.default_rng(7)
    N, M, K_a, K_u, T = 8, 3, 3, 2, 20000
    adj = _ring_adj(N)
    A_true = _make_truth(N, K_a, adj, rho=0.85, seed=1)

    B_true = np.zeros((N, M, K_u))
    drive = [0, 3, 6]                                  # each input drives one node ...
    for m, i in enumerate(drive):
        B_true[i, m, 0] = 2.0
        B_true[i, m, 1] = -0.8
    U = np.zeros((M, T))
    for m in range(M):                                  # sparse impulse train
        U[m, rng.choice(T, size=T // 60, replace=False)] = 1.0

    noise = 0.05 * np.eye(N)
    X = _simulate(A_true, B_true, U, noise, seed=2)
    tr, te = block_split(T - max(K_a, K_u), test_frac=0.25, n_blocks=20)
    ok = True

    def check(label, cond, detail=""):
        nonlocal ok
        ok &= bool(cond)
        print(f"  [{'PASS' if cond else 'FAIL'}] {label}{('  ' + detail) if detail else ''}")

    print(f"\nsynthetic ring: N={N} M={M} K_a={K_a} K_u={K_u} T={T}, "
          f"rho(A_true)={spectral_radius(A_true):.3f}")

    # 1. E0 -- unconstrained OLS recovers A and B.
    f0 = fit_gdarx(X, U, K_a=K_a, K_u=K_u, model="ols", b_mask="free",
                   method="joint", gls=False)
    eA = np.linalg.norm(f0["A"] - A_true) / np.linalg.norm(A_true)
    eB = np.linalg.norm(f0["B"] - B_true) / np.linalg.norm(B_true)
    print("\nE0  unconstrained OLS")
    # Looser tolerance than the constrained fits below: unconstrained A carries N^2 K_a
    # parameters against the constrained (N + E) K_a, so it is the noisier estimator.
    check("A recovered", eA < 0.08, f"rel err {eA:.2e}")
    check("B recovered", eB < 0.05, f"rel err {eB:.2e}")

    # 2. E1 -- graph+symmetry constrained A with a free B, on the same truth.
    f1 = fit_gdarx(X, U, adj=adj, K_a=K_a, K_u=K_u, model="gdar", b_mask="free",
                   method="alt", n_iter=4, gls=True)
    eA = np.linalg.norm(f1["A"] - A_true) / np.linalg.norm(A_true)
    eB = np.linalg.norm(f1["B"] - B_true) / np.linalg.norm(B_true)
    print(f"\nE1  GDAR + free B   ({f1['n_free']} free params, {f1['n_iter']} iters)")
    check("A recovered", eA < 0.05, f"rel err {eA:.2e}")
    check("B recovered", eB < 0.05, f"rel err {eB:.2e}")
    check("symmetry enforced",
          np.allclose(f1["A"], np.transpose(f1["A"], (1, 0, 2))))
    check("off-graph entries are exactly zero",
          np.abs(f1["A"][~(adj | np.eye(N, dtype=bool))]).max() == 0.0)
    check("stable", spectral_radius(f1["A"]) < 1.0,
          f"rho={spectral_radius(f1['A']):.3f}")

    # 3. E2 -- joint constrained GLS with a restricted (site-local) B.
    bmask = np.zeros((N, M), bool)
    for m, i in enumerate(drive):
        bmask[i, m] = True
    f2 = fit_gdarx(X, U, adj=adj, K_a=K_a, K_u=K_u, model="gdar", b_mask=bmask,
                   method="joint", gls=True)
    eB = np.linalg.norm(f2["B"] - B_true) / np.linalg.norm(B_true)
    print(f"\nE2  joint constrained GLS, restricted B  ({f2['n_free']} free params)")
    check("B recovered", eB < 0.05, f"rel err {eB:.2e}")
    check("restricted support honoured", np.abs(f2["B"][~bmask]).max() == 0.0)
    check("E2 fits no worse than E1 in-sample",
          np.trace(resid_moment(f2["theta"], f2["grams"]))
          <= np.trace(resid_moment(f1["theta"], f1["grams"])) * 1.02)

    # 4. zero input -> B must collapse to (numerically) zero.
    fz = fit_gdarx(X, np.zeros_like(U), adj=adj, K_a=K_a, K_u=K_u, model="gdar",
                   b_mask="free", method="alt", n_iter=2, gls=False)
    print("\nzero-input control")
    check("||B|| ~ 0 when u == 0", np.abs(fz["B"]).max() < 1e-8,
          f"max |B| = {np.abs(fz['B']).max():.2e}")

    # 5. held-out predictive likelihood: the input term must earn its keep.
    ftr = fit_gdarx(X, U, adj=adj, K_a=K_a, K_u=K_u, model="gdar", b_mask="free",
                    method="alt", n_iter=3, gls=True, keep=tr)
    g_te = grams(X, U, ftr["a_lags"], ftr["u_lags"], keep=te)
    d = delta_loglik(ftr["theta"], g_te, ftr["Sigma"])
    print("\nheld-out (train on 75% of contiguous blocks, score on the rest)")
    check("delta loglik > 0", d["delta_mean"] > 0,
          f"delta/sample = {d['delta_mean']:.3f}  (n_test = {d['n']})")
    vaf_u = vaf_from_grams(ftr["theta"], g_te)
    vaf_0 = vaf_from_grams(_zero_input(ftr["theta"], g_te), g_te)
    check("held-out VAF improves at the driven nodes",
          np.all(vaf_u[drive] > vaf_0[drive]),
          f"mean VAF {vaf_0.mean():.3f} -> {vaf_u.mean():.3f}")

    # 6. impulse response / DC gain sanity.
    h = impulse_response(f1["A"], f1["B"], 40)
    h_true = impulse_response(A_true, B_true, 40)
    e = np.linalg.norm(h - h_true) / np.linalg.norm(h_true)
    print("\nmodel summaries")
    check("impulse response matches truth", e < 0.05, f"rel err {e:.2e}")
    check("DC gain finite", np.all(np.isfinite(dc_gain(f1["A"], f1["B"]))))

    # 7. graph builder on the real AL_0048 grid geometry.
    xs = np.arange(-3.5, 4.0, 1.0)
    ys = np.arange(-4.0, 4.0, 1.0)
    sites = np.array([(x, y) for y in ys for x in xs])[:52]
    a8 = lattice_graph(sites, 8)
    a4 = lattice_graph(sites, 4)
    print("\ngrid lattice geometry")
    check("adjacency symmetric, hollow",
          np.array_equal(a8, a8.T) and not a8.diagonal().any())
    check("8-conn strictly contains 4-conn",
          np.all(a8 | a4 == a8) and a8.sum() > a4.sum(),
          f"{a4.sum() // 2} vs {a8.sum() // 2} edges over {len(sites)} sites")
    check("midline split removes cross-hemisphere edges",
          lattice_graph(sites, 8, bridge_midline=False).sum() < a8.sum())

    print("\n" + ("ALL TESTS PASSED" if ok else "SOME TESTS FAILED"))
    return ok


if __name__ == "__main__":
    import sys
    sys.exit(0 if _selftest() else 1)
