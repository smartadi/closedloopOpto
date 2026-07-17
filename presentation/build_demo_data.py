"""
build_demo_data.py — assemble the self-contained bundle for the demo video from
the MATLAB-exported movie bundle (presentation/assets/m10_bundle.mat).

Session: m5 = AL_0033, 2025-03-04 (AL_0033ctrl03041), 60 trials (36 OL / 24 CL),
CL-vs-OL gap ~28%. Chosen for its clean face + eye (pupil) behaviour videos. The
true widefield movie is a low-rank SVD (U_ds + per-trial V windows):
frame = mimg + U_ds @ V[:,tau].

Output: presentation/assets/demo_data.npz
Run:    .venv/Scripts/python.exe presentation/build_demo_data.py
"""
import argparse
import os
import numpy as np
import scipy.io as sio

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "presentation", "assets")

FS = 35.0
NWIN = 176
PRE = 35            # samples before onset (t = -1 s)

# fallback metadata if a bundle lacks the mouse/date/session strings (m5's does)
META = {"m5": ("AL_0033", "2025-03-04", "m5"), "m13": ("AL_0039", "2025-04-20", "m13")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--session", default="m5", help="session key, e.g. m5 or m13")
    ap.add_argument("--bundle", default=None, help="override bundle .mat path")
    ap.add_argument("--out", default=None, help="override output .npz path")
    args = ap.parse_args()
    bundle = args.bundle or os.path.join(ASSETS, f"{args.session}_bundle.mat")
    out = args.out or os.path.join(ASSETS, f"demo_data_{args.session}.npz")
    m = sio.loadmat(bundle)
    U_ds = m["U_ds"].astype(np.float32)                 # (n, n, K)
    mimg = m["mimg_ds"].astype(np.float32)              # (n, n)
    Vnc = m["Vwin_nc"].astype(np.float32)               # (K, 176, N_ol)
    Vwc = m["Vwin_wc"].astype(np.float32)               # (K, 176, N_cl)
    ncD = np.atleast_2d(m["ncDfk"].astype(float))
    wcD = np.atleast_2d(m["wcDfk"].astype(float))
    er_nc = np.atleast_1d(m["er_ncDfk"].astype(float).ravel())
    er_wc = np.atleast_1d(m["er_wcDfk"].astype(float).ravel())
    vr_nc = np.atleast_1d(m["vr_ncDfk"].astype(float).ravel())   # per-trial variance
    vr_wc = np.atleast_1d(m["vr_wcDfk"].astype(float).ravel())
    ncInp = np.atleast_2d(m["ncInp"].astype(float))
    wcInp = np.atleast_2d(m["wcInp"].astype(float))
    ncMot = np.atleast_2d(m["ncmotion"].astype(float))     # (N_ol, 176) z-scored face motion
    wcMot = np.atleast_2d(m["wcmotion"].astype(float))
    nc_idx = np.atleast_1d(m["nc"].astype(int).ravel())
    wc_idx = np.atleast_1d(m["wc"].astype(int).ravel())
    ip = np.atleast_2d(m["input_params"].astype(float))
    REF = float(np.asarray(m["refv"]).ravel()[0])
    DUR = float(np.asarray(m["durv"]).ravel()[0])
    pixel = np.asarray(m["pixel"]).ravel().astype(float)
    ds = int(np.asarray(m["ds"]).ravel()[0])
    n = U_ds.shape[0]
    K = U_ds.shape[2]

    # input_params cols: [trial#, onset, loop, Kp, Ki, Kref, ref_mag, dur]
    gain_by_trial = {int(r[0]): (r[3], r[4], r[5], r[6]) for r in ip}
    print("gain sample (Kp,Ki,Kref,ref):", next(iter(gain_by_trial.values())))

    t = (np.arange(NWIN) - PRE) / FS

    def envelope(x, w=250):
        # sliding-window max = amplitude of the sine/pulse carrier. For a step
        # (non-oscillatory) input this returns the step level unchanged.
        from numpy.lib.stride_tricks import sliding_window_view as swv
        pad = np.pad(np.asarray(x, float), (w // 2, w // 2), mode="edge")
        return swv(pad, w).max(-1)[:len(x)]

    def resamp_inp(row):
        e = envelope(row)                       # laser-command amplitude envelope
        src_t = np.linspace(0, DUR, e.size)
        u = np.interp(t, src_t, e, left=0.0, right=e[-1])
        u[t < 0] = 0.0
        u[t > DUR] = 0.0
        return u

    trials = []
    for i in range(ncD.shape[0]):
        trials.append(dict(n=int(nc_idx[i]), loop="OL", y=ncD[i],
                           u=resamp_inp(ncInp[i]) if i < ncInp.shape[0] else np.zeros(NWIN),
                           mot=ncMot[i] if i < ncMot.shape[0] else np.zeros(NWIN),
                           mse=float(er_nc[i]) if i < er_nc.size else np.nan,
                           var=float(vr_nc[i]) if i < vr_nc.size else np.nan,
                           v=Vnc[:, :, i]))
    for i in range(wcD.shape[0]):
        trials.append(dict(n=int(wc_idx[i]), loop="CL", y=wcD[i],
                           u=resamp_inp(wcInp[i]) if i < wcInp.shape[0] else np.zeros(NWIN),
                           mot=wcMot[i] if i < wcMot.shape[0] else np.zeros(NWIN),
                           mse=float(er_wc[i]) if i < er_wc.size else np.nan,
                           var=float(vr_wc[i]) if i < vr_wc.size else np.nan,
                           v=Vwc[:, :, i]))
    trials.sort(key=lambda tr: tr["n"])

    Y = np.array([tr["y"] for tr in trials])
    U = np.array([tr["u"] for tr in trials])
    LOOP = np.array([tr["loop"] for tr in trials])
    TRN = np.array([tr["n"] for tr in trials])
    MSE = np.array([tr["mse"] for tr in trials])
    VAR = np.array([tr["var"] for tr in trials])       # per-trial variance (%ΔF/F)²
    ERR = Y - REF
    GAIN = np.array([gain_by_trial.get(tr["n"], (np.nan,) * 4) for tr in trials])
    VWIN = np.array([tr["v"] for tr in trials], dtype=np.float32)   # (Ntr, K, 176)
    MOT = np.array([tr["mot"] for tr in trials])                   # (Ntr, 176) face motion

    roi = pixel / ds                                    # ROI in downsampled coords (x, y)

    # metadata: prefer strings stored in the bundle, else the fallback table
    def meta(key, i):
        if key in m and np.asarray(m[key]).size:
            return str(np.asarray(m[key]).ravel()[0])
        return META.get(args.session, ("?", "?", args.session))[i]
    mouse, date, session = meta("mouse", 0), meta("date", 1), meta("session", 2)

    print(f"[{session}] trials={len(trials)}  OL={np.sum(LOOP=='OL')}  CL={np.sum(LOOP=='CL')}  "
          f"movie {n}x{n} K={K}  ROI_ds={roi.round(1)}")
    np.savez_compressed(
        out,
        Y=Y, U=U, ERR=ERR, LOOP=LOOP, TRN=TRN, MSE=MSE, VAR=VAR, GAIN=GAIN, MOT=MOT,
        VWIN=VWIN, U_ds=U_ds.reshape(-1, K), mimg=mimg, roi=roi,
        t_win=t, FS=FS, DUR=DUR, REF=REF, PRE=PRE,
        mouse=mouse, date=date, session=session,
    )
    print("wrote", out, f"({os.path.getsize(out)/1e6:.1f} MB)")


if __name__ == "__main__":
    main()
