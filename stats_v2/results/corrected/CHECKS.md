# stats_v2 CHECKS

Generated 2026-10-28T03:56:53+00:00 by `stats_v2/run_all.py`.

## 1. Per-session counts, channel, motion

| id | cache meta (mn td en) | meta ok | trials in input_params | stimStarts | validation N | OL | CL | condition codes | active channel | 99.9th pct per channel (V) | has_motion | dur | ref |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| m1 | AL_0033 2025-01-20 3 | True | 122 | 122 | 120 | 56 | 64 | [0.0, 1.0] | inpVals | inpVals=4.409 | False | 3 | -5 |
| m2 | AL_0033 2025-02-12 2 | True | 220 | 220 | 200 | 97 | 103 | [0.0, 1.0] | inpVals | inpVals=4.619 | True | 3 | -5 |
| m3 | AL_0033 2025-02-24 2 | True | 225 | 225 | 200 | 101 | 99 | [0.0, 1.0] | inpVals | inpVals=2.674 | False | 3 | -5 |
| m4 | AL_0033 2025-02-26 2 | True | 213 | 213 | 200 | 92 | 108 | [0.0, 1.0] | inpVals | inpVals=2.667 | True | 3 | -5 |
| m5 | AL_0033 2025-03-04 1 | True | 111 | 111 | 60 | 36 | 24 | [0.0, 1.0] | inpVals | inpVals=1.939 | True | 3 | -5 |
| m6 | AL_0033 2025-03-05 2 | True | 32 | 32 | 30 | 14 | 16 | [0.0, 1.0] | inpVals | inpVals=2.068 | True | 3 | -5 |
| m7 | AL_0033 2025-03-20 4 | True | 104 | 104 | 100 | 46 | 54 | [0.0, 1.0] | inpVals | inpVals=1.701 | False | 3 | -5 |
| m8 | AL_0033 2025-04-15 2 | True | 62 | 62 | 60 | 38 | 22 | [0.0, 1.0] | inpVals | inpVals=2.613 | False | 3 | -5 |
| m9 | AL_0039 2025-04-20 1 | True | 103 | 103 | 100 | 50 | 50 | [0.0, 1.0] | inpVals | inpVals=1.126 | True | 3 | -5 |
| m10 | AL_0039 2025-04-19 1 | True | 105 | 105 | 100 | 48 | 52 | [0.0, 1.0] | inpVals | inpVals=1.264 | True | 3 | -5 |
| m11 | AL_0039 2025-04-30 3 | True | 101 | 101 | 100 | 50 | 50 | [0.0, 1.0] | inpVals | inpVals=1.005 | True | 3 | -5 |
| m12 | AL_0033 2025-04-19 1 | True | 110 | 110 | 100 | 35 | 65 | [0.0, 1.0] | inpVals | inpVals=1.136 | True | 3 | -5 |
| m13 | AL_0039 2025-04-20 2 | True | 111 | 111 | 100 | 55 | 45 | [0.0, 1.0] | inpVals | inpVals=1.246 | True | 3 | -5 |
| m14 | AL_0048 2026-07-29 2 | True | 106 | 106 | 100 | 45 | 55 | [0.0, 1.0] | inpVals638 | inpVals=-0.001, inpVals594=-0.001, inpVals638=2.963 | True | 3 | -5 |
| m15 | AL_0051 2026-07-29 2 | True | 108 | 108 | 100 | 55 | 45 | [0.0, 1.0] | inpVals | inpVals=4.506, inpVals594=4.506, inpVals638=-0.006 | True | 3 | -5 |

Sessions with motion: 11 of 15 (m2, m4, m5, m6, m9, m10, m11, m12, m13, m14, m15). Without: m1, m3, m7, m8.

- **m15: channel tie** on the 99.9th percentile between ['inpVals', 'inpVals594'] (arrays identical: True); chose `inpVals` (see CHOICES).
- m14: per-channel time vectors equal to d.inpTime: {'inpTime594': True, 'inpTime638': True}.
- m15: per-channel time vectors equal to d.inpTime: {'inpTime594': True, 'inpTime638': True}.

## 2. Array lengths and alignment

Spec says `data.dFk` has the same length as `timeBlue`. Where it does not, the primary analysis maps dFk[i] to timeBlue[i] (start-aligned; see CHOICES).
The `response lag` column is an alignment check: the lag (frames) at which frame-to-frame dFk changes are most negatively correlated with frame-to-frame changes of the frame-binned laser command (positive = dFk responds after the command). It uses the primary start-aligned mapping.

