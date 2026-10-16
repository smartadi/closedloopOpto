"""Supplementary VARX figure (PROTOTYPE, user 2026-10-16: "the VARX model needs a demo of its own ... show how well it
predicts and also how it's constructed"). Static session AL_0033 2025-02-26 e2 (Fig 6 A-H), the SAME model as the MPC:
z = [controlled site y, 100 brain spots], L = 10 lags, Q = 35 laser lags, ridge 100. Held-out OL protocol of
mpc_varx_embed.py (5 folds over the 92 OL trials; training = spontaneous frames + training-fold OL trials).

Computes
  C  rolling 1 s iterated forecasts on one held-out OL trial (origins every 0.5 s, recorded future laser)
  D  R^2 of y vs lead: VARX | site + laser only (no cortex: ablation of the 100 spots) | (AR, naive from embed .mat)
  F  learned laser -> site response: model driven by the mean OL laser (laser-on minus laser-off rollout, zero
     history) vs the measured OL trial average (baseline = 1 s pre)
  G  weight of each input channel in the one-step y equation: sqrt(sum over lags W^2), standardized units
  H  whiteness: autocorrelation of held-out one-step residuals of y vs autocorrelation of y itself
Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_varx_supp.py [sess]
OUT     data/mpc_varx_supp_<sess>.mat
"""
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_varx_embed import fit, solve, iterate, r2, Q, POST, PAD, HMAX, LEADS  # noqa: E402

