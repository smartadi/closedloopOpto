clc;
close all;
clear all;
githubDir = "/home/nimbus/Documents/Brain/"

% Script to analyze widefield/behavioral data from 

addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab

%%
% input experiment 
% mn = 'test'; td = '2024_09_23'; 
% en = 2;


% input experiment 
% mn = 'AL_0033'; td = '2024_09_03'; 
% en = 1;

% mn = 'AL_0034'; td = '2024-09-26'; 
% en = 3;

% 
% mn = 'AL_0034'; td = '2024-09-30'; 
% en = 2;

% mn = 'AL_0034'; td = '2024-10-04'; 
% en = 3;

% mn = 'AL_0034'; td = '2024-10-16'; 
% en = 3;

%% RESULT
% mn = 'AL_0034'; td = '2024-10-16'; 
% en = 5;

%% GRID 
% mn = 'AL_0034'; td = '2024-10-17'; 
% en = 30;
% mn = 'AL_0034'; td = '2024-10-18'; 
% en = 1;

%% Tune
mn = 'AL_0034'; td = '2024-10-25'; 
en = 1;

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

%%
horizon = 35*40;
w=horizon-1;
input_params = readmatrix(append(serverRoot,"/input_params.csv"));
frames = readmatrix(append(serverRoot,"/frames.csv"));
states_raw = dlmread(append(serverRoot,"/states.csv"),' ');
inputs_raw = dlmread(append(serverRoot,"/input_amps.csv"),' ');
kdata = readNPY(append(serverRoot,'/Kdata.npy'));
kval = readNPY(append(serverRoot,'/Kval.npy'));
kr = readNPY(append(serverRoot,'/Kr.npy'));

states = states_raw;
inputs = inputs_raw

states(1:horizon) = [];
states(length(frames)/2+1:end) = [];

inputs(1:horizon) = [];
inputs(length(frames)/2+1:end) = [];
% load(append(serverRoot,"/params.mat"))
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

%%

% stimTimes = tt(v(2:end)>0.1 & v(1:end-1)<=0.1);
% ds = find(diff([0;stimTimes])>1);
% stimStarts = stimTimes(ds);
% stimEnds = stimTimes(ds(2:end)-1);
% 
% % Amps
% amps=[];
% for i = 1:length(stimStarts)-1
%     amps = [amps,max(v(find(tt == stimStarts(i)):find(tt == stimEnds(i))))];
% end
% 
% stimDur = stimEnds-stimStarts(1:end-1);

%%
stimTimes = tt(v(2:end)>0.01 & v(1:end-1)<=0.01);
ds = find(diff([0;stimTimes])>1);
stimStarts = stimTimes(ds);
stimEnds = stimTimes(ds(2:end)-1);

% Amps
amps=[];
for i = 1:length(stimStarts)-1
    amps = [amps,max(v(find(tt == stimStarts(i)):find(tt == stimEnds(i))))];
end

stimStarts(end)=[];
stimDur = stimEnds-stimStarts;



%%
% bb= find(stimStarts(2:end)-stimEnds>1);
% 
% stimStarts = stimStarts(bb);
% stimEnds = stimEnds(bb);
% stimDur = stimEnds-stimStarts;

wf_times = tt(wt(2:end)>1 & wt(1:end-1)<=1);
% t = wf_times(2:2:end);
t = wf_times(1:2:end);


%% repair
% input_params(451:end,:)=[];
% %
% % for i= 1:StimDur
% %     if StimDur
% % end
% 
% % 3+12 case
% i = find(diff(stimStarts < 15))
% 
% stimStarts(i)=[];
%% read raw images
% source_dir ='/mnt/data/brain/';
% source_dir = append(source_dir,mn,'/',td,'/',num2str(en))
% a=dir([source_dir '/*'])
% out=size(a,1)
% 
% out=out-2;
% 
% pixel=[450,350]
% 
% path = append(source_dir,'/frame-')
% i=201;
% pathim=append(path,num2str(i-1));
% fileID = fopen(pathim,'r');
% A = fread(fileID,[560,560],'uint16')';
% 
% figure()
% imagesc(A);hold on
% plot(pixel(1,1),pixel(1,2),'or')
% clim([0 500]);
% colorbar
% impixelinfo
% %



