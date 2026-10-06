# Introduction — verified literature map (2026-10-05)

Every entry was checked against Crossref / Europe PMC / publisher records on 2026-10-05.
The bib already lost 4 fabricated refs (c803948) — **only cite from this list or re-verify.**
"Supports" = which paper claim / intro sentence it backs.

## Novelty verdict
Search (Europe PMC, 244 hits for closed-loop + widefield/mesoscale + optogenetic + GCaMP; web)
found **no published closed-loop optogenetic control of a widefield/mesoscale calcium signal**.
Closest: widefield neurofeedback where the actuator is the animal's learning (Clancy 2014,
Gupta & Murphy 2026); cellular all-optical closed loop (Zhang 2018/2025); single-unit
optogenetic control (Newman 2015, Bolus 2018/2021); Matveev 2024 = our read/write platform,
which explicitly leaves closed loop as future work. STIMscope (bioRxiv 2026) is mesoscale
closed-loop-capable but slices only.
→ Safe: "to our knowledge, the first closed-loop optogenetic control of mesoscale cortical
calcium activity"; "largely unexplored" is safe unhedged.
→ No paper tests linearity / dose-response of mesoscale optogenetic responses → Fig 2 linearity is new.
→ Contra-disturbance claim has direct precedent: **Shimaoka 2019** (contra hemisphere predicts
trial variability). Frame ours as *rejecting* it with feedback, not discovering it.

## Fixes to existing refs.bib
- `Zaaimi2022` → journal year is **2023**: Nat Biomed Eng 7:559–575, 10.1038/s41551-022-00945-8.
- `Matveev2024` is a bioRxiv (10.1101/2024.11.01.621418): widefield GCaMP + systemic AAV ChrimsonR
  in inhibitory neurons + galvo stim. Cite as the platform, not as closed-loop work.
- Ye et al. spirals: cite **Science 392 (2026), 10.1126/science.adx1369**, not the 2023 bioRxiv.
- Ritt & Ching 2015 is an **ACC proceedings** paper (10.1109/ACC.2015.7171915); omit page numbers (records disagree). No Neuron version exists.
- O'Shea/Shenoy optogenetic perturbation exists only as **bioRxiv 2022** (10.1101/2022.12.16.520768). No 2018 paper.

## A. Brain state & variability (the motivation)
| Key | Citation | DOI | Supports |
|---|---|---|---|
| Arieli1996 | Arieli, Sterkin, Grinvald, Aertsen. Science 273:1868 (1996) | 10.1126/science.273.5283.1868 | ongoing activity explains evoked variability |
| Petersen2003 | Petersen, Hahn, Mehta, Grinvald, Sakmann. PNAS 100:13638 (2003) | 10.1073/pnas.2235811100 | response depends on state at stim time |
| Churchland2010 | Churchland, Yu, Cunningham, et al. Nat Neurosci 13:369 (2010) | 10.1038/nn.2501 | stimulus onset quenches variability (our OL variance-slope result) |
| Goris2014 | Goris, Movshon, Simoncelli. Nat Neurosci 17:858 (2014) | 10.1038/nn.3711 | variability = slow gain fluctuations |
| Lin2015 | Lin, Okun, Carandini, Harris. Neuron 87:644 (2015) | 10.1016/j.neuron.2015.06.035 | shared low-dim variability |
| Scholvinck2015 | Schölvinck, Saleem, Benucci, Harris, Carandini. J Neurosci 35:170 (2015) | 10.1523/JNEUROSCI.4994-13.2015 | cortical state sets variability |
| Niell2010 | Niell, Stryker. Neuron 65:472 (2010) | 10.1016/j.neuron.2010.01.033 | locomotion modulates cortex |
| McGinley2015 | McGinley, David, McCormick. Neuron 87:179 (2015) | 10.1016/j.neuron.2015.05.038 | low arousal → slow fluctuations, variable responses |
| Vinck2015 | Vinck, Batista-Brito, Knoblich, Cardin. Neuron 86:740 (2015) | 10.1016/j.neuron.2015.03.028 | arousal vs locomotion; LF power |
| Reimer2014 | Reimer, Froudarakis, Cadwell, Yatsenko, Denfield, Tolias. Neuron 84:355 (2014) | 10.1016/j.neuron.2014.09.033 | synchronized/desynchronized switching in quiet wakefulness |
| Salkoff2020 | Salkoff, Zagha, McCarthy, McCormick. Cereb Cortex 30:421 (2020) | 10.1093/cercor/bhz206 | movement explains widefield activity |
| Crochet2006 | Crochet, Petersen. Nat Neurosci 9:608 (2006) | 10.1038/nn1690 | slow large Vm fluctuations in quiet awake mice (2–4 Hz claim) |
| Poulet2008 | Poulet, Petersen. Nature 454:881 (2008) | 10.1038/nature07150 | same |
| Mateo2011 | Mateo, Avermann, Gentet, Zhang, Deisseroth, Petersen. Curr Biol 21:1593 (2011) | 10.1016/j.cub.2011.08.028 | **optogenetic responses are state dependent** (Fig 2 precedent) |
| Massimini2005 | Massimini et al. Science 309:2228 (2005) | 10.1126/science.1117256 | perturbation (TMS) response depends on state |
| Sederberg2019 | Sederberg, Pala, Zheng, He, Stanley. PLoS Comput Biol 15:e1006716 (2019) | 10.1371/journal.pcbi.1006716 | pre-stim state improves single-trial prediction |
| Mohajerani2010 | Mohajerani, McVea, Fingas, Murphy. J Neurosci 30:3745 (2010) | 10.1523/JNEUROSCI.6437-09.2010 | bilateral mirrored spontaneous activity |
| Shimaoka2019 | Shimaoka, Steinmetz, Harris, Carandini. eLife 8:e43533 (2019) | 10.7554/eLife.43533 | **contra hemisphere predicts trial variability** (Fig 4 contra) |
| Ye2026 | Ye, …, Steinmetz. Science 392 (2026) | 10.1126/science.adx1369 | bilateral rotating waves; instantaneous contra→ipsi |
| Shimaoka2018 | Shimaoka, Harris, Carandini. Cell Rep 22:3160 (2018) | 10.1016/j.celrep.2018.02.092 | widefield arousal effects |
| Ma2016 | Ma, Shaik, …, Hillman. Phil Trans R Soc B 371:20150360 (2016) | 10.1098/rstb.2015.0360 | hemodynamic caveat |
| Valley2020 | Valley, Moore, Zhuang, …, Waters. J Neurophysiol 123:356 (2020) | 10.1152/jn.00304.2019 | hemodynamic caveat |
| Peters2021 | Peters, Fabre, Steinmetz, Harris, Carandini. Nature 591:420 (2021) | 10.1038/s41586-020-03166-8 | widefield pipeline |
| ZatkaHaas2021 | Zatka-Haas, Steinmetz, Carandini, Harris. eLife 10:e63163 (2021) | 10.7554/eLife.63163 | widefield + optogenetic inactivation (open loop) |
| Couto2021 | Couto, Musall, …, Churchland. Nat Protoc 16:3241 (2021) | 10.1038/s41596-021-00527-z | widefield methods |

