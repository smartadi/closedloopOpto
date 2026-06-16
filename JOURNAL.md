# JOURNAL.md — Working Diary

Freeform, dated, conversational. This is the one file with **no template** — dump
ideas, frustrations, half-decisions, "today I noticed…", questions for Nick, etc.

**How the glean loop works:**
- *You* write entries here (or dictate to me and I write them).
- *I* read this at session start. From each new entry I extract:
  - action items → append to `TASKS.md` (correct 🔴/🟡/🟢 tier)
  - answered questions / results → append to `FINDINGS.md`
  - concrete changes → `RESEARCH.md` change log
- The prose stays here as the human narrative. I never delete your entries; I mark
  what I've gleaned with `↳ gleaned: TASKS#… / FINDINGS#…`.
- Agents may **read** this for context but should not rewrite your words.

Newest entry on top.

---
### 2026-06-16 

#### Regarging prediction vs brain states,
- Earlier we had an analysis where we did prediction error per trial on impulse responses as deviation of trial response from trial averaged response on that amp.
- with this new decontaminated version, should we instead add a TF based impulse reponse(learned on trail averaged for that amp, so same for that amp) and the contra pred + tf amp as prediction vs what happended on trial as actual. the deviation on the stim to stim + 200ms as the pred error and we map that to the states(motion and motion excluded prestim var/ delta power)  
↳ gleaned: TASKS#Contra→ipsi framework — refined per-trial-error definition (red=contra+TF vs actual, 0-200ms) mapped to brain states; CP-4 already computes red4/err4/covariates (needs 0-200ms window + α=1 baseline). Answer = YES, do it this way.

#### Focus on contra to ipsi prediction model.
- The goal is to be able to use contra activity to predict the ipsi 21 by 21 kernel. This has been shown to work really well by just using instantaneous activity by Zhiwen ye(folder:: C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals\2023.12.07.570517v3.full.pdf, code exists alongside).
- We are currently using a OLS type regressor, I want to solidify one single approach either OLS, one used by Zhiwen or PCA based, which ever wins best on non stim data.
- Then we want to be able to make prediction of ipsi activity using this model during stim. The hypothesis is that contra activity remains unaffeected by stim so the model would predict the activity of theipsi as if no stim was applied. But in real world the stim does affect regions radially outward and contra regions get afffected, with decresing intensity, farther they are from ipsi kernel.
- We want to be able to make a model that accounts for the bleep over effect of stim creeping into contra and remove it, then be able to predict what impulse response would have been on top of the contra to ipsi prediction using a tf trained on ipsi stim effects. I want the prediction to work on trail level activity.
- In some trials the prediction would be good some it would be bad, this would ostly depend on motion and pretrial variance(or delta power during stim).
- I want to be able to use this as a analysis framework where this setup can also be used in controller level contra to ipsi prediction analysis.
- So to summarize the goal is to be albe to isolated activity that is purely. 
↳ gleaned: TASKS#Contra→ipsi prediction framework (impulse) — 5 items (benchmark OLS/Ye/PCA, compare Ye 2023 code, per-trial quality vs motion+variance, generalize framework, TF-on-residual decision); reference [[reference-ye-2023-spirals]]



### 2026-06-15 — (example — replace me)
Set up JOURNAL.md as the diary layer. Want a place to think out loud and have
Claude turn it into tasks/findings automatically. Next: try writing a real entry
and ask Claude to "glean the journal".
↳ gleaned: nothing yet
