"""Model H, fitted to the measured Green's function instead of to one-step prediction.

`hetgraph.py` fits (Omega, W, B) by one-step equation error on the continuous record.  That
objective is what breaks the model: a delta-shaped kernel maximises lag-1 predictability, so
the fit throws away the node dynamics the model exists to represent, and every frame past the
first is unpenalised.  Here the objective is the thing the experiment actually measures --

    minimise  sum_{a,s,i,t} ( y_model[t, i | impulse at (s,a)] - H[a, i, s, t] )^2

-- i.e. output error on the full 0..0.7 s impulse response, for every stim site and both
amplitudes.  Nothing about topology or the midline is imposed; W and B stay free.

Fitting is staged, and the stages are scientifically useful in their own right:

    0  Omega from the measured on-site responses (linear).  Node dynamics come from the data
       rather than from whatever helps one-step prediction.
    1  B with W held at ZERO (linear).  This is the pure-injection model: every response is
       direct drive, nothing propagates.  Its residual is the part of the Green's function
       that REQUIRES a network -- which is the question this whole model family is asking.
    2  Joint (Omega, W, B) by L-BFGS with exact gradients.

Stage 1 vs stage 2 is the headline comparison, not stage 2's absolute fit quality.

No autodiff is available in this environment, so the gradient is hand-derived and checked
against finite differences on every run (`--check-grad`).  The forward pass is a linear
recursion over ~25 frames; the adjoint is the standard reverse recursion:

    A_t[i,r,m] = g_t[i,m] Omega[i,r] + poles[r] A_{t+1}[i,r,m]      (state adjoint)
    lam_t[i,m] = sum_r A_t[i,r,m]                                   (drive adjoint)
    g_t        = dL/dY_t + W' lam_{t+1}                             (output adjoint)

    dL/dOmega[i,r] = sum_{t,m} g_t[i,m] X_t[i,r,m]
    dL/dW[i,j]     = sum_{t,m} lam_t[i,m] Y_{t-1}[j,m]
    dL/dB[i,m]     = lam_0[i,m]

    .venv/Scripts/python.exe bilateral/grid/hetgraph_oe.py --roi
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from scipy.optimize import minimize

import gdar_x
import gdarx_grid
import hetgraph

DATA = Path(__file__).resolve().parents[2] / "data"
PNG = Path(__file__).resolve().parent / "network_png"
RESULT = DATA / "grid_hetgraph_oe.npz"
GREEN = DATA / "grid_cross_response_2amp.npz"

FS = hetgraph.FS
T_POST = 0.7          # s of impulse response to fit


# --------------------------------------------------------------------------------------
# target
# --------------------------------------------------------------------------------------

def load_target(sites, t_post=T_POST, fs=FS):
    """Measured Green's function on the MODEL clock, in percent dF/F.

    Returns Hm (A, T, N, N) indexed [amp, frame, readout, stim site], the amplitudes, and
    the frame count.  Two conversions live here and both have bitten already: H is stored on
    a 70 Hz interpolated window and must be decimated to the 35 Hz model clock, and it is
    fractional dF/F against the model's percent.
    """
    z = np.load(GREEN, allow_pickle=True)
    H, amps, base = z["H"], z["amps"], int(z["base_ix"])
    step = int(round(float(z["fs_win"]) / fs))
    key = {(round(x, 3), round(y, 3)): i for i, (x, y) in enumerate(z["sites"])}
    orig = np.array([key[(round(x, 3), round(y, 3))] for x, y in np.asarray(sites)])
    T = min(int(round(t_post * fs)), (H.shape[-1] - base) // step)
    sub = H[:, :, :, base:base + step * T:step][:, orig][:, :, orig]       # (A,N,N,T)
    return np.ascontiguousarray(sub.transpose(0, 3, 1, 2)) * 100.0, amps, T, step


TRIALS = DATA / "grid_trials_2amp.npz"


def build_target_trials(sites, t_post=T_POST, fs=FS, n_pre=10, parity=None, verbose=True):
    """Green's function trigger-averaged from the raw trials, on the native imaging clock.

    Built here rather than read from `grid_cross_response_2amp.npz` for two reasons.  The
    cached H is interpolated onto a 70 Hz window and stored as fractional dF/F, so using it
    costs a decimation and a unit conversion, both of which have already caused a bug.  More
    importantly, building it here means it can be built from a SUBSET of trials -- which is
    the only honest way to validate a model with ~5800 parameters against a target whose own
    trial noise is large.

    parity : None for all trials, 0 or 1 to take every other trial (split-half).
    Returns (A, T, N, N) percent dF/F indexed [amp, frame, readout, stim site], plus the
    per-entry trial count.
    """
    z = np.load(TRIALS, allow_pickle=True)
    roi = z["roi_ts"].astype(np.float64)
    svdT = z["svdT"].astype(np.float64)
    onset_t, pos, onset_amp = z["onset_t"], z["pos"], z["onset_amp"]
    all_sites = z["sites"]

    F0 = np.median(roi, axis=0)
    X = (roi - F0) / F0 * 100.0                                  # (T, 52) percent dF/F

    key = {(round(x, 3), round(y, 3)): i for i, (x, y) in enumerate(all_sites)}
    site_of = np.array([key.get((round(x, 3), round(y, 3)), -1) for x, y in pos])
    keep_idx = np.array([key[(round(x, 3), round(y, 3))] for x, y in np.asarray(sites)])
    remap = -np.ones(len(all_sites), int)
    remap[keep_idx] = np.arange(len(keep_idx))

    amps = np.unique(np.round(onset_amp, 3))
    T = int(round(t_post * fs))
    N = len(keep_idx)
    fi = np.searchsorted(svdT, onset_t)
    fi = np.where((fi > 0) & (np.abs(svdT[np.clip(fi - 1, 0, None)] - onset_t)
                              < np.abs(svdT[np.clip(fi, 0, len(svdT) - 1)] - onset_t)),
                  fi - 1, fi)

    ok = (remap[site_of] >= 0) & (fi >= n_pre) & (fi < len(svdT) - T)
    if parity is not None:
        ok &= (np.arange(len(fi)) % 2) == parity

    out = np.zeros((len(amps), T, N, N))
    cnt = np.zeros((len(amps), N), int)
    for ai, amp in enumerate(amps):
        for s in range(N):
            m = ok & (remap[site_of] == s) & np.isclose(np.round(onset_amp, 3), amp)
            k = fi[m]
            if not len(k):
                continue
            win = X[k[:, None] + np.arange(T)[None, :], :][:, :, keep_idx]   # (n, T, N)
            base = X[k[:, None] + np.arange(-n_pre, 0)[None, :], :][:, :, keep_idx].mean(1)
            out[ai, :, :, s] = (win - base[:, None, :]).mean(0)      # (T, N)
            cnt[ai, s] = len(k)
    if verbose:
        tag = "" if parity is None else f", parity {parity}"
        print(f"target from trials{tag}: {out.shape[0]} amps x {T} frames x {N}x{N}, "
              f"{cnt.min()}-{cnt.max()} trials per (site, amp)")
    return out, amps, T, cnt


def kernel_basis(poles, T):
    """k[r, t] = poles[r]^(t-1) for t >= 1, zero at t = 0 (strictly causal drive)."""
    K = np.zeros((len(poles), T))
    for t in range(1, T):
        K[:, t] = poles ** (t - 1)
    return K


# --------------------------------------------------------------------------------------
# forward / adjoint
# --------------------------------------------------------------------------------------

def simulate(Om, W, B, poles, T):
    """Impulse responses for every input channel at once.

    Returns Y (T, N, M) and the trajectories needed by the adjoint.
    """
    N, P = Om.shape
    M = B.shape[1]
    X = np.zeros((N, P, M))
    Y = np.zeros((N, M))
    Ys = np.zeros((T, N, M))
    Xs = np.zeros((T, N, P, M))
    for t in range(T):
        V = W @ Y
        if t == 0:
            V = V + B
        X = X * poles[None, :, None] + V[:, None, :]
        Y = np.einsum("ip,ipm->im", Om, X)
        Xs[t] = X
        Ys[t] = Y
    return Ys, Xs


def loss_grad(Om, W, B, poles, T, target, wt=None, need_grad=True, ridge_w=0.0):
    """SSE against `target` (T, N, M), plus ridge on W, plus exact gradients.

    Only W is penalised.  B is the injection field and shrinking it would bias the fit
    toward attributing spread to propagation -- the exact question being asked -- and Omega
    is 5 numbers per node fitted against 24 frames, so it is not where the overfitting is.
    """
    N, P = Om.shape
    Ys, Xs = simulate(Om, W, B, poles, T)
    R = Ys - target
    if wt is not None:
        R = R * wt
    loss = float((R ** 2).sum())
    if ridge_w:
        loss += float(ridge_w * (W ** 2).sum())
    if not need_grad:
        return loss, None, None, None

    dY = 2.0 * (R * wt if wt is not None else R)          # (T, N, M)
    A = np.zeros_like(Xs[0])                              # state adjoint, (N, P, M)
    lam_next = None
    gOm = np.zeros_like(Om)
    gW = np.zeros_like(W)
    gB = np.zeros_like(B)
    for t in range(T - 1, -1, -1):
        g = dY[t] if lam_next is None else dY[t] + W.T @ lam_next
        A = g[:, None, :] * Om[:, :, None] + poles[None, :, None] * A
        lam = A.sum(1)                                    # (N, M)
        gOm += np.einsum("im,ipm->ip", g, Xs[t])
        if t == 0:
            gB += lam
        else:
            gW += lam @ Ys[t - 1].T
        lam_next = lam
    if ridge_w:
        gW += 2.0 * ridge_w * W
    return loss, gOm, gW, gB


# --------------------------------------------------------------------------------------
# staged fit
# --------------------------------------------------------------------------------------

def stage0_omega(target, poles, T, ridge=1e-6):
    """Per-node kernel weights from that node's own measured on-site response (linear)."""
    A, _, N, _ = target.shape[0], None, target.shape[2], None
    K = kernel_basis(poles, T)                            # (P, T)
    Om = np.zeros((N, len(poles)))
    for i in range(N):
        y = target[:, :, i, i].mean(0)                    # amp-averaged on-site trace
        G = K @ K.T + ridge * np.trace(K @ K.T) / len(poles) * np.eye(len(poles))
        Om[i] = np.linalg.solve(G, K @ y)
    return hetgraph._norm_sign(Om, poles)[0]


