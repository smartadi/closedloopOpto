% controller-analysis/f4_model_explainer.m
% Fig-4 explanatory figure -- how the stim-blind contra->ipsi (Global) model works, in 3 steps:
%   1 LEARN      fit stim-site = sum b*(contra pixels) on SPONTANEOUS (laser-off) frames.
%   2 REGULARIZE ridge shrinks the whole grid; lambda chosen where the laser-off "catch"
%                leak stops falling (never sees a stim trial). Shrinkage removes the fragile,
%                collinear directions the stim signature lives in, at little spont-R^2 cost.
%   3 DECOMPOSE  deploy: Global = contra prediction = counterfactual "no local input"; it stays
%                flat through the stim, so Local = Actual - Global isolates stim + controller.
% All three panels use the real exemplar (AL_0033_0415_e2, ridge predictor). Methods/supp figure.
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
dd=fullfile(root,'controller-analysis','data');
outfig=fullfile(root,'paper','images','figure4');
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
tag='AL_0033_0415_e2';

S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)));
[sfx,pmode]=ctrl_pred_tag(); assert(strcmp(pmode,'ridge'),'need ridge predictor');
O =load(fullfile(dd,sprintf('ctrl_ols_ol_stimblind%s_%s.mat',sfx,tag)));
brain=ctrl_mean_img(tag); [bm,bnd,mid]=ctrl_brain_mask(tag); [nY,nX]=size(brain);
b=O.b(:); grR=O.grR(:); grC=O.grC(:); sx=S1.py_prim; sy=S1.px_prim;   % stim site x=col, y=row
t=O.rel(:).'/O.Fs; A=O.Aa(:).'; G=O.Gg(:).';
P=O.RPATH; [la,ord]=sort(P.lambdas); R2te=P.R2te(ord); leak=P.catchdef(ord); nrm=P.nrm(ord); lstar=P.lambda_star;
colG=[0.20 0.40 0.75]; colA=[0.10 0.10 0.10]; colL=[0.78 0.16 0.12]; colK=[0.30 0.30 0.30];

f=paperFig(19,6.6);
badge=@(x,y,s) annotation(f,'textbox',[x y .03 .06],'String',s,'FontSize',PS.fs+1,'FontWeight','bold', ...
    'HorizontalAlignment','center','VerticalAlignment','middle','EdgeColor',[.2 .2 .2],'BackgroundColor',[.95 .95 .95],'Margin',1);

% ===== STEP 1 -- LEARN (kernel on brain) ==========================================
axB=axes(f,'Position',[0.015 0.10 0.27 0.72]); hold(axB,'on');
lo=prctile(brain(bm),1); hi=prctile(brain(bm),99);
g=min(max((brain-lo)/max(hi-lo,eps),0),1); g=0.12+0.85*g; RGB=cat(3,g,g,g); RGB(repmat(~bm,1,1,3))=1;
image(axB,RGB); bmax=prctile(abs(b),99);
scatter(axB,grC,grR,9,b,'filled','MarkerEdgeColor','none','MarkerFaceAlpha',0.95);
colormap(axB,interp1([0 .5 1],[0.16 0.34 0.66;1 1 1;0.78 0.16 0.12],linspace(0,1,256))); clim(axB,[-bmax bmax]);
plot(axB,bnd(:,2),bnd(:,1),'-','Color',[.2 .2 .2],'LineWidth',0.8);
if ~isempty(mid), plot(axB,mid.x,mid.y,':','Color',[.35 .35 .35],'LineWidth',0.7); end
plot(axB,sx,sy,'o','MarkerSize',7,'MarkerFaceColor','k','MarkerEdgeColor','none');
text(axB,double(sx),double(sy)+15,'stim site','Color','k','FontSize',PS.fs,'FontWeight','bold','HorizontalAlignment','center','VerticalAlignment','top');
axis(axB,'image'); set(axB,'YDir','reverse'); axis(axB,'off');
[ry,rx]=find(bm); pad=10; xlim(axB,[max(1,min(rx)-pad) min(nX,max(rx)+pad)]); ylim(axB,[max(1,min(ry)-pad) min(nY,max(ry)+pad)]);
title(axB,{'Learn: stim site = \Sigma b\cdot(contra px)','fit on laser-off frames'},'FontSize',PS.fs,'FontWeight','bold');
badge(0.015,0.86,'1');

