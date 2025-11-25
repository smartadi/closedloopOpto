%% plotting across sessions

%% Data analysis Script
% add pixel configuration


clc;
close all;
clear all;

%% experiment name

% With rewards %%%%%%%%%%%%%%%%%%%
% mn = 'AL_0033'; td = '2025-03-04'; 
% en = 1;
% mn = 'AL_0033'; td = '2025-03-04'; 
% en = 2;
% 
% mn = 'AL_0033'; td = '2025-03-05'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-03-18'; 
% en = 1;

% mn = 'AL_0033'; td = '2025-03-20'; 
% en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-04-18'; 
% en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; 
% en = 2;

% NEW LASER
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;

% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 1;
% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 2;


% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;

% mn = 'AL_0033'; td = '2025-04-19'; 
% en = 1;


% mn = 'AL_0033'; td = '2025-04-18'; 
% en = 4;

% mn = 'AL_0033'; td = '2025-04-20'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-04-20'; 
% en = 2;
% 
mn = 'AL_0039'; td = '2025-04-19'; 
en = 1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% No Reward, high controller delay

% mn = 'AL_0033'; td = '2024-12-18'; 
% en = 4;

% mn = 'AL_0033'; td = '2025-01-20'; 
% en = 3;

% mn = 'AL_0033'; td = '2025-02-12'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-02-26'; 
% en = 2;
% 
% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-02-21'; 
% en = 2;

% mn = 'AL_0033'; td = '2024-12-19'; 
% en = 2; % no variance reduction and control consteained to half
% Auto tunning no reward
% mn = 'AL_0033'; td = '2024-12-19'; 
% en = 1;
% mn = 'AL_0033'; td = '2024-12-20'; 
% en = 7;
% 
% mn = 'AL_0033'; td = '2024-12-23'; 
% en = 1;
% 
% % mn = 'AL_0033'; td = '2025-02-13'; 
% % en = 2;  % no parameter data
% 
% 
% 
% mn = 'AL_0033'; td = '2025-01-17'; 
% en = 1; % input data missing

% mn = 'AL_0033'; td = '2025-01-20'; 
% en = 3;


%candidates
% mn = 'AL_0033'; td = '2024-12-23'; 
% en = 1;
% 
% mn = 'AL_0033'; td = '2025-01-20'; 
% en = 3;
% mn = 'AL_0033'; td = '2025-02-12'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-02-26'; 
% en = 2;
% % 
% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-03-04'; 
% en = 1;
% mn = 'AL_0033'; td = '2025-03-04'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-03-05'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-03-20'; 
% en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; 
% en = 2;



% NEW LASER
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;
% 
% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 1;
% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 1;
% mn = 'AL_0033'; td = '2025-04-19'; 
% en = 1;
% 
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;
% mn = 'AL_0039'; td = '2025-04-30'; 
% en = 3;

% mn = 'AL_0033'; td = '2025-04-19'; 
% en = 1;
% mn = 'AL_0033'; td = '2025-04-20'; 
% en = 2;


% mn = 'AL_0033'; td = '2025-03-20'; 
% en = 4;


% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;
%% get data
% pathString = genpath('utils');
%     addpath(pathString);
%     % %%
%     % addpath('utils')
% d = initialize_data(mn,en,td);
% 
% d.params.pix_ids = [2,4,5,8,9,12,13];
% d.params.pix_inv = [170,320];
% %% Run Movie
% sigName = 'lightCommand';
% [tt, v] = getTLanalog(mn, td, en, sigName);
%     serverRoot = expPath(mn, td, en);
% 
% tInd = 1;
% traces(tInd).t = tt;
% traces(tInd).v = v;
% traces(tInd).name = sigName;
% traces(tInd).lims = [0 5];
% 
% % tInd = 2;
% % traces(tInd).t = tt;
% % traces(tInd).v = vel;
% % traces(tInd).name = 'wheelVelocity';
% % traces(tInd).lims = [-3000 3000];
% nSV = 500;
% 
% [U, V, t, mimg] = loadUVt(serverRoot, nSV);
% movieWithTracesSVD(U, V, t, traces, [], []);

