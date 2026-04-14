function [stimStarts_time, stimEnds_time, uniqueImpulseAmp, idxByImpulseAmp] = ...
    detectStimEvents_idx(t, x, varargin)

    % Defaults
    MinDist_sec = 0.05;
    ThreshFrac  = 0.1;
    AmpTol      = 0.0;
    PreWin_sec  = 0.02;

    % Parse optional args
    for k = 1:2:length(varargin)
        switch lower(varargin{k})
            case 'mindist'
                MinDist_sec = varargin{k+1};
            case 'threshfrac'
                ThreshFrac = varargin{k+1};
            case 'amptol'
                AmpTol = varargin{k+1};
            case 'prewin'
                PreWin_sec = varargin{k+1};
        end
    end

    % Ensure column vectors
    t = t(:);
    x = x(:);

    % Derivative
    dx = [0; diff(x)];
    maxDx = max(abs(dx));
    if maxDx == 0
        stimStarts_time = [];
        stimEnds_time = [];
        uniqueImpulseAmp = [];
        idxByImpulseAmp = {};
        return;
    end

    th = ThreshFrac * maxDx;

    % Candidate edges
    starts = find(dx > th);
    ends   = find(dx < -th);

    % MinDist → samples
    dt = mean(diff(t));
    MinDist_samp = max(1, round(MinDist_sec / dt));

    starts = starts([true; diff(starts) > MinDist_samp]);
    ends   = ends([true; diff(ends) > MinDist_samp]);

    % Align start/end pairs
    ends(ends < starts(1)) = [];
    n = min(numel(starts), numel(ends));
    starts = starts(1:n);
    ends   = ends(1:n);

    good = ends > starts;
    starts = starts(good);
    ends   = ends(good);

    % Time outputs
    stimStarts_time = t(starts);
    stimEnds_time   = t(ends);

    % Compute amplitude per impulse
    PreWin_samp = max(1, round(PreWin_sec / dt));
    nEv = numel(starts);
    amp = zeros(nEv,1);

    for i = 1:nEv
        s = starts(i);
        e = ends(i);

        b0 = max(1, s - PreWin_samp);
        b1 = max(1, s - 1);
        baseline = median(x(b0:b1));

        seg = x(s:e);
        amp(i) = max(abs(seg - baseline));
    end

    % --- Grouping (unique amplitudes) ---
    if AmpTol > 0
        ampKey = round(amp / AmpTol) * AmpTol;
    else
        ampKey = amp;
    end

    [uniqueImpulseAmp, ~, groupID] = unique(ampKey, 'stable');

    % ---- SORT the unique amplitudes ----
    [uniqueImpulseAmp, sortOrder] = sort(uniqueImpulseAmp, 'ascend');

    % Reorder event groups accordingly
    idxByImpulseAmp = cell(numel(uniqueImpulseAmp),1);
    for k = 1:numel(uniqueImpulseAmp)
        origGroup = sortOrder(k);             % which group ID corresponds to this sorted amplitude
        idxByImpulseAmp{k} = find(groupID == origGroup);
    end
end
