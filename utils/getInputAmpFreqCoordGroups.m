function [groupTable, rowsByGroup, groupId, rowsByPairCoord] = getInputAmpFreqCoordGroups(dOrInputParams, ampCol, freqCol, xCol, yCol, ampPriority)
% GETINPUTAMPFREQCOORDGROUPS Group rows by (amp,freq) and then by (x,y).
%   [groupTable, rowsByGroup, groupId, rowsByPairCoord] = getInputAmpFreqCoordGroups(d)
%   [groupTable, rowsByGroup, groupId, rowsByPairCoord] = getInputAmpFreqCoordGroups(input_params)
%
%   Defaults:
%     ampCol = 11, freqCol = 12, xCol = 13, yCol = 14, ampPriority = 'descend'
%
%   Outputs:
%     groupTable      : table with one row per unique (amp,freq,x,y) group
%     rowsByGroup     : {nGroups x 1} row indices for each group (global group index)
%     groupId         : [nRows x 1] global group index for each row
%     rowsByPairCoord : {nPairs x 1}; each entry is {nCoordGroups x 1} row indices

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

[uniquePairs, rowsByPair] = getInputAmpFreqGroups(inputParams, ampCol, freqCol, ampPriority);

nRows = size(inputParams, 1);
groupId = zeros(nRows, 1);
rowsByGroup = {};
rowsByPairCoord = cell(size(uniquePairs, 1), 1);

pairIndexAll = [];
ampAll = [];
freqAll = [];
xAll = [];
yAll = [];
nRowsAll = [];

globalGroupCounter = 0;
for p = 1:size(uniquePairs, 1)
    pairRows = rowsByPair{p};
    xy = inputParams(pairRows, [xCol, yCol]);

    [uniqueXY, ~, xyId] = unique(xy, 'rows', 'stable');

    nXY = size(uniqueXY, 1);
    rowsByPairCoord{p} = cell(nXY, 1);

    for c = 1:nXY
        globalGroupCounter = globalGroupCounter + 1;

        currentRows = pairRows(xyId == c);
        rowsByPairCoord{p}{c} = currentRows;
        rowsByGroup{globalGroupCounter, 1} = currentRows;
        groupId(currentRows) = globalGroupCounter;

        pairIndexAll(globalGroupCounter, 1) = p;
        ampAll(globalGroupCounter, 1) = uniquePairs(p, 1);
        freqAll(globalGroupCounter, 1) = uniquePairs(p, 2);
        xAll(globalGroupCounter, 1) = uniqueXY(c, 1);
        yAll(globalGroupCounter, 1) = uniqueXY(c, 2);
        nRowsAll(globalGroupCounter, 1) = numel(currentRows);
    end
end

groupIndex = (1:globalGroupCounter)';
groupTable = table(groupIndex, pairIndexAll, ampAll, freqAll, xAll, yAll, nRowsAll, ...
    'VariableNames', {'group', 'pair', 'amp', 'freq', 'x', 'y', 'nRows'});
end
