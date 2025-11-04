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
% mn = 'AL_0033'; td = '2025-01-18'; 
% en = 1;

mn = 'AL_0033'; td = '2025-01-29'; 
en = 1;


serverRoot = expPath(mn, td, en);

d = loadData(serverRoot,mn,td,en);

%% Stim Times

% mode = 0;  % for stims derived from input pulse detection  (does not find
% 0)
mode = 0;  % for detecting input from input params

d = findStims(d,mode);

% d.stimStarts = d.stimStarts + 0.129;

%% Alternate( if input params follows old data format)
% stimTimes = d.inpTime(d.inpVals(2:end)>0.1 & d.inpVals(1:end-1)<=0.1);
% ds = find(diff([0;stimTimes])>2);
% d.stimStarts = stimTimes(ds);
% d.stimEnds = stimTimes(ds(2:end)-1);
% 
% 
% d.stimDur = d.stimEnds-d.stimStarts(1:end-1);

%%

offsetx = 0;
offsety = 0;

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
r = 1
mode = 0;

data = getpixel_dFoF(d,0,d.params.pixel,r);
% 
dFk = data.dFk;

% data = getpixels_dFoF(d);

%% impulse stamps
imp = d.input_params(:,end);
[C,ia,ic] = unique(imp);


%% Trial Samples

%% Filter
lp_dFk = lowpass(dFk,3,35);

%
t = d.timeBlue;
close all
j=10;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));
figure()
plot(t(i-35:i+35*4),dFk(i-35:i+35*4))
xline(t(i))
% xline(t(i2))

close all;
Tout = -2:0.0285:3;



figure()
sgtitle('impulses 01291')
for k = 1:9
    subplot(3,3,k)
    j = randi(length(d.stimStarts));

[a i] = min(abs(t - d.stimStarts(j)));

plot(Tout,dFk( i - 2*35:(i+35*3) ),'r','LineWidth',2);hold on;
plot(Tout,lp_dFk( i - 2*35:(i+35*3) ),'k','LineWidth',2);hold on;

ylim([-20,20])
xlim([-2,3])
yline(0)
xline(0)
title(append('impulse = ',num2str(imp(j))))
end
%%
close all
i = 3

k = find(ic == i);

figure()
plot(tImp,d_stack(k,:));hold on
plot(tImp,mean(d_stack(k,:)),'k','LineWidth',3);





%% marker data
dFk = data.dFk;

mData = markeranalysis(d,data);

%% analyze impulse stamps



tImp = -2:0.0285:3;
dFki = zeros(length(ia),length(tImp));
% dFkirel = zeros(length(ia),length(tImp));
d_stack = [];


ldFki = zeros(length(ia),length(tImp));
% dFkirel = zeros(length(ia),length(tImp));
ld_stack = [];

for j = 1:length(ic)
    k = numel(find(ic==ic(j)));
    
    [a i] = min(abs(t - d.stimStarts(j)));

    % dFkirel(ic(j),:) = dFkirel(ic(j),:) + (dFk(i-2*35:i+3*35) - dFk(i))/k;
    dFki(ic(j),:) = dFki(ic(j),:) + (dFk(i-2*35:i+3*35)- dFk(i))/k;
    
    d_stack = [d_stack;(dFk(i-2*35:i+3*35) - dFk(i))];

    ldFki(ic(j),:) = ldFki(ic(j),:) + (lp_dFk(i-2*35:i+3*35)- lp_dFk(i))/k;
    
    ld_stack = [ld_stack;(lp_dFk(i-2*35:i+3*35) - lp_dFk(i))];


end
%%
close all;
figure()
plot(tImp,dFki(2:end,:),'LineWidth',2);hold on
xline(0)

N = 9
 Legend=cell(N,1);
 for iter=2:N+1
   Legend{iter-1}= (append('impulse', num2str(C(iter))));
 end
 Legend
 legend(Legend)


%% compute error

