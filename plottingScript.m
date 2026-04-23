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
pathString = genpath('utils');
    addpath(pathString);
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
    mouse.(fields{k}).d = initialize_data_nosvd(mouse.(fields{k}).mn, mouse.(fields{k}).en, mouse.(fields{k}).td);
    
    %
    mode = 0;  % from binary image
    % mode = 1; % from SVD

    % r = 0; % dont read file
    r = 1; % read file
    mouse.(fields{k}).data = getpixel_dFoF(mouse.(fields{k}).d, mode, mouse.(fields{k}).d.params.pixel, r);
    dFk = mouse.(fields{k}).data.dFk;
    trials = 100;

    mouse.(fields{k}).data = controllerData_nomotion(mouse.(fields{k}).data, mouse.(fields{k}).d, mouse.(fields{k}).trials);

    % Plots for interleaved trials, 1 = save as pdf
    % analysisPlots(mouse.(fields{k}).data, d, 0);
end
%% save data to npy

%%
Mvarnc = [];
Mvarwc = [];
for k = 1:length(fields)
    % mouse.(fields{k}).d = initialize_data(mouse.(fields{k}).mn, mouse.(fields{k}).en, mouse.(fields{k}).td);
    
    %
    
nc =  mouse.(fields{k}).data.nc;
wc =  mouse.(fields{k}).data.wc;

    dFk = mouse.(fields{k}).data.dFk;
dur =3;
er_ncDfk=[];
vr_ncDfk=[];
pncDfk = [];
error_nc = [];
ncInp=[];

error_NC = [];


spont_dFk = []

t = mouse.(fields{k}).d.timeBlue;
for j = 1: length(nc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(nc(j))));
    er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pncDfk = [pncDfk; dFk(i-35*3:i+35*(dur+3))];


    error_nc = [error_nc;dFk(i:i+35*(dur))+5];

    spont_dFk = [spont_dFk;dFk(i-(6*35):i-1)];


    [a i2] = min(abs(ti - d.stimStarts(nc(j))));
    
    
    ncInp = [ncInp; d.inpVals(i2:i2+dur*2000)'];

end


wcInp=[];

er_wcDfk=[];
vr_wcDfk=[];
pwcDfk = [];
error_wc = [];
for j = 1: length(wc)
    [a i] = min(abs(t - mouse.(fields{k}).d.stimStarts(wc(j))));
    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
    
    pwcDfk = [pwcDfk; dFk(i-35*3:i+35*(dur+3))];

    error_wc = [error_wc;dFk(i:i+35*(dur))+5];

    spont_dFk = [spont_dFk;dFk(i-(6*35):i-1)];

    [a i2] = min(abs(ti - d.stimStarts(wc(j))));
    
    
    wcInp = [wcInp; d.inpVals(i2:i2+dur*2000)'];
end

mouse.(fields{k}).data.er_wcDfk_l = er_wcDfk;
mouse.(fields{k}).data.er_ncDfk_l = er_ncDfk;
mouse.(fields{k}).data.pwcDfk_l = pwcDfk;

mouse.(fields{k}).data.error_nc = error_nc;

mouse.(fields{k}).data.vr_wcDfk_l = var(pwcDfk);
mouse.(fields{k}).data.vr_ncDfk_l = var(pncDfk);
mouse.(fields{k}).data.pncDfk_l = pncDfk;

mouse.(fields{k}).data.error_wc = error_wc;


mouse.(fields{k}).data.ncInp = ncInp;
mouse.(fields{k}).data.wcInp = wcInp;

mouse.(fields{k}).data.spont_dFk = spont_dFk;

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

%%
fig= figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 6, 4];


plot(tp,Mean_var_nc,'r','LineWidth',4);hold on
plot(tp,Mean_var_wc,'Color',[0,0.5,0],'LineWidth',4);hold on
xline(0,'k','LineWidth',0.2);
xline(3,'k','LineWidth',0.2);
ylim([-2 12])

% exportgraphics(gcf, 'figure_var.svg', 'ContentType', 'vector');
yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;


patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');
 shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 2, ...
      'XLabel', '1 sec', 'YLabel', 'Variance', 'LineWidth', 5,'LabelGap',  0.04)
% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off


exportgraphics(fig, 'paper/all_variance.png', 'Resolution', 300);

% xlabel('time(sec)','FontSize',12,'FontWeight','bold')
% ylabel('Variance','FontSize',12,'FontWeight','bold')
%%
figure()
plot(mouse.m3.data.er_ncDfk,'or','LineWidth',2);hold on
plot(mouse.m3.data.er_wcDfk,'og','LineWidth',2)

