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

movieWithTracesSVD(U, V, t, traces, [], []);

%% find stims

% [stimStarts, stimEnds] = detectStimEvents(tt, v, ...
%     'MinDist', 4, ...
%     'ThreshFrac', 0.05);

[stimStarts, stimEnds, uAmp, idxByAmp] = detectStimEvents_idx(tt, v, ...
    'AmpTol', 0.1, 'MinDist', 0.05);

% % All impulses with the 3rd unique size:
% impulseNums = idxByAmp{3};
% startTimes  = ts(impulseNums);
% endTimes    = te(impulseNums);


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


%% sort dF by impulse:


i=1;
DF_imp=[];
Peak_imp=[];
imp.mot = containers.Map;
imp.Peak_imp = containers.Map;
for i  = 1:length(uAmp)
    impulseNums = idxByAmp{i};
    startTimes  = stimStarts(impulseNums);
    df_imp=[];
    p_imp=[];
    mot=[];
    
    

    
    if i==2
        startTimes(end)=[];
    end
    for j = 1:length(startTimes)

        
        [a,b] = min(abs(d.timeBlue - startTimes(j)));

        df_imp = [df_imp;dF(b - 3*35:b + 3*35) - dF(b)];
        p_imp = [p_imp,min(dF(b: b + 0.5*35) - dF(b))];
        % mot = [mot, sum(d.mv(b-35:b+35))];
    end
    imp.Peak_imp(string(uAmp(i))) = p_imp;
    imp.mot(string(uAmp(i))) = mot;
DF_imp = [DF_imp;mean(df_imp,1)];
% Peak_imp = [Peak_imp; p_imp];

end


%%
close all;
timp = -3:1/35:3;
 
figure()
plot(timp,DF_imp,'LineWidth', 3); hold on;
xline(0)

legend('0.8','1.6','2.4','2.7');
ylabel('dF')
xlabel('time')


peaks=[];
for i=1:length(uAmp)

peaks = [peaks,min(DF_imp(i,35*3:35*3.5))];
end

slope = (peaks(end) - peaks(1))/(uAmp(end) - uAmp(1));

c0 = peaks(1) - slope*uAmp(1);


figure()
plot(uAmp,peaks,'or','LineWidth', 3); hold on;
ylabel('inhibition')
xlabel('impulse(V)')
%%

keys(imp.mot)

values(imp.mot)


%%

keysList = keys(imp.Peak_imp);
keysList = sort(string(keysList));   % sort alphabetically / numerically

allVals = [];
groupLabels = [];

for i = 1:numel(keysList)
    key = keysList(i);
    vals = imp.Peak_imp(key);

    allVals = [allVals; vals(:)];
    groupLabels = [groupLabels; repmat(key, numel(vals), 1)];
end

% Create boxplot
figure;
bp = boxplot(allVals, groupLabels,'Symbol', '');
xlabel('Group');
ylabel('Value');
title('Boxplot from containers.Map');



%% Predicted impulse vs motion
% 
% for i  = 1:length(uAmp)
%     impulseNums = idxByAmp{i};
%     startTimes  = stimStarts(impulseNums);
%     % df_imp=[];
%     % p_imp=[];
%     mot=[];
%     error_imp=[];
%     % 
% 
% 
%     if i==2
%         startTimes(end)=[];
%     end
%     for j = 1:length(startTimes)
% 
% 
%         [a,b] = min(abs(d.timeBlue - startTimes(j)));
% 
%         pred_imp = uAmp(i)*slope + c0;
%         error_imp = [error_imp,norm(pred_imp - min(dF(b:b + 0.5*35) - dF(b)))];
%         mot = [mot, sum(d.mv(b:b+35))];
%     end
% %     imp.Peak_imp(string(uAmp(i))) = p_imp;
% %     imp.mot(string(uAmp(i))) = mot;
% % DF_imp = [DF_imp;mean(df_imp,1)];
% % Peak_imp = [Peak_imp; p_imp];
% 
% end
% 
% 
% %%
% 
% length(mot)
% length(error_imp)
% 
% p = polyfit(mot, error_imp, 1);      % p(1) = slope m, p(2) = intercept b
% 
% m = p(1);
% b = p(2);
% 
% y_fit = polyval(p, mot);
% 
% figure()
% plot(mot,error_imp,'or','LineWidth',3);hold on;
% plot(mot, y_fit, 'k-', 'LineWidth', 2);
% xlabel('motion energy')
% ylabel('trial variability')

%%

close all

% Create boxplot
figure;
bp = boxplot(allVals, groupLabels,'Symbol', '', ...
    'Widths', 0.1);
xlabel('Amplitude(V)');
% title('Boxplot from containers.Map');
set(bp, 'LineWidth', 1.5);

% % --- Means per condition ---
% mu = mean(allVals, 1, 'omitnan');          % 1×2
% xpos = 1:size(allVals,2);                  % [1 2]
% 
% % Plot means
% plot(xpos, mu, 'o', 'MarkerSize', 7, 'LineWidth', 1.8);
% 
% % --- Linear fit over the means (through the mean points) ---
% p = polyfit(xpos, mu, 1);            % slope/intercept
% xf = linspace(min(xpos), max(xpos), 100);
% yf = polyval(p, xf);
% 
% plot(xf, yf, '-', 'LineWidth', 2.0);

