"""step_response.py — trial-averaged response AT THE ACTIVATION SITE for LONG-DURATION
(constant-step) photostim on the EXCITATORY (left) hemisphere of AL_0048.

Companion to `al0048_catalog.py`: the catalogue says which experiments hold long left-side
bouts, this script actually averages them. Everything is derived from the RAW 2 kHz Timeline
(`lightCommand594/638`, `galvoX/Y`) for the same reason as the catalogue — the Signals runs
ship no `input_params.csv` and the ones that do use four different column layouts.

A CONDITION = (session, laser, galvo site X *and* Y binned to 0.5 V, command level binned to
0.1 V, duration binned to 0.5 s). Two keys the catalogue does NOT group on are load-bearing
here: duration (2026-06-05 e2 mixes 29 ms impulses and ~2 s steps under one site/power key)
and galvoY (2026-06-07 e1's "three left sites" are three different Y rows, ~200 px apart in
the image — pooling them averages three different cortical areas).

Kept: left hemisphere (`galvoX < 0` = EXCITATORY, locked convention), median bout duration
>= MIN_DUR_S, within-bout command SD < FLAT_SD (a genuine constant step, not a closed-loop
waveform), n >= MIN_N, and saved widefield SVD.

Activation site is DATA-DERIVED, not from the galvo calibration: the extremum of the
(stim - baseline) dF/F map inside the stimulated hemifield (midline from `bregma.csv` when the
session has one), smoothed to reject single hot pixels. Same rule as the impulse module's
`find_focal_pixel`, minus the nominal-position search box (which needs a per-session
hardwareInfo.json that these controller sessions do not all have).

Run:  .venv/Scripts/python.exe bilateral/step_response.py
Outputs -> bilateral/step_png/ (gitignored) + bilateral/STEP_EXCIT.md (the summary table).
"""
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
import scipy.interpolate
import scipy.ndimage
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SERVER = Path("//sahale.biostr.washington.edu/data/Subjects/AL_0048")
HERE = Path(__file__).resolve().parent
OUTDIR = HERE / "step_png"

# ---------------------------- selection knobs ----------------------------
SIDE_SIGN = -1          # galvoX sign kept: -1 = LEFT = excitatory
THR = 0.3               # V, light-command on-threshold
MERGE_GAP_S = 0.5       # sub-pulses closer than this belong to one bout
FLAT_SD = 0.05          # within-bout command SD below which the step is "constant"
MIN_DUR_S = 0.5         # "long duration" cut
MIN_N = 5               # minimum trials to average
DUR_BIN_S = 0.5         # duration binning for the condition key
# Sessions analysed. The two June 594 nm sessions (2026-06-05 e2, 2026-06-07 e1) are OUT:
# their "responses" are photostim light in the camera, not cortex (RESEARCH 2026-08-11 — square
# command-shaped deflections of 20-214 % dF/F, first-frame jump 0.46-0.80, no trial scatter).
# Set to None to sweep every catalogued experiment again (that is how they were caught).
SESSION_KEEP = {("2026-06-11", "6"), ("2026-06-20", "1"), ("2026-07-21", "1")}

