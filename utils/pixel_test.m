function pixel_test(d,data,dFkp)
wc=data.wc;
nc=data.nc;
tt = d.inpTime;
v = d.inpVals;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;

pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;

er = sort(er_wcDfk);
ner = sort(er_ncDfk);
dur = d.params.dur;
t = d.timeBlue;
dFk = data.dFk;


erw = sort(er_wcDfk);

i=15;

a1 = find(er_wcDfk==(erw(i)));
a2 = find(er_wcDfk==(erw(length(er_wcDfk)-i)));


m1=a1;
j1 = wc(m1);

m2=a2;
j2 = wc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));
[a k2] = min(abs(t - d.stimStarts(j2)));

k1
k2

[a k11] = min(abs(tt - d.stimStarts(j1)));
[a k12] = min(abs(tt - d.stimEnds(j1)));


figure()
plot(tt(k11:k12)-tt(k11),v(k11:k12),'LineWidth',3)
xlim([-5,4])
ylim([0,5])
ylabel('input')
xlabel('time')


close all
t1 = 0:1/35:dur;
ref=-5*ones(length(t1));
figure()
subplot(2,2,1)
plot(t1,dFk(k1:k1+35*(dur)),'LineWidth',2);hold on;
plot(t1,ref,'--k','LineWidth',2);hold on
ylim([-10,10])
title('regularized signal')

subplot(2,2,3)
plot(t1,dFkp(:,k1:k1+35*(dur)'),'LineWidth',2);hold on;
plot(t1,ref,'--k','LineWidth',2);hold on
ylim([-10,10])
title('regularized signal')



subplot(2,2,2)
plot(t1,dFk(k2:k2+35*(dur)),'LineWidth',2);hold on;
ylim([-10,10])
title('unregularized signal')

subplot(2,2,4)
plot(t1,dFkp(:,k2:k2+35*(dur)'),'LineWidth',2);hold on;
ylim([-10,10])
title('unregularized signal')

sgtitle('FBC')








ern = sort(er_ncDfk)

a1 = find(er_ncDfk==(ern(i)));
a2 = find(er_ncDfk==(ern(length(er_ncDfk)-i)));


m1=a1;
j1 = wc(m1);

m2=a2;
j2 = wc(m2);

[a k1] = min(abs(t - d.stimStarts(j1)));
[a k2] = min(abs(t - d.stimStarts(j2)));

k1
k2

[a k11] = min(abs(tt - d.stimStarts(j1)));
[a k12] = min(abs(tt - d.stimEnds(j1)));

% figure()
% plot(tt(k11:k12)-tt(k11),v(k11:k12),'LineWidth',3)
% xlim([-5,4])
% ylim([0,5])
% ylabel('input')
% xlabel('time')



figure()
subplot(2,2,1)
plot(t1,dFk(k1:k1+35*(dur)),'LineWidth',2);hold on;
plot(t1,ref,'--k','LineWidth',2);hold on
ylim([-10,10])
title('regularized signal')

subplot(2,2,3)
plot(t1,dFkp(:,k1:k1+35*(dur)'),'LineWidth',2);hold on;
plot(t1,ref,'--k','LineWidth',2);hold on
ylim([-10,10])
title('regularized signal')



subplot(2,2,2)
plot(t1,dFk(k2:k2+35*(dur)),'LineWidth',2);hold on;
ylim([-10,10])
title('unregularized signal')

subplot(2,2,4)
plot(t1,dFkp(:,k2:k2+35*(dur)'),'LineWidth',2);hold on;
ylim([-10,10])
title('unregularized signal')
sgtitle('FFC')


%
t2 = -3:0.0285:3;
figure()
subplot(2,2,1)
plot(t2,dFk(k1-35*(dur):k1+35*(dur)),'LineWidth',2);hold on;
plot(t1,ref,'--k','LineWidth',2);hold on
ylim([-10,10])
title('regularized signal')

subplot(2,2,3)
plot(t2,dFkp(:,k1-35*(dur):k1+35*(dur)),'LineWidth',2);hold on;
plot(t1,ref,'--k','LineWidth',2);hold on
ylim([-10,10])
title('regularized signal')



subplot(2,2,2)
plot(t2,dFk(k2-35*(dur):k2+35*(dur)),'LineWidth',2);hold on;
ylim([-10,10])
title('unregularized signal')

subplot(2,2,4)
plot(t2,dFkp(:,k2-35*(dur):k2+35*(dur)),'LineWidth',2);hold on;
ylim([-10,10])
title('unregularized signal')

sgtitle('FBC')




% Trial averaged pixels:

for k = 1:length(d.params.pixels)
ncDfkp=[];
wcDfkp=[];
ncer = [];
wcer = [];

for j = 1: length(nc)

    [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));
    ncDfkp = [ncDfkp; dFkp(k,i-35*5:i+35*(d.params.dur+5))];

    ncer = [ncer; dFkp(k,i:i+35*(d.params.dur))];


end
ncdFkp(:,:,k) = ncDfkp;
nc_trial(:,:,k) = ncer;



for j = 1: length(wc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));
    wcDfkp = [wcDfkp; dFkp(k,i-35*5:i+35*(d.params.dur+5))];

    wcer = [wcer; dFkp(k,i:i+35*(d.params.dur))];

end


wcdFkp(:,:,k) = wcDfkp;
wc_trial(:,:,k) = ncer;
end


% pixel mean
wc_mean=[];
wc_trial_dev = wc_trial;

for k = 1:length(d.params.pixels)
    kk = mean(wc_trial(:,:,k),1)
    wc_mean = [wc_mean;kk];

    wc_trial_dev(:,:,k) = wc_trial(:,:,k) - kk;




end




%

figure()

for i = 1:3
% i=40;

a1 = find(er_wcDfk==(erw(i)));
a2 = find(er_wcDfk==(erw(length(er_wcDfk)-i)));
m1=a1;
j1 = wc(m1);

m2=a2;
j2 = wc(m2);



p1 = a1
p2 = a2



% aa = squeeze(wcdFkp(p,:,:));
% figure()
% plot(aa);
% xline(35*5)
% xline(35*(5+3))
% title('per trial pixel')
% 
% figure()
% plot(wc_mean')
% title('pixels trial averaged')
% 
% aa = squeeze(wc_trial_dev(p,:,:));
% figure()
% plot(aa);
% title('per trial pixel dev')




subplot(3,2,1+i-1)

aa = squeeze(wcdFkp(p1,:,:));

plot(aa);
xline(35*5)
xline(35*(5+3))
title('per trial pixel')

subplot(3,2,2+i-1)

aa = squeeze(wc_trial_dev(p1,:,:));
plot(aa);
title('per trial pixel dev')

end



close all

figure()
i=40;

a1 = find(er_wcDfk==(erw(i)));
a2 = find(er_wcDfk==(erw(length(er_wcDfk)-i)));
m1=a1;
j1 = wc(m1);

m2=a2;
j2 = wc(m2);



p1 = a1
p2 = a2



aa = squeeze(wcdFkp(p1,:,:));
figure()
plot(aa);
xline(35*5)
xline(35*(5+3))
title('per trial pixel')

figure()
plot(wc_mean')
title('pixels trial averaged')

aa = squeeze(wc_trial_dev(p1,:,:));
figure()
plot(aa);
title('per trial pixel dev')
end