%%
fig= figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 10, 4];


halfWidth = 0.3;
alphaFill = 0.5;


colA = [1 0 0];
colB = [0  0.5 0];
for k = 1:length(fields)
    er_ncDfk = mouse.(fields{k}).data.er_ncDfk;
    er_wcDfk = mouse.(fields{k}).data.er_wcDfk;


    [fA, yA] = ksdensity(er_ncDfk);
    fA = fA / max(fA) * halfWidth;

    fill([k - fA, k*ones(size(fA))], ...
         [yA,      fliplr(yA)], ...
         colA, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line A
    muA = mean(er_ncDfk);
    plot([ k - 0.1], [ muA], 'r*', 'LineWidth', 1.5);

    % -------- Distribution B (right) --------
    [fB, yB] = ksdensity(er_wcDfk);
    fB = fB / max(fB) * halfWidth;

    fill([k + fB, k*ones(size(fB))], ...
         [yB,      fliplr(yB)], ...
         colB, 'FaceAlpha', alphaFill, 'EdgeColor','none');

    % Mean line B
    muB = mean(er_wcDfk);
    plot([k+0.1], [ muB], 'g*', 'LineWidth', 1.5);
end
numExp = length(fields);
% ax.FontSize = 16
xlim([0.5 numExp+0.5])
xticks([])
xticklabels([])
yticklabels([])
set(gca, ...
    'Box','off', ...
    'XColor','none', ...
    'YColor','none', ...
    'TickDir','out', ...
    'XTick',[], ...
    'YTick',[], ...
    'Color','none');

text(-0.1 , 40, 'Trial MSE', ...
    'Color','k', 'FontSize', 12, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
    'Rotation', 90, 'Clipping','off');


text(5,-10, 'Sessions', ...
    'Color','k', 'FontSize', 12, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
    'Clipping','off');
% shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','Experiments','YLabel','Trial MSE','LineWidth',5)
exportgraphics(fig, 'paper/all_MSE.png', 'Resolution', 300);

% xlabel('Experiments', FontWeight='bold')
% ylabel('Tracking error',FontWeight='bold')



%% Single trial


% d.mv = d.motion.motion_1(1:2:end,1);

d = mouse.m10.d;
dur = d.params.dur;
data = mouse.m10.data;
dFk = mouse.m10.data.dFk;
nc = mouse.m10.data.nc;
wc = mouse.m10.data.wc;
t = d.timeBlue;
close all
trial=6;

j = nc(trial)
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
Tref = 0:0.0285:dur;
% close all
figure()
subplot(1,2,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'r','LineWidth',3);hold on
plot(Tref,-5*ones(1,length(Tref)),'--k','LineWidth',2)
plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
xlim([-3,6])
xline(0)
xline(3)
ylabel('dF/F','FontSize',12,'FontWeight','bold')
xlabel('Time (s)','FontSize',12,'FontWeight','bold')
yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off
box off
xticklabels([])
yticklabels([])

j = wc(trial)
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



subplot(1,2,2)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'Color',[0,0.5,0],'LineWidth',3);hold on
plot(Tref,-5*ones(1,length(Tref)),'--k','LineWidth',2)
plot(tt(k:k2)-tt(k),2*v(k:k2),'b','LineWidth',3)
xlim([-3,6])
xline(0)
xline(3)
xlabel('Time (s)','FontSize',12,'FontWeight','bold')

yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');

% Keep data on top
uistack(findobj(gca,'Type','line'),'top')
hold off
box off
xticklabels([])
yticklabels([])

%%
tp = 0:1/35:3;
figure()
hold on;
colA = [1 0 0];
colB = [0  0.5 0];
for k = 1:length(fields)
    ncDfk = mouse.(fields{k}).data.ncDfk(:,35:4*35);
    

    
    step = mean(mean(ncDfk(35:4*35)));
    plot(tp,step- mean(ncDfk), 'Color',colA, 'LineWidth', 2);
end
xticks([])
xlabel('time(secs)', FontWeight='bold')
ylabel('dF/F',FontWeight='bold')


%% single plots

% d.ref = -5;
% analysisPlots_paper(data,d,0);

%%


close all
fig= figure('Color','w'); hold on;
fig.Units    = 'inches';
fig.Position = [1, 1, 6, 4];


