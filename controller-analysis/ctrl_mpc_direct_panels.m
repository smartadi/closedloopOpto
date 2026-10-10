function ctrl_mpc_direct_panels(sess)
%CTRL_MPC_DIRECT_PANELS  Supplementary panels, direct-prediction MPC (lambda = 0.1), JNeurosci rule-book style:
%   grid panel sizes (4.13 x 3.3 cm = 4-across, 8.43 cm = 2-across), Arial 6/7 pt, direct labels instead of
%   legends, minimal ticks. The MPC predicts the controlled signal itself with the delay-embedded VARX
%   ([controlled spot, 100 brain spots] + laser; no disturbance proxy) -- mpc_direct.py. Simulation in a VARX
%   world driven by each trial's recorded innovations -> descriptive only, no statistics.
%   PI = the rig's RECORDED CL trial (the world reproduces it exactly under the recorded laser).
%   "Perfect MPC" = the same MPC with the world's future innovations known (prediction ceiling).
%   Panel set (user 2026-10-09 review): 0 schematic (one real step, in trial context) | 0b the optimisation
%   problem | B prediction (+ Lu et al. AR) | C/D example (+ perfect MPC) | E scatter | E2 RMSE | E3 variance |
%   F lambda. Learned laser response (old A) and robustness (old G) dropped.
%   Inputs (run first): data/mpc_direct_<sess>_lam01.mat (MPCD_RD=0.1 MPCD_ORD=0.1 MPCD_TAG=_lam01, incl. the
%   one-step snapshot), data/mpc_direct_<sess>_lowrd.mat, data/mpc_direct_<sess>.mat,
%   data/mpc_varx_embed_<sess>.mat (mpc_varx_embed.py, incl. the AR baseline).
%   OUT paper/images/supp_mpc/mpcd_*.png (drafts; not in MANIFEST until locked)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','supp_mpc');
PS = paperStyle(); S = jnStyle();
C.pi = PS.col_cl; C.m = [0.45 0.20 0.60]; C.o = [0.78 0.66 0.90]; C.g = [0.62 0.62 0.62]; C.k = [0 0 0];
W1 = 4.13; W2 = 8.43; H = 3.3;
D = load(fullfile(dataDir, sprintf('mpc_direct_%s_lam01.mat', sess)));
nm = cellstr(D.names); iPI = find(strcmp(nm,'PI')); iM = find(startsWith(nm,'MPC')); iO = find(startsWith(nm,'ORACLE'));
Fs = double(D.Fs); N = size(D.Y,1); tt = (0:N-1).'/Fs; ref = double(D.ref); pre = double(D.pre);
rPI = D.rmse(:,iPI); rM = D.rmse(:,iM); rO = D.rmse(:,iO); q = rM./rPI; qo = rO./rPI; k = double(D.snap_k);
nT = numel(rPI); w = tt >= 34/Fs - 1e-9;                                   % RMSE window 1-3 s (frames 34..104)
vr = @(i) var(D.Y(:,:,i), 0, 2);                                            % across-trial variance per frame
vPI = vr(iPI); vM = vr(iM); vO = vr(iO);
fprintf('[MPCD-P] median RMSE  actual PI %.3f | MPC %.3f | perfect MPC %.3f\n', median(rPI), median(rM), median(rO));
fprintf('[MPCD-P] MPC/PI %.3f (%d/%d below) | perfect/PI %.3f (%d/%d below) | example trial %d\n', ...
    median(q), sum(q<1), nT, median(qo), sum(qo<1), nT, k);
fprintf('[MPCD-P] across-trial variance 1-3 s, mean  PI %.3f | MPC %.3f | perfect %.3f  (%%dF/F)^2\n', ...
    mean(vPI(w)), mean(vM(w)), mean(vO(w)));
for p = {'mpcd_0_problem','mpcd_A_laser_response','mpcd_G_robustness'}               % dropped panels
    old = dir(fullfile(figDir, [p{1} '.*'])); for i = 1:numel(old), delete(fullfile(figDir, old(i).name)); end
end

%% 0 -- how the MPC works: one real step, shown inside its trial (stim window 0-3 s)
st = double(D.snap_t); tnow = st/Fs;
yp = D.snap_ypast(:); up = D.snap_upast(:); tp = (-pre:st).'/Fs;            % trial start -> now
tf = tnow + (1:numel(D.snap_yhat)).'/Fs;                                    % prediction horizon (1 s)
ytrue = D.snap_ytrue(:); utrue = D.snap_utrue(:); ifu = (st+1:N).'; tfu = (ifu-1)/Fs;  % what then happened
fig = jnFig(W2, 4.0);
ax1 = axes(fig, 'Units','centimeters', 'Position', [0.9 1.75 W2-1.75 1.95]); hold(ax1,'on');
ax2 = axes(fig, 'Units','centimeters', 'Position', [0.9 0.8 W2-1.75 0.8]); hold(ax2,'on');
for a = [ax1 ax2]
    patch(a, [0 3 3 0], [-100 -100 100 100], C.g, 'FaceAlpha', 0.10, 'EdgeColor','none');          % stim window
    patch(a, [tnow tf(end) tf(end) tnow], [-100 -100 100 100], C.m, 'FaceAlpha', 0.10, 'EdgeColor','none');  % horizon
    plot(a, [tnow tnow], [-100 100], '-', 'Color', C.m, 'LineWidth', S.lw_axis);
