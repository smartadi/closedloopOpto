%% redraw_dose_only.m -- just the inhibition-energy panel, for iterating on its axes
%
% redraw_plant_panels.m re-runs all three plant panels and the whole TF sweep (~7 min cold).
% The y-axis/label work on panel 2 needed two passes, so this is the same knobs for that
% panel alone. Everything it sets matches redraw_plant_panels -- keep them in step.

root   = 'C:\Users\aditya\Documents\projects\brain_paper';
outDir = fullfile(root, 'talk');
addpath(genpath(fullfile(root, 'utils')));
addpath(fullfile(root, 'impulse-analysis'));
cd(fullfile(root, 'impulse-analysis'));

if ~exist('allExperiments', 'var') || isempty(allExperiments)
    fprintf('[DOSE] loading experiments (cold)\n');
    load_experiments;
end

DR_LABEL  = 'mouse';   % per-ANIMAL labels (AL_0041 contributes two sessions -> 1a / 1b)
DR_YAXIS  = true;      % real y axis with ticks + units
DR_OUTDIR = outDir;    %#ok<NASGU>
dose_response;
fprintf('[DOSE] -> %s\n', fullfile(outDir,'imp_response.pdf'));
