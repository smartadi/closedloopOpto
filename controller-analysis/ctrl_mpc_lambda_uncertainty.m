function S = ctrl_mpc_lambda_uncertainty(sess)
%CTRL_MPC_LAMBDA_UNCERTAINTY  Effect of the input-smoothness weight lambda (P.rd, penalty on (Delta u)^2)
%   on MPC performance as forecast uncertainty shrinks. Fig-3 frame, AR forecaster, 200 ms preview.
%   Preview = truth + x*(AR forecast - truth); x = 1 the real AR forecast, x = 0 a perfect preview.
%   Reports MPC error / tuned-PI error (PI is fixed, Kp=0.10 Ki=1.5) and command roughness
%   (median per-trial total variation of u, relative to the recorded PI command's).
%   Simulation -> descriptive only, no tests.
% OUT  data/ctrl_mpc_lambda_uncertainty_<sess>.mat
%      paper/images/supp_mpc/mpc_M_lambda_error.png, mpc_N_lambda_roughness.png
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
figDir = fullfile(here,'..','paper','images','supp_mpc'); addpath(fullfile(here,'..','utils'));
lam = [0 0.1 1 10 100]; xG = [1 0.8 0.6 0.4 0.2 0]; Lp = 7;
ratio = nan(numel(lam), numel(xG)); rough = ratio;
for il = 1:numel(lam)
    fprintf('[LAM] rd = %g\n', lam(il));
    T = ctrl_mpc_lqr('frame','fig3','fcstModel','ar','Lp',Lp,'rd',lam(il),'xGrid',xG, ...
                     'KpGrid',0.10,'KiGrid',1.5,'tag','_lam');
    tvPI = median(sum(abs(diff(T.uPI,1,1)),1));
    for ix = 1:numel(xG)
        c = strcmp(T.modes, sprintf('x%.2f', xG(ix)));
        ratio(il,ix) = median(T.rM(:,c) ./ T.rPI);
        rough(il,ix) = median(sum(abs(diff(T.U{c},1,1)),1)) / tvPI;
    end
end
S = struct('lam',lam,'xG',xG,'Lp_ms',Lp*1000/35,'ratio',ratio,'rough',rough);
save(fullfile(dataDir, sprintf('ctrl_mpc_lambda_uncertainty_%s.mat', sess)), '-struct','S');
disp(array2table(round(ratio,3), 'RowNames', compose('rd=%g',lam), 'VariableNames', compose('x%.1f', xG)));
disp(array2table(round(rough,2), 'RowNames', compose('rd=%g',lam), 'VariableNames', compose('x%.1f', xG)));
plotIt(S, figDir);
end

function plotIt(S, figDir)
PS = paperStyle(); St = jnStyle();
cm = flipud(parula(numel(S.lam)+1)); cm = cm(2:end,:);              % dark = smooth (large lambda)
cm = cm(end:-1:1,:);
Ys = {S.ratio, S.rough}; yl = {'MPC error / PI error', 'command roughness / PI'};
fn = {'mpc_M_lambda_error.png', 'mpc_N_lambda_roughness.png'};
for v = 1:2
    fig = jnFig(7.4, St.rowH+0.8); ax = axes(fig); hold(ax,'on');
    plot(ax, [-1 2], [1 1], '-', 'Color', PS.col_cl, 'LineWidth', St.lw_mean);
    h = gobjects(1,numel(S.lam));
    for il = 1:numel(S.lam)
        h(il) = plot(ax, S.xG, Ys{v}(il,:), '-o', 'Color', cm(il,:), 'LineWidth', St.lw_mean, ...
            'MarkerSize', St.marker-1, 'MarkerFaceColor', cm(il,:));
    end
    xlim(ax, [-0.05 1.05]); set(ax,'XDir','reverse','XTick',0:0.2:1,'XTickLabel',compose('%d%%',100*(0:0.2:1)));
    if v == 2, set(ax,'YScale','log'); end
    xlabel(ax, 'AR forecast error kept'); ylabel(ax, yl{v});
    title(ax, sprintf('AR forecast, %.0f ms preview', S.Lp_ms));
    lg = legend(ax, h, compose('\\lambda = %g', S.lam), 'Box','off','Location','eastoutside','FontSize',St.fs_annot);
    lg.ItemTokenSize = [10 6];
    jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, fn{v}));
end
end
