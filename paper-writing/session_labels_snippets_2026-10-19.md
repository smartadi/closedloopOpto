# Session labels — manuscript snippets (2026-10-19)

**Rule (Aditya, 2026-10-19):** a session is named by its mouse number. If a mouse has more than one
session anywhere in the paper, a letter follows, assigned in date order (then experiment number)
across all of that mouse's sessions. One label per session, the same in every figure, table and
sentence. Registry: `brain_paper/utils/paper_session_label.m`.

## Mapping

| Label | Mouse | Date | Exp | Old ID | Used in |
|---|---|---|---|---|---|
| 1a | AL_0033 | 2025-01-20 | 3 | m1 | CL vs OL |
| 1b | AL_0033 | 2025-01-29 | 1 | "Mouse 1" (impulse) | Fig 2, Fig S1A |
| 1c | AL_0033 | 2025-02-12 | 2 | m2 | CL vs OL (excluded from Fig 4G) |
| 1d | AL_0033 | 2025-02-24 | 2 | m3 | CL vs OL |
| 1e | AL_0033 | 2025-02-26 | 2 | m4 | CL vs OL, Fig 6 A–H MPC replay, supp. figure at L190 |
| 1f | AL_0033 | 2025-03-04 | 1 | m5 | CL vs OL |
| 1g | AL_0033 | 2025-03-05 | 1 | — | Gain grid (Fig S2 A, D) |
| 1h | AL_0033 | 2025-03-05 | 2 | m6 | CL vs OL |
| 1i | AL_0033 | 2025-03-17 | 3 | — | Auto-tune (Fig S2 B, C) |
| 1j | AL_0033 | 2025-03-20 | 4 | m7 | CL vs OL |
| 1k | AL_0033 | 2025-04-15 | 2 | m8 | CL vs OL, Fig 4E example |
| 1l | AL_0033 | 2025-04-19 | 1 | m12 | CL vs OL |
| 2a | AL_0039 | 2025-04-19 | 1 | m10 | CL vs OL, Fig 3 example, Fig 1 SVD frame |
| 2b | AL_0039 | 2025-04-20 | 1 | m9 | CL vs OL |
| 2c | AL_0039 | 2025-04-20 | 2 | m13 | CL vs OL |
| 2d | AL_0039 | 2025-04-30 | 3 | m11 | CL vs OL |
| 3a | AL_0048 | 2026-07-01 | 6 | sine s1 | Fig 5 I–K |
| 3b | AL_0048 | 2026-07-14 | 1 | sine s2 | Fig 5 B–H example, Fig 6 I–M |
| 3c | AL_0048 | 2026-07-15 | 1 | "Mouse 3" (impulse) | Fig 2 |
| 3d | AL_0048 | 2026-07-21 | 1 | sine s3 | Fig 5 I–K |
| 3e | AL_0048 | 2026-07-29 | 2 | m14 | CL vs OL |
| 4 | AL_0051 | 2026-07-29 | 2 | m15 | CL vs OL (excluded from Fig 4G) |
| 5a | AL_0041 | 2025-12-02 | 1 | 5a | Fig 2 |
| 5b | AL_0041 | 2025-12-02 | 2 | 5b | Fig 2 |

Mouse 5 is unchanged. In the text, use "Mouse 1b" for one session and "Mice 5a, 5b and 1b" for a
list. Bare "Mouse 1" now means the animal only.

---

## results.tex

**L57 (Fig 2A)**: no change (Mouse 5b).

**L58 (Fig 2B)**: this also fixes the trial counts.
```latex
    \textbf{B:} Evoked suppression (mean $\Delta F/F$ over the 200\,ms after onset) versus stimulation amplitude for four sessions from three mice (Mice 5a and 5b are two sessions of one animal). Points, mean $\pm$ SEM across trials ($n = 44$--$59$, $81$--$85$ and $100$ trials per amplitude for Mice 5a--5b, 1b and 3c; Table~\ref{tab:stat_counts}); lines, linear fits.\\
```

**L59 (Fig 2C)**: `at three amplitudes (Mouse 1)` → `at three amplitudes (Mouse 1b)`

**L71**: `to $0.95$ in Mouse 1 (Figure` → `to $0.95$ in Mouse 1b (Figure`

**L73**: `Mice 5b and 1, four poles and three zeros; Mouse 3, five poles` → `Mice 5b and 1b, four poles and three zeros; Mouse 3c, five poles`

