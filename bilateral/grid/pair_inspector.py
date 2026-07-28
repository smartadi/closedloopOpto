#!/usr/bin/env python
"""pair_inspector.py — everything about ONE (stim site -> readout) pair, both amplitudes.

Opened by `interactive_grid.py` on the second click of the two-click flow:
click 1 on the SELECTOR map picks the stim site S, click 2 picks the readout. The readout can
be either of two things, and the four panels are the same for both:

  * a GRID SITE  (left-click a node on the efferent map)  -> `show(S, R, ai)`
  * ANY PIXEL    (right-click anywhere on the selector map) -> `show_pixel(S, cx, cy, ai)`
    The stim must stay on the grid — that is where the laser went — but the readout is only an
    ROI choice. Pixel fits are computed on the fly from the cached SVD basis (`pixel_probe`).

  A  does the response scale with laser power?   trial mean +/-SEM at amp 1.0 and 2.0,
     with the INDEPENDENT per-amp TF fits overlaid (dashed), and t* marked.
  B  site mode: is it amplitude-LINEAR? the SHARED fit (one h(t), amp as input, forces x2) —
     its systematic residual IS the saturation, not a misfit.
     pixel mode: WHERE is this pixel? the full-frame dF/F snapshot for this stim site with the
     ROI box drawn on it (the SVD "pixel viewer" display).
  C  which timescale carries the response?       the fitted modes drawn one by one
     (A*exp(-t/tau)*sin(om*t+ph)), labelled with tau and om/2pi, plus a CANCELLATION factor:
     sum|A| / peak. Large values mean the modes cancel and the individual tau are not
     separately identifiable even though their sum fits.
  D  is the mean trustworthy?                    single-trial raster at the display amp.

The s-plane pole/zero panel and the population dose-response scatter were dropped on request
(2026-07-28). Their content survives in the numeric report: the poles and zeros are listed per
amplitude, and the population's focal dose-response slope sits next to this pair's own ratio.

Reads cached fits — no network:
  data/grid_tf_fits_2amp.npz          independent TF per amp   (tf_fit.py 2amp)
  data/grid_tf_fits_shared_gglob.npz  shared TF, amp as input  (tf_fit.py shared, optional)
  data/grid_cross_response_2amp.npz   trial counts for the SEM
  data/grid_trials_2amp.npz           single trials            (cross_response.py 2amp)
  data/grid_svd_<subj>_<date>_n50.npz SVD basis, pixel mode only (svd_cache.py)

Standing caveat, called out on the figure: under the damped-sinusoid model an in-sample R2 of
~0.8 is reachable on pure noise, so gate on the held-out CV-R2 (> 0), never on R2. When the
display amp's CV-R2 <= 0 the report says so in red: read the data panels (A, D), not the model
ones (B, C).
"""
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt

import config as cfg
import cross_response as cr
import tf_fit

DATA = Path(__file__).resolve().parents[2] / "data"
TF2 = DATA / "grid_tf_fits_2amp.npz"
XR2 = DATA / "grid_cross_response_2amp.npz"
SHARED = ["grid_tf_fits_shared_gglob.npz", "grid_tf_fits_shared.npz"]

AC = ["#1f77b4", "#d62728"]          # amp colours: low, high
POP_TAU_RATIO = 0.965                # population median tau2/tau1 (2026-07-17, 61 good pairs)
POP_GAIN_RATIO = 1.37                # population median focal |gain| ratio amp2/amp1


