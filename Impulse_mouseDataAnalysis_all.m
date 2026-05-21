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

githubDir = "/home/nimbus/Documents/Brain/"
    
    
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

        % motion sum over ±35 samples using cumsum (no per-trial loop)
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
print(figS, sprintf('paper/imp_single_%s_%s_en%d.pdf',mn3,td3,en3), '-dpdf','-painters');

%% Combined plot for all experiments
% close all;
% 
% % Colors for each experiment
% expColors = [0.2 0.4 0.8; 0.8 0.2 0.2; 0.2 0.8 0.4];
% nCond = 3;
% figure('Color','w','Position',[100 100 800 600]); hold on
% h1 = yline(0,'--k')
% hLegend = gobjects(nCond,1);   % preallocate handles
% 
% % Plot each experiment
% for expIdx = 1:length(allExperiments)
%     allVals = allExperiments(expIdx).allVals;
%     groupLabels = allExperiments(expIdx).groupLabels;
% 
%     % Get means and std per group in plotting order
%     [ug,~,idx] = unique(groupLabels, 'stable');
%     meanVals = accumarray(idx(:), allVals(:), [], @(v) mean(v,'omitnan'));
%     stdVals = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan'));
%     semVals = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan')/sqrt(sum(~isnan(v))));
% 
%     % X-positions (offset for each experiment)
%     xpos = 1:numel(ug);
%     xOffset = (expIdx - 2) * 0.15;  % offset experiments slightly
%     xpos = xpos + xOffset;
% 
%     % Plot mean as dots with std as vertical lines
%     capWidth = 0.05;
% 
%     nCond = 3;
%     for i = 1:numel(ug)
%         % Vertical line for SEM
%         plot([xpos(i) xpos(i)], [meanVals(i)-semVals(i), meanVals(i)+semVals(i)], ...
%             '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
%         % Horizontal caps at top and bottom
%         plot([xpos(i)-capWidth xpos(i)+capWidth], [meanVals(i)-semVals(i), meanVals(i)-semVals(i)], ...
%             '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
%         plot([xpos(i)-capWidth xpos(i)+capWidth], [meanVals(i)+semVals(i), meanVals(i)+semVals(i)], ...
%             '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
%         % Mean as dot
%         plot(xpos(i), meanVals(i), 'o', 'MarkerSize', 10, ...
%             'MarkerFaceColor', expColors(expIdx,:), 'MarkerEdgeColor', expColors(expIdx,:), 'LineWidth', 2);
% 
% 
%     end
% 
%     % Fit line through means for this experiment
%     p  = polyfit(xpos, meanVals, 1);
%     xf = linspace(min(xpos)-0.2, max(xpos)+0.2, 100);
%     hMean  = plot(xf, polyval(p,xf), '-', 'LineWidth', 2.0, 'Color', expColors(expIdx,:), ...
%         'DisplayName', sprintf('%s %s-%d', allExperiments(expIdx).mn, ...
%                                allExperiments(expIdx).td, allExperiments(expIdx).en));
%     hLegend(expIdx) = hMean;
% end
% 
% % Beautify for paper
% ax = gca;
% ax.LineWidth = 1.5;
% ax.FontName = 'Arial';
% ax.FontSize = 12;
% ax.FontWeight = 'bold';
% ax.TickDir = 'out';
% ax.Box = 'off';
% xlabel('Amplitude(V)', 'FontWeight','bold');
% ylabel('dF/F %', 'FontWeight','bold');
% ylim([-5 3])
% uistack(h1, 'bottom')
% xticks([])
% try
%     shortCornerAxes_plot(gca,'Frac',0.1,'XLabel','Input(V)','YLabel','dF/F','LineWidth',5)
% catch
%     xlabel('Input(V)', 'FontWeight','bold');
%     ylabel('dF/F %', 'FontWeight','bold');
% end
% nExp_leg = length(allExperiments);
% legTxt_1 = arrayfun(@(e) sprintf('Session %d', e), 1:nExp_leg, 'UniformOutput', false);
% lgd = legend(ax, hLegend(1:nExp_leg), legTxt_1, 'Box','off','Color','none');
% lgd.ItemTokenSize = [14 6];
% lgd.AutoUpdate = 'off';
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

    for j = 1:numel(ug)
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
print(fig, 'paper/imp_response.pdf', '-dpdf', '-painters');

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
print(figM, 'paper/imp_response_median.pdf', '-dpdf', '-painters');

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
    'LineWidth',2,'LabelGap',0.05,'FontSize',6);

lgd_A = legend(ax_A, 'Box','off','FontSize',6,'FontWeight','bold','Location','southeast');
lgd_A.ItemTokenSize = [15 10];
lgd_A.AutoUpdate = 'off';

exportgraphics(fig_A, sprintf('paper/tf_data_vs_model_%s_%s_en%d.pdf', ...
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
        'LineWidth',2,'LabelGap',0.05,'FontSize',6);

    lgd_B = legend(ax_B, 'Box','off','FontSize',6,'FontWeight','bold','Location','southwest');
    lgd_B.ItemTokenSize = [6 6];
    lgd_B.AutoUpdate = 'off';

    exportgraphics(fig_B, sprintf('paper/tf_loao_%s_%s_en%d.pdf', ...
        allExperiments(selExp).mn, allExperiments(selExp).td, allExperiments(selExp).en), ...
        'ContentType','vector');
end

%% Motion vs Peak_imp deviation — one figure per session, subplots per amp
%
% X: motion energy = sum(mv_z, stim±1s)  (imp.mot, window already set to ±35 samples)
% Y: |Peak_imp − mean(Peak_imp)| for that amp group  (imp.Peak_imp_dev)
% Click any dot → motionDetailCallback opens dF/F + motion trace for that trial.

nExp = numel(allExperiments);
t_win_mot = -tWin : 1/35 : tWin;

for expIdx = 1:nExp
    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    nCols_m = min(nAmp_e, 4);
    nRows_m = ceil(nAmp_e / nCols_m);

    fig_m = figure('Color','w');
    fig_m.Units    = 'inches';
    fig_m.Position = [1, 1, nCols_m*3, nRows_m*3];
    sgtitle(sprintf('%s  %s  e%d  [click dot for detail]', allExperiments(expIdx).mn, ...
        allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 10, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        mot_i = imp_e.mot{iAmp}(:);
        dev_i = imp_e.Peak_imp_dev{iAmp}(:);
        nUse  = min(numel(mot_i), numel(dev_i));
        if nUse < 2, continue; end
        mot_i = mot_i(1:nUse);
        dev_i = dev_i(1:nUse);

        ax = subplot(nRows_m, nCols_m, iAmp);
        hS = scatter(ax, mot_i, dev_i, 25, [0.2 0.4 0.8], 'o', 'filled', ...
            'MarkerFaceAlpha', 0.6);

        r = corr(mot_i, dev_i, 'rows','complete');
        title(ax, sprintf('%.2f V   (n=%d,  r=%.2f)', imp_e.uAmp{iAmp}, nUse, r), ...
            'FontSize', 8, 'FontWeight','bold');
        xlabel(ax, 'Motion energy (±1s)', 'FontSize', 8);
        ylabel(ax, 'Prediction error', 'FontSize', 8);
        set(ax, 'Box','off', 'TickDir','out', 'FontSize', 8);

        % Capture per-iteration values for the closure
        c_ax   = ax;
        c_mot  = mot_i;
        c_dev  = dev_i;
        c_imp  = imp_e;
        c_iAmp = iAmp;
        c_twin = t_win_mot;
        set(hS, 'ButtonDownFcn', ...
            @(~,~) motionDetailCallback(c_ax, c_mot, c_dev, c_imp, c_iAmp, c_twin));
    end
end

%% Motion-sorted trial heatmap + signed deviation figure (per amplitude)
%
% Figure 1: per-amplitude heatmap — trials × time, sorted by motion energy
%           ascending, raw dF/F as colour (shared CLim across amps).
% Figure 2: per-amplitude signed deviation — same trial order on Y-axis,
%           Peak_imp − mean(Peak_imp) on X-axis, coloured by motion tertile.
%
% Motion window: ±1 s (±35 samples at 35 Hz) around stim onset (imp.mot).

selExp_mot     = 3;
tCrop_mot      = [-0.5, 1.5];   % display window (s)
tertColors_mot = [0.20 0.40 0.80;   % low  — blue
                  0.55 0.25 0.75;   % mid  — purple
                  0.85 0.20 0.20];  % high — red
cmap_bwr = interp1([0 0.5 1], [0.0 0.0 1.0; 1.0 1.0 1.0; 1.0 0.0 0.0], ...
                   linspace(0, 1, 256));

imp_e_mot  = allExperiments(selExp_mot).imp;
nAmp_mot   = numel(imp_e_mot.uAmp);
t_full_mot = -tWin : 1/35 : tWin;
iCrop_mot  = find(t_full_mot >= tCrop_mot(1) & t_full_mot <= tCrop_mot(2));
tDisp_mot  = t_full_mot(iCrop_mot);

% --- Per-amplitude: sort trials by motion, compute signed deviation ---
dfSorted_all  = cell(nAmp_mot, 1);
devSorted_all = cell(nAmp_mot, 1);
motSorted_all = cell(nAmp_mot, 1);
tertile_all   = cell(nAmp_mot, 1);
nT_all        = zeros(nAmp_mot, 1);

for iAmp = 1:nAmp_mot
    df_i  = imp_e_mot.dfImp{iAmp};
    mot_i = imp_e_mot.mot{iAmp}(:);
    pk_i  = imp_e_mot.Peak_imp{iAmp}(:);
    nUse  = min([size(df_i, 1), numel(mot_i), numel(pk_i)]);
    if nUse < 2, continue; end
    df_i  = df_i(1:nUse, iCrop_mot);
    mot_i = mot_i(1:nUse);
    pk_i  = pk_i(1:nUse);

    [~, si]             = sort(mot_i, 'ascend');
    dfSorted_all{iAmp}  = df_i(si, :);
    motSorted_all{iAmp} = mot_i(si);
    dev_i               = pk_i - mean(pk_i, 'omitnan');
    devSorted_all{iAmp} = abs(dev_i(si));
    nT_all(iAmp)        = nUse;

    edges               = quantile(mot_i(si), [1/3, 2/3]);
    tertile_all{iAmp}   = 1 + (mot_i(si) >= edges(1)) + (mot_i(si) >= edges(2));
end

% Shared CLim for Figure 1: 2nd–98th percentile across all raw dF/F values
allRaw_mot = cell2mat(cellfun(@(m) m(:), dfSorted_all, 'UniformOutput', false));
clim_mot   = prctile(allRaw_mot(~isnan(allRaw_mot)), [2, 98]);

mn_mot = allExperiments(selExp_mot).mn;
td_mot = allExperiments(selExp_mot).td;
en_mot = allExperiments(selExp_mot).en;

% ---- Figure 1: heatmap (trials × time, sorted by motion) ----
fig_mh = paperFig(nAmp_mot * 3, 4);
tl_mh  = tiledlayout(fig_mh, 1, nAmp_mot, 'TileSpacing', 'tight', 'Padding', 'compact');

for iAmp = 1:nAmp_mot
    if isempty(dfSorted_all{iAmp}), continue; end
    ax = nexttile(tl_mh);
    imagesc(ax, tDisp_mot, 1:nT_all(iAmp), dfSorted_all{iAmp});
    set(ax, 'YDir', 'normal', 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
    colormap(ax, cmap_bwr);
    clim(ax, clim_mot);
    xline(ax, 0, 'w--', 'LineWidth', 0.8);
    n3 = nT_all(iAmp);
    yline(ax, n3/3 + 0.5,   'w--', 'LineWidth', 0.8);
    yline(ax, 2*n3/3 + 0.5, 'w--', 'LineWidth', 0.8);
    title(ax, sprintf('%.2f V  n=%d', imp_e_mot.uAmp{iAmp}, nT_all(iAmp)), ...
        'FontSize', 6, 'FontWeight', 'bold');
    xlabel(ax, 'Time (s)', 'FontSize', 6, 'FontWeight', 'bold');
    if iAmp == 1
        ylabel(ax, 'Trial (sorted by motion)', 'FontSize', 6, 'FontWeight', 'bold');
    end
    if iAmp == nAmp_mot
        cb = colorbar(ax, 'Location', 'eastoutside');
        cb.Label.String   = '\DeltaF/F (%)';
        cb.Label.FontSize = 6;
        cb.FontSize       = 6;
    end
end
exportgraphics(fig_mh, ...
    sprintf('paper/imp_motion_heatmap_%s_%s_en%d.pdf', mn_mot, td_mot, en_mot), ...
    'ContentType', 'vector');
exportgraphics(fig_mh, ...
    sprintf('paper/imp_motion_heatmap_%s_%s_en%d.png', mn_mot, td_mot, en_mot), ...
    'Resolution', 300);

% Figure 2 (pooled normalised deviation) is generated after the pool loop below.

% ---- Figure 3 / 4 / 5 / 6: pooled amplitude-normalised data ----
% Normalise each trial's trace and deviation by |Peak_imp_mean|.
% Also track amp group index and normalised |deviation| for Options A–C.
allDF_n    = [];
allMot_n   = [];
ampIdx_n   = [];   % amplitude group index per pooled trial
devNorm_n  = [];   % |Peak_imp - mean| / |Peak_imp_mean| per trial
for iAmp = 1:nAmp_mot
    df_i  = imp_e_mot.dfImp{iAmp};
    mot_i = imp_e_mot.mot{iAmp}(:);
    pk_i  = imp_e_mot.Peak_imp{iAmp}(:);
    mn_i  = imp_e_mot.Peak_imp_mean(iAmp);
    if isnan(mn_i) || mn_i == 0, continue; end
    nUse  = min([size(df_i, 1), numel(mot_i), numel(pk_i)]);
    allDF_n   = [allDF_n;   df_i(1:nUse, iCrop_mot) / abs(mn_i)];        %#ok<AGROW>
    allMot_n  = [allMot_n;  mot_i(1:nUse)];                               %#ok<AGROW>
    ampIdx_n  = [ampIdx_n;  repmat(iAmp, nUse, 1)];                       %#ok<AGROW>
    devNorm_n = [devNorm_n; abs(pk_i(1:nUse) - mn_i) / abs(mn_i)];       %#ok<AGROW>
end
edges_n   = quantile(allMot_n, [1/3, 2/3]);
tertile_n = 1 + (allMot_n >= edges_n(1)) + (allMot_n >= edges_n(2));

fig_mt = paperFig(6, 4);
ax_mt  = axes(fig_mt);
hold(ax_mt, 'on');
lgdStr_mt = {'Low motion', 'Mid motion', 'High motion'};
for k = 1:3
    mk = tertile_n == k;
    mu = mean(allDF_n(mk, :), 1, 'omitnan');
    se = std(allDF_n(mk, :), 0, 1, 'omitnan') / sqrt(sum(mk));
    fill(ax_mt, [tDisp_mot, fliplr(tDisp_mot)], [mu+se, fliplr(mu-se)], ...
        tertColors_mot(k, :), 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(ax_mt, tDisp_mot, mu, 'Color', tertColors_mot(k, :), 'LineWidth', 1, ...
        'DisplayName', lgdStr_mt{k});
end
xline(ax_mt, 0, 'k--', 'LineWidth', 0.5);
set(ax_mt, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
xlabel(ax_mt, 'Time (s)',        'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_mt, 'Norm. \DeltaF/F', 'FontSize', 6, 'FontWeight', 'bold');
lg_mt = legend(ax_mt, 'Location', 'best', 'FontSize', 6);
lg_mt.ItemTokenSize = [6 6];
hold(ax_mt, 'off');
exportgraphics(fig_mt, ...
    sprintf('paper/imp_motion_traces_%s_%s_en%d.pdf', mn_mot, td_mot, en_mot), ...
    'ContentType', 'vector');
exportgraphics(fig_mt, ...
    sprintf('paper/imp_motion_traces_%s_%s_en%d.png', mn_mot, td_mot, en_mot), ...
    'Resolution', 300);

% ---- Figure 2 (pooled): all amps, trials sorted by motion, norm |deviation| on X ----
[~, si_md]    = sort(allMot_n, 'ascend');
devNorm_smd   = devNorm_n(si_md);
mot_smd       = allMot_n(si_md);
nT_md         = numel(mot_smd);
edges_md      = quantile(mot_smd, [1/3, 2/3]);
tertile_md    = 1 + (mot_smd >= edges_md(1)) + (mot_smd >= edges_md(2));

fig_md = paperFig(6, 6);
ax_md  = axes(fig_md);
hold(ax_md, 'on');
lgdStr_md = {'Low motion', 'Mid motion', 'High motion'};
for k = 1:3
    mk = tertile_md == k;
    scatter(ax_md, devNorm_smd(mk), find(mk), 6, ...
        tertColors_mot(k, :), 'filled', 'MarkerFaceAlpha', 0.6, ...
        'DisplayName', lgdStr_md{k});
end
hl_md = xline(ax_md, 0, 'k--', 'LineWidth', 0.5);
hl_md.HandleVisibility = 'off';
r_md2 = corr(mot_smd, devNorm_smd, 'rows', 'complete');
title(ax_md, sprintf('All amps pooled  r = %.2f', r_md2), ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_md, '|Peak inhib \minus mean| / mean', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_md, 'Trial (sorted by motion)',         'FontSize', 6, 'FontWeight', 'bold');
lg_md = legend(ax_md, 'Location', 'best', 'FontSize', 6);
lg_md.ItemTokenSize = [6 6];
set(ax_md, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'YDir', 'normal');
hold(ax_md, 'off');
exportgraphics(fig_md, ...
    sprintf('paper/imp_motion_deviation_%s_%s_en%d.pdf', mn_mot, td_mot, en_mot), ...
    'ContentType', 'vector');
exportgraphics(fig_md, ...
    sprintf('paper/imp_motion_deviation_%s_%s_en%d.png', mn_mot, td_mot, en_mot), ...
    'Resolution', 300);

% ---- Figure 4 (Option A): normalised heatmap + amp strip + deviation strip ----
% All trials pooled, sorted by motion.  Left strip = amplitude group colour.
% Main = normalised dF/F heatmap.  Right strip = normalised |deviation|.
[~, si_n]    = sort(allMot_n, 'ascend');
dfN_sorted   = allDF_n(si_n, :);
ampIdx_sort  = ampIdx_n(si_n);
devNorm_sort = devNorm_n(si_n);
nT_n         = numel(allMot_n);

ampColors_n  = lines(nAmp_mot);   % one colour per amplitude group
ampStrip     = reshape(ampIdx_sort, [], 1);       % nT × 1 integer
devStrip     = reshape(devNorm_sort, [], 1);       % nT × 1

clim_n   = prctile(dfN_sorted(~isnan(dfN_sorted)), [2, 98]);
devClim  = [0, prctile(devNorm_n, 98)];

fig_na = paperFig(12, 6);
tl_na  = tiledlayout(fig_na, 1, 20, 'TileSpacing', 'none', 'Padding', 'compact');

% Left strip: amp group
ax_as = nexttile(tl_na, 1, [1 1]);
imagesc(ax_as, 1, 1:nT_n, ampStrip);
colormap(ax_as, ampColors_n);
clim(ax_as, [0.5, nAmp_mot + 0.5]);
set(ax_as, 'YDir', 'normal', 'XTick', [], 'YTick', [], 'Box', 'off');
ylabel(ax_as, 'Trial (sorted by motion)', 'FontSize', 6, 'FontWeight', 'bold');

% Main heatmap
ax_nh = nexttile(tl_na, 2, [1 17]);
imagesc(ax_nh, tDisp_mot, 1:nT_n, dfN_sorted);
set(ax_nh, 'YDir', 'normal', 'YTick', [], 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
colormap(ax_nh, cmap_bwr);
clim(ax_nh, clim_n);
xline(ax_nh, 0, 'w--', 'LineWidth', 0.8);
mot_n_s = sort(allMot_n, 'ascend');
edges_na = quantile(mot_n_s, [1/3, 2/3]);
t_na     = 1 + (mot_n_s >= edges_na(1)) + (mot_n_s >= edges_na(2));
yline(ax_nh, sum(t_na==1)+0.5,   'w--', 'LineWidth', 0.8);
yline(ax_nh, sum(t_na<=2)+0.5,   'w--', 'LineWidth', 0.8);
xlabel(ax_nh, 'Time (s)', 'FontSize', 6, 'FontWeight', 'bold');
cb_nh = colorbar(ax_nh, 'Location', 'eastoutside');
cb_nh.Label.String   = 'Norm. \DeltaF/F';
cb_nh.Label.FontSize = 6;
cb_nh.FontSize       = 6;

% Right strip: normalised |deviation|
ax_ds = nexttile(tl_na, 19, [1 2]);
imagesc(ax_ds, 1, 1:nT_n, devStrip);
colormap(ax_ds, hot(256));
clim(ax_ds, devClim);
set(ax_ds, 'YDir', 'normal', 'XTick', [], 'YTick', [], 'Box', 'off');
cb_ds = colorbar(ax_ds, 'Location', 'eastoutside');
cb_ds.Label.String   = '|Dev| / mean';
cb_ds.Label.FontSize = 6;
cb_ds.FontSize       = 6;

exportgraphics(fig_na, ...
    sprintf('paper/imp_motion_normheatmap_%s_%s_en%d.pdf', mn_mot, td_mot, en_mot), ...
    'ContentType', 'vector');
exportgraphics(fig_na, ...
    sprintf('paper/imp_motion_normheatmap_%s_%s_en%d.png', mn_mot, td_mot, en_mot), ...
    'Resolution', 300);

% ---- Figure 5 (Option B): normalised deviation scatter + regression ----
% X: motion energy  Y: |deviation| / |Peak_imp_mean|  colour: amplitude group
fig_ns = paperFig(8, 6);
ax_ns  = axes(fig_ns);
hold(ax_ns, 'on');
for iAmp = 1:nAmp_mot
    mk = ampIdx_n == iAmp;
    scatter(ax_ns, allMot_n(mk), devNorm_n(mk), 6, ampColors_n(iAmp, :), ...
        'filled', 'MarkerFaceAlpha', 0.4, 'DisplayName', sprintf('%.2f V', imp_e_mot.uAmp{iAmp}));
end
mdl_ns  = fitlm(allMot_n, devNorm_n);
x_rng   = linspace(min(allMot_n), max(allMot_n), 100)';
[y_fit, ci_fit] = predict(mdl_ns, x_rng);
hf_ns = fill(ax_ns, [x_rng; flipud(x_rng)], [ci_fit(:,1); flipud(ci_fit(:,2))], ...
    [0.5 0.5 0.5], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
hf_ns.HandleVisibility = 'off';
hp_ns = plot(ax_ns, x_rng, y_fit, 'k-', 'LineWidth', 1.2);
hp_ns.HandleVisibility = 'off';
r_ns = corr(allMot_n, devNorm_n, 'rows', 'complete');
p_ns = mdl_ns.Coefficients.pValue(2);
title(ax_ns, sprintf('r = %.2f,  p = %.3f', r_ns, p_ns), ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_ns, 'Motion energy (±1s)', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_ns, '|Peak inhib \minus mean| / mean', 'FontSize', 6, 'FontWeight', 'bold');
lg_ns = legend(ax_ns, 'Location', 'best', 'FontSize', 6);
lg_ns.ItemTokenSize = [6 6];
set(ax_ns, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
hold(ax_ns, 'off');
exportgraphics(fig_ns, ...
    sprintf('paper/imp_motion_devscatter_%s_%s_en%d.pdf', mn_mot, td_mot, en_mot), ...
    'ContentType', 'vector');
exportgraphics(fig_ns, ...
    sprintf('paper/imp_motion_devscatter_%s_%s_en%d.png', mn_mot, td_mot, en_mot), ...
    'Resolution', 300);

% ---- Figure 6 (Option C): quartile mean traces (amplitude-normalised) ----
quartEdges  = quantile(allMot_n, [0.25, 0.50, 0.75]);
quartile_n  = 1 + (allMot_n >= quartEdges(1)) + ...
                  (allMot_n >= quartEdges(2)) + ...
                  (allMot_n >= quartEdges(3));
quartColors = [0.15 0.35 0.80;   % Q1 — dark blue
               0.40 0.65 0.90;   % Q2 — light blue
               0.95 0.55 0.20;   % Q3 — orange
               0.85 0.15 0.15];  % Q4 — red
quartLabels = {'Q1 (lowest motion)', 'Q2', 'Q3', 'Q4 (highest motion)'};

fig_nq = paperFig(6, 4);
ax_nq  = axes(fig_nq);
hold(ax_nq, 'on');
for k = 1:4
    mk = quartile_n == k;
    mu = mean(allDF_n(mk, :), 1, 'omitnan');
    se = std(allDF_n(mk, :), 0, 1, 'omitnan') / sqrt(sum(mk));
    fill(ax_nq, [tDisp_mot, fliplr(tDisp_mot)], [mu+se, fliplr(mu-se)], ...
        quartColors(k, :), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(ax_nq, tDisp_mot, mu, 'Color', quartColors(k, :), 'LineWidth', 1, ...
        'DisplayName', quartLabels{k});
end
xline(ax_nq, 0, 'k--', 'LineWidth', 0.5);
set(ax_nq, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
xlabel(ax_nq, 'Time (s)',        'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_nq, 'Norm. \DeltaF/F', 'FontSize', 6, 'FontWeight', 'bold');
lg_nq = legend(ax_nq, 'Location', 'best', 'FontSize', 6);
lg_nq.ItemTokenSize = [6 6];
hold(ax_nq, 'off');
exportgraphics(fig_nq, ...
    sprintf('paper/imp_motion_quartiles_%s_%s_en%d.pdf', mn_mot, td_mot, en_mot), ...
    'ContentType', 'vector');
exportgraphics(fig_nq, ...
    sprintf('paper/imp_motion_quartiles_%s_%s_en%d.png', mn_mot, td_mot, en_mot), ...
    'Resolution', 300);

%% Freq band power heatmap — one figure per session, subplots per amp
%
% Y-axis: trials sorted by Peak_imp_dev ascending
% X-axis: frequency band centres (0.25–9.75 Hz, 20 bands)
% Color : absolute band power (S_bands), no normalization or z-scoring

fbCtrs = (0:19)*0.5 + 0.25;   % 20 bands, 0.25–9.75 Hz (fixed, same as spectrogram setup)

for expIdx = 1:nExp
    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    % Shared color limit: 98th percentile of all freq power for this experiment
    all_freq_e = vertcat(imp_e.freqSpec{:});
    clim_e     = prctile(all_freq_e(:), 98);

    nCols_f = min(nAmp_e, 4);
    nRows_f = ceil(nAmp_e / nCols_f);

    fig_f = figure('Color','w');
    fig_f.Units    = 'inches';
    fig_f.Position = [1, 1, nCols_f*3.5, nRows_f*3];
    sgtitle(sprintf('%s  %s  e%d — Freq band power', allExperiments(expIdx).mn, ...
        allExperiments(expIdx).td, allExperiments(expIdx).en), ...
        'FontWeight','bold', 'FontSize', 10, 'Interpreter','none');

    for iAmp = 1:nAmp_e
        dev_i  = imp_e.Peak_imp_dev{iAmp}(:);
        freq_i = imp_e.freqSpec{iAmp};         % nTrials × nBands, absolute power
        nUse   = min(numel(dev_i), size(freq_i,1));
        if nUse < 2, continue; end
        dev_i  = dev_i(1:nUse);
        freq_i = freq_i(1:nUse, :);

        [~, sOrd] = sort(dev_i, 'ascend');

        ax = subplot(nRows_f, nCols_f, iAmp);
        imagesc(ax, fbCtrs, 1:nUse, freq_i(sOrd, :));
        colormap(ax, 'hot');
        clim(ax, [0 clim_e]);
        cb = colorbar(ax);  cb.Label.String = 'Power (\DeltaF/F)^2 Hz^{-1}';

        xlabel(ax, 'Frequency (Hz)', 'FontSize', 8);
        ylabel(ax, 'Trial (sorted by dev)', 'FontSize', 8);
        title(ax, sprintf('%.2f V  (n=%d)', imp_e.uAmp{iAmp}, nUse), ...
            'FontSize', 8, 'FontWeight','bold');
        set(ax, 'YDir','normal', 'Box','off', 'TickDir','out', 'FontSize', 8);
        xticks(ax, 0:2:10);
    end
end

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
        hImg = imagesc(ax, fbCtrs, 1:nUse, freq_i(sOrd, :));
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

%% Pre-trial variance sort — motion-excluded (top 25% motion trials removed)
%
% Same scatter + errorbar layout as above, but trials in the top 25% of
% motion energy (imp.mot) are excluded before computing mean/deviation.

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

%% Pre-trial variance vs prediction error — all trials, pooled amps, session 3

selExp_pvp  = 3;
imp_pvp     = allExperiments(selExp_pvp).imp;
preIdx_pvp  = t_win_imp >= -1 & t_win_imp < 0;   % 1 s pre-stim

allPreVar_pvp = [];
allDevN_pvp   = [];

for iAmp = 1:numel(imp_pvp.uAmp)
    df_i = imp_pvp.dfImp{iAmp};
    pk_i = imp_pvp.Peak_imp{iAmp}(:);
    mn_i = imp_pvp.Peak_imp_mean(iAmp);
    if isnan(mn_i) || mn_i == 0, continue; end
    nUse = min(size(df_i,1), numel(pk_i));
    if nUse < 2, continue; end
    allPreVar_pvp = [allPreVar_pvp; var(df_i(1:nUse, preIdx_pvp), 0, 2)]; %#ok<AGROW>
    allDevN_pvp   = [allDevN_pvp;   abs(pk_i(1:nUse) - mn_i) / abs(mn_i)]; %#ok<AGROW>
end

% Sort by pre-trial variance ascending (low at bottom)
[~, si_pvp]   = sort(allPreVar_pvp, 'ascend');
devSorted_pvp = allDevN_pvp(si_pvp);
nT_pvp        = numel(devSorted_pvp);

% Variance tertile colouring
edges_pvp  = quantile(allPreVar_pvp(si_pvp), [1/3, 2/3]);
tert_pvp   = 1 + (allPreVar_pvp(si_pvp) >= edges_pvp(1)) ...
               + (allPreVar_pvp(si_pvp) >= edges_pvp(2));
tColors_pvp = [0.20 0.40 0.80; 0.55 0.25 0.75; 0.85 0.20 0.20];
tLabels_pvp = {'Low var', 'Mid var', 'High var'};

% Linear fit: trial rank ~ prediction error
mdl_pvp  = fitlm(allDevN_pvp, (1:nT_pvp)');
xr_pvp   = linspace(min(allDevN_pvp), max(allDevN_pvp), 100)';
yfit_pvp = predict(mdl_pvp, xr_pvp);

% Correlation stats
r_pvp = corr(allPreVar_pvp, allDevN_pvp, 'rows', 'complete');
[~, p_pvp] = corr(allPreVar_pvp, allDevN_pvp, 'rows', 'complete');

fig_pvp = paperFig(6, 6);
ax_pvp  = axes(fig_pvp);
hold(ax_pvp, 'on');
for k = 1:3
    mk = tert_pvp == k;
    scatter(ax_pvp, devSorted_pvp(mk), find(mk), 6, ...
        tColors_pvp(k,:), 'filled', 'MarkerFaceAlpha', 0.5, ...
        'DisplayName', tLabels_pvp{k});
end
% hl_pvp = plot(ax_pvp, xr_pvp, yfit_pvp, 'k-', 'LineWidth', 1.5);
hl_pvp.HandleVisibility = 'off';
title(ax_pvp, sprintf('All trials  r = %.2f  p = %.3f', r_pvp, p_pvp), ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_pvp, 'Prediction error (norm. |dev|)',       'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pvp, 'Trial (sorted by pre-trial variance)', 'FontSize', 6, 'FontWeight', 'bold');
lg_pvp = legend(ax_pvp, 'Location', 'best', 'FontSize', 6);
lg_pvp.ItemTokenSize = [6 6];
set(ax_pvp, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'YDir', 'normal');
hold(ax_pvp, 'off');

mn_pvp = allExperiments(selExp_pvp).mn;
td_pvp = allExperiments(selExp_pvp).td;
en_pvp = allExperiments(selExp_pvp).en;
exportgraphics(fig_pvp, ...
    sprintf('paper/imp_prevar_deviation_%s_%s_en%d.pdf', mn_pvp, td_pvp, en_pvp), ...
    'ContentType', 'vector');
exportgraphics(fig_pvp, ...
    sprintf('paper/imp_prevar_deviation_%s_%s_en%d.png', mn_pvp, td_pvp, en_pvp), ...
    'Resolution', 300);

%% Poster figure — brain state predicts impulse predictability (motion-cleaned)
%
% Session selExp_poster, all amps pooled, top-25%-motion trials excluded.
% Panel A: freq heatmap (trials sorted by norm |deviation|, X = freq bands)
% Panel B: mean power per band across prediction-error quintiles
% Panel C: pre-trial variance vs norm |deviation|, coloured by motion tertile

selExp_poster  = 3;
imp_p          = allExperiments(selExp_poster).imp;
nAmp_p         = numel(imp_p.uAmp);
preIdx_poster  = t_win_imp >= -1 & t_win_imp < 0;   % 1 s pre-stim (35 samples)
tertColors_p   = [0.20 0.40 0.80; 0.55 0.25 0.75; 0.85 0.20 0.20];
lgdStr_p       = {'Low motion', 'Mid motion', 'High motion'};

% Global motion threshold: 75th percentile across all amps
all_mot_p   = cell2mat(cellfun(@(x) x(:), imp_p.mot, 'UniformOutput', false));
motThresh_p = prctile(all_mot_p, 75);

% Pool across amps (motion-cleaned, normalised)
allFreq_p   = [];
allDevN_p   = [];
allPreVar_p = [];
allMot_p    = [];

for iAmp = 1:nAmp_p
    df_i   = imp_p.dfImp{iAmp};
    freq_i = imp_p.freqSpec{iAmp};
    mot_i  = imp_p.mot{iAmp}(:);
    pk_i   = imp_p.Peak_imp{iAmp}(:);
    mn_i   = imp_p.Peak_imp_mean(iAmp);
    if isnan(mn_i) || mn_i == 0, continue; end
    nUse = min([size(df_i,1), size(freq_i,1), numel(mot_i), numel(pk_i)]);
    if nUse < 2, continue; end
    df_i   = df_i(1:nUse, :);
    freq_i = freq_i(1:nUse, :);
    mot_i  = mot_i(1:nUse);
    pk_i   = pk_i(1:nUse);

    keep   = mot_i <= motThresh_p;
    if sum(keep) < 2, continue; end
    df_i   = df_i(keep, :);
    freq_i = freq_i(keep, :);
    mot_i  = mot_i(keep);
    pk_i   = pk_i(keep);

    devN_i   = abs(pk_i - mn_i) / abs(mn_i);
    preVar_i = var(df_i(:, preIdx_poster), 0, 2);

    allFreq_p   = [allFreq_p;   freq_i];   %#ok<AGROW>
    allDevN_p   = [allDevN_p;   devN_i];   %#ok<AGROW>
    allPreVar_p = [allPreVar_p; preVar_i]; %#ok<AGROW>
    allMot_p    = [allMot_p;    mot_i];    %#ok<AGROW>
end
nT_p = numel(allDevN_p);

% Sort by prediction error for heatmap
[~, si_p]     = sort(allDevN_p, 'ascend');
freq_sorted_p = allFreq_p(si_p, :);

% Quintile IDs (based on unsorted devN, for Panel B)
qEdges_p = quantile(allDevN_p, linspace(0, 1, 6));
qID_p    = discretize(allDevN_p, qEdges_p);
qID_p(isnan(qID_p)) = 1;

% Motion tertile (for Panel C colour)
mEdges_p = quantile(allMot_p, [1/3, 2/3]);
motTert_p = 1 + (allMot_p >= mEdges_p(1)) + (allMot_p >= mEdges_p(2));

% ── Figure ──────────────────────────────────────────────────────────────
fig_poster = paperFig(18, 6);
tl_poster  = tiledlayout(fig_poster, 1, 3, 'TileSpacing', 'tight', 'Padding', 'compact');

% --- Panel A: freq heatmap sorted by prediction error ---
ax_pA = nexttile(tl_poster);
clim_pA = [0, prctile(allFreq_p(:), 98)];
imagesc(ax_pA, fbCtrs, 1:nT_p, freq_sorted_p);
colormap(ax_pA, 'hot');
clim(ax_pA, clim_pA);
set(ax_pA, 'YDir', 'normal', 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
xlabel(ax_pA, 'Frequency (Hz)',               'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pA, 'Trial (sorted by pred. error)', 'FontSize', 6, 'FontWeight', 'bold');
title(ax_pA, 'Spectral content vs prediction error', 'FontSize', 6, 'FontWeight', 'bold');
xticks(ax_pA, 0:2:10);
nPerQ_p = round(nT_p / 5);
for iq = 1:4
    yline(ax_pA, iq*nPerQ_p + 0.5, 'w--', 'LineWidth', 0.6, 'HandleVisibility', 'off');
end
cb_pA = colorbar(ax_pA, 'Location', 'eastoutside');
cb_pA.Label.String   = 'Power (\DeltaF/F)^2 Hz^{-1}';
cb_pA.Label.FontSize = 6;
cb_pA.FontSize       = 6;

% --- Panel B: mean power per freq band by prediction-error quintile ---
ax_pB = nexttile(tl_poster);
qColors_p = [0.15 0.35 0.80;
             0.40 0.60 0.90;
             0.70 0.70 0.70;
             0.95 0.55 0.20;
             0.85 0.15 0.15];
qLabels_p = {'Q1 (low err)','Q2','Q3','Q4','Q5 (high err)'};
hold(ax_pB, 'on');
for q = 1:5
    mk   = qID_p == q;
    mu_q = mean(allFreq_p(mk, :), 1, 'omitnan');
    se_q = std(allFreq_p(mk, :), 0, 1, 'omitnan') / sqrt(sum(mk));
    hfq  = fill(ax_pB, [fbCtrs, fliplr(fbCtrs)], [mu_q+se_q, fliplr(mu_q-se_q)], ...
        qColors_p(q,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    hfq.HandleVisibility = 'off';
    plot(ax_pB, fbCtrs, mu_q, 'Color', qColors_p(q,:), 'LineWidth', 1, ...
        'DisplayName', qLabels_p{q});
end
hold(ax_pB, 'off');
set(ax_pB, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
xlabel(ax_pB, 'Frequency (Hz)',                    'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pB, 'Mean power (\DeltaF/F)^2 Hz^{-1}', 'FontSize', 6, 'FontWeight', 'bold');
title(ax_pB, 'Power by error quintile',            'FontSize', 6, 'FontWeight', 'bold');
xticks(ax_pB, 0:2:10);
lg_pB = legend(ax_pB, 'Location', 'best', 'FontSize', 6);
lg_pB.ItemTokenSize = [6 6];

% --- Panel C: pre-trial variance vs prediction error ---
ax_pC = nexttile(tl_poster);
hold(ax_pC, 'on');
for k = 1:3
    mk = motTert_p == k;
    scatter(ax_pC, allPreVar_p(mk), allDevN_p(mk), 6, ...
        tertColors_p(k,:), 'filled', 'MarkerFaceAlpha', 0.5, ...
        'DisplayName', lgdStr_p{k});
end
mdl_pC = fitlm(allPreVar_p, allDevN_p);
xr_pC  = linspace(min(allPreVar_p), max(allPreVar_p), 100)';
[yf_pC, ci_pC] = predict(mdl_pC, xr_pC);
hfc = fill(ax_pC, [xr_pC; flipud(xr_pC)], [ci_pC(:,1); flipud(ci_pC(:,2))], ...
    [0.5 0.5 0.5], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
hfc.HandleVisibility = 'off';
hpc = plot(ax_pC, xr_pC, yf_pC, 'k-', 'LineWidth', 1.2);
hpc.HandleVisibility = 'off';
r_pC = corr(allPreVar_p, allDevN_p, 'rows', 'complete');
p_pC = mdl_pC.Coefficients.pValue(2);
title(ax_pC, sprintf('r = %.2f   p = %.3f', r_pC, p_pC), ...
    'FontSize', 6, 'FontWeight', 'bold');
xlabel(ax_pC, 'Pre-trial variance (\DeltaF/F)^2', 'FontSize', 6, 'FontWeight', 'bold');
ylabel(ax_pC, 'Prediction error (norm. |dev|)',    'FontSize', 6, 'FontWeight', 'bold');
title(ax_pC, sprintf('Pre-trial state  r=%.2f  p=%.3f', r_pC, p_pC), ...
    'FontSize', 6, 'FontWeight', 'bold');
lg_pC = legend(ax_pC, 'Location', 'best', 'FontSize', 6);
lg_pC.ItemTokenSize = [6 6];
set(ax_pC, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6);
hold(ax_pC, 'off');

% --- Export ---
mn_p = allExperiments(selExp_poster).mn;
td_p = allExperiments(selExp_poster).td;
en_p = allExperiments(selExp_poster).en;
exportgraphics(fig_poster, ...
    sprintf('paper/imp_brainstate_poster_%s_%s_en%d.pdf', mn_p, td_p, en_p), ...
    'ContentType', 'vector');
exportgraphics(fig_poster, ...
    sprintf('paper/imp_brainstate_poster_%s_%s_en%d.png', mn_p, td_p, en_p), ...
    'Resolution', 300);

% ── Spatial spread vs amplitude ───────────────────────────────────────────
pxMM      = 0.173;    % mm per pixel
selExp_sp = selExp;   % session to analyse; change independently if needed

uA_sp     = allExperiments(selExp_sp).uAmp(:);
imp_s     = allExperiments(selExp_sp).imp;
mimg_s    = allExperiments(selExp_sp).mimg;
brainMask = allExperiments(selExp_sp).brainMask;
mI1_s     = allExperiments(selExp_sp).mI1;  
nAmp_sp   = numel(uA_sp);
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

% Per-amplitude FWHM threshold: 50% of each map's own peak inhibition.
% This avoids a global noise threshold that would make all contours identical
% when the noise floor is much smaller than any amplitude's response.
spread_area  = nan(nAmp_sp, 1);
spread_r     = nan(nAmp_sp, 1);
thr_per_amp  = nan(nV_sp, 1);
for k = 1:nV_sp
    iA = validIdx_sp(k);
    map_k = resp_maps(:, k);
    thr_per_amp(k) = 0.5 * min(map_k);   % 50% of peak inhibition (FWHM)
    n_px = sum(map_k < thr_per_amp(k));
    spread_area(iA) = n_px * pxMM^2;
    spread_r(iA)    = sqrt(spread_area(iA) / pi);   % effective radius (mm)
    fprintf('  amp=%.2f mW  peak=%.3f%%dF/F  thr=%.3f  area=%.2f mm²  r=%.2f mm\n', ...
        uA_sp(iA)/3, min(map_k), thr_per_amp(k), spread_area(iA), spread_r(iA));
end

% ── Figure ─────────────────────────────────────────────────────────────────
fig_sp = paperFig(12, 4);
tlo_sp = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% Panel A: mean brain image + one FWHM contour per amplitude
ax_map = nexttile(tlo_sp);
imagesc(ax_map, mimg_s);
colormap(ax_map, gray);
axis(ax_map, 'image');
axis(ax_map, 'off');
hold(ax_map, 'on');

cMap_sp = parula(nV_sp + 2);
for k = 1:nV_sp
    iA       = validIdx_sp(k);
    map_full = nan(nr_s * nc_s, 1);
    map_full(brainMask) = resp_maps(:, k);
    map_2d   = reshape(map_full, nr_s, nc_s);
    contour(ax_map, map_2d, [thr_per_amp(k) thr_per_amp(k)], ...
        'Color', cMap_sp(k, :), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%.2f mW', uA_sp(iA)/3));
end

% 1-mm scale bar (bottom-left corner)
sb_px = 1 / pxMM;
line(ax_map, [10, 10 + sb_px], [nr_s - 15, nr_s - 15], 'Color', 'w', 'LineWidth', 2);
text(ax_map, 10, nr_s - 8, '1 mm', 'Color', 'w', 'FontSize', 6, 'FontWeight', 'bold');
title(ax_map, 'Inhibition contours (FWHM per amplitude)', ...
    'FontSize', 6, 'FontWeight', 'bold');

% Panel B: effective spread radius vs amplitude
ax_sp = nexttile(tlo_sp);
hold(ax_sp, 'on');
xAmp_sp = uA_sp(validAmp_sp) / 3;
yR_sp   = spread_r(validAmp_sp);
plot(ax_sp, xAmp_sp, yR_sp, 'o-', ...
    'Color', [0.15 0.35 0.8], 'MarkerFaceColor', [0.15 0.35 0.8], ...
    'MarkerSize', 4, 'LineWidth', 1.5);
xlabel(ax_sp, 'Amplitude (mW)', 'FontWeight', 'bold', 'FontSize', 6);
ylabel(ax_sp, 'Spread radius (mm)', 'FontWeight', 'bold', 'FontSize', 6);
set(ax_sp, 'Box', 'off', 'TickDir', 'out', 'FontSize', 6, 'FontWeight', 'bold');

mn_sp = allExperiments(selExp_sp).mn;
td_sp = allExperiments(selExp_sp).td;
en_sp = allExperiments(selExp_sp).en;
exportgraphics(fig_sp, sprintf('paper/spatial_spread_%s_%s_en%d.pdf', mn_sp, td_sp, en_sp), ...
    'ContentType', 'vector');
end