% read data 

clc;
close all;
clear all;
githubDir = "/home/nimbus/Documents/Brain/"

% Script to analyze widefield/behavioral data from 

addpath(genpath(fullfile(githubDir, 'widefield'))) % cortex-lab/widefield
addpath(genpath(fullfile(githubDir, 'Pipelines'))) % SteinmetzLab/Pipelines
addpath(genpath(fullfile(githubDir, 'npy-matlab'))) % kwikteam/npy-matlab
addpath('utils')
%%
%% experiment name
% mn = 'AL_0033'; td = '2025-01-18'; 
% en = 1;

mn = 'AL_0033'; td = '2025-03-04'; 
en = 2;

serverRoot = expPath(mn, td, en);

d = loadData(serverRoot,mn,td,en);

