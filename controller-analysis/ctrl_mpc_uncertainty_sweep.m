function S = ctrl_mpc_uncertainty_sweep(sess)
%CTRL_MPC_UNCERTAINTY_SWEEP  MPC (0.2 s preview) vs PI as each forecaster's error is shrunk toward 0.
%   Fig-3 frame. For model m and scale x, the preview fed to the MPC is truth + x*(forecast_m - truth):
%   x = 1 is the model as-is, x = 0 is a perfect preview. Forecast error (and its variance) scale
%   with x / x^2, so this is "the same model, with less and less uncertainty".
%   Common x-axis: effective error at the 200 ms lead = x * skill_m(200 ms) (error / climatology).
% OUT  data/ctrl_mpc_uncertainty_sweep_<sess>.mat
%      paper/images/supp_mpc/mpc_K_uncertainty_sweep.png (ratio vs x),
%      mpc_L_uncertainty_common_axis.png (ratio vs effective 200 ms error)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
figDir = fullfile(here,'..','paper','images','supp_mpc'); addpath(fullfile(here,'..','utils'));
mods = {'naive','average','theta','ar','arma','dlinear','mlp','lstm'};
xG = [1 0.8 0.6 0.4 0.2 0]; Lp = 7;                                  % 7 samples = 200 ms at 35 Hz
K = load(fullfile(dataDir, sprintf('ctrl_mpc_forecasters_%s.mat', sess)), 'skill','leads_ms','names');
s200 = K.skill(:, abs(K.leads_ms - 200) < 1);                         % lead 7 samples = 200 ms

ratio = nan(numel(mods), numel(xG)); beats = ratio;          % simulation -> descriptive, no CIs/tests
for im = 1:numel(mods)
    fprintf('[UNC] %s\n', mods{im});
    T = ctrl_mpc_lqr('frame','fig3','fcstModel',mods{im},'Lp',Lp,'xGrid',xG, ...
                     'KpGrid',0.10,'KiGrid',1.5,'tag',['_unc_' mods{im}]);
    for ix = 1:numel(xG)
        c = strcmp(T.modes, sprintf('x%.2f', xG(ix)));
        q = T.rM(:,c) ./ T.rPI;
        ratio(im,ix) = median(q); beats(im,ix) = sum(q < 1);
    end
end
sk = s200(cellfun(@(m) find(strcmp(K.names, m)), mods));
S = struct('mods',{mods},'xG',xG,'Lp_ms',Lp*1000/35,'ratio',ratio,'beats',beats,'skill200',sk(:));
save(fullfile(dataDir, sprintf('ctrl_mpc_uncertainty_sweep_%s.mat', sess)), '-struct','S');
disp(array2table(round(ratio,3), 'RowNames', mods, 'VariableNames', compose('x%.1f', xG)));
plotIt(S, figDir);
end

function plotIt(S, figDir)
PS = paperStyle(); St = jnStyle();
fam = containers.Map({'naive','average','theta','ar','arma','dlinear','mlp','lstm'}, {1,1,1,2,2,2,3,3});
cf  = {[.55 .55 .55], [.20 .45 .75], [.15 .60 .30]}; ls = {'-','--',':'};
lbl = containers.Map({'naive','average','theta','ar','arma','dlinear','mlp','lstm'}, ...
                     {'Naive','Average','Theta','AR','ARMA','DLinear','MLP','LSTM'});
for v = 1:2
    fig = jnFig(8.9, St.rowH+0.8); ax = axes(fig); hold(ax,'on');
    plot(ax, [-1 2], [1 1], '-', 'Color', PS.col_cl, 'LineWidth', St.lw_mean);
    cnt = zeros(1,3); h = gobjects(1,numel(S.mods));
    for im = 1:numel(S.mods)
        c = fam(S.mods{im}); cnt(c) = cnt(c)+1;
        if v == 1, x = S.xG; else, x = S.xG * S.skill200(im); end
        h(im) = plot(ax, x, S.ratio(im,:), ls{cnt(c)}, 'Color', cf{c}, 'LineWidth', St.lw_mean, ...
            'Marker','o','MarkerSize',St.marker-1,'MarkerFaceColor',cf{c});
    end
    ylim(ax, [0 1.3]); ylabel(ax, 'MPC error / PI error');
    if v == 1
        xlim(ax, [-0.05 1.05]); set(ax,'XDir','reverse','XTick',0:0.2:1, 'XTickLabel', compose('%d%%', 100*(0:0.2:1)));
        xlabel(ax, 'forecast error kept (% of model''s own)'); fn = 'mpc_K_uncertainty_sweep.png';
    else
        xlim(ax, [-0.05 1.05]); set(ax,'XDir','reverse');
        xlabel(ax, 'forecast error at 200 ms (/ climatology)'); fn = 'mpc_L_uncertainty_common_axis.png';
    end
    text(ax, 1.02, 1.04, 'tuned PI', 'VerticalAlignment','bottom','FontSize',St.fs_annot,'Color',PS.col_cl);
    title(ax, sprintf('%.0f ms preview', S.Lp_ms));
    lg = legend(ax, h, cellfun(@(s) lbl(s), S.mods, 'uni', 0), 'Box','off','Location','eastoutside','FontSize',St.fs_annot);
    lg.ItemTokenSize = [10 6];
    jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, fn));
end
end
