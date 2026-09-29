% controller-analysis/f4_contra_model.m
% Fig-4 ROW-3 MIDDLE panel -- the A = G + L decomposition (STANDALONE, individual PDF).
%   Deploy: Actual (A) vs Global (G, contra-predicted counterfactual). G is flat through
%   stim (stim-blind), so the gap A-G = Local (the controller's own effect). R^2_te
%   (prediction quality) annotated here next to the prediction.
%
% 2026-09-28 (user): un-stitched. This script now exports ONLY the A=G+L panel as its own
% PDF (f4_agl.pdf). The kernel-weights brain map is a SEPARATE individual panel produced by
% f4_kernel_map.m (f4_kernel_map.pdf); the old OL-vs-CL phi panel was removed 2026-09-21 and
% is now the CL-only reach-gated reject panel H (f4_cl_reject_panel.m -> f4_cl_reject_RR.pdf).
% Row 3 = f4_kernel_map.pdf + f4_agl.pdf + f4_cl_reject_RR.pdf.
% Exemplar: AL_0033_0415_e2 (ridge).
clc; close all;
PS=paperStyle(); setPaperDefaults();
root='C:\Users\aditya\Documents\projects\brain_paper'; addpath(fullfile(root,'utils'));
dd=fullfile(root,'controller-analysis','data');
outfig=fullfile(root,'paper','images','figure4');
outview=fullfile(root,'controller-analysis','_preview'); if ~exist(outview,'dir'); mkdir(outview); end
tag='AL_0033_0415_e2';
colG=[0.20 0.40 0.75]; colA=[0.10 0.10 0.10]; colL=[0.78 0.16 0.12];

% ---- data (stim-blind deploy: Actual A, Global G, test R^2) ----
[sfx,pmode]=ctrl_pred_tag(); assert(strcmp(pmode,'ridge'),'need ridge predictor');
O =load(fullfile(dd,sprintf('ctrl_ols_ol_stimblind%s_%s.mat',sfx,tag)));
t=O.rel(:).'/O.Fs; A=O.Aa(:).'; G=O.Gg(:).'; R2=O.R2_te;

% ===== A = G + L (standalone) ======================================================
f=paperFig(5.0,4.6); axD=axes(f); hold(axD,'on');
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

paperExport(f,fullfile(outfig,'f4_agl.pdf'));
paperExport(f,fullfile(outview,'f4_agl.png'));
fprintf('[f4_contra_model] standalone A=G+L panel -> %s (f4_agl.pdf) | R2te=%.2f\n', outfig, R2);
