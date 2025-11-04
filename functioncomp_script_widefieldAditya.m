clc;
close all;
clear all;
githubDir = "/home/nimbus/Documents/Brain/"

% Script to analyze widefield/behavioral data from 

addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab


% load("rand_signals.mat");
%%
%99
mn = 'AL_0034'; td = '2024-08-30'; 
en = 1;


% %70
% mn = 'AL_0033'; td = '2024-08-24'; 
% en = 1;
% %70
% mn = 'AL_0035'; td = '2024-08-12'; 
% en = 1;

%73
% mn = 'AL_0034'; td = '2024-07-29'; 
% en = 1;
% 
% % 69
% mn = 'AL_0033'; td = '2024-07-25'; 
% en = 1;

serverRoot = expPath(mn, td, en)

%% preprocess video

% colors = {'blue', 'violet'};
% computeWidefieldTimestamps(serverRoot, colors);



%% svdViewer
% load(fullfile(serverRoot, 'blue', 'dataSummary.mat'));
% svdViewer(U, Sv(1:nSV), V, 1/mean(diff(t))); 

%% process hemodynamic correction
% nSV = 500;
% 
% [U, V, t, mimg] = hemoCorrect(serverRoot, nSV);

%% load directly (if you had already run correction)
nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);

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

%%
stimTimes = tt(v(2:end)>0.09 & v(1:end-1)<=0.09);
ds = find(diff([0;stimTimes])>0.05);
stimStarts = stimTimes(ds);
stimEnds = stimTimes(ds(2:end)-1);

%% Amps
amps=[];
for i = 1:length(stimStarts)-1
    amps = [amps,max(v(find(tt == stimStarts(i)):find(tt == stimEnds(i))))];
end

%%
stimDur = stimEnds-stimStarts(1:end-1);

% load("rand_inputs.mat")

%%

% pixelTuningCurveViewerSVD(U, V(:,:), t(1:end-1), stimStarts(1:end-1), stimDur, [-1 3]);



%%

h  = histogram(amps,'BinWidth',0.25);
%%
[N,edges,bin] = histcounts(amps,6);


events = edges(bin) + 0.1;

%%
% pixelTuningCurveViewerSVD(U, V(:,1:end-1), t, stimStarts(1:end-1),events, [-1 3])
% pixelTuningCurveViewerSVD(U, V, t(1:end-1), stimStarts(1:end-1),events, [-1 5])

%% signal
Uu=reshape(U,560*560,500);
%%
p = [432,241];

J = 5;
pr = randi([-50 50],J,2);
p = p+pr;

dfF=[];
for j = 1:J

Im=[];
for a = -3:1:3
    for b = -3:1:3
        Im = [Im;Uu((p(j,2)+b-1)*560 + p(j,1)+a,1:50)*V(1:50,:)];
    end
end
Im = mean(Im,1);
Im_mean = mean(mimg(p(2)-3:p(2)+3,p(1)-3:p(1)+3),'all');
dfF = [dfF;(Im)/Im_mean*100];
end



%%
I_maxval=[];
Imin_val=[];
energy_val=[];
integral_val=[];
IMean_val=[];
for k = 1:J
I_val = [];

I_val = [];
Ii_val = [];
II_val = [];
II=[];

Imean_val=[];


for j = 1:length(stimEnds)
    [a i] = min(abs(t - stimStarts(j)));
    [a2 i2] = min(abs(t - stimEnds(j)));
    I_val = [I_val;dfF(k,i:i+70)];

    % I_val = [I_val;Im(i:i+100)];
    % size([Im(i:i2),zeros(1,70-(i2-i))])
    Ii_val = [Ii_val;dfF(i:i2),zeros(1,70-(i2-i))];
    II_val = [II_val;dfF(i-35:i2+35),zeros(1,70-(i2-i))];
    Imean_val=[Imean_val;mean(max(-dfF(k,i:i2),0))];
    II = [II,i2-i];
    
end
% max inhibition
size(min(I_val,[],2)');
size(I_maxval);
IMean_val = [IMean_val,Imean_val];
I_maxval = [I_maxval;min(I_val,[],2)'];
Imin_val = [Imin_val;max(max(-Ii_val,0),[],2)'];
[m n] = size(Ii_val);
energy_val = [energy_val;sum(max(-Ii_val,0).^2,2)'/100];
integral_val = [integral_val;sum(max(-Ii_val,0),2)'/100];
end

%%

fp=[];
for j=1:J
    f_mean = fit(amps',double(IMean_val(:,j)),"poly2");
    fp = [fp;f_mean.p2/f_mean.p1,f_mean.p3/f_mean.p1];
end