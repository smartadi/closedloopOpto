function d = findStims(d,mode)
%FINDSTIMS Summary of this function goes here
%   Detailed explanation goes here

input_params = d.input_params;

try
    horizon = d.params.horizon;
catch
    horizon  = 40*35;
end
dur = d.params.dur;
t = d.timeBlue;

if mode == 0
    % Threshold crossing on the analog light-command signal
    stimTimes = d.inpTime(d.inpVals(2:end)>0.1 & d.inpVals(1:end-1)<=0.1);
    ds = find(diff([0;stimTimes])>2);
    d.stimStarts = stimTimes(ds);
    d.stimEnds = stimTimes(ds(2:end)-1);
    d.stimDur = d.stimEnds-d.stimStarts(1:end-1);

elseif mode == 1
    % input_params column 2 stores sample index of stim onset relative to
    % horizon start; subtract horizon to recover absolute sample index.
    % Used by older sessions (AL_0033, AL_0039).
    a1 = input_params(:,2) - double(horizon)*ones(length(input_params),1);
    a2 = input_params(:,2) - double(horizon) + double(dur)*35;
    d.stimStarts = t(a1);
    d.stimEnds = t(a2);

elseif mode == 2
    % input_params column 2 stores the absolute sample index of stim onset.
    % No horizon subtraction. Used by newer sessions (AL_0041).
    a1 = input_params(:,2);
    a2 = input_params(:,2) + double(dur)*35;
    d.stimStarts = t(a1);
    d.stimEnds = t(a2);
end

end