% analyze raw image:
clc;
clear all;
close all;

path = '/home/nimbus/Documents/Brain/data/AB_0032/2024-07-11/1/frame-'
num = 1
pathim=append(path,num2str(num));
fileID = fopen(pathim,'r');
A = fread(fileID,[560,560],'int16')';



pixel = [230,220;
        360,130;
        170,330;
        230,80]
%%
close all


figure()
clims = [0 2000]
imagesc(A);hold on
plot(pixel(1,1),pixel(1,2),'or')
colorbar
impixelinfo



%%
source_dir ='/home/nimbus/Documents/Brain/data/AB_0032/2024-07-11/1/'
a=dir([source_dir '/*'])
out=size(a,1)

out=out-2;
   

F = []
for i=1:out
    pathim=append(path,num2str(i-1));
    fileID = fopen(pathim,'r');
    A = fread(fileID,[560,560],'int16')';
    G=[];
    for j = 1 :length(pixel)
        G = [G;A(pixel(j,1),pixel(j,2))];
    end
    i
    F = [F,G];
end



%%
figure()
plot(F)
%%
save("pixel_var.mat")

%%
mn = 'AB_0032'; td = '2024-06-25'; 
en = 1;

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
pixelCorrelationViewerSVD(U,V)

%% movie
sigName = 'lightCommand';
[tt, v] = getTLanalog(mn, td, en, sigName);

tInd = 1;
traces(tInd).t = tt;
traces(tInd).v = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];

stimTimes = tt(v(2:end)>2 & v(1:end-1)<=2);
ds = find(diff([0;stimTimes])>0.05);
stimStarts = stimTimes(ds);
stimEnds = stimTimes(ds(2:end)-1); 
%%
stimDur = stimEnds-stimStarts(1:end-1);

%%

% pixelTuningCurveViewerSVD(U, V(:,1:end-1), t, stimStarts(1:end-1), stimDur, [-1 3])



%%

% h  = histogram(stimDur,'BinWidth',0.05);
%%
[N,edges,bin] = histcounts(stimDur,20)


events = edges(bin) + 0.1;

%%
pixelTuningCurveViewerSVD(U, V(:,1:end-1), t, stimStarts(1:end-1),events, [-1 1])



%%
c = ismember(tt,stimStarts);
starts_id = find(c)
%% Filter
