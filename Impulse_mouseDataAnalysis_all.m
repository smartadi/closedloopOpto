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
S_bands = abs(S_spec(1:nBands, :)).^2;
S_norm  = S_bands ./ (sum(S_bands, 1) + eps);   % 20 × nSpecTime, relative power
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
            freqSpec(j,:) = mean(S_norm(:, i_lo:i_hi), 2)';
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
lgd = legend('Box','off','FontSize',6,'FontWeight','bold','Location','southeast');
lgd.ItemTokenSize = [10 6];
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

nExp = numel(allExperiments);
hLegend = gobjects(nExp,1);              % one legend entry per experiment
legTxt  = cell(nExp,1);

for expIdx = 1:nExp
    allVals = allExperiments(expIdx).allVals;
    groupLabels = allExperiments(expIdx).groupLabels;

    [ug,~,idx] = unique(groupLabels, 'stable');
    meanVals = accumarray(idx(:), allVals(:), [], @(v) mean(v,'omitnan'));
    semVals  = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan')/sqrt(sum(~isnan(v))))  ;

    xpos     = str2double(cellstr(ug))';          % true amplitude values
    xOffset  = (expIdx - 2) * 0.005;             % small jitter to separate overlapping sessions
    xpos     = xpos + xOffset;
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

%% Combined plot — median ± IQR
figM = figure('Color','w'); hold on
figM.Units = 'centimeters';  figM.PaperUnits = 'centimeters';
figM.Position = [0 0 PW_c PH_c];
figM.PaperSize = [PW_c PH_c];  figM.PaperPosition = [0 0 PW_c PH_c];
h1m = yline(0,'--k');

hLegendM = gobjects(nExp,1);
legTxtM   = cell(nExp,1);

