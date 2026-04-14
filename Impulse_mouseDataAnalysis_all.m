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
% sigName is now set from experiments array
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
tWin  = 3.0;     % seconds for DF_imp window (+/-)
tPeak = 0.114;    % seconds after stim start to sample inhibition (CHANGE THIS)


tSum = 0.2;                 % seconds after stim (same as old peak if you want)
sumSamp = round(tSum * fs);

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
 figure();
% fig2 = figure();
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
    
    % figure(fig1);
    % subplot(3,5,i)
    hold on;
    for j = 1:length(impulseNums)
        % Find index b closest to stim start time
        [~, b] = min(abs(d.timeBlue - startTimes(j)));

        % Bounds check for the DF_imp window
        i0 = b - winSamp;
        i1 = b + winSamp;

        % % Bounds check for the fixed peak sample
        % k = b + peakSamp;
        % 
        if i1 > numel(dF) || k < 1 || k > numel(dF)
            continue; % skip trials too close to edges
        end

        baseline = dF(b);

        % Store aligned trace (baseline-subtracted)
        df_imp = [df_imp; dF(i0:i1) - baseline];

        % Store "peak inhibition" at fixed time tPeak after stim
        % p_imp = [p_imp; dF(k) - baseline];



        % Define summation window after stimulation
        k0 = b + 1;
         k1 = b + sumSamp;

        if i1 > numel(dF) || k0 < 1 || k1 > numel(dF)
            continue;
        end



% Store summed inhibition (baseline subtracted)
p_imp = [p_imp; sum(dF(k0:k1) - baseline)/(k1-k0)];

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
    % plot(t_win,df_imp,'Color',[0,0,i/(length(uAmp))],'LineWidth',3);
    % plot(t_win,mean(df_imp),'Color',[1,0,i/(length(uAmp))],'LineWidth',5);

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
    
    % subplot(3,5,i+5)
    % plot((imp.Peak_imp{i}),imp.lfp{i},'or','LineWidth',3);
    % xlabel('inhibition')
    % ylabel('lfp')
    % xlim([-10 10])
    % ylim([0.5 1])
    % 
    % subplot(3,5,i+10)
    % plot((imp.Peak_imp{i}),imp.mot{i},'ob','LineWidth',3);
    % xlabel('inhibition')
    % xlim([-5,10])
    % ylabel('motion')
    % 
    % figure(fig2);
    plot(t_win,mean(df_imp),'Color',[0.5,0,i/length(uAmp)],'LineWidth',5); hold on;

end

%% Store results for this experiment
allVals = [];
groupLabels = [];

for i = 1:length(imp.uAmp)
    vals = imp.Peak_imp{i};  % Get values from cell array
    ampLabel = imp.uAmp{i};  % Get amplitude value
    
    allVals = [allVals; vals(:)];
    groupLabels = [groupLabels; repmat(string(ampLabel), numel(vals), 1)];
end

allExperiments(expIdx).mn = mn;
allExperiments(expIdx).td = td;
allExperiments(expIdx).en = en;
allExperiments(expIdx).allVals = allVals;
allExperiments(expIdx).groupLabels = groupLabels;
allExperiments(expIdx).imp = imp;
allExperiments(expIdx).DF_imp = DF_imp;
allExperiments(expIdx).uAmp  = uAmp;

end  % End of experiment loop

%% Combined plot for all experiments
close all;

% Colors for each experiment
expColors = [0.2 0.4 0.8; 0.8 0.2 0.2; 0.2 0.8 0.4];
nCond = 3;
figure('Color','w','Position',[100 100 800 600]); hold on
h1 = yline(0,'--k')
hLegend = gobjects(nCond,1);   % preallocate handles

