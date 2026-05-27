%% Data analysis Script

% add pixel configuration


clc;
close all;
clear all;

%% experiment name - define all experiments

experiments = {
    'AL_0041', '2025-12-02', 1, 'lightCommand638';
    'AL_0041', '2025-12-02', 2, 'lightCommand638';

    % 'AL_0033', '2025-01-18', 1, 'lightCommand'; % no violet ?
    'AL_0033', '2025-01-29', 1, 'lightCommand';

    % 'AL_0033', '2025-01-29', 1, 'lightCommand';
};

% Storage for combined results
allExperiments = struct();

%% Loop through all experiments
for expIdx = 1:size(experiments, 1)
    mn = experiments{expIdx, 1};
    td = experiments{expIdx, 2};
    en = experiments{expIdx, 3};
    sigName = experiments{expIdx, 4};
    
    fprintf('Processing experiment %d/%d: %s, %s, en=%d, signal=%s\n', ...
        expIdx, size(experiments,1), mn, td, en, sigName);

% get data
pathString = genpath('utils');
addpath(pathString);

githubDir = "/home/nimbus/Documents/Brain/";
    
    
% Script to analyze widefield/behavioral data from 
addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab
    
    
serverRoot = expPath(mn, td, en);
    
d = loadData(serverRoot,mn,td,en);

% Run Movie
% sigName is now set from experiments array
[tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);

tInd = 1;
traces(tInd).t = tt;
traces(tInd).v = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];


nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);
%
mv   = d.motion.motion_1(1:2:end);
mv_z = zscore(mv);
% movieWithTracesSVD(U, V, t, traces, [], []);

% find stims

% [stimStarts, stimEnds] = detectStimEvents(tt, v, ...
%     'MinDist', 4, ...
%     'ThreshFrac', 0.05);

[stimStarts, stimEnds, uAmp, idxByAmp] = detectStimEvents_idx(tt, v, ...
    'AmpTol', 0.1, 'MinDist', 4);



% ============================
% FILL MISSING (ZERO) STARTS
% ============================
EventPeriod_sec = 5;                      % expected stim spacing
GapThresh_sec   = 1.5 * EventPeriod_sec;  % trigger insertion
MaxInsert       = 1000;                   % safety cap
DedupTol_sec    = 0.5 * EventPeriod_sec; % de-dup tolerance

detS = stimStarts(:);
insS = [];

if numel(detS) >= 2
    for i = 1:numel(detS)-1
        gap = detS(i+1) - detS(i);

        if gap > GapThresh_sec
            nMissing = round(gap / EventPeriod_sec) - 1;
            if nMissing < 1
                nMissing = floor(gap / EventPeriod_sec) - 1;
            end

            if nMissing > 0
                nMissing = min(nMissing, MaxInsert);
                newS = detS(i) + (1:nMissing)' * EventPeriod_sec;

                % keep strictly inside the gap
                newS = newS(newS < detS(i+1) - 0.25*EventPeriod_sec);

                insS = [insS; newS];
            end
        end
    end
end

% ============================
% REBUILD PER-EVENT AMP FOR DETECTED EVENTS (from uAmp + idxByAmp)
% ============================
nDet = numel(detS);
ampDet = nan(nDet,1);
for k = 1:numel(uAmp)
    ampDet(idxByAmp{k}) = uAmp(k);
end
if any(isnan(ampDet))
    warning('Some detected events were not assigned an amplitude. Check idxByAmp coverage.');
end

% ============================
% MERGE STARTS + AMPS, SORT TOGETHER, THEN DEDUP
% ============================
allS   = [detS; insS];
allAmp = [ampDet; zeros(numel(insS),1)];   % inserted => 0 amplitude

[allS, ord]   = sort(allS, 'ascend');
allAmp        = allAmp(ord);

% De-duplicate near-equal times (keep first)
if ~isempty(allS)
    keep = [true; diff(allS) > DedupTol_sec];
    allS   = allS(keep);
    allAmp = allAmp(keep);
end

% ============================
% REBUILD uAmp / idxByAmp CONSISTENTLY WITH FILLED + SORTED EVENTS
% ============================
% If you want tolerance-binning here too, do it now:
AmpTol = 0.1;  % keep consistent with your call above
if AmpTol > 0
    ampKey = round(allAmp / AmpTol) * AmpTol;
else
    ampKey = allAmp;
end

uAmp_filled = unique(ampKey, 'stable');         % keep stable order first
[uAmp_filled, sortOrder] = sort(uAmp_filled);   % then sort amplitudes

idxByAmp_filled = cell(numel(uAmp_filled),1);
for kk = 1:numel(uAmp_filled)
    idxByAmp_filled{kk} = find(ampKey == uAmp_filled(kk));
end

% ---- final outputs you'll use ----
stimStarts_filled = allS;
uAmp_filled       = uAmp_filled;
idxByAmp_filled   = idxByAmp_filled;

% (optional) overwrite originals
stimStarts = stimStarts_filled;
uAmp       = uAmp_filled;
idxByAmp   = idxByAmp_filled;

save(fullfile('data', sprintf('stim_vars_%s_%s_en%d.mat', mn, td, en)), 'uAmp', 'idxByAmp', 'stimStarts');


% get dF/F
% d.mv = d.motion.motion_1(1:2:end);

% 
UU = reshape(U, 560*560, nSV);
brainMask_e = mimg(:) > 0.1 * max(mimg(:));   % exclude dim background
UU_brain_e  = UU(brainMask_e, :);             % nBrainPx × nSV


