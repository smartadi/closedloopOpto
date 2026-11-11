# Overleaf review export: Closedloop_edit

Exported 2026-11-02, reviewer filter "steinme". 14 comment threads, 132 tracked changes.

## Comments

### C1 · introduction.tex:10

> One way

- **nsteinme** (2026-10-30 17:59 UTC): I don't understand what is the point of this whole section on modeling. we're trying to do control: the question is what happens to behavior when you achieve a pattern of activity that's unachievable without control - any modeling of the variability is irrelevant because the question fundamentally can't be asked without doing the control experiment...

### C2 · main.tex:91

> ongoing dynamics.

- **nsteinme** (2026-10-30 17:15 UTC): this "it controls" is very claude to me. I don't know exactly how to get rid of claude-voice, maybe give it some older papers of mine and ask it to rewrite in that style/voice? But one way or another we have to get rid of claude-voice stuff. it'll be a long slow process of me re-writing everything if we don't have any other strategy. did you make this with opus 5 or 5.5? 

### C3 · main.tex:91

> target level

- **nsteinme** (2026-10-30 17:19 UTC): to me "target level" is much more interpretable when read as plain english, "reference" seems like jargon.... we can discuss

### C4 · main.tex:97

> Predicting the disturbance on each trial from the opposite hemisphere, we show that feedback partially rejects it.

- **nsteinme** (2026-10-30 17:26 UTC): maybe we can discuss what this sentence is doing, what claim it is making, and where it goes. (maybe before the previous sentence?)

### C5 · main.tex:98

> delays

- **nsteinme** (2026-10-30 17:28 UTC): I don't understand this "whereas feedback reduces error and variability" so I removed it, maybe you need to explain it to me

### C6 · main.tex:99

> Finally, in a simulated replay of recorded trials with a constant reference, a model-predictive controller using a linear model of cortex and the laser lowers the error left by feedback by about 40\%.

- **nsteinme** (2026-10-30 17:28 UTC): not sure whether this is an abstract-level claim if it's just a simulation? 

### C7 · main.tex:100

> is informative about brain state

- **nsteinme** (2026-10-30 17:30 UTC): we need to have here a clearer statement about what exactly we learned from the brain state observations. Something like "spontaneous fluctuations from different sources are differently controllable by cortical inputs"? not sure

### C8 · main.tex:106

> o it. 

- **nsteinme** (2026-10-30 17:35 UTC): two of the things to look for as "claude speak" are clauses that sound nice but don't add anything - cut them - and using metaphorical verbs like something "carries" or "holds" or similar. In general verbs in science writing should be non-metaphorical, except in context-specific exceptions like how we can use "steer" to specifically describe the effect of our controller here

### C9 · main.tex:107

> tracked

- **nsteinme** (2026-10-30 17:37 UTC): when it is a statement about something specific we did or observed it needs to be past tense. when it's a general conclusion about the brain it can be present. it's a little tricky to decide in some cases. but please switch to past tense where appropriate (looks like at least some of the results already is)

### C10 · main.tex:109

> allowing us estimate the disturbance the controller rejects on each trial

- **nsteinme** (2026-10-30 17:39 UTC): what is the claim about this though? keep in mind we're in "significance statement" here

### C11 · results.tex:12

> We built a closed-loop optogenetic system that precisely regulates (i.e., steers) the activity of a cortical region, monitored with wide-field calcium imaging in mice.
> The evoked responses to stimulation scaled monotonically with stimulus amplitude, and a linear time-invariant model captured their dynamics, which gave us an empirical basis for designing a controller.
> We then show that this controller holds cortical activity at a target level and its regulation performance is informative about brain states.

- **nsteinme** (2026-11-02 19:31 UTC): I think these sentences can go - the last paragraph of intro is doing all the 'setting of the stage' that we need. delete unless you have a reason to keep them

### C12 · results.tex:19

> spontaneous activity

- **nsteinme** (2026-11-02 19:37 UTC): here cite https://www.cell.com/neuron/fulltext/S0896-6273(22)00588-8 and https://www.cell.com/neuron/fulltext/S0896-6273(25)00127-8

### C13 · results.tex:20

> Figure

- **nsteinme** (2026-11-02 19:50 UTC): I've been finding that Opus 5.5 is quite good and cleaning up figures (not perfect, but gets a lot of the way there). ask it to harmonize font sizes, panel sizes and positioning, re-draw panels D and E for clarity? 

### C14 · results.tex:41

