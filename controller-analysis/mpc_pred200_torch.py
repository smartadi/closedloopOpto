"""200 ms predictor, round 2 (user 2026-10-07: "do 1 and 2 ... we can use the widefield svd components directly").

Change 1 -- SELECT ON STIMULATED TRIALS. Inside each outer fold, 20 % of the TRAINING OL trials are held out
            as an inner validation set (their windows removed from training). Hyperparameters and early
            stopping are scored on R^2 of the controlled spot at 200 ms over those trials (origins at every
            frame of the trial, exactly as the test), not on the mostly-spontaneous chronological tail.
Change 2 -- TRAIN ON THE ROLLOUT. The delay-embedded VARX (state z = [controlled spot, inputs], L lags, Q laser
            lags, known future laser) is initialised from its one-step ridge fit and then fine-tuned in torch
            on the error of the 7-step iterated rollout (backprop through the rollout), + ridge penalty.
Inputs   -- the 100 brain spots (as before) vs the first k widefield SVD temporal components (k = 50/100/200;
            ctrl_mpc_svd_export.m), each z-scored on valid frames.
Selection (fold 1 inner validation): inputs x L x lambda for the one-step ridge, then rollout fine-tuning
            variants (lead weighting, state-loss weight) on the best one or two input sets.
Test     -- 92 held-out OL trials, 5 folds (same folds/exclusions as before): R^2 at 86 / 200 ms + lag, against
            the current VARX (spots, L10, lambda100: 0.687 / 0.419) and persistence (0.098 at 200 ms).

Usage:  .venv\\Scripts\\python.exe controller-analysis\\mpc_pred200_torch.py [sess]
OUT     data/mpc_pred200_torch_<sess>.mat, paper/images/mpc_arx/pred200_torch_<sess>.png
"""
import sys
import time
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import torch
from scipy.io import loadmat, savemat

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mpc_pred200_sweep import Model, BASE, r2, POST, HMAX, PAD, H7  # noqa: E402

HERE = Path(__file__).resolve().parent
DATA, FIG = HERE / "data", HERE.parent / "paper" / "images" / "mpc_arx"
INNER_FRAC, BATCH, MAX_EP, PATIENCE = 0.2, 512, 60, 8   # lr 3e-4 wrecked the ridge init (first run) -> per-variant lr <= 3e-5
torch.manual_seed(0)


def rollout_t(W, Zt, ut, org, L, Q, H):
    """Iterated H-step forecast of the full state (torch, differentiable). Feature order == Model.phi."""
    lags, ql = torch.arange(L), torch.arange(Q)
    hist = Zt[org[:, None] - lags]                                      # B x L x nC (lag-major)
    one = torch.ones(org.numel(), 1)
    out = []
    for h in range(H):
        A = torch.cat([hist.reshape(org.numel(), -1), ut[org[:, None] + h + 1 - ql], one], 1)
        nxt = A @ W
        out.append(nxt)
        hist = torch.cat([nxt[:, None, :], hist[:, :-1, :]], 1)
    return torch.stack(out, 1)                                          # B x H x nC