# ---------------------------- extraction knobs ----------------------------
N_COMPS = 50            # SVD components (same as grid/impulse dose-response)
ROI_RAD = 10            # px half-width of the site ROI
FS_WIN = 35.0           # trial-window resample rate (Hz; widefield runs ~35 Hz)
WIN_PRE = 1.0           # s before onset
WIN_POST_PAD = 2.0      # s after step offset
BASE_WIN = (-0.5, 0.0)  # per-trial baseline
# TWO loci are reported per condition, because on 2026-07-21 they are ~85 px (1.5 mm) apart and
# there is no window choice that is right for every session:
#   SITE  = max of the whole-step map. With the laser on for the entire step, the illuminated
#           spot is the one that STAYS driven, so this is the primary activation site.
#   EARLY = max of the 0.03-0.15 s map. On 06-11/06-20 it lands on the same blob (<20 px), but
#           on 07-21 it is a diffuse, barely-lateralised transient centred elsewhere that decays
#           BELOW baseline inside the step — an onset/arousal response, not the driven spot.
# Neither is assumed: both are marked, and both traces are drawn when they disagree by more
# than SITE_SPLIT_PX. A high-pass (DoG) site finder was tried and does not merge them — the two
# blobs are separately focal, so this is a real dissociation, not a smoothing artifact.
SITE_WIN_EARLY = (0.03, 0.15)
SITE_SPLIT_PX = 25       # early/whole-step loci further apart than this are traced separately
SUS_T0 = 0.3             # s, start of the sustained map (display only)
PLATEAU_FRAC = 0.25     # plateau = last this fraction of the step
OFF_WIN = 1.0           # s after offset searched for the undershoot
MIDLINE_PX_DEFAULT = 280.0
# Neighbourhood: four ROIs one millimetre from the site along the cortical axes (the widefield
# rig runs 57.8 px/mm). "medial" is toward the midline, so its image direction depends on which
# hemisphere was stimulated; anterior is up in image coords (PX_PER_MM_Y is negative).
NEIGH_OFF_PX = 58
BORDER_PX = 40          # ignore this margin when hunting the site
SMOOTH_PX = 5           # box smoothing of the dF/F map before argmax

# ---------------------------- light-artifact flags ----------------------------
# Photostim light leaking into the camera reproduces the COMMAND waveform: it steps within one
# frame, holds square, rings at the edges and returns instantly at offset — nothing like a
# calcium transient, which needs several frames to rise and adapts inside the step. Two cheap
# discriminators flag it; both are reported, neither silently drops a condition.
ARTIFACT_PEAK_PCT = 20.0    # %dF/F a population widefield signal cannot plausibly reach
ARTIFACT_JUMP_FRAC = 0.7    # fraction of the peak already reached in the FIRST frame


# ============================== Timeline ==============================
def timeline_time(expdir, chan, n_samples):
    """Sample index -> Timeline seconds. `<chan>.timestamps_Timeline.npy` is
    [[idx0, t0], [idxN, tN]] (0-based), so a rig sample-rate change cannot silently
    shift every onset. Falls back to 2 kHz if the file is missing."""
    f = Path(expdir) / f"{chan}.timestamps_Timeline.npy"
    if f.exists():
        ts = np.asarray(np.load(f), dtype=float)
        (i0, t0), (i1, t1) = ts[0], ts[-1]
        return lambda ix: t0 + (np.asarray(ix) - i0) * (t1 - t0) / (i1 - i0)
    return lambda ix: np.asarray(ix) / 2000.0


def bouts(expdir, laser):
    """Merged laser bouts: onset sample, duration, galvo volts, command level, flatness.
    Same detection as al0048_catalog.bout_table, plus Timeline-clock onset times."""
    expdir = Path(expdir)
    f = expdir / f"lightCommand{laser}.raw.npy"
    if not f.exists():
        return []
    v = np.asarray(np.load(f)).ravel()
    if (v > THR).sum() == 0:
        return []
    gx = np.asarray(np.load(expdir / "galvoX.raw.npy")).ravel()
    gy = np.asarray(np.load(expdir / "galvoY.raw.npy")).ravel()
    on = v > THR
    d = np.diff(on.astype(np.int8))
    s = np.flatnonzero(d == 1) + 1
    e = np.flatnonzero(d == -1) + 1
    if on[0]:
        s = np.r_[0, s]
    if on[-1]:
        e = np.r_[e, len(on)]
    t_of = timeline_time(expdir, f"lightCommand{laser}", len(v))
    fs = 1.0 / float(t_of(1) - t_of(0))
    g = int(MERGE_GAP_S * fs)
    ms, me = [s[0]], []
    for i in range(1, len(s)):
        if s[i] - e[i - 1] > g:
            me.append(e[i - 1])
            ms.append(s[i])
    me.append(e[-1])
    out = []
    for a, b in zip(ms, me):
        hi = v[a:b][v[a:b] > THR]
        out.append(dict(t0=float(t_of(a)), dur=float(t_of(b) - t_of(a)),
                        gx=float(np.median(gx[a:b])), gy=float(np.median(gy[a:b])),
                        cmd=float(np.median(hi)), sd=float(hi.std())))
    return out


