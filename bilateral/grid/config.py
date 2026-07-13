"""config.py — galvo photostim site-grid analysis (opto_brainGrid638).

All session / calibration / window constants for the AL_0048 dual-opsin grid live
here so the loader, analysis and plotting modules stay free of magic numbers.
Edit a session by changing only this file. Provenance for each block is noted inline;
see grid/README.md for the full handoff.
"""
from pathlib import Path

# ============================== SESSION ==============================
# *** To analyze a different session, edit ONLY these 4 fields. ***
# Galvo volts->mm calibration is auto-read from the server per session (calibration.py, from
# hardwareInfo.json in the BLOCK_EXP folder); only BREGMA_PX / PX_PER_MM below (image
# registration) may need a Fig-0 re-check when the mouse/mounting changes.
SUBJECT = "AL_0048"
DATE = "2026-07-10"
WF_EXP = "3"                # widefield SVD + raw Timeline traces (analysis reads this)
BLOCK_EXP = "6"            # paired Signals run: hardwareInfo.json + Block.mat (power/pos/order)
# previous sessions: 2026-07-01 WF=4 Block=5 ; 2026-06-24 WF=2 Block=3

# 2026-07-10 note: exp 3's Timeline/SVD spans the WHOLE ~97-min session, so its 638 onsets
# contain the two impulse blocks (4=false-start, 5=impulse dose-response) THEN this grid
# block (6), separated by a >90 s gap. Take the LAST onset segment for the grid; the impulse
# stream is handled in bilateral/impulse/.
ONSET_SEGMENT = "last"     # None = use all onsets (single-block sessions); 'last'/'first'/int
SEGMENT_GAP_S = 50         # inter-block gap (s) that marks a block boundary

SERVER = "//sahale.biostr.washington.edu/data/Subjects"

EXPDIR = Path(SERVER) / SUBJECT / DATE / WF_EXP

# ============================== STIM ==============================
LASER = "638"              # active laser line (lightCommand638; 594 was idle)
AMP_SEL = 2.0             # single-amp default (legacy 1-amp pipeline: build/tf_fit/viewer)
AMPS = [1.0, 2.0]         # 2026-07-10 grid (block 6): two power levels, BOTH fired, 2600
                          #   onsets each (50 reps x 52 sites). (2026-07-01 was [0.25, 0.5].)
FS_DAQ = 2000.0           # Timeline DAQ rate (Hz), from TimelineHW.json
N_COMPS = 50              # SVD components used
LASER_THR = 0.3          # V threshold on lightCommand for onset detection
DEBOUNCE_S = 0.06         # min gap between accepted onsets (s)

# galvo volts -> mm-from-bregma: NOT hardcoded — read per session from the server's
# hardwareInfo.json (signalsOutputs.opto<LASER>, identical to .galvoOpto) by
# calibration.galvo_calib() and cached to data/grid_calib_<subject>_<date>.json.
# cross_response.build() fetches mmPerV_X/Y + bregmaOffset_X/Y automatically.

# mm -> SVD-image pixel.  *** IMAGE REGISTRATION — verify with Fig 0 (grid_sites.png) ***
# These are NOT on the server for the widefield session: bregma is marked visually and px/mm
# is a widefield-optics rig constant (from AL_0041 notebook). calibration.bregma_px_hint()
# suggests a bregma pixel from a same-day bregma.csv when one exists; verify before trusting.
BREGMA_PX = (280.0, 250.0)   # (x, y) px in the 560x560 meanImage (Fig-0 verified)
PX_PER_MM_X = 57.8           # widefield rig scale
PX_PER_MM_Y = -57.8          # y inverted for image coords
ROI_RAD = 10                 # ROI half-width (px) around each site

# trial window (notebook: arange(0, 1.5, 1/70) - 12/35), seconds relative to onset
FS_WIN = 70.0
WIN_PRE = 12 / 35
WIN_DUR = 1.5
TAU_T0_IX = 32               # first sample used for the exp-rise fit (notebook start_ix)

# cross-response tensor / TF viewer display window (s rel. onset). NOTE: ITI ~0.71 s, so
# windows beyond ~±0.7 s overlap neighbor stims (avg ~3.6 others within ±2 s); the trial
# average smears those out but the tails carry a residual ripple. TF fit is capped tighter.
CROSS_WIN = (-2.0, 2.0)

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