| id | len timeBlue | len dFk | len motion | measured frame rate (Hz) | response lag (frames) | r at lag | frames with abs(dFk) > 50 % | of which at frame >= 2000 | max abs(dFk) |
|---|---|---|---|---|---|---|---|---|---|
| m1 | 80858 | 80858 | 80858 | 35.088 | 2 | -0.062 | 958 | 0 | 65441.2 |
| m2 | 149458 | 149458 | 149458 | 35.088 | 3 | -0.053 | 0 | 0 | 17.1 |
| m3 | 150119 | 150119 | 150119 | 35.088 | 3 | -0.037 | 916 | 0 | 46021.9 |
| m4 | 138286 | 138286 | 138286 | 35.088 | 3 | -0.061 | 922 | 0 | 58017.3 |
| m5 | 80124 | 80124 | 80124 | 35.088 | 3 | -0.079 | 947 | 0 | 67600.9 |
| m6 | 21629 | 21629 | 21629 | 35.088 | 2 | -0.083 | 922 | 0 | 74303.3 |
| m7 | 68368 | 68368 | 68368 | 35.088 | 2 | -0.053 | 934 | 0 | 62097.3 |
| m8 | 42615 | 42614 **(mismatch)** | 42615 | 35.088 | 1 | -0.039 | 963 | 0 | 67863.6 |
| m9 | 67864 | 67864 | 67864 | 35.088 | 2 | -0.107 | 942 | 0 | 43798.2 |
| m10 | 80458 | 80458 | 80457 **(mismatch)** | 35.088 | 3 | -0.117 | 934 | 0 | 44695.9 |
| m11 | 66200 | 66200 | 66199 **(mismatch)** | 35.088 | 3 | -0.137 | 935 | 0 | 52987.3 |
| m12 | 74397 | 74397 | 74397 | 35.088 | 2 | -0.172 | 910 | 0 | 66662.4 |
| m13 | 91875 | 91800 **(mismatch)** | 91875 | 35.088 | 3 | -0.138 | 983 | 10 | 47638.7 |
| m14 | 54839 | 54828 **(mismatch)** | 54839 | 35.088 | 3 | -0.086 | 0 | 0 | 18.0 |
| m15 | 55307 | 55307 | 55307 | 35.088 | 3 | -0.139 | 0 | 0 | 32.2 |

- Response lag across sessions: m1 +2, m2 +3, m3 +3, m4 +3, m5 +3, m6 +2, m7 +2, m8 +1, m9 +2, m10 +3, m11 +3, m12 +2, m13 +3, m14 +3, m15 +3. Sessions with the response 1–3 frames after the command: m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15; outside that range: none.
- **m14 contradicts the start-aligned mapping**: its dFk is 11 frames shorter than timeBlue and, start-aligned, its dFk 'responds' -3 frames *before* the laser command changes (physically impossible). Re-mapping dFk[i] to timeBlue[i+11] (end-aligned) gives a lag of -8 frames (r = -0.086), in line with the other sessions. The primary outputs keep the spec's literal mapping; a sensitivity re-run with the shifted m14 is in section 8 and `sensitivity_m14_align.csv`.
- m8 (dFk 1 frame short) shows lag 1 vs 2–3 in the other old builds; with a 1-frame length difference the evidence for an end-alignment there is weak (correlations are small). Not changed.
- m13 (dFk 75 frames short) shows lag 3, consistent with start alignment (missing frames at the end). No validation window reaches beyond the end of dFk.
- m10, m11: `d.motion` is 1 frame shorter than timeBlue; start-aligned; no state window reaches the missing frame.
- Sessions with frames where abs(dFk) > 50 %: m1, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13. These sit mostly at the very start of the session (start-up transient of the online ΔF/F baseline); sessions with such frames at frame >= 2000: m13 (10 frames). Frames with abs(dFk) > 50 % between the first validation pre window and the last post_var window: 0 in total; none of them falls inside an analysis window (section 5).

## 3. Onset sanity: laser command rise vs onset frame

Rise = first active-channel sample in [t0−0.5, t0+1.0) s above (median over [t0−1.5, t0−0.5) s) + 0.05 V, with t0 = timeBlue[onset frame]. Offset in frames = (t_rise − t0) / median frame interval. Spec expectation: within ±2 frames. In CL trials a late rise can be the controller output sitting at zero, so OL trials are the cleaner test.

| id | OL median | OL min | OL max | CL median | CL min | CL max | trials outside ±2 (OL / CL / total) | no rise found |
|---|---|---|---|---|---|---|---|---|
| m1 | 1.86 | 1.39 | 2.37 | 1.91 | 0.98 | 3.67 | 19 / 28 / 47 of 120 | 0 |
| m2 | 1.91 | 1.39 | 2.37 | 1.93 | 0.56 | 2.86 | 40 / 45 / 85 of 200 | 0 |
| m3 | 2.00 | 1.39 | 2.39 | 2.18 | 0.91 | 3.53 | 50 / 60 / 110 of 200 | 0 |
| m4 | 2.04 | 1.39 | 2.37 | 1.97 | 0.95 | 3.04 | 51 / 48 / 99 of 200 | 0 |
| m5 | 2.01 | 1.39 | 2.39 | 2.04 | 1.02 | 2.58 | 18 / 12 / 30 of 60 | 0 |
| m6 | 2.06 | 1.42 | 2.26 | 1.62 | 1.07 | 2.61 | 9 / 7 / 16 of 30 | 0 |
| m7 | 2.09 | 1.40 | 2.37 | 2.29 | 0.98 | 3.58 | 28 / 39 / 67 of 100 | 0 |
| m8 | 2.04 | 1.39 | 2.37 | 2.23 | 1.05 | 2.72 | 22 / 16 / 38 of 60 | 0 |
| m9 | 1.89 | 1.86 | 2.89 | 1.89 | 1.86 | 2.91 | 3 / 4 / 7 of 100 | 0 |
| m10 | 1.89 | 1.84 | 2.89 | 1.89 | 1.86 | 2.89 | 4 / 4 / 8 of 100 | 0 |
| m11 | 1.86 | 1.86 | 2.88 | 1.86 | 1.84 | 2.88 | 4 / 1 / 5 of 100 | 0 |
| m12 | 1.89 | 1.86 | 2.02 | 1.89 | 1.86 | 2.88 | 2 / 2 / 4 of 100 | 0 |
| m13 | 1.89 | 1.86 | 2.96 | 1.88 | 1.86 | 2.95 | 7 / 4 / 11 of 100 | 0 |
| m14 | 2.86 | 1.86 | 4.23 | 2.86 | 1.88 | 17.91 | 44 / 54 / 98 of 100 | 0 |
| m15 | 2.86 | 2.26 | 3.88 | 2.86 | 1.86 | 3.88 | 55 / 44 / 99 of 100 | 0 |

