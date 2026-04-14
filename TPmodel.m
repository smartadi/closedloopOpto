%% Spontaneous Mouse TP Model%% Data analysis Script
% add pixel configuration


clc;
close all;
clear all;

%% experiment name


mn = 'AL_0046'; td = '2026-02-12'; 
en = 1;

githubDir = "/home/nimbus/Documents/Brain/"
    
    
% Script to analyze widefield/behavioral data from 
addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab

serverRoot = expPath(mn, td, en);

% get data
pathString = genpath('utils');
addpath(pathString);

%% 
nSV = 500;

[U, V, t, meanImage] = loadUVt(serverRoot, nSV);

[Un, Vn] = dffFromSVD(U, V, meanImage);

pixel=[300,300];
dF = pixdff(Un,Vn,pixel);

%%
figure()
plot(t,dF(2:end));





