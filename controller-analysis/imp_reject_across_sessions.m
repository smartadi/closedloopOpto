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
pooled_ol = []; pooled_cl = []; pooled_ol_g = []; pooled_cl_g = [];   % pooled per-trial rho + session id
fprintf('\n[IMP-XSESS] scanning %d candidate sessions...\n', numel(SESS));
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
            fprintf('  %-22s  SKIP (no controller cache)\n', fld_s);  continue;
        end
        tmp_s = load(pth_s);
        if ~isfield(tmp_s,'d')
            fprintf('  %-22s  SKIP (cache has no d)\n', fld_s);  clear tmp_s;  continue;
        end
        mouse.(fld_s).d = tmp_s.d;  mouse.(fld_s).data = tmp_s.data;  clear tmp_s;
        if ~isfield(mouse.(fld_s).d,'ref'); mouse.(fld_s).d.ref = -5; end
        freeAfter = true;
    end
    S = imp_build_session(mouse, fields, s, dataDir, CFG);
    if freeAfter; mouse.(fld_s) = rmfield(mouse.(fld_s), {'d','data'}); end
    if ~S.ok
        fprintf('  %-22s  SKIP (%s)\n', S.sess_tag, S.msg);  continue;
    end
    R = imp_reject_core(S.Aol, S.Gol, S.Acl, S.Gcl, S.pre, S.Fs, CFG.resp_s, S.ref);
    k = numel(Q)+1;
    Q(k).sess_tag = S.sess_tag;  Q(k).selField = s;  Q(k).mn = S.mn;
    Q(k).nOL = R.n_ol;  Q(k).nCL = R.n_cl;
    Q(k).med_ol = R.med_ol;  Q(k).med_cl = R.med_cl;  Q(k).dmed = R.dmed;
    Q(k).p_rho = R.p_rho;  Q(k).rhoP_ol = R.rhoP_ol;  Q(k).rhoP_cl = R.rhoP_cl;
    Q(k).Gdip_ol = R.Gdip_ol;  Q(k).Gdip_cl = R.Gdip_cl;  Q(k).R2_te = S.R2_te;
    Q(k).rho_ol = R.rho_ol;  Q(k).rho_cl = R.rho_cl;
    pooled_ol=[pooled_ol; R.rho_ol]; pooled_cl=[pooled_cl; R.rho_cl];
    pooled_ol_g=[pooled_ol_g; k*ones(R.n_ol,1)]; pooled_cl_g=[pooled_cl_g; k*ones(R.n_cl,1)];
    fprintf('  %-22s %5d %5d %+7.3f %+7.3f %8.2g %+9.3f %+9.3f\n', ...
        S.sess_tag, R.n_ol, R.n_cl, R.med_ol, R.med_cl, R.p_rho, R.Gdip_ol, R.Gdip_cl);
end
nS = numel(Q);
assert(nS>=1, '[XSESS] no session had usable Stage-1/2 caches -- build the predictors first.');

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
XS = struct('CFG',CFG,'nS',nS,'Q',Q, ...
    'med_ol',med_ol,'med_cl',med_cl,'gain',gain,'gain_ci',gain_ci, ...
    'p_sess',p_sess,'p_pool',p_pool,'Gdip_ol',Gdip_ol,'Gdip_cl',Gdip_cl, ...
    'pooled_ol',pooled_ol,'pooled_cl',pooled_cl);
save(fullfile(dataDir,'imp_reject_across_sessions.mat'),'XS');
fprintf('[IMP-XSESS] struct -> data/imp_reject_across_sessions.mat  (%d qualifying sessions)\n', nS);
