function features = feature_analysis(data,d)
    Fs = 35;
    win_len_sec = 2;
    features.mf = compute_bandpower_sliding(data.dFk, Fs, win_len_sec);
    win_len_sec = 1;
    features.v1 = compute_past_variance(data.dFk, Fs, win_len_sec);
    win_len_sec = 2;
    features.v2 = compute_past_variance(data.dFk, Fs, win_len_sec);
    win_len_sec = 3;
    features.v3 = compute_past_variance(data.dFk, Fs, win_len_sec);

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
dur = d.params.dur
t = d.timeBlue;
dFk = data.dFk;

wc_pval1 = zeros(length(data.wc), 1);
nc_pval1 = zeros(length(data.nc), 1);

wc_pval2 = zeros(length(data.wc), 1);
nc_pval2 = zeros(length(data.nc), 1);

wc_pval3 = zeros(length(data.wc), 1);
nc_pval3 = zeros(length(data.nc), 1);

wc_pval4 = zeros(length(data.wc), 1);
nc_pval4 = zeros(length(data.nc), 1);

v_val_fb = zeros(length(data.wc), 3);
f_val_fb = zeros(length(data.wc), 3);

v_val_ff = zeros(length(data.nc), 3);
f_val_ff = zeros(length(data.nc), 3);


wcfeature.variance.v1 = zeros(length(data.wc), 1);
wcfeature.variance.v2 = zeros(length(data.wc), 1);
wcfeature.variance.v3 = zeros(length(data.wc), 1);
wcfeature.freq.f1 = zeros(length(data.wc), 1);
wcfeature.freq.f2 = zeros(length(data.wc), 1);
wcfeature.freq.f3 = zeros(length(data.wc), 1);

ncfeature.variance.v1 = zeros(length(data.nc), 1);
ncfeature.variance.v2 = zeros(length(data.nc), 1);
ncfeature.variance.v3 = zeros(length(data.nc), 1);
ncfeature.freq.f1 = zeros(length(data.nc), 1);
ncfeature.freq.f2 = zeros(length(data.nc), 1);
ncfeature.freq.f3 = zeros(length(data.nc), 1);

pre_v_fb = zeros(length(data.wc), 3);
pre_f_fb = zeros(length(data.wc), 3);

post_v_fb = zeros(length(data.wc), 3);
post_f_fb = zeros(length(data.wc), 3);

pre_v_ff = zeros(length(data.nc), 3);
pre_f_ff = zeros(length(data.nc), 3);

post_v_ff = zeros(length(data.nc), 3);
post_f_ff = zeros(length(data.nc), 3);

for i = 1:length(data.wc)
    j = wc(i);
    [a, k] = min(abs(t - d.stimStarts(j)));

    wcfeature.variance.v1(i) = features.v1(k);
    wcfeature.variance.v2(i) = features.v2(k);
    wcfeature.variance.v3(i) = features.v3(k);
    wcfeature.freq.f1 = features.mf(k, 1);
    wcfeature.freq.f2 = features.mf(k, 2);
    wcfeature.freq.f3 = features.mf(k, 3);
    

    pre_v_fb(i, :) = [sum(features.v1(k-35*2:k)), sum(features.v2(k-35*2:k)), sum(features.v3(k-35*2:k))];
    pre_f_fb(i, :) = [sum(features.mf(k-35*2:k, 1)), sum(features.mf(k-35*2:k, 2)), sum(features.mf(k-35*2:k, 3))];

    post_v_fb(i, :) = [sum(features.v1(k:k+35*3)), sum(features.v2(k:k+35*3)), sum(features.v3(k:k+35*3))];
    post_f_fb(i, :) = [sum(features.mf(k:k+35*3, 1)), sum(features.mf(k:k+35*3, 2)), sum(features.mf(k:k+35*3, 3))];
end

