# stats_v2 CHECKS

Generated 2026-10-28T03:56:40+00:00 by `stats_v2/run_all.py`.

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
| m14 | 54839 | 54828 **(mismatch)** | 54839 | 35.088 | -8 | -0.086 | 0 | 0 | 18.0 |
| m15 | 55307 | 55307 | 55307 | 35.088 | 3 | -0.139 | 0 | 0 | 32.2 |

- Response lag across sessions: m1 +2, m2 +3, m3 +3, m4 +3, m5 +3, m6 +2, m7 +2, m8 +1, m9 +2, m10 +3, m11 +3, m12 +2, m13 +3, m14 -8, m15 +3. Sessions with the response 1–3 frames after the command: m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m15; outside that range: m14.
- **m14 contradicts the start-aligned mapping**: its dFk is 11 frames shorter than timeBlue and, start-aligned, its dFk 'responds' 8 frames *before* the laser command changes (physically impossible). Re-mapping dFk[i] to timeBlue[i+11] (end-aligned) gives a lag of 3 frames (r = -0.086), in line with the other sessions. The primary outputs keep the spec's literal mapping; a sensitivity re-run with the shifted m14 is in section 8 and `sensitivity_m14_align.csv`.
- m8 (dFk 1 frame short) shows lag 1 vs 2–3 in the other old builds; with a 1-frame length difference the evidence for an end-alignment there is weak (correlations are small). Not changed.
- m13 (dFk 75 frames short) shows lag 3, consistent with start alignment (missing frames at the end). No validation window reaches beyond the end of dFk.
- m10, m11: `d.motion` is 1 frame shorter than timeBlue; start-aligned; no state window reaches the missing frame.
- Sessions with frames where abs(dFk) > 50 %: m1, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13. These sit mostly at the very start of the session (start-up transient of the online ΔF/F baseline); sessions with such frames at frame >= 2000: m13 (10 frames). Frames with abs(dFk) > 50 % between the first validation pre window and the last post_var window: 0 in total; none of them falls inside an analysis window (section 5).

## 3. Onset sanity: laser command rise vs onset frame

Rise = first active-channel sample in [t0−0.5, t0+1.0) s above (median over [t0−1.5, t0−0.5) s) + 0.05 V, with t0 = timeBlue[onset frame]. Offset in frames = (t_rise − t0) / median frame interval. Spec expectation: within ±2 frames. In CL trials a late rise can be the controller output sitting at zero, so OL trials are the cleaner test.

| id | OL median | OL min | OL max | CL median | CL min | CL max | trials outside ±2 (OL / CL / total) | no rise found |
|---|---|---|---|---|---|---|---|---|
| m1 | 5.65 | 4.65 | 6.67 | 5.78 | 4.98 | 6.67 | 56 / 64 / 120 of 120 | 0 |
| m2 | 6.28 | 5.53 | 6.82 | 6.23 | 5.54 | 6.86 | 97 / 103 / 200 of 200 | 0 |
| m3 | 1.44 | -2.91 | 3.58 | 1.35 | -2.98 | 3.53 | 47 / 43 / 90 of 200 | 0 |
| m4 | 1.36 | -4.95 | 3.39 | 1.53 | -4.75 | 3.04 | 46 / 53 / 99 of 200 | 0 |
| m5 | 1.98 | -0.96 | 3.49 | 2.03 | -0.77 | 2.60 | 17 / 12 / 29 of 60 | 0 |
| m6 | 2.05 | 0.26 | 2.60 | 1.59 | 0.05 | 2.39 | 8 / 5 / 13 of 30 | 0 |
| m7 | 2.06 | -0.98 | 3.00 | 2.18 | -0.63 | 3.58 | 25 / 33 / 58 of 100 | 0 |
| m8 | 2.18 | -0.77 | 4.14 | 2.54 | 0.04 | 3.68 | 20 / 15 / 35 of 60 | 0 |
| m9 | 1.89 | 1.86 | 2.89 | 1.89 | 1.86 | 2.91 | 3 / 4 / 7 of 100 | 0 |
| m10 | 1.89 | 1.84 | 2.89 | 1.89 | 1.86 | 2.89 | 4 / 4 / 8 of 100 | 0 |
| m11 | 1.86 | 1.86 | 2.88 | 1.86 | 1.84 | 2.88 | 4 / 1 / 5 of 100 | 0 |
| m12 | 1.89 | 1.86 | 2.02 | 1.89 | 1.86 | 2.88 | 2 / 2 / 4 of 100 | 0 |
| m13 | 1.89 | 1.86 | 2.96 | 1.88 | 1.86 | 2.95 | 7 / 4 / 11 of 100 | 0 |
| m14 | 2.86 | 1.86 | 4.23 | 2.86 | 1.88 | 17.91 | 44 / 54 / 98 of 100 | 0 |
| m15 | 2.86 | 2.26 | 3.88 | 2.86 | 1.86 | 3.88 | 55 / 44 / 99 of 100 | 0 |

