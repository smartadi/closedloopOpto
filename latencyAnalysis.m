%% Latency Analysis

clc;
close all;
clear all;

%% Session
mn = 'test'; td = '2026-04-22';
en = 3;

%% Setup
pathString = genpath('utils');
addpath(pathString);
serverRoot = expPath(mn, td, en)

diode = readNPY(append(serverRoot,'\photodiode.raw.npy'));
light = readNPY(append(serverRoot,'\lightCommand594.raw.npy'));
expo = readNPY(append(serverRoot,'\widefieldExposure.raw.npy'));

t = 0:1/2000:(length(light)-1)/2000;
%%
figure()
plot(t,diode);hold on
plot(t,light);hold on

%% Rise times for both signals
fs = 2000;

lightTh = (max(light) + min(light)) / 2;
diodeTh = (max(diode) + min(diode)) / 2;

lightBin_all = double(light > lightTh);
diodeBin_all = double(diode > diodeTh);

t_lightRise = t(diff([0; lightBin_all]) > 0.5)';
t_diodeRise = t(diff([0; diodeBin_all]) > 0.01)';


t_expo = t(diff([0; expo]) > 1)';

% Expo fall times, keeping every other one (odd-indexed)
expoBin = double(expo > (max(expo) + min(expo)) / 2);
t_expoFall_all = t(diff([0; expoBin]) < -0.5)';
t_expoFall = t_expoFall_all(1:2:end);

fprintf('Light rises: %d\nDiode rises: %d\n', numel(t_lightRise), numel(t_diodeRise));

aaa = diff([0; diode]);

t_diodeRise_true = t(diff([0; diode]) > 0.015)';

% Ignore peaks before 20s
t_diodeRise_true = t_diodeRise_true(t_diodeRise_true >= 20);

% Ignore peaks too close together (keep first, drop within minSep)
minSep = 0.01; % seconds
keep = true(size(t_diodeRise_true));
for i = 2:numel(t_diodeRise_true)
    if t_diodeRise_true(i) - t_diodeRise_true(find(keep(1:i-1), 1, 'last')) < minSep
        keep(i) = false;
    end
end
t_diodeRise_true = t_diodeRise_true(keep);

% Remove diode peaks too close to light signal fall times
t_lightFall = t(diff([0; lightBin_all]) < -0.5)';
fallProximity = 0.5; % seconds
nearFall = any(abs(t_diodeRise_true - t_lightFall') < fallProximity, 2);
t_diodeRise_true = t_diodeRise_true(~nearFall);

%%
close all;
figure();hold on;
plot(t,light)
plot(t,diode)
plot(t,aaa,'k')
xline(t_lightRise,'Color','g');

xline(t_diodeRise_true,'Color','cyan')

xline(t_expoFall,'Color','r')
%%

latency = diff(t_diodeRise_true);
latency = latency(latency <= 0.1);

figure()
plot(latency,'*r')

figure()
histogram(latency * 1000, 50)
xlabel('Latency (ms)')
ylabel('Count')
title('latency distribution')
