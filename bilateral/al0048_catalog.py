"""Full catalogue of every AL_0048 experiment on the server.

For each <date>/<exp> folder records: what kind of run it is (expDef / experimentType),
whether widefield SVD exists (and whether hemodynamic-corrected), what the controller log
says, and — derived from the RAW Timeline traces, which is the only source that works for
every session — the photostim structure: laser line, per-hemisphere bout counts, and the
distinct (side, command, duration, flat?) trial-type groups.

Writes, beside this file: al0048_catalog.json (machine-readable) and AL0048_CATALOG.md
(the human lookup table). Read-only w.r.t. the server.

Run:  .venv/Scripts/python.exe bilateral/al0048_catalog.py
Re-run it whenever new AL_0048 sessions land; the interactive counterpart that opens any
catalogued trial type in pixelTuningCurveViewerSVD is bilateral/bil_pick_viewer.m.
"""
import json
from collections import defaultdict
from pathlib import Path

import numpy as np

SERVER = Path("//sahale.biostr.washington.edu/data/Subjects/AL_0048")
OUT = Path(__file__).resolve().parent
FS, THR = 2000.0, 0.3
FLAT_SD = 0.05          # within-bout command SD below which the step is "constant"
MERGE_GAP_S = 0.5       # sub-pulses closer than this belong to one bout


def bout_table(E, laser):
    """Merged laser bouts with galvo side, command level, duration and flatness."""
    v = np.load(E / f"lightCommand{laser}.raw.npy").ravel()
    if (v > THR).sum() == 0:
        return []
    gx = np.load(E / "galvoX.raw.npy").ravel()
    gy = np.load(E / "galvoY.raw.npy").ravel()
    on = v > THR
    d = np.diff(on.astype(np.int8))
    s = np.flatnonzero(d == 1) + 1
    e = np.flatnonzero(d == -1) + 1
    if on[0]:
        s = np.r_[0, s]
    if on[-1]:
        e = np.r_[e, len(on)]
    g = int(MERGE_GAP_S * FS)
    ms, me = [s[0]], []
    for i in range(1, len(s)):
        if s[i] - e[i - 1] > g:
            me.append(e[i - 1])
            ms.append(s[i])
    me.append(e[-1])
    out = []
    for a, b in zip(np.array(ms), np.array(me)):
        seg = v[a:b]
        hi = seg[seg > THR]
        out.append(dict(t0=round(a / FS, 4), dur=round((b - a) / FS, 3),
                        gx=round(float(np.median(gx[a:b])), 3),
                        gy=round(float(np.median(gy[a:b])), 3),
                        cmd=round(float(np.median(hi)), 3),
                        sd=round(float(hi.std()), 4),
                        npulse=int(np.sum(np.diff((seg > THR).astype(np.int8)) == 1) + 1)))
    return out


def kind_of(bouts):
    """Coarse experiment kind from the bout duration distribution."""
    if not bouts:
        return "no-stim"
    dur = np.array([b["dur"] for b in bouts])
    npul = np.array([b["npulse"] for b in bouts])
    if np.median(dur) < 0.1:
        return "impulse (single-frame pulses)"
    if np.median(npul) > 3:
        return "modulated (sine / carrier)"
    flat_frac = np.mean([b["sd"] < FLAT_SD for b in bouts])
    return "constant step" if flat_frac > 0.6 else "continuous / closed-loop"


