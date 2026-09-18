%% ctrl_state_xsess.m   [CTRL-XSTATE-A]  -- POPULATION version of Fig-4 Panel A
% Cross-session version of ctrl_state_dependence.m's Q2 (the "trial-average state
% dependence" panel): does the pre-stim ongoing level of the contra-derived Global
% predict WHERE the ipsilateral signal lands, and does closed loop FLATTEN that
% dependence?  Single-session (m4) gave OL slope 0.340 vs CL 0.084 (~4x shallower),
% but the bootstrap CI already touched 0 -- this asks whether it holds across sessions.
%
% MEASURES (per trial, all in absolute %dF/F, mirroring ctrl_state_dependence.m)
%   state    s_lvl = mean ABSOLUTE Global  over [-pre_s, 0] s   (ongoing level at onset)
%   outcome  o_act = mean ABSOLUTE Actual  over [1, resp_s] s   (where the signal landed)
% Per session we fit the OLS slope o_act ~ s_lvl for OL and CL separately.
%
% INFERENCE  session-level (each session = one unit, NOT trials -- trial-level p would
%   be pseudoreplication).  Paired Wilcoxon signrank on the per-session OL-vs-CL slope
%   difference, plus signrank of each arm's slopes vs 0, plus bootstrap CIs over sessions.
%
% NO REFITTING.  Trials/predictor are rebuilt through imp_build_session -- the SAME front
% end used by imp_reject_across_sessions.m and imp_state_across_sessions.m -- so these
% numbers cannot drift from the D/E panels.  Same R^2>=0.85 admission gate on the deployed
% predictor (a state slope built on an under-floor Global measures the model, not the brain).
% Sessions without both Stage-1/2 caches, or below the floor, auto-skip and are listed.
%
% PREREQ: Stage-1/2 caches per session (imp_xsess_build.m).  Run: load_sessions.m -> this.
% SECTIONS: [XSA-CFG] [XSA-LOOP] [XSA-STATS] [XSA-FIG] [XSA-SAVE]
% ---------------------------------------------------------------------------------

%% [XSA-CFG] --------------------------------------------------------------------
CFG.nSV_load = 500;  CFG.Fs = 35;  CFG.pre_s = 1.0;  CFG.resp_s = 3.0;
ss_s   = 1.0;                    % steady-state window start [ss_s, resp_s] s
nBoot  = 2000;  rng(7,'twister');
SESS   = 1:numel(fields);
r2_floor = ctrl_r2_floor();      % 0.85 on the DEPLOYED (Stage-2) predictor
USE_GATE = ctrl_gate_on();       % single project switch (utils/ctrl_gate_on.m); CTRL_GATE overrides
PS = paperStyle();  col_ol = PS.col_ol;  col_cl = PS.col_cl;

