%% Data analysis Script
% add pixel configuration


clc;
close all;
clear all;

%% experiment name

% mn = 'AL_0041'; td = '2026-04-13';   
% en = 2;


% With rewards %%%%%%%%%%%%%%%%%%%
mn = 'AL_0033'; td = '2025-03-04'; 
en = 1;
% mn = 'AL_0033'; td = '2025-03-04'; 
% en = 2;
   
% mn = 'AL_0033'; td = '2025-03-05'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-03-18'; 
% en = 1;

% mn = 'AL_0033'; td = '2025-03-20'; 
% en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-04-18'; 
% en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; 
% en = 2;

% NEW LASER
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;

% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 1;
% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 2;


% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;

% mn = 'AL_0033'; td = '2025-04-19'; 
% en = 1;


% mn = 'AL_0033'; td = '2025-04-18'; 
% en = 4;

% mn = 'AL_0033'; td = '2025-04-20'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-04-20'; 
% en = 2;
% 
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% No Reward, high controller delay

% mn = 'AL_0033'; td = '2024-12-18'; 
% en = 4;

% mn = 'AL_0033'; td = '2025-01-20'; 
% en = 3;

% mn = 'AL_0033'; td = '2025-02-12'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-02-26'; 
% en = 2;
% 
% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-02-21'; 
% en = 2;

% mn = 'AL_0033'; td = '2024-12-19'; 
% en = 2; % no variance reduction and control consteained to half
% Auto tunning no reward
% mn = 'AL_0033'; td = '2024-12-19'; 
% en = 1;
% mn = 'AL_0033'; td = '2024-12-20'; 
% en = 7;
% 
% mn = 'AL_0033'; td = '2024-12-23'; 
% en = 1;
% 
% % mn = 'AL_0033'; td = '2025-02-13'; 
% % en = 2;  % no parameter data
% 
% 
% 
% mn = 'AL_0033'; td = '2025-01-17'; 
% en = 1; % input data missing

% mn = 'AL_0033'; td = '2025-01-20'; 
% en = 3;


%candidates
% mn = 'AL_0033'; td = '2024-12-23'; 
% en = 1;
% 
% mn = 'AL_0033'; td = '2025-01-20'; 
% en = 3;
% mn = 'AL_0033'; td = '2025-02-12'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-02-26'; 
% en = 2;
% % 
% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-03-04'; 
% en = 1;
% mn = 'AL_0033'; td = '2025-03-04'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-03-05'; 
% en = 2;
% mn = 'AL_0033'; td = '2025-03-20'; 
% en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; 
% en = 2;



% NEW LASER
% mn = 'AL_0039'; td = '2025-04-19'; 
% en = 1;
% 
% mn = 'AL_0039'; td = '2025-04-20'; 
% en = 1;



% mn = 'AL_0039'; td = '2025-04-30'; 
% en = 3;


% mn = 'AL_0033'; td = '2025-04-20'; 
% en = 2;

     
% mn = 'AL_0033'; td = '2025-03-20'; 
% en = 4;


% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;

% mn = 'AL_0033'; td = '2025-02-24'; 
% en = 2;

% mn = 'AL_0041'; td = '2025-11-05'; 
% en = 3;
% 
% mn = 'AL_0041'; td = '2025-11-12'; 
% en = 1;

% mn = 'AL_0041'; td = '2025-12-10'; 
% en = 1;
%% get data
pathString = genpath('utils');
    addpath(pathString);
    % %%
    % addpath('utils')
d = initialize_data(mn,en,td);

d.params.pix_ids = [2,4,5,8,9,12,13];
d.params.pix_inv = [170,320];
%% Run Movie
sigName = 'lightCommand638';
sigName = 'lightCommand';
[tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);

tInd = 1;
traces(tInd).t = tt;
traces(tInd).v = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];

% tInd = 2;
% traces(tInd).t = tt;
% traces(tInd).v = vel;
% traces(tInd).name = 'wheelVelocity';
% traces(tInd).lims = [-3000 3000];
nSV = 500;

[U, V, t, mimg] = loadUVt(serverRoot, nSV);
%%

movieWithTracesSVD(U, V, t, traces, [], []);

%% display image
% if image has been extracted on the local PC
displayFrame(mn, td, en, d, d.params.pixels);

%% Load or save from image data

mode = 0  % from binary image
% mode = 1 ; % from SVD
%
% r = 0; % dont read file
r = 1; % read file
[data,dFk_temp] = getpixel_dFoF(d,mode,d.params.pixel,r);
dFk = data.dFk;
%%
data_pix = getpixels_dFoF(d);
dFkp = data_pix.dFk;

%% Trial Samples
% d.mv = d.motion.motion_1;
% d.mv = d.motion.motion_1(1:2:end,1);


dur = d.params.dur;
t = d.timeBlue;
close all
j=6;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
close all
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
ylabel('dF/F trace')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)
ylabel('Input Values');


% subplot(3,1,3)
% plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
% plot(Tout,5*ones(1,length(Tout)))
% xlim([-3,6])
% xline(0)
% xline(3)
% ylabel('motion')
% xlabel('Time (s)');
% sgtitle('trial sample')


%% Feedforward vs Feedback 

trials = 100;

d.ref=-5;

data = controllerData(data,d,trials);
%%
% Plots for interleaved trials, 1 = save as pdf
analysisPlots(data,d,0);
%%
analysisPlots_paper(data,d,0);

%% get trail stamps
nc = data.nc;
wc = data.wc;
%% Invariance tests
invarianceAnalysis(data,d);
%%


features = feature_analysis(data,d);

mf = features.mf;
v1 = features.v1;
v2 = features.v2;
v3 = features.v3;

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
%% MSE wrt initial condition
figure()
plot(data.er_ncDfk,abs(X0_nc+5),'or','LineWidth',3);hold on;
plot(data.er_wcDfk,abs(X0_wc+5),'og','LineWidth',3);
yline(0)
shortCornerAxes_plot(gca,'Frac',0.10,'XLabel','MSE','YLabel','|y_0 - y_{ref}|','LineWidth',5)



%% Analysis based on H2 
pixel_test(d,data,dFkp);
%%
dataPixel = pixelAnalysis(d,data,dFkp);
%%
close all;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;

pwcDfk = data.pwcDfk;
pncDfk = data.pncDfk;

er = sort(er_wcDfk);
ner = sort(er_ncDfk);

%% Analyzer
close all;
i = 15;
motionPlotter(i,d,data,features)

%%



%%