for expIdx = 1:nExp
    allVals_e     = allExperiments(expIdx).allVals;
    groupLabels_e = allExperiments(expIdx).groupLabels;

    [ug_m,~,idx_m] = unique(groupLabels_e, 'stable');
    medVals = accumarray(idx_m(:), allVals_e(:), [], @(v) median(v,'omitnan'));
    q25     = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v,25));
    q75     = accumarray(idx_m(:), allVals_e(:), [], @(v) prctile(v,75));

    xpos_m    = str2double(cellstr(ug_m))';
    xpos_m    = xpos_m + (expIdx - 2) * 0.005;
    capWidth_m = 0.003;

    for j = 1:numel(ug_m)
        plot([xpos_m(j) xpos_m(j)], [q25(j), q75(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [q25(j) q25(j)], ...
            '-', 'LineWidth', 1, 'Color', expColors(expIdx,:));
        plot([xpos_m(j)-capWidth_m xpos_m(j)+capWidth_m], [q75(j) q75(j)], ...
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
%%{ =========================================================
%  PARAMETRIC MODEL — SINGLE SESSION
%  Transfer function with dead-time (lag) compensation.
%  Uses DF_imp / uAmp / t_win / fs from the last loop iteration.
%
%  Strategy: since input is a known impulse, output = impulse response
%  directly.  Estimate Td from peak of |response|, then fit the
%  lag-compensated decaying tail analytically:
%
%    1-pole:  h(t) = A * exp(-t/tau)
%             H(s) = Kp/(tau*s+1) * exp(-Td*s),  Kp = A*tau
%             pole: p = -1/tau
%
%    2-pole:  h(t) = A1*exp(-t/tau1) + A2*exp(-t/tau2)
%             H(s) = Kp/((tau1*s+1)(tau2*s+1)) * exp(-Td*s)
%             poles: p1=-1/tau1, p2=-1/tau2
%
%  Order selected per amplitude by AIC.
%  Requires: Optimization Toolbox (lsqcurvefit) only.
%%{ =========================================================

selExp  = 2;                                    % <-- change to target session
DF_this = allExperiments(selExp).DF_imp;        % nAmps x nTime
uA_this = allExperiments(selExp).uAmp(:);       % nAmps x 1  (assumes sorted ascending)
nAmp    = size(DF_this, 1);
dt      = 1/fs;

iPost = find(t_win >= 0);
tPost = t_win(iPost);    % post-stim time, starting at 0 (seconds)
tVec  = tPost(:);
nPost = numel(tPost);

lsqOpt = optimoptions('lsqcurvefit','Display','off', ...
    'MaxFunctionEvaluations',10000,'MaxIterations',2000, ...
    'FunctionTolerance',1e-8,'StepTolerance',1e-8);

% ---- Select high-SNR amplitudes to fit the shared shape -----------------
% Low amplitudes are below noise floor; only use the top nHighKeep.
nHighKeep = max(2, ceil(nAmp/2));   % <-- change to e.g. 2 if only top 2 are clean
highIdx   = (nAmp - nHighKeep + 1) : nAmp;   % indices of highest amps
nFit      = numel(highIdx);

fprintf('\nFitting single-session TF on amplitudes: ');
fprintf('%.3f  ', uA_this(highIdx)); fprintf('\n');

% ---- Model shapes (full response from t = 0) ----------------------------
%
%  1-pole:  h(t; tau, Td)
%         = exp(-(t-Td)/tau) .* (t >= Td)
%           → jump at Td, exponential decay; pole at p = -1/tau
%
%  2-pole:  h(t; tau1, tau2, Td)           [tau1 < tau2]
%         = (exp(-(t-Td)/tau1) - exp(-(t-Td)/tau2)) / (tau1-tau2) .* (t>=Td)
%           → zero at Td, smooth rise to peak, exponential decay
%           → poles at p1=-1/tau1, p2=-1/tau2

h1 = @(p, t)  exp(-(t - p(2))  ./ p(1)) .* (t >= p(2));
h2 = @(p, t) (exp(-(t-p(3))./p(1)) - exp(-(t-p(3))./p(2))) ...
             ./ (p(1) - p(2) + eps) .* (t >= p(3));

% ---- Normalize each trace by its own amplitude before shape fitting -----
% This removes amplitude-weighting bias so every trace contributes equally
% to the shape estimate regardless of stimulus magnitude.
% K per amplitude is recovered by linear projection afterward.
yNorm  = DF_this(highIdx, iPost) ./ uA_this(highIdx);   % nFit x nPost (unit IR per amp)
hMean  = mean(yNorm, 1)';                                % nPost x 1 (mean unit IR)

iPk = min(round(tPeak * fs) + 1, nPost);   % index near expected peak

% ---- 1-pole fit (shape only, no K) --------------------------------------
p0_1 = [0.30,  tPeak];
lb_1 = [0.01,  0.005];
ub_1 = [5.0,   tPost(end)*0.8];
try
    p1j = lsqcurvefit(h1, p0_1, tVec, hMean, lb_1, ub_1, lsqOpt);
catch ME
    warning('1-pole fit: %s', ME.message);  p1j = p0_1;
end

% ---- 2-pole fit (shape only, no K) --------------------------------------
p0_2 = [0.04,  0.50,  tPeak*0.25];
lb_2 = [0.005, 0.05,  0.005];
ub_2 = [0.4,   5.0,   tPeak];
try
    p2j = lsqcurvefit(h2, p0_2, tVec, hMean, lb_2, ub_2, lsqOpt);
catch ME
    warning('2-pole fit: %s', ME.message);  p2j = p0_2;
end

% ---- AIC on mean normalised trace (k = shape params only) ---------------
n     = numel(hMean);
yHat1 = h1(p1j, tVec);
yHat2 = h2(p2j, tVec);
RSS1  = sum((hMean - yHat1).^2);
RSS2  = sum((hMean - yHat2).^2);
aic1  = n*log(RSS1/n + eps) + 2*2;
aic2  = n*log(RSS2/n + eps) + 2*3;
R2_1  = 1 - RSS1 / max(sum((hMean - mean(hMean)).^2), eps);
R2_2  = 1 - RSS2 / max(sum((hMean - mean(hMean)).^2), eps);

if aic2 < aic1
    modelOrder = 2;
    Td_fit   = p2j(3);  tau1_fit = p2j(1);  tau2_fit = p2j(2);
    h_shape  = @(t) h2(p2j(1:3), t);
    R2_fit   = R2_2;
else
    modelOrder = 1;
    Td_fit   = p1j(2);  tau1_fit = p1j(1);  tau2_fit = NaN;
    h_shape  = @(t) h1(p1j(1:2), t);
    R2_fit   = R2_1;
end

fprintf('\n=== Single-Session TF — Session %d ===\n', selExp);
fprintf('  Model order : %d-pole\n', modelOrder);
fprintf('  AIC (1-pole): %.2f   AIC (2-pole): %.2f\n', aic1, aic2);
fprintf('  Fit R2      : %.3f\n', R2_fit);
fprintf('  T_d         : %.1f ms\n', Td_fit*1000);
fprintf('  tau1        : %.1f ms   (pole p1 = %.3f rad/s)\n', tau1_fit*1000, -1/tau1_fit);
if modelOrder==2
    fprintf('  tau2        : %.1f ms   (pole p2 = %.3f rad/s)\n', tau2_fit*1000, -1/tau2_fit);
    tStar = tau1_fit*tau2_fit/(tau2_fit-tau1_fit) * log(tau2_fit/tau1_fit);
    fprintf('  Peak time   : Td + %.1f ms = %.1f ms after stim\n', ...
        tStar*1000, (Td_fit+tStar)*1000);
end

% ---- Project K for ALL amplitudes (shape fixed, linear solve) -----------
% Given fixed h_shape(t), K_i = argmin ||y_i - K*h||^2 = (h'*y_i)/(h'*h)
hVec  = h_shape(tVec);          % nPost x 1
K_all = nan(nAmp, 1);
for i = 1:nAmp
    y_i    = DF_this(i, iPost)';
    K_all(i) = (hVec' * y_i) / max(hVec' * hVec, eps);
end

% ---- Overlay plot: all amplitudes, single model -------------------------
figure('Color','w','Position',[50 50 300*nAmp 360]);
tlo = tiledlayout(1, nAmp, 'TileSpacing','compact','Padding','tight');

for i = 1:nAmp
    y_i    = DF_this(i, iPost)';
    yModel = K_all(i) * hVec;
    ss_res = sum((y_i - yModel).^2);
    ss_tot = sum((y_i - mean(y_i)).^2);
    r2_i   = 1 - ss_res / max(ss_tot, eps);

    nexttile; hold on;
    plot(tPost*1000, y_i,    'k',  'LineWidth', 2.5);
    plot(tPost*1000, yModel, 'r--','LineWidth', 2.5);
    xline(Td_fit*1000, ':b', 'T_d','LabelVerticalAlignment','bottom','FontSize',8);

    flagStr = ''; if ismember(i, highIdx), flagStr = ' [fit]'; end
    title(sprintf('Amp=%.2fV%s\nK=%.3f  R^2=%.2f', ...
        uA_this(i), flagStr, K_all(i), r2_i), 'FontSize', 8);
    xlabel('Time (ms)'); ylabel('dF/F (%)');
    ax=gca; ax.Box='off'; ax.TickDir='out'; ax.LineWidth=1.2;
    if i==1, legend({'data','model'},'Box','off','FontSize',7,'Location','southeast'); end
end
title(tlo, sprintf('%d-pole TF, T_d=%.0f ms — Session %d', ...
    modelOrder, Td_fit*1000, selExp), 'FontWeight','bold');

% ---- Cross-amplitude validation (LOAO on high-amp subset) ---------------
% Fit shape on nHighKeep-1 amplitudes, predict the held-out high-amp trace.
% Tests whether single TF shape transfers across amplitudes.
crossR2 = nan(nFit, 1);

for iCV = 1:nFit
    cvTrainIdx = highIdx(setdiff(1:nFit, iCV));
    if isempty(cvTrainIdx), crossR2(iCV)=NaN; continue; end

    % normalize training traces by amplitude, take mean → unit IR estimate
    hTrMean = mean(DF_this(cvTrainIdx, iPost) ./ uA_this(cvTrainIdx), 1)';

    % refit shape on training mean (same model order as selected above)
    if modelOrder == 2
        try
            pCV = lsqcurvefit(h2, p0_2, tVec, hTrMean, lb_2, ub_2, lsqOpt);
        catch
            crossR2(iCV) = NaN; continue;
        end
        hCV = h2(pCV, tVec);
    else
        try
            pCV = lsqcurvefit(h1, p0_1, tVec, hTrMean, lb_1, ub_1, lsqOpt);
        catch
            crossR2(iCV) = NaN; continue;
        end
        hCV = h1(pCV, tVec);
    end

    % project K for held-out amplitude and evaluate
    y_val = DF_this(highIdx(iCV), iPost)';
    K_cv  = (hCV' * y_val) / max(hCV' * hCV, eps);
    yPred = K_cv * hCV;
    crossR2(iCV) = 1 - sum((y_val-yPred).^2) / max(sum((y_val-mean(y_val)).^2), eps);
end

fprintf('\n=== Cross-Amplitude Validation (LOAO on high-SNR amps) ===\n');
for iCV = 1:nFit
    fprintf('  Hold-out amp=%.3fV:  R2=%.3f\n', uA_this(highIdx(iCV)), crossR2(iCV));
end
fprintf('  Mean R2 = %.3f +/- %.3f\n', mean(crossR2,'omitnan'), std(crossR2,'omitnan'));

% ---- Summary: gain vs amplitude + Bode magnitude -----------------------
isTrain = ismember(1:nAmp, highIdx)';

figure('Color','w','Position',[100 100 750 300]);
tlo2 = tiledlayout(1, 2, 'TileSpacing','compact','Padding','compact');

nexttile; hold on;
plot(uA_this(~isTrain), K_all(~isTrain), 'o', ...
    'Color',[0.6 0.6 0.6],'MarkerFaceColor',[0.6 0.6 0.6],'MarkerSize',8,'LineWidth',1.5);
plot(uA_this(isTrain),  K_all(isTrain),  'ko', ...
    'MarkerFaceColor','k','MarkerSize',8,'LineWidth',2);
plin = polyfit(uA_this(isTrain), K_all(isTrain), 1);
xf   = linspace(0, max(uA_this)*1.1, 100);
plot(xf, polyval(plin, xf), 'r--', 'LineWidth', 1.5);
xlabel('Amplitude (V)','FontWeight','bold');
ylabel('Gain K','FontWeight','bold');
title('Gain vs Amplitude (linearity check)');
legend({'predict (low SNR)','fit','linear'},'Box','off','Location','best','FontSize',8);
ax=gca; ax.Box='off'; ax.TickDir='out'; ax.LineWidth=1.5;

nexttile;
omega = logspace(-1, 3, 500);
if modelOrder==1
    H_w = exp(-1i*omega*Td_fit) ./ (1 + 1i*omega*tau1_fit);
else
    H_w = exp(-1i*omega*Td_fit) ./ ((1+1i*omega*tau1_fit).*(1+1i*omega*tau2_fit));
end
semilogx(omega/(2*pi), 20*log10(abs(H_w)), 'k', 'LineWidth', 2);
xlabel('Frequency (Hz)','FontWeight','bold');
ylabel('|H| (dB, normalised)','FontWeight','bold');
title(sprintf('%d-pole Bode, T_d=%.0f ms', modelOrder, Td_fit*1000));
ax=gca; ax.Box='off'; ax.TickDir='out'; ax.LineWidth=1.5; grid on;

title(tlo2, sprintf('Session %d — TF Summary', selExp), 'FontWeight','bold');
%}

%% Motion vs Peak_imp deviation — one figure per session, subplots per amp
%
% X: motion energy = sum(mv_z, stim±1s)  (imp.mot, window already set to ±35 samples)
% Y: |Peak_imp − mean(Peak_imp)| for that amp group  (imp.Peak_imp_dev)

nExp = numel(allExperiments);

for expIdx = 1:nExp
    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

    nCols_m = min(nAmp_e, 4);
    nRows_m = ceil(nAmp_e / nCols_m);

    fig_m = figure('Color','w');
    fig_m.Units    = 'inches';
    fig_m.Position = [1, 1, nCols_m*3, nRows_m*3];
    sgtitle(sprintf('%s  %s  e%d', allExperiments(expIdx).mn, ...
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
        scatter(ax, mot_i, dev_i, 25, [0.2 0.4 0.8], 'o', 'filled', ...
            'MarkerFaceAlpha', 0.6);

        r = corr(mot_i, dev_i, 'rows','complete');
        title(ax, sprintf('%.2f V   (n=%d,  r=%.2f)', imp_e.uAmp{iAmp}, nUse, r), ...
            'FontSize', 8, 'FontWeight','bold');
        xlabel(ax, 'Motion energy (±1s)', 'FontSize', 8);
        ylabel(ax, '|Peak inhib − mean|', 'FontSize', 8);
        set(ax, 'Box','off', 'TickDir','out', 'FontSize', 8);
    end
end

%% Freq band power heatmap — one figure per session, subplots per amp
%
% Y-axis: trials sorted by Peak_imp_dev ascending
% X-axis: frequency band centres (0.25–9.75 Hz, 20 bands)
% Color : relative band power (band/total), averaged over stim±1s spectrogram bins

fbCtrs = (0:19)*0.5 + 0.25;   % 20 bands, 0.25–9.75 Hz (fixed, same as spectrogram setup)

for expIdx = 1:nExp
    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

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
        freq_i = imp_e.freqSpec{iAmp};         % nTrials × nBands
        nUse   = min(numel(dev_i), size(freq_i,1));
        if nUse < 2, continue; end
        dev_i  = dev_i(1:nUse);
        freq_i = freq_i(1:nUse, :);

        % sort trials by Peak_imp_dev ascending
        [dev_sorted, sOrd] = sort(dev_i, 'ascend');
        img = freq_i(sOrd, :);      % nTrials × nBands, y=trial(sorted), x=band

        ax = subplot(nRows_f, nCols_f, iAmp);
        imagesc(ax, fbCtrs, 1:nUse, img);
        colormap(ax, 'hot');
        clim_val = prctile(img(:), 98);
        if clim_val > 0
            clim(ax, [0, clim_val]);
        end
        colorbar(ax);

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
%   bot: per-trial vs mean relative band power

t_win_imp = -tWin : 1/35 : tWin;   % time vector matching df_imp columns

for expIdx = 1:nExp
    imp_e  = allExperiments(expIdx).imp;
    nAmp_e = numel(imp_e.uAmp);
    if nAmp_e == 0, continue; end

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
        img = freq_i(sOrd, :);

        ax = subplot(nRows_f, nCols_f, iAmp);
        hImg = imagesc(ax, fbCtrs, 1:nUse, img);
        colormap(ax, 'hot');
        clim_val = prctile(img(:), 98);
        if clim_val > 0, clim(ax, [0, clim_val]); end
        colorbar(ax);
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