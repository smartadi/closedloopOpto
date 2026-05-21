# Paper TODO List

---

## Scientific Claims to Fix (require analysis before editing)

These claims have identified problems and must be revisited before submission. Each has a `\todo{}` marker in `results_edit.tex` pointing to the issue.

- [ ] **Linearity claim too broad** (`results_edit.tex`, linearity paragraph): The paper tests linearity using peak ΔF/F vs amplitude only. Either (a) show that full trial-averaged waveforms superimpose after amplitude normalization, or (b) keep the "peak response scales approximately linearly" framing — but verify it is defensible as stated. Critical because the controller design assumes LTI dynamics.

- [ ] **Step-response internal tension** (`results_edit.tex` L49, `discussion.tex` L13): Text says "remained within a bounded set... consistent with marginally stable oscillatory dynamics" but the LTI claim implies convergence to steady state. Either state that the 3 s window is too short to observe steady state, or narrow the claim to what the step response actually shows (bounded, not converging).

- [ ] **Variance-convergence paragraph** (`results_edit.tex` L52): "Batch-mean variance decreasing with trial count" is a CLT consequence for *any* finite-variance process, including drifting ones. What you actually need to show is that the *batch mean itself* converges to a stable value across batch sizes. Verify whether Fig. S1 shows this; rephrase accordingly.

- [ ] **"Stimulation onset did not affect variance" claim** (`results_edit.tex` L50): Must clarify this is open-loop only. Must quantify (pre- vs. post-onset variance ratio or statistical test). The `\todo{}` marker is in place.

- [ ] **"Three independent sessions" for linearity** (`results_edit.tex` L36): n=3 is low given that Fig. 3 uses ~13 sessions. Either add remaining sessions or state the explicit selection criterion. Add n+CI on slope estimates.

---

## CL vs OL analysis
- [ ] add comparision purely focused on disturbance rejection, ie the last two seconds, so that activity settles for that refernce for both OL and CL.
- [ ] freq analysis we added was confusing Nick, and we shold rightfully use the absolute power values instead of using normalizations and ratios.



## Variable refernce plotting and literture
we have added a feedforward and a preview based controller to the experiment pipeline, we need to add the literature, results and discussions
- [ ] add plots for variable sine wave
- [ ] need to classify feedforward vs preview
- [ ] need to add coparision against naive CL.

## Manuscript corrections (Closedloop_edit)

### results_edit.tex
- [x] L16: Resolve `\aditya{}` comment about physiological delay — written out as proper sentence
- [x] L37: "This prompts to the fact" → "This suggests" — already fixed in file
- [x] L37: "a open loop" → "an open loop" — already fixed in file
- [x] L37: "supplimentary" → "supplementary" — already fixed in file
- [x] L37: Resolve `\aditya{add the figure as supplementary}` todo — already fixed in file
- [x] L54–55: Figure references `fig:figure1D` → `fig:figure2` — already fixed in file
- [x] L80–81: Figure 3 caption panel ordering — already correct in file
- [ ] L89: Fill in actual gain values for Kp and Ki (currently [X] placeholders) — defer, need data

### discussion.tex
- [x] L3: Duplicate "to" in steady-state sentence — already fixed in file
- [x] L39: "differes" → "differs" — already fixed in file
- [x] L67: "the=is controller" → "this controller" — already fixed in file
- [x] L87: Incomplete sentence — completed: "...so that the predicted tracking error over a future horizon is minimized."

### main.tex
- [x] L85: Removed `\aditya{separately editing}`, uncommented `\input{introduction}`
- [ ] L63–67: Fill in real author names and department affiliations — waiting on user input

### methods_edit.tex
- [x] L110: `\ref{fig:2}C` label format — already fixed in file
- [x] L447: `\ref{fig:4}A` label format — already fixed in file

# Stuff from CLAUDE

