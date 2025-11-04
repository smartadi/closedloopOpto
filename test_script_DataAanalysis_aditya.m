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
mn = 'test'; td = '2024_10_1'; 
en = 2;
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


%% read raw images
source_dir ='/mnt/data/brain/';
source_dir = append(source_dir,mn,'/',td,'/',num2str(en))
a=dir([source_dir '/*'])
out=size(a,1)

out=out-2;

pixel = [163,360];
%%
close all

path = append(source_dir,'/frame-')
i=100;
pathim=append(path,num2str(i-1));
fileID = fopen(pathim,'r');
A = fread(fileID,[560,560],'uint16')';

figure()
imagesc(A);hold on
plot(pixel(1,1),pixel(1,2),'or')
clim([0 4096]);
colorbar
impixelinfo
%%


F2 = []
F3 = []

k=3
for i=1:2:out
    pathim=append(path,num2str(i-1));
    fileID = fopen(pathim,'r');
    A = fread(fileID,[560,560],'uint16')';
    j=1
        G  = A(pixel(j,2),pixel(j,1));
        G2 = mean(A(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k),'all');
    i
    F2 = [F2,G];
    F3 = [F3,G2];

end 


%%
w=500-1;
F  = [ones(1,w),F2];
Fk  = [ones(1,w),F3];
dF=[];
Fmean=[];
dFk=[];
Fkmean=[];

for i = 1:length(F2)
    % Add an LPF filter 
    Fmean = [Fmean,mean(F(i:i+w))];
    Fkmean = [Fkmean,mean(Fk(i:i+w))];

    dF = [dF,(F(i+w)-Fmean(i))/Fmean(i)];

    dFk = [dFk,(Fk(i+w)-Fkmean(i))/Fkmean(i)];
end

df = dF(w:end);
dfk = dFk(w:end);

%%
wf_times = tt(wt(2:end)>1 & wt(1:end-1)<=1);
t = wf_times(2:2:end);


%%
close all
figure()
plot(t(500:end),dF(500:end));hold on;
for j=1:length(stimStarts)
    [a i] = min(abs(t - stimStarts(j)));

    xline(t(i))
end

%%
close all
j =4
[a i] = min(abs(t - stimStarts(j)));

figure()
plot(t(i-100:i+300),dF(i-100:i+300),'r','LineWidth',2);hold on
plot(t(i-100:i+300),dFk(i-100:i+300),'b','LineWidth',2)
title(append('amp = ',num2str(amps(j))))
xline(t(i))
xline(t(i+70))


% figure()
% plot(t(i-100:i+400),F2(i-100:i+400))
% xline(t(i))

%% average behavior
favg=[];
for j = 1:length(stimStarts)
    [a i] = min(abs(t - stimStarts(j)));
    favg = [favg;dF(i-1*35:i+3*35)];
end

Favg = mean(favg,1);
tavg = linspace(-1,3,141);

% close all;
figure()
plot(tavg,Favg,'r','LineWidth',2)
xline(0,'--b','LineWidth',1.5)
xline(2,'--b','LineWidth',1.5)
xlabel('sec')
ylabel('df/F')
title('avg')
%%

input_params = readmatrix(append(serverRoot,"/input_params.csv"));
states = readmatrix(append(serverRoot,"/states.csv"));
frames = readmatrix(append(serverRoot,"/frames.csv"));
%%

load(append(serverRoot,"/params.mat"))