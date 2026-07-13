"""impulse_config.py — dual-opsin bilateral impulse dose-response (opto_bilateralImpulse638).

Sub-area of the dual-opsin (bilateral) analysis, running the impulse-analysis logic on the
AL_0048 two-spot single-frame impulse experiment. One session so far:

  AL_0048 2026-07-10 — exp 3 = continuous widefield SVD + Timeline (spans the whole ~97-min
  session); the impulse dose-response is Signals **block 5** (block 4 = 2-trial false start).
  Block 5: 643 trials, 6 amps [0, 0.5, 1.0, 1.5, 2.0, 2.5] (0 = sham, no laser onset), two
  mirrored spots galvoX = -2.5 (left / EXCITATORY) and +2.5 (right / INHIBITORY) at galvoY=-3.
  Planned 1200 (100/amp), stopped ~half -> 532 firing onsets (~50 reps/amp/side).

The exp-3 Timeline holds impulse (blocks 4,5) then grid (block 6) onsets separated by a >90 s
gap; `impulse_core` derives all 638 onsets and keeps the impulse segment, then assigns amplitude
positionally from block 5's firing trials (validated 1:1, 100% galvoX-sign match).

Image registration (BREGMA_PX / PX_PER_MM) and galvo volts->mm calibration are shared with the
grid module and read from there. See impulse/README.md for the handoff.
"""
from pathlib import Path
import sys

# reuse the grid module's loader / calibration / analysis primitives + verified registration
GRID_DIR = Path(__file__).resolve().parent.parent / "grid"
sys.path.insert(0, str(GRID_DIR))
import config as gridcfg   # noqa: E402  (verified BREGMA_PX / PX_PER_MM / ROI_RAD / N_COMPS)

# ============================== SESSION ==============================
SUBJECT = "AL_0048"
DATE = "2026-07-10"
WF_EXP = "3"                 # continuous widefield SVD + Timeline (analysis reads this)
IMPULSE_BLOCK = "5"          # Signals block with the impulse dose-response (4 = false start)
CALIB_BLOCK = "6"            # any block this session has hardwareInfo.json (galvo calib is
                             #   session-constant); block 5 also has one — 6 already cached.

SERVER = "//sahale.biostr.washington.edu/data/Subjects"
EXPDIR = Path(SERVER) / SUBJECT / DATE / WF_EXP

# ============================== STIM ==============================
LASER = "638"
FS_DAQ = 2000.0             # Timeline DAQ rate (Hz)
N_COMPS = gridcfg.N_COMPS   # SVD components
LASER_THR = 0.3             # V threshold for onset detection
DEBOUNCE_S = 0.06
SEGMENT_GAP_S = 50          # inter-block gap (s); impulse = the segment BEFORE the grid

# firing amplitudes present in block 5 (sham 0 excluded: it produces no laser onset)
AMPS = [0.5, 1.0, 1.5, 2.0, 2.5]
FOCUS_AMP = 2.5             # strongest amp used to localize the data-derived focal pixel

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
