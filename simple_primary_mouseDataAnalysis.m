%% Data analysis Script

clc;
close all;
clear all;

%% Experiment name

% With rewards
mn = 'AL_0033'; td = '2025-03-04'; en = 1;
% mn = 'AL_0033'; td = '2025-03-04'; en = 2;
% mn = 'AL_0033'; td = '2025-03-05'; en = 2;
% mn = 'AL_0033'; td = '2025-03-18'; en = 1;
% mn = 'AL_0033'; td = '2025-03-20'; en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; en = 2;
% mn = 'AL_0033'; td = '2025-04-18'; en = 4;
% mn = 'AL_0033'; td = '2025-04-19'; en = 1;
% mn = 'AL_0033'; td = '2025-04-20'; en = 2;

% NEW LASER
% mn = 'AL_0039'; td = '2025-04-19'; en = 1;
% mn = 'AL_0039'; td = '2025-04-20'; en = 1;
% mn = 'AL_0039'; td = '2025-04-20'; en = 2;
% mn = 'AL_0039'; td = '2025-04-30'; en = 3;

% No Reward, high controller delay
% mn = 'AL_0033'; td = '2024-12-18'; en = 4;
% mn = 'AL_0033'; td = '2024-12-19'; en = 2;
% mn = 'AL_0033'; td = '2024-12-20'; en = 7;
% mn = 'AL_0033'; td = '2024-12-23'; en = 1;
% mn = 'AL_0033'; td = '2025-01-20'; en = 3;
% mn = 'AL_0033'; td = '2025-02-12'; en = 2;
% mn = 'AL_0033'; td = '2025-02-24'; en = 2;
% mn = 'AL_0033'; td = '2025-02-26'; en = 2;

% AL_0041 candidates
% mn = 'AL_0041'; td = '2025-11-05'; en = 3;
% mn = 'AL_0041'; td = '2025-11-12'; en = 1;
% mn = 'AL_0041'; td = '2025-12-10'; en = 1;

% mn = 'AL_0041'; td = '2026-04-13'; en = 3;

%% Get data
pathString = genpath('utils');
addpath(pathString);
d = initialize_data(mn, en, td);

%%


% if isfield(d, 'input_params') && size(d.input_params, 2) >= 16
%     d.unique_xy = unique(d.input_params(:, [15 16]), 'rows');
%     disp('Unique [x y] coordinates from d.input_params columns 15 and 16:');
%     disp(d.unique_xy);
% else
%     warning('d.input_params is missing or does not include columns 15 and 16.');
%     d.unique_xy = [];
% end

%% Run Movie
try
    sigName = 'lightCommand594';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
catch
    sigName = 'lightCommand';
    [tt, v] = getTLanalog(mn, td, en, sigName);
    serverRoot = expPath(mn, td, en);
end

tInd          = 1;
traces(tInd).t    = tt;
traces(tInd).v    = v;
traces(tInd).name = sigName;
traces(tInd).lims = [0 5];
nSV = 500;
[U, V, t, mimg] = loadUVt(serverRoot, nSV);

%% Select pixel via interactive image
% svdImage   = mimg;
% initBregma = [];
% [clickData, mmData, clickPixelCoords, bregmaOffset] = openSVDImageClick(svdImage, initBregma, 0.0173);
% d.params.selected_pixels = clickPixelCoords;
% 
% if ~isempty(bregmaOffset)
%     d.params.pix_inv = bregmaOffset;
%     fprintf('Saved bregma offset -> x=%d, y=%d\n', d.params.pix_inv(1), d.params.pix_inv(2));
% end
% 
% if mmData.isValid
%     d.params.pixel       = [mmData.col, mmData.row];
%     d.params.pixel_value = mmData.value;
%     fprintf('MM-selected pixel -> x=%d, y=%d, value=%g\n', d.params.pixel(1), d.params.pixel(2), d.params.pixel_value);
% elseif ~isempty(clickData)
%     d.params.pixel       = [clickData(1,2), clickData(1,1)];
%     d.params.pixel_value = clickData(1,3);
%     fprintf('Selected pixel -> x=%d, y=%d, value=%g\n', d.params.pixel(1), d.params.pixel(2), d.params.pixel_value);
% elseif isfield(d.params, 'pixel') && numel(d.params.pixel) == 2
%     d.params.pixel_value = svdImage(d.params.pixel(2), d.params.pixel(1));
%     fprintf('Using existing d.params.pixel -> x=%d, y=%d, value=%g\n', d.params.pixel(1), d.params.pixel(2), d.params.pixel_value);
% end

