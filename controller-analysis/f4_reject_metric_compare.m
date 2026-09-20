% controller-analysis/f4_reject_metric_compare.m   PREVIEW ONLY (metric choice)
% SESSION-WISE (n=13), SETTLED 1-3 s, from the FRESHLY REBUILT contra-model cache
% (imp_reject_across_sessions_ridge.mat, 2026-09-18). Two bounded contra-model rejection
% metrics, 1 - metric (1 = perfect rejection):
%   ER = ||A-ref||^2/||G-ref||^2  (both referenced to target; the disturbance is a MEAN excursion,
%        so ER captures it) -- HEADLINE.
%   SR = ||A-<A>||^2/||G-<G>||^2  (mean-removed FLUCTUATION transmission) -- robustness; weak here
%        because the stim disturbance is mostly a mean shift that SR discards.
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
dd=fullfile(root,'controller-analysis','data');
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
col_ol=PS.col_ol; col_cl=PS.col_cl;
L=load(fullfile(dd,'imp_reject_across_sessions_ridge.mat')); Q=L.XSr.Q; nS=numel(Q);
erej_ol=arrayfun(@(q)1-median(q.er_ol),Q).'; erej_cl=arrayfun(@(q)1-median(q.er_cl),Q).';
srej_ol=arrayfun(@(q)q.rej_frac_ol,Q).';     srej_cl=arrayfun(@(q)q.rej_frac_cl,Q).';
pE=signrank(erej_ol,erej_cl); nE=nnz(erej_cl>erej_ol);
pS=signrank(srej_ol,srej_cl); nSw=nnz(srej_cl>srej_ol);

f=paperFig(13,6.4);
axE=axes(f,'Position',[0.10 0.16 0.36 0.66]);
paneled(axE,erej_ol,erej_cl,'ER: 1-||A-r||^2/||G-r||^2  (HEADLINE)',pE,nE,0,col_ol,col_cl,PS);
ylabel(axE,'disturbance rejected  1 - ER','FontSize',PS.fs,'FontWeight',PS.fw);
axS=axes(f,'Position',[0.60 0.16 0.36 0.66]);
paneled(axS,srej_ol,srej_cl,'SR: 1-||A-<A>||^2/||G-<G>||^2  (fluctuation)',pS,nSw,-0.6,col_ol,col_cl,PS);
ylabel(axS,'fluctuation rejected  1 - SR','FontSize',PS.fs,'FontWeight',PS.fw);
sgtitle(f,'Contra-model rejection, settled 1-3 s (n=13, rebuilt)','FontSize',PS.fs+1,'FontWeight','bold');
exportgraphics(f,fullfile(outview,'f4_reject_metric_compare.png'),'Resolution',220);
fprintf('ER 1-ER: OL %.3f -> CL %.3f (%d/%d, p=%.2e) | SR 1-SR: OL %.3f -> CL %.3f (%d/%d, p=%.3f)\n', ...
   median(erej_ol),median(erej_cl),nE,nS,pE, median(srej_ol),median(srej_cl),nSw,nS,pS);
fprintf('bounded[0,1]: 1-ER OL %d/%d CL %d/%d | 1-SR OL %d/%d CL %d/%d\n', ...
   nnz(erej_ol>=0&erej_ol<=1),nS,nnz(erej_cl>=0&erej_cl<=1),nS, nnz(srej_ol>=0&srej_ol<=1),nS,nnz(srej_cl>=0&srej_cl<=1),nS);

function paneled(ax,ro,rc,ttl,p,nw,ylo,col_ol,col_cl,PS)
    hold(ax,'on');
    patch(ax,[.6 2.4 2.4 .6],[0 0 1 1],[.94 .97 .94],'EdgeColor','none','HandleVisibility','off');
    if ylo<0, plot(ax,[.6 2.4],[0 0],'--','Color',[.55 .55 .55],'LineWidth',PS.lw_ref,'HandleVisibility','off'); end
    for k=1:numel(ro), plot(ax,[1 2],[ro(k) rc(k)],'-','Color',[.8 .8 .8],'LineWidth',0.5); end
    scatter(ax,ones(numel(ro),1),ro,11,col_ol,'filled'); scatter(ax,2*ones(numel(rc),1),rc,11,col_cl,'filled');
    plot(ax,[1 2],[median(ro) median(rc)],'-k','LineWidth',1.6);
    set(ax,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
    xlim(ax,[.6 2.4]); ylim(ax,[ylo 1]);
    title(ax,{ttl,sprintf('CL>OL %d/%d, p=%.3g',nw,numel(ro),p)},'FontSize',PS.fs,'FontWeight','bold');
end
