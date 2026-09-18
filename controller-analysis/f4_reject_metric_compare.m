% controller-analysis/f4_reject_metric_compare.m   PREVIEW ONLY (metric not locked)
% SESSION-WISE comparison (n=sessions, no pooling) of bounded disturbance-rejection metrics, each
% with per-session bootstrap validation (2000 resamples of trials), vs the current unbounded phi.
%   CURRENT  phi = 1 - RR,  RR=||A-ref||^2/||G||^2 (num->ref, den->0)  -> OL down to -6.3 (unbounded).
%   A) 1-ER  ER=||A-ref||^2/||G-ref||^2 (both->ref); contra-model, strictly in [0,1]; paired OL,CL.
%   B) CL-vs-OL  1 - med(||A_cl-ref||^2)/med(||A_ol-ref||^2) on the RAW regulated ipsi (settled 1-3 s),
%      OL = baseline (=0). Session-wise from pnc/pwc buffered traces (utils cache), NOT pooled.
% Bootstrap CI per session = validation (CI excluding 0 => that session significantly rejects).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
dd=fullfile(root,'controller-analysis','data');
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
col_ol=PS.col_ol; col_cl=PS.col_cl; grey=[.5 .5 .5]; rng(7); nB=2000;

% ---- Option A + current phi, session-wise from XSr (bootstrap per session) ----
L=load(fullfile(dd,'imp_reject_across_sessions_ridge.mat')); Q=L.XSr.Q; nS=numel(Q);
tagA={Q.sess_tag};
A_ol=zeros(nS,1);A_cl=zeros(nS,1);A_cl_lo=zeros(nS,1);A_cl_hi=zeros(nS,1);
phi_ol=zeros(nS,1);phi_cl=zeros(nS,1);
for k=1:nS
  q=Q(k); A_ol(k)=1-median(q.er_ol); A_cl(k)=1-median(q.er_cl);
  bs=zeros(nB,1); ec=q.er_cl(:); for b=1:nB, bs(b)=1-median(ec(randi(numel(ec),numel(ec),1))); end
  ci=prctile(bs,[2.5 97.5]); A_cl_lo(k)=ci(1); A_cl_hi(k)=ci(2);
  phi_ol(k)=1-median(q.rho_ol.^2); phi_cl(k)=1-median(q.rho_cl.^2);
end

% ---- Option B (raw ipsi, session-wise, precomputed) matched to the same sessions ----
Lb=load(fullfile(dd,'ctrl_rejectB_sessionwise.mat')); Bs=Lb.B; tagB={Bs.tag};
Bv=nan(nS,1);Blo=nan(nS,1);Bhi=nan(nS,1);
for k=1:nS, j=find(strcmp(tagB,tagA{k}),1); if ~isempty(j), Bv(k)=Bs(j).B; Blo(k)=Bs(j).lo; Bhi(k)=Bs(j).hi; end; end

pA=signrank(A_ol,A_cl); nAwin=nnz(A_cl>A_ol);
nBpos=nnz(Bv>0); nBsig=nnz(Blo>0);

f=paperFig(19,6.6);
% (1) current unbounded phi
axC=axes(f,'Position',[0.07 0.17 0.22 0.66]); hold(axC,'on');
plot(axC,[.6 2.4],[0 0],'--','Color',grey,'LineWidth',PS.lw_ref);
for k=1:nS, plot(axC,[1 2],[phi_ol(k) phi_cl(k)],'-','Color',[.82 .82 .82],'LineWidth',0.5); end
scatter(axC,ones(nS,1),phi_ol,10,col_ol,'filled'); scatter(axC,2*ones(nS,1),phi_cl,10,col_cl,'filled');
plot(axC,[1 2],[median(phi_ol) median(phi_cl)],'-k','LineWidth',1.6);
set(axC,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw); xlim(axC,[.6 2.4]);
ylabel(axC,'\phi = 1 - RR','FontSize',PS.fs,'FontWeight',PS.fw);
title(axC,{'CURRENT (unbounded)','OL to -6.3'},'FontSize',PS.fs,'FontWeight','bold','Color',[.6 .1 .1]);

% (2) Option A: 1-ER paired, bounded [0,1]
axA=axes(f,'Position',[0.38 0.17 0.22 0.66]); hold(axA,'on');
patch(axA,[.6 2.4 2.4 .6],[0 0 1 1],[.94 .97 .94],'EdgeColor','none');
for k=1:nS, plot(axA,[1 2],[A_ol(k) A_cl(k)],'-','Color',[.82 .82 .82],'LineWidth',0.5); end
scatter(axA,ones(nS,1),A_ol,10,col_ol,'filled'); scatter(axA,2*ones(nS,1),A_cl,10,col_cl,'filled');
plot(axA,[1 2],[median(A_ol) median(A_cl)],'-k','LineWidth',1.6);
set(axA,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw); xlim(axA,[.6 2.4]); ylim(axA,[0 1]);
ylabel(axA,'1 - ER   (contra model)','FontSize',PS.fs,'FontWeight',PS.fw);
title(axA,{'A) 1-ER (bounded, paired)',sprintf('CL>OL %d/%d, p=%.1e',nAwin,nS,pA)},'FontSize',PS.fs,'FontWeight','bold');

% (3) Option B: CL-vs-OL, session-wise with bootstrap CI (validation)
axB=axes(f,'Position',[0.69 0.17 0.28 0.66]); hold(axB,'on');
[~,ord]=sort(Bv); xx=1:nS;
patch(axB,[.4 nS+.6 nS+.6 .4],[0 0 1 1],[.94 .97 .94],'EdgeColor','none');
plot(axB,[.4 nS+.6],[0 0],'--','Color',grey,'LineWidth',PS.lw_ref);
for i=1:nS, k=ord(i); c=col_cl; if Bhi(k)<0||Blo(k)>0, else, end; if Bv(k)<0, c=col_ol; end
    plot(axB,[i i],[Blo(k) Bhi(k)],'-','Color',[.6 .6 .6],'LineWidth',0.7);
    scatter(axB,i,Bv(k),14,c,'filled'); end
plot(axB,[.4 nS+.6],[median(Bv) median(Bv)],'-k','LineWidth',1.2);
set(axB,'XTick',[],'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw); xlim(axB,[.4 nS+.6]); ylim(axB,[-0.8 1]);
xlabel(axB,'session (sorted)','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axB,'1 - ||A_{cl}-ref||^2/||A_{ol}-ref||^2','FontSize',PS.fs,'FontWeight',PS.fw);
title(axB,{'B) CL-vs-OL (OL=baseline, \pm95% CI)',sprintf('med %.2f, >0 %d/%d, CI>0 %d/%d',median(Bv),nBpos,nS,nBsig,nS)},'FontSize',PS.fs,'FontWeight','bold');

sgtitle(f,'Disturbance-rejection metric options -- session-wise (n=13), bootstrap-validated','FontSize',PS.fs+1,'FontWeight','bold');
exportgraphics(f,fullfile(outview,'f4_reject_metric_compare.png'),'Resolution',220);
fprintf('[compare] A 1-ER: med OL %.2f CL %.2f (CL>OL %d/%d p=%.1e)\n', median(A_ol),median(A_cl),nAwin,nS,pA);
fprintf('[compare] B CL-vs-OL: med %.2f, >0 %d/%d, CI>0 (sig) %d/%d\n', median(Bv),nBpos,nS,nBsig,nS);