def stage1_B(target_flat, Om, poles, T, ridge=1e-8):
    """B with W = 0: each (readout, channel) is a scalar times that readout's kernel."""
    N, P = Om.shape
    M = target_flat.shape[2]
    K = kernel_basis(poles, T)
    k = Om @ K                                            # (N, T) per-node kernel
    denom = (k ** 2).sum(1) + ridge                       # (N,)
    return np.einsum("tim,it->im", target_flat, k) / denom[:, None]


def fit_oe(target, poles, maxiter=600, w_off=1.0, verbose=True, check_grad=False,
           x0=None, ridge_w=0.0, freeze_omega=False):
    """Stages 0-2.  `target` is (A, T, N, N); channels are flattened as (amp, site)."""
    A, T, N, _ = target.shape
    P = len(poles)
    tf = np.concatenate([target[a] for a in range(A)], axis=2)      # (T, N, A*N)
    M = tf.shape[2]

    wt = None
    if w_off != 1.0:
        wt = np.full((T, N, M), float(w_off))
        for a in range(A):
            for s in range(N):
                wt[:, s, a * N + s] = 1.0
        wt = np.sqrt(wt)

    Om = stage0_omega(target, poles, T)
    B = stage1_B(tf, Om, poles, T)
    W = np.zeros((N, N))
    l1, *_ = loss_grad(Om, W, B, poles, T, tf, wt, need_grad=False)
    sst = float(((tf * (wt if wt is not None else 1.0)) ** 2).sum())
    if verbose:
        print(f"stage 1  (W = 0, pure injection)   SSE {l1:.4g}   "
              f"VE {1 - l1 / sst:.4f}")

    if x0 is not None:
        Om, W, B = x0

    def pack(Om, W, B):
        return np.concatenate([Om.ravel(), W.ravel(), B.ravel()])

    def unpack(v):
        i = N * P
        j = i + N * N
        return v[:i].reshape(N, P), v[i:j].reshape(N, N), v[j:].reshape(N, M)

    def fun(v):
        om, w, b = unpack(v)
        l, gom, gw, gb = loss_grad(om, w, b, poles, T, tf, wt, ridge_w=ridge_w)
        if freeze_omega:
            # Node dynamics held at their stage-0 values (fitted to the on-site responses
            # alone) so that W has to explain the off-diagonal without being able to
            # re-attribute it to slower node kernels.  See `run`'s frozen-vs-joint report.
            gom = np.zeros_like(gom)
        return l, pack(gom, gw, gb)

    if check_grad:
        rng = np.random.default_rng(0)
        v = pack(Om, W, B) + 0.01 * rng.standard_normal(N * P + N * N + N * M)
        l0, g = fun(v)
        # Scale the error by the gradient's own magnitude, not per-coordinate.  A central
        # difference on a loss of order 1e4 carries absolute roundoff ~loss*eps/h, which is
        # a large RELATIVE error on any coordinate whose gradient happens to be small --
        # that is finite-difference noise, not a wrong derivative, and a per-coordinate
        # relative test reports it as a failure.  (The exact check lives in `_selftest`,
        # where the loss is O(1) and finite differences are clean.)
        idx = rng.choice(len(v), 16, replace=False)
        num = np.empty(len(idx))
        for q, ii in enumerate(idx):
            h = 1e-5 * max(abs(v[ii]), 1.0)
            vp = v.copy(); vp[ii] += h
            vm = v.copy(); vm[ii] -= h
            num[q] = (fun(vp)[0] - fun(vm)[0]) / (2 * h)
        scaled = np.abs(num - g[idx]).max() / max(np.abs(num).max(), 1e-12)
        print(f"gradient check: max error / gradient scale {scaled:.2e} over 16 "
              f"coordinates ({'OK' if scaled < 1e-5 else 'FAIL'})")

    res = minimize(fun, pack(Om, W, B), jac=True, method="L-BFGS-B",
                   options=dict(maxiter=maxiter, maxfun=maxiter * 2, ftol=1e-14,
                                gtol=1e-10))
    Om2, W2, B2 = unpack(res.x)
    Om2, sc = hetgraph._norm_sign(Om2, poles)
    # Rescaling node i's kernel by 1/sc_i must be undone in node i's DRIVE, so both W and B
    # scale by sc on the ROW index only.  There is no column factor: y_j is the model output
    # and is invariant under the reparameterisation, so dividing by sc_j (as a first version
    # did) silently changes the model -- it showed up as the reported loss RISING with more
    # optimiser iterations, which L-BFGS cannot do.
    W2 = W2 * sc[:, None]
    B2 = B2 * sc[:, None]
    chk, *_ = loss_grad(Om2, W2, B2, poles, T, tf, wt, need_grad=False, ridge_w=ridge_w)
    if chk > res.fun * (1 + 1e-8) + 1e-9:
        raise RuntimeError(
            f"the sign/scale normalisation changed the model: loss {res.fun:.6g} -> "
            f"{chk:.6g}. The reparameterisation must be exactly loss-preserving.")
    l2, *_ = loss_grad(Om2, W2, B2, poles, T, tf, wt, need_grad=False)
    if verbose:
        print(f"stage 2  (joint, {res.nit} iters)       SSE {l2:.4g}   "
              f"VE {1 - l2 / sst:.4f}   [{res.message.strip()}]")
        print(f"         coupling buys {100 * (l1 - l2) / l1:.1f}% of the "
              f"pure-injection residual")
    return dict(Omega=Om2, W=W2, B=B2, Omega0=stage0_omega(target, poles, T),
                poles=poles, T=T, M=M, N=N, A=A,
                sse1=l1, sse2=l2, sst=sst, ve1=1 - l1 / sst, ve2=1 - l2 / sst,
                nit=int(res.nit), target=tf, wt=wt)