colA = [1 0 0];
colB = [0  0.5 0];
Error_nc=[];
Error_wc=[];

error_WC=[];
error_NC =[];

t = 0:1/35:3;
t1 = -3:1/35:6;
for k = 1:length(fields)
    error_NC = mean(mouse.(fields{k}).data.pncDfk_l - [mouse.(fields{k}).data.pncDfk_l(:,1:35*3),-5*ones(length(mouse.(fields{k}).data.nc),35*3),mouse.(fields{k}).data.pncDfk_l(:,35*6+1:end)])
    error_WC = mean(mouse.(fields{k}).data.pwcDfk_l - [mouse.(fields{k}).data.pwcDfk_l(:,1:35*3),-5*ones(length(mouse.(fields{k}).data.wc),35*3),mouse.(fields{k}).data.pwcDfk_l(:,35*6+1:end)])

    error_nc = mean(mouse.(fields{k}).data.error_nc);
    error_wc = mean(mouse.(fields{k}).data.error_wc);
    
    Error_nc = [Error_nc;abs(error_nc)];
    Error_wc = [Error_wc;abs(error_wc)];



    % plot(t,abs(error_nc), 'Color',colA, 'LineWidth', 0.3);
    % plot(t,abs(error_wc), 'Color',colB, 'LineWidth', 0.3);


    plot(t1,abs(error_NC), 'Color',colA, 'LineWidth', 0.3, 'HandleVisibility','off');
    plot(t1,abs(error_WC), 'Color',colB, 'LineWidth', 0.3, 'HandleVisibility','off');
    
end
plot(t,zeros(1,length(error_wc)),'--k', 'LineWidth', 2, 'HandleVisibility','off');

plot(t,mean(Error_nc), 'Color',colA, 'LineWidth', 5);
plot(t,mean(Error_wc), 'Color',colB, 'LineWidth', 5);
yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
xlim([0 3])
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');
xticks([])
ylim([-1 6])

text(3.1, 0, '0', ...
    'Color','k', 'FontSize', 10, ...
    'HorizontalAlignment','right', 'VerticalAlignment','middle', 'Clipping','off');


legend({'Open-Loop', 'Closed-Loop'}, ...
    'Location','northeast', ...
    'Box','off', FontSize=12, FontWeight='bold')

shortCornerAxes_plot(gca, 'XLength', 0.5, 'YLength', 1, ...
      'XLabel', '500 msec', 'YLabel', 'MSE dF/F', 'LineWidth', 5,'LabelGap',  0.04)
exportgraphics(fig, 'paper/all_average.png', 'Resolution', 300);



%% plot the open loop step response

close all
figure(); hold on;

set(gcf, 'Renderer', 'opengl')
colA = [1 0 0];
colB = [0 0.5 0];

t = 0:1/35:3;

for k = 7:7
    e_nc = mouse.(fields{k}).data.error_nc;   % n x t (trials x time)

    mu  = mean(e_nc, 1);        % 1 x t
    sig = std(e_nc, 0, 1);      % 1 x t (N-1 normalization)

    % Mean-center (match your plot(t, error_nc - mean(error_nc)))
    mu0  = mu  - mean(mu);
    up0  = (mu + sig) - mean(mu);
    low0 = (mu - sig) - mean(mu);

    % Shaded mean ± std (put behind the line)
    hfill = fill([t fliplr(t)], ...
                 [up0 fliplr(low0)], ...
                 [0 0 1], ...
                 'EdgeColor','none', ...
                 'FaceAlpha',0.1);
    hfill.HandleVisibility = 'off';
    uistack(hfill,'bottom');

    % Bold mean line
    plot(t, mu0, 'b', 'LineWidth', 2);
end