Already in bib, verified: Harris2011 (10.1038/nrn3084), Stringer2019 (10.1126/science.aav7893),
musall2019single (10.1038/s41593-019-0502-4), mohajerani2013spontaneous (10.1038/nn.3499),
vanni2014mesoscale (10.1523/JNEUROSCI.1818-14.2014), allen2017global, makino2017transformation.

## B. Closed-loop neural control (positioning)
| Key | Citation | DOI | Supports |
|---|---|---|---|
| newman2015 (bib) | Newman, Fong, Millard, Whitmire, Stanley, Potter. eLife 4:e07192 (2015) | 10.7554/eLife.07192 | optoclamp, firing-rate setpoint |
| bolus2018 (bib) | Bolus, Willats, Whitmire, Rozell, Stanley. J Neural Eng 15:026011 (2018) | 10.1088/1741-2552/aaa506 | model-based PI design (PMID 29300002) |
| bolus2021 (bib) | Bolus, Willats, Rozell, Stanley. J Neural Eng 18:036006 (2021) | 10.1088/1741-2552/abb89c | LDS + LQR, awake mouse thalamus |
| Zhang2018 | Zhang, Russell, Packer, Gauld, Häusser. Nat Methods 15:1037 (2018) | 10.1038/s41592-018-0183-z | all-optical closed loop, cellular |
| Zhang2025 | Zhang, Dzialecka, …, Häusser. Cell Rep Methods 5:101180 (2025) | 10.1016/j.crmeth.2025.101180 | same, recent |
| Packer2015 | Packer, Russell, Dalgleish, Häusser. Nat Methods 12:140 (2015) | 10.1038/nmeth.3217 | all-optical foundation |
| Siegle2014 | Siegle, Wilson. eLife 3:e03061 (2014) | 10.7554/eLife.03061 | phase-locked closed loop |
| Paz2013 | Paz, Davidson, …, Huguenard. Nat Neurosci 16:64 (2013) | 10.1038/nn.3269 | event-triggered (seizure) |
| KrookMagnuson2013 | Krook-Magnuson, Armstrong, Oijala, Soltesz. Nat Commun 4:1376 (2013) | 10.1038/ncomms2376 | event-triggered (seizure) |
| nicholson2018 (bib) | Nicholson, Kuzmin, Leite, Akam, Kullmann. eLife 7:e38346 (2018) | 10.7554/eLife.38346 | oscillation control |
| kanta2019 (bib) | Kanta, Paré, Headley. Nat Commun 10:3970 (2019) | 10.1038/s41467-019-11938-8 | oscillation control |
| Zaaimi2023 (bib, fix year) | Zaaimi, …, Jackson. Nat Biomed Eng 7:559 (2023) | 10.1038/s41551-022-00945-8 | primate closed-loop optogenetics |
| clancy2014 (bib) | Clancy, Koralek, Costa, Feldman, Carmena. Nat Neurosci 17:807 (2014) | 10.1038/nn.3712 | imaging neurofeedback |
| Neely2018 | Neely, Koralek, Athalye, Costa, Carmena. Neuron 97:1356 (2018) | 10.1016/j.neuron.2018.01.051 | imaging neurofeedback |
| Gupta2026 | Gupta, Murphy. eLife 14:RP105070 (2026) | 10.7554/eLife.105070 | **closest**: real-time widefield ΔF/F in the loop, reward actuator (no opto) |
| Yang2018 | Yang, Connolly, Shanechi. J Neural Eng 15:066007 (2018) | 10.1088/1741-2552/aad1a8 | sysID → controller pipeline |
| Yang2021 | Yang, Qiao, Sani, Sedillo, Ferrentino, Pesaran, Shanechi. Nat Biomed Eng 5:324 (2021) | 10.1038/s41551-020-00666-w | multiregional stim-response LSSM |
| RittChing2015 | Ritt, Ching. Proc ACC (2015) | 10.1109/ACC.2015.7171915 | neurocontrol review |
| Fang2025 | Fang, Mombeini, Madhav. Curr Opin Behav Sci 66:101597 (2025) | 10.1016/j.cobeha.2025.101597 | recent closed-loop review |
| Fehrman2025 | Fehrman, Meliza. Neural Comput 37:2125 (2025) | 10.1162/neco.a.37 | MPC vs PID (in silico) — discussion |
| Lim2012 | Lim, Mohajerani, LeDue, Boyd, Chen, Murphy. Front Neural Circuits 6:11 (2012) | 10.3389/fncir.2012.00011 | mesoscale opto + imaging, open loop |
| Ambrosone2025 | Ambrosone et al. Brain Stimul 18:1514 (2025) | 10.1016/j.brs.2025.07.003 | widefield + opto silencing, open loop |

