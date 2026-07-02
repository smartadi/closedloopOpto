% bilateral/sine_ff_modes.m
% Sine-wave reference tracking — 4-mode comparison (FF-Analysis experiment).
% AL_0048 2026-07-01 exp 6, right (inhibitory) hemisphere only.
% Requires: load_bilateral.m has been run (sessions struct in workspace).
%
% ff_analysis_cond (input_params col 17) -> mode:
%   2 = OL only        (gain_fb = 0, preview off)   "blind open loop"
%   1 = OL + preview   (gain_fb = 0, preview on)
%   3 = CL only        (gain_fb = 1, preview off)   "PI only"
%   0 = CL + preview   (gain_fb = 1, preview on)
%
% Reference is a single FIXED commanded sine, identical across all trials/modes:
%   s(t) = amp * (1 + sin(-pi/2 + 2*pi*hz*t)),  fs = 35 Hz  (see base_controller._update_traj_array)
% All four modes are scored against this same raw reference so preview is not
% credited for tracking its own time-shifted setpoint.
%
% Compares per-trial MSE (vs the fixed sine) and across-trial variance.

%% ---- Knobs -------------------------------------------------------------
SIDE        = 'right';        % inhibitory hemisphere (only side used this session)
fs_img      = 35;
n_pre_s     = 1.0;            % pre-onset context for plots (s)
REF_SIGN    = -1;            % sign of commanded sine in dF/F space (VERIFY via panel 0)
REF_BASE    = [];            % DC offset of reference; [] => use sess.(SIDE).ref
EXPORT_FIG  = false;

% Mode display order, labels, colours
MODE_CODES  = [2 1 3 0];
MODE_LABELS = {'OL', 'OL+prev', 'CL', 'CL+prev'};
MODE_COLS   = [0.60 0.60 0.60;   % OL      grey
               0.30 0.55 0.85;   % OL+prev blue
               0.85 0.35 0.30;   % CL      red
               0.20 0.55 0.25];  % CL+prev green
% -------------------------------------------------------------------------

sty = paperStyle();

% Resolve paper/ root (works from brain_paper/ or bilateral/)
if exist(fullfile('paper', 'images'), 'dir')
    paper_root = 'paper';
elseif exist(fullfile('..', 'paper', 'images'), 'dir')
    paper_root = fullfile('..', 'paper');
else
    paper_root = 'paper';
end
outDir = fullfile(paper_root, 'images', 'bilateral');

%% ---- Locate the FF-analysis session -----------------------------------
fields = fieldnames(sessions);
sess = [];
for k = 1:numel(fields)
    s = sessions.(fields{k});
    if isfield(s, 'skip') && s.skip; continue; end
    if isfield(s, 'sine') && ~isempty(s.sine) && ...
       any([s.trial_meta.ff_cond] >= 0)
        sess = s; break;
    end
end
if isempty(sess)
    error('sine_ff_modes: no FF-analysis session found in `sessions`. Run load_bilateral.m with the 2026-07-01 exp 6 row.');
end

d   = sess.d;
t   = d.timeBlue;
sn  = sess.sine;

if isempty(sess.(SIDE).dFoF)
    error('sine_ff_modes: sess.%s.dFoF is empty — pixel not resolved. Check d.params.pixels in load_bilateral.m.', SIDE);
end
dFoF = sess.(SIDE).dFoF;

%% ---- Reconstruct the fixed commanded sine reference -------------------
n_win = round(sn.dur * fs_img);
n_pre = round(n_pre_s * fs_img);
t_ax  = (-n_pre : n_win) / fs_img;         % time axis for extracted windows
t_ref = (0 : n_win) / fs_img;              % reference time axis (post-onset)
t_post = t_ax >= 0;                        % post-onset samples

wave  = 1 + sin(-pi/2 + 2*pi * sn.hz * t_ref);   % in [0, 2], starts at 0
if isempty(REF_BASE); ref_base = sess.(SIDE).ref; else; ref_base = REF_BASE; end
Rref  = ref_base + REF_SIGN * sn.amp * wave;      % commanded reference (dF/F units)

%% ---- Collect per-mode trial windows -----------------------------------
nMode = numel(MODE_CODES);
traces = cell(1, nMode);   % each: [nTrial x numel(t_ax)]
mse    = cell(1, nMode);   % each: [nTrial x 1] MSE vs Rref over [0, dur]
nTr    = zeros(1, nMode);

