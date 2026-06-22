%% package_for_collab.m
% Export a minimal, collaborator-ready bundle for impulse widefield sessions.
%
% Ships, per session:
%   widefield/ : canonical SVD  U[Y,X,nSV], V[nSV,nFrames], meanImage, frameTimes
%   aligned/   : laser input binned to SVD frames, motion energy on SVD frames,
%                FULL trial table (all 900 trials incl. zero-amp catch trials)
%   face/      : face motion SVD (motSVD + spatial masks + avg frames)
%
% Trial table comes from input_params.csv (ground truth: every commanded trial,
% all amplitude levels INCLUDING amplitude 0 / no-stim catch trials), not from
% analog detection. col2 = SVD frame index of onset (mode 1: minus a per-session
% horizon recovered by matching the measured analog onsets; mode 2: absolute).
%
% Re-saves U/V as single, first nSV comps -> ~150x smaller than the raw session
% folder, and arrays that np.load and MATLAB readNPY both read with no transpose.
%
% Run from impulse-analysis/ (section-by-section ok).

%% ---- config ----------------------------------------------------------
nSV     = 500;                                              % components to ship
outRoot = 'C:\Users\aditya\Documents\projects\collab_export';   % delivery folder (OUTSIDE repo)

% cols: mouse, date, expNum, lightCommand signal name, stimMode (1=AL_0033, 2=AL_0041)
sessions = {
    'AL_0041','2025-12-02',1,'lightCommand638', 2;
    'AL_0041','2025-12-02',2,'lightCommand638', 2;
    'AL_0033','2025-01-29',1,'lightCommand',    1;
};
selRows = 3;            % rows to export this run. Set to 1:size(sessions,1) for all.

%% ---- setup -----------------------------------------------------------
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
addpath(genpath(fullfile(thisDir,'..','utils')));
addpath(thisDir);
if ~exist(outRoot,'dir'), mkdir(outRoot); end