**724 of 1670 validation trials have the command rise outside ±2 frames of the onset frame.** The onsets were NOT changed (spec rule). Notable patterns:
- m1, m2: the command rises 0.98–3.67 (m1) and 0.56–2.86 (m2) frames after the onset frame, in every trial (OL and CL). The onset defined from stimStarts precedes the laser by ~0.16–0.18 s (median) in these two sessions, versus ~0.04–0.08 s in the others.
- m3–m8: the offset jitters trial to trial over roughly −5 … +4 frames.
- m9–m13: offsets cluster at ~1.9 frames with a minority at ~2.9 frames (outside ±2) and a few at 2.0–2.2.
- m3–m8 offsets drift gradually from trial to trial and then wrap (saw-tooth pattern in trial order), e.g. m4 trials 115–132 run from −2.5 to −4.9 frames.
- m14, m15: the rise is at ~2.9 frames in nearly all trials (just outside ±2), OL max 4.2 frames. The longest delays (m14 CL trials, up to 17.9 frames) occur only in CL trials and are compatible with the controller output staying at zero while dFk is below the reference (e.g. m14 trials 71 and 89 start below −5 %); not investigated further.
- Old-build commands (m1–m13) are a 35 Hz pulsed waveform (frame-locked half-sine pulses whose amplitude carries the control); new builds are a per-frame staircase.

Every trial outside ±2 frames (trial_index = 1-based input_params column, condition, offset in frames):

