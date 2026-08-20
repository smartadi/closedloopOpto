%% make_lti_cv_fig.m -- cross-validation figure for the LTI plant fits
%
% The 2C-i shape panel draws an IN-SAMPLE fit (the model saw every amplitude it is drawn
% against), so it cannot answer "does the plant model generalise". This does, using the
% leave-one-amplitude-out folds already computed in imp_tf_fit_session.m: refit the model on
% all amplitudes but one, then predict the held-out one.
%
% Two panels:
%   tf_cv_traces_<tag>.pdf   measured vs HELD-OUT prediction, one trace pair per amplitude.
%                            The dashed curve was produced by a model that never saw that
%                            amplitude, so agreement is real generalisation, not fit quality.
%   tf_cv_r2.pdf             in-sample R2 vs held-out R2, one line per fold, all sessions.
%                            The identity line is "no loss"; below zero is worse than
%                            predicting the amplitude's own mean.
%
% Requires imp_tf_run to have been run in this workspace (Sprim). Run talk/redraw_plant_panels
% or imp_tf_run first, or call this straight after either.
%
% Requested by the user 2026-08-19 after the shape panel turned out not to be cross-validated.

root   = 'C:\Users\aditya\Documents\projects\brain_paper';
outDir = fullfile(root,'talk');
addpath(genpath(fullfile(root,'utils')));
addpath(fullfile(root,'impulse-analysis'));
cd(fullfile(root,'impulse-analysis'));

if ~exist('allExperiments','var') || isempty(allExperiments)
    fprintf('[CV] loading experiments (cold)\n');
    load_experiments;
end
if ~exist('Sprim','var') || isempty(Sprim)
    fprintf('[CV] running imp_tf_run to build the fits\n');
    RUN_TALK = true; RUN_OUTDIR = outDir; RUN_EXPORT = true; RUN_NBOOT = 100;   %#ok<NASGU>
    imp_tf_run;
end

PS = paperStyle(); setPaperDefaults();
ok = cellfun(@(s) isfield(s,'ok') && s.ok && isfield(s,'loao_pred'), Sprim);
S  = Sprim(ok);
n  = numel(S);
fprintf('[CV] %d session(s) with LOAO predictions stored\n', n);

%% ---- panel 1: held-out predictions, per amplitude, one panel per session ----
% Amplitudes within a session are a dose series, so the single-hue ramp is the right encoding
% (dark = weakest drive). Measured solid, held-out prediction dashed in the same hue: the eye
% checks each pair locally instead of matching across a legend.
for k = 1:n
    T  = S{k};
    t  = T.tPost(:);
    nA = size(T.loao_pred,1);
    use = find(any(isfinite(T.loao_pred), 2));
    if isempty(use), continue; end
    ramp = interp1([0 1], [PS.grad0; PS.grad1], linspace(0,1,max(numel(use),2)));

    f = paperFig(PS.f2w*1.35, PS.f2h*1.1);  ax = axes(f); hold(ax,'on');
    for j = 1:numel(use)
        a = use(j);  c = ramp(j,:);
        m = min([numel(t), size(T.loao_meas,2), size(T.loao_pred,2)]);
        plot(ax, t(1:m), T.loao_meas(a,1:m), '-',  'Color', c, 'LineWidth', PS.lw_mean);
        plot(ax, t(1:m), T.loao_pred(a,1:m), '--', 'Color', c, 'LineWidth', PS.lw_fit);
    end
    yline(ax, 0, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_zero);
    xlim(ax, [t(1) t(end)]);
    xlabel(ax, 'time from onset (s)');
    ylabel(ax, '\DeltaF/F (%)');
    hM = plot(ax, NaN, NaN, '-',  'Color','k', 'LineWidth', PS.lw_mean);
    hP = plot(ax, NaN, NaN, '--', 'Color','k', 'LineWidth', PS.lw_fit);
    lg = legend(ax, [hM hP], {'measured','predicted (held out)'}, 'Location','southeast', 'Box','off');
    lg.ItemTokenSize = [20 PS.lgd_token(2)];  lg.FontSize = PS.fs; lg.FontWeight = PS.fw;
    set(ax,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
    r2 = T.R2_loao(use);
    title(ax, sprintf('%s   held-out R^2 %.2f to %.2f', strrep(T.label,'_','\_'), ...
          min(r2), max(r2)), 'FontSize', PS.fs, 'FontWeight', PS.fw);
    tag = matlab.lang.makeValidName(T.label);
    paperExport(f, fullfile(outDir, sprintf('tf_cv_traces_%s.pdf', tag)));
    fprintf('[CV] %-26s folds %d | held-out R2 %s\n', T.label, numel(use), ...
            strjoin(compose('%+.2f', r2(:).'), ' '));
end

%% ---- panel 2: in-sample vs held-out R2, every fold ----
% Collect first, plot second: the fold stats are also dumped to a .mat so this panel can be
% restyled without paying another cold load of the experiments (~20 min).
allIn = []; allOut = []; allSess = []; allAmp = [];
for k = 1:n
    T = S{k};
    a = find(isfinite(T.R2_loao) & isfinite(T.R2));
    if isempty(a), continue; end
    allIn   = [allIn;   T.R2(a(:))];        %#ok<AGROW>
    allOut  = [allOut;  T.R2_loao(a(:))];   %#ok<AGROW>
    allSess = [allSess; k*ones(numel(a),1)];%#ok<AGROW>
    allAmp  = [allAmp;  a(:)];              %#ok<AGROW>
end
cvStats = struct('in',allIn,'out',allOut,'sess',allSess,'amp',allAmp, ...
                 'labels',{cellfun(@(x) x.label, S, 'uni', 0)});
save(fullfile(outDir,'tf_cv_stats.mat'), 'cvStats');

% Drawing lives in talk/plot_cv_r2.m so the panel can be restyled straight from
% tf_cv_stats.mat without another cold load of the experiments.
plot_cv_r2(cvStats, outDir);

fprintf('[CV] -> %s\n', outDir);
