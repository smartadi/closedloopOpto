% impulse-analysis/contra_residual.m
% INTERACTIVE entry point for the contra→ipsi RESIDUAL state pipeline.
% Runs cp_residual_core for one session and opens the clickable CP-RESi inspector
% (click a scatter point -> per-trial actual / contra-pred / residual / motion).
%
% The shared pipeline lives in utils/cp_residual_core.m.
%   - batch replication across sessions -> cp_state_batch.m
%   - bleed-comp absolute dose-response -> cp_doseresponse.m
%
% Presettable in the workspace before running (defaults = state-pipeline config):
%   selExp     (3)     — experiment index
%   decontam   (false) — bleed comp OFF: it cancels in the within-amp state metrics
%                        and dropping it gives cleaner residual traces
%   use_motion (true)  — motion as a nuisance regressor in the contra map
%
% Prereq: load_experiments.m has been run (allExperiments in workspace).
close all;

% Locate utils/ so cp_residual_core + cp_res_inspector are on the path.
wrap_path = mfilename('fullpath');
if isempty(wrap_path), wrap_path = fullfile(pwd, 'contra_residual.m'); end
addpath(genpath(fullfile(fileparts(wrap_path), '..', 'utils')));

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('contra_residual: run load_experiments.m first.');
end

if ~exist('selExp','var')     || isempty(selExp),     selExp     = 3;     end
if ~exist('decontam','var')   || isempty(decontam),   decontam   = false; end
if ~exist('use_motion','var') || isempty(use_motion), use_motion = true;  end

opts = struct('decontam', decontam, 'use_motion', use_motion, ...
              'make_wide', true, 'plot', true);
[R, S] = cp_residual_core(allExperiments, selExp, opts);

% ---- open the clickable CP-RESi inspector ----
if ~isempty(R.Sin)
    cp_res_inspector(R.Sin);
    fprintf('[CP-RESi] Interactive inspector open — click a scatter point.\n');
end

fprintf('\n[contra_residual] %s %s e%d | decontam=%d motion=%d | held-out R²=%.3f\n', ...
    R.mn, R.td, R.en, R.decontam, R.use_motion, R.cv_mean);
fprintf('  partial(dev_stim, state | dev_pre):  Motion %+.3f (p=%.3g) | PreVar %+.3f (p=%.3g) | PreDelta %+.3f (p=%.3g)\n', ...
    S.r_partial(1), S.p_partial(1), S.r_partial(2), S.p_partial(2), S.r_partial(3), S.p_partial(3));
