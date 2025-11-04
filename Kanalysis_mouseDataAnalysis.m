%% Data analysis Script
% add var and fft to a function


clc;
close all;
clear all;
githubDir = "C:\Users\adity\Documents\brain_paper\utils"


% Script to analyze widefield/behavioral data from 
addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab
addpath('utils')



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
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;

% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 1;
% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-04-19'; 
% en = 1;
% 
mn = 'AL_0039'; td = '2025-04-19'; 
en = 1;
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

%% Stim Times

% mode = 0 % from stim search
mode = 1; % from param data

d = findStims(d,mode);
%%
df = diff(d.stimStarts);

% d = findStims_debug(d,mode);


% % Alternate( if input params follows old data format)
% stimTimes = d.inpTime(d.inpVals(2:end)>0.1 & d.inpVals(1:end-1)<=0.1);
% ds = find(diff([0;stimTimes])>2);
% d.stimStarts = stimTimes(ds);
% d.stimEnds = stimTimes(ds(2:end)-1);
% 
% % Amps
% amps=[];
% for i = 1:length(d.stimStarts)-1
%     amps = [amps,max(d.inpVals(find(d.inpTime == d.stimStarts(i)):find(d.inpTime == d.stimEnds(i))))];
% end

% wd.stimDur = d.stimEnds-d.stimStarts(1:end-1);

%%
%380,320
pix = [d.params.pixel(1);d.params.pixel(1)]
% offsetx = 40;
% offsety = -75;

offsetx = 50;
offsety = -40;
% 
px = [200,300,150,200,300,350,100,200,300,400,100,200,300,400]+offsetx;
py = [150,150,225,225,225,225,325,325,325,325,425,425,425,425]+offsety;
% px=[];
% py=[];

frame = double([d.params.pixel(1),px;d.params.pixel(2),py]); 



source_dir ='/mnt/data/brain/';
source_dir = append(source_dir,mn,'/',td,'/',num2str(en))
a=dir([source_dir '/*'])
out=size(a,1)

out=out-2;

% pixel=[163,300]

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
clim([0 4000]);
colorbar
impixelinfo

% d.params.pixel = frame';


%% Load or save from image data
mode = 0  % from binary image
% mode = 1 ; % from SVD

% r = 0; % dont read file
r = 1; % read file

data = getpixel_dFoF(d,mode,d.params.pixel,r);


% data_pix = getpixel_dFoF_pix(d,mode,pixel2);
% 

dFk = data.dFk;

%%
% 
% F = data.F;
% w=d.params.horizon-1;
%     Fk  = [ones(1,w),F];
%     dF=[];
%     Fmean=[];
%     dFk=[];
%     Fkmean=[];
% 
%     for i = 1:length(F)
%         % Add an LPF filter 
%         if mode == 0
% 
%         Fkmean = [Fkmean,mean(Fk(i:i+w))];
%         dFk = [dFk,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];
%         else
%         dFk = [dFk,(F(i))/mI(i)*100];
%         end
% 
%     end
% data.dFk = dFk;
% data = getpixels_dFoF(d);
%%
% d.stimStarts = d.stimStarts+0.14;
% d.stimEnds = d.stimEnds + 0.14;
%
%% if dfK was not already computed for the dataset
% load('pixel12207.mat')
% 
% w=d.params.horizon-1;
% Fk  = [ones(1,w),F];
% dF=[];
% Fmean=[];
% dFk=[];
% Fkmean=[];
% 
% for i = 1:length(F)
%     % Add an LPF filter 
% 
% 
%     Fkmean = [Fkmean,mean(Fk(i:i+w))];
%     dFk = [dFk,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];
% end
% %
% 
% data.dFk = dFk
%% Trial Samples
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
Tout = 0:0.0285:dur;
close all
figure()
subplot(2,1,1)
plot(Tout,-dFk(i:i+35*dur));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([0,dur])
title('analysis')

