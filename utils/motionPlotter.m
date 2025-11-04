function motionPlotter(i,d,data)
mv = d.mv; % motion
tt = d.inpTime;
v = d.inpVals;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;

pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;

er = sort(er_wcDfk);
ner = sort(er_ncDfk);

wc=data.wc;
nc=data.nc;

dur = d.params.dur
t = d.timeBlue;

[m1,i1] = max(er_wcDfk);
[m2,i2] = min(er_wcDfk);


a1 = find(er_wcDfk == (er(i)), 1, 'first'); % Optimize to find first occurrence
a2 = find(er_wcDfk == (er(end - i)), 1, 'first'); % Optimize to find first occurrence

m1 = a1;
j1 = wc(m1);

m2 = a2;
j2 = wc(m2);

[a, k1] = min(abs(t - d.stimStarts(j1)));
[a, k2] = min(abs(t - d.stimStarts(j2)));

ref = -5 * ones(1, 3 * 35 + 1);
Tref = 0:0.0285:dur;

Tp = -10:0.0285:dur + 3;
Tp2 = -5:0.0285:dur + 1;


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
plot(Tp2,1e-6*mv((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])
legend('0-3Hz','3-6Hz','3-6Hz','var 1s','var 2s','var 3s')
ylabel('dF/F')
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
plot(Tp2,1e-6*mv((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])

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

ner = sort(er_ncDfk);

a1 = find(er_ncDfk == ner(i), 1, 'first'); % Optimize to find first occurrence
a2 = find(er_ncDfk == ner(end - i), 1, 'first'); % Optimize to find first occurrence

m1 = a1;
j1 = nc(m1);

m2 = a2;
j2 = nc(m2);

[a, k1] = min(abs(t - d.stimStarts(j1)));
[a, k2] = min(abs(t - d.stimStarts(j2)));
k1
k2

ref = -5 * ones(1, 3 * 35 + 1);
Tref = 0:0.0285:dur;

Tp = -10:0.0285:dur + 3;
Tp2 = -5:0.0285:dur + 1;

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
plot(Tp2,1e-5*mv((k1-35*5):(k1+35*(dur+1))),'LineWidth',2);hold on
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
plot(Tp2,1e-6*mv((k2-35*5):(k2+35*(dur+1))),'LineWidth',2);hold on
xline(0)
xline(3)
ylim([0,30])
xlim([-5,4])

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
end