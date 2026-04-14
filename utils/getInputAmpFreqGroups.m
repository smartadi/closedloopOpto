function [uniquePairs, rowsByPair, pairId] = getInputAmpFreqGroups(dOrInputParams, ampCol, freqCol, ampPriority)
% GETINPUTAMPFREQGROUPS Group input_params rows by unique (amp,freq) pairs.
%   [uniquePairs, rowsByPair, pairId] = getInputAmpFreqGroups(d)
%   [uniquePairs, rowsByPair, pairId] = getInputAmpFreqGroups(input_params)
%   [uniquePairs, rowsByPair, pairId] = getInputAmpFreqGroups(..., ampCol, freqCol, ampPriority)
%
%   Defaults: ampCol = 11, freqCol = 12.
%   Default ampPriority = 'descend' (high amp first).
%   Example:
%     [uniquePairs, rowsByPair, pairId] = getInputAmpFreqGroups(d, 11, 12, 'descend');
%     printInputAmpFreqGroups(uniquePairs, rowsByPair);
%
%   Outputs:
%     uniquePairs : [nPairs x 2] unique [amp freq] pairs (sorted by ampPriority)
%     rowsByPair  : {nPairs x 1} each cell has row indices for that pair
%     pairId      : [nRows x 1] pair index (1..nPairs) for each row

if nargin < 2 || isempty(ampCol)
    ampCol = 11;
end
if nargin < 3 || isempty(freqCol)
    freqCol = 12;
end
if nargin < 4 || isempty(ampPriority)
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

if ~ismatrix(inputParams) || size(inputParams, 2) < max(ampCol, freqCol)
    error('input_params must be a 2D matrix with enough columns.');
end

pairMatrix = inputParams(:, [ampCol, freqCol]);
[uniquePairsStable, ~, pairIdStable] = unique(pairMatrix, 'rows', 'stable');

switch lower(string(ampPriority))
    case "ascend"
        [uniquePairs, sortIdx] = sortrows(uniquePairsStable, [1 2]);
    case "descend"
        [uniquePairs, sortIdx] = sortrows(uniquePairsStable, [-1 2]);
    otherwise
        error('ampPriority must be ''ascend'' or ''descend''.');
end

nPairs = size(uniquePairs, 1);
rowsByPair = cell(nPairs, 1);
pairId = zeros(size(pairIdStable));

for k = 1:nPairs
    stableGroupIdx = sortIdx(k);
    rowsByPair{k} = find(pairIdStable == stableGroupIdx);
    pairId(rowsByPair{k}) = k;
end
end
