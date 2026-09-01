"""Assemble Figure 3 — individual panel exports + a combined montage.

Usage (real data, on the lab PC where data/ caches live):

    from pyFigure3 import figure3
    figure3.make_figure3(
        cache_paths=["data/AL_0033ctrl01203.mat", ...],
        rep_path="data/AL_0033ctrl02242.mat",   # representative session for A-E
        outdir="paper/images/figure3",
    )

Panels A-E come from the representative session; F-J pool all sessions.
"""
from __future__ import annotations

import os
from typing import List, Optional

from . import panels
from .io import Session, load_session, load_many


def _new_axes(figsize):
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=figsize)
    return fig, ax


def export_panels(rep: Session, sessions: List[Session], outdir: str, fmt: str = "png"):
    """Write each panel A-J as its own file into outdir."""
    import matplotlib.pyplot as plt

    os.makedirs(outdir, exist_ok=True)
    single = {"A": panels.panel_A, "B": panels.panel_B, "C": panels.panel_C,
              "D": panels.panel_D, "E": panels.panel_E}
    cross = {"F": panels.panel_F, "G": panels.panel_G, "H": panels.panel_H,
             "I": panels.panel_I, "J": panels.panel_J}
    written = []
    for letter, fn in single.items():
        fig, ax = _new_axes((3.2, 2.6))
        fn(ax, rep)
        path = os.path.join(outdir, f"panel_{letter}.{fmt}")
        fig.tight_layout(); fig.savefig(path, dpi=200); plt.close(fig)
        written.append(path)
    for letter, fn in cross.items():
        w = 7.5 if letter == "G" else 3.4
        fig, ax = _new_axes((w, 2.8))
        fn(ax, sessions)
        path = os.path.join(outdir, f"panel_{letter}.{fmt}")
        fig.tight_layout(); fig.savefig(path, dpi=200); plt.close(fig)
        written.append(path)
    return written


def montage(rep: Session, sessions: List[Session], outpath: str):
    """One overview figure with all ten panels in a grid."""
    import matplotlib.pyplot as plt

    fig = plt.figure(figsize=(14, 10))
    gs = fig.add_gridspec(3, 4, hspace=0.55, wspace=0.45)
    panels.panel_A(fig.add_subplot(gs[0, 0]), rep)
    panels.panel_B(fig.add_subplot(gs[0, 1]), rep)
    panels.panel_C(fig.add_subplot(gs[0, 2]), rep)
    panels.panel_D(fig.add_subplot(gs[0, 3]), rep)
    panels.panel_E(fig.add_subplot(gs[1, 0]), rep)
    panels.panel_F(fig.add_subplot(gs[1, 1]), sessions)
    panels.panel_H(fig.add_subplot(gs[1, 2]), sessions)
    panels.panel_I(fig.add_subplot(gs[1, 3]), sessions)
    panels.panel_G(fig.add_subplot(gs[2, :3]), sessions)
    panels.panel_J(fig.add_subplot(gs[2, 3]), sessions)
    fig.suptitle("Figure 3 — closed-loop vs open-loop cortical activity control",
                 fontsize=10, fontweight="bold")
    os.makedirs(os.path.dirname(outpath) or ".", exist_ok=True)
    fig.savefig(outpath, dpi=200, bbox_inches="tight")
    plt.close(fig)
    return outpath


def make_figure3(cache_paths: List[str], outdir: str,
                 rep_path: Optional[str] = None, rep_index: int = 0):
    """End-to-end: load caches, export panels + montage. Returns written paths."""
    import matplotlib
    matplotlib.use("Agg")

    sessions = load_many(cache_paths)
    if rep_path is not None:
        rep = load_session(rep_path)
    else:
        rep = sessions[rep_index]
    written = export_panels(rep, sessions, outdir)
    written.append(montage(rep, sessions, os.path.join(outdir, "figure3_montage.png")))
    return written
