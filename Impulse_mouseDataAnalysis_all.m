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
%% =========================================================
%  TF FIT — all amplitudes, session mean
%  Knobs: selExp, nPoles (1 or 2), nLeads (0 or 1)
%  nLeads=1 adds one numerator zero → response can start at t=0
%  (more responsive / faster onset)
%% =========================================================

selExp   = 3;        % <-- target session
maxPoles = 3;        % <-- sweep 1..maxPoles
maxZeros = 2;        % <-- sweep 0..min(np-1, maxZeros)

DF_s   = allExperiments(selExp).DF_imp;
uA_s   = allExperiments(selExp).uAmp(:);
nAmp_s = numel(uA_s);

% Post-stim window 0 to +1 s
t_full = -tWin : 1/fs : tWin;
iPost  = find(t_full >= 0 & t_full <= 1);
tPost  = t_full(iPost)';
Ts     = 1/fs;

% Normalise each amplitude by its input voltage → all collapse to h(t)
% Exclude zero-amplitude rows (inserted missing-event placeholders)
validAmp = uA_s > 0;
h_norm   = mean(bsxfun(@rdivide, DF_s(validAmp, iPost), uA_s(validAmp)), 1, 'omitnan')';
validT_h = isfinite(h_norm);   % guards against NaN and Inf
nT_h     = sum(validT_h);

% Single iddata: unit impulse in, normalised response out
% Prepend nPre zeros (toolbox requirement for transient data)
nPre    = maxPoles + maxZeros + 2;
u_fit   = [zeros(nPre,1); 1; zeros(nT_h-1, 1)];
y_fit   = [zeros(nPre,1); h_norm(validT_h)];
data_fit = iddata(y_fit, u_fit, Ts);

% Sweep over (np, nz): strictly proper → nz < np
tfOpt    = tfestOptions('EnforceStability', false, 'Display', 'off');
allMdls  = {};
mdlNames = {};
res      = struct('np',{},'nz',{},'AIC',{},'FPE',{},'sys',{});
ri       = 0;
for np = 1:maxPoles
    for nz = 0:min(np-1, maxZeros)
        try
            sys_i = tfest(data_fit, np, nz, tfOpt);
            ri = ri + 1;
            res(ri).np  = np;
            res(ri).nz  = nz;
            res(ri).AIC = aic(sys_i);
            res(ri).FPE = fpe(sys_i);
            res(ri).sys = sys_i;
            allMdls{end+1}  = sys_i; %#ok<SAGROW>
            mdlNames{end+1} = sprintf('%dp%dz', np, nz); %#ok<SAGROW>
        catch ME
            fprintf('  tfest(%dp%dz) failed: %s\n', np, nz, ME.message);
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
fprintf('  np  nz     AIC       FPE\n');
for r = 1:numel(res)
    mk = ''; if r == iBest, mk = '  <-- best'; end
    fprintf('  %d   %d  %8.2f  %10.4f%s\n', res(r).np, res(r).nz, res(r).AIC, res(r).FPE, mk);
end
fprintf('Best: %dp/%dz\n', res(iBest).np, res(iBest).nz);

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
tfStr = sprintf('Session %d — best TF: %dp/%dz  (AIC=%.1f)', ...
    selExp, res(iBest).np, res(iBest).nz, res(iBest).AIC);
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
        ylabel(ax, '|Peak inhib − mean|', 'FontSize', 8);
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

        % sort trials by Peak_imp_dev ascending; z-score each freq column across trials
        [~, sOrd] = sort(dev_i, 'ascend');
        img_z = zscore(freq_i(sOrd, :), 0, 1);   % nTrials × nBands

        nC  = 256;
        bwr = [linspace(0.2,1,nC/2)' linspace(0.3,1,nC/2)' ones(nC/2,1);
               ones(nC/2,1) linspace(1,0.3,nC/2)' linspace(1,0.2,nC/2)'];

        ax = subplot(nRows_f, nCols_f, iAmp);
        imagesc(ax, fbCtrs, 1:nUse, img_z);
        colormap(ax, bwr);
        clim(ax, [-2 2]);
        cb = colorbar(ax);  cb.Label.String = 'z-score';

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
        img_z = zscore(freq_i(sOrd, :), 0, 1);

        nC  = 256;
        bwr = [linspace(0.2,1,nC/2)' linspace(0.3,1,nC/2)' ones(nC/2,1);
               ones(nC/2,1) linspace(1,0.3,nC/2)' linspace(1,0.2,nC/2)'];

        ax = subplot(nRows_f, nCols_f, iAmp);
        hImg = imagesc(ax, fbCtrs, 1:nUse, img_z);
        colormap(ax, bwr);
        clim(ax, [-2 2]);
        cb = colorbar(ax);  cb.Label.String = 'z-score';
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