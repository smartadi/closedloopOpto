function ctrl_mpc_sine_panels(sess, kEx)
%CTRL_MPC_SINE_PANELS  Fig 6 I-M: the direct-prediction MPC replayed on a SINE reference (mpc_direct_sine.py),
%   AL_0048 2026-07-14/1 right hemisphere (Fig 5's representative session), 1 Hz sine 0..-4 %dF/F, 4 s window.
%   Same look as ctrl_mpc_direct_panels (Fig 6 A-H): Fig-3 stim box, corner scale bars, colour-named conditions,
%   no numbers in the panels. Colours: Fig 5 modes (OL red, CL+p green), MPC purple, perfect-prediction MPC light
%   purple. SIMULATION -> descriptive only, no tests, no stars.
%   COMPARISON SET (user 2026-10-16): CL+p against the two MPCs only (no CL); OL as the uncontrolled reference.
%   MPC / perfect = the replays on the 57 CL+p trials, each paired with the recorded CL+p trial it replays.
%   Panels: I example CL+p trial (large MPC gain, kEx) | J RMSE over time (Fig 5F definition: sqrt of the
%           across-trial mean squared error, +/- SEM) | K per-trial RMSE, paired | L phase lag of the trial average
%           (1 Hz fundamental, Fig 5H) | M across-trial variance vs time.
%   IN  data/mpc_direct_sine_<sess>.mat.   OUT paper/images/supp_mpc/mpcs_*.png (+ PDF + mirror with PAPER_FINAL)
if nargin < 1 || isempty(sess), sess = 'AL_0048_0714_e1'; end
% Example trial (1-based, all-sine index). 161 = picked by eye (user 2026-10-16: "show a trial where MPC does really
% well") from the top 5 CL+p trials by RMSE drop (104, 141, 184, 27, 161): MPC tracks the sine over the whole window
% while CL+p overshoots each rise (RMSE 1.58 -> 0.83). 104/141 gain mostly in the onset transient. [] = median trial.
if nargin < 2, kEx = 161; end
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here,'data'); addpath(genpath(fullfile(here,'..','utils')));
figDir = fullfile(here,'..','paper','images','supp_mpc');
PS = paperStyle(); S = jnStyle();
C.m = [0.45 0.20 0.60]; C.o = [0.78 0.66 0.90]; C.g = [0.62 0.62 0.62]; C.k = [0 0 0];
C.edge = [0.45 0.45 0.45]; C.ref = [0.25 0.25 0.25];
C.ol = [1 0 0]; C.clp = [0 0.50 0];                  % Fig 5 MODE_COLS: OL red, CL+p green
% ONE ROW at the 17.6 cm double-column width (user 2026-10-16): I 5.2 + 4 x 2.8 + 4 gaps x 0.3 = 17.6 cm
W1 = 2.8; W2 = 5.2; H = 3.0;
D = load(fullfile(dataDir, sprintf('mpc_direct_sine_%s.mat', sess)));
cond = double(D.cond(:)); Fs = double(D.Fs); N = double(D.N); ext = double(D.ext); dur = (N-1)/Fs;
tx = (-ext:N+ext-1).'/Fs; keep = tx >= -1 - 1e-9 & tx <= dur + 1 + 1e-9; tx = tx(keep);   % -1 .. 5 s
sn = cellstr(D.sim_names); iM = find(strcmp(sn,'MPC')); iO = find(strcmp(sn,'perfect'));
isOL = cond == 2; isCLp = cond == 0;
rRec = D.rmse_rec(:); rM = D.rmse_sim(:,iM); rO = D.rmse_sim(:,iO);
Rref = mean(D.R, 2); tw = (0:N-1).'/Fs;
v2mw = @(v) laser_v2mw(v, '2026-07-14', 638);
% the four conditions of J/L/M: recorded OL, recorded CL+p, MPC and perfect MPC on the CL+p trials
col4 = [C.ol; C.clp; C.m; C.o]; nam4 = {'OL','CL+p','MPC','perfect'};
Yw = {D.Yrec(:,isOL), D.Yrec(:,isCLp), D.Ysim(:,isCLp,iM), D.Ysim(:,isCLp,iO)};        % stim window, N x n
Rw = {D.R(:,isOL), D.R(:,isCLp), D.R(:,isCLp), D.R(:,isCLp)};
Yx = {D.Yrecx(keep,isOL), D.Yrecx(keep,isCLp), D.Yx(keep,isCLp,iM), D.Yx(keep,isCLp,iO)};   % -1 .. 5 s
for p = {'mpcs_J_trial_average'}                                                            % replaced panels
    old = dir(fullfile(figDir, [p{1} '.*'])); for i = 1:numel(old), delete(fullfile(figDir, old(i).name)); end
end

% ---- I: example CL+p trial with a large MPC improvement ---------------------------------------------------------
iC = find(isCLp); [~, s] = sort(rM(iC) - rRec(iC)); kMed = iC(s(round(0.5*(numel(iC)-1))+1));
k = kMed; if ~isempty(kEx), k = kEx; end
fprintf('[MPCS-P] median-improvement CL+p trial would be %d\n', kMed);
fprintf('[MPCS-P] example trial %d (CL+p): RMSE CL+p %.2f | MPC %.2f | perfect %.2f\n', k, rRec(k), rM(k), rO(k));
Yk = [D.Yrecx(keep,k) D.Yx(keep,k,iM) D.Yx(keep,k,iO)]; Uk = v2mw([D.Urecx(keep,k) D.Ux(keep,k,iM) D.Ux(keep,k,iO)]);
col3 = [C.clp; C.m; C.o]; nam3 = {'CL+p','MPC','perfect'};
fig = jnFig(W2, H);
ax1 = axes(fig, 'Units','centimeters', 'Position', [0.6 1.3 W2-0.7 1.6]); hold(ax1,'on');
ax2 = axes(fig, 'Units','centimeters', 'Position', [0.6 0.42 W2-0.7 0.42]); hold(ax2,'on');
yl1 = [min([Yk(:); Rref]) max(Yk(:))] + [-0.5 0.5]; yl2 = [-0.02 max(Uk(:))*1.05];
stimBox(ax1, 0, dur, yl1, C); stimBox(ax2, 0, dur, yl2, C);
plot(ax1, tx([1 end]), [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
plot(ax1, tw, Rref, '--', 'Color', C.ref, 'LineWidth', S.lw_ref);
for j = [3 1 2]
    plot(ax1, tx, Yk(:,j), '-', 'Color', col3(j,:), 'LineWidth', S.lw_mean);
    stairs(ax2, tx, Uk(:,j), '-', 'Color', col3(j,:), 'LineWidth', PS.lw_inp);
end
plot(ax1, tw, Rref, '--', 'Color', C.ref, 'LineWidth', 1.0);      % target on top: at this size the traces hide it
xlim(ax1, tx([1 end])); ylim(ax1, yl1); xlim(ax2, tx([1 end])); ylim(ax2, yl2);
paperAxes(ax1, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2% \DeltaF/F');
paperAxes(ax2, 'XLength', 0, 'YLength', 0.5, 'YLabel', '0.5 mW');
nameRow(fig, 0.6, 0.0, col3, nam3, C, true);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_I_example.png')); close(fig);

% ---- J: RMSE over time, trial-averaged (Fig 5F definition) -----------------------------------------------------
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.55 0.5 W1-0.65 1.7]); hold(ax,'on');
mx = 0;
for j = [1 2 4 3]
    E = (Yw{j} - Rw{j}).^2; mu = mean(E, 2); se = std(E, 0, 2) / sqrt(size(E, 2));
    lo = sqrt(max(mu - se, 0)); hi = sqrt(mu + se); mx = max(mx, max(hi));
    fill(ax, [tw; flipud(tw)], [hi; flipud(lo)], col4(j,:), 'FaceAlpha', 0.25, 'EdgeColor', 'none');
    plot(ax, tw, sqrt(mu), '-', 'Color', col4(j,:), 'LineWidth', S.lw_mean);
end
xlim(ax, [0 dur]); ylim(ax, [0 mx*1.02]);
paperAxes(ax, 'XLength', 1, 'YLength', 1, 'XLabel', '1 s', 'YLabel', '1% \DeltaF/F');
text(ax, 0.5, 1.2, 'RMSE across trials', 'Units','normalized', 'FontSize', S.fs_annot, ...
    'FontWeight','bold', 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
nameRow(fig, 0.55, 2.27, col4, nam4, C, false);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_J_rmse_time.png')); close(fig);

% ---- K: per-trial RMSE, paired with the recorded CL+p trial ----------------------------------------------------
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.95 0.75 W1-1.05 2.05]); hold(ax,'on'); rng(1);
Rb = [rRec(isCLp) rM(isCLp) rO(isCLp)]; jx = (rand(nnz(isCLp),1)-0.5)*0.36;
plot(ax, (1:3)' + [jx jx jx]', Rb', '-', 'Color', [C.g 0.12], 'LineWidth', 0.25);
for i = 1:3
    scatter(ax, i + jx, Rb(:,i), 4, col3(i,:), 'filled', 'MarkerFaceAlpha', 0.5);
    plot(ax, i + [-0.28 0.28], median(Rb(:,i))*[1 1], '-', 'Color', C.k, 'LineWidth', 1.2);
end
mxr = ceil(max(Rb(:)));
set(ax, 'XTick', 1:3, 'XTickLabel', {'CL+p','MPC','perfect'}, 'YTick', [0 mxr]); xlim(ax, [0.4 3.6]); ylim(ax, [0 mxr]);
ylabel(ax, 'trial RMSE (%)'); jnAxes(ax); set(ax, 'XTickLabelRotation', 45);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_K_rmse_compare.png')); close(fig);

% ---- L: phase lag of the trial average (1 Hz fundamental fit, Fig 5H definition) ------------------------------
rows = cellstr(D.summary_rows); su = D.summary;
lag = cellfun(@(l) su(strcmp(rows, l), 2), {'rec OL','rec CL+p','MPC on CL+p','perfect on CL+p'});
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.95 0.75 W1-1.05 2.05]); hold(ax,'on');
% Scaled to the CL+p vs MPC differences (user 2026-10-16); OL (~71 deg) runs off the top, drawn truncated
% with a white break mark -- its value is given in the caption.
yl = [-2.5 3];
for i = 1:numel(lag), bar(ax, i, min(lag(i), yl(2)), 0.6, 'FaceColor', col4(i,:), 'EdgeColor', 'none'); end
for i = find(lag > yl(2))
    for dy = [-0.55 -0.25]
        plot(ax, i + [-0.36 0.36], yl(2) + dy + [-0.12 0.12], '-', 'Color', 'w', 'LineWidth', 1.2);
    end
