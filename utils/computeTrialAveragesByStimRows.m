function pairTrialAvg = computeTrialAveragesByStimRows(dFoverF, timeVec, stimStarts, rowsByPair, preSec, postSec)
if nargin < 5 || isempty(preSec)
    preSec = 2;
end
if nargin < 6 || isempty(postSec)
    postSec = 3;
end

if isvector(dFoverF)
    dFoverF = dFoverF(:)';
end

if ndims(dFoverF) ~= 2
    error('dFoverF must be a vector or 2D matrix [nTraces x nTime].');
end

timeVec = timeVec(:)';
stimStarts = stimStarts(:);

if size(dFoverF, 2) ~= numel(timeVec)
    error('timeVec length must match size(dFoverF,2).');
end

if ~iscell(rowsByPair)
    error('rowsByPair must be a cell array of row index vectors.');
end

dt = median(diff(timeVec));
if dt <= 0
    error('timeVec must be strictly increasing.');
end

fs = 1 / dt;
nPre = round(preSec * fs);
nPost = round(postSec * fs);
relTime = (-nPre:nPost) / fs;
nSamples = numel(relTime);
nTraces = size(dFoverF, 1);

pairTrialAvg = repmat(struct( ...
    'rows', [], ...
    'usedRows', [], ...
    'skippedRows', [], ...
    'trialTraces', [], ...
    'meanTrace', [], ...
    'timeRelative', relTime, ...
    'preSec', preSec, ...
    'postSec', postSec), numel(rowsByPair), 1);

for p = 1:numel(rowsByPair)
    rows = rowsByPair{p}(:);
    rows = rows(rows >= 1 & rows <= numel(stimStarts));

    trialStack = nan(numel(rows), nTraces, nSamples);
    usedRows = [];
    skippedRows = [];

    trialCount = 0;
    for r = 1:numel(rows)
        stimRow = rows(r);
        t0 = stimStarts(stimRow);
        [~, idx0] = min(abs(timeVec - t0));

        idxWin = (idx0 - nPre):(idx0 + nPost);
        if idxWin(1) < 1 || idxWin(end) > numel(timeVec)
            skippedRows = [skippedRows; stimRow];
            continue;
        end

        trialCount = trialCount + 1;
        trialStack(trialCount, :, :) = dFoverF(:, idxWin);
        usedRows = [usedRows; stimRow];
    end

    if trialCount == 0
        trialTraces = [];
        meanTrace = nan(nTraces, nSamples);
    else
        trialTraces = trialStack(1:trialCount, :, :);
        meanTrace = squeeze(mean(trialTraces, 1, 'omitnan'));
        if isvector(meanTrace)
            meanTrace = reshape(meanTrace, 1, []);
        end
    end

    pairTrialAvg(p).rows = rows;
    pairTrialAvg(p).usedRows = usedRows;
    pairTrialAvg(p).skippedRows = skippedRows;
    pairTrialAvg(p).trialTraces = trialTraces;
    pairTrialAvg(p).meanTrace = meanTrace;
end
end
