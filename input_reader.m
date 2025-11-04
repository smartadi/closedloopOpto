close all;
clear all;
clc;
load("inp_var.mat");
F(1)=[];
F2(1)=[];
F3(1)=[];


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
close all
s = 2
k=0
th=0
while th<1
    k=k+1;

    th = input(inda+k);
end

is = interp1(Vt,1:length(Vt),t_series(inda+k),'nearest');


ontime = t_series(i) + istart(s) - istart(1);
offtime = t_series(i) + istop(s) - istart(1);

inda = interp1(Vt,1:length(Vt),ontime,'nearest');
indb = interp1(Vt,1:length(Vt),offtime,'nearest');

figure()
plot(Vt(inda:indb),F(inda:indb));hold on;
plot(Vt(inda:indb),F2(inda:indb))
plot(Vt(inda:indb),F3(inda:indb))
xline(Vt(is))


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
%%
Ea=[]
Eb=[]
for iter = 1:length(istart)

ea = t_series(i) + istart(2) - istart(1);
eb = t_series(i) + istop(2) - istart(1);

inda = interp1(Vt,1:length(Vt),ontime,'nearest');
indb = interp1(Vt,1:length(Vt),offtime,'nearest');



end
figure()
plot(t_series(inda:indb),input(inda:indb))


ind_u = interp1(t_series,1:length(t_series),ea,'nearest');


while th<0.1
    iter = iter +1
    th = t_series(ind_u+iter)
end

ind_u = ind_u+iter

figure()
plot(Vt(inda:indb),F(inda:indb));hold on;
plot(Vt(inda:indb),F2(inda:indb))
plot(Vt(inda:indb),F3(inda:indb))
xline(Vt(is))


figure()
plot(t_series(inda:indb),input(inda:indb))
%%
close all;
x = F(15000:16000);
x2 = F2(15000:16000);
x3 = F3(15000:16000);

qw = interp1(t_series,1:length(t_series),Vt(15000),'nearest');
qe = interp1(t_series,1:length(t_series),Vt(16000),'nearest');


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

figure()
plot(t_series(qw:qe),input(qw:qe))

%%

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
    yc=[yc,100*cov(x)];
    yi=[yi,sum(x)/L];
    yf=[yf,sum(abs(fft(x)))/(2*L)];

    x2 = F2(i:i+L);
    yc2=[yc2,100*cov(x2)];
    yi2=[yi2,sum(x2)/L];
    yf2=[yf2,sum(abs(fft(x2)))/(2*L)];

    x3 = F3(i:i+L);
    yc3=[yc3,100*cov(x3)];
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

%
t = 10000
T = 500
qw = interp1(t_series,1:length(t_series),Vt(t),'nearest');
qe = interp1(t_series,1:length(t_series),Vt(t+T),'nearest');

close all
figure()
subplot(4,1,1)
plot(tt(t:t+T),F(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yf(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yc(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yi(t:t+T),'LineWidth',2);hold on;
ylim([-0.7 0.7])
legend('signal','fft','covariance','integral')
ylabel('Pix1')
title('attention state from pixel readings')


subplot(4,1,2)
plot(tt(t:t+T),F2(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yf2(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yc2(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yi2(t:t+T),'LineWidth',2);hold on;
ylim([-0.7 0.7])
ylabel('Pix2')
% legend('signal','fft','covariance','integral')
% xlabel('time')
% title('attention state from pixel readings')


subplot(4,1,3)
plot(tt(t:t+T),F3(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yf3(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yc3(t:t+T),'LineWidth',2);hold on;
plot(tt(t:t+T),yi3(t:t+T),'LineWidth',2);hold on;
ylim([-0.7 0.7])
% legend('signal','fft','covariance','integral')
xlabel('time(s)')
ylabel('Pix3')
% title('attention state from pixel readings')

subplot(4,1,4)
plot(t_series(qw:qe),input(qw:qe),'LineWidth',2);hold on;
xlabel('time(s)')
ylabel('inp')
% title('attention state from pixel readings')


