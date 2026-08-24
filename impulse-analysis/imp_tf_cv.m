%% imp_tf_cv.m -- TRIAL-level cross-validated normalised LTI fit, all sessions.
%
% The 2C-i shape panel draws an IN-SAMPLE fit and the only cross-validation in the pipeline
% (LOAO / talk/make_lti_cv_fig) holds out an AMPLITUDE while still fitting on trial averages.
% Neither holds out trials, so neither answers "does the plant model predict the impulse
% response of repeats it never saw". This does, by repeated stratified split-half over trials
% (see utils/imp_tf_cv_session.m for the method + the choices behind it).
%
% Requested by the user 2026-08-24: "normalised LTI fit comparison for all sessions but cross
% validated -- randomise both datasets first, then fit, then test."
%
% Two panels, both across all sessions:
%   tf_cv_shape_across_sessions.pdf   cross-validated 2C-i: measured HELD-OUT trace (solid) vs
%                                     the prediction of a model that never saw those trials
%                                     (dashed), peak-normalised, one pair per session.
%   tf_cv_r2_trial.pdf                in-sample vs held-out R^2 per session (median + IQR over
%                                     splits). The paired drop is the generalisation cost.
%
% USAGE
%   load_experiments            % (imp_tf_run appends AL_0048 if absent)
%   imp_tf_cv                   % <- this
% Knobs (optional, set before running):
%   CV_NSPLIT  random split-half repeats per session      [default 100]
%   CV_OUTDIR  where the PDFs go            [default paper/explore/tf_cv -- NOT a locked panel]
%   CV_EXPORT  write the PDFs                              [default true]

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
root = fileparts(here);
addpath(genpath(fullfile(root,'utils')));
addpath(here);

if ~exist('allExperiments','var') || isempty(allExperiments)
    fprintf('[CV] loading experiments (cold)\n');
    load_experiments;
end
if ~exist('fs','var')   || isempty(fs),   fs   = 35;  end
if ~exist('tWin','var') || isempty(tWin), tWin = 3.0; end
if ~exist('CV_NSPLIT','var') || isempty(CV_NSPLIT), CV_NSPLIT = 100; end
if ~exist('CV_EXPORT','var') || isempty(CV_EXPORT), CV_EXPORT = true; end
if ~exist('CV_OUTDIR','var') || isempty(CV_OUTDIR)
    CV_OUTDIR = fullfile(root,'paper','explore','tf_cv');   % candidate panel, not locked -> not figureN
end
if CV_EXPORT && ~exist(CV_OUTDIR,'dir'), mkdir(CV_OUTDIR); end

%% ---- (1) full-data fits: reuse the cache if present, else fit fresh (no bootstrap) ----------
fitFile = fullfile(here,'data','imp_tf_fits.mat');
if exist('Sprim','var') && iscell(Sprim) && ~isempty(Sprim)
    fprintf('[CV] using Sprim already in the workspace (%d sessions)\n', numel(Sprim));
elseif exist(fitFile,'file')
    fprintf('[CV] loading cached full-data fits -> %s\n', fitFile);
    L = load(fitFile,'Sprim');  Sprim = L.Sprim;
else
    fprintf('[CV] no cached fits -- running imp_tf_run (RUN_NBOOT=0, no export) to get orders\n');
    RUN_NBOOT = 0; RUN_EXPORT = false;
    imp_tf_run;
end

%% ---- (2) trial-level CV per session ---------------------------------------------------------
nS  = numel(Sprim);
CVo = struct('nSplit',CV_NSPLIT,'seed',7,'minTrials',6,'verbose',true);
fprintf('\n[CV] trial-level split-half CV, %d splits x 2 directions per session\n', CV_NSPLIT);
CV = cell(nS,1);
for k = 1:nS
    CV{k} = imp_tf_cv_session(allExperiments(k), fs, tWin, Sprim{k}, CVo);
end
ok = cellfun(@(c) isstruct(c) && isfield(c,'ok') && c.ok, CV);
CV = CV(ok);
n  = numel(CV);
assert(n >= 1, '[CV] no session produced a cross-validated fit.');
fprintf('[CV] %d/%d sessions cross-validated\n', n, nS);

PS = paperStyle();  setPaperDefaults();

%% ---- (3) panel A: cross-validated normalised overlay, all sessions --------------------------
figA = paperFig(PS.f2w, PS.f2h);  axA = axes(figA);  hold(axA,'on');
tmax = 0.5;
for k = 1:n
    c   = PS.sessColor(k);
    t   = CV{k}.tPost(:);
    hm  = CV{k}.h_meas_cv(:);   hp = CV{k}.h_pred_cv(:);
    m   = min([numel(t) numel(hm) numel(hp)]);
    t = t(1:m); hm = hm(1:m); hp = hp(1:m);
    sc  = max(abs(hm(isfinite(hm))));         % peak-normalise on the MEASURED held-out trace
    if isempty(sc) || sc == 0, continue; end
    plot(axA, t, hm/sc, '-',  'Color', c, 'LineWidth', PS.lw_mean);   % measured (held out)
    plot(axA, t, hp/sc, '--', 'Color', c, 'LineWidth', PS.lw_fit);    % predicted (never saw these trials)
