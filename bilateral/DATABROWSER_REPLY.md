# Reply: closed-loop controller files in AL_0048 sessions

These answers come from the rig code (`StLab_Rainier`: `Main_experiment.py`, `experiment_core/mp_controller.py`, `mp_control.py`, `base_controller.py`) and the brain_paper analysis notes. Versions that apply: the TrackCmp layout came in 16aeda6 (06-15), the FF-analysis layout in dc7e1da (06-26), aa5a6fa (07-15) and a644dc9 (07-22). The control process `mp_control.py` has not changed since 06-15.

**Read columns by name from `input_params_header.csv`, not by position.** The code writes:
`trial_idx, kk, mode, Kref, Kp, Ki, K_preview, previewT_steps, ref, dur, traj_on, traj_mode, traj_amp, traj_hz, galvo_x_mm, galvo_y_mm, ff_analysis_cond`. Note that `ref` is column 9.

## input_params.csv

| Column | Verdict |
|---|---|
| `trial_idx` | **Right.** |
| `kk` | **Wrong: it is the trial END, not the start.** `kk` is the loop's sample counter, read just after the stimulus wait finishes. Onset ≈ `kk − dur·35` (±1–2 samples, because the wait is timed by the PC clock). One `kk` step is two camera frames: the camera runs at 70 Hz with alternating colours, and control runs at 35 Hz. Frame 0 is the first camera frame after the trigger line (Line3) goes high. A true onset column, `kk_onset`, was only added on 2026-08-13. |
| `mode` | **Right for 0 and 1. The "replay" reading is wrong.** 0 = open loop (`u = Kref·R(t)`), 1 = closed loop. In 07-14/1 and 07-21/1, open-loop trials follow a sine reference that is computed online. Each trial is driven by the same sine, so the commands look nearly identical (correlation 0.99). They are not a recorded command played back. A real replay exists only as `mode = 0.5`, and only in Analyze runs that played back the average command from earlier custom trials. |
| `ref` | **Right but incomplete.** See the next section. |
| `Kref`, `Kp`, `Ki` | **Right.** See the control law below. |
| `K_preview`, `previewT_steps` | **Right but incomplete.** `previewT_steps` is counted in control samples of 1/35 s. `K_preview` holds the value set in the GUI, not whether preview was used on that trial. Use `ff_analysis_cond` for that. |
| `dur`, `traj_*` | **Right.** `dur` is the stimulus window in seconds. `traj_mode`: 0 = sine, 1 = sawtooth, 2 = pulse. The sine is `amp·(1 − cos 2πft)`, so it runs from 0 to 2·`traj_amp`, in % dF/F. |
| `galvo_x_mm/y_mm` | **Wrong: the table is not one trial ahead.** The values are logged before the galvo moves, so row i is the site that was active during trial i. The shift you measured probably comes from reading `kk` as the trial start. Each row's `kk` (the trial end) then lies closest to the *next* trial's pulse, so pulse i gets paired with row i−1. That would also explain the odd −1.34 to +0.42 s "offset". Pair rows with pulses again using `kk − dur·35`, or match each row to the `traj_on.csv` epoch whose end is nearest its `kk` (within about 5 samples), then repeat the galvo test. One real exception: after Pick Pixel, the next trial logs the new site and takes feedback from the new ROI, but the laser is still at the old site until that trial ends. |
| `ff_analysis_cond` | **Right but incomplete.** Conditions are drawn at random each trial. **Neither 1 nor 2 is a replay;** both are computed online from the sine. Known bug before 2026-08-13: if an FF run was stopped early, later trials could keep the last condition value. See the table below. |

`ff_analysis_cond` values:

| Value | Condition |
|---|---|
| −1 | Not part of the FF analysis: warm-up, stationary, Analyze and custom trials |
| 0 | Closed loop with preview |
| 1 | Open loop with preview |
| 2 | Open loop without preview ("blind") |
| 3 | Closed loop without preview (PI only) |

## `ref`: units and the two scales

- **Units:** percent dF/F, the same units as `states.csv`.
- **Sign:** the logged value is minus the number typed in the GUI.
  - `−5` means 5 was typed. The loop drives the signal toward −5% (suppression).
  - `+5` means the target is +5% (excitation).
- **`−0.0321`, `−0.0482`, `−0.1275` and the other small values are a logging race, not settings.**
  - During sine trials, `ref` is overwritten every sample with the current value of the trajectory.
  - The row is written before `ref` is reset, so the logged value is the negated sine value at the trial's last sample.
  - Example: with amplitude 2 at 1 Hz, `2·(1 − cos(2π/35)) = 0.0321`.
  - Ignore these as parameters. For sine trials, take the reference from `reference.csv` or `reference_raw.csv`.
- In the June–July code, if the picked pixel was right of bregma, the loop used `−|ref|` as its reference. The logged `ref` does not show that change.

**Control law** (`mp_control.py`), computed each sample:

```
R   = −ref                                  (preview already included)
er  = fb + R                                (fb = online dF/F; fb_sign = +1 throughout June–July)
eri = mean of the last 105 samples of er    (3 s window, reset between trials)
u   = clip(Kref·R + mode·(Kp·er + Ki·eri), 0, 2.45)
```

