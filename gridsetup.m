close all;
clear all;
clc;
N_gridp = 5
N_gridi = 5
Kp = linspace(0.01,0.3,N_gridp)
Ki = linspace(0.01,0.2,N_gridi)


%%

Kp = repelem(Kp,N_gridi);
Ki = repmat(Ki,1,N_gridp);

K=[Kp,0;Ki,0];

N_trials = 20;

K = repmat(K,1,N_trials);

figure()
plot(K(1,:),K(2,:),'ro','LineWidth',2)

%%
Kr = K(:, randperm(size(K, 2)))

% figure()
% plot(Kr(1,:),Kr(2,:),'ro','LineWidth',2)

writeNPY(Kr,'Kr.npy');

%%
% KR = readNPY('Kr.npy')

% figure()
% plot(KR(1,:),KR(2,:),'ro','LineWidth',2)