- **m1** (47): 7CL(+3.7), 13CL(+2.4), 17OL(+2.3), 18CL(+2.3), 19OL(+2.3), 20OL(+2.2), 21CL(+2.2), 22OL(+2.2), 23CL(+2.1), 24OL(+2.1), 25CL(+2.0), 29CL(+2.9), 30CL(+2.9), 31CL(+2.8), 43CL(+2.4), 46OL(+2.4), 47CL(+2.3), 48CL(+3.3), 49CL(+3.2), 50OL(+2.2), 51OL(+2.2), 52OL(+2.1), 53CL(+3.1), 54CL(+2.1), 55CL(+2.0), 73CL(+2.4), 75OL(+2.4), 76CL(+2.3), 77CL(+2.3), 78CL(+3.2), 79CL(+3.2), 80CL(+2.2), 81CL(+2.1), 82OL(+2.1), 83CL(+2.1), 84OL(+2.1), 85CL(+2.0), 97CL(+2.6), 102CL(+2.4), 107OL(+2.3), 108OL(+2.2), 109OL(+2.2), 110CL(+2.2), 111OL(+2.1), 112OL(+2.1), 113OL(+2.1), 114OL(+2.0)
- **m2** (85): 34OL(+2.4), 35CL(+2.3), 36OL(+2.3), 37OL(+2.3), 38CL(+2.2), 39CL(+2.2), 40OL(+2.2), 41CL(+2.1), 42OL(+2.1), 43CL(+2.1), 44OL(+2.0), 64CL(+2.3), 65CL(+2.3), 66CL(+2.3), 67OL(+2.2), 68CL(+2.2), 69CL(+2.2), 70CL(+2.1), 71OL(+2.1), 72CL(+2.1), 73OL(+2.1), 84CL(+2.7), 93OL(+2.4), 94OL(+2.3), 95CL(+2.3), 96OL(+2.3), 97CL(+2.2), 98OL(+2.2), 99CL(+2.2), 100CL(+2.1), 101OL(+2.1), 102CL(+2.1), 103OL(+2.0), 104OL(+2.0), 112CL(+2.7), 113CL(+2.7), 119CL(+2.5), 123CL(+2.3), 124OL(+2.3), 125CL(+2.3), 126OL(+2.2), 127OL(+2.2), 128CL(+2.2), 129CL(+2.1), 130OL(+2.1), 131CL(+2.1), 132OL(+2.0), 138CL(+2.9), 152OL(+2.4), 153OL(+2.3), 154OL(+2.3), 155CL(+2.2), 156OL(+2.2), 157CL(+2.2), 158OL(+2.2), 159CL(+2.2), 160OL(+2.1), 161CL(+2.1), 162OL(+2.0), 172CL(+2.7), 173CL(+2.6), 174CL(+2.6), 175CL(+2.6), 177CL(+2.5), 182OL(+2.4), 183CL(+2.3), 184CL(+2.3), 185OL(+2.2), 186CL(+2.2), 187OL(+2.2), 188OL(+2.1), 189CL(+2.1), 190CL(+2.1), 191CL(+2.1), 192CL(+2.0), 211CL(+2.4), 212OL(+2.3), 213OL(+2.3), 214OL(+2.3), 215OL(+2.2), 216CL(+2.2), 217OL(+2.2), 218OL(+2.1), 219OL(+2.1), 220OL(+2.1)
- **m3** (110): 27OL(+2.0), 28CL(+2.2), 31OL(+2.1), 33OL(+2.1), 34OL(+2.3), 35CL(+2.5), 37CL(+2.1), 42OL(+2.3), 43CL(+2.5), 45OL(+2.2), 46OL(+2.4), 47CL(+2.5), 48CL(+2.0), 50OL(+2.4), 56OL(+2.1), 57CL(+2.2), 60OL(+2.1), 61CL(+2.2), 67CL(+2.6), 68OL(+2.1), 73CL(+2.6), 74CL(+2.1), 75OL(+2.3), 78OL(+2.1), 79CL(+2.3), 83CL(+2.3), 84CL(+2.5), 85CL(+2.6), 86OL(+2.1), 87CL(+2.3), 88CL(+2.5), 91OL(+2.1), 97OL(+2.2), 100CL(+2.5), 106CL(+3.5), 108CL(+2.2), 109OL(+2.4), 110CL(+2.5), 111OL(+2.0), 112CL(+2.2), 113OL(+2.4), 114CL(+2.6), 115OL(+2.0), 116OL(+2.2), 119OL(+2.1), 120CL(+2.3), 123OL(+2.2), 126OL(+2.0), 127OL(+2.2), 128CL(+2.4), 130CL(+2.0), 131OL(+2.2), 132CL(+2.4), 133CL(+2.6), 134OL(+2.0), 135OL(+2.2), 136CL(+2.4), 137CL(+2.4), 138CL(+2.6), 139OL(+2.0), 140CL(+2.2), 143OL(+2.1), 144CL(+2.2), 145CL(+2.4), 146CL(+2.6), 147OL(+2.1), 148CL(+3.4), 149CL(+2.5), 150CL(+2.0), 151OL(+2.2), 152CL(+2.4), 153CL(+3.3), 156CL(+2.1), 157OL(+2.3), 159CL(+3.3), 160CL(+2.5), 162OL(+2.2), 163OL(+2.4), 165CL(+2.4), 167OL(+2.1), 168CL(+2.3), 171OL(+2.1), 174CL(+2.6), 175OL(+2.1), 176OL(+2.3), 177CL(+2.5), 179CL(+2.1), 180CL(+2.3), 181CL(+2.5), 184OL(+2.3), 187CL(+2.2), 188CL(+2.3), 194CL(+2.0), 195OL(+2.2), 196CL(+2.4), 202OL(+2.4), 203CL(+2.5), 205OL(+2.2), 206OL(+2.4), 211CL(+2.6), 212OL(+2.0), 215CL(+2.6), 216OL(+2.1), 217OL(+2.2), 220OL(+2.1), 221OL(+2.2), 222CL(+2.4), 223CL(+2.6), 224CL(+2.1), 225OL(+2.3)
- **m4** (99): 14OL(+2.3), 18OL(+2.0), 19CL(+2.2), 20CL(+2.4), 21CL(+2.6), 23OL(+2.2), 25CL(+2.6), 26OL(+2.1), 27OL(+2.2), 30CL(+2.2), 31CL(+2.4), 32CL(+2.5), 33CL(+2.0), 34OL(+2.2), 35OL(+2.4), 36CL(+2.5), 37OL(+2.0), 38CL(+2.2), 41OL(+2.1), 42CL(+2.2), 43CL(+2.4), 44CL(+2.6), 45CL(+2.1), 49OL(+2.1), 50CL(+2.3), 51CL(+2.5), 52CL(+2.6), 61OL(+2.1), 62CL(+2.2), 65OL(+2.1), 66CL(+2.2), 70OL(+2.3), 73CL(+2.1), 74OL(+2.3), 75CL(+2.5), 77OL(+2.1), 78OL(+2.3), 82OL(+2.3), 83CL(+2.5), 89OL(+2.1), 90OL(+2.3), 92CL(+2.6), 93OL(+2.1), 94OL(+2.3), 101CL(+2.1), 102OL(+2.3), 105CL(+2.2), 106CL(+2.3), 107CL(+2.5), 113OL(+2.2), 114OL(+2.4), 117OL(+2.2), 119CL(+2.6), 120OL(+2.0), 121OL(+2.2), 124OL(+2.1), 125OL(+2.2), 126CL(+2.4), 128OL(+2.1), 129CL(+2.3), 132OL(+2.1), 134CL(+2.2), 135OL(+2.3), 136CL(+2.5), 138CL(+2.2), 139OL(+2.4), 140CL(+2.5), 141CL(+2.7), 142CL(+2.2), 143OL(+2.4), 145OL(+2.1), 146CL(+2.3), 147CL(+2.5), 149CL(+2.2), 154OL(+2.4), 155CL(+2.5), 157OL(+2.2), 158OL(+2.4), 160CL(+2.0), 161OL(+2.2), 162CL(+2.4), 165OL(+2.0), 166OL(+2.2), 167CL(+2.4), 168CL(+2.6), 170OL(+2.2), 175CL(+2.5), 177CL(+2.2), 179OL(+2.2), 183OL(+2.2), 184OL(+2.1), 185OL(+2.3), 188OL(+2.2), 189CL(+3.0), 190CL(+2.2), 195OL(+2.1), 201OL(+2.2), 208OL(+2.0), 209OL(+2.2)
- **m5** (30): 52OL(+2.4), 56CL(+2.5), 58OL(+2.2), 59CL(+2.3), 60CL(+2.5), 63CL(+2.4), 64CL(+2.5), 66CL(+2.2), 67OL(+2.4), 69OL(+2.0), 70CL(+2.2), 73OL(+2.1), 74OL(+2.2), 77OL(+2.1), 78CL(+2.2), 80CL(+2.1), 81OL(+2.3), 85OL(+2.3), 86OL(+2.2), 87OL(+2.4), 88CL(+2.5), 89OL(+2.0), 90OL(+2.2), 93OL(+2.0), 94CL(+2.2), 96CL(+2.6), 97OL(+2.1), 98OL(+2.2), 101OL(+2.2), 107OL(+2.3)
- **m6** (16): 3OL(+2.0), 4CL(+2.2), 5CL(+2.4), 6CL(+2.6), 7OL(+2.1), 8OL(+2.2), 9CL(+2.4), 10CL(+2.6), 14CL(+2.6), 15CL(+2.1), 16OL(+2.3), 21OL(+2.2), 25OL(+2.3), 28OL(+2.2), 31OL(+2.1), 32OL(+2.2)
- **m7** (67): 6CL(+2.1), 7OL(+2.4), 9CL(+3.4), 10CL(+2.6), 11OL(+2.1), 12CL(+2.2), 13CL(+2.4), 14CL(+3.3), 15CL(+2.5), 16CL(+2.6), 17CL(+2.1), 18OL(+2.3), 19CL(+2.5), 20CL(+2.7), 21OL(+2.1), 22OL(+2.3), 25OL(+2.2), 28OL(+2.1), 29OL(+2.3), 34OL(+2.2), 35OL(+2.4), 36CL(+2.5), 37OL(+2.0), 38CL(+3.6), 39OL(+2.1), 40CL(+2.2), 43CL(+2.5), 46OL(+2.4), 49OL(+2.2), 50OL(+2.4), 56CL(+2.1), 57OL(+2.3), 58CL(+2.5), 60OL(+2.2), 61CL(+2.3), 62CL(+2.5), 64CL(+2.2), 65OL(+2.3), 67CL(+2.0), 69OL(+2.4), 70CL(+2.5), 72CL(+2.2), 74CL(+2.5), 75OL(+2.0), 76OL(+2.2), 77CL(+2.4), 78CL(+2.6), 81CL(+2.6), 82OL(+2.1), 83OL(+2.3), 86OL(+2.1), 87CL(+2.3), 88CL(+2.5), 89CL(+2.6), 90OL(+2.1), 92CL(+2.6), 93OL(+2.1), 94CL(+2.2), 95CL(+3.1), 96CL(+2.3), 97CL(+2.5), 98CL(+2.7), 99CL(+2.1), 100OL(+2.3), 101CL(+2.5), 103CL(+2.2), 104OL(+2.3)
- **m8** (38): 3CL(+2.2), 4OL(+2.3), 5CL(+2.5), 7OL(+2.2), 8OL(+2.4), 10OL(+2.0), 11OL(+2.2), 12CL(+2.4), 14OL(+2.0), 15CL(+2.0), 16OL(+2.2), 17CL(+2.4), 19OL(+2.0), 20OL(+2.2), 22CL(+2.6), 23CL(+2.1), 24OL(+2.2), 26CL(+2.6), 27OL(+2.1), 28OL(+2.2), 31OL(+2.1), 32CL(+2.3), 38OL(+2.1), 41CL(+2.7), 42OL(+2.2), 43OL(+2.4), 46OL(+2.2), 47OL(+2.4), 48CL(+2.5), 49CL(+2.7), 50CL(+2.2), 52CL(+2.6), 53OL(+2.0), 54OL(+2.2), 55CL(+2.4), 58OL(+2.2), 61CL(+2.1), 62OL(+2.2)
- **m9** (7): 5OL(+2.9), 14CL(+2.9), 17OL(+2.9), 23CL(+2.9), 63OL(+2.9), 87CL(+2.9), 90CL(+2.9)
- **m10** (8): 8CL(+2.2), 28OL(+2.9), 55CL(+2.9), 58OL(+2.9), 61OL(+2.9), 67CL(+2.9), 83CL(+2.1), 87OL(+2.9)
- **m11** (5): 15OL(+2.9), 34OL(+2.9), 70CL(+2.9), 73OL(+2.9), 85OL(+2.9)
- **m12** (4): 41OL(+2.0), 42CL(+2.9), 45CL(+2.9), 59OL(+2.0)
- **m13** (11): 14OL(+2.9), 23OL(+2.9), 39OL(+2.9), 42OL(+2.9), 45OL(+3.0), 83CL(+2.9), 89CL(+2.9), 92OL(+2.9), 95OL(+2.9), 107CL(+2.9), 110CL(+2.9)
- **m14** (98): 7CL(+2.9), 8OL(+2.9), 9CL(+2.9), 10CL(+2.8), 11CL(+2.9), 12OL(+2.9), 13OL(+2.2), 14CL(+2.9), 15OL(+2.8), 16CL(+2.0), 17CL(+2.9), 18CL(+3.3), 19CL(+3.5), 20OL(+3.9), 21CL(+2.9), 22OL(+3.9), 23OL(+2.9), 24CL(+2.9), 25CL(+2.9), 26CL(+2.9), 27OL(+2.9), 28OL(+2.9), 29CL(+3.2), 30OL(+2.9), 31OL(+3.9), 32OL(+2.9), 33OL(+2.9), 34CL(+3.9), 35CL(+3.0), 36OL(+2.9), 38CL(+2.9), 39OL(+2.9), 40CL(+3.2), 41CL(+5.9), 43CL(+3.1), 44CL(+2.9), 45OL(+3.1), 46CL(+2.9), 47CL(+2.9), 48OL(+4.2), 49OL(+3.4), 50OL(+2.9), 51OL(+2.9), 52OL(+2.9), 53CL(+2.9), 54CL(+2.9), 55CL(+2.9), 56CL(+3.9), 57CL(+3.9), 58OL(+2.9), 59CL(+2.9), 60OL(+3.6), 61CL(+2.9), 62CL(+2.9), 63OL(+2.9), 64CL(+2.9), 65CL(+2.9), 66CL(+2.9), 67CL(+2.9), 68OL(+2.9), 69OL(+2.9), 70OL(+3.2), 71CL(+4.9), 72CL(+2.9), 73OL(+2.9), 74CL(+2.9), 75CL(+2.9), 76CL(+2.9), 77OL(+3.1), 78CL(+2.9), 79CL(+2.9), 80OL(+2.9), 81CL(+2.9), 82OL(+2.9), 83CL(+2.9), 84CL(+4.9), 85OL(+2.4), 86CL(+2.9), 87OL(+2.9), 88CL(+2.9), 89CL(+17.9), 90OL(+2.9), 91CL(+2.9), 92OL(+2.9), 93OL(+2.9), 94OL(+2.9), 95CL(+2.9), 96OL(+2.9), 97OL(+2.9), 98CL(+2.9), 99OL(+2.9), 100CL(+6.9), 101OL(+2.9), 102OL(+2.4), 103CL(+2.9), 104CL(+3.5), 105OL(+2.8), 106OL(+2.9)
- **m15** (99): 9CL(+2.9), 10OL(+2.8), 11OL(+2.9), 12CL(+2.9), 13OL(+3.2), 14CL(+3.3), 15OL(+3.9), 16OL(+2.9), 17CL(+2.9), 18OL(+2.9), 19CL(+2.4), 20CL(+2.9), 21OL(+2.9), 22OL(+2.9), 23OL(+2.9), 24OL(+2.9), 25OL(+2.9), 26CL(+2.9), 27OL(+3.4), 28OL(+2.9), 29OL(+2.9), 30CL(+2.9), 31OL(+2.9), 32OL(+2.9), 33CL(+2.9), 34CL(+2.9), 35OL(+2.9), 37OL(+2.9), 38OL(+2.9), 39OL(+3.4), 40OL(+3.4), 41CL(+2.9), 42OL(+2.9), 43OL(+3.8), 44OL(+2.9), 45CL(+2.2), 46OL(+2.9), 47CL(+2.9), 48OL(+2.9), 49CL(+3.2), 50CL(+2.9), 51OL(+3.9), 52OL(+2.9), 53CL(+2.9), 54OL(+3.0), 55OL(+2.9), 56OL(+2.9), 57CL(+2.9), 58CL(+2.8), 59OL(+2.3), 60CL(+2.9), 61CL(+2.9), 62CL(+2.9), 63CL(+2.9), 64OL(+2.9), 65CL(+2.9), 66OL(+3.9), 67CL(+2.9), 68CL(+2.8), 69OL(+2.9), 70OL(+2.9), 71OL(+2.9), 72CL(+2.9), 73OL(+2.9), 74OL(+2.9), 75OL(+2.9), 76OL(+2.9), 77CL(+2.9), 78CL(+2.9), 79CL(+3.9), 80OL(+2.9), 81CL(+2.9), 82CL(+2.8), 83OL(+3.5), 84OL(+2.9), 85OL(+2.9), 86CL(+2.9), 87CL(+2.9), 88CL(+3.4), 89CL(+2.9), 90CL(+2.9), 91OL(+2.9), 92CL(+3.4), 93OL(+3.4), 94CL(+2.9), 95OL(+2.9), 96CL(+2.9), 97OL(+2.9), 98CL(+2.8), 99CL(+2.9), 100CL(+2.9), 101CL(+2.9), 102OL(+2.9), 103OL(+2.9), 104OL(+2.9), 105OL(+2.3), 106CL(+2.9), 107OL(+3.0), 108OL(+2.9)

