"""impulse_ols.py — contra->ipsi stim-blind OLS predictor for the AL_0048 dual-opsin session.

Python port of the impulse-analysis MATLAB pipeline (`ols_tf_pipeline.m`:
`local_stimblind_session` + `select_wlasso`/`cd_lasso`) into the bilateral/impulse module.
Isolates the LOCAL stim effect at each photostim site as the residual of a spontaneous-trained
contra->ipsi predictor built to be stim-blind, so the residual carries the evoked deflection
(the "Local" component) while the prediction carries ongoing network state flowing into the ipsi
kernel (the "Global" component).

MODEL = §17d [STIMBLIND-SELECT]: keep the stim-UNAFFECTED contra pixels (per-amp bled map), then
fit the spontaneous OLS with an L1 penalty that GROWS toward the ipsi stim site, so the surviving
predictors are FEW and FAR from the site (least stim-contaminated). There is NO dip-blinding
constraint, so Global is an HONEST LEAK: the residual captures the dip only insofar as those
distal predictors are genuinely stim-blind.

  [RETIRED 2026-07-18, upstream] The former §17b NATIVE KKT predictor (keep ALL unaffected px and
  zero the predicted dip by an equality constraint on a blind subspace) was removed upstream and
  is NOT ported here: it cancelled the dip BY CONSTRUCTION, so its ~100% dip capture was
  guaranteed rather than informative. SELECT's capture/leak split is the meaningful readout.

Dual-opsin twist: every trial stims ONE hemisphere, so the OTHER hemisphere is the unstimulated
"contra" predictor of global state on that trial. Run per side -> excitatory (left, +dF/F) and
inhibitory (right, -dF/F) local effects isolated in a single session, a within-animal
opposite-sign control.

Decomposition (per amplitude, trial-averaged, %dF/F at the focal ipsi pixel):
    Actual = ya              (measured peri-onset ipsi trace)
    Global = yg = bN' * evZ  (stim-blind contra prediction of ongoing state)
    Local  = rL = ya - yg    (the residual == the isolated local stim effect)

Reuses `impulse_core.load_session` (raw onset/amp/side) and `analysis.make_t2svd`. The contra
grid is built from a midline hemisphere split of the mean image (no hand-drawn ROI needed, unlike
the unilateral AL_0033 workbench which loads a cached ROI).
"""
from dataclasses import dataclass

import numpy as np

import analysis  # from bilateral/grid (on sys.path via impulse_config)


# ------------------------------------------------------------------ config knobs
@dataclass
class OLSConfig:
    """Stim-blind OLS knobs. Defaults mirror the MATLAB batch engine (cfg in ols_tf_pipeline)."""
    n_grid: int = 500        # target contra grid nodes
    edge_margin: int = 12    # erode: drop nodes whose (2*em+1)^2 nbhd isn't fully in-mask
    settle_s: float = 2.0    # post-onset settle before a spontaneous interstim window starts
    train_frac: float = 2 / 3
    max_frames: int = 60000  # cap on spontaneous frames
    pre_s: float = 0.5       # peri-onset pre window (baseline)
    post_s: float = 1.0      # peri-onset post window
    dip_win_s: float = 0.300  # inhibition/excitation energy window (data-driven, S15 SETTLETIME)
    bc_z_thr: float = 1.28   # bled-pixel z threshold (LOWER = more contra px dropped)
    # --- SELECT (§17d) sparse, distance-weighted stim-blind fit -------------------------
    select_l1frac: float = 0.15   # L1 strength (fraction of max|rescaled Z'y|); higher = sparser
    select_pen_near: float = 2.0  # L1 weight AT the ipsi site (expensive -> near px dropped)
    select_pen_far: float = 0.2   # L1 weight at the FARTHEST px (cheap -> far px retained)
    thr_pctile: float = 20   # intensity FLOOR inside the drawn outline (not a mask on its own)
    n_boot_couple: int = 200
    n_boot_bled: int = 300
    max_base_trl: int = 500  # cap on 0V pseudo-catch onsets
    lam_rel: float = 1e-6    # relative ridge on the Gram for the native OLS solve
    seed: int = 7