def conditions(expdir, laser):
    """Long, flat, left-side bouts grouped into (site, power, duration) conditions."""
    b = [r for r in bouts(expdir, laser)
         if np.sign(r["gx"]) == SIDE_SIGN and r["dur"] >= MIN_DUR_S and r["sd"] < FLAT_SD]
    grp = defaultdict(list)
    for r in b:
        grp[(round(r["gx"] * 2) / 2, round(r["gy"] * 2) / 2, round(r["cmd"], 1),
             round(r["dur"] / DUR_BIN_S) * DUR_BIN_S)].append(r)
    return {k: v for k, v in sorted(grp.items(), key=lambda kv: -len(kv[1])) if len(v) >= MIN_N}


# ============================== widefield ==============================
def load_svd(expdir):
    """U (Y,X,nSV) memmap, mimg, V (T,N_COMPS), svdT. Prefers the hemodynamically
    corrected V; falls back to raw blue (flagged by the returned `corr`)."""
    expdir = Path(expdir)
    corr = (expdir / "corr/svdTemporalComponents_corr.npy").exists()
    if corr:
        V = np.asarray(np.load(expdir / "corr/svdTemporalComponents_corr.npy",
                               mmap_mode="r")[:, :N_COMPS])
        svdT = np.asarray(np.load(expdir / "corr/svdTemporalComponents_corr.timestamps.npy"))
    else:
        V = np.asarray(np.load(expdir / "blue/svdTemporalComponents.npy",
                               mmap_mode="r")[:, :N_COMPS])
        svdT = np.asarray(np.load(expdir / "blue/svdTemporalComponents.timestamps.npy"))
    svdT = svdT.ravel()
    n = min(len(svdT), V.shape[0])          # timestamps can outrun V (07-29 e2: by 11)
    if len(svdT) != V.shape[0]:
        print(f"    ! svdT {len(svdT)} vs V {V.shape[0]} -> truncating {abs(len(svdT)-V.shape[0])} from the END")
    U = np.load(expdir / "blue/svdSpatialComponents.npy", mmap_mode="r")
    mimg = np.asarray(np.load(expdir / "blue/meanImage.npy"))
    return U, mimg, V[:n], svdT[:n], corr


def midline_px(date, exp):
    """Image-x of the midline: the session's marked bregma when it has one, else the
    rig default. Image-left = brain-left (verified: impulse left site x=164, right x=401)."""
    f = SERVER / date / str(exp) / "bregma.csv"
    if f.exists():
        try:
            return float(np.loadtxt(f, delimiter=",", skiprows=1)[0]), "bregma.csv"
        except Exception:
            pass
    return MIDLINE_PX_DEFAULT, "default"


def site_map(U50, mimg, t2svd, t0s, win):
    """(stim - baseline) dF/F image over `win` (s rel. onset), trial-averaged."""
    rb = np.arange(BASE_WIN[0], BASE_WIN[1], 1 / FS_WIN)
    rs = np.arange(win[0], win[1], 1 / FS_WIN)
    base_v = np.nanmean(t2svd(t0s[:, None] + rb[None, :]), (0, 1))
    stim_v = np.nanmean(t2svd(t0s[:, None] + rs[None, :]), (0, 1))
    base_im = np.einsum("yxc,c->yx", U50, base_v) + mimg
    stim_im = np.einsum("yxc,c->yx", U50, stim_v) + mimg
    return (stim_im - base_im) / base_im


def find_site(dff, mimg, mid_x):
    """Extremum of the smoothed dF/F map inside the stimulated hemifield."""
    ny, nx = mimg.shape
    sm = scipy.ndimage.uniform_filter(np.nan_to_num(dff), SMOOTH_PX)
    ok = np.zeros_like(sm, dtype=bool)
    ok[BORDER_PX:ny - BORDER_PX, BORDER_PX:nx - BORDER_PX] = True
    ok &= mimg > np.percentile(mimg, 40)          # stay on tissue
    if SIDE_SIGN < 0:
        ok[:, int(mid_x):] = False                # left stim -> left hemifield
    else:
        ok[:, :int(mid_x)] = False
    cand = np.where(ok, sm, -np.inf)
    y, x = np.unravel_index(np.argmax(cand), cand.shape)
    return int(x), int(y)


