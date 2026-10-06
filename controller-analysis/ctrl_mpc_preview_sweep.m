function S = ctrl_mpc_preview_sweep(sess)
%CTRL_MPC_PREVIEW_SWEEP  Preview window allowed (0..1 s) vs preview-LQR performance (user 2026-10-05).
%   Control horizon fixed at 1 s (ctrl_mpc_lqr P.Hp); only the first Lp samples of the disturbance
%   forecast are used, the last previewed value is held beyond. Lp = 0 = no preview. Forecasts:
%   perfect, half the AR error, AR. PI fixed at the tuned gains (Kp 0.15, Ki 0.50), measured gain spread.
%   Same trials / gain draws / PI as the main ctrl_mpc_lqr run (paired).
% OUT  data/ctrl_mpc_preview_sweep_<sess>.mat, paper/images/supp_mpc/mpc_E_preview_window.png
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
figDir = fullfile(here,'..','paper','images','supp_mpc'); addpath(fullfile(here,'..','utils'));
LpS = [0 1 2 3 4 5 7 10 14 17];                      % samples, capped at 500 ms (user 2026-10-05; 1-s
                                                     % run saturated by ~100 ms, flat 0.4-1 s)
xG  = [0 0.5 1];
rat = nan(numel(LpS), numel(xG)); q1 = rat; q3 = rat;
for i = 1:numel(LpS)
    T = ctrl_mpc_lqr('Lp',LpS(i),'xGrid',xG,'KpGrid',0.15,'KiGrid',0.5,'tag','_Lp');
    for j = 1:numel(xG)
        r = T.rM(:, strcmp(T.modes, sprintf('x%.2f',xG(j)))) ./ T.rPI;
        rat(i,j) = median(r); q1(i,j) = prctile(r,25); q3(i,j) = prctile(r,75);
    end
end
delete(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_Lp.mat', sess)));
S = struct('Lp_s',LpS/35,'xG',xG,'rat',rat,'q1',q1,'q3',q3);
save(fullfile(dataDir, sprintf('ctrl_mpc_preview_sweep_%s.mat', sess)), '-struct','S');

%% figure -------------------------------------------------------------------------------
PS = paperStyle(); St = jnStyle(); cols = [0.45 0.20 0.60; 0.62 0.45 0.75; 0.80 0.65 0.90];
fig = jnFig(jnPanelWidth('double',3), St.rowH); ax = axes(fig); hold(ax,'on');
plot(ax,[0 0.5],[1 1],'-','Color',PS.col_cl,'LineWidth',St.lw_mean);
xline(ax, 2/35, ':','Color',[.55 .55 .55],'LineWidth',St.lw_ref);
h = gobjects(1,numel(xG));
for j = 1:numel(xG)
    fill(ax,[S.Lp_s fliplr(S.Lp_s)],[q1(:,j).' fliplr(q3(:,j).')],cols(j,:),'FaceAlpha',0.15,'EdgeColor','none');
    h(j) = plot(ax,S.Lp_s,rat(:,j),'-o','Color',cols(j,:),'MarkerFaceColor',cols(j,:),'MarkerSize',St.marker,'LineWidth',St.lw_mean);
end
text(ax,0.49,1.03,'tuned PI','HorizontalAlignment','right','VerticalAlignment','bottom','FontSize',St.fs_annot,'Color',PS.col_cl);
text(ax,2/35+0.015,0.08,'loop delay','FontSize',St.fs_annot,'Color',[.55 .55 .55]);
xlim(ax,[0 0.5]); ylim(ax,[0 1.3]);
xlabel(ax,'preview window (s)'); ylabel(ax,'error / PI error');
labs = {'perfect forecast','half AR error','AR forecast'};       % direct labels under each curve
for j = 1:numel(xG)
    text(ax, 0.3, rat(end,j)-0.04, labs{j}, 'VerticalAlignment','top','FontSize',St.fs_annot,'Color',cols(j,:));
end
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_E_preview_window.png'));
fprintf('[PREVIEW] Lp(s): %s\n', mat2str(S.Lp_s,2));
for j=1:numel(xG), fprintf('[PREVIEW] x=%.2f: %s\n', xG(j), mat2str(rat(:,j).',2)); end
end