> limits the bandwidth over which feedback can act (see Discussion

- **nsteinme** (2026-11-02 20:09 UTC): can we say something like "to a theoretical maximum of XX Hz"? like 1/50 ms = 20Hz? or is there some kind of control theory math about how you can determine and quantify the speed of control as a function of system lag?

## Tracked changes, grouped by line


### introduction.tex:3

Line now (insertions applied, deletions removed):

> Precisely modulating the activity of a neuronal population can establish how it contributes to or affects behavior, which pathways mediate its influence, and how its effect depends on brain state.

- inserted by nsteinme: `mediate`
- deleted by nsteinme: `carry`

### introduction.tex:4

Line now (insertions applied, deletions removed):

> Yet modulation, whether optical, electrical, or magnetic, is often delivered open loop, with an input pattern chosen in advance.

- inserted by nsteinme: `,`
- inserted by nsteinme: `n`
- deleted by nsteinme: ` model-dependent`
- inserted by nsteinme: `pattern `
- deleted by nsteinme: ` without feedback from ongoing neuronal activity`

### introduction.tex:5

Line now (insertions applied, deletions removed):

> The response to any input depends on the circuit's current state, that is, its ongoing pattern of activity, as has been shown for sensory, optogenetic, and magnetic stimulation~\citep{Arieli1996, Petersen2003, Goris2014, Mateo2011, Massimini2005}.

- inserted by nsteinme: `,`

### introduction.tex:6

Line now (insertions applied, deletions removed):

> In the cortex of awake mice, brain state is influenced by movements such as whisking or fidgeting and by arousal~\citep{Niell2010, McGinley2015, Vinck2015, musall2019single, stringer2019spontaneous, Salkoff2020}. State fluctuates between slow, synchronized rhythms during quiet wakefulness and desynchronized activity during engaged states ~\citep{Crochet2006, Poulet2008, Reimer2014}, and is shared across the two hemispheres~\citep{Mohajerani2010, Shimaoka2019, Ye2026}.

- inserted by nsteinme: ` is influenced by`
- deleted by nsteinme: `, measured from single neurons to the mesoscale, follows`
- inserted by nsteinme: `s such as whisking or fidgeting`
- inserted by nsteinme: ` by`
- inserted by nsteinme: `.`
- deleted by nsteinme: `,`
- inserted by nsteinme: `State fluctuates betwee`
- deleted by nsteinme: `alternates with`
- inserted by nsteinme: ` and desynchronized activity during engaged states `

### introduction.tex:7

Line now (insertions applied, deletions removed):

> Momentary cortical activity is presumably driven by these well-characterized states along with unobservable states,  unmeasurable stimuli, and interactions from other brain regions.

- inserted by nsteinme: `Momentary cortical activity is presumably driven by these well-characterized states along with`
- deleted by nsteinme: `Not only the known states but also`
- deleted by nsteinme: ` drive the activity`

### introduction.tex:8

Line now (insertions applied, deletions removed):

> Therefore, activity appears highly variable across trials of responses to a fixed stimulus.

- deleted by nsteinme: `at the trial-to-trial scale, `
- inserted by nsteinme: ` appears`
- deleted by nsteinme: ` seems`
- inserted by nsteinme: ` across trials of`
- deleted by nsteinme: `; especially, the measured`
- inserted by nsteinme: `s`
- inserted by nsteinme: `fixed`
- deleted by nsteinme: `known`
- deleted by nsteinme: ` also becomes variable`

### main.tex:71

Line now (insertions applied, deletions removed):

> \title{\textbf{Real-time Feedback Control of Mesoscopic Cortical Dynamics in Mice }}

- inserted by nsteinme: `Real-time F`
- deleted by nsteinme: `F`
- deleted by nsteinme: ` Analysis`
- inserted by nsteinme: `of`
- deleted by nsteinme: `for`
- inserted by nsteinme: `Mesoscopic `

### main.tex:91

Line now (insertions applied, deletions removed):

> Here we show that closed-loop optogenetic inhibition can steer cortical activity in real time toward a target level, using feedback from the ongoing dynamics. We employed a system with simultaneous wide-field calcium imaging and laser-driven optogenetic stimulation at the cortical surface in mice.

- inserted by nsteinme: `target level`
- deleted by nsteinme: `reference below baseline`
- deleted by nsteinme: ` it controls`
- inserted by nsteinme: ` We employed a system with simultaneous wide-field calcium imaging and laser-driven optogenetic stimulation at the cortical surface in mice.`

### main.tex:92

Line now (insertions applied, deletions removed):

> In this preparation, the trial-averaged response of a cortical site when stimulated in open-loop is approximately linear and, within a session, time-invariant.

- inserted by nsteinme: `In this preparation, the`
- deleted by nsteinme: `The`
- deleted by nsteinme: ` `
- inserted by nsteinme: ` cortical site`
- deleted by nsteinme: `cortical readout next to the stimulated site`
- inserted by nsteinme: `when stimulated in open-loop `

### main.tex:93

Line now (insertions applied, deletions removed):

> On this basis, we designed a closed-loop linear feedback controller with measured fluorescence as the input and laser intensity as the output.

- inserted by nsteinme: `ed`
- inserted by nsteinme: `closed-loop `
- inserted by nsteinme: ` with measured fluorescence as the input and laser intensity as the output`
- deleted by nsteinme: ` that tracks a reference`

### main.tex:94

Line now (insertions applied, deletions removed):

> The controller steered the activity to the target level more accurately than open-loop stimulation and reduced trial-to-trial variability.

- inserted by nsteinme: `The controller `
- deleted by nsteinme: `It holds`
- inserted by nsteinme: `target level`
- deleted by nsteinme: `reference`
- deleted by nsteinme: `in all 15 sessions from 4 mice `
- inserted by nsteinme: `d`
- deleted by nsteinme: `s`
- deleted by nsteinme: `, consistent with disturbance rejection`

### main.tex:95

Line now (insertions applied, deletions removed):

> Controller performance depended on brain state:

- inserted by nsteinme: `ed`
- deleted by nsteinme: `s`

### main.tex:96

Line now (insertions applied, deletions removed):

> feedback removed more of the error that accompanied overt bodily movements of the mouse, despite the activity being less predictable whereas its error grew with spontaneous delta-band (1--4\,Hz) synchronized cortical activity. 

- inserted by nsteinme: `d`
- deleted by nsteinme: `s`
- inserted by nsteinme: `d overt bodily`
- deleted by nsteinme: `s`
- inserted by nsteinme: `s of the mouse`
- inserted by nsteinme: `grew`
- deleted by nsteinme: `grows`
- inserted by nsteinme: `spontaneous `
- deleted by nsteinme: `slow-wave-like `
- inserted by nsteinme: `synchronized cortical `

### main.tex:98

Line now (insertions applied, deletions removed):

> For time-varying target levels, a preview component of the controller successfully compensated for system delays.

- inserted by nsteinme: `For `
- deleted by nsteinme: `In one mouse tracking a `
- inserted by nsteinme: `target levels`
- deleted by nsteinme: `reference`
- inserted by nsteinme: `a `
- inserted by nsteinme: ` component of the controller successfully compensated for system delays`
- deleted by nsteinme: ` cancels the phase lag of the cortical response, whereas feedback reduces error and variability`

### main.tex:105

Line now (insertions applied, deletions removed):

> We introduce a closed-loop control framework to steer cortical activity toward a target level. 

- inserted by nsteinme: `to steer`
- deleted by nsteinme: `that steers`
- inserted by nsteinme: `target level`
- deleted by nsteinme: `reference`

### main.tex:106

Line now (insertions applied, deletions removed):

> Using wide-field calcium imaging, we read out activity at one cortical site in real time and used it to set optogenetic inhibition delivered next to it. 

- inserted by nsteinme: `d`
- deleted by nsteinme: `, which can only lower that activity`

### main.tex:107

Line now (insertions applied, deletions removed):

> Closed-loop stimulation tracked the target level more accurately than open-loop, fixed stimulation and reduced trial-to-trial variability across sessions and animals.

- inserted by nsteinme: `ed`
- deleted by nsteinme: `s`
- inserted by nsteinme: `target level`
- deleted by nsteinme: `reference`
- inserted by nsteinme: `, fixed`
- inserted by nsteinme: `d`
- deleted by nsteinme: `s`

### main.tex:108

Line now (insertions applied, deletions removed):

> The remaining error depended on cortical state during the stimulation, and a feedforward preview corrected phase lags when tracking time-varying targets. 

- inserted by nsteinme: `remaining error depended`
- deleted by nsteinme: `error that remains under feedback depends`
- inserted by nsteinme: `during the`
- deleted by nsteinme: `around`
- inserted by nsteinme: `a `
- inserted by nsteinme: `ed`
- deleted by nsteinme: `s`
- deleted by nsteinme: `the `
- inserted by nsteinme: `s`
- inserted by nsteinme: `targets`
- deleted by nsteinme: `references`

### main.tex:109

Line now (insertions applied, deletions removed):

> Finally, a linear model based on measured activity of the opposite hemisphere predicted much of the spontaneous activity in the controlled region, allowing us estimate the disturbance the controller rejects on each trial.

- inserted by nsteinme: `based on measured activity `
- inserted by nsteinme: `ed`
- deleted by nsteinme: `s`
- deleted by nsteinme: ` (median held-out $R^2 = 0.76$)`
- inserted by nsteinme: `allowing`
- deleted by nsteinme: `which lets`

### results.tex:12

Line now (insertions applied, deletions removed):

> We built a closed-loop optogenetic system that precisely regulates (i.e., steers) the activity of a cortical region, monitored with wide-field calcium imaging in mice.

- inserted by nsteinme: ` (i.e., steers) `
- deleted by nsteinme: `, ie the ability to steer, `

### results.tex:19

Line now (insertions applied, deletions removed):

> Each mouse sat in a behavioral chamber facing a blank screen, with its forelimbs resting on a freely moving wheel, and was not engaged in any task, so all recordings captured spontaneous activity.

- inserted by nsteinme: ` `
- deleted by nsteinme: `~\citep{Matveev2024} `

### results.tex:20

Line now (insertions applied, deletions removed):

> We recorded cortical activity at 35\,Hz with wide-field calcium imaging (Figure~\ref{fig:figure1}A) and delivered spatially targeted optogenetic stimulation to a fixed cortical spot, which suppressed activity in the surrounding cortex (\citep{Matveev2024} ; Figure~\ref{fig:spatial_spread}A,B).

- inserted by nsteinme: `\citep{Matveev2024} ; `

### results.tex:21

Line now (insertions applied, deletions removed):

> We quantified cortical activity as the fractional change in fluorescence relative to its mean ($\Delta F/F$), averaged over pixels near the stimulation spot (Figure~\ref{fig:figure1}B,C; see Materials and Methods), and take this signal, which we call the 'output', as the quantity to be controlled.

- inserted by nsteinme: `We quantified cortical activity as the`
- deleted by nsteinme: `We refer to the controlled signal as the output, or simply activity: the`
- deleted by nsteinme: ` a kernel of`
- inserted by nsteinme: `near`
- deleted by nsteinme: `adjacent to`
- inserted by nsteinme: `, and take this signal, which we call the 'output', as the quantity to be controlled`

### results.tex:22

Line now (insertions applied, deletions removed):

> In a subset of experiments, we also recorded video of the face and computed its motion energy as a behavioral co-variate.

- inserted by nsteinme: `its `
- inserted by nsteinme: ` as a behavioral co-variate`
- deleted by nsteinme: `, the squared pixel change per unit time (see Materials and Methods)`

### results.tex:29

Line now (insertions applied, deletions removed):

>     \textbf{A:} Optical path of the wide-field microscope \citep{Matveev2024}. Blue (470\,nm) and violet (405\,nm) LEDs illuminate the dorsal cortex, and the camera collects emitted green light through two dichroics. A red (638\,nm) galvanometer-steered laser passes through both dichroics for spatially targeted optogenetic stimulation.\\

- inserted by nsteinme: ` \citep{Matveev2024}`

### results.tex:39

Line now (insertions applied, deletions removed):

> We built an end-to-end software system for real-time closed-loop control  (Figure~\ref{fig:figure1}D).

- inserted by nsteinme: `software `
- deleted by nsteinme: `of mesoscale activity`

### results.tex:40

Line now (insertions applied, deletions removed):

> At each imaging frame acquisition, the software collects the frame data, computes the error between the measured output and a reference $\Delta F/F$ value, and computes the required optogenetic stimulus amplitude. The system has a measured end-to-end loop delay of XX.X ms on average (mean; YY.Y-ZZ.Z range; Figure~\ref{fig:figure1}F).

- inserted by nsteinme: `At each imaging frame acquisition, the`
- deleted by nsteinme: `In real time,`
- inserted by nsteinme: `collects the frame data, `
- inserted by nsteinme: `,`
- inserted by nsteinme: ` amplitude. The system has`
- deleted by nsteinme: `, which drives the cortical dynamics with`
- inserted by nsteinme: `measured end-to-end `
- inserted by nsteinme: `XX.X ms on average (mean; YY.Y-ZZ.Z range; Figure~\ref{fig:figure1}F).`
- deleted by nsteinme: `at most 47\,ms and about half that on average (Figure~\ref{fig:figure1}E,F).`
