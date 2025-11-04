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

%% experiment name
mn = 'AL_0033'; td = '2024-12-23'; 
en = 1;

serverRoot = expPath(mn, td, en);

d = loadData(serverRoot,mn,td,en);

%% Stim Times

d = findStims(d);


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

offsetx = 0;
offsety = -75;

px = [200,300,150,200,300,350,100,200,300,400,100,200,300,400];%+offsetx;
py = [150,150,225,225,225,225,325,325,325,325,425,425,425,425];%+offsety;
px=[];
py=[];

frame= double([px,d.params.pixel(1);py,d.params.pixel(1)]) + [offsetx;offsety]



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

d.params.pixel = frame';


%% Load or save from image data

data = getpixel_dFoF(d);
% 
% dFk = data.dFk;

% data = getpixels_dFoF(d);

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

t = d.timeBlue;
close all
j=23;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));
figure()
plot(t(i-35:i+35*4),dFk(i-35:i+35*4))
xline(t(i))
xline(t(i2))


%% Feedforard vs Feedback 

data = controllerData(data,d);


%% Plots for interleaved trials, 1 = save as pdf
analysisPlots(data,d,0);

%% plots
dur = d.params.dur;
% ncDfk = data.ncDfk;
wcDfk = data.wcDfk;
% nc_avg = mean(ncDfk,1);
wc_avg = mean(wcDfk,1);
T= -1:0.0285:(dur+1);
Tin = 0:0.0005:dur;
Tout = 0:0.0285:dur;

k = figure()

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

% %% Grid Experiment
% dur = d.params.dur;
% % gc = find(d.input_params(:,3)==2);
% 
% 
% 
% [C,ia,ic] = unique(d.input_params(:,5:6),'rows')
% 
% J_val =zeros(length(C),1);
% 
% for j =1:length(ic)
%     k = numel(find(ic==ic(j)));
%     % [a i] = min(abs(t - d.stimStarts(j)));
%     i = d.input_params(j,2)
%     traj = norm(dFk(i:(i+35*(dur)))+5)/k;
%     J_val(ic(j)) = J_val(ic(j)) + traj;
% end
% 
% %
% close all;
% figure()
% plot3(C(:,1),C(:,2),J_val,'or','LineWidth',2)
% xlabel('Kp')
% ylabel('Ki')
% grid on
% %
% f = fit([C(:,1) C(:,2)],J_val,'linearinterp');
% 
% close all;
% figure()
% plot(f,[C(:,1),C(:,2)],J_val)
% colorbar
% xlabel('Kp')
% ylabel('Ki')
% zlabel('MSE')
% title('Cost function J(Kp,Ki)')
% 
% 
% 
% %
% gc = find(d.input_params(:,3)==2);
% tt = d.inpTime;
% v = d.inpVals;
% %
% m=30;
% j = gc(m);
% % [a i] = min(abs(t - d.stimStarts(j)));
% % [a i2] = min(abs(t - d.stimEnds(j)));
% 
% [a k] = min(abs(tt - d.stimStarts(j)));
% [a k2] = min(abs(tt - d.stimEnds(j)));
% 
% i = d.input_params(j,2)
% 
% % Tin = 0:0.0005:stimDur(j);
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
%% Variability analysis

% Classify x0
X0=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));
    X0 = [X0; dFk(i)];
end



%% Controlability test
dur = d.params.dur;
% nc = data.nc;
% pncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - d.stimStarts(nc(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
% 
%     pncDfk = [pncDfk; dFk(i-35*5:i+35*(dur+1))];
% end

wc = data.wc;

pwcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));
    pwcDfk = [pwcDfk; dFk(i-35*5:i+35*(dur+1))];
end

% marker


%%

close all;
Tout = -2:0.0285:dur+1;

ref = [-5*ones(1,3*35+1)];
Tref  = 0:0.0285:dur;


