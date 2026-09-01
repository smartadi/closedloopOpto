"""pyFigure3 — Python port of the MATLAB Figure 3 (CL vs OL) panel pipeline.

Ported from controller-analysis/{variance_mse,step_response}.m and
utils/analysisPlots_combined.m. Reads the same data/<session>.mat controller
caches (MATLAB -v7.3 / HDF5) via io.load_session, so it runs unchanged on the
lab PC where the caches live.
"""
from . import style, io, panels, figure3  # noqa: F401
from .io import Session, load_session, load_many  # noqa: F401

__all__ = ["style", "io", "panels", "figure3", "Session", "load_session", "load_many"]