% Zero line (NOTE: your original uses error_wc, which isn't defined here)
plot(t, zeros(1, numel(t)), '--k', 'LineWidth', 2);

yl = ylim;   % current y-limits
x1 = 0;
x2 = 3;
patch([x1 x2 x2 x1], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none');

xticks([])

shortCornerAxes_plot(gca,'Frac',0.1,'XLabel','time(secs)','YLabel','dF/F','LineWidth',5)



%% plot the open loop step response

close all
figure(); hold on;

set(gcf, 'Renderer', 'opengl')

t = -3:1/35:(dur+3);

% ---- Your three indices ----
custom_idx = [4 9 11];   % change as needed

% ---- Your experimental colors ----
expColors = [0.2 0.4 0.8;
             0.8 0.2 0.2;
             0.2 0.8 0.4];

ax = gca;

hLegend = gobjects(length(custom_idx),1);
legTxt  = strings(length(custom_idx),1);
t0 = 0:1/35:3;
for i = 1:length(custom_idx)
% for i = 1:1

    k = custom_idx(i);
    e_nc = mouse.(fields{k}).data.pwcDfk_l;   % n x t

    mu  = mean(e_nc, 1);
    sig = std(e_nc, 0, 1);

    % mu0  = mu - mean(mu);
    mu0  = mu;
    up0  = (mu + sig) - mean(mu);
    low0 = (mu - sig) - mean(mu);

    c = expColors(i,:);

    % ---- Shaded mean ± std (hidden from legend)
    hfill = fill([t fliplr(t)], ...
                 [up0 fliplr(low0)], ...
                 c, ...
                 'EdgeColor','none', ...
                 'FaceAlpha',0.15);
    hfill.HandleVisibility = 'off';
    uistack(hfill,'bottom');


alphaVal = 0.6;
cLight = alphaVal * c + (1-alphaVal) * [1 1 1];   % blend toward white

plot(t0, ...
     ones(1,numel(t0)) * mean(mu(3*35:6*35)), ...
     'LineWidth', 2, ...
     'Color', cLight, ...
     'HandleVisibility','off');
    % ---- Mean line (store handle for legend)
    hLegend(i) = plot(t, mu0, ...
                      'Color', c, ...
                      'LineWidth', 2);

    % legTxt(i) = fields{k};   % or custom label
    legTxt{i} = sprintf('Session %d',i);
end


t0 = 0:1/35:3;
% Zero line (hidden from legend)
h0 = plot(t0, -5*ones(1, numel(t0)), '--k', 'LineWidth', 2);
h0.HandleVisibility = 'off';

yl = ylim;
patch([0 3 3 0], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none', ...
      'HandleVisibility','off');

xticks([])

% ---- Your legend style ----
% lgd = legend(ax, hLegend, legTxt, ...
%              'Box','off', ...
%              'Color','none');

shortCornerAxes_plot(ax,'Frac',0.1,'XLabel','time(secs)','YLabel','dF/F','LineWidth',5)


%% plot the open loop step response

close all;
fig = figure;
fig.Units = 'inches';
fig.Position = [1, 1, 6, 4];  % [1,1]
hold on;

set(gcf, 'Renderer', 'opengl')

t = -3:1/35:(dur+3);

% ---- Your three indices ----
custom_idx = [4 9 11];   % change as needed


% custom_idx = [3 6 8];   % change as needed

% ---- Your experimental colors ----
expColors = [0.2 0.4 0.8;
             0.8 0.2 0.2;
             0.2 0.8 0.4];

ax = gca;

hLegend = gobjects(length(custom_idx),1);
legTxt  = strings(length(custom_idx),1);
t0 = 0:1/35:3;
for i = 1:length(custom_idx)
% for i = 1:1

    k = custom_idx(i);
    e_nc = mouse.(fields{k}).data.pncDfk_l;   % n x t

    mu  = mean(e_nc, 1);
    sig = std(e_nc, 0, 1);

    % mu0  = mu - mean(mu);
    mu0  = mu;
    up0  = (mu + sig) - mean(mu);
    low0 = (mu - sig) - mean(mu);

    c = expColors(i,:);

    % ---- Shaded mean ± std (hidden from legend)
    hfill = fill([t fliplr(t)], ...
                 [up0 fliplr(low0)], ...
                 c, ...
                 'EdgeColor','none', ...
                 'FaceAlpha',0.15);
    hfill.HandleVisibility = 'off';
    uistack(hfill,'bottom');


alphaVal = 0.6;
cLight = alphaVal * c + (1-alphaVal) * [1 1 1];   % blend toward white


plot(t,2+var(e_nc),'Color', c, ...
                      'LineWidth', 1)

plot(t0, ...
     ones(1,numel(t0)) * mean(mu(3*35:6*35)), ...
     'LineWidth', 2, ...
     'Color', c, ...
     'HandleVisibility','off');
    % ---- Mean line (store handle for legend)
    hLegend(i) = plot(t, mu0, ...
                      'Color', c, ...
                      'LineWidth', 3);

    % legTxt(i) = fields{k};   % or custom label
    legTxt{i} = sprintf('Session %d',i);
end


t0 = 0:1/35:3;
% Zero line (hidden from legend)
% h0 = plot(t0, -5*ones(1, numel(t0)), '--k', 'LineWidth', 2);
% h0.HandleVisibility = 'off';

yl = ylim;
patch([0 3 3 0], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.9 0.9 0.9], ...
      'FaceAlpha', 0.3, ...
      'EdgeColor', 'none', ...
      'HandleVisibility','off');

xticks([])

% ---- Your legend style ----
lgd = legend(ax, hLegend, legTxt, ...
             'Box','off', ...
             'Color','none','FontSize', 14, 'FontWeight','bold');



lgd = legend(ax, hLegend, legTxt, 'Box','off','Color','none','Location','southeast');
lgd.ItemTokenSize = [14 6];
lgd.AutoUpdate = 'off';

% legend(ax2, [hA hD hC hB], {'Open-Loop', 'Closed-Loop','Stim', 'Ref'}, ...
%     'Location','northeast', ...
%     'Box','off', FontSize=12, FontWeight='bold')
% shortCornerAxes_plot(ax,'Frac',0.1,'XLabel','time(secs)','YLabel','dF/F  /  Variance','LineWidth',5,'LabelGap',0.05)

text(-0.1-3, 10, 'Variance', ...
    'Color','k', 'FontSize', 12, 'FontWeight','bold', ...
    'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
    'Rotation', 90, 'Clipping','off');


 shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 3, ...
      'XLabel', '1 sec', 'YLabel', '3% dF/F', 'LineWidth', 5,'LabelGap',  0.04)