# --------------------------------------------------------------------------- #
# TF algebra
# --------------------------------------------------------------------------- #
def poles_zeros(tau, A, om=None, ph=None):
    """Poles and zeros of the fitted TF, in 1/s.

    osc modes (om supplied): mode i is A_i*exp(-t/tau_i)*sin(om_i*t + ph_i), i.e. a
    complex-conjugate pole pair at -1/tau_i +- j*om_i with numerator
    A_i*[sin(ph_i)*s + (sin(ph_i)/tau_i + om_i*cos(ph_i))] over (s+1/tau_i)^2 + om_i^2.
    real modes (om None/NaN): poles -1/tau_i, numerator A_i.
    Zeros = roots of the numerator sum over the common denominator.
    """
    m = ~np.isnan(tau)
    tau, A = np.asarray(tau)[m], np.asarray(A)[m]
    a = 1.0 / tau
    has_osc = om is not None and np.any(np.isfinite(np.asarray(om)[m]))
    if not has_osc:
        if len(a) <= 1:
            return -a, np.array([])
        nco = np.zeros(len(a))
        for i in range(len(a)):
            nco = np.polyadd(nco, A[i] * np.poly(-np.delete(a, i)))
        return -a, np.roots(nco)

    om, ph = np.asarray(om)[m], np.asarray(ph)[m]
    dens = [np.array([1.0, 2 * ai, ai * ai + oi * oi]) for ai, oi in zip(a, om)]
    nums = [np.array([Ai * np.sin(pi), Ai * (np.sin(pi) * ai + oi * np.cos(pi))])
            for Ai, ai, oi, pi in zip(A, a, om, ph)]
    total = np.array([0.0])
    for i in range(len(a)):
        term = nums[i]
        for j in range(len(a)):
            if j != i:
                term = np.polymul(term, dens[j])
        total = np.polyadd(total, term)
    poles = np.concatenate([[-ai + 1j * oi, -ai - 1j * oi] for ai, oi in zip(a, om)])
    zeros = np.roots(total) if np.any(np.abs(total) > 1e-30) else np.array([])
    return poles, zeros


def dominant_tau(tau_vec, A_vec):
    """Time constant carrying the largest-magnitude residue — the pole that sets the shape.
    (Same rule as tf_matrix._dominant_tau; duplicated so importing this module does not pull
    in tf_matrix, which forces the Agg backend at import time.)"""
    tau_vec, A_vec = np.asarray(tau_vec), np.asarray(A_vec)
    m = np.isfinite(tau_vec) & np.isfinite(A_vec)
    if not m.any():
        return np.nan
    return float(tau_vec[m][np.argmax(np.abs(A_vec[m]))])


def _fmt_c(v):
    v = complex(v)
    return f"{v.real:.1f}" if abs(v.imag) < 1e-6 else f"{v.real:.1f}{v.imag:+.1f}j"


def _load(p):
    z = np.load(p, allow_pickle=True)
    return {k: z[k] for k in z.files}


def matched_time(window, h_hi):
    """Index/time of the high-amp |peak| INSIDE the fit window — the time at which every amp
    is compared. Signed per-amp peaks can land on different lobes of a biphasic response
    (excitatory ~70 ms, suppression ~140-240 ms), which makes a raw gain ratio meaningless."""
    fit = (window >= 0) & (window <= tf_fit.FIT_TMAX)
    ixf = np.where(fit)[0]
    k = int(np.nanargmax(np.abs(np.nan_to_num(h_hi[fit]))))
    return int(ixf[k]), float(window[ixf[k]])


