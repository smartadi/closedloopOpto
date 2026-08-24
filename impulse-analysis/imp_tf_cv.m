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
% CV_PANELB: also draw the in-sample vs held-out R^2 comparison. NOT a paper panel
% (user, 2026-08-24: "dont need the r2 comparision for paper"), so off by default.
if ~exist('CV_PANELB','var') || isempty(CV_PANELB), CV_PANELB = false; end
% CV_SINGLE: the SUPPLEMENTARY single-session per-amplitude CV fit (user, 2026-08-24: "single
% session tf fitting ... same cross validation treatment ... same constraints" -> to supp).
% Uses the SAME engine/constraints as the cross-session fits, so consistency is automatic.
if ~exist('CV_SINGLE','var')    || isempty(CV_SINGLE),    CV_SINGLE    = true;      end
if ~exist('CV_SINGLE_MN','var') || isempty(CV_SINGLE_MN), CV_SINGLE_MN = 'AL_0033'; end
% CV_SINGLE_NAMP: how many amplitudes to draw on the single-session panel (user, 2026-08-24:
% "not so many amps, only a few"). Sub-threshold amplitudes (held-out R^2 <= 0, the SNR floor)
% are dropped first, then this many are spaced across what remains.
if ~exist('CV_SINGLE_NAMP','var') || isempty(CV_SINGLE_NAMP), CV_SINGLE_NAMP = 3; end
% Paper panel 2C goes straight into the paper figure folder (user, 2026-08-24: "only put them
% in the paper figure folders"). tf_cv_shape_across_sessions keeps a name distinct from the
% in-sample tf_shape_across_sessions (2C-i, written by imp_tf_run) so neither overwrites the other.
if ~exist('CV_OUTDIR','var') || isempty(CV_OUTDIR)
    CV_OUTDIR = fullfile(root,'paper','images','figure2');
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
hLine   = gobjects(n,1);         % one solid (measured) handle per session for the legend
legTxt  = cell(n,1);             % "Mouse 1a  R^2=0.50" -- animal label + held-out R^2 on the legend
mouseLab = imp_mouse_label(cellfun(@(c) c.mn, CV(:), 'uni', 0));   % shared cross-figure convention
for k = 1:n
    c   = PS.sessColor(k);
    t   = CV{k}.tPost(:);
    hm  = CV{k}.h_meas_cv(:);   hp = CV{k}.h_pred_cv(:);
    m   = min([numel(t) numel(hm) numel(hp)]);
    t = t(1:m); hm = hm(1:m); hp = hp(1:m);
    sc  = max(abs(hm(isfinite(hm))));         % peak-normalise on the MEASURED held-out trace
    if isempty(sc) || sc == 0, continue; end
    hLine(k) = plot(axA, t, hm/sc, '-',  'Color', c, 'LineWidth', PS.lw_mean);   % measured (held out)
    plot(axA, t, hp/sc, '--', 'Color', c, 'LineWidth', PS.lw_fit);               % predicted (never saw these trials)
    legTxt{k} = sprintf('%s  R^2=%.2f', mouseLab{k}, median(CV{k}.R2_out,'omitnan'));  % animal + held-out R^2
end
yline(axA, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_zero);
xlim(axA, [0 tmax]);
xlabel(axA, 'time from onset (s)');
ylabel(axA, 'normalised \DeltaF/F');
set(axA, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir','out', 'Box','off');
% Per-session legend carrying each session's HELD-OUT R^2 (user: "write down r2 values on
% legends"). Placed NORTHWEST: early post-onset the traces are diving to the dip (y<0), so the
% top-left is the empty quadrant -- southeast ran the box through the rising limb. Small token +
% no box = minimal (user, 2026-08-24). solid=measured / dashed=fit goes in the CAPTION now, not
% a footer, so the paper panel stays clean.
val = isgraphics(hLine);
lg  = legend(axA, hLine(val), legTxt(val), 'Location','northwest', 'Box','off');
lg.ItemTokenSize = [7 PS.lgd_token(2)];  lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;
allOut = cell2mat(cellfun(@(c) c.R2_out(:),   CV, 'uni', 0));
allShp = cell2mat(cellfun(@(c) c.R2_shape(:), CV, 'uni', 0));
% PAPER PANEL 2C -- the cross-validated shape overlay (user: "this figure will become 2C").
if CV_EXPORT, paperExport(figA, fullfile(CV_OUTDIR,'tf_cv_shape_across_sessions.pdf')); end

%% ---- (4) panel B: in-sample vs held-out R^2 per session (median + IQR) -----------------------
% Diagnostic only -- not a paper panel. Off unless CV_PANELB is set.
if CV_PANELB
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
end   % CV_PANELB

%% ---- (4b) SUPPLEMENTARY: single-session per-amplitude CV fit -----------------------------------
% "Single session TF fitting" (the old tf_data_vs_model view) but TRIAL-cross-validated and at the
% SAME widened constraints as the cross-session fits -- measured HELD-OUT trace vs the LTI
% prediction uA*h(t) of a model that never saw those trials, one pair per amplitude. Grey ramp =
% amplitudes within one session (Fig-2 colour policy); the session is named in the title.
if CV_SINGLE
    ksel = find(cellfun(@(c) contains(c.mn, CV_SINGLE_MN), CV), 1);
    if isempty(ksel), ksel = 1; end
    S1 = CV{ksel};
    if isfield(S1,'amp') && ~isempty(S1.amp.idx)
        aidx  = S1.amp.idx(:).';
        good  = aidx(S1.amp.R2(aidx) > 0);          % drop SNR-floor amps (held-out R^2 <= 0)
        if numel(good) >= 2, aidx = good; end       % keep the panel from emptying if all are noisy
        nShow = min(CV_SINGLE_NAMP, numel(aidx));
        ashow = aidx(unique(round(linspace(1, numel(aidx), nShow))));
        ramp  = interp1([0 1], [PS.grad0; PS.grad1], linspace(0,1,max(numel(ashow),2)));
        t     = S1.tPost(:);
        figS  = paperFig(PS.f2w*1.2, PS.f2h*1.1);  axS = axes(figS);  hold(axS,'on');
        hL = gobjects(numel(ashow),1);  lgS = cell(numel(ashow),1);
        for i = 1:numel(ashow)
            a = ashow(i);  c = ramp(i,:);
            hL(i) = plot(axS, t, S1.amp.meas(a,:), '-',  'Color', c, 'LineWidth', PS.lw_mean);
            plot(axS, t, S1.amp.pred(a,:), '--', 'Color', c, 'LineWidth', PS.lw_fit);
            lgS{i} = sprintf('%.1f V  R^2=%.2f', S1.amp.uA(a), S1.amp.R2(a));
        end
        yline(axS, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_zero);
        xlim(axS, [0 0.5]);
        xlabel(axS, 'time from onset (s)');  ylabel(axS, '\DeltaF/F (%)');
        set(axS, 'FontSize', PS.fs, 'FontWeight', PS.fw, 'TickDir','out', 'Box','off');
        title(axS, sprintf('%s  (held-out, %dp%dz%dd)', mouseLab{ksel}, S1.np, S1.nz, S1.nd), ...
              'FontSize', PS.fs, 'FontWeight', PS.fw, 'Interpreter','none');
        lg = legend(axS, hL, lgS, 'Location','southeast', 'Box','off');
        lg.ItemTokenSize = [12 PS.lgd_token(2)];  lg.FontSize = PS.fs;  lg.FontWeight = PS.fw;
        suppDir = fullfile(root,'paper','images','supplementary');
        if ~exist(suppDir,'dir'), mkdir(suppDir); end
        if CV_EXPORT
            paperExport(figS, fullfile(suppDir, ...
                sprintf('tf_cv_single_%s.pdf', matlab.lang.makeValidName(char(S1.mn)))));
        end
        fprintf('[CV] single-session supp panel (%s, %d amps) -> %s\n', ...
                S1.label, numel(ashow), suppDir);
    else
        fprintf(2,'[CV] CV_SINGLE on but no per-amplitude data for %s -- skipped\n', CV_SINGLE_MN);
    end
end

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
