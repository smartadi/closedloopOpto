% Analysis_openloop_sinsusoid


clc;
close all;       
clear all;

%% experiment name


% 
% mn = 'AL_0041'; td = '2026-02-27'; 
% en = 1;

mn = 'AL_0041'; td = '2026-02-28'; 
en = 2;

%% get data

pathString = genpath('utils');
    addpath(pathString);
    % %%
    % addpath('utils')
d = initialize_data(mn,en,td);

%%

if isfield(d, 'input_params')
    [d.input_unique_pairs, d.input_rows_by_pair, d.input_pair_id] = getInputAmpFreqGroups(d, 11, 12, 'descend');
    printInputAmpFreqGroups(d.input_unique_pairs, d.input_rows_by_pair);
    [d.input_coord_structs, d.input_unique_coords] = splitInputParamsByCoordinate(d, 11, 12, 13, 14, 'descend');
    if numel(d.input_coord_structs) >= 1
        d.input_coord_1 = d.input_coord_structs(1);
    end
    if numel(d.input_coord_structs) >= 2
        d.input_coord_2 = d.input_coord_structs(2);
    end
else
    warning('d.input_params not found. Skipping amp/freq grouping.');
end

%% Run Movie
try 
    sigName = 'lightCommand638';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
catch
    sigName = 'lightCommand';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
end
tInd = 1;
traces(tInd).t = tt;
traces(tInd).v = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];

% tInd = 2;
% traces(tInd).t = tt;
% traces(tInd).v = vel;
% traces(tInd).name = 'wheelVelocity';
% traces(tInd).lims = [-3000 3000];
nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);
%% Load or save from image data

%mode = 0  % from binary image
mode = 1 ; % from SVD
%
% r = 0; % dont read file
r = 1; % read file

svdImage = mimg;
[clickData, mmData, clickPixelCoords, bregmaOffset] = openSVDImageClick(svdImage, 0.0173);
d.params.selected_pixels = clickPixelCoords;
if ~isempty(bregmaOffset)
    d.params.pix_inv = bregmaOffset;
    fprintf('Saved bregma offset from first click -> x=%d, y=%d\n', d.params.pix_inv(1), d.params.pix_inv(2));
end
if mmData.isValid
    d.params.pixel = [mmData.col, mmData.row];
    fprintf('MM-selected pixel -> x=%d, y=%d, value=%g\n', mmData.col, mmData.row, mmData.value);
elseif ~isempty(clickData)
    d.params.pixel = [clickData(1,2), clickData(1,1)];
    fprintf('Selected pixel -> x=%d, y=%d, value=%g\n', clickData(1,2), clickData(1,1), clickData(1,3));
end

% [pixelCoordsMM, pixelValuesMM, mmPositionsMM] = getPixelValuesFromMMPositionsImage(svdImage, d.params.pix_inv, [], 0.0173);
% d.params.mm_positions = mmPositionsMM;
% d.params.mm_pixel_coords = pixelCoordsMM;
% d.params.mm_pixel_values = pixelValuesMM;
% mmTable = table((1:size(mmPositionsMM,1))', mmPositionsMM(:,1), mmPositionsMM(:,2), ...
%     pixelCoordsMM(:,1), pixelCoordsMM(:,2), pixelValuesMM, ...
%     'VariableNames', {'idx','x_mm','y_mm','x_pix','y_pix','pixel_value'});
% disp(mmTable)



%%

d.params.pixels = d.unique_xy;

%%


data_trace = getpixels_trace(d);
F = data_trace.F;

%%
% try
%     data.ref_var = dlmread(append(serverRoot,"/reference.csv"),' ');
% catch
% end
% 
% data.ref_var = data.ref_var(1:length(d.timeBlue));
d.iputs = d.iputs(1:length(d.timeBlue));
%%

windowSec = 2;
[dFkpix, FmeanPix, windowSamples] = compute_dFoF_window(F, data_trace.t, windowSec);
data_trace.dFoverF = dFkpix;
data_trace.Fmean = FmeanPix;
data_trace.windowSec = windowSec;
data_trace.windowSamples = windowSamples;