cat = []
for date_dir in sorted(SERVER.iterdir()):
    if not date_dir.is_dir():
        continue
    for exp in sorted(date_dir.iterdir()):
        if not exp.is_dir() or exp.name == "optoGalvoCalib":
            continue
        rec = dict(date=date_dir.name, exp=exp.name, path=str(exp))

        # ---- what the rig called it -------------------------------------
        rec["expdef"] = rec["exptype"] = ""
        pj = sorted(exp.glob("*parameters.json"))
        if pj:
            try:
                j = json.loads(pj[0].read_text())
            except Exception:
                j = {}
            rec["exptype"] = str(j.get("experimentType", ""))
            rec["expdef"] = Path(str(j.get("defFunction", ""))).stem
        rec["has_block"] = bool(list(exp.glob("*_Block.mat")))

        # ---- imaging -----------------------------------------------------
        blue = exp / "blue/svdTemporalComponents.npy"
        rec["wf"] = blue.exists()
        rec["wf_corr"] = (exp / "corr/svdTemporalComponents_corr.npy").exists()
        rec["n_frames"] = 0
        if rec["wf"]:
            rec["n_frames"] = int(np.load(blue, mmap_mode="r").shape[0])
        rec["cam_only"] = (not rec["wf"]) and (exp / "widefieldExposure.raw.npy").exists()

        # ---- controller log ---------------------------------------------
        rec["ip_rows"] = rec["ip_cols"] = 0
        ip = exp / "input_params.csv"
        if ip.exists():
            try:
                a = np.genfromtxt(ip, delimiter=",", skip_header=1)
                a = np.atleast_2d(a)
                rec["ip_rows"], rec["ip_cols"] = int(a.shape[0]), int(a.shape[1])
            except Exception:
                pass

        # ---- photostim ---------------------------------------------------
        rec["dur_s"] = 0.0
        rec["lasers"] = {}
        if (exp / "galvoX.raw.npy").exists():
            rec["dur_s"] = round(len(np.load(exp / "galvoX.raw.npy", mmap_mode="r")) / FS, 1)
            for laser in ("638", "594"):
                if not (exp / f"lightCommand{laser}.raw.npy").exists():
                    continue
                b = bout_table(exp, laser)
                if not b:
                    continue
                # A trial TYPE = (hemisphere, galvo site to 0.5 V, command level to 0.1 V).
                # Duration is summarised, not grouped on: it jitters by a frame on pulsed
                # runs and varies continuously on closed-loop runs, so grouping by it
                # shatters real conditions into dozens of singletons.
                grp = defaultdict(list)
                for r in b:
                    grp[(("L" if r["gx"] < 0 else "R"),
                         round(r["gx"] * 2) / 2, round(r["cmd"], 1))].append(r)
                groups = []
                for k, rs in sorted(grp.items(), key=lambda kv: -len(kv[1])):
                    dur = np.array([x["dur"] for x in rs])
                    groups.append(dict(
                        side=k[0], galvo_x_v=k[1], cmd_v=k[2], n=len(rs),
                        dur_med=round(float(np.median(dur)), 3),
                        dur_min=round(float(dur.min()), 3), dur_max=round(float(dur.max()), 3),
                        flat_frac=round(float(np.mean([x["sd"] < FLAT_SD for x in rs])), 2)))
                rec["lasers"][laser] = dict(
                    n_bouts=len(b), kind=kind_of(b),
                    n_left=int(sum(r["gx"] < 0 for r in b)),
                    n_right=int(sum(r["gx"] >= 0 for r in b)),
                    groups=groups, bouts=b)
        cat.append(rec)
        print(f"{rec['date']} e{rec['exp']:<3} wf={'Y' if rec['wf'] else ('cam' if rec['cam_only'] else 'N')}"
              f"{'+corr' if rec['wf_corr'] else '':6s} ip={rec['ip_rows']}x{rec['ip_cols']:<3} "
              f"{rec['expdef'] or rec['exptype']:<26} "
              + " | ".join(f"{L}: {v['n_bouts']} bouts, {v['kind']}, L{v['n_left']}/R{v['n_right']}"
                           for L, v in rec["lasers"].items()))

# the per-bout list is ~2 MB and is re-derived from the Timeline by every consumer
# (bil_pick_viewer.m does its own detection), so only the summary is persisted
slim = [{k: ({L: {kk: vv for kk, vv in d.items() if kk != "bouts"} for L, d in v.items()}
             if k == "lasers" else v) for k, v in r.items()} for r in cat]
(OUT / "al0048_catalog.json").write_text(json.dumps(slim, indent=1))

# ------------------------------- markdown table ---------------------------
def runtype(r):
    if r["expdef"]:
        return f"`{r['expdef']}` (Signals)"
    if r["ip_cols"] == 17:
        return "controller, 17-col FFA build"
    if r["ip_cols"] == 18:
        return "controller, 18-col build"
    if r["ip_cols"] == 12:
        return "controller, 12-col build"
    if r["ip_cols"] == 9:
        return "opto/controller, 9-col build"
    if r["has_block"]:
        return "Signals block"
    return "Timeline only"


def imaging(r):
    if r["wf"]:
        return ("SVD + **corr**" if r["wf_corr"] else "SVD, blue only") + f", {r['n_frames']} fr"
    return "camera ran, **not saved**" if r["cam_only"] else "none"


