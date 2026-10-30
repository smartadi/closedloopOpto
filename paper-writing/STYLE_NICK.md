# Writing in Nick's voice (both drafts)

Built 2026-10-30 from three papers Aditya chose (PDFs in `brain_paper/nick papers/`, untracked, lab PC
only): Steinmetz et al. 2019 *Nature* (distributed coding), Zatka-Haas, Steinmetz et al. 2021 *eLife*
(sensory coding and causal impact), Steinmetz et al. 2021 *Science* (Neuropixels 2.0). Plus Nick's
JN Overleaf comments N2, N3, N8, N9 (`REVIEW_NICK_2026-10-30.md`). First applied to NC (NC 660d8fd..3da79c0).

## What measured as "Claude voice" (per 1000 words)

| marker | Nick | NC before | NC after |
|---|---|---|---|
| motion verbs: grew / fell / rose / stayed / leaves / needs / enough | 0.1 | 5.9 | 1.6 |
| plain change verbs: increase / decrease / correlate / reduce | 4.9 | 1.5 | 6.7 |
| metaphorical verbs: carry, hold, shape, drive, govern, sit, lie, capture | 1.3 | 5.7 | 1.4 |
| hedges: may, might, could, suggest, likely | 3.2 | 1.4 | 2.9 |
| "we" + past-tense verb | 83% | 59% | 69% |

Sentence length was never the problem (Nick ~28 words mean, ours the same).
Re-measure by grepping the marker words; the table is a target, not a quota.

## Rules

1. **Tense (N9).** Past for anything we did or saw ("Closed loop lowered RMSE"). Present for general
   conclusions, for what a model or controller is by definition, and for "Here we show".
2. **Verbs (N8).** Literal verbs only: increased/decreased, not grew/fell/rose; remained, not stayed;
   contained, not carried; did not use X, not was blind to X. "Steer" is allowed for the controller.
   Nick himself writes "neurons carrying signals"; the rule targets verbs that give agency to
   quantities (the error carries, the state holds, the dip sets).
3. **Cut decorative clauses (N8).** If a clause restates the previous one or only sounds good
   ("the stronger the stimulation, the deeper the suppression"), delete it.
4. **Plain words (N3).** "Target level", never "reference", in prose and captions; Methods defines
   y_ref once as "the reference, in control terms". "Constant offset", not "standing offset". Avoid
   plant, actuator, fed back on, clamp, leak (or gloss them once).
5. **Hedge interpretations, not observations.** Results state what happened; "consistent with",
   "suggest", "may" go on the interpretation ("as expected if feedback corrects each trial's
   deviation"). Associations are called associations.
6. **Paragraph openers.** Either the purpose ("To test whether X, we ...") or the finding with its
   figure panel. Close with "Consistent with ..." or "Thus, ..." only when it adds the inference.
7. **Connectives Nick uses:** However, By contrast, Thus, For example, Consistent with, Finally.
   Avoid colon reveals ("X: Y") for anything but lists.
8. **Numbers in parentheses**, with n and unit: (ratio 0.77, p = 5.8e-8; 15 sessions, four mice).
9. **State claims on the robust test.** If a claim survives Holm or leave-one-mouse-out, word it on
   that test; never lean a headline on a null (p = 0.16 is "not significant", not "did not change").

## Structure (his papers)

- **Abstract:** context → gap → "Here we ..." → method in one sentence → one finding per sentence,
  past tense → one present-tense conclusion.
- **Intro:** problem → gap → open questions → "Here we ..." paragraph of findings in past tense,
  ending on the general conclusion.
- **Discussion:** summary of the claims → one block per claim (interpretation + literature) →
  limitations → use → "In summary".
