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

### Airtight logging rules (non-negotiable)

1. **Log immediately** after the triggering action — before starting the next task and before ending the turn. Never defer "until later".
2. **One entry per logical change.** Never batch unrelated edits into one entry; never collapse a multi-script change into a single line.
3. **All four fields required.** No blank `Why:` or `Next:`. If a follow-up is truly none, write `Next: none`.
4. **Use today's real date** (`currentDate` in context), `YYYY-MM-DD`. Never guess or reuse a prior date.
5. **Newest entry on top** of the `## Change Log` section, directly under the `## Change Log` header.
6. **End-of-turn self-audit:** before finishing any turn that edited a script, ran an analysis, changed a figure, or found a bug — confirm a matching Change Log entry exists. If not, add it before replying.
7. **Failures and dead-ends get logged too** (rejected approaches, bugs, "decided not to" — these are the most valuable entries to future-you).

One entry per change. Do not skip — the log is the primary record between git commits.

---

## Vault worklog (cross-project hub)

Separate from `RESEARCH.md`. The **Research Hub** is a single Obsidian file spanning all of Aditya's projects (both postdoc labs, the sleep-mask startup, personal):

**Path:** `C:\Users\aditya\OneDrive\Notes\Research Hub.md`

**At the END of any session that did real work** (edited a script, ran an analysis, produced a figure, or found something), append **one** distilled entry to the `## 📓 Worklog` section:

```
### YYYY-MM-DD · Brain Paper — <one-line title>
**Done:** <what got done this session, plain language>
**Found:** <key result / bug / decision, or "—">
**Next:** <what's next, or "—">
```

Rules:
1. **Newest on top**, directly under the `## 📓 Worklog` header (below its format comment).
2. **One entry per session, not per change.** This is the human daily distillation — `RESEARCH.md` remains the granular per-change machine log. Don't paste RESEARCH entries here; summarize the session.
3. **Human, low-jargon.** Write it so a non-specialist collaborator (or future-you skimming a week later) gets it. Spell out what mattered, skip the script internals.
4. **Prefix the title with `Brain Paper`** so the hub stays sortable by project.
5. **Append only to `## 📓 Worklog`.** Never edit the `## 🎯 Command board` (that's the user's brief to you) — but *do* read the `### Brain Paper` command section at session start for pending asks. You may update the project's row in `## 📊 Dashboard` (Current focus / Next action / Updated date) when it has clearly changed.
6. Use today's real date (`currentDate`). Never guess or reuse a prior date.

---

## Git commit & push discipline

The Change Log is the record *between* commits; commits + push are the durable record. Keep them tight.

1. **Branch:** work on `alpha` (current). **Never commit directly to `main`.** If on `main`, create/switch to a feature branch first.
2. **Commit at every logical unit** — a finished analysis, a working figure, a bug fix. Don't let the working tree accumulate a day's worth of unrelated changes in one commit.
3. **Push after every commit** (or at minimum at the end of every working session). Unpushed work is unbacked-up work — this is a single-machine research repo, so push is the only backup.
4. **Before committing:** stage intentionally (`git add` specific files, not blind `git add -A`); confirm the corresponding `RESEARCH.md` Change Log entry is included in the same commit so log and code move together.
5. **Commit message:** imperative one-line summary (≤72 chars), matching the style of recent commits (e.g. `Add cl_mse_factors.m: CL MSE variance decomposition`). Body only if the why isn't obvious.
6. **Never** `--force`, `--no-verify`, or rewrite pushed history unless the user explicitly asks.
7. **End-of-session checklist:** (a) Change Log up to date → (b) commit staged work → (c) `git push`. State to the user whether the push succeeded.

---

## File size & rotation limits

Keep the coordination files scannable. Check these at the **end of each session**; if a cap is exceeded, rotate before finishing.

**RESEARCH.md — soft cap 1000 lines.**
- When exceeded, move the **oldest** entries (keep the most recent ~50 entries / ~3 months in place) into `RESEARCH_archive_YYYYHn.md` (e.g. `RESEARCH_archive_2026H1.md`).
- Leave a one-line pointer at the bottom of the live `## Change Log`: `<!-- older entries → RESEARCH_archive_2026H1.md -->`.
- Never delete entries — archive only. Grep both live + archive when searching history.

