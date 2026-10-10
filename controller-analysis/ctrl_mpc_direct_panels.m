function ctrl_mpc_direct_panels(sess)
%CTRL_MPC_DIRECT_PANELS  Supplementary panels, direct-prediction MPC (lambda = 0.1), JNeurosci rule-book style:
%   grid panel sizes (4.13 x 3.3 cm = 4-across, 8.43 cm = 2-across), Arial 6/7 pt, direct labels instead of
%   legends, minimal ticks. The MPC predicts the controlled signal itself with the delay-embedded VARX
%   ([controlled spot, 100 brain spots] + laser; no disturbance proxy) -- mpc_direct.py. Simulation in a VARX
%   world driven by each trial's recorded innovations -> descriptive only, no statistics.
%   PI = the rig's RECORDED CL trial (the world reproduces it exactly under the recorded laser).
%   Inputs (run first): data/mpc_direct_<sess>_lam01.mat (MPCD_RD=0.1 MPCD_ORD=0.1 MPCD_TAG=_lam01, incl. the
%   one-step snapshot), data/mpc_direct_robust_<sess>_lam01.mat, data/mpc_direct_<sess>_lowrd.mat,
%   data/mpc_direct_<sess>.mat, data/mpc_varx_embed_<sess>.mat.
%   OUT paper/images/supp_mpc/mpcd_*.png (drafts; not in MANIFEST until locked)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','supp_mpc');
PS = paperStyle(); S = jnStyle();
C.pi = PS.col_cl; C.m = [0.45 0.20 0.60]; C.o = [0.78 0.66 0.90]; C.g = [0.62 0.62 0.62]; C.k = [0 0 0];
W1 = 4.13; W2 = 8.43; H = 3.3;
D = load(fullfile(dataDir, sprintf('mpc_direct_%s_lam01.mat', sess)));
nm = cellstr(D.names); iPI = find(strcmp(nm,'PI')); iM = find(startsWith(nm,'MPC')); iO = find(startsWith(nm,'ORACLE'));
Fs = double(D.Fs); N = size(D.Y,1); tt = (0:N-1).'/Fs; ref = double(D.ref);
rPI = D.rmse(:,iPI); rM = D.rmse(:,iM); rO = D.rmse(:,iO); q = rM./rPI; k = double(D.snap_k);
fprintf('[MPCD-P] MPC/PI(recorded) %.3f (%d/%d) | perfect prediction %.3f | example trial %d\n', ...
    median(q), sum(q<1), numel(q), median(rO./rPI), k);
old = dir(fullfile(figDir, 'mpcd_0_problem.*')); for i = 1:numel(old), delete(fullfile(figDir, old(i).name)); end  % superseded by the schematic