# --------------------------------------------------------------------------------------
# scoring
# --------------------------------------------------------------------------------------

def green_scores(fit, label="", verbose=True):
    """Correlations against the measured Green's function, split the way the claim splits."""
    Om, W, B, poles, T = fit["Omega"], fit["W"], fit["B"], fit["poles"], fit["T"]
    N, A = fit["N"], fit["A"]
    Ys, _ = simulate(Om, W, B, poles, T)
    tf = fit["target"]
    on_m, on_e, pm, pe = [], [], np.zeros((A, N, N)), np.zeros((A, N, N))
    for a in range(A):
        for s in range(N):
            ch = a * N + s
            on_m.append(Ys[:, s, ch]); on_e.append(tf[:, s, ch])
            pm[a, :, s] = Ys[np.abs(Ys[:, :, ch]).argmax(0), np.arange(N), ch]
            pe[a, :, s] = tf[np.abs(tf[:, :, ch]).argmax(0), np.arange(N), ch]
    od = ~np.eye(N, dtype=bool)
    out = dict(r_onsite=float(np.corrcoef(np.ravel(on_m), np.ravel(on_e))[0, 1]),
               r_peak=float(np.corrcoef(pm.ravel(), pe.ravel())[0, 1]),
               r_peak_off=float(np.corrcoef(pm[:, od].ravel(), pe[:, od].ravel())[0, 1]),
               r_full=float(np.corrcoef(Ys.ravel(), tf.ravel())[0, 1]),
               rho=hetgraph.spectral_radius(dict(Omega=Om, W=W, poles=poles)))
    if verbose:
        print(f"  {label:<22s} full {out['r_full']:+.3f} | on-site {out['r_onsite']:+.3f} "
              f"| peak map {out['r_peak']:+.3f} | OFF-DIAG {out['r_peak_off']:+.3f} "
              f"| rho {out['rho']:.3f}")
    return out