ncmotion_pre = sum(data.ncmotion(:,1:35*1),2);
wcmotion_pre = sum(data.wcmotion(:,1:35*1),2);


ncmotion_during = sum(data.ncmotion(:,35:(dur)*35),2);
wcmotion_during = sum(data.wcmotion(:,35:(dur)*35),2);



%% Thresholding
close all
figure()
subplot(1,2,1)
s = scatter3(X0_wc,wcmotion_pre,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,ncmotion_pre,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('motion')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% % colorbar
% % zlim([0,100])
% % clim([0,80])
title('regularizability dependece on motion pre trial')


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
% 
subplot(1,2,2)
s = scatter3(X0_wc,wcmotion_during,er_wcDfk,[],er_wcDfk,'filled','g');hold on
s = scatter3(X0_nc,ncmotion_during,er_ncDfk,[],er_ncDfk,'filled','r');
xlabel('x_0 df/F')
ylabel('motion')
zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% colorbar
% zlim([0,100])
% clim([0,80])
title('regularizability dependece on motion during trial')


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
% 
% 
% subplot(1,3,3)
% s = scatter3(X0,f3_fb,er_wcDfk,[],er_wcDfk,'filled','g');hold on
% s = scatter3(XX0,f3_ff,er_ncDfk,[],er_ncDfk,'filled','r');
% xlabel('x_0 df/F')
% ylabel('freq marker')
% zlabel('Tracking error norm')
% xlim([-10 10])
% ylim([0 20])
% zlim([0 50])
% % colorbar
% % zlim([0,100])
% % clim([0,80])
% title('regularizability dependece on state and parameters')

%%
dur = d.params.dur
t = d.timeBlue;
close all
j=50;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
close all
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,-5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('analysis')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('analysis')


%%

inputs = d.iputs(d.params.horizon:d.params.horizon+length(d.timeBlue));
%% Linear Regression: predict primary pixel from pixel inputs + task signals

% --- USER CONFIGURATION ---
startIdx    = 2000;
Train_length = length(d.timeBlue) - startIdx;
endIdx      = startIdx + Train_length - 1;
train_ratio = 0.7;

pixelIdx    = [5, 6, 10];          % which peripheral pixels to include as regressors
useMotion   = true;                % include d.mv (motion)
useInputs   = true;                % include controller inputs

pY = 1;                            % AR lags of primary pixel
pX = 2;                            % lags of each X column

% -----------------------------------------------------------------------

T = Train_length;
rng(0);
close all;

% --- Build X matrix ---
DataX = dFkp(pixelIdx, startIdx:endIdx)';           % T x nPixels
if useMotion,  DataX = [DataX, d.mv(startIdx:endIdx)];         end
if useInputs,  DataX = [DataX, inputs(startIdx:endIdx)];       end

Datay = dFk(startIdx:endIdx)';                      % T x 1

% --- Train/test split ---
Ntr    = floor(train_ratio * T);
idx_tr = 1:Ntr;
idx_te = (Ntr+1):T;
X_tr = DataX(idx_tr,:);   X_te = DataX(idx_te,:);
y_tr = Datay(idx_tr);     y_te = Datay(idx_te);

% --- Z-score using train statistics only ---
[X_tr_z, muX, sdX] = zscore(X_tr);  sdX(sdX < eps) = 1;
X_te_z = (X_te - muX) ./ sdX;
[y_tr_z, muy, sdy] = zscore(y_tr);  sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

% --- Lagged design matrices (no leakage across split) ---
[Phi_tr, y_tr_aligned, maxLag] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned, ~     ] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- OLS fit ---
beta         = Phi_tr \ y_tr_aligned;
yhat_tr_scal = Phi_tr * beta;
yhat_te_scal = Phi_te * beta;

% --- Invert z-score to original units ---
yhat_tr = yhat_tr_scal * sdy + muy;
yhat_te = yhat_te_scal * sdy + muy;
y_tr_raw = y_tr((maxLag+1):end);
y_te_raw = y_te((maxLag+1):end);

% Pad NaNs to align with original time axis
yhat_tr_full                   = NaN(Ntr, 1);
yhat_tr_full((maxLag+1):end)   = yhat_tr;
yhat_te_full                   = NaN(T - Ntr, 1);
yhat_te_full((maxLag+1):end)   = yhat_te;
yhat_all_full = [yhat_tr_full; yhat_te_full];

% --- Metrics ---
rmse_tr = sqrt(mean((y_tr_raw - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw - yhat_te).^2));
r2_tr   = 1 - sum((y_tr_raw - yhat_tr).^2) / sum((y_tr_raw - mean(y_tr_raw)).^2);
r2_te   = 1 - sum((y_te_raw - yhat_te).^2) / sum((y_te_raw - mean(y_te_raw)).^2);
fprintf('maxLag=%d | Train: RMSE=%.6f  R²=%.4f | Test: RMSE=%.6f  R²=%.4f\n', ...
        maxLag, rmse_tr, r2_tr, rmse_te, r2_te);

% --- Plots ---
figure('Name','Full Reconstruction','NumberTitle','off');
plot(1:T, Datay, 'LineWidth', 1); hold on;
plot(1:T, yhat_all_full, 'LineWidth', 1);
xlabel('t'); ylabel('dF/F'); title('Actual vs Predicted (Full Series)');
legend('Actual','Predicted','Location','best'); grid on;

