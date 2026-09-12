function A = f2_affected(P, opt)
%F2_AFFECTED  Fig-2 stream, STAGE 2: the stim-affected pixel layout for ONE session.
%
% THIS DOES NOT RE-IMPLEMENT THE DETECTOR. The biphasic-TF detector (ols_tf_pipeline.m §10T/§10T2)
% is ~300 lines of intricate, validated code whose human decision -- the sensitivity `tf_sens` --
% is confirmed once per session at the §10T3 selector and SAVED together with the resulting mask:
%       data/tf_sens_<mn>_<MMDD>_e<en>.mat   ->  tf_sens, affected_tf [nG x nA], key, saved_on
% Re-deriving that mask here would create a second definition of "stim-affected" in the project,
% which is precisely the §18-vs-§10T mismatch already on record. So this stage LOADS the confirmed
% mask, verifies it matches this session's geometry, and draws the layout. Detection stays where
% it was validated; the Fig-2 stream stays clean.
%
% If a session has no confirmed selection, this errors with the exact command that produces one
% rather than silently falling back to a different criterion.
%
% INPUT   P    from f2_prep
%         opt  .plot(true)  draw the per-amp layout figure
%              .require_all_amps(false)  error if some amp has zero affected pixels
% OUTPUT  A  .affected [nG x nA] logical   per-amp stim-affected mask (CONFIRMED)
%            .unaff_pooled                 pixels unaffected at EVERY amp (the model candidate set)
%            .tf_sens .saved_on .file .nAff [1 x nA] .fig
% -------------------------------------------------------------------------------------------------
if nargin < 2, opt = struct(); end
if ~isfield(opt,'plot') || isempty(opt.plot), opt.plot = true; end
if ~isfield(opt,'require_all_amps') || isempty(opt.require_all_amps), opt.require_all_amps = false; end

% A committed RANK-based selection (utils/f2_affected_detect, tuned in f2_affected_gui) OVERRIDES the
% TF mask when present -- the robust, per-session candidate set that replaces the brittle absolute
% tf_sens cut. It stores only the RULE (method + K); the mask is rebuilt from the CURRENT P, so it can
% never desync from this session's geometry.
selfile = fullfile(P.cfg.dataDir, sprintf('f2_affsel_%s.mat', P.sess_tag));
srcTfSens = NaN;  isRank = false;  A_rank = [];
if exist(selfile,'file')
    Sx = load(selfile);
    assert(isfield(Sx,'sel'), 'f2_affected: %s has no sel struct.', selfile);
    dopt = Sx.sel;  dopt.verbose = false;              % sel carries method + its params (mono_thr / keep_n)
    A_rank = f2_affected_detect(P, dopt);
    aff = A_rank.affected;  srcFile = selfile;  srcSavedOn = local_def(Sx.sel,'saved_on','?');  isRank = true;
else
    f = fullfile(P.cfg.dataDir, sprintf('tf_sens_%s.mat', P.tf_tag));
    if ~exist(f,'file')
        error(['f2_affected: no CONFIRMED stim-affected selection for %s.\n  missing: %s\n' ...
               '  Produce it once with the validated TF detector:\n' ...
               '      selExp_override = <index>; OLS_OVERRIDE = struct(''tf_reuseSens'',false); ols_tf_pipeline\n' ...
               '  then press "CONFIRM selection & build model" at the §10T3 selector; OR commit a rank\n' ...
               '  selection in f2_affected_gui. This stream will not invent a second definition.'], P.label, f);
    end
    S = load(f);
    assert(isfield(S,'affected_tf'), 'f2_affected: %s has no affected_tf -- it predates the mask-saving fix.', f);
    aff = logical(S.affected_tf);
    srcFile = f;  srcTfSens = local_def(S,'tf_sens',NaN);  srcSavedOn = local_def(S,'saved_on','?');
end

% GEOMETRY CHECK. The mask is indexed by the contra grid, which depends on nGrid/edgeMargin/the ROI.
% A silent size mismatch here would misassign every pixel, so it is a hard error.
if ~isequal(size(aff), [P.nG P.nA])
    error(['f2_affected: confirmed mask for %s is [%d x %d] but this session''s grid is [%d x %d].\n' ...
           '  The grid changed since the selection was confirmed (nGrid / edgeMargin / ROI).\n' ...
           '  Re-confirm the selector for this session, or restore the previous grid settings.'], ...
           P.label, size(aff,1), size(aff,2), P.nG, P.nA);