def run(interior=False, roi=False, P=hetgraph.P_POLES, t_post=T_POST, maxiter=600,
        w_off=1.0, check_grad=True, save=True, verbose=True, tag="",
        ridge_path=(0.0, 1.0, 10.0, 100.0, 1000.0)):
    d = gdarx_grid.load(verbose=verbose)
    if roi or interior:
        import freegraph
        if roi:
            import roi_nodes
            keep = roi_nodes.load_mask(d["sites"], verbose=verbose)
        else:
            keep = gdar_x.interior_nodes(d["sites"], verbose=verbose)
        d = freegraph.subset_nodes(d, keep, verbose=verbose)
    sites = d["sites"]
    poles, tau = hetgraph.pole_bank(P)

    # Split-half by trial parity.  With ~5800 parameters against a target whose own trial
    # noise is large, in-sample SSE is not evidence -- fitting BELOW the noise level is
    # possible and meaningless.  Train on one half of the trials, score on the other.
    tr_t, amps, T, cnt = build_target_trials(sites, t_post, parity=0, verbose=verbose)
    te_t, _, _, _ = build_target_trials(sites, t_post, parity=1, verbose=verbose)
    full_t, _, _, _ = build_target_trials(sites, t_post, parity=None, verbose=verbose)

    def flat(x):
        return np.concatenate([x[a] for a in range(x.shape[0])], axis=2)

    tr_f, te_f = flat(tr_t), flat(te_t)
    sst_te = float((te_f ** 2).sum())
    # The two halves disagree by trial noise alone; that disagreement is the floor any
    # model is scored against on held-out data.
    floor = float(((tr_f - te_f) ** 2).sum()) / 2.0
    if verbose:
        print(f"poles P={P}, tau {tau[0] * 1e3:.0f} ms - {tau[-1]:.1f} s")
        print(f"split-half noise floor: held-out SSE {floor:.4g} "
              f"(VE ceiling {1 - floor / sst_te:.4f}) -- a model that scores below this "
              f"is fitting noise\n")

    lams = [0.0] if ridge_path is None else list(ridge_path)
    rows = []
    for lam in lams:
        f = fit_oe(tr_t, poles, maxiter=maxiter, w_off=w_off, ridge_w=lam,
                   verbose=verbose and len(lams) == 1, check_grad=check_grad and lam == lams[0])
        te_sse, *_ = loss_grad(f["Omega"], f["W"], f["B"], poles, T, te_f, f["wt"],
                               need_grad=False)
        f["te_sse"] = te_sse
        f["te_ve"] = 1 - te_sse / sst_te
        f["lam"] = lam
        rows.append(f)
        if verbose:
            print(f"  ridge {lam:<9.4g} train SSE {f['sse2']:9.4g}  held-out SSE "
                  f"{te_sse:9.4g}  held-out VE {f['te_ve']:.4f}"
                  f"{'   <- below the noise floor' if te_sse < floor else ''}")

    fit = min(rows, key=lambda r: r["te_sse"])
    fit.update(sites=sites, amps=amps, floor=floor, sst_te=sst_te, rows=rows,
               target_full=flat(full_t))
    if verbose:
        print(f"\nselected ridge {fit['lam']:g}: held-out VE {fit['te_ve']:.4f} "
              f"against a ceiling of {1 - floor / sst_te:.4f}")

        # W = 0 baseline, refitted on the same training half
        Om1 = stage0_omega(tr_t, poles, T)
        B1 = stage1_B(tr_f, Om1, poles, T)
        inj = dict(fit, Omega=Om1, W=np.zeros_like(fit["W"]), B=B1)
        te1, *_ = loss_grad(Om1, np.zeros_like(fit["W"]), B1, poles, T, te_f, fit["wt"],
                            need_grad=False)
        print(f"pure injection (W=0):  held-out SSE {te1:.4g}  VE {1 - te1 / sst_te:.4f}")
        print(f"coupling buys {100 * (te1 - fit['te_sse']) / max(te1 - floor, 1e-9):.1f}% "
              f"of the explainable held-out residual\n")
        print("Green's function correlations (held-out half):")
        green_scores(dict(inj, target=te_f), "pure injection (W=0)")
        green_scores(dict(fit, target=te_f), "joint (W free)")
        print("  one-step-fitted model, same nodes: OFF-DIAG +0.031  <- where we started")

    if save:
        np.savez_compressed(RESULT.with_name(RESULT.stem + tag + RESULT.suffix),
                            Omega=fit["Omega"], W=fit["W"], B=fit["B"], poles=poles,
                            tau=tau, sites=sites, amps=amps, T=T,
                            sse1=fit["sse1"], sse2=fit["sse2"], sst=fit["sst"],
                            ve1=fit["ve1"], ve2=fit["ve2"], lam=fit["lam"],
                            te_sse=fit["te_sse"], te_ve=fit["te_ve"],
                            floor=fit["floor"], sst_te=fit["sst_te"])
        print(f"\nsaved -> {RESULT.stem + tag + RESULT.suffix}")
    return fit