impEr = [];
for j = 1:length(ic)
    k = ic(j);
    impEr = [impEr;norm(dFki(k,70:80) - d_stack(j,70:80))];

end


impErr = [];
for j = 1:length(C)
    idx = find(imp==C(j));
    imper=[]
    % for i = 1:length(idx)
    for i = 1:89
        imper = [imper, norm(dFki(j,70:80) - d_stack(idx(i),70:80))];
    end
    size(imper)
    impErr = [impErr;imper];
end




%%
V0=[];
FF0=[];
X0 = [];
for j = 1:length(ic)
    % k = numel(find(ic==ic(j)));
    
    [a i] = min(abs(t - d.stimStarts(j)));

    V0 = [V0; mData.Rv1(i)];
    FF0 = [FF0; mData.fft3(i)];
    X0 = [X0;dFk(i)];

end
%%

N=89;
close all;
figure()
for j = 1:length(ia)
    k = numel(find(ic==ic(j)));
    
    I = find(imp==C(j));
    v1 = V0(I(1:N));

    length(v1)
    k = N;

    plot(C(j)*ones(k,1),v1,'o');hold on;
end
title('variance')


figure()
for j = 1:length(ia)
    k = numel(find(ic==ic(j)));
    
    I = find(imp==C(j));
    f1 = FF0(I(1:N));

    length(v1)
    k = N;

    plot(C(j)*ones(k,1),f1,'o');hold on;
    ylim([0,50])
end
title('freq 0-6Hz')

figure()
for j = 1:length(ia)
    k = numel(find(ic==ic(j)));
    
    I = find(imp==C(j));
    x0 = X0(I(1:N));

    length(v1)
    k = N;

    plot(C(j)*ones(k,1),x0,'o');hold on;
    ylim([0,50])
end
title('x0')


figure()
for j = 1:length(ia)
    k = numel(find(ic==ic(j)));
    
    I = find(imp==C(j));
    x0 = X0(I(1:N));

    length(v1)
    k = N;

    plot(C(j)*ones(k,1),x0,'o');hold on;
    ylim([0,50])
end
title('impulse error')


%% filtered plotting
% 
% vv = 10;
% ff= 10;
% ex = 15;
% 
% 
% % vv = 100;
% % ff= 100;
% % er = 15;
% 
% 
% 
% 
% DFkimp=[];
% for i = 1: length(ia)
%     I = find(imp == C(i));
%     dFkimp=[];
% 
%     for j = 1:length(I)
%         [a k] = min(abs(t - d.stimStarts(I(j))));
% 
%         if V0(I(j)) <= vv & FF0(I(j)) <= ff & X0(I(j)) <= ex
%             dFkimp = [dFkimp;(dFk(k-2*35:k+3*35)) - dFk(k)];
%         end
% 
% 
%     end
%     DFkimp = [DFkimp; mean(dFkimp,1)];
% end
% 
% 
% 
% %
% close all;
% figure()
% plot(tImp,DFkimp(2:end,:),'LineWidth',2);hold on
% xline(0)
% 
% N = 9
%  Legend=cell(N,1);
%  for iter=2:N+1
%    Legend{iter-1}= (append('impulse', num2str(C(iter))));
%  end
%  Legend
%  legend(Legend)
% 




%%
close all;
figure()
plot(V0,impEr,'or','LineWidth',2)
xlabel('variance')
ylabel('impulse error')
ylim([0 100])

figure()
plot(FF0,impEr,'or','LineWidth',2)
xlabel('freq')
ylabel('impulse error')
ylim([0 100])

figure()
plot(X0,impEr,'or','LineWidth',2)
xlabel('x0')
ylabel('impulse error')
ylim([0 100])




