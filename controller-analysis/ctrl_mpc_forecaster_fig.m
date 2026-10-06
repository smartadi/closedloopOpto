function ctrl_mpc_forecaster_fig(sess)
%CTRL_MPC_FORECASTER_FIG  Plots for the forecaster bake-off (ctrl_mpc_forecasters + MPC runs).
%   H  forecast error / climatology vs lead, every model (families coloured as in Lu et al.)
%   I  MPC error / tuned-PI error per forecaster (0.2 s preview), with trials-beating-PI counts
% Inputs: data/ctrl_mpc_forecasters_<sess>.mat, data/ctrl_mpc_forecaster_mpc_<sess>.mat
% OUT  paper/images/supp_mpc/mpc_H_forecast_skill_models.png, mpc_I_mpc_by_forecaster.png
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
figDir = fullfile(here,'..','paper','images','supp_mpc'); addpath(fullfile(here,'..','utils'));
K = load(fullfile(dataDir, sprintf('ctrl_mpc_forecasters_%s.mat', sess)), 'skill','leads_ms','names');
M = load(fullfile(dataDir, sprintf('ctrl_mpc_forecaster_mpc_%s.mat', sess)));      % mods, res=[RMSE ratio nBeat]
PS = paperStyle(); St = jnStyle();
fam = containers.Map({'naive','average','theta','ar','arma','dlinear','mlp','lstm'}, {1,1,1,2,2,2,3,3});
cf  = {[.55 .55 .55], [.20 .45 .75], [.15 .60 .30]};          % baseline / classical / neural
lbl = containers.Map({'naive','average','theta','ar','arma','dlinear','mlp','lstm'}, ...
                     {'Naive','Average','Theta','AR','ARMA','DLinear','MLP','LSTM'});
ls  = {'-','--',':'};

%% H forecast skill vs lead --------------------------------------------------------------
fig = jnFig(8.9, St.rowH+0.6); ax = axes(fig); hold(ax,'on');
xline(ax, 57, ':', 'Color', [.55 .55 .55], 'LineWidth', St.lw_ref);
xline(ax, 86, '-', 'Color', [.85 .85 .85], 'LineWidth', 3);
cnt = zeros(1,3); h = gobjects(1,numel(K.names));
for i = 1:numel(K.names)
    nm = K.names{i}; c = fam(nm); cnt(c) = cnt(c)+1;
    h(i) = plot(ax, K.leads_ms, K.skill(i,:), ls{cnt(c)}, 'Color', cf{c}, 'LineWidth', St.lw_mean, ...
        'Marker','o','MarkerSize',St.marker-1,'MarkerFaceColor',cf{c});
end
text(ax, 55, 0.12, 'loop delay', 'HorizontalAlignment','right', 'FontSize', St.fs_min, 'Color', [.55 .55 .55]);
text(ax, 92, 0.12, 'lead that matters', 'FontSize', St.fs_min, 'Color', [.6 .6 .6]);
set(ax,'XScale','log','XTick',[30 60 100 200 500 1000]); xlim(ax,[25 1100]); ylim(ax,[0 1.4]);
xlabel(ax,'forecast lead (ms)'); ylabel(ax,'forecast error / climatology');
lg = legend(ax, h, cellfun(@(s) lbl(s), K.names, 'uni', 0), 'Box','off','Location','eastoutside','FontSize',St.fs_annot);
lg.ItemTokenSize = [10 6];
jnAxes(ax); paperExport(fig, fullfile(figDir,'mpc_H_forecast_skill_models.png'));

%% I MPC by forecaster -----------------------------------------------------------------------
[r, o] = sort(M.res(:,2)); mods = M.mods(o); nb = M.res(o,3);
fig = jnFig(6.5, St.rowH+0.6); ax = axes(fig); hold(ax,'on');
plot(ax, [0.4 numel(mods)+0.6], [1 1], '-', 'Color', PS.col_cl, 'LineWidth', St.lw_mean);
for i = 1:numel(mods)
    c = cf{fam(mods{i})};
    bar(ax, i, r(i), 0.6, 'FaceColor', c, 'EdgeColor', 'none');
    text(ax, i, r(i)+0.03, sprintf('%d', nb(i)), 'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',St.fs_min);
end
text(ax, 0.6, 1.27, '— tuned PI (= 1)', 'VerticalAlignment','middle','FontSize',St.fs_annot,'Color',PS.col_cl);
set(ax,'XTick',1:numel(mods),'XTickLabel',cellfun(@(s) lbl(s), mods, 'uni', 0),'XTickLabelRotation',35);
xlim(ax,[0.4 numel(mods)+0.6]); ylim(ax,[0.8 1.32]);
ylabel(ax,'MPC error / PI error'); title(ax,'0.2 s preview  (numbers = trials beating PI, of 108)');
jnAxes(ax); paperExport(fig, fullfile(figDir,'mpc_I_mpc_by_forecaster.png'));

%% J Kalman bias-noise sweep (AR forecaster) — values from the 2026-10-05 qb runs (RESEARCH.md)
qb = [1 0.1 0.01 1e-3 0]; rq = [0.988 0.956 0.939 0.942 0.942]; bq = [59 79 81 83 83];
xq = [1 2 3 4 5];
fig = jnFig(5, St.rowH+0.6); ax = axes(fig); hold(ax,'on');
plot(ax, [0.6 5.4], [1 1], '-', 'Color', PS.col_cl, 'LineWidth', St.lw_mean);
plot(ax, xq, rq, '-o', 'Color', cf{2}, 'LineWidth', St.lw_mean, 'MarkerFaceColor', cf{2}, 'MarkerSize', St.marker);
plot(ax, 4, rq(4), 'o', 'MarkerSize', St.marker+3, 'Color', 'k', 'LineWidth', 0.8);
for i = 1:5, text(ax, xq(i), rq(i)+0.008, sprintf('%d', bq(i)), 'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',St.fs_min); end
set(ax,'XTick',xq,'XTickLabel',{'1','0.1','0.01','10^{-3}','0'}); xlim(ax,[0.6 5.4]); ylim(ax,[0.92 1.01]);
xlabel(ax,'bias random-walk variance q_b'); ylabel(ax,'MPC error / PI error');
title(ax,'AR forecast, 0.2 s preview');
jnAxes(ax); paperExport(fig, fullfile(figDir,'mpc_J_kalman_bias_noise.png'));
end
