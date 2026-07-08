# Contra→Ipsi Prediction Workflow — Standardized Pipeline

**Script:** `impulse-analysis/contra_prediction.m` (sectioned MATLAB workbench, run `%%` blocks in order/on demand)
**Session (canonical):** AL_0033, 2025-01-29, e1 (`selExp = 3`) — **n = 1**, replication on AL_0041 pending
**Purpose:** isolate the **LOCAL** photoinhibition effect (the stim response *not* explained by the shared inter-hemispheric network) and test its dependence on brain state.

> This file is the standing spec. It is the thing to *argue against*: every claim below names the section(s) that support it, the decision locks it rests on, and its current status (SOLID / CAVEAT / RETRACTED / PENDING). Edit here first, then change the script.

## ISSUES
- We first need to check our predictor scheme, the current rank1 spatial kernel I am getting seems incorrect. were the temporal motes normalized? from our original svd?



- I want solld characterization of bleed effects, like the bleed is so and so due to  

---

## 1. The argument (paper flow)

The pipeline is built to support one narrative, claim by claim:

| # | Claim | Supported by | Status |
|---|---|---|---|
| **C1** | The contra hemisphere linearly predicts a large fraction of the ipsi dip — the **Global** component (Ye/Zhiwen replication). | S08 `[CP-HEMI]` | SOLID |
| **C2** | That prediction is **spatially distributed network coupling**, *not* an artifact of stim light bleeding into contra pixels. | S09–S14 (KRECON, BLEED, CLEAN, CLEANRES, STIMAFF) | SOLID |
| **C3** | Decompose each trial: **Actual = Global + Local**, where **Local = Actual − Global = residual = the local stim effect**. | S16 `[CP-SETUP]` | DEFINITIONAL |
| **C4** | The **Local** stim effect is **motion-invariant**; the well-known motion→predictability effect lives entirely in **Global** (the network), not Local. | S18–S20 | SOLID (headline) |
| **C5** | Local's apparent variance/δ state-dependence is a **signal-power confound** and does **not** cross-replicate → **not claimed**. | S21, S22, `[CP-PREDQ]` S15, Zhiwen ctrl | RETRACTED |
| **C6** | The Local effect is **not a bleed-absorption artifact** (a state-modulated leakage faking a state-modulated Local). | S23 `[CP-BLEEDCTRL]`, S13 | SOLID |

**One-line headline:** *Splitting the ipsi photoinhibition response through the contralateral hemisphere shows the motion-dependent variability is a global/network property; the local stim response itself is state-robust.*

---

## 2. Pipeline stages

### Stage 0 — Data & site (S01–S07)  *foundation, no claims*
| S | Tag | Question / role | Key output |
|---|---|---|---|
| S01 | Setup | session + model params (`selExp`, `nSV_load`, `K`, ref) | scalars |
| S02 | Load SVD | load `U_cp,V_cp,mimg_cp` for the session | SVD |
| S03 | `[CP-SITE]` | **Where is the laser site?** (params.pixel is flip-prone) → data-derived deepest-inhibition pixel | `px_prim,py_prim`, `y_full` |
| S04 | mask/split | full-brain mask bisected at midline → contra / ipsi | `valid_cp_svd`, `ipsi_mask_cp` |
| S05 | contra SVD | re-SVD the contra pixels → predictor timeseries | `V_c_full`, `U_svd_raw` |
| S06 | frame count | frames for spontaneous windows | `nF_m` |
| S07 | `[CP-STIM]` | stim-onset list (nonzero amplitudes) | `all_starts_cp` |

