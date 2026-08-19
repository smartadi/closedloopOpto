"""impulse_config.py — dual-opsin bilateral impulse dose-response (opto_bilateralImpulse638).

Sub-area of the dual-opsin (bilateral) analysis, running the impulse-analysis logic on the
AL_0048 two-spot single-frame impulse experiment (opto_bilateralImpulse638). Sessions are held
in the `SESSIONS` registry below and selected via `SESSION`; both use the same mirrored
one-spot-per-hemisphere design (galvoX = -2.5 left/EXCITATORY, +2.5 right/INHIBITORY, galvoY=-3):

  2026-07-10 — exp 3 = continuous widefield SVD + Timeline; impulse = Signals block 5 (block 4 =
    false start), 6 amps [0,0.5,1.0,1.5,2.0,2.5]; stopped ~half -> 532 firing (~50 reps/amp/side);
    a grid run (block 6) follows in the same Timeline (>90 s gap).
  2026-07-15 — exp 1 = widefield+Timeline; impulse = Signals block 2, 4 amps [0,0.5,1.5,2.5];
    completed 800 trials -> 600 firing (100 reps/amp/side) + 200 sham; no grid after.

`impulse_core` derives the 638 onsets, keeps the pre-grid impulse segment, assigns amplitude
positionally from the block's firing trials (validated 1:1, galvoX-sign match), and (when
RECOVER_SHAM) recovers the amp-0 catch trials via the Block<->Timeline clock map.

Image registration (BREGMA_PX / PX_PER_MM) and galvo volts->mm calibration are shared with the
grid module and read from there. See impulse/README.md for the handoff.
"""
from pathlib import Path
import sys

# reuse the grid module's loader / calibration / analysis primitives + verified registration
GRID_DIR = Path(__file__).resolve().parent.parent / "grid"
sys.path.insert(0, str(GRID_DIR))
import config as gridcfg   # noqa: E402  (verified BREGMA_PX / PX_PER_MM / ROI_RAD / N_COMPS)

# ============================== SESSION REGISTRY ==============================
# One entry per bilateral two-spot impulse session (opto_bilateralImpulse638). Both use the
# SAME mirrored one-spot-per-hemisphere design (galvoX = -2.5 left/excit, +2.5 right/inhib);
# they differ only in block layout and which firing amps were run. Shared knobs (SITE_*,
# windows, registration) stay module-level below. Select the session via `SESSION`.
#   WF_EXP        — exp holding the continuous widefield SVD + Timeline (638 traces)
#   IMPULSE_BLOCK — Signals block (exp) with the impulse dose-response
#   CALIB_BLOCK   — any block this session has hardwareInfo.json (galvo calib is session-const)
#   AMPS          — FIRING amps present (sham 0 excluded: it produces no laser onset)
#   FOCUS_AMP     — strongest amp used to localize the data-derived focal pixel
#   HAS_GRID_AFTER— True if a >gap grid run follows the impulse in the same Timeline
SESSIONS = {
    "2026-07-10": dict(
        WF_EXP="3", IMPULSE_BLOCK="5", CALIB_BLOCK="6",
        AMPS=[0.5, 1.0, 1.5, 2.0, 2.5], FOCUS_AMP=2.5, HAS_GRID_AFTER=True,
        note="first run, stopped ~half (~50 reps/amp/side); block 4 = false start; "
             "grid block 6 follows in the same exp-3 Timeline (>90 s gap)."),
    "2026-07-15": dict(
        WF_EXP="1", IMPULSE_BLOCK="2", CALIB_BLOCK="2",
        AMPS=[0.5, 1.5, 2.5], FOCUS_AMP=2.5, HAS_GRID_AFTER=False,
        note="completed run: 800 trials (100/cond x 8) -> 600 firing + 200 sham; "
             "no false-start, no grid after (single onset segment)."),
}
SESSION = "2026-07-15"       # <-- select session here (default: latest complete run)

# ============================== SESSION (resolved from registry) ==============================
SUBJECT = "AL_0048"
DATE = SESSION
_S = SESSIONS[SESSION]
WF_EXP = _S["WF_EXP"]        # continuous widefield SVD + Timeline (analysis reads this)
IMPULSE_BLOCK = _S["IMPULSE_BLOCK"]
CALIB_BLOCK = _S["CALIB_BLOCK"]

SERVER = "//sahale.biostr.washington.edu/data/Subjects"
EXPDIR = Path(SERVER) / SUBJECT / DATE / WF_EXP

# ============================== STIM ==============================
LASER = "638"
FS_DAQ = 2000.0             # Timeline DAQ rate (Hz)
N_COMPS = gridcfg.N_COMPS   # SVD components
LASER_THR = 0.3             # V threshold for onset detection
DEBOUNCE_S = 0.06
SEGMENT_GAP_S = 50          # inter-block gap (s); impulse = the segment BEFORE any grid run

# firing amplitudes present (sham 0 excluded: it produces no laser onset — recovered separately)
AMPS = _S["AMPS"]
FOCUS_AMP = _S["FOCUS_AMP"]

# recover the amp-0 (sham) catch trials via the Block<->Timeline clock map (they fire no laser
# so they are absent from the detected onsets); include them as a per-side zero-amp condition.
RECOVER_SHAM = True
DOSE_AMPS = ([0.0] + list(AMPS)) if RECOVER_SHAM else list(AMPS)

# two mirrored spots (galvo mm-from-bregma); side = sign(galvoX)
SITE_LEFT = (-2.5, -3.0)    # excitatory opsin -> positive dF/F
SITE_RIGHT = (2.5, -3.0)    # inhibitory opsin -> negative dF/F

# ============================== IMAGE REGISTRATION (shared, Fig-0 verified) ==============================
BREGMA_PX = gridcfg.BREGMA_PX
PX_PER_MM_X = gridcfg.PX_PER_MM_X
PX_PER_MM_Y = gridcfg.PX_PER_MM_Y
ROI_RAD = gridcfg.ROI_RAD          # focal-readout ROI half-width (px)
FOCUS_SEARCH_RAD = 35              # search box (px) around the nominal spot for the focal pixel

# ============================== TRIAL WINDOW ==============================
# ITI is 3-5 s so a +2 s window never overlaps the next impulse (unlike the grid).
FS_WIN = 70.0
WIN_PRE = 0.5              # s of baseline shown before onset
WIN_POST = 2.0            # s shown after onset
BASE_WIN = (-0.5, 0.0)    # pre-onset baseline window (s rel. onset)

# inhibition/excitation ENERGY window (impulse-analysis locked: peak_mode=3, mean 0-200 ms).
# Well-matched to the SUSTAINED inhibitory trough; for the fast excitatory transient the
# signed PEAK (PEAK_WIN) is the better dose-response readout — both are reported.
ENERGY_WIN = (0.0, 0.20)
PEAK_WIN = (0.0, 0.30)     # window for the signed peak (max on excit side, min on inhib side)

# spatial dF/F snapshot windows (for the focal-site map)
SNAP_BASE_WIN = (-0.20, 0.0)
SNAP_STIM_WIN = (0.03, 0.15)
SPATIAL_CLIM = 0.03       # +/- dF/F color scale for per-side spatial maps

OUTDIR = Path(__file__).resolve().parent / "impulse_png"
