# Presentation — real-time controller demo video

Presentation-grade "live rig" video for talks/PPT. It replays **real closed-loop
controller data** — including the **true widefield brain movie** — through a
white-theme replica of the Rainier live experiment GUI, with controller
performance accumulating in parallel as trials arrive. Two sessions are built:
**m5** (pulse stimulus) and **m13** (step stimulus).

## What it shows

**Left — the "live rig"** (white theme; mirrors `experiment_core/live_plotter.py`):
- **Main: true widefield ΔF/F ACTIVITY movie** — reconstructed frame-by-frame from
  the session SVD and shown as **baseline-subtracted dF/F** (`100·U·(V(τ)−V₀)/mimg`)
  over a **grayscale anatomy underlay**, **masked to the cortical window** (intensity
  threshold → fill-holes → largest blob → Gaussian-smoothed boundary). A diverging
  colormap (with a vertical colorbar) makes dynamic activity pop — the ROI region goes
  blue (suppressed) during stim. Only the **control-ROI □** is marked; it glows while
  the laser is on. **Mask override:** if `assets/mask_<session>.npy` exists (drawn with
  `draw_mask.py`) it is used instead of the auto mask.
  (Face/pupil camera panels + the face-motion trace were removed for a cleaner,
  performance-focused layout; `build_cam_movies.py` / `cam_movies.npz` remain, unused.)
- **Calibration HUD** — a small static card fixed to the closed-loop settings:
  Ref (−5 %ΔF/F), Kp, Ki, Kref (the real CL-median gains).
- Scrolling **ΔF/F feedback** vs the −5 reference; **laser amplitude** (the
  command-envelope, i.e. the sine/pulse *amplitude*, not the raw carrier); and
  **tracking error**. The 0–3 s stim window is shaded on every trace panel.
- A **TRIAL n/N · CLOSED-/OPEN-LOOP** banner streaming trial after trial.

**Right — performance in parallel:**
- **Trial-averaged response**: *every individual trial* drawn (thin, coloured by
  loop) plus the bold running CL/OL means. Closed-loop holds −5 %; open-loop overshoots.
- **Trial-to-trial variance over time** (same time axis as the trial-average): the
  across-trial variance at each timepoint, for CL vs OL, **evolving** as trials
  accumulate. CL sits below OL through the stim hold — the controller suppresses
  trial-to-trial variability.

## Data sources

- **m5 = AL_0033, 2025-03-04** (`data/AL_0033ctrl03041.mat`), 60 trials
  (36 OL / 24 CL), **pulse** stimulus, ~28% CL-vs-OL gap.
- **m13 = AL_0039, 2025-04-20** (`data/AL_0039ctrl04202.mat`), 100 trials
  (55 OL / 45 CL), **step** stimulus, ~30% CL-vs-OL gap (best of the 7
  movie-bearing sessions; see `make_session_previews.py` for the full ranking).

Both brain-movie bundles (`assets/m5_bundle.mat`, `assets/m13_bundle.mat`) are the
SVD `U`→140×140×200 block-average + per-trial `V` windows, exported from the
multi-GB controller caches in MATLAB (`frame = mimg + U·V(τ)`; V windows aligned to
onset frames via `timeBlue`/`stimStarts`, verified corr≈0.999 vs the ROI ΔF/F).

## Rebuild

```bash
# 0. (one-time) export each session's SVD movie bundle from the multi-GB cache in
#    MATLAB -> assets/<key>_bundle.mat  (block-avg U to 140x140x200 + per-trial V
#    windows; see the RESEARCH.md 2026-07-13 m13 entry for the MATLAB snippet)

# 1. assemble the per-session data bundle (assets/demo_data_<key>.npz)
.venv/Scripts/python.exe presentation/build_demo_data.py --session m5
.venv/Scripts/python.exe presentation/build_demo_data.py --session m13

# 2. render  (both modes play EVERY trial — short is a quick 900p copy, full is 1080p)
.venv/Scripts/python.exe presentation/make_video.py --session m5  --mode full --hd
.venv/Scripts/python.exe presentation/make_video.py --session m13 --mode full --hd
```

Outputs `presentation/controller_demo_<key>_<mode>[_hd].mp4`.
(H.264, drops into PowerPoint/Keynote.)

## Notes / honesty

- Illustrative replay/reconstruction, not a raw screen capture. All traces, gains,
  MSE, and the widefield movie are **real session data**; the layout is restyled for
  presentation.
- m5 uses a **pulse-train** stimulus, m13 a **step**; the laser panel shows the
  command **amplitude envelope** (sliding-window max, w=250, in `build_demo_data.py`),
  not the raw carrier — for CL trials this is the controller's modulated drive, for
  OL trials a flat level.
- To add another session: export its `<key>_bundle.mat` from MATLAB (see the
  RESEARCH.md 2026-07-13 m13 entry), then
  `build_demo_data.py --session <key>` and `make_video.py --session <key> …`.
- `draw_mask.py --session <key>` — hand-draw the brain mask (polygon) if the auto
  mask isn't clean; saves `assets/mask_<key>.npy`, which make_video then uses.
- Extra tooling kept for reference: `make_session_previews.py` (per-session
  performance previews + CL/OL ranking → `session_previews/`), `make_trial_clips.py`
  (per-trial clips → `clips/`), `build_cam_movies.py` (+ `cam_movies.npz`, the
  now-unused face/pupil extraction).
- ffmpeg is provided by the `imageio-ffmpeg` pip package (no system ffmpeg needed).
