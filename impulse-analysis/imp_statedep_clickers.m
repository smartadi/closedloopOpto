% imp_statedep_clickers.m — one CLICKABLE state-vs-prediction scatter per session (all 4).
% ------------------------------------------------------------------------------------------
% Runs ols_tf_pipeline.m once per session and KEEPS each session's §17c STATEDEP figure
% (the 4-panel Motion / Pre-var / Pre-δ / Rel-δ scatter of single-trial Local-dip DV vs state).
% Each kept figure stays clickable: click any scatter point -> that trial's actual / stim-blind
% prediction / residual (+ motion) traces. The click callback is self-contained (guidata), so
% all four figures remain interactive after the loop finishes.
%
% NOTE: ols_tf_pipeline.m is a SCRIPT run in this workspace, so it clobbers ordinary loop
% variables (k, f, s, ...). ALL persistent control state therefore lives in the struct CLK,
% which the pipeline never touches; nothing bare is trusted across a run(pipe) call.
%
% PREREQUISITE: allExperiments already in the base workspace (run load_experiments.m first).
% USAGE:  imp_statedep_clickers          % just run it
% ------------------------------------------------------------------------------------------

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('imp_statedep_clickers: allExperiments not in workspace — run load_experiments.m first.');
end

CLK       = struct();
CLK.sess  = [3 1 2 4];                                    % allExperiments indices
CLK.tags  = {'AL0033','AL0041e1','AL0041e2','AL0048'};    % display labels (matched order)
CLK.pipe  = fullfile(fileparts(mfilename('fullpath')),'ols_tf_pipeline.m');
CLK.n     = min(numel(CLK.sess), numel(allExperiments));  % don't index past what's loaded
CLK.keep  = gobjects(0);                                  % accumulated clicker figures

for kk = 1:CLK.n
    CLK.i = kk;                                           % stash index in CLK (kk gets clobbered by the pipeline)
    if CLK.sess(CLK.i) > numel(allExperiments)
        fprintf(2,'skip %s: session index %d not loaded\n', CLK.tags{CLK.i}, CLK.sess(CLK.i)); continue;
    end

    % clear the previous run's clutter but preserve the clickers already kept
    delete(setdiff(findobj('Type','figure'), CLK.keep));

    clear OLS_OVERRIDE RUN_ALLSESS RUN_SESSION_VIEWER
    OLS_OVERRIDE       = struct('affect_mode','matched','selExp',CLK.sess(CLK.i));  % headless (no §10T3 gate)
    RUN_SESSION_VIEWER = false;

    CLK.err = '';
    fprintf('[clickers] running %s (selExp=%d) ...\n', CLK.tags{CLK.i}, CLK.sess(CLK.i));
    try
        evalc('run(CLK.pipe)');                          % suppress the pipeline's console spew
    catch ME
        CLK.err = ME.message;                            % ME set here, after the pipeline stopped -> safe
    end

    % from here trust ONLY CLK: the pipeline just overwrote every ordinary variable
    if ~isempty(CLK.err)
        fprintf(2,'%s FAILED: %s\n', CLK.tags{CLK.i}, CLK.err); continue;
    end

    f = findobj('Type','figure','Name','[STATEDEP] Local dip vs brain state');
    if isempty(f)
        fprintf(2,'%s: no STATEDEP figure produced\n', CLK.tags{CLK.i}); continue;
    end
    f = f(1);
    set(f,'Name',sprintf('STATEDEP %s  —  state vs prediction (CLICK a point to see the trial)', CLK.tags{CLK.i}));
    set(f,'Position',[30+(CLK.i-1)*36, 520-(CLK.i-1)*44, 1320, 360]);   % cascade so each title bar is grabbable
    CLK.keep(end+1) = f;
    fprintf('[clickers] kept %s\n', CLK.tags{CLK.i});
end

% final sweep: leave only the kept clickers on screen
delete(setdiff(findobj('Type','figure'), CLK.keep));
if ~isempty(CLK.keep), figure(CLK.keep(1)); end
fprintf('[clickers] DONE — %d clickable state-vs-prediction figures open.\n', numel(CLK.keep));
