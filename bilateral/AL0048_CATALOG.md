# AL_0048 — experiment catalogue

Every experiment folder under `\\sahale…\Subjects\AL_0048\`, auto-generated from the
**raw 2 kHz Timeline** (`lightCommand594/638`, `galvoX/Y`) rather than from `input_params.csv`.
That is deliberate: the Signals runs (`opto_bilateralImpulse638`, `opto_brainGrid638`,
`opto_Impulse638`) ship no `input_params.csv` at all, and the ones that do use four different
column layouts across rig builds — the Timeline is the only source common to all 47 experiments.

**Side convention (locked):** `galvoX < 0` → **LEFT = excitatory**; `galvoX > 0` → **RIGHT = inhibitory**.
Verified against the 2026-07-15 impulse polarity (left +dF/F monotonic in amplitude, right −dF/F).

**To open any row:** set `SESS_DATE`/`SESS_EXP` in [`bil_pick_viewer.m`](bil_pick_viewer.m), run it
once to print that session's trial-type menu, then set `SEL` and re-run to launch
`pixelTuningCurveViewerSVD`. Rows with imaging *not saved* have trials but cannot be viewed.

**Stim kind** is inferred from the bout-duration distribution: `impulse` = median < 0.1 s,
`modulated` = >3 sub-pulses per bout (sine/carrier), `constant step` = >60 % of bouts flat
(within-bout command SD < 0.05 V), else `continuous/closed-loop`.

## Master table

| date | exp | run type | imaging | trial log | laser | stim kind | bouts (L/R) |
|---|---|---|---|---|---|---|---|
| 2026-04-22 | 1 | Timeline only | none | — | — | no stim | — |
| 2026-04-22 | 2 | `opto_miniGrid` (Signals) | none | Block.mat | — | no stim | — |
| 2026-04-22 | 3 | Timeline only | none | — | — | no stim | — |
| 2026-04-22 | 4 | `opto_brainGridOrange` (Signals) | none | Block.mat | — | no stim | — |
| 2026-06-05 | 1 | Timeline only | camera ran, **not saved** | — | 594 nm | constant step | **13** (6/7) |
| 2026-06-05 | 2 | opto/controller, 9-col build | SVD + **corr**, 18874 fr | 100×9 | 594 nm | impulse (single-frame pulses) | **100** (50/50) |
| 2026-06-07 | 1 | opto/controller, 9-col build | SVD, blue only, 41083 fr | 200×9 | 594 nm | constant step | **200** (100/100) |
| 2026-06-11 | 1 | Timeline only | SVD + **corr**, 3385 fr | 1×0 | — | no stim | — |
| 2026-06-11 | 2 | controller, 12-col build | SVD + **corr**, 1777 fr | 40×12 | — | no stim | — |
| 2026-06-11 | 3 | controller, 12-col build | SVD + **corr**, 6392 fr | 14×12 | — | no stim | — |
| 2026-06-11 | 4 | opto/controller, 9-col build | SVD + **corr**, 2654 fr | 7×9 | 594 nm | constant step | **6** (2/4) |
| 2026-06-11 | 5 | opto/controller, 9-col build | SVD + **corr**, 10275 fr | 40×9 | 638 nm | constant step | **20** (0/20) |
| 2026-06-11 | 6 | opto/controller, 9-col build | SVD + **corr**, 14863 fr | 40×9 | 638 nm | constant step | **40** (20/20) |
| 2026-06-12 | 1 | Timeline only | camera ran, **not saved** | — | — | no stim | — |
| 2026-06-12 | 2 | Timeline only | camera ran, **not saved** | — | — | no stim | — |
| 2026-06-12 | 3 | Timeline only | camera ran, **not saved** | — | — | no stim | — |
| 2026-06-12 | 4 | Timeline only | SVD + **corr**, 31564 fr | — | 638 nm | continuous / closed-loop | **70** (0/70) |
| 2026-06-12 | 5 | Timeline only | camera ran, **not saved** | — | 638 nm | constant step | **150** (75/75) |
| 2026-06-20 | 1 | opto/controller, 9-col build | SVD + **corr**, 40438 fr | 200×9 | 638 nm | constant step | **200** (100/100) |
| 2026-06-20 | 2 | controller, 18-col build | SVD + **corr**, 27361 fr | 61×18 | 638 nm | constant step | **61** (0/61) |
| 2026-06-20 | 3 | controller, 18-col build | none | 6×18 | — | no stim | — |
| 2026-06-23 | 1 | Timeline only | camera ran, **not saved** | — | 638 nm | impulse (single-frame pulses) | **1848** (655/1193) |
| 2026-06-23 | 2 | `opto_brainGrid638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-06-23 | 3 | Timeline only | camera ran, **not saved** | — | 638 nm | impulse (single-frame pulses) | **138** (48/90) |
| 2026-06-23 | 4 | `opto_brainGrid638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-06-23 | 5 | Timeline only | camera ran, **not saved** | — | — | no stim | — |
| 2026-06-24 | 1 | Timeline only | camera ran, **not saved** | — | — | no stim | — |
| 2026-06-24 | 2 | Timeline only | SVD + **corr**, 95249 fr | — | 638 nm | impulse (single-frame pulses) | **1843** (452/1391) |
| 2026-06-24 | 3 | `opto_brainGrid638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-06-24 | 4 | Timeline only | camera ran, **not saved** | — | 638 nm | modulated (sine / carrier) | **2** (0/2) |
| 2026-06-24 | 5 | controller, 17-col FFA build | SVD + **corr**, 44551 fr | 104×17 | 638 nm | continuous / closed-loop | **106** (0/106) |
| 2026-06-26 | 1 | Timeline only | camera ran, **not saved** | — | 638 nm | modulated (sine / carrier) | **119** (0/119) |
| 2026-07-01 | 1 | Timeline only | camera ran, **not saved** | — | 638 nm | constant step | **5** (0/5) |
| 2026-07-01 | 2 | Timeline only | camera ran, **not saved** | — | 638 nm | continuous / closed-loop | **17** (0/17) |
| 2026-07-01 | 3 | Timeline only | camera ran, **not saved** | — | — | no stim | — |
| 2026-07-01 | 4 | Timeline only | SVD + **corr**, 95825 fr | — | 638 nm | continuous / closed-loop | **2269** (1782/487) |
| 2026-07-01 | 5 | `opto_brainGrid638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-07-01 | 6 | controller, 17-col FFA build | SVD + **corr**, 47244 fr | 87×17 | 638 nm | modulated (sine / carrier) | **113** (0/113) |
| 2026-07-10 | 1 | Timeline only | camera ran, **not saved** | — | 638 nm | impulse (single-frame pulses) | **1** (0/1) |
| 2026-07-10 | 2 | `opto_bilateralImpulse638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-07-10 | 3 | Timeline only | SVD + **corr**, 203357 fr | — | 638 nm | impulse (single-frame pulses) | **2800** (774/2026) |
| 2026-07-10 | 4 | `opto_bilateralImpulse638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-07-10 | 5 | `opto_bilateralImpulse638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-07-10 | 6 | `opto_brainGrid638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-07-14 | 1 | controller, 17-col FFA build | SVD + **corr**, 113302 fr | 214×17 | 638 nm | modulated (sine / carrier) | **364** (0/364) |
| 2026-07-15 | 1 | Timeline only | SVD + **corr**, 154176 fr | — | 638 nm | impulse (single-frame pulses) | **600** (300/300) |
| 2026-07-15 | 2 | `opto_Impulse638` (Signals) | none | Block.mat | — | no stim | — |
| 2026-07-21 | 1 | controller, 17-col FFA build | SVD + **corr**, 150013 fr | 258×17 | 638 nm | continuous / closed-loop | **375** (49/326) |
| 2026-07-29 | 1 | controller, 17-col FFA build | camera ran, **not saved** | 84×17 | 638 nm | continuous / closed-loop | **84** (15/69) |
| 2026-07-29 | 2 | controller, 17-col FFA build | SVD, blue only, 54828 fr | 106×17 | 638 nm | continuous / closed-loop | **107** (0/107) |

## Excitatory (LEFT) trial types — the analysable inventory

Every left-hemisphere trial type with **n ≥ 5 and saved widefield**. A *type* is
(hemisphere, galvo site binned to 0.5 V, command level binned to 0.1 V); duration is
reported, not grouped on, because it jitters by a frame on pulsed runs and varies
continuously on closed-loop runs.

| date | exp | laser | corr? | galvoX | cmd | n | duration | shape |
|---|---|---|---|---|---|---|---|---|
| 2026-06-05 | 2 | 594 | ✔ | -1.5 V | 3.4 V | **30** | 0.029 s (0.01–1.97) | impulse ⚠ **split by duration** |
| 2026-06-05 | 2 | 594 | ✔ | -1.5 V | 1.7 V | **20** | 0.029 s (0.02–1.97) | impulse ⚠ **split by duration** |
| 2026-06-07 | 1 | 594 | — | -1.0 V | 0.8 V | **47** | 0.972 s (0.95–0.99) | CONSTANT step |
| 2026-06-07 | 1 | 594 | — | -0.5 V | 0.8 V | **31** | 0.971 s (0.95–0.99) | CONSTANT step |
| 2026-06-07 | 1 | 594 | — | -2.0 V | 0.8 V | **22** | 0.972 s (0.95–0.99) | CONSTANT step |
| 2026-06-11 | 6 | 638 | ✔ | -0.5 V | 0.4 V | **20** | 0.972 s (0.96–0.99) | CONSTANT step |
| 2026-06-20 | 1 | 638 | ✔ | -2.5 V | 3.4 V | **55** | 0.972 s (0.96–0.99) | CONSTANT step |
| 2026-06-20 | 1 | 638 | ✔ | -2.5 V | 1.7 V | **45** | 0.972 s (0.95–0.99) | CONSTANT step |
| 2026-06-24 | 2 | 638 | ✔ | -0.5 V | 1.4 V | **187** | 0.024 s (0.02–0.02) | impulse |
| 2026-06-24 | 2 | 638 | ✔ | -1.5 V | 1.4 V | **153** | 0.024 s (0.02–0.02) | impulse |
| 2026-06-24 | 2 | 638 | ✔ | -2.5 V | 1.4 V | **112** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | +0.0 V | 0.9 V | **836** | 0.603 s (0.25–5.10) | modulated ⚠ **split by duration** |
| 2026-07-01 | 4 | 638 | ✔ | +0.0 V | 1.4 V | **457** | 0.783 s (0.27–4.19) | modulated ⚠ **split by duration** |
| 2026-07-01 | 4 | 638 | ✔ | -0.5 V | 1.4 V | **82** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | -1.5 V | 0.9 V | **72** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | -0.5 V | 0.9 V | **70** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | -1.5 V | 1.4 V | **68** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | -2.5 V | 0.9 V | **61** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | -3.5 V | 1.4 V | **54** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | -2.5 V | 1.4 V | **44** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-01 | 4 | 638 | ✔ | -3.5 V | 0.9 V | **38** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -2.0 V | 0.7 V | **107** | 0.024 s (0.02–0.03) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -2.0 V | 1.3 V | **104** | 0.024 s (0.02–0.03) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -0.5 V | 0.7 V | **74** | 0.023 s (0.02–0.02) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -1.0 V | 1.3 V | **72** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -1.0 V | 0.7 V | **71** | 0.023 s (0.02–0.02) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -0.5 V | 1.3 V | **67** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -2.0 V | 1.6 V | **56** | 0.028 s (0.03–0.03) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -2.0 V | 1.0 V | **56** | 0.027 s (0.03–0.03) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -2.0 V | 0.3 V | **56** | 0.026 s (0.03–0.03) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -3.0 V | 0.7 V | **50** | 0.023 s (0.02–0.02) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -3.0 V | 1.3 V | **44** | 0.024 s (0.02–0.02) | impulse |
| 2026-07-10 | 3 | 638 | ✔ | -2.0 V | 0.6 V | **7** | 0.026 s (0.02–0.03) | impulse |
| 2026-07-15 | 1 | 638 | ✔ | -2.0 V | 1.0 V | **100** | 0.027 s (0.03–0.03) | impulse |
| 2026-07-15 | 1 | 638 | ✔ | -2.0 V | 0.3 V | **100** | 0.026 s (0.03–0.03) | impulse |
| 2026-07-15 | 1 | 638 | ✔ | -2.0 V | 1.6 V | **100** | 0.028 s (0.03–0.03) | impulse |
| 2026-07-21 | 1 | 638 | ✔ | -2.0 V | 3.4 V | **31** | 3.000 s (2.98–3.03) | CONSTANT step |
| 2026-07-21 | 1 | 638 | ✔ | -2.0 V | 4.5 V | **10** | 3.000 s (2.98–3.03) | CONSTANT step |
