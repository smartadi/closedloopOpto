"""
build_cam_movies.py — extract true face (motion) + eye (pupil) movies from the raw
session camera videos on the server, synced to each trial window, aligned to the
demo_data.npz trial order.

Cameras: face.mp4 (448x560) and eye.mp4 (336x488), both 30-fps container but ~69-fps
real acquisition; frameTimes.timestamps.npy gives each frame's Timeline-clock time.
A trial onset (stimStarts, Timeline sec) maps to camera frame index by that timeline.

MUST be run via PowerShell (the \\sahale UNC share is only visible in that context):
  powershell> & .venv\Scripts\python.exe presentation\build_cam_movies.py --poc
  powershell> & .venv\Scripts\python.exe presentation\build_cam_movies.py

Output: presentation/assets/cam_movies.npz  (FACE, EYE uint8 stacks, demo-order)
"""
import argparse
import os
import subprocess
import numpy as np
import scipy.io as sio
import imageio_ffmpeg

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")
# m5 = AL_0033 2025-03-04 seq 1 — clean face + eye (pupil) videos.
SRV = r"\\sahale.biostr.washington.edu\data\Subjects\AL_0033\2025-03-04\1"
FACE_MP4 = os.path.join(SRV, "face.mp4")
EYE_MP4 = os.path.join(SRV, "eye.mp4")
FF = imageio_ffmpeg.get_ffmpeg_exe()

NCAM = 48                    # frames stored per trial per camera
FACE_W, FACE_H = 76, 88      # face.mp4 is 416x582
# m5's dedicated eye.mp4 (320x484) has a clear pupil — use it directly, light crop
# to centre the eye and drop fur edges.
EYE_CROP = (20, 40, 280, 400)   # x, y, w, h in the 320x484 eye frame
EYE_W, EYE_H = 96, 82           # output size
CONTAINER_FPS = 30.0            # nominal container fps (real acq ~69 fps; index-mapped)


def grab_window(video, W, H, ft, t0, t1, crop=None):
    """Extract the [t0,t1]-Timeline-sec window from *video*, gray, W x H, then
    resample to NCAM frames. *crop*=(x,y,w,h) crops before scaling."""
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
        return np.zeros((NCAM, H, W), np.uint8)
    a = a[:nf * W * H].reshape(nf, H, W)
    idx = np.linspace(0, nf - 1, NCAM).round().astype(int)
    return a[idx]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--poc", action="store_true", help="one trial -> sync check png")
    args = ap.parse_args()

    D = np.load(os.path.join(ASSETS, "demo_data.npz"), allow_pickle=True)
    TRN = D["TRN"]; LOOP = D["LOOP"].astype(str)
    tm = sio.loadmat(os.path.join(ASSETS, "m5_timing.mat"), squeeze_me=True)
    ss = np.asarray(tm["stimStarts"]).ravel()
    ft = np.load(os.path.join(ASSETS, "server_cache", "frameTimes.timestamps.npy")).ravel()
    print(f"trials={len(TRN)}  stimStarts n={ss.size}  frameTimes n={ft.size}")

    def onset(trn):
        return float(ss[int(trn) - 1])          # nc/wc are 1-based indices into stimStarts

    if args.poc:
        import matplotlib
        matplotlib.use("Agg"); import matplotlib.pyplot as plt
        ti = int(np.where(LOOP == "CL")[0][10])
        t0 = onset(TRN[ti])
        print(f"POC trial idx={ti} TRN={TRN[ti]} onset={t0:.2f}s")
        face = grab_window(FACE_MP4, FACE_W, FACE_H, ft, t0 - 1, t0 + 4)
        eye = grab_window(EYE_MP4, EYE_W, EYE_H, ft, t0 - 1, t0 + 4, crop=EYE_CROP)
        print("face", face.shape, "eye", eye.shape)
        fig, axs = plt.subplots(2, 5, figsize=(12, 6))
        taus = np.linspace(0, NCAM - 1, 5).astype(int)
        tt = np.linspace(-1, 4, NCAM)
        for j, k in enumerate(taus):
            axs[0, j].imshow(face[k], cmap="gray"); axs[0, j].set_title(f"face t={tt[k]:.1f}s"); axs[0, j].axis("off")
            axs[1, j].imshow(eye[k], cmap="gray"); axs[1, j].set_title(f"eye t={tt[k]:.1f}s"); axs[1, j].axis("off")
        plt.tight_layout(); out = os.path.join(ASSETS, "cam_poc.png")
        plt.savefig(out, dpi=95); print("saved", out)
        return

    # Face (motion) full view + eye/pupil crop — both taken from the well-exposed
    # face.mp4 (the dedicated eye.mp4 is too dark). Same camera => already synced.
    FACE = np.zeros((len(TRN), NCAM, FACE_H, FACE_W), np.uint8)
    EYE = np.zeros((len(TRN), NCAM, EYE_H, EYE_W), np.uint8)
    for k, trn in enumerate(TRN):
        t0 = onset(trn)
        FACE[k] = grab_window(FACE_MP4, FACE_W, FACE_H, ft, t0 - 1, t0 + 4)
        EYE[k] = grab_window(EYE_MP4, EYE_W, EYE_H, ft, t0 - 1, t0 + 4, crop=EYE_CROP)
        if k % 10 == 0:
            print(f"  trial {k+1}/{len(TRN)} (TRN {trn}, onset {t0:.1f}s)")
    out = os.path.join(ASSETS, "cam_movies.npz")
    np.savez_compressed(out, FACE=FACE, EYE=EYE, NCAM=NCAM)
    print("wrote", out, f"({os.path.getsize(out)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