F = []

k=5
% for i=1:2:out
%     pathim=append(path,num2str(i-1));
%     fileID = fopen(pathim,'r');
%     A = fread(fileID,[560,560],'uint16')';
%     j=1;
%         G = mean(A(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k),'all');
% 
%     F = [F,G];
%     i
% 
% end 

% Time saver
% save('pixel10251.mat','F')
load('pixel10251.mat','F')
%%

Fk  = [ones(1,w),F];
dF=[];
Fmean=[];
dFk=[];
Fkmean=[];

for i = 1:length(F)
    % Add an LPF filter 
    Fkmean = [Fkmean,mean(Fk(i:i+w))];
    dFk = [dFk,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];
end





%%
dur=3
Tout = 0:0.0285:dur;
close all
j=100

[a i] = min(abs(t - stimStarts(j)));
[a i2] = min(abs(t - stimEnds(j)));
figure()
subplot(2,1,1)
plot(Tout,dFk(i:i+35*dur));hold on;
plot(Tout,-5*ones(1,length(Tout)))
xlim([0,3])
subplot(2,1,2)

[a k] = min(abs(tt - stimStarts(j)));
[a k2] = min(abs(tt - stimEnds(j)));



Tin = 0:0.0005:stimDur(j);
Tout = 0:0.0285:dur;
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([0,3])
xlim([0,4])
ylim([0,5])

close all
i=5;
j = nc(i);
[a i] = min(abs(t - stimStarts(j)));
[a i2] = min(abs(t - stimEnds(j)));

[a k] = min(abs(tt - stimStarts(j)));
[a k2] = min(abs(tt - stimEnds(j)));



Tin = 0:0.0005:stimDur(j);
Tout = 0:0.0285:4;

% figure()

subplot(2,2,2)
plot(Tout,dFk(i:i+35*4));hold on
plot(Tout,-10*ones(1,length(Tout)))
xlim([0,4])
title('nc')

subplot(2,2,4)
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([0,4])
ylim([0,5])


%% No controller:

% nc = find(input_params(:,7)==0);
% 
% % sort by ref level:
% 
% nc_Kref = sortrows(input_params(nc,:),1)

% nc = find(input_params(:,2)==0 & input_params(:,3) == 0 & input_params(:,1) == 0.175);
% wc = find(input_params(:,2)~=0 & input_params(:,1) == 0.175);

% nc = find(input_params(:,7)==0);
% wc = find(input_params(:,7)==1);



%%
close all;

K = input_params(:,5:6);

figure()

viscircles(K,0.1,'Color','k','LineStyle','--');hold on;
plot(K(:,1),K(:,2),'ro','LineWidth',4)
plot(K(1,1),K(1,2),'bo','LineWidth',6)
plot(K(end,1),K(end,2),'go','LineWidth',6)
xlim([-0.2 0.4])
ylim([-0.2 0.4])
%%
close all;
dk = diff(K)

figure()
plot(vecnorm(dk,2,2))



%%
close all;
figure()
plot(dFk); hold on;
plot(states)
legend('computed','saved')
%%
close all;
figure()
plot(-inputs); hold on;
plot(states)
legend('inputs','states')


figure()
plot(-inputs_raw); hold on;
plot(states_raw)
legend('inputs','states')

%%

figure()
subplot(1,2,1)


plot(K(end,1),K(end,2),'go','LineWidth',6);hold on
plot(K(1,1),K(1,2),'bo','LineWidth',6)
plot(K(:,1),K(:,2),'ro','LineWidth',4);hold on
plot(K(end,1),K(end,2),'go','LineWidth',6)
viscircles(K,0.1,'Color','k','LineStyle','--');hold on;
xlim([-0.2 0.4])
ylim([-0.2 0.4])
xlabel('Kp')
ylabel('Ki')
legend('initial','final')
title('zero-order optimization')

subplot(1,2,2)
plot(kval(1:end-1),'LineWidth',2)
xlabel('iterations')
ylabel('J(K)')
title('Cost per iteration')