%% Data analysis Script
% add pixel configuration


clc;
close all;
clear all;

%% experiment name

mn = 'AL_0041'; td = '2025-12-02'; 
en = 1;

% mn = 'AL_0041'; td = '2025-12-02'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-01-18';
% en  = 1;


% mn = 'AL_0033'; td = '2025-01-29';
% en  = 1;

%% get data
pathString = genpath('utils');
addpath(pathString);

githubDir = "/home/nimbus/Documents/Brain/"
    
    
% Script to analyze widefield/behavioral data from 
addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab
    
    
serverRoot = expPath(mn, td, en);
    
d = loadData(serverRoot,mn,td,en);

%% Run Movie
sigName = 'lightCommand638';
% sigName = 'lightCommand';
[tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);

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
%%
d.mv = d.motion.motion_1(1:2:end);
% movieWithTracesSVD(U, V, t, traces, [], []);

%% find stims

% [stimStarts, stimEnds] = detectStimEvents(tt, v, ...
%     'MinDist', 4, ...
%     'ThreshFrac', 0.05);

[stimStarts, stimEnds, uAmp, idxByAmp] = detectStimEvents_idx(tt, v, ...
    'AmpTol', 0.1, 'MinDist', 0.05);



% ============================
% FILL MISSING (ZERO) STARTS
% ============================
EventPeriod_sec = 5;                      % expected stim spacing
GapThresh_sec   = 1.5 * EventPeriod_sec;  % trigger insertion
MaxInsert       = 1000;                   % safety cap
DedupTol_sec    = 0.25 * EventPeriod_sec; % de-dup tolerance

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





%% get dF/F
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
%%

dF = F/mI(1)*100;

% dF = F;




%% sort dF by impulse, but define "peak inhibition" at a fixed time point
fs    = 35;      % Hz
tWin  = 3;     % seconds for DF_imp window (+/-)

tWin  = 1;     % seconds for DF_imp window (+/-)
tPeak = 0.114;    % seconds after stim start to sample inhibition (CHANGE THIS)

winSamp  = round(tWin  * fs);
peakSamp = round(tPeak * fs);

DF_imp = [];

nAmp = length(uAmp);
imp = struct();
imp.uAmp      = num2cell(uAmp(:));  % "keys" kept as values
imp.Peak_imp  = cell(nAmp,1);       % each cell holds a vector (len varies)
imp.mot       = cell(nAmp,1);       % each cell holds a vector (len varies)
imp.lfp       = cell(nAmp,1);       % each cell holds a vector (len varies)

% Optional summaries
imp.Peak_imp_mean = nan(nAmp,1);
imp.mot_mean      = nan(nAmp,1);
imp.p_var    = cell(nAmp,1);   % trial x 1

%
fs = 35;
freqBand = [0 3];      % low frequency band
totalBand = [0 17];
 

t_win = -3:1/35:3;

t_win = -1:1/35:1;
fig1 = figure();
fig2 = figure();
fig2.Units = 'inches';
fig2.Position = [1, 1, 6, 4];  % [1,1]