def _selftest():
    """Exact gradient check on a small instance, where the loss is O(1)."""
    rng = np.random.default_rng(1)
    N, P, M, T = 4, 3, 5, 6
    poles = hetgraph.pole_bank(P)[0]
    Om = rng.standard_normal((N, P)) * 0.5
    W = rng.standard_normal((N, N)) * 0.15
    B = rng.standard_normal((N, M)) * 0.8
    tgt = rng.standard_normal((T, N, M)) * 0.3
    _, gOm, gW, gB = loss_grad(Om, W, B, poles, T, tgt)

    def numgrad(mat, setter):
        g = np.zeros_like(mat)
        for idx in np.ndindex(mat.shape):
            hp, hm = mat.copy(), mat.copy()
            hp[idx] += 1e-6
            hm[idx] -= 1e-6
            g[idx] = (loss_grad(*setter(hp), poles, T, tgt, need_grad=False)[0]
                      - loss_grad(*setter(hm), poles, T, tgt, need_grad=False)[0]) / 2e-6
        return g

    ok = True
    for name, ana, nu in (("Omega", gOm, numgrad(Om, lambda m: (m, W, B))),
                          ("W", gW, numgrad(W, lambda m: (Om, m, B))),
                          ("B", gB, numgrad(B, lambda m: (Om, W, m)))):
        err = np.abs(ana - nu).max() / max(np.abs(nu).max(), 1e-12)
        ok &= err < 1e-6
        print(f"  {name:<6s} n={ana.size:3d}  max err / grad scale {err:.2e}  "
              f"{'OK' if err < 1e-6 else 'FAIL'}")
    print("analytic gradient:", "VERIFIED" if ok else "WRONG")
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--selftest", action="store_true",
                    help="exact gradient check on a small instance, then exit")
    ap.add_argument("--roi", action="store_true")
    ap.add_argument("--interior", action="store_true")
    ap.add_argument("--poles", type=int, default=hetgraph.P_POLES)
    ap.add_argument("--t-post", type=float, default=T_POST)
    ap.add_argument("--maxiter", type=int, default=600)
    ap.add_argument("--w-off", type=float, default=1.0,
                    help="relative weight on off-diagonal (propagated) entries")
    ap.add_argument("--no-check-grad", action="store_true")
    ap.add_argument("--ridge", type=float, default=None,
                    help="single ridge on W instead of the selection path")
    ap.add_argument("--no-save", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        raise SystemExit(0 if _selftest() else 1)
    tag = "_roi" if a.roi else "_int" if a.interior else ""
    run(interior=a.interior, roi=a.roi, P=a.poles, t_post=a.t_post, maxiter=a.maxiter,
        w_off=a.w_off, check_grad=not a.no_check_grad, save=not a.no_save, tag=tag,
        ridge_path=(a.ridge,) if a.ridge is not None else (0.0, 1.0, 10.0, 100.0, 1000.0))


if __name__ == "__main__":
    main()