def neighbour_px(px, mid_x, mimg):
    """The four cardinal neighbours one NEIGH_OFF_PX step from the site, clipped into the
    frame. Returned in a fixed order so colours mean the same thing in every panel."""
    ny, nx = mimg.shape
    med = 1 if px[0] < mid_x else -1          # image direction that points at the midline
    d = NEIGH_OFF_PX
    out = {"anterior": (px[0], px[1] - d), "posterior": (px[0], px[1] + d),
           "medial": (px[0] + med * d, px[1]), "lateral": (px[0] - med * d, px[1])}
    return {k: (int(np.clip(x, ROI_RAD, nx - ROI_RAD)), int(np.clip(y, ROI_RAD, ny - ROI_RAD)))
            for k, (x, y) in out.items()}


def site_traces(U, mimg, t2svd, px, t0s, dur):
    """Per-trial %dF/F at the site ROI, each trial on its own pre-onset baseline."""
    ny, nx = mimg.shape
    x0, x1 = int(np.clip(px[0] - ROI_RAD, 0, nx)), int(np.clip(px[0] + ROI_RAD, 0, nx))
    y0, y1 = int(np.clip(px[1] - ROI_RAD, 0, ny)), int(np.clip(px[1] + ROI_RAD, 0, ny))
    spat = np.asarray(U[y0:y1, x0:x1, :N_COMPS]).mean((0, 1))
    mI = mimg[y0:y1, x0:x1].mean()
    win = np.arange(-WIN_PRE, dur + WIN_POST_PAD, 1 / FS_WIN)
    fluo = t2svd(win[None, :] + t0s[:, None]) @ spat + mI
    base_ix = win < BASE_WIN[1]
    base = np.nanmean(fluo[:, (win >= BASE_WIN[0]) & base_ix], axis=1, keepdims=True)
    return win, 100.0 * (fluo - base) / base


def metrics(win, dff, dur):
    """Peak / time-to-peak / plateau / post-offset extremum of the TRIAL-MEAN trace, plus the
    light-contamination diagnostics (`jump`, `artifact`) described in ARTIFACT_* below."""
    m = np.nanmean(dff, 0)
    sem = np.nanstd(dff, 0) / np.sqrt(dff.shape[0])
    ins = (win >= 0.05) & (win <= dur)
    plat = (win >= dur * (1 - PLATEAU_FRAC)) & (win <= dur)
    off = (win > dur) & (win <= dur + OFF_WIN)
    k = int(np.nanargmax(m[ins]))
    peak = float(m[ins][k])
    first = float(m[np.argmax(win >= 0)])          # first frame at/after onset
    jump = first / peak if peak > 0 else np.nan
    return dict(mean=m, sem=sem,
                peak=peak, t_peak=float(win[ins][k]),
                plateau=float(np.nanmean(m[plat])),
                off=float(np.nanmin(m[off])) if off.any() else np.nan,
                base_sd=float(np.nanstd(m[win < 0])),
                jump=float(jump),
                artifact=bool(peak > ARTIFACT_PEAK_PCT or jump > ARTIFACT_JUMP_FRAC))


