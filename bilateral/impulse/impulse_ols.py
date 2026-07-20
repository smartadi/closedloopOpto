"""impulse_ols.py — contra->ipsi stim-blind OLS predictor for the AL_0048 dual-opsin session.

Python port of the impulse-analysis MATLAB pipeline (`ols_tf_pipeline.m`:
`local_stimblind_session` + `native_project`) into the bilateral/impulse module. Isolates the
LOCAL stim effect at each photostim site as the residual of a spontaneous-trained contra->ipsi
predictor whose weights are projected BLIND to the stim-coupling subspace, so the residual
carries the full evoked deflection (the "Local" component), while the prediction carries only
ongoing network state flowing into the ipsi kernel (the "Global" component).

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
    n_blind: int = 4         # # blind sub-windows for the KKT stim-subspace projection
    bc_z_thr: float = 1.28   # bled-pixel z threshold (LOWER = more contra px dropped)
    thr_pctile: float = 20   # brain-mask percentile on the mean image
    midline_margin_mm: float = 0.5  # gutter (mm) excluded either side of the bregma midline
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


def build_contra_grid(mimg, bregma_px, site_xy, cfg):
    """Eroded, subsampled grid over the CONTRA hemisphere (opposite the photostim site).

    Brain mask = mimg above `thr_pctile`; hemispheres split at the bregma x-midline with a
    `midline_margin_mm` gutter; contra = the side NOT containing the site. Mirrors the MATLAB
    grid build (uniform eroded lattice, ~n_grid nodes) but derives the mask from the midline
    rather than a hand-drawn ROI.

    Returns (rows, cols) integer pixel arrays of the kept grid nodes.
    """
    ny, nx = mimg.shape
    thr = np.percentile(mimg, cfg.thr_pctile)
    brain = mimg > thr

    mid_x = bregma_px[0]
    margin_px = cfg.midline_margin_mm * PX_PER_MM_X_REF
    site_left = site_xy[0] < mid_x            # site on the left (smaller x) side of midline
    xx = np.arange(nx)[None, :] * np.ones((ny, 1))
    if site_left:                             # contra = right hemisphere
        hemi = xx > (mid_x + margin_px)
    else:                                     # contra = left hemisphere
        hemi = xx < (mid_x - margin_px)
    mask = brain & hemi

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


# module-level px/mm for the midline gutter (set by the runner from the shared grid config)
PX_PER_MM_X_REF = 1.0


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


def _native_project(n_blind, ev_z, ya, dip_cols, stim_cols, S, dG_inv, b0, pre_n, wb,
                    yte, muY, Zte, sstot):
    """NATIVE stim-blind KKT projection (port of native_project).

    Split the coupling window `stim_cols` into `n_blind` sub-windows, blind the prediction to
    each sub-window's mean evoked contra direction, return constrained weights + Global/residual
    traces + held-out R^2. `dG_inv` is a callable solving G[S,S] x = rhs.
    """
    edg = np.round(np.linspace(0, stim_cols.size, n_blind + 1)).astype(int)
    D = np.zeros((S.size, n_blind))
    for q in range(n_blind):
        cc = stim_cols[edg[q]:edg[q + 1]]
        if cc.size:
            D[:, q] = ev_z[np.ix_(S, cc)].mean(1)
    D = D[:, np.any(np.abs(D) > 0, axis=0)]
    if D.size:
        GD = dG_inv(D)                                    # G[S,S]^-1 D
        bN = b0 - GD @ (np.linalg.pinv(D.T @ GD) @ (D.T @ b0))
    else:
        bN = b0.copy()
    yg = ev_z[S, :].T @ bN
    yg = yg - yg[:pre_n].mean()
    rL = ya - yg
    r2sb = 1 - np.sum((yte - (muY + Zte[:, S] @ bN)) ** 2) / sstot
    return bN, yg, rL, r2sb


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
    ya_by_amp, blk_ipsi_by_amp = [], []
    nT_amp = np.zeros(n_a, dtype=int)
    for ai, a in enumerate(amps):
        onf = onf_by_amp[ai]
        nT_amp[ai] = onf.size
        if onf.size == 0:
            ya_by_amp.append(None); blk_ipsi_by_amp.append(None); continue
        _, m_amp = _peri_block(u_grid, mi_grid, V, onf, rel, pre_n)
        m_resp[:, :, ai] = m_amp - m0
        evz, _ = _peri_z(u_grid, V, mu_p, sd_p, onf, rel, pre_n)
        ev_z[:, :, ai] = evz
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

    # --- NATIVE stim-blind projection per amp -------------------------------------------
    sstot = max(np.sum((y_sp_te - y_sp_te.mean()) ** 2), 1e-12)
    A_dip = np.full(n_a, np.nan); G_dip = np.full(n_a, np.nan); L_dip = np.full(n_a, np.nan)
    r2_clean = np.full(n_a, np.nan); n_drop = np.zeros(n_a, dtype=int)
    trA, trG, trL, b_clean = [], [], [], []
    for ai in range(n_a):
        onf = onf_by_amp[ai]
        if onf.size == 0 or np.all(np.isnan(ev_z[:, :, ai])):
            trA.append(None); trG.append(None); trL.append(None); b_clean.append(None); continue
        active = ~bled[:, ai]
        if active.sum() < 5:
            active = np.ones(n_g, dtype=bool)
        Sset = np.where(active)[0]
        n_drop[ai] = n_g - Sset.size
        Gss = G[np.ix_(Sset, Sset)] + cfg.lam_rel * np.mean(np.diag(G)) * np.eye(Sset.size)
        Gss_lu = np.linalg.inv(Gss)          # small (|active| x |active|); reused for b0 + GD
        b0 = Gss_lu @ cz[Sset]
        ya = ya_by_amp[ai]
        bN, yg, rL, r2sb = _native_project(
            cfg.n_blind, ev_z[:, :, ai], ya, dip_cols, cpl_cols, Sset,
            lambda M, _M=Gss_lu: _M @ M, b0, pre_n, wb, y_sp_te, muY, Zte, sstot)
        r2_clean[ai] = r2sb
        bfull = np.zeros(n_g); bfull[Sset] = bN; b_clean.append(bfull)
        trA.append(ya); trG.append(yg); trL.append(rL)
        A_dip[ai] = ya[dip_cols].mean(); G_dip[ai] = yg[dip_cols].mean(); L_dip[ai] = rL[dip_cols].mean()

    med_local_pct = np.nanmedian(100 * L_dip / A_dip)
    if verbose:
        print(f"    grid nodes={n_g}  spont R2(full)={r2_ols:.3f}  "
              f"couple_win={couple_win_s*1000:.0f}ms  medLocal%={med_local_pct:.0f}")

    return dict(
        amps=amps, rel=rel, fs=fs, pre_n=pre_n, sign=sign,
        Actual=A_dip, Global=G_dip, Local=L_dip,
        trA=trA, trG=trG, trL=trL,
        r2_ols=r2_ols, r2_clean=r2_clean, n_drop=n_drop, n_g=n_g,
        med_local_pct=med_local_pct, dip_cols=dip_cols, cpl_cols=cpl_cols,
        couple_win_s=couple_win_s, null_win_s=null_win_s,
        b_ols=b_ols, b_clean=b_clean, bled=bled, grid_rc=(gr, gc),
        blk_ipsi_by_amp=blk_ipsi_by_amp, ev_z=ev_z, mu_p=mu_p, sd_p=sd_p,
        nT_amp=nT_amp, focal_px=focal_px,
    )


# module-level refs set by the runner from the shared grid/impulse config
_FS_REF = 70.0
ROI_RAD_REF = 8
