% run_all.m — run the full controller-analysis pipeline in order.
% Execute from brain_paper/ root OR from controller-analysis/.
%
% To skip a script, comment it out below.
clc;
clear all;
close all;

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
if ~strcmp(pwd, root)
    cd(root);
    fprintf('Working directory set to: %s\n', root);
end

% Add utils with an absolute path BEFORE run() calls.
% MATLAB's run() temporarily cd's into the script's directory, so relative
% paths like genpath('utils') inside load_sessions.m would fail otherwise.
addpath(genpath(fullfile(root, 'utils')));

run(fullfile(here, 'load_sessions.m'));

% load_sessions.m contains 'clear all' which wipes workspace vars including
% 'here'. Recompute before each subsequent run() call.
here = fileparts(mfilename('fullpath'));

run(fullfile(here, 'variance_mse.m'));
run(fullfile(here, 'step_response.m'));
run(fullfile(here, 'motion_analysis.m'));
run(fullfile(here, 'spectral_mse_sort.m'));
run(fullfile(here, 'prestim_variance.m'));
run(fullfile(here, 'cl_mse_factors.m'));
run(fullfile(here, 'widebrain_arx.m'));

fprintf('\nrun_all complete.\n');
