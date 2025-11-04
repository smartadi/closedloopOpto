
clc;
clear all;
Fs = 35;
x = randn(1, 1000);       % Example signal
win_len_sec = 4;          % Use past 4 seconds only

bp = compute_bandpower_sliding(x, Fs, win_len_sec);

figure;
plot(bp);
legend('1–3 Hz', '3–6 Hz', '6–17.5 Hz');
xlabel('Sample');
ylabel('Band Power');
title('Past-Only Sliding Band Power');

close all;


% File: example_sine_bandpower.m

% Sampling settings
Fs = 35;               % Sampling frequency
T = 100;               % Signal duration in seconds
t = 0:1/Fs:T-1/Fs;     % Time vector
N = length(t);

% Create signal with 3 sine waves in different bands
x = 2*sin(2*pi*2*t) + 10*sin(2*pi*4*t) + 1*sin(2*pi*10*t);

% Optional: add noise
% x = x + 0.1*randn(size(x));

% Define function here or call external file
win_len_sec = 2;  % 4-second past window

% Band power calculation
bp = compute_bandpower_sliding(x, Fs, win_len_sec);

% Plot signal and band powers
figure;

subplot(4,1,1);
plot(t, x);
xlabel('Time (s)');
ylabel('Signal');
title('Input Signal (2Hz + 4Hz + 10Hz)');

subplot(4,1,2);
plot(t, bp(:,1), 'b');
ylabel('Power 1–3 Hz');
ylim([0 inf]);

subplot(4,1,3);
plot(t, bp(:,2), 'g');
ylabel('Power 3–6 Hz');
ylim([0 inf]);

subplot(4,1,4);
plot(t, bp(:,3), 'r');
ylabel('Power 6+ Hz');
xlabel('Time (s)');
ylim([0 inf]);

sgtitle('Band Power Over Time (Past-only Sliding Window)');






% %%
% 
% x = ones(1,3500);
% x = sin(5*pi*t);
% win_len_sec=1;
% close all;
% 
% v = compute_past_variance(x, Fs, win_len_sec);
% figure()
% plot(t,v);
% xlabel('Sample');
% ylabel('Variance');
% title('Past-Only Sliding Variance');
% 
% 
% 
% figure()
% plot(t,x);
