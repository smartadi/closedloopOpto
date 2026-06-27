# Bilateral Analysis — Session Context

## Mouse
- **AL_0048** — dual opsin: excitatory (left hemisphere), inhibitory (right hemisphere)
- Galvo position is fixed per trial; hemisphere identity read from `input_params` (bregma coords: positive = left/excitatory, negative = right/inhibitory)
- Polarity convention is **switchable** — set `SIGN_L = +1; SIGN_R = -1` at top of each script; flip if data says otherwise

## Sub-area trigger words
bilateral, AL_0048, dual opsin, excitatory left, inhibitory right, galvo position, variable ref, controller tuning, grid sweep, gradient descent

## Related: AL_0048 galvo photostim site-grid (`opto_brainGrid638`)
Separate from the CL/OL controller work above: a 52-position 638 nm photostim *spatial-mapping*
grid. Python analysis (runs in repo `.venv`, not MATLAB) → **`scratch_grid/grid_analysis.py`**;
full handoff in **`scratch_grid/README.md`**. Confirmed dual-opsin polarity (excit-left +/red,
inhib-right −/blue); only the 0.5 laser power fired (0.25 sub-threshold). Run on AL_0048
2026-06-24/2 (widefield+Timeline) with exp 3 = Block/expDef/hardwareInfo (calibration).

## Scripts (run from brain_paper/ root)
- `load_bilateral.m`     — session registry, per-side pixel coords, data loading + caching
- `ol_characterization.m` — OL impulse + step response, both sides
- `cl_constant_ref.m`    — CL constant-reference controller, both sides
- `cl_tuning.m`          — Kp/Ki grid sweep + gradient descent on top, both sides
- `cl_sinewave.m`        — feedforward/preview sine-wave controller, both sides
- `compare_sides.m`      — cross-side summary figures

## Session loading pipeline
Same as controller area: `initialize_data → getpixel_dFoF → bilateralData → cache to data/<session>_bil.mat`
Cache key: `sprintf('%s_bil_%s%d.mat', mn, td(6:7), en)`

## Stim detection — UNDECIDED (choose one when data arrives)
Two options tracked in `load_bilateral.m` under `STIM_MODE`:
- **Mode A** — use `input_params` server timestamps directly (column TBD; most precise if server clock is synced)
- **Mode B** — use timeline input-application trace (threshold crossing); robust if server timestamps drift
- **Mode C** — intersection of both (A as seed, B as validation); recommended if jitter > 1 frame
Set `STIM_MODE = 'A'` (placeholder) at top of `load_bilateral.m`; swap to `'B'` or `'C'` without touching downstream scripts.

## Per-trial metadata — `sess.trial_meta`
Every session produces a struct array (one entry per trial) with fields:
- `.trial_idx` — index into `d.stimStarts`
- `.side` — `'left'` | `'right'` | `'unknown'`  (from `BREGMA_COL`)
- `.stim_type` — `'impulse'` | `'step'` | `'cl_const'` | `'cl_tune'` | `'sinewave'` | `'unknown'`  (from `STIM_TYPE_COL` + `STIM_TYPE_MAP`)
- `.amplitude` — numeric value from `AMP_COL`

Downstream scripts filter with logical masks on `trial_meta`, e.g.:
```matlab
mask = strcmp({sess.trial_meta.side}, 'left') & strcmp({sess.trial_meta.stim_type}, 'impulse');
trials = [sess.trial_meta(mask).trial_idx];
```
A session can contain any mix of stim types — no `exp_type` tag at session level.

## Galvo / side convention (locked)
`galvo_x_mm > 0` → **right** hemisphere (inhibitory opsin)
`galvo_x_mm < 0` → **left** hemisphere (excitatory opsin)

## Reference polarity
- Left (excitatory): `d.ref > 0` (default `+5`, switchable via `REF_L`)
- Right (inhibitory): `d.ref < 0` (default `−5`, switchable via `REF_R`)
Both are top-of-script knobs — do not hard-code into analysis sections.

## Controller tuning (cl_tuning.m)
- Grid sweep: Kp × Ki 2D, PI controller only (no Kd until justified by data)
- Gradient descent: numerical finite-difference on offline MSE surface, initialised at grid minimum
- MSE metric: same window as controller area — **t = 0 s to +3 s** default

## Locked-in decisions (subject to update as data arrives)
- `motThresh = 1.5` (same as controller area, revisit if excitatory side has different motion profile)
- Offline only — no live-acquisition interface
- Cache flag: `r_bil = 1` to load; `r_bil = 0` to recompute

## Export paths
`paper/images/bilateral/` — panels BL-*, BR-* for left/right respectively

## input_params column map (confirmed 2026-06-06)
| col | name | used for |
|---|---|---|
| 1 | trial_idx | — |
| 2 | kk_start | stim onset sample index |
| 3 | trial_type | `STIM_TYPE_COL` — codes TBD |
| 4 | hemisphere | `HEMISPHERE_COL` — side assignment |
| 5 | amplitude | `AMP_COL` |
| 6 | trial_dur | — |
| 7 | iti | — |
| 8 | galvo_x_mm | `GALVO_X_COL` — cross-check for hemisphere |
| 9 | galvo_y_mm | — |

## Open questions (update as resolved)
1. trial_type numeric codes for impulse / step / cl_const → fill `STIM_TYPE_MAP` in `load_bilateral.m`
2. hemisphere column encoding — confirm +1=left / -1=right (or flip `SIGN_L`/`SIGN_R`)
3. Best stim detection mode for AL_0048 → set `STIM_MODE`
4. Decide whether bilateral trials (both hemispheres in one experiment) will be used