figure('Name','Test Reconstruction','NumberTitle','off');
t_te_ax = (Ntr+1):T;
plot(t_te_ax, Datay(t_te_ax), 'LineWidth', 1); hold on;
plot(t_te_ax, yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('dF/F'); title('Actual vs Predicted (Test)');
legend('Actual','Predicted','Location','best'); grid on;

figure('Name','Test Residuals','NumberTitle','off');
plot(t_te_ax, Datay(t_te_ax) - yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('Residual'); title('Residuals (Test)'); grid on;

dFk_reg = [zeros(length(data.dFk) - length(yhat_all_full),1);yhat_all_full];

%%
pixel = d.params.pix_inv;
tic 
dfkpix = get_dFoF(d,pixel, serverRoot);
toc
%%




%
% DataX = [dfkpix(startIdx:endIdx)',d.mv(startIdx:endIdx),inputs(startIdx:endIdx),];


DataX = [dFkp(d.params.pix_ids,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs(startIdx:endIdx)];

Datay = dFk(startIdx:endIdx)';


pY = 0;
pX = 70;


% --- Split ---
train_ratio = 0.7;
Ntr = floor(train_ratio*T);
idx_tr = 1:Ntr; idx_te = (Ntr+1):T;
X_tr = DataX(idx_tr,:);  X_te = DataX(idx_te,:);
y_tr = Datay(idx_tr);    y_te = Datay(idx_te);

% --- Train-only zscore ---
[X_tr_z, muX, sdX] = zscore(X_tr); sdX(sdX<eps)=1;
X_te_z = (X_te - muX) ./ sdX;
[y_tr_z, muy, sdy] = zscore(y_tr); sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

% --- Build lagged design (no leakage) ---
[Phi_tr, y_tr_aligned,maxLag] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
beta         = Phi_tr \ y_tr_aligned;
yhat_tr_scal = Phi_tr * beta;
yhat_te_scal = Phi_te  * beta;

% --- Invert y scaling & align ---
yhat_tr = yhat_tr_scal * sdy + muy;
yhat_te = yhat_te_scal * sdy + muy;
y_tr_raw_aligned = y_tr((maxLag+1):end);
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_tr_full = NaN(Ntr,1);           yhat_tr_full((maxLag+1):end) = yhat_tr;
yhat_te_full = NaN(T-Ntr,1);         yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_tr_full; yhat_te_full];

% --- METRICS ---
rmse_tr = sqrt(mean((y_tr_raw_aligned - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw_aligned - yhat_te).^2));


dFk_reg = [zeros(length(data.dFk) - length(yhat_all_full),1);yhat_all_full];

reg.dFk = dFk_reg;

time_reg = d.timeBlue(startIdx:endIdx);
reg.t = time_reg;

reg.dFk = dFk_reg;
reg.t = time_reg;


%

reg = regData(reg,d,data);
close all


figure()
plot(reg.er_ncDfk,'or');hold on
plot(reg.er_wcDfk,'og');


figure()
plot(reg.er_ncDfk,data.er_ncDfk,'or');hold on
plot(reg.er_ncDfk,reg.er_ncDfk,'ok');hold on

ylabel('trial error')
xlabel('recon error')
title('ff')

figure()
plot(reg.er_wcDfk,data.er_wcDfk,'or');hold on
plot(reg.er_wcDfk,reg.er_wcDfk,'ok');hold on

ylabel('trial error')
xlabel('recon error')
title('fb')

% recon


figure()
plot(d.timeBlue,reg.dFk,'r');hold on
plot(d.timeBlue,data.dFk,'g');hold on


%

dur = d.params.dur
t = d.timeBlue;
j=12;
[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'g');hold on
plot(Tout,reg.dFk((i-(3*35)):(i+35*(dur+3))),'r');hold on
plot(Tout,-5*ones(1,length(Tout)))
legend('primary','recon')
xlim([-3,6])
xline(0)
xline(3)
title('trial')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)
title('input')

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('motion')


%% Comparing ff and fb


TestIdxStart = 10000;
TestIdxEnd = 10000;


% custom openloop inputs
inputs_ff = inputs;
for i=1:length(wc)
    [~, j] = min(abs(t - d.stimStarts(wc(i))));
    
    inputs_ff((j+3):(j+35*dur)) = 0.5;
end


% figure()
% plot(inputs);hold on
% plot(inputs_ff)
%%
DataX = [dFkp(2:end,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs_ff(startIdx:endIdx)];

X_te = DataX;
y_te = Datay;
X_te_z = (X_te - muX) ./ sdX;
y_te_z = (y_te - muy) ./ sdy;

[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
yhat_te_scal = Phi_te  * beta;

  
% --- Invert y scaling & align ---
yhat_te = yhat_te_scal * sdy + muy;
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_te_full = NaN(T,1);           
% yhat_te_full((maxLag+1):end) = yhat_te;
% yhat_all_full = [yhat_te_full];



dFk_reg_test = [zeros(length(data.dFk) - length(yhat_te),1);yhat_te];
reg_test.dFk = dFk_reg_test;


time_reg = d.timeBlue(startIdx:endIdx);
reg_test.t = time_reg;

reg_test.dFk = dFk_reg_test;
reg_test.t = time_reg;
% 
% 
% %
% 
reg_test = regData(reg_test,d,data);

close all


% figure()
% plot(reg.er_ncDfk,'or');hold on
% plot(reg.er_wcDfk,'og');
% 
% 
% figure()
% plot(reg.er_ncDfk,data.er_ncDfk,'or');hold on
% plot(reg.er_ncDfk,reg.er_ncDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('ff')
% 
% figure()
% plot(reg.er_wcDfk,data.er_wcDfk,'or');hold on
% plot(reg.er_wcDfk,reg.er_wcDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('fb')
% 
% % recon
% 
% 
% figure()
% plot(d.timeBlue,reg.dFk,'r');hold on
% plot(d.timeBlue,data.dFk,'g');hold on


%

dur = d.params.dur
t = d.timeBlue;
j=5;

j = wc(j);

[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'g');hold on
plot(Tout,reg.dFk((i-(3*35)):(i+35*(dur+3))),'r');hold on
plot(Tout,reg_test.dFk((i-(3*35)):(i+35*(dur+3))),'k');hold on

plot(Tout,-5*ones(1,length(Tout)))
legend('primary','recon')
xlim([-3,6])
xline(0)
xline(3)
title('trial')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))
xlim([-3,6])
xline(0)
xline(3)
title('input')

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('motion')




%%

dFkp_contra = dFkp(d.params.pix_ids,:);
%% 

dFk_inv = get_dFoF(d,d.params.pix_inv,serverRoot);
%%
close all;

% indices
startIdx = 2000
Train_length = length(d.timeBlue) - startIdx;
endIdx = startIdx + Train_length

T = Train_length;
rng(0);

% rnd pixels
% a = 2; b = 15; n = 5;                              % require n <= b-a+1
% k = a - 1 + randperm(b - a + 1, n);                % 1×n row vector
k = k(:); 
% k=[6,10]
% n-dimensional X (here n = 3)
n = 1;


% DataX = [dFkp(k,startIdx:endIdx)'];

% DataX = [dFkp(k,startIdx:endIdx)',inputs(startIdx:endIdx)];
% DataX = [dFkp_contra(:,startIdx:endIdx)',d.mv(startIdx:endIdx)];
DataX = [dFk_inv(:,startIdx:endIdx)'];

% DataX = [d.mv(startIdx:endIdx),inputs(startIdx:endIdx),];

Datay = dFk(startIdx:endIdx)';


pY = 0;
pX = 5;


% --- Split ---
train_ratio = 0.7;
Ntr = floor(train_ratio*T);
idx_tr = 1:Ntr; idx_te = (Ntr+1):T;
X_tr = DataX(idx_tr,:);  X_te = DataX(idx_te,:);
y_tr = Datay(idx_tr);    y_te = Datay(idx_te);

% --- Train-only zscore ---
[X_tr_z, muX, sdX] = zscore(X_tr); sdX(sdX<eps)=1;
X_te_z = (X_te - muX) ./ sdX;
[y_tr_z, muy, sdy] = zscore(y_tr); sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

% --- Build lagged design (no leakage) ---
[Phi_tr, y_tr_aligned,maxLag] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
beta         = Phi_tr \ y_tr_aligned;
yhat_tr_scal = Phi_tr * beta;
yhat_te_scal = Phi_te  * beta;

% --- Invert y scaling & align ---
yhat_tr = yhat_tr_scal * sdy + muy;
yhat_te = yhat_te_scal * sdy + muy;
y_tr_raw_aligned = y_tr((maxLag+1):end);
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_tr_full = NaN(Ntr,1);           yhat_tr_full((maxLag+1):end) = yhat_tr;
yhat_te_full = NaN(T-Ntr,1);         yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_tr_full; yhat_te_full];

% --- METRICS ---
rmse_tr = sqrt(mean((y_tr_raw_aligned - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw_aligned - yhat_te).^2));
fprintf('maxLag=%d | RMSE Train=%.6f  Test=%.6f\n', maxLag, rmse_tr, rmse_te);

% %% --- PLOTS: RECONSTRUCTION ---
% % 1) Full-series reconstruction (with NaNs up front)
%
figure('Name','Full Reconstruction','NumberTitle','off');
plot(1:T+1, Datay, 'LineWidth', 1); hold on;
plot(1:T, yhat_all_full, 'LineWidth', 1);
xlabel('t'); ylabel('y');
title('Actual vs Predicted (Full Series)');
legend('Actual y','Predicted \hat{y}','Location','best'); grid on;
%
% 2) Test-slice reconstruction only
figure('Name','Test Reconstruction','NumberTitle','off');
t_test = (Ntr+1):T;  % original-time indices for test region
plot(t_test, Datay(t_test), 'LineWidth', 1); hold on;
plot(t_test, yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('y');
title('Actual vs Predicted (Test Segment)');
legend('Actual y (test)','Predicted \hat{y} (test)','Location','best'); grid on;

% 3) Test residuals
figure('Name','Test Residuals','NumberTitle','off');
plot(t_test, Datay(t_test) - yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('Residual'); grid on;
title('Residuals on Test Segment');
  


% filler data

dFk_reg = [zeros(length(data.dFk) - length(yhat_all_full),1);yhat_all_full];

dFk_reg_test = [zeros(length(data.dFk) - length(yhat_te),1);yhat_te];
reg_test.dFk = dFk_reg_test;


time_reg = d.timeBlue(startIdx:endIdx);
reg_test.t = time_reg;

reg_test.dFk = dFk_reg_test;
reg_test.t = time_reg;
% 
% 
% %
% 
reg_test = regData(reg_test,d,data);

%% Average contrallateral activities

dFk_base = [];

close all;
figure()
for k = 1:length(d.params.pix_ids)
% for k = 1:1
    dF_data=[];
    for j=1:length(wc)
        s = wc(j);

        [a i] = min(abs(t - d.stimStarts(s)));
        
        dF_data = [dF_data;dFkp_contra(k,i-35*1:i+35*(dur+1))];


    end
    dFk_base = [dFk_base;mean(dF_data,1)];

plot(dFk_base(end,:),'LineWidth',2);hold on;
end

plot(dFk_base(1,:),'r','LineWidth',3);
plot(mean(data.wcDfk,1),'g','LineWidth',3);



dFk_base = [];
figure()
for k = 1:length(d.params.pix_ids)
% for k = 1:1
    dF_data=[];
    for j=1:length(nc)
        s =nc(j);
        [a i] = min(abs(t - d.stimStarts(s)));
        
        dF_data = [dF_data;dFkp_contra(k,i-35*1:i+35*(dur+1))];


    end
    dFk_base = [dFk_base;mean(dF_data,1)];

plot(dFk_base(end,:),'LineWidth',2);hold on;
end

plot(dFk_base(1,:),'r','LineWidth',3);
plot(mean(data.ncDfk,1),'g','LineWidth',3);



pred_wc=[];
DFk_inv_prestim_wc = [];
for j=1:length(wc)
        s = wc(j);

        [a i] = min(abs(t - d.stimStarts(s)));
        
        pred_wc = [pred_wc;dFk(i-35*(2):i+35*(dur+1))];

        DFk_inv_prestim_wc = [DFk_inv_prestim_wc;dFk_inv(i-35*10:i)];

end

pred_wc = mean(pred_wc,1);

pred_nc=[];
DFk_inv_prestim_nc=[];
for j=1:length(nc)
        s =nc(j);
        [a i] = min(abs(t - d.stimStarts(s)));
        
        pred_nc = [pred_nc;dFk(i-35*(2):i+35*(dur+1))];

        DFk_inv_prestim_nc = [DFk_inv_prestim_nc;dFk_inv(i-35*10:i)];

end
pred_nc = mean(pred_nc,1);


figure()
plot(pred_wc,'r','LineWidth',2);hold on
plot(pred_nc,'g','LineWidth',2);hold on

%% Test


startIdx = 2000
Train_length = length(d.timeBlue) - startIdx;
endIdx = startIdx + Train_length

T = Train_length;


% DataX = [dFk_inv(:,startIdx:endIdx)', inputs(startIdx:endIdx)];
DataX = [dFk_inv(:,startIdx:endIdx)'];

% DataX = [dFkp(2:end,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs_ff(startIdx:endIdx)];
pY = 0;
pX = 70;

X_te = DataX;
y_te = Datay;
X_te_z = (X_te - muX) ./ sdX;
y_te_z = (y_te - muy) ./ sdy;

[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
beta         = Phi_te \ y_te_aligned;
yhat_te_scal = Phi_te  * beta;

  
% --- Invert y scaling & align ---
yhat_te = yhat_te_scal * sdy + muy;
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_te_full = NaN(T+1,1);           
yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_te_full];



dFk_reg = [zeros(length(data.dFk) - length(yhat_all_full),1);yhat_all_full];
reg.dFk = dFk_reg;
time_reg = d.timeBlue(startIdx:endIdx);
reg.t = time_reg;
reg.dFk = dFk_reg;
reg.t = time_reg;
reg = regData(reg,d,data);


dFk_reg_test = [zeros(length(data.dFk) - length(yhat_te),1);yhat_te];
reg_test.dFk = dFk_reg_test;


time_reg = d.timeBlue(startIdx:endIdx);
reg_test.t = time_reg;

reg_test.dFk = dFk_reg_test;
reg_test.t = time_reg;
% 
% 
% %
% 
reg_test = regData(reg_test,d,data);


close all


% figure()
% plot(reg.er_ncDfk,'or');hold on
% plot(reg.er_wcDfk,'og');
% 
% 
% figure()
% plot(reg.er_ncDfk,data.er_ncDfk,'or');hold on
% plot(reg.er_ncDfk,reg.er_ncDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('ff')
% 
% figure()
% plot(reg.er_wcDfk,data.er_wcDfk,'or');hold on
% plot(reg.er_wcDfk,reg.er_wcDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('fb')
% 
% % recon
% 
% 
% figure()
% plot(d.timeBlue,reg.dFk,'r');hold on
% plot(d.timeBlue,data.dFk,'g');hold on


%%

dur = d.params.dur
t = d.timeBlue;
j=5;

j = wc(j);

[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'g');hold on
% plot(Tout,reg.dFk((i-(3*35)):(i+35*(dur+3))),'r');hold on
plot(Tout,reg_test.dFk((i-(3*35)):(i+35*(dur+3))),'k');hold on


plot(Tout,-5*ones(1,length(Tout)))
legend('primary','recon')
xlim([-3,6])
xline(0)
xline(3)
title('trial')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))

xlim([-3,6])
xline(0)
xline(3)
title('input')

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('motion')



%% Analysis on contralateral prediction

% Use the average response to predic contralateral response


% for i =1: length(wc)
for i =5:5
    s = wc(i);

    [a k] = min(abs(t - d.stimStarts(s)));

    DataX = [dFk_inv(k-35*(2):k+35*4)'];
    Datay = [dFk(k-35*(2):k+35*4)'];

    % DataX = [dFkp(2:end,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs_ff(startIdx:endIdx)];
    pY = 0;
    pX = 70;

    X_te = DataX;
    y_te = Datay;
    X_te_z = (X_te - muX) ./ sdX;
    y_te_z = (y_te - muy) ./ sdy;

[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
yhat_te_scal = Phi_te  * beta;
yhat_te = yhat_te_scal * sdy + muy;
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_te_full = NaN(211,1);           
yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_te_full];
end





%% Using spontaneous data with average input response against contralateral



%% segmented_lagged_regression.m
% Data format:
%   y_mat    : L x S   (L = length per segment, S = #segments)
%   X_tensor : L x n x S   (n = # exogenous inputs) or [] if none
%
% Set pY=0 to exclude y-lags ("no y as input"). Uses MATLAB zscore.




%% --- USER DATA (REPLACE) ---
% Example placeholders (deterministic). Replace y_mat / X_tensor with your own.

% startIdx = 2000
% Train_length = length(d.timeBlue) - startIdx;
% endIdx = startIdx + Train_length
% 
% T = Train_length;
% 
% 
% % DataX = [dFk_inv(:,startIdx:endIdx)', inputs(startIdx:endIdx)];
% DataX = [dFk_inv(:,startIdx:endIdx)'d.mv()];

% DataX = [dFkp(2:end,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs_ff(startIdx:endIdx)];

L = 5*35;
n = 1;
S = length(d.stimStarts);
X_tensor = zeros(L, n, S);
y_mat = NaN(L,S);
ta = (1:L)';

pY = 0; pX = 35; maxLag = max(pY,pX);
for i = 1:length(d.stimStarts)
    [a k] = min(abs(t - d.stimStarts(i)))

    Xtensor(:,:,i) = [dFk_inv(k-35*(5):k)',d.mv(k-35*(5):k)]; 
    % Xtensor(:,:,i) = [dFk_inv(k-35*(5):k)']; 

    y_mat(maxLag+1:L,i) = dFk(k-35*(5)+maxLag+1:k)';
    y_mat(1:maxLag,i) = 1;
end

% L = 200; S = 6; t = (1:L)'; n = 3;
% X_tensor = zeros(L, n, S);
% for s = 1:S
%     X_tensor(:,1,s) = 2.5 + 2.5*sin(2*pi*(t+(s-1)*5)/24); % 0..5-ish
%     X_tensor(:,2,s) = linspace(0, 1e6, L)';               % 0..1e6 ramp
%     X_tensor(:,3,s) = (-1).^(floor((t+(s-1)*20)/40));     % {-1,1} blocks
% end
% True model (no y-lags)

 
% pY = 0; pX = 35; maxLag = max(pY,pX);
% b0 = 10;
% y_mat = NaN(L,S);
% for s = 1:S
% 
%     y_mat(:, s) = d.dFk();
%     for tt = (maxLag+1):L
%         y_mat(tt,s) = b0 ...
%             + 0.7   * X1(tt-1) ...
%             + 0.8e-6* X2(tt-2) ...
%             - 0.6   * X3(tt-1);
%     end
%     y_mat(1:maxLag,s) = b0; % fill first maxLag (or leave NaN)
% end

%% --- TRAIN/TEST SPLIT BY SEGMENTS ---
train_ratio_segments = 0.6;               % e.g., 2/3 of segments for train
Str = max(1, floor(train_ratio_segments * S));
trainSegs = 1:Str;                          % simple: first Str segments
testSegs  = (Str+1):S;

%% --- SCALE WITH MATLAB zscore (TRAIN SEGMENTS ONLY) ---
% Stack train segments vertically to compute per-column stats
y_tr_stack = y_mat(:, trainSegs); y_tr_stack = y_tr_stack(:);
[y_tr_z, muy, sdy] = zscore(y_tr_stack); sdy = max(sdy, eps);

if ~isempty(X_tensor)
    X_tr_stack = reshape(X_tensor(:, :, trainSegs), [], n);  % (L*Str) x n
    [X_tr_z_stack, muX, sdX] = zscore(X_tr_stack); sdX(sdX<eps) = 1;
    % Apply to all segments
    X_z = zeros(size(X_tensor));
    for s = 1:S
        Xz_s = reshape(X_tensor(:, :, s), [], n);
        Xz_s = (Xz_s - muX) ./ sdX;          % train stats applied
        X_z(:, :, s) = reshape(Xz_s, L, n);
    end
else
    X_z = [];
end
% Apply y scaling to all segments
y_z = (y_mat - muy) ./ sdy;

%% --- BUILD DESIGN MATRICES (NO LEAKAGE, WITHIN-SEGMENT LAGS) ---
[Phi_tr, y_tr_vec, maxLag, seg_tr, t_tr] = ...
    buildLagMatrix_segments(y_z(:, trainSegs), X_z(:, :, trainSegs), pY, pX);

[Phi_te, y_te_vec] = deal([]); seg_te=[]; t_te=[];
if ~isempty(testSegs)
    [Phi_te, y_te_vec, ~, seg_te, t_te] = ...
        buildLagMatrix_segments(y_z(:, testSegs), X_z(:, :, testSegs), pY, pX);
end

%% --- FIT & PREDICT IN SCALED SPACE ---
beta = Phi_tr \ y_tr_vec;
yhat_tr_scaled = Phi_tr * beta;
yhat_te_scaled = []; if ~isempty(Phi_te), yhat_te_scaled = Phi_te * beta; end

%% --- INVERT y SCALING TO ORIGINAL UNITS ---
yhat_tr = yhat_tr_scaled * sdy + muy;
yhat_te = yhat_te_scaled * sdy + muy;

%% --- RECONSTRUCT PREDICTIONS BACK TO SEGMENTS (L x S) ---
yhat_mat = NaN(L, S);
% Fill train segments
k = 0;
for sLocal = 1:numel(trainSegs)
    s = trainSegs(sLocal);
    for ta = (maxLag+1):L
        k = k + ta;
        yhat_mat(ta, s) = yhat_tr(k);
    end
end
% Fill test segments
k = 0;
for sLocal = 1:numel(testSegs)
    s = testSegs(sLocal);
    for ta = (maxLag+1):L
        k = k + 1;
        yhat_mat(ta, s) = yhat_te(k);
    end
end


%% ------------------ PLOTS: Validation & Test Reconstructions ------------------
% Per-segment overlays for VALIDATION
if ~isempty(valSegs)
    figure('Name','Validation Segments: Actual vs Predicted','NumberTitle','off');
    tiledlayout(numel(valSegs),1,'TileSpacing','compact','Padding','compact');
    for idx = 1:numel(valSegs)
        s = valSegs(idx);
        nexttile;
        plot(1:L, y_mat(:,s), 'LineWidth', 1); hold on;
        plot(1:L, yhat_mat(:,s), 'LineWidth', 1);
        grid on; ylabel(sprintf('seg %d', s));
        if idx==1, title('Validation: Actual vs Predicted'); end
        if idx==numel(valSegs), xlabel('t'); end
        xline(maxLag+0.5, ':'); % prediction starts
        legend({'Actual','Predicted'},'Location','best'); legend boxoff;
    end
end

% Per-segment overlays for TEST
if ~isempty(testSegs)
    figure('Name','Test Segments: Actual vs Predicted','NumberTitle','off');
    tiledlayout(numel(testSegs),1,'TileSpacing','compact','Padding','compact');
    for idx = 1:numel(testSegs)
        s = testSegs(idx);
        nexttile;
        plot(1:L, y_mat(:,s), 'LineWidth', 1); hold on;
        plot(1:L, yhat_mat(:,s), 'LineWidth', 1);
        grid on; ylabel(sprintf('seg %d', s));
        if idx==1, title('Test: Actual vs Predicted'); end
        if idx==numel(testSegs), xlabel('t'); end
        xline(maxLag+0.5, ':'); % prediction starts
        legend({'Actual','Predicted'},'Location','best'); legend boxoff;
    end
end


%% Test


startIdx = 2000
Train_length = length(d.timeBlue) - startIdx;
endIdx = startIdx + Train_length

T = Train_length;


% DataX = [dFk_inv(:,startIdx:endIdx)', inputs(startIdx:endIdx)];
DataX = [dFk_inv(:,startIdx:endIdx)'];
DataY = dFk(startIdx:endIdx)';
% DataX = [dFkp(2:end,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs_ff(startIdx:endIdx)];
pY = 0;
pX = 70;

X_te = DataX;
y_te = Datay;
X_te_z = (X_te - muX) ./ sdX;
y_te_z = (y_te - muy) ./ sdy;

[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
beta         = Phi_te \ y_te_aligned;
yhat_te_scal = Phi_te  * beta;

  
% --- Invert y scaling & align ---
yhat_te = yhat_te_scal * sdy + muy;
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_te_full = NaN(T+1,1);           
yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_te_full];



dFk_reg = [zeros(length(data.dFk) - length(yhat_all_full),1);yhat_all_full];
reg.dFk = dFk_reg;
time_reg = d.timeBlue(startIdx:endIdx);
reg.t = time_reg;
reg.dFk = dFk_reg;
reg.t = time_reg;
reg = regData(reg,d,data);


dFk_reg_test = [zeros(length(data.dFk) - length(yhat_te),1);yhat_te];
reg_test.dFk = dFk_reg_test;


time_reg = d.timeBlue(startIdx:endIdx);
reg_test.t = time_reg;

reg_test.dFk = dFk_reg_test;
reg_test.t = time_reg;
% 
% 
% %
% 
reg_test = regData(reg_test,d,data);


close all


% figure()
% plot(reg.er_ncDfk,'or');hold on
% plot(reg.er_wcDfk,'og');
% 
% 
% figure()
% plot(reg.er_ncDfk,data.er_ncDfk,'or');hold on
% plot(reg.er_ncDfk,reg.er_ncDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('ff')
% 
% figure()
% plot(reg.er_wcDfk,data.er_wcDfk,'or');hold on
% plot(reg.er_wcDfk,reg.er_wcDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('fb')
% 
% % recon
% 
% 
% figure()
% plot(d.timeBlue,reg.dFk,'r');hold on
% plot(d.timeBlue,data.dFk,'g');hold on


%

dur = d.params.dur
t = d.timeBlue;
j=33;

j = wc(j);

[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'g');hold on
% plot(Tout,reg.dFk((i-(3*35)):(i+35*(dur+3))),'r');hold on
plot(Tout,reg_test.dFk((i-(3*35)):(i+35*(dur+3))),'k');hold on


plot(Tout,-5*ones(1,length(Tout)))
legend('primary','recon')
xlim([-3,6])
xline(0)
xline(3)
title('trial')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))

xlim([-3,6])
xline(0)
xline(3)
title('input')

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('motion')



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'g');hold on
% plot(Tout,reg.dFk((i-(3*35)):(i+35*(dur+3))),'r');hold on
plot(Tout,reg_test.dFk((i-(3*35)):(i+35*(dur+3)))+avg_nc','k');hold on


plot(Tout,-5*ones(1,length(Tout)))
legend('primary','recon')
xlim([-3,6])
xline(0)
xline(3)
title('trial')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))

xlim([-3,6])
xline(0)
xline(3)
title('input')

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('motion')

% Test

%%
startIdx = 2000
Train_length = length(d.timeBlue) - startIdx;
endIdx = startIdx + Train_length

T = Train_length;


% DataX = [dFk_inv(:,startIdx:endIdx)', inputs(startIdx:endIdx)];



% DataX = [dFk_inv(:,startIdx:endIdx)',inputs_ff(startIdx:endIdx)];

DataX = [dFk_inv(:,startIdx:endIdx)'];

% DataX = [dFkp(2:end,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs_ff(startIdx:endIdx)];
pY = 0;
pX = 70;

X_te = DataX;
y_te = Datay;
X_te_z = (X_te - muX) ./ sdX;
y_te_z = (y_te - muy) ./ sdy;

[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
beta         = Phi_te \ y_te_aligned;
yhat_te_scal = Phi_te  * beta;

  
% --- Invert y scaling & align ---
yhat_te = yhat_te_scal * sdy + muy;
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_te_full = NaN(T+1,1);           
yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_te_full];



dFk_reg = [zeros(length(data.dFk) - length(yhat_all_full),1);yhat_all_full];
reg.dFk = dFk_reg;
time_reg = d.timeBlue(startIdx:endIdx);
reg.t = time_reg;
reg.dFk = dFk_reg;
reg.t = time_reg;
reg = regData(reg,d,data);


dFk_reg_test = [zeros(length(data.dFk) - length(yhat_te),1);yhat_te];
reg_test.dFk = dFk_reg_test;


time_reg = d.timeBlue(startIdx:endIdx);
reg_test.t = time_reg;

reg_test.dFk = dFk_reg_test;
reg_test.t = time_reg;
% 
% 
% %
% 
reg_test = regData(reg_test,d,data);




% figure()
% plot(reg.er_ncDfk,'or');hold on
% plot(reg.er_wcDfk,'og');
% 
% 
% figure()
% plot(reg.er_ncDfk,data.er_ncDfk,'or');hold on
% plot(reg.er_ncDfk,reg.er_ncDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('ff')
% 
% figure()
% plot(reg.er_wcDfk,data.er_wcDfk,'or');hold on
% plot(reg.er_wcDfk,reg.er_wcDfk,'ok');hold on
% 
% ylabel('trial error')
% xlabel('recon error')
% title('fb')
% 
% % recon
% 
% 
% figure()
% plot(d.timeBlue,reg.dFk,'r');hold on
% plot(d.timeBlue,data.dFk,'g');hold on


%

dur = d.params.dur
t = d.timeBlue;
j=33;

j = wc(j);

[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'g');hold on
% plot(Tout,reg.dFk((i-(3*35)):(i+35*(dur+3))),'r');hold on
plot(Tout,reg_test.dFk((i-(3*35)):(i+35*(dur+3))),'k');hold on


plot(Tout,-5*ones(1,length(Tout)))
legend('primary','recon')
xlim([-3,6])
xline(0)
xline(3)
title('trial')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))

xlim([-3,6])
xline(0)
xline(3)
title('input')

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('motion')
%%

figure()
plot(data.wcmotion')


anc = mean(data.pncDfk(:,10*35:13*35),1);
awc = mean(data.pncDfk(:,10*35:13*35),1);

avg_nc = zeros(1,316);
avg_wc = zeros(1,316);

avg_nc(3*35:6*35) = anc;
avg_wc(3*35:6*35) = awc;

figure()
plot(data.ncDfk');hold on;
plot(avg_nc,'k','LineWidth',3);
% dFkp_contra = 
%% Motion vs error grid


% during trial motion content
motion_metric_wc = sum(data.wcmotion(:,9*35:13*35),2);
motion_metric_nc = sum(data.ncmotion(:,9*35:14*35),2);


% prediction difference



dur = d.params.dur
t = d.timeBlue;
j=9;

j = wc(j);

[a i] = min(abs(t - d.stimStarts(j)));
[a i2] = min(abs(t - d.stimEnds(j)));


tt = d.inpTime;
v = d.inpVals;

[a k] = min(abs(tt - d.stimStarts(j)));
[a k2] = min(abs(tt - d.stimEnds(j)));



% Tin = 0:0.0005:stimDur(j);
Tout = -3:0.0285:dur+3;
figure()
subplot(3,1,1)
plot(Tout,dFk((i-(3*35)):(i+35*(dur+3))),'g');hold on
% plot(Tout,reg.dFk((i-(3*35)):(i+35*(dur+3))),'r');hold on
plot(Tout,reg_test.dFk((i-(3*35)):(i+35*(dur+3))) + avg_nc','k');hold on
% plot(Tout,reg_test.dFk((i-(3*35)):(i+35*(dur+3))),'k');hold on


plot(Tout,-5*ones(1,length(Tout)))
legend('primary','recon')
xlim([-3,6])
xline(0)
xline(3)
title('trial')

subplot(3,1,2)
% plot(tt(k:k2)-tt(k),v(k:k2));
plot(tt(k:k2)-tt(k),v(k:k2))

xlim([-3,6])
xline(0)
xline(3)
title('input')

subplot(3,1,3)
plot(Tout,d.mv((i-(3*35)):(i+35*(dur+3))));hold on
plot(Tout,5*ones(1,length(Tout)))
xlim([-3,6])
xline(0)
xline(3)
title('motion')

%%
pdiff_nc=[];
for j = 1: length(nc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));

    % prediction difference
    er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))) + avg_nc(3*35:6*35)')
        % er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))) )

    pdiff_nc=[pdiff_nc;er];

   
    
end

pdiff_wc=[];
for j = 1: length(wc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));

    er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))) + avg_wc(3*35:6*35)')
        % er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))))

    pdiff_wc=[pdiff_wc;er];
    
end


%%

figure()
plot(motion_metric_nc,pdiff_nc,'or','Linewidth',2);hold on
plot(motion_metric_wc,pdiff_wc,'og','Linewidth',2);

%%
%
%
%
%
%
%
%
%
%
%
%
%
%
%
%
%%


startIdx = 2000
Train_length = length(d.timeBlue) - startIdx;
endIdx = startIdx + Train_length

T = Train_length;


% DataX = [dFk_inv(:,startIdx:endIdx)', inputs(startIdx:endIdx)];
pDiff_nc = pdiff_nc;
pDiff_wc = pdiff_wc;
for s = 1:7

% DataX = [dFk_inv(:,startIdx:endIdx)',inputs_ff(startIdx:endIdx)];

% DataX = [dFkp_contra(s,startIdx:endIdx)',inputs_ff(startIdx:endIdx)];


DataX = [dFkp_contra(s,startIdx:endIdx)'];


% DataX = [dFk_inv(:,startIdx:endIdx)'];

% DataX = [dFkp(2:end,startIdx:endIdx)',d.mv(startIdx:endIdx),inputs_ff(startIdx:endIdx)];
pY = 0;
pX = 70;

X_te = DataX;
y_te = Datay;
X_te_z = (X_te - muX) ./ sdX;
y_te_z = (y_te - muy) ./ sdy;

[Phi_te, y_te_aligned,maxLag] = buildLagMatrix(y_te_z, X_te_z, pY, pX);

% --- Fit & predict (scaled space) ---
beta         = Phi_te \ y_te_aligned;
yhat_te_scal = Phi_te  * beta;

  
% --- Invert y scaling & align ---
yhat_te = yhat_te_scal * sdy + muy;
y_te_raw_aligned = y_te((maxLag+1):end);

% Put back onto original time axis (NaNs for first maxLag of each split)
yhat_te_full = NaN(T+1,1);           
yhat_te_full((maxLag+1):end) = yhat_te;
yhat_all_full = [yhat_te_full];



dFk_reg = [zeros(length(data.dFk) - length(yhat_all_full),1);yhat_all_full];
reg.dFk = dFk_reg;
time_reg = d.timeBlue(startIdx:endIdx);
reg.t = time_reg;
reg.dFk = dFk_reg;
reg.t = time_reg;
reg = regData(reg,d,data);


dFk_reg_test = [zeros(length(data.dFk) - length(yhat_te),1);yhat_te];
reg_test.dFk = dFk_reg_test;


time_reg = d.timeBlue(startIdx:endIdx);
reg_test.t = time_reg;

reg_test.dFk = dFk_reg_test;
reg_test.t = time_reg;
% 
% 
% %
% 
reg_test = regData(reg_test,d,data);




pdiff_nc=[];
for j = 1: length(nc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(nc(j))));

    % prediction difference
    er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))) + avg_nc(3*35:6*35)')
        % er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))) )

    pdiff_nc=[pdiff_nc;er];

   
    
end

pdiff_wc=[];
for j = 1: length(wc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(wc(j))));

    er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))) + avg_wc(3*35:6*35)')
        % er = norm(dFk(i:i+35*(dur))' - reg_test.dFk(i:(i+35*(dur))))

    pdiff_wc=[pdiff_wc;er];
    
end


pDiff_nc=[pDiff_nc,pdiff_nc];
pDiff_wc=[pDiff_wc,pdiff_wc];
end


%%
close all;

figure()
subplot(2,2,1)
imagesc(pDiff_wc');
colorbar;
caxis([50 100]);
colormap(parula)
% axis equal tight;
title('closed loop')

subplot(2,2,3)
imagesc(motion_metric_wc');
colorbar;
caxis([0 4e8]);
% axis equal tight;
% plot(motion_metric_wc);

0
subplot(2,2,2)
imagesc(pDiff_nc');
colorbar;
caxis([50 100]);
% axis equal tight;
title('open loop')

subplot(2,2,4)
imagesc(motion_metric_nc');
colormap(hot)
colorbar;
caxis([0 4e8]);
% axis equal tight;

%% Variance Plot


wcvar=[];

for j = 1: length(data.wc)
    [a i] = min(abs(d.timeBlue - d.stimStarts(data.wc(j))));
    wcvar = [wcvar; dFk(i:i+35*(d.params.dur)) + 5];

end
wcvar = [wcvar; dFk(i:i+35*(d.params.dur))];


Wcerr=[];
Wcvar=[];
for i = 10:10:10
    wwc = wcvar(randi([1 100], i, 1),:);
    WCerr = vecnorm(wwc,1,2);
    Wcvar = var(wwc')
end
%%

%% -------------------------
% Build wcvar (trials x time)
%% -------------------------
wcvar = [];

for j = 1:length(data.wc)
    [~, idx] = min(abs(d.timeBlue - d.stimStarts(data.wc(j))));
    wcvar = [wcvar; dFk(idx:idx + 35*(d.params.dur)) + 5];
end

% NOTE: Your original code had this extra append line:
% wcvar = [wcvar; dFk(i:i+35*(d.params.dur))];
% It uses "i" from later / wrong scope. Likely a bug, so I'm leaving it out.

nTrials = size(wcvar, 1);

%% -----------------------------------------
% Bootstrap sizes and store variable-length outputs
%% -----------------------------------------
sizes = 10:10:100;

Wcerr_cell = cell(numel(sizes), 1);
Wcvar_cell = cell(numel(sizes), 1);

% For boxplots: collect all values + group labels
allErr  = [];
grpErr  = [];

allVar  = [];
grpVar  = [];

for k = 1:numel(sizes)
    n = sizes(k);

    % sample n rows (with replacement) from wcvar
    pick = randi([1 100], n, 1);
    wwc  = wcvar(pick, :);

    % per-trial L1 norm across time (n x 1)
    WCerr = vecnorm(wwc, 2, 2);

    % per-trial variance across time (1 x n) -> make it (n x 1)
    Wcvar = var(wwc, 0, 2);   % variance across columns (time), returns (n x 1)

    % save (variable length each iteration)
    Wcerr_cell{k} = WCerr;
    Wcvar_cell{k} = Wcvar;

    % accumulate for boxplots
    allErr = [allErr; WCerr];
    grpErr = [grpErr; repmat(n, n, 1)];

    allVar = [allVar; Wcvar];
    grpVar = [grpVar; repmat(n, n, 1)];
end


figure;
boxplot(allErr, grpErr);
xlabel('n (rows sampled)');
ylabel('WCerr = L1 norm per trial');
title('WCerr across bootstrap sizes');

figure;
boxplot(allVar, grpVar);
xlabel('n (rows sampled)');
ylabel('Wcvar = variance across time per trial');
title('Wcvar across bootstrap sizes');