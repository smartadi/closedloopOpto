%% Data analysis Script
% add var and fft to a function


clc;
close all;
clear all;
githubDir = "/home/nimbus/Documents/Brain/"


% Script to analyze widefield/behavioral data from 
addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab
addpath('utils')



%% experiment name: move to g sheet

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
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;
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
mn = 'AL_0039'; td = '2025-04-19'; 
en = 1;
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

serverRoot = expPath(mn, td, en);

d = loadData(serverRoot,mn,td,en);

%% Get Stim Times (Start and End)

% mode = 0 % from stim search (if stim = 0 during exp, this method fails)
mode = 1; % from param data (Directly use logged input times from Rainier)

d = findStims(d,mode);

%% Add motion to data structure (the motion svd is not processed for some datasets)

d.motion = load(append(serverRoot,'/face_proc.mat'));

mv1 = d.motion.motSVD_0(1:2:end,1);
%%



pix = [d.params.pixel(1);d.params.pixel(1)]

% Used to center the image
offsetx = 20;
offsety = -40;

% Generate an point grid
px = [200,300,150,200,300,350,100,200,300,400,100,200,300,400]+offsetx;
py = [150,150,225,225,225,225,325,325,325,325,425,425,425,425]+offsety;


frame = double([d.params.pixel(1),px;d.params.pixel(2),py]); 


% plot
source_dir ='/mnt/data/brain/';
source_dir = append(source_dir,mn,'/',td,'/',num2str(en))
a=dir([source_dir '/*'])
out=size(a,1)

out=out-2;