% shortCornerAxes_plot(gca,'Frac',0.15,'XLabel','Time','YLabel','dF/F','LineWidth',5,'LabelGap',0.05)
exportgraphics(fig, 'paper/step_response.png', 'Resolution', 300);



%%
close all;

n_sample   = 3;                          % number of fields to sample
custom_idx = randperm(13, n_sample);     % random sample of n ints from 1:13



batch_sizes = 10:10:100;
m_repeats   = 500;          % number of random draws per batch size

colors = lines(length(custom_idx));



all_data  = cell(length(custom_idx), length(batch_sizes));  % {field, batchsize} -> m values

for i = 1:length(custom_idx)
    spont_dFk = mouse.(fields{custom_idx(i)}).data.spont_dFk;   % trials x time
    n_trials  = size(spont_dFk, 1);

    for bi = 1:length(batch_sizes)
        n = batch_sizes(bi);
        vals = zeros(m_repeats, 1);
        for r = 1:m_repeats
            idx  = randperm(n_trials, min(n, n_trials));
            batch = spont_dFk(idx, :);          % n x time
            % vals(r) = sum(var(batch, 0, 1));    % sum of per-timepoint variance across trials

            vals(r) = sum(var(batch));    % sum of per-timepoint variance across trials
        end
        all_data{i, bi} = vals;
    end
end

% --- plot: mean ± SEM per field, connected by line ---
x_positions = 1:length(batch_sizes);
capWidth     = 0.2;



fig = figure; hold on

fig.Units = 'inches';
fig.Position = [1, 1, 6, 4];  % [1,1]

hLegend = gobjects(length(custom_idx), 1);
legTxt  = cell(length(custom_idx), 1);

% --- first pass: collect raw means to compute per-field grand mean ---
rawMeans = zeros(length(custom_idx), 1);
allMeanVals = zeros(length(custom_idx), length(batch_sizes));
allSemVals  = zeros(length(custom_idx), length(batch_sizes));

for i = 1:length(custom_idx)
    for bi = 1:length(batch_sizes)
        vals = all_data{i, bi};
        allMeanVals(i, bi) = mean(vals);
        allSemVals(i, bi)  = std(vals) / sqrt(m_repeats);
    end
    rawMeans(i) = mean(allMeanVals(i, :));
end

