%% fig2_jn_capture.m -- draw the seven Fig 2 panels with their producers and keep the MATLAB figures.
%
% JN draft only (Aditya, 2026-11-03: "take a crack at figure placements and in figure text optimization
% and sizing for figure 2"). The producers keep all the science: this script only runs them, with their
% exports pointed at a scratch folder and PAPER_FINAL off so that panels/figure2 (shared with NC) stays as
% it is, and saves the open figures as .fig. fig2_jn_panels.m then restyles those .fig files without
% touching the data, so a layout change never needs the data again.
%
% Needs read access to the lab server (load_experiments). Writes only under paper/figures_final/jn/fig2/.
% Run from the project root:   fig2_jn_capture
root = 'C:\Users\aditya\Documents\projects\brain_paper';
cd(root);
addpath(fullfile(root,'impulse-analysis'));
addpath(genpath(fullfile(root,'utils')));

global PAPER_FINAL; PAPER_FINAL = false; %#ok<GVMIS,NASGU>
if ~exist('allExperiments','var') || isempty(allExperiments)
    load_experiments;
end
global PAPER_FINAL; PAPER_FINAL = false; %#ok<GVMIS,NASGU>  % load_experiments clears the workspace
root = 'C:\Users\aditya\Documents\projects\brain_paper';
cd(root);
F2SRC = fullfile(root,'paper','figures_final','jn','fig2','src');
F2TMP = fullfile(F2SRC,'tmp_exports');
if ~exist(F2TMP,'dir'), mkdir(F2TMP); end

% ---- A: traces, Mouse 1b
TO_EXP = 3; TO_OUTDIR = F2TMP; trace_overlay; savefig(figS, fullfile(F2SRC,'A.fig'));
fprintf('[capture] A\n');

% ---- B: evoked suppression vs laser power
DR_OUTDIR = F2TMP; dose_response; savefig(fig, fullfile(F2SRC,'B.fig'));
fprintf('[capture] B\n');

% ---- C and D: held-out fit (same producer, same split-half run)
CV_OUTDIR = F2TMP; CV_EXPORT = true; imp_tf_cv;
savefig(figS, fullfile(F2SRC,'C.fig')); savefig(fH, fullfile(F2SRC,'D.fig'));
fprintf('[capture] C D\n');

% ---- E and F: model swap and timescales, from the saved fits
close all;
FIG_OUTDIR = F2TMP; FIG_PANELS = {'swap','tau'}; FIG_EXPORT = true; imp_tf_figs;
ff = findall(0,'Type','figure');
for iF = 1:numel(ff)
    axs = findall(ff(iF),'Type','axes');
    tt = arrayfun(@(a) string(a.Title.String), axs, 'UniformOutput', false);
    xl = arrayfun(@(a) string(a.XLabel.String), axs, 'UniformOutput', false);
    if any(contains([xl{:}],'applied to session')), savefig(ff(iF), fullfile(F2SRC,'E.fig')); fprintf('[capture] E\n'); end
    if any(contains([tt{:}],'Timescales')),         savefig(ff(iF), fullfile(F2SRC,'F.fig')); fprintf('[capture] F\n'); end
end

% ---- G: state dependence, from the saved stats
close all;
imp_state_var_combined([], F2TMP);
savefig(gcf, fullfile(F2SRC,'G.fig'));
fprintf('[capture] G\n');
disp(string({dir(fullfile(F2SRC,'*.fig')).name}));
