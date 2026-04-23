function features = feature_analysis(dFk, d, data)
% Computes sliding variance and band-power features over the full session,
% then extracts per-trial summaries for wc (closed-loop) and nc (open-loop) trials.
%
% Inputs:
%   dFk  — 1xT primary pixel dF/F trace
%   d    — experiment struct (d.timeBlue, d.stimStarts)
%   data — trial struct (data.wc, data.nc, data.er_wcDfk, data.er_ncDfk)
%
% Returned fields:
%   features.v1/v2/v3     — full-session causal variance (1xT), windows 1/2/3 s
%   features.mf           — full-session band-power ratios (Tx3), 2 s window
%   features.wc / .nc     — per-trial structs with:
%       .onset_var   [nTrials x 3]  variance at stimulus onset
%       .onset_freq  [nTrials x 3]  band power at stimulus onset
%       .pre_var     [nTrials x 3]  sum of variance over 2 s pre-trial
%       .pre_freq    [nTrials x 3]  sum of band power over 2 s pre-trial
%       .post_var    [nTrials x 3]  sum of variance over 3 s post-trial
%       .post_freq   [nTrials x 3]  sum of band power over 3 s post-trial
%       .total_var   [nTrials x 3]  sum over [-3 s, +3 s] window
%       .total_freq  [nTrials x 3]  sum over [-3 s, +3 s] window

    Fs = 35;
    t  = d.timeBlue;

    % --- Full-session sliding features (computed once, indexed per trial) ---
    features.v1 = compute_past_variance(dFk, Fs, 1);
    features.v2 = compute_past_variance(dFk, Fs, 2);
    features.v3 = compute_past_variance(dFk, Fs, 3);
    features.mf = compute_bandpower_sliding(dFk, Fs, 2);

    % --- Per-trial extraction ---
    features.wc = extractTrialFeatures(features, data.wc, d.stimStarts, t, Fs);
    features.nc = extractTrialFeatures(features, data.nc, d.stimStarts, t, Fs);
end


function tf = extractTrialFeatures(features, trialIdx, stimStarts, t, Fs)
% Extract per-trial variance and frequency features from precomputed signals.

    nTrials   = numel(trialIdx);
    pre_samp  = round(2 * Fs);   % 2 s pre-trial
    post_samp = round(3 * Fs);   % 3 s post-trial
    tot_samp  = round(3 * Fs);   % total window: [-3 s, +3 s]
    T         = numel(features.v1);

    tf.onset_var  = zeros(nTrials, 3);
    tf.onset_freq = zeros(nTrials, 3);
    tf.pre_var    = zeros(nTrials, 3);
    tf.pre_freq   = zeros(nTrials, 3);
    tf.post_var   = zeros(nTrials, 3);
    tf.post_freq  = zeros(nTrials, 3);
    tf.total_var  = zeros(nTrials, 3);
    tf.total_freq = zeros(nTrials, 3);

    for i = 1:nTrials
        [~, k] = min(abs(t - stimStarts(trialIdx(i))));

        % Bounds-safe window edges
        k_pre_lo  = max(1, k - pre_samp);
        k_post_hi = min(T, k + post_samp);
        k_tot_lo  = max(1, k - tot_samp);

        % Instantaneous at onset
        tf.onset_var(i,:)  = [features.v1(k), features.v2(k), features.v3(k)];
        tf.onset_freq(i,:) = features.mf(k,:);

        % 2 s pre-trial
        tf.pre_var(i,:)  = [sum(features.v1(k_pre_lo:k)), ...
                             sum(features.v2(k_pre_lo:k)), ...
                             sum(features.v3(k_pre_lo:k))];
        tf.pre_freq(i,:) = [sum(features.mf(k_pre_lo:k, 1)), ...
                             sum(features.mf(k_pre_lo:k, 2)), ...
                             sum(features.mf(k_pre_lo:k, 3))];

        % 3 s post-trial
        tf.post_var(i,:)  = [sum(features.v1(k:k_post_hi)), ...
                              sum(features.v2(k:k_post_hi)), ...
                              sum(features.v3(k:k_post_hi))];
        tf.post_freq(i,:) = [sum(features.mf(k:k_post_hi, 1)), ...
                              sum(features.mf(k:k_post_hi, 2)), ...
                              sum(features.mf(k:k_post_hi, 3))];

        % [-3 s, +3 s] total window
        tf.total_var(i,:)  = [sum(features.v1(k_tot_lo:k_post_hi)), ...
                               sum(features.v2(k_tot_lo:k_post_hi)), ...
                               sum(features.v3(k_tot_lo:k_post_hi))];
        tf.total_freq(i,:) = [sum(features.mf(k_tot_lo:k_post_hi, 1)), ...
                               sum(features.mf(k_tot_lo:k_post_hi, 2)), ...
                               sum(features.mf(k_tot_lo:k_post_hi, 3))];
    end
end