# ------------------------------------------------------------------ small helpers
def nearest_frames(svd_t, times):
    """Nearest SVD frame index to each query time (svd_t is sorted ascending)."""
    times = np.atleast_1d(times)
    j = np.searchsorted(svd_t, times)
    j = np.clip(j, 1, len(svd_t) - 1)
    left = np.abs(times - svd_t[j - 1]) <= np.abs(times - svd_t[j])
    return j - left.astype(int)


def _onsets_in_movie(svd_t, start_t, pre_n, post_n, n_frames):
    """Nearest frames whose [-pre_n, +post_n] window is fully inside the movie."""
    onf = nearest_frames(svd_t, start_t)
    keep = (onf - pre_n >= 0) & (onf + post_n < n_frames)
    return onf[keep]


def build_contra_grid(mask, cfg):
    """Eroded, subsampled grid over a given CONTRA mask (uniform lattice, ~n_grid nodes).

    `mask` is the hand-drawn contra hemisphere from `brain_mask.get_masks` — the project's
    single source of truth for this ROI. (Previously this function derived its own mask by
    thresholding + a bregma-x split; that was NOT a brain mask — `mimg > percentile(mimg, 20)`
    keeps 80% of the frame by construction and swept in the ventral/skull band. See RESEARCH
    2026-07-21.)

    Returns (rows, cols) integer pixel arrays of the kept grid nodes.
    """
    ny, nx = mask.shape
    rC, cC = np.where(mask)
    rmn, rmx, cmn, cmx = rC.min(), rC.max(), cC.min(), cC.max()
    d = max(1, int(round(np.sqrt(mask.sum() / cfg.n_grid))))
    grid_rc = None
    for _ in range(12):
        gr, gc = np.meshgrid(np.arange(rmn, rmx + 1, d), np.arange(cmn, cmx + 1, d), indexing="ij")
        gr, gc = gr.ravel(), gc.ravel()
        inm = mask[gr, gc]
        gr, gc = gr[inm], gc[inm]
        if gr.size >= cfg.n_grid or d == 1:
            grid_rc = (gr, gc)
            break
        d = max(1, d - 1)
    if grid_rc is None:
        grid_rc = (gr, gc)
    gr, gc = grid_rc

    em = cfg.edge_margin
    keep = (gr > em) & (gr <= ny - 1 - em) & (gc > em) & (gc <= nx - 1 - em)
    for g in np.where(keep)[0]:
        blk = mask[gr[g] - em:gr[g] + em + 1, gc[g] - em:gc[g] + em + 1]
        if not blk.all():
            keep[g] = False
    return gr[keep], gc[keep]


def _recon(u_grid, v_cols):
    """Reconstruct grid-pixel SVD signal: u_grid (nG, nSV) @ v_cols (nSV, nCols) -> (nG, nCols)."""
    return u_grid @ v_cols


def _peri_block(u_grid, mi_grid, V, onf, rel, pre_n):
    """Per-trial peri-onset %dF/F block for grid pixels.

    Returns (blk_pct (nG, Wb, nT) raw %dF/F, m (nG, Wb) pre-baselined trial-average)."""
    wb = rel.size
    nt = onf.size
    idx = (onf[:, None] + rel[None, :]).ravel()          # (nT*Wb,), t outer / w inner
    rec = _recon(u_grid, V[idx].T)                        # (nG, nT*Wb)
    blk = rec.reshape(u_grid.shape[0], nt, wb).transpose(0, 2, 1)   # (nG, Wb, nT)
    blk_pct = blk / mi_grid[:, None, None] * 100.0
    m = np.mean(blk_pct - blk_pct[:, :pre_n, :].mean(1, keepdims=True), axis=2)
    return blk_pct, m


def _peri_z(u_grid, V, mu_p, sd_p, onf, rel, pre_n):
    """z-scored (spont mu/sd) contra grid, trial-averaged peri-onset, baseline-subtracted -> (nG, Wb)."""
    wb = rel.size
    nt = onf.size
    idx = (onf[:, None] + rel[None, :]).ravel()
    z = (_recon(u_grid, V[idx].T) - mu_p[:, None]) / sd_p[:, None]
    z = z.reshape(u_grid.shape[0], nt, wb).transpose(0, 2, 1)       # (nG, Wb, nT)
    ev = z.mean(2)
    ev = ev - ev[:, :pre_n].mean(1, keepdims=True)
    return ev, z