The P and I terms are each clipped to ±5 before they are summed. `u` is sent to the Arduino as `round(u·100)`. With preview on, the reference becomes `R(k) = r(k) + K_preview·(r(k+d) − r(k))`, where `d = previewT_steps`. There are also velocity and acceleration terms whose gains are not logged.

## Older table layouts

**Right: these are not closed loop.**

- **9 columns** (`kk_start, hemisphere, spot_idx, amplitude, trial_dur, iti`, …). Written by `impulse_bilateral.py`. Protocol: open-loop 1 s steps, with the PID bypassed.
  - `hemisphere`: 0 = left, 1 = right, alternating.
  - `spot_idx`: row in the galvo position table. Left rows come first; right rows are mirrored by negating x.
  - `iti`: the gap drawn for that trial, in seconds (uniform, 4–5 s).
  - `kk_start`: the sample read just before the stimulus starts, so about onset − 1 sample.
  - `trial_type` (0 = impulse, 1 = step) was only in the first version, from 06-05.
- **11 columns** (adds `settling_value, phase, staircase_step`). Written by `characterization.py`. Protocol: a descending amplitude staircase run separately for each side, with 3 s steps alternating between sides.
  - `phase`: 0 = coarse, 1 = fine.
  - `staircase_step`: index of the amplitude within that side's list.
  - `settling_value`: mean dF/F at the end of the step. Builds from 06-12 on subtract the mean before the step.
  - `iti`: the base value only. The real gap was `iti + U(0,1)`.
- **`amplitude`** is the Arduino command, 0–2.45 "volts", on the same scale as `u`. It is not mW, and no conversion exists in the code.
  - From 06-09 to 06-26, left-side amplitudes were logged ×0.25.
  - "Only half the trials have a pulse" fits the alternating sides: left and right probably use different laser channels (594 vs 638 nm).
  - The code does not explain the −2.7 s offset.
- **06-20/2 and 06-20/3** use the TrackCmp layout.
  - `track_cond`: 0 = open loop, 1 = PI only, 2 = PI plus added feedforward, −1 = not part of TrackCmp.
  - `K_ff_trial`: the feedforward gain applied on that trial.

## Q2: per-frame files

All of these are written with `np.savetxt`: space-separated, one line per array row. Each line is padded to **300,000 columns**, and only the first `max(kk)` values are real.

| File | Contents |
|---|---|
| `frames.csv` | Camera frame index 0..i−1, at 70 Hz (twice the control rate). |
| `states.csv` | One line per galvo position (one line in these sessions). It holds the online raw % dF/F of a 10×10 px box at the ROI. Padding is 1.0, not 0. The low-pass-filtered version is not saved. |
| `input_amps.csv` | One line: the laser command `u`. Value k was computed from frame k−1 (Spearman 0.9996 against 0.73 for no lag). |
| `error.csv` | One line: `statedf − ref`, recomputed by the logger. Under the right-hemisphere `−|ref|` override, this can differ from the error the controller actually used. |
| `reference.csv` | One line: the setpoint the controller actually used, `R`, with preview included. |
| `reference_raw.csv` | One line: the raw sine trajectory, and 0 outside sine trials. Present only from 06-26 on. |
| `traj_on.csv` | One line: per-sample flag for whether a trajectory is running. |

How the online dF/F is computed:
- `F` is the mean of the ROI box on the control frames.
- `F0` is the running mean of the last 20 s (700 samples). `F0` is frozen during stimulation, for the stimulated position only.
- `dF/F = (F − F0)·100 / (F0 + 0.001)`.

## Q3: frame 0 and Timeline

Frame 0 is the first frame after the camera trigger line goes high. Up to 5 frames grabbed earlier, during warm-up, are thrown away. The code never reads Timeline. A constant offset within each session is what you'd expect, but the code does not fix how large it is.

## Q4: is the widefield response stored?

No column in `input_params` holds the response. The online response is in `states.csv`. The paper analysis instead rebuilds dF/F offline from the widefield SVD, with hemodynamic correction where it is available. The rebuilt trace matches `states.csv` at r = 0.995.

## Q5: which sessions are closed loop

| Type | Sessions |
|---|---|
| Closed and open loop (17-column table) | 06-24/5, 07-29/2, 07-29/1 (14 excitatory trials, no imaging saved) |
| Sine feedforward experiments (all four conditions) | 07-01/6, 07-14/1, 07-21/1 |
| TrackCmp | 06-20/2 (06-20/3 had no stimulation) |
| Steps and staircases | 06-05 to 06-20/1 |
| Galvo grids | 06-23/2, 06-23/4, 06-24/3, 07-01/5, 07-10/6 |
| Impulse runs (Timeline only) | 06-24/2, 07-10/3, 07-15/1 |

In 07-21/1, rows 208–258 are a separate block on the *left* side with a fixed (non-sine) reference. All of those rows have `ff_analysis_cond` −1.

## Not determinable from the code

- The mW produced per command unit.
- Whether Timeline drives the camera trigger.
- Which way image-x points on the animal. The docs disagree; the analysis treats `galvo_x > 0` as right (inhibitory).
- Which commit ran on a given date. There is no provenance file before 2026-08-13.