%% Convert mm coordinates to pixels
% if ~isempty(d.unique_xy) && isfield(d.params, 'pix_inv') && numel(d.params.pix_inv) == 2
%     d.params.pixels = convertXYmmToPixels(d.unique_xy, d.params.pix_inv, 0.0173);
% else
%     d.params.pixels = d.unique_xy;
%     warning('Could not convert unique_xy to pixels; using d.unique_xy directly.');
% end

d.params.pix_ids = [2, 4, 5, 8, 9, 12, 13];

figure()
imagesc(mimg); hold on;
plot(d.params.pixels(1,1), d.params.pixels(1,2), 'ok', 'LineWidth', 5)

%% Load pixel dF/F
mode = 0;  % from binary image
r    = 1;  % read file
[data, dFk_temp] = getpixel_dFoF(d, mode, d.params.pixels, r);
dFk = data.dFk;

data_pix = getpixels_dFoF(d);
dFkp = data_pix.dFk;

%% Trial sample visualization
% d.stimStarts = d.stimStarts - 2;
dur = d.params.dur;
t   = d.timeBlue;
tt  = d.inpTime;
v   = d.inpVals;

close all;
plotTrialSample(60, t, dFk, d, tt, v, dur);

%% Feedforward vs Feedback
trials = 100;
d.ref  = -5;
data   = controllerData(data, d, trials);

%% Plots
analysisPlots(data, d, 0);
% analysisPlots_paper(data, d, 0);

%% Trial stamps, invariance, features
nc = data.nc;
wc = data.wc;
% invarianceAnalysis(data, d);

features = feature_analysis(dFk, d, data);
mf = features.mf;
v1 = features.v1;
v2 = features.v2;
v3 = features.v3;

%% Load Motion

d.motion = load(append(serverRoot,'/face_proc.mat'));
%%
d.mv = d.motion.motion_1(1:2:end-1);


%%

svdMotionPlayer(U, V, t, mimg, d.mv)



%% Initial conditions (vectorized)
stimIdx = zeros(numel(d.stimStarts), 1);
for j = 1:numel(d.stimStarts)
    [~, stimIdx(j)] = min(abs(t - d.stimStarts(j)));
end
X0    = dFk(stimIdx)';
X0_wc = X0(wc);
X0_nc = X0(nc);

%% MSE wrt initial condition
figure()
plot(abs(X0_nc + 5), data.er_ncDfk, 'or', 'LineWidth', 3); hold on;
plot(abs(X0_wc + 5), data.er_wcDfk, 'og', 'LineWidth', 3);
shortCornerAxes_plot(gca, 'XLength', 1, 'YLength', 2, ...
    'XLabel', '|y_0 - y_{ref}|', 'YLabel', 'MSE', 'LineWidth', 5, 'LabelGap', 0.04)


%% Analysis based on H2
pixel_test(d, data, dFkp);
dataPixel = pixelAnalysis(d, data, dFkp);
close all;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;
pwcDfk   = data.pwcDfk;
pncDfk   = data.pncDfk;
er       = sort(er_wcDfk);
ner      = sort(er_ncDfk);

%% Analyzer
close all;
i = 15;
motionPlotter(i, d, data, features)

%% Motion sums
ncmotion_pre    = sum(data.ncmotion(:, 1:35*1),    2);
wcmotion_pre    = sum(data.wcmotion(:, 1:35*1),    2);
ncmotion_during = sum(data.ncmotion(:, 35:dur*35), 2);
wcmotion_during = sum(data.wcmotion(:, 35:dur*35), 2);

%% Thresholding
threshold = 30;
close all
figure()
subplot(1,2,1)
scatter3(X0_wc, wcmotion_pre, er_wcDfk, [], er_wcDfk, 'filled', 'g'); hold on
scatter3(X0_nc, ncmotion_pre, er_ncDfk, [], er_ncDfk, 'filled', 'r');
xlabel('x_0 df/F'); ylabel('motion'); zlabel('Tracking error norm')
title('regularizability dependence on motion pre trial')
addThresholdPlane(gca, threshold);

subplot(1,2,2)
scatter3(X0_wc, wcmotion_during, er_wcDfk, [], er_wcDfk, 'filled', 'g'); hold on
scatter3(X0_nc, ncmotion_during, er_ncDfk, [], er_ncDfk, 'filled', 'r');
xlabel('x_0 df/F'); ylabel('motion'); zlabel('Tracking error norm')
title('regularizability dependence on motion during trial')
addThresholdPlane(gca, threshold);