**876 of 1670 validation trials have the command rise outside ±2 frames of the onset frame.** The onsets were NOT changed (spec rule). Notable patterns:
- m1, m2: the command rises 4.65–6.67 (m1) and 5.53–6.86 (m2) frames after the onset frame, in every trial (OL and CL). The onset defined from stimStarts precedes the laser by ~0.16–0.18 s (median) in these two sessions, versus ~0.04–0.08 s in the others.
- m3–m8: the offset jitters trial to trial over roughly −5 … +4 frames.
- m9–m13: offsets cluster at ~1.9 frames with a minority at ~2.9 frames (outside ±2) and a few at 2.0–2.2.
- m3–m8 offsets drift gradually from trial to trial and then wrap (saw-tooth pattern in trial order), e.g. m4 trials 115–132 run from −2.5 to −4.9 frames.
- m14, m15: the rise is at ~2.9 frames in nearly all trials (just outside ±2), OL max 4.2 frames. The longest delays (m14 CL trials, up to 17.9 frames) occur only in CL trials and are compatible with the controller output staying at zero while dFk is below the reference (e.g. m14 trials 71 and 89 start below −5 %); not investigated further.
- Old-build commands (m1–m13) are a 35 Hz pulsed waveform (frame-locked half-sine pulses whose amplitude carries the control); new builds are a per-frame staircase.

Every trial outside ±2 frames (trial_index = 1-based input_params column, condition, offset in frames):

