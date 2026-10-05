function ctrl_mpc_supp_fig(sess)
%CTRL_MPC_SUPP_FIG  Supplementary MPC figure: what a disturbance forecast would buy over PI.
%   A  forecast skill vs lead on the real single-trial disturbance (ctrl_mpc_forecast_sigma)
%   B  per-trial residual RMSE vs forecast error, measured vs perfect actuator (ctrl_mpc_realtrial)
%   C  one example trial: tuned PI vs MPC with a real forecast vs MPC with a perfect forecast
% Working-copy PNGs -> paper/images/supp_mpc/. Not a locked panel yet (no PDF; see CLAUDE.md).
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); if isempty(here), here = fullfile(pwd,'controller-analysis'); end
dataDir = fullfile(here,'data'); figDir = fullfile(here,'..','paper','images','supp_mpc');
if ~exist(figDir,'dir'); mkdir(figDir); end
addpath(fullfile(here,'..','utils'));
PS = paperStyle(); S = jnStyle();
F  = load(fullfile(dataDir, sprintf('ctrl_mpc_forecast_sigma_%s.mat', sess)));
R  = load(fullfile(dataDir, sprintf('ctrl_mpc_realtrial_%s.mat', sess)));
Rg = load(fullfile(dataDir, sprintf('ctrl_mpc_realtrial_%s_g1.mat', sess)));
colM = [0.45 0.20 0.60];  colG = [0.55 0.55 0.55];  delay = 3/35;   % plant input delay nk = 3 samples
W = jnPanelWidth('double',3);

%% A  forecast skill vs lead ---------------------------------------------------------
fig = jnFig(W, S.rowH); ax = axes(fig); hold(ax,'on');
plot(ax,[0 1],[1 1],'--','Color',colG,'LineWidth',S.lw_ref);
xline(ax, delay, ':','Color',colG,'LineWidth',S.lw_ref);
hP = plot(ax,[0 F.lead_s],[0 F.mPer],'-','Color',colG,'LineWidth',S.lw_mean);
hA = plot(ax,[0 F.lead_s],[0 F.mAR],'-','Color',colM,'LineWidth',S.lw_mean);
text(ax, 0.97, 1.04, 'no forecast','HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',S.fs_annot,'Color',colG);
text(ax, delay+0.02, 0.08, 'plant delay','FontSize',S.fs_annot,'Color',colG);
xlim(ax,[0 1]); ylim(ax,[0 1.4]);
xlabel(ax,'forecast lead (s)'); ylabel(ax,'forecast error (rel.)');
lg = legend(ax,[hA hP],{'AR forecaster','persistence'},'Box','off','Location','southeast','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_A_forecast_skill.png'));

%% B  residual vs forecast error -------------------------------------------------------
xg = R.P.xGrid; ix = cellfun(@(m) find(strcmp(R.modes, sprintf('x%.2f',m))), num2cell(xg));
med = median(R.rM(:,ix)); q1 = prctile(R.rM(:,ix),25); q3 = prctile(R.rM(:,ix),75);
xgg = Rg.P.xGrid; ixg = cellfun(@(m) find(strcmp(Rg.modes, sprintf('x%.2f',m))), num2cell(xgg));
fig = jnFig(W, S.rowH); ax = axes(fig); hold(ax,'on');
fill(ax,[xg fliplr(xg)],[q1 fliplr(q3)], colM,'FaceAlpha',PS.fa,'EdgeColor','none');
plot(ax,[0 1.5],median(R.rPI)*[1 1],'-','Color',PS.col_cl,'LineWidth',S.lw_mean);
plot(ax,[0 1.5],median(R.realCL)*[1 1],'--','Color',PS.col_cl,'LineWidth',S.lw_ref);
hM = plot(ax,xg,med,'-o','Color',colM,'MarkerFaceColor',colM,'MarkerSize',S.marker,'LineWidth',S.lw_mean);
hG = plot(ax,xgg,median(Rg.rM(:,ixg)),'--o','Color',colM,'MarkerFaceColor','w','MarkerSize',S.marker,'LineWidth',S.lw_ref);
text(ax,1.48,median(R.rPI),'tuned PI','HorizontalAlignment','right','VerticalAlignment','top','FontSize',S.fs_annot,'Color',PS.col_cl);
text(ax,1.48,median(R.realCL),'recorded CL','HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',S.fs_annot,'Color',PS.col_cl);
set(ax,'XTick',[0 0.5 1 1.5],'XTickLabel',{'perfect','0.5','AR','1.5'});
xlim(ax,[0 1.5]); ylim(ax,[0 3.5]);
xlabel(ax,'forecast error (\times AR)'); ylabel(ax,'RMSE (%\DeltaF/F)');
lg = legend(ax,[hM hG],{'MPC, measured gain spread','MPC, perfect actuator'},'Box','off','Location','northwest','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_B_rmse_vs_forecast.png'));

%% C  example trial --------------------------------------------------------------------
tt = R.tt; iC = strcmp(R.modes,'x0.00'); iA = strcmp(R.modes,'x1.00');
% representative trial: all three controllers jointly closest to their own median RMSE (log distance)
Rr = [R.rPI R.rM(:,iA) R.rM(:,iC)];
[~,k] = min(sum(abs(log(Rr ./ median(Rr))), 2));
R.yPI1 = R.yPI(:,k); R.yEx = cellfun(@(Yi) Yi(:,k), R.Y, 'uni', 0);
fprintf('[MPC-SUPP] example trial %d: RMSE PI %.2f | MPC AR %.2f | MPC perfect %.2f\n', k, R.rPI(k), R.rM(k,iA), R.rM(k,iC));
fig = jnFig(W, S.rowH); ax = axes(fig); hold(ax,'on');
plot(ax,[0 3],R.P.ref*[1 1],'--','Color','k','LineWidth',S.lw_ref);
patch(ax,[1 3 3 1],[-15 -15 10 10],[0.93 0.93 0.93],'EdgeColor','none');
hPI = plot(ax,tt,R.yPI1,'-','Color',PS.col_cl,'LineWidth',S.lw_mean);
hA  = plot(ax,tt,R.yEx{iA},'-','Color',colM,'LineWidth',S.lw_mean);
hC  = plot(ax,tt,R.yEx{iC},'-','Color',[0.80 0.65 0.90],'LineWidth',S.lw_mean);
uistack(findobj(ax,'Type','patch'),'bottom');
xlim(ax,[0 3]); yl = [min([R.yPI1;R.yEx{iA};R.yEx{iC}])-1, max([R.yPI1;R.yEx{iA};R.yEx{iC}])+4]; ylim(ax,yl);   % headroom for the legend
xlabel(ax,'time from onset (s)'); ylabel(ax,'\DeltaF/F (%)');
lg = legend(ax,[hPI hA hC],{'PI','MPC (AR)','MPC (perfect)'},'Box','off','Location','north','NumColumns',3,'FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_C_example_trial.png'));
fprintf('[MPC-SUPP] 3 panels -> %s\n', figDir);
end
