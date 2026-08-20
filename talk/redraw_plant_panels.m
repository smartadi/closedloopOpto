%% redraw_plant_panels.m -- the three "plant is linear" panels, talk-styled, into talk/
%
% Run this, not the individual scripts. It sets the talk knobs, redraws all three panels
% and drops the PDFs in brain_paper/talk/ so the paper's figure2/ copies are untouched.
%
%   1  imp_single_*        impulse traces           -- NO model-fit window   (TO_FITWIN=false)
%   2  imp_response        inhibition energy        -- y axis + units, per-MOUSE labels
%                                                      (DR_LABEL='mouse', DR_YAXIS=true)
%   3  tf_shape_across_*   normalised h(t) + fit    -- pre-onset lead-in, stim marker,
%                                                      longer legend dash, validation
%                                                      footer                (RUN_TALK=true)
%
% Cold (SVD not yet loaded) this pays ~5.5 min for load_experiments. Warm it is ~1 min.
% Requested by the user 2026-08-19 for the NeuroAI Seattle deck.

root   = 'C:\Users\aditya\Documents\projects\brain_paper';
outDir = fullfile(root, 'talk');
if ~exist(outDir, 'dir'), mkdir(outDir); end
addpath(genpath(fullfile(root, 'utils')));
addpath(fullfile(root, 'impulse-analysis'));
cd(fullfile(root, 'impulse-analysis'));

if ~exist('allExperiments', 'var') || isempty(allExperiments)
    fprintf('[TALKFIG] loading experiments (cold -- this is the slow part)\n');
    load_experiments;
end
fprintf('[TALKFIG] %d sessions in memory\n', numel(allExperiments));

%% 1 -- impulse traces, no model-fit window
TO_FITWIN = false;  TO_OUTDIR = outDir;                                  %#ok<NASGU>
trace_overlay;
fprintf('[TALKFIG] 1/3 impulse traces done\n');

%% 2 -- inhibition energy: real y axis with units, one label per MOUSE
% (user, 2026-08-19). DR_LABEL='mouse' numbers the UNIQUE animals, not the sessions --
% AL_0041 contributes two sessions, so a bare "Mouse 1..4" would claim four animals where
% there are three; those two come out as Mouse 1a / Mouse 1b.
DR_LABEL  = 'mouse';  DR_YAXIS = true;  DR_OUTDIR = outDir;              %#ok<NASGU>
dose_response;
fprintf('[TALKFIG] 2/3 dose-response done\n');

%% 3 -- normalised h(t) measured vs LTI fit, talk styling
RUN_TALK   = true;   RUN_OUTDIR = outDir;   RUN_EXPORT = true;           %#ok<NASGU>
RUN_NBOOT  = 100;    % tau CIs still needed by the robustness panel; 100 is enough here
imp_tf_run;
fprintf('[TALKFIG] 3/3 TF shape done\n');

fprintf('\n[TALKFIG] panels written to %s\n', outDir);
d = dir(fullfile(outDir, '*.pdf'));
for k = 1:numel(d), fprintf('   %s\n', d(k).name); end