**TASKS.md — keep the whole file ≤ ~120 lines.**
- `## ✅ Recently done`: **hard cap 10 items.** When adding an 11th, delete the oldest (it already lives in RESEARCH.md / FINDINGS.md, so nothing is lost).
- `🟢 Deferred`: prune items that have gone stale or been superseded; don't let it grow unbounded.
- Completed 🔴/🟡 items move to `✅ Recently done` (with date), they are not left checked in place.

**FINDINGS.md — no line cap**, but a finding that is fully written into the manuscript and needs no further analysis may be marked `Status: CLOSED (in paper §X)` and is eligible to move to a `FINDINGS_archive.md` if the file gets unwieldy.

---

## Journal glean loop

`JOURNAL.md` is the freeform diary (no template, newest on top). At session start,
**read new JOURNAL.md entries** and glean from them:
- action items → `TASKS.md` (assign 🔴/🟡/🟢 tier)
- answered questions / results → `FINDINGS.md`
- concrete script/figure changes → `RESEARCH.md` change log

Never delete or rewrite the user's journal prose. After gleaning an entry, append a
`↳ gleaned: TASKS#… / FINDINGS#…` line under it. When a TASKS item is completed, move
it to the `## ✅ Recently done` section (with date) before pruning.

---

## Area detection and context loading

**Infer the area from the first message** (impulse / controller / paper-writing).
Then read the matching sub-area CLAUDE.md before starting work. Do not read more than one.

| Trigger words | Sub-area file to read |
|---|---|
| impulse, TF fit, dose-response, AL_0041 | `impulse-analysis/CLAUDE.md` |
| controller, plottingScript, CL vs OL, MSE, sessions | `controller-analysis/CLAUDE.md` |
| manuscript, LaTeX, results_edit, paper, Overleaf | `paper-writing/CLAUDE.md` |
| bilateral, AL_0048, dual opsin, excitatory, inhibitory, galvo, variable ref, tuning, grid sweep, gradient descent, photostim site-grid, opto_brainGrid | `bilateral/CLAUDE.md` |
| controller grid, gain grid, gain sweep, Kp Ki sweep, cost surface, J(Kp,Ki), auto-tune, auto-tuning, tuning methodology | `controller-tuning/CLAUDE.md` |
| explore, staging, inspect, vibe, server root, list files | `explore/CLAUDE.md` |

> Disambiguation: AL_0034 / AL_0033 controller-gain grids + auto-tuning → `controller-tuning`.
> AL_0048 dual-opsin Kp/Ki sweep + gradient descent → `bilateral`.
> AL_0048/AL_0046 galvo photostim *site* grid (spatial mapping) → `bilateral/grid/` (Python).

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
- **AL_0048** — dual-opsin bilateral mouse; excitatory left, inhibitory right; sessions tracked in `bilateral/load_bilateral.m`; reference polarity switchable (`REF_L`, `REF_R`)

### Impulse analysis
- Inhibition energy = mean ΔF/F over **0–200 ms** post-onset (`peak_mode = 3`), not peak trough
- Error bars: **95th-percentile bounds** (2.5th–97.5th percentile) on median plot; SEM on mean plot
- Stim detection: **mode 1** for AL_0033/AL_0039; **mode 2** (absolute index) for AL_0041
- TF fit currently on `selExp = 3` (AL_0033, 2025-01-29); sweep 1–3 poles, 0–2 zeros, 0–5 sample delay; AIC selection

### Controller / CL vs OL
- Error metric = **RMSE** (root-mean-squared error, sample-normalised, in %ΔF/F) — decided 2026-07-15, supersedes the old "MSE" naming. `controllerData.m` now stores `er_ncDfk`/`er_wcDfk` as `norm(seg-ref)/sqrt(numel(seg))` (was un-normalised `norm()` = ‖e‖₂ = RMSE·√N). Label every axis/caption "RMSE"; the theory cost in Methods stays a squared cost (√ is monotone → same minimiser). Fig 3H is the one exception: it is genuinely **MAE** (`abs(mean error)`) and is labelled MAE.
- RMSE window: **t = 0 s to +3 s** for trial RMSE analysis, **t = +1 s to +3 s** only for disturbance rejection in one panel, post-laser onset (skips inhibitory transient)
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
  utils/                 ← project helpers + vendored deps
    npy-matlab/ Rigbox/ widefield/ Pipelines/  ← external deps — DO NOT MODIFY
    (everything else, e.g. cp_*.m, paperFig.m — project-owned, editable)
  paper/                 ← exported figures
  Closedloop_edit/       ← local LaTeX snapshot (sibling dir, not in repo)
```
