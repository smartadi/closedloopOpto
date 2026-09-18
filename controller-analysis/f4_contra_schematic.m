% controller-analysis/f4_contra_schematic.m
% Fig-4 BLOCK 4 schematic -- how the contralateral model isolates the local disturbance.
% Left: the stim-site linear predictor kernel on the real brain (contra weights -> stim site).
% Right: the SAME exemplar's trial-averaged Actual vs Global (contra-predicted) traces; Global
% stays flat THROUGH the stim while Actual dips, so the shaded gap = Local = A - G is the part
% the contra hemisphere cannot reproduce (the local stim + controller action). This is the visual
% statement of "the model negates the stim effect": the counterfactual is built from the other
% hemisphere and ridge (stim-blind lambda) drops the small-eigenvalue directions where stim leaks.
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
dd=fullfile(root,'controller-analysis','data');
outfig=fullfile(root,'paper','images','figure4');
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
tag='AL_0033_0415_e2';

% ---- data ----
S1=load(fullfile(dd,sprintf('ctrl_ols_spont_%s.mat',tag)));
[sfx,pmode]=ctrl_pred_tag(); assert(strcmp(pmode,'ridge'),'need ridge predictor');
O =load(fullfile(dd,sprintf('ctrl_ols_ol_stimblind%s_%s.mat',sfx,tag)));
brain=ctrl_mean_img(tag); [bm,bnd,mid]=ctrl_brain_mask(tag); [nY,nX]=size(brain);
b=O.b(:); grR=O.grR(:); grC=O.grC(:);
sx=S1.py_prim; sy=S1.px_prim;                 % stim site: x=col(py_prim), y=row(px_prim)
t=O.rel(:).'/O.Fs; A=O.Aa(:).'; G=O.Gg(:).'; L=O.Lo(:).';   % trial-avg traces (t in s)
colA=[0.10 0.10 0.10]; colG=[0.20 0.40 0.75]; colL=[0.78 0.16 0.12];

% ---- figure ----
f=paperFig(18,6);

% (1) brain kernel (left) -----------------------------------------------------------
axB=axes(f,'Position',[0.02 0.10 0.30 0.80]); hold(axB,'on');
lo=prctile(brain(bm),1); hi=prctile(brain(bm),99);
g=min(max((brain-lo)/max(hi-lo,eps),0),1); g=0.12+0.85*g; RGB=cat(3,g,g,g);
RGB(repmat(~bm,1,1,3))=1; image(axB,RGB);
bmax=prctile(abs(b),99);
scatter(axB,grC,grR,10,b,'filled','MarkerEdgeColor','none','MarkerFaceAlpha',0.95);
cmap=interp1([0 .5 1],[0.16 0.34 0.66; 1 1 1; 0.78 0.16 0.12],linspace(0,1,256));
colormap(axB,cmap); clim(axB,[-bmax bmax]);
plot(axB,bnd(:,2),bnd(:,1),'-','Color',[.2 .2 .2],'LineWidth',0.8);
if ~isempty(mid), plot(axB,mid.x,mid.y,':','Color',[.35 .35 .35],'LineWidth',0.7); end
plot(axB,sx,sy,'o','MarkerSize',7,'MarkerFaceColor','k','MarkerEdgeColor','none');
text(axB,double(sx),double(sy)+15,'stim site','Color','k','FontSize',PS.fs,'FontWeight','bold', ...
    'HorizontalAlignment','center','VerticalAlignment','top');
axis(axB,'image'); set(axB,'YDir','reverse'); axis(axB,'off');
[ry,rx]=find(bm); pad=10; xlim(axB,[max(1,min(rx)-pad) min(nX,max(rx)+pad)]); ylim(axB,[max(1,min(ry)-pad) min(nY,max(ry)+pad)]);
title(axB,{'contralateral kernel','(predicts stim site)'},'FontSize',PS.fs,'FontWeight','bold');
text(axB,double(min(rx)),double(min(ry))-6,'contra','Color',colG,'FontSize',PS.fs,'FontWeight','bold');

% arrow: kernel -> Global -----------------------------------------------------------
annotation(f,'textarrow',[0.335 0.40],[0.52 0.52],'String',{'ridge weights b','stim-blind \lambda'}, ...
    'FontSize',PS.fs,'FontWeight','bold','HeadStyle','vback2','HeadWidth',6,'HeadLength',6,'Color',[.15 .15 .15]);

% (2) decomposition (right): Actual vs Global, gap = Local --------------------------
axT=axes(f,'Position',[0.46 0.20 0.50 0.66]); hold(axT,'on');
xl=[t(1) t(end)]; yl=[min(A)*1.15 max(2,max(G))];
patch(axT,[0 3 3 0],[yl(1) yl(1) yl(2) yl(2)],[.93 .90 .82],'EdgeColor','none','FaceAlpha',.6,'HandleVisibility','off'); % stim window
% shaded Local = gap between Actual and Global
xf=[t fliplr(t)]; yf=[A fliplr(G)];
patch(axT,xf,yf,colL,'EdgeColor','none','FaceAlpha',0.20,'HandleVisibility','off');
plot(axT,xl,[0 0],'--','Color',[.6 .6 .6],'LineWidth',PS.lw_ref,'HandleVisibility','off');
xline(axT,0,':','Color',[.55 .55 .55],'HandleVisibility','off');
hG=plot(axT,t,G,'-','Color',colG,'LineWidth',PS.lw_mean);
hA=plot(axT,t,A,'-','Color',colA,'LineWidth',PS.lw_mean);
xlim(axT,xl); ylim(axT,yl); set(axT,'Box','off','TickDir','out','FontSize',PS.fs,'FontWeight',PS.fw);
xlabel(axT,'time from stim (s)','FontSize',PS.fs,'FontWeight',PS.fw);
ylabel(axT,'\DeltaF/F (%, baselined)','FontSize',PS.fs,'FontWeight',PS.fw);
lg=legend(axT,[hA hG],{'Actual (measured stim site)','Global (contra-predicted, no local input)'}, ...
    'Box','off','Location','northeast','FontSize',PS.fs); lg.ItemTokenSize=[8 8];
% annotate the gap = Local
[~,im]=min(A); xm=t(im);
text(axT,xm+0.15,(A(im)+G(im))/2,{'gap = Local','= A - G','(stim + control)'},'Color',colL, ...
    'FontSize',PS.fs,'FontWeight','bold','VerticalAlignment','middle');
text(axT,-0.9,0.6,'Global stays flat through stim','Color',colG,'FontSize',PS.fs,'FontWeight','bold');

sgtitle(f,'Contralateral model isolates the local disturbance:  A = G + L','FontSize',PS.fs+1,'FontWeight','bold');

paperExport(f,fullfile(outfig,'f4_contra_schematic.pdf'));
paperExport(f,fullfile(outview,'f4_contra_schematic.png'));
fprintf('[f4_contra_schematic] wrote schematic -> %s\n',outfig);
