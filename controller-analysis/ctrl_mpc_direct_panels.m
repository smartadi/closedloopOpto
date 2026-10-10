function ctrl_mpc_direct_panels(sess)
%CTRL_MPC_DIRECT_PANELS  DRAFT supplementary panels for the direct-prediction MPC (user 2026-10-09: "use lambda
%   0.1, draft panels"). The MPC predicts the controlled signal itself with the delay-embedded VARX
%   ([controlled spot, 100 brain spots] + laser; no disturbance proxy) -- mpc_direct.py. Simulation in a
%   VARX "world" driven by each trial's recorded innovations -> descriptive only, no statistics.
%   Inputs (run first):
%     data/mpc_direct_<sess>_lam01.mat        MPCD_RD=0.1 MPCD_ORD=0.1 MPCD_TAG=_lam01 (traces, rmse, G)
%     data/mpc_direct_robust_<sess>_lam01.mat mpc_direct.py robust, MPCD_RD=0.1 (worlds A-D)
%     data/mpc_direct_<sess>_lowrd.mat        rd 0 / .01 / .03 / .1 / 1 ;  data/mpc_direct_<sess>.mat  rd .1 / 1 / 10
%     data/mpc_varx_embed_<sess>.mat           held-out OL prediction R^2 by lead (mpc_varx_embed.py)
%   Panels (paper/images/supp_mpc/, PNG drafts; NOT in MANIFEST until locked):
%     mpcd_0_problem, mpcd_A_laser_response, mpcd_B_prediction, mpcd_C_example_trace, mpcd_D_example_laser,
%     mpcd_E_rmse_scatter, mpcd_F_lambda, mpcd_G_robustness
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','supp_mpc');
PS = paperStyle(); S = jnStyle();
cPI = PS.col_cl; cM = [0.45 0.20 0.60]; cO = [0.80 0.65 0.90]; cR = [0.6 0.6 0.6];
D = load(fullfile(dataDir, sprintf('mpc_direct_%s_lam01.mat', sess)));
names = cellstr(D.names); iPI = find(strcmp(names,'PI')); iM = find(startsWith(names,'MPC')); iO = find(startsWith(names,'ORACLE'));
Fs = double(D.Fs); N = size(D.Y,1); tt = (0:N-1).'/Fs; ref = double(D.ref);
rPI = D.rmse(:,iPI); rM = D.rmse(:,iM); rO = D.rmse(:,iO); q = rM ./ rPI;
fprintf('[MPCD-P] lambda 0.1: MPC/PI %.3f (%d/%d) | oracle %.3f | PI Kp %g Ki %g\n', median(q), sum(q<1), numel(q), median(rO./rPI), D.Kp, D.Ki);

%% 0 -- the optimisation problem
fig = jnFig(9.4, 4.0); ax = axes(fig,'Position',[0 0 1 1]); axis(ax,'off'); xlim(ax,[0 1]); ylim(ax,[0 1]); fs = S.fs_annot + 1;
L = { ...
 '$\displaystyle \min_{u_{t+1},\dots,u_{t+H}} \; \sum_{j=1}^{H} \big(\hat y_{t+j}-r\big)^2 \;+\; \rho \sum_{j=1}^{H} \big(u_{t+j}-u_{ss}\big)^2 \;+\; \lambda \sum_{j=1}^{H} \big(\Delta u_{t+j}\big)^2$', ...
 '$\mathrm{s.t.}\quad \hat{\mathbf z}_{k+1} = \sum_{i=0}^{9} W_i\,\hat{\mathbf z}_{k-i} + \sum_{i=0}^{34} b_i\,u_{k+1-i} + c, \qquad \hat y_k = [\hat{\mathbf z}_k]_1, \qquad 0 \le u_k \le u_{\max}$', ...
 '$\mathbf z$ = [controlled spot, 100 brain spots] (VARX, fitted on spontaneous + OL + CL data)', ...
 '$H = 1\,\mathrm{s}\;(35)$, \ $r=-5\%$, \ $\rho=10^{-3}$, \ $\lambda = 0.1$', ...
 'receding horizon: apply $u_{t+1}$, observe $\mathbf z_{t+1}$, re-solve every frame (35 Hz)'};
y = [0.84 0.62 0.42 0.24 0.07];
for i = 1:numel(L), text(ax, 0.02, y(i), L{i}, 'Interpreter','latex', 'FontSize', fs + (i==1)*0.5, 'VerticalAlignment','middle'); end
ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_0_problem.png')); close(fig);

%% A -- laser -> controlled-spot response learned by the VARX
fig = jnFig(6, 4); ax = axes(fig); hold(ax,'on');
g = D.G(:,1); lag = (1:numel(g)).'*1000/Fs;
plot(ax, [0 lag(end)], [0 0], '-', 'Color', cR, 'LineWidth', S.lw_ref);
plot(ax, lag, g, '-o', 'Color', 'k', 'LineWidth', S.lw_mean, 'MarkerSize', 2, 'MarkerFaceColor','k');
plot(ax, lag, cumsum(g), '-', 'Color', cM, 'LineWidth', S.lw_mean);
xlabel(ax, 'time after laser pulse (ms)'); ylabel(ax, '\DeltaF/F (%) per laser unit');
lg = legend(ax, {'','impulse response','cumulative (step)'}, 'Box','off','Location','east','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
xlim(ax, [0 1000]); jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_A_laser_response.png')); close(fig);

%% B -- prediction quality of the VARX by lead (held-out OL trials)
V = load(fullfile(dataDir, sprintf('mpc_varx_embed_%s.mat', sess)));
fig = jnFig(6, 4); ax = axes(fig); hold(ax,'on');
plot(ax, V.lead_ms, V.R2, '-o', 'Color', cM, 'LineWidth', S.lw_mean, 'MarkerSize', S.marker, 'MarkerFaceColor', cM);
plot(ax, V.lead_ms, V.R2_persist, '-o', 'Color', cR, 'LineWidth', S.lw_mean, 'MarkerSize', S.marker, 'MarkerFaceColor', cR);
set(ax, 'XScale','log'); xlim(ax, [25 1100]); ylim(ax, [-0.1 1]); plot(ax, [25 1100], [0 0], '-', 'Color', cR, 'LineWidth', S.lw_ref);
xlabel(ax, 'prediction lead (ms)'); ylabel(ax, 'R^2 (held-out OL trials)');
lg = legend(ax, {'VARX','last value'}, 'Box','off','Location','southwest','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_B_prediction.png')); close(fig);

%% C, D -- example trial (median MPC-PI difference)
[~, o] = sort(rM - rPI); k = o(round(0.5*numel(o)));
fig = jnFig(6, 4); ax = axes(fig); hold(ax,'on');
plot(ax, [0 3], [ref ref], '--', 'Color', 'k', 'LineWidth', S.lw_ref);
h1 = plot(ax, tt, D.Y(:,k,iPI), '-', 'Color', cPI, 'LineWidth', S.lw_mean);
h2 = plot(ax, tt, D.Y(:,k,iM), '-', 'Color', cM, 'LineWidth', S.lw_mean);
h3 = plot(ax, tt, D.Y(:,k,iO), '-', 'Color', cO, 'LineWidth', S.lw_mean);
xlabel(ax, 'time from onset (s)'); ylabel(ax, '\DeltaF/F (%)'); xlim(ax, [0 3]);
lg = legend(ax, [h1 h2 h3], {sprintf('PI (%.2f)', rPI(k)), sprintf('MPC (%.2f)', rM(k)), sprintf('MPC, perfect prediction (%.2f)', rO(k))}, ...
    'Box','off','Location','northeast','FontSize',S.fs_annot); lg.ItemTokenSize = S.itemtoken;
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_C_example_trace.png')); close(fig);
fig = jnFig(6, 4); ax = axes(fig); hold(ax,'on');
plot(ax, tt, D.U(:,k,iPI), '-', 'Color', cPI, 'LineWidth', PS.lw_inp);
plot(ax, tt, D.U(:,k,iM), '-', 'Color', cM, 'LineWidth', PS.lw_inp);
plot(ax, tt, D.U(:,k,iO), '-', 'Color', cO, 'LineWidth', PS.lw_inp);
xlabel(ax, 'time from onset (s)'); ylabel(ax, 'laser command'); xlim(ax, [0 3]); ylim(ax, [0 2.8]);
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_D_example_laser.png')); close(fig);
fprintf('[MPCD-P] example: CL trial %d (median of MPC-PI)\n', k);

%% E -- per-trial RMSE, MPC vs PI
fig = jnFig(4.5, 4.5); ax = axes(fig); hold(ax,'on');
mx = ceil(max([rPI; rM])*2)/2;
plot(ax, [0 mx], [0 mx], '-', 'Color', cR, 'LineWidth', S.lw_ref);
scatter(ax, rPI, rM, 6, cM, 'filled', 'MarkerFaceAlpha', 0.6);
axis(ax, 'square'); xlim(ax, [0 mx]); ylim(ax, [0 mx]);
xlabel(ax, 'PI RMSE (%\DeltaF/F)'); ylabel(ax, 'MPC RMSE (%\DeltaF/F)');
text(ax, 0.05*mx, 0.92*mx, sprintf('%d / %d trials below', sum(q<1), numel(q)), 'FontSize', S.fs_annot, 'Color', cM);
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_E_rmse_scatter.png')); close(fig);

%% F -- input smoothness lambda vs error (world A)
Lw = load(fullfile(dataDir, sprintf('mpc_direct_%s_lowrd.mat', sess)));
Hi = load(fullfile(dataDir, sprintf('mpc_direct_%s.mat', sess)));
[lam, rat] = deal([]);
for SRC = {Lw, Hi}
    s = SRC{1}; nm = cellstr(s.names); p = s.rmse(:, strcmp(nm,'PI'));
    for i = find(startsWith(nm,'MPC rd='))
        l = sscanf(nm{i}, 'MPC rd=%f');
        if ~ismember(l, lam), lam(end+1) = l; rat(end+1) = median(s.rmse(:,i)./p); end %#ok<AGROW>
    end
end
[lam, o] = sort(lam); rat = rat(o); x = lam; x(x == 0) = 3e-3;             % plot lambda = 0 at the left edge
fig = jnFig(6, 4); ax = axes(fig); hold(ax,'on');
plot(ax, [2e-3 20], [1 1], '-', 'Color', cPI, 'LineWidth', S.lw_ref);
plot(ax, x, rat, '-o', 'Color', cM, 'LineWidth', S.lw_mean, 'MarkerSize', S.marker, 'MarkerFaceColor', cM);
i1 = find(lam == 0.1); plot(ax, x(i1), rat(i1), 'o', 'MarkerSize', S.marker+3, 'Color', 'k', 'LineWidth', 0.75);
set(ax, 'XScale','log', 'XTick', [3e-3 1e-2 1e-1 1 10], 'XTickLabel', {'0','0.01','0.1','1','10'}); xlim(ax, [2e-3 20]); ylim(ax, [0.6 1.05]);
xlabel(ax, 'input smoothness \lambda'); ylabel(ax, 'MPC / PI error (median)');
text(ax, x(i1)*1.3, rat(i1)-0.03, 'used', 'FontSize', S.fs_annot);
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_F_lambda.png')); close(fig);

%% G -- robustness of the comparison to the world model (lambda 0.1)
R = load(fullfile(dataDir, sprintf('mpc_direct_robust_%s_lam01.mat', sess)));
mods = cellstr(R.models); jm = find(startsWith(mods, 'MPC'));
lab = {'same model','different model','+20% gain error','both'};
fig = jnFig(6, 4); ax = axes(fig); hold(ax,'on');
b = bar(ax, R.ratio(:, jm), 0.6, 'FaceColor', cM, 'EdgeColor', 'none');
plot(ax, [0.4 4.6], [1 1], '-', 'Color', cPI, 'LineWidth', S.lw_ref);
for i = 1:size(R.ratio,1), text(ax, i, R.ratio(i,jm)+0.07, sprintf('%.2f', R.ratio(i,jm)), 'HorizontalAlignment','center','FontSize',S.fs_annot); end
set(ax, 'XTick', 1:4, 'XTickLabel', lab); xtickangle(ax, 25); ylim(ax, [0 1.1]); xlim(ax, [0.4 4.6]);
ylabel(ax, 'MPC / PI error (median)'); xlabel(ax, 'simulated brain');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_G_robustness.png')); close(fig); %#ok<NASGU>
fprintf('[MPCD-P] panels -> %s\n', figDir);
end
