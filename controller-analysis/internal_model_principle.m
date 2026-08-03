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

[U_cp,V_cp,t_svd,mimg_cp] = cp_loadUVt(expPath(mn,td,en), nSV_load, d_s.timeBlue);
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
% Actual A = the paper's referenced ipsi trace data.dFk (ref=-5 lives in THIS scale);
% Global G = Gall from the Stage-2 predictor, which must ALSO be canonical (target_mode='canonical').
dfk_canon = data.dFk(:);
assert(numel(dfk_canon) >= nF, '[IMP] data.dFk (%d) shorter than SVD frames (%d).', numel(dfk_canon), nF);
if isfield(S2,'target_mode') && ~strcmp(S2.target_mode,'canonical')
    warning('[IMP] Stage-2 cache is target_mode=''%s'' (not canonical) -- A(dFk) and G(y_full) are in DIFFERENT scales; rerun ctrl_ols_ol_stimblind.m with target_mode=''canonical''.', S2.target_mode);
end
grab = @(ons) deal_trials(ons, t_full, dfk_canon, Gall, rel, pre, post, nF);
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
res2 = zeros(nOL,numel(resp)); res3 = zeros(nOL,numel(resp)); res3b = zeros(nOL,numel(resp));
for j=1:nOL
    tr=true(nOL,1); tr(j)=false;
    rbarA = mean(Ar_ol(tr,:),1);                          % LOO avg ACTUAL response
    rbarL = mean(Ar_ol(tr,:)-Gr_ol(tr,:),1);              % LOO avg LOCAL residual
    res2(j,:)  = Ar_ol(j,resp) - rbarA(resp);                     % M2  trial-average only
    res3(j,:)  = Ar_ol(j,resp) - Gr_ol(j,resp) - rbarL(resp);     % M3  contra-global + avg residual
    res3b(j,:) = Ar_ol(j,resp) - Gr_ol(j,resp) - rbarA(resp);     % M3b contra-global + trial-average
end
R2_M1  = 1 - sum(res1(:).^2)/SST_ol;
R2_M2  = 1 - sum(res2(:).^2)/SST_ol;
R2_M3  = 1 - sum(res3(:).^2)/SST_ol;
R2_M3b = 1 - sum(res3b(:).^2)/SST_ol;
% CONTROL: contra-global predicts ipsi in the PRE-STIM baseline window (no laser) -- absolute
Apre=Aol(:,bwin); Gpre=Gol(:,bwin);
R2_pre = 1 - sum((Apre(:)-Gpre(:)).^2)/sum((Apre(:)-mean(Apre(:))).^2);
% noise-floor: M3 residual var (post) vs baseline prediction residual var (pre, no laser)
Lpre = Ar_ol(:,bwin)-Gr_ol(:,bwin);
var_pre = var(Lpre(:)); var_post = var(res3(:)); nf_ratio = var_post/var_pre;

fprintf('\n[IMP-OL-PROOF] OL: ipsi ~= contra-global + avg OL response  (LOO-CV, window [0,%.0f]s)\n', resp_s);
fprintf('  CONTROL  contra-global -> ipsi, PRE-STIM (no laser)   R2 = %.3f\n', R2_pre);
fprintf('  CV-R2  M1  contra-global only          %.3f\n', R2_M1);
fprintf('  CV-R2  M2  trial-average only           %.3f\n', R2_M2);
fprintf('  CV-R2  M3  contra-global + avg RESIDUAL  %.3f\n', R2_M3);
fprintf('  CV-R2  M3b contra-global + TRIAL-AVG     %.3f\n', R2_M3b);
fprintf('  residual variance  baseline(pre) %.3f  post(M3) %.3f   ratio %.2f (1=noise floor)\n', ...
    var_pre, var_post, nf_ratio);

% ---- OL predicted-vs-actual R2 (proof/gallery/predfit drawn COMBINED with CL in [IMP-*-FIG] below) ----
pred_ol = Gr_ol + mean(Lol,1);                               % contra-global + avg OL residual
xt = reshape(pred_ol(:,resp),[],1); yt = reshape(Ar_ol(:,resp),[],1);
r2tp_ol = 1 - sum((yt-xt).^2)/sum((yt-mean(yt)).^2);         % per-timepoint R2
xm_ol = mean(pred_ol(:,resp),2); ym_ol = mean(Ar_ol(:,resp),2);
r2tr_ol = 1 - sum((ym_ol-xm_ol).^2)/sum((ym_ol-mean(ym_ol)).^2);   % per-trial-mean R2
fprintf('[IMP-OL-PREDPLOT] per-timepoint R2=%.3f | per-trial-mean R2=%.3f\n', r2tp_ol, r2tr_ol);

%% [IMP-CL-NULLMODEL] closed-loop null-model STATS via shared reporter ----------
% (Stats only; OL/CL figures are drawn COMBINED in [IMP-*-FIG] below.)
R_CL = imp_null_report('CL', Acl, Gcl, Ar_cl, Gr_cl, Lcl, nCL, resp, bwin);

%% [IMP-PROOF-FIG] combined OL/CL null-model proof (2x3: OL top row, CL bottom) --
col_da = [0.95 0.45 0.10];                                   % trial-avg prediction colour (orange)
[~,iEX_ol]=min(abs(recRMSE_ol-median(recRMSE_ol)));          % representative OL trial
[~,iEX_cl]=min(abs(recRMSE_cl-median(recRMSE_cl)));          % representative CL trial
PF(1)=struct('nm','OL','col',col_ol,'vv',[R2_M1 R2_M2 R2_M3 R2_M3b],'R2pre',R2_pre, ...
    'varpre',var_pre,'nf',nf_ratio,'Ar',Ar_ol,'Gr',Gr_ol,'L',Lol,'iEX',iEX_ol,'n',nOL);
PF(2)=struct('nm','CL','col',col_cl,'vv',[R_CL.R2_M1 R_CL.R2_M2 R_CL.R2_M3 R_CL.R2_M3b],'R2pre',R_CL.R2_pre, ...
    'varpre',R_CL.var_pre,'nf',R_CL.nf_ratio,'Ar',Ar_cl,'Gr',Gr_cl,'L',Lcl,'iEX',iEX_cl,'n',nCL);