if ~isempty(dFkpix)
    dFk = dFkpix(1,:);
end

if isfield(d, 'input_coord_structs') && ~isempty(d.input_coord_structs)
    preSec = 2;
    postSec = 3;
    
    for c = 1:numel(d.input_coord_structs)
        rowsByPair = d.input_coord_structs(c).rows_by_pair;
        d.input_coord_structs(c).pair_trial_avg = computeTrialAveragesByStimRows( ...
            dFkpix, d.timeBlue, d.stimStarts, rowsByPair, preSec, postSec);
    end

    if numel(d.input_coord_structs) >= 1
        d.input_coord_1 = d.input_coord_structs(1);
    end
    if numel(d.input_coord_structs) >= 2
        d.input_coord_2 = d.input_coord_structs(2);
    end

    nCoordToPlot = min(2, numel(d.input_coord_structs));
    hasInputsTrace = isfield(d, 'iputs') && ~isempty(d.iputs) && numel(d.iputs) >= numel(d.timeBlue);
    if hasInputsTrace
        inputTraceFull = d.iputs(:)';
        inputTime = d.timeBlue(:)';
        fsInput = 1 / median(diff(inputTime));
    end
    for c = 1:nCoordToPlot
        thisCoord = d.input_coord_structs(c);
        nPairs = numel(thisCoord.pair_trial_avg);
        if nPairs == 0
            continue;
        end

        % First plot for this coordinate: first 16 pairs as subplot grid
        nFirst = min(16, nPairs);
        figure('Name', sprintf('Coord %d first 16 pairs', c));
        for p = 1:nFirst
            meanTraceMat = thisCoord.pair_trial_avg(p).meanTrace;
            trialTraces = thisCoord.pair_trial_avg(p).trialTraces;
            if isempty(meanTraceMat)
                continue;
            end
            if isvector(meanTraceMat)
                plotTrace = meanTraceMat(:)';
            else
                plotTrace = mean(meanTraceMat, 1, 'omitnan');
            end

            subplot(4,4,p)
            tRel = thisCoord.pair_trial_avg(p).timeRelative;
            hold on
            if ~isempty(trialTraces)
                nTrials = size(trialTraces, 1);
                trialCurves = nan(nTrials, numel(tRel));
                for tr = 1:nTrials
                    trData = squeeze(trialTraces(tr, :, :));
                    if isvector(trData)
                        trialCurves(tr, :) = trData(:)';
                    else
                        trialCurves(tr, :) = mean(trData, 1, 'omitnan');
                    end
                end
                stdTrace = std(trialCurves, 0, 1, 'omitnan');
                ub = plotTrace + stdTrace;
                lb = plotTrace - stdTrace;
                fill([tRel, fliplr(tRel)], [lb, fliplr(ub)], [0.3 0.5 1.0], ...
                    'FaceAlpha', 0.25, 'EdgeColor', 'none');
            end
            plot(tRel, plotTrace, 'b', 'LineWidth', 2.5);

            if hasInputsTrace
                usedRows = thisCoord.pair_trial_avg(p).usedRows;
                nPreIn = round(thisCoord.pair_trial_avg(p).preSec * fsInput);
                nPostIn = round(thisCoord.pair_trial_avg(p).postSec * fsInput);
                inCurves = [];
                for rr = 1:numel(usedRows)
                    t0 = d.stimStarts(usedRows(rr));
                    [~, idx0In] = min(abs(inputTime - t0));
                    idxWinIn = (idx0In - nPreIn):(idx0In + nPostIn);
                    if idxWinIn(1) >= 1 && idxWinIn(end) <= numel(inputTraceFull)
                        inCurves = [inCurves; inputTraceFull(idxWinIn)];
                    end
                end
                if ~isempty(inCurves)
                    inMean = mean(inCurves, 1, 'omitnan');
                    tIn = (-nPreIn:nPostIn) / fsInput;
                    yyaxis right
                    plot(tIn, inMean, 'r-', 'LineWidth', 1.5);
                    ylabel('Input');
                    ylim([0 10]);
                    yyaxis left
                end
            end

            xline(0, '--k');
            xline(1, '--k');
            xline(3, ':k');
            title(sprintf('P%d | A=%g F=%g | n=%d', p, thisCoord.unique_pairs(p,1), thisCoord.unique_pairs(p,2), ...
                numel(thisCoord.pair_trial_avg(p).usedRows)));
            xlabel('Time from stimStart (s)');
            ylabel('dF/F (%)');
            xlim([-2 3]);
        end
        sgtitle(sprintf('Coord %d (x,y)=(%g,%g): first 16 pairs', c, thisCoord.x, thisCoord.y));

        % Second plot for this coordinate: last pair only
        pLast = nPairs;
        meanTraceMat = thisCoord.pair_trial_avg(pLast).meanTrace;
        trialTracesLast = thisCoord.pair_trial_avg(pLast).trialTraces;
        if isvector(meanTraceMat)
            plotTraceLast = meanTraceMat(:)';
        else
            plotTraceLast = mean(meanTraceMat, 1, 'omitnan');
        end

        figure('Name', sprintf('Coord %d last pair', c));
        tRelLast = thisCoord.pair_trial_avg(pLast).timeRelative;
        hold on
        if ~isempty(trialTracesLast)
            nTrialsLast = size(trialTracesLast, 1);
            trialCurvesLast = nan(nTrialsLast, numel(tRelLast));
            for tr = 1:nTrialsLast
                trData = squeeze(trialTracesLast(tr, :, :));
                if isvector(trData)
                    trialCurvesLast(tr, :) = trData(:)';
                else
                    trialCurvesLast(tr, :) = mean(trData, 1, 'omitnan');
                end
            end
            stdTraceLast = std(trialCurvesLast, 0, 1, 'omitnan');
            ubLast = plotTraceLast + stdTraceLast;
            lbLast = plotTraceLast - stdTraceLast;
            fill([tRelLast, fliplr(tRelLast)], [lbLast, fliplr(ubLast)], [0.3 0.5 1.0], ...
                'FaceAlpha', 0.25, 'EdgeColor', 'none');
        end
        plot(tRelLast, plotTraceLast, 'b', 'LineWidth', 2.8);

        if hasInputsTrace
            usedRowsLast = thisCoord.pair_trial_avg(pLast).usedRows;
            nPreInLast = round(thisCoord.pair_trial_avg(pLast).preSec * fsInput);
            nPostInLast = round(thisCoord.pair_trial_avg(pLast).postSec * fsInput);
            inCurvesLast = [];
            for rr = 1:numel(usedRowsLast)
                t0 = d.stimStarts(usedRowsLast(rr));
                [~, idx0In] = min(abs(inputTime - t0));
                idxWinIn = (idx0In - nPreInLast):(idx0In + nPostInLast);
                if idxWinIn(1) >= 1 && idxWinIn(end) <= numel(inputTraceFull)
                    inCurvesLast = [inCurvesLast; inputTraceFull(idxWinIn)];
                end
            end
            if ~isempty(inCurvesLast)
                inMeanLast = mean(inCurvesLast, 1, 'omitnan');
                tInLast = (-nPreInLast:nPostInLast) / fsInput;
                yyaxis right
                plot(tInLast, inMeanLast, 'r-', 'LineWidth', 1.7);
                ylabel('Input');
                ylim([0 10]);
                yyaxis left
            end
        end

        xline(0, '--k');
        xline(1, '--k');
        xline(3, ':k');
        title(sprintf('Coord %d (x,y)=(%g,%g) | Last Pair P%d | A=%g F=%g | n=%d', ...
            c, thisCoord.x, thisCoord.y, pLast, thisCoord.unique_pairs(pLast,1), thisCoord.unique_pairs(pLast,2), ...
            numel(thisCoord.pair_trial_avg(pLast).usedRows)));
        xlabel('Time from stimStart (s)');
        ylabel('dF/F (%)');
        xlim([-2 3]);
    end

    if isfield(d, 'input_rows_by_pair') && ~isempty(d.input_rows_by_pair)
        d.input_pair_trial_avg_all = computeTrialAveragesByStimRows( ...
            dFkpix, d.timeBlue, d.stimStarts, d.input_rows_by_pair, preSec, postSec);

        nPairsAll = numel(d.input_pair_trial_avg_all);
        if nPairsAll > 0
            nFirstAll = min(16, nPairsAll);
            figure('Name', 'All coordinates combined: first 16 pairs');
            for p = 1:nFirstAll
                meanTraceMat = d.input_pair_trial_avg_all(p).meanTrace;
                trialTraces = d.input_pair_trial_avg_all(p).trialTraces;
                if isempty(meanTraceMat)
                    continue;
                end
                if isvector(meanTraceMat)
                    plotTrace = meanTraceMat(:)';
                else
                    plotTrace = mean(meanTraceMat, 1, 'omitnan');
                end

                subplot(4,4,p)
                tRel = d.input_pair_trial_avg_all(p).timeRelative;
                hold on
                if ~isempty(trialTraces)
                    nTrials = size(trialTraces, 1);
                    trialCurves = nan(nTrials, numel(tRel));
                    for tr = 1:nTrials
                        trData = squeeze(trialTraces(tr, :, :));
                        if isvector(trData)
                            trialCurves(tr, :) = trData(:)';
                        else
                            trialCurves(tr, :) = mean(trData, 1, 'omitnan');
                        end
                    end
                    stdTrace = std(trialCurves, 0, 1, 'omitnan');
                    ub = plotTrace + stdTrace;
                    lb = plotTrace - stdTrace;
                    fill([tRel, fliplr(tRel)], [lb, fliplr(ub)], [0.3 0.5 1.0], ...
                        'FaceAlpha', 0.25, 'EdgeColor', 'none');
                end
                plot(tRel, plotTrace, 'b', 'LineWidth', 2.5);

                if hasInputsTrace
                    usedRows = d.input_pair_trial_avg_all(p).usedRows;
                    nPreIn = round(d.input_pair_trial_avg_all(p).preSec * fsInput);
                    nPostIn = round(d.input_pair_trial_avg_all(p).postSec * fsInput);
                    inCurves = [];
                    for rr = 1:numel(usedRows)
                        t0 = d.stimStarts(usedRows(rr));
                        [~, idx0In] = min(abs(inputTime - t0));
                        idxWinIn = (idx0In - nPreIn):(idx0In + nPostIn);
                        if idxWinIn(1) >= 1 && idxWinIn(end) <= numel(inputTraceFull)
                            inCurves = [inCurves; inputTraceFull(idxWinIn)];
                        end
                    end
                    if ~isempty(inCurves)
                        inMean = mean(inCurves, 1, 'omitnan');
                        tIn = (-nPreIn:nPostIn) / fsInput;
                        yyaxis right
                        plot(tIn, inMean, 'r-', 'LineWidth', 1.5);
                        ylabel('Input');
                        ylim([0 10]);
                        yyaxis left
                    end
                end

                xline(0, '--k');
                xline(1, '--k');
                xline(3, ':k');
                title(sprintf('ALL P%d | A=%g F=%g | n=%d', p, d.input_unique_pairs(p,1), d.input_unique_pairs(p,2), ...
                    numel(d.input_pair_trial_avg_all(p).usedRows)));
                xlabel('Time from stimStart (s)');
                ylabel('dF/F (%)');
                xlim([-2 3]);
            end
            sgtitle('All coordinates combined: first 16 pairs');

            pLastAll = nPairsAll;
            meanTraceMat = d.input_pair_trial_avg_all(pLastAll).meanTrace;
            trialTracesLast = d.input_pair_trial_avg_all(pLastAll).trialTraces;
            if isvector(meanTraceMat)
                plotTraceLast = meanTraceMat(:)';
            else
                plotTraceLast = mean(meanTraceMat, 1, 'omitnan');
            end

            figure('Name', 'All coordinates combined: last pair');
            tRelLast = d.input_pair_trial_avg_all(pLastAll).timeRelative;
            hold on
            if ~isempty(trialTracesLast)
                nTrialsLast = size(trialTracesLast, 1);
                trialCurvesLast = nan(nTrialsLast, numel(tRelLast));
                for tr = 1:nTrialsLast
                    trData = squeeze(trialTracesLast(tr, :, :));
                    if isvector(trData)
                        trialCurvesLast(tr, :) = trData(:)';
                    else
                        trialCurvesLast(tr, :) = mean(trData, 1, 'omitnan');
                    end
                end
                stdTraceLast = std(trialCurvesLast, 0, 1, 'omitnan');
                ubLast = plotTraceLast + stdTraceLast;
                lbLast = plotTraceLast - stdTraceLast;
                fill([tRelLast, fliplr(tRelLast)], [lbLast, fliplr(ubLast)], [0.3 0.5 1.0], ...
                    'FaceAlpha', 0.25, 'EdgeColor', 'none');
            end
            plot(tRelLast, plotTraceLast, 'b', 'LineWidth', 2.8);

            if hasInputsTrace
                usedRowsLast = d.input_pair_trial_avg_all(pLastAll).usedRows;
                nPreInLast = round(d.input_pair_trial_avg_all(pLastAll).preSec * fsInput);
                nPostInLast = round(d.input_pair_trial_avg_all(pLastAll).postSec * fsInput);
                inCurvesLast = [];
                for rr = 1:numel(usedRowsLast)
                    t0 = d.stimStarts(usedRowsLast(rr));
                    [~, idx0In] = min(abs(inputTime - t0));
                    idxWinIn = (idx0In - nPreInLast):(idx0In + nPostInLast);
                    if idxWinIn(1) >= 1 && idxWinIn(end) <= numel(inputTraceFull)
                        inCurvesLast = [inCurvesLast; inputTraceFull(idxWinIn)];
                    end
                end
                if ~isempty(inCurvesLast)
                    inMeanLast = mean(inCurvesLast, 1, 'omitnan');
                    tInLast = (-nPreInLast:nPostInLast) / fsInput;
                    yyaxis right
                    plot(tInLast, inMeanLast, 'r-', 'LineWidth', 1.7);
                    ylabel('Input');
                    ylim([0 10]);
                    yyaxis left
                end
            end

            xline(0, '--k');
            xline(1, '--k');
            xline(3, ':k');
            title(sprintf('All coordinates | Last Pair P%d | A=%g F=%g | n=%d', ...
                pLastAll, d.input_unique_pairs(pLastAll,1), d.input_unique_pairs(pLastAll,2), ...
                numel(d.input_pair_trial_avg_all(pLastAll).usedRows)));
            xlabel('Time from stimStart (s)');
            ylabel('dF/F (%)');
            xlim([-2 3]);
        end
    end