path = append(source_dir,'/frame-')
i=5003;
pathim=append(path,num2str(i-1));
fileID = fopen(pathim,'r');
A = fread(fileID,[560,560],'uint16')';
close all;
figure()
imagesc(A);hold on
plot(d.params.pixel(:,1),d.params.pixel(:,2),'or');hold on
plot(frame(1,:),frame(2,:)','ok','LineWidth',2)
plot(frame(1,1),frame(2,1)','or','LineWidth',2)
clim([0 4000]);
colorbar
impixelinfo

d.params.pixels = frame';


%% Load or save from image data

mode = 0  % from binary image
% mode = 1 ; % from SVD 


% r = 0; % dont read file
r = 1; % read file

data = getpixel_dFoF(d,mode,d.params.pixel,r); %loads df/f for primary pixels
% data_pix = getpixels_dFoF(d);  %loads df/f for all pixels
 

dFk = data.dFk;



%% Trial Sample plot
dur = d.params.dur
t = d.timeBlue;
close all
j=3;
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
plot(Tout,mv1((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('analysis')

% figure()
% plot(t(i-35:i+35*4),dFk(i-35:i+35*4))
% xline(t(i))
% xline(t(i2))


%% Feedforard vs Feedback 
trials = 100;

data = controllerData(data,d,trials);
% data = controllerData(data,d);
% 

%% Plots for interleaved trials, 1 = save as pdf
analysisPlots(data,d,0);

%% no stim data 10 seconds before every stim
nc = data.nc;
wc = data.wc;
nostim=[];
L = 35*10;
Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
tf = (0:L-1)*T;        % Time vector
ff = Fs/L*(0:(L/2));
tns = -10:1/35:0;


nostimfft= [];
for k = 1:length(d.stimStarts)
    [a i] = min(abs(t - d.stimStarts(k)));

    nostim = [nostim;dFk(i-10*35:i)];

    X = dFk(i-10*35:i);
    Y = fft(X);

        P2 = abs(Y/L);
        P1 = P2(1:L/2+1);
        P1(2:end-1) = 2*P1(2:end-1);

        nostimfft= [nostimfft;P1];

end

%%
% close all;
% figure()
% plot(ff,nostimfft');
% 
% %
% 
% 
% 
% %
% j = 100
% X = nostim(j,:);
%     Y = fft(X);
% 
%         P2 = abs(Y/L);
%         P1 = P2(1:L/2+1);
%         P1(2:end-1) = 2*P1(2:end-1);
% 
% %%
% 
% nno_stim = reshape(nostim.',1,[]);
% nv = var(nno_stim);
% 
% maxn = max(nostim);
% minn = min(nostim);
% 
% 
% nno_stimnc = reshape(nostim(nc,:).',1,[]);
% nvnc = var(nno_stimnc);
% 
% maxnnc = max(nostim(nc,:));
% minnnc = min(nostim(nc,:));
% 
% nno_stimwc = reshape(nostim(wc,:).',1,[]);
% nvwc = var(nno_stimwc);
% 
% maxnwc = max(nostim(wc,:));
% minnwc = min(nostim(wc,:));
% 
% 
% 
% close all
% % figure()
% % plot(tns,nostim,'LineWidth',0.3,'HandleVisibility','off');hold on;
% % plot(tns,mean(nostim,1),'r','LineWidth',3);
% % plot(tns,maxn,'k','LineWidth',2,'HandleVisibility','off');
% % plot(tns,minn,'k','LineWidth',2);
% % plot(tns,sqrt(nv)*ones(1,length(tns))+mean(nostim,1),'--k','LineWidth',2);
% % plot(tns,-sqrt(nv)*ones(1,length(tns))+mean(nostim,1),'--k','LineWidth',2,'HandleVisibility','off');
% % legend('trail average','min-max','std dev')
% % title('dF/F traces spontaneous')
% 
% 
% 
% figure()
% plot(tns,nostim(nc,:),'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(tns,mean(nostim(nc,:),1),'r','LineWidth',3);
% plot(tns,maxnnc,'k','LineWidth',2,'HandleVisibility','off');
% plot(tns,minnnc,'k','LineWidth',2);
% plot(tns,sqrt(nvnc)*ones(1,length(tns))+mean(nostim(nc,:),1),'--k','LineWidth',2);
% plot(tns,-sqrt(nvnc)*ones(1,length(tns))+mean(nostim(nc,:),1),'--k','LineWidth',2,'HandleVisibility','off');
% legend('trail average','min-max','std dev')
% title('dF/F traces spontaneous before FFC')
% 
% figure()
% plot(tns,nostim(wc,:),'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(tns,mean(nostim(wc,:),1),'r','LineWidth',3);
% plot(tns,maxnwc,'k','LineWidth',2,'HandleVisibility','off');
% plot(tns,minnwc,'k','LineWidth',2);
% plot(tns,sqrt(nvwc)*ones(1,length(tns))+mean(nostim(wc,:),1),'--k','LineWidth',2);
% plot(tns,-sqrt(nvwc)*ones(1,length(tns))+mean(nostim(wc,:),1),'--k','LineWidth',2,'HandleVisibility','off');
% legend('trail average','min-max','std dev')
% title('dF/F traces spontaneous before FBC')
% % Invariance analysis
% % close all;
% inv_wc = data.wcDfk(:,35:35*(dur+1));
% inv_nc = data.ncDfk(:,35:35*(dur+1));
% 
% var_inv_wc = var(reshape(inv_wc.',1,[]));
% var_inv_nc = var(reshape(inv_nc.',1,[]));
% 
% 
% inv_wc = data.wcDfk(:,35:35*(dur+1));
% inv_nc = data.ncDfk(:,35:35*(dur+1));
% 
% inv_wcl = data.pwcDfk;
% inv_ncl = data.pncDfk;
% 
% 
% var_wc = var(inv_wc);
% var_nc = var(inv_nc);
% 
% var_wcl = var(inv_wcl);
% var_ncl = var(inv_ncl);
% 
% inv_wc_max = max(inv_wc);
% inv_wc_min = min(inv_wc);
% 
% inv_nc_max = max(inv_nc);
% inv_nc_min = min(inv_nc);
% 
% inv_nc_mean = mean(inv_nc,1);
% inv_wc_mean = mean(inv_wc,1);
% 
% NCvol = sum(inv_nc_max - inv_nc_mean - inv_nc_min)
% WCvol = sum(inv_wc_max - inv_wc_mean - inv_wc_min)
% 
% % Invariance vol reduction
% vol_red = (NCvol - WCvol)*100/NCvol
% 
% ts = 0:1/35:dur;
% 
% 
% er_nc = (5+mean(mean(inv_nc,1)))*100/5
% er_wc = (5+mean(mean(inv_wc,1)))*100/5
% 
% 
% figure()
% subplot(1,2,1)
% plot(ts,inv_nc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(ts,-5*ones(1,length(ts)),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(ts,mean(inv_nc,1),'r','LineWidth',3);hold on;
% plot(ts,inv_nc_max,'k','LineWidth',2,'HandleVisibility','off');
% plot(ts,inv_nc_min,'k','LineWidth',2);
% % plot(ts,sqrt(var_inv_nc)*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',2);
% % plot(ts,-sqrt(var_inv_nc)*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',2,'HandleVisibility','off');
% 
% plot(ts,sqrt(var_nc).*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',3,'HandleVisibility','off');
% plot(ts,-sqrt(var_nc).*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',3);
% 
% legend('trail average','min-max','deviation')
% title(append('FFC, avg error=',num2str(er_nc),'%'))
% xlabel('time','FontSize',12,'FontWeight','bold')
% ylabel('dF/F','FontSize',12,'FontWeight','bold')
% ylim([-15 15])
% a = get(gca,'XTickLabel');
% set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
% 
% subplot(1,2,2)
% plot(ts,inv_wc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(ts,-5*ones(1,length(ts)),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(ts,mean(inv_wc,1),'r','LineWidth',3);hold on;
% plot(ts,inv_wc_max,'k','LineWidth',1.5,'HandleVisibility','off');
% plot(ts,inv_wc_min,'k','LineWidth',1.5);
% 
% plot(ts,sqrt(var_wc).*ones(1,length(ts))+mean(inv_wc,1),'--k','LineWidth',3,'HandleVisibility','off');
% plot(ts,-sqrt(var_wc).*ones(1,length(ts))+mean(inv_wc,1),'--k','LineWidth',3);% plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off');
% % legend('trail average','min-max','std dev')
% title(append('FBC, avg error=',num2str(er_wc),'%'))
% ylim([-15 15])
% xlabel('time','FontSize',14,'FontWeight','bold')
% ylabel('dF/F','FontSize',14,'FontWeight','bold')
% a = get(gca,'XTickLabel');
% set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
% sgtitle('dF/F traces')
% 
% % % figure()
% % subplot(2,2,3)
% % % plot(ts,inv_nc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% % % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off'); hold on;
% % % plot(ts,mean(inv_nc,1),'--k','LineWidth',3.5);hold on;
% % plot(ts,inv_nc_max - inv_nc_mean ,'k','LineWidth',2,'HandleVisibility','off');hold on;
% % plot(ts,inv_nc_min - inv_nc_mean,'k','LineWidth',2);
% % plot(ts,sqrt(var_inv_nc)*ones(1,length(ts)),'--k','LineWidth',2);
% % plot(ts,-sqrt(var_inv_nc)*ones(1,length(ts)),'--k','LineWidth',2,'HandleVisibility','off');
% % legend('min-max','std dev','FontSize',14,'FontWeight','Bold')
% % title('dF/F envelope wrt avg')
% % ylim([-15 15]) 
% % xlabel('time','FontSize',14,'FontWeight','bold')
% % ylabel('relative dF/F ','FontSize',14,'FontWeight','bold')
% % a = get(gca,'XTickLabel');
% % set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
% % 
% % 
% % subplot(2,2,4)
% % % plot(ts,inv_wc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% % % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off'); hold on;
% % % plot(ts,mean(inv_wc,1),'--k','LineWidth',3.5);hold on;
% % plot(ts,inv_wc_max - inv_wc_mean,'k','LineWidth',2,'HandleVisibility','off'); hold on;
% % plot(ts,inv_wc_min - inv_wc_mean,'k','LineWidth',2);
% % 
% % plot(ts,sqrt(var_inv_wc)*ones(1,length(ts)),'--k','LineWidth',2);
% % plot(ts,-sqrt(var_inv_wc)*ones(1,length(ts)),'--k','LineWidth',2,'HandleVisibility','off');
% % 
% % plot(ts,sqrt(var_wc).*ones(1,length(ts)),'--g','LineWidth',2,'HandleVisibility','off');
% % plot(ts,-sqrt(var_wc).*ones(1,length(ts)),'--g','LineWidth',2,'HandleVisibility','off');
% % 
% % 
% % % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off');
% % % legend('min-max','std dev','FontSize',14,'FontWeight','Bold')
% % % title('dF/F traces FBC variance')
% % title(append('dF/F envelope size reduction ',num2str(vol_red),'%'))
% % ylim([-15 15])
% % xlabel('time','FontSize',14,'FontWeight','bold')
% % % ylabel('dF/F relative to trial-average','FontSize',18,'FontWeight','bold')
% % a = get(gca,'XTickLabel');
% % set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
% red_ratio = sum(var_wc/var_nc);
% 
% figure()
% plot(ts,var_wc,'g','LineWidth',2);hold on;
% plot(ts,var_nc,'r','LineWidth',2);
% legend('FBC','FFC')
% xlabel('time','FontSize',14,'FontWeight','bold')
% ylabel('variance','FontSize',14,'FontWeight','bold')
% title(append('variance across experiment, reduction ratio = ',num2str(red_ratio)))
% 
% 
% tsl = -5:1/35:6;
% figure()
% plot(tsl,var_wcl,'g','LineWidth',2);hold on;
% plot(tsl,var_ncl,'r','LineWidth',2);
% legend('FBC','FFC')
% xlabel('time','FontSize',14,'FontWeight','bold')
% ylabel('variance','FontSize',14,'FontWeight','bold')
% title(append('variance across experiment, reduction ratio = ',num2str(red_ratio)))
% xline(0,'LineWidth',2,'HandleVisibility','off')
% xline(3,'LineWidth',2,'HandleVisibility','off')
% xlim([-5,6])
% 
% %Inv Volumes
% 
% NCvol = sum(inv_nc_max - inv_nc_mean - inv_nc_min)
% WCvol = sum(inv_wc_max - inv_wc_mean - inv_wc_min)
% 
% % Invariance vol reduction
% vol_red = (NCvol - WCvol)*100/NCvol
% 
% %
% m = min(inv_nc_mean);
% m2 = mean(inv_nc_mean(end-35:end))
% j = 7;
% figure()
% % plot(ts,inv_nc);hold on;
% plot(ts,inv_nc_mean - m2,'r','LineWidth', 2);hold on;
% % plot(ts,m*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;
% % plot(ts,m2*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;
% plot(ts,0*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;
% 
% xlabel('time')
% ylabel('dF/F wrt mean')
% % ylim([-8 2])
% title('Step response deviation from mean')


%%

% m = markeranalysis(d,data);
%%
Fs=35;
mf = compute_bandpower_sliding(data.dFk, Fs, 2);
win_len_sec =1;
v1 = compute_past_variance(data.dFk, Fs, win_len_sec);
win_len_sec =2;
v2 = compute_past_variance(data.dFk, Fs, win_len_sec);
win_len_sec =3;
v3 = compute_past_variance(data.dFk, Fs, win_len_sec);




%% Variability analysis

% Classify x0
X0=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));
    X0 = [X0; dFk(i)];
end

XX0=[];
for j = 1: length(nc)
    [a i] = min(abs(t - d.stimStarts(nc(j))));
    XX0 = [XX0; dFk(i)];
end


x0=[];
for j = 1: length(d.stimStarts)
    [a i] = min(abs(t - d.stimStarts(j)));
    x0 = [x0; dFk(i)];
end



%% Analysis based on H2 
close all;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;


pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;
% a1 = find(er_wcDfk > 20);
% a2 = find(er_wcDfk < 20);

er = sort(er_wcDfk)
ner = sort(er_ncDfk)
%%
mv1 = d.motion.motSVD_0(1:2:end,1);
%% Analyzer
tt = d.inpTime;
v = d.inpVals;
[m1,i1] = max(er_wcDfk);
[m2,i2] = min(er_wcDfk);

i=5;
a1 = find(er_wcDfk==(er(i)));
a2 = find(er_wcDfk==(er(length(er_wcDfk)-i)));



% m1=a1(i);

m1=a1;
j1 = wc(m1);

m2=a2;
 
% m2=a2(i);
j2 = wc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));

[a k2] = min(abs(t - d.stimStarts(j2)));
k1
k2

%
ref = [-5*ones(1,3*35+1)];
Tref  = 0:0.0285:dur;


Tp = -5:0.0285:dur+3;

Tp2 = -5:0.0285:dur+1;
close all
figure()
subplot(3,2,1)
plot(Tp,pwcDfk(a1,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
ylim([-15,15])
xlim([-5,4])
title('regularized signal')

subplot(3,2,3)
plot(Tp2,mf((k1-35*5):(k1+35*(dur+1)),1),'LineWidth',2);hold on
plot(Tp2,mf((k1-35*5):(k1+35*(dur+1)),2),'LineWidth',2);hold on
plot(Tp2,mf((k1-35*5):(k1+35*(dur+1)),3),'LineWidth',2);hold on
plot(Tp2,v1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v2((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,1e-6*mv1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.fft2((k1-35*5):(k1+35*(dur+1))));hold on
% plot(Tp,m.fft3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp2,m.fft4((k1-35*5):(k1+35*(dur+1))));hold on
% plot(Tp2,m.Rv1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv2((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
legend('0-3Hz','3-6Hz','3-6Hz','var 1s','var 2s','var 3s','motion')
ylabel('dF/F')
% legend('0-6Hz','var 2s')
title('paramerter approximation')


subplot(3,2,2)
plot(Tp,pwcDfk(a2,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
% yline(-5)
ylim([-15,15])
xlim([-5,4])
ylabel('dF/F')
title('unregularized signal')

subplot(3,2,4)
plot(Tp2,mf((k2-35*5):(k2+35*(dur+1)),1),'LineWidth',2);hold on
plot(Tp2,mf((k2-35*5):(k2+35*(dur+1)),2),'LineWidth',2);hold on
plot(Tp2,mf((k2-35*5):(k2+35*(dur+1)),3),'LineWidth',2);hold on
plot(Tp2,v1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v2((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v3((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,1e-6*mv1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
% legend('0-6Hz','var 2s')
title('paramerter approximation')

[a k11] = min(abs(tt - d.stimStarts(j1)));
[a k12] = min(abs(tt - d.stimEnds(j1)));

subplot(3,2,5)
plot(tt(k11:k12)-tt(k11),v(k11:k12))
xlim([-5,4])
ylim([0,5])
ylabel('input')
xlabel('time')

[a k21] = min(abs(tt - d.stimStarts(j2)));
[a k22] = min(abs(tt - d.stimEnds(j2)));

subplot(3,2,6)
plot(tt(k21:k22)-tt(k21),v(k21:k22))
xlim([-5,4])
ylim([0,5])
ylabel('input')
xlabel('time')
sgtitle('FBC')

ner = sort(er_ncDfk)
% [m1,i1] = max(er_wcDfk);
% [m2,i2] = min(er_wcDfk);


a1 = find(er_ncDfk==(ner(i)));
a2 = find(er_ncDfk==(ner(length(er_ncDfk)-i)));



% m1=a1(i);

m1=a1;
j1 = nc(m1);

m2=a2;

% m2=a2(i);
j2 = nc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));

[a k2] = min(abs(t - d.stimStarts(j2)));
k1
k2

%
ref = [-5*ones(1,3*35+1)];
Tref  = 0:0.0285:dur;


Tp = -5:0.0285:dur+3;

Tp2 = -5:0.0285:dur+1;

figure()
subplot(3,2,1)
plot(Tp,pncDfk(a1,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
ylim([-15,15])
xlim([-5,4])
title('regularized signal')

subplot(3,2,3)
plot(Tp2,mf((k1-35*5):(k1+35*(dur+1)),1),'LineWidth',2);hold on
plot(Tp2,mf((k1-35*5):(k1+35*(dur+1)),2),'LineWidth',2);hold on
plot(Tp2,mf((k1-35*5):(k1+35*(dur+1)),3),'LineWidth',2);hold on
plot(Tp2,v1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v2((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,1e-6*mv1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
legend('0-3Hz','6Hz+','var 1s')
ylabel('dF/F')
% legend('0-6Hz','var 2s')
title('paramerter approximation')


subplot(3,2,2)
plot(Tp,pncDfk(a2,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
% yline(-5)
ylim([-15,15])
xlim([-5,4])
ylabel('dF/F')
title('unregularized signal')

subplot(3,2,4)
plot(Tp2,mf((k2-35*5):(k2+35*(dur+1)),1),'LineWidth',2);hold on
plot(Tp2,mf((k2-35*5):(k2+35*(dur+1)),2),'LineWidth',2);hold on
plot(Tp2,mf((k2-35*5):(k2+35*(dur+1)),3),'LineWidth',2);hold on
plot(Tp2,v1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v2((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,v3((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,1e-6*mv1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
% legend('0-6Hz','var 2s')
title('paramerter approximation')

[a k11] = min(abs(tt - d.stimStarts(j1)));
[a k12] = min(abs(tt - d.stimEnds(j1)));

subplot(3,2,5)
plot(tt(k11:k12)-tt(k11),v(k11:k12),'LineWidth',3)
xlim([-5,4])
ylim([0,5])
ylabel('input')
xlabel('time')

[a k21] = min(abs(tt - d.stimStarts(j2)));
[a k22] = min(abs(tt - d.stimEnds(j2)));

subplot(3,2,6)
plot(tt(k21:k22)-tt(k21),v(k21:k22),'LineWidth',3)
xlim([-5,4])
ylim([0,5])
ylabel('input')

xlabel('time')

sgtitle('FFC')

%% Sort error vs low power 
wc_pval1=[];
nc_pval1=[];

wc_pval2=[];
nc_pval2=[];

wc_pval3=[];
nc_pval3=[];

wc_pval4=[];
nc_pval4=[];

v_val_fb = [];
f_val_fb = [];

v_val_ff = [];
f_val_ff = [];

v1_fb=[];
v2_fb=[];
v3_fb=[];
f1_fb=[];
f2_fb=[];
f3_fb=[];

v1_ff=[];
v2_ff=[];
v3_ff=[];
f1_ff=[];
f2_ff=[];
f3_ff=[];


    pre_v_fb = [];
    pre_f_fb = [];

    post_v_fb = [];
    post_f_fb = [];


    pre_v_ff = [];
    pre_f_ff = [];

    post_v_ff = [];
    post_f_ff = [];

for i=1:length(data.wc)
    j =wc(i);
    [a k] = min(abs(t - d.stimStarts(j)));


    v1_fb = [v1_fb; v1(k)];
    v2_fb = [v2_fb; v2(k)];
    v3_fb = [v3_fb; v3(k)];

    f1_fb = [f1_fb; mf(k,1)];
    f2_fb = [f2_fb; mf(k,2)];
    f3_fb = [f3_fb; mf(k,3)];


    pre_v_fb = [pre_v_fb; sum(v1(k-35*2:k)),sum(v2(k-35*2:k)),sum(v3(k-35*2:k))];
    pre_f_fb = [pre_f_fb; sum(mf(k-35*2:k,1)),sum(mf(k-35*2:k,2)),sum(mf(k-35*2:k,3))];

    post_v_fb = [post_v_fb; sum(v1(k:k+35*3)),sum(v2(k:k+35*3)),sum(v3(k:k+35*3))];
    post_f_fb = [post_f_fb; sum(mf(k:k+35*3,1)),sum(mf(k:k+35*3,2)),sum(mf(k:k+35*3,3))];


end

for i=1:length(data.nc)
    j =nc(i);
    [a k] = min(abs(t - d.stimStarts(j)));


    v1_ff = [v1_ff; v1(k)];
    v2_ff = [v2_ff; v2(k)];
    v3_ff = [v3_ff; v3(k)];

    f1_ff = [f1_ff; mf(k,1)];
    f2_ff = [f2_ff; mf(k,2)];
    f3_ff = [f3_ff; mf(k,3)];



    pre_v_ff = [pre_v_ff; sum(v1(k-35*2:k)),sum(v2(k-35*2:k)),sum(v3(k-35*2:k))];
    pre_f_ff = [pre_f_ff; sum(mf(k-35*2:k,1)),sum(mf(k-35*2:k,2)),sum(mf(k-35*2:k,3))];

    post_v_ff = [post_v_ff; sum(v1(k:k+35*3)),sum(v2(k:k+35*3)),sum(v3(k:k+35*3))];
    post_f_ff = [post_f_ff; sum(mf(k:k+35*3,1)),sum(mf(k:k+35*3,2)),sum(mf(k:k+35*3,3))];

end



%% Thresholding

figure()
subplot(1,3,1)
s = scatter3(X0,f1_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,f1_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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

subplot(1,3,2)
s = scatter3(X0,f2_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,f2_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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


subplot(1,3,3)
s = scatter3(X0,f3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,f3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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


figure()
subplot(1,3,1)
s = scatter3(X0,v1_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,v1_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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

subplot(1,3,2)
s = scatter3(X0,v2_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,v2_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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


subplot(1,3,3)
s = scatter3(X0,v3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,v3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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
 


%%


figure()
subplot(1,3,1)
s = scatter3(X0,pre_f_fb(:,1),er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,pre_f_ff(:,1),er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('f1')


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

subplot(1,3,2)
s = scatter3(X0,pre_f_fb(:,2),er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,pre_f_ff(:,2),er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('f2')


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


subplot(1,3,3)
s = scatter3(X0,pre_f_fb(:,3),er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,pre_f_ff(:,3),er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('f3')


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
%%

figure()
subplot(1,3,1)
s = scatter3(X0,v1_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,v1_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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

subplot(1,3,2)
s = scatter3(X0,v2_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,v2_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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


subplot(1,3,3)
s = scatter3(X0,v3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,v3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


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
%%
% 
% 
% sigName = 'lightCommand';
% [tt, v] = getTLanalog(mn, td, en, sigName);
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
% 
% movieWithTracesSVD(U, V, t, traces, [], []);
% %%
% dFk_pix = [data.dFk;data_pix.dFk];
% erw = sort(er_wcDfk)
% 
% i=15;
% 
% a1 = find(er_wcDfk==(erw(i)));
% a2 = find(er_wcDfk==(erw(length(er_wcDfk)-i)));
% 
% 
% m1=a1;
% j1 = wc(m1);
% 
% m2=a2;
% j2 = wc(m2);
% 
% [a k1] = min(abs(t - d.stimStarts(j1)));
% [a k2] = min(abs(t - d.stimStarts(j2)));
% 
% k1
% k2
% 
% [a k11] = min(abs(tt - stimStarts(j1)));
% [a k12] = min(abs(tt - stimEnds(j1)));
% 
% figure()
% plot(tt(k11:k12)-tt(k11),v(k11:k12),'LineWidth',3)
% xlim([-5,4])
% ylim([0,5])
% ylabel('input')
% xlabel('time')
% 
% 
% close all
% 
% figure()
% subplot(2,2,1)
% plot(t1,dFk(k1:k1+35*(dur)),'LineWidth',2);hold on;
% plot(Tref,ref,'--k','LineWidth',2);hold on
% ylim([-10,10])
% title('regularized signal')
% 
% subplot(2,2,3)
% plot(t1,dFk_pix(:,k1:k1+35*(dur)'),'LineWidth',2);hold on;
% plot(Tref,ref,'--k','LineWidth',2);hold on
% ylim([-10,10])
% title('regularized signal')
% 
% 
% 
% subplot(2,2,2)
% plot(t1,dFk(k2:k2+35*(dur)),'LineWidth',2);hold on;
% ylim([-10,10])
% title('unregularized signal')
% 
% subplot(2,2,4)
% plot(t1,dFk_pix(:,k2:k2+35*(dur)'),'LineWidth',2);hold on;
% ylim([-10,10])
% title('unregularized signal')
% 
% sgtitle('FBC')
% 
% 
% 
% 
% 
% 
% 
% 
% ern = sort(er_ncDfk)
% 
% a1 = find(er_ncDfk==(ern(i)));
% a2 = find(er_ncDfk==(ern(length(er_ncDfk)-i)));
% 
% 
% m1=a1;
% j1 = wc(m1);
% 
% m2=a2;
% j2 = wc(m2);
% 
% [a k1] = min(abs(t - d.stimStarts(j1)));
% [a k2] = min(abs(t - d.stimStarts(j2)));
% 
% k1
% k2
% 
% [a k11] = min(abs(tt - stimStarts(j1)));
% [a k12] = min(abs(tt - stimEnds(j1)));
% 
% % figure()
% % plot(tt(k11:k12)-tt(k11),v(k11:k12),'LineWidth',3)
% % xlim([-5,4])
% % ylim([0,5])
% % ylabel('input')
% % xlabel('time')
% 
% 
% 
% figure()
% subplot(2,2,1)
% plot(t1,dFk(k1:k1+35*(dur)),'LineWidth',2);hold on;
% plot(Tref,ref,'--k','LineWidth',2);hold on
% ylim([-10,10])
% title('regularized signal')
% 
% subplot(2,2,3)
% plot(t1,dFk_pix(:,k1:k1+35*(dur)'),'LineWidth',2);hold on;
% plot(Tref,ref,'--k','LineWidth',2);hold on
% ylim([-10,10])
% title('regularized signal')
% 
% 
% 
% subplot(2,2,2)
% plot(t1,dFk(k2:k2+35*(dur)),'LineWidth',2);hold on;
% ylim([-10,10])
% title('unregularized signal')
% 
% subplot(2,2,4)
% plot(t1,dFk_pix(:,k2:k2+35*(dur)'),'LineWidth',2);hold on;
% ylim([-10,10])
% title('unregularized signal')
% sgtitle('FFC')
% 
% 
% %%
% t2 = -3:0.0285:3;
% figure()
% subplot(2,2,1)
% plot(t2,dFk(k1-35*(dur):k1+35*(dur)),'LineWidth',2);hold on;
% plot(Tref,ref,'--k','LineWidth',2);hold on
% ylim([-10,10])
% title('regularized signal')
% 
% subplot(2,2,3)
% plot(t2,dFk_pix(:,k1-35*(dur):k1+35*(dur)),'LineWidth',2);hold on;
% plot(Tref,ref,'--k','LineWidth',2);hold on
% ylim([-10,10])
% title('regularized signal')
% 
% 
% 
% subplot(2,2,2)
% plot(t2,dFk(k2-35*(dur):k2+35*(dur)),'LineWidth',2);hold on;
% ylim([-10,10])
% title('unregularized signal')
% 
% subplot(2,2,4)
% plot(t2,dFk_pix(:,k2-35*(dur):k2+35*(dur)),'LineWidth',2);hold on;
% ylim([-10,10])
% title('unregularized signal')
% 
% sgtitle('FBC')
% 
% 
% 
% 
% %% Trial averaged pixels:
% 
% for k = 1:length(d.params.pixels)
% ncDfkp=[];
% wcDfkp=[];
% ncer = [];
% wcer = [];
% 
% for j = 1: length(nc)
% 
%     [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));
%     ncDfkp = [ncDfkp; dFk_pix(k,i-35*5:i+35*(d.params.dur+5))];
% 
%     ncer = [ncer; dFk_pix(k,i:i+35*(d.params.dur))];
% 
% 
% end
% ncDfk_pix(:,:,k) = ncDfkp;
% nc_trial(:,:,k) = ncer;
% 
% 
% 
% for j = 1: length(wc)
%     [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));
%     wcDfkp = [wcDfkp; dFk_pix(k,i-35*5:i+35*(d.params.dur+5))];
% 
%     wcer = [wcer; dFk_pix(k,i:i+35*(d.params.dur))];
% 
% end
% 
% 
% wcDfk_pix(:,:,k) = wcDfkp;
% wc_trial(:,:,k) = ncer;
% end
% 
% 
% %% pixel mean
% wc_mean=[];
% wc_trial_dev = wc_trial;
% 
% for k = 1:length(d.params.pixels)
%     kk = mean(wc_trial(:,:,k),1)
%     wc_mean = [wc_mean;kk];
% 
%     wc_trial_dev(:,:,k) = wc_trial(:,:,k) - kk;
% 
% 
% 
% 
% end
% 
% 
% 
% 
% %%
% 
% figure()
% 
% for i = 1:3
% % i=40;
% 
% a1 = find(er_wcDfk==(erw(i)));
% a2 = find(er_wcDfk==(erw(length(er_wcDfk)-i)));
% m1=a1;
% j1 = wc(m1);
% 
% m2=a2;
% j2 = wc(m2);
% 
% 
% 
% p1 = a1
% p2 = a2
% 
% 
% 
% % aa = squeeze(wcDfk_pix(p,:,:));
% % figure()
% % plot(aa);
% % xline(35*5)
% % xline(35*(5+3))
% % title('per trial pixel')
% % 
% % figure()
% % plot(wc_mean')
% % title('pixels trial averaged')
% % 
% % aa = squeeze(wc_trial_dev(p,:,:));
% % figure()
% % plot(aa);
% % title('per trial pixel dev')
% 
% 
% 
% 
% subplot(3,2,1+i-1)
% 
% aa = squeeze(wcDfk_pix(p1,:,:));
% 
% plot(aa);
% xline(35*5)
% xline(35*(5+3))
% title('per trial pixel')
% 
% subplot(3,2,2+i-1)
% 
% aa = squeeze(wc_trial_dev(p1,:,:));
% plot(aa);
% title('per trial pixel dev')
% 
% end
% 
% %%
% 
% %%
% close all
% 
% figure()
% i=40;
% 
% a1 = find(er_wcDfk==(erw(i)));
% a2 = find(er_wcDfk==(erw(length(er_wcDfk)-i)));
% m1=a1;
% j1 = wc(m1);
% 
% m2=a2;
% j2 = wc(m2);
% 
% 
% 
% p1 = a1
% p2 = a2
% 
% 
% 
% aa = squeeze(wcDfk_pix(p1,:,:));
% figure()
% plot(aa);
% xline(35*5)
% xline(35*(5+3))
% title('per trial pixel')
% 
% figure()
% plot(wc_mean')
% title('pixels trial averaged')
% 
% aa = squeeze(wc_trial_dev(p1,:,:));
% figure()
% plot(aa);
% title('per trial pixel dev')
% 
% 
% 
% 
% 
% %%
% 
% [a k1] = min(abs(t - 419));
% 
% 
% figure()
% plot(dFk_pix(2,k1:k1+200)');
% plot(dFk2(2,k1:k1+200)');
% 
% %%
%     F1 = [];
% pixel = d.params.pixel;              
%     k=d.params.kernel;
%     display('computing pixel val')
% 
%         source_dir ='/mnt/data/brain/';
%         source_dir = append(source_dir,d.mn,'/',d.td,'/',num2str(d.en));
%         a=dir([source_dir '/*']);
%         out=size(a,1);
% 
%         out=out-2;
%         path = append(source_dir,'/frame-');
% 
%         for i=1:2:out
%             pathim=append(path,num2str(i-1));
%             fileID = fopen(pathim,'r');
%             A = fread(fileID,[560,560],'uint16')';
%             % j=length(pixel);
%             j=1;
%             G = mean(A(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k),'all');
% 
%             F1 = [F1,G];
% 
%             fclose(fileID);
% 
%         end
%     %%
%         nSV = 500;
% 
%         [U1, V1, t1, mimg1] = loadUVt(serverRoot, nSV);
% 
% 
% 
%         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         expRoot = serverRoot;
% t = [];
% movieSuffix = 'blue';
% 
% U2 = readUfromNPY(fullfile(expRoot, movieSuffix, ['svdSpatialComponents.npy']), nSV);
% mimg2 = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));
% 
% 
%     fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
%     V2 = readVfromNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.npy']), nSV);
%     t2 = readNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.timestamps.npy']));
%  %%
%     Fs2 = 1/mean(diff(t1));
% 
%     V2 = detrendAndFilt(V2, Fs2);
%         %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
%         %%
% F2=[];
% F3 = [];
% 
%         mimg = mimg1';
%         j=1;
%         mI = [];
%         for i = 1:length(V1)
%             mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
%             mI = [mI,mean(mimg_kernel,'all')];
%             imkernel = U1(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
%             % size(imkernel)
%             imstack = mean(imkernel,[1,2]);
%             % size(imstack)   
%             F2 = [F2,reshape(imstack,[1,nSV])*V1(:,i)];
% 
% 
%             imkernel = U2(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
%             % size(imkernel)
%             imstack = mean(imkernel,[1,2]);
%             % size(imstack)   
%             F3 = [F3,reshape(imstack,[1,nSV])*V2(:,i)];
%         end
% 
% %%
% 
% figure()            
% plot(d.timeBlue,F1);hold on;
% plot(d.timeBlue,F2+mI(1));hold on;
% plot(d.timeBlue,F3+mI(2));hold on;
% legend('raw','corr svd','ucorr svd')

%%

% nSV = 2000;
% 
% [U1, V1, t1, mimg1] = loadUVt(serverRoot, nSV);
% %%
% Im=zeros(560*560,1);
% i = 1;
% for j = 1:500
%     Im = Im + reshape(U(:,:,j),560*560,1)*V(j,i);
% end
% Im = reshape(Im,560,560)+ mimg;
% 
% %%
% figure()
% image(Im)
% 
% %% SVD 
% 
% expRoot = serverRoot;
% movieSuffix = 'blue';
% nSV = 2000;
% U = readUfromNPY(fullfile(expRoot, movieSuffix, ['svdSpatialComponents.npy']), nSV);
% mimg = readNPY(fullfile(expRoot, movieSuffix, ['meanImage.npy']));
% 
% %
%     fprintf(1, 'corrected file not found; loading uncorrected temporal components\n');
%     V = readVfromNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.npy']), nSV);
%     t = readNPY(fullfile(expRoot, movieSuffix, ['svdTemporalComponents.timestamps.npy']));
% 
% 
% 
% 
% %%
% Im=zeros(560*560,1);
% i = 50000;
% for j = 1:500
%     Im = Im + reshape(U(:,:,j),560*560,1)*V(j,i);
% end
% Im = reshape(Im,560,560)+ mimg;
% 
% 
% 
% source_dir ='/mnt/data/brain/';
% source_dir = append(source_dir,mn,'/',td,'/',num2str(en))
% a=dir([source_dir '/*'])
% out=size(a,1)
% 
% out=out-2;
% 
% % pixel=[163,300]
% i = 2*i+1;
% path = append(source_dir,'/frame-')
% 
% pathim=append(path,num2str(i-1));
% fileID = fopen(pathim,'r');
% A = fread(fileID,[560,560],'uint16')';
% % close all;
% figure()
% imagesc(A);hold on
% plot(d.params.pixel(:,1),d.params.pixel(:,2),'or');hold on
% plot(frame(1,:),frame(2,:)','ok','LineWidth',2)
% clim([0 4000]);
% colorbar
% impixelinfo
% 
% %
% 
% figure()
% image(Im - A)
% colorbar
% aa = Im - A;



%%

datapix = getpixels_dFoF(d);

%%

win_len_sec=3;
dFkp = datapix.dFk.dFk;
close all
%%
figure()
plot(d.timeBlue,dFkp);hold on;
plot(d.timeBlue,dFkp(1,:),'Linewidth',3);hold on;

%% Variance based segregation
x1 = dFk;
x2 = dFk;  % Phase-shifted

frechet = frechet_distance_sliding(x1, x2, Fs, win_len_sec);


%% Get band power across pixels at stim start ::
tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);
win_len_sec = 3;
bands = compute_bandpower_at_times(dFkp,d.timeBlue, Fs, win_len_sec, tfb, tff);


%
bpfb = bands.BandPower_Vec1;  % [n × length(tvec1) × 3]
[n, k, ~] = size(bpfb);
close all;
figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};

for b = 1:3
    subplot(3,1,b);
    hold on;
    
    for i = 1:n
        plot(er_wcDfk, squeeze(bpfb(i,:,b)),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, squeeze(bpfb(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region pre Stim (FB)');


bpfF = bands.BandPower_Vec2;  % [n × length(tvec1) × 3]

figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};
for b = 1:3
    subplot(3,1,b);
    hold on;

    for i = 1:n
        plot(er_ncDfk, squeeze(bpfF(i,:,b)),'o' ,'LineWidth', 1);
    end
        plot(er_ncDfk, squeeze(bpfF(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region pre Stim (FF)');


%% Get band power across pixels during stim ::
tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);
win_len_sec = 3;
bands = compute_bandpower_at_times(dFkp,d.timeBlue, Fs, win_len_sec, tfb, tff);


%
bpfb = bands.BandPower_Vec1;  % [n × length(tvec1) × 3]
[n, k, ~] = size(bpfb);
close all;
figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};

for b = 1:3
    subplot(3,1,b);
    hold on;
    
    for i = 1:n
        plot(er_wcDfk, squeeze(bpfb(i,:,b)),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, squeeze(bpfb(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region during Stim (FB)');


bpfF = bands.BandPower_Vec2;  % [n × length(tvec1) × 3]

figure;
band_labels = {'1–3 Hz', '3–6 Hz', '6+ Hz'};
for b = 1:3
    subplot(3,1,b);
    hold on;

    for i = 1:n
        plot(er_ncDfk, squeeze(bpfF(i,:,b)),'o' ,'LineWidth', 1);
    end
        plot(er_ncDfk, squeeze(bpfF(1,:,b)),'ko' ,'LineWidth', 3);
    title(['Band ', num2str(b), ' (', band_labels{b}, ')']);
    xlabel('tracking MSE');
    ylabel('Band Power');
    grid on;
end
sgtitle('Band Power per region during Stim (FF)');

%% Frechet distance before stim ::
dfk_temp = repmat(dFk, 15, 1);  % n x t
win_len_sec = 3;
Fs=35;
tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);

frechet_dists_fb = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tfb);
frechet_dists_ff = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tff);


%%
n=15;
close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, frechet_dists_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, frechet_dists_fb(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FB(prestim)');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, frechet_dists_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, frechet_dists_ff(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FF(prestim)');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
%% Frechet distance during stim ::
dfk_temp = repmat(dFk, 15, 1);  % n x t
win_len_sec = 3;
Fs=35;
tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);

frechet_dists_fb = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tfb);
frechet_dists_ff = compute_frechet_distance_at_times(dfk_temp, dFkp, d.timeBlue, Fs, win_len_sec, tff);


%
n=15;
close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, frechet_dists_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, frechet_dists_fb(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FB');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, frechet_dists_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, frechet_dists_ff(1,:),'ko' ,'LineWidth', 3);
    title('Frechet dist FF');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
%% Variance Pre stim
win_len_sec=3;

tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);

var_fb = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tfb);  % [n × length(tvec)]
var_ff = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tff);  % [n × length(tvec)]
%

n=15;
close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, var_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, var_fb(1,:),'ko' ,'LineWidth', 3);
    title('var FB prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, var_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, var_ff(1,:),'ko' ,'LineWidth', 3);
    title('var FF prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
% Variance during Stim

    win_len_sec=3;

tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);

var_fb = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tfb);  % [n × length(tvec)]
var_ff = compute_variance_at_times(dFkp, d.timeBlue, Fs, win_len_sec, tff);  % [n × length(tvec)]


n=15;
% close all;
figure()

    hold on;

    for i = 1:n
        plot(er_wcDfk, var_fb(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_wcDfk, var_fb(1,:),'ko' ,'LineWidth', 3);
    title('var FB during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n
        plot(er_ncDfk, var_ff(i,:),'o' ,'LineWidth', 1);
    end
    plot(er_ncDfk, var_ff(1,:),'ko' ,'LineWidth', 3);
    title('var FF during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;
%% Sample without computing full data::::



%% Correlation Coeficiant


win_len_sec=3;

tfb = d.stimStarts(wc);
tff = d.stimStarts(nc);



c_fb = (compute_corr_relative(dFkp, d.timeBlue, tfb, win_len_sec));  % [n × length(tvec)]
c_ff = (compute_corr_relative(dFkp, d.timeBlue, tff, win_len_sec));  % [n × length(tvec)]
%


n=15;
close all;
figure()

    hold on;

    for i = 1:n-1
        plot(er_wcDfk, c_fb(:,i),'o' ,'LineWidth', 1);
    end
    title('var FB prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n-1
        plot(er_ncDfk, c_ff(:,i),'o' ,'LineWidth', 1);
    end
    title('var FF prestim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;



win_len_sec=3;

tfb = d.stimEnds(wc);
tff = d.stimEnds(nc);



c_fb = compute_corr_relative(dFkp, d.timeBlue, tfb, win_len_sec);  % [n × length(tvec)]
c_ff = compute_corr_relative(dFkp, d.timeBlue, tff, win_len_sec);  % [n × length(tvec)]
%


n=15;
% close all;
figure()

    hold on;

    for i = 1:n-1
        plot(er_wcDfk, c_fb(:,i),'o' ,'LineWidth', 1);
    end
    title('var FB during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;


    n=15;
figure()

    hold on;

    for i = 1:n-1
        plot(er_ncDfk, c_ff(:,i),'o' ,'LineWidth', 1);
    end
    title('var FF during stim');
    xlabel('tracking MSE');
    ylabel('f');
    grid on;

%%


%%

close all
plot(mv1/1e4);hold on
plot(dFk);hold on

%%

ncmotion_pre = sum(data.ncmotion(:,1:35*1),2);
wcmotion_pre = sum(data.wcmotion(:,1:35*1),2);


ncmotion_during = sum(data.ncmotion(:,35:(dur+1)*35),2);
wcmotion_during = sum(data.wcmotion(:,35:(dur+1)*35),2);



%%
% Fs=35;
% mf = compute_bandpower_sliding(data.dFk, Fs, 2);
% win_len_sec =1;
% v1 = compute_past_variance(data.dFk, Fs, win_len_sec);
% win_len_sec =2;
% v2 = compute_past_variance(data.dFk, Fs, win_len_sec);
% win_len_sec =3;
% v3 = compute_past_variance(data.dFk, Fs, win_len_sec);
%% Thresholding
close all
figure()
subplot(1,2,1)
s = scatter3(X0,wcmotion_pre,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,ncmotion_pre,er_ncDfk,[],er_ncDfk,'filled','r');
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
s = scatter3(X0,wcmotion_during,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,ncmotion_during,er_ncDfk,[],er_ncDfk,'filled','r');
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
title('analysis')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)

subplot(3,1,3)
plot(Tout,mv1((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('analysis')
%% 


tt = d.inpTime;
v = d.inpVals;
[m1,i1] = max(er_wcDfk);
[m2,i2] = min(er_wcDfk);

i=10;
a1 = find(er_wcDfk==(er(i)));
a2 = find(er_wcDfk==(er(length(er_wcDfk)-i)));



% m1=a1(i);

m1=a1;
j1 = wc(m1);

m2=a2;
 
% m2=a2(i);
j2 = wc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));

[a k2] = min(abs(t - d.stimStarts(j2)));
k1
k2

%
ref = [-5*ones(1,3*35+1)];
Tref  = 0:0.0285:dur;


Tp = -5:0.0285:dur+3;

Tp2 = -5:0.0285:dur+1;



[a k11] = min(abs(tt - d.stimStarts(j1)));
[a k12] = min(abs(tt - d.stimEnds(j1)));


[a k21] = min(abs(tt - d.stimStarts(j2)));
[a k22] = min(abs(tt - d.stimEnds(j2)));



close all
figure()
subplot(1,2,1)
plot(Tp,pwcDfk(a1,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
plot(tt(k11:k12)-tt(k11),2*v(k11:k12),'LineWidth',2)
xline(0)
xline(3)
yline(0)
ylim([-15,15])
xlim([-2,4])
ylabel('dF/F')
xlabel('sec')
title('regularized signal')



subplot(1,2,2)
plot(Tp,pwcDfk(a2,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
plot(tt(k21:k22)-tt(k21),2*v(k21:k22),'LineWidth',2)
xline(0)
xline(3)
yline(0)
% yline(-5)
ylim([-15,15])
xlim([-2,4])
xlabel('sec')
title('unregularized signal')
sgtitle('closed loop')

ner = sort(er_ncDfk)
% [m1,i1] = max(er_wcDfk);
% [m2,i2] = min(er_wcDfk);


a1 = find(er_ncDfk==(ner(i)));
a2 = find(er_ncDfk==(ner(length(er_ncDfk)-i)));



% m1=a1(i);

m1=a1;
j1 = nc(m1);

m2=a2;

% m2=a2(i);
j2 = nc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));

[a k2] = min(abs(t - d.stimStarts(j2)));
k1
k2

%
ref = [-5*ones(1,3*35+1)];
Tref  = 0:0.0285:dur;


Tp = -5:0.0285:dur+3;

Tp2 = -5:0.0285:dur+1;


[a k11] = min(abs(tt - d.stimStarts(j1)));
[a k12] = min(abs(tt - d.stimEnds(j1)));


[a k21] = min(abs(tt - d.stimStarts(j2)));
[a k22] = min(abs(tt - d.stimEnds(j2)));



figure()
subplot(1,2,1)
plot(Tp,pncDfk(a1,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
plot(tt(k11:k12)-tt(k11),2*v(k11:k12),'LineWidth',3)

xline(0)
xline(3)
yline(0)
ylim([-15,15])
xlim([-2,4])
ylabel('dF/F');
xlabel('time(sec)');
title('regularized signal')



subplot(1,2,2)
plot(Tp,pncDfk(a2,:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
plot(tt(k21:k22)-tt(k21),2*v(k21:k22),'LineWidth',3)

xline(0)
xline(3)
yline(0)
% yline(-5)
ylim([-15,15])
xlim([-2,4])
xlabel('time(sec)');
title('unregularized signal')
sgtitle('open loop')


