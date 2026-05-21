# CLAUDE.md — Brain Paper

## Mandatory: Log every significant session action

After **any** of the following, append an entry to the `## Change Log` section of `RESEARCH.md`:
- Editing a MATLAB script (even a small fix)
- Discovering a bug, artifact, or unexpected data behaviour
- Running an analysis and observing a result
- Changing a figure, axis, or export parameter
- Deciding *not* to do something for a non-obvious reason

**Format — always use this template:**

```
### YYYY-MM-DD — <one-line title>
**Changed/Found:** `<script.m>` — <what specifically changed or was found>
**Why:** <reason, constraint, or observation that motivated it>
**Next:** <what should be verified or done as a follow-up>
```

If multiple changes were made in one session, write one entry per change (separate `###` blocks, same date).

Do not skip this step. The log is the primary record of what happened between git commits.

---

## Context management — follow these rules every session

**Start focused.** At the top of a session, read only the relevant area CLAUDE.md:
- `impulse-analysis/CLAUDE.md` for impulse work
- `controller-analysis/CLAUDE.md` for controller/plotting work
- `paper-writing/CLAUDE.md` for manuscript work
Do not read `RESEARCH.md` upfront. Pull only the specific change-log entry you need, when you need it.

**Never read a large script in full.** MATLAB scripts here are 200–1400 lines. Always read by line range:
1. Use `Grep` to locate the section first (function name, `%%` header, or keyword).
2. Then `Read` with `offset` + `limit` to pull only that section.
Exception: if the task genuinely requires understanding the whole file, read it once and do not re-read.

**Never re-read a file you already read in the same session** unless the file was edited and you need to verify a specific region.

**Do not load multiple large files at once.** If a task touches both `plottingScript.m` and `Impulse_mouseDataAnalysis_all.m`, read only the relevant section of each, not both files in full.

---

## Project layout
- `utils/` — external dependencies (npy-matlab, Pipelines, Rigbox, widefield). Do not modify.
- `paper/` — exported figures
- `RESEARCH.md` — analysis tasks and change log
- `TASKS.md` — static project context
- `impulse-analysis/` — context for impulse experiment work (see `impulse-analysis/CLAUDE.md`)
- `controller-analysis/` — context for CL vs OL cross-session analysis (see `controller-analysis/CLAUDE.md`)
- `paper-writing/` — context for manuscript editing (see `paper-writing/CLAUDE.md`)

## Two mice
- AL_0033: 8 sessions
- AL_0039: 3 sessions

---

## Three Research Areas

### 1. Impulse Analysis (`impulse-analysis/`)
**Primary script:** `Impulse_mouseDataAnalysis_all.m`  
**Goal:** Characterize the cortical inhibitory response to brief optogenetic pulses across amplitudes. Provides empirical basis for the LTI assumption (linear dose-response) that justifies the PI controller design.  
**Key outputs:** dose-response figures, TF fit (system ID), spatial spread, pre-trial variance analysis.  
**Status:** TF fit working for session 3 (AL_0033); LOAO validation done. Still need: multi-session TF comparison, paper-quality TF figure.

### 2. Controller Analysis (`controller-analysis/`)
**Primary script:** `plottingScript.m` (+ `Analysis_variable.m`, supporting scripts)  
**Goal:** Cross-session CL vs OL comparison. Does closed-loop reduce MSE and variance? Does it decouple pre-stim brain state from trial outcome?  
**Key outputs:** Figures F–H (variance, MSE violin, trial average), motion/freq/widebrain analyses.  
**Status:** Core figures done. Open: widebrain ARX R² verification, Curto & Issa trial-sorting, three-layer prediction model (Nick, 2026-05-11), feedforward/preview section.

### 3. Paper Writing (`paper-writing/`)
**Location:** Overleaf (primary); local snapshot in `Closedloop_edit/`  
**Goal:** Prepare manuscript for submission. Target style: Li, Lu et al. — results-first prose, active voice, quantitative reporting.  
**Status:** Many corrections applied (2026-05-14). Open: Kp/Ki values, author affiliations, broken refs, n+CI on slope, linearity claim strengthening.

---

## How the Areas Relate
```
Impulse_mouseDataAnalysis_all.m
  → TF poles/time constants
     ↓ compare
plottingScript.m %% OL step TF fit
  → same LTI model, step input
     ↓ both feed
Paper: linearity claim (Results §1)
  + controller performance (Results §2-3)
     ↓
Closedloop_edit/ → Overleaf → submission
```

The impulse TF time constants should match the OL step TF time constants. If they agree, it validates the LTI assumption across stimulus types — a key claim in the paper.

---

## Paper workflow
- Paper is edited on **Overleaf** (primary editing environment).
- A local snapshot of the current Overleaf version lives in `C:\Users\aditya\Documents\projects\Closedloop_edit\` (sibling directory, outside this repo).
  - Main file: `Closedloop_edit\main.tex`
  - Section files: `introduction.tex`, `methods.tex` (+ `methods_edit.tex`), `results_edit.tex`, `discussion.tex`
  - Figure images used in the paper: `Closedloop_edit\images\` — copy exported figures here when updating the paper.
- Workflow: edit analysis → export figures to `paper/` → copy relevant figures into `Closedloop_edit\images\` → sync to Overleaf.