**L74**: `$0.87$ against $0.85$ in Mouse 3)` → `$0.87$ against $0.85$ in Mouse 3c)`

**L80**: `(in Mice 5b and 1 the slower mode` → `(in Mice 5b and 1b the slower mode`

**L81**: `in Mice 5a, 5b and 1, and $0.14$\,s in Mouse 3;` → `in Mice 5a, 5b and 1b, and $0.14$\,s in Mouse 3c;`
and `$0.154$ instead of $0.114$\,s in Mouse 1.` → `... in Mouse 1b.`

**L82**: `($0.27$\,s in Mouse 1, $0.50$\,s in Mouse 3 at` → `($0.27$\,s in Mouse 1b, $0.50$\,s in Mouse 3c at`
and `in all refits in Mouse 3, against $3\%$ in Mouse 1 (Materials` → `in all refits in Mouse 3c, against $3\%$ in Mouse 1b (Materials`

**L127**: this also fixes the "Mouse10" typo.
```latex
Figure~\ref{fig:figure3}A--D and F show one representative session (Mouse~2a; $K_r = 0.1$, $K_p = 0.07$, $K_i = 0.1$), and Figure~\ref{fig:figure3}E and G--I pool all 15 sessions.
```

**L169 (Fig 4E)**: `(representative session, Mouse~1)` → `(representative session, Mouse~1k)`

**L238**:
```latex
We describe one session of Mouse~3 (Mouse~3b, 200 trials) in detail and then all three of its sinusoidal sessions (3a, 3b and 3d).
```

**L244 (Fig 5 caption)**: `B--H show one session; I--K show all three.` → `B--H show Mouse~3b; I--K show Mice 3a, 3b and 3d.`

**L286**: `of one session (Mouse~1, 108 trials)` → `of one session (Mouse~1e, 108 trials)`

**L303**: `of Figure~\ref{fig:figure5} (Mouse~3) that ran` → `of Figure~\ref{fig:figure5} (Mouse~3b) that ran`

**L324**: `one session of Mouse~1 (108 closed-loop trials).` → `Mouse~1e (108 closed-loop trials).`

**L340**: `the Mouse~3 session of Fig.~\ref{fig:figure5};` → `Mouse~3b, the session of Fig.~\ref{fig:figure5}B--H;`

## methods_rewrite.tex

**Cohort table (L44–68)**: replace the whole table.
```latex
\begin{table}[h]
    \centering
    \small
    \begin{tabular}{lllllll}
        \hline
        Mouse & Sex & Indicator & Sessions & Dates & Trials/session & Contributes to \\
        \hline
        1 & M & GCaMP8s & 12 (1a--1l) & 2025-01-20 to 2025-04-19 & 30--200 & Closed- vs open-loop (1a, 1c--1f, 1h, 1j--1l); impulse (1b); gain grid (1g); auto-tuning (1i) \\
        2 & F & GCaMP8s & 4 (2a--2d) & 2025-04-19 to 2025-04-30 & 100 & Closed- vs open-loop \\
        3 & M & GCaMP8s & 5 (3a--3e) & 2026-07-01 to 2026-07-29 & 100 & Sinusoidal reference (3a, 3b, 3d); impulse (3c); closed- vs open-loop (3e) \\
        4 & F & GCaMP8s & 1 & 2026-07-29 & 100 & Closed- vs open-loop \\
        5 & F & GCaMP8s & 2 (5a, 5b) & 2025-12-02 & 208--260 & Impulse only \\
        \hline
    \end{tabular}
    \caption{Animals and sessions. A session is one experiment; two can share a recording day
        (1g and 1h; 2b and 2c). A session is named by its mouse number, followed by a letter
        when that mouse contributed more than one session to the paper; letters run in date
        order over all of a mouse's sessions, so each session keeps one label in every figure
        and table. The closed- versus open-loop comparison rests on 15 sessions from 4 mice
        (Table~\ref{tab:gains}). Trials per session count the validation block of the closed-
        versus open-loop sessions (for Mouse 5, impulse trials at nonzero amplitudes).}
    \label{tab:cohort}
\end{table}
```
(The column spec changed from `llllcll` to `lllllll`. If "Contributes to" overflows, use `p{4cm}`.)

**L175**: `In Mice 3\nand 4 the tuning phase` → `In Mice 3e\nand 4 the tuning phase`

**L385**: `(Mouse~1, session m4; 108 closed-loop trials)` → `(Mouse~1e; 108 closed-loop trials)`