## 4. New builds: stimStarts vs timeBlue[kk] − dur

- m14: max |stimStarts − (timeBlue[kk−1] − dur)| = 0 s (median 0 s), kk read 1-based from input_params row 2 over the validation block.
- m15: max |stimStarts − (timeBlue[kk−1] − dur)| = 0 s (median 0 s), kk read 1-based from input_params row 2 over the validation block.

Onset frame vs stimStarts (all sessions): max |timeBlue[onset] − stimStarts| = m1 0.1430 s, m2 0.1430 s, m3 0.1430 s, m4 0.2000 s, m5 0.0860 s, m6 0.0575 s, m7 0.0855 s, m8 0.0860 s, m9 0.0000 s, m10 0.0000 s, m11 0.0000 s, m12 0.0000 s, m13 0.0000 s, m14 0.0005 s, m15 0.0000 s

## 5. NaN / out-of-range windows

- m1: NaN states {'motion': 120} (no motion: expected)
- m3: NaN states {'motion': 200} (no motion: expected)
- m7: NaN states {'motion': 100} (no motion: expected)
- m8: NaN states {'motion': 60} (no motion: expected)
- No analysis window (pre, early, late, full, post_rmse, post_var, peri) runs outside the dFk array or contains NaN, and no window sample has |dFk| > 50 %. Nothing was dropped or imputed.
- Motion state is NaN for the 4 sessions without motion (m1, m3, m7, m8), as specified; those sessions are excluded from the motion analyses only.