end
plot(ax1, [0 3], [ref ref], ':', 'Color', C.k, 'LineWidth', S.lw_ref);
plot(ax1, [tnow; tfu], [yp(end); ytrue(ifu)], '-', 'Color', C.g, 'LineWidth', S.lw_ind+0.2);
plot(ax1, tp, yp, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax1, [tnow; tf], [yp(end); D.snap_yhat(:)], '--', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax1, tnow, yp(end), 'o', 'MarkerSize', 3, 'MarkerFaceColor', C.m, 'MarkerEdgeColor', 'w', 'LineWidth', 0.4);
yl = [min([yp; D.snap_yhat(:); ytrue; ref]) max([yp; D.snap_yhat(:); ytrue; ref])] + [-0.8 2.0];
ylim(ax1, yl); set(ax1, 'XTick', [], 'XColor','none'); ylabel(ax1, '\DeltaF/F (%)');
text(ax1, 0.04, yl(2), 'stim on', 'FontSize', S.fs_annot, 'VerticalAlignment','top', 'Color', [0.4 0.4 0.4]);
text(ax1, tnow-0.04, yl(2), 'now', 'FontSize', S.fs_annot, 'VerticalAlignment','top', 'HorizontalAlignment','right', 'Color', C.m, 'Clipping','off');
text(ax1, mean([tnow tf(end)]), yl(2), 'predict 1 s', 'FontSize', S.fs_annot, 'VerticalAlignment','top', 'HorizontalAlignment','center', 'Color', C.m);
text(ax1, 3.04, ref, 'target', 'FontSize', S.fs_annot, 'VerticalAlignment','middle', 'Clipping','off');
text(ax1, 3.04, ref-1.1, 'actual', 'FontSize', S.fs_annot, 'Color', C.g, 'VerticalAlignment','middle', 'Clipping','off');
stairs(ax2, [tnow; tfu], [up(end); utrue(ifu)], '-', 'Color', C.g, 'LineWidth', S.lw_ind+0.2);
stairs(ax2, tp, up, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
stairs(ax2, [tnow; tf], [up(end); D.snap_U(:)], '--', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax2, tf(1), D.snap_U(1), 'o', 'MarkerSize', 3, 'MarkerFaceColor', C.m, 'MarkerEdgeColor','w', 'LineWidth', 0.4);
text(ax2, mean([tnow tf(end)]), 3.3, 'plan', 'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','top', 'Color', C.m);
text(ax2, tnow-0.04, D.snap_U(1), 'apply 1st', 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom', 'Color', C.m);
for a = [ax1 ax2], xlim(a, [-pre/Fs 3]); end
ylim(ax2, [-0.15 3.3]); set(ax2, 'YTick', [0 2.5], 'XTick', [-1 0 1 2 3]); ylabel(ax2, 'laser');
xlabel(ax2, 'time from stim onset (s)');
jnAxes(ax1); jnAxes(ax2); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_0_schematic.png')); close(fig);

%% 0b -- the optimisation solved at every frame (text panel)
yh = char(375);                                                             % y-hat in Arial
fig = jnFig(W2, 2.2); ax = axes(fig, 'Position', [0 0 1 1], 'Visible','off'); hold(ax,'on'); xlim(ax,[0 1]); ylim(ax,[0 1]);
L = {'\bfat every frame t, choose the laser plan', ...
     ['\rmmin_{u}  \Sigma_{h=1}^{H} (' yh '_{t+h} - target)^2 + \lambda \Sigma (\Deltau)^2'], ...
     '\rmsubject to  0 \leq u \leq u_{max}', ...
     ['\rm' yh ' = VARX(brain past, laser past + plan)'], ...
     '\rmH = 1 s,  \lambda = 0.1;  apply u_{t+1}, repeat'};
yy = [0.88 0.66 0.46 0.29 0.11];
for i = 1:numel(L)
    text(ax, 0.06, yy(i), L{i}, 'Interpreter','tex', 'FontName', S.font, 'FontSize', S.fs_annot+1, ...
        'Color', C.m*(i>1) + C.k*(i==1), 'VerticalAlignment','middle');
end
ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_0b_problem.png')); close(fig);

%% B -- how well the model predicts the signal (held-out OL trials), vs Lu et al. AR and last value
V = load(fullfile(dataDir, sprintf('mpc_varx_embed_%s.mat', sess)));
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
for x = [200 1000], plot(ax, [x x], [-0.25 1], ':', 'Color', C.g, 'LineWidth', S.lw_axis); end
plot(ax, [25 1100], [0 0], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
plot(ax, V.lead_ms, V.R2_persist, '-', 'Color', C.g, 'LineWidth', S.lw_mean);
plot(ax, V.lead_ms, V.R2_ar, '-', 'Color', C.k, 'LineWidth', S.lw_ind+0.3);
plot(ax, V.lead_ms, V.R2, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax, V.lead_ms, V.R2, 'o', 'MarkerSize', 2.5, 'MarkerFaceColor', C.m, 'MarkerEdgeColor', 'none');
i7 = find(round(V.lead_ms) == 200);
text(ax, 210, V.R2(i7)+0.08, 'VARX (ours)', 'Color', C.m, 'FontSize', S.fs_annot);
text(ax, 32, -0.06, sprintf('AR (Lu et al.)'), 'Color', C.k, 'FontSize', S.fs_annot);
text(ax, 32, -0.19, 'last value', 'Color', C.g, 'FontSize', S.fs_annot);
set(ax, 'XScale','log', 'XTick', [30 200 1000], 'XTickLabel', {'30','200','1000'}, 'YTick', [0 0.5 1]);
xlim(ax, [25 1100]); ylim(ax, [-0.25 1]); xlabel(ax, 'prediction lead (ms)'); ylabel(ax, 'R^2');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_B_prediction.png')); close(fig);
fprintf('[MPCD-P] R2 @200 ms VARX %.2f | AR(%d) %.2f | last %.2f;  @1 s %.2f | %.2f | %.2f\n', V.R2(i7), V.ar_order, ...
    V.R2_ar(i7), V.R2_persist(i7), V.R2(end), V.R2_ar(end), V.R2_persist(end));

%% C, D -- example trial (median MPC - PI): actual PI, MPC, perfect MPC
fig = jnFig(W2, 2.7); ax = axes(fig, 'Units','centimeters', 'Position', [1.0 0.3 W2-1.3 2.2]); hold(ax,'on');   % same x-extent as D
plot(ax, [0 3], [ref ref], ':', 'Color', C.k, 'LineWidth', S.lw_ref);
plot(ax, tt, D.Y(:,k,iO), '-', 'Color', C.o, 'LineWidth', S.lw_mean);
plot(ax, tt, D.Y(:,k,iPI), '-', 'Color', C.pi, 'LineWidth', S.lw_mean);
plot(ax, tt, D.Y(:,k,iM), '-', 'Color', C.m, 'LineWidth', S.lw_mean);
xlim(ax, [0 3]); set(ax, 'XTick', [0 1 2 3], 'XTickLabel', []); ylabel(ax, '\DeltaF/F (%)');
yl = ylim(ax); dy = 0.14*diff(yl);
text(ax, 2.98, yl(2), sprintf('actual PI trial RMSE  %.2f', rPI(k)), 'Color', C.pi, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(ax, 2.98, yl(2)-dy, sprintf('MPC RMSE  %.2f', rM(k)), 'Color', C.m, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(ax, 2.98, yl(2)-2*dy, sprintf('perfect MPC RMSE  %.2f', rO(k)), 'Color', C.o, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_C_example_trace.png')); close(fig);
fig = jnFig(W2, 2.0); ax = axes(fig, 'Units','centimeters', 'Position', [1.0 0.8 W2-1.3 1.05]); hold(ax,'on');
stairs(ax, tt, D.U(:,k,iO), '-', 'Color', C.o, 'LineWidth', PS.lw_inp);
stairs(ax, tt, D.U(:,k,iPI), '-', 'Color', C.pi, 'LineWidth', PS.lw_inp);
stairs(ax, tt, D.U(:,k,iM), '-', 'Color', C.m, 'LineWidth', PS.lw_inp);
xlim(ax, [0 3]); ylim(ax, [0 2.9]); set(ax, 'XTick', [0 1 2 3], 'YTick', [0 2.5]);
xlabel(ax, 'time from onset (s)'); ylabel(ax, 'laser');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_D_example_laser.png')); close(fig);

%% E -- every trial: MPC (and perfect MPC) vs actual PI RMSE
fig = jnFig(H, H); ax = axes(fig); hold(ax,'on');
mx = ceil(max([rPI; rM]));
plot(ax, [0 mx], [0 mx], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
scatter(ax, rPI, rO, 5, C.o, 'filled', 'MarkerFaceAlpha', 0.7);
scatter(ax, rPI, rM, 5, C.m, 'filled', 'MarkerFaceAlpha', 0.55);
axis(ax, 'square'); xlim(ax, [0 mx]); ylim(ax, [0 mx]); set(ax, 'XTick', [0 mx], 'YTick', [0 mx]);
xlabel(ax, 'actual PI RMSE (%)'); ylabel(ax, 'MPC RMSE (%)');
text(ax, 0.05*mx, 0.97*mx, sprintf('MPC %d/%d below', sum(q<1), nT), 'FontSize', S.fs_annot, 'Color', C.m, 'VerticalAlignment','top');
text(ax, 0.05*mx, 0.83*mx, sprintf('perfect %d/%d', sum(qo<1), nT), 'FontSize', S.fs_annot, 'Color', C.o, 'VerticalAlignment','top');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_E_rmse_scatter.png')); close(fig);

%% E2 -- RMSE comparison: actual PI / MPC / perfect MPC (per trial, median bar)
R = [rPI rM rO]; cols = [C.pi; C.m; C.o]; lab = {'PI','MPC','perfect'};
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
rng(1); jx = (rand(nT,1)-0.5)*0.36;
plot(ax, (1:3)' + [jx jx jx]', R', '-', 'Color', [C.g 0.12], 'LineWidth', 0.25);
for i = 1:3
    scatter(ax, i + jx, R(:,i), 4, cols(i,:), 'filled', 'MarkerFaceAlpha', 0.5);
    plot(ax, i + [-0.28 0.28], median(R(:,i))*[1 1], '-', 'Color', C.k, 'LineWidth', 1.2);
    text(ax, i, max(R(:))*1.02, sprintf('%.2f', median(R(:,i))), 'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Color', cols(i,:));
end
mx = ceil(max(R(:))*1.15);
set(ax, 'XTick', 1:3, 'XTickLabel', lab, 'YTick', [0 mx]); xlim(ax, [0.4 3.6]); ylim(ax, [0 mx]);
ylabel(ax, 'trial RMSE (%)');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_E2_rmse_compare.png')); close(fig);

%% E3 -- variance comparison: across-trial variance vs time (RMSE window 1-3 s shaded)
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
vmx = ceil(max([vPI; vM; vO])/5)*5;
patch(ax, [1 3 3 1], [0 0 1 1]*vmx*1.45, C.g, 'FaceAlpha', 0.10, 'EdgeColor','none');
plot(ax, tt, vO, '-', 'Color', C.o, 'LineWidth', S.lw_mean);
plot(ax, tt, vPI, '-', 'Color', C.pi, 'LineWidth', S.lw_mean);
plot(ax, tt, vM, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
xlim(ax, [0 3]); ylim(ax, [0 vmx*1.45]); set(ax, 'XTick', [0 1 2 3], 'YTick', [0 vmx]);
xlabel(ax, 'time from onset (s)'); ylabel(ax, 'variance (%^2)');
text(ax, 2.95, vmx*1.45, sprintf('PI %.2f', mean(vPI(w))), 'Color', C.pi, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(ax, 2.95, vmx*1.31, sprintf('MPC %.2f', mean(vM(w))), 'Color', C.m, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
text(ax, 2.95, vmx*1.17, sprintf('perfect %.2f', mean(vO(w))), 'Color', C.o, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_E3_variance.png')); close(fig);

%% F -- input smoothness lambda (demo; lambda = 0.1 used)
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
plot(ax, [2e-3 20], [1 1]*median(qo), '--', 'Color', C.o, 'LineWidth', S.lw_ref);
plot(ax, x, rat, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
i1 = find(lam == 0.1);
plot(ax, x, rat, 'o', 'MarkerSize', 2.5, 'MarkerFaceColor', C.m, 'MarkerEdgeColor','none');
plot(ax, x(i1), rat(i1), 'o', 'MarkerSize', 5, 'MarkerEdgeColor', C.k, 'LineWidth', 0.5);
text(ax, 18, 1, 'actual PI', 'Color', C.pi, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
text(ax, 18, median(qo), 'perfect MPC', 'Color', C.o, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
text(ax, x(i1), rat(i1)-0.06, 'used', 'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','top');
set(ax, 'XScale','log', 'XTick', [3e-3 1e-1 10], 'XTickLabel', {'0','0.1','10'}, 'YTick', [0 0.5 1]);
xlim(ax, [2e-3 20]); ylim(ax, [0 1.12]); xlabel(ax, 'smoothness \lambda'); ylabel(ax, 'MPC / PI RMSE');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_F_lambda.png')); close(fig);
fprintf('[MPCD-P] panels -> %s\n', figDir);
end
