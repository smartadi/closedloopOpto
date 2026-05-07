    %% Primary Controller Analysis Script

clc;
close all;
clear all;

%% Experiment name

% With rewards
% mn = 'AL_0033'; td = '2025-03-04'; en = 1;
% mn = 'AL_0033'; td = '2025-03-04'; en = 2;
% mn = 'AL_0033'; td = '2025-03-05'; en = 2;
% mn = 'AL_0033'; td = '2025-03-18'; en = 1;
% mn = 'AL_0033'; td = '2025-03-20'; en = 4;
% mn = 'AL_0033'; td = '2025-04-15'; en = 2;
% mn = 'AL_0033'; td = '2025-04-18'; en = 4;
mn = 'AL_0033'; td = '2025-04-19'; en = 1;
% mn = 'AL_0033'; td = '2025-04-20'; en = 2;

% NEW LASER
mn = 'AL_0039'; td = '2025-04-19'; en = 1;
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

% d.params.pix_ids = [2, 4, 5, 8, 9, 12, 13];

%% Run movie
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

%% Display brain image with pixel location
svdData.U    = U;
svdData.V    = V;
svdData.mimg = mimg;
displayFrame(mn, td, en, d, d.params.pixels, svdData);

%% Load pixel dF/F
mode = 0;  % from binary image
r    = 1;  % read file
[data, ~] = getpixel_dFoF(d, mode, d.params.pixels, r);
dFk = data.dFk;

% data_pix = getpixels_dFoF(d);
% dFkp = data_pix.dFk;

%% Trial sample visualization
dur = d.params.dur;
t   = d.timeBlue;
tt  = d.inpTime;
v   = d.inpVals;

close all;
plotTrialSample(10, t, dFk, d, tt, v, dur);

%% Feedforward vs Feedback classification
trials = 100;
d.ref  = -5;
data   = controllerData(data, d, trials);

%% Plots
close all;
analysisPlots_combined(data, d);

%% Invariance analysis
% invarianceAnalysis(data, d);
% 
% %% Features
% nc = data.nc;
% wc = data.wc;
% 
% features = feature_analysis(dFk, d, data);
% mf = features.mf;
% v1 = features.v1;
% v2 = features.v2;
% v3 = features.v3;



%% Initial conditions (vectorized)
nc = data.nc;
wc = data.wc;
stimIdx = zeros(numel(d.stimStarts), 1);
for j = 1:numel(d.stimStarts)
    [~, stimIdx(j)] = min(abs(t - d.stimStarts(j)));
end
X0    = dFk(stimIdx)';
X0_wc = X0(wc);
X0_nc = X0(nc);

%% MSE vs initial condition
colOL = [1 0 0];
colCL = [0 0.5 0];

x_nc = abs(X0_nc + 5);
x_wc = abs(X0_wc + 5);
y_nc = data.er_ncDfk;
y_wc = data.er_wcDfk;

fig1           = figure('Color', 'w');
fig1.Units     = 'inches';
fig1.Position  = [1 1 5 4];
ax = axes(fig1);
hold(ax, 'on');
drawEllipse(ax, x_nc, y_nc, colOL, 0.2);
drawEllipse(ax, x_wc, y_wc, colCL, 0.2);
scatter(ax, x_nc, y_nc, 16, colOL, 'o', 'MarkerFaceColor', colOL, 'MarkerFaceAlpha', 0.5, 'LineWidth', 0.5);
scatter(ax, x_wc, y_wc, 16, colCL, 'o', 'MarkerFaceColor', colCL, 'MarkerFaceAlpha', 0.5, 'LineWidth', 0.5);
xlabel(ax, 'Initial deviation from reference', 'FontSize', 8, 'FontWeight', 'bold');
ylabel(ax, 'Trial MSE',                        'FontSize', 8, 'FontWeight', 'bold');
set(ax, 'Box', 'off', 'TickDir', 'out', 'XTick', [], 'YTick', [], 'FontName', 'Arial', 'FontSize', 8);

%% Pixel analysis
% pixel_test(d, data, dFkp);
% dataPixel = pixelAnalysis(d, data, dFkp);
% close all;

er_wcDfk = data.er_wcDfk;
er_ncDfk = data.er_ncDfk;
pwcDfk   = data.pwcDfk;
pncDfk   = data.pncDfk;

%% Motion plotter
% close all;
% motionPlotter(15, d, data, features)

%% Motion vs MSE
close all;
pre_end      = 35 * 10;
trial_on     = pre_end + 1;
trial_off    = pre_end + dur * 35;
combined_on  = pre_end - 3 * 35;   % t = -2s relative to trial onset