figure()
sgtitle('feedback 1219')
for k = 1:9
    subplot(3,3,k)
    j = randi(length(data.wc));
% j = 11;
% a = wc(j);
% i = d.input_params(a,2) - d.params.horizon;
[a i] = min(abs(t - d.stimStarts(wc(j))));
n = norm(dFk(i:i+35*(dur))+5);
plot(Tref,ref,'--k','LineWidth',2);hold on
plot(Tout,dFk( i - 2*35:(i+35*(dur) + 35) ),'LineWidth',2);hold on;

ylim([-20,20])
xlim([-2,4])
yline(0)
xline(0)
xline(3)
title(append('error = ',num2str(n)))
end

%%
figure()
sgtitle('feedforward 1219')
for k = 1:9
    subplot(3,3,k)
    j = randi(length(data.nc));
% j = 11;
% a = wc(j);
% i = d.input_params(a,2) - d.params.horizon;
[a i] = min(abs(t - d.stimStarts(nc(j))));
n = norm(dFk(i:i+35*(dur))+5);
plot(Tref,ref,'--k','LineWidth',2);hold on
plot(Tout,dFk( i - 2*35:(i+35*(dur) + 35) ),'LineWidth',2);hold on;

ylim([-20,20])
xlim([-2,4])
yline(0)
xline(0)
xline(3)
title(append('error = ',num2str(n)))
end
%%

Tout = 0:0.0285:dur;

% er_ncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - stimStarts(nc(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
% 
%     er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
% end

%%



er_wcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));

    er_wcDfk = [er_wcDfk; norm(dFk(i:i+35*(dur))+5)];
end
% er_ncDfk=[];
% 
% for j = 1: length(nc)
%     [a i] = min(abs(t - d.stimStarts(nc(j))));
% 
%     er_ncDfk = [er_ncDfk; norm(dFk(i:i+35*(dur))+5)];
% end
% p_ncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - d.stimStarts(nc(j))));
% 
%     % [a i2] = min(abs(t - stimEnds(nc_ref(j))));
% 
%     p_ncDfk = [p_ncDfk; norm(dFk(i:i+35*(dur))+5)];
% end



%
figure()
% plot(er_ncDfk,'or','LineWidth',2);hold on;
plot(er_wcDfk,'og','LineWidth',2);
legend('feedforward','feedback')
title('Tracking Error')
ylabel('error')
xlabel('Trial number')


p_wcDfk=[];
for j = 1: length(wc)
    [a i] = min(abs(t - d.stimStarts(wc(j))));
    p_wcDfk = [p_wcDfk; norm(dFk(i:i+35*(dur))+5)];
end

% p_ncDfk=[];
% for j = 1: length(nc)
%     [a i] = min(abs(t - d.stimStarts(nc(j))));
%     p_ncDfk = [p_ncDfk; norm(dFk(i:i+35*(dur))+5)];
% end

%%
close all;

a1 = find(er_wcDfk > 50);
a2 = find(er_wcDfk < 30);

[mm,amax] = max(er_wcDfk);
[mm,amin] = min(er_wcDfk);

% [mm,amaxf] = max(er_ncDfk);
% [mm,aminf] = min(er_ncDfk);


i=3

