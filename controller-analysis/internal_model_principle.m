% internal_model_principle.m
% ---------------------------------------------------------------------------
% Residual analysis of the controller through the Internal Model Principle lens.
%
% FRAME (IMP): a feedback controller can only reject the part of a disturbance
% for which it holds an internal model. Whatever survives in the LOCAL residual
% L = Actual - Global is, by definition, the part the model did NOT capture.
% Comparing that residual between open and closed loop tells us what the
% controller adds; ranking trials by it (later) tells us which brain states the
% controller's internal model fails on (the "less controllable/observable" ones).
%
% Decomposition (per trial, absolute dF/F, rebuilt from the Stage 1/2 predictor):
%   A = Actual measured ipsi
%   G = Global = stim-blind contra prediction = disturbance / no-controller counterfactual
%   L = A - G = Local residual = the laser + controller's own effect
%
% THIS SCRIPT answers QUESTIONS 1, 2, 3 (the controllability/observability
% ranking is the follow-up):
%   Q1  additive-model test:  does A_response ~= G_response + average local?
%       -> holds for OL (fixed command), breaks for CL (controller adapts each trial).
%   Q2  disturbance compensation: interpreting G as the disturbance, regress the
%       trial-specific local action (L - L_bar) on the trial-specific disturbance
%       (G - G_bar). slope beta: 0 = no rejection, -1 = perfect cancellation.
%       rejection fraction = -beta; transmission (dA on dG) = 1 + beta.
%   Q3  residual OL vs CL: trial-AVERAGE L_bar(t) and trial-to-trial variability.
%
% Working in the RESPONSE domain (each trace baseline-subtracted over [-1,0]s):
%   Ar = A - A(pre),  Gr = G - G(pre),  L = Ar - Gr  (local response).
% Perfect disturbance rejection => Ar flat => L = -Gr (local exactly cancels the
% global excursion) => beta = -1. No rejection (OL) => L ignores dG => beta ~ 0.
%
% SCOPE: single session (m4 = AL_0033_0226_e2) -- the only session with the
%   Stage 1 (ctrl_ols_spont) + Stage 2 (ctrl_ols_ol_stimblind) predictor caches.
%   Descriptive, n=1 animal. Not a population claim.
%
% PREREQS: load_sessions.m has run (mouse, fields); Stage 1 + Stage 2 caches.
% SECTIONS: [CFG] [LOAD] [TRIALS] [RESIDUAL] [Q3-STATS] [Q3-FIG] [SAVE]
% ---------------------------------------------------------------------------

%% [IMP-CFG] --------------------------------------------------------------------
selField  = 4;
nSV_load  = 500;
Fs        = 35;
pre_s     = 1.0;          % pre-stim baseline window [-1,0] s
resp_s    = 3.0;          % response window [0, resp_s] s for scalar summaries
nBoot     = 2000;
rng(7,'twister');

PS = paperStyle();
col_ol = PS.col_ol;  col_cl = PS.col_cl;    % OL red / CL blue (paper palette)

assert(exist('mouse','var') && exist('fields','var'), '[IMP] run load_sessions.m first.');
here = fileparts(mfilename('fullpath'));
if isempty(here) || contains(here,tempdir,'IgnoreCase',true) || contains(here,'Editor_','IgnoreCase',true)
    here = fullfile(pwd,'controller-analysis'); if ~exist(here,'dir'); here = pwd; end
end
dataDir = fullfile(here,'data');
fig_dir = fullfile(here,'..','paper','images','predictor_saga'); if ~exist(fig_dir,'dir'); mkdir(fig_dir); end

%% [IMP-LOAD] -------------------------------------------------------------------
fld = fields{selField};
d_s = mouse.(fld).d;  data = mouse.(fld).data;
mn = mouse.(fld).mn; td = mouse.(fld).td; en = mouse.(fld).en;
sess_tag = sprintf('%s_%s%s_e%d', mn, td(6:7), td(9:10), en);
S1 = load(fullfile(dataDir, sprintf('ctrl_ols_spont_%s.mat', sess_tag)));
S2 = load(fullfile(dataDir, sprintf('ctrl_ols_ol_stimblind_%s.mat', sess_tag)));
gridIdx=S1.gridIdx; px_prim=S1.px_prim; py_prim=S1.py_prim; k_prim=S1.k_prim;
horizon=S1.horizon; dur=S1.trial_dur;
b=S2.b; mu=S2.mu; sd=S2.sd; muY=S2.muY; Su=S2.Su;