ncmotion_pre      = sum(data.ncmotion(:, 1:pre_end),                2);
wcmotion_pre      = sum(data.wcmotion(:, 1:pre_end),                2);
ncmotion_during   = sum(data.ncmotion(:, trial_on:trial_off),       2);
wcmotion_during   = sum(data.wcmotion(:, trial_on:trial_off),       2);
ncmotion_combined = sum(data.ncmotion(:, combined_on:trial_off),    2);
wcmotion_combined = sum(data.wcmotion(:, combined_on:trial_off),    2);

figure(); hold on;
scatter(ncmotion_combined, er_ncDfk, 30, colOL, 'o', 'filled', 'MarkerFaceAlpha', 0.6)
scatter(wcmotion_combined, er_wcDfk, 30, colCL, 'o', 'filled', 'MarkerFaceAlpha', 0.6)
xr = linspace(min([ncmotion_combined; wcmotion_combined]), max([ncmotion_combined; wcmotion_combined]), 100);
plot(xr, polyval(polyfit(ncmotion_combined, er_ncDfk, 1), xr), '-', 'Color', colOL, 'LineWidth', 1.5)
plot(xr, polyval(polyfit(wcmotion_combined, er_wcDfk, 1), xr), '-', 'Color', colCL, 'LineWidth', 1.5)
xlabel('Total motion (t=-2s to trial end) (a.u.)'); ylabel('MSE norm ||e||')
legend({'OL', 'CL'}, 'Location', 'best'); box off

%% 3D scatter: initial condition, motion, MSE
threshold = 30;
close all
figure()
subplot(1,2,1)
scatter3(X0_wc, wcmotion_pre, er_wcDfk, [], er_wcDfk, 'filled', 'g'); hold on
scatter3(X0_nc, ncmotion_pre, er_ncDfk, [], er_ncDfk, 'filled', 'r');
xlabel('x_0 df/F'); ylabel('motion'); zlabel('MSE norm')
title('pre-trial motion')
addThresholdPlane(gca, threshold);

subplot(1,2,2)
scatter3(X0_wc, wcmotion_during, er_wcDfk, [], er_wcDfk, 'filled', 'g'); hold on
scatter3(X0_nc, ncmotion_during, er_ncDfk, [], er_ncDfk, 'filled', 'r');
xlabel('x_0 df/F'); ylabel('motion'); zlabel('MSE norm')
title('during-trial motion')
addThresholdPlane(gca, threshold);

%% Second trial sample
plotTrialSample(50, t, dFk, d, tt, v, dur);

%% Controller inputs
inputs = d.iputs(d.params.horizon:d.params.horizon + length(d.timeBlue));

%% OLS Regression: predict primary pixel from peripheral pixels + motion + inputs
startIdx    = 2000;
T           = length(d.timeBlue) - startIdx;
endIdx      = startIdx + T - 1;
train_ratio = 0.7;
pY          = 1;
pX          = 2;
rng(0);

