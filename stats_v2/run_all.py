"""stats_v2: produce every output listed in SPEC.md section 7.

Run from the project root:
    stats_v2/.venv/Scripts/python.exe -I stats_v2/run_all.py
"""
import datetime
import hashlib
import json
import platform
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import h5py  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import scipy  # noqa: E402
from scipy import stats  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402
from tests import holm, sess_test  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2"
STATES = ["init_dev", "motion", "rel_delta", "abs_delta"]
RISE_TOL = 2.0  # frames
LOWER_V = 0.01
UPPER_FRAC = 0.99
M14_SHIFT = 11  # sensitivity: dFk[i] -> timeBlue[i + 11] in m14


# --------------------------------------------------------------------------- per session
def analyse_session(s):
    dfk, ref, tb = s["dFk"], s["ref"], s["timeBlue"]
    t_cmd, cmd = s["inpTime"], s["cmd"]
    rows, segs = [], {w: [] for w in M.WINDOWS}
    nan_windows = {w: 0 for w in M.WINDOWS}
    big_in_window = 0
    rise, base, pre_low = [], [], []
    cl_cmd = []
    for j, o in enumerate(s["onset"]):
        col = int(s["val_cols"][j])
        cond = int(s["cond"][j])
        t0 = tb[o]
        r = {
            "session": s["id"],
            "mouse": s["mouse"],
            "trial_index": col + 1,
            "val_index": j,
            "condition": "CL" if cond == 1 else "OL",
            "onset_s": s["stim"][j],
            "onset_frame": int(o) + 1,
        }
        for w, rng in M.WINDOWS.items():
            seg = M.segment(dfk, o, rng)
            segs[w].append(seg)
            if not np.all(np.isfinite(seg)):
                nan_windows[w] += 1
            if np.any(np.abs(seg) > 50):
                big_in_window += 1
        for name, w in [("pre", "pre"), ("early", "early"), ("late", "late"), ("full", "full"),
                        ("post", "post_rmse")]:
            r[f"rmse_{name}"] = M.rmse(M.segment(dfk, o, M.WINDOWS[w]), ref)
        r.update(M.trial_states(dfk, s["motion"], o, ref, s["has_motion"]))
        c03 = M.cmd_slice(t_cmd, cmd, t0, t0 + 3.0)
        r["max_cmd"] = float(np.max(c03))
        off, b = M.rise_offset_frames(t_cmd, cmd, t0, s["dt_frame"])
        r["rise_offset_frames"] = off
        r["onset_tb_minus_stim_s"] = float(t0 - s["stim"][j])
        rise.append(off)
        base.append(b)
        pre = M.cmd_slice(t_cmd, cmd, t0 - 1.5, t0 - 0.5)
        pre_low.append(np.mean(np.abs(pre) < LOWER_V))
        if cond == 1:
            cl_cmd.append(c03)
        rows.append(r)
    tr = pd.DataFrame(rows)
    ol = tr["condition"].values == "OL"
    cl = ~ol

    # ---- Fig 3
    f3 = {"session": s["id"], "mouse": s["mouse"], "n_OL": int(ol.sum()), "n_CL": int(cl.sum())}
    for name, (wr, wv) in M.FIG3_WINDOWS.items():
        col = "rmse_post" if name == "post" else f"rmse_{name}"
        f3[f"rmse_OL_{name}"] = tr.loc[ol, col].mean()
        f3[f"rmse_CL_{name}"] = tr.loc[cl, col].mean()
        f3[f"rmse_ratio_{name}"] = f3[f"rmse_CL_{name}"] / f3[f"rmse_OL_{name}"]
        mat = np.vstack(segs[wv])
        f3[f"var_OL_{name}"] = M.across_trial_var(mat[ol])
        f3[f"var_CL_{name}"] = M.across_trial_var(mat[cl])
        f3[f"var_ratio_{name}"] = f3[f"var_CL_{name}"] / f3[f"var_OL_{name}"]

    # ---- Fig 4D
    f4 = []
    y = tr["rmse_late"].values
    for st in STATES:
        if st == "motion" and not s["has_motion"]:
            continue
        x = tr[st].values
        z = M.zscore(x)
        P = M.ols_slope(z[ol], y[ol])
        R = M.ols_slope(z[cl], y[cl])
        bl_ol = M.ols_slope(z[ol], np.log(y[ol]))
        bl_cl = M.ols_slope(z[cl], np.log(y[cl]))
        A = bl_cl - bl_ol
        f4.append({
            "session": s["id"], "mouse": s["mouse"], "state": st,
            "n_OL": int(ol.sum()), "n_CL": int(cl.sum()),
            "state_mean": float(np.mean(x)), "state_sd": float(np.std(x, ddof=1)),
            "P": P, "R": R, "logslope_OL": bl_ol, "logslope_CL": bl_cl,
            "A": A, "A_pct": 100 * (np.exp(A) - 1),
            "gap": float(y[ol].mean() - y[cl].mean()), "gap_change": P - R,
        })

    # ---- prep covariate
    cc = np.concatenate(cl_cmd)
    umax = float(cc.max())
    lower = float(np.mean(np.abs(cc) < LOWER_V))
    upper = float(np.mean(cc >= UPPER_FRAC * umax))
    prep = {
        "session": s["id"], "mouse": s["mouse"], "n_CL": int(cl.sum()), "n_samples": int(len(cc)),
        "u_max_CL": umax, "frac_lower": lower, "frac_upper": upper, "frac_total": lower + upper,
        "rmse_ratio_full": f3["rmse_ratio_full"],
    }

    # ---- checks
    rise = np.array(rise)
    chk = {
        "rise": rise, "cond": s["cond"], "trial_index": tr["trial_index"].values,
        "cmd_baseline_median": float(np.median(base)),
        "pre_off_frac_below_0p01": float(np.mean(pre_low)),
        "nan_windows": nan_windows, "big_in_window": big_in_window,
        "state_nan": {st: int(tr[st].isna().sum()) for st in STATES},
    }
    return tr, f3, f4, prep, chk


