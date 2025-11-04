clc;
close all;
clear all;
githubDir = "/home/nimbus/Documents/Brain/"

% Script to analyze widefield/behavioral data from 

addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab

%%
% input bug removed
mn = 'AL_0033'; td = '2024_12_10'; 
en = 1;

% input experiment 
% mn = 'test'; td = '2024_10_1'; 
% en = 2;
% mn = 'test'; td = '2024_09_23'; 
% en = 2;

%70
% mn = 'AB_0032'; td = '2024-07-26'; 
% en = 1;

%73
% mn = 'AL_0034'; td = '2024-07-29'; 
% en = 1;
% 
% % 69
% mn = 'AL_0033'; td = '2024-07-25'; 
% en = 1;

serverRoot = expPath(mn, td, en)

%% load directly (if you had already run correction)
% nSV = 500;
% 
% [U, V, t, mimg] = loadUVt(serverRoot, nSV);

%% correlation map
% pixelCorrelationViewerSVD(U,V)

%% movie
sigName = 'lightCommand';
[tt, v] = getTLanalog(mn, td, en, sigName);

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

% movieWithTracesSVD(U, V, t, traces, [], []);
%%

ll = readNPY(append(serverRoot,'/lightCommand.raw.npy'));
lt = readNPY(append(serverRoot,'/lightCommand.timestamps_Timeline.npy'));
wf = readNPY(append(serverRoot,'/widefieldExposure.timestamps_Timeline.npy'));
wt = readNPY(append(serverRoot,'/widefieldExposure.raw.npy'));

%% Read params

% input_params = readmatrix(append(serverRoot,"/input_params.csv"))




stimTimes = tt(v(2:end)>0.1 & v(1:end-1)<=0.1);
ds = find(diff([0;stimTimes])>0.05);
stimStarts = stimTimes(ds);
stimEnds = stimTimes(ds(2:end)-1);

% Amps
amps=[];
for i = 1:length(stimStarts)-1
    amps = [amps,max(v(find(tt == stimStarts(i)):find(tt == stimEnds(i))))];
end

%
stimDur = stimEnds-stimStarts(1:end-1);





% %%
% close all
% j =4
% [a i] = min(abs(t - stimStarts(j)));
% 
% figure()
% plot(t(i-100:i+300),dF(i-100:i+300),'r','LineWidth',2);hold on
% plot(t(i-100:i+300),dFk(i-100:i+300),'b','LineWidth',2)
% title(append('amp = ',num2str(amps(j))))
% xline(t(i))
% xline(t(i+70))
% 
% 
% % figure()
% % plot(t(i-100:i+400),F2(i-100:i+400))
% % xline(t(i))
% 
% %% average behavior
% favg=[];
% for j = 1:length(stimStarts)
%     [a i] = min(abs(t - stimStarts(j)));
%     favg = [favg;dF(i-1*35:i+3*35)];
% end
% 
% Favg = mean(favg,1);
% tavg = linspace(-1,3,141);
% 
% % close all;
% figure()
% plot(tavg,Favg,'r','LineWidth',2)
% xline(0,'--b','LineWidth',1.5)
% xline(2,'--b','LineWidth',1.5)
% xlabel('sec')
% ylabel('df/F')
% title('avg')
%%

input_params = readmatrix(append(serverRoot,"/input_params.csv"));
states = dlmread(append(serverRoot,"/states.csv"),' ');
frames = readmatrix(append(serverRoot,"/frames.csv"));
%%
load(append(serverRoot,"/params.mat"))

states(1:horizon) =[];
states((length(frames)/2+1:end)) = [];
%%
close all;
figure()
plot(tt,v)

figure()
plot(states)
%%
wf_times = tt(wt(2:end)>1 & wt(1:end-1)<=1);
t = wf_times(2:2:end);


%%
close all
figure()
plot(t(1:end),states(1:end));hold on;
for j=1:length(stimStarts)
    [a i] = min(abs(t - stimStarts(j)));

    xline(t(i))
    ylim([-10 10])
end


%%
close all
j =4
[a i] = min(abs(t - stimStarts(j)));

figure()
plot(t(i-100:i+300),states(i-100:i+300),'r','LineWidth',2);hold on
title(append('amp = ',num2str(amps(j))))
xline(t(i))
xline(t(i+3*35))


% figure()
% plot(t(i-100:i+400),F2(i-100:i+400))
% xline(t(i))

%%


Tout = 0:0.0285:3;
close all
j=20

[a i] = min(abs(t - stimStarts(j)));
[a i2] = min(abs(t - stimEnds(j)));
figure()
subplot(2,1,1)
plot(Tout,states(i:i+35*3));hold on;
plot(Tout,-5*ones(1,length(Tout)))

subplot(2,1,2)

[a k] = min(abs(tt - stimStarts(j)));
[a k2] = min(abs(tt - stimEnds(j)));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([0,3])