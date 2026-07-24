"""
build_ff_data.py — assemble the feedforward (sine-tracking) demo bundle.

Session: AL_0048 2026-07-21/1 (dual-opsin, right/inhibitory hemisphere).
Reads the MATLAB-exported movie bundle (assets/ff_<tag>_bundle.mat) + the local
camera/sync cache (assets/server_cache/<key>/) and produces assets/demo_ff_<key>.npz
for make_ff_video.py.

Adds, relative to the controller demo:
  - 4 controller MODES (ff_cond 2=OL 1=OL+prev 3=CL 0=CL+prev), one fixed sine ref
  - per-trial PUPIL diameter (segmented from eye.mp4) + MOTION energy (motEngProc)
  - 3 auto-picked REAL-TIME trials (high-motion / sleepy / clean-tracking)
  - a variable-speed playback schedule (real-time trials slow, others fast)
  - the exact displayed eye+face camera frames (pre-extracted, one monotonic pass)

Run:
  .venv/Scripts/python.exe presentation/build_ff_data.py --key 0721 --validate
  .venv/Scripts/python.exe presentation/build_ff_data.py --key 0721
"""
import argparse
import os
import subprocess
import numpy as np
import scipy.io as sio
from scipy import ndimage
import imageio_ffmpeg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")
FF = imageio_ffmpeg.get_ffmpeg_exe()
CONTAINER_FPS = 30.0        # nominal container fps; real acq ~69 fps, index-mapped via ft

# ff_cond -> (order, label); display order OL, OL+prev, CL, CL+prev
MODE_ORDER = {2: 0, 1: 1, 3: 2, 0: 3}
MODE_LABEL = {2: "OL", 1: "OL+prev", 3: "CL", 0: "CL+prev"}
MODE_COL = {2: "#8a8f99", 1: "#3f7fd6", 3: "#d6593b", 0: "#2f9e54"}

# playback: frames rendered per trial
FPS = 30
RT_FRAMES = None      # real-time trials: set from window duration below
FAST_FRAMES = 6       # fast montage trials


def grab_window(video, W, H, ft, t0, t1, nframes, crop=None):
    """Grab the [t0,t1] Timeline-sec window from *video* as (nframes,H,W) gray uint8,
    via fast keyframe seek on the nominal-30fps container (index-mapped through ft)."""
    i0 = int(np.searchsorted(ft, t0)); i1 = int(np.searchsorted(ft, t1))
    vt0 = i0 / CONTAINER_FPS
    dur = max(0.1, (i1 - i0) / CONTAINER_FPS)
    vf = (f"crop={crop[2]}:{crop[3]}:{crop[0]}:{crop[1]}," if crop else "") + \
         f"scale={W}:{H},format=gray"
    cmd = [FF, "-nostdin", "-loglevel", "error", "-ss", f"{vt0:.3f}", "-i", video,
           "-t", f"{dur:.3f}", "-vf", vf, "-f", "rawvideo", "-pix_fmt", "gray", "pipe:1"]
    r = subprocess.run(cmd, capture_output=True)
    a = np.frombuffer(r.stdout, np.uint8)
    nf = a.size // (W * H)
    if nf == 0:
        return np.zeros((nframes, H, W), np.uint8)
    a = a[:nf * W * H].reshape(nf, H, W)
    idx = np.linspace(0, nf - 1, nframes).round().astype(int)
    return a[idx]