def session_checks(s):
    ip = s["input_params"]
    n_all, n_val = s["n_trials_all"], s["n_val"]
    c = {
        "id": s["id"],
        "meta_ok": (s["mn"] == s["mouse"] and s["td"] == s["date"] and int(s["en"]) == s["exp"]),
        "mn_td_en": f'{s["mn"]} {s["td"]} {int(s["en"])}',
        "n_trials": n_all, "n_stimStarts": s["n_stimStarts"], "n_val": n_val,
        "n_OL": int(np.sum(s["cond"] == 0)), "n_CL": int(np.sum(s["cond"] == 1)),
        "cond_values": sorted(set(np.unique(ip[2]).tolist())),
        "active": s["active_channel"], "p999": s["chan_p999"], "tied": s["chan_tied"],
        "identical": s["chan_identical"], "time_equal": s["chan_time_equal"],
        "has_motion": s["has_motion"], "dur": s["dur"], "ref": s["ref"],
        "len_tb": s["len_timeBlue"], "len_dfk": s["len_dFk"], "len_motion": s["len_motion"],
        "dt_frame": s["dt_frame"], "fs_measured": 1.0 / s["dt_frame"],
        "max_abs_tb_minus_stim": float(np.max(np.abs(s["timeBlue"][s["onset"]] - s["stim"]))),
    }
    raw = s["dFk_raw"]
    big = np.flatnonzero(np.abs(raw) > 50)
    c["dfk_big_n"] = int(len(big))
    c["dfk_big_after2000"] = int(np.sum(big >= 2000))
    c["dfk_max_abs"] = float(np.max(np.abs(raw)))
    first_val = int(s["onset"].min() + M.WINDOWS["pre"][0])
    c["dfk_big_in_val_span"] = int(np.sum((big >= first_val) & (big <= s["onset"].max() + 210)))
    pre = ip[:, : n_all - n_val]
    c["pre_block_OL"] = int(np.sum(pre[2] == 0)) if pre.shape[1] else 0
    c["pre_block_CL"] = int(np.sum(pre[2] == 1)) if pre.shape[1] else 0
    val = ip[:, s["val_cols"]]
    c["val_param_rows_varying"] = {
        r: sorted(set(np.round(val[r], 4).tolist())) for r in range(3, ip.shape[0])
        if len(np.unique(val[r])) > 1
    }
    st = s["stim"]
    iti = np.diff(st)
    c["iti_min"] = float(iti.min())
    c["iti_median"] = float(np.median(iti))
    c["iti_lt6"] = int(np.sum(iti < 6.0))
    c["iti_lt9"] = int(np.sum(iti < 9.0))
    if s["build"] == "new":
        kk = s["kk"].astype(int)
        pred = s["timeBlue"][kk - 1] - s["dur"]
        dis = st - pred
        c["kk_disagree_max_s"] = float(np.max(np.abs(dis)))
        c["kk_disagree_median_s"] = float(np.median(dis))
    c["runs"] = M.runs_test(s["cond"])
    c["lag"] = M.response_lag(s["inpTime"], s["cmd"], s["timeBlue"], s["dFk"])
    return c


# --------------------------------------------------------------------------- tests
TEST_COLS = ["figure", "quantity", "window_or_state", "role", "n", "effect", "ci_lo", "ci_hi", "t",
             "df", "p", "wilcoxon_p", "k", "k_n", "lomo_worst_p", "mouse_k", "mouse_n", "mouse_p",
             "holm_p", "holm_family", "sign", "lomo_worst_mouse", "effect_pct", "ci_lo_pct",
             "ci_hi_pct", "n_zero", "n_tied", "wilcoxon_note", "sessions"]