## 6. Trial-order randomness (runs test, validation block)

| id | n OL | n CL | runs | expected | z | p (two-sided, normal approx.) |
|---|---|---|---|---|---|---|
| m1 | 56 | 64 | 55 | 60.7 | -1.06 | 0.291 |
| m2 | 97 | 103 | 105 | 100.9 | 0.58 | 0.562 |
| m3 | 101 | 99 | 111 | 101.0 | 1.42 | 0.156 |
| m4 | 92 | 108 | 98 | 100.4 | -0.34 | 0.736 |
| m5 | 36 | 24 | 31 | 29.8 | 0.33 | 0.745 |
| m6 | 14 | 16 | 17 | 15.9 | 0.40 | 0.690 |
| m7 | 46 | 54 | 53 | 50.7 | 0.47 | 0.639 |
| m8 | 38 | 22 | 34 | 28.9 | 1.44 | 0.150 |
| m9 | 50 | 50 | 50 | 51.0 | -0.20 | 0.841 |
| m10 | 48 | 52 | 47 | 50.9 | -0.79 | 0.430 |
| m11 | 50 | 50 | 56 | 51.0 | 1.01 | 0.315 |
| m12 | 35 | 65 | 38 | 46.5 | -1.88 | 0.060 |
| m13 | 55 | 45 | 48 | 50.5 | -0.51 | 0.612 |
| m14 | 45 | 55 | 54 | 50.5 | 0.71 | 0.477 |
| m15 | 55 | 45 | 54 | 50.5 | 0.71 | 0.477 |