% Plot each experiment
for expIdx = 1:length(allExperiments)
    allVals = allExperiments(expIdx).allVals;
    groupLabels = allExperiments(expIdx).groupLabels;
    
    % Get means and std per group in plotting order
    [ug,~,idx] = unique(groupLabels, 'stable');
    meanVals = accumarray(idx(:), allVals(:), [], @(v) mean(v,'omitnan'));
    stdVals = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan'));
    semVals = accumarray(idx(:), allVals(:), [], @(v) std(v,'omitnan')/sqrt(sum(~isnan(v))));
    
    % X-positions (offset for each experiment)
    xpos = 1:numel(ug);
    xOffset = (expIdx - 2) * 0.15;  % offset experiments slightly
    xpos = xpos + xOffset;
    
    % Plot mean as dots with std as vertical lines
    capWidth = 0.05;

    nCond = 3;
    for i = 1:numel(ug)
        % Vertical line for SEM
        plot([xpos(i) xpos(i)], [meanVals(i)-semVals(i), meanVals(i)+semVals(i)], ...
            '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
        % Horizontal caps at top and bottom
        plot([xpos(i)-capWidth xpos(i)+capWidth], [meanVals(i)-semVals(i), meanVals(i)-semVals(i)], ...
            '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
        plot([xpos(i)-capWidth xpos(i)+capWidth], [meanVals(i)+semVals(i), meanVals(i)+semVals(i)], ...
            '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
        % Mean as dot
        plot(xpos(i), meanVals(i), 'o', 'MarkerSize', 10, ...
            'MarkerFaceColor', expColors(expIdx,:), 'MarkerEdgeColor', expColors(expIdx,:), 'LineWidth', 2);

        
    end
    
    % Fit line through means for this experiment
    p  = polyfit(xpos, meanVals, 1);
    xf = linspace(min(xpos)-0.2, max(xpos)+0.2, 100);
    hMean  = plot(xf, polyval(p,xf), '-', 'LineWidth', 2.0, 'Color', expColors(expIdx,:), ...
        'DisplayName', sprintf('%s %s-%d', allExperiments(expIdx).mn, ...
                               allExperiments(expIdx).td, allExperiments(expIdx).en));
    hLegend(i) = hMean;
end

% Beautify for paper
ax = gca;
ax.LineWidth = 1.5;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.FontWeight = 'bold';
ax.TickDir = 'out';
ax.Box = 'off';
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
% legend('Location','best');
ylim([-5 3])
uistack(h1, 'bottom')
% Optional: custom corner axes
xticks([])
try
    shortCornerAxes_plot(gca,'Frac',0.1,'XLabel','Input(V)','YLabel','dF/F','LineWidth',5)
catch
    % If function not available, just use regular labels
    xlabel('Input(V)', 'FontWeight','bold');
    ylabel('dF/F %', 'FontWeight','bold');
end
legend(ax,hLegend, {'Cond1','Cond2','Cond3'}, ...
       'Box','off','Color','none');

lgd.ItemTokenSize = [14 6];   % compact line sample
lgd.AutoUpdate = 'off';
%%

%% Combined plot for all experiments
close all;

expColors = [0.2 0.4 0.8; 0.8 0.2 0.2; 0.2 0.8 0.4];

fig = figure; hold on

fig.Units = 'inches';
fig.Position = [1, 1, 6, 4];  % [1,1]
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

    xpos = 1:numel(ug);
    xOffset = (expIdx - 2) * 0.15;
    xpos = xpos + xOffset;   

    capWidth = 0.05;

    for j = 1:numel(ug)
        plot([xpos(j) xpos(j)], [meanVals(j)-semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)-semVals(j), meanVals(j)-semVals(j)], ...
            '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
        plot([xpos(j)-capWidth xpos(j)+capWidth], [meanVals(j)+semVals(j), meanVals(j)+semVals(j)], ...
            '-', 'LineWidth', 2.5, 'Color', expColors(expIdx,:));
        plot(xpos(j), meanVals(j), 'o', 'MarkerSize', 10, ...
            'MarkerFaceColor', expColors(expIdx,:), ...
            'MarkerEdgeColor', expColors(expIdx,:), ...
            'LineWidth', 2);
    end

    % Fit line through means for this experiment
    p  = polyfit(xpos, meanVals, 1);
    xf = linspace(min(xpos)-0.2, max(xpos)+0.2, 100);

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
    shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','Input(mW)','YLabel','dF/F','LineWidth',5,'LabelGap',0.05)
catch
    xlabel('Input(V)', 'FontWeight','bold');
    ylabel('dF/F %', 'FontWeight','bold');
end

% Legend (clean neuro style)
lgd = legend(ax, hLegend, legTxt, 'Box','off','Color','none');
lgd.ItemTokenSize = [14 6];
lgd.AutoUpdate = 'off';
exportgraphics(fig, 'paper/imp_response.png', 'Resolution', 300);

%% =========================================================
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
%% =========================================================

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