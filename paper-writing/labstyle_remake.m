% LABSTYLE_REMAKE  Re-run the paper's figure producers in the lab style, into paper/figures_labstyle/.
%
% Comparison only (Aditya, 2026-11-05: "remake all paper figures ... put them in a folder, I want to
% compare changes to the current plotting setup"). With the global PAPER_LABSTYLE on, jnExport and
% paperExport hand every panel to utils/sls_lab_export.m, which restyles it with sls_style_fig (the
% lab's paper.mplstyle in MATLAB) and writes it under paper/figures_labstyle/ ONLY: the exporters
% write nothing to paper/images/ and never call paper_final_mirror, so figures_final/ is not touched.
% PAPER_FINAL is switched on too, because some producers only write their PDFs when it is on; the few
% that also copy a file straight into figures_final/ when it is on (TikZ panels, padded maps) are
% listed in RESEARCH 2026-11-05, and that folder is checked against a backup after the run.
%
% Run ONE stage at a time from the project root (each loader clears the workspace):
%   RUN_LS_STAGE = 'ctrl';  labstyle_remake   % load_sessions -> Fig 3, Fig 4, S1 (ctrl), S3, OLbest
%   RUN_LS_STAGE = 'mpc';   labstyle_remake   % Fig 6, S_varx (cached MPC/VARX results)
%   RUN_LS_STAGE = 'tune';  labstyle_remake   % S2 (load_grid, run first, + tune_supp_panels)
%   RUN_LS_STAGE = 'sine';  labstyle_remake   % Fig 5 (load_bilateral, run first, + sine panels)
%   RUN_LS_STAGE = 'imp';   labstyle_remake   % S1 area, state supplement (load_experiments + ...)
%   RUN_LS_STAGE = 'fig2';  labstyle_remake   % Fig 2, from the .fig files of fig2_jn_capture
% A subset of a stage: also set RUN_LS_ONLY = {'load_sessions', 'variance_mse'} (step names as listed below).
% Then:  py -3 paper-writing/labstyle_assemble.py build
% Each producer runs inside try/catch; a failure is printed and the stage goes on.

if ~exist('RUN_LS_STAGE','var'), error('set RUN_LS_STAGE first (see the header)'); end
if any(strcmp(RUN_LS_STAGE, {'sine', 'tune'}))  % these loaders clear the workspace: run them first
    cd(fileparts(fileparts(mfilename('fullpath'))));
    addpath(genpath('utils'), 'bilateral', 'controller-tuning');
    if strcmp(RUN_LS_STAGE, 'sine'), load_bilateral; RUN_LS_STAGE = 'sine';
    else, load_grid; RUN_LS_STAGE = 'tune'; end
end
RUN_LS_ROOT = fileparts(fileparts(mfilename('fullpath')));
cd(RUN_LS_ROOT);
addpath(genpath(fullfile(RUN_LS_ROOT,'utils')));
addpath(fullfile(RUN_LS_ROOT,'controller-analysis'), fullfile(RUN_LS_ROOT,'impulse-analysis'), ...
        fullfile(RUN_LS_ROOT,'bilateral'), fullfile(RUN_LS_ROOT,'controller-tuning'), ...
        fullfile(RUN_LS_ROOT,'paper-writing'));
clear sls_lab_export sls_style_fig jnExport paperExport paper_final_mirror; rehash;
global PAPER_LABSTYLE PAPER_FINAL PAPER_LABSTYLE_LOG                %#ok<GVMIS>
PAPER_LABSTYLE = true;  PAPER_FINAL = true;  PAPER_LABSTYLE_LOG = {};
RUN_LS_T = tic;
fprintf('\n[LS] ===== lab-style stage ''%s'' =====\n', RUN_LS_STAGE);

switch RUN_LS_STAGE
    case 'ctrl'
        r_lean = 0;                                                 %#ok<NASGU>
        RUN_LS_STEPS = {'load_sessions', 'variance_mse', 'step_response', 'f4_state_exemplars', ...
            'f4_error_decomp', 'f4_row2_quartiles', 'f4_state_exemplars_supp', 'f4_1B_equation', ...
            'f4_kernel_map', 'f4_contra_model', 'f4_cl_reject_panel', 'ctrl_best_fixed_ol'};
    case 'mpc'
        RUN_LS_STEPS = {'ctrl_mpc_direct_panels', 'ctrl_mpc_sine_panels', 'ctrl_mpc_varx_supp_panels'};
    case 'tune'
        RUN_LS_STEPS = {'tune_supp_panels'};                         % load_grid ran above
    case 'sine'
        RUN_LS_STEPS = {'sine_ff_plots_combined', 'sine_ff_across_sessions'};   % load_bilateral ran above
    case 'imp'
        RUN_LS_STEPS = {'load_experiments', 'imp_spatial_panels', 'imp_relabs_exemplars', ...
            'imp_state_quartile_supp', 'STV_PLOT = false; imp_state_trialvar', ...
            'clear clim; imp_state_raster_peramp'};   % imp_spatial_panels leaves a variable named clim
    case 'fig2'
        RUN_LS_STEPS = {'fig2_jn_panels'};
    otherwise
        error('unknown stage %s', RUN_LS_STAGE);
end
if exist('RUN_LS_ONLY', 'var')       % e.g. RUN_LS_ONLY = {'load_sessions','variance_mse'}: a subset of the stage
    RUN_LS_STEPS = RUN_LS_STEPS(ismember(RUN_LS_STEPS, RUN_LS_ONLY));
end

for RUN_LS_I = 1:numel(RUN_LS_STEPS)
    RUN_LS_STEP = RUN_LS_STEPS{RUN_LS_I};
    RUN_LS_T1 = tic;
    fprintf('\n[LS] --- %s ---\n', RUN_LS_STEP);
    try
        eval(RUN_LS_STEP);
        fprintf('[LS] ok      %-28s %6.0f s\n', RUN_LS_STEP, toc(RUN_LS_T1));
    catch RUN_LS_ME
        fprintf(2, '[LS] FAILED  %-28s %6.0f s: %s\n', RUN_LS_STEP, toc(RUN_LS_T1), RUN_LS_ME.message);
        if ~isempty(RUN_LS_ME.stack)
            fprintf(2, '[LS]         at %s line %d\n', RUN_LS_ME.stack(1).name, RUN_LS_ME.stack(1).line);
        end
    end
    % loaders and producers clear the workspace (load_bilateral: clear all): restore the switches
    global PAPER_LABSTYLE PAPER_FINAL                               %#ok<GVMIS,TLEV>
    PAPER_LABSTYLE = true;  PAPER_FINAL = true;
    if ~exist('RUN_LS_STEPS','var')                                 % clear all took the step list too
        error('[LS] %s cleared the workspace; run the remaining steps of this stage by hand', RUN_LS_STEP);
    end
    close all force;
end
fprintf('\n[LS] stage ''%s'' done in %.0f s\n', RUN_LS_STAGE, toc(RUN_LS_T));
PAPER_LABSTYLE = false;  PAPER_FINAL = false;
