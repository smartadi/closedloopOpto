# impulse-analysis/archive/

Superseded residual/stim-blind **entry-point scripts**, archived 2026-08-25 so the
residual-error story has **one** runnable script: `../ols_tf_pipeline.m`.

Nothing here is deleted — files are `git mv`'d, recoverable from history, and this
folder is **off the MATLAB path** (`load_experiments.m` adds `impulse-analysis/`
non-recursively), so these scripts cannot run or shadow anything by accident.

## What's here and why it was retired

| File | Was | Retired because |
|---|---|---|
| `contra_prediction.m` | The CP-* residual/state workbench (Actual/Global/Local, bleed/clean/stimaffect/predq controls) | Superseded by `ols_tf_pipeline.m` (§17d SELECT is the sole stim-blind model since 2026-07-18). Its reviewer-defense control analyses (`[CP-BLEEDCTRL]`, `[CP-CLEAN]`, `[CP-STIMAFF]`, `[CP-PREDQ]`) are NOT replicated in the pipeline — restore this script to regenerate them. |
| `ols_pixel_predictor.m` | Standalone direct-pixel contra→ipsi OLS (frozen 2026-07-04 projection version) | Superseded by `ols_tf_pipeline.m`. |
| `ols_pixel_predictor_wip.m` | WIP repair copy; the clean pipeline was extracted from it 2026-07-13 | Its GREEDY/NATIVE/NAIVE stim-blind models enforce dip-blindness by construction → capture number is uninformative. Do NOT quote its numbers. |
| `kernelmap_paint.m` | Kernel-map painting tool | Its only prerequisite (`ols_pixel_predictor_wip.m`) is archived; cannot run without it. |

## The one script (kept)

`../ols_tf_pipeline.m` — SETUP → TF affected-detection → §17d **SELECT** (sole
stim-blind model) → §17c/§17c2 residual state-dependence → §18 cross-session batch.

Run the whole story headless:

```matlab
load_experiments                 % once: loads data (slow, reads the server; does its own clear all)
RUN_ALL = true; ols_tf_pipeline  % validate: SELECT → state-dep → §18 batch → pooled state-dep
```

Diagnosis (confirm each session's stim-blind model one-by-one, then the pooled state-dep):

```matlab
RUN_ALL = true; RUN_MODE = 'diagnose'; ols_tf_pipeline
```

The pooled cross-session state-dependence (`imp_state_xsess`) is folded into the §18 tail
(`RUN_XSESS`, default true). A new session's ROI is drawn once with `../cp_draw_roi.m`.

## To restore any file

```bash
git mv impulse-analysis/archive/<file>.m impulse-analysis/<file>.m
```

Its `utils/` helpers were deliberately left in place (still on the path), so a restored
script works immediately. Helpers used only by `contra_prediction.m`
(`cp_cont_state`, `cp_motion_amp`, `cp_res_inspector`, `cp_clean_predict`, `cp_cleanres`,
`cp_stimaffect`, `cp_pixel_recon`) are now dormant but harmless.