DATA = Path(__file__).resolve().parent / "data"
L, LAM = 10, 100.0


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    Wb = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    yr, ur, X = A["y"].astype(float), A["u"].astype(float), Wb["X"].astype(float)
    sy, su = yr[valid].std(), ur[valid].std()
    Z = np.column_stack([yr / sy, X / X[valid].std(0)]); u = ur / su
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = yr.size, onOL.size
    fold = np.random.default_rng(7).permutation(np.arange(nO) % 5) + 1        # = mpc_varx_embed folds

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    spont = ~(win(onOL, -pre, N + POST) | win(onCL, -pre, N + POST))

    def rows_for(f):
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        ok = (spont | win(onOL[tr], -pre, N + POST)) & ~win(onOL[te], -pre - PAD, N + POST + HMAX) & valid
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(PAD, T - HMAX - 1)
        return t[(cs[t + Q + 2] - cs[t - PAD + 1]) == 0], te

    H = int(LEADS.max())
    tg, fv, fs_, res, ytr = [], [], [], [], []
    Wf, origins_ex, fc_ex = {}, None, None
    orgs_rel = np.arange(-pre, N + 1)                                        # origins -1 .. 3 s (as embed)
    for f in range(1, 6):
        rows, te = rows_for(f)
        G, B = fit(Z, u, rows, L, LAM); W = solve(G, B, LAM); Wf[f] = W
        Zs = Z[:, :1]                                                         # ablation: site + laser only
        G1, B1 = fit(Zs, u, rows, L, LAM); W1 = solve(G1, B1, LAM)
        for k in te:
            org = onOL[k] + orgs_rel
            tg.append(Z[org[:, None] + np.arange(1, H + 1), 0])
            fv.append(iterate(Z, u, org, W, L, H)); fs_.append(iterate(Zs, u, org, W1, L, H))
            res.append(tg[-1][:, 0] - fv[-1][:, 0])                           # one-step residuals
            ytr.append(Z[org + 1, 0])
    # R^2 exactly as mpc_varx_embed (Fig 6G): origin o-1+t0, target y(o-1+t0+lead) inside the 0-3 s window
    tg, fv, fs_ = np.stack(tg), np.stack(fv), np.stack(fs_)                 # trial x origin x lead
    def r2lead(F, h):
        i = pre - 1 + np.arange(N - h + 1)
        return r2(tg[:, i, h - 1], F[:, i, h - 1])
    R2v = np.array([r2lead(fv, h) for h in LEADS]); R2s = np.array([r2lead(fs_, h) for h in LEADS])
    print(f"[VARX-S] R2 VARX  {np.round(R2v, 3)}\n[VARX-S] R2 site+laser only {np.round(R2s, 3)}", flush=True)

    # ---- C: example trial -- the held-out OL trial with median one-step R^2, rolling 1 s forecasts --------------
    ok = []
    for k in range(nO):
        f = fold[k]; o = onOL[k]; org = o + orgs_rel
        e1 = Z[org + 1, 0] - iterate(Z, u, org, Wf[f], L, 1)[:, 0]
        ok.append(np.mean(e1 ** 2))
    kx = int(np.argsort(ok)[nO // 2]); o = onOL[kx]; Wx = Wf[fold[kx]]
    org_ex = o + np.arange(-pre, N + 1, int(Fs / 2))                        # every 0.5 s
    fc_ex = iterate(Z, u, org_ex, Wx, L, int(Fs)) * sy                        # 1 s ahead
    ytrace = yr[o - 2 * pre:o + N + 2 * pre]; utrace = ur[o - 2 * pre:o + N + 2 * pre]
    print(f"[VARX-S] example OL trial {kx + 1} (fold {fold[kx]})", flush=True)

    # ---- F: learned laser response vs measured OL trial average ----------------------------------------------
    Uol = np.column_stack([ur[x - pre:x + N + 2 * pre] for x in onOL]).mean(1)       # mean OL command, -1..5 s
    Yol = np.column_stack([yr[x - pre:x + N + 2 * pre] - yr[x - pre:x].mean() for x in onOL])
    Wall = Wf[1]                                                              # fold-1 model (never saw fold-1 OL trials)
    zl = np.zeros((1, L, Z.shape[1])); M = Uol.size
    def roll(uu):
        hist = zl.copy(); out = np.empty(M); upad = np.concatenate([np.zeros(Q), uu / su])
        for h in range(M):
            a = np.hstack([hist.reshape(1, -1), upad[None, Q + h - np.arange(Q)], [[1.0]]])   # z(h) uses u(h..h-Q+1)
            nxt = a @ Wall; out[h] = nxt[0, 0]; hist = np.concatenate([nxt[:, None, :], hist[:, :-1, :]], 1)
        return out * sy
    resp = roll(Uol) - roll(np.zeros_like(Uol))
    print(f"[VARX-S] laser response: model min {resp.min():.2f} vs measured OL mean min {Yol.mean(1).min():.2f}", flush=True)

    # ---- G: channel weights in the y equation (fold-1 model; mean over folds) ------------------------------------
    nC = Z.shape[1]
    wy = np.mean([np.sqrt((W[:nC * L, 0].reshape(L, nC) ** 2).sum(0)) for W in Wf.values()], 0)
    wl = np.mean([W[nC * L:nC * L + Q, 0] for W in Wf.values()], 0) * sy / su   # laser lags, physical %/unit

    # ---- H: whiteness ----------------------------------------------------------------------------------------
    res = np.concatenate(res); ytr = np.concatenate(ytr)
    def acf(x, n):
        x = x - x.mean(); return np.array([np.sum(x[:-k] * x[k:]) / np.sum(x * x) if k else 1.0 for k in range(n + 1)])
    # per-trial ACFs averaged (segments are discontinuous across trials)
    seg = orgs_rel.size
    acf_r = np.mean([acf(res[i:i + seg], 35) for i in range(0, res.size, seg)], 0)
    acf_y = np.mean([acf(ytr[i:i + seg], 35) for i in range(0, ytr.size, seg)], 0)
    print(f"[VARX-S] residual ACF lag1 {acf_r[1]:.3f} lag5 {acf_r[5]:.3f} | y ACF lag1 {acf_y[1]:.3f} lag5 {acf_y[5]:.3f}")

    Em = loadmat(DATA / f"mpc_varx_embed_{sess}.mat", squeeze_me=True)
    Sw = loadmat(DATA / f"mpc_pred200_sweep_{sess}.mat", squeeze_me=True)
    savemat(DATA / f"mpc_varx_supp_{sess}.mat", {
        "lead_ms": LEADS * 1000 / Fs, "R2_varx": R2v, "R2_site": R2s, "R2_ar": Em["R2_ar"], "R2_naive": Em["R2_persist"],
        "R2_embed": Em["R2"], "ex_k": kx + 1, "ex_org": (org_ex - o) / Fs, "ex_fc": fc_ex, "ex_y": ytrace, "ex_u": utrace,
        "ex_t": np.arange(-2 * pre, N + 2 * pre) / Fs, "resp_model": resp, "resp_meas": Yol.mean(1),
        "resp_sem": Yol.std(1, ddof=1) / np.sqrt(nO), "resp_u": Uol, "resp_t": np.arange(-pre, N + 2 * pre) / Fs,
        "w_chan": wy, "w_laser": wl, "rc": Wb["rc"], "site_rc": Wb["site_rc"], "mask": Wb["mask"], "mimg": Wb["mimg"],
        "acf_res": acf_r, "acf_y": acf_y, "sweep_names": Sw["names"], "sweep_r2_86": Sw["val_r2_86"],
        "sweep_r2_200": Sw["val_r2_200"], "L": L, "lam": LAM, "Q": Q, "Fs": Fs, "nOL": nO})


if __name__ == "__main__":
    main(*sys.argv[1:])
