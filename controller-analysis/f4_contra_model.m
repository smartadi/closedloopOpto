% controller-analysis/f4_contra_model.m
% Fig-4 BLOCK 4 composite -- the contralateral (Global) model: PREDICTION capability + DISTURBANCE
% rejection, in one panel row.
%   a  Stim-site linear predictor kernel weights on the real brain (spatial prediction).
%   b  Deploy: Actual vs Global (contra-predicted); Global flat through stim -> gap = Local = A-G.
%      R^2_te annotated here (prediction quality lives next to the prediction).
%   c  Per-session disturbance rejected phi = 1 - ||A-ref||^2/||G||^2, OL -> CL paired (signrank).
% Exemplar for a/b: AL_0033_0415_e2 (ridge). c pools all sessions (imp_reject_across_sessions_ridge).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
dd=fullfile(root,'controller-analysis','data');
outfig=fullfile(root,'paper','images','figure4');
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
tag='AL_0033_0415_e2';
col_ol=PS.col_ol; col_cl=PS.col_cl;
colG=[0.20 0.40 0.75]; colA=[0.10 0.10 0.10]; colL=[0.78 0.16 0.12];

% ---- data ----
S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)));
[sfx,pmode]=ctrl_pred_tag(); assert(strcmp(pmode,'ridge'),'need ridge predictor');
O =load(fullfile(dd,sprintf('ctrl_ols_ol_stimblind%s_%s.mat',sfx,tag)));
brain=ctrl_mean_img(tag); [bm,bnd,mid]=ctrl_brain_mask(tag); [nY,nX]=size(brain);
b=O.b(:); grR=O.grR(:); grC=O.grC(:); sx=S1.py_prim; sy=S1.px_prim;   % stim site x=col,y=row
t=O.rel(:).'/O.Fs; A=O.Aa(:).'; G=O.Gg(:).'; R2=O.R2_te;

f=paperFig(19,6.2);