# --------------------------------------------------------------------------- #
class PairInspector:
    """Holds the caches + one reusable figure; `show`/`show_pixel` redraw it in place."""

    def __init__(self, xlim=(-0.5, 1.0), trials=None, live=True):
        if not TF2.exists():
            raise FileNotFoundError(f"{TF2} missing — run `python tf_fit.py 2amp` first")
        self.Z = _load(TF2)
        self.sites = self.Z["sites"]
        self.window = self.Z["window"]
        self.amps = [float(a) for a in self.Z["amps"]]
        self.ZS, self.shared_name = self._load_shared()
        self.tz = trials if trials is not None else cr.load_trials2()
        self.ntri = np.load(XR2)["ntri"] if XR2.exists() else None   # (nA, nS), lazy key read
        self.xlim, self.live = xlim, live
        self.fig = None
        self.sv = None                                    # SVD basis, loaded on first pixel use
        self.pop = self._population()

    # -- data ---------------------------------------------------------------
    def _load_shared(self):
        for n in SHARED:
            if (DATA / n).exists():
                return _load(DATA / n), n
        return None, None

    def _matched_gain_all(self):
        """Matched-time dF/F for EVERY site pair -> (gm (nA,nS,nS), tstar (nS,nS))."""
        H, W = self.Z["H"], self.window
        fit = (W >= 0) & (W <= tf_fit.FIT_TMAX)
        ixf = np.where(fit)[0]
        k = np.nanargmax(np.abs(np.nan_to_num(H[-1][..., fit])), axis=-1)
        ix = ixf[k]
        I, J = np.indices(k.shape)
        return H[:, I, J, ix], W[ix]

    def _population(self):
        """Cross-pair reference numbers every pair is compared against."""
        cv = self.Z["cvr2"]
        nS = len(self.sites)
        gm, tstar = self._matched_gain_all()
        ok = np.all(cv > 0, 0)                       # generalizes at BOTH amps
        foc = np.eye(nS, dtype=bool) & ok            # on-site (focal) pairs — the honest set
        x, y = gm[0][foc], gm[1][foc]
        slope = float((x * y).sum() / (x * x).sum()) if x.size else np.nan
        with np.errstate(divide="ignore", invalid="ignore"):
            ratio = float(np.nanmedian(np.abs(y) / np.abs(x))) if x.size else np.nan
        return dict(ok=ok, foc=foc, slope=slope, ratio=ratio, n_ok=int(ok.sum()),
                    gm=gm, tstar=tstar)

    def lab(self, j):
        return f"({self.sites[j,0]:+.1f},{self.sites[j,1]:+.0f})"

    # -- packs: turn a readout choice into the common panel input ------------
    def _pack_site(self, S, R, ai):
        Z, nA = self.Z, len(self.amps)
        d = float(np.hypot(*(self.sites[R] - self.sites[S])))
        P = dict(
            ai=ai, amps=self.amps, window=self.window, mode="site",
            H=Z["H"][:, S, R], yhat=Z["yhat"][:, S, R], Hstd=Z["Hstd"][:, S, R],
            ntri=(self.ntri[:, S] if self.ntri is not None else np.full(nA, np.nan)),
            order=Z["order"][:, S, R], r2=Z["r2"][:, S, R], cvr2=Z["cvr2"][:, S, R],
            gain=Z["gain"][:, S, R], tau=Z["tau"][:, S, R], A=Z["A"][:, S, R],
            om=Z["om"][:, S, R], ph=Z["ph"][:, S, R],
            tstar=float(self.pop["tstar"][S, R]),
            gm=np.array([self.pop["gm"][a, S, R] for a in range(nA)]),
            raster=lambda a, S=S, R=R: cr.extract_trials_amp(self.tz, S, R, self.amps[a])[0],
            title=(f"PAIR  stim {self.lab(S)}  →  readout {self.lab(R)}   ({d:.1f} mm apart)"),
            fitted="cached (tf_fit.py 2amp)",
        )
        if self.ZS is not None:
            P["B"] = dict(kind="shared", H=self.ZS["H"][:, S, R], yhat=self.ZS["yhat"][:, S, R],
                          gamma=float(self.ZS["gamma"][S, R]) if "gamma" in self.ZS else np.nan,
                          name=self.shared_name)
        else:
            P["B"] = dict(kind="none", msg="no shared-fit cache\n\nrun:  python tf_fit.py shared")
        return P

    def _pack_pixel(self, S, cx, cy, ai):
        """Readout = an arbitrary pixel ROI. Fits are computed here, on the fly."""
        import pixel_probe as pp
        if self.sv is None:
            self.sv = pp.load()
        W, nA = self.window, len(self.amps)
        ts, meta = pp.pixel_series(self.sv, cx, cy)
        H = np.full((nA, len(W)), np.nan)
        yhat = np.zeros((nA, len(W)))
        Hstd = np.zeros((nA, len(W)))
        nmax = self.Z["tau"].shape[-1]
        tau = np.full((nA, nmax), np.nan); Amp = np.full((nA, nmax), np.nan)
        om = np.full((nA, nmax), np.nan); ph = np.full((nA, nmax), np.nan)
        order = np.zeros(nA, int); r2 = np.full(nA, np.nan); cvr2 = np.full(nA, np.nan)
        gain = np.full(nA, np.nan); ntri = np.zeros(nA, int)
        base_ix = int(self.tz["base_ix"])
        dffs = []
        for a in range(nA):
            fluo = pp.trial_fluo(self.tz, ts, self.sv["svdT"], S, self.amps[a])
            ntri[a] = fluo.shape[0]
            if fluo.shape[0] == 0:
                dffs.append(np.zeros((0, len(W))))
                continue
            f, h, dff = pp.fit_pixel(W, fluo, base_ix)
            dffs.append(dff)
            H[a] = h
            Hstd[a] = np.nanstd(dff, 0)
            if f is None:
                continue
            yhat[a] = tf_fit._impulse(W, f["theta"], f["A"], f["tau"], f["om"], f["ph"])
            order[a], r2[a] = f["order"], f["r2"]
            cvr2[a] = f.get("cvr2", np.nan)
            gain[a] = f["gain"]
            o = np.argsort(f["tau"]); n = len(o)
            tau[a, :n] = np.asarray(f["tau"])[o]; Amp[a, :n] = np.asarray(f["A"])[o]
            if f["om"] is not None:
                om[a, :n] = np.asarray(f["om"])[o]; ph[a, :n] = np.asarray(f["ph"])[o]
        ix, ts_star = matched_time(W, H[-1])
        ml, ap = pp.px_to_mm(cx, cy)
        return dict(
            ai=ai, amps=self.amps, window=W, mode="pixel",
            H=H, yhat=yhat, Hstd=Hstd, ntri=ntri, order=order, r2=r2, cvr2=cvr2,
            gain=gain, tau=tau, A=Amp, om=om, ph=ph,
            tstar=ts_star, gm=H[:, ix],
            raster=lambda a, d=dffs: d[a],
            title=(f"PAIR  stim {self.lab(S)}  →  PIXEL ({int(cx)},{int(cy)}) px = "
                   f"({ml:+.1f},{ap:+.1f}) mm   [ROI ±{meta['rad']} px]"),
            fitted="on the fly (pixel ROI, split-half CV)",
            B=dict(kind="snapshot", img=pp.snapshot(self.sv, self.tz, S, self.amps[ai]),
                   box=meta["box"], site=(cfg.BREGMA_PX[0] + self.sites[S, 0] * cfg.PX_PER_MM_X,
                                          cfg.BREGMA_PX[1] + self.sites[S, 1] * cfg.PX_PER_MM_Y),
                   amp=self.amps[ai]),
        )

    # -- figure -------------------------------------------------------------
    def _figure(self):
        if self.fig is not None and plt.fignum_exists(self.fig.number):
            for ax in self.axs.values():
                ax.clear(); ax.set_axis_on()
            self.txt.clear(); self.txt.axis("off")
            for cb in self._cbars:
                try:
                    cb.remove()
                except Exception:
                    pass
            self._cbars = []
            return
        fig = plt.figure(figsize=(13.0, 9.4))
        gs = fig.add_gridspec(3, 2, height_ratios=[1.0, 1.0, 0.62], hspace=0.42, wspace=0.20,
                              left=0.065, right=0.955, top=0.90, bottom=0.03)
        self.fig = fig
        self.axs = {k: fig.add_subplot(gs[i // 2, i % 2]) for i, k in enumerate("ABCD")}
        self.txt = fig.add_subplot(gs[2, :]); self.txt.axis("off")
        self._cbars = []
        if self.live:
            fig.show()

    def show(self, S, R, ai=None):
        """Grid-site readout."""
        ai = len(self.amps) - 1 if ai is None else int(ai)
        self._render(self._pack_site(S, R, ai))

    def show_pixel(self, S, cx, cy, ai=None):
        """Arbitrary-pixel readout (fits computed on the fly)."""
        ai = len(self.amps) - 1 if ai is None else int(ai)
        self._render(self._pack_pixel(S, cx, cy, ai))

    def _render(self, P):
        self._figure()
        self._panel_data(self.axs["A"], P)
        self._panel_B(self.axs["B"], P)
        self._panel_modes(self.axs["C"], P)
        self._panel_raster(self.axs["D"], P)
        self._panel_text(P)
        self.fig.suptitle(f"{P['title']}   ·   AL_0048 {cfg.DATE} grid, amps {P['amps']}"
                          f"   ·   display amp {P['amps'][P['ai']]:.1f}", fontsize=12, y=0.975)
        self.fig.canvas.draw_idle()

    # -- panels -------------------------------------------------------------
    def _panel_data(self, ax, P):
        """A — trial mean +/-SEM at every amp, independent per-amp TF fits dashed."""
        W = P["window"]
        ax.axvline(P["tstar"], c="0.35", lw=0.8, ls=":", zorder=0)
        for a, c in zip(range(len(P["amps"])), AC):
            h = P["H"][a]
            n = P["ntri"][a]
            if np.isfinite(n) and n > 0:
                sem = P["Hstd"][a] / np.sqrt(max(int(n), 1))
                ax.fill_between(W, h - sem, h + sem, color=c, alpha=0.18, lw=0)
            ax.plot(W, h, c=c, lw=1.6, label=f"amp {P['amps'][a]:.1f}  data")
            ax.plot(W, P["yhat"][a], c=c, lw=1.1, ls="--",
                    label=f"amp {P['amps'][a]:.1f}  fit (CV-R² {P['cvr2'][a]:+.2f})")
        self._decorate(ax, P, f"A  data + INDEPENDENT fit per amp   (band = ±SEM, "
                              f"dotted = t* {P['tstar']*1000:.0f} ms)")
        ax.legend(fontsize=6.5, loc="upper right", framealpha=0.9)

    def _panel_B(self, ax, P):
        """B — shared amp-as-input fit (site mode) or the full-frame SVD snapshot (pixel)."""
        B = P["B"]
        if B["kind"] == "none":
            ax.text(0.5, 0.5, B["msg"], ha="center", va="center", transform=ax.transAxes,
                    fontsize=9, color="0.4")
            ax.set_title("B  SHARED fit (amp = input)", fontsize=9.5); ax.axis("off")
            return
        if B["kind"] == "shared":
            W = P["window"]
            for a, c in zip(range(len(P["amps"])), AC):
                ax.plot(W, B["H"][a], c=c, lw=1.6, label=f"amp {P['amps'][a]:.1f}  data")
                ax.plot(W, B["yhat"][a], c=c, lw=1.1, ls="--")
            gt = f"   γ={B['gamma']:.2f}" if np.isfinite(B["gamma"]) else ""
            self._decorate(ax, P, f"B  SHARED fit — ONE h(t), amp is the input{gt}\n"
                                  f"   residual = saturation, not misfit   [{B['name']}]")
            ax.legend(fontsize=6.5, loc="upper right", framealpha=0.9)
            return
        # pixel mode: the SVD display — full-frame dF/F for this stim site
        img = B["img"]
        cl = cfg.SPATIAL_CLIM
        im = ax.imshow(img, cmap="RdBu_r", vmin=-cl, vmax=cl, interpolation="nearest")
        x0, x1, y0, y1 = B["box"]
        ax.add_patch(plt.Rectangle((x0, y0), x1 - x0, y1 - y0, fill=False, ec="lime", lw=1.6))
        ax.scatter(*B["site"], s=90, marker="+", c="k", lw=1.6)
        ax.set_xticks([]); ax.set_yticks([])
        ax.set_title(f"B  full-frame dF/F @ amp {B['amp']:.1f}   ({cfg.STIM_WIN[0]*1000:.0f}–"
                     f"{cfg.STIM_WIN[1]*1000:.0f} ms)\n"
                     f"green = readout ROI, + = stim site   (±{cl*100:.0f}%)", fontsize=9.5)
        # horizontal: a right-hand colorbar here lands in panel C's ylabel
        self._cbars.append(self.fig.colorbar(im, ax=ax, orientation="horizontal",
                                             fraction=0.05, pad=0.03))

    def _panel_modes(self, ax, P):
        """D — the fitted modes drawn separately: which timescale carries the response."""
        W, ai = P["window"], P["ai"]
        tau, A, om, ph = P["tau"][ai], P["A"][ai], P["om"][ai], P["ph"][ai]
        m = np.isfinite(tau) & np.isfinite(A)
        ax.plot(W, P["H"][ai], c="0.55", lw=1.3, label="data")
        ax.plot(W, P["yhat"][ai], c="k", lw=1.4, ls="--", label="fit (sum)")
        cmap = plt.get_cmap("viridis")
        idx = np.where(m)[0]
        for k, i in enumerate(idx):
            o = None if not np.isfinite(om[i]) else np.array([om[i]])
            p = None if o is None else np.array([ph[i]])
            y = tf_fit._impulse(W, 0.0, np.array([A[i]]), np.array([tau[i]]), o, p)
            f_hz = om[i] / (2 * np.pi) if np.isfinite(om[i]) else 0.0
            ax.plot(W, y, lw=1.1, c=cmap(k / max(len(idx) - 1, 1) * 0.85),
                    label=f"mode {k+1}: τ={tau[i]*1000:.0f} ms, {f_hz:.1f} Hz")
        # keep the DATA readable: individual modes can be an order of magnitude larger than
        # their sum when they cancel. `cancel` reports that ill-conditioning explicitly —
        # a large value means the individual τ's are not separately identifiable.
        peak = max(float(np.nanmax(np.abs(P["yhat"][ai]))),
                   float(np.nanmax(np.abs(np.nan_to_num(P["H"][ai])))), 1e-6)
        cancel = float(np.nansum(np.abs(A[m]))) / peak
        ax.set_ylim(-3.0 * peak, 3.0 * peak)
        self._decorate(ax, P, f"C  mode decomposition @ amp {P['amps'][ai]:.1f}  "
                              f"(order {int(P['order'][ai])})\n"
                              f"cancellation ×{cancel:.0f}"
                              f"{'  ⚠ individual τ not identifiable' if cancel > 4 else ''}")
        ax.legend(fontsize=6.5, loc="upper right", framealpha=0.9)

    def _panel_raster(self, ax, P):
        """E — every single trial for this pair at the display amp (the averaging check)."""
        ai = P["ai"]
        dff = P["raster"](ai)
        tw = self.tz["window"]
        if dff is None or dff.size == 0:
            ax.text(0.5, 0.5, "no trials at this amp", ha="center", va="center",
                    transform=ax.transAxes); ax.axis("off"); return
        cl = float(np.nanpercentile(np.abs(dff), 98)) or 0.01
        im = ax.imshow(dff, aspect="auto", cmap="RdBu_r", vmin=-cl, vmax=cl,
                       extent=[tw[0], tw[-1], dff.shape[0], 0], interpolation="nearest")
        ax.axvline(0, c="k", lw=0.9)
        ax.set(xlabel="time from stim (s)", ylabel="trial")
        if self.xlim:
            ax.set_xlim(*self.xlim)
        ax.set_title(f"D  single trials @ amp {P['amps'][ai]:.1f}  (n={dff.shape[0]}, "
                     f"±{cl*100:.1f}% scale)", fontsize=9.5)
        self._cbars.append(self.fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02))

    def _panel_text(self, P):
        """Numeric report under the panels — the numbers you would otherwise read off by eye."""
        nA, ai = len(P["amps"]), P["ai"]
        cv, gn, td = P["cvr2"], P["gain"], [dominant_tau(P["tau"][a], P["A"][a])
                                            for a in range(nA)]
        rows = [f"{'':<16}" + "".join(f"{'amp '+format(a,'.1f'):>16}" for a in P["amps"])
                + f"{'ratio hi/lo':>16}{'population':>26}",
                "-" * (16 + 16 * nA + 16 + 26),
                f"{'trials':<16}" + "".join(f"{int(P['ntri'][a]):>16d}" for a in range(nA))
                + f"{'':>16}{P['fitted']:>26}",
                f"{'order':<16}" + "".join(f"{int(P['order'][a]):>16d}" for a in range(nA))
                + f"{'':>16}{'':>26}",
                f"{'R² (in-sample)':<16}" + "".join(f"{P['r2'][a]:>16.3f}" for a in range(nA))
                + f"{'':>16}{'not a quality metric':>26}",
                f"{'CV-R² (held-out)':<16}" + "".join(f"{cv[a]:>+16.3f}" for a in range(nA))
                + f"{'':>16}{'gate on this: >0':>26}"]
        gr = abs(gn[-1]) / abs(gn[0]) if gn[0] else np.nan
        flip = np.sign(gn[0]) != np.sign(gn[-1])
        rows.append(f"{'peak gain':<16}" + "".join(f"{gn[a]:>+16.4f}" for a in range(nA))
                    + f"{gr:>16.2f}"
                    + f"{('⚠ LOBE FLIP — ignore' if flip else 'own-peak, each amp'):>26}")
        gm = [float(v) for v in P["gm"]]
        gmr = abs(gm[-1]) / abs(gm[0]) if gm[0] else np.nan
        rows.append(f"{'dF/F @ t*='+format(P['tstar']*1000,'.0f')+'ms':<16}"
                    + "".join(f"{gm[a]:>+16.4f}" for a in range(nA))
                    + f"{gmr:>16.2f}"
                    + f"{'focal slope '+format(self.pop['slope'],'.2f'):>26}")
        tr = td[-1] / td[0] if td[0] else np.nan
        rows.append(f"{'dominant τ (ms)':<16}"
                    + "".join(f"{td[a]*1000:>16.0f}" for a in range(nA))
                    + f"{tr:>16.2f}" + f"{'LTI: median '+format(POP_TAU_RATIO,'.3f'):>26}")
        for a in range(nA):
            p, z = poles_zeros(P["tau"][a], P["A"][a], P["om"][a], P["ph"][a])
            rows.append(f"{'poles @'+format(P['amps'][a],'.1f')+' (1/s)':<16}  "
                        + ", ".join(_fmt_c(v) for v in p)
                        + ("   |  zeros " + ", ".join(_fmt_c(v) for v in z) if len(z) else ""))
        self.txt.text(0.0, 1.0, "\n".join(rows), family="monospace", fontsize=8,
                      va="top", ha="left", transform=self.txt.transAxes)
        bad = not (cv[ai] > 0)
        note = ("⚠  CV-R² ≤ 0 at the display amp: the fit does not predict held-out trials — "
                "read panels A/E (data), not C/D (model)." if bad else
                f"fit window 0–{tf_fit.FIT_TMAX:g} s (ITI ≈ 0.71 s → beyond ~±0.7 s "
                f"neighbouring stims contaminate the average).")
        if P["mode"] == "pixel":
            note += "   Pixel ROIs are smaller/noisier than site ROIs — expect lower CV-R²."
        self.txt.text(0.0, -0.02, note, fontsize=8.5, va="top", ha="left",
                      color="crimson" if bad else "0.35", transform=self.txt.transAxes)

    def _decorate(self, ax, P, title):
        ax.axhline(0, c="0.7", lw=0.6, ls=":")
        ax.axvline(0, c="red", lw=0.9)
        ax.axvspan(0, tf_fit.FIT_TMAX, color="0.85", alpha=0.35, lw=0, zorder=0)
        ax.set(xlabel="time from stim (s)", ylabel="dF/F")
        if self.xlim:
            ax.set_xlim(*self.xlim)
        ax.set_title(title, fontsize=9.5)


def strongest_pair(Z=None, off_diagonal=False):
    """(S, R) of the largest |peak gain| among pairs that generalize at both amps."""
    Z = _load(TF2) if Z is None else Z
    g = np.abs(Z["gain"][-1])
    g = np.where(np.all(Z["cvr2"] > 0, 0), g, -np.inf)
    if off_diagonal:
        np.fill_diagonal(g, -np.inf)
    S, R = np.unravel_index(int(np.argmax(g)), g.shape)
    return int(S), int(R)


if __name__ == "__main__":
    import sys
    import matplotlib
    save = "save" in sys.argv
    if save:
        matplotlib.use("Agg")
    pi = PairInspector(live=not save)
    S, R = strongest_pair(pi.Z, off_diagonal=True)
    pi.show(S, R)
    if save:
        out = Path(__file__).resolve().parent / "grid_png"
        out.mkdir(exist_ok=True)
        pi.fig.savefig(out / "view_pair_inspector.png", dpi=130)
        print("wrote", out / "view_pair_inspector.png")
    else:
        plt.show()
