# Closed-loop Figure 3 export: per-trial controller data

From Aditya (brain_paper repo, commit `b989df1`, branch `alpha`), 2026-11-05, for Anna Li's figure-skill evals.

## Location

```
\\sahale.biostr.washington.edu\data\temp\closedloop_fig3_export\
```

- 15 `.mat` files, one per controller session, named like the source caches (`<mouse>ctrl<MMDD><exp>.mat`), plus `MANIFEST.txt`.
- 64.2 MB in total; 1.3–9.5 MB per file (4.3 MB average).
- All 15 sessions exist; none is missing. Each written file was reloaded and matched its source cache field by field (names, order, class, size, values). Nothing failed verification.
- `MANIFEST.txt` in the folder has the full per-session field lists with sizes.

## What each file contains

| variable | contents |
|---|---|
| `data` | The cache's per-trial `data` struct, unchanged. |
| `d` | A small struct holding ONLY `d.ref` (all 15) and `d.provenance` (9 of 15). It is NOT the full `d` from the cache: there is no `timeBlue`, `params`, `motion`, etc. |

Files are MATLAB `-v7.3` (HDF5).

- MATLAB: `S = load(f); data = S.data; d = S.d;`
- Python (`h5py` or `mat73`): 2-D arrays come out transposed relative to MATLAB, e.g. `ncDfk` is `176 x nTrials`. `d.provenance.stamped_utc` is a MATLAB `datetime` object, which Python readers generally cannot decode; skip it or read it in MATLAB.

## Sessions

`nc` = open loop (controller off), `wc` = closed loop (controller on). The paper labels are the manuscript's session names. The m-numbers are internal ids from `load_sessions.m`.

| id | paper label | file | mouse | date | exp | OL / CL trials | file MB | median RMSE OL / CL (%ΔF/F) | `d.provenance` | motion |
|---|---|---|---|---|---|---|---|---|---|---|
| m1 | Mouse 1a | AL_0033ctrl01203.mat | AL_0033 | 2025-01-20 | 3 | 56 / 64 | 5.91 | 3.18 / 2.74 | yes | none (zeros) |
| m2 | Mouse 1c | AL_0033ctrl02122.mat | AL_0033 | 2025-02-12 | 2 | 97 / 103 | 9.53 | 3.66 / 3.43 | yes | yes |
| m3 | Mouse 1d | AL_0033ctrl02242.mat | AL_0033 | 2025-02-24 | 2 | 101 / 99 | 8.01 | 3.41 / 2.80 | yes | none (zeros) |
| m4 | Mouse 1e | AL_0033ctrl02262.mat | AL_0033 | 2025-02-26 | 2 | 92 / 108 | 8.45 | 2.29 / 2.03 | yes | yes |
| m5 | Mouse 1f | AL_0033ctrl03041.mat | AL_0033 | 2025-03-04 | 1 | 36 / 24 | 2.69 | 2.28 / 1.71 | yes | yes |
| m6 | Mouse 1h | AL_0033ctrl03052.mat | AL_0033 | 2025-03-05 | 2 | 14 / 16 | 1.34 | 2.08 / 1.51 | yes | yes |
| m7 | Mouse 1j | AL_0033ctrl03204.mat | AL_0033 | 2025-03-20 | 4 | 46 / 54 | 4.07 | 2.52 / 2.14 | yes | none (zeros) |
| m8 | Mouse 1k | AL_0033ctrl04152.mat | AL_0033 | 2025-04-15 | 2 | 38 / 22 | 2.37 | 2.56 / 1.90 | yes | none (zeros) |
| m9 | Mouse 2b | AL_0039ctrl04201.mat | AL_0039 | 2025-04-20 | 1 | 50 / 50 | 2.91 | 2.43 / 2.04 | no | yes |
| m10 | Mouse 2a | AL_0039ctrl04191.mat | AL_0039 | 2025-04-19 | 1 | 48 / 52 | 3.10 | 2.40 / 1.78 | no | yes |
| m11 | Mouse 2d | AL_0039ctrl04303.mat | AL_0039 | 2025-04-30 | 3 | 50 / 50 | 2.91 | 2.73 / 2.14 | no | yes |
| m12 | Mouse 1l | AL_0033ctrl04191.mat | AL_0033 | 2025-04-19 | 1 | 35 / 65 | 3.04 | 1.91 / 1.63 | no | yes |
| m13 | Mouse 2c | AL_0039ctrl04202.mat | AL_0039 | 2025-04-20 | 2 | 55 / 45 | 3.10 | 2.74 / 1.91 | no | yes |
| m14 | Mouse 3e | AL_0048ctrl07292.mat | AL_0048 | 2026-07-29 | 2 | 45 / 55 | 3.43 | 3.38 / 3.07 | yes | yes |
| m15 | Mouse 4 | AL_0051ctrl07292.mat | AL_0051 | 2026-07-29 | 2 | 55 / 45 | 3.37 | 2.77 / 2.23 | no | yes |

## Field key (`data`)

Imaging is 35 Hz and the laser is on for 3 s in every trial. The window widths below were checked in all 15 sessions.