end

A = struct();
A.affected  = aff;
A.nAff      = sum(aff,1);
A.tf_sens   = srcTfSens;                       % NaN when a rank selection is in force (not a TF cut)
A.saved_on  = srcSavedOn;
A.file      = srcFile;
A.isRank    = isRank;
if isRank                                       % carry the rank extras for the selector / diagnostics
    A.score = A_rank.score;  A.rank = A_rank.rank;  A.K = A_rank.K;  A.bleed_kept = A_rank.bleed_kept;
    A.detMethod = A_rank.method;  A.mono = A_rank.mono;
end
% POOLED candidate set: unaffected at EVERY amplitude. One predictor set serves all amps, which is
% what makes per-amp leak comparable at all -- a per-amp set changes the model between amplitudes
% and then the dose-response of the leak is partly a dose-response of the pixel selection.
A.unaff_pooled = find(all(~aff, 2));

if isRank
    fprintf('[F2-AFFECT] %s | %s selection: %d px kept (committed %s, residual dip bleed %+.2f)\n', ...
            P.label, A.detMethod, A.K, A.saved_on, A.bleed_kept);
else
    fprintf('[F2-AFFECT] %s | tf_sens %.2f (confirmed %s)\n', P.label, A.tf_sens, A.saved_on);
end
fprintf('   per-amp affected: ');  fprintf('%d ', A.nAff);  fprintf('of %d px\n', P.nG);
fprintf('   pooled UNAFFECTED (candidate predictors, all amps): %d px (%.0f%%)\n', ...
        numel(A.unaff_pooled), 100*numel(A.unaff_pooled)/P.nG);
if any(A.nAff == 0)
    msg = sprintf('amp(s) %s have ZERO affected pixels -> the detector found no stim-driven contra response there', ...
                  mat2str(find(A.nAff==0)));
    if opt.require_all_amps, error('f2_affected: %s', msg); else, fprintf(2,'   ** %s **\n', msg); end
end
if numel(A.unaff_pooled) < 20
    fprintf(2,['   ** only %d pooled-unaffected px: the predictor set is nearly empty, so any R^2 or leak\n' ...
               '      below is about a degenerate model, not about the brain. **\n'], numel(A.unaff_pooled));
end

%% ---- layout figure: one panel per amplitude ------------------------------------------------
A.fig = [];
if ~opt.plot, return; end
nC = min(P.nA,3);  nR = ceil(P.nA/nC);
A.fig = figure('Color','w','Name',sprintf('[F2-AFFECT] %s', P.label), ...
               'Position',[60 60 420*nC 340*nR]);
for ai = 1:P.nA
    ax = subplot(nR,nC,ai);  hold(ax,'on');
    image(ax, repmat(P.dspImg,[1 1 3]));  axis(ax,'image','off');  set(ax,'YDir','reverse');
    a = aff(:,ai);
    scatter(ax, P.dspGc(~a), P.dspGr(~a), 10, [0.78 0.78 0.78],'filled', ...
            'MarkerEdgeColor',[0.45 0.45 0.45],'LineWidth',0.2);
    scatter(ax, P.dspGc(a),  P.dspGr(a),  16, 'k','filled','MarkerEdgeColor','k');
    plot(ax, P.dspSc, P.dspSr, 'r+','MarkerSize',12,'LineWidth',1.6);
    title(ax, sprintf('%.2f V   %d/%d affected  (n=%d trials)', ...
          P.amps(ai), A.nAff(ai), P.nG, P.nT_amp(ai)), 'FontSize',9,'FontWeight','bold');
end
sgtitle(sprintf(['%s  —  stim-AFFECTED contra pixels (black), confirmed TF detector @ tf\\_sens %.2f' ...
                 '\npooled unaffected = %d px feed the ipsi predictor;  red + = ipsi stim site'], ...
                 P.label, A.tf_sens, numel(A.unaff_pooled)), 'FontWeight','bold','FontSize',10);
end

% ------------------------------------------------------------------------------------------------
function v = local_def(S, f, d)
if isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = d; end
end