figure()
subplot(1,2,1)
plot(pwcDfk(amax,:)');hold on;
xline(35*5)
xline(35*8)
yline(0)
yline(-5)
ylim([-15,15])
title(' feedback uncontrollable')

subplot(1,2,2)
plot(pwcDfk(amin,:)');hold on;
xline(35*5)
xline(35*8)
yline(0)
yline(-5)
ylim([-15,15])
title('feedback controllable')

% subplot(2,2,2)
% plot(pncDfk(amaxf,:)');hold on;
% xline(35*5)
% xline(35*8)
% yline(0)
% yline(-5)
% ylim([-15,15])
% title('feedforward uncontrollable')
% 
% 
% subplot(2,2,4)
% plot(pncDfk(aminf,:)');hold on;
% xline(35*5)
% xline(35*8)
% yline(0)
% yline(-5)
% ylim([-15,15])
% title('feedforward controllable')


% 
figure()
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
% N = 36;

Fs = 35;            % Sampling frequency                  nc  
T = 1/Fs;             % Sampling period       
L = 2*35;             % Length of signal
ti = (0:L-1)*T;        % Time vector
N = L+1;
% S = 0.8 + 0.7*sin(2*pi*50*t) + sin(2*pi*120*t);
% X = S + 2*randn(size(t));
w = 5000;
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

%% Running Variance

N1 = 35;
N2 = 2*35;
N3 = 3*35;

Rv1=zeros(1,N1);
Rv2=zeros(1,N2);
Rv3=zeros(1,N3);

for i = N1:length(dFk)
    V = dFk(i-N1+1:i);
    Rv1=[Rv1,var(V)];
end

for i = N2:length(dFk)
    V = dFk(i-N2+1:i);
    Rv2=[Rv2,var(V)];
end

for i = N3:length(dFk)
    V = dFk(i-N3+1:i);
    Rv3=[Rv3,var(V)];
end


%%
close all;

a1 = find(er_wcDfk > 55);
a2 = find(er_wcDfk < 18);

% a1ff = find(er_ncDfk > 40);
% a2ff = find(er_ncDfk < 25);
%%

i=2;
m1=a1(i);
j1 = wc(m1);

m2=a2(i);
j2 = wc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));

[a k2] = min(abs(t - d.stimStarts(j2)));
k1
k2

%
ref = [-5*ones(1,3*35+1)];
Tref  = 0:0.0285:dur;


Tp = -5:0.0285:dur+1;
close all
figure()
subplot(2,2,1)
plot(Tp,pwcDfk(a1(i),:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
ylim([-15,15])
xlim([-5,4])
title('uncontrollable')

subplot(2,2,3)
% plot(Tp,fft1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft2((k1-35*5):(k1+35*(dur+1))));hold on
plot(Tp,fft3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft4((k1-35*5):(k1+35*(dur+1))));hold on
% plot(Tp,Rv1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp,Rv2((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,Rv3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
legend('0-6Hz','var 2s')
title('signal spectral power ')


subplot(2,2,2)
plot(Tp,pwcDfk(a2(i),:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
% yline(-5)
ylim([-15,15])
xlim([-5,4])
title('signal spectral power')

subplot(2,2,4)
% plot(Tp,fft1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft2((k2-35*5):(k2+35*(dur+1))));hold on
plot(Tp,fft3((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft4((k2-35*5):(k2+35*(dur+1))));hold on
% plot(Tp,Rv1((k2-35*5):(k2+35*(dur+1))));hold on
plot(Tp,Rv2((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,Rv3((k2-35*5):(k2+35*(dur+1))));hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
legend('0-6Hz','var 2s')
title('controllable')
%%
i=4;
m1=a1ff(i);
j1 = nc(m1);


m2=a2ff(i);
j2 = nc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));

[a k2] = min(abs(t - d.stimStarts(j2)));
k1
k2

%
ref = [-5*ones(1,3*35+1)];
Tref  = 0:0.0285:dur;


Tp = -5:0.0285:dur+1;
close all
figure()
subplot(2,2,1)
plot(Tp,pncDfk(a1(i),:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
ylim([-15,15])
xlim([-5,4])
title('uncontrollable')

subplot(2,2,3)
% plot(Tp,fft1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft2((k1-35*5):(k1+35*(dur+1))));hold on
plot(Tp,fft3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft4((k1-35*5):(k1+35*(dur+1))));hold on
% plot(Tp,Rv1((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
plot(Tp,Rv2((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,Rv3((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
legend('0-6Hz','var 2s')
title('signal spectral power ')


subplot(2,2,2)
plot(Tp,pncDfk(a2(i),:)','LineWidth',2);hold on;
plot(Tref,ref,'--k','LineWidth',2);hold on
xline(0)
xline(3)
yline(0)
% yline(-5)
ylim([-15,15])
xlim([-5,4])
title('signal spectral power')

subplot(2,2,4)
% plot(Tp,fft1((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft2((k2-35*5):(k2+35*(dur+1))));hold on
plot(Tp,fft3((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,fft4((k2-35*5):(k2+35*(dur+1))));hold on
% plot(Tp,Rv1((k2-35*5):(k2+35*(dur+1))));hold on
plot(Tp,Rv2((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
% plot(Tp,Rv3((k2-35*5):(k2+35*(dur+1))));hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
% legend('0-3Hz','3-6Hz','0-6Hz','6Hz+','var 1s','var 2s','var 3s')
legend('0-6Hz','var 2s')
title('controllable')
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

v_val = []
f_val = []
for i=1:length(data.wc)
    j =wc(i);
    [a k] = min(abs(t - d.stimStarts(j)));
    % wc_pval1 = [wc_pval1; sum(fft1(k - 35*5:k))];
    % wc_pval2 = [wc_pval2; sum(fft2(k - 35*5:k))];
    % wc_pval3 = [wc_pval3; sum(fft3(k - 35*5:k))];
    % wc_pval4 = [wc_pval4; sum(fft4(k - 35*5:k))];
    wc_pval1 = [wc_pval1; sum(fft1(k))];
    wc_pval2 = [wc_pval2; sum(fft2(k))];
    wc_pval3 = [wc_pval3; sum(fft3(k))];
    wc_pval4 = [wc_pval4; sum(fft4(k))];
    v_val = [v_val; Rv2(k)];
    f_val = [f_val; fft3(k)];
end

% for i=1:length(nc)
%     j =nc(i);
%     [a k] = min(abs(t - stimStarts(j)));
%     nc_pval1 = [nc_pval1; sum(fft1(k - 35*5:k))];
%     nc_pval2 = [nc_pval2; sum(fft2(k - 35*5:k))];
%     nc_pval3 = [nc_pval3; sum(fft3(k - 35*5:k))];
%     nc_pval4 = [nc_pval4; sum(fft4(k - 35*5:k))];
% end

%
close all
figure()
subplot(2,2,1)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval1,'go','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,30])
xlim([0,100])


subplot(2,2,2)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval2,'ko','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,10])
xlim([0,100])


subplot(2,2,3)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval3,'ro','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,30])
xlim([0,100])


subplot(2,2,4)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(p_wcDfk,wc_pval4,'bo','Linewidth',2);
xlabel('lf power')
ylabel('integral tracking error')
ylim([0,10])
xlim([0,100])



%%
close all
figure()
subplot(1,2,1)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(v_val,p_wcDfk,'go','Linewidth',2);
xlabel('var')
ylabel('tracking error')
ylim([0,110])
xlim([0,100])


subplot(1,2,2)
% plot(nc_pval,p_ncDfk,'ro','Linewidth',2); hold on
plot(f_val,p_wcDfk,'ko','Linewidth',2);
xlabel('0-6hz power')
ylabel('tracking error')
ylim([0,110])
xlim([0,50])

%% 
v_valf = []
f_valf = []
for i=1:length(data.nc)
    j =nc(i);
    [a k] = min(abs(t - d.stimStarts(j)));
    % wc_pval1 = [wc_pval1; sum(fft1(k - 35*5:k))];
    % wc_pval2 = [wc_pval2; sum(fft2(k - 35*5:k))];
    % wc_pval3 = [wc_pval3; sum(fft3(k - 35*5:k))];
    % wc_pval4 = [wc_pval4; sum(fft4(k - 35*5:k))]
    v_valf = [v_valf; Rv2(k)];
    f_valf = [f_valf; fft3(k)];
end


close all
figure()
subplot(1,2,1)
plot(v_val,p_wcDfk,'go','Linewidth',2);hold on
% plot(p_ncDfk,v_valf,'ro','Linewidth',2);
xlabel('var')
ylabel('tracking error')
legend('feedback','feedforward')

ylim([0,110])
xlim([0,100])


subplot(1,2,2)
plot(f_val,p_wcDfk,'go','Linewidth',2);;hold on
% plot(p_ncDfk,f_valf,'ro','Linewidth',2);
xlabel('0-6hz power')
ylabel('tracking error')
legend('feedback','feedforward')
ylim([0,110])
xlim([0,100])

%%
figure()
plot(p_wcDfk,X0,'go','Linewidth',2);;hold on
% plot(p_ncDfk,f_valf,'ro','Linewidth',2);
ylabel('x0')
xlabel('tracking error')
xlim([0,110])
ylim([-20,20])

%% 

X0a = find(abs(X0)<2.5);
X0b = find(abs(X0)>2.5 & abs(X0)<5);
X0c = find(abs(X0)>5 & abs(X0)<10);
X0d = find(abs(X0)>10);


%%
figure()
plot(p_wcDfk(X0a), X0(X0a),'go','Linewidth',2);hold on
plot(p_wcDfk(X0b), X0(X0b),'ro','Linewidth',2);hold on
plot(p_wcDfk(X0c), X0(X0c),'bo','Linewidth',2);hold on
plot(p_wcDfk(X0d), X0(X0d),'ko','Linewidth',2);hold on

%%
close all
f = fit([X0 v_val],p_wcDfk,"poly23")
plot(f,[X0 v_val],p_wcDfk)


%%
close all;

figure()
plot3(X0,v_val,p_wcDfk,'go','Linewidth',4)
xlabel('x0 (df/F)')
ylabel('variance')
zlabel('Tracking error')
grid on
%
figure()
% s = scatter3(X0,v_val,p_wcDfk,'x0 (df/F)','variance','Tracking Error','filled', ...
%     'ColorVariable','Tracking Error');
% s = scatter3(X0,v_val,p_wcDfk,'filled','ColorVariable',p_wcDfk);
s = scatter3(X0,v_val,p_wcDfk,[],p_wcDfk,'filled');
xlabel('x_0 df/F')
ylabel('variance')
zlabel('Tracking error norm')
colorbar

%%
tbl = readtable('patients.xls');
s = scatter3(tbl,'Systolic','Diastolic','Weight','filled', ...
    'ColorVariable','Diastolic');


%%
pathData = append('pixel',d.td(6:7),d.td(9:10),int2str(d.en),'.mat');

source_dir ='/mnt/data/brain/';
source_dir = append(source_dir,d.mn,'/',d.td,'/',num2str(d.en));
a=dir([source_dir '/*']);
out=size(a,1);

out=out-2;
path = append(source_dir,'/frame-');

F = [];

    k=d.params.kernel;
    display('computing pixel val')
    
    for i=1:2:out
        pathim=append(path,num2str(i-1));
        fileID = fopen(pathim,'r');
        A = fread(fileID,[560,560],'uint16')';
        j=length(d.params.pixel);
        G = mean(A(d.params.pixel(j,2)-k:d.params.pixel(j,2)+k,d.params.pixel(j,1)-k:d.params.pixel(j,1)+k),'all');
        i
        F = [F,G];
        

        

    end
    display('computing df/F')
    w=d.params.horizon-1;
    Fk  = [ones(1,w),F];
    dF=[];
    Fmean=[];
    dFK=[];
    Fkmean=[];

    % for i = 1:length(F)
    %     % Add an LPF filter 
    % 
    % 
    %     Fkmean = [Fkmean,mean(Fk(i:i+w))];
    %     dFk = [dFk,(Fk(i+w)-Fkmean(i))/Fkmean(i)*100];
    % end



%%

