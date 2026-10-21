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

---

## Supplementary figure: closed loop vs best fixed input (M1)

Panels: `paper/figures_final/panels/supp_best_fixed/` (A commands in 1d, B/C per-session RMSE 0–1 / 1–3 s,
D CL command vs c*). Assemble at 17.6 cm as `S_best_fixed.pdf` and upload to `images/supplementary/`.

### SF-1: supplementary.tex, insert right after the Table S1 block (`\label{tab:gains}` ... `\end{table}`)
```latex
\begin{figure}
    \centering
    \includegraphics[width=\linewidth]{images/supplementary/S_best_fixed.pdf}
    \caption{\textbf{Closed loop against the best fixed open-loop input.}
    \textbf{A:} Laser command in Mouse 1d, the session with the median rescaling,
    for open loop as run (red), the best fixed input (gray) and closed loop (blue,
    mean $\pm$ SD over trials). The best fixed input is the open-loop command scaled
    by the constant that minimizes the squared error to the reference over the
    0--3\,s stimulation window under the linear model. It is computed on the same
    open-loop trials and capped at the command limit (Materials and Methods). The
    command is shown as its peak over 40\,ms, which gives the drive level in
    sessions with 40\,Hz modulation.
    \textbf{B, C:} Mean trial RMSE in each session for the three inputs, in the
    transient (0--1\,s, \textbf{B}) and the steady state (1--3\,s, \textbf{C}).
    Lines join one session (15 sessions, 4 mice). Above each panel, the
    closed-loop/best-fixed ratio (geometric mean with its $t$-based 95\% CI,
    Table~\ref{tab:stat_fig3}).
    \textbf{D:} Mean closed-loop command over 1--3\,s against the best fixed input,
    both relative to the open-loop command, one point per session. Open circles,
    sessions where the best fixed input was capped at the command limit. Dotted
    line, identity. Spearman $\rho = 0.66$, $p = 0.009$.}
    \label{fig:best_fixed}
\end{figure}
```

### M1-3 (updated, supersedes M1-3 above): Results paragraph after "Before and after stimulation the ratio stayed at one ..."
```latex
Part of this advantage reflects the rough feedforward calibration, which left open-loop activity a median of $1.5\%\,\Delta F/F$ short of the reference during stimulation (Figure~\ref{fig:figure3}B).
To separate calibration from feedback, we compared closed loop with the best fixed input, the constant command that would have minimized each session's open-loop error under the linear model, computed on the same trials, which favors open loop (Figure~\ref{fig:best_fixed}A; Materials and Methods).
This brought open-loop activity to within $0.3\%\,\Delta F/F$ of the reference and lowered its steady-state RMSE by 15\%.
Closed loop still tracked better than the best fixed input, by 8\% in the transient (ratio $0.92$, $p = 0.036$) and by 20\% in the steady state ($0.80$), with the ratio below one in 13 of 15 sessions in both windows (Figure~\ref{fig:best_fixed}B,C; Table~\ref{tab:stat_fig3}).
In the steady state the mixed model assigned part of the variation to mice, which left 2.6 degrees of freedom ($p = 0.22$).
Feedback also moved the average command toward this input on its own. The mean closed-loop command was 1.16 times the open-loop command (median over sessions), against 1.29 times for the best fixed input, and the two were correlated across sessions (Spearman $\rho = 0.66$, $p = 0.009$, Figure~\ref{fig:best_fixed}D).
Under the same model, recalibration leaves across-trial variance unchanged, so the variance reduction below is not a calibration effect.
```

---

## M2 + M11: the feedforward gain is rough by design and carries over between sessions

**Analysis** (RESEARCH 2026-10-20):
- c* (best fixed / used input): median 1.29, IQR 1.06–1.40, range 0.78–1.67.
- Gain that would have been best, K_r·c*: Mouse 2 0.077–0.105 (CV 0.14, 11 days); Mouse 1 0.10–0.28 (CV 0.29, 3 months).
- Dropping 1e (three Kp values) leaves Fig 3H/3I unchanged: RMSE 0.84 / 0.68, variance 0.64 / 0.53, n = 14, all p ≤ 0.003.

### M2-1: Methods, K_r paragraph (methods_rewrite.tex), supersedes M1-1
Replace everything from `where $Y^{\dagger}$ is the Moore--Penrose pseudoinverse.` to the end of that
paragraph (just before `\subsubsection*{Proportional--integral feedback}`) with:
```latex
where $Y^{\dagger}$ is the Moore--Penrose pseudoinverse. This regresses amplitude
on measured output, the direction an actuator command needs, and so is not the
reciprocal of the forward dose--response slope. $K_r$ is a rough calibration by
design. It was fit on the impulse-response signal, whose $\Delta F/F$ uses a
constant baseline, rather than on the trailing-baseline signal the controller
fed back on. Learning it precisely would have needed open-loop trials at several
powers in every session, which the session time did not allow next to the
controller experiments. $K_r$ was instead carried over between sessions and
adjusted by hand at the start of each session (\nameref{sec:gain_opt}), and
feedback corrected the remaining error. Open- and closed-loop trials within a
session share the same $K_r$, so open-loop error includes the error of this
calibration. To separate the two, we compared closed loop with the best fixed
input (\nameref{sec:stats}), which was a median of 1.29 times the feedforward
input we used (interquartile range 1.06--1.40, Figure~\ref{fig:best_fixed}).
```

### M2-2: Results, Fig 2 section (results.tex)
Find:
```latex
We therefore recalibrated the feedforward gain in every session rather than reusing a fitted model.
The partial similarity of the dynamics across sessions nonetheless made this calibration simple in practice: gains from earlier sessions served as a starting point and needed minor adjustments (Materials and Methods).
```
Replace:
```latex
We therefore used the fitted models only to set a rough feedforward gain and relied on feedback to correct its error.
The partial similarity of the dynamics across sessions made this rough gain easy to maintain: gains carried over from earlier sessions with small adjustments (Table~\ref{tab:gains}, Materials and Methods).
```

### M2-3: Discussion (discussion.tex)
Find:
```latex
The fitted models transferred only inconsistently between sessions (Figure~\ref{fig:figure2}E), so we recalibrated the feedforward gain in every session.
```
Replace:
```latex
The fitted models transferred only inconsistently between sessions (Figure~\ref{fig:figure2}E), so we used them only for a rough feedforward gain, carried it over between sessions with small adjustments, and let feedback correct the rest.
Against the best fixed input this gain was a median of 29\% too low, and the closed-loop command moved toward that input on its own (Figure~\ref{fig:best_fixed}D).
```

### M11-1: Table S1 caption (supplementary.tex)
Find:
```latex
$K_p$ values and is given as a range.
```
Replace:
```latex
$K_p$ values and is given as a range. Excluding 1e left the closed-loop/open-loop
        ratios of Fig.~\ref{fig:figure3}H,I essentially unchanged (RMSE $0.84$ and $0.68$,
        variance $0.64$ and $0.53$ at 0--1 and 1--3\,s, 14 sessions, all $p \le 0.003$).
```

### M11-2: Methods, "Gains used for validation" (methods_rewrite.tex). CONFIRM BEFORE PASTING
Mice 2 and 4 had no impulse session. The replacement assumes their first gains came from earlier sessions.
Table S1 is consistent with that (2a used 0.1, the same as 1l on the same day), but it is not confirmed.
Find:
```latex
Later sessions started from the gains of earlier sessions,
with small adjustments at the start of each session.
```
Replace:
```latex
Later sessions, including the first sessions of Mice 2 and 4, which had no
impulse session, started from the gains of earlier sessions, with small
adjustments at the start of each session.
```
