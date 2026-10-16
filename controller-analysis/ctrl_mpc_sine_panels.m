function ctrl_mpc_sine_panels(sess)
%CTRL_MPC_SINE_PANELS  Fig 6 I-M: the direct-prediction MPC replayed on a SINE reference (mpc_direct_sine.py),
%   AL_0048 2026-07-14/1 right hemisphere (Fig 5's representative session), 1 Hz sine 0..-4 %dF/F, 4 s window.
%   Same look as ctrl_mpc_direct_panels (Fig 6 A-H): Fig-3 stim box, corner scale bars, colour-named conditions,
%   no numbers in the panels. Colours: Fig 5 modes (OL red, OL+p orange, CL blue, CL+p green), MPC purple,
%   perfect-prediction MPC light purple. SIMULATION -> descriptive only, no tests, no stars.
%   MPC / perfect = replayed on every closed-loop trial (46 CL + 57 CL+p); each is paired with its recorded trial.
%   Panels: I example trial (median MPC - CL, CL trials) | J trial average +/- SD | K per-trial RMSE, paired |
%           L phase lag of the trial average (1 Hz fundamental, Fig 5H) | M across-trial variance vs time.
%   IN  data/mpc_direct_sine_<sess>.mat.   OUT paper/images/supp_mpc/mpcs_*.png (+ PDF + mirror with PAPER_FINAL)
if nargin < 1, sess = 'AL_0048_0714_e1'; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','supp_mpc');
PS = paperStyle(); S = jnStyle();
C.m = [0.45 0.20 0.60]; C.o = [0.78 0.66 0.90]; C.g = [0.62 0.62 0.62]; C.k = [0 0 0];
C.edge = [0.45 0.45 0.45]; C.ref = [0.25 0.25 0.25];
MC = [0 0.50 0; 1 0.55 0.25; 1 0 0; 0 0.40 0.85];   % ff_cond 0..3 = CL+p, OL+p, OL, CL (Fig 5 MODE_COLS)
W1 = 4.13; W2 = 8.43; H = 3.3;
D = load(fullfile(dataDir, sprintf('mpc_direct_sine_%s.mat', sess)));
cond = double(D.cond(:)); Fs = double(D.Fs); N = double(D.N); ext = double(D.ext); dur = (N-1)/Fs;
tx = (-ext:N+ext-1).'/Fs; keep = tx >= -1 - 1e-9 & tx <= dur + 1 + 1e-9; tx = tx(keep);   % -1 .. 5 s
sn = cellstr(D.sim_names); iM = find(strcmp(sn,'MPC')); iO = find(strcmp(sn,'perfect'));
closed = ismember(cond, [0 3]); isCL = cond == 3; isCLp = cond == 0;
rRec = D.rmse_rec(:); rM = D.rmse_sim(:,iM); rO = D.rmse_sim(:,iO);
Rref = mean(D.R, 2); tw = (0:N-1).'/Fs;
v2mw = @(v) laser_v2mw(v, '2026-07-14', 638);

% ---- I: example CL trial at the median MPC improvement --------------------------------------------------------
iCL = find(isCL); [~, s] = sort(rM(iCL) - rRec(iCL)); k = iCL(s(round(0.5*(numel(iCL)-1))+1));
fprintf('[MPCS-P] example trial %d (CL): RMSE CL %.2f | MPC %.2f | perfect %.2f\n', k, rRec(k), rM(k), rO(k));
Yk = [D.Yrecx(keep,k) D.Yx(keep,k,iM) D.Yx(keep,k,iO)]; Uk = v2mw([D.Urecx(keep,k) D.Ux(keep,k,iM) D.Ux(keep,k,iO)]);
col3 = [MC(4,:); C.m; C.o]; nam3 = {'CL','MPC','perfect MPC'};
fig = jnFig(W2, 3.6);
ax1 = axes(fig, 'Units','centimeters', 'Position', [0.7 1.45 W2-1.0 2.0]); hold(ax1,'on');
ax2 = axes(fig, 'Units','centimeters', 'Position', [0.7 0.5 W2-1.0 0.6]); hold(ax2,'on');
yl1 = [min([Yk(:); Rref]) max(Yk(:))] + [-0.5 0.5]; yl2 = [-0.02 max(Uk(:))*1.05];
stimBox(ax1, 0, dur, yl1, C); stimBox(ax2, 0, dur, yl2, C);
plot(ax1, tx([1 end]), [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
plot(ax1, tw, Rref, '--', 'Color', C.ref, 'LineWidth', S.lw_ref);
for j = [3 1 2]
    plot(ax1, tx, Yk(:,j), '-', 'Color', col3(j,:), 'LineWidth', S.lw_mean);
    stairs(ax2, tx, Uk(:,j), '-', 'Color', col3(j,:), 'LineWidth', PS.lw_inp);
end
xlim(ax1, tx([1 end])); ylim(ax1, yl1); xlim(ax2, tx([1 end])); ylim(ax2, yl2);
paperAxes(ax1, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2% \DeltaF/F');
paperAxes(ax2, 'XLength', 0, 'YLength', 0.5, 'YLabel', '0.5 mW');
nameRow(fig, W2, col3, nam3, C);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_I_example.png')); close(fig);

% ---- J: trial average +/- SD, one axes per condition -----------------------------------------------------------
grp = {D.Yrecx(keep, cond == 2), D.Yrecx(keep, isCL), D.Yrecx(keep, isCLp), D.Yx(keep, closed, iM), D.Yx(keep, closed, iO)};
colJ = [MC(3,:); MC(4,:); MC(1,:); C.m; C.o]; namJ = {'OL','CL','CL+p','MPC','perfect'};
nJ = numel(grp); fig = jnFig(W2, 3.0); wA = (W2-1.1)/nJ - 0.12;
mx = -inf; mn = inf;
for j = 1:nJ, m = mean(grp{j},2); sd = std(grp{j},0,2); mx = max(mx, max(m+sd)); mn = min(mn, min(m-sd)); end
yl = [min(mn, min(Rref)) mx] + [-0.3 0.3];
for j = 1:nJ
    ax = axes(fig, 'Units','centimeters', 'Position', [0.9+(j-1)*(wA+0.12) 0.5 wA 2.1]); hold(ax,'on');
    m = mean(grp{j},2); sd = std(grp{j},0,2);
    stimBox(ax, 0, dur, yl, C);
    fill(ax, [tx; flipud(tx)], [m+sd; flipud(m-sd)], colJ(j,:), 'FaceAlpha', 0.25, 'EdgeColor','none');
    plot(ax, tx([1 end]), [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
    plot(ax, tw, Rref, '--', 'Color', C.ref, 'LineWidth', S.lw_ref);
    plot(ax, tx, m, '-', 'Color', colJ(j,:), 'LineWidth', S.lw_mean);
    xlim(ax, tx([1 end])); ylim(ax, yl);
    text(ax, mean(tx([1 end])), yl(2), namJ{j}, 'Color', colJ(j,:), 'FontSize', S.fs_label, 'FontWeight','bold', ...
        'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
    if j == 1, paperAxes(ax, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2% \DeltaF/F');
    else, paperAxes(ax); set(ax, 'XColor','none', 'YColor','none'); end
end
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_J_trial_average.png')); close(fig);

% ---- K: per-trial RMSE, paired with the recorded trial ---------------------------------------------------------
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on'); rng(1);
blk = {isCL, MC(4,:), 'CL'; isCLp, MC(1,:), 'CL+p'}; xt = []; xl = {};
for b = 1:2
    msk = blk{b,1}; Rb = [rRec(msk) rM(msk) rO(msk)]; x0 = (b-1)*3.6; xs = x0 + (1:3);
    jx = (rand(nnz(msk),1)-0.5)*0.36;
    plot(ax, xs' + [jx jx jx]', Rb', '-', 'Color', [C.g 0.12], 'LineWidth', 0.25);
    cb = [blk{b,2}; C.m; C.o];
    for i = 1:3
        scatter(ax, xs(i) + jx, Rb(:,i), 4, cb(i,:), 'filled', 'MarkerFaceAlpha', 0.5);
        plot(ax, xs(i) + [-0.28 0.28], median(Rb(:,i))*[1 1], '-', 'Color', C.k, 'LineWidth', 1.2);
    end
    xt = [xt xs]; xl = [xl {blk{b,3}, 'MPC', 'perfect'}]; %#ok<AGROW>
end
mxr = ceil(max([rRec(closed); rM(closed)]));
set(ax, 'XTick', xt, 'XTickLabel', xl, 'YTick', [0 mxr]); xlim(ax, [0.4 xt(end)+0.6]); ylim(ax, [0 mxr]);
ylabel(ax, 'trial RMSE (%)'); jnAxes(ax); set(ax, 'XTickLabelRotation', 45);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_K_rmse_compare.png')); close(fig);

% ---- L: phase lag of the trial average (1 Hz fundamental fit, Fig 5H definition) ------------------------------
rows = cellstr(D.summary_rows); su = D.summary;
lab = {'rec OL','rec OL+p','rec CL','rec CL+p','MPC on CL+CL+p','perfect on CL+CL+p'};
colL = [MC(3,:); MC(2,:); MC(4,:); MC(1,:); C.m; C.o]; namL = {'OL','OL+p','CL','CL+p','MPC','perfect'};
lag = cellfun(@(l) su(strcmp(rows, l), 2), lab);
fig = jnFig(W1, H); ax = axes(fig); hold(ax,'on');
for i = 1:numel(lag), bar(ax, i, lag(i), 0.6, 'FaceColor', colL(i,:), 'EdgeColor', 'none'); end
plot(ax, [0.4 numel(lag)+0.6], [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
yt = 15*[floor(min([lag 0])/15) ceil(max(lag)/15)];
set(ax, 'XTick', 1:numel(lag), 'XTickLabel', namL, 'YTick', unique([yt 0])); xlim(ax, [0.4 numel(lag)+0.6]); ylim(ax, yt + [-2 2]);
ylabel(ax, 'phase lag (\circ)'); jnAxes(ax); set(ax, 'XTickLabelRotation', 45);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_L_phase_lag.png')); close(fig);

% ---- M: across-trial variance vs time (Fig-3 variance look) ----------------------------------------------------
% 5-frame (143 ms) running mean on the variance traces only: 46-103 trials per condition make the raw
% per-frame variance too ragged to compare five overlaid curves (window means below are unsmoothed).
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [1.1 0.6 W1-2.15 2.2]); hold(ax,'on');
Vraw = cell2mat(cellfun(@(Y) var(Y, 0, 2), grp, 'uni', 0)); Vx = movmean(Vraw, 5, 1);
yl = [0 max(Vx(:))*1.05];
stimBox(ax, 0, dur, yl, C);
for j = [5 1 3 2 4], plot(ax, tx, Vx(:,j), '-', 'Color', colJ(j,:), 'LineWidth', S.lw_mean); end
xlim(ax, tx([1 end])); ylim(ax, yl);
paperAxes(ax, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2 (%\DeltaF/F)^2');
text(ax, 0.5, 1.02, 'Variance across trials', 'Units','normalized', 'FontSize', S.fs_annot, ...
    'FontWeight','bold', 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
for j = 1:nJ
    text(ax, 1.04, 1.0 - 0.13*(j-1), namJ{j}, 'Units','normalized', 'Color', colJ(j,:), 'FontSize', S.fs_annot, ...
        'FontWeight','bold', 'HorizontalAlignment','left', 'VerticalAlignment','top', 'Clipping','off');
end
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_M_variance.png')); close(fig);
win = tx >= 0 & tx <= dur + 1e-9;
fprintf('[MPCS-P] variance over the 4 s window (OL/CL/CL+p/MPC/perfect): %s\n', mat2str(round(mean(Vraw(win,:)),2)));
fprintf('[MPCS-P] phase lag (OL/OL+p/CL/CL+p/MPC/perfect): %s deg\n', mat2str(round(lag,1)));
fprintf('[MPCS-P] panels -> %s\n', figDir);
end

function stimBox(ax, x1, x2, yl, C)
patch(ax, [x1 x2 x2 x1], yl([1 1 2 2]), [0.9 0.9 0.9], 'FaceAlpha', 0.4, 'EdgeColor','none');
plot(ax, [x1 x1], yl, '-', 'Color', C.edge, 'LineWidth', 0.6);
plot(ax, [x2 x2], yl, '-', 'Color', C.edge, 'LineWidth', 0.6);
end

function nameRow(fig, W, cols, names, C)
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