[U_cp,V_cp,t_svd,mimg_cp] = loadUVt(expPath(mn,td,en), nSV_load);
V_cp=double(V_cp); [nY,nX]=size(mimg_cp); nSV=size(U_cp,3);
Uflat=reshape(U_cp,nY*nX,nSV); t_full=t_svd(:); nF=min(size(V_cp,2),numel(t_full));
[y_full,ok] = local_svd_rolling_dfk(Uflat,V_cp,mimg_cp,px_prim,py_prim,k_prim,horizon,nY,nX);
assert(ok,'[IMP] target rebuild failed.');
Xg = double(Uflat(gridIdx,:))*V_cp;
Gall = muY + (((Xg(Su,:)-mu)./sd).')*b;                    % stim-blind Global, all frames

%% [IMP-TRIALS] absolute per-trial A and G, both conditions ---------------------
pre=round(pre_s*Fs); post=round(dur*Fs); rel=-pre:post;
bwin=1:pre; twin=pre+1:pre+post;
resp = pre+1 : pre+round(resp_s*Fs);                       % [0, resp_s] s window
grab = @(ons) deal_trials(ons, t_full, y_full, Gall, rel, pre, post, nF);
[Aol,Gol,nOL] = grab(sort(d_s.stimStarts(data.nc(:))));
[Acl,Gcl,nCL] = grab(sort(d_s.stimStarts(data.wc(:))));
tt = rel/Fs;
fprintf('[IMP] %s | OL %d trials | CL %d trials\n', sess_tag, nOL, nCL);

%% [IMP-RESIDUAL] response-domain traces: Ar, Gr, and L = Ar - Gr ---------------
Ar_ol = Aol - mean(Aol(:,bwin),2);  Gr_ol = Gol - mean(Gol(:,bwin),2);
Ar_cl = Acl - mean(Acl(:,bwin),2);  Gr_cl = Gcl - mean(Gcl(:,bwin),2);
Lol = Ar_ol - Gr_ol;                 % local response OL   (== (A-G) baseline-sub)
Lcl = Ar_cl - Gr_cl;                 % local response CL

%% [IMP-Q1] additive model: Ar ~= Gr + average local response -------------------
Lbar_ol = mean(Lol,1);  Lbar_cl = mean(Lcl,1);              % grand-avg local response
Ahat_ol = Gr_ol + Lbar_ol;  Ahat_cl = Gr_cl + Lbar_cl;      % reconstruction (broadcast)

recRMSE_ol = sqrt(mean((Ar_ol(:,resp)-Ahat_ol(:,resp)).^2,2));   % per-trial recon error
recRMSE_cl = sqrt(mean((Ar_cl(:,resp)-Ahat_cl(:,resp)).^2,2));
r2p = @(A,Ah) 1 - sum((A(:,resp)-Ah(:,resp)).^2,'all') / ...
                  sum((A(:,resp)-mean(A(:,resp),'all')).^2,'all');
R2add_ol = r2p(Ar_ol,Ahat_ol);  R2add_cl = r2p(Ar_cl,Ahat_cl);   % G + avg-local model
R2g_ol   = r2p(Ar_ol,Gr_ol+mean(Lbar_ol(resp)));                 % G-only (disturbance) ref
R2g_cl   = r2p(Ar_cl,Gr_cl+mean(Lbar_cl(resp)));
dRMSE_bs = zeros(nBoot,1);
for k2=1:nBoot
    io=randi(nOL,nOL,1); ic=randi(nCL,nCL,1);
    dRMSE_bs(k2)=mean(recRMSE_cl(ic))-mean(recRMSE_ol(io));
end
dRMSE_ci = prctile(dRMSE_bs,[2.5 97.5]);

fprintf('\n[IMP-Q1] additive model  Ar ~= Gr + avg-local, response window [0,%.0f]s\n', resp_s);
fprintf('  reconstruction R2 (G + avg local): OL %.3f   CL %.3f\n', R2add_ol, R2add_cl);
fprintf('  reconstruction R2 (G only ref)   : OL %.3f   CL %.3f\n', R2g_ol, R2g_cl);
fprintf('  per-trial recon RMSE (fixed-response residual): OL %.3f   CL %.3f   (dCL-OL %+.3f, 95%% CI [%+.3f,%+.3f])\n', ...
    mean(recRMSE_ol), mean(recRMSE_cl), mean(recRMSE_cl)-mean(recRMSE_ol), dRMSE_ci(1), dRMSE_ci(2));

%% [IMP-OL-PROOF] rigorous OL null-model test: Ar ~= Gr + avg OL response --------
% Nested, cross-validated (leave-one-trial-out) on OL trials, response window.
%   M1 = disturbance only (Gr) ; M2 = avg response only ; M3 = Gr + avg response.
SST_ol = sum((Ar_ol(:,resp)-mean(Ar_ol(:,resp),'all')).^2,'all');
res1 = Ar_ol(:,resp)-Gr_ol(:,resp);                       % M1: no free params
res2 = zeros(nOL,numel(resp)); res3 = zeros(nOL,numel(resp));
for j=1:nOL
    tr=true(nOL,1); tr(j)=false;
    rbarA = mean(Ar_ol(tr,:),1);                          % LOO avg actual response (M2)
    rbarL = mean(Ar_ol(tr,:)-Gr_ol(tr,:),1);              % LOO avg local response  (M3)
    res2(j,:) = Ar_ol(j,resp) - rbarA(resp);
    res3(j,:) = Ar_ol(j,resp) - Gr_ol(j,resp) - rbarL(resp);
end
R2_M1 = 1 - sum(res1(:).^2)/SST_ol;
R2_M2 = 1 - sum(res2(:).^2)/SST_ol;
R2_M3 = 1 - sum(res3(:).^2)/SST_ol;
% noise-floor: M3 residual var (post) vs baseline prediction residual var (pre, no laser)
Lpre = Ar_ol(:,bwin)-Gr_ol(:,bwin);                       % pre-stim local = baseline pred residual
var_pre = var(Lpre(:)); var_post = var(res3(:)); nf_ratio = var_post/var_pre;

fprintf('\n[IMP-OL-PROOF] OL: Ar ~= Gr + avg OL response  (LOO-CV, window [0,%.0f]s)\n', resp_s);
fprintf('  CV-R2  M1 disturbance only   %.3f\n', R2_M1);
fprintf('  CV-R2  M2 avg-response only   %.3f\n', R2_M2);
fprintf('  CV-R2  M3 G + avg response    %.3f   (gain over M1 +%.2f, over M2 +%.2f)\n', ...
    R2_M3, R2_M3-R2_M1, R2_M3-R2_M2);
fprintf('  residual variance  baseline(pre) %.3f  post(M3) %.3f   ratio %.2f (1=noise floor)\n', ...
    var_pre, var_post, nf_ratio);

% ---- OL-proof figure ----
[~,iEX]=min(abs(recRMSE_ol-median(recRMSE_ol)));          % representative OL trial
rbarL_all = mean(Lol,1);
figp=figure('Color','w','Position',[40 80 1500 430]);
tlp=tiledlayout(figp,1,3,'TileSpacing','compact','Padding','compact');
% (a) nested CV-R2
axa=nexttile(tlp,1);
bar(axa,[R2_M1 R2_M2 R2_M3],0.6,'FaceColor',col_ol,'EdgeColor','none');
set(axa,'XTickLabel',{'G only','avg resp','G+avg'},'Box','off','TickDir','out'); ylim(axa,[0 1]);
ylabel(axa,'cross-validated R^2'); title(axa,'(a) nested models (OL)','FontWeight','normal');
text(axa,1,R2_M1+0.03,sprintf('%.2f',R2_M1),'HorizontalAlignment','center');
text(axa,2,R2_M2+0.03,sprintf('%.2f',R2_M2),'HorizontalAlignment','center');
text(axa,3,R2_M3+0.03,sprintf('%.2f',R2_M3),'HorizontalAlignment','center');
% (b) residual SD(t) vs baseline noise floor
axb=nexttile(tlp,2); hold(axb,'on');
plot(axb,tt,sdLol,'-','Color',col_ol,'LineWidth',1.6,'DisplayName','M3 residual SD');
yline(axb,sqrt(var_pre),'--','Color',[.4 .4 .4],'LineWidth',1.2,'DisplayName','baseline noise floor');
xline(axb,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(axb,'time from stim (s)'); ylabel(axb,'residual SD (%\DeltaF/F)'); xlim(axb,[tt(1) tt(end)]);
title(axb,sprintf('(b) residual vs noise floor  (post/pre var %.2f)',nf_ratio),'FontWeight','normal');
legend(axb,'Location','northwest','Box','off');
% (c) example OL trial: actual, disturbance, full model
axc=nexttile(tlp,3); hold(axc,'on');
xline(axc,0,':','Color',[.5 .5 .5],'HandleVisibility','off'); yline(axc,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
plot(axc,tt,Ar_ol(iEX,:),'-','Color','k','LineWidth',1.5,'DisplayName','A_r (actual)');
plot(axc,tt,Gr_ol(iEX,:),'-','Color',[.55 .55 .55],'LineWidth',1.2,'DisplayName','G_r (disturbance)');
plot(axc,tt,Gr_ol(iEX,:)+rbarL_all,'--','Color',col_ol,'LineWidth',1.4,'DisplayName','G_r + avg resp');
xlabel(axc,'time from stim (s)'); ylabel(axc,'response (%\DeltaF/F)'); xlim(axc,[tt(1) tt(end)]);
title(axc,sprintf('(c) OL example (trial %d)',iEX),'FontWeight','normal'); legend(axc,'Location','southwest','Box','off');
sgtitle(figp,sprintf('[IMP] OL null-model proof: Ar \\approx Gr + avg OL response   %s   (OL n=%d)', ...
    strrep(sess_tag,'_','\_'),nOL));
olpng=fullfile(fig_dir,sprintf('internal_model_principle_olproof_%s.png',sess_tag));
exportgraphics(figp,olpng,'Resolution',300); fprintf('[IMP-OL-PROOF-FIG] -> %s\n',olpng);

%% [IMP-Q2] disturbance compensation: dL ~ dG -----------------------------------
dG_ol = Gr_ol-mean(Gr_ol,1); dL_ol = Lol-Lbar_ol; dA_ol = Ar_ol-mean(Ar_ol,1);
dG_cl = Gr_cl-mean(Gr_cl,1); dL_cl = Lcl-Lbar_cl; dA_cl = Ar_cl-mean(Ar_cl,1);
pslope = @(x,y) local_pslope(x(:,resp),y(:,resp));
beta_ol=pslope(dG_ol,dL_ol);  beta_cl=pslope(dG_cl,dL_cl);         % compensation slope
trans_ol=pslope(dG_ol,dA_ol); trans_cl=pslope(dG_cl,dA_cl);        % disturbance transmission
% per-trial compensation (projection of local action onto -disturbance)
comp_ol = -sum(dL_ol(:,resp).*dG_ol(:,resp),2)./max(sum(dG_ol(:,resp).^2,2),eps);
comp_cl = -sum(dL_cl(:,resp).*dG_cl(:,resp),2)./max(sum(dG_cl(:,resp).^2,2),eps);
dbeta_bs=zeros(nBoot,1);
for k2=1:nBoot
    io=randi(nOL,nOL,1); ic=randi(nCL,nCL,1);
    dbeta_bs(k2)=pslope(dG_cl(ic,:),dL_cl(ic,:))-pslope(dG_ol(io,:),dL_ol(io,:));
end
dbeta_ci=prctile(dbeta_bs,[2.5 97.5]);

fprintf('\n[IMP-Q2] disturbance compensation (dL ~ dG), response window [0,%.0f]s\n', resp_s);
fprintf('  compensation slope beta: OL %+.3f   CL %+.3f   (rejection = -beta: OL %.0f%%  CL %.0f%%)\n', ...
    beta_ol, beta_cl, -beta_ol*100, -beta_cl*100);
fprintf('  transmission (dA~dG)   : OL %+.3f   CL %+.3f   (CL passes %.0f%% of the disturbance)\n', ...
    trans_ol, trans_cl, trans_cl*100);
fprintf('  beta CL-OL difference  : %+.3f   95%% CI [%+.3f,%+.3f]%s\n', ...
    beta_cl-beta_ol, dbeta_ci(1), dbeta_ci(2), ternS(dbeta_ci(2)<0||dbeta_ci(1)>0,'  *',''));
fprintf('  per-trial compensation median: OL %+.2f   CL %+.2f\n', median(comp_ol), median(comp_cl));

%% [IMP-Q1-FIG] -----------------------------------------------------------------
[~,iOL]=min(abs(recRMSE_ol-median(recRMSE_ol)));   % representative (median-error) trials
[~,iCL]=min(abs(recRMSE_cl-median(recRMSE_cl)));
figq1=figure('Color','w','Position',[40 80 1500 430]);
tlq1=tiledlayout(figq1,1,3,'TileSpacing','compact','Padding','compact');
ex_(nexttile(tlq1,1), tt, Ar_ol(iOL,:), Ahat_ol(iOL,:), col_ol, sprintf('(a) OL example (trial %d)',iOL));
ex_(nexttile(tlq1,2), tt, Ar_cl(iCL,:), Ahat_cl(iCL,:), col_cl, sprintf('(b) CL example (trial %d)',iCL));
axq=nexttile(tlq1,3); hold(axq,'on');
beeswarm_(axq,1,recRMSE_ol,col_ol); beeswarm_(axq,2,recRMSE_cl,col_cl);
errorbar(axq,1-0.28,mean(recRMSE_ol),std(recRMSE_ol),'ko','MarkerFaceColor',col_ol,'MarkerSize',6,'LineWidth',1,'CapSize',4);
errorbar(axq,2+0.28,mean(recRMSE_cl),std(recRMSE_cl),'ko','MarkerFaceColor',col_cl,'MarkerSize',6,'LineWidth',1,'CapSize',4);
set(axq,'XTick',[1 2],'XTickLabel',{'OL','CL'}); xlim(axq,[0.5 2.5]);
ylabel(axq,'recon RMSE: A_r vs (G_r + avg local)  (%\DeltaF/F)');
title(axq,sprintf('(c) fixed-response residual   R^2 OL %.2f / CL %.2f',R2add_ol,R2add_cl),'FontWeight','normal');
sgtitle(figq1,sprintf('[IMP] Q1 additive model  Ar \\approx Gr + avg-local   %s   (OL n=%d, CL n=%d)', ...
    strrep(sess_tag,'_','\_'),nOL,nCL));
q1png=fullfile(fig_dir,sprintf('internal_model_principle_q1_%s.png',sess_tag));
exportgraphics(figq1,q1png,'Resolution',300); fprintf('[IMP-Q1-FIG] -> %s\n',q1png);

%% [IMP-Q2-FIG] -----------------------------------------------------------------
rng(11,'twister'); nsub=3000;
figq2=figure('Color','w','Position',[40 80 1500 430]);
tlq2=tiledlayout(figq2,1,3,'TileSpacing','compact','Padding','compact');
axa=nexttile(tlq2,1); hold(axa,'on');
sc_(axa,dG_ol(:,resp),dL_ol(:,resp),col_ol,nsub,beta_ol,'OL');
sc_(axa,dG_cl(:,resp),dL_cl(:,resp),col_cl,nsub,beta_cl,'CL');
xlabel(axa,'disturbance  dG = G_r - \langleG_r\rangle'); ylabel(axa,'local action  dL = L - \langleL\rangle');
title(axa,sprintf('(a) compensation   \\beta OL %+.2f / CL %+.2f',beta_ol,beta_cl),'FontWeight','normal');
legend(axa,'Location','northeast','Box','off');
axb=nexttile(tlq2,2); hold(axb,'on');
sc_(axb,dG_ol(:,resp),dA_ol(:,resp),col_ol,nsub,trans_ol,'OL');
sc_(axb,dG_cl(:,resp),dA_cl(:,resp),col_cl,nsub,trans_cl,'CL');
xlabel(axb,'disturbance  dG'); ylabel(axb,'output deviation  dA_r');
title(axb,sprintf('(b) transmission   OL %+.2f / CL %+.2f  (CL rejects %.0f%%)',trans_ol,trans_cl,(1-trans_cl)*100),'FontWeight','normal');
axc=nexttile(tlq2,3); hold(axc,'on');
beeswarm_(axc,1,comp_ol,col_ol); beeswarm_(axc,2,comp_cl,col_cl);
yline(axc,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
errorbar(axc,1-0.28,median(comp_ol),iqr(comp_ol)/2,'ko','MarkerFaceColor',col_ol,'MarkerSize',6,'LineWidth',1,'CapSize',4);
errorbar(axc,2+0.28,median(comp_cl),iqr(comp_cl)/2,'ko','MarkerFaceColor',col_cl,'MarkerSize',6,'LineWidth',1,'CapSize',4);
set(axc,'XTick',[1 2],'XTickLabel',{'OL','CL'}); xlim(axc,[0.5 2.5]);
ylabel(axc,'per-trial compensation  -\langledL,dG\rangle/\langledG,dG\rangle');
title(axc,'(c) per-trial disturbance rejection','FontWeight','normal');
sgtitle(figq2,sprintf('[IMP] Q2 disturbance compensation   %s   (OL n=%d, CL n=%d, single session)', ...
    strrep(sess_tag,'_','\_'),nOL,nCL));
q2png=fullfile(fig_dir,sprintf('internal_model_principle_q2_%s.png',sess_tag));
exportgraphics(figq2,q2png,'Resolution',300); fprintf('[IMP-Q2-FIG] -> %s\n',q2png);

%% [IMP-Q3-STATS] ---------------------------------------------------------------
mLol=mean(Lol,1); seLol=std(Lol,0,1)/sqrt(nOL); sdLol=std(Lol,0,1);
mLcl=mean(Lcl,1); seLcl=std(Lcl,0,1)/sqrt(nCL); sdLcl=std(Lcl,0,1);

% scalar per-trial mean residual over the response window
sOL = mean(Lol(:,resp),2);  sCL = mean(Lcl(:,resp),2);
% trial-averaged response magnitude (mean residual over the window)
respMag_OL = mean(sOL);  respMag_CL = mean(sCL);
% trial-to-trial spread of that scalar
varOL = var(sOL); varCL = var(sCL); vratio = varCL/varOL;
% time-integrated trial-to-trial SD over the response window
sdint_OL = mean(sdLol(resp)); sdint_CL = mean(sdLcl(resp));

% bootstrap CIs: variance ratio (spread) and mean-response difference
vr_bs = zeros(nBoot,1); dm_bs = zeros(nBoot,1);
for k2 = 1:nBoot
    io = randi(nOL,nOL,1); ic = randi(nCL,nCL,1);
    vr_bs(k2) = var(sCL(ic))/var(sOL(io));
    dm_bs(k2) = mean(sCL(ic)) - mean(sOL(io));
end
vr_ci = prctile(vr_bs,[2.5 97.5]);  dm_ci = prctile(dm_bs,[2.5 97.5]);

fprintf('\n[IMP-Q3] residual (Local) OL vs CL, response window [0,%.0f]s\n', resp_s);
fprintf('  trial-avg response magnitude:  OL %+.3f   CL %+.3f   (dMean %+.3f, 95%% CI [%+.3f,%+.3f])\n', ...
    respMag_OL, respMag_CL, respMag_CL-respMag_OL, dm_ci(1), dm_ci(2));
fprintf('  trial-to-trial spread (var of per-trial mean-L): OL %.3f  CL %.3f  ratio %.2f  95%% CI [%.2f,%.2f]\n', ...
    varOL, varCL, vratio, vr_ci(1), vr_ci(2));
fprintf('  time-integrated trial SD over window:            OL %.3f  CL %.3f  (ratio %.2f)\n', ...
    sdint_OL, sdint_CL, sdint_CL/sdint_OL);
sig = ''; if vr_ci(1)>1 || vr_ci(2)<1; sig=' *'; end
fprintf('  (variance-ratio CI excludes 1: %s)  n_OL=%d n_CL=%d, single session\n', ...
    ternS(~isempty(sig),'YES','no'), nOL, nCL);

%% [IMP-Q3-FIG] -----------------------------------------------------------------
figI = figure('Color','w','Position',[40 80 1500 430]);
tl = tiledlayout(figI,1,3,'TileSpacing','compact','Padding','compact');

% (1) trial-average residual +- SEM
ax1=nexttile(tl,1); hold(ax1,'on');
shade_(ax1, tt, mLol, seLol, col_ol);
shade_(ax1, tt, mLcl, seLcl, col_cl);
hO=plot(ax1,tt,mLol,'-','Color',col_ol,'LineWidth',1.6,'DisplayName','OL residual');
hC=plot(ax1,tt,mLcl,'-','Color',col_cl,'LineWidth',1.6,'DisplayName','CL residual');
xline(ax1,0,':','Color',[.5 .5 .5]); yline(ax1,0,':','Color',[.5 .5 .5]);
xlabel(ax1,'time from stim (s)'); ylabel(ax1,'residual L = A - G  (%\DeltaF/F)');
title(ax1,'(a) trial-average residual','FontWeight','normal');
legend(ax1,[hO hC],'Location','southwest','Box','off'); xlim(ax1,[tt(1) tt(end)]);

% (2) trial-to-trial SD over time
ax2=nexttile(tl,2); hold(ax2,'on');
xline(ax2,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
plot(ax2,tt,sdLol,'-','Color',col_ol,'LineWidth',1.6,'DisplayName','OL');
plot(ax2,tt,sdLcl,'-','Color',col_cl,'LineWidth',1.6,'DisplayName','CL');
xlabel(ax2,'time from stim (s)'); ylabel(ax2,'trial-to-trial SD of residual  (%\DeltaF/F)');
title(ax2,'(b) residual variability','FontWeight','normal');
legend(ax2,'Location','northwest','Box','off'); xlim(ax2,[tt(1) tt(end)]);

% (3) per-trial mean residual: OL vs CL spread
ax3=nexttile(tl,3); hold(ax3,'on');
beeswarm_(ax3, 1, sOL, col_ol); beeswarm_(ax3, 2, sCL, col_cl);
errorbar(ax3,1-0.28,mean(sOL),std(sOL),'ko','MarkerFaceColor',col_ol,'MarkerSize',6,'LineWidth',1.0,'CapSize',4);
errorbar(ax3,2+0.28,mean(sCL),std(sCL),'ko','MarkerFaceColor',col_cl,'MarkerSize',6,'LineWidth',1.0,'CapSize',4);
set(ax3,'XTick',[1 2],'XTickLabel',{'OL','CL'}); xlim(ax3,[0.5 2.5]);
ylabel(ax3,'per-trial mean residual over [0,3]s  (%\DeltaF/F)');
title(ax3,sprintf('(c) residual spread  var ratio %.2f [%.2f,%.2f]',vratio,vr_ci(1),vr_ci(2)),'FontWeight','normal');

sgtitle(figI, sprintf('[IMP] Q3 residual OL vs CL   %s   (OL n=%d, CL n=%d, single session)', ...
    strrep(sess_tag,'_','\_'), nOL, nCL));
fig_png = fullfile(fig_dir, sprintf('internal_model_principle_q3_%s.png', sess_tag));
exportgraphics(figI, fig_png, 'Resolution', 300);
fprintf('[IMP-Q3-FIG] -> %s\n', fig_png);

%% [IMP-SAVE] -------------------------------------------------------------------
IMP = struct('sess_tag',sess_tag,'nOL',nOL,'nCL',nCL,'tt',tt, ...
    'mLol',mLol,'mLcl',mLcl,'sdLol',sdLol,'sdLcl',sdLcl,'sOL',sOL,'sCL',sCL, ...
    'respMag_OL',respMag_OL,'respMag_CL',respMag_CL,'varOL',varOL,'varCL',varCL, ...
    'vratio',vratio,'vr_ci',vr_ci,'dm_ci',dm_ci,'resp_s',resp_s,'Fs',Fs, ...
    'R2add_ol',R2add_ol,'R2add_cl',R2add_cl,'R2g_ol',R2g_ol,'R2g_cl',R2g_cl, ...
    'recRMSE_ol',recRMSE_ol,'recRMSE_cl',recRMSE_cl,'dRMSE_ci',dRMSE_ci, ...
    'beta_ol',beta_ol,'beta_cl',beta_cl,'trans_ol',trans_ol,'trans_cl',trans_cl, ...
    'dbeta_ci',dbeta_ci,'comp_ol',comp_ol,'comp_cl',comp_cl);
imp_file = fullfile(dataDir, sprintf('internal_model_principle_%s.mat', sess_tag));
save(imp_file,'-struct','IMP','-v7.3');
fprintf('[IMP-SAVE] -> %s\n\n', imp_file);

%% ---- helpers -----------------------------------------------------------------
function [A,G,n] = deal_trials(starts, t_full, y_full, Gall, rel, pre, post, nF)
onF = zeros(numel(starts),1);
for j=1:numel(starts), [~,onF(j)] = min(abs(t_full-starts(j))); end
onF = onF(onF>pre & onF+post<=nF);  n = numel(onF);
A = zeros(n,numel(rel)); G = zeros(n,numel(rel));
for j=1:n, A(j,:) = y_full(onF(j)+rel).'; G(j,:) = Gall(onF(j)+rel).'; end
end

function shade_(ax,x,m,e,col)
x=x(:).'; m=m(:).'; e=e(:).';
fill(ax,[x fliplr(x)],[m+e fliplr(m-e)],col,'FaceAlpha',0.15,'EdgeColor','none','HandleVisibility','off');
end

function beeswarm_(ax,xc,y,col)
n=numel(y); jit=(rand(n,1)-0.5)*0.28;
scatter(ax,xc+jit,y,12,col,'filled','MarkerFaceAlpha',0.45,'HandleVisibility','off');
end

function ex_(ax,tt,Ar,Ahat,col,ttl)
hold(ax,'on');
xline(ax,0,':','Color',[.5 .5 .5],'HandleVisibility','off'); yline(ax,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
plot(ax,tt,Ar,'-','Color','k','LineWidth',1.5,'DisplayName','A_r (actual)');
plot(ax,tt,Ahat,'--','Color',col,'LineWidth',1.4,'DisplayName','G_r + avg local');
plot(ax,tt,Ar-Ahat,'-','Color',[.6 .6 .6],'LineWidth',1.0,'DisplayName','residual');
xlabel(ax,'time from stim (s)'); ylabel(ax,'response (%\DeltaF/F)');
title(ax,ttl,'FontWeight','normal'); legend(ax,'Location','southwest','Box','off'); xlim(ax,[tt(1) tt(end)]);
end

function sc_(ax,X,Y,col,nsub,slope,name)
x=X(:); y=Y(:); m=numel(x);
if m>nsub; s=randperm(m,nsub); else; s=1:m; end
scatter(ax,x(s),y(s),6,col,'filled','MarkerFaceAlpha',0.12,'HandleVisibility','off');
c=[ones(m,1) x]\y; xr=linspace(min(x),max(x),20).';
plot(ax,xr,c(1)+slope*xr,'-','Color',col,'LineWidth',1.8,'DisplayName',name);
end

function b=local_pslope(X,Y)
x=X(:); y=Y(:); ok=isfinite(x)&isfinite(y); x=x(ok); y=y(ok);
c=[ones(numel(x),1) x]\y; b=c(2);
end

function s=ternS(c,a,b); if c, s=a; else, s=b; end; end

function [y, ok] = local_svd_rolling_dfk(Uflat, V, mimg, prow, pcol, k, horizon, nY, nX)
y = nan(size(V,2),1);  ok = false;
if prow<1||prow>nY||pcol<1||pcol>nX; return; end
kr = max(1,prow-k):min(nY,prow+k);  kc = max(1,pcol-k):min(nX,pcol+k);
[KR,KC] = ndgrid(kr,kc);  kidx = sub2ind([nY,nX], KR(:), KC(:));
mI = mean(mimg(kr,kc),'all');
if ~isfinite(mI) || abs(mI) < eps; return; end
Fsvd = mean(double(Uflat(kidx,:)),1) * V;
Fraw = mI + Fsvd(:);
w = max(1, round(horizon)-1);  T = numel(Fraw);  ii = (1:T).';
cs = [0; cumsum(Fraw)];  lo = max(ii-w,1);
base = (cs(ii+1)-cs(lo))./(ii-lo+1);
y = (Fraw - base)./base*100;  y(1:w) = NaN;
ok = true;
end
