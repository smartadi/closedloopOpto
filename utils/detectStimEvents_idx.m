function [stimStarts_time, stimEnds_time, uniqueImpulseAmp, idxByImpulseAmp] = ...
    detectStimEvents_idx(t, x, varargin)

    % Defaults
    MinDist_sec = 0.05;
    ThreshFrac  = 0.1;
    AmpTol      = 0.0;
    PreWin_sec  = 0.02;
    GapTol      = 0.03;   % V; see grouping note below

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
            case 'gaptol'
                GapTol = varargin{k+1};
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
    % 2026-10-10: group by GAPS between sorted per-event amplitudes (a new level starts where
    % consecutive amplitudes differ by > GapTol), then label each group on the AmpTol grid
    % (round(median/AmpTol)*AmpTol). Plain rounding split a single plateau that straddles a
    % rounding boundary: AL_0041 2025-12-02 e2's 1.945-1.958 V plateau went 26 events to "1.9"
    % and 19 to "2.0" (RESEARCH 2026-10-10). Within-plateau spread is <= 0.013 V in every impulse
    % session, and the closest genuine levels are 0.079 V apart (AL_0041 e2, 2.594 vs 2.682 V),
    % so GapTol = 0.03 merges split plateaus without merging real levels. Labels are unchanged
    % for every group that rounding did not split.
    if AmpTol > 0
        [sa, so] = sort(amp);
        gid = cumsum([1; diff(sa) > GapTol]);
        ampKey = zeros(size(amp));
        for gI = 1:max(gid)
            ampKey(so(gid == gI)) = round(median(sa(gid == gI)) / AmpTol) * AmpTol;
        end
        assert(numel(unique(ampKey)) == max(gid), 'detectStimEvents_idx:labels', ...
            'two amplitude groups round to the same %.2f V label; inspect the levels', AmpTol);
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