figure()
% s = scatter3(X0,v_val,p_wcDfk,'x0 (df/F)','variance','Tracking Error','filled', ...
%     'ColorVariable','Tracking Error');
% s = scatter3(X0,v_val,p_wcDfk,'filled','ColorVariable',p_wcDfk);
s = scatter3(X0,V0,impEr,[],impEr,'filled');
xlabel('x_0 df/F')
ylabel('variance')
zlabel('Impulse deviation')
colorbar


figure()
% s = scatter3(X0,v_val,p_wcDfk,'x0 (df/F)','variance','Tracking Error','filled', ...
%     'ColorVariable','Tracking Error');
% s = scatter3(X0,v_val,p_wcDfk,'filled','ColorVariable',p_wcDfk);
s = scatter3(X0,FF0,impEr,[],impEr,'filled');
xlabel('x_0 df/F')
ylabel('FP')
zlabel('Impulse deviation')
colorbar
%%

% savedata.F = dFk;
% savedata.stimTimes = d.stimStarts;
% savedata.Impulse = d.input_params(:,end);
% 
% 
% save('data01181.mat',"savedata");


%% segregation

vv = 5;
ff= 10;
ex = 20;

% vv = 5;
% ff= 30;
% ex = 50;


numImpa=[];
numImpb=[];
DFkimp_a=[];
lDFkimp_a=[];

DFkimp_b=[];
lDFkimp_b=[];
Uu=[];
% U_b=[];
Ya=[];
Yb=[];

lYa=[];
lYb=[];

Na=[];
Nb = [];
for i = 1: length(ia)
    I = find(imp == C(i));
    dFkimp_a=[];
    ldFkimp_a=[];
    dFkimp_b=[];
    ldFkimp_b=[];
    nIa=0;
    nIb=0;

    y_a = [];
    ly_a=[];
    y_b = [];
    ly_b = [];
    pvar_a=[];
    pvar_b=[];
    lpvar_a=[];
    lpvar_b=[];

    for j = 1:length(I)
        [a k] = min(abs(t - d.stimStarts(I(j))));

        

        if  X0(I(j)) <= ex & FF0(I(j)) <= ff % V0(I(j)) <= vv &

            dFkimp_a = [dFkimp_a;(dFk(k-2*35:k+3*35)) - dFk(k)];
            ldFkimp_a = [ldFkimp_a;(lp_dFk(k-2*35:k+3*35)) - lp_dFk(k)];

            nIa = nIa +1;
            dtemp = (dFk(k-2*35:k+3*35)) - dFk(k);
            ldtemp = (lp_dFk(k-2*35:k+3*35)) - lp_dFk(k);

            pvar_a = [pvar_a,mean(abs(dtemp(35:70) - mean(dtemp(35:70))))];
            lpvar_a = [lpvar_a,mean(abs(ldtemp(35:70) - mean(ldtemp(35:70))))];

            y_a = [y_a,min(dtemp(70:80))];
            ly_a = [ly_a,min(dtemp(70:80))];

            Na = [Na,I(j)];
        else
            
            dFkimp_b = [dFkimp_b;(dFk(k-2*35:k+3*35)) - dFk(k)];
            ldFkimp_b = [ldFkimp_b;(lp_dFk(k-2*35:k+3*35)) - lp_dFk(k)];
            nIb = nIb +1;
            pvar_b = [pvar_b,mean(abs(dtemp(35:70) - mean(dtemp(35:70))))];
            lpvar_b = [lpvar_b,mean(abs(ldtemp(35:70) - mean(ldtemp(35:70))))];


            y_b = [y_b,min(dFkimp_b(70:80))];
            ly_b = [ly_b,min(ldFkimp_b(70:80))];
            Nb = [Nb,I(j)];
        end

        
    end
    numImpa = [numImpa,nIa];
    % DFkimp_a = [DFkimp_a; mean(dFkimp_a,1)];
    DFkimp_a = [DFkimp_a; mean(dFkimp_a)];
    lDFkimp_a = [lDFkimp_a; mean(ldFkimp_a,1)];

    Uu = [Uu;zeros(1,2*35), C(i), zeros(1,3*35)];

    numImpb = [numImpb,nIb];
    DFkimp_b = [DFkimp_b; mean(dFkimp_b,1)];
    lDFkimp_b = [lDFkimp_b; mean(ldFkimp_b,1)];
    % U_b = [U_b;zeros(1,2*35), C(i), zeros(1,3*35)];

    Ya.("ya"+num2str(i)) = y_a;

    Yb.("yb"+num2str(i)) = y_b;
    
    Pa.("pa"+num2str(i)) = pvar_a;

    Pb.("pb"+num2str(i)) = pvar_b;



    lYa.("ya"+num2str(i)) = ly_a;

    lYb.("yb"+num2str(i)) = ly_b;
    
    lPa.("pa"+num2str(i)) = lpvar_a;

    lPb.("pb"+num2str(i)) = lpvar_b;
    
