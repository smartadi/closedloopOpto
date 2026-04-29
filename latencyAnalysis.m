%% Latency Analysis

clc;
close all;
clear all;

%% Session
mn = 'test'; td = '2026-04-23';
en = 1;

%% Setup
pathString = genpath('utils');
addpath(pathString);
serverRoot = expPath(mn, td, en)

diode = readNPY(append(serverRoot,'\photodiode.raw.npy'));
light = readNPY(append(serverRoot,'\lightCommand594.raw.npy'));
expo = readNPY(append(serverRoot,'\widefieldExposure.raw.npy'));

t = 0:1/2000:(length(light)-1)/2000;
%%
% figure()
% plot(t,diode);hold on
% plot(t,light);hold on

%% Rise times for both signals
fs = 2000;

lightTh = (max(light) + min(light)) / 2;

lightBin_all = double(light > lightTh);

t_lightRise = t(diff([0; lightBin_all]) > 0.5)';

t_expo = t(diff([0; expo]) > 1)';

% Expo fall times, keeping every other one (odd-indexed)
expoBin = double(expo > (max(expo) + min(expo)) / 2);
t_expoFall_all = t(diff([0; expoBin]) < -0.5)';
t_expoFall = t_expoFall_all(1:2:end);

aaa = diff([0; diode]);

%% Detect diode rises with noise rejection
t_diodeRise_all = t(diff([0; diode]) > 0.05)';

% Ignore peaks before 20s
t_diodeRise_all = t_diodeRise_all(t_diodeRise_all >= 20);

% Noise rejection: drop peaks within minSep of the previous kept peak
% minSep should be > noise spike spacing but < true latency
minSep = 0.003; % 3 ms — tune based on noise clustering in windowed plot
keep = true(size(t_diodeRise_all));
for i = 2:numel(t_diodeRise_all)
    if t_diodeRise_all(i) - t_diodeRise_all(find(keep(1:i-1), 1, 'last')) < minSep
        keep(i) = false;
    end
end
t_diodeRise_true = t_diodeRise_all(keep);

fprintf('Diode rises after noise rejection: %d\n', numel(t_diodeRise_true));

%% Explicit peak pairing: Peak1 -> Peak2 within same pulse
minLatency = 0.003; % 3 ms  — lower bound, rejects surviving noise pairs
maxLatency = 0.100; % 100 ms — upper bound, rejects inter-pulse gaps

latency = [];
peak1_times = [];
peak2_times = [];

i = 1;
while i < numel(t_diodeRise_true)
    gap = t_diodeRise_true(i+1) - t_diodeRise_true(i);
    if gap >= minLatency && gap <= maxLatency
        latency    = [latency;    gap];
        peak1_times = [peak1_times; t_diodeRise_true(i)];
        peak2_times = [peak2_times; t_diodeRise_true(i+1)];
        i = i + 2; % both peaks consumed
    else
        i = i + 1; % unpaired peak1, skip
    end
end

fprintf('Valid latency pairs found: %d\n', numel(latency));