figp=figure('Color','w','Position',[40 40 1500 800]);
tlp=tiledlayout(figp,2,3,'TileSpacing','compact','Padding','compact');
for rr=1:2
    P=PF(rr); rbarL=mean(P.L,1); rbarA=mean(P.Ar,1); sd_res=std(P.L,0,1);
    axa=nexttile(tlp,(rr-1)*3+1);
    bar(axa,P.vv,0.7,'FaceColor',P.col,'EdgeColor','none');
    set(axa,'XTick',1:4,'XTickLabel',{'contra','trial-avg','+resid','+trial-avg'},'Box','off','TickDir','out','FontSize',8);
    ylim(axa,[min(0,min(P.vv))-0.02 1]); ylabel(axa,'cross-validated R^2');
    title(axa,sprintf('(%s-a) nested models   [pre-stim contra R^2=%.2f]',P.nm,P.R2pre),'FontWeight','normal');
    for bi=1:4; text(axa,bi,max(P.vv(bi),0)+0.04,sprintf('%.2f',P.vv(bi)),'HorizontalAlignment','center','FontSize',8); end
    axb=nexttile(tlp,(rr-1)*3+2); hold(axb,'on');
    plot(axb,tt,sd_res,'-','Color',P.col,'LineWidth',1.6,'DisplayName','residual SD');
    yline(axb,sqrt(P.varpre),'--','Color',[.4 .4 .4],'LineWidth',1.2,'DisplayName','baseline noise floor');
    xline(axb,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
    xlabel(axb,'time from stim (s)'); ylabel(axb,'residual SD (%\DeltaF/F)'); xlim(axb,[tt(1) tt(end)]);
    title(axb,sprintf('(%s-b) residual vs noise floor  (post/pre var %.2f)',P.nm,P.nf),'FontWeight','normal');
    legend(axb,'Location','northwest','Box','off');
    axc=nexttile(tlp,(rr-1)*3+3); hold(axc,'on');
    xline(axc,0,':','Color',[.5 .5 .5],'HandleVisibility','off'); yline(axc,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
    plot(axc,tt,P.Ar(P.iEX,:),'-','Color','k','LineWidth',1.5,'DisplayName','ipsi (actual)');
    plot(axc,tt,P.Gr(P.iEX,:),'-','Color',[.6 .6 .6],'LineWidth',1.1,'DisplayName','contra-global');
    plot(axc,tt,P.Gr(P.iEX,:)+rbarL,'--','Color',P.col,'LineWidth',1.4,'DisplayName','contra + avg residual');
    plot(axc,tt,P.Gr(P.iEX,:)+rbarA,':','Color',col_da,'LineWidth',1.5,'DisplayName','contra + trial-avg');
    xlabel(axc,'time from stim (s)'); ylabel(axc,'response (%\DeltaF/F)'); xlim(axc,[tt(1) tt(end)]);
    title(axc,sprintf('(%s-c) example (trial %d)',P.nm,P.iEX),'FontWeight','normal'); legend(axc,'Location','southwest','Box','off');
end
sgtitle(figp,sprintf('[IMP] null-model: ipsi \\approx contra-global + avg response   %s   (OL top n=%d / CL bottom n=%d)', ...
    strrep(sess_tag,'_','\_'),nOL,nCL));
proofpng=fullfile(fig_dir,sprintf('internal_model_principle_proof_%s.png',sess_tag));
exportgraphics(figp,proofpng,'Resolution',300); fprintf('[IMP-PROOF-FIG] -> %s\n',proofpng);

%% [IMP-GALLERY-FIG] combined trial-by-trial (4x6: OL rows 1-2, CL rows 3-4) -----
ngal=12;                                                     % trials/condition (2 rows x 6)
figg=figure('Color','w','Position',[20 20 1720 980]);
tlg=tiledlayout(figg,4,6,'TileSpacing','compact','Padding','compact'); axg1=[];
GF={Ar_ol,Gr_ol,mean(Lol,1),mean(Ar_ol,1),col_ol,'OL',nOL; Ar_cl,Gr_cl,mean(Lcl,1),mean(Ar_cl,1),col_cl,'CL',nCL};
for bl=1:2
    Arb=GF{bl,1}; Grb=GF{bl,2}; rL=GF{bl,3}; rA=GF{bl,4}; colb=GF{bl,5}; nmb=GF{bl,6}; nb=GF{bl,7};
    for jj=1:min(ngal,nb)
        tile=(bl-1)*12+jj; axg=nexttile(tlg,tile); if isempty(axg1); axg1=axg; end; hold(axg,'on');
        pred=Grb(jj,:)+rL; predb=Grb(jj,:)+rA; rmse_j=sqrt(mean((Arb(jj,resp)-pred(resp)).^2));
        xline(axg,0,':','Color',[.6 .6 .6],'HandleVisibility','off'); yline(axg,0,':','Color',[.85 .85 .85],'HandleVisibility','off');
        plot(axg,tt,Arb(jj,:),'-','Color','k','LineWidth',1.0,'DisplayName','ipsi (actual)');
        plot(axg,tt,pred,'--','Color',colb,'LineWidth',1.0,'DisplayName','contra + avg residual');
        plot(axg,tt,predb,':','Color',col_da,'LineWidth',1.0,'DisplayName','contra + trial-avg');
        xlim(axg,[tt(1) tt(end)]); title(axg,sprintf('%s tr %d   rmse %.1f',nmb,jj,rmse_j),'FontWeight','normal','FontSize',8);
        if tile~=1; set(axg,'XTickLabel',[],'YTickLabel',[]); end
    end
end
legend(axg1,'FontSize',7,'Box','off','Location','southwest');
sgtitle(figg,sprintf('[IMP] trial-by-trial: ipsi vs contra-global + avg response   %s   (%d OL rows 1-2 / %d CL rows 3-4)', ...
    strrep(sess_tag,'_','\_'),min(ngal,nOL),min(ngal,nCL)));
galpng=fullfile(fig_dir,sprintf('internal_model_principle_trialfit_%s.png',sess_tag));
exportgraphics(figg,galpng,'Resolution',200); fprintf('[IMP-GALLERY-FIG] -> %s\n',galpng);

%% [IMP-PREDFIT-FIG] combined predicted-vs-actual (OL+CL overlaid, 1x2) ----------
pred_cl = Gr_cl + mean(Lcl,1);
figpp=figure('Color','w','Position',[60 80 1160 470]);
tlpp=tiledlayout(figpp,1,2,'TileSpacing','compact','Padding','compact');
% (a) per-timepoint scatter, both conditions overlaid
axs1=nexttile(tlpp,1); hold(axs1,'on'); rng(3,'twister');
xo=reshape(pred_ol(:,resp),[],1); yo=reshape(Ar_ol(:,resp),[],1);
xk=reshape(pred_cl(:,resp),[],1); yk=reshape(Ar_cl(:,resp),[],1);
so=randperm(numel(xo),min(3000,numel(xo))); sk=randperm(numel(xk),min(3000,numel(xk)));
scatter(axs1,xo(so),yo(so),6,col_ol,'filled','MarkerFaceAlpha',0.08,'DisplayName',sprintf('OL R^2=%.2f',r2tp_ol));
scatter(axs1,xk(sk),yk(sk),6,col_cl,'filled','MarkerFaceAlpha',0.08,'DisplayName',sprintf('CL R^2=%.2f',R_CL.r2_tp));
lims=[min([xo;yo;xk;yk]) max([xo;yo;xk;yk])]; plot(axs1,lims,lims,'k-','LineWidth',1,'HandleVisibility','off');
axis(axs1,'square'); xlim(axs1,lims); ylim(axs1,lims); grid(axs1,'on');
xlabel(axs1,'predicted (%\DeltaF/F)'); ylabel(axs1,'actual ipsi (%\DeltaF/F)');
title(axs1,'(a) per-timepoint','FontWeight','normal'); legend(axs1,'Location','northwest','Box','off');
% (b) per-trial mean scatter, both conditions overlaid
axs2=nexttile(tlpp,2); hold(axs2,'on');
xmo=mean(pred_ol(:,resp),2); ymo=mean(Ar_ol(:,resp),2);
xmk=mean(pred_cl(:,resp),2); ymk=mean(Ar_cl(:,resp),2);
scatter(axs2,xmo,ymo,22,col_ol,'filled','MarkerFaceAlpha',0.5,'DisplayName',sprintf('OL R^2=%.2f',r2tr_ol));
scatter(axs2,xmk,ymk,22,col_cl,'filled','MarkerFaceAlpha',0.5,'DisplayName',sprintf('CL R^2=%.2f',R_CL.r2_tr));
lims2=[min([xmo;ymo;xmk;ymk]) max([xmo;ymo;xmk;ymk])]; plot(axs2,lims2,lims2,'k-','LineWidth',1,'HandleVisibility','off');
axis(axs2,'square'); xlim(axs2,lims2); ylim(axs2,lims2); grid(axs2,'on');
xlabel(axs2,'predicted trial-mean (%\DeltaF/F)'); ylabel(axs2,'actual trial-mean (%\DeltaF/F)');
title(axs2,'(b) per-trial mean','FontWeight','normal'); legend(axs2,'Location','northwest','Box','off');
sgtitle(figpp,sprintf('[IMP] prediction vs actual: contra-global + avg response   %s   (OL n=%d / CL n=%d)', ...
    strrep(sess_tag,'_','\_'),nOL,nCL));
predpng=fullfile(fig_dir,sprintf('internal_model_principle_predfit_%s.png',sess_tag));
exportgraphics(figpp,predpng,'Resolution',300); fprintf('[IMP-PREDFIT-FIG] -> %s\n',predpng);

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
FSq = 14;                                                    % base font size (larger, cleaner)
figI = figure('Color','w','Position',[40 80 1500 480]);
tl = tiledlayout(figI,1,3,'TileSpacing','compact','Padding','compact');

% (1) trial-average residual +- SEM
ax1=nexttile(tl,1); hold(ax1,'on');
shade_(ax1, tt, mLol, seLol, col_ol);
shade_(ax1, tt, mLcl, seLcl, col_cl);
hO=plot(ax1,tt,mLol,'-','Color',col_ol,'LineWidth',1.8,'DisplayName','OL residual');
hC=plot(ax1,tt,mLcl,'-','Color',col_cl,'LineWidth',1.8,'DisplayName','CL residual');
xline(ax1,0,':','Color',[.5 .5 .5]); yline(ax1,0,':','Color',[.5 .5 .5]);
xlabel(ax1,'time from stim (s)','FontSize',FSq+1); ylabel(ax1,'residual L = A − G  (%\DeltaF/F)','FontSize',FSq+1);
title(ax1,'(a) trial-average residual','FontWeight','normal','FontSize',FSq+2);
set(ax1,'Box','off','TickDir','out','FontSize',FSq);
legend(ax1,[hO hC],'Location','southwest','Box','off','FontSize',FSq); xlim(ax1,[tt(1) tt(end)]);

% (2) trial-to-trial SD over time
ax2=nexttile(tl,2); hold(ax2,'on');
xline(ax2,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
plot(ax2,tt,sdLol,'-','Color',col_ol,'LineWidth',1.8,'DisplayName','OL');
plot(ax2,tt,sdLcl,'-','Color',col_cl,'LineWidth',1.8,'DisplayName','CL');
xlabel(ax2,'time from stim (s)','FontSize',FSq+1); ylabel(ax2,'trial-to-trial SD  (%\DeltaF/F)','FontSize',FSq+1);
title(ax2,'(b) residual variability','FontWeight','normal','FontSize',FSq+2);
set(ax2,'Box','off','TickDir','out','FontSize',FSq);
legend(ax2,'Location','northwest','Box','off','FontSize',FSq); xlim(ax2,[tt(1) tt(end)]);

% (3) per-trial mean residual: OL vs CL spread
ax3=nexttile(tl,3); hold(ax3,'on');
beeswarm_(ax3, 1, sOL, col_ol); beeswarm_(ax3, 2, sCL, col_cl);
errorbar(ax3,1-0.28,mean(sOL),std(sOL),'ko','MarkerFaceColor',col_ol,'MarkerSize',7,'LineWidth',1.0,'CapSize',5);
errorbar(ax3,2+0.28,mean(sCL),std(sCL),'ko','MarkerFaceColor',col_cl,'MarkerSize',7,'LineWidth',1.0,'CapSize',5);
set(ax3,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',FSq); xlim(ax3,[0.5 2.5]);
ylabel(ax3,'per-trial mean residual  (%\DeltaF/F)','FontSize',FSq+1);
title(ax3,'(c) residual spread','FontWeight','normal','FontSize',FSq+2);

sgtitle(figI, sprintf('residual  OL vs CL   %s', strrep(sess_tag,'_','\_')),'FontSize',FSq+3,'FontWeight','bold');
fig_png = fullfile(fig_dir, sprintf('internal_model_principle_q3_%s.png', sess_tag));
exportgraphics(figI, fig_png, 'Resolution', 300);
fprintf('[IMP-Q3-FIG] -> %s\n', fig_png);

%% [IMP-COMPARE] OL vs CL: fixed-response null model & the active-control excess -
figc=figure('Color','w','Position',[50 80 1500 430]);
tlc=tiledlayout(figc,1,3,'TileSpacing','compact','Padding','compact');
% (a) null-model fit R2 (OL vs CL)
axca=nexttile(tlc,1);
ba=bar(axca,[R2_M3 R_CL.R2_M3],0.6,'FaceColor','flat'); ba.CData(1,:)=col_ol; ba.CData(2,:)=col_cl;
set(axca,'XTickLabel',{'OL','CL'},'Box','off','TickDir','out'); ylim(axca,[0 1]);
ylabel(axca,'null-model CV-R^2  (contra + avg resp)');
title(axca,'(a) fixed-response model fit','FontWeight','normal');
text(axca,1,R2_M3+0.03,sprintf('%.2f',R2_M3),'HorizontalAlignment','center');
text(axca,2,R_CL.R2_M3+0.03,sprintf('%.2f',R_CL.R2_M3),'HorizontalAlignment','center');
% (b) fixed-response residual SD(t) with per-condition noise floors
axcb=nexttile(tlc,2); hold(axcb,'on');
flo_ol=mean(sdLol(bwin)); flo_cl=mean(sdLcl(bwin));
plot(axcb,tt,sdLol,'-','Color',col_ol,'LineWidth',1.6,'DisplayName','OL residual SD');
plot(axcb,tt,sdLcl,'-','Color',col_cl,'LineWidth',1.6,'DisplayName','CL residual SD');
yline(axcb,flo_ol,'--','Color',col_ol,'LineWidth',1.0,'HandleVisibility','off');
yline(axcb,flo_cl,'--','Color',col_cl,'LineWidth',1.0,'HandleVisibility','off');
xline(axcb,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(axcb,'time from stim (s)'); ylabel(axcb,'fixed-response residual SD (%\DeltaF/F)'); xlim(axcb,[tt(1) tt(end)]);
title(axcb,'(b) residual excess = active control','FontWeight','normal');
legend(axcb,'Location','northwest','Box','off');
% (c) noise-floor ratio (integrated residual excess)
axcc=nexttile(tlc,3);
bc=bar(axcc,[nf_ratio R_CL.nf_ratio],0.6,'FaceColor','flat'); bc.CData(1,:)=col_ol; bc.CData(2,:)=col_cl;
set(axcc,'XTickLabel',{'OL','CL'},'Box','off','TickDir','out');
yline(axcc,1,':','Color',[.4 .4 .4],'HandleVisibility','off');
ylabel(axcc,'residual var / baseline  (noise-floor ratio)');
title(axcc,'(c) residual excess over noise floor','FontWeight','normal');
text(axcc,1,nf_ratio+0.1,sprintf('%.1f\\times',nf_ratio),'HorizontalAlignment','center');
text(axcc,2,R_CL.nf_ratio+0.1,sprintf('%.1f\\times',R_CL.nf_ratio),'HorizontalAlignment','center');
sgtitle(figc,sprintf('[IMP] OL vs CL: fixed-response null model & active-control excess   %s   (OL n=%d, CL n=%d)', ...
    strrep(sess_tag,'_','\_'),nOL,nCL));
cpng=fullfile(fig_dir,sprintf('internal_model_principle_olcl_compare_%s.png',sess_tag));
exportgraphics(figc,cpng,'Resolution',300); fprintf('[IMP-COMPARE] -> %s\n',cpng);

%% [IMP-REJECT] per-trial disturbance transmission: rho = ||A-ref|| / ||G|| ------
% Disturbance is time-varying = stim-blind contra prediction, zero-referenced:
%     D_k(t) = G_k(t)              (what the ipsi WOULD do with no controller)
% Subdued error on the controlled trial, referenced to the target:
%     E_k(t) = A_k(t) - ref        (how far the ACTUAL ipsi sits from target)
% Metric = residual-to-disturbance RMS ratio over the window:
%     rho_k = ||E_k|| / ||D_k||    over the response window.
% rho=0 perfect rejection (E sits at ref); rho=1 disturbance passes unattenuated;
% rho>1 amplified. LOWER = better rejection (this is the raw ratio, not 1-ratio).
if isfield(d_s,'ref') && ~isempty(d_s.ref); ref = d_s.ref; else; ref = -5; end
% Split the response into two physically distinct sub-windows:
%   w_tr  = 0-1 s : dominated by the laser-evoked initial deviation (common OL/CL)
%   w_rej = 1-3 s : settled window -> pure disturbance rejection (headline stats)
w_tr  = pre+1              : pre+round(1*Fs);
w_rej = pre+round(1*Fs)+1  : pre+round(resp_s*Fs);
rejW  = @(A,G,w) sqrt(mean((A(:,w)-ref).^2,2)) ./ sqrt(mean(G(:,w).^2,2));   % per-trial ||E||/||D|| on window w
poolW = @(A,G,w) sqrt(sum((A(:,w)-ref).^2,'all')/sum(G(:,w).^2,'all'));      % pooled ||E||/||D|| on window w

rho_ol_tr=rejW(Aol,Gol,w_tr);   rho_cl_tr=rejW(Acl,Gcl,w_tr);      % 0-1 s transient (init-dev)
rho_ol=rejW(Aol,Gol,w_rej);     rho_cl=rejW(Acl,Gcl,w_rej);        % 1-3 s transmission (headline)
Dmag_ol=sqrt(mean(Gol(:,w_rej).^2,2));   Dmag_cl=sqrt(mean(Gcl(:,w_rej).^2,2));  % disturbance RMS (1-3s)
Emag_ol=sqrt(mean((Aol(:,w_rej)-ref).^2,2)); Emag_cl=sqrt(mean((Acl(:,w_rej)-ref).^2,2));
p_tr  = ranksum(rho_ol_tr,rho_cl_tr);   p_rho = ranksum(rho_ol,rho_cl);
rhoP_ol=poolW(Aol,Gol,w_rej);  rhoP_cl=poolW(Acl,Gcl,w_rej);
fprintf('\n[IMP-REJECT] per-trial transmission  rho = ||A-ref||/||G||  (0=full rejection, ref=%.1f)\n',ref);
fprintf('  0-1 s (transient / init-dev): med OL %.3f  CL %.3f  (rank-sum p=%.3g)\n',median(rho_ol_tr),median(rho_cl_tr),p_tr);
fprintf('  1-3 s (settled transmission): med OL %.3f  CL %.3f  (rank-sum p=%.3g)  <-- headline (lower=better)\n',median(rho_ol),median(rho_cl),p_rho);
fprintf('  1-3 s pooled rho           : OL %.3f  CL %.3f\n',rhoP_ol,rhoP_cl);

% ---- trial gallery: disturbance D=G (gray), actual A without ref-subtraction
%      (light dashed), and subdued error E=A-ref (colored, pre-stim lighter). The
%      raw A shows pre-stim A~G~0 -> the reference is effectively zero before the
%      laser; post-stim the referenced error E is what the metric compares to D. --
ncols = 4;
gsel = @(n) max(1,min(n,round(linspace(0.10,0.90,ncols)*n)));
[~,so]=sort(rho_ol); idxO=so(gsel(nOL));
[~,sc]=sort(rho_cl); idxC=sc(gsel(nCL));
figr=figure('Color','w','Position',[40 60 1500 620]);
tlr=tiledlayout(figr,2,ncols,'TileSpacing','compact','Padding','compact');
rowspec = {Aol,Gol,idxO,rho_ol,col_ol,'OL'; Acl,Gcl,idxC,rho_cl,col_cl,'CL'};
for rr=1:2
    A=rowspec{rr,1}; G=rowspec{rr,2}; idx=rowspec{rr,3}; rhov=rowspec{rr,4}; col=rowspec{rr,5}; nm=rowspec{rr,6};
    for cc=1:ncols
        ax=nexttile(tlr,(rr-1)*ncols+cc); k=idx(cc);
        h = plot_reject_panel(ax, tt, G(k,:), A(k,:), ref, col, resp_s);
        title(ax,sprintf('%s trial %d   ||E||/||D||=%.2f',nm,k,rhov(k)),'FontWeight','normal');
        if cc==1; ylabel(ax,'%\DeltaF/F'); end
        if rr==2; xlabel(ax,'time from stim (s)'); end
        if rr==1 && cc==1; legend(ax,[h.D h.A h.E],'Location','northwest','Box','off'); end
    end
end
sgtitle(figr,sprintf('[IMP-REJECT] rejection gallery  %s  (D=contra disturbance, E=A-ref; shaded = 1-3 s rejection window)', ...
    strrep(sess_tag,'_','\_')));
rejpng=fullfile(fig_dir,sprintf('internal_model_principle_reject_gallery_%s.png',sess_tag));
exportgraphics(figr,rejpng,'Resolution',300); fprintf('[IMP-REJECT] -> %s\n',rejpng);

% ---- summary: rejection distributions + rejection vs disturbance size ----------
FS = 14;                                                     % base font size (larger, cleaner)
figs=figure('Color','w','Position',[50 80 1500 480]);
tls=tiledlayout(figs,1,3,'TileSpacing','compact','Padding','compact');
% --- (a) 0-1 s transient window ; (b) 1-3 s rejection window (jitter dist + median) ---
for pp=1:2
    if pp==1; ro=rho_ol_tr; rc=rho_cl_tr; ttl='(a) 0–1 s transient';
    else;     ro=rho_ol;    rc=rho_cl;    ttl='(b) 1–3 s settled'; end
    ax=nexttile(tls,pp); hold(ax,'on');
    scatter(ax,1+0.09*randn(nOL,1),ro,22,col_ol,'filled','MarkerFaceAlpha',.5);
    scatter(ax,2+0.09*randn(nCL,1),rc,22,col_cl,'filled','MarkerFaceAlpha',.5);
    plot(ax,[0.72 1.28],[median(ro) median(ro)],'-','Color',col_ol,'LineWidth',2.8);
    plot(ax,[1.72 2.28],[median(rc) median(rc)],'-','Color',col_cl,'LineWidth',2.8);
    yline(ax,1,'--','Color',[.7 .7 .7],'HandleVisibility','off');   % 1 = disturbance passes (no rejection)
    yline(ax,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
    set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',FS); xlim(ax,[0.5 2.5]);
    if pp==1; ylabel(ax,'transmission  ||E|| / ||D||','FontSize',FS+1); end
    title(ax,ttl,'FontWeight','normal','FontSize',FS+2);
end
axc=nexttile(tls,3); hold(axc,'on');
scatter(axc,Dmag_ol,rho_ol,24,col_ol,'filled','MarkerFaceAlpha',.55,'DisplayName','OL');
scatter(axc,Dmag_cl,rho_cl,24,col_cl,'filled','MarkerFaceAlpha',.55,'DisplayName','CL');
yline(axc,1,'--','Color',[.7 .7 .7],'HandleVisibility','off');
yline(axc,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(axc,'disturbance ||G|| (RMS %\DeltaF/F)','FontSize',FS+1); ylabel(axc,'transmission  ||E|| / ||D||','FontSize',FS+1);
set(axc,'Box','off','TickDir','out','FontSize',FS);
title(axc,'(c) vs disturbance size','FontWeight','normal','FontSize',FS+2);
legend(axc,'Location','southeast','Box','off','FontSize',FS);
sgtitle(figs,sprintf('disturbance rejection   %s',strrep(sess_tag,'_','\_')),'FontSize',FS+3,'FontWeight','bold');
rej2png=fullfile(fig_dir,sprintf('internal_model_principle_reject_summary_%s.png',sess_tag));
exportgraphics(figs,rej2png,'Resolution',300); fprintf('[IMP-REJECT] -> %s\n',rej2png);

%% [IMP-REJECT-CLICK] interactive: click a point in (rho vs disturbance size, 1-3 s) -> reveal that trial
% Left = the panel-(c) scatter, clickable. Click any dot -> right panel shows that trial's
% disturbance D=G (gray) and subdued error E=A-ref (colored), shaded 1-3 s rejection window.
CK = struct('tt',tt,'ref',ref,'w_rej',w_rej,'resp_s',resp_s,'col_ol',col_ol,'col_cl',col_cl, ...
    'Aol',Aol,'Gol',Gol,'Acl',Acl,'Gcl',Gcl);
CK.x    = [Dmag_ol; Dmag_cl];               % disturbance ||G||_{1-3}
CK.y    = [rho_ol;  rho_cl];                % rejection rho_{1-3}
CK.cond = [ones(nOL,1); 2*ones(nCL,1)];     % 1=OL, 2=CL
CK.tidx = [(1:nOL)'; (1:nCL)'];             % within-condition trial index
figCK = figure('Color','w','Position',[60 90 1320 520],'Name',sprintf('[IMP-REJECT] click a trial  %s',sess_tag));
tlk = tiledlayout(figCK,1,2,'TileSpacing','compact','Padding','compact');
axS = nexttile(tlk,1); hold(axS,'on');      % clickable scatter
hOL = scatter(axS,Dmag_ol,rho_ol,28,col_ol,'filled','MarkerFaceAlpha',.6);
hCL = scatter(axS,Dmag_cl,rho_cl,28,col_cl,'filled','MarkerFaceAlpha',.6);
yline(axS,0,':','Color',[.5 .5 .5],'HandleVisibility','off');
xlabel(axS,'disturbance ||G||_{1-3} (RMS %\DeltaF/F)'); ylabel(axS,'rejection \rho_{1-3}');
title(axS,'click a point \rightarrow inspect its trial'); box(axS,'off'); set(axS,'TickDir','out');
legend(axS,[hOL hCL],{'OL','CL'},'Location','southeast','Box','off');
axI = nexttile(tlk,2); title(axI,'(click a point on the left)'); box(axI,'off'); set(axI,'TickDir','out');
CK.axS = axS; CK.axI = axI; CK.hMark = [];
guidata(figCK, CK);
set(figCK,'WindowButtonDownFcn',@(f,~)imp_reject_click(f));
fprintf('[IMP-REJECT-CLICK] interactive figure open -- click points to reveal trials.\n');

%% [IMP-STATE-QUARTILE] rho_{1-3} vs pre-stim state (motion / delta power) -------
% Classify the per-trial rejection ratio rho_{1-3}=||E||/||D|| (lower=better) by
% two pre-stim states, binned into quartiles Q1(low)->Q4(high):
%   motion       = mean movement over the 2 s pre-stim window (data.*motion, 1:70)
%   delta power  = mean absolute 2-4 Hz band power over pre-onset bins (data.*FreqPow)
% Quartile edges are POOLED over OL+CL so Q1..Q4 are the SAME absolute state for
% both conditions. State arrays are stored in nc/wc order -> re-sorted by onset and
% edge-dropped to match the rho_ol/rho_cl trial order (same as deal_trials).
% State definitions MATCH the figure-4 factor analysis (cl_rmse_factor_windows.m),
% recomputed here from primitives (d.motion, data.dFk) so no cache field is needed:
%   motion = mean z-motion^2 over -2 s -> trial end          (energy; d.motion is z-scored)
%   delta  = RELATIVE 2-4 Hz power = bandpow(2-4)/bandpow(0.4-10) over -2 s -> stim end
%            (per-trial periodogram: linear detrend + Hann, identical local_bandpow)
% NB (as in fig-4): the window spans -2 s through the trial, not pre-stim only.
% States come from the SHARED helper utils/imp_trial_states.m so this section and the
% cross-session batch (imp_state_across_sessions.m) can never drift apart.
STx = imp_trial_states(d_s, data, t_full, pre, post, nF, Fs);
haveMot = STx.haveMot;
if ~haveMot; warning('[IMP-STATE-QUARTILE] d.motion/timeBlue absent -- motion panel skipped.'); end
assert(STx.n_ol==nOL && STx.n_cl==nCL, ...
    '[IMP-STATE-QUARTILE] onset/rho trial-count mismatch (OL %d/%d, CL %d/%d).', STx.n_ol,nOL,STx.n_cl,nCL);

STQ = struct('name',{},'ol',{},'cl',{});
if haveMot; STQ(end+1)=struct('name',STx.names{1},'ol',STx.mot_ol,'cl',STx.mot_cl); end
STQ(end+1)=struct('name',STx.names{2},'ol',STx.delt_ol,'cl',STx.delt_cl);
nSt=numel(STQ);
figQ=figure('Color','w','Position',[50 70 620*nSt 480]); FSq=13;
tlq=tiledlayout(figQ,1,nSt,'TileSpacing','compact','Padding','compact');
fprintf('\n[IMP-STATE-QUARTILE] rho_{1-3}=||E||/||D|| vs pre-stim state (quartiles; lower rho=better)\n');
for s=1:nSt
    so=STQ(s).ol; sc=STQ(s).cl;
    sv=[so;sc]; sv=sv(isfinite(sv));
    ed=quantile(sv,[0 .25 .5 .75 1]); ed(1)=-inf; ed(end)=inf;
    qo=discretize(so,ed); qc=discretize(sc,ed);
    [mo,eo,no]=local_qstat(rho_ol,qo); [mc,ec,nc_]=local_qstat(rho_cl,qc);
    [rs_o,po]=corr(so,rho_ol,'type','Spearman','rows','complete');
    [rs_c,pc]=corr(sc,rho_cl,'type','Spearman','rows','complete');
    STQ(s).q_ol=qo; STQ(s).q_cl=qc; STQ(s).med_ol=mo; STQ(s).med_cl=mc; STQ(s).n_ol=no; STQ(s).n_cl=nc_;
    STQ(s).rs_ol=rs_o; STQ(s).rs_cl=rs_c; STQ(s).p_ol=po; STQ(s).p_cl=pc; STQ(s).edges=ed;
    fprintf('  %-26s OL Spearman r=%+.2f (p=%.2g) med Q1->Q4 [%s] | CL r=%+.2f (p=%.2g) [%s]\n', ...
        STQ(s).name, rs_o,po, sprintf('%.2f ',mo), rs_c,pc, sprintf('%.2f ',mc));
    ax=nexttile(tlq,s); hold(ax,'on');
    errorbar(ax,(1:4)-0.06,mo,eo,'-o','Color',col_ol,'LineWidth',1.8,'MarkerFaceColor',col_ol,'CapSize',4,'DisplayName','OL');
    errorbar(ax,(1:4)+0.06,mc,ec,'-o','Color',col_cl,'LineWidth',1.8,'MarkerFaceColor',col_cl,'CapSize',4,'DisplayName','CL');
    yline(ax,1,'--','Color',[.7 .7 .7],'HandleVisibility','off');   % 1 = disturbance passes (no rejection)
    set(ax,'XTick',1:4,'XTickLabel',{'Q1','Q2','Q3','Q4'},'Box','off','TickDir','out','FontSize',FSq); xlim(ax,[0.5 4.5]);
    xlabel(ax,sprintf('%s  (low \\rightarrow high)',STQ(s).name),'FontSize',FSq+1);
    if s==1; ylabel(ax,'transmission  ||E|| / ||D||','FontSize',FSq+1); end
    title(ax,sprintf('OL r_s=%+.2f  |  CL r_s=%+.2f',rs_o,rs_c),'FontWeight','normal','FontSize',FSq+1);
    if s==1; legend(ax,'Location','best','Box','off','FontSize',FSq); end
end
sgtitle(figQ,sprintf('rejection vs pre-stim state (quartiles)   %s',strrep(sess_tag,'_','\_')),'FontSize',FSq+3,'FontWeight','bold');
stqpng=fullfile(fig_dir,sprintf('internal_model_principle_state_quartile_%s.png',sess_tag));
exportgraphics(figQ,stqpng,'Resolution',300); fprintf('[IMP-STATE-QUARTILE] -> %s\n',stqpng);

%% [IMP-SAVE] -------------------------------------------------------------------
IMP = struct('sess_tag',sess_tag,'nOL',nOL,'nCL',nCL,'tt',tt, ...
    'mLol',mLol,'mLcl',mLcl,'sdLol',sdLol,'sdLcl',sdLcl,'sOL',sOL,'sCL',sCL, ...
    'respMag_OL',respMag_OL,'respMag_CL',respMag_CL,'varOL',varOL,'varCL',varCL, ...
    'vratio',vratio,'vr_ci',vr_ci,'dm_ci',dm_ci,'resp_s',resp_s,'Fs',Fs, ...
    'R2add_ol',R2add_ol,'R2add_cl',R2add_cl,'R2g_ol',R2g_ol,'R2g_cl',R2g_cl, ...
    'recRMSE_ol',recRMSE_ol,'recRMSE_cl',recRMSE_cl,'dRMSE_ci',dRMSE_ci, ...
    'beta_ol',beta_ol,'beta_cl',beta_cl,'trans_ol',trans_ol,'trans_cl',trans_cl, ...
    'dbeta_ci',dbeta_ci,'comp_ol',comp_ol,'comp_cl',comp_cl, ...
    'R2_pre',R2_pre,'R2_M1',R2_M1,'R2_M2',R2_M2,'R2_M3',R2_M3,'R2_M3b',R2_M3b, ...
    'R_CL',R_CL);
IMP.ref=ref; IMP.rho_ol=rho_ol; IMP.rho_cl=rho_cl; IMP.rhoP_ol=rhoP_ol; IMP.rhoP_cl=rhoP_cl;
IMP.rho_ol_tr=rho_ol_tr; IMP.rho_cl_tr=rho_cl_tr; IMP.p_tr=p_tr; IMP.p_rho=p_rho;
IMP.Dmag_ol=Dmag_ol; IMP.Dmag_cl=Dmag_cl; IMP.Emag_ol=Emag_ol; IMP.Emag_cl=Emag_cl;
IMP.STQ=STQ;   % [IMP-STATE-QUARTILE] rho vs pre-stim motion / delta-power quartiles
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

function imp_reject_click(f)
% [IMP-REJECT-CLICK] callback: snap the click to the nearest scatter point and
% draw that trial via the shared panel (D=G gray, A no-ref light dashed, E=A-ref
% colored with pre-stim lighter). Metric = ||E||/||D|| (lower = better rejection).
CK = guidata(f);
cp = get(CK.axS,'CurrentPoint'); xc = cp(1,1); yc = cp(1,2);
xl = get(CK.axS,'XLim'); yl = get(CK.axS,'YLim');            % normalize axes so x,y are comparable
[~,i] = min(((CK.x-xc)/max(diff(xl),eps)).^2 + ((CK.y-yc)/max(diff(yl),eps)).^2);
if CK.cond(i)==1, A=CK.Aol; G=CK.Gol; col=CK.col_ol; nm='OL'; else, A=CK.Acl; G=CK.Gcl; col=CK.col_cl; nm='CL'; end
k = CK.tidx(i);  tt = CK.tt;
if ~isempty(CK.hMark) && ishandle(CK.hMark), delete(CK.hMark); end
CK.hMark = plot(CK.axS, CK.x(i), CK.y(i), 'ko','MarkerSize',12,'LineWidth',1.7); guidata(f,CK);
ax = CK.axI; delete(allchild(ax)); hold(ax,'off');   % clear ALL children incl. hidden-handle (pre-stim) lines
h = plot_reject_panel(ax, tt, G(k,:), A(k,:), CK.ref, col, CK.resp_s, true);   % raw-A pre-stim only
xlabel(ax,'time from stim (s)'); ylabel(ax,'%\DeltaF/F');
w = CK.w_rej; Dm = sqrt(mean(G(k,w).^2)); Em = sqrt(mean((A(k,w)-CK.ref).^2)); rho = Em/Dm;
title(ax,sprintf('%s trial %d:  ||E||/||D||=%.2f   ||G||=%.2f   ||E||=%.2f',nm,k,rho,Dm,Em),'FontWeight','normal');
legend(ax,[h.D h.A h.E],'Location','northwest','Box','off');
end

function h = plot_reject_panel(ax, tt, Dk, Ak, ref, col, resp_s, aPreOnly)
% One rejection trial panel, shared by the gallery and the click reveal:
%   D = G        disturbance / stim-blind contra prediction         (gray, solid)
%   A (no ref)   raw actual ipsi, NOT ref-subtracted                (light dashed)
%                -> pre-stim A ~ G ~ 0, i.e. the reference is effectively zero
%                   before the laser; post-stim A shows the true suppression.
%   E = A - ref  subdued error (the metric numerator); pre-stim drawn lighter to
%                mark the ref-zero baseline, post-stim in full condition colour.
% aPreOnly (default false): draw the raw-A dashed trace pre-stim only (t<0).
if nargin<8 || isempty(aPreOnly), aPreOnly=false; end
hold(ax,'on');
Ek = Ak - ref;  ipre = tt<0;  ipost = ~ipre;
lcol = col + 0.55*([1 1 1]-col);                            % lighter tint of the condition colour
if aPreOnly, aY = Ak(ipre); else, aY = Ak; end             % A samples that will be shown
yl = [min([Dk aY Ek])-1, max([Dk aY Ek])+1];
patch(ax,[1 resp_s resp_s 1],[yl(1) yl(1) yl(2) yl(2)],[.92 .92 .92],'EdgeColor','none','HandleVisibility','off');
yline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
xline(ax,0,':','Color',[.6 .6 .6],'HandleVisibility','off');
h.D = plot(ax,tt,Dk,'-','Color',[.45 .45 .45],'LineWidth',1.2,'DisplayName','disturbance D = contra pred');
if aPreOnly
    h.A = plot(ax,tt(ipre),Ak(ipre),'--','Color',lcol,'LineWidth',1.1,'DisplayName','actual A (no ref, pre-stim)');
else
    h.A = plot(ax,tt,Ak,'--','Color',lcol,'LineWidth',1.1,'DisplayName','actual A (no ref)');
end
plot(ax,tt(ipre),Ek(ipre),'-','Color',lcol,'LineWidth',1.2,'HandleVisibility','off');   % pre-stim error (ref-zero baseline)
h.E = plot(ax,tt(ipost),Ek(ipost),'-','Color',col,'LineWidth',1.6,'DisplayName','subdued error E = A - ref');
xlim(ax,[tt(1) tt(end)]); ylim(ax,yl); box(ax,'off'); set(ax,'TickDir','out');
end





function [m,e,n] = local_qstat(y,q)
% median, SEM-of-median (~1.2533*SD/sqrt(n)) and count of y within each quartile bin q=1..4
m=nan(1,4); e=nan(1,4); n=zeros(1,4);
for k=1:4
    yk=y(q==k); yk=yk(isfinite(yk)); n(k)=numel(yk);
    if n(k)>0, m(k)=median(yk); e(k)=1.2533*std(yk)/sqrt(max(1,n(k))); end
end
end

function R = imp_null_report(cond,A,G,Ar,Gr,L,n,resp,bwin)
% Null-model STATS for one condition: nested LOO-CV models (contra-global + avg
% response), pre-stim control, noise floor, predicted-vs-actual R2. Returns ONLY
% numbers -- the OL/CL figures are drawn COMBINED by the caller
% ([IMP-PROOF-FIG]/[IMP-GALLERY-FIG]/[IMP-PREDFIT-FIG]) so each is one figure.
% --- nested LOO-CV models ---
SST = sum((Ar(:,resp)-mean(Ar(:,resp),'all')).^2,'all');
res1 = Ar(:,resp)-Gr(:,resp);
res2 = zeros(n,numel(resp)); res3 = zeros(n,numel(resp)); res3b = zeros(n,numel(resp));
for j=1:n
    tr=true(n,1); tr(j)=false;
    rbarA = mean(Ar(tr,:),1); rbarL = mean(Ar(tr,:)-Gr(tr,:),1);
    res2(j,:)  = Ar(j,resp) - rbarA(resp);
    res3(j,:)  = Ar(j,resp) - Gr(j,resp) - rbarL(resp);
    res3b(j,:) = Ar(j,resp) - Gr(j,resp) - rbarA(resp);
end
R.R2_M1=1-sum(res1(:).^2)/SST; R.R2_M2=1-sum(res2(:).^2)/SST;
R.R2_M3=1-sum(res3(:).^2)/SST; R.R2_M3b=1-sum(res3b(:).^2)/SST;
Apre=A(:,bwin); Gpre=G(:,bwin);
R.R2_pre = 1 - sum((Apre(:)-Gpre(:)).^2)/sum((Apre(:)-mean(Apre(:))).^2);
Lpre = Ar(:,bwin)-Gr(:,bwin);
R.var_pre=var(Lpre(:)); var_post=var(res3(:)); R.nf_ratio=var_post/R.var_pre;
fprintf('\n[IMP-%s-PROOF] %s: ipsi ~= contra-global + avg %s response  (LOO-CV)\n',cond,cond,cond);
fprintf('  CONTROL  contra-global -> ipsi, PRE-STIM   R2 = %.3f\n',R.R2_pre);
fprintf('  CV-R2  contra-only %.3f | trial-avg %.3f | contra+resid %.3f | contra+trial-avg %.3f\n', ...
    R.R2_M1,R.R2_M2,R.R2_M3,R.R2_M3b);
fprintf('  noise-floor  baseline %.3f  post %.3f  ratio %.2f\n',R.var_pre,var_post,R.nf_ratio);
% --- predicted-vs-actual R2 (scatter drawn combined by caller) ---
pred_all=Gr+mean(L,1);
xt=reshape(pred_all(:,resp),[],1); yt=reshape(Ar(:,resp),[],1);
R.r2_tp=1-sum((yt-xt).^2)/sum((yt-mean(yt)).^2);
xm=mean(pred_all(:,resp),2); ym=mean(Ar(:,resp),2);
R.r2_tr=1-sum((ym-xm).^2)/sum((ym-mean(ym)).^2);
fprintf('[IMP-%s-PREDPLOT] per-timepoint R2=%.3f | per-trial-mean R2=%.3f\n',cond,R.r2_tp,R.r2_tr);
end

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
