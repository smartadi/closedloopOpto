# Manuscript edits queued 2026-10-10 (apply after Aditya's Overleaf push is merged)

Held because Aditya has unpushed language edits on Overleaf. Apply on `draft`, build, fast-forward `main`.

## 1. Fig 2F: dip and rebound timescales (user 2026-10-10: keep the free-order fits, name modes by what they do)

### results.tex, Fig 2 paragraph, replace from "Each response was summarized by two time constants" to the end of that paragraph

> The fitted models separated each response into two components (Fig.~\ref{fig:figure2}F). A
> \emph{dip} timescale, the decay of a damped 3--4\,Hz oscillation that shapes the initial
> suppression, was reproducible across sessions ($0.14$--$0.15$\,s in three of four sessions;
> median $0.145$\,s). A \emph{rebound} timescale, the slowest fitted mode, which governs how
> activity returns after the dip, varied several-fold between sessions ($0.18$--$0.54$\,s) and
> lies near or beyond the $0.5$\,s fit window, so it is less well constrained. The
> amplitude-normalized responses accordingly overlap through the dip and diverge during the
> rebound (Fig.~\ref{fig:figure2}D).

Also: drop "settling time of ~200 ms" earlier in the paragraph (use "peak suppression at ~110 ms"),
and replace "dominant timescale" with "dip timescale" if the common-amplitude-range sentence is kept.

### Fig 2 caption, panel F

> \textbf{F:} Response timescales from the fitted poles: dip (open square) and rebound (filled
> circle) time constant per session; dotted line, median dip timescale ($0.145$\,s). Rebound
> timescales lie near or beyond the $0.5$\,s fit window and are weakly constrained (42--50\% of
> bootstrap refits exceeded it in three of four sessions), so intervals are not shown.

### discussion.tex, "Linear approximation ..." subsection, new sentences after the first paragraph

> The fitted models needed more than one pole pair, not to predict held-out trials---a single
> damped oscillation predicted them nearly as well (pooled held-out $R^2 = 0.84$ against
> $0.86$)---but to separate two components of the response: a dip whose timescale is conserved
> across sessions (${\approx}0.145$\,s) and a rebound whose timescale varies several-fold. The
> conserved dip is the component a controller acting within a trial has to anticipate, whereas
> the session-specific rebound is consistent with the per-session differences in fitted dynamics
> (Fig.~\ref{fig:figure2}E) and with tuning gains per session.

Basis: RESEARCH 2026-10-10 "Tested capping the impulse TF at 2 poles" and "Fig 2C/D/F layout + what
the TF fits actually learned".

## 2. Other held caption/Results edits (see TASKS.md)
- Fig 2G: session-level panel (thin grey = sessions, black = mean of sessions, no band).
- Fig 3: E<->F letters swapped, G wording + line-weight key, H/I titles + no Mean legend,
  RMSE annotations in A (per trial) and B (of the trial-averaged trace).
