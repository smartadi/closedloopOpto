# PCA-Based Stim Artifact Removal from Contra Widefield Signal (MATLAB)

## Context

Widefield calcium imaging timeseries. Optogenetic stim applied to one hemisphere. Stim bleedover contaminates the contralateral signal. A trained contra→ipsi activity predictor (R²=0.9 on clean data) must be run during stim trials without propagating the artifact. Goal: clean the contra signal before feeding it to the predictor.

## Data Assumptions

- `wf_data`: 3D array `(T, X, Y)` — full widefield timeseries
- `stim_onsets`: vector of frame indices where stim begins
- `contra_mask`: logical `(X, Y)` — contralateral hemisphere pixels
- `pre_stim_frames`, `post_stim_frames`: window around stim onset
- Predictor is a trained function/model that takes a contra ROI timeseries and returns ipsi prediction

---

## Step 1: Extract Contra Pixels

Reshape `wf_data` so contra pixels are a 2D matrix `(T, N_contra_pixels)` using `contra_mask`. All subsequent steps operate on this matrix.

---

## Step 2: Build the Mean Stim Artifact Epoch

For each stim onset, extract the peri-stim window `[onset - pre_stim_frames : onset + post_stim_frames]` from the contra pixel matrix. Baseline-subtract each epoch using the mean of the pre-stim frames. Stack all trials and average across trials to get a single mean artifact epoch of shape `(T_epoch, N_contra_pixels)`. This is the stereotyped artifact spatiotemporal pattern.

---

## Step 3: PCA on the Mean Artifact Epoch

Run PCA on the mean artifact epoch matrix (observations = timepoints, variables = pixels). Use `pca()` in MATLAB — it expects `(observations x variables)` so the orientation is correct. Retain the top 10 components to start.

Plot the explained variance (scree plot). Plot the spatial map of each top component by reshaping the component vector back to `(X, Y)` using `contra_mask`. 

**Artifact components** will look like a smooth radial blob near the stim site bleeding into contra. **Neural components** will look like functional cortical areas. Manually select `n_artifact_components` (typically 1–3) that look like artifact. Store these as `artifact_basis` of shape `(n_artifact_components, N_contra_pixels)`.

---

## Step 4: Project Out Artifact from Each Stim Trial

For each stim onset:
1. Extract the post-stim window from the raw contra pixel matrix
2. Baseline-subtract using pre-stim mean
3. Project the baseline-corrected signal onto `artifact_basis` to get per-timepoint coefficients: `coeffs = signal_bc * artifact_basis'` — shape `(T_window, n_artifact_components)`
4. Reconstruct the artifact: `artifact_recon = coeffs * artifact_basis`
5. Subtract the artifact reconstruction, then add the baseline back
6. Write the cleaned signal back into only that window of the contra pixel matrix

Do not modify non-stim frames.

---

## Step 5: Validate

- Re-project the cleaned stim windows onto `artifact_basis` — residual coefficients should be near zero
- Confirm non-stim frames are bit-for-bit identical to the original
- Plot the mean cleaned stim epoch spatially and compare to the mean raw stim epoch — the bleedover blob should be gone, any real neural structure should remain
- Optionally: compute variance explained by artifact basis before vs after cleaning as a scalar QC metric

---

## Step 6: Run Predictor on Cleaned Signal

Aggregate the cleaned contra pixel matrix into whatever input format the predictor expects (e.g., mean over an ROI mask, or a specific pixel subset). Pass the full cleaned timeseries to the predictor — stim and non-stim frames together. The predictor should now produce artifact-free ipsi predictions during stim events.

---

## Key Gotchas

- Fit PCA on the **mean stim epoch only**, not the full timeseries — otherwise artifact variance is diluted
- Always baseline-correct before projecting, then add baseline back after — prevents DC offsets corrupting coefficients
- Only overwrite stim windows — leave non-stim frames untouched
- If stim amplitude varies trial-to-trial, the per-trial coefficient fitting (Step 4) handles this naturally
- Watch for over-subtraction: if real contra neural activity is spatially correlated with the artifact blob, PCA will remove it. The spatial map inspection in Step 3 is the main guard against this
