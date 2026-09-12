function [S, D, P] = f2_click(n, knobs)
%F2_CLICK  Investigate ONE impulse session: performance figure + CLICKABLE trial scatter.
%
% This is f2_perf PLUS the trial investigator, in one call:
%   f2_click(3)                                  % AL_0033, default op-point
%   f2_click(1, struct('select_mode','subspace','nu',0.90))   % session 1 with a tuned op-point
%
% It opens TWO figures:
%   (1) the model PERFORMANCE figure (same as f2_perf) -- held-out fit / weight map / decomposition
%   (2) a CLICKABLE state scatter for this session: Local-residual DV vs motion and vs 2-4 Hz rel-power.
%       CLICK any point -> that trial's actual ipsi / Global / Local traces + motion window + spectrum.
%
% So the flow is: look at (1) to judge the model, then click points in (2) to see the individual
% trials behind the state-dependence -- especially the outliers, to check they are real responses and
% not baseline mis-fits (the header of each trial view reports its pre-onset prediction error percentile).
%
% Same session numbers as f2_perf (run `f2_perf` with no arguments to list them). Needs
% `load_experiments` run once first. Reloads the session's SVD once (~30 s), same as f2_perf.
% -------------------------------------------------------------------------------------------------
here = fileparts(mfilename('fullpath'));
if isempty(here), here = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis'; end
addpath(here); addpath(genpath(fullfile(here,'..','utils')));
if nargin < 2, knobs = struct(); end

% ---- performance figure + the decomposition for this session (one SVD load) ----------------------
[~, D, P] = f2_perf(n, knobs);

% ---- clickable state scatter for THIS session only -----------------------------------------------
% f2_state takes a per-session struct array and, with plot=true, draws the motion + rel-delta scatter
% and arms f2_inspector (click a point -> trial detail). One session in, so nS = 1.
F2s = struct('label',{D.label}, 'caveat',{P.caveat}, 'D',{D});
S = f2_state(F2s, struct('dv','L1DEVz', 'plot',true, 'verbose',false));

fprintf(['\n[f2_click] TWO figures open: (1) performance, (2) clickable state scatter.\n' ...
         '           CLICK any point in the scatter -> that trial''s actual/Global/Local traces.\n' ...
         '           (blue window = the dip the DV is measured on; grey = pre-onset fit-quality check)\n']);
end
