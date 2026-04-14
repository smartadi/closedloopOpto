function pixelGroups = splitStimStartsByPixelAndMode(stimStarts, inputParams, pixelCols, modeCol, trajValue)
% SPLITSTIMSTARTSBYPIXELANDMODE Split stimStarts by unique pixel and mode.
%   pixelGroups = splitStimStartsByPixelAndMode(stimStarts, inputParams)
%   pixelGroups = splitStimStartsByPixelAndMode(stimStarts, inputParams, [13 14], 9, 1)
%
%   inputParams(:,pixelCols) -> [x y] pixel
%   inputParams(:,modeCol)   -> mode label; traj when == trajValue, else step

if nargin < 3 || isempty(pixelCols)
    pixelCols = [13 14];
end
if nargin < 4 || isempty(modeCol)
    modeCol = 9;
end
if nargin < 5 || isempty(trajValue)
    trajValue = 1;
end

if isempty(stimStarts) || isempty(inputParams)
    pixelGroups = struct([]);
    return;
end

if size(inputParams,2) < max([pixelCols(:); modeCol])
    error('inputParams does not contain required columns.');
end

stimStarts = stimStarts(:);
nRows = min(numel(stimStarts), size(inputParams,1));
if nRows < numel(stimStarts)
    warning('Truncating stimStarts to match inputParams rows.');
elseif nRows < size(inputParams,1)
    warning('Truncating inputParams rows to match stimStarts.');
end

stimStartsUse = stimStarts(1:nRows);
inputUse = inputParams(1:nRows, :);

xy = inputUse(:, pixelCols);
[uniqueXY, ~, grpId] = unique(xy, 'rows', 'stable');

nGroups = size(uniqueXY, 1);
pixelGroups = repmat(struct( ...
    'pixel', [], ...
    'rows_all', [], ...
    'stimStarts_all', [], ...
    'rows_traj', [], ...
    'stimStarts_traj', [], ...
    'rows_step', [], ...
    'stimStarts_step', []), nGroups, 1);

modeVals = inputUse(:, modeCol);

for g = 1:nGroups
    rowsAll = find(grpId == g);
    rowsTraj = rowsAll(modeVals(rowsAll) == trajValue);
    rowsStep = rowsAll(modeVals(rowsAll) ~= trajValue);

    pixelGroups(g).pixel = uniqueXY(g, :);
    pixelGroups(g).rows_all = rowsAll;
    pixelGroups(g).stimStarts_all = stimStartsUse(rowsAll);
    pixelGroups(g).rows_traj = rowsTraj;
    pixelGroups(g).stimStarts_traj = stimStartsUse(rowsTraj);
    pixelGroups(g).rows_step = rowsStep;
    pixelGroups(g).stimStarts_step = stimStartsUse(rowsStep);
end
end