fig3 = figure();
for i = 1:length(uAmp)
    impulseNums = idxByAmp{i};
    startTimes  = stimStarts(impulseNums);

    df_imp = [];
    p_imp  = [];
    mot    = [];
    lfp=[];

    % if i == 2
    %     startTimes(end) = [];
    % end
    
    figure(fig1);
    subplot(3,5,i)
    hold on;
    for j = 1:length(impulseNums)
        % Find index b closest to stim start time
        [~, b] = min(abs(d.timeBlue - startTimes(j)));

        % Bounds check for the DF_imp window
        i0 = b - winSamp;
        i1 = b + winSamp;

        % Bounds check for the fixed peak sample
        k = b + peakSamp;

        if i1 > numel(dF) || k < 1 || k > numel(dF)
            continue; % skip trials too close to edges
        end

        baseline = dF(b);

        % Store aligned trace (baseline-subtracted)
        df_imp = [df_imp; dF(i0:i1) - baseline];

        % Store "peak inhibition" at fixed time tPeak after stim
        p_imp = [p_imp; dF(k) - baseline];

        % Optional motion metric if you want it back:
        mot = [mot, sum(d.mv(i0:b))];


        [pxx,f] = pwelch(dF(i0:i1),[],[],[],fs);

        P_lf = trapz(f(f>=freqBand(1) & f<=freqBand(2)), ...
             pxx(f>=freqBand(1) & f<=freqBand(2)));

        P_tot = trapz(f(f>=totalBand(1) & f<=totalBand(2)), ...
              pxx(f>=totalBand(1) & f<=totalBand(2)));

        lfRatio = P_lf / P_tot;

        lfp = [lfp,lfRatio];

        
    end
    plot(t_win,df_imp,'Color',[0,0.2*i,0.2*i],'LineWidth',3);
    plot(t_win,mean(df_imp),'Color',[1,0,0.2*i],'LineWidth',5);

    imp.Peak_imp{i} = p_imp;
    imp.mot{i}      = mot;
    imp.lfp{i}      = lfp;

    imp.Peak_imp_mean(i) = mean(p_imp, 'omitnan');
    imp.mot_mean(i)      = mean(mot,   'omitnan');
    
    mu_p = mean(p_imp, 'omitnan');

    imp.p_var{i} = p_imp - mu_p;


    if ~isempty(df_imp)
        DF_imp = [DF_imp; mean(df_imp, 1)];
    else
        % keep row alignment if you want:
        DF_imp = [DF_imp; nan(1, 2*winSamp + 1)];
    end
    
    subplot(3,5,i+5)
    plot((imp.Peak_imp{i}),imp.lfp{i},'or','LineWidth',3);
    xlabel('inhibition')
    ylabel('lfp')
    xlim([-10 10])
    ylim([0.5 1])

    subplot(3,5,i+10)
    plot((imp.Peak_imp{i}),imp.mot{i},'ob','LineWidth',3);
    xlabel('inhibition')
    xlim([-5,10])
    ylabel('motion')

    figure(fig2);
    % ax = gca;
    plot(0, 0.25, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'red','HandleVisibility', 'off')
    plot(t_win,mean(df_imp),'Color',[1-( 0.15*i), (1- 0.15*i), (1- 0.15*i)],'LineWidth',5, ...
        'DisplayName', sprintf('%.2f V', uAmp(i))); hold on;
    xticks([])

    

    % lgd = legend(ax, hLegend, legTxt, 'Box','off','Color','none','Location','north');
    % lgd.ItemTokenSize = [14 6];
    % lgd.AutoUpdate = 'off';
    

    % shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','Time','YLabel','dF/F','LineWidth',5,'LabelGap',0.05)
    % shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','Input(mW)','YLabel','dF/F','LineWidth',5,'LabelGap',0.05)

end
legend('Box','off','FontSize',12,'FontWeight','bold','Location','southeast')
shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','Time','YLabel','dF/F','LineWidth',5,'LabelGap',0.05)

exportgraphics(fig2, 'paper/imp_response_single.png', 'Resolution', 300);
%%


allVals = [];
groupLabels = [];

for i = 1:length(imp.uAmp)
    vals = imp.Peak_imp{i};  % Get values from cell array
    ampLabel = imp.uAmp{i};  % Get amplitude value
    
    allVals = [allVals; vals(:)];
    groupLabels = [groupLabels; repmat(string(ampLabel), numel(vals), 1)];
end

%%
close all;

% x : 1×N or N×1 data vector
% g : 1×N or N×1 group labels (numeric/categorical/strings)

figure('Color','w'); hold on

% Get means and std per group in plotting order
[ug,~,idx] = unique(groupLabels, 'stable');
meanVals = accumarray(idx(:), allVals(:), [], @(v) mean(v,'omitnan'));
stdVals = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan'));

% X-positions (1..K)
xpos = 1:numel(ug);

% Plot mean as dots with std as vertical lines
capWidth = 0.05;  % Width of horizontal caps
for i = 1:numel(ug)
    % Vertical line for std dev
    plot([xpos(i) xpos(i)], [meanVals(i)-stdVals(i), meanVals(i)+stdVals(i)], ...
        'k-', 'LineWidth', 2.5);
    % Horizontal caps at top and bottom
    plot([xpos(i)-capWidth xpos(i)+capWidth], [meanVals(i)-stdVals(i), meanVals(i)-stdVals(i)], ...
        'k-', 'LineWidth', 2.5);
    plot([xpos(i)-capWidth xpos(i)+capWidth], [meanVals(i)+stdVals(i), meanVals(i)+stdVals(i)], ...
        'k-', 'LineWidth', 2.5);
    % Mean as dot
    plot(xpos(i), meanVals(i), 'o', 'MarkerSize', 10, ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'LineWidth', 2);
end

% Optional: best-fit (least-squares) line through means
p  = polyfit(xpos, meanVals, 1);
xf = linspace(min(xpos), max(xpos), 100);
plot(xf, polyval(p,xf), '-', 'LineWidth', 2.2, 'Color', [0.5 0.5 0.5]);

% Beautify for paper
ax = gca;
ax.LineWidth = 1.5;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.FontWeight = 'bold';
ax.TickDir = 'out';
ax.Box = 'off';
ax.XTick = xpos;
ax.XTickLabel = cellstr(ug);
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');

% Optional: tighten y-lims a bit
ylim([-10 3])




xticks([])

shortCornerAxes_plot(gca,'Frac',0.2,'XLabel','Input(V)','YLabel','dF/F','LineWidth',5)