for i = 1:length(data.nc)
    j = nc(i);
    [a, k] = min(abs(t - d.stimStarts(j)));

    ncfeature.variance.v1(i) = features.v1(k);
    ncfeature.variance.v2(i) = features.v2(k);
    ncfeature.variance.v3(i) = features.v3(k);
    ncfeature.freq.f1 = features.mf(k, 1);
    ncfeature.freq.f2 = features.mf(k, 2);
    ncfeature.freq.f3 = features.mf(k, 3);

    pre_v_ff(i, :) = [sum(features.v1(k-35*2:k)), sum(features.v2(k-35*2:k)), sum(features.v3(k-35*2:k))];
    pre_f_ff(i, :) = [sum(features.mf(k-35*2:k, 1)), sum(features.mf(k-35*2:k, 2)), sum(features.mf(k-35*2:k, 3))];

    post_v_ff(i, :) = [sum(features.v1(k:k+35*3)), sum(features.v2(k:k+35*3)), sum(features.v3(k:k+35*3))];
    post_f_ff(i, :) = [sum(features.mf(k:k+35*3, 1)), sum(features.mf(k:k+35*3, 2)), sum(features.mf(k:k+35*3, 3))];
end

%% Sort error vs parameter 
wc_pval1 = zeros(length(data.wc), 1);
nc_pval1 = zeros(length(data.nc), 1);

wc_pval2 = zeros(length(data.wc), 1);
nc_pval2 = zeros(length(data.nc), 1);

wc_pval3 = zeros(length(data.wc), 1);
nc_pval3 = zeros(length(data.nc), 1);

wc_pval4 = zeros(length(data.wc), 1);
nc_pval4 = zeros(length(data.nc), 1);

v_val_fb = zeros(length(data.wc), 3);
f_val_fb = zeros(length(data.wc), 3);

v_val_ff = zeros(length(data.nc), 3);
f_val_ff = zeros(length(data.nc), 3);

v1_fb = zeros(length(data.wc), 1);
v2_fb = zeros(length(data.wc), 1);
v3_fb = zeros(length(data.wc), 1);
f1_fb = zeros(length(data.wc), 1);
f2_fb = zeros(length(data.wc), 1);
f3_fb = zeros(length(data.wc), 1);

v1_ff = zeros(length(data.nc), 1);
v2_ff = zeros(length(data.nc), 1);
v3_ff = zeros(length(data.nc), 1);
f1_ff = zeros(length(data.nc), 1);
f2_ff = zeros(length(data.nc), 1);
f3_ff = zeros(length(data.nc), 1);

pre_v_fb = zeros(length(data.wc), 3);
pre_f_fb = zeros(length(data.wc), 3);

post_v_fb = zeros(length(data.wc), 3);
post_f_fb = zeros(length(data.wc), 3);

pre_v_ff = zeros(length(data.nc), 3);
pre_f_ff = zeros(length(data.nc), 3);

post_v_ff = zeros(length(data.nc), 3);
post_f_ff = zeros(length(data.nc), 3);

for i = 1:length(data.wc)
    j = wc(i);
    [a, k] = min(abs(t - d.stimStarts(j)));

    v1_fb(i) = features.v1(k);
    v2_fb(i) = features.v2(k);
    v3_fb(i) = features.v3(k);

    f1_fb(i) = features.mf(k, 1);
    f2_fb(i) = features.mf(k, 2);
    f3_fb(i) = features.mf(k, 3);

    pre_v_fb(i, :) = [sum(features.v1(k-35*2:k)), sum(features.v2(k-35*2:k)), sum(features.v3(k-35*2:k))];
    pre_f_fb(i, :) = [sum(features.mf(k-35*2:k, 1)), sum(features.mf(k-35*2:k, 2)), sum(features.mf(k-35*2:k, 3))];

    post_v_fb(i, :) = [sum(features.v1(k:k+35*3)), sum(features.v2(k:k+35*3)), sum(features.v3(k:k+35*3))];
    post_f_fb(i, :) = [sum(features.mf(k:k+35*3, 1)), sum(features.mf(k:k+35*3, 2)), sum(features.mf(k:k+35*3, 3))];
