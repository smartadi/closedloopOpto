%% make_state_panels.m -- Fig-2 state panels for the talk: state vs prediction error, no controls
%
% Three panels, no stim-free (grey) control line on any of them:
%
%   1. MOTION          all trials                 -> imp_state_var_motion
%   2. Relative delta  HIGH-MOTION TRIALS REMOVED -> imp_state_var_reldelta
%   3. Pre-trial var   HIGH-MOTION TRIALS REMOVED -> imp_state_var_prevar
%
% Two passes are needed because the trial pool differs: motion has to keep the high-motion
% trials (they are the effect), the brain states have to lose them (so a surviving effect
% cannot be movement under another name). Exclusion threshold = the locked motThresh = 1.5.
%
% ⚠ Pre-trial VARIANCE is the state retracted 2026-07-02 as a signal-power confound -- it is
% the denominator of the R^2 it was scored against. It is drawn here because it was asked for;
% do not present it beside the other two as an equal finding. Relative delta is the
% power-independent version, and even it does not replicate on Ye/Zhiwen's data (rho = -0.25,
% opposite sign). See impulse-analysis/CLAUDE.md.
%
% Staged as PDFs under talk/_stage/; paper/images/figure2 is never touched.

root = 'C:\Users\aditya\Documents\projects\brain_paper';
addpath(genpath(fullfile(root,'utils')));
addpath(fullfile(root,'impulse-analysis'));
cd(fullfile(root,'impulse-analysis'));

if ~exist('allExperiments','var') || isempty(allExperiments)
    fprintf('[STATEPANELS] loading experiments (cold -- the slow part)\n');
    load_experiments;
end

STAGE          = fullfile(root, 'talk', '_stage');     % NOT paper/ -- staging only
STVF_PAPER     = true;
STVF_PAPERROOT = STAGE;
STV_PLOTCTRL   = false;        % <- no "No stimulus" grey series, on the figure or in the stats
% y-axis in %dF/F: "predict the impulse response from the laser amplitude alone and, in this
% state, you are off by about this much". The published 2J/2K y (SD of the amplitude-scaled
% deviation) is ~1 by construction and unitless, so it can only say wider/narrower, never
% how wide -- which is the thing the slide has to land. Set STVF_UNITS='sd' for the paper axis.
STVF_UNITS     = 'raw';

% ---- pass 1: motion, all trials ----------------------------------------------------------
fprintf('\n[STATEPANELS] pass 1/2 -- MOTION, all trials\n');
STV_MOTEXCL  = false;
imp_state_trialvar;
STVF_MARKERS = {'MOT'};
imp_state_trialvar_fig;

% ---- pass 2: brain states, high-motion trials removed ------------------------------------
fprintf('\n[STATEPANELS] pass 2/2 -- REL DELTA + PRE-TRIAL VARIANCE, motion-excluded\n');
STV_MOTEXCL  = true;
imp_state_trialvar;
STVF_MARKERS = {'DPr','PVv'};
imp_state_trialvar_fig;

fprintf('\n[STATEPANELS] staged PDFs -> %s\n', fullfile(STAGE,'images','figure2'));
d = dir(fullfile(STAGE,'images','figure2','*.pdf'));
for k = 1:numel(d), fprintf('   %s\n', d(k).name); end
