function [stimStarts_time, stimEnds_time] = detectStimEvents(t, x, varargin)
% detectStimEvents
% Detect onset and offset time points (and indices) of impulses or steps.
%
% Usage:
%   [idxStart, idxEnd, tStart, tEnd] = detectStimEvents(t, x);
%
% Optional name/value parameters:
%   'MinDist'    : minimum separation between events in SECONDS (default = 0.05)
%   'ThreshFrac' : fraction of max(|dx|) for detection threshold (default = 0.05)

    % Defaults
    MinDist_sec = 0.05;      % event spacing in seconds
    ThreshFrac  = 0.05;

    % Parse optional args
    for k = 1:2:length(varargin)
        switch lower(varargin{k})
            case 'mindist'
                MinDist_sec = varargin{k+1};
            case 'threshfrac'
                ThreshFrac = varargin{k+1};
        end
    end

    % Ensure column vectors
    t = t(:);
    x = x(:);

    if length(t) ~= length(x)
        error('Time array t and signal x must have same length.');
    end

    % Derivative
    dx = [0; diff(x)];

    % Threshold based on derivative magnitude
    maxDx = max(abs(dx));
    if maxDx == 0
        stimStarts_idx = [];
        stimEnds_idx = [];
        stimStarts_time = [];
        stimEnds_time = [];
        return;
    end
    th = ThreshFrac * maxDx;

    % Rising and falling edge candidates
    candidatesStart = find(dx > th);
    candidatesEnd   = find(dx < -th);

    % Convert MinDist from seconds → samples (based on time array)
    dt = mean(diff(t));   % estimated sample period
    MinDist_samples = round(MinDist_sec / dt);

    % Enforce minimum spacing
    stimStarts_idx = candidatesStart([true; diff(candidatesStart) > MinDist_samples]);
    stimEnds_idx   = candidatesEnd([true; diff(candidatesEnd) > MinDist_samples]);

    % Align start/end pairs
    stimEnds_idx(stimEnds_idx < stimStarts_idx(1)) = [];
    n = min(length(stimStarts_idx), length(stimEnds_idx));
    stimStarts_idx = stimStarts_idx(1:n);
    stimEnds_idx   = stimEnds_idx(1:n);

    % Time outputs
    stimStarts_time = t(stimStarts_idx);
    stimEnds_time   = t(stimEnds_idx);
end
