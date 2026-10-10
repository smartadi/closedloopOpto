function ctrl_mpc_direct_panels(sess)
%CTRL_MPC_DIRECT_PANELS  Supplementary panels, direct-prediction MPC (lambda = 0.1), JNeurosci / Figure-3 style:
%   trial-time panels use the Fig-3 look (grey stim window with edge lines, thin zero line, dashed target,
%   short corner scale bars instead of axes, colour-named conditions, no numbers in labels).
%   The MPC predicts the controlled signal itself with the delay-embedded VARX ([controlled spot, 100 brain
%   spots] + laser; no disturbance proxy) -- mpc_direct.py. Simulation in a VARX world driven by each trial's
%   recorded innovations -> descriptive only, no statistics. PI = the rig's RECORDED CL trial (the world
%   reproduces it exactly under the recorded laser). Perfect MPC = same MPC with the future innovations known.
%   Pre/post context (2 s each) from mpc_direct.py's EXT: pre = recorded, post = world with the laser off.
%   Panels (user review 2026-10-09, round 2):
%     0b problem (LaTeX) | 0 schematic | B prediction (VARX / AR / naive) | C1,C2 example trials (median +
%     large mid-trial deviation) | G trial average | E3 variance | E2 RMSE | F lambda (file only)
%   Inputs: data/mpc_direct_<sess>_lam01.mat (MPCD_RD=0.1 MPCD_ORD=0.1 MPCD_TAG=_lam01), _lowrd.mat, .mat,
%   data/mpc_varx_embed_<sess>.mat.   OUT paper/images/supp_mpc/mpcd_*.png (drafts; not in MANIFEST)
if nargin < 1, sess = 'AL_0033_0226_e2'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','supp_mpc');
PS = paperStyle(); S = jnStyle();
C.pi = PS.col_cl; C.m = [0.45 0.20 0.60]; C.o = [0.78 0.66 0.90]; C.g = [0.62 0.62 0.62]; C.k = [0 0 0];
C.edge = [0.45 0.45 0.45]; C.ref = [0.25 0.25 0.25];
W1 = 4.13; W2 = 8.43; H = 3.3;
D = load(fullfile(dataDir, sprintf('mpc_direct_%s_lam01.mat', sess)));
nm = cellstr(D.names); iPI = find(strcmp(nm,'PI')); iM = find(startsWith(nm,'MPC')); iO = find(startsWith(nm,'ORACLE'));
ord3 = [iPI iM iO]; col3 = [C.pi; C.m; C.o]; nam3 = {'PI','MPC','perfect MPC'};
Fs = double(D.Fs); N = size(D.Y,1); tt = (0:N-1).'/Fs; ref = double(D.ref); pre = double(D.pre);
ext = double(D.ext); tx = (-ext:N+ext-1).'/Fs; dur = N/Fs;                % -2 .. 5 s
rPI = D.rmse(:,iPI); rM = D.rmse(:,iM); rO = D.rmse(:,iO); q = rM./rPI; qo = rO./rPI;
nT = numel(rPI);
[~, srt] = sort(rM - rPI); k = srt(round(0.5*(nT-1))+1);                      % median trial of MPC - PI (= mpc_direct.py rule)
fprintf('[MPCD-P] median RMSE  PI %.3f | MPC %.3f | perfect %.3f;  MPC/PI %.3f (%d/%d) | perfect/PI %.3f (%d/%d)\n', ...
    median(rPI), median(rM), median(rO), median(q), sum(q<1), nT, median(qo), sum(qo<1), nT);
for p = {'mpcd_0_problem','mpcd_A_laser_response','mpcd_G_robustness','mpcd_E_rmse_scatter', ...
         'mpcd_C_example_trace','mpcd_D_example_laser'}                               % dropped / renamed panels
    old = dir(fullfile(figDir, [p{1} '.*'])); for i = 1:numel(old), delete(fullfile(figDir, old(i).name)); end