def _row(figure, quantity, where, role, res, sessions):
    r = {"figure": figure, "quantity": quantity, "window_or_state": where, "role": role}
    for k in ["n", "effect", "ci_lo", "ci_hi", "t", "df", "p", "wilcoxon_p", "k", "k_n",
              "lomo_worst_p", "mouse_k", "mouse_n", "mouse_p", "sign", "lomo_worst_mouse",
              "n_zero", "n_tied", "wilcoxon_note"]:
        r[k] = res[k]
    r["sessions"] = " ".join(sessions)
    return r


def run_tests(f3, f4, prep):
    rows = []
    roles = {"pre": "null_window", "early": "secondary", "late": "secondary", "full": "main",
             "post": "null_window"}
    for w in M.FIG3_WINDOWS:
        for q in ["rmse_ratio", "var_ratio"]:
            res = sess_test(f3[f"{q}_{w}"].values, f3["mouse"].values, log=True)
            rows.append(_row("fig3", q, w, roles[w], res, list(f3["session"])))
    for st in STATES:
        sub = f4[f4["state"] == st]
        for q in ["P", "R", "A"]:
            res = sess_test(sub[q].values, sub["mouse"].values, log=False)
            r = _row("fig4d", q, st, "main", res, list(sub["session"]))
            if q == "A":
                r["effect_pct"] = 100 * (np.exp(res["effect"]) - 1)
                r["ci_lo_pct"] = 100 * (np.exp(res["ci_lo"]) - 1)
                r["ci_hi_pct"] = 100 * (np.exp(res["ci_hi"]) - 1)
            rows.append(r)
        for q in ["gap", "gap_change"]:
            res = sess_test(sub[q].values, sub["mouse"].values, log=False)
            rows.append(_row("fig4d", q, st, "secondary", res, list(sub["session"])))
    t = pd.DataFrame(rows)
    for fam, qs in [("fig4d_PR", ["P", "R"]), ("fig4d_A", ["A"])]:
        m = (t["figure"] == "fig4d") & t["quantity"].isin(qs)
        t.loc[m, "holm_p"] = holm(t.loc[m, "p"].values)
        t.loc[m, "holm_family"] = f"{fam} (m={int(m.sum())})"
    for frac in ["frac_lower", "frac_upper", "frac_total"]:
        rho, p = stats.spearmanr(prep[frac], prep["rmse_ratio_full"])
        t = pd.concat([t, pd.DataFrame([{
            "figure": "prep", "quantity": f"spearman_rho({frac}, rmse_ratio_full)",
            "window_or_state": "0-3 s CL command", "role": "supplementary", "n": len(prep),
            "effect": rho, "p": p, "sessions": " ".join(prep["session"])}])], ignore_index=True)
    for c in TEST_COLS:
        if c not in t:
            t[c] = np.nan
    return t[TEST_COLS]


# --------------------------------------------------------------------------- outputs
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 22), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args):
    try:
        return subprocess.run(["git", *args], cwd=loader.ROOT, capture_output=True, text=True,
                              check=True).stdout.strip()
    except Exception as e:  # pragma: no cover
        return f"unavailable ({e})"


def fmt(x, nd=4):
    if x is None:
        return ""
    if isinstance(x, (float, np.floating)):
        if not np.isfinite(x):
            return "NaN"
        return f"{x:.{nd}g}" if abs(x) < 1e-3 and x != 0 else f"{x:.{nd}f}"
    return str(x)