for r = selRows(:)'
    mn = sessions{r,1}; td = sessions{r,2}; en = sessions{r,3};
    sigName = sessions{r,4}; stimMode = sessions{r,5};
    fprintf('\n=== Packaging %s %s en%d (signal=%s, mode=%d) ===\n', mn,td,en,sigName,stimMode);
    serverRoot = expPath(mn,td,en);

    outDir = fullfile(outRoot, sprintf('%s_%s_en%d', mn, td, en));
    for s = {'widefield','aligned','face'}, mkdir(fullfile(outDir,s{1})); end

    %% --- widefield SVD (canonical, single, first nSV comps) ------------
    [U,V,t,mimg] = loadUVt(serverRoot, nSV);     % U[Y,X,nSV], V[nSV,N], t[N], mimg[Y,X]
    t = double(t(:));
    nFrames = numel(t);
    fs = 1/median(diff(t));
    writeNPY(single(U),    fullfile(outDir,'widefield','U_svdSpatial.npy'));
    writeNPY(single(V),    fullfile(outDir,'widefield','V_svdTemporal_corr.npy'));
    writeNPY(single(mimg), fullfile(outDir,'widefield','meanImage.npy'));
    writeNPY(t,            fullfile(outDir,'widefield','frameTimes.npy'));
    fprintf('  widefield: U[%d %d %d] V[%d %d] @ %.2f Hz\n', size(U,1),size(U,2),size(U,3), size(V,1),size(V,2), fs);
    clear U V mimg

    %% --- laser input binned to SVD frames ------------------------------
    [ti, vi] = getTLanalog(mn,td,en,sigName);
    ti = double(ti(:)); vi = double(vi(:));
    dtv   = median(diff(t));
    edges = [t(1)-dtv/2; (t(1:end-1)+t(2:end))/2; t(end)+dtv/2];   % per-frame bin edges
    bin   = discretize(ti, edges);
    ok    = ~isnan(bin);
    sums  = accumarray(bin(ok), vi(ok), [nFrames 1], @sum, 0);
    cnts  = accumarray(bin(ok), 1,      [nFrames 1], @sum, 0);
    input_binned          = sums ./ max(cnts,1);     % mean command per frame
    input_binned(cnts==0) = NaN;
    input_binned          = fillmissing(input_binned,'previous');
    input_binned          = fillmissing(input_binned,'nearest');

    %% --- motion energy on SVD frames (interp by time) ------------------
    fp   = load(fullfile(serverRoot,'face_proc.mat'),'motion_1');
    m1   = double(fp.motion_1(:));
    tAll = double(readNPY(fullfile(serverRoot,'frameTimes.timestamps.npy')));
    n    = min(numel(m1), numel(tAll));              % motion_1 may run 1-2 samples long
    motion_energy = interp1(tAll(1:n), m1(1:n), t, 'linear','extrap');
    clear fp

    %% --- FULL trial table from input_params.csv (incl. amplitude 0) ----
    ip        = readmatrix(fullfile(serverRoot,'input_params.csv'));
    frameRaw  = ip(:,2);           % onset index (frame units; +horizon for mode 1)
    amplitude = ip(:,9);           % commanded amplitude; 0 = no-stim / catch trial
    horizon   = 0;
    if stimMode == 1
        % recover horizon: shift commanded nonzero onsets onto measured analog onsets
        ss       = detectStimEvents_idx(ti, vi, 'AmpTol',0.1, 'MinDist',4);
        detFrame = interp1(t, (1:nFrames)', ss, 'nearest','extrap');
        nzRaw    = frameRaw(amplitude>0);
        cost     = @(h) median(arrayfun(@(f) min(abs((nzRaw-h)-f)), detFrame));
        hc       = 0:5:3000;  mc = arrayfun(cost, hc);  [~,bi] = min(mc);  h0 = hc(bi);
        hf       = h0-5:h0+5; mf = arrayfun(cost, hf);  [~,bj] = min(mf);  horizon = hf(bj);
        resid_ms = cost(horizon)/fs*1000;
        fprintf('  horizon = %d frames (commanded vs measured residual %.1f ms)\n', horizon, resid_ms);
    end
    svd_frame = round(frameRaw - horizon);
    inr       = svd_frame>=1 & svd_frame<=nFrames;
    svd_frame(~inr) = NaN;
    stim_time = nan(size(svd_frame));  stim_time(inr) = t(svd_frame(inr));
    measured_peak_V = nan(size(svd_frame));            % delivered volts (≈0 for catch trials)
    for i = find(inr)'
        lo = max(1,svd_frame(i)-1); hi = min(nFrames,svd_frame(i)+2);
        measured_peak_V(i) = max(input_binned(lo:hi));
    end
    trials = table((1:numel(amplitude))', stim_time, svd_frame, amplitude, measured_peak_V, ...
        'VariableNames', {'trial','stim_time_s','svd_frame','amplitude','measured_peak_V'});
    fprintf('  trials: %d total | %d zero-amp (catch) | %d nonzero | %d in-range\n', ...
        height(trials), sum(amplitude==0), sum(amplitude>0), sum(inr));

    %% --- face motion SVD ----------------------------------------------
    ff = load(fullfile(serverRoot,'face_proc.mat'), ...
              'motSVD_0','motMask_reshape_0','avgmotion_0','avgframe_0');
    writeNPY(single(ff.motSVD_0),          fullfile(outDir,'face','face_motSVD.npy'));      % [nFaceFrames x 500]
    writeNPY(single(ff.motMask_reshape_0), fullfile(outDir,'face','face_motMask.npy'));     % [Hy x Wx x 500]
    writeNPY(single(ff.avgmotion_0),       fullfile(outDir,'face','face_avgmotion.npy'));
    writeNPY(single(ff.avgframe_0),        fullfile(outDir,'face','face_avgframe.npy'));
    copyfile(fullfile(serverRoot,'frameTimes.timestamps.npy'), ...
             fullfile(outDir,'face','face_frameTimes.npy'));
    clear ff

    %% --- write aligned signals: npy + csv + mat ------------------------
    writeNPY(input_binned,  fullfile(outDir,'aligned','input_binned.npy'));
    writeNPY(motion_energy, fullfile(outDir,'aligned','motion_energy.npy'));
    writematrix([t input_binned motion_energy], ...
        fullfile(outDir,'aligned','aligned_signals.csv'));         % cols: frame_time_s, input, motion
    writetable(trials, fullfile(outDir,'aligned','trials.csv'));
    frame_times = t; %#ok<NASGU>
    save(fullfile(outDir,'aligned','session_aligned.mat'), ...
        'frame_times','input_binned','motion_energy','trials','fs','horizon','-v7');

    %% --- size report ---------------------------------------------------
    fl = dir(fullfile(outDir,'**','*'));
    tot = sum([fl(~[fl.isdir]).bytes]);
    fprintf('  DONE -> %s  (%.2f GB)\n', outDir, tot/1e9);
end

fprintf('\nDelivery folder: %s\n', outRoot);
fprintf('Remember the explanation file: %s\\README.md\n', outRoot);
