# Brain Paper — closed-loop widefield optogenetic controller

Mouse / session roster for the project. **Authoritative** — pulled from the live
`load_sessions.m` session struct and the impulse / bilateral loaders (last verified
2026-09-26). Update this table whenever a session is added, excluded, or re-cached.

For working context see `CLAUDE.md`; per-change log in `RESEARCH.md`; task list in `TASKS.md`.

## Mice at a glance

| Area | Mice | Sessions |
|---|---|---|
| Controller (CL/OL) | AL_0033, AL_0039, AL_0048, AL_0051 | 15 candidates → **13 qualifying** |
| Impulse | AL_0041, AL_0033 | 3 |
| Bilateral (dual-opsin) | AL_0048 | 3 controller + 1 grid |

Reference level: `d.ref = -5` %ΔF/F project-wide (bilateral: left/excit `+5`, right/inhib `-5`, switchable).

## Controller analysis (CL/OL) — `load_sessions.m`

15 candidate sessions (m1–m15), 4 mice. 13 qualify for the disturbance-rejection
analysis; 2 are skipped (no Stage-1/2 predictor cache).

Candidate counts: AL_0033 = 9 · AL_0039 = 4 · AL_0048 = 1 · AL_0051 = 1
Qualifying counts (R² pipeline): AL_0033 = 8 · AL_0039 = 3 · AL_0048 = 1 · AL_0051 = 1 → **13**

| id | mouse | date | exp | notes |
|---|---|---|---|---|
| m1  | AL_0033 | 2025-01-20 | e3 | **skipped** — no cache |
| m2  | AL_0033 | 2025-02-12 | e2 | |
| m3  | AL_0033 | 2025-02-24 | e2 | |
| m4  | AL_0033 | 2025-02-26 | e2 | step-response (`custom_idx`) |
| m5  | AL_0033 | 2025-03-04 | e1 | |
| m6  | AL_0033 | 2025-03-05 | e2 | |
| m7  | AL_0033 | 2025-03-20 | e4 | |
| m8  | AL_0033 | 2025-04-15 | e2 | |
| m9  | AL_0039 | 2025-04-20 | e1 | step-response (`custom_idx`) |
| m10 | AL_0039 | 2025-04-19 | e1 | |
| m11 | AL_0039 | 2025-04-30 | e3 | step-response (`custom_idx`) |
| m12 | AL_0033 | 2025-04-19 | e1 | |
| m13 | AL_0039 | 2025-04-20 | e2 | **skipped** — no cache |
| m14 | AL_0048 | 2026-07-29 | e2 | dual-opsin, static-ref |
| m15 | AL_0051 | 2026-07-29 | e2 | static-ref |

- Step-response sessions: `custom_idx = [4 9 11]`.
- **AL_0050**: excluded (poor stim).

## Impulse analysis — 3 sessions, 2 mice

| mouse | date | exp | notes |
|---|---|---|---|
| AL_0041 | — | e1 | stim mode 2 (absolute sample index) |
| AL_0041 | — | e2 | stim mode 2; no 0 V catch trials |
| AL_0033 | 2025-01-29 | e1 | exp 3; stim mode 1; **canonical** `selExp = 3` for TF fit / contra-prediction |

Contra-prediction headline is AL_0033 0129 e1 only (n = 1); AL_0041 replication pending.

## Bilateral (dual-opsin AL_0048, excit-left / inhib-right) — `bilateral/load_bilateral.m`

| mouse | date | exp | notes |
|---|---|---|---|
| AL_0048 | 2026-07-01 | e6 | sine FF-analysis, 4 modes, right side, 99 trials |
| AL_0048 | 2026-07-14 | e1 | imaging preprocessed, controller CSVs pending |
| AL_0048 | 2026-07-21 | e1 | sine FFA, 258 trials; `pixel_R = [407 367]` (galvo sign-flip fix) |

- AL_0048 2026-06-05 e2 is commented out of the registry.
- Grid (Python, `opto_brainGrid638`): AL_0048 2026-06-24 e2 — 52-position 638 nm photostim spatial map.