end

for i = 1:length(data.nc)
    j = nc(i);
    [a, k] = min(abs(t - d.stimStarts(j)));

    v1_ff(i) = features.v1(k);
    v2_ff(i) = features.v2(k);
    v3_ff(i) = features.v3(k);

    f1_ff(i) = features.mf(k, 1);
    f2_ff(i) = features.mf(k, 2);
    f3_ff(i) = features.mf(k, 3);

    pre_v_ff(i, :) = [sum(features.v1(k-35*2:k)), sum(features.v2(k-35*2:k)), sum(features.v3(k-35*2:k))];
    pre_f_ff(i, :) = [sum(features.mf(k-35*2:k, 1)), sum(features.mf(k-35*2:k, 2)), sum(features.mf(k-35*2:k, 3))];

    post_v_ff(i, :) = [sum(features.v1(k:k+35*3)), sum(features.v2(k:k+35*3)), sum(features.v3(k:k+35*3))];
    post_f_ff(i, :) = [sum(features.mf(k:k+35*3, 1)), sum(features.mf(k:k+35*3, 2)), sum(features.mf(k:k+35*3, 3))];
end




%% Classify initial condition

X0_wc = zeros(length(wc), 1); % Preallocate for efficiency
for j = 1:length(wc)
    [~, i] = min(abs(t - d.stimStarts(wc(j))));
    X0_wc(j) = dFk(i);
end

X0_nc = zeros(length(nc), 1); % Preallocate for efficiency
for j = 1:length(nc)
    [~, i] = min(abs(t - d.stimStarts(nc(j))));
    X0_nc(j) = dFk(i);
end

X0 = zeros(length(d.stimStarts), 1); % Preallocate for efficiency
for j = 1:length(d.stimStarts)
    [~, i] = min(abs(t - d.stimStarts(j)));
    X0(j) = dFk(i);
end
%% Thresholding

figure()
subplot(1,3,1)
s = scatter3(X0_wc,f1_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,f1_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;

subplot(1,3,2)
s = scatter3(X0_wc,f2_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,f2_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;


subplot(1,3,3)
s = scatter3(X0_wc,f3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,f3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;


figure()
subplot(1,3,1)
s = scatter3(X0_wc,v1_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,v1_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;

subplot(1,3,2)
s = scatter3(X0_wc,v2_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,v2_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;


subplot(1,3,3)
s = scatter3(X0_wc,v3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,v3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;
 
%%

figure()
subplot(1,3,1)
s = scatter3(X0_wc,pre_f_fb(:,1),er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,pre_f_ff(:,1),er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('f1')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;

subplot(1,3,2)
s = scatter3(X0_wc,pre_f_fb(:,2),er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,pre_f_ff(:,2),er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('f2')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;


subplot(1,3,3)
s = scatter3(X0_wc,pre_f_fb(:,3),er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,pre_f_ff(:,3),er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('freq marker')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('f3')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;
%%

figure()
subplot(1,3,1)
s = scatter3(X0_wc,v1_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,v1_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;

subplot(1,3,2)
s = scatter3(X0_wc,v2_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,v2_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;


subplot(1,3,3)
s = scatter3(X0_wc,v3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,v3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('var marker')
zlabel('Tracking error norm')
xlim([-10 10])
ylim([0 20])
zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on state and parameters')


threshold = 30; 

xp = get(gca,'Xlim');
yp = get(gca,'Ylim');
% Use the axes x and Y limits to find the co-ordinates for the patch
x1 = [ xp(1) xp(2) xp(2) xp(1)];
y1 = [ yp(1) yp(1) yp(2) yp(2)];
z1 = ones(1,numel(y1))* threshold; 
v = patch(x1,y1,z1, 'g');
set(v,'facealpha',0.1);
set(v,'edgealpha',0.5);
set(gcf,'renderer','opengl') ;
hold on;
end