end
yline(axA, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_zero);
xlim(axA, [0 tmax]);
xlabel(axA, 'time from onset (s)');
ylabel(axA, 'normalised \DeltaF/F');
set(axA, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir','out', 'Box','off');
hM = plot(axA, NaN, NaN, '-',  'Color','k', 'LineWidth', PS.lw_mean);
hP = plot(axA, NaN, NaN, '--', 'Color','k', 'LineWidth', PS.lw_fit);
lg = legend(axA, [hM hP], {'measured (held out)','LTI fit (held out)'}, ...
            'Location','southeast', 'Box','off');
lg.ItemTokenSize = [20 PS.lgd_token(2)];  lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;
% Footer: the held-out R2 the dashed curve actually earns, pooled across sessions x splits.
allOut = cell2mat(cellfun(@(c) c.R2_out(:),   CV, 'uni', 0));
allShp = cell2mat(cellfun(@(c) c.R2_shape(:), CV, 'uni', 0));
txt = sprintf('held-out R^2 = %.2f (amp-norm) | %.2f (shape) | median over %d sessions x %d splits', ...
              median(allOut,'omitnan'), median(allShp,'omitnan'), n, 2*CV_NSPLIT);
text(axA, 0.5, -0.235, txt, 'Units','normalized', 'HorizontalAlignment','center', ...
     'VerticalAlignment','top', 'FontSize', max(4.5,PS.fs*0.85), 'FontWeight', PS.fw, ...
     'Color', [0.25 0.25 0.25], 'Clipping','off');
if CV_EXPORT, paperExport(figA, fullfile(CV_OUTDIR,'tf_cv_shape_across_sessions.pdf')); end

%% ---- (4) panel B: in-sample vs held-out R^2 per session (median + IQR) -----------------------
figB = paperFig(PS.f2w*1.1, PS.f2h*1.1);  axB = axes(figB);  hold(axB,'on');
yline(axB, 0, '--', 'Color',[0.35 0.35 0.35], 'LineWidth', PS.lw_ref, 'HandleVisibility','off');
for k = 1:n
    c   = PS.sessColor(k);
    mi  = median(CV{k}.R2_in, 'omitnan');   qi = prctile(CV{k}.R2_in, [25 75]);
    mo  = median(CV{k}.R2_out,'omitnan');   qo = prctile(CV{k}.R2_out,[25 75]);
    plot(axB, [1 2], [mi mo], '-', 'Color', c, 'LineWidth', PS.lw_mean, 'HandleVisibility','off');
    plot(axB, [1 1], qi, '-', 'Color', c, 'LineWidth', 0.8, 'HandleVisibility','off');
    plot(axB, [2 2], qo, '-', 'Color', c, 'LineWidth', 0.8, 'HandleVisibility','off');
    plot(axB, 1, mi, 'o', 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 3, 'HandleVisibility','off');
    plot(axB, 2, mo, 'o', 'Color', c, 'MarkerFaceColor','w', 'MarkerSize', 3, 'HandleVisibility','off');
end
xlim(axB,[0.8 2.2]);  xticks(axB,[1 2]);  xticklabels(axB, {'in-sample','held out'});
ylabel(axB, 'R^2');
set(axB,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
mi = cellfun(@(c) median(c.R2_in,'omitnan'),  CV);
mo = cellfun(@(c) median(c.R2_out,'omitnan'), CV);
title(axB, sprintf('%d sessions   median %.2f \\rightarrow %.2f   \\Delta %.2f', ...
      n, median(mi), median(mo), median(mi-mo)), 'FontSize', PS.fs, 'FontWeight', PS.fw);
if CV_EXPORT, paperExport(figB, fullfile(CV_OUTDIR,'tf_cv_r2_trial.pdf')); end

%% ---- (5) numbers for the caption ------------------------------------------------------------
fprintf('\n=============================== [CV] SUMMARY ===============================\n');
fprintf('%-24s %6s %8s %18s %8s %8s\n','session','order','in-samp','held-out R2 [IQR]','shape','fail%%');
for k = 1:n
    fprintf('%-24s %2dp%dz%dd %8.3f  %6.3f [%5.3f %5.3f] %8.3f %7.0f%%\n', ...
        strrep(CV{k}.label,'_','\_'), CV{k}.np, CV{k}.nz, CV{k}.nd, ...
        median(CV{k}.R2_in,'omitnan'), median(CV{k}.R2_out,'omitnan'), ...
        prctile(CV{k}.R2_out,25), prctile(CV{k}.R2_out,75), ...
        median(CV{k}.R2_shape,'omitnan'), 100*CV{k}.reject);
end
fprintf('---------------------------------------------------------------------------\n');
fprintf('POOLED held-out R2: amp-norm %.3f | shape %.3f   (median over %d sessions x %d splits)\n', ...
        median(allOut,'omitnan'), median(allShp,'omitnan'), n, 2*CV_NSPLIT);
fprintf('CAPTION: order is selected once on the full session and held FIXED across folds;\n');
fprintf('         the CV validates the fitted DYNAMICS, not the order-selection step.\n');
fprintf('[CV] panels -> %s\n', CV_OUTDIR);
