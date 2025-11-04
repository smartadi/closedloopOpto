clear all;
close all;
clc;
% dt = 1/35;
dt = 0.0285;
t = 0:dt:dt*1000;

% nimbus
path = "/run/user/1000/gvfs/smb-share:server=sahale.biostr.washington.edu,share=data/Subjects/ZYE_0069/2023-10-03/1";

% path = "/run/user/1001/gvfs/smb-share:server=sahale.biostr.washington.edu,share=data/Subjects/ZYE_0069/2023-10-03/1";
upath = '/corr/svdSpatialComponents_ortho.npy';
upath = append(path,upath);
vpath = '/corr/svdTemporalComponents_ortho.npy';
vpath = append(path,vpath);

Uu = readNPY(upath);
Vv1 = readNPY(vpath);

[TT,dims]= size(Vv1);

Vv = Vv1./vecnorm(Vv1,2,1);

disp('loading WF PCA projections')

data1=Vv';
N=10000;

l=10;
ll=500;
S = Vv1(1:ll,1:50000)' ;

%%  pixel specific
% time

i=1000;
Im =  reshape(Uu*Vv1(:,i),560,560);

%rank 10
Im3 =  reshape(Uu(:,1:5)*Vv1(1:5,i),560,560);


%
P=[225,425];
P2=[240,125];
P3=[350,325];
close all;
figure()
image(Im');hold on;
plot(P(1),P(2),'ro')
plot(P2(1),P2(2),'ko')
plot(P3(1),P3(2),'ko')
colorbar
%%
close all


figure()
image(Im3');
colorbar

J = imadjust(Im3');

figure()
imshow(J);hold on;
plot(P(1),P(2),'ro')
colorbar
%%
F=0;
F2=0;
F3=0;
t0=10000;
T=500;
for t = t0:t0+T

Im =  reshape(Uu(:,1:500)*Vv1(1:500,t),560,560);    
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

%%
%
fs=35


figure()
plot(F)

% Spectrum on pixel
figure()
pspectrum(F,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
    'MinThreshold',-50,'FrequencyLimits',[0, 10]);

figure()
fsst(F,fs,'yaxis')


%
figure()
plot(F2)

% Spectrum on pixel
figure()
pspectrum(F2,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
    'MinThreshold',-50,'FrequencyLimits',[0, 10]);

figure()
fsst(F2,fs,'yaxis')

%%
F_short = F(1:500);
F_short2 = F2(1:500);
F_short3 = F3(1:500);
%%
close all;


figure()
pspectrum(F_short,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 10]);


figure()
fsst(F_short,fs,'yaxis')


figure()
pspectrum(F_short2,fs,'spectrogram','Leakage',1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 10]);


figure()
fsst(F_short2,fs,'yaxis')
%%

[a,b,c] = pspectrum(F_short,fs,'persistence','Leakage',1,'OverlapPercent',99, ...
    'MinThreshold',0,'FrequencyLimits',[1, 10]);


%% Moving Variance
close all;
figure()
plot(F_short)


figure()
fsst(F_short,fs,'yaxis')


figure()
plot(F_short2)


figure()
fsst(F_short2,fs,'yaxis')



figure()
plot(F_short3)


figure()
fsst(F_short3,fs,'yaxis')

%%
close all;


figure()
pspectrum(F_short,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[2, 10]);


figure()
plot(F_short)


figure()
pspectrum(F_short2,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[2, 10]);


figure()
plot(F_short2)

figure()
pspectrum(F_short3,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[2, 10]);

%%
close all;


figure()
plot(F_short3)

figure()
subplot(3,1,1)
pspectrum(F_short,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 10]);
subplot(3,1,2)
pspectrum(F_short2,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 10]);
subplot(3,1,3)
pspectrum(F_short3,fs,'spectrogram','Leakage',0.1,'OverlapPercent',99, ...
    'MinThreshold',-100,'FrequencyLimits',[1, 10]);


figure()
subplot(3,1,1)
plot(F_short)
subplot(3,1,2)
plot(F_short2)
subplot(3,1,3)
plot(F_short3)
%%

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
plot(covX(1:1500),'r','LineWidth',2);hold on
plot(F(1:1500),'k','LineWidth',2);hold on
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
