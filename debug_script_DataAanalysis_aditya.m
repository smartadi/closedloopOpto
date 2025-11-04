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


mn = 'AL_0033'; td = '2024-12-20'; 
en = 7;


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

serverRoot = expPath(mn, td, en)

%%
% input_params = readmatrix(append(serverRoot,"/data/input_params.csv"));
% % frames = readmatrix(append(serverRoot,"/frames.csv"));
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
% save('pixel12231.mat','F')
% load('pixel2231.mat')

load('pixel12207.mat')
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





%%

close all
j=50
[a i] = min(abs(t - stimStarts(j)));
[a i2] = min(abs(t - stimEnds(j)));
figure()
plot(t(i-35:i+35*4),dFk(i-35:i+35*4))
xline(t(i))
xline(t(i2))

%% No controller:

% nc = find(input_params(:,7)==0);
% 
% % sort by ref level:
% 
% nc_Kref = sortrows(input_params(nc,:),1)

% nc = find(input_params(:,2)==0 & input_params(:,3) == 0 & input_params(:,1) == 0.175);
% wc = find(input_params(:,2)~=0 & input_params(:,1) == 0.175);

nc = find(input_params(:,3)==0);
wc = find(input_params(:,3)==1);


%%
close all;

% dur=4;
ncDfk=[];
for j = 1: length(nc)
    [a i] = min(abs(t - stimStarts(nc(j))));

    % [a i2] = min(abs(t - stimEnds(nc_ref(j))));

    ncDfk = [ncDfk; dFk(i-35:i+35*(dur+1))];
end



wcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - stimStarts(wc(j))));

    % [a i2] = min(abs(t - stimEnds(nc_ref(j))));

    wcDfk = [wcDfk; dFk(i-35:i+35*(dur+1))];
end
%%

nc_avg = mean(ncDfk,1);
wc_avg = mean(wcDfk,1);
T= -1:0.0285:(dur+1);
Tin = 0:0.0005:dur;
Tout = 0:0.0285:dur;
%% 
% close all;
% % 
% figure()
% subplot(1,2,1)
% plot(T,ncDfk);hold on
% plot(T,-5*ones(1,length(T)),'--r','Linewidth',3);hold on
% plot(T,nc_avg,'k','Linewidth',3);
% xline(0)
% xline(dur)
% ylim([-20 20])
% title('Feedforward')
% 
% subplot(1,2,2)
% plot(T,wcDfk);hold on
% plot(T,-5*ones(1,length(T)),'--r','Linewidth',3);hold on
% plot(T,wc_avg,'k','Linewidth',3);
% xline(0)
% xline(dur)
% ylim([-20 20])
% title('Feedback')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas
% hgexport(gcf,'images/comp_controllers.pdf',figure_property); %Set desired file name

