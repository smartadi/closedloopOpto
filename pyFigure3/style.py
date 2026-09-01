"""Paper style constants — Python mirror of utils/paperStyle.m.

Only the constants needed for Figure 3 (closed-loop vs open-loop) are ported.
Values are taken verbatim from paperStyle.m (see fig3_spec §6).
"""

# ---- Global acquisition / analysis constants -------------------------------
FS = 35            # widefield dF/F sample rate (Hz)
FS_IN = 2000       # optogenetic input command sample rate (Hz)
DUR = 3            # stim duration (s); d.params.dur, hard-set to 3 across the pipeline
REF = -5.0         # reference dF/F level (%); d.ref

# ---- Column layout of the 176-sample ncDfk/wcDfk window --------------------
# window = dFk(i-35 : i+35*(dur+1)), onset sample i at MATLAB col 36 (1-based).
# Python 0-based equivalents below.
NCDFK_ONSET = 35        # MATLAB col 36  -> t = 0 s
NCDFK_T1    = 70        # MATLAB col 71  -> t = +1 s
NCDFK_T3    = 140       # MATLAB col 141 -> t = +3 s
# window bounds used by the windowed-RMSE panels (MATLAB inclusive ranges):
#   early [0,1] s : cols 36:71  -> python slice [35:71]
#   late  [1,3] s : cols 71:141 -> python slice [70:141]
#   full  [0,3] s : cols 36:141 -> python slice [35:141]

# ---- Column layout of the 561-sample pncDfk/pwcDfk window ------------------
# window = dFk(i-350 : i+35*(dur+3)), onset at MATLAB col 351 (1-based).
PNCDFK_ONSET = 350      # MATLAB col 351 -> t = 0 s
# The 316-sample "_l" window (tp axis, -3..+6 s) is a sub-slice of pncDfk:
#   pncDfk_l = pncDfk(:, 246:561)  -> python slice [245:561]
PL_START = 245
PL_STOP = 561           # exclusive; 561-245 = 316 columns
PL_ONSET = 105          # MATLAB col 106 within the _l window -> t = 0 s

# ---- Colors (RGB 0-1) ------------------------------------------------------
COL_OL = (1.0, 0.0, 0.0)          # open-loop  -> red
COL_CL = (0.0, 0.40, 0.85)        # closed-loop -> blue
COL_INP_OL = (0.55, 0.55, 0.55)   # input traces are gray in current code
COL_INP_CL = (0.55, 0.55, 0.55)   # (caption says pink/blue; code reserves color for the response)
COL_FIT = (0.2, 0.4, 0.8)
COL_GRAY = (0.6, 0.6, 0.6)
STIM_PATCH = (0.85, 0.85, 0.85)

# ---- Line widths / fonts / alpha ------------------------------------------
LW_MEAN = 1.5
LW_FIT = 1.2
LW_TRIAL = 0.4
LW_REF = 1.0
LW_INP = 0.75
LW_ZERO = 0.5
FS_LABEL = 6
FW = "bold"
FA = 0.2           # ribbon / violin fill alpha
VIOLIN_HALFWIDTH = 0.3
INPUT_DISPLAY_SCALE = 3.0   # panel C scales trial-avg input x3 for visibility