Here's a close read of your section alongside the Li, Lu et al. conventions.
High-level style and organization
Lead with findings, not setup. The single most consistent feature of the Li/Lu paper is that topic sentences state what was found, not what needs to be established. Compare your opener — "Designing a stable feedback controller requires establishing that the trial-averaged input-output relationship…" — with theirs: "A 'peer prediction' of V1 neurons captured a major fraction of the V1 variability via locally shared factors in the neural population." Their Results reads as a sequence of claims backed by evidence; yours reads as a sequence of setups followed by evidence. Your first paragraph in particular is all motivation and no result, and most of its content (definition of "well-defined," reference to the Trial-averaging Assumption) belongs in Methods or can be stated in one clause.
Cut equations and forward-references to Methods out of Results. Li/Lu's Results never cites a numbered equation. You reference Equations 9, 12, 17, and the "Trial-averaging Assumption" repeatedly. In their Results, mathematical detail appears only as brief qualitative description (e.g., "a Poisson reduced-rank regression model"). Readers who want the formalism go to Methods. Strip these — it will tighten the section and make the narrative accessible to a broader audience.
The variance-convergence paragraph is misplaced. As written, it's justifying that trial-averaging is meaningful (that empirical means converge). But the section claim is about linearity of the averaged dynamics, not about whether averaging works. I'd either (a) move the variance-convergence result to a separate paragraph/subsection about the validity of the trial-averaging assumption, possibly even relegating it to a supplementary figure; or (b) cut it down to one sentence pointing to Figure 4. Right now it feels like a detour before getting to the actual linearity evidence.
Restructure toward a cleaner arc. Something like: (1) one-sentence claim that trial-averaged input–output is approximately linear; (2) impulse-response evidence (amplitude sweep → linear peak inhibition); (3) step-response evidence + linearity caveats; (4) variance-convergence as brief support for the trial-averaging assumption. Then end — don't add the "We then designed the closed loop control architecture described as follows" transition. Li/Lu never writes transitional sentences at section boundaries; section headers do that work.
Match their quantitative reporting. Li/Lu never describes a finding without n and a summary statistic: "26.7 ± 1.7% (mean ± SEM)", "n=12 sessions, n=10 mice, n=2722 total neurons." You say "across three independent sessions in different animals" — which is on the low side to begin with, and without uncertainties or a statistical test on the linearity of the peak-vs-amplitude fit. At minimum, report R² and slope ± CI for Fig. 1B, and make n explicit everywhere.
Lower-level specifics
Broken references. "(Section )", "(?)", "predictions of Assumption" (missing number), and "Algorithm ??" in the Fig. 5 caption. Fix these before next pass.
Passive-voice density. Li/Lu is almost entirely active ("We recorded…", "We used…", "The Local model predicted…"). Your section leans hard on passives: "Impulse-based optogenetic inputs were then delivered," "Individual trial responses were quantified," "Step responses were characterized." Convert these to "We delivered…," "We quantified responses as…," "We characterized step responses by…" The passive voice also obscures who did what with which decision (e.g., who defined peak timing from which trace?).
Figure citation style. Li/Lu uses "Fig. 1A" / "Fig. 1H-J"; you use "Figure 1(A)" / "Figure 1B". Pick one and be consistent — matching the advisor's style would be "Fig. 1A."
Grammar and clarity issues in prose:

"The distribution of variance shrunk monotonically…" — "shrunk" should be "shrank"; "decreased" reads cleaner in scientific prose.
"We also note that the variability characteristics like variance per batch size of trials is not consistent across experiments, for the same brain-region, showing the effect of parameters and brain states on characterization of trial-to-trial variability." This sentence has a subject–verb agreement problem ("characteristics… is"), awkward comma placement, and vague referents. Something like: "Convergence rates differed across sessions recorded from the same region, consistent with session-to-session differences in brain state" would be cleaner — but consider whether the point earns a sentence at all.
"reaching a stable minimum beyond approximately 50 trials per session" — quantify with a criterion (e.g., "variance across batch sizes changed by less than X% beyond N=50").

Captions are thin relative to Li/Lu's standard. Their Fig. 1 caption is ~20 dense lines telling you what each subpanel shows, what the error bars are, what the asterisks mean, and what the n is. Your Fig. 1 caption has three one-line descriptions. The reader of Fig. 1B cannot tell from the caption what the points are (individual trials? sessions?), what the error bars represent, or how many trials per amplitude.
Scientific content concerns
The linearity claim is narrower than the prose suggests. You test linearity using peak % ΔF/F suppression vs. input amplitude (Fig. 1B). But a linear system response to impulses of varying amplitude should scale the entire waveform linearly, not just its peak. The impulse responses in Fig. 1A don't obviously look like scaled copies of one another to my eye — they differ in shape, not just amplitude. Either (a) show that the full trial-averaged waveforms superimpose after amplitude normalization, or (b) soften the claim to "the peak response scales approximately linearly with input amplitude," which is a weaker but defensible statement. This matters because your controller design explicitly assumes LTI dynamics in expectation.
Internal tension in the step-response paragraph. You write that the response was "approximated with a linear system response reaching a steady state," then immediately note that "the trial-averaged trajectories do not converge to a fixed equilibrium within the window." These two things are in tension — a stable LTI system driven by a constant input does converge to a steady state. Either the window is too short to observe steady state (fine, say so), or the averaged dynamics aren't well-approximated as a stable LTI system with that input (which would be a real problem for the controller). The "marginally stable oscillatory dynamics" handwave papers over this. It should either be defended or replaced with a narrower claim about what the step response actually shows.
The variance-convergence result doesn't establish what you claim. "This convergence… confirms that disturbances d_t are approximately zero-mean over a session" — variance of batch means shrinking with N is a consequence of the central limit theorem for any finite-variance process. It says nothing specifically about the disturbance being zero-mean (e.g., a process with a persistent nonzero drift would also show shrinking batch-variance). What you actually want to show is that the batch mean itself converges to a stable value across batch sizes — is that what Fig. 4 shows? If so, the claim needs rewording; if not, the evidence doesn't support the conclusion.
"Stimulation onset did not affect trial-to-trial variance" deserves closer scrutiny. Fig. 3E,F show that variance decreases during stimulation in the closed-loop condition. The claim here is presumably about open-loop, but that's not stated, and from the traces in Fig. 1C it's hard to tell whether the shaded regions (variance?) actually stay constant through stimulation onset. Quantify or remove.
The "three independent sessions" framing. This is n=3 across an unknown number of mice for your linearity claim. Given that your later results in Fig. 3 use ~10+ sessions, readers will wonder why the linearity characterization uses so few. Either add more or explain why those three were chosen as representative.