## 7. Other observations (not fixed)

- **m4: input_params rows vary within the validation block** (rows 0-based: values) {3: [0.16, 0.17], 4: [0.1, 0.15, 0.2], 5: [0.002, 0.005]}. All validation trials were used as specified.
- m5: the 51 trials before the validation block include 18 OL and 33 CL trials (excluded by the last-N rule).
- m6: the 2 trials before the validation block include 1 OL and 1 CL trials (excluded by the last-N rule).
- Inter-onset intervals (validation block): m1 min 18.0 s / median 18.0 s, m2 min 18.0 s / median 18.0 s, m3 min 18.0 s / median 18.0 s, m4 min 18.0 s / median 18.0 s, m5 min 18.0 s / median 18.0 s, m6 min 18.0 s / median 18.0 s, m7 min 18.0 s / median 18.0 s, m8 min 18.0 s / median 18.0 s, m9 min 18.1 s / median 18.1 s, m10 min 18.1 s / median 18.1 s, m11 min 18.1 s / median 18.1 s, m12 min 18.1 s / median 18.1 s, m13 min 18.1 s / median 18.1 s, m14 min 11.1 s / median 12.9 s, m15 min 9.1 s / median 11.4 s.
- Intervals < 9 s (a trial's post_var 3–6 s window overlaps the next trial's pre window): none; < 6 s (next pre window overlaps this trial's stimulus): none.
- Prep covariate validity: the lower-bound test |u| < 0.01 V is applied to the raw command, whose resting (laser-off) level is offset from 0 V. Per session, resting level = median command over [t0−1.5, t0−0.5) s; and the fraction of those laser-off samples that pass |u| < 0.01 V:
  m1 -0.0148 V / 0.00; m2 -0.0128 V / 0.01; m3 -0.0059 V / 0.97; m4 -0.0072 V / 0.90; m5 -0.0105 V / 0.36; m6 -0.0105 V / 0.40; m7 -0.0128 V / 0.15; m8 -0.0125 V / 0.14; m9 -0.0102 V / 0.46; m10 -0.0102 V / 0.44; m11 -0.0076 V / 0.85; m12 -0.0105 V / 0.36; m13 -0.0102 V / 0.45; m14 +0.0082 V / 0.69; m15 +0.0148 V / 0.08.
  For the old builds the CL command is also a 35 Hz pulse train, so samples at |u| < 0.01 V inside 0–3 s include pulse troughs, not only frames where the controller output is at zero. Reported as computed (pre-specified); interpret with care.

## 8. Sensitivity: m14 with dFk end-aligned (dFk[i] → timeBlue[i+11])

Session values for m14:

| quantity | m14_start_aligned | m14_shift11 |
|---|---|---|
| rmse_ratio_full | 0.8739 | 0.8822 |
| var_ratio_full | 0.6389 | 0.6194 |

Main tests, primary vs m14-shifted (other 14 sessions unchanged):

| figure | quantity | window_or_state | role | effect | p | wilcoxon_p | k | k_n | holm_p | effect_m14shift | p_m14shift | wilcoxon_p_m14shift | k_m14shift | k_n_m14shift | holm_p_m14shift |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fig3 | rmse_ratio | full | main | 0.7679 | 5.814e-08 | 6.104e-05 | 15.0000 | 15.0000 | NaN | 0.7684 | 6.724e-08 | 6.104e-05 | 15.0000 | 15.0000 | NaN |
| fig3 | var_ratio | full | main | 0.5848 | 6.34e-06 | 0.0001221 | 14.0000 | 15.0000 | NaN | 0.5836 | 5.952e-06 | 0.0001221 | 14.0000 | 15.0000 | NaN |
| fig4d | P | init_dev | main | 0.1783 | 0.0560 | 0.0833 | 10.0000 | 15.0000 | 0.1681 | 0.1872 | 0.0435 | 0.0730 | 11.0000 | 15.0000 | 0.1732 |
| fig4d | R | init_dev | main | 0.1368 | 0.0142 | 0.0034 | 13.0000 | 15.0000 | 0.0709 | 0.1453 | 0.0102 | 0.0034 | 13.0000 | 15.0000 | 0.0714 |
| fig4d | A | init_dev | main | -0.0036 | 0.9104 | 0.9341 | 7.0000 | 15.0000 | 0.9104 | -0.00093 | 0.9772 | 0.9780 | 7.0000 | 15.0000 | 0.9772 |
| fig4d | P | motion | main | 0.2370 | 0.0107 | 0.0029 | 10.0000 | 11.0000 | 0.0688 | 0.2358 | 0.0112 | 0.0029 | 10.0000 | 11.0000 | 0.0714 |
| fig4d | R | motion | main | -0.0577 | 0.1610 | 0.3203 | 6.0000 | 11.0000 | 0.3220 | -0.0724 | 0.1347 | 0.3203 | 6.0000 | 11.0000 | 0.2695 |
| fig4d | A | motion | main | -0.1382 | 0.0023 | 0.0009766 | 11.0000 | 11.0000 | 0.0092 | -0.1414 | 0.0019 | 0.0009766 | 11.0000 | 11.0000 | 0.0078 |
| fig4d | P | rel_delta | main | -0.0016 | 0.9762 | 0.5614 | 9.0000 | 15.0000 | 0.9762 | -0.0016 | 0.9752 | 0.5245 | 9.0000 | 15.0000 | 0.9752 |
| fig4d | R | rel_delta | main | 0.0989 | 0.0349 | 0.0302 | 10.0000 | 15.0000 | 0.1396 | 0.0927 | 0.0433 | 0.0302 | 10.0000 | 15.0000 | 0.1732 |
| fig4d | A | rel_delta | main | 0.0505 | 0.0291 | 0.0125 | 13.0000 | 15.0000 | 0.0874 | 0.0468 | 0.0428 | 0.0151 | 13.0000 | 15.0000 | 0.1284 |
| fig4d | P | abs_delta | main | 0.2790 | 0.0098 | 0.0084 | 13.0000 | 15.0000 | 0.0688 | 0.2699 | 0.0116 | 0.0103 | 13.0000 | 15.0000 | 0.0714 |
| fig4d | R | abs_delta | main | 0.3232 | 0.0007071 | 6.104e-05 | 15.0000 | 15.0000 | 0.0057 | 0.3227 | 0.0007068 | 6.104e-05 | 15.0000 | 15.0000 | 0.0057 |
| fig4d | A | abs_delta | main | 0.0653 | 0.0939 | 0.0353 | 12.0000 | 15.0000 | 0.1878 | 0.0662 | 0.0908 | 0.0353 | 12.0000 | 15.0000 | 0.1816 |
