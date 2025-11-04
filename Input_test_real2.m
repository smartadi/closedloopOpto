clear all;
close all;
clc;
% dt = 1/35;
dt = 0.0285;
t = 0:dt:dt*1000;

% nimbus
% path = "/run/user/1000/gvfs/smb-share:server=sahale.biostr.washington.edu,share=data/Subjects/ZYE_0069/2023-10-03/";

% input test
path = "/run/user/1000/gvfs/smb-share:server=sahale.biostr.washington.edu,share=data/Subjects/AB_0032/2024-06-25/";

% path = "/run/user/1001/gvfs/smb-share:server=sahale.biostr.washington.edu,share=data/Subjects/ZYE_0069/2023-10-03/1";

vpath = '1/corr/svdTemporalComponents_corr.npy';
upath = '1/blue/svdSpatialComponents.npy';
fpath = '1/face_proc.mat';

% upath = '/corr/svdSpatialComponents_ortho.npy';
upath = append(path,upath);
% vpath = '/corr/svdTemporalComponents_ortho.npy';
vpath = append(path,vpath);
fpath = append(path,fpath);





Uu = readNPY(upath);
Vv1 = readNPY(vpath)';
fproc = load(fpath);
%%

[TT,dims]= size(Vv1);

Vv = Vv1./vecnorm(Vv1,2,1);

disp('loading WF PCA projections')

data1=Vv';
N=10000;
%%
l=10;
ll=500;
S = Vv1(1:ll,1:20000)' ;
%%


param_path = '2/2024-06-25_2_AB_0032_Block.mat';
param_path = append(path,param_path);
i_path = '1/lightCommand.raw.npy'
i_path = append(path,i_path);
input = readNPY(i_path);
a= load(param_path)
tr_path = '1/lightCommand.timestamps_Timeline.npy';
tr_path = append(path,tr_path);
tr = readNPY(tr_path);

exp_path = '1/expStartStop.raw.npy';
expt_path = '1/expStartStop.timestamps_Timeline.npy';


exp_path = append(path,exp_path);
expt_path = append(path,expt_path);

exp = readNPY(exp_path);
expt = readNPY(expt_path);



% vpath = '1/corr/svdTemporalComponents_corr.npy';
% vpath = append(path,vpath);
% 
vtpath = '1/corr/svdTemporalComponents_corr.timestamps.npy';
vtpath = append(path,vtpath);

Vt = readNPY(vtpath);

tpath = '1/frameTimes.timestamps.npy'; 
tpath = append(path,tpath);
tt = readNPY(tpath);



