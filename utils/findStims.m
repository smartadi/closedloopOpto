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
    stimTimes = d.inpTime(d.inpVals(2:end)>0.1 & d.inpVals(1:end-1)<=0.1);
    ds = find(diff([0;stimTimes])>2);
    d.stimStarts = stimTimes(ds);
    d.stimEnds = stimTimes(ds(2:end)-1);
    
    
    d.stimDur = d.stimEnds-d.stimStarts(1:end-1);
else
    a1 = input_params(:,2) - double(horizon)*ones(length(input_params),1);
    a2 = input_params(:,2) - double(horizon) + double(dur)*35;
    
    % a1 = input_params(:,2);% - double(horizon)*ones(length(input_params),1);
    % a2 = input_params(:,2)+double(dur)*35;% - double(horizon) + double(dur)*35;

    d.stimStarts = t(a1);
    d.stimEnds = t(a2);
end

end