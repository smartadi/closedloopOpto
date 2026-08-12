%% imp_reject_across_sessions.m   [IMP-XSESS]  -- STREAM 2 (confirmatory)
% Repeat ONLY the headline disturbance-rejection statistic across every qualifying
% controller session and present the COMBINED result. Deliberately does NOT re-run
% the internal_model_principle suite (Q1/Q2/Q3, null-models, galleries, GUIs, state
% framework) -- that stays a single-session playground (Stream 1).
%
% Two-stream contract:
%   Stream 1  internal_model_principle.m  -> you tune the analysis on ONE session.
%   Stream 2  THIS script                 -> once happy, confirm the main stat on ALL.
% Both compute rho through the SAME kernel (imp_reject_core.m) via the SAME trial
% builder (imp_build_session.m), so the population number can never drift from the
% single-session number.
%
% PREREQUISITE (built separately, run first): each session needs Stage-1
% (ctrl_ols_spont) + Stage-2 (ctrl_ols_ol_stimblind, target_mode='canonical')
% caches in controller-analysis/data/. Sessions lacking them are auto-skipped and
% listed -- so this script also *is* the C1 qualification audit.
%
% Run: load_sessions.m  ->  imp_reject_across_sessions.m

%% [XSESS-CFG] ------------------------------------------------------------------
CFG.nSV_load = 500;  CFG.Fs = 35;  CFG.pre_s = 1.0;  CFG.resp_s = 3.0;
nBoot = 2000;  rng(7,'twister');
SESS = 1:numel(fields);          % candidate sessions; auto-skips those without caches
% ADMISSION GATE (user, 2026-08-12) -- identical rule in all three cross-session scripts
% (ctrl_ols_xsess.m, this, imp_state_across_sessions.m). rho and ER are ratios against a
% Global the predictor produced, so a Global below the floor hands its own prediction error
% to the residual and manufactures rejection out of model weakness. Gate first, then pool.
r2_floor = ctrl_r2_floor();      % 0.85 on the DEPLOYED (Stage-2) predictor
USE_GATE = true;                 % false = diagnostic only, NEVER for a reported number
% EXEMPLAR session for the Fig-4 demo panels. Its trial-averaged traces are stored in XS.EX so
% f4_reject_panels.m can draw the single-session demo WITHOUT reloading a 1-3.5 GB session --
% and, more importantly, so the demo is guaranteed to be the same decomposition the population
% statistic was computed from. Falls back to the first qualifying session if the tag is absent.
EXEMPLAR = 'AL_0033_0226_e2';
PS = paperStyle();  col_ol = PS.col_ol;  col_cl = PS.col_cl;

