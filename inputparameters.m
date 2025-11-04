close all;
clear all;
clc;


githubDir = '/home/nimbus/Documents/Brain/'


addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab

%%
load("pixel_var.mat")
F_real = F;
F=[];
%%
F_real = F_real - mean(F_real,2)



close all
figure()
plot(F_real(:,1:500)')

%%
Fb = F_real(:,1:2:end);
Fv = F_real(:,2:2:end);

%%
close all
figure()
plot(Fb(:,1:100)')
title('real blue')

figure()
plot(Fv(:,1:100)')
title('real violet')
%%
close all;
fc = 10;
n = 2;
fs = 35;
[b,a] = butter(4,0.5);
yb = filter(b,a,Fb);
yv = filter(b,a,Fv);


figure()
plot(yb(:,1:500)')

figure()
plot(yv(:,1:500)')

%%
load("pixel_real.mat");
%%
close all;
figure()
plot(F2(:,1:500)')
title('svd pixel')



figure()
plot(Fb(:,1:500)')
title('real blue')

figure()
plot(Fv(:,1:500)')
title('real violet')

%%
close all;

Fs=35
Y = Fb;
L = length(Y);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);


%%






f = Fs/L*(0:(L/2));
plot(f,P1,"LineWidth",3) 
title("Single-Sided Amplitude Spectrum of X(t)")
xlabel("f (Hz)")
ylabel("|P1(f)|")
%%
close all;

figure()
plot(Fb(:,1:100)')
title('real blue')

figure()
plot(Fv(:,1:100)')
title('real violet')


% figure()
% plot(F_real)
%%
close all
df = diff(F_real,1,2);


figure()
plot(df(:,1:500)')


%
a0 = find(~df(1,:));

figure()
plot(a0)


%%
k=[];
for i=1:length(df)
    if df(i) == 0
        k = [k,1];
    else
        k = [k,0];
    end
end
%%
close all;
figure()
plot(k(1:500)*200);hold on;
plot(F_real(1,1:500))