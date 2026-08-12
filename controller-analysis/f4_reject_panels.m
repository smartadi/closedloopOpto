%% f4_reject_panels.m   [F4-REJ]  -- PAPER PANELS for cross-session disturbance rejection
%
% Fig-4 block 3, production styling. Turns the cross-session rejection result into
% paperFig/paperStyle panels: how much of the contra-predicted disturbance the controller
% actually removes, across every qualifying session.
%
% READS ONLY. Loads data/imp_reject_across_sessions.mat and draws it. No session is opened,
% nothing is refitted, no statistic is re-derived that the batch already computed -- the
% aggregates (er_gain, p_er_sess, er_gain_ci) are READ from the struct, because a second copy
% of an aggregation formula is a second thing that can drift from the reported number.
% Consequence: re-run imp_reject_across_sessions.m first whenever the caches change; this
% script will happily draw a stale struct and say so in its header line.
%
% METRIC. Primary is the ENERGY RATIO (Nick, 2026-07-28)
%     ER = ||A - ref||^2 / ||G - ref||^2   over the 0-3 s stim window
%     1 = the controller did no work (holds identically when A == G),  <1 = controller gain
% The legacy transmission ratio rho = ||A-ref||/||G|| is available via MET='rho' for
% reproducing pre-2026-08-10 numbers ONLY. The two are NOT interchangeable: rho's denominator
% is zero-referenced, so its LEVEL depends on where the brain's natural level happens to sit
% relative to the target and only the OL-vs-CL contrast ever meant anything. Quote one.
%
% WHAT TRAVELS WITH THESE PANELS. ER is a ratio against a Global the predictor produced, so
% two numbers must be quoted with it and both are printed by [F4-REJ-REPORT]:
%   Gdip   how far the Global trace itself dips through the stim -- a dipping Global means the
%          disturbance estimate already contains laser effect, so ER UNDER-states rejection
%   R2_te  the deployed predictor's held-out R^2, gated at ctrl_r2_floor() upstream
% Panel D exists for the same reason: it is the T1 objection ("the residual is just prediction
% error") in its cross-session form -- if rejection were a modelling artefact, sessions with a
% weaker predictor would report a bigger gain. A null there is the answer to the objection.
%
% Run:  (after) load_sessions -> ctrl_residual_build -> imp_reject_across_sessions
%       then:  f4_reject_panels        (no load_sessions needed -- reads the struct)
%
% PANEL SET (user, 2026-08-12): ONE session shown as a demo + its own statistic, then the
% combined-session statistics. Demo traces ride in the batch struct (XS.EX) so this script
% stays read-only and the demo is guaranteed to be the same decomposition the population
% numbers came from.
%   f4_reject_demo_ol / _cl      single session: Global (disturbance) vs Actual vs ref
%   f4_reject_demo_stat_<met>    that session's own per-trial OL vs CL
%   f4_reject_paired_<met>       COMBINED: per-session paired medians  <- the headline
%   f4_reject_trials_<met>       COMBINED: pooled per-trial (descriptive only)
%   f4_reject_gain_<met>         COMBINED: per-session gain + bootstrap CI
%   f4_reject_capacity_<met>     COMBINED: the T1 control (gain vs predictor R^2)
%
% SECTIONS: [F4-REJ-CFG] [F4-REJ-LOAD] [F4-REJ-DEMO] [F4-REJ-A] [F4-REJ-B] [F4-REJ-C]
%           [F4-REJ-D] [F4-REJ-REPORT]

%% [F4-REJ-CFG] -----------------------------------------------------------------
MET      = 'ER';       % 'ER' (primary) | 'rho' (legacy, reproduction only)
EXPORT   = true;
% REVIEW WORKFLOW (user, 2026-08-12): PNG first, approve, THEN vector PDFs. Flip to
% {'pdf','png'} once the panels are signed off -- nothing else changes, so the approved
% figure and the exported PDF are the same code path.
FMT      = {'png'};    % {'png'} = review | {'pdf','png'} = final
W = 6; H = 4;          % project default panel size (cm)

PS = paperStyle(); setPaperDefaults();
col_ol = PS.col_ol; col_cl = PS.col_cl;

here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis');  if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
outDir  = fullfile(here,'..','paper','images','figure4');
if EXPORT && ~exist(outDir,'dir'); mkdir(outDir); end

%% [F4-REJ-LOAD] ----------------------------------------------------------------
xf = fullfile(dataDir,'imp_reject_across_sessions.mat');
assert(exist(xf,'file')>0, ['[F4-REJ] %s not found. Run imp_reject_across_sessions.m first ' ...
    '(and ctrl_residual_build.m before that if the Stage-2 caches are stale).'], xf);
L = load(xf,'XS');  XS = L.XS;  Q = XS.Q;  nS = XS.nS;
xinfo = dir(xf);
fprintf('\n[F4-REJ] source: imp_reject_across_sessions.mat  (%s, %d sessions)\n', xinfo.date, nS);

% The gate is a property of the run, not of this script. An ungated struct must never reach a
% paper panel -- the whole point of the floor is that a weak Global manufactures rejection.
if ~isfield(XS,'USE_GATE') || ~XS.USE_GATE
    error(['[F4-REJ] this struct was built with the R^2 gate OFF (or predates it). ' ...
        'Ungated numbers are diagnostic only. Re-run imp_reject_across_sessions.m with USE_GATE=true.']);
end
fprintf('         R^2 gate ON at floor %.2f;  %d session(s) skipped upstream\n', ...
    XS.r2_floor, numel(XS.skipped));
assert(nS >= 2, '[F4-REJ] need >=2 qualifying sessions for a paired panel (have %d).', nS);

switch upper(MET)
    case 'ER'
        s_ol = XS.er_med_ol(:);  s_cl = XS.er_med_cl(:);
        t_ol = vertcat(Q.er_ol);  t_cl = vertcat(Q.er_cl);      % pooled per-trial
        gainV = XS.er_gain(:);  gain_ci = XS.er_gain_ci;  p_sess = XS.p_er_sess;
        ylab  = 'energy ratio  ||A-ref||^2/||G-ref||^2';
        ylab_s = 'energy ratio';
        nullY = 1;   % 1 = controller did no work
    case 'RHO'
        s_ol = XS.med_ol(:);  s_cl = XS.med_cl(:);
        t_ol = XS.pooled_ol(:);  t_cl = XS.pooled_cl(:);
        gainV = XS.gain(:);  gain_ci = XS.gain_ci;  p_sess = XS.p_sess;
        ylab  = 'transmission  ||A-ref||/||G||';
        ylab_s = 'transmission';
        nullY = 1;
    otherwise
        error('[F4-REJ] MET must be ''ER'' or ''rho'' (got ''%s'').', MET);
end
tag = lower(MET);
mice = unique({Q.mn});

%% [F4-REJ-DEMO] ONE session: what the decomposition looks like, and its own statistic
% The population panels below say how big the effect is; they do not show what it IS. These
% three panels are the single session the reader is shown: the contra-predicted Global (the
% disturbance the controller faced, from a hemisphere that never sees the laser), the measured
% Actual, and the reference -- once open-loop, once closed-loop, on SHARED y-limits so the two
% are directly comparable -- plus that session's own per-trial statistic.
% Traces come from XS.EX, written by the batch from the SAME decomposition the population
% numbers were computed from, so the demo cannot disagree with the summary.
if ~isfield(XS,'EX') || ~isfield(XS.EX,'sess_tag')
    fprintf('[F4-REJ] no exemplar traces in the struct (older run) -- demo panels skipped.\n');
else
    E = XS.EX;
    inWin = E.t >= -1 & E.t <= E.resp_s;
    tt = E.t(inWin);
    lo = min([E.Aol_m(inWin) E.Gol_m(inWin) E.Acl_m(inWin) E.Gcl_m(inWin) E.ref]);
    hi = max([E.Aol_m(inWin) E.Gol_m(inWin) E.Acl_m(inWin) E.Gcl_m(inWin) E.ref]);
    pad = 0.08*(hi-lo);  ylimD = [lo-pad hi+pad];

    demo = { 'ol', E.Aol_m, E.Aol_e, E.Gol_m, E.Gol_e, col_ol, E.n_ol; ...
             'cl', E.Acl_m, E.Acl_e, E.Gcl_m, E.Gcl_e, col_cl, E.n_cl };
    for m = 1:2
        figE = paperFig(W,H); axE = axes(figE); hold(axE,'on');
        Am = demo{m,2}(inWin);  Ae = demo{m,3}(inWin);
        Gm = demo{m,4}(inWin);  Ge = demo{m,5}(inWin);
        fill(axE,[tt fliplr(tt)],[Gm+Ge fliplr(Gm-Ge)],[.5 .5 .5], ...
            'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
        fill(axE,[tt fliplr(tt)],[Am+Ae fliplr(Am-Ae)],demo{m,6}, ...
            'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
        yline(axE,E.ref,'--','Color',[.35 .35 .35],'LineWidth',PS.lw_ref,'HandleVisibility','off');
        xline(axE,0,':','Color',[.6 .6 .6],'LineWidth',PS.lw_zero,'HandleVisibility','off');
        plot(axE,tt,Gm,'-','Color',[.45 .45 .45],'LineWidth',PS.lw_fit);
        plot(axE,tt,Am,'-','Color',demo{m,6},   'LineWidth',PS.lw_mean);
        xlabel(axE,'time (s)','FontSize',PS.fs,'FontWeight',PS.fw);
        ylabel(axE,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight',PS.fw);
        set(axE,'FontSize',PS.fs,'FontWeight',PS.fw);  ylim(axE,ylimD);
        lgE = legend(axE,{'Global (disturbance)','Actual'},'Location','best','Box','off');
        lgE.ItemTokenSize = PS.lgd_token;  lgE.FontSize = PS.fs;
        title(axE,sprintf('%s, %d trials', upper(demo{m,1}), demo{m,7}), ...
            'FontSize',PS.fs,'FontWeight',PS.fw);
        cleanAxes(axE);
        deal_export(figE, outDir, sprintf('f4_reject_demo_%s',demo{m,1}), EXPORT, FMT);
    end

    % that session's OWN per-trial statistic -- the single-session claim, before pooling
    % keyed off `tag` rather than an if/else on MET, which the analyzer constant-folds
    DVSRC  = struct('er', {{E.er_ol, E.er_cl, E.p_er}}, 'rho', {{E.rho_ol, E.rho_cl, E.p_rho}});
    dsel   = DVSRC.(tag);
    dv_ol  = dsel{1};  dv_cl = dsel{2};  p_demo = dsel{3};
    figF = paperFig(W,H); axF = axes(figF); hold(axF,'on');
    yline(axF,nullY,'--','Color',[.55 .55 .55],'LineWidth',PS.lw_ref,'HandleVisibility','off');
    DV = {dv_ol(isfinite(dv_ol)), dv_cl(isfinite(dv_cl))};  CVd = [col_ol; col_cl];
    for m = 1:2
        v = DV{m};
        if numel(v) > 4
            [fk,yk] = ksdensity(v);  fk = fk/max(fk)*0.34;
            fill(axF,[m-fk, m*ones(size(fk))],[yk, fliplr(yk)],CVd(m,:), ...
                'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
        end
        plot(axF,[m-0.34 m+0.06],median(v)*[1 1],'-','Color',CVd(m,:),'LineWidth',PS.lw_mean);
    end
    set(axF,'XTick',[1 2],'XTickLabel',{'OL','CL'},'FontSize',PS.fs,'FontWeight',PS.fw);
    xlim(axF,[0.5 2.5]);
    ylabel(axF,ylab_s,'FontSize',PS.fs,'FontWeight',PS.fw);
    title(axF,sprintf('p=%.2g', p_demo),'FontSize',PS.fs,'FontWeight',PS.fw);
    cleanAxes(axF);
    deal_export(figF, outDir, sprintf('f4_reject_demo_stat_%s',tag), EXPORT, FMT);

    fprintf('\n[F4-REJ-DEMO] %s (single-session demo, deployed R^2 %.3f)\n', E.sess_tag, E.R2_te);
    fprintf('  median %s : OL %.3f | CL %.3f   (%d / %d trials, rank-sum p=%.3g)\n', ...
        ylab_s, median(DV{1}), median(DV{2}), numel(DV{1}), numel(DV{2}), p_demo);
end

%% [F4-REJ-A] per-session paired OL -> CL ---------------------------------------
% The headline. Each session contributes ONE point per condition, so this is the panel the
% signrank p belongs to; the pooled-trial view (panel B) is descriptive only.
figA = paperFig(W,H); axA = axes(figA); hold(axA,'on');
for k = 1:nS
    plot(axA,[1 2],[s_ol(k) s_cl(k)],'-','Color',[.72 .72 .72], ...
        'LineWidth',PS.lw_trial*1.5,'HandleVisibility','off');
end
yline(axA,nullY,'--','Color',[.55 .55 .55],'LineWidth',PS.lw_ref,'HandleVisibility','off');
scatter(axA,ones(nS,1),  s_ol, 12, col_ol,'filled','MarkerFaceAlpha',.85);
scatter(axA,2*ones(nS,1),s_cl, 12, col_cl,'filled','MarkerFaceAlpha',.85);
plot(axA,[1 2],[median(s_ol) median(s_cl)],'-k','LineWidth',PS.lw_mean);
set(axA,'XTick',[1 2],'XTickLabel',{'OL','CL'},'FontSize',PS.fs,'FontWeight',PS.fw);
xlim(axA,[0.7 2.3]);
ylabel(axA,ylab_s,'FontSize',PS.fs,'FontWeight',PS.fw);
title(axA,sprintf('n=%d, p=%.2g', nS, p_sess),'FontSize',PS.fs,'FontWeight',PS.fw);
cleanAxes(axA);
deal_export(figA, outDir, sprintf('f4_reject_paired_%s',tag), EXPORT, FMT);

%% [F4-REJ-B] pooled per-trial distributions ------------------------------------
% DESCRIPTIVE ONLY -- trials within a session are not independent, and one long session would
% otherwise carry the result. Drawn because the session medians hide how much of the trial
% distribution actually sits below the no-work line.
figB = paperFig(W,H); axB = axes(figB); hold(axB,'on');
yline(axB,nullY,'--','Color',[.55 .55 .55],'LineWidth',PS.lw_ref,'HandleVisibility','off');
V = {t_ol(isfinite(t_ol)), t_cl(isfinite(t_cl))};  CV = [col_ol; col_cl];
hw = 0.34;
for m = 1:2
    v = V{m};
    if numel(v) > 4
        [fk,yk] = ksdensity(v);  fk = fk/max(fk)*hw;
        fill(axB,[m-fk, m*ones(size(fk))],[yk, fliplr(yk)],CV(m,:), ...
            'FaceAlpha',PS.fa,'EdgeColor','none','HandleVisibility','off');
    end
    plot(axB,[m-hw m+0.06],median(v)*[1 1],'-','Color',CV(m,:),'LineWidth',PS.lw_mean);
end
set(axB,'XTick',[1 2],'XTickLabel',{'OL','CL'},'FontSize',PS.fs,'FontWeight',PS.fw);
xlim(axB,[0.5 2.5]);
ylabel(axB,ylab_s,'FontSize',PS.fs,'FontWeight',PS.fw);
title(axB,sprintf('%d / %d trials', numel(V{1}), numel(V{2})),'FontSize',PS.fs,'FontWeight',PS.fw);
cleanAxes(axB);
deal_export(figB, outDir, sprintf('f4_reject_trials_%s',tag), EXPORT, FMT);

%% [F4-REJ-C] per-session gain, sorted ------------------------------------------
% gain = OL - CL, so >0 means CL removed more disturbance energy than OL in that session.
% Sorted so the reader can count sign agreement without reading labels; the CI band is the
% session-level bootstrap already computed by the batch.
figC = paperFig(W,H); axC = axes(figC); hold(axC,'on');
gs = sort(gainV);
fill(axC,[0.4 nS+0.6 nS+0.6 0.4],[gain_ci(1) gain_ci(1) gain_ci(2) gain_ci(2)], ...
    [0.35 0.55 0.75],'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
bar(axC,1:nS,gs,0.62,'FaceColor',[0.35 0.55 0.75],'EdgeColor','none');
yline(axC,0,'-','Color',[.35 .35 .35],'LineWidth',PS.lw_zero,'HandleVisibility','off');
yline(axC,mean(gainV),'--','Color',[0.10 0.30 0.70],'LineWidth',PS.lw_ref,'HandleVisibility','off');
xlim(axC,[0.4 nS+0.6]);
set(axC,'XTick',[],'FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axC,'session','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axC,'gain (OL-CL)','FontSize',PS.fs,'FontWeight',PS.fw);
title(axC,sprintf('CL better in %d/%d', nnz(gainV>0), nS),'FontSize',PS.fs,'FontWeight',PS.fw);
cleanAxes(axC);
deal_export(figC, outDir, sprintf('f4_reject_gain_%s',tag), EXPORT, FMT);

%% [F4-REJ-D] the T1 control: gain vs predictor quality -------------------------
% If "the controller rejects the disturbance" were really "the predictor missed some of the
% response", the gain would GROW as the predictor gets worse. Plot it and test it. A flat,
% non-significant relationship is the strongest available answer to that objection; a negative
% slope is a finding that must be reported, not buried.
r2te = [Q.R2_te].';
figD = paperFig(W,H); axD = axes(figD); hold(axD,'on');
scatter(axD, r2te, gainV, 14, [0.25 0.25 0.25],'filled','MarkerFaceAlpha',.8);
yline(axD,0,'-','Color',[.35 .35 .35],'LineWidth',PS.lw_zero,'HandleVisibility','off');
rs_cap = NaN; p_cap = NaN;
if nS >= 4 && numel(unique(r2te(isfinite(r2te)))) > 2
    [rs_cap,p_cap] = corr(r2te, gainV, 'type','Spearman','rows','complete');
    b = polyfit(r2te(isfinite(r2te)&isfinite(gainV)), gainV(isfinite(r2te)&isfinite(gainV)), 1);
    xr = linspace(min(r2te),max(r2te),10);
    plot(axD, xr, polyval(b,xr), '-','Color',[0.10 0.30 0.70],'LineWidth',PS.lw_fit);
    title(axD,sprintf('r_s=%+.2f, p=%.2g', rs_cap, p_cap),'FontSize',PS.fs,'FontWeight',PS.fw);
else
    title(axD,sprintf('n=%d (test needs >=4)', nS),'FontSize',PS.fs,'FontWeight',PS.fw);
end
xlabel(axD,'deployed R^2','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axD,'gain (OL-CL)','FontSize',PS.fs,'FontWeight',PS.fw);
set(axD,'FontSize',PS.fs,'FontWeight',PS.fw);
cleanAxes(axD);
deal_export(figD, outDir, sprintf('f4_reject_capacity_%s',tag), EXPORT, FMT);

%% [F4-REJ-REPORT] numbers for the caption --------------------------------------
% Everything a caption or a Results sentence needs, in one block, in the units of MET.
fprintf('\n[F4-REJ-REPORT] metric = %s   (%d sessions, %d mice: %s)\n', ...
    upper(MET), nS, numel(mice), strjoin(mice,', '));
fprintf('  per-session median  : OL %.3f [IQR %.3f] | CL %.3f [IQR %.3f]\n', ...
    median(s_ol), iqr(s_ol), median(s_cl), iqr(s_cl));
fprintf('  paired OL vs CL     : signrank p=%.3g, mean gain %+.3f, 95%% CI [%+.3f, %+.3f]\n', ...
    p_sess, mean(gainV), gain_ci(1), gain_ci(2));
fprintf('  CL better in        : %d/%d sessions\n', nnz(gainV>0), nS);
if strcmpi(MET,'ER')
    fprintf('  vs the no-work line : OL p=%.3g | CL p=%.3g  (signrank vs 1)\n', XS.p_er_ol1, XS.p_er_cl1);
end
fprintf('  pooled per-trial    : OL %.3f | CL %.3f   (DESCRIPTIVE ONLY, n=%d/%d trials)\n', ...
    median(V{1}), median(V{2}), numel(V{1}), numel(V{2}));
fprintf('  predictor (gated)   : deployed R^2 %.3f-%.3f (floor %.2f)\n', ...
    min(r2te), max(r2te), XS.r2_floor);
fprintf('  T1 control          : corr(gain, R^2) r_s=%+.2f p=%.2g  %s\n', rs_cap, p_cap, ...
    t1_verdict(rs_cap, p_cap));
fprintf('  ** QUOTE WITH IT ** Global dip (leak) 1-3 s: OL %+.3f +/- %.3f | CL %+.3f +/- %.3f %%dF/F\n', ...
    mean(XS.Gdip_ol), std(XS.Gdip_ol), mean(XS.Gdip_cl), std(XS.Gdip_cl));
fprintf('     A dipping Global already contains laser effect => the disturbance is UNDER-stated\n');
fprintf('     => rejection is UNDER-reported, not over-reported. Say so in Methods.\n');
if ~isempty(XS.skipped)
    fprintf('  skipped upstream:\n');
    for i = 1:numel(XS.skipped)
        fprintf('    %-22s %s\n', XS.skipped(i).fld, XS.skipped(i).msg);
    end
end
fprintf('[F4-REJ] panels -> %s\n', outDir);

%% ---- local functions (must sit at EOF in a script) ---------------------------
function deal_export(fig, outDir, base, EXPORT, FMT)
if ~EXPORT; return; end
for i = 1:numel(FMT)
    paperExport(fig, fullfile(outDir,[base '.' FMT{i}]));
end
end

function s = t1_verdict(rs, p)
if ~isfinite(rs) || ~isfinite(p)
    s = '(not tested)';
elseif p >= 0.05
    s = '<- NULL: rejection does not track predictor weakness (answers T1)';
elseif rs < 0
    s = '<- WARNING: weaker predictors report LARGER gain. Report this.';
else
    s = '<- gain rises with predictor quality (opposite of the T1 artefact)';
end
end