# ============================== run ==============================
def main():
    OUTDIR.mkdir(exist_ok=True)
    cat = json.loads((HERE / "al0048_catalog.json").read_text())
    todo = defaultdict(list)                       # (date, exp) -> [(laser, key, bouts)]
    for r in cat:
        if not r["wf"] or (SESSION_KEEP is not None
                           and (r["date"], r["exp"]) not in SESSION_KEEP):
            continue
        for laser in r["lasers"]:
            for k, v in conditions(r["path"], laser).items():
                todo[(r["date"], r["exp"])].append((laser, k, v, r["wf_corr"]))

    results = []
    for (date, exp), conds in sorted(todo.items()):
        expdir = SERVER / date / str(exp)
        print(f"\n{date} e{exp}: {len(conds)} long excitatory condition(s)")
        U, mimg, V, svdT, corr = load_svd(expdir)
        t2svd = scipy.interpolate.interp1d(svdT, V, axis=0, bounds_error=False,
                                           fill_value=np.nan)
        U50 = np.asarray(U[:, :, :N_COMPS])
        mid_x, mid_src = midline_px(date, exp)
        for laser, (gx, gy, cmd, durb), bts, _ in conds:
            t0s = np.array([b["t0"] for b in bts])
            dur = float(np.median([b["dur"] for b in bts]))
            keep = (t0s - WIN_PRE > svdT.min()) & (t0s + dur + WIN_POST_PAD < svdT.max())
            if keep.sum() < MIN_N:
                print(f"  gx{gx:+.1f} gy{gy:+.1f} {cmd:.1f}V {dur:.2f}s: only {keep.sum()} "
                      f"trials inside the imaging record -> skipped")
                continue
            t0s = t0s[keep]
            map_early = site_map(U50, mimg, t2svd, t0s, SITE_WIN_EARLY)
            map_step = site_map(U50, mimg, t2svd, t0s, (0.0, dur))
            px = find_site(map_step, mimg, mid_x)
            px_e = find_site(map_early, mimg, mid_x)
            split = float(np.hypot(px[0] - px_e[0], px[1] - px_e[1]))
            win, dff = site_traces(U, mimg, t2svd, px, t0s, dur)
            M = metrics(win, dff, dur)
            Me = None
            if split > SITE_SPLIT_PX:
                _, dff_e = site_traces(U, mimg, t2svd, px_e, t0s, dur)
                Me = metrics(win, dff_e, dur)
            npx = neighbour_px(px, mid_x, mimg)
            neigh = {}
            for lab, q in npx.items():
                _, dq = site_traces(U, mimg, t2svd, q, t0s, dur)
                neigh[lab] = dict(px=q, **metrics(win, dq, dur))
            results.append(dict(date=date, exp=exp, laser=laser, corr=corr, gx=gx, gy=gy,
                                cmd=cmd, dur=dur, n=int(len(t0s)), px=px, px_e=px_e,
                                split=split, early=Me, neigh=neigh, mid_x=mid_x, mid_src=mid_src,
                                win=win, dff=dff, map=map_early, map_step=map_step,
                                mimg=mimg, **M))
            print(f"  {laser}nm gx{gx:+.1f} gy{gy:+.1f} cmd {cmd:.1f}V {dur:.2f}s n={len(t0s):3d} "
                  f"site=(row {px[1]}, col {px[0]})  peak {M['peak']:+.2f}% @{M['t_peak']:.2f}s "
                  f" plateau {M['plateau']:+.2f}%  off {M['off']:+.2f}%  (pre-sd {M['base_sd']:.2f}, "
                  f"jump {M['jump']:.2f})"
                  + ("" if corr else "   [BLUE ONLY - uncorrected]")
                  + ("   ** LIGHT ARTIFACT **" if M["artifact"] else ""))
            if Me is not None:
                print(f"      early locus {split:.0f} px away at (row {px_e[1]}, col {px_e[0]}): "
                      f"peak {Me['peak']:+.2f}% @{Me['t_peak']:.2f}s  plateau {Me['plateau']:+.2f}%"
                      f"  -> separate onset response, traced too")
        del U50
    plot_all(results)
    write_md(results)
    return results