def cd_lasso(G, c, dg, lam1, lam2=0.0, max_iter=400):
    """Coordinate-descent ELASTIC NET (port of cd_lasso):
        min_b  1/2||y - Z b||^2 + lam1*||b||_1 + (lam2/2)*||b||_2^2
    from precomputed G = Z'Z, c = Z'(y - mean(y)), dg = diag(G). lam2=0 -> pure lasso.
    """
    p = c.size
    b = np.zeros(p)
    Gb = np.zeros(p)
    for _ in range(max_iter):
        maxd = 0.0
        for j in range(p):
            rj = c[j] - Gb[j] + dg[j] * b[j]              # partial residual for coord j
            bj = np.sign(rj) * max(abs(rj) - lam1, 0.0) / (dg[j] + lam2)
            dbj = bj - b[j]
            if dbj != 0.0:
                Gb += G[:, j] * dbj
                b[j] = bj
                if abs(dbj) > maxd:
                    maxd = abs(dbj)
        if maxd < 1e-6 * max(1.0, np.max(np.abs(b))):
            break
    return b


def select_wlasso(G, c, S, gamma, l1frac, lamR):
    """SELECT model (port of select_wlasso): sparse, DISTANCE-WEIGHTED spont contra->ipsi fit
    restricted to predictor set S:
        min_b ||y - Z_S b||^2 + lam1 * sum_i (1/gamma_i)|b_i| + lam2||b||^2
    The 1/gamma_i penalty GROWS toward the ipsi site (gamma small near, large far), so near-ipsi
    predictors are expensive (dropped) and far ones cheap (retained) -> few predictors, all FAR
    from ipsi. Solved by column-rescaling b_i = gamma_i a_i, turning the weighted L1 into a
    UNIFORM lasso in a.
    """
    b = np.zeros(G.shape[0])
    if S.size == 0:
        return b
    g = gamma[S]
    Gs = np.outer(g, g) * G[np.ix_(S, S)]                 # Z~'Z~ with Z~ = Z_S diag(g)
    cs = g * c[S]
    dgs = np.diag(Gs).copy()
    lam1 = l1frac * np.max(np.abs(cs))                    # L1 scaled to the rescaled target
    a = cd_lasso(Gs, cs, dgs, lam1, lamR)
    b[S] = g * a                                          # undo the rescale
    return b