end
Na = sort(Na);
Nb = sort(Nb);


%
close all;

figure()
subplot(1,2,1)
plot(tImp,DFkimp_a(2:end,:),'LineWidth',2);hold on
xline(0)
ylim([-5,5])
N = 9
 Legend=cell(N,1);
 for iter=2:N+1
   Legend{iter-1}= (append('impulse', num2str(C(iter))));
 end
 Legend
 legend(Legend)
 title('predictable')



subplot(1,2,2)
plot(tImp,DFkimp_b(2:end,:),'LineWidth',2);hold on
xline(0)
ylim([-5,5])
N = 9
 Legend=cell(N,1);
 for iter=2:N+1
   Legend{iter-1}= (append('impulse', num2str(C(iter))));
 end
 Legend
 legend(Legend) 
 title('un-predictable') 







% 
% figure()
% subplot(1,2,1)
% plot(tImp,lDFkimp_a(2:end,:),'LineWidth',2);hold on
% xline(0)
% ylim([-5,5])
% N = 9
%  Legend=cell(N,1);
%  for iter=2:N+1
%    Legend{iter-1}= (append('impulse', num2str(C(iter))));
%  end
%  Legend
%  legend(Legend)
%  title('predictable')
% 
% 
% 
% subplot(1,2,2)
% plot(tImp,lDFkimp_b(2:end,:),'LineWidth',2);hold on
% xline(0)
% ylim([-5,5])
% N = 9
%  Legend=cell(N,1);
%  for iter=2:N+1
%    Legend{iter-1}= (append('impulse', num2str(C(iter))));
%  end
%  Legend
%  legend(Legend) 
%  title('un-predictable') 


%%
figure()

plot(tImp,lDFkimp_a(2:end,:),'LineWidth',2);hold on
xline(0)
ylim([-5,5])
N = 9
 Legend=cell(N,1);
 for iter=2:N+1
   Legend{iter-1}= (append('impulse', num2str(C(iter))));
 end
 Legend
 legend(Legend)
 title('predictable')
%%
i = 10;
n = [];
sys = impulseest(Uu(i,:)',lDFkimp_a(i,:)',n)

