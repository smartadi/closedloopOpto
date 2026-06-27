% impulse-analysis/contra_residual.m
% SECTIONED residual-analysis workbench for the contra->ipsi LOCAL stim effect.
% Run [CP-SETUP] first (builds R, S, and the Actual/Global/Local decomposition),
% then run any section below on its own (Ctrl+Enter), in any order:
%   [CP-RESi]   clickable per-trial inspector (actual / contra-pred / residual / motion)
%   [CP-LOCAL]  overview: where each state's effect lives (GLOBAL=contra vs LOCAL=residual)
%   [CP-MOTION] motion-only effect (No-motion vs Motion: predictability + mean dip)
%   [CP-MOTION-AMP] per-amplitude motion vs |dip dev| (fig-3 style, large fonts; amp_sig switch)
%   [CP-VAR]    pre-stim variance-only effect (scatter + dose-response + partial)
%   [CP-DELTA]  pre-stim 1-4 Hz delta-only effect
%
% Shared pipeline: utils/cp_residual_core.m. Helpers: utils/cp_agl.m (decomposition),
% utils/cp_cont_state.m (continuous-state figure), utils/cp_motion_amp.m (per-amp),
% utils/cp_res_inspector.m. Cross-session batch: cp_state_batch.m.
% Concept: the trial-average ipsi dip ~ a low-dim LTI/SISO impulse response; contra
% predicts the GLOBAL activity flowing into the ipsi kernel; residual = LOCAL stim
% effect; the question is whether that local effect is brain-state dependent.
%
% Metric (ported from motion_analysis.m fig 6): |dip - amplitude-mean| = single-trial
% deviation from the trial-average (lower = more predictable). Split per trial into
%   dA = actual (= fig 6, global+local) | dG = contra pred (GLOBAL) | dL = residual (LOCAL).
%
% Presettable before [CP-SETUP]:
%   selExp     (3)     — experiment index
%   decontam   (false) — bleed comp OFF (cancels in within-amp state metrics)
%   use_motion (false) — keep motion OUT of the contra map so it can be tested as a
%                        state in [CP-MOTION]; variance/delta unaffected (R² 0.899 vs 0.900)
%
% Prereq: load_experiments.m has been run (allExperiments in workspace).

%% [CP-SETUP] Build residual + Actual/Global/Local decomposition — RUN THIS FIRST
close all;
wrap_path = mfilename('fullpath');
if isempty(wrap_path), wrap_path = fullfile(pwd, 'contra_residual.m'); end
addpath(genpath(fullfile(fileparts(wrap_path), '..', 'utils')));

if ~exist('allExperiments','var') || isempty(allExperiments)
    error('contra_residual: run load_experiments.m first.');
end
if ~exist('selExp','var')     || isempty(selExp),     selExp     = 3;     end
if ~exist('decontam','var')   || isempty(decontam),   decontam   = false; end
if ~exist('use_motion','var') || isempty(use_motion), use_motion = false; end

opts  = struct('decontam', decontam, 'use_motion', use_motion, ...
               'make_wide', true, 'plot', false);
[R, S] = cp_residual_core(allExperiments, selExp, opts);

% Per-trial fig-6 deviation (z-within-amp) for Actual/Global/Local + pooled dip traces.
[dA, dG, dL, trA, trG, trL] = cp_agl(R);
AGL = {'Actual (fig6)', dA; 'Global (contra)', dG; 'Local (residual)', dL};

if R.use_motion
    warning(['[CP-SETUP] use_motion=true regresses motion out of the residual; the ' ...
             '[CP-MOTION] test will be biased. Set use_motion=false and re-run.']);
end
fprintf('\n[CP-SETUP] %s %s e%d | decontam=%d motion=%d | held-out R²=%.3f\n', ...
    R.mn, R.td, R.en, R.decontam, R.use_motion, R.cv_mean);
fprintf('  partial(dev_stim, state | dev_pre):  Motion %+.3f (p=%.3g) | PreVar %+.3f (p=%.3g) | PreDelta %+.3f (p=%.3g)\n', ...
    S.r_partial(1), S.p_partial(1), S.r_partial(2), S.p_partial(2), S.r_partial(3), S.p_partial(3));
