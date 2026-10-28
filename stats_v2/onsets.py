"""Corrected trial onsets from the open-loop laser-command rise (user decision 2026-10-27).

stimStarts (timeBlue at input_params row 2 minus horizon) drifted away from the real laser onset in
some sessions. Only OPEN-LOOP trials mark the onset reliably with the command: a closed-loop command
can start late when the initial error is ~0. So, per session:

  1. Measure the command-rise offset (frames after the stimStarts frame) in every OL trial.
  2. Reference offset L = median OL offset over the build's sessions whose offsets are stable.
     L is NOT the loop latency: it is whole frames of trial bookkeeping (the first command is
     computed from onset frame + 1 in the old builds, + 2 in the new) plus the ~24 ms
     exposure-to-laser latency (methods.tex:101), i.e. ~1.88 and ~2.86 frames.
  3. A session needs correction if any of its OL trials sits > 1.5 frames from L.
  4. In those sessions the onset becomes (laser rise - L): OL trials from their own rise; CL trials
     from the OL offsets interpolated in time. Where the two neighbouring OL offsets jump by
     > 1.5 frames (a clock re-sync between them), take the neighbour that agrees with the CL trial's
     own rise to within 1 frame, else the nearer one in time.

Sessions that do not need correction keep their stimStarts onsets unchanged.

Run:  stats_v2/.venv/Scripts/python.exe -I stats_v2/onsets.py
Writes data/stats_v2/onsets_corrected.csv and ONSETS.md.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

import loader  # noqa: E402
import metrics as M  # noqa: E402

OUT = loader.ROOT / "data" / "stats_v2"
OFF_TOL = 1.5     # frames from L that count as off
OFF_FRAC = 0.0    # any OL trial off -> the session needs correction (separates m1-m8 from m9-m15)
JUMP = 1.5        # frames between neighbouring OL offsets that mark a re-sync
AGREE = 1.0       # frames: CL rise must agree this well to pick a side of a re-sync


def rise_offsets(s):
    """Command-rise offset (frames, continuous) of every validation trial vs its stimStarts frame."""
    tb = s["timeBlue"]
    return np.array([M.rise_offset_frames(s["inpTime"], s["cmd"], tb[o], s["dt_frame"])[0]
                     for o in s["onset"]])


def estimate_offsets(t, e, is_ol):
    """Per-trial offset estimate: OL trials keep their own; others come from the OL trials."""
    use = is_ol & np.isfinite(e)
    to, eo = t[use], e[use]
    est = np.where(use, e, np.nan)
    src = np.where(use, "OL", "")
    for j in np.flatnonzero(~use):
        k = np.searchsorted(to, t[j])
        if k == 0 or k == len(to):
            n = 0 if k == 0 else len(to) - 1
            est[j], src[j] = eo[n], "edge"
            continue
        a, b = k - 1, k
        if abs(eo[b] - eo[a]) <= JUMP:
            w = (t[j] - to[a]) / (to[b] - to[a])
            est[j], src[j] = eo[a] + w * (eo[b] - eo[a]), "interp"
            continue
        own = e[j]
        near = [n for n in (a, b) if np.isfinite(own) and abs(own - eo[n]) <= AGREE]
        if len(near) == 1:
            est[j], src[j] = eo[near[0]], "resync_own"
        else:
            n = a if (t[j] - to[a]) <= (to[b] - t[j]) else b
            est[j], src[j] = eo[n], "resync_near"
    return est, src


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    per = {}
    for sid in loader.SESSION_IDS:
        s = loader.load_session(sid)
        e = rise_offsets(s)
        ol = s["cond"] == 0
        per[sid] = dict(s=dict(id=sid, build=s["build"], mouse=s["mouse"], dt=s["dt_frame"],
                               tb=s["timeBlue"], onset=s["onset"], val_cols=s["val_cols"],
                               cond=s["cond"]), e=e, ol=ol)
        del s

    # Nominal latency per build, from the stable sessions (iterate once: provisional L = median of all).
    L = {}
    for build in ("old", "new"):
        ids = [k for k, v in per.items() if v["s"]["build"] == build]
        L0 = np.nanmedian(np.concatenate([per[k]["e"][per[k]["ol"]] for k in ids]))
        stable = [k for k in ids
                  if np.mean(np.abs(per[k]["e"][per[k]["ol"]] - L0) > OFF_TOL) <= OFF_FRAC]
        L[build] = float(np.nanmedian(np.concatenate([per[k]["e"][per[k]["ol"]] for k in stable])))

    rows, summ = [], []
    for sid, v in per.items():
        s, e, ol = v["s"], v["e"], v["ol"]
        Lb = L[s["build"]]
        off_frac = float(np.mean(np.abs(e[ol] - Lb) > OFF_TOL))
        needs = off_frac > OFF_FRAC
        tb, onset = s["tb"], s["onset"]
        t = tb[onset]
        est, src = estimate_offsets(t, e, ol)
        if needs:
            t_new = t + (est - Lb) * s["dt"]
            on_new = np.array([int(np.argmin(np.abs(tb - x))) for x in t_new])
        else:
            on_new, src = onset.copy(), np.full(len(onset), "unchanged")
        cl_ok = (~ol) & np.isfinite(e) & (src != "OL")
        agree = np.abs(e[cl_ok] - est[cl_ok])
        summ.append(dict(session=sid, mouse=s["mouse"], build=s["build"], L=Lb,
                         ol_offset_median=float(np.nanmedian(e[ol])),
                         ol_offset_min=float(np.nanmin(e[ol])), ol_offset_max=float(np.nanmax(e[ol])),
                         ol_off_frac=off_frac, corrected=needs,
                         shift_median=float(np.median(on_new - onset)),
                         shift_min=int(np.min(on_new - onset)), shift_max=int(np.max(on_new - onset)),
                         cl_check_n=int(cl_ok.sum()),
                         cl_check_within1=float(np.mean(agree <= 1.0)) if cl_ok.any() else np.nan,
                         n_resync=int(np.sum(np.char.startswith(src.astype(str), "resync")))))
        for j in range(len(onset)):
            rows.append(dict(session=sid, trial_index=int(s["val_cols"][j]) + 1,
                             condition="CL" if s["cond"][j] == 1 else "OL",
                             onset_frame_stim=int(onset[j]) + 1, rise_offset=e[j],
                             est_offset=est[j], source=src[j], onset_frame=int(on_new[j]) + 1,
                             shift=int(on_new[j] - onset[j])))

    pd.DataFrame(rows).to_csv(OUT / "onsets_corrected.csv", index=False)
    sm = pd.DataFrame(summ)
    lines = ["# Corrected onsets (OL laser-command rise)", "",
             f"Reference offset L (frames, logged onset frame -> first laser command; NOT loop latency, see docstring): old builds {L['old']:.2f}, "
             f"new builds {L['new']:.2f}.",
             f"A session is corrected if > {OFF_FRAC:.0%} of its OL trials sit > {OFF_TOL} frames from L.",
             "cl_check = CL trials whose own rise was detected: share within 1 frame of the OL-derived estimate.",
             "", "```", sm.round(2).to_string(index=False), "```"]
    (OUT / "ONSETS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
