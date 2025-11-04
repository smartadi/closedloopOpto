clc;
clear all;
close all;

states = dlmread("data/2025-05-01/2/states.csv",' ');
inp = dlmread("data/2025-05-01/2/input_amps.csv",' ');

% inp = readmatrix('data/2025-05-01/1/input_amps.csv');
% state = readmatrix('data/2025-05-01/1/states.csv');
params = load('data/2025-05-01/2/params.mat');
input_params = readmatrix('data/2025-05-01/2/input_params.csv');


%%
j=10;
k = input_params(j,2);

f = 330;
dur=3;
t = -2:1/330:(dur+2);
figure()
subplot(2,1,1)
plot(t,states(k -(2)*f :k+(dur+2)*f));hold on
xline(0)
xline(3)
yline(0)
yline(-5)

subplot(2,1,2)
plot(t,inp(k -(2)*f :k+(dur+2)*f));hold on

%%

nc = find(input_params(:,3) == 0);
wc = find(input_params(:,3) == 1);

ncdf = [];
for i=1: length(nc)
    j = nc(i)
    k = input_params(j,2);
ncdf = [ncdf;states(k -(3)*f :k+(dur+3)*f)'];
end

wcdf = [];
for i=1: length(wc)
     j = wc(i);
    k = input_params(j,2);
wcdf = [wcdf;states(k -(3)*f :k+(dur+3)*f)'];
end
ncdfavg = mean(ncdf);
wcdfavg = mean(wcdf);


t = -3:1/330:(dur+3);

% figure()
% subplot(1,2,1)
% plot(t,ncdf);hold on
% plot(t,ncdfavg,'r','LineWidth',3);hold on
% title('FFC')
% xline(0)
% xline(3)
% yline(0)
% yline(-5)
% ylim([-15,15])
% 
% 
% subplot(1,2,2)
% plot(t,wcdf);hold on
% plot(t,wcdfavg,'r','LineWidth',3);hold on
% title('FBC')
% xline(0)
% xline(3)
% yline(0)
% yline(-5)
% ylim([-15,15])


%% error
NCdf = ncdf(:,3*f:(3+dur)*f);
WCdf = wcdf(:,3*f:(3+dur)*f);

% data analysis 
er_ncdf = vecnorm(NCdf+5,2,2);
er_wcdf = vecnorm(WCdf+5,2,2);

vr_ncdf = var(NCdf);
vr_wcdf = var(WCdf)

N = 991;

aenc = mean(er_ncdf)
aewc = mean(er_wcdf)


% er_wcdf = vecnorm(WCdf+5,2,2);
% aenc = mean(mean(NCdf+5,2));
% aewc = mean(mean(WCdf+5,2));
% 
% 
% 
% an = abs(aenc/5)*100;
% aw = abs(aewc/5)*100;

avg_ernc = mean(er_ncdf);
avg_erwc = mean(er_wcdf);

figure()
plot(er_wcdf,'og','LineWidth',2);hold on
plot(er_ncdf,'or','LineWidth',2);hold on
legend('FBC','FFC')
legend('H2 error per trials')

%%

varnc = var(NCdf);
varwc = var(WCdf);

varncl = var(ncdf);
varwcl = var(wcdf);

tvarnc = sum(var(NCdf));
tvarwc = sum(var(WCdf));

%%
close all;
figure()
plot(t,varncl,'r','LineWidth',2);hold on
plot(t,varwcl,'g','LineWidth',2);hold on
legend('FFC','FBC');
xline(0,HandleVisibility="off")
xline(3,HandleVisibility="off")
xlim([-3,6])
title(append('variance comparision across experiment, reduction ratio = ', num2str(tvarwc/tvarnc)))


figure()
plot(er_wcdf,'og','LineWidth',2);hold on
plot(er_ncdf,'or','LineWidth',2);hold on
legend('FBC','FFC')
title('H2 error per trials')

figure()
subplot(1,2,1)
plot(t,ncdf);hold on
plot(t,ncdfavg,'r','LineWidth',3);hold on
title('FFC')
xline(0)
xline(3)
yline(0)
yline(-5)
ylim([-15,15])
xlim([-3,6])

subplot(1,2,2)
plot(t,wcdf);hold on
plot(t,wcdfavg,'r','LineWidth',3);hold on
title('FBC')
xline(0)
xline(3)
yline(0)
yline(-5)
ylim([-15,15])
xlim([-3,6])
sgtitle(('FFC vs FBC low latency'))



%%
vr_ncdf = var(NCdf');
vr_wcdf = var(WCdf');

figure()
plot(vr_wcdf,'og','LineWidth',2);hold on
plot(vr_ncdf,'or','LineWidth',2);hold on