fprintf('  -> now run any of: [CP-RESi] [CP-LOCAL] [CP-MOTION] [CP-MOTION-AMP] [CP-VAR] [CP-DELTA]\n');

%% [CP-RESi] Clickable inspector — click a trial: actual / contra-pred / residual / motion
if ~exist('R','var'), error('Run [CP-SETUP] first.'); end
if isempty(R.Sin)
    warning('[CP-RESi] no inspector payload (make_wide was off). Re-run [CP-SETUP].');
else
    cp_res_inspector(R.Sin);
    fprintf('[CP-RESi] Inspector open — click a scatter point (snaps to nearest trial).\n');
end

%% [CP-LOCAL] Overview: where each state effect lives (GLOBAL contra vs LOCAL residual)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
states = {'Motion',  'Motion (z)',         R.mot, R.okM; ...
          'PreVar',  'Pre-stim var (z)',   R.pv,  R.okV; ...
          'PreDelta','Pre-stim \delta (z)',R.dp,  R.okD};
fprintf('\n[CP-LOCAL] Spearman rho of |dip dev| with each state (z-within-amp):\n');
fprintf('  %-9s  Actual   Global   Local\n', 'state');
for s = 1:3
    rr = nan(1,3);
    for c = 1:3
        m = states{s,4} & isfinite(AGL{c,2});
        rr(c) = corr(AGL{c,2}(m), states{s,3}(m), 'type','Spearman','rows','complete');
    end
    fprintf('  %-9s  %+.3f   %+.3f   %+.3f\n', states{s,1}, rr(1), rr(2), rr(3));