- **m1** (120): 3CL(+5.8), 4OL(+5.8), 5CL(+5.7), 6OL(+5.7), 7CL(+6.7), 8OL(+4.6), 9OL(+5.6), 10OL(+5.6), 11CL(+5.5), 12CL(+5.5), 13CL(+6.5), 14CL(+5.4), 15CL(+5.4), 16CL(+5.4), 17OL(+6.4), 18CL(+6.3), 19OL(+6.3), 20OL(+5.2), 21CL(+5.2), 22OL(+5.2), 23CL(+6.1), 24OL(+6.1), 25CL(+6.1), 26CL(+5.0), 27CL(+6.0), 28CL(+5.9), 29CL(+5.9), 30CL(+5.9), 31CL(+5.9), 32OL(+4.8), 33OL(+5.8), 34CL(+5.8), 35OL(+5.7), 36OL(+5.7), 37OL(+6.7), 38OL(+5.6), 39OL(+5.6), 40OL(+5.6), 41OL(+5.5), 42OL(+5.5), 43CL(+6.4), 44CL(+5.4), 45OL(+5.4), 46OL(+5.4), 47CL(+5.3), 48CL(+6.3), 49CL(+6.2), 50OL(+5.2), 51OL(+5.2), 52OL(+5.1), 53CL(+6.1), 54CL(+6.1), 55CL(+6.0), 56CL(+5.0), 57OL(+6.0), 58CL(+5.9), 59OL(+5.9), 60OL(+5.9), 61CL(+5.8), 62OL(+5.8), 63CL(+5.8), 64CL(+5.7), 65CL(+5.7), 66OL(+5.7), 67CL(+5.6), 68OL(+5.6), 69CL(+5.6), 70OL(+5.5), 71OL(+5.5), 72CL(+5.5), 73CL(+6.4), 74CL(+5.4), 75OL(+5.4), 76CL(+5.3), 77CL(+5.3), 78CL(+6.2), 79CL(+6.2), 80CL(+5.2), 81CL(+5.1), 82OL(+5.1), 83CL(+6.1), 84OL(+6.1), 85CL(+6.0), 86OL(+5.0), 87OL(+6.0), 88CL(+5.9), 89OL(+5.9), 90CL(+5.8), 91CL(+5.8), 92CL(+5.8), 93OL(+5.8), 94OL(+5.7), 95OL(+5.7), 96CL(+5.6), 97CL(+6.6), 98OL(+5.6), 99OL(+5.6), 100OL(+5.5), 101CL(+5.5), 102CL(+6.4), 103CL(+5.4), 104CL(+5.4), 105CL(+5.3), 106CL(+5.3), 107OL(+6.3), 108OL(+5.3), 109OL(+5.2), 110CL(+5.2), 111OL(+5.2), 112OL(+6.1), 113OL(+6.1), 114OL(+6.1), 115CL(+5.0), 116CL(+6.0), 117OL(+6.0), 118OL(+5.9), 119OL(+5.9), 120OL(+5.9), 121CL(+5.8), 122CL(+5.8)
- **m2** (200): 21OL(+6.8), 22OL(+6.8), 23CL(+5.8), 24CL(+6.7), 25OL(+6.7), 26CL(+6.7), 27OL(+6.6), 28CL(+6.6), 29CL(+6.5), 30CL(+6.5), 31CL(+6.5), 32OL(+6.5), 33CL(+6.4), 34OL(+6.4), 35CL(+6.3), 36OL(+6.3), 37OL(+6.3), 38CL(+6.2), 39CL(+6.2), 40OL(+6.2), 41CL(+6.1), 42OL(+6.1), 43CL(+6.1), 44OL(+6.0), 45CL(+6.0), 46CL(+6.0), 47CL(+5.9), 48CL(+5.9), 49CL(+5.9), 50OL(+5.8), 51CL(+5.8), 52OL(+6.8), 53OL(+6.7), 54OL(+6.7), 55OL(+6.7), 56OL(+6.6), 57CL(+6.6), 58CL(+6.6), 59OL(+6.5), 60CL(+6.5), 61OL(+6.5), 62OL(+6.4), 63OL(+6.4), 64CL(+6.4), 65CL(+6.3), 66CL(+6.3), 67OL(+6.2), 68CL(+6.2), 69CL(+6.2), 70CL(+6.2), 71OL(+6.1), 72CL(+6.1), 73OL(+6.1), 74CL(+6.0), 75CL(+6.0), 76CL(+5.9), 77CL(+5.9), 78CL(+5.9), 79CL(+5.8), 80OL(+5.8), 81CL(+5.8), 82CL(+5.7), 83OL(+5.7), 84CL(+6.7), 85OL(+5.6), 86OL(+6.6), 87CL(+5.6), 88OL(+6.6), 89OL(+6.5), 90OL(+6.5), 91CL(+6.4), 92CL(+6.4), 93OL(+6.4), 94OL(+6.4), 95CL(+6.3), 96OL(+6.3), 97CL(+6.2), 98OL(+6.2), 99CL(+6.2), 100CL(+6.1), 101OL(+6.1), 102CL(+6.1), 103OL(+6.1), 104OL(+6.0), 105OL(+6.0), 106CL(+5.9), 107CL(+5.9), 108OL(+5.9), 109OL(+5.8), 110CL(+5.8), 111CL(+5.8), 112CL(+6.7), 113CL(+6.7), 114CL(+5.6), 115CL(+6.6), 116OL(+6.6), 117OL(+6.6), 118OL(+5.5), 119CL(+6.5), 120OL(+6.5), 121OL(+6.4), 122CL(+6.4), 123CL(+6.4), 124OL(+6.3), 125CL(+6.3), 126OL(+6.3), 127OL(+6.2), 128CL(+6.2), 129CL(+6.1), 130OL(+6.1), 131CL(+6.1), 132OL(+6.1), 133OL(+6.0), 134OL(+6.0), 135OL(+6.0), 136OL(+5.9), 137OL(+5.9), 138CL(+6.9), 139CL(+6.8), 140OL(+6.8), 141CL(+6.8), 142CL(+6.7), 143CL(+6.7), 144OL(+6.6), 145CL(+6.6), 146OL(+6.6), 147CL(+6.5), 148OL(+6.5), 149OL(+6.5), 150CL(+6.4), 151OL(+6.4), 152OL(+6.4), 153OL(+6.3), 154OL(+6.3), 155CL(+6.3), 156OL(+6.2), 157CL(+6.2), 158OL(+6.2), 159CL(+6.2), 160OL(+6.1), 161CL(+6.1), 162OL(+6.0), 163OL(+6.0), 164CL(+6.0), 165OL(+5.9), 166CL(+5.9), 167OL(+5.9), 168OL(+5.8), 169OL(+5.8), 170CL(+5.8), 171OL(+5.7), 172CL(+6.7), 173CL(+6.7), 174CL(+6.6), 175CL(+6.6), 176CL(+5.5), 177CL(+6.5), 178OL(+6.5), 179OL(+6.5), 180OL(+6.4), 181OL(+6.4), 182OL(+6.4), 183CL(+6.3), 184CL(+6.3), 185OL(+6.3), 186CL(+6.2), 187OL(+6.2), 188OL(+6.2), 189CL(+6.1), 190CL(+6.1), 191CL(+6.1), 192CL(+6.0), 193OL(+6.0), 194OL(+6.0), 195CL(+5.9), 196CL(+5.9), 197CL(+5.8), 198CL(+5.8), 199CL(+5.8), 200CL(+6.7), 201OL(+6.7), 202CL(+6.7), 203CL(+6.6), 204OL(+6.6), 205CL(+6.6), 206CL(+6.5), 207CL(+6.5), 208CL(+6.5), 209OL(+6.5), 210OL(+6.4), 211CL(+6.4), 212OL(+6.3), 213OL(+6.3), 214OL(+6.3), 215OL(+6.2), 216CL(+6.2), 217OL(+6.2), 218OL(+6.1), 219OL(+6.1), 220OL(+6.1)
- **m3** (90): 26OL(+3.6), 27OL(+2.0), 28CL(+2.2), 29CL(+2.4), 30OL(+2.6), 31OL(+2.1), 32OL(+2.9), 33OL(+2.1), 34OL(+2.3), 35CL(+2.5), 37CL(+2.1), 62OL(-2.6), 63OL(-2.4), 64CL(-2.9), 65CL(-2.8), 66OL(-2.6), 67CL(-2.4), 68OL(-2.9), 69CL(+2.6), 70CL(+2.1), 71CL(+2.2), 72OL(+2.4), 73CL(+2.6), 74CL(+2.1), 75OL(+2.3), 89OL(+2.5), 91OL(+2.1), 92CL(+2.3), 93CL(+2.5), 95OL(+3.5), 96CL(+2.0), 97OL(+2.2), 98OL(+2.4), 99OL(+2.6), 100CL(+3.5), 101OL(+2.6), 102CL(+2.1), 103CL(+2.3), 104OL(+2.5), 106CL(+3.5), 108CL(+2.2), 109OL(+2.4), 110CL(+2.5), 111OL(+2.0), 112CL(+2.2), 119OL(+2.1), 120CL(+2.3), 121OL(+2.5), 123OL(+2.2), 137CL(+2.4), 138CL(+2.6), 139OL(+2.0), 140CL(+2.2), 141CL(+2.4), 142OL(+2.6), 148CL(+2.4), 149CL(+2.5), 150CL(+2.0), 151OL(+2.2), 152CL(+2.4), 153CL(+3.3), 154OL(+2.4), 156CL(+2.1), 157OL(+2.3), 158OL(+2.5), 159CL(+3.3), 160CL(+2.5), 162OL(+2.2), 163OL(+2.4), 164OL(+2.5), 165CL(+3.4), 166OL(+2.6), 167OL(+2.1), 168CL(+2.3), 169OL(+2.4), 170OL(+2.6), 171OL(+2.1), 190CL(-2.0), 195OL(-2.8), 196CL(-2.6), 197OL(-2.5), 198CL(-3.0), 199CL(-2.8), 200OL(-2.6), 201CL(-2.4), 202OL(+2.4), 203CL(+2.5), 205OL(+2.2), 206OL(+2.4), 207OL(+2.5)
- **m4** (99): 14OL(+2.3), 15CL(+2.5), 16CL(+2.4), 17OL(+2.5), 18OL(+2.0), 19CL(+2.2), 20CL(+2.4), 21CL(+2.6), 28OL(+2.5), 30CL(+2.2), 31CL(+2.4), 32CL(+2.5), 33CL(+2.0), 53CL(+2.3), 54OL(+2.5), 55CL(+2.7), 56CL(+2.1), 57CL(+2.3), 58OL(+2.5), 59OL(+3.4), 60OL(+2.6), 61OL(+2.1), 62CL(+2.2), 63OL(+2.4), 64OL(+2.6), 80CL(-2.1), 84CL(-2.0), 85CL(+2.1), 86CL(+2.2), 87OL(+2.4), 88OL(+2.6), 89OL(+2.1), 90OL(+2.3), 112CL(-2.0), 115CL(-2.5), 116CL(-3.0), 117OL(-2.8), 118OL(-2.6), 119CL(-2.5), 120OL(-3.0), 121OL(-2.8), 122CL(-3.6), 123OL(-3.4), 124OL(-4.0), 125OL(-3.8), 126CL(-3.6), 127OL(-4.4), 128OL(-4.9), 129CL(-4.8), 130OL(-4.6), 131OL(-4.4), 132OL(-4.9), 134CL(+2.2), 135OL(+2.3), 136CL(+2.5), 138CL(+2.2), 145OL(+2.1), 146CL(+2.3), 147CL(+2.5), 149CL(+2.2), 163CL(+2.4), 164OL(+2.6), 165OL(+2.0), 166OL(+2.2), 167CL(+2.4), 168CL(+2.6), 175CL(+2.5), 177CL(+2.2), 178CL(+2.4), 179OL(+3.2), 180CL(+2.4), 181CL(+2.6), 182CL(+2.1), 183OL(+2.2), 184OL(+3.1), 185OL(+2.3), 186CL(+2.5), 187OL(+2.7), 188OL(+2.2), 189CL(+3.0), 190CL(+2.2), 191OL(+2.4), 192CL(+2.6), 193CL(+2.1), 194CL(+2.2), 195OL(+3.1), 196CL(+2.3), 197OL(+2.5), 198OL(+2.6), 199CL(+2.1), 200CL(+2.3), 201OL(+3.2), 202CL(+2.4), 203OL(+2.5), 204CL(+2.0), 205CL(+2.2), 206CL(+2.4), 207OL(+2.6), 208OL(+2.0)
- **m5** (29): 56CL(+2.5), 58OL(+2.2), 59CL(+2.3), 60CL(+2.5), 80CL(+2.1), 81OL(+2.3), 82CL(+2.5), 83OL(+2.6), 84CL(+2.1), 85OL(+2.3), 86OL(+3.2), 87OL(+2.4), 88CL(+2.5), 89OL(+2.0), 90OL(+2.2), 91OL(+2.4), 92OL(+2.6), 99OL(+2.5), 101OL(+2.2), 102CL(+2.4), 103CL(+2.5), 104OL(+3.4), 105CL(+2.6), 106CL(+2.1), 107OL(+2.3), 108CL(+2.4), 109OL(+2.6), 110OL(+3.5), 111OL(+2.7)
- **m6** (13): 3OL(+2.0), 4CL(+2.2), 5CL(+2.4), 17CL(+2.2), 18OL(+2.4), 19OL(+2.6), 20CL(+2.1), 21OL(+2.2), 28OL(+2.2), 29CL(+2.4), 30OL(+2.6), 31OL(+2.1), 32OL(+2.2)
- **m7** (58): 6CL(+2.1), 7OL(+2.4), 8OL(+2.5), 9CL(+3.4), 10CL(+2.6), 11OL(+2.1), 12CL(+2.2), 13CL(+2.4), 14CL(+3.3), 15CL(+2.5), 16CL(+2.6), 17CL(+2.1), 18OL(+2.3), 19CL(+2.5), 20CL(+2.7), 21OL(+2.1), 28OL(+2.1), 29OL(+2.3), 30CL(+2.4), 31CL(+2.6), 32CL(+2.1), 33OL(+3.0), 34OL(+2.2), 35OL(+2.4), 36CL(+2.5), 37OL(+2.0), 38CL(+3.6), 39OL(+2.1), 40CL(+2.2), 41OL(+2.4), 42OL(+2.6), 43CL(+3.5), 45CL(+2.1), 46OL(+2.4), 47CL(+2.5), 48OL(+2.7), 49OL(+2.2), 56CL(+2.1), 57OL(+2.3), 58CL(+2.5), 60OL(+2.2), 61CL(+2.3), 79CL(+2.2), 80OL(+2.4), 81CL(+2.6), 82OL(+2.1), 83OL(+2.3), 91OL(+2.4), 92CL(+2.6), 93OL(+2.1), 94CL(+2.2), 95CL(+3.1), 96CL(+2.3), 97CL(+2.5), 98CL(+2.7), 99CL(+2.1), 100OL(+2.3), 101CL(+2.5)
- **m8** (35): 3CL(+2.2), 4OL(+2.3), 5CL(+2.5), 7OL(+2.2), 8OL(+2.4), 9OL(+2.5), 15CL(+3.0), 16OL(+3.2), 17CL(+3.4), 18OL(+3.6), 19OL(+3.0), 20OL(+2.2), 21OL(+2.4), 22CL(+2.6), 23CL(+2.1), 24OL(+2.2), 25OL(+2.4), 26CL(+2.6), 33CL(+3.2), 34OL(+3.4), 35OL(+3.6), 36CL(+3.1), 37CL(+3.3), 38OL(+4.1), 39CL(+3.3), 40OL(+3.5), 41CL(+3.7), 42OL(+3.2), 43OL(+3.4), 44OL(+2.5), 46OL(+2.2), 47OL(+2.4), 48CL(+2.5), 49CL(+2.7), 50CL(+2.2)
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