def main(sess="AL_0033_0226_e2"):
    A = loadmat(DATA / f"ctrl_mpc_arx_in_{sess}.mat", squeeze_me=True)
    valid = A["valid"].astype(bool)
    yr, ur = A["y"].astype(float), A["u"].astype(float)
    sy = yr[valid].std(); y = yr / sy; u = ur / ur[valid].std()
    Xsp = loadmat(DATA / f"ctrl_mpc_wb_in_{sess}_n100.mat", squeeze_me=True)["X"].astype(float)
    Vsv = loadmat(DATA / f"ctrl_mpc_svd_in_{sess}_k200.mat", squeeze_me=True)["V"].astype(float)
    INPUTS = {"spots100": Xsp / Xsp[valid].std(0)}
    for k in (50, 100, 200):
        INPUTS[f"svd{k}"] = Vsv[:, :k] / Vsv[valid, :k].std(0)
    onOL, onCL = A["onOL"].astype(int) - 1, A["onCL"].astype(int) - 1
    pre, N, Fs = int(A["pre"]), int(A["N"]), float(A["Fs"])
    T, nO = yr.size, onOL.size
    fold = np.random.default_rng(7).permutation(np.arange(nO) % 5) + 1

    def win(ons, lo, hi):
        m = np.zeros(T, bool)
        for o in ons:
            m[max(0, o + lo): min(T, o + hi + 1)] = True
        return m
    spont = ~(win(onOL, -pre, N + POST) | win(onCL, -pre, N + POST))
    stim = win(onOL, 0, N) | win(onCL, 0, N)

    def rows_excluding(train_trials, held):
        ok = (spont | win(onOL[train_trials], -pre, N + POST)) & ~win(onOL[held], -pre - PAD, N + POST + HMAX) & valid
        cs = np.concatenate([[0], np.cumsum(~ok)]); t = np.arange(PAD, T - HMAX - 1)
        return t[(cs[t + 72] - cs[t - PAD + 1]) == 0]

    def split(f):
        """outer test trials, inner-val trials, training rows (both test and inner-val windows excluded)."""
        te, tr = np.flatnonzero(fold == f), np.flatnonzero(fold != f)
        iv = np.random.default_rng(100 + f).choice(tr, int(round(INNER_FRAC * tr.size)), replace=False)
        tr_in = np.setdiff1d(tr, iv)
        return te, iv, rows_excluding(tr_in, np.concatenate([te, iv]))

    def score(predict, trials):
        """R^2 at 86 / 200 ms + 200 ms lag over every-frame origins of the given OL trials (raw units)."""
        FC = np.stack([predict(onOL[k] - 1 + np.arange(N)) for k in trials]) * sy        # n x N x H7
        out = {}
        for L in (3, H7):
            t0 = np.arange(N - L + 1)
            tg = np.stack([yr[onOL[k] + t0 + L - 1] for k in trials]); fc = FC[:, t0, L - 1]
            cc = [np.corrcoef(fc[:, s:].ravel(), tg[:, :tg.shape[1] - s].ravel())[0, 1] for s in range(12)]
            out[L] = (r2(tg, fc), int(np.argmax(cc)))
        return out

    def ridge(inp, cfg, rows):
        return Model(dict(BASE, **cfg), y, INPUTS[inp], u, rows).fit(rows, stim)

    def finetune(m, rows, iv, lead_w, state_w, lr, stim_rep, tag):
        """Rollout fine-tune of the ridge VARX; early stopping on inner-val R^2 at 200 ms. Returns W, curve."""
        c = m.c; L, Q = c["L"], c["Q"]
        Zt = torch.tensor(m.Z, dtype=torch.float32); ut = torch.tensor(u, dtype=torch.float32)
        W = torch.tensor(m.W, dtype=torch.float32, requires_grad=True)
        W0 = W.detach().clone()
        opt = torch.optim.Adam([W], lr=lr)
        lw = torch.tensor(lead_w, dtype=torch.float32); lw = lw / lw.sum()
        tgt_idx = torch.arange(1, H7 + 1)
        pen = c["lam"] / rows.size                                       # ridge penalty per sample (matches the ridge objective)
        def pred_np(org):
            with torch.no_grad():
                return rollout_t(W, Zt, ut, torch.as_tensor(org), L, Q, H7)[:, :, 0].numpy()
        best, bestW, bad, curve = score(pred_np, iv)[H7][0], W0.clone(), 0, []
        curve.append(best)
        rows_t = torch.as_tensor(np.concatenate([rows] + [rows[stim[rows]]] * (stim_rep - 1)))   # oversample stimulated rows
        for ep in range(MAX_EP):
            t1 = time.time()
            for b in torch.randperm(rows_t.numel()).split(BATCH):
                org = rows_t[b]
                Zh = rollout_t(W, Zt, ut, org, L, Q, H7)
                Zy = Zt[org[:, None] + tgt_idx]
                e2 = (Zh - Zy) ** 2
                loss = (e2[:, :, 0].mean(0) * lw).sum() + state_w * e2[:, :, 1:].mean() + pen * (W[:-1] ** 2).sum()
                opt.zero_grad(); loss.backward(); opt.step()
            s = score(pred_np, iv)[H7][0]; curve.append(s)
            print(f"[P200T] {tag} ep {ep+1:2d} inner-val R2 200 ms {s:.4f} ({time.time()-t1:.0f} s)", flush=True)
            if s > best + 1e-4:
                best, bestW, bad = s, W.detach().clone(), 0
            else:
                bad += 1
                if bad >= PATIENCE:
                    break
        W.data = bestW
        return pred_np, best, curve

    # ================= selection on fold 1 inner validation (stimulated OL trials) ======================
    te1, iv1, rows1 = split(1)
    print(f"[P200T] fold 1: {rows1.size} training rows, {iv1.size} inner-val OL trials, {te1.size} test trials", flush=True)
    sel = []
    for inp in INPUTS:
        for L in (5, 10, 20):
            for lam in (10.0, 100.0, 1e3, 1e4):
                if inp == "svd200" and L == 20:
                    continue
                m = ridge(inp, dict(L=L, lam=lam), rows1)
                s = score(lambda o, m=m: m.predict(o, H7), iv1)
                sel.append((inp, L, lam, s[3][0], s[H7][0]))
                print(f"[P200T] ridge {inp:9s} L={L:2d} lambda={lam:<6g} inner-val R2 86 ms {s[3][0]:.4f} | 200 ms {s[H7][0]:.4f}", flush=True)
    sel_arr = sorted(sel, key=lambda r: -r[4])
    best_per_inp = {}
    for r in sel_arr:
        best_per_inp.setdefault(r[0], r)
    for inp, r in best_per_inp.items():
        print(f"[P200T] BEST ridge {inp}: L={r[1]} lambda={r[2]:g} -> 200 ms {r[4]:.4f}", flush=True)
    top = sorted(best_per_inp.values(), key=lambda r: -r[4])[:2]
    if "spots100" not in [t[0] for t in top]:
        top.append(best_per_inp["spots100"])

    VARIANTS = {"uniform lr1e-5": ([1] * H7, 0.0, 1e-5, 1), "uniform lr3e-6": ([1] * H7, 0.0, 3e-6, 1),
                "uniform+state lr1e-5": ([1] * H7, 0.1, 1e-5, 1), "late lr1e-5": ([0, 0, 0, 0, 1, 1, 2], 0.0, 1e-5, 1),
                "uniform stimx3 lr1e-5": ([1] * H7, 0.0, 1e-5, 3)}
    ft = []
    for inp, L, lam, _, s_r in top:
        m = ridge(inp, dict(L=L, lam=lam), rows1)                      # finetune copies m.W, never mutates m
        for vn, (lw, sw, lr, sr) in VARIANTS.items():
            _, s, curve = finetune(m, rows1, iv1, lw, sw, lr, sr, f"{inp} L{L} {vn}")
            ft.append((inp, L, lam, vn, s_r, s, len(curve) - 1))
            print(f"[P200T] FT {inp} L={L} lambda={lam:g} {vn}: inner-val 200 ms ridge {s_r:.4f} -> rollout {s:.4f}", flush=True)
    bft = max(ft, key=lambda r: r[5])
    bridge = sel_arr[0]
    print(f"[P200T] SELECTED ridge: {bridge[:3]} | rollout: {bft[:4]}", flush=True)

    # ================= outer test: 5 folds, 92 OL trials ================================================
    configs = {"current VARX (spots, L10, lam100, old selection)": ("ridge", "spots100", 10, 100.0, None),
               f"ridge, stim-selected ({bridge[0]}, L{bridge[1]}, lam{bridge[2]:g})": ("ridge", *bridge[:3], None),
               f"rollout-trained ({bft[0]}, L{bft[1]}, {bft[3]})": ("ft", *bft[:3], bft[3])}
    res, FCall = {}, {}
    for nm, (kind, inp, L, lam, vn) in configs.items():
        preds = {}
        for f in range(1, 6):
            te, iv, rows = split(f)
            m = ridge(inp, dict(L=L, lam=lam), rows)
            if kind == "ft":
                lw, sw, lr, sr = VARIANTS[vn]
                p, _, _ = finetune(m, rows, iv, lw, sw, lr, sr, f"TEST fold {f} {inp}")
            else:
                p = (lambda o, m=m: m.predict(o, H7))
            for k in te:
                preds[k] = p(onOL[k] - 1 + np.arange(N))
        allp = lambda o: preds[int(np.flatnonzero(onOL - 1 == o[0])[0])]      # trial lookup by first origin
        res[nm] = score(allp, np.arange(nO))
        FCall[nm] = np.stack([preds[k] for k in range(nO)]) * sy
        print(f"[P200T-TEST] {nm:58s} " + " | ".join(f"{L*1000/Fs:.0f} ms R2 {v[0]:.3f} lag {v[1]}" for L, v in res[nm].items()), flush=True)
    t0 = np.arange(N - H7 + 1)
    per = r2(np.stack([yr[o + t0 + H7 - 1] for o in onOL]), np.stack([yr[o + t0 - 1] for o in onOL]))
    print(f"[P200T-TEST] persistence 200 ms R2 {per:.3f}", flush=True)

    # ================= figure ===========================================================================
    FIG.mkdir(parents=True, exist_ok=True)
    fig = plt.figure(figsize=(15, 9), constrained_layout=True)
    gs = fig.add_gridspec(2, 3)
    a = fig.add_subplot(gs[0, 0])
    cols = {"spots100": "#264653", "svd50": "#e9c46a", "svd100": "#f4a261", "svd200": "#e76f51"}
    for inp in INPUTS:
        for L, ls in zip((5, 10, 20), (":", "--", "-")):
            pts = [(r[2], r[4]) for r in sel if r[0] == inp and r[1] == L]
            if pts:
                a.semilogx(*zip(*pts), ls, marker="o", ms=3, color=cols[inp], label=f"{inp} L={L}")
    a.set_xlabel("ridge λ"); a.set_ylabel("inner-val R² at 200 ms (stimulated OL trials)")
    a.set_title("change 1: one-step ridge, selected on stimulated trials", fontsize=9); a.legend(fontsize=6, ncol=2, frameon=False)
    a = fig.add_subplot(gs[0, 1])
    lab = [f"{r[0]} L{r[1]}\n{r[3]}" for r in ft]
    xx = np.arange(len(ft))
    a.bar(xx - 0.2, [r[4] for r in ft], 0.4, color="#adb5bd", label="one-step ridge")
    a.bar(xx + 0.2, [r[5] for r in ft], 0.4, color="#2a9d8f", label="rollout-trained")
    a.set_xticks(xx); a.set_xticklabels(lab, fontsize=5.5, rotation=60, ha="right"); a.set_ylabel("inner-val R² at 200 ms")
    lo = min(min(r[4] for r in ft), min(r[5] for r in ft))
    a.set_ylim(lo - 0.03, max(r[5] for r in ft) + 0.02)
    a.set_title("change 2: rollout (7-step) training loss", fontsize=9); a.legend(fontsize=7, frameon=False)
    a = fig.add_subplot(gs[0, 2])
    names = list(res); v86 = [res[n].get(3, (np.nan,))[0] for n in names]; v200 = [res[n][H7][0] for n in names]
    xx = np.arange(len(names))
    a.bar(xx - 0.2, v86, 0.4, color="#8ecae6", label="86 ms"); a.bar(xx + 0.2, v200, 0.4, color="#023047", label="200 ms")
    a.axhline(per, color="r", lw=0.8, ls="--", label=f"persistence 200 ms ({per:.3f})")
    for i in range(len(names)):
        a.text(i + 0.2, v200[i] + 0.01, f"{v200[i]:.3f}\nlag {res[names[i]][H7][1]*1000/Fs:.0f} ms", ha="center", fontsize=6.5)
        a.text(i - 0.2, v86[i] + 0.01, f"{v86[i]:.3f}", ha="center", fontsize=6.5)
    a.set_xticks(xx); a.set_xticklabels([n.replace(" (", "\n(") for n in names], fontsize=6)
    a.set_ylabel("HELD-OUT OL R² (92 trials)"); a.set_ylim(0, 1); a.legend(fontsize=7, frameon=False)
    a.set_title("held-out test", fontsize=9)
    # example trials: 200 ms forecasts, current vs best
    ex = np.random.default_rng(3).choice(nO, 3, replace=False)
    tt = np.arange(N) / Fs
    for j, k in enumerate(ex):
        a = fig.add_subplot(gs[1, j])
        o = onOL[k]
        a.plot((np.arange(-pre, N)) / Fs, yr[o - pre:o + N], "k-", lw=1.2, label="recorded")
        t0 = np.arange(N - H7 + 1)
        for nm, c in zip(names, ("#adb5bd", "#457b9d", "#e63946")):
            a.plot((t0 + H7 - 1) / Fs, FCall[nm][k, t0, H7 - 1], "-", color=c, lw=1, label=nm.split(" (")[0])
        a2 = a.twinx(); a2.fill_between(np.arange(-pre, N) / Fs, ur[o - pre:o + N], step="mid", color="#ffb703", alpha=0.25)
        a2.set_yticks([])
        a.set_xlabel("time from onset (s)"); a.set_ylabel("ΔF/F (%)")
        a.set_title(f"OL trial {k}: 200 ms-ahead forecasts (plotted at target time)", fontsize=8)
        if j == 0:
            a.legend(fontsize=6, frameon=False)
    fig.savefig(FIG / f"pred200_torch_{sess}.png", dpi=170)
    savemat(DATA / f"mpc_pred200_torch_{sess}.mat", {
        "sel": np.array([list(r[1:]) for r in sel], float), "sel_inp": np.array([r[0] for r in sel], dtype=object),
        "ft": np.array([[r[1], r[2], r[4], r[5], r[6]] for r in ft], float),
        "ft_name": np.array([f"{r[0]} {r[3]}" for r in ft], dtype=object),
        "test_names": np.array(names, dtype=object), "test_r2_86": np.array(v86), "test_r2_200": np.array(v200),
        "test_lag200": np.array([res[n][H7][1] for n in names]), "persist200": per})


if __name__ == "__main__":
    main(*sys.argv[1:])