def plot_all(res):
    if not res:
        print("no conditions passed the filters")
        return
    n = len(res)
    fig, ax = plt.subplots(n, 3, figsize=(10.5, 2.3 * n), squeeze=False)
    for i, r in enumerate(res):
        for j, (key, ttl) in enumerate(
                [("map", f"early {SITE_WIN_EARLY[0]:.2f}-{SITE_WIN_EARLY[1]:.2f}s  (x = early max)"),
                 ("map_step", "whole step  (+ = site)")]):
            a = ax[i, j]
            c = np.nanpercentile(np.abs(r[key]), 99.5)
            a.imshow(r["mimg"], cmap="gray")
            a.imshow(np.where(r["mimg"] > np.percentile(r["mimg"], 40), r[key], np.nan),
                     cmap="RdBu_r", vmin=-c, vmax=c, alpha=0.75)
            a.plot(*r["px"], "k+", ms=9, mew=1.6)
            a.plot(*r["px_e"], "kx", ms=7, mew=1.4)
            a.axvline(r["mid_x"], color="w", lw=0.6, ls=":")
            a.set_xticks([]); a.set_yticks([])
            a.set_ylabel(f"+ ({r['px'][1]},{r['px'][0]})  x ({r['px_e'][1]},{r['px_e'][0]})", fontsize=6)
            head = (f"{r['date']} e{r['exp']} {r['laser']}nm "
                    f"galvo({r['gx']:+.1f},{r['gy']:+.1f})V {r['cmd']:.1f}V {r['dur']:.2f}s "
                    f"n={r['n']}"
                    + ("" if r["corr"] else " [blue only]")
                    + ("  ** LIGHT ARTIFACT **" if r["artifact"] else ""))
            a.set_title(f"{head}\n{ttl}" if j == 0 else ttl,
                        fontsize=7, color="red" if (r["artifact"] and j == 0) else "black")

        b = ax[i, 2]
        b.axhspan(0, 0, color="k")
        b.axvspan(0, r["dur"], color="#ffcc66", alpha=0.35, lw=0)
        b.plot(r["win"], r["dff"].T, color="0.7", lw=0.3, alpha=0.5)
        b.plot(r["win"], r["mean"], color="crimson", lw=1.6, label="site (+)")
        b.fill_between(r["win"], r["mean"] - r["sem"], r["mean"] + r["sem"],
                       color="crimson", alpha=0.3, lw=0)
        if r["early"] is not None:
            b.plot(r["win"], r["early"]["mean"], color="tab:blue", lw=1.3, ls="--",
                   label=f"early locus (x), {r['split']:.0f} px away")
            b.legend(fontsize=6, frameon=False)
        b.axhline(0, color="k", lw=0.6)
        b.set_xlim(r["win"][0], r["win"][-1])
        b.set_xlabel("time from step onset (s)", fontsize=7)
        b.set_ylabel("%dF/F", fontsize=7)
        b.tick_params(labelsize=6)
        b.set_title(f"peak {r['peak']:+.2f}%  plateau {r['plateau']:+.2f}%  "
                    f"off {r['off']:+.2f}%", fontsize=7)
    fig.tight_layout()
    f1 = OUTDIR / "step_excit_conditions.png"
    fig.savefig(f1, dpi=200)
    plt.close(fig)

    # every condition as its own panel, absolute time, own y-scale. No duration normalisation:
    # the 1 s and 3 s steps are different experiments and rescaling time hides that.
    ncol = 3 if len(res) <= 6 else 4
    nrow = int(np.ceil(len(res) / ncol))
    fig, ax = plt.subplots(nrow, ncol, figsize=(3.1 * ncol, 2.4 * nrow), squeeze=False)
    for i, r in enumerate(res):
        a = ax[i // ncol, i % ncol]
        a.axvspan(0, r["dur"], color="#ffcc66", alpha=0.35, lw=0)
        a.plot(r["win"], r["dff"].T, color="0.75", lw=0.3, alpha=0.5)
        a.plot(r["win"], r["mean"], color="crimson", lw=1.6)
        a.fill_between(r["win"], r["mean"] - r["sem"], r["mean"] + r["sem"],
                       color="crimson", alpha=0.3, lw=0)
        if r["early"] is not None:
            a.plot(r["win"], r["early"]["mean"], color="tab:blue", lw=1.2, ls="--")
        a.axhline(0, color="k", lw=0.6)
        a.set_xlim(r["win"][0], r["win"][-1])
        a.tick_params(labelsize=6)
        a.set_xlabel("time from onset (s)", fontsize=7)
        a.set_ylabel("%dF/F", fontsize=7)
        a.set_title(f"{r['date'][5:]} e{r['exp']} {r['laser']}nm  {r['cmd']:.1f}V  {r['dur']:.2f}s"
                    f"  n={r['n']}" + ("" if r["corr"] else "  [blue only]")
                    + ("\n** LIGHT ARTIFACT **" if r["artifact"] else
                       f"\npeak {r['peak']:+.2f}%  plat {r['plateau']:+.2f}%  off {r['off']:+.2f}%"),
                    fontsize=7, color="red" if r["artifact"] else "black")
    for j in range(len(res), nrow * ncol):
        ax[j // ncol, j % ncol].axis("off")
    fig.suptitle("AL_0048 excitatory (left) long-duration steps — trial mean +/- SEM at the "
                 "activation site (blue dashed = early locus where it differs)", fontsize=9)
    fig.tight_layout()
    f2 = OUTDIR / "step_excit_panels.png"
    fig.savefig(f2, dpi=200)
    plt.close(fig)
    f3 = plot_neighbours(res)
    print(f"\nwrote {f1}\n      {f2}\n      {f3}")


NEIGH_COL = {"site": "crimson", "anterior": "tab:blue", "posterior": "tab:green",
             "medial": "tab:orange", "lateral": "tab:purple"}


def plot_neighbours(res):
    """Site vs its four 1 mm neighbours, one row per condition: ROI map + overlaid traces."""
    n = len(res)
    fig, ax = plt.subplots(n, 2, figsize=(9.0, 2.5 * n), squeeze=False)
    for i, r in enumerate(res):
        a = ax[i, 0]
        c = np.nanpercentile(np.abs(r["map_step"]), 99.5)
        a.imshow(r["mimg"], cmap="gray")
        a.imshow(np.where(r["mimg"] > np.percentile(r["mimg"], 40), r["map_step"], np.nan),
                 cmap="RdBu_r", vmin=-c, vmax=c, alpha=0.7)
        a.axvline(r["mid_x"], color="w", lw=0.6, ls=":")
        for lab, q in [("site", r["px"])] + [(k, v["px"]) for k, v in r["neigh"].items()]:
            a.add_patch(plt.Rectangle((q[0] - ROI_RAD, q[1] - ROI_RAD), 2 * ROI_RAD, 2 * ROI_RAD,
                                      fill=False, ec=NEIGH_COL[lab], lw=1.4))
        a.set_xticks([]); a.set_yticks([])
        a.set_title(f"{r['date']} e{r['exp']} {r['laser']}nm {r['cmd']:.1f}V {r['dur']:.2f}s "
                    f"n={r['n']}  — whole-step map + ROIs", fontsize=7)

        b = ax[i, 1]
        b.axvspan(0, r["dur"], color="#ffcc66", alpha=0.35, lw=0)
        for lab, M in [("site", r)] + list(r["neigh"].items()):
            b.plot(r["win"], M["mean"], color=NEIGH_COL[lab], lw=1.4,
                   label=f"{lab} {M['peak']:+.2f}%")
            b.fill_between(r["win"], M["mean"] - M["sem"], M["mean"] + M["sem"],
                           color=NEIGH_COL[lab], alpha=0.18, lw=0)
        b.axhline(0, color="k", lw=0.6)
        b.set_xlim(r["win"][0], r["win"][-1])
        b.set_xlabel("time from step onset (s)", fontsize=7)
        b.set_ylabel("%dF/F", fontsize=7)
        b.tick_params(labelsize=6)
        b.legend(fontsize=6, frameon=False, ncol=2)
        b.set_title(f"site vs neighbours at {NEIGH_OFF_PX} px "
                    f"({NEIGH_OFF_PX / 57.8:.1f} mm), peak of trial mean", fontsize=7)
    fig.tight_layout()
    f = OUTDIR / "step_excit_neighbours.png"
    fig.savefig(f, dpi=200)
    plt.close(fig)
    return f


def write_md(res):
    L = ["# AL_0048 — excitatory (LEFT) long-duration step responses", "",
         "Trial-averaged %dF/F at the **data-derived activation site** for every left-hemisphere",
         f"constant-step condition with bout duration >= {MIN_DUR_S} s, within-bout command SD <",
         f"{FLAT_SD} V, n >= {MIN_N} and saved widefield. Generated by `step_response.py`; the",
         "session inventory it draws on is `AL0048_CATALOG.md`.", "",
         f"Site = extremum of the smoothed whole-step minus ({BASE_WIN[0]} -> 0 s) dF/F map inside the",
         f"stimulated hemifield; ROI = {2*ROI_RAD}x{2*ROI_RAD} px around it. `early` is where the",
         f"{SITE_WIN_EARLY[0]:.2f}-{SITE_WIN_EARLY[1]:.2f} s map peaks and `split` their distance; when split > {SITE_SPLIT_PX} px the early",
         "locus is a separate response and is traced separately (see the figure).",
         "Peak/plateau/offset are read off",
         f"the TRIAL-MEAN trace (plateau = last {PLATEAU_FRAC:.0%} of the step; offset = min within",
         f"{OFF_WIN} s of step end). `pre-sd` is the trial-mean SD before onset — the noise floor.", "",
         f"**`jump`** = fraction of the peak already reached in the FIRST frame after onset. A row is",
         f"flagged **ARTIFACT** when peak > {ARTIFACT_PEAK_PCT:.0f} % or jump > {ARTIFACT_JUMP_FRAC:.1f}: photostim light leaking into",
         "the camera reproduces the command waveform (square, one-frame edges, ringing) instead of a",
         "calcium transient. Flagged rows are kept in the table and in the per-condition figure but",
         "excluded from the overlay — they measure the laser, not the cortex.", "",
         "| date | exp | laser | corr | galvo (X,Y) | cmd | dur | n | site (row,col) | early (row,col) | split | peak | t_peak | plateau | offset | pre-sd | jump | flag |",
         "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in res:
        L.append(f"| {r['date']} | {r['exp']} | {r['laser']} | {'yes' if r['corr'] else '**NO**'} "
                 f"| ({r['gx']:+.1f}, {r['gy']:+.1f}) V | {r['cmd']:.1f} V | {r['dur']:.2f} s | **{r['n']}** "
                 f"| ({r['px'][1]}, {r['px'][0]}) | ({r['px_e'][1]}, {r['px_e'][0]}) "
                 f"| {r['split']:.0f} px | **{r['peak']:+.2f} %** | {r['t_peak']:.2f} s "
                 f"| {r['plateau']:+.2f} % | {r['off']:+.2f} % | {r['base_sd']:.2f} % | {r['jump']:.2f} "
                 f"| {'**ARTIFACT**' if r['artifact'] else 'ok'} |")
    L += ["", f"## Site vs its four {NEIGH_OFF_PX / 57.8:.1f} mm neighbours", "",
          f"Peak of the trial mean at the site and at four ROIs {NEIGH_OFF_PX} px away along the cortical",
          "axes (medial = toward the midline). `spread` = mean neighbour peak / site peak — how",
          "much of the driven response is still present a millimetre out.", "",
          "| date | exp | cmd | site | anterior | posterior | medial | lateral | spread |",
          "|---|---|---|---|---|---|---|---|---|"]
    for r in res:
        g = r["neigh"]
        sp = np.mean([g[k]["peak"] for k in g]) / r["peak"] if r["peak"] else np.nan
        L.append(f"| {r['date']} | {r['exp']} | {r['cmd']:.1f} V | **{r['peak']:+.2f} %** "
                 + "".join(f"| {g[k]['peak']:+.2f} % " for k in
                           ("anterior", "posterior", "medial", "lateral"))
                 + f"| {sp:.0%} |")
    L += ["", "Figures (gitignored, regenerate with the script): `step_png/step_excit_conditions.png`",
          "(per-condition early map + whole-step map + trace), `step_png/step_excit_panels.png`",
          "(one subplot per condition, absolute time — deliberately NOT duration-normalised),",
          "`step_png/step_excit_neighbours.png` (site + 4 neighbours per condition).", ""]
    (HERE / "STEP_EXCIT.md").write_text("\n".join(L), encoding="utf-8")
    print("wrote bilateral/STEP_EXCIT.md")


if __name__ == "__main__":
    main()
