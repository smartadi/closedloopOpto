# Paper Writing — Session Context

## Editing environment — local-first, Overleaf is downstream
- **Repo:** `C:\Users\aditya\Documents\projects\Closedloop_edit\` (own git repo, NOT part of `brain_paper`)
- **Chain:** local repo → GitHub `smartadi/Closedloop` → Overleaf pulls via GitHub sync
- **Editor:** VS Code + LaTeX Workshop. `.vscode/settings.json` is committed-ignored, so it is local only.
- **Build locally:** MiKTeX is installed; `latexmk -pdf main.tex` compiles (31 pp). Never edit on Overleaf while a draft is open locally — it forces a merge.
- **Shared with Nick** on Overleaf

### Branch protocol (the review gate)
| Branch | Meaning |
|---|---|
| `main` | Mirrors what is on Overleaf. Only fast-forward merges from `draft`. |
| `draft` | Where Claude (and in-progress user edits) commit. Never pushed. |

Claude commits prose changes to `draft` only. Aditya reviews `git diff main..draft`
in VS Code, then merges to `main` and pushes; Overleaf pull is the last step.
**Never push `draft`, and never commit to `main` directly.**

### What must NOT reach Overleaf
- Build artifacts → already handled by `.gitignore` (note: `.gitignore` itself IS pushed).
- Local-only helper files (`sync_figs.ps1`, `notes/`, local PDFs) → listed in
  `.git/info/exclude`, which is machine-local and never travels. Put new local
  helpers there, not in `.gitignore`.
- Uncited figures → `.\sync_figs.ps1` reports them; only cited figures belong in `images/`.

### Figures
`.\sync_figs.ps1` (dry run) / `-Apply` copies **only figures cited by `\includegraphics`**
from `brain_paper/paper/` into `images/`, and flags cited-but-missing + tracked-but-uncited.

## File map (Closedloop_edit/)
| File | Role |
|---|---|
| `results.tex` | Primary editing target (there is no `results_edit.tex` — renamed) |
| `discussion.tex` | Discussion |
| `methods_edit.tex` | Methods — the live one; `main.tex` inputs this |
| `methods.tex` | **DEAD** — not inputted. Two `\todo` refs in `results.tex` point at labels that live only here (`fig:lowfreq_examples`, `sec:disturbance`), hence 2 undefined refs at build. Harmless until those sections are written. |
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
- Error metric = **RMSE** everywhere (2026-07-16 decision, supersedes "MSE"); Fig 3H is the exception — genuinely MAE, labelled MAE
- RMSE window: **t = 0 to +3 s** (general trial RMSE); **t = +1 to +3 s** only for the disturbance-rejection panel — state both windows explicitly in Methods
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
3. ~~Does Fig 3H show MSE or MAE?~~ RESOLVED 2026-07-16: **MAE** (`step_response.m` plots `abs(mean error)`); caption already correct, axis label fixed MSE→MAE.
4. Should feedforward/preview be a full section or supplementary?