%% Customized
% 
% wc_ref = find(input_params(:,2) >=0.2 & input_params(:,1) ~= 0 & input_params(:,4) == 10);
% 
% 
% 
% wcDfk=[];
% for j = 1: length(wc_ref)
%     [a i] = min(abs(t - stimStarts(wc_ref(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
%     ab = dFk(i-35:i+35*4);
% 
%     wcDfk = [wcDfk; ab];
% end
% %
% 
% wc_avg = mean(wcDfk,1);
% 
% % close al
% figure()
% plot(T,wcDfk);hold on
% plot(T,wc_avg,'k','Linewidth',3);
% xline(0)
% xline(4)
% 
% %%
% aa = mean(ncDfk(:,35:end-35),2);

%%
% nc_var = var(ncDfk(:,35:end-35) - 10);
% wc_var = var(wcDfk(:,35:end-35) - 10);
% 
% 
% close all;
% figure()
% plot(T(35:end-35),nc_var,'r','LineWidth',2);hold on
% plot(T(35:end-35),wc_var,'g','LineWidth',2);
% %%
% 
% close all
% m=9;
% j = wc(m);
% [a i] = min(abs(t - stimStarts(j)));
% [a i2] = min(abs(t - stimEnds(j)));
% 
% [a k] = min(abs(tt - stimStarts(j)));
% [a k2] = min(abs(tt - stimEnds(j)));
% 
% 
% 
% Tin = 0:0.0005:stimDur(j);
% Tout = 0:0.0285:dur;
% close all
% figure()
% subplot(2,2,1)
% plot(Tout,-dFk(i:i+35*dur));hold on
% plot(Tout,5*ones(1,length(Tout)))
% xlim([0,dur])
% title('wc')
% 
% subplot(2,2,3)
% plot(tt(k:k2)-tt(k),v(k:k2))
% xlim([0,dur])
% ylim([0,5])
% %
% % close all
% i=5;
% j = nc(m);
% [a i] = min(abs(t - stimStarts(j)));
% [a i2] = min(abs(t - stimEnds(j)));
% 
% [a k] = min(abs(tt - stimStarts(j)));
% [a k2] = min(abs(tt - stimEnds(j)));
% 
% 
% 
% Tin = 0:0.0005:stimDur(j);
% Tout = 0:0.0285:dur;
% 
% % figure()
% 
% subplot(2,2,2)
% plot(Tout,dFk(i:i+35*dur));hold on
% plot(Tout,-10*ones(1,length(Tout)))
% xlim([0,dur])
% title('nc')
% 
% subplot(2,2,4)
% plot(tt(k:k2)-tt(k),v(k:k2))
% xlim([0,dur])
% ylim([0,5])
% 
% %% var analysis
% 
% % nc_var = var(ncDfk - nc_avg);
% % wc_var = var(wcDfk - wc_avg);
% 
% 
% nc_var = var(ncDfk);
% wc_var = var(wcDfk);
% % nc_var = mean(ncDfk);
% % wc_var = mean(wcDfk);
% 
% 
% close all;
% figure()
% plot(T,nc_var,'r','LineWidth',2);hold on
% plot(T,wc_var,'g','LineWidth',2);
% xline(0,'LineWidth',1.5)
% xline(dur,'LineWidth',1.5)
% ylim([-2,12])
% legend('Feedforward', 'Feedback')
% title('Variance Comparision')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas
% % hgexport(gcf,'images/comp_var.pdf',figure_property); %Set desired file name
% %% Tracking error
% 
% % nc_var = var(ncDfk - nc_avg);
% % wc_var = var(wcDfk - wc_avg);
% 
% 
% nc_er = mean(ncDfk)+5;
% wc_er = mean(wcDfk)+5;
% % nc_var = mean(ncDfk);
% % wc_var = mean(wcDfk);
% 
% 
% close all;
% figure()
% plot(T,nc_er,'r','LineWidth',2);hold on
% plot(T,wc_er,'g','LineWidth',2);
% plot(T,0*ones(1,length(T)),'--k','Linewidth',3);hold on
% xline(0,'LineWidth',1.5)
% xline(dur,'LineWidth',1.5)
% ylim([-2,12])
% legend('Feedforward', 'Feedback')
% title('Average Error')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas
% % hgexport(gcf,'images/comp_error.pdf',figure_property); %Set desired file name
% %%
% %%%%%%%%%%%%%%%%%%%%%%
% close all;
% figure(1)
% subplot(1,2,1)
% plot(T,nc_var,'r','LineWidth',2);hold on
% plot(T,wc_var,'g','LineWidth',2);
% xline(0,'LineWidth',1.5)
% xline(dur,'LineWidth',1.5)
% ylim([-2,12])
% % legend('Feedforward', 'Feedback')
% title('Variance Comparision')
% subplot(1,2,2)
% plot(T,nc_er,'r','LineWidth',2);hold on
% plot(T,wc_er,'g','LineWidth',2);
% plot(T,0*ones(1,length(T)),'--k','Linewidth',3);hold on
% xline(0,'LineWidth',1.5)
% xline(dur,'LineWidth',1.5)
% ylim([-2,12])
% legend('Feedforward', 'Feedback')
% title('Average Error')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas
% % hgexport(gcf,'images/comp_var_error.pdf',figure_property); %Set desired file name
% % exportgraphics(figure(1), 'comp.pdf',figure_property);
% %%%%%%%%%%%%%%%%%%%%%%%%
% %%
% k = 10;
% sw = size(wcDfk)
% sn = size(ncDfk)
% iwc = randperm(sw(1),10);
% inc = randperm(sn(1),10);
% 
% nc_interval = mean(ncDfk(inc,35:35+4*35)+5);
% wc_interval = mean(wcDfk(iwc,35:35+4*35)+5);
% 
% T_interval = 0:0.0285:dur;
% 
% close all;
% figure()
% plot(T_interval,nc_interval,'r','LineWidth',2);hold on
% plot(T_interval,wc_interval,'g','LineWidth',2);
% plot(T_interval,nc_er(35:35+dur*35),'--r','LineWidth',3);hold on
% plot(T_interval,wc_er(35:35+dur*35),'--g','LineWidth',3);
% plot(T_interval,0*ones(1,length(T_interval)),'--k','Linewidth',3);hold on
% xline(0,'LineWidth',3)
% xline(dur,'LineWidth',3)
% legend('no control', 'controlled')
% title('average error over intervals')
% 
% 
% wc_dev = norm(wc_er(35:35+dur*35) - wc_interval)
% nc_dev = norm(nc_er(35:35+dur*35) - nc_interval)
% 
% %%
% 
% sw = size(wcDfk)
% sn = size(ncDfk)
% T_interval = 0:0.0285:dur;
% 
% 
% Wc_dev=[];
% Nc_dev=[];
% ti = 0:4:60
% figure()
% for i=0:2:60 
% nc_dev=[];
% wc_dev=[];
%     for j=1:20
% i
% 
% 
% iwc = randperm(sw(1),i);
% inc = randperm(sn(1),i);
% 
% nc_interval = mean(ncDfk(inc,35:35+dur*35)+5);
% wc_interval = mean(wcDfk(iwc,35:35+dur*35)+5);
% 
% 
% wc_dev = [wc_dev, norm(wc_er(35:35+dur*35) - wc_interval)];
% nc_dev = [nc_dev, norm(nc_er(35:35+dur*35) - nc_interval)];
%     end
% 
% plot(i,mean(nc_dev),'ro');hold on
% plot(i,mean(wc_dev),'go')
% end
% legend('no control','control')
% ylabel('MSE')
% xlabel('trials')
% title('MSE deviation from true average')
% 
% 
% %%
% close all
% m=9;
% j = wc(m);
% [a i] = min(abs(t - stimStarts(j)));
% [a i2] = min(abs(t - stimEnds(j)));
% 
% [a k] = min(abs(tt - stimStarts(j)));
% [a k2] = min(abs(tt - stimEnds(j)));
% 
% 
% 
% Tin = 0:0.0005:stimDur(j);
% Tout = 0:0.0285:dur;
% close all
% figure()
% subplot(2,1,1)
% plot(Tout,-dFk(i:i+35*dur));hold on
% plot(Tout,5*ones(1,length(Tout)))
% xlim([0,dur])
% title('wc')
% 
% subplot(2,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2))
% xlim([0,dur])
% ylim([0,5])

%% Controlability test
% pncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - stimStarts(nc(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
% 
%     pncDfk = [pncDfk; dFk(i-35*5:i+35*(dur+1))];
% end



pwcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - stimStarts(wc(j))));

    % [a i2] = min(abs(t - stimEnds(nc_ref(j))));

    pwcDfk = [pwcDfk; dFk(i-35*5:i+35*(dur+1))];
end

% marker


%%
close all;
Tout = 0:0.0285:dur;
% dur=4;
% er_ncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - stimStarts(nc(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
% 
%     er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
% end



er_wcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - stimStarts(wc(j))));

    % [a i2] = min(abs(t - stimEnds(nc_ref(j))));

    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
end



%
figure()
% plot(er_ncDfk,'or');hold on;
plot(er_wcDfk,'og');

% p_ncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - stimStarts(nc(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
% 
%     p_ncDfk = [p_ncDfk; norm(dFk(i:i+35*(dur))+5)];
% end



p_wcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - stimStarts(wc(j))));

    % [a i2] = min(abs(t - stimEnds(nc_ref(j))));

    p_wcDfk = [p_wcDfk; norm(dFk(i:i+35*(dur))+5)];
end

%%
close all;

a1 = find(er_wcDfk > 40);
a2 = find(er_wcDfk < 20);


i=5

subplot(1,2,1)
plot(pwcDfk(a1(i),:)');hold on;
xline(35*5)
xline(35*8)
yline(0)
yline(-5)
ylim([-15,15])
title('uncontrollable')


subplot(1,2,2)
plot(pwcDfk(a2(i),:)');hold on;
xline(35*5)
xline(35*8)
yline(0)
yline(-5)
ylim([-15,15])
title('controllable')





%%
close all;
figure()
subplot(1,2,1)
spectrogram(pwcDfk(a1(i),:),'yaxis')
subplot(1,2,2)
spectrogram(pwcDfk(a2(i),:),'yaxis')

s = spectrogram(pwcDfk(a1(i),:),'yaxis')

%%
close all;
Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
L = 70;             % Length of signal
% t = (0:L-1)*T;        % Time vector

% S = 0.8 + 0.7*sin(2*pi*50*t) + sin(2*pi*120*t);
% X = S + 2*randn(size(t));
w = 100000;
X = dFk(w:w+L);
Y = fft(X);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs/L*(0:(L/2));

figure()
plot(f,P1,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of S(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")


%%
N = 71

Fs = 35;            % Sampling frequency                  nc  
T = 1/Fs;             % Sampling period       
L = 70;             % Length of signal
ti = (0:L-1)*T;        % Time vector

% S = 0.8 + 0.7*sin(2*pi*50*t) + sin(2*pi*120*t);
% X = S + 2*randn(size(t));
w = 100000;
X = dFk(w:w+L);
Y = fft(X);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs/L*(0:(L/2));

fft1=zeros(1,L);
fft2=zeros(1,L);
fft3=zeros(1,L);
fft4=zeros(1,L);
for i = N:length(dFk)
    Y = fft(dFk((i-L):i));
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    


    % fft1 = [fft1,sum(P1(1:7))/sum(P1)];
    % fft2 = [fft2,sum(P1(8:13))/sum(P1)];
    % fft3 = [fft3,sum(P1(1:13))/sum(P1)];


    fft1 = [fft1,sum(P1(1:7))];
    fft2 = [fft2,sum(P1(8:13))];
    fft3 = [fft3,sum(P1(1:13))];
    fft4 = [fft4,sum(P1(14:end))];
end



%%
close all;

a1 = find(er_wcDfk > 37);
a2 = find(er_wcDfk < 20);
%%

i=5
m1=a1(i);
j1 = wc(m1);

m2=a2(i);
j2 = wc(m2);

[a k1] = min(abs(t - stimStarts(j1)));

[a k2] = min(abs(t - stimStarts(j2)));
k1
k2

%


Tp = -5:0.0285:dur+1;
close all
figure()
subplot(2,2,1)
plot(pwcDfk(a1(i),:)');hold on;
xline(35*5)
xline(35*8)
yline(0)
yline(-5)
ylim([-15,15])
title('uncontrollable')

subplot(2,2,3)
plot(fft1((k1-35*5):(k1+35*(dur+1))));hold on
plot(fft2((k1-35*5):(k1+35*(dur+1))));hold on
plot(fft3((k1-35*5):(k1+35*(dur+1))));hold on
plot(fft4((k1-35*5):(k1+35*(dur+1))));hold on
xline(35*5)
xline(35*8)
ylim([0,30])
legend('0-3Hz','3-6Hz','0-6Hz','6Hz+')
title('uncontrollable')


subplot(2,2,2)
plot(pwcDfk(a2(i),:)');hold on;
xline(35*5)
xline(35*8)
yline(0)
yline(-5)
ylim([-15,15])
title('controllable')

subplot(2,2,4)
plot(fft1((k2-35*5):(k2+35*(dur+1))));hold on
plot(fft2((k2-35*5):(k2+35*(dur+1))));hold on
plot(fft3((k2-35*5):(k2+35*(dur+1))));hold on
plot(fft4((k2-35*5):(k2+35*(dur+1))));hold on
xline(35*5)
xline(35*8)
ylim([0,30])
legend('0-3Hz','3-6Hz','0-6Hz','6Hz+')
title('controllable')



%% Sort error vs low power 
wc_pval1=[];
nc_pval1=[];

wc_pval2=[];
nc_pval2=[];

wc_pval3=[];
nc_pval3=[];

wc_pval4=[];
nc_pval4=[];

for i=1:length(wc)
    j =wc(i);
    [a k] = min(abs(t - stimStarts(j)));
    wc_pval1 = [wc_pval1; sum(fft1(k - 35*5:k))];
    wc_pval2 = [wc_pval2; sum(fft2(k - 35*5:k))];
    wc_pval3 = [wc_pval3; sum(fft3(k - 35*5:k))];
    wc_pval4 = [wc_pval4; sum(fft4(k - 35*5:k))];
end

for i=1:length(nc)
    j =nc(i);
    [a k] = min(abs(t - stimStarts(j)));
    nc_pval1 = [nc_pval1; sum(fft1(k - 35*5:k))];
    nc_pval2 = [nc_pval2; sum(fft2(k - 35*5:k))];
    nc_pval3 = [nc_pval3; sum(fft3(k - 35*5:k))];
    nc_pval4 = [nc_pval4; sum(fft4(k - 35*5:k))];
end

%
close all
figure()
subplot(2,2,1)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval1,'go','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,5000])
xlim([0,100])


subplot(2,2,2)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval2,'ko','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,1500])
xlim([0,100])


subplot(2,2,3)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval3,'ro','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,5000])
xlim([0,100])


subplot(2,2,4)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval4,'bo','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,1500])
xlim([0,100])