%% display image
% if image has been extracted on the local PC


%% Load or save from image data
% 
% mode = 0  % from binary image
% % mode = 1 ; % from SVD
% 
% % r = 0; % dont read file
% r = 1; % read file
% data = getpixel_dFoF(d,mode,d.params.pixel,r);
% dFk = data.dFk;
% 
% % data_pix = getpixels_dFoF(d);
% % dFkp = data_pix.dFk;


%%  save data as npy

mouse.m1.mn = 'AL_0033'; mouse.m1.td = '2025-01-20'; 
mouse.m1.en = 3;
mouse.m1.trials = 120;

mouse.m2.mn = 'AL_0033'; mouse.m2.td = '2025-02-12'; 
mouse.m2.en = 2;
mouse.m2.trials = 200;

mouse.m3.mn = 'AL_0033'; mouse.m3.td = '2025-02-24'; 
mouse.m3.en = 2;
mouse.m3.trials = 200;

mouse.m4.mn = 'AL_0033'; mouse.m4.td = '2025-02-26'; 
mouse.m4.en = 2;
mouse.m4.trials = 200;

mouse.m5.mn = 'AL_0033'; mouse.m5.td = '2025-03-04'; 
mouse.m5.en = 1;
mouse.m5.trials = 60;


mouse.m6.mn = 'AL_0033'; mouse.m6.td = '2025-03-05'; 
mouse.m6.en = 2;
mouse.m6.trials = 30;

mouse.m7.mn = 'AL_0033'; mouse.m7.td = '2025-03-20'; 
mouse.m7.en = 4;
mouse.m7.trials = 100;

mouse.m8.mn = 'AL_0033'; mouse.m8.td = '2025-04-15'; 
mouse.m8.en = 2;
mouse.m8.trials = 60;


mouse.m9.mn = 'AL_0039'; mouse.m9.td = '2025-04-20'; 
mouse.m9.en = 1;
mouse.m9.trials = 100;


mouse.m10.mn = 'AL_0039'; mouse.m10.td = '2025-04-19'; 
mouse.m10.en = 1;
mouse.m10.trials = 100;

mouse.m11.mn = 'AL_0039'; mouse.m11.td = '2025-04-30'; 
mouse.m11.en = 3;
mouse.m11.trials = 100;


mouse.m12.mn = 'AL_0033'; mouse.m12.td = '2025-04-19'; 
mouse.m12.en = 1;
mouse.m12.trials = 100;

mouse.m13.mn = 'AL_0039'; mouse.m13.td = '2025-04-20'; 
mouse.m13.en = 2;
mouse.m13.trials = 100;




%%
% d = initialize_data(mouse.m9.mn,mouse.m9.en,mouse.m9.td);


% %
% mode = 0  % from binary image
% % mode = 1 ; % from SVD
% 
% % r = 0; % dont read file
% r = 1; % read file
% mouse.m1.data = getpixel_dFoF(d,mode,d.params.pixel,r);
% dFk = mouse.m1.data.dFk;
% trials = 100;
% 
% mouse.m1.data = controllerData(mouse.m1.data,d,trials);
% 
% % Plots for interleaved trials, 1 = save as pdf
% analysisPlots(mouse.m1.data,d,0);

%% Feedforward vs Feedback

fields = fieldnames(mouse);
for k = 1:length(fields)
    mouse.(fields{k}).d = initialize_data(mouse.(fields{k}).mn, mouse.(fields{k}).en, mouse.(fields{k}).td);
    
    %
    mode = 0;  % from binary image
    % mode = 1; % from SVD

    % r = 0; % dont read file
    r = 1; % read file
    mouse.(fields{k}).data = getpixel_dFoF(mouse.(fields{k}).d, mode, mouse.(fields{k}).d.params.pixel, r);
    dFk = mouse.(fields{k}).data.dFk;
    trials = 100;

    mouse.(fields{k}).data = controllerData(mouse.(fields{k}).data, mouse.(fields{k}).d, mouse.(fields{k}).trials);

    % Plots for interleaved trials, 1 = save as pdf
    % analysisPlots(mouse.(fields{k}).data, d, 0);
