"""Self-contained test/demo for the Figure 3 port.

Runs without real data: builds synthetic sessions, round-trips them through the
MATLAB-v7.3-style HDF5 loader, renders every panel, and checks the paper's core
claims hold on the synthetic ground truth.

    python -m pyFigure3.test_figure3            # run checks + write demo figures
    pytest pyFigure3/test_figure3.py            # run as tests

Outputs (PNGs) go to $FIG3_OUT or ./_fig3_test_out (gitignored: *.png).
"""
from __future__ import annotations

import os
import tempfile

import numpy as np

from . import synth, panels, figure3
from .io import load_session

OUTDIR = os.environ.get("FIG3_OUT", "_fig3_test_out")


def test_hdf5_roundtrip():
    """Loader recovers array shapes/values from a v7.3-style HDF5 cache."""
    sess = synth.make_synthetic_session(seed=1, n_ol=30, n_cl=25)
    with tempfile.TemporaryDirectory() as td:
        path = os.path.join(td, "synthctrl01011.mat")
        synth.write_synthetic_cache(path, sess)
        loaded = load_session(path)
    assert loaded.ncDfk.shape == (30, 176), loaded.ncDfk.shape
    assert loaded.wcDfk.shape == (25, 176)
    assert loaded.pncDfk.shape == (30, 561)
    assert loaded.ncInp.shape == (30, 6001)
    assert loaded.ref == -5.0 and loaded.dur == 3.0
    # values survive the transpose round-trip
    np.testing.assert_allclose(loaded.ncDfk, sess.ncDfk, rtol=1e-9, atol=1e-9)
    np.testing.assert_allclose(loaded.er_ncDfk, sess.er_ncDfk, rtol=1e-9, atol=1e-9)


def test_rmse_definition_matches_matlab():
    """Recomputed RMSE == cached er_* == sample-normalised sqrt(mean((seg-ref)^2))."""
    sess = synth.make_synthetic_session(seed=2)
    seg = sess.ncDfk[:, 35:141]                       # [0,3] s, cols 36:141 (1-based)
    manual = np.sqrt(np.mean((seg - sess.ref) ** 2, axis=1))
    np.testing.assert_allclose(sess.rmse_full(cl=False), manual, rtol=1e-9)


def test_paper_claims_hold_on_synthetic():
    """CL tracks better than OL: lower RMSE, and stim-window variance ratio > 1."""
    sessions = synth.make_session_set(n=6)
    ol_rmse = np.mean([s.rmse_full(cl=False).mean() for s in sessions])
    cl_rmse = np.mean([s.rmse_full(cl=True).mean() for s in sessions])
    assert cl_rmse < ol_rmse, (cl_rmse, ol_rmse)

    # variance ratio during stim (0-3 s) should exceed 1 (OL more variable)
    from .io import time_axis_l
    tp = time_axis_l()
    stim = (tp >= 0) & (tp <= 3)
    ratios = []
    for s in sessions:
        r = s.var_trace_l(cl=False)[stim].mean() / s.var_trace_l(cl=True)[stim].mean()
        ratios.append(r)
    assert np.mean(ratios) > 1.0, np.mean(ratios)


def test_all_panels_render():
    """Every panel A-J draws without error and produces finite artists."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    sessions = synth.make_session_set(n=6)
    rep = sessions[0]
    single = [panels.panel_A, panels.panel_B, panels.panel_C, panels.panel_D, panels.panel_E]
    cross = [panels.panel_F, panels.panel_G, panels.panel_H, panels.panel_I, panels.panel_J]
    for fn in single:
        fig, ax = plt.subplots()
        fn(ax, rep)
        assert ax.has_data()
        plt.close(fig)
    for fn in cross:
        fig, ax = plt.subplots()
        fn(ax, sessions)
        assert ax.has_data()
        plt.close(fig)


def main():
    import matplotlib
    matplotlib.use("Agg")

    print("[1/4] HDF5 v7.3 round-trip ...", end=" ")
    test_hdf5_roundtrip(); print("ok")
    print("[2/4] RMSE definition ...", end=" ")
    test_rmse_definition_matches_matlab(); print("ok")
    print("[3/4] paper claims on synthetic ...", end=" ")
    test_paper_claims_hold_on_synthetic(); print("ok")
    print("[4/4] render all panels + montage ...", end=" ")

    # Write real HDF5 caches, then drive the full make_figure3 path from disk.
    sessions = synth.make_session_set(n=6)
    os.makedirs(OUTDIR, exist_ok=True)
    cache_paths = []
    for s in sessions:
        p = os.path.join(OUTDIR, f"{s.name}_cache.mat")
        synth.write_synthetic_cache(p, s)
        cache_paths.append(p)
    written = figure3.make_figure3(cache_paths, outdir=OUTDIR, rep_index=0)
    print("ok")
    print(f"\nWrote {len(written)} files to {OUTDIR}/")
    for w in written:
        print("  ", w)


if __name__ == "__main__":
    main()
