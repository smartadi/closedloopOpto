% run_all.m — run the full impulse-analysis pipeline in order.
% Execute from brain_paper/ root OR from impulse-analysis/.
%
% To skip a script, comment it out below.
% NOTE: spectral_heatmap.m is excluded — it requires interactive input.
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
% paths like genpath('utils') inside load_experiments.m would fail otherwise.
addpath(genpath(fullfile(root, 'utils')));

run(fullfile(here, 'load_experiments.m'));

% load_experiments.m contains 'clear all' which wipes workspace vars including
% 'here'. Recompute before each subsequent run() call.
here = fileparts(mfilename('fullpath'));

% tf_fit → contra_prediction → motion_analysis / prestim_variance
% (contra_prediction needs best_sys from tf_fit; motion and prestim use
%  contra_prediction residuals as the deviation signal)
run(fullfile(here, 'tf_fit.m'));
run(fullfile(here, 'contra_prediction.m'));
run(fullfile(here, 'trace_overlay.m'));
run(fullfile(here, 'dose_response.m'));
run(fullfile(here, 'motion_analysis.m'));
run(fullfile(here, 'prestim_variance.m'));
run(fullfile(here, 'spatial_spread.m'));

fprintf('\nrun_all complete.\n');