end
%% save data to npy

%%
Mvarnc = [];
Mvarwc = [];
for k = 1:length(fields)
    mouse.(fields{k}).d = initialize_data(mouse.(fields{k}).mn, mouse.(fields{k}).en, mouse.(fields{k}).td);
    
    %
    
nc =  mouse.(fields{k}).data.nc;
wc =  mouse.(fields{k}).data.wc;

    dFk = mouse.(fields{k}).data.dFk;
dur =3;
er_ncDfk=[];
vr_ncDfk=[];
pncDfk = [];
t = mouse.(fields{k}).d.timeBlue;
for j = 1: length(nc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(nc(j))));
    er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pncDfk = [pncDfk; dFk(i-35*3:i+35*(dur+3))];
end




er_wcDfk=[];
vr_wcDfk=[];
pwcDfk = [];
for j = 1: length(wc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(wc(j))));
    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pwcDfk = [pwcDfk; dFk(i-35*3:i+35*(dur+3))];
end

mouse.(fields{k}).data.er_wcDfk_l = er_wcDfk;
mouse.(fields{k}).data.er_ncDfk_l = er_ncDfk;
mouse.(fields{k}).data.pwcDfk_l = pwcDfk;

mouse.(fields{k}).data.vr_wcDfk_l = var(pwcDfk);
mouse.(fields{k}).data.vr_ncDfk_l = var(pncDfk);
mouse.(fields{k}).data.pncDfk_l = pncDfk;

Mvarnc = [Mvarnc;mouse.(fields{k}).data.vr_ncDfk_l];
Mvarwc = [Mvarwc;mouse.(fields{k}).data.vr_wcDfk_l];
end


%%

figure()
plot(mouse.m1.data.vr_wcDfk,'g','LineWidth',2);hold on
plot(mouse.m1.data.vr_ncDfk,'g','LineWidth',2);hold on

%%

figure()
plot(Mvarnc','r','LineWidth',2);hold on
plot(Mvarwc','g','LineWidth',2);hold on


%%
Mean_var_wc = mean(Mvarwc);
Mean_var_nc = mean(Mvarnc);


figure()
plot(Mean_var_nc,'r','LineWidth',2);hold on
plot(Mean_var_wc,'g','LineWidth',2);hold on


%%
close all;
 tp = -3:1/35:6;
 ref = -5*ones(length(tp),1);

 tpr = 0:1/35:3;
 la = -7*ones(length(tpr),1);




figure()
set(gcf, 'Renderer', 'opengl')
plot(tp,mouse.m13.data.pncDfk_l','m','LineWidth',0.3);hold on
plot(tp,mean(mouse.m13.data.pncDfk_l),'k','LineWidth',3)
plot(tp,ref,'--g','LineWidth',3)
plot(tpr,la,'r','LineWidth',4)
xline(0,'k','LineWidth',0.2);
xline(3,'k','LineWidth',0.2);
exportgraphics(gcf, 'figure_nc.svg', 'ContentType', 'vector');


figure()
set(gcf, 'Renderer', 'opengl')
plot(tp,mouse.m13.data.pwcDfk_l','b','LineWidth',0.3);hold on
plot(tp,mean(mouse.m13.data.pwcDfk_l),'k','LineWidth',3)
plot(tp,ref,'--g','LineWidth',3)
xline(0,'k','LineWidth',0.2);
xline(3,'k','LineWidth',0.2);
exportgraphics(gcf, 'figure_wc.svg', 'ContentType', 'vector');


figure()
set(gcf, 'Renderer', 'opengl')
plot(tp,Mean_var_nc,'m','LineWidth',2);hold on
plot(tp,Mean_var_wc,'b','LineWidth',2);hold on
xline(0,'k','LineWidth',0.2);
xline(3,'k','LineWidth',0.2);
exportgraphics(gcf, 'figure_var.svg', 'ContentType', 'vector');
