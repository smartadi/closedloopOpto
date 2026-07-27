#!/usr/bin/env python
"""pair_inspector.py — everything about ONE (stim site -> readout site) pair, both amplitudes.

Opened by `interactive_grid.py` on the second click of the two-click flow:
click 1 on the SELECTOR map picks the stim site S, click 2 on the EFFERENT map picks the
readout R. This window then answers, for that pair:

  A  does the response scale with laser power?   trial mean +/-SEM at amp 1.0 and 2.0,
     with the INDEPENDENT per-amp TF fits overlaid (dashed).
  B  is it amplitude-LINEAR?                     the SHARED fit (one h(t), amp as input,
     forces x2). Its systematic residual IS the saturation — not a bad fit.
  C  what are the timescales?                    poles/zeros of both amps in the s-plane.
     Amplitude-invariant poles = the LTI check (population median tau ratio 0.965).
  D  which timescale carries the response?       the fitted modes drawn one by one
     (A*exp(-t/tau)*sin(om*t+ph)), labelled with tau and om/2pi.
  E  is the mean trustworthy?                    single-trial raster at the display amp.
  F  where does this pair sit in the population?  peak gain @1.0 vs @2.0 against all pairs,
     with the focal (on-site) dose-response slope.

Reads only cached fits — no network, no refitting:
  data/grid_tf_fits_2amp.npz          independent TF per amp   (tf_fit.py 2amp)
  data/grid_tf_fits_shared_gglob.npz  shared TF, amp as input  (tf_fit.py shared, optional)
  data/grid_cross_response_2amp.npz   trial counts for the SEM
  data/grid_trials_2amp.npz           single trials            (cross_response.py 2amp)

Standing caveat, printed on the figure: under the damped-sinusoid model an in-sample R2 of
~0.8 is reachable on pure noise, so panel C greys itself out when the held-out CV-R2 <= 0.
"""
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt

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
    tau, A = tau[m], A[m]
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
    m = np.isfinite(tau_vec) & np.isfinite(A_vec)
    if not m.any():
        return np.nan
    tv, av = tau_vec[m], A_vec[m]
    return float(tv[np.argmax(np.abs(av))])


def _fmt_c(v):
    v = complex(v)
    return f"{v.real:.1f}" if abs(v.imag) < 1e-6 else f"{v.real:.1f}{v.imag:+.1f}j"


# --------------------------------------------------------------------------- #
def _load(p):
    z = np.load(p, allow_pickle=True)
    return {k: z[k] for k in z.files}