%% 0 -- how the MPC works: one real step (trial k, 1.5 s after onset)
fig = jnFig(W2, 4.4);
ax1 = axes(fig, 'Units','centimeters', 'Position', [0.9 2.0 W2-1.95 1.75]); hold(ax1,'on');
ax2 = axes(fig, 'Units','centimeters', 'Position', [0.9 0.8 W2-1.95 0.95]); hold(ax2,'on');
yp = D.snap_ypast(:); up = D.snap_upast(:); np_ = min(numel(yp), 36);
tp = (-(np_-1):0).'/Fs; yp = yp(end-np_+1:end); up = up(end-np_+1:end);
tf = (1:numel(D.snap_yhat)).'/Fs; st = double(D.snap_t);
ytrue = D.snap_ytrue(:); yfut = ytrue(st+2 : min(st+1+numel(tf), numel(ytrue))); tfa = tf(1:numel(yfut));
for a = [ax1 ax2], patch(a, [0 1 1 0], [-100 -100 100 100], C.m, 'FaceAlpha', 0.07, 'EdgeColor','none'); end
plot(ax1, [-1 1], [ref ref], ':', 'Color', C.k, 'LineWidth', S.lw_ref);
plot(ax1, tfa, yfut, '-', 'Color', C.g, 'LineWidth', S.lw_ind);
plot(ax1, tp, yp, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax1, tf, D.snap_yhat(:), '--', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax1, 0, yp(end), 'o', 'MarkerSize', 3, 'MarkerFaceColor', C.m, 'MarkerEdgeColor', 'w', 'LineWidth', 0.4);
yl = [min([yp; D.snap_yhat(:); yfut; ref]) max([yp; D.snap_yhat(:); yfut; ref])]; yl = yl + [-0.6 0.6];
ylim(ax1, yl); xlim(ax1, [-1 1]); set(ax1, 'XTick', [], 'XColor','none'); ylabel(ax1, '\DeltaF/F (%)');
text(ax1, 0.03, yl(2), 'now', 'FontSize', S.fs_annot, 'VerticalAlignment','top', 'Color', C.m);
text(ax1, 0.97, yl(2), 'predicted 1 s ahead', 'FontSize', S.fs_annot, 'VerticalAlignment','top', 'HorizontalAlignment','right', 'Color', C.m);
text(ax1, 1.03, ref, 'target', 'FontSize', S.fs_annot, 'VerticalAlignment','middle', 'Clipping','off');
text(ax1, 1.03, yfut(end), 'actual', 'FontSize', S.fs_annot, 'Color', C.g, 'VerticalAlignment','middle', 'Clipping','off');
stairs(ax2, tp, up, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
stairs(ax2, [0; tf], [up(end); D.snap_U(:)], '--', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax2, tf(1), D.snap_U(1), 'o', 'MarkerSize', 3, 'MarkerFaceColor', C.m, 'MarkerEdgeColor','w', 'LineWidth', 0.4);
text(ax2, 0.97, 2.9, 'planned laser', 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top', 'Color', C.m);
text(ax2, tf(1)+0.03, D.snap_U(1), 'apply 1st move', 'FontSize', S.fs_annot, 'VerticalAlignment','bottom', 'Color', C.m);
ylim(ax2, [0 3]); xlim(ax2, [-1 1]); set(ax2, 'YTick', [0 2.5]); ylabel(ax2, 'laser');
xlabel(ax2, 'time from now (s)'); set(ax2, 'XTick', [-1 0 1]);
yh = char(375);                                                     % y-hat in Arial
annotation(fig, 'textbox', [0 0.86 1 0.14], 'EdgeColor','none', 'Interpreter','tex', 'FontName', S.font, ...
    'String', ['min  \Sigma(' yh ' - target)^2 + \lambda\Sigma(\Deltau)^2,    ' yh ' = VARX(brain, laser)'], ...
    'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','middle', 'Color', C.m);
jnAxes(ax1); jnAxes(ax2); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_0_schematic.png')); close(fig);

%% A -- laser -> controlled-spot response the model learned
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
g = D.G(:,1); lag = (1:numel(g)).'*1000/Fs;
plot(ax, [0 1000], [0 0], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
plot(ax, lag, g, '-', 'Color', C.g, 'LineWidth', S.lw_ind+0.2);
plot(ax, lag, cumsum(g), '-', 'Color', C.m, 'LineWidth', S.lw_mean);
text(ax, 990, sum(g), sprintf('step %.1f', sum(g)), 'Color', C.m, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(ax, lag(3)+40, min(g), 'pulse', 'Color', C.g, 'FontSize', S.fs_annot, 'VerticalAlignment','middle');
xlim(ax, [0 1000]); ylim(ax, [-4 0.3]); set(ax, 'XTick', [0 500 1000], 'YTick', [-4 -2 0]);
xlabel(ax, 'time after laser (ms)'); ylabel(ax, '\DeltaF/F per unit (%)');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_A_laser_response.png')); close(fig);

%% B -- how well the model predicts the signal (held-out OL trials)
V = load(fullfile(dataDir, sprintf('mpc_varx_embed_%s.mat', sess)));
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
plot(ax, [25 1100], [0 0], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
plot(ax, V.lead_ms, V.R2_persist, '-', 'Color', C.g, 'LineWidth', S.lw_mean);
plot(ax, V.lead_ms, V.R2, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax, V.lead_ms, V.R2, 'o', 'MarkerSize', 2.5, 'MarkerFaceColor', C.m, 'MarkerEdgeColor', 'none');
text(ax, 300, 0.42, 'model', 'Color', C.m, 'FontSize', S.fs_annot);
text(ax, 120, 0.22, 'last value', 'Color', C.g, 'FontSize', S.fs_annot, 'HorizontalAlignment','right');
set(ax, 'XScale','log', 'XTick', [30 100 300 1000], 'XTickLabel', {'30','100','300','1000'}, 'YTick', [0 0.5 1]);
xlim(ax, [25 1100]); ylim(ax, [-0.1 1]); xlabel(ax, 'prediction lead (ms)'); ylabel(ax, 'R^2');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_B_prediction.png')); close(fig);

%% C, D -- example trial (median MPC - PI)
fig = jnFig(W2, 2.7); ax = axes(fig, 'Units','centimeters', 'Position', [1.0 0.3 W2-1.3 2.2]); hold(ax,'on');   % same x-extent as D
plot(ax, [0 3], [ref ref], ':', 'Color', C.k, 'LineWidth', S.lw_ref);
plot(ax, tt, D.Y(:,k,iPI), '-', 'Color', C.pi, 'LineWidth', S.lw_mean);
plot(ax, tt, D.Y(:,k,iM), '-', 'Color', C.m, 'LineWidth', S.lw_mean);
xlim(ax, [0 3]); set(ax, 'XTick', [0 1 2 3], 'XTickLabel', []); ylabel(ax, '\DeltaF/F (%)');
yl = ylim(ax); text(ax, 2.98, yl(2), sprintf('PI (recorded)  %.2f', rPI(k)), 'Color', C.pi, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(ax, 2.98, yl(2) - 0.14*diff(yl), sprintf('MPC  %.2f', rM(k)), 'Color', C.m, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_C_example_trace.png')); close(fig);
fig = jnFig(W2, 2.0); ax = axes(fig, 'Units','centimeters', 'Position', [1.0 0.8 W2-1.3 1.05]); hold(ax,'on');
stairs(ax, tt, D.U(:,k,iPI), '-', 'Color', C.pi, 'LineWidth', PS.lw_inp);
stairs(ax, tt, D.U(:,k,iM), '-', 'Color', C.m, 'LineWidth', PS.lw_inp);
xlim(ax, [0 3]); ylim(ax, [0 2.9]); set(ax, 'XTick', [0 1 2 3], 'YTick', [0 2.5]);
xlabel(ax, 'time from onset (s)'); ylabel(ax, 'laser');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_D_example_laser.png')); close(fig);

%% E -- every trial: MPC vs PI error
fig = jnFig(H, H); ax = axes(fig); hold(ax,'on');
mx = ceil(max([rPI; rM]));
plot(ax, [0 mx], [0 mx], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
scatter(ax, rPI, rM, 5, C.m, 'filled', 'MarkerFaceAlpha', 0.55);
axis(ax, 'square'); xlim(ax, [0 mx]); ylim(ax, [0 mx]); set(ax, 'XTick', [0 mx], 'YTick', [0 mx]);
xlabel(ax, 'PI error (%)'); ylabel(ax, 'MPC error (%)');
text(ax, 0.05*mx, 0.95*mx, sprintf('%d/%d\nbelow', sum(q<1), numel(q)), 'FontSize', S.fs_annot, 'Color', C.m, 'VerticalAlignment','top');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_E_rmse_scatter.png')); close(fig);

%% F -- input smoothness lambda
Lw = load(fullfile(dataDir, sprintf('mpc_direct_%s_lowrd.mat', sess)));
Hi = load(fullfile(dataDir, sprintf('mpc_direct_%s.mat', sess)));
[lam, rat] = deal([]);
for SRC = {Lw, Hi}
    s = SRC{1}; nn = cellstr(s.names); p = s.rec(:);
    for i = find(startsWith(nn,'MPC rd='))
        l = sscanf(nn{i}, 'MPC rd=%f');
        if ~ismember(l, lam), lam(end+1) = l; rat(end+1) = median(s.rmse(:,i)./p); end %#ok<AGROW>
    end
end
[lam, o] = sort(lam); rat = rat(o); x = lam; x(x == 0) = 3e-3;
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
plot(ax, [2e-3 20], [1 1], '-', 'Color', C.pi, 'LineWidth', S.lw_ref);
plot(ax, [2e-3 20], [1 1]*median(rO./rPI), '--', 'Color', C.o, 'LineWidth', S.lw_ref);
plot(ax, x, rat, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
i1 = find(lam == 0.1);
plot(ax, x, rat, 'o', 'MarkerSize', 2.5, 'MarkerFaceColor', C.m, 'MarkerEdgeColor','none');
plot(ax, x(i1), rat(i1), 'o', 'MarkerSize', 5, 'MarkerEdgeColor', C.k, 'LineWidth', 0.5);
text(ax, 18, 1, 'PI', 'Color', C.pi, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
text(ax, 18, median(rO./rPI), 'perfect prediction', 'Color', C.o, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
text(ax, x(i1), rat(i1)-0.06, 'used', 'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','top');
set(ax, 'XScale','log', 'XTick', [3e-3 1e-1 10], 'XTickLabel', {'0','0.1','10'}, 'YTick', [0 0.5 1]);
xlim(ax, [2e-3 20]); ylim(ax, [0 1.12]); xlabel(ax, 'smoothness \lambda'); ylabel(ax, 'MPC / PI error');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_F_lambda.png')); close(fig);

%% G -- does the result depend on the simulated brain?
R = load(fullfile(dataDir, sprintf('mpc_direct_robust_%s_lam01.mat', sess)));
jm = find(startsWith(cellstr(R.models), 'MPC')); v = R.ratio(:, jm);
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
plot(ax, [0.4 4.6], [1 1], '-', 'Color', C.pi, 'LineWidth', S.lw_ref);
for i = 1:numel(v)
    plot(ax, [i i], [0 v(i)], '-', 'Color', C.m, 'LineWidth', 1.5);
    plot(ax, i, v(i), 'o', 'MarkerSize', 4, 'MarkerFaceColor', C.m, 'MarkerEdgeColor','none');
    text(ax, i, v(i)+0.06, sprintf('%.2f', v(i)), 'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','bottom');
end
text(ax, 4.55, 1, 'PI', 'Color', C.pi, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
set(ax, 'XTick', 1:4, 'XTickLabel', {'same','other','gain','both'}, 'YTick', [0 0.5 1]);
xlim(ax, [0.4 4.6]); ylim(ax, [0 1.12]); ylabel(ax, 'MPC / PI error'); xlabel(ax, 'simulated brain');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_G_robustness.png')); close(fig);
fprintf('[MPCD-P] panels -> %s\n', figDir);
end