end
plot(ax, [0.4 numel(lag)+0.6], [0 0], '-', 'Color', C.k, 'LineWidth', 0.4);
set(ax, 'XTick', 1:numel(lag), 'XTickLabel', nam4, 'YTick', [-2 0 2]); xlim(ax, [0.4 numel(lag)+0.6]); ylim(ax, yl);
ylabel(ax, 'phase lag (\circ)'); jnAxes(ax); set(ax, 'XTickLabelRotation', 45);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_L_phase_lag.png')); close(fig);

% ---- M: across-trial variance vs time (Fig-3 variance look) ----------------------------------------------------
% 5-frame (143 ms) running mean on the variance traces only: 51-57 trials per condition make the raw
% per-frame variance too ragged to compare four overlaid curves (window means below are unsmoothed).
fig = jnFig(W1, H); ax = axes(fig, 'Units','centimeters', 'Position', [0.55 0.5 W1-0.65 1.7]); hold(ax,'on');
Vraw = cell2mat(cellfun(@(Y) var(Y, 0, 2), Yx, 'uni', 0)); Vx = movmean(Vraw, 5, 1);
yl = [0 max(Vx(:))*1.05];
stimBox(ax, 0, dur, yl, C);
for j = [1 2 4 3], plot(ax, tx, Vx(:,j), '-', 'Color', col4(j,:), 'LineWidth', S.lw_mean); end
xlim(ax, tx([1 end])); ylim(ax, yl);
paperAxes(ax, 'XLength', 1, 'YLength', 2, 'XLabel', '1 s', 'YLabel', '2 (%\DeltaF/F)^2');
text(ax, 0.5, 1.2, 'Variance across trials', 'Units','normalized', 'FontSize', S.fs_annot, ...
    'FontWeight','bold', 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Clipping','off');
nameRow(fig, 0.55, 2.27, col4, nam4, C, false);
ctrl_mpc_export(fig, fullfile(figDir, 'mpcs_M_variance.png')); close(fig);
win = tx >= 0 & tx <= dur + 1e-9;
fprintf('[MPCS-P] variance over the 4 s window (OL/CL+p/MPC/perfect): %s\n', mat2str(round(mean(Vraw(win,:)),2)));
fprintf('[MPCS-P] RMSE over time, window mean of sqrt(mean sq err) (OL/CL+p/MPC/perfect): %s\n', ...
    mat2str(round(cellfun(@(Y,R) mean(sqrt(mean((Y-R).^2, 2))), Yw, Rw), 2)));
fprintf('[MPCS-P] phase lag (OL/CL+p/MPC/perfect): %s deg\n', mat2str(round(lag,1)));
fprintf('[MPCS-P] panels -> %s\n', figDir);
end

function stimBox(ax, x1, x2, yl, C)
patch(ax, [x1 x2 x2 x1], yl([1 1 2 2]), [0.9 0.9 0.9], 'FaceAlpha', 0.4, 'EdgeColor','none');
plot(ax, [x1 x1], yl, '-', 'Color', C.edge, 'LineWidth', 0.6);
plot(ax, [x2 x2], yl, '-', 'Color', C.edge, 'LineWidth', 0.6);
end

function nameRow(fig, x0, y0, cols, names, C, withTarget)
% condition names in one row, laid out in cm from each label's measured width (fits any panel width)
S = jnStyle(); ax = axes(fig, 'Units','centimeters', 'Position', [0 y0 fig.Position(3) 0.3]); hold(ax,'on'); axis(ax,'off');
set(ax, 'XLim', [0 fig.Position(3)], 'YLim', [0 1]); x = x0; seg = 0.25 * withTarget;
for j = 1:numel(names)
    if withTarget, plot(ax, x + [0 seg], [0.5 0.5], '-', 'Color', cols(j,:), 'LineWidth', 1.5); end
    t = text(ax, x + seg + 0.05*withTarget, 0.5, names{j}, 'Color', cols(j,:)*(~withTarget), 'FontSize', S.fs_annot, ...
        'FontWeight','bold', 'VerticalAlignment','middle', 'Units','data');
    if ~withTarget, t.Color = cols(j,:); end
    x = t.Extent(1) + t.Extent(3) + 0.15;
end
if withTarget
    plot(ax, x + [0 seg], [0.5 0.5], '--', 'Color', C.ref, 'LineWidth', 1.0);
    text(ax, x + seg + 0.05, 0.5, 'target', 'FontSize', S.fs_annot, 'FontWeight','bold', 'VerticalAlignment','middle');
end
end
