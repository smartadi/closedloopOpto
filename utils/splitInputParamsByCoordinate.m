function [coordStructs, uniqueCoords] = splitInputParamsByCoordinate(dOrInputParams, ampCol, freqCol, xCol, yCol, ampPriority)
% SPLITINPUTPARAMSBYCOORDINATE Split input_params into separate structs by unique (x,y).
%   [coordStructs, uniqueCoords] = splitInputParamsByCoordinate(d)
%   [coordStructs, uniqueCoords] = splitInputParamsByCoordinate(input_params)
%
%   Defaults:
%     ampCol = 11, freqCol = 12, xCol = 13, yCol = 14, ampPriority = 'descend'
%
%   Output coordStructs(k) fields:
%     .coord          [x y]
%     .x, .y          coordinate values
%     .rows           row indices in original input_params
%     .input_params   subset matrix for this coordinate
%     .unique_pairs   unique [amp freq] pairs within this coordinate subset
%     .rows_by_pair   row indices (global row numbers) for each amp/freq pair
%     .pair_id        pair index for each row in original input_params (0 elsewhere)

if nargin < 2 || isempty(ampCol)
    ampCol = 11;
end
if nargin < 3 || isempty(freqCol)
    freqCol = 12;
end
if nargin < 4 || isempty(xCol)
    xCol = 13;
end
if nargin < 5 || isempty(yCol)
    yCol = 14;
end
if nargin < 6 || isempty(ampPriority)
    ampPriority = 'descend';
end

if isstruct(dOrInputParams)
    if ~isfield(dOrInputParams, 'input_params')
        error('Input struct must contain field d.input_params.');
    end
    inputParams = dOrInputParams.input_params;
else
    inputParams = dOrInputParams;
end

requiredCols = max([ampCol, freqCol, xCol, yCol]);
if ~ismatrix(inputParams) || size(inputParams, 2) < requiredCols
    error('input_params must be a 2D matrix with enough columns.');
end

coordMatrix = inputParams(:, [xCol, yCol]);
[uniqueCoords, ~, coordId] = unique(coordMatrix, 'rows', 'stable');

nCoords = size(uniqueCoords, 1);
coordStructs = repmat(struct( ...
    'coord', [], 'x', [], 'y', [], 'rows', [], 'input_params', [], ...
    'unique_pairs', [], 'rows_by_pair', {{}}, 'pair_id', []), nCoords, 1);

nRows = size(inputParams, 1);

for k = 1:nCoords
    rows = find(coordId == k);
    subInput = inputParams(rows, :);

    [uniquePairsSub, rowsByPairLocal, pairIdLocal] = getInputAmpFreqGroups(subInput, ampCol, freqCol, ampPriority);

    rowsByPairGlobal = cell(size(rowsByPairLocal));
    for j = 1:numel(rowsByPairLocal)
        rowsByPairGlobal{j} = rows(rowsByPairLocal{j});
    end

    pairIdGlobal = zeros(nRows, 1);
    pairIdGlobal(rows) = pairIdLocal;

    coordStructs(k).coord = uniqueCoords(k, :);
    coordStructs(k).x = uniqueCoords(k, 1);
    coordStructs(k).y = uniqueCoords(k, 2);
    coordStructs(k).rows = rows;
    coordStructs(k).input_params = subInput;
    coordStructs(k).unique_pairs = uniquePairsSub;
    coordStructs(k).rows_by_pair = rowsByPairGlobal;
    coordStructs(k).pair_id = pairIdGlobal;
end
end
