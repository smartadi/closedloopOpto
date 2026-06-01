function fig = paperFig(w, h)
% Standard paper figure: w x h in centimeters, white background, correct PaperSize.
% PaperPositionMode='manual' is critical: prevents MATLAB from overriding
% PaperPosition with an auto-calculated value that drifts from [0 0 w h].
fig = figure('Color','w');
fig.Units             = 'centimeters';
fig.PaperUnits        = 'centimeters';
fig.Position          = [0 0 w h];
fig.PaperSize         = [w h];
fig.PaperPosition     = [0 0 w h];
fig.PaperPositionMode = 'manual';
end