% --- second pass: min-max normalize then scale by grand mean ---
% curves span [0, rawMean] so y-amplitude encodes mean variance
for i = 1:length(custom_idx)
    c = colors(i,:);

    mn = min(allMeanVals(i,:));
    mx = max(allMeanVals(i,:));
    scale = mx - mn + eps;
    meanVals = ((allMeanVals(i,:) - mn) / scale) * rawMeans(i);
    semVals  = (allSemVals(i,:) / scale) * rawMeans(i);

    xpos = x_positions;

    % SEM bars with caps
    for bi = 1:length(batch_sizes)
        plot([xpos(bi) xpos(bi)], [meanVals(bi)-semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)-semVals(bi), meanVals(bi)-semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)+semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot(xpos(bi), meanVals(bi), 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', c, 'HandleVisibility','off');
    end

    % Connecting line through means
    hLegend(i) = plot(xpos, meanVals, '-', 'LineWidth', 2.0, 'Color', c);
    legTxt{i}  = sprintf('Session %d', i);
end

ax = gca;
ax.LineWidth  = 1.5;
ax.FontName   = 'Arial';
ax.FontSize   = 12;
ax.FontWeight = 'bold';
ax.TickDir    = 'out';
ax.Box        = 'off';
ax.XColor = 'k';              % keep ticks and labels visible
ax.YColor = 'none';           % hide y axis line and ticks
ax.XAxis.LineWidth = 0.001;    % make x axis spine invisible without hiding ticks

% ticks only at 20,40,60,80,100
tick_bs  = [20 40 60 80 100];
tick_pos = x_positions(ismember(batch_sizes, tick_bs));
xticks(tick_pos);
xticklabels(arrayfun(@num2str, tick_bs, 'UniformOutput', false));
ax.XAxis.TickLength = [0.02 0.02];

% y label only, no ticks or axis line
yticks([]);
yl = ylabel('Normalized variance', 'FontName','Arial', 'FontSize',12, 'FontWeight','bold');
yl.Color = 'k';
xl = xlabel('Batch size (trials)', 'FontName','Arial', 'FontSize',12, 'FontWeight','bold');
xl.Color = 'k';

lgd = legend(ax, hLegend, legTxt, 'Box','off', 'Color','none');
lgd.ItemTokenSize = [14 6];
lgd.AutoUpdate = 'off';
exportgraphics(fig, 'paper/spont_variance.png', 'Resolution', 300);

%% Variance vs batch size — log-log scale (raw, no normalization)

fig_ll = figure('Color','w'); hold on;
fig_ll.Units    = 'inches';
fig_ll.Position = [1, 1, 6, 4];

hLegend_ll = gobjects(length(custom_idx), 1);
legTxt_ll  = cell(length(custom_idx), 1);

for i = 1:length(custom_idx)
    c        = colors(i,:);
    logM     = log(allMeanVals(i,:));
    meanVals = log(logM);
    semVals  = allSemVals(i,:) ./ (allMeanVals(i,:) .* logM);  % delta method for log(log(x))
    xpos     = x_positions;

    for bi = 1:length(batch_sizes)
        plot([xpos(bi) xpos(bi)], [meanVals(bi)-semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)-semVals(bi), meanVals(bi)-semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot([xpos(bi)-capWidth xpos(bi)+capWidth], [meanVals(bi)+semVals(bi), meanVals(bi)+semVals(bi)], ...
            '-', 'LineWidth', 2.5, 'Color', c, 'HandleVisibility','off');
        plot(xpos(bi), meanVals(bi), 'o', 'MarkerSize', 8, ...
            'MarkerFaceColor', c, 'MarkerEdgeColor', c, 'HandleVisibility','off');
    end

    hLegend_ll(i) = plot(xpos, meanVals, '-', 'LineWidth', 2.0, 'Color', c);
    legTxt_ll{i}  = sprintf('Session %d', i);
end

set(gca, 'XScale', 'log');

ax = gca;
ax.LineWidth  = 1.5;
ax.FontName   = 'Arial';
ax.FontSize   = 12;
ax.FontWeight = 'bold';
ax.TickDir    = 'out';
ax.Box        = 'off';
xticks([]);

lgd_ll = legend(ax, hLegend_ll, legTxt_ll, 'Box','off', 'Color','none');
lgd_ll.ItemTokenSize = [14 6];
lgd_ll.AutoUpdate    = 'off';







shortCornerAxes_plot(gca, 'Frac',0.05, 'XLabel','Batch size (trials)', 'YLabel','Variance', 'LineWidth',5, 'LabelGap',0.05);
% exportgraphics(fig_ll, 'paper/spont_variance_loglog.png', 'Resolution', 300);

%% Single-session paper plots (m10)
close all;
sess = mouse.m10;
d    = sess.d;
data = sess.data;

% map loop-computed fields to names expected by analysisPlots_paper
data.pncDfk   = sess.data.pncDfk_l;
data.pwcDfk   = sess.data.pwcDfk_l;
data.er_ncDfk = sess.data.er_ncDfk_l;
data.er_wcDfk = sess.data.er_wcDfk_l;

d.ref = -5;

analysisPlots_paper(data, d, 0);
%%


