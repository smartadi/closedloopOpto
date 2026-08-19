"""Fit GDAR-with-input to the AL_0048 grid photostimulation session.

Builds a continuous 52-channel state `X` (one ROI per stim site, dF/F on the 35 Hz frame
clock) and a 52-channel input `U` (impulse train, one channel per site), then fits the
model family in `gdar_x.py` and scores each member by held-out one-step predictive
log-likelihood.

Why the continuous record rather than trial windows: the inter-stimulus interval is
~0.49 s, so any trial window past ~+0.7 s overlaps neighbouring stims (the reason
`network_id.py` caps its fit window at 0.08-0.60 s).  A VARX on the unbroken record models
that overlap natively as superposition -- the window cap simply disappears, and every one
of the 5200 onsets contributes.

The scientific question this answers, which `network_id.py` cannot: does the stimulus enter
the network *only at the stimulated node* (b_mask='diag', all spatial spread carried by
(I - sum A_k)^-1), or does it inject broadly (b_mask='free')?  Held-out likelihood decides.

    .venv/Scripts/python.exe bilateral/grid/gdarx_grid.py            # fit + figures
    .venv/Scripts/python.exe bilateral/grid/gdarx_grid.py --rebuild  # redo the X/U cache

Caveats worth carrying into any interpretation
----------------------------------------------
* GCaMP kinetics are inside A.  The fitted propagator mixes neural propagation with
  indicator rise/decay; A is a dynamics model of the *measurement*, not of spiking.
* Dual opsin: left hemisphere (x < 0) is excitatory, right (x > 0) inhibitory, so the
  response sign flips across the midline.  The sign lives in B, but GDAR's symmetric A is
  a real assumption across that boundary -- hence the GVAR (non-symmetric) comparison and
  the `bridge_midline` switch.
* 25 ms pulse under a 28.6 ms frame: `u` is a sub-frame impulse, split linearly between
  the two bracketing frames.
* The 52 ROIs are not 52 independent signals.  `cross_response.py` reconstructs them from a
  rank-50 SVD basis (`N_COMPS = 50`), so cov(X) has condition ~4e13 and 99% of its variance
  lives in 17 components.  Hence the diagonal noise model -- see `run()`.  It also means the
  unconstrained VARX design is rank deficient: its *predictions* are sound (its held-out
  advantage is 84% inside the top-17 signal subspace) but its individual A coefficients are
  not uniquely determined and should not be read as connectivity.
* Every graph-constrained fit comes out with spectral radius > 1, i.e. formally unstable;
  only the unconstrained VARX lands below 1 (0.987, and that is close enough to the unit
  circle that DC-gain magnitudes are inflated).  The lattice appears to be too restrictive
  to express the real coupling, and compensates with an explosive mode.  One-step held-out
  scores are unaffected, but long-horizon simulation and `dc_gain` are not meaningful for
  those fits.
* The dose response is sublinear: fitting one input channel per (site, amplitude) pair puts
  the 2 mW gain at ~1.4x the 1 mW gain, not 2x.  `amp_mode='weight'` assumes 2x.  It makes
  almost no difference to held-out score, but B is then a slight underestimate at 1 mW.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

import gdar_x

DATA = Path(__file__).resolve().parents[2] / "data"
PNG = Path(__file__).resolve().parent / "network_png"
TRIALS = DATA / "grid_trials_2amp.npz"
CACHE = DATA / "grid_gdarx_data.npz"
RESULT = DATA / "grid_gdarx_fits.npz"

FS = 35.0
DETREND_S = 20.0      # moving-average high-pass; slow bleaching drift would otherwise be
                      # absorbed into a near-unit-root A and inflate every VAF
PAD_S = 5.0           # frames kept either side of the first/last onset
K_A = 5               # 5 lags @ 35 Hz = 143 ms of history
K_U = 5


# --------------------------------------------------------------------------------------
# data preparation
# --------------------------------------------------------------------------------------

def _moving_average(x, w):
    """Centred boxcar along axis 1, edge-padded (w in samples, forced odd)."""
    w = int(w) | 1
    if w < 3:
        return np.zeros_like(x)
    pad = w // 2
    xp = np.pad(x, ((0, 0), (pad, pad)), mode="edge")
    c = np.cumsum(xp, axis=1)
    c = np.concatenate([np.zeros((x.shape[0], 1)), c], axis=1)
    return (c[:, w:] - c[:, :-w]) / w


def build(detrend_s=DETREND_S, amp_mode="weight", cache=True, verbose=True):
    """Continuous state X (N,T) and input U (M,T) for the primary grid session.

    amp_mode : 'weight' -- one input channel per site, impulse height = laser amp (mW),
                           i.e. a linear dose-response is assumed and B is a per-mW gain.
               'unit'   -- one channel per site, unit impulses; amplitude folded into B.
               'split'  -- one channel per (site, amp) pair, M = 2N; makes no linearity
                           assumption, at the cost of doubling the B parameters.

    Returns a dict: X, U, sites, site_of_input, amp_of_input, frame_t, fs, F0, and the
    build settings.  Cached to data/grid_gdarx_data.npz.
    """
    if not TRIALS.exists():
        raise FileNotFoundError(
            f"{TRIALS.name} missing -- build it with:\n"
            f"  .venv/Scripts/python.exe bilateral/grid/cross_response.py 2amp")
    z = np.load(TRIALS, allow_pickle=True)
    roi = z["roi_ts"].astype(np.float64)            # (T, nSites) raw fluorescence
    svdT = z["svdT"].astype(np.float64)
    onset_t = z["onset_t"].astype(np.float64)
    pos = z["pos"].astype(np.float64)
    onset_amp = z["onset_amp"].astype(np.float64)
    sites = z["sites"].astype(np.float64)
    N = len(sites)

    # --- restrict to the grid segment (the session also holds non-grid blocks) ---------
    seg = (svdT >= onset_t.min() - PAD_S) & (svdT <= onset_t.max() + PAD_S)
    frame_t = svdT[seg]
    F = roi[seg].T                                   # (N, T)
    T = F.shape[1]

    # --- fluorescence -> percent dF/F --------------------------------------------------
    F0 = np.median(F, axis=1, keepdims=True)
    X = (F - F0) / F0 * 100.0

    # --- remove slow drift, then centre ------------------------------------------------
    if detrend_s and detrend_s > 0:
        X = X - _moving_average(X, round(detrend_s * FS))
    X = X - X.mean(axis=1, keepdims=True)

    # --- map each onset to its site index ----------------------------------------------
    key = {(round(x, 3), round(y, 3)): i for i, (x, y) in enumerate(sites)}
    onset_site = np.array([key.get((round(x, 3), round(y, 3)), -1) for x, y in pos])
    good = onset_site >= 0
    if verbose and (~good).any():
        print(f"[warn] {(~good).sum()} onsets fall outside the {N}-site list -- dropped")

    amps = np.unique(np.round(onset_amp[good], 3))
    if amp_mode == "weight":
        chan, w = onset_site[good], onset_amp[good]
        site_of_input, amp_of_input = np.arange(N), np.full(N, np.nan)
    elif amp_mode == "unit":
        chan, w = onset_site[good], np.ones(good.sum())
        site_of_input, amp_of_input = np.arange(N), np.full(N, np.nan)
    elif amp_mode == "split":
        ai = np.searchsorted(amps, np.round(onset_amp[good], 3))
        chan = onset_site[good] + ai * N
        w = np.ones(good.sum())
        site_of_input = np.tile(np.arange(N), len(amps))
        amp_of_input = np.repeat(amps, N)
    else:
        raise ValueError("amp_mode must be 'weight', 'unit' or 'split'")

    M = N * (len(amps) if amp_mode == "split" else 1)
    U, n_used = gdar_x.build_input(frame_t, onset_t[good], chan, M,
                                   weight=w, fractional=True)

    out = dict(X=X, U=U, sites=sites, site_of_input=site_of_input,
               amp_of_input=amp_of_input, frame_t=frame_t, F0=F0.ravel(),
               fs=FS, amps=amps, amp_mode=amp_mode, detrend_s=float(detrend_s or 0.0),
               n_onsets=int(n_used))
    if verbose:
        print(f"segment {frame_t[0]:.0f}-{frame_t[-1]:.0f}s  T={T} frames @ {FS:.0f}Hz "
              f"({(frame_t[-1] - frame_t[0]) / 60:.1f} min)")
        print(f"X {X.shape}  dF/F%  sd {X.std():.3f}  |  U {U.shape}  "
              f"amp_mode={amp_mode}  {n_used} onsets  amps {list(amps)}")
    if cache:
        DATA.mkdir(exist_ok=True)
        np.savez_compressed(CACHE, **{k: np.asarray(v) for k, v in out.items()})
        print(f"cached -> {CACHE.name}")
    return out


def load(rebuild=False, **kw):
    if rebuild or not CACHE.exists():
        return build(**kw)
    z = np.load(CACHE, allow_pickle=True)
    d = {k: z[k] for k in z.files}
    d["amp_mode"] = str(d["amp_mode"])
    print(f"loaded {CACHE.name}: X {d['X'].shape}, U {d['U'].shape}, "
          f"amp_mode={d['amp_mode']}")
    return d


CROSS = DATA / "grid_cross_response_2amp.npz"


def validate_alignment(d=None, pre_s=0.30, post_s=1.00, verbose=True, thresh=0.85):
    """Check that X and U are on the same clock, against the cached Green's function H.

    Worth having as a standing check rather than a one-off: everything downstream is a
    regression of X on lagged U, so a frame-level misalignment would not error, it would
    quietly produce a small, smeared, plausible-looking B.  The independent ground truth is
    `grid_cross_response_2amp.npz`, built by cross_response.py through a completely separate
    trial-averaging path.  Trigger-averaging the continuous X on the true onset times has to
    reproduce it.

    Two traps this function exists to avoid, both of which cost real time to find:
      * `build_input(fractional=True)` splits each onset across the two bracketing frames,
        so U's nonzero frames are NOT onsets and their heights are NOT amplitudes.  Trigger
        off `onset_t` from the trials file, never off U.
      * H is *fractional* dF/F ((F - F0) / F0, no percent) while X is percent.  The factor
        of 100 here is a unit conversion, not a fudge.

    Returns a dict.  On this session both correlations land at 0.90-0.94 and are flat across
    any sensible pre/post window (checked from 0.15/0.30 s out to 0.5/1.5 s), so `thresh` is
    set at 0.85: comfortably below the observed value, far above anything a frame-offset
    would survive.  The residual gap from 1.0 is baseline noise -- the ~0.49 s ISI means the
    pre-stim frames sit in the tail of the previous pulse -- not misalignment.
    """
    d = load() if d is None else d
    if not CROSS.exists():
        if verbose:
            print(f"[skip] {CROSS.name} missing -- cannot validate alignment")
        return None
    z = np.load(CROSS, allow_pickle=True)
    H, win, amps = z["H"], z["window"], z["amps"]

    t = np.load(TRIALS, allow_pickle=True)
    X, sites, frame_t = d["X"], d["sites"], d["frame_t"]
    N = X.shape[0]
    key = {(round(x, 3), round(y, 3)): i for i, (x, y) in enumerate(sites)}
    site = np.array([key.get((round(x, 3), round(y, 3)), -1) for x, y in t["pos"]])
    onset_t, amp = t["onset_t"].astype(float), t["onset_amp"].astype(float)

    pre, post = int(round(pre_s * FS)), int(round(post_s * FS))
    fi = np.searchsorted(frame_t, onset_t)
    ok = (site >= 0) & (fi >= pre) & (fi < X.shape[1] - post)
    fi, site_, amp_ = fi[ok], site[ok], amp[ok]

    # trigger-average per site, per mW, baseline-subtracted on the pre-stim frames
    avg = np.zeros((N, N, pre + post))
    for j in range(N):
        m = site_ == j
        seg = np.stack([X[:, k - pre:k + post] for k in fi[m]]) / amp_[m][:, None, None]
        a = seg.mean(0)
        avg[j] = a - a[:, :pre].mean(1, keepdims=True)

    # cached H on the same frame grid, percent, per mW, averaged over amplitudes
    tt = (np.arange(pre + post) - pre) / FS
    emp = np.zeros_like(avg)
    for ai, a in enumerate(amps):
        for s in range(N):
            for r in range(N):
                emp[s, r] += np.interp(tt, win, H[ai, s, r]) * 100.0 / a / len(amps)

    on = np.array([avg[j, j] for j in range(N)])
    on_e = np.array([emp[j, j] for j in range(N)])
    pk, pk_e = np.abs(avg).max(-1), np.abs(emp).max(-1)
    # where does the stimulated site rank among the 52 readouts?  Not first, as it turns out.
    rank = np.array([(pk[j] > pk[j, j]).sum() + 1 for j in range(N)])

    out = dict(corr_onsite=float(np.corrcoef(on.ravel(), on_e.ravel())[0, 1]),
               corr_peak=float(np.corrcoef(pk.ravel(), pk_e.ravel())[0, 1]),
               peak_onsite=float(np.abs(on).max(1).mean()),
               peak_onsite_H=float(np.abs(on_e).max(1).mean()),
               onsite_rank=float(rank.mean()), n_onsets=int(ok.sum()),
               n_dropped=int((~ok).sum()))
    if verbose:
        print(f"\nalignment check ({out['n_onsets']} onsets, {out['n_dropped']} dropped)")
        print(f"  corr(on-site trace, H)     {out['corr_onsite']:+.3f}")
        print(f"  corr(peak map, 52x52)      {out['corr_peak']:+.3f}")
        print(f"  on-site peak  {out['peak_onsite']:.3f} %/mW   H {out['peak_onsite_H']:.3f}")
        print(f"  stimulated site ranks {out['onsite_rank']:.1f} of {N} readouts by peak "
              f"-- the stimulated ROI is not the largest responder")
        if min(out["corr_onsite"], out["corr_peak"]) < thresh:
            print(f"  [FAIL] below {thresh:.2f} -- X and U look misaligned, or a cache is stale")
    return out


def b_masks(N, M, site_of_input, adj):
    """Input-support masks that work for M != N (the 'split' amp mode)."""
    soi = np.asarray(site_of_input, int)
    diag = (np.arange(N)[:, None] == soi[None, :])
    local = diag | np.asarray(adj, bool)[:, soi]
    return dict(diag=diag, local=local, free=np.ones((N, M), bool))


# --------------------------------------------------------------------------------------
# model comparison
# --------------------------------------------------------------------------------------

MODELS = [
    # label,            model,  b_mask,  method
    ("autonomous",      "gdar", "zero",  "joint"),
    ("GDAR + B-diag",   "gdar", "diag",  "joint"),
    ("GDAR + B-local",  "gdar", "local", "joint"),
    ("GDAR + B-free",   "gdar", "free",  "alt"),
    ("GVAR + B-diag",   "gvar", "diag",  "joint"),
    ("GVAR + B-free",   "gvar", "free",  "alt"),
    ("VARX (no graph)", "ols",  "free",  "alt"),
]


def run(d=None, connectivity=8, bridge_midline=True, K_a=K_A, K_u=K_U,
        test_frac=0.2, models=None, save=True, verbose=True, u_lag0=True,
        sigma_diagonal=True, sigma_shrink=1e-6):
    """Fit every model in `models`, score on held-out contiguous blocks, return results.

    u_lag0 : include the contemporaneous input lag (u_lags = 0..K_u-1 instead of 1..K_u).
        This matters more than it looks.  The pulse at frame t0 first appears in `u` at
        t0, and the fluorescence starts rising in that same frame; with strictly causal
        lags the model only sees the stimulus at t0+1, by which point the response is
        already in the AR history and the input term is largely redundant.  A
        contemporaneous term is legitimate here because `u` is exogenous and
        experimenter-controlled -- there is no simultaneity to bias.

    sigma_diagonal : weight the GLS objective by per-channel variances only, ignoring the
        residual cross-covariance.  On by default, and not a cosmetic choice.  The 52 ROIs
        are read out of a rank-50 SVD basis (`N_COMPS = 50` in config.py), so cov(X) has
        condition ~4e13 and a full residual Sigma inherits it; Sigma^-1 then weights
        signal-free directions by seven orders of magnitude more than the ones the stimulus
        actually lives in.  Measured on this session: 95.5% of the stimulus-response power
        sits in Sigma's top-10 eigenvectors and 0.0% in the bottom-10, yet the full-Sigma
        metric hands the bottom-10 6.1% of its weight and the top-10 only 29.3%.  The
        consequence is not subtle -- the fitted diagonal B collapses to |B_jj| ~ 0.0004
        against an OLS value of 0.40, and the B-vs-no-B likelihood gain reads 0.000.  With
        a diagonal Sigma the model family is monotone again, in-sample SSE drops ~35%, and
        |B_jj| is a stable 0.40-0.42 across every input mask.  Pass False to reproduce the
        old full-Sigma behaviour; `gdar_x.condition_report` explains what it costs.
    """
    d = load() if d is None else d
    X, U = d["X"], d["U"]
    N, T = X.shape
    M = U.shape[0]
    adj = gdar_x.lattice_graph(d["sites"], connectivity=connectivity,
                               bridge_midline=bridge_midline)
    masks = b_masks(N, M, d["site_of_input"], adj)
    models = MODELS if models is None else models

    a_lags = list(range(1, K_a + 1))
    u_lags = list(range(0, K_u)) if u_lag0 else list(range(1, K_u + 1))
    lag_max = max(a_lags + u_lags)
    tr, te = gdar_x.block_split(T - lag_max, test_frac=test_frac)

    rep = gdar_x.condition_report(X)
    if verbose:
        print(f"\nN={N} nodes, M={M} inputs, {adj.sum() // 2} graph edges "
              f"({connectivity}-conn, midline {'bridged' if bridge_midline else 'split'})")
        print(f"a_lags {a_lags[0]}-{a_lags[-1]}, u_lags {u_lags[0]}-{u_lags[-1]} "
              f"-> D={N * K_a + M * K_u};  train {tr.sum()} / test {te.sum()} frames")
        print(f"channels: effective rank {rep['rank']}/{rep['N']}, cond(cov X) "
              f"{rep['cond']:.1e}, 99% of variance in {rep['n_99']} components"
              + ("  <- rank deficient" if rep["deficient"] else ""))
        print(f"noise model: {'diagonal' if sigma_diagonal else 'FULL'} Sigma"
              f", shrink {sigma_shrink:g}"
              + ("" if sigma_diagonal else
                 "  <- GLS weight is dominated by signal-free directions; see run() docstring"))
        print("accumulating second moments ...")

    g_tr = gdar_x.grams(X, U, a_lags, u_lags, keep=tr)
    g_te = gdar_x.grams(X, U, a_lags, u_lags, keep=te)

    rows, fits = [], {}
    for label, model, bkey, method in models:
        bm = "zero" if bkey == "zero" else masks[bkey]
        f = gdar_x.fit_gdarx(X, U, adj=adj, a_lags=a_lags, u_lags=u_lags, model=model,
                             b_mask=bm, method=method, n_iter=8, gls=True, g=g_tr,
                             sigma_diagonal=sigma_diagonal, sigma_shrink=sigma_shrink)
        # Held-out columns are scored with the coefficients AND Sigma from training only.
        # f["Sigma"] carries whichever noise model was fitted, so scoring stays consistent
        # with the objective: with sigma_diagonal the likelihood's logdet is a sum of
        # per-channel log-variances and is well conditioned.
        theta_te = _pad_theta(f["theta"], g_te)
        ell, ell_mean = gdar_x.loglik_from_grams(theta_te, g_te, f["Sigma"])
        vaf_te = gdar_x.vaf_from_grams(theta_te, g_te)
        vaf_tr = gdar_x.vaf_from_grams(_pad_theta(f["theta"], g_tr), g_tr)
        # MSE and logdet come straight off the held-out residual moment, so unlike `ell`
        # they carry no dependence on how well each fit's own Sigma is calibrated.
        R_te = gdar_x.resid_moment(theta_te, g_te)
        mse = float(np.trace(R_te) / g_te["n"] / N)
        # logdet follows the noise model.  The full slogdet of a rank-deficient residual
        # covariance is set by its smallest, signal-free eigenvalues; the diagonal version
        # is just the summed per-channel log-variance and stays comparable across models.
        Rn = R_te / g_te["n"]
        logdet = (float(np.log(np.diag(Rn)).sum()) if sigma_diagonal
                  else float(np.linalg.slogdet(Rn)[1]))
        dl = (gdar_x.delta_loglik(theta_te, g_te, f["Sigma"])["delta_mean"]
              if f["B"] is not None else 0.0)
        rho = gdar_x.spectral_radius(f["A"])
        rows.append(dict(label=label, model=model, b=bkey, method=f["method"],
                         n_free=f["n_free"], vaf_train=float(np.nanmean(vaf_tr)),
                         vaf_test=float(np.nanmean(vaf_te)), mse_test=mse,
                         logdet_test=logdet, ell_mean=ell_mean, delta_mean=dl, rho=rho))
        fits[label] = f
        if verbose:
            print(f"  {label:<17s} {f['n_free']:>6d} par | VAF {rows[-1]['vaf_test']:.4f} "
                  f"| MSE {mse:.5f} | logdet {logdet:9.3f} | ell {ell_mean:8.3f} | "
                  f"dEll {dl:7.3f} | rho {rho:.4f}")

    # `models` may omit the autonomous baseline when only a subset is being refitted, in
    # which case the "vs autonomous" column has nothing to reference and stays at nan.
    base = next((r["ell_mean"] for r in rows if r["b"] == "zero"), None)
    for r in rows:
        r["ell_vs_autonomous"] = np.nan if base is None else r["ell_mean"] - base

    if verbose:
        _print_table(rows, sigma_diagonal)
    if save:
        _save(rows, fits, d, adj, connectivity, bridge_midline, a_lags, u_lags,
              sigma_diagonal, rep)
    return rows, fits, dict(adj=adj, g_tr=g_tr, g_te=g_te, train=tr, test=te,
                            condition=rep)


def _pad_theta(theta, g):
    """Match a fitted theta to a Gram layout that may carry a wider input block."""
    if theta.shape[1] == g["D"]:
        return theta
    out = np.zeros((theta.shape[0], g["D"]))
    out[:, :theta.shape[1]] = theta
    return out


def _print_table(rows, sigma_diagonal=True):
    w = 112
    print("\n" + "=" * w)
    print(f"{'model':<18s}{'free par':>9s}{'VAF te':>9s}{'MSE te':>10s}"
          f"{'logdet te':>11s}{'ell/samp':>10s}{'vs auton.':>11s}"
          f"{'dEll(B=0)':>11s}{'rho':>9s}")
    print("-" * w)
    for r in rows:
        print(f"{r['label']:<18s}{r['n_free']:>9d}{r['vaf_test']:>9.4f}"
              f"{r['mse_test']:>10.5f}{r['logdet_test']:>11.3f}{r['ell_mean']:>10.3f}"
              f"{r['ell_vs_autonomous']:>11.3f}{r['delta_mean']:>11.3f}{r['rho']:>9.4f}")
    print("=" * w)
    print("All scores are held out (contiguous blocks, coefficients and Sigma from train).")
    print("  VAF/MSE  : per-channel one-step accuracy      -- lower MSE better")
    print("  ell      : Gaussian predictive log-lik/sample -- higher better")
    print("  dEll(B=0): gain from the input term alone, same fit and same Sigma")
    if sigma_diagonal:
        print("  logdet   : summed per-channel log-variance -- lower better")
        print("Noise model is a DIAGONAL Sigma.  The 52 ROIs come out of a rank-50 SVD, so a")
        print("full Sigma is near-singular and its inverse weights signal-free directions; ell")
        print("and logdet would then be about those directions rather than about the fit.")
    else:
        print("  logdet   : generalised variance of the residual covariance -- lower better")
        print("[caveat] FULL Sigma on rank-deficient channels: logdet and ell are dominated by")
        print("near-zero eigenvalues carrying no signal, and B is driven toward zero.  Treat")
        print("these numbers as a diagnostic, not as a model comparison.")


def _save(rows, fits, d, adj, connectivity, bridge_midline, a_lags, u_lags,
          sigma_diagonal=True, rep=None):
    out = {f"row_{k}": np.array([r[k] for r in rows]) for k in rows[0]}
    for label, f in fits.items():
        tag = label.replace(" ", "_").replace("+", "").replace("(", "").replace(")", "")
        out[f"A__{tag}"] = f["A"]
        if f["B"] is not None:
            out[f"B__{tag}"] = f["B"]
        out[f"Sigma__{tag}"] = f["Sigma"]
    out.update(sites=d["sites"], adj=adj, connectivity=connectivity,
               bridge_midline=bridge_midline, a_lags=a_lags, u_lags=u_lags,
               amp_mode=d["amp_mode"], site_of_input=d["site_of_input"], fs=FS,
               sigma_diagonal=sigma_diagonal)
    if rep is not None:
        out.update(chan_rank=rep["rank"], chan_cond=rep["cond"], chan_eig=rep["eig"])
    DATA.mkdir(exist_ok=True)
    np.savez_compressed(RESULT, **out)
    print(f"\nsaved -> {RESULT.name}")


# --------------------------------------------------------------------------------------
# figures
# --------------------------------------------------------------------------------------

def figures(rows, fits, sites, best="GDAR + B-free", n_steps=25):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    PNG.mkdir(exist_ok=True)
    f = fits[best]
    A, B = f["A"], f["B"]
    N = A.shape[0]

    fig, ax = plt.subplots(2, 3, figsize=(16.5, 10))

    # (0,0) held-out likelihood gain over the autonomous model
    lab = [r["label"] for r in rows]
    val = [r["ell_vs_autonomous"] for r in rows]
    col = ["0.6" if v <= 0 else "#2c7fb8" for v in val]
    ax[0, 0].barh(range(len(lab)), val, color=col)
    ax[0, 0].set_yticks(range(len(lab)))
    ax[0, 0].set_yticklabels(lab, fontsize=9)
    ax[0, 0].axvline(0, color="k", lw=0.8)
    ax[0, 0].set_xlabel("held-out log-lik / sample, vs autonomous")
    ax[0, 0].set_title("does the input term earn its parameters?", fontsize=10)
    ax[0, 0].invert_yaxis()

    # (0,1) direct input gain ||B[i,m,:]||
    G = gdar_x.input_gain(B)
    im = ax[0, 1].imshow(G, cmap="magma", aspect="auto")
    ax[0, 1].set_title(f"direct input gain  ||B[i,m,:]||\n{best}", fontsize=10)
    ax[0, 1].set_xlabel("stim site m"); ax[0, 1].set_ylabel("readout node i")
    plt.colorbar(im, ax=ax[0, 1], fraction=0.046)

    # (0,2) network-mediated steady-state gain
    Gd = gdar_x.dc_gain(A, B)
    v = np.nanpercentile(np.abs(Gd), 99)
    im = ax[0, 2].imshow(Gd, cmap="RdBu_r", vmin=-v, vmax=v, aspect="auto")
    ax[0, 2].set_title("DC gain  (I - sum A_k)^-1 sum B_r", fontsize=10)
    ax[0, 2].set_xlabel("stim site m"); ax[0, 2].set_ylabel("readout node i")
    plt.colorbar(im, ax=ax[0, 2], fraction=0.046)

    # (1,0) diagonal vs off-diagonal of the direct gain: is the input site-local?
    dg = np.diag(G) if G.shape[0] == G.shape[1] else G.max(1)
    off = G.copy()
    if G.shape[0] == G.shape[1]:
        np.fill_diagonal(off, np.nan)
    ax[1, 0].plot(dg, "o-", ms=3, label="own site  B[m,m]", color="#d95f02")
    ax[1, 0].plot(np.nanmean(off, 1), "s-", ms=3, label="mean other sites",
                  color="0.45")
    ax[1, 0].set_xlabel("stim site"); ax[1, 0].set_ylabel("||B|| (dF/F % per mW)")
    ax[1, 0].set_title("input locality: direct drive at the stimulated node\n"
                       "vs everywhere else", fontsize=10)
    ax[1, 0].legend(fontsize=8)

    # (1,1) network structure: summed AR coupling on the lattice
    Asum = A.sum(-1)
    v = np.nanpercentile(np.abs(Asum - np.diag(np.diag(Asum))), 99)
    im = ax[1, 1].imshow(Asum, cmap="RdBu_r", vmin=-v, vmax=v, aspect="auto")
    ax[1, 1].set_title(f"sum_k A_k   (rho = {gdar_x.spectral_radius(A):.3f})", fontsize=10)
    ax[1, 1].set_xlabel("from node j"); ax[1, 1].set_ylabel("to node i")
    plt.colorbar(im, ax=ax[1, 1], fraction=0.046)

    # (1,2) model impulse responses at the stimulated node
    h = gdar_x.impulse_response(A, B, n_steps)
    t = np.arange(n_steps) / FS
    x = np.asarray(sites)[:, 0]
    for m in range(min(B.shape[1], N)):
        c = "#1b7837" if x[m % N] < 0 else "#762a83"
        ax[1, 2].plot(t, h[:, m % N, m], color=c, lw=0.8, alpha=0.55)
    ax[1, 2].axhline(0, color="k", lw=0.8)
    ax[1, 2].set_xlabel("time after pulse (s)")
    ax[1, 2].set_ylabel("dF/F % (model)")
    ax[1, 2].set_title("model impulse response at the stimulated site\n"
                       "green = left (excitatory), purple = right (inhibitory)",
                       fontsize=10)

    fig.suptitle(f"GDAR-with-input on the AL_0048 grid  |  best = {best}", fontsize=13)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    p = PNG / "gdarx_summary.png"
    fig.savefig(p, dpi=140)
    plt.close(fig)
    print(f"figure -> {p.relative_to(PNG.parents[2])}")
    return p


# --------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rebuild", action="store_true", help="rebuild the X/U cache")
    ap.add_argument("--amp-mode", default="weight", choices=["weight", "unit", "split"])
    ap.add_argument("--connectivity", type=int, default=8, choices=[4, 8])
    ap.add_argument("--no-midline", action="store_true",
                    help="drop cross-hemisphere graph edges")
    ap.add_argument("--K-a", type=int, default=K_A)
    ap.add_argument("--K-u", type=int, default=K_U)
    ap.add_argument("--causal-u", action="store_true",
                    help="strictly causal input lags (1..K_u) instead of 0..K_u-1")
    ap.add_argument("--both-lags", action="store_true",
                    help="run both input-lag conventions and compare")
    ap.add_argument("--full-sigma", action="store_true",
                    help="use a full residual covariance in the GLS weight (diagnostic "
                         "only -- the ROI channels are rank deficient, see run() docstring)")
    ap.add_argument("--sigma-shrink", type=float, default=1e-6,
                    help="ridge on Sigma before inverting, as a fraction of tr(Sigma)/N")
    ap.add_argument("--no-figures", action="store_true")
    ap.add_argument("--no-check", action="store_true",
                    help="skip the X/U alignment check against the cached H")
    a = ap.parse_args()

    d = load(rebuild=a.rebuild, amp_mode=a.amp_mode)
    if not a.no_check:
        validate_alignment(d)
    kw = dict(connectivity=a.connectivity, bridge_midline=not a.no_midline,
              K_a=a.K_a, K_u=a.K_u, sigma_diagonal=not a.full_sigma,
              sigma_shrink=a.sigma_shrink)
    if a.both_lags:
        print("\n### strictly causal input lags (u_lags = 1..K_u) " + "#" * 40)
        run(d, u_lag0=False, save=False, **kw)
        print("\n### contemporaneous input lag included (u_lags = 0..K_u-1) " + "#" * 26)
    rows, fits, _ = run(d, u_lag0=not a.causal_u, **kw)
    if not a.no_figures:
        best = max((r for r in rows if r["b"] != "zero"),
                   key=lambda r: r["ell_mean"])["label"]
        figures(rows, fits, d["sites"], best=best)


if __name__ == "__main__":
    main()