| field | shape | meaning |
|---|---|---|
| `nc`, `wc` | trials x 1 | Trial numbers (rows of the rig's `input_params`) of the open-loop and closed-loop trials. |
| `dFk` | 1 x frames | Whole-session %ΔF/F at the controlled site, one sample per frame. |
| `ncDfk`, `wcDfk` | trials x 176 | %ΔF/F from −1 s to +4 s; laser onset at column 36. |
| `pncDfk`, `pwcDfk` | trials x 561 | %ΔF/F from −10 s to +6 s; laser onset at column 351. |
| `ncmotion`, `wcmotion` | trials x 176 | Face motion energy from −2 s to +3 s; onset at column 71. All zeros in m1, m3, m7 and m8 (no face video). |
| `ncInp`, `wcInp` | trials x 6001 | Laser command at 2 kHz, 0 to +3 s. |
| `er_ncDfk`, `er_wcDfk` | trials x 1 | Per-trial RMSE about the reference (`d.ref` = −5 %ΔF/F) over 0 to +3 s, in %ΔF/F. |
| `vr_ncDfk`, `vr_wcDfk` | trials x 1 | Per-trial variance over 0 to +3 s. |
| `ncFreqPow`, `wcFreqPow` | trials x 13 x 20 | Absolute power: 13 time bins (1 s hop, 2 s Hann window) x 20 bands (0.5 Hz wide, 0–10 Hz). **Missing in m9–m13.** |
| `ncFreqSpec`, `wcFreqSpec` | trials x 13 x 20 | The same, as a fraction of 0–10 Hz power. Present in all 15. |
| `freqBandCtrs` | 1 x 20 | Band centres (Hz). |
| `freqOnsetBin` | 1 x 1 | Time-bin column of laser onset in the FreqPow/FreqSpec arrays. |
| `F` | 1 x frames | **m14 and m15 only.** The site's fluorescence from the widefield SVD reconstruction, with the mean image not added back (near zero, can be negative). `dFk` was computed from it. |
| `dff_mode`, `dff_w` | 1 x 1 | **m14 and m15 only.** The ΔF/F method (2) and baseline length (1400) that produced `dFk`. |

## Pitfalls for automated use

1. **The field set differs between sessions, so index fields by name, never by position:**
   - `ncFreqPow`/`wcFreqPow` are absent in m9–m13.
   - `F`, `dff_mode` and `dff_w` exist only in m14 and m15.
   - Field order also varies.
2. **Class:** `dFk` is `single` in m2 and `double` in every other session.
3. **ΔF/F is the same definition in all 15 sessions:** (F − trailing mean) / trailing mean × 100, with a 1400-frame (40 s) trailing window. That is the controller's own online window, so `dFk` is the signal the loop fed back on. m1–m13 are computed from the raw frames and m14–m15 from the SVD reconstruction.
4. **`d.provenance` exists in 9 of 15 sessions (m1–m8, m14):**
   - Its fields are `stamped_utc`, `reason`, `dff_mode`, `dff_w`, `slim` and `git`.
   - In m1–m8, `dff_mode` is NaN, meaning it was not recorded (it was not guessed); `dff_w` is 1400 and the reason is "onset fix 2026-10-27".
   - In m14, `dff_mode` is 2.
   - The other six caches were written before the stamp existed (on or before 2026-10-02).
5. **m14 (AL_0048) is already aligned.** Its `dFk` was padded by the project's onset fix. Do not apply any further frame shift: an extra 11-frame shift produced wrong numbers once (2026-11-02).
6. **Motion is all zeros, not missing, in m1, m3, m7 and m8.** Treat it as absent; don't read it as zero motion.
7. **Reference:** `d.ref` = −5 %ΔF/F in all 15 sessions.

## Which sessions Figure 3 pools

- **Figure 3 pools all 15 sessions, m1 and m13 included.** Both have a controller cache, and the Figure 3 scripts use every session whose cache loads.
- **Panel split:** the paper is not published yet; in the current JNeurosci draft, Figure 3E and G–I pool all 15 sessions, and Figure 3A–D and F show one session, Mouse 2a (m10).
- **The README's former "skipped, no cache" for m1 and m13 meant the Stage-1/2 contralateral predictor cache, not the controller cache.** (The README has since been reworded.) It affects only the disturbance analysis in Figure 4E–G, which uses 13 of the 15 sessions:
  - m1: the widefield video was never decomposed into an SVD, so there is nothing to fit the predictor on.
  - m13: the online ΔF/F trace does not line up frame by frame with its widefield SVD (scattered frame loss, 75 frames short).
  - Neither affects the controller trace that Figure 3 uses.
- **Not re-run:** this answer was traced in the code and the draft; the panels were not re-run for it.

## How the export was made

- `data` was loaded on its own with `load(cache, 'data')` and saved with `save(out, 'data', 'd', '-v7.3')`.
- Before `d.ref` and `d.provenance` were read, a check confirmed that no cache holds a `d.svd`; none does.
- They were then read with `matfile`. MatFile objects only support `()` indexing, so `m.d.provenance` is an error; the script read `m.d` whole and took the two fields from it.
- The source caches were read only and not modified.
