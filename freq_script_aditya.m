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

mn = 'AL_0033'; td = '2024_12_18'; 
en = 4;
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

% mn = 'AL_0033'; td = '2024-12-18'; 
% en = 4;

% mn = 'AL_0033'; td = '2024-12-19'; 
% en = 2;


% mn = 'AL_0033'; td = '2024-12-20'; 
% en = 7;


% mn = 'AL_0033'; td = '2024-12-23'; 
% en = 1;

% mn = 'AL_0034'; td = '2024-10-17'; 
% en = 30;


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

% mn = 'AL_0033'; td = '2024-12-10'; 
% en = 1;

% mn = 'AL_0034'; td = '2024-10-18'; 
% en = 1;

% mn = 'AL_0033'; td = '2025-01-09'; 
% en = 1;
%%
serverRoot = expPath(mn, td, en)

%%
% input_params = readmatrix(append(serverRoot,"/data/input_params.csv"));
% frames = readmatrix(append(serverRoot,"/frames.csv"));
% states = dlmread(append(serverRoot,"/data/states.csv"),' ');
% load(append(serverRoot,"/data/params.mat"))


input_params = readmatrix(append(serverRoot,"/input_params.csv"));
% frames = readmatrix(append(serverRoot,"/frames.csv"));
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

stimTimes = tt(v(2:end)>0.1 & v(1:end-1)<=0.1);
ds = find(diff([0;stimTimes])>2);
stimStarts = stimTimes(ds);
stimEnds = stimTimes(ds(2:end)-1);

% Amps
amps=[];
for i = 1:length(stimStarts)-1
    amps = [amps,max(v(find(tt == stimStarts(i)):find(tt == stimEnds(i))))];
end

stimDur = stimEnds-stimStarts(1:end-1);
%%
% bb= find(stimStarts(2:end)-stimEnds>1);
% 
% stimStarts = stimStarts(bb);
% stimEnds = stimEnds(bb);
% stimDur = stimEnds-stimStarts;

wf_times = tt(wt(2:end)>1 & wt(1:end-1)<=1);
% t = wf_times(2:2:end);
t = wf_times(1:2:end);



%% read raw images
pixel = [380,320]
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
% % save('pixel12231.mat','F')
% save('pixel01091.mat','F')
% % load('pixel2231.mat')

load('pixel12184.mat')
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

%% debug
% close all;
figure()
plot(tt,v);hold on
xline(stimStarts)

% create a new input time line as stimstarts might miss an input,
% if it was zero 
a1 = input_params(:,2) - double(horizon)*ones(length(input_params),1);
a2 = input_params(:,2) - double(horizon) + double(dur);

stimStarts_a = t(a1);
stimEnds_a = t(a2);
%%

 

L=1000;
S = dFk(1:L);

Fs = 35;

f = Fs/L*(0:(L-1));

figure()
plot(f,S,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of X(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")
%%

Y = fft(S);
P2 = abs(Y/L);
P1 = P2(1:L-1);
P1(2:end-1) = 2*P1(2:end-1);

figure()
plot(f,Y,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of S(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")


figure()
plot(Fs/L*(-L/2:L/2-1),abs(fftshift(Y)),"LineWidth",3)
title("fft Spectrum in the Positive and Negative Frequencies")
xlabel("f (Hz)")
ylabel("|fft(X)|")


power = abs(Y).^2/L;    % power of the DFT

figure()
plot(f,power)
xlabel('Frequency')
ylabel('Power')
%%

[pxx,f] = pspectrum(abs(Y),35);

figure()
plot(f,pxx)
xlabel('Frequency (Hz)')
ylabel('Power Spectrum (dB)')
title('Default Frequency Resolution')



%% 
close all;

L=1000
S = dFk(1:L);


Y = fft(S);

YY = abs(fftshift(Y));
tt= Fs/L*(0:L/2-1);

% figure()
% plot(tt,a(L/2+1:end,:),"LineWidth",3)
% title("fft Spectrum in the Positive and Negative Frequencies")
% xlabel("f (Hz)")
% ylabel("|fft(X)|")
% 

figure()
semilogy(tt,YY(L/2+1:end),"LineWidth",3)
title("fft Spectrum in the Positive and Negative Frequencies")
xlabel("f (Hz)")
ylabel("|fft(X)|")
%% filter