%%
% F=0;
% F2=0;
% F3=0;
% t0=10000;
% T=5000;
% for t = t0:t0+T
% 
% Im =  reshape(Uu(:,1:500)*Vv1(1:500,t),560,560);    
% 
% % filtered low rank
% 
% 
% f=0;
% f2=0;
% f3=0;
% 
% 
% for i = -1:1:1
%     for j = -1:1:1
%         f = f + Im(P(1)+i,P(2)+j)/50;
%         f2 = f2 + Im(P2(1)+i,P2(2)+j)/50;
%         f3 = f3 + Im(P3(1)+i,P3(2)+j)/50;
% 
% 
%     end
% end
% F=[F,f];
% F2=[F2,f2];
% F3=[F3,f3];
% 
% end
% F = F/1e3;
% F2 = F2/1e3;
% F3 = F3/1e3;
% 
% %%
% %
% fs=35
% 
% 
% figure()
% plot(F)
% 
% % Spectrum on pixel
% figure()
% pspectrum(F,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
%     'MinThreshold',-50,'FrequencyLimits',[0, 10]);
% 
% figure()
% fsst(F,fs,'yaxis')
% 
% 
% %
% figure()
% plot(F2)
% 
% % Spectrum on pixel
% figure()
% pspectrum(F2,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
%     'MinThreshold',-50,'FrequencyLimits',[0, 10]);
% 
% figure()
% fsst(F2,fs,'yaxis')
% 
% %%
% F_short = F(1:500);
% F_short2 = F2(1:500);
% F_short3 = F3(1:500);
% %%
% close all;
% 
% 
% figure()
% pspectrum(F_short,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[1, 10]);
% 
% 
% figure()
% fsst(F_short,fs,'yaxis')
% 
% 
% figure()
% pspectrum(F_short2,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[1, 10]);
% 
% 
% figure()
% fsst(F_short2,fs,'yaxis')
% %%
% 
% [a,b,c] = pspectrum(F_short,fs,'persistence','Leakage',1,'OverlapPercent',99, ...
%     'MinThreshold',0,'FrequencyLimits',[1, 10]);
% 
% 
% %% Moving Variance
% close all;
% figure()
% plot(F_short)
% 
% 
% figure()
% fsst(F_short,fs,'yaxis')
% 
% 
% figure()
% plot(F_short2)
% 
% 
% figure()
% fsst(F_short2,fs,'yaxis')
% 
% 
% 
% figure()
% plot(F_short3)
% 
% 
% figure()
% fsst(F_short3,fs,'yaxis')
% 
% %%
% close all;
% 
% 
% figure()
% pspectrum(F_short,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[2, 10]);
% 
% 
% figure()
% plot(F_short)
% 
% 
% figure()
% pspectrum(F_short2,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[2, 10]);
% 
% 
% figure()
% plot(F_short2)
% 
% figure()
% pspectrum(F_short3,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[2, 10]);
% 
% %%
% close all;
% 
% 
% figure()
% plot(F_short3)
% 
% figure()
% subplot(3,1,1)
% pspectrum(F_short,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[1, 10]);
% subplot(3,1,2)
% pspectrum(F_short2,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[1, 10]);
% subplot(3,1,3)
% pspectrum(F_short3,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
%     'MinThreshold',-100,'FrequencyLimits',[1, 10]);
% 
% 
% figure()
% subplot(3,1,1)
% plot(F_short)
% subplot(3,1,2)
% plot(F_short2)
% subplot(3,1,3)
% plot(F_short3)
% %%
% 
% close all;
% NN=100;
% 
% x = zeros(1,NN);
% 
% 
% %for i=NN:length(F)
% covX=zeros(1,NN-1);
% %for i=NN:100
% 
% 
% for i=NN:length(F)
% %for i=NN
%     x = F(i+1-NN:i)*10;
%     covX = [covX,(cov(x))];
% end
% 
% 
% %
% 
% figure()
% plot(covX,'r','LineWidth',2);hold on
% plot(F,'k','LineWidth',2);hold on
% 
% 
% 
% figure()
% plot(covX(1:1500),'r','LineWidth',2);hold on
% plot(F(1:1500),'k','LineWidth',2);hold on
% %%
% 
% close all;
% NN=100;
% 
% x1 = zeros(1,NN);
% x2 = zeros(1,NN);
% x3 = zeros(1,NN);
% 
% 
% %for i=NN:length(F)
% covX1=zeros(1,NN-1);
% covX2=zeros(1,NN-1);
% covX3=zeros(1,NN-1);
% %for i=NN:100
% 
% 
% for i=NN:length(F)
% %for i=NN
%     x1 = F(i+1-NN:i)*1;
%     covX1 = [covX1,(cov(x1))];
% 
%     x2 = F2(i+1-NN:i)*1;
%     covX2 = [covX2,(cov(x2))];
% 
%     x3 = F3(i+1-NN:i)*1;
%     covX3 = [covX3,(cov(x3))];
% end
% 
% 
% %
% 
% figure()
% plot(covX1,'r','LineWidth',2);hold on
% plot(F,'k','LineWidth',0.5);hold on
% plot(covX2,'g','LineWidth',2);hold on
% % plot(F,'k','LineWidth',2);hold on
% plot(covX3,'b','LineWidth',2);hold on
% % plot(F,'k','LineWidth',2);hold on
% 
% 
% 
% figure()
% plot(F(1:1500),'k','LineWidth',0.5);hold on
% plot(covX1(1:1500),'r','LineWidth',2);hold on
% plot(covX2(1:1500),'g','LineWidth',2);hold on
% plot(covX3(1:1500),'b','LineWidth',2);hold on
% title('pixel covariance')
% legend('pixel signal1','cov1','cov2','cov3')
% 
% %% Covariance, integral, fft test
% tt = 0:1/35:1/35*(length(F)-1);
% 
% L=50;
% yc=[];
% yi=[];
% yf=[];
% 
% yc2=[];
% yi2=[];
% yf2=[];
% 
% yc3=[];
% yi3=[];
% yf3=[];
% 
% 
% for i=1: length(F)-L
%     x = F(i:i+L);
%     yc=[yc,cov(x)];
%     yi=[yi,sum(x)/L];
%     yf=[yf,sum(abs(fft(x)))/(2*L)];
% 
%     x2 = F2(i:i+L);
%     yc2=[yc2,cov(x2)];
%     yi2=[yi2,sum(x2)/L];
%     yf2=[yf2,sum(abs(fft(x2)))/(2*L)];
% 
%     x3 = F3(i:i+L);
%     yc3=[yc3,cov(x3)];
%     yi3=[yi3,sum(x3)/L];
%     yf3=[yf3,sum(abs(fft(x3)))/(2*L)];
% end
% 
% yc=[zeros(1,L),yc];
% yi=[zeros(1,L),yi];
% yf=[zeros(1,L),yf];
% 
% yc2=[zeros(1,L),yc2];
% yi2=[zeros(1,L),yi2];
% yf2=[zeros(1,L),yf2];
% 
% yc3=[zeros(1,L),yc3];
% yi3=[zeros(1,L),yi3];
% yf3=[zeros(1,L),yf3];
% 
% 
% figure()
% plot(tt,F,'LineWidth',2);hold on;
% plot(tt,yf,'LineWidth',2);hold on;
% plot(tt,yc,'LineWidth',2);hold on;
% plot(tt,yi,'LineWidth',2);hold on;
% legend('signal','fft','covariance','integral')
% xlabel('time')
% title('attention state from pixel readings')
% 
% %%
% close all
% figure()
% subplot(3,1,1)
% plot(tt(1:500),F(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yf(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yc(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yi(1:500),'LineWidth',2);hold on;
% ylim([-0.7 0.7])
% legend('signal','fft','covariance','integral')
% ylabel('Pix1')
% title('attention state from pixel readings')
% 
% 
% subplot(3,1,2)
% plot(tt(1:500),F2(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yf2(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yc2(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yi2(1:500),'LineWidth',2);hold on;
% ylim([-0.7 0.7])
% ylabel('Pix2')
% % legend('signal','fft','covariance','integral')
% % xlabel('time')
% % title('attention state from pixel readings')
% 
% 
% subplot(3,1,3)
% plot(tt(1:500),F3(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yf3(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yc3(1:500),'LineWidth',2);hold on;
% plot(tt(1:500),yi3(1:500),'LineWidth',2);hold on;
% ylim([-0.7 0.7])
% % legend('signal','fft','covariance','integral')
% xlabel('time(s)')
% ylabel('Pix3')
% % title('attention state from pixel readings')

%% ABC
te = a.block.events;
tp = a.block.paramsValues;
tpt = a.block.paramsTimes;

frames = tr(2,1) - tr(1,1);

total_time = tr(2,2) - tr(1,2);

t_series = tr(1,2):total_time/frames:tr(2,2);
% events = vertcat(tp.trialType);

%%
figure()
plot(t_series,input)
%%

vtp = Vt(1:end-1);
vtm = Vt(2:end);

Vdt = vtm-vtp;

%
figure()
plot(Vdt(1:100))


%% input interp

input_interp = interp1(t_series,input,Vt);
%%
figure()
plot(Vt(10000:12000),input_interp(10000:12000));hold on;
plot(Vt(10000:12000),Vv1(1:5,10000:12000))

%% pixel analysis

uu= reshape(Uu,560*560,2000);
i=10000;
Im =  reshape(uu(:,1:500)*Vv1(:,i),560,560);

%rank 10
Im3 =  reshape(uu(:,1:5)*Vv1(1:5,i),560,560);


%
P=[225,425];
P2=[240,125];
P3=[350,325];
close all;
figure()
image(Im);hold on;
plot(P(1),P(2),'ro')
plot(P2(1),P2(2),'ko')
plot(P3(1),P3(2),'ko')
colorbar
%%
close all


figure()
image(Im3);
colorbar

J = imadjust(Im3);

figure()
imshow(J);hold on;
plot(P(1),P(2),'ro')
colorbar
%%


F=0;
F2 = 0;
F3 = 0;
t0 = 1;
T = 1000;
% for t = t0:t0+T
for t = 1:length(Vv1)

Im =  reshape(uu(:,1:500)*Vv1(1:500,t),560,560);    
t
% filtered low rank


f=0;
f2=0;
f3=0;


for i = -1:1:1
    for j = -1:1:1
        f = f + Im(P(1)+i,P(2)+j)/50;
        f2 = f2 + Im(P2(1)+i,P2(2)+j)/50;
        f3 = f3 + Im(P3(1)+i,P3(2)+j)/50;


    end
end
F=[F,f];
F2=[F2,f2];
F3=[F3,f3];

end
F = F/1e3;
F2 = F2/1e3;
F3 = F3/1e3;



close all;
NN=100;

x = zeros(1,NN);


%for i=NN:length(F)
covX=zeros(1,NN-1);
%for i=NN:100


for i=NN:length(F)
%for i=NN
    x = F(i+1-NN:i)*10;
    covX = [covX,(cov(x))];
end


%

figure()
plot(covX,'r','LineWidth',2);hold on
plot(F,'k','LineWidth',2);hold on



figure()
plot(covX(1:500),'r','LineWidth',2);hold on
plot(F(1:500),'k','LineWidth',2);hold on
%%

close all;
NN=100;

x1 = zeros(1,NN);
x2 = zeros(1,NN);
x3 = zeros(1,NN);


%for i=NN:length(F)
covX1=zeros(1,NN-1);
covX2=zeros(1,NN-1);
covX3=zeros(1,NN-1);
%for i=NN:100


for i=NN:length(F)
%for i=NN
    x1 = F(i+1-NN:i)*1;
    covX1 = [covX1,(cov(x1))];

    x2 = F2(i+1-NN:i)*1;
    covX2 = [covX2,(cov(x2))];

    x3 = F3(i+1-NN:i)*1;
    covX3 = [covX3,(cov(x3))];
end


%

figure()
plot(covX1,'r','LineWidth',2);hold on
plot(F,'k','LineWidth',0.5);hold on
plot(covX2,'g','LineWidth',2);hold on
% plot(F,'k','LineWidth',2);hold on
plot(covX3,'b','LineWidth',2);hold on
% plot(F,'k','LineWidth',2);hold on



figure()
plot(F(1:500),'k','LineWidth',0.5);hold on
plot(covX1(1:500),'r','LineWidth',2);hold on
plot(covX2(1:500),'g','LineWidth',2);hold on
plot(covX3(1:500),'b','LineWidth',2);hold on
title('pixel covariance')
legend('pixel signal1','cov1','cov2','cov3')

%% Covariance, integral, fft test
tt = 0:1/35:1/35*(length(F)-1);

L=50;
yc=[];
yi=[];
yf=[];

yc2=[];
yi2=[];
yf2=[];

yc3=[];
yi3=[];
yf3=[];


for i=1: length(F)-L
    x = F(i:i+L);
    yc=[yc,cov(x)];
    yi=[yi,sum(x)/L];
    yf=[yf,sum(abs(fft(x)))/(2*L)];

    x2 = F2(i:i+L);
    yc2=[yc2,cov(x2)];
    yi2=[yi2,sum(x2)/L];
    yf2=[yf2,sum(abs(fft(x2)))/(2*L)];

    x3 = F3(i:i+L);
    yc3=[yc3,cov(x3)];
    yi3=[yi3,sum(x3)/L];
    yf3=[yf3,sum(abs(fft(x3)))/(2*L)];
end

yc=[zeros(1,L),yc];
yi=[zeros(1,L),yi];
yf=[zeros(1,L),yf];

yc2=[zeros(1,L),yc2];
yi2=[zeros(1,L),yi2];
yf2=[zeros(1,L),yf2];

yc3=[zeros(1,L),yc3];
yi3=[zeros(1,L),yi3];
yf3=[zeros(1,L),yf3];


figure()
plot(tt,F,'LineWidth',2);hold on;
plot(tt,yf,'LineWidth',2);hold on;
plot(tt,yc,'LineWidth',2);hold on;
plot(tt,yi,'LineWidth',2);hold on;
legend('signal','fft','covariance','integral')
xlabel('time')
title('attention state from pixel readings')

%%
close all
figure()
subplot(3,1,1)
plot(tt(1:500),F(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yf(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yc(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yi(1:500),'LineWidth',2);hold on;
ylim([-0.7 0.7])
legend('signal','fft','covariance','integral')
ylabel('Pix1')
title('attention state from pixel readings')


subplot(3,1,2)
plot(tt(1:500),F2(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yf2(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yc2(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yi2(1:500),'LineWidth',2);hold on;
ylim([-0.7 0.7])
ylabel('Pix2')
% legend('signal','fft','covariance','integral')
% xlabel('time')
% title('attention state from pixel readings')


subplot(3,1,3)
plot(tt(1:500),F3(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yf3(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yc3(1:500),'LineWidth',2);hold on;
plot(tt(1:500),yi3(1:500),'LineWidth',2);hold on;
ylim([-0.7 0.7])
% legend('signal','fft','covariance','integral')
xlabel('time(s)')
ylabel('Pix3')
% title('attention state from pixel readings')

%%
close all;
figure()
hold on
plot(Vt(1:500),input_interp(1:500),'y');hold on
plot(Vt(1:500),F(1,1:500),'r');
plot(Vt(1:500),yf(1,1:500),'b');
plot(Vt(1:500),yi(1,1:500),'g');
plot(Vt(1:500),yc(1,1:500),'k');
legend('input','pixel','fft','integral','cov')
%%
save("inp_var.mat")

%%
t0= 10000
T = 1000
figure()
plot(tt(t0:t0+T),F(t0:t0+T));hold on
plot(tt(t0:t0+T),F2(t0:t0+T));hold on
plot(tt(t0:t0+T),F3(t0:t0+T));hold on

%%
figure()
plot(t_series,exp)

%% 
onpath = "1/laserOnTimes.npy"
offpath = "1/laserOffTimes.npy"

onpath = append(path,onpath);
on = readNPY(onpath);

offpath = append(path,offpath);
off = readNPY(offpath);

figure()
plot(on);hold on
plot(off)
%%
tdiff2 = off-on;
tdiff = vertcat(a.block.paramsValues.laserDur);
%
figure()
plot(tdiff);hold on
plot(tdiff2)
plot(tdiff2-tdiff)
%%
figure()
plot(t_series,input)

%%
%
figure()
plot(tdiff2)
%%
i=0
th=0
while th<0.1
    i=i+1;
    th = exp(i);
end
j=i
while th >0.1
    j=j+1;
    th = exp(j);
end

%%
figure()
plot(t_series(i:j), input(i:j))

%%  exp slice
istart = a.block.events.newTrialTimes;
istop = a.block.events.endTrialTimes;

e1 = t_series(i)  
e2 = t_series(i) +istop(1) - istart(1)

%%
ind = interp1(t_series,1:length(t_series),e2,'nearest');

%%
figure()
plot(t_series(i:ind),input(i:ind))

exp_start = a.block.events.expStartTimes
exp_stop = a.block.events.expStopTimes


%%
ea = t_series(i) + istart(2) - istart(1);
eb = t_series(i) + istop(2) - istart(1);

inda = interp1(t_series,1:length(t_series),ea,'nearest');
indb = interp1(t_series,1:length(t_series),eb,'nearest');


figure()
plot(t_series(inda:indb),input(inda:indb))

%%
%%
ea = t_series(i) + istart(3) - istart(1);
eb = t_series(i) + istop(3) - istart(1);

inda = interp1(t_series,1:length(t_series),ea,'nearest');
indb = interp1(t_series,1:length(t_series),eb,'nearest');


figure()
plot(t_series(inda:indb),input(inda:indb))


%%

load(append(path+'1/2024-06-25_1_AB_0032_Timeline.mat'));
%% TODO
% in WF frequency, find the start times for lasers, log it against the
% laser duration


%% FFT analysis:

afft = abs(fft(x3))

L=51
Fs=35

figure()
plot(Fs/L*(0:L-1),afft,"LineWidth",3)
title("Complex Magnitude of fft Spectrum")
xlabel("f (Hz)")
ylabel("|fft(X)|")

%%

fs=35

figure()
plot(x)

figure()
subplot(3,1,1)
pspectrum(x,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 17]);
subplot(3,1,2)
pspectrum(x2,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 17]);
subplot(3,1,3)
pspectrum(x3,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 17]);


figure()
subplot(3,1,1)
plot(x)
subplot(3,1,2)
plot(x2)
subplot(3,1,3)
plot(x3)

%%
close all
[p,f] = pspectrum(x);
[p2,f2] = pspectrum(x2);
[p3,f3] = pspectrum(x3);

plot(f,p);hold on;
plot(f2,p2);hold on;
plot(f3,p3);hold on;
%%
L = 51
Y = fft(x);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = Fs/L*(0:(L/2));
plot(f,P1,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of S(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")