function scatterClickCallback(src, ev, mouse, fields)
% ButtonDownFcn for interactive motion scatter.
% Fires only on mouse click (unlike datacursormode which fires on hover).
% Finds the nearest data point to the click location and opens plotSingleTrial.

pt  = ev.IntersectionPoint(1:2);   % [x, y] in data coordinates
[~, idx] = min((src.XData(:) - pt(1)).^2 + (src.YData(:) - pt(2)).^2);

info = src.UserData(idx);
sess = mouse.(info.field);
plotSingleTrial(info.stim_idx, sess.d.timeBlue, sess.data.dFk, sess.d, info.lbl);
end
