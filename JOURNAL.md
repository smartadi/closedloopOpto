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
### 2026-06-20
The entries are not concrete, 


### 2026-06-19 — LDS plan: universal input-driven state-space model for contra→ipsi impulse analysis

Plan for `contra_lds.m` crystallised across two sessions. Key architectural decisions:

**Model:** `x+ = Ax + Bu + w; z_c = C_c x + v_c; y = c_y'x + d·u + v_y`
- u = laser amplitude at stim onset frames (physical units), 0 elsewhere
- z_c = top nSV_lds contra SVD modes (OBSERVED by Kalman)
- y = ipsi primary pixel (HELD OUT — never fed into filter)

**Why driven (not spontaneous) training:** Spontaneous alone has nothing in the mean to learn — E[x]→0 for stable LTI with zero-mean input; only B and D require driven data. (A is constrained by spontaneous fluctuations via fluctuation-dissipation, but B/D need actual stim trials.)

**Universal KF (not per-trial reset):** Single predictor runs over the full session. State at each trial onset reflects the real accumulated brain history from all prior contra observations — no artificial cold-start. This is both more principled and gives a cleaner test: does better contra-estimated brain state predict a better stim response?

**The test that falls out:** Compare eig(A_spont) vs eig(A_evoked). Equality = LTI/relaxation (and GCaMP-is-just-indicator control). Inequality/state-variation = stimulus engages different dynamics = the actual finding.

**Fork A chosen:** contra = observation, ipsi = held-out predicted output. K_c = K[:,1:nSV_lds] (drop ipsi column from Kalman gain so filter never sees ipsi).

**Built up to LDS-KF.** Next sections pending:
- LDS-STATE: same partialcorr(dev_stim, state | dev_pre) test as CP-RES but on the Kalman residual — does SS+KF reduce state-dependence below the static map?
- LDS-EIG: complex z-plane figure comparing A_spont vs A_evoked eigenvalues

**n_states sweep needed:** Try [5, 10, 15, 20]; select by held-out dip R². Default 15.

---
### 2026-06-17 

#### Realization
-Actually we should only care about ipsi-only part of stimulation, when we create the mapping from contra to ipsi(near stim site), we created it on non stim data. but then on stim trials the stim effects infects the contra too with decreasing intensity. Then we tried fancy methods to be able to recreate the proper ipsi activity from ipsi using the model plus some manipulations. Instead why dont we directly report that during stim the contra(infected) predicts ipsi to do y, but in actuality it did y_prime, so the difference is the actual local ipsi activity, and then characterize its behavior on trial avg setup cmparing amp vs residual and their sate dependences(compared to motion and then variance/delta power)
↳ gleaned: TASKS#Residual-as-local-activity reframing — residual = actual_ipsi − contra_pred becomes canonical DV (REPLACES err4). CRITICAL incompleteness flagged: must use BLEED-CORRECTED (not infected) contra, else residual is amplitude-dependently attenuated (raw bleed 97% @0.5V → 76% @4.9V, so naive residual = 3–24% of true local response, distorting the amp-vs-residual dose-response). Decision: bleed removed via SPATIAL-DECAY extrapolation (fit gain(amp)·profile(distance-from-stim), no free α); bleed itself becomes a reported finding (decay λ + spatial map). TF demoted to descriptor of trial-avg residual. See RESEARCH.md 2026-06-17. Decided with user via routing Q.


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