F=[];
pixel  = d.params.pixel;
j=1;
k = d.params.kernel;
mI=[];
for i = 1:length(V)
            mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
            mI = [mI,mean(mimg_kernel,'all')];
            imkernel = U(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
            % size(imkernel)
            imstack = mean(imkernel,[1,2]);
            % size(imstack)   
            F = [F,reshape(imstack,[1,500])*V(:,i)];
end
%

dF = F/mI(1)*100;

% dF = F;




% sort dF by impulse, but define "peak inhibition" at a fixed time point
fs      = 35;    % Hz
tWin    = 3.0;   % seconds for DF_imp window (+/-)
winSamp = round(tWin * fs);

% ---- Peak_imp method (switch here) ----
% 2 : per-trial min within ±5-sample window around trial-average trough
% 3 : mean dF/F over fixed 0–200 ms post-onset window
% peak_mode = 2;
peak_mode = 3;

% Session-level spectrogram (matches controllerData.m convention)
specWin = 2 * fs;           % 70-sample Hann window → Δf = 0.5 Hz
specHop = fs;               % 35-sample hop → 1-s steps
nBands  = 20;               % bands 0–10 Hz, one FFT bin each
[S_spec, ~, t_spec] = spectrogram(dF, hann(specWin), specWin-specHop, specWin, fs);
S_bands = abs(S_spec(1:nBands, :)).^2;   % absolute power, (\DeltaF/F)^2 Hz^-1
S_norm  = S_bands ./ (sum(S_bands, 1) + eps);   % kept for reference, not used for freqSpec
freqBandCtrs = (0:nBands-1)*0.5 + 0.25;          % 0.25, 0.75, …, 9.75 Hz

nAmp = length(uAmp);
imp = struct();
imp.uAmp         = num2cell(uAmp(:));
imp.Peak_imp     = cell(nAmp,1);
imp.Peak_imp_dev = cell(nAmp,1);
imp.mot          = cell(nAmp,1);
imp.freqSpec     = cell(nAmp,1);
imp.dfImp        = cell(nAmp,1);
imp.motTrace     = cell(nAmp,1);
imp.Peak_imp_mean = nan(nAmp,1);
imp.mot_mean      = nan(nAmp,1);
imp.p_var         = cell(nAmp,1);
imp.startTimes    = cell(nAmp,1);
imp.resp_map      = cell(nAmp,1);   % brain-pixel dF/F response (peak − baseline)
imp.base_map      = cell(nAmp,1);   % brain-pixel dF/F during baseline window

DF_imp   = nan(nAmp, 2*winSamp+1);
t_win    = -3:1/35:3;
cumMv    = [0; cumsum(mv_z(:))];          % for vectorised motion sums
dt_spec  = t_spec(2) - t_spec(1);
iSpec_hw = round(1.0 / dt_spec);          % ±1 s in spectrogram bins
nF  = numel(dF);
nMv = numel(mv_z);
t0  = d.timeBlue(1);
for i = 1:length(uAmp)
    impulseNums  = idxByAmp{i};
    startTimes_i = stimStarts(impulseNums);

    % vectorised nearest-frame lookup (avoids per-trial linear scan)
    bAll  = round((startTimes_i(:) - t0) * fs) + 1;
    bAll  = max(1, min(nF, bAll));
    valid = (bAll - winSamp) >= 1 & (bAll + winSamp) <= min(nF, nMv);
    bAll  = bAll(valid);
    valid_start = startTimes_i(valid)';
    nV    = numel(bAll);

    % Spatial maps: trial-averaged dF/F in SVD space, brain pixels only
    % Baseline: −500 ms to 0 ms;  Peak: 0 to +200 ms (matches peak_mode=3)
    iBase_off = (-round(0.5*fs)):(-1);
    iPeak_off = 1 : round(0.2*fs);
    if nV > 0
        bBase = bAll(:) + iBase_off;            % nV × nBase frame indices
        bPeak = bAll(:) + iPeak_off;            % nV × nPeak frame indices
        V_base_m = mean(V(:, bBase(:)), 2);     % nSV × 1, mean over all baseline frames
        V_peak_m = mean(V(:, bPeak(:)), 2);
        imp.resp_map{i} = UU_brain_e * (V_peak_m - V_base_m) / mI(1) * 100;
        imp.base_map{i} = UU_brain_e * V_base_m / mI(1) * 100;
    else
        imp.resp_map{i} = zeros(sum(brainMask_e), 1);
        imp.base_map{i} = zeros(sum(brainMask_e), 1);
    end

    if nV == 0
        df_imp = zeros(0, 2*winSamp+1);
        mot      = zeros(1, 0);
        motTrace = zeros(0, 2*winSamp+1);
        freqSpec = nan(0, nBands);
    else
        % df_imp and motTrace: extract all trials at once via index matrix
        idxMat   = bAll(:) + (-winSamp:winSamp);              % nV × nSamp
        baseline = reshape(dF(bAll), nV, 1);                  % force nV × 1
        df_imp   = bsxfun(@minus, dF(idxMat), baseline);      % nV × nSamp
        motTrace = mv_z(idxMat);                               % nV × nSamp

        % motion cumsum over ±35 samples (±1 s) — wide window kept for analysis flexibility
        i0_mot = max(1,   bAll - 35);
        i1_mot = min(nMv, bAll + 35);
        mot    = (cumMv(i1_mot + 1) - cumMv(i0_mot))';   % 1 × nV

        % freqSpec: pre-allocated, integer-index spectrogram slice per trial
        freqSpec = nan(nV, nBands);
        for j = 1:nV
            ic   = round(((bAll(j)-1)/fs - t_spec(1)) / dt_spec) + 1;
            i_lo = max(1, ic - iSpec_hw);
            i_hi = min(size(S_norm,2), ic + iSpec_hw);
            freqSpec(j,:) = mean(S_bands(:, i_lo:i_hi), 2)';
        end
    end

    % p_imp: trial-level inhibition depth.
    % df_imp columns: winSamp+1 = stim onset (= 0 by construction).
    if ~isempty(df_imp)
        mean_resp  = mean(df_imp, 1);
        post_start = winSamp + 2;          % first sample strictly after onset
        [~, pk]    = min(mean_resp(post_start:end));
        avg_peak   = post_start - 1 + pk;  % trial-average trough index

        if peak_mode == 2
            % Option 2: per-trial min within ±5 samples of trial-average trough.
            % Allows latency jitter; ±143 ms search window bounds noise.
            hw       = 5;
            srch     = max(post_start, avg_peak-hw) : min(size(df_imp,2), avg_peak+hw);
            p_imp    = min(df_imp(:, srch), [], 2);

        else  % peak_mode == 3
            % Option 3: mean dF/F over 0–200 ms post-onset.
            % Integrates total inhibition energy; insensitive to peak timing.
            win3     = post_start : min(size(df_imp,2), winSamp + round(0.22*fs));
            p_imp    = mean(df_imp(:, win3), 2);
        end
    else
        p_imp = zeros(0, 1);
    end
    % plot(t_win,df_imp,'Color',[0,0,i/(length(uAmp))],'LineWidth',3);
    % plot(t_win,mean(df_imp),'Color',[1,0,i/(length(uAmp))],'LineWidth',5);

    imp.Peak_imp{i}     = p_imp;
    imp.mot{i}          = mot(:);
    imp.Peak_imp_dev{i} = abs(p_imp - mean(p_imp, 'omitnan'));
    imp.freqSpec{i}     = freqSpec;
    imp.dfImp{i}        = df_imp;
    imp.motTrace{i}     = motTrace;

    imp.Peak_imp_mean(i) = mean(p_imp, 'omitnan');
    imp.mot_mean(i)      = mean(mot,   'omitnan');

    mu_p = mean(p_imp, 'omitnan');

    imp.p_var{i}      = p_imp - mu_p;
    imp.startTimes{i} = valid_start;


    if ~isempty(df_imp)
        DF_imp(i,:) = mean(df_imp, 1);
    end

end

% Store results for this experiment
tmp         = cellfun(@(v) v(:), imp.Peak_imp, 'UniformOutput', false);
allVals     = vertcat(tmp{:});
nPerAmp     = cellfun(@numel, imp.Peak_imp);
groupLabels = repelem(string(cell2mat(imp.uAmp(:))), nPerAmp(:));

allExperiments(expIdx).mn = mn;
allExperiments(expIdx).td = td;
allExperiments(expIdx).en = en;
allExperiments(expIdx).allVals = allVals;
allExperiments(expIdx).groupLabels = groupLabels;
allExperiments(expIdx).imp = imp;
allExperiments(expIdx).DF_imp = DF_imp;
allExperiments(expIdx).uAmp      = uAmp;
allExperiments(expIdx).dF        = dF;
allExperiments(expIdx).timeBlue  = d.timeBlue;
allExperiments(expIdx).mv_z          = mv_z;
allExperiments(expIdx).freqBandCtrs  = freqBandCtrs;
allExperiments(expIdx).brainMask     = brainMask_e;
allExperiments(expIdx).mimg          = mimg;
allExperiments(expIdx).mI1           = mI(1);

end  % End of experiment loop

%% Single-session trace overlay — session 3
close all;
imp3  = allExperiments(3).imp;
uAmp3 = allExperiments(3).uAmp;
mn3   = allExperiments(3).mn;
td3   = allExperiments(3).td;
en3   = allExperiments(3).en;

PW_s = 5; PH_s = 4;
figS = figure('Color','w');
figS.Units = 'centimeters';  figS.PaperUnits = 'centimeters';
figS.Position = [0 0 PW_s PH_s];
figS.PaperSize = [PW_s PH_s];  figS.PaperPosition = [0 0 PW_s PH_s];
hold on;
for i = 1:length(uAmp3)
    if mod(i,2)==1 && ~isempty(imp3.dfImp{i})
        plot(0, 0.75, 'ro','MarkerSize',5,'MarkerFaceColor','red','HandleVisibility','off');
        plot(t_win, mean(imp3.dfImp{i}), ...
            'Color',[1-(0.1*i),(1-0.1*i),(1-0.1*i)],'LineWidth',2, ...
            'DisplayName', sprintf('%.2f mW', uAmp3(i)/3));
    end
end
xlim([-1,1])
lgd = legend('Box','off','FontSize',6,'FontWeight','bold','Location','southeast');
lgd.ItemTokenSize = [6 6];
shortCornerAxes_plot(gca,'XLength',0.5,'YLength',1,'XLabel','500 ms', ...
    'YLabel','1% dF/F','LineWidth',2,'LabelGap',0.05);
text(0.1, 1.5, 'Stim','Color','r','FontSize',7,'FontWeight','bold', ...
    'HorizontalAlignment','right','VerticalAlignment','top','Clipping','off');
print(figS, sprintf('paper/images/figure2/imp_single_%s_%s_en%d.pdf',mn3,td3,en3), '-dpdf','-painters');


%%

%% Combined plot for all experiments
close all;

expColors = [0.2 0.4 0.8; 0.8 0.2 0.2; 0.2 0.8 0.4];

PW_c = 5; PH_c = 4;
fig = figure('Color','w'); hold on
fig.Units = 'centimeters';  fig.PaperUnits = 'centimeters';
fig.Position = [0 0 PW_c PH_c];
fig.PaperSize = [PW_c PH_c];  fig.PaperPosition = [0 0 PW_c PH_c];
h1 = yline(0,'--k');
ax_c = gca;

nExp = numel(allExperiments);
hLegend = gobjects(nExp,1);              % one legend entry per experiment
legTxt  = cell(nExp,1);

fprintf('\n--- Dose-response linear fits (mean ± SEM) ---\n');
for expIdx = 1:nExp
    allVals = allExperiments(expIdx).allVals;
    groupLabels = allExperiments(expIdx).groupLabels;

    [ug,~,idx] = unique(groupLabels, 'stable');
    meanVals = accumarray(idx(:), allVals(:), [], @(v) mean(v,'omitnan'));
    semVals  = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan')/sqrt(sum(~isnan(v))));

    xpos_raw = str2double(cellstr(ug))';
    nzMask   = xpos_raw > 0;          % exclude 0-amp gap-fill markers (not real laser trials)
    meanVals = meanVals(nzMask);
    semVals  = semVals(nzMask);
    xpos     = xpos_raw(nzMask) + (expIdx - 2) * 0.005;
    capWidth = 0.003;

    for j = 1:numel(xpos)
        plot([xpos(j) xpos(j)], [meanVals(j)-semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)-semVals(j), meanVals(j)-semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)+semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot(xpos(j), meanVals(j), 'o', 'MarkerSize', 1.5, ...
            'MarkerFaceColor', expColors(expIdx,:), ...
            'MarkerEdgeColor', expColors(expIdx,:), ...
            'LineWidth', 2);
    end

    % Fit line through means for this experiment
    p  = polyfit(xpos, meanVals, 1);
    xf = linspace(min(xpos)-0.02, max(xpos)+0.02, 100);

    hLegend(expIdx) = plot(xf, polyval(p,xf), '-', 'LineWidth', 2.0, ...
        'Color', expColors(expIdx,:));

    legTxt{expIdx} = sprintf('Session %d',expIdx);

    % R² for this linear fit
    yfit   = polyval(p, xpos);
    SS_res = sum((meanVals(:) - yfit(:)).^2);
    SS_tot = sum((meanVals(:) - mean(meanVals)).^2);
    R2_e   = 1 - SS_res / max(SS_tot, eps);
    fprintf('  Session %d: slope=%.4f dF%%/V,  R²=%.3f\n', expIdx, p(1), R2_e);
    text(ax_c, 0.5, 0.05 + 0.12*(expIdx-1), ...
        sprintf('S%d: m=%.3f, R²=%.2f', expIdx, p(1), R2_e), ...
        'Units','normalized', 'FontSize',5, 'Color',expColors(expIdx,:), ...
        'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
end

% Beautify
ax = gca;
ax.LineWidth = 1.5;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.FontWeight = 'bold';
ax.TickDir = 'out';
ax.Box = 'off';
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
ylim([-5 3])
uistack(h1, 'bottom')
xticks([])

try
    % shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','mW','YLabel',' ', ...
    %     'LineWidth',3,'LabelGap',0.05);
    shortCornerAxes_plot(gca,'XLength',2,'YLength',0.01,'XLabel','0.5 mW', ...
    'YLabel',' ','LineWidth',2,'LabelGap',0.05);
catch
    xlabel('Input(V)', 'FontWeight','bold');
    ylabel('dF/F %', 'FontWeight','bold');
end

% Legend (clean neuro style)
lgd = legend(ax, hLegend, legTxt, 'Box','off','Color','none','FontSize',6);
lgd.ItemTokenSize = [10 6];
lgd.AutoUpdate = 'off';
text(ax, -0.12, 0.5, 'Inhibition Energy', ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',7, 'FontWeight','bold', 'Color','k', 'Clipping','off');
print(fig, 'paper/images/figure2/imp_response.pdf', '-dpdf', '-painters');

%% Combined plot — median ± 95th-percentile bounds
figM = figure('Color','w'); hold on
figM.Units = 'centimeters';  figM.PaperUnits = 'centimeters';
figM.Position = [0 0 PW_c PH_c];
figM.PaperSize = [PW_c PH_c];  figM.PaperPosition = [0 0 PW_c PH_c];
h1m = yline(0,'--k');
ax_mc = gca;

hLegendM = gobjects(nExp,1);
legTxtM   = cell(nExp,1);

fprintf('\n--- Dose-response linear fits (median ± 95th-pctile bounds) ---\n');
for expIdx = 1:nExp
    allVals_e     = allExperiments(expIdx).allVals;
    groupLabels_e = allExperiments(expIdx).groupLabels;

    [ug_m,~,idx_m] = unique(groupLabels_e, 'stable');
    medVals = accumarray(idx_m(:), allVals_e(:), [], @(v) median(v,'omitnan'));
    p2_5    = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v, 2.5));
    p97_5   = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v, 97.5));

    xpos_raw_m = str2double(cellstr(ug_m))';
    nzMask_m   = xpos_raw_m > 0;          % exclude 0-amp gap-fill markers
    medVals    = medVals(nzMask_m);
    p2_5       = p2_5(nzMask_m);
    p97_5      = p97_5(nzMask_m);
    xpos_m     = xpos_raw_m(nzMask_m) + (expIdx - 2) * 0.005;
    ug_m       = ug_m(nzMask_m);
    capWidth_m = 0.003;

    for j = 1:numel(ug_m)
        plot([xpos_m(j) xpos_m(j)], [p2_5(j), p97_5(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [p2_5(j) p2_5(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [p97_5(j) p97_5(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot(xpos_m(j), medVals(j), 'o', 'MarkerSize', 1, ...
            'MarkerFaceColor', expColors(expIdx,:), ...
            'MarkerEdgeColor', expColors(expIdx,:), 'LineWidth', 2);
    end

    p_m  = polyfit(xpos_m, medVals, 1);
    xf_m = linspace(min(xpos_m)-0.02, max(xpos_m)+0.02, 100);
    hLegendM(expIdx) = plot(xf_m, polyval(p_m,xf_m), '-', 'LineWidth', 1.5, ...
        'Color', expColors(expIdx,:));
    legTxtM{expIdx} = sprintf('Session %d', expIdx);

    % R² for this linear fit
    yfit_m   = polyval(p_m, xpos_m);
    SS_res_m = sum((medVals(:) - yfit_m(:)).^2);
    SS_tot_m = sum((medVals(:) - mean(medVals)).^2);
    R2_m     = 1 - SS_res_m / max(SS_tot_m, eps);
    fprintf('  Session %d: slope=%.4f dF%%/V,  R²=%.3f\n', expIdx, p_m(1), R2_m);
    text(ax_mc, 0.5, 0.05 + 0.12*(expIdx-1), ...
        sprintf('S%d: m=%.3f, R²=%.2f', expIdx, p_m(1), R2_m), ...
        'Units','normalized', 'FontSize',5, 'Color',expColors(expIdx,:), ...
        'FontWeight','bold', 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
end

ax_m = gca;
ax_m.LineWidth = 1.5;  ax_m.FontName = 'Arial';  ax_m.FontSize = 7;
ax_m.FontWeight = 'bold';  ax_m.TickDir = 'out';  ax_m.Box = 'off';
ylim([-5 3]);  xticks([]);
uistack(h1m, 'bottom');
try
    shortCornerAxes_plot(ax_m,'XLength',1,'YLength',0.01,'XLabel','0.3 mW', ...
        'YLabel',' ','LineWidth',2,'LabelGap',0.05);
catch
    xlabel('Input(V)','FontWeight','bold');  ylabel('dF/F %','FontWeight','bold');
end
lgd_m = legend(ax_m, hLegendM, legTxtM, 'Box','off','Color','none','FontSize',6);
lgd_m.ItemTokenSize = [10 6];
lgd_m.AutoUpdate = 'off';
text(ax_m, -0.12, 0.5, 'Inhibition Energy', ...
    'Units','normalized', 'Rotation',90, ...
    'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontSize',7, 'FontWeight','bold', 'Color','k', 'Clipping','off');
exportgraphics(figM, 'paper/imp_response_median.png', 'Resolution',300);

%%
%% =========================================================
%  TF FIT — all amplitudes, session mean
%  Knobs: selExp, nPoles (1 or 2), nLeads (0 or 1)
%  nLeads=1 adds one numerator zero → response can start at t=0
%  (more responsive / faster onset)
%% =========================================================

selExp   = 3;        % <-- target session
maxPoles = 3;        % <-- sweep 1..maxPoles
maxZeros = 3;        % <-- sweep 0..min(np-1, maxZeros)
maxDelay = 0;        % <-- sweep 0..maxDelay samples (~0..143 ms at 35 Hz)
tFit_s   = 0.5;     % <-- post-stim fit window end (s); increase for strong-amp tails
fig_A_amps_mW = [0, 0.7, 1.63];  % <-- mW values to plot in Fig A; [] = auto (smallest/mid/largest)

DF_s   = allExperiments(selExp).DF_imp;
uA_s   = allExperiments(selExp).uAmp(:);
nAmp_s = numel(uA_s);

% Post-stim fit window: 0 to tFit_s (set above; use tWin for full available range)
t_full = -tWin : 1/fs : tWin;
iPost  = find(t_full >= 0 & t_full <= tFit_s);
tPost  = t_full(iPost)';
Ts     = 1/fs;

% Normalise each amplitude by its input voltage → all collapse to h(t)
% Exclude zero-amplitude rows (inserted missing-event placeholders)
% Weight by amplitude^2 so stronger inputs dominate the fitted time constants
% (unweighted mean biases poles toward weak-amp shape; stronger amps have longer tails)
validAmp = uA_s > 0;
w_amp    = uA_s(validAmp).^2;
w_amp    = w_amp / sum(w_amp);
h_rows   = bsxfun(@rdivide, DF_s(validAmp, iPost), uA_s(validAmp));
h_norm   = sum(bsxfun(@times, h_rows, w_amp), 1, 'omitnan')';
validT_h = isfinite(h_norm);   % guards against NaN and Inf
nT_h     = sum(validT_h);

% Single iddata: unit impulse in, normalised response out
% Prepend nPre zeros (toolbox requirement for transient data)
nPre    = maxPoles + maxZeros + 2;
u_fit   = [zeros(nPre,1); 1; zeros(nT_h-1, 1)];
y_fit   = [zeros(nPre,1); h_norm(validT_h)];
data_fit = iddata(y_fit, u_fit, Ts);
data_fit.Tstart = -nPre * Ts;   % shift so t=0 is the impulse, not the start of the prepended zeros

% Sweep over (np, nz): strictly proper → nz < np
tfOpt    = tfestOptions('EnforceStability', false, 'Display', 'off');
allMdls  = {};
mdlNames = {};
res      = struct('np',{},'nz',{},'nd',{},'AIC',{},'FPE',{},'sys',{});
ri       = 0;
for nd = 0:maxDelay
    for np = 1:maxPoles
        for nz = 0:min(np-1, maxZeros)
            try
                sys_i = tfest(data_fit, np, nz, tfOpt, 'InputDelay', nd*Ts);
                ri = ri + 1;
                res(ri).np  = np;
                res(ri).nz  = nz;
                res(ri).nd  = nd;
                res(ri).AIC = aic(sys_i);
                res(ri).FPE = fpe(sys_i);
                res(ri).sys = sys_i;
                allMdls{end+1}  = sys_i; %#ok<SAGROW>
                mdlNames{end+1} = sprintf('%dp%dz%dd', np, nz, nd); %#ok<SAGROW>
            catch ME
                fprintf('  tfest(%dp%dz%dd) failed: %s\n', np, nz, nd, ME.message);
            end
        end
    end
end

if isempty(res)
    error('tfest failed — check that System Identification Toolbox is installed.');
end

% Toolbox compare on the normalised trace
figure('Name', sprintf('Session %d — model comparison', selExp));
compare(data_fit, allMdls{:});
legend(mdlNames{:}, 'Location','best');

% Select best by AIC
[~, iBest] = min([res.AIC]);
best_sys = res(iBest).sys;

fprintf('\nSession %d — TF order selection:\n', selExp);
fprintf('  np  nz  nd     AIC       FPE\n');
for r = 1:numel(res)
    mk = ''; if r == iBest, mk = '  <-- best'; end
    fprintf('  %d   %d   %d  %8.2f  %10.4f%s\n', res(r).np, res(r).nz, res(r).nd, res(r).AIC, res(r).FPE, mk);
end
fprintf('Best: %dp/%dz/%dd (delay=%.0f ms)\n', res(iBest).np, res(iBest).nz, res(iBest).nd, res(iBest).nd*Ts*1000);
[num_tf, den_tf] = tfdata(best_sys, 'v');
fprintf('  Num: [%s]\n', num2str(num_tf, '%.4g  '));
fprintf('  Den: [%s]\n', num2str(den_tf, '%.4g  '));
if best_sys.InputDelay > 0
    fprintf('  Input delay: %.1f ms\n', best_sys.InputDelay * 1000);
end

% ── Residual analysis ─────────────────────────────────────
% Autocorrelation of residuals + cross-correlation with input.
% Significant spikes outside the confidence bounds → model is missing structure.
figure('Name', sprintf('Session %d — residual analysis', selExp));
resid(data_fit, best_sys);

% Per-amplitude predictions using toolbox sim()
R2_all = nan(nAmp_s,1);
yp_all = cell(nAmp_s,1);
for iAmp = 1:nAmp_s
    y_i    = DF_s(iAmp, iPost)';
    validT = ~isnan(y_i);
    if sum(validT) < 5, continue; end
    nT  = sum(validT);
    % simulate unit impulse response, scale by input amplitude
    u_unit = [zeros(nPre,1); 1; zeros(nT-1, 1)];
    yp_obj = sim(best_sys, iddata([], u_unit, Ts));
    yp_i   = uA_s(iAmp) * yp_obj.OutputData(nPre+1:end);
    SS_res = sum((y_i(validT) - yp_i).^2);
    SS_tot = sum((y_i(validT) - mean(y_i(validT))).^2);
    R2_all(iAmp) = 1 - SS_res / max(SS_tot, eps);
    yp_full = nan(size(tPost));
    yp_full(validT) = yp_i;
    yp_all{iAmp} = yp_full;
    fprintf('  amp=%.2fV  R²=%.3f\n', uA_s(iAmp), R2_all(iAmp));
end

% ── Figure: one subplot per amplitude ────────────────────
nCols = min(nAmp_s, 4);
nRows = ceil(nAmp_s / nCols);
figure('Color','w','Position',[60 80 260*nCols 240*nRows]);
tlo_tf = tiledlayout(nRows, nCols, 'TileSpacing','compact','Padding','compact');
tfStr = sprintf('Session %d — best TF: %dp/%dz/%dd  (AIC=%.1f)', ...
    selExp, res(iBest).np, res(iBest).nz, res(iBest).nd, res(iBest).AIC);
title(tlo_tf, tfStr, 'FontWeight','bold','FontSize',9);

cMap = parula(nAmp_s);
for iAmp = 1:nAmp_s
    ax = nexttile(tlo_tf);  hold(ax,'on');

    % individual trials (gray)
    df_trials = allExperiments(selExp).imp.dfImp{iAmp}(:, iPost);
    validT = ~isnan(DF_s(iAmp, iPost)');
    for k = 1:size(df_trials,1)
        plot(ax, tPost(validT), df_trials(k,validT), '-', ...
            'Color',[0.8 0.8 0.8],'LineWidth',0.4,'HandleVisibility','off');
    end

    % mean
    y_data = DF_s(iAmp, iPost)';
    plot(ax, tPost(validT), y_data(validT), '-', ...
        'Color', cMap(iAmp,:), 'LineWidth',2, 'DisplayName','Mean');

    % fit
    if ~isempty(yp_all{iAmp})
        plot(ax, tPost(validT), yp_all{iAmp}(validT), 'k--', ...
            'LineWidth',1.5, 'DisplayName',sprintf('R²=%.2f', R2_all(iAmp)));
    end

    title(ax, sprintf('%.2f V  R²=%.2f', uA_s(iAmp), R2_all(iAmp)), 'FontSize',8);
    xlabel(ax,'Time (s)');
    if iAmp==1, ylabel(ax,'dF/F (%)'); end
    legend(ax,'Box','off','FontSize',7,'Location','best');
    set(ax,'Box','off','TickDir','out','FontSize',8);
end

%% ── LOAO validation ──────────────────────────────────────
% Leave-one-amplitude-out: for each amplitude, refit h_norm on the remaining
% amplitudes, then predict the held-out amplitude and record R².
% A drop in R² relative to the full-fit value reveals amplitude-dependent dynamics.

validIdx  = find(validAmp);          % indices into uA_s that were used in h_norm
nValid    = numel(validIdx);
R2_loao   = nan(nAmp_s, 1);

fprintf('\nLOAO validation (session %d):\n', selExp);
fprintf('  amp(V)   R²_full   R²_loao\n');

for iLeave = 1:nValid
    iAmp_lo  = validIdx(iLeave);     % amplitude index being held out
    trainIdx = validIdx([1:iLeave-1, iLeave+1:end]);

    % Recompute amplitude-weighted h_norm without the held-out amplitude
    w_lo   = uA_s(trainIdx).^2;
    w_lo   = w_lo / sum(w_lo);
    h_rows_lo = bsxfun(@rdivide, DF_s(trainIdx, iPost), uA_s(trainIdx));
    h_norm_lo = sum(bsxfun(@times, h_rows_lo, w_lo), 1, 'omitnan')';
    validT_lo = isfinite(h_norm_lo);
    nT_lo     = sum(validT_lo);
    if nT_lo < maxPoles + 2, continue; end

    % Fit best-order model (same np/nz/nd as full best) on leave-out data
    u_lo   = [zeros(nPre,1); 1; zeros(nT_lo-1,1)];
    y_lo   = [zeros(nPre,1); h_norm_lo(validT_lo)];
    d_lo   = iddata(y_lo, u_lo, Ts);
    d_lo.Tstart = -nPre * Ts;
    try
        sys_lo = tfest(d_lo, res(iBest).np, res(iBest).nz, tfOpt, ...
                       'InputDelay', res(iBest).nd * Ts);
    catch
        continue;
    end

    % Predict held-out amplitude
    y_ho   = DF_s(iAmp_lo, iPost)';
    validT_ho = ~isnan(y_ho);
    if sum(validT_ho) < 5, continue; end
    nT_ho  = sum(validT_ho);
    u_ho   = [zeros(nPre,1); 1; zeros(nT_ho-1,1)];
    yp_obj = sim(sys_lo, iddata([], u_ho, Ts));
    yp_ho  = uA_s(iAmp_lo) * yp_obj.OutputData(nPre+1:end);
    SS_res = sum((y_ho(validT_ho) - yp_ho).^2);
    SS_tot = sum((y_ho(validT_ho) - mean(y_ho(validT_ho))).^2);
    R2_loao(iAmp_lo) = 1 - SS_res / max(SS_tot, eps);

    fprintf('  %.2f      %.3f     %.3f\n', uA_s(iAmp_lo), R2_all(iAmp_lo), R2_loao(iAmp_lo));
end

% ── LOAO summary figure ───────────────────────────────────
figure('Color','w','Position',[100 100 400 300]); hold on;
validPlot = ~isnan(R2_loao);
plot(uA_s(validPlot), R2_all(validPlot),  'o-', 'Color',[0.2 0.4 0.8], ...
    'LineWidth',1.5, 'MarkerFaceColor',[0.2 0.4 0.8], 'DisplayName','Full fit');
plot(uA_s(validPlot), R2_loao(validPlot), 's--','Color',[0.8 0.2 0.2], ...
    'LineWidth',1.5, 'MarkerFaceColor',[0.8 0.2 0.2], 'DisplayName','LOAO');
xlabel('Amplitude (V)'); ylabel('R²');
title(sprintf('Session %d — LOAO validation', selExp), 'FontWeight','bold');
legend('Box','off','Location','best');
set(gca,'Box','off','TickDir','out');
ylim([0 1]);

%% ── Paper Fig A: TF data vs model ────────────────────────
% Smallest, middle, largest amplitude: session mean (color) + TF fit (black dash).
% Pre-trial baseline shown to the left of t = 0.

preWin_A = 0.2;                                          % seconds of pre-stim baseline to show
iWin_A   = find(t_full >= -preWin_A & t_full <= tFit_s);
tWin_A   = t_full(iWin_A);

vIdx = find(validAmp);
nV   = numel(vIdx);
fprintf('Session %d available amplitudes (mW): %s\n', selExp, num2str(uA_s(:)'/3, '%.2f  '));
if ~isempty(fig_A_amps_mW)
    tol = 0.5;   % mW tolerance for nearest-amplitude match
    repAmpIdx = [];
    for tgt = fig_A_amps_mW
        [d_match, ii] = min(abs(uA_s/3 - tgt));
        if d_match <= tol
            repAmpIdx(end+1) = ii; 
        else
            fprintf('  WARNING: no amplitude within %.2f mW of %.2f mW (closest: %.2f mW)\n', tol, tgt, uA_s(ii)/3);
        end
    end
elseif nV >= 3
    repAmpIdx = vIdx([1, round(nV/2), nV]);
elseif nV == 2
    repAmpIdx = vIdx([1, nV]);
else
    repAmpIdx = vIdx;
end
nRep = numel(repAmpIdx);
cRep = parula(nRep + 2);

PS = paperStyle();
fig_A = paperFig(6, 4);
hold on;
ax_A  = gca;

for k = 1:nRep
    iAmp   = repAmpIdx(k);
    y_data = DF_s(iAmp, iWin_A)';
    validT = ~isnan(y_data);

    plot(ax_A, tWin_A(validT), y_data(validT), '-', ...
        'Color', cRep(k,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%.2f mW', uA_s(iAmp)/3));

    % TF model prediction — same color as mean trace, dashed; out of legend
    if ~isempty(yp_all{iAmp})
        validPost = ~isnan(DF_s(iAmp, iPost)');
        plot(ax_A, tPost(validPost), yp_all{iAmp}(validPost), '--', ...
            'Color', cRep(k,:), 'LineWidth', 1.5, 'HandleVisibility','off');
    end
end

% Single neutral legend entry — gray dash explains the dashed style
plot(ax_A, nan, nan, '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.5, 'DisplayName', 'TF Pred');

% Stim onset marker (vertical line at t = 0)
yl_A = ylim(ax_A);
yTop = max(yl_A(2), 0.5);
ylim(ax_A, [yl_A(1), yTop]);
line(ax_A, [0 0], [yl_A(1), yTop * 0.85], 'Color','r', 'LineWidth', 0.75, 'HandleVisibility','off');
text(ax_A, 0.02, yTop, 'Stim', 'Color','r', 'FontSize',6, 'FontWeight','bold', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top', 'Clipping','off');

shortCornerAxes_plot(ax_A, 'XLength',0.15,'YLength',1,'XLabel','150 ms','YLabel','1% dF/F', ...
    'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);

lgd_A = legend(ax_A, 'Box','off','FontSize',6,'FontWeight','bold','Location','southeast');
lgd_A.ItemTokenSize = [15 10];
lgd_A.AutoUpdate = 'off';

exportgraphics(fig_A, sprintf('paper/images/figure2/tf_data_vs_model_%s_%s_en%d.pdf', ...
    allExperiments(selExp).mn, allExperiments(selExp).td, allExperiments(selExp).en), ...
    'ContentType','vector');

%% ── Paper Fig B: LOAO validation ─────────────────────────
% Full-fit R² (filled circles) vs LOAO R² (open squares) across amplitudes

validBoth = validAmp & ~isnan(R2_loao);
xAmp_B    = uA_s(validBoth) / 3;   % V → mW
r2Full_B  = R2_all(validBoth);
r2Loao_B  = R2_loao(validBoth);

if isempty(xAmp_B)
    warning('tf_loao: no amplitudes with both R2_full and R2_loao — skipping figure.');
else
    fig_B = paperFig(4, 4);
    hold on;
    ax_B  = gca;

    plot(ax_B, xAmp_B, r2Full_B, 'o-', ...
        'Color', [0.2 0.4 0.8], 'LineWidth', 1.5, ...
        'MarkerSize', 4, 'MarkerFaceColor', [0.2 0.4 0.8], ...
        'DisplayName', 'Full fit');
    plot(ax_B, xAmp_B, r2Loao_B, 's--', ...
        'Color', [0.8 0.2 0.2], 'LineWidth', 1.5, ...
        'MarkerSize', 4, 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', [0.8 0.2 0.2], ...
        'DisplayName', 'LOAO');

    ylim(ax_B, [0, 1]);
    yline(ax_B, 1, '--k', 'LineWidth', 0.75, 'HandleVisibility','off');

    xRange_B = max(xAmp_B) - min(xAmp_B);
    xLen_B   = max(0.1, round(xRange_B / 2, 1));

    shortCornerAxes_plot(ax_B, 'XLength',xLen_B,'YLength',0.5, ...
        'XLabel',sprintf('%.1f mW', xLen_B),'YLabel','0.5 R^2', ...
        'LineWidth',PS.sca_lw,'LabelGap',PS.sca_gap,'FontSize',PS.fs,'FontWeight',PS.fw);

    lgd_B = legend(ax_B, 'Box','off','FontSize',6,'FontWeight','bold','Location','southwest');
    lgd_B.ItemTokenSize = [6 6];
    lgd_B.AutoUpdate = 'off';

    % exportgraphics(fig_B, sprintf('paper/images/figure2/tf_loao_%s_%s_en%d.pdf', ...
    %     allExperiments(selExp).mn, allExperiments(selExp).td, allExperiments(selExp).en), ...
    %     'ContentType','vector');
end

%% Motion analysis parameters — set integration window here before running analysis sections
% Motion energy is recomputed on-the-fly from the stored motTrace (±3 s).
% Change motWin_ana / motThr_lo / motThr_hi; both sections below will use them.

motWin_ana     = [-1.0, 0.5];   % [start, end] in seconds relative to stim onset
motThr_lo      = -0.5;          % mean z-score: Low | Mid boundary
motThr_hi      =  0.5;          % mean z-score: Mid | High boundary
tertertColors_motot = [0.20 0.40 0.80;   % Low  — blue
                  0.55 0.25 0.75;   % Mid  — purple
                  0.85 0.20 0.20];  % High — red
tLabels_m      = {'Low motion', 'Mid motion', 'High motion'};

%% Motion vs Peak_imp deviation — one figure per session, subplots per amp
%
% X: mean z-scored motion over motWin_ana (comparable across sessions)
% Y: |Peak_imp − mean(Peak_imp)| for that amp group  (imp.Peak_imp_dev)
% Dots coloured by Low/Mid/High using motThr_lo / motThr_hi from parameter cell.
% Click any dot → motionDetailCallback opens dF/F + motion trace for that trial.

nExp      = numel(allExperiments);
t_win_mot = -tWin : 1/35 : tWin;   % full ±3 s — matches dfImp / motTrace column count
iMot_a    = t_win_mot >= motWin_ana(1) & t_win_mot <= motWin_ana(2);

for expIdx = 1:nExp
    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    % Compute shared x/y limits across all amps for this experiment
    xAll_m = []; yAll_m = [];
    for iA = 1:nAmp_e
        xAll_m = [xAll_m; mean(imp_e.motTrace{iA}(:, iMot_a), 2)]; %#ok<AGROW>
        yAll_m = [yAll_m; imp_e.Peak_imp_dev{iA}(:)];              %#ok<AGROW>
    end
    xAll_m = xAll_m(isfinite(xAll_m)); yAll_m = yAll_m(isfinite(yAll_m));
    xPad   = 0.05 * (max(xAll_m) - min(xAll_m));
    yPad   = 0.05 * max(yAll_m);
    xLim_m = [min(xAll_m) - xPad,  max(xAll_m) + xPad];
    yLim_m = [0,                    max(yAll_m) + yPad];

    nCols_m = min(nAmp_e, 4);
    nRows_m = ceil(nAmp_e / nCols_m);

    fig_m = figure('Color','w');
    fig_m.Units    = 'inches';
    fig_m.Position = [1, 1, nCols_m*3, nRows_m*3];
    sgtitle(sprintf('%s  %s  e%d  [click dot for detail]', allExperiments(expIdx).mn, ...
        allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 10, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        dev_i  = imp_e.Peak_imp_dev{iAmp}(:);
        nUse   = min(size(imp_e.motTrace{iAmp}, 1), numel(dev_i));
        if nUse < 2, continue; end
        mot_i  = mean(imp_e.motTrace{iAmp}(1:nUse, iMot_a), 2);
        dev_i  = dev_i(1:nUse);
        tert_i = 1 + (mot_i >= motThr_lo) + (mot_i > motThr_hi);

        ax = subplot(nRows_m, nCols_m, iAmp);
        hold(ax, 'on');
        hS = [];
        for k = 1:3
            mk = tert_i == k;
            if ~any(mk), continue; end
            hS = scatter(ax, mot_i(mk), dev_i(mk), 25, tertertColors_motot(k,:), ...
                'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', tLabels_m{k});
        end

        r = corr(mot_i, dev_i, 'rows','complete');
        title(ax, sprintf('%.2f V   (n=%d,  r=%.2f)', imp_e.uAmp{iAmp}, nUse, r), ...
            'FontSize', 8, 'FontWeight','bold');
        xlabel(ax, sprintf('Mean motion z-score (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), 'FontSize', 8);
        ylabel(ax, 'Prediction error', 'FontSize', 8);
        lg = legend(ax, 'Box','off', 'FontSize', 7, 'Location','best');
        lg.ItemTokenSize = [6 6];
        set(ax, 'Box','off', 'TickDir','out', 'FontSize', 8);
        xlim(ax, xLim_m);
        ylim(ax, yLim_m);

        % Capture per-iteration values for the closure
        c_ax   = ax;
        c_mot  = mot_i;
        c_dev  = dev_i;
        c_imp  = imp_e;
        c_iAmp = iAmp;
        c_twin = t_win_mot;
        if ~isempty(hS)
            set(hS, 'ButtonDownFcn', ...
                @(~,~) motionDetailCallback(c_ax, c_mot, c_dev, c_imp, c_iAmp, c_twin));
        end
    end
end

%% Motion-sorted figures — pooled amps, session selExp_mot
%
% Figure 1: trials sorted by motion (Y), |Peak_imp − mean| (X), two classes.
% Figure 2: mean motion z-score (X) vs |Peak_imp − mean| (Y), two classes.
%
% Classification: No motion (mean z ≤ motThr_hi) vs Motion (mean z > motThr_hi).
% motThr_hi is set in the parameters cell above.

selExp_mot = 3;

imp_e_mot  = allExperiments(selExp_mot).imp;
nAmp_mot   = numel(imp_e_mot.uAmp);
mn_mot     = allExperiments(selExp_mot).mn;
td_mot     = allExperiments(selExp_mot).td;
en_mot     = allExperiments(selExp_mot).en;

t_full_mot = -tWin : 1/35 : tWin;
iMot_a     = t_full_mot >= motWin_ana(1) & t_full_mot <= motWin_ana(2);
iCrop_new  = find(t_full_mot >= -2 & t_full_mot <= 2);   % for legacy pool loop

binColors_m = [0.30 0.55 0.85; 0.85 0.20 0.20];   % No motion — blue; Motion — red
binLabels_m = {'No motion', 'Motion'};

% --- Pooled data prep ---
allAbsDev_m = [];
allMot_m    = [];

for iAmp = 1:nAmp_mot
    df_i  = imp_e_mot.dfImp{iAmp};
    pk_i  = imp_e_mot.Peak_imp{iAmp}(:);
    mn_i  = mean(pk_i, 'omitnan');
    nUse  = min([size(df_i, 1), numel(pk_i), size(imp_e_mot.motTrace{iAmp}, 1)]);
    if nUse < 2, continue; end
    mot_i = mean(imp_e_mot.motTrace{iAmp}(1:nUse, iMot_a), 2);
    allAbsDev_m = [allAbsDev_m; abs(pk_i(1:nUse) - mn_i)];  %#ok<AGROW>
    allMot_m    = [allMot_m;    mot_i];                       %#ok<AGROW>
end

[~, si_m]      = sort(allMot_m, 'ascend');
absDevSorted_m = allAbsDev_m(si_m);
motSorted_m    = allMot_m(si_m);

motBin_m     = (allMot_m    > motThr_hi) + 1;   % 1 = No motion, 2 = Motion
motBinSort_m = (motSorted_m > motThr_hi) + 1;

% --- Legacy pool loop (used by poster figure and pre-trial variance sections) ---
allDF_n   = [];
allMot_n  = [];
ampIdx_n  = [];
devNorm_n = [];
for iAmp = 1:nAmp_mot
    df_i  = imp_e_mot.dfImp{iAmp};
    pk_i  = imp_e_mot.Peak_imp{iAmp}(:);
    mn_i  = imp_e_mot.Peak_imp_mean(iAmp);
    if isnan(mn_i) || mn_i == 0, continue; end
    nUse  = min([size(df_i, 1), numel(pk_i), size(imp_e_mot.motTrace{iAmp}, 1)]);
    mot_i = mean(imp_e_mot.motTrace{iAmp}(1:nUse, iMot_a), 2);
    allDF_n   = [allDF_n;   df_i(1:nUse, iCrop_new) / abs(mn_i)];  %#ok<AGROW>
    allMot_n  = [allMot_n;  mot_i];                                  %#ok<AGROW>
    ampIdx_n  = [ampIdx_n;  repmat(iAmp, nUse, 1)];                 %#ok<AGROW>
    devNorm_n = [devNorm_n; abs(pk_i(1:nUse) - mn_i) / abs(mn_i)];  %#ok<AGROW>
end

% ---- Figure 1: trial rank (sorted by motion) vs |Peak dev| ----
[rA_m, pA_m] = corr(allMot_m, allAbsDev_m, 'rows', 'complete');

fig_ad = paperFig(6, 6);
ax_ad  = axes(fig_ad);
hold(ax_ad, 'on');
for k = 1:2
    mk = motBinSort_m == k;
    scatter(ax_ad, absDevSorted_m(mk), find(mk), 6, ...
        binColors_m(k, :), 'filled', 'MarkerFaceAlpha', 0.6, ...
        'DisplayName', binLabels_m{k});
end
hl_a0 = xline(ax_ad, 0, 'k-', 'LineWidth', 0.5); hl_a0.HandleVisibility = 'off';
title(ax_ad, sprintf('r = %.2f  p = %.3f', rA_m, pA_m), ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_ad, '|Peak dev| (\DeltaF/F %)',  'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_ad, sprintf('Trial (sorted by motion, %.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), ...
    'FontSize', 6, 'FontWeight', 'bold');
lg_ad = legend(ax_ad, 'Location', 'best', 'FontSize', 6);
lg_ad.ItemTokenSize = [6 6];
set(ax_ad, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'YDir', 'normal');
hold(ax_ad, 'off');

% ---- Figure 2: mean motion z-score vs |Peak dev| scatter ----
fig_mv = paperFig(6, 4);
ax_mv  = axes(fig_mv);
hold(ax_mv, 'on');
for k = 1:2
    mk = motBin_m == k;
    scatter(ax_mv, allMot_m(mk), allAbsDev_m(mk), 6, ...
        binColors_m(k, :), 'filled', 'MarkerFaceAlpha', 0.5, ...
        'DisplayName', binLabels_m{k});
end
hl_mv = xline(ax_mv, motThr_hi, 'k--', 'LineWidth', 0.8); hl_mv.HandleVisibility = 'off';
% title(ax_mv, sprintf('r = %.2f  p = %.3f', rA_m, pA_m), ...
    % 'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_mv, sprintf('Mean motion z-score (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_mv, '|Peak dev| (\DeltaF/F %)',  'FontSize', 6, 'FontWeight', 'bold');
lg_mv = legend(ax_mv, 'Location', 'best', 'FontSize', 6);
lg_mv.ItemTokenSize = [6 6];
set(ax_mv, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
hold(ax_mv, 'off');
exportgraphics(fig_mv, ...
    sprintf('paper/images/figure2/imp_motion_devscatter_%s_%s_en%d.pdf', mn_mot, td_mot, en_mot), ...
    'ContentType', 'vector');

% ---- Figure 2 (pooled all sessions): motion z-score vs |Peak dev| ----
% colour = session (expColors); marker = o no-motion, ^ motion
allAbsDev_pool = [];
allMot_pool    = [];
allExp_pool    = [];

for expIdx = 1:nExp
    imp_e_p  = allExperiments(expIdx).imp;
    nAmp_p   = numel(imp_e_p.uAmp);
    for iAmp = 1:nAmp_p
        df_i  = imp_e_p.dfImp{iAmp};
        pk_i  = imp_e_p.Peak_imp{iAmp}(:);
        mn_i  = mean(pk_i, 'omitnan');
        nUse  = min([size(df_i, 1), numel(pk_i), size(imp_e_p.motTrace{iAmp}, 1)]);
        if nUse < 2, continue; end
        mot_i = mean(imp_e_p.motTrace{iAmp}(1:nUse, iMot_a), 2);
        allAbsDev_pool = [allAbsDev_pool; abs(pk_i(1:nUse) - mn_i)];  %#ok<AGROW>
        allMot_pool    = [allMot_pool;    mot_i];                       %#ok<AGROW>
        allExp_pool    = [allExp_pool;    repmat(expIdx, nUse, 1)];     %#ok<AGROW>
    end
end

[rP, pP]    = corr(allMot_pool, allAbsDev_pool, 'rows', 'complete');
motBin_pool = (allMot_pool > motThr_hi) + 1;   % 1=No motion, 2=Motion

% shuffle so no session dominates by draw order
rng(0);
shufIdx        = randperm(numel(allMot_pool));
allMot_s       = allMot_pool(shufIdx);
allAbsDev_s    = allAbsDev_pool(shufIdx);
allExp_s       = allExp_pool(shufIdx);
motBin_s       = motBin_pool(shufIdx);

poolMarkers = {'o', '^'};   % No motion = circle, Motion = triangle

% per-trial colour matrix (N×3) from session index
cMat = expColors(allExp_s, :);

fig_mvp = paperFig(6, 4);
ax_mvp  = axes(fig_mvp);
hold(ax_mvp, 'on');

% one scatter call per marker class; per-point colour via Nx3 matrix
for k = 1:2
    mk = motBin_s == k;
    if ~any(mk), continue; end
    scatter(ax_mvp, allMot_s(mk), allAbsDev_s(mk), 8, cMat(mk, :), ...
        poolMarkers{k}, 'filled', 'MarkerFaceAlpha', 0.5, ...
        'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
end

hLeg_p  = gobjects(nExp + 2, 1);
for expIdx = 1:nExp
    eCol = expColors(expIdx, :);
    hLeg_p(expIdx) = plot(ax_mvp, nan, nan, 'o', ...
        'MarkerFaceColor', eCol, 'MarkerEdgeColor', 'none', ...
        'MarkerSize', 4, 'DisplayName', sprintf('Session %d', expIdx));
end
% legend entries for marker shape
hLeg_p(nExp+1) = plot(ax_mvp, nan, nan, 'o', 'MarkerFaceColor', [0.5 0.5 0.5], ...
    'MarkerEdgeColor','none','MarkerSize',4,'DisplayName','No motion');
hLeg_p(nExp+2) = plot(ax_mvp, nan, nan, '^', 'MarkerFaceColor', [0.5 0.5 0.5], ...
    'MarkerEdgeColor','none','MarkerSize',4,'DisplayName','Motion');
hl_p = xline(ax_mvp, motThr_hi, 'k--', 'LineWidth', 0.8); hl_p.HandleVisibility = 'off';
% title(ax_mvp, sprintf('All sessions  r = %.2f  p = %.3f', rP, pP), ...
%     'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_mvp, sprintf('Mean motion z-score (%.1f to %.1f s)', motWin_ana(1), motWin_ana(2)), ...
    'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_mvp, '|Peak dev| (\DeltaF/F %)', 'FontSize', 6, 'FontWeight', 'bold');
lg_mvp = legend(ax_mvp, hLeg_p(1:nExp+2), 'Location', 'best', 'FontSize', 6);
lg_mvp.ItemTokenSize = [6 6];
set(ax_mvp, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
hold(ax_mvp, 'off');
exportgraphics(fig_mvp, ...
    'paper/images/figure2/imp_motion_devscatter_all_sessions.pdf', ...
    'ContentType', 'vector');

%% Interactive freq heatmap — click a trial row to open detail view

%
% Same layout as static heatmap above.
% Click any row → impulseDetailCallback opens a 3-panel figure:
%   top: dF/F trial trace + amp-mean ± SD
%   mid: z-scored motion trace
%   bot: per-trial vs mean absolute band power

t_win_imp = -tWin : 1/35 : tWin;   % time vector matching df_imp columns

for expIdx = 1:nExp

    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    % Shared color limit for this experiment
    all_freq_e = vertcat(imp_e.freqSpec{:});
    clim_e     = prctile(all_freq_e(:), 98);

    nCols_f = min(nAmp_e, 4);
    nRows_f = ceil(nAmp_e / nCols_f);

    fig_fi = figure('Color','w');
    fig_fi.Units    = 'inches';
    fig_fi.Position = [2, 2, nCols_f*3.5, nRows_f*3];
    sgtitle(sprintf('%s  %s  e%d — click trial row for detail', ...
        allExperiments(expIdx).mn, allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 10, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        dev_i  = imp_e.Peak_imp_dev{iAmp}(:);
        freq_i = imp_e.freqSpec{iAmp};
        nUse   = min(numel(dev_i), size(freq_i,1));
        if nUse < 2, continue; end
        dev_i  = dev_i(1:nUse);
        freq_i = freq_i(1:nUse, :);

        [~, sOrd] = sort(dev_i, 'ascend');

        ax = subplot(nRows_f, nCols_f, iAmp);
        hImg = imagesc(ax, freqBandCtrs, 1:nUse, freq_i(sOrd, :));
        colormap(ax, 'hot');
        clim(ax, [0 clim_e]);
        cb = colorbar(ax);  cb.Label.String = 'Power (\DeltaF/F)^2 Hz^{-1}';
        xlabel(ax, 'Frequency (Hz)', 'FontSize', 8);
        ylabel(ax, 'Trial (sorted by dev)', 'FontSize', 8);
        title(ax, sprintf('%.2f V  (n=%d)  [click]', imp_e.uAmp{iAmp}, nUse), ...
            'FontSize', 8, 'FontWeight','bold');
        set(ax, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 8);
        xticks(ax, 0:2:10);

        % Capture per-iteration values for the closure
        c_ax   = ax;
        c_sOrd = sOrd;
        c_imp  = imp_e;
        c_iAmp = iAmp;
        c_twin = t_win_imp;
        set(hImg, 'ButtonDownFcn', ...
            @(~,~) impulseDetailCallback(c_ax, c_sOrd, c_imp, c_iAmp, c_twin));
    end
end

%% Pre-trial variance sort — scatter (row 1) + errorbar by variance quintile (row 2)
%
% For each amplitude:
%   Row 1: scatter(pre-trial variance, |Peak_imp dev|) + Pearson r
%   Row 2: trials binned into 5 variance quintiles → mean ± SEM of |Peak_imp dev|
%
% Subplot index uses column/group calculation so the layout is correct
% when nAmp > 4 and amplitudes wrap across rows.

preIdx_var = t_win_imp >= -1 & t_win_imp < 0;   % 35 samples, -1 to 0 s
nVarBins   = 5;

for expIdx = 1:nExp

    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    nCols_v = min(nAmp_e, 4);
    nRows_v = ceil(nAmp_e / nCols_v);   % amplitude row-groups
    nGridR  = nRows_v * 2;              % total subplot rows (scatter + eb per group)

    fig_v = figure('Color','w');
    fig_v.Units    = 'centimeters';
    fig_v.Position = [2, 2, nCols_v*6, nRows_v*2*4];
    sgtitle(sprintf('%s  %s  e%d — pre-trial variance vs inhibition deviation', ...
        allExperiments(expIdx).mn, allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 8, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        df_i  = imp_e.dfImp{iAmp};
        dev_i = imp_e.Peak_imp_dev{iAmp}(:);
        n_i   = min(size(df_i,1), numel(dev_i));
        if n_i < 3, continue; end
        df_i  = df_i(1:n_i, :);
        dev_i = dev_i(1:n_i);

        preVar_i = var(df_i(:, preIdx_var), 0, 2);   % nTrials × 1

        [r_v, p_v] = corr(preVar_i, dev_i, 'rows','complete');

        % Correct subplot indices: each amplitude occupies one column;
        % amplitudes wrap every nCols_v, each wrap uses 2 grid rows.
        col_v   = mod(iAmp-1, nCols_v) + 1;
        grp_v   = ceil(iAmp / nCols_v);
        sp_top  = (grp_v-1)*2*nCols_v + col_v;        % scatter row
        sp_bot  = (grp_v-1)*2*nCols_v + nCols_v + col_v;  % errorbar row

        % Row 1: scatter
        ax1 = subplot(nGridR, nCols_v, sp_top);
        scatter(ax1, preVar_i, dev_i, 12, 'filled', 'MarkerFaceAlpha', 0.5);
        xlabel(ax1, 'Pre-trial var (\DeltaF/F)^2', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax1, '|Peak dev|', 'FontSize', 6, 'FontWeight','bold');
        title(ax1, sprintf('%.2f V  r=%.2f  p=%.3f', imp_e.uAmp{iAmp}, r_v, p_v), ...
            'FontSize', 6, 'FontWeight','bold');
        set(ax1, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');

        % Row 2: mean ± SEM of |Peak dev| per variance quintile
        edges_v  = quantile(preVar_i, linspace(0, 1, nVarBins+1));
        edges_v(1) = edges_v(1) - eps;
        [~, ~, binID] = histcounts(preVar_i, edges_v);
        eb_mu  = zeros(nVarBins, 1);
        eb_sem = zeros(nVarBins, 1);
        for ib = 1:nVarBins
            vals = dev_i(binID == ib);
            eb_mu(ib)  = mean(vals, 'omitnan');
            eb_sem(ib) = std(vals, 'omitnan') / sqrt(max(sum(~isnan(vals)), 1));
        end

        ax2 = subplot(nGridR, nCols_v, sp_bot);
        errorbar(ax2, 1:nVarBins, eb_mu, eb_sem, 'o-', ...
            'Color',[0.2 0.4 0.8], 'MarkerFaceColor',[0.2 0.4 0.8], ...
            'MarkerSize', 4, 'LineWidth', 0.8, 'CapSize', 4);
        xticks(ax2, 1:nVarBins);
        xticklabels(ax2, {'Q1','Q2','Q3','Q4','Q5'});
        xlabel(ax2, 'Pre-trial var quintile', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax2, 'Mean |Peak dev| ± SEM', 'FontSize', 6, 'FontWeight','bold');
        title(ax2, sprintf('n=%d', n_i), 'FontSize', 6, 'FontWeight','bold');
        set(ax2, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');
    end
end



%% Pre-trial variance vs deviation (per session, motion-excluded)
%
% Per-session, per-amplitude: scatter of pre-trial variance vs |Peak dev|,
% plus quintile errorbar.  Top 25% motion trials excluded.
% Diagnostic only — no export.

for expIdx = 1:nExp

    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    % Threshold across all amplitudes for this experiment
    mot_rows_e = cellfun(@(x) x(:)', imp_e.mot, 'UniformOutput', false);
    all_mot_e  = horzcat(mot_rows_e{:});
    mot_thresh = prctile(all_mot_e(:), 75);

    nCols_m = min(nAmp_e, 4);
    nRows_m = ceil(nAmp_e / nCols_m);
    nGridR_m = nRows_m * 2;

    fig_m = figure('Color','w');
    fig_m.Units    = 'centimeters';
    fig_m.Position = [2, 2, nCols_m*6, nRows_m*2*4];
    sgtitle(sprintf('%s  %s  e%d — pre-trial variance (motion-excluded, top 25%% removed)', ...
        allExperiments(expIdx).mn, allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 8, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        df_i    = imp_e.dfImp{iAmp};
        pk_i    = imp_e.Peak_imp{iAmp}(:);
        mot_i   = imp_e.mot{iAmp}(:);
        n_total = min([size(df_i,1), numel(pk_i), numel(mot_i)]);
        if n_total < 3, continue; end

        df_i  = df_i(1:n_total, :);
        pk_i  = pk_i(1:n_total);
        mot_i = mot_i(1:n_total);

        keepIdx = mot_i <= mot_thresh;
        n_kept  = sum(keepIdx);
        if n_kept < 3, continue; end

        df_clean  = df_i(keepIdx, :);
        pk_clean  = pk_i(keepIdx);
        dev_clean = abs(pk_clean - mean(pk_clean, 'omitnan'));
        mot_clean = imp_e.motTrace{iAmp}(keepIdx, :);

        preVar_clean = var(df_clean(:, preIdx_var), 0, 2);
        [r_m, p_m]   = corr(preVar_clean, dev_clean, 'rows','complete');

        % Correct subplot indices
        col_m  = mod(iAmp-1, nCols_m) + 1;
        grp_m  = ceil(iAmp / nCols_m);
        sp_top = (grp_m-1)*2*nCols_m + col_m;
        sp_bot = (grp_m-1)*2*nCols_m + nCols_m + col_m;

        % Row 1: scatter (clickable)
        ax1 = subplot(nGridR_m, nCols_m, sp_top);
        hS = scatter(ax1, preVar_clean, dev_clean, 12, 'filled', 'MarkerFaceAlpha', 0.5);
        xlabel(ax1, 'Pre-trial var (\DeltaF/F)^2', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax1, '|Peak dev|', 'FontSize', 6, 'FontWeight','bold');
        title(ax1, sprintf('%.2f V  r=%.2f  p=%.3f  (%d/%d)  [click]', ...
            imp_e.uAmp{iAmp}, r_m, p_m, n_kept, n_total), ...
            'FontSize', 6, 'FontWeight','bold');
        set(ax1, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');

        % Capture closure variables for callback
        c_ax1   = ax1;
        c_pvar  = preVar_clean;
        c_dev   = dev_clean;
        c_df    = df_clean;
        c_mot   = mot_clean;
        c_twin  = t_win_imp;
        c_amp   = imp_e.uAmp{iAmp};
        set(hS, 'ButtonDownFcn', ...
            @(~,~) varDetailCallback(c_ax1, c_pvar, c_dev, c_df, c_mot, c_twin, c_amp));

        % Row 2: mean ± SEM of |Peak dev| per variance quintile
        edges_m = quantile(preVar_clean, linspace(0, 1, nVarBins+1));
        edges_m(1) = edges_m(1) - eps;
        [~, ~, binID_m] = histcounts(preVar_clean, edges_m);
        eb_mu_m  = zeros(nVarBins, 1);
        eb_sem_m = zeros(nVarBins, 1);
        for ib = 1:nVarBins
            vals = dev_clean(binID_m == ib);
            eb_mu_m(ib)  = mean(vals, 'omitnan');
            eb_sem_m(ib) = std(vals, 'omitnan') / sqrt(max(sum(~isnan(vals)), 1));
        end

        ax2 = subplot(nGridR_m, nCols_m, sp_bot);
        errorbar(ax2, 1:nVarBins, eb_mu_m, eb_sem_m, 'o-', ...
            'Color',[0.2 0.7 0.4], 'MarkerFaceColor',[0.2 0.7 0.4], ...
            'MarkerSize', 4, 'LineWidth', 0.8, 'CapSize', 4);
        xticks(ax2, 1:nVarBins);
        xticklabels(ax2, {'Q1','Q2','Q3','Q4','Q5'});
        xlabel(ax2, 'Pre-trial var quintile', 'FontSize', 6, 'FontWeight','bold');
        ylabel(ax2, 'Mean |Peak dev| ± SEM', 'FontSize', 6, 'FontWeight','bold');
        title(ax2, sprintf('n=%d kept', n_kept), 'FontSize', 6, 'FontWeight','bold');
        set(ax2, 'Box','off', 'TickDir','out', 'FontSize', 6, 'FontWeight','bold');
    end
end   % for expIdx - Section A

%% Pre-trial variance vs peak deviation — paper figure, motion-excluded (session selExp)
%
% Same as the all-trials paper figure above but top 25% motion trials removed.
% Motion threshold: 75th percentile of all motion values across all amps, session selExp.
% Deviation recomputed on kept trials only (mean shifts after removing noisy trials).

PS_pvm = paperStyle();

imp_pam   = allExperiments(selExp).imp;
nAmp_pam  = numel(imp_pam.uAmp);

% Motion threshold: 75th pctile across all amplitudes for this session
mot_rows_pam = cellfun(@(x) x(:)', imp_pam.mot, 'UniformOutput', false);
mot_thresh_pam = prctile(horzcat(mot_rows_pam{:}), 75);

vToMW_pam = 1.8 / 4.9;   % laser calibration: 0 V = 0 mW, 4.9 V = 1.8 mW

validAmps_pam = find(cellfun(@(x) x > 0, imp_pam.uAmp));
nV_pam        = numel(validAmps_pam);
ampCmap_pam   = cool(nV_pam);

fig_pvm = paperFig(6, 4);
ax_pvm  = axes(fig_pvm);
hold(ax_pvm, 'on');

for ki = 1:nV_pam
    iAmp   = validAmps_pam(ki);
    df_i   = imp_pam.dfImp{iAmp};
    pk_i   = imp_pam.Peak_imp{iAmp}(:);
    mot_i  = imp_pam.mot{iAmp}(:);
    n_tot  = min([size(df_i,1), numel(pk_i), numel(mot_i)]);
    if n_tot < nBins_pa + 1, continue; end

    df_i  = df_i(1:n_tot, :);
    pk_i  = pk_i(1:n_tot);
    mot_i = mot_i(1:n_tot);

    keepIdx = mot_i <= mot_thresh_pam;
    if sum(keepIdx) < nBins_pa + 1, continue; end

    df_k   = df_i(keepIdx, :);
    pk_k   = pk_i(keepIdx);
    dev_k  = abs(pk_k - mean(pk_k, 'omitnan'));   % recomputed on kept trials

    preVar_k = var(df_k(:, preIdx_var), 0, 2);

    edges_pam    = quantile(preVar_k, linspace(0, 1, nBins_pa + 1));
    edges_pam(1) = edges_pam(1) - eps;
    [~, ~, binID_pam] = histcounts(preVar_k, edges_pam);

    bin_mu_m  = zeros(nBins_pa, 1);
    bin_sem_m = zeros(nBins_pa, 1);
    bin_xmu_m = zeros(nBins_pa, 1);
    for ib = 1:nBins_pa
        mask_ib       = binID_pam == ib;
        vals_ib       = dev_k(mask_ib);
        bin_mu_m(ib)  = mean(vals_ib, 'omitnan');
        bin_sem_m(ib) = std(vals_ib, 'omitnan') / sqrt(max(sum(~isnan(vals_ib)), 1));
        bin_xmu_m(ib) = mean(preVar_k(mask_ib), 'omitnan');
    end

    col_pam = ampCmap_pam(ki, :);
    errorbar(ax_pvm, bin_xmu_m, bin_mu_m, bin_sem_m, 'o-', ...
        'Color', col_pam, 'MarkerFaceColor', col_pam, ...
        'MarkerSize', 3, 'LineWidth', PS_pvm.lw_mean, 'CapSize', 3, ...
        'DisplayName', sprintf('%.2f mW', imp_pam.uAmp{iAmp} * vToMW_pam));
end

hold(ax_pvm, 'off');
set(ax_pvm, 'Box', 'off', 'TickDir', 'out', 'FontSize', PS_pvm.fs, 'FontWeight', PS_pvm.fw);
xlabel(ax_pvm, 'Pre-trial variance (\DeltaF/F)^2', 'FontSize', PS_pvm.fs, 'FontWeight', PS_pvm.fw);
ylabel(ax_pvm, 'Mean |peak dev| +/- SEM (\DeltaF/F %)', 'FontSize', PS_pvm.fs, 'FontWeight', PS_pvm.fw);
% title(ax_pvm, 'Pre-trial variance vs deviation (motion excluded)', ...
%     'FontSize', PS_pvm.fs, 'FontWeight', PS_pvm.fw);
lg_pvm = legend(ax_pvm, 'Location', 'eastoutside', 'FontSize', PS_pvm.fs);
lg_pvm.ItemTokenSize = [PS_pvm.lw_mean * 4, 6];
lg_pvm.Box = 'off';

mn_pam = allExperiments(selExp).mn;
td_pam = allExperiments(selExp).td;
en_pam = allExperiments(selExp).en;
exportgraphics(fig_pvm, ...
    sprintf('paper/images/figure2/prevar_vs_dev_allamps_motexcl_%s_%s_en%d.pdf', mn_pam, td_pam, en_pam), ...
    'ContentType', 'vector');

%% Freq heatmap sorted by pre-trial variance + deviation side strip (interactive)
%
% Trials sorted ascending by pre-trial variance (motion removed, session selExp).
% X axis: frequency bands (freqBandCtrs).
% Left panel: spectral power heatmap (parula). 2-4 Hz band highlighted.
% Right strip: absolute deviation |Peak_imp - mean| per trial (hot colormap).
%
% Click any row in either panel to open a 3-panel detail figure for that trial:
%   top   : dF/F trace (this trial, red) vs all kept-trial mean +/- SD (grey)
%   middle: frequency spectrum (this trial, red) vs mean spectrum (grey)
%   bottom: text summary (trial rank, pre-stim variance, deviation, amplitude)
%
% Static PNG is also exported.

% --- Pool data across amplitudes (motion excluded, same session and threshold) ---
imp_pvh        = allExperiments(selExp).imp;
nAmp_pvh       = numel(imp_pvh.uAmp);
mot_rows_pvh   = cellfun(@(x) x(:)', imp_pvh.mot, 'UniformOutput', false);
mot_thresh_pvh = prctile(horzcat(mot_rows_pvh{:}), 75);
vToMW_pvh      = 1.8 / 4.9;   % 0 V = 0 mW, 4.9 V = 1.8 mW

allPreVar_p   = [];
allFreq_p     = [];
allDev_p      = [];
allTrace_p    = [];
allAmpV_p     = [];   % amplitude in V per trial

for iAmp_pvh = 1:nAmp_pvh
    df_i   = imp_pvh.dfImp{iAmp_pvh};
    pk_i   = imp_pvh.Peak_imp{iAmp_pvh}(:);
    mot_i  = imp_pvh.mot{iAmp_pvh}(:);
    freq_i = imp_pvh.freqSpec{iAmp_pvh};
    n_tot  = min([size(df_i,1), numel(pk_i), numel(mot_i), size(freq_i,1)]);
    if n_tot < 3, continue; end
    df_i   = df_i(1:n_tot, :);
    pk_i   = pk_i(1:n_tot);
    mot_i  = mot_i(1:n_tot);
    freq_i = freq_i(1:n_tot, :);

    keep   = find(mot_i <= mot_thresh_pvh);
    if numel(keep) < 3, continue; end

    df_k   = df_i(keep, :);
    pk_k   = pk_i(keep);
    freq_k = freq_i(keep, :);
    dev_k  = abs(pk_k - mean(pk_k, 'omitnan'));
    pvar_k = var(df_k(:, preIdx_var), 0, 2);

    allPreVar_p = [allPreVar_p; pvar_k];                                        %#ok<AGROW>
    allFreq_p   = [allFreq_p;   freq_k];                                        %#ok<AGROW>
    allDev_p    = [allDev_p;    dev_k];                                         %#ok<AGROW>
    allTrace_p  = [allTrace_p;  df_k];                                          %#ok<AGROW>
    allAmpV_p   = [allAmpV_p;   repmat(imp_pvh.uAmp{iAmp_pvh}, numel(keep), 1)]; %#ok<AGROW>
end

% --- Sort all pooled trials by pre-trial variance ---
[~, si_pv]       = sort(allPreVar_p, 'ascend');
freq_sorted_pv   = allFreq_p(si_pv, :);
dev_sorted_pv    = allDev_p(si_pv);
trace_sorted_pv  = allTrace_p(si_pv, :);
pvar_sorted_pv   = allPreVar_p(si_pv);
ampV_sorted_pv   = allAmpV_p(si_pv);
nT_pv            = numel(dev_sorted_pv);

% --- Build figure ---
fig_pvh = paperFig(10, 5);
tl_pvh  = tiledlayout(fig_pvh, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel A: spectral heatmap
ax_pvhA = nexttile(tl_pvh, 1);
hImg_A  = imagesc(ax_pvhA, freqBandCtrs, 1:nT_pv, freq_sorted_pv);
colormap(ax_pvhA, parula);
clim(ax_pvhA, [0, prctile(allFreq_p(:), 98)]);
set(ax_pvhA, 'YDir', 'normal', 'Box', 'off', 'TickDir', 'out', ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_pvhA, 'Frequency (Hz)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pvhA, 'Trial (sorted by pre-stim variance, low->high)', ...
    'FontSize', 6, 'FontWeight', 'bold');
title(ax_pvhA, 'Spectral power  [click row]', 'FontSize', 6, 'FontWeight', 'bold');
xticks(ax_pvhA, 0:2:10);
hold(ax_pvhA, 'on');
patch(ax_pvhA, [2 4 4 2], [0.5 0.5 nT_pv+0.5 nT_pv+0.5], ...
    [1 0.85 0.1], 'FaceAlpha', 0.13, 'EdgeColor', [0.85 0.6 0], ...
    'LineWidth', 0.8, 'HandleVisibility', 'off');
hold(ax_pvhA, 'off');
cb_pvhA = colorbar(ax_pvhA, 'Location', 'eastoutside');
cb_pvhA.Label.String   = 'Power (\DeltaF/F)^2 Hz^{-1}';
cb_pvhA.Label.FontSize = 6;
cb_pvhA.FontSize       = 6;

% Panel B: deviation side strip
ax_pvhB = nexttile(tl_pvh, 2);
hImg_B  = imagesc(ax_pvhB, 1, 1:nT_pv, dev_sorted_pv);
colormap(ax_pvhB, hot);
clim(ax_pvhB, [0, prctile(dev_sorted_pv, 98)]);
set(ax_pvhB, 'YDir', 'normal', 'Box', 'off', 'TickDir', 'out', ...
    'XTick', [], 'FontSize', 6, 'FontWeight', 'bold', 'YTickLabel', {});
title(ax_pvhB, '|Dev| (dF/F)  [click]', 'FontSize', 6, 'FontWeight', 'bold');
cb_pvhB = colorbar(ax_pvhB, 'Location', 'eastoutside');
cb_pvhB.Label.String   = '|Peak dev| (\DeltaF/F %)';
cb_pvhB.Label.FontSize = 6;
cb_pvhB.FontSize       = 6;

% --- Attach click callbacks ---
% Capture all closure variables explicitly (avoids workspace-clear issues).
pvh_data.trace    = trace_sorted_pv;
pvh_data.dev      = dev_sorted_pv;
pvh_data.pvar     = pvar_sorted_pv;
pvh_data.ampV     = ampV_sorted_pv;
pvh_data.freq     = freq_sorted_pv;
pvh_data.fbCtrs   = freqBandCtrs;
pvh_data.twin     = t_win_imp;
pvh_data.nT       = nT_pv;
pvh_data.vToMW    = vToMW_pvh;
pvh_data.meanTr   = mean(trace_sorted_pv, 1, 'omitnan');
pvh_data.sdTr     = std(trace_sorted_pv, 0, 1);
pvh_data.meanFreq = mean(freq_sorted_pv, 1, 'omitnan');

set(hImg_A, 'ButtonDownFcn', @(~, ev) heatmapRowCallback(ev, ax_pvhA, pvh_data));
set(hImg_B, 'ButtonDownFcn', @(~, ev) heatmapRowCallback(ev, ax_pvhB, pvh_data));

exportgraphics(fig_pvh, 'paper/prevar_sorted_heatmap_dev.png', 'Resolution', 300);

%% Spatial spread vs amplitude

pxMM      = 0.173;    % mm per pixel
selExp_sp = 3;        % session to analyse (change here; does not require selExp in workspace)

uA_sp       = allExperiments(selExp_sp).uAmp(:);
imp_s       = allExperiments(selExp_sp).imp;
mimg_s      = allExperiments(selExp_sp).mimg;
brainMask   = allExperiments(selExp_sp).brainMask;
mI1_s       = allExperiments(selExp_sp).mI1;
nAmp_sp     = numel(uA_sp);
validAmp_sp = uA_sp > 0;
validIdx_sp = find(validAmp_sp);
nV_sp       = numel(validIdx_sp);

nr_s = size(mimg_s, 1);   nc_s = size(mimg_s, 2);

% Stack resp and baseline maps across valid amplitudes
resp_maps = zeros(sum(brainMask), nV_sp);
base_maps = zeros(sum(brainMask), nV_sp);
for k = 1:nV_sp
    iA = validIdx_sp(k);
    resp_maps(:, k) = imp_s.resp_map{iA};
    base_maps(:, k) = imp_s.base_map{iA};
end

% Global threshold: 50% of the strongest inhibition across ALL amplitudes.
% Using per-amplitude FWHM inverts the ordering (small amps get a very
% permissive threshold, counting noise as spread -> spuriously large area).
% A single shared threshold fixes this: small amps that never reach it
% give near-zero area, and area grows monotonically with amplitude.
global_thr_sp = 0.5 * min(resp_maps(:));   % most negative dF/F across all amps, halved
fprintf('Global threshold: %.4f dF/F%%  (50%% of strongest peak)\n', global_thr_sp);

spread_area = nan(nAmp_sp, 1);
for k = 1:nV_sp
    iA = validIdx_sp(k);
    map_k = resp_maps(:, k);
    n_px = sum(map_k < global_thr_sp);
    spread_area(iA) = n_px * pxMM^2;
    fprintf('  amp=%.2f mW  peak=%.3f%%dF/F  area=%.2f mm2\n', ...
        uA_sp(iA) * (1.8/4.9), min(map_k), spread_area(iA));
end

% ── Figure: amplitude vs inhibition area ────────────────────────────────
vToMW_sp  = 1.8 / 4.9;   % calibration: 0 V = 0 mW, 4.9 V = 1.8 mW
xAmp_sp   = uA_sp(validAmp_sp) * vToMW_sp;
yArea_sp  = spread_area(validAmp_sp);

fig_sp = paperFig(6, 4);
ax_sp  = axes(fig_sp);
plot(ax_sp, xAmp_sp, yArea_sp, 'o-', ...
    'Color', [0.15 0.35 0.8], 'MarkerFaceColor', [0.15 0.35 0.8], ...
    'MarkerSize', 4, 'LineWidth', 1.5);
xlabel(ax_sp, 'Amplitude (mW)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_sp, 'Inhibition area (mm^2)', 'FontSize', 6, 'FontWeight', 'bold');
set(ax_sp, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

mn_sp = allExperiments(selExp_sp).mn;
td_sp = allExperiments(selExp_sp).td;
en_sp = allExperiments(selExp_sp).en;
exportgraphics(fig_sp, ...
    sprintf('paper/spatial_spread_%s_%s_en%d.png', mn_sp, td_sp, en_sp), ...
    'Resolution', 300);

