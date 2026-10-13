# AL_0048 experiment inventory (which experiment is which)

Built 2026-09-21 by scanning `\\sahale...\Subjects\AL_0048\` — `parameters.mat` (`defFunction`,
`laserDur/laserAmp/galvoXPos/YPos`) for the opto experiments; Block `expDef` + CSV presence for the rest.

## ⚠ Galvo side convention (RESOLVED from the caches, 2026-09-21)
**`galvo_x_mm > 0` = RIGHT hemisphere = INHIBITORY;  `galvo_x_mm < 0` = LEFT = EXCITATORY.**
Verified against `AL_0048_clol_06202` (galvo_x=+2 → `sides.name='right'`, ref −5, pixel [408,410]) and
`AL_0048_clol_06245` (all galvo_x>0 → 'right'), and the 07-21 registry math (positive galvo → right pixel 407).
NOTE: `bilateral/CLAUDE.md` is self-contradictory — its line 5 ("positive = left/excitatory") is WRONG;
lines 56–57 ("x>0 → right/inhibitory") are correct. All side counts below use the verified mapping.

## Opto / photostim (galvo) — the excitatory-relevant data

### Spatial grids (52-site maps; both hemispheres, so they carry excitatory-left sites)
| date/exp | expDef | dur (s) | amps | sites | hemis |
|---|---|---|---|---|---|
| 2026-04-22/4 | `opto_brainGridOrange` | 0.05 | 1, 3 | 52 | +/- (**ORANGE 594 nm excitatory-selective**) — ⚠ **NO widefield SVD on the share** (Signals/Block only) → cannot be mapped |
| 2026-06-23/2 | `opto_brainGrid638` | 0.025 | 0.25, 0.5 | 52 | +/- |
| 2026-06-23/4 | `opto_brainGrid638` | 0.025 | 0.25, 0.5 | 52 | +/- |
| 2026-06-24/3 | `opto_brainGrid638` | 0.025 | 0.25, 0.5 | 52 | +/- (analyzed grid; grid_calib present) |
| 2026-07-01/5 | `opto_brainGrid638` | 0.025 | 0.25, 0.5 | 52 | +/- (low-power, SNR-limited) |
| 2026-07-10/6 | `opto_brainGrid638` | 0.025 | 1, 2 | 52 | +/- (clean dose-response, slope 1.39) |
| 2026-04-22/2 | `opto_miniGrid` | 0.025 | 3 | 25 | - (right/inhib only) |

### Impulse dose-response (2-site: excitatory-left + inhibitory-right)
| date/exp | expDef | dur (s) | amps | sites |
|---|---|---|---|---|
| 2026-07-10/2 | `opto_bilateralImpulse6` | 0.029 | 0, 0.5, 1, 1.5, 2, 2.5 | 2 (L+R) |
| 2026-07-10/4 | `opto_bilateralImpulse6` | 0.029 | 0, 0.5, 1, 1.5, 2, 2.5 | 2 (L+R) |
| 2026-07-10/5 | `opto_bilateralImpulse6` | 0.029 | 0, 0.5, 1, 1.5, 2, 2.5 | 2 (L+R) — main impulse session analyzed |
| 2026-07-15/2 | `opto_Impulse638` | 0.029 | 0, 0.5, 1.5, 2.5 | 2 (L+R) |

## Controller / OL / CL / step / sine (custom rig; states.csv + input_params, no Rigbox Block)
Side = sign of `galvo_x_mm` (**x<0 = LEFT = excitatory; x>0 = RIGHT = inhibitory**, corrected).
The single-hemisphere constant-ref CL sessions are all **INHIBITORY** (the working side). The **excitatory**
data lives in the BOTH-hemisphere OL characterization sessions — including the 06-05/2 step.

**Excitatory (left) OL / step characterization — the excitatory-plot source:**
| date/exp | header fmt | excit(L) / inhib(R) | input | cached? | notes |
|---|---|---|---|---|---|
| **2026-06-05/2** | trial_type | 50 / 50 | **impulse (0.057 s) + STEP (2.0 s)**, amps 0.5/1.0 | no | ⭐ dedicated impulse+**step**, both hemis — the "steps as input" experiment |
| 2026-06-07/1 | spot_idx | 100 / 100 | sustained 1.0 s, amps 0.25/1.0 | no | OL step-like characterization, both hemis |
| 2026-06-20/1 | spot_idx | 100 / 100 | sustained 1.0 s, amps 0.5/1.0 | no | OL step-like characterization, both hemis |
| 2026-06-11/5,6 | spot_idx | 20 / 20 | 1.0 s, low amps | no | thin blocks |
| 2026-06-11/2,3 | staircase_step | 20 / 20 ; 7 / 7 | staircase (stepped amp) OL | no | excitatory staircase-step OL |
| 2026-06-11/1,4 | staircase_step | thin | staircase, amp≈0 | no | aborted/calibration |

**Excitatory CLOSED-LOOP (mode=1) trials DO exist (data-poor, but excit CL WAS attempted):**
| date/exp | excit OL / excit CL | note |
|---|---|---|
| **2026-07-29/1** | 0 / **14** | 14 clean excitatory CL trials (galvo_x<0) — the clean excitatory CL data |
| **2026-07-21/1** | 17 / **34** | 51 excitatory trials inside the mostly-inhibitory sine session; ⚠ **07-21 has the registry-flagged galvo sign-flip** → verify the side of these 51 before trusting |

**Inhibitory (right) constant-ref CL/OL — the working closed-loop side:**
| date/exp | inhib(R) trials | modes | cache |
|---|---|---|---|
| 2026-06-20/2 | 61 | OL+CL | `AL_0048_clol_06202` |
| 2026-06-24/5 | 104 | OL+CL | `AL_0048_clol_06245` |
| 2026-07-14/1 | 214 | OL+CL +traj | — |
| 2026-07-29/2 | 106 | OL+CL | `AL_0048ctrl07292` |
| 2026-07-01/6, 2026-07-21/1 | right | sine FF 4-mode | — (inhibitory sine) |

## Imaging-only / calibration / aborted (not experiments)
- `optoGalvoCalib` dirs on every session date — galvo calibration, not a trial experiment.
- Widefield-imaging-only / aborted exps (no laser params, no controller csv):
  04-22/1,3; 06-12/1–5; 06-23/1,3,5; 06-24/1,2,4; 06-26/1; 07-01/1–4; 07-10/1,3; 07-15/1; 08-19/1,2.

## Data source per plot family
- **grid/**  → `opto_brainGrid638` (06-23, 06-24/3, 07-01/5, 07-10/6) + `opto_brainGridOrange` (04-22/4, excitatory 594). Python `bilateral/grid/`.
- **impulse/** → `opto_bilateralImpulse6` (07-10/2,4,5) + `opto_Impulse638` (07-15/2). Python `bilateral/impulse/`.
- **tf/** → TF fits to the excitatory-left vs inhibitory-right **impulse** responses (from the impulse sessions above).
- **step/** → **RESOLVED.** Primary: **2026-06-05/2** trial_type=1 (2.0 s step) on the excitatory-**LEFT** site (galvo_x<0, ~25 step trials) + its impulse trials as a within-session control. Secondary: excitatory-left OL trials of the 1.0 s characterizations **06-07/1, 06-20/1** (+ thin 06-11/5,6). All show the excitatory step + inhibitory rebound after offset. NONE are cached → needs a fresh load of the excitatory-left pixel. (User: "controller OL trials, one experiment had steps as input" — that experiment is 06-05/2.)