subplot(2,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
ylim([0,5])
xlim([0,dur])

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
close all;
figure()
plot(ff,nostimfft');

%%


% 
% %
% j = 100
% X = nostim(j,:);
%     Y = fft(X);
% 
%         P2 = abs(Y/L);
%         P1 = P2(1:L/2+1);
%         P1(2:end-1) = 2*P1(2:end-1);



nno_stim = reshape(nostim.',1,[]);
nv = var(nno_stim);

maxn = max(nostim);
minn = min(nostim);


nno_stimnc = reshape(nostim(nc,:).',1,[]);
nvnc = var(nno_stimnc);

maxnnc = max(nostim(nc,:));
minnnc = min(nostim(nc,:));

close all
figure()
plot(tns,nostim,'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(tns,mean(nostim,1),'r','LineWidth',3);
plot(tns,maxn,'k','LineWidth',2,'HandleVisibility','off');
plot(tns,minn,'k','LineWidth',2);
plot(tns,sqrt(nv)*ones(1,length(tns))+mean(nostim,1),'--k','LineWidth',2);
plot(tns,-sqrt(nv)*ones(1,length(tns))+mean(nostim,1),'--k','LineWidth',2,'HandleVisibility','off');
legend('trail average','min-max','std dev')
title('dF/F traces spontaneous')



figure()
plot(tns,nostim(nc,:),'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(tns,mean(nostim(nc,:),1),'r','LineWidth',3);
plot(tns,maxnnc,'k','LineWidth',2,'HandleVisibility','off');
plot(tns,minnnc,'k','LineWidth',2);
plot(tns,sqrt(nvnc)*ones(1,length(tns))+mean(nostim(nc,:),1),'--k','LineWidth',2);
plot(tns,-sqrt(nvnc)*ones(1,length(tns))+mean(nostim(nc,:),1),'--k','LineWidth',2,'HandleVisibility','off');
legend('trail average','min-max','std dev')
title('dF/F traces spontaneous before FFC')
%% Invariance analysis
% close all;
inv_wc = data.wcDfk(:,35:35*(dur+1));
inv_nc = data.ncDfk(:,35:35*(dur+1));

var_inv_wc = var(reshape(inv_wc.',1,[]));
var_inv_nc = var(reshape(inv_nc.',1,[]));


inv_wc = data.wcDfk(:,35:35*(dur+1));
inv_nc = data.ncDfk(:,35:35*(dur+1));

inv_wcl = data.pwcDfk(:,3*35:end-36);
inv_ncl = data.pncDfk(:,3*35:end-36);


var_wc = var(inv_wc);
var_nc = var(inv_nc);

var_wcl = var(inv_wcl);
var_ncl = var(inv_ncl);

inv_wc_max = max(inv_wc);
inv_wc_min = min(inv_wc);

inv_nc_max = max(inv_nc);
inv_nc_min = min(inv_nc);

inv_nc_mean = mean(inv_nc,1);
inv_wc_mean = mean(inv_wc,1);


inv_wc_maxl = max(inv_wcl);
inv_wc_minl = min(inv_wcl);

inv_nc_maxl = max(inv_ncl);
inv_nc_minl = min(inv_ncl);

inv_nc_meanl = mean(inv_ncl,1);
inv_wc_meanl = mean(inv_wcl,1);

NCvol = sum(inv_nc_max - inv_nc_mean - inv_nc_min)
WCvol = sum(inv_wc_max - inv_wc_mean - inv_wc_min)

% Invariance vol reduction
vol_red = (NCvol - WCvol)*100/NCvol

ts = -2:1/35:5;
tinp = 0:0.0005:3;

er_nc = (5+mean(mean(inv_nc,1)))*100/5
er_wc = (5+mean(mean(inv_wc,1)))*100/5
t0 = -2:1/35:0-1/35;
t1 = 0:1/35:3-1/35;
t2 = 3:1/35:5-1/35;
close all;
figure()
subplot(2,2,1)
plot(ts,inv_ncl,'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(ts,-5*ones(1,length(ts)),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(ts,mean(inv_ncl,1),'r','LineWidth',3);hold on;
plot(ts,inv_nc_maxl,'k','LineWidth',2,'HandleVisibility','off');
plot(ts,inv_nc_minl,'k','LineWidth',2,'HandleVisibility','off');
% plot(ts,sqrt(var_inv_nc)*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',2);
% plot(ts,-sqrt(var_inv_nc)*ones(1,length(ts))+mean(inv_nc,1),'--k','LineWidth',2,'HandleVisibility','off');

% plot(ts,sqrt(var_nc).*ones(1,length(ts))+mean(inv_ncl,1),'--k','LineWidth',3,'HandleVisibility','off');
% plot(ts,-sqrt(var_nc).*ones(1,length(ts))+mean(inv_ncl,1),'--k','LineWidth',3);

legend('trail average','FontSize',10)
% title(append('Open Loop, avg error=',num2str(er_nc),'%'))
title('Open Loop')

% xlabel('time(sec)','FontSize',10,'FontWeight','bold')
ylabel('dF/F %','FontSize',10,'FontWeight','bold')
ylim([-15 15])
xlim([-2 5])
xline(0,'--k','LineWidth',2,'HandleVisibility','off');
xline(3,'--k','LineWidth',2,'HandleVisibility','off');
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'FontName','Times','fontsize',10)

subplot(2,2,2)
plot(ts,inv_wcl,'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(ts,mean(inv_wcl,1),'r','LineWidth',3);hold on;
plot(ts,inv_wc_maxl,'k','LineWidth',1.5,'HandleVisibility','off');
plot(ts,inv_wc_minl,'k','LineWidth',1.5);

% plot(ts,sqrt(var_wc).*ones(1,length(ts))+mean(inv_wcl,1),'--k','LineWidth',3,'HandleVisibility','off');
% plot(ts,-sqrt(var_wc).*ones(1,length(ts))+mean(inv_wcl,1),'--k','LineWidth',3);% plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off');
% legend('trail average','min-max','std dev')
% title(append('Closed loop,  MSE=',num2str(er_wc),'%'))
title('Closed Loop')
ylim([-15 15])
xlim([-2 5])
% xlabel('time(sec)','FontSize',14,'FontWeight','bold')
% ylabel('dF/F %','FontSize',14,'FontWeight','bold')
xline(0,'--k','LineWidth',2,'HandleVisibility','off');
xline(3,'--k','LineWidth',2,'HandleVisibility','off');
a = get(gca,'XTickLabel');

i=20;

subplot(2,2,3)
plot(ts,inv_ncl(i,:),'LineWidth',0.3);hold on;
plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(tinp,4*data.ncInp(i,:),'r','LineWidth',2);hold on
xline(0,'--k','LineWidth',2,'HandleVisibility','off');
xline(3,'--k','LineWidth',2,'HandleVisibility','off');
xlabel('time(sec)','FontSize',10,'FontWeight','bold')
ylim([-15 15])
xlim([-2 5])
legend('pixel trace','input')

subplot(2,2,4)
plot(ts,inv_wcl(i,:),'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(tinp,4*data.wcInp(i,:),'r','LineWidth',2,'HandleVisibility','off');hold on
xline(0,'--k','LineWidth',2,'HandleVisibility','off');
xline(3,'--k','LineWidth',2,'HandleVisibility','off');
xlabel('time(sec)','FontSize',10,'FontWeight','bold')
ylim([-15 15])
xlim([-2 5])

set(gca,'XTickLabel',a,'FontName','Times','fontsize',10)
exportgraphics(gcf,'Pc.png','Resolution',1500)

%%
close all;
figure()
set(gca,'XTickLabel',a,'FontName','Times','fontsize',10)

subplot(1,2,1)
plot(ts,inv_ncl,'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(ts,-5*ones(1,length(ts)),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;

plot(t1,-20*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,-15*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,-15*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(ts,mean(inv_ncl,1),'r','LineWidth',3);hold on;
plot(ts,inv_nc_maxl,'k','LineWidth',2,'HandleVisibility','off');
plot(ts,inv_nc_minl,'k','LineWidth',2,'HandleVisibility','off');
plot(ts,-15+inv_ncl(i,:),'g','LineWidth',2);hold on;
plot(tinp,-15+4*data.ncInp(i,:),'b','LineWidth',2);hold on

% legend('trail average','trace','input(V)','FontSize',10)
% title(append('Open Loop, avg error=',num2str(er_nc),'%'))
title('Open Loop')

xlabel('time(sec)','FontSize',10)
ylabel('dF/F %','FontSize',10)
ylim([-25 12])
xlim([-2 5])
xline(0,'--k','LineWidth',2,'HandleVisibility','off');
xline(3,'--k','LineWidth',2,'HandleVisibility','off');
a = get(gca,'XTickLabel');
set(gca,'XTickLabel',a,'FontName','Times','fontsize',10)

subplot(1,2,2)
plot(ts,inv_wcl,'LineWidth',0.3,'HandleVisibility','off');hold on;
plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;


plot(t1,-20*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t0,-15*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
plot(t2,-15*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;

plot(ts,mean(inv_wcl,1),'r','LineWidth',3,'HandleVisibility','off');hold on;
plot(ts,inv_wc_maxl,'k','LineWidth',1.5,'HandleVisibility','off');
plot(ts,inv_wc_minl,'k','LineWidth',1.5);
plot(ts,-15+inv_wcl(i,:),'g','LineWidth',2,'HandleVisibility','off');hold on;
plot(tinp,-15+4*data.wcInp(i,:),'b','LineWidth',2,'HandleVisibility','off');hold on


% plot(ts,sqrt(var_wc).*ones(1,length(ts))+mean(inv_wcl,1),'--k','LineWidth',3,'HandleVisibility','off');
% plot(ts,-sqrt(var_wc).*ones(1,length(ts))+mean(inv_wcl,1),'--k','LineWidth',3);% plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off');
% legend('trail average','min-max','std dev')
% title(append('Closed loop,  MSE=',num2str(er_wc),'%'))
title('Closed Loop')
ylim([-25 12])
xlim([-2 5])
xlabel('time(sec)','FontSize',10)
% ylabel('dF/F %','FontSize',14,'FontWeight','bold')
xline(0,'--k','LineWidth',2,'HandleVisibility','off');
xline(3,'--k','LineWidth',2,'HandleVisibility','off');
a = get(gca,'XTickLabel');

i=20;

% subplot(2,2,3)
% plot(ts,inv_ncl(i,:),'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(tinp,data.ncInp(i,:),'r','LineWidth',2,'HandleVisibility','off');hold on
% xline(0,'--k','LineWidth',2,'HandleVisibility','off');
% xline(3,'--k','LineWidth',2,'HandleVisibility','off');
% 
% 
% subplot(2,2,4)
% plot(ts,inv_wcl(i,:),'LineWidth',0.3,'HandleVisibility','off');hold on;
% plot(t1,-5*ones(1,3*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(t0,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(t2,0*ones(1,2*35),'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(tinp,data.wcInp(i,:),'r','LineWidth',2,'HandleVisibility','off');hold on
% xline(0,'--k','LineWidth',2,'HandleVisibility','off');
% xline(3,'--k','LineWidth',2,'HandleVisibility','off');
exportgraphics(gcf,'Pc2.png','Resolution',1500)




%%
% exportgraphics(gcf,'Pc.png','Resolution',600)

% sgtitle('dF/F traces')

% % figure()
% subplot(2,2,3)
% % plot(ts,inv_nc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off'); hold on;
% % plot(ts,mean(inv_nc,1),'--k','LineWidth',3.5);hold on;
% plot(ts,inv_nc_max - inv_nc_mean ,'k','LineWidth',2,'HandleVisibility','off');hold on;
% plot(ts,inv_nc_min - inv_nc_mean,'k','LineWidth',2);
% plot(ts,sqrt(var_inv_nc)*ones(1,length(ts)),'--k','LineWidth',2);
% plot(ts,-sqrt(var_inv_nc)*ones(1,length(ts)),'--k','LineWidth',2,'HandleVisibility','off');
% legend('min-max','std dev','FontSize',14,'FontWeight','Bold')
% title('dF/F envelope wrt avg')
% ylim([-15 15]) 
% xlabel('time','FontSize',14,'FontWeight','bold')
% ylabel('relative dF/F ','FontSize',14,'FontWeight','bold')
% a = get(gca,'XTickLabel');
% set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
% 
% 
% subplot(2,2,4)
% % plot(ts,inv_wc,'LineWidth',0.3,'HandleVisibility','off');hold on;
% % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off'); hold on;
% % plot(ts,mean(inv_wc,1),'--k','LineWidth',3.5);hold on;
% plot(ts,inv_wc_max - inv_wc_mean,'k','LineWidth',2,'HandleVisibility','off'); hold on;
% plot(ts,inv_wc_min - inv_wc_mean,'k','LineWidth',2);
% 
% plot(ts,sqrt(var_inv_wc)*ones(1,length(ts)),'--k','LineWidth',2);
% plot(ts,-sqrt(var_inv_wc)*ones(1,length(ts)),'--k','LineWidth',2,'HandleVisibility','off');
% 
% plot(ts,sqrt(var_wc).*ones(1,length(ts)),'--g','LineWidth',2,'HandleVisibility','off');
% plot(ts,-sqrt(var_wc).*ones(1,length(ts)),'--g','LineWidth',2,'HandleVisibility','off');
% 
% 
% % plot(ts,-5*ones(1,length(ts)),'--r','LineWidth',1,'HandleVisibility','off');
% % legend('min-max','std dev','FontSize',14,'FontWeight','Bold')
% % title('dF/F traces FBC variance')
% title(append('dF/F envelope size reduction ',num2str(vol_red),'%'))
% ylim([-15 15])
% xlabel('time','FontSize',14,'FontWeight','bold')
% % ylabel('dF/F relative to trial-average','FontSize',18,'FontWeight','bold')
% a = get(gca,'XTickLabel');
% set(gca,'XTickLabel',a,'FontName','Times','fontsize',14)
red_ratio = sum(var_wc/var_nc);

% figure()
% plot(ts,var_wc,'g','LineWidth',2);hold on;
% plot(ts,var_nc,'r','LineWidth',2);
% legend('FBC','FFC')
% xlabel('time','FontSize',14,'FontWeight','bold')
% ylabel('variance','FontSize',14,'FontWeight','bold')
% title(append('variance across experiment, reduction ratio = ',num2str(red_ratio)))

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
%% Inv Volumes

NCvol = sum(inv_nc_max - inv_nc_mean - inv_nc_min)
WCvol = sum(inv_wc_max - inv_wc_mean - inv_wc_min)

% Invariance vol reduction
vol_red = (NCvol - WCvol)*100/NCvol

%%
m = min(inv_nc_mean);
m2 = mean(inv_nc_mean(end-35:end))
j = 7;
figure()
% plot(ts,inv_nc);hold on;
plot(ts,inv_nc_mean - m2,'r','LineWidth', 2);hold on;
% plot(ts,m*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;
% plot(ts,m2*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;
plot(ts,0*ones(1,length(inv_nc_mean)),'--k','LineWidth', 2);hold on;

xlabel('time')
ylabel('dF/F wrt mean')
% ylim([-8 2])
title('Step response deviation from mean')


%%
m = markeranalysis(d,data);
%% plots
dur = d.params.dur;
ncDfk = data.ncDfk;
wcDfk = data.wcDfk;
nc_avg = mean(ncDfk,1);
wc_avg = mean(wcDfk,1);
T= -1:0.0285:(dur+1);
Tin = 0:0.0005:dur;
Tout = 0:0.0285:dur;

figure()

plot(T,wcDfk);hold on
plot(T,-5*ones(1,length(T)),'--r','Linewidth',3);hold on
plot(T,wc_avg,'k','Linewidth',3);
xline(0)
xline(dur)
ylim([-20 20])
xlim([-1 4])
title('Feedback')
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
% if a == 1
%     hgexport(gcf,'images/comp_controllers01102.pdf',figure_property); %Set desired file name
% end

%%
wc = data.wc;
nc = data.nc;

stimStarts = d.stimStarts;
stimEnds = d.stimEnds;

tt = d.inpTime;
v = d.inpVals;

close all
c=3;
j = wc(c);
[a i] = min(abs(t - stimStarts(j)));
[a i2] = min(abs(t - stimEnds(j)));

[a k] = min(abs(tt - stimStarts(j)));
[a k2] = min(abs(tt - stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = 0:0.0285:dur;
close all
figure()
subplot(2,2,1)
plot(Tout,dFk(i:i+35*dur));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([0,dur])
title('wc')

subplot(2,2,3)
plot(tt(k:k2)-tt(k),v(k:k2));hold on
plot(data.wcInp(c,:))
xlim([0,dur])
ylim([0,5])

j = nc(c);
[a i] = min(abs(t - stimStarts(j)));
[a i2] = min(abs(t - stimEnds(j)));

[a k] = min(abs(tt - stimStarts(j)));
[a k2] = min(abs(tt - stimEnds(j)));

subplot(2,2,2)
plot(Tout,dFk(i:i+35*dur));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([0,dur])
title('nc')

subplot(2,2,4)
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([0,dur])
ylim([0,5])

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


% X0=[];
% for j = 1: length(d.stimStarts)
%     [a i] = min(abs(t - d.stimStarts(j)));
%     X0 = [X0; dFk(i)];
% end


% %% Controlability test
% % stack feedforward and feedback
% 
% dur = d.params.dur;
% nc = data.nc;
% pncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - d.stimStarts(nc(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
% 
%     pncDfk = [pncDfk; dFk(i-35*5:i+35*(dur+1))];
% end
% 
% wc = data.wc;
% 
% pwcDfk=[];
% for j = 1: length(wc)
%     [a i] = min(abs(t - d.stimStarts(wc(j))));
%     pwcDfk = [pwcDfk; dFk(i-35*5:i+35*(dur+1))];
% end
% 
% %% Compute H2 performance per trial sum(||e||)
% 
% Tout = 0:0.0285:dur;
% 
% er_ncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - stimStarts(nc(j))));
%     er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
% end
% 
% 
% 
% 
% er_wcDfk=[];
% for j = 1: length(wc)
%     [a i] = min(abs(t - d.stimStarts(wc(j))));
%     er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
% end
% 
% 
% 
% %%
% figure()
% plot(er_ncDfk,'or','LineWidth',2);hold on;
% plot(er_wcDfk,'og','LineWidth',2);
% legend('feedforward','feedback')
% title('H2 performance per trial')
% ylabel('error')
% xlabel('Trials')


%%
% close all;
% er_wcDfk = data.er_wcDfk;
% er_ncDfk = data.er_ncDfk;
% 
% 
% pwcDfk = data.pwcDfk;
% pncDfk = data.pncDfk;
% 
% a1 = find(er_wcDfk > 20);
% a2 = find(er_wcDfk < 20);
% 
% [mm,amax] = max(er_wcDfk);
% [mm,amin] = min(er_wcDfk);
% 
% [a kmax] = min(abs(tt - stimStarts(j)));
% [a kmin] = min(abs(tt - stimEnds(j)));
% 
% 
% [mm,amaxf] = max(er_ncDfk);
% [mm,aminf] = min(er_ncDfk);
% 
% Tout = -5:0.0285:(dur+3);
% i=3
% 
% figure()
% subplot(2,2,2)
% plot(Tout,pwcDfk(amax,:)');hold on;
% xline(0)
% xline(3)
% xlim([-5,4])
% yline(0)
% yline(-5)
% ylim([-15,15])
% title(' feedback high H2')
% 
% subplot(2,2,4)
% plot(Tout,pwcDfk(amin,:)');hold on;
% xline(0)
% xline(3)
% xlim([-5,4])
% yline(0)
% yline(-5)
% ylim([-15,15])
% title('feedback low H2')
% 
% subplot(2,2,1)
% plot(Tout,pncDfk(amaxf,:)');hold on;
% xline(0)
% xline(3)
% xlim([-5,4])
% yline(0)
% yline(-5)
% ylim([-15,15])
% title('feedforward high H2')
% 
% 
% 
% subplot(2,2,3)
% plot(Tout,pncDfk(aminf,:)');hold on;
% xline(0)
% xline(3)
% xlim([-5,4])
% yline(0)
% yline(-5)
% ylim([-15,15])
% title('feedforward low H2')


%% Analysis based on H2 
close all;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;


pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;
% a1 = find(er_wcDfk > 20);
% a2 = find(er_wcDfk < 20);

er = sort(er_wcDfk)

%%

[m1,i1] = max(er_wcDfk);
[m2,i2] = min(er_wcDfk);

i=1;
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
plot(Tp2,m.fft1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.fft2((k1-35*5):(k1+35*(dur+1))));hold on
% plot(Tp,m.fft3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,m.fft4((k1-35*5):(k1+35*(dur+1))));hold on
plot(Tp2,m.Rv1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv2((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
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
plot(Tp2,m.fft1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.fft2((k2-35*5):(k2+35*(dur+1))));hold on
% plot(Tp,m.fft3((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,m.fft4((k2-35*5):(k2+35*(dur+1))));hold on
plot(Tp2,m.Rv1((k2-35*5):(k2+35*(dur+1))));hold on
% plot(Tp,m.Rv2((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv3((k2-35*5):(k2+35*(dur+1))));hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
% legend('0-6Hz','var 2s')
title('paramerter approximation')

[a k11] = min(abs(tt - stimStarts(j1)));
[a k12] = min(abs(tt - stimEnds(j1)));

subplot(3,2,5)
plot(tt(k11:k12)-tt(k11),v(k11:k12))
xlim([-5,4])
ylim([0,5])
ylabel('input')
xlabel('time')

[a k21] = min(abs(tt - stimStarts(j2)));
[a k22] = min(abs(tt - stimEnds(j2)));

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
plot(Tp2,m.fft1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.fft2((k1-35*5):(k1+35*(dur+1))));hold on
% plot(Tp,m.fft3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,m.fft4((k1-35*5):(k1+35*(dur+1))));hold on
plot(Tp2,m.Rv1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv2((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
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
plot(Tp2,m.fft1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.fft2((k2-35*5):(k2+35*(dur+1))));hold on
% plot(Tp,m.fft3((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
plot(Tp2,m.fft4((k2-35*5):(k2+35*(dur+1))));hold on
plot(Tp2,m.Rv1((k2-35*5):(k2+35*(dur+1))));hold on
% plot(Tp,m.Rv2((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,m.Rv3((k2-35*5):(k2+35*(dur+1))));hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
% legend('0-6Hz','var 2s')
title('paramerter approximation')

[a k11] = min(abs(tt - stimStarts(j1)));
[a k12] = min(abs(tt - stimEnds(j1)));

subplot(3,2,5)
plot(tt(k11:k12)-tt(k11),v(k11:k12),'LineWidth',3)
xlim([-5,4])
ylim([0,5])
ylabel('input')
xlabel('time')

[a k21] = min(abs(tt - stimStarts(j2)));
[a k22] = min(abs(tt - stimEnds(j2)));

subplot(3,2,6)
plot(tt(k21:k22)-tt(k21),v(k21:k22),'LineWidth',3)
xlim([-5,4])
ylim([0,5])
ylabel('input')
xlabel('time')

sgtitle('FFC')
%%
% i=5
% m1=a1(i);
% j1 = wc(m1);
% 
% m2=a2(i);
% j2 = wc(m2);
% 
% [a k1] = min(abs(t - d.stimStarts(j1)));
% 
% [a k2] = min(abs(t - d.stimStarts(j2)));
% k1
% k2
% Tp = -5:0.0285:dur+1;
% close all
% figure()
% subplot(2,2,1)
% plot(pwcDfk(a1(i),:)');hold on;
% xline(35*5)
% xline(35*8)
% yline(0)
% yline(-5)
% ylim([-15,15])
% title('uncontrollable')
% 
% subplot(2,2,3)
% plot(Rv((k1-35*5):(k1+35*(dur+1))));hold on
% xline(35*5)
% xline(35*8)
% ylim([0,30])
% title('uncontrollable')
% 
% 
% subplot(2,2,2)
% plot(pwcDfk(a2(i),:)');hold on;
% xline(35*5)
% xline(35*8)
% yline(0)
% yline(-5)
% ylim([-15,15])
% title('controllable')
% 
% subplot(2,2,4)
% plot(Rv((k2-35*5):(k2+35*(dur+1))));hold on
% xline(35*5)
% xline(35*8)
% ylim([0,30])
% title('controllable')

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


s_v_val_fb = [];
s_f_val_fb = [];

s_v_val_ff = [];
s_f_val_ff = [];


for i=1:length(data.wc)
    j =wc(i);
    [a k] = min(abs(t - d.stimStarts(j)));
    [a k2] = min(abs(t - d.stimEnds(j)));
    v_val_fb = [v_val_fb; m.Rv2(k)];
    f_val_fb = [f_val_fb; m.fft3(k)];


    s_v_val_fb = [s_v_val_fb; sum(m.Rv2(k:k2))];
    s_f_val_fb = [s_f_val_fb; sum(m.fft3(k:k2))];
end

for i=1:length(data.nc)
    j =nc(i);
    [a k] = min(abs(t - d.stimStarts(j)));
        [a k2] = min(abs(t - d.stimEnds(j)));

    v_val_ff = [v_val_ff; m.Rv2(k)];
    f_val_ff = [f_val_ff; m.fft3(k)];

    s_v_val_ff = [s_v_val_ff; sum(m.Rv2(k:k2))];
    s_f_val_ff = [s_f_val_ff; sum(m.fft3(k:k2))];
end




%
close all
figure()
subplot(1,2,1)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(v_val_fb,er_wcDfk,'go','Linewidth',2); hold on;
plot(v_val_ff,er_ncDfk,'ro','Linewidth',2);
legend('feedback','feedforward')
xlabel('var')
ylabel('H2 performance')
ylim([0,110])
xlim([0,40])


subplot(1,2,2)
plot(f_val_fb,er_wcDfk,'go','Linewidth',2);hold on;
plot(f_val_ff,er_ncDfk,'ro','Linewidth',2);
ylabel('H2 performance')
xlabel('0-6hz')
ylabel('tracking error')
ylim([0,110])
xlim([0,30])


%%
figure()
plot(er_wcDfk,X0,'go','Linewidth',2);hold on
ylabel('x0')
xlabel('tracking error')
xlim([0,110])
ylim([-20,20])

%% 

X0a = find(abs(X0)<2.5);
X0b = find(abs(X0)>2.5 & abs(X0)<5);
X0c = find(abs(X0)>5 & abs(X0)<7.5);
X0d = find(abs(X0)>7.5);


%%
figure()
plot(er_wcDfk(X0a), X0(X0a),'go','Linewidth',2);hold on
plot(er_wcDfk(X0b), X0(X0b),'ro','Linewidth',2);hold on
plot(er_wcDfk(X0c), X0(X0c),'bo','Linewidth',2);hold on
plot(er_wcDfk(X0d), X0(X0d),'ko','Linewidth',2);hold on



%%
close all;

figure()
plot3(X0,v_val_fb,er_wcDfk,'go','Linewidth',4)
xlabel('x0 (df/F)')
ylabel('variance')
zlabel('Tracking error')
grid on
%
figure()
% s = scatter3(X0,v_val_fb,p_wcDfk,'x0 (df/F)','variance','Tracking Error','filled', ...
%     'ColorVariable','Tracking Error');
% s = scatter3(X0,v_val,p_wcDfk,'filled','ColorVariable',p_wcDfk);
s = scatter3(X0,v_val_fb,er_wcDfk,[],er_wcDfk,'filled');
xlabel('x_0 df/F')
ylabel('variance')
zlabel('Tracking error norm')
colorbar
clim([20 50])

figure()
subplot(1,2,1)
s = scatter3(X0,f_val_fb,er_wcDfk,[],er_wcDfk,'filled');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
colorbar
title('feedback')

subplot(1,2,2)
s = scatter3(XX0,f_val_ff,er_ncDfk,[],er_ncDfk,'filled');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
colorbar
title('feedforward')




figure()
subplot(1,2,1)
s = scatter3(X0,v_val_fb,er_wcDfk,[],er_wcDfk,'filled');
xlabel('x_0 df/F')
ylabel('variance marker')
zlabel('Tracking error norm')
colorbar
zlim([0,100])
clim([0,80])
title('feedback')

subplot(1,2,2)
s = scatter3(XX0,v_val_ff,er_ncDfk,[],er_ncDfk,'filled');
xlabel('x_0 df/F')
ylabel('variance marker')
zlabel('Tracking error norm')
colorbar
title('feedforward')
zlim([0,100])
clim([0,80])



figure()
s = scatter3(X0,v_val_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,v_val_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('variance marker')
zlabel('Tracking error norm')
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizable set')


%%
close all
figure()
s = scatter3(X0,s_v_val_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,s_v_val_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('variance marker')
zlabel('Tracking error norm')
% colorbar
% zlim([0,100])
% clim([0,80])
title('during stim regularizable set')

figure()
s = scatter3(X0,s_f_val_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,s_f_val_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% colorbar
% zlim([0,100])
% clim([0,80])
title('during stim regularizable set')
%%
close all

figure()
s = scatter3(X0,f_val_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,f_val_ff,er_ncDfk,[],er_ncDfk,'filled','r');
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
subplot(1,2,1)
s = scatter3(X0,s_v_val_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,s_v_val_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('variance marker')
zlabel('Tracking error norm')
% colorbar
% zlim([0,100])
% clim([0,80])
title('during stim regularizable set')

threshold = 20; 

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

subplot(1,2,2)
s = scatter3(X0,s_f_val_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(XX0,s_f_val_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% colorbar
% zlim([0,100])
% clim([0,80])
title('during stim regularizable set')
threshold = 20; 

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



%% Averaging based on wc and nc

wc_stab=[];
wc_ustab=[];
fm = 10;
xm = 5;
for i = 1:length(wc)
    j = wc(i)
    [a k] = min(abs(t - d.stimStarts(j)));
k

    if m.fft3(k) <=fm & abs(X0(i))<=xm
        wc_stab = [wc_stab;j]
        j
    else
        wc_ustab = [wc_ustab;j];
        
    end
end

%



nc_stab=[];
nc_ustab=[];
for i = 1:length(nc)
    j = nc(i);
    [a k] = min(abs(t - d.stimStarts(j)));
    if m.fft3(k) <=fm & abs(XX0(i))<=xm
        nc_stab = [nc_stab;j];
    else
        nc_ustab = [nc_ustab;j];
    end

end



ssncDfk=[];
ssncDfk0=[];
for j = 1: length(nc_stab)
    [a i] = min(abs(d.timeBlue - d.stimStarts(nc_stab(j))));
    ssncDfk = [ssncDfk; dFk(i-35:i+35*(d.params.dur+1))];
    ssncDfk0 = [ssncDfk0; dFk(i-35*5:i)];
end
usncDfk=[];
usncDfk0=[];
for j = 1: length(nc_ustab)
    [a i] = min(abs(d.timeBlue - d.stimStarts(nc_ustab(j))));
    usncDfk = [usncDfk; dFk(i-35:i+35*(d.params.dur+1))];
    usncDfk0 = [usncDfk0; dFk(i-35*5:i)];
end



sswcDfk=[];
sswcDfk0=[];
for j = 1: length(wc_stab)
    [a i] = min(abs(d.timeBlue - d.stimStarts(wc_stab(j))));
    sswcDfk = [sswcDfk; dFk(i-35:i+35*(d.params.dur+1))];
    sswcDfk0 = [sswcDfk0; dFk(i-35*5:i)];
end
uswcDfk=[];
uswcDfk0=[];
for j = 1: length(wc_ustab)
    [a i] = min(abs(d.timeBlue - d.stimStarts(wc_ustab(j))));
    uswcDfk = [uswcDfk; dFk(i-35:i+35*(d.params.dur+1))];
    uswcDfk0 = [uswcDfk0; dFk(i-35*5:i)];

end

ssnc_avg = mean(ssncDfk,1);
sswc_avg = mean(sswcDfk,1);

usnc_avg = mean(usncDfk,1);
uswc_avg = mean(uswcDfk,1);



er_wss = vecnorm(sswcDfk,2,2);
er_wus = vecnorm(uswcDfk,2,2);

T= -1:0.0285:(dur+1);
Tin = 0:0.0005:dur;
Tout = 0:0.0285:dur;


figure()
subplot(1,2,1)
plot(T,ssncDfk);hold on
plot(T,-5*ones(1,length(T)),'--r','Linewidth',3);hold on
plot(T,ssnc_avg,'k','Linewidth',3);
xline(0)
xline(dur)
ylim([-20 20])
xlim([-1 4])
title('Feedforward')

subplot(1,2,2)
plot(T,sswcDfk);hold on
plot(T,-5*ones(1,length(T)),'--r','Linewidth',3);hold on
plot(T,sswc_avg,'k','Linewidth',3);
xline(0)
xline(dur)
ylim([-20 20])
xlim([-1 4])
title('Feedback')
figure_property.Width= '16'; % Figure width on canvas
figure_property.Height= '9'; % Figure height on canvas
% if a == 1
%     hgexport(gcf,'images/comp_controllers01102.pdf',figure_property); %Set desired file name
% end

% uiwait(k)

%%
close all
figure()
subplot(1,2,1)
plot(T,-5*ones(1,length(T)),'--r','Linewidth',3);hold on
plot(T,ssnc_avg,'k','Linewidth',3);
plot(T,nc_avg,'b','Linewidth',3);
plot(T,usnc_avg,'r','Linewidth',3);
xline(0)
xline(dur)
ylim([-20 20])
xlim([-1 4])
legend('ref','stab','all','unstab')
title('Feedforward')

subplot(1,2,2)
plot(T,-5*ones(1,length(T)),'--r','Linewidth',3);hold on
plot(T,sswc_avg,'k','Linewidth',3);
plot(T,wc_avg,'b','Linewidth',3);

plot(T,uswc_avg,'r','Linewidth',3);
xline(0)
xline(dur)
ylim([-20 20])
xlim([-1 4])
legend('ref','stab','all','unstab')
title('FeedBack')
clc%%
er_wss = vecnorm(sswcDfk,2,2);
er_wus = vecnorm(uswcDfk,2,2);

er_nss = vecnorm(ssncDfk,2,2);
er_nus = vecnorm(usncDfk,2,2);


%%
close all;
figure()
subplot(1,2,1)
plot(er_wss,'og','LineWidth',2);hold on;
plot(er_wus,'or','LineWidth',2);hold on;
title('marker feedback')
ylim([0 140])
ylabel('error')
xlabel('iter')

subplot(1,2,2)
plot(er_nss,'og','LineWidth',2);hold on;
plot(er_nus,'or','LineWidth',2);hold on;
legend('stab','un-stab')
ylim([0 140])
title('marker feedforward')
ylabel('error')
xlabel('iter')

%%

% close all;
% i = 5
% 
% figure()
% for i = 1:16
% Xa = pwcDfk(i,(5-dur)*35:5*35);
% Xb = pwcDfk(i,5*35:(5+dur)*35);
% Ya = fft(Xa);
% Yb = fft(Xb);
% 
% Fs = 35;              % Sampling frequency                    
% T = 1/Fs;             % Sampling period       
% L = (dur*35);         % Length of signal
% t = (0:L-1)*T;        % Time vector
% 
% P2a = abs(Ya/L);
% P1a = P2a(1:L/2+1);
% P1a(2:end-1) = 2*P1a(2:end-1);
% 
% P2b = abs(Yb/L);
% P1b = P2b(1:L/2+1);
% P1b(2:end-1) = 2*P1b(2:end-1);
% 
% f = Fs/L*(0:(L/2));
% 
% subplot(4,4,i)
% plot(f,P1a,'g',"LineWidth",3);hold on 
% plot(f,P1b,'r',"LineWidth",3) 
% 
% xlabel("f (Hz)")
% ylabel("|P1(f)|")
% end
% legend('pre_stim','stim')
% sgtitle("Single-Sided Amplitude Spectrum of X(t)")


%%
% close all;
% 
% Xa = pwcDfk(:,(5-dur)*35:5*35);
% Xb = pwcDfk(:,5*35:(5+dur)*35);
% Ya = fft(Xa);
% Yb = fft(Xb);
% 
% Fs = 35;              % Sampling frequency                    
% T = 1/Fs;             % Sampling period       
% L = (dur*35);         % Length of signal
% t = (0:L-1)*T;        % Time vector
% 
% P2a = abs(Ya/L);
% P1a = P2a(1:L/2+1);
% P1a(2:end-1) = 2*P1a(2:end-1);
% 
% P2b = abs(Yb/L);
% P1b = P2b(1:L/2+1);
% P1b(2:end-1) = 2*P1b(2:end-1);
% 
% f = Fs/L*(0:(L/2));
% 
% figure()
% plot(f,P1a,'g',"LineWidth",3);hold on 
% plot(f,P1b,'r',"LineWidth",3) 
% legend('pre_stim','stim')
% xlabel("f (Hz)")
% ylabel("|P1(f)|")

%%
close all;

figure()
plot(Tp,pncDfk)

%% Variance analysis


% all data
close all;
TT = 0:1/35:dur;
wcdfk = wcDfk(:,35*1:35*(dur+1));
ncdfk = ncDfk(:,35*1:35*(dur+1));
wcdfk0 = pwcDfk(:,1:35*5);
ncdfk0 = pncDfk(:,1:35*5);

% segrgated data
stab_wc = sswcDfk(:,35*1:35*(dur+1));
stab_nc = ssncDfk(:,35*1:35*(dur+1));
ustab_wc = uswcDfk(:,35*1:35*(dur+1));
ustab_nc = usncDfk(:,35*1:35*(dur+1));

stab_wc0 = sswcDfk0(:,1:35*5);
stab_nc0 = ssncDfk0(:,1:35*5);
ustab_wc0 = uswcDfk0(:,1:35*5);
ustab_nc0 = usncDfk0(:,1:35*5);



% mean
mwcdfk = mean(wcdfk);
mncdfk = mean(ncdfk);
mwcdfk0 = mean(wcdfk0);
mncdfk0 = mean(ncdfk0);

mstabwc = mean(stab_wc);
mstabnc = mean(stab_nc);
mstabwc0 = mean(stab_wc0);
mstabnc0 = mean(stab_wc0);

mustabwc = mean(ustab_wc);
mustabnc = mean(ustab_nc);
mustabwc0 = mean(ustab_wc0);
mustabnc0 = mean(ustab_wc0);






figure()
plot(wcDfk')

figure()
plot(pwcDfk')

figure()
plot(mwcdfk);hold on
plot(mncdfk);hold on

figure()
plot(mwcdfk0);hold on;
plot(mncdfk0);hold on;
%%


vwc = var(wcdfk);
vnc = var(ncdfk);
vwc0 = var(wcdfk0);
vnc0 = var(ncdfk0);


% segrgated data
vswc = var(stab_wc);
vsnc = var(stab_nc) ;
vuwc = var(ustab_wc) ;
vunc = var(ustab_nc) ;

vswc0 = var(stab_wc0) ;
vsnc0 = var(stab_nc0) ;
vuwc0 = var(ustab_wc0);
vunc0 = var(ustab_nc0);

%%
close all;
figure()
plot(vwc);hold on;
plot(vnc);hold on;


figure()
plot(vwc0);hold on;
plot(vnc0);hold on;


close all;
t1 = 0:1/35:dur;
t0 = -5:1/35:0;
figure()
subplot(2,2,1)
plot(t0(2:end),vswc0,'g');hold on;
plot(t0(2:end),vsnc0,'r');
legend('feedback','feedforward')
title('openloop variance stabilizable set')
ylim([0,40])

subplot(2,2,3)
plot(t0(2:end),vuwc0,'g');hold on;
plot(t0(2:end),vunc0,'r');
legend('feedback','feedforward')
title('openloop variance un-stabilizable set')
ylim([0,40])

subplot(2,2,2)
plot(t1,vswc,'g');hold on;
plot(t1,vsnc,'r');
legend('feedback','feedforward')
title('closedloop variance stabilizable set')
ylim([0,40])

subplot(2,2,4)
plot(t1,vuwc,'g');hold on;
plot(t1,vunc,'r');
legend('feedback','feedforward')
title('closedloop variance un-stabilizable set')
ylim([0,40])
%% Variance analysis
wcvar = var(reshape(wcdfk,1,[]))
ncvar = var(reshape(ncdfk,1,[]))

wcvar0 = var(reshape(wcdfk0,1,[]))
ncvar0 = var(reshape(ncdfk0,1,[]))


swcvar = var(reshape(stab_wc,1,[]))
sncvar = var(reshape(stab_nc,1,[]))
uwcvar = var(reshape(ustab_wc,1,[]))
uncvar = var(reshape(ustab_nc,1,[]))

swcvar0 = var(reshape(stab_wc0,1,[]))
sncvar0 = var(reshape(stab_nc0,1,[]))
uwcvar0 = var(reshape(ustab_wc0,1,[]))
uncvar0 = var(reshape(ustab_nc0,1,[]))


%%
Fs = 35;            % Sampling frequency       
T = 1/Fs;           % Sampling period       
% L = 2*35;
L = 70;           % Length of signal
ti = (0:L-1)*T;     % Time vector
N = L+1;

dFk = data.dFk;


w = 10000;
X = dFk(w:w+L);
Y = fft(X);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs/L*(0:(L/2));


figure()
subplot(2,1,1)
plot(f,P1);

subplot(2,1,2)
plot(dFk(w:w+L));
%%
close all;
j=10;
tk = 0:1/35:3;
figure()
subplot(2,1,1)
plot(tk,data.ncDfk(j,35:(35)*(dur+1)));


ti = 0:0.0005:3;
subplot(2,1,2)
plot(ti,data.ncInp(j,:));


%%
ti = 0:0.0005:3;
close all;
j=10;
tk = 0:1/35:3;
figure()
subplot(2,1,1)
plot(ti,data.ncInp);


ti = 0:0.0005:3;
subplot(2,1,2)
plot(ti,data.wcInp);




%% Controller Eval 

% How effective is PI controller under different measurements of error?


% Q1 Mean across time versus Target level
% A: MSE plots  

% Q2 Var across trials
% A: Var plots

% Q3 Var within trial
% A: 


%% Classification Correlation analysis

er_wcDfk

i=1;

a1 = find(er_wcDfk==(er(i)));
a2 = find(er_wcDfk==(er(length(er_wcDfk)-i)));


m1=a1;
j1 = wc(m1);

m2=a2;
j2 = wc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));
[a k2] = min(abs(t - d.stimStarts(j2)));

k1
k2

%%
    nSV = 500;

        [U, V, t, mimg] = loadUVt(serverRoot, nSV);
        mimg = mimg';
        j=1;
        mI = [];
        %%
F2 = [];
        pixel = [200,150];
j=1
k=d.params.kernel;

        for i = 1:length(V)
            mimg_kernel = mimg(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k);
            mI = [mI,mean(mimg_kernel,'all')];
            imkernel = U(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k,:);
            % size(imkernel)
            imstack = mean(imkernel,[1,2]);
            % size(imstack)   
            F2 = [F2,reshape(imstack,[1,500])*V(:,i)];
        end

 w=d.params.horizon-1;
    Fk  = [ones(1,w),F2];
    dF=[];
    Fmean=[];
    dFk2=[];
    Fkmean=[];
%%
    for i = 1:length(F2)
        % Add an LPF filter 
        if mode == 0

        Fkmean = [Fkmean,mean(Fk(i:i+w))];
        dFk2 = [dFk2,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];
        else
        dFk2 = [dFk2,(F(i))/mI(i)*100];
        end

    end
%%
    % F = [];
    % 
    % k=d.params.kernel;
    % display('computing pixel val')
    % 
    % 
    %     source_dir ='/mnt/data/brain/';
    %     source_dir = append(source_dir,d.mn,'/',d.td,'/',num2str(d.en));
    %     a=dir([source_dir '/*']);
    %     out=size(a,1);
    % 
    %     out=out-2;
    %     path = append(source_dir,'/frame-');
    % 
    %     for i=1:2:out
    %         pathim=append(path,num2str(i-1));
    %         fileID = fopen(pathim,'r');
    %         A = fread(fileID,[560,560],'uint16')';
    %         % j=length(pixel);
    %         j=1;
    %         G = mean(A(pixel(j,2)-k:pixel(j,2)+k,pixel(j,1)-k:pixel(j,1)+k),'all');
    % 
    %         F = [F,G];
    % 
    % 
    %     end
%%
er_wcDfk

i=1;

a1 = find(er_wcDfk==(er(i)));
a2 = find(er_wcDfk==(er(length(er_wcDfk)-i)));


m1=a1;
j1 = wc(m1);

m2=a2;
j2 = wc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));
[a k2] = min(abs(t - d.stimStarts(j2)));

k1
k2

[a k11] = min(abs(tt - stimStarts(j1)));
[a k12] = min(abs(tt - stimEnds(j1)));

% figure()
% plot(tt(k11:k12)-tt(k11),v(k11:k12),'LineWidth',3)
% xlim([-5,4])
% ylim([0,5])
% ylabel('input')
% xlabel('time')



close all
figure()
plot(dFk(k1:k1+35*(dur)),'LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
title('regularized signal')


figure()
plot(dFk(k2:k2+35*(dur)),'LineWidth',2);hold on;
title('unregularized signal')


figure()
plot(dFk2(k1:k1+35*(dur)),'LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
title('regularized signal')


figure()
plot(dFk2(k2:k2+35*(dur)),'LineWidth',2);hold on;
title('unregularized signal')
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


%%

        nSV = 500;

        [U1, V1, t1, mimg1] = loadUVt(serverRoot, nSV);

