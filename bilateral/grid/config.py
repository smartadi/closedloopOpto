"""config.py — galvo photostim site-grid analysis (opto_brainGrid638).

All session / calibration / window constants for the AL_0048 dual-opsin grid live
here so the loader, analysis and plotting modules stay free of magic numbers.
Edit a session by changing only this file. Provenance for each block is noted inline;
see grid/README.md for the full handoff.
"""
from pathlib import Path

# ============================== SESSION ==============================
SUBJECT = "AL_0048"
DATE = "2026-06-24"
WF_EXP = "2"                # widefield SVD + raw Timeline traces (analysis reads this)
BLOCK_EXP = "3"             # paired Signals run: per-trial power/position/order (Block.mat)
SERVER = r"\\sahale.biostr.washington.edu\data\Subjects"

EXPDIR = Path(SERVER) / SUBJECT / DATE / WF_EXP

# ============================== STIM ==============================
LASER = "638"              # active laser line (lightCommand638; 594 was idle)
AMP_SEL = 0.5             # laser power to analyze. In this session only 0.5 fired;
                          #   0.25 was sub-threshold (no pulse). None -> pool whatever fired.
FS_DAQ = 2000.0           # Timeline DAQ rate (Hz), from TimelineHW.json
N_COMPS = 50              # SVD components used
LASER_THR = 0.3          # V threshold on lightCommand for onset detection
DEBOUNCE_S = 0.06         # min gap between accepted onsets (s)

# galvo volts -> mm-from-bregma  (hardwareInfo.daqController.galvoOpto)
MM_PER_V_X = 1.1111111111111112
MM_PER_V_Y = -1.075268817204301      # Y inverted
BREGMA_OFFSET_X = 0.732639223045812  # galvo volts at bregma (mm=0)
BREGMA_OFFSET_Y = 0.30088318722119456

# mm -> SVD-image pixel.  *** DIAL THESE IN WITH Fig 0 (grid_sites.png) ***
#   server bregma_coords ([530, 217]) lives in the 512x640 calibration image, NOT this
#   560x560 SVD frame, so it can't be used directly. Confirmed visually correct by user.
BREGMA_PX = (280.0, 250.0)   # (x, y) px in the 560x560 meanImage
PX_PER_MM_X = 57.8           # rig scale (from AL_0041 notebook)
PX_PER_MM_Y = -57.8          # y inverted for image coords
ROI_RAD = 10                 # ROI half-width (px) around each site

# trial window (notebook: arange(0, 1.5, 1/70) - 12/35), seconds relative to onset
FS_WIN = 70.0
WIN_PRE = 12 / 35
WIN_DUR = 1.5
TAU_T0_IX = 32               # first sample used for the exp-rise fit (notebook start_ix)

# spatial dF/F snapshot grid (notebook cell 10): a full-frame response image per site
SPATIAL_SNAPSHOT = True
BASE_WIN = (-0.10, 0.0)      # s rel. onset, baseline frames
STIM_WIN = (0.04, 0.12)      # s rel. onset, early-response frames
SPATIAL_CLIM = 0.02          # +/- dF/F color scale

# per-site trial x time raster (notebook cell 19)
RASTER = True
RASTER_CLIM = 0.08           # +/- dF/F color scale

# output dir for regenerable figures (gitignored)
OUTDIR = Path(__file__).resolve().parent / "grid_png"