L = []
L.append("# AL_0048 — experiment catalogue")
L.append("")
L.append("Every experiment folder under `\\\\sahale…\\Subjects\\AL_0048\\`, auto-generated from the")
L.append("**raw 2 kHz Timeline** (`lightCommand594/638`, `galvoX/Y`) rather than from `input_params.csv`.")
L.append("That is deliberate: the Signals runs (`opto_bilateralImpulse638`, `opto_brainGrid638`,")
L.append("`opto_Impulse638`) ship no `input_params.csv` at all, and the ones that do use four different")
L.append("column layouts across rig builds — the Timeline is the only source common to all 47 experiments.")
L.append("")
L.append("**Side convention (locked):** `galvoX < 0` → **LEFT = excitatory**; `galvoX > 0` → **RIGHT = inhibitory**.")
L.append("Verified against the 2026-07-15 impulse polarity (left +dF/F monotonic in amplitude, right −dF/F).")
L.append("")
L.append("**To open any row:** set `SESS_DATE`/`SESS_EXP` in [`bil_pick_viewer.m`](bil_pick_viewer.m), run it")
L.append("once to print that session's trial-type menu, then set `SEL` and re-run to launch")
L.append("`pixelTuningCurveViewerSVD`. Rows with imaging *not saved* have trials but cannot be viewed.")
L.append("")
L.append("**Stim kind** is inferred from the bout-duration distribution: `impulse` = median < 0.1 s,")
L.append("`modulated` = >3 sub-pulses per bout (sine/carrier), `constant step` = >60 % of bouts flat")
L.append("(within-bout command SD < 0.05 V), else `continuous/closed-loop`.")
L.append("")
L.append("## Master table")
L.append("")
L.append("| date | exp | run type | imaging | trial log | laser | stim kind | bouts (L/R) |")
L.append("|---|---|---|---|---|---|---|---|")
for r in cat:
    log = f"{r['ip_rows']}×{r['ip_cols']}" if r["ip_rows"] else ("Block.mat" if r["has_block"] else "—")
    if not r["lasers"]:
        L.append(f"| {r['date']} | {r['exp']} | {runtype(r)} | {imaging(r)} | {log} | — | no stim | — |")
        continue
    for las, v in r["lasers"].items():
        L.append(f"| {r['date']} | {r['exp']} | {runtype(r)} | {imaging(r)} | {log} | {las} nm "
                 f"| {v['kind']} | **{v['n_bouts']}** ({v['n_left']}/{v['n_right']}) |")

# ---------------- excitatory-side inventory ----------------
L.append("")
L.append("## Excitatory (LEFT) trial types — the analysable inventory")
L.append("")
L.append("Every left-hemisphere trial type with **n ≥ 5 and saved widefield**. A *type* is")
L.append("(hemisphere, galvo site binned to 0.5 V, command level binned to 0.1 V); duration is")
L.append("reported, not grouped on, because it jitters by a frame on pulsed runs and varies")
L.append("continuously on closed-loop runs.")
L.append("")
L.append("| date | exp | laser | corr? | galvoX | cmd | n | duration | shape |")
L.append("|---|---|---|---|---|---|---|---|---|")
for r in cat:
    if not r["wf"]:
        continue
    for las, v in r["lasers"].items():
        for g in v["groups"]:
            if g["side"] != "L" or g["n"] < 5:
                continue
            # flat/modulated is only meaningful for bouts long enough to have a plateau —
            # a 25 ms pulse is all ramp, so its command SD says nothing about its shape
            shape = ("impulse" if g["dur_med"] < 0.1 else
                     "CONSTANT step" if g["flat_frac"] > 0.8 else
                     "modulated" if g["flat_frac"] < 0.2 else
                     f"mixed ({g['flat_frac']:.0%} flat)")
            # a >3x duration spread means two conditions (e.g. impulse + step) share one
            # (site, power) key — they must be split before any trial average
            if g["dur_max"] > 3 * max(g["dur_min"], 1e-6):
                shape += " ⚠ **split by duration**"
            L.append(f"| {r['date']} | {r['exp']} | {las} | {'✔' if r['wf_corr'] else '—'} "
                     f"| {g['galvo_x_v']:+.1f} V | {g['cmd_v']:.1f} V | **{g['n']}** "
                     f"| {g['dur_med']:.3f} s ({g['dur_min']:.2f}–{g['dur_max']:.2f}) | {shape} |")

(OUT / "AL0048_CATALOG.md").write_text("\n".join(L) + "\n", encoding="utf-8")
print("wrote bilateral/AL0048_CATALOG.md", len(L), "lines")