def seg_pupil_fast(gray, prev=None):
    """validated pupil segmentation on a (already half-res) gray frame."""
    from pupil_seg import seg_pupil
    d, cx, cy, _ = seg_pupil(gray.astype(np.float32), dark_pct=7,
                             min_area=40, max_area=1500, prev=prev)
    if not np.isfinite(d):
        return np.nan, prev
    return d, (cx, cy)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--key", default="0721")
    ap.add_argument("--validate", action="store_true",
                    help="stop after pupil/motion/auto-pick; emit diagnostic PNG")
    args = ap.parse_args()
    key = args.key
    cache = os.path.join(ASSETS, "server_cache", key)

    m = sio.loadmat(os.path.join(ASSETS, f"ff_{key}_bundle.mat"))
    U_ds = m["U_ds"].astype(np.float32)                     # (n,n,K)
    mimg = m["mimg_ds"].astype(np.float32)                  # (n,n)
    Vwin = m["Vwin"].astype(np.float32)                     # (K,NWIN,Ntr)
    dFoF = m["dFoFwin"].astype(np.float64)                  # (Ntr,NWIN)
    refw = m["refwin"].astype(np.float64)                   # (Ntr, n_win+1)
    ffc = m["ffcond"].astype(int).ravel()                   # (Ntr,)
    onset_t = m["onset_t"].astype(float).ravel()            # Timeline sec
    pixel = m["pixel"].astype(float).ravel()
    ds = int(m["ds"].ravel()[0])
    ref0 = float(m["ref0"].ravel()[0]); amp = float(m["amp"].ravel()[0])
    dur = float(m["dur"].ravel()[0]); fs = float(m["fs_img"].ravel()[0])
    n_pre = int(m["n_pre"].ravel()[0]); n_win = int(m["n_win"].ravel()[0])
    NWIN = int(m["NWIN"].ravel()[0])
    Ntr = dFoF.shape[0]
    t_win = (np.arange(NWIN) - n_pre) / fs                  # -1 .. dur
    post = t_win >= 0

    # ---- reference: the commanded sine, defined only during the stim (0..dur) --
    REFW = np.full((Ntr, NWIN), np.nan)
    REFW[:, n_pre:] = refw
    REFW[:, t_win > dur + 1e-6] = np.nan                    # no command after stim end

    # ---- per-trial tracking error (MSE vs sine, over the stim window) -----
    stim = (t_win >= 0) & (t_win <= dur)
    MSE = np.nanmean((dFoF[:, stim] - REFW[:, stim]) ** 2, axis=1)

    # ---- motion energy synced to each window ------------------------------
    ft = np.load(os.path.join(cache, "frameTimes.timestamps.npy")).ravel()
    meng = np.load(os.path.join(cache, "motEngProc.npy")).ravel()
    half = min(len(ft) // 2, len(meng))                    # motEng at half cam-rate (frame 2i)
    meng_t = ft[0:2 * half:2]
    meng = meng[:half]                                     # clip tail beyond Timeline log
    MOT = np.zeros((Ntr, NWIN))
    for j in range(Ntr):
        MOT[j] = np.interp(onset_t[j] + t_win, meng_t, meng)

    # ---- pupil diameter synced to each window (segment eye.mp4) -----------
    eye_path = os.path.join(cache, "eye.mp4")
    EW, EH = 224, 246           # half-res eye frame for fast segmentation
    PUP = np.full((Ntr, NWIN), np.nan)
    pup_frac = np.zeros(Ntr)                     # fraction of window with a segmentable pupil
    print(f"segmenting pupil over {Ntr} trial windows ...")
    for j in range(Ntr):
        stack = grab_window(eye_path, EW, EH, ft, onset_t[j] + t_win[0],
                            onset_t[j] + t_win[-1], NWIN)
        prev = None
        vals = np.full(NWIN, np.nan)
        samp = list(range(0, NWIN, 2))          # every 2nd sample; interpolate rest
        for tau in samp:
            d, prev = seg_pupil_fast(stack[tau], prev)
            vals[tau] = d
        good = np.isfinite(vals)
        pup_frac[j] = good[samp].sum() / len(samp)
        idx = np.arange(NWIN)
        if good.sum() >= 2:
            vals = np.interp(idx, idx[good], vals[good])
        PUP[j] = vals
        if (j + 1) % 40 == 0:
            print(f"  {j + 1}/{Ntr}")
    PUP = ndimage.median_filter(PUP, size=(1, 5))

    # ---- auto-pick 3 real-time trials -------------------------------------
    mot_lvl = np.nanmean(MOT[:, post], axis=1)
    pup_lvl = np.nanmean(PUP[:, post], axis=1)
    mz = (mot_lvl - np.nanmedian(mot_lvl)) / (np.nanstd(mot_lvl) + 1e-9)
    pz = (pup_lvl - np.nanmedian(pup_lvl)) / (np.nanstd(pup_lvl) + 1e-9)
    trackable = pup_frac >= 0.6                              # need a showable pupil trace

    hi_motion = int(np.nanargmax(mot_lvl))
    # sleepy: low motion AND small (constricted) pupil, but pupil must be trackable
    # enough to display. Score low = drowsy; restrict to trackable, not the motion pick.
    sleep_score = np.where(trackable, mz + pz, np.inf)
    sleep_score[hi_motion] = np.inf
    sleepy = int(np.argmin(sleep_score))
    # clean tracking: low MSE among preview modes, low motion, trackable pupil
    clean_pool = np.where(np.isin(ffc, [1, 0]) & (mz < 0.5) & trackable)[0]
    clean = int(clean_pool[np.argmin(MSE[clean_pool])]) if len(clean_pool) else int(np.argmin(MSE))
    picks = {"high-motion": hi_motion, "sleepy": sleepy, "clean-tracking": clean}
    print("auto-picked real-time trials:")
    for lab, j in picks.items():
        print(f"  {lab:14s} trial#{j:3d} mode={MODE_LABEL[ffc[j]]:8s} "
              f"mot={mot_lvl[j]:.2f} pup={pup_lvl[j]:.1f} pfrac={pup_frac[j]:.2f} mse={MSE[j]:.2f}")

    if args.validate:
        _diag(t_win, dFoF, REFW, MOT, PUP, MSE, ffc, picks, post, key)
        return

    # ---- variable-speed playback schedule ---------------------------------
    rt_idx = np.array(sorted(set(picks.values())))
    rt_label_map = {v: k for k, v in picks.items()}
    RT_FRAMES = int(round(FPS * (t_win[-1] - t_win[0])))     # real time: ~30 fps * 5 s
    sched_trial, sched_tau = [], []
    for j in range(Ntr):
        nfr = RT_FRAMES if j in rt_idx else FAST_FRAMES
        taus = np.linspace(0, NWIN - 1, nfr).round().astype(int)
        sched_trial += [j] * nfr
        sched_tau += taus.tolist()
    SCHED_TRIAL = np.array(sched_trial); SCHED_TAU = np.array(sched_tau)
    print(f"schedule: {len(SCHED_TRIAL)} output frames "
          f"({len(rt_idx)} real-time x {RT_FRAMES} + {Ntr - len(rt_idx)} fast x {FAST_FRAMES})")

    # ---- extract the displayed eye+face camera frames ---------------------
    face_path = os.path.join(cache, "face.mp4")
    EYE_DW, EYE_DH = 132, 145           # display eye size (448x492 aspect)
    FACE_DW, FACE_DH = 152, 135         # display face size (544x484 aspect)
    CAM_EYE = np.zeros((len(SCHED_TRIAL), EYE_DH, EYE_DW), np.uint8)
    CAM_FACE = np.zeros((len(SCHED_TRIAL), FACE_DH, FACE_DW), np.uint8)
    print("extracting displayed camera frames ...")
    for j in range(Ntr):
        fr_mask = SCHED_TRIAL == j
        taus_j = SCHED_TAU[fr_mask]
        eye_w = grab_window(eye_path, EYE_DW, EYE_DH, ft, onset_t[j] + t_win[0],
                            onset_t[j] + t_win[-1], NWIN)
        face_w = grab_window(face_path, FACE_DW, FACE_DH, ft, onset_t[j] + t_win[0],
                             onset_t[j] + t_win[-1], NWIN)
        CAM_EYE[fr_mask] = eye_w[taus_j]
        CAM_FACE[fr_mask] = face_w[taus_j]
        if (j + 1) % 40 == 0:
            print(f"  {j + 1}/{Ntr}")

    # ---- assemble + save --------------------------------------------------
    n = int(np.sqrt(U_ds.shape[0] * U_ds.shape[1] / U_ds.shape[2])) if U_ds.ndim == 2 else U_ds.shape[0]
    n = mimg.shape[0]; K = U_ds.shape[2]
    roi = pixel / ds
    out = os.path.join(ASSETS, f"demo_ff_{key}.npz")
    np.savez_compressed(
        out,
        U_ds=U_ds.reshape(-1, K), mimg=mimg, roi=roi,
        Vwin=np.transpose(Vwin, (2, 0, 1)),          # (Ntr,K,NWIN)
        dFoF=dFoF, REFW=REFW, MOT=MOT, PUP=PUP,
        ffc=ffc, MSE=MSE, pup_frac=pup_frac,
        t_win=t_win, fs=fs, dur=dur, n_pre=n_pre, ref0=ref0, amp=amp,
        NWIN=NWIN, n=n, K=K,
        SCHED_TRIAL=SCHED_TRIAL, SCHED_TAU=SCHED_TAU,
        CAM_EYE=CAM_EYE, CAM_FACE=CAM_FACE,
        rt_idx=rt_idx, rt_labels=np.array([rt_label_map[j] for j in rt_idx]),
        RT_FRAMES=RT_FRAMES, FAST_FRAMES=FAST_FRAMES, FPS=FPS,
        mouse=str(m["mouse"][0]) if "mouse" in m else "AL_0048",
        date=str(m["dt_str"][0]) if "dt_str" in m else "2026-07-21",
        session=key,
    )
    print(f"wrote {out} ({os.path.getsize(out)/1e6:.1f} MB)")


def _diag(t_win, dFoF, REFW, MOT, PUP, MSE, ffc, picks, post, key):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(3, 3, figsize=(13, 8))
    for col, (lab, j) in enumerate(picks.items()):
        axes[0, col].plot(t_win, dFoF[j], color=MODE_COL[ffc[j]], lw=1.5, label="ΔF/F")
        axes[0, col].plot(t_win, REFW[j], "k--", lw=1.0, label="sine ref")
        axes[0, col].set_title(f"{lab}: trial#{j} {MODE_LABEL[ffc[j]]}  MSE={MSE[j]:.2f}", fontsize=9)
        axes[0, col].axvline(0, color="0.6", ls=":"); axes[0, col].legend(fontsize=7)
        axes[1, col].plot(t_win, MOT[j], color="#c0392b"); axes[1, col].set_ylabel("motion")
        axes[1, col].axvline(0, color="0.6", ls=":")
        axes[2, col].plot(t_win, PUP[j], color="#2c7fb8"); axes[2, col].set_ylabel("pupil D (px)")
        axes[2, col].axvline(0, color="0.6", ls=":"); axes[2, col].set_xlabel("t (s)")
    fig.suptitle(f"FF {key}: auto-picked real-time trials (validation)", fontsize=11)
    fig.tight_layout()
    out = os.path.join(ASSETS, f"ff_{key}_validate.png")
    fig.savefig(out, dpi=110)
    print("wrote", out)
    # also a session-overview: motion & pupil level per trial
    fig2, ax = plt.subplots(2, 1, figsize=(12, 5), sharex=True)
    ax[0].plot(np.nanmean(MOT[:, post], 1), ".-", color="#c0392b"); ax[0].set_ylabel("mean motion")
    ax[1].plot(np.nanmean(PUP[:, post], 1), ".-", color="#2c7fb8"); ax[1].set_ylabel("mean pupil D")
    for lab, j in picks.items():
        for a in ax:
            a.axvline(j, color="k", ls="--", lw=0.8)
    ax[1].set_xlabel("trial (acquisition order)")
    fig2.suptitle(f"FF {key}: per-trial motion & pupil (dashed = picks)")
    fig2.tight_layout()
    out2 = os.path.join(ASSETS, f"ff_{key}_overview.png")
    fig2.savefig(out2, dpi=110)
    print("wrote", out2)


if __name__ == "__main__":
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    main()