end
figL = paperFig(18, 14);
for s = 1:3
    for c = 1:3
        axL = subplot(3,3,(s-1)*3+c); hold(axL,'on');
        m = states{s,4} & isfinite(AGL{c,2}); xv = states{s,3}(m); yv = AGL{c,2}(m);
        scatter(axL, xv, yv, 6, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha',0.3);
        if numel(xv) > 2
            pc = polyfit(xv,yv,1); xl = [min(xv) max(xv)];
            plot(axL, xl, polyval(pc,xl), 'r-', 'LineWidth',1.0);
            [rv,pp] = corr(xv,yv,'type','Spearman');
            title(axL, sprintf('%s  \\rho=%+.2f p=%.2g', AGL{c,1}, rv, pp), 'FontSize',5,'FontWeight','bold');
        end
        set(axL,'Box','off','TickDir','out','FontSize',5,'FontWeight','bold');
        if s==3, xlabel(axL, states{s,2}, 'FontSize',5,'FontWeight','bold'); end
        if c==1, ylabel(axL, sprintf('%s\n|dip dev| (z)', states{s,2}), 'FontSize',5,'FontWeight','bold'); end
    end
end
sgtitle(figL, sprintf('CP-LOCAL overview  %s %s e%d  (rows=state, cols=Actual/Global/Local)', ...
    R.mn, R.td, R.en), 'FontSize',6,'FontWeight','bold','Interpreter','tex');
paperExport(figL, fullfile(R.paper_root,'images','figure2','cp_local_state.png'));
fprintf('[CP-LOCAL] Exported cp_local_state.png\n');

%% [CP-MOTION] Motion-only: predictability (No-motion vs Motion) + mean dip trace
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
mot = R.mot;  noM = mot <= 0.5;  yesM = mot > 0.5;   % binary split (motion z is zero-inflated; lab motThr_hi=0.5)
[rp,pp_] = partialcorr(R.devS(R.okM), mot(R.okM), R.devP(R.okM), 'type','Spearman','rows','complete');
fprintf('\n[CP-MOTION] partial(dev_stim, motion | dev_pre) rho=%+.3f p=%.3g | n(No/Mot)=%d/%d\n', ...
    rp, pp_, sum(noM), sum(yesM));
clsCol = [0.3 0.55 0.85; 0.85 0.2 0.2];  clsLab = {'No motion','Motion'};  TR = {trA, trG, trL};
figM = paperFig(18, 11);
for c = 1:3
    d = AGL{c,2};  T = TR{c};
    axt = subplot(2,3,c); hold(axt,'on');               % top: |dip dev| No-motion vs Motion
    grp = {d(noM & isfinite(d)), d(yesM & isfinite(d))};
    for q = 1:2
        v = grp{q};  mu = mean(v);  se = std(v)/sqrt(max(numel(v),1));
        bar(axt, q, mu, 0.6, 'FaceColor',clsCol(q,:), 'FaceAlpha',0.55, 'EdgeColor','none');
        errorbar(axt, q, mu, se, 'k', 'LineWidth',1, 'CapSize',5);
    end
    pr = ranksum(grp{1}, grp{2});
    set(axt,'XTick',1:2,'XTickLabel',clsLab,'XLim',[0.4 2.6],'Box','off','TickDir','out','FontSize',6,'FontWeight','bold');
    title(axt, sprintf('%s  ranksum p=%.2g', AGL{c,1}, pr), 'FontSize',6,'FontWeight','bold');
    if c==1, ylabel(axt, '|dip dev| (z) [lower=predictable]','FontSize',6,'FontWeight','bold'); end
    axb = subplot(2,3,3+c); hold(axb,'on');             % bottom: mean dip trace by motion class
    cls = {noM, yesM};
    for q = 1:2
        idx = cls{q} & any(isfinite(T),2);
        m  = mean(T(idx,:),1,'omitnan');  se = std(T(idx,:),0,1,'omitnan')/sqrt(max(sum(idx),1));
        patch(axb,[R.t_imp,fliplr(R.t_imp)],[m+se,fliplr(m-se)],clsCol(q,:),'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
        plot(axb, R.t_imp, m, 'Color',clsCol(q,:), 'LineWidth',1.2, 'DisplayName',sprintf('%s (n=%d)',clsLab{q},sum(idx)));
    end
    xline(axb,0,'k:','LineWidth',0.5,'HandleVisibility','off'); yline(axb,0,'k--','LineWidth',0.4,'HandleVisibility','off');
    set(axb,'Box','off','TickDir','out','FontSize',6,'FontWeight','bold'); xlabel(axb,'Time re onset (s)','FontSize',6,'FontWeight','bold');
    if c==1, ylabel(axb,'\DeltaF/F (%)','FontSize',6,'FontWeight','bold'); lg=legend(axb,'Location','south','Box','off','FontSize',5); lg.ItemTokenSize=[6 6]; end
end
sgtitle(figM, sprintf('CP-MOTION  %s %s e%d  (top: predictability | bottom: mean dip)  by motion class', ...
    R.mn, R.td, R.en), 'FontSize',6,'FontWeight','bold','Interpreter','tex');
paperExport(figM, fullfile(R.paper_root,'images','figure2','cp_motion_residual.png'));
fprintf('[CP-MOTION] Exported cp_motion_residual.png\n');

%% [CP-MOTION-AMP] Per-amplitude motion vs |dip dev| (figure-3 style, large fonts)
% One subplot per amplitude (within-amp r controls for amplitude). Pick the signal:
%   amp_sig = 'Actual' (= motion_analysis fig 3) | 'Global' (contra) | 'Local' (residual)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
if ~exist('amp_sig','var') || isempty(amp_sig), amp_sig = 'Actual'; end
imp_amp = allExperiments(R.selExp).imp;
switch lower(amp_sig)
    case 'global', SIGc = R.prr_imp;  sName = 'Global (contra)';
    case 'local',  SIGc = R.res_imp;  sName = 'Local (residual)';
    otherwise,     SIGc = R.act_imp;  sName = 'Actual (fig3)';  amp_sig = 'Actual';
end
cp_motion_amp(R, imp_amp, SIGc, sName, sprintf('cp_motion_amp_%s.png', lower(amp_sig)));

%% [CP-VAR] Pre-stim variance-only effect (A/G/L scatter + Local dose-response + partial)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
cp_cont_state('PreVar', 'Pre-stim var (z)', R.pv, AGL, R.devS, R.devP, R.okV, R, 'cp_var_residual.png');

%% [CP-DELTA] Pre-stim 1-4 Hz delta-only effect (A/G/L scatter + Local dose-response + partial)
if ~exist('dL','var'), error('Run [CP-SETUP] first.'); end
cp_cont_state('PreDelta', 'Pre-stim \delta (z)', R.dp, AGL, R.devS, R.devP, R.okD, R, 'cp_delta_residual.png');
