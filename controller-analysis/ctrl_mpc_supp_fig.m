function ctrl_mpc_supp_fig(sess)
%CTRL_MPC_SUPP_FIG  Supplementary MPC figure: what a disturbance preview buys over PI.
%   A  plant: OL trial-average step response vs the 2-state + 57 ms delay model (ctrl_mpc_lqr)
%   B  forecast skill vs lead on the real single-trial disturbance (ctrl_mpc_forecast_sigma)
%   C  preview-LQR error relative to tuned PI vs forecast error (median paired ratio, IQR band),
%      measured actuator-gain spread vs perfect actuator (ctrl_mpc_lqr, '' and '_g1' runs)
%   D  representative trial: PI vs preview-LQR with the AR forecast vs with a perfect forecast
% Working-copy PNGs -> paper/images/supp_mpc/. Not a locked panel yet (no PDF; see CLAUDE.md).
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); if isempty(here), here = fullfile(pwd,'controller-analysis'); end
dataDir = fullfile(here,'data'); figDir = fullfile(here,'..','paper','images','supp_mpc');
if ~exist(figDir,'dir'); mkdir(figDir); end
addpath(fullfile(here,'..','utils'));
PS = paperStyle(); S = jnStyle();
F  = load(fullfile(dataDir, sprintf('ctrl_mpc_forecast_sigma_%s.mat', sess)));
R  = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s.mat', sess)));
Rg = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_g1.mat', sess)));
L  = load(fullfile(dataDir, sprintf('ctrl_lti_%s.mat', sess)));
colM = [0.45 0.20 0.60];  colM2 = [0.80 0.65 0.90];  colG = [0.55 0.55 0.55];
Fs = R.P.Fs; delay = R.P.delay/Fs;
W = jnPanelWidth('double',3);
delete(findobj(0,'Type','figure','-regexp','Name','^mpcS'));

%% A  plant fit ----------------------------------------------------------------------
md = ss(R.A, R.B, R.C, 0, 1/Fs); tA = ((1:numel(L.y_OL)) - L.pre).'/Fs;
yfit = lsim(md, L.u_OL(:));
fig = jnFig(W, S.rowH); ax = axes(fig); hold(ax,'on');
hD = plot(ax, tA, L.y_OL, '-', 'Color', PS.col_ol, 'LineWidth', S.lw_mean);
hF = plot(ax, tA, yfit, '--', 'Color', 'k', 'LineWidth', S.lw_fit);
xlim(ax,[-0.5 3]); xlabel(ax,'time from onset (s)'); ylabel(ax,'\DeltaF/F (%)');
lg = legend(ax,[hD hF],{'OL trial average', sprintf('2-state + %.0f ms delay (%.0f%%)', 1000*delay, R.fitOL)}, ...
    'Box','off','Location','northeast','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_A_plant_fit.png'));

%% B  forecast skill vs lead ---------------------------------------------------------
fig = jnFig(W, S.rowH); ax = axes(fig); hold(ax,'on');
plot(ax,[0 1],[1 1],'--','Color',colG,'LineWidth',S.lw_ref);
xline(ax, delay, ':','Color',colG,'LineWidth',S.lw_ref);
hP = plot(ax,[0 F.lead_s],[0 F.mPer],'-','Color',colG,'LineWidth',S.lw_mean);
hA = plot(ax,[0 F.lead_s],[0 F.mAR],'-','Color',colM,'LineWidth',S.lw_mean);
text(ax, 0.97, 1.04, 'no forecast','HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',S.fs_annot,'Color',colG);
text(ax, delay+0.02, 0.08, 'loop delay','FontSize',S.fs_annot,'Color',colG);
xlim(ax,[0 1]); ylim(ax,[0 1.4]);
xlabel(ax,'forecast lead (s)'); ylabel(ax,'forecast error (rel.)');
lg = legend(ax,[hA hP],{'AR forecaster','persistence'},'Box','off','Location','southeast','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_B_forecast_skill.png'));

%% C  error relative to PI vs forecast error --------------------------------------------
[xg, med, q1, q3] = ratioCurve(R);  [xgg, medg] = ratioCurve(Rg);
fig = jnFig(W, S.rowH); ax = axes(fig); hold(ax,'on');
fill(ax,[xg fliplr(xg)],[q1 fliplr(q3)], colM,'FaceAlpha',PS.fa,'EdgeColor','none');
plot(ax,[0 1.5],[1 1],'-','Color',PS.col_cl,'LineWidth',S.lw_mean);
hM = plot(ax,xg,med,'-o','Color',colM,'MarkerFaceColor',colM,'MarkerSize',S.marker,'LineWidth',S.lw_mean);
hG = plot(ax,xgg,medg,'--o','Color',colM,'MarkerFaceColor','w','MarkerSize',S.marker,'LineWidth',S.lw_ref);
text(ax,0.02,1.04,'tuned PI','VerticalAlignment','bottom','FontSize',S.fs_annot,'Color',PS.col_cl);
set(ax,'XTick',[0 0.5 1 1.5],'XTickLabel',{'perfect','0.5','AR','1.5'});
xlim(ax,[0 1.5]); ylim(ax,[0 1.6]);
xlabel(ax,'forecast error (\times AR)'); ylabel(ax,'error / PI error');
lg = legend(ax,[hM hG],{'measured gain spread','perfect actuator'},'Box','off','Location','southeast','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_C_ratio_vs_forecast.png'));

%% D  representative trial --------------------------------------------------------------
tt = R.tt; iC = strcmp(R.modes,'x0.00'); iA = strcmp(R.modes,'x1.00');
Rr = [R.rPI R.rM(:,iA) R.rM(:,iC)];
[~,k] = min(sum(abs(log(Rr ./ median(Rr))), 2));          % jointly nearest each controller's median
yP = R.yPI(:,k); yA = R.Y{iA}(:,k); yC = R.Y{iC}(:,k);
fprintf('[MPC-SUPP] example trial %d: RMSE PI %.2f | LQR AR %.2f | LQR perfect %.2f\n', k, Rr(k,:));
fig = jnFig(W, S.rowH); ax = axes(fig); hold(ax,'on');
yl = [min([yP;yA;yC])-1, max([yP;yA;yC])+4];
patch(ax,[1 3 3 1],[yl(1) yl(1) yl(2) yl(2)],[0.93 0.93 0.93],'EdgeColor','none');
plot(ax,[0 3],R.P.ref*[1 1],'--','Color','k','LineWidth',S.lw_ref);
hPI = plot(ax,tt,yP,'-','Color',PS.col_cl,'LineWidth',S.lw_mean);
hA  = plot(ax,tt,yA,'-','Color',colM,'LineWidth',S.lw_mean);
hC  = plot(ax,tt,yC,'-','Color',colM2,'LineWidth',S.lw_mean);
xlim(ax,[0 3]); ylim(ax,yl);
xlabel(ax,'time from onset (s)'); ylabel(ax,'\DeltaF/F (%)');
lg = legend(ax,[hPI hA hC],{'PI','MPC (AR)','MPC (perfect)'},'Box','off','Location','north','NumColumns',3,'FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_D_example_trial.png'));
fprintf('[MPC-SUPP] 4 panels -> %s\n', figDir);
end

function [xg, med, q1, q3] = ratioCurve(R)
xg = R.P.xGrid; ix = arrayfun(@(x) find(strcmp(R.modes, sprintf('x%.2f',x))), xg);
rat = R.rM(:,ix) ./ R.rPI;
med = median(rat); q1 = prctile(rat,25); q3 = prctile(rat,75);
end
