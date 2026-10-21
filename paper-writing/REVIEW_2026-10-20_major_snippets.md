# Major review points: analyses and Overleaf snippets (2026-10-20)

Against Closedloop `main` 43fabaf, plus the minor snippets. Review IDs refer to `REVIEW_2026-10-20.md`.

---

## M1: closed loop vs the best fixed open-loop input

**Analysis:** `controller-analysis/ctrl_best_fixed_ol.m` (brain_paper 43d751b, 7d784ed).

Each session's open-loop response is rescaled by the gain c* that would have brought it closest to
the reference. This uses the linear, additive-disturbance model and the same trials (in-sample),
which favours open loop.

| 1–3 s unless noted | value |
|---|---|
| CL / OL as run (Table 4 check) | 0.68 [0.62, 0.76], 15/15 |
| Best fixed / OL as run | 0.85 [0.76, 0.94] (0–1 s: 0.92) |
| **CL / best fixed** | **0.80 [0.73, 0.89], 13/15**; LMM t(2.6) = −1.62, p = 0.22 (0–1 s: 0.92 [0.85, 0.99], 13/15, p = 0.036) |
| Median stim-window offset | OL 1.47 → best fixed 0.29 %ΔF/F |
| Mean CL command / OL command | median 1.16 vs c* 1.29; Spearman ρ = 0.66, p = 0.009 |

About half of the closed-loop advantage is calibration, and half is feedback beyond the best fixed
input. Under the model, recalibration leaves across-trial variance unchanged.

### M1-1: Methods, K_r paragraph (methods_rewrite.tex)
Find:
```latex
at the start of each session (\nameref{sec:gain_opt}). Open- and closed-loop
trials within a session share the same $K_r$, so the comparison between them
does not depend on its value.
```
Replace:
```latex
at the start of each session (\nameref{sec:gain_opt}). Open- and closed-loop
trials within a session share the same $K_r$, so open-loop error includes any
error in this rough calibration, which feedback can correct. To separate the
two, we also compared closed loop with the best fixed input (\nameref{sec:stats}).
```

### M1-2: Methods, statistics (methods_rewrite.tex, after the Fig 3 paragraph)
Find:
```latex
it. The comparisons are pre-specified, one per metric and window, and are
not corrected for multiple comparisons.
```
Replace:
```latex
it. The comparisons are pre-specified, one per metric and window, and are
not corrected for multiple comparisons.

\emph{Best fixed input.} To separate the error that feedback removes from the
error of the rough feedforward calibration, we compared closed loop with the best
fixed input that each session's open-loop trials allow. Under the trial-averaged
model with an additive disturbance, an open-loop trial is
$y_i(t) = b + h(t) + n_i(t)$, where $b$ is the trial-averaged level over the
1\,s before onset, $h$ the trial-averaged effect of the open-loop command and
$n_i$ the trial's deviation from the trial average. A command scaled by $c$
would give $b + c\,h(t) + n_i(t)$. We chose $c$ to minimize the squared error to
the reference over the 0--3\,s stimulation window on the same open-loop trials,
which favors open loop, and capped it at the command limit. We then compared
closed-loop RMSE with the RMSE of these rescaled trials, as above. Under this
model the across-trial variance does not depend on $c$.
```

### M1-3: Results, after the Fig 3H windows paragraph (results.tex)
Find:
```latex
Before and after stimulation the ratio stayed at one (geometric mean $1.01$ and $1.00$; $p = 0.84$ and $1.0$).
```
Replace:
```latex
Before and after stimulation the ratio stayed at one (geometric mean $1.01$ and $1.00$; $p = 0.84$ and $1.0$).

Part of this advantage reflects the rough feedforward calibration, which left open-loop activity a median of $1.5\%\,\Delta F/F$ short of the reference during stimulation (Figure~\ref{fig:figure3}B).
To separate calibration from feedback, we rescaled each session's open-loop response to the best fixed input, the constant command that would have minimized its error under the linear model, computed on the same trials, which favors open loop (Materials and Methods).
This brought open-loop activity to within $0.3\%\,\Delta F/F$ of the reference and lowered its steady-state RMSE by 15\%.
Closed loop still tracked better than the best fixed input, by 8\% in the transient (ratio $0.92$, $p = 0.036$) and by 20\% in the steady state ($0.80$), with the ratio below one in 13 of 15 sessions in both windows (Table~\ref{tab:stat_fig3}).
In the steady state the mixed model assigned part of the variation to mice, which left 2.6 degrees of freedom ($p = 0.22$).
Feedback also moved the average command toward this input on its own, as the mean closed-loop command was 1.16 times the open-loop command (median over sessions), against 1.29 times for the best fixed input, and the two were correlated across sessions (Spearman $\rho = 0.66$, $p = 0.009$).
Under the same model, recalibration leaves across-trial variance unchanged, so the variance reduction below is not a calibration effect.
```

### M1-4: Discussion, PI paragraph (discussion.tex)
Find:
```latex
With this minimal model, feedback lowered error in every session and, on average, trial-to-trial variability (Figure~\ref{fig:figure3}H,I).
```
Replace:
```latex
With this minimal model, feedback lowered error in every session and, on average, trial-to-trial variability (Figure~\ref{fig:figure3}H,I), and about half of the error reduction remained against the best fixed input.
```

### M1-5: Table 4 (stat_tables.tex)
Replace the whole Table 4 `\begin{table} ... \end{table}` block (the one with
`\label{tab:stat_fig3}`) with the regenerated block. It is in the chat message, and it is produced
by `paper_stats_tex.m`. It includes the earlier caption fixes plus a new "closed loop / best fixed
input" block and footnote b.
