%% Data analysis Script
% add pixel configuration


clc;
close all;
clear all;

%% experiment name



mn = 'AL_0041'; td = '2026-02-07'; 
en = 2;

% mn = 'AL_0041'; td = '2026-02-09'; 
% en = 3;

% mn = 'AL_0041'; td = '2026-02-10'; 
% en = 2;

% mn = 'AL_0041'; td = '2026-02-10'; 
% en = 2;

% mn = 'AL_0041'; td = '2026-02-21'; 
% en = 3;

% mn = 'AL_0041'; td = '2026-02-21'; 
% en = 4;
%% get data
pathString = genpath('utils');
    addpath(pathString);
    % %%
    % addpath('utils')
d = initialize_data(mn,en,td);

d.params.pix_ids = [2,4,5,8,9,12,13];
d.params.pix_inv = [170,320];
%% Run Movie



try 
    sigName = 'lightCommand638';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
catch
    sigName = 'lightCommand';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
end
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

% movieWithTracesSVD(U, V, t, traces, [], []);

%% display image
% if image has been extracted on the local PC
% displayFrame(mn, td, en, d, d.params.pixels);

%% Load or save from image data

mode = 0  % from binary image
% mode = 1 ; % from SVD
%
% r = 0; % dont read file
r = 1; % read file
[data,dFk_temp] = getpixel_dFoF(d,mode,d.params.pixel,r);
dFk = data.dFk;
%%
% data_pix = getpixels_dFoF(d);
% dFkp = data_pix.dFk;

%% Trial Samples
% d.mv = d.motion.motion_1;
% d.mv = d.motion.motion_1(1:2:end,1);


dur = d.params.dur;
t = d.timeBlue;
close all
j=5;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
close all
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
ylabel('dF/F trace')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)
ylabel('Input Values');


% subplot(3,1,3)
% plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
% plot(Tout,5*ones(1,length(Tout)))
% xlim([-3,6])
% xline(0)
% xline(3)
% ylabel('motion')
% xlabel('Time (s)');
% sgtitle('trial sample')

%%

try
    d.ref_var = dlmread(append(serverRoot,"/reference.csv"),' ');
catch
end


%% Feedforward vs Feedback 

trials = 100;

% d.ref=-2;

% data = controllerData(data,d,trials);


data = controllerData_var(data,d,trials);

%%
close all;
analysisPlots_var(data,d,0);

%%

Ref=[];
for j = 1: length(d.stimStarts)
    [a i] = min(abs(d.timeBlue - d.stimStarts((j))));
    Ref = [Ref; d.ref_var(i:i+35*(d.params.dur))'];
end



Ref = Ref(end-99:100,:);

%% get trail stamps
nc = data.nc;
wc = data.wc;
%% Invariance tests
invarianceAnalysis(data,d);
%%


features = feature_analysis(data,d);

mf = features.mf;
v1 = features.v1;
v2 = features.v2;
v3 = features.v3;

%% Classify initial condition

X0_wc = zeros(length(wc), 1); % Preallocate for efficiency
for j = 1:length(wc)
    [~, i] = min(abs(t - d.stimStarts(wc(j))));
    X0_wc(j) = dFk(i);
end

X0_nc = zeros(length(nc), 1); % Preallocate for efficiency
for j = 1:length(nc)
    [~, i] = min(abs(t - d.stimStarts(nc(j))));
    X0_nc(j) = dFk(i);
end

X0 = zeros(length(d.stimStarts), 1); % Preallocate for efficiency
for j = 1:length(d.stimStarts)
    [~, i] = min(abs(t - d.stimStarts(j)));
    X0(j) = dFk(i);
end



%% Analysis based on H2 
pixel_test(d,data,dFkp);
%%
dataPixel = pixelAnalysis(d,data,dFkp);
%%
close all;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;

pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;

er = sort(er_wcDfk);
ner = sort(er_ncDfk);

%% Analyzer
close all;
i = 10;
motionPlotter(i,d,data)

%%



%%

ncmotion_pre = sum(data.ncmotion(:,1:35*1),2);
wcmotion_pre = sum(data.wcmotion(:,1:35*1),2);


ncmotion_during = sum(data.ncmotion(:,35:(dur)*35),2);
wcmotion_during = sum(data.wcmotion(:,35:(dur)*35),2);



%% Thresholding
close all
figure()
subplot(1,2,1)
s = scatter3(X0_wc,wcmotion_pre,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,ncmotion_pre,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('motion')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% % colorbar
% % zlim([0,100])
% % clim([0,80])
title('regularizability dependece on motion pre trial')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;
% 
subplot(1,2,2)
s = scatter3(X0_wc,wcmotion_during,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,ncmotion_during,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('motion')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on motion during trial')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;
% 
% 
% subplot(1,3,3)
% s = scatter3(X0,f3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
% s = scatter3(XX0,f3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
% xlabel('x_0 df/F')
% ylabel('freq marker')
% zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% % colorbar
% % zlim([0,100])
% % clim([0,80])
% title('regularizability dependece on state and parameters')

%%
dur = d.params.dur
t = d.timeBlue;
close all
j=50;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
close all
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('analysis')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('analysis')


%%

rref = Ref(end,:);


figure()
ax =gca;
plot(rref,'LineWidth',4);
shortCornerAxes_plot(ax,'Frac',0.1,'XLabel','time(secs)','YLabel','Ref','LineWidth',5)
