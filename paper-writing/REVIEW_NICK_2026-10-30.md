# Nick's review, 2026-10-30 (JN draft: abstract, significance, intro P1)

Source: Overleaf project **Closedloop_edit** (the JN draft, shared with Nick). His comment threads and
tracked changes were read on 2026-10-30 with `paper-writing/overleaf_comments_export.js` (see "How to
re-export" at the end). He worked from 17:15 to 17:59 UTC on 2026-10-30, before the 12:00 PDT meeting:
- **10 comment threads**, none resolved, no replies yet: 9 in `main.tex` (abstract and significance),
  1 in `introduction.tex`;
- **106 tracked changes**: 77 in `main.tex`, 29 in `introduction.tex` L3–8.

Every comment below is quoted verbatim, with where it lands, a diagnosis, a proposed fix and a status.

Status: `OPEN` (not started) · `DRAFT` (a draft was given in chat, waiting on Aditya) ·
`DECIDE` (needs Aditya's call, maybe with Nick) · `DONE` (cite the commit).

---

## For the agent picking this up

- **Process:** same as Anna's review: ONE item at a time, show the proposal, wait for Aditya, then
  update the status here. His overlapping notes are in `REVIEW_ANNA_2026-10-29.md`: G1 (abstract
  order), G2 (significance "what is this for"), G4 (the "slop" patterns) and T3/T5 (intro P1–P2).
- **Overleaf is ahead of GitHub and Aditya is editing there.** On 2026-10-30, Overleaf's
  `main.tex`, `introduction.tex` and `results.tex` all differ from `origin/main`:
  - Nick's tracked changes;
  - untracked edits: title, Nick's author line, the abstract "steered the" and "despite the activity
    being less predictable", and `results.tex` L12–14 and L202.

  Overleaf history shows Aditya editing `main.tex`, `results.tex` and `introduction.tex` at
  18:07–18:27 UTC.
  - Never edit the JN files locally until Aditya pushes Overleaf to GitHub and the local repo has pulled.
  - Default: LaTeX snippets in chat; Aditya applies them on Overleaf.
  - Local JN `main` has one unpushed commit (98aebf1, `results.tex` L251–277). It touches no line
    Overleaf changed.
- **Tracked changes are Aditya's to accept or reject in Overleaf.** Problems found in them are listed
  under "Problems in the tracked edits" below, so he can fix them as he accepts.
- **Both drafts.** Nick commented on JN. His style rules (N2, N8, N9) and the wording decision
  (N3) apply to NC too. Abstract and significance items are JN only: NC has its own abstract and no
  significance statement.
  - Conflict: Nick's edits to JN intro L3–8 and the NC rewrite of the same sentences for Anna's T3
    (NC, 2026-10-30) differ. Reconcile them when porting.
- **Numbers used in the drafts below:** from FINDINGS.md:
  - Fig 4, session rule (2026-10-27):
    - motion: OL slope +0.24, CL slope n.s., attenuation −13 %/SD, 11/11 sessions;
    - abs 1–4 Hz: OL +0.28, CL +0.32, 15/15 sessions.
  - Fig 4G: rejection ratio 0.58, 11 of 13 sessions with a predictor, 3 mice.
  - Fig 5: lag 71° → 16° OL and 46° → 2° CL with preview; variance 11.8 → 5.8; one mouse, 3 sessions,
    descriptive only.

---

## Comments

| ID | Nick (verbatim) | Where (Overleaf line, anchor) | Diagnosis / proposed fix | Status |
|---|---|---|---|---|
| N1 | "I don't understand what is the point of this whole section on modeling. we're trying to do control: the question is what happens to behavior when you achieve a pattern of activity that's unachievable without control - any modeling of the variability is irrelevant because the question fundamentally can't be asked without doing the control experiment..." | `introduction.tex` L10 ("One way"), i.e. paragraph 2, L10–17 | The paragraph argues "why not model the variability and plan the input in advance". Nick's frame is different: control is needed because it produces activity patterns that fixed stimulation cannot, and that is what a causal test needs. Options: **(a)** cut L10–15 and rebuild P2 on his frame; L16–17 (feedback corrects each trial without a model of the cause) survive as the bridge. **(b)** As (a), but move the model-limits content (rSLDS, ML models, the 1.5 s forecast limit) to the Discussion, where it answers the referee question "why not a model-based open-loop input?". `discussion.tex` L29 already makes the 1.5 s point. Recommend (b). It reopens the intro structure locked 2026-10-20 (memory `project_intro_rewrite`) and Anna's T5 fix in NC. | DECIDE |
| N2 | "this "it controls" is very claude to me. I don't know exactly how to get rid of claude-voice, maybe give it some older papers of mine and ask it to rewrite in that style/voice? But one way or another we have to get rid of claude-voice stuff. it'll be a long slow process of me re-writing everything if we don't have any other strategy. did you make this with opus 5 or 5.5?" | `main.tex` L91 ("ongoing dynamics.") | Nick already cut "it controls". **Strategy:** (1) Aditya picks 2–3 of Nick's papers whose writing he likes (PDFs). (2) From them, build a short, concrete style sheet: sentence length, how Results paragraphs open, verb choice, tense, hedging. (3) Sweep JN section by section against that sheet plus N8/N9, one section per sitting, so Nick reviews diffs instead of rewriting. The model question is Aditya's to answer. | DECIDE (which papers) |
| N3 | "to me "target level" is much more interpretable when read as plain english, "reference" seems like jargon.... we can discuss" | `main.tex` L91 ("target level") | Nick already swapped it in the abstract and significance. Mixing the two terms across sections would confuse readers, so pick one rule. **(a)** "target level" in all prose (abstract, intro, Results, captions), and "reference r(t)" only in Methods equations, defined once as the target level. **(b)** "target level" in the abstract and significance only. Recommend (a). Check figure labels ("ref") at the same time. Applies to NC too. | DECIDE |
| N4 | "maybe we can discuss what this sentence is doing, what claim it is making, and where it goes. (maybe before the previous sentence?)" | `main.tex` L97 ("Predicting the disturbance on each trial from the opposite hemisphere, we show that feedback partially rejects it.") | The claim (Fig 4E–G): a linear model of the opposite hemisphere predicts each trial's spontaneous fluctuation at the controlled site. Under feedback, the error kept only about 60% of that fluctuation's energy (rejection ratio 0.58, 11 sessions). That is the direct test of disturbance rejection, so it belongs right after the "reduced trial-to-trial variability" sentence, before the state sentence, as Nick suggests. See the abstract draft below. | DRAFT (below) |
| N5 | "I don't understand this "whereas feedback reduces error and variability" so I removed it, maybe you need to explain it to me" | `main.tex` L98 ("delays") | Explanation for Nick: in sine tracking, preview and feedback fix different failures. Preview removes the timing error, the lag of the cortical response (71° → 16° OL, 46° → 2° CL). Feedback removes the trial-to-trial scatter (variance 11.8 → 5.8). Since L94 already claims the variability reduction, dropping the clause is fine. Two fixes to his version: (1) "system delays" is wrong. At 1 Hz, the open-loop lag of 71° is about 200 ms, while the 24 ms loop latency accounts for only about 9°. The rest comes from the slow response of cortex and indicator to light, so say "the lag of the cortical response". (2) Keep "in one mouse" (n = 1 mouse, descriptive). | DRAFT (below) |
| N6 | "not sure whether this is an abstract-level claim if it's just a simulation?" | `main.tex` L99 (MPC sentence) | Agree: cut it from the abstract and keep Fig 6 in Results and the Discussion. The freed words go to the state claim (N7). | DRAFT (below) |
| N7 | "we need to have here a clearer statement about what exactly we learned from the brain state observations. Something like "spontaneous fluctuations from different sources are differently controllable by cortical inputs"? not sure" | `main.tex` L100 ("is informative about brain state") | The data support his wording: (1) open-loop error grew with movement and with 1–4 Hz power; (2) under feedback, error no longer grew with movement but still grew with 1–4 Hz power; (3) fluctuations shared with the other hemisphere were partly rejected. Conclusion: fluctuations from different sources differ in how well cortical input can correct them. | DRAFT (below) |
| N8 | "two of the things to look for as "claude speak" are clauses that sound nice but don't add anything - cut them - and using metaphorical verbs like something "carries" or "holds" or similar. In general verbs in science writing should be non-metaphorical, except in context-specific exceptions like how we can use "steer" to specifically describe the effect of our controller here" | `main.tex` L106 ("o it."; Nick cut ", which can only lower that activity") | A style rule for the whole paper, both drafts. Sweep for decorative clauses and metaphorical verbs (carries, holds, leaves, lets, owns, marks, reveals, drives), keeping "steer". The JN abstract, intro, Results and Discussion have roughly 80 candidate lines (some, like "held-out", are fine). Do it together with N2 and N9, one section at a time. | OPEN |
| N9 | "when it is a statement about something specific we did or observed it needs to be past tense. when it's a general conclusion about the brain it can be present. it's a little tricky to decide in some cases. but please switch to past tense where appropriate (looks like at least some of the results already is)" | `main.tex` L107 ("tracked") | Tense rule: past for what we did and observed, present for general conclusions. The abstract, significance and intro currently use present for our results. Sweep with N8. | OPEN |
| N10 | "what is the claim about this though? keep in mind we're in "significance statement" here" | `main.tex` L109 ("allowing us estimate the disturbance the controller rejects on each trial") | The sentence describes a method, not a finding. Either state the finding (feedback partly rejected fluctuations predicted from the other hemisphere) or drop it. In a significance statement, drop it; Anna's G2 asks for the same rewrite. See the significance draft below. | DRAFT (below) |

---

## Problems in the tracked edits (fix while accepting in Overleaf)

| ID | Where (Overleaf line) | Problem | Fix |
|---|---|---|---|
| E1 | `main.tex` L96 | Run-on: "…movements of the mouse, despite the activity being less predictable whereas its error grew with…". The "despite" clause is an untracked edit. | Replaced by the abstract draft below. |
| E2 | `main.tex` L98 | "compensated for system delays": the lag is mostly the slow cortical response, not loop delay. "successfully" adds nothing. "In one mouse" was dropped. | See N5. |
| E3 | `main.tex` L108 | "cortical state during the stimulation": the Fig 4 state window is −2 to +3 s (locked), so it covers before and during. | "around stimulation", or "before and during stimulation". |
| E4 | `main.tex` L109 | "allowing us estimate": "to" is missing. | Moot if N10 drops the sentence. |
| E5 | `main.tex` L92 | Present tense for our observation ("is approximately linear"); "in open-loop" is used as an adverb. | "…when stimulated open loop, was approximately linear…" (N9). |
| E6 | `main.tex` L94 | "in all 15 sessions from 4 mice" was dropped. | Optional: restore it. The n is the abstract's strongest number. |
| E7 | `main.tex` L91 | Two sentences on one line. | Split them (one-sentence-per-line rule). |
| E8 | `introduction.tex` L6, L7 | L6 has a stray space before `~\citep` ("engaged states ~\citep"). L7 has a double space ("states,  unmeasurable"). | Remove both. |

---

## Draft abstract (N4–N7, built on Nick's tracked version)

The opening lines are Nick's text, with the tense fix (E5) and the line split (E7):

```latex
Mesoscale brain dynamics have been linked to a wide range of perceptual, cognitive and motor functions.
However, establishing causal links between mesoscale dynamics and behavior remains challenging, because it requires not only perturbing these dynamics but also precisely shaping them.
Here we show that closed-loop optogenetic inhibition can steer cortical activity in real time toward a target level, using feedback from the ongoing dynamics.
We employed a system with simultaneous wide-field calcium imaging and laser-driven optogenetic stimulation at the cortical surface in mice.
The trial-averaged response of a cortical site to open-loop stimulation was approximately linear and, within a session, time-invariant.
On this basis, we designed a linear feedback controller with measured fluorescence as the input and laser intensity as the output.
The controller steered activity to the target level more accurately than open-loop stimulation in all 15 sessions from 4 mice, and reduced trial-to-trial variability.
Feedback partly rejected spontaneous fluctuations that we predicted on each trial from activity in the opposite hemisphere.
Open-loop error grew with the mouse's movements and with slow, synchronized (1--4\,Hz) cortical activity.
Under feedback, error no longer grew with movement but still grew with 1--4\,Hz activity.
In one mouse tracking a time-varying target level, a preview of the upcoming target compensated for the lag of the cortical response.
Together, these results show that approximately linear, time-invariant trial-averaged dynamics can be used to control regional cortical activity, and that spontaneous fluctuations from different sources differ in how well cortical input can correct them.
```

The MPC sentence is cut (N6). The draft is 249 words, against a JNeurosci limit of 250 that is recalled, not verified. Lines 89–93 now differ from Nick's text only by E5 ("In this preparation," cut, past tense) and by dropping the redundant "closed-loop" before "linear feedback".

## Draft significance statement (N8–N10 + Anna G2)

```latex
Testing how a pattern of cortical activity affects behavior requires producing that pattern reliably, but the same stimulus has different effects from trial to trial because ongoing activity varies.
We read out activity at one cortical site in real time with wide-field calcium imaging and used it to set optogenetic inhibition delivered next to it.
This closed-loop stimulation tracked a target level more accurately than fixed, open-loop stimulation and reduced trial-to-trial variability across sessions and animals.
Under feedback, error no longer grew with the mouse's movements but still grew with slow, synchronized cortical activity.
Closed-loop control can therefore produce cortical activity patterns that fixed stimulation cannot, and it shows which spontaneous fluctuations cortical input can correct.
```

116 words (the JNeurosci limit of 120 is recalled, not verified). It opens on the problem (Anna G2). It drops the R² and the disturbance-estimation method (N10) and the preview clause.

---

## Untracked Overleaf edits found while exporting (not Nick's comments; for the record)

- `main.tex` L71, title: "Feedback Control Analysis for Cortical Dynamics in Mice" → "Real-time Feedback Control of Mesoscopic Cortical Dynamics in Mice".
- `main.tex` L78: "Nick Steinmetz" → "Nicholas A. Steinmetz".
- `results.tex` L12–14 (opening paragraph) and L202 (attenuation sentence): Aditya's edits, 2026-10-30 18:21–18:27 UTC.

## Older threads

The original Overleaf project **Closedloop** holds 49 earlier comments from Nick (2025-11-25 to
2026-04-22, one resolved), all on the pre-restructure draft. They have not been exported. To export
them, open that project and run the script.

## How to re-export

1. Open the project in Overleaf (signed in) and press F12 → Console.
2. Paste `paper-writing/overleaf_comments_export.js` and press Enter. The last line,
   `olExport('steinme')`, keeps Nick's threads. Use `olExport('')` for everyone.

A Markdown file downloads with every thread (file:line, anchored text, all replies, resolved flag)
and every tracked change, grouped by line. `olExport('steinme', {dry: true})` returns the text
without downloading. Overleaf's Git/GitHub sync never carries comments, so this is the only route.