## C. Linear models & control theory
| Key | Citation | DOI | Supports |
|---|---|---|---|
| Nozari2024 | Nozari, Bertolero, …, Bassett. Nat Biomed Eng 8:68 (2024) | 10.1038/s41551-023-01117-y | **macroscale dynamics best fit by linear models; averaging hides nonlinearity** |
| Shenoy2013 | Shenoy, Sahani, Churchland. Annu Rev Neurosci 36:337 (2013) | 10.1146/annurev-neuro-062111-150509 | dynamical-systems view |
| Sani2021 | Sani, Abbaspourazad, Wong, Pesaran, Shanechi. Nat Neurosci 24:140 (2021) | 10.1038/s41593-020-00733-0 | linear SSM identification |
| Vahidi2024 | Vahidi, Sani, Shanechi. PNAS (2024) | 10.1073/pnas.2212887121 | input-driven vs intrinsic dynamics |
| Gu2015 | Gu, Pasqualetti, …, Bassett. Nat Commun 6:8414 (2015) | 10.1038/ncomms9414 | network controllability (theory) |
| Tang2018 | Tang, Bassett. Rev Mod Phys 90:031003 (2018) | 10.1103/RevModPhys.90.031003 | brain-network control review |
| Acharya2022 | Acharya, Ruf, Nozari. Front Control Eng 3:1046764 (2022) | 10.3389/fcteg.2022.1046764 | models for control review |
| Schiff2012 | Schiff. Neural Control Engineering. MIT Press (2012), ISBN 978-0-262-01537-0 | — | framing |
| Jazayeri2017 | Jazayeri, Afraz. Neuron 93:1003 (2017) | 10.1016/j.neuron.2017.02.019 | causal perturbation |
| Wolff2018 | Wolff, Ölveczky. Curr Opin Neurobiol 49:84 (2018) | 10.1016/j.conb.2018.01.004 | perils of perturbation |
| Pandarinath2018 | Pandarinath, O'Shea, …. Nat Methods 15:805 (2018) | 10.1038/s41592-018-0109-9 | single-trial dynamics (contrast) |

Already in bib, verified: Churchland2012 (10.1038/nature11129), vyas2020computation (10.1146/annurev-neuro-092619-094115).

## Unverified — do NOT cite
- Any Stanley-lab optoclamp follow-up after 2021 (none found).
- A paper showing widefield optogenetic responses scale with pre-stim δ power (none found — ours is new).
- Bergmann/Siebner "slow-oscillation state-dependent TMS" (not found).
- Wagenmaker et al. active-learning LDS: arXiv 2412.02529 only, venue unconfirmed.