end

%% saver


if isfield(d, 'input_params') && ~isempty(d.input_params)
    d.input_params_table = array2table(d.input_params);
    nCols = size(d.input_params, 2);
    varNames = arrayfun(@(k) sprintf('col%d', k), 1:nCols, 'UniformOutput', false);
    if nCols >= 1, varNames{1} = 'id'; end
    if nCols >= 2, varNames{2} = 'timeIdx'; end
    if nCols >= 3, varNames{3} = 'controlId'; end
    if nCols >= 4, varNames{4} = 'Kref'; end
    if nCols >= 5, varNames{5} = 'Kp'; end
    if nCols >= 6, varNames{6} = 'Ki'; end
    if nCols >= 7, varNames{7} = 'ref'; end
    if nCols >= 8, varNames{8} = 'dur'; end
    if nCols >= 9, varNames{9} = 'traj'; end
    if nCols >= 10, varNames{10} = 'trajmode'; end
    if nCols >= 11, varNames{11} = 'amp'; end
    if nCols >= 12, varNames{12} = 'freq'; end
    if nCols >= 13, varNames{13} = 'x'; end
    if nCols >= 14, varNames{14} = 'y'; end
    if nCols >= 15, varNames{15} = 'px'; end
    if nCols >= 16, varNames{16} = 'py'; end
    d.input_params_table.Properties.VariableNames = matlab.lang.makeUniqueStrings(varNames);
    disp('Created d.input_params_table with named columns.');
end



%%

T = d.input_params_table;
S = d.stimStarts;
E = d.stimEnds;

save('ExperimentData022726.mat', 'T', 'S', 'E')