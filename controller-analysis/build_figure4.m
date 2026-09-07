% controller-analysis/build_figure4.m
% ============================================================================
% FIGURE 4 PIPELINE  -- "Closed-loop feedback decouples the controlled response
% from a state-dependent disturbance carried by the contralateral hemisphere."
%
% Regenerates EVERY Figure-4 panel in one run, grouped by the three narrative
% blocks of the two-mechanism story. All panels export to paper/images/figure4/.
%
%   Block A  DISTURBANCE REJECTION -- the loop rejects the laser disturbance
%            ctrl_disturbance_rejection.m   [DISTREJ]  (CL vs OL RMSE, 13/13, ~1.48x)
%
%   Block B  ERROR COMPOSITION -- what the residual CL error is made of (physiology).
%            This ALSO carries the state-decoupling story: init-dev's unique-R^2 collapse
%            across windows (bars in cl_rmse_factor_windows) IS the decoupling, in the
%            exemplar/decomposition format -- no separate regression/slope panel.
%            cl_rmse_factor_windows.m       decomposition by window + exemplar spectra
%            cl_mse_exemplars.m             per-factor exemplar trials
%            cl_delta_burst_explore.m       short delta-burst gallery
%
% COHORT (2026-09-07): all blocks use the 13 controller sessions (m1-m13); the new-rig
% mice AL_0048/AL_0051 (m14/m15) are excluded everywhere. Motion-/spectrum-complete
% panels are naturally the 9 of those 13 with motion (513 trials).
%
% NOT a panel: ctrl_distrej_statedep.m [DRSTATE] (init-dev decoupling p=0.013) is a
% SUPPLEMENTARY regression analysis, cited in text only -- deliberately NOT run here.
%
% USAGE:  >> build_figure4          % from repo root OR controller-analysis/
%   The three blocks all read the session workspace produced by load_sessions.m
%   (mouse, fields). If those are absent this driver runs load_sessions.m once
%   (heavy: the full data-load loop); if they are present it reuses them.
%
% NOTE: the Block-C scripts each begin with `clc; close all`, so the running log
% is cleared mid-build -- the panel inventory printed at the end (by file mtime)
% is the authoritative record of what regenerated.
% ============================================================================

here4 = fileparts(mfilename('fullpath'));
if isempty(here4); here4 = fullfile(pwd,'controller-analysis'); end

% -- ensure the session workspace is loaded (heavy; do it at most once) -------
if ~exist('mouse','var') || ~exist('fields','var')
    fprintf('[fig4] session workspace (mouse/fields) not found -- running load_sessions.m ...\n');
    run(fullfile(here4,'load_sessions.m'));
end

blocks4 = {
  'A  disturbance rejection', {'ctrl_disturbance_rejection.m'}
  'B  error composition',     {'cl_rmse_factor_windows.m','cl_mse_exemplars.m','cl_delta_burst_explore.m'}
};

fprintf('\n================ BUILD FIGURE 4 ================\n');
fig4_fail = {};
for bb4 = 1:size(blocks4,1)
    fprintf('\n----- Block %s -----\n', blocks4{bb4,1});
    scr4 = blocks4{bb4,2};
    for ss4 = 1:numel(scr4)
        fpath4 = fullfile(here4, scr4{ss4});
        fprintf('[fig4] run %s ...\n', scr4{ss4});
        try
            run(fpath4);
        catch ME4
            fig4_fail{end+1} = sprintf('%s (%s)', scr4{ss4}, ME4.message); %#ok<SAGROW>
            fprintf(2,'[fig4] !! %s FAILED: %s\n', scr4{ss4}, ME4.message);
        end
    end
end

% -- panel inventory (survives the sub-scripts' clc) --------------------------
outdir4 = fullfile(here4,'..','paper','images','figure4');
fprintf('\n================ FIGURE 4 PANELS (paper/images/figure4/) ================\n');
D4 = dir(fullfile(outdir4,'*.p*g')); D4 = [D4; dir(fullfile(outdir4,'*.pdf'))];
[~,ord4] = sort([D4.datenum],'descend');
for i4 = 1:min(numel(D4),40)
    d = D4(ord4(i4));
    fprintf('  %s   %s\n', datestr(d.datenum,'HH:MM:SS'), d.name);
end
if ~isempty(fig4_fail)
    fprintf(2,'\n[fig4] %d script(s) FAILED:\n', numel(fig4_fail));
    for i4 = 1:numel(fig4_fail); fprintf(2,'   - %s\n', fig4_fail{i4}); end
else
    fprintf('\n[fig4] all blocks completed -> %s\n', outdir4);
end
