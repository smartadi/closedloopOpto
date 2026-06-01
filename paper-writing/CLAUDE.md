# Paper Writing — Session Context

## Editing environment
- **Local:** `C:\Users\aditya\Documents\projects\Closedloop_edit\`
- **Sync:** copy updated PDFs/PNGs from `paper/` → `Closedloop_edit/images/` → push to Overleaf
- **Shared with Nick** on Overleaf

## File map (Closedloop_edit/)
| File | Role |
|---|---|
| `results_edit.tex` | Primary editing target |
| `discussion.tex` | Discussion |
| `methods_edit.tex` | Methods (edit this, not `methods.tex`) |
| `main.tex` | Top-level; `\input{introduction}` now active |
| `introduction.tex` | Introduction |

## Target style: Li & Lu et al.
- Active voice ("We delivered…", "We quantified…")
- Topic sentences state the finding, not the setup
- No numbered equation references in Results
- Every quantitative claim has n, ± CI or SEM, and a statistical test
- Figure citations: `Fig. 1A` format (not `Figure 1(A)`)

## Locked-in decisions (see root CLAUDE.md for full list)
- Error bars on impulse plots: 95th-percentile bounds (2.5th–97.5th)
- MSE window: **t = 0 to +3 s** (general trial MSE); **t = +1 to +3 s** only for the disturbance-rejection panel — state both windows explicitly in Methods
- Inhibition energy = integral over 0–200 ms post-onset (define exact bounds in Methods)
- Absolute power spectra only — no relative normalization

## Start a paper session by reading
1. This file (done)
2. `FINDINGS.md` — grep for the finding/claim you are writing about
3. `TASKS.md` 🔴 section — check what is blocking submission
4. Grep `MEETINGS.md` for the most recent entry if context on Nick's decisions is needed

## Open questions (see TASKS.md for full list)
1. What are actual Kp and Ki values? (needed for `results_edit.tex` L89)
2. Is n=3 sessions for linearity defensible, or add more?
3. Does Fig 3H show MSE or MAE? Affects caption.
4. Should feedforward/preview be a full section or supplementary?