% ===== (a) kernel weights ==========================================================
axK=axes(f,'Position',[0.015 0.10 0.28 0.70]); hold(axK,'on');
lo=prctile(brain(bm),1); hi=prctile(brain(bm),99);
g=min(max((brain-lo)/max(hi-lo,eps),0),1); g=0.12+0.85*g; RGB=cat(3,g,g,g); RGB(repmat(~bm,1,1,3))=1;
image(axK,RGB); bmax=prctile(abs(b),99);
scatter(axK,grC,grR,11,b,'filled','MarkerEdgeColor','none','MarkerFaceAlpha',0.95);
colormap(axK,interp1([0 .5 1],[0.16 0.34 0.66;1 1 1;0.78 0.16 0.12],linspace(0,1,256))); clim(axK,[-bmax bmax]);
plot(axK,bnd(:,2),bnd(:,1),'-','Color',[.2 .2 .2],'LineWidth',0.8);
if ~isempty(mid), plot(axK,mid.x,mid.y,':','Color',[.35 .35 .35],'LineWidth',0.7); end
plot(axK,sx,sy,'o','MarkerSize',7,'MarkerFaceColor','k','MarkerEdgeColor','none');
text(axK,double(sx),double(sy)+15,'stim site','Color','k','FontSize',PS.fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top');
axis(axK,'image'); set(axK,'YDir','reverse'); axis(axK,'off');
[ry,rx]=find(bm); pad=10; xlim(axK,[max(1,min(rx)-pad) min(nX,max(rx)+pad)]); ylim(axK,[max(1,min(ry)-pad) min(nY,max(ry)+pad)]);
title(axK,'Stim site linear predictor kernel weights','FontSize',PS.fs,'FontWeight','bold');
cb=colorbar(axK,'eastoutside'); cb.FontSize=PS.fs; cb.Ticks=[-bmax bmax];
cb.TickLabels={sprintf('%+.2f',-bmax),sprintf('%+.2f',bmax)}; cb.TickLength=0;
cb.Position=[0.295 0.22 0.010 0.44];

% ===== (b) decomposition A=G+L =====================================================
axD=axes(f,'Position',[0.42 0.20 0.27 0.60]); hold(axD,'on');
xl=[t(1) t(end)]; yl=[min(A)*1.15 max(2,max(G))];
patch(axD,[0 3 3 0],[yl(1) yl(1) yl(2) yl(2)],[.93 .90 .82],'EdgeColor','none','FaceAlpha',.6,'HandleVisibility','off');
patch(axD,[t fliplr(t)],[A fliplr(G)],colL,'EdgeColor','none','FaceAlpha',0.20,'HandleVisibility','off');
plot(axD,xl,[0 0],'--','Color',[.6 .6 .6],'LineWidth',PS.lw_ref,'HandleVisibility','off');
xline(axD,0,':','Color',[.55 .55 .55],'HandleVisibility','off');
hG=plot(axD,t,G,'-','Color',colG,'LineWidth',PS.lw_mean);
hA=plot(axD,t,A,'-','Color',colA,'LineWidth',PS.lw_mean);
xlim(axD,xl); ylim(axD,yl); set(axD,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axD,'time from stim (s)','FontSize',PS.fs,'FontWeight',PS.fw); ylabel(axD,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight',PS.fw);
lg=legend(axD,[hA hG],{'Actual','Global (contra pred.)'},'Box','off','Location','northeast','FontSize',PS.fs); lg.ItemTokenSize=[8 8];
[~,im]=min(A); text(axD,t(im)+0.2,(A(im)+G(im))/2,{'Local','= A - G'},'Color',colL,'FontSize',PS.fs,'FontWeight','bold','VerticalAlignment','middle');
text(axD,xl(1)+0.1,yl(1)*0.92,sprintf('R^2_{te} = %.2f',R2),'Color',colG,'FontSize',PS.fs,'FontWeight','bold');
title(axD,'Global predicts the counterfactual','FontSize',PS.fs,'FontWeight','bold');

% ===== (c) per-session disturbance rejection: 1 - ER (bounded, contra model) =======
% ER = ||A-ref||^2 / ||G-ref||^2 (both referenced to ref) on the 0-3 s stim window, so a
% do-nothing controller (A==G) gives ER=1 -> rejection 0, and the fraction stays in [0,1]
% (unlike phi=1-RR, whose zero-referenced denominator sent OL to -6). Per session = 1-median(ER).
axP=axes(f,'Position',[0.80 0.20 0.165 0.60]); hold(axP,'on');
L=load(fullfile(dd,'imp_reject_across_sessions_ridge.mat')); Q=L.XSr.Q; nS=numel(Q);
rej_ol=arrayfun(@(q) 1-median(q.er_ol),Q).'; rej_cl=arrayfun(@(q) 1-median(q.er_cl),Q).';
p_sess=signrank(rej_ol,rej_cl); nwin=nnz(rej_cl>rej_ol);
patch(axP,[0.6 2.4 2.4 0.6],[0 0 1 1],[.94 .97 .94],'EdgeColor','none','HandleVisibility','off');
for k=1:nS, plot(axP,[1 2],[rej_ol(k) rej_cl(k)],'-','Color',[.75 .75 .75],'LineWidth',0.5,'HandleVisibility','off'); end
scatter(axP,ones(nS,1),rej_ol,9,col_ol,'filled','MarkerFaceAlpha',.85);
scatter(axP,2*ones(nS,1),rej_cl,9,col_cl,'filled','MarkerFaceAlpha',.85);
plot(axP,[1 2],[median(rej_ol) median(rej_cl)],'-k','LineWidth',1.6);
xlim(axP,[0.6 2.4]); ylim(axP,[0 1]); set(axP,'XTick',[1 2],'XTickLabel',{'OL','CL'},'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axP,'disturbance rejected  1 - ER','FontSize',PS.fs,'FontWeight',PS.fw);
title(axP,sprintf('n=%d, CL>OL %d/%d, p=%s',nS,nwin,nS,pstr(p_sess)),'FontSize',PS.fs,'FontWeight',PS.fw);

% panel letters
annotation(f,'textbox',[0.005 0.90 .03 .06],'String','a','FontSize',PS.fs+2,'FontWeight','bold','EdgeColor','none');
annotation(f,'textbox',[0.375 0.90 .03 .06],'String','b','FontSize',PS.fs+2,'FontWeight','bold','EdgeColor','none');
annotation(f,'textbox',[0.755 0.90 .03 .06],'String','c','FontSize',PS.fs+2,'FontWeight','bold','EdgeColor','none');

paperExport(f,fullfile(outfig,'f4_contra_model.pdf'));
paperExport(f,fullfile(outview,'f4_contra_model.png'));
fprintf('[f4_contra_model] R2te=%.2f | 1-ER med OL %.3f -> CL %.3f | CL>OL %d/%d p=%.2e\n', ...
    R2, median(rej_ol), median(rej_cl), nwin, nS, p_sess);
fprintf('[f4_contra_model] wrote composite -> %s\n', outfig);

function s=pstr(p); if p<1e-3, s=sprintf('%.1e',p); else, s=sprintf('%.3f',p); end; end