### Stage 1 — The predictor & its validation (S08–S15)  *supports C1, C2*
| S | Tag | Question | Result (this session) | Status |
|---|---|---|---|---|
| S08 | `[CP-HEMI]` | Can contra modes predict the ipsi field/kernel? (whole-hemi RRR, held-out rank) | held-out kernel R² ≈ 0.88 (post-fix) | SOLID |
| S09 | `[CP-KERNEL]` | Which contra pixels carry the weight? | distributed weight map | SOLID |
| S10 | `[CP-KRECON]` | How large a contra **region** is needed? | coupling **distributed, not focal** | SOLID |
| S11 | `[CP-BLEED]` | Which contra pixels are **stim-input-affected** (amp-graded slope test)? | ~2% flagged (1623/80987) | SOLID |
| S12 | `[CP-CLEAN]` | Predict from **bleed-free** contra pixels only. | bleed & predictive maps **disjoint** (ρ=−0.06); drop bleed → R² unchanged 0.865 | SOLID |
| S13 | `[CP-CLEANRES]` | Does the STIM residual survive the bleed-free predictor? | peri-stim dip full −1.12 ≈ bleed-free −1.13 → **not a bleed-absorption artifact** | SOLID |
| S14 | `[CP-STIMAFF]` | Is "bleed-free" truly bleed-free? Exclude MORE onset-responsive px. | onset-targeted ≈ random at matched R² → deeper residual is **predictor-loss, not bleed**; ~95% of contra co-suppresses (network) | SOLID |
| S15 | `[CP-PREDQ]` | Does contra→ipsi **predictability** itself depend on brain state? (spontaneous, clickable) | Motion ρ=−0.01 (null); Var +0.79 / abs-δ +0.67 (power-confound); rel-δ +0.29 (does NOT replicate on Zhiwen) | CAVEAT |

**Alternative predictor (STANDALONE)** — **`impulse-analysis/ols_pixel_predictor.m`**, a fresh self-contained script *independent* of this RRR pipeline (its own data load; no redoSVD / CanonCor2 / reduced rank). Direct-pixel, **no-lag OLS** on a tight **200-pixel regular grid** over the contra map. Same interstim train/test split as CP-HEMI, so its held-out R² is directly comparable to the RRR `H.cv`. Interpretability foil / independent cross-check for C1: if a raw 200-pixel contemporaneous OLS reaches comparable R², the coupling is genuinely instantaneous and distributed, not an artifact of the SVD-mode machinery. Run after `load_experiments.m`. **Interactive:** weights overlaid on the brain; click any IPSI pixel to refit the contra kernel to that target (held-out R² live), with a companion figure of the 5 best / 5 worst held-out windows.

### Stage 2 — Decomposition (S16–S17)  *supports C3*
| S | Tag | Role | Output |
|---|---|---|---|
| **S16** | `[CP-SETUP]` | **RUN FIRST** for Stage 3. Builds `R` + `AGL` (Actual/Global/Local per-trial DVs). | `R`, `AGL`, `dA/dG/dL`, `trA/trG/trL` |
| S17 | `[CP-RESi]` | Clickable per-trial inspector (actual / contra-pred / residual / motion). | interactive |

### Stage 3 — State-dependence tests (S18–S23)  *supports C4, C5, C6*
| S | Tag | Question | Verdict |
|---|---|---|---|
| S18 | `[CP-LOCAL]` | For each state, does the effect live in Global or Local? | Motion→GLOBAL; var/δ→partly Local |
| S19 | `[CP-MOTION]` | Motion (binary) predictability, per component. | Local **motion-null** (partial ρ≈+0.003, p≈0.93) ✓ |
| S20 | `[CP-MOTION-AMP]` | Does motion↔predictability hold **within amplitude**? | yes for Actual, null for Local |
| S21 | `[CP-VAR]` | Pre-stim variance → Local predictability? | statistically survives BUT **power-confounded** ⚠ |
| S22 | `[CP-DELTA]` | Pre-stim 1–4 Hz δ → Local predictability? | same as S21 ⚠ |
| S23 | `[CP-BLEEDCTRL]` | Is any Local state-dep a **bleed** artifact? | confound **rejected** (bleed not state-dep, survives control, catch null) ✓ |

### Aux — Viewers
| S | Tag | Role |
|---|---|---|
| S24 | `[CP-TUNE]` | Per-pixel **amplitude tuning-curve** viewer (`pixelTuningCurveViewerSVD`); click a pixel → response vs stim amplitude. |

