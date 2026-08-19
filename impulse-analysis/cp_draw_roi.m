%% cp_draw_roi.m -- draw + cache the contra/ipsi ROI for one impulse session.
%
% The analysis pipelines deliberately NEVER open the draw GUI (ols_tf_pipeline errors and tells
% you to draw it elsewhere, so an unattended batch can never block on a human). This is that
% "elsewhere" for the impulse side: it opens cp_roi_masks ONCE for a chosen session and writes
% data/cp_roi2_<tag>.mat, after which every stage runs unattended.
%
% You click twice:
%   STEP 1 -- many points around the FULL-BRAIN outline, then Enter
%   STEP 2 -- 2 points on the MIDLINE, then Enter
% The image is shown TRANSPOSED (imagesc(mimg')), the codebase's canonical view.
%
% IPSI/CONTRA need no input: cp_roi_masks calls whichever side holds the primary (site) pixel
% IPSI and the other CONTRA. So for a two-spot session the SAME geometry serves either site --
% but the cache is written per `sess_tag`, so each registered site gets its own file (they are
% identical geometry with the hemispheres swapped by construction).
%
% Usage (after the session is registered in `allExperiments`):
%   DRAW_SEL = 1;  cp_draw_roi        % 1 = index into allExperiments
% ---------------------------------------------------------------------------------

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('[DRAW-ROI] no `allExperiments` -- run load_experiments.m / load_bilateral_impulse.m first.');
end
if ~exist('DRAW_SEL','var') || isempty(DRAW_SEL); DRAW_SEL = 1; end

here_d = fileparts(mfilename('fullpath'));
if isempty(here_d) || contains(here_d,tempdir,'IgnoreCase',true) || contains(here_d,'Editor_','IgnoreCase',true)
    here_d = 'C:\Users\aditya\Documents\projects\brain_paper\impulse-analysis';
end
dataDir_d = fullfile(here_d,'data');

A_d = allExperiments(DRAW_SEL);
if isfield(A_d,'sess_tag') && ~isempty(A_d.sess_tag)
    tag_d = A_d.sess_tag;
else
    tag_d = sprintf('%s_%s%s_e%d', A_d.mn, A_d.td(6:7), A_d.td(9:10), A_d.en);
end
roi_d  = fullfile(dataDir_d, sprintf('cp_roi2_%s.mat', tag_d));
site_d = fullfile(dataDir_d, sprintf('cp_stim_site_%s.mat', tag_d));
assert(exist(site_d,'file')>0, ['[DRAW-ROI] no site cache %s -- the site must be localised ' ...
    'before the ROI (ipsi is defined as the side holding it).'], site_d);
S_d = load(site_d);  rc_d = double(S_d.rowcol);

if exist(roi_d,'file')
    fprintf('[DRAW-ROI] ROI already cached: %s\n   delete it (or set DRAW_REDO=true) to redraw.\n', roi_d);
    if ~exist('DRAW_REDO','var') || ~DRAW_REDO
        M_d = cp_roi_masks(A_d.mimg, roi_d, rc_d(1), rc_d(2), struct('redefine',false,'thr_pctile',20,'plot',true));
        return
    end
else
    DRAW_REDO = false;
end

fprintf(['\n[DRAW-ROI] %s  site [row %d col %d]\n' ...
         '   STEP 1: click MANY points around the whole brain outline, then press Enter.\n' ...
         '   STEP 2: click 2 points on the midline, then press Enter.\n'], tag_d, rc_d);
M_d = cp_roi_masks(A_d.mimg, roi_d, rc_d(1), rc_d(2), ...
                   struct('redefine', logical(DRAW_REDO), 'thr_pctile', 20, 'plot', true));
fprintf('[DRAW-ROI] cached %s  | contra(predictor) %d px | ipsi(target) %d px\n', ...
    roi_d, nnz(M_d.contra), nnz(M_d.ipsi));
