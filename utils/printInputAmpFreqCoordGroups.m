function printInputAmpFreqCoordGroups(groupTable, rowsByGroup)
% PRINTINPUTAMPFREQCOORDGROUPS Print amp/freq/x/y groups with row numbers.
%   printInputAmpFreqCoordGroups(groupTable, rowsByGroup)

if nargin < 2
    error('Usage: printInputAmpFreqCoordGroups(groupTable, rowsByGroup)');
end

requiredVars = {'group','pair','amp','freq','x','y','nRows'};
if ~all(ismember(requiredVars, groupTable.Properties.VariableNames))
    error('groupTable must contain variables: group, pair, amp, freq, x, y, nRows');
end

if numel(rowsByGroup) ~= height(groupTable)
    error('rowsByGroup length must match number of rows in groupTable.');
end

fprintf('group\tpair\tamp\tfreq\tx\ty\tnRows\trowNumbers\n');
for k = 1:height(groupTable)
    rows = rowsByGroup{k};
    if isempty(rows)
        rowStr = '[]';
    else
        rowStr = sprintf('%d ', rows);
        rowStr = strtrim(rowStr);
    end

    fprintf('%d\t%d\t%g\t%g\t%g\t%g\t%d\t%s\n', ...
        groupTable.group(k), groupTable.pair(k), groupTable.amp(k), groupTable.freq(k), ...
        groupTable.x(k), groupTable.y(k), groupTable.nRows(k), rowStr);
end
end