end
% second example: a large mid-trial PI excursion that the MPC removes. Shortlist = top 12 trials by the drop in
% RMSE over 0.8-2.6 s (PI -> MPC); trial 79 picked by eye from it as the cleanest single excursion (~2.2 s).
mid = tt >= 0.8 & tt <= 2.6;
dPI = max(abs(D.Y(mid,:,iPI) - ref), [], 1).'; dM = max(abs(D.Y(mid,:,iM) - ref), [], 1).';
k2 = 79;
fprintf('[MPCD-P] examples: median trial %d (PI %.2f, MPC %.2f) | large-deviation trial %d (PI %.2f, MPC %.2f; mid peak %.1f -> %.1f)\n', ...
    k, rPI(k), rM(k), k2, rPI(k2), rM(k2), dPI(k2), dM(k2));

%% 0b -- the optimisation problem (clean math, LaTeX)
fig = jnFig(W2, 1.7); ax = axes(fig, 'Position', [0 0 1 1]); axis(ax, 'off'); xlim(ax,[0 1]); ylim(ax,[0 1]);
L = {'$\displaystyle \min_{u_{t+1},\dots,u_{t+H}} \; \sum_{h=1}^{H} \big(\hat y_{t+h}-r\big)^2 \;+\; \rho \sum_{h=1}^{H} \big(u_{t+h}-u_{ss}\big)^2 \;+\; \lambda \sum_{h=1}^{H} \big(\Delta u_{t+h}\big)^2$', ...
     '$\mathrm{s.t.}\quad \hat y_{t+h} = \mathrm{VARX}\big(z_{t},\dots,z_{t-L+1};\; u_{t+h},\dots\big), \qquad 0 \le u \le u_{\max}$', ...
     '$H = 1\,\mathrm{s}, \quad r = -5\%, \quad \rho = 10^{-3}, \quad \lambda = 0.1$'};
yy = [0.76 0.40 0.12];
for i = 1:numel(L)
    text(ax, 0.02, yy(i), L{i}, 'Interpreter','latex', 'FontSize', S.fs_annot + 1 + (i==1)*0.5, 'VerticalAlignment','middle');
end
ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_0b_problem.png')); close(fig);

%% 0 -- how the MPC works: one real step inside its trial (Fig-3 look, scale bars)
st = double(D.snap_t); tnow = st/Fs;
yp = D.snap_ypast(:); up = D.snap_upast(:); tp = (-pre:st).'/Fs;
tf = tnow + (1:numel(D.snap_yhat)).'/Fs;
ytrue = D.snap_ytrue(:); utrue = D.snap_utrue(:); ifu = (st+1:N).'; tfu = (ifu-1)/Fs;
fig = jnFig(W2, 3.8);
ax1 = axes(fig, 'Units','centimeters', 'Position', [0.7 1.45 W2-1.6 2.15]); hold(ax1,'on');
ax2 = axes(fig, 'Units','centimeters', 'Position', [0.7 0.2 W2-1.6 0.75]); hold(ax2,'on');
yl1 = [min([yp; D.snap_yhat(:); ytrue; ref]) max([yp; D.snap_yhat(:); ytrue; ref])] + [-0.8 1.6]; yl2 = [-0.1 3.2];
for a = {ax1, yl1; ax2, yl2}.'
    stimBox(a{1}, 0, dur, a{2}, C);
    patch(a{1}, [tnow tf(end) tf(end) tnow], a{2}([1 1 2 2]), C.m, 'FaceAlpha', 0.10, 'EdgeColor','none');
    plot(a{1}, [tnow tnow], a{2}, '-', 'Color', C.m, 'LineWidth', 0.6);