**L409**: `of Fig.~\ref{fig:figure5} (Mouse~3), with` → `of Fig.~\ref{fig:figure5} (Mouse~3b), with`

**L466 / L470 / L481**: `Mouse 3` → `Mouse 3c` (three times; these are the impulse TF fits).

**L529**: `In one session of Mouse~1 the controller cycled` → `In one session (Mouse~1g) the controller cycled`

**L599–600**:
```latex
          more than one third of the total. This removed sessions 1c and 4
          (Table~\ref{tab:gains}). In these two sessions the closed-loop
```

## supplementary.tex

**L38 (Fig S1A)**: `(Mouse~1).` → `(Mouse~1b).`

**L84–85**: `Mouse 1, 1.43\,mW, 82; Mouse 3, 0.33\,mW, 100)` → `Mouse 1b, 1.43\,mW, 82; Mouse 3c, 0.33\,mW, 100)`

**L99 (Fig S2)**:
```latex
    \caption{\textbf{Controller gain tuning.} All panels are from Mouse~1: the grid sweep (Mouse~1g) and the online gain search (Mouse~1i).
```

**Table S1 (L128–144)**: the Mouse column is folded into Session, and rows are in label order.
```latex
        Session & Exp. & Date & $K_{r}$ & $K_{p}$ & $K_{i}$ & OL & CL \\
        \hline
        1a & 3 & 2025-01-20 & 0.175 & 0.1 & 0.1 & 56 & 64 \\
        1c & 2 & 2025-02-12 & 0.25 & 0.1 & 0.25 & 97 & 103 \\
        1d & 2 & 2025-02-24 & 0.22 & 0.075 & 0.01 & 101 & 99 \\
        1e & 2 & 2025-02-26 & 0.16--0.17 & 0.1--0.2 & 0.002--0.005 & 92 & 108 \\
        1f & 1 & 2025-03-04 & 0.18 & 0.125 & 0.075 & 36 & 24 \\
        1h & 2 & 2025-03-05 & 0.15 & 0.15 & 0.1 & 14 & 16 \\
        1j & 4 & 2025-03-20 & 0.15 & 0.06 & 0.01 & 46 & 54 \\
        1k & 2 & 2025-04-15 & 0.15 & 0.05 & 0.1 & 38 & 22 \\
        1l & 1 & 2025-04-19 & 0.1 & 0.05 & 0.1 & 35 & 65 \\
        2a & 1 & 2025-04-19 & 0.1 & 0.07 & 0.1 & 48 & 52 \\
        2b & 1 & 2025-04-20 & 0.07 & 0.05 & 0.1 & 50 & 50 \\
        2c & 2 & 2025-04-20 & 0.07 & 0.07 & 0.1 & 55 & 45 \\
        2d & 3 & 2025-04-30 & 0.05 & 0.05 & 0.2 & 50 & 50 \\
        3e & 2 & 2026-07-29 & 0.05 & 0.075 & 0.01 & 45 & 55 \\
        4 & 2 & 2026-07-29 & 0.075 & 0.1 & 0.05 & 55 & 45 \\
```
Drop one `l` from the tabular column spec, since there is one column fewer.

**L151**: `m4 interleaved three` → `session 1e interleaved three`

**L190**: `(Mouse~1, session m4)` → `(Mouse~1e)`

## stat_tables.tex (generated: do not hand-edit)

`data/fig2b_trial_counts.csv` is already relabelled (Mouse 1 → 1b, Mouse 3 → 3c). Re-run
`paper-writing/paper_stats_tex.m` to regenerate `tab:stat_counts`.

## Figures (code updated, panels NOT yet regenerated)

Label code now reads the registry: `imp_mouse_label.m`, which wraps `paper_session_label.m`,
plus `f4_cl_reject_panel.m`. Panels whose printed labels change:
- Fig 2: `imp_response.pdf` (2B direct labels), `tf_cv_2D_sidebar.pdf`, `tf_model_swap.pdf`,
  `tf_tau_forest.pdf` and the 2C legend: "1" → "1b", "3" → "3c".
- Fig 4G `f4_cl_reject_RR.pdf`: ticks were relettered within the panel; they now follow the global
  letters (1a, 1d, ... 3e).
- Fig 2 supplementary state/raster panels.
Re-run with `PAPER_FINAL` on (`run_fig2.m` for Fig 2, needs the server SVD load; `f4_cl_reject_panel`
for 4G), then update the links in Illustrator. Check the `.ai` files for any session labels typed
by hand.
