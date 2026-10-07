function S = ctrl_mpc_smooth_tradeoff(sess)
%CTRL_MPC_SMOOTH_TRADEOFF  Error vs laser-command roughness as the MPC move penalty rd is swept
%   (cost sum (y-ref)^2 + r (u-uss)^2 + rd (Delta u)^2), Fig-3-frame replay of the recorded CL trials.
%   Roughness = median per-trial total variation of the command over 0-3 s. Perfect vs AR preview,
%   laser bounded [0, u_max]. Reference points: tuned-PI replay and the recorded rig command.
% OUT  data/ctrl_mpc_smooth_tradeoff_<sess>.mat, paper/images/supp_mpc/mpc_F_smooth_tradeoff.png
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
figDir = fullfile(here,'..','paper','images','supp_mpc'); addpath(fullfile(here,'..','utils'));
rdG = [0 0.1 1 10 100 1000];
tv  = @(U) median(sum(abs(diff(U,1,1)),1));
[eP, eA, tP, tA] = deal(nan(size(rdG)));
for i = 1:numel(rdG)
    T = ctrl_mpc_lqr('frame','fig3','rd',rdG(i),'xGrid',[0 1],'KpGrid',0.10,'KiGrid',1.5,'tag','_smooth');
    iC = strcmp(T.modes,'x0.00'); iA = strcmp(T.modes,'x1.00');
    eP(i) = median(T.rM(:,iC)./T.rPI); eA(i) = median(T.rM(:,iA)./T.rPI);
    tP(i) = tv(T.U{iC}); tA(i) = tv(T.U{iA});
end
tvPI = tv(T.uPI); tvRec = tv(T.recUCL); eRec = median(T.realCL./T.rPI);
delete(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_smooth.mat', sess)));
S = struct('rd',rdG,'eP',eP,'eA',eA,'tvP',tP,'tvA',tA,'tvPI',tvPI,'tvRec',tvRec,'eRec',eRec);
save(fullfile(dataDir, sprintf('ctrl_mpc_smooth_tradeoff_%s.mat', sess)), '-struct','S');

PS = paperStyle(); St = jnStyle(); cP = [0.80 0.65 0.90]; cA = [0.45 0.20 0.60];
fig = jnFig(8.9, St.rowH+0.4); ax = axes(fig); hold(ax,'on');
hP = plot(ax, tP, eP, '-o', 'Color', cP, 'MarkerFaceColor', cP, 'MarkerSize', St.marker, 'LineWidth', St.lw_mean);
hA = plot(ax, tA, eA, '-o', 'Color', cA, 'MarkerFaceColor', cA, 'MarkerSize', St.marker, 'LineWidth', St.lw_mean);
for i = 1:numel(rdG)       % rd value next to each perfect-preview point (skip the overlapping 0 / 0.1 pair)
    if rdG(i) == 0.1, continue; end
    text(ax, tP(i), eP(i)-0.04, sprintf('%g', rdG(i)), 'FontSize', St.fs_min, 'Color', cP*0.75, 'VerticalAlignment','top','HorizontalAlignment','center');
end
hPI = plot(ax, tvPI, 1, 's', 'Color', PS.col_cl, 'MarkerFaceColor', PS.col_cl, 'MarkerSize', St.marker+1);
hR  = plot(ax, tvRec, eRec, 'd', 'Color', PS.col_cl, 'MarkerFaceColor', 'w', 'MarkerSize', St.marker+1);
text(ax, 1.5, 1.22, 'labels on points: \lambda_{\Deltau}', 'FontSize', St.fs_min, 'Color', cP*0.75);
set(ax,'XScale','log','XTick',[1 2 5 10 20],'XTickLabel',{'1','2','5','10','20'}); xlim(ax,[1 30]); ylim(ax,[0 1.3]);
lg = legend(ax, [hP hA hPI hR], {'MPC, perfect preview','MPC, AR preview','tuned PI','recorded CL'}, ...
    'Box','off','Location','eastoutside','FontSize',St.fs_annot); lg.ItemTokenSize = St.itemtoken;
xlabel(ax,'laser command roughness (total variation, 0-3 s)'); ylabel(ax,'error / PI error');
jnAxes(ax);
paperExport(fig, fullfile(figDir,'mpc_F_smooth_tradeoff.png'));
fprintf('[SMOOTH] rd      %s\n[SMOOTH] perf e %s tv %s\n[SMOOTH] AR   e %s tv %s\n[SMOOTH] PI tv %.1f | recorded CL tv %.1f e %.2f\n', ...
    mat2str(rdG), mat2str(eP,2), mat2str(tP,2), mat2str(eA,2), mat2str(tA,2), tvPI, tvRec, eRec);
end
