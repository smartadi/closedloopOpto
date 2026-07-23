# Case for a relative delta-band measure in the Figure 4 state-dependence analysis

**For:** Nick · **From:** Aditya · **Date:** 2026-07-23
**Decision requested:** permission to use *relative* 2–4 Hz power (band ÷ total) as a
brain-state **regressor** in the controllability analysis, alongside our existing
rule that **displayed power spectra stay absolute**.

---

## The standing rule

Our locked convention (root `CLAUDE.md`; `methods_edit.tex` §Power spectral analysis,
L658–663) is: *"absolute (ΔF/F)² Hz⁻¹ only — no z-scoring or relative normalisation at
any stage."* That rule is right for the **spectral display panels** and I am not
proposing to change it there. The question is narrower: what measure do we regress
tracking error on when we ask *which brain states the controller fails to reject*.

## The problem absolute power creates here

RMSE is itself a **magnitude** of the ΔF/F signal. Absolute delta-band power is *also*
a magnitude of the same signal. So regressing one on the other is close to circular —
you are correlating the size of a signal with the size of the same signal in a
sub-band. Concretely, at the session level:

- **Absolute delta → CL slope +1.08, p < 0.001** — looks strong, but it is the same
  signal-power confound that sank the impulse-side variance/δ claim we retracted on
  2026-07-01. It cannot separate "this brain state is hard to control" from "this trial
  simply has a larger signal."

A referee will make exactly this objection, and they will be right.

## Why the relative measure is the fix, not a fudge

Relative 2–4 Hz power = (2–4 Hz band power) ÷ (total 0.4–10 Hz power). It is a measure
of **spectral composition** — what *fraction* of the activity is in that band —
**independent of the overall signal magnitude**. It asks a different, non-circular
question: *does the controller do worse when a larger share of the ongoing activity is
2–4 Hz, holding total power aside?*

That question survives every control we can throw at it:

| Test | Result |
|---|---|
| Mixed-effects, session + animal random effects¹ | rel-24 standardized β = **+0.129 [0.041, 0.216], t = 2.89, p = 0.0040** |
| Per-session signed-rank, OL-vs-CL interaction (late 1–3 s window) | **p = 0.048 (\*)** |
| **1–2 Hz relative (large slow waves) — null control** | interaction **p = 0.38 (n.s.)** |

¹ `rmse ~ rel24 + (1 + rel24 | session) + (1 | animal)`, 752 CL trials, 13 sessions,
2 animals.

The **null control is the decisive point**. If any normalization mechanically produced
a hit, the 1–2 Hz relative band would light up too. It does not. Only the 2–4 Hz
composition predicts closed-loop error; the large-amplitude 1–2 Hz slow waves are a
clean null. That specificity is not something a signal-power artifact can produce — it
is a genuine, band-specific brain-state effect. (It also refines the original
intuition: the huge slow waves are *not* what the controller fails on; the faster
2–4 Hz activity is.)

## What I'm actually asking for

1. Keep **displayed spectra absolute** — no change to the rule as it governs figures.
2. Permit **relative 2–4 Hz power as a state regressor** in the controllability
   analysis only, with the absolute-power confound and the 1–2 Hz null control both
   stated explicitly in Methods so the reasoning is on the page.
3. In text, quote the **mixed-effects p = 0.0040** as the headline (it is the estimate
   that survives both session and animal clustering), not the per-session signed-rank,
   which is z-baseline-sensitive.

## The honest caveats

- **Two animals.** The animal random effect is estimated from n = 2, so it clusters but
  does not richly generalize. State as a limitation.
- The per-session signed-rank p wobbles with the z-scoring base (0.021 CL-only vs 0.068
  pooled); this is exactly why the mixed model is the headline number.
- The effect is **late-window (1–3 s, settled)**; in the full window the OL slope is
  messy. We restrict the delta claim to the disturbance-rejection window and say so.

## If the answer is no

If you would rather not use any relative measure, the fallback is to **drop delta as a
controllability factor** entirely (absolute delta is confounded and unusable), and
Figure 4 rests on **motion** (the clean, power-independent decoupling, p = 0.0078) plus
**initial deviation** (positive control). That is a smaller but fully defensible figure.
I'd prefer to keep delta because the motion-yes / delta-no contrast is what motivates
the feedforward/MPC direction — but it is your call.