# ------------------------------------------------------------------ per-side engine
def stimblind_side(S, focal_px, sign, cfg, verbose=True):
    """Run the stim-blind contra->ipsi decomposition for one hemisphere.

    Parameters
    ----------
    S : dict from impulse_core.load_session (U, mimg, V, svdT, onset_t, amp, side, ...)
    focal_px : (px_x, px_y) data-derived focal ipsi pixel for THIS side
    sign : +1 excitatory (left), -1 inhibitory (right) — used only for reporting the signed dip
    cfg : OLSConfig
    side_name : which trials are IPSI (their contra is the opposite hemisphere)

    Returns a result dict (traces, dose, weights, R^2, per-trial arrays for state-dependence).
    """
    rng = np.random.default_rng(cfg.seed)
    U, mimg, V, svd_t = S["U"], S["mimg"], S["V"], S["svdT"]
    onset_t, amp, side = S["onset_t"], S["amp"], S["side"]
    ny, nx = mimg.shape
    fs = _FS_REF
    n_frames = V.shape[0]
    nsv = V.shape[1]

    # --- contra grid (opposite hemisphere from the site) --------------------------------
    gr, gc = S["_grid"]                              # prebuilt by the runner (shared per side)
    u_grid = np.asarray(U[gr, gc, :nsv]).astype(np.float64)   # (nG, nSV)
    mi_grid = mimg[gr, gc].astype(np.float64)
    n_g = gr.size

    # --- ipsi target = focal ROI %dF/F over all frames (SVD spatial mixing) --------------
    rad = ROI_RAD_REF
    x0, x1 = int(np.clip(focal_px[0] - rad, 0, nx)), int(np.clip(focal_px[0] + rad, 0, nx))
    y0, y1 = int(np.clip(focal_px[1] - rad, 0, ny)), int(np.clip(focal_px[1] + rad, 0, ny))
    spat = np.asarray(U[y0:y1, x0:x1, :nsv]).mean((0, 1)).astype(np.float64)   # (nSV,)
    mi_ipsi = float(mimg[y0:y1, x0:x1].mean())

    # --- onsets (this side stims THIS hemisphere; contra = opposite) --------------------
    pre_n = int(round(cfg.pre_s * fs))
    post_n = int(round(cfg.post_s * fs))
    rel = np.arange(-pre_n, post_n + 1)
    wb = rel.size
    amps = np.array(sorted(np.unique(amp[side == S["_side_name"]])))
    amps = amps[amps > 0]
    n_a = amps.size
    onf_by_amp = []
    for a in amps:
        st = onset_t[(side == S["_side_name"]) & (amp == a)]
        onf_by_amp.append(_onsets_in_movie(svd_t, st, pre_n, post_n, n_frames))

    # --- spontaneous interstim frames + train/test split --------------------------------
    all_starts = np.sort(onset_t[(side == S["_side_name"]) & (amp > 0)])
    ons = nearest_frames(svd_t, all_starts)
    settle = int(round(cfg.settle_s * fs))
    frames = []
    for j in range(ons.size):
        i0 = ons[j] + settle
        i1 = ons[j + 1] - 2 if j < ons.size - 1 else n_frames - 1
        i0, i1 = max(i0, 0), min(i1, n_frames - 1)
        if i1 >= i0:
            frames.append(np.arange(i0, i1 + 1))
    frames = np.unique(np.concatenate(frames))
    if frames.size > cfg.max_frames:
        frames = frames[np.round(np.linspace(0, frames.size - 1, cfg.max_frames)).astype(int)]
    n_tr = int(np.floor(cfg.train_frac * frames.size))
    itr, ite = frames[:n_tr], frames[n_tr:]

    # --- fixed z-scored contra design (z-score by train stats) --------------------------
    Xg_tr = _recon(u_grid, V[itr].T)                  # (nG, nTr)
    mu_p = Xg_tr.mean(1)
    sd_p = Xg_tr.std(1)
    sd_p[sd_p == 0] = 1
    Ztr = ((Xg_tr - mu_p[:, None]) / sd_p[:, None]).T          # (nTr, nG)
    Zte = ((_recon(u_grid, V[ite].T) - mu_p[:, None]) / sd_p[:, None]).T
    y_sp_tr = (spat @ V[itr].T) / mi_ipsi * 100.0
    y_sp_te = (spat @ V[ite].T) / mi_ipsi * 100.0

    # --- full-grid spont OLS (reference ceiling) ----------------------------------------
    muY = y_sp_tr.mean()
    G = Ztr.T @ Ztr
    cz = Ztr.T @ (y_sp_tr - muY)
    b_ols = np.linalg.solve(G + cfg.lam_rel * np.mean(np.diag(G)) * np.eye(n_g), cz)
    yhat_te = muY + Zte @ b_ols
    r2_ols = 1 - np.sum((y_sp_te - yhat_te) ** 2) / max(np.sum((y_sp_te - y_sp_te.mean()) ** 2), 1e-12)

    # --- 0V pseudo-catch (sham fires no laser -> gap midpoints between impulse onsets) ---
    impF = np.sort(nearest_frames(svd_t, all_starts))
    mids = np.round((impF[:-1] + impF[1:]) / 2).astype(int)
    gap_ok = (impF[1:] - impF[:-1]) > (pre_n + post_n + round(1.5 * fs))
    onf0 = mids[gap_ok]
    onf0 = onf0[(onf0 - pre_n >= 0) & (onf0 + post_n < n_frames)]
    if onf0.size > cfg.max_base_trl:
        onf0 = onf0[np.round(np.linspace(0, onf0.size - 1, cfg.max_base_trl)).astype(int)]
    n_t0 = onf0.size

    # --- per-amp evoked excess (amp - 0V), %dF/F, contra grid ---------------------------
    blk0_pct, m0 = _peri_block(u_grid, mi_grid, V, onf0, rel, pre_n)           # 0V baseline
    m_resp = np.full((n_g, wb, n_a), np.nan)
    ev_z = np.full((n_g, wb, n_a), np.nan)
    ya_by_amp, blk_ipsi_by_amp, z_by_amp = [], [], []
    nT_amp = np.zeros(n_a, dtype=int)
    for ai, a in enumerate(amps):
        onf = onf_by_amp[ai]
        nT_amp[ai] = onf.size
        if onf.size == 0:
            ya_by_amp.append(None); blk_ipsi_by_amp.append(None); z_by_amp.append(None); continue
        _, m_amp = _peri_block(u_grid, mi_grid, V, onf, rel, pre_n)
        m_resp[:, :, ai] = m_amp - m0
        evz, zblk = _peri_z(u_grid, V, mu_p, sd_p, onf, rel, pre_n)
        ev_z[:, :, ai] = evz
        z_by_amp.append(zblk.astype(np.float32))   # (nG, Wb, nT) for single-trial predictions
        # ipsi actual peri-onset (per-trial then trial-avg), %dF/F
        idx = (onf[:, None] + rel[None, :]).ravel()
        yblk = ((spat @ V[idx].T) / mi_ipsi * 100.0).reshape(onf.size, wb)
        yblk = yblk - yblk[:, :pre_n].mean(1, keepdims=True)
        blk_ipsi_by_amp.append(yblk)
        ya_by_amp.append(yblk.mean(0))

    # --- data-driven coupling window (b_ols . evoked vs 0V bootstrap null) ---------------
    post_cols = np.arange(pre_n, wb)
    idx0 = (onf0[:, None] + rel[None, :]).ravel()
    Z0 = (_recon(u_grid, V[idx0].T) - mu_p[:, None]) / sd_p[:, None]
    Z0 = Z0.reshape(n_g, n_t0, wb).transpose(0, 2, 1)          # (nG, Wb, nT0)
    Z0 = Z0 - Z0[:, :pre_n, :].mean(1, keepdims=True)
    cw_end = np.zeros(n_a)
    for ai in range(n_a):
        nT = nT_amp[ai]
        if nT == 0:
            continue
        P = b_ols @ ev_z[:, :, ai]
        bd = np.empty((cfg.n_boot_couple, wb))
        for b in range(cfg.n_boot_couple):
            ev0 = Z0[:, :, rng.integers(0, n_t0, nT)].mean(2)
            bd[b] = np.abs(b_ols @ ev0)
        Pn = np.quantile(bd, 0.95, axis=0)
        sig = np.abs(P[post_cols]) > Pn[post_cols]
        lk = np.where(sig)[0]
        if lk.size:
            cw_end[ai] = rel[pre_n + lk[-1]] / fs
    couple_win_s = max(cw_end.max(), 0.0) or cfg.dip_win_s
    null_win_s = max(couple_win_s, cfg.dip_win_s)
    cpl_cols = np.arange(pre_n, min(wb, pre_n + int(round(null_win_s * fs))))
    dip_cols = np.arange(pre_n, min(wb, pre_n + int(round(cfg.dip_win_s * fs))))

    # --- per-amp bled map (which contra px are stim-affected) ----------------------------
    e_dip = np.nanmean(np.abs(m_resp[:, cpl_cols, :]), axis=1)   # (nG, nA)
    bled = np.zeros((n_g, n_a), dtype=bool)
    for ai in range(n_a):
        nT = nT_amp[ai]
        if nT == 0:
            continue
        nd = np.empty((n_g, cfg.n_boot_bled))
        for r in range(cfg.n_boot_bled):
            bb = blk0_pct[:, :, rng.integers(0, n_t0, nT)]
            mb = (bb - bb[:, :pre_n, :].mean(1, keepdims=True)).mean(2) - m0
            nd[:, r] = np.abs(mb[:, cpl_cols]).mean(1)
        z = (e_dip[:, ai] - nd.mean(1)) / np.maximum(nd.std(1), 1e-12)
        bled[:, ai] = z > cfg.bc_z_thr

    # --- SELECT (§17d) sparse, DISTANCE-WEIGHTED stim-blind fit per amp -------------------
    # L1 penalty grows toward the ipsi site -> few predictors, all FAR from it. No dip-blinding,
    # so Global is an HONEST LEAK. Distance in ARRAY coords (display orientation is an isometry).
    lamR = cfg.lam_rel * np.mean(np.diag(G))
    selD = np.hypot(gc - focal_px[0], gr - focal_px[1])   # focal_px = (x=col, y=row)
    selDn = (selD - selD.min()) / max(selD.max() - selD.min(), 1e-12)
    gammaS = 1.0 / (cfg.select_pen_near * (1 - selDn) + cfg.select_pen_far * selDn)

    sstot = max(np.sum((y_sp_te - y_sp_te.mean()) ** 2), 1e-12)
    A_dip = np.full(n_a, np.nan); G_dip = np.full(n_a, np.nan); L_dip = np.full(n_a, np.nan)
    r2_clean = np.full(n_a, np.nan)
    n_drop = np.zeros(n_a, dtype=int); n_active = np.zeros(n_a, dtype=int)
    trA, trG, trL, b_clean = [], [], [], []
    pred_by_amp, resid_by_amp = [], []      # single-trial (nT, Wb) prediction + residual
    for ai in range(n_a):
        onf = onf_by_amp[ai]
        if onf.size == 0 or np.all(np.isnan(ev_z[:, :, ai])):
            trA.append(None); trG.append(None); trL.append(None); b_clean.append(None)
            pred_by_amp.append(None); resid_by_amp.append(None); continue
        active = ~bled[:, ai]                             # keep stim-UNAFFECTED px
        if active.sum() < 5:
            active = np.ones(n_g, dtype=bool)
        Sset = np.where(active)[0]
        n_drop[ai] = n_g - Sset.size
        ya = ya_by_amp[ai]
        bfull = select_wlasso(G, cz, Sset, gammaS, cfg.select_l1frac, lamR)
        n_active[ai] = int(np.count_nonzero(bfull))
        yg = ev_z[:, :, ai].T @ bfull                     # Global = sparse distal prediction
        yg = yg - yg[:pre_n].mean()
        rL = ya - yg                                      # Local = residual (carries the dip)
        r2_clean[ai] = 1 - np.sum((y_sp_te - (muY + Zte @ bfull)) ** 2) / sstot
        b_clean.append(bfull)
        trA.append(ya); trG.append(yg); trL.append(rL)
        A_dip[ai] = ya[dip_cols].mean(); G_dip[ai] = yg[dip_cols].mean(); L_dip[ai] = rL[dip_cols].mean()
        # single-trial stim-blind prediction + residual (the DV the state-dep stage operates on)
        ptr = np.einsum("g,gwt->tw", bfull, z_by_amp[ai].astype(np.float64))
        ptr = ptr - ptr[:, :pre_n].mean(1, keepdims=True)
        pred_by_amp.append(ptr)
        resid_by_amp.append(blk_ipsi_by_amp[ai] - ptr)

    med_local_pct = np.nanmedian(100 * L_dip / A_dip)
    med_leak_pct = np.nanmedian(100 * G_dip / A_dip)
    if verbose:
        print(f"    grid nodes={n_g}  spont R2(full)={r2_ols:.3f}  couple_win={couple_win_s*1000:.0f}ms"
              f"  medCapture={med_local_pct:.0f}%  medLeak={med_leak_pct:.0f}%"
              f"  nActive={n_active.min()}-{n_active.max()}")

    return dict(
        amps=amps, rel=rel, fs=fs, pre_n=pre_n, sign=sign,
        Actual=A_dip, Global=G_dip, Local=L_dip,
        trA=trA, trG=trG, trL=trL,
        r2_ols=r2_ols, r2_clean=r2_clean, n_drop=n_drop, n_active=n_active, n_g=n_g,
        med_local_pct=med_local_pct, med_leak_pct=med_leak_pct,
        selD=selD, gammaS=gammaS, dip_cols=dip_cols, cpl_cols=cpl_cols,
        couple_win_s=couple_win_s, null_win_s=null_win_s,
        b_ols=b_ols, b_clean=b_clean, bled=bled, grid_rc=(gr, gc),
        blk_ipsi_by_amp=blk_ipsi_by_amp, ev_z=ev_z, mu_p=mu_p, sd_p=sd_p,
        nT_amp=nT_amp, focal_px=focal_px,
        pred_by_amp=pred_by_amp, resid_by_amp=resid_by_amp,
        # held-out spontaneous prediction (what r2_ols / r2_clean actually mean)
        y_te=y_sp_te, yhat_te_ols=yhat_te,
        yhat_te_select=(muY + Zte @ b_clean[-1]) if b_clean and b_clean[-1] is not None else None,
    )


# module-level refs set by the runner from the shared grid/impulse config
_FS_REF = 70.0
ROI_RAD_REF = 8