%% Light-gate: only keep pairs where Peak2 is near a light rise
lightRiseTol = 0.05; % 50 ms — Peak2 must be within this of a light rise
validPair = any(abs(peak2_times - t_lightRise') < lightRiseTol, 2);

latency     = latency(validPair);
peak1_times = peak1_times(validPair);
peak2_times = peak2_times(validPair);
fprintf('Valid pairs after light-gating: %d\n', numel(latency));

%% Windowed verification plot
close all;
k = 1000000;
tWin = [t(k), t(k) + 20];
tMask = t >= tWin(1) & t <= tWin(2);
figure(); hold on;
plot(t(tMask), light(tMask))
plot(t(tMask), diode(tMask))
plot(t(tMask), aaa(tMask), 'k')
tRise_win  = t_lightRise(t_lightRise >= tWin(1) & t_lightRise <= tWin(2));
tPeak1_win = peak1_times(peak1_times >= tWin(1) & peak1_times <= tWin(2));
tPeak2_win = peak2_times(peak2_times >= tWin(1) & peak2_times <= tWin(2));
xline(tRise_win,  'Color', 'g');
xline(tPeak1_win, 'Color', 'b');  % Peak 1 (diode lit)
xline(tPeak2_win, 'Color', 'r');  % Peak 2 (laser response)
legend('light','diode','d(diode)','light rise','peak1','peak2')
title('Verification: blue=Peak1, red=Peak2')

latency_ms = latency * 1000;

%% Latency plots
figure()
plot(latency_ms, '*r')
xlabel('Pair index')
ylabel('Latency (ms)')
title('Latency per pair')

fig = figure('Color','w');
fig.Units    = 'inches';
fig.Position = [1, 1, 4, 3];

histogram(latency_ms, 30, ...
    'FaceColor', [0.2 0.2 0.2], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.85);

latMin = min(latency_ms);
latMax = max(latency_ms);

set(gca, ...
    'Box',       'off', ...
    'TickDir',   'out', ...
    'FontSize',  11, ...
    'FontWeight','bold', ...
    'LineWidth',  1.2, ...
    'XTick',     [latMin, latMax], ...
    'XTickLabel', {sprintf('%.1f', latMin), sprintf('%.1f', latMax)});

xlabel('Latency (ms)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Count',        'FontSize', 12, 'FontWeight', 'bold');

exportgraphics(fig, 'paper/latency_histogram.png', 'Resolution', 300);

%% Sample windows for lowest latency
[~, sortIdx] = sort(latency);
nShowLow  = min(5, numel(latency));
low_p1    = peak1_times(sortIdx(1:nShowLow));
low_p2    = peak2_times(sortIdx(1:nShowLow));
low_lat   = latency(sortIdx(1:nShowLow));

for i = 1:nShowLow
    tC    = low_p1(i);
    tWin  = [tC - 0.3, tC + 0.3];
    tMask = t >= tWin(1) & t <= tWin(2);
    tExpo_win = t_expo(t_expo >= tWin(1) & t_expo <= tWin(2));
    figure(); hold on;
    plot(t(tMask), light(tMask))
    plot(t(tMask), diode(tMask))
    plot(t(tMask), aaa(tMask), 'k')
    xline(low_p1(i),  'b', 'LineWidth', 2);
    xline(low_p2(i),  'r', 'LineWidth', 2);
    xline(tExpo_win,  'Color', [0.8 0.5 0], 'LineWidth', 1);
    title(sprintf('Low latency sample %d — %.1f ms', i, low_lat(i)*1000))
    legend('light','diode','d(diode)','peak1','peak2','expo')
end

%% Sample windows for latency > 40ms
highMask    = latency > 0.040;
high_p1     = peak1_times(highMask);
high_p2     = peak2_times(highMask);
high_lat    = latency(highMask);
nShow       = min(5, numel(high_p1));
fprintf('Pairs > 40ms: %d  (showing %d)\n', numel(high_p1), nShow);

for i = 1:nShow
    tC    = high_p1(i);
    tWin  = [tC - 0.3, tC + 0.3];
    tMask = t >= tWin(1) & t <= tWin(2);
    tExpo_win = t_expo(t_expo >= tWin(1) & t_expo <= tWin(2));
    figure(); hold on;
    plot(t(tMask), light(tMask))
    plot(t(tMask), diode(tMask))
    plot(t(tMask), aaa(tMask), 'k')
    xline(high_p1(i),  'b', 'LineWidth', 2);
    xline(high_p2(i),  'r', 'LineWidth', 2);
    xline(tExpo_win,   'Color', [0.8 0.5 0], 'LineWidth', 1);
    title(sprintf('Sample %d — latency = %.1f ms', i, high_lat(i)*1000))
    legend('light','diode','d(diode)','peak1','peak2','expo')
end

%% Debug outliers
outlierThresh = 0.065; % 65 ms
outlierMask = latency > outlierThresh;
fprintf('Outliers > 65ms: %d\n', sum(outlierMask));

outlier_times   = peak1_times(outlierMask);
outlier_peak2   = peak2_times(outlierMask);
outlier_latency = latency(outlierMask);

for i = 1:numel(outlier_times)
    tC   = outlier_times(i);
    tWin = [tC - 0.5, tC + 0.5];
    tMask = t >= tWin(1) & t <= tWin(2);
    tExpo_win = t_expo(t_expo >= tWin(1) & t_expo <= tWin(2));
    figure(); hold on;
    plot(t(tMask), light(tMask))
    plot(t(tMask), diode(tMask))
    plot(t(tMask), aaa(tMask), 'k')
    xline(outlier_times(i),  'b', 'LineWidth', 2);
    xline(outlier_peak2(i),  'r', 'LineWidth', 2);
    xline(tExpo_win,         'Color', [0.8 0.5 0], 'LineWidth', 1);
    title(sprintf('Outlier %d — latency = %.1f ms', i, outlier_latency(i)*1000))
    legend('light','diode','d(diode)','peak1','peak2','expo')
end


