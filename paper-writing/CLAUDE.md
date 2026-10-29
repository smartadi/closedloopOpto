# Paper Writing — Session Context

## Editing environment — local-first, Overleaf is downstream

### Two independent drafts (since 2026-10-29)
| Draft | Local repo | GitHub | Overleaf | Target |
|---|---|---|---|---|
| **JN** | `projects\Closedloop_edit\` | `smartadi/Closedloop` | original project (shared with Nick) | arXiv, then JNeurosci |
| **NC** | `projects\Closedloop_nc\` | `smartadi/Closedloop-NC` (private) | imported from GitHub 2026-10-29 | Nature Communications |

- NC was cloned from JN main 98aebf1 (tag `fork-nc-2026-10-29` in the NC repo). From then on the two
  drafts are independent: prose, captions, figure assemblies, `main.tex` and `refs.bib` belong to each draft.
- Shared, single-sourced in `brain_paper`: analysis code, panels (`paper/figures_final/panels/`),
  `STATS_TABLE.csv`, FINDINGS. A science change must land in both drafts by hand.
- The NC repo has a fetch-only `jn` remote (push URL disabled, main only). A shared fix may be
  cherry-picked from `jn/main` while the file still matches; after the NC restructure, port by hand.
  Nothing in the JN repo knows the NC repo exists.
- **Every manuscript request names a draft. If it is unclear which, ask.**
- Both are their own git repos, NOT part of `brain_paper`. Chain for each: local repo → its GitHub
  repo → its Overleaf project pulls via GitHub sync. Both are `auto` in the hub's `REPOS.md`, so
  `sync.py` never pushes their `main`.
- **Editor:** VS Code + LaTeX Workshop. `.vscode/settings.json` is committed-ignored, so it is local only.
- **Build locally:** MiKTeX is installed; `latexmk -pdf main.tex` compiles (31 pp). Never edit on Overleaf while a draft is open locally — it forces a merge.

### Branch protocol (the review gate)
Since 2026-10-27 each draft repo has ONLY `main` (the `draft` branch was deleted locally and on
GitHub). Commit straight on `main`, one commit per logical change, check with `latexmk`, and ask
before pushing `main`, because a push reaches Overleaf. `origin/overleaf-*` branches are Overleaf's
conflict branches, not ours. Default is still Overleaf-first: give snippets in chat and edit the
repo only when Aditya asks.

### What must NOT reach Overleaf
- Build artifacts → already handled by `.gitignore` (note: `.gitignore` itself IS pushed).
- Local-only helper files (`sync_figs.ps1`, `notes/`, local PDFs) → listed in
  `.git/info/exclude`, which is machine-local and never travels. Put new local
  helpers there, not in `.gitignore`.
- Uncited figures → `.\sync_figs.ps1` reports them; only cited figures belong in `images/`.

### Figures
`.\sync_figs.ps1` (dry run) / `-Apply` copies **only figures cited by `\includegraphics`**
into `images/`, and flags cited-but-missing + tracked-but-uncited. Each draft has its own local copy:
JN pulls from `brain_paper/paper/`, NC from `brain_paper/paper/figures_final/nc/` (the NC Illustrator
assemblies: lowercase panel letters, 88/180 mm widths). Both assemblies link the same panels.

## File map (Closedloop_edit/)
| File | Role |
|---|---|
| `results.tex` | Primary editing target (there is no `results_edit.tex` — renamed) |
| `discussion.tex` | Discussion |
| `methods.tex` | Methods — the ONLY Methods file (2026-10-20: `methods_rewrite.tex` renamed to it; the dead `methods.tex`/`methods_edit.tex` deleted, they live in git history). One sentence per line. Older audit docs (NUMBERS.md, PROVENANCE.md) cite `methods_rewrite.tex` line numbers from before the rename. |
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