% --- Beautify for neuroscience paper ---
ax = gca;
ax.LineWidth = 1.5;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.FontWeight = 'bold';
ax.TickDir = 'out';
ax.Box = 'off';
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
% title('Boxplot + mean trend', 'FontWeight','bold');

% Optional: tighten y-lims a bit
% ylim([min(allVals(:)) max(allVals(:))] + [-1 1]*0.05*range(allVals(:)));
ylim([-10 0.5])
% Optional: annotate slope
% txt = sprintf('slope = %.3g', p(1));
% text(1.05, max(ylim)*0.95, txt, 'FontWeight','bold');

%%

close all

% Create boxplot
figure;
bp = boxplot(allVals, groupLabels,'Symbol', '', ...
    'Widths', 0.1, ...
    'Whisker',0.5);
xlabel('Amplitude(V)');
% title('Boxplot from containers.Map');
set(bp, 'LineWidth', 1.5);

% % --- Means per condition ---
% mu = mean(allVals, 1, 'omitnan');          % 1×2
% xpos = 1:size(allVals,2);                  % [1 2]
% 
% % Plot means
% plot(xpos, mu, 'o', 'MarkerSize', 7, 'LineWidth', 1.8);
% 
% % --- Linear fit over the means (through the mean points) ---
% p = polyfit(xpos, mu, 1);            % slope/intercept
% xf = linspace(min(xpos), max(xpos), 100);
% yf = polyval(p, xf);
% 
% plot(xf, yf, '-', 'LineWidth', 2.0);

% --- Beautify for neuroscience paper ---
ax = gca;
ax.LineWidth = 1.5;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.FontWeight = 'bold';
ax.TickDir = 'out';
ax.Box = 'off';
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
% title('Boxplot + mean trend', 'FontWeight','bold');

% Optional: tighten y-lims a bit
% ylim([min(allVals(:)) max(allVals(:))] + [-1 1]*0.05*range(allVals(:)));
ylim([-7 0.5])
% Optional: annotate slope
% txt = sprintf('slope = %.3g', p(1));
% text(1.05, max(ylim)*0.95, txt, 'FontWeight','bold');

%%


% x : 1×N or N×1 data vector
% g : 1×N or N×1 group labels (numeric/categorical/strings)

figure('Color','w'); hold on

% Median-based boxplot (default)
% bp = boxplot(allVals, groupLabels,'Symbol', '', ...
%     'Widths', 0.2, ...
%     'Whisker',0.5);
% xlabel('Amplitude(V)');
% % title('Boxplot from containers.Map');
% set(bp, 'LineWidth', 3);


% Get medians per group in plotting order
[ug,~,idx] = unique(groupLabels, 'stable');
med = accumarray(idx(:), allVals(:), [], @(v) median(v,'omitnan'));

% X-positions of boxes (1..K)
xpos = 1:numel(ug);

% % Line connecting medians (approximation line)
% plot(xpos, med, '-o', ...
%     'LineWidth', 2.2, ...
%     'MarkerSize', 6);

% Optional: best-fit (least-squares) line through medians
p  = polyfit(xpos, med, 1);
xf = linspace(min(xpos), max(xpos), 100);
plot(xf, polyval(p,xf), '-', 'LineWidth', 2.2);
% plot(str2double(ug), med, 'o', 'LineWidth', 2.2);



% Median-based boxplot (default)
bp = boxplot(allVals, groupLabels,'Symbol', '', ...
    'Widths', 0.2, ...
    'Whisker',0.5);
xlabel('Amplitude(V)');
% title('Boxplot from containers.Map');
set(bp, 'LineWidth', 3);
% Beautify for paper
% --- Beautify for neuroscience paper ---
ax = gca;
ax.LineWidth = 1.5;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.FontWeight = 'bold';
ax.TickDir = 'out';
ax.Box = 'off';
xlabel('Amplitude(V)', 'FontWeight','bold');
ylabel('dF/F %', 'FontWeight','bold');
% title('Boxplot + mean trend', 'FontWeight','bold');

% Optional: tighten y-lims a bit
% ylim([min(allVals(:)) max(allVals(:))] + [-1 1]*0.05*range(allVals(:)));
ylim([-7 0.5])


%%
clear; close all;

% ---- Data ----
x = linspace(0,10,400);
y = 0.05*sin(2*pi*0.6*x) + 0.02*randn(size(x));

% ---- Plot ----
figure('Color','w','Position',[100 100 520 380]);
plot(x,y,'k','LineWidth',1.5);
hold on;

xlabel('Time (s)','FontWeight','bold')
ylabel('\DeltaF/F','FontWeight','bold')

% ---- Remove full axes ----
ax = gca;
ax.Box = 'off';
ax.TickDir = 'out';
ax.LineWidth = 1.2;
ax.FontSize = 12;
ax.FontName = 'Arial';

ax.XRuler.Axle.Visible = 'off';
ax.YRuler.Axle.Visible = 'off';

% ---- Draw short corner axes manually ----
xl = xlim;
yl = ylim;

dx = 0.12 * diff(xl);   % length of x-axis corner
dy = 0.12 * diff(yl);   % length of y-axis corner

plot([xl(1) xl(1)+dx], [yl(1) yl(1)], 'k', 'LineWidth', 1.4)
plot([xl(1) xl(1)], [yl(1) yl(1)+dy], 'k', 'LineWidth', 1.4)

% ---- Optional: tidy ----
ax.TickLength = [0.015 0.015];
