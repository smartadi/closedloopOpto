"""Trial-level view of the 3-6 Hz amplification, and why it does not show in RMSE (Aditya, 2026-11-02).

  1. Examples, picked by rule, not by eye: in the group-median session and the strongest session,
     the trial at the 50th and 90th percentile of per-trial 3-6 Hz residual power in each condition.
     Raw dF/F, the 3-6 Hz part of the residual, and the laser command per frame.
  2. Is the effect in typical trials or in outliers? Ratio of means (what the curve uses), ratio of
     medians, and P(a random CL trial has more 3-6 Hz power than a random OL trial).
  3. Budget: residual variance by band in absolute units, and how much RMSE the amplification costs.
     RMSE^2 = (offset of the mean trace from the reference)^2 + across-trial variance.
  4. Check: the ratio of integrated residual power should reproduce the Fig 3 variance ratio.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/sens_trials.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import matplotlib  # noqa: E402

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy import signal, stats  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402
from sensitivity import FREQ, periodograms  # noqa: E402
from tests import sess_test  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2" / "corrected"
FIG = loader.ROOT / "paper" / "images" / "figure4" / "supp"
AMP = (3.0, 6.0)
BANDS = [(0.0, 1.0), (1.0, 3.0), (3.0, 6.0), (6.0, 17.5)]
COL = {"OL": "#d62728", "CL": "#1f77b4"}
FULL = M.WINDOWS["full"]
PAD = 35  # frames either side, so the band-pass filter has no edge inside the 0-3 s window
SOS = signal.butter(2, AMP, btype="bandpass", fs=M.FS, output="sos")


def bint(P, lo, hi):
    k = (FREQ >= lo) & (FREQ <= hi)
    return np.trapezoid(P[..., k], FREQ[k], axis=-1)


def per_frame_cmd(s, t0, n):
    """Laser command averaged over each frame, so a 35 Hz pulse train and a step read alike."""
    dt = s["dt_frame"]
    edges = t0 + dt * np.arange(n + 1)
    i = np.searchsorted(s["inpTime"], edges)
    return np.array([s["cmd"][a:b].mean() if b > a else np.nan for a, b in zip(i[:-1], i[1:])])


def session(sid, onsets):
    s = loader.load_session(sid, onset_frames=onsets.get(sid))
    out = {"s": s, "sid": sid, "mouse": s["mouse"]}
    a, b = FULL
    for name, code in (("OL", 0), ("CL", 1)):
        on = s["onset"][s["cond"] == code]
        X = np.array([M.segment(s["dFk"], o, FULL) for o in on])
        W = np.array([M.segment(s["dFk"], o, (a - PAD, b + PAD)) for o in on])
        keep = np.all(np.isfinite(W), axis=1)
        X, W, on = X[keep], W[keep], on[keep]
        n = len(X)
        R = X - X.mean(axis=0, keepdims=True)
        Pj = periodograms(R)  # trials x freq
        Rw = W - W.mean(axis=0, keepdims=True)
        B = signal.sosfiltfilt(SOS, Rw, axis=1)[:, PAD:-PAD]
        out[name] = {"on": on, "X": X, "R": R, "Pj": Pj, "B": B, "n": n,
                     "P": Pj.mean(axis=0) * n / (n - 1), "amp": bint(Pj, *AMP)}
    return out


def examples(ax_col, q, name, pct, ylim_raw, ylim_b, ylim_u):
    d = q[name]
    i = int(np.argsort(d["amp"])[int(round(pct / 100 * (d["n"] - 1)))])
    s = q["s"]
    t = np.arange(d["X"].shape[1]) / M.FS
    a0, a1, a2 = ax_col
    a0.plot(t, d["X"][i], color=COL[name], lw=0.9)
    a0.plot(t, d["X"].mean(axis=0), color="0.55", lw=0.8)
    a0.axhline(s["ref"], color="0.3", ls="--", lw=0.6)
    a0.set_ylim(*ylim_raw)
    a0.set_title(f"{name}, {pct}th pct of 3–6 Hz power\n"
                 f"trial RMS in band {np.sqrt(d['amp'][i]):.2f} %ΔF/F", fontsize=7)
    a1.plot(t, d["B"][i], color=COL[name], lw=0.9)
    a1.axhline(0, color="0.8", lw=0.5)
    a1.set_ylim(*ylim_b)
    u = per_frame_cmd(s, s["timeBlue"][d["on"][i]], len(t))
    a2.plot(t, u, color="k", lw=0.9)
    a2.set_ylim(*ylim_u)
    a2.set_xlabel("Time from onset (s)")
    return i


def main():
    oc = pd.read_csv(OUT.parent / "onsets_corrected.csv")
    onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
    Q = [session(sid, onsets) for sid in loader.SESSION_IDS]
    mice = np.array([q["mouse"] for q in Q])

    # ---------------------------------------------------------------- 2. typical trials or outliers
    rows = []
    for q in Q:
        ao, ac = q["OL"]["amp"], q["CL"]["amp"]
        auc = float(np.mean(ac[:, None] > ao[None, :]))
        lo = bint(q["OL"]["P"], *AMP)
        lc = bint(q["CL"]["P"], *AMP)
        rows.append({"session": q["sid"], "mouse": q["mouse"], "nOL": q["OL"]["n"], "nCL": q["CL"]["n"],
                     "ratio_means": lc / lo, "ratio_medians": np.median(ac) / np.median(ao),
                     "p_CL_gt_OL": auc, "rms_OL": np.sqrt(lo), "rms_CL": np.sqrt(lc)})
    tr = pd.DataFrame(rows)
    pd.set_option("display.width", 200)
    print("2. Per session, 3-6 Hz residual, 0-3 s")
    print(tr.to_string(index=False, float_format=lambda v: f"{v:.2f}"))
    for col, log in (("ratio_means", True), ("ratio_medians", True)):
        t = sess_test(tr[col].to_numpy(), mice, log=log)
        print(f"   {col}: {t['effect']:.2f} [{t['ci_lo']:.2f}, {t['ci_hi']:.2f}], p = {t['p']:.2g}, "
              f"{t['k']}/{t['n']}, {t['mouse_k']}/{t['mouse_n']} mice")
    t = sess_test(tr["p_CL_gt_OL"].to_numpy() - 0.5, mice)
    print(f"   P(CL trial > OL trial): {0.5 + t['effect']:.3f} [{0.5 + t['ci_lo']:.3f}, {0.5 + t['ci_hi']:.3f}], "
          f"p = {t['p']:.2g}, {t['k']}/{t['n']}")
    print(f"   band RMS: OL {tr.rms_OL.mean():.3f}, CL {tr.rms_CL.mean():.3f} %dF/F (session means)")
    tr.to_csv(OUT / "sens_trials_sessions.csv", index=False)

    # ---------------------------------------------------------------- 3. budget
    print("\n3. Residual variance by band, (%dF/F)^2, mean over sessions, 0-3 s")
    bud = []
    for q in Q:
        for lo, hi in BANDS:
            bud.append({"session": q["sid"], "band": f"{lo:g}-{hi:g}", "OL": bint(q["OL"]["P"], lo, hi),
                        "CL": bint(q["CL"]["P"], lo, hi)})
    bud = pd.DataFrame(bud)
    b = bud.groupby("band", sort=False)[["OL", "CL"]].mean()
    b["CL-OL"] = b["CL"] - b["OL"]
    b["share_OL"] = b["OL"] / b["OL"].sum()
    b["share_CL"] = b["CL"] / b["CL"].sum()
    print(b.round(3).to_string())
    print(f"   total: OL {b.OL.sum():.3f}, CL {b.CL.sum():.3f}")
    bud.to_csv(OUT / "sens_trials_budget.csv", index=False)

    print("\n3b. RMSE^2 = offset^2 + variance, per window, mean over sessions; cost of the 3-6 Hz excess")
    dec = []
    for q in Q:
        s = q["s"]
        for wname, (a, b_) in (("0-3 s", (0, 105)), ("1-3 s", (35, 105))):
            r = {"session": q["sid"], "window": wname}
            for c in ("OL", "CL"):
                seg = q[c]["X"][:, a:b_ + 1]
                r[f"rmse_{c}"] = float(np.mean(np.sqrt(np.mean((seg - s["ref"]) ** 2, axis=1))))
                r[f"mse_{c}"] = float(np.mean((seg - s["ref"]) ** 2))
                r[f"off2_{c}"] = float(np.mean((seg.mean(axis=0) - s["ref"]) ** 2))
                r[f"var_{c}"] = float(np.mean(seg.var(axis=0)))
            excess = max(bint(q["CL"]["P"], *AMP) - bint(q["OL"]["P"], *AMP), 0.0)
            r["excess36"] = excess
            r["rmse_CL_no_excess"] = np.sqrt(max(r["mse_CL"] - excess, 0.0))
            r["cost_pct"] = 100 * (np.sqrt(r["mse_CL"]) / r["rmse_CL_no_excess"] - 1)
            dec.append(r)
    dec = pd.DataFrame(dec)
    print(dec.drop(columns="session").groupby("window").mean().round(3).T.to_string())
    dec.to_csv(OUT / "sens_trials_rmse.csv", index=False)
    for w, g in dec.groupby("window"):
        print(f"   {w}: CL RMSE lower in {(g.rmse_CL < g.rmse_OL).sum()}/{len(g)} sessions; "
              f"3-6 Hz excess costs {g.cost_pct.median():.1f}% of CL RMSE (median; range {g.cost_pct.min():.1f}-{g.cost_pct.max():.1f})")

    # ---------------------------------------------------------------- 4. check against Fig 3
    ratio_int = np.array([bint(q["CL"]["P"], 0, 17.5) / bint(q["OL"]["P"], 0, 17.5) for q in Q])
    ratio_var = np.array([np.mean(q["CL"]["X"].var(axis=0, ddof=1)) / np.mean(q["OL"]["X"].var(axis=0, ddof=1)) for q in Q])
    gm = lambda v: float(np.exp(np.mean(np.log(v))))  # noqa: E731
    print(f"\n4. Integrated power ratio {gm(ratio_int):.3f}; across-trial variance ratio {gm(ratio_var):.3f} "
          f"(Fig 3 full-window variance ratio 0.585); r across sessions {np.corrcoef(np.log(ratio_int), np.log(ratio_var))[0, 1]:.2f}")

    # ---------------------------------------------------------------- 5. does it track the loop?
    # Effective gain at 3-6 Hz, measured: RMS of the CL command over RMS of the CL readout, both as
    # residuals about their trial means. Laser effect: OL dip from the 1 s before onset to 1-3 s, per volt.
    print("\n5. Across sessions: does the 3-6 Hz excess track the loop?")
    gain = []
    for q in Q:
        s = q["s"]
        U = np.array([per_frame_cmd(s, s["timeBlue"][o], 106) for o in q["CL"]["on"]])
        ok = np.all(np.isfinite(U), axis=1)
        U = U[ok]
        Ru = U - U.mean(axis=0, keepdims=True)
        Pu = periodograms(Ru).mean(axis=0) * len(U) / (len(U) - 1)
        Kc = np.sqrt(bint(Pu, *AMP) / bint(q["CL"]["P"], *AMP))
        on = q["OL"]["on"]
        pre = np.array([M.segment(s["dFk"], o, (-35, -1)) for o in on])
        late = q["OL"]["X"][:, 35:106]
        uo = np.nanmean([per_frame_cmd(s, s["timeBlue"][o], 106)[35:] for o in on])
        dip = np.nanmean(pre) - np.nanmean(late)
        gain.append({"session": q["sid"], "mouse": q["mouse"], "Kc_V_per_pct": Kc, "laser_pct_per_V": dip / uo,
                     "loop": Kc * dip / uo, "cmd_rms_36": np.sqrt(bint(Pu, *AMP)),
                     "S36": bint(q["CL"]["P"], *AMP) / bint(q["OL"]["P"], *AMP),
                     "S01": bint(q["CL"]["P"], 0, 1) / bint(q["OL"]["P"], 0, 1),
                     "S13": bint(q["CL"]["P"], 1, 3) / bint(q["OL"]["P"], 1, 3)})
    gain = pd.DataFrame(gain)
    gain.to_csv(OUT / "sens_trials_gain.csv", index=False)
    print(gain.drop(columns="mouse").to_string(index=False, float_format=lambda v: f"{v:.2f}"))
    pairs = [("Kc_V_per_pct", "S36"), ("loop", "S36"), ("laser_pct_per_V", "S36"), ("S01", "S36"),
             ("loop", "S01"), ("Kc_V_per_pct", "S01")]
    rng = np.random.default_rng(20261102)
    for a_, b_ in pairs:
        r, p = stats.spearmanr(gain[a_], gain[b_])
        # within mouse: remove each mouse's mean of the log values, permute within mouse
        la, lb = np.log(gain[a_].to_numpy()), np.log(gain[b_].to_numpy())
        ma = gain["mouse"].to_numpy()
        for mo in np.unique(ma):
            la[ma == mo] -= la[ma == mo].mean()
            lb[ma == mo] -= lb[ma == mo].mean()
        rw = np.corrcoef(la, lb)[0, 1]
        null = []
        for _ in range(20000):
            pm = lb.copy()
            for mo in np.unique(ma):
                i_ = np.where(ma == mo)[0]
                pm[i_] = lb[rng.permutation(i_)]
            null.append(np.corrcoef(la, pm)[0, 1])
        pw = float(np.mean(np.abs(null) >= abs(rw)))
        print(f"   {a_:16s} vs {b_:4s}: Spearman {r:+.2f} (p = {p:.3g}, n = 15); within mouse r {rw:+.2f} (perm p = {pw:.3g})")

    # ---------------------------------------------------------------- 1. examples
    order = tr.sort_values("ratio_means").reset_index(drop=True)
    med_sid = order.loc[len(order) // 2, "session"]
    top_sid = order.loc[len(order) - 1, "session"]
    print(f"\n1. Example sessions: median {med_sid}, strongest {top_sid}")
    for label, sid in (("median", med_sid), ("strongest", top_sid)):
        q = next(x for x in Q if x["sid"] == sid)
        r = tr[tr.session == sid].iloc[0]
        rawmin = min(q["OL"]["X"].min(), q["CL"]["X"].min())
        allraw = np.concatenate([q[c]["X"].ravel() for c in ("OL", "CL")])
        ylim_raw = np.percentile(allraw, [0.2, 99.8])
        allb = np.concatenate([q[c]["B"].ravel() for c in ("OL", "CL")])
        bm = np.percentile(np.abs(allb), 99.8)
        ucl = per_frame_cmd(q["s"], q["s"]["timeBlue"][q["CL"]["on"][0]], 106)
        fig = plt.figure(figsize=(14, 6.6), constrained_layout=True)
        gs = fig.add_gridspec(3, 5, height_ratios=[1.3, 1, 0.7], width_ratios=[1, 1, 1, 1, 0.9])
        umax = 0.0
        cols = []
        for j, (name, pct) in enumerate((("OL", 50), ("CL", 50), ("OL", 90), ("CL", 90))):
            ax = [fig.add_subplot(gs[i, j]) for i in range(3)]
            d = q[name]
            i = int(np.argsort(d["amp"])[int(round(pct / 100 * (d["n"] - 1)))])
            u = per_frame_cmd(q["s"], q["s"]["timeBlue"][d["on"][i]], 106)
            umax = max(umax, np.nanmax(u))
            cols.append((ax, name, pct))
        for ax, name, pct in cols:
            i = examples(ax, q, name, pct, ylim_raw, (-bm, bm), (-0.05 * umax, 1.1 * umax))
            print(f"   {sid} {name} {pct}th pct: val trial position {i}")
        cols[0][0][0].set_ylabel("ΔF/F (%)\nblack dash = target, gray = mean")
        cols[0][0][1].set_ylabel("3–6 Hz part of\nresidual (%ΔF/F)")
        cols[0][0][2].set_ylabel("Laser command (V)")
        a = fig.add_subplot(gs[0, 4])
        for x0, c in ((0, "OL"), (1, "CL")):
            v = q[c]["amp"]
            a.scatter(x0 + np.random.default_rng(1).uniform(-0.12, 0.12, len(v)), v, s=7, color=COL[c], alpha=0.6, lw=0)
            a.plot([x0 - 0.25, x0 + 0.25], [np.median(v)] * 2, color="k", lw=1.2)
        a.set(yscale="log", xticks=[0, 1], xticklabels=["OL", "CL"], ylabel="Trial 3–6 Hz power (%ΔF/F)²")
        a.set_title(f"Each dot a trial; bar = median\nP(CL > OL) = {r.p_CL_gt_OL:.2f}", fontsize=7)
        a = fig.add_subplot(gs[1:, 4])
        kp = (FREQ >= 0.5) & (FREQ <= 17.5)
        for c in ("OL", "CL"):
            a.plot(FREQ[kp], q[c]["P"][kp], color=COL[c], lw=1.2, label=c)
        a.axvspan(*AMP, color="0.9", zorder=0)
        a.set(xscale="log", yscale="log", xlabel="Frequency (Hz)", ylabel="Residual power ((%ΔF/F)² Hz⁻¹)")
        a.legend(frameon=False, fontsize=7)
        fig.suptitle(f"{label.capitalize()} session by 3–6 Hz ratio: {sid} {q['mouse']} {q['s']['td']}, "
                     f"{q['OL']['n']} OL / {q['CL']['n']} CL trials, CL/OL 3–6 Hz power {r.ratio_means:.2f}", fontsize=9)
        out = FIG / f"sens_trials_{label}.png"
        fig.savefig(out, dpi=200)
        print(f"   wrote {out}")

    # ---------------------------------------------------------------- budget figure
    fig, ax = plt.subplots(1, 3, figsize=(11.5, 3.6), constrained_layout=True)
    a = ax[0]
    shades = ["0.25", "0.5", "#e6a23c", "0.85"]
    for x0, c in ((0, "OL"), (1, "CL")):
        bot = 0.0
        for (bn, row), col in zip(b.iterrows(), shades):
            a.bar(x0, row[c], bottom=bot, color=col, width=0.6, label=f"{bn} Hz" if x0 == 0 else None)
            bot += row[c]
    a.set(xticks=[0, 1], xticklabels=["OL", "CL"], ylabel="Residual variance (%ΔF/F)²",
          title="Where the fluctuation power is")
    a.legend(frameon=False, fontsize=7)
    a = ax[1]
    for _, r in tr.iterrows():
        a.plot([0, 1], [r.rms_OL, r.rms_CL], color="0.6", lw=0.7, marker="o", ms=2.5)
    a.set(xticks=[0, 1], xticklabels=["OL", "CL"], xlim=(-0.3, 1.3), ylim=(0, None),
          ylabel="3–6 Hz residual RMS (%ΔF/F)", title="3–6 Hz alone: CL larger")
    a = ax[2]
    g = dec[dec.window == "0-3 s"]
    for _, r in g.iterrows():
        a.plot([0, 1], [r.rmse_OL, r.rmse_CL], color="0.6", lw=0.7, marker="o", ms=2.5)
    a.set(xticks=[0, 1], xticklabels=["OL", "CL"], xlim=(-0.3, 1.3), ylim=(0, None),
          ylabel="Trial RMSE 0–3 s (%ΔF/F)", title="All frequencies: CL smaller")
    out = FIG / "sens_trials_budget.png"
    fig.savefig(out, dpi=200)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