%%
i = 10;
n = 2;
sys = impulseest(lDFkimp_a(i,70:end)',n)

%%

udata = reshape(Uu,1,[]);
ydata = reshape(DFkimp_a,1,[]);
n = [];

sys = impulseest(U(i,:)',DFkimp_a(i,:)',n)



%%
Uinterp = interp1(d.inpTime,d.inpVals,t);
%%

sys = impulseest(Uinterp,dFk',n);
%% Linear Fits, input output data
fa = fieldnames(Ya)
pa = fieldnames(Pa)
da=[];
amp=[];

fb = fieldnames(Yb)
pb = fieldnames(Pb)
db=[];
ampb=[];

for j = 1:length(C)
    da = [da,Ya.(fa{j}) + Pa.(pa{j})];
    amp = [amp,C(j)*ones(1,length(Ya.(fa{j})))];

    db = [db,Yb.(fb{j}) + Pb.(pb{j})];
    ampb = [ampb,C(j)*ones(1,length(Yb.(fb{j})))];
end



%
close all;
f = fit(amp',da',"poly1");
y=[];

figure()
subplot(2,2,1)
plot( f,amp, da);
hold on;
% for i=1:length(C)
%     y = [y,integral_val(bin==i)]
% 
% end
xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition','FontSize',11, 'FontWeight','bold')
title('low LFP set')
subplot(2,2,2)
boxplot(da,amp,'Whisker',1,'Widths',.3)
% hAx=gca;                                   % retrieve the axes handle
% xtk=hAx.XTick;                             % and the xtick values to plot() at...
% hold on
% hL=plot(xtk,f,'k-*'); 


xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition','FontSize',11, 'FontWeight','bold')
title('low LFP set')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas


fb = fit(ampb',db',"poly1");
y=[];

% figure()
subplot(2,2,3)
plot( fb,ampb, db);
hold on;
xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition','FontSize',11, 'FontWeight','bold')
title('high LFP set')
% for i=1:length(C)
%     y = [y,integral_val(bin==i)]
% 
% end
subplot(2,2,4)
boxplot(db,ampb,'Whisker',1,'Widths',.3)

xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition ','FontSize',11, 'FontWeight','bold')
title('high LFP set')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas

%% Linear Fits, input output data for low frequency
lfa = fieldnames(lYa)
lpa = fieldnames(lPa)
lda=[];
amp=[];

lfb = fieldnames(lYb)
lpb = fieldnames(lPb)
ldb=[];
ampb=[];

for j = 1:length(C)
    lda = [lda,lYa.(lfa{j}) + lPa.(lpa{j})];
    amp = [amp,C(j)*ones(1,length(lYa.(lfa{j})))];

    ldb = [ldb,lYb.(lfb{j}) + lPb.(lpb{j})];
    ampb = [ampb,C(j)*ones(1,length(lYb.(lfb{j})))];
end



%
close all;
f = fit(amp',lda',"poly1");
y=[];

figure()
subplot(2,2,1)
plot( f,amp, lda);
hold on;
% for i=1:length(C)
%     y = [y,integral_val(bin==i)]
% 
% end
xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition','FontSize',11, 'FontWeight','bold')
title('low LFP set')
subplot(2,2,2)
boxplot(lda,amp,'Whisker',1,'Widths',.3)
% hAx=gca;                                   % retrieve the axes handle
% xtk=hAx.XTick;                             % and the xtick values to plot() at...
% hold on
% hL=plot(xtk,f,'k-*'); 


xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition','FontSize',11, 'FontWeight','bold')
title('low LFP set')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas


fb = fit(ampb',ldb',"poly1");
y=[];

% figure()
subplot(2,2,3)
plot( fb,ampb, ldb);
hold on;
xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition','FontSize',11, 'FontWeight','bold')
title('high LFP set')
% for i=1:length(C)
%     y = [y,integral_val(bin==i)]
% 
% end
subplot(2,2,4)
boxplot(ldb,ampb,'Whisker',1,'Widths',.3)

xlabel('Input Amlpitude', 'FontSize',11, 'FontWeight','bold')
ylabel('Pixel Inhibition ','FontSize',11, 'FontWeight','bold')
title('high LFP set')
% figure_property.Width= '16'; % Figure width on canvas
% figure_property.Height= '9'; % Figure height on canvas





%%
Ts = 1/35
close all
np = 2;
nz = 0;
iodelay = 0;
sysd = tfest(udata',ydata',np,nz,iodelay,'Ts',Ts)

figure()
bode(sysd)


figure()
impulse(sysd)

%% SVD Tests

nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);

%%
close all
pixelTuningCurveViewerSVD(U, V, t, d.stimStarts, imp, [-4 4])


close all
pixelTuningCurveViewerSVD(U, V, t, d.stimStarts(Na), imp(Na), [-4 4])


%%
pixelTuningCurveViewerSVD(U, V, t, d.stimStarts(Nb), imp(Nb), [-4 4])


%% FFT for paper

close all;
Y = fft(dFk);

Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
L = length(dFk);             % Length of signal
t = (0:L-1)*T;        % Time vector

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);

