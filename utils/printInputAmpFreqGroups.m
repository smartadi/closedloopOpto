function printInputAmpFreqGroups(uniquePairs, rowsByPair)
% PRINTINPUTAMPFREQGROUPS Print grouped amp/freq rows in compact format.
%   printInputAmpFreqGroups(uniquePairs, rowsByPair)
%
%   uniquePairs: [nPairs x 2] [amp freq]
%   rowsByPair : {nPairs x 1} row indices for each pair

if nargin < 2
    error('Usage: printInputAmpFreqGroups(uniquePairs, rowsByPair)');
end

if size(uniquePairs, 2) ~= 2
    error('uniquePairs must be nPairs x 2 [amp freq].');
end

nPairs = size(uniquePairs, 1);
if numel(rowsByPair) ~= nPairs
    error('rowsByPair length must match number of unique pairs.');
end

fprintf('pair\tamp\tfreq\tnRows\trowNumbers\n');
for k = 1:nPairs
    rows = rowsByPair{k};
    if isempty(rows)
        rowStr = '[]';
    else
        rowStr = sprintf('%d ', rows);
        rowStr = strtrim(rowStr);
    end
    fprintf('%d\t%g\t%g\t%d\t%s\n', k, uniquePairs(k,1), uniquePairs(k,2), numel(rows), rowStr);
end
end
