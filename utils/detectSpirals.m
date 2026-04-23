function spirals = detectSpirals(U, V, t, stimStarts, stimEnds, window, serverRoot)
% detectSpirals  Detect spiral waves during stimulus windows.
%
%   spirals = detectSpirals(U, V, t, stimStarts, stimEnds, window, serverRoot)
%
%   Inputs
%     U          - spatial SVD components  [x × y × nSV]
%     V          - temporal SVD components [nSV × nFrames]
%     t          - time vector             [1 × nFrames], seconds
%     stimStarts - vector of stim onset times (seconds)
%     stimEnds   - vector of stim offset times (seconds)
%     window     - seconds to include before stim onset and after stim offset
%     serverRoot - session data folder (ROI saved/loaded here as spiral_roi.mat)
%
%   Output
%     spirals    - table with columns:
%                  center_x, center_y, radius, direction,
%                  abs_frame, trial, t_rel

addpath(genpath('C:\Users\aditya\Documents\projects\YE-et-al-2023-spirals\spirals'));

freq      = [2, 8];   % Hz bandpass (Ye et al. standard)
filterPad = 35;       % frames of padding for filter edge effects (~1 s at 35 Hz)
nSV       = 50;

U1  = U(:,:,1:nSV);
dV1 = [zeros(nSV,1), diff(V(1:nSV,:),[],2)];

params = setSpiralDetectionParams(U1, t);

%% ROI: load if saved, otherwise draw interactively and save
roi_path = fullfile(serverRoot, 'spiral_roi.mat');
fprintf('ROI path: %s\n', roi_path);

if exist(roi_path, 'file')
    fprintf('Loading existing ROI from %s\n', roi_path);
    load(roi_path, 'roi');
else
    fprintf('No ROI found — draw brain outline on the figure, then double-click to confirm.\n');
    mimg = mean(reshape(U1, [], nSV) * dV1, 2);   % rough mean image from SVD
    mimg = reshape(mimg, size(U1,1), size(U1,2));
    mimg_padded = padZeros(mimg, params.halfpadding);
    figure; imagesc(mimg_padded); colormap gray; axis image;
    title('Draw brain ROI, then double-click to confirm');
    roi = drawpolygon;
    input('Press Enter after confirming ROI...');
    save(roi_path, 'roi');
    fprintf('ROI saved to %s\n', roi_path);
end

tf           = inROI(roi, params.xx(:), params.yy(:));
params.xxRoi = params.xx(tf);
params.yyRoi = params.yy(tf);

%% Per-trial detection
spiralAll = [];
nTrials   = numel(stimStarts);

for j = 1:nTrials
    t0 = stimStarts(j);
    t1 = stimEnds(j);

    [~, f_start] = min(abs(t - (t0 - window)));
    [~, f_end  ] = min(abs(t - (t1 + window)));

    f_pad_start = max(1,         f_start - filterPad);
    f_pad_end   = min(length(t), f_end   + filterPad);

    dV_chunk = dV1(:, f_pad_start:f_pad_end);
    t_chunk  = t(f_pad_start:f_pad_end);

    [~, ~, tracePhase_raw] = spiralPhaseMap_freq(U1, dV_chunk, t_chunk, params, freq, 1);

    % strip filter padding
    i_start          = filterPad + 1;
    i_end            = size(tracePhase_raw, 3) - filterPad;
    tracePhase_inner = tracePhase_raw(:,:, i_start:i_end);

    tracePhase = padZeros(tracePhase_inner, params.halfpadding);

    nFrames    = size(tracePhase, 3);
    abs_frames = f_start:f_end;

    for fi = 1:nFrames
        A = squeeze(tracePhase(:,:,fi));

        pw1 = spiralAlgorithm(A, params);
        if isempty(pw1), continue; end

        pw2 = checkClusterXY(pw1, params.dThreshold);
        pw3 = doubleCheckSpiralsAlgorithm(A, pw2, params);
        pw4 = spatialRefine(A, pw3, params);
        pw5 = spiralRadiusCheck2(A, pw4, params);
        if isempty(pw5), continue; end

        pw5(:,1:2) = pw5(:,1:2) - params.halfpadding;

        abs_frame = abs_frames(fi);
        t_rel     = t(abs_frame) - t0;
        pw5(:, end+1) = abs_frame;
        pw5(:, end+1) = j;
        pw5(:, end+1) = t_rel;

        spiralAll = [spiralAll; pw5];
    end

    fprintf('Trial %d/%d done — %d spirals so far\n', j, nTrials, size(spiralAll,1));
end

if isempty(spiralAll)
    spirals = table();
    fprintf('No spirals detected.\n');
    return
end

spirals = array2table(spiralAll, 'VariableNames', ...
    {'center_x','center_y','radius','direction','abs_frame','trial','t_rel'});
fprintf('Done: %d spirals across %d trials.\n', height(spirals), nTrials);
end
