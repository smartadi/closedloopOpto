function ctrl_mpc_plant_fig(sess)
%CTRL_MPC_PLANT_FIG  Panel A in the Fig-3 frame: recorded OL trial-average response (rig online dF/F)
%   vs the 2-state + 57 ms delay model identified on it (ctrl_mpc_lqr 'fig3' run), with the OL command.
%   Rebuilds u_OL / y_OL exactly as ctrl_mpc_lqr's fig3 loader does.
% OUT  paper/images/supp_mpc/mpc_A_plant_fit.png (replaces the old svd-frame version)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data');
figDir = fullfile(here,'..','paper','images','supp_mpc'); addpath(genpath(fullfile(here,'..','utils')));
R = load(fullfile(dataDir, sprintf('ctrl_mpc_lqr_%s_fig3.mat', sess)), 'A','B','C','P','fitOL','poles');
Z = load(fullfile(here,'..','data',R.P.rawFile)); dz = Z.d; Dz = Z.data;
[uAmp,~] = cp_laser_amplitude(dz.inpVals, dz.inpTime);
tb = dz.timeBlue(:); yfull = Dz.dFk(:); pre = 35; N = 105; rel = -pre:N;
on = arrayfun(@(t) find(tb >= t, 1), dz.stimStarts(:)); nc = Dz.nc(:);
Yol = cell2mat(arrayfun(@(i) yfull(on(i)+rel).', nc, 'uni', 0));
Uol = cell2mat(arrayfun(@(i) interp1(dz.inpTime, uAmp, tb(on(i)+rel), 'linear', 0).', nc, 'uni', 0));
u = mean(Uol,1).' - mean(mean(Uol(:,1:pre))); y = mean(Yol,1).' - mean(mean(Yol(:,1:pre)));
Fs = R.P.Fs; t = rel(:)/Fs; yfit = lsim(ss(R.A,R.B,R.C,0,1/Fs), u);
tau = -1000/Fs./log(max(R.poles,eps));

PS = paperStyle(); St = jnStyle();
fig = jnFig(8.9, St.rowH+0.4);
ax = axes(fig); hold(ax,'on'); yyaxis(ax,'right');
plot(ax, t, u, '-', 'Color', [.6 .6 .6], 'LineWidth', PS.lw_inp); ylabel(ax,'laser command'); ax.YColor = [.5 .5 .5];
yl = ylim(ax); ylim(ax, [yl(1) yl(2)*2.2]);
yyaxis(ax,'left');
hD = plot(ax, t, y, '-', 'Color', PS.col_ol, 'LineWidth', St.lw_mean);
hF = plot(ax, t, yfit, '--', 'Color', 'k', 'LineWidth', St.lw_fit); ax.YColor = 'k';
xlim(ax,[-0.5 3]); xlabel(ax,'time from onset (s)'); ylabel(ax,'\DeltaF/F (%)');
lg = legend(ax,[hD hF],{sprintf('OL trial average (n = %d)', numel(nc)), ...
    sprintf('model: \\tau = %.0f ms, %.0f ms delay (fit %.0f%%)', max(tau), 1000*R.P.delay/Fs, R.fitOL)}, ...
    'Box','off','Location','northoutside','FontSize',St.fs_annot); lg.ItemTokenSize = St.itemtoken;
jnAxes(ax); paperExport(fig, fullfile(figDir,'mpc_A_plant_fit.png'));
fprintf('[PLANT] poles %s | tau %s ms | fit %.0f%% | n OL %d\n', mat2str(R.poles,3), mat2str(round(tau)), R.fitOL, numel(nc));
end