DataX = [dFkp(d.params.pix_ids, startIdx:endIdx)', d.mv(startIdx:endIdx), inputs(startIdx:endIdx)];
Datay = dFk(startIdx:endIdx)';

Ntr    = floor(train_ratio * T);
X_tr = DataX(1:Ntr,:);       X_te = DataX(Ntr+1:end,:);
y_tr = Datay(1:Ntr);         y_te = Datay(Ntr+1:end);

[X_tr_z, muX, sdX] = zscore(X_tr);  sdX(sdX < eps) = 1;
X_te_z = (X_te - muX) ./ sdX;
[y_tr_z, muy, sdy] = zscore(y_tr);  sdy = max(sdy, eps);
y_te_z = (y_te - muy) ./ sdy;

[Phi_tr, y_tr_aligned, maxLag] = buildLagMatrix(y_tr_z, X_tr_z, pY, pX);
[Phi_te, y_te_aligned]         = buildLagMatrix(y_te_z, X_te_z, pY, pX);

beta      = Phi_tr \ y_tr_aligned;
yhat_tr   = (Phi_tr * beta) * sdy + muy;
yhat_te   = (Phi_te * beta) * sdy + muy;
y_tr_raw  = y_tr((maxLag+1):end);
y_te_raw  = y_te((maxLag+1):end);

rmse_tr = sqrt(mean((y_tr_raw - yhat_tr).^2));
rmse_te = sqrt(mean((y_te_raw - yhat_te).^2));
r2_tr   = 1 - sum((y_tr_raw - yhat_tr).^2) / sum((y_tr_raw - mean(y_tr_raw)).^2);
r2_te   = 1 - sum((y_te_raw - yhat_te).^2) / sum((y_te_raw - mean(y_te_raw)).^2);
fprintf('maxLag=%d | Train: RMSE=%.4f  R²=%.4f | Test: RMSE=%.4f  R²=%.4f\n', maxLag, rmse_tr, r2_tr, rmse_te, r2_te);

yhat_tr_full = NaN(Ntr, 1);    yhat_tr_full((maxLag+1):end) = yhat_tr;
yhat_te_full = NaN(T-Ntr, 1);  yhat_te_full((maxLag+1):end) = yhat_te;
yhat_full    = [yhat_tr_full; yhat_te_full];

figure('Name', 'Reconstruction');
plot(1:T, Datay, 'LineWidth', 1); hold on;
plot(1:T, yhat_full, 'LineWidth', 1);
xlabel('t'); ylabel('dF/F'); title('Actual vs Predicted');
legend('Actual', 'Predicted'); grid on;

%% Regression trial analysis
dFk_reg = [zeros(length(data.dFk) - length(yhat_full), 1); yhat_full];
reg.dFk = dFk_reg;
reg.t   = d.timeBlue(startIdx:endIdx);
reg     = regData(reg, d, data);

close all;
figure()
plot(reg.er_ncDfk, data.er_ncDfk, 'or'); hold on
plot(reg.er_wcDfk, data.er_wcDfk, 'og');
xlabel('reconstructed trial error'); ylabel('actual trial error')
legend('feedforward', 'feedback')

%% Average contralateral pixel activities
dFkp_contra = dFkp(d.params.pix_ids, :);
dFk_inv     = get_dFoF(d, d.params.pix_inv, serverRoot);

dFk_base_wc = [];
for k = 1:length(d.params.pix_ids)
    dF_data = [];
    for j = 1:length(wc)
        [~, i] = min(abs(t - d.stimStarts(wc(j))));
        dF_data = [dF_data; dFkp_contra(k, i-35:i+35*(dur+1))];
    end
    dFk_base_wc = [dFk_base_wc; mean(dF_data, 1)];
end

dFk_base_nc = [];
for k = 1:length(d.params.pix_ids)
    dF_data = [];
    for j = 1:length(nc)
        [~, i] = min(abs(t - d.stimStarts(nc(j))));
        dF_data = [dF_data; dFkp_contra(k, i-35:i+35*(dur+1))];
    end
    dFk_base_nc = [dFk_base_nc; mean(dF_data, 1)];
end

figure()
subplot(1,2,1); plot(dFk_base_wc'); title('CL contralateral avg')
subplot(1,2,2); plot(dFk_base_nc'); title('OL contralateral avg')

%% Bootstrap variance vs sample size
wcvar = [];
for j = 1:length(data.wc)
    [~, idx] = min(abs(d.timeBlue - d.stimStarts(data.wc(j))));
    wcvar = [wcvar; dFk(idx:idx + 35*dur) + 5];
end

sizes  = 10:10:100;
allErr = [];  grpErr = [];
allVar = [];  grpVar = [];
for k = 1:numel(sizes)
    n    = sizes(k);
    pick = randi([1, size(wcvar, 1)], n, 1);
    wwc  = wcvar(pick, :);
    WCerr = vecnorm(wwc, 2, 2);
    Wcvar = var(wwc, 0, 2);
    allErr = [allErr; WCerr];  grpErr = [grpErr; repmat(n, n, 1)];
    allVar = [allVar; Wcvar];  grpVar = [grpVar; repmat(n, n, 1)];
end

figure()
subplot(1,2,1); boxplot(allErr, grpErr); xlabel('n trials'); ylabel('MSE norm');  title('MSE vs bootstrap size')
subplot(1,2,2); boxplot(allVar, grpVar); xlabel('n trials'); ylabel('variance');  title('Variance vs bootstrap size')


%% ---- LOCAL FUNCTIONS ----

function plotTrialSample(j, t, dFk, d, tt, v, dur)
    [~, i]  = min(abs(t  - d.stimStarts(j)));
    [~, k]  = min(abs(tt - d.stimStarts(j)));
    [~, k2] = min(abs(tt - d.stimEnds(j)));
    Tout = -3:0.0285:dur+3;
    figure()
    subplot(3,1,1)
    plot(Tout, dFk((i-(3*35)):(i+35*(dur+3)))); hold on
    plot(Tout, -5*ones(1, length(Tout)))
    xlim([-3,6]); xline(0); xline(3); ylabel('dF/F')
    subplot(3,1,2)
    plot(tt(k:k2)-tt(k), v(k:k2))
    xlim([-3,6]); xline(0); xline(3); ylabel('Input')
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

function drawEllipse(ax, x, y, col, alpha_val)
    mu     = [mean(x(:)), mean(y(:))];
    C      = cov(x(:), y(:));
    [V, D] = eig(C);
    theta  = linspace(0, 2*pi, 200);
    ell    = 2 * V * sqrt(D) * [cos(theta); sin(theta)];
    fill(ax, mu(1) + ell(1,:), mu(2) + ell(2,:), col, ...
        'FaceAlpha', alpha_val, 'EdgeColor', col, 'LineWidth', 1.5);
end