end
plot(ax1, [-pre/Fs dur], [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
plot(ax1, [0 dur], [ref ref], '--', 'Color', C.ref, 'LineWidth', S.lw_ref);
plot(ax1, [tnow; tfu], [yp(end); ytrue(ifu)], '-', 'Color', C.g, 'LineWidth', S.lw_ind+0.2);
plot(ax1, tp, yp, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax1, [tnow; tf], [yp(end); D.snap_yhat(:)], '--', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax1, tnow, yp(end), 'o', 'MarkerSize', 3, 'MarkerFaceColor', C.m, 'MarkerEdgeColor', 'w', 'LineWidth', 0.4);
text(ax1, tnow-0.04, yl1(2), 'now', 'FontSize', S.fs_annot, 'VerticalAlignment','top', 'HorizontalAlignment','right', 'Color', C.m);
text(ax1, mean([tnow tf(end)]), yl1(2), 'predict 1 s', 'FontSize', S.fs_annot, 'VerticalAlignment','top', 'HorizontalAlignment','center', 'Color', C.m);
text(ax1, dur+0.05, ref, 'target', 'FontSize', S.fs_annot, 'VerticalAlignment','middle', 'Color', C.ref, 'Clipping','off');
text(ax1, dur+0.05, ref-1.1, 'actual', 'FontSize', S.fs_annot, 'Color', C.g, 'VerticalAlignment','middle', 'Clipping','off');
stairs(ax2, [tnow; tfu], [up(end); utrue(ifu)], '-', 'Color', C.g, 'LineWidth', S.lw_ind+0.2);
stairs(ax2, tp, up, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
stairs(ax2, [tnow; tf], [up(end); D.snap_U(:)], '--', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax2, tf(1), D.snap_U(1), 'o', 'MarkerSize', 3, 'MarkerFaceColor', C.m, 'MarkerEdgeColor','w', 'LineWidth', 0.4);
text(ax2, mean([tnow tf(end)]), yl2(2), 'plan', 'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','top', 'Color', C.m);
text(ax2, tnow-0.04, yl2(2), 'apply 1st', 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','top', 'Color', C.m);
xlim(ax1, [-pre/Fs dur]); ylim(ax1, yl1); xlim(ax2, [-pre/Fs dur]); ylim(ax2, yl2);
paperAxes(ax1, 'XLength', 0.5, 'YLength', 2, 'XLabel', '0.5 s', 'YLabel', '2% \DeltaF/F');
paperAxes(ax2, 'XLength', 0, 'YLength', 1, 'YLabel', '1 mW');
ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_0_schematic.png')); close(fig);

%% B -- prediction R^2 vs lead (held-out OL trials): VARX / AR / naive
V = load(fullfile(dataDir, sprintf('mpc_varx_embed_%s.mat', sess)));
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
for x = [200 1000], plot(ax, [x x], [-0.25 1], ':', 'Color', C.g, 'LineWidth', S.lw_axis); end
plot(ax, [25 1100], [0 0], '-', 'Color', C.g, 'LineWidth', S.lw_axis);
plot(ax, V.lead_ms, V.R2_persist, '-', 'Color', C.g, 'LineWidth', S.lw_mean);
plot(ax, V.lead_ms, V.R2_ar, '-', 'Color', C.k, 'LineWidth', S.lw_ind+0.3);
plot(ax, V.lead_ms, V.R2, '-', 'Color', C.m, 'LineWidth', S.lw_mean);
plot(ax, V.lead_ms, V.R2, 'o', 'MarkerSize', 2.5, 'MarkerFaceColor', C.m, 'MarkerEdgeColor', 'none');
i7 = find(round(V.lead_ms) == 200);
text(ax, 210, V.R2(i7)+0.08, 'VARX', 'Color', C.m, 'FontSize', S.fs_annot);
text(ax, 32, -0.06, 'AR', 'Color', C.k, 'FontSize', S.fs_annot);
text(ax, 32, -0.19, 'naive', 'Color', C.g, 'FontSize', S.fs_annot);
set(ax, 'XScale','log', 'XTick', [30 200 1000], 'XTickLabel', {'30','200','1000'}, 'YTick', [0 0.5 1]);
xlim(ax, [25 1100]); ylim(ax, [-0.25 1]); xlabel(ax, 'prediction lead (ms)'); ylabel(ax, 'R^2');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_B_prediction.png')); close(fig);

%% C1, C2 -- example trials, -2..5 s (Fig-3 look): signal + laser, three controllers
exs = [k k2]; tags = {'mpcd_C1_example_median', 'mpcd_C2_example_deviation'};
for e = 1:2
    kk = exs(e);
    Yk = squeeze(D.Yx(:,kk,ord3)); Uk = squeeze(D.Ux(:,kk,ord3));
    fig = jnFig(W2, 3.6);
    ax1 = axes(fig, 'Units','centimeters', 'Position', [0.7 1.45 W2-1.0 2.0]); hold(ax1,'on');
    ax2 = axes(fig, 'Units','centimeters', 'Position', [0.7 0.5 W2-1.0 0.6]); hold(ax2,'on');
    yl1 = [min(Yk(:)) max(Yk(:))] + [-0.5 0.5]; yl2 = [-0.1 3.0];
    stimBox(ax1, 0, dur, yl1, C); stimBox(ax2, 0, dur, yl2, C);
    plot(ax1, tx([1 end]), [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
    plot(ax1, [0 dur], [ref ref], '--', 'Color', C.ref, 'LineWidth', S.lw_ref);
    for j = [3 1 2]
        plot(ax1, tx, Yk(:,j), '-', 'Color', col3(j,:), 'LineWidth', S.lw_mean);
        stairs(ax2, tx, Uk(:,j), '-', 'Color', col3(j,:), 'LineWidth', PS.lw_inp);
    end
    xlim(ax1, tx([1 end])); ylim(ax1, yl1); xlim(ax2, tx([1 end])); ylim(ax2, yl2);
    paperAxes(ax1, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2% \DeltaF/F');
    paperAxes(ax2, 'XLength', 0, 'YLength', 1, 'YLabel', '1 mW');
    nameRow(fig, W2, col3, nam3, C);
    ctrl_mpc_export(fig, fullfile(figDir, [tags{e} '.png'])); close(fig);
end

%% G -- trial average +/- SD, -2..5 s, one axes per controller (Fig-3 panel B look)
fig = jnFig(W2, 3.0); wA = (W2-0.9)/3 - 0.15;
mx = -inf; mn = inf;
for j = 1:3, Yj = D.Yx(:,:,ord3(j)); m = mean(Yj,2); s = std(Yj,0,2); mx = max(mx, max(m+s)); mn = min(mn, min(m-s)); end
yl = [mn mx] + [-0.3 0.3];
for j = 1:3
    ax = axes(fig, 'Units','centimeters', 'Position', [0.7+(j-1)*(wA+0.15) 0.5 wA 2.1]); hold(ax,'on');
    Yj = D.Yx(:,:,ord3(j)); m = mean(Yj,2); s = std(Yj,0,2);
    stimBox(ax, 0, dur, yl, C);
    fill(ax, [tx; flipud(tx)], [m+s; flipud(m-s)], col3(j,:), 'FaceAlpha', 0.25, 'EdgeColor','none');
    plot(ax, tx([1 end]), [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
    plot(ax, [0 dur], [ref ref], '--', 'Color', C.ref, 'LineWidth', S.lw_ref);
    plot(ax, tx, m, '-', 'Color', col3(j,:), 'LineWidth', S.lw_mean);
    xlim(ax, tx([1 end])); ylim(ax, yl);
    text(ax, mean(tx([1 end])), yl(2), nam3{j}, 'Color', col3(j,:), 'FontSize', S.fs_label, 'FontWeight','bold', ...
        'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
    if j == 1, paperAxes(ax, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2% \DeltaF/F');
    else, paperAxes(ax); set(ax, 'XColor','none', 'YColor','none'); end
end
ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_G_trial_average.png')); close(fig);

%% E3 -- across-trial variance vs time, -2..5 s (Fig-3 variance look)
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [1.25 0.75 W1-1.4 2.2]); hold(ax,'on');
Vx = zeros(numel(tx), 3); for j = 1:3, Vx(:,j) = var(D.Yx(:,:,ord3(j)), 0, 2); end
yl = [0 max(Vx(:))*1.05];
stimBox(ax, 0, dur, yl, C);
for j = [3 1 2], plot(ax, tx, Vx(:,j), '-', 'Color', col3(j,:), 'LineWidth', S.lw_mean); end
xlim(ax, tx([1 end])); ylim(ax, yl);
paperAxes(ax, 'XLength', 1, 'YLength', 5, 'XLabel', '1 s', 'YLabel', '5 (%\DeltaF/F)^2');
text(ax, -0.36, 0.5, 'Variance across trials', 'Units','normalized', 'Rotation', 90, 'FontSize', S.fs_annot, ...
    'FontWeight','bold', 'HorizontalAlignment','center', 'Clipping','off');
for j = 1:3
    text(ax, 0.12, yl(2)*(1.0 - 0.11*(j-1)), nam3{j}, 'Color', col3(j,:), 'FontSize', S.fs_annot, ...
        'HorizontalAlignment','left', 'VerticalAlignment','top');
end
ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_E3_variance.png')); close(fig);
w13 = tx >= 1-1e-9 & tx < dur; wpre = tx < 0; wpost = tx >= dur;
fprintf('[MPCD-P] variance  pre %s | 1-3 s %s | post %s  (PI/MPC/perfect)\n', mat2str(round(mean(Vx(wpre,:)),2)), ...
    mat2str(round(mean(Vx(w13,:)),2)), mat2str(round(mean(Vx(wpost,:)),2)));

%% E2 -- RMSE comparison: PI / MPC / perfect MPC (per trial, paired, median bar)
R = [rPI rM rO];
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
rng(1); jx = (rand(nT,1)-0.5)*0.36;
plot(ax, (1:3)' + [jx jx jx]', R', '-', 'Color', [C.g 0.12], 'LineWidth', 0.25);
for i = 1:3
    scatter(ax, i + jx, R(:,i), 4, col3(i,:), 'filled', 'MarkerFaceAlpha', 0.5);
    plot(ax, i + [-0.28 0.28], median(R(:,i))*[1 1], '-', 'Color', C.k, 'LineWidth', 1.2);
end
mx = ceil(max(R(:)));
set(ax, 'XTick', 1:3, 'XTickLabel', {'PI','MPC','perfect'}, 'YTick', [0 mx]); xlim(ax, [0.4 3.6]); ylim(ax, [0 mx]);
ylabel(ax, 'trial RMSE (%)');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_E2_rmse_compare.png')); close(fig);

%% F -- input smoothness lambda (demo; lambda = 0.1 used) -- file only, not in the layout
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
text(ax, 18, 1, 'PI', 'Color', C.pi, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
text(ax, 18, median(qo), 'perfect MPC', 'Color', C.o, 'FontSize', S.fs_annot, 'HorizontalAlignment','right', 'VerticalAlignment','bottom');
text(ax, x(i1), rat(i1)-0.06, 'used', 'FontSize', S.fs_annot, 'HorizontalAlignment','center', 'VerticalAlignment','top');
set(ax, 'XScale','log', 'XTick', [3e-3 1e-1 10], 'XTickLabel', {'0','0.1','10'}, 'YTick', [0 0.5 1]);
xlim(ax, [2e-3 20]); ylim(ax, [0 1.12]); xlabel(ax, 'smoothness \lambda'); ylabel(ax, 'MPC / PI RMSE');
jnAxes(ax); ctrl_mpc_export(fig, fullfile(figDir, 'mpcd_F_lambda.png')); close(fig);
fprintf('[MPCD-P] panels -> %s\n', figDir);
end

function stimBox(ax, x1, x2, yl, C)
% Fig-3 stim window: light grey fill + grey edge lines
patch(ax, [x1 x2 x2 x1], yl([1 1 2 2]), [0.9 0.9 0.9], 'FaceAlpha', 0.4, 'EdgeColor','none');
plot(ax, [x1 x1], yl, '-', 'Color', C.edge, 'LineWidth', 0.6);
plot(ax, [x2 x2], yl, '-', 'Color', C.edge, 'LineWidth', 0.6);
end

function nameRow(fig, W, cols, names, C)
% Fig-3 style legend row under the panel: coloured line + name, then dashed target
S = jnStyle(); ax = axes(fig, 'Units','centimeters', 'Position', [0.7 0.0 W-1.0 0.3]); hold(ax,'on'); axis(ax,'off');
xlim(ax, [0 1]); ylim(ax, [0 1]); x = 0.08;
for j = 1:size(cols,1)
    plot(ax, x + [0 0.045], [0.5 0.5], '-', 'Color', cols(j,:), 'LineWidth', 1.5);
    text(ax, x + 0.055, 0.5, names{j}, 'FontSize', S.fs_annot, 'FontWeight','bold', 'VerticalAlignment','middle');
    x = x + 0.09 + 0.021*numel(names{j});
end
plot(ax, x + [0 0.045], [0.5 0.5], '--', 'Color', C.ref, 'LineWidth', 1.0);
text(ax, x + 0.055, 0.5, 'target', 'FontSize', S.fs_annot, 'FontWeight','bold', 'VerticalAlignment','middle');
end
