function txt = motionScatterCursor(~, event, mouse, fields)
% datacursormode UpdateFcn for the interactive motion scatter.
% Clicking a point opens a plotSingleTrial figure for that trial.
%
% Each scatter object must have UserData set to a struct array with fields:
%   .field     — key into mouse struct, e.g. 'm3'
%   .stim_idx  — index into d.stimStarts for this trial
%   .lbl       — 'OL' or 'CL'
%   .mse       — trial MSE

info = event.Target.UserData(event.DataIndex);

sess = mouse.(info.field);
plotSingleTrial(info.stim_idx, sess.d.timeBlue, sess.data.dFk, sess.d, info.lbl);

txt = {sprintf('%s  %s  e%d', sess.mn, sess.td, sess.en), ...
       sprintf('Trial %d  |  %s', info.stim_idx, info.lbl), ...
       sprintf('MSE = %.3f', info.mse)};
end