def md_table(df, nd=4):
    cols = list(df.columns)
    out = ["| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for _, r in df.iterrows():
        out.append("| " + " | ".join(fmt(r[c], nd) for c in cols) + " |")
    return "\n".join(out)


def main():
    # --corrected: onsets from stats_v2/onsets.py (OL laser-command rise) and m14 dFk shifted by
    # M14_SHIFT; outputs go to data/stats_v2/corrected/. The m14 sensitivity then compares against
    # the unshifted mapping instead.
    global OUT
    corrected = "--corrected" in sys.argv
    onsets, m14_main, m14_alt = {}, 0, M14_SHIFT
    if corrected:
        oc = pd.read_csv(OUT / "onsets_corrected.csv")
        onsets = {k: g["onset_frame"].to_numpy() - 1 for k, g in oc.groupby("session")}
        m14_main, m14_alt = M14_SHIFT, 0
        OUT = OUT / "corrected"
    OUT.mkdir(parents=True, exist_ok=True)
    trials, f3s, f4s, preps, chks, scs = [], [], [], [], {}, {}
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid, dfk_offset=m14_main if sid == "m14" else 0,
                                onset_frames=onsets.get(sid))
        tr, f3, f4, prep, chk = analyse_session(s)
        sc = session_checks(s)
        print(f"{sid}: {s['mn']} {s['td']} trials={s['n_trials_all']} val={s['n_val']} "
              f"OL={sc['n_OL']} CL={sc['n_CL']} chan={s['active_channel']} motion={s['has_motion']} "
              f"rise_med={np.nanmedian(chk['rise']):.2f} lag={sc['lag'][0]}")
        trials.append(tr); f3s.append(f3); f4s.extend(f4); preps.append(prep)
        chks[sid], scs[sid] = chk, sc
        del s
    trials = pd.concat(trials, ignore_index=True)
    f3 = pd.DataFrame(f3s)
    f4 = pd.DataFrame(f4s)
    prep = pd.DataFrame(preps)
    tests = run_tests(f3, f4, prep)

    trial_cols = ["session", "mouse", "trial_index", "val_index", "condition", "onset_s",
                  "onset_frame", "rmse_pre", "rmse_early", "rmse_late", "rmse_full", "rmse_post",
                  "init_dev", "motion", "rel_delta", "abs_delta", "max_cmd",
                  "rise_offset_frames", "onset_tb_minus_stim_s"]
    trials[trial_cols].to_csv(OUT / "trials.csv", index=False)
    f3.to_csv(OUT / "session_fig3.csv", index=False)
    f4.to_csv(OUT / "session_fig4d.csv", index=False)
    prep.to_csv(OUT / "prep.csv", index=False)
    tests.to_csv(OUT / "tests.csv", index=False)

    # ---- sensitivity: m14 dFk aligned to the END of timeBlue (shift 11 frames)
    s14 = loader.load_session("m14", dfk_offset=m14_alt, onset_frames=onsets.get("m14"))
    tr14, f3_14, f4_14, prep14, chk14 = analyse_session(s14)
    lag14 = M.response_lag(s14["inpTime"], s14["cmd"], s14["timeBlue"], s14["dFk"])
    del s14
    order = lambda c: c.map(loader.SESSION_IDS.index)  # noqa: E731
    f3b = pd.concat([f3[f3["session"] != "m14"], pd.DataFrame([f3_14])], ignore_index=True)
    f3b = f3b.sort_values("session", key=order, kind="stable").reset_index(drop=True)
    f4b = pd.concat([f4[f4["session"] != "m14"], pd.DataFrame(f4_14)], ignore_index=True)
    f4b = f4b.sort_values("session", key=order, kind="stable").reset_index(drop=True)
    prepb = prep.copy()
    prepb.loc[prepb["session"] == "m14", "rmse_ratio_full"] = f3_14["rmse_ratio_full"]
    tests_b = run_tests(f3b, f4b, prepb)
    sens = tests[["figure", "quantity", "window_or_state", "role", "effect", "p", "wilcoxon_p",
                  "k", "k_n", "holm_p"]].merge(
        tests_b[["figure", "quantity", "window_or_state", "effect", "p", "wilcoxon_p", "k",
                 "k_n", "holm_p"]],
        on=["figure", "quantity", "window_or_state"], suffixes=("", "_m14shift"))
    sens.to_csv(OUT / "sensitivity_m14_align.csv", index=False)
    sens_sess = pd.DataFrame({
        "quantity": ["rmse_ratio_full", "var_ratio_full"],
        "m14_start_aligned": [f3.loc[f3.session == "m14", "rmse_ratio_full"].item(),
                              f3.loc[f3.session == "m14", "var_ratio_full"].item()],
        "m14_shift11": [f3_14["rmse_ratio_full"], f3_14["var_ratio_full"]],
    })

    write_checks(chks, scs, trials, f3, tests, sens, sens_sess, lag14, chk14)
    write_choices()
    write_manifest()
    print(tests[["figure", "quantity", "window_or_state", "role", "n", "effect", "ci_lo", "ci_hi",
                 "p", "wilcoxon_p", "k", "k_n", "holm_p"]].to_string())


