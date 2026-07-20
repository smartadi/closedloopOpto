# Rig expDefs — bilateral impulse (638 nm)

Rigbox/Signals experiment definitions **for the experiment rig, not this PC**. They are
written and version-controlled here, then **copied manually** to the server:

```
\\sahale.biostr.washington.edu\data\Code\Rigging\ExpDefinitions\WidefieldOpto\
```

Nothing here writes to the server automatically.

## `opto_bilateralImpulse638.m`

This is the server's `opto_pulses638.m` with only the condition option-vectors edited —
same signals plumbing, same `outputs.opto638` struct, same `CombVec` build, same
`getDelay`. It runs a single-widefield-frame impulse dose-response on the AL_0048
dual-opsin bilateral mouse.

Edits vs `opto_pulses638.m`:
- `laserDurOpts = [1/35]` — impulse = one widefield frame (~28.6 ms @ 35 Hz).
- `laserAmpOpts = [0 0.5 1.0 1.5]` — 4 amps (0 = sham).
- `galvoXPosOpts = [-2.5 2.5]`, `galvoYPosOpts = [-3.0]` — two mirrored spots, one per
  hemisphere (`galvoX<0` left/excitatory, `galvoX>0` right/inhibitory, per
  `bilateral/load_bilateral.m`).
- `p.numRepeats = repmat(numRepeats, 1, ...)` — the one addition `opto_pulses638.m`
  lacks; guarantees `numRepeats` (default 100) trials per condition instead of relying
  on the MC GUI.

Condition count: 4 amps × 1 dur × 2 spots = **8 conditions × 100 = 800 trials**,
interleaved/randomised by MC. ≈ **60 min** run time (range ~47–74 min with ITI jitter).

Amp count trimmed to 4 (from 6) so 100 reps fit in ~1 h **while keeping the 3–5 s gap**:
the onset-to-onset spacing (≥3.53 s) clears the `settle_s = 2.0` + 0.5 s baseline that
`impulse-analysis/ols_pixel_predictor.m` needs for clean pre-onset baselines and
spontaneous interstim training frames. Shorter-gap configs (which kept more amps) would
violate that — see RESEARCH 2026-07-10.

### Set before running (top `try` block)
1. `galvoXPosOpts` / `galvoYPosOpts` — actual bregma-relative spot coordinates. **Both
   spots must share the same Y** (single-valued `galvoYPosOpts`); otherwise `CombVec`
   expands into a full X×Y grid rather than two spots.
2. `laserAmpOpts` — calibrate the 4 power values per opsin.
3. `laserDurOpts` — `1/35` tracks the widefield frame rate; change if the rig runs at a
   different rate.
4. `numRepeats` — trials per condition (lower it if the full run is too long).

### Timing (gap between impulses)
One impulse per trial. Per-trial structure:
- `getDelay` — **fixed 0.5 s** pre-onset delay (galvo settles at the new spot + baseline).
- impulse (~0.029 s).
- `getITI` — **3 + rand·2 s (3–5 s)** gap after the impulse: keeps impulses non-periodic
  and lets the response fully decay before the next trial.

Impulse onset-to-onset spacing ≈ **3.5–5.5 s** (0.5 s settle + 3–5 s gap). To change the
gap, edit `getITI` (`3 + rand*2`); to change settle time, edit `getDelay`. For a strict
3–5 s onset-to-onset, drop the 0.5 s pre-delay — but keep some settle time given the
left↔right galvo swing.
