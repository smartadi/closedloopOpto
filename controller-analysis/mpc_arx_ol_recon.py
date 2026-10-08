"""Does an AR / ARX model trained on spontaneous + open-loop data predict the STIM RESPONSE?
Held-out open-loop (OL) trial reconstruction, one controller session (default AL_0033 2025-02-26 e2).

Signal: the rig's online dF/F of the controlled ROI (y = data.dFk, Fig-3 frame), modelled DIRECTLY
(not the plant-residual disturbance): y[s] = sum_i a_i y[s-i] + sum_j b_j u[s-j] + c + e, where u is
the recorded laser command at the frame times (ctrl_mpc_arx_export.m bundle). Order selection is the
Lu et al. 2025 AR(valQL) recipe (mpc_arx_forecaster.select_and_fit): lags grown until validation
MWQL fails to improve 10x in a row, chronologically last 20 % of the training frames as validation.

Models (5-fold CV over the 92 OL trials; a test trial's window -1 s .. +5 s, padded by the max lag,
never enters training):
  AR          spont + training OL, no stim input  (the paper's model, as-is)
  ARX         spont + training OL, laser-command lags
  ARX+CL      spont + training OL + ALL CL trials (feedback data: u depends on past noise)
Baselines: template = training-fold OL trial average (stim-locked mean); persistence.

Tests on each held-out OL trial (future stim is KNOWN in OL -- it is pre-scheduled):
  1 free-run simulation from rel -1 frame to +4 s given only the stim command (no y feedback)
  2 k-step-ahead forecasts from every origin in 0..3 s, leads 1..35 (what an MPC preview would use)

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_arx_ol_recon.py [sess]
OUT     controller-analysis/data/mpc_arx_ol_recon_<sess>.mat, paper/images/mpc_arx/ol_recon_*.png
"""
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mpc_arx_forecaster as M  # noqa: E402  (select_and_fit, fit, psi_sd, P_MAX, Q_GRID)

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
FIG = HERE.parent / "paper" / "images" / "mpc_arx"
POST = 70                       # frames after stim end kept inside a trial window (2 s recovery)
SIM_H = 141                     # free run: rel 0 .. +4 s
LEADS = np.array([1, 2, 3, 5, 7, 10, 17, 35])
COL = {"rec": "k", "template": "0.6", "AR": "#c08a00", "ARX": "#5b2c86", "ARX+CL": "#2a9d8f"}


forecast_known_u = M.forecast_known_u


def step_response(a, b, H=105):
    """Response of the fitted ARX to a unit step in u (0 before), from rest."""
    p, q = a.size, b.size
    y = np.zeros(H + p)
    uu = np.concatenate([np.zeros(q), np.ones(H)])
    for s in range(H):
        y[p + s] = y[p + s - p:p + s][::-1] @ a + (uu[q + s - q:q + s][::-1] @ b if q else 0.0)
    return y[p:]