Onset frame vs stimStarts (all sessions): max |timeBlue[onset] − stimStarts| = m1 0.0000 s, m2 0.0000 s, m3 0.0000 s, m4 0.0000 s, m5 0.0000 s, m6 0.0000 s, m7 0.0000 s, m8 0.0000 s, m9 0.0000 s, m10 0.0000 s, m11 0.0000 s, m12 0.0000 s, m13 0.0000 s, m14 0.0005 s, m15 0.0000 s

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
  m1 -0.0148 V / 0.00; m2 -0.0128 V / 0.01; m3 -0.0059 V / 0.97; m4 -0.0075 V / 0.90; m5 -0.0105 V / 0.36; m6 -0.0105 V / 0.40; m7 -0.0128 V / 0.15; m8 -0.0125 V / 0.14; m9 -0.0102 V / 0.46; m10 -0.0102 V / 0.44; m11 -0.0076 V / 0.85; m12 -0.0105 V / 0.36; m13 -0.0102 V / 0.45; m14 +0.0082 V / 0.69; m15 +0.0148 V / 0.08.
  For the old builds the CL command is also a 35 Hz pulse train, so samples at |u| < 0.01 V inside 0–3 s include pulse troughs, not only frames where the controller output is at zero. Reported as computed (pre-specified); interpret with care.