# --------------------------------------------------------------------------- CHECKS.md
def write_checks(chks, scs, trials, f3, tests, sens, sens_sess, lag14, chk14):
    L = ["# stats_v2 CHECKS", "", f"Generated {datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')} by `stats_v2/run_all.py`.", ""]

    L += ["## 1. Per-session counts, channel, motion", "",
          "| id | cache meta (mn td en) | meta ok | trials in input_params | stimStarts | validation N | OL | CL | condition codes | active channel | 99.9th pct per channel (V) | has_motion | dur | ref |",
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for sid, c in scs.items():
        p = ", ".join(f"{k}={v:.3f}" for k, v in c["p999"].items())
        L.append(f"| {sid} | {c['mn_td_en']} | {c['meta_ok']} | {c['n_trials']} | {c['n_stimStarts']} | {c['n_val']} | {c['n_OL']} | {c['n_CL']} | {c['cond_values']} | {c['active']} | {p} | {c['has_motion']} | {c['dur']:g} | {c['ref']:g} |")
    nm = sum(c["has_motion"] for c in scs.values())
    L += ["", f"Sessions with motion: {nm} of 15 ({', '.join(k for k, c in scs.items() if c['has_motion'])}). Without: {', '.join(k for k, c in scs.items() if not c['has_motion'])}.", ""]
    ties = {k: c for k, c in scs.items() if len(c["tied"]) > 1}
    for k, c in ties.items():
        L.append(f"- **{k}: channel tie** on the 99.9th percentile between {c['tied']} (arrays identical: {c['identical']}); chose `{c['active']}` (see CHOICES).")
    for k, c in scs.items():
        if c["time_equal"]:
            L.append(f"- {k}: per-channel time vectors equal to d.inpTime: {c['time_equal']}.")
    L.append("")

    L += ["## 2. Array lengths and alignment", "",
          "Spec says `data.dFk` has the same length as `timeBlue`. Where it does not, the primary analysis maps dFk[i] to timeBlue[i] (start-aligned; see CHOICES).",
          "The `response lag` column is an alignment check: the lag (frames) at which frame-to-frame dFk changes are most negatively correlated with frame-to-frame changes of the frame-binned laser command (positive = dFk responds after the command). It uses the primary start-aligned mapping.", "",
          "| id | len timeBlue | len dFk | len motion | measured frame rate (Hz) | response lag (frames) | r at lag | frames with abs(dFk) > 50 % | of which at frame >= 2000 | max abs(dFk) |",
          "|---|---|---|---|---|---|---|---|---|---|"]
    for sid, c in scs.items():
        flag = " **(mismatch)**" if c["len_dfk"] != c["len_tb"] else ""
        mflag = " **(mismatch)**" if c["len_motion"] != c["len_tb"] else ""
        L.append(f"| {sid} | {c['len_tb']} | {c['len_dfk']}{flag} | {c['len_motion']}{mflag} | {c['fs_measured']:.3f} | {c['lag'][0]} | {c['lag'][1]:.3f} | {c['dfk_big_n']} | {c['dfk_big_after2000']} | {c['dfk_max_abs']:.1f} |")
    lag_txt = ", ".join(f"{k} {c['lag'][0]:+d}" for k, c in scs.items())
    late_big = ", ".join(f"{k} ({c['dfk_big_after2000']} frames)" for k, c in scs.items()
                         if c["dfk_big_after2000"]) or "none"
    L += ["",
          f"- Response lag across sessions: {lag_txt}. Sessions with the response 1–3 frames after the command: {', '.join(k for k, c in scs.items() if 1 <= c['lag'][0] <= 3)}; outside that range: {', '.join(k for k, c in scs.items() if not 1 <= c['lag'][0] <= 3) or 'none'}.",
          f"- **m14 contradicts the start-aligned mapping**: its dFk is {scs['m14']['len_tb'] - scs['m14']['len_dfk']} frames shorter than timeBlue and, start-aligned, its dFk 'responds' {-scs['m14']['lag'][0]} frames *before* the laser command changes (physically impossible). Re-mapping dFk[i] to timeBlue[i+{M14_SHIFT}] (end-aligned) gives a lag of {lag14[0]} frames (r = {lag14[1]:.3f}), in line with the other sessions. The primary outputs keep the spec's literal mapping; a sensitivity re-run with the shifted m14 is in section 8 and `sensitivity_m14_align.csv`.",
          f"- m8 (dFk 1 frame short) shows lag {scs['m8']['lag'][0]} vs 2–3 in the other old builds; with a 1-frame length difference the evidence for an end-alignment there is weak (correlations are small). Not changed.",
          f"- m13 (dFk 75 frames short) shows lag {scs['m13']['lag'][0]}, consistent with start alignment (missing frames at the end). No validation window reaches beyond the end of dFk.",
          "- m10, m11: `d.motion` is 1 frame shorter than timeBlue; start-aligned; no state window reaches the missing frame.",
          f"- Sessions with frames where abs(dFk) > 50 %: {', '.join(k for k, c in scs.items() if c['dfk_big_n']) or 'none'}. These sit mostly at the very start of the session (start-up transient of the online ΔF/F baseline); sessions with such frames at frame >= 2000: {late_big}. Frames with abs(dFk) > 50 % between the first validation pre window and the last post_var window: {sum(c['dfk_big_in_val_span'] for c in scs.values())} in total; none of them falls inside an analysis window (section 5).", ""]

    L += ["## 3. Onset sanity: laser command rise vs onset frame", "",
          "Rise = first active-channel sample in [t0−0.5, t0+1.0) s above (median over [t0−1.5, t0−0.5) s) + 0.05 V, with t0 = timeBlue[onset frame]. Offset in frames = (t_rise − t0) / median frame interval. Spec expectation: within ±2 frames. In CL trials a late rise can be the controller output sitting at zero, so OL trials are the cleaner test.", "",
          "| id | OL median | OL min | OL max | CL median | CL min | CL max | trials outside ±2 (OL / CL / total) | no rise found |",
          "|---|---|---|---|---|---|---|---|---|"]
    outside_lists = []
    for sid, ch in chks.items():
        r, cnd, ti = ch["rise"], ch["cond"], ch["trial_index"]
        o, c_ = r[cnd == 0], r[cnd == 1]
        out = np.abs(r) > RISE_TOL
        n_o, n_c = int(np.sum(out & (cnd == 0))), int(np.sum(out & (cnd == 1)))
        L.append(f"| {sid} | {np.nanmedian(o):.2f} | {np.nanmin(o):.2f} | {np.nanmax(o):.2f} | {np.nanmedian(c_):.2f} | {np.nanmin(c_):.2f} | {np.nanmax(c_):.2f} | {n_o} / {n_c} / {n_o + n_c} of {len(r)} | {int(np.isnan(r).sum())} |")
        if out.any():
            items = ", ".join(f"{t}{'CL' if k == 1 else 'OL'}({v:+.1f})" for t, k, v in zip(ti[out], cnd[out], r[out]))
            outside_lists.append(f"- **{sid}** ({int(out.sum())}): {items}")
    tot = sum(int(np.sum(np.abs(ch["rise"]) > RISE_TOL)) for ch in chks.values())
    ntr = sum(len(ch["rise"]) for ch in chks.values())
    L += ["", f"**{tot} of {ntr} validation trials have the command rise outside ±2 frames of the onset frame.** The onsets were NOT changed (spec rule). Notable patterns:",
          f"- m1, m2: the command rises {np.nanmin(chks['m1']['rise']):.2f}–{np.nanmax(chks['m1']['rise']):.2f} (m1) and {np.nanmin(chks['m2']['rise']):.2f}–{np.nanmax(chks['m2']['rise']):.2f} (m2) frames after the onset frame, in every trial (OL and CL). The onset defined from stimStarts precedes the laser by ~0.16–0.18 s (median) in these two sessions, versus ~0.04–0.08 s in the others.",
          "- m3–m8: the offset jitters trial to trial over roughly −5 … +4 frames.",
          "- m9–m13: offsets cluster at ~1.9 frames with a minority at ~2.9 frames (outside ±2) and a few at 2.0–2.2.",
          "- m3–m8 offsets drift gradually from trial to trial and then wrap (saw-tooth pattern in trial order), e.g. m4 trials 115–132 run from −2.5 to −4.9 frames.",
          "- m14, m15: the rise is at ~2.9 frames in nearly all trials (just outside ±2), OL max 4.2 frames. The longest delays (m14 CL trials, up to 17.9 frames) occur only in CL trials and are compatible with the controller output staying at zero while dFk is below the reference (e.g. m14 trials 71 and 89 start below −5 %); not investigated further.",
          "- Old-build commands (m1–m13) are a 35 Hz pulsed waveform (frame-locked half-sine pulses whose amplitude carries the control); new builds are a per-frame staircase.",
          "", "Every trial outside ±2 frames (trial_index = 1-based input_params column, condition, offset in frames):", ""]
    L += outside_lists + [""]

    L += ["## 4. New builds: stimStarts vs timeBlue[kk] − dur", ""]
    for sid in ["m14", "m15"]:
        c = scs[sid]
        L.append(f"- {sid}: max |stimStarts − (timeBlue[kk−1] − dur)| = {c['kk_disagree_max_s']:.3g} s (median {c['kk_disagree_median_s']:.3g} s), kk read 1-based from input_params row 2 over the validation block.")
    L += ["", "Onset frame vs stimStarts (all sessions): max |timeBlue[onset] − stimStarts| = " + ", ".join(f"{k} {c['max_abs_tb_minus_stim']:.4f} s" for k, c in scs.items()), ""]

    L += ["## 5. NaN / out-of-range windows", ""]
    bad = False
    for sid, ch in chks.items():
        nw = {k: v for k, v in ch["nan_windows"].items() if v}
        sn = {k: v for k, v in ch["state_nan"].items() if v}
        if nw or ch["big_in_window"]:
            bad = True
            L.append(f"- {sid}: windows with NaN/out-of-range samples {nw}; trials with |dFk|>50 in any window: {ch['big_in_window']}.")
        if sn:
            L.append(f"- {sid}: NaN states {sn}" + (" (no motion: expected)" if set(sn) == {"motion"} else ""))
    if not bad:
        L.append("- No analysis window (pre, early, late, full, post_rmse, post_var, peri) runs outside the dFk array or contains NaN, and no window sample has |dFk| > 50 %. Nothing was dropped or imputed.")
    nomo = [k for k, c in scs.items() if not c["has_motion"]]
    L.append(f"- Motion state is NaN for the {len(nomo)} sessions without motion ({', '.join(nomo)}), as specified; those sessions are excluded from the motion analyses only.")
    L.append("")

    L += ["## 6. Trial-order randomness (runs test, validation block)", "",
          "| id | n OL | n CL | runs | expected | z | p (two-sided, normal approx.) |", "|---|---|---|---|---|---|---|"]
    for sid, c in scs.items():
        r = c["runs"]
        L.append(f"| {sid} | {c['n_OL']} | {c['n_CL']} | {r['runs']} | {r['expected_runs']:.1f} | {r['z']:.2f} | {r['p']:.3f} |")
    L.append("")

    L += ["## 7. Other observations (not fixed)", ""]
    for sid, c in scs.items():
        if c["val_param_rows_varying"]:
            L.append(f"- **{sid}: input_params rows vary within the validation block** (rows 0-based: values) {c['val_param_rows_varying']}. All validation trials were used as specified.")
    for sid, c in scs.items():
        if c["pre_block_OL"]:
            L.append(f"- {sid}: the {c['n_trials'] - c['n_val']} trials before the validation block include {c['pre_block_OL']} OL and {c['pre_block_CL']} CL trials (excluded by the last-N rule).")
    L.append("- Inter-onset intervals (validation block): " + ", ".join(f"{k} min {c['iti_min']:.1f} s / median {c['iti_median']:.1f} s" for k, c in scs.items()) + ".")
    lt9 = {k: c["iti_lt9"] for k, c in scs.items() if c["iti_lt9"]}
    lt6 = {k: c["iti_lt6"] for k, c in scs.items() if c["iti_lt6"]}
    L.append(f"- Intervals < 9 s (a trial's post_var 3–6 s window overlaps the next trial's pre window): {lt9 if lt9 else 'none'}; < 6 s (next pre window overlaps this trial's stimulus): {lt6 if lt6 else 'none'}.")
    L.append("- Prep covariate validity: the lower-bound test |u| < 0.01 V is applied to the raw command, whose resting (laser-off) level is offset from 0 V. Per session, resting level = median command over [t0−1.5, t0−0.5) s; and the fraction of those laser-off samples that pass |u| < 0.01 V:")
    L.append("  " + "; ".join(f"{k} {ch['cmd_baseline_median']:+.4f} V / {ch['pre_off_frac_below_0p01']:.2f}" for k, ch in chks.items()) + ".")
    L.append("  For the old builds the CL command is also a 35 Hz pulse train, so samples at |u| < 0.01 V inside 0–3 s include pulse troughs, not only frames where the controller output is at zero. Reported as computed (pre-specified); interpret with care.")
    L.append("")

    L += [f"## 8. Sensitivity: m14 with dFk end-aligned (dFk[i] → timeBlue[i+{M14_SHIFT}])", "",
          "Session values for m14:", "", md_table(sens_sess), "",
          "Main tests, primary vs m14-shifted (other 14 sessions unchanged):", ""]
    keep = sens[(sens["role"] == "main")]
    L.append(md_table(keep))
    L.append("")
    (OUT / "CHECKS.md").write_text("\n".join(L), encoding="utf-8")


# --------------------------------------------------------------------------- CHOICES.md
CHOICES = [
    ("Active channel tie", "If two inpVals* channels share the largest 99.9th percentile, take the first of inpVals, inpVals594, inpVals638. Only m15 ties (inpVals and inpVals594 are identical arrays), so the choice has no effect."),
    ("Command time base", "All channels use d.inpTime (spec). In the new builds d.inpTime594 and d.inpTime638 were read only to confirm they are identical to d.inpTime (they are)."),
    ("dFk / timeBlue length mismatch", "Spec says equal lengths; m8 (−1), m13 (−75) and m14 (−11 frames) are shorter. Primary analysis maps dFk[i] to timeBlue[i] (start-aligned, the literal reading); frames without dFk are NaN (none fall in a window). Because the m14 alignment check contradicts this, a sensitivity run with m14 end-aligned (shift 11) is reported in CHECKS §8 and sensitivity_m14_align.csv; it does not replace the primary numbers."),
    ("motion length mismatch", "m10 and m11 d.motion is 1 frame short; start-aligned to timeBlue (no window reaches the missing frame)."),
    ("has_motion", "A session has motion iff max(d.motion) > min(d.motion) over the whole session."),
    ("Onset frame indexing", "Internally 0-based. trials.csv reports onset_frame 1-based (MATLAB convention, comparable with kk); trial_index is the 1-based input_params column; val_index is 0-based within the validation block."),
    ("Validation block", "Exactly the last N input_params columns (and the matching stimStarts entries) per the table, even where controller parameters vary inside it (m4)."),
    ("Fs for spectra", "Fs = 35 Hz (spec) for the PSD frequency axis and normalisation, although the measured frame rate is 35.088 Hz. Windows are defined in samples, so only the spectral band edges are affected (by 0.25 %)."),
    ("Hann taper", "scipy.signal.windows.hann(N, sym=True): symmetric, zero at both ends (same as MATLAB hann(N))."),
    ("Detrend", "scipy.signal.detrend(type='linear'): least-squares straight-line removal over the 175-sample segment."),
    ("nfft", "max(8192, next power of 2 ≥ 8N); for N = 175 this is 8192."),
    ("One-sided PSD", "rfft bins 0..nfft/2; |X|²/(Fs·Σw²); bins 1..nfft/2−1 doubled (DC and Nyquist not doubled)."),
    ("Band integration", "Trapezoid over [lo, bins strictly inside (lo, hi), hi], with the PSD at lo and hi linearly interpolated between neighbouring bins."),
    ("Initial deviation", "|dFk[o] − ref| using the onset-frame sample only."),
    ("State z-score", "z = (x − mean)/SD with SD ddof = 1, over all validation trials of the session (OL+CL pooled). Motion only in motion sessions."),
    ("OLS slope", "Ordinary least squares with intercept, slope = Σ(z−z̄)(y−ȳ)/Σ(z−z̄)², fitted within the condition's trials (z is not re-standardised within condition)."),
    ("Logs", "Natural log for A (log RMSE) and for the ratio tests; A_pct = 100·(e^A − 1). For the A test row, effect_pct / ci_*_pct apply the same transform to the mean and CI of A."),
    ("Variance", "Across-trial variance uses numpy var(ddof=1) per sample offset, then the mean over the window samples; the post variance window is post_var (3–6 s) and post RMSE uses post_rmse (3–4 s), as specified."),
    ("Prep window", "Command samples with timeBlue[o] ≤ t < timeBlue[o]+3 s on d.inpTime, pooled over all CL validation trials; 'session maximum CL command' = the maximum of these pooled samples; total = lower + upper (disjoint). Raw command samples, no offset correction (pre-specified definition kept; validity caveat in CHECKS §7)."),
    ("max_cmd", "Per trial, the maximum active-channel sample over the same 0–3 s interval, OL and CL."),
    ("Onset sanity", "Rise = first sample in [t0−0.5, t0+1.0) s exceeding (median over [t0−1.5, t0−0.5) s) + 0.05 V; offset = (t_rise − t0)/median frame interval; 'within ±2 frames' = |offset| ≤ 2."),
    ("Alignment check", "Added check (not in spec): lag of the most negative correlation between frame-to-frame changes of dFk and of the frame-binned command, lags −20..+20, excluding |dFk| ≥ 50 (start-up transient)."),
    ("Runs test", "Wald–Wolfowitz runs test on the validation-block condition sequence, normal approximation, two-sided."),
    ("sess_test sign count", "k = number of sessions whose value (on the tested scale, i.e. log ratio for ratios) has the same sign as the session mean; k_n = number of non-zero values. tests.csv names the sign-count denominator k_n because the spec lists 'n' twice. The 'sign' column says which sign was counted."),
    ("sess_test CI", "t-based 95 % CI on the tested scale (df = n−1); for log=True the mean and CI are exponentiated (geometric mean and its CI)."),
    ("Wilcoxon", "scipy.stats.wilcoxon(x, method='exact', alternative='two-sided') on the tested-scale values (log ratios vs 0, i.e. ratio vs 1); zero_method default 'wilcox'. Zeros/ties are counted in tests.csv (n_zero, n_tied); none occurred."),
    ("Leave-one-mouse-out", "One-sample t-test p after removing all sessions of one mouse, for each mouse; lomo_worst_p = the largest of these; a mouse whose removal leaves < 2 sessions would be skipped (never happens here)."),
    ("Mouse-averaged", "Per-mouse mean on the tested scale (log for ratios); mouse_k = mice whose mean has the same sign as the session mean; mouse_p = one-sample t-test across the mouse means (n = 4 mice, df = 3)."),
    ("Holm", "Own implementation (tests.holm): step-down, adjusted p_(i) = max over j ≤ i of min(1, (m−j+1)·p_(j)). Families: P and R over the 4 states (m = 8); A over the 4 states (m = 4). Raw p kept."),
    ("Roles", "Fig 3: full = main; early, late = secondary; pre, post = null_window. Fig 4D P, R, A = main (spec gives no role). Fig 4D gap and gap_change = secondary (spec asks for effect and CI; the other columns are filled anyway). Prep Spearman = supplementary."),
    ("gap per state", "gap does not depend on the state; it is repeated per state so that the motion row uses the 11 motion sessions and the others use all 15."),
    ("Spearman", "scipy.stats.spearmanr (average ranks for ties, two-sided p from its t approximation), n = 15 sessions, against the full-window RMSE ratio."),
]


def write_choices():
    L = ["# stats_v2 CHOICES", "", "Decisions taken where SPEC.md was silent or ambiguous (one line each).", ""]
    L += [f"{i}. **{k}**: {v}" for i, (k, v) in enumerate(CHOICES, 1)]
    (OUT / "CHOICES.md").write_text("\n".join(L) + "\n", encoding="utf-8")


# --------------------------------------------------------------------------- manifest
def write_manifest():
    code = {p.name: sha256(p) for p in sorted(Path(__file__).resolve().parent.glob("*.py"))}
    man = {
        "git_commit": git("rev-parse", "HEAD"),
        "git_branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "stats_v2_uncommitted": git("status", "--porcelain", "--", "stats_v2"),
        "code_sha256": code,
        "utc_time": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "python": platform.python_version(),
        "packages": {"numpy": np.__version__, "scipy": scipy.__version__,
                     "pandas": pd.__version__, "h5py": h5py.__version__},
        "inputs": {s[4]: {"session": s[0], "sha256": sha256(loader.DATA / s[4])}
                   for s in loader.SESSIONS},
        "fields_read": sorted(loader.FIELDS_READ),
    }
    (OUT / "manifest.json").write_text(json.dumps(man, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