f = Fs/L*(0:(L/2));
plot(f,P1,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of X(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")


figure()
pspectrum(Y,Fs)

M = 70
L = 10
lk = 0.7;
figure()
pspectrum(dFk,Fs,"spectrogram", ...
    TimeResolution=M/Fs,OverlapPercent=L/M*100, ...
    Leakage=lk)
title("pspectrum")


cc = clim;
xl = xlim;


T0 = 100000;
L = 1000;

Y = dFk(T0:T0+L);


% Y = fft(dFk);

Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
t = (0:L-1)*T;        % Time vector

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);

f = Fs/L*(0:(L/2));
plot(f,P1,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of X(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")


figure()
pspectrum(Y,Fs)

M = 70;
L = 7;
lk = 0.7;

figure()
pspectrum(Y,Fs,"spectrogram", ...
    TimeResolution=M/Fs,OverlapPercent=L/M*100, ...
    Leakage=lk)
title("pspectrum")

%%
close all;
fs=35;
L = 50000;
Y = dFk(T0:T0+L);
pspectrum(Y,fs,'persistence', ...
    'FrequencyLimits',[0 17],'TimeResolution',1)

%%



T0 = 100000;
L = 100;
X = dFk(T0:T0+L)
Y = fft(X);


Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
L = length(X);             % Length of signal
t = (0:L-1)*T;        % Time vector

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);

f = Fs/L*(0:(L/2));
plot(f,P1,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of X(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")
%%
close all;
horizon  = d.params.horizon;
L = 35*3;
Fs = 35;            % Sampling frequency                    
T = 1/Fs;             % Sampling period       
t = (0:L-1)*T;        % Time vector
f = Fs/L*(0:(L/2));


figure()

for i = 1:16

T0 = randi([(horizon) (length(dFk)-L)],1);

X = dFk(T0:T0+L)
Y = fft(X);

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);

aa = subplot(4,4,i)
plot(f,P1,"LineWidth",3)
ylim([0 10])
end
sgtitle("Single-Sided Amplitude Spectrum of X(t) vs freq(Hz)")

% xlabel("f (Hz)")
% ylabel("|P1(f)|"
% 


%% 0-6Hz information is Low freq
LPF = [];
for i  = 1: (length(dFk)-L-1)


X = dFk(i:i+L);
Y = fft(X);

P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);


LPF = [LPF, sum(P1(1:19))/sum(P1)];
end


%%
close all;

figure()
plot(LPF)

%%


        

i  = 70001;

im=zeros(560,560);
for j=1:500
    im = im+ double(U(:,:,j)*V(j,i));

end
im = im+mimg;


pathim=append(path,num2str(i-1));
fileID = fopen(pathim,'r');
A = fread(fileID,[560,560],'uint16')';


%
close all;
figure()
subplot(1,2,1)
imagesc(A);hold on
colorbar
clim([0 1000]);
impixelinfo;

subplot(1,2,2)
imagesc(im');hold on
colorbar
clim([0 3000]);
impixelinfo;




figure()
imagesc(A- im')
colorbar

%% Fitting Problem

inp1 = interp1(d.inpTime,d.inpVals,d.timeBlue);

%%
inp2 = zeros(size(d.timeBlue));

for j = 1:length(d.stimStarts)
    [k1,k2] = (min(abs(d.timeBlue - d.stimStarts(j))));
    [s1,s2] = (min(abs(d.inpTime  - d.stimStarts(j))));
    % imp = max(d.inpVals(s2-1000:s2+1000));
    inp2(k2) = max(d.inpVals(s2-1000:s2+1000));
end