## 8. Sensitivity: m14 with dFk end-aligned (dFk[i] → timeBlue[i+11])

Session values for m14:

| quantity | m14_start_aligned | m14_shift11 |
|---|---|---|
| rmse_ratio_full | 0.8822 | 0.8739 |
| var_ratio_full | 0.6194 | 0.6389 |

Main tests, primary vs m14-shifted (other 14 sessions unchanged):

| figure | quantity | window_or_state | role | effect | p | wilcoxon_p | k | k_n | holm_p | effect_m14shift | p_m14shift | wilcoxon_p_m14shift | k_m14shift | k_n_m14shift | holm_p_m14shift |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fig3 | rmse_ratio | full | main | 0.7675 | 9.201e-08 | 6.104e-05 | 15.0000 | 15.0000 | NaN | 0.7670 | 8.01e-08 | 6.104e-05 | 15.0000 | 15.0000 | NaN |
| fig3 | var_ratio | full | main | 0.5814 | 7.357e-06 | 0.0001221 | 14.0000 | 15.0000 | NaN | 0.5826 | 7.83e-06 | 0.0001221 | 14.0000 | 15.0000 | NaN |
| fig4d | P | init_dev | main | 0.1529 | 0.0603 | 0.0833 | 11.0000 | 15.0000 | 0.1810 | 0.1439 | 0.0787 | 0.0946 | 10.0000 | 15.0000 | 0.2361 |
| fig4d | R | init_dev | main | 0.1618 | 0.0060 | 0.0015 | 13.0000 | 15.0000 | 0.0421 | 0.1533 | 0.0085 | 0.0015 | 13.0000 | 15.0000 | 0.0597 |
| fig4d | A | init_dev | main | 0.0193 | 0.5148 | 0.5995 | 9.0000 | 15.0000 | 0.5148 | 0.0166 | 0.5724 | 0.6788 | 9.0000 | 15.0000 | 0.5724 |
| fig4d | P | motion | main | 0.2360 | 0.0113 | 0.0020 | 10.0000 | 11.0000 | 0.0652 | 0.2372 | 0.0109 | 0.0020 | 10.0000 | 11.0000 | 0.0597 |
| fig4d | R | motion | main | -0.0759 | 0.1326 | 0.3203 | 6.0000 | 11.0000 | 0.2651 | -0.0612 | 0.1607 | 0.3203 | 6.0000 | 11.0000 | 0.3215 |
| fig4d | A | motion | main | -0.1430 | 0.0019 | 0.0009766 | 11.0000 | 11.0000 | 0.0077 | -0.1398 | 0.0023 | 0.0009766 | 11.0000 | 11.0000 | 0.0091 |
| fig4d | P | rel_delta | main | -0.0031 | 0.9520 | 0.5245 | 9.0000 | 15.0000 | 0.9520 | -0.0030 | 0.9531 | 0.5245 | 9.0000 | 15.0000 | 0.9531 |
| fig4d | R | rel_delta | main | 0.0929 | 0.0399 | 0.0302 | 10.0000 | 15.0000 | 0.1596 | 0.0991 | 0.0321 | 0.0302 | 10.0000 | 15.0000 | 0.1282 |
| fig4d | A | rel_delta | main | 0.0473 | 0.0390 | 0.0151 | 13.0000 | 15.0000 | 0.1171 | 0.0510 | 0.0263 | 0.0125 | 13.0000 | 15.0000 | 0.0789 |
| fig4d | P | abs_delta | main | 0.2708 | 0.0109 | 0.0103 | 13.0000 | 15.0000 | 0.0652 | 0.2799 | 0.0092 | 0.0084 | 13.0000 | 15.0000 | 0.0597 |
| fig4d | R | abs_delta | main | 0.3277 | 0.0007002 | 6.104e-05 | 15.0000 | 15.0000 | 0.0056 | 0.3283 | 0.0007001 | 6.104e-05 | 15.0000 | 15.0000 | 0.0056 |
| fig4d | A | abs_delta | main | 0.0678 | 0.0818 | 0.0353 | 12.0000 | 15.0000 | 0.1637 | 0.0669 | 0.0846 | 0.0353 | 12.0000 | 15.0000 | 0.1693 |