annotation(f,'arrow',[0.29 0.335],[0.5 0.5],'HeadStyle','vback2','HeadWidth',6,'HeadLength',6,'Color',colK);

% ===== STEP 2 -- REGULARIZE (stim-blind lambda) ===================================
axL=axes(f,'Position',[0.375 0.20 0.21 0.58]); hold(axL,'on');
yyaxis(axL,'left');
plot(axL,la,leak/max(leak),'-o','Color',colL,'MarkerFaceColor',colL,'MarkerSize',2.5,'LineWidth',PS.lw_mean);
ylabel(axL,'catch leak (rel.)','Color',colL,'FontSize',PS.fs,'FontWeight',PS.fw); ylim(axL,[0.75 1.02]);
set(axL,'YColor',colL);
yyaxis(axL,'right');
plot(axL,la,R2te,'-s','Color',colG,'MarkerFaceColor',colG,'MarkerSize',2.5,'LineWidth',PS.lw_mean);
ylabel(axL,'spont R^2','Color',colG,'FontSize',PS.fs,'FontWeight',PS.fw); ylim(axL,[0.66 0.80]); set(axL,'YColor',colG);
set(axL,'XScale','log'); xlim(axL,[min(la) max(la)]);
xline(axL,lstar,'-','Color',colK,'LineWidth',1.0,'HandleVisibility','off');
text(axL,lstar,0.79,'  \lambda*','Color',colK,'FontSize',PS.fs,'FontWeight','bold');
xlabel(axL,'ridge \lambda','FontSize',PS.fs,'FontWeight',PS.fw);
set(axL,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
title(axL,{'Regularize (stim-blind):','cut leak, stop before R^2 falls'},'FontSize',PS.fs,'FontWeight','bold');
text(axL,min(la)*2,0.685,sprintf('||b||: %.1f\\rightarrow%.1f',nrm(1),nrm(end)),'Color',colK,'FontSize',PS.fs-0.5,'FontWeight','bold');
badge(0.375,0.82,'2');

annotation(f,'arrow',[0.60 0.645],[0.5 0.5],'HeadStyle','vback2','HeadWidth',6,'HeadLength',6,'Color',colK);

% ===== STEP 3 -- DECOMPOSE (deploy) ===============================================
axT=axes(f,'Position',[0.685 0.20 0.30 0.58]); hold(axT,'on');
xl=[t(1) t(end)]; yl=[min(A)*1.15 max(2,max(G))];
patch(axT,[0 3 3 0],[yl(1) yl(1) yl(2) yl(2)],[.93 .90 .82],'EdgeColor','none','FaceAlpha',.6,'HandleVisibility','off');
patch(axT,[t fliplr(t)],[A fliplr(G)],colL,'EdgeColor','none','FaceAlpha',0.20,'HandleVisibility','off');
plot(axT,xl,[0 0],'--','Color',[.6 .6 .6],'LineWidth',PS.lw_ref,'HandleVisibility','off');
xline(axT,0,':','Color',[.55 .55 .55],'HandleVisibility','off');
hG=plot(axT,t,G,'-','Color',colG,'LineWidth',PS.lw_mean);
hA=plot(axT,t,A,'-','Color',colA,'LineWidth',PS.lw_mean);
xlim(axT,xl); ylim(axT,yl); set(axT,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axT,'time from stim (s)','FontSize',PS.fs,'FontWeight',PS.fw); ylabel(axT,'\DeltaF/F (%)','FontSize',PS.fs,'FontWeight',PS.fw);
lg=legend(axT,[hA hG],{'Actual','Global (contra pred.)'},'Box','off','Location','northeast','FontSize',PS.fs); lg.ItemTokenSize=[8 8];
[~,im]=min(A); text(axT,t(im)+0.2,(A(im)+G(im))/2,{'Local','= A - G'},'Color',colL,'FontSize',PS.fs,'FontWeight','bold','VerticalAlignment','middle');
title(axT,{'Decompose: Global flat through stim','\Rightarrow Local = stim + control'},'FontSize',PS.fs,'FontWeight','bold');
badge(0.685,0.82,'3');

sgtitle(f,'How the contralateral (Global) model isolates the local disturbance','FontSize',PS.fs+1,'FontWeight','bold');

paperExport(f,fullfile(outfig,'f4_model_explainer.pdf'));
paperExport(f,fullfile(outview,'f4_model_explainer.png'));
fprintf('[f4_model_explainer] wrote explainer -> %s\n',outfig);