%% Second trial sample
plotTrialSample(50, t, dFk, d, tt, v, dur);

%% Inputs
inputs = d.iputs(d.params.horizon:d.params.horizon + length(d.timeBlue));

%% Linear Regression

% --- USER INPUTS ---
startIdx    = 2000;
endIdx      = length(d.timeBlue);
DataX       = [dFkp(d.params.pix_ids, startIdx:endIdx)', d.mv(startIdx:endIdx), inputs(startIdx:endIdx)];
Datay       = dFk(startIdx:endIdx)';
pY          = 0;
pX          = 5;
train_ratio = 0.7;

% --- REGRESSION PIPELINE ---
T   = endIdx - startIdx;
rng(0);

Ntr    = floor(train_ratio * T);
idx_tr = 1:Ntr;  idx_te = (Ntr+1):T;
X_tr = DataX(idx_tr,:);  X_te = DataX(idx_te,:);
y_tr = Datay(idx_tr);    y_te = Datay(idx_te);

[X_tr_z, muX, sdX] = zscore(X_tr);  sdX(sdX < eps) = 1;
X_te_z = (X_te - muX) ./ sdX;
[y_tr_z, muy, sdy] = zscore(y_tr);  sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

[Phi_tr, y_tr_aligned, maxLag] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned]         = buildLagMatrix(y_te_z, X_te_z, pY, pX);

beta      = Phi_tr \ y_tr_aligned;
yhat_tr_z = Phi_tr * beta;
yhat_te_z = Phi_te * beta;

yhat_tr  = yhat_tr_z * sdy + muy;
yhat_te  = yhat_te_z * sdy + muy;
y_tr_raw = y_tr((maxLag+1):end);
y_te_raw = y_te((maxLag+1):end);

rmse_tr = sqrt(mean((y_tr_raw - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw - yhat_te).^2));
fprintf('maxLag=%d | RMSE Train=%.6f  Test=%.6f\n', maxLag, rmse_tr, rmse_te);

yhat_tr_full = NaN(Ntr, 1);    yhat_tr_full((maxLag+1):end) = yhat_tr;
yhat_te_full = NaN(T-Ntr, 1);  yhat_te_full((maxLag+1):end) = yhat_te;
yhat_full    = [yhat_tr_full; yhat_te_full];

figure('Name','Full Reconstruction');
plot(1:T, Datay, 'LineWidth', 1); hold on;
plot(1:T, yhat_full, 'LineWidth', 1);
xlabel('t'); ylabel('dF/F'); title('Actual vs Predicted (Full)');
legend('Actual','Predicted'); grid on;

figure('Name','Test Reconstruction');
t_te_axis = (Ntr+1):T;
plot(t_te_axis, Datay(t_te_axis), 'LineWidth', 1); hold on;
plot(t_te_axis, yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('dF/F'); title('Actual vs Predicted (Test)');
legend('Actual','Predicted'); grid on;

figure('Name','Test Residuals');
plot(t_te_axis, Datay(t_te_axis) - yhat_te_full, 'LineWidth', 1);
xlabel('t'); ylabel('Residual'); title('Residuals (Test)'); grid on;


%% ---- LOCAL FUNCTIONS ----

function plotTrialSample(j, t, dFk, d, tt, v, dur)
    [~, i]  = min(abs(t  - d.stimStarts(j)));
    [~, k]  = min(abs(tt - d.stimStarts(j)));
    [~, k2] = min(abs(tt - d.stimEnds(j)));
    Tout = -3:0.0285:dur+3;
    figure()
    subplot(3,1,1)
    plot(Tout, dFk((i-(3*35)):(i+35*(dur+3)))); hold on
    plot(Tout, -5*ones(1,length(Tout)))
    xlim([-3,6]); xline(0); xline(3)
    ylabel('dF/F trace')
    subplot(3,1,2)
    plot(tt(k:k2)-tt(k), v(k:k2))
    xlim([-3,6]); xline(0); xline(3)
    ylabel('Input Values')
end

function addThresholdPlane(ax, threshold)
    xp = get(ax, 'Xlim');
    yp = get(ax, 'Ylim');
    x1 = [xp(1) xp(2) xp(2) xp(1)];
    y1 = [yp(1) yp(1) yp(2) yp(2)];
    p  = patch(x1, y1, ones(1,4)*threshold, 'g');
    set(p, 'facealpha', 0.1, 'edgealpha', 0.5);
    set(gcf, 'renderer', 'opengl');
    hold on;
end
