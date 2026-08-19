"""Model G -- free-topology VARX on the AL_0048 grid: let the data pick the edges.

Same state/input as `gdarx_grid.py`, same lags, same diagonal-Sigma noise model and the same
contiguous-block split, so every number here is directly comparable to that table.  The one
change is the A support: instead of `lattice_graph`'s 8-connectivity mask, every off-diagonal
edge is available and a group lasso decides which survive.

    min_theta_i  0.5 ||y_i - theta_i' z||^2  +  lam * sum_{j != i} sqrt(K_a) ||A_{ij,.}||_2
                                             +  0.5 * ridge * ||theta_i||^2

The group is the K_a lags of one directed edge j -> i, so the penalty selects EDGES, not
lags (the standard Granger group lasso).  Two things are deliberately left unpenalised:

  * the self terms A_{ii,.} -- node dynamics are not in question here, and shrinking them
    would push the fit toward explaining everything with coupling;
  * the whole B block -- sparsifying B would bias the fit toward local injection, which is
    exactly the question the dual-opsin overlap hypothesis is asking.  B is ridged only.

Why this is cheap: with a diagonal Sigma the N equations separate exactly (see
`gdar_x.noise_cov`), so this is N independent group-lasso problems sharing one D x D Gram,
and D is only N*K_a + M*K_u = 520.  Everything below runs off precomputed second moments --
after one pass to build the per-block Grams there is no further contact with the data.

    .venv/Scripts/python.exe bilateral/grid/freegraph.py

Read the recovered graph with care.  cov(X) has rank 50 of 52 (`cross_response.py` rebuilds
the ROIs from a 50-component SVD basis), so the design has a null space and *some* support
is unidentifiable no matter how good the estimator.  That is what the stability-selection
pass is for: an edge that only appears in a minority of block subsamples is a coefficient
the data cannot place, not a connection.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection

import gdar_x
import gdarx_grid

DATA = Path(__file__).resolve().parents[2] / "data"
PNG = Path(__file__).resolve().parent / "network_png"
RESULT = DATA / "grid_freegraph.npz"

K_A, K_U = gdarx_grid.K_A, gdarx_grid.K_U
N_BLOCKS = 20
TEST_FRAC = 0.2


# --------------------------------------------------------------------------------------
# block Grams: one data pass, then every subsample is a sum of blocks
# --------------------------------------------------------------------------------------

def block_grams(X, U, a_lags, u_lags, n_blocks=N_BLOCKS, verbose=True):
    """Per-block second moments plus the block id of every fit column.

    Splitting the record into contiguous blocks and accumulating each one separately means
    the train Gram, the test Gram and every stability-selection subsample are *sums of
    blocks* -- computed once, combined for free.  The alternative (re-running `grams` per
    subsample) is a full O(D^2 T) pass each time.
    """
    T = X.shape[1]
    lag_max = max(a_lags + u_lags)
    n_fit = T - lag_max
    blk = (np.arange(n_fit) * n_blocks) // n_fit
    out = []
    for b in range(n_blocks):
        out.append(gdar_x.grams(X, U, a_lags, u_lags, keep=(blk == b)))
        if verbose:
            print(f"\r  block {b + 1}/{n_blocks}", end="", flush=True)
    if verbose:
        print()
    return out, blk


def combine(gl, which):
    """Sum a subset of block Grams into one Gram dict."""
    which = list(which)
    g0 = gl[which[0]]
    out = {k: sum(gl[b][k] for b in which) for k in ("Z2", "ZY", "YY", "Ysum", "n")}
    for k in ("n_fit", "N", "M", "K_a", "K_u", "D", "Da", "a_lags", "u_lags", "lag_max"):
        out[k] = g0[k]
    out["n"] = int(out["n"])
    return out


# --------------------------------------------------------------------------------------
# the group-lasso solve
# --------------------------------------------------------------------------------------

def _scale(g):
    """Unit-rms regressors and unit-sd targets, so one lam is comparable across equations.

    The A and B blocks live on completely different scales (percent dF/F against an impulse
    train that is zero 88% of the time), and a group lasso is not scale invariant -- without
    this the penalty would be an arbitrary function of the units.
    """
    n = g["n"]
    d = np.sqrt(np.diag(g["Z2"]) / n)
    d[d <= 0] = 1.0
    var_y = np.diag(g["YY"]) / n - (g["Ysum"] / n) ** 2
    sig = np.sqrt(np.maximum(var_y, np.finfo(float).tiny))
    S = 1.0 / d
    Q = (g["Z2"] * S[:, None] * S[None, :]) / n
    R = (g["ZY"] * S[:, None]) / n / sig[None, :]
    return Q, R, S, sig


def _free_cols(g):
    """Column indices that are never penalised, per equation: own lags + the whole B block."""
    N, Da, D, K_a = g["N"], g["Da"], g["D"], g["K_a"]
    bcols = np.arange(Da, D)
    return [np.r_[[k * N + i for k in range(K_a)], bcols] for i in range(N)]


def _solve_free(Q, R, cols, ridge):
    """Unpenalised-only solution (self lags + B), one equation at a time."""
    Theta = np.zeros(R.shape)
    for i, c in enumerate(cols):
        Qc = Q[np.ix_(c, c)] + ridge * np.eye(len(c))
        Theta[c, i] = np.linalg.solve(Qc, R[c, i])
    return Theta


def _group_norms(Theta, N, K_a):
    """||A_{ij,.}||_2 per (j, equation) from the stacked scaled coefficients."""
    return np.linalg.norm(Theta[:N * K_a].reshape(K_a, N, -1), axis=0)


def fit_group_lasso(g, lam, ridge=1e-4, max_iter=400, tol=1e-7, Theta0=None,
                    Q=None, R=None, L=None):
    """FISTA for the N per-equation group lassos, vectorised across equations.

    `lam` is a per-equation vector in the scaled parameterisation.  Returns the scaled
    coefficient matrix (D, N); use `unscale` for coefficients in data units.
    """
    if Q is None:
        Q, R, _, _ = _scale(g)
    N, K_a, Da = g["N"], g["K_a"], g["Da"]
    if L is None:
        L = float(np.linalg.eigvalsh(Q)[-1]) + ridge
    step = 1.0 / L
    thr0 = step * np.sqrt(K_a) * np.asarray(lam, float)[None, :] * np.ones((N, 1))
    np.fill_diagonal(thr0, 0.0)                     # self terms are never penalised

    Th = np.zeros(R.shape) if Theta0 is None else np.array(Theta0, float, copy=True)
    Y = Th.copy()
    t = 1.0
    for _ in range(max_iter):
        G = Q @ Y - R + ridge * Y
        Z = Y - step * G
        A = Z[:Da].reshape(K_a, N, -1)
        nrm = np.linalg.norm(A, axis=0)
        scale = np.maximum(0.0, 1.0 - thr0 / np.maximum(nrm, 1e-300))
        Z[:Da] = (A * scale[None]).reshape(Da, -1)
        t_new = 0.5 * (1 + np.sqrt(1 + 4 * t * t))
        Y = Z + ((t - 1) / t_new) * (Z - Th)
        delta = np.max(np.abs(Z - Th))
        Th, t = Z, t_new
        if delta < tol:
            break
    return Th


def unscale(Theta_s, S, sig):
    """Scaled (D, N) coefficients -> theta (N, D) in data units, as `gdar_x` expects."""
    return (Theta_s * S[:, None] * sig[None, :]).T


def debias(g, support, ridge, Q=None, R=None, S=None, sig=None):
    """Refit without the penalty on the selected support (lasso shrinkage removed).

    The lasso is used as a selector only.  Its coefficients are biased toward zero by
    construction, so any magnitude read off the penalised fit -- edge weight, coupling vs
    self term -- would be an underestimate of whatever the support implies.
    """
    if Q is None:
        Q, R, S, sig = _scale(g)
    N, K_a, Da, D = g["N"], g["K_a"], g["Da"], g["D"]
    free = _free_cols(g)
    Theta = np.zeros((D, N))
    for i in range(N):
        js = np.nonzero(support[:, i])[0]
        extra = np.array([k * N + j for j in js for k in range(K_a)], int)
        c = np.unique(np.r_[free[i], extra]).astype(int)
        Qc = Q[np.ix_(c, c)] + ridge * np.eye(len(c))
        Theta[c, i] = np.linalg.solve(Qc, R[c, i])
    return Theta


# --------------------------------------------------------------------------------------
# scoring
# --------------------------------------------------------------------------------------

def score(theta, g_tr, g_te, sigma_shrink=1e-6):
    """Held-out one-step scores, computed exactly as `gdarx_grid.run` does."""
    N = g_te["N"]
    Sigma = gdar_x.noise_cov(theta, g_tr, diagonal=True, shrinkage=sigma_shrink)
    ell, ell_mean = gdar_x.loglik_from_grams(theta, g_te, Sigma)
    R_te = gdar_x.resid_moment(theta, g_te)
    Rn = R_te / g_te["n"]
    A, B = _split(theta, g_te)
    return dict(ell_mean=ell_mean, ell=ell,
                mse=float(np.trace(R_te) / g_te["n"] / N),
                logdet=float(np.log(np.diag(Rn)).sum()),
                vaf=float(np.nanmean(gdar_x.vaf_from_grams(theta, g_te))),
                rho=gdar_x.spectral_radius(A),
                dell=gdar_x.delta_loglik(theta, g_te, Sigma)["delta_mean"])


def _split(theta, g):
    N, M, K_a, K_u, Da = g["N"], g["M"], g["K_a"], g["K_u"], g["Da"]
    A = np.stack([theta[:, k * N:(k + 1) * N] for k in range(K_a)], -1)
    B = np.stack([theta[:, Da + r * M:Da + (r + 1) * M] for r in range(K_u)], -1)
    return A, B


def ebic(theta, g, support, gamma=0.5):
    """Extended BIC, summed over equations -- a selector that can actually stop.

    Held-out one-step likelihood does NOT select a sparse graph on this data (it improves
    monotonically to the complete graph, converging on the unconstrained VARX), because any
    correlated channel improves a one-step prediction whether or not it is a connection.
    eBIC (Chen & Chen 2008) adds the 2*gamma*log(p) term that plain BIC lacks, which is the
    term that matters when the number of CANDIDATE edges p is large relative to n.
    """
    N, n, K_a = g["N"], g["n"], g["K_a"]
    rss = np.diag(gdar_x.resid_moment(theta, g))
    p = N - 1                                            # candidate edges per equation
    df = support.sum(0) * K_a + K_a + g["M"] * g["K_u"]  # selected + self lags + B
    val = n * np.log(rss / n) + df * (np.log(n) + 2 * gamma * np.log(max(p, 2)))
    return float(val.sum())


def spatial_stats(sup, sites, rng=None, n_null=200):
    """Mean edge length and cross-midline fraction of a support, against a random-support null.

    A recovered graph that is indistinguishable from a random set of edges of the same size
    has no spatial structure, whatever its held-out score says.
    """
    N = len(sites)
    dist = np.linalg.norm(sites[:, None, :] - sites[None, :, :], axis=-1)
    cross = np.sign(sites[:, 0])[:, None] != np.sign(sites[:, 0])[None, :]
    eye = np.eye(N, dtype=bool)
    k = int(sup.sum())
    if k == 0:
        return dict(k=0, mean_dist=np.nan, cross_frac=np.nan, null_dist=np.nan,
                    null_cross=np.nan, z_dist=np.nan)
    cand = np.nonzero(~eye)
    rng = np.random.default_rng(0) if rng is None else rng
    nd = np.empty(n_null)
    for s in range(n_null):
        pick = rng.choice(len(cand[0]), size=min(k, len(cand[0])), replace=False)
        nd[s] = dist[cand[0][pick], cand[1][pick]].mean()
    md = float(dist[sup].mean())
    return dict(k=k, mean_dist=md, cross_frac=float(cross[sup].mean()),
                null_dist=float(nd.mean()), null_cross=float(cross[~eye].mean()),
                z_dist=float((md - nd.mean()) / max(nd.std(), 1e-12)))


# --------------------------------------------------------------------------------------
# driver
# --------------------------------------------------------------------------------------

def remove_global(X, k=1, verbose=True):
    """Project out the top-k principal components of the channel set.

    A dense, distance-indifferent, midline-indifferent coupling matrix is exactly what a
    shared component across all ROIs produces -- widefield hemodynamics and global brain
    state both do this, and neither is point-to-point connectivity.  Refitting without the
    leading PC is the cheap decisive test: if the recovered graph does not sparsify or
    localise, the density is not an artefact of a global mode.
    """
    X = np.asarray(X, float)
    Xc = X - X.mean(1, keepdims=True)
    U_, s, _ = np.linalg.svd(Xc @ Xc.T)
    P = U_[:, :k]
    frac = float(s[:k].sum() / s.sum())
    if verbose:
        print(f"removing top-{k} PC(s): {frac:.1%} of channel covariance, "
              f"loading sd across nodes {P[:, 0].std():.3f} "
              f"(uniform would be {1 / np.sqrt(len(X)):.3f})")
    return X - P @ (P.T @ X), frac


def subset_nodes(d, keep, verbose=True):
    """Restrict state, input channels and sites to a node mask.

    Input channels are dropped alongside their site: a stim delivered to a discarded node is
    no longer a channel the model has a readout for, and keeping it would let B soak up
    responses at sites that are not in the state.
    """
    keep = np.asarray(keep, bool)
    soi = np.asarray(d["site_of_input"], int)
    kc = keep[soi]
    remap = -np.ones(len(keep), int)
    remap[np.nonzero(keep)[0]] = np.arange(int(keep.sum()))
    out = dict(d)
    out["X"] = d["X"][keep]
    out["U"] = d["U"][kc]
    out["sites"] = d["sites"][keep]
    out["site_of_input"] = remap[soi[kc]]
    if "amp_of_input" in d:
        out["amp_of_input"] = np.asarray(d["amp_of_input"], float)[kc]
    if verbose:
        print(f"subset: {int(keep.sum())} nodes, {int(kc.sum())} input channels "
              f"(dropped {int((~keep).sum())} nodes / {int((~kc).sum())} channels)")
    return out


def run(d=None, n_lam=18, lam_lo=0.005, ridge=1e-4, n_sub=20, sub_frac=0.5,
        stab_thresh=0.6, seed=0, save=True, verbose=True, drop_pcs=0, interior=False,
        roi=False, tag=""):
    d = gdarx_grid.load() if d is None else d
    if roi:
        import roi_nodes
        d = subset_nodes(d, roi_nodes.load_mask(d["sites"], verbose=verbose),
                         verbose=verbose)
    elif interior:
        d = subset_nodes(d, gdar_x.interior_nodes(d["sites"], verbose=verbose),
                         verbose=verbose)
    X, U, sites = d["X"], d["U"], d["sites"]
    if drop_pcs:
        X, _ = remove_global(X, drop_pcs, verbose=verbose)
    N = X.shape[0]
    rep = gdar_x.condition_report(X)
    if verbose:
        print(f"channels: effective rank {rep['rank']}/{rep['N']}, cond {rep['cond']:.1e}, "
              f"99% of variance in {rep['n_99']} components"
              + ("  <- rank deficient" if rep["deficient"] else "  <- FULL RANK"))
    a_lags = list(range(1, K_A + 1))
    u_lags = list(range(0, K_U))
    adj = gdar_x.lattice_graph(sites, connectivity=8, bridge_midline=True)

    if verbose:
        print(f"N={N} nodes, M={U.shape[0]} inputs, D={N * K_A + U.shape[0] * K_U}")
        print(f"accumulating {N_BLOCKS} block Grams (one pass) ...")
    gl, blk = block_grams(X, U, a_lags, u_lags, verbose=verbose)

    stride = max(int(round(1.0 / TEST_FRAC)), 2)
    te_blocks = [b for b in range(N_BLOCKS) if b % stride == stride - 1]
    tr_blocks = [b for b in range(N_BLOCKS) if b not in te_blocks]
    g_tr, g_te = combine(gl, tr_blocks), combine(gl, te_blocks)
    if verbose:
        print(f"train {g_tr['n']} frames ({len(tr_blocks)} blocks) / "
              f"test {g_te['n']} ({len(te_blocks)})")

    Q, R, S, sig = _scale(g_tr)
    L = float(np.linalg.eigvalsh(Q)[-1]) + ridge
    free = _free_cols(g_tr)

    # lam_max: the smallest penalty that leaves the graph empty, measured at the
    # unpenalised (self + B only) solution rather than at zero, so the path really does
    # start from "no edges".
    Th_free = _solve_free(Q, R, free, ridge)
    G0 = Q @ Th_free - R + ridge * Th_free
    gn0 = _group_norms(G0, N, K_A) / np.sqrt(K_A)
    np.fill_diagonal(gn0, 0.0)
    lam_max = gn0.max(0)
    if verbose:
        print(f"lam_max per equation: {lam_max.min():.4g} - {lam_max.max():.4g}")

    fracs = np.geomspace(1.0, lam_lo, n_lam)
    rng = np.random.default_rng(seed)
    k_sub = max(2, int(round(sub_frac * len(tr_blocks))))
    subs = [rng.choice(tr_blocks, size=k_sub, replace=False) for _ in range(n_sub)]
    g_subs = [combine(gl, p) for p in subs]
    pre = []
    for g_s in g_subs:                                    # per-subsample scaling, once
        Qs, Rs, Ss, sgs = _scale(g_s)
        Ls = float(np.linalg.eigvalsh(Qs)[-1]) + ridge
        Th0 = _solve_free(Qs, Rs, _free_cols(g_s), ridge)
        Gs = Qs @ Th0 - Rs + ridge * Th0
        gns = _group_norms(Gs, N, K_A) / np.sqrt(K_A)
        np.fill_diagonal(gns, 0.0)
        pre.append(dict(g=g_s, Q=Qs, R=Rs, L=Ls, lam_max=gns.max(0), Th=Th0))

    rows, thetas, supports, freqs = [], [], [], []
    Th = Th_free
    for fr in fracs:
        Th = fit_group_lasso(g_tr, lam_max * fr, ridge=ridge, Theta0=Th, Q=Q, R=R, L=L)
        sup = _group_norms(Th, N, K_A) > 0
        np.fill_diagonal(sup, False)
        Th_d = debias(g_tr, sup, ridge, Q, R, S, sig)
        theta = unscale(Th_d, S, sig)
        sc = score(theta, g_tr, g_te)
        sc.update(frac=float(fr), n_edges=int(sup.sum()),
                  ebic=ebic(theta, g_tr, sup), **spatial_stats(sup, sites))

        # stability selection at THIS lam, not only at the CV pick: the selection frequency
        # of an edge is a property of the operating point, and the CV point here is the
        # complete graph, where every edge is trivially "stable".
        fq = np.zeros((N, N))
        for p in pre:
            # the SAME absolute lam as the full fit, not the subsample's own lam_max --
            # otherwise the supports are not nested with it and "stable" can exceed
            # "selected", which is meaningless.
            Th_s = fit_group_lasso(p["g"], lam_max * fr, ridge=ridge,
                                   Theta0=p["Th"], Q=p["Q"], R=p["R"], L=p["L"])
            s_s = _group_norms(Th_s, N, K_A) > 0
            np.fill_diagonal(s_s, False)
            fq += s_s
        fq /= len(pre)
        sc["n_stable"] = int((fq >= stab_thresh).sum())

        rows.append(sc); thetas.append(theta); supports.append(sup); freqs.append(fq)
        if verbose:
            print(f"  lam/lam_max {fr:7.4f}  edges {sup.sum():5d} (stable {sc['n_stable']:5d})"
                  f"  MSE {sc['mse']:.5f}  ell {sc['ell_mean']:8.3f}  rho {sc['rho']:.3f}"
                  f"  eBIC {sc['ebic']:11.0f}  dist {sc['mean_dist']:.2f} vs null "
                  f"{sc['null_dist']:.2f} (z {sc['z_dist']:+.1f})")

    best = int(np.argmax([r["ell_mean"] for r in rows]))
    best_ebic = int(np.argmin([r["ebic"] for r in rows]))
    # A third operating point, chosen by neither criterion: the lam whose support is the
    # same SIZE as the lattice.  Neither selector wants a graph this sparse, but it is the
    # only apples-to-apples comparison against the imposed 8-connectivity mask -- same
    # number of edges, chosen by the data instead of by geometry.
    n_lat = int((adj & ~np.eye(N, dtype=bool)).sum())
    match = int(np.argmin([abs(r["n_edges"] - n_lat) for r in rows]))
    if verbose:
        print(f"\nheld-out ell picks lam/lam_max={fracs[best]:.4f}: "
              f"{rows[best]['n_edges']} of {N * (N - 1)} possible edges "
              f"({rows[best]['n_edges'] / (N * (N - 1)):.0%}) "
              f"-- ell is monotone in edge count, so this is the dense limit")
        print(f"eBIC picks       lam/lam_max={fracs[best_ebic]:.4f}: "
              f"{rows[best_ebic]['n_edges']} edges")

    sup_stab = freqs[best_ebic] >= stab_thresh
    theta_stab = unscale(debias(g_tr, sup_stab, ridge, Q, R, S, sig), S, sig)
    sc_stab = score(theta_stab, g_tr, g_te)
    sc_stab.update(frac=float(fracs[best_ebic]), n_edges=int(sup_stab.sum()),
                   **spatial_stats(sup_stab, sites))
    if verbose:
        print(f"stable support at the eBIC lam (freq >= {stab_thresh:g}): "
              f"{sup_stab.sum()} edges, MSE {sc_stab['mse']:.5f}, "
              f"ell {sc_stab['ell_mean']:.3f}, rho {sc_stab['rho']:.3f}")

    out = dict(fracs=fracs, rows=rows, best=best, best_ebic=best_ebic, match=match,
               theta=thetas[best_ebic], support=supports[best_ebic],
               theta_match=thetas[match], support_match=supports[match],
               freq_match=freqs[match], n_lat=n_lat,
               theta_cv=thetas[best], support_cv=supports[best],
               freq=freqs[best_ebic], freqs=freqs, support_stable=sup_stab,
               theta_stable=theta_stab, score_stable=sc_stab, adj=adj, sites=sites,
               g_tr=g_tr, g_te=g_te, lam_max=lam_max, ridge=ridge,
               stab_thresh=stab_thresh, drop_pcs=drop_pcs, tag=tag)
    if save:
        np.savez_compressed(
            RESULT.with_name(RESULT.stem + tag + RESULT.suffix),
            fracs=fracs, best=best, best_ebic=best_ebic, match=match,
            theta_match=thetas[match], support_match=supports[match],
            theta=thetas[best_ebic], support=supports[best_ebic],
            theta_cv=thetas[best], support_cv=supports[best],
            freq=freqs[best_ebic], support_stable=sup_stab, theta_stable=theta_stab,
            adj=adj, sites=sites, lam_max=lam_max, ridge=ridge, stab_thresh=stab_thresh,
            **{k: np.array([r[k] for r in rows]) for k in
               ("n_edges", "n_stable", "ell_mean", "mse", "rho", "ebic",
                "mean_dist", "null_dist", "cross_frac", "z_dist")})
        print(f"saved -> {RESULT.stem + tag + RESULT.suffix}")
    return out


# --------------------------------------------------------------------------------------
# report
# --------------------------------------------------------------------------------------

def lattice_report(sup, adj, sites, label="selected", verbose=True):
    N = len(sites)
    eye = np.eye(N, dtype=bool)
    und = sup | sup.T                                   # undirected footprint
    lat = adj & ~eye
    hit = int((und & lat).sum() // 2)
    tot_lat = int(lat.sum() // 2)
    offl = int((und & ~lat & ~eye).sum() // 2)
    cross = np.sign(sites[:, 0])[:, None] != np.sign(sites[:, 0])[None, :]
    n_cross = int((sup & cross).sum())
    dist = np.linalg.norm(sites[:, None, :] - sites[None, :, :], axis=-1)
    md = float(dist[sup].mean()) if sup.any() else np.nan
    if verbose:
        print(f"\n{label}: {int(sup.sum())} directed edges "
              f"({int(und.sum() // 2)} undirected)")
        print(f"  lattice edges recovered   {hit}/{tot_lat} ({hit / tot_lat:.0%})")
        print(f"  off-lattice edges chosen  {offl}  "
              f"({offl / max(int(und.sum() // 2), 1):.0%} of the graph)")
        print(f"  crossing the midline      {n_cross} of {int(sup.sum())} "
              f"({n_cross / max(int(sup.sum()), 1):.0%})")
        print(f"  mean edge length          {md:.2f} mm "
              f"(lattice edges are <= {np.sqrt(2) * 1.0:.2f} mm)")
    return dict(hit=hit, tot_lat=tot_lat, offlattice=offl, cross=n_cross, mean_dist=md)


def figure(res, out=None):
    sites, adj = res["sites"], res["adj"]
    N = len(sites)
    eye = np.eye(N, dtype=bool)
    rows, fracs, best = res["rows"], res["fracs"], res["best"]
    sup, freq, sup_st = res["support"], res["freq"], res["support_stable"]
    A_sum = _split(res["theta_stable"], res["g_te"])[0].sum(-1)
    dist = np.linalg.norm(sites[:, None, :] - sites[None, :, :], axis=-1)
    lat = adj & ~eye

    be = res["best_ebic"]

    fig, ax = plt.subplots(2, 3, figsize=(15, 9.2))
    fig.suptitle("Model G — free-topology VARX: which edges does the data pick?", fontsize=12)

    # A: regularisation path -- two selectors that disagree completely
    a = ax[0, 0]
    ne = [r["n_edges"] for r in rows]
    ell = [r["ell_mean"] for r in rows]
    eb = [r["ebic"] for r in rows]
    a.semilogx(fracs, ell, "o-", color="tab:blue", ms=4, label="held-out log-lik")
    a.axvline(fracs[best], color="tab:blue", ls="--", lw=0.9)
    a.axvline(fracs[be], color="tab:red", ls="--", lw=0.9)
    a.set_xlabel("lam / lam_max", fontsize=8)
    a.set_ylabel("held-out log-lik / sample", color="tab:blue", fontsize=8)
    a2 = a.twinx()
    a2.semilogx(fracs, eb, "s-", color="tab:red", ms=3)
    a2.set_ylabel("eBIC (lower = better)", color="tab:red", fontsize=8)
    a.set_title(f"A. the two selectors disagree by 2 orders of magnitude\n"
                f"held-out ell -> {ne[best]} edges (dense limit); "
                f"eBIC -> {ne[be]} edges", fontsize=9)

    # B: the selected graph at the lattice-matched operating point (the dense selectors'
    # supports are a hairball and say nothing to the eye)
    a = ax[0, 1]
    mi = res["match"]
    sup_m = res["support_match"]
    A_m = _split(res["theta_match"], res["g_te"])[0].sum(-1)
    ii, jj = np.nonzero(sup_m)
    w = A_m[ii, jj]
    vmax = float(np.percentile(np.abs(w), 98)) if len(w) else 1.0
    seg = np.stack([sites[jj], sites[ii]], 1)
    on_lat = lat[ii, jj]
    lc = LineCollection(seg, array=w, cmap="RdBu_r", norm=plt.Normalize(-vmax, vmax),
                        linewidths=0.3 + 2.5 * np.abs(w) / max(vmax, 1e-12), zorder=2)
    a.add_collection(lc)
    a.scatter(sites[:, 0], sites[:, 1], c="0.75", s=55, ec="k", lw=0.3, zorder=3)
    a.axvline(0, color="0.55", ls="--", lw=0.8)
    fig.colorbar(lc, ax=a, fraction=0.045).set_label("sum_k A_k[i,j]", fontsize=7)
    a.set_aspect("equal"); a.set_xticks([]); a.set_yticks([])
    a.set_title(f"B. the learned graph at LATTICE SIZE ({sup_m.sum()} edges vs "
                f"{res['n_lat']} lattice)\nchosen by neither selector — only "
                f"{int(on_lat.sum())} of them are lattice edges", fontsize=9)
    a.autoscale_view()

    # C: edge weight vs distance -- a result, not an assumption
    a = ax[0, 2]
    a.scatter(dist[sup_st & lat], np.abs(A_sum[sup_st & lat]), s=12, c="tab:orange",
              label="on lattice")
    a.scatter(dist[sup_st & ~lat], np.abs(A_sum[sup_st & ~lat]), s=12, c="tab:blue",
              label="off lattice")
    a.axvline(np.sqrt(2), color="0.5", ls="--", lw=0.8)
    a.text(np.sqrt(2), a.get_ylim()[1], " 8-conn radius", fontsize=6.5, va="top")
    a.set_xlabel("inter-site distance (mm)", fontsize=8)
    a.set_ylabel("|sum_k A_k[i,j]|", fontsize=8)
    a.legend(fontsize=7, frameon=False)
    a.set_title("C. coupling vs distance — measured, not imposed", fontsize=9)

    # D: does the recovered support have ANY spatial structure?
    a = ax[1, 0]
    md = [r["mean_dist"] for r in rows]
    nd = [r["null_dist"] for r in rows]
    a.semilogx(fracs, md, "o-", color="tab:green", ms=4, label="selected edges")
    a.semilogx(fracs, nd, "--", color="0.5", lw=1.2, label="random support, same size")
    a.axvline(fracs[be], color="tab:red", ls="--", lw=0.9)
    a.set_xlabel("lam / lam_max", fontsize=8)
    a.set_ylabel("mean edge length (mm)", fontsize=8)
    a.legend(fontsize=7, frameon=False)
    a.set_title(f"D. spatial structure vs a random-support null\n"
                f"at the eBIC point: {rows[be]['mean_dist']:.2f} mm vs null "
                f"{rows[be]['null_dist']:.2f} (z = {rows[be]['z_dist']:+.1f})", fontsize=9)

    # E: stability path
    a = ax[1, 1]
    a.loglog(fracs, np.maximum(ne, 0.5), "o-", color="tab:orange", ms=4, label="selected")
    a.loglog(fracs, np.maximum([r["n_stable"] for r in rows], 0.5), "s-",
             color="tab:purple", ms=4, label=f"stable (freq>={res['stab_thresh']:g})")
    a.axhline(int(lat.sum()), color="0.5", ls=":", lw=0.9)
    a.text(fracs[-1], lat.sum(), " lattice", fontsize=6.5, va="bottom")
    a.axvline(fracs[be], color="tab:red", ls="--", lw=0.9)
    a.set_xlabel("lam / lam_max", fontsize=8); a.set_ylabel("edges", fontsize=8)
    a.legend(fontsize=7, frameon=False)
    a.set_title("E. stability path: how many edges survive block resampling\n"
                "at each operating point", fontsize=9)

    # F: held-out comparison against the lattice-constrained table
    a = ax[1, 2]
    labels, mses = [], []
    fit_npz = DATA / "grid_gdarx_fits.npz"
    if fit_npz.exists():
        z = np.load(fit_npz, allow_pickle=True)
        for lab, m in zip([str(x) for x in z["row_label"]], z["row_mse_test"]):
            if lab in ("autonomous", "GVAR + B-free", "VARX (no graph)"):
                labels.append(lab.replace(" + ", "\n+ ").replace(" (", "\n(")); mses.append(m)
    labels += ["G-free\n(CV lam)", "G-sparse\n(eBIC, stable)"]
    mses += [rows[best]["mse"], res["score_stable"]["mse"]]
    cols = ["0.6"] * (len(mses) - 2) + ["tab:green", "tab:olive"]
    a.bar(range(len(mses)), mses, color=cols)
    a.set_xticks(range(len(mses))); a.set_xticklabels(labels, fontsize=7)
    a.set_ylabel("held-out one-step MSE", fontsize=8)
    a.set_ylim(min(mses) * 0.95, max(mses) * 1.02)
    a.set_title("F. held-out MSE vs the lattice-constrained fits", fontsize=9)

    fig.tight_layout(rect=(0, 0, 1, 0.96))
    PNG.mkdir(exist_ok=True)
    out = (PNG / "freegraph.png") if out is None else Path(out)
    fig.savefig(out, dpi=150)
    print(f"wrote {out}")
    return fig


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--n-lam", type=int, default=18)
    ap.add_argument("--lam-lo", type=float, default=0.005)
    ap.add_argument("--ridge", type=float, default=1e-4)
    ap.add_argument("--n-sub", type=int, default=20)
    ap.add_argument("--stab", type=float, default=0.6)
    ap.add_argument("--drop-pcs", type=int, default=0,
                    help="project out the top-k PCs of X before fitting (global-mode test)")
    ap.add_argument("--interior", action="store_true",
                    help="drop perimeter grid sites (see gdar_x.interior_nodes)")
    ap.add_argument("--roi", action="store_true",
                    help="use the hand-drawn ROI mask (bilateral/grid/roi_nodes.py)")
    ap.add_argument("--no-save", action="store_true")
    a = ap.parse_args()

    tag = (("_roi" if a.roi else "_int" if a.interior else "")
           + (f"_pc{a.drop_pcs}" if a.drop_pcs else ""))
    res = run(n_lam=a.n_lam, lam_lo=a.lam_lo, ridge=a.ridge, n_sub=a.n_sub,
              stab_thresh=a.stab, save=not a.no_save, drop_pcs=a.drop_pcs,
              interior=a.interior, roi=a.roi, tag=tag)
    lattice_report(res["support_cv"], res["adj"], res["sites"], "held-out-ell support")
    lattice_report(res["support"], res["adj"], res["sites"], "eBIC support")
    lattice_report(res["support_stable"], res["adj"], res["sites"],
                   "eBIC support, stability-filtered")
    figure(res, out=PNG / f"freegraph{tag}.png")


if __name__ == "__main__":
    main()
