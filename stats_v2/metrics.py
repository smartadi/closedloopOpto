"""Per-trial and per-session metrics (SPEC.md section 3)."""
import numpy as np
from scipy import signal, stats

FS = 35.0  # frames/s, as fixed by the spec (the measured frame rate is ~35.09 Hz)

# Inclusive sample ranges relative to the onset frame o.
WINDOWS = {
    "pre": (-105, -1),
    "early": (0, 34),
    "late": (35, 105),
    "full": (0, 105),
    "post_rmse": (106, 140),
    "post_var": (106, 210),
}
PERI = (-70, 104)  # Fig 4D state window [-2, +3) s, 175 samples

# Fig 3 window name -> (window for RMSE, window for variance)
FIG3_WINDOWS = {
    "pre": ("pre", "pre"),
    "early": ("early", "early"),
    "late": ("late", "late"),
    "full": ("full", "full"),
    "post": ("post_rmse", "post_var"),
}


def segment(x, o, rng):
    """x[o+a .. o+b] inclusive; NaN where the window leaves the array."""
    a, b = rng
    idx = o + np.arange(a, b + 1)
    out = np.full(idx.shape, np.nan)
    ok = (idx >= 0) & (idx < len(x))
    out[ok] = x[idx[ok]]
    return out


def rmse(seg, ref):
    return float(np.sqrt(np.mean((seg - ref) ** 2)))


def across_trial_var(mat):
    """mat: trials x samples. Variance across trials (ddof=1) at each sample, averaged over samples."""
    return float(np.mean(np.var(mat, axis=0, ddof=1)))


# ---------------------------------------------------------------- band power ('continuous')
def psd_continuous(x, fs=FS):
    x = signal.detrend(np.asarray(x, dtype=float), type="linear")
    n = len(x)
    w = signal.windows.hann(n, sym=True)
    nfft = max(8192, 1 << int(np.ceil(np.log2(8 * n))))
    X = np.fft.rfft(x * w, nfft)
    P = np.abs(X) ** 2 / (fs * np.sum(w ** 2))
    P[1:-1] *= 2.0  # interior bins doubled (nfft even: last bin is Nyquist)
    f = np.arange(len(P)) * fs / nfft
    return f, P


def bandpower(x, lo, hi, fs=FS):
    f, P = psd_continuous(x, fs)
    inner = (f > lo) & (f < hi)
    ff = np.concatenate([[lo], f[inner], [hi]])
    pp = np.concatenate([[np.interp(lo, f, P)], P[inner], [np.interp(hi, f, P)]])
    return float(np.sum(np.diff(ff) * (pp[1:] + pp[:-1]) / 2.0))


def trial_states(dfk, motion, o, ref, has_motion):
    seg = segment(dfk, o, PERI)
    out = {
        "init_dev": float(abs(dfk[o] - ref)),
        "rel_delta": np.nan,
        "abs_delta": np.nan,
        "motion": np.nan,
    }
    if np.all(np.isfinite(seg)):
        out["rel_delta"] = bandpower(seg, 2, 4) / bandpower(seg, 0.4, 10)
        out["abs_delta"] = float(np.log10(bandpower(seg, 1, 4)))
    if has_motion:
        mseg = segment(motion, o, PERI)
        if np.all(np.isfinite(mseg)):
            out["motion"] = float(np.mean(mseg))
    return out


def ols_slope(x, y):
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    xc = x - x.mean()
    return float(np.sum(xc * (y - y.mean())) / np.sum(xc ** 2))


def zscore(x):
    x = np.asarray(x, float)
    return (x - np.mean(x)) / np.std(x, ddof=1)


# ---------------------------------------------------------------- checks
def runs_test(seq):
    """Wald-Wolfowitz runs test on a 0/1 sequence (normal approximation, two-sided)."""
    seq = np.asarray(seq).astype(int)
    n1 = int(np.sum(seq == 0))
    n2 = int(np.sum(seq == 1))
    n = n1 + n2
    runs = int(1 + np.sum(seq[1:] != seq[:-1]))
    mu = 2.0 * n1 * n2 / n + 1.0
    var = 2.0 * n1 * n2 * (2.0 * n1 * n2 - n) / (n ** 2 * (n - 1))
    z = (runs - mu) / np.sqrt(var)
    p = float(2 * stats.norm.sf(abs(z)))
    return {"runs": runs, "expected_runs": mu, "z": float(z), "p": p}


def rise_offset_frames(t_cmd, cmd, t0, dt_frame, thr=0.05):
    """Laser-command rise relative to t0, in frames.

    Baseline = median command over [t0-1.5, t0-0.5) s; rise = first sample in [t0-0.5, t0+1.0] s
    above baseline + thr (V). Returns NaN if no sample crosses.
    """
    a, b, c = np.searchsorted(t_cmd, [t0 - 1.5, t0 - 0.5, t0 + 1.0])
    base = np.median(cmd[a:b])
    up = np.flatnonzero(cmd[b:c] > base + thr)
    if len(up) == 0:
        return np.nan, base
    return float((t_cmd[b + up[0]] - t0) / dt_frame), float(base)


def cmd_slice(t_cmd, cmd, t0, t1):
    a, b = np.searchsorted(t_cmd, [t0, t1])  # samples with t0 <= t < t1
    return cmd[a:b]


def response_lag(t_cmd, cmd, tb, dfk, max_lag=20, clip=50.0):
    """Alignment check: lag (frames) at which frame-to-frame dFk changes are most negatively
    correlated with frame-to-frame changes of the frame-binned laser command (inhibition).
    Positive lag = dFk responds after the command. Frames with |dFk| >= clip (start-up
    transient) or NaN are excluded from the dFk differences.
    """
    edges = np.searchsorted(t_cmd, tb)
    cs = np.concatenate([[0.0], np.cumsum(cmd)])
    cnt = np.maximum(edges[1:] - edges[:-1], 1)
    u = (cs[edges[1:]] - cs[edges[:-1]]) / cnt  # mean command in [tb[i], tb[i+1])
    du = np.diff(u)
    x = dfk[: len(u)]
    dd = np.diff(x)
    good = np.isfinite(x[:-1]) & np.isfinite(x[1:]) & (np.abs(x[:-1]) < clip) & (np.abs(x[1:]) < clip)
    dd = np.where(good, dd, 0.0)
    lags = np.arange(-max_lag, max_lag + 1)
    r = []
    for lag in lags:
        if lag >= 0:
            a, b = du[: len(du) - lag], dd[lag:]
        else:
            a, b = du[-lag:], dd[: len(dd) + lag]
        r.append(np.corrcoef(a, b)[0, 1])
    r = np.array(r)
    i = int(np.argmin(r))
    return int(lags[i]), float(r[i])
