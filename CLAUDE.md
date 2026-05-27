# CLAUDE.md — Brain Paper

## Mandatory: Log every significant session action

After **any** of the following, append an entry to the `## Change Log` section of `RESEARCH.md`:
- Editing a MATLAB script (even a small fix)
- Discovering a bug, artifact, or unexpected data behaviour
- Running an analysis and observing a result
- Changing a figure, axis, or export parameter
- Deciding *not* to do something for a non-obvious reason

**Format:**
```
### YYYY-MM-DD — <one-line title>
**Changed/Found:** `<script.m>` — <what specifically changed or was found>
**Why:** <reason, constraint, or observation that motivated it>
**Next:** <what should be verified or done as a follow-up>
```

One entry per change. Do not skip — the log is the primary record between git commits.

---

## Area detection and context loading

**Infer the area from the first message** (impulse / controller / paper-writing).
Then read the matching sub-area CLAUDE.md before starting work. Do not read more than one.

| Trigger words | Sub-area file to read |
|---|---|
| impulse, TF fit, dose-response, AL_0041 | `impulse-analysis/CLAUDE.md` |
| controller, plottingScript, CL vs OL, MSE, sessions | `controller-analysis/CLAUDE.md` |
| manuscript, LaTeX, results_edit, paper, Overleaf | `paper-writing/CLAUDE.md` |

After reading the sub-area file, also check:
- `TASKS.md` for the current priority tier
- `FINDINGS.md` for relevant completed findings (grep by keyword, not full read)
- `MEETINGS.md` for relevant Nick decisions (grep by date, not full read)

---

## Context management rules

**Never read a large script in full.** Always:
1. `Grep` to locate the section (function name, `%%` header, keyword).
2. `Read` with `offset` + `limit` for that section only.

**Never re-read a file** already read this session unless you edited it.

**Never load multiple large files at once.** One relevant section at a time.

**For the change log:** `Grep RESEARCH.md` with a date or keyword. Never read in full.

**For FINDINGS.md:** Grep by keyword (e.g. "contralateral", "variance", "TF"). Never read in full once it grows large.

---

## Export format rule

**Never export a figure to PDF unless explicitly told it is a paper panel.**
- Default: `exportgraphics(..., 'Resolution', 300)` → `.png`
- PDF only for panels listed in `PAPER.md` under "Paper panels in use", or user says "paper panel / paper figure".
- If unsure, use PNG.

---

## Locked-in project decisions

These are final — do not question or re-derive unless the user explicitly reopens them.

### Data & sessions
- Two mice: **AL_0033** (8 sessions), **AL_0039** (3 sessions), plus **AL_0041** for impulse experiments
- 13 controller sessions total (m1–m13)
- Reference level: `d.ref = −5` (percent ΔF/F), project-wide default

### Impulse analysis
- Inhibition energy = mean ΔF/F over **0–200 ms** post-onset (`peak_mode = 3`), not peak trough
- Error bars: **95th-percentile bounds** (2.5th–97.5th percentile) on median plot; SEM on mean plot
- Stim detection: **mode 1** for AL_0033/AL_0039; **mode 2** (absolute index) for AL_0041
- TF fit currently on `selExp = 3` (AL_0033, 2025-01-29); sweep 1–3 poles, 0–2 zeros, 0–5 sample delay; AIC selection

### Controller / CL vs OL
- MSE window: **t = 0 s to +3 s** for trial MSE analysis, **t = +1 s to +3 s** only for disturbance rejection in one panel,post-laser onset (skips inhibitory transient)
- Power spectra: **absolute (ΔF/F)² Hz⁻¹** only — no normalization, no z-scoring at any stage
- Motion exclusion threshold: `motThresh = 1.5` (z-scored motion)
- Step response sessions: `custom_idx = [4 9 11]` (m4=AL_0033 2025-02-26, m9/m11=AL_0039)

### Figure style
- Size: **6 cm W × 4 cm H** default; see PAPER.md for per-panel sizes
- Font: **6 pt bold** throughout
- Line widths: mean=1.5 pt, fit=1.2 pt, individual trials=0.4 pt, ref=1.0 pt
- Shading: ±std for single-session traces; ±SEM for cross-session means
- Legend: `ItemTokenSize [6 6]`
- Helper: `paperFig(w, h)` for figure creation; `paperStyle()` for style constants
- Export: `exportgraphics(..., 'ContentType', 'vector')` for line-art; 300 dpi PNG for heatmaps

### Manuscript
- Target style: Li & Lu et al. — active voice, results-first topic sentences, no equation refs in Results
- Local editing: `C:\Users\aditya\Documents\projects\Closedloop_edit\`
- Sync to Overleaf after editing

---

## Project layout

```
brain_paper/
  CLAUDE.md              ← this file (always loaded)
  TASKS.md               ← prioritized TODO (🔴/🟡/🟢)
  FINDINGS.md            ← question→result→claim bridge (analysis→paper)
  RESEARCH.md            ← append-only change log (grep only, never read full)
  MEETINGS.md            ← parsed meeting entries + open action items
  PAPER.md               ← figure registry + scientific claims
  impulse-analysis/
    CLAUDE.md            ← impulse context (~35 lines, load for impulse sessions)
  controller-analysis/
    CLAUDE.md            ← controller context (~35 lines, load for CL/OL sessions)
  paper-writing/
    CLAUDE.md            ← manuscript context (~35 lines, load for writing sessions)
  utils/                 ← external dependencies — DO NOT MODIFY
  paper/                 ← exported figures
  Closedloop_edit/       ← local LaTeX snapshot (sibling dir, not in repo)
```
