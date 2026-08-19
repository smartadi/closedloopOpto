"""Draw the graph the GDAR-with-input fits actually end up with.

Reads `data/grid_gdarx_fits.npz` (written by `gdarx_grid.py`) -- no refitting.

    .venv/Scripts/python.exe bilateral/grid/gdarx_graph_fig.py

The headline this figure exists to make unmissable: for every GDAR/GVAR fit the *topology*
is imposed (`lattice_graph`, 8-connectivity + midline bridge) and only the edge WEIGHTS are
learned, so "the learned graph" is a weighting of an assumed lattice, not a discovered one.
The only fit that learns its own support is VARX, and its design is rank deficient -- panel F
is the evidence that its coefficients are noise, not connectivity.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection

DATA = Path(__file__).resolve().parents[2] / "data"
PNG = Path(__file__).resolve().parent / "network_png"
RESULT = DATA / "grid_gdarx_fits.npz"
OUT = PNG / "gdarx_graph.png"


def _edges(adj):
    """Upper-triangle (i, j) index pairs of a symmetric boolean adjacency."""
    ii, jj = np.nonzero(np.triu(np.asarray(adj, bool)))
    return ii, jj


def _draw_nodes(ax, sites, c=None, cmap="viridis", vmin=None, vmax=None, s=70):
    ax.axvline(0, color="0.55", ls="--", lw=0.8, zorder=1)
    kw = dict(s=s, ec="k", lw=0.3, zorder=3)
    if c is None:
        return ax.scatter(sites[:, 0], sites[:, 1], c="0.75", **kw)
    return ax.scatter(sites[:, 0], sites[:, 1], c=c, cmap=cmap, vmin=vmin, vmax=vmax, **kw)


def _tidy(ax, title):
    ax.set_aspect("equal")
    ax.set_xticks([]); ax.set_yticks([])
    ax.set_title(title, fontsize=9)


def _draw_edges(ax, sites, ii, jj, w, vmax, lw_max=3.0):
    """Signed edge weights: colour = signed magnitude (RdBu_r), width proportional to |w|."""
    seg = np.stack([sites[ii], sites[jj]], axis=1)
    lw = 0.25 + lw_max * np.abs(w) / max(vmax, 1e-12)
    lc = LineCollection(seg, array=w, cmap="RdBu_r", norm=plt.Normalize(-vmax, vmax),
                        linewidths=lw, zorder=2)
    ax.add_collection(lc)
    return lc


def main():
    z = np.load(RESULT, allow_pickle=True)
    sites, adj = z["sites"], z["adj"].astype(bool)
    N = len(sites)
    eye = np.eye(N, dtype=bool)
    off = (~eye)
    ii, jj = _edges(adj)
    labels = [str(x) for x in z["row_label"]]
    rho = dict(zip(labels, z["row_rho"]))

    A_gvar = z["A__GVAR__B-free"].sum(-1)     # sum over the 5 lags = the DC propagator
    A_gdar = z["A__GDAR__B-free"].sum(-1)
    A_varx = z["A__VARX_no_graph"].sum(-1)

    # symmetric part of the (non-symmetric) GVAR weights, for drawing one line per edge
    w_gvar = 0.5 * (A_gvar[ii, jj] + A_gvar[jj, ii])
    w_gdar = A_gdar[ii, jj]
    vmax = float(np.percentile(np.abs(w_gvar), 99))

    fig, ax = plt.subplots(2, 3, figsize=(15, 9.2))
    fig.suptitle("What graph do we end up learning?  "
                 "topology is IMPOSED, only the weights are fitted", fontsize=12)

    # --- A: the assumed lattice -------------------------------------------------------
    a = ax[0, 0]
    seg = np.stack([sites[ii], sites[jj]], axis=1)
    a.add_collection(LineCollection(seg, colors="0.65", linewidths=0.8, zorder=2))
    hemi = np.where(sites[:, 0] < 0, 0, 1)
    a.scatter(sites[hemi == 0, 0], sites[hemi == 0, 1], c="tab:green", s=70, ec="k", lw=0.3,
              zorder=3, label="left / excitatory")
    a.scatter(sites[hemi == 1, 0], sites[hemi == 1, 1], c="tab:purple", s=70, ec="k", lw=0.3,
              zorder=3, label="right / inhibitory")
    a.axvline(0, color="0.55", ls="--", lw=0.8, zorder=1)
    n_bridge = int((adj & (np.sign(sites[:, 0])[:, None] != np.sign(sites[:, 0])[None, :])).sum() // 2)
    a.legend(fontsize=7, loc="upper left", frameon=False)
    _tidy(a, f"A. the imposed lattice: 8-connectivity, midline bridged\n"
             f"{len(ii)} edges ({n_bridge} cross the midline) — assumed, not learned")
    a.autoscale_view()

    # --- B: GVAR learned weights ------------------------------------------------------
    a = ax[0, 1]
    lc = _draw_edges(a, sites, ii, jj, w_gvar, vmax)
    sc = _draw_nodes(a, sites, c=np.diag(A_gvar), cmap="viridis")
    cb1 = fig.colorbar(lc, ax=a, fraction=0.045, pad=0.02)
    cb1.set_label("edge  A[i,j]", fontsize=7); cb1.ax.tick_params(labelsize=6)
    cb2 = fig.colorbar(sc, ax=a, fraction=0.045, pad=0.11)
    cb2.set_label("self  A[i,i]", fontsize=7); cb2.ax.tick_params(labelsize=6)
    _tidy(a, f"B. GVAR + B-free (best graph fit)\n"
             f"edge |w| max {np.abs(w_gvar).max():.3f}, self term "
             f"{np.diag(A_gvar).min():.2f}–{np.diag(A_gvar).max():.2f}   rho={rho['GVAR + B-free']:.2f}")
    a.autoscale_view()

    # --- C: GDAR (symmetry-tied) on the SAME scale -------------------------------------
    a = ax[0, 2]
    _draw_edges(a, sites, ii, jj, w_gdar, vmax)
    _draw_nodes(a, sites, c=np.diag(A_gdar), cmap="viridis")
    _tidy(a, f"C. GDAR + B-free — same colour scale as B\n"
             f"symmetry tie crushes coupling: |w| max {np.abs(w_gdar).max():.3f} "
             f"({np.abs(w_gdar).max() / np.abs(w_gvar).max():.0%} of GVAR)")
    a.autoscale_view()

    # --- D: coupling is tiny next to the self term -------------------------------------
    a = ax[1, 0]
    names = ["autonomous", "GDAR + B-free", "GVAR + B-free", "VARX (no graph)"]
    mats = [z["A__autonomous"].sum(-1), A_gdar, A_gvar, A_varx]
    self_t = [np.abs(np.diag(M)).mean() for M in mats]
    coup = [np.sqrt((M[adj] ** 2).mean()) for M in mats]
    x = np.arange(len(names))
    a.bar(x - 0.2, self_t, 0.4, label="mean |self term|", color="0.4")
    a.bar(x + 0.2, coup, 0.4, label="rms on-lattice coupling", color="tab:orange")
    for xi, (s_, c_) in enumerate(zip(self_t, coup)):
        a.text(xi, max(s_, c_) * 1.25, f"{c_ / s_:.1%}", ha="center", fontsize=7)
    a.set_yscale("log"); a.set_xticks(x)
    a.set_xticklabels([n.replace(" + ", "\n+ ").replace(" (", "\n(") for n in names], fontsize=7)
    a.legend(fontsize=7, frameon=False)
    a.set_title("D. A is almost diagonal: coupling as a % of the self term\n"
                "(the graph carries little of the response — hence free-B wins)", fontsize=9)

    # --- E: is the learned coupling directed? ------------------------------------------
    a = ax[1, 1]
    fwd, rev = A_gvar[ii, jj], A_gvar[jj, ii]
    a.axhline(0, color="0.8", lw=0.6); a.axvline(0, color="0.8", lw=0.6)
    lim = 1.05 * max(np.abs(fwd).max(), np.abs(rev).max())
    a.plot([-lim, lim], [-lim, lim], color="0.6", ls="--", lw=0.8, label="symmetric (GDAR assumes this)")
    cross = np.sign(sites[ii, 0]) != np.sign(sites[jj, 0])
    a.scatter(fwd[~cross], rev[~cross], s=14, c="0.35", label="within hemisphere")
    a.scatter(fwd[cross], rev[cross], s=20, c="tab:red", label="crosses the midline")
    r = np.corrcoef(fwd, rev)[0, 1]
    opp = float(np.mean(np.sign(fwd) != np.sign(rev)))
    a.set_xlim(-lim, lim); a.set_ylim(-lim, lim); a.set_aspect("equal")
    a.set_xlabel("A[i,j]  (j -> i)", fontsize=8); a.set_ylabel("A[j,i]  (i -> j)", fontsize=8)
    a.legend(fontsize=6.5, frameon=False, loc="upper left")
    a.set_title(f"E. the learned coupling is DIRECTED\n"
                f"corr(fwd, rev) = {r:+.2f}; {opp:.0%} of edges have opposite signs", fontsize=9)

    # --- F: VARX does not learn a graph -------------------------------------------------
    a = ax[1, 2]
    on, offl = A_varx[adj], A_varx[off & ~adj]
    rms_on, rms_off = float(np.sqrt((on ** 2).mean())), float(np.sqrt((offl ** 2).mean()))
    bins = np.linspace(0, np.percentile(np.abs(np.r_[on, offl]), 99), 40)
    a.hist(np.abs(offl), bins=bins, histtype="step", density=True, color="tab:blue",
           label=f"off-lattice (n={offl.size}), rms {rms_off:.0f}")
    a.hist(np.abs(on), bins=bins, histtype="step", density=True, color="tab:orange",
           label=f"on-lattice (n={on.size}), rms {rms_on:.0f}")
    a.set_xlabel("|sum_k A_k[i,j]|  (VARX)", fontsize=8); a.set_ylabel("density", fontsize=8)
    a.legend(fontsize=7, frameon=False)
    a.set_title("F. VARX could learn its own support — and does not\n"
                "the two distributions are the same: rank-deficient\n"
                "design, so these coefficients are not connectivity", fontsize=9)

    fig.tight_layout(rect=(0, 0, 1, 0.96))
    PNG.mkdir(exist_ok=True)
    fig.savefig(OUT, dpi=150)
    print(f"wrote {OUT}")

    print(f"\nlattice: {len(ii)} edges, {n_bridge} crossing the midline")
    for nm, M in zip(names, mats):
        print(f"  {nm:<16} self {np.abs(np.diag(M)).mean():8.3f}   "
              f"on-lattice rms {np.sqrt((M[adj]**2).mean()):8.3f}   "
              f"off-lattice rms {np.sqrt((M[off & ~adj]**2).mean()):8.3f}")
    print(f"  GVAR directedness: corr(fwd,rev) = {r:+.3f}, {opp:.1%} sign-flipped edges")


if __name__ == "__main__":
    main()
