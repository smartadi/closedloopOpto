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
mn = 'AL_0034'; td = '2024-10-18'; 
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
input_params = readmatrix(append(serverRoot,"/input_params.csv"));
frames = readmatrix(append(serverRoot,"/frames.csv"));
states = dlmread(append(serverRoot,"/states.csv"),' ');
load(append(serverRoot,"/params.mat"))
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
abb= find(diff(stimStarts)>17)
input_params(abb(2),:)=[];
input_params(abb(3),:)=[];
input_params(abb(4),:)=[];
input_params(abb(5),:)=[];

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
input_params(451:end,:)=[];
stimStarts(451:end)=[];
%
% for i= 1:StimDur
%     if StimDur
% end

% % 3+12 case
% i = find(diff(stimStarts < 15))
% 
% stimStarts(i)=[];
%% read raw images
source_dir ='/mnt/data/brain/';
source_dir = append(source_dir,mn,'/',td,'/',num2str(en))
a=dir([source_dir '/*'])
out=size(a,1)

out=out-2;

% pixel=[163,300]

path = append(source_dir,'/frame-')
i=10434;
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
% 
% 
% 
% F = []
% 
% k=kernel
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
% 
% % Time saver
% save('pixel10181.mat','F')
load('pixel10181.mat')
%%

w=horizon-1;
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

Tout = 0:0.0285:3;
close all
j=300

[a i] = min(abs(t - stimStarts(j)));
[a i2] = min(abs(t - stimEnds(j)));
figure()
subplot(2,1,1)
plot(Tout,dFk(i:i+35*3));hold on;
plot(Tout,-5*ones(1,length(Tout)))

subplot(2,1,2)

[a k] = min(abs(tt - stimStarts(j)));
[a k2] = min(abs(tt - stimEnds(j)));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([0,3])

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

[C,ia,ic] = unique(input_params(2:end,2:3),'rows')

J_val =zeros(length(C),1);

for j =1:length(ic)
    k = numel(find(ic==ic(j)));
    [a i] = min(abs(t - stimStarts(j)));
    traj = norm(dFk(i:i+35*(dur))+5)/k;
    J_val(ic(j)) = J_val(ic(j)) + traj;
end

%
close all;
figure()
plot3(C(:,1),C(:,2),J_val,'or','LineWidth',2)
xlabel('Kp')
ylabel('Ki')
grid on
%%
f = fit([C(:,1) C(:,2)],J_val,'linearinterp');

close all;
figure()
plot(f,[C(:,1),C(:,2)],J_val)
colorbar
xlabel('Kp')
ylabel('Ki')
zlabel('MSE')
title('Cost function J(Kp,Ki)')