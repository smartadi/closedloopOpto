"""plots.py — render the grid figures from computed results.

Each function takes already-computed data + config and writes one PNG to cfg.OUTDIR.
Exploratory figures (300 dpi PNG); apply paperFig/paperStyle only if promoted to a panel.
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from analysis import site_px


def _layout_rc(mx, my):
    """8x8 subplot (row, col) for a grid site, matching the monolith layout."""
    return int(round(3 - my)), int(round(mx + 3.5))


def plot_sites(mimg, sites, cfg, label):
    """Fig 0: bregma + site overlay on the mean image (dial-in check)."""
    fig, ax = plt.subplots(figsize=(4, 4))
    ax.imshow(mimg, cmap="gray"); ax.set_axis_off()
    ax.scatter(*cfg.BREGMA_PX, ec="m", fc="none", s=70, lw=1.2)
    sx, sy = site_px(sites[:, 0], sites[:, 1], cfg.BREGMA_PX, cfg.PX_PER_MM_X, cfg.PX_PER_MM_Y)
    ax.scatter(sx, sy, c="r", s=14, lw=0, alpha=0.5)
    ax.set_title(f"{cfg.SUBJECT} {cfg.DATE} - verify bregma / sites")
    fig.savefig(cfg.OUTDIR / "grid_sites.png", dpi=300, bbox_inches="tight"); plt.close(fig)


def plot_timecourses(window, responses, sites, cfg, label):
    """Per-site ROI dF/F median +/- SEM with exp-rise tau fit (8x8)."""
    fig = plt.figure(figsize=(8, 8))
    gs = fig.add_gridspec(8, 8, wspace=0.3, hspace=0.3)
    for mx, my in sites:
        r = responses[(mx, my)]
        ax = fig.add_subplot(gs[_layout_rc(mx, my)])
        ax.fill_between(window, r["median"] - r["sem"], r["median"] + r["sem"],
                        color="dodgerblue", lw=0, alpha=0.3)
        ax.plot(window, r["median"], c="dodgerblue", lw=0.5)
        ax.axhline(0, ls="--", c="k", lw=0.4)
        ax.set_ylim(-0.03, 0.03); ax.set_axis_off()
        if r["fit_t"] is not None:
            ax.plot(r["fit_t"], r["fit_y"], c="orange", lw=0.7, ls="--")
    fig.suptitle(f"{cfg.SUBJECT} {cfg.DATE} - dF/F per site ({cfg.LASER} nm, {label})")
    fig.savefig(cfg.OUTDIR / "grid_timecourses.png", dpi=300, bbox_inches="tight"); plt.close(fig)


def plot_tau(responses, sites, cfg, label):
    """Rise-tau spatial map."""
    try:
        import colorcet  # noqa: F401  (registers cet_* colormaps)
        cmap = "cet_CET_L4"
    except Exception:
        cmap = "viridis"
    tv = np.array([responses[(s[0], s[1])]["tau"] for s in sites])
    fig, ax = plt.subplots(figsize=(4, 4)); ax.set_aspect("equal"); ax.set_axis_off()
    sc = ax.scatter(sites[:, 0], sites[:, 1], c=tv, s=120, ec="k", cmap=cmap, vmin=0, vmax=0.2)
    cb = fig.colorbar(sc, ax=ax, shrink=0.7); cb.set_label(r"$\tau$ (s)")
    ax.set_title(f"{cfg.SUBJECT} {cfg.DATE} - rise " + r"$\tau$" + f" ({label})")
    fig.savefig(cfg.OUTDIR / "grid_tau.png", dpi=300, bbox_inches="tight"); plt.close(fig)


def plot_spatial(snapshots, sites, cfg, label):
    """Full-frame dF/F image per site (early-response window), 8x8."""
    fig = plt.figure(figsize=(8, 8))
    gs = fig.add_gridspec(8, 8, wspace=0.1, hspace=0.1)
    im0 = None
    for mx, my in sites:
        ax = fig.add_subplot(gs[_layout_rc(mx, my)])
        im0 = ax.imshow(snapshots[(mx, my)], cmap="bwr",
                        clim=(-cfg.SPATIAL_CLIM, cfg.SPATIAL_CLIM))
        cx, cy = site_px(mx, my, cfg.BREGMA_PX, cfg.PX_PER_MM_X, cfg.PX_PER_MM_Y)
        ax.scatter(cx, cy, marker=".", c="m", s=6, lw=0)
        ax.set_axis_off()
    cb = fig.colorbar(im0, ax=fig.axes, shrink=0.5,
                      ticks=[-cfg.SPATIAL_CLIM, cfg.SPATIAL_CLIM])
    cb.set_label("dF/F")
    cb.ax.set_yticklabels([f"{-cfg.SPATIAL_CLIM*100:.0f}%", f"{cfg.SPATIAL_CLIM*100:.0f}%"])
    fig.suptitle(f"{cfg.SUBJECT} {cfg.DATE} - dF/F image per site "
                 f"({cfg.STIM_WIN[0]*1000:.0f}-{cfg.STIM_WIN[1]*1000:.0f} ms, {label})")
    fig.savefig(cfg.OUTDIR / "grid_spatial.png", dpi=300, bbox_inches="tight"); plt.close(fig)


def plot_raster(window, responses, sites, cfg, label):
    """Per-site trial x time dF/F raster, 8x8."""
    fig = plt.figure(figsize=(8, 8))
    gs = fig.add_gridspec(8, 8, wspace=0.2, hspace=0.2)
    im0 = None
    for mx, my in sites:
        dff = responses[(mx, my)]["dff"]
        ax = fig.add_subplot(gs[_layout_rc(mx, my)])
        im0 = ax.imshow(dff, cmap="bwr", clim=(-cfg.RASTER_CLIM, cfg.RASTER_CLIM),
                        aspect="auto", extent=[window[0], window[-1], 0, dff.shape[0]])
        ax.axvspan(0, 0.025, color="r", lw=0, alpha=0.5)        # 25 ms stim period
        ax.set_xticks([]); ax.set_yticks([])
    cb = fig.colorbar(im0, ax=fig.axes, shrink=0.5,
                      ticks=[-cfg.RASTER_CLIM, cfg.RASTER_CLIM])
    cb.set_label("dF/F")
    cb.ax.set_yticklabels([f"{-cfg.RASTER_CLIM*100:.0f}%", f"{cfg.RASTER_CLIM*100:.0f}%"])
    fig.suptitle(f"{cfg.SUBJECT} {cfg.DATE} - per-site trial x time dF/F "
                 f"({cfg.LASER} nm, {label})")
    fig.savefig(cfg.OUTDIR / "grid_raster.png", dpi=300, bbox_inches="tight"); plt.close(fig)