sideMask = strcmp({sess.trial_meta.side}, SIDE);
for m = 1:nMode
    modeMask = ([sess.trial_meta.ff_cond] == MODE_CODES(m)) & sideMask;
    trials   = [sess.trial_meta(modeMask).trial_idx];
    for j = 1:numel(trials)
        [~, i0] = min(abs(t - d.stimStarts(trials(j))));
        if i0 - n_pre < 1 || i0 + n_win > length(dFoF); continue; end
        seg = dFoF(i0 - n_pre : i0 + n_win);
        traces{m} = [traces{m}; seg(:)'];
        seg_post  = seg(n_pre + 1 : end);          % t >= 0, length numel(t_ref)
        mse{m}    = [mse{m}; mean((seg_post - Rref).^2)];
    end
    nTr(m) = size(traces{m}, 1);
    fprintf('[%s] mode %-8s (cond %d): %2d trials | mean MSE = %.4f | mean var = %.4f\n', ...
        SIDE, MODE_LABELS{m}, MODE_CODES(m), nTr(m), ...
        mean(mse{m}), mean(var(traces{m}(:, t_post), 0, 1)));
end

%% ---- Panel 0 (verification): grand-mean dFoF vs reconstructed ref ------
% Overlay every mode's mean trace with Rref to confirm REF_SIGN / REF_BASE
% before trusting MSE. If the reference sits opposite the data, flip REF_SIGN.
fig0 = paperFig(6, 4); hold on;
for m = 1:nMode
    if nTr(m) == 0; continue; end
    plot(t_ax, mean(traces{m}, 1), 'Color', MODE_COLS(m,:), 'LineWidth', sty.lw_mean);
end
plot(t_ref, Rref, 'k--', 'LineWidth', sty.lw_ref);
xline(0, 'k:', 'LineWidth', 0.8);
legend([MODE_LABELS, {'ref'}], 'FontSize', sty.fs, 'ItemTokenSize', [6 6], 'Box', 'off');
xlabel('Time (s)', 'FontSize', sty.fs, 'FontWeight', 'bold');
ylabel('\DeltaF/F (%)', 'FontSize', sty.fs, 'FontWeight', 'bold');
title('Tracking + reference (verify sign)', 'FontSize', sty.fs, 'FontWeight', 'bold');
hold off;

%% ---- Panel A: MSE across the 4 modes (violin + mean) -------------------
figA = paperFig(6, 4); ax = gca; hold(ax, 'on');
hw = 0.32;
for m = 1:nMode
    if nTr(m) < 2; continue; end
    [f, y] = ksdensity(mse{m});
    f = f / max(f) * hw;
    fill(ax, [m - f, m*ones(size(f))], [y, fliplr(y)], MODE_COLS(m,:), ...
        'FaceAlpha', 0.5, 'EdgeColor', 'none');
    plot(ax, m, mean(mse{m}), 'k.', 'MarkerSize', 8);
end
hold(ax, 'off');
xlim(ax, [0.5 nMode + 0.5]);
ax.XTick = 1:nMode; ax.XTickLabel = MODE_LABELS;
ylabel(ax, 'Trial MSE vs sine (\DeltaF/F)^2', 'FontSize', sty.fs, 'FontWeight', 'bold');
set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', sty.fs, 'FontWeight', 'bold');
title(ax, 'MSE by mode', 'FontSize', sty.fs, 'FontWeight', 'bold');

% Pairwise Wilcoxon rank-sum on the key contrasts
pairs = {[1 2] 'OL vs OL+prev'; [3 4] 'CL vs CL+prev'; [1 3] 'OL vs CL'; [2 4] 'OL+prev vs CL+prev'};
fprintf('\nPairwise MSE (Wilcoxon rank-sum):\n');
for p = 1:size(pairs, 1)
    a = pairs{p,1}(1); b = pairs{p,1}(2);
    if nTr(a) >= 2 && nTr(b) >= 2
        pv = ranksum(mse{a}, mse{b});
        fprintf('  %-22s p = %.4g\n', pairs{p,2}, pv);
    end
end

%% ---- Panel B: across-trial variance traces, 4 modes -------------------
figB = paperFig(6, 4); hold on;
for m = 1:nMode
    if nTr(m) < 2; continue; end
    v = var(traces{m}, 0, 1);
    plot(t_ax, v, 'Color', MODE_COLS(m,:), 'LineWidth', sty.lw_mean);
end
xline(0, 'k:', 'LineWidth', 0.8);
xline(sn.dur, 'k:', 'LineWidth', 0.8);
legend(MODE_LABELS(nTr >= 2), 'FontSize', sty.fs, 'ItemTokenSize', [6 6], 'Box', 'off');
xlabel('Time (s)', 'FontSize', sty.fs, 'FontWeight', 'bold');
ylabel('Across-trial variance (\DeltaF/F)^2', 'FontSize', sty.fs, 'FontWeight', 'bold');
title('Variance by mode', 'FontSize', sty.fs, 'FontWeight', 'bold');
hold off;

%% ---- Export -----------------------------------------------------------
if EXPORT_FIG
    if ~exist(outDir, 'dir'); mkdir(outDir); end
    exportgraphics(fig0, fullfile(outDir, 'sine_ff_verify.png'),   'Resolution', 300);
    exportgraphics(figA, fullfile(outDir, 'sine_ff_mse.png'),      'Resolution', 300);
    exportgraphics(figB, fullfile(outDir, 'sine_ff_variance.png'), 'Resolution', 300);
    fprintf('Exported 3 PNGs to %s\n', outDir);
end