class PairInspector:
    """Holds the caches + one reusable figure; `show(S, R, ai)` redraws it in place."""

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
        self.pop = self._population()

    # -- data ---------------------------------------------------------------
    def _load_shared(self):
        for n in SHARED:
            if (DATA / n).exists():
                return _load(DATA / n), n
        return None, None

    def _matched_gain(self):
        """Every amp's response evaluated at the SAME time — the highest amp's |peak| time
        inside the fit window.

        WHY not the stored `gain`: that is the signed peak of each amp's own fit, and the
        responses are BIPHASIC (excitatory lobe ~70 ms, suppression ~140-240 ms). A pair can
        therefore peak on the positive lobe at one amp and the negative lobe at the other, so
        the raw gain ratio mixes lobes and is meaningless (it also drags the population
        through-origin slope). Matching the time makes the dose-response sign-consistent by
        construction. Returns (gm (nA,nS,nS), t_star (nS,nS)).
        """
        H, W = self.Z["H"], self.window
        fit = (W >= 0) & (W <= tf_fit.FIT_TMAX)
        ixf = np.where(fit)[0]
        k = np.nanargmax(np.abs(np.nan_to_num(H[-1][..., fit])), axis=-1)
        ix = ixf[k]
        I, J = np.indices(k.shape)
        return H[:, I, J, ix], W[ix]

    def _population(self):
        """Cross-pair reference numbers this pair is compared against."""
        cv = self.Z["cvr2"]
        nS = len(self.sites)
        gm, tstar = self._matched_gain()
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

    # -- figure -------------------------------------------------------------
    def _figure(self):
        if self.fig is not None and plt.fignum_exists(self.fig.number):
            for ax in self.axs.values():
                ax.clear()
            self.txt.clear(); self.txt.axis("off")
            return
        fig = plt.figure(figsize=(15.5, 9.2))
        gs = fig.add_gridspec(3, 3, height_ratios=[1.0, 1.0, 0.55], hspace=0.42, wspace=0.24,
                              left=0.055, right=0.985, top=0.90, bottom=0.03)
        self.fig = fig
        self.axs = {k: fig.add_subplot(gs[i // 3, i % 3])
                    for i, k in enumerate("ABCDEF")}
        self.txt = fig.add_subplot(gs[2, :]); self.txt.axis("off")
        if self.live:
            fig.show()

    def show(self, S, R, ai=None):
        """Draw the full inspector for stim site S -> readout site R. `ai` = display amp index."""
        ai = len(self.amps) - 1 if ai is None else int(ai)
        self._figure()
        Z, W = self.Z, self.window
        nA = len(self.amps)
        cv = [float(Z["cvr2"][a, S, R]) for a in range(nA)]
        gn = [float(Z["gain"][a, S, R]) for a in range(nA)]
        td = [dominant_tau(Z["tau"][a, S, R], Z["A"][a, S, R]) for a in range(nA)]

        self._panel_data(self.axs["A"], S, R)
        self._panel_shared(self.axs["B"], S, R)
        self._panel_splane(self.axs["C"], S, R, cv)
        self._panel_modes(self.axs["D"], S, R, ai)
        self._panel_raster(self.axs["E"], S, R, ai)
        self._panel_population(self.axs["F"], S, R, gn)
        self._panel_text(S, R, cv, gn, td, ai)

        d = float(np.hypot(*(self.sites[R] - self.sites[S])))
        self.fig.suptitle(f"PAIR  stim {self.lab(S)}  →  readout {self.lab(R)}"
                          f"   ({d:.1f} mm apart)   ·   AL_0048 2026-07-10 grid,"
                          f" amps {self.amps}   ·   display amp {self.amps[ai]:.1f}",
                          fontsize=12, y=0.975)
        self.fig.canvas.draw_idle()

    # -- panels -------------------------------------------------------------
    def _panel_data(self, ax, S, R):
        """A — trial mean +/-SEM at every amp, independent per-amp TF fits dashed."""
        Z, W = self.Z, self.window
        ax.axvline(self.pop["tstar"][S, R], c="0.35", lw=0.8, ls=":", zorder=0)
        for a, c in zip(range(len(self.amps)), AC):
            h, yh = Z["H"][a, S, R], Z["yhat"][a, S, R]
            if self.ntri is not None:
                sem = Z["Hstd"][a, S, R] / np.sqrt(max(int(self.ntri[a, S]), 1))
                ax.fill_between(W, h - sem, h + sem, color=c, alpha=0.18, lw=0)
            ax.plot(W, h, c=c, lw=1.6, label=f"amp {self.amps[a]:.1f}  data")
            ax.plot(W, yh, c=c, lw=1.1, ls="--",
                    label=f"amp {self.amps[a]:.1f}  fit (CV-R² {Z['cvr2'][a,S,R]:+.2f})")
        self._decorate(ax, f"A  data + INDEPENDENT fit per amp   (band = ±SEM, "
                           f"dotted = t* {self.pop['tstar'][S,R]*1000:.0f} ms)")
        ax.legend(fontsize=6.5, loc="upper right", framealpha=0.9)

    def _panel_shared(self, ax, S, R):
        """B — the shared (amp-as-input) fit: its residual measures saturation."""
        if self.ZS is None:
            ax.text(0.5, 0.5, "no shared-fit cache\n\nrun:  python tf_fit.py shared",
                    ha="center", va="center", transform=ax.transAxes, fontsize=9, color="0.4")
            ax.set_title("B  SHARED fit (amp = input)", fontsize=9.5); ax.axis("off")
            return
        Z, W = self.ZS, self.window
        for a, c in zip(range(len(self.amps)), AC):
            ax.plot(W, Z["H"][a, S, R], c=c, lw=1.6, label=f"amp {self.amps[a]:.1f}  data")
            ax.plot(W, Z["yhat"][a, S, R], c=c, lw=1.1, ls="--")
        g = Z["gamma"][S, R] if "gamma" in Z else np.nan
        gt = f"   γ={float(g):.2f}" if np.isfinite(g) else ""
        self._decorate(ax, f"B  SHARED fit — ONE h(t), amp is the input{gt}\n"
                           f"   residual = saturation, not misfit   [{self.shared_name}]")
        ax.legend(fontsize=6.5, loc="upper right", framealpha=0.9)

    def _panel_splane(self, ax, S, R, cv):
        """C — poles/zeros of both amps. Amplitude-invariant poles = LTI holds."""
        Z = self.Z
        allp, nz_off = [], 0
        for a, c in zip(range(len(self.amps)), AC):
            p, z = poles_zeros(Z["tau"][a, S, R], Z["A"][a, S, R],
                               Z["om"][a, S, R], Z["ph"][a, S, R])
            allp.append(np.asarray(p))
            dim = cv[a] <= 0
            ax.scatter(np.real(p), np.imag(p), marker="x", s=90, lw=2.0, c=c,
                       alpha=0.25 if dim else 1.0, label=f"amp {self.amps[a]:.1f} poles")
            if len(z):
                ax.scatter(np.real(z), np.imag(z), marker="o", s=60, facecolors="none",
                           edgecolors=c, lw=1.6, alpha=0.25 if dim else 1.0)
        # scale to the POLES: zeros routinely sit hundreds of 1/s out and would squash the
        # pole cluster (which is the thing being compared across amps) into the axis edge.
        pp = np.concatenate(allp) if allp else np.array([0j])
        xr = max(float(np.max(np.abs(np.real(pp)))) * 1.35, 5.0)
        yr = max(float(np.max(np.abs(np.imag(pp)))) * 1.35, 5.0)
        for a in range(len(self.amps)):
            _, z = poles_zeros(Z["tau"][a, S, R], Z["A"][a, S, R],
                               Z["om"][a, S, R], Z["ph"][a, S, R])
            nz_off += int(np.sum((np.abs(np.real(z)) > xr) | (np.abs(np.imag(z)) > yr)))
        ax.set_xlim(-xr, 0.45 * xr); ax.set_ylim(-yr, yr)
        ax.axvline(0, c="k", lw=0.8); ax.axhline(0, c="0.7", lw=0.6, ls=":")
        ax.set(xlabel="Re  (1/s)   ← faster decay", ylabel="Im  (rad/s)")
        ax.grid(alpha=0.25)
        bad = [f"{self.amps[a]:.1f}" for a in range(len(self.amps)) if cv[a] <= 0]
        sub = f"   ⚠ CV-R²≤0 at amp {', '.join(bad)} — faded, do not trust" if bad else \
              (f"   ({nz_off} zero(s) off-scale)" if nz_off else "")
        ax.set_title("C  s-plane: × poles, ○ zeros\n"
                     f"overlap ⇒ amplitude-invariant dynamics{sub}", fontsize=9.5)
        ax.legend(fontsize=6.5, loc="best", framealpha=0.9)

    def _panel_modes(self, ax, S, R, ai):
        """D — the fitted modes drawn separately: which timescale carries the response."""
        Z, W = self.Z, self.window
        tau, A = Z["tau"][ai, S, R], Z["A"][ai, S, R]
        om, ph = Z["om"][ai, S, R], Z["ph"][ai, S, R]
        m = np.isfinite(tau) & np.isfinite(A)
        ax.plot(W, Z["H"][ai, S, R], c="0.55", lw=1.3, label="data")
        ax.plot(W, Z["yhat"][ai, S, R], c="k", lw=1.4, ls="--", label="fit (sum)")
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
        peak = max(float(np.nanmax(np.abs(Z["yhat"][ai, S, R]))),
                   float(np.nanmax(np.abs(Z["H"][ai, S, R]))), 1e-6)
        cancel = float(np.nansum(np.abs(A[m]))) / peak
        ax.set_ylim(-3.0 * peak, 3.0 * peak)
        self._decorate(ax, f"D  mode decomposition @ amp {self.amps[ai]:.1f}  "
                           f"(order {int(Z['order'][ai,S,R])})\n"
                           f"cancellation ×{cancel:.0f}"
                           f"{'  ⚠ individual τ not identifiable' if cancel > 4 else ''}")
        ax.legend(fontsize=6.5, loc="upper right", framealpha=0.9)

    def _panel_raster(self, ax, S, R, ai):
        """E — every single trial for this pair at the display amp (the averaging check)."""
        dff, mean = cr.extract_trials_amp(self.tz, S, R, self.amps[ai])
        tw = self.tz["window"]
        if dff.size == 0:
            ax.text(0.5, 0.5, "no trials at this amp", ha="center", va="center",
                    transform=ax.transAxes); ax.axis("off"); return
        cl = float(np.nanpercentile(np.abs(dff), 98)) or 0.01
        im = ax.imshow(dff, aspect="auto", cmap="RdBu_r", vmin=-cl, vmax=cl,
                       extent=[tw[0], tw[-1], dff.shape[0], 0], interpolation="nearest")
        ax.axvline(0, c="k", lw=0.9)
        ax.set(xlabel="time from stim (s)", ylabel="trial")
        if self.xlim:
            ax.set_xlim(*self.xlim)
        ax.set_title(f"E  single trials @ amp {self.amps[ai]:.1f}  (n={dff.shape[0]}, "
                     f"±{cl*100:.1f}% scale)", fontsize=9.5)
        self.fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02)

    def _panel_population(self, ax, S, R, gn):
        """F — this pair's dose-response against every pair's, at MATCHED time t*."""
        g, ok, foc = self.pop["gm"], self.pop["ok"], self.pop["foc"]
        ax.scatter(g[0][ok], g[1][ok], s=8, c="0.75", lw=0, label=f"all pairs CV-R²>0 "
                                                                 f"(n={self.pop['n_ok']})")
        ax.scatter(g[0][foc], g[1][foc], s=26, c="darkorange", ec="0.3", lw=0.4,
                   label=f"focal / on-site (n={int(foc.sum())})")
        lim = float(np.nanpercentile(np.abs(g[:, ok]), 99.5)) * 1.15
        xs = np.array([-lim, lim])
        ax.plot(xs, xs, c="0.4", ls=":", lw=1.0, label="identity (×1)")
        ax.plot(xs, 2 * xs, c="0.4", ls="--", lw=1.0, label="strict linear (×2)")
        if np.isfinite(self.pop["slope"]):
            ax.plot(xs, self.pop["slope"] * xs, c="green", lw=1.2,
                    label=f"focal slope {self.pop['slope']:.2f}")
        gx, gy = g[0][S, R], g[1][S, R]
        ax.axhline(gy, c="red", lw=0.7, ls=":", zorder=4)      # crosshair: readable even if
        ax.axvline(gx, c="red", lw=0.7, ls=":", zorder=4)      # the legend covers the marker
        ax.scatter([gx], [gy], s=210, marker="*", c="red", ec="k", lw=0.6, zorder=5,
                   label="this pair")
        ax.axhline(0, c="0.8", lw=0.6); ax.axvline(0, c="0.8", lw=0.6)
        ax.set(xlim=(-lim, lim), ylim=(-lim, lim), aspect="equal",
               xlabel=f"dF/F @ t*, amp {self.amps[0]:.1f}",
               ylabel=f"dF/F @ t*, amp {self.amps[-1]:.1f}")
        ax.set_title("F  amplitude scaling at MATCHED time t* — pair vs population",
                     fontsize=9.5)
        ax.legend(fontsize=6.0, loc="lower right", framealpha=0.9)

    def _panel_text(self, S, R, cv, gn, td, ai):
        """Numeric report under the panels — the numbers you would otherwise read off by eye."""
        Z = self.Z
        nA = len(self.amps)
        rows = []
        rows.append(f"{'':<16}" + "".join(f"{'amp '+format(a,'.1f'):>16}" for a in self.amps)
                    + f"{'ratio hi/lo':>16}{'population':>26}")
        rows.append("-" * (16 + 16 * nA + 16 + 26))
        rows.append(f"{'order':<16}" + "".join(f"{int(Z['order'][a,S,R]):>16d}" for a in range(nA))
                    + f"{'':>16}{'':>26}")
        rows.append(f"{'R² (in-sample)':<16}"
                    + "".join(f"{Z['r2'][a,S,R]:>16.3f}" for a in range(nA))
                    + f"{'':>16}{'not a quality metric':>26}")
        rows.append(f"{'CV-R² (held-out)':<16}" + "".join(f"{cv[a]:>+16.3f}" for a in range(nA))
                    + f"{'':>16}" + f"{'gate on this: >0':>26}")
        gr = abs(gn[-1]) / abs(gn[0]) if gn[0] else np.nan
        flip = np.sign(gn[0]) != np.sign(gn[-1])
        rows.append(f"{'peak gain':<16}" + "".join(f"{gn[a]:>+16.4f}" for a in range(nA))
                    + f"{gr:>16.2f}"
                    + f"{('⚠ LOBE FLIP — ignore' if flip else 'own-peak, each amp'):>26}")
        gm, ts = self.pop["gm"], self.pop["tstar"][S, R]
        gmv = [float(gm[a, S, R]) for a in range(nA)]
        gmr = abs(gmv[-1]) / abs(gmv[0]) if gmv[0] else np.nan
        rows.append(f"{'dF/F @ t*='+format(ts*1000,'.0f')+'ms':<16}"
                    + "".join(f"{gmv[a]:>+16.4f}" for a in range(nA))
                    + f"{gmr:>16.2f}" + f"{'focal median '+format(POP_GAIN_RATIO,'.2f'):>26}")
        tr = td[-1] / td[0] if td[0] else np.nan
        rows.append(f"{'dominant τ (ms)':<16}"
                    + "".join(f"{td[a]*1000:>16.0f}" for a in range(nA))
                    + f"{tr:>16.2f}" + f"{'LTI: median '+format(POP_TAU_RATIO,'.3f'):>26}")
        for a in range(nA):
            p, z = poles_zeros(Z["tau"][a, S, R], Z["A"][a, S, R],
                               Z["om"][a, S, R], Z["ph"][a, S, R])
            rows.append(f"{'poles @'+format(self.amps[a],'.1f')+' (1/s)':<16}  "
                        + ", ".join(_fmt_c(v) for v in p)
                        + ("   |  zeros " + ", ".join(_fmt_c(v) for v in z) if len(z) else ""))
        self.txt.text(0.0, 1.0, "\n".join(rows), family="monospace", fontsize=8,
                      va="top", ha="left", transform=self.txt.transAxes)
        note = ("⚠  CV-R² ≤ 0 at the display amp: the fit does not predict held-out "
                "trials — read panels A/E (data), not C/D (model).") if cv[ai] <= 0 else \
               (f"fit window 0–{tf_fit.FIT_TMAX:g} s (ITI ≈ 0.71 s → beyond ~±0.7 s "
                f"neighbouring stims contaminate the average).")
        self.txt.text(0.0, -0.02, note, fontsize=8.5, va="top", ha="left",
                      color="crimson" if cv[ai] <= 0 else "0.35",
                      transform=self.txt.transAxes)

    def _decorate(self, ax, title):
        ax.axhline(0, c="0.7", lw=0.6, ls=":")
        ax.axvline(0, c="red", lw=0.9)
        ax.axvspan(0, tf_fit.FIT_TMAX, color="0.85", alpha=0.35, lw=0, zorder=0)
        ax.set(xlabel="time from stim (s)", ylabel="dF/F")
        if self.xlim:
            ax.set_xlim(*self.xlim)
        ax.set_title(title, fontsize=9.5)


def strongest_pair(Z=None):
    """(S, R) of the largest |peak gain| among pairs that generalize at both amps — a
    sensible default pair for a headless render."""
    Z = _load(TF2) if Z is None else Z
    g = np.abs(Z["gain"][-1])
    g = np.where(np.all(Z["cvr2"] > 0, 0), g, -np.inf)
    S, R = np.unravel_index(int(np.argmax(g)), g.shape)
    return int(S), int(R)


if __name__ == "__main__":
    import sys
    import matplotlib
    save = "save" in sys.argv
    if save:
        matplotlib.use("Agg")
    pi = PairInspector(live=not save)
    S, R = strongest_pair(pi.Z)
    pi.show(S, R)
    if save:
        out = Path(__file__).resolve().parent / "grid_png"
        out.mkdir(exist_ok=True)
        pi.fig.savefig(out / "view_pair_inspector.png", dpi=130)
        print("wrote", out / "view_pair_inspector.png")
    else:
        plt.show()
