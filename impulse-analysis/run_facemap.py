"""run_facemap.py — produce the missing face_proc.mat for a session, headless.

WHY: the impulse pipeline's motion state is `d.motion.motion_1` (load_experiments:
`mv = d.motion.motion_1(1:2:end)`), which is a FACEMAP output. AL_0048 2026-07-15/1 has
`face.mp4` (4 GB) and `face_ROI.mat` on the server but NO `face_proc.mat` — the face video
was recorded but never processed, so motion looked "unavailable" for that session. This runs
Facemap on it with the same settings the already-processed sessions used, so AL_0048 gets a
motion trace defined identically to AL_0041 / AL_0033.

SETTINGS (read off AL_0041 2025-12-02/1 face_proc.mat): sbin=4, fullSVD=0, save_mat=1,
motSVD only (no movSVD), a single ROI of rtype "motion SVD".

ROI: the face .mp4 is ALREADY CROPPED to the face ROI box (AL_0041: face_ROI [.. 416 414]
and its video is exactly 416x414; AL_0048: face_ROI [.. 448 478], video exactly 448x478), so
the facemap ROI is the frame itself. AL_0041's GUI ROI sat a few px inside the frame edge;
here the default is the full frame (INSET=0). Motion is z-scored per session before use
(`mv_z = zscore(mv)`), so a border difference of a few px does not affect any downstream
comparison — but it is a real difference from AL_0041, so it is stated rather than hidden.

FRAME ALIGNMENT: the face camera is triggered with the widefield, two face frames per
blue frame. AL_0048: 308351 face frames vs 154175 blue frames (2x + 1), which is why the
pipeline takes `motion_1(1:2:end)`.

OUTPUT: written LOCALLY (impulse-analysis/data/) by default, NOT to the lab share — copying
it next to the video on the server is a separate, deliberate step.

Run with the facemap env:
  ~/anaconda3/envs/facemap/python.exe impulse-analysis/run_facemap.py \
      --subject AL_0048 --date 2026-07-15 --exp 1
"""
import argparse
import os
import shutil
import sys
import time

import numpy as np

SERVER = r"//sahale.biostr.washington.edu/data/Subjects"
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")

SBIN = 4          # spatial binning, matches AL_0041
INSET = 0         # px inset from the frame edge for the ROI (video is already the face crop)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject", required=True)
    ap.add_argument("--date", required=True)
    ap.add_argument("--exp", required=True)
    ap.add_argument("--server", default=SERVER)
    ap.add_argument("--sbin", type=int, default=SBIN)
    ap.add_argument("--inset", type=int, default=INSET)
    ap.add_argument("--to-server", action="store_true",
                    help="also copy the result next to the video on the lab share")
    args = ap.parse_args()

    import cv2
    from facemap import process

    expdir = os.path.join(args.server, args.subject, args.date, str(args.exp))
    video = os.path.join(expdir, "face.mp4")
    if not os.path.exists(video):
        sys.exit(f"no face.mp4 at {expdir}")

    cap = cv2.VideoCapture(video)
    nfr = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    Lx = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    Ly = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    cap.release()
    print(f"[facemap] {args.subject} {args.date}/{args.exp}: {nfr} frames, {Lx}x{Ly}, sbin={args.sbin}",
          flush=True)

    i = args.inset
    roi = dict(
        rind=1, rtype="motion SVD", iROI=0, ivid=0,
        color=(151.0, 0.0, 46.0),
        yrange=np.arange(i, Ly - i, dtype=int),
        xrange=np.arange(i, Lx - i, dtype=int),
    )
    os.makedirs(DATA, exist_ok=True)
    proc = dict(sbin=args.sbin, fullSVD=False, save_mat=True, rois=[roi],
                sy=0, sx=0, savepath=DATA)

    t0 = time.time()
    out = process.run([[video]], sbin=args.sbin, motSVD=True, movSVD=False,
                      proc=proc, savepath=DATA)
    print(f"[facemap] done in {(time.time()-t0)/60:.1f} min -> {out}", flush=True)

    # facemap names the output after the video ("face_proc.mat"); make the session explicit
    src_mat = os.path.join(DATA, "face_proc.mat")
    tag_mat = os.path.join(DATA, f"{args.subject}_{args.date}_{args.exp}_face_proc.mat")
    if os.path.exists(src_mat):
        shutil.move(src_mat, tag_mat)
        print(f"[facemap] saved {tag_mat}", flush=True)
        if args.to_server:
            dst = os.path.join(expdir, "face_proc.mat")
            shutil.copyfile(tag_mat, dst)
            print(f"[facemap] copied to the lab share: {dst}", flush=True)
    else:
        print(f"[facemap] WARNING: expected {src_mat}; check what run() wrote", flush=True)


if __name__ == "__main__":
    main()