assert(exist('mouse','var') && exist('fields','var'), '[XSESS] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [XSESS-LOOP] build + score each session through the shared kernel ------------
Q = struct([]);          % per-session qualifying results
skipped = struct('fld',{},'msg',{});
EX = struct();           % exemplar traces for the Fig-4 demo panel (see EXEMPLAR above)
pooled_ol = []; pooled_cl = []; pooled_ol_g = []; pooled_cl_g = [];   % pooled per-trial rho + session id
gate_txt = {'OFF','ON'};   % indexed by logical+1 (script local functions must sit at EOF)
fprintf('\n[IMP-XSESS] scanning %d candidate sessions  (R^2 gate %s, floor %.2f)...\n', ...
    numel(SESS), gate_txt{USE_GATE+1}, r2_floor);
fprintf('  %-22s %5s %5s %7s %7s %8s %9s %9s\n','session','nOL','nCL','medOL','medCL','p(1-3s)','Gdip_OL','Gdip_CL');
for s = SESS
    % Lazy per-session load: each cached `d` is 1-3.5 GB (it carries the full SVD), so holding
    % all 15 at once OOMs. Load the session only if the caller has not already, and drop it
    % again afterwards. Sessions with no controller cache are skipped like any other.
    fld_s = fields{s};  freeAfter = false;
    if ~isfield(mouse.(fld_s),'d') || isempty(mouse.(fld_s).d)
        pth_s = fullfile(fileparts(here),'data', sprintf('%sctrl%s%s%d.mat', ...
            mouse.(fld_s).mn, mouse.(fld_s).td(6:7), mouse.(fld_s).td(9:10), mouse.(fld_s).en));
        if ~exist(pth_s,'file')
            skipped(end+1) = struct('fld',fld_s,'msg','no controller cache'); %#ok<SAGROW>
            fprintf('  %-22s  SKIP (no controller cache)\n', fld_s);  continue;
        end
        tmp_s = load(pth_s);
        if ~isfield(tmp_s,'d')
            skipped(end+1) = struct('fld',fld_s,'msg','cache has no d'); %#ok<SAGROW>
            fprintf('  %-22s  SKIP (cache has no d)\n', fld_s);  clear tmp_s;  continue;
        end
        mouse.(fld_s).d = tmp_s.d;  mouse.(fld_s).data = tmp_s.data;  clear tmp_s;
        if ~isfield(mouse.(fld_s).d,'ref'); mouse.(fld_s).d.ref = -5; end
        freeAfter = true;
    end
    S = imp_build_session(mouse, fields, s, dataDir, CFG);
    if freeAfter; mouse.(fld_s) = rmfield(mouse.(fld_s), {'d','data'}); end
    if ~S.ok
        skipped(end+1) = struct('fld',S.sess_tag,'msg',S.msg); %#ok<SAGROW>
        fprintf('  %-22s  SKIP (%s)\n', S.sess_tag, S.msg);  continue;
    end
    if USE_GATE && ~(S.R2_te >= r2_floor)
        skipped(end+1) = struct('fld',S.sess_tag, ...
            'msg',sprintf('deployed R^2 %.3f < floor %.2f', S.R2_te, r2_floor)); %#ok<SAGROW>
        fprintf('  %-22s  SKIP (deployed R^2 %.3f < floor %.2f)\n', S.sess_tag, S.R2_te, r2_floor);
        continue;
    end
    R = imp_reject_core(S.Aol, S.Gol, S.Acl, S.Gcl, S.pre, S.Fs, CFG.resp_s, S.ref);
    k = numel(Q)+1;
    Q(k).sess_tag = S.sess_tag;  Q(k).selField = s;  Q(k).mn = S.mn;
    Q(k).nOL = R.n_ol;  Q(k).nCL = R.n_cl;
    Q(k).med_ol = R.med_ol;  Q(k).med_cl = R.med_cl;  Q(k).dmed = R.dmed;
    Q(k).p_rho = R.p_rho;  Q(k).rhoP_ol = R.rhoP_ol;  Q(k).rhoP_cl = R.rhoP_cl;
    Q(k).Gdip_ol = R.Gdip_ol;  Q(k).Gdip_cl = R.Gdip_cl;  Q(k).R2_te = S.R2_te;
    Q(k).rho_ol = R.rho_ol;  Q(k).rho_cl = R.rho_cl;
    % ENERGY RATIO (primary, Nick 2026-07-28): 1 = no work, <1 = controller gain.
    Q(k).er_ol = R.er_ol;  Q(k).er_cl = R.er_cl;
    Q(k).er_med_ol = R.er_med_ol;  Q(k).er_iqr_ol = R.er_iqr_ol;
    Q(k).er_med_cl = R.er_med_cl;  Q(k).er_iqr_cl = R.er_iqr_cl;
    Q(k).p_er = R.p_er;  Q(k).er_frac_ol = R.er_frac_ol;  Q(k).er_frac_cl = R.er_frac_cl;
    % --- exemplar traces for the demo panel (trial averages only; the full trial matrices
    % would bloat the struct and the panel draws mean +/- SEM) ---
    if strcmp(S.sess_tag, EXEMPLAR) || (~isfield(EX,'sess_tag') && k == 1)
        EX = struct('sess_tag',S.sess_tag,'mn',S.mn,'selField',s, ...
            'pre',S.pre,'Fs',S.Fs,'ref',S.ref,'resp_s',CFG.resp_s, ...
            't', ((1:size(S.Aol,2)) - S.pre - 1)/S.Fs, ...
            'Aol_m',mean(S.Aol,1), 'Gol_m',mean(S.Gol,1), ...
            'Acl_m',mean(S.Acl,1), 'Gcl_m',mean(S.Gcl,1), ...
            'Aol_e',std(S.Aol,0,1)/sqrt(size(S.Aol,1)), 'Gol_e',std(S.Gol,0,1)/sqrt(size(S.Gol,1)), ...
            'Acl_e',std(S.Acl,0,1)/sqrt(size(S.Acl,1)), 'Gcl_e',std(S.Gcl,0,1)/sqrt(size(S.Gcl,1)), ...
            'er_ol',R.er_ol, 'er_cl',R.er_cl, 'rho_ol',R.rho_ol, 'rho_cl',R.rho_cl, ...
            'p_er',R.p_er, 'p_rho',R.p_rho, 'n_ol',R.n_ol, 'n_cl',R.n_cl, 'R2_te',S.R2_te);
    end
    pooled_ol=[pooled_ol; R.rho_ol]; pooled_cl=[pooled_cl; R.rho_cl];
    pooled_ol_g=[pooled_ol_g; k*ones(R.n_ol,1)]; pooled_cl_g=[pooled_cl_g; k*ones(R.n_cl,1)];
    fprintf('  %-22s %5d %5d %+7.3f %+7.3f %8.2g %+9.3f %+9.3f\n', ...
        S.sess_tag, R.n_ol, R.n_cl, R.med_ol, R.med_cl, R.p_rho, R.Gdip_ol, R.Gdip_cl);
end
nS = numel(Q);
assert(nS>=1, ['[XSESS] no session qualified. Either the Stage-1/2 caches are missing ' ...
    '(build them: ctrl_roi_draw_all -> ctrl_residual_build), or every deployed predictor ' ...
    'is below the R^2 floor (%.2f). Set USE_GATE=false to see the ungated numbers -- ' ...
    'DIAGNOSTIC ONLY, they are not reportable.'], r2_floor);

%% [XSESS-STATS] combined inference ---------------------------------------------
med_ol = [Q.med_ol].';  med_cl = [Q.med_cl].';
gain = med_ol - med_cl;    % rejection GAIN: OL-CL transmission; >0 => CL lower ratio => CL rejects more (lower=better)
Gdip_ol = [Q.Gdip_ol].';  Gdip_cl = [Q.Gdip_cl].';
% (i) SESSION-LEVEL (each session = one unit; respects session structure) -------
if nS>=2
    p_sess = signrank(med_cl, med_ol);                       % paired, per-session medians
else
    p_sess = NaN;
end
% session-level bootstrap CI on mean per-session rejection gain (OL-CL)
bs = zeros(nBoot,1);
for i=1:nBoot, ix=randi(nS,nS,1); bs(i)=mean(gain(ix)); end
gain_ci = prctile(bs,[2.5 97.5]);
% (ii) POOLED (all trials, descriptive) ----------------------------------------
p_pool = ranksum(pooled_ol, pooled_cl);
fprintf('\n[IMP-XSESS] COMBINED disturbance transmission (1-3 s settled), %d sessions  (rho=||E||/||D||, lower=better)\n', nS);
fprintf('  per-session median rho : OL %+.3f +/- %.3f | CL %+.3f +/- %.3f\n', ...
    mean(med_ol),std(med_ol), mean(med_cl),std(med_cl));
fprintf('  per-session rejection gain (OL-CL): mean %+.3f  95%% CI [%+.3f, %+.3f]  (signrank p=%.3g, n=%d)\n', ...
    mean(gain), gain_ci(1), gain_ci(2), p_sess, nS);
fprintf('  CL rejects more (lower rho) in %d/%d sessions\n', nnz(gain>0), nS);
fprintf('  pooled per-trial rho   : OL %+.3f | CL %+.3f  (rank-sum p=%.3g, all trials)\n', ...
    median(pooled_ol), median(pooled_cl), p_pool);
fprintf('  network co-suppression (Global dip, 1-3 s): OL %+.3f +/- %.3f | CL %+.3f +/- %.3f  %%dF/F\n', ...
    mean(Gdip_ol),std(Gdip_ol), mean(Gdip_cl),std(Gdip_cl));

%% [XSESS-ER] ENERGY RATIO -- the reporting metric (Nick 2026-07-28) -------------
% ER = ||A-ref||^2 / ||G-ref||^2 over the 0-3 s stim window.
%   1  = controller did no work    (holds identically when A == G)
%   <1 = controller gain
% Inference is SESSION-LEVEL (n = sessions), per Nick: median +/- IQR reported
% separately for OL and CL, Wilcoxon signed-rank on the paired session medians.
er_med_ol = [Q.er_med_ol].';  er_med_cl = [Q.er_med_cl].';
er_gain   = er_med_ol - er_med_cl;              % >0 => CL suppresses more energy
if nS>=2
    p_er_sess = signrank(er_med_cl, er_med_ol);              % paired OL vs CL
    p_er_ol1  = signrank(er_med_ol, 1);                      % does OL do work at all?
    p_er_cl1  = signrank(er_med_cl, 1);                      % does CL do work at all?
else
    p_er_sess = NaN;  p_er_ol1 = NaN;  p_er_cl1 = NaN;
end
bsE = zeros(nBoot,1);
for i=1:nBoot, ix=randi(nS,nS,1); bsE(i)=mean(er_gain(ix)); end
er_gain_ci = prctile(bsE,[2.5 97.5]);

fprintf('\n[XSESS-ER] ENERGY RATIO  ER = ||A-ref||^2/||G-ref||^2  (0-3 s stim window), %d sessions\n', nS);
fprintf('           1 = no work done, <1 = controller gain.  Inference is session-level (n=%d).\n', nS);
fprintf('  per-session median ER  : OL %.3f [IQR %.3f] | CL %.3f [IQR %.3f]\n', ...
    median(er_med_ol), iqr(er_med_ol), median(er_med_cl), iqr(er_med_cl));
fprintf('  vs 1 (signrank)        : OL p=%.3g | CL p=%.3g\n', p_er_ol1, p_er_cl1);
fprintf('  OL vs CL paired        : signrank p=%.3g   mean gain %+.3f  95%% CI [%+.3f, %+.3f]\n', ...
    p_er_sess, mean(er_gain), er_gain_ci(1), er_gain_ci(2));
fprintf('  CL suppresses more energy in %d/%d sessions;  median trials with ER<1: OL %.0f%% CL %.0f%%\n', ...
    nnz(er_gain>0), nS, 100*median([Q.er_frac_ol]), 100*median([Q.er_frac_cl]));
fprintf('  per-session ER (OL -> CL):\n');
verdictER = {'OL better','CL better'};       % index 1/2 via logical+1 (no local fn:
for k=1:nS                                   % script local functions must sit at EOF)
    fprintf('    %-22s  %.3f -> %.3f   (%s)\n', Q(k).sess_tag, Q(k).er_med_ol, Q(k).er_med_cl, ...
        verdictER{(Q(k).er_med_cl < Q(k).er_med_ol) + 1});
end
fprintf('  NOTE: ER and rho are NOT interchangeable -- rho divides by ||G|| (zero-referenced),\n');
fprintf('        so its LEVEL was never interpretable, only the OL-vs-CL contrast. Quote one or the other.\n');

%% [XSESS-FIG] combined figure --------------------------------------------------
figX = figure('Color','w','Position',[40 60 1500 440]);
tl = tiledlayout(figX,1,3,'TileSpacing','compact','Padding','compact');

% (a) per-session paired medians OL->CL
ax1 = nexttile(tl,1); hold(ax1,'on');
for k=1:nS
    plot(ax1,[1 2],[med_ol(k) med_cl(k)],'-','Color',[.7 .7 .7],'LineWidth',0.8,'HandleVisibility','off');
end
scatter(ax1,ones(nS,1),med_ol,34,col_ol,'filled','MarkerFaceAlpha',.8);
scatter(ax1,2*ones(nS,1),med_cl,34,col_cl,'filled','MarkerFaceAlpha',.8);
plot(ax1,[1 2],[mean(med_ol) mean(med_cl)],'-k','LineWidth',2);
yline(ax1,0,':','Color',[.5 .5 .5]);
yline(ax1,1,'--','Color',[.7 .7 .7]);   % 1 = disturbance passes (no rejection)
set(ax1,'XTick',[1 2],'XTickLabel',{'OL','CL'}); xlim(ax1,[0.6 2.4]);
ylabel(ax1,'median transmission ||E||/||D||'); title(ax1,sprintf('(a) per-session (n=%d, signrank p=%.2g)',nS,p_sess),'FontWeight','normal');

% (b) pooled per-trial rho distributions
ax2 = nexttile(tl,2); hold(ax2,'on');
scatter(ax2,1+0.10*randn(numel(pooled_ol),1),pooled_ol,10,col_ol,'filled','MarkerFaceAlpha',.25);
scatter(ax2,2+0.10*randn(numel(pooled_cl),1),pooled_cl,10,col_cl,'filled','MarkerFaceAlpha',.25);
plot(ax2,[0.7 1.3],median(pooled_ol)*[1 1],'-k','LineWidth',2);
plot(ax2,[1.7 2.3],median(pooled_cl)*[1 1],'-k','LineWidth',2);
yline(ax2,1,'--','Color',[.7 .7 .7]); yline(ax2,0,':','Color',[.5 .5 .5]);
set(ax2,'XTick',[1 2],'XTickLabel',{'OL','CL'}); xlim(ax2,[0.5 2.5]);
ylabel(ax2,'transmission ||E||/||D|| (per trial)'); title(ax2,sprintf('(b) pooled trials (p=%.2g)',p_pool),'FontWeight','normal');

% (c) per-session rejection gain (OL-CL; >0 => CL rejects more)
ax3 = nexttile(tl,3); hold(ax3,'on');
[gs,ord] = sort(gain);
bar(ax3,1:nS,gs,0.6,'FaceColor',[0.35 0.55 0.75],'EdgeColor','none');
yline(ax3,0,'-','Color',[.4 .4 .4]);
yline(ax3,mean(gain),'--','Color',[0.1 0.3 0.7],'Label','mean','LineWidth',1.2);
set(ax3,'XTick',1:nS,'XTickLabel',{Q(ord).sess_tag},'XTickLabelRotation',60,'TickLabelInterpreter','none','FontSize',7);
ylabel(ax3,'rejection gain  OL-CL'); title(ax3,sprintf('(c) per-session gain  [CI %+.2f, %+.2f]',gain_ci),'FontWeight','normal');

sgtitle(figX, sprintf('[IMP-XSESS] combined disturbance transmission   %d sessions   (CL rejects more in %d, session p=%.2g, pooled p=%.2g)', ...
    nS, nnz(gain>0), p_sess, p_pool));
xpng = fullfile(fig_dir, 'imp_reject_across_sessions.png');
exportgraphics(figX, xpng, 'Resolution',300);
fprintf('[IMP-XSESS] figure -> %s\n', xpng);

%% [XSESS-SAVE] -----------------------------------------------------------------
% ER aggregates are saved (not just the per-session Q fields) so the paper-panel script
% f4_reject_panels.m can READ them instead of re-deriving the same formulas from Q --
% a second copy of the aggregation is a second thing that can drift.
XS = struct('CFG',CFG,'nS',nS,'Q',Q, ...
    'r2_floor',r2_floor,'USE_GATE',USE_GATE,'skipped',skipped,'EX',EX, ...
    'med_ol',med_ol,'med_cl',med_cl,'gain',gain,'gain_ci',gain_ci, ...
    'p_sess',p_sess,'p_pool',p_pool,'Gdip_ol',Gdip_ol,'Gdip_cl',Gdip_cl, ...
    'pooled_ol',pooled_ol,'pooled_cl',pooled_cl, ...
    'er_med_ol',er_med_ol,'er_med_cl',er_med_cl,'er_gain',er_gain, ...
    'er_gain_ci',er_gain_ci,'p_er_sess',p_er_sess,'p_er_ol1',p_er_ol1,'p_er_cl1',p_er_cl1);
save(fullfile(dataDir,'imp_reject_across_sessions.mat'),'XS');
fprintf('[IMP-XSESS] struct -> data/imp_reject_across_sessions.mat  (%d qualifying, %d skipped)\n', ...
    nS, numel(skipped));
if ~isempty(skipped)
    fprintf('  skipped:\n');
    for i = 1:numel(skipped)
        fprintf('    %-22s %s\n', skipped(i).fld, skipped(i).msg);
    end
end