assert(exist('mouse','var') && exist('fields','var'), '[XSA] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [XSA-LOOP] -------------------------------------------------------------------
P = struct([]);  skipped = struct('fld',{},'msg',{});
gate_txt = {'OFF','ON'};
CX_ol = [];  CY_ol = [];  CX_cl = [];  CY_cl = [];   % within-session-centred pool for the scatter
fprintf('\n[CTRL-XSTATE-A] scanning %d candidate sessions  (R^2 gate %s, floor %.2f)...\n', ...
    numel(SESS), gate_txt{USE_GATE+1}, r2_floor);
for s = SESS
    fld_s = fields{s};  freeAfter = false;
    if ~isfield(mouse.(fld_s),'d') || isempty(mouse.(fld_s).d)
        pth_s = fullfile(fileparts(here),'data', sprintf('%sctrl%s%s%d.mat', ...
            mouse.(fld_s).mn, mouse.(fld_s).td(6:7), mouse.(fld_s).td(9:10), mouse.(fld_s).en));
        if ~exist(pth_s,'file'); continue; end
        tmp_s = load(pth_s);
        if ~isfield(tmp_s,'d'); clear tmp_s; continue; end
        mouse.(fld_s).d = tmp_s.d;  mouse.(fld_s).data = tmp_s.data;  clear tmp_s;
        if ~isfield(mouse.(fld_s).d,'ref'); mouse.(fld_s).d.ref = -5; end
        freeAfter = true;
    end
    S = imp_build_session(mouse, fields, s, dataDir, CFG);
    gateFail = S.ok && USE_GATE && ~(S.R2_te >= r2_floor);
    if freeAfter; mouse.(fld_s) = rmfield(mouse.(fld_s), {'d','data'}); end
    if ~S.ok
        skipped(end+1) = struct('fld',S.sess_tag,'msg',S.msg); %#ok<SAGROW>
        fprintf('  %-22s SKIP (%s)\n', S.sess_tag, S.msg);  continue;
    end
    if gateFail
        skipped(end+1) = struct('fld',S.sess_tag, ...
            'msg',sprintf('deployed R^2 %.3f < floor %.2f', S.R2_te, r2_floor)); %#ok<SAGROW>
        fprintf('  %-22s SKIP (deployed R^2 %.3f < floor %.2f)\n', S.sess_tag, S.R2_te, r2_floor);
        continue;
    end

    pre_mask = S.tt >= -CFG.pre_s & S.tt <= 0;         % [-1, 0] s
    ss_mask  = S.tt >=  ss_s      & S.tt <= CFG.resp_s; % [ 1, 3] s
    slvl_ol = mean(S.Gol(:,pre_mask),2);  oact_ol = mean(S.Aol(:,ss_mask),2);
    slvl_cl = mean(S.Gcl(:,pre_mask),2);  oact_cl = mean(S.Acl(:,ss_mask),2);
    [bo,ro,po] = fitslope(slvl_ol, oact_ol);
    [bc,rc,pc] = fitslope(slvl_cl, oact_cl);
    if ~isfinite(bo) || ~isfinite(bc)
        skipped(end+1) = struct('fld',S.sess_tag,'msg','too few finite trials for slope'); %#ok<SAGROW>
        fprintf('  %-22s SKIP (slope undefined)\n', S.sess_tag);  continue;
    end

    k = numel(P)+1;
    P(k).sess_tag = S.sess_tag;  P(k).mn = S.mn;  P(k).selField = s;
    P(k).n_ol = S.nOL;  P(k).n_cl = S.nCL;  P(k).R2_te = S.R2_te;
    P(k).slope_ol = bo;  P(k).slope_cl = bc;  P(k).r_ol = ro;  P(k).r_cl = rc;
    P(k).p_ol = po;      P(k).p_cl = pc;
    % within-session-centred pool (remove each session's DC so slopes overlay cleanly)
    CX_ol=[CX_ol; slvl_ol-mean(slvl_ol,'omitnan')];  CY_ol=[CY_ol; oact_ol-mean(oact_ol,'omitnan')]; %#ok<AGROW>
    CX_cl=[CX_cl; slvl_cl-mean(slvl_cl,'omitnan')];  CY_cl=[CY_cl; oact_cl-mean(oact_cl,'omitnan')]; %#ok<AGROW>
    fprintf('  %-22s nOL %3d nCL %3d | slope OL %+.3f (r %+.2f) CL %+.3f (r %+.2f) | R2te %.2f\n', ...
        S.sess_tag, S.nOL, S.nCL, bo, ro, bc, rc, S.R2_te);
end
nS = numel(P);
assert(nS >= 1, ['[XSA] no session qualified. Stage-1/2 caches missing, or every deployed ' ...
    'predictor below the R^2 floor (%.2f). Set CTRL_GATE=0 to see ungated numbers (DIAGNOSTIC ONLY).'], r2_floor);

%% [XSA-STATS] ------------------------------------------------------------------
bOL = [P.slope_ol].';  bCL = [P.slope_cl].';  dSL = bOL - bCL;
p_diff = NaN; p_ol0 = NaN; p_cl0 = NaN;
if nS >= 3
    p_diff = signrank(bOL, bCL);   % paired OL vs CL slope
    p_ol0  = signrank(bOL);        % OL slope vs 0
    p_cl0  = signrank(bCL);        % CL slope vs 0
end
bo_m = zeros(nBoot,1); bc_m = zeros(nBoot,1); bd_m = zeros(nBoot,1);
for b = 1:nBoot
    ix = randi(nS,nS,1);
    bo_m(b)=mean(bOL(ix)); bc_m(b)=mean(bCL(ix)); bd_m(b)=mean(dSL(ix));
end
ci_ol = prctile(bo_m,[2.5 97.5]); ci_cl = prctile(bc_m,[2.5 97.5]); ci_d = prctile(bd_m,[2.5 97.5]);
nShallow = nnz(bCL < bOL);          % sessions where CL is flatter than OL

fprintf('\n[CTRL-XSTATE-A] Panel-A state dependence (o_act ~ s_lvl), %d sessions\n', nS);
fprintf('  OL slope  mean %+.3f  CI [%+.3f %+.3f]  (vs 0: p=%.3g)\n', mean(bOL), ci_ol, p_ol0);
fprintf('  CL slope  mean %+.3f  CI [%+.3f %+.3f]  (vs 0: p=%.3g)\n', mean(bCL), ci_cl, p_cl0);
fprintf('  OL-CL     mean %+.3f  CI [%+.3f %+.3f]  (paired signrank p=%.3g)\n', mean(dSL), ci_d, p_diff);
fprintf('  CL flatter than OL in %d/%d sessions\n', nShallow, nS);

%% [XSA-FIG] --------------------------------------------------------------------
figS = figure('Color','w','Position',[60 80 1120 460]);
tl = tiledlayout(figS,1,2,'TileSpacing','compact','Padding','compact');

% (left) per-session paired slopes OL vs CL
ax1 = nexttile(tl,1); hold(ax1,'on');
for k = 1:nS
    plot(ax1,[1 2],[bOL(k) bCL(k)],'-','Color',[.75 .75 .75],'LineWidth',0.8,'HandleVisibility','off');
end
scatter(ax1,ones(nS,1),bOL,42,col_ol,'filled','MarkerFaceAlpha',.85,'DisplayName','OL');
scatter(ax1,2*ones(nS,1),bCL,42,col_cl,'filled','MarkerFaceAlpha',.85,'DisplayName','CL');
plot(ax1,[0.78 1.22],mean(bOL)*[1 1],'-k','LineWidth',2.5,'HandleVisibility','off');
plot(ax1,[1.78 2.22],mean(bCL)*[1 1],'-k','LineWidth',2.5,'HandleVisibility','off');
yline(ax1,0,':','Color',[.4 .4 .4],'HandleVisibility','off');
set(ax1,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out'); xlim(ax1,[0.6 2.4]);
ylabel(ax1,'slope  o_{act} \sim s_{lvl}   (\Delta land / \Delta state)');
title(ax1,sprintf('OL %+.2f vs CL %+.2f  (paired p=%.2g, %d/%d flatter)', ...
    mean(bOL),mean(bCL),p_diff,nShallow,nS),'FontWeight','normal');
legend(ax1,'Location','best','Box','off');

% (right) within-session-centred pooled scatter + regression lines
ax2 = nexttile(tl,2); hold(ax2,'on');
scatter(ax2,CX_ol,CY_ol,8,col_ol,'filled','MarkerFaceAlpha',.20,'HandleVisibility','off');
scatter(ax2,CX_cl,CY_cl,8,col_cl,'filled','MarkerFaceAlpha',.20,'HandleVisibility','off');
xr = linspace(prctile([CX_ol;CX_cl],1),prctile([CX_ol;CX_cl],99),50);
Po = fitline(CX_ol,CY_ol); Pc = fitline(CX_cl,CY_cl);
plot(ax2,xr,polyval(Po,xr),'-','Color',col_ol,'LineWidth',2.4,'DisplayName',sprintf('OL (pooled b=%+.2f)',Po(1)));
plot(ax2,xr,polyval(Pc,xr),'-','Color',col_cl,'LineWidth',2.4,'DisplayName',sprintf('CL (pooled b=%+.2f)',Pc(1)));
set(ax2,'Box','off','TickDir','out');
xlabel(ax2,'pre-stim Global level  s_{lvl}  (session-centred)');
ylabel(ax2,'steady-state |Actual|  o_{act}  (session-centred)');
title(ax2,'trial-level state dependence (all sessions pooled)','FontWeight','normal');
legend(ax2,'Location','best','Box','off');

sgtitle(figS,sprintf('[CTRL-XSTATE-A] Fig-4 Panel A across %d sessions (%s)', ...
    nS, strjoin(unique({P.mn}),', ')),'FontWeight','bold');
spng = fullfile(fig_dir,'ctrl_state_xsess.png');
exportgraphics(figS, spng, 'Resolution',300);
fprintf('[CTRL-XSTATE-A] figure -> %s\n', spng);

%% [XSA-SAVE] -------------------------------------------------------------------
XS_A = struct('CFG',CFG,'ss_s',ss_s,'nS',nS,'P',P, ...
    'slope_ol',bOL,'slope_cl',bCL,'diff',dSL, ...
    'mean_ol',mean(bOL),'mean_cl',mean(bCL),'mean_diff',mean(dSL), ...
    'ci_ol',ci_ol,'ci_cl',ci_cl,'ci_diff',ci_d, ...
    'p_diff',p_diff,'p_ol0',p_ol0,'p_cl0',p_cl0,'nShallow',nShallow, ...
    'r2_floor',r2_floor,'USE_GATE',USE_GATE,'skipped',skipped);
save(fullfile(dataDir,'ctrl_state_xsess.mat'),'XS_A');
fprintf('[CTRL-XSTATE-A] struct -> data/ctrl_state_xsess.mat (%d qualifying, %d skipped)\n', nS, numel(skipped));
if ~isempty(skipped)
    fprintf('  skipped: %s\n', strjoin(arrayfun(@(x) sprintf('%s (%s)',x.fld,x.msg), skipped,'uni',0), '; '));
end

%% ---- local functions (must sit at EOF for a script) --------------------------
function [b1,r,p] = fitslope(x,y)
    ok = isfinite(x) & isfinite(y); x = x(ok); y = y(ok);
    if numel(x) < 5; b1 = NaN; r = NaN; p = NaN; return; end
    P = polyfit(x,y,1); b1 = P(1);
    [r,p] = corr(x,y,'type','Pearson');
end
function P = fitline(x,y)
    ok = isfinite(x) & isfinite(y); x = x(ok); y = y(ok);
    if numel(x) < 5; P = [0 0]; return; end
    P = polyfit(x,y,1);
end
