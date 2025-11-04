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

stimEnds = [stimEnds;stimStarts(end)+2]; 

%% Amps
amps=[];
for i = 1:length(stimStarts)
    amps = [amps,max(v(find(tt == stimStarts(i)):find(tt == stimEnds(i))))];
end

%%
stimDur = stimEnds-stimStarts;

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
j=1
% for i=1:N
%     Im = Uu((p(j,2)-1)*560 + p(j,1),1:50)*V(1:50,:);
% % end
% 
% p = [432,241];
% 
% J = 5;
% pr = randi([-50 50],J,2);
% p = p+pr;
% 
% dfF=[];
% for j = 1:J

Im=[];
for a = -3:1:3
    for b = -3:1:3
        Im = [Im;Uu((p(j,2)+b-1)*560 + p(j,1)+a,1:50)*V(1:50,:)];
    end
end
Im = mean(Im,1);
Im_mean = mean(mimg(p(2)-3:p(2)+3,p(1)-3:p(1)+3),'all');
dfF = (Im)/Im_mean*100;






Im_mean = mimg(p(1),p(2));
dfF = (Im)/Im_mean*100;
%%
close all
figure()
plot(t(1:end-1),Im)

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
j=40;
[a i] = min(abs(t - stimStarts(aa(j))));
[a i2] = min(abs(t - stimEnds(aa(j))));
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       

plot(t(i-35:i2+35),Im(i-35:i2+35));hold on
xline(t(i2))
xline(t(i))
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
%%


f = fit(amps',double(energy_val),"poly2");

plot( f,amps, double(energy_val) )
xlabel('amlpitude')
ylabel('inhibition energy')
%%


f = fit(amps',double(integral_val),"poly2");

plot( f,amps, double(integral_val) )
xlabel('amlpitude')
ylabel('inhibition integral')

%%

close all;
figure()

f = fit(amps',double(Imean_val),"poly2");
y=[];
subplot(1,2,1)
plot( f,amps, double(Imean_val));
hold on;
for i=1:length(edges)-1
    y = [y,Imean_val(bin==i)]
    
end

aa = 0:1:5;
boxplot(y)

xlabel('Input Amlpitude','FontSize',11, 'FontWeight','bold')
ylabel('Mean Pixel Inhibition','FontSize',11, 'FontWeight','bold')
%
% close all;
f = fit(amps',double(integral_val),"poly2");
y=[];
subplot(1,2,2)
plot( f,amps, double(integral_val));
hold on;
for i=1:length(edges)-1
    y = [y,integral_val(bin==i)]
    
end
boxplot(y,'Whisker',1,'Widths',.3)

xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition Energy','FontSize',11, 'FontWeight','bold')
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
hgexport(gcf,'images/func_fit.pdf',figure_property); %Set desired file name
%%
close all;
fig=plot(f,'r--');
set(fig,'lineWidth',2);
%.................. ^
hold on;
plot(amps, double(integral_val),'ob','MarkerSize',1.5);

for i=1:length(edges)-1
    y = [y,integral_val(bin==i)]
    
end
boxplot(y,'Whisker',1,'Widths',.3)

xlabel('amlpitude')
ylabel('Inhibition energy')
%%
DF=[];
for i=1:length(edges)-1

l = find(bin==i);
as=[];
for j=1:length(l)
    [a i] = min(abs(t - stimStarts(l(j))));
    % [a i2] = min(abs(t - stimEnds(l(j))));
    as = [as; dfF(i-35:i+105)];
end
DF = [DF;mean(as,1)];
end


figure()
plot(DF')

%%


close all
figure()
j=150;
[a i] = min(abs(t - stimStarts(aa(j))));
[a i2] = min(abs(t - stimEnds(aa(j))));
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       


plot(t(i-35:i+105),Im(i-35:i+105)/50,'r','LineWidth',1.5);hold on
plot(t(i-35:i+105),dfF(i-35:i+105),'r','LineWidth',1.5);hold on
plot(t(i-35:i+105),DF(bin(j),:),'--k','LineWidth',2);hold on
xline(t(i2))
xline(t(i))