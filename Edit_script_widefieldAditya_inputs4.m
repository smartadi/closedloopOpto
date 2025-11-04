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
pixelCorrelationViewerSVD(U,V)

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
% 
% movieWithTracesSVD(U, V, t, traces, [], []);

%%

% matchBlocks2Timeline(mn,td,[3 4],[])


%% 

% dV = [zeros(size(V,1),1) diff(V,[],2)];

%%

% [newU, newV] = dffFromSVD(U, V, mimg);


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

%%

pixelTuningCurveViewerSVD(U, V(:,:), t(1:end-1), stimStarts(1:end-1), stimDur, [-1 3]);



%%

h  = histogram(amps,'BinWidth',0.25);
%%
[N,edges,bin] = histcounts(amps,6);


events = edges(bin) + 0.1;

%%
% pixelTuningCurveViewerSVD(U, V(:,1:end-1), t, stimStarts(1:end-1),events, [-1 3])
pixelTuningCurveViewerSVD(U, V, t(1:end-1), stimStarts(1:end-1),events, [-1 5])

%% sort



uu = reshape(U(:,:,1:500),560*560,500);



%% signal
Uu=reshape(U,560*560,500);
%%
p = [432,241];
j=1
% for i=1:N
    Im = Uu((p(j,2)-1)*560 + p(j,1),1:50)*V(1:50,:);
% end
df = ones(1,500);
dfFF = ones(1,500);
mI = ones(1,500);
for i=501:length(Im)
    mI = [mI,mean(Im(:,i-500:i))];
    df = [df,Im(:,i) - mean(Im(:,i-500:i))];
    dfFF = [dfFF, df(:,end)/mean(Im(:,i-500:i))]; 
end




Im_mean = mimg(p(1),p(2));
dfF = (Im)/Im_mean*100;
%%
close all
figure()
plot(t(1:end-1),Im)


figure()
plot(t(1:end-1),dfFF)


figure()
plot(t(1:end-1),dfF)

figure()
plot(t(1:end-1),mI)

%%
close all
j=120
[a i] = min(abs(t - stimStarts(j)));

figure()
plot(t(i-100:i+400),Im(i-100:i+400))
xline(t(i))

figure()
plot(t(i-100:i+400),dfF(i-100:i+400))
xline(t(i))
%%
aa = find(stimDur > 1.9);

%%
close all
figure()
for j = 1:length(aa)
j
[a i] = min(abs(t - stimStarts(aa(j))));


plot(Im(i-100:i+400));hold on

end
xline(100)
%%

%%
close all
figure()
% for j = 1:length(aa)
j = 10;
% [a i] = min(abs(t - stimStarts(aa(j))));
% [a2 i2] = min(abs(t - stimEnds(aa(j))));



[a i] = min(abs(t - stimStarts(j)));
[a2 i2] = min(abs(t - stimEnds(j)));

plot(t(i-100:i+400),Im(i-100:i+400));hold on

% end
xline(t(i))
xline(t(i2))
title(num2str(stimDur(aa(j))))


%%


%%
I_val = [];
for j = 1:length(stimEnds)
    [a i] = min(abs(t - stimStarts(j)));
    [a2 i2] = min(abs(t - stimEnds(j)));
    I_val = [I_val;dfF(i:i+100)];
    
end
%% max inhibition

I_maxval = min(I_val,[],2);

%%
close all;
figure()
plot(amps,I_maxval,'ro')
xlabel('laseramp')
ylabel('max inhibition')


%%
clc
I_val = [];
Ii_val = [];
II=[];

Imean_val=[]
for j = 1:length(stimEnds)
    j
    [a i] = min(abs(t - stimStarts(j)));
    [a2 i2] = min(abs(t - stimEnds(j)));
    % I_val = [I_val;Im(i:i+100)];
    % size([Im(i:i2),zeros(1,70-(i2-i))])
    Ii_val = [Ii_val;dfF(i:i2),zeros(1,70-(i2-i))];
    Imean_val=[Imean_val;mean(max(-dfF(i:i2),0))]
    II = [II,i2-i];
    
end

Imin_val = max(max(-Ii_val,0),[],2);

[m n] = size(Ii_val)

energy_val = sum(max(-Ii_val,0).^2,2)/100;

integral_val = sum(max(-Ii_val,0),2)/100;
%% mapping
close all;

figure()
plot(amps,Imin_val,'or')
xlabel('amlpitude')
ylabel('inhibition')
grid on


figure()
plot(amps,energy_val,'or')
xlabel('amlpitude')
ylabel('inhigition energy')
grid on

%%
f = fit(amps',double(Imin_val),"poly2");

plot( f,amps, double(Imin_val) )
xlabel('amlpitude')
ylabel('max inhibition')
title('max(df/F)')
%%


f = fit(amps',double(energy_val),"poly2");

plot( f,amps, double(energy_val) )
xlabel('amlpitude')
title('$\sum (df/F)^2$ ','Interpreter','latex')

%%
close all;

f = fit(amps',double(integral_val),"poly2");

plot( f,amps, double(integral_val) )
xlabel('amlpitude')
ylabel('inhibition integral')
title('$\sum (df/F)^2$ ','Interpreter','latex')

%%
close all;


f = fit(amps',double(Imean_val),"poly2");

plot( f,amps, double(Imean_val) )
xlabel('amlpitude')
ylabel('inhibition mean')
title('mean value $\sum (df/F)/n$','Interpreter','latex')