---

## 3. Run order

```
load_experiments.m                 % builds allExperiments (slow, reads server SVD)
S01 → S02 → S03 → S04 → S05 → S06 → S07     % foundation (in order)
S08 [CP-HEMI]  (+ S09 for [CP-KRECON]/explorers)
S10–S15                             % predictor-validation, any order
S16 [CP-SETUP]  ← REQUIRED before Stage 3
S17–S23                             % any order
S24 [CP-TUNE]                       % standalone viewer (needs load + [CP-SETUP] vars)
```

**If you rebuild the SVD caches** (redoSVD fix), re-run **S05 + S08 + S16** before any Stage-3 section — the in-memory `R`/`AGL` are stale.

---

## 4. Locked decisions (do not silently change)

- **Site** = data-derived deepest inhibition (`cp_find_stim_site`), array `[row 373, col 353]`; display transposed, mark `plot(px_prim,py_prim)`. `params.pixel` is untrusted (flip-prone).
- **Dip window** = 0–200 ms post-onset (`iDip`); 200–300 ms is rebound, not inhibition.
- **Predictor** = whole-hemisphere reduced-rank regression (CanonCor2), collapsed to affine map `yhat = V_c_full(1:K)'·bk + b0`. Input modes **K** (raise from 50 pending), RRR rank chosen by **held-out** kernel R².
- **DV primary = L1-dev** (predictability = trial's departure from the amplitude-mean dip template), **normalized as a RATIO to the amplitude-mean** (1 = average, <1 = more predictable; positive, amplitude-controlled). **DV secondary = template-gain** `<r,μ>/<μ,μ>` (signed size), z-within-amp.
- **decontam = false** for state analysis (per-amp constant cancels in within-amp deviations); decontam=true only for absolute dose-response.
- **use_motion = false** in the contra map (so motion can be tested as an independent state).
- **Motion split** threshold z = 0.5 (binary No/Motion); low-motion exclusion `motThr = 1.5` for var/δ.
- **Spontaneous train window** = post-settle interstim (`settle_s = 1.0`), 2/3 train / 1/3 test temporal split.

---

## 5. Known caveats & open items

- **redoSVD DC-offset bug (FIXED, caches rebuilding):** per-batch mean subtraction injected step artifacts at 975-frame batch boundaries; fixed to a single global mean. Kernel R² 0.847→0.885. Caches deleted 2026-07-02; **rebuild + K-raise pending**.
- **var/δ Local state-dependence — RETRACTED:** signal-power confound (`PreVar = var(y)` is L1-dev's own scale). Relative-δ (power-independent) gave +0.29 here but **flips to −0.25/−0.33 on Zhiwen AB_0004** → not a general law. No power-independent predictability-state effect survives cross-dataset replication. Motion-null untested on Zhiwen (no motion trace).
- **n = 1:** everything is AL_0033 0129 e1. Replicate the whole flow on AL_0041 e1/e2 (needs interactive ROI + `cp_find_stim_site`).
- **Reviewer risks (tracked):** hemodynamic contamination of the contra predictor; n=1; "Local-as-residual" (Local inherits both signals' noise). Pre-submission checklist in TASKS.md.

---

## 6. Helper map (utils/)

`cp_residual_core.m` (shared compute for S16) · `cp_agl.m` (A/G/L split) · `cp_hemi_predictor.m` (deployable RRR map, S08) · `cp_pixel_recon.m` (S10) · `cp_clean_predict.m` (S12) · `cp_cleanres.m` (S13) · `cp_stimaffect.m` (S14) · `cp_spont_predq.m` (S15) · `cp_res_inspector.m` (S17) · `cp_cont_state.m` (S21/22) · `cp_bleed_control.m` (S23) · `cp_motion_amp.m` (S20) · `pixelTuningCurveViewerSVD.m` (S24, vendored `utils/widefield/miniGUIs/`).

---

*Last updated 2026-07-02. Change log of the pipeline itself lives in `RESEARCH.md`; per-finding status in `FINDINGS.md`.*
