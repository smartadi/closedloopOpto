# NeuroAI deck — figure updates (drop into Keynote on the Mac)

All PNGs are 300 dpi, transparent-safe. Keynote: just drag the file onto the slide, size to match.
Deck stays `.key` — nothing here changes the format.

## 1. State-dependence plots — REPLACE the two you already have
Your deck currently shows `P1_imp_state_var_motion` and `P3_imp_state_var_prevar`.
Swap them for these updated, y-normalized versions (canonical brain-state = relative 2–4 Hz):

- `01_statedep_motion.png`      → replaces the **motion** panel.  Say: prediction error rises with movement, **p=1.5e-7, 4/4 sessions**.
- `02_statedep_rhythm_2-4Hz.png`→ replaces the old **pre-stim-variance** panel (now the 2–4 Hz rhythm). Say: **p=0.005, 3/4 sessions**.
  (Note: this is now the *relative 2–4 Hz* definition, not pre-stim variance — that's the change.)

## 2. Figure 4 — NEW slide(s) (controller-error → brain state)
Headline: the closed loop removes the error it can *see*, not the ongoing rhythm.

- `11_f4_decomp_schematic.png`  — the Global/Local decomposition diagram (lead with this).
- `12_f4_error_states_avg.png`  — the three factors driving closed-loop error.
- `13_f4_state_initdev.png`     — initial deviation: **no** state-dependence (p=0.78) → controller cancels it.
- `14_f4_state_motion.png`      — motion-driven error **decoupled** by the loop (p≈0.001).
- `15_f4_state_rhythm.png`      — 2–4 Hz rhythm **survives** the loop (p≈0.013).
- `16_f4_disturb_rejection.png` — per-session disturbance rejection (real but modest, ~7% of the fluctuation).
- `17_f4_stats_mixedeffects.png`— referee-proof mixed-effects stats (back-pocket / backup slide).
- `10_Figure4_composite.png`    — the whole finalized Figure-4 as one image, if you'd rather show it assembled.

## 3. Clean MPC results — NEW slide(s) (replaces any old MPC numbers)
This is the Sept-15 reconvened analysis on the correct post-onset (+1..+3 s) window.

- `20_mpc_example_traces.png` — tube-MPC vs PI rollout; MPC (blue) holds the −5 target, PI (black) drifts.
- `22_mpc_improvement.png`    — residual vs forecast quality. A realistic forecaster (AR/PatchTST, Lu et al.)
                               lands at **~0.82 RMSE ratio to PI ≈ 88% of the ideal benefit**; real forecast noise costs little.
- `21_mpc_horizon_sweep.png`  — look-ahead sweep: **flat from 200 ms out to 1 s** → forecast *accuracy* matters, not horizon.

One-liner for the talk: "Even a realistic learned forecaster buys ~88% of the ideal disturbance-rejection
benefit over the current PI controller — and 200 ms of look-ahead is already enough."