def main(sess="AL_0033_0226_e2"):
    B = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    y, u = B["y"].astype(float), B["u"].astype(float)
    onOL, onCL = B["onOL"].astype(int) - 1, B["onCL"].astype(int) - 1
    pre, N, H, Fs = int(B["pre"]), int(B["N"]), int(B["Hp"]), float(B["Fs"])
    T, nO = y.size, onOL.size
    pad = M.P_MAX + max(M.Q_GRID)

    def win_mask(ons, lo=-pre, hi=N + POST, extra=0):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + extra + 1)] = True
        return m

    inOL, inCL = win_mask(onOL), win_mask(onCL)
    spont = ~(inOL | inCL)
    rng = np.random.default_rng(7)
    fold = rng.permutation(np.arange(nO) % 5) + 1
    print(f"[OLREC] {sess}: {T} frames, spont {spont.mean()*100:.0f} %, {nO} OL / {onCL.size} CL trials", flush=True)

    rel_sim = np.arange(SIM_H)                                   # targets rel 0..140 from origin rel -1
    models = ("AR", "ARX", "ARX+CL")
    SIM = {m: np.full((nO, SIM_H), np.nan) for m in models + ("template",)}
    KST = {m: np.full((nO, N, H), np.nan) for m in models}       # k-step forecasts, origins rel 0..N-1
    orders, steps = {m: [] for m in models}, {m: [] for m in models}
    for f in range(1, 6):
        te = np.flatnonzero(fold == f)
        tr_ol = np.flatnonzero(fold != f)
        test_block = win_mask(onOL[te], extra=pad)
        ok_base = (spont | win_mask(onOL[tr_ol])) & ~test_block
        ok_cl = (ok_base | inCL) & ~test_block
        # template baseline: training-fold OL stim-locked mean, rel 0..140
        tmpl = np.mean([y[o:o + SIM_H] for o in onOL[tr_ol]], axis=0)
        SIM["template"][te] = tmpl
        for m, ok, use_u in (("AR", ok_base, False), ("ARX", ok_base, True), ("ARX+CL", ok_cl, True)):
            R = M.select_and_fit(y, u, ok, H, use_u, known_u=True)
            orders[m].append((f, R["p"], R["q"], R["val_mwql"]))
            steps[m].append(step_response(R["a"], R["b"]))
            print(f"[OLREC] fold {f} {m:7s} p={R['p']:3d} q={R['q']:2d} valMWQL={R['val_mwql']:.4f}", flush=True)
            org = onOL[te] - 1                                    # last observed = rel -1
            SIM[m][te] = forecast_known_u(y, u, org, R["a"], R["b"], R["c"], SIM_H)
            for k in te:
                KST[m][k] = forecast_known_u(y, u, onOL[k] + np.arange(N) - 1, R["a"], R["b"], R["c"], H)

    REC = np.stack([y[o:o + SIM_H] for o in onOL])               # rel 0..140
    PRE = np.stack([y[o - pre:o] for o in onOL])
    U = np.stack([u[o - pre:o + SIM_H] for o in onOL])
    w = slice(0, N)                                               # stim window 0..3 s

    # ---- metrics ------------------------------------------------------------------------------
    rmse = {m: np.sqrt(np.mean((SIM[m][:, w] - REC[:, w]) ** 2, axis=1)) for m in SIM}
    avg_r2 = {m: 1 - np.sum((SIM[m][:, w].mean(0) - REC[:, w].mean(0)) ** 2)
                 / np.sum((REC[:, w].mean(0) - REC[:, w].mean(0).mean()) ** 2) for m in SIM}
    # single-trial variance explained around the stim-locked mean: does the model track trial-specific
    # fluctuations beyond the template?  R2_dev = 1 - SSE(model) / SSE(template)
    sse = {m: np.sum((SIM[m][:, w] - REC[:, w]) ** 2, axis=1) for m in SIM}
    rel_tmpl = {m: np.median(sse[m] / sse["template"]) for m in models}
    print("[OLREC] free-run 0-3 s: median per-trial RMSE " +
          ", ".join(f"{m} {np.median(rmse[m]):.2f}" for m in SIM))
    print("[OLREC] free-run trial-average R2 " + ", ".join(f"{m} {avg_r2[m]:.3f}" for m in SIM))
    print("[OLREC] free-run SSE / template SSE (median) " + ", ".join(f"{m} {rel_tmpl[m]:.2f}" for m in models))

    # k-step: error vs lead, targets in 0..3 s, normalised by the template error at the same targets
    kerr, kerr_t, kerr_p = {}, [], []
    for L in LEADS:
        t0 = np.arange(N - L + 1)                                 # origins rel t0-1, target rel t0+L-1
        tgt = REC[:, t0 + L - 1]
        kerr_t.append(np.sqrt(np.mean((tgt - SIM["template"][:, t0 + L - 1]) ** 2)))
        last = np.stack([y[o + t0 - 1] for o in onOL])
        kerr_p.append(np.sqrt(np.mean((tgt - last) ** 2)))
        for m in models:
            kerr.setdefault(m, []).append(np.sqrt(np.mean((tgt - KST[m][:, t0, L - 1]) ** 2)))
    kerr = {m: np.array(v) for m, v in kerr.items()}
    kerr_t, kerr_p = np.array(kerr_t), np.array(kerr_p)
    lead_ms = LEADS * 1000 / Fs
    print("[OLREC] k-step RMSE @ " + str(np.round(lead_ms).astype(int)) + " ms")
    for m in models:
        print(f"         {m:7s} {np.round(kerr[m], 2)}")
    print(f"         template {np.round(kerr_t, 2)}\n         persist  {np.round(kerr_p, 2)}")

    # ---- figure ----------------------------------------------------------------------------------
    FIG.mkdir(parents=True, exist_ok=True)
    tt = np.arange(-pre, SIM_H) / Fs
    ts = rel_sim / Fs
    fig, ax = plt.subplots(2, 3, figsize=(15, 7.5), constrained_layout=True)
    ex = np.argsort(rmse["ARX"])[[nO // 4, nO // 2, 3 * nO // 4]]  # good / median / poor (by ARX)
    for i, k in enumerate(ex):
        a = ax[0, i]
        a.plot(tt, np.concatenate([PRE[k], REC[k]]), color=COL["rec"], lw=1.2, label="recorded")
        for m in ("template", "AR", "ARX", "ARX+CL"):
            a.plot(ts, SIM[m][k], color=COL[m], lw=1.2 if m != "template" else 1.0,
                   ls="--" if m == "template" else "-", label=m)
        a2 = a.twinx(); a2.fill_between(tt, 0, U[k], color="0.85", step="mid", zorder=0)
        a2.set_ylim(0, U.max() * 3); a2.set_yticks([]); a.set_zorder(a2.get_zorder() + 1); a.patch.set_visible(False)
        a.axvline(0, color="0.7", lw=0.6)
        a.set_title(f"held-out OL trial {k + 1}  (ARX rank {['25th', '50th', '75th'][i]} pct)", fontsize=9)
        a.set_xlabel("time from onset (s)"); a.set_ylabel("dF/F (%)")
        if i == 0:
            a.legend(fontsize=7, frameon=False, loc="lower left")
    a = ax[1, 0]
    a.plot(tt, np.concatenate([PRE.mean(0), REC.mean(0)]), color="k", lw=1.6, label="recorded")
    for m in ("template", "AR", "ARX", "ARX+CL"):
        a.plot(ts, SIM[m].mean(0), color=COL[m], lw=1.3, ls="--" if m == "template" else "-",
               label=(f"{m} (R² {avg_r2[m]:.2f})" if m != "template"
                      else "template (training-fold mean; ~grand mean, R² trivially ~1)"))
    a.set_title("trial average of held-out free-run simulations", fontsize=9)
    a.set_xlabel("time from onset (s)"); a.set_ylabel("dF/F (%)"); a.legend(fontsize=7, frameon=False)
    a = ax[1, 1]
    data = [rmse[m] for m in ("template", "AR", "ARX", "ARX+CL")]
    bp = a.boxplot(data, tick_labels=["template", "AR", "ARX", "ARX+CL"], showfliers=False, widths=0.5)
    for i, m in enumerate(("template", "AR", "ARX", "ARX+CL")):
        a.scatter(np.full(nO, i + 1) + rng.uniform(-0.15, 0.15, nO), rmse[m], s=5, color=COL[m], alpha=0.5)
    a.set_ylabel("per-trial RMSE, 0-3 s (%dF/F)"); a.set_title("free-run reconstruction error (92 held-out OL trials)", fontsize=9)
    a = ax[1, 2]
    for m in models:
        a.plot(lead_ms, kerr[m], "-o", color=COL[m], ms=3, label=m)
    a.plot(lead_ms, kerr_t, "--", color=COL["template"], label="template")
    a.plot(lead_ms, kerr_p, ":", color="0.4", label="persistence")
    a.axvline(57, color="0.7", lw=0.6, ls=":"); a.set_xscale("log")
    a.set_xlabel("forecast lead (ms)"); a.set_ylabel("RMSE (%dF/F)")
    a.set_title("k-step forecast with known stim, origins 0-3 s", fontsize=9); a.legend(fontsize=7, frameon=False)
    fig.savefig(FIG / f"ol_recon_{sess}.png", dpi=200)

    fig2, a = plt.subplots(figsize=(5, 3.2), constrained_layout=True)
    for m in ("ARX", "ARX+CL"):
        S = np.array(steps[m])
        for s_ in S:
            a.plot(np.arange(S.shape[1]) / Fs, s_, color=COL[m], lw=0.6, alpha=0.6)
        a.plot([], [], color=COL[m], label=f"{m} (5 folds)")
    a.set_xlabel("time from step (s)"); a.set_ylabel("dF/F per unit command")
    a.set_title("learned stim step response", fontsize=9); a.legend(fontsize=7, frameon=False)
    fig2.savefig(FIG / f"ol_recon_step_{sess}.png", dpi=200)

    savemat(DATA / f"mpc_arx_ol_recon_{sess}.mat", {
        "SIM": {k.replace("+", "_"): v for k, v in SIM.items()}, "REC": REC, "fold": fold,
        "rmse": {k.replace("+", "_"): v for k, v in rmse.items()},
        "avg_r2": {k.replace("+", "_"): v for k, v in avg_r2.items()},
        "kerr": {k.replace("+", "_"): v for k, v in kerr.items()}, "kerr_template": kerr_t,
        "kerr_persist": kerr_p, "lead_ms": lead_ms,
        "orders": {k.replace("+", "_"): np.array(v) for k, v in orders.items()},
        "steps": {k.replace("+", "_"): np.array(v) for k, v in steps.items()}}, do_compression=True)
    print(f"[OLREC] -> {FIG / f'ol_recon_{sess}.png'}")


if __name__ == "__main__":
    main(*sys.argv[1:])
