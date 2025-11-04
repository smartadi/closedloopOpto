% File: test_and_visualize_frechet.m
clear; clc;

% %% Fréchet Functions
% % Discrete Fréchet distance
% function dist = discrete_frechet(P, Q)
%     n = length(P);
%     m = length(Q);
%     ca = -ones(n, m);
% 
%     function d = c(i, j)
%         if ca(i,j) > -1
%             d = ca(i,j);
%         elseif i == 1 && j == 1
%             d = norm(P(1) - Q(1));
%         elseif i > 1 && j == 1
%             d = max(c(i-1,1), norm(P(i)-Q(1)));
%         elseif i == 1 && j > 1
%             d = max(c(1,j-1), norm(P(1)-Q(j)));
%         else
%             d = max(min([c(i-1,j), c(i-1,j-1), c(i,j-1)]), norm(P(i)-Q(j)));
%         end
%         ca(i,j) = d;
%     end
%     dist = c(n, m);
% end
% 
% % Sliding Fréchet distance
% function dists = frechet_distance_sliding(x1, x2, Fs, win_len_sec)
%     assert(length(x1) == length(x2), 'Signals must be same length');
%     T = length(x1);
%     win_len_samples = round(win_len_sec * Fs);
%     dists = NaN(1, T);
% 
%     for t = 1:T
%         start_idx = t - win_len_samples + 1;
%         if start_idx < 1
%             continue;
%         end
%         seg1 = x1(start_idx:t);
%         seg2 = x2(start_idx:t);
%         dists(t) = discrete_frechet(seg1, seg2);
%     end
% end

%% Run Tests
disp('Running Fréchet Distance Tests...');
Fs = 35;
t = 0:1/Fs:5;
win_len_sec = 2;

% Test 1: Identical
x1 = sin(2*pi*2*t);
x2 = x1;
d = frechet_distance_sliding(x1, x2, Fs, win_len_sec);
assert(all(abs(d(~isnan(d))) < 1e-10), 'Test 1 failed: identical signals');
figure()
plot(d)

% Test 2: Constant vs. oscillating
x1 = zeros(1, length(t));
x2 = sin(2*pi*2*t);
d = frechet_distance_sliding(x1, x2, Fs, win_len_sec);
assert(all(d(~isnan(d)) > 0.5), 'Test 2 failed: constant vs oscillating');
figure()
plot(d)



% % Test 3: Phase shifted
% x1 = sin(2*pi*2*t);
% x2 = sin(2*pi*2*t + pi/2);
% d = frechet_distance_sliding(x1, x2, Fs, win_len_sec);
% assert(all(d(~isnan(d)) > 0.1), 'Test 3 failed: phase shift');
% assert(std(d(~isnan(d))) < 0.05, 'Test 3 failed: unstable distance');
% 
% % Test 4: Too short signal
% x1 = sin(2*pi*2*t(1:10));
% x2 = sin(2*pi*2*t(1:10));
% d = frechet_distance_sliding(x1, x2, Fs, win_len_sec);
% assert(all(isnan(d)), 'Test 4 failed: short signal should return NaN');

disp('All tests passed');

%% Visualization
% 10s dual signal with phase shift
t = 0:1/Fs:10;
x1 = sin(2*pi*2*t);
x2 = sin(2*pi*2*t + pi/20);  % Phase-shifted

frechet = frechet_distance_sliding(x1, x2, Fs, win_len_sec);

figure;
subplot(3,1,1);
plot(t, x1, 'b', t, x2, 'r');
legend('x1', 'x2');
title('Signals');
xlabel('Time (s)');

subplot(3,1,2);
plot(t, frechet, 'k');
ylabel('Fréchet Distance');
xlabel('Time (s)');
title(['Sliding Fréchet Distance (past ', num2str(win_len_sec), 's)']);

% Optional: visualize a few segments
highlight_idxs = round(linspace(Fs*win_len_sec+1, length(x1), 3));
subplot(3,1,3);
hold on;
for k = 1:length(highlight_idxs)
    idx = highlight_idxs(k);
    seg1 = x1(idx - Fs*win_len_sec + 1 : idx);
    seg2 = x2(idx - Fs*win_len_sec + 1 : idx);
    plot(seg1, 'b--');
    plot(seg2, 'r--');
end
title('Example Past Windows at Selected Times');
legend('x1 windows', 'x2 windows');
xlabel('Sample